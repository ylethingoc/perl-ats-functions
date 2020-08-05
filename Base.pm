package SonusQA::Base;
 
use strict;
use warnings;
use SonusQA::Utils qw (:all);
use Sys::Hostname; 
use Log::Log4perl qw(:easy);
use Net::Telnet;
use XML::Simple; # qw(:strict);
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request::Common;
use JSON qw( decode_json );
require ATS;
use Data::GUID;
use Data::UUID;
use WWW::Curl::Easy;
use DBI;
use Tie::IxHash;
use MIME::Base64;
use Net::OpenSSH;
use SonusQA::SCPATS;
use Time::HiRes qw(gettimeofday tv_interval);

our $AtsSCP = undef;
our @EXPORT_OK;
=head1 NAME

SonusQA::Base - SonusQA namespace base class

=head1 SYNOPSIS

use ATS;

=head1 DESCRIPTION

SonusQA::Base provides an extended interface to Net::Telnet.  Many SonusQA namepsace objects extend SonusQA::Base (ISA).
This provides them with the necessary functionality to implement different kinds of sessions (connectivity).

Typically SonusQA::Base is not used directly - other objects should simply extend this to obtain it's functionality.

=head1 SEE ALSO

L<Net::Telnet>, L<XML::Simple>

=head2 AUTHORS

Darren Ball <dball@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.
See Inline documentation for contributors.

=head2 SUB-ROUTINES
=cut
=head2 C< new >
    Notes:
    * The arguments take the form of a list of key-value pairs.
    * For a given key 'attribute', the following are equivalent: -ATTRIBUTE, ATTRIBUTE, -attribute, attribute.
      Internally they are stored as $obj->{ATTRIBUTE}
    my $obj = SonusQA::<namespace object>->new(-obj_host => <object host name or IP address>,
                                                -obj_hosts => <a reference to a list of object host names or IP addresses>
                                                -obj_user => <object connection user id>,
                                                -obj_password => <object connection user password>,
                                                -return_on_fail => <boolean 0 false, 1 true (default 0)> 
                                                -comm_type => <typically: SSH, SFTP, TELNET or FTP - see specific object documentation for details>);

    This method returns a SonusQA namespace object of which would normally have extended SonusQA::Base.
    When used with a SonusQA namespace object that extends this class - this method returns a Net::Telnet object.

    Notes:
    -comm_type
        Automatic fallback (TELNET <-> SSH and SFTP <-> FTP) for failed connection attempts is supported.
        Fallback is NOT initited when a login attempt fails due to incorrect login/password or timeout on $obj->{PROMPT}
        $obj->{COMM_TYPE} is set to the protocol that was succeffully used to establish a session;
        e.g., when TELNET fails but SSH is successful then $obj->{COMM_TYPE} is set to SSH even though initially
        it was set to TELNET
    -obj_host and -obj_hosts
        When -obj_host is defined, it is prepanded (perl 'unshift' operation) to the array pointed to by reference -obj_hosts
        Internally: $obj->{OBJ_HOSTS} is a reference and @{$obj->{OBJ_HOSTS}} is a list
        Elements of the @{$obj->{OBJ_HOSTS}} list are used, one-by-one, to establish connection. On the first successful
        attempt, the used address is saved as $obj->{OBJ_HOST} and no additonal connection attempts are made
    -return_on_fail
        Used to to determine whether to call Sonus::Utils::error on failure to connect (and thus force exit from the script, the default behaviour) 
        or to return 0 and allow the caller to do error processing (e.g. when waiting for a device to reboot). In the latter case the caller can check if
        the returned value is a hash(success) or not using ref().
    Examples:
        my @hosts = qw/ gsx-1-1 gsx-2-1 gsx-1-2 gsx-2-2 /;
        my $s = new SonusQA::Base(  -obj_host => gsx,
                                    -obj_hosts => \@hosts,
                                    -obj_user => admin,
                                    -obj_password => gsx9000,
                                    -comm_type => TELNET,
                                    -defaulttimeout => 10,
                                );
        or:
        my $s = new SonusQA::Base(  -obj_host => gsx,
                                    -obj_hosts => [ 'gsx-1-1', 'gsx-2-1', 'gsx-1-2', 'gsx-2-2' ],
                                    -obj_user => admin,
                                    -obj_password => gsx9000,
                                    -comm_type => TELNET,
                                    -defaulttimeout => 10,
                                );

=cut

sub new {
    my($class, %args) = @_;
    my $sub = "new";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__. ".$sub: --> Entered sub ");
    my(
       $obj_host,
       $obj_hostname,
       $obj_port,
       $obj_user,
       $obj_password,
       $conn,
       $obj_commtype,
       $obj_nodetype,
       $obj_maintmode,
       $return_on_fail,
       @accpt_commptypes,
       $sessionlog,
       );
    my $self = bless {}, $class;
    #@accpt_commptypes = qw(TELNET SSH SFTP FTP);
    # Default values
    $obj_maintmode = 1;  # Defaulting to using maint mode for DSICLI objects
    $self->{DEFAULTTIMEOUT} = 60;
    # CMDERRORFLAG is used to determine whether or not to call error on execFuncCall failure.
    # Enable this to provide automatic checking for errors
    if(defined($ENV{CMDERRORFLAG})){
        $logger->debug(__PACKAGE__ . ".new  ENV CMDERRORFLAG OVERRIDE");
        $self->{CMDERRORFLAG} = $ENV{CMDERRORFLAG};
    }
    else {
        $self->{CMDERRORFLAG} = 1;
    }
    # Some mandatory object parameters - mostly for stack and information
    
    $self->{STACK} = [];
    $self->{BANNER} = [];     # why dont we store banner msg which apears after password
    $self->{LOCALHOST} = 0; #local box ip address
    $self->{HISTORY} = ();
    $self->{CMDRESULTS} = [];
    $self->{LIBLOADED} = 0; 
    $self->{SESSIONLOG} = 1;            # scongdon: Nov 21, 2008. SESSIONLOG option for connect()
    $self->{IGNOREXML} = 0;
    $self->{RETURN_ON_FAIL} = 0;
    $self->{PROMPT} = '/.*[\$#%>\[]]\s?$/'; # connect() uses this attribute and complains if not set; we should default to some value
    $self->{DEFAULTPROMPT} = $self->{PROMPT};
    $self->{BINMODE} = 0;
    $self->{OUTPUT_RECORD_SEPARATOR} = "\r";
    
    # Pawel, 7/30/07
    # Pass object initiation args to doInitializtaion() for processing
    # The subroutine may overwrite some of the defaul values, most notably, DEFAULTTIMEOUT
    #
    $self->doInitialization(%args);
	
    ## Parse the named parameters.
    foreach (keys %args) {
        # Some explicit checking for type that have to be of a certian value
        if(/^-?obj_commtype$/i){
	    foreach my $a (@{$self->{COMMTYPES}}){
		if(uc($args{$_}) eq $a ){
		    $self->{COMM_TYPE} = $a;
		    last;
		}
	    }
	}
        # #Everything is just assigned back to the object
        my $var = uc($_);
        $var =~ s/^-//i;	   
        $self->{$var} = $args{$_};
    }

    if ( $self->{OBJ_HOST} ) { unshift @{$self->{OBJ_HOSTS}}, $self->{OBJ_HOST}; }
    $self->{OBJ_NEW_PASSWORD} = $self->{OBJ_PASSWORD};

    ## Check for mandatory parameters.
    &error(__PACKAGE__ . ".new Mandatory \"-obj_host\" (or \"-obj_hosts\") parameter not provided") unless $self->{OBJ_HOSTS}[0];
    my @userid = qx#id -un#;
    chomp @userid;
    unless ( $self->{OBJ_USER} ){
        $self->{OBJ_USER} = $userid[0];
	$logger->debug(__PACKAGE__ . ".$sub: $self->{OBJ_USER} is empty or not defined. Setting the current user as \"OBJ_USER\".");
    }
    &error(__PACKAGE__ . ".new Mandatory \"-obj_commtype\" parameter not provided or invalid") unless defined $self->{COMM_TYPE};

    unless($self->{OBJ_KEY_FILE} || $self->{OBJ_PASSWORD} || $self->{OBJ_USER} eq $userid[0]){
        &error(__PACKAGE__ . ".new Mandatory \"-obj_password\" or \"-obj_key_file\" parameter not provided");
    }

    $self->verifySelf() if $self->can("verifySelf");          
    $logger->info(__PACKAGE__ . ".$sub: Connection Information:");
    $self->descSelf();
    
    $self->{USER_DEFINED_COMM_TYPE} = $self->{COMM_TYPE};
    my $connected = 0;
    
    foreach ( @{$self->{OBJ_HOSTS}} ) {
        
        $self->{COMM_TYPE} = $self->{USER_DEFINED_COMM_TYPE};
        $self->{OBJ_HOST} = $_;
        $logger->debug(__PACKAGE__ . ".$sub: Trying Connecting to OBJ_HOST [$_]"); 
        if ( $self->connect( %args ) ) {
            $connected = 1;
            $logger->debug(__PACKAGE__ . ".$sub: Connected Successfully to OBJ_HOST [$_]");
            last;
        }
    }
    
    unless ( $connected ) {
        if($self->{RETURN_ON_FAIL}) {
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        } else {
            # Default behaviour - &error calls exit and script terminates.
            &error(__PACKAGE__ . " Failed to connect");
        }
    }   
    
    #VMCTRL object should be deleted at the last
    ($class =~ /VMCTRL/) ? (push(@cleanup, $self)) : (unshift(@cleanup, $self));
    return $self;
}


=head2 C< loadXMLLibrary >

Typical inner library usage:
  $obj->loadXMLLibrary(<library path>);
  &error(__PACKAGE__ . ".setSystem XML LIBRARY ERROR") if !$self->{LIBLOADED}; 

This method is used commonly throughout the SonusQA namepsace to load XML libraries for objects that require them.
This method accepts a library path - of which it to be absolute (from root).  If the method can not verify the library path exists
using the '-e' file test - it will attempt to call the parent object's autogenXML function (if that function exists).

If successful, this method will load the XML library into $self->{funcref} using XML::Simple, implementing Storable.

This method sets $self->{LIBLOADED} to true (1) if successful.
This method returns $self->{LIBLOADED}, a boolean <0|1> always.

=cut

sub loadXMLLibrary(){
    my($self,$libpath,$dont_exit)=@_;
    my ($logger);
    if(Log::Log4perl::initialized()){
      $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".loadXMLLibrary");
    }else{
      $logger = Log::Log4perl->easy_init($DEBUG);
    }
    
    $self->{LIBLOADED} = 0;
    
    if($self->{AUTOGENERATE} && $self->can("autogenXML")){
      $self->autogenXML();
      exit 0;  # This is called - as the generation script need not go any further
    }

    if( ! -e $libpath){    
       if($self->can("autogenXML")){
           $logger->debug(__PACKAGE__ . ".loadXMLLibrary  AUTOGENERATION IS BEING CALLED");
           $self->autogenXML();
       }
    }

    if( -e $libpath){
      eval {
        $self->{funcref} = &XMLin($libpath,ForceArray=>[],KeyAttr=>['id'],SuppressEmpty=>'',cache=>'storable');
        # Possibly add the export of all the functions here as keys of the xml struct, plus add an autoload method to detect an invalid call.
        push(@EXPORT_OK, keys (%{$self->{funcref}->{function}}) );
      };

        if ($@) {
            if ($dont_exit) {
                $logger->warn(__PACKAGE__ . ".loadXMLLibrary() UNABLE TO PARSE XML CONIFGURATION FILE: $libpath");
                return 0;
            } else {
                &error(__PACKAGE__ . ".loadXMLLibrary() UNABLE TO PARSE XML CONIFGURATION FILE: $libpath");
            }   
        }

      $self->{LIBLOADED} = 1;
      $logger->info(__PACKAGE__ . ".loadXMLLibrary  SUCCESSFULLY PARSED XML CONFIGURATION FILE: $libpath");
    }else{
        if ($dont_exit) {
            $logger->warn(__PACKAGE__ . ".loadXMLLibrary()  XML CONFIGURATION FILE: $libpath DOES NOT EXIST");
            return 0;
        } else {
            &error(__PACKAGE__ . ".loadXMLLibrary  XML CONFIGURATION FILE: $libpath DOES NOT EXIST");
        }
    }
    return $self->{LIBLOADED};
    
}


=head2 C< descSelf >
Typical inner library usage:
$obj->descSelf([<mode: info | debug | warn | critical>);
This method is used to display a summary of object information.  This method is called automatically by C< new >.
This method does not return anything - it is a display method

=cut

sub descSelf(){
    my($self,$mode)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".descSelf");
    if(!defined($mode)){
	$mode = "info";
    }
    if (defined($self->{OBJ_HOST})) {
        $logger->$mode(__PACKAGE__ . ".descSelf HOST:\t$self->{OBJ_HOST}");
    } elsif (defined($self->{OBJ_HOSTS})) {
        my $hosts = join ", ", @{$self->{OBJ_HOSTS}};
        $logger->$mode(__PACKAGE__ . ".descSelf HOSTS:\t$hosts");
    }
    $logger->$mode(__PACKAGE__ . ".descSelf USER:\t$self->{OBJ_USER}");
    $logger->$mode(__PACKAGE__ . ".descSelf PASS:\t$self->{OBJ_PASSWORD}");
    if($self->{TYPE}){
	$logger->$mode(__PACKAGE__ . ".descSelf TYPE:\t$self->{TYPE}");
    }
    if($self->{ORACLE_USER}){
	$logger->$mode(__PACKAGE__ . ".descSelf ORACLE USER:\t$self->{ORACLE_USER}");
    }
    if($self->{ORACLE_PASSWORD}){
	$logger->debug(__PACKAGE__ . ".descSelf ORACLE PASSWORD:\t\$self->{ORACLE_PASSWORD}");
    }
    if($self->{COMM_TYPE}){
	$logger->$mode(__PACKAGE__ . ".descSelf COMM TYPE:\t$self->{COMM_TYPE}");
    }
    if($self->{OBJ_PORT}){
	$logger->$mode(__PACKAGE__ . ".descSelf PORT:\t$self->{OBJ_PORT}");
    }
    if($self->{OBJ_HOSTNAME}){
	$logger->$mode(__PACKAGE__ . ".descSelf HOSTNAME:\t$self->{OBJ_HOSTNAME}");
    }
    if($self->{OBJ_NODETYPE}){
	$logger->$mode(__PACKAGE__ . ".descSelf NODE TYPE:\t$self->{OBJ_NODETYPE}");
    }
    if($self->{OBJ_MAINTMODE}){
	$logger->$mode(__PACKAGE__ . ".descSelf MAINT MODE:\t$self->{OBJ_MAINTMODE}");
    }    	
    if($self->{OBJ_TARGET}){
	$logger->$mode(__PACKAGE__ . ".descSelf TARGET INSTANCE:\t$self->{OBJ_TARGET}");
    } 	
}

=head2 C< doInitialization >
Typical inner library usage:
$obj->doInitialization();
This method is empty and is typically over-ridden by the class that is extending C< SonusQA::Base >.

=cut

sub doInitialization {}

sub spawnPty {
    my ($self, $cmdArgs)=@_;
    my($pid, $pty, $tty, $tty_fd, @cmd);
    our $success;
    @cmd = @$cmdArgs;
    ## Create a new pseudo terminal.
    use IO::Pty ();
    &error(__PACKAGE__ . ".spawnPty Unable to create IO::Pty object") unless $pty = new IO::Pty;
    ## Execute the program in another process.
    unless ($pid = fork) {  # child process\
        &error(__PACKAGE__ . ".spawnPty Problem spawing Pty session") unless defined $pid;
        ## Disassociate process from existing controlling terminal.
        use POSIX ();
        #POSIX::setsid or die "setsid failed: $!";
	&error(__PACKAGE__ . ".spawnPty Unable to call POSIX::setsid") unless POSIX::setsid;
        $pty->make_slave_controlling_terminal; 
        ## Associate process with a new controlling terminal.
        $tty = $pty->slave;
        $tty_fd = $tty->fileno;
        close $pty;

        ## Make stdio use the new controlling terminal.
        open STDIN, "<&$tty_fd" or die $!;
        open STDOUT, ">&$tty_fd" or die $!;
        open STDERR, ">&STDOUT" or die $!;
        close $tty;
	#autoflush STDOUT 0;	
        ## Execute requested program.
        #exec @cmd or die "problem executing $cmd[0]\n";
	&error(__PACKAGE__ . ".spawnPty Problem executing $cmd[0]") unless exec @cmd;
        #system(@cmd) == 0 or &error(__PACKAGE__ . ".spawnPty Problem executing $cmd[0]");
    } # end child process
    $pty;
}


=head2 C< connect >
Typical inner library usage:
$obj->connect();

=cut

