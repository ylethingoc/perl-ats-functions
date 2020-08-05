package SonusQA::RADIUS;

=head1 NAME

 SonusQA::RADIUS- Perl module for RADIUS Server side interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure

   $ats_obj_ref = $package->new(-obj_host => $obj_host,
                                -obj_user => "$alias_hashref->{LOGIN}->{1}->{USERID}",
                                -obj_password => "$alias_hashref->{LOGIN}->{1}->{PASSWD}",
                                -obj_login_type => $alias_hashref->{LOGIN}->{1}->{TYPE},
                                -obj_commtype => "SSH",
                                -obj_port => $port,
                                %refined_args,
                                );

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper

=head1 DESCRIPTION

 This module is used to start or stop the radius server, configure the radius server, get the type of radius server running on the machine and also execute commands on the server.

=head1 AUTHORS

 Nandeesha Palleda <npalleda@sonusnet.com>.

=head1 SUB-ROUTINES

=cut

use strict;
use warnings;
use SonusQA::Utils qw(:errorhandlers :utilities);
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use Data::Dumper;
use SonusQA::ATSHELPER;
use Module::Locate qw(locate);
our @ISA = qw(SonusQA::Base);

=pod

=head2 SonusQA::RADIUS::doInitialization()

    This function is internally called during the object creation ie. from Base.pm and sets the default parameters as defined herein.

=over

=item Arguments

  NONE

=item Returns

  NOTHING

=back

=cut

sub doInitialization {
    my($self, %args)=@_;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

    $self->{COMMTYPES} = ["SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%#\}\|\>\]] $/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)

    $self->{LOCATION} = locate __PACKAGE__ ;
}

=head2 SonusQA::RADIUS::setSystem()

    This function sets the system information and Prompt.

=over

=item Arguments:

        Object Reference

=item Returns:

        Returns 0 - If succeeds
        Reutrns 1 - If Failed

=back

=cut

sub setSystem(){
    my ($self) = @_;
    my $sub = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered sub");
    my($cmd,$prompt, $prevPrompt);
    $self->{conn}->cmd("bash");
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
     unless ($self->execCmd($cmd)){
        $logger->error(__PACKAGE__ . ".$sub: Could not execute '$cmd'");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: last_prompt: " . $self->{conn}->last_prompt);
        $logger->debug(__PACKAGE__ . ".$sub: lastline: " . $self->{conn}->lastline);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0 ;
    }
    $self->{conn}->waitfor(Match => $self->{PROMPT}, Timeout => 2);

    $self->{conn}->cmd("set +o history");
    unless($self->getRadiusType()){
        $logger->error(__PACKAGE__ . ".$sub: Failed to get the radius type");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0 ;
    }    
    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub[1]");
    return 1;
}


=pod

=head2 SonusQA::RADIUS::startServer()

 This function starts the radius server on specified port of an IP

=over

=item ARGUMENTS
 
 Mandatory:
          None
 Optional:
         -ip  : $args{-ip} || ($self->{'TMS_ALIAS_DATA'}->{'NODE'}->{1}->{'IP'})
         -port: $args{-port} || ($self->{'TMS_ALIAS_DATA'}->{'CONFIG'}->{1}->{'PORT'}

=item PACKAGE:

 SonusQA::RADIUS

=item Arguments 

 1 - if service starts successfully
 0 - if service is already running on specified port for an IP

=item EXAMPLE(s):

 my $radius = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'radius_test');
 my %args = (-ip => 10.54.90.108, -port => '2222');
 $radius->startServer;
  OR
 $radius->startServer(%args);

=back

=cut

sub startServer{

    my ($self, %args) = @_;

    my $sub_name = "startServer";
    my $logger   = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub_name" );
    $logger->debug( __PACKAGE__ . ".$sub_name: --> Entered Sub" );
    my $ip = $args{-ip} || ($self->{'TMS_ALIAS_DATA'}->{'NODE'}->{1}->{'IP'});
    my $port = $args{-port} || ($self->{'TMS_ALIAS_DATA'}->{'CONFIG'}->{1}->{'PORT'});

    if($self->serviceStatus($ip, $port)){
        $logger->error( __PACKAGE__ . ".$sub_name: Service is already running");
        $logger->warn( __PACKAGE__ . ".$sub_name: Stopping the server on ip $ip and port $port");
        unless($self->stopServer(-ip => $ip, -port => $port)){
            $logger->debug( __PACKAGE__ . ".$sub_name: Failed to stop the radius server");
            $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 1;
        }
    }
    $logger->debug( __PACKAGE__ . ".$sub_name: Starting the radius server on ip $ip and port $port");
    my $cmd_radius = ($ip && $port) ? "$self->{RADIUS_BIN} -x -i $ip -p $port" : "$self->{RADIUS_BIN} -x";
    $self->{conn}->cmd( String => $cmd_radius );
    $logger->debug( __PACKAGE__ . ".$sub_name: Service $self->{RADIUS_BIN} started with ip '$ip' and port '$port'" );
    $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
    return 1;
}

=pod

=head2 SonusQA::RADIUS::stopServer()

 This function stops the radius server on specified port of an IP

=over

=item ARGUMENTS

 Mandatory:
          None
 Optional:
         -ip  : $args{-ip} || ($self->{'TMS_ALIAS_DATA'}->{'NODE'}->{1}->{'IP'})
         -port: $args{-port} || ($self->{'TMS_ALIAS_DATA'}->{'CONFIG'}->{1}->{'PORT'})

=item PACKAGE:

 SonusQA::RADIUS

=item Returns

 1 - if service stops successfully
 0 - if service is not running on specified port for an IP

=item EXAMPLE(s):

 my $radius = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'radius_test');
 my %args = (-ip => 10.54.90.108, -port => '2222');
 $radius->stopServer()
 OR
 $radius->stopServer(%args);

