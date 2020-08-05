package SonusQA::RACOON;

=head1 NAME

SonusQA::RACOON- Perl module for creating ipsec tunnelling with SBX.

=head1 IMPORTANT 

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   my $obj = SonusQA::RACOON->new(-OBJ_HOST => '<host name | IP Adress>',
                                  -OBJ_USER => '<cli user name - usually dsi>',
                                  -OBJ_PASSWORD => '<cli user password>',
                                  -OBJ_COMMTYPE => "<TELNET|SSH>",
                                   optional args
                                 );
=head1 REQUIRES

	Perl5.8.7, Log::Log4perl, SonusQA::Base, Data::Dumper, POSIX

=head1 DESCRIPTION

	This module provides integration of Racoon with ATS. 

=head2 SUB-ROUTINES

=cut

use strict;
use SonusQA::Utils qw(:all);
use Log::Log4perl qw(get_logger :easy); 
use Data::Dumper;
use POSIX ;
our $version = "1.0" ;
use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase); 

our $datestamp = strftime ("%Y%m%d%H%M%S" , localtime) ;

=pod

=head3 SonusQA::RACOON::doInitialization() 

    This function is internally called during the object creation ie. from Base.pm and sets the default parameters as defined herein.

=over

=item Arguments

  NONE

=item Returns

  NOTHING

=back

=cut 

sub doInitialization {
    my ($self , %args) = @_ ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
    my $sub = 'doInitialization' ;
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    
    $self->{COMMTYPES} = ["TELNET", "SSH"];
    $self->{PROMPT} = '/.*[\$%#\}\|\>].*$/' ;
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{TYPE}  = __PACKAGE__  ;
    $self->{conn} = undef ;
    $self->{DEFAULTTIMEOUT} = 500  ;
    $self->{PATH}  =  "/etc/racoon" ;  
    $logger->info("Initialization Complete") ;
    $logger->info(__PACKAGE__. ".$sub : <-- Leaving Sub [1]") ;
    return 1 ;
}

=pod

=head3 SonusQA::RACOON::setSystem()

    This function is also internally called when the connection is made to the object from Base.pm

=over

=item Arguments

  NONE

=item Returns

  NOTHING

=back

=cut

sub setSystem {

    my ($self , %args ) = @_  ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem") ;
    $logger->info(__PACKAGE__ . ".setSystem --> Entered setSystem");

    $self->{conn}->cmd("bash") ;
    $self->{conn}->cmd("") ;  

    $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
    return 1;
}

=pod

=head3 SonusQA::RACOON::execCmd()
    This function enables user to execute any command on the Racoon session created.

=over

=item Arguments:
    1. Command to be executed.
    2. Timeout in seconds (optional).

=item Returns
    Output of the command executed.

=item Example(s):
    my @results = $obj->execCmd("ls -ltr");
    This would execute the command "ls -ltr" on the session and return the output of the command.

=back

=cut