sub connect {
    my ($self, %args) = @_;
    my $sub_name = "connect";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered $sub_name");
    my($loop, $ok_flag , $telObj, @results, $prematch, $match, $ug, @cmd);
    $ug = new Data::UUID();

    my @retry_passwd =  $self->{OBJ_PASSWORD} ; #TOOLS - 16364
    ($self->{OBJ_USER},$self->{OBJ_PASSWORD}) = ('admin',$self->{TMS_ALIAS_DATA}->{LOGIN}->{3}->{PASSWD} || 'admin') if(exists $self->{'TMS_ALIAS_DATA'} and $self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} =~ /(PSX|EMS)/i and $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID} =~ /(ssuser|insight)/i);    
    #TOOLS-18755 - For admin user, We are changing the passowrd to Sonus@123, so removing the product TYPE check and having only OBJ_USER check.
    if(defined($self->{TYPE})) {
        if ($self->{OBJ_USER} =~ /^admin$/ ) {
 	    (push @retry_passwd , 'admin') unless(grep (/^admin$/,@retry_passwd));
            (push @retry_passwd , 'Sonus@123') unless(grep (/^Sonus\@123$/,@retry_passwd));
            (push @retry_passwd , $self->{DEFAULT_PASSWORD}) unless(grep (/^$self->{DEFAULT_PASSWORD}$/,@retry_passwd)); #TOOLS-17411
        }elsif ($self->{TYPE} =~ /SBCEDGE/ and $self->{OBJ_USER} =~ /^root$/) {
            (push @retry_passwd , 'sonus') unless(grep(/^sonus$/,@retry_passwd));
        }
    }
    if ( exists $self->{TMS_ALIAS_DATA}) {
         push @retry_passwd ,$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD}   if( $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD} and !grep ( /^$self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{PASSWD}$/ , @retry_passwd ))  ;
         push @retry_passwd ,$self->{TMS_ALIAS_DATA}->{LOGIN}->{2}->{PASSWD}   if( $self->{TMS_ALIAS_DATA}->{LOGIN}->{2}->{PASSWD} and !grep ( /^$self->{TMS_ALIAS_DATA}->{LOGIN}->{2}->{PASSWD}$/ , @retry_passwd ))  ;
    }
    #As we first try login with OBJ_PASSWORD, its unnecessary to add OBJ_PASSWORD in retry_passwd.Because the maximum trials to retry login is restricted to Three times.
    shift @retry_passwd;#TOOLS-17411

    # Pawel 8/23/2007
    # Adding fallback (TELNET <-> SSH and SFTP <-> FTP) for failed connection attempts
    #
    my $failures = 0;
    my $failures_threshold = $args{-failures_threshold} || 2;

    while ( $failures < $failures_threshold ) {

        if ( $failures ) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Waiting for 30seconds before connection attempt");
            sleep(30);
            $ug = new Data::UUID();
            # Switch protocol
            if (( $self->{COMM_TYPE} eq 'TELNET')&&(grep(/^SSH$/i,@{$self->{COMMTYPES}}))) { $self->{COMM_TYPE} = 'SSH'; }
            elsif (($self->{COMM_TYPE} eq 'SSH' )&&(grep(/^TELNET$/i,@{$self->{COMMTYPES}}))) { $self->{COMM_TYPE} = 'TELNET'; }
            elsif (($self->{COMM_TYPE} eq 'FTP' )&&(grep(/^SFTP$/i,@{$self->{COMMTYPES}}))) { $self->{COMM_TYPE} = 'SFTP'; }
            elsif (($self->{COMM_TYPE} eq 'SFTP')&&(grep(/^FTP$/i,@{$self->{COMMTYPES}}))) { $self->{COMM_TYPE} = 'FTP'; }
            elsif ( $self->{COMM_TYPE} eq 'NETCONF' ) { $failures = $failures_threshold } # We have no fallback for Netconf, the only mandatory transport per the RFC is SSH - so rather than just retry until we hit the failure threshold, we force a bail-out thru the failure leg here.
        }   

        $logger->info(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Making $self->{COMM_TYPE} connection attempt");

        my $uuid = $ug->create_str();

        # scongdon: Nov 21, 2008
        # Adding option for logging based on SESSIONLOG

        my %sessionLogInfo;

        if ( $self->{SESSIONLOG} ) {
            $sessionLogInfo{sessionDumpLog} = "/tmp/sessiondump_". $uuid. ".log";
            $sessionLogInfo{sessionInputLog} = "/tmp/sessioninput_". $uuid. ".log";

            # Update the log filenames
            $self->getSessionLogInfo(-sessionLogInfo   => \%sessionLogInfo);

            $self->{sessionLog1} = $sessionLogInfo{sessionDumpLog};
            $self->{sessionLog2} = $sessionLogInfo{sessionInputLog};
        }
        else {
            $self->{sessionLog1} = ""; # turning off dump_log
            $self->{sessionLog2} = ""; # turning off input_log
        }
        $logger->debug(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Session dump log: $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Session input log: $self->{sessionLog2}");

        $self->{CONNECTED_IPTYPE} = ($self->{OBJ_HOST} =~ /\d+\.\d+\.\d+\.\d+/) ? 'IPV4' : 'IPV6'; # storing the ip type used for connection

        if($self->{COMM_TYPE} eq 'TELNET'){

            if((!$self->{OBJ_PORT}) or ($self->{OBJ_PORT} == 22)){
                $self->{OBJ_PORT}=23;
            }

            if( $self->{SESSIONLOG} ) {
                $telObj = new Net::Telnet (-prompt => $self->{PROMPT},
                                           -port => $self->{OBJ_PORT},
                                           -telnetmode => 1,
                                           -cmd_remove_mode => 1,
                                           -output_record_separator => $self->{OUTPUT_RECORD_SEPARATOR},
                                           -Timeout => $self->{DEFAULTTIMEOUT},
                                           -Errmode => "return",
                                           -Dump_log => $self->{sessionLog1},
                                           -Input_log => $self->{sessionLog2},
                                           -binmode => $self->{BINMODE},
                                           -Family => 'any', 
                                        );
            } else {
                $telObj = new Net::Telnet (-prompt => $self->{PROMPT},
                                           -port => $self->{OBJ_PORT},
                                           -telnetmode => 1,
                                           -cmd_remove_mode => 1,
                                           -output_record_separator => $self->{OUTPUT_RECORD_SEPARATOR},
                                           -Timeout => $self->{DEFAULTTIMEOUT},
                                           -Errmode => "return",
                                           -binmode => $self->{BINMODE},
                                           -Family => 'any',
                                        );
            }

            unless ( $telObj ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Failed to create a session object");
                $failures += 1;
                next;
            }
            
            unless ( $telObj->open($self->{OBJ_HOST}) ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Net::Telnet->open() failed");
                $failures += 1;
                next;
            }
            else {        #to check already a FORTISSIMO session is active if so then new session will not be established
                if ( $self->{TYPE} eq 'SonusQA::FORTISSIMO' ) {
                    my @lines = $telObj->getlines;
                    if ( grep /session already active/, @lines ) {
		        $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Net::Telnet->open() failed due to already active session");
		    }
                }
                $logger->debug(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Net::Telnet->open() succeeded");
	    }
            # Added for spectra2: 
	    if (($self->{OBJ_PORT} == 10001)&&($self->{TYPE} eq 'SonusQA::SPECTRA2')) {
		$logger->debug(__PACKAGE__ . ".$sub_name Not using the username and password for spectra2 connection");
	    }
	    # added for fortissimo
	    elsif (($self->{OBJ_PORT} == 23)&&($self->{TYPE} eq 'SonusQA::FORTISSIMO')) {
		$logger->debug(__PACKAGE__ . ".$sub_name Not using the username and password for $self->{TYPE} connection");
	    }
	    # added for NAVTEL
	    elsif (($self->{OBJ_PORT} == 23)&&($self->{TYPE} eq 'SonusQA::NAVTEL')) {
		$logger->debug(__PACKAGE__ . ".$sub_name  using the username \'$self->{OBJ_USER}\' and password \'\$self->{OBJ_PASSWORD}\' for $self->{TYPE} connection");

                unless ( $telObj->login(
                                        Name     => $self->{OBJ_USER},
                                        Password => $self->{OBJ_PASSWORD},
                                        Prompt   => $self->{PROMPT},
                                    ) ) {
                    $logger->warn(__PACKAGE__ . " .$sub_name [$self->{OBJ_HOST}] Net::Telnet->login() failed");
                    $failures += $failures_threshold; 
                    last;
                }
	    }
	    else
	    {
                unless ( $telObj->login($self->{OBJ_USER},$self->{OBJ_PASSWORD}) ) {
                    $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Net::Telnet->login() failed");
                    $failures += 1; 
                    next;
                }
            }
            
            $self->{conn} = $telObj;
            if($self->can("setSystem")){
                $logger->info(__PACKAGE__ . ".$sub_name object type is $self->{TYPE}, validating return value of setSystem");
                unless ($self->setSystem(%args)) {
                    $logger->warn(__PACKAGE__ . ".$sub_name setSystem() of class $self->{TYPE} is failed");
                    $failures += $failures_threshold;
                }
            }
            
            last; # We must have connected; exit the loop
            
        }elsif($self->{COMM_TYPE} eq 'SSH' or $self->{COMM_TYPE} eq 'NETCONF') {

            # scongdon: adding port option

            if ( $self->{OBJ_PORT} and ($self->{OBJ_PORT} != 23)) {
                $logger->info(__PACKAGE__ . ".$sub_name PORT set to $self->{OBJ_PORT}");
            }
            else {
                $self->{OBJ_PORT} = 22;
                $logger->info(__PACKAGE__ . ".$sub_name PORT not set, using default (22)");
            }

        # We rely on the 'Permission denied...' output from SSH later, if the user has a ~/.ssh/config which sets the Log-level to QUIET - this is never output and we break, force it here.
	    if($self->{COMM_TYPE} eq 'NETCONF') {
	            @cmd = ('ssh','-o','LogLevel=INFO','-o','UserKnownHostsFile=/dev/null','-o','StrictHostKeyChecking=no','-l', $self->{OBJ_USER}, $self->{OBJ_HOST}, '-p', $self->{OBJ_PORT}, '-s', 'netconf');
	    } else { 
	            @cmd = ('ssh','-o','LogLevel=INFO','-o','UserKnownHostsFile=/dev/null','-o','StrictHostKeyChecking=no','-l', $self->{OBJ_USER}, $self->{OBJ_HOST}, '-p', $self->{OBJ_PORT});
                    push (@cmd, '-b', $self->{LOCALHOST}) if ($self->{LOCALHOST}); #userdefined local ipadress
		    if ($self->{OBJ_KEY_FILE}) {
                       $logger->debug(__PACKAGE__ . ".$sub_name: logging in using key file");
                        push (@cmd, '-i', $self->{OBJ_KEY_FILE});
                        `chmod 600 $self->{OBJ_KEY_FILE}`; #change the permission of the private key file
                    }
                    #TOOLS-71291
                    if (exists $self->{EXTRA_SSH_OPTIONS} && @{$self->{EXTRA_SSH_OPTIONS}}) {
                        $logger->debug(__PACKAGE__ . ".$sub_name: adding extra options @{$self->{EXTRA_SSH_OPTIONS}}");
                        push (@cmd, @{$self->{EXTRA_SSH_OPTIONS}});
                    }
	    }

            my $pty = $self->spawnPty(\@cmd);

            unless ( $pty ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Failed to create a pty object");
                $failures += 1;
                next;
            }

            if( $self->{SESSIONLOG} ) {
                $telObj = new Net::Telnet (-fhopen => $pty,
                                        -prompt => $self->{PROMPT},
                                        -telnetmode => 0,
                                        -binmode=> 0,  # setting this to 1 added a weird character to the end of each line.
                                        -cmd_remove_mode => 1,
                                        -output_record_separator => "\r",
                                        -Timeout => $self->{DEFAULTTIMEOUT},
                                        -Errmode => "return",
                                        -Dump_log => $self->{sessionLog1},
                                        -Input_log => $self->{sessionLog2},
                                        );
            } else {
                $telObj = new Net::Telnet (-fhopen => $pty,
                                        -prompt => $self->{PROMPT},
                                        -telnetmode => 0,
                                        -binmode=> 0,  # setting this to 1 added a weird character to the end of each line.
                                        -cmd_remove_mode => 1,
                                        -output_record_separator => "\r",
                                        -Timeout => $self->{DEFAULTTIMEOUT},
                                        -Errmode => "return"
                                        );
            }


            unless ( $telObj ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Failed to create a session object");
                $failures += 1;
                next;
            }
           
# The following 3 lines have been added as a fix for CQ SONUS00154019. The maximum buffer size has been increased to 50 MB from 1 MB.
   my $len_buf;
   my $cur_len_buf = 52428800;
   $len_buf=$telObj->max_buffer_length($cur_len_buf);

            unless ( ($prematch, $match) = $telObj->waitfor(-match => '/connection refused/i',
                                                            -match => '/unknown host/i',
                                                            -match => '/name or service not known/i',
                                                            -match => '/connection reset/i',
                                                            -match => '/no route to host/i',
                                                            -match => '/Enter passphrase for key/i',
                                                            -match => '/yes\/no/i',
                                                            -match => '/[P|p]assword: ?$/i',
                                                            -match => $self->{PROMPT},
							    -match => '/Host key verification failed/',
							    -match => '/Permanently added.+to the list of known hosts/i',
                                                            -errmode => "return") ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get one of expected patterns: " . $telObj->lastline);
                $failures += 1;
                next;
            }
            
            if ( $match =~ /Enter passphrase for key/i ) {
            	$logger->info(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Key with passphrase encountered - sending blank");
		$telObj->print("");
                unless ( ($prematch, $match) = $telObj->waitfor(-match => '/[P|p]assword:\s*$/i', -match => $self->{PROMPT}, -errmode => "return") ) {
                    $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get either password prompt or '$self->{PROMPT}'" . $telObj->lastline);
                    $failures += 1;
                    next;
                }   
            }
            	                

            if ( $match =~ m/connection refused/i or $match =~ m/unknown host/i or $match =~ m/name or service not known/i  or $match =~ m/connection reset/i or $match =~ m/no route to host/i) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Connection failed: " . $telObj->lastline);
                $failures += 1;
                next;
            }   

            if($match =~ m/yes\/no/i){
                $logger->info(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] RSA encountered - entering 'yes'");
                $telObj->print("yes");
                unless ( ($prematch, $match) = $telObj->waitfor(-match => '/[P|p]assword:\s*$/i', -match => $self->{PROMPT}, -errmode => "return") ) {
                    $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get either password prompt or '$self->{PROMPT}'" . $telObj->lastline);
                    $failures += 1;
                    next;
                }   
            }

            # Ensure that the | in the banner is not mistaken as the prompt. This happens sometimes when there is a slight delay
            # in getting the password prompt and hence the connection is not established.
            # Added # also for the banner check to fix TOOLS-4296

            my $waitfor_password = 1;
WAITFOR_PASSWORD:

            if (($match =~ m/(\|.*\|)|(#.*#)|(%.*%)/) or ($match =~ m/Permanently added/i)) { 
		#using 1. banner %.*% as software upgrade line comes in it,
		 #     2. Permanently added because it might come as the first line after logging in.
                $logger->info(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Waiting for the password prompt...");
                unless ( ($prematch, $match) = $telObj->waitfor(-match => '/[P|p]assword:\s*$/i', -match => $self->{PROMPT}, -match => '/yes\/no/i', -errmode => "return") ) {
                    $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get either password prompt or '$self->{PROMPT}'" . $telObj->lastline);
                    $failures += 1;
                    next;
                }
                goto BANNER_ACK if ($match =~ /yes\/no/i and defined $self->{BANNER_ACK});

                #go back to 'WAITFOR_PASSWORD' to check whether we got the match correctly or still in banner (Fix for TOOLS-3877)
                goto WAITFOR_PASSWORD;
            }

            if($match =~ m/[P|p]assword:\s*$/i){
		delete $SSH_KEYS{$self->{OBJ_HOST}}{$self->{OBJ_USER}};
                my @banner_before_passwd = split ("\n", $prematch);
                chomp @banner_before_passwd;
                @banner_before_passwd = grep /\S/,  @banner_before_passwd;
                $self->{BANNER_BEFORE_PASSWD} = \@banner_before_passwd;
                $telObj->print($self->{OBJ_PASSWORD});
                unless ( ($prematch, $match) = $telObj->waitfor(-match => $self->{PROMPT}, -match => '/yes\/no/i', -match => '/Your password has expired/i', -match => '/Permission denied/i', -match => '/You are required to change your password immediately/i', -match =>'/.*[\$#%>] $/', -match =>'/Press any key to continue/i', -match =>'/Access denied/i', -errmode => "return") ) {#TOOLS-11525
                    $logger->error(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get prompt '$self->{PROMPT}' or '/.*[\$#%>] \$/'. ERROR: " . $telObj->lastline);
                    $failures += $failures_threshold;
                    last;
                }
CHANGE_PASSWORD:
                if ($match =~ m/(Your password has expired|You are required to change your password immediately)/i){
                    $self->{SBC_NEWUSER_4_1} = 1; #Post 4.1 the sbc will ask a newly created user to change the password even before getting the first prompt
		    my $newpassword;
		    if( $self->{OBJ_USER} =~ /admin/ and $self->{OBJ_NEW_PASSWORD} =~ /admin/){ 
			$logger->warn(__PACKAGE__ . ".$sub_name: The attribute value for {LOGIN}->{1}->{PASSWD} on the TMS is \'admin\'. This cannot be used as the new password. Hence, we are setting the new password to \'Sonus\@123\' ");
			$logger->warn(__PACKAGE__ . ".$sub_name: Edit the attribute value for {LOGIN}->{1}->{PASSWD} on the TMS in case you don't want to use \'Sonus\@123\' as the new password");
			$newpassword = "Sonus\@123";
		    }elsif($match =~ m/You are required to change your password immediately/i){
                        if( $self->{OBJ_USER} =~ /ssuser/ and $self->{OBJ_NEW_PASSWORD} =~ /ssuser/){
                            $logger->warn(__PACKAGE__ . ".$sub_name: The attribute value for {LOGIN}->{1}->{PASSWD} on the TMS is \'ssuser\'. This cannot be used as the new password. Hence, we are setting the new password to \'SONUS\@123\' ");
                            $logger->warn(__PACKAGE__ . ".$sub_name: Edit the attribute value for {LOGIN}->{1}->{PASSWD} on the TMS in case you don't want to use \'SONUS\@123\' as the new password");
                            $newpassword = "SONUS\@123";
                        }elsif( $self->{OBJ_USER} =~ /root/ and $self->{OBJ_NEW_PASSWORD} =~ /sonus/){
                            $logger->warn(__PACKAGE__ . ".$sub_name: The attribute value for {LOGIN}->{1}->{PASSWD} on the TMS is \'sonus\'. This cannot be used as the new password. Hence, we are setting the new password to \'l0ngP\@ss\' ");
                            $logger->warn(__PACKAGE__ . ".$sub_name: Edit the attribute value for {LOGIN}->{1}->{PASSWD} on the TMS in case you don't want to use \'l0ngP\@ss\' as the new password");
                            $newpassword = "l0ngP\@ss";
                        }
                    } 
		    $newpassword ||= $self->{OBJ_NEW_PASSWORD};
		   
		    if ( defined $args{-newpassword}){
			$newpassword =  $args{-newpassword};
			$logger->debug(__PACKAGE__ . ".$sub_name: NEW PASSWORD OVERRIDE - Using \$args{-newpassword} as the new password. This was passed as an argument '-newpassword' to newFromAlias"); 
		    }
		    elsif ($self->{OBJ_PASSWORD} eq $newpassword and $self->{TMS_ALIAS_DATA}->{LOGIN}->{2}->{PASSWD}) {
                        $logger->warn(__PACKAGE__ . ".$sub_name: The old password and new password are same. This cannot be used as the new password. Hence, we are setting the new password to {LOGIN}->{2}->{PASSWD}");
                        $newpassword = $self->{TMS_ALIAS_DATA}->{LOGIN}->{2}->{PASSWD};
                    }
                    $logger->debug(__PACKAGE__ . ".$sub_name: Changing the password.. Old Password: \$self->{OBJ_PASSWORD} New Password: \$newpassword ");
                    tie (my %print, "Tie::IxHash");
                    %print = ( '(Enter old|UNIX) password:' => $self->{OBJ_PASSWORD}, 'new password:' => $newpassword, '(Re-enter|Retype) new password:' => $newpassword);
CHANGE_PASSWD: #TOOLS-17278
                    my ($prematch, $match) = ('','');
                    foreach (keys %print) {
                        unless ( ($prematch, $match) = $telObj->waitfor(-match => "/$_/i", -match =>$self->{PROMPT}, -timeout   => $self->{DEFAULTTIMEOUT})) {
                            $logger->error(__PACKAGE__ . ".$sub_name: dint match for expected match -> $_ ,prematch ->  $prematch,  match ->$match");
                            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                            return 0;
                        }
                        if ($match =~ /$_/i) {
                            $logger->info(__PACKAGE__ . ".$sub_name: matched for $_, passing $print{$_} argument");
                            $telObj->print($print{$_});
                        } else {
                            $logger->error(__PACKAGE__ . ".$sub_name: dint match for expected prompt $_");
                            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                            return 0;
                        }
                    }
#TOOLS-17278 - Added support for 'failed to commit new password'
                    unless ( ($prematch, $match) = $telObj->waitfor(-match =>$self->{PROMPT}, -match => '/Password mismatch/i', -match => '/bad password/i', -match => '/failed to commit new password/', -timeout   => $self->{DEFAULTTIMEOUT})) {
                        if(grep(/Connection to $self->{OBJ_HOST} closed/i , ${$telObj->buffer})){
                            unless($self->reconnect()){
                                $logger->error(__PACKAGE__ . ".$sub_name: Unable to reconnect");
                                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                                return 0;
                            }
                            else{
                                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
                                return 1;
                            }
                        }
                        else{
                                $logger->error(__PACKAGE__ . ".$sub_name: Didn't receive an expected msg after changing the password , prematch ->  '$prematch',  match ->'$match' '".${$telObj->buffer}."'");
                                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                                return 0;
                        }
                    }
		    if( $match =~ /bad password/i ){
	                if( defined $ENV{CMDERRORFLAG} &&  $ENV{CMDERRORFLAG} ) {
                	    $logger->warn(__PACKAGE__ . ". $sub_name: CMDERRORFLAG flag set -CALLING ERROR ");
                	    &error("Failure in resetting the password: $match  ${$telObj->buffer} ");
            		} else {
                            $logger->error(__PACKAGE__ . ".$sub_name: Failure in resetting the password. $match  ${$telObj->buffer}");
                            $logger->info(__PACKAGE__ . ".$sub_name: Use a password that meets the above criteria and retry ");
		    	    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]"); 
		    	    return 0;
		    	}
                    }elsif ($match =~ /Password mismatch/i) {
                        $logger->error(__PACKAGE__ . ".$sub_name: Password mismatch");
                        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                        return 0;
                    }elsif ($match =~ /failed to commit new password/i) {#TOOLS-17278
                        $logger->debug(__PACKAGE__ . ".$sub_name: Got [$match] as match, so trying again after sleep of 15s..");
                        sleep 15;
                        goto CHANGE_PASSWD;
                    }elsif($prematch !~ /(password has been changed|password updated successfully)/i){
                        $logger->error(__PACKAGE__ . ".$sub_name: Did not get the expected pattern after password change");
                        $logger->info(__PACKAGE__ . ".$sub_name: prematch ->  $prematch,  match ->$match");
                        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                        return 0;
                    }
                    $logger->info(__PACKAGE__ . ".$sub_name: Password changed successfully.");
                    $self->{OBJ_OLD_PASSWORD} = $self->{OBJ_PASSWORD};
                    $self->{OBJ_PASSWORD} = $newpassword;
                }
                elsif ($match =~ m/Press any key to continue/i){   #TOOLS-11525
                    $logger->debug(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] sending enter, match: $match ");
                    $telObj->print();
                    unless ( ($prematch, $match) = $telObj->waitfor(-match =>'/.*[\$#%>].*/', -errmode => "return") ) {
                        $logger->error(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get prompt. ERROR: " . $telObj->lastline);
                        $failures += $failures_threshold;
                        last;
                    }
                }
            }

BANNER_ACK:
        my @banner;
        if(defined($self->{EXTRABANNER}) && ($self->{EXTRABANNER} == 1)){ # CQ SONUS00155022 This is performed only for SBC
        @banner = split ("\n", $prematch);
            while(1){
                my @gettrail;
                last unless(@gettrail = $telObj->getlines(All => "", Timeout=> 1));
                push (@banner, @gettrail);
            }  
        }
        else{
        @banner = split ("\n", $prematch);
        push (@banner, $match);
        }
        if ($match =~ /yes\/no/i and defined $self->{BANNER_ACK})  {
            $telObj->print($self->{BANNER_ACK});
            unless ( ($prematch, $match) = $telObj->waitfor(-match => $self->{PROMPT}, -errmode => "return") ) {
                $logger->error(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get prompt '$self->{PROMPT}' after banner acknowledgement . ERROR: " . $telObj->lastline);
                $failures += $failures_threshold;
                last;
            }
            push (@banner, split("\n", $prematch), $match);
            $logger->info(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] sent $self->{BANNER_ACK} for banner acknowledgement");
            if($match =~/Your password has expired/i){
                $logger->debug(__PACKAGE__ . ".$sub_name goto CHANGE_PASSWORD, since match is password has expired ($match) after banner acknowledgement");
                goto CHANGE_PASSWORD;
            }
        } elsif ($match =~ /yes\/no/i) {
            $logger->error(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}], unexpected banner acknowledgement apeared . ERROR: " . $telObj->lastline);
            $failures += $failures_threshold;
            last;
        }

        chomp @banner;
        @banner = grep /\S/,  @banner;
        $self->{BANNER} = \@banner;

        # If we get the sessions exceeded message - it is still proceeded by a prompt, and /then/ a connection closed message. e.g.
        #
        # admin connected from 10.2.203.109 using ssh on sbx35.eng.sonusnet.com
        # The number of allowed sessions has been exceeded. End an existing session and try logging in again.
        # Your last successful login was at 2013-9-23 9:32:33
        # Your last successful login was from 10.2.203.109
        # admin@sbx35> Connection to 10.6.82.55 closed.
        #
        # Thus - we give the 'banner' special treatment in this case - and warn the user explicitly that this connection failed.
        
        if ( grep {/The number of allowed sessions has been exceeded/} @banner ) { # This is CSPS specific, but has to be handled here in Base as it is returned prior to the PROMPT
            $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Connection failed: Target Device indicates maximum number of sessions reached.");
            $failures += $failures_threshold;  # We are unable to continue at this point - the user has to close some sessions (or restart the device).
            last;
        }
	    
	    # Since we no longer consider the user known_hosts file when connecting via ssh - something went *very* wrong if we hit this... bail...
	    if ( $match =~ /Host key verification failed/) {
		$logger->logdie(__PACKAGE__ ." $sub_name [$self->{OBJ_HOST}] !!! THIS SHOULD NEVER OCCUR - Not wiping your ~/.ssh/known_hosts, please file a TOOLS bug @ mlashley with the full logs.");
	    }
            if ( $match =~ /Permission denied/i ) {
                $logger->error(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get prompt '$self->{PROMPT}' or '/.*[\$#%>] \$/'. ERROR: " . $telObj->lastline);
                $logger->warn(__PACKAGE__ . ".$sub_name Trying to match the prompt again");
		unless ( ($prematch, $match) = $telObj->waitfor(-match => $self->{PROMPT}, -match => '/password:\s*$/i')){                    #Fix for TOOLS-11527
                    $logger->error(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get either of the prompts $self->{PROMPT} or password:.");
		    $failures += $failures_threshold;
		    last;
                }
                if($match =~ m/password:\s*$/i){
                    $logger->warn(__PACKAGE__ ." $sub_name [$self->{OBJ_HOST}] Login failed with password : [$self->{OBJ_PASSWORD}].");
                    unless(@retry_passwd){ #TOOLS-17440
                        $failures += $failures_threshold;
                        last;
                    }
                    $self->{OBJ_PASSWORD} = shift @retry_passwd; #TOOLS-16731
                    $logger->warn(__PACKAGE__ ." $sub_name [$self->{OBJ_HOST}] Let's try with password : [$self->{OBJ_PASSWORD}] ");
                    goto WAITFOR_PASSWORD;
                }
            }

            #Fix for TOOLS-19851
            for (1 .. 5){
                last if($match =~/$self->{OBJ_USER}/i);
                $logger->info(__PACKAGE__ . ".$sub_name [$_] didn't get user ($self->{OBJ_USER}) in the match, so waiting for prompt ($self->{PROMPT}) again");
                $logger->debug(__PACKAGE__ . ".$sub_name  prematch: $prematch, match: $match");
                unless(($prematch, $match) = $telObj->waitfor(-match => $self->{PROMPT}, -match => '/password:\s*$/i', Timeout => 2)){
                    $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get prompt '$self->{PROMPT}' or 'password:'. lastline: " . $telObj->lastline);
                    last;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name after waitfor '$self->{PROMPT}' or 'password:' : prematch: $prematch, match: $match");
                if($waitfor_password && $match=~/password/i){
                        $logger->debug(__PACKAGE__ . ".$sub_name Got password prompt, goto WAITFOR_PASSWORD to enter password");
                        $waitfor_password = 0;
                        goto WAITFOR_PASSWORD;
                }
            }
 
            $self->{conn} = $telObj;
            if($self->can("setSystem")){
                $logger->info(__PACKAGE__ . ".$sub_name object type is $self->{TYPE}, validating return value of setSystem");
                unless ($self->setSystem(%args)) {
                     $logger->warn(__PACKAGE__ . ".$sub_name setSystem() of class $self->{TYPE} is failed");
                     $failures += $failures_threshold;
                }
            }
            
            last; # We must have connected; exit the loop
            
        }elsif($self->{COMM_TYPE} eq 'FTP'){
            
            @cmd = ('ftp',$self->{OBJ_USER} . "@" . $self->{OBJ_HOST});
            if($self->{OBJ_PORT}){
                push(@cmd,$self->{OBJ_PORT});   
            }
	    if ($self->{OBJ_KEY_FILE}) {
                       $logger->debug(__PACKAGE__ . ".$sub_name: logging in using key file");
                        push (@cmd, '-i', $self->{OBJ_KEY_FILE});
                        `chmod 600 $self->{OBJ_KEY_FILE}`; #change the permission of the private key file
            }

            $self->{PROMPT} = '/.*ftp\>\s+$/';
            
            if( $self->{SESSIONLOG} ) {
                $telObj = new Net::Telnet (-fhopen => $self->spawnPty(\@cmd),
                                        -prompt => $self->{PROMPT},
                                        -telnetmode => 0,
                                        -cmd_remove_mode => 1,
                                        -output_record_separator => "\r",
                                        -Timeout => $self->{DEFAULTTIMEOUT},
                                        -Errmode => "return",
                                        -Dump_log => $self->{sessionLog1},
                                        -Input_log => $self->{sessionLog2},
                                        );
            } else {
                $telObj = new Net::Telnet (-fhopen => $self->spawnPty(\@cmd),
                                        -prompt => $self->{PROMPT},
                                        -telnetmode => 0,
                                        -cmd_remove_mode => 1,
                                        -output_record_separator => "\r",
                                        -Timeout => $self->{DEFAULTTIMEOUT},
                                        -Errmode => "return"
                                        );
            }

            unless ( $telObj ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Failed to create a session object");
                $failures += 1;
                next;
            }

            unless ( ($prematch, $match) = $telObj->waitfor(-match => '/connection refused/i',
                                                            -match => '/unknown host/i',
                                                            -match => '/name or service not known/i',
                                                            -match => '/connection reset/i',
                                                            -match => '/[P|p]assword: ?$/i',
                                                            -errmode => "return") ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get password prompt: " . $telObj->lastline);
                $failures += 1;
                next;
            }

            unless ( $match =~ /[P|p]assword: ?$/i  ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Connection failed: " . $telObj->lastline);
                $failures += 1;
                next;
            }   

            $telObj->print($self->{OBJ_PASSWORD});

            unless ( ($prematch, $match) = $telObj->waitfor(-match => '/530/i', -match => '/230/i', -errmode => "return") ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get login confirmation: " . $telObj->lastline);
                $failures += $failures_threshold;
                last;
            }   

            if ( $match =~ m/530/i ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Login failure: " . $telObj->lastline);
                $failures += $failures_threshold;
                last;
            }   

            unless ( $telObj->waitfor(-match => $self->{PROMPT}, -errmode => "return") ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get prompt '$self->{PROMPT}': " . $telObj->lastline);
                $failures += $failures_threshold;
                last;
            }   

            $self->{conn} = $telObj;
            
            last; # We must have connected; exit the loop
            
        }elsif($self->{COMM_TYPE} eq 'SFTP'){
            @cmd = ('sftp');
	    push (@cmd , '-o','UserKnownHostsFile=/dev/null','-o','StrictHostKeyChecking=no');
            if ( $self->{OBJ_PORT} ){
                $logger->info(__PACKAGE__ . ".$sub_name PORT set to $self->{OBJ_PORT}");
                push (@cmd, '-P', $self->{OBJ_PORT});
            }
 
            if ($self->{OBJ_KEY_FILE}) {
                $logger->info(__PACKAGE__ . ".$sub_name: logging in using key file, $self->{OBJ_KEY_FILE}");
                push (@cmd, '-i', $self->{OBJ_KEY_FILE});
                `chmod 600 $self->{OBJ_KEY_FILE}`; #change the permission of the private key file
            }
 
            push (@cmd, $self->{OBJ_USER} . "@" . $self->{OBJ_HOST});

            $self->{PROMPT} = '/.*sftp\>\s+$/';

            if( $self->{SESSIONLOG} ) {            
                $telObj = new Net::Telnet (-fhopen => $self->spawnPty(\@cmd),
                                        -prompt => $self->{PROMPT},
                                        -telnetmode => 0,
                                        -cmd_remove_mode => 1,
                                        -output_record_separator => "\r",
                                        -Timeout => $self->{DEFAULTTIMEOUT},
                                        -Errmode => "return",
                                        -Dump_log => $self->{sessionLog1}, 
                                        -Input_log => $self->{sessionLog2},
                                        );
            } else {
                $telObj = new Net::Telnet (-fhopen => $self->spawnPty(\@cmd),
                                        -prompt => $self->{PROMPT},
                                        -telnetmode => 0,
                                        -cmd_remove_mode => 1,
                                        -output_record_separator => "\r",
                                        -Timeout => $self->{DEFAULTTIMEOUT},
                                        -Errmode => "return"
                                        );
            }

            unless ( $telObj ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Failed to create a session object");
                $failures += 1;
                next;
            }
            unless ( ($prematch, $match) = $telObj->waitfor(-match => '/connection refused/i',
                                                            -match => '/unknown host/i',
                                                            -match => '/name or service not known/i',
                                                            -match => '/connection reset/i',
                                                            -match => '/yes\/no/i',
                                                            -match => '/[P|p]assword: ?$/i',
                                                            -match => $self->{PROMPT},
                                                            -errmode => "return") ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get one of expected patterns: " . $telObj->lastline);
                $failures += 1;
                next;
            }   

            if ( $match =~ m/connection refused/i or $match =~ m/unknown host/i or $match =~ m/name or service not known/i  or $match =~ m/connection reset/i ) {
                $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Connection failed: " . $telObj->lastline);
                $failures += 1;
                next;
            }   

            if($match =~ m/yes\/no/i){
                $logger->info(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] RSA encountered - entering 'yes'");
                $telObj->print("yes");
                unless ( ($prematch, $match) = $telObj->waitfor(-match => '/[P|p]assword: ?$/i', -match => $self->{PROMPT}, -errmode => "return") ) {
                    $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get either password prompt or '$self->{PROMPT}': " . $telObj->lastline);
                    $failures += 1;
                    next;
                }   
            }

            if($match =~ m/[P|p]assword:\s*$/i){
                $logger->info(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] password encountered - entering \$self->{OBJ_PASSWORD} ");
                $telObj->print($self->{OBJ_PASSWORD});
                unless ( $telObj->waitfor(-match => $self->{PROMPT}, -errmode => "return") ) {
                    $logger->warn(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Did not get prompt '$self->{PROMPT}': " . $telObj->lastline);
                    $failures += $failures_threshold;
                    last;
                }
            }
            
            $self->{conn} = $telObj;
            
            last; # We must have connected; exit the loop
            
        }else{
            &error(__PACKAGE__ . ".$sub_name spawn Invalid COMM_TYPE: $self->{COMM_TYPE}");
            last;
        }
    }

    if ( $failures >= $failures_threshold ) {
        $logger->error(__PACKAGE__ . ".$sub_name Failed to connect to host '$self->{OBJ_HOST}' using credentials: user '$self->{OBJ_USER}' password '\$self->{OBJ_PASSWORD}'");
 	my @userid = qx#id -un#;
	chomp @userid;
	if($self->{OBJ_USER} eq $userid[0] and $self->{OBJ_PASSWORD} eq "" ){
	    $logger->warn(__PACKAGE__ . ".$sub_name Password is not defined on the tms and the ssh keys are not set. Generate the ssh keys or set the password on the tms ");
	}
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");	
        return 0;
    }   
    
    $logger->info(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] Initial $self->{COMM_TYPE} session established");
    $logger->debug(__PACKAGE__ . ".$sub_name [$self->{OBJ_HOST}] CREDENTIALS: USER->$self->{OBJ_USER} PASSWORD->\$self->{OBJ_PASSWORD}");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 C< closeConn >
  
  $obj->closeConn();

=cut


sub closeConn {
    my ($self) = @_;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".closeConn");
    $logger->info(__PACKAGE__ . ".closeConn OBJ_HOST: $self->{OBJ_HOST} OBJ_PORT: $self->{OBJ_PORT} COMM_TYPE:$self->{COMM_TYPE}");

    unless (defined $self->{conn}) { $logger->warn(__PACKAGE__ . ".closeConn Called with undefined {conn} - OBJ_PORT: $self->{OBJ_PORT} COMM_TYPE:$self->{COMM_TYPE}"); return undef }
    ## ADDED for SPECTRA2:
    if( $self->{OBJ_PORT} == 10001) {
	$self->{conn}->cmd("Close");
    }

    if($self->{COMM_TYPE} eq 'SSH' and !$self->{ENTEREDCLI}){
       $logger->debug(__PACKAGE__ . ".closeConn - This is a console session - sending a couple of exits");
       $self->{conn}->cmd( -string => "exit", -timeout => 1);
       $self->{conn}->cmd( -string => "exit", -timeout => 1); # This likely won't get a prompt back - what is returned is device dependent - so we just reduce the timeout. (And there was no error checking originally anyway (since we are called from DESTROY - it makes little sense.)
       $self->{conn}->cmd( -string => "exit", -timeout => 1) if(exists $self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} and $self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} =~ /(PSX|EMS)/i);
    }
 
    if ( $self->{COMM_TYPE} eq 'FTP') {
        $self->{conn}->cmd( -string => 'bye', -prompt => '/Goodbye/' );
    }
 
    if ($self->{conn}) {
      $logger->debug(__PACKAGE__ . ".closeConn Closing Socket");
      $self->{conn}->close;
      undef $self->{conn}; #this is a proof that i closed the session
    }
    $logger->debug(__PACKAGE__ . ".closeConn - DONE!");
}



=head2 C< _COMMANDHISTORY >
 
  $obj->_COMMANDHISTORY();

=cut


sub _COMMANDHISTORY(){
    my($self)=@_;
    my(@history);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "._COMMANDHISTORY");
    @history = @{$self->{HISTORY}};
    if($#history > 0){
	#reverse @history;
	$logger->debug(__PACKAGE__ . "._COMMANDHISTORY  ********** BEGIN COMMAND HISTORY **************************");
	$logger->debug(__PACKAGE__ . "._COMMANDHISTORY  FOR OBJECT: ");
	$self->descSelf("debug");
	$logger->debug(__PACKAGE__ . "._COMMANDHISTORY  OBJECT COMMAND EXECUTION HISTORY:");
	while (@history) {
	    my $cmd = shift @history;
	    $logger->debug(__PACKAGE__ . "._COMMANDHISTORY  $cmd");
	}
	$logger->debug(__PACKAGE__ . "._COMMANDHISTORY  ********** END COMMAND HISTORY ****************************");
    }
}

=head2 C< getTime >

  $obj->getTime();

=cut


sub getTime(){
    use POSIX qw(strftime);
    return strftime "%Y/%m/%d %H:%M:%S", localtime;
}

=head2 C< DESTROY >
  
  $obj->DESTROY();

=cut


sub fetchCmdResults(){
    my($self)=@_;
    return @{$self->{CMDRESULTS}};
}


=head1 PERL default module method Over-rides:


=head2 C< DESTROY >
Typical inner library usage:
$obj->DESTROY();

=cut

sub DESTROY {
    my ($self)=@_;
    my ($logger);
    if(Log::Log4perl::initialized()){
      $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".DESTROY");
    }else{
      Log::Log4perl->easy_init($DEBUG);
      $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".DESTROY");
    }
    #if($self->can("gatherStats")){
    #   $self->gatherStats();
    #}
    if($self->can("_DUMPSTACK") && defined($self->{DUMPSTACK}) && $self->{DUMPSTACK}){
	$self->_DUMPSTACK();
    }else{
	 $logger->debug(__PACKAGE__ . ".DESTROY  OBJECT DOES NOT HAVE DUMPSTACK METHOD (OR NO HISTORY IS AVAILABLE)");
    }
    if($self->can("_REVERSESTACK")  && defined($self->{STACK}) && @{$self->{STACK}}){
	$self->_REVERSESTACK();
    }else{
	 $logger->debug(__PACKAGE__ . ".DESTROY  OBJECT DOES NOT HAVE REVERSESTACK METHOD (OR NO HISTORY IS AVAILABLE)");
    }
    
    if($self->can("_COMMANDHISTORY") && defined($self->{HISTORY}) && @{$self->{HISTORY}}){
	$self->_COMMANDHISTORY();
    }else{
	 $logger->debug(__PACKAGE__ . ".DESTROY  OBJECT DOES NOT HAVE COMMANDHISTORY METHOD (OR NO HISTORY IS AVAILABLE)");
    }
    
    if($self->can("resetNode")){
	$self->resetNode();
    }
    $logger->info(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Cleaning up...");
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroying object");
    $self->closeConn();
    $self->{"CE0LinuxObj"}->closeConn() if(defined ($self->{"CE0LinuxObj"}) and !$self->{D_SBC});  

    delete $vm_ctrl_obj{$self->{TMS_ALIAS_DATA}->{ALIAS_NAME}} if (exists $vm_ctrl_obj{$self->{TMS_ALIAS_DATA}->{ALIAS_NAME}});

    my $vmCtrlAlias = $self->{TMS_ALIAS_DATA}->{VM_CTRL}->{2}->{NAME} ||  $self->{TMS_ALIAS_DATA}->{VM_CTRL}->{1}->{NAME}; #TOOLS-12934
    my $vmCtrlMaster = $self->{TMS_ALIAS_DATA}->{VM_CTRL}->{1}->{NAME};

    #TOOLS-71159 : $main::TESTSUITE for startAutomation and other for STARTxxxAUTOMATION
    $main::BISTQ_LAST_SUITE ||= $main::TESTSUITE->{BISTQ_LAST_SUITE};
    $logger->debug(__PACKAGE__ . ".DESTROY CE_NAME: $self->{CE_NAME}, DO_NOT_DELETE: $self->{DO_NOT_DELETE}, BISTQ_LAST_SUITE: $main::BISTQ_LAST_SUITE, job_uuid: $main::job_uuid");
    if ( $vmCtrlAlias && !$self->{DO_NOT_DELETE} && $main::BISTQ_LAST_SUITE ne 'N') {
        my $delete_success = 0 ;
        if ($self->{TMS_ALIAS_DATA}->{VM_CTRL}->{1}->{TYPE} eq "IAC") {
            $delete_success = $vm_ctrl_obj{$vmCtrlAlias}->deleteInstance( -mgmtip_list => [$self->{OBJ_HOST}]);
        }else {
            $self->{DELETE_CINDER} = 1 unless(exists $self->{DELETE_CINDER}); #TOOLS-75900 - setting default as 1, pass 0 for override it
            $delete_success = $vm_ctrl_obj{$vmCtrlAlias}->deleteInstance($self->{'CE_NAME'}, $self->{DELETE_CINDER}) if( $self->{CE_NAME} && (-e "/home/$ENV{ USER }/ats_user/logs/.$self->{CE_NAME}_$main::job_uuid"));
            $delete_success = $vm_ctrl_obj{$vmCtrlMaster}->deleteInstance($self->{TMS_ALIAS_DATA}->{MASTER}->{1}->{NAME}, $self->{DELETE_CINDER}) if(exists $self->{TMS_ALIAS_DATA}->{MASTER} && $self->{TMS_ALIAS_DATA}->{MASTER}->{1}->{NAME} && -e "/home/$ENV{ USER }/ats_user/logs/.$self->{TMS_ALIAS_DATA}->{MASTER}->{1}->{NAME}_$main::job_uuid");
        }
        $main::TESTBED{$main::TESTBED{$self->{TMS_ALIAS_NAME}}.":hash"}->{RESOLVE_CLOUD} = 0  if($delete_success);
    }

    if($self->{TMS_ALIAS_DATA}->{__OBJTYPE} eq 'EMS' && $self->{PSX_ALIAS} && $main::TESTBED{'FC_CLEANUP'} && -e "/home/$ENV{ USER }/ats_user/logs/.$self->{PSX_ALIAS}_$main::job_uuid"){ 
        #CAll unregisterPSXNode only if object type is EMS and its a cloud PSX.	
	my @nodes = ($self->{PSX_ALIAS});
        push(@nodes,$self->{OBJ_TARGET}) if($self->{OBJ_TARGET} && $self->{PSX_ALIAS} ne $self->{OBJ_TARGET} && -e "/home/$ENV{ USER }/ats_user/logs/.$self->{OBJ_TARGET}_$main::job_uuid");
	$self->unregisterPSXNode();
    }
    $logger->debug(__PACKAGE__ . ".DESTROY [$self->{OBJ_HOST}] Destroyed object");
}

=head2 C< AUTOLOAD >
  
  $obj->AUTOLOAD();

=cut

sub AUTOLOAD {
  our $AUTOLOAD;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $AUTOLOAD );
  $logger->warn(__PACKAGE__ . $AUTOLOAD . "  ATTEMPT TO CALL $AUTOLOAD FAILED (POSSIBLY INVALID METHOD");
}

=head2 C< clone > 
  
  $obj->clone();

=cut

sub clone {
  my $self = shift;
  bless { %$self }, ref $self;
}


=head2 C< listMethods >
  
  $obj->listMethods(<string: object type, string: version);

=cut

sub listMethods {
    my($self, $objType, $version)=@_;
    my ($logger);
    if(Log::Log4perl::initialized()){
      $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".listMethods");
    }else{
      $logger = Log::Log4perl->easy_init($DEBUG);
    }
    if(!defined($objType)){
        $logger->warn(__PACKAGE__ . ".listMethods  OBJECT TYPE REQUIRED - PLEASE SUPPLY");
    }
    if(!defined($version)){
        $logger->warn(__PACKAGE__ . ".listMethods  VERSION REQUIRED - PLEASE SUPPLY ");
    }
    
}

sub getLog {
  my ($self, $logPath)=@_;
  my (@cmdResults, $cmd, $logger, $line, $bsize, $asize,$i,@log,$len);
  @cmdResults = ();

  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getLog");
  if(!defined($logPath)){
    $logger->warn(__PACKAGE__ . ".getLog  PATH MISSING OR NOT DEFINED - REQUIRED");
    return 0;
  }
  $bsize = $self->_sessFileExists($logPath);
  $i = 0;
  while (($i < 12) && (!defined($bsize))) {
        $logger->warn(__PACKAGE__ . ".getLog  $logPath DOES NOT SEEM TO EXIST, WAITING 10 SECONDS");
        sleep(10);
        $bsize = $self->_sessFileExists($logPath);
        $i++;
  }

  if(!defined($bsize)){
      $logger->warn(__PACKAGE__ . ".getLog  $logPath DOES NOT SEEM TO EXIST");
      # means that there was no need for removal
      return @cmdResults;
  }

  $logger->info(__PACKAGE__ . ".getLog  RETRIEVING FILE CONTENTS");
  @log = $self->{conn}->cmd(String => "/bin/cat $logPath", Timeout => 120 , errmode => "return");
  $len = @log;
  $logger->info(__PACKAGE__ . ".getLog  length of array = $len ");

  my @output = grep(/$logPath/, @log);
  $len = @output;
  $i = 0;
  while (($len != 0) && ($i<12)) {
          $logger->warn(__PACKAGE__ . ".getLog  FILE STILL BEING WRITTEN, WAITING 10 SECONDS");
          sleep(10);
          @log = $self->{conn}->cmd(String => "/bin/cat $logPath", Timeout => 120 , errmode => "return");
          @output = grep(/$logPath/, @log);
          $len = @output;
          $i++;
  }

  chomp(@log);
  return @log;
}

END {
    foreach(@cleanup){
      $_->DESTROY() if (defined($_) and defined $_->{conn}); #why should i call DESTROY if session is already closed
    }

    # archiving the logs, $ENV{ARCHIVE_CMD} has set fron SonusQA::HARNESS::runTestsinSuite()
    `$ENV{ARCHIVE_CMD}` if($ENV{ARCHIVE_CMD});
}

=pod

=head3 reconnect()

    This function reconnects the ATS object using its attributes 
    which were passed in during object instantiation.

Arguments :

    -retry_timeout => <maximum time to try reconnection (all attempts)>
    -conn_timeout  => <maximum time for each connection attempt>

Return Values :

   1 - success
   0 - otherwise

Example :
    $atsobj->reconnect()

Author :
 Nimit Sarup
 nsarup@sonusnet.com

=cut

sub reconnect
{
    my ($self,%args) = @_;
    my @cmdResult;
    my $sub = "reconnect()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($timeout, $t0, $connected, $temp_default_timeout);
    $logger->debug(__PACKAGE__ . ".$sub:  --> Entered Sub");
    $self->closeConn();
    $self->{"CE0LinuxObj"}->closeConn() if ( defined $self->{"CE0LinuxObj"} );

    $timeout   = 60;
    $connected = 0;
    if ( (!defined $args{-retry_timeout}) ||
          $args{-retry_timeout} =~ /^$/ ) {

        $logger->debug(__PACKAGE__ . ".$sub missing \"-retry_timeout\" value, continuing with default (60 secs).");
    }
    else {
        $timeout = $args{-retry_timeout};
    }

    if ( (!defined $args{-conn_timeout}) ||
          $args{-conn_timeout} !~ /^[1-9][0-9]+$/ ) {

        $logger->debug(__PACKAGE__ . ".$sub missing or invalid \"-conn_timeout\" value, continuing with default ($self->{DEFAULTTIMEOUT} secs).");
    }
    else {
        $temp_default_timeout = $self->{DEFAULTTIMEOUT};
        $logger->debug(__PACKAGE__ . ".$sub Setting \$self->{DEFAULTTIMEOUT} to connection timeout of '$args{-conn_timeout}'.");
        $self->{DEFAULTTIMEOUT} = $args{-conn_timeout};
    }
    
    $t0 = [gettimeofday];

    do
    {
        foreach ( @{$self->{OBJ_HOSTS}} ) {

            $self->{OBJ_HOST} = $_;
            $logger->debug(__PACKAGE__ . ".$sub Calling connect for $self->{OBJ_HOST}\n");

             if($self->{DEFAULTPROMPT}){
                $logger->debug(__PACKAGE__ . ".$sub Changing the prompt ($self->{PROMPT}) to default prompt ($self->{DEFAULTPROMPT})");
                $self->{PROMPT} = $self->{DEFAULTPROMPT};
            }
            else{
                $logger->warn(__PACKAGE__ . ".$sub DEFAULTPROMPT is not set. So can't change the prompt ($self->{PROMPT}) to default prompt");
            }
            $self->{RE_CONNECTION} = 1;
            if ( $self->connect() ) {

                $connected = 1;
                last;
            }
        }

        if( $connected == 0 ) {

            $logger->info(__PACKAGE__ . ".$sub retrying connections.");
        }
    } while( ($connected == 0) && (tv_interval($t0) <= $timeout) );

    if (defined($temp_default_timeout)) {
        $logger->debug(__PACKAGE__ . ".$sub Resetting \$self->{DEFAULTTIMEOUT} to original value of '$temp_default_timeout'.");
        $self->{DEFAULTTIMEOUT} = $temp_default_timeout;
    }
    
    unless($connected)
    {
        if ( $self->{RETURN_ON_FAIL} ) {
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]"); 
            return 0;
        }
        else {
            &error(__PACKAGE__ . ".$sub Failed to re-connect");
        }
    }

    if($self->{'UNHIDE_DEBUG_SET'}){
        unless ( $self->unhideDebug ($self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD} || 'sonus1')) {
            $logger->error(__PACKAGE__ . ".$sub:  Cannot issue \'unhide debug\'");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=pod

=head3 getSessionLogInfo()
Description:
 This subroutine makes the sessionlog names and directory to put in the file

Arguments :
 -sessionLogInfo     => An empty hash reference
                        This will get filled in the sub with the following information
                        sessionInputLog => "/homes/ssukumaran/ats_user/logs/$type-$hostName-$timeStamp-sessionInput.log"
                        sessionDumpLog => "/homes/ssukumaran/ats_user/logs/$type-$hostName-$timeStamp-sessionDump.log"

Return Values :

   1 - success
   0 - otherwise

Example :
    $atsobj->getSessionLogInfo()

Author :

=cut

sub getSessionLogInfo {
   my ($self, %args) = @_;
   my %a;
   my $sub = "getSessionLogInfo()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

   # get the arguments
   while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

   $logger->info(__PACKAGE__ . ".$sub Entering sub");

   my $userHomeDir;
   my $userName;

   # System
   if ( $ENV{ HOME } ) {
      $userHomeDir = $ENV{ HOME };
   } else {
      $userName = $ENV{ USER };
      if ( system( "ls /home/$userName/ > /dev/null" ) == 0 ) { #to run silently, redirecting the output to /dev/null
         $userHomeDir   = "/home/$userName";
      } elsif ( system( "ls /export/home/$userName/ > /dev/null" ) == 0 ) { #to run silently, redirecting the output to /dev/null
         $userHomeDir   = "/export/home/$userName";
      } else {
         $logger->error(__PACKAGE__ . ".$sub *** Could not establish users home directory... using /tmp ***");
         $userHomeDir = "/tmp";
      }
   }

   # set the log dir
   my $logDir = "$userHomeDir/ats_user/logs";
   $logDir = $ENV{SESSION_DIR} if (defined $ENV{SESSION_DIR} and $ENV{SESSION_DIR});

   unless ( system ( "mkdir -p $logDir" ) == 0 ) {
      $logger->error(__PACKAGE__ . ".$sub *** Could not create user log directory in $userHomeDir/ ***");
      return 0;
   }

   # Create timestamp for automation run logs
   my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
   my $timeStamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;

   my $hostName = "UNKNOWN";
   my $devType = "UNKNOWN";
   if(defined ($self->{TYPE})) {
      my $tmpType = $self->{TYPE};
      if ($tmpType =~ m/SonusQA::(\S+)/){
         $devType = $1;
      }
   }

   if (defined ($self->{SYS_HOSTNAME})) {
      $hostName = $self->{SYS_HOSTNAME};
   }

   my $sessLogInfo = $a{-sessionLogInfo};
   #This below if condition is to include customised session name if $a{-sessionLogInfo} is anything other than 1 #TOOLS-4214
   if(defined($self->{SESSIONLOG}) and $self->{SESSIONLOG} =~/[^1]/){
       $hostName .="-$self->{SESSIONLOG}";
   }
   $sessLogInfo->{sessionInputLog} = "$logDir/$devType-$hostName-$timeStamp-sessionInput.log";
   $sessLogInfo->{sessionDumpLog} = "$logDir/$devType-$hostName-$timeStamp-sessionDump.log";

   return 1;
}

=pod

=head3 emsLogin()
Description: 
 This subroutine will login to given emsIp and provides the curl object.

Arguments :
 -emsIp                       => Ip of the EMS

Return Values :
   1 - success
   0 - Failur

Example :
    $self->emsLogin( -emsIp=> $emsip);

Author :

=cut

sub emsLogin {
    my ($self, %args) = @_;
	
    my $sub_name = "emsLogin";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    unless ( $args{-emsIp} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument EMS IP address input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
	
    $logger->info(__PACKAGE__ . ".$sub_name: creating curl object");
    $self->{curl} = new WWW::Curl::Easy;
    $self->{curl}->setopt(CURLOPT_TIMEOUT,120);
    $self->{curl}->setopt(CURLOPT_HEADER,1);
    $self->{curl}->setopt(CURLOPT_FOLLOWLOCATION,1);
    $self->{curl}->setopt(CURLOPT_AUTOREFERER,1);
    $self->{curl}->setopt(CURLOPT_USERAGENT,"curl/7.19.6 (x86_64-pc-linux-gnu) libcurl/7.19.6 OpenSSL/0.9.8k zlib/1.2.3");
    $self->{curl}->setopt(CURLOPT_SSL_VERIFYPEER, 0);
    $self->{curl}->setopt(CURLOPT_SSL_VERIFYHOST, 0);
    $self->{curl}->setopt(CURLOPT_PROXY,""); #Fix for TOOLS-10005
    # Store cookies in memory
    $self->{curl}->setopt(CURLOPT_COOKIEJAR,"-");
    $self->{curl}->setopt(CURLOPT_URL, "https://$args{-emsIp}/emxAuth/auth/getInfo");

    # Setup a variable to store our HTTP response data (rather than a file)
    $self->{curl_response_body} = undef;
    $self->{curl_file_handle} = undef;
    open ($self->{curl_file_handle} ,">", \$self->{curl_response_body});
    $self->{curl}->setopt(CURLOPT_WRITEDATA,$self->{curl_file_handle}); 
    my $retcode;
    my $https_check = 1; #In EMS 9.1, they have stopped supporting http for accessing the EMS GUI (https is used instead of http). So we have a flag to check the login using https if http fails on the first attempt. If this succeeds then we set $self->{HTTPS} = 1 and use this flag for setting CURLOPT_URL in the later curl operations.
    $self->{HTTPS} = 1;
    $logger->debug(__PACKAGE__ . ".$sub_name: Accessing EMS GUI using https.");

    $retcode = $self->{curl}->perform;
# For TOOLS - 20276
    my $version = ( $self->{curl_response_body} =~ /\"version\":\"([A-Z0-9\.]+)\"/) ? $1 : '' ;

    if ( SonusQA::Utils::greaterThanVersion( $version  , 'V12.00.00') ) {
        $self->{curl}->setopt(CURLOPT_URL, "https://$args{-emsIp}/");
    } else {
        $self->{curl}->setopt(CURLOPT_URL, "https://$args{-emsIp}/coreGui/ui/logon/launch.jsp");
    }

    LOGINBANNER:
    $retcode = $self->{curl}->perform;
    if ($retcode == 0) {
       $logger->debug(__PACKAGE__ . ".$sub_name : ====== Login Banner ======");

       my $response_code = $self->{curl}->getinfo(CURLINFO_HTTP_CODE);

       $logger->debug(__PACKAGE__ . ".$sub_name : Transfer went ok ($response_code)");

       # judge result and next action based on $response_code
       unless ($response_code == 200) {
          $logger->error(__PACKAGE__ . ".$sub_name : ERROR Expected 200 OK response - got $response_code");
          $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
          return 0;
       }
   } elsif($retcode == 7 and $https_check == 1){
       $self->{HTTPS} = 0;
       $self->{curl}->setopt(CURLOPT_URL, "http://$args{-emsIp}/coreGui/ui/logon/launch.jsp");
       $https_check = 0;
       $logger->debug(__PACKAGE__ . ".$sub_name: Unable to access EMS GUI using https. Trying http now.. ");
       goto LOGINBANNER;
   } else {
       $logger->error(__PACKAGE__ . ".$sub_name : Error in curl perform: " . $self->{curl}->strerror($retcode)." ($retcode)");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
   }

   # Provide login credentials
   $self->{curl}->setopt(CURLOPT_POST,1);
   $self->{curl}->setopt(CURLOPT_POSTFIELDS,'j_username=admin&j_password=admin&j_security_check=++Log+On++');
   $self->{curl}->setopt(CURLOPT_URL, "http://$args{-emsIp}/coreGui/ui/logon/j_security_check");
   $self->{curl}->setopt(CURLOPT_URL, "https://$args{-emsIp}/coreGui/ui/logon/j_security_check") if($self->{HTTPS});
   $retcode = $self->{curl}->perform;

   if ($retcode == 0) {
       $logger->debug(__PACKAGE__ . ".$sub_name :===== Login Credentials =======");
       my $response_code = $self->{curl}->getinfo(CURLINFO_HTTP_CODE);

       $logger->debug(__PACKAGE__ . ".$sub_name : Transfer went ok ($response_code)");

       # judge result and next action based on $response_code
       unless ($response_code == 200) {
           $logger->error(__PACKAGE__ . ".$sub_name : ERROR Expected 200 OK response - got $response_code");
           $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
           return 0;
       }
   } else {
       $logger->error(__PACKAGE__ . ".$sub_name : An error happened: ".$self->{curl}->strerror($retcode)." ($retcode)");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
       return 0;
   }
   return 1;
}

=pod

=head3 discoverNode()
DESCRIPTION:   
 This subroutine performs Device Discover in Insight Administartion section of EMS (EMS -> Insight Administration -> deviceType -> <deviceNameInEms> -> Discover).

Arguments :
   -emsIp                       => Ip of the EMS
   -deviceNameInEms             => Device Name in EMS
   -deviceType                  => Device Type (eg -> PSX, SGX4000) Default is SGX4000

Return Values :

   1 - success
   0 - Failur

Example :
    $self->discoverNode( -emsIp=> $emsip, -deviceNameInEms => 'abcd', -deviceType => 'SGX4000');

Author :

=cut

sub discoverNode {
    my ($self, %args) = @_;

    my $sub_name = "discoverNode";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");
    my %a   = ( -deviceType      => 'SGX4000' );

    # curl breaks our SIGINT handler - save it here to restore later. (Fix for TOOLS-2590)
    my $oldhandler = $SIG{INT};

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
	
    unless ( $a{-emsIp} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory EMS IP address input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $a{-deviceNameInEms} ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory sgx Name In Ems input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }	

    $a{-emsIp} = "[$a{-emsIp}]" if ($a{-emsIp} =~ m/:/); # TOOLS-15478 Added [] for ipv6 
    $logger->info(__PACKAGE__ . ".$sub_name: creating LWP user agent object");

    my $ua = LWP::UserAgent->new( keep_alive => 1);
    $ua->ssl_opts(verify_hostname => 0) if ($ua->can('ssl_opts'));
    $ua->ssl_opts( SSL_verify_mode => 0 ) if ($ua->can('ssl_opts'));

    my $cookie_jar = HTTP::Cookies->new( );
    $ua->cookie_jar( $cookie_jar );

    my $authorisation_value ;
    unless ( ( $ua, $cookie_jar , $authorisation_value) = SonusQA::ATSHELPER::loginToEMSGUI( $a{-emsIp} , 'admin', 'admin' , $ua , $cookie_jar ) )  {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to login to EMS");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my ($request , $response, $nodeid, $json, $decoded_json ) ;

    my $retry_attempt = 1;
    # EMS -> Insight Administration -> deviceType -> <SGX Name> -> Discover
        
    unless ( $authorisation_value) {
     RETRYDISCOVERY:
        unless($retry_attempt == 1) {
            $request = GET "http://$a{-emsIp}/nodeAdmin/NodeAdminServlet?op=getAllNodesByType" unless ($retry_attempt == 1) ;
        } else {
            $request = GET "https://$a{-emsIp}/nodeAdmin/NodeAdminServlet?op=getAllNodesByType" ;
        }
        $response = $ua->request( $request);
        unless ( $response->{_rc} == 200) { 
            if ($retry_attempt == 1) {
                $logger->warn(__PACKAGE__ . ".$sub_name : Retrying to get node ID.. ");
                $retry_attempt++;
                goto RETRYDISCOVERY;
            }else {
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }

        $json = $response->{_content};
        $decoded_json = decode_json( $json );

        foreach my $type (@{$decoded_json}) {
            if ($type->{'attr'}->{'typeName'} =~ /$a{-deviceType}/ ){
                foreach my $node (@{$type->{'children'}} ) {
        	    if($node->{'data'} eq $a{-deviceNameInEms}){
	                $nodeid = $node->{'attr'}->{'id'};
	                last;
        	    }
    	        }
                last;
            }
        }

        unless( $nodeid ) {
            $logger->debug(__PACKAGE__ . ".$sub_name : Device Type : $a{-deviceType}  Node Name : $a{-deviceNameInEms} ");
            $logger->debug(__PACKAGE__ . ".$sub_name : Response : ".Dumper($decoded_json));
            $logger->error(__PACKAGE__ . ".$sub_name : Unable to get node ID ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }

        my %form_fields = (
                           'node_type' => $a{-deviceType},
                           'nodeId' => $nodeid ,
                           'type' => $a{-deviceType},
                           'enabled' =>'true' ,
                           'cmd_discover' => ' Discover '
                          );
        unless ($retry_attempt == 1) {
            $request = POST "http://$a{-emsIp}/emsGui/jsp/admin/administration/nodeAdmin/nodeadmin.jsp" ,\%form_fields ;
        }else {
            $request = POST "https://$a{-emsIp}/emsGui/jsp/admin/administration/nodeAdmin/nodeadmin.jsp" ,\%form_fields  ;
        }
        $response = $ua->request( $request);
    }else {
        $request = GET "https://$a{-emsIp}/nodeMgmt/v1.0/nodes" ;
        $response = $ua->request( $request);
        $json = $response->{_content};
        $decoded_json = decode_json( $json );

        foreach my $node (@{$decoded_json->{'nodes'}}) {
            if($node->{'name'} eq $a{-deviceNameInEms}){
                $nodeid = $node->{'nodeId'};
                last;
            }
        }
  
        unless( $nodeid ) {
            $logger->debug(__PACKAGE__ . ".$sub_name : Device Type : $a{-deviceType}  Node Name : $a{-deviceNameInEms} ");
            $logger->debug(__PACKAGE__ . ".$sub_name : Response : ".Dumper($decoded_json));
            $logger->error(__PACKAGE__ . ".$sub_name : Unable to get node ID ");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        $request = PUT "https://$a{-emsIp}/nodeMgmt/v1.0/nodes/$nodeid/actions/discoverNode";
        $response = $ua->request( $request );
        print " \nresponse " .Dumper( $response);
    }

    $SIG{INT}=$oldhandler;

    my $discover_response = $response->{_rc} ;
    # judge result and next action based on $response_code
    if ($discover_response == 200) {
        $logger->info(__PACKAGE__ . ".$sub_name : Transfer went ok ($discover_response)");
    }else {
        $logger->debug(__PACKAGE__ . ".$sub_name : discover dump ".Dumper($response));
        $logger->error(__PACKAGE__ . ".$sub_name : ERROR Expected 200 OK response - got $discover_response");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    if ($a{-deviceType} =~ /SGX4000/i) {
        unless($self->execCliCmd('show table snmp trapTarget')) {
            $logger->error (__PACKAGE__ . ".$sub_name Failed to execute \'show table snmpTargetMib\' lets try \'show table SNMP-TARGET-MIB\'");
            unless($self->execCliCmd('show table SNMP-TARGET-MIB')) {
                $logger->error (__PACKAGE__ . ".$sub_name Failed to execute \'show table SNMP-TARGET-MIB\'");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }
        $logger->debug(__PACKAGE__ . ".$sub_name Output : " . Dumper ($self->{CMDRESULTS}));
    }

    # curl breaks our SIGINT handler - adding an extra restore (if anyone add $self->{curl}->perform and forgot to restore). (Fix for TOOLS-2590)
    $SIG{INT}=$oldhandler;

    return 1;
}

=pod

=head3 switchSessionLog()
DESCRIPTION:   
   This subroutine will switch the session to passed directory.

Arguments :
   Manditory -> path to switch

Return Values :

   1 - success
   0 - Failur

Example :
    $self->switchSessionLog( $path);

=cut


sub switchSessionLog {
    my $path = shift;

    my $sub_name = "switchSessionLog";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    unless ($path) {
       $logger->error(__PACKAGE__ . ".$sub_name: manditory argument path is missing or blank");
       return 0;
    }

    foreach my $obj (@cleanup) {
        next unless $obj->{conn};
        next unless $obj->{SESSIONLOG};
        if ($obj->{sessionLog1} =~ /\/(.+\/)?(.+\.log)$/){ 
            $obj->{conn}->dump_log("$path/$2"); #switching the session dump log
	    $logger->info(__PACKAGE__ . ".$sub_name: switched $obj->{sessionLog1} to $path");
            $obj->{sessionLog1} = "$path/$2";
        }
        if ($obj->{sessionLog2} =~ /\/(.+\/)?(.+\.log)$/){
            $obj->{conn}->input_log("$path/$2");#switching the session input log
	    $logger->info(__PACKAGE__ . ".$sub_name: switched $obj->{sessionLog2} to $path");
            $obj->{sessionLog2} = "$path/$2";
        }
    }

    return 1;
}

=pod

=head3 reconnectSessions()
DESCRIPTION:  
   This subroutine will make reconnection of required object family.

Arguments :
   Manditory -> object family (ex -> "GSX", "PSX", "SBX5000")

Return Values :

	- number objects reconnected.

Example :
    SonusQA::Base::reconnectSessions( 'GSX');

=cut

sub reconnectSessions {
    my $objFamily = shift;

    my $sub_name = "reconnectSessions";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    unless ( $objFamily) {
       $logger->error(__PACKAGE__ . ".$sub_name: manditory argument object family is missing");
       return 0;
    }

    my $count = 0;
    my @reconnectedObjects = ();
    while (my $atsObj = shift @cleanup) {
       next unless (defined $atsObj);

       unless (ref $atsObj eq "SonusQA::$objFamily"){
           push (@reconnectedObjects, $atsObj);
           next;
       }
       $count++;
       $logger->info(__PACKAGE__ . ".$sub_name: reconnecting $objFamily obj -> $count");

       unless ($atsObj->reconnect()) {
          $logger->error(__PACKAGE__ . ".$sub_name:  re-connection attempt to $count $objFamily obj failed");
          $count--;
          next;
       } else {
          push (@reconnectedObjects, $atsObj);
       }
 
       $logger->info(__PACKAGE__ . ".$sub_name:  re-connection attempt to $count $objFamily obj successful");
    }

    push (@cleanup, @reconnectedObjects) if (scalar(@reconnectedObjects) > 0);

    $logger->info(__PACKAGE__ . ".$sub_name: number session reconnection made -> $count");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$count]");

    return $count;
}

=pod

=head3 pingHost()
DESCRIPTION:   
   This subroutine will ping the passed ip from the machine.

Arguments :
   Manditory -> ipadress 

Return Values :

   1 -> if pingable
   0 -> if ping fails

Example :

    $obj->pingHost("10.54.80.7");

=cut

sub pingHost {
    my ($self, $dest) = @_;

    my $sub_name = "pingHost()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    unless ($dest) {
        $logger->error(__PACKAGE__ . ".$sub_name: manditory argument ipadress is missing");
        return 0;
    }

    my(@cmdResults,$cmd);

    if ($dest =~ /^\d+\.\d+\.\d+\.\d+$/i) {
        $cmd = sprintf("ping -c 4 %s ", $dest);
    }else{
        $cmd = sprintf("ping6 -c 4 %s ", $dest);
    }

    @cmdResults =  $self->{conn}->cmd($cmd);

    if (grep (/\s0\% packet loss/i, @cmdResults) or grep (/is alive/i, @cmdResults)) {
        $logger->info(__PACKAGE__ . ".$sub_name: Ping Successful, Host($dest) reachable!");
        return 1;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Ping not Successful, Host($dest) not reachable! Ping command output :");
        foreach(@cmdResults){
            $logger->debug($_);
        }
        return 0;
    }
}

=pod

=head3 forcedDestroy()
DESCRIPTION:   
   This subroutine is use DESTROY all the uncleared sessions. Comes handy when most the session are not cleared because of which you wont be able to make furture session ( case of mega run)

Arguments :
   NONE

Return Values :
   1
Example :
    SonusQA::Base::forcedDestroy();

=cut

sub forcedDestroy {
    my $sub_name = "forcedDestroy()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name:  --> Entered Sub");

    foreach(@cleanup){
       $_->DESTROY() if defined($_);
    }
    @cleanup = ();
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}


=head2 becomeUser()
DESCRIPTION:
    This function will login as passed username for the linux session (default login is insight/insight)
            
Arguments:
    Optional
        -userName => user name, default is insight
        -password => password, default is insight

Return Value:
    0 - on failure
    1 - on success

Usage:
    $emsObj->becomeUser();
=cut

sub becomeUser {
    my($self, %args)=@_;
    my $sub_name = 'becomeUser';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    my $user = defined ($args{-userName}) ? $args{-userName} : 'insight';
    my $password = defined ($args{-password}) ? $args{-password} : 'insight';

    my $cmd = 'id';
    my $login_cmd = (exists $self->{SU_CMD})?$self->{SU_CMD}:'su -';
    my @cmdresults;
    
    unless($args{-skipIdCheck}){
        unless ( @cmdresults = $self->{conn}->cmd($cmd) ) #TOOLS-18755 changed execCmd to conn->cmd. Because for SBC we will run SQL commands with Root object, which is a Base Object and Base dont have execCmd.
        {
            $logger->error( __PACKAGE__ . ".$sub_name: failed to execute the command : $cmd" );
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub_name Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub_name Session Input Log is: $self->{sessionLog2}");
            $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
            return 0;
        }

        if ( grep( /uid=\d+\($user\)/, @cmdresults ) )
        {
            $logger->debug( __PACKAGE__ . ".$sub_name: You are already logged in as $user" ) ;
            $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [1]" );
            return 1;
        }
    }
    
    if($self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} =~ /(PSX|EMS)/i and !grep(/^uid=\d+\(admin\)/,@cmdresults)){ #TOOLS-17812 TOOLS-17912 
        $self->{conn}->prompt($self->{DEFAULTPROMPT});
        foreach('exit','exit',$cmd){
            @cmdresults = $self->{conn}->cmd( String => $_, Prompt => $self->{DEFAULTPROMPT}); #TOOLS-18755 changed execCmd to conn->cmd. Because for SBC we will run SQL commands with Root object, which is a Base Object and Base dont have execCmd.
        }
        unless ( grep( /admin/, @cmdresults ) )
        {
            $logger->debug( __PACKAGE__ . ".$sub_name: You are not logged in as admin.".Dumper(\@cmdresults) ) ;
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub_name Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub_name Session Input Log is: $self->{sessionLog2}");
            $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
            return 0;
        }
    }
    unless ($self->{conn}->print("$login_cmd $user")) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to enter as \'$user\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my ($prematch, $match) = ('','');

    unless (($prematch, $match) = $self->{conn}->waitfor( -match     => '/[P|p]assword:/',-match     =>  $self->{DEFAULTPROMPT})) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to get expected prompt");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    if ( $match =~ m/[P|p]assword:/ ) {
        $self->{conn}->print($password);
        unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                -match => '/incorrect password/',
                                                -match => $self->{DEFAULTPROMPT},
                                                -errmode   => "return",
                                              )) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Unknown error on password entry.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        if ( $match =~ m/incorrect password/ ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  Password used \'$password\' for su - $user was incorrect.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        else {
            $logger->debug(__PACKAGE__ . ".$sub_name:  Password accepted for \'su - $user\'");
        }
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name: Login accepted without password");
    }

    unless($args{-skipIdCheck}){
        unless ( @cmdresults = $self->{conn}->cmd( String => $cmd, Prompt => $self->{DEFAULTPROMPT}) ){ #TOOLS-18755 changed execCmd to conn->cmd. Because for SBC we will run SQL commands with Root object, which is a Base Object and Base dont have execCmd.
            $logger->error( __PACKAGE__ . ".$sub_name: failed to execute the command : $cmd" );
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub_name Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub_name Session Input Log is: $self->{sessionLog2}");
            $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
            return 0;
        }

        unless ( grep( /$user/, @cmdresults ) ){
            $logger->debug( __PACKAGE__ . ".$sub_name: You are not logged in as $user." ) ;
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub_name Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub_name Session Input Log is: $self->{sessionLog2}");
            $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
            return 0;
        }
    }
    $self->setPrompt;

    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 pingDelay()

    This function starts the ping function and analyses the delay against the expected delay 

Arguments:
    Mandatory
        -destIp => The Destination to which the ping has to be done
    Optional
        -time => The Response delay aganist which the packet response time is validated. If the responsee time is less than 30% of this and greater than 50% then it is pegged as invalid delay
		 If not specified then 1ms is considered as default
        -noMinCheck => No check for min delay max delay can be in excess of 10% of time passed i.e if 4ms is checked(passed) 4.39ms delay will pass

Return Value:

    0 - on failure
	If the Number of Responses is less than or equal 8  or if the Invalid Delay is more than or equal to 5 then it reports Failure
    1 - on success

Usage:
    $psxObj->pingDelay(-destIp => '10.54.126.251' , -time => 10)

=cut


sub pingDelay {
    my($self, %args)=@_;
    my $sub_name = 'pingDelay';
    my $cmd = '';
    my @cmd_res = ();
    my $result = 1 ;
    my ($ResponseCount,$invalidDelay) = (0,0);
   
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    $args{-time} = (defined $args{-time}) ? $args{-time}:1;

    if (!defined $args{-destIp}) {
 	$logger->error(__PACKAGE__ . ".$sub_name: -destIp is not defined");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $cmd = "ping -I 1 $args{-destIp} 56 10" if ($self->{PLATFORM} eq 'SunOS');
    $cmd = "ping -c 10 $args{-destIp} " if ($self->{PLATFORM} eq 'linux');
    @cmd_res = $self->execCmd("$cmd",300);
    $logger->info(__PACKAGE__ . ".$sub_name:The ping o/p is " . Dumper(\@cmd_res));
    foreach (@cmd_res) {
	if ( $_ =~  m /(64 bytes)(.*)time=([0-9\.]+)([\s]+)ms/i ) {
	  if(defined $args{-noMinCheck}) {
		# check only if rtt is more that 10% of passed arguement, minimum is not checked, the lower the better
		$invalidDelay++  if (($3 >= 1.1*$args{-time}));
		$ResponseCount++;
        }
	else{
		#This leg is for checking min delay is present as required in most of EMS provisioning cases, this logic should not be altered
	    $invalidDelay++  if (($3 < 0.3*$args{-time}) || ($3 > 1.5*$args{-time}));
	    $ResponseCount++;
       	} 
    }
   }
   
   if (($ResponseCount <= 8 ) || ($invalidDelay >= 5)) {
	$logger->error(__PACKAGE__ . ".$sub_name: No Response Count = " .eval{10-$ResponseCount}  . ", Invalid Delay = $invalidDelay");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
   } else {
	$logger->info(__PACKAGE__ . ".$sub_name: Number of responses = $ResponseCount ,Number of Valid response Delay =" . eval{10-$invalidDelay});
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
	return 1;
   }

}

=head2 secureCopy()
DESCRIPTION:
    This function copies the files from source to destination, Remote server can be the Source Or Destination

Arguments:

    Hash with below deatils
          - Manditory
                -hostip                 Ip Address of the host, to which you want to connect and copy the files
                -hostuser               UserName of the remote host 
                -hostpasswd             Password of the remote host
                -sourceFilePath         File path of source
                -destinationFilePath    File path of destination
          - Optional
                -scpPort        Port Number to which you want to connect, By default it is 22
                -timeout        Time out value, by default it is 10s
                -identity_file  key file with complete path

Return Value:

    1 - on success
    0 - on failure

Usage:
     my %scpArgs;
     $scpArgs{-hostip} = "$self->{OBJ_HOST}";
     $scpArgs{-hostuser} = "$a{-userName}";
     $scpArgs{-hostpasswd} = "$a{-passwd}";
     $scpArgs{-scpPort} = "$a{-loginPort}";

Values of Source asnd Destination file names, and function call varies as following:
========================================================== 
When Copying single file from RemoteHost to local host
	$scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$a{-srcFileName};
	$scpArgs{-destinationFilePath} = $destFileName;
	unless(&SonusQA::Base::secureCopy(%scpArgs)){
           $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
           $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
           return 0;
        }
When Copying multiple files(*.log) from RemoteHost to local host
	$scpArgs{-sourceFilePath} = "$scpArgs{-hostip}:/export/home/ssuser/SOFTSWITCH/LOG/*.log";
	$scpArgs{-destinationFilePath} = $destFileName;
	unless(&SonusQA::Base::secureCopy(%scpArgs)){
           $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
           $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
           return 0;
        }
When Copying single file from LocalHost to RemoteHost
	$scpArgs{-sourceFilePath} = $out_file;
	$scpArgs{-destinationFilePath} = $scpArgs{-hostip}.':'."/tmp/$script_file";
	unless(&SonusQA::Base::secureCopy(%scpArgs)){
           $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
           $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
           return 0;
        }
When Copying multiple files from LocalHost to RemoteHost
     foreach my $log ("info.log", "info1.log", "info2.log", "info3.log"){
	$scpArgs{-sourceFilePath} = "/home/nanthoti/TEST/$log";
	$scpArgs{-destinationFilePath} = "$scpArgs{-hostip}:/export/home/ssuser/SOFTSWITCH/LOG/";
	unless(&SonusQA::Base::secureCopy(%scpArgs)){
           $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the files");
           $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
           return 0;
        }
     }
==========================================================

=cut

sub secureCopy{
    my %args = @_;
    my ($logger,$sub,$ssh,$scp_get);
    $sub = 'secureCopy';
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");
    $logger->info(__PACKAGE__ . ".$sub Entered sub");

#TOOLS-71111
    if ($args{-destinationFilePath}=~ /ats_repos\/lib\/perl\/QATEST\/PSX\/FEATURES.+DUTLogs.+\/(tms.+)/){
        `mkdir -p  $main::log_dir/DUTLogs`;
        $args{-destinationFilePath} = "$main::log_dir/DUTLogs/$1";
        $logger->info(__PACKAGE__ . ".$sub: Changed -destinationFilePath to $args{-destinationFilePath}");
    }
    my $scp;
    unless($scp = SonusQA::SCPATS->new( host=> $args{-hostip}, user=> $args{-hostuser}, password=> $args{-hostpasswd}, port => $args{-scpPort}, timeout=>$args{-timeout}, identity_file => $args{-identity_file})){
        $logger->error(__PACKAGE__ . ".$sub: Failed to create SCPATS object");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    unless($scp->scp($args{-sourceFilePath}, $args{-destinationFilePath})){
        $logger->error(__PACKAGE__ . ".$sub: Failed to scp $args{-sourceFilePath} to $args{-destinationFilePath}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [1]");
    return 1;
}

=head2 C< restAPI >

DESCRIPTION:

    This subroutine is used to execute REST API methods GET/PUT/POST/DELETE/PATCH. It returns a string with error code and error message . Eg -> 503: Service Unavailable

Note:

ARGUMENTS:

Mandatory :
   -url         => REST client URL to be executed.
   -contenttype => Type of content XML/JSON/HTML
   -method      => Type of REST client method  GET/PUT/POST/DELETE/PATCH

Optional:
   -username    => Username of the SBX.
   -password    => Password for SBX.
   -arguments => String containing XML formated input for PUT and POST methods.

PACKAGE:

    SonusQA::SBX5000:SBX5000HELPER

GLOBAL VARIABLES USED:

    None

OUTPUT:

   Eg -> (200, content)

EXAMPLES:

  my $url ='https://bf998-1/api/config/global/callRouting/route/trunkGroup';
  my $arguments ='<sipTrunkGroup><name>SBX-153_INT_TG_1</name><media><mediaIpInterfaceGroupName>LIF1</mediaIpInterfaceGroupName><mediaPortRange><baseUdpPort>1123</baseUdpPort><maxUdpPort>1200</maxUdpPort></mediaPortRange></media></sipTrunkGroup>';

  my ($responcecode,$responcecontent) = SonusQA::Base::restAPI( -url            => $url,
                                        			-contenttype    => 'xml',
                                        			-method         => 'POST',
                                        			-username       => 'admin',
                                        			-password       => 'Sonus@123',
                                        			-arguments      => $arguments);

=cut

sub restAPI {
        my %args = @_;
        my $sub = "restAPI()";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");
	
	$logger->info(__PACKAGE__ . ".$sub Entered sub");

        unless($args{-url}){
                $logger->error("$sub: Invalid url ");
                $logger->info("$sub: <-- Leaving Sub[0]");
                return 0;
        }

        unless($args{-contenttype}){
                $logger->debug("$sub: No content type is mentioned, Assuming XML as content type ");
                $args{-contenttype} = 'xml'
        }

        unless($args{-method} =~ /GET|PUT|POST|DELETE|PATCH/){
                $logger->error("$sub: Unknown method or method is invalid");
                $logger->info("$sub: <-- Leaving Sub[0]");
                return 0;
        }

        
		my $headers = {Accept => "application/$args{-contenttype}", 'Content-Type' => "application/$args{-contenttype}"};
		if ($args{-username} && $args{-password}) {
			$headers->{Authorization} = "Basic " . encode_base64($args{-username} . ":" . $args{-password});
		} 
		elsif ($args{-token}) {
			$headers->{Authorization} = "Bearer " . $args{-token};
		}

        my $client = REST::Client->new();
        $client->getUseragent()->ssl_opts(verify_hostname => 0);
        $client->getUseragent()->ssl_opts(SSL_verify_mode => 0);

        if($args{-method} eq "GET"){
                $client->GET($args{-url},$headers);
                $logger->debug("$sub: Executed Rest client GET URL : ".$args{-url});
                $logger->info("$sub: <-- Leaving Sub[1]");
                return ($client->responseCode(),$client->responseContent());
        }elsif($args{-method} eq "PUT"){
                unless($args{-arguments}){
                        $logger->error("$sub: Invalid arguments ");
                        $logger->info("$sub: <-- Leaving Sub[0]");
                        return 0;
                }
                $client->PUT($args{-url},$args{-arguments},$headers);
                $logger->debug("Executed REST client PUT URL : ".$args{-url});
                $logger->info("$sub: <-- Leaving Sub[1]");
                return ($client->responseCode(),$client->responseContent());;

        }elsif($args{-method} eq "POST"){
                unless($args{-arguments}){
                        $logger->error("$sub: Invalid arguments ");
                        $logger->info("$sub: <-- Leaving Sub[0]");
                        return 0;
                }
                $client->POST($args{-url},$args{-arguments},$headers);
                $logger->debug("Executed REST client POST URL :  ".$args{-url});
                $logger->info("$sub: <-- Leaving Sub[1]");
                return ($client->responseCode(),$client->responseContent());
        }elsif($args{-method} eq "DELETE"){
                $client->DELETE($args{-url},$headers);
                print $client->responseCode();
                $logger->debug("$sub: Executed Rest client DELETE URL : ".$args{-url});

                $logger->info("$sub: <-- Leaving Sub[1]");
                return ($client->responseCode(),$client->responseContent());
        }elsif($args{-method} eq "PATCH"){
                unless($args{-arguments}){
                        $logger->error("$sub: Mandatory argument, -arguments not passed ");
                        $logger->info("$sub: <-- Leaving Sub[0]");
                        return 0;
                }
                $client->PATCH($args{-url},$args{-arguments},$headers);
                $logger->debug("Executed REST client PATCH URL :  ".$args{-url});
                $logger->info("$sub: <-- Leaving Sub[1]");
                return ($client->responseCode(),$client->responseContent());
        }
		
        $logger->info("$sub: <-- Leaving Sub[0]");
        return 0;
}

=head1 enterRootSessionViaSU ()

DESCRIPTION:

 This subroutine will enter the linux root session via Su command.
 This subroutine also enters root session via sudo su command


ARGUMENTS:
None

PACKAGE:

GLOBAL VARIABLES USED:
 None

OUTPUT:
 1               - Success
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:

unless ( $brxObj->enterRootSessionViaSU( )) {
        $logger->debug(__PACKAGE__ . " : Could not enter root session");
        return 0;
        }

unless ( $brxObj->enterRootSessionViaSU('sudo')) {
        $logger->debug(__PACKAGE__ . " : Could not enter sudo root session");
        return 0;
        }

AUTHOR:
sonus-auto-core

=cut

sub enterRootSessionViaSU
{
        my ($self, $sudo) = @_;
        my $sub    = "enterRootSessionViaSU()";
        my $logger = Log::Log4perl->get_logger( __PACKAGE__ . "enterRootSessionViaSU()" );

        $logger->debug( __PACKAGE__ . ".$sub: Entered " );

        my $cmd1 = "id";
        my $login_cmd = (exists $self->{SU_CMD})?$self->{SU_CMD}:'su -';
        my ( @cmdresults, @cmdresults1 );
        unless ( @cmdresults = $self->{conn}->cmd($cmd1) )
        {
                $logger->error( __PACKAGE__ . ".$sub: failed to execute the command : $cmd1" );
                $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;
        }
        if ( grep( /root/, @cmdresults ) )
        {
                $logger->debug( __PACKAGE__ . ".$sub: You are already logged in as root" ) ;
                $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [1]" );
                return 1;
        }

        $logger->debug( __PACKAGE__ . ".$sub: changing the prompt from $self->{PROMPT} to $self->{DEFAULTPROMPT}");
        $self->{conn}->prompt($self->{DEFAULTPROMPT});

        if($self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} =~ /(PSX|EMS)/i and !grep(/^uid=\d+\(admin\)/,@cmdresults)){ #TOOLS-17812 TOOLS-17912 
            foreach('exit','exit',$cmd1){
                # TOOLS-20086 : adding extra waitfor to make sure we got the prompt. 
                # when we enter 'exit' from ssuser, an extra prompt (logout) is coming and because of this not getting the correct output of next command (id).
                $self->{conn}->waitfor(-match => $self->{DEFAULTPROMPT}, -timeout => 2 ) unless(/exit/);
                @cmdresults = $self->{conn}->cmd($_);
            }

            unless ( grep( /admin/,@cmdresults ) )
            {
                $logger->debug( __PACKAGE__ . ".$sub: You are not logged in as admin.There is some issue" ) ;
                $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub Session Input Log is: $self->{sessionLog2}");
                $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;
            }
        }
        my $is_root_pwd = 0;
        my ($cmd2, $rootpwd);
        if($sudo && $sudo =~ /sudo/i){
            $logger->debug( __PACKAGE__ . ".$sub: Entering sudo su root");
            $cmd2 = "sudo su root";
            $rootpwd = $self->{OBJ_PASSWORD};
        }else{
             $cmd2 = $login_cmd.' root';
             $is_root_pwd = 1;
             $rootpwd = $self->{ROOTPASSWD} ? $self->{ROOTPASSWD} : $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
        }
        #TOOLS-4391 end
	$logger->debug( __PACKAGE__ . ".$sub: Issuing the Cli: $cmd2" );
        $self->{conn}->print($cmd2);

        my ( $prematch, $match );
        unless (
                 ( $prematch, $match ) =
                 $self->{conn}->waitfor(
                                         -match   => '/Password.*\:/i', 
                                         -match => $self->{DEFAULTPROMPT},
                                         -errmode => "return",
                                         -timeout => $self->{DEFAULTTIMEOUT}
                 )
          )
        {
                $logger->warn( __PACKAGE__ . ".$sub: Root Login Failed" );
        	$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;
        }
        if ( $match =~ m/Password.*\:/i )
        {
                $self->{conn}->print($rootpwd);
                unless (
                         ( $prematch, $match ) =
                         $self->{conn}->waitfor( 
                                                 -match =>'/You are required to change your password immediately/i',
                                                 -match   => $self->{conn}->prompt, 
                                                 -match => $self->{DEFAULTPROMPT},
                                                 -errmode => "return",
                                                 -timeout => $self->{DEFAULTTIMEOUT}
                         )
                  )
                {
                        $logger->warn( __PACKAGE__ . ".$sub: failed to get Root Login Prompt " );
        		$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
		        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                        return 0;
                }
                if($match =~ m/You are required to change your password immediately/i){
                    $logger->warn(__PACKAGE__ . ".$sub: The new password will be -NEWROOTPASSWD or {LOGIN}->{2}->{ROOTPASSWD} or 'l0ngP\@ss'");
                    my $newpassword = $self->{NEWROOTPASSWD} || $self->{TMS_ALIAS_DATA}->{LOGIN}->{2}->{ROOTPASSWD} || "l0ngP\@ss";

                    tie (my %print, "Tie::IxHash");
                    %print = ( 'UNIX password:' => $rootpwd, 'New password:' => $newpassword, 'Retype new password:' => $newpassword);
                
                    my ($prematch, $match) = ('','');
                    my $flag = 1;
                    foreach (keys %print) {
                        unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => "/$_/i", -timeout   => $self->{DEFAULTTIMEOUT})) {
                            $logger->error(__PACKAGE__ . ".$sub: didn't match the expected match -> $_ ");
                            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                            $flag = 0;
                            last;
                        }
                        $logger->info(__PACKAGE__ . ".$sub: matched for $_, passing $print{$_} ");
                        $self->{conn}->print($print{$_});
                    }
                    unless($flag) {
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
                        return $flag;
                    }
                    unless ( ($prematch, $match) = $self->{conn}->waitfor(
                                                                           -match =>$self->{conn}->prompt, 
                                                                           -match => $self->{DEFAULTPROMPT},
                                                                           -errmode => "return", 
                                                                          -timeout   => $self->{DEFAULTTIMEOUT})) {
                        $logger->error(__PACKAGE__ . ".$sub: failed to get the root login prompt ");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
                        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                        return 0;
                    }
                    unless ( $self->changePasswd($rootpwd ,$is_root_pwd ) ) {
                        $logger->error(__PACKAGE__ . ".$sub: Could not change password to $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD} ");
                        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                        return 0;
                    }
                }
        }

        $self->setPrompt();

        #Fix for TOOLS-13691: executing 'unalias grep' to remove the color while doing grep
        foreach my $cmd ('unalias grep', $cmd1){ 
            @cmdresults1 = $self->{conn}->cmd($cmd); 
        }
	
        if ( grep( /root/, @cmdresults1 ) )
        {
            $self->{ENTERED_ROOT_SESSION} = 1;
            $logger->info( __PACKAGE__ . ".$sub: Successfully entered root Session" );
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [1]" );
            return 1;
        }

        $logger->error( __PACKAGE__ . ".$sub: login to root session failed!" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
}


=head1 leaveRootSession () 
DESCRIPTION:
 This subroutine exits from the linux root session.
 
ARGUMENTS:
None

PACKAGE:

GLOBAL VARIABLES USED:
 None

OUTPUT:
 1               - Success
 0       - Failure - Either we timed out, or a command failed.

EXAMPLE:
 unless ( $brxObj->leaveRootSession( )) {
        $logger->debug(__PACKAGE__ . " : Could not leave the root session");
        return 0;
        }
AUTHOR:
sonus-auto-core

=cut		

sub leaveRootSession
{
        my ($self) = @_;
        my $sub    = "leaveRootSession()";
        my $logger = Log::Log4perl->get_logger( __PACKAGE__ . "leaveRootSession()" );

        $logger->debug( __PACKAGE__ . ".$sub: Entered " );

        my $cmd1 = "id";
        my $cmd2 = "exit";

        my ( @cmdresults1, @cmdresults2, @cmdresults3 );
        unless ( @cmdresults1 = $self->{conn}->cmd($cmd1) )
        {
                $logger->error( __PACKAGE__ . ".$sub: failed to execute the command : $cmd1" );
                $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;
        }

        if ( grep( /root/, @cmdresults1 ) )
        {
            #Removed the TOOLS-4396 fix and added the below line
            unless( $self->{ENTERED_ROOT_SESSION} == 1 )  {
                $logger->debug( __PACKAGE__ . ".$sub: Didn't entered root session via enterRootSessionViaSu. So no need to exit.");
                $logger->debug( __PACKAGE__ . ".$sub; <-- Leaving sub [1]" );
                return 1;
            }
            $logger->debug( __PACKAGE__ . ".$sub: changing the prompt from $self->{PROMPT} to $self->{DEFAULTPROMPT}");
            $self->{conn}->prompt( $self->{DEFAULTPROMPT});#TOOLS-12706 
            $logger->debug( __PACKAGE__ . ".$sub: Issuing the Cli: $cmd2" );
            for(1..2){
                $self->{conn}->cmd($cmd2);
                #$self->{conn}->prompt( $self->{PROMPT} );#TOOLS-17812 TOOLS-17912
            }
        }
        unless ( @cmdresults2 = $self->{conn}->cmd($cmd1) )
        {
                $logger->error( __PACKAGE__ . ".$sub: failed to execute the command : $cmd1" );
                $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
                return 0;
        }

        unless ( grep( /root/, @cmdresults2 ) )
        {
            $self->{ENTERED_ROOT_SESSION} = 0;
            $logger->info( __PACKAGE__ . ".$sub: Successfully exited from root session" );
            if($self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} =~ /(PSX|EMS)/i){ #TOOLS-17812 TOOLS-17912
                unless ( $self->becomeUser(-userName => $self->{'TMS_ALIAS_DATA'}->{LOGIN}->{1}->{USERID},-password => $self->{'TMS_ALIAS_DATA'}->{LOGIN}->{1}->{PASSWD}) ) {
                    $logger->error(__PACKAGE__ . ".$sub:  failed to login as $self->{'TMS_ALIAS_DATA'}->{LOGIN}->{1}->{USERID}.");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                    return 0;
                }
            }
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [1]" );
            return 1;
        }

        $logger->error( __PACKAGE__ . ".$sub: Failed to exit from root session" );
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        return 0;
}

=head1 setClientAliveInterval ()

DESCRIPTION:

 This subroutine will set the ClientAliveinterval time in sshd_config file to 0.


ARGUMENTS:
None

PACKAGE:
 SonusQA::Base

GLOBAL VARIABLES USED:
 None

EXTERNAL FUNCTIONS USED:
 SonusQA::Base::enterRootSessionViaSU()
 SonusQA::Base::leaveRootSession()

OUTPUT:
 1               - Success
 0       	 - Failure - Either external functions returned 0 or command failed.

EXAMPLE:

unless ( $emsObj->setClientAliveInterval()) {
        $logger->debug(__PACKAGE__ . " : Could not set ClientAliveInterval to 0.");
        return 0;
        }

AUTHOR:
sonus-auto-core

=cut

sub setClientAliveInterval
{
	my ($self) = @_;
	my $sub = "setClientAliveInterval()";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ". $sub");

	$logger->info( __PACKAGE__ . ".$sub: Entered ");

	unless( $self->enterRootSessionViaSU() ) {
		$logger->error( __PACKAGE__ . " : Could not enter root session" );
	        $logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
        	return 0;
	}

	$logger->info( __PACKAGE__ . ".$sub: Going to remove ClientAliveInterval from sshd config" );

  	my @cmdResults = $self->execCmd("grep ClientAliveInterval /etc/ssh/sshd_config");
        if (grep(/^\s*ClientAliveInterval\s*[1-9].*/, @cmdResults)){
		my $client_interval_cmd = 'perl -pi -e "s/^\s*ClientAliveInterval\s*[1-9].*/ClientAliveInterval 0/" /etc/ssh/sshd_config';
		$self->execCmd("$client_interval_cmd");

		if ( $self->{PLATFORM} eq 'SunOS' )
			{
			my $sshd_restart_cmd = "svcadm restart network/ssh" ;
			$self->execCmd("$sshd_restart_cmd");
			}
		else {
			my $sshd_restart_cmd = "service sshd restart";
			unless ( $self->execCmd("$sshd_restart_cmd") ) {
				$logger->error( __PACKAGE__ . " : Could not execute: $sshd_restart_cmd" );
				$logger->info( __PACKAGE__ . ".$sub: <-- Leaving sub [0]" );
				return 0;
			}
		}
	}
        $self->{conn}->cmd("sed -i -e 's/PasswordAuthentication no/#PasswordAuthentication no/' /etc/ssh/sshd_config;sed -i -e 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config;sed -i -e 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config; service sshd restart");

	unless ( $self->leaveRootSession()) {
		$logger->error(__PACKAGE__ . " : Could not leave the root session");
		return 0;
	}
	
	$logger->info( __PACKAGE__ . ".$sub: ClientAliveInterval set to 0." );
	return 1;
}

=head1 sqlplusCommand()

DESCRIPTION:
Purpose      :  Used to enter a correctly formatted SQLPLUS command on PSX and SBX; This command can only update/insert/delete 1 row at a time.
                It assumes dbimpl password on the PSX system is dbimpl

Parameters   :
        Mandatory:
                sqlplus command
        Optional:
                Database username
                Database password

Return values:
                0 if unsuccessful
                command output if successful

=cut

sub sqlplusCommand {
    my ($self, $command, $user, $pass, $timeout)=@_;
    my $obj= $self;
    my (@cmdResult, $cmd, $prematch, $match, $oracle_login,@id_result);
    my $flag = 0;

    my $sub_name = "sqlplusCommand";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered sub");

    if(!defined($command)){
      $logger->error(__PACKAGE__ . ".$sub_name: MISSING - REQUIRED command");
      $logger->debug(__PACKAGE__.".$sub_name: <-- Leaving sub [0]");
      return 0;
    }
  
    if ( $self->{CLOUD_PSX} and $self->{MASTER}){
        $obj = $self->{MASTER};
        if ($command =~ /\bSS_PROCESS\b/){
            $command =~ s/PROCESS_MANAGER_ID\s+=\s+(\S+)/PROCESS_MANAGER_ID = \'$main::TESTBED{'ssmgr_config'}\'/;
            $command =~ s/VALUES\s+\(\s*'DEFAULT'/VALUES \(\'$main::TESTBED{'ssmgr_config'}\'/;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Became Master PSX");
    }
    $timeout ||= $self->{DEFAULTTIMEOUT};

    my ($prompt, $dbexit)  ;

    if ( $self->{SBC_VERSION} and SonusQA::Utils::greaterThanVersion( $self->{SBC_VERSION}, 'V08.00.00')) {   # adding SBC_VERSION in makeRootseesion
        $cmd =("psql ssdb");
        $prompt = '/ssdb\=\>/' ;
        $dbexit = '\q' ;
    }else {
        unless( @id_result = $obj->{conn}->cmd(String => 'id',Prompt => $obj->{DEFAULTPROMPT})){
            $logger->error(__PACKAGE__.".$sub_name: Unable to execute \'id\' cmd");
            $logger->debug(__PACKAGE__.".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        if(defined $self->{TMS_ALIAS_DATA} and $self->{TMS_ALIAS_DATA}->{__OBJTYPE} eq 'PSX'){
            $user ||= $obj->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{USERID};
            $pass ||= $obj->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{PASSWD};
        }

        if(grep(/oracle/i,@id_result)){
            $logger->debug(__PACKAGE__.".$sub_name: Already logged in as oracle user");
        }else{
            # Changing the Login to Oracle  as sysdba login works on that
            unless ( $obj->becomeUser(-userName => 'oracle',-password => 'oracle') ) {
                $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as oracle.");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
                return 0;
	    }
            $oracle_login = 1; #logged in as oracle 
        }
        $cmd =($user and $pass)?("sqlplus $user\/$pass"):("sqlplus \'\/as sysdba\'");
        $prompt = '/SQL\>/' ;
        $dbexit = 'exit';
    }
    #TOOLS-18610
    #Enter SQL
    $obj->{conn}->print($cmd);
    if(($prematch, $match) = $obj->{conn}->waitfor(-match => $prompt,
                                                        -errmode => "return",
                                                       )){
            $logger->info(__PACKAGE__ . ".$sub_name: SENDING SQL COMMAND $command");
        #Execute the Cmd  
        if (@cmdResult = $obj->{conn}->cmd(String => $command, Prompt => $prompt ,Timeout => $timeout)) {
            $self->{conn}->buffer_empty; #TOOLS-19853: clearing the buffer solved the issue. buffer was ' SQL> SQL> ' and next command execution matched this as prompt.
            #Execute Commit
            unless (grep (/ERROR/, @cmdResult)) {
                if ( $prompt =~ /SQL/ ) { 
                    unless($obj->{conn}->cmd(String => 'commit;', Prompt => $prompt ,Timeout => $timeout)) {
                        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute 'commit;'");
                        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $obj->{conn}->errmsg);
                    }
                }
                $flag = 1;
            }else{
                $logger->error(__PACKAGE__ . ".$sub_name: Command $command resulted in error");
            }
        }else{
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute command:$command");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $obj->{conn}->errmsg);
        }
    }else{
        $logger->error(__PACKAGE__ . ".$sub_name: UNABLE TO ENTER SQL:$cmd ");
    }

    $obj->{conn}->prompt($obj->{DEFAULTPROMPT});
    $obj->{conn}->cmd(String => $dbexit); # SQL exit
    if($oracle_login) # oracle exit
    {
        unless( $obj->exitUser()) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $obj->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $obj->{sessionLog2}");
            &error("CMD FAILURE:exit ") if($obj->{CMDERRORFLAG});
            $logger->debug(__PACKAGE__ . ".$sub_name failed to come out of oracle  prompt");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }

    if($self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} =~ /^(PSX|EMS)/){ #TOOLS-17812 TOOLS-17912
        unless ( $obj->becomeUser(-userName => $self->{'TMS_ALIAS_DATA'}->{LOGIN}->{1}->{USERID},-password => $self->{'TMS_ALIAS_DATA'}->{LOGIN}->{1}->{PASSWD}) ) {
            $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as $self->{'TMS_ALIAS_DATA'}->{LOGIN}->{2}->{USERID}.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    if($flag){
        $logger->debug(__PACKAGE__ . ".$sub_name: successfully executed SQL command $command") if($flag)
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $obj->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $obj->{sessionLog2}");
    }
    chomp (@cmdResult);
    @cmdResult = grep /\S/, @cmdResult;
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[$flag]");
    return @cmdResult;
}

=head1 changePasswd()

DESCRIPTION:
Purpose      :  Use to change the password by using the command, "passwd" 

Parameters   :
        Mandatory:
                newPasswd

Return values:
                0 if unsuccessful
                1 if successful

=cut

sub changePasswd{
    my ($self, $newPasswd,$is_root_pwd) = @_;
    my $sub = "changePasswd";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub Changing password to \'$newPasswd\' ");
    $self->{conn}->print("passwd");
    tie (my %print, "Tie::IxHash");
    %print = ( 'New password: ' => $newPasswd, 'Retype new password: ' => $newPasswd);
    my ($prematch, $match) = ('','');
    foreach (keys %print) {
        unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => "/$_/i", -match =>$self->{PROMPT}, -timeout   => $self->{DEFAULTTIMEOUT})) {
            $logger->error(__PACKAGE__ . ".$sub: dint match for expected match -> [$_] ,prematch ->  [$prematch],  match ->[$match]");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        if ($match =~ /$_/i) {
            $logger->info(__PACKAGE__ . ".$sub: matched for [$_],prematch ->  [$prematch], passing [$print{$_}] argument");
            $self->{conn}->print($print{$_});
        } else {
            $logger->error(__PACKAGE__ . ".$sub: dint match for expected prompt [$_], prematch ->  [$prematch],  match ->[$match] ");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
    unless ( ($prematch, $match) = $self->{conn}->waitfor(-match => '/all authentication tokens updated successfully/i', -match =>$self->{PROMPT}, -match => '/Password mismatch/i',  -match => '/bad password/i', -timeout   => $self->{DEFAULTTIMEOUT})) {
        $logger->error(__PACKAGE__ . ".$sub: Didn't receive an expected msg after changing the password , prematch ->  '$prematch',  match ->'$match' '".${$self->{conn}->buffer}."'");
        ($prematch, $match) = $self->{conn}->waitfor(-match =>$self->{PROMPT}, -timeout   => $self->{DEFAULTTIMEOUT});
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    if ($match =~ m/all authentication tokens updated successfully/i or $match =~ m/password updated successfully/i) {
        $logger->info(__PACKAGE__ . ".$sub: Password changed successfully.");
        $self->{conn}->waitfor(-match =>$self->{PROMPT}, -timeout   => $self->{DEFAULTTIMEOUT});
        $is_root_pwd ? ($self->{ROOTPASSWD} = $newPasswd) : ($self->{OBJ_PASSWORD} = $newPasswd) ;
    } elsif ($prematch =~ /Password mismatch/i) {
        $logger->info(__PACKAGE__ . ".$sub: Password mismatch");
        $self->{conn}->waitfor(-match =>$self->{PROMPT}, -timeout   => $self->{DEFAULTTIMEOUT});
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    } 
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1; 
}

=head2 C< storeLogs >

=over 

=item DESCRIPTION:

   This subroutine takes the logfile as argument and decides where it needs to be saved depending upon $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} value.
   $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 1 for saving the logs on the SBX itself
   $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 2 for saving logs on ATS server only
   $TESTSUITE->{STORE_LOGS} or $self->{STORE_LOGS} is 3 for saving logs on both ATS server and SBX
   SonusQA::Base::secureCopy(%scpArgs) subroutine is called for copying file from Remote host to on ATS server.

=item ARGUMENTS:

 MANDATORY:
   1. Name of the file     - $filename
   2. CopyLocation         - $copyLocation
   3. testCase Id          - $tcid. Default value is 'NONE'

=item PACKAGE:
    
 SonusQA::Base

=item OUTPUT:

 0   - failure
 1   - success

=item EXAMPLES:

 $sbxObj->storeLogs($filename,$tcid,$copyLocation);

=back

=cut

sub storeLogs {
    my ($self) = shift;
    my $home_dir;
    my $sub_name = "storeLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    if ($self->{D_SBC}) {
        my %hash = (
                        'args' => [@_]
                );
        my $retVal = $self->__dsbcCallback(\&storeLogs, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$retVal]");
        return $retVal;
    }
    my ($filename,$tcid,$copyLocation,$localPath) = @_ ;

    unless ( $filename ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory filename empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ( $copyLocation ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory copy location empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless ( $tcid ) {
        $logger->warn(__PACKAGE__ . ".$sub_name: Mandatory tcid is empty or blank. Considering \'NONE\' as testcase id.");
        $tcid = "NONE"; 
    }

   my $sbc_type = ($self->{SBC_TYPE}) ? "$self->{SBC_TYPE}-$self->{INDEX}_" : ''; # $self->{SBC_TYPE} is only for DSBC and it is S_SBC/M_SBC/T_SBC/I_SBC
   my $ce_hostname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME};
   my $store_log = (defined  $main::TESTSUITE->{STORE_LOGS}) ? $main::TESTSUITE->{STORE_LOGS} : $self->{STORE_LOGS};
   $logger->debug(__PACKAGE__ . ".$sub_name: STORE_LOGS value is: $store_log");
   my $datestamp = strftime("%Y%m%d%H%M%S",localtime);
   my $ip_type = ($self->{CONNECTED_IPTYPE} eq 'IPV6') ? 'IPV6' : 'IP';
   my (%scpArgs, $locallogname);
   $scpArgs{-hostip} = $self->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{$ip_type} || $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{IP};

   if($self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} eq 'VIGIL'){
       $localPath = $self->{'LOG_PATH'};
       $locallogname = $copyLocation;
       $scpArgs{-hostuser} = 'vigiladmin';
       $scpArgs{-hostpasswd} = 'vigiladmin123';
       $scpArgs{-scpPort} = '22';
   }elsif($self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} eq 'SBCEDGE'){
        unless ( $localPath ) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory local path  empty or blank.");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
       $locallogname = $copyLocation;
       $scpArgs{-hostuser} = 'root';
       $scpArgs{-hostpasswd} = 'sonus';
       $scpArgs{-scpPort} = '22';
       $scpArgs{-destinationFilePath} = $locallogname;
   }
   elsif($self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} eq 'QSBC'){
       $localPath ||= $self->{'LOG_PATH'};#TOOLS-75671
       $locallogname = $copyLocation;
       $scpArgs{-hostuser} = 'root';
       $scpArgs{-hostpasswd} = 'shipped!!';
       $scpArgs{-scpPort} = '22';
       $sbc_type = 'QSBC';
       $ce_hostname = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};
   }
   else{
       my $ce = $self->{ACTIVE_CE};
       $localPath ||= ($filename =~ /snmp/i) ? "/opt/sonus/sbx/tailf/var/confd/log/" : "/var/log/sonus/sbx/evlog";
       $locallogname = $self->{LOG_PATH};
       $self = $self->{$ce};
       $scpArgs{-hostuser} = 'root';
       $scpArgs{-hostpasswd} = 'sonus1';
       $scpArgs{-scpPort} = '2024';
   }

   if ($filename!~/\.TRC/ and ($store_log == 1 or $store_log == 3)) {
       my $cmd = "cp $localPath/$filename $copyLocation/${sbc_type}$ce_hostname"."_".$datestamp."_".$tcid."_".$filename;
       $logger->debug(__PACKAGE__ . ".$sub_name: Executing command $cmd");
       unless ($self->{conn}->cmd($cmd))  {
           $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd.");
           $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
           $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
           $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
           $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
           $main::failure_msg .= "TOOLS:Base-Failed to CopyLogs to DUT; ";
           return 0;
       }
       $logger->debug(__PACKAGE__ . ".$sub_name: Successfully copied the file");
   }

   my $ret = 1;
   if ( $store_log == 2 or $store_log == 3) {
        # TOOLS-17987
       if($filename=~/\.TRC/){
            my $zip_cmd = "tar -czf $localPath/$filename.tgz $localPath/$filename";
            $logger->info(__PACKAGE__ . ".$sub_name: $filename will be zipped and copied to /logstore");
            $logger->debug(__PACKAGE__ . ".$sub_name: cmd: $zip_cmd");

            unless ( $self->{conn}->cmd($zip_cmd))  {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the tar command");
                $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                $main::failure_msg .= "TOOLS:Base-Failed to tar $filename; ";
                return 0;
            }
            $filename .= '.tgz';
            chomp (my $id=`id -un`);
            $scpArgs{-destinationFilePath} = "/logstore/${id}_$sbc_type${ce_hostname}_${datestamp}_${tcid}_$filename";
        }

       $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$localPath/$filename";
       unless(exists $scpArgs{-destinationFilePath}){
           $locallogname = $main::log_dir if (defined $main::log_dir and $main::log_dir);
           $locallogname .= "/$sbc_type".$ce_hostname."_".$datestamp."_".$tcid."_".$filename;
           $scpArgs{-destinationFilePath} = $locallogname;
       }
       $logger->debug(__PACKAGE__ . ".$sub_name: scp log $localPath/$filename to $scpArgs{-destinationFilePath}");
       unless(&SonusQA::Base::secureCopy(%scpArgs)){
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the $filename file");
	       $main::failure_msg .= "TOOLS:Base-Failed to CopyLogs to ATS; ";
           $ret = 0;
       }

        # TOOLS-17987
        if($filename=~/\.TRC/){
            unless ( $self->{conn}->cmd("rm -f $localPath/$filename"))  {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the command: rm -f $localPath/$filename");
                $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
                $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                $main::failure_msg .= "TOOLS:Base-Failed to rm -f $filename; ";
                return 0;
            }
        }
   }

   $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$ret]");
   return $ret;
}

=head2 C< parseLogFiles >

=over

=item DESCRIPTION:

 This subroutine checks the Pattern in the given log file .
 If the pattern should be checked in sequential then the sequential flag(seq_flag = 1) must be set while calling the subroutine.

=item ARGUMENTS:

 1.log_file_name = Name of the Log file to be parsed
 2.logstring     = The pattern to be checked in the logfile 
  i)   pass array           = To simply check whether the pattern is present in log file .
  ii)  pass array reference = To check the pattern is present in sequence (in order).
  iii) pass hash reference  = To check the exact count of pattern present in log file.

 Optional:

 1.seq_flag = 1 ( to check Sequential )  

=item PACKAGE:

 SonusQA::Base

=item OUTPUT:

 0   - fail (even if one fails)
 1   - success (if all the  pattern match)

=item EXAMPLES:

 1.TO simply check whethere the pattern is present in log file:

    my @parse = ("m=audio .* RTP/AVP 96 8 18 9 116 99 126 100");
    $sbxObj->parseLogFiles($log_file_name,@parse);

 2.To check the pattern is present in sequence (in order):

    my @parse = ("m=audio .* RTP/AVP 96 8 18 9 116 99 126 100","SEQ","m=audio .* RTP/AVP 96 8 18 9 116 99 126 100");
    $sbxObj->parseLogFiles($log_file_name,\@parse,1);

 3.To check atleast the given count of pattern present in log file:

    my $parse = {"SipsMemFree: corrupted block" => 0,"SYS ERR" => 0};
    $sbxObj->parseLogFiles($log_file_name,$parse);

=back

=cut

sub parseLogFiles {
    my ($self) = shift ;
    my ($logfile) = shift;
    my (@logstring,%logstring,@logstringcount,$seq_flag,%seen,$cmd);
    my $flag = 0;
    my $sub_name = "parseLogFiles";
    my @match;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

=pod                           #Commented with pod and cut for TOOLS - 12241, suppose if we need these changes in future , we can just uncomment them.
    if ($self->{D_SBC}) {
        $logger->debug(__PACKAGE__ . ".$sub_name: It is a D_SBC");
        my $fileType = $1 if ($logfile =~ /\w+\.(.*)/); #get the log type from the file passed
        my ($resArr, $result);
        my @nextInput = @_;
        my $sbcType = 'S_SBC';
        foreach my $sbcType (@{$self->{PERSONALITIES}}) {
            foreach my $instance (keys %{$self->{$sbcType}}) {
                my $obj = $self->{$sbcType}->{$instance};
                my $aliasName = $obj->{OBJ_HOSTNAME};

                $logger->debug(__PACKAGE__ . ".$sub_name: Getting Recent Log file for '$aliasName' ($sbcType\-\>$instance)");
		my ($logFile) = $self->{$sbcType}->{$instance}->getRecentLogFiles($fileType, 1); #get the recent log file

                $logger->debug(__PACKAGE__ . ".$sub_name: Executing sub for '$aliasName' ($sbcType\-\>$instance)");
                ($resArr, $result) = parseLogFiles($self->{$sbcType}->{$instance}, $logFile, @nextInput); #get the result of parse log file for this object
                my @resArr = @$resArr;

                last if $result; #if result is 1 (passed)
                next unless (@resArr); #if result Array is empty, means checking for sequence, it didn't match
                if (ref $_[0] eq 'HASH') {
                    my $strings = shift;
                    my (@stringValue, @stringKey, %nextInput);
                    chomp %$strings;
                    while (my ($key, $value) = each (%$strings)) {
                        push (@stringValue, $value);
                        push (@stringKey, $key);
                    }
                    for (my $index = 0; $index <= $#resArr; $index++) {
                        if ($stringValue[$index] == 0) {
                            if ($resArr[$index] != $stringValue[$index]) { #value didn't match, check in next sbc
                                $nextInput{$stringKey[$index]} = $stringValue[$index];
                            }
                        }
                        else {
                            if ($resArr[$index] < $stringValue[$index]) { #value is less than expected, check in next sbc
                                $nextInput{$stringKey[$index]} = $stringValue[$index];
                            }
                        }
                    }
                    @nextInput = \%nextInput;
                }
                else {
                    @nextInput = ();
                    my @strings = (ref $_[0] eq "ARRAY" ? @{$_[0]} : @_);
                    for (my $index = 0; $index <= $#resArr; $index++) {
                        if ($resArr[$index] < 1) { #value not present, check in next sbc
                            push (@nextInput, $strings[$index]);
                        }
                    }
                }
            }
            last if $result;
        }
        return ($resArr, $result);
    }

=cut                      
    #getting the pattern to parse
    if(ref $_[0] eq 'HASH' ){
        %logstring = %{$_[0]};
        chomp %logstring;
        while(my ($key,$value) = each(%logstring)){
            push @logstringcount, $value;
            push @logstring, $key;
        }
    }elsif(ref $_[0] eq 'ARRAY'){
        my $logstring = shift;
        @logstring = @$logstring;
        $seq_flag = shift;
    }else{
         @logstring =@_; 
    } 
    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $logfile ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory filename empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( @logstring ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory search pattern is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if($self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} eq 'VIGIL' || $self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} eq 'QSBC' || $self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} eq 'C3' || $self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} eq 'AS' || $self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} eq 'SST'){
        $cmd = "cd $self->{'LOG_PATH'}";
    }
    elsif($self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} eq 'SBX5000'){
        if ($self->{D_SBC}) {                                               # TOOLS - 12241
            my $sbc_type = (exists $self->{I_SBC}) ? 'I_SBC' : 'S_SBC';
            $self = $self->{$sbc_type}->{1};
            $logger->debug(__PACKAGE__ . ".$sub_name: Executing only for $self->{OBJ_HOSTNAME} {$sbc_type}->{1}");
        }
        my $ce = $self->{ACTIVE_CE}; #changed to ACTIVE_CE insteaof CE0 (Fix for TOOLS-9532)
	$cmd=($logfile =~ /snmp|audit/i) ? "cd /opt/sonus/sbx/tailf/var/confd/log/" : "cd /var/log/sonus/sbx/evlog";
	$self = $self->{$ce};
    }
    unless ( my @cmd_result = $self->{conn}->cmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command:$cmd");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    if ( $seq_flag ) {
         $logger->info(__PACKAGE__ . ".$sub_name: The patterns in \"$logfile\" is to be checked SEQUENTIALLY.");
         my $prev_line = 0;
         for (my $pattern=0; $pattern<=$#logstring; $pattern++ ){
             my $pat = $logstring[$pattern];
             unless ($seen{$pat}{pindex}) {
                 my @grep_line_num;
                 unless(@grep_line_num = $self->{conn}->cmd("grep -n \"$pat\" $logfile | cut -f1 -d:")){ #gets the line number
                     $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the shell command to get the line number");
                     $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
                     $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
                     $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                     $main::failure_msg .= "UNKNOWN:Base-Failed to grep $pat; ";
                     return 0;
                 }
                 chomp @grep_line_num;
                 $seen{$pat}{line_num} = \@grep_line_num;
             }
             my $line_num = $seen{$pat}{line_num}->[$seen{$pat}{pindex}];
             $seen{$pat}{pindex}++;
             unless ($line_num){
                 $logger->error(__PACKAGE__.".$sub_name: The Pattern \"$pat\" was NOT FOUND in \"$logfile\".");
                 $flag = 1;
                 last;
             }
             if( $prev_line < $line_num) {
                 $logger->info(__PACKAGE__.".$sub_name: The Pattern \"$pat\" in \"$logfile\" was found to be in SEQUENCE( Line no.$line_num).");
                 $prev_line = $line_num;
             }else {
                 $logger->error(__PACKAGE__.".$sub_name: The Pattern \"$pat\" in \"$logfile\" was NOT in SEQUENCE ( Line no.$line_num).");
                 $flag = 1;
                 last;
             }
         }
    }else {
         for(my $pattern=0; $pattern <= $#logstring; $pattern++ ){
             my $pat = $logstring[$pattern];
             my $cmd2="grep -i \"$pat\" $logfile | wc -l";
             my @matches = $self->{conn}->cmd($cmd2);
             chomp @matches;
             my $matches = $matches[0];
             unless ( defined $logstringcount[$pattern] ) {
                 $logstringcount[$pattern] = 1;
             }
             if ( $logstringcount[$pattern] == 0){
                 if ( $matches == $logstringcount[$pattern] ) {
                     $logger->debug(__PACKAGE__ . ".$sub_name: Expected count,'$logstringcount[$pattern]' MATCHES for \"$pat\" in \"$logfile\": Count of Matches -> $matches ");
                 } else {
                     $logger->debug(__PACKAGE__ . ".$sub_name: Expected count,'$logstringcount[$pattern]' NOT MATCHES for \"$pat\" in \"$logfile\": Count of Matches -> $matches ");
	             $main::failure_msg .= "UNKNOWN:Base-Failed to Match $pat; ";
                     $flag = 1;
                 }
             }else {
                 if ( $matches >= $logstringcount[$pattern] ) {
                     $logger->debug(__PACKAGE__ . ".$sub_name: Expected count,'$logstringcount[$pattern]' MATCHES for \"$pat\" in \"$logfile\": Count of Matches -> $matches");
                 } else {
                     $logger->debug(__PACKAGE__ . ".$sub_name: Expected count,'$logstringcount[$pattern]' NOT MATCHES for \"$pat\" in \"$logfile\": Count of Matches -> $matches");	
	             $main::failure_msg .= "UNKNOWN:Base-Failed to Match $pat; ";
                     $flag = 1;
                 }
             }
             push @match,$matches;
         }
     }
     $self->{conn}->cmd("cd"); #coming ot of evlog directory
     if($flag){
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
         return (\@match,0);
     }else{
         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
         return (\@match,1);
     }
}

