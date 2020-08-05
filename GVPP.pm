package SonusQA::GVPP;

=head1 NAME

 SonusQA::GVPP - Perl module for GVPP

=head1 AUTHOR

 nthuong2 - nthuong2@tma.com.vn

=head1 IMPORTANT

 B<This module is a work in progress, it should work as described>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   $ats_obj_ref = SonusQA::GVPP->new(-obj_host => "$alias_hashref->{MGMTNIF}->{1}->{IP}",
                                      -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                      -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                      -obj_commtype => "SSH",
                                      %refined_args,
                                      );

=head1 REQUIRES

 Perl5.8.7, Log::Log4perl, SonusQA::Base, Module::Locate

=head1 DESCRIPTION
 GVPP (GENView Provisioning and Portals) is a modular telecommunications solution designed to enhance a service provider’s Centrex offering. 
 This module implements some functions that support on GVPP.

=head1 METHODS

=cut

use strict;
use warnings;
use Data::Dumper;

use Log::Log4perl qw(get_logger :easy);
use Module::Locate qw /locate/;

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
    $self->{PROMPT} = '/.*[\$%\}\|\>]$/'; 
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
    
    $self->{PROMPT} = '/.*[\$%#\}\|\>\]].*$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT};
    $self->{conn}->prompt($self->{DEFAULTPROMPT});
    
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[1]");
    return 1;
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

sub execCmd{
   my ($self,$cmd, $timeout)=@_;
   my $sub_name = "execCmd";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name  ...... ");
   my @cmdResults;
   $logger->debug(__PACKAGE__ . ".$sub_name --> Entered Sub");
   unless (defined $timeout) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".$sub_name: Timeout not specified. Using $timeout seconds ");
   }
   else {
      $logger->debug(__PACKAGE__ . ".$sub_name: Timeout specified as $timeout seconds ");
   }

   $logger->info(__PACKAGE__ . ".$sub_name ISSUING CMD: $cmd");
   unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
      $logger->error(__PACKAGE__ . ".$sub_name:  COMMAND EXECTION ERROR OCCURRED");
	  $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
      $logger->debug (__PACKAGE__ . ".$sub_name:  errmsg : ". $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub[0]");
      return 0;
   }
   chomp(@cmdResults);
   $logger->debug(__PACKAGE__ . ".$sub_name ...... : ".Dumper(\@cmdResults));
   $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub ");
   return @cmdResults;
}

=head2 B<SOAPUI()>

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

    Optional:
        timeout: if not set, timeout = 60s
=item Returns:

        Returns 1 - If succeeds
        Reutrns 0 - If Failed

=item Example:
        my %args = (
        ip => $provHost,
        port => $prov_port,
        username => $provUserName,
        password => $provPasswd,
        xmlfile => 'addServiceForUser.xml',
        parameters => {
                        usr_profileName => 'auto_test_callgrabber',
                        usr_fromRegisteredClients => 'true',
                        usr_fromTrustedNodes => 'true',
                    }
        );
        
        $obj->SOAPUI(%args);

=back

=cut

sub SOAPUI {
    my ($self, %args) = @_;
    my $sub_name = "SOAPUI";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $args{timeout} = $args{timeout} || 60;
    
    my $flag = 1;
    foreach ('ip', 'port', 'username', 'password', 'xmlfile') { 
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless ($flag);
     
    
    my @path = split(/.xml/, $args{xmlfile});
    my $in_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/GVPP/SOAP_UI_FILE/".$args{xmlfile};
    my $out_file = "/home/$ENV{ USER }/ats_repos/lib/perl/QATEST/GVPP/SOAP_UI_FILE/".$path[0]."_new.xml";
    
    unless ( open(IN, "<$in_file")) {
        $logger->error( __PACKAGE__ . ".$sub_name: Open $in_file failed " );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
        return 0;
    }
 
    $logger->debug(__PACKAGE__ . ".$sub_name: Create new xml file '$out_file' \n");
    unless (open OUT, ">$out_file") {
        $logger->error( __PACKAGE__ . ".$sub_name: Open $out_file failed " );
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
        return 0;
    }
    
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
        elsif ($line =~ /Handle keys tags/) {
                print OUT "<stat:item> \r\n";
                print OUT "<c3c:features>\r\n";
                for my $featureName (keys %{$args{parameters}{usr_keyItems}}) {
                    $logger->debug(__PACKAGE__ . ".$sub_name: Feature Name : $featureName \n");
                    print OUT "<stat:item>\r\n";
                    print OUT "<c3c:featureAction>$args{parameters}{usr_keyItems}{$featureName}{featureAction}</c3c:featureAction>\r\n";
                    print OUT "<c3c:featureName>$featureName</c3c:featureName>\r\n";
                    
                    if (exists $args{parameters}{usr_keyItems}{$featureName}{featurePrompts}) {
                        print OUT "<c3c:featurePrompts>\r\n";
                            for my $name (keys %{$args{parameters}{usr_keyItems}{$featureName}{featurePrompts}}) {
                                print "Name and value: $name : $args{parameters}{usr_keyItems}{$featureName}{featurePrompts}{$name} \n";
                                print OUT "<stat:item>\r\n";
                                print OUT "<name>$name</name>\r\n";
                                print OUT "<value>$args{parameters}{usr_keyItems}{$featureName}{featurePrompts}{$name}</value>\r\n";
                                print OUT "</stat:item>\r\n";
                            }
                        print OUT "</c3c:featurePrompts>\r\n";
                    }
                    
                    print OUT "</stat:item>\r\n";
                }
                print OUT "</c3c:features>\r\n";
                print OUT "<c3c:keyNumber>$args{parameters}{usr_keyNumber}</c3c:keyNumber>\r\n";
                print OUT "</stat:item> \r\n";
                $logger->debug(__PACKAGE__ . ".$sub_name: Handle 'keys' tags \n");
                if (exists $args{parameters}{usr_subscriberSID}) { 
                    print OUT "<c3c:subscriberSID>$args{parameters}{usr_subscriberSID}</c3c:subscriberSID>\r\n";
                }
                next;
        }
        elsif ($line =~ /Input SystemDataType/) {
			if (exists $args{parameters}{usr_name}) {
				for (my $i =0; $i < scalar @{$args{parameters}{usr_name}}; $i++) {
					print OUT "<net:item>\r\n";
                    print OUT "<c3c:name>$args{parameters}{usr_name}[$i]</c3c:name>\r\n";
					print OUT "<c3c:value>$args{parameters}{usr_value}[$i]</c3c:value>\r\n";
                    print OUT "</net:item>\r\n";
				}
			}
		}
        elsif ($line =~ /Input Service Profile/) {
			if (exists $args{parameters}{usr_name}) {
				for (my $i =0; $i < scalar @{$args{parameters}{usr_name}}; $i++) {
                    print OUT "<c3c:name>$args{parameters}{usr_name}[$i]</c3c:name>\r\n";
					print OUT "<c3c:value>$args{parameters}{usr_value}[$i]</c3c:value>\r\n";
				}
			}
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
    
    $request->header('Authorization',  "Basic " . MIME::Base64::encode("$args{username}:$args{password}", '') );
    $request->header(SOAPAction => "");
    $request->content_type("application/xml");
    $request->content($message);
    
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Run SOAPUI request  ");
    my $response = $userAgent->request($request);
    
    $logger->info(__PACKAGE__ . ".$sub_name: --> Run file $args{xmlfile} completely. ");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Leaving Sub  ");
    return $response;
}

1;












