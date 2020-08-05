package SonusQA::AS;


=head1 NAME
 SonusQA::AS - Perl module for AS

=head1 AUTHOR

 Tram Nguyen - ntqtram@tma.com.vn

=head1 IMPORTANT

 B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   $ats_obj_ref = SonusQA::AS->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                      -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                      -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                      -obj_commtype => "SSH",
                                      %refined_args,
                                      );

=head1 REQUIRES

 Perl5.8.7, Log::Log4perl, SonusQA::Base, Data::Dumper, Module::Locate

=head1 DESCRIPTION

 This module provides an interface to telnet to MSC and PAC cards and execute basic commands on them.

=head1 METHODS

=cut

use strict;
use warnings;


use Log::Log4perl qw(get_logger :easy);
use Module::Locate qw /locate/;
use Data::Dumper;
use Switch;
use List::MoreUtils qw(uniq);


our $VERSION = "1.0";
our @ISA = qw(SonusQA::Base);

=head2 B<doInitialization()>

=over 6

=item DESCRIPTION:

 Routine to set object defaults and session prompt.

=item Arguments:

 Object Reference

=item Returns:

 None

=back

=cut

sub doInitialization {
    my($self, %args)=@_;
    my $sub = "doInitialization";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: Entered sub");
    $self->{COMMTYPES} = ["SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%#\}\|\>\]].*$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{STORE_LOGS} = 2;
    $self->{LOCATION} = locate __PACKAGE__ ;
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[1]");
    return 1;
}

=head2 B<setSystem()>

    This function sets the system information and Prompt.

=over 6

=item Arguments:

        Object Reference

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=back

=cut

sub setSystem{
    my ($self) = @_;
    my $sub_name = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub");
    $self->{conn}->cmd("bash");
    my $cmd = 'export PS1="AUTOMATION> "';
    $self->{PROMPT} = '/AUTOMATION\> $/';
    my $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub_name  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
     unless ($self->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not execute '$cmd'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$sub_name: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0 ;
    }
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);

    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
}


=head2 B<SOAPUI()>

    This function read xml file, replace value from input and save on _new file. Then execute SOAPUI cammand to provisioning on A2.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        ip
        port
        username
        password
        users     
        xmlfile
        others variables depend on xml file. 

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        my %args = (
        -ip => '10.250.161.36',
        -port => '8443',
        -username => 'admin',
        -password => 'admin',
        -users => '4409940@tma15.automation.com',
        -services => 'audioconf|nortel,allowedclients|nortel',
        -xmlfile => 'addServiceForUser.xml',;
        $obj->SOAPUI(%args);

=back

=cut

sub SOAPUI{
    my ($self, %args) = @_;
    my $sub_name = "SOAPUI";
    my ($xmlfile);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    foreach ('-ip', '-port', '-xmlfile') {
    #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    #Checking for the xml file
    
    unless ($args{-xmlfile}=~m[.xml]) {
        $logger->error(__PACKAGE__ . ".$sub_name: -xmlfile must contains .xml at the end. For examble : 'addServiceForUser.xml'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my @cmdResults;
    my $cmdResult;
    my $timeout = 30;
    my $line;
    my @path = split(/.xml/, $args{-xmlfile});
    my $in_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/AS/SOAP_UI_FILE/".$args{-xmlfile};
    my $out_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/AS/SOAP_UI_FILE/".$path[0]."_new.xml";
    unless ( open(IN, "<$in_file")) {
        $logger->error( __PACKAGE__ . ".$sub_name: open $in_file failed " );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Open xml file \n");
    unless (open OUT, ">$out_file") {
        $logger->error( __PACKAGE__ . ".$sub_name: open $out_file failed " );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Create new xml file \n");
    my $flag;
    while ( $line = <IN> ) {
    $xmlfile = $args{-xmlfile};
    #Replace IP:port MCP provisioning
        if ($line =~ m[MCPHost]) {
            $line =~ s/MCPHost/$args{-ip}\:$args{-port}/;
            $logger->debug(__PACKAGE__ . ".$sub_name: Replace IP:port (MCP): $args{-ip}\:$args{-port} \n");
        }
    #Replace IP:port A2 provisioning
        if ($line =~ m[ProvisioningHost]) {
            $line =~ s/ProvisioningHost/$args{-ip}\:$args{-port}/;
            $logger->debug(__PACKAGE__ . ".$sub_name: Replace IP:port (A2 Prov): $args{-ip}\:$args{-port} \n");
        }
    #Replace username to login A2 provisioning
        if ($line =~ m[<con:username>admin</con:username>]) {
            $line =~ s/admin/$args{-username}/;
            $logger->debug(__PACKAGE__ . ".$sub_name: Replace Username: $args{-username} \n");
        }
    #Replace password to login A2 provisioning
        if ($line =~ m[<con:password>admin</con:password>]) {
            $line =~ s/admin/$args{-password}/;
            $logger->debug(__PACKAGE__ . ".$sub_name: Replace Password: $args{-password} \n");
        }
        $flag = 1;
        if ($xmlfile =~ /addServiceForUser/i)
        {
            foreach ('-usr_users', '-usr_services') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace services
            if ($line =~ m[services="presence\|nortel\,allowedclients\|nortel"]) {
                $line =~ s/presence\|nortel\,allowedclients\|nortel/$args{-usr_services}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace services: $args{-usr_services} \n");
            }
            #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }
        }
        elsif ($xmlfile =~ /addMultiUser/i)
        {
            foreach ('-usr_UserName','-usr_Password','-usr_Total_User','-usr_Domain','-usr_Service_Set','-usr_Type') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace users will be added new no1
                if ($line =~ m[userName\=\"8219941\"\;]) {
                    $line =~ s/8219941/$args{-usr_UserName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserName: $args{-usr_UserName} \n");
                }
            #Replace password for users
                elsif ($line =~ m[password\=\"1234\"\;]) {
                    $line =~ s/1234/$args{-usr_Password}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Password: $args{-usr_Password} \n");
                }
            #Replace total users added
                elsif ($line =~ m[userNumber\=\"3\"\;]) {
                    $line =~ s/3/$args{-usr_Total_User}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace Total_User: $args{-usr_Total_User} \n");
                }
            #Replace domain of users
                elsif ($line =~ m[domain\=\"tma6\.automation\.com\"\;]) {
                    $line =~ s/tma6\.automation\.com/$args{-usr_Domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace Domain: $args{-usr_Domain} \n");
                }
            #Replace Service Set for User
                elsif ($line =~ m[serviceSet\=\"service\_au\"\;]) {
                    $line =~ s/service\_au/$args{-usr_Service_Set}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace Service_Set: $args{-usr_Service_Set} \n");
                }
            #Replace line type of Users
                elsif ($line =~ m[type\=\"asftswtch\"\;]) {
                    $line =~ s/asftswtch/$args{-usr_Type}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace Type: $args{-usr_Type} \n");
                }
        }
        
        elsif ($xmlfile =~  /(addProfileServiceAdhocConf|addProfileServiceAccountCodes|setProfileAllowedClientsService|setProfileAuthCodesService|setProfileCallFwdService|setProfileCallPickupService|setProfileCallReturnService|setProfileCallTypeScrService|setProfileDenyAllCallsService|setProfileHotLineService|setProfileMeetMeConfService|setProfilePresenceService|setProfileSelectCallRejectService|setProfileTIRService|setProfileNcwdService|setProfileCallGrabService|setProfileCallParkService|setSystemProfileInstantMessagingForUser|setSystemProfileAdvScrForUser|setSystemProfileAddressBookForUser)/i)
        {   
            foreach ('-usr_users', '-usr_profile') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace profile
            if ($line =~ m[profile_name]) {
                $line =~ s/profile_name/$args{-usr_profile}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace profile: $args{-usr_profile} \n");
            }
            #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }
        }
        elsif ($xmlfile =~ /setUseProfileAdhocConfForUser/i)
        {
            foreach ('-usr_users', '-usr_adhocConfEnabled') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace adhocConfEnabled
            if ($line =~ m[\<adhocConfEnabled xsi\:type\=\"xsd\:boolean\"\>true\<\/adhocConfEnabled\>]) {
                $line =~ s/true/$args{-usr_adhocConfEnabled}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace adhocConfEnabled: $args{-usr_adhocConfEnabled} \n");
            }
            #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }
        }
        elsif ($xmlfile =~ /setCFVRouteForUserBusy/i)
        {
            foreach ('-usr_users', '-usr_dnroutetobusy','-usr_numRings') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace dnroutetobusy
            if ($line =~ m[dnroutetobusy\@domain]) {
                $line =~ s/dnroutetobusy\@domain/$args{-usr_dnroutetobusy}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace dnroutetobusy: $args{-usr_dnroutetobusy} \n");
            }
            #Replace numRings
            elsif ($line =~ m[numRings]) {
                $line =~ s/numRings/$args{-usr_numRings}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace numRings: $args{-usr_numRings} \n");
            }
            #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }
        }
        elsif ($xmlfile =~ /setCFVRouteForUserNoAnswer/i)
        {
            foreach ('-usr_users', '-usr_dnRouteToNoAnswer', '-usr_numRings') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace dnRouteToNoAnswer
            if ($line =~ m[dnRouteToNoAnswer\@domain]) {
                $line =~ s/dnRouteToNoAnswer\@domain/$args{-usr_dnRouteToNoAnswer}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace dnRouteToNoAnswer: $args{-usr_dnRouteToNoAnswer} \n");
            }
        #Replace numRings
            elsif ($line =~ m[numRings]) {
                $line =~ s/numRings/$args{-usr_numRings}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace numRings: $args{-usr_numRings} \n");

            }
        #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }
        }
        elsif ($xmlfile =~ /setCFIRouteImmediate/i)
        {
            foreach ('-usr_users', '-usr_dnRouteToImmediate', '-usr_numRings') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace usr_dnRouteToImmediate
            if ($line =~ m[usr_dnRouteToImmediate]) {
                $line =~ s/usr_dnRouteToImmediate/$args{-usr_dnRouteToImmediate}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dnRouteToImmediate: $args{-usr_dnRouteToImmediate} \n");
            }
        #Replace usr_Active_TorF
            elsif ($line =~ m[usr_Active_TorF]) {
                if ($args{-usr_Active_TorF} eq 'true'|$args{-usr_Active_TorF} eq 'false') {
                    $line =~ s/usr_Active_TorF/$args{-usr_Active_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Active_TorF: $args{-usr_Active_TorF} \n");
                } else {
                    $line =~ s/usr_Active_TorF/true/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Active_TorF: true \n");
                }
            }                
        #Replace numRings
            elsif ($line =~ m[usr_numRings]) {
                $line =~ s/usr_numRings/$args{-usr_numRings}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numRings: $args{-usr_numRings} \n");

            }
        #Replace users will be added services
            elsif ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        }
        elsif ($xmlfile =~ /setUseProfileCallPickupForUser/i)
        {
            foreach ('-usr_users', '-usr_agentStatusEnabled') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace agentStatusEnabled
            if ($line =~ m[\<agentStatusEnabled xsi\:type\=\"xsd\:boolean"\>true\<\/agentStatusEnabled\>]) {
                $line =~ s/true/$args{-usr_agentStatusEnabled}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace agentStatusEnabled: $args{-usr_agentStatusEnabled} \n");
            }
        #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }
        }
        elsif ($xmlfile =~ /setUseProfileCallReturnForUser/i)
        {
            foreach ('-usr_users', '-usr_callReturnEnabled') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace callReturnEnabled
            if ($line =~ m[\<callReturnEnabled xsi\:type\=\"xsd\:boolean\"\>true\<\/callReturnEnabled\>]) {
                $line =~ s/true/$args{-usr_callReturnEnabled}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace callReturnEnabled: $args{-usr_callReturnEnabled} \n");
            }
        #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }            
        }
        elsif ($xmlfile =~ /changePINForCallReturn/i)
        {
            unless ($args{-usr_password}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_password
            if ($line =~ m[usr_password]) {
                $line =~ s/usr_password/$args{-usr_password}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_password: $args{-usr_password} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setSelectedCallTypesAreBlocked/i)
        {
            foreach ('-usr_users', '-usr_setInternational', '-usr_setInternationalExcludingHC', '-usr_setLocal', '-usr_setLongDistance', '-usr_setLongDistanceInterRateArea', '-usr_setLongDistanceIntraRateArea', '-usr_setPremium') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace setInternational 
            if ($line =~ m[\<international xsi\:type\=\"xsd\:boolean\"\>setInternational\<\/international\>]) {
                $line =~ s/setInternational/$args{-usr_setInternational}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setInternational: $args{-usr_setInternational} \n");
            }
        #Replace setInternationalExcludingHC  
            elsif ($line =~ m[\<internationalExcludingHC xsi\:type\=\"xsd\:boolean\"\>setInternationalExcludingHC\<\/internationalExcludingHC\>]) {
                $line =~ s/setInternationalExcludingHC/$args{-usr_setInternationalExcludingHC}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setInternationalExcludingHC: $args{-usr_setInternationalExcludingHC} \n");
            }
        #Replace setLocal   
            elsif ($line =~ m[\<local xsi\:type\=\"xsd\:boolean\"\>setLocal\<\/local\>]) {
                $line =~ s/setLocal/$args{-usr_setLocal}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setLocal: $args{-usr_setLocal} \n");
            }
        #Replace setLongDistance   
            elsif ($line =~ m[\<longDistance xsi\:type\=\"xsd\:boolean\"\>setLongDistance\<\/longDistance\>]) {
                $line =~ s/setLongDistance/$args{-usr_setLongDistance}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setLongDistance: $args{-usr_setLongDistance} \n");
            }
        #Replace setLongDistanceInterRateArea    
            elsif ($line =~ m[\<longDistanceInterRateArea xsi\:type\=\"xsd\:boolean\"\>setLongDistanceInterRateArea\<\/longDistanceInterRateArea\>]) {
                $line =~ s/setLongDistanceInterRateArea/$args{-usr_setLongDistanceInterRateArea}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setLongDistanceInterRateArea: $args{-usr_setLongDistanceInterRateArea} \n");
            }
        #Replace setLongDistanceIntraRateArea     
            elsif ($line =~ m[\<longDistanceIntraRateArea xsi\:type\=\"xsd\:boolean\"\>setLongDistanceIntraRateArea\<\/longDistanceIntraRateArea\>]) {
                $line =~ s/setLongDistanceIntraRateArea/$args{-usr_setLongDistanceIntraRateArea}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setLongDistanceIntraRateArea: $args{-usr_setLongDistanceIntraRateArea} \n");
            }
        #Replace setPremium    
            elsif ($line =~ m[\<premium xsi\:type\=\"xsd\:boolean\"\>setPremium\<\/premium\>]) {
                $line =~ s/setPremium/$args{-usr_setPremium}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setPremium: $args{-usr_setPremium} \n");
            }
        #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }            
        }
        elsif ($xmlfile =~ /clickToCallAdminService/i)
        {
            foreach ('-usr_domainOfUser', '-usr_dnCTCFromParty', '-usr_dnCTCToParty') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace domainOfUser
            if ($line =~ m[domainOfUser]) {
                $line =~ s/domainOfUser/$args{-usr_domainOfUser}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace domainOfUser: $args{-usr_domainOfUser} \n");
            }
        #Replace dnCTCFromParty
            elsif ($line =~ m[\"\>dnCTCFromParty\@domain\<\/ctcFromParty\>]) {
                $line =~ s/dnCTCFromParty\@domain/$args{-usr_dnCTCFromParty}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace dnCTCFromParty: $args{-usr_dnCTCFromParty} \n");
            }
        #Replace dnCTCToParty
            elsif ($line =~ m[\"\>dnCTCToParty\@domain\<\/ctcToParty\>]) {
                $line =~ s/dnCTCToParty\@domain/$args{-usr_dnCTCToParty}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace dnCTCToParty: $args{-usr_dnCTCToParty} \n");
            }
        }
        elsif ($xmlfile =~ /setUseProfileHotLineForUser/i)
        {
            foreach ('-usr_users', '-usr_setCalledParty', '-usr_setkeyLabel') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace setCalledParty 
            if ($line =~ m[\>setCalledParty\<\/calledParty\>]) {
                $line =~ s/setCalledParty/$args{-usr_setCalledParty}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setCalledParty: $args{-usr_setCalledParty} \n");
            }
        #Replace setkeyLabel 
            elsif ($line =~ m[\"\>setkeyLabel\<\/keyLabel\>]) {
                $line =~ s/setkeyLabel/$args{-usr_setkeyLabel}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setkeyLabel: $args{-usr_setkeyLabel} \n");
            }
        #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }            
        }
        elsif ($xmlfile =~ /addConfigMeetMeConfForUser|modifyConfigMeetMeConfForUser/i)
        {
            foreach ('-usr_users', '-usr_numAccessCode', '-usr_setAudioEmotIconsEnabledTorF', '-usr_dnAudioRecEmailAddr', '-usr_setChairEndsTorF', '-usr_setChairPinNum', '-usr_setEntryExitIndication', '-usr_setFastStartTorF', '-usr_setImenableTorF', '-usr_setPremConfTorF', '-usr_setPublicPinNum', '-usr_setUserStateTorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace numAccessCode 
            if ($line =~ m[\"\>numAccessCode\<\/accessCode\>]) {
                $line =~ s/numAccessCode/$args{-usr_numAccessCode}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace numAccessCode: $args{-usr_numAccessCode} \n");
            }
        #Replace setAudioEmotIconsEnabledTorF  
            elsif ($line =~ m[\<audioEmotIconsEnabled xsi\:type\=\"xsd\:boolean\"\>setAudioEmotIconsEnabledTorF\<\/audioEmotIconsEnabled\>]) {
                $line =~ s/setAudioEmotIconsEnabledTorF/$args{-usr_setAudioEmotIconsEnabledTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setAudioEmotIconsEnabledTorF: $args{-usr_setAudioEmotIconsEnabledTorF} \n");
            }
        #Replace dnAudioRecEmailAddr   
            elsif ($line =~ m[\"\>dnAudioRecEmailAddr\@domain\<\/audioRecEmailAddr\>]) {
                $line =~ s/dnAudioRecEmailAddr\@domain/$args{-usr_dnAudioRecEmailAddr}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace dnAudioRecEmailAddr: $args{-usr_dnAudioRecEmailAddr} \n");
            }
        #Replace setChairEndsTorF  
            elsif ($line =~ m[\<chairEnds xsi\:type\=\"xsd\:boolean\"\>setChairEndsTorF\<\/chairEnds\>]) {
                $line =~ s/setChairEndsTorF/$args{-usr_setChairEndsTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setChairEndsTorF: $args{-usr_setChairEndsTorF} \n");
            }
        #Replace setChairPinNum    
            elsif ($line =~ m[\"\>setChairPinNum\<\/chairPin\>]) {
                $line =~ s/setChairPinNum/$args{-usr_setChairPinNum}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setChairPinNum: $args{-usr_setChairPinNum} \n");
            }
        #Replace setEntryExitIndication     
            elsif ($line =~ m[\"\>setEntryExitIndication\<\/entryExitIndication\>]) {
                $line =~ s/setEntryExitIndication/$args{-usr_setEntryExitIndication}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setEntryExitIndication: $args{-usr_setEntryExitIndication} \n");
            }
        #Replace setFastStartTorF    
            elsif ($line =~ m[\<fastStart xsi\:type\=\"xsd\:boolean\"\>setFastStartTorF\<\/fastStart\>]) {
                $line =~ s/setFastStartTorF/$args{-usr_setFastStartTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setFastStartTorF: $args{-usr_setFastStartTorF} \n");
            }
        #Replace setImenableTorF    
            elsif ($line =~ m[\<imEnabled xsi\:type\=\"xsd\:boolean\"\>setImenableTorF\<\/imEnabled\>]) {
                $line =~ s/setImenableTorF/$args{-usr_setImenableTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setImenableTorF: $args{-usr_setImenableTorF} \n");
            }
        #Replace setPremConfTorF    
            elsif ($line =~ m[\<premConf xsi\:type\=\"xsd\:boolean\"\>setPremConfTorF\<\/premConf\>]) {
                $line =~ s/setPremConfTorF/$args{-usr_setPremConfTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setPremConfTorF: $args{-usr_setPremConfTorF} \n");
            }
        #Replace setPublicPinNum    
            elsif ($line =~ m[\"\>setPublicPinNum\<\/publicPin\>]) {
                $line =~ s/setPublicPinNum/$args{-usr_setPublicPinNum}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setPublicPinNum: $args{-usr_setPublicPinNum} \n");
            }
        #Replace setUserStateTorF    
            elsif ($line =~ m[\<userState xsi\:type\=\"xsd\:boolean\"\>setUserStateTorF\<\/userState\>]) {
                $line =~ s/setUserStateTorF/$args{-usr_setUserStateTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setUserStateTorF: $args{-usr_setUserStateTorF} \n");
            }
        #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }            
        }
        elsif ($xmlfile =~ /removeConfigMeetMeConfForUser|setDenyAllIncomingCalls|setDenyAllOutGoingCalls|removeAllServicesFromUser/i)
        {
            foreach ('-usr_users') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace users will be added services
            if ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }            
        }
        elsif ($xmlfile =~ /removeDenyAllIncomingCalls|removeDenyAllOutgoingCalls/i)
        {
            unless ($args{-usr_users}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_user
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setConfigProfilePresenceServiceForUser/i)
        {
            foreach ('-usr_users', '-usr_numEnhancedAuthorization', '-usr_numInactivityTimer', '-usr_setReportInactiveTorF', '-usr_setReportOnPhoneTorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace numEnhancedAuthorization 
            if ($line =~ m[\<enhancedAuthorization xsi\:type\=\"xsd\:int\"\>numEnhancedAuthorization\<\/enhancedAuthorization\>]) {
                $line =~ s/numEnhancedAuthorization/$args{-usr_numEnhancedAuthorization}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace numEnhancedAuthorization: $args{-usr_numEnhancedAuthorization} \n");
            }
        #Replace numInactivityTimer 
            elsif ($line =~ m[\<inactivityTimer xsi\:type\=\"xsd\:int\"\>numInactivityTimer\<\/inactivityTimer\>]) {
                $line =~ s/numInactivityTimer/$args{-usr_numInactivityTimer}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace numInactivityTimer: $args{-usr_numInactivityTimer} \n");
            }
        #Replace setReportInactiveTorF 
            elsif ($line =~ m[\<reportInactive xsi\:type\=\"xsd\:boolean\"\>setReportInactiveTorF\<\/reportInactive\>]) {
                $line =~ s/setReportInactiveTorF/$args{-usr_setReportInactiveTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setReportInactiveTorF: $args{-usr_setReportInactiveTorF} \n");
            }
        #Replace setReportOnPhoneTorF 
            elsif ($line =~ m[\<reportOnPhone xsi\:type\=\"xsd:boolean\"\>setReportOnPhoneTorF\<\/reportOnPhone\>]) {
                $line =~ s/setReportOnPhoneTorF/$args{-usr_setReportOnPhoneTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setReportOnPhoneTorF: $args{-usr_setReportOnPhoneTorF} \n");
            }
        #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }            
        }
        elsif ($xmlfile =~ /setSLADataForUser/i)
        {
            foreach ('-usr_users', '-usr_setActiveTorF', '-usr_setBridgingAllowedTorF', '-usr_setPrivateHoldAllowedTorF', '-usr_SLATypeName', '-usr_SLATypeLongName', '-usr_setWarningToneActiveTorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace setActiveTorF 
            if ($line =~ m[\<active xsi\:type\=\"xsd\:boolean\"\>setActiveTorF\<\/active\>]) {
                $line =~ s/setActiveTorF/$args{-usr_setActiveTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setActiveTorF: $args{-usr_setActiveTorF} \n");
            }
        #Replace setBridgingAllowedTorF 
            elsif ($line =~ m[\<bridgingAllowed xsi\:type\=\"xsd\:boolean\"\>setBridgingAllowedTorF\<\/bridgingAllowed\>]) {
                $line =~ s/setBridgingAllowedTorF/$args{-usr_setBridgingAllowedTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setBridgingAllowedTorF: $args{-usr_setBridgingAllowedTorF} \n");
            }
        #Replace setPrivateHoldAllowedTorF 
            elsif ($line =~ m[\<privateHoldAllowed xsi\:type\=\"xsd\:boolean\"\>setPrivateHoldAllowedTorF\<\/privateHoldAllowed\>]) {
                $line =~ s/setPrivateHoldAllowedTorF/$args{-usr_setPrivateHoldAllowedTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setPrivateHoldAllowedTorF: $args{-usr_setPrivateHoldAllowedTorF} \n");
            }
        #Replace SLATypeName
            elsif ($line =~ m[\<name xsi\:type\=\"soapenc\:string\"\>SLATypeName\<\/name\>]) {
                $line =~ s/SLATypeName/$args{-usr_SLATypeName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace SLATypeName: $args{-usr_SLATypeName} \n");
            }
        #Replace SLATypeLongName
            elsif ($line =~ m[\<longName xsi\:type\=\"soapenc\:string\"\>SLATypeLongName\<\/longName\>]) {
                $line =~ s/SLATypeLongName/$args{-usr_SLATypeLongName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace SLATypeLongName: $args{-usr_SLATypeLongName} \n");
            }
        #Replace setWarningToneActiveTorF
            elsif ($line =~ m[\<warningToneActive xsi\:type\=\"xsd\:boolean\"\>setWarningToneActiveTorF\<\/warningToneActive\>]) {
                $line =~ s/setWarningToneActiveTorF/$args{-usr_setWarningToneActiveTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setWarningToneActiveTorF: $args{-usr_setWarningToneActiveTorF} \n");
            }
        #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }            
        }
        elsif ($xmlfile =~ /addSLASecondaryUser/i)
        {
            foreach ('-usr_dnPrimary', '-usr_dnSecondary') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace dnPrimary
            if ($line =~ m[\"\>dnPrimary\@domain\<\/name\>]) {
                $line =~ s/dnPrimary\@domain/$args{-usr_dnPrimary}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace dnPrimary: $args{-usr_dnPrimary} \n");
            }
        #Replace dnSecondary 
            elsif ($line =~ m[\"\>dnSecondary\@domain\<\/name\>]) {
                $line =~ s/dnSecondary\@domain/$args{-usr_dnSecondary}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace dnSecondary: $args{-usr_dnSecondary} \n");
            }
        }
        elsif ($xmlfile =~ /removeSlaData/i)
        {
            foreach ('-usr_dnPrimary') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace usr_dnPrimary
            if ($line =~ m[usr_dnPrimary]) {
                $line =~ s/usr_dnPrimary/$args{-usr_dnPrimary}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dnPrimary: $args{-usr_dnPrimary} \n");
            }
        }
        elsif ($xmlfile =~ /setUseProfileTIRServiceForUser/i)
        {
            foreach ('-usr_users', '-usr_callidPrivacyEnabled') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace callidPrivacyEnabled
            if ($line =~ m[\<callidPrivacyEnabled xsi\:type\=\"xsd\:boolean\"\>true\<\/callidPrivacyEnabled\>]) {
                $line =~ s/true/$args{-usr_callidPrivacyEnabled}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace callidPrivacyEnabled: $args{-usr_callidPrivacyEnabled} \n");
            }
        #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }            
        }
        elsif ($xmlfile =~ /setUseProfileNcwdServiceForUser/i)
        {
            foreach ('-usr_users', '-usr_setNcwdEnabledTorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace setNcwdEnabledTorF
            if ($line =~ m[\<ncwdEnabled xsi\:type\=\"xsd\:boolean\"\>setNcwdEnabledTorF\<\/ncwdEnabled\>]) {
                $line =~ s/setNcwdEnabledTorF/$args{-usr_setNcwdEnabledTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setNcwdEnabledTorF: $args{-usr_setNcwdEnabledTorF} \n");
            }
        #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }            
        }
        elsif ($xmlfile =~ /setAuthorizedCallingPartyIdForCallGrab/i)
        {
            foreach ('-usr_users', '-usr_setAuthorizedCallingPartyID') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace setAuthorizedCallingPartyID
            if ($line =~ m[\"\>setAuthorizedCallingPartyID\<\/name\>]) {
                $line =~ s/setAuthorizedCallingPartyID/$args{-usr_setAuthorizedCallingPartyID}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setAuthorizedCallingPartyID: $args{-usr_setAuthorizedCallingPartyID} \n");
            }
        #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }
        }
        elsif ($xmlfile =~ /setUseProfileCallParkForUser/i)
        {
            foreach ('-usr_users', '-usr_setAutoRetrieveEnabledBoolean', '-usr_setNumAutoRetrieveTimer') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace setAutoRetrieveEnabledBoolean
            if ($line =~ m[\<autoRetrieveEnabled xsi\:type\=\"xsd\:boolean\"\>setAutoRetrieveEnabledBoolean\<\/autoRetrieveEnabled\>]) {
                $line =~ s/setAutoRetrieveEnabledBoolean/$args{-usr_setAutoRetrieveEnabledBoolean}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setAutoRetrieveEnabledBoolean: $args{-usr_setAutoRetrieveEnabledBoolean} \n");
            }
        #Replace setNumAutoRetrieveTimer
            elsif ($line =~ m[\<autoRetrieveTimer xsi\:type\=\"xsd\:int\"\>setNumAutoRetrieveTimer\<\/autoRetrieveTimer\>]) {
                $line =~ s/setNumAutoRetrieveTimer/$args{-usr_setNumAutoRetrieveTimer}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace setNumAutoRetrieveTimer: $args{-usr_setNumAutoRetrieveTimer} \n");
            }
        #Replace users will be added services
            elsif ($line =~ m[dn\@domain]) {
                $line =~ s/dn\@domain/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace users: $args{-usr_users} \n");
            }            
        }
        elsif ($xmlfile =~ /addProfileSESM/i)
        {
            foreach ('-usr_UserName', '-usr_Domain', '-usr_Sesmprofile') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace users will be added new no1
            if ($line =~ m[usernameLine]) {
                $line =~ s/usernameLine/$args{-usr_UserName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace UserName: $args{-usr_UserName} \n");
            }
        #Replace domain of users
            elsif ($line =~ m[domain\=\"tma6\.automation\.com\"\;]) {
                $line =~ s/tma6\.automation\.com/$args{-usr_Domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace Domain: $args{-usr_Domain} \n");
            }
        #Replace profile SESM 
            elsif ($line =~ m[profile\=\"sesm1\_profile\"\;]) {
                $line =~ s/sesm1\_profile/$args{-usr_Sesmprofile}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace Sesmprofile: $args{-usr_Sesmprofile} \n");
            }
        }
        elsif ($xmlfile =~ /removeMultiUser/i)
        {
            foreach ('-usr_UserName', '-usr_Total_User', '-usr_Domain') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace users will be added new no1
            if ($line =~ m[userName\=\"8219941\"\;]) {
                $line =~ s/8219941/$args{-usr_UserName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace UserName: $args{-usr_UserName} \n");
            }
        #Replace total users removed
            elsif ($line =~ m[userNumber\=\"3\"\;]) {
                $line =~ s/3/$args{-usr_Total_User}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace Total_User: $args{-usr_Total_User} \n");
            }
        #Replace domain of users
            elsif ($line =~ m[domain\=\"tma6\.automation\.com\"\;]) {
                $line =~ s/tma6\.automation\.com/$args{-usr_Domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace Domain: $args{-usr_Domain} \n");
            }
        }
        elsif ($xmlfile =~ /setCPLServices/i)
        {
            foreach ('-usr_defRouteConvnoVMRing', '-usr_defRoutenoVMRing', '-usr_defRouteRing', '-usr_routeRing') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace defRouteConvnoVMRing
            if ($line =~ m[defRouteConvnoVMRing\=\"9\"\;]) {
                $line =~ s/9/$args{-usr_defRouteConvnoVMRing}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace defRouteConvnoVMRing: $args{-usr_defRouteConvnoVMRing} \n");
            }
        #Replace defRoutenoVMRing
            elsif ($line =~ m[defRoutenoVMRing\=\"10\"\;]) {
                $line =~ s/10/$args{-usr_defRoutenoVMRing}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace defRoutenoVMRing: $args{-usr_defRoutenoVMRing} \n");
            }
        #Replace defRouteRing
            elsif ($line =~ m[defRouteRing\=\"3\"\;]) {
                $line =~ s/3/$args{-usr_defRouteRing}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace defRouteRing: $args{-usr_defRouteRing} \n");
            }
        #Replace routeRing
            elsif ($line =~ m[routeRing\=\"5\"\;]) {
                $line =~ s/5/$args{-usr_routeRing}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace routeRing: $args{-usr_routeRing} \n");
            }
        }
        elsif ($xmlfile =~ /addHuntGroup/i)
        {
            foreach ('-usr_huntGroup_domain', '-usr_huntGroup_name', '-usr_hunt_alphaTag', '-usr_hunt_cfgdaOption','-usr_hunt_cfgdaTime', '-usr_hunt_cos', '-usr_hunt_disableCPL_TorF', '-usr_hunt_enableDirectHunting_TorF','-usr_hunt_groupType', '-usr_hunt_overflowOption') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace huntGroup_domain
            if ($line =~ m[huntGroup_domain]) {
                $line =~ s/huntGroup_domain/$args{-usr_huntGroup_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_domain: $args{-usr_huntGroup_domain} \n");
            }
        #Replace huntGroup_name
            elsif ($line =~ m[huntGroup_name]) {
                $line =~ s/huntGroup_name/$args{-usr_huntGroup_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_name: $args{-usr_huntGroup_name} \n");
            }
        #Replace hunt_alphaTag
            elsif ($line =~ m[hunt_alphaTag]) {
                $line =~ s/hunt_alphaTag/$args{-usr_hunt_alphaTag}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_alphaTag: $args{-usr_hunt_alphaTag} \n");
            }
        #Replace hunt_cfgdaDest
            elsif ($line =~ m[hunt_cfgdaDest]) {
                if ($args{-usr_hunt_cfgdaDest}) {
                $line =~ s/hunt_cfgdaDest/$args{-usr_hunt_cfgdaDest}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_cfgdaDest: $args{-usr_hunt_cfgdaDest} \n");
                } else {
                  $line =~ s/hunt_cfgdaDest//;
                  $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_cfgdaDest:Null \n");
                  } 
            }                  
        #Replace hunt_cfgdaOption
            elsif ($line =~ m[hunt_cfgdaOption]) {
                $line =~ s/hunt_cfgdaOption/$args{-usr_hunt_cfgdaOption}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_cfgdaOption: $args{-usr_hunt_cfgdaOption} \n");
            }
        #Replace hunt_cfgdaTime
            elsif ($line =~ m[hunt_cfgdaTime]) {
                $line =~ s/hunt_cfgdaTime/$args{-usr_hunt_cfgdaTime}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_cfgdaTime: $args{-usr_hunt_cfgdaTime} \n");
            }
        #Replace hunt_cos
            elsif ($line =~ m[hunt_cos]) {
                $line =~ s/hunt_cos/$args{-usr_hunt_cos}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_cos: $args{-usr_hunt_cos} \n");
            }
        #Replace hunt_disableCPL_TorF
            elsif ($line =~ m[hunt_disableCPL_TorF]) {
                $line =~ s/hunt_disableCPL_TorF/$args{-usr_hunt_disableCPL_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_disableCPL_TorF: $args{-usr_hunt_disableCPL_TorF} \n");
            }
        #Replace hunt_enableDirectHunting_TorF
            elsif ($line =~ m[hunt_enableDirectHunting_TorF]) {
                $line =~ s/hunt_enableDirectHunting_TorF/$args{-usr_hunt_enableDirectHunting_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_enableDirectHunting_TorF: $args{-usr_hunt_enableDirectHunting_TorF} \n");
            }
        #Replace hunt_groupType
            elsif ($line =~ m[hunt_groupType]) {
                $line =~ s/hunt_groupType/$args{-usr_hunt_groupType}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_groupType: $args{-usr_hunt_groupType} \n");
            }
        #Replace hunt_overflowDest
            elsif ($line =~ m[hunt_overflowDest]) {
                if ($args{-usr_hunt_overflowDest}) {
                $line =~ s/hunt_overflowDest/$args{-usr_hunt_overflowDest}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_overflowDest: $args{-usr_hunt_overflowDest} \n");
                } else {
                  $line =~ s/hunt_overflowDest//;
                  $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_overflowDest:Null \n");
                  } 
            }    
        #Replace hunt_overflowOption
            elsif ($line =~ m[hunt_overflowOption]) {
                $line =~ s/hunt_overflowOption/$args{-usr_hunt_overflowOption}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_overflowOption: $args{-usr_hunt_overflowOption} \n");
            }
        #Replace hunt_pilotDN_name
            elsif ($line =~ m[hunt_pilotDN_name]) {
                if ($args{-usr_hunt_pilotDN_name}) {
                $line =~ s/hunt_pilotDN_name/$args{-usr_hunt_pilotDN_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_pilotDN_name: $args{-usr_hunt_pilotDN_name} \n");
                } else {
                  $line =~ s/hunt_pilotDN_name//;
                  $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_pilotDN_name:Null \n");
                  } 
            }    
        #Replace hunt_aliases
            elsif ($line =~ m[hunt_aliases]) {
                if ($args{-usr_hunt_aliases}) {
                $line =~ s/hunt_aliases/$args{-usr_hunt_aliases}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_aliases: $args{-usr_hunt_aliases} \n");
                } else {
                  $line =~ s/hunt_aliases//;
                  $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_aliases:Null \n");
                  } 
            }    
        #Replace hunt_dirNumbers
            elsif ($line =~ m[hunt_dirNumbers]) {
                if ($args{-usr_hunt_dirNumbers}) {
                $line =~ s/hunt_dirNumbers/$args{-usr_hunt_dirNumbers}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_dirNumbers: $args{-usr_hunt_dirNumbers} \n");
                } else {
                  $line =~ s/hunt_dirNumbers//;
                  $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_dirNumbers:Null \n");
                  } 
            }    
        }
        elsif ($xmlfile =~ /addAdminToHuntGroup/i)
        {
            foreach ('-usr_huntGroup_domain', '-usr_huntGroup_name', '-usr_huntGroup_userAdmin') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace huntGroup_domain
            if ($line =~ m[huntGroup_domain]) {
                $line =~ s/huntGroup_domain/$args{-usr_huntGroup_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_domain: $args{-usr_huntGroup_domain} \n");
            }
        #Replace huntGroup_name
            elsif ($line =~ m[huntGroup_name]) {
                $line =~ s/huntGroup_name/$args{-usr_huntGroup_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_name: $args{-usr_huntGroup_name} \n");
            }
        #Replace huntGroup_userAdmin
            elsif ($line =~ m[huntGroup_userAdmin]) {
                $line =~ s/huntGroup_userAdmin/$args{-usr_huntGroup_userAdmin}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_userAdmin: $args{-usr_huntGroup_userAdmin} \n");
            }    
       }
       elsif ($xmlfile =~ /addAgentToHuntGroup/i)
        {
            foreach ('-usr_huntGroup_domain', '-usr_huntGroup_name', '-usr_huntGroup_userAgent', '-usr_hunt_Order','-usr_stopHuntTorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace huntGroup_domain
            if ($line =~ m[huntGroup_domain]) {
                $line =~ s/huntGroup_domain/$args{-usr_huntGroup_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_domain: $args{-usr_huntGroup_domain} \n");
            }
        #Replace huntGroup_name
            elsif ($line =~ m[huntGroup_name]) {
                $line =~ s/huntGroup_name/$args{-usr_huntGroup_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_name: $args{-usr_huntGroup_name} \n");
            }
        #Replace huntGroup_userAgent
            elsif ($line =~ m[huntGroup_userAgent]) {
                $line =~ s/huntGroup_userAgent/$args{-usr_huntGroup_userAgent}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_userAgent: $args{-usr_huntGroup_userAgent} \n");
            }
        #Replace hunt_Order
            elsif ($line =~ m[hunt_Order]) {
                $line =~ s/hunt_Order/$args{-usr_hunt_Order}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace hunt_Order: $args{-usr_hunt_Order} \n");
            }
        #Replace stopHuntTorF
            if ($line =~ m[stopHuntTorF]) {
                $line =~ s/stopHuntTorF/$args{-usr_stopHuntTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace stopHuntTorF: $args{-usr_stopHuntTorF} \n");
            }
        }
        elsif ($xmlfile =~ /setProfileForHuntGroup/i)
        {
            foreach ('-usr_huntGroup_domain', '-usr_huntGroup_name', '-usr_huntGroup_profileSESM') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace huntGroup_domain
            if ($line =~ m[huntGroup_domain]) {
                $line =~ s/huntGroup_domain/$args{-usr_huntGroup_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_domain: $args{-usr_huntGroup_domain} \n");
            }
        #Replace huntGroup_name
            elsif ($line =~ m[huntGroup_name]) {
                $line =~ s/huntGroup_name/$args{-usr_huntGroup_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_name: $args{-usr_huntGroup_name} \n");
            }
        #Replace huntGroup_profileSESM
            elsif ($line =~ m[huntGroup_profileSESM]) {
                $line =~ s/huntGroup_profileSESM/$args{-usr_huntGroup_profileSESM}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_profileSESM: $args{-usr_huntGroup_profileSESM} \n");
            }    
       }
       elsif ($xmlfile =~ /setHuntMusicFolder/i)
        {
            foreach ('-usr_huntGroup_domain', '-usr_huntGroup_name', '-usr_pool', '-usr_MOHFolder') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_huntGroup_domain
            if ($line =~ m[usr_huntGroup_domain]) {
                $line =~ s/usr_huntGroup_domain/$args{-usr_huntGroup_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_domain: $args{-usr_huntGroup_domain} \n");
            }
        #Replace usr_huntGroup_name
            elsif ($line =~ m[usr_huntGroup_name]) {
                $line =~ s/usr_huntGroup_name/$args{-usr_huntGroup_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_huntGroup_name: $args{-usr_huntGroup_name} \n");
            }
        #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} \n");
            }  
        #Replace usr_MOHFolder
            elsif ($line =~ m[usr_MOHFolder]) {
                $line =~ s/usr_MOHFolder/$args{-usr_MOHFolder}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_MOHFolder: $args{-usr_MOHFolder} \n");
            }
       }
       elsif ($xmlfile =~ /setHuntTreatmentFile/i)
        {
            foreach ('-usr_huntGroup_domain', '-usr_huntGroup_name', '-usr_pool', '-usr_treatment_reason', '-usr_treatment_file') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_huntGroup_domain
            if ($line =~ m[usr_huntGroup_domain]) {
                $line =~ s/usr_huntGroup_domain/$args{-usr_huntGroup_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_domain: $args{-usr_huntGroup_domain} \n");
            }
        #Replace usr_huntGroup_name
            elsif ($line =~ m[usr_huntGroup_name]) {
                $line =~ s/usr_huntGroup_name/$args{-usr_huntGroup_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_huntGroup_name: $args{-usr_huntGroup_name} \n");
            }
        #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} \n");
            }  
        #Replace usr_treatment_reason
            elsif ($line =~ m[usr_treatment_reason]) {
                $line =~ s/usr_treatment_reason/$args{-usr_treatment_reason}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_treatment_reason: $args{-usr_treatment_reason} \n");
            }
        #Replace usr_treatment_file
            elsif ($line =~ m[usr_treatment_file]) {
                $line =~ s/usr_treatment_file/$args{-usr_treatment_file}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_treatment_file: $args{-usr_treatment_file} \n");
            }
       }
       elsif ($xmlfile =~ /removeHuntGroup/i)
       {
            foreach ('-usr_huntGroup_domain', '-usr_huntGroup_name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace huntGroup_domain
            if ($line =~ m[huntGroup_domain]) {
                $line =~ s/huntGroup_domain/$args{-usr_huntGroup_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_domain: $args{-usr_huntGroup_domain} \n");
            }
        #Replace huntGroup_name
            elsif ($line =~ m[huntGroup_name]) {
                $line =~ s/huntGroup_name/$args{-usr_huntGroup_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace huntGroup_name: $args{-usr_huntGroup_name} \n");
            }
        } 
        elsif ($xmlfile =~ /removeCallScrFeatureXLA/i)
       {
            foreach ('-usr_ScrFeature_domain', '-usr_ScrFeature_name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace ScrFeature_domain
            if ($line =~ m[ScrFeature_domain]) {
                $line =~ s/ScrFeature_domain/$args{-usr_ScrFeature_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace ScrFeature_domain: $args{-usr_ScrFeature_domain} \n");
            }
        #Replace ScrFeature_name
            elsif ($line =~ m[ScrFeature_name]) {
                $line =~ s/ScrFeature_name/$args{-usr_ScrFeature_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace ScrFeature_name: $args{-usr_ScrFeature_name} \n");
            }
        }
        elsif ($xmlfile =~ /addCallScrFeatureXLA/i)
        {
            foreach ('-usr_ScrFeature_domain', '-usr_ScrFeature_name', '-usr_ScrFeature_fromDigits', '-usr_ScrFeature_maxDigits', '-usr_ScrFeature_minDigits', '-usr_ScrFeature_toDigits', '-usr_ScrFeature_callType') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace ScrFeature_domain
            if ($line =~ m[ScrFeature_domain]) {
                $line =~ s/ScrFeature_domain/$args{-usr_ScrFeature_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace ScrFeature_domain: $args{-usr_ScrFeature_domain} \n");
            }
        #Replace ScrFeature_name
            elsif ($line =~ m[ScrFeature_name]) {
                $line =~ s/ScrFeature_name/$args{-usr_ScrFeature_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace ScrFeature_name: $args{-usr_ScrFeature_name} \n");
            }
        #Replace ScrFeature_fromDigits
            elsif ($line =~ m[ScrFeature_fromDigits]) {
                $line =~ s/ScrFeature_fromDigits/$args{-usr_ScrFeature_fromDigits}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace ScrFeature_fromDigits: $args{-usr_ScrFeature_fromDigits} \n");
            }
        #Replace ScrFeature_maxDigits
            elsif ($line =~ m[ScrFeature_maxDigits]) {
                $line =~ s/ScrFeature_maxDigits/$args{-usr_ScrFeature_maxDigits}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace ScrFeature_maxDigits: $args{-usr_ScrFeature_maxDigits} \n");
            }
        #Replace ScrFeature_minDigits
            if ($line =~ m[ScrFeature_minDigits]) {
                $line =~ s/ScrFeature_minDigits/$args{-usr_ScrFeature_minDigits}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace ScrFeature_minDigits: $args{-usr_ScrFeature_minDigits} \n");
            }
        #Replace ScrFeature_toDigits
            elsif ($line =~ m[ScrFeature_toDigits]) {
                $line =~ s/ScrFeature_toDigits/$args{-usr_ScrFeature_toDigits}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace ScrFeature_toDigits: $args{-usr_ScrFeature_toDigits} \n");
            }
        #Replace ScrFeature_callType
            elsif ($line =~ m[ScrFeature_callType]) {
                $line =~ s/ScrFeature_callType/$args{-usr_ScrFeature_callType}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace ScrFeature_callType: $args{-usr_ScrFeature_callType} \n");
            }
        }
        elsif ($xmlfile =~ /setSystemProfileCLIRSPForUser/i)
       {
            foreach ('-usr_users', '-usr_systemProfile_name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace systemProfile_name
            elsif ($line =~ m[systemProfile_name]) {
                $line =~ s/systemProfile_name/$args{-usr_systemProfile_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace systemProfile_name: $args{-usr_systemProfile_name} \n");
            }
        }

elsif ($xmlfile =~ /loginOMI-14.0/i)
        {
            foreach ('-user_password', '-user_id', '-user_session_response' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_password
                if ($line =~ m[user_password]) {
                    $line =~ s/user_password/$args{-user_password}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_password: $args{-user_password} \n");
                }

			#Replace user_id
                elsif ($line =~ m[user_id]) {
                    $line =~ s/user_id/$args{-user_id}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_id: $args{-user_id} \n");
                }

			#Replace user_session_response
                elsif ($line =~ m[user_session_response]) {
                    $line =~ s/user_session_response/$args{-user_session_response}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_session_response: $args{-user_session_response} \n");
                }
	}
        elsif ($xmlfile =~ /setUserProfileCLIRservice/i)
       {
            foreach ('-usr_users', '-usr_callidPrivacyEnabledTorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_callidPrivacyEnabledTorF
            elsif ($line =~ m[usr_callidPrivacyEnabledTorF]) {
                $line =~ s/usr_callidPrivacyEnabledTorF/$args{-usr_callidPrivacyEnabledTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callidPrivacyEnabledTorF: $args{-usr_callidPrivacyEnabledTorF} \n");
            }
        }
        elsif ($xmlfile =~ /setBrandingDomainData/i)
       {
            foreach ('-usr_Domain', '-usr_files', '-usr_playInDiffDomainsTorF', '-usr_playInDomainTorF', '-usr_poolname', '-usr_repeat') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_Domain
            if ($line =~ m[usr_Domain]) {
                $line =~ s/usr_Domain/$args{-usr_Domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Domain: $args{-usr_Domain} \n");
            }
        #Replace usr_files
            elsif ($line =~ m[usr_files]) {
                $line =~ s/usr_files/$args{-usr_files}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_files: $args{-usr_files} \n");
            }
        #Replace usr_playInDiffDomainsTorF
            if ($line =~ m[usr_playInDiffDomainsTorF]) {
                $line =~ s/usr_playInDiffDomainsTorF/$args{-usr_playInDiffDomainsTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_playInDiffDomainsTorF: $args{-usr_playInDiffDomainsTorF} \n");
            }
        #Replace usr_playInDomainTorF
            elsif ($line =~ m[usr_playInDomainTorF]) {
                $line =~ s/usr_playInDomainTorF/$args{-usr_playInDomainTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_playInDomainTorF: $args{-usr_playInDomainTorF} \n");
            }
        #Replace usr_poolname
            if ($line =~ m[usr_poolname]) {
                $line =~ s/usr_poolname/$args{-usr_poolname}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_poolname: $args{-usr_poolname} \n");
            }
        #Replace usr_repeat
            elsif ($line =~ m[usr_repeat]) {
                $line =~ s/usr_repeat/$args{-usr_repeat}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_repeat: $args{-usr_repeat} \n");
            }    
        }
        elsif ($xmlfile =~ /removeBrandingDomainData/i)
       {
            foreach ('-usr_Domain') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_Domain
            if ($line =~ m[usr_Domain]) {
                $line =~ s/usr_Domain/$args{-usr_Domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Domain: $args{-usr_Domain} \n");
            } 
        }
        elsif ($xmlfile =~ /removeTreatmentPoolFromDomain/i)
       {
            foreach ('-usr_Domain') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_Domain
            if ($line =~ m[usr_Domain]) {
                $line =~ s/usr_Domain/$args{-usr_Domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Domain: $args{-usr_Domain} \n");
            } 
        }
        elsif ($xmlfile =~ /setTreatmentPoolForDomain/i)
       {
            foreach ('-usr_Domain', '-usr_PooledRoute') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_Domain
            if ($line =~ m[usr_Domain]) {
                $line =~ s/usr_Domain/$args{-usr_Domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Domain: $args{-usr_Domain} \n");
            }
        #Replace usr_PooledRoute
            elsif ($line =~ m[usr_PooledRoute]) {
                $line =~ s/usr_PooledRoute/$args{-usr_PooledRoute}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PooledRoute: $args{-usr_PooledRoute} \n");
            }
        }
        elsif ($xmlfile =~ /clearUserlockout|sendUnRegister/i)
       {
            foreach ('-usr_user') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} \n");
            }
        }
        elsif ($xmlfile =~ /LoginOmi/i)
       {
            foreach ('-usr_mcp_password', '-usr_mcp_userID', '-usr_ats_user') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_mcp_password
            if ($line =~ m[usr_mcp_password]) {
                $line =~ s/usr_mcp_password/$args{-usr_mcp_password}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mcp_password: $args{-usr_mcp_password} \n");
            }
        #Replace usr_mcp_userID
            elsif ($line =~ m[usr_mcp_userID]) {
                $line =~ s/usr_mcp_userID/$args{-usr_mcp_userID}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mcp_userID: $args{-usr_mcp_userID} \n");
            }
        #Replace usr_ats_user
            elsif ($line =~ m[usr_ats_user]) {
                $line =~ s/usr_ats_user/$args{-usr_ats_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ats_user: $args{-usr_ats_user} \n");
            }
        }
        elsif ($xmlfile =~ /addAuthorizedMethod/i)
       {
            foreach ('-usr_mcp_userID', '-usr_mcp_sessionID', '-usr_authorize_method', '-usr_NE_longName', '-usr_NE_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_mcp_userID
            if ($line =~ m[usr_mcp_userID]) {
                $line =~ s/usr_mcp_userID/$args{-usr_mcp_userID}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mcp_userID: $args{-usr_mcp_userID} \n");
            }
        #Replace usr_mcp_sessionID
            elsif ($line =~ m[usr_mcp_sessionID]) {
                $line =~ s/usr_mcp_sessionID/$args{-usr_mcp_sessionID}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mcp_sessionID: $args{-usr_mcp_sessionID} \n");
            }
        #Replace usr_authorize_method
            elsif ($line =~ m[usr_authorize_method]) {
                $line =~ s/usr_authorize_method/$args{-usr_authorize_method}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_authorize_method: $args{-usr_authorize_method} \n");
            }
        #Replace usr_NE_longName
            elsif ($line =~ m[usr_NE_longName]) {
                $line =~ s/usr_NE_longName/$args{-usr_NE_longName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_NE_longName: $args{-usr_NE_longName} \n");
            }
        #Replace usr_NE_shortName
            elsif ($line =~ m[usr_NE_shortName]) {
                $line =~ s/usr_NE_shortName/$args{-usr_NE_shortName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_NE_shortName: $args{-usr_NE_shortName} \n");
            }
        }
        elsif ($xmlfile =~ /deleteAuthorizedMethod/i)
       {
            foreach ('-usr_mcp_userID', '-usr_mcp_sessionID', '-usr_authorize_method', '-usr_NE_longName', '-usr_NE_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_mcp_userID
            if ($line =~ m[usr_mcp_userID]) {
                $line =~ s/usr_mcp_userID/$args{-usr_mcp_userID}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mcp_userID: $args{-usr_mcp_userID} \n");
            }
        #Replace usr_mcp_sessionID
            elsif ($line =~ m[usr_mcp_sessionID]) {
                $line =~ s/usr_mcp_sessionID/$args{-usr_mcp_sessionID}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mcp_sessionID: $args{-usr_mcp_sessionID} \n");
            }
        #Replace usr_authorize_method
            elsif ($line =~ m[usr_authorize_method]) {
                $line =~ s/usr_authorize_method/$args{-usr_authorize_method}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_authorize_method: $args{-usr_authorize_method} \n");
            }
        #Replace usr_NE_longName
            elsif ($line =~ m[usr_NE_longName]) {
                $line =~ s/usr_NE_longName/$args{-usr_NE_longName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_NE_longName: $args{-usr_NE_longName} \n");
            }
        #Replace usr_NE_shortName
            elsif ($line =~ m[usr_NE_shortName]) {
                $line =~ s/usr_NE_shortName/$args{-usr_NE_shortName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_NE_shortName: $args{-usr_NE_shortName} \n");
            }
        }
        elsif ($xmlfile =~ /addUCDGroup/i)
       {
            foreach ('-usr_domain', '-usr_ucd_groupName', '-usr_agentAllowedToRouteTheCall_TorF', '-usr_users', '-usr_delayAnnouncement', '-usr_groupDisplayName', '-usr_maxCallQueueSize', '-usr_maxWaitTime', '-usr_groupIdentifier', '-usr_aliases', '-usr_dirNumbers', '-usr_presentationDuration', '-usr_queueClosureAction') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_ucd_groupName
            elsif ($line =~ m[usr_ucd_groupName]) {
                $line =~ s/usr_ucd_groupName/$args{-usr_ucd_groupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ucd_groupName: $args{-usr_ucd_groupName} \n");
            }
        #Replace usr_agentAllowedToRouteTheCall_TorF
            elsif ($line =~ m[usr_agentAllowedToRouteTheCall_TorF]) {
                $line =~ s/usr_agentAllowedToRouteTheCall_TorF/$args{-usr_agentAllowedToRouteTheCall_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_agentAllowedToRouteTheCall_TorF: $args{-usr_agentAllowedToRouteTheCall_TorF} \n");
            }
        #Replace usr_users
            elsif ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_delayAnnouncement
            elsif ($line =~ m[usr_delayAnnouncement]) {
                $line =~ s/usr_delayAnnouncement/$args{-usr_delayAnnouncement}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_delayAnnouncement: $args{-usr_delayAnnouncement} \n");
            }
        #Replace usr_groupDisplayName
            elsif ($line =~ m[usr_groupDisplayName]) {
                $line =~ s/usr_groupDisplayName/$args{-usr_groupDisplayName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_groupDisplayName: $args{-usr_groupDisplayName} \n");
            }
        #Replace usr_maxCallQueueSize
            elsif ($line =~ m[usr_maxCallQueueSize]) {
                $line =~ s/usr_maxCallQueueSize/$args{-usr_maxCallQueueSize}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxCallQueueSize: $args{-usr_maxCallQueueSize} \n");
            }
        #Replace usr_maxWaitTime
            elsif ($line =~ m[usr_maxWaitTime]) {
                $line =~ s/usr_maxWaitTime/$args{-usr_maxWaitTime}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxWaitTime: $args{-usr_maxWaitTime} \n");
            }
        #Replace usr_groupIdentifier
            elsif ($line =~ m[usr_groupIdentifier]) {
                $line =~ s/usr_groupIdentifier/$args{-usr_groupIdentifier}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_groupIdentifier: $args{-usr_groupIdentifier} \n");
            }
         #Replace usr_aliases
            elsif ($line =~ m[usr_aliases]) {
                $line =~ s/usr_aliases/$args{-usr_aliases}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_aliases: $args{-usr_aliases} \n");
            }
         #Replace usr_dirNumbers
            elsif ($line =~ m[usr_dirNumbers]) {
                $line =~ s/usr_dirNumbers/$args{-usr_dirNumbers}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dirNumbers: $args{-usr_dirNumbers} \n");
            }
         #Replace usr_presentationDuration
            elsif ($line =~ m[usr_presentationDuration]) {
                $line =~ s/usr_presentationDuration/$args{-usr_presentationDuration}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_presentationDuration: $args{-usr_presentationDuration} \n");
            }
         #Replace usr_queueClosureAction
            elsif ($line =~ m[usr_queueClosureAction]) {
                $line =~ s/usr_queueClosureAction/$args{-usr_queueClosureAction}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_queueClosureAction: $args{-usr_queueClosureAction} \n");
            }    
        }
        elsif ($xmlfile =~ /assignAdminToUCDGroup/i)
       {
            foreach ('-usr_domain', '-usr_ucd_groupName', '-usr_ucd_userAdmin') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_ucd_groupName
            elsif ($line =~ m[usr_ucd_groupName]) {
                $line =~ s/usr_ucd_groupName/$args{-usr_ucd_groupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ucd_groupName: $args{-usr_ucd_groupName} \n");
            }
        #Replace usr_ucd_userAdmin
            elsif ($line =~ m[usr_ucd_userAdmin]) {
                $line =~ s/usr_ucd_userAdmin/$args{-usr_ucd_userAdmin}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ucd_userAdmin: $args{-usr_ucd_userAdmin} \n");
            }
        }
        elsif ($xmlfile =~ /addAgentToUCDGroup/i)
       {
            foreach ('-usr_domain', '-usr_UCD_GroupName', '-usr_UCDAgent_x') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_UCD_GroupName
            elsif ($line =~ m[usr_UCD_GroupName]) {
                $line =~ s/usr_UCD_GroupName/$args{-usr_UCD_GroupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UCD_GroupName: $args{-usr_UCD_GroupName} \n");
            }
        #Replace usr_UCDAgent_x
            elsif ($line =~ m[usr_UCDAgent_x]) {
                $line =~ s/usr_UCDAgent_x/$args{-usr_UCDAgent_x}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UCDAgent_x: $args{-usr_UCDAgent_x} \n");
            }
        }
        elsif ($xmlfile =~ /removeUCDGroup/i)
       {
            foreach ('-usr_domain', '-usr_ucd_groupName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_ucd_groupName
            elsif ($line =~ m[usr_ucd_groupName]) {
                $line =~ s/usr_ucd_groupName/$args{-usr_ucd_groupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ucd_groupName: $args{-usr_ucd_groupName} \n");
            }
        }
        elsif ($xmlfile =~ /setProfileForUCDGroup/i)
       {
            foreach ('-usr_domain', '-usr_ucd_groupName', '-usr_sesmProfile') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_ucd_groupName
            elsif ($line =~ m[usr_ucd_groupName]) {
                $line =~ s/usr_ucd_groupName/$args{-usr_ucd_groupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ucd_groupName: $args{-usr_ucd_groupName} \n");
            }
        #Replace usr_sesmProfile
            elsif ($line =~ m[usr_sesmProfile]) {
                $line =~ s/usr_sesmProfile/$args{-usr_sesmProfile}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sesmProfile: $args{-usr_sesmProfile} \n");
            }
        }
        elsif ($xmlfile =~ /setUCDGroupAgentStatus/i)
       {
            foreach ('-usr_users', '-usr_ucdAgent_statusTorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_ucdAgent_statusTorF
            elsif ($line =~ m[usr_ucdAgent_statusTorF]) {
                $line =~ s/usr_ucdAgent_statusTorF/$args{-usr_ucdAgent_statusTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ucdAgent_statusTorF: $args{-usr_ucdAgent_statusTorF} \n");
            }
        }
        elsif ($xmlfile =~ /setUCDGroupQueueStatus/i)
       {
            foreach ('-usr_domain', '-usr_ucd_groupName', '-usr_ucdQueue_statusTorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_ucd_groupName
            elsif ($line =~ m[usr_ucd_groupName]) {
                $line =~ s/usr_ucd_groupName/$args{-usr_ucd_groupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ucd_groupName: $args{-usr_ucd_groupName} \n");
            }
        #Replace usr_ucdQueue_statusTorF
            elsif ($line =~ m[usr_ucdQueue_statusTorF]) {
                $line =~ s/usr_ucdQueue_statusTorF/$args{-usr_ucdQueue_statusTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ucdQueue_statusTorF: $args{-usr_ucdQueue_statusTorF} \n");
            }
        }
        elsif ($xmlfile =~ /setSystemProfilesVideoForUser/i)
       {
            foreach ('-usr_users', '-usr_video_profile') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_video_profile
            elsif ($line =~ m[usr_video_profile]) {
                $line =~ s/usr_video_profile/$args{-usr_video_profile}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_video_profile: $args{-usr_video_profile} \n");
            }
        }
        elsif ($xmlfile =~ /setMctDomainData/i)
       {
            foreach ('-usr_domain', '-usr_afterCallTraceEnabled_TorF', '-usr_autoTraceEnabled_TorF', '-usr_midCallTraceEnabled_TorF', '-usr_midcallFailure', '-usr_midcallSuccess') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_afterCallTraceEnabled_TorF
            elsif ($line =~ m[usr_afterCallTraceEnabled_TorF]) {
                $line =~ s/usr_afterCallTraceEnabled_TorF/$args{-usr_afterCallTraceEnabled_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_afterCallTraceEnabled_TorF: $args{-usr_afterCallTraceEnabled_TorF} \n");
            }
        #Replace usr_autoTraceEnabled_TorF
            if ($line =~ m[usr_autoTraceEnabled_TorF]) {
                $line =~ s/usr_autoTraceEnabled_TorF/$args{-usr_autoTraceEnabled_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_autoTraceEnabled_TorF: $args{-usr_autoTraceEnabled_TorF} \n");
            }
        #Replace usr_midCallTraceEnabled_TorF
            elsif ($line =~ m[usr_midCallTraceEnabled_TorF]) {
                $line =~ s/usr_midCallTraceEnabled_TorF/$args{-usr_midCallTraceEnabled_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_midCallTraceEnabled_TorF: $args{-usr_midCallTraceEnabled_TorF} \n");
            }
        #Replace usr_midcallFailure
            if ($line =~ m[usr_midcallFailure]) {
                $line =~ s/usr_midcallFailure/$args{-usr_midcallFailure}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_midcallFailure: $args{-usr_midcallFailure} \n");
            }
        #Replace usr_midcallSuccess
            elsif ($line =~ m[usr_midcallSuccess]) {
                $line =~ s/usr_midcallSuccess/$args{-usr_midcallSuccess}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_midcallSuccess: $args{-usr_midcallSuccess} \n");
            }    
        }
        elsif ($xmlfile =~ /setMctUserData/i)
       {
            foreach ('-usr_users', '-usr_autoTrace_TorF', '-usr_mctCaller', '-usr_terminatingTrace_TorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_autoTrace_TorF
            elsif ($line =~ m[usr_autoTrace_TorF]) {
                $line =~ s/usr_autoTrace_TorF/$args{-usr_autoTrace_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_autoTrace_TorF: $args{-usr_autoTrace_TorF} \n");
            }
        #Replace usr_mctCaller
            if ($line =~ m[usr_mctCaller]) {
                $line =~ s/usr_mctCaller/$args{-usr_mctCaller}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mctCaller: $args{-usr_mctCaller} \n");
            }
        #Replace usr_terminatingTrace_TorF
            elsif ($line =~ m[usr_terminatingTrace_TorF]) {
                $line =~ s/usr_terminatingTrace_TorF/$args{-usr_terminatingTrace_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_terminatingTrace_TorF: $args{-usr_terminatingTrace_TorF} \n");
            }  
        }
        elsif ($xmlfile =~ /setMctSystemData/i)
       {
            foreach ('-usr_outgoingScreenedUsers') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_outgoingScreenedUsers
            if ($line =~ m[usr_outgoingScreenedUsers]) {
                $line =~ s/usr_outgoingScreenedUsers/$args{-usr_outgoingScreenedUsers}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_outgoingScreenedUsers: $args{-usr_outgoingScreenedUsers} \n");
            }
        }
        elsif ($xmlfile =~ /setDomainPool/i)
       {
            foreach ('-usr_domain', '-usr_crbt_pool') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_crbt_pool
            elsif ($line =~ m[usr_crbt_pool]) {
                $line =~ s/usr_crbt_pool/$args{-usr_crbt_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_crbt_pool: $args{-usr_crbt_pool} \n");
            } 
        }
        elsif ($xmlfile =~ /setSystemProfileServiceCrbtForUser/i)
       {
            foreach ('-usr_users', '-usr_systemProfile_Crbt') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_systemProfile_Crbt
            elsif ($line =~ m[usr_systemProfile_Crbt]) {
                $line =~ s/usr_systemProfile_Crbt/$args{-usr_systemProfile_Crbt}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_systemProfile_Crbt: $args{-usr_systemProfile_Crbt} \n");
            } 
        }
        elsif ($xmlfile =~ /setCFVRouteBusy/i)
       {
            foreach ('-usr_users', '-usr_ActiveTorF', '-usr_busyDestination', '-usr_busyEnabledtorF', '-usr_numOfRings', '-usr_sentToVoicemailTorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_ActiveTorF
            elsif ($line =~ m[usr_ActiveTorF]) {
                $line =~ s/usr_ActiveTorF/$args{-usr_ActiveTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ActiveTorF: $args{-usr_ActiveTorF} \n");
            }
        #Replace usr_busyDestination
            if ($line =~ m[usr_busyDestination]) {
                $line =~ s/usr_busyDestination/$args{-usr_busyDestination}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_busyDestination: $args{-usr_busyDestination} \n");
            }
        #Replace usr_busyEnabledtorF
            elsif ($line =~ m[usr_busyEnabledtorF]) {
                $line =~ s/usr_busyEnabledtorF/$args{-usr_busyEnabledtorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_busyEnabledtorF: $args{-usr_busyEnabledtorF} \n");
            }
        #Replace usr_numOfRings
            if ($line =~ m[usr_numOfRings]) {
                $line =~ s/usr_numOfRings/$args{-usr_numOfRings}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numOfRings: $args{-usr_numOfRings} \n");
            }
        #Replace usr_sentToVoicemailTorF
            elsif ($line =~ m[usr_sentToVoicemailTorF]) {
                $line =~ s/usr_sentToVoicemailTorF/$args{-usr_sentToVoicemailTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sentToVoicemailTorF: $args{-usr_sentToVoicemailTorF} \n");
            }            
        }
        elsif ($xmlfile =~ /setCFVRouteNoAnswer/i)
       {
            foreach ('-usr_users', '-usr_ActiveTorF', '-usr_noAnswerDestination', '-usr_noAnswerEnabledTorF', '-usr_numOfRings', '-usr_sentToVoicemailTorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_ActiveTorF
            elsif ($line =~ m[usr_ActiveTorF]) {
                $line =~ s/usr_ActiveTorF/$args{-usr_ActiveTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ActiveTorF: $args{-usr_ActiveTorF} \n");
            }
        #Replace usr_noAnswerDestination
            if ($line =~ m[usr_noAnswerDestination]) {
                $line =~ s/usr_noAnswerDestination/$args{-usr_noAnswerDestination}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_noAnswerDestination: $args{-usr_noAnswerDestination} \n");
            }
        #Replace usr_noAnswerEnabledTorF
            elsif ($line =~ m[usr_noAnswerEnabledTorF]) {
                $line =~ s/usr_noAnswerEnabledTorF/$args{-usr_noAnswerEnabledTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_noAnswerEnabledTorF: $args{-usr_noAnswerEnabledTorF} \n");
            }
        #Replace usr_numOfRings
            if ($line =~ m[usr_numOfRings]) {
                $line =~ s/usr_numOfRings/$args{-usr_numOfRings}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numOfRings: $args{-usr_numOfRings} \n");
            }
        #Replace usr_sentToVoicemailTorF
            elsif ($line =~ m[usr_sentToVoicemailTorF]) {
                $line =~ s/usr_sentToVoicemailTorF/$args{-usr_sentToVoicemailTorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sentToVoicemailTorF: $args{-usr_sentToVoicemailTorF} \n");
            }            
        }
        elsif ($xmlfile =~ /setCFVRouteUnreachable/i)
       {
            foreach ('-usr_user', '-usr_Active_ToF', '-usr_numOfRings', '-usr_sentToVoicemail_ToF', '-usr_unreachableDestination', '-usr_unreachableEnabled_ToF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        #Replace usr_Active_ToF
            elsif ($line =~ m[usr_Active_ToF]) {
                $line =~ s/usr_Active_ToF/$args{-usr_Active_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Active_ToF: $args{-usr_Active_ToF} in $xmlfile \n");
            }
        #Replace usr_sentToVoicemail_ToF
            if ($line =~ m[usr_sentToVoicemail_ToF]) {
                $line =~ s/usr_sentToVoicemail_ToF/$args{-usr_sentToVoicemail_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sentToVoicemail_ToF: $args{-usr_sentToVoicemail_ToF}  in $xmlfile \n");
            }
        #Replace usr_unreachableDestination
            elsif ($line =~ m[usr_unreachableDestination]) {
                $line =~ s/usr_unreachableDestination/$args{-usr_unreachableDestination}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_unreachableDestination: $args{-usr_unreachableDestination} in $xmlfile \n");
            }
        #Replace usr_numOfRings
            if ($line =~ m[usr_numOfRings]) {
                $line =~ s/usr_numOfRings/$args{-usr_numOfRings}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numOfRings: $args{-usr_numOfRings} in $xmlfile \n");
            }
        #Replace usr_unreachableEnabled_ToF
            elsif ($line =~ m[usr_unreachableEnabled_ToF]) {
                $line =~ s/usr_unreachableEnabled_ToF/$args{-usr_unreachableEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_unreachableEnabled_ToF: $args{-usr_unreachableEnabled_ToF} in $xmlfile \n");
            }            
        }
        elsif ($xmlfile =~ /addCPUGroup/i)
       {
            foreach ('-usr_domain', '-usr_CPU_GroupName', '-usr_allowActiveSubscriptions_TorF', '-usr_groupDisplayName', '-usr_maxCallQueueSize', '-usr_maxGroupSize', '-usr_pilotDN', '-usr_aliases', '-usr_dirNumbers', '-usr_locale', '-usr_timezone') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_CPU_GroupName
            elsif ($line =~ m[usr_CPU_GroupName]) {
                $line =~ s/usr_CPU_GroupName/$args{-usr_CPU_GroupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_CPU_GroupName: $args{-usr_CPU_GroupName} \n");
            }
        #Replace usr_allowActiveSubscriptions_TorF
            if ($line =~ m[usr_allowActiveSubscriptions_TorF]) {
                $line =~ s/usr_allowActiveSubscriptions_TorF/$args{-usr_allowActiveSubscriptions_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_allowActiveSubscriptions_TorF: $args{-usr_allowActiveSubscriptions_TorF} \n");
            }
        #Replace usr_groupDisplayName
            elsif ($line =~ m[usr_groupDisplayName]) {
                $line =~ s/usr_groupDisplayName/$args{-usr_groupDisplayName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_groupDisplayName: $args{-usr_groupDisplayName} \n");
            }  
        #Replace usr_maxCallQueueSize
            elsif ($line =~ m[usr_maxCallQueueSize]) {
                $line =~ s/usr_maxCallQueueSize/$args{-usr_maxCallQueueSize}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxCallQueueSize: $args{-usr_maxCallQueueSize} \n");
            }
        #Replace usr_maxGroupSize
            elsif ($line =~ m[usr_maxGroupSize]) {
                $line =~ s/usr_maxGroupSize/$args{-usr_maxGroupSize}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxGroupSize: $args{-usr_maxGroupSize} \n");
            }
        #Replace usr_pilotDN
            elsif ($line =~ m[usr_pilotDN]) {
                $line =~ s/usr_pilotDN/$args{-usr_pilotDN}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pilotDN: $args{-usr_pilotDN} \n");
            }
        #Replace usr_aliases
            elsif ($line =~ m[usr_aliases]) {
                $line =~ s/usr_aliases/$args{-usr_aliases}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_aliases: $args{-usr_aliases} \n");
            }  
        #Replace usr_dirNumbers
            elsif ($line =~ m[usr_dirNumbers]) {
                $line =~ s/usr_dirNumbers/$args{-usr_dirNumbers}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dirNumbers: $args{-usr_dirNumbers} \n");
            }
        #Replace usr_locale
            elsif ($line =~ m[usr_locale]) {
                $line =~ s/usr_locale/$args{-usr_locale}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_locale: $args{-usr_locale} \n");
            }
        #Replace usr_timezone
            elsif ($line =~ m[usr_timezone]) {
                $line =~ s/usr_timezone/$args{-usr_timezone}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_timezone: $args{-usr_timezone} \n");
            }            
        }
        elsif ($xmlfile =~ /addAgentToCPUGroup/i)
       {
            foreach ('-usr_domain', '-usr_CPU_GroupName', '-usr_CPUAgent_x') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_CPU_GroupName
            elsif ($line =~ m[usr_CPU_GroupName]) {
                $line =~ s/usr_CPU_GroupName/$args{-usr_CPU_GroupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_CPU_GroupName: $args{-usr_CPU_GroupName} \n");
            }
        #Replace usr_CPUAgent_x
            if ($line =~ m[usr_CPUAgent_x]) {
                $line =~ s/usr_CPUAgent_x/$args{-usr_CPUAgent_x}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_CPUAgent_x: $args{-usr_CPUAgent_x} \n");
            }        
        }
        elsif ($xmlfile =~ /setProfileForGroup/i)
       {
            foreach ('-usr_domain', '-usr_CPU_GroupName', '-usr_systemProfile') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_CPU_GroupName
            elsif ($line =~ m[usr_CPU_GroupName]) {
                $line =~ s/usr_CPU_GroupName/$args{-usr_CPU_GroupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_CPU_GroupName: $args{-usr_CPU_GroupName} \n");
            }
        #Replace usr_systemProfile
            if ($line =~ m[usr_systemProfile]) {
                $line =~ s/usr_systemProfile/$args{-usr_systemProfile}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_systemProfile: $args{-usr_systemProfile} \n");
            }        
        }
        elsif ($xmlfile =~ /removeCPUGroup/i)
       {
            foreach ('-usr_domain', '-usr_CPU_GroupName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_CPU_GroupName
            elsif ($line =~ m[usr_CPU_GroupName]) {
                $line =~ s/usr_CPU_GroupName/$args{-usr_CPU_GroupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_CPU_GroupName: $args{-usr_CPU_GroupName} \n");
            }      
        }
        elsif ($xmlfile =~ /setCFVRouteNotLogged/i)
       {
            foreach ('-usr_users', '-usr_isActive_TorF', '-usr_notLoggedInDestination', '-usr_notLoggedInEnabled_TorF', '-usr_numOfRings', '-usr_sentToVoicemail_TorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_isActive_TorF
            elsif ($line =~ m[usr_isActive_TorF]) {
                $line =~ s/usr_isActive_TorF/$args{-usr_isActive_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_isActive_TorF: $args{-usr_isActive_TorF} \n");
            }
        #Replace usr_notLoggedInDestination
            if ($line =~ m[usr_notLoggedInDestination]) {
                $line =~ s/usr_notLoggedInDestination/$args{-usr_notLoggedInDestination}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_notLoggedInDestination: $args{-usr_notLoggedInDestination} \n");
            }
        #Replace usr_notLoggedInEnabled_TorF
            if ($line =~ m[usr_notLoggedInEnabled_TorF]) {
                $line =~ s/usr_notLoggedInEnabled_TorF/$args{-usr_notLoggedInEnabled_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_notLoggedInEnabled_TorF: $args{-usr_notLoggedInEnabled_TorF} \n");
            }
        #Replace usr_numOfRings
            elsif ($line =~ m[usr_numOfRings]) {
                $line =~ s/usr_numOfRings/$args{-usr_numOfRings}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numOfRings: $args{-usr_numOfRings} \n");
            }
        #Replace usr_sentToVoicemail_TorF
            if ($line =~ m[usr_sentToVoicemail_TorF]) {
                $line =~ s/usr_sentToVoicemail_TorF/$args{-usr_sentToVoicemail_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sentToVoicemail_TorF: $args{-usr_sentToVoicemail_TorF} \n");
            }            
        }
        elsif ($xmlfile =~ /addSystemProfileMCR/i)
       {
            foreach ('-usr_MCRSystemProfile_name', '-usr_simultaneousCalls') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_MCRSystemProfile_name
            if ($line =~ m[usr_MCRSystemProfile_name]) {
                $line =~ s/usr_MCRSystemProfile_name/$args{-usr_MCRSystemProfile_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_MCRSystemProfile_name: $args{-usr_MCRSystemProfile_name} \n");
            }
        #Replace usr_simultaneousCalls
            elsif ($line =~ m[usr_simultaneousCalls]) {
                $line =~ s/usr_simultaneousCalls/$args{-usr_simultaneousCalls}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_simultaneousCalls: $args{-usr_simultaneousCalls} \n");
            }      
        }
        elsif ($xmlfile =~ /addSystemProfilesMCRForDomain/i)
       {
            foreach ('-usr_domain', '-usr_MCRSystemSP_Name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_MCRSystemSP_Name
            elsif ($line =~ m[usr_MCRSystemSP_Name]) {
                $line =~ s/usr_MCRSystemSP_Name/$args{-usr_MCRSystemSP_Name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_MCRSystemSP_Name: $args{-usr_MCRSystemSP_Name} \n");
            }      
        }
        elsif ($xmlfile =~ /removeSystemProfileMCR/i)
       {
            foreach ('-usr_MCRSystemSP_name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_MCRSystemSP_name
            if ($line =~ m[usr_MCRSystemSP_name]) {
                $line =~ s/usr_MCRSystemSP_name/$args{-usr_MCRSystemSP_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_MCRSystemSP_name: $args{-usr_MCRSystemSP_name} \n");
            }    
        }
        elsif ($xmlfile =~ /setSystemProfileMCRForUser/i)
       {
            foreach ('-usr_users', '-usr_MCRSystemSP_Name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_MCRSystemSP_Name
            elsif ($line =~ m[usr_MCRSystemSP_Name]) {
                $line =~ s/usr_MCRSystemSP_Name/$args{-usr_MCRSystemSP_Name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_MCRSystemSP_Name: $args{-usr_MCRSystemSP_Name} \n");
            }      
        }
        elsif ($xmlfile =~ /addTeenGroup/i)
       {
            foreach ('-usr_domain', '-usr_TeenGroup_Name', '-usr_userPrimary', '-usr_RingToneProfile', '-usr_userSubscribers') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_TeenGroup_Name
            elsif ($line =~ m[usr_TeenGroup_Name]) {
                $line =~ s/usr_TeenGroup_Name/$args{-usr_TeenGroup_Name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_TeenGroup_Name: $args{-usr_TeenGroup_Name} \n");
            }
        #Replace usr_userPrimary
            if ($line =~ m[usr_userPrimary]) {
                $line =~ s/usr_userPrimary/$args{-usr_userPrimary}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_userPrimary: $args{-usr_userPrimary} \n");
            }
        #Replace usr_RingToneProfile
            elsif ($line =~ m[usr_RingToneProfile]) {
                $line =~ s/usr_RingToneProfile/$args{-usr_RingToneProfile}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_RingToneProfile: $args{-usr_RingToneProfile} \n");
            }   
        #Replace usr_userSubscribers
            elsif ($line =~ m[usr_userSubscribers]) {
                $line =~ s/usr_userSubscribers/$args{-usr_userSubscribers}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_userSubscribers: $args{-usr_userSubscribers} \n");
            }            
        }
        elsif ($xmlfile =~ /removeTeenGroup/i)
       {
            foreach ('-usr_domain', '-usr_TeenGroup_Name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_TeenGroup_Name
            elsif ($line =~ m[usr_TeenGroup_Name]) {
                $line =~ s/usr_TeenGroup_Name/$args{-usr_TeenGroup_Name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_TeenGroup_Name: $args{-usr_TeenGroup_Name} \n");
            }      
        }
        elsif ($xmlfile =~ /setUCDTreatmentFile/i)
       {
            foreach ('-usr_domain', '-usr_GroupUCD_Name', '-usr_PooledRoute', '-usr_TrmtReason', '-usr_TrmtFile') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_GroupUCD_Name
            elsif ($line =~ m[usr_GroupUCD_Name]) {
                $line =~ s/usr_GroupUCD_Name/$args{-usr_GroupUCD_Name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_GroupUCD_Name: $args{-usr_GroupUCD_Name} \n");
            }
        #Replace usr_PooledRoute
            if ($line =~ m[usr_PooledRoute]) {
                $line =~ s/usr_PooledRoute/$args{-usr_PooledRoute}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PooledRoute: $args{-usr_PooledRoute} \n");
            }
        #Replace usr_TrmtReason
            elsif ($line =~ m[usr_TrmtReason]) {
                $line =~ s/usr_TrmtReason/$args{-usr_TrmtReason}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_TrmtReason: $args{-usr_TrmtReason} \n");
            }   
        #Replace usr_TrmtFile
            elsif ($line =~ m[usr_TrmtFile]) {
                $line =~ s/usr_TrmtFile/$args{-usr_TrmtFile}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_TrmtFile: $args{-usr_TrmtFile} \n");
            }            
        }
        elsif ($xmlfile =~ /setUCDMusicFolder/i)
       {
            foreach ('-usr_domain', '-usr_GroupUCD_Name', '-usr_PooledRoute', '-usr_MOHFolder') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_GroupUCD_Name
            elsif ($line =~ m[usr_GroupUCD_Name]) {
                $line =~ s/usr_GroupUCD_Name/$args{-usr_GroupUCD_Name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_GroupUCD_Name: $args{-usr_GroupUCD_Name} \n");
            }
        #Replace usr_PooledRoute
            if ($line =~ m[usr_PooledRoute]) {
                $line =~ s/usr_PooledRoute/$args{-usr_PooledRoute}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PooledRoute: $args{-usr_PooledRoute} \n");
            }
        #Replace usr_MOHFolder
            elsif ($line =~ m[usr_MOHFolder]) {
                $line =~ s/usr_MOHFolder/$args{-usr_MOHFolder}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_MOHFolder: $args{-usr_MOHFolder} \n");
            }              
        }
        elsif ($xmlfile =~ /addSystemProfileAccountCode/i)
       {
            foreach ('-usr_systemprofile_name', '-usr_accountCodes_name', '-usr_accountCodes_value', '-usr_conferencingExcluded_TorF', '-usr_exclusionList_DN', '-usr_forced_TorF', '-usr_verified_TorF', '-usr_voicemailExcluded_TorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_systemprofile_name
            if ($line =~ m[usr_systemprofile_name]) {
                $line =~ s/usr_systemprofile_name/$args{-usr_systemprofile_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_systemprofile_name: $args{-usr_systemprofile_name} \n");
            }
        #Replace usr_accountCodes_name
            elsif ($line =~ m[usr_accountCodes_name]) {
                $line =~ s/usr_accountCodes_name/$args{-usr_accountCodes_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_accountCodes_name: $args{-usr_accountCodes_name} \n");
            }
        #Replace usr_accountCodes_value
            if ($line =~ m[usr_accountCodes_value]) {
                $line =~ s/usr_accountCodes_value/$args{-usr_accountCodes_value}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_accountCodes_value: $args{-usr_accountCodes_value} \n");
            }
        #Replace usr_conferencingExcluded_TorF
            elsif ($line =~ m[usr_conferencingExcluded_TorF]) {
                $line =~ s/usr_conferencingExcluded_TorF/$args{-usr_conferencingExcluded_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_conferencingExcluded_TorF: $args{-usr_conferencingExcluded_TorF} \n");
            } 
          #Replace usr_exclusionList_DN
            if ($line =~ m[usr_exclusionList_DN]) {
                $line =~ s/usr_exclusionList_DN/$args{-usr_exclusionList_DN}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_exclusionList_DN: $args{-usr_exclusionList_DN} \n");
            }
        #Replace usr_forced_TorF
            elsif ($line =~ m[usr_forced_TorF]) {
                $line =~ s/usr_forced_TorF/$args{-usr_forced_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_forced_TorF: $args{-usr_forced_TorF} \n");
            }
        #Replace usr_verified_TorF
            if ($line =~ m[usr_verified_TorF]) {
                $line =~ s/usr_verified_TorF/$args{-usr_verified_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_verified_TorF: $args{-usr_verified_TorF} \n");
            }
        #Replace usr_voicemailExcluded_TorF
            elsif ($line =~ m[usr_voicemailExcluded_TorF]) {
                $line =~ s/usr_voicemailExcluded_TorF/$args{-usr_voicemailExcluded_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_voicemailExcluded_TorF: $args{-usr_voicemailExcluded_TorF} \n");
            } 
                    
        }
        elsif ($xmlfile =~ /addSystemProfilesAccountCodeForDomain|removeDomainFromSystemProfileAccountCode/i)
       {
            foreach ('-usr_domain', '-usr_systemprofile_name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_systemprofile_name
            elsif ($line =~ m[usr_systemprofile_name]) {
                $line =~ s/usr_systemprofile_name/$args{-usr_systemprofile_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_systemprofile_name: $args{-usr_systemprofile_name} \n");
            }             
        }
        elsif ($xmlfile =~ /addSystemProfileAccountCodeNonVerify/i)
       {
            foreach ('-usr_systemprofile_name','-usr_conferencingExcluded_TorF', '-usr_exclusionList_DN', '-usr_forced_TorF', '-usr_verified_TorF', '-usr_voicemailExcluded_TorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_systemprofile_name
            if ($line =~ m[usr_systemprofile_name]) {
                $line =~ s/usr_systemprofile_name/$args{-usr_systemprofile_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_systemprofile_name: $args{-usr_systemprofile_name} \n");
            }
        #Replace usr_conferencingExcluded_TorF
            elsif ($line =~ m[usr_conferencingExcluded_TorF]) {
                $line =~ s/usr_conferencingExcluded_TorF/$args{-usr_conferencingExcluded_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_conferencingExcluded_TorF: $args{-usr_conferencingExcluded_TorF} \n");
            } 
          #Replace usr_exclusionList_DN
            if ($line =~ m[usr_exclusionList_DN]) {
                $line =~ s/usr_exclusionList_DN/$args{-usr_exclusionList_DN}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_exclusionList_DN: $args{-usr_exclusionList_DN} \n");
            }
        #Replace usr_forced_TorF
            elsif ($line =~ m[usr_forced_TorF]) {
                $line =~ s/usr_forced_TorF/$args{-usr_forced_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_forced_TorF: $args{-usr_forced_TorF} \n");
            }
        #Replace usr_verified_TorF
            if ($line =~ m[usr_verified_TorF]) {
                $line =~ s/usr_verified_TorF/$args{-usr_verified_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_verified_TorF: $args{-usr_verified_TorF} \n");
            }
        #Replace usr_voicemailExcluded_TorF
            elsif ($line =~ m[usr_voicemailExcluded_TorF]) {
                $line =~ s/usr_voicemailExcluded_TorF/$args{-usr_voicemailExcluded_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_voicemailExcluded_TorF: $args{-usr_voicemailExcluded_TorF} \n");
            } 
                    
        }
        elsif ($xmlfile =~ /setUserAlias/i)
       {
            foreach ('-usr_users', '-usr_alias') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_alias
            elsif ($line =~ m[usr_alias]) {
                $line =~ s/usr_alias/$args{-usr_alias}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alias: $args{-usr_alias} \n");
            }             
        }
        elsif ($xmlfile =~ /setDomainCLI/i)
       {
            foreach ('-usr_domain', '-usr_dCLINumber','-usr_publicName', '-usr_publicNumber') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_dCLINumber
            elsif ($line =~ m[usr_dCLINumber]) {
                $line =~ s/usr_dCLINumber/$args{-usr_dCLINumber}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dCLINumber: $args{-usr_dCLINumber} \n");
            }
        #Replace usr_publicName
            elsif ($line =~ m[usr_publicName]) {
                $line =~ s/usr_publicName/$args{-usr_publicName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_publicName: $args{-usr_publicName} \n");
            }
        #Replace usr_publicNumber
            elsif ($line =~ m[usr_publicNumber]) {
                $line =~ s/usr_publicNumber/$args{-usr_publicNumber}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_publicNumber: $args{-usr_publicNumber} \n");
            }    
        }
        elsif ($xmlfile =~ /removeDomainCLI|removeDomainDataASAC/i)
       {
            foreach ('-usr_domain') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }   
        }
        elsif ($xmlfile =~ /addCUG/i)
       {
            foreach ('-usr_domain', '-usr_CUGGroupName','-usr_incomingCallBarringAllowed_TorF', '-usr_incomingGroupCommAllowed_TorF', '-usr_onNet_TorF', '-usr_outgoingCallBarringAllowed_TorF','-usr_outgoingGroupCommAllowed_TorF', '-usr_users') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_CUGGroupName
            elsif ($line =~ m[usr_CUGGroupName]) {
                $line =~ s/usr_CUGGroupName/$args{-usr_CUGGroupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_CUGGroupName: $args{-usr_CUGGroupName} \n");
            }
        #Replace usr_incomingCallBarringAllowed_TorF
            elsif ($line =~ m[usr_incomingCallBarringAllowed_TorF]) {
                $line =~ s/usr_incomingCallBarringAllowed_TorF/$args{-usr_incomingCallBarringAllowed_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_incomingCallBarringAllowed_TorF: $args{-usr_incomingCallBarringAllowed_TorF} \n");
            }
        #Replace usr_incomingGroupCommAllowed_TorF
            elsif ($line =~ m[usr_incomingGroupCommAllowed_TorF]) {
                $line =~ s/usr_incomingGroupCommAllowed_TorF/$args{-usr_incomingGroupCommAllowed_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_incomingGroupCommAllowed_TorF: $args{-usr_incomingGroupCommAllowed_TorF} \n");
            }
        #Replace usr_onNet_TorF
            elsif ($line =~ m[usr_onNet_TorF]) {
                $line =~ s/usr_onNet_TorF/$args{-usr_onNet_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_onNet_TorF: $args{-usr_onNet_TorF} \n");
            }
        #Replace usr_outgoingCallBarringAllowed_TorF
            elsif ($line =~ m[usr_outgoingCallBarringAllowed_TorF]) {
                $line =~ s/usr_outgoingCallBarringAllowed_TorF/$args{-usr_outgoingCallBarringAllowed_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_outgoingCallBarringAllowed_TorF: $args{-usr_outgoingCallBarringAllowed_TorF} \n");
            }
        #Replace usr_outgoingGroupCommAllowed_TorF
            elsif ($line =~ m[usr_outgoingGroupCommAllowed_TorF]) {
                $line =~ s/usr_outgoingGroupCommAllowed_TorF/$args{-usr_outgoingGroupCommAllowed_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_outgoingGroupCommAllowed_TorF: $args{-usr_outgoingGroupCommAllowed_TorF} \n");
            }
        #Replace usr_users
            elsif ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }    
        }


elsif ($xmlfile =~ /updateConfigParm-14.0/i)
        {
            foreach ('-user_omi_userID', '-user_omi_Version', '-user_omi_sessionID', '-user_omi_groupName', '-user_omi_parmName', '-user_omi_type', '-user_omi_value', '-user_longName', '-user_shortName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

                #Replace user_omi_userID
                if ($line =~ m[user_omi_userID]) {
                    $line =~ s/user_omi_userID/$args{-user_omi_userID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_omi_userID: $args{-user_omi_userID} \n");
                }

                #Replace user_omi_Version
                elsif ($line =~ m[user_omi_Version]) {
                    $line =~ s/user_omi_Version/$args{-user_omi_Version}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_omi_Version: $args{-user_omi_Version} \n");
                }

                #Replace user_omi_sessionID
                elsif ($line =~ m[user_omi_sessionID]) {
                    $line =~ s/user_omi_sessionID/$args{-user_omi_sessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_omi_sessionID: $args{-user_omi_sessionID} \n");
                }

                #Replace user_omi_groupName
                elsif ($line =~ m[user_omi_groupName]) {
                    $line =~ s/user_omi_groupName/$args{-user_omi_groupName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_omi_groupName: $args{-user_omi_groupName} \n");
                }

                #Replace user_omi_parmName
                elsif ($line =~ m[user_omi_parmName]) {
                    $line =~ s/user_omi_parmName/$args{-user_omi_parmName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_omi_parmName: $args{-user_omi_parmName} \n");
                }

                #Replace user_omi_type
                elsif ($line =~ m[user_omi_type]) {
                    $line =~ s/user_omi_type/$args{-user_omi_type}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_omi_type: $args{-user_omi_type} \n");
                }

                #Replace user_omi_value
                elsif ($line =~ m[user_omi_value]) {
                    $line =~ s/user_omi_value/$args{-user_omi_value}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_omi_value: $args{-user_omi_value} \n");
                }

                #Replace user_longName
                elsif ($line =~ m[user_longName]) {
                    $line =~ s/user_longName/$args{-user_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_longName: $args{-user_longName} \n");
                }

                #Replace user_shortName
                elsif ($line =~ m[user_shortName]) {
                    $line =~ s/user_shortName/$args{-user_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_shortName: $args{-user_shortName} \n");
                }

        }


        elsif ($xmlfile =~ /modifyCUGUser/i)
       {
            foreach ('-usr_domain', '-usr_CUGGroupName','-usr_users', '-usr_allowIncomingCallBarring', '-usr_allowIncomingGroupComm', '-usr_allowOutgoingCallBarring','-usr_allowOutgoingGroupComm') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_CUGGroupName
            elsif ($line =~ m[usr_CUGGroupName]) {
                $line =~ s/usr_CUGGroupName/$args{-usr_CUGGroupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_CUGGroupName: $args{-usr_CUGGroupName} \n");
            }
        #Replace usr_users
            elsif ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_allowIncomingCallBarring
            elsif ($line =~ m[usr_allowIncomingCallBarring]) {
                $line =~ s/usr_allowIncomingCallBarring/$args{-usr_allowIncomingCallBarring}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_allowIncomingCallBarring: $args{-usr_allowIncomingCallBarring} \n");
            }
        #Replace usr_allowIncomingGroupComm
            elsif ($line =~ m[usr_allowIncomingGroupComm]) {
                $line =~ s/usr_allowIncomingGroupComm/$args{-usr_allowIncomingGroupComm}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_allowIncomingGroupComm: $args{-usr_allowIncomingGroupComm} \n");
            }
        #Replace usr_allowOutgoingCallBarring
            elsif ($line =~ m[usr_allowOutgoingCallBarring]) {
                $line =~ s/usr_allowOutgoingCallBarring/$args{-usr_allowOutgoingCallBarring}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_allowOutgoingCallBarring: $args{-usr_allowOutgoingCallBarring} \n");
            }
        #Replace usr_allowOutgoingGroupComm
            elsif ($line =~ m[usr_allowOutgoingGroupComm]) {
                $line =~ s/usr_allowOutgoingGroupComm/$args{-usr_allowOutgoingGroupComm}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_allowOutgoingGroupComm: $args{-usr_allowOutgoingGroupComm} \n");
            }   
        }
        elsif ($xmlfile =~ /removeCUG/i)
       {
            foreach ('-usr_domain', '-usr_CUGGroupName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_CUGGroupName
            elsif ($line =~ m[usr_CUGGroupName]) {
                $line =~ s/usr_CUGGroupName/$args{-usr_CUGGroupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_CUGGroupName: $args{-usr_CUGGroupName} \n");
            }    
        }
        elsif ($xmlfile =~ /setDNDRoute/i)
       {
            foreach ('-usr_users', '-usr_isActive_TorF','-usr_rejectReason', '-usr_sentToVoicemail_TorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_isActive_TorF
            elsif ($line =~ m[usr_isActive_TorF]) {
                $line =~ s/usr_isActive_TorF/$args{-usr_isActive_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_isActive_TorF: $args{-usr_isActive_TorF} \n");
            }
        #Replace usr_rejectReason
            elsif ($line =~ m[usr_rejectReason]) {
                $line =~ s/usr_rejectReason/$args{-usr_rejectReason}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_rejectReason: $args{-usr_rejectReason} \n");
            }
        #Replace usr_sentToVoicemail_TorF
            elsif ($line =~ m[usr_sentToVoicemail_TorF]) {
                $line =~ s/usr_sentToVoicemail_TorF/$args{-usr_sentToVoicemail_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sentToVoicemail_TorF: $args{-usr_sentToVoicemail_TorF} \n");
            }  
        }
        elsif ($xmlfile =~ /addShortDialingCodeFeatureXLA/i)
       {
            foreach ('-usr_domain', '-usr_featureXLAName','-usr_prefix', '-usr_uri') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_featureXLAName
            elsif ($line =~ m[usr_featureXLAName]) {
                $line =~ s/usr_featureXLAName/$args{-usr_featureXLAName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_featureXLAName: $args{-usr_featureXLAName} \n");
            }
        #Replace usr_prefix
            if ($line =~ m[usr_prefix]) {
                $line =~ s/usr_prefix/$args{-usr_prefix}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_prefix: $args{-usr_prefix} \n");
            }
        #Replace usr_uri
            elsif ($line =~ m[usr_uri]) {
                $line =~ s/usr_uri/$args{-usr_uri}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_uri: $args{-usr_uri} \n");
            }    
        }
        elsif ($xmlfile =~ /removeShortDialingCodeFeatureXLA/i)
       {
            foreach ('-usr_domain', '-usr_featureXLAName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_featureXLAName
            elsif ($line =~ m[usr_featureXLAName]) {
                $line =~ s/usr_featureXLAName/$args{-usr_featureXLAName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_featureXLAName: $args{-usr_featureXLAName} \n");
            }   
        }
        elsif ($xmlfile =~ /updateConfigParm/i)
       {
            foreach ('-usr_UserID', '-usr_SessionID','-usr_groupName', '-usr_parmName', '-usr_type', '-usr_value','-usr_NE_longName', '-usr_NE_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_UserID
            if ($line =~ m[usr_UserID]) {
                $line =~ s/usr_UserID/$args{-usr_UserID}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
            }
        #Replace usr_SessionID
            elsif ($line =~ m[usr_SessionID]) {
                $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
            }
        #Replace usr_groupName
            elsif ($line =~ m[usr_groupName]) {
                $line =~ s/usr_groupName/$args{-usr_groupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_groupName: $args{-usr_groupName} \n");
            }
        #Replace usr_parmName
            elsif ($line =~ m[usr_parmName]) {
                $line =~ s/usr_parmName/$args{-usr_parmName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_parmName: $args{-usr_parmName} \n");
            }
        #Replace usr_type
            elsif ($line =~ m[usr_type]) {
                $line =~ s/usr_type/$args{-usr_type}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_type: $args{-usr_type} \n");
            }
        #Replace usr_value
            elsif ($line =~ m[usr_value]) {
                $line =~ s/usr_value/$args{-usr_value}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_value: $args{-usr_value} \n");
            }
        #Replace usr_NE_longName
            elsif ($line =~ m[usr_NE_longName]) {
                $line =~ s/usr_NE_longName/$args{-usr_NE_longName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_NE_longName: $args{-usr_NE_longName} \n");
            } 
        #Replace usr_NE_shortName
            elsif ($line =~ m[usr_NE_shortName]) {
                $line =~ s/usr_NE_shortName/$args{-usr_NE_shortName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_NE_shortName: $args{-usr_NE_shortName} \n");
            }            
        }
        elsif ($xmlfile =~ /restartNEInstance/i)
       {
            foreach ('-usr_UserID', '-usr_SessionID','-usr_NE_longName', '-usr_NE_shortName', '-usr_NE_Server_shortName','-usr_NE_Server_name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_UserID
            if ($line =~ m[usr_UserID]) {
                $line =~ s/usr_UserID/$args{-usr_UserID}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
            }
        #Replace usr_SessionID
            elsif ($line =~ m[usr_SessionID]) {
                $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
            }
        #Replace usr_NE_longName
            elsif ($line =~ m[usr_NE_longName]) {
                $line =~ s/usr_NE_longName/$args{-usr_NE_longName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_NE_longName: $args{-usr_NE_longName} \n");
            }
        #Replace usr_NE_shortName
            elsif ($line =~ m[usr_NE_shortName]) {
                $line =~ s/usr_NE_shortName/$args{-usr_NE_shortName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_NE_shortName: $args{-usr_NE_shortName} \n");
            }
        #Replace usr_NE_ServerID
            elsif ($line =~ m[usr_NE_ServerID]) {
                $line =~ s/usr_NE_ServerID/$args{-usr_NE_ServerID}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_NE_ServerID: $args{-usr_NE_ServerID} \n");
            }
        #Replace usr_NE_Server_shortName
            elsif ($line =~ m[usr_NE_Server_shortName]) {
                $line =~ s/usr_NE_Server_shortName/$args{-usr_NE_Server_shortName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_NE_Server_shortName: $args{-usr_NE_Server_shortName} \n");
            }
        #Replace usr_NE_Server_name
            elsif ($line =~ m[usr_NE_Server_name]) {
                $line =~ s/usr_NE_Server_name/$args{-usr_NE_Server_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_NE_Server_name: $args{-usr_NE_Server_name} \n");
            }           
        }
        elsif ($xmlfile =~ /setACRRoute/i)
       {
            foreach ('-usr_users', '-usr_isActive_TorF','-usr_rejectReason') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_isActive_TorF
            elsif ($line =~ m[usr_isActive_TorF]) {
                $line =~ s/usr_isActive_TorF/$args{-usr_isActive_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_isActive_TorF: $args{-usr_isActive_TorF} \n");
            }
        #Replace usr_rejectReason
            elsif ($line =~ m[usr_rejectReason]) {
                $line =~ s/usr_rejectReason/$args{-usr_rejectReason}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_rejectReason: $args{-usr_rejectReason} \n");
            }     
        }
        elsif ($xmlfile =~ /addCallActionRoute/i)
       {
            foreach ('-usr_users', '-usr_CallActionRoute_Name','-usr_active_TorF', '-usr_destinations', '-usr_numberofRings', '-usr_greetingName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_CallActionRoute_Name
            elsif ($line =~ m[usr_CallActionRoute_Name]) {
                $line =~ s/usr_CallActionRoute_Name/$args{-usr_CallActionRoute_Name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_CallActionRoute_Name: $args{-usr_CallActionRoute_Name} \n");
            }
        #Replace usr_active_TorF
            elsif ($line =~ m[usr_active_TorF]) {
                $line =~ s/usr_active_TorF/$args{-usr_active_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_active_TorF: $args{-usr_active_TorF} \n");
            }
        #Replace usr_destinations
            elsif ($line =~ m[usr_destinations]) {
                $line =~ s/usr_destinations/$args{-usr_destinations}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_destinations: $args{-usr_destinations} \n");
            }
        #Replace usr_numberofRings
            elsif ($line =~ m[usr_numberofRings]) {
                $line =~ s/usr_numberofRings/$args{-usr_numberofRings}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberofRings: $args{-usr_numberofRings} \n");
            }
        #Replace usr_greetingName
            elsif ($line =~ m[usr_greetingName]) {
                $line =~ s/usr_greetingName/$args{-usr_greetingName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_greetingName: $args{-usr_greetingName} \n");
            }           
        }
        elsif ($xmlfile =~ /setMOHPoolLocations/i)
       {
            foreach ('-usr_domain', '-usr_pool','-usr_location') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} \n");
            }
        #Replace usr_location
            elsif ($line =~ m[usr_location]) {
                $line =~ s/usr_location/$args{-usr_location}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_location: $args{-usr_location} \n");
            }        
        }
         elsif ($xmlfile =~ /setMusicOnHoldDomainPool|addMusicOnHoldFolder|removeMusicOnHoldFolder/i)
       {
            foreach ('-usr_domain', '-usr_MOHFolder', '-usr_pool') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile ");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_MOHFolder
            elsif ($line =~ m[usr_MOHFolder]) {
                $line =~ s/usr_MOHFolder/$args{-usr_MOHFolder}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_MOHFolder: $args{-usr_MOHFolder} \n");
            }    
        #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} \n");
            }        
        }
        elsif ($xmlfile =~ /removeTrmtPoolLocations|removeAdhocConferencePoolLocations|removeMOHPoolLocations|removeMeetMePoolLocations|removeCrbtPoolLocations/i)
       {
            foreach ('-usr_domain', '-usr_pool') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }   
        #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} \n");
            }        
        }
        elsif ($xmlfile =~ /setTrmtPoolLocations/i)
       {
            foreach ('-usr_domain', '-usr_pool','-usr_location') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} \n");
            }
        #Replace usr_location
            elsif ($line =~ m[usr_location]) {
                $line =~ s/usr_location/$args{-usr_location}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_location: $args{-usr_location} \n");
            }        
        }
        elsif ($xmlfile =~ /setAdhocConferencePoolLocations|setMeetMePoolLocations|setCrbtPoolLocations/i)
       {
            foreach ('-usr_domain', '-usr_pool','-usr_location') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} \n");
            }
        #Replace usr_location
            elsif ($line =~ m[usr_location]) {
                $line =~ s/usr_location/$args{-usr_location}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_location: $args{-usr_location} \n");
            }        
        }
       elsif ($xmlfile =~ /addPrimaryAssistants/i)
       {
             foreach ('-usr_user', '-usr_list_primAssistants') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} \n");
            }
        #Replace usr_list_primAssistants
            elsif ($line =~ m[usr_list_primAssistants]) {
                $line =~ s/usr_list_primAssistants/$args{-usr_list_primAssistants}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_primAssistants: $args{-usr_list_primAssistants} \n");
            }         
        }
       elsif ($xmlfile =~ /addAlternateAssistants/i)
       {
            foreach ('-usr_user', '-usr_list_altAssistants') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} \n");
            }
        #Replace usr_list_altAssistants
            elsif ($line =~ m[usr_list_altAssistants]) {
                $line =~ s/usr_list_altAssistants/$args{-usr_list_altAssistants}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_altAssistants: $args{-usr_list_altAssistants} \n");
            }       
        }
       elsif ($xmlfile =~ /setDefaultAssistantServicesRoute/i)
       {
            foreach ('-usr_user', '-usr_routeName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} \n");
            }
        #Replace usr_routeName
            elsif ($line =~ m[usr_routeName]) {
                $line =~ s/usr_routeName/$args{-usr_routeName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_routeName: $args{-usr_routeName} \n");
            }       
        }
        elsif ($xmlfile =~ /removeDefaultAssistantServicesRouteSetting/i)
       {
            foreach ('-usr_user') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} \n");
            }      
        }
        elsif ($xmlfile =~ /removeAssistants/i)
       {
            foreach ('-usr_user', '-usr_list_Assistants') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} \n");
            }
        #Replace usr_list_Assistants
            elsif ($line =~ m[usr_list_Assistants]) {
                $line =~ s/usr_list_Assistants/$args{-usr_list_Assistants}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_Assistants: $args{-usr_list_Assistants} \n");
            }       
        }
        elsif ($xmlfile =~ /modifyCallActionRoute/i)
       {
            foreach ('-usr_users', '-usr_CallActionRoute','-usr_active_TorF', '-usr_myclient', '-usr_other', '-usr_numberofRings', '-usr_greetingName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_CallActionRoute
            elsif ($line =~ m[usr_CallActionRoute]) {
                $line =~ s/usr_CallActionRoute/$args{-usr_CallActionRoute}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_CallActionRoute: $args{-usr_CallActionRoute} \n");
            }
        #Replace usr_active_TorF
            elsif ($line =~ m[usr_active_TorF]) {
                $line =~ s/usr_active_TorF/$args{-usr_active_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_active_TorF: $args{-usr_active_TorF} \n");
            }
        #Replace usr_myclient
            elsif ($line =~ m[usr_myclient]) {
                $line =~ s/usr_myclient/$args{-usr_myclient}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_myclient: $args{-usr_myclient} \n");
            }
        #Replace usr_other
            elsif ($line =~ m[usr_other]) {
                $line =~ s/usr_other/$args{-usr_other}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_other: $args{-usr_other} \n");
            }    
        #Replace usr_numberofRings
            elsif ($line =~ m[usr_numberofRings]) {
                $line =~ s/usr_numberofRings/$args{-usr_numberofRings}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberofRings: $args{-usr_numberofRings} \n");
            }
        #Replace usr_greetingName
            elsif ($line =~ m[usr_greetingName]) {
                $line =~ s/usr_greetingName/$args{-usr_greetingName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_greetingName: $args{-usr_greetingName} \n");
            }           
        }
        elsif ($xmlfile =~ /addDomainDataServiceAsac/i)
       {
            foreach ('-usr_domain', '-usr_asacAudioBudget','-usr_asacVideoBudget') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_asacAudioBudget
            elsif ($line =~ m[usr_asacAudioBudget]) {
                $line =~ s/usr_asacAudioBudget/$args{-usr_asacAudioBudget}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_asacAudioBudget: $args{-usr_asacAudioBudget} \n");
            }
        #Replace usr_asacVideoBudget
            elsif ($line =~ m[usr_asacVideoBudget]) {
                $line =~ s/usr_asacVideoBudget/$args{-usr_asacVideoBudget}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_asacVideoBudget: $args{-usr_asacVideoBudget} \n");
            }              
        }
        elsif ($xmlfile =~ /addSystemProfileMLPP/i)
        {
            foreach ('-usr_profileName', '-usr_audioDscpName', '-usr_diversionDN', 
                        '-usr_maxPriority', '-usr_namespaceName', '-usr_videoDscpName')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} \n");
            }
        #Replace usr_audioDscpName    
            elsif ($line =~ m[usr_audioDscpName]) {
                $line =~ s/usr_audioDscpName/$args{-usr_audioDscpName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_audioDscpName: $args{-usr_audioDscpName} \n");
            }
        #Replace usr_diversionDN
            elsif ($line =~ m[usr_diversionDN]) {
                $line =~ s/usr_diversionDN/$args{-usr_diversionDN}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_diversionDN: $args{-usr_diversionDN} \n");
            }
         #Replace usr_maxPriority
            elsif ($line =~ m[usr_maxPriority]) {
                $line =~ s/usr_maxPriority/$args{-usr_maxPriority}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxPriority: $args{-usr_maxPriority} \n");
            }
        #Replace usr_namespaceName
            elsif ($line =~ m[usr_namespaceName]) {
                $line =~ s/usr_namespaceName/$args{-usr_namespaceName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_namespaceName: $args{-usr_namespaceName} \n");
            }
        #Replace usr_videoDscpName
            elsif ($line =~ m[usr_videoDscpName]) {
                $line =~ s/usr_videoDscpName/$args{-usr_videoDscpName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_videoDscpName: $args{-usr_videoDscpName} \n");
            }
        }
        elsif ($xmlfile =~ /setDomainsForSystemProfileMLPP|removeDomainsFromSystemProfileMLPP/i)
        {
            foreach ('-usr_profileName', '-usr_domainNames')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_domainName
            elsif ($line =~ m[Input Domains]) {
                foreach (@{$args{-usr_domainNames}}) {
                    print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
         			print OUT "</multiRef>";
                    print OUT "\n";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Set domain: $_ in $xmlfile \n");
                }
                next; 
            }
        }
        elsif ($xmlfile =~ /setSystemProfileMLPPForUser/i)
        {
            foreach ('-usr_user', '-usr_profileName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} \n");
            }
        #Replace usr_profileName
            elsif ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} \n");
            }
        }
        elsif ($xmlfile =~ /removeSPMLPPFromUser/i)
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeSystemProfileMLPP/i)
        {
            unless ($args{-usr_profileName}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /StrNameAddMultipleUsers/i)
        {
            foreach ('-usr_userNameStr', '-usr_userPass', '-usr_total_user', '-usr_userNameInt_first', '-usr_domain', '-usr_serviceSet', '-usr_userType') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_userNameStr
            if ($line =~ m[usr_userNameStr]) {
                $line =~ s/usr_userNameStr/$args{-usr_userNameStr}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_userNameStr: $args{-usr_userNameStr} \n");
            }
        #Replace usr_userPass
            elsif ($line =~ m[usr_userPass]) {
                $line =~ s/usr_userPass/$args{-usr_userPass}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_userPass: $args{-usr_userPass} \n");
            }
        #Replace usr_total_user
            if ($line =~ m[usr_total_user]) {
                $line =~ s/usr_total_user/$args{-usr_total_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_total_user: $args{-usr_total_user} \n");
            }
        #Replace usr_userNameInt_first
            elsif ($line =~ m[usr_userNameInt_first]) {
                $line =~ s/usr_userNameInt_first/$args{-usr_userNameInt_first}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_userNameInt_first: $args{-usr_userNameInt_first} \n");
            }
        #Replace usr_domain
            if ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        #Replace usr_serviceSet
            elsif ($line =~ m[usr_serviceSet]) {
                $line =~ s/usr_serviceSet/$args{-usr_serviceSet}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_serviceSet: $args{-usr_serviceSet} \n");
            } 
        #Replace usr_userType
            elsif ($line =~ m[usr_userType]) {
                $line =~ s/usr_userType/$args{-usr_userType}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_userType: $args{-usr_userType} \n");
            }              
        }
        elsif ($xmlfile =~ /modifyUserWithServiceSet/i)
        {
            foreach ('-usr_user', '-usr_serviceSet') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} \n");
            }
        #Replace usr_serviceSet
            elsif ($line =~ m[usr_serviceSet]) {
                $line =~ s/usr_serviceSet/$args{-usr_serviceSet}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_serviceSet: $args{-usr_serviceSet} \n");
            }
        } 
        elsif ($xmlfile =~ /StrNameRemoveMultipleUser/i)
        {
            
            foreach ('-usr_userNameStr', '-usr_total_user', '-usr_userNameInt_first', '-usr_domain') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_userNameStr
            if ($line =~ m[usr_userNameStr]) {
                $line =~ s/usr_userNameStr/$args{-usr_userNameStr}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_userNameStr: $args{-usr_userNameStr} \n");
            }
        #Replace usr_total_user
            elsif ($line =~ m[usr_total_user]) {
                $line =~ s/usr_total_user/$args{-usr_total_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_total_user: $args{-usr_total_user} \n");
            }
        #Replace usr_userNameInt_first
            if ($line =~ m[usr_userNameInt_first]) {
                $line =~ s/usr_userNameInt_first/$args{-usr_userNameInt_first}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_userNameInt_first: $args{-usr_userNameInt_first} \n");
            }
        #Replace usr_domain
            elsif ($line =~ m[usr_domain]) {
                $line =~ s/usr_domain/$args{-usr_domain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
            }
        }
        elsif ($xmlfile =~ /setAliasForUser/i)
        {
            
            foreach ('-usr_users', '-usr_list_alias') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_list_alias
            elsif ($line =~ m[usr_list_alias]) {
                $line =~ s/usr_list_alias/$args{-usr_list_alias}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_alias: $args{-usr_list_alias} \n");
            }
        }
        elsif ($xmlfile =~ /setUserDirectoryNumber/i)
        {
            
            foreach ('-usr_users', '-usr_list_dn') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_list_dn
            elsif ($line =~ m[usr_list_dn]) {
                $line =~ s/usr_list_dn/$args{-usr_list_dn}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_dn: $args{-usr_list_dn} \n");
            }
        }
        elsif ($xmlfile =~ /addSingleUser14.0/i)
        {
            foreach ('-user_domain', '-user_password', '-user_name', '-user_email','-user_firstName',  '-user_lastName', '-user_status', '-user_timezone', '-user_type' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
            #Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }
            #Replace user_password
                elsif ($line =~ m[user_password]) {
                    $line =~ s/user_password/$args{-user_password}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_password: $args{-user_password} \n");
                }
            #Replace user_name
                elsif ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }
            #Replace user_cellPhone
                elsif ($line =~ m[user_cellPhone]) {
                    $line =~ s/user_cellPhone/$args{-user_cellPhone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cellPhone: $args{-user_cellPhone} \n");
                }
            #Replace user_email
                elsif ($line =~ m[user_email]) {
                    $line =~ s/user_email/$args{-user_email}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_email: $args{-user_email} \n");
                }
            #Replace user_fax
                elsif ($line =~ m[user_fax]) {
                    $line =~ s/user_fax/$args{-user_fax}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_fax: $args{-user_fax} \n");
                }
            #Replace user_firstName
                elsif ($line =~ m[user_firstName]) {
                    $line =~ s/user_firstName/$args{-user_firstName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace Timezone: $args{-user_firstName} \n");
                } 
            #Replace user_homeCountry
                elsif ($line =~ m[user_homeCountry]) {
                    $line =~ s/user_homeCountry/$args{-user_homeCountry}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_homeCountry: $args{-user_homeCountry} \n");
                }
            #Replace user_homeLanguage
                if ($line =~ m[user_homeLanguage]) {
                    $line =~ s/user_homeLanguage/$args{-user_homeLanguage}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_homeLanguage: $args{-user_homeLanguage} \n");
                }
            #Replace user_homePhone
                elsif ($line =~ m[user_homePhone]) {
                    $line =~ s/user_homePhone/$args{-user_homePhone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_homePhone: $args{-user_homePhone} \n");
                }
            #Replace user_lastName
                elsif ($line =~ m[user_lastName]) {
                    $line =~ s/user_lastName/$args{-user_lastName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_lastName: $args{-user_lastName} \n");
                }
            #Replace user_locale
                elsif ($line =~ m[user_locale]) {
                    $line =~ s/user_locale/$args{-user_locale}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_locale: $args{-user_locale} \n");
                }
            #Replace user_phone
                elsif ($line =~ m[user_phone]) {
                    $line =~ s/user_phone/$args{-user_officePhone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_phone: $args{-user_officePhone} \n");
                }
            #Replace user_pager
                elsif ($line =~ m[user_pager]) {
                    $line =~ s/user_pager/$args{-user_pager}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_pager: $args{-user_pager} \n");
                }
            #Replace user_picture
                elsif ($line =~ m[user_picture]) {
                    $line =~ s/user_picture/$args{-user_picture}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_picture: $args{-user_picture} \n");
                }    
            #Replace user_status
                if ($line =~ m[user_status]) {
                    $line =~ s/user_status/$args{-user_status}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_status: $args{-user_status} \n");
                }
            #Replace user_Reason
                elsif ($line =~ m[user_Reason]) {
                    $line =~ s/user_Reason/$args{-user_Reason}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_Reason: $args{-user_Reason} \n");
                }
            #Replace user_subDomain
                elsif ($line =~ m[user_subDomain]) {
                    $line =~ s/user_subDomain/$args{-user_subDomain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_subDomain: $args{-user_subDomain} \n");
                }
            #Replace user_timezone
                elsif ($line =~ m[user_timezone]) {
                    $line =~ s/user_timezone/$args{-user_timezone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_timezone: $args{-user_timezone} \n");
                }
            #Replace user_type
                elsif ($line =~ m[user_type]) {
                    $line =~ s/user_type/$args{-user_type}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_type: $args{-user_type} \n");
                }
        }
        elsif ($xmlfile =~ /modifySEQRoute|modifySIMRoute/i)
        {
            
            foreach ('-usr_users', '-usr_list_users', '-usr_numRing', '-usr_active_TorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_list_users
            elsif ($line =~ m[usr_list_users]) {
                $line =~ s/usr_list_users/$args{-usr_list_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_users: $args{-usr_list_users} \n");
            }
        #Replace usr_numRing
            elsif ($line =~ m[usr_numRing]) {
                $line =~ s/usr_numRing/$args{-usr_numRing}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numRing: $args{-usr_numRing} \n");
            }    
        #Replace usr_active_TorF
            elsif ($line =~ m[usr_active_TorF]) {
                $line =~ s/usr_active_TorF/$args{-usr_active_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_active_TorF: $args{-usr_active_TorF} \n");
            }     
        }
        elsif ($xmlfile =~ /setPresenceBaseRoute/i)
        {
            
            foreach ('-usr_users','-usr_destination', '-usr_Active_TorF', '-usr_numRing', '-usr_list_presenceStates', '-usr_sendToVoicemail_TorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
        #Replace usr_users
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
            }
        #Replace usr_destination
            if ($line =~ m[usr_destination]) {
                $line =~ s/usr_destination/$args{-usr_destination}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_destination: $args{-usr_destination} \n");
            }    
        #Replace usr_Active_TorF
            elsif ($line =~ m[usr_Active_TorF]) {
                $line =~ s/usr_Active_TorF/$args{-usr_Active_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Active_TorF: $args{-usr_Active_TorF} \n");
            }
        #Replace usr_numRing
            elsif ($line =~ m[usr_numRing]) {
                $line =~ s/usr_numRing/$args{-usr_numRing}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numRing: $args{-usr_numRing} \n");
            }    
        #Replace usr_list_presenceStates
            elsif ($line =~ m[usr_list_presenceStates]) {
                $line =~ s/usr_list_presenceStates/$args{-usr_list_presenceStates}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_presenceStates: $args{-usr_list_presenceStates} \n");
            } 
        #Replace usr_sendToVoicemail_TorF
            elsif ($line =~ m[usr_sendToVoicemail_TorF]) {
                $line =~ s/usr_sendToVoicemail_TorF/$args{-usr_sendToVoicemail_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sendToVoicemail_TorF: $args{-usr_sendToVoicemail_TorF} \n");
            }     
        }
        elsif ($xmlfile =~ /modifyDataAndServiceSetForUser/i)
        {
            foreach ('-usr_users', '-usr_name', '-usr_cellPhone','-usr_firstName',  '-usr_homeCountry', '-usr_homeLanguage', '-usr_homePhone', '-usr_lastName', '-usr_officePhone', '-usr_status', '-usr_timezone', '-usr_type', '-usr_serviceSet' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                }
            #Replace usr_name
                elsif ($line =~ m[usr_name]) {
                    $line =~ s/usr_name/$args{-usr_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_name: $args{-usr_name} \n");
                }
            #Replace usr_cellPhone
                elsif ($line =~ m[usr_cellPhone]) {
                    $line =~ s/usr_cellPhone/$args{-usr_cellPhone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_cellPhone: $args{-usr_cellPhone} \n");
                }
            #Replace usr_email
                elsif ($line =~ m[usr_email]) {
                    $line =~ s/usr_email/$args{-usr_email}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_email: $args{-usr_email} \n");
                }
            #Replace usr_fax
                elsif ($line =~ m[usr_fax]) {
                    $line =~ s/usr_fax/$args{-usr_fax}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_fax: $args{-usr_fax} \n");
                }
            #Replace usr_firstName
                elsif ($line =~ m[usr_firstName]) {
                    $line =~ s/usr_firstName/$args{-usr_firstName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_firstName: $args{-usr_firstName} \n");
                } 
            #Replace usr_homeCountry
                elsif ($line =~ m[usr_homeCountry]) {
                    $line =~ s/usr_homeCountry/$args{-usr_homeCountry}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_homeCountry: $args{-usr_homeCountry} \n");
                }
            #Replace usr_homeLanguage
                if ($line =~ m[usr_homeLanguage]) {
                    $line =~ s/usr_homeLanguage/$args{-usr_homeLanguage}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_homeLanguage: $args{-usr_homeLanguage} \n");
                }
            #Replace usr_homePhone
                elsif ($line =~ m[usr_homePhone]) {
                    $line =~ s/usr_homePhone/$args{-usr_homePhone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_homePhone: $args{-usr_homePhone} \n");
                }
            #Replace usr_lastName
                elsif ($line =~ m[usr_lastName]) {
                    $line =~ s/usr_lastName/$args{-usr_lastName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_lastName: $args{-usr_lastName} \n");
                }
            #Replace usr_locale
                elsif ($line =~ m[usr_locale]) {
                    $line =~ s/usr_locale/$args{-usr_locale}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_locale: $args{-usr_locale} \n");
                }
            #Replace usr_officePhone
                elsif ($line =~ m[usr_officePhone]) {
                    $line =~ s/usr_officePhone/$args{-usr_officePhone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_officePhone: $args{-usr_officePhone} \n");
                }
            #Replace usr_pager
                elsif ($line =~ m[usr_pager]) {
                    $line =~ s/usr_pager/$args{-usr_pager}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pager: $args{-usr_pager} \n");
                }
            #Replace usr_picture
                elsif ($line =~ m[usr_picture]) {
                    $line =~ s/usr_picture/$args{-usr_picture}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_picture: $args{-usr_picture} \n");
                }    
            #Replace usr_status
                if ($line =~ m[usr_status]) {
                    $line =~ s/usr_status/$args{-usr_status}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_status: $args{-usr_status} \n");
                }
            #Replace usr_reason
                elsif ($line =~ m[usr_reason]) {
                    $line =~ s/usr_reason/$args{-usr_reason}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_reason: $args{-usr_reason} \n");
                }
            #Replace usr_subDomainName
                elsif ($line =~ m[usr_subDomainName]) {
                    $line =~ s/usr_subDomainName/$args{-usr_subDomainName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_subDomainName: $args{-usr_subDomainName} \n");
                }
            #Replace usr_timezone
                elsif ($line =~ m[usr_timezone]) {
                    $line =~ s/usr_timezone/$args{-usr_timezone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_timezone: $args{-usr_timezone} \n");
                }
            #Replace usr_type
                elsif ($line =~ m[usr_type]) {
                    $line =~ s/usr_type/$args{-usr_type}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_type: $args{-usr_type} \n");
                }
            #Replace usr_serviceSet
                elsif ($line =~ m[usr_serviceSet]) {
                    $line =~ s/usr_serviceSet/$args{-usr_serviceSet}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_serviceSet: $args{-usr_serviceSet} \n");
                }     
        }
        elsif ($xmlfile =~ /addTimeBlockGroup/i)
        {
            foreach ('-usr_users', '-usr_timeBlockName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                }
            #Replace usr_timeBlockName
                elsif ($line =~ m[usr_timeBlockName]) {
                    $line =~ s/usr_timeBlockName/$args{-usr_timeBlockName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_timeBlockName: $args{-usr_timeBlockName} \n");
                }
            #Replace list days
                elsif ($line =~ m[usr_monday,usr_tuesday,usr_wednesday,usr_thursday,usr_friday,usr_saturday,usr_sunday]) {
                    $line =~ s/usr_monday,usr_tuesday,usr_wednesday,usr_thursday,usr_friday,usr_saturday,usr_sunday/$args{-usr_monday},$args{-usr_tuesday},$args{-usr_wednesday},$args{-usr_thursday},$args{-usr_friday},$args{-usr_saturday},$args{-usr_sunday}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace list days \n");
                }
            #Replace usr_list_time_start_mon
                elsif ($line =~ m[usr_list_time_start_mon]) {
                    $line =~ s/usr_list_time_start_mon/$args{-usr_list_time_start_mon}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_start_mon: $args{-usr_list_time_start_mon} \n");
                }
            #Replace usr_list_time_stop_mon
                elsif ($line =~ m[usr_list_time_stop_mon]) {
                    $line =~ s/usr_list_time_stop_mon/$args{-usr_list_time_stop_mon}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_stop_mon: $args{-usr_list_time_stop_mon} \n");
                }
            #Replace usr_list_time_start_tue
                elsif ($line =~ m[usr_list_time_start_tue]) {
                    $line =~ s/usr_list_time_start_tue/$args{-usr_list_time_start_tue}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_start_tue: $args{-usr_list_time_start_tue} \n");
                }
            #Replace usr_list_time_stop_tue
                elsif ($line =~ m[usr_list_time_stop_tue]) {
                    $line =~ s/usr_list_time_stop_tue/$args{-usr_list_time_stop_tue}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_stop_tue: $args{-usr_list_time_stop_tue} \n");
                }
            #Replace usr_list_time_start_wed
                elsif ($line =~ m[usr_list_time_start_wed]) {
                    $line =~ s/usr_list_time_start_wed/$args{-usr_list_time_start_wed}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_start_wed: $args{-usr_list_time_start_wed} \n");
                }    
            #Replace usr_list_time_stop_wed
                if ($line =~ m[usr_list_time_stop_wed]) {
                    $line =~ s/usr_list_time_stop_wed/$args{-usr_list_time_stop_wed}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_stop_wed: $args{-usr_list_time_stop_wed} \n");
                }
            #Replace usr_list_time_start_thu
                elsif ($line =~ m[usr_list_time_start_thu]) {
                    $line =~ s/usr_list_time_start_thu/$args{-usr_list_time_start_thu}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_start_thu: $args{-usr_list_time_start_thu} \n");
                }
            #Replace usr_list_time_stop_thu
                elsif ($line =~ m[usr_list_time_stop_thu]) {
                    $line =~ s/usr_list_time_stop_thu/$args{-usr_list_time_stop_thu}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_stop_thu: $args{-usr_list_time_stop_thu} \n");
                }
            #Replace usr_list_time_start_fri
                elsif ($line =~ m[usr_list_time_start_fri]) {
                    $line =~ s/usr_list_time_start_fri/$args{-usr_list_time_start_fri}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_start_fri: $args{-usr_list_time_start_fri} \n");
                }
            #Replace usr_list_time_stop_fri
                elsif ($line =~ m[usr_list_time_stop_fri]) {
                    $line =~ s/usr_list_time_stop_fri/$args{-usr_list_time_stop_fri}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_stop_fri: $args{-usr_list_time_stop_fri} \n");
                }
            #Replace usr_list_time_start_sat
                elsif ($line =~ m[usr_list_time_start_sat]) {
                    $line =~ s/usr_list_time_start_sat/$args{-usr_list_time_start_sat}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_start_sat: $args{-usr_list_time_start_sat} \n");
                } 
           #Replace usr_list_time_stop_sat
                elsif ($line =~ m[usr_list_time_stop_sat]) {
                    $line =~ s/usr_list_time_stop_sat/$args{-usr_list_time_stop_sat}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_stop_sat: $args{-usr_list_time_stop_sat} \n");
                }
            #Replace usr_list_time_start_sun
                elsif ($line =~ m[usr_list_time_start_sun]) {
                    $line =~ s/usr_list_time_start_sun/$args{-usr_list_time_start_sun}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_start_sun: $args{-usr_list_time_start_sun} \n");
                }
            #Replace usr_list_time_stop_sun
                elsif ($line =~ m[usr_list_time_stop_sun]) {
                    $line =~ s/usr_list_time_stop_sun/$args{-usr_list_time_stop_sun}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_time_stop_sun: $args{-usr_list_time_stop_sun} \n");
                }       
        }
        elsif ($xmlfile =~ /timeBlockAddCallRoute/i)
        {
            foreach ('-usr_users', '-usr_callAction_name', '-usr_active_TorF', '-usr_setTimeBlock_TorF', '-usr_list_dns', '-usr_numRing') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                }
            #Replace usr_callAction_name
                elsif ($line =~ m[usr_callAction_name]) {
                    $line =~ s/usr_callAction_name/$args{-usr_callAction_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callAction_name: $args{-usr_callAction_name} \n");
                }
            #Replace usr_active_TorF
                elsif ($line =~ m[usr_active_TorF]) {
                    $line =~ s/usr_active_TorF/$args{-usr_active_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_active_TorF: $args{-usr_active_TorF} \n");
                }
            #Replace usr_setTimeBlock_TorF
                elsif ($line =~ m[usr_setTimeBlock_TorF]) {
                    $line =~ s/usr_setTimeBlock_TorF/$args{-usr_setTimeBlock_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_setTimeBlock_TorF: $args{-usr_setTimeBlock_TorF} \n");
                }    
            #Replace usr_list_timeBlocks
                elsif ($line =~ m[usr_list_timeBlocks]) {
                    $line =~ s/usr_list_timeBlocks/$args{-usr_list_timeBlocks}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_timeBlocks: $args{-usr_list_timeBlocks} \n");
                }
            #Replace usr_list_dns
                elsif ($line =~ m[usr_list_dns]) {
                    $line =~ s/usr_list_dns/$args{-usr_list_dns}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_dns: $args{-usr_list_dns} \n");
                }
            #Replace usr_numRing
                elsif ($line =~ m[usr_numRing]) {
                    $line =~ s/usr_numRing/$args{-usr_numRing}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numRing: $args{-usr_numRing} \n");
                }    
        }
        elsif ($xmlfile =~ /addRejectActionRoute/i)
        {
            foreach ('-usr_users', '-usr_rejectRoute_name', '-usr_active_TorF', '-usr_call_TorF', '-usr_im_TorF', '-usr_rejectMessage') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                }
            #Replace usr_rejectRoute_name
                elsif ($line =~ m[usr_rejectRoute_name]) {
                    $line =~ s/usr_rejectRoute_name/$args{-usr_rejectRoute_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_rejectRoute_name: $args{-usr_rejectRoute_name} \n");
                }
            #Replace usr_active_TorF
                elsif ($line =~ m[usr_active_TorF]) {
                    $line =~ s/usr_active_TorF/$args{-usr_active_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_active_TorF: $args{-usr_active_TorF} \n");
                }
            #Replace usr_call_TorF
                elsif ($line =~ m[usr_call_TorF]) {
                    $line =~ s/usr_call_TorF/$args{-usr_call_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_call_TorF: $args{-usr_call_TorF} \n");
                }    
            #Replace usr_condition_TorF
                elsif ($line =~ m[usr_condition_TorF]) {
                    $line =~ s/usr_condition_TorF/$args{-usr_condition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_condition_TorF: $args{-usr_condition_TorF} \n");
                }    
            #Replace usr_anonymousCondition_TorF
                elsif ($line =~ m[usr_anonymousCondition_TorF]) {
                    $line =~ s/usr_anonymousCondition_TorF/$args{-usr_anonymousCondition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_anonymousCondition_TorF: $args{-usr_anonymousCondition_TorF} \n");
                }
            #Replace usr_pabConditionGb_TorF
                elsif ($line =~ m[usr_pabConditionGb_TorF]) {
                    $line =~ s/usr_pabConditionGb_TorF/$args{-usr_pabConditionGb_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pabConditionGb_TorF: $args{-usr_pabConditionGb_TorF} \n");
                }
            #Replace usr_list_pabConditionGb
                elsif ($line =~ m[usr_list_pabConditionGb]) {
                    $line =~ s/usr_list_pabConditionGb/$args{-usr_list_pabConditionGb}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_pabConditionGb: $args{-usr_list_pabConditionGb} \n");
                } 
            #Replace usr_genericCondition_TorF
                elsif ($line =~ m[usr_genericCondition_TorF]) {
                    $line =~ s/usr_genericCondition_TorF/$args{-usr_genericCondition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_genericCondition_TorF: $args{-usr_genericCondition_TorF} \n");
                } 
            #Replace usr_listgenericCondition
                elsif ($line =~ m[usr_listgenericCondition]) {
                    $line =~ s/usr_listgenericCondition/$args{-usr_listgenericCondition}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_listgenericCondition: $args{-usr_listgenericCondition} \n");
                }
            #Replace usr_pabCondition_TorF
                elsif ($line =~ m[usr_pabCondition_TorF]) {
                    $line =~ s/usr_pabCondition_TorF/$args{-usr_pabCondition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pabCondition_TorF: $args{-usr_pabCondition_TorF} \n");
                }
            #Replace usr_list_pabCondition
                elsif ($line =~ m[usr_list_pabCondition]) {
                    $line =~ s/usr_list_pabCondition/$args{-usr_list_pabCondition}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_pabCondition: $args{-usr_list_pabCondition} \n");
                } 
            #Replace usr_pabGroupCondition_TorF
                elsif ($line =~ m[usr_pabGroupCondition_TorF]) {
                    $line =~ s/usr_pabGroupCondition_TorF/$args{-usr_pabGroupCondition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pabGroupCondition_TorF: $args{-usr_pabGroupCondition_TorF} \n");
                }  
            #Replace usr_list_pabGroupCondition
                elsif ($line =~ m[usr_list_pabGroupCondition]) {
                    $line =~ s/usr_list_pabGroupCondition/$args{-usr_list_pabGroupCondition}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_pabGroupCondition: $args{-usr_list_pabGroupCondition} \n");
                }
            #Replace usr_presenceCondition_TorF
                elsif ($line =~ m[usr_presenceCondition_TorF]) {
                    $line =~ s/usr_presenceCondition_TorF/$args{-usr_presenceCondition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_presenceCondition_TorF: $args{-usr_presenceCondition_TorF} \n");
                }
            #Replace usr_list_presenceCondition
                elsif ($line =~ m[usr_list_presenceCondition]) {
                    $line =~ s/usr_list_presenceCondition/$args{-usr_list_presenceCondition}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_presenceCondition: $args{-usr_list_presenceCondition} \n");
                } 
            #Replace usr_timeOfDayCondition_TorF
                elsif ($line =~ m[usr_timeOfDayCondition_TorF]) {
                    $line =~ s/usr_timeOfDayCondition_TorF/$args{-usr_timeOfDayCondition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_timeOfDayCondition_TorF: $args{-usr_timeOfDayCondition_TorF} \n");
                } 
             #Replace usr_list_timeOfDayCondition
                if ($line =~ m[usr_list_timeOfDayCondition]) {
                    $line =~ s/usr_list_timeOfDayCondition/$args{-usr_list_timeOfDayCondition}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_timeOfDayCondition: $args{-usr_list_timeOfDayCondition} \n");
                }
            #Replace usr_exception_TorF
                elsif ($line =~ m[usr_exception_TorF]) {
                    $line =~ s/usr_exception_TorF/$args{-usr_exception_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_exception_TorF: $args{-usr_exception_TorF} \n");
                }
            #Replace usr_anonymousException_TorF
                elsif ($line =~ m[usr_anonymousException_TorF]) {
                    $line =~ s/usr_anonymousException_TorF/$args{-usr_anonymousException_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_anonymousException_TorF: $args{-usr_anonymousException_TorF} \n");
                }
            #Replace usr_pabExceptionGb_TorF
                elsif ($line =~ m[usr_pabExceptionGb_TorF]) {
                    $line =~ s/usr_pabExceptionGb_TorF/$args{-usr_pabExceptionGb_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pabExceptionGb_TorF: $args{-usr_pabExceptionGb_TorF} \n");
                }    
            #Replace usr_list_pabExceptionGb
                elsif ($line =~ m[usr_list_pabExceptionGb]) {
                    $line =~ s/usr_list_pabExceptionGb/$args{-usr_list_pabExceptionGb}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_pabExceptionGb: $args{-usr_list_pabExceptionGb} \n");
                }
            #Replace usr_genericException_TorF
                elsif ($line =~ m[usr_genericException_TorF]) {
                    $line =~ s/usr_genericException_TorF/$args{-usr_genericException_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_genericException_TorF: $args{-usr_genericException_TorF} \n");
                }
            #Replace usr_listgenericException
                elsif ($line =~ m[usr_listgenericException]) {
                    $line =~ s/usr_listgenericException/$args{-usr_listgenericException}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_listgenericException: $args{-usr_listgenericException} \n");
                } 
            #Replace usr_pabException_TorF
                elsif ($line =~ m[usr_pabException_TorF]) {
                    $line =~ s/usr_pabException_TorF/$args{-usr_pabException_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pabException_TorF: $args{-usr_pabException_TorF} \n");
                } 
            #Replace usr_list_pabException
                elsif ($line =~ m[usr_list_pabException]) {
                    $line =~ s/usr_list_pabException/$args{-usr_list_pabException}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_pabException: $args{-usr_list_pabException} \n");
                }
            #Replace usr_pabGroupException_TorF
                elsif ($line =~ m[usr_pabGroupException_TorF]) {
                    $line =~ s/usr_pabGroupException_TorF/$args{-usr_pabGroupException_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pabGroupException_TorF: $args{-usr_pabGroupException_TorF} \n");
                }
            #Replace usr_list_pabGroupException
                elsif ($line =~ m[usr_list_pabGroupException]) {
                    $line =~ s/usr_list_pabGroupException/$args{-usr_list_pabGroupException}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_pabGroupException: $args{-usr_list_pabGroupException} \n");
                } 
            #Replace usr_presenceException_TorF
                elsif ($line =~ m[usr_presenceException_TorF]) {
                    $line =~ s/usr_presenceException_TorF/$args{-usr_presenceException_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_presenceException_TorF: $args{-usr_presenceException_TorF} \n");
                }  
            #Replace usr_list_presenceException
                elsif ($line =~ m[usr_list_presenceException]) {
                    $line =~ s/usr_list_presenceException/$args{-usr_list_presenceException}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_presenceException: $args{-usr_list_presenceException} \n");
                }
            
            #Replace usr_im_TorF
                elsif ($line =~ m[usr_im_TorF]) {
                    $line =~ s/usr_im_TorF/$args{-usr_im_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_im_TorF: $args{-usr_im_TorF} \n");
                } 
            #Replace usr_rejectMessage
                elsif ($line =~ m[usr_rejectMessage]) {
                    $line =~ s/usr_rejectMessage/$args{-usr_rejectMessage}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_rejectMessage: $args{-usr_rejectMessage} \n");
                }    
        }
         elsif ($xmlfile =~ /addAddressBookEntry/i)
        {
            foreach ('-usr_users', '-usr_bookEntry_name', '-usr_buddy_TorF', '-usr_primaryContact') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                }
            #Replace usr_bookEntry_name
                elsif ($line =~ m[usr_bookEntry_name]) {
                    $line =~ s/usr_bookEntry_name/$args{-usr_bookEntry_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_bookEntry_name: $args{-usr_bookEntry_name} \n");
                }
            #Replace usr_buddy_TorF
                elsif ($line =~ m[usr_buddy_TorF]) {
                    $line =~ s/usr_buddy_TorF/$args{-usr_buddy_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_buddy_TorF: $args{-usr_buddy_TorF} \n");
                }
            #Replace usr_businessPhoneNumber
                elsif ($line =~ m[usr_businessPhoneNumber]) {
                    $line =~ s/usr_businessPhoneNumber/$args{-usr_businessPhoneNumber}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_businessPhoneNumber: $args{-usr_businessPhoneNumber} \n");
                }    
            #Replace usr_conferenceURL
                elsif ($line =~ m[usr_conferenceURL]) {
                    $line =~ s/usr_conferenceURL/$args{-usr_conferenceURL}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_conferenceURL: $args{-usr_conferenceURL} \n");
                }
            #Replace usr_emailAddress
                elsif ($line =~ m[usr_emailAddress]) {
                    $line =~ s/usr_emailAddress/$args{-usr_emailAddress}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_emailAddress: $args{-usr_emailAddress} \n");
                }
            #Replace usr_fax
                elsif ($line =~ m[usr_fax]) {
                    $line =~ s/usr_fax/$args{-usr_fax}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_fax: $args{-usr_fax} \n");
                } 
            #Replace usr_firstName
                elsif ($line =~ m[usr_firstName]) {
                    $line =~ s/usr_firstName/$args{-usr_firstName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_firstName: $args{-usr_firstName} \n");
                } 
            #Replace usr_group
                elsif ($line =~ m[usr_group]) {
                    $line =~ s/usr_group/$args{-usr_group}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_group: $args{-usr_group} \n");
                }
            #Replace usr_homePhoneNumber
                elsif ($line =~ m[usr_homePhoneNumber]) {
                    $line =~ s/usr_homePhoneNumber/$args{-usr_homePhoneNumber}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_homePhoneNumber: $args{-usr_homePhoneNumber} \n");
                }
            #Replace usr_lastName
                elsif ($line =~ m[usr_lastName]) {
                    $line =~ s/usr_lastName/$args{-usr_lastName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_lastName: $args{-usr_lastName} \n");
                } 
            #Replace usr_mobile
                elsif ($line =~ m[usr_mobile]) {
                    $line =~ s/usr_mobile/$args{-usr_mobile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mobile: $args{-usr_mobile} \n");
                }  
            #Replace usr_pager
                elsif ($line =~ m[usr_pager]) {
                    $line =~ s/usr_pager/$args{-usr_pager}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pager: $args{-usr_pager} \n");
                }
            #Replace usr_photoURL
                elsif ($line =~ m[usr_photoURL]) {
                    $line =~ s/usr_photoURL/$args{-usr_photoURL}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_photoURL: $args{-usr_photoURL} \n");
                }
            #Replace usr_lastName
                elsif ($line =~ m[usr_lastName]) {
                    $line =~ s/usr_lastName/$args{-usr_lastName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_lastName: $args{-usr_lastName} \n");
                } 
            #Replace usr_primaryContact
                elsif ($line =~ m[usr_primaryContact]) {
                    $line =~ s/usr_primaryContact/$args{-usr_primaryContact}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_primaryContact: $args{-usr_primaryContact} \n");
                }    
        }
        elsif ($xmlfile =~ /addAddressBookGroup/i)
        {
            foreach ('-usr_users', '-usr_addrBookGroup_name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                }
            #Replace usr_addrBookGroup_name
                elsif ($line =~ m[usr_addrBookGroup_name]) {
                    $line =~ s/usr_addrBookGroup_name/$args{-usr_addrBookGroup_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_addrBookGroup_name: $args{-usr_addrBookGroup_name} \n");
                }   
        }
        elsif ($xmlfile =~ /actionRouteFullMode/i)
        {
            foreach ('-usr_users', '-usr_routeName', '-usr_active_TorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                }
            #Replace usr_routeName
                elsif ($line =~ m[usr_routeName]) {
                    $line =~ s/usr_routeName/$args{-usr_routeName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_routeName: $args{-usr_routeName} \n");
                }
            #Replace usr_active_TorF
                elsif ($line =~ m[usr_active_TorF]) {
                    $line =~ s/usr_active_TorF/$args{-usr_active_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_active_TorF: $args{-usr_active_TorF} \n");
                }
            #Replace usr_condition_TorF
                elsif ($line =~ m[usr_condition_TorF]) {
                    $line =~ s/usr_condition_TorF/$args{-usr_condition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_condition_TorF: $args{-usr_condition_TorF} \n");
                }    
            #Replace usr_anonymousCondition_TorF
                elsif ($line =~ m[usr_anonymousCondition_TorF]) {
                    $line =~ s/usr_anonymousCondition_TorF/$args{-usr_anonymousCondition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_anonymousCondition_TorF: $args{-usr_anonymousCondition_TorF} \n");
                }
            #Replace usr_pabConditionGb_TorF
                elsif ($line =~ m[usr_pabConditionGb_TorF]) {
                    $line =~ s/usr_pabConditionGb_TorF/$args{-usr_pabConditionGb_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pabConditionGb_TorF: $args{-usr_pabConditionGb_TorF} \n");
                }
            #Replace usr_list_pabConditionGb
                elsif ($line =~ m[usr_list_pabConditionGb]) {
                    $line =~ s/usr_list_pabConditionGb/$args{-usr_list_pabConditionGb}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_pabConditionGb: $args{-usr_list_pabConditionGb} \n");
                } 
            #Replace usr_genericCondition_TorF
                elsif ($line =~ m[usr_genericCondition_TorF]) {
                    $line =~ s/usr_genericCondition_TorF/$args{-usr_genericCondition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_genericCondition_TorF: $args{-usr_genericCondition_TorF} \n");
                } 
            #Replace usr_listgenericCondition
                elsif ($line =~ m[usr_listgenericCondition]) {
                    $line =~ s/usr_listgenericCondition/$args{-usr_listgenericCondition}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_listgenericCondition: $args{-usr_listgenericCondition} \n");
                }
            #Replace usr_pabCondition_TorF
                elsif ($line =~ m[usr_pabCondition_TorF]) {
                    $line =~ s/usr_pabCondition_TorF/$args{-usr_pabCondition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pabCondition_TorF: $args{-usr_pabCondition_TorF} \n");
                }
            #Replace usr_list_pabCondition
                elsif ($line =~ m[usr_list_pabCondition]) {
                    $line =~ s/usr_list_pabCondition/$args{-usr_list_pabCondition}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_pabCondition: $args{-usr_list_pabCondition} \n");
                } 
            #Replace usr_pabGroupCondition_TorF
                elsif ($line =~ m[usr_pabGroupCondition_TorF]) {
                    $line =~ s/usr_pabGroupCondition_TorF/$args{-usr_pabGroupCondition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pabGroupCondition_TorF: $args{-usr_pabGroupCondition_TorF} \n");
                }  
            #Replace usr_list_pabGroupCondition
                elsif ($line =~ m[usr_list_pabGroupCondition]) {
                    $line =~ s/usr_list_pabGroupCondition/$args{-usr_list_pabGroupCondition}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_pabGroupCondition: $args{-usr_list_pabGroupCondition} \n");
                }
            #Replace usr_presenceCondition_TorF
                elsif ($line =~ m[usr_presenceCondition_TorF]) {
                    $line =~ s/usr_presenceCondition_TorF/$args{-usr_presenceCondition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_presenceCondition_TorF: $args{-usr_presenceCondition_TorF} \n");
                }
            #Replace usr_list_presenceCondition
                elsif ($line =~ m[usr_list_presenceCondition]) {
                    $line =~ s/usr_list_presenceCondition/$args{-usr_list_presenceCondition}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_presenceCondition: $args{-usr_list_presenceCondition} \n");
                } 
            #Replace usr_timeOfDayCondition_TorF
                elsif ($line =~ m[usr_timeOfDayCondition_TorF]) {
                    $line =~ s/usr_timeOfDayCondition_TorF/$args{-usr_timeOfDayCondition_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_timeOfDayCondition_TorF: $args{-usr_timeOfDayCondition_TorF} \n");
                } 
             #Replace usr_list_timeOfDayCondition
                if ($line =~ m[usr_list_timeOfDayCondition]) {
                    $line =~ s/usr_list_timeOfDayCondition/$args{-usr_list_timeOfDayCondition}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_timeOfDayCondition: $args{-usr_list_timeOfDayCondition} \n");
                }
            #Replace usr_exception_TorF
                elsif ($line =~ m[usr_exception_TorF]) {
                    $line =~ s/usr_exception_TorF/$args{-usr_exception_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_exception_TorF: $args{-usr_exception_TorF} \n");
                }
            #Replace usr_anonymousException_TorF
                elsif ($line =~ m[usr_anonymousException_TorF]) {
                    $line =~ s/usr_anonymousException_TorF/$args{-usr_anonymousException_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_anonymousException_TorF: $args{-usr_anonymousException_TorF} \n");
                }
            #Replace usr_pabExceptionGb_TorF
                elsif ($line =~ m[usr_pabExceptionGb_TorF]) {
                    $line =~ s/usr_pabExceptionGb_TorF/$args{-usr_pabExceptionGb_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pabExceptionGb_TorF: $args{-usr_pabExceptionGb_TorF} \n");
                }    
            #Replace usr_list_pabExceptionGb
                elsif ($line =~ m[usr_list_pabExceptionGb]) {
                    $line =~ s/usr_list_pabExceptionGb/$args{-usr_list_pabExceptionGb}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_pabExceptionGb: $args{-usr_list_pabExceptionGb} \n");
                }
            #Replace usr_genericException_TorF
                elsif ($line =~ m[usr_genericException_TorF]) {
                    $line =~ s/usr_genericException_TorF/$args{-usr_genericException_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_genericException_TorF: $args{-usr_genericException_TorF} \n");
                }
            #Replace usr_listgenericException
                elsif ($line =~ m[usr_listgenericException]) {
                    $line =~ s/usr_listgenericException/$args{-usr_listgenericException}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_listgenericException: $args{-usr_listgenericException} \n");
                } 
            #Replace usr_pabException_TorF
                elsif ($line =~ m[usr_pabException_TorF]) {
                    $line =~ s/usr_pabException_TorF/$args{-usr_pabException_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pabException_TorF: $args{-usr_pabException_TorF} \n");
                } 
            #Replace usr_list_pabException
                elsif ($line =~ m[usr_list_pabException]) {
                    $line =~ s/usr_list_pabException/$args{-usr_list_pabException}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_pabException: $args{-usr_list_pabException} \n");
                }
            #Replace usr_pabGroupException_TorF
                elsif ($line =~ m[usr_pabGroupException_TorF]) {
                    $line =~ s/usr_pabGroupException_TorF/$args{-usr_pabGroupException_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pabGroupException_TorF: $args{-usr_pabGroupException_TorF} \n");
                }
            #Replace usr_list_pabGroupException
                elsif ($line =~ m[usr_list_pabGroupException]) {
                    $line =~ s/usr_list_pabGroupException/$args{-usr_list_pabGroupException}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_pabGroupException: $args{-usr_list_pabGroupException} \n");
                } 
            #Replace usr_presenceException_TorF
                elsif ($line =~ m[usr_presenceException_TorF]) {
                    $line =~ s/usr_presenceException_TorF/$args{-usr_presenceException_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_presenceException_TorF: $args{-usr_presenceException_TorF} \n");
                }  
            #Replace usr_list_presenceException
                elsif ($line =~ m[usr_list_presenceException]) {
                    $line =~ s/usr_list_presenceException/$args{-usr_list_presenceException}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_presenceException: $args{-usr_list_presenceException} \n");
                }
            #Replace usr_termAction_TorF
                elsif ($line =~ m[usr_termAction_TorF]) {
                    $line =~ s/usr_termAction_TorF/$args{-usr_termAction_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_termAction_TorF: $args{-usr_termAction_TorF} \n");
                }
            #Replace usr_busyDest_TorF
                elsif ($line =~ m[usr_busyDest_TorF]) {
                    $line =~ s/usr_busyDest_TorF/$args{-usr_busyDest_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_busyDest_TorF: $args{-usr_busyDest_TorF} \n");
                } 
            #Replace usr_enable_busyDest_TorF
                elsif ($line =~ m[usr_enable_busyDest_TorF]) {
                    $line =~ s/usr_enable_busyDest_TorF/$args{-usr_enable_busyDest_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_enable_busyDest_TorF: $args{-usr_enable_busyDest_TorF} \n");
                }
            #Replace usr_numberofRings_busyDest
                elsif ($line =~ m[usr_numberofRings_busyDest]) {
                    $line =~ s/usr_numberofRings_busyDest/$args{-usr_numberofRings_busyDest}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberofRings_busyDest: $args{-usr_numberofRings_busyDest} \n");
                }
            #Replace usr_list_busyDest
                elsif ($line =~ m[usr_list_busyDest]) {
                    $line =~ s/usr_list_busyDest/$args{-usr_list_busyDest}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_busyDest: $args{-usr_list_busyDest} \n");
                }
            #Replace usr_dests_TorF
                elsif ($line =~ m[usr_dests_TorF]) {
                    $line =~ s/usr_dests_TorF/$args{-usr_dests_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dests_TorF: $args{-usr_dests_TorF} \n");
                } 
            #Replace usr_destsfirst_TorF
                elsif ($line =~ m[usr_destsfirst_TorF]) {
                    $line =~ s/usr_destsfirst_TorF/$args{-usr_destsfirst_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_destsfirst_TorF: $args{-usr_destsfirst_TorF} \n");
                }    
            #Replace usr_list_destsfirst
                elsif ($line =~ m[usr_list_destsfirst]) {
                    $line =~ s/usr_list_destsfirst/$args{-usr_list_destsfirst}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_destsfirst: $args{-usr_list_destsfirst} \n");
                }
            #Replace usr_numberofRings_first
                elsif ($line =~ m[usr_numberofRings_first]) {
                    $line =~ s/usr_numberofRings_first/$args{-usr_numberofRings_first}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberofRings_first: $args{-usr_numberofRings_first} \n");
                }
            #Replace usr_destssecond_TorF
                elsif ($line =~ m[usr_destssecond_TorF]) {
                    $line =~ s/usr_destssecond_TorF/$args{-usr_destssecond_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_destssecond_TorF: $args{-usr_destssecond_TorF} \n");
                }    
            #Replace usr_list_destssecond
                elsif ($line =~ m[usr_list_destssecond]) {
                    $line =~ s/usr_list_destssecond/$args{-usr_list_destssecond}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_destssecond: $args{-usr_list_destssecond} \n");
                } 
            #Replace usr_numberofRings_second
                elsif ($line =~ m[usr_numberofRings_second]) {
                    $line =~ s/usr_numberofRings_second/$args{-usr_numberofRings_second}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberofRings_second: $args{-usr_numberofRings_second} \n");
                } 
            #Replace usr_deststhird_TorF
                elsif ($line =~ m[usr_deststhird_TorF]) {
                    $line =~ s/usr_deststhird_TorF/$args{-usr_deststhird_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_deststhird_TorF: $args{-usr_deststhird_TorF} \n");
                }
            #Replace usr_list_deststhird
                elsif ($line =~ m[usr_list_deststhird]) {
                    $line =~ s/usr_list_deststhird/$args{-usr_list_deststhird}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_deststhird: $args{-usr_list_deststhird} \n");
                }
            #Replace usr_numberofRings_third
                elsif ($line =~ m[usr_numberofRings_third]) {
                    $line =~ s/usr_numberofRings_third/$args{-usr_numberofRings_third}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberofRings_third: $args{-usr_numberofRings_third} \n");
                } 
            #Replace usr_noAnswerDest_TorF
                elsif ($line =~ m[usr_noAnswerDest_TorF]) {
                    $line =~ s/usr_noAnswerDest_TorF/$args{-usr_noAnswerDest_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_noAnswerDest_TorF: $args{-usr_noAnswerDest_TorF} \n");
                }  
            #Replace usr_enable_noAnswerDest_TorF
                elsif ($line =~ m[usr_enable_noAnswerDest_TorF]) {
                    $line =~ s/usr_enable_noAnswerDest_TorF/$args{-usr_enable_noAnswerDest_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_enable_noAnswerDest_TorF: $args{-usr_enable_noAnswerDest_TorF} \n");
                }
            #Replace usr_numberofRings_noAnswerDest
                elsif ($line =~ m[usr_numberofRings_noAnswerDest]) {
                    $line =~ s/usr_numberofRings_noAnswerDest/$args{-usr_numberofRings_noAnswerDest}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberofRings_noAnswerDest: $args{-usr_numberofRings_noAnswerDest} \n");
                }
            #Replace usr_list_noAnswerDest
                elsif ($line =~ m[usr_list_noAnswerDest]) {
                    $line =~ s/usr_list_noAnswerDest/$args{-usr_list_noAnswerDest}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_noAnswerDest: $args{-usr_list_noAnswerDest} \n");
                } 
            #Replace usr_notLoggedInDest_TorF
                elsif ($line =~ m[usr_notLoggedInDest_TorF]) {
                    $line =~ s/usr_notLoggedInDest_TorF/$args{-usr_notLoggedInDest_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_notLoggedInDest_TorF: $args{-usr_notLoggedInDest_TorF} \n");
                }
            #Replace usr_enable_notLoggedInDest_TorF
                elsif ($line =~ m[usr_enable_notLoggedInDest_TorF]) {
                    $line =~ s/usr_enable_notLoggedInDest_TorF/$args{-usr_enable_notLoggedInDest_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_enable_notLoggedInDest_TorF: $args{-usr_enable_notLoggedInDest_TorF} \n");
                }
            #Replace usr_numberofRings_notLoggedInDest
                elsif ($line =~ m[usr_numberofRings_notLoggedInDest]) {
                    $line =~ s/usr_numberofRings_notLoggedInDest/$args{-usr_numberofRings_notLoggedInDest}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberofRings_notLoggedInDest: $args{-usr_numberofRings_notLoggedInDest} \n");
                } 
            #Replace usr_list_notLoggedInDest
                elsif ($line =~ m[usr_list_notLoggedInDest]) {
                    $line =~ s/usr_list_notLoggedInDest/$args{-usr_list_notLoggedInDest}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_notLoggedInDest: $args{-usr_list_notLoggedInDest} \n");
                }  
            #Replace usr_unreachableDest_TorF
                elsif ($line =~ m[usr_unreachableDest_TorF]) {
                    $line =~ s/usr_unreachableDest_TorF/$args{-usr_unreachableDest_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_unreachableDest_TorF: $args{-usr_unreachableDest_TorF} \n");
                }
            #Replace usr_enable_unreachableDest_TorF
                elsif ($line =~ m[usr_enable_unreachableDest_TorF]) {
                    $line =~ s/usr_enable_unreachableDest_TorF/$args{-usr_enable_unreachableDest_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_enable_unreachableDest_TorF: $args{-usr_enable_unreachableDest_TorF} \n");
                }
            #Replace usr_numberofRings_unreachableDest
                elsif ($line =~ m[usr_numberofRings_unreachableDest]) {
                    $line =~ s/usr_numberofRings_unreachableDest/$args{-usr_numberofRings_unreachableDest}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberofRings_unreachableDest: $args{-usr_numberofRings_unreachableDest} \n");
                } 
            #Replace usr_list_unreachableDest
                elsif ($line =~ m[usr_list_unreachableDest]) {
                    $line =~ s/usr_list_unreachableDest/$args{-usr_list_unreachableDest}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_unreachableDest: $args{-usr_list_unreachableDest} \n");
                }                  
        }
        elsif ($xmlfile =~ /updateSipProfileSIPPSA/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_profileName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_profileName
                elsif ($line =~ m[usr_profileName]) {
                    $line =~ s/usr_profileName/$args{-usr_profileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} \n");
                }
            #Replace usr_audioCodec
                elsif ($line =~ m[usr_audioCodec]) {
                    if ($args{-usr_audioCodec}) { 
                    $line =~ s/usr_audioCodec/$args{-usr_audioCodec}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_audioCodec: $args{-usr_audioCodec} \n");
                    } else {
                        $line =~ s/usr_audioCodec/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_audioCodec  \n");
                    }
                }    
            #Replace usr_audioPtime
                elsif ($line =~ m[usr_audioPtime]) {
                     if ($args{-usr_audioPtime}) {
                     $line =~ s/usr_audioPtime/$args{-usr_audioPtime}/;
                     $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_audioPtime: $args{-usr_audioPtime} \n");
                    } else {
                        $line =~ s/usr_audioPtime/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_audioPtime  \n");
                    }
                }
            #Replace usr_insertPtime
                elsif ($line =~ m[usr_insertPtime]) {
                    if ($args{-usr_insertPtime}) {
                    $line =~ s/usr_insertPtime/$args{-usr_insertPtime}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_insertPtime: $args{-usr_insertPtime} \n");
                    } else {
                        $line =~ s/usr_insertPtime/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_insertPtime \n");
                }
                }
            #Replace usr_mediaBitmap
                elsif ($line =~ m[usr_mediaBitmap]) {
                    if ($args{-usr_mediaBitmap}) {
                    $line =~ s/usr_mediaBitmap/$args{-usr_mediaBitmap}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mediaBitmap: $args{-usr_mediaBitmap} \n");
                } else {
                    $line =~ s/usr_mediaBitmap/671950/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mediaBitmap  \n");
                 }
                }
            #Replace usr_videoCodec
                elsif ($line =~ m[usr_videoCodec]) {
                    if ($args{-usr_videoCodec}) {
                    $line =~ s/usr_videoCodec/$args{-usr_videoCodec}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_videoCodec: $args{-usr_videoCodec} \n");
                    } else {
                        $line =~ s/usr_videoCodec/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_videoCodec  \n");
                    }
                }
            #Replace usr_activeCLIDUpdateMethod
                elsif ($line =~ m[usr_activeCLIDUpdateMethod]) {
                    if ($args{-usr_activeCLIDUpdateMethod}) {
                    $line =~ s/usr_activeCLIDUpdateMethod/$args{-usr_activeCLIDUpdateMethod}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_activeCLIDUpdateMethod: $args{-usr_activeCLIDUpdateMethod} \n");
                } else {
                    $line =~ s/usr_activeCLIDUpdateMethod/0/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_activeCLIDUpdateMethod  \n");
                }
                }
            #Replace usr_alertInfoNoRing
                elsif ($line =~ m[usr_alertInfoNoRing]) {
                    if ($args{-usr_alertInfoNoRing}) {
                    $line =~ s/usr_alertInfoNoRing/$args{-usr_alertInfoNoRing}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alertInfoNoRing: $args{-usr_alertInfoNoRing} \n");
                    } else {
                        $line =~ s/usr_alertInfoNoRing/1/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alertInfoNoRing  \n");
                    }
                }
            #Replace usr_alertInfoSet_string
                elsif ($line =~ m[usr_alertInfoSet_string]) {
                    if ($args{-usr_alertInfoSet_string}) {
                    $line =~ s/usr_alertInfoSet_string/$args{-usr_alertInfoSet_string}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alertInfoSet_string: $args{-usr_alertInfoSet_string} \n");
                    } else {
                        $line =~ s/usr_alertInfoSet_string/D\;/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alertInfoSet_string  \n");
                    }
                }
            #Replace usr_alertInfoset_int
                elsif ($line =~ m[usr_alertInfoset_int]) {
                    if ($args{-usr_alertInfoset_int}) {
                    $line =~ s/usr_alertInfoset_int/$args{-usr_alertInfoset_int}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alertInfoset_int: $args{-usr_alertInfoset_int} \n");
                    } else {
                        $line =~ s/usr_alertInfoset_int/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alertInfoset_int  \n");
                    }
                }
            #Replace usr_allowMethods
                elsif ($line =~ m[usr_allowMethods]) {
                    if ($args{-usr_allowMethods}) {
                    $line =~ s/usr_allowMethods/$args{-usr_allowMethods}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_allowMethods: $args{-usr_allowMethods} \n");
                    } else {
                        $line =~ s/usr_allowMethods/D\;\;/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_allowMethods  \n");
                    }
                }
            #Replace usr_description
                elsif ($line =~ m[usr_description]) {
                    if ($args{-usr_description}) {
                    $line =~ s/usr_description/$args{-usr_description}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_description: $args{-usr_description} \n");
                    } else {
                        $line =~ s/usr_description/$args{-usr_profileName}/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_description  \n");
                    }
                }
            #Replace usr_digitTimeoutUserName
                elsif ($line =~ m[usr_digitTimeoutUserName]) {
                    if ($args{-usr_digitTimeoutUserName}) {
                    $line =~ s/usr_digitTimeoutUserName/$args{-usr_digitTimeoutUserName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_digitTimeoutUserName: $args{-usr_digitTimeoutUserName} \n");
                    } else {
                        $line =~ s/usr_digitTimeoutUserName/digit_timeout/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_digitTimeoutUserName  \n");
                    }
                }
            #Replace usr_disableSlowStartMethods
                elsif ($line =~ m[usr_disableSlowStartMethods]) {
                    if ($args{-usr_disableSlowStartMethods}) {
                    $line =~ s/usr_disableSlowStartMethods/$args{-usr_disableSlowStartMethods}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_disableSlowStartMethods: $args{-usr_disableSlowStartMethods} \n");
                    } else {
                        $line =~ s/usr_disableSlowStartMethods/D\;\;/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_disableSlowStartMethods  \n");
                    }
                }                
             #Replace usr_earlyCLIDUpdate
                if ($line =~ m[usr_earlyCLIDUpdate]) {
                    if ($args{-usr_earlyCLIDUpdate}) {
                    $line =~ s/usr_earlyCLIDUpdate/$args{-usr_earlyCLIDUpdate}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_earlyCLIDUpdate: $args{-usr_earlyCLIDUpdate} \n");
                    } else {
                        $line =~ s/usr_earlyCLIDUpdate/\;/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_earlyCLIDUpdate  \n");
                    }
                }
            #Replace usr_flashUriUserName
                elsif ($line =~ m[usr_flashUriUserName]) {
                    if ($args{-usr_flashUriUserName}) {
                    $line =~ s/usr_flashUriUserName/$args{-usr_flashUriUserName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_flashUriUserName: $args{-usr_flashUriUserName} \n");
                    } else {
                        $line =~ s/usr_flashUriUserName/flash/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_flashUriUserName  \n");
                    }
                }
            #Replace usr_headers
                elsif ($line =~ m[usr_headers]) {
                    if ($args{-usr_headers}) {
                    $line =~ s/usr_headers/$args{-usr_headers}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_headers: $args{-usr_headers} \n");
                    } else {
                        $line =~ s/usr_headers/0\:0\:0\:0\:0\:262144\:0\:0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_headers  \n");
                    } 
                 }   
            #Replace usr_matchCriteria
                elsif ($line =~ m[usr_matchCriteria]) {
                    if ($args{-usr_matchCriteria}) {
                    $line =~ s/usr_matchCriteria/$args{-usr_matchCriteria}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_matchCriteria: $args{-usr_matchCriteria} \n");
                    } else {
                        $line =~ s/usr_matchCriteria/1\:user/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_matchCriteria  \n");
                    }
                }                
            #Replace usr_maxBlockSize
                elsif ($line =~ m[usr_maxBlockSize]) {
                    if ($args{-usr_maxBlockSize}) {
                    $line =~ s/usr_maxBlockSize/$args{-usr_maxBlockSize}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxBlockSize: $args{-usr_maxBlockSize} \n");
                    } else {
                        $line =~ s/usr_maxBlockSize/4096/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxBlockSize  \n");
                    }
                }
            #Replace usr_maxHeaderLength
                elsif ($line =~ m[usr_maxHeaderLength]) {
                    if ($args{-usr_maxHeaderLength}) {
                    $line =~ s/usr_maxHeaderLength/$args{-usr_maxHeaderLength}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxHeaderLength: $args{-usr_maxHeaderLength} \n");
                    } else {
                        $line =~ s/usr_maxHeaderLength/1024/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxHeaderLength  \n");
                    }
                }
            #Replace usr_maxHeaders
                elsif ($line =~ m[usr_maxHeaders]) {
                    if ($args{-usr_maxHeaders}) {
                    $line =~ s/usr_maxHeaders/$args{-usr_maxHeaders}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxHeaders: $args{-usr_maxHeaders} \n");
                    } else {
                        $line =~ s/usr_maxHeaders/200/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxHeaders  \n");
                    }
                }                
            #Replace usr_requestMethods
                elsif ($line =~ m[usr_requestMethods]) {
                    if ($args{-usr_requestMethods}) {
                    $line =~ s/usr_requestMethods/$args{-usr_requestMethods}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_requestMethods: $args{-usr_requestMethods} \n");
                    } else {
                        $line =~ s/usr_requestMethods/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_requestMethods  \n");
                    }
                }                
            #Replace usr_servicesConfig
                elsif ($line =~ m[usr_servicesConfig]) {
                    if ($args{-usr_servicesConfig}) {
                    $line =~ s/usr_servicesConfig/$args{-usr_servicesConfig}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_servicesConfig: $args{-usr_servicesConfig} \n");
                    } else {
                        $line =~ s/usr_servicesConfig//;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_servicesConfig \n");
                    }
                }                
            #Replace usr_signaling
                elsif ($line =~ m[usr_signaling]) {
                    if ($args{-usr_signaling}) {
                    $line =~ s/usr_signaling/$args{-usr_signaling}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_signaling: $args{-usr_signaling} \n");
                    } else {
                        $line =~ s/usr_signaling/0\;1\;2\;10\;12\;32\;54\;/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_signaling \n");
                    }
                }                
            #Replace usr_subscribeParam
                elsif ($line =~ m[usr_subscribeParam]) {
                    if ($args{-usr_subscribeParam}) {
                    $line =~ s/usr_subscribeParam/$args{-usr_subscribeParam}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_subscribeParam: $args{-usr_subscribeParam} \n");
                    } else {
                        $line =~ s/usr_subscribeParam/4/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_subscribeParam  \n");
                    }
                }                
            #Replace usr_supportedIntercomHeader
                elsif ($line =~ m[usr_supportedIntercomHeader]) {
                    if ($args{-usr_supportedIntercomHeader}) {
                    $line =~ s/usr_supportedIntercomHeader/$args{-usr_supportedIntercomHeader}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_supportedIntercomHeader: $args{-usr_supportedIntercomHeader} \n");
                    } else {
                        $line =~ s/usr_supportedIntercomHeader//;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_supportedIntercomHeader  \n");
                    }
                }
        }
        elsif ($xmlfile =~ /addSystemProfileOIP/i)
        {
            foreach ('-usr_systemProfile_name', '-usr_origIdPresentationEnabled_TorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_systemProfile_name
                if ($line =~ m[usr_systemProfile_name]) {
                    $line =~ s/usr_systemProfile_name/$args{-usr_systemProfile_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_systemProfile_name: $args{-usr_systemProfile_name} \n");
                }
            #Replace usr_origIdPresentationEnabled_TorF
                elsif ($line =~ m[usr_origIdPresentationEnabled_TorF]) {
                    $line =~ s/usr_origIdPresentationEnabled_TorF/$args{-usr_origIdPresentationEnabled_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_origIdPresentationEnabled_TorF: $args{-usr_origIdPresentationEnabled_TorF} \n");
                }   
        }
        elsif ($xmlfile =~ /removeSystemProfileOIP/i)
        {
            foreach ('-usr_systemProfile_name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_systemProfile_name
                if ($line =~ m[usr_systemProfile_name]) {
                    $line =~ s/usr_systemProfile_name/$args{-usr_systemProfile_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_systemProfile_name: $args{-usr_systemProfile_name} \n");
                }  
        }
        elsif ($xmlfile =~ /setDomainsForSystemProfileOIP|removeDomainFromSystemProfileOIP/i)
        {
            foreach ('-usr_systemProfile_name', '-usr_domain') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_systemProfile_name
                if ($line =~ m[usr_systemProfile_name]) {
                    $line =~ s/usr_systemProfile_name/$args{-usr_systemProfile_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_systemProfile_name: $args{-usr_systemProfile_name} \n");
                }
            #Replace usr_domain
                elsif ($line =~ m[usr_domain]) {
                    $line =~ s/usr_domain/$args{-usr_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
                }   
        }
        elsif ($xmlfile =~ /setSystemProfileOIPForUser/i)
        {
            foreach ('-usr_users', '-usr_systemProfile_name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                }
            #Replace usr_systemProfile_name
                elsif ($line =~ m[usr_systemProfile_name]) {
                    $line =~ s/usr_systemProfile_name/$args{-usr_systemProfile_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_systemProfile_name: $args{-usr_systemProfile_name} \n");
                }   
        }
        elsif ($xmlfile =~ /updateSipProfileSIPPPBX/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_profileName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_profileName
                elsif ($line =~ m[usr_profileName]) {
                    $line =~ s/usr_profileName/$args{-usr_profileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} \n");
                }
            #Replace usr_audioCodec
                elsif ($line =~ m[usr_audioCodec]) {
                    if ($args{-usr_audioCodec}) { 
                    $line =~ s/usr_audioCodec/$args{-usr_audioCodec}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_audioCodec: $args{-usr_audioCodec} \n");
                    } else {
                        $line =~ s/usr_audioCodec/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_audioCodec \n");
                    }
                }    
            #Replace usr_audioPtime
                elsif ($line =~ m[usr_audioPtime]) {
                     if ($args{-usr_audioPtime}) {
                     $line =~ s/usr_audioPtime/$args{-usr_audioPtime}/;
                     $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_audioPtime: $args{-usr_audioPtime} \n");
                    } else {
                        $line =~ s/usr_audioPtime/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_audioPtime \n");
                    }
                }
            #Replace usr_insertPtime
                elsif ($line =~ m[usr_insertPtime]) {
                    if ($args{-usr_insertPtime}) {
                    $line =~ s/usr_insertPtime/$args{-usr_insertPtime}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_insertPtime: $args{-usr_insertPtime} \n");
                    } else {
                        $line =~ s/usr_insertPtime/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_insertPtime \n");
                }
                }
            #Replace usr_mediaBitmap
                elsif ($line =~ m[usr_mediaBitmap]) {
                    if ($args{-usr_mediaBitmap}) {
                    $line =~ s/usr_mediaBitmap/$args{-usr_mediaBitmap}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mediaBitmap: $args{-usr_mediaBitmap} \n");
                } else {
                    $line =~ s/usr_mediaBitmap/671950/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mediaBitmap \n");
                 }
                }
            #Replace usr_videoCodec
                elsif ($line =~ m[usr_videoCodec]) {
                    if ($args{-usr_videoCodec}) {
                    $line =~ s/usr_videoCodec/$args{-usr_videoCodec}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_videoCodec: $args{-usr_videoCodec} \n");
                    } else {
                        $line =~ s/usr_videoCodec/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_videoCodec \n");
                    }
                }
            #Replace usr_activeCLIDUpdateMethod
                elsif ($line =~ m[usr_activeCLIDUpdateMethod]) {
                    if ($args{-usr_activeCLIDUpdateMethod}) {
                    $line =~ s/usr_activeCLIDUpdateMethod/$args{-usr_activeCLIDUpdateMethod}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_activeCLIDUpdateMethod: $args{-usr_activeCLIDUpdateMethod} \n");
                } else {
                    $line =~ s/usr_activeCLIDUpdateMethod/0/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_activeCLIDUpdateMethod \n");
                }
                }
            #Replace usr_alertInfoNoRing
                elsif ($line =~ m[usr_alertInfoNoRing]) {
                    if ($args{-usr_alertInfoNoRing}) {
                    $line =~ s/usr_alertInfoNoRing/$args{-usr_alertInfoNoRing}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alertInfoNoRing: $args{-usr_alertInfoNoRing} \n");
                    } else {
                        $line =~ s/usr_alertInfoNoRing/1/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alertInfoNoRing \n");
                    }
                }
            #Replace usr_alertInfoSet_string
                elsif ($line =~ m[usr_alertInfoSet_string]) {
                    if ($args{-usr_alertInfoSet_string}) {
                    $line =~ s/usr_alertInfoSet_string/$args{-usr_alertInfoSet_string}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alertInfoSet_string: $args{-usr_alertInfoSet_string} \n");
                    } else {
                        $line =~ s/usr_alertInfoSet_string/D\;/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alertInfoSet_string \n");
                    }
                }
            #Replace usr_alertInfoset_int
                elsif ($line =~ m[usr_alertInfoset_int]) {
                    if ($args{-usr_alertInfoset_int}) {
                    $line =~ s/usr_alertInfoset_int/$args{-usr_alertInfoset_int}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alertInfoset_int: $args{-usr_alertInfoset_int} \n");
                    } else {
                        $line =~ s/usr_alertInfoset_int/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alertInfoset_int \n");
                    }
                }
            #Replace usr_allowMethods
                elsif ($line =~ m[usr_allowMethods]) {
                    if ($args{-usr_allowMethods}) {
                    $line =~ s/usr_allowMethods/$args{-usr_allowMethods}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_allowMethods: $args{-usr_allowMethods} \n");
                    } else {
                        $line =~ s/usr_allowMethods/D\;\;/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_allowMethods \n");
                    }
                }
            #Replace usr_description
                elsif ($line =~ m[usr_description]) {
                    if ($args{-usr_description}) {
                    $line =~ s/usr_description/$args{-usr_description}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_description: $args{-usr_description} \n");
                    } else {
                        $line =~ s/usr_description/$args{-usr_profileName}/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_description \n");
                    }
                }
            #Replace usr_digitTimeoutUserName
                elsif ($line =~ m[usr_digitTimeoutUserName]) {
                    if ($args{-usr_digitTimeoutUserName}) {
                    $line =~ s/usr_digitTimeoutUserName/$args{-usr_digitTimeoutUserName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_digitTimeoutUserName: $args{-usr_digitTimeoutUserName} \n");
                    } else {
                        $line =~ s/usr_digitTimeoutUserName/digit_timeout/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_digitTimeoutUserName \n");
                    }
                }
            #Replace usr_disableSlowStartMethods
                elsif ($line =~ m[usr_disableSlowStartMethods]) {
                    if ($args{-usr_disableSlowStartMethods}) {
                    $line =~ s/usr_disableSlowStartMethods/$args{-usr_disableSlowStartMethods}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_disableSlowStartMethods: $args{-usr_disableSlowStartMethods} \n");
                    } else {
                        $line =~ s/usr_disableSlowStartMethods/D\;\;/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_disableSlowStartMethods \n");
                    }
                }                
             #Replace usr_earlyCLIDUpdate
                if ($line =~ m[usr_earlyCLIDUpdate]) {
                    if ($args{-usr_earlyCLIDUpdate}) {
                    $line =~ s/usr_earlyCLIDUpdate/$args{-usr_earlyCLIDUpdate}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_earlyCLIDUpdate: $args{-usr_earlyCLIDUpdate} \n");
                    } else {
                        $line =~ s/usr_earlyCLIDUpdate/\;/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_earlyCLIDUpdate \n");
                    }
                }
            #Replace usr_flashUriUserName
                elsif ($line =~ m[usr_flashUriUserName]) {
                    if ($args{-usr_flashUriUserName}) {
                    $line =~ s/usr_flashUriUserName/$args{-usr_flashUriUserName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_flashUriUserName: $args{-usr_flashUriUserName} \n");
                    } else {
                        $line =~ s/usr_flashUriUserName/flash/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_flashUriUserName \n");
                    }
                }
            #Replace usr_headers
                elsif ($line =~ m[usr_headers]) {
                    if ($args{-usr_headers}) {
                    $line =~ s/usr_headers/$args{-usr_headers}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_headers: $args{-usr_headers} \n");
                    } else {
                        $line =~ s/usr_headers/0\:0\:0\:0\:0\:262144\:0\:0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_headers \n");
                    } 
                 }   
            #Replace usr_matchCriteria
                elsif ($line =~ m[usr_matchCriteria]) {
                    if ($args{-usr_matchCriteria}) {
                    $line =~ s/usr_matchCriteria/$args{-usr_matchCriteria}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_matchCriteria: $args{-usr_matchCriteria} \n");
                    } else {
                        $line =~ s/usr_matchCriteria/1\:user/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_matchCriteria \n");
                    }
                }                
            #Replace usr_maxBlockSize
                elsif ($line =~ m[usr_maxBlockSize]) {
                    if ($args{-usr_maxBlockSize}) {
                    $line =~ s/usr_maxBlockSize/$args{-usr_maxBlockSize}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxBlockSize: $args{-usr_maxBlockSize} \n");
                    } else {
                        $line =~ s/usr_maxBlockSize/4096/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxBlockSize \n");
                    }
                }
            #Replace usr_maxHeaderLength
                elsif ($line =~ m[usr_maxHeaderLength]) {
                    if ($args{-usr_maxHeaderLength}) {
                    $line =~ s/usr_maxHeaderLength/$args{-usr_maxHeaderLength}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxHeaderLength: $args{-usr_maxHeaderLength} \n");
                    } else {
                        $line =~ s/usr_maxHeaderLength/1024/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxHeaderLength \n");
                    }
                }
            #Replace usr_maxHeaders
                elsif ($line =~ m[usr_maxHeaders]) {
                    if ($args{-usr_maxHeaders}) {
                    $line =~ s/usr_maxHeaders/$args{-usr_maxHeaders}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxHeaders: $args{-usr_maxHeaders} \n");
                    } else {
                        $line =~ s/usr_maxHeaders/200/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxHeaders \n");
                    }
                }                
            #Replace usr_requestMethods
                elsif ($line =~ m[usr_requestMethods]) {
                    if ($args{-usr_requestMethods}) {
                    $line =~ s/usr_requestMethods/$args{-usr_requestMethods}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_requestMethods: $args{-usr_requestMethods} \n");
                    } else {
                        $line =~ s/usr_requestMethods/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_requestMethods \n");
                    }
                }                
            #Replace usr_servicesConfig
                elsif ($line =~ m[usr_servicesConfig]) {
                    if ($args{-usr_servicesConfig}) {
                    $line =~ s/usr_servicesConfig/$args{-usr_servicesConfig}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_servicesConfig: $args{-usr_servicesConfig} \n");
                    } else {
                        $line =~ s/usr_servicesConfig/\<\!\[CDATA\[\<services\-config\>
\<sla\-config\>
\<appearance\-header\>
\<name\>Alert\-Info\<\/name\>
\<index\>appearance\<\/index\>
\<\/appearance\-header\>
\<callstates\>
\<state\-reservation\>trying\<\/state\-reservation\>
\<state\-call\-attempt\>proceeding\<\/state\-call\-attempt\>
\<state\-ringing\>early\<\/state\-ringing\>
\<state\-established\>confirmed\<\/state\-established\>
\<state\-termination\>terminated\<\/state\-termination\>
\<state\-bridge\>confirmed\<\/state\-bridge\>
\<state\-public\-hold\>confirmed\<\/state\-public\-hold\>
\<state\-private\-hold\>confirmed\<\/state\-private\-hold\>
\<\/callstates\>
\<reservation\>
\<method\>PUBLISH\<\/method\>
\<event\>dialog\<\/event\>
\<minSE\>15\<\/minSE\>
\<maxSE\>60\<\/maxSE\>
\<allow\-via\-dialog\-body \/\>
\<\/reservation\>
\<notification\>
\<event\>dialog\<\/event\>
\<allow\-via\-dialog\-body \/\>
\<\/notification\>
\<\/sla\-config\>
\<\/services\-config\>\]\]\]\]\>\>\<\!\[CDATA\[/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_servicesConfig \n");
                    }
                }                
            #Replace usr_signaling
                elsif ($line =~ m[usr_signaling]) {
                    if ($args{-usr_signaling}) {
                    $line =~ s/usr_signaling/$args{-usr_signaling}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_signaling: $args{-usr_signaling} \n");
                    } else {
                        $line =~ s/usr_signaling/0\;1\;2\;4\;10\;12\;54\;/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_signaling  \n");
                    }
                }                
            #Replace usr_subscribeParam
                elsif ($line =~ m[usr_subscribeParam]) {
                    if ($args{-usr_subscribeParam}) {
                    $line =~ s/usr_subscribeParam/$args{-usr_subscribeParam}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_subscribeParam: $args{-usr_subscribeParam} \n");
                    } else {
                        $line =~ s/usr_subscribeParam/4/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_subscribeParam  \n");
                    }
                }                
            #Replace usr_supportedIntercomHeader
                elsif ($line =~ m[usr_supportedIntercomHeader]) {
                    if ($args{-usr_supportedIntercomHeader}) {
                    $line =~ s/usr_supportedIntercomHeader/$args{-usr_supportedIntercomHeader}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_supportedIntercomHeader: $args{-usr_supportedIntercomHeader} \n");
                    } else {
                        $line =~ s/usr_supportedIntercomHeader//;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_supportedIntercomHeader  \n");
                    }
                }
        }
        elsif ($xmlfile =~ /removeSystemProfileAccountCode/i)
        {
            foreach ('-usr_systemprofile_name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_systemprofile_name
                if ($line =~ m[usr_systemprofile_name]) {
                    $line =~ s/usr_systemprofile_name/$args{-usr_systemprofile_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_systemprofile_name: $args{-usr_systemprofile_name} \n");
                }  
        }
        elsif ($xmlfile =~ /removeSPOIPFromUser/i)
        {
            foreach ('-usr_users') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                }  
        }
        elsif ($xmlfile =~ /addIncomingSelectiveRejectEntries/i)
        {
            foreach ('-usr_users', '-usr_listEntry_incomingReject') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                } 
           #Replace usr_listEntry_incomingReject
                if ($line =~ m[usr_listEntry_incomingReject]) {
                    $line =~ s/usr_listEntry_incomingReject/$args{-usr_listEntry_incomingReject}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_listEntry_incomingReject: $args{-usr_listEntry_incomingReject} \n");
                }                 
        }
        elsif ($xmlfile =~ /addOutgoingSelectiveRejectEntries/i)
        {
            foreach ('-usr_users', '-usr_listEntry_outgoingReject') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                } 
           #Replace usr_listEntry_outgoingReject
                if ($line =~ m[usr_listEntry_outgoingReject]) {
                    $line =~ s/usr_listEntry_outgoingReject/$args{-usr_listEntry_outgoingReject}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_listEntry_outgoingReject: $args{-usr_listEntry_outgoingReject} \n");
                }                 
        }
        elsif ($xmlfile =~ /removeAllIncomingSelectiveRejectEntries|removeAllOutgoingSelectiveRejectEntries/i)
        {
            unless ($args{-usr_users}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_user
            if ($line =~ m[usr_users]) {
                $line =~ s/usr_users/$args{-usr_users}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /updateSipPbxStatic1tran/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_sipPbx_longName', '-usr_sipPbx_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_sipPbx_longName
                elsif ($line =~ m[usr_sipPbx_longName]) {
                    $line =~ s/usr_sipPbx_longName/$args{-usr_sipPbx_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_longName: $args{-usr_sipPbx_longName} \n");
                }
            #Replace usr_sipPbx_shortName
                elsif ($line =~ m[usr_sipPbx_shortName]) {
                    $line =~ s/usr_sipPbx_shortName/$args{-usr_sipPbx_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_shortName: $args{-usr_sipPbx_shortName} \n");
                }    
            #Replace usr_chargingTrusted_TorF
                elsif ($line =~ m[usr_chargingTrusted_TorF]) {
                    if ($args{-usr_chargingTrusted_TorF}) { 
                    $line =~ s/usr_chargingTrusted_TorF/$args{-usr_chargingTrusted_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_chargingTrusted_TorF: $args{-usr_chargingTrusted_TorF} \n");
                    } else {
                        $line =~ s/usr_chargingTrusted_TorF/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_chargingTrusted_TorF \n");
                    }
                }    
            #Replace usr_exemptDoSProtection_TorF
                elsif ($line =~ m[usr_exemptDoSProtection_TorF]) {
                     if ($args{-usr_exemptDoSProtection_TorF}) {
                     $line =~ s/usr_exemptDoSProtection_TorF/$args{-usr_exemptDoSProtection_TorF}/;
                     $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_exemptDoSProtection_TorF: $args{-usr_exemptDoSProtection_TorF} \n");
                    } else {
                        $line =~ s/usr_exemptDoSProtection_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_exemptDoSProtection_TorF \n");
                    }
                }
            #Replace usr_trusted_TorF
                elsif ($line =~ m[usr_trusted_TorF]) {
                    if ($args{-usr_trusted_TorF}) {
                    $line =~ s/usr_trusted_TorF/$args{-usr_trusted_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_trusted_TorF: $args{-usr_trusted_TorF} \n");
                    } else {
                        $line =~ s/usr_trusted_TorF/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_trusted_TorF \n");
                }
                }
            #Replace usr_ccmPritoSip
                elsif ($line =~ m[usr_ccmPritoSip]) {
                    if ($args{-usr_ccmPritoSip}) {
                    $line =~ s/usr_ccmPritoSip/$args{-usr_ccmPritoSip}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ccmPritoSip: $args{-usr_ccmPritoSip} \n");
                } else {
                    $line =~ s/usr_ccmPritoSip/default/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ccmPritoSip \n");
                 }
                }
            #Replace usr_ccmSiptoPri
                elsif ($line =~ m[usr_ccmSiptoPri]) {
                    if ($args{-usr_ccmSiptoPri}) {
                    $line =~ s/usr_ccmSiptoPri/$args{-usr_ccmSiptoPri}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ccmSiptoPri: $args{-usr_ccmSiptoPri} \n");
                    } else {
                        $line =~ s/usr_ccmSiptoPri/default/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ccmSiptoPri \n");
                    }
                }
            #Replace usr_dnsEnab_TorF
                elsif ($line =~ m[usr_dnsEnab_TorF]) {
                    if ($args{-usr_dnsEnab_TorF}) {
                    $line =~ s/usr_dnsEnab_TorF/$args{-usr_dnsEnab_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dnsEnab_TorF: $args{-usr_dnsEnab_TorF} \n");
                } else {
                    $line =~ s/usr_dnsEnab_TorF/false/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dnsEnab_TorF \n");
                }
                }
            #Replace usr_headerMapping
                elsif ($line =~ m[usr_headerMapping]) {
                    if ($args{-usr_headerMapping}) {
                    $line =~ s/usr_headerMapping/$args{-usr_headerMapping}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_headerMapping: $args{-usr_headerMapping} \n");
                    } else {
                        $line =~ s/usr_headerMapping/AutoTest/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_headerMapping \n");
                    }
                }
            #Replace usr_auditEnabled_TorF
                elsif ($line =~ m[usr_auditEnabled_TorF]) {
                    if ($args{-usr_auditEnabled_TorF}) {
                    $line =~ s/usr_auditEnabled_TorF/$args{-usr_auditEnabled_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditEnabled_TorF: $args{-usr_auditEnabled_TorF} \n");
                    } else {
                        $line =~ s/usr_auditEnabled_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditEnabled_TorF \n");
                    }
                }
            #Replace usr_auditPeriod
                elsif ($line =~ m[usr_auditPeriod]) {
                    if (($args{-usr_auditPeriod})) {
                    $line =~ s/usr_auditPeriod/$args{-usr_auditPeriod}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditPeriod: $args{-usr_auditPeriod} \n");
                    } else {
                        $line =~ s/usr_auditPeriod/20/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditPeriod \n");
                    }
                }
            #Replace usr_aytProfile
                elsif ($line =~ m[usr_aytProfile]) {
                    if ($args{-usr_aytProfile}) {
                    $line =~ s/usr_aytProfile/$args{-usr_aytProfile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_aytProfile: $args{-usr_aytProfile} \n");
                    } else {
                        $line =~ s/usr_aytProfile/defaultInfo/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_aytProfile \n");
                    }
                }
            #Replace usr_longAuditPeriod
                elsif ($line =~ m[usr_longAuditPeriod]) {
                    if ($args{-usr_auditPeriod}) {
                    $line =~ s/usr_longAuditPeriod/$args{-usr_auditPeriod}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_longAuditPeriod: $args{-usr_auditPeriod} \n");
                    } else {
                        $line =~ s/usr_longAuditPeriod/20/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditPeriod \n");
                    }
                }
                 
            #Replace usr_omsEnabled_TorF
                elsif ($line =~ m[usr_omsEnabled_TorF]) {
                    if ($args{-usr_omsEnabled_TorF}) {
                    $line =~ s/usr_omsEnabled_TorF/$args{-usr_omsEnabled_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_omsEnabled_TorF: $args{-usr_omsEnabled_TorF} \n");
                    } else {
                        $line =~ s/usr_omsEnabled_TorF/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_omsEnabled_TorF \n");
                    }
                }
            #Replace usr_mime1
                elsif ($line =~ m[usr_mime1]) {
                    if ($args{-usr_mime1}) {
                    $line =~ s/usr_mime1/$args{-usr_mime1}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime1: $args{-usr_mime1} \n");
                    } else {
                        $line =~ s/usr_mime1/ESN5/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime1 \n");
                    }
                }
            #Replace usr_mime2
                elsif ($line =~ m[usr_mime2]) {
                    if ($args{-usr_mime2}) {
                    $line =~ s/usr_mime2/$args{-usr_mime2}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime2: $args{-usr_mime2} \n");
                    } else {
                        $line =~ s/usr_mime2/CUG/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime2 \n");
                    }
                }
            #Replace usr_mime3
                elsif ($line =~ m[usr_mime3]) {
                    if ($args{-usr_mime3}) {
                    $line =~ s/usr_mime3/$args{-usr_mime3}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime3: $args{-usr_mime3} \n");
                    } else {
                        $line =~ s/usr_mime3/NSS/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime3 \n");
                    }
                }
            #Replace usr_mime4
                elsif ($line =~ m[usr_mime4]) {
                    if ($args{-usr_mime4}) {
                    $line =~ s/usr_mime4/$args{-usr_mime4}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime4: $args{-usr_mime4} \n");
                    } else {
                        $line =~ s/usr_mime4/MCDN/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime4 \n");
                    }
                }
            #Replace usr_mime5
                elsif ($line =~ m[usr_mime5]) {
                    if ($args{-usr_mime5}) {
                    $line =~ s/usr_mime5/$args{-usr_mime5}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime5: $args{-usr_mime5} \n");
                    } else {
                        $line =~ s/usr_mime5/EPID/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime5 \n");
                    }
                }    
            #Replace usr_PBXenableTCPPortP_TorF
                elsif ($line =~ m[usr_PBXenableTCPPortP_TorF]) {
                    if ($args{-usr_PBXenableTCPPortP_TorF}) {
                    $line =~ s/usr_PBXenableTCPPortP_TorF/$args{-usr_PBXenableTCPPortP_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXenableTCPPortP_TorF: $args{-usr_PBXenableTCPPortP_TorF} \n");
                    } 
                }
            #Replace usr_PBXenableTLSPortP_TorF
                elsif ($line =~ m[usr_PBXenableTLSPortP_TorF]) {
                    if ($args{-usr_PBXenableTLSPortP_TorF}) {
                    $line =~ s/usr_PBXenableTLSPortP_TorF/$args{-usr_PBXenableTLSPortP_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXenableTLSPortP_TorF: $args{-usr_PBXenableTLSPortP_TorF} \n");
                    } else {
                        $line =~ s/usr_enableTLSPort_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_enableTLSPort_TorF \n");
                    }
                } 
            #Replace usr_PBXenableUDPPortP_TorF
                elsif ($line =~ m[usr_PBXenableUDPPortP_TorF]) {
                    if ($args{-usr_PBXenableUDPPortP_TorF}) {
                    $line =~ s/usr_PBXenableUDPPortP_TorF/$args{-usr_PBXenableUDPPortP_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXenableUDPPortP_TorF: $args{-usr_PBXenableUDPPortP_TorF} \n");
                    }
                }
            #Replace usr_PBXportP
                elsif ($line =~ m[usr_PBXportP]) {
                    if ($args{-usr_PBXportP}) {
                    $line =~ s/usr_PBXportP/$args{-usr_PBXportP}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXportP: $args{-usr_PBXportP} \n");
                    } else {
                        $line =~ s/usr_PBXportP/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXportP \n");
                    }
                }
            #Replace usr_PBXnodeP
                elsif ($line =~ m[usr_PBXnodeP]) {
                    $line =~ s/usr_PBXnodeP/$args{-usr_PBXnodeP}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXnodeP: $args{-usr_PBXnodeP} \n");
                }    
             #Replace usr_PBXsipUDPPortP
                elsif ($line =~ m[usr_PBXsipUDPPortP]) {
                    $line =~ s/usr_PBXsipUDPPortP/$args{-usr_PBXsipUDPPortP}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXsipUDPPortP: $args{-usr_PBXsipUDPPortP} \n");
                }
            #Replace usr_PBXsipTCPPortP
                elsif ($line =~ m[usr_PBXsipTCPPortP]) {
                    $line =~ s/usr_PBXsipTCPPortP/$args{-usr_PBXsipTCPPortP}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXsipTCPPortP: $args{-usr_PBXsipTCPPortP} \n");
                }
            #Replace usr_PBXsipTLSPortP
                elsif ($line =~ m[usr_PBXsipTLSPortP]) {
                    $line =~ s/usr_PBXsipTLSPortP/$args{-usr_PBXsipTLSPortP}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXsipTLSPortP: $args{-usr_PBXsipTLSPortP} \n");
                }
            #Replace usr_PBXtransportGroupP
                elsif ($line =~ m[usr_PBXtransportGroupP]) {
                    if ($args{-usr_PBXtransportGroupP}) {
                    $line =~ s/usr_PBXtransportGroupP/$args{-usr_PBXtransportGroupP}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXtransportGroupP: $args{-usr_PBXtransportGroupP} \n");
                    } else {
                        $line =~ s/usr_PBXtransportGroupP/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXtransportGroupP \n");
                    }
                }                
        }
        elsif ($xmlfile =~ /updateSipPbxDynemic/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_sipPbx_longName', '-usr_sipPbx_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_sipPbx_longName
                elsif ($line =~ m[usr_sipPbx_longName]) {
                    $line =~ s/usr_sipPbx_longName/$args{-usr_sipPbx_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_longName: $args{-usr_sipPbx_longName} \n");
                }
            #Replace usr_sipPbx_shortName
                elsif ($line =~ m[usr_sipPbx_shortName]) {
                    $line =~ s/usr_sipPbx_shortName/$args{-usr_sipPbx_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_shortName: $args{-usr_sipPbx_shortName} \n");
                }    
            #Replace usr_chargingTrusted_TorF
                elsif ($line =~ m[usr_chargingTrusted_TorF]) {
                    if ($args{-usr_chargingTrusted_TorF}) { 
                    $line =~ s/usr_chargingTrusted_TorF/$args{-usr_chargingTrusted_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_chargingTrusted_TorF: $args{-usr_chargingTrusted_TorF} \n");
                    } else {
                        $line =~ s/usr_chargingTrusted_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_chargingTrusted_TorF \n");
                    }
                }    
            #Replace usr_exemptDoSProtection_TorF
                elsif ($line =~ m[usr_exemptDoSProtection_TorF]) {
                     if ($args{-usr_exemptDoSProtection_TorF}) {
                     $line =~ s/usr_exemptDoSProtection_TorF/$args{-usr_exemptDoSProtection_TorF}/;
                     $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_exemptDoSProtection_TorF: $args{-usr_exemptDoSProtection_TorF} \n");
                    } else {
                        $line =~ s/usr_exemptDoSProtection_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_exemptDoSProtection_TorF \n");
                    }
                }
            #Replace usr_trusted_TorF
                elsif ($line =~ m[usr_trusted_TorF]) {
                    if ($args{-usr_trusted_TorF}) {
                    $line =~ s/usr_trusted_TorF/$args{-usr_trusted_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_trusted_TorF: $args{-usr_trusted_TorF} \n");
                    } else {
                        $line =~ s/usr_trusted_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_trusted_TorF \n");
                }
                }
            #Replace usr_ccmPritoSip
                elsif ($line =~ m[usr_ccmPritoSip]) {
                    if ($args{-usr_ccmPritoSip}) {
                    $line =~ s/usr_ccmPritoSip/$args{-usr_ccmPritoSip}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ccmPritoSip: $args{-usr_ccmPritoSip} \n");
                } else {
                    $line =~ s/usr_ccmPritoSip/default/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ccmPritoSip \n");
                 }
                }
            #Replace usr_ccmSiptoPri
                elsif ($line =~ m[usr_ccmSiptoPri]) {
                    if ($args{-usr_ccmSiptoPri}) {
                    $line =~ s/usr_ccmSiptoPri/$args{-usr_ccmSiptoPri}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ccmSiptoPri: $args{-usr_ccmSiptoPri} \n");
                    } else {
                        $line =~ s/usr_ccmSiptoPri/default/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ccmSiptoPri \n");
                    }
                }
            #Replace usr_dnsEnab_TorF
                elsif ($line =~ m[usr_dnsEnab_TorF]) {
                    if ($args{-usr_dnsEnab_TorF}) {
                    $line =~ s/usr_dnsEnab_TorF/$args{-usr_dnsEnab_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dnsEnab_TorF: $args{-usr_dnsEnab_TorF} \n");
                } else {
                    $line =~ s/usr_dnsEnab_TorF/false/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dnsEnab_TorF \n");
                }
                }
            #Replace usr_headerMapping
                elsif ($line =~ m[usr_headerMapping]) {
                    if ($args{-usr_headerMapping}) {
                    $line =~ s/usr_headerMapping/$args{-usr_headerMapping}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_headerMapping: $args{-usr_headerMapping} \n");
                    } else {
                        $line =~ s/usr_headerMapping/AutoTest/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_headerMapping \n");
                    }
                }
            #Replace usr_auditEnabled_TorF
                elsif ($line =~ m[usr_auditEnabled_TorF]) {
                    if ($args{-usr_auditEnabled_TorF}) {
                    $line =~ s/usr_auditEnabled_TorF/$args{-usr_auditEnabled_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditEnabled_TorF: $args{-usr_auditEnabled_TorF} \n");
                    } else {
                        $line =~ s/usr_auditEnabled_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditEnabled_TorF \n");
                    }
                }
            #Replace usr_auditPeriod
                elsif ($line =~ m[usr_auditPeriod]) {
                    if (($args{-usr_auditPeriod})) {
                    $line =~ s/usr_auditPeriod/$args{-usr_auditPeriod}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditPeriod: $args{-usr_auditPeriod} \n");
                    } else {
                        $line =~ s/usr_auditPeriod/20/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditPeriod \n");
                    }
                }
            #Replace usr_aytProfile
                elsif ($line =~ m[usr_aytProfile]) {
                    if ($args{-usr_aytProfile}) {
                    $line =~ s/usr_aytProfile/$args{-usr_aytProfile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_aytProfile: $args{-usr_aytProfile} \n");
                    } else {
                        $line =~ s/usr_aytProfile/defaultInfo/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_aytProfile \n");
                    }
                }
            #Replace usr_longAuditPeriod
                elsif ($line =~ m[usr_longAuditPeriod]) {
                    if ($args{-usr_auditPeriod}) {
                    $line =~ s/usr_longAuditPeriod/$args{-usr_auditPeriod}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_longAuditPeriod: $args{-usr_auditPeriod} \n");
                    } else {
                        $line =~ s/usr_longAuditPeriod/20/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditPeriod \n");
                    }
                }
                 
            #Replace usr_omsEnabled_TorF
                elsif ($line =~ m[usr_omsEnabled_TorF]) {
                    if ($args{-usr_omsEnabled_TorF}) {
                    $line =~ s/usr_omsEnabled_TorF/$args{-usr_omsEnabled_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_omsEnabled_TorF: $args{-usr_omsEnabled_TorF} \n");
                    } else {
                        $line =~ s/usr_omsEnabled_TorF/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_omsEnabled_TorF \n");
                    }
                } 
            #Replace usr_mime1
                elsif ($line =~ m[usr_mime1]) {
                    if ($args{-usr_mime1}) {
                    $line =~ s/usr_mime1/$args{-usr_mime1}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime1: $args{-usr_mime1} \n");
                    } else {
                        $line =~ s/usr_mime1/ESN5/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime1 \n");
                    }
                }	
            #Replace usr_mime2
                elsif ($line =~ m[usr_mime2]) {
                    if ($args{-usr_mime2}) {
                    $line =~ s/usr_mime2/$args{-usr_mime2}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime2: $args{-usr_mime2} \n");
                    } else {
                        $line =~ s/usr_mime2/CUG/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime2 \n");
                    }
                }
            #Replace usr_mime3
                elsif ($line =~ m[usr_mime3]) {
                    if ($args{-usr_mime3}) {
                    $line =~ s/usr_mime3/$args{-usr_mime3}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime3: $args{-usr_mime3} \n");
                    } else {
                        $line =~ s/usr_mime3/NSS/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime3 \n");
                    }
                }
            #Replace usr_mime4
                elsif ($line =~ m[usr_mime4]) {
                    if ($args{-usr_mime4}) {
                    $line =~ s/usr_mime4/$args{-usr_mime4}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime4: $args{-usr_mime4} \n");
                    } else {
                        $line =~ s/usr_mime4/MCDN/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime4 \n");
                    }
                }
            #Replace usr_mime5
                elsif ($line =~ m[usr_mime5]) {
                    if ($args{-usr_mime5}) {
                    $line =~ s/usr_mime5/$args{-usr_mime5}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime5: $args{-usr_mime5} \n");
                    } else {
                        $line =~ s/usr_mime5/EPID/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime5 \n");
                    }
                }    
        }
        elsif ($xmlfile =~ /offlineSipPbx|restartSipPbx|busySipPbx/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_longName', '-usr_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_longName
                elsif ($line =~ m[usr_longName]) {
                    $line =~ s/usr_longName/$args{-usr_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_longName: $args{-usr_longName} \n");
                }
            #Replace usr_shortName
                elsif ($line =~ m[usr_shortName]) {
                    $line =~ s/usr_shortName/$args{-usr_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_shortName: $args{-usr_shortName} \n");
                }
       }
       elsif ($xmlfile =~ /addPbxRoute/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_sessionMgr_longName', '-usr_sessionMgr_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_callServer
                elsif ($line =~ m[usr_callServer]) {
                    $line =~ s/usr_callServer/$args{-usr_callServer}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callServer: $args{-usr_callServer} \n");
                }
            #Replace usr_ltid
                elsif ($line =~ m[usr_ltid]) {
                    $line =~ s/usr_ltid/$args{-usr_ltid}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ltid: $args{-usr_ltid} \n");
                }
            #Replace usr_sipPbx_longName
                if ($line =~ m[usr_sipPbx_longName]) {
                    $line =~ s/usr_sipPbx_longName/$args{-usr_sipPbx_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_longName: $args{-usr_sipPbx_longName} \n");
                }
            #Replace usr_sipPbx_shortName
                elsif ($line =~ m[usr_sipPbx_shortName]) {
                    $line =~ s/usr_sipPbx_shortName/$args{-usr_sipPbx_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_shortName: $args{-usr_sipPbx_shortName} \n");
                }
            #Replace usr_sessionMgr_longName
                elsif ($line =~ m[usr_sessionMgr_longName]) {
                    $line =~ s/usr_sessionMgr_longName/$args{-usr_sessionMgr_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_longName: $args{-usr_sessionMgr_longName} \n");
                }
            #Replace usr_sessionMgr_shortName
                elsif ($line =~ m[usr_sessionMgr_shortName]) {
                    $line =~ s/usr_sessionMgr_shortName/$args{-usr_sessionMgr_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_shortName: $args{-usr_sessionMgr_shortName} \n");
                } 
            #Replace usr_vmg
                elsif ($line =~ m[usr_vmg]) {
                    $line =~ s/usr_vmg/$args{-usr_vmg}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_vmg: $args{-usr_vmg} \n");
                }                
       }
       elsif ($xmlfile =~ /deletePbxRoute/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_sessionMgr_longName', '-usr_sessionMgr_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_callServer
                elsif ($line =~ m[usr_callServer]) {
                    $line =~ s/usr_callServer/$args{-usr_callServer}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callServer: $args{-usr_callServer} \n");
                }
            #Replace usr_ltid
                elsif ($line =~ m[usr_ltid]) {
                    $line =~ s/usr_ltid/$args{-usr_ltid}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ltid: $args{-usr_ltid} \n");
                }
            #Replace usr_sessionMgr_longName
                elsif ($line =~ m[usr_sessionMgr_longName]) {
                    $line =~ s/usr_sessionMgr_longName/$args{-usr_sessionMgr_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_longName: $args{-usr_sessionMgr_longName} \n");
                }
            #Replace usr_sessionMgr_shortName
                elsif ($line =~ m[usr_sessionMgr_shortName]) {
                    $line =~ s/usr_sessionMgr_shortName/$args{-usr_sessionMgr_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_shortName: $args{-usr_sessionMgr_shortName} \n");
                }              
       }
       elsif ($xmlfile =~ /addPbxDigitBasedRoute/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_sessionMgr_longName', '-usr_sessionMgr_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_callServer
                elsif ($line =~ m[usr_callServer]) {
                    $line =~ s/usr_callServer/$args{-usr_callServer}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callServer: $args{-usr_callServer} \n");
                }
            #Replace usr_fromDigit
                elsif ($line =~ m[usr_fromDigit]) {
                    $line =~ s/usr_fromDigit/$args{-usr_fromDigit}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_fromDigit: $args{-usr_fromDigit} \n");
                }    
            #Replace usr_ltid
                elsif ($line =~ m[usr_ltid]) {
                    $line =~ s/usr_ltid/$args{-usr_ltid}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ltid: $args{-usr_ltid} \n");
                }
            #Replace usr_toDigit
                elsif ($line =~ m[usr_toDigit]) {
                    $line =~ s/usr_toDigit/$args{-usr_toDigit}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_toDigit: $args{-usr_toDigit} \n");
                }
            #Replace usr_sipPbx_longName
                elsif ($line =~ m[usr_sipPbx_longName]) {
                    $line =~ s/usr_sipPbx_longName/$args{-usr_sipPbx_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_longName: $args{-usr_sipPbx_longName} \n");
                }
            #Replace usr_sipPbx_shortName
                elsif ($line =~ m[usr_sipPbx_shortName]) {
                    $line =~ s/usr_sipPbx_shortName/$args{-usr_sipPbx_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_shortName: $args{-usr_sipPbx_shortName} \n");
                }    
            #Replace usr_sessionMgr_longName
                elsif ($line =~ m[usr_sessionMgr_longName]) {
                    $line =~ s/usr_sessionMgr_longName/$args{-usr_sessionMgr_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_longName: $args{-usr_sessionMgr_longName} \n");
                }
            #Replace usr_sessionMgr_shortName
                elsif ($line =~ m[usr_sessionMgr_shortName]) {
                    $line =~ s/usr_sessionMgr_shortName/$args{-usr_sessionMgr_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_shortName: $args{-usr_sessionMgr_shortName} \n");
                } 
            #Replace usr_vmg
                elsif ($line =~ m[usr_vmg]) {
                    $line =~ s/usr_vmg/$args{-usr_vmg}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_vmg: $args{-usr_vmg} \n");
                }     
       }
       elsif ($xmlfile =~ /deletePbxDigitBasedRoute/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_sessionMgr_longName', '-usr_sessionMgr_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_callServer
                elsif ($line =~ m[usr_callServer]) {
                    $line =~ s/usr_callServer/$args{-usr_callServer}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callServer: $args{-usr_callServer} \n");
                }
            #Replace usr_fromDigit
                elsif ($line =~ m[usr_fromDigit]) {
                    $line =~ s/usr_fromDigit/$args{-usr_fromDigit}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_fromDigit: $args{-usr_fromDigit} \n");
                }    
            #Replace usr_ltid
                elsif ($line =~ m[usr_ltid]) {
                    $line =~ s/usr_ltid/$args{-usr_ltid}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ltid: $args{-usr_ltid} \n");
                }
            #Replace usr_toDigit
                elsif ($line =~ m[usr_toDigit]) {
                    $line =~ s/usr_toDigit/$args{-usr_toDigit}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_toDigit: $args{-usr_toDigit} \n");
                }    
            #Replace usr_sessionMgr_longName
                elsif ($line =~ m[usr_sessionMgr_longName]) {
                    $line =~ s/usr_sessionMgr_longName/$args{-usr_sessionMgr_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_longName: $args{-usr_sessionMgr_longName} \n");
                }
            #Replace usr_sessionMgr_shortName
                elsif ($line =~ m[usr_sessionMgr_shortName]) {
                    $line =~ s/usr_sessionMgr_shortName/$args{-usr_sessionMgr_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_shortName: $args{-usr_sessionMgr_shortName} \n");
                }   
       }
       elsif ($xmlfile =~ /modifyCS2KSipPbx/i)
        {
            foreach ('-usr_domain', '-usr_CS2KSipPbx', '-usr_chargeDN', '-usr_username') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domain
                if ($line =~ m[usr_domain]) {
                    $line =~ s/usr_domain/$args{-usr_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
                }
            #Replace usr_CS2KSipPbx
                elsif ($line =~ m[usr_CS2KSipPbx]) {
                    $line =~ s/usr_CS2KSipPbx/$args{-usr_CS2KSipPbx}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_CS2KSipPbx: $args{-usr_CS2KSipPbx} \n");
                }
            #Replace usr_bchannelLimitControl_TorF
                elsif ($line =~ m[usr_bchannelLimitControl_TorF]) {
                    if ($args{-usr_bchannelLimitControl_TorF}) {
                    $line =~ s/usr_bchannelLimitControl_TorF/$args{-usr_bchannelLimitControl_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_bchannelLimitControl_TorF: $args{-usr_bchannelLimitControl_TorF} \n");
                    } else {
                        $line =~ s/usr_bchannelLimitControl_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_bchannelLimitControl_TorF \n");
                    }
                }    
            #Replace usr_chargeDN
                elsif ($line =~ m[usr_chargeDN]) {
                    $line =~ s/usr_chargeDN/$args{-usr_chargeDN}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_chargeDN: $args{-usr_chargeDN} \n");
                }
            #Replace usr_cliAsChargeNumber_TorF
                elsif ($line =~ m[usr_cliAsChargeNumber_TorF]) {
                    if ($args{-usr_cliAsChargeNumber_TorF}) { 
                    $line =~ s/usr_cliAsChargeNumber_TorF/$args{-usr_cliAsChargeNumber_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_cliAsChargeNumber_TorF: $args{-usr_cliAsChargeNumber_TorF} \n");
                    } else {
                        $line =~ s/usr_cliAsChargeNumber_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_cliAsChargeNumber_TorF \n");
                    }
                }    
            #Replace usr_connModeAllowed_TorF
                elsif ($line =~ m[usr_connModeAllowed_TorF]) {
                     if ($args{-usr_connModeAllowed_TorF}) {
                     $line =~ s/usr_connModeAllowed_TorF/$args{-usr_connModeAllowed_TorF}/;
                     $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_connModeAllowed_TorF: $args{-usr_connModeAllowed_TorF} \n");
                    } else {
                        $line =~ s/usr_connModeAllowed_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_connModeAllowed_TorF \n");
                    }
                }
            #Replace usr_defaultPEM
                elsif ($line =~ m[usr_defaultPEM]) {
                    if ($args{-usr_defaultPEM}) {
                    $line =~ s/usr_defaultPEM/\<defaultPEM xsi\:type\=\"sip\:DefaultPEMNKDO\"\>
               \<name xsi\:type\=\"soapenc:string\" xmlns\:soapenc=\"http\:\/\/schemas\.xmlsoap\.org\/soap\/encoding\/\"\>$args{-usr_defaultPEM}\<\/name\>
            \<\/defaultPEM\>/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_defaultPEM: $args{-usr_defaultPEM} \n");
                    } else {
                        $line =~ s/usr_defaultPEM/\<defaultPEM xsi\:type\=\"sip\:DefaultPEMNKDO\"\>
               \<name xsi\:type\=\"soapenc:string\" xmlns\:soapenc=\"http\:\/\/schemas\.xmlsoap\.org\/soap\/encoding\/\"\/\>
            \<\/defaultPEM\>/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_defaultPEM \n");
                }
                }
            #Replace usr_failCallOnUnresolvedRoute_TorF
                elsif ($line =~ m[usr_failCallOnUnresolvedRoute_TorF]) {
                    if ($args{-usr_failCallOnUnresolvedRoute_TorF}) {
                    $line =~ s/usr_failCallOnUnresolvedRoute_TorF/$args{-usr_failCallOnUnresolvedRoute_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_failCallOnUnresolvedRoute_TorF: $args{-usr_failCallOnUnresolvedRoute_TorF} \n");
                } else {
                    $line =~ s/usr_failCallOnUnresolvedRoute_TorF/false/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_failCallOnUnresolvedRoute_TorF \n");
                 }
                }
            #Replace usr_foreignDomain
                elsif ($line =~ m[usr_foreignDomain]) {
                    if ($args{-usr_foreignDomain}) {
                    $line =~ s/usr_foreignDomain/\<foreignDomain xsi\:type\=\"core\:ForeignDomainNaturalKeyDO\" xmlns\:core\=\"core\.data\.ws\.nortelnetworks\.com\"\>
               \<name xsi\:type\=\"soapenc\:string\" xmlns\:soapenc\=\"http\:\/\/schemas\.xmlsoap\.org\/soap\/encoding\/\"\>$args{-usr_foreignDomain}\<\/name\>
            \<\/foreignDomain\>/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_foreignDomain: $args{-usr_foreignDomain} \n");
                    } else {
                        $line =~ s/usr_foreignDomain/\<foreignDomain xsi\:type\=\"core\:ForeignDomainNaturalKeyDO\" xmlns\:core\=\"core\.data\.ws\.nortelnetworks\.com\"\>
               \<name xsi\:type\=\"soapenc\:string\" xmlns\:soapenc\=\"http\:\/\/schemas\.xmlsoap\.org\/soap\/encoding\/\"\/\>
            \<\/foreignDomain\>/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_foreignDomain \n");
                    }
                }
            #Replace usr_globalE164Support_TorF
                elsif ($line =~ m[usr_globalE164Support_TorF]) {
                    if ($args{-usr_globalE164Support_TorF}) {
                    $line =~ s/usr_globalE164Support_TorF/$args{-usr_globalE164Support_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_globalE164Support_TorF: $args{-usr_globalE164Support_TorF} \n");
                } else {
                    $line =~ s/usr_globalE164Support_TorF/false/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_globalE164Support_TorF \n");
                }
                }
            #Replace usr_homeCountry
                elsif ($line =~ m[usr_homeCountry]) {
                    if ($args{-usr_homeCountry}) {
                    $line =~ s/usr_homeCountry/$args{-usr_homeCountry}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_homeCountry: $args{-usr_homeCountry} \n");
                    } else {
                        $line =~ s/usr_homeCountry/US/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_homeCountry \n");
                    }
                }
            #Replace usr_homeLanguage
                elsif ($line =~ m[usr_homeLanguage]) {
                    if ($args{-usr_homeLanguage}) {
                    $line =~ s/usr_homeLanguage/$args{-usr_homeLanguage}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_homeLanguage: $args{-usr_homeLanguage} \n");
                    } else {
                        $line =~ s/usr_homeLanguage/en/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_homeLanguage \n");
                    }
                }
            #Replace usr_numberQualifierProfile
                elsif ($line =~ m[usr_numberQualifierProfile]) {
                    if ($args{-usr_numberQualifierProfile}) {
                    $line =~ s/usr_numberQualifierProfile/$args{-usr_numberQualifierProfile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberQualifierProfile: $args{-usr_numberQualifierProfile} \n");
                    } else {
                        $line =~ s/usr_numberQualifierProfile/NQforPBXS/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberQualifierProfile \n");
                    }
                }
            #Replace usr_ocnToHeaderInterworking_TorF
                elsif ($line =~ m[usr_ocnToHeaderInterworking_TorF]) {
                    if ($args{-usr_ocnToHeaderInterworking_TorF}) {
                    $line =~ s/usr_ocnToHeaderInterworking_TorF/$args{-usr_ocnToHeaderInterworking_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ocnToHeaderInterworking_TorF: $args{-usr_ocnToHeaderInterworking_TorF} \n");
                    } else {
                        $line =~ s/usr_ocnToHeaderInterworking_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ocnToHeaderInterworking_TorF \n");
                    }
                }
            #Replace usr_routingType
                elsif ($line =~ m[usr_routingType]) {
                    if ($args{-usr_routingType}) {
                    $line =~ s/usr_routingType/\<routingType xsi\:type\=\"sip\:RoutingTypeNKDO\"\>
               \<name xsi\:type\=\"soapenc\:string\" xmlns\:soapenc\=\"http\:\/\/schemas\.xmlsoap\.org\/soap\/encoding\/\"\>$args{-usr_routingType}\<\/name\>
            \<\/routingType\>/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_routingType: $args{-usr_routingType} \n");
                    } else {
                        $line =~ s/usr_routingType/\<routingType xsi\:type\=\"sip\:RoutingTypeNKDO\"\>
               \<name xsi\:type\=\"soapenc\:string\" xmlns\:soapenc\=\"http\:\/\/schemas\.xmlsoap\.org\/soap\/encoding\/\"\/\>
            \<\/routingType\>/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_routingType \n");
                    }
                }
            #Replace usr_supportedSipURI
                elsif ($line =~ m[usr_supportedSipURI]) {
                    if ($args{-usr_supportedSipURI}) {
                    $line =~ s/usr_supportedSipURI/$args{-usr_supportedSipURI}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_supportedSipURI: $args{-usr_supportedSipURI} \n");
                    } else {
                        $line =~ s/usr_supportedSipURI/\[username\]\@\[subscriberIP\]\:\[subscriberPort\]/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_supportedSipURI \n");
                    }
                }
            #Replace usr_telURI_TorF
                elsif ($line =~ m[usr_telURI_TorF]) {
                    if ($args{-usr_telURI_TorF}) {
                    $line =~ s/usr_telURI_TorF/$args{-usr_telURI_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_telURI_TorF: $args{-usr_telURI_TorF} \n");
                    } else {
                        $line =~ s/usr_telURI_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_telURI_TorF \n");
                    }
                }     
            #Replace usr_timezone
                elsif ($line =~ m[usr_timezone]) {
                    if ($args{-usr_timezone}) {
                    $line =~ s/usr_timezone/$args{-usr_timezone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_timezone: $args{-usr_timezone} \n");
                    } else {
                        $line =~ s/usr_timezone/Eastern Standard Time/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_timezone \n");
                    }
                }                
            #Replace usr_username
                elsif ($line =~ m[usr_username]) {
                    $line =~ s/usr_username/$args{-usr_username}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_username: $args{-usr_username} \n");
                }    
        }
        elsif ($xmlfile =~ /addPbxDefaultRoute|deletePbxDefaultRoute/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_sessionMgr_longName', '-usr_sessionMgr_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_callServer
                elsif ($line =~ m[usr_callServer]) {
                    $line =~ s/usr_callServer/$args{-usr_callServer}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callServer: $args{-usr_callServer} \n");
                }    
            #Replace usr_ltid
                elsif ($line =~ m[usr_ltid]) {
                    $line =~ s/usr_ltid/$args{-usr_ltid}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ltid: $args{-usr_ltid} \n");
                }
            #Replace usr_sessionMgr_longName
                elsif ($line =~ m[usr_sessionMgr_longName]) {
                    $line =~ s/usr_sessionMgr_longName/$args{-usr_sessionMgr_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_longName: $args{-usr_sessionMgr_longName} \n");
                }
            #Replace usr_sessionMgr_shortName
                elsif ($line =~ m[usr_sessionMgr_shortName]) {
                    $line =~ s/usr_sessionMgr_shortName/$args{-usr_sessionMgr_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_shortName: $args{-usr_sessionMgr_shortName} \n");
                }    
            #Replace usr_sipPbx_longName
                elsif ($line =~ m[usr_sipPbx_longName]) {
                    $line =~ s/usr_sipPbx_longName/$args{-usr_sipPbx_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_longName: $args{-usr_sipPbx_longName} \n");
                }
            #Replace usr_sipPbx_shortName
                elsif ($line =~ m[usr_sipPbx_shortName]) {
                    $line =~ s/usr_sipPbx_shortName/$args{-usr_sipPbx_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_shortName: $args{-usr_sipPbx_shortName} \n");
                }    
       }
        elsif ($xmlfile =~ /setBchLimitForDomain|removeMctSystemData/i)
        {
            #Replace usr_domain
                if ($line =~ m[usr_domain]) {
                    $line =~ s/usr_domain/$args{-usr_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain: $args{-usr_domain} \n");
                }
            #Replace usr_limit
                elsif ($line =~ m[usr_limit]) {
                    $line =~ s/usr_limit/$args{-usr_limit}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_limit: $args{-usr_limit} \n");
                }  
       }
        elsif ($xmlfile =~ /updateSipPbxStatic2tran/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_sipPbx_longName', '-usr_sipPbx_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_sipPbx_longName
                elsif ($line =~ m[usr_sipPbx_longName]) {
                    $line =~ s/usr_sipPbx_longName/$args{-usr_sipPbx_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_longName: $args{-usr_sipPbx_longName} \n");
                }
            #Replace usr_sipPbx_shortName
                elsif ($line =~ m[usr_sipPbx_shortName]) {
                    $line =~ s/usr_sipPbx_shortName/$args{-usr_sipPbx_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_shortName: $args{-usr_sipPbx_shortName} \n");
                }   
            #Replace usr_chargingTrusted_TorF
                elsif ($line =~ m[usr_chargingTrusted_TorF]) {
                    if ($args{-usr_chargingTrusted_TorF}) { 
                    $line =~ s/usr_chargingTrusted_TorF/$args{-usr_chargingTrusted_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_chargingTrusted_TorF: $args{-usr_chargingTrusted_TorF} \n");
                    } else {
                        $line =~ s/usr_chargingTrusted_TorF/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_chargingTrusted_TorF \n");
                    }
                }    
            #Replace usr_exemptDoSProtection_TorF
                elsif ($line =~ m[usr_exemptDoSProtection_TorF]) {
                     if ($args{-usr_exemptDoSProtection_TorF}) {
                     $line =~ s/usr_exemptDoSProtection_TorF/$args{-usr_exemptDoSProtection_TorF}/;
                     $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_exemptDoSProtection_TorF: $args{-usr_exemptDoSProtection_TorF} \n");
                    } else {
                        $line =~ s/usr_exemptDoSProtection_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_exemptDoSProtection_TorF \n");
                    }
                }
            #Replace usr_trusted_TorF
                elsif ($line =~ m[usr_trusted_TorF]) {
                    if ($args{-usr_trusted_TorF}) {
                    $line =~ s/usr_trusted_TorF/$args{-usr_trusted_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_trusted_TorF: $args{-usr_trusted_TorF} \n");
                    } else {
                        $line =~ s/usr_trusted_TorF/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_trusted_TorF \n");
                }
                }
            #Replace usr_ccmPritoSip
                elsif ($line =~ m[usr_ccmPritoSip]) {
                    if ($args{-usr_ccmPritoSip}) {
                    $line =~ s/usr_ccmPritoSip/$args{-usr_ccmPritoSip}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ccmPritoSip: $args{-usr_ccmPritoSip} \n");
                } else {
                    $line =~ s/usr_ccmPritoSip/default/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ccmPritoSip \n");
                 }
                }
            #Replace usr_ccmSiptoPri
                elsif ($line =~ m[usr_ccmSiptoPri]) {
                    if ($args{-usr_ccmSiptoPri}) {
                    $line =~ s/usr_ccmSiptoPri/$args{-usr_ccmSiptoPri}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ccmSiptoPri: $args{-usr_ccmSiptoPri} \n");
                    } else {
                        $line =~ s/usr_ccmSiptoPri/default/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ccmSiptoPri \n");
                    }
                }
            #Replace usr_dnsEnab_TorF
                elsif ($line =~ m[usr_dnsEnab_TorF]) {
                    if ($args{-usr_dnsEnab_TorF}) {
                    $line =~ s/usr_dnsEnab_TorF/$args{-usr_dnsEnab_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dnsEnab_TorF: $args{-usr_dnsEnab_TorF} \n");
                } else {
                    $line =~ s/usr_dnsEnab_TorF/false/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dnsEnab_TorF \n");
                }
                }
            #Replace usr_headerMapping
                elsif ($line =~ m[usr_headerMapping]) {
                    if ($args{-usr_headerMapping}) {
                    $line =~ s/usr_headerMapping/$args{-usr_headerMapping}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_headerMapping: $args{-usr_headerMapping} \n");
                    } else {
                        $line =~ s/usr_headerMapping/AutoTest/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_headerMapping \n");
                    }
                }
            #Replace usr_auditEnabled_TorF
                elsif ($line =~ m[usr_auditEnabled_TorF]) {
                    if ($args{-usr_auditEnabled_TorF}) {
                    $line =~ s/usr_auditEnabled_TorF/$args{-usr_auditEnabled_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditEnabled_TorF: $args{-usr_auditEnabled_TorF} \n");
                    } else {
                        $line =~ s/usr_auditEnabled_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditEnabled_TorF \n");
                    }
                }
            #Replace usr_auditPeriod
                elsif ($line =~ m[usr_auditPeriod]) {
                    if (($args{-usr_auditPeriod})) {
                    $line =~ s/usr_auditPeriod/$args{-usr_auditPeriod}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditPeriod: $args{-usr_auditPeriod} \n");
                    } else {
                        $line =~ s/usr_auditPeriod/20/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditPeriod \n");
                    }
                }
            #Replace usr_aytProfile
                elsif ($line =~ m[usr_aytProfile]) {
                    if ($args{-usr_aytProfile}) {
                    $line =~ s/usr_aytProfile/$args{-usr_aytProfile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_aytProfile: $args{-usr_aytProfile} \n");
                    } else {
                        $line =~ s/usr_aytProfile/defaultInfo/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_aytProfile \n");
                    }
                }
            #Replace usr_longAuditPeriod
                elsif ($line =~ m[usr_longAuditPeriod]) {
                    if ($args{-usr_auditPeriod}) {
                    $line =~ s/usr_longAuditPeriod/$args{-usr_auditPeriod}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_longAuditPeriod: $args{-usr_auditPeriod} \n");
                    } else {
                        $line =~ s/usr_longAuditPeriod/20/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditPeriod \n");
                    }
                }
                 
            #Replace usr_omsEnabled_TorF
                elsif ($line =~ m[usr_omsEnabled_TorF]) {
                    if ($args{-usr_omsEnabled_TorF}) {
                    $line =~ s/usr_omsEnabled_TorF/$args{-usr_omsEnabled_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_omsEnabled_TorF: $args{-usr_omsEnabled_TorF} \n");
                    } else {
                        $line =~ s/usr_omsEnabled_TorF/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_omsEnabled_TorF \n");
                    }
                }
            #Replace usr_mime1
                elsif ($line =~ m[usr_mime1]) {
                    if ($args{-usr_mime1}) {
                    $line =~ s/usr_mime1/$args{-usr_mime1}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime1: $args{-usr_mime1} \n");
                    } else {
                        $line =~ s/usr_mime1/ESN5/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime1 \n");
                    }
                }
            #Replace usr_mime2
                elsif ($line =~ m[usr_mime2]) {
                    if ($args{-usr_mime2}) {
                    $line =~ s/usr_mime2/$args{-usr_mime2}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime2: $args{-usr_mime2} \n");
                    } else {
                        $line =~ s/usr_mime2/CUG/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime2 \n");
                    }
                }
            #Replace usr_mime3
                elsif ($line =~ m[usr_mime3]) {
                    if ($args{-usr_mime3}) {
                    $line =~ s/usr_mime3/$args{-usr_mime3}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime3: $args{-usr_mime3} \n");
                    } else {
                        $line =~ s/usr_mime3/NSS/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime3 \n");
                    }
                }
            #Replace usr_mime4
                elsif ($line =~ m[usr_mime4]) {
                    if ($args{-usr_mime4}) {
                    $line =~ s/usr_mime4/$args{-usr_mime4}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime4: $args{-usr_mime4} \n");
                    } else {
                        $line =~ s/usr_mime4/MCDN/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime4 \n");
                    }
                }
            #Replace usr_mime5
                elsif ($line =~ m[usr_mime5]) {
                    if ($args{-usr_mime5}) {
                    $line =~ s/usr_mime5/$args{-usr_mime5}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime5: $args{-usr_mime5} \n");
                    } else {
                        $line =~ s/usr_mime5/EPID/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mime5 \n");
                    }
                }    
            #Replace usr_PBXenableTCPPortP_TorF
                elsif ($line =~ m[usr_PBXenableTCPPortP_TorF]) {
                    if ($args{-usr_PBXenableTCPPortP_TorF}) {
                    $line =~ s/usr_PBXenableTCPPortP_TorF/$args{-usr_PBXenableTCPPortP_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXenableTCPPortP_TorF: $args{-usr_PBXenableTCPPortP_TorF} \n");
                    }
                }
            #Replace usr_PBXenableTLSPortP_TorF
                elsif ($line =~ m[usr_PBXenableTLSPortP_TorF]) {
                    if ($args{-usr_PBXenableTLSPortP_TorF}) {
                    $line =~ s/usr_PBXenableTLSPortP_TorF/$args{-usr_PBXenableTLSPortP_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXenableTLSPortP_TorF: $args{-usr_PBXenableTLSPortP_TorF} \n");
                    }
                } 
            #Replace usr_PBXenableUDPPortP_TorF
                elsif ($line =~ m[usr_PBXenableUDPPortP_TorF]) {
                    if ($args{-usr_PBXenableUDPPortP_TorF}) {
                    $line =~ s/usr_PBXenableUDPPortP_TorF/$args{-usr_PBXenableUDPPortP_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXenableUDPPortP_TorF: $args{-usr_PBXenableUDPPortP_TorF} \n");
                    }
                }     
            #Replace usr_PBXportP
                elsif ($line =~ m[usr_PBXportP]) {
                    if ($args{-usr_PBXportP}) {
                    $line =~ s/usr_PBXportP/$args{-usr_PBXportP}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXportP: $args{-usr_PBXportP} \n");
                    } else {
                        $line =~ s/usr_PBXportP/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXportP \n");
                    }
                }
            #Replace usr_PBXnodeP
                elsif ($line =~ m[usr_PBXnodeP]) {
                    $line =~ s/usr_PBXnodeP/$args{-usr_PBXnodeP}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXnodeP: $args{-usr_PBXnodeP} \n");
                }  
            #Replace usr_PBXsipUDPPortP
                elsif ($line =~ m[usr_PBXsipUDPPortP]) {
                    $line =~ s/usr_PBXsipUDPPortP/$args{-usr_PBXsipUDPPortP}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXsipUDPPortP: $args{-usr_PBXsipUDPPortP} \n");
                }
            #Replace usr_PBXsipTCPPortP
                elsif ($line =~ m[usr_PBXsipTCPPortP]) {
                    $line =~ s/usr_PBXsipTCPPortP/$args{-usr_PBXsipTCPPortP}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXsipTCPPortP: $args{-usr_PBXsipTCPPortP} \n");
                }
            #Replace usr_PBXsipTLSPortP
                elsif ($line =~ m[usr_PBXsipTLSPortP]) {
                    $line =~ s/usr_PBXsipTLSPortP/$args{-usr_PBXsipTLSPortP}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXsipTLSPortP: $args{-usr_PBXsipTLSPortP} \n");
                } 
                 
            #Replace usr_PBXtransportGroupP
                elsif ($line =~ m[usr_PBXtransportGroupP]) {
                    if ($args{-usr_PBXtransportGroupP}) {
                    $line =~ s/usr_PBXtransportGroupP/$args{-usr_PBXtransportGroupP}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXtransportGroupP: $args{-usr_PBXtransportGroupP} \n");
                    } else {
                        $line =~ s/usr_PBXtransportGroupP/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXtransportGroupP \n");
                    }
                }
            #Replace usr_PBXenableTCPPortS_TorF
                elsif ($line =~ m[usr_PBXenableTCPPortS_TorF]) {
                    if ($args{-usr_PBXenableTCPPortS_TorF}) {
                    $line =~ s/usr_PBXenableTCPPortS_TorF/$args{-usr_PBXenableTCPPortS_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXenableTCPPortS_TorF: $args{-usr_PBXenableTCPPortS_TorF} \n");
                    }
                }
            #Replace usr_PBXenableTLSPortS_TorF
                elsif ($line =~ m[usr_PBXenableTLSPortS_TorF]) {
                    if ($args{-usr_PBXenableTLSPortS_TorF}) {
                    $line =~ s/usr_PBXenableTLSPortS_TorF/$args{-usr_PBXenableTLSPortS_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXenableTLSPortS_TorF: $args{-usr_PBXenableTLSPortS_TorF} \n");
                    }
                } 
            #Replace usr_PBXenableUDPPortS_TorF
                elsif ($line =~ m[usr_PBXenableUDPPortS_TorF]) {
                    if ($args{-usr_PBXenableUDPPortS_TorF}) {
                    $line =~ s/usr_PBXenableUDPPortS_TorF/$args{-usr_PBXenableUDPPortS_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXenableUDPPortS_TorF: $args{-usr_PBXenableUDPPortS_TorF} \n");
                    }
                }    
            #Replace usr_PBXportS
                elsif ($line =~ m[usr_PBXportS]) {
                    if ($args{-usr_PBXportS}) {
                    $line =~ s/usr_PBXportS/$args{-usr_PBXportS}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXportS: $args{-usr_PBXportS} \n");
                    } else {
                        $line =~ s/usr_PBXportS/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXportS \n");
                    }
                }
            #Replace usr_PBXnodeS
                elsif ($line =~ m[usr_PBXnodeS]) {
                    $line =~ s/usr_PBXnodeS/$args{-usr_PBXnodeS}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXnodeS: $args{-usr_PBXnodeS} \n");
                }    
            #Replace usr_PBXsipUDPPortS
                elsif ($line =~ m[usr_PBXsipUDPPortS]) {
                    $line =~ s/usr_PBXsipUDPPortS/$args{-usr_PBXsipUDPPortS}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXsipUDPPortS: $args{-usr_PBXsipUDPPortS} \n");
                }
            #Replace usr_PBXsipTCPPortS
                elsif ($line =~ m[usr_PBXsipTCPPortS]) {
                    $line =~ s/usr_PBXsipTCPPortS/$args{-usr_PBXsipTCPPortS}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXsipTCPPortS: $args{-usr_PBXsipTCPPortS} \n");
                }
             #Replace usr_PBXsipTLSPortS
                elsif ($line =~ m[usr_PBXsipTLSPortS]) {
                    $line =~ s/usr_PBXsipTLSPortS/$args{-usr_PBXsipTLSPortS}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXsipTLSPortS: $args{-usr_PBXsipTLSPortS} \n");
                }    
            #Replace usr_PBXtransportGroupS
                elsif ($line =~ m[usr_PBXtransportGroupS]) {
                    if ($args{-usr_PBXtransportGroupS}) {
                    $line =~ s/usr_PBXtransportGroupS/$args{-usr_PBXtransportGroupS}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXtransportGroupS: $args{-usr_PBXtransportGroupS} \n");
                    } else {
                        $line =~ s/usr_PBXtransportGroupS/0/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_PBXtransportGroupS \n");
                    }
                }                
        }
        elsif ($xmlfile =~ /modifySvcNode/i)
        {
            foreach ('-usr_nodeName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_nodeName
                if ($line =~ m[usr_nodeName]) {
                    $line =~ s/usr_nodeName/$args{-usr_nodeName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_nodeName: $args{-usr_nodeName} \n");
                }
            #Replace usr_behindnat_TorF
                elsif ($line =~ m[usr_behindnat_TorF]) {
                    if ($args{-usr_behindnat_TorF}) { 
                    $line =~ s/usr_behindnat_TorF/$args{-usr_behindnat_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_behindnat_TorF: $args{-usr_behindnat_TorF} \n");
                    } else {
                        $line =~ s/usr_behindnat_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_behindnat_TorF \n");
                    }
                }    
            #Replace usr_dualcli_TorF
                elsif ($line =~ m[usr_dualcli_TorF]) {
                     if ($args{-usr_dualcli_TorF}) {
                     $line =~ s/usr_dualcli_TorF/$args{-usr_dualcli_TorF}/;
                     $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dualcli_TorF: $args{-usr_dualcli_TorF} \n");
                    } else {
                        $line =~ s/usr_dualcli_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dualcli_TorF \n");
                    }
                }
            #Replace usr_externalDomain
                elsif ($line =~ m[usr_externalDomain]) {
                    if ($args{-usr_externalDomain}) {
                    $line =~ s/usr_externalDomain/$args{-usr_externalDomain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_externalDomain: $args{-usr_externalDomain} \n");
                    } else {
                        $line =~ s/usr_externalDomain/IP/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_externalDomain \n");
                }
                }
            #Replace usr_location
                elsif ($line =~ m[usr_location]) {
                    if ($args{-usr_location}) {
                    $line =~ s/usr_location/$args{-usr_location}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_location: $args{-usr_location} \n");
                } else {
                    $line =~ s/usr_location/Other/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_location \n");
                 }
                }
            #Replace usr_nodeType
                elsif ($line =~ m[usr_nodeType]) {
                    if ($args{-usr_nodeType}) {
                    $line =~ s/usr_nodeType/$args{-usr_nodeType}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_nodeType: $args{-usr_nodeType} \n");
                    } else {
                        $line =~ s/usr_nodeType/Unidentified/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_nodeType \n");
                    }
                }
            #Replace usr_ntIM_TorF
                elsif ($line =~ m[usr_ntIM_TorF]) {
                    if ($args{-usr_ntIM_TorF}) {
                    $line =~ s/usr_ntIM_TorF/$args{-usr_ntIM_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ntIM_TorF: $args{-usr_ntIM_TorF} \n");
                } else {
                    $line =~ s/usr_ntIM_TorF/false/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dnsEnab_TorF \n");
                }
                }
            #Replace usr_privacyEnabled_TorF
                elsif ($line =~ m[usr_privacyEnabled_TorF]) {
                    if ($args{-usr_privacyEnabled_TorF}) {
                    $line =~ s/usr_privacyEnabled_TorF/$args{-usr_privacyEnabled_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_privacyEnabled_TorF: $args{-usr_privacyEnabled_TorF} \n");
                    } else {
                        $line =~ s/usr_privacyEnabled_TorF/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_privacyEnabled_TorF \n");
                    }
                }
            #Replace usr_swaStatus
                elsif ($line =~ m[usr_swaStatus]) {
                    if ($args{-usr_swaStatus}) {
                    $line =~ s/usr_swaStatus/\<swaStatus xsi\:type\=\"soapenc:string\" xmlns\:soapenc\=\"http\:\/\/schemas\.xmlsoap\.org\/soap\/encoding\/\">$args{-usr_swaStatus}\<\/swaStatus\>/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_auditEnabled_TorF: $args{-usr_auditEnabled_TorF} \n");
                    } else {
                        $line =~ s/usr_swaStatus/<swaStatus xsi:type=\"soapenc:string\" xmlns:soapenc=\"http:\/\/schemas.xmlsoap.org\/soap\/encoding\/"\/>/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_swaStatus \n");
                    }
                }
            #Replace usr_topologyHidden_TorF
                elsif ($line =~ m[usr_topologyHidden_TorF]) {
                    if (($args{-usr_topologyHidden_TorF})) {
                    $line =~ s/usr_topologyHidden_TorF/$args{-usr_topologyHidden_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_topologyHidden_TorF: $args{-usr_topologyHidden_TorF} \n");
                    } else {
                        $line =~ s/usr_topologyHidden_TorF/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_topologyHidden_TorF \n");
                    }
                }          
        }
        elsif ($xmlfile =~ /addPbxTrunkBasedRoute/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_sessionMgr_longName', '-usr_sessionMgr_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_callServer
                elsif ($line =~ m[usr_callServer]) {
                    $line =~ s/usr_callServer/$args{-usr_callServer}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callServer: $args{-usr_callServer} \n");
                }
            #Replace usr_context
                elsif ($line =~ m[usr_context]) {
                    $line =~ s/usr_context/$args{-usr_context}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_context: $args{-usr_context} \n");
                }    
            #Replace usr_group
                elsif ($line =~ m[usr_group]) {
                    $line =~ s/usr_group/$args{-usr_group}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_group: $args{-usr_group} \n");
                }
            #Replace usr_ltid
                elsif ($line =~ m[usr_ltid]) {
                    $line =~ s/usr_ltid/$args{-usr_ltid}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ltid: $args{-usr_ltid} \n");
                }
            #Replace usr_sipPbx_longName
                elsif ($line =~ m[usr_sipPbx_longName]) {
                    $line =~ s/usr_sipPbx_longName/$args{-usr_sipPbx_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_longName: $args{-usr_sipPbx_longName} \n");
                }
            #Replace usr_sipPbx_shortName
                elsif ($line =~ m[usr_sipPbx_shortName]) {
                    $line =~ s/usr_sipPbx_shortName/$args{-usr_sipPbx_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_shortName: $args{-usr_sipPbx_shortName} \n");
                }    
            #Replace usr_sessionMgr_longName
                elsif ($line =~ m[usr_sessionMgr_longName]) {
                    $line =~ s/usr_sessionMgr_longName/$args{-usr_sessionMgr_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_longName: $args{-usr_sessionMgr_longName} \n");
                }
            #Replace usr_sessionMgr_shortName
                elsif ($line =~ m[usr_sessionMgr_shortName]) {
                    $line =~ s/usr_sessionMgr_shortName/$args{-usr_sessionMgr_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_shortName: $args{-usr_sessionMgr_shortName} \n");
                } 
            #Replace usr_vmg
                elsif ($line =~ m[usr_vmg]) {
                    $line =~ s/usr_vmg/$args{-usr_vmg}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_vmg: $args{-usr_vmg} \n");
                }     
       }
       elsif ($xmlfile =~ /deletePbxTrunkBasedRoute/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_sessionMgr_longName', '-usr_sessionMgr_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_callServer
                elsif ($line =~ m[usr_callServer]) {
                    $line =~ s/usr_callServer/$args{-usr_callServer}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callServer: $args{-usr_callServer} \n");
                }
            #Replace usr_context
                elsif ($line =~ m[usr_context]) {
                    $line =~ s/usr_context/$args{-usr_context}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_context: $args{-usr_context} \n");
                }    
            #Replace usr_group
                elsif ($line =~ m[usr_group]) {
                    $line =~ s/usr_group/$args{-usr_group}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_group: $args{-usr_group} \n");
                }
            #Replace usr_ltid
                elsif ($line =~ m[usr_ltid]) {
                    $line =~ s/usr_ltid/$args{-usr_ltid}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ltid: $args{-usr_ltid} \n");
                }   
            #Replace usr_sessionMgr_longName
                elsif ($line =~ m[usr_sessionMgr_longName]) {
                    $line =~ s/usr_sessionMgr_longName/$args{-usr_sessionMgr_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_longName: $args{-usr_sessionMgr_longName} \n");
                }
            #Replace usr_sessionMgr_shortName
                elsif ($line =~ m[usr_sessionMgr_shortName]) {
                    $line =~ s/usr_sessionMgr_shortName/$args{-usr_sessionMgr_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_shortName: $args{-usr_sessionMgr_shortName} \n");
                }    
       }
        elsif ($xmlfile =~ /modifySystemDataForAdhoc/i)
        {
            foreach ('-usr_displayMode', '-usr_entryExitTones_ToF','-usr_maxNumOfParticipants',
                        '-usr_originatorReleaseEndsConf_ToF', '-usr_sendAccountingInfo_ToF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace usr_displayMode
            if ($line =~ m[usr_displayMode]) {
                $line =~ s/usr_displayMode/$args{-usr_displayMode}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_displayMode: $args{-usr_displayMode} in $xmlfile \n");
            }
        #Replace usr_entryExitTones_ToF
            elsif ($line =~ m[usr_entryExitTones_ToF]) {
                $line =~ s/usr_entryExitTones_ToF/$args{-usr_entryExitTones_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_entryExitTones_ToF: $args{-usr_entryExitTones_ToF} in $xmlfile \n");
            }
        #Replace usr_maxNumOfParticipants
            elsif ($line =~ m[usr_maxNumOfParticipants]) {
                $line =~ s/usr_maxNumOfParticipants/$args{-usr_maxNumOfParticipants}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxNumOfParticipants: $args{-usr_maxNumOfParticipants} in $xmlfile \n");
            } 
        #Replace usr_originatorReleaseEndsConf_ToF
            elsif ($line =~ m[usr_originatorReleaseEndsConf_ToF]) {
                $line =~ s/usr_originatorReleaseEndsConf_ToF/$args{-usr_originatorReleaseEndsConf_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_originatorReleaseEndsConf_ToF: $args{-usr_originatorReleaseEndsConf_ToF} in $xmlfile \n");
            }
        #Replace usr_sendAccountingInfo_ToF
            elsif ($line =~ m[usr_sendAccountingInfo_ToF]) {
                $line =~ s/usr_sendAccountingInfo_ToF/$args{-usr_sendAccountingInfo_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sendAccountingInfo_ToF: $args{-usr_sendAccountingInfo_ToF} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addSystemProfileAdhoc/i)
        {
            foreach ('-usr_profileName', '-usr_adhocConfVSCEnabled_TorF','-usr_ports_int') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        #Replace usr_adhocConfVSCEnabled_TorF
            elsif ($line =~ m[usr_adhocConfVSCEnabled_TorF]) {
                $line =~ s/usr_adhocConfVSCEnabled_TorF/$args{-usr_adhocConfVSCEnabled_TorF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_adhocConfVSCEnabled_TorF: $args{-usr_adhocConfVSCEnabled_TorF} in $xmlfile \n");
            }
        #Replace usr_ports_int
            elsif ($line =~ m[usr_ports_int]) {
                $line =~ s/usr_ports_int/$args{-usr_ports_int}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ports_int: $args{-usr_ports_int} in $xmlfile \n");
            }        
        }
        elsif ($xmlfile =~ /setDomainsForSystemProfileAdhoc|removeDomainsFromSystemProfileAdhoc|setDomainsForSystemProfileAdvAddrBook|removeDomainsFromSystemProfileAdvAddrBook|setDomainsForSystemProfileAdvScr|removeDomainsFromSystemProfileAdvScr/i)
        {
            foreach ('-usr_profileName', '-usr_domainNames') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        #Replace usr_domainNames
            elsif ($line =~ m[Input Domains]) {
                foreach (@{$args{-usr_domainNames}}) {
                    print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
         			print OUT "</multiRef>";
                    print OUT "\n";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Set domain: $_ in $xmlfile \n");
                }
                next; 
            }      
        }
        elsif ($xmlfile =~ /removeUserProfileAdhocForUser|removeSystemProfileAdhocFromUser|removeSystemProfileAddressBookFromUser|removeSystemProfileAdvScrFromUser|removeSystemProfileAuthCodeFromUser|removeSystemProfileCallFwdFromUser|removeSystemProfileCrbtFromUser|removeSystemProfileAccCodeFromUser|removeAllRoutes/i)
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeSystemProfileAdhocConf|removeSystemProfileAdvAddrBook|removeSystemProfileAdvScreen|removeSystemProfileAuthCodes|removeSystemProfileCallForward|removeSystemProfileCRBT/) 
        {
            unless ($args{-usr_profileName}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        }	
        elsif ($xmlfile =~ /addSystemProfileAdvAddrBook/i) 
        {
            foreach ('-usr_profileName', '-usr_maxAddrBookEntries_int') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
		#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_maxAddrBookEntries_int
            elsif ($line =~ m[usr_maxAddrBookEntries_int]) {
                $line =~ s/usr_maxAddrBookEntries_int/$args{-usr_maxAddrBookEntries_int}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxAddrBookEntries_int: $args{-usr_maxAddrBookEntries_int} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addSystemProfileAdvSrc/i) 
        {
            foreach ('-usr_profileName', '-usr_busyRoutingEnabled_ToF', '-usr_maxRinglists_int', '-usr_maxRoutesPerUser_int', '-usr_maxTelNumPerRinglist_int',
                      '-usr_noAnswerRoutingEnabled_ToF', '-usr_notLoggedInRoutingEnabled_ToF', '-usr_presenceRoutingEnabled_ToF', '-usr_unreachableRoutingEnabled_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_busyRoutingEnabled_ToF
            elsif ($line =~ m[usr_busyRoutingEnabled_ToF]) {
                $line =~ s/usr_busyRoutingEnabled_ToF/$args{-usr_busyRoutingEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_busyRoutingEnabled_ToF: $args{-usr_busyRoutingEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_maxRinglists_int
            elsif ($line =~ m[usr_maxRinglists_int]) {
                $line =~ s/usr_maxRinglists_int/$args{-usr_maxRinglists_int}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxRinglists_int: $args{-usr_maxRinglists_int} in $xmlfile \n");
            }
            #Replace usr_maxRoutesPerUser_int
            elsif ($line =~ m[usr_maxRoutesPerUser_int]) {
                $line =~ s/usr_maxRoutesPerUser_int/$args{-usr_maxRoutesPerUser_int}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxRoutesPerUser_int: $args{-usr_maxRoutesPerUser_int} in $xmlfile \n");
            }
            #Replace usr_maxTelNumPerRinglist_int
            elsif ($line =~ m[usr_maxTelNumPerRinglist_int]) {
                $line =~ s/usr_maxTelNumPerRinglist_int/$args{-usr_maxTelNumPerRinglist_int}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxTelNumPerRinglist_int: $args{-usr_maxTelNumPerRinglist_int} in $xmlfile \n");
            }
            #Replace usr_noAnswerRoutingEnabled_ToF
            elsif ($line =~ m[usr_noAnswerRoutingEnabled_ToF]) {
                $line =~ s/usr_noAnswerRoutingEnabled_ToF/$args{-usr_noAnswerRoutingEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_noAnswerRoutingEnabled_ToF: $args{-usr_noAnswerRoutingEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_notLoggedInRoutingEnabled_ToF
            elsif ($line =~ m[usr_notLoggedInRoutingEnabled_ToF]) {
                $line =~ s/usr_notLoggedInRoutingEnabled_ToF/$args{-usr_notLoggedInRoutingEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_notLoggedInRoutingEnabled_ToF: $args{-usr_notLoggedInRoutingEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_presenceRoutingEnabled_ToF
            elsif ($line =~ m[usr_presenceRoutingEnabled_ToF]) {
                $line =~ s/usr_presenceRoutingEnabled_ToF/$args{-usr_presenceRoutingEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_presenceRoutingEnabled_ToF: $args{-usr_presenceRoutingEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_unreachableRoutingEnabled_ToF
            elsif ($line =~ m[usr_unreachableRoutingEnabled_ToF]) {
                $line =~ s/usr_unreachableRoutingEnabled_ToF/$args{-usr_unreachableRoutingEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_unreachableRoutingEnabled_ToF: $args{-usr_unreachableRoutingEnabled_ToF} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addAuthCode/i) 
        {
            foreach ('-usr_authCodeName', '-usr_denyAllOutgoingCalls_ToF', '-usr_international_ToF', '-usr_local_ToF', '-usr_longDistanceInterRateArea_ToF',
                      '-usr_longDistanceIntraRateArea_ToF', '-usr_premium_ToF', '-usr_authCodeValue')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_authCodeName
            if ($line =~ m[usr_authCodeName]) {
                $line =~ s/usr_authCodeName/$args{-usr_authCodeName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_authCodeName: $args{-usr_authCodeName} in $xmlfile \n");
            }
            #Replace usr_denyAllOutgoingCalls_ToF
            elsif ($line =~ m[usr_denyAllOutgoingCalls_ToF]) {
                $line =~ s/usr_denyAllOutgoingCalls_ToF/$args{-usr_denyAllOutgoingCalls_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_denyAllOutgoingCalls_ToF: $args{-usr_denyAllOutgoingCalls_ToF} in $xmlfile \n");
            }
            #Replace usr_international_ToF
            elsif ($line =~ m[usr_international_ToF]) {
                $line =~ s/usr_international_ToF/$args{-usr_international_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_international_ToF: $args{-usr_international_ToF} in $xmlfile \n");
            }
            #Replace usr_local_ToF
            elsif ($line =~ m[usr_local_ToF]) {
                $line =~ s/usr_local_ToF/$args{-usr_local_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_local_ToF: $args{-usr_local_ToF} in $xmlfile \n");
            }
            #Replace usr_longDistanceInterRateArea_ToF
            elsif ($line =~ m[usr_longDistanceInterRateArea_ToF]) {
                $line =~ s/usr_longDistanceInterRateArea_ToF/$args{-usr_longDistanceInterRateArea_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_longDistanceInterRateArea_ToF: $args{-usr_longDistanceInterRateArea_ToF} in $xmlfile \n");
            }
            #Replace usr_longDistanceIntraRateArea_ToF
            elsif ($line =~ m[usr_longDistanceIntraRateArea_ToF]) {
                $line =~ s/usr_longDistanceIntraRateArea_ToF/$args{-usr_longDistanceIntraRateArea_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_longDistanceIntraRateArea_ToF: $args{-usr_longDistanceIntraRateArea_ToF} in $xmlfile \n");
            }
            #Replace usr_notLoggedInRoutingEnabled_ToF
            elsif ($line =~ m[usr_notLoggedInRoutingEnabled_ToF]) {
                $line =~ s/usr_notLoggedInRoutingEnabled_ToF/$args{-usr_notLoggedInRoutingEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_notLoggedInRoutingEnabled_ToF: $args{-usr_notLoggedInRoutingEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_premium_ToF
            elsif ($line =~ m[usr_premium_ToF]) {
                $line =~ s/usr_premium_ToF/$args{-usr_premium_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_premium_ToF: $args{-usr_premium_ToF} in $xmlfile \n");
            }
            #Replace usr_authCodeValue
            elsif ($line =~ m[usr_authCodeValue]) {
                $line =~ s/usr_authCodeValue/$args{-usr_authCodeValue}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_authCodeValue: $args{-usr_authCodeValue} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addSystemProfileAuthCode/i) 
        {
            foreach ('-usr_profileName', '-usr_authCodeName')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_authCodeName
            elsif ($line =~ m[usr_authCodeName]) {
                $line =~ s/usr_authCodeName/$args{-usr_authCodeName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_authCodeName: $args{-usr_authCodeName} in $xmlfile \n");
            } 
        }
        elsif ($xmlfile =~ /removeAuthCode/i) 
        {
            unless ($args{-usr_authCodeName}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
            #Replace usr_authCodeName
            if ($line =~ m[usr_authCodeName]) {
                $line =~ s/usr_authCodeName/$args{-usr_authCodeName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_authCodeName: $args{-usr_authCodeName} in $xmlfile \n");
            } 
        }
        elsif ($xmlfile =~ /addSystemProfileCallFwd/i) 
        {
            foreach ('-usr_profileName', '-usr_callfwdBusyEnabled_ToF', '-usr_callfwdImmediateEnabled_ToF', '-usr_callfwdNoAnswerEnabled_ToF', 
                      '-usr_callfwdNotLoggedInEnabled_ToF', '-usr_callfwdUnreachableEnabled_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_callfwdBusyEnabled_ToF
            elsif ($line =~ m[usr_callfwdBusyEnabled_ToF]) {
                $line =~ s/usr_callfwdBusyEnabled_ToF/$args{-usr_callfwdBusyEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callfwdBusyEnabled_ToF: $args{-usr_callfwdBusyEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_callfwdImmediateEnabled_ToF
            elsif ($line =~ m[usr_callfwdImmediateEnabled_ToF]) {
                $line =~ s/usr_callfwdImmediateEnabled_ToF/$args{-usr_callfwdImmediateEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callfwdImmediateEnabled_ToF: $args{-usr_callfwdImmediateEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_callfwdNoAnswerEnabled_ToF
            elsif ($line =~ m[usr_callfwdNoAnswerEnabled_ToF]) {
                $line =~ s/usr_callfwdNoAnswerEnabled_ToF/$args{-usr_callfwdNoAnswerEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callfwdNoAnswerEnabled_ToF: $args{-usr_callfwdNoAnswerEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_callfwdNotLoggedInEnabled_ToF
            elsif ($line =~ m[usr_callfwdNotLoggedInEnabled_ToF]) {
                $line =~ s/usr_callfwdNotLoggedInEnabled_ToF/$args{-usr_callfwdNotLoggedInEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callfwdNotLoggedInEnabled_ToF: $args{-usr_callfwdNotLoggedInEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_callfwdUnreachableEnabled_ToF
            elsif ($line =~ m[usr_callfwdUnreachableEnabled_ToF]) {
                $line =~ s/usr_callfwdUnreachableEnabled_ToF/$args{-usr_callfwdUnreachableEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callfwdUnreachableEnabled_ToF: $args{-usr_callfwdUnreachableEnabled_ToF} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addSystemProfileCrbt/i) 
        {
            foreach ('-usr_profileName', '-usr_crbtPAEnabled_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_crbtPAEnabled_ToF
            elsif ($line =~ m[usr_crbtPAEnabled_ToF]) {
                $line =~ s/usr_crbtPAEnabled_ToF/$args{-usr_crbtPAEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_crbtPAEnabled_ToF: $args{-usr_crbtPAEnabled_ToF} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setDomainsForSystemProfileAuthCode|removeDomainsFromSystemProfileAuthCode|setDomainsForSystemProfileCallFwd|removeDomainsFromSystemProfileCallFwd|setDomainsForSystemProfileCrbt|removeDomainsFromSystemProfileCrbt/i)
        {
            foreach ('-usr_profileName', '-usr_domainNames') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
        #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        #Replace usr_domainNames
            elsif ($line =~ m[Input Domains]) {
                foreach (@{$args{-usr_domainNames}}) {
                    print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
         			print OUT "</multiRef>";
                    print OUT "\n";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Set domain: $_ in $xmlfile \n");
                }
                next; 
            }      
        }
        elsif ($xmlfile =~ /addSystemProfileCallPickup/i) 
        {
            foreach ('-usr_profileName', '-usr_directedCallPickupEnabled_ToF', '-usr_groupCallPickupEnabled_ToF', '-usr_targetedCallPickupEnabled_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_directedCallPickupEnabled_ToF
            elsif ($line =~ m[usr_directedCallPickupEnabled_ToF]) {
                $line =~ s/usr_directedCallPickupEnabled_ToF/$args{-usr_directedCallPickupEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_directedCallPickupEnabled_ToF: $args{-usr_directedCallPickupEnabled_ToF} in $xmlfile \n");
            }
			#Replace usr_groupCallPickupEnabled_ToF
			elsif ($line =~ m[usr_groupCallPickupEnabled_ToF]) {
                $line =~ s/usr_groupCallPickupEnabled_ToF/$args{-usr_groupCallPickupEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_groupCallPickupEnabled_ToF: $args{-usr_groupCallPickupEnabled_ToF} in $xmlfile \n");
            }
			#Replace usr_targetedCallPickupEnabled_ToF
			elsif ($line =~ m[usr_targetedCallPickupEnabled_ToF]) {
                $line =~ s/usr_targetedCallPickupEnabled_ToF/$args{-usr_targetedCallPickupEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_targetedCallPickupEnabled_ToF: $args{-usr_targetedCallPickupEnabled_ToF} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addSystemProfileCallReturn/i) 
        {
            foreach ('-usr_profileName', '-usr_callReturnDigit', '-usr_callReturnVSCEnabled_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_callReturnDigit
            elsif ($line =~ m[usr_callReturnDigit]) {
                $line =~ s/usr_callReturnDigit/$args{-usr_callReturnDigit}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callReturnDigit: $args{-usr_callReturnDigit} in $xmlfile \n");
            }
			#Replace usr_callReturnVSCEnabled_ToF
			elsif ($line =~ m[usr_callReturnVSCEnabled_ToF]) {
                $line =~ s/usr_callReturnVSCEnabled_ToF/$args{-usr_callReturnVSCEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callReturnVSCEnabled_ToF: $args{-usr_callReturnVSCEnabled_ToF} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addSystemProfileCallTypeBasedScreening/i) 
        {
            foreach ('-usr_profileName', '-usr_callTypeScrVSC_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_callTypeScrVSC_ToF
            elsif ($line =~ m[usr_callTypeScrVSC_ToF]) {
                $line =~ s/usr_callTypeScrVSC_ToF/$args{-usr_callTypeScrVSC_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callTypeScrVSC_ToF: $args{-usr_callTypeScrVSC_ToF} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addSystemProfileDenyAllCalls/i)
		{
            foreach ('-usr_profileName', '-usr_denyAllIncoming_ToF', '-usr_denyAllIncomingVSC_ToF', '-usr_denyAllOutgoing_ToF', '-usr_denyAllOutgoingVSC_ToF', '-usr_denyAllRoaming_ToF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_denyAllIncoming_ToF
            if ($line =~ m[usr_denyAllIncoming_ToF]) {
                $line =~ s/usr_denyAllIncoming_ToF/$args{-usr_denyAllIncoming_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_denyAllIncoming_ToF: $args{-usr_denyAllIncoming_ToF} in $xmlfile \n");
            }
            #Replace usr_denyAllIncomingVSC_ToF
            elsif ($line =~ m[usr_denyAllIncomingVSC_ToF]) {
                $line =~ s/usr_denyAllIncomingVSC_ToF/$args{-usr_denyAllIncomingVSC_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_denyAllIncomingVSC_ToF: $args{-usr_denyAllIncomingVSC_ToF} in $xmlfile \n");
            }
			#Replace usr_denyAllOutgoing_ToF
            elsif ($line =~ m[usr_denyAllOutgoing_ToF]) {
                $line =~ s/usr_denyAllOutgoing_ToF/$args{-usr_denyAllOutgoing_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_denyAllOutgoing_ToF: $args{-usr_denyAllOutgoing_ToF} in $xmlfile \n");
            }
			#Replace usr_denyAllOutgoingVSC_ToF
            elsif ($line =~ m[usr_denyAllOutgoingVSC_ToF]) {
                $line =~ s/usr_denyAllOutgoingVSC_ToF/$args{-usr_denyAllOutgoingVSC_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_denyAllOutgoingVSC_ToF: $args{-usr_denyAllOutgoingVSC_ToF} in $xmlfile \n");
            }
			#Replace usr_denyAllRoaming_ToF
            elsif ($line =~ m[usr_denyAllRoaming_ToF]) {
                $line =~ s/usr_denyAllRoaming_ToF/$args{-usr_denyAllRoaming_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_denyAllRoaming_ToF: $args{-usr_denyAllRoaming_ToF} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addSystemProfileSelectiveCallReject/i)
        {
            foreach ('-usr_profileName', '-usr_addInCallSCRList_ToF', '-usr_incomingSCR_ToF', '-usr_incomingSCRVSC_ToF', '-usr_outgoingSCR_ToF', '-usr_outgoingSCRVSC_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_addInCallSCRList_ToF
            if ($line =~ m[usr_addInCallSCRList_ToF]) {
                $line =~ s/usr_addInCallSCRList_ToF/$args{-usr_addInCallSCRList_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_addInCallSCRList_ToF: $args{-usr_addInCallSCRList_ToF} in $xmlfile \n");
            }
            #Replace usr_incomingSCR_ToF
            elsif ($line =~ m[usr_incomingSCR_ToF]) {
                $line =~ s/usr_incomingSCR_ToF/$args{-usr_incomingSCR_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_incomingSCR_ToF: $args{-usr_incomingSCR_ToF} in $xmlfile \n");
            }
			#Replace usr_incomingSCRVSC_ToF
            elsif ($line =~ m[usr_incomingSCRVSC_ToF]) {
                $line =~ s/usr_incomingSCRVSC_ToF/$args{-usr_incomingSCRVSC_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_incomingSCRVSC_ToF: $args{-usr_incomingSCRVSC_ToF} in $xmlfile \n");
            }
			#Replace usr_outgoingSCR_ToF
            elsif ($line =~ m[usr_outgoingSCR_ToF]) {
                $line =~ s/usr_outgoingSCR_ToF/$args{-usr_outgoingSCR_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_outgoingSCR_ToF: $args{-usr_outgoingSCR_ToF} in $xmlfile \n");
            }
			#Replace usr_outgoingSCRVSC_ToF
            elsif ($line =~ m[usr_outgoingSCRVSC_ToF]) {
                $line =~ s/usr_outgoingSCRVSC_ToF/$args{-usr_outgoingSCRVSC_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_outgoingSCRVSC_ToF: $args{-usr_outgoingSCRVSC_ToF} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addSystemProfileRingTone/i)
        {
            foreach ('-usr_profileName', '-usr_ringtoneNames')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
			#Replace usr_ringtoneNames
			elsif ($line =~ m[Input Domains]) {
				foreach (@{$args{-usr_ringtoneNames}}) {
					print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:RingToneNaturalKeyDO\" xmlns:ns3=\"ringtone.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
					$logger->debug(__PACKAGE__ . ".$sub_name: Set domain: '$_' in $xmlfile \n");
				}
				next; 
			}
        }
        elsif ($xmlfile =~ /setDomainsForSystemProfileCallPickup|removeDomainsFromSystemProfileCallPickup|setDomainsForSystemProfileCallReturn|removeDomainsFromSystemProfileCallReturn|setDomainsForSystemProfileCallTypeBasedScreening|removeDomainsFromSystemProfileCallTypeBasedScreening/i) 
        {
            foreach ('-usr_profileName', '-usr_domainNames') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
			
			#Replace usr_domainNames
			elsif ($line =~ m[Input Domains]) {
				foreach (@{$args{-usr_domainNames}}) {
					print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
					$logger->debug(__PACKAGE__ . ".$sub_name: Set domain: '$_' in $xmlfile \n");
				}
				next; 
			}      
        }
		elsif ($xmlfile =~ /setDomainsForSystemProfileDenyAllCalls|removeDomainsFromSystemProfileDenyAllCalls|setDomainsForSystemProfileSelectiveCallReject|removeDomainsFromSystemProfileSelectiveCallReject|setDomainsForSystemProfileRingTone|removeDomainsFromSystemProfileRingTone/i) 
        {
            foreach ('-usr_profileName', '-usr_domainNames') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
			
			#Replace usr_domainNames
			elsif ($line =~ m[Input Domains]) {
				foreach (@{$args{-usr_domainNames}}) {
					print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
					$logger->debug(__PACKAGE__ . ".$sub_name: Set domain: '$_' in $xmlfile \n");
				}
				next; 
			}      
        }
		elsif ($xmlfile =~ /setUserTeenRingToneTeenService/i) 
        {
            foreach ('-usr_user', '-usr_ringtoneName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
			#Replace usr_ringtoneName
            if ($line =~ m[usr_ringtoneName]) {
                $line =~ s/usr_ringtoneName/$args{-usr_ringtoneName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ringtoneName: $args{-usr_ringtoneName} in $xmlfile \n");
            }
			    
        }
        elsif ($xmlfile =~ /removeSystemProfileFromUserCallPickup|removeSystemProfileFromUserCallReturn|removeUserProfileCallReturn|removeUserProfileCallPickup|removeSystemProfileFromUserCallTypeBasedScreening/i) 
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
			#Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /removeSystemProfileFromUserDenyAllCalls|removeSystemProfileFromUserSelectiveCallReject|removeUserTeenRingToneTeenService/i) 
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
			#Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeSystemProfileCallPickup|removeSystemProfileCallReturn|removeSystemProfileCallTypeBasedScreening/)
        {
            unless ($args{-usr_profileName}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /removeSystemProfileDenyAllCalls|removeSystemProfileSelectiveCallReject|removeSystemProfileRingTone/)
        {
            unless ($args{-usr_profileName}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setCrbtFiles|setCrbtDomainData/i) 
        {
            foreach ('-usr_domainName', '-usr_pool', '-usr_fileName', '-usr_displayName')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domainName
            if ($line =~ m[usr_domainName]) {
                $line =~ s/usr_domainName/$args{-usr_domainName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domainName: $args{-usr_domainName} in $xmlfile \n");
            }
            #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} in $xmlfile \n");
            }
            #Replace usr_fileName
            elsif ($line =~ m[usr_fileName]) {
                $line =~ s/usr_fileName/$args{-usr_fileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_fileName: $args{-usr_fileName} in $xmlfile \n");
            }
            #Replace usr_displayName
            elsif ($line =~ m[usr_displayName]) {
                $line =~ s/usr_displayName/$args{-usr_displayName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_displayName: $args{-usr_displayName} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addAdvanceRouteCRBTonPA/i)
        {
            foreach ('-usr_users', '-usr_routeName', '-usr_active_TorF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                }
            #Replace usr_routeName
                elsif ($line =~ m[usr_routeName]) {
                    $line =~ s/usr_routeName/$args{-usr_routeName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_routeName: $args{-usr_routeName} \n");
                }
            #Replace usr_active_TorF
                elsif ($line =~ m[usr_active_TorF]) {
                    $line =~ s/usr_active_TorF/$args{-usr_active_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_active_TorF: $args{-usr_active_TorF} \n");
                }
            #Replace usr_termAction_TorF
                elsif ($line =~ m[usr_termAction_TorF]) {
                    $line =~ s/usr_termAction_TorF/$args{-usr_termAction_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_termAction_TorF: $args{-usr_termAction_TorF} \n");
                }
            #Replace usr_dests_TorF
                elsif ($line =~ m[usr_dests_TorF]) {
                    $line =~ s/usr_dests_TorF/$args{-usr_dests_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_dests_TorF: $args{-usr_dests_TorF} \n");
                } 
            #Replace usr_destsfirst_TorF
                elsif ($line =~ m[usr_destsfirst_TorF]) {
                    $line =~ s/usr_destsfirst_TorF/$args{-usr_destsfirst_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_destsfirst_TorF: $args{-usr_destsfirst_TorF} \n");
                }    
            #Replace usr_list_destsfirst
                elsif ($line =~ m[usr_list_destsfirst]) {
                    $line =~ s/usr_list_destsfirst/$args{-usr_list_destsfirst}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_destsfirst: $args{-usr_list_destsfirst} \n");
                }
            #Replace usr_numberofRings_first
                elsif ($line =~ m[usr_numberofRings_first]) {
                    $line =~ s/usr_numberofRings_first/$args{-usr_numberofRings_first}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberofRings_first: $args{-usr_numberofRings_first} \n");
                }
            #Replace usr_ringBackTone_first
                elsif ($line =~ m[usr_ringBackTone_first]) {
                    $line =~ s/usr_ringBackTone_first/$args{-usr_ringBackTone_first}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ringBackTone_first: $args{-usr_ringBackTone_first} \n");
                }    
            #Replace usr_destssecond_TorF
                elsif ($line =~ m[usr_destssecond_TorF]) {
                    $line =~ s/usr_destssecond_TorF/$args{-usr_destssecond_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_destssecond_TorF: $args{-usr_destssecond_TorF} \n");
                }    
            #Replace usr_list_destssecond
                elsif ($line =~ m[usr_list_destssecond]) {
                    $line =~ s/usr_list_destssecond/$args{-usr_list_destssecond}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_destssecond: $args{-usr_list_destssecond} \n");
                } 
            #Replace usr_numberofRings_second
                elsif ($line =~ m[usr_numberofRings_second]) {
                    $line =~ s/usr_numberofRings_second/$args{-usr_numberofRings_second}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberofRings_second: $args{-usr_numberofRings_second} \n");
                } 
            #Replace usr_ringBackTone_second
                elsif ($line =~ m[usr_ringBackTone_second]) {
                    $line =~ s/usr_ringBackTone_second/$args{-usr_ringBackTone_second}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ringBackTone_second: $args{-usr_ringBackTone_second} \n");
                }    
            #Replace usr_deststhird_TorF
                elsif ($line =~ m[usr_deststhird_TorF]) {
                    $line =~ s/usr_deststhird_TorF/$args{-usr_deststhird_TorF}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_deststhird_TorF: $args{-usr_deststhird_TorF} \n");
                }
            #Replace usr_list_deststhird
                elsif ($line =~ m[usr_list_deststhird]) {
                    $line =~ s/usr_list_deststhird/$args{-usr_list_deststhird}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_list_deststhird: $args{-usr_list_deststhird} \n");
                }
            #Replace usr_numberofRings_third
                elsif ($line =~ m[usr_numberofRings_third]) {
                    $line =~ s/usr_numberofRings_third/$args{-usr_numberofRings_third}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_numberofRings_third: $args{-usr_numberofRings_third} \n");
                } 
            #Replace usr_ringBackTone_third
                elsif ($line =~ m[usr_ringBackTone_third]) {
                    $line =~ s/usr_ringBackTone_third/$args{-usr_ringBackTone_third}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ringBackTone_third: $args{-usr_ringBackTone_third} \n");
                }    
           
        }
        elsif ($xmlfile =~ /removeAdvanceRouteCRBT/i)
        {
            foreach ('-usr_users', '-usr_crbtRouteName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_users
                if ($line =~ m[usr_users]) {
                    $line =~ s/usr_users/$args{-usr_users}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_users: $args{-usr_users} \n");
                }
            #Replace usr_crbtRouteName
                elsif ($line =~ m[usr_crbtRouteName]) {
                    $line =~ s/usr_crbtRouteName/$args{-usr_crbtRouteName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_crbtRouteName: $args{-usr_crbtRouteName} \n");
                }
        }
        elsif ($xmlfile =~ /removeCrbtDomainData/i) 
        {
            unless ($args{-usr_domainName}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
            #Replace usr_domainName
            if ($line =~ m[usr_domainName]) {
                $line =~ s/usr_domainName/$args{-usr_domainName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domainName: $args{-usr_domainName} in $xmlfile \n");
            } 
        }
        elsif ($xmlfile =~ /removeCrbtFile/i) 
        {
            foreach ('-usr_domainName', '-usr_pool', '-usr_fileName')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domainName
            if ($line =~ m[usr_domainName]) {
                $line =~ s/usr_domainName/$args{-usr_domainName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domainName: $args{-usr_domainName} in $xmlfile \n");
            }
            #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} in $xmlfile \n");
            }
            #Replace usr_fileName
            elsif ($line =~ m[usr_fileName]) {
                $line =~ s/usr_fileName/$args{-usr_fileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_fileName: $args{-usr_fileName} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeTimeBlockGroup/i) 
        {
            foreach ('-usr_user', '-usr_timeGroupName')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
            #Replace usr_timeGroupName
            elsif ($line =~ m[usr_timeGroupName]) {
                $line =~ s/usr_timeGroupName/$args{-usr_timeGroupName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_timeGroupName: $args{-usr_timeGroupName} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeAdhocConferencePool/i) 
        {
            foreach ('-usr_domainName', '-usr_poolName')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domainName
            if ($line =~ m[usr_domainName]) {
                $line =~ s/usr_domainName/$args{-usr_domainName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domainName: $args{-usr_domainName} in $xmlfile \n");
            }
            #Replace usr_poolName
            elsif ($line =~ m[usr_poolName]) {
                $line =~ s/usr_poolName/$args{-usr_poolName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_poolName: $args{-usr_poolName} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setCPLSystemData/i) 
        {
            foreach ('-usr_defaultRouteConvNoVMRings', '-usr_defaultRouteNoVMRings', '-usr_defaultRouteRings', '-usr_routeRingCycleTime')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_defaultRouteConvNoVMRings
            if ($line =~ m[usr_defaultRouteConvNoVMRings]) {
                $line =~ s/usr_defaultRouteConvNoVMRings/$args{-usr_defaultRouteConvNoVMRings}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_defaultRouteConvNoVMRings: $args{-usr_defaultRouteConvNoVMRings} in $xmlfile \n");
            }
            #Replace usr_defaultRouteNoVMRings
            elsif ($line =~ m[usr_defaultRouteNoVMRings]) {
                $line =~ s/usr_defaultRouteNoVMRings/$args{-usr_defaultRouteNoVMRings}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_defaultRouteNoVMRings: $args{-usr_defaultRouteNoVMRings} in $xmlfile \n");
            }
            #Replace usr_defaultRouteRings
            elsif ($line =~ m[usr_defaultRouteRings]) {
                $line =~ s/usr_defaultRouteRings/$args{-usr_defaultRouteRings}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_defaultRouteRings: $args{-usr_defaultRouteRings} in $xmlfile \n");
            }
            #Replace usr_routeRingCycleTime
            elsif ($line =~ m[usr_routeRingCycleTime]) {
                $line =~ s/usr_routeRingCycleTime/$args{-usr_routeRingCycleTime}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_routeRingCycleTime: $args{-usr_routeRingCycleTime} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /assignDomainPoolForIMChatroom|assignDomainPoolForMeetMeConf/i) 
        {
            foreach ('-usr_domainName', '-usr_pool')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domainName
            if ($line =~ m[usr_domainName]) {
                $line =~ s/usr_domainName/$args{-usr_domainName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domainName: $args{-usr_domainName} in $xmlfile \n");
            }
            #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeDomainPoolForMeetMeConf/i)
        {
            unless ($args{-usr_domain_name}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_domain_name
            if ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addSystemProfileNetworkCallWaitingDisable/i) 
        {
            foreach ('-usr_profileName', '-usr_ncwdPermanantVSCEnabled_ToF', '-usr_ncwdVSCEnabled_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_ncwdPermanantVSCEnabled_ToF
            elsif ($line =~ m[usr_ncwdPermanantVSCEnabled_ToF]) {
                $line =~ s/usr_ncwdPermanantVSCEnabled_ToF/$args{-usr_ncwdPermanantVSCEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ncwdPermanantVSCEnabled_ToF: $args{-usr_ncwdPermanantVSCEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_ncwdVSCEnabled_ToF
            elsif ($line =~ m[usr_ncwdVSCEnabled_ToF]) {
                $line =~ s/usr_ncwdVSCEnabled_ToF/$args{-usr_ncwdVSCEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ncwdVSCEnabled_ToF: $args{-usr_ncwdVSCEnabled_ToF} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setDomainsForSystemProfileNcwd|removeDomainsFromSystemProfileNcwd/i) 
        {
            foreach ('-usr_profileName', '-usr_domainNames')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_domainName
            elsif ($line =~ m[Input Domains]) {
				foreach (@{$args{-usr_domainNames}}) {
					print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
					$logger->debug(__PACKAGE__ . ".$sub_name: Set domains in $xmlfile \n");
				}
				next; 
			} 
        }
        elsif ($xmlfile =~ /removeUserProfileNcwdForUser|removeSystemProfileNcwdFromUser/i)
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeSystemProfileNetworkCallWaitingDisable|removeSystemProfleCallGrabber|removeSystemProfileCallPark|removeSystemProfileMultipleRegister/i)
        {
            unless ($args{-usr_profileName}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addSystemProfileCallGrabber/i)
        {
            foreach ('-usr_profileName', '-usr_fromRegisteredClients_ToF', '-usr_fromTrustedNodes_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_fromRegisteredClients_ToF
            elsif ($line =~ m[usr_fromRegisteredClients_ToF]) {
                $line =~ s/usr_fromRegisteredClients_ToF/$args{-usr_fromRegisteredClients_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_fromRegisteredClients_ToF: $args{-usr_fromRegisteredClients_ToF} in $xmlfile \n");
            }
            #Replace usr_fromTrustedNodes_ToF
            elsif ($line =~ m[usr_fromTrustedNodes_ToF]) {
                $line =~ s/usr_fromTrustedNodes_ToF/$args{-usr_fromTrustedNodes_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_fromTrustedNodes_ToF: $args{-usr_fromTrustedNodes_ToF} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addSystemProfileCallPark/i)
        {
            foreach ('-usr_profileName', '-usr_autoRetrieveEnabled_ToF', '-usr_mohOnGenLotEnabled_ToF', '-usr_autoRetrieveTimer_int')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_autoRetrieveEnabled_ToF
            elsif ($line =~ m[usr_autoRetrieveEnabled_ToF]) {
                $line =~ s/usr_autoRetrieveEnabled_ToF/$args{-usr_autoRetrieveEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_autoRetrieveEnabled_ToF: $args{-usr_autoRetrieveEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_mohOnGenLotEnabled_ToF
            elsif ($line =~ m[usr_mohOnGenLotEnabled_ToF]) {
                $line =~ s/usr_mohOnGenLotEnabled_ToF/$args{-usr_mohOnGenLotEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mohOnGenLotEnabled_ToF: $args{-usr_mohOnGenLotEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_autoRetrieveTimer_int
            elsif ($line =~ m[usr_autoRetrieveTimer_int]) {
                $line =~ s/usr_autoRetrieveTimer_int/$args{-usr_autoRetrieveTimer_int}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_autoRetrieveTimer_int: $args{-usr_autoRetrieveTimer_int} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addSystemProfileMultipleRegister/i)
        {
            foreach ('-usr_profileName', '-usr_maxLogins_int')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_maxLogins_int
            elsif ($line =~ m[usr_maxLogins_int]) {
                $line =~ s/usr_maxLogins_int/$args{-usr_maxLogins_int}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxLogins_int: $args{-usr_maxLogins_int} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setSystemProfileMultipleRegisterForUser|setSystemProfileVoicemailForUser/i)
        {
            foreach ('-usr_profileName', '-usr_user')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_user
            elsif ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setDomainsForSystemProfileCallGrabber|removeDomainsFromSystemProfileCallGrabber|setDomainsForSystemProfileCallPark|removeDomainsFromSystemProfileCallPark|setDomainsForSystemProfileMultipleRegister|removeDomainsFromSystemProfileMultipleRegister/i)
        {
            foreach ('-usr_profileName', '-usr_domainNames')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_domainName
            elsif ($line =~ m[Input Domains]) {
                foreach (@{$args{-usr_domainNames}}) {
                    print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
         			print OUT "</multiRef>";
                    print OUT "\n";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Set domain: $_ in $xmlfile \n");
                }
                next; 
            }
        }
        elsif ($xmlfile =~ /setUserProfileCallGrabForUser/i)
        {
            foreach ('-usr_user', '-usr_authorizedCallingPartyID')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_authorizedCallingPartyID
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
            #Replace usr_authorizedCallingPartyID
            elsif ($line =~ m[usr_authorizedCallingPartyID]) {
                $line =~ s/usr_authorizedCallingPartyID/$args{-usr_authorizedCallingPartyID}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_authorizedCallingPartyID: $args{-usr_authorizedCallingPartyID} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setMCTFiles/i)
        {
            foreach ('-usr_domain_name', '-usr_mct_files')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domain_name
            if ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
            #'Input MCT Files'
            elsif ($line =~ m[Input MCT Files]) {
                foreach (@{$args{-usr_mct_files}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:MctFileNaturalKeyDO\" xmlns:ns4=\"mct.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                    print OUT "</multiRef>";
                    print OUT "\n";
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: Input MCT Files in $xmlfile \n");
                next
            }
            
        }
        elsif ($xmlfile =~ /removeUserProfileCallGrabForUser|removeSystemProfileCallGrabFromUser|removeUserProfileCallParkForUser|removeSPCallParkFromUser|removeSystemProfileMultiRegFromUser|removeMCTUserData/i)
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setDefaultCUGForExternalUser/i)
        {
            foreach ('-usr_external_user', '-usr_domain_name', '-usr_closed_user_group')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_external_user
            if ($line =~ m[usr_external_user]) {
                $line =~ s/usr_external_user/$args{-usr_external_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_external_user: $args{-usr_external_user} in $xmlfile \n");
            }
            #Replace usr_domain_name
            elsif ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
            #Replace usr_closed_user_group
            elsif ($line =~ m[usr_closed_user_group]) {
                $line =~ s/usr_closed_user_group/$args{-usr_closed_user_group}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_closed_user_group: $args{-usr_closed_user_group} in $xmlfile \n");
            }
            
        }
        elsif ($xmlfile =~ /setCUGGroupCalls/i)
        {
            foreach ('-usr_domain_name', '-usr_closed_user_group')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_closed_user_group
            if ($line =~ m[usr_closed_user_group]) {
                $line =~ s/usr_closed_user_group/$args{-usr_closed_user_group}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_closed_user_group: $args{-usr_closed_user_group} in $xmlfile \n");
            }
            #Replace usr_domain_name
            elsif ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
            #Replace 'Input Group Calls'
            elsif ($line =~ m[Input Group Calls]) {
                if ($args{-usr_incCallEnabledGroups}) {
                    print OUT "<incCallEnabledGroups xsi:type=\"cug:ArrayOf_tns167_GroupNaturalKeyDO\" soapenc:arrayType=\"gro:GroupNaturalKeyDO[]\" xmlns:gro=\"group.data.ws.nortelnetworks.com\">";
                    foreach (@{$args{-usr_incCallEnabledGroups}}) {
                        print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns7:GroupNaturalKeyDO\" xmlns:ns7=\"group.data.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                        print OUT "</multiRef>"; 
                    }
                    print OUT "</incCallEnabledGroups>";
                    print OUT "\n";
                }
                if ($args{-usr_incCallDisabledGroups}) {
                    print OUT "<incCallDisabledGroups xsi:type=\"cug:ArrayOf_tns167_GroupNaturalKeyDO\" soapenc:arrayType=\"gro:GroupNaturalKeyDO[]\" xmlns:gro=\"group.data.ws.nortelnetworks.com\">";
                    foreach (@{$args{-usr_incCallDisabledGroups}}) {
                        print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns7:GroupNaturalKeyDO\" xmlns:ns7=\"group.data.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                        print OUT "</multiRef>";
                    }
                    print OUT "</incCallDisabledGroups>";
                    print OUT "\n";
                }
                if ($args{-usr_outCallEnabledGroups}) {
                    print OUT "<outCallEnabledGroups xsi:type=\"cug:ArrayOf_tns167_GroupNaturalKeyDO\" soapenc:arrayType=\"gro:GroupNaturalKeyDO[]\" xmlns:gro=\"group.data.ws.nortelnetworks.com\">";
                    foreach (@{$args{-usr_outCallEnabledGroups}}) {
                        print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns7:GroupNaturalKeyDO\" xmlns:ns7=\"group.data.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                        print OUT "</multiRef>";
                    }
                    print OUT "</outCallEnabledGroups>";
                    print OUT "\n";
                }
                if ($args{-usr_outCallDisabledGroups}) {
                    print OUT "<outCallDisabledGroups xsi:type=\"cug:ArrayOf_tns167_GroupNaturalKeyDO\" soapenc:arrayType=\"gro:GroupNaturalKeyDO[]\" xmlns:gro=\"group.data.ws.nortelnetworks.com\">";
                    foreach (@{$args{-usr_outCallDisabledGroups}}) {
                        print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns7:GroupNaturalKeyDO\" xmlns:ns7=\"group.data.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                        print OUT "</multiRef>";
                    }
                    print OUT "</outCallDisabledGroups>";
                    print OUT "\n";
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: Input group call in $xmlfile \n");
                next
            }
            
        }
        elsif ($xmlfile =~ /addGIACGroup/i)
        {
            foreach ('-usr_domain_name', '-usr_group_name', '-usr_group_dn') # optional: -usr_group_agents
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domain_name
            if ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
            #Replace usr_group_name
            elsif ($line =~ m[usr_group_name]) {
                $line =~ s/usr_group_name/$args{-usr_group_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_group_name: $args{-usr_group_name} in $xmlfile \n");
            }   
            elsif ($line =~ m[Input Group DN ]) {
                foreach (@{$args{-usr_group_dn}}) {
                    print OUT "<dirNumbers xsi:type=\"soapenc:string\">$_</dirNumbers> \n";
                }
                next;
            }
            elsif ($line =~ m[Input Group Agents]) {
                if ($args{-usr_group_agents}) {
                    print OUT "<agents xsi:type=\"giac:ArrayOfGIACAgentNaturalKeyDO\" soapenc:arrayType=\"giac:GIACAgentNaturalKeyDO[]\"> \n";
                    foreach (@{$args{-usr_group_agents}}) {
                        print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:GIACAgentNaturalKeyDO\" xmlns:ns4=\"giac.ws.genband.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">\n";
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>\n";
                        print OUT "</multiRef>\n";
                    }
                    print OUT "</agents>\n";
                }
                next;
            }
        }
        elsif ($xmlfile =~ /removeGIACGroup/i)
        {
            foreach ('-usr_domain_name', '-usr_group_name')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domain_name
            if ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
            #Replace usr_group_name
            elsif ($line =~ m[usr_group_name]) {
                $line =~ s/usr_group_name/$args{-usr_group_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_group_name: $args{-usr_group_name} in $xmlfile \n");
            }      
        }
        elsif ($xmlfile =~ /addSystemProfileAllowedClients/i)
        {
            foreach ('-usr_profileName', '-usr_mmOfficeClient_ToF', '-usr_pcClientSet_ToF', '-usr_pcClientVoice_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_mmOfficeClient_ToF
            elsif ($line =~ m[usr_mmOfficeClient_ToF]) {
                $line =~ s/usr_mmOfficeClient_ToF/$args{-usr_mmOfficeClient_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mmOfficeClient_ToF: $args{-usr_mmOfficeClient_ToF} in $xmlfile \n");
            }
            #Replace usr_pcClientSet_ToF
            elsif ($line =~ m[usr_pcClientSet_ToF]) {
                $line =~ s/usr_pcClientSet_ToF/$args{-usr_pcClientSet_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pcClientSet_ToF: $args{-usr_pcClientSet_ToF} in $xmlfile \n");
            }
            #Replace usr_pcClientVoice_ToF
            elsif ($line =~ m[usr_pcClientVoice_ToF]) {
                $line =~ s/usr_pcClientVoice_ToF/$args{-usr_pcClientVoice_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pcClientVoice_ToF: $args{-usr_pcClientVoice_ToF} in $xmlfile \n");
            }     
        }
        elsif ($xmlfile =~ /addSystemProfileInstantMessaging/i)
        {
            foreach ('-usr_profileName', '-usr_composing_ToF', '-usr_encrEnabled_ToF', '-usr_encrUseDomainData_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_composing_ToF
            elsif ($line =~ m[usr_composing_ToF]) {
                $line =~ s/usr_composing_ToF/$args{-usr_composing_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_composing_ToF: $args{-usr_composing_ToF} in $xmlfile \n");
            }
            #Replace usr_encrEnabled_ToF
            elsif ($line =~ m[usr_encrEnabled_ToF]) {
                $line =~ s/usr_encrEnabled_ToF/$args{-usr_encrEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_encrEnabled_ToF: $args{-usr_encrEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_encrUseDomainData_ToF
            elsif ($line =~ m[usr_encrUseDomainData_ToF]) {
                $line =~ s/usr_encrUseDomainData_ToF/$args{-usr_encrUseDomainData_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_encrUseDomainData_ToF: $args{-usr_encrUseDomainData_ToF} in $xmlfile \n");
            }     
        }
        elsif ($xmlfile =~ /setDomainDataForInstantMessage/i)
        {
            foreach ('-usr_domain_name', '-usr_encryptionEnabled_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domain_name
            if ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
            #Replace usr_encryptionEnabled_ToF
            elsif ($line =~ m[usr_encryptionEnabled_ToF]) {
                $line =~ s/usr_encryptionEnabled_ToF/$args{-usr_encryptionEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_encryptionEnabled_ToF: $args{-usr_encryptionEnabled_ToF} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeDomainDataForInstantMessage/i)
        {
            unless ($args{-usr_domain_name}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_domain_name
            if ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeSPAllowClientFromUser|removeSPInstantMessagingFromUser|removeSPMultiCallResFromUser|removeSPVoicemailFromUser/i)
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setDomainsForSPAllowedClients|removeDomainsFromSPAllowClient|setDomainsForSPInstantMessaging|removeDomainsFromSPInstantMessaging|setDomainsForSPMeetMeConf|removeDomainsFromSPMeetMeConf|removeDomainsFromSPMultiCallRes/i)
        {
            foreach ('-usr_profileName', '-usr_domainNames')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_domainName
            elsif ($line =~ m[Input Domains]) {
                foreach (@{$args{-usr_domainNames}}) {
                    print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
         			print OUT "</multiRef>";
                    print OUT "\n";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Set domain: $_ in $xmlfile \n");
                }
                next; 
            }
        }
        elsif ($xmlfile =~ /removeSystemProfileAllowClient|removeSystemProfileInstantMessaging|removeSystemProfileMeetMeConf|removeSystemProfileVoicemail/i)
        {
            unless ($args{-usr_profileName}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addSystemProfileMeetMeConf/i)
        {
            foreach ('-usr_profileName', '-usr_maxParticipants_int', '-usr_premiumConfEnabled_ToF', '-usr_videoConfEnabled_ToF', '-usr_webCollabEnabled_ToF', '-usr_audioRecordingEnabled_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_maxParticipants_int
            elsif ($line =~ m[usr_maxParticipants_int]) {
                $line =~ s/usr_maxParticipants_int/$args{-usr_maxParticipants_int}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxParticipants_int: $args{-usr_maxParticipants_int} in $xmlfile \n");
            }
            #Replace usr_premiumConfEnabled_ToF
            elsif ($line =~ m[usr_premiumConfEnabled_ToF]) {
                $line =~ s/usr_premiumConfEnabled_ToF/$args{-usr_premiumConfEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_premiumConfEnabled_ToF: $args{-usr_premiumConfEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_videoConfEnabled_ToF
            elsif ($line =~ m[usr_videoConfEnabled_ToF]) {
                $line =~ s/usr_videoConfEnabled_ToF/$args{-usr_videoConfEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_videoConfEnabled_ToF: $args{-usr_videoConfEnabled_ToF} in $xmlfile \n");
            }     
            #Replace usr_webCollabEnabled_ToF
            elsif ($line =~ m[usr_webCollabEnabled_ToF]) {
                $line =~ s/usr_webCollabEnabled_ToF/$args{-usr_webCollabEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_webCollabEnabled_ToF: $args{-usr_webCollabEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_audioRecordingEnabled_ToF
            elsif ($line =~ m[usr_audioRecordingEnabled_ToF]) {
                $line =~ s/usr_audioRecordingEnabled_ToF/$args{-usr_audioRecordingEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_audioRecordingEnabled_ToF: $args{-usr_audioRecordingEnabled_ToF} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setMeetMeDomainData/i)
        {
            foreach ('-usr_domain_name', '-usr_chairEndsConf_ToF', '-usr_imEnabled_ToF', '-usr_nameEnabled_ToF', '-usr_tonesEnabled', '-usr_operator_user_id')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domain_name
            if ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
            #Replace usr_chairEndsConf_ToF
            elsif ($line =~ m[usr_chairEndsConf_ToF]) {
                $line =~ s/usr_chairEndsConf_ToF/$args{-usr_chairEndsConf_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_chairEndsConf_ToF: $args{-usr_chairEndsConf_ToF} in $xmlfile \n");
            }
            #Replace usr_imEnabled_ToF
            elsif ($line =~ m[usr_imEnabled_ToF]) {
                $line =~ s/usr_imEnabled_ToF/$args{-usr_imEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_imEnabled_ToF: $args{-usr_imEnabled_ToF} in $xmlfile \n");
            }
            #Replace usr_nameEnabled_ToF
            elsif ($line =~ m[usr_nameEnabled_ToF]) {
                $line =~ s/usr_nameEnabled_ToF/$args{-usr_nameEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_nameEnabled_ToF: $args{-usr_nameEnabled_ToF} in $xmlfile \n");
            }     
            #Replace usr_tonesEnabled
            elsif ($line =~ m[usr_tonesEnabled]) {
                $line =~ s/usr_tonesEnabled/$args{-usr_tonesEnabled}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_tonesEnabled: $args{-usr_tonesEnabled} in $xmlfile \n");
            }
            #Replace usr_operator_user_id
            elsif ($line =~ m[usr_operator_user_id]) {
                $line =~ s/usr_operator_user_id/$args{-usr_operator_user_id}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_operator_user_id: $args{-usr_operator_user_id} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addMeetMeAlias/i)
        {
            foreach ('-usr_domain_name', '-usr_alias_name', '-usr_locate_name', '-usr_pool')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domain_name
            if ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
            #Replace usr_alias_name
            elsif ($line =~ m[usr_alias_name]) {
                $line =~ s/usr_alias_name/$args{-usr_alias_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alias_name: $args{-usr_alias_name} in $xmlfile \n");
            }
            #Replace usr_locate_name
            elsif ($line =~ m[usr_locate_name]) {
                $line =~ s/usr_locate_name/$args{-usr_locate_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_locate_name: $args{-usr_locate_name} in $xmlfile \n");
            }
            #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} in $xmlfile \n");
            }     
        }
        elsif ($xmlfile =~ /removeMeetMeAlias/i)
        {
            foreach ('-usr_domain_name', '-usr_alias_name')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domain_name
            if ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
            #Replace usr_alias_name
            elsif ($line =~ m[usr_alias_name]) {
                $line =~ s/usr_alias_name/$args{-usr_alias_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_alias_name: $args{-usr_alias_name} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /changeChairPinForMeetMe/i)
        {
            foreach ('-usr_user', '-usr_pin')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
            #Replace usr_pin
            elsif ($line =~ m[usr_pin]) {
                $line =~ s/usr_pin/$args{-usr_pin}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pin: $args{-usr_pin} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addBrandingFileBrandingAdminService|removeBrandingFileBrandingAdminService/i)
        {
            foreach ('-usr_domainName', '-usr_poolName', '-usr_fileName')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_domainName
            if ($line =~ m[usr_domainName]) {
                $line =~ s/usr_domainName/$args{-usr_domainName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domainName: $args{-usr_domainName} in $xmlfile \n");
            }
			#Replace usr_poolName
			elsif ($line =~ m[usr_poolName]) {
                $line =~ s/usr_poolName/$args{-usr_poolName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_poolName: $args{-usr_poolName} in $xmlfile \n");
            }
			#Replace usr_fileName
			elsif ($line =~ m[usr_fileName]) {
                $line =~ s/usr_fileName/$args{-usr_fileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_fileName: $args{-usr_fileName} in $xmlfile \n");
            }
			
        }
		elsif ($xmlfile =~ /addSystemProfileOIR/i)
        {
            foreach ('-usr_profileName', '-usr_permanent_ToF', '-usr_callidPrivacyEnabled_ToF', '-usr_mediaPrivacyEnabled_ToF', '-usr_callidRestrictionVSCEnabled_ToF', '-usr_callidPresentationVSCEnabled_ToF', '-usr_callidPermanentVSCEnabled_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_permanent_ToF
            if ($line =~ m[usr_permanent_ToF]) {
                $line =~ s/usr_permanent_ToF/$args{-usr_permanent_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_permanent_ToF: $args{-usr_permanent_ToF} in $xmlfile \n");
            }
            #Replace usr_callidPrivacyEnabled_ToF
            elsif ($line =~ m[usr_callidPrivacyEnabled_ToF]) {
                $line =~ s/usr_callidPrivacyEnabled_ToF/$args{-usr_callidPrivacyEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callidPrivacyEnabled_ToF: $args{-usr_callidPrivacyEnabled_ToF} in $xmlfile \n");
            }
			#Replace usr_mediaPrivacyEnabled_ToF
            elsif ($line =~ m[usr_mediaPrivacyEnabled_ToF]) {
                $line =~ s/usr_mediaPrivacyEnabled_ToF/$args{-usr_mediaPrivacyEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mediaPrivacyEnabled_ToF: $args{-usr_mediaPrivacyEnabled_ToF} in $xmlfile \n");
            }
			#Replace usr_callidRestrictionVSCEnabled_ToF
            elsif ($line =~ m[usr_callidRestrictionVSCEnabled_ToF]) {
                $line =~ s/usr_callidRestrictionVSCEnabled_ToF/$args{-usr_callidRestrictionVSCEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callidRestrictionVSCEnabled_ToF: $args{-usr_callidRestrictionVSCEnabled_ToF} in $xmlfile \n");
            }
			#Replace usr_callidPresentationVSCEnabled_ToF
            elsif ($line =~ m[usr_callidPresentationVSCEnabled_ToF]) {
                $line =~ s/usr_callidPresentationVSCEnabled_ToF/$args{-usr_callidPresentationVSCEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callidPresentationVSCEnabled_ToF: $args{-usr_callidPresentationVSCEnabled_ToF} in $xmlfile \n");
            }
			#Replace usr_callidPermanentVSCEnabled_ToF
            elsif ($line =~ m[usr_callidPermanentVSCEnabled_ToF]) {
                $line =~ s/usr_callidPermanentVSCEnabled_ToF/$args{-usr_callidPermanentVSCEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callidPermanentVSCEnabled_ToF: $args{-usr_callidPermanentVSCEnabled_ToF} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addSystemProfileTIR/i)
        {
            foreach ('-usr_profileName', '-usr_permanent_ToF', '-usr_callidPrivacyEnabled_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_permanent_ToF
            if ($line =~ m[usr_permanent_ToF]) {
                $line =~ s/usr_permanent_ToF/$args{-usr_permanent_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_permanent_ToF: $args{-usr_permanent_ToF} in $xmlfile \n");
            }
			#Replace usr_callidPrivacyEnabled_ToF
            elsif ($line =~ m[usr_callidPrivacyEnabled_ToF]) {
                $line =~ s/usr_callidPrivacyEnabled_ToF/$args{-usr_callidPrivacyEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callidPrivacyEnabled_ToF: $args{-usr_callidPrivacyEnabled_ToF} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /setDomainsForSystemProfileOIR|removeDomainsFromSystemProfileOIR|setDomainsForSystemProfileTIR|removeDomainsFromSystemProfileTIR/i) 
        {
            foreach ('-usr_profileName', '-usr_domainNames') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
			
			#Replace usr_domainNames
			elsif ($line =~ m[Input Domains]) {
				foreach (@{$args{-usr_domainNames}}) {
					print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
					$logger->debug(__PACKAGE__ . ".$sub_name: Set domain: '$_' in $xmlfile \n");
				}
				next; 
			}      
        }
		elsif ($xmlfile =~ /setSystemProfileForUserOIR/i) 
        {
            foreach ('-usr_user', '-usr_profileName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
			    
        }
		elsif ($xmlfile =~ /setUserProfileOIR/i) 
        {
            foreach ('-usr_user', '-usr_callidPrivacyEnabled_ToF') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
			#Replace usr_callidPrivacyEnabled_ToF
            if ($line =~ m[usr_callidPrivacyEnabled_ToF]) {
                $line =~ s/usr_callidPrivacyEnabled_ToF/$args{-usr_callidPrivacyEnabled_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callidPrivacyEnabled_ToF: $args{-usr_callidPrivacyEnabled_ToF} in $xmlfile \n");
            }
			    
        }
		elsif ($xmlfile =~ /removeSystemProfileFromUserOIR|removeSystemProfileFromUserTIR/i) 
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
			#Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /removeSystemProfileOIR|removeSystemProfileTIR/)
        {
            unless ($args{-usr_profileName}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /removeUserProfileOIR|removeUserProfileTIR/)
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
			#Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addSystemProfileNetworkCallLogs/i)
        {
            foreach ('-usr_profileName', '-usr_inbox', '-usr_outbox')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_inbox
            if ($line =~ m[usr_inbox]) {
                $line =~ s/usr_inbox/$args{-usr_inbox}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_inbox: $args{-usr_inbox} in $xmlfile \n");
            }
            #Replace usr_outbox
            elsif ($line =~ m[usr_outbox]) {
                $line =~ s/usr_outbox/$args{-usr_outbox}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_outbox: $args{-usr_outbox} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addSystemProfilePresence/i)
        {
            foreach ('-usr_profileName', '-usr_maxFriends', '-usr_reportInactive_ToF', '-usr_inactivityTimer', '-usr_reportOnPhone_ToF', '-usr_enhancedAuthorization_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_maxFriends
            if ($line =~ m[usr_maxFriends]) {
                $line =~ s/usr_maxFriends/$args{-usr_maxFriends}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxFriends: $args{-usr_maxFriends} in $xmlfile \n");
            }
            #Replace usr_reportInactive_ToF
            elsif ($line =~ m[usr_reportInactive_ToF]) {
                $line =~ s/usr_reportInactive_ToF/$args{-usr_reportInactive_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_reportInactive_ToF: $args{-usr_reportInactive_ToF} in $xmlfile \n");
            }
			#Replace usr_inactivityTimer
            elsif ($line =~ m[usr_inactivityTimer]) {
                $line =~ s/usr_inactivityTimer/$args{-usr_inactivityTimer}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_inactivityTimer: $args{-usr_inactivityTimer} in $xmlfile \n");
            }
			#Replace usr_reportOnPhone_ToF
            elsif ($line =~ m[usr_reportOnPhone_ToF]) {
                $line =~ s/usr_reportOnPhone_ToF/$args{-usr_reportOnPhone_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_reportOnPhone_ToF: $args{-usr_reportOnPhone_ToF} in $xmlfile \n");
            }
			#Replace usr_enhancedAuthorization_ToF
            elsif ($line =~ m[usr_enhancedAuthorization_ToF]) {
                $line =~ s/usr_enhancedAuthorization_ToF/$args{-usr_enhancedAuthorization_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_enhancedAuthorization_ToF: $args{-usr_enhancedAuthorization_ToF} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addSystemProfileSpeedDial/i)
        {
            foreach ('-usr_profileName', '-usr_digitType')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_digitType
            if ($line =~ m[usr_digitType]) {
                $line =~ s/usr_digitType/$args{-usr_digitType}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_digitType: $args{-usr_digitType} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addSystemProfileHotLine/i)
        {
            foreach ('-usr_profileName', '-usr_protectedHotline_ToF', '-usr_hotlineType', '-usr_hotlineIndicator')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_protectedHotline_ToF
            if ($line =~ m[usr_protectedHotline_ToF]) {
                $line =~ s/usr_protectedHotline_ToF/$args{-usr_protectedHotline_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_protectedHotline_ToF: $args{-usr_protectedHotline_ToF} in $xmlfile \n");
            }
			#Replace usr_hotlineType
            if ($line =~ m[usr_hotlineType]) {
                $line =~ s/usr_hotlineType/$args{-usr_hotlineType}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_hotlineType: $args{-usr_hotlineType} in $xmlfile \n");
            }
			#Replace usr_hotlineIndicator
            if ($line =~ m[usr_hotlineIndicator]) {
                $line =~ s/usr_hotlineIndicator/$args{-usr_hotlineIndicator}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_hotlineIndicator: $args{-usr_hotlineIndicator} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /setDomainsForSystemProfileNetworkCallLogs|removeDomainsFromSystemProfileNetworkCallLogs/i) 
        {
            foreach ('-usr_profileName', '-usr_domainNames') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
			
			#Replace usr_domainNames
			elsif ($line =~ m[Input Domains]) {
				foreach (@{$args{-usr_domainNames}}) {
					print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
					$logger->debug(__PACKAGE__ . ".$sub_name: Set domain: '$_' in $xmlfile \n");
				}
				next; 
			}      
        }
		elsif ($xmlfile =~ /setDomainsForSystemProfilePresence|removeDomainsFromSystemProfilePresence/i) 
        {
            foreach ('-usr_profileName', '-usr_domainNames') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
			
			#Replace usr_domainNames
			elsif ($line =~ m[Input Domains]) {
				foreach (@{$args{-usr_domainNames}}) {
					print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
					$logger->debug(__PACKAGE__ . ".$sub_name: Set domain: '$_' in $xmlfile \n");
				}
				next; 
			}      
        }
		elsif ($xmlfile =~ /setDomainsForSystemProfileSpeedDial|removeDomainsFromSystemProfileSpeedDial/i) 
        {
            foreach ('-usr_profileName', '-usr_domainNames') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
			
			#Replace usr_domainNames
			elsif ($line =~ m[Input Domains]) {
				foreach (@{$args{-usr_domainNames}}) {
					print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
					$logger->debug(__PACKAGE__ . ".$sub_name: Set domain: '$_' in $xmlfile \n");
				}
				next; 
			}      
        }
		elsif ($xmlfile =~ /setDomainsForSystemProfileHotLine|removeDomainsFromSystemProfileHotLine/i) 
        {
            foreach ('-usr_profileName', '-usr_domainNames') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
			
			#Replace usr_domainNames
			elsif ($line =~ m[Input Domains]) {
				foreach (@{$args{-usr_domainNames}}) {
					print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
					$logger->debug(__PACKAGE__ . ".$sub_name: Set domain: '$_' in $xmlfile \n");
				}
				next; 
			}      
        }
		elsif ($xmlfile =~ /setSystemProfileForUserNetworkCallLogs|setSystemProfileForUserSpeedDial/i) 
        {
            foreach ('-usr_user', '-usr_profileName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			#Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
			    
        }
		elsif ($xmlfile =~ /removeSystemProfileFromUserNetworkCallLogs|removeSystemProfileFromUserPresence|removeSystemProfileFromUserSpeedDial|removeSystemProfileFromUserHotLine/i) 
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
			#Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /removeSystemProfileNetworkCallLogs|removeSystemProfilePresence|removeSystemProfileSpeedDial|removeSystemProfileHotLine/)
        {
            unless ($args{-usr_profileName}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
			#Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /removeUserProfilePresence|removeUserProfileHotLine/)
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
			#Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addTreatmentFile|removeTreatmentFile/i)
        {
            foreach ('-usr_domain_name', '-usr_pool', '-usr_treatment_file')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domain_name
            if ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
            #Replace usr_treatment_file
            elsif ($line =~ m[usr_treatment_file]) {
                $line =~ s/usr_treatment_file/$args{-usr_treatment_file}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_treatment_file: $args{-usr_treatment_file} in $xmlfile \n");
            }
            #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} in $xmlfile \n");
            }     
        }
        elsif ($xmlfile =~ /addTreatmentGroup/i)
        {
            foreach ('-usr_domain_name', '-usr_treatment_group', '-usr_treatment_files', '-usr_pool', '-usr_repeat', '-usr_treatmentRoute', '-usr_treatmentReasons')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domain_name
            if ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
            #Replace usr_treatment_group
            elsif ($line =~ m[usr_treatment_group]) {
                $line =~ s/usr_treatment_group/$args{-usr_treatment_group}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_treatment_group: $args{-usr_treatment_group} in $xmlfile \n");
            }
            #Replace usr_pool
            elsif ($line =~ m[usr_pool]) {
                $line =~ s/usr_pool/$args{-usr_pool}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_pool: $args{-usr_pool} in $xmlfile \n");
            }
            #Replace usr_repeat
            elsif ($line =~ m[usr_repeat]) {
                $line =~ s/usr_repeat/$args{-usr_repeat}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_repeat: $args{-usr_repeat} in $xmlfile \n");
            }
            #Replace usr_treatmentRoute
            elsif ($line =~ m[usr_treatmentRoute]) {
                $line =~ s/usr_treatmentRoute/$args{-usr_treatmentRoute}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_treatmentRoute: $args{-usr_treatmentRoute} in $xmlfile \n");
            }
            #Replace usr_treatment_files
            elsif ($line =~ m[Input Treatment Files]) {
                foreach (@{$args{-usr_treatment_files}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns2:TrmtFileNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns2=\"treatment.ws.nortelnetworks.com\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
         			print OUT "</multiRef>";
                    print OUT "\n";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Select treatment file: $_ in $xmlfile \n");
                }
                next; 
            }
            #Replace usr_treatmentReasons
            elsif ($line =~ m[Input Treatment Reasons]) {
                foreach (@{$args{-usr_treatmentReasons}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns2:TrmtReasonNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns2=\"treatment.ws.nortelnetworks.com\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
         			print OUT "</multiRef>";
                    print OUT "\n";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Select treatment reason: $_ in $xmlfile \n");
                }
                next; 
            }
        }
        elsif ($xmlfile =~ /removeTreatmentGroup/i)
        {
            foreach ('-usr_domain_name', '-usr_treatment_group')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_domain_name
            if ($line =~ m[usr_domain_name]) {
                $line =~ s/usr_domain_name/$args{-usr_domain_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_domain_name: $args{-usr_domain_name} in $xmlfile \n");
            }
            #Replace usr_treatment_group
            elsif ($line =~ m[usr_treatment_group]) {
                $line =~ s/usr_treatment_group/$args{-usr_treatment_group}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_treatment_group: $args{-usr_treatment_group} in $xmlfile \n");
            }
        }
		elsif ($xmlfile =~ /addSystemProfileVideo/i)
        {
            foreach ('-usr_profileName', '-usr_h263Video_ToF', '-usr_h263plusVideo_ToF', '-usr_h264Video_ToF',
                        '-usr_maxBitrate_Int', '-usr_maxVideoHeight_Int', '-usr_maxVideoWidth_Int', '-usr_mpeg4Video_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_h263Video_ToF
            elsif ($line =~ m[usr_h263Video_ToF]) {
                $line =~ s/usr_h263Video_ToF/$args{-usr_h263Video_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_h263Video_ToF: $args{-usr_h263Video_ToF} in $xmlfile \n");
            }
            #Replace usr_h263plusVideo_ToF
            elsif ($line =~ m[usr_h263plusVideo_ToF]) {
                $line =~ s/usr_h263plusVideo_ToF/$args{-usr_h263plusVideo_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_h263plusVideo_ToF: $args{-usr_h263plusVideo_ToF} in $xmlfile \n");
            }
            #Replace usr_h264Video_ToF
            elsif ($line =~ m[usr_h264Video_ToF]) {
                $line =~ s/usr_h264Video_ToF/$args{-usr_h264Video_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_h264Video_ToF: $args{-usr_h264Video_ToF} in $xmlfile \n");
            }
            #Replace usr_maxBitrate_Int
            elsif ($line =~ m[usr_maxBitrate_Int]) {
                $line =~ s/usr_maxBitrate_Int/$args{-usr_maxBitrate_Int}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxBitrate_Int: $args{-usr_maxBitrate_Int} in $xmlfile \n");
            }
            #Replace usr_maxVideoHeight_Int
            elsif ($line =~ m[usr_maxVideoHeight_Int]) {
                $line =~ s/usr_maxVideoHeight_Int/$args{-usr_maxVideoHeight_Int}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxVideoHeight_Int: $args{-usr_maxVideoHeight_Int} in $xmlfile \n");
            }
            #Replace usr_maxVideoWidth_Int
            elsif ($line =~ m[usr_maxVideoWidth_Int]) {
                $line =~ s/usr_maxVideoWidth_Int/$args{-usr_maxVideoWidth_Int}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_maxVideoWidth_Int: $args{-usr_maxVideoWidth_Int} in $xmlfile \n");
            }
            #Replace usr_mpeg4Video_ToF
            elsif ($line =~ m[usr_mpeg4Video_ToF]) {
                $line =~ s/usr_mpeg4Video_ToF/$args{-usr_mpeg4Video_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_mpeg4Video_ToF: $args{-usr_mpeg4Video_ToF} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setDomainsForSystemProfileVideo|removeDomainsFromSPVideo/i)
        {
            foreach ('-usr_profileName', '-usr_domainNames')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_domainName
            elsif ($line =~ m[Input Domains]) {
                foreach (@{$args{-usr_domainNames}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
         			print OUT "</multiRef>";
                    print OUT "\n";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Set domain: $_ in $xmlfile \n");
                }
                next; 
            }
        }
        elsif ($xmlfile =~ /setUserVideoData/i)
        {
            foreach ('-usr_user', '-usr_preferredCodec')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
            #Replace usr_preferredCodec
            elsif ($line =~ m[usr_preferredCodec]) {
                $line =~ s/usr_preferredCodec/$args{-usr_preferredCodec}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_preferredCodec: $args{-usr_preferredCodec} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeSPVideoFromUser|removeUserVideoData/i)
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeSystemProfileVideo/i)
        {
            unless ($args{-usr_profileName}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /updateAddress/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_logicalName', '-usr_ipAddr') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_logicalName
                if ($line =~ m[usr_logicalName]) {
                    $line =~ s/usr_logicalName/$args{-usr_logicalName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_logicalName: $args{-usr_logicalName} \n");
                }
            #Replace usr_ipAddr
                elsif ($line =~ m[usr_ipAddr]) {
                    $line =~ s/usr_ipAddr/$args{-usr_ipAddr}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ipAddr: $args{-usr_ipAddr} \n");
                }
        }
        elsif ($xmlfile =~ /busyC20SipPbx|offlineC20SipPbx|rtsC20SipPbx|testC20SipPbx/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_sessionMgr_longName', '-usr_sessionMgr_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_sessionMgr_longName
                if ($line =~ m[usr_sessionMgr_longName]) {
                    $line =~ s/usr_sessionMgr_longName/$args{-usr_sessionMgr_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_longName: $args{-usr_sessionMgr_longName} \n");
                }
            #Replace usr_sessionMgr_shortName
                elsif ($line =~ m[usr_sessionMgr_shortName]) {
                    $line =~ s/usr_sessionMgr_shortName/$args{-usr_sessionMgr_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_shortName: $args{-usr_sessionMgr_shortName} \n");
                }
            #Replace usr_sipPbx_longName
                if ($line =~ m[usr_sipPbx_longName]) {
                    $line =~ s/usr_sipPbx_longName/$args{-usr_sipPbx_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_longName: $args{-usr_sipPbx_longName} \n");
                }
            #Replace usr_sipPbx_shortName
                elsif ($line =~ m[usr_sipPbx_shortName]) {
                    $line =~ s/usr_sipPbx_shortName/$args{-usr_sipPbx_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPbx_shortName: $args{-usr_sipPbx_shortName} \n");
                }
        }
        elsif ($xmlfile =~ /updateAcctStorageRule/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_Acct_longName', '-usr_Acct_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_Acct_longName
                if ($line =~ m[usr_Acct_longName]) {
                    $line =~ s/usr_Acct_longName/$args{-usr_Acct_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Acct_longName: $args{-usr_Acct_longName} \n");
                }
            #Replace usr_Acct_shortName
                elsif ($line =~ m[usr_Acct_shortName]) {
                    $line =~ s/usr_Acct_shortName/$args{-usr_Acct_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Acct_shortName: $args{-usr_Acct_shortName} \n");
                }
            #Replace usr_Acct_name
                if ($line =~ m[usr_Acct_name]) {
                    $line =~ s/usr_Acct_name/$args{-usr_Acct_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Acct_name: $args{-usr_Acct_name} \n");
                }
            #Replace usr_Acct_format
                elsif ($line =~ m[usr_Acct_format]) {
                    $line =~ s/usr_Acct_format/$args{-usr_Acct_format}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Acct_format: $args{-usr_Acct_format} \n");
                }
            #Replace usr_compression
                elsif ($line =~ m[usr_compression]) {
                    if ($args{-usr_compression}) { 
                    $line =~ s/usr_compression/$args{-usr_compression}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_compression: $args{-usr_compression} \n");
                    } else {
                        $line =~ s/usr_compression/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_compression \n");
                    }
                }
            #Replace usr_retentionSize
                elsif ($line =~ m[usr_retentionSize]) {
                    if ($args{-usr_retentionSize}) { 
                    $line =~ s/usr_retentionSize/$args{-usr_retentionSize}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_retentionSize: $args{-usr_retentionSize} \n");
                    } else {
                        $line =~ s/usr_retentionSize/10000/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_retentionSize \n");
                    }
                }
            #Replace usr_Enabled_retentionSize
                elsif ($line =~ m[usr_Enabled_retentionSize]) {
                    if ($args{-usr_Enabled_retentionSize}) { 
                    $line =~ s/usr_Enabled_retentionSize/$args{-usr_Enabled_retentionSize}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Enabled_retentionSize: $args{-usr_Enabled_retentionSize} \n");
                    } else {
                        $line =~ s/usr_Enabled_retentionSize/false/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Enabled_retentionSize \n");
                    }
                }
            #Replace usr_retention
                elsif ($line =~ m[usr_retention]) {
                    if ($args{-usr_retention}) { 
                    $line =~ s/usr_retention/$args{-usr_retention}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_retention: $args{-usr_retention} \n");
                    } else {
                        $line =~ s/usr_retention/7/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_retention \n");
                    }
                }
            #Replace usr_rotationPeriod
                elsif ($line =~ m[usr_rotationPeriod]) {
                    if ($args{-usr_rotationPeriod}) { 
                    $line =~ s/usr_rotationPeriod/$args{-usr_rotationPeriod}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_rotationPeriod: $args{-usr_rotationPeriod} \n");
                    } else {
                        $line =~ s/usr_rotationPeriod/100/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_rotationPeriod \n");
                    }
                }
            #Replace usr_Enabled_rotationPeriod
                elsif ($line =~ m[usr_Enabled_rotationPeriod]) {
                    if ($args{-usr_Enabled_rotationPeriod}) { 
                    $line =~ s/usr_Enabled_rotationPeriod/$args{-usr_Enabled_rotationPeriod}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Enabled_rotationPeriod: $args{-usr_Enabled_rotationPeriod} \n");
                    } else {
                        $line =~ s/usr_Enabled_rotationPeriod/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Enabled_rotationPeriod \n");
                    }
                }
            #Replace usr_rotationSize
                elsif ($line =~ m[usr_rotationSize]) {
                    if ($args{-usr_rotationSize}) { 
                    $line =~ s/usr_rotationSize/$args{-usr_rotationSize}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_rotationSize: $args{-usr_rotationSize} \n");
                    } else {
                        $line =~ s/usr_rotationSize/1000/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_rotationSize \n");
                    }
                }
            #Replace usr_Enabled_rotationSize
                elsif ($line =~ m[usr_Enabled_rotationSize]) {
                    if ($args{-usr_Enabled_rotationSize}) { 
                    $line =~ s/usr_Enabled_rotationSize/$args{-usr_Enabled_rotationSize}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Enabled_rotationSize: $args{-usr_Enabled_rotationSize} \n");
                    } else {
                        $line =~ s/usr_Enabled_rotationSize/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Enabled_rotationSize \n");
                    }
                }
        }
        elsif ($xmlfile =~ /enableAcctStorageRule|disableAcctStorageRule/i)
        {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_Acct_name') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_Acct_name
                if ($line =~ m[usr_Acct_name]) {
                    $line =~ s/usr_Acct_name/$args{-usr_Acct_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Acct_name: $args{-usr_Acct_name} \n");
                }
            #Replace usr_Acct_longName
                elsif ($line =~ m[usr_Acct_longName]) {
                    $line =~ s/usr_Acct_longName/$args{-usr_Acct_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Acct_longName: $args{-usr_Acct_longName} \n");
                }
            #Replace usr_Acct_shortName
                elsif ($line =~ m[usr_Acct_shortName]) {
                    $line =~ s/usr_Acct_shortName/$args{-usr_Acct_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Acct_shortName: $args{-usr_Acct_shortName} \n");
                }
            #Replace usr_Acct_longName
                elsif ($line =~ m[usr_Acct_longName]) {
                    $line =~ s/usr_Acct_longName/$args{-usr_Acct_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Acct_longName: $args{-usr_Acct_longName} \n");
                }
            #Replace usr_Acct_shortName
                elsif ($line =~ m[usr_Acct_shortName]) {
                    $line =~ s/usr_Acct_shortName/$args{-usr_Acct_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Acct_shortName: $args{-usr_Acct_shortName} \n");
                }
        }
        elsif ($xmlfile =~ /updateSessMgr/i) {
            foreach ('-usr_UserID', '-usr_SessionID', '-usr_sessionMgr_longName', '-usr_sessionMgr_shortName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_UserID
                if ($line =~ m[usr_UserID]) {
                    $line =~ s/usr_UserID/$args{-usr_UserID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_UserID: $args{-usr_UserID} \n");
                }
            #Replace usr_SessionID
                elsif ($line =~ m[usr_SessionID]) {
                    $line =~ s/usr_SessionID/$args{-usr_SessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SessionID: $args{-usr_SessionID} \n");
                }
            #Replace usr_sessionMgr_longName
                if ($line =~ m[usr_sessionMgr_longName]) {
                    $line =~ s/usr_sessionMgr_longName/$args{-usr_sessionMgr_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_longName: $args{-usr_sessionMgr_longName} \n");
                }
            #Replace usr_sessionMgr_shortName
                elsif ($line =~ m[usr_sessionMgr_shortName]) {
                    $line =~ s/usr_sessionMgr_shortName/$args{-usr_sessionMgr_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sessionMgr_shortName: $args{-usr_sessionMgr_shortName} \n");
                }
            #Replace usr_basrPort
                elsif ($line =~ m[usr_basrPort]) {
                    $line =~ s/usr_basrPort/$args{-usr_basrPort}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_basrPort: $args{-usr_basrPort} \n");
                }
            #Replace usr_serviceAddress
                elsif ($line =~ m[usr_serviceAddress]) {
                    $line =~ s/usr_serviceAddress/$args{-usr_serviceAddress}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_serviceAddress: $args{-usr_serviceAddress} \n");
                }
            #Replace usr_Fpm_longName
                elsif ($line =~ m[usr_Fpm_longName]) {
                    $line =~ s/usr_Fpm_longName/$args{-usr_Fpm_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Fpm_longName: $args{-usr_Fpm_longName} \n");
                }
            #Replace usr_Fpm_shortName
                elsif ($line =~ m[usr_Fpm_shortName]) {
                    $line =~ s/usr_Fpm_shortName/$args{-usr_Fpm_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Fpm_shortName: $args{-usr_Fpm_shortName} \n");
                }
            #Replace usr_Acct_longName
                elsif ($line =~ m[usr_Acct_longName]) {
                    $line =~ s/usr_Acct_longName/$args{-usr_Acct_longName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Acct_longName: $args{-usr_Acct_longName} \n");
                }
            #Replace usr_Acct_shortName
                elsif ($line =~ m[usr_Acct_shortName]) {
                    $line =~ s/usr_Acct_shortName/$args{-usr_Acct_shortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_Acct_shortName: $args{-usr_Acct_shortName} \n");
                }
            #Replace usr_callParkId
                elsif ($line =~ m[usr_callParkId]) {
                    if ($args{-usr_callParkId}) { 
                    $line =~ s/usr_callParkId/$args{-usr_callParkId}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callParkId: $args{-usr_callParkId} \n");
                    } else {
                        $line =~ s/usr_callParkId/1/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_callParkId \n");
                    }
                }
            #Replace usr_enableTCPPort
                elsif ($line =~ m[usr_enableTCPPort]) {
                    if ($args{-usr_enableTCPPort}) { 
                    $line =~ s/usr_enableTCPPort/$args{-usr_enableTCPPort}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_enableTCPPort: $args{-usr_enableTCPPort} \n");
                    } else {
                        $line =~ s/usr_enableTCPPort/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_enableTCPPort \n");
                    }
                }
            #Replace usr_enableTLSPort
                elsif ($line =~ m[usr_enableTLSPort]) {
                    if ($args{-usr_enableTLSPort}) { 
                    $line =~ s/usr_enableTLSPort/$args{-usr_enableTLSPort}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_enableTLSPort: $args{-usr_enableTLSPort} \n");
                    } else {
                        $line =~ s/usr_enableTLSPort/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_enableTLSPort \n");
                    }
                }
            #Replace usr_enableUDPPort
                elsif ($line =~ m[usr_enableUDPPort]) {
                    if ($args{-usr_enableUDPPort}) { 
                    $line =~ s/usr_enableUDPPort/$args{-usr_enableUDPPort}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_enableUDPPort: $args{-usr_enableUDPPort} \n");
                    } else {
                        $line =~ s/usr_enableUDPPort/true/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_enableUDPPort \n");
                    }
                }
            #Replace usr_sipPort
                elsif ($line =~ m[usr_sipPort]) {
                    if ($args{-usr_sipPort}) { 
                    $line =~ s/usr_sipPort/$args{-usr_sipPort}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPort: $args{-usr_sipPort} \n");
                    } else {
                        $line =~ s/usr_sipPort/5060/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipPort \n");
                    }
                }
            #Replace usr_sipTCPPort
                elsif ($line =~ m[usr_sipTCPPort]) {
                    if ($args{-usr_sipTCPPort}) { 
                    $line =~ s/usr_sipTCPPort/$args{-usr_sipTCPPort}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipTCPPort: $args{-usr_sipTCPPort} \n");
                    } else {
                        $line =~ s/usr_sipTCPPort/5060/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipTCPPort \n");
                    }
                }
            #Replace usr_sipTLSPort
                elsif ($line =~ m[usr_sipTLSPort]) {
                    if ($args{-usr_sipTLSPort}) { 
                    $line =~ s/usr_sipTLSPort/$args{-usr_sipTLSPort}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipTLSPort: $args{-usr_sipTLSPort} \n");
                    } else {
                        $line =~ s/usr_sipTLSPort/5061/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipTLSPort \n");
                    }
                }
            #Replace usr_sipUDPPort
                elsif ($line =~ m[usr_sipUDPPort]) {
                    if ($args{-usr_sipUDPPort}) { 
                    $line =~ s/usr_sipUDPPort/$args{-usr_sipUDPPort}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipUDPPort: $args{-usr_sipUDPPort} \n");
                    } else {
                        $line =~ s/usr_sipUDPPort/5060/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipUDPPort \n");
                    }
                }
            #Replace usr_externalNATAddr
                elsif ($line =~ m[usr_externalNATAddr]) {
                    if ($args{-usr_externalNATAddr}) { 
                    $line =~ s/usr_externalNATAddr/$args{-usr_externalNATAddr}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_externalNATAddr: $args{-usr_externalNATAddr} \n");
                    } else {
                        $line =~ s/usr_externalNATAddr//;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_externalNATAddr \n");
                    }
                }
            #Replace usr_ldapCertificate
                elsif ($line =~ m[usr_ldapCertificate]) {
                    if ($args{-usr_ldapCertificate}) { 
                    $line =~ s/usr_ldapCertificate/$args{-usr_ldapCertificate}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ldapCertificate: $args{-usr_ldapCertificate} \n");
                    } else {
                        $line =~ s/usr_ldapCertificate/default/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ldapCertificate \n");
                    }
                }
            #Replace usr_sipCertificate
                elsif ($line =~ m[usr_sipCertificate]) {
                    if ($args{-usr_sipCertificate}) { 
                    $line =~ s/usr_sipCertificate/$args{-usr_sipCertificate}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipCertificate: $args{-usr_sipCertificate} \n");
                    } else {
                        $line =~ s/usr_sipCertificate/default/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sipCertificate \n");
                    }
                }
            #Replace usr_xmppCertificate
                elsif ($line =~ m[usr_xmppCertificate]) {
                    if ($args{-usr_xmppCertificate}) { 
                    $line =~ s/usr_xmppCertificate/$args{-usr_xmppCertificate}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_xmppCertificate: $args{-usr_xmppCertificate} \n");
                    } else {
                        $line =~ s/usr_xmppCertificate/default/;
                        $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_xmppCertificate \n");
                    }
                }
        }
        elsif ($xmlfile =~ /addVoicemailServerHost/i)
        {
            foreach ('-usr_host_name', '-usr_host_url', '-usr_host_type')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_host_name
            if ($line =~ m[usr_host_name]) {
                $line =~ s/usr_host_name/$args{-usr_host_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_host_name: $args{-usr_host_name} in $xmlfile \n");
            }
            #Replace usr_host_url
            elsif ($line =~ m[usr_host_url]) {
                $line =~ s/usr_host_url/$args{-usr_host_url}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_host_url: $args{-usr_host_url} in $xmlfile \n");
            }
            #Replace usr_host_type
            elsif ($line =~ m[usr_host_type]) {
                $line =~ s/usr_host_type/$args{-usr_host_type}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_host_type: $args{-usr_host_type} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addSIPVoicemailServer/i)
        {
            foreach ('-usr_sip_vms_name', '-usr_clientContact', '-usr_domainNames','-usr_SESM_name', '-usr_SESM_displayName', '-usr_host_name', '-usr_overwriteHIData_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_sip_vms_name
            if ($line =~ m[usr_sip_vms_name]) {
                $line =~ s/usr_sip_vms_name/$args{-usr_sip_vms_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sip_vms_name: $args{-usr_sip_vms_name} in $xmlfile \n");
            }
            #Replace usr_clientContact
            elsif ($line =~ m[usr_clientContact]) {
                $line =~ s/usr_clientContact/$args{-usr_clientContact}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_clientContact: $args{-usr_clientContact} in $xmlfile \n");
            }
            #Replace usr_domainName
            elsif ($line =~ m[Input Domains]) {
                foreach (@{$args{-usr_domainNames}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:DomainNaturalKeyDO\" xmlns:ns4=\"common.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
         			print OUT "</multiRef>";
                    print OUT "\n";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Set domain: $_ in $xmlfile \n");
                }
                next; 
            }
            #Replace usr_SESM_name
            elsif ($line =~ m[usr_SESM_name]) {
                $line =~ s/usr_SESM_name/$args{-usr_SESM_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SESM_name: $args{-usr_SESM_name} in $xmlfile \n");
            }
            #Replace usr_SESM_displayName
            elsif ($line =~ m[usr_SESM_displayName]) {
                $line =~ s/usr_SESM_displayName/$args{-usr_SESM_displayName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_SESM_displayName: $args{-usr_SESM_displayName} in $xmlfile \n");
            }
            #Replace usr_host_name
            elsif ($line =~ m[usr_host_name]) {
                $line =~ s/usr_host_name/$args{-usr_host_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_host_name: $args{-usr_host_name} in $xmlfile \n");
            }
            #Replace usr_overwriteHIData_ToF
            elsif ($line =~ m[usr_overwriteHIData_ToF]) {
                $line =~ s/usr_overwriteHIData_ToF/$args{-usr_overwriteHIData_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_overwriteHIData_ToF: $args{-usr_overwriteHIData_ToF} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addSystemProfileVoicemail/i)
        {
            foreach ('-usr_profileName', '-usr_revertiveCallSupport_ToF', '-usr_voiceMailViaVSC_ToF')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_revertiveCallSupport_ToF
            elsif ($line =~ m[usr_revertiveCallSupport_ToF]) {
                $line =~ s/usr_revertiveCallSupport_ToF/$args{-usr_revertiveCallSupport_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_revertiveCallSupport_ToF: $args{-usr_revertiveCallSupport_ToF} in $xmlfile \n");
            }
            
            #Replace usr_voiceMailViaVSC_ToF
            elsif ($line =~ m[usr_voiceMailViaVSC_ToF]) {
                $line =~ s/usr_voiceMailViaVSC_ToF/$args{-usr_voiceMailViaVSC_ToF}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_voiceMailViaVSC_ToF: $args{-usr_voiceMailViaVSC_ToF} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setUsersVoicemailServer/i)
        {
            foreach ('-usr_user', '-usr_voiceMail', '-usr_voicemailServer')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
            #Replace usr_voiceMail
            elsif ($line =~ m[usr_voiceMail]) {
                $line =~ s/usr_voiceMail/$args{-usr_voiceMail}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_voiceMail: $args{-usr_voiceMail} in $xmlfile \n");
            }
            
            #Replace usr_voicemailServer
            elsif ($line =~ m[usr_voicemailServer]) {
                $line =~ s/usr_voicemailServer/$args{-usr_voicemailServer}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_voicemailServer: $args{-usr_voicemailServer} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setDomainsForSystemProfileVoicemail|removeDomainsFromSPVoicemail/i)
        {
            foreach ('-usr_profileName', '-usr_domainNames')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_domainName
            elsif ($line =~ m[Input Domains]) {
                foreach (@{$args{-usr_domainNames}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
         			print OUT "</multiRef>";
                    print OUT "\n";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Set domain: $_ in $xmlfile \n");
                }
                next; 
            }
        }
        elsif ($xmlfile =~ /removeSIPVoicemailServer/i)
        {
            unless ($args{-usr_sip_vms_name}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_sip_vms_name
            if ($line =~ m[usr_sip_vms_name]) {
                $line =~ s/usr_sip_vms_name/$args{-usr_sip_vms_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_sip_vms_name: $args{-usr_sip_vms_name} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeVoicemailServerHost/i)
        {
            unless ($args{-usr_host_name}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_host_name
            if ($line =~ m[usr_host_name]) {
                $line =~ s/usr_host_name/$args{-usr_host_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_host_name: $args{-usr_host_name} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /addSPDistinctiveAlerting/i)
        {
            foreach ('-usr_profileName', '-usr_boundaryDomain', '-usr_ringtone')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_boundaryDomain
            elsif ($line =~ m[usr_boundaryDomain]) {
                $line =~ s/usr_boundaryDomain/$args{-usr_boundaryDomain}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_boundaryDomain: $args{-usr_boundaryDomain} in $xmlfile \n");
            }
            #Replace usr_ringtone
            elsif ($line =~ m[usr_ringtone]) {
                $line =~ s/usr_ringtone/$args{-usr_ringtone}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_ringtone: $args{-usr_ringtone} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setDomainsForSPDistinctiveAlerting|removeDomainsFromSPDistinctiveAlerting/i)
        {
            foreach ('-usr_profileName', '-usr_domainNames')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_domainName
            elsif ($line =~ m[Input Domains]) {
                foreach (@{$args{-usr_domainNames}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
         			print OUT "</multiRef>";
                    print OUT "\n";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Set domain: $_ in $xmlfile \n");
                }
                next; 
            }
        }
        elsif ($xmlfile =~ /setSPDistinctiveAlertingForUser/i)
        {
            foreach ('-usr_profileName', '-usr_user')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
            #Replace usr_user
            elsif ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /setUserProfileDistinctiveAlertingForUser/i)
        {
            foreach ('-usr_user', '-usr_externalRingtone', '-usr_internalRingtone')
            {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
            #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
            #Replace usr_externalRingtone
            elsif ($line =~ m[usr_externalRingtone]) {
                $line =~ s/usr_externalRingtone/$args{-usr_externalRingtone}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_externalRingtone: $args{-usr_externalRingtone} in $xmlfile \n");
            }
            #Replace usr_internalRingtone
            elsif ($line =~ m[usr_internalRingtone]) {
                $line =~ s/usr_internalRingtone/$args{-usr_internalRingtone}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_internalRingtone: $args{-usr_internalRingtone} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeUserProfileDistinctiveAlertingForUser|removeSPDistinctiveAlertingFromUser/i)
        {
            unless ($args{-usr_user}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_user
            if ($line =~ m[usr_user]) {
                $line =~ s/usr_user/$args{-usr_user}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_user: $args{-usr_user} in $xmlfile \n");
            }
        }
        elsif ($xmlfile =~ /removeSystemProfileDistinctiveAlerting/i)
        {
            unless ($args{-usr_profileName}) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present in $xmlfile");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                $flag = 0;
            }
        #Replace usr_profileName
            if ($line =~ m[usr_profileName]) {
                $line =~ s/usr_profileName/$args{-usr_profileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace usr_profileName: $args{-usr_profileName} in $xmlfile \n");
            }
        }

	elsif ($xmlfile =~ /addSingleUser-14.0/i)
        {
            foreach ('-user_domain', '-user_password', '-user_name',  '-user_firstName',  '-user_lastName', '-user_status', '-user_statusReason', '-user_subDomain', '-user_timezone', '-user_type' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                   # $flag = 0;
                    last;
                }
            }

 	#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

	 #Replace user_password
                elsif ($line =~ m[user_password]) {
                    $line =~ s/user_password/$args{-user_password}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_password: $args{-user_password} \n");
                }

 #Replace user_name
                elsif ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

 #Replace user_cellPhone
                elsif ($line =~ m[user_cellPhone]) {
                    $line =~ s/user_cellPhone/$args{-user_cellPhone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cellPhone: $args{-user_cellPhone} \n");
                }

 #Replace user_email
                elsif ($line =~ m[user_email]) {
                    $line =~ s/user_email/$args{-user_email}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_email: $args{-user_email} \n");
                }

 #Replace user_fax
                elsif ($line =~ m[user_fax]) {
                    $line =~ s/user_fax/$args{-user_fax}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_fax: $args{-user_fax} \n");
                }

 #Replace user_firstName
                elsif ($line =~ m[user_firstName]) {
                    $line =~ s/user_firstName/$args{-user_firstName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_firstName: $args{-user_firstName} \n");
                }

 #Replace user_homeCountry
                elsif ($line =~ m[user_homeCountry]) {
                    $line =~ s/user_homeCountry/$args{-user_homeCountry}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_homeCountry: $args{-user_homeCountry} \n");
                }

 #Replace user_homeLanguage
                elsif ($line =~ m[user_homeLanguage]) {
                    $line =~ s/user_homeLanguage/$args{-user_homeLanguage}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_homeLanguage: $args{-user_homeLanguage} \n");
                }

 #Replace user_homePhone
                elsif ($line =~ m[user_homePhone]) {
                    $line =~ s/user_homePhone/$args{-user_homePhone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_homePhone: $args{-user_homePhone} \n");
                }

 #Replace user_lastName
                elsif ($line =~ m[user_lastName]) {
                    $line =~ s/user_lastName/$args{-user_lastName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_lastName: $args{-user_lastName} \n");
                }

 #Replace user_locale
                elsif ($line =~ m[user_locale]) {
                    $line =~ s/user_locale/$args{-user_locale}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_locale: $args{-user_locale} \n");
                }

 #Replace user_officePhone
                elsif ($line =~ m[user_officePhone]) {
                    $line =~ s/user_officePhone/$args{-user_officePhone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_officePhone: $args{-user_officePhone} \n");
                }

 #Replace user_pager
                elsif ($line =~ m[user_pager]) {
                    $line =~ s/user_pager/$args{-user_pager}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_pager: $args{-user_pager} \n");
                }

 #Replace user_picture
                elsif ($line =~ m[user_picture]) {
                    $line =~ s/user_picture/$args{-user_picture}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_picture: $args{-user_picture} \n");
                }

 #Replace user_status
                elsif ($line =~ m[user_status]) {
                    $line =~ s/user_status/$args{-user_status}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_status: $args{-user_status} \n");
                }

 #Replace user_statusReason
                elsif ($line =~ m[user_statusReason]) {
                    $line =~ s/user_statusReason/$args{-user_statusReason}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_statusReason: $args{-user_statusReason} \n");
                }

 #Replace user_subDomain
                elsif ($line =~ m[user_subDomain]) {
                    $line =~ s/user_subDomain/$args{-user_subDomain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_subDomain: $args{-user_subDomain} \n");
                }

 #Replace user_timezone
                elsif ($line =~ m[user_timezone]) {
                    $line =~ s/user_timezone/$args{-user_timezone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_timezone: $args{-user_timezone} \n");
                }

 #Replace user_type
                elsif ($line =~ m[user_type]) {
                    $line =~ s/user_type/$args{-user_type}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_type: $args{-user_type} \n");
                }

}
		elsif ($xmlfile =~ /setUserDirectoryNumber-14.0/i)
        {
            foreach ('-user_name', '-user_DN1' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

		#Replace user_DN1
                elsif ($line =~ m[user_DN1]) {
                    $line =~ s/user_DN1/$args{-user_DN1}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_DN1: $args{-user_DN1} \n");
                }
		}
		elsif ($xmlfile =~ /addCallPickupSystemProfile-14.0/i)
        {
            foreach ('-user_callPickup_SPName', '-user_boolean_directedCallEnabled', '-user_boolean_groupCallEnabled', '-user_boolean_targetedCallEnabled' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_callPickup_SPName
                if ($line =~ m[user_callPickup_SPName]) {
                    $line =~ s/user_callPickup_SPName/$args{-user_callPickup_SPName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_callPickup_SPName: $args{-user_callPickup_SPName} \n");
                }

		#Replace user_boolean_directedCallEnabled
                elsif ($line =~ m[user_boolean_directedCallEnabled]) {
                    $line =~ s/user_boolean_directedCallEnabled/$args{-user_boolean_directedCallEnabled}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_boolean_directedCallEnabled: $args{-user_boolean_directedCallEnabled} \n");
                }

		#Replace user_boolean_groupCallEnabled
                elsif ($line =~ m[user_boolean_groupCallEnabled]) {
                    $line =~ s/user_boolean_groupCallEnabled/$args{-user_boolean_groupCallEnabled}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_boolean_groupCallEnabled: $args{-user_boolean_groupCallEnabled} \n");
                }

		#Replace user_boolean_targetedCallEnabled
                elsif ($line =~ m[user_boolean_targetedCallEnabled]) {
                    $line =~ s/user_boolean_targetedCallEnabled/$args{-user_boolean_targetedCallEnabled}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_boolean_targetedCallEnabled: $args{-user_boolean_targetedCallEnabled} \n");
                }

		}
		elsif ($xmlfile =~ /addCallPickupSystemProfileForDomain-14.0/i)
        {
            foreach ('-user_domain', '-user_systemProfileName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

		#Replace user_systemProfileName
                elsif ($line =~ m[user_systemProfileName]) {
                    $line =~ s/user_systemProfileName/$args{-user_systemProfileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_systemProfileName: $args{-user_systemProfileName} \n");
                }

		}
		elsif ($xmlfile =~ /addCallPickupSystemProfileForUser-14.0/i)
        {
            foreach ('-user_name', '-user_systemProfileName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

		#Replace user_systemProfileName
                elsif ($line =~ m[user_systemProfileName]) {
                    $line =~ s/user_systemProfileName/$args{-user_systemProfileName}/;
					$logger->debug(__PACKAGE__ . ".$sub_name: Replace user_systemProfileName: $args{-user_systemProfileName} \n");
                }

		}
		elsif ($xmlfile =~ /setCallPickupUserProfile-14.0/i)
        {
            foreach ('-user_name', '-user_boolean_agentStatusEnabled' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

		#Replace user_boolean_agentStatusEnabled
                elsif ($line =~ m[user_boolean_agentStatusEnabled]) {
                    $line =~ s/user_boolean_agentStatusEnabled/$args{-user_boolean_agentStatusEnabled}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_boolean_agentStatusEnabled: $args{-user_boolean_agentStatusEnabled} \n");
                }

		}
		elsif ($xmlfile =~ /removeCallPickupUserProfile-14.0/i)
        {
            foreach ('-user_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

		}
		elsif ($xmlfile =~ /removeCallPickupSPFromUser-14.0/i)
        {
            foreach ('-user_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

		}
		elsif ($xmlfile =~ /removeCallPickupSPFromDomain-14.0/i)
        {
            foreach ('-user_domain', '-user_systemProfileName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

		#Replace user_systemProfileName
                elsif ($line =~ m[user_systemProfileName]) {
                    $line =~ s/user_systemProfileName/$args{-user_systemProfileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_systemProfileName: $args{-user_systemProfileName} \n");
                }

		}
		elsif ($xmlfile =~ /removeCallPickupSystemProfile-14.0/i)
        {
            foreach ('-user_systemProfileName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_systemProfileName
                if ($line =~ m[user_systemProfileName]) {
                    $line =~ s/user_systemProfileName/$args{-user_systemProfileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_systemProfileName: $args{-user_systemProfileName} \n");
                }

		}
		elsif ($xmlfile =~ /addCallPickupGroup-14.0/i)
        {
            foreach ('-user_domain', '-user_cpuGroupName', '-user_name1', '-user_name2', '-user_name3', '-user_allowActiveSubscriptions', '-user_groupDisplayName', '-user_maxCallQueueSize', '-user_maxGroupSize', '-user_pilotDNName', '-user_groupAlias', '-user_groupDirectoryNumber', '-user_locale', '-user_timezone' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

		#Replace user_cpuGroupName
                elsif ($line =~ m[user_cpuGroupName]) {
                    $line =~ s/user_cpuGroupName/$args{-user_cpuGroupName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cpuGroupName: $args{-user_cpuGroupName} \n");
                }

		#Replace user_name1
                elsif ($line =~ m[user_name1]) {
                    $line =~ s/user_name1/$args{-user_name1}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name1: $args{-user_name1} \n");
                }

		#Replace user_name2
                elsif ($line =~ m[user_name2]) {
                    $line =~ s/user_name2/$args{-user_name2}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name2: $args{-user_name2} \n");
                }

		#Replace user_name3
                elsif ($line =~ m[user_name3]) {
                    $line =~ s/user_name3/$args{-user_name3}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name3: $args{-user_name3} \n");
                }

		#Replace user_allowActiveSubscriptions
                elsif ($line =~ m[user_allowActiveSubscriptions]) {
                    $line =~ s/user_allowActiveSubscriptions/$args{-user_allowActiveSubscriptions}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_allowActiveSubscriptions: $args{-user_allowActiveSubscriptions} \n");
                }

		#Replace user_groupDisplayName
                elsif ($line =~ m[user_groupDisplayName]) {
                    $line =~ s/user_groupDisplayName/$args{-user_groupDisplayName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_groupDisplayName: $args{-user_groupDisplayName} \n");
                }

		#Replace user_maxCallQueueSize
                elsif ($line =~ m[user_maxCallQueueSize]) {
                    $line =~ s/user_maxCallQueueSize/$args{-user_maxCallQueueSize}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_maxCallQueueSize: $args{-user_maxCallQueueSize} \n");
                }

		#Replace user_maxGroupSize
                elsif ($line =~ m[user_maxGroupSize]) {
                    $line =~ s/user_maxGroupSize/$args{-user_maxGroupSize}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_maxGroupSize: $args{-user_maxGroupSize} \n");
                }

		#Replace user_pilotDNName
                elsif ($line =~ m[user_pilotDNName]) {
                    $line =~ s/user_pilotDNName/$args{-user_pilotDNName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_pilotDNName: $args{-user_pilotDNName} \n");
                }

		#Replace user_groupAlias
                elsif ($line =~ m[user_groupAlias]) {
                    $line =~ s/user_groupAlias/$args{-user_groupAlias}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_groupAlias: $args{-user_groupAlias} \n");
                }

		#Replace user_groupDirectoryNumber
                elsif ($line =~ m[user_groupDirectoryNumber]) {
                    $line =~ s/user_groupDirectoryNumber/$args{-user_groupDirectoryNumber}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_groupDirectoryNumber: $args{-user_groupDirectoryNumber} \n");
                }

		#Replace user_locale
                elsif ($line =~ m[user_locale]) {
                    $line =~ s/user_locale/$args{-user_locale}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_locale: $args{-user_locale} \n");
                }

		#Replace user_timezone
                elsif ($line =~ m[user_timezone]) {
                    $line =~ s/user_timezone/$args{-user_timezone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_timezone: $args{-user_timezone} \n");
                }

		}
		elsif ($xmlfile =~ /assignAdminToCallPickupGroup-14.0/i)
        {
            foreach ('-user_domain', '-user_groupName', '-user_groupAdminName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

		#Replace user_groupName
                elsif ($line =~ m[user_groupName]) {
                    $line =~ s/user_groupName/$args{-user_groupName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_groupName: $args{-user_groupName} \n");
                }

		#Replace user_groupAdminName
                elsif ($line =~ m[user_groupAdminName]) {
                    $line =~ s/user_groupAdminName/$args{-user_groupAdminName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_groupAdminName: $args{-user_groupAdminName} \n");
                }

		}
		elsif ($xmlfile =~ /removeAdminFromCallPickupGroup-14.0/i)
        {
            foreach ('-user_domain', '-user_groupName', '-user_groupAdminName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

		#Replace user_groupName
                elsif ($line =~ m[user_groupName]) {
                    $line =~ s/user_groupName/$args{-user_groupName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_groupName: $args{-user_groupName} \n");
                }

		#Replace user_groupAdminName
                elsif ($line =~ m[user_groupAdminName]) {
                    $line =~ s/user_groupAdminName/$args{-user_groupAdminName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_groupAdminName: $args{-user_groupAdminName} \n");
                }

		}
		elsif ($xmlfile =~ /removeCallPickupGroup-14.0/i)
        {
            foreach ('-user_domain', '-user_groupName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

		#Replace user_groupName
                elsif ($line =~ m[user_groupName]) {
                    $line =~ s/user_groupName/$args{-user_groupName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_groupName: $args{-user_groupName} \n");
                }

		}
		elsif ($xmlfile =~ /setSesmProfileCallPickupGroup-14.0/i)
        {
            foreach ('-user_domain', '-user_groupName', '-user_sesmProfileName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

			#Replace user_groupName
                elsif ($line =~ m[user_groupName]) {
                    $line =~ s/user_groupName/$args{-user_groupName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_groupName: $args{-user_groupName} \n");
                }

			#Replace user_sesmProfileName
                elsif ($line =~ m[user_sesmProfileName]) {
                    $line =~ s/user_sesmProfileName/$args{-user_sesmProfileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_sesmProfileName: $args{-user_sesmProfileName} \n");
                }

		}
		elsif ($xmlfile =~ /addVSCFeatureXLA-14.0/i)
        {
            foreach ('-user_domain', '-user_vscFeatureName', '-user_vscPrefix', '-user_vscStarCode' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

			#Replace user_vscFeatureName
                elsif ($line =~ m[user_vscFeatureName]) {
                    $line =~ s/user_vscFeatureName/$args{-user_vscFeatureName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_vscFeatureName: $args{-user_vscFeatureName} \n");
                }

			#Replace user_vscPrefix
                elsif ($line =~ m[user_vscPrefix]) {
                    $line =~ s/user_vscPrefix/$args{-user_vscPrefix}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_vscPrefix: $args{-user_vscPrefix} \n");
                }

			#Replace user_vscStarCode
                elsif ($line =~ m[user_vscStarCode]) {
                    $line =~ s/user_vscStarCode/$args{-user_vscStarCode}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_vscStarCode: $args{-user_vscStarCode} \n");
                }

		}
		elsif ($xmlfile =~ /removeVSCFeatureXLA-14.0/i)
        {
            foreach ('-user_domain', '-user_vscFeatureName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

			#Replace user_vscFeatureName
                elsif ($line =~ m[user_vscFeatureName]) {
                    $line =~ s/user_vscFeatureName/$args{-user_vscFeatureName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_vscFeatureName: $args{-user_vscFeatureName} \n");
                }

		}
		elsif ($xmlfile =~ /addCallParkSystemProfile_14.0/i)
        {
            foreach ('-user_cpark_sprofile', '-user_boolean_autoRetrieve', '-user_autoRetrieveTimer', '-user_boolean_mohOnGEnabled' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_cpark_sprofile
                if ($line =~ m[user_cpark_sprofile]) {
                    $line =~ s/user_cpark_sprofile/$args{-user_cpark_sprofile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cpark_sprofile: $args{-user_cpark_sprofile} \n");
                }

			#Replace user_boolean_autoRetrieve
                elsif ($line =~ m[user_boolean_autoRetrieve]) {
                    $line =~ s/user_boolean_autoRetrieve/$args{-user_boolean_autoRetrieve}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_boolean_autoRetrieve: $args{-user_boolean_autoRetrieve} \n");
                }

			#Replace user_autoRetrieveTimer
                elsif ($line =~ m[user_autoRetrieveTimer]) {
                    $line =~ s/user_autoRetrieveTimer/$args{-user_autoRetrieveTimer}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_autoRetrieveTimer: $args{-user_autoRetrieveTimer} \n");
                }

			#Replace user_boolean_mohOnGEnabled
                elsif ($line =~ m[user_boolean_mohOnGEnabled]) {
                    $line =~ s/user_boolean_mohOnGEnabled/$args{-user_boolean_mohOnGEnabled}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_boolean_mohOnGEnabled: $args{-user_boolean_mohOnGEnabled} \n");
                }

		}
		elsif ($xmlfile =~ /addCallParkSystemProfileForDomain_14.0/i)
        {
            foreach ('-user_domain', '-user_spName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

			#Replace user_spName
                elsif ($line =~ m[user_spName]) {
                    $line =~ s/user_spName/$args{-user_spName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_spName: $args{-user_spName} \n");
                }

		}
		elsif ($xmlfile =~ /setCallParkSPForUser_14.0/i)
        {
            foreach ('-user_name', '-user_spName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

			#Replace user_spName
                elsif ($line =~ m[user_spName]) {
                    $line =~ s/user_spName/$args{-user_spName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_spName: $args{-user_spName} \n");
                }

		}
		elsif ($xmlfile =~ /setCallParkUserProfile_14.0/i)
        {
            foreach ('-user_name', '-user_boolean_autoRetrieve', '-user_autoRetrieveTimer' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

			#Replace user_boolean_autoRetrieve
                elsif ($line =~ m[user_boolean_autoRetrieve]) {
                    $line =~ s/user_boolean_autoRetrieve/$args{-user_boolean_autoRetrieve}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_boolean_autoRetrieve: $args{-user_boolean_autoRetrieve} \n");
                }

			#Replace user_autoRetrieveTimer
                elsif ($line =~ m[user_autoRetrieveTimer]) {
                    $line =~ s/user_autoRetrieveTimer/$args{-user_autoRetrieveTimer}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_autoRetrieveTimer: $args{-user_autoRetrieveTimer} \n");
                }

		}
		elsif ($xmlfile =~ /removeCallParkSystemProfile_14.0/i)
        {
            foreach ('-user_cpark_sprofile' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_cpark_sprofile
                if ($line =~ m[user_cpark_sprofile]) {
                    $line =~ s/user_cpark_sprofile/$args{-user_cpark_sprofile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cpark_sprofile: $args{-user_cpark_sprofile} \n");
                }

		}
		elsif ($xmlfile =~ /removeCallParkSPFromDomain_14.0/i)
        {
            foreach ('-user_domain', '-user_spName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

			#Replace user_spName
                elsif ($line =~ m[user_spName]) {
                    $line =~ s/user_spName/$args{-user_spName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_spName: $args{-user_spName} \n");
                }

		}
		elsif ($xmlfile =~ /removeCallParkSPFromUser_14.0/i)
        {
            foreach ('-user_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

		}
		elsif ($xmlfile =~ /removeCallParkUserProfile_14.0/i)
        {
            foreach ('-user_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

		}
		elsif ($xmlfile =~ /addCallFwdSystemProfile_14.0/i)
        {
            foreach ('-user_cFwd_systemProfile', '-user_callfwdBusyEnabled', '-user_callfwdImmediateEnabled', '-user_callfwdNoAnswerEnabled', '-user_callfwdNotLoggedInEnabled', '-user_callfwdUnreachableEnabled' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_cFwd_systemProfile
                if ($line =~ m[user_cFwd_systemProfile]) {
                    $line =~ s/user_cFwd_systemProfile/$args{-user_cFwd_systemProfile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cFwd_systemProfile: $args{-user_cFwd_systemProfile} \n");
                }

			#Replace user_callfwdBusyEnabled
                elsif ($line =~ m[user_callfwdBusyEnabled]) {
                    $line =~ s/user_callfwdBusyEnabled/$args{-user_callfwdBusyEnabled}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_callfwdBusyEnabled: $args{-user_callfwdBusyEnabled} \n");
                }

			#Replace user_callfwdImmediateEnabled
                elsif ($line =~ m[user_callfwdImmediateEnabled]) {
                    $line =~ s/user_callfwdImmediateEnabled/$args{-user_callfwdImmediateEnabled}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_callfwdImmediateEnabled: $args{-user_callfwdImmediateEnabled} \n");
                }

			#Replace user_callfwdNoAnswerEnabled
                elsif ($line =~ m[user_callfwdNoAnswerEnabled]) {
                    $line =~ s/user_callfwdNoAnswerEnabled/$args{-user_callfwdNoAnswerEnabled}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_callfwdNoAnswerEnabled: $args{-user_callfwdNoAnswerEnabled} \n");
                }

			#Replace user_callfwdNotLoggedInEnabled
                elsif ($line =~ m[user_callfwdNotLoggedInEnabled]) {
                    $line =~ s/user_callfwdNotLoggedInEnabled/$args{-user_callfwdNotLoggedInEnabled}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_callfwdNotLoggedInEnabled: $args{-user_callfwdNotLoggedInEnabled} \n");
                }

			#Replace user_callfwdUnreachableEnabled
                elsif ($line =~ m[user_callfwdUnreachableEnabled]) {
                    $line =~ s/user_callfwdUnreachableEnabled/$args{-user_callfwdUnreachableEnabled}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_callfwdUnreachableEnabled: $args{-user_callfwdUnreachableEnabled} \n");
                }

		}
		elsif ($xmlfile =~ /removeCallFwdSystemProfile_14.0/i)
        {
            foreach ('-user_cFwd_systemProfile' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_cFwd_systemProfile
                if ($line =~ m[user_cFwd_systemProfile]) {
                    $line =~ s/user_cFwd_systemProfile/$args{-user_cFwd_systemProfile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cFwd_systemProfile: $args{-user_cFwd_systemProfile} \n");
                }

		}
		elsif ($xmlfile =~ /addCallFwdSPforDomain_14.0/i)
        {
            foreach ('-user_domain', '-user_cFwd_systemProfile' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

			#Replace user_cFwd_systemProfile
                elsif ($line =~ m[user_cFwd_systemProfile]) {
                    $line =~ s/user_cFwd_systemProfile/$args{-user_cFwd_systemProfile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cFwd_systemProfile: $args{-user_cFwd_systemProfile} \n");
                }

		}
		elsif ($xmlfile =~ /removeCallFwdSPfromDomain_14.0/i)
        {
            foreach ('-user_domain', '-user_cFwd_systemProfile' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

			#Replace user_cFwd_systemProfile
                elsif ($line =~ m[user_cFwd_systemProfile]) {
                    $line =~ s/user_cFwd_systemProfile/$args{-user_cFwd_systemProfile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cFwd_systemProfile: $args{-user_cFwd_systemProfile} \n");
                }

		}
		elsif ($xmlfile =~ /setCallFwdSPforUser_14.0/i)
        {
            foreach ('-user_name', '-user_cFwd_systemProfile' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

			#Replace user_cFwd_systemProfile
                elsif ($line =~ m[user_cFwd_systemProfile]) {
                    $line =~ s/user_cFwd_systemProfile/$args{-user_cFwd_systemProfile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cFwd_systemProfile: $args{-user_cFwd_systemProfile} \n");
                }

		}
		elsif ($xmlfile =~ /removeCallFwdSPfromUser_14.0/i)
        {
            foreach ('-user_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

		}
		elsif ($xmlfile =~ /setCFIRoute_14.0/i)
        {
            foreach ('-user_name', '-user_callForward_destination', '-user_cfi_boolen_active', '-user_numRings', '-user_cfi_sentToVoicemail' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

			#Replace user_callForward_destination
                elsif ($line =~ m[user_callForward_destination]) {
                    $line =~ s/user_callForward_destination/$args{-user_callForward_destination}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_callForward_destination: $args{-user_callForward_destination} \n");
                }

			#Replace user_cfi_boolen_active
                elsif ($line =~ m[user_cfi_boolen_active]) {
                    $line =~ s/user_cfi_boolen_active/$args{-user_cfi_boolen_active}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cfi_boolen_active: $args{-user_cfi_boolen_active} \n");
                }

			#Replace user_numRings
                elsif ($line =~ m[user_numRings]) {
                    $line =~ s/user_numRings/$args{-user_numRings}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_numRings: $args{-user_numRings} \n");
                }

			#Replace user_cfi_sentToVoicemail
                elsif ($line =~ m[user_cfi_sentToVoicemail]) {
                    $line =~ s/user_cfi_sentToVoicemail/$args{-user_cfi_sentToVoicemail}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cfi_sentToVoicemail: $args{-user_cfi_sentToVoicemail} \n");
                }

		}

			elsif ($xmlfile =~ /addAdhocSystemProfile_14.0/i)
        {
            foreach ('-user_adhoc_spName', '-user_adhoc_vscEnabled', '-user_adhoc_ports' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

                #Replace user_adhoc_spName
                if ($line =~ m[user_adhoc_spName]) {
                    $line =~ s/user_adhoc_spName/$args{-user_adhoc_spName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_adhoc_spName: $args{-user_adhoc_spName} \n");
                }

                #Replace user_adhoc_vscEnabled
                elsif ($line =~ m[user_adhoc_vscEnabled]) {
                    $line =~ s/user_adhoc_vscEnabled/$args{-user_adhoc_vscEnabled}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_adhoc_vscEnabled: $args{-user_adhoc_vscEnabled} \n");
                }

                #Replace user_adhoc_ports
                elsif ($line =~ m[user_adhoc_ports]) {
                    $line =~ s/user_adhoc_ports/$args{-user_adhoc_ports}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_adhoc_ports: $args{-user_adhoc_ports} \n");
                }

        }
		elsif ($xmlfile =~ /addAdhocSystemProfileForDomain_14.0/i)
        {
            foreach ('-user_domain', '-user_adhoc_spName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

                #Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

                #Replace user_adhoc_spName
                elsif ($line =~ m[user_adhoc_spName]) {
                    $line =~ s/user_adhoc_spName/$args{-user_adhoc_spName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_adhoc_spName: $args{-user_adhoc_spName} \n");
                }

        }
		elsif ($xmlfile =~ /addAdhocSystemProfileForUser_14.0/i)
        {
            foreach ('-user_name', '-user_adhoc_spName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

                #Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

                #Replace user_adhoc_spName
                elsif ($line =~ m[user_adhoc_spName]) {
                    $line =~ s/user_adhoc_spName/$args{-user_adhoc_spName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_adhoc_spName: $args{-user_adhoc_spName} \n");
                }

        }
		elsif ($xmlfile =~ /setAdhocUserProfile_14.0/i)
        {
            foreach ('-user_name', '-user_adhocConfEnabled' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

                #Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

                #Replace user_adhocConfEnabled
                elsif ($line =~ m[user_adhocConfEnabled]) {
                    $line =~ s/user_adhocConfEnabled/$args{-user_adhocConfEnabled}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_adhocConfEnabled: $args{-user_adhocConfEnabled} \n");
                }

        }
		elsif ($xmlfile =~ /removeAdhocUserProfile_14.0/i)
        {
            foreach ('-user_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

                #Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

        }
		elsif ($xmlfile =~ /removeAdhocSPForUser_14.0/i)
        {
            foreach ('-user_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

                #Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

        }
		elsif ($xmlfile =~ /removeAdhocSPForDomain_14.0/i)
        {
            foreach ('-user_domain', '-user_adhoc_spName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

                #Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

                #Replace user_adhoc_spName
                elsif ($line =~ m[user_adhoc_spName]) {
                    $line =~ s/user_adhoc_spName/$args{-user_adhoc_spName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_adhoc_spName: $args{-user_adhoc_spName} \n");
                }

        }
		elsif ($xmlfile =~ /removeAdhocSystemProfile_14.0/i)
        {
            foreach ('-user_adhoc_spName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

                #Replace user_adhoc_spName
                if ($line =~ m[user_adhoc_spName]) {
                    $line =~ s/user_adhoc_spName/$args{-user_adhoc_spName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_adhoc_spName: $args{-user_adhoc_spName} \n");
                }

        }
		elsif ($xmlfile =~ /addSingleUserWithServiceSet14.0/i)
        {
            foreach ('-user_domain', '-user_serviceSet', '-user_password', '-user_name', '-user_firstName', '-user_lastName', '-user_status', '-user_timezone', '-user_type' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
					#$flag = 0;
                    last;
                }
            }

				#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

			#Replace user_serviceSet
                elsif ($line =~ m[user_serviceSet]) {
                    $line =~ s/user_serviceSet/$args{-user_serviceSet}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_serviceSet: $args{-user_serviceSet} \n");
                }

			#Replace user_password
                elsif ($line =~ m[user_password]) {
                    $line =~ s/user_password/$args{-user_password}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_password: $args{-user_password} \n");
                }

			#Replace user_name
                elsif ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

			#Replace user_cellPhone
                elsif ($line =~ m[user_cellPhone]) {
                    $line =~ s/user_cellPhone/$args{-user_cellPhone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_cellPhone: $args{-user_cellPhone} \n");
                }

			#Replace user_email
                elsif ($line =~ m[user_email]) {
                    $line =~ s/user_email/$args{-user_email}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_email: $args{-user_email} \n");
                }

			#Replace user_fax
                elsif ($line =~ m[user_fax]) {
                    $line =~ s/user_fax/$args{-user_fax}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_fax: $args{-user_fax} \n");
                }

			#Replace user_firstName
                elsif ($line =~ m[user_firstName]) {
                    $line =~ s/user_firstName/$args{-user_firstName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_firstName: $args{-user_firstName} \n");
                }

			#Replace user_homeCountry
                elsif ($line =~ m[user_homeCountry]) {
                    $line =~ s/user_homeCountry/$args{-user_homeCountry}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_homeCountry: $args{-user_homeCountry} \n");
                }

			#Replace user_homeLanguage
                elsif ($line =~ m[user_homeLanguage]) {
                    $line =~ s/user_homeLanguage/$args{-user_homeLanguage}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_homeLanguage: $args{-user_homeLanguage} \n");
                }

			#Replace user_homePhone
                elsif ($line =~ m[user_homePhone]) {
                    $line =~ s/user_homePhone/$args{-user_homePhone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_homePhone: $args{-user_homePhone} \n");
                }

			#Replace user_lastName
                elsif ($line =~ m[user_lastName]) {
                    $line =~ s/user_lastName/$args{-user_lastName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_lastName: $args{-user_lastName} \n");
                }

			#Replace user_locale
                elsif ($line =~ m[user_locale]) {
                    $line =~ s/user_locale/$args{-user_locale}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_locale: $args{-user_locale} \n");
                }

			#Replace user_officePhone
                elsif ($line =~ m[user_officePhone]) {
                    $line =~ s/user_officePhone/$args{-user_officePhone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_officePhone: $args{-user_officePhone} \n");
                }

			#Replace user_pager
                elsif ($line =~ m[user_pager]) {
                    $line =~ s/user_pager/$args{-user_pager}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_pager: $args{-user_pager} \n");
                }

			#Replace user_picture
                elsif ($line =~ m[user_picture]) {
                    $line =~ s/user_picture/$args{-user_picture}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_picture: $args{-user_picture} \n");
                }

			#Replace user_status
                elsif ($line =~ m[user_status]) {
                    $line =~ s/user_status/$args{-user_status}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_status: $args{-user_status} \n");
                }

			#Replace user_Reason
                elsif ($line =~ m[user_Reason]) {
                    $line =~ s/user_Reason/$args{-user_Reason}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_Reason: $args{-user_Reason} \n");
                }

			#Replace user_subDomain
                elsif ($line =~ m[user_subDomain]) {
                    $line =~ s/user_subDomain/$args{-user_subDomain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_subDomain: $args{-user_subDomain} \n");
                }

			#Replace user_timezone
                elsif ($line =~ m[user_timezone]) {
                    $line =~ s/user_timezone/$args{-user_timezone}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_timezone: $args{-user_timezone} \n");
                }

			#Replace user_type
                elsif ($line =~ m[user_type]) {
                    $line =~ s/user_type/$args{-user_type}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_type: $args{-user_type} \n");
                }

		}
		
		elsif ($xmlfile =~ /setXmppServicesForUser14.0/i)
        {
            foreach ('-user_name', '-user_vendor1_name', '-user_vendor2_name', '-user_service1_name', '-user_service2_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

		#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

		#Replace user_vendor1_name
                elsif ($line =~ m[user_vendor1_name]) {
                    $line =~ s/user_vendor1_name/$args{-user_vendor1_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_vendor1_name: $args{-user_vendor1_name} \n");
                }

		#Replace user_vendor2_name
                elsif ($line =~ m[user_vendor2_name]) {
                    $line =~ s/user_vendor2_name/$args{-user_vendor2_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_vendor2_name: $args{-user_vendor2_name} \n");
                }

		#Replace user_service1_name
                elsif ($line =~ m[user_service1_name]) {
                    $line =~ s/user_service1_name/$args{-user_service1_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_service1_name: $args{-user_service1_name} \n");
                }

			#Replace user_service2_name
                elsif ($line =~ m[user_service2_name]) {
                    $line =~ s/user_service2_name/$args{-user_service2_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_service2_name: $args{-user_service2_name} \n");
                }

		}
		elsif ($xmlfile =~ /removeSingleServiceFromUser14.0/i)
        {
            foreach ('-user_name', '-user_service_name', '-user_vendor_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

			#Replace user_service_name
                elsif ($line =~ m[user_service_name]) {
                    $line =~ s/user_service_name/$args{-user_service_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_service_name: $args{-user_service_name} \n");
                }

			#Replace user_vendor_name
                elsif ($line =~ m[user_vendor_name]) {
                    $line =~ s/user_vendor_name/$args{-user_vendor_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_vendor_name: $args{-user_vendor_name} \n");
                }

		}
		elsif ($xmlfile =~ /removeUser14.0/i)
        {
            foreach ('-user_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

		}
		elsif ($xmlfile =~ /getAdminRightByName14.0/i)
        {
            foreach ('-user_service_name', '-user_soap_request', '-user_soap_response') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_service_name
                if ($line =~ m[user_service_name]) {
                    $line =~ s/user_service_name/$args{-user_service_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_service_name: $args{-user_service_name} \n");
                }

			#Replace user_soap_request
                elsif ($line =~ m[user_soap_request]) {
                    $line =~ s/user_soap_request/$args{-user_soap_request}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_request: $args{-user_soap_request} \n");
                }
			#Replace user_soap_response
                elsif ($line =~ m[user_soap_response]) {
                    $line =~ s/user_soap_response/$args{-user_soap_response}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_response: $args{-user_soap_response} \n");
                }
		}
		elsif ($xmlfile =~ /setXMPPSystemPassword14.0/i)
        {
            foreach ('-user_xmpp_password', '-user_soap_request', '-user_soap_response' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_xmpp_password
                if ($line =~ m[user_xmpp_password]) {
                    $line =~ s/user_xmpp_password/$args{-user_xmpp_password}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_xmpp_password: $args{-user_xmpp_password} \n");
                }

			#Replace user_soap_request
                elsif ($line =~ m[user_soap_request]) {
                    $line =~ s/user_soap_request/$args{-user_soap_request}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_request: $args{-user_soap_request} \n");
                }
			#Replace user_soap_response
                elsif ($line =~ m[user_soap_response]) {
                    $line =~ s/user_soap_response/$args{-user_soap_response}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_response: $args{-user_soap_response} \n");
                }

		}
		elsif ($xmlfile =~ /addXmppSystemProfileForDomain14.0/i)
        {
            foreach ('-user_domain', '-user_serviceProfileName', '-user_soap_request', '-user_soap_response' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

			#Replace user_serviceProfileName
                elsif ($line =~ m[user_serviceProfileName]) {
                    $line =~ s/user_serviceProfileName/$args{-user_serviceProfileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_serviceProfileName: $args{-user_serviceProfileName} \n");
                }
			#Replace user_soap_request
                elsif ($line =~ m[user_soap_request]) {
                    $line =~ s/user_soap_request/$args{-user_soap_request}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_request: $args{-user_soap_request} \n");
                }
			#Replace user_soap_response
                elsif ($line =~ m[user_soap_response]) {
                    $line =~ s/user_soap_response/$args{-user_soap_response}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_response: $args{-user_soap_response} \n");
                }
 
		}
		
		elsif ($xmlfile =~ /removeDomainFromXmppSystemProfile14.0/i)
        {
            foreach ('-user_serviceProfileName', '-user_domain', '-user_soap_request' ,'-user_soap_response' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_serviceProfileName
                if ($line =~ m[user_serviceProfileName]) {
                    $line =~ s/user_serviceProfileName/$args{-user_serviceProfileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_serviceProfileName: $args{-user_serviceProfileName} \n");
                }

			#Replace user_domain
                elsif ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }
			#Replace user_soap_request
                elsif ($line =~ m[user_soap_request]) {
                    $line =~ s/user_soap_request/$args{-user_soap_request}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_request: $args{-user_soap_request} \n");
                }
			#Replace user_soap_response
                elsif ($line =~ m[user_soap_response]) {
                    $line =~ s/user_soap_response/$args{-user_soap_response}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_response: $args{-user_soap_response} \n");
                }
	
		}
		
		elsif ($xmlfile =~ /setXmppSystemProfileForUser14.0/i)
        {
            foreach ('-user_name', '-user_serviceProfileName', '-user_soap_request', '-user_soap_response' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

			#Replace user_serviceProfileName
                elsif ($line =~ m[user_serviceProfileName]) {
                    $line =~ s/user_serviceProfileName/$args{-user_serviceProfileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_serviceProfileName: $args{-user_serviceProfileName} \n");
                }
			#Replace user_soap_request
                elsif ($line =~ m[user_soap_request]) {
                    $line =~ s/user_soap_request/$args{-user_soap_request}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_request: $args{-user_soap_request} \n");
                }
			#Replace user_soap_response
                elsif ($line =~ m[user_soap_response]) {
                    $line =~ s/user_soap_response/$args{-user_soap_response}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_response: $args{-user_soap_response} \n");
                }
		}
		elsif ($xmlfile =~ /removeXmppSystemProfileFromUser14.0/i)
        {
            foreach ('-user_name', '-user_soap_request', '-user_soap_response' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }
			#Replace user_soap_request
                elsif ($line =~ m[user_soap_request]) {
                    $line =~ s/user_soap_request/$args{-user_soap_request}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_request: $args{-user_soap_request} \n");
                }
			#Replace user_soap_response
                elsif ($line =~ m[user_soap_response]) {
                    $line =~ s/user_soap_response/$args{-user_soap_response}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_response: $args{-user_soap_response} \n");
                }

		}
		elsif ($xmlfile =~ /setXmppUserProfile14.0/i)
        {
            foreach ('-user_name', '-user_xmpp_name', '-user_soap_request', '-user_soap_response' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

			#Replace user_xmpp_name
                elsif ($line =~ m[user_xmpp_name]) {
                    $line =~ s/user_xmpp_name/$args{-user_xmpp_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_xmpp_name: $args{-user_xmpp_name} \n");
                }
			#Replace user_soap_request
                elsif ($line =~ m[user_soap_request]) {
                    $line =~ s/user_soap_request/$args{-user_soap_request}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_request: $args{-user_soap_request} \n");
                }
			#Replace user_soap_response
                elsif ($line =~ m[user_soap_response]) {
                    $line =~ s/user_soap_response/$args{-user_soap_response}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_response: $args{-user_soap_response} \n");
                }

		}
		elsif ($xmlfile =~ /removeXmppUserProfile14.0/i)
        {
            foreach ('-user_name', '-user_soap_request', '-user_soap_response' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

			#Replace user_soap_request
                elsif ($line =~ m[user_soap_request]) {
                    $line =~ s/user_soap_request/$args{-user_soap_request}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_request: $args{-user_soap_request} \n");
                }
			#Replace user_soap_response
                elsif ($line =~ m[user_soap_response]) {
                    $line =~ s/user_soap_response/$args{-user_soap_response}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_response: $args{-user_soap_response} \n");
                }

		}
		
		elsif ($xmlfile =~ /removeXmppSystemProfile14.0/i)
        {
            foreach ('-user_serviceProfileName', '-user_soap_request', '-user_soap_response' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_serviceProfileName
                if ($line =~ m[user_serviceProfileName]) {
                    $line =~ s/user_serviceProfileName/$args{-user_serviceProfileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_serviceProfileName: $args{-user_serviceProfileName} \n");
                }

			#Replace user_soap_request
                elsif ($line =~ m[user_soap_request]) {
                    $line =~ s/user_soap_request/$args{-user_soap_request}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_request: $args{-user_soap_request} \n");
                }
			#Replace user_soap_response
                elsif ($line =~ m[user_soap_response]) {
                    $line =~ s/user_soap_response/$args{-user_soap_response}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_response: $args{-user_soap_response} \n");
                }

		}
		elsif ($xmlfile =~ /addXmppSystemProfile14.0/i)
        {
            foreach ('-user_serviceProfileName', '-user_externalNode', '-user_soap_request', '-user_soap_response' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

			#Replace user_serviceProfileName
                if ($line =~ m[user_serviceProfileName]) {
                    $line =~ s/user_serviceProfileName/$args{-user_serviceProfileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_serviceProfileName: $args{-user_serviceProfileName} \n");
                }

			#Replace user_externalNode
                elsif ($line =~ m[user_externalNode]) {
                    $line =~ s/user_externalNode/$args{-user_externalNode}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_externalNode: $args{-user_externalNode} \n");
                }

			##Replace user_soap_request
                elsif ($line =~ m[user_soap_request]) {
                    $line =~ s/user_soap_request/$args{-user_soap_request}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_request: $args{-user_soap_request} \n");
                }
			#Replace user_soap_response
                elsif ($line =~ m[user_soap_response]) {
                    $line =~ s/user_soap_response/$args{-user_soap_response}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_response: $args{-user_soap_response} \n");
                }

		}
		elsif ($xmlfile =~ /updatePasswordRulesOMI-14.0/i)
        {
            foreach ('-user_omi_userID', '-user_omi_Version', '-user_omi_sessionID', '-user_passwordRuleName', '-user_password_expiryNotificationDays', '-user_maxPasswordDays', '-user_minPasswordChars', '-user_password_minLowercaseChars', '-user_minPasswordHours', '-user_minPasswordLength', '-user_password_minSpecialChars', '-user_password_minUppercaseChars', '-user_passwordHistorySize', '-user_boolean_userIDpermitted', '-user_soap_request', '-user_soap_response' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }

		#Replace user_omi_userID
                if ($line =~ m[user_omi_userID]) {
                    $line =~ s/user_omi_userID/$args{-user_omi_userID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_omi_userID: $args{-user_omi_userID} \n");
                }

		#Replace user_omi_Version
                elsif ($line =~ m[user_omi_Version]) {
                    $line =~ s/user_omi_Version/$args{-user_omi_Version}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_omi_Version: $args{-user_omi_Version} \n");
                }

		#Replace user_omi_sessionID
                elsif ($line =~ m[user_omi_sessionID]) {
                    $line =~ s/user_omi_sessionID/$args{-user_omi_sessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_omi_sessionID: $args{-user_omi_sessionID} \n");
                }

		#Replace user_passwordRuleName
                elsif ($line =~ m[user_passwordRuleName]) {
                    $line =~ s/user_passwordRuleName/$args{-user_passwordRuleName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_passwordRuleName: $args{-user_passwordRuleName} \n");
                }

		#Replace user_password_expiryNotificationDays
                elsif ($line =~ m[user_password_expiryNotificationDays]) {
                    $line =~ s/user_password_expiryNotificationDays/$args{-user_password_expiryNotificationDays}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_password_expiryNotificationDays: $args{-user_password_expiryNotificationDays} \n");
                }

		#Replace user_maxPasswordDays
                elsif ($line =~ m[user_maxPasswordDays]) {
                    $line =~ s/user_maxPasswordDays/$args{-user_maxPasswordDays}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_maxPasswordDays: $args{-user_maxPasswordDays} \n");
                }

		#Replace user_minPasswordChars
                elsif ($line =~ m[user_minPasswordChars]) {
                    $line =~ s/user_minPasswordChars/$args{-user_minPasswordChars}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_minPasswordChars: $args{-user_minPasswordChars} \n");
                }

		#Replace user_password_minLowercaseChars
                elsif ($line =~ m[user_password_minLowercaseChars]) {
                    $line =~ s/user_password_minLowercaseChars/$args{-user_password_minLowercaseChars}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_password_minLowercaseChars: $args{-user_password_minLowercaseChars} \n");
                }

		#Replace user_minPasswordHours
                elsif ($line =~ m[user_minPasswordHours]) {
                    $line =~ s/user_minPasswordHours/$args{-user_minPasswordHours}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_minPasswordHours: $args{-user_minPasswordHours} \n");
                }

		#Replace user_minPasswordLength
                elsif ($line =~ m[user_minPasswordLength]) {
                    $line =~ s/user_minPasswordLength/$args{-user_minPasswordLength}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_minPasswordLength: $args{-user_minPasswordLength} \n");
                }

		#Replace user_password_minSpecialChars
                elsif ($line =~ m[user_password_minSpecialChars]) {
                    $line =~ s/user_password_minSpecialChars/$args{-user_password_minSpecialChars}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_password_minSpecialChars: $args{-user_password_minSpecialChars} \n");
                }

		#Replace user_password_minUppercaseChars
                elsif ($line =~ m[user_password_minUppercaseChars]) {
                    $line =~ s/user_password_minUppercaseChars/$args{-user_password_minUppercaseChars}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_password_minUppercaseChars: $args{-user_password_minUppercaseChars} \n");
                }

		#Replace user_passwordHistorySize
                elsif ($line =~ m[user_passwordHistorySize]) {
                    $line =~ s/user_passwordHistorySize/$args{-user_passwordHistorySize}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_passwordHistorySize: $args{-user_passwordHistorySize} \n");
                }

		#Replace user_boolean_userIDpermitted
                elsif ($line =~ m[user_boolean_userIDpermitted]) {
                    $line =~ s/user_boolean_userIDpermitted/$args{-user_boolean_userIDpermitted}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_boolean_userIDpermitted: $args{-user_boolean_userIDpermitted} \n");
                }
		#Replace user_soap_request
                elsif ($line =~ m[user_soap_request]) {
                    $line =~ s/user_soap_request/$args{-user_soap_request}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_request: $args{-user_soap_request} \n");
                }
			#Replace user_soap_response
                elsif ($line =~ m[user_soap_response]) {
                    $line =~ s/user_soap_response/$args{-user_soap_response}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_soap_response: $args{-user_soap_response} \n");
                }

		}
		
		
	elsif ($xmlfile =~ /addSipProfileOMI-14.0/i)
        {
            foreach ('-user_userID', '-user_OMIVersion', '-user_sessionID', '-user_profileName', '-user_description', '-user_sipSignaling' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

#Replace user_userID
                if ($line =~ m[user_userID]) {
                    $line =~ s/user_userID/$args{-user_userID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_userID: $args{-user_userID} \n");
                }

#Replace user_OMIVersion
                elsif ($line =~ m[user_OMIVersion]) {
                    $line =~ s/user_OMIVersion/$args{-user_OMIVersion}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_OMIVersion: $args{-user_OMIVersion} \n");
                }

#Replace user_sessionID
                elsif ($line =~ m[user_sessionID]) {
                    $line =~ s/user_sessionID/$args{-user_sessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_sessionID: $args{-user_sessionID} \n");
                }

#Replace user_profileName
                elsif ($line =~ m[user_profileName]) {
                    $line =~ s/user_profileName/$args{-user_profileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_profileName: $args{-user_profileName} \n");
                }

#Replace user_description
                elsif ($line =~ m[user_description]) {
                    $line =~ s/user_description/$args{-user_description}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_description: $args{-user_description} \n");
                }

#Replace user_sipSignaling
                elsif ($line =~ m[user_sipSignaling]) {
                    $line =~ s/user_sipSignaling/$args{-user_sipSignaling}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_sipSignaling: $args{-user_sipSignaling} \n");
                }

}

elsif ($xmlfile =~ /setDNandNQforUser-14.0/i)
        {
            foreach ('-user_name', '-user_privateDNNumber', '-user_privateNQName', '-user_publicDNNumber', '-user_publicNQName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }

 #Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

 #Replace user_privateDNNumber
                elsif ($line =~ m[user_privateDNNumber]) {
                    $line =~ s/user_privateDNNumber/$args{-user_privateDNNumber}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_privateDNNumber: $args{-user_privateDNNumber} \n");
                }

 #Replace user_privateNQName
                elsif ($line =~ m[user_privateNQName]) {
                    $line =~ s/user_privateNQName/$args{-user_privateNQName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_privateNQName: $args{-user_privateNQName} \n");
                }

 #Replace user_publicDNNumber
                elsif ($line =~ m[user_publicDNNumber]) {
                    $line =~ s/user_publicDNNumber/$args{-user_publicDNNumber}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_publicDNNumber: $args{-user_publicDNNumber} \n");
                }

 #Replace user_publicNQName
                elsif ($line =~ m[user_publicNQName]) {
                    $line =~ s/user_publicNQName/$args{-user_publicNQName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_publicNQName: $args{-user_publicNQName} \n");
                }

}

elsif ($xmlfile =~ /setUserChargeInfo-14.0/i)
        {
            foreach ('-user_name', '-user_privateChargeId', '-user_publicChargeId' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }

 #Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

 #Replace user_privateChargeId
                elsif ($line =~ m[user_privateChargeId]) {
                    $line =~ s/user_privateChargeId/$args{-user_privateChargeId}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_privateChargeId: $args{-user_privateChargeId} \n");
                }

 #Replace user_publicChargeId
                elsif ($line =~ m[user_publicChargeId]) {
                    $line =~ s/user_publicChargeId/$args{-user_publicChargeId}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_publicChargeId: $args{-user_publicChargeId} \n");
                }

}

elsif ($xmlfile =~ /setUserDirectoryNumbers-14.0/i)
        {
            foreach ('-user_name', '-user_DN1', '-user_DN2' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }

 #Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

 #Replace user_DN1
                elsif ($line =~ m[user_DN1]) {
                    $line =~ s/user_DN1/$args{-user_DN1}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_DN1: $args{-user_DN1} \n");
                }

 #Replace user_DN2
                elsif ($line =~ m[user_DN2]) {
                    $line =~ s/user_DN2/$args{-user_DN2}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_DN2: $args{-user_DN2} \n");
                }

}

elsif ($xmlfile =~ /updateConfigParmOMI-14.0/i)
        {
            foreach ('-user_userID', '-user_OMIVersion', '-user_sessionID', '-user_groupName', '-user_parmName', '-user_parmType', '-user_parmValue', '-user_NELongName', '-user_NEShortName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

 #Replace user_userID
                if ($line =~ m[user_userID]) {
                    $line =~ s/user_userID/$args{-user_userID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_userID: $args{-user_userID} \n");
                }

 #Replace user_OMIVersion
                elsif ($line =~ m[user_OMIVersion]) {
                    $line =~ s/user_OMIVersion/$args{-user_OMIVersion}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_OMIVersion: $args{-user_OMIVersion} \n");
                }

 #Replace user_sessionID
                elsif ($line =~ m[user_sessionID]) {
                    $line =~ s/user_sessionID/$args{-user_sessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_sessionID: $args{-user_sessionID} \n");
                }

 #Replace user_groupName
                elsif ($line =~ m[user_groupName]) {
                    $line =~ s/user_groupName/$args{-user_groupName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_groupName: $args{-user_groupName} \n");
                }

 #Replace user_parmName
                elsif ($line =~ m[user_parmName]) {
                    $line =~ s/user_parmName/$args{-user_parmName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_parmName: $args{-user_parmName} \n");
                }

 #Replace user_parmType
                elsif ($line =~ m[user_parmType]) {
                    $line =~ s/user_parmType/$args{-user_parmType}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_parmType: $args{-user_parmType} \n");
                }

 #Replace user_parmValue
                elsif ($line =~ m[user_parmValue]) {
                    $line =~ s/user_parmValue/$args{-user_parmValue}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_parmValue: $args{-user_parmValue} \n");
                }

 #Replace user_NELongName
                elsif ($line =~ m[user_NELongName]) {
                    $line =~ s/user_NELongName/$args{-user_NELongName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_NELongName: $args{-user_NELongName} \n");
                }

 #Replace user_NEShortName
                elsif ($line =~ m[user_NEShortName]) {
                    $line =~ s/user_NEShortName/$args{-user_NEShortName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_NEShortName: $args{-user_NEShortName} \n");
                }

}


elsif ($xmlfile =~ /deleteSipProfileOMI-14.0/i)
        {
            foreach ('-user_userID', '-user_OMIVersion', '-user_sessionID', '-user_profileName' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

#Replace user_userID
                if ($line =~ m[user_userID]) {
                    $line =~ s/user_userID/$args{-user_userID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_userID: $args{-user_userID} \n");
                }

#Replace user_OMIVersion
                elsif ($line =~ m[user_OMIVersion]) {
                    $line =~ s/user_OMIVersion/$args{-user_OMIVersion}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_OMIVersion: $args{-user_OMIVersion} \n");
                }

#Replace user_sessionID
                elsif ($line =~ m[user_sessionID]) {
                    $line =~ s/user_sessionID/$args{-user_sessionID}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_sessionID: $args{-user_sessionID} \n");
                }

#Replace user_profileName
                elsif ($line =~ m[user_profileName]) {
                    $line =~ s/user_profileName/$args{-user_profileName}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_profileName: $args{-user_profileName} \n");
                }

}

elsif ($xmlfile =~ /assignSingleServiceForUser/i)
        {
            foreach ('-user_name', '-user_service_name', '-user_vendor_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

            #Replace user_name
            if ($line =~ m[user_name]) {
                $line =~ s/user_name/$args{-user_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
            }

            #Replace user_service_name
            elsif ($line =~ m[user_service_name]) {
                $line =~ s/user_service_name/$args{-user_service_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_service_name: $args{-user_service_name} \n");
            }

            #Replace user_vendor_name
            elsif ($line =~ m[user_vendor_name]) {
                $line =~ s/user_vendor_name/$args{-user_vendor_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_vendor_name: $args{-user_vendor_name} \n");
	        }

        }
		
		elsif ($xmlfile =~ /removeSingleServiceFromUser/i)
        {
            foreach ('-user_name', '-user_service_name', '-user_vendor_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

            #Replace user_name
            if ($line =~ m[user_name]) {
                $line =~ s/user_name/$args{-user_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
            }

            #Replace user_service_name
            elsif ($line =~ m[user_service_name]) {
                $line =~ s/user_service_name/$args{-user_service_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_service_name: $args{-user_service_name} \n");
            }

            #Replace user_vendor_name
            elsif ($line =~ m[user_vendor_name]) {
                $line =~ s/user_vendor_name/$args{-user_vendor_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_vendor_name: $args{-user_vendor_name} \n");
	        }

        }
		
		elsif ($xmlfile =~ /addBLFSystemProfile/i)
        {
            foreach ('-user_systemProfileName', '-user_earlyFlag') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

            #Replace user_systemProfileName
            if ($line =~ m[user_systemProfileName]) {
                $line =~ s/user_systemProfileName/$args{-user_systemProfileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_systemProfileName: $args{-user_systemProfileName} \n");
            }

            #Replace user_earlyFlag
            elsif ($line =~ m[user_earlyFlag]) {
                $line =~ s/user_earlyFlag/$args{-user_earlyFlag}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_earlyFlag: $args{-user_earlyFlag} \n");
            }

        }
		
		elsif ($xmlfile =~ /addDomainForBLFSystemProfile/i)
        {
            foreach ('-user_systemProfileName', '-user_domainName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

            #Replace user_systemProfileName
            if ($line =~ m[user_systemProfileName]) {
                $line =~ s/user_systemProfileName/$args{-user_systemProfileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_systemProfileName: $args{-user_systemProfileName} \n");
            }

            #Replace user_domainName
            elsif ($line =~ m[user_domainName]) {
                $line =~ s/user_domainName/$args{-user_domainName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domainName: $args{-user_domainName} \n");
            }
        }
		
		elsif ($xmlfile =~ /removeDomainFromBLFSystemProfile/i)
        {
            foreach ('-user_systemProfileName', '-user_domainName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

            #Replace user_systemProfileName
            if ($line =~ m[user_systemProfileName]) {
                $line =~ s/user_systemProfileName/$args{-user_systemProfileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_systemProfileName: $args{-user_systemProfileName} \n");
            }

            #Replace user_domainName
            elsif ($line =~ m[user_domainName]) {
                $line =~ s/user_domainName/$args{-user_domainName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domainName: $args{-user_domainName} \n");
            }
        }

        elsif ($xmlfile =~ /removeBLFSystemProfile/i)
        {
            foreach ('-user_systemProfileName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

            #Replace user_systemProfileName
            if ($line =~ m[user_systemProfileName]) {
                $line =~ s/user_systemProfileName/$args{-user_systemProfileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_systemProfileName: $args{-user_systemProfileName} \n");
            }
        }
		
		elsif ($xmlfile =~ /setBLFSystemProfileForUser/i)
        {
            foreach ('-user_name', '-user_systemProfileName') {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }
			
			#Replace user_name
            if ($line =~ m[user_name]) {
                $line =~ s/user_name/$args{-user_name}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
            }

            #Replace user_systemProfileName
            if ($line =~ m[user_systemProfileName]) {
                $line =~ s/user_systemProfileName/$args{-user_systemProfileName}/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_systemProfileName: $args{-user_systemProfileName} \n");
            }
        }
elsif ($xmlfile =~ /simuser-14.0/i)
        {
            foreach ('-user_name', '-user_activeBoolean', '-user_number1', '-user_number2', '-user_number3','-user_number4', '-user_numRings' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
 	#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

 	#Replace user_activeBoolean
                elsif ($line =~ m[user_activeBoolean]) {
                    $line =~ s/user_activeBoolean/$args{-user_activeBoolean}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_activeBoolean: $args{-user_activeBoolean} \n");
                }

 	#Replace user_number1
                elsif ($line =~ m[user_number1]) {
                    $line =~ s/user_number1/$args{-user_number1}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_number1: $args{-user_number1} \n");
                }

 	#Replace user_number2
                elsif ($line =~ m[user_number2]) {
                    $line =~ s/user_number2/$args{-user_number2}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_number2: $args{-user_number2} \n");
                }

 	#Replace user_number3
                elsif ($line =~ m[user_number3]) {
                    $line =~ s/user_number3/$args{-user_number3}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_number3: $args{-user_number3} \n");
                }
       #Replace user_number4
                elsif ($line =~ m[user_number4]) {
                    $line =~ s/user_number4/$args{-user_number4}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_number4: $args{-user_number4} \n");
                }


 	#Replace user_numRings
                elsif ($line =~ m[user_numRings]) {
                    $line =~ s/user_numRings/$args{-user_numRings}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_numRings: $args{-user_numRings} \n");
                }
	} 
	elsif ($xmlfile =~ /modifyroute-14.0/i)
        {
            foreach ('-user_name', '-user_activeBoolean', '-user_number1', '-user_number2', '-user_number3', '-user_numRings' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }
 	#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

 	#Replace user_activeBoolean
                elsif ($line =~ m[user_activeBoolean]) {
                    $line =~ s/user_activeBoolean/$args{-user_activeBoolean}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_activeBoolean: $args{-user_activeBoolean} \n");
                }

 	#Replace user_number1
                elsif ($line =~ m[user_number1]) {
                    $line =~ s/user_number1/$args{-user_number1}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_number1: $args{-user_number1} \n");
                }

 	#Replace user_number2
                elsif ($line =~ m[user_number2]) {
                    $line =~ s/user_number2/$args{-user_number2}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_number2: $args{-user_number2} \n");
                }

 	#Replace user_number3
                elsif ($line =~ m[user_number3]) {
                    $line =~ s/user_number3/$args{-user_number3}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_number3: $args{-user_number3} \n");
                }

 	#Replace user_numRings
                elsif ($line =~ m[user_numRings]) {
                    $line =~ s/user_numRings/$args{-user_numRings}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_numRings: $args{-user_numRings} \n");
                }
	}     



elsif ($xmlfile =~ /addsystemProfile_14.0/i)
        {
            foreach ('-user_profilename', '-user_value', '-user_ringlist', '-user_peruser', '-user_maxroute', '-user_Noanswer', '-user_routing', '-user_unreachable', '-user_notloggedin' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                                        last;
                }
            }

                #Replace user_profilename
                if ($line =~ m[user_profilename]) {
                    $line =~ s/user_profilename/$args{-user_profilename}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_profilename: $args{-user_profilename} \n");
                }

                #Replace user_value
                elsif ($line =~ m[user_value]) {
                    $line =~ s/user_value/$args{-user_value}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_value: $args{-user_value} \n");
                }

                #Replace user_ringlist
                elsif ($line =~ m[user_ringlist]) {
                    $line =~ s/user_ringlist/$args{-user_ringlist}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_ringlist: $args{-user_ringlist} \n");
                }

                #Replace user_peruser
                elsif ($line =~ m[user_peruser]) {
                    $line =~ s/user_peruser/$args{-user_peruser}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_peruser: $args{-user_peruser} \n");
                }

                #Replace user_maxroute
                elsif ($line =~ m[user_maxroute]) {
                    $line =~ s/user_maxroute/$args{-user_maxroute}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_maxroute: $args{-user_maxroute} \n");
                }

                #Replace user_Noanswer
                elsif ($line =~ m[user_Noanswer]) {
                    $line =~ s/user_Noanswer/$args{-user_Noanswer}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_Noanswer: $args{-user_Noanswer} \n");
                }

                #Replace user_routing
                elsif ($line =~ m[user_routing]) {
                    $line =~ s/user_routing/$args{-user_routing}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_routing: $args{-user_routing} \n");
                }

                #Replace user_unreachable
                elsif ($line =~ m[user_unreachable]) {
                    $line =~ s/user_unreachable/$args{-user_unreachable}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_unreachable: $args{-user_unreachable} \n");
                }

                #Replace user_notloggedin
                elsif ($line =~ m[user_notloggedin]) {
                    $line =~ s/user_notloggedin/$args{-user_notloggedin}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_notloggedin: $args{-user_notloggedin} \n");
                }

        }


elsif ($xmlfile =~ /addsystemProfileforDomain_14.0/i)
        {
            foreach ('-user_domain', '-user_profilename' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

                #Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

                #Replace user_profilename
                elsif ($line =~ m[user_profilename]) {
                    $line =~ s/user_profilename/$args{-user_profilename}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_profilename: $args{-user_profilename} \n");
                }

        }



elsif ($xmlfile =~ /removeSystemProfileforUser_14.0/i)
        {
            foreach ('-user_name' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                                        last;
                }
            }

                #Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

        }

elsif ($xmlfile =~ /removesystemProfilefromDomain_14.0/i)
        {
            foreach ('-user_domain', '-user_profilename' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                                        last;
                }
            }

                #Replace user_domain
                if ($line =~ m[user_domain]) {
                    $line =~ s/user_domain/$args{-user_domain}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_domain: $args{-user_domain} \n");
                }

                #Replace user_profilename
                elsif ($line =~ m[user_profilename]) {
                    $line =~ s/user_profilename/$args{-user_profilename}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_profilename: $args{-user_profilename} \n");
                }

        }

elsif ($xmlfile =~ /removesystemProfileall_14.0/i)
        {
            foreach ('-user_profilename' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    last;
                }
            }

                #Replace user_profilename
                if ($line =~ m[user_profilename]) {
                    $line =~ s/user_profilename/$args{-user_profilename}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_profilename: $args{-user_profilename} \n");
                }

        }

elsif ($xmlfile =~ /setAdvScrSPForUser-14.0/i)
        {
            foreach ('-user_name', '-user_advScreeningSysProfile' ) {
                unless ($args{$_}) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
                    $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
                    $flag = 0;
                    last;
                }
            }

 	#Replace user_name
                if ($line =~ m[user_name]) {
                    $line =~ s/user_name/$args{-user_name}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_name: $args{-user_name} \n");
                }

	 #Replace user_advScreeningSysProfile
                elsif ($line =~ m[user_advScreeningSysProfile]) {
                    $line =~ s/user_advScreeningSysProfile/$args{-user_advScreeningSysProfile}/;
                    $logger->debug(__PACKAGE__ . ".$sub_name: Replace user_advScreeningSysProfile: $args{-user_advScreeningSysProfile} \n");
                }

	}   

		
		else {
            $logger->error(__PACKAGE__ . ".$sub_name:  Invalid xml file $xmlfile specified");
            $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [0]");
            $flag = 0;
            last;
        }
    print OUT $line;

    last unless ($flag == 1);
    }
    close IN;
    close OUT;
    $logger->debug(__PACKAGE__ . ".$sub_name: Close xml file");
    return 0 if ($flag == 0);
    #run xml file
    unless (@cmdResults = $self->{conn}->cmd("/opt/SoapUI-5.4.0/bin/testrunner.sh -r $out_file")) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Could not execute command: /opt/SoapUI-5.4.0/bin/testrunner.sh -r $out_file");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }    
    $logger->debug(__PACKAGE__ . ".$sub_name: Run xml file");
    #waiting for login and password prompts and
    $cmdResult = join("",@cmdResults);
    $logger->debug(__PACKAGE__ . ".$sub_name: $cmdResult");
    unless ($cmdResult =~ m[Receiving response\: HTTP\/1.1 200 OK]) {
        $logger->error(__PACKAGE__ . ".$sub_name: Execute command failed: /opt/SoapUI-5.4.0/bin/testrunner.sh -r $out_file");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<runSOAPRequest()>

    This function read xml file, replace value from input and save on _new file. Then send SOAPUI request using LWP module in Perl.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        ip
        port
        username
        password
        xmlfile
        parameters 

=item Returns:

        Returns : $response 

=item Example:

        my %args = (
        ip => $provHost,
        port => $prov_port,
        username => $provUserName,
        password => $provPasswd,
        xmlfile => 'addNewSP.xml',
        parameters => {
                        usr_profileName => 'auto_test_callgrabber',
                        usr_fromRegisteredClients => 'true',
                        usr_fromTrustedNodes => 'true',
                        usr_domainNames => ['tma6.automation.com', 'example.com']
                    }
        );

        my $response = $self->runSOAPRequest(%args);
        
        unless ($response->code == 200) {
            $logger->error(__PACKAGE__ . " .$sub_name : $tcid - Failed to run SOAP request ");
            $response->content; # show detail error
            return 0;
       } 
       
=back

=cut

sub runSOAPRequest {
    my ($self, %args) = @_;
    my $sub_name = "runSOAPRequest";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('ip', 'port', 'xmlfile', 'parameters') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present ");
            $flag = 0;
            last;
        }
    }
    unless ($flag) {
        $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
        return $flag;
    }
    
    my @path = split(/.xml/, $args{xmlfile});
    
    my $in_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/AS/SOAP_UI_FILE/".$args{xmlfile};
    my $out_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/AS/SOAP_UI_FILE/".$path[0]."_new.xml";
    
    unless ( open(IN, "<$in_file")) {
        $logger->error( __PACKAGE__ . ".$sub_name: open $in_file failed " );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Open xml file \n");
    unless (open OUT, ">$out_file") {
        $logger->error( __PACKAGE__ . ".$sub_name: open $out_file failed " );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Create new xml file \n");
    
    
    my @keys = keys %{$args{parameters}};
    my @values = values %args;
    my ($line, $url);
    while ($line = <IN>) {
        if ($line =~ /<!--\s*URL:\s*(.+)\s*--/) {
            $url = $1;
            $url =~ s/ProvisioningHost/$args{ip}:$args{port}/;
        }
        elsif ($line =~ /<.+>(.+)<\/.+>/ && exists $args{parameters}{$1}) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Replace parameter '$1' with value '$args{parameters}{$1}' \n");
            my $k = $1;
            $line =~ s/$k/$args{parameters}{$k}/;
        }
        elsif ($line =~ /Input Domains/) {
            unless (exists $args{parameters}{usr_domainNames}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_domainNames' not present ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_domainNames}}) {
                print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:DomainNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"common.ws.nortelnetworks.com\">";
                print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                print OUT "</multiRef>";
                print OUT "\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Set domain: $_ in $args{xmlfile} \n");
            }
            next;
        } 
        elsif ($line =~ /Input Branding Files/) {
            unless (exists $args{parameters}{usr_brandingFiles}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_brandingFiles' not present ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_brandingFiles}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:BrandingFileNaturalKeyDO\" xmlns:ns4=\"branding.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                print OUT "</multiRef>";
                print OUT "\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Set Branding File: $_ in $args{xmlfile} \n");
            }
            next;
        }
		elsif ($line =~ /Input Selective Reject Entries/) {
			unless (exists $args{parameters}{usr_selectiveRejectEntries}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_selectiveRejectEntries' not present ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
			foreach (@{$args{parameters}{usr_selectiveRejectEntries}}) {
				print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns2:BarredEntry\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns2=\"callscreening.opi.ims.nortelnetworks.com\">";
				print OUT "<barredEntryName xsi:type=\"xsd:string\">$_</barredEntryName>";
				print OUT "</multiRef>";
				print OUT "\n";
				$logger->debug(__PACKAGE__ . ".$sub_name: Set domain: $_ in $args{xmlfile} \n");
			}
			next;
		}
        elsif ($line =~ /Input Locations To Pool/) {
            unless (exists $args{parameters}{usr_locationNames}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_locationNames' not present ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_locationNames}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:LocationNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"core.data.ws.nortelnetworks.com\">";
                print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                print OUT "</multiRef>";
                print OUT "\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Set location : $_ to pool  in $args{xmlfile} \n");
            }
            next;
        }
        elsif ($line =~ /Input Crbt Files/) {
            unless (exists $args{parameters}{usr_fileNames}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_fileNames' not present ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            for my $i (0 .. $#{$args{parameters}{usr_fileNames}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:CrbtFileDO\" xmlns:ns3=\"crbt.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">${$args{parameters}{usr_fileNames}}[$i]</name>";
                print OUT "<displayName xsi:type=\"xsd:string\">${$args{parameters}{usr_displayNames}}[$i]</displayName>";
                print OUT "</multiRef>";
                print OUT "\n";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Set crbt files in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Input Account Codes/) {
            unless (exists $args{parameters}{usr_accountCodeNames} && exists $args{parameters}{usr_accountCodeValues}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_accountCodeNames' or 'usr_accountCodeValues' not present ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            for my $i (0 .. $#{$args{parameters}{usr_accountCodeNames}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:AccountCodeDO\" xmlns:ns4=\"accountcodes.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">${$args{parameters}{usr_accountCodeNames}}[$i]</name>";
                print OUT "<value xsi:type=\"xsd:string\">${$args{parameters}{usr_accountCodeValues}}[$i]</value>";
                print OUT "</multiRef>";
                print OUT "\n";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Set account code name and value  in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Input Exclusion List/) {
            unless (exists $args{parameters}{usr_executionList} ) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_executionList' not present ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_executionList}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:AccountCodeExclusionNaturalKeyDO\" xmlns:ns3=\"accountcodes.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                print OUT "</multiRef>";
                print OUT "\n";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Set Exclusion list in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Input External Users/) {
            unless (exists $args{parameters}{usr_externalUsers} ) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_externalUsers' not present ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_externalUsers}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns5:ExternalUserNaturalKeyDO\" xmlns:ns5=\"cug.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                print OUT "</multiRef>";
                print OUT "\n";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Set External Users in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Input Ranges For CUG/) {
            unless (exists $args{parameters}{usr_fromDN} && exists $args{parameters}{usr_toDN}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_fromDN' or 'usr_toDN' not present ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            for my $i (0 .. $#{$args{parameters}{usr_fromDN}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns6:CUGRangeDO\" xmlns:ns6=\"cug.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<fromDn xsi:type=\"xsd:string\">${$args{parameters}{usr_fromDN}}[$i]</fromDn>";
                print OUT "<toDn xsi:type=\"xsd:string\">${$args{parameters}{usr_toDN}}[$i]</toDn>";
                print OUT "</multiRef>";
                print OUT "\n";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Set Ranges For CUG in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Input Users For CUG/) {
            unless (exists $args{parameters}{usr_users}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_users' or 'usr_users' not present ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_users}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:CUGUserDO\" xmlns:ns4=\"cug.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<cugUserProperty xsi:type=\"ns4:CUGUserPropertyDO\" xsi:nil=\"true\"/>";
                print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                print OUT "</multiRef>";
                print OUT "\n";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Set Users For CUG  in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Input CUG Group Calls/) {
            if (exists $args{parameters}{usr_incCallEnabledGroups}) {
                print OUT "<incCallEnabledGroups xsi:type=\"cug:ArrayOf_tns167_GroupNaturalKeyDO\" soapenc:arrayType=\"gro:GroupNaturalKeyDO[]\" xmlns:gro=\"group.data.ws.nortelnetworks.com\">";
                foreach (@{$args{parameters}{usr_incCallEnabledGroups}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns7:GroupNaturalKeyDO\" xmlns:ns7=\"group.data.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                    print OUT "</multiRef>"; 
                }
                print OUT "</incCallEnabledGroups>";
                print OUT "\n"; 
                $logger->debug(__PACKAGE__ . ".$sub_name: Set usr_incCallEnabledGroups CUG  in $args{xmlfile} \n");
            }
            if (exists $args{parameters}{usr_incCallDisabledGroups}) {
                print OUT "<incCallDisabledGroups xsi:type=\"cug:ArrayOf_tns167_GroupNaturalKeyDO\" soapenc:arrayType=\"gro:GroupNaturalKeyDO[]\" xmlns:gro=\"group.data.ws.nortelnetworks.com\">";
                foreach (@{$args{parameters}{usr_incCallDisabledGroups}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns7:GroupNaturalKeyDO\" xmlns:ns7=\"group.data.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                    print OUT "</multiRef>";
                }
                print OUT "</incCallDisabledGroups>";
                print OUT "\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Set usr_incCallDisabledGroups CUG  in $args{xmlfile} \n");
            }
            if (exists $args{parameters}{usr_outCallEnabledGroups}) {
                print OUT "<outCallEnabledGroups xsi:type=\"cug:ArrayOf_tns167_GroupNaturalKeyDO\" soapenc:arrayType=\"gro:GroupNaturalKeyDO[]\" xmlns:gro=\"group.data.ws.nortelnetworks.com\">";
                foreach (@{$args{parameters}{usr_outCallEnabledGroups}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns7:GroupNaturalKeyDO\" xmlns:ns7=\"group.data.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                    print OUT "</multiRef>";
                }
                print OUT "</outCallEnabledGroups>";
                print OUT "\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Set usr_outCallEnabledGroups CUG  in $args{xmlfile} \n");
            }
            if (exists $args{parameters}{usr_outCallDisabledGroups}) {
                print OUT "<outCallDisabledGroups xsi:type=\"cug:ArrayOf_tns167_GroupNaturalKeyDO\" soapenc:arrayType=\"gro:GroupNaturalKeyDO[]\" xmlns:gro=\"group.data.ws.nortelnetworks.com\">";
                foreach (@{$args{parameters}{usr_outCallDisabledGroups}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns7:GroupNaturalKeyDO\" xmlns:ns7=\"group.data.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                    print OUT "</multiRef>";
                }
                print OUT "</outCallDisabledGroups>";
                print OUT "\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Set usr_outCallDisabledGroups CUG  in $args{xmlfile} \n");
            }
            next;
        }
        elsif ($line =~ /Input Authorization Code Names/) {
            unless (exists $args{parameters}{usr_authCodeNames}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_authCodeNames' or 'usr_authCodeNames' not present ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_authCodeNames}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:AuthCodeNaturalKeyDO\" xmlns:ns3=\"authcodes.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                print OUT "</multiRef>";
                print OUT "\n";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Set Authorization Code Names  in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Input Services/) {
            unless (exists $args{parameters}{usr_services}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_services' or 'usr_services' not present ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_services}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns6:ServiceNaturalKeyDO\" xmlns:ns6=\"common.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                print OUT "</multiRef>";
                print OUT "\n";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Set Services For user  in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Input Vendor/) {
            foreach (@{$args{parameters}{usr_services}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns7:VendorNaturalKeyDO\" xmlns:ns7=\"coresvcs.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">nortel</name>";
                print OUT "</multiRef>";
                print OUT "\n";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Set Norterl For user  in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Input Destinations /) {
            if ($args{parameters}{usr_routeName} eq 'CS_RT_SIM_LBL') {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns19:CallDestinationDO\" xmlns:ns19=\"routes.data.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<destinations soapenc:arrayType=\"soapenc:string[1]\" xsi:type=\"soapenc:Array\">";
                    foreach (@{$args{parameters}{usr_Destinations}}) {
                        print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                        print OUT "\n";
                    }
                print OUT "</destinations>";
                print OUT "<numberofRings xsi:type=\"xsd:int\">$args{parameters}{usr_numberofRings}</numberofRings>";
                print OUT "</multiRef>";
            }
            elsif ($args{parameters}{usr_routeName} eq 'CS_RT_SEQ_LBL') {
                foreach (@{$args{parameters}{usr_Destinations}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns19:CallDestinationDO\" xmlns:ns19=\"routes.data.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<destinations soapenc:arrayType=\"soapenc:string[1]\" xsi:type=\"soapenc:Array\">";
                    print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                    print OUT "</destinations>";
                    print OUT "<numberofRings xsi:type=\"xsd:int\">$args{parameters}{usr_numberofRings}</numberofRings>";
                    print OUT "</multiRef>";
                }
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Set destination For call route action  in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Input Presence States/) {
            if ($args{parameters}{usr_activeOnPhone} eq 'true') {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns5:PresenceStateNaturalKeyDO\" xmlns:ns5=\"presence.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">Active On the Phone</name>";
                print OUT "</multiRef>";
            }
            if ($args{parameters}{usr_unavailableBusy} eq 'true') {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns5:PresenceStateNaturalKeyDO\" xmlns:ns5=\"presence.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">Unavailable Busy</name>";
                print OUT "</multiRef>";
            }
            if ($args{parameters}{usr_unavailableOffline} eq 'true') {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns5:PresenceStateNaturalKeyDO\" xmlns:ns5=\"presence.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">Unavailable Offline</name>";
                print OUT "</multiRef>";
            }
            if ($args{parameters}{usr_unavailableOnVacation} eq 'true') {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns5:PresenceStateNaturalKeyDO\" xmlns:ns5=\"presence.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">Unavailable On Vacation</name>";
                print OUT "</multiRef>";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Set Presence States  in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Input Time Blocks/) {
            if (exists ($args{parameters}{Monday})) {
                for my $i (0 .. $#{$args{parameters}{Monday}{startTimes}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:TimeBlockDO\" xmlns:ns4=\"timeblock.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<days soapenc:arrayType=\"soapenc:boolean[7]\" xsi:type=\"soapenc:Array\">";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">true</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "</days>";
                    print OUT "<startTime xsi:type=\"xsd:string\">$args{parameters}{Monday}{startTimes}[$i]</startTime>";
                    print OUT "<stopTime xsi:type=\"xsd:string\">$args{parameters}{Monday}{stopTimes}[$i]</stopTime>";
                    print OUT "</multiRef>";
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: Add time blocks for Monday in $args{xmlfile} \n");
            }   
            if (exists ($args{parameters}{Tuesday})) {
                for my $i (0 .. $#{$args{parameters}{Tuesday}{startTimes}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:TimeBlockDO\" xmlns:ns4=\"timeblock.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<days soapenc:arrayType=\"soapenc:boolean[7]\" xsi:type=\"soapenc:Array\">";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">true</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "</days>";
                    print OUT "<startTime xsi:type=\"xsd:string\">$args{parameters}{Tuesday}{startTimes}[$i]</startTime>";
                    print OUT "<stopTime xsi:type=\"xsd:string\">$args{parameters}{Tuesday}{stopTimes}[$i]</stopTime>";
                    print OUT "</multiRef>";
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: Add time blocks for Tuesday in $args{xmlfile} \n");
            }
            if (exists ($args{parameters}{Wednesday})) {
                for my $i (0 .. $#{$args{parameters}{Wednesday}{startTimes}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:TimeBlockDO\" xmlns:ns4=\"timeblock.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<days soapenc:arrayType=\"soapenc:boolean[7]\" xsi:type=\"soapenc:Array\">";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">true</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "</days>";
                    print OUT "<startTime xsi:type=\"xsd:string\">$args{parameters}{Wednesday}{startTimes}[$i]</startTime>";
                    print OUT "<stopTime xsi:type=\"xsd:string\">$args{parameters}{Wednesday}{stopTimes}[$i]</stopTime>";
                    print OUT "</multiRef>";
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: Add time blocks for Wednesday in $args{xmlfile} \n");
            }
            if (exists ($args{parameters}{Thursday})) {
                for my $i (0 .. $#{$args{parameters}{Thursday}{startTimes}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:TimeBlockDO\" xmlns:ns4=\"timeblock.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<days soapenc:arrayType=\"soapenc:boolean[7]\" xsi:type=\"soapenc:Array\">";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">true</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "</days>";
                    print OUT "<startTime xsi:type=\"xsd:string\">$args{parameters}{Thursday}{startTimes}[$i]</startTime>";
                    print OUT "<stopTime xsi:type=\"xsd:string\">$args{parameters}{Thursday}{stopTimes}[$i]</stopTime>";
                    print OUT "</multiRef>";
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: Add time blocks for Thursday in $args{xmlfile} \n");
            }
            if (exists ($args{parameters}{Friday})) {
                for my $i (0 .. $#{$args{parameters}{Friday}{startTimes}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:TimeBlockDO\" xmlns:ns4=\"timeblock.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<days soapenc:arrayType=\"soapenc:boolean[7]\" xsi:type=\"soapenc:Array\">";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">true</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "</days>";
                    print OUT "<startTime xsi:type=\"xsd:string\">$args{parameters}{Friday}{startTimes}[$i]</startTime>";
                    print OUT "<stopTime xsi:type=\"xsd:string\">$args{parameters}{Friday}{stopTimes}[$i]</stopTime>";
                    print OUT "</multiRef>";
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: Add time blocks for Friday in $args{xmlfile} \n");
            }
            if (exists ($args{parameters}{Saturday})) {
                for my $i (0 .. $#{$args{parameters}{Saturday}{startTimes}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:TimeBlockDO\" xmlns:ns4=\"timeblock.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<days soapenc:arrayType=\"soapenc:boolean[7]\" xsi:type=\"soapenc:Array\">";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">true</days>";
                    print OUT "</days>";
                    print OUT "<startTime xsi:type=\"xsd:string\">$args{parameters}{Saturday}{startTimes}[$i]</startTime>";
                    print OUT "<stopTime xsi:type=\"xsd:string\">$args{parameters}{Saturday}{stopTimes}[$i]</stopTime>";
                    print OUT "</multiRef>";
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: Add time blocks for Saturday in $args{xmlfile} \n");
            }
            if (exists ($args{parameters}{Sunday})) {
                for my $i (0 .. $#{$args{parameters}{Sunday}{startTimes}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:TimeBlockDO\" xmlns:ns4=\"timeblock.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<days soapenc:arrayType=\"soapenc:boolean[7]\" xsi:type=\"soapenc:Array\">";
                    print OUT "<days xsi:type=\"soapenc:boolean\">true</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "<days xsi:type=\"soapenc:boolean\">false</days>";
                    print OUT "</days>";
                    print OUT "<startTime xsi:type=\"xsd:string\">$args{parameters}{Sunday}{startTimes}[$i]</startTime>";
                    print OUT "<stopTime xsi:type=\"xsd:string\">$args{parameters}{Sunday}{stopTimes}[$i]</stopTime>";
                    print OUT "</multiRef>";
                }
                $logger->debug(__PACKAGE__ . ".$sub_name: Add time blocks for Sunday in $args{xmlfile} \n");
            }
            next;
        }
		elsif ($line =~ /Add UCD Agents/) {
            if (exists $args{parameters}{usr_agents}) {
                print OUT '<agents xsi:type="ucd:ArrayOfUCDAgentNaturalKeyDO" soapenc:arrayType="ucd:UCDAgentNaturalKeyDO[]">';
                foreach (@{$args{parameters}{usr_agents}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns7:UCDAgentNaturalKeyDO\" xmlns:ns7=\"ucd.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                    print OUT "</multiRef>";
                    print OUT "\n";
                }
                print OUT "</agents>\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Add UCD Agents in $args{xmlfile} \n");    
                next;
            } 
        }
        elsif ($line =~ /Add UCD Aliases/) {
            if (exists $args{parameters}{usr_aliases}) {
                print OUT '<aliases xsi:type="ucd:ArrayOfUCDAliasNaturalKeyDO" soapenc:arrayType="ucd:UCDAliasNaturalKeyDO[]">';
                foreach (@{$args{parameters}{usr_aliases}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns11:UCDAliasNaturalKeyDO\" xmlns:ns11=\"ucd.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                    print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                    print OUT "</multiRef>";
                    print OUT "\n";
                }
                print OUT "</aliases>\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Add UCD Aliases in $args{xmlfile} \n");    
                next;
            } 
        }
        elsif ($line =~ /Add UCD Directory Number/) {
            unless (exists $args{parameters}{usr_dirNumbers}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_dirNumbers' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_dirNumbers}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns10:UCDDNNaturalKeyDO\" xmlns:ns10=\"ucd.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                print OUT "</multiRef>";
                print OUT "\n";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Add UCD Directory Number in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Add Redirection Class Of Service/) {
            unless (exists $args{parameters}{usr_redirectCos}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_redirectCos' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            if ($args{parameters}{usr_redirectCos} eq 'None') {
                print OUT "<name xsi:type=\"xsd:string\" xsi:nil=\"true\"/>";
            } else {
                print OUT "<name xsi:type=\"soapenc:string\">$args{parameters}{usr_redirectCos}</name>";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Add Redirection Class Of Service in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Add Secondary Appearance Users/) {
            unless (exists $args{parameters}{usr_secondarySLA}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_secondarySLA' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_secondarySLA}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:SlaSecondaryAppearanceNaturalKeyDO\" xmlns:ns3=\"sla.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                print OUT "</multiRef>";
                print OUT "\n";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Add Secondary Appearance Users in $args{xmlfile} \n");    
            next;
        }
        elsif ($line =~ /Input outgoingScreenedUsers For MCT/) {
            unless (exists $args{parameters}{usr_outgoingScreenedUsers}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_outgoingScreenedUsers' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_outgoingScreenedUsers}}) {
                print OUT "<name>$_</name>";
                print OUT "\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Input outgoingScreenedUsers For MCT: $_ in $args{xmlfile} \n");    
            }
            next;
        }
        elsif ($line =~ /Input MCT Files/) {
            unless (exists $args{parameters}{usr_MTCFiles}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_MTCFiles' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_MTCFiles}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:MctFileNaturalKeyDO\" xmlns:ns3=\"mct.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
                print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                print OUT " </multiRef>";
                print OUT "\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Input MCT Files: $_ in $args{xmlfile} \n");    
            }
            next;
        }
        elsif ($line =~ /Add Caller URI/) {
            unless (exists $args{parameters}{usr_mctCallers}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_mctCallers' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_mctCallers}}) {
                print OUT "<name>$_</name>";
                print OUT "\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Input usr_mctCallers For MCT: $_ in $args{xmlfile} \n");    
            }
            next;
        }
        elsif ($line =~ /Input Selective RingTones/) {
			unless (exists $args{parameters}{usr_selectiveRingTones}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_selectiveRingTones' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
			foreach (@{$args{parameters}{usr_selectiveRingTones}}) {
				print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:RingToneNaturalKeyDO\" xmlns:ns3=\"ringtone.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
				print OUT "<name xsi:type=\"xsd:string\">$_</name>";
				print OUT "</multiRef>";
				print OUT "\n";
				$logger->debug(__PACKAGE__ . ".$sub_name: Set selective RingTones: $_ in $args{xmlfile} \n");
			}
			next;
		}    
		elsif ($line =~ /Input Subcribers RingTone/) {
			unless (exists $args{parameters}{usr_subcribers}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_subcribers' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
			foreach (@{$args{parameters}{usr_subcribers}}) {
				print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns6:UserNaturalKeyDO\" xmlns:ns6=\"common.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
				print OUT "<name xsi:type=\"xsd:string\">$_</name>";
				print OUT "</multiRef>";
				print OUT "\n";
				$logger->debug(__PACKAGE__ . ".$sub_name: Set subcribers: $_ in $args{xmlfile} \n");
			}
			next;
		}
		elsif ($line =~ /Add Assistant Users/) {
            unless (exists $args{parameters}{usr_assistantUsers}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_assistantUsers' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            foreach (@{$args{parameters}{usr_assistantUsers}}) {
                print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns2:AssistantUserNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns2=\"asstsvc.ws.nortelnetworks.com\">";
                print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                print OUT "</multiRef>";
                print OUT "\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Input usr_assistantUsers For User: $_ in $args{xmlfile} \n");    
            }
            next;
        }
		elsif ($line =~ /Add Ordered Lists/) {
            unless (exists $args{parameters}{usr_firstList}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_firstList' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            # Input first list 
            print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns23:CallDestinationDO" xmlns:ns23="routes.data.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
            print OUT '<destinations xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]">';
                foreach (@{$args{parameters}{usr_firstList}{usr_Destinations}}) {
                    print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Input destination : $_ in $args{xmlfile} \n");    
                }
            print OUT '</destinations>';
            print OUT "<numberofRings xsi:type=\"xsd:int\">$args{parameters}{usr_firstList}{usr_numberofRings}</numberofRings>";
            if (exists $args{parameters}{usr_firstList}{usr_instantMessage}) {
                print OUT "<instantMessage xsi:type=\"soapenc:string\">$args{parameters}{usr_firstList}{usr_instantMessage}</instantMessage>";
            }
            print OUT '<ringBackTone xsi:type="crbt:CrbtFileNaturalKeyDO" xmlns:crbt="crbt.ws.nortelnetworks.com">';
            print OUT "<name xsi:type=\"soapenc:string\">$args{parameters}{usr_firstList}{usr_fileName}</name>";
            print OUT '</ringBackTone>';
            print OUT "</multiRef>\n";
            $logger->debug(__PACKAGE__ . ".$sub_name: Input fisrt list in $args{xmlfile} \n");    
            # Input second  list 
            if (exists $args{parameters}{usr_secondList}) {
                print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns23:CallDestinationDO" xmlns:ns23="routes.data.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                print OUT '<destinations xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]">';
                    foreach (@{$args{parameters}{usr_secondList}{usr_Destinations}}) {
                        print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                        $logger->debug(__PACKAGE__ . ".$sub_name: Input destination : $_ in $args{xmlfile} \n");    
                    }
                print OUT '</destinations>';
                print OUT "<numberofRings xsi:type=\"xsd:int\">$args{parameters}{usr_secondList}{usr_numberofRings}</numberofRings>";
                if (exists $args{parameters}{usr_secondList}{usr_instantMessage}) {
                    print OUT "<instantMessage xsi:type=\"soapenc:string\">$args{parameters}{usr_secondList}{usr_instantMessage}</instantMessage>";
                }
                print OUT '<ringBackTone xsi:type="crbt:CrbtFileNaturalKeyDO" xmlns:crbt="crbt.ws.nortelnetworks.com">';
                print OUT "<name xsi:type=\"soapenc:string\">$args{parameters}{usr_secondList}{usr_fileName}</name>";
                print OUT '</ringBackTone>';
                print OUT "</multiRef>\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Input second list in $args{xmlfile} \n");    
            }
            # Input third  list 
            if (exists $args{parameters}{usr_thirdList}) {
                print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns23:CallDestinationDO" xmlns:ns23="routes.data.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                print OUT '<destinations xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]">';
                    foreach (@{$args{parameters}{usr_thirdList}{usr_Destinations}}) {
                        print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                        $logger->debug(__PACKAGE__ . ".$sub_name: Input destination : $_ in $args{xmlfile} \n");    
                    }
                print OUT '</destinations>';
                print OUT "<numberofRings xsi:type=\"xsd:int\">$args{parameters}{usr_thirdList}{usr_numberofRings}</numberofRings>";
                if (exists $args{parameters}{usr_thirdList}{usr_instantMessage}) {
                    print OUT "<instantMessage xsi:type=\"soapenc:string\">$args{parameters}{usr_thirdList}{usr_instantMessage}</instantMessage>";
                }
                print OUT '<ringBackTone xsi:type="crbt:CrbtFileNaturalKeyDO" xmlns:crbt="crbt.ws.nortelnetworks.com">';
                print OUT "<name xsi:type=\"soapenc:string\">$args{parameters}{usr_thirdList}{usr_fileName}</name>";
                print OUT '</ringBackTone>';
                print OUT "</multiRef>\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Input third list in $args{xmlfile} \n");    
            }
            next;
        }
        elsif ($line =~ /Add Outcome Actions/) { # add term action
            unless (exists $args{parameters}{usr_outcomeActions} && exists $args{parameters}{usr_outcomeActions}{usr_firstList}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_outcomeActions' and 'usr_firstList' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            print OUT "\n";
            print OUT '<dests xsi:type="rout:ArrayOf_tns102_CallDestinationDO" soapenc:arrayType="rout1:CallDestinationDO[]">';
            # Input first list 
            print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns23:CallDestinationDO" xmlns:ns23="routes.data.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
            print OUT '<destinations xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]">';
                foreach (@{$args{parameters}{usr_outcomeActions}{usr_firstList}{usr_Destinations}}) {
                    print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                    $logger->debug(__PACKAGE__ . ".$sub_name: Input destination : $_ in $args{xmlfile} \n");    
                }
            print OUT '</destinations>';
            print OUT "<numberofRings xsi:type=\"xsd:int\">$args{parameters}{usr_outcomeActions}{usr_firstList}{usr_numberofRings}</numberofRings>";
            if (exists $args{parameters}{usr_outcomeActions}{usr_firstList}{usr_instantMessage}) {
                print OUT "<instantMessage xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_firstList}{usr_instantMessage}</instantMessage>";
            }
            if (exists $args{parameters}{usr_outcomeActions}{usr_firstList}{usr_fileName}) {
                print OUT '<ringBackTone xsi:type="crbt:CrbtFileNaturalKeyDO" xmlns:crbt="crbt.ws.nortelnetworks.com">';
                print OUT "<name xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_firstList}{usr_fileName}</name>";
                print OUT '</ringBackTone>';
            }
            
            print OUT "</multiRef>\n";
            $logger->debug(__PACKAGE__ . ".$sub_name: Input fisrt list in $args{xmlfile} \n");    
            # Input second  list 
            if (exists $args{parameters}{usr_outcomeActions}{usr_secondList}) {
                print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns23:CallDestinationDO" xmlns:ns23="routes.data.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                print OUT '<destinations xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]">';
                    foreach (@{$args{parameters}{usr_outcomeActions}{usr_secondList}{usr_Destinations}}) {
                        print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                        $logger->debug(__PACKAGE__ . ".$sub_name: Input destination : $_ in $args{xmlfile} \n");    
                    }
                print OUT '</destinations>';
                print OUT "<numberofRings xsi:type=\"xsd:int\">$args{parameters}{usr_outcomeActions}{usr_secondList}{usr_numberofRings}</numberofRings>";
                if (exists $args{parameters}{usr_outcomeActions}{usr_secondList}{usr_instantMessage}) {
                    print OUT "<instantMessage xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_secondList}{usr_instantMessage}</instantMessage>";
                }
                if (exists $args{parameters}{usr_outcomeActions}{usr_secondList}{usr_fileName}) {
                    print OUT '<ringBackTone xsi:type="crbt:CrbtFileNaturalKeyDO" xmlns:crbt="crbt.ws.nortelnetworks.com">';
                    print OUT "<name xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_secondList}{usr_fileName}</name>";
                    print OUT '</ringBackTone>';
                }
                
                print OUT "</multiRef>\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Input second list in $args{xmlfile} \n");    
            }
            # Input third  list 
            if (exists $args{parameters}{usr_outcomeActions}{usr_thirdList}) {
                print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns23:CallDestinationDO" xmlns:ns23="routes.data.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                print OUT '<destinations xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]">';
                    foreach (@{$args{parameters}{usr_outcomeActions}{usr_thirdList}{usr_Destinations}}) {
                        print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                        $logger->debug(__PACKAGE__ . ".$sub_name: Input destination : $_ in $args{xmlfile} \n");    
                    }
                print OUT '</destinations>';
                print OUT "<numberofRings xsi:type=\"xsd:int\">$args{parameters}{usr_outcomeActions}{usr_thirdList}{usr_numberofRings}</numberofRings>";
                if (exists $args{parameters}{usr_outcomeActions}{usr_thirdList}{usr_instantMessage}) {
                    print OUT "<instantMessage xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_thirdList}{usr_instantMessage}</instantMessage>";
                }
                if (exists $args{parameters}{usr_outcomeActions}{usr_thirdList}{usr_fileName}) {
                    print OUT '<ringBackTone xsi:type="crbt:CrbtFileNaturalKeyDO" xmlns:crbt="crbt.ws.nortelnetworks.com">';
                    print OUT "<name xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_thirdList}{usr_fileName}</name>";
                    print OUT '</ringBackTone>';
                }
                
                print OUT "</multiRef>\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Input third list in $args{xmlfile} \n");    
            }
            print OUT "</dests>\n";
            # Input busy dest 
            if (exists $args{parameters}{usr_outcomeActions}{usr_busyDest}) {
                print OUT '<busyDest xsi:type="rout1:CallDestinationDO">';
                print OUT '<destinations xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]">';
                    foreach (@{$args{parameters}{usr_outcomeActions}{usr_busyDest}{usr_Destinations}}) {
                        print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                        $logger->debug(__PACKAGE__ . ".$sub_name: Input destination : $_ in $args{xmlfile} \n");    
                    }
                print OUT '</destinations>';
                print OUT "<numberofRings xsi:type=\"xsd:int\">$args{parameters}{usr_outcomeActions}{usr_busyDest}{usr_numberofRings}</numberofRings>";
                if (exists $args{parameters}{usr_outcomeActions}{usr_busyDest}{usr_instantMessage}) {
                    print OUT "<instantMessage xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_busyDest}{usr_instantMessage}</instantMessage>";
                }
                if (exists $args{parameters}{usr_outcomeActions}{usr_busyDest}{usr_fileName}) {
                    print OUT '<ringBackTone xsi:type="crbt:CrbtFileNaturalKeyDO" xmlns:crbt="crbt.ws.nortelnetworks.com">';
                    print OUT "<name xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_busyDest}{usr_fileName}</name>";
                    print OUT '</ringBackTone>';
                }
               
                print OUT "</busyDest>\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Input busy dest in $args{xmlfile} \n");    
            }
            # Input noAnswerDest
            if (exists $args{parameters}{usr_outcomeActions}{usr_noAnswerDest}) {
                print OUT '<noAnswerDest xsi:type="rout1:CallDestinationDO">';
                print OUT '<destinations xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]">';
                    foreach (@{$args{parameters}{usr_outcomeActions}{usr_noAnswerDest}{usr_Destinations}}) {
                        print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                        $logger->debug(__PACKAGE__ . ".$sub_name: Input destination : $_ in $args{xmlfile} \n");    
                    }
                print OUT '</destinations>';
                print OUT "<numberofRings xsi:type=\"xsd:int\">$args{parameters}{usr_outcomeActions}{usr_noAnswerDest}{usr_numberofRings}</numberofRings>";
                if (exists $args{parameters}{usr_outcomeActions}{usr_noAnswerDest}{usr_instantMessage}) {
                    print OUT "<instantMessage xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_noAnswerDest}{usr_instantMessage}</instantMessage>";
                }
                if (exists $args{parameters}{usr_outcomeActions}{usr_noAnswerDest}{usr_fileName}) {
                    print OUT '<ringBackTone xsi:type="crbt:CrbtFileNaturalKeyDO" xmlns:crbt="crbt.ws.nortelnetworks.com">';
                    print OUT "<name xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_noAnswerDest}{usr_fileName}</name>";
                    print OUT '</ringBackTone>';
                }
                
                print OUT "</noAnswerDest>\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Input noAnswer Dest in $args{xmlfile} \n");    
            }
            # Input notLoggedInDest
            if (exists $args{parameters}{usr_outcomeActions}{usr_notLoggedInDest}) {
                print OUT '<notLoggedInDest xsi:type="rout1:CallDestinationDO">';
                print OUT '<destinations xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]">';
                    foreach (@{$args{parameters}{usr_outcomeActions}{usr_notLoggedInDest}{usr_Destinations}}) {
                        print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                        $logger->debug(__PACKAGE__ . ".$sub_name: Input destination : $_ in $args{xmlfile} \n");    
                    }
                print OUT '</destinations>';
                print OUT "<numberofRings xsi:type=\"xsd:int\">$args{parameters}{usr_outcomeActions}{usr_notLoggedInDest}{usr_numberofRings}</numberofRings>";
                if (exists $args{parameters}{usr_outcomeActions}{usr_notLoggedInDest}{usr_instantMessage}) {
                    print OUT "<instantMessage xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_notLoggedInDest}{usr_instantMessage}</instantMessage>";
                }
                if (exists $args{parameters}{usr_outcomeActions}{usr_notLoggedInDest}{usr_fileName}) {
                    print OUT '<ringBackTone xsi:type="crbt:CrbtFileNaturalKeyDO" xmlns:crbt="crbt.ws.nortelnetworks.com">';
                    print OUT "<name xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_notLoggedInDest}{usr_fileName}</name>";
                    print OUT '</ringBackTone>';
                }
                
                print OUT "</notLoggedInDest>\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Input usr_notLoggedIn Dest in $args{xmlfile} \n");    
            }
            # Input unreachableDest
            if (exists $args{parameters}{usr_outcomeActions}{usr_unreachableDest}) {
                print OUT '<unreachableDest xsi:type="rout1:CallDestinationDO">';
                print OUT '<destinations xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]">';
                    foreach (@{$args{parameters}{usr_outcomeActions}{usr_unreachableDest}{usr_Destinations}}) {
                        print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                        $logger->debug(__PACKAGE__ . ".$sub_name: Input destination : $_ in $args{xmlfile} \n");    
                    }
                print OUT '</destinations>';
                print OUT "<numberofRings xsi:type=\"xsd:int\">$args{parameters}{usr_outcomeActions}{usr_unreachableDest}{usr_numberofRings}</numberofRings>";
                if (exists $args{parameters}{usr_outcomeActions}{usr_unreachableDest}{usr_instantMessage}) {
                    print OUT "<instantMessage xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_unreachableDest}{usr_instantMessage}</instantMessage>";
                }
                if (exists $args{parameters}{usr_outcomeActions}{usr_unreachableDest}{usr_fileName}) {
                    print OUT '<ringBackTone xsi:type="crbt:CrbtFileNaturalKeyDO" xmlns:crbt="crbt.ws.nortelnetworks.com">';
                    print OUT "<name xsi:type=\"soapenc:string\">$args{parameters}{usr_outcomeActions}{usr_unreachableDest}{usr_fileName}</name>";
                    print OUT '</ringBackTone>';
                }
                
                print OUT "</unreachableDest>\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Input unreachable Dest in $args{xmlfile} \n");    
            }
            next;
        }
        elsif (($line =~ /Add Route Conditions/) && (exists $args{parameters}{usr_Conditions})) {
            print OUT "\n";
            print OUT "<condition xsi:type=\"rout:ConditionDO\">\n";
            if (exists $args{parameters}{usr_Conditions}{usr_anonymous}) { # anonymousCondition
                print OUT '<anonymousCondition xsi:type="rout1:AnonymousConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<values xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]"/>';
                print OUT "</anonymousCondition>\n";
            }
            if (exists $args{parameters}{usr_Conditions}{usr_globalAddressList}) { # gabCondition
                print OUT '<gabCondition xsi:type="rout1:GABConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<globalAddrBookEntry xsi:type="rout:ArrayOf_tns33_GlobalAddrBookEntryNaturalKeyDO" soapenc:arrayType="gab:GlobalAddrBookEntryNaturalKeyDO[]" xmlns:gab="gab.ws.nortelnetworks.com">';
                foreach (@{$args{parameters}{usr_Conditions}{usr_globalAddressList}}) {
                        print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns31:GlobalAddrBookEntryNaturalKeyDO" xmlns:ns31="gab.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                        print OUT '</multiRef>';
                    }
                print OUT '</globalAddrBookEntry>';
                print OUT "</gabCondition>\n";
            }
            if (exists $args{parameters}{usr_Conditions}{usr_telephoneNumber}) { # genericCondition
                print OUT '<genericCondition xsi:type="rout1:GenericConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<values xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]">';
                foreach (@{$args{parameters}{usr_Conditions}{usr_telephoneNumber}}) {
                        print OUT "<name xsi:type=\"soapenc:string\">$_</name>";
                    }
                print OUT '</values>';
                print OUT "</genericCondition>\n";
            }
            if (exists $args{parameters}{usr_Conditions}{usr_personalAddressBook}) { # pabCondition
                print OUT '<pabCondition xsi:type="rout1:PABConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<addrBookEntry xsi:type="rout:ArrayOf_tns64_AddrBookEntryNaturalKeyDO" soapenc:arrayType="add:AddrBookEntryNaturalKeyDO[]" xmlns:add="addrbook.data.ws.nortelnetworks.com">';
                foreach (@{$args{parameters}{usr_Conditions}{usr_personalAddressBook}}) {
                        print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns37:AddrBookEntryNaturalKeyDO" xmlns:ns37="addrbook.data.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                        print OUT '</multiRef>';
                    }
                print OUT '</addrBookEntry>';
                print OUT "</pabCondition>\n";
            }
            if (exists $args{parameters}{usr_Conditions}{usr_directoryGroups}) { # pabGroupCondition
                print OUT '<pabGroupCondition xsi:type="rout1:PABGroupConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<addrBookGroup xsi:type="rout:ArrayOf_tns64_AddrBookGroupNaturalKeyDO" soapenc:arrayType="add:AddrBookGroupNaturalKeyDO[]" xmlns:add="addrbook.data.ws.nortelnetworks.com">';
                foreach (@{$args{parameters}{usr_Conditions}{usr_directoryGroups}}) {
                        print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns45:AddrBookGroupNaturalKeyDO" xmlns:ns45="addrbook.data.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                        print OUT '</multiRef>';
                    }
                print OUT '</addrBookGroup>';
                print OUT "</pabGroupCondition>\n";
            }
            if (exists $args{parameters}{usr_Conditions}{usr_presenceState}) { # presenceCondition
                print OUT '<presenceCondition xsi:type="rout1:PresenceConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<presenceState xsi:type="rout:ArrayOf_tns205_PresenceStateNaturalKeyDO" soapenc:arrayType="pres:PresenceStateNaturalKeyDO[]" xmlns:pres="presence.ws.nortelnetworks.com">';
                foreach (@{$args{parameters}{usr_Conditions}{usr_presenceState}}) {
                        print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns44:PresenceStateNaturalKeyDO" xmlns:ns44="presence.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                        print OUT '</multiRef>';
                    }
                print OUT '</presenceState>';
                print OUT "</presenceCondition>\n";
            }
            if (exists $args{parameters}{usr_Conditions}{usr_timeBlockGroupName}) { # timeOfDayCondition
                print OUT '<timeOfDayCondition xsi:type="rout1:TimeOfDayConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<timeBlock xsi:type="rout:ArrayOf_tns151_TimeBlockGroupNaturalKeyDO" soapenc:arrayType="tim:TimeBlockGroupNaturalKeyDO[]" xmlns:tim="timeblock.ws.nortelnetworks.com">';
                print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns37:TimeBlockGroupNaturalKeyDO" xmlns:ns37="timeblock.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                print OUT "<name xsi:type=\"xsd:string\">$args{parameters}{usr_Conditions}{usr_timeBlockGroupName}</name>";
                print OUT '</multiRef>';  
                print OUT '</timeBlock>';
                print OUT "</timeOfDayCondition>\n";
            }
            print OUT "</condition>\n";
            
            next;
        }
        elsif (($line =~ /Add Route Exceptions/) && (exists $args{parameters}{usr_Exceptions}) ) {
            print OUT "\n";
            print OUT "<exception xsi:type=\"rout:ExceptionDO\">\n";
            if (exists $args{parameters}{usr_Exceptions}{usr_anonymous}) { # anonymousCondition
                print OUT '<anonymousCondition xsi:type="rout1:AnonymousConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<values xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]"/>';
                print OUT "</anonymousCondition>\n";
            }
            if (exists $args{parameters}{usr_Exceptions}{usr_globalAddressList}) { # gabCondition
                print OUT '<gabCondition xsi:type="rout1:GABConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<globalAddrBookEntry xsi:type="rout:ArrayOf_tns33_GlobalAddrBookEntryNaturalKeyDO" soapenc:arrayType="gab:GlobalAddrBookEntryNaturalKeyDO[]" xmlns:gab="gab.ws.nortelnetworks.com">';
                foreach (@{$args{parameters}{usr_Exceptions}{usr_globalAddressList}}) {
                        print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns31:GlobalAddrBookEntryNaturalKeyDO" xmlns:ns31="gab.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                        print OUT '</multiRef>';
                    }
                print OUT '</globalAddrBookEntry>';
                print OUT "</gabCondition>\n";
            }
            if (exists $args{parameters}{usr_Exceptions}{usr_telephoneNumber}) { # genericCondition
                print OUT '<genericCondition xsi:type="rout1:GenericConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<values xsi:type="rout:ArrayOf_soapenc_string" soapenc:arrayType="soapenc:string[]">';
                foreach (@{$args{parameters}{usr_Exceptions}{usr_telephoneNumber}}) {
                        print OUT "<name xsi:type=\"soapenc:string\">$_</name>";
                    }
                print OUT '</values>';
                print OUT "</genericCondition>\n";
            }
            if (exists $args{parameters}{usr_Exceptions}{usr_personalAddressBook}) { # pabCondition
                print OUT '<pabCondition xsi:type="rout1:PABConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<addrBookEntry xsi:type="rout:ArrayOf_tns64_AddrBookEntryNaturalKeyDO" soapenc:arrayType="add:AddrBookEntryNaturalKeyDO[]" xmlns:add="addrbook.data.ws.nortelnetworks.com">';
                foreach (@{$args{parameters}{usr_Exceptions}{usr_personalAddressBook}}) {
                        print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns37:AddrBookEntryNaturalKeyDO" xmlns:ns37="addrbook.data.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                        print OUT '</multiRef>';
                    }
                print OUT '</addrBookEntry>';
                print OUT "</pabCondition>\n";
            }
            if (exists $args{parameters}{usr_Exceptions}{usr_directoryGroups}) { # pabGroupCondition
                print OUT '<pabGroupCondition xsi:type="rout1:PABGroupConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<addrBookGroup xsi:type="rout:ArrayOf_tns64_AddrBookGroupNaturalKeyDO" soapenc:arrayType="add:AddrBookGroupNaturalKeyDO[]" xmlns:add="addrbook.data.ws.nortelnetworks.com">';
                foreach (@{$args{parameters}{usr_Exceptions}{usr_directoryGroups}}) {
                        print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns45:AddrBookGroupNaturalKeyDO" xmlns:ns45="addrbook.data.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                        print OUT '</multiRef>';
                    }
                print OUT '</addrBookGroup>';
                print OUT "</pabGroupCondition>\n";
            }
            if (exists $args{parameters}{usr_Exceptions}{usr_presenceState}) { # presenceCondition
                print OUT '<presenceCondition xsi:type="rout1:PresenceConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<presenceState xsi:type="rout:ArrayOf_tns205_PresenceStateNaturalKeyDO" soapenc:arrayType="pres:PresenceStateNaturalKeyDO[]" xmlns:pres="presence.ws.nortelnetworks.com">';
                foreach (@{$args{parameters}{usr_Exceptions}{usr_presenceState}}) {
                        print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns44:PresenceStateNaturalKeyDO" xmlns:ns44="presence.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                        print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                        print OUT '</multiRef>';
                    }
                print OUT '</presenceState>';
                print OUT "</presenceCondition>\n";
            }
            if (exists $args{parameters}{usr_Exceptions}{usr_timeBlockGroupName}) { # timeOfDayCondition
                print OUT '<timeOfDayCondition xsi:type="rout1:TimeOfDayConditionDO" xmlns:rout1="routes.data.ws.nortelnetworks.com">';
                print OUT '<timeBlock xsi:type="rout:ArrayOf_tns151_TimeBlockGroupNaturalKeyDO" soapenc:arrayType="tim:TimeBlockGroupNaturalKeyDO[]" xmlns:tim="timeblock.ws.nortelnetworks.com">';
                print OUT '<multiRef id="id" soapenc:root="0" soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xsi:type="ns37:TimeBlockGroupNaturalKeyDO" xmlns:ns37="timeblock.ws.nortelnetworks.com" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/">';
                print OUT "<name xsi:type=\"xsd:string\">$args{parameters}{usr_Conditions}{usr_timeBlockGroupName}</name>";
                print OUT '</multiRef>';  
                print OUT '</timeBlock>';
                print OUT "</timeOfDayCondition>\n";
            }
            print OUT "</exception>\n";
            
            next;
        }
        elsif ($line =~ /Input Locations MeetMe/) {
			unless (exists $args{parameters}{usr_locations}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_locations' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
			foreach (@{$args{parameters}{usr_locations}}) {
				print OUT "<multiRef id=\"id0\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns3:LocationNaturalKeyDO\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:ns3=\"core.data.ws.nortelnetworks.com\">";
				print OUT "<name xsi:type=\"xsd:string\">$_</name>";
				print OUT "</multiRef>";
				print OUT "\n";
				$logger->debug(__PACKAGE__ . ".$sub_name: Set location Meet Me: $_ in $args{xmlfile} \n");
			}
			next;
		}
		elsif ($line =~ /Input CallPickup Aliases/) {
			if (exists $args{parameters}{usr_aliases}) {
				print OUT "<aliases xsi:type=\"cal:ArrayOfCPUAliasNaturalKeyDO\" soapenc:arrayType=\"cal:CPUAliasNaturalKeyDO[]\">";
                foreach (@{$args{parameters}{usr_aliases}}) {
					print OUT "<multiRef id=\"id4\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns8:CPUAliasNaturalKeyDO\" xmlns:ns8=\"callpickup.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
				}
				print OUT "</aliases>";
				$logger->debug(__PACKAGE__ . ".$sub_name: Set Call Pickup Aliases: $_ in $args{xmlfile} \n");
				next;
            }
		}
		elsif ($line =~ /Input CallPickup DirNumbers/) {
			if (exists $args{parameters}{usr_dirNumbers}) {
				print OUT "<dirNumbers xsi:type=\"cal:ArrayOfCPUDNNaturalKeyDO\" soapenc:arrayType=\"cal:CPUDNNaturalKeyDO[]\">";
                foreach (@{$args{parameters}{usr_dirNumbers}}) {
					print OUT "<multiRef id=\"id2\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns6:CPUDNNaturalKeyDO\" xmlns:ns6=\"callpickup.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
				}
				print OUT "</dirNumbers>";
                $logger->debug(__PACKAGE__ . ".$sub_name: Set Call Pickup DirNumbers: $_ in $args{xmlfile} \n");
                next;
            }
		}
		elsif ($line =~ /Input CallPickup GroupMembers/) {
			if (exists $args{parameters}{usr_groupMembers}) {
                print OUT "<agents xsi:type=\"cal:ArrayOfCPUAgentNaturalKeyDO\" soapenc:arrayType=\"cal:CPUAgentNaturalKeyDO[]\">";
                foreach (@{$args{parameters}{usr_groupMembers}}) {
					print OUT "<multiRef id=\"id2\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns4:CPUAgentNaturalKeyDO\" xmlns:ns4=\"callpickup.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
				}
				print OUT "</agents>";
                $logger->debug(__PACKAGE__ . ".$sub_name: Set Call Pickup GroupMembers: $_ in $args{xmlfile} \n");
				next;
            }
		}
		elsif ($line =~ /Input Hunting Aliases/) {
			if (exists $args{parameters}{usr_aliases}) {
                print OUT "<aliases soapenc:arrayType=\"ns5:HuntAliasNaturalKeyDO[]\" xsi:type=\"soapenc:Array\">";
				foreach (@{$args{parameters}{usr_aliases}}) {
					print OUT "<multiRef id=\"id9\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns11:HuntAliasNaturalKeyDO\" xmlns:ns11=\"hunting.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
				}
				print OUT "</aliases>";
				$logger->debug(__PACKAGE__ . ".$sub_name: Set Call Pickup Aliases: $_ in $args{xmlfile} \n");
				next;
            }
		}
		elsif ($line =~ /Input Hunting DirNumbers/) {
			if (exists $args{parameters}{usr_dirNumbers}) {
                print OUT "<dirNumbers soapenc:arrayType=\"ns5:HuntDNNaturalKeyDO[]\" xsi:type=\"soapenc:Array\">";
				foreach (@{$args{parameters}{usr_dirNumbers}}) {
					print OUT "<multiRef id=\"id11\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns12:HuntDNNaturalKeyDO\" xmlns:ns12=\"hunting.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
					print OUT "</multiRef>";
					print OUT "\n";
				}
				print OUT "</dirNumbers>";
				$logger->debug(__PACKAGE__ . ".$sub_name: Set Call Hunting DirNumbers: $_ in $args{xmlfile} \n");
				next;
			}
		}
        elsif ($line =~ /Input destinations CallAction UCD/) {
			if (exists $args{parameters}{usr_destinations}) {
				foreach (@{$args{parameters}{usr_destinations}}) {
					print OUT "<destinations xsi:type=\"soapenc:string\">$_</destinations>";
                    print OUT "\n";
				}
				$logger->debug(__PACKAGE__ . ".$sub_name: Set UCD Destinations: $_ in $args{xmlfile} \n");
				next;
            }
		}
        elsif ($line =~ /Input anonymousCondition UCD/) {
			if (exists $args{parameters}{usr_anonymous}) {
				print OUT "<values xsi:type=\"ucd:ArrayOf_soapenc_string\" soapenc:arrayType=\"soapenc:string[]\">";
				print OUT "<values xsi:type=\"soapenc:string\">anonymous</values>";
				print OUT "</values>";
                print OUT "\n";
            } else {
				print OUT "<values xsi:type=\"ucd:ArrayOf_soapenc_string\" soapenc:arrayType=\"soapenc:string[]\"/>";
                print OUT "\n";
            }
        $logger->debug(__PACKAGE__ . ".$sub_name: Set anonymousCondition \n");
        }
        elsif ($line =~ /Input genericCondition UCD/) {
			if (exists $args{parameters}{usr_generics}) {
				print OUT "<values xsi:type=\"ucd:ArrayOf_soapenc_string\" soapenc:arrayType=\"soapenc:string[]\">";
				foreach (@{$args{parameters}{usr_generics}}) {
					print OUT "<values xsi:type=\"soapenc:string\">$_</values>";
                    print OUT "\n";
				}
				print OUT "</values>";
                print OUT "\n";
            } else {
				print OUT "<values xsi:type=\"ucd:ArrayOf_soapenc_string\" soapenc:arrayType=\"soapenc:string[]\"/>";
                print OUT "\n";
            }
        $logger->debug(__PACKAGE__ . ".$sub_name: Set genericCondition \n");
        }
        elsif ($line =~ /Input timeCondition UCD/) {
			if (exists $args{parameters}{usr_ucdTimeBlocks}) {
				print OUT "<ucdTimeBlocks xsi:type=\"ucd:ArrayOfUCDTimeBlockGroupNKDO\" soapenc:arrayType=\"ucd:UCDTimeBlockGroupNKDO[]\">";
				foreach (@{$args{parameters}{usr_ucdTimeBlocks}}) {
                    print OUT "<multiRef id=\"id\" soapenc:root=\"0\" soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xsi:type=\"ns9:UCDTimeBlockGroupNKDO\" xmlns:ns9=\"ucd.ws.nortelnetworks.com\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">";
					print OUT "<name xsi:type=\"xsd:string\">$_</name>";
                    print OUT "</multiRef>";
                    print OUT "\n";
				}
				print OUT "</ucdTimeBlocks>";
                print OUT "\n";
            } else {
				print OUT "<ucdTimeBlocks xsi:type=\"ucd:ArrayOfUCDTimeBlockGroupNKDO\" soapenc:arrayType=\"ucd:UCDTimeBlockGroupNKDO[]\"/>";
                print OUT "\n";
            }
        $logger->debug(__PACKAGE__ . ".$sub_name: Set timeCondition \n");
        }
        elsif ($line =~ /Input externalNATAddress/) {
            unless (exists $args{parameters}{usr_externalNATAddress}) {
                $flag = 0;
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter 'usr_externalNATAddress' not present in $args{xmlfile} ");
                $logger->debug(__PACKAGE__ . ".$sub_name:  Leaving Sub [$flag]");
                last;
            }
            if ($args{parameters}{usr_externalNATAddress} eq 'None') {
                print OUT "<externalNATAddress xsi:type=\"ns3:AddressNaturalKey\" xsi:nil=\"true\"/>";
            } else {
                print OUT "<externalNATAddress xsi:type=\"net:AddressNaturalKey\">";
                print OUT "<logicalName xsi:type=\"soapenc:string\" xmlns:soapenc=\"http://schemas.xmlsoap.org/soap/encoding/\">$args{usr_externalNATAddress}</logicalName>";
                print OUT "</externalNATAddress>";
                print OUT "\n";
            }
            $logger->debug(__PACKAGE__ . ".$sub_name: Add externalNATAddress in $args{xmlfile} \n");    
            next;
        }
		print OUT $line;        
    }
    
    close IN;
    close OUT;
    return 0 unless ($flag);
   $logger->debug(__PACKAGE__ . ".$sub_name: URL: $url "); 
   my @message = $self->execCmd("cat $out_file");    
   
   
   my $userAgent = LWP::UserAgent->new(keep_alive => 1 );
    $userAgent->ssl_opts(verify_hostname => 0);
    $userAgent->ssl_opts( SSL_verify_mode => 0 );
    
   my $message = join("",@message);
   my  $request = HTTP::Request->new(POST => $url);
    if ($args{username}) {
        $request->header('Authorization',  "Basic " . MIME::Base64::encode("$args{username}:$args{password}", '') );
    }
    $request->header(SOAPAction => "");
    $request->content_type("application/xml");
    $request->content($message);
    
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Run SOAPUI request  ");
    my $response = $userAgent->request($request);
    
    $logger->info(__PACKAGE__ . ".$sub_name: --> Run file $args{xmlfile} completely. ");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Leaving Sub  ");
    return $response;
}

#Get SESM log


=head2 B<startSESMlog()>

    This function takes a hash containing the list_dn, telnet_username, telnet_password

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        list_dn
        telnet_username
        telnet_password

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:
        my %args = (-list_dn => ['4409920','4409921','4409922'], -telnet_username => 'anh1', -telnet_password => 'anh1', -port  => '22000');
        $obj->startSESMlog(%args);
=back

=cut

sub startSESMlog{
    my ($self, %args) = @_;
    my $sub_name = "startSESMlog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Start SESM logs");
    my @cmdResults;
    my $cmdResult;
    my $timeout = 30;
    my $flag = 1;
    foreach('-telnet_username', '-telnet_password') {               
    #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
    return 0;
    }
    if ($args{-port}) {
        unless ($self->doTelnet(-ip => 'localhost', -port => $args{-port}, -user => $args{-telnet_username}, -password => $args{-telnet_password})) {
        #Telnet to localhost with telnet_port # 21000
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to telnet to localhost with port $args{-port}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    } else {
        unless ($self->doTelnet(-ip => 'localhost', -port => '21000', -user => $args{-telnet_username}, -password => $args{-telnet_password})) {
        #Telnet to localhost with telnet_port 21000
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to telnet to localhost with port 21000");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
      }
    my $prev_prompt = $self->{conn}->prompt('/\>/'); #Changing the prompt to \> to match this so as to run further commands
    $logger->debug( __PACKAGE__ . ".$sub_name: Changing the prompt to />/");
    $self->{conn}->waitfor(-match => '/\>/');
    if (grep/Cannot/, $self->execCmd("cd trace")) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Fail to cd trace ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if (grep/Cannot/, $self->execCmd("deact")) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Fail to Deactive ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return 0;
    }
    if (grep/Cannot/, $self->execCmd("act")) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Fail to Active ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if (grep/Cannot/, $self->execCmd("rep ts on")) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Fail to ts on ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $flag = 1;
    if ($args{-active_wildcard}) {
        if (grep/Cannot/, $self->execCmd("select *")) {
            $logger->error(__PACKAGE__ . ".$sub_name:   Fail to select wildcard");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
   } else {
        if ($args{-list_dn}) {
            foreach(@{$args{-list_dn}}) {               
                if (grep/Cannot/, $self->execCmd("select user ".$_)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to select user $_");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
        if ($args{-list_host}) {
            foreach(@{$args{-list_host}}) {               
                if (grep/Cannot/, $self->execCmd("select host ".$_)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to select host $_");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
        if ($args{-list_endptid}) {
            foreach(@{$args{-list_endptid}}) {              
                if (grep/Cannot/, $self->execCmd("select endptid ".$_)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to select endptid $_");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
        if ($args{-list_trunkcontext}) {
            foreach(@{$args{-list_trunkcontext}}) {              
                if (grep/Cannot/, $self->execCmd("select tgrp trunk-context ".$_)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to select tgrp trunk-context $_");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
        if ($args{-list_route}) {
            foreach(@{$args{-list_route}}) {               
                if (grep/Cannot/, $self->execCmd("select route ".$_)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to select route $_");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
        if ($args{-list_ltid}) {
            foreach(@{$args{-list_ltid}}) {              
                if (grep/Cannot/, $self->execCmd("select ltid ".$_)) {
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to select ltid $_");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if (grep/Cannot/, $self->execCmd("set SIP 1")) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Fail to SIP logs ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if (grep/Cannot/, $self->execCmd("set GCP 7")) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Fail to GCP logs ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if (grep/Cannot/, $self->execCmd("set mp 1")) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Fail to MP logs ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if ($args{-active_fulllog}) {
        if (grep/Cannot/, $self->execCmd("set TRANS 2")) {
            $logger->error(__PACKAGE__ . ".$sub_name:   Fail to Transactor logs ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        if (grep/Cannot/, $self->execCmd("set svc 1 all")) {
            $logger->error(__PACKAGE__ . ".$sub_name:   Fail to All services logs ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        if (grep/Cannot/, $self->execCmd("set topology 16")) {
            $logger->error(__PACKAGE__ . ".$sub_name:   Fail to set topology ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    if ($args{-transfer_log2SM}) {
        if (grep/Cannot/, $self->execCmd("rep out log")) {
            $logger->error(__PACKAGE__ . ".$sub_name:   Fail to rep out log ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    } else {
        if (grep/Cannot/, $self->execCmd("rep out sess")) {
            $logger->error(__PACKAGE__ . ".$sub_name:   Fail to rep out sess ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    if (grep/Cannot/, $self->execCmd("debuglevel set DEBG verbose")) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Fail to set debug ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if (grep/Cannot/, $self->execCmd("start")) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Fail to start logs ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}


=head2 B<stopSESMlog()>
   
    This function gets the logs from the given objects. startSESMlog SHOULD be called before using this function
=over 6

=item Arguments:

 Mandatory:
        Object Reference

=item Returns:

        Returns location of log file

=item Example:
        unless (($SESMlogpath) = $Obj->stopSESMlog()) {
        $logger->debug(__PACKAGE__ . " : Fail to stop get SESM logs");
        return 0;
        }
=back

=cut

sub stopSESMlog {
    my ($self, %args) = @_;
    my $sub_name = "stopSESMlog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Stop SESM logs");
    unless ($self->{conn}->print("stop")) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Fail to stop get logs ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->{conn}->waitfor(-match => '/Debug tracing has been stopped for this session/')) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get Debug tracing has been stopped for this session prompt");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if (grep/Cannot/, $self->execCmd("deact")) {
        $logger->error(__PACKAGE__ . ".$sub_name:   Fail to Deactive ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return $self->{sessionLog2};
}

=head2 B<verifyContents()>

    This function is used to match and verify the pattern present in the log file. 

=over 6

=item Arguments:

        Object Reference
        -FilePath - The path file log need to verify
        -pattern - The pattern to be matched in the log file

=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:
        
        my %input = (-FilePath => '/home/hntanh/ats_user/logs/SOAPTEMPLATE/C3-UNKNOWN-20180808-160105-sessionInput.log', -patterns => ['BYE sip\:4409937(.*)(\s+)From\:(.*)sip\:4409920(.*)(\s+)To\:(.*)sip\:4409937']);
            
        $obj->verifyContents(%input);

=back

=cut

sub verifyContents {
    
    my ($self, %input) = @_;
    my $sub = "verifyContents";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    unless ($self) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    unless (%input) {
        $logger->error(__PACKAGE__ . ".$sub: Input Hash is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    #Checking for the log file
    my @checklink;
    if (@checklink = $self->execCmd("ls $input{-FilePath}")) {
        my $check = join("",@checklink);
        if ($check =~ /No such file or directory/) {
            $logger->error( __PACKAGE__ . ".$sub: file $input{-FilePath} didn't exist " );
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
            return 0;
        }
    }
    #Reading the DBG File
    my $logfile = "";
    my $result;
    unless ( open(FILE, "<$input{-FilePath}")) {
        $logger->error( __PACKAGE__ . ".$sub: open $input{-FilePath} failed " );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    while(<FILE>){
      chomp $_;
      $logfile=$logfile.$_;
    }
    foreach my $i (0 .. $#{$input{-patterns}}) {
        if ($logfile=~ /$input{-patterns}[$i]/) {
            $logger->debug(__PACKAGE__ . ".$sub: Found patterns :  \" $input{-patterns}[$i] \"in the captured data sucessfully");
            $result = 1;
        }else {
            $logger->error(__PACKAGE__ . ".$sub: Cannot found patterns : \" $input{-patterns}[$i]\" in the captured data");
            $result = 0;
            last;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$result]");
    return $result;
}
=head2 B<doTelnet()>

    This function takes a hash containing the IP, port, user and password and opens a telnet connection.

=over 6

=item Arguments:

 Mandatory:
        Object Reference
        ip
        user
        password
 Optional:
        port

=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:

        my %args = (-ip => '10.250.14.10', -user => 'root', -password => 'root');
        $obj->doTelnet(%args);

=back

=cut

sub doTelnet {
    my ($self, %args) = @_;
    my $sub_name = "doTelnet";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-ip', '-user', '-password') {                                                        #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Trying to telnet to $args{-ip} with user $args{-user} and password $args{-password}");
    unless ($self->{conn}->print("telnet $args{-ip} $args{-port}")) {                              #telnet to the host
        $logger->error(__PACKAGE__ . ".$sub_name:   Could not telnet to $args{-ip}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->{conn}->waitfor(-match => '/Username\:\s*/')) {                                    #waiting for Username and Password prompts and entering the inputs
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get Username prompt");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->{conn}->print($args{-user})) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not enter username");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->{conn}->waitfor(-match => '/Password\:\s*/')) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get Password prompt");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->{conn}->print($args{-password})) {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not enter password");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Telnet successful"); 
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 B<verifyMessage()>

    This subroutine is used to validate sip message content from SESM log file. 
    This inturn calls validator() to verify the pattern.

=over 6

=item Arguments:

   Mandatory:

        -SESMlogpath - SESM log file (full path)
        -pattern - search data hash referance having below pattern
                    ( 'msg type1' => { 'occurance1' => ['pattern1','pattern2'.....]],
                                      'occurance2' => ['pattern1','pattern2'.....]], },
                    'msg type2' => { 'occurance1' => ['pattern1','pattern2'.....]],
                                      'occurance2' => ['pattern1','pattern2'.....]], },
                    )
   Optional:
        -returnpattern => 1, When we pass this value as 1, It will return a hash contain order of match message. See the below example for more detail.
        
=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:

        my %input = (-pattern => { 'INVITE' => { 1 => ['sip:4409937@tma15.automation.com','CSeq: 92579 INVITE'],
                                                 2 => ['Contact: "4409925"','CSeq: 92579 INVITE']},
                                    'REGISTER' => { 1 => ['sip:8218825@tma6.automation.com']}
                                 },
                     -SESMlogpath => '/home/hntanh/ats_user/logs/ASTEMPLATE/AS-UNKNOWN-TC6_SESMLog-20180920-135536-sessionInput.log'
                     -returnpattern => 1
                    );

        ($Result,$returnhash) = $soapui->verifyMessage(%input);

=back

=cut

sub verifyMessage {
    my ($self, %input) = @_;
    my $sub = "verifyMessage";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    unless ($self) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    unless (%input) {
        $logger->error(__PACKAGE__ . ".$sub: Input Hash is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my ($file) = $input{-SESMlogpath};
    unless ($file) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the log file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }else{
    $logger->info(__PACKAGE__ . ".$sub: Got the log file to verify the Message: $file");
    }
    my @logFile;
    #Reading the DBG File
    unless ( open(IN, "<$file")) {
        $logger->error( __PACKAGE__ . ".$sub: open $file failed " );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: Open $file \n");
    while (<IN>){
        chomp $_;
        push (@logFile, $_);
    }
    close IN;
    my $i;
    for ($i = 1; $i < scalar @logFile; $i++) {
        chomp $logFile[$i];        
        if ($logFile[$i-1] eq '' && $logFile[$i] eq '' ) {
            $logFile[$i] = '----------'; 
        }
    }
    my ($header, $pdu_start, %count, %content, %returnhash);
    my %pattern = %{$input{-pattern}};
    my $temp_pattern = join ('|', keys%pattern); # i need to this make regex match circus
    my $start_boundary = 'SIP/2.0'; #defined boundary or i will take default
    my $end_boundary = '----------';
    my @path = split(/\.log/, $file);
    my $out_file = $path[0]."_new.log";
    unless (open OUT, ">$out_file") {
        $logger->error( __PACKAGE__ . ".$sub: open $out_file failed " );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: Create new $out_file \n");
    foreach my $line (@logFile) {
        print OUT $line;
        print OUT "\n";
        chomp $line;
        if (!$header && $line =~ /$start_boundary/i && $line =~ /($temp_pattern)/) {
            $header = $1;
            $count{$header}++;
        } 

        $header ='' if ( $line =~ /$end_boundary/);

        next unless $header;

        push (@{$content{$header}{$count{$header}}}, $line);
    }
    close OUT;
    my $flag;
    my @result;
    foreach my $msg ( keys %pattern) {
        foreach my $occurrence ( keys %{$pattern{$msg}}) {
            unless ($content{$msg}{$occurrence}) {
                $logger->error(__PACKAGE__ . ".$sub: there is no $occurrence occurrence of $msg");
                push (@result, 0);
            } else {
                $flag = 0;
                foreach $i (1 .. scalar (keys %{$content{$msg}})) {
                    # Calling a validatior function which goes recurrsive based on tree passed ;-)
                    my $resultvalidator = validator($pattern{$msg}->{$occurrence}, $content{$msg}{$i});
                    if ( $resultvalidator ) {
                        $logger->info(__PACKAGE__ . ".$sub: found all patterns of $msg $occurrence occurrence present in message $i th captured data");
                        $flag = 1;
                        push (@{$returnhash{$msg}->{$occurrence}}, $i);
                    }
                }
                push (@result, $flag);
            }
        }
    }
    if (grep /0/, @result) {
        $logger->error(__PACKAGE__ . ".$sub: Not all patterns found in captured data");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } else {
        $logger->info(__PACKAGE__ . ".$sub: you found all patterns in the captured data");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
        if( defined $input{-returnpattern} and $input{-returnpattern}){
            return (1,\%returnhash);
        }else{
            return 1;
        }
    }
}



=head2 validator()

=over

=item DESCRIPTION:

    Internal use only. Used by verifyCapturedMsg()
    Used to match the patter present in array referance and also goes recursive untill we get array referance.

=item ARGUMENTS:

    Mandatory:
    - pattern : array reference of patterns to match
    - data : either array reference or hash reference
    - start_msg : if empty search will start from the first line

    Optional:
    - returnpattern : 1 or 0. 0 by default

=item PACKAGE:

    SonusQA::AS

=item GLOBAL VARIABLES USED:

    None

=item FUNCTIONS USED:

    None

=item OUTPUT:

    0 - fail ( if any one of the search pattern is not found)
    1 - Success ( if all of the search patterns found)
    (1, $return_value) - return hash reference of the values if returnpattern is 1 and if all of the search patterns found.

=item EXAMPLE:

    my ($resultvalidator, $returnvalidator) = validator($input{$msg}->{$occurrence}, $content{$msg}{$occurrence},"",1);
    unless ( $resultvalidator ) {
        $logger->error(__PACKAGE__ . ".$sub: not all the pattern of $occurrence occurrence of $msg present in captured data");
    }

=back

=cut

sub validator {
    my ($pattern, $data, $start_msg, $returnpattern) = @_;
    my $sub = "validator()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    $returnpattern ||= 0;
    my %returnvalues;

    #TOOLS-18561
    if (ref ($data) eq 'HASH') {
        my ($resultvalidator, $returnvalidator);
        foreach my $occurrence (sort { $a <=> $b } keys %{$data}) {
            ($resultvalidator, $returnvalidator) = validator($pattern, $data->{$occurrence}, '', $returnpattern);
            if ( $resultvalidator ) {
                $logger->info(__PACKAGE__ . ".$sub: found all the patterns in $occurrence th occurrence");
                last;
            }
        }
        unless ($resultvalidator) {
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }

        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
        if ( $returnpattern) {
            return (1, $returnvalidator);
        }
        else {
            return 1;
        }
    }
    #TOOLS-18561

    unless (ref ($pattern)eq 'ARRAY') {
        foreach my $key (keys %{$pattern}) {
            my ($resultvalidator, $returnvalidator) = validator($pattern->{$key}, $data, $key, $returnpattern); 
            unless ( $resultvalidator ) {
                $main::failure_msg .= "TOOLS:TSHARK- Pattern NotFound; ";
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
            $returnvalues{$key} = $returnvalidator;
            $logger->info(__PACKAGE__ . ".$sub: found all the pattern of $key");
        }
    } else {
        my $msg_found = 0;
        my $start_index = 0;
        if (defined $start_msg and $start_msg) {
            my @presence = grep { $data->[$_] =~ /$start_msg/} 0..$#$data;
            unless (scalar @presence) {
                $main::failure_msg .= "TOOLS:TSHARK- MsgLine $start_msg NotFound; ";
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
            $start_index = $presence[0];
        }

        my %matched = ();
        my @patterns = @{$pattern}; #dereferencing and storing in to a variable so that the original values remain unchanges
        my $required_mtach = shift (@patterns); # i just need to follow the order of match hence taking first value of array
        foreach my $index ( $start_index..$#$data) {
            $matched{$required_mtach} = 0 unless ( defined $matched{$required_mtach}); # intaily assuming pattern is not found
            if ($data->[$index] =~ /$required_mtach/) {
                if ( $returnpattern ) {
                    if ( $data->[$index] =~ /(^\s+)(.*):\s (.*)$/ ) {
                        my ($k,$v);
                        $k = $2;
                        $v = $3;
                        chomp $k;
                        $k =~ s/^[^a-zA-Z]//g;
                        chomp $v;
                        $v =~ s/\]//g;
                        $returnvalues{$k} = $v;
                    }
                }
                $logger->info(__PACKAGE__ . ".$sub: pattern \'$required_mtach\' found");
                $matched{$required_mtach} = 1; # setting falg found
                last unless (@patterns); # i am not fool to loop around if nothing is left to check
                $required_mtach = shift (@patterns);
            }
        }

        foreach ( keys %matched) {
            unless ($matched{$_}) {
               $main::failure_msg .= "TOOLS:TSHARK- Pattern NotFound; ";
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
        }
    }
    
    $logger->info(__PACKAGE__ . ".$sub: found all the pattern for msg -> $start_msg") if (defined $start_msg);
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    if ( defined $returnpattern and $returnpattern) {
        return (1,\%returnvalues);
    }else{
        return 1;
    }
}



=head2 B<prepareSIPPFile()>

    This function read SIPP file from "QATEST/AS/SIPP_FILE/"$location", replace value from input and save on a file in "QATEST/AS/"$project" .

=over 6

=item Arguments:

        Object Reference
        -XMLfile - The file name and pattern to be replaced with new value.
        -location - The folder contains all files.
        -project - The folder is used to save the new file.

=item Returns:

        Returns folder contains new files

=item Example:

        my %XMLfile = ('uac_PAC2C.xml' => { 'calling_party' => '8410031',
                                                    'called_party' => '8410032',
                                                    'domain' => 'tma6.automation.com'
                                                },
                                'uac_C2C2.xml' => { 'called_party' => '8410031',
                                                }
                    );

        $out_file = SonusQA::AS::prepareSIPPFile(-XMLfile => \%XMLfile, -project => 'ADQ_639' ,-location => 'C2C' );

=back

=cut

sub prepareSIPPFile {
    my (%args) = @_;
    my $sub_name = "prepareSIPPFile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless ( defined($args{-XMLfile}) && defined($args{-project}) && defined($args{-location}) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Argument missing. Required aruguments are -XMLfile, -project, -location.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my $in_file;
    my $out_file;
    my %XMLfile = %{$args{-XMLfile}};
    foreach my $xml ( keys %XMLfile){
    my $line;
    $in_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/AS/SIPP_FILE/".$args{-location}."/".$xml;
    $out_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/AS/".$args{-project}."/".$xml;
    open (IN, "<$in_file") or $logger->debug(__PACKAGE__ . ".$sub_name: Can't open $in_file: $!\n");
    $logger->debug(__PACKAGE__ . ".$sub_name: Open $xml file \n");
    open (OUT, ">$out_file") or $logger->debug(__PACKAGE__ . ".$sub_name: Can't open $out_file: $!\n");
    $logger->debug(__PACKAGE__ . ".$sub_name: Create new $xml file \n");
    while ( $line = <IN> ) {
        foreach my $pattern ( keys %{$XMLfile{$xml}}){
            my $value = $XMLfile{$xml}{$pattern};
            if ($line =~ m[assign_to\=\"$pattern\"]) {
                $line =~ s/value\=\".*\"/value\=\"$value\"/;
                $logger->debug(__PACKAGE__ . ".$sub_name: Replace $pattern: $value");
            }
        }
        print OUT $line;
    }
    close IN;
    close OUT;
    $logger->debug(__PACKAGE__ . ".$sub_name: Close $xml file");
    }
    $out_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/AS/".$args{-project};
    $logger->debug(__PACKAGE__ . ".$sub_name: Folder contains new files : $out_file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub 1");
    return $out_file;
}

=head2 C< execCmd() >

    This function enables user to execute any command on the server.

=over

=item Arguments:

    1. Command to be executed.
    2. Timeout in seconds (optional).

=item Return Value:

    Output of the command executed.

=item Example:

    my @results = $obj->execCmd("cat test.txt");
    This would execute the command "cat test.txt" on the session and return the output of the command.

=back

=cut

sub execCmd {
    my ($self,$cmd, $timeout)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd  ...... ");
    my(@cmdResults,$timestamp);
    $logger->debug(__PACKAGE__ . ".execCmd --> Entered Sub");
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
        $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECTION ERROR OCCURRED");
        $logger->warn(__PACKAGE__ . ".execCmd  errmsg : ". $self->{conn}->errmsg);
        $logger->info(__PACKAGE__ . ".execCmd  <-- Leaving sub[0]");
    return 0;
    }
    chomp(@cmdResults);
    $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
    $logger->info(__PACKAGE__ . ".execCmd  <-- Leaving sub");
    return @cmdResults;
}

=head2 C< checkSESMActive >

=over

=item DESCRIPTION:

 This subroutine is used to check SESM that actived

=item ARGUMENTS:

=item OUTPUT:

Name of SESM Active

=item EXAMPLES:

my $SESM_active = $sesm -> checkSESMActive();

=back

=cut

sub checkSESMActive{
    my ($self) = @_;
    my $sub_name = "checkSESMActive";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my @cmdResults;
    my $SESM_active;
    @cmdResults = $self->execCmd("neinit -p");
    $logger->debug(__PACKAGE__ . ".$sub_name: check SESM active by command: neinit -p");
    foreach my $line (@cmdResults){
        if ($line =~ m/SESM(.*)(\s+)/) {
            $SESM_active = "SESM".$1;
            $SESM_active =~ s/^\s+|\s+$//g;
            $logger->debug( __PACKAGE__ . ".$sub_name: SESM active is $SESM_active");
            last;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$SESM_active]");
    return $SESM_active;
}


=head2 B<createIPDRfile()>

    This subroutine is used to create a new IPDR file from original IPDR file and SESM log.
    This return new IPDR file.

=over 6

=item Arguments:

   Mandatory:

        -SESMlogpath - SESM log file (full path)
        -ipdrLogPath - original IPDR file (full path)
        
=item Returns:

        Returns : $newipdrLog (new IPDR file)

=item Example:

        my %input = (-SESMlogpath => '/home/nthuong2/ats_user/logs/DEMOTEMPLATE/SESM.log'
                     -ipdrLogPath => '/home/nthuong2/ats_user/logs/DEMOTEMPLATE/IPDR.log'
                    );

        $newipdrLog = $obj->createIPDRfile(%input);

=back

=cut

sub createIPDRfile {
    my ($self, %input) = @_;
    my $sub = "createIPDRfile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    my $flag = 1;
    foreach ('-SESMlogpath', '-ipdrLogPath') {
        unless ($input{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag) {
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    my ($file) = $input{-SESMlogpath};
    #Reading the SESM File
    unless ( open(SESM, "<$file")) {
        $logger->error( __PACKAGE__ . ".$sub: open $file failed " );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    # get Call-ID in SESM log
    $logger->debug(__PACKAGE__ . ".$sub: Open $file \n");
    my @callID;
    my $flag1 = 0;
    while (<SESM>){
        if ($flag1 == 1) {
            $flag1 = 0;
            next;
        }
        if(/REGISTER/) {
            $flag1 = 1;
            next;
        }
        if (/Call-ID: (.+)\@/) {
            push (@callID, $1);
        }
    }
    close SESM;
    @callID = uniq(@callID);
    $logger->debug( __PACKAGE__ . ".$sub: Call-ID in SESM log:  ".Dumper(\@callID) );
   
   # get recordID in IPDR log
    my $ipdrLog = $input{-ipdrLogPath};
    $logger->debug( __PACKAGE__ . ".$sub: IPDR log path : $ipdrLog" );
    unless ( open(IPDR1, "<$ipdrLog")) {
        $logger->error( __PACKAGE__ . ".$sub: open $ipdrLog failed " );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub: Open $ipdrLog \n");
    my (@tmpArr, @recordID);
    my $flag2 = 0;
    while (<IPDR1>){
        if (/uniqueCallId>(.+)\@/) {
            if (grep/^$1$/, @callID) {
                $flag2 = 1;
                next;
            }
        }
        if (($flag2 == 1) && (/recordID>(.+)</)) {
            push (@recordID, $1);
            $flag2 = 0;
        }
        
    }
    close IPDR1;
    @recordID = uniq(@recordID);
    $logger->debug( __PACKAGE__ . ".$sub: ".Dumper(\@recordID) );
    
    my @path = split(/\.active/, $ipdrLog);
    my $newipdrLog = $path[0]."_newIPDR.active";
    
    unless ( open(OUT, ">$newipdrLog")) {
        $logger->error( __PACKAGE__ . ".$sub: open $newipdrLog failed " );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    unless ( open(IPDR2, "<$ipdrLog")) {
        $logger->error( __PACKAGE__ . ".$sub: open $ipdrLog failed " );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
      
    # get recordID in IPDR log and write to new IPDR file
    $logger->debug(__PACKAGE__ . ".$sub: Open $ipdrLog \n");

    while (<IPDR2>){
        if (/<IPDR\s|<nortel:|<VoIP:|<\/IPDR/) {
            push (@tmpArr, $_);
            if (/<\/IPDR/) {
                foreach my $elm (@tmpArr) {
                    if ($elm =~ /recordID>(.+)</) {
                        if (grep/^$1$/, @recordID) {
                            print OUT join ("\n", @tmpArr);
                            print OUT "\n";
                            last;
                        }
                    }
                }
                @tmpArr = ();
            }
            next;
        }
        print OUT $_;
        print OUT "\n";
        
    }
    close IPDR2;  
    
    $logger->debug(__PACKAGE__ . ".$sub: Completed creating new IPDR file. ");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$newipdrLog]");
    return $newipdrLog;  
}
=head2 B<modifyCSVfile()>

    This subroutine is used to modify csv and then save override this file.
    This return new csv file.

=over 6

=item Arguments:

   Mandatory:
        -csvFile - original csv file (full path)
        -replacement: a hash contains index (key )and new value needed to replace. Key must to be a number.
=item Returns:

        Returns : 1: passed
                  0: failed  

=item Example:

        my %input = (-csvFile => '/home/nthuong2/ats_repos/lib/perl/QATEST/AS/TEMPLATE/Demo/t6ims1_sslTC22A.csv',
                     -replacement => { 2 => '2222',
                                        5 => '55555'
                                        }
                    );

        $obj->modifyCSVfile(%input);

=back

=cut

sub modifyCSVfile {
    my ($self, %input) = @_;
    my $sub = "modifyCSVfile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");

    my $flag = 1;
    foreach ('-csvFile', '-replacement') {
        unless ($input{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    my ($file) = $input{-csvFile};
    #Reading the original csv File
    unless ( open(CSV, "<$file")) {
        $logger->error( __PACKAGE__ . ".$sub: Open original csv file '$file' failed " );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }   
    my $firstLine;
    my @tmpArr = ();
    while (<CSV>){
        if (/SEQUENTIAL/) {
            $firstLine = $_;
            next;
        }
        @tmpArr = split(/;/, $_);
    }
    close CSV;
    # Replace value
    for (keys %{$input{-replacement}}) {
        $logger->debug(__PACKAGE__ . ".$sub: Replacing value '$tmpArr[$_ - 1]' at index '$_' with new value '$input{-replacement}{$_}' ");
        $tmpArr[$_ - 1] = $input{-replacement}{$_};
    }
    unless ( open(OUT, ">$file")) {
        $logger->error( __PACKAGE__ . ".$sub: Re-open csv file '$file' failed " );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    } 
    
    # Write to new csv file
    print OUT $firstLine;
    print OUT join (";", @tmpArr);
    close OUT;
    
    $logger->info(__PACKAGE__ . ".$sub: Completed modify csv file. ");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;  
}
=head2 C< CompareOMvalues >

=over

=item DESCRIPTION:

 This subroutine is used to get OM value, after that compare them with user-provided values.

=item ARGUMENTS:

=item OUTPUT:

        Returns 0 - If failed
        Returns 1 - If success

=item EXAMPLES:

        my %input = (-OMgroup => 'SIPPBXCallMgmtInstance',
                     -OMrow => 'pbxa1',
                     -OMtest => ['inComingCallAttempts'],
                     -OMvalue => ['0'],
                    );

        $obj->CompareOMvalues(%input);

=back

=cut

sub CompareOMvalues{
    my ($self, %input) = @_;
    my $sub = "CompareOMvalues";
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $flag = 1;
    foreach ('-OMgroup', '-OMrow', '-OMtest', '-OMvalue') {
        unless ($input{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if($flag == 0) {
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
    }
    my @cmdResults;
    my @valueReturns;
    my $value;
    my $i;
    @cmdResults = $self->execCmd("grep -a '$input{-OMgroup},$input{-OMrow}' \$(ls -rt | tail -n -1)");
    $logger->debug(__PACKAGE__ . ".$sub: Get OM record on $input{-OMrow} by command: grep -a '$input{-OMgroup},$input{-OMrow}' \$(ls -rt | tail -n -1)");
    for ($i = 0; $i <= $#{$input{-OMtest}}; $i ++){
      foreach my $line (@cmdResults){
            if ($line =~ m/$input{-OMtest}[$i]\,(\d+)/) {
                $value = $1;
                $logger->debug( __PACKAGE__ . ".$sub: Get value of OM that need to verify : $input{-OMtest}[$i] == $value ");
                if ($value == $input{-OMvalue}[$i]) {
                    $flag = 0;
                    last;
                }    
            }    
      }  
    }
    if($flag == 0) {
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub: Completed Compare OM values ");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;  
}
=head2 B<startCallTraklog()>

    This function is used to start CallTrak log.

=over 6
=item Arguments:

 Optional:
 
 -list_trk_clli: list of TRUNK CLLI
 -list_dpt_trunk_clli: list of DPT TRUNK CLLI
 -list_dn: list of DN
 -list_len: list of LEN
 
=item Returns:

        Returns l - If succeeds
        Reutrns 0 - If Failed

=item Example:
        my %args = (-list_trk_clli => ['PBX_ATS1','PBX_ATS2','PBX_ATS3'], 
                    -list_dpt_trunk_clli => ['603','717','711'], 
                    -list_dn => ['4412901','4412902','4412903'], 
                    -list_len  => ['4412901','4412902','4412903'],
                    );
        $obj->startCallTraklog(%args);
=back

=cut

sub startCallTraklog{
    my ($self, %args) = @_;
    my $sub_name = "startCallTraklog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Start CallTrak logs");
    my @cmdResults;
    my $cmdResult;
    my $timeout = 30;
    my $flag = 1;
    my $prev_prompt = $self->{conn}->prompt('/\>/'); #Changing the prompt to \> to match this so as to run further commands
    $logger->debug( __PACKAGE__ . ".$sub_name: Changing the prompt to />/");
    for ("CALLTRAK;", "PGMTRACE DISPLAYOPTS SET RETADDR EDITION TIMESORT;", "MSGTRACE BUFSIZE SHORT 230 LONG 65;", "MSGTRACE DISPLAYOPTS SET TIMESORT;", "PGMTRACE EXCLUDE MODULE TCUSER;","PGMTRACE EXCLUDE MODULE MSGTRACE;", "PGMTRACE ON;", "MSGTRACE ON;") {
        if (grep/Cannot/, $self->execCmd($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name:   Fail to execute command: $_ ");
            $flag = 0;
            last;
        }    
    }
    if($flag == 0) {
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
      return 0;
    }
    
    foreach (qw(list_trunk_clli list_dpt_trunk_clli list_dn list_len)) {
        next unless(exists $args{"-$_"});
        my $cmd;
        if ($_ =~ /list_trunk_clli/) {
            $cmd = "select TRK ";
        } 
        elsif ($_ =~ /list_dpt_trunk_clli/) {
            $cmd = "select DPT CLLI ";
        }
        elsif ($_ =~ /list_dn/) {
            $cmd = "select DN ";
        } else {
            $cmd = "select LEN ";
        }
        foreach(@{$args{"-$_"}}) {              #Running commands one by one
            if (grep/Cannot/, $self->execCmd($cmd.$_)) {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to $cmd$_");
                $flag = 0;
                last;
            }
        }
    }
    if($flag == 0) {
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
      return 0;
    }
    for ("start", "y") {
        if (grep/Cannot/, $self->execCmd($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name:   Fail to execute command: $_ ");
            $flag = 0;
            last;
        }    
    }
    if($flag == 0) {
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
      return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}
=head2 B<stopCallTraklog()>
   
    This function gets the logs from the given objects. stopCallTraklog SHOULD be called before using this function
=over 6

=item Arguments:

Optional:
 -display_merge => 'yes' when you want to display merge
 
=item Returns:

        Returns location - If succeeds
        Returns 0 - If Failed

=item Example:
        my %args = (-display_merge => 'yes',
                    );
        unless (($Calltraklogpath) = $Obj->stopCallTraklog()) {
        $logger->debug(__PACKAGE__ . " : Fail to stop get CallTrack logs");
        return 0;
        }
=back

=cut

sub stopCallTraklog {
    my ($self, %args) = @_;
    my $sub_name = "stopCallTraklog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    if ($args{-display_merge}) {
        if (grep/Cannot/, $self->{conn}->cmd("display msgtrace;display merge")) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute command: display msgtrace;display merge ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    } else {
      if (grep/Cannot/, $self->{conn}->cmd('display msgtrace')) {
          $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute command: display msgtrace ");
          $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
          return 0;
      }
     }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return $self->{sessionLog2};
}
=head2 B<VerifyIPDRBilling>

    This function is used to grep and verify the pattern present in the IPDR log file. 

=over 6

=item Arguments:

        -file_path  - The path file log need to verify
        -IPDR_chain - List chains that you want to verify 
        -IPDR_type  - Type that you want to verify 
        -IPDR_field  - List fields that you want to verify
=item Returns:

        Returns 0 - If failed
        Returns 1 - If success

=item Example:
        
        my %args = (   -file_path  => '/home/vdkhoi/ats_user/logs/C20PBXS/E00_03.active', 
                        -IPDR_chain => ['ConnectEgress','ConnectEgress']
                        -IPDR_type => 'Nortel-VoIP',
                        -IPDR_field => ['ansInd', 'VoIP:startTime', 'VoIP:destinationId', 'nortel:oUA'],
                        
                        );
            
        $obj->VerifyIPDRBilling(%args);

=back

=cut

sub VerifyIPDRBilling {
    my ($self, %args) = @_;
    my $sub = "VerifyIPDRBilling";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $flag = 1;
    foreach('-file_path ', '-IPDR_chain', '-IPDR_type', '-IPDR_field') {               
    #Checking for the parameters in the input hash
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    #Checking for the log file
    if (grep /No such file or directory/, $self->execCmd("ls $args{-file_path }")) {
        $logger->error( __PACKAGE__ . ".$sub: file $args{-file_path} didn't exist " );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
    }
    #Grep the IPDR File
    my @results;
    $self->{conn}->prompt('/AUTOMATION\>/');
    foreach my $IPDR_chain (@{$args{-IPDR_chain}}) {
        foreach my $IPDR_type(@{$args{-IPDR_type}}) {
            foreach(@{$args{-IPDR_field}}) {               #Running commands one by one
                @results = $self->execCmd("grep -A 200 -B 30 \'$IPDR_chain\' \$\(ls -1rt $args{-file_path} \| tail -n -1\) \| grep -A 60 \'nortel\:$IPDR_type\' | grep -m 1 "."\'".$_."\'");
                unless (grep $_, @results) {
                   $logger->error(__PACKAGE__ . ".$sub: Failed to  grep command with IPDR_field $_");
                   $flag = 0;
                   last;           
                }   
            }
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}
sub closeConn {
    my $self = shift;
    my $sub_name = "closeConn";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    $logger->debug(__PACKAGE__ .".$sub_name: -->Entered Sub");
    unless (defined $self->{conn}) {
        $logger->warn(__PACKAGE__ . ".$sub_name: Called with undefined {conn} - OBJ_PORT: $self->{OBJ_PORT} COMM_TYPE:$self->{COMM_TYPE}");
        $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
    $self->copyLogToATS ();
    $logger->debug(__PACKAGE__ . ".$sub_name: Closing Socket");
    $self->{conn}->close;
    undef $self->{conn}; #this is a proof that i closed the session
    $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}


1;