=head2 C< verifyDecodeMessage() >

=over

=item DESCRIPTION:

    Provides the Decoded result by runing the decodeTool for given parameter.

=item Arguments :

   Mandatory :
        -LogFile - Full path of the log file to check the pattern in.
        -RawData - '01 10 21 01 0a 00 02 07 05 01 90 59 83 f8 0a 05 81 12 59 83 08 08 01 00 1d 03 80 90 a3 31 02 00 4a c0 09 06 84 10 33 76 68 33 42 09 3d 01 0e 39 06 3d c0 31 90 c0 d4 00'
        -String - Strings to be matched in the decoded output
        -Variant - protocol variant  can be japan,ansi,china,itu,bt etc 
   Optional :
        -NoRoute - no route option can only be used with the no Logfile
        -ReverseCheck => 1      this argument should be set if the pattern not found need to be considered as true

=item Return Values :

   0 - Failed
   1 - Success

=item Example :

 Example for Raw Data:
   my %params = (  -RawData  => '01 11 48 00 0a 03 02 0a 08 83 90 89 04 04 00 00 0f 0a 07 03 13 99 54 04 00 00 1d 03 90 90 a3 31 02 00 18 c0 08 06 03 10 99 54 04 00 00 39 04 31 90 c0 84 00',
                   -String    => ['SCCP Method Indicator-0x1','Simple Segmentation Indicator-0x0'],
                   -Variant   => 'itu',
                   -NoRoute    => 1
                );

   $Obj->verifyDecodeMessage(%params);

   my %params = (   -LogFile  => '/export/home/SonusNFS/WODEYAR/evlog/2019116661/DBG/1000017.DBG',
                   -String    => { 'IAM' => {
                                                'SENT'          => ['SCCP Method Indicator-0x1','Simple Segmentation Indicator-0x0'],
                                                'RECEIVED'      => ['SCCP Method Indicator-0x1','Simple Segmentation Indicator-0x0'],
                                               },
                                      'ACM' => {
                                                'SENT'          => ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0'],
                                                'RECEIVED'      => ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0'],
                                               },
                                      'ANM' => {
                                                'SENT'          => ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0'],
                                               },
                                    },
                   -Variant   => 'itu',
   );

   $Obj->verifyDecodeMessage(%params);

                                                   or

   my %params = (   -LogFile  => '/export/home/SonusNFS/WODEYAR/evlog/2019116661/DBG/1000017.DBG',
                   -String    => { 'IAM' => {
                                                'SENT'          => {'Parameter Code     [0x121]' => ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0']},
                                               },
                                      'ACM' => {
                                                'SENT'          => {'Parameter Code     [0x121]' => ['SCCP Method Indicator-0x0','Simple Segmentation Indicator-0x0']},},
                                               }
                                    },
                   -Variant   => 'itu',
   );

   $Obj->verifyDecodeMessage(%params);