=back

=cut

sub stopServer{

    my ($self, %args) = @_;
    my $ip = $args{-ip} || ($self->{'TMS_ALIAS_DATA'}->{'NODE'}->{1}->{'IP'});
    my $port = $args{-port} || ($self->{'TMS_ALIAS_DATA'}->{'CONFIG'}->{1}->{'PORT'});
    my $sub_name = "stopServer";
    my $logger   = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub_name" );
    $logger->debug( __PACKAGE__ . ".$sub_name: --> Entered Sub" );

    if(my $pid = $self->serviceStatus($ip, $port)){
    	$self->{conn}->cmd( String => "kill $pid");
        $logger->debug( __PACKAGE__ . ".$sub_name: Stopped $self->{RADIUS_BIN} service." );
    }else{
        $logger->debug( __PACKAGE__ . ".$sub_name: Radius service is not running");
    }
    $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]" );
    return 1;
}

=pod

=head2 SonusQA::RADIUS::configureServer()

 Adds the configuration to /usr/local/etc/raddb/clients.conf

=over

=item ARGUMENTS

 None.

=item PACKAGE

 SonusQA::RADIUS

=item Returns

 1 - if configuration is added successfully
 0 - if configuration already exists

=item EXAMPLE(s):

 my $radius = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'radius_test');
 $radius->configureServer;

=back

=cut

sub configureServer {

    my $self = shift;

    my $sub_name = 'configureRadius';
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub_name" );
    $logger->debug( __PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $primary_mgmt_ip = $self->{'TMS_ALIAS_DATA'}->{'MGMTNIF'}->{1}->{'IP'};
    my $primary_short_name = $self->{'TMS_ALIAS_DATA'}->{'NODE'}->{1}->{'HOSTNAME'};

    my $secondary_mgmt_ip = $self->{'TMS_ALIAS_DATA'}->{'MGMTNIF'}->{2}->{'IP'};
    my $secondary_short_name = $self->{'TMS_ALIAS_DATA'}->{'NODE'}->{2}->{'HOSTNAME'};

    unless($self->addConfig( 'ip' => $primary_mgmt_ip, 'short_name' => $primary_short_name)){
        $logger->error( __PACKAGE__ . ".$sub_name: Could not call addConfig() for ip: \'$primary_mgmt_ip\' and short_name: \'$primary_short_name\'");
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]" );
        return 0;
    }
    if($secondary_mgmt_ip){
        unless($self->addConfig( 'ip' => $secondary_mgmt_ip, 'short_name' => $secondary_short_name)){
            $logger->error( __PACKAGE__ . ".$sub_name: Could not call addConfig() for ip: \'$secondary_mgmt_ip\' and short_name: \'$secondary_short_name\'");
            $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]" );
            return 0;
        }
    }
    $logger->debug( __PACKAGE__ . ".$sub_name: Added the configuration." );
    $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]" );
    return 1;
}

