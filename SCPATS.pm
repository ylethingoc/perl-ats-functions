package SonusQA::SCPATS; 

use strict;
use SonusQA::Utils qw (:all);
use Data::Dumper;
use SonusQA::Base ;
use Net::OpenSSH;
use Data::UUID;
use Net::Telnet;

=head1 NAME

 SonusQA::SCPATS - SonusQA namespace SCPATS class

=head1 AUTHOR
 Aneesh Karattil <akarattil@rbbn.com>

=head1 SYNOPSIS

 use SonusQA::SCPATS;
 my $scp = SonusQA::SCPATS->new( 
    host=> '10.54.252.88' , 
    user=> 'linuxadmin', 
    password=> 'sonus1', 
    port => '2024',
    timeout=>180 );

=head1 REQUIRES

 Net::OpenSSH, Log::Log4perl, Data::Dumper, SonusQA::Utils 

=head1 DESCRIPTION

 SonusQA::SCPATS provides an extended interface to Net::OpenSSH. 
 This provides scp functionality to and from remote host.
 Mainly it is used to replace directt use of Net::SCP::Expect in feature pm. 

=head1 SEE ALSO
L<Net::OpenSSH>

=head1 SUBROUTINES

=cut

=head2 B< new >
=over 6
=item DESCRIPTION:
    This returns a SonusQA namespace object of SCPATS which is an extended interface to Net::OpenSSH.

=item Arguments:
Mandatory:
    host=> remote host ip, 
    user=> remote host user id, 
    password=> remote host password

Optional:
    identity_file => ssh key file with complete path
    port => remote host port, default value is 22
    timeout=> timeout value in seconds, default value is 360

=item Returns:
    object reference - on success
    0 - on failure

=item Example:
    my $scp = SonusQA::SCPATS->new( host=> $sbx_IP , user=> 'root' , password=> 'sonus1', port => '2024',timeout=>180 );

=back

=cut