sub execCmd {
    my ($self,$cmd, $timeout) = @_;
    my($flag, $logger, @cmdResults);
    $flag = 1; 
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd") ;
     
    $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
    $logger->debug(__PACKAGE__ . ".execCmd Clearing the buffer before command execution");
    $self->{conn}->buffer_empty ;    #clearing the buffer before the execution of CLI command 

    $timeout ||= $self->{DEFAULTTIMEOUT};
    unless (@cmdResults = $self->{conn}->cmd(String => $cmd, Timeout => $timeout )) {
        $logger->warn(__PACKAGE__ . ".execCmd  COMMAND EXECTION ERROR OCCURRED");
        map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
    };
 
    chomp(@cmdResults);
    @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
    push(@{$self->{CMDRESULTS}},@cmdResults);
    push(@{$self->{HISTORY}},"$cmd");
    map { $logger->debug(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
    foreach(@cmdResults) {
        if(m/(Permission|Error)/i){
            if($self->{CMDERRORFLAG}){
                $logger->warn(__PACKAGE__ . ".execCmd  CMDERROR FLAG IS POSITIVE - CALLING ERROR");
#                &error("CMD FAILURE: $cmd");        not calling error handler if it fails due to permission issue.
            }
            $flag = 0;
            last;
        }
    }
    return @cmdResults;
}

=pod 

=head3 SonusQA::RACOON::execMultipleCmd()
    This function enables user to execute multiple commands on the Racoon session created.

=over

=item Arguments
    1. List of Commands in form of array reference to be executed.

=item Returns
   1 :: if all commands are successsfully executed. 
   0 :: if any one command fails.

=item Example(s):

    my $cmd = ['cd /root/racoon2-20100526a', 'setkey', 'setkey -FP', 'setkey -f /home/sbjain/policy_transport_IKEV2_IPV4_beemer.conf'] ;
    my $result = $obj->execMultipleCmd($cmd);
    This would execute the commands mentioned one by one. 

=back

=cut


sub execMultipleCmd {
    my ( $self, $cmd ) = @_ ;  
    my $sub = "execMultipleCmd" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub" ) ;  
    my (@cmdList, $command) ; 

    unless (defined $cmd ) {
        $logger->error(__PACKAGE__. ".$sub : mandatory command list is not available") ; 
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0 ;
    }

    @cmdList = @$cmd ; 
    $logger->info(__PACKAGE__ . ".$sub: The command list is \'@cmdList\'  " ); 
   
    foreach $command (@cmdList) {
        $logger->info(__PACKAGE__ . ".$sub: The command to be executed is : \'$command\' " ); 
        $self->execCmd($command);
    } 

    $logger->info(__PACKAGE__ . ".$sub: successfully executed all the commands \n" ); 
    return 1 ; 
}

=pod

=head3 SonusQA::RACOON::createFiles()

    This function creates the required configuration files (three) for racoon Execution viz Policy.conf, preshared key, racoon.conf

=over

=item Arguments:
  
  Mandatory :: 
    None (by default it considers the mode as Tunnel Mode and IPV4 configuration).

  Optional :: 
    1. -transport => If Racoon is run for Transport mode, then this parameter needs to be passed. (see usage for moe details) 
    2. -IPV6  => This parameter is needed for running the Racoon on IPV6 configuration (by default, it runs on IPV4 configuration).

=item Returns
   1 : success
   0 : failure

=item Example(s):

  1. when no argument is passed :: (it takes Tunnel Mode and IPV4 configuration by default ) ::
        $racoonObj->createFiles() ;

  2. When arguments are passed :: 
        $racoonObj->createFiles( -transport => 1, -IPV6 => 1) ; 

=back

=cut

sub createFiles { 

    my ($self , %args) = @_ ; 
    my $sub = "createFiles" ; 
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ ) ;      

    $logger->debug(__PACKAGE__ . ".$sub: providing autouser the root access");   
    $self->{conn}->cmd("sudo su") ; 

    $logger->debug(__PACKAGE__ . ".$sub: Logging to $self->{PATH} as root");
    $self->{conn}->cmd("cd $self->{PATH}") ;    

    $logger->debug(__PACKAGE__ . ".$sub: Creating the policy conf files");     
    unless ($self->createPolicyConf(%args)) { 
        $logger->debug(__PACKAGE__ . ".$sub: failed to create Policy Conf file");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving sub [0] ") ;
        return 0 ;
    } 
    
    unless ($self->createPreShared(%args)) { 
        $logger->debug(__PACKAGE__ . ".$sub: failed to create preshared key");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving sub [0] ") ;
        return 0 ;
    }

    unless ($self->createRacoonConf(%args)) { 
        $logger->debug(__PACKAGE__ . ".$sub: failed to create Racoon Conf file");
        $logger->debug(__PACKAGE__ . ".$sub: Leaving sub [0] ") ;
        return 0 ;
    }
    
    return 1 ;
}

=pod

=head3 SonusQA::RACOON::runRacoon()
  
    This function runs the command that sets the basic configuration and invokes Racoon Process Viz setkey commands and invoking the Racoon Process command.

=over

=item Arguments:
Optional
    policy_conf = Policy conf file 
    racoon_conf = Racoon conf file 

=item Returns
    1 - Racoon Server Started
    0 - Failed to Start Racoon Server

=item Example(s)

   unless ($racoonObj->runRacoon('%args)) {
       $logger->debug(__PACKAGE__ . ". unable to invoke racoon command ");
       return 0 ;
   } ; 

=back

=cut

sub runRacoon {

    my ($self, %args) = @_ ; 
    my $sub = "runRacoon" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub"); 
 
    $logger->debug(__PACKAGE__ . ".$sub : --> Entered Sub");
    $self->{STARTED} = 1;
    my $cmd = ['cd /etc/racoon','ip xfrm state flush', 'ip xfrm policy flush', 'setkey -D', 'setkey -F', 'setkey -DP', 'setkey -FP'];
    if(defined $args{-policy_conf}){
        push (@$cmd , "setkey -f $args{-policy_conf}");
    }else{
        push (@$cmd , "setkey -f policy_$datestamp.conf");
    }
    unless($self->execMultipleCmd($cmd)){
        $logger->error(__PACKAGE__ . ".$sub Failed to execute commands");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    if(defined $args{-raccon_conf}){
        $self->{conn}->print("racoon -F -ddd -f $args{-raccon_conf}");
    }else{
        $self->{conn}->print("racoon -F -ddd -f racoon_$datestamp.conf")
    }
    $logger->debug(__PACKAGE__ . ".$sub: Started Racoon");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub[1] ");
    return 1;
}

=pod

=head3 SonusQA::RACOON::runRacoon2()

    This function runs the command that sets the basic configuration and invokes Racoon2 process.

=over

=item Arguments:
    None

=item Returns
    1- Racoon Server started
    0- Failed to start Racoon server

=item Example(s)

   unless ($racoonObj->runRacoon2()) {
       $logger->debug(__PACKAGE__ . ". unable to invoke racoon command ");
       return 0 ;
   } ;

=back

=cut

sub runRacoon2{
    my ($self) = @_ ;
    my $sub = "runRacoon2" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub : --> Entered Sub");
    $self->{STARTED} = 2;
    $logger->debug(__PACKAGE__ . ".$sub : Executing Commands to start Racoon2");
    my $cmd = ['cd /root/racoon2','ip xfrm state flush', 'ip xfrm policy flush', 'cd spmd', './spmd  -f  /usr/local/etc/racoon2/racoon2.conf ', 'cd ../iked'];
    unless($self->execMultipleCmd($cmd)){
        $logger->error(__PACKAGE__ . ".$sub Failed to execute commands");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $self->{conn}->print("./iked -f /usr/local/etc/racoon2/racoon2.conf -dF");
    $logger->debug(__PACKAGE__ . ".$sub: Started Racoon");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub[1] ");
    return 1;
    
}    

=pod

=head3 SonusQA::RACOON::stopRacoon()

    This function stops the running foreground process and kills the background process.

=over

=item Arguments:
    None

=item Returns
    1- Racoon server stopped
    0- Failed to stop Racoon Server

=item Example(s)

   unless ($racoonObj->stopRacoon()) {
       $logger->debug(__PACKAGE__ . ". unable to invoke racoon command ");
       return 0 ;
   } ;

=back

=cut

sub stopRacoon{
    my ($self) = @_ ;
    my $sub = "stopRacoon" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->info(__PACKAGE__ . ".$sub : passing ctrl c argument to stop the racoon process") ;
    $self->{conn}->cmd("\x03") ;

    if($self->{STARTED} == 2){
        $logger->info(__PACKAGE__ . ".$sub Killing the current racoon2 process");
        unless($self->{conn}->cmd("pkill -f spmd")){
            $logger->error(__PACKAGE__ . ".$sub Couldn't get prompt ($self->{PROMPT}) after executing command");
            $logger->debug(__PACKAGE__ . ".$sub errmsg: ". $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub lastline: ". $self->{conn}->lastline);
            $logger->debug(__PACKAGE__ . ".$sub PROMPT : $self->{PROMPT}");
            $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub[0]");
            
            return 0;
        }
    }
    
    $logger->debug(__PACKAGE__ . ".$sub Stopped Racoon");
    $self->{STARTED} = 0;
    $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub[1]");
    return 1;
}

=pod
=head3 SonusQA::RACOON::createPolicyConf()
  
    This function is internally called by the subroutine createFiles(). 
    More details of that subroutine, please refer to its documentation.

=over

=item Arguments: (if it is called independently)
   Mandatory : None  

  Optional :: 
    1. -transport => If Racoon is run for Transport mode, then this parameter needs to be passed. (see usage for moe details) 
    2. -IPV6  => This parameter is needed for running the Racoon on IPV6 configuration (by default, it runs on IPV4 configuration).

=item Returns:
   1 : success
   0 : failure

=item Example(s):

  1. when no argument is passed :: (it takes Tunnel Mode and IPV4 configuration by default ) ::
        $racoonObj->createPolicyConf() ;

  2. When arguments are passed :: 
        $racoonObj->createPolicyConf( -transport => 1, -IPV6 => 1) ; 

=back

=cut

sub createPolicyConf {
    my ($self, %args)  = @_ ;
    my $sub = "createPolicyConf" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->info(__PACKAGE__. ".$sub: opening the file \'policy_$datestamp.conf\'") ;
    unless (open (POLICYCONF, "> $ENV{HOME}/policy_$datestamp.conf")) {
        $logger->error(__PACKAGE__. ".$sub: failed to open policy.conf file") ;
        return 0 ;
    }

    my $LIF_IP = (defined $args{-IPV6} and $args{-IPV6}) ? $self->{TMS_ALIAS_DATA}->{NIF}->{1}->{IPV6} : $self->{NIF_IP} ;
    my $SIPSIG_IP = (defined $args{-IPV6} and $args{-IPV6}) ? $self->{TMS_ALIAS_DATA}->{SIG_SIP}->{1}->{IPV6} : $self->{SIPSIG_IP} ; 
    my $RACOON_IP = (defined $args{-IPV6} and $args{-IPV6}) ? $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6} : $self->{RACOON_IP} ; 

#Checking for the mode : if transport flag is not defined, by default it takes tunnel mode.
 
    my $mask = ( defined ($args{-IPV6}) and $args{-IPV6} ) ? '60' : '32' ;
    my $mode = ( defined ($args{-transport}) and $args{-transport} ) ? 'transport' : 'tunnel' ;  
    $logger->info(__PACKAGE__. ".$sub: Mask chosen is \'$mask\' and Mode selected is : \'$mode\' ") ; 
    
    my @content = split ("~" , "#!/usr/sbin/setkey -f ~
# Flush the SAD and SPD ~
flush ; # optional command  ~
spdflush; # optional command  ~

# Security policies ~

spdadd $RACOON_IP/$mask $SIPSIG_IP/$mask any -P out ipsec esp/$mode/$RACOON_IP-$LIF_IP/require ; ~
spdadd $SIPSIG_IP/$mask $RACOON_IP/$mask any -P in ipsec esp/$mode/$LIF_IP-$RACOON_IP/require ;  ~ 

") ; 

    foreach (@content) {
        print POLICYCONF $_ ;       
    } 
    close (POLICYCONF) ;
    $logger->info(__PACKAGE__. ".$sub : succesfully closed the policy config file ") ;
    
    $logger->info(__PACKAGE__. ".$sub : copying the policy file ") ;
    my $cmd = "cp $ENV{HOME}/policy_$datestamp.conf ." ;
    $self->{conn}->cmd($cmd) ; 
    my @result = $self->{conn}->cmd("cat policy_$datestamp.conf")  ; 
    return 1 ;
} 

=pod

=head3 SonusQA::RACOON::createPreShared() 
  
   -  This function is internally called by the subroutine createFiles() and creates the configuration file for Racoon named preshared key.
 
   -  More details of that subroutine, please refer to its documentation. 
   
   -  If this function needs to be called independently, refer the documentation for subroutine createPolicyConf(). 

=over

=item Arguments

  NONE

=item Returns

  NOTHING

=back

=cut

sub createPreShared {
    my ($self , %args) = @_ ;
    my $sub = "createPreShared" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub") ;

    $logger->info(__PACKAGE__. ".$sub: opening the file \'psk_$datestamp.txt\'") ;
    unless (open (PRESHARED, "> $ENV{HOME}/psk_$datestamp.txt")) {
        $logger->error(__PACKAGE__ . ".$sub : failed to create psk.txt file") ;
        return 0 ;
    }  
    my $LIF_IP = (defined $args{-IPV6} and $args{-IPV6}) ? $self->{TMS_ALIAS_DATA}->{NIF}->{1}->{IPV6} : $self->{NIF_IP} ;
    my $SIPSIG_IP = (defined $args{-IPV6} and $args{-IPV6}) ? $self->{TMS_ALIAS_DATA}->{SIG_SIP}->{1}->{IPV6} : $self->{SIPSIG_IP} ;  
    
    my $ip = (defined $args{-transport} and $args{-transport}) ? "$SIPSIG_IP"  : "$LIF_IP" ;  

    my $PreSharedKey = "$self->{PRESHARED_KEY}" ;
    $logger->info(__PACKAGE__ . ".$sub : IP obtained : $ip , Shared Key : $PreSharedKey \n") ;

    my @content = split('~' , "# file for pre-shared keys used for IKE authentication ~

# format is:  'identifier' 'key' ~

#!/usr/sbin/setkey -f ~

###### ALSO the KEY is written into the SAD from where the kernel refers so as to apply IP sec to a given packet ####### ~

$ip $PreSharedKey

") ;

    foreach (@content) {
        print PRESHARED $_ ;
    }
    $logger->info(__PACKAGE__. ".$sub : successfully closing the Preshared Key") ;
    close (PRESHARED) ;
    
    $logger->info(__PACKAGE__. ".$sub : copying the shared key ") ;
    my $cmd  = "cp $ENV{HOME}/psk_$datestamp.txt ." ;
    $self->{conn}->cmd($cmd) ;

    $logger->info(__PACKAGE__. ".$sub : changing to the required permissions of shared key ") ;
    $self->{conn}->cmd("chmod 400 psk_$datestamp.txt") ; 
    my @result = $self->{conn}->cmd("cat psk_$datestamp.txt")  ; 
    return 1 ;
}

=pod

=head3 SonusQA::RACOON::createRacoonConf()  
  
   -  This function is internally called by the subroutine createFiles() and creates the configuration file for Racoon named Racoon.conf 
 
   -  More details of that subroutine, please refer to its documentation. 
   
   -  If this function needs to be called independently, refer the documentation for subroutine createPolicyConf(). 

=cut

sub createRacoonConf {
    my ( $self, %args )  = @_ ;
    my $sub = "createRacoonConf" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ .".$sub") ;

    $logger->info(__PACKAGE__. ".$sub: opening the file \'racoon_$datestamp.conf\'") ;
    unless (open (RACOONCONF, "> $ENV{HOME}/racoon_$datestamp.conf")) {
        $logger->error(__PACKAGE__ . ".$sub : failed to create racoon.conf file") ;
        return 0 ;
    }
         
    my $LIF_IP = (defined $args{-IPV6} and $args{-IPV6}) ? $self->{TMS_ALIAS_DATA}->{NIF}->{1}->{IPV6} : $self->{NIF_IP} ;
    my $SIPSIG_IP = (defined $args{-IPV6} and $args{-IPV6}) ? $self->{TMS_ALIAS_DATA}->{SIG_SIP}->{1}->{IPV6} : $self->{SIPSIG_IP} ; 
    my $RACOON_IP = (defined $args{-IPV6} and $args{-IPV6}) ? $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6} : $self->{RACOON_IP} ;   

    my $ip = (defined $args{-transport} and $args{-transport}) ? "$SIPSIG_IP"  : "$LIF_IP" ;  
    my $mask = ( defined ($args{-IPV6}) and $args{-IPV6} ) ? '60' : '32' ;
    $logger->info(__PACKAGE__. ".$sub: The IP taken is \'$ip\'  and  mask selected is \'$mask\'") ;

    my @content = split('~' , "# Racoon IKE daemon configuration file ~ 
# See 'man racoon.conf' for a description of the format and entries. ~

#give the path of pre-shared key file psk.txt ~

path pre_shared_key \"/etc/racoon/psk_$datestamp.txt\" ; ~

#path certificate \"\/etc\/racoon\/certs\"; ~

#authentication mode is pre-shared key and DH mode is modp1024 ~

remote $ip { ~
    exchange_mode main ; ~
    proposal { ~ 

        encryption_algorithm 3des; ~
        hash_algorithm sha1;  ~
        authentication_method pre_shared_key; ~ 
        dh_group modp1024;  ~
    } ~        
} ~ 

#below configuration is for creation of IPsec SA using the IKE SA. Encryption algorithm is 3des, authentication algorithm is HMAC-sha1 ~

sainfo address $RACOON_IP/$mask any address $SIPSIG_IP/$mask any { ~
    encryption_algorithm 3des; ~
    authentication_algorithm hmac_sha1; ~
    compression_algorithm deflate; ~
} ~

") ;

    foreach (@content) {
        print RACOONCONF $_ ;
    }  
    $logger->debug(__PACKAGE__ . ".$sub : successfully closing the File handler for Racoon Config File") ;
    close (RACOONCONF)  ;
    
    $logger->debug(__PACKAGE__ . ".$sub : copying the Racoon Conf file ") ;
    my $cmd = "cp $ENV{HOME}/racoon_$datestamp.conf ." ;
    $self->{conn}->cmd($cmd) ; 
    my @result = $self->{conn}->cmd("cat racoon_$datestamp.conf") ;  
    return 1 ;

}

=pod

=head3 SonusQA::RACOON::DESTROY()  
  
    - This function issues Control C command to stop the raccon process otherwise it keeps on running in the background even after killing the object. 
    - The configuration files are moved to the following directory of user :: /ats_user/logs. 
    - the connection is closed and the suite is exited.

=over

=item Example(s): 
    - $racoonObj->DESTROY() ;  

=back

=cut

sub DESTROY {

    my ($self) = @_ ; 
    my $sub = "DESTROY" ; 

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ .".$sub") ;  
   
    $self->stopRacoon() if($self->{STARTED} );

    $logger->info(__PACKAGE__ . ".$sub : Closing the connection to Racoon Object") ;
    $self->closeConn() ; 
}


1;  