=pod

=head2 SonusQA::RADIUS::addConfig()

 Adds the configuration details to /usr/local/etc/raddb/clients.conf or /etc/freeradius/clients.conf based on the server type.

=over

=item ARGUMENTS

 ip and shortname of the server

=item PACKAGE

 SonusQA::RADIUS

=item Returns

 1 - if configuration is added successfully
 0 - if adding configuration fails

=item EXAMPLE(s):

 my $radius = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'radius_test');
 $radius->addConfig('ip' => $primary_mgmt_ip, 'short_name' => $primary_short_name);

=back

=cut

sub addConfig {

    my($self, %args)=@_;
    my $sub_name = 'addConfig';
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub_name" );
    $logger->debug( __PACKAGE__ . ".$sub_name: -->Entered Sub");

    unless($args{ip}){
        $logger->debug( __PACKAGE__ . ".$sub_name: Mandatory argument 'ip' missing");
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]" );
        return 0;
    }
    my $cmd_read_config = "cat $self->{RADIUS_CONF}";
    my @file;
    unless (@file = $self->execCmd($cmd_read_config)){
        $logger->debug( __PACKAGE__ . ".$sub_name: Execution of command \'$cmd_read_config\' failed");
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]" );
        return 0;
    }
    my @config;

    foreach my $line ( @file ) {
        $line =~ s/#.*//;               # ignore comments by erasing them
        next if $line =~ /^(\s)*$/;     # skip blank lines
        chomp $line;                    # remove trailing newline characters
        push @config, $line;            # push the data line onto the array
    }

    my $secret = $args{secret_key} || 'sonus123';
    my $flag = -1;
    for my $i (0..$#config){
        if($config[$i] =~ /$args{ip}/){
            if($config[$i+1] =~ /$secret/ && $config[$i+2]=~ /$args{short_name}/){
                $logger->debug(__PACKAGE__ . ".$sub_name: Client $args{ip} already exists");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
                $flag = 1;
                last;
            }else{
                $logger->debug(__PACKAGE__ . ".$sub_name: Incomplete match. Only user $args{ip} matched");
                $logger->debug(__PACKAGE__ . ".$sub_name: Removing the entry from $self->{RADIUS_CONF}");
                unless($self->removeClient(-ip => $args{ip})){
                    $logger->error( __PACKAGE__ . ".$sub_name: Failed to remove client with ip $args{ip}");
                    $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]" );
                    $flag = 0;
                    last;
                }
            }
        }
    }
    return $flag unless($flag == -1);

    my $data =  "<<- CONFIG >> $self->{RADIUS_CONF} 
client $args{ip} {
    secret = $secret
    shortname = $args{short_name}
    login = admin
    password = Sonus\@123
}
CONFIG";

    my $cmd_add_config = "cat $data";
    unless(my @cmd_result = $self->execCmd($cmd_add_config)){
        $logger->debug( __PACKAGE__ . ".$sub_name: Execution of command \'$cmd_add_config\' failed");
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]" );
        return 0;
    }
    $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]" );
    return 1;
}

=pod

=head2 SonusQA::RADIUS::getRadiusType()

 Gets the type of radius server running on the machine

=over

=item ARGUMENTS

 None.

=item PACKAGE:

 SonusQA::RADIUS

=item Returns

 radiusd - if service is of type radius
 freeradius - if service is of type freeradius

=item EXAMPLE(s):

 my $radius = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'radius_test');
 $radius->getRadiusType;

=back

=cut

sub getRadiusType {

    my $self = shift;
    my $sub_name = 'getRadiusType';
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub_name" );
    $logger->debug( __PACKAGE__ . ".$sub_name: --> Entered Sub");
    my @cmdResult;
    unless(@cmdResult = $self->execCmd("which freeradius")){
        $logger->debug( __PACKAGE__ . ".$sub_name: Execution of command 'which freeradius' failed");
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]" );
        return 0;
    }

    chomp(@cmdResult);
    $self->{RADIUS_BIN}= ($cmdResult[0] eq '/usr/sbin/freeradius') ? 'freeradius' : 'radiusd';
    $self->{RADIUS_CONF} = ($self->{RADIUS_BIN} eq 'radiusd') ? '/usr/local/etc/raddb/clients.conf' : '/etc/freeradius/clients.conf';
    $self->{RADIUS_USERS} = ($self->{RADIUS_BIN} eq 'radiusd') ? '/usr/local/etc/raddb/users' : '/etc/freeradius/users';
    $logger->debug( __PACKAGE__ . ".$sub_name: Radius Binary: $self->{RADIUS_BIN}, Radius Conf file: $self->{RADIUS_CONF}, Radius Users file: $self->{RADIUS_USERS}");
    $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[$self->{RADIUS_BIN}]");
    return $self->{RADIUS_BIN};
}

