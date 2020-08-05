package SonusQA::SBCEDGE;

=head1 NAME

SonusQA::SBCEDGE - Perl module for SBCEDGE REST interaction

=head1 AUTHOR

Vijayakumar Musigeri - vmusigeri@rbbn.com

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure
   my $sbcClient = SonusQA::SBCEDGE->new(-obj_user => $uname , 
                                          -obj_password => $passwd , 
                                          -obj_baseurl => 'https://10.xx.xx.xx/');

   NOTE: port 2024 can be used during dev. for access to the Linux shell

=head1 REQUIRES

Perl5.8.6, Log::Log4perl

=head1 DESCRIPTION

This module provides an interface for Sonus SBCEDGE REST interaction.

=head1 METHODS

=cut


use strict;
use warnings;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper ; 
use Net::SSL;
use REST::Client;
use MIME::Base64;
use Data::Dumper;
use URI::Encode;

sub new { 
	my ($class , %args) = @_ ;  
	my %tms_alias = () ; 
	my $sub = "new" ; 
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ; 
	$logger->info(__PACKAGE__ . ".$sub --> Entered Sub ") ;   

	my $self = {-obj_baseurl => $args{-obj_baseurl},
		-obj_user => $args{-obj_user},
		-obj_password => $args{-obj_password}
	};

	bless $self, $class ; 

	$logger->debug(__PACKAGE__ . ".$sub --> Dumper of object :".Dumper($self) ) ;
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
	return $self;
} 

=head1 loginSBC()

        The function is used login into SBC using rest API's

=over