sub new {
    my($class, %args) = @_;
    my $sub = "new";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__. ".$sub: --> Entered sub ");

    $args{port} ||= 22;
    $args{timeout} ||= 360;

    my $self = bless {}, $class;
    $self->{time_out} = $args{timeout} ;
    # TOOLS-17460
    $logger->debug(__PACKAGE__ . ".$sub $args{host}, $args{port}, $main::TESTSUITE->{SBX5000_APPLICATION_VERSION}");
    if($args{user} eq 'root' && $args{port} ==  2024 && $main::TESTSUITE->{SBX5000_APPLICATION_VERSION}){
        (my $version = $main::TESTSUITE->{SBX5000_APPLICATION_VERSION})=~s/^SBX_//;
        $logger->info(__PACKAGE__ . ".$sub  version: $version");
        if(SonusQA::Utils::greaterThanVersion( $version, 'V07.01.00')){
            $self->{CHOWN} = 1;
            $args{user} = 'linuxadmin';
            $args{password} = 'sonus';
        }
    }

    $self->{USER} = $args{user};
    $self->{PASSWORD} = $args{password};
    $self->{TYPE} = __PACKAGE__;

    #when cloud instance is spawned using ssh keys for user linuxadmin and user call SonusQA::SCPATS::new() with password, scp will not work
    #To overcome this problem, storing key file in the global hash %SSH_KEYS in SBX5000::setSystem.
    #key file is stored with host ip and username in %SSH_KEYS
    if (exists $SSH_KEYS{$args{host}} and $SSH_KEYS{$args{host}}{$args{user}} and !$args{identity_file}) {
        $args{identity_file} = $SSH_KEYS{$args{host}}{$args{user}};
    }

    my $user_home = qx#echo ~#;
    chomp ($user_home);
    unless ($args{password} or $args{identity_file}) {
        $user_home =~ /\/.+\/(.+)$/;
        my $current_user = $1;
        # checking scp user and current user are same
        if ($args{user} eq $current_user) {
            $logger->debug(__PACKAGE__ . ".$sub: Getting the key file from user home");
            unless (-e "$user_home/.ssh/id_rsa") {
                $logger->error(__PACKAGE__ . ".$sub: key file is not present");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
            }
            $args{identity_file} = $user_home."/.ssh/id_rsa";
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub: Neither password nor ssh-keys are provided");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }

    if ($args{identity_file}) {
        $logger->info(__PACKAGE__ . ".$sub: Using key file for login.");
        delete $args{password}; # TOOLS-17224 Giving priority to identity file if both hey file and password are passed.
    }

    # TOOLS-17589 Changing permission for user home directory as ~/.libnet-openssh-perl is the default location for SSH master control socket to be created and this directory and its parents must be writable only by the current effective user or root
    my $change_permission = `chmod 755 $user_home`;
    $logger->debug(__PACKAGE__ . ".$sub: scp args : ". Dumper (\%args));

    $self->{STDERR_FILE} = "$user_home/ssh_".time.'.err';
    my $stderr_fh;
    unless(open $stderr_fh, '>', $self->{STDERR_FILE}){
        $logger->warn(__PACKAGE__ . ".$sub: Couldn't create $self->{STDERR_FILE} for stderror: $!. So errors will mnot be captured.");
        delete $self->{STDERR_FILE};
        $self->{SSH} = Net::OpenSSH->new($args{host}, user=> $args{user} , password=> $args{password} , port => $args{port} , master_opts => [-o  => "StrictHostKeyChecking=no", -o => "UserKnownHostsFile=/dev/null"], timeout => $args{timeout}, key_path => $args{identity_file});
#        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
#       return 0;
    }
    else{
        $self->{SSH} = Net::OpenSSH->new($args{host}, user=> $args{user} , password=> $args{password} , port => $args{port} , master_opts => [-o  => "StrictHostKeyChecking=no", -o => "UserKnownHostsFile=/dev/null"], timeout => $args{timeout}, key_path => $args{identity_file}, default_stderr_fh => $stderr_fh);
    }
    if($self->{SSH}->error){
      $logger->error(__PACKAGE__ . ".$sub: connection error : ". $self->{SSH}->error);
      $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
      return 0;
    }

    if ($self->{CHOWN}) {
        my $ug = new Data::UUID();
        my %sessionLogInfo;
        my $uuid = $ug->create_str();
        $sessionLogInfo{sessionDumpLog} = "/tmp/sessiondump_". $uuid. ".log";
        $sessionLogInfo{sessionInputLog} = "/tmp/sessioninput_". $uuid. ".log";

        # Update the log filenames
        SonusQA::Base::getSessionLogInfo($self, -sessionLogInfo   => \%sessionLogInfo);

        $self->{sessionLog1} = $sessionLogInfo{sessionDumpLog};
        $self->{sessionLog2} = $sessionLogInfo{sessionInputLog};
 
        my ($pty, $pid) = $self->{SSH}->open2pty({stderr_to_stdout => 1});
        $self->{TELNET} = Net::Telnet->new(-fhopen => $pty,
                                      -prompt => '/.*[\$#%>\]]\s?$/',
                                      -telnetmode => 0,
                                      -cmd_remove_mode => 1,
                                      -output_record_separator => "\r",
                                      -Dump_log => $self->{sessionLog1},
                                      -Input_log => $self->{sessionLog2},
                                      );

        $logger->debug(__PACKAGE__ . ".$sub:  <-- Session Input Log: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Session Dump Log:$self->{sessionLog1}");
        unless($self->{TELNET}->waitfor(-match => $self->{TELNET}->prompt,
                     -errmode => "return")) {
            $logger->error(__PACKAGE__ . ".$sub: Failed to do telnet connection");
            $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [$class]");
    return $self;
}

=head2 B< scp >
=over 6
=item DESCRIPTION:
    This copies the files from source to destination.
    Remote host can be the source or destination. Has to pass the remote host ip along with the sourece or destination accordingly. 
    
=item Arguments:
Mandatory:
    source - source file
    destination - destination file

Returns:

    1 - on success
    0 - on failure

=item Example:
    - Copying from remote host:
        $scp->scp("$remote_ip:$source",$dest);
    - Copying to remote host:
        $scp->scp($source,"$remote_ip:$dest");

=back

=cut


sub scp{
    my($self, $source, $dest) = @_;
    my $sub = "scp";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__. ".$sub: --> Entered sub ");

    my ($flag, $retry) = (1, 1);
    if($dest =~/(.+):(.+)$/ || ($source =~/$ENV{USER}/ &&  $source !~/:/)){ #TOOLS-20830
        $dest = $2 if($2); #TOOLS-74595
        my $orig_dest = $dest;
        if($self->{CHOWN}){
            $dest = '/tmp/scp_put_'.time.'/';
             unless($self->{SSH}->system("mkdir $dest")){
                $logger->error(__PACKAGE__ . ".$sub: Failed to execute 'mkdir $dest'");
                $flag = 0;
            }
        }
        if($flag){
            $logger->debug(__PACKAGE__ . ".$sub: scp_put => $source to $dest");
            $source =~ s/^\~/$ENV{"HOME"}/;             #TOOLS-73189
            unless( $self->{SSH}->scp_put({recursive => "1", glob => 1}, $source, $dest)){
                $logger->error(__PACKAGE__ . ".$sub: Failed to execute scp_put, $source to $dest");
                if($self->{STDERR_FILE}){
                    my $cat_out =  `cat $self->{STDERR_FILE}`;
                    $logger->debug(__PACKAGE__ . ".$sub: ERROR : $cat_out");
                }
                $flag=0;
            }
            elsif($self->{CHOWN}){
                $logger->debug(__PACKAGE__ . ".$sub: executing 'sudo mv $dest/* $orig_dest'");
                my ($prematch, $match) ;
                $self->{TELNET}->print("sudo mv $dest/* $orig_dest");
                unless(($prematch, $match) = $self->{TELNET}->waitfor(
                                              -match => $self->{TELNET}->prompt,
                                              -match => '/linuxadmin\@.+\$/',
                                              -match => '/[P|p]assword for linuxadmin:/',
                                              -errmode   => "return",
                                                )){
                    $logger->error(__PACKAGE__ . ".$sub: Failed to get expected prompt after 'sudo mv $dest/* $orig_dest'");
                    $flag=0;
                }
                if ($match =~ m/[P|p]assword for linuxadmin:/) {
                    $logger->info(__PACKAGE__ . ".$sub: Trying with linuxadmin password");
                    $self->{TELNET}->print($self->{PASSWORD}) ;
                    unless($self->{TELNET}->waitfor (
                                                      -match => $self->{TELNET}->prompt,
                                                      -match => '/linuxadmin\@.+\$/',
                                                      -errmode   => "return",
                                                      -timeout => $self->{timeout},)){
                        $logger->error(__PACKAGE__ . ".$sub: Failed doing 'sudo mv $dest/* $orig_dest'");
                        $flag=0;
                    } ;
                }
                $self->{SSH}->system("rm -rf $dest");
                $dest = $orig_dest;
            }
        }
    }
    else{
        $source =~ s/^$self->{SSH}->{_host}://; #TOOLS-76160 #TOOLS-78295
        $dest =~ s/^\~/$ENV{"HOME"}/;                   #TOOLS-73189
EXECUTE:
        unless( $self->{SSH}->scp_get({recursive => "1", glob => 1}  , $source , $dest)){
            $logger->error(__PACKAGE__ . ".$sub: Failed to execute scp_get : $source to $dest");
            if($self->{STDERR_FILE}){
                my $cat_out =  `cat $self->{STDERR_FILE}`;
                $logger->debug(__PACKAGE__ . ".$sub: ERROR : $cat_out");
                if($self->{CHOWN} && $retry && $cat_out =~/Permission denied/){
                    $logger->debug(__PACKAGE__ . ".$sub: Got Permission denied error, so trying 'chown $self->{USER} $source'");
                    my ($prematch, $match) ;
                    $self->{TELNET}->print("sudo chown $self->{USER} $source");
                    if(($prematch, $match) = $self->{TELNET}->waitfor(
                                              -match => $self->{TELNET}->prompt,
                                              -match => '/linuxadmin\@.+\$/',
                                              -match => '/[P|p]assword for linuxadmin:/',
                                              -errmode   => "return",)){
                        if ($match =~ m/[P|p]assword for linuxadmin:/) {
                            $logger->info(__PACKAGE__ . ".$sub: Trying with linuxadmin password");
                            $self->{TELNET}->print($self->{PASSWORD}) ;
                            unless($self->{TELNET}->waitfor(                     
                                                          -match => $self->{TELNET}->prompt,
                                                          -match => '/linuxadmin\@.+\$/',
                                                          -errmode   => "return",)){
                                $logger->error(__PACKAGE__ . ".$sub: Failed doing 'sudo chown '");
                                $flag = 0;
                            } 
                        }
                        if ($flag) {
                            $logger->debug(__PACKAGE__ . ".$sub: Trying SCP again");
                            $retry = 0;
                            goto EXECUTE;
                        }
                    }else {
                        $logger->debug(__PACKAGE__ . ".$sub: Failed to get the expected prompt");
                    }
                }
            }
            $flag=0;
        }
    }

    if($flag) {
        $logger->debug(__PACKAGE__ . ".$sub: Successfully copied  $source  to $dest");
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub: scp error : ".$self->{SSH}->error);
        $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the $source to $dest");
    }

    $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [$flag]");
    return $flag; 
}

sub DESTROY {
    my ($self)  = @_;
    my $sub = "DESTROY";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__. ".$sub: --> Entered sub ");
    if($self->{STDERR_FILE}){
        $logger->debug(__PACKAGE__. ".$sub: rm $self->{STDERR_FILE}");
        `rm $self->{STDERR_FILE}`;
    }
    $logger->debug(__PACKAGE__. ".$sub: <-- Leaving sub");
}

1;