=pod

=head2 SonusQA::RADIUS::execCmd()

    This function enables user to execute any command on the RADIUS server.

=over

=item Arguments:

    1. Command to be executed.
    2. Timeout in seconds (optional).

=item Returns

    Output of the command executed.

=item Example(s)

    my @results = $radiusObject->execCmd("ls /ats/NBS/sample.csv");
    This would execute the command "ls /ats/NBS/sample.csv" on the RADIUS server and return the output of the command.

=back

=cut

sub execCmd{
  my ($self,$cmd, $timeout)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd  ...... ");
  $logger->debug(__PACKAGE__ . ".execCmd: --> Entered Sub");
  my(@cmdResults,$timestamp);
    if (!(defined $timeout)) {
       $timeout = $self->{DEFAULTTIMEOUT};
       $logger->debug(__PACKAGE__ . ".execCmd Timeout not specified. Using $timeout seconds ");
    }
    else {
       $logger->debug(__PACKAGE__ . ".execCmd Timeout specified as $timeout seconds ");
    }

    $logger->debug(__PACKAGE__ . ".execCmd Clearing the buffer");
    $self->{conn}->buffer_empty; #clearing the buffer before the execution of CLI command

    $logger->info(__PACKAGE__ . ".execCmd ISSUING CMD: $cmd");
    unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
        $logger->error(__PACKAGE__ . ".execCmd  errmsg : ". $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".execCmd Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".execCmd Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".execCmd:  <-- Leaving sub[0] ");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".execCmd ...... : @cmdResults");
    $logger->debug(__PACKAGE__ . ".execCmd:  <-- Leaving sub ");
    return @cmdResults;
}

=pod

=head2 SonusQA::RADIUS::serviceStatus()

 This function is used to check if the radius service is in use

=over

=item ARGUMENTS

 Mandatory:
          None
 Optional:
         -ip
         -port

=item PACKAGE:

 SonusQA::RADIUS

=item Returns

 0 - if service not in use
 pid - if service is running

=item EXAMPLE(s):

 my $radius = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'radius_test');
 my $ip = '10.54.90.108';
 my $port = '2222';
 unless ($pid = $radius->serviceStatus($ip, $port)){
 }

=back

=cut

sub serviceStatus{
    my ($self, $ip, $port) = @_;
    my $sub_name = 'serviceStatus';
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub_name" );
    $logger->debug( __PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $cmd_pgrep = ($ip && $port) ? "pgrep -fl \'$self->{RADIUS_BIN} -x -i $ip -p $port\'" : "pgrep -fl \'$self->{RADIUS_BIN} -x\'";
    my @cmdResult = $self->execCmd($cmd_pgrep);
    chomp @cmdResult;
    my ($pid,$string) = split(/\s/, $cmdResult[0], 2);
    if($pid){
        $logger->debug( __PACKAGE__ . ".$sub_name: Service '$cmd_pgrep' is running with pid '$pid'");
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[$pid]" );
        return $pid;
    }
    $logger->debug( __PACKAGE__ . ".$sub_name: Service not in use. It can be started on $ip and $port");
    $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
    return 0;
}

=pod

=head2 SonusQA::RADIUS::addUser()

 This function is used to add a new user to /etc/freeradius/users file

=over

=item ARGUMENTS

 Mandatory:
          -user
          -password
          -group

=item PACKAGE:

 SonusQA::RADIUS

=item Returns

 1 - On adding user successfully
 0 - Failed to add user

=item EXAMPLE(s):

 my $radius = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'radius_test');
 my %args = (-user => 'calea', -password => 'calea', -group => 'Admin')
 unless($radius->addUser(%args)){
 }

=back

=cut