=item ARGUMENTS:
        -obj_baseurl - URL to send REST request

        Optional Args:
        -bodyParam - body parameters
        NONE
        e.g:
        unless ($self->loginSBC()) {
                $logger->error("__PACKAGE__ . ".$sub: login failed");
                return 0;
        }

=item PACKAGES USED:
       REST::Client

=item GLOBAL VARIABLES USED:
       None

=item EXTERNAL FUNCTIONS USED:
       None

=item RETURNS:
       1 - Success
       0 - Failure

=back

=cut


sub loginSBC{
	my ($self) = @_ ; 
	my $sub = "loginSBC" ; 
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub"); 

	my $headers = {Accept => "application/x-www-form-urlencoded", 'Content-Type' => "application/x-www-form-urlencoded"};
	my $hostUri = $self->{-obj_baseurl}."rest/login";
        my $bodyParam = "Username=$self->{-obj_user}" . "&Password=$self->{-obj_password}";
 
	my $restClient = REST::Client->new();
	$restClient->getUseragent()->ssl_opts(verify_hostname => 0) if ($restClient->getUseragent()->can('ssl_opts'));
	$restClient->getUseragent()->ssl_opts(SSL_verify_mode => 0) if ($restClient->getUseragent()->can('ssl_opts'));

	$restClient->POST($hostUri, $bodyParam,  $headers);

	my $rc = $restClient->responseCode();
	my $content = $restClient->responseContent();
	my $cookie = $restClient->responseHeader('set-cookie');
	my @temp = split(';',$cookie);
	my $cookie_id = $cookie;

	$logger->debug(__PACKAGE__ . ".$sub: ResponseCode =". Dumper(\$rc));
	$logger->debug(__PACKAGE__ . ".$sub: ResponseContent =". Dumper(\$content));
	$logger->debug(__PACKAGE__ . ".$sub: ResponseHeaders =". Dumper(\$cookie_id));

	if ($rc eq "200") {


		if ($content =~m/http_code>200/){
			$logger->info(__PACKAGE__ . ".$sub: SBC1K/2K REST login Successful !!");
		} else {
			$logger->error(__PACKAGE__ . ".$sub: SBC1K/2K REST login is not Successful !!");
			return 0;
		}

	} else {
		$logger->error(__PACKAGE__ . ".$sub: SBC1K/2K REST login is not Successful !!");
		return 0;
	}
	$self->{cookie_id} =  $cookie_id;
	$self->{restObj} = \$restClient;
	return 1;


}

=head1 execRest()

        The function is used login into SBC using rest API's

=over

=item ARGUMENTS:
        -method - Type of REST request
        -url - URL to send REST request
        -contenttype - Content type of REST request

        Optional Args:
        -bodyParam - body parameters
        NONE
        e.g:
        unless ($sbcClient->execRest(-method => "PUT",-url => "rest/sipservertable/2" , -bodyParam => "Description=xyz");) {
                $logger->error("__PACKAGE__ . ".$sub: execRest failed");
                return 0;
        }

=item PACKAGES USED:
       REST::Client

=item GLOBAL VARIABLES USED:
       None

=item EXTERNAL FUNCTIONS USED:
       None

=item RETURNS:
      1 - Success
      0 - Failure

=back

=cut


sub execRest {

        my ($self, %args)=@_;
	my $sub = "execRest()";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

        unless($args{-url}){
             $logger->error(__PACKAGE__ . ".$sub: Did you forget to send REST API -url ?");
             $logger->info(__PACKAGE__ . "$sub: <-- Leaving Sub[0]");
             return 0;
        }
        unless($args{-contenttype}){
             $logger->error(__PACKAGE__ . ".$sub: Did you forget to send -contenttype ?");
             $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
             return 0;
        }
        unless($args{-method}){
             $logger->error(__PACKAGE__ . ".$sub: Did you forget to send REST API -method ?");
             $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
             return 0;
        }


	my $headers = {Accept => "application/".$args{-contenttype}, 'Content-Type' => "application/$args{-contenttype}"};
	my $restClient = ${$self->{restObj}};
	$restClient->addHeader('cookie',$self->{cookie_id});
        $restClient->getUseragent()->ssl_opts(verify_hostname => 0) if ($restClient->getUseragent()->can('ssl_opts'));
        $restClient->getUseragent()->ssl_opts(SSL_verify_mode => 0) if ($restClient->getUseragent()->can('ssl_opts'));

	if($args{-method} eq "GET"){
		$restClient->GET($self->{-obj_baseurl}."/$args{-url}", $headers);
	}elsif($args{-method} eq "PUT"){
		unless($args{-bodyParam}){
			$logger->error(__PACKAGE__ . ".sub: Invalid -bodyParam ");
			$logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
			return 0;
		}
		$restClient->PUT($self->{-obj_baseurl}."/$args{-url}", $args{-bodyParam},  $headers);
	}elsif($args{-method} eq "POST"){
		unless($args{-bodyParam}){
			$logger->error(__PACKAGE__ . ".$sub: Invalid -bodyParam ");
			$logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
			return 0;
		}
		$restClient->POST($self->{-obj_baseurl}."$args{-url}", $args{-bodyParam},  $headers);
	}elsif($args{-method} eq "DELETE"){
		$restClient->DELETE($self->{-obj_baseurl}."/$args{-url}",  $headers);
	}

    my $response_code = $restClient->responseCode();
    my $content = $restClient->responseContent();

	$logger->debug(__PACKAGE__ . "$sub: Executed Rest client $args{-method} URL : ".$self->{-obj_baseurl}."/$args{-url}");
	$logger->debug(__PACKAGE__ . "$sub: Rest responce code $response_code");
    $logger->debug(__PACKAGE__ . ".$sub: Rest responce content $content");

    if($response_code != 200){
        $logger->error(__PACKAGE__ . ".$sub: Rest api call is failed. responseCode: $response_code");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");
        return 0;
    }
    elsif(exists $args{-validate_http_code} and $args{-validate_http_code} !=0 and $content !~ /\<http_code\>200\<\/http_code\>/){
        $logger->error(__PACKAGE__ . ".$sub: Rest api call is failed. http_code in content is not 200");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub");
        return 0;
    }
    else{
        $logger->info(__PACKAGE__ . ".$sub: Rest api call is successful");
    } 
 
        if(defined $args{-reqRestContent} and $args{-reqRestContent} == 1){      
               $logger->info(__PACKAGE__ . ".$sub: -reqRestContent Flag is Set. Hence Response content will be returned..");
               if ($args{-method} eq "DELETE") {
                      return(1,0);
               } else {
                      return(1,$restClient->responseContent());
               }
        }
 return 1;
}

=head1 enableSSH()

        The function is used to enable SSH using rest API's

=over

=item ARGUMENTS:

       None

=item PACKAGES USED:

       None

=item GLOBAL VARIABLES USED:

       None

=item EXTERNAL FUNCTIONS USED:

       None

=item RETURNS:

      $administartor_password  - Success, password to login as root through SSH
      0 - Failure

=back

=cut


sub enableSSH {
    my ($self )=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".enableSSH");
    my $sub_name = 'enableSSH';
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $bodyParam = "Username=$self->{-obj_user}" . "&Password=$self->{-obj_password}";
    my ($response_return  ,$response_content) = $self->execRest(-method => "POST",
                                                                -url => "rest/licensekey?action=download" , 
                                                                -contenttype => "x-www-form-urlencoded" , 
                                                                -bodyParam => $bodyParam,
                                                                -validate_http_code => 0, 
                                                                -reqRestContent => 1 ) ;
    unless ($response_return ) {
        $logger->error(__PACKAGE__ . ".$sub_name: execRest failed");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Leaving Sub");
        return 0;
    }
    $response_content =~ /hostId\>(.+)\<\/hostId/ ;
    my $finger_print = $1 ;
    unless( $finger_print ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to fetch the fingerprint '$finger_print' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Leaving Sub");
        return 0;
    }
#    system ("touch Password.txt");
    my $password =  `~/ats_repos/lib/perl/SonusQA/SBCEDGE/GetUXAdminPwd $finger_print` ;
    $password =~ /Administrator\s+password\s+\=\s+(.+)\s+/ ;
    my $administartor_password = $1 ;

    unless ( $administartor_password ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to fetch the Encrypted Password: $administartor_password");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Leaving Sub");
        return 0;
    }

    my $uri     = URI::Encode->new( { encode_reserved => 1 } );
    my $encoded_password = $uri->encode($administartor_password);
    
    ($response_return  ,$response_content) = $self->execRest(-contenttype => "x-www-form-urlencoded", 
                                                             -method => "POST",-url => "rest/debugresource" ,
                                                             -reqRestContent => 1, 
                                                             -bodyParam => "Username=$self->{-obj_user}" . "&Password=$self->{-obj_password}" . "&System=12" . "&Action=2" .  "&buffer=ssh_full" . "&EncryptedPassword=$encoded_password");
    unless($response_return ) {
        $logger->error(__PACKAGE__ . ".$sub_name: execRest failed");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Leaving Sub");
        return 0;
    }

    unless ($response_content =~ /SSH started for 2 hours/ ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to enable the SSH");
        $logger->debug(__PACKAGE__ . ".$sub_name: --> Leaving Sub");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: --> Leaving Sub");
    return $administartor_password ;
}

=head1 sshRootLogin()

       The function is used to login into SBC as root through SSH using admin password and change the password as 'sonus'.

=over

=item ARGUMENTS:

       Mandatory :

       None

       Optional :

       -current_psswrd - admin password to login as root( if it is not passed , enableSSH will be done to get this password)  
       -new_psswrd - password to which it has to be changed (if not passed, 'sonus' is considered as new password)  

=item PACKAGES USED:

       SonusQA::TOOLS

=item GLOBAL VARIABLES USED:

       None

=item EXTERNAL FUNCTIONS USED:

       SonusQA::TOOLS->new

=item RETURNS:

       1 - Success
       0 - Failure

=item EXAMPLE:

       $obj->sshRootLogin( );

=back

=cut

sub sshRootLogin {
    my ($self, %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".ssh_root_login");
    my $sub_name = 'ssh_root_login';
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub") ;

    my $new_psswrd = $args{-new_psswrd} || 'sonus'  ;

    $self->{-obj_baseurl} =~  /.+\/(\d+\.\d+\.\d+\.\d+).+/ ;
    my $host_ip = $1 ;

    unless(($self->{root_obj} = SonusQA::TOOLS->new(-obj_host => "$host_ip",
                          -obj_user => 'root',
                          -obj_password => $args{-current_psswrd} || $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD},
                          -obj_commtype => "SSH",
                          -type => 'SBCEDGE',
                          -return_on_fail => 1
                          ))){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my ($prematch, $match) = ('','');
    $self->{root_obj}->{conn}->print("passwd");
    unless ( ($prematch, $match) = $self->{root_obj}->{conn}->waitfor(-match => '/Enter new UNIX password/') ) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get expected prompt");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{root_obj}->{conn}->print("$new_psswrd");
    unless ( ($prematch, $match) = $self->{root_obj}->{conn}->waitfor(-match => '/Retype new UNIX password/') ) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get expected prompt");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $self->{root_obj}->{conn}->cmd("$new_psswrd");

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head1 logoutSBC()

        The function is used logout into SBC using rest API's

=over

=item ARGUMENTS:
        NONE
        e.g:
        unless ($obj->logoutSBC()) {
                $logger->error("__PACKAGE__ . ".$sub: logout failed");
                return 0;
        }

=item PACKAGES USED:
        REST::Client

=item GLOBAL VARIABLES USED:
        None

=item EXTERNAL FUNCTIONS USED:
        None

=item RETURNS:
        1 - Success
        0 - Failure

=back

=cut

sub logoutSBC {

	my $self = shift;
	my $sub = "logoutSBC()";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
        my $headers = {Accept => "application/x-www-form-urlencoded", 'Content-Type' => "application/x-www-form-urlencoded"};
        
	my $hostUri = $self->{-obj_baseurl}."rest/logout";
	my $cookie_id = $self->{cookie_id};
	my $restClient = ${$self->{restObj}};


	$restClient->addHeader('cookie',$cookie_id);
	$restClient->POST($hostUri, '',  $headers);

	my $rc = $restClient->responseCode();
	my $content = $restClient->responseContent();
	my $i=0;
	my $line;

	$logger->debug(__PACKAGE__ . ".$sub: ResponseCode =". Dumper(\$rc));
	$logger->debug(__PACKAGE__ . ".$sub: ResponseContent =". Dumper(\$content));

	if ($rc eq "200") {


		if ($content =~m/http_code>200/){
			$logger->info(__PACKAGE__ . ".$sub: SBC1K/2K REST logout Successful !!");
		} else {
			$logger->error(__PACKAGE__ . ".$sub: SBC1K/2K REST logout is not Successful !!");
			return 0;
		}

	} else {
		$logger->error(__PACKAGE__ . ".$sub: SBC1K/2K REST logout is not Successful !!");
		return 0;
	}

	return 1;

}

=head1 checkforCore()

       Help to check whether core happened, if yes then the logs will be collected to user preferred location.
=over

=item ARGUMENTS:

       Mandatory :
               -copy_location = Path to copy the logs

       Optional :
   	       -testcase_id   = Testcase ID	

=item PACKAGES USED:


=item GLOBAL VARIABLES USED:

       None

=item EXTERNAL FUNCTIONS USED:

       SonusQA::Base->storeLogs

=item RETURNS:

       1 - Success
       0 - Failure

=item EXAMPLE:

       $sbcedge_obj->checkforCore( -copy_location => '/home/<USER>/', -testcase_id => 'tms12345');

=back

=cut

sub checkforCore {
    my ($self, %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".checkforCore");
    my $sub_name = 'checkforCore';
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub") ;

    unless ( $args{-copy_location} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory $args{-copy_location} is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my $ls = 'ls -ltr /mnt/core/*.core';
    my @cmd_result;

    unless ( @cmd_result = $self->{root_obj}->execCmd($ls) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Unable to execute $ls.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if(grep(/No such file or directory/,@cmd_result)){
        $logger->debug(__PACKAGE__ . ".$sub_name: No core Generated.".Dumper(\@cmd_result));
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    `mkdir -p $args{-copy_location}/$args{-testcase_id}` ;

    unless ( SonusQA::Base::storeLogs($self,'*.core','',$args{-copy_location},'/mnt/core')){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
   
    $self->{root_obj}->execCmd('rm -rf /mnt/core/*.core');

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}
sub DESTROY{

    my ($self)=@_;
    my ($logger);
    my $sub = 'DESTROY';
    if(Log::Log4perl::initialized()){
      $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".DESTROY");
    }else{
      $logger = Log::Log4perl->easy_init($DEBUG);
    }
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroying object");
    $self->{root_obj}->{conn}->close() if (defined $self->{root_obj}->{conn});
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroyed object");
}
1;