=back 

=cut

sub verifyDecodeMessage{
     my ($self) = shift;
     my ($TRCfile, @output, $type, $flag, $sent_received, $log_file, %pattern, $log_path);
     my $sub_name = "verifyDecodeMessage";
     my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
     $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

     my (%args, $cmd) = @_;
     unless ($args{-LogFile} or $args{-RawData}) {
          $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument Log File and Raw Data empty or blank, Please pass one of them.");
 	  $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	  return 0;
     }
     unless ($args{-Variant} or $args{-ConfigFile}) {
	  $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument protocol variant and configuration file are empty or blank, Please pass one of them.");
	  $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	  return 0;
     }
     unless ($args{-String}) {
	  $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument Matching String is empty or blank.");
	  $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	  return 0;
     }
         
     my $decodeTool = ($args{-DecodeTool}) ? $args{-DecodeTool} : $self->{DECODETOOL};
     if(defined $main::TESTSUITE->{PATH}){
         $log_path = $main::TESTSUITE->{PATH} . "\/logs";
         unless ($main::TESTSUITE->{PATH}) {
             $logger->error(__PACKAGE__ . ".$sub_name: unable to find the log path");
             return 0;
         }
     }
     if ($args{-LogFile}) {
          if ($args{-LogFile} =~ /\,/) {
               $logger->debug(__PACKAGE__ . "$sub_name : two files passes for comaprision -  $args{-LogFile}");
               my @logfiles = split(',',$args{-LogFile});
               $cmd = "$decodeTool -o -dbg1 $logfiles[0] -dbg2 $logfiles[1] -d ";
          } else {
	       $log_file = $args{-LogFile};
               $log_file =~ s/\s//g;
	       
               if ($args{-LogFile} =~ /TRC$/i) {
    	            $cmd = "cat $log_file | $decodeTool -D ";
	            $TRCfile = 1;
	       } else {
	            $cmd = "cat $log_file | $decodeTool -d ";
	       }
          }
     } else {
          $cmd = "$decodeTool ";
     }
    	
     unless ($TRCfile) {
	  $cmd .= $args{-ConfigFile} ? "-cfg $args{-ConfigFile} " :"-p $args{-Variant} ";
	  $cmd .= "-nofile " unless ($args{-LogFile});
	  $cmd .= "-noroute " if ($args{-NoRoute} and !$args{-LogFile});
     }
    
     $logger->debug(__PACKAGE__ . ".$sub_name: Passed Arguments are : " .  Dumper(\%args));
     if($log_path){   
         if ($args{-LogFile} =~ /\,/) { 
             $cmd .= " | tee $log_path\/decoded_for_comparision.txt" unless ($args{-RawData});
         }else{
             $cmd .= " | tee $log_path\/decoded_$log_file" unless ($args{-RawData});
         }
     }
     $logger->debug(__PACKAGE__ . ".$sub_name: Command framed is : " .  $cmd);
     my $fail_var = ($args{-ReverseCheck})? '':'not' ;
     my $pass_var = ($args{-ReverseCheck})? 'not':'' ;
     if ($args{-RawData} ) {
         $self->{conn}->print($cmd);
     
         my ($prematch, $match) = $self->{conn}->waitfor( -match     => '/Please enter Raw Data.*\>/i',
                                                          -match     => '/\[error\]/',
                                                          -match     => $self->{PROMPT},
                                                          -timeout   => $self->{DEFAULTTIMEOUT}
                                                        );
     
         if ( $match =~ m/Please enter Raw Data.*\>/i ) {
               $self->{conn}->print($args{-RawData});
               ($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{PROMPT} , -timeout   => $self->{DEFAULTTIMEOUT});
         } elsif ( $match =~ m/\[error\]/) {
               $logger->debug(__PACKAGE__ . ". $sub_name \'$cmd\' command error:\n$prematch\n$match");
               $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
               $self->{conn}->waitfor( -match => $self->{PROMPT},  -timeout   => $self->{DEFAULTTIMEOUT});
	       $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Failed to Decode RawData; ";
               return 0;
         }    
         @output = split ('\n', $prematch);
         foreach (@{$args{-String}}) {
             my @string_addr = split('-', $_);
             my $string_found = grep (/$string_addr[0]\s+$string_addr[1]/i, @output) ;
             $string_found = ($string_found)? 1 : 0;
             if (!($args{-ReverseCheck} ^ $string_found)) {
                 $logger->error(__PACKAGE__ . ".$sub_name: search pattern  $_ $fail_var present in decoded result");
                 $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Pattern $fail_var present";
                 return 0;
             }
         }
         $logger->debug(__PACKAGE__ . ".$sub_name: search  $pass_var pattern found in decoded result");
         return 1;
     } else {
         @output = $self->{conn}->cmd($cmd);
     }

     my $match_variant = (defined $args{-Variant} and $args{-Variant}) ? $args{-Variant} : '';
     my %temp_string = %{$args{-String}};
     my %occurence;
     foreach my $line (@output) {
         $flag = 1 if ($line =~ /SONUS.*$match_variant.*LOGFILE DECODE BEGIN/i);
         next unless ($flag);
         if($line =~ /ISUP MESSAGE \= \[\s(\w+)\s\]\s+(\w+)/i) {
             $type = $1;
             $sent_received = $2;
             $occurence{$type}{$sent_received}++;
         }
     # Storing the ISUP Message for different occurences into to different array references
        if($temp_string{$type}->{$sent_received}{occurrence}){
             push (@{$pattern{$type}{$sent_received}{$occurence{$type}{$sent_received}}}, $line)  if $type;
        }
        else{
            push (@{$pattern{$type}{$sent_received}{0}}, $line)  if $type;
        }
         $flag = 0 if ($line =~ /SONUS.*$match_variant.*LOGFILE DECODE END/i);
     }
     my ($occurence,$temp);
   #Checking for pattern in any given occurrence of ISUP Message. 
     my $result = 1; 
     foreach my $temp_type (keys %temp_string) {
         foreach my $sent_received (keys %{$temp_string{$temp_type}}) {
             if($temp_string{$temp_type}->{$sent_received}{occurrence}){
                 $occurence = $temp_string{$temp_type}->{$sent_received}{occurrence};
                 $temp = $temp_string{$temp_type}->{$sent_received}{pattern};
             }
             else{
                $occurence = 0; #If user dont pass occurence for any Type of ISUP message, Default Occurence is taken as '0'
                 $temp = $temp_string{$temp_type}->{$sent_received};
             }
             if (ref ($temp) eq 'ARRAY') {
                 $logger->debug(__PACKAGE__ . ".$sub_name: you are searching without parameter code");
                 foreach (@{$temp}) {
                    my @string_addr = split('-', $_);
                    my $found_string = grep (/($string_addr[0]\s+$string_addr[1]|$string_addr[1]\s*\|\s*$string_addr[0])/i, @{$pattern{$temp_type}{$sent_received}{$occurence}}) ;
                    unless($args{-ReverseCheck} ^ $found_string) {
                       $logger->error(__PACKAGE__ . ".$sub_name: search pattern $_ $fail_var present in decoded result");
                       $logger->error(__PACKAGE__ . ".$sub_name: failed for Address Presentation Restricted Indicator in ISUP MESSAGE = [ $temp_type ]   $sent_received");
		       $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Pattern $fail_var present.";
                       $result = 0; 
                       last;
                    }
                 }
             } elsif (ref ($temp) eq 'HASH') { 
                 $logger->debug(__PACKAGE__ . ".$sub_name: you are searching for specific paramete code");
                 foreach my $parmeter_code (keys %{$temp}) {
                     my $p_code = $parmeter_code;
                     $p_code =~ s/\s+/.*/g; #replace all space or tab with .*, to take care of extra space from user
                     $p_code =~ s/\[/\\[/g; # i make [ as normal string for regex
                     my %found = (); # to hold the occurance and non-occurance of search pattern
                     my $found_pcode = 0; # falg to indicate parameter code start and end
                     CONTENT:  foreach my $line (@{$pattern{$temp_type}{$sent_received}{$occurence}}) {
                         if ($found_pcode and $line =~ /Parameter Code/i) {
                             $found_pcode = 0; #reset the falg back when the next parameter code occurs
                             #last CONTENT; #commenting to continue the check, there might be multiple occureance of same parameter code
                         }
                         $found_pcode = 1 if ($line =~ /$p_code/);
                         next unless $found_pcode; #continue only if its of required parameter code
                         foreach (@{$temp->{$parmeter_code}}) {
                             my @string_addr = split('-', $_);
                             $found{$_} =1 if ($line =~ /($string_addr[0]\s+$string_addr[1]|$string_addr[1]\s*\|\s*$string_addr[0])/i); #says i found the pattern
                             $found{$_} = 0 unless (defined $found{$_}); #search pattern not found
                         } 
                     }
                     foreach (keys %found) {
                         unless ($args{-ReverseCheck} ^ $found{$_}){
                             $logger->error(__PACKAGE__ . ".$sub_name: search pattern $_ $fail_var found for $parmeter_code -> $sent_received -> $temp_type");
         		     $main::failure_msg .= "UNKNOWN:SBX5000HELPER-Pattern $fail_var present ";
                             $result = 0;
                             last;
                         }
                     }
                     unless (keys %found) {
                         unless ($args{-ReverseCheck}) {
                             $logger->error(__PACKAGE__ . ".$sub_name: parameter code $parmeter_code not found for $sent_received -> $temp_type");
                             $result = 0;
                             last;
                         }else {
                             $logger->info(__PACKAGE__ . ".$sub_name: parameter code $parmeter_code not found for $sent_received -> $temp_type");
                         }
                     }
                 }
             }
             last unless($result) ;
         }
         last unless($result);
     }
    $logger->debug(__PACKAGE__ . ".$sub_name: search pattern $pass_var found in decoded result") if ($result);
    return $result; 
}

=head2 C< loginToHost >

=over

=item DESCRIPTION:

 This subroutine is used to login to the host using sftp or ssh.

=item ARGUMENTS:

 -host - IP address of the server to login
 -user - username
 -pass - the password to login
 -comm_type - sftp or ssh
 -port (Optional) - Port used inorder to login (Default Value - 22)

=item PACKAGE:

 SonusQA::Base

=item OUTPUT:

 0   - fail 
 ($match, 0) - In case of 'Connection refused' or 'closed by remote host|Connection reset by peer'
 1   - success

=item EXAMPLES:

 my %args = (-host => '10.54.213.33', -user => 'ssuser', -pass => 'ssuser', -comm_type => 'sftp', -port => '223');

 1)  unless($obj->loginToHost(%args)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to login");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
 2) unless(($match, $retval) = $obj->loginToHost(%args)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to login");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
    if($match =~ /Connection refused/i){
        $logger->error(__PACKAGE__ . ".$sub_name: Connection refused by host");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
        return 1;
    }elsif($match =~ /closed by remote host|Connection reset by peer/i){
        $logger->error(__PACKAGE__ . ".$sub_name: Connection closed by host");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }


=back

=cut

sub loginToHost{
    my ($self, %args) = @_;
    my $sub_name = "loginToHost";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 1;
    foreach('-host', '-user', '-pass', '-comm_type'){
        unless($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument $_ is empty or blank");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            $flag = 0;
            last;
        }
    }
    return 0 unless ($flag);
    my ($prematch, $match, $retries);
	$args{-port} ||= 22;
	my $port_opt = ($args{-comm_type} eq 'sftp' or $args{-comm_type} eq 'scp') ? " -P $args{-port}" : " -p $args{-port}"; 
RETRY:
    unless($self->{conn}->print("$args{-comm_type} $port_opt -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $args{-user}\@$args{-host}")){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to $args{-comm_type} to $args{-host} with user: $args{-user}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
    unless(($prematch, $match) = $self->{conn}->waitfor( -match     => '/password\:/i',
                                                         -match     => '/Connection refused/i',
                                                         -timeout   => $self->{DEFAULTTIMEOUT},
                                                       )) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to match one of the expected patterns: 'password:' or 'Connection refused'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
    if($match =~ /Connection refused/i){
        $logger->error(__PACKAGE__ . ".$sub_name: Unable to connect to $args{-host}. Connection refused");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return ($match, 0);
    }elsif($match =~ /password\:/i){
        unless($self->{conn}->print($args{-pass})){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to enter password");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }
    }
    unless(($prematch, $match) = $self->{conn}->waitfor( -match     => $self->{DEFAULTPROMPT},
                                                         -match     => '/closed by remote host|Connection reset by peer/i',
                                                         -timeout   => $self->{DEFAULTTIMEOUT},
                                                       )) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to match any of the patterns");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
    if($match =~ /closed by remote host|Connection reset by peer/i){
        unless($retries == 1){
            $logger->debug(__PACKAGE__ . ".$sub_name: Prematch contains 'closed by remote host' or 'Connection reset by peer'. Trying to connect again");
            $retries++;            
            goto RETRY;
        }else{
            $logger->error(__PACKAGE__ . ".$sub_name: Connection closed by remote host even after retrying");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return ($match, 0);
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Successfully logged into the host $args{-host}");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}

=head2 C< execCmdWait >

=over

=item DESCRIPTION:

        JIRA ID : TOOLS-18573.
        Generic subroutine, to get the list of the commands and its respective match and value from the User.
        If the last match is not mentioned, ATS will match with Objects connection Prompt.
	
=item ARGUMENTS:

 Mandatory :

    -list => Array reference of cmd and subsequent match and its respective value is passed.

             If the array size is Even -> We will end with the user passed prompt match, else
                                  Odd  -> At the end, We will wait for the Objects connection PROMPT.

            Example:
                1st Format : For a command, subsequent match and value is passed .
                        (
                        'command',
                        'match1',
                        'value1,'
                        'match2',
                        'value2'
                        'match3'
                        );
                2nd Format : For last value, alone match is not passed.
                              We will use the connection objects PROMPT.
                        (
                        'command',
                        'match1',
                        'value1'
                        'match2',
                        'value2'
                        );

 Optional :

    -timeout => Maximum time to wait for the prompt to come. 
                picks DEFAULTTIMEOUT, if -timeout is empty.
		Example : -timeout => 30 #waits max 30s for the prompt to come.

=item PACKAGE:

    SonusQA::Base

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    (@cmd_result,1) - success
    (@cmd_result,0) - failure

=item EXAMPLES:

1.Directly checking the function return value

    my @list = (
                'set system virtualMediaGateway VMG1 mediaGatewayController MGC_Pri role primary',
                'Value for \'ipAddressV4\' \(\<IPv4 Address\>\)',
                "\cC", # passes ctrl+c
    );
    unless($sbc_obj->execCmdWait( -timeout => 10, -list => \@list )){
        $logger->error(__PACKAGE__ . ".$sub_name: execCmdWait ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
  
2.Fetching the output then checking the return value

    my @list = (
		'cd /ats_repos/lib/perl/SonusQA/'
    );
    my (@cmd_result, $return) = $sbc_obj->execCmdWait( -timeout => 10, -list => \@list );
    unless($return){
        $logger->error(__PACKAGE__ . ".$sub_name: execCmdWait ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
  
3.Without passing the timeout value, ATS will pick the default timeout value.

    my @list = (
                'cd /ats_repos/lib/perl/SonusQA/'
    );
    my (@cmd_result, $return) = $sbc_obj->execCmdWait( -list => \@list );
    unless($return){
        $logger->error(__PACKAGE__ . ".$sub_name: execCmdWait ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }


=back

=cut

sub execCmdWait{
    my ($self) = shift;
    my $sub = 'execCmdWait';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
    my %args = @_;
    my $flag = 1;
    my @list = @{$args{-list}};
    my ($prematch, $match, @cmd_result);

    for( my $i = 0; $i < @list; $i += 2){


        $logger->debug(__PACKAGE__ . ".$sub: Executing for $list[$i] ");
        unless($self->{conn}->print($list[$i])){
            $logger->error(__PACKAGE__ . ".$sub: Unable to print: $list[$i]");
            $flag = 0;
            last;
        }
        last if($i == $#list);#Current index equals last index then come out of the loop.
        $logger->debug(__PACKAGE__ . ".$sub:  Waiting for $list[$i+1]");
        unless(($prematch, $match) = $self->{conn}->waitfor(
                                                            -match => "/$list[$i+1]/",
                                                            -timeout => $args{-timeout} || $self->{DEFAULTTIMEOUT}, 
                                                       )){
            $logger->error(__PACKAGE__ . ".$sub: Unable to match: $list[$i+1] ");
            $flag = 0;
            last;
        }

    }
    if(@list % 2 == 1){#Coz at last if user dont need any special match for waitfor we will add the $self->{PROMPT}
        unless(($prematch, $match) = $self->{conn}->waitfor(
                                                            -match => $self->{PROMPT},
                                                            -timeout => $args{-timeout} || $self->{DEFAULTTIMEOUT},
                                                       )){
            $logger->error(__PACKAGE__ . ".$sub: Unable to match: $self->{PROMPT} ");
            $flag = 0;
        }	
    }

    unless($flag){
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
    }
    @cmd_result = split("\n",$prematch);
    shift @cmd_result;
    @cmd_result = grep /\S/,@cmd_result;
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
    return ( @cmd_result, $flag);
}

=head2  execShellCmd()

=over

=item DESCRIPTION:

 The function is a wrapper around execCmd for the SBX5000 linux shell. The function issues a command then issues echo $? to check for a return value. The function will then return 1 or 0 depending on whether the echo command yielded 0 or not. Ie. in the shell 0 is pass (and so the perl function returns 1) any other value is fail (and so the perl function returns 0). In the case of timeout 0 is returned. The command output from the command is then accessible from $self->{CMDRESULTS}.

=item ARGUMENTS:

 1. The command to be issued to the CLI

=item PACKAGE:

 SonusQA::SBX5000

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - success
 0 - failure

 $self->{CMDRESULTS} - CLI output
 $self->{LASTCMD}    - CLI command issued

=item EXAMPLE:

 my @result = $obj->execShellCmd( "ls /opt/sonus" );

=back

=cut

sub execShellCmd {

    # Due to the frequency of running this command there will only be log output
    # if there is a failure

    # If successful ther cmd response is stored in $self->{CMDRESULTS}

    my $sub_name     = "execShellCmd";
    my ($self,$cmd) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered sub");

    if ($self->{D_SBC}) {
        my @dsbc_arr = $self->dsbcCmdLookUp($cmd);
        my @role_arr = $self->nkRoleLookUp($cmd) if($self->{NK_REDUNDANCY});
        my %hash = (
                        'args' => [$cmd],
                        'types'=> [@dsbc_arr],
                        'roles'=> [@role_arr]
                );
        my $retVal = $self->__dsbcCallback(\&execShellCmd, \%hash);
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$retVal]");
        return $retVal;
    }
    my (@result);

    #Fix for TOOLS-3643.  Removing '>' and '%' from prompt which is not needed in linuxadmin or root sessions
    my $prev_prompt = $self->{conn}->prompt('/.*[#\$>] $/');
    $logger->debug(__PACKAGE__ . ".$sub_name: Changed the connection prompt to '". $self->{conn}->prompt ."'. Previous prompt : $prev_prompt");

    @result = $self->execCmd( $cmd );

    # Reverting the prompt to original after execution of shell command (TOOLS-3643)
    $self->{conn}->prompt($prev_prompt);
    $logger->debug(__PACKAGE__ . ".$sub_name: Changed the connection prompt back to original : ". $self->{conn}->prompt );

    foreach ( @result ) {
        chomp;

        if ( /error/ || /^\-bash:/ || /: command not found$/ || /No such file or directory/) {
            $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR \($cmd\): --\n@result");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $main::failure_msg .= "UNKNOWN:SBX5000-Cli command error; ";
            return 0;
        }
    }

    # Save cmd output
    my $command_output = $self->{CMDRESULTS};



    # So far so good then... now check the return code
    unless ( @result = $self->execCmd( "echo \$?" ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR. Could not get return code from `echo \$?`. No return information");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000-Echo command error; ";
        return 0;
    }
    unless ( $result[0] == 0 ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  CMD ERROR: return code $result[0] --\n@result");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        $main::failure_msg .= "UNKNOWN:SBX5000-Command error; ";
        return 0;
    }

    # Put the result back in case the user wants them.
    $self->{CMDRESULTS} = $command_output;

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 setPrompt

=over

=item DESCRIPTION:
  
    #TOOLS-18755
    This subroutine sets the 'AUTOMATION>' as Prompt.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::Base

=item OUTPUT:

    1 - Success
    0 - Failure

=item EXAMPLE:

  $obj->setPrompt(); #set 'AUTOMATION> ' as prompt

=back

=cut

sub setPrompt {
    my $self = shift;

    my $sub_name = 'setPrompt';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    $self->{conn}->cmd("bash");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    my $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub_name:  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    $self->{conn}->cmd('export PS1="AUTOMATION> "');
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 1);
    $logger->info(__PACKAGE__ . ".$sub_name:  SET PROMPT TO: " . $self->{conn}->last_prompt);

    # Fix for TOOLS-2652. Moved the below code from PSX::setSystem()
    # In PSX new build (Linux os) PROMPT_COMMAND has set by default as printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/~}".
    # Because of this, non printable characters ('[]0;ssuser@KRUSTY:~') coming before the prompt 'AUTOMATION> '. So unsetting PROMPT_COMMAND
    $self->{conn}->cmd("unset PROMPT_COMMAND");
    $self->{conn}->cmd('unalias grep');

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1 ;
}

=head2 exitUser

=over

=item DESCRIPTION:

    TOOLS-18820
    This subroutine exits from the current user.
	For PSX/EMS, inaddition to exit, it will enter to $self->{OBJ_USER}.

=item ARGUMENTS:

 Mandatory :

    None

 Optional :

    None

=item PACKAGE:

    SonusQA::Base

=item OUTPUT:

    1 - Success
    0 - Failure

=item EXAMPLE:

  $obj->exitUser();

=back

=cut

sub exitUser {
    my $self = shift;

    my $sub_name = 'exitUser';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $cmd = 'id';
    my @cmdresults;
    my $flag = 1;

    unless ( @cmdresults = $self->{conn}->cmd(String => $cmd, Prompt => $self->{DEFAULTPROMPT}) ) #TOOLS-18755 changed execCmd to conn->cmd. Because for SBC we will run SQL commands with Root object, which is a Base Object and Base dont have execCmd.
    {
        $logger->error( __PACKAGE__ . ".$sub_name: failed to execute the command : $cmd" );
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub_name Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__.'->'.__LINE__."::$sub_name Session Input Log is: $self->{sessionLog2}");
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [0]" );
        return 0;
    }

    if ( grep( /uid=\d+\($self->{OBJ_USER}/, @cmdresults ) )
    {
        $logger->debug( __PACKAGE__ . ".$sub_name: You are already logged in as $self->{OBJ_USER}" ) ;
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving sub [1]" );
        return 1;
    }

    if($self->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} =~ /(PSX|EMS)/i){
	unless( $self->becomeUser( -userName => $self->{OBJ_USER}, -password => $self->{OBJ_PASSWORD} ) ){
            $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as $self->{OBJ_USER}.");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;            
        }
    }else{
        foreach('exit','exit'){ #TOOLS-75332
            unless( $self->{conn}->cmd( String => $_, Prompt => $self->{DEFAULTPROMPT}) ){
            $logger->error(__PACKAGE__ . ".$sub_name:  failed to issue exit.");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            $flag =0;
            last;  
            }
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag ;
}

=head2 C< verifyTable >

=over

=item DESCRIPTION:

        This subroutine helps to verify the output got from cmd passed by the user.

=item ARGUMENTS:

 Mandatory :

        $cmd - cmd to be executed ,
        $cliHash - expected values should be passed as a key-value pair.

 Optional :

        $mode - if value is 'private', it will enter to the config(private) mode in SBC.
        retry_count - cliHash key to  count the number of retries, default is 12.
        retry_sleep - cliHash key for the dutation of sleep after every retry, default is 1s.

=item PACKAGE:

    SonusQA::SBX5000::SBX5000HELPER

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success
=item EXAMPLE:

  $obj->verifyTable($cmd,$cliHash,$mode);

=back

=cut
sub verifyTable {

    my ($self,$cmd,$cliHash,$mode) = @_ ;
    my $sub_name = "verifyTable";
    my $type=$self->{TYPE};
    my (@output,$key,$value,@value,%returnhash);
    my $flag = 0;
    my %cliHash = %$cliHash;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $logger->debug(__PACKAGE__ . ".$sub_name: Args : ". Dumper($cmd,$cliHash,$mode));
    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cmd ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory CLI command empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $cliHash ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory Hash Reference empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my $retry_count = delete($cliHash{'retry_count'}) || 12;
    my $retry_sleep = delete($cliHash{'retry_sleep'}) || 1;
########  Execute input CLI Command #########################################

    if ($mode =~m/private/) {
    $self->execCmd("configure private");
    @output = $self->execCmd($cmd);
    $self->leaveConfigureSession;
    }
    else {
    @output = $self->execCmd($cmd);
    }

    if($self->{D_SBC}){
    #TOOLS-8401 : replacing S_SBC ip with M_SBC ip
        if(exists $cliHash{'ingressMediaStream1LocalIpSockAddr'}){
            my $old_ingress = $cliHash{'ingressMediaStream1LocalIpSockAddr'};
	    if($self->{S_SBC}->{1}->{TMS_ALIAS_DATA}->{PKT_NIF}->{1}->{IPV6} =~ m/$cliHash{'ingressMediaStream1LocalIpSockAddr'}/ ){
                 $cliHash{'ingressMediaStream1LocalIpSockAddr'} =~ s/$self->{S_SBC}->{1}->{TMS_ALIAS_DATA}->{PKT_NIF}->{1}->{IPV6}/$self->{M_SBC}->{1}->{TMS_ALIAS_DATA}->{PKT_NIF}->{1}->{IPV6}/;
            }elsif($self->{S_SBC}->{1}->{TMS_ALIAS_DATA}->{PKT_NIF}->{1}->{IP} =~ m/$cliHash{'ingressMediaStream1LocalIpSockAddr'}/ ){
                $cliHash{'ingressMediaStream1LocalIpSockAddr'} =~ s/$self->{S_SBC}->{1}->{TMS_ALIAS_DATA}->{PKT_NIF}->{1}->{IP}/$self->{M_SBC}->{1}->{TMS_ALIAS_DATA}->{PKT_NIF}->{1}->{IP}/;
            }
$logger->debug(__PACKAGE__ . ".$sub_name: Changed '$old_ingress' to '$cliHash{'ingressMediaStream1LocalIpSockAddr'}' for 'ingressMediaStream1LocalIpSockAddr' since it is D_SBC" );
        }
        if(exists $cliHash{'egressMediaStream1LocalIpSockAddr'}){
            my $old_egress = $cliHash{'egressMediaStream1LocalIpSockAddr'};
            if($self->{S_SBC}->{1}->{TMS_ALIAS_DATA}->{PKT_NIF}->{2}->{IPV6} =~ m/$cliHash{'egressMediaStream1LocalIpSockAddr'}/ ){
                $cliHash{'egressMediaStream1LocalIpSockAddr'} =~ s/$self->{S_SBC}->{1}->{TMS_ALIAS_DATA}->{PKT_NIF}->{2}->{IPV6}/$self->{M_SBC}->{1}->{TMS_ALIAS_DATA}->{PKT_NIF}->{2}->{IPV6}/;   
            }elsif($self->{S_SBC}->{1}->{TMS_ALIAS_DATA}->{PKT_NIF}->{2}->{IP} =~ m/$cliHash{'egressMediaStream1LocalIpSockAddr'}/){
                $cliHash{'egressMediaStream1LocalIpSockAddr'} =~ s/$self->{S_SBC}->{1}->{TMS_ALIAS_DATA}->{PKT_NIF}->{2}->{IP}/$self->{M_SBC}->{1}->{TMS_ALIAS_DATA}->{PKT_NIF}->{2}->{IP}/;
            }
         $logger->debug(__PACKAGE__ . ".$sub_name: Changed $old_egress to $cliHash{'egressMediaStream1LocalIpSockAddr'} for 'egressMediaStream1LocalIpSockAddr' since it is D_SBC");
        }
        if($cmd =~ /ipAccessControlList rule/i){           #Fix for TOOLS-14515 to change key only if its ipACL
        #Fix for TOOLS-13152 to change key for DSBC
            $cliHash{'destIpAddress'} = delete $cliHash{'destinationIpAddress'} if(exists $cliHash{'destinationIpAddress'});
            $cliHash{'destIpAddressPrefixLength'} = delete $cliHash{'destinationAddressPrefixLength'} if(exists $cliHash{'destinationAddressPrefixLength'});
        }
    }
    my ($count, %prev_val);
RETRY:
    my $execute_again = 0;
    my (@grep_result, %verifyHash);
    if ($mode =~ m/private/) {
        $self->execCmd("configure private");
        @output = $self->execCmd($cmd);
        $self->leaveConfigureSession;
    }else {
        @output = $self->execCmd($cmd);
    }
    foreach $key (keys %cliHash) {
        $returnhash{$key} = $cliHash{$key};
        unless (@grep_result = grep(/\Q$key\E.+\Q$cliHash{$key}\E/i, @output)) {
            $logger->debug(__PACKAGE__ . ".$sub_name: Key: $key checking if Expected value is a range.");
            if (@grep_result = grep(/\Q$key\E.+/i, @output)) {
                 $logger->debug(__PACKAGE__ . ".$sub_name: possible actual match for key is");
                if( $grep_result[0] =~ /\Q$key\E\s*(.*)\s*.*$/){
                    my $value = $1;
                    $value =~ s/\s+$//g;
                    $value =~ s/^\s*|(\;|\s*\{\s*)$//g;
                    $returnhash{$key} = $value;
                    if (ref ($cliHash{$key}) eq "ARRAY") {
  			my @range = @{$cliHash{$key}};
                        if ($value >= $range[0] and $value <= $range[1]) {
                             $logger->debug(__PACKAGE__ . ".$sub_name: key: '$key' Value: $value is in the range $range[0] and $range[1] MATCH SUCCESS!!");
                        }
                        else {
                            $logger->debug(__PACKAGE__ . ".$sub_name: key: '$key' Value: $value is not in range $range[0] and $range[1] MATCH FAILED!!");
                            $main::failure_msg .="UNKNOWN: $type Failed to match $key; ";
                            $flag = 1;
                        }
                    }else {
                        $logger->debug(__PACKAGE__ . ".$sub_name: Key: '$key' Returning value : '$returnhash{$key}' MATCH FAILED!!");
                        $main::failure_msg .= "UNKNOWN: $type Failed to match $key; ";
                        $flag = 1;
                    }
                    if($flag && ($key =~ /(ingressMediaStream1PacketsSent|ingressMediaStream1PacketsReceived|egressMediaStream1PacketsSent|egressMediaStream1PacketsReceived)/)){
                        if($prev_val{$key}{'value'} && $prev_val{$key}{'value'} != $value){
                            $logger->debug(__PACKAGE__ . ".$sub_name: Previous value for $key: '$prev_val{$key}{'value'}' not same as current value: '$value'");
                            $prev_val{$key}{'count'} = 1;
                        }else{
                            $logger->debug(__PACKAGE__ . ".$sub_name: Previous value for $key: '$prev_val{$key}{'value'}' same as current value: '$value'");
                            $prev_val{$key}{'count'}++;
                        }
                        if($count <= $retry_count){
                            if($prev_val{$key}{'count'} == 3){
                                $logger->debug(__PACKAGE__ . ".$sub_name: Previous 2 values for $key same as the current value. No increase in value even after sleep");
                                $flag = 1;
                            }else{
                                $execute_again = 1;
                                $verifyHash{$key} = $cliHash{$key};
                                $prev_val{$key}{'value'} = $value;
                                $flag = 0;
                            }
                        }
                    }
                }
            }
            else {
                $logger->debug(__PACKAGE__ . ".$sub_name: Key: $key  MATCH FAILED, there is no key: $key");
                $main::failure_msg .= "-Failed to match $key; ";
                $flag = 1;
            }
        } else {
            $logger->debug(__PACKAGE__ . ".$sub_name: Key: $key Expected: $cliHash{$key}  MATCH SUCCESS !!");
        }
    }
if($flag){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return (\%returnhash,0);
    }elsif($execute_again){
        $logger->debug(__PACKAGE__ . ".$sub_name: Looping through the unmatched values again");
        %cliHash = %verifyHash;
        $count++;
        $logger->debug(__PACKAGE__ . ".$sub_name: Sleeping for $retry_sleep. Count ($count/$retry_count)");
        sleep($retry_sleep);
        goto RETRY;
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return (\%returnhash,1);
    }

}
=head2 C< ftpFiles >

=over

=item DESCRIPTION:

        This subroutine helps to send files from local to remote server and vice versa.

=item ARGUMENTS:

 Mandatory :

        '-remoteip' => 'This is the ip where we need to perform pftp or sftp operation',
        '-remoteuser' => 'Username of the remote machine',
        '-remotepasswd' => 'Password of the remote machine', 
        '-sourceFilePath' => 'This is the path where all files needs to be present before performing put operation', 
        '-remoteFilePath' => 'This is the path where all files needs to be present before performing get opeartion', 
        '-type'  => 'Type of opeartion which has to be performed either get or put',
        '-files' =>'Array of files which has to be transferred '

 Optional :
         '-pftp' = 1. for performing pftp opeartion 
          sftp opeartion will happen if not passed.

=item PACKAGE:

    SonusQA::Base

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    0   - fail
    1   - success
=item EXAMPLE:

my %args;
     $args{-remoteip}      = "172.28.218.19";
     $args{-remoteuser}    = "sgsnds";
     $args{-remotepasswd}  = "sgsnds";
     $args{-sourceFilePath} = "/export/home/medadmin/sampleData/Telus-Samples/";
     $args{-remoteFilePath} = "/export/meddata/incoming/";
     $args{-type} = "put";
     $args{-timeout} = 360;
     $args{-files} = ['020165.U180306020276AMA' , '020031.030001.29187.01.2']

      unless($obj->ftpFiles(\%args)){
          $logger->error(__PACKAGE__ ".$sub_name: Unable to call function");
      }

=back

=cut

sub ftpFiles {
	
    my ($self, %args) = @_;
    my $sub_name = "sftpFiles";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    $args{-timeout} = $args{-timeout} || 60;

    my $flag = 1;
    foreach('-remoteip', '-remoteuser', '-remotepasswd', '-sourceFilePath', '-remoteFilePath', '-type', '-files'){ #Checking for the parameters in the input hash
        unless(defined $args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    unless($flag){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my (@cdres);
    @cdres = $self->execCmd("cd $args{-sourceFilePath}");
    if(grep /No such file or directory/, @cdres)
    {
        $logger->error(__PACKAGE__. ".$sub_name  File Not Found");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my ($cmd_new ,$prompt);
    if($args{-pftp}){
        $cmd_new = "pftp $args{-remoteip}";
        $prompt = '/ftp>/';
    }else{
        $cmd_new = "sftp $args{-remoteuser}\@$args{-remoteip}";
        $prompt = '/sftp>/';
     }
    unless ($self->{conn}->print($cmd_new)) {
	$logger->error(__PACKAGE__ . ".$sub_name: Cannot execute command '$cmd_new' ");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
	return 0;
    }
    my ($prematch, $match);
WAITFOR_PASSWORD:
    unless(($prematch, $match) = $self->{conn}->waitfor( -match => '/Name.*/' ,
                                                         -match => '/[P|p]assword:/' ,
                                                         -match => '/.*want to continue connecting/')){
        $logger->error(__PACKAGE__. ".$sub_name: Couldn't match Name or password");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    if($match =~ /Name.*/){
        unless($self->{conn}->print($args{-remoteuser})){
            $logger->error(__PACKAGE__. ".$sub_name: Failed to print Username");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name: Waiting for password prompt");
        goto WAITFOR_PASSWORD;
   }

    if($match =~/.*want to continue connecting/){
        unless($self->{conn}->print("yes")){
            $logger->error(__PACKAGE__. ".$sub_name: Failed to print yes");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
        goto WAITFOR_PASSWORD;
   }
    if($match =~ /[P|p]assword:/){
        unless($self->{conn}->print("$args{-remotepasswd}")){
            $logger->error(__PACKAGE__. ".$sub_name: Failed to print remote password");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }
    }
    unless(($prematch, $match)=$self->{conn}->waitfor( -match => $prompt,
                                                       -match => '/Permission denied.*/i')){
        $logger->error(__PACKAGE__ . ".$sub_name: FTP connection failed");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    if($match =~ /Permission denied.*/){
        $logger->error(__PACKAGE__ . ".$sub_name: Password entered in incorrect");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    my (@cmd_res ,@cmd_array , $path);
    @cmd_array = @{$args{-files}};
    my $prev_prompt = $self->{conn}->prompt("/$match/");
    @cdres = $self->execCmd("cd $args{-remoteFilePath}");
    if(grep /The system cannot find the file specified|No such file or directory/, @cdres)
    {
        $logger->error(__PACKAGE__. ".$sub_name: File Not Found");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    foreach (@cmd_array){
             unless(@cmd_res = $self->{conn}->cmd("$args{-type}  $_ ")){
                  $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the command");
                  $flag = 0;
                  last;
             }

             $logger->debug(__PACKAGE__ . ".$sub_name: $_ is tranferred");
             if (grep /No such file or directory|Couldn't|is not a directory|The system cannot find the file specified/, @cmd_res){
                 $logger->error(__PACKAGE__ . ".$sub_name:".Dumper(\@cmd_res));
                 $flag = 0;
                 last;
             }
        
    } 
 
    $logger->debug(__PACKAGE__ . ".$sub_name: File Copied Successfully") if($flag);
    $self->{conn}->prompt($prev_prompt);
    unless($self->{conn}->cmd("bye")){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute the command");
        $flag=0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$flag]");
    return $flag; 
}    

=head2 C< verifyDBGMsg >

=over

=item DESCRIPTION:

  This subroutine will take the DBG file (provided by user or the recent file from CLI) to verify the messages.
  TOOLS-76105 - Moved from SBX5000HELPER to support both SBX and GSX

=item ARGUMENTS:

  Mandatory :
  -pattern => record hash with  pattern to match

=item GLOBAL VARIABLES USED:

  None

=item OUTPUT:

  1. Hashref
    Reference of Hash containing mismatched or matched values.

  2. Result
    0   - fail (even if one fails)
    1   - success (if all the messages match)

=item EXAMPLE:

  my %input = (-pattern => { 'INVITE' => { 2 => ['^Contact: <sips:810@172.16.103.184:5061$>', '^Min-SE: 90$'],
                                          1 => ['^CSeq: 1 INVITE$']
                                        },
                          'SIP/2.0' => { 2 => ['^Call-ID: .*', '^Contact: <sip:.*'],
                                         3 => ['^To: <sip:809@10.54.20.168>;5072$', 'msg = SIP/2.0 100 TRYING']
                                         }
                        } );

  my ($hashref, $result) = $SBXObj->verifyDBGMsg( %input );

=back

=cut

sub verifyDBGMsg {
    my ($self, %input) = @_;
    my $sub_name = "verifyDBGMsg";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug("$sub_name: --> Entered Sub");
    $logger->debug("$sub_name:  input args ", Dumper(\%input));

    unless (exists $input{-pattern}) {
        $logger->info("$sub_name: Mandatory argument '-pattern' not passed.");
        $logger->debug("$sub_name: <-- Leaving Sub [0]");
        return ({}, 0);
    }

    if ($self->{D_SBC}) {
        $logger->info("$sub_name: It is a D_SBC");
        my ($hashRef, $result);
        my %nextInput = %input;
        foreach my $sbcType (@{$self->{PERSONALITIES}}) {
            foreach my $instance (keys %{$self->{$sbcType}}) {
                my $aliasName = $self->{$sbcType}->{$instance}->{OBJ_HOSTNAME};
                #create the input hash for function call from the output.
                foreach my $msgType (keys %{$hashRef}) {
                    foreach my $occur (keys %{$hashRef->{$msgType}}) {
                        $nextInput{-pattern}{$msgType}{$occur} = $input{-pattern}{$msgType}{$occur};
                    }
                }

                #Execute the sub
                $hashRef = {};
                $logger->info("$sub_name: Executing sub for '$aliasName' ('$sbcType\-\>$instance' object)");
                ($hashRef, $result) = verifyDBGMsg($self->{$sbcType}->{$instance}, %nextInput);
                $logger->info("$sub_name: '$aliasName' ('$sbcType\-\>$instance' object) returned $result");
                last if ($result);
                %nextInput = {};
            }
            last if ($result);
        }
        $logger->info("$sub_name: <-- Leaving Sub [$result]");
        unless ($result) { #return the unmatched values.
            return ($hashRef, $result);
        }
        else {
        #In this subroutine if all the values are matched, we send a string for all values.
            my %matchedHash = {};
            foreach my $msgType (keys %{$input{-pattern}}) {
                foreach my $occur (keys %{$input{-pattern}{$msgType}}) {
                    my $count = 1;
                    foreach my $element (@{$input{-pattern}{$msgType}{$occur}}) {
                        $matchedHash{$msgType}{$occur}{$count} = "Matched '$element'";
                        $count++;
                    }
                }
            }
            return (\%matchedHash, $result);
        }
    }

    my (@dbgFile, %pattern);

    if( ref $self eq 'SonusQA::SBX5000'){
        my $file;
        unless($file = $self->getRecentLogViaCli('DBG')) {
            $main::failure_msg .= "TOOLS:DBG File NotFound; ";
            $logger->error("$sub_name: Unable to get the current DBG logfile");
            $logger->debug("$sub_name: <-- Leaving Sub [0]");
            return ({}, 0);
        }

        $self = $self->{$self->{ACTIVE_CE}};
        @dbgFile = $self->{conn}->cmd(String => "/bin/cat /var/log/sonus/sbx/evlog/$file", Timeout => 120 , errmode => "return");
    } 
    elsif (ref $self eq 'SonusQA::GSX'){
        @dbgFile = SonusQA::GSX::GSXHELPER::getDBGlog($self);
    }

    #Reading the DBG File
    unless( @dbgFile) {
        $main::failure_msg .= "TOOLS:DBG File NotFound; ";
        $logger->error("$sub_name: Cannot get latest DBG file.");
        $logger->debug("$sub_name: <-- Leaving Sub [0]");
        return ({}, 0);
    }

    %pattern = %{$input{-pattern}};
    my (%startLines, %endLines);

    #flag to check if values are unmatched
    my $fail = 0;
    my (%matchedHash, %unmatchedHash);

    foreach my $msgType (keys %pattern) {
        #taking the start line of the message
        unless ( @{$startLines{$msgType}} = grep{$dbgFile[$_] =~ /-\s+msg =.*$msgType\s?/} 0..$#dbgFile ) {
            $fail = 1;
            $logger->error("$sub_name: No '$msgType' message type is present in DBG file");
            next;
        }

        OCCUR: foreach my $occur (sort { $a <=> $b } keys %{$pattern{$msgType}}) {
            my $start;
            unless ($start = ($startLines{$msgType}[$occur - 1])) {
                $logger->error("$sub_name: Could not find '$msgType' for occurance $occur");
                $unmatchedHash{$msgType}{$occur}{0} = "couldn't find '$msgType' for occurance $occur";
                $fail = 1;
                next OCCUR;
            }
            my $count = 1;
            foreach my $element (@{$pattern{$msgType}{$occur}}) {
                my $found = 0;

                foreach ($start..$#dbgFile) {
                    if ($dbgFile[$_] =~ /^\,\s+msgLen\s+=/) {
                        last;
                    }
                    my $fileValue = $dbgFile[$_];
                    if ($fileValue =~ /$element/) {
                        $logger->debug("$sub_name: Matched $element");
                        $matchedHash{$msgType}{$occur}{$count} = "Matched '$element'";
                        $count++;
                        $found = 1;
                        last;
                    }
                }
                unless ($found) {
                    $logger->debug("$sub_name: Did not match '$element'");
                    $unmatchedHash{$msgType}{$occur}{$count} = "Did not match '$element'";
                    $count++;
                    $fail = 1;
                }
            }
        }
    }

    if ($fail) {
        $main::failure_msg .= "UNKNOWN:DBG Pattern Mismatch; ";
        $logger->debug("$sub_name: <-- Leaving Sub [0]");
        return (\%unmatchedHash, 0);
    }
    else {
        $logger->debug("$sub_name: <-- Leaving Sub [1]");
        return (\%matchedHash, 1);
    }
}
 
1;