sub addUser{
    my ($self, %args) = @_;
    my $sub_name = 'addUser';
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub_name" );
    $logger->debug( __PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $flag = 0;
    foreach('-user', '-password', '-group'){
        unless($args{$_}){
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument $_ is empty or blank");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            $flag = 1;
            last;
        }
    }
    return 0 if ($flag);
    my @cmd_results = $self->execCmd("cat $self->{RADIUS_USERS}");
    $flag = -1;
    for my $i (0..$#cmd_results){
        if($cmd_results[$i] =~ /$args{-user}.+$args{-password}/){
            if($cmd_results[$i+1] =~ /$args{-group}/){
                $logger->debug(__PACKAGE__ . ".$sub_name: User $args{-user} already exists");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
                $flag = 1;
                last;
            }else{
                $logger->error(__PACKAGE__ . ".$sub_name: Incomplete match. Only user $args{-user} matched");
                $logger->debug(__PACKAGE__ . ".$sub_name: Removing the entry from $self->{RADIUS_USERS}");
                unless($self->removeUser(-user => $args{-user})){
                    $logger->error(__PACKAGE__ . ".$sub_name: Failed to remove user $args{-user}");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                    $flag = 0;
                    last;
                }
            }
        }
    }
    return $flag unless($flag == -1);

    $logger->debug( __PACKAGE__ . ".$sub_name: Adding user $args{-user}");
    my $data =  "<<- CONFIG >> $self->{RADIUS_USERS}
$args{-user} Cleartext-Password := \"$args{-password}\"
    GroupName := \"$args{-group}\",
    Fall-Through = Yes
CONFIG";

    my $cmd_add_config = "cat $data";    
    unless($self->execCmd($cmd_add_config)){
        $logger->error( __PACKAGE__ . ".$sub_name: Failed to add user $args{-user} into '$self->{RADIUS_USERS}'");
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]" );
        return 0;
    }
    $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]" );
    return 1;
}

=pod

=head2 SonusQA::RADIUS::removeUser()

 This function is used to remove a user from /etc/freeradius/users file

=over

=item ARGUMENTS

 Mandatory:
          -user

=item PACKAGE:

 SonusQA::RADIUS

=item Returns

 1 - On removing user successfully
 0 - Failed to remove user

=item EXAMPLE(s):

 my $radius = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'radius_test');
 my %args = (-user => 'calea');
 unless($radius->removeUser(%args)){
 }

=back

=cut

sub removeUser{
    my ($self, %args) = @_;
    my $sub_name = 'removeUser';
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub_name" );
    $logger->debug( __PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless($args{-user}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument '-user' is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
    $logger->debug( __PACKAGE__ . ".$sub_name: Removing user $args{-user}");
    $self->execCmd("sed -i -E \'/$args{-user}\\s+Cleartext-Password/,/Fall-Through/d\' $self->{RADIUS_USERS}");
    my @cmd_results = $self->execCmd("cat $self->{RADIUS_USERS}");
    if(grep /$args{-user}/, @cmd_results){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to remove user $args{-user}");
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]" );
        return 0;
    }
    $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]" );
    return 1;    
}

=pod

=head2 SonusQA::RADIUS::removeClient()

 This function is used to remove a client from /etc/freeradius/clients.conf file

=over

=item ARGUMENTS

 Mandatory:
          -ip

=item PACKAGE:

 SonusQA::RADIUS

=item Returns

 1 - On removing client successfully
 0 - Failed to remove client

=item EXAMPLE(s):

 my $radius = SonusQA::ATSHELPER::newFromAlias(-tms_alias => 'radius_test');
 my %args = (-ip => '10.54.52.19')
 unless($radius->removeClient(%args)){
 }

=back

=cut

sub removeClient{
    my ($self, %args) = @_;
    my $sub_name = 'removeClient';
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub_name" );
    $logger->debug( __PACKAGE__ . ".$sub_name: --> Entered Sub");
    unless($args{-ip}){
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument '-ip' is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }

    $logger->debug( __PACKAGE__ . ".$sub_name: Deleting client $args{-ip}");
    $self->execCmd("sed -i \'/client $args{-ip} /,/}/d\' $self->{RADIUS_CONF}");
    my @cmd_results = $self->execCmd("cat $self->{RADIUS_CONF}");
    if(grep /$args{-ip}/, @cmd_results){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to remove client $args{-ip}");
        $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]" );
        return 0;
    }
    $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]" );
    return 1;
}

1;
