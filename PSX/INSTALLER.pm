package SonusQA::PSX::INSTALLER;

=head1 NAME

SonusQA::PSX::INSTALLER - Perl module for PSX IUG procedures

=head1 REQUIRES

Log::Log4perl, Data::Dumper, SonusQA::ILOM

=head1 DESCRIPTION

This module provides APIs for PSX ISO/APP installation & upgrade on various nodes.

=head1 AUTHORS

Nandeesh Mp <npalleda@sonsnet.com>, ....
Sadanand Pattanshetty <spattanshetty@rbbn.com> ....

=head1 METHODS

=cut

use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use SonusQA::ILOM;
use Time::HiRes qw(gettimeofday tv_interval usleep);
use SonusQA::Base;

=head2 C< doInstallation >

=over

    It will do iso installation parallelly on passed testbeds and wait for installation to complete. Also it will perform app installation.

=item ARGUMENTS

    -primary_testbed
    -secondary_testbed (Optional)
    -build_path
    -build_location
    -boot_val (Optional: default value is 1)

=item RETURNS

    1 => success
    0 => failure

=item EXAMPLE

   $ret = SonusQA::PSX::INSTALLER::doInstallation('-build_path' => '/sonus/SonusHornetNFS2/LINTEL_ISO/V10.03.00R001/psx-V10.03.00R001-RHEL7-07.02.05.00R010-x86_64.iso', '-primary_testbed' => $primary_tb, '-secondary_testbed' => $secondary_tb, '-build_location' => 'I');

=back

=cut

sub doInstallation{
    my (%args) = @_;

    my $sub_name = 'doInstallation';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");
	$logger->info(__PACKAGE__ . ".$sub_name: args: ". Dumper(\%args));

    my %install_args;
    foreach my $testbed ($args{-primary_testbed}, $args{-secondary_testbed}){
		next unless($testbed);
        $install_args{$testbed} = {
            -build_path => $args{-build_path},
            -boot_val => $args{-boot_val} || 1,
            -build_location => $args{-build_location},
        };
    }

    unless(doMultipleInstallations(%install_args)){
        $logger->error(__PACKAGE__ . ".$sub_name: ISO Installation failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
	
    my $version = "$1$2" if($args{-build_path} =~/psx\-(V\d+)\.(\d+)\.\d+\w\d+\-/); ##/sonus/SonusHornetNFS2/LINTEL_ISO/V10.03.00R001/psx-V10.03.00R001-RHEL7-07.02.05.00R010-x86_64.iso
		
    foreach my $testbed ($args{-primary_testbed}, $args{-secondary_testbed}){
        next unless($testbed);
        my $testbed_alias_data = SonusQA::Utils::resolve_alias($testbed);
        $logger->info(__PACKAGE__ . ".$sub_name: doInstall master psx_ip =>  $testbed_alias_data->{NODE}->{1}->{IP}");
		unless(SonusQA::PSX::INSTALLER::doInstall(
			psx_ip =>  $testbed_alias_data->{NODE}->{1}->{IP},
			type    => 'master',
			version => $version, #'V1102'
		)){
			$logger->error(__PACKAGE__ . ".$sub_name: PSX installation Failed in master ($testbed_alias_data->{NODE}->{1}->{IP}).");
			$logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
			return 0;
		}
		
		if($testbed_alias_data->{SLAVE_CLOUD}->{1}->{IP}){	
            $logger->info(__PACKAGE__ . ".$sub_name: doInstall slave psx_ip =>  $testbed_alias_data->{SLAVE_CLOUD}->{1}->{IP}");
			unless(SonusQA::PSX::INSTALLER::doInstall(
				psx_ip =>  $testbed_alias_data->{SLAVE_CLOUD}->{1}->{IP},
				master_name => $testbed_alias_data->{NODE}->{1}->{NAME},
				master_psx_ip => $testbed_alias_data->{NODE}->{1}->{IP},
				type    => 'slave',
				version => $version, #'V1102',
			)){
				$logger->error(__PACKAGE__ . ".$sub_name: PSX installation Failed in slave ( $testbed_alias_data->{SLAVE_CLOUD}->{1}->{IP}).");
				$logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
				return 0;
			}
		}	
	}

    $ENV{'I_JUST_ISOd'} = 1; # 1 = I just did iso so we have to register psx and associate licnesnses for fist time when EMSCLI	is called
	$logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]");
	return 1;
}

=head2 C< installISOonG8 >

=over

=item DESCRIPTION:

Install PSX/EMS ISO on G8 box

=item ARGUMENTS:

Mandatory Args:
$iso_path =>  Path of the ISO to be installed
$ilom_ip  =>  ILOM IP. This is where we will vsp to trigger installation
$mgmt_ip  =>  IP to be assigned to a box
$gateway  =>  gateway ip
$netmask  =>  netmask
$hostname => PSX box hostname
$ntp      => NTP server IP details
$time_zone => Time zone

=item PACKAGES USED:

None

=item GLOBAL VARIABLES USED:

None

=item EXTERNAL FUNCTIONS USED:

None

=item RETURNS:

0 - On Failure
1 - On success

=item EXAMPLE:

    unless(SonusQA::PSX::INSTALLER::installISOonG8 (-ilom_ip => '10.54.0.6', -mgmt_ip => '10.54.8.6', -gateway => '10.54.8.1', -netmask => '255.255.254.0', -iso_path => 'http://10.54.92.200/PSX/psx-V10.01.00A005-RHEL7-07.02.01.00A005-x86_64.iso', -hostname => 'sukma',-ntpservers =>'10.128.254.67', -timezone => Asia/Kolkata )) {
        $logger->error(__PACKAGE__ . ".$sub_name: Installation on G8 box failed.");
        $logger->info(__PACKAGE__ . ".$sub_name:  Sub[0]-");
        return 0;
    }

=back

=cut

sub installISOonG8 {

    my (%args) = @_;

    my $sub_name = "installISOonG8";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    my $obj = SonusQA::ILOM->new(
        -OBJ_HOST     => $args{-ilom_ip},
        -OBJ_USER     => 'Administrator',
        -OBJ_PASSWORD => 'Sonus!@#',
        -OBJ_COMMTYPE => "SSH",
        -sessionlog   => 1,
    );

    my ($prematch, $match, $max_attempts);
    my @cmds = (
        'vm cdrom insert ' . $args{-iso_path},
        'vm cdrom set boot_once',
        'vm cdrom get',
        'power reset'
    );

    foreach (@cmds) {
        $logger->info(__PACKAGE__ . " Entering $_");
        unless ($obj->{conn}->cmd($_)){
            $logger->error( __PACKAGE__ . " Failed to execute $_" );
            $logger->error( __PACKAGE__ . " Error Msg  : " . $obj->{conn}->errmsg );
            $logger->info( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }
    }

    $logger->info(__PACKAGE__ . " Sending 'vsp'");
    unless ($obj->{conn}->print('vsp')){
        $logger->error( __PACKAGE__ . " Failed to send vsp" );
        $logger->error( __PACKAGE__ . " Error Msg  : " . $obj->{conn}->errmsg );
        $logger->info( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    $logger->info( __PACKAGE__ . " Waiting for VSP to start..." );
    unless (( $prematch, $match ) = $obj->{conn}->waitfor(
            -match   => '/Press \'ESC \(\' to return to the CLI Session./',
            -errmode => "return"
        )){
        $logger->error( __PACKAGE__ . " Error on wait for vsp. PREMATCH: $prematch\nMATCH: $match");
        $logger->error( __PACKAGE__ . " Error Msg  : " . $obj->{conn}->errmsg );
        $logger->info( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    $logger->info(__PACKAGE__ . " VSP started - Waiting for ANSI 'query-device' term command" );
    unless (( $prematch, $match ) = $obj->{conn}->waitfor(
            -string => "\x1b\x5b5n",
            -match  => $obj->{PROMPT},
            -Timeout => 300,  # Server pre-BIOS initialization can take some time...
            -errmode => "return"
        )){
        $logger->error( __PACKAGE__ . " Error on wait for ansi term cmd.." );
        $logger->error( __PACKAGE__ . " Error Msg  : " . $obj->{conn}->errmsg );
        $logger->info( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;        
    }

    unless ( $obj->{conn}->print("\x1b\x5b0n") ) {
        $logger->error( __PACKAGE__ . " Failed to send '\x1b\x5b0n'" );
        $logger->error( __PACKAGE__ . " Error Msg  : " . $obj->{conn}->errmsg );
        $logger->info( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    $logger->info( __PACKAGE__ . " Waiting for boot prompt" );
    my $a = "\x1b" . '\[\d+;\d+H'; # ANSI 'cursor position' code regexp - note - odd-looking quoting is intentional here..
    my $boot_regexp = "/b${a}${a}o${a}${a}o${a}${a}t/";

    unless (( $prematch, $match ) = $obj->{conn}->waitfor(
            -match   => $boot_regexp,
            -Timeout => 900,            # BIOS initialization can take some time...
            -errmode => "return"
        )){
        $logger->error( __PACKAGE__ . " Error on wait for boot prompt.." );
        $logger->error( __PACKAGE__ . " Error Msg  : " . $obj->{conn}->errmsg );
        $logger->info( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;        
    }

    $logger->info( __PACKAGE__ . " Found boot prompt: $match" );
    $logger->info( __PACKAGE__ . " Entering 1" );

    my $cmd = "1 ip=$args{-mgmt_ip} netmask=$args{-netmask} gateway=$args{-gateway} hostname=$args{-hostname} ntpserver=$args{-ntpservers} timezone=$args{-timezone} console=ttyS1,19200\n";

    # Sending the command in 1 go overloads the serial console... Send it char-by-char every 100ms
    my $c;
    for $c ( split( //, $cmd ) ) {
        usleep 100000;
        $logger->info( __PACKAGE__ . " Sending: $c" );
        $obj->{conn}->put($c);
    }

    $logger->info( __PACKAGE__ . " Should now be booting..." );
    $logger->info( __PACKAGE__ . " Sleeping 1200 seconds" );
    sleep 1200;

    $logger->info( __PACKAGE__ . " Waiting for login prompt..." );
    $max_attempts = 30;
    for (my $attempt = 1 ; $attempt <= $max_attempts ; $attempt++){
        if (( $prematch, $match ) = $obj->{conn}->waitfor(
                -match   => '/.*login: $/',
                -Timeout => 300,
                -errmode => "return"
            )){
            $logger->info( __PACKAGE__ . " Prompt matched. Boot complete." );
            last;
        }
        else {
            if ($attempt < $max_attempts){
                $logger->warn( __PACKAGE__ . " Attempt $attempt failed. Error on wait for login prompt. PREMATCH: $prematch\nMATCH: $match");
                $logger->warn(__PACKAGE__ . " Error Msg  : " . $obj->{conn}->errmsg ); 
                $logger->warn( __PACKAGE__ . " Attempting again... " );
            }
            else {
                $logger->error( __PACKAGE__ . " Reached max attempts($max_attempts). Installation failed. Manual intervention required.");
                $logger->info( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                return 0;
            }
        }
    }

    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
    return 1;
}


=head2 C< installG8 >
	 
=over

=item ARGUMENTS:

    -mgmt_ip	: Management IP of the PSX
    -boot_val	: 
    -ilom_ip	: ILOM IP of the PSX
    -iso_path	: ISO path of the PSX to be installed
    -hostname	: host name of the PSX  
    -netmask	: 
    -gateway	: gateway IP of the PSX
    -ntpserver	: IP of the Network Time 

=item RETURNS:

    0 - On Failure
    1 - On Success

=item EXAMPLE:

    unless(SonusQA::PSX::INSTALLER::installG8(
				-mgmt_ip => ,
				-boot_val => ,
				-ilom_ip => ,
				-iso_path => ,
				-hostname => ,
				-netmask  => ,
				-gateway => ,
				-ntpserver => 
        )) {
        $logger->error(__PACKAGE__ . ".$sub_name installation on G8 failed.");
        $logger->info(__PACKAGE__ . ".$sub_name <-- leaving Sub [0]");
       return 0;
    }

=back

=cut

sub installG8 {
    my (%args) = @_;
    my $sub_name = "installG8";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    foreach (qw(-mgmt_ip -boot_val -ilom_ip -iso_path -hostname -netmask -gateway -ntpserver)) {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument $_ not provided.");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }
    }

    my ($build_version, $version) = $args{-iso_path} =~ /((V\d\d\.\d\d).+)-RHEL.+.iso/i;
    $version =~ s/\.//g;

    $logger->debug(__PACKAGE__ . "version is :$version");

    my $log_file = "$ENV{ HOME }/ats_user/logs/iso_out_$args{-mgmt_ip}_". time;
    my $expect_script = "$ENV{ HOME }/ats_repos/lib/perl/SonusQA/PSX/ExpectScripts/$version/INSTALL/installG8";
    unless(-e $expect_script) {
        $logger->error(__PACKAGE__ . ".$sub_name: ERROR $expect_script not found.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0] ");
        return 0;
    }
    my $cmd = $expect_script. " $args{-boot_val} $args{-ilom_ip} $args{-iso_path} $args{-hostname}  $args{-mgmt_ip} $args{-netmask} $args{-gateway} $args{-ntpserver}  > $log_file".' & echo $!';

    $logger->info(__PACKAGE__ . ".$sub_name: executing iso installation command: $cmd");
    my $pid = `$cmd`;
    chomp($pid);
    $logger->debug(__PACKAGE__ . ".$sub_name: pid: $pid");

    if ($pid=~/(\d+)/){
        $logger->debug(__PACKAGE__ . ".$sub_name: got the process id, $1");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
        return($1, $log_file);
    }else{
        $logger->debug(__PACKAGE__ . ".$sub_name: couldn't get the process id.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return(0);
    }

}


=head2 C< waitForIsoInstallation >

=over

=item ARGUMENTS

=item RETURNS

=item EXAMPLE

=back

=cut

sub waitForIsoInstallation{

    my %args = @_;

    my $sub_name = "waitForIsoInstallation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    my ($cnt, $error);

    while($cnt <= 9000){ #waits max 2 hour
        $logger->info(__PACKAGE__ . ".$sub_name: checking pidof expect. $cnt");
        my $out = `pidof expect`;
        chomp($out);
        my @pids = split(/\s+/, $out);
        $logger->info(__PACKAGE__ . ".$sub_name: pidof expect : @pids");

        foreach my $pid (keys %args){
            unless(grep {$pid} @pids){
                my @out = `cat $args{$pid}`;
                $logger->info(__PACKAGE__ . ".$sub_name: Process $pid ($args{$pid}). Output  : @out");
                ##unlink $args{$pid};
                unless(@out){
                    $logger->error(__PACKAGE__ . ".$sub_name: Installation didnt happen $pid. Output: @out");
                    $error = 1;
                }
                elsif(grep {/ERROR/i} @out){
                    $logger->error(__PACKAGE__ . ".$sub_name: Got error for process $pid. Output: @out");
                    $error = 1;
                }
                delete $args{$pid};
            }
        }

        last unless(keys %args);
        $cnt+=60;
        $logger->info(__PACKAGE__ . ".$sub_name: Sleeping 60s.");
        sleep 60;
    }

 if(keys %args){
        foreach my $pid (keys %args){
            $logger->error(__PACKAGE__ . ".$sub_name: Installation is not completed in 2 hour for process id, $pid. So killing it.");
            `kill $pid`;
        }

        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }

    if($error){
        $logger->error(__PACKAGE__ . ".$sub_name: Installation failed");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
    }
    else{
        $logger->info(__PACKAGE__ . ".$sub_name: Installation completed succesfully for all the process.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
        return 1;
    }
}


=head2 C< doMultipleInstallations >

=over

    It will do iso installation parallelly on passed testbeds and wait for installation to complete.

=item ARGUMENTS	
	
    a hash with testbed alias as key and following hash reference as value. We can pass multiple testbeds
            -build_path,
            -boot_val ,
            -build_location,

=item RETURNS
    1 => success
    0 => failure

=item EXAMPLE

    my %install_args;
    foreach my $testbed ($args{-primary_testbed}, $args{-secondary_testbed}){
        next unless($testbed);
        $install_args{$testbed} = {
            -build_path => '/sonus/SonusHornetNFS2/LINTEL_ISO/V10.03.00R001/psx-V10.03.00R001-RHEL7-07.02.05.00R010-x86_64.iso',
            -boot_val => 1,
            -build_location => 'I',
        };
    }

   unless(doMultipleInstallations(%install_args)){
        $logger->error(__PACKAGE__ . ".$sub_name: ISO Installation failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;
   }

=back

=cut

sub doMultipleInstallations{

    my %args = @_;
    my $sub_name = "doMultipleInstallations";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");

    my %apache_server = (   I => '10.54.81.11', # bats12
                            W => '10.6.40.241' # wfats1
    );

    my (%pids, $pid, $log_file);

    foreach my $testbed (keys %args){
        my  $build_path = $args{$testbed}->{-build_path};
        my  $boot_val = $args{$testbed}->{-boot_val};
        my $build_location = $args{$testbed}->{-build_location};
        my $testbed_alias_data = SonusQA::Utils::resolve_alias($testbed);
        $build_path =~ s/\/sonus/http\:\/\/$apache_server{$build_location}/;

        my %master_args = (
            -ilom_ip => $testbed_alias_data->{NODE}->{1}->{ILOM_IP},
            -mgmt_ip => $testbed_alias_data->{NODE}->{1}->{IP},
            -gateway => $testbed_alias_data->{NODE}->{1}->{GATEWAY},
            -netmask => $testbed_alias_data->{NODE}->{1}->{NETMASK},
            -iso_path => $build_path,
            -hostname => $testbed_alias_data->{NODE}->{1}->{NAME},
            -ntpserver => $testbed_alias_data->{NTP}->{1}->{IP},
            -timezone => $testbed_alias_data->{NODE}->{1}->{TIMEZONE},
            -root_passwd => $testbed_alias_data->{LOGIN}->{1}->{ROOTPASSWD},
            -ssuser_passwd => $testbed_alias_data->{LOGIN}->{1}->{PASSWD},
            -oracle_passwd => $testbed_alias_data->{LOGIN}->{2}->{PASSWD},
            -admin_passwd => $testbed_alias_data->{LOGIN}->{3}->{PASSWD},
            -boot_val =>  $boot_val,
            -iso_path => $build_path,
        );

        $logger->info(__PACKAGE__ . "dumping args of $testbed: ".Dumper(\%master_args));

	($pid, $log_file) = &installG8(%master_args);
        unless($pid){
            $logger->error(__PACKAGE__ . ".$sub_name: ISO Installation on PSX $testbed ($args{-mgmt_ip}) failed.");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
            return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub_name: ISO Installation on PSX $testbed ($args{-mgmt_ip}) started, process id is $pid.");
        $pids{$pid} = $log_file;

        if($testbed_alias_data->{SLAVE_CLOUD}->{1}->{IP}){
            $logger->info(__PACKAGE__. ".$sub_name: Installing ISO on G8 for slave psx ($testbed_alias_data->{SLAVE_CLOUD}->{1}->{IP})");

            my %slave_args = (
                -ilom_ip => $testbed_alias_data->{SLAVE_CLOUD}->{1}->{ILOM_IP} || $testbed_alias_data->{NODE}->{1}->{ILOM_IP},
                -mgmt_ip => $testbed_alias_data->{SLAVE_CLOUD}->{1}->{IP},
                -gateway => $testbed_alias_data->{SLAVE_CLOUD}->{1}->{GATEWAY} || $testbed_alias_data->{NODE}->{1}->{GATEWAY},
                -netmask => $testbed_alias_data->{SLAVE_CLOUD}->{1}->{NETMASK} || $testbed_alias_data->{NODE}->{1}->{NETMASK},
                -iso_path => $build_path,
                -hostname => $testbed_alias_data->{SLAVE_CLOUD}->{1}->{NAME},
                -ntpserver => $testbed_alias_data->{NTP}->{1}->{IP},
                -timezone => $testbed_alias_data->{NODE}->{1}->{TIMEZONE},
                -root_passwd => $testbed_alias_data->{LOGIN}->{1}->{ROOTPASSWD},
                -ssuser_passwd => $testbed_alias_data->{LOGIN}->{1}->{PASSWD},
                -oracle_passwd => $testbed_alias_data->{LOGIN}->{2}->{PASSWD},
                -admin_passwd => $testbed_alias_data->{LOGIN}->{3}->{PASSWD},
                -boot_val =>  $boot_val,
                -iso_path => $build_path,
            );
        
            $logger->debug(__PACKAGE__ . "dumping slave_args ".Dumper(\%slave_args));

            ($pid, $log_file) = &installG8(%slave_args);
            unless($pid){
                $logger->error(__PACKAGE__ . ".$sub_name: ISO Installation on SLAVE PSX ($slave_args{-mgmt_ip}) failed.");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
                return 0;
            }
            $logger->info(__PACKAGE__ . ".$sub_name: ISO Installation on SLAVE PSX ($slave_args{-mgmt_ip}) started, process id is $pid.");
            $pids{$pid} = $log_file;
        }
    }

    unless(&waitForIsoInstallation(%pids)){
        $logger->info(__PACKAGE__ . ".$sub_name: ISO Installation failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]-");
        return 0;    
    }

    $logger->error(__PACKAGE__ . ".$sub_name: ISO Installation success.");
    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[1]-");
    return 1;
}

=head2 C< doInstall >

=over	

=item DESCRIPTION:

    This subroutine executes the install script for different combinations of variants and types of PSX and stores the logs in $log_file path

=item ARGUMENTS:

    This subroutine expects 2 mandatory arguments:
		testbed        : tms alias of the testbed
		type           : type of PSX. It can be one of the following:
				'active' or 'standby' in case of HA
				'master' or 'slave' in case of Standalone
                version        : Version of PSX
	Optional arguments:
		variant        : Optional variant of the PSX, mandatory only in case of HA. It can be one of the following:
				'V3700', 'SAN'
		master_testbed : Optional tms alias of master psx, mandatory only in case of Standalone slave.

=item RETURNS:

	returns 1 on success and 0 on failure

=item EXAMPLE:

    unless(SonusQA::PSX::INSTALLER::doInstall(
        testbed => '',
        type    => 'active',
        variant => 'V3700',
        version => 'V1003'
        ){
        $logger->error(__PACKAGE__ . ".$sub_name: PSX installation Failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
	}
    )

=back

=cut

sub doInstall {
    my (%args) = @_;
	
    my $sub_name = "doInstall";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: Entered Sub");
	$logger->info(__PACKAGE__ . ".$sub_name: args: ". Dumper(\%args));
	
	my @mandatory_args = qw(type variant version);
    if ($args{type} eq 'slave' || $args{type} eq 'master') {
        $args{variant} = 'PSX';
        if($args{type} eq 'slave' && $args{master_testbed}) {
            my $testbed_alias_data2 = SonusQA::Utils::resolve_alias($args{master_testbed});
            $args{master_name} = $testbed_alias_data2->{NODE}->{1}->{NAME};
            $args{master_psx_ip} = $testbed_alias_data2->{NODE}->{1}->{IP};
            push @mandatory_args, ('master_name', 'master_psx_ip');#because not mandatory unless standalone slave
        }
    }
	
    my $flag = 1;	
    foreach (@mandatory_args) { #checking mandatory parameters defined or not
        unless ($args{$_} ) {
            $logger->error(__PACKAGE__ . ".$sub_name: ERROR: Mandatory \"$_\" parameter not provided ");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            $flag = '';
            last;
        }
    }
    return 0 unless($flag);
	
	
	if($args{testbed}){
		my $testbed_alias_data = SonusQA::Utils::resolve_alias($args{testbed});
		$args{psx_ip} = $testbed_alias_data->{NODE}->{1}->{IP};
		$args{psx_ilom_ip} = $testbed_alias_data->{NODE}->{1}->{ILOM_IP};
		$args{mpath} = $testbed_alias_data->{NODE}->{1}->{TYPE};
	}
		
    $args{type} = uc $args{type};
    $args{variant} = uc $args{variant};
 	
    my $log_file = "$ENV{ HOME }/ats_user/logs/install$args{variant}"."$args{type}"."_$args{psx_ip}"."_". time;
 	
    my $expect_script = "$ENV{ HOME }/ats_repos/lib/perl/SonusQA/PSX/ExpectScripts/$args{version}/INSTALL/install_$args{variant}"."_$args{type}";
	
    unless(-e $expect_script) {
        $logger->error(__PACKAGE__ . ".$sub_name: ERROR $expect_script not found.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0] ");
        return 0;
    }

    my $cmd = $expect_script." $args{psx_ip}";
	
    if ($args{type} eq 'SLAVE') {
        $cmd .= " $args{master_name} $args{master_psx_ip}";
    } elsif ($args{type} eq 'STANDBY' || $args{type} eq 'ACTIVE') {
        unless ($args{psx_ilom_ip}) {
			$logger->error(__PACKAGE__ . ".$sub_name: ERROR: Mandatory \"psx_ilom_ip\" parameter not initialized ");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        $cmd .= " $args{psx_ilom_ip}";
		
        if ($args{type} eq 'STANDBY' && $args{variant} eq 'SAN') {
            unless ($args{mpath}) {
                $logger->error(__PACKAGE__ . ".$sub_name: ERROR: Mandatory \"mpath\" parameter not initialized ");
                $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
            $cmd .= " $args{mpath}";
        }
    }	
    $cmd .= " > $log_file";

    $logger->debug(__PACKAGE__ . ".$sub_name: executing iso installation command: $cmd");

    my @result = `$cmd`;

    $logger->info(__PACKAGE__ . ".$sub_name: output of $cmd -> \@result" .Dumper(\@result));

    $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;

}

=head2 C< toggleSoftswitch  >

=over

=item DESCRIPTION

	executes either the 'start.Softswitch' or 'stop.Softswitch' script

=item ARGUMENTS

	expects 1 argument either 'start' or 'stop'

=item RETURNS

	1 if successful.
	0 if failed.

=item EXAMPLE

    unless (SonusQA::PSX::INSTALLER::toggleSoftswitch('start')) {
        $logger->error(__PACKAGE__ . ".$sub_name installation on G8 failed.");
        $logger->info(__PACKAGE__ . ".$sub_name <-- leaving Sub [0]");
        return 0;
    }

=back

=cut

sub toggleSoftswitch{
    my ($self, $toggle) = @_;
    my $sub_name = 'toggleSoftswitch';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub -->");
    SonusQA::PSX::execCmd($self,'cd /export/home/ssuser/SOFTSWWITCH/BIN/');
    unless ($self->{conn}->print("./$toggle.ssoftswitch")){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to $toggle softswitch");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my ($prematch, $match) = ('','');
    unless (($prematch, $match) = $self->{conn}->waitfor(
            -match   => $self->{conn}->prompt,
            -errmode => 'return',
            -timeout => 60
        )){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get the prompt. Prematch: $prematch, Match: $match");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< verifyHA >

=over

=item DESCRIPTION

	This subroutine executes getstate command in PSX and checks whether it is same as the parameters 'actual' and 'configured'.

=item ARGUMENTS

	expects 3 arguments:
		$self is connection object of the PSX
		$args{actual} is 'actual' state of the PSX.
		$args{configured} is 'configured' state of PSX

=item RETURNS

	1 on Success
	0 on failure

=item EXAMPLE

    unless(verifyHA($self_active,'STANDBY', 'ACTIVE')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check the states on active");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

=back

=cut

sub verifyHA {
    my ($self, %args) = @_;
    my $sub_name = "verifyHA";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub -->");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub -->args ".Dumper(\@_));
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub -->". $self ." , " . $args{actual}." , " . $args{configured});
    my @get_state;
    unless(@get_state = $self->{conn}->cmd(String => 'getstate', Prompt => '/.*\>+\s?$/')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to get the states of the PSX");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    my ($actual_state, $config_state);
    foreach(@get_state){
        if($_ =~ /Actual state:\s*(\S+)\s*/i){
            $actual_state = $1;
        }elsif($_ =~ /Configured state\:\s*(\S+)\s*/i){
            $config_state = $1;
        }
    }
    unless($actual_state eq $args{actual} and $config_state eq $args{configured}){
        $logger->error(__PACKAGE__ . ".$sub_name: The required states and actual states do not match.");
        $logger->debug(__PACKAGE__ . ".$sub_name:  States to be matched are: Actual state: $args{actual} and Configured state: $args{configured}. States obtained using 'getstate' command are: Actual state: $actual_state and configured state: $config_state.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->error(__PACKAGE__ . ".$sub_name: The required states and actual states are same.");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< checkMount >

=over

=item DESCRIPTION

	This subroutine checks whether '/export/raid' is mounted in active PSX or not

=item ARGUMENTS

	Expects a connection object of the active PSX

=item RETURNS

	1 if path is mounted
	0 if path is not mounted

=item EXAMPLE

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking for mount path '/export/raid' on active PSX after starting softswitch");
    unless(checkMount($self_active)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check mount point on Active PSX");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

=back

=cut

sub checkMount{
    my $self = shift;
    my $sub_name = "checkMount";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub -->");
    for(1..3){
        $logger->debug(__PACKAGE__ . ".$sub_name: Checking for '/export/raid'. Attempt $_ of 3");
        my @cmd_result = SonusQA::PSX::execCmd($self,'df -kh | grep /export/raid');
        if(@cmd_result){
            $logger->debug(__PACKAGE__ . ".$sub_name: Mount path found");
            last;
        }else {
            if ($_ < 4){
                $logger->warn( __PACKAGE__ . ".$sub_name: Attempt $_ failed. Unable to find the mount path");
                $logger->info( __PACKAGE__ . ".$sub_name: Attempting again... " );
            }
            else {
                $logger->error( __PACKAGE__ . ".$sub_name: Reached max attempts(3). Could not find the mount path");
                $logger->debug( __PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
                return 0;
            }
        }
        sleep(10);
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 C< copyLogs >

=over

=item DESCRIPTION

	This subroutine uses SonusQA::SCPATS to store 3 types of logs

=item ARGUMENTS

	This subroutine expects a connection object of a PSX

=item RETURNS

	1 on Success
	0 on Failure

=item EXAMPLE

    unless(copyLogs($psx_active)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to copy the logs to ATS");
        $flag = 0;
        last;
    }

=back

=cut

sub copyLogs{
    my $self = shift;
    my $sub_name = "copyLogs";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub -->");
    my $flag = 1;
    my @logs = ('/opt/sonus/platform/logs/RAIDV3700.log', '/var/opt/sonus/*', '/export/home/ssuser/SOFTSWITCH/BIN/*');
    my %scp_args;
    $scp_args{host} = $self->{'OBJ_HOST'};
    $scp_args{user} = $self->{'OBJ_USER'};
    $scp_args{password} = $self->{'OBJ_PASSWORD'};
    $scp_args{port} = '22';
    my $scp;
    unless($scp = SonusQA::SCPATS->new(%scp_args)) {
	$logger->error(__PACKAGE__ . "$sub_name: SCPATS could not establish a connection");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
	return 0;
    }
    my $source_file_path;
    my  $destination_file_path = "/home/$ENV{USER}/ats_user/logs/IUG/";
    `mkdir -p $destination_file_path`;
    foreach(@logs){
        $logger->debug(__PACKAGE__ . ".$sub_name: Copying $_");
        $source_file_path = $scp_args{-hostip}.':'.$_;
        unless($scp->scp($source_file_path, $destination_file_path)){
            $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the log $_");
            $flag = 0;
            next;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:  Successfully copied $_ to $scp_args{-destinationFilePath}");
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 C< validateHA >

=over

=item DESCRIPTION

	This subroutine does the following:
	1: Starts the softswitch in both 'active' and 'standby' PSX.
	2: It checks whether '/export/raid' is mounted in 'active'.
	3: Verifies if both the 'actual'and 'configured' state are same for each of the 'activ'e and 'standby' PSX.
	4: Issues 'failover' to change states to check if the states change successfully.
	5: Verifies the new 'actual' and 'configured' states in both 'active' and 'standby' PSX after 'failover'.
	6: Checks whether '/export/raid' is mounted in 'standby' that is now 'active'.
	7: Issues 'failover' again to restore original states in both PSX.
	8: check whether '/export/raid' is mounted in 'active' after restoration of state.
	9: copies logs.

=item ARGUMENTS

	It expects 2 arguments:
		1: active PSX TMS alias
		2: standby PSX TMS alias

=item RETURNS

	0 - on failure
	1 - on success

=item EXAMPLE

    unless(SonusQA::PSX::INSTALLER::validateHA(
            testbed_active => $testbed_active,
            testbed_standby =>  $testbed_standby)) {
	$logger->error(__PACKAGE__ . ".$sub_name: validation of activea and standby PSX failed.");
        $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
        return 0;
    }

=back

=cut

sub validateHA {
    my $sub_name = "validateHA";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: Entered sub -->");

    my ($testbed_active, $testbed_standby) = @_;
    my $testbed_alias_data1 = SonusQA::Utils::resolve_alias($testbed_active);
    my $active_psx_ip = $testbed_alias_data1->{NODE}->{1}->{IP};
    my $testbed_alias_data2 = SonusQA::Utils::resolve_alias($testbed_standby);
    my $standby_psx_ip = $testbed_alias_data2->{NODE}->{1}->{IP};

    my ($self_active, $self_stdby);
    $self_active = SonusQA::Base->new(  -obj_host => $active_psx_ip,
                                        -obj_user => 'ssuser',
                                        -obj_password => 'ssuser',
                                        -comm_type => 'SSH',
                                        -defaulttimeout => 10,
                                        -sessionlog   => 1,
    );

    $self_stdby = SonusQA::Base->new(  -obj_host => $standby_psx_ip,
                                        -obj_user => 'ssuser',
                                        -obj_password => 'ssuser',
                                        -comm_type => 'SSH',
                                        -defaulttimeout => 10,
                                        -sessionlog   => 1,
    );


    $logger->debug(__PACKAGE__ . ".$sub_name: Starting Softswitch on active");
    unless(toggleSoftswitch($self_active, 'start')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to start softswitch for  Active PSX");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Sleeping for 180 seconds");
    sleep(180);

    $logger->debug(__PACKAGE__ . ".$sub_name: Checking for mount path '/export/raid' on active PSX after starting softswitch");
    unless(checkMount($self_active)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check mount point on Active PSX");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
	
    $logger->info(__PACKAGE__ . ".$sub_name: Sleeping for 60 seconds");
    sleep(60);

    $logger->debug(__PACKAGE__ . ".$sub_name: Starting Softswitch on standby");
    unless(toggelSoftswitch($self_stdby, 'start')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to start softswitch for Standby PSX");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Sleeping for 60 seconds");
    sleep(60);


    $logger->debug(__PACKAGE__ . ".$sub_name: Verifying HA system status on active and standby");
    my @verify_ha_array = ([$self_active, 'ACTIVE'],[$self_stdby, 'STANDBY']);
    foreach (@verify_ha_array) {
        unless($$_[0]->{conn}->cmd(String => 'hamgmt 127.0.0.1 3089', Prompt => '/.*\>+\s?$/')){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to enter hamgmt prompt on $$_[1]");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $$_[0]->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $$_[0]>{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $$_[0]->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
        unless(verifyHA($$_[0], $$_[1], $$_[1])){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to check the states on $$_[1]");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Issuing 'failover' to change the states");
    unless($self_active->{conn}->cmd(String => 'failover', Prompt => '/.*\>+\s?$/')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to switch state on active PSX");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self_active->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self_active->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self_active->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Sleeping for 120 seconds");
    sleep(120);
    unless(verifyHA($self_active,'STANDBY', 'ACTIVE')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check the states on active");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless(verifyHA($self_stdby,'ACTIVE', 'STANDBY')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check the states on standby");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless($self_stdby->{conn}->cmd(String => 'exit', Prompt => '/[#>]\s?$/')){
        $logger->error(__PACKAGE__ . ".$sub_name: Could not exit from hamgmt");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self_stdby->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self_stdby->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self_stdby->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Checking for mount path '/export/raid' on standby PSX after failover on active");
    unless(checkMount($self_stdby)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check mount point on Standby PSX after failover on active");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless($self_stdby->{conn}->cmd(String => 'hamgmt 127.0.0.1 3089', Prompt => '/.*\>+\s?$/')){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to enter hamgmt prompt on standby");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self_stdby->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self_stdby->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self_stdby->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    unless($self_stdby->{conn}->cmd(String => 'failover', Prompt => '/.*\>+\s?$/')){
        $logger->error(__PACKAGE__ . ".$sub_name: Could not execute failover from standby");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self_stdby->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self_stdby->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self_stdby->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Sleeping for 120 seconds");
    sleep(120);
    foreach(@verify_ha_array) { #see line number 708
        unless(verifyHA($$_[0],$$_[1], $$_[1])){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to check the states on active");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my $flag = 1;
    for($self_active, $self_stdby){
        unless($_->{conn}->cmd(String => 'exit', Prompt => '/[#>]\s?$/')){
            $logger->error(__PACKAGE__ . ".$sub_name: Could not exit from hamgmt");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $_->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $_->{conn}->last_line);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $_->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $_->{sessionLog2}");
            $flag = 0;
            last;
        }
    }
    if($flag == 0){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: Checking for mount path '/export/raid' on active PSX after failover on standby");
    unless(checkMount($self_active)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to check mount point on Active PSX after failover on standby");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $flag = 1;
    for($self_active, $self_stdby){
        unless(copyLogs($_)){
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to copy the logs to ATS");
            $flag = 0;
            last;
	}
    }
    if($flag == 0){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}
	


1;
