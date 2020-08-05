package SonusQA::QSBC;

=head1 NAME

  SonusQA::QSBC - Perl module for any QSBC

=head1 AUTHOR

  Rohit Baid - rbaid@sonusnet.com

=head1 IMPORTANT

  B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

  use ATS;           # This is the base class for Automated Testing Structure
  my $obj = SonusQA::QSBC->new(-OBJ_HOST => '<host name | IP Adress>',
                               -OBJ_USER => '<cli user name - usually dsi>',
                               -OBJ_PASSWORD => '<cli user password>',
                               -OBJ_COMMTYPE => "<TELNET|SSH>",
                               optional args
                              );

=head1 REQUIRES

  Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper 

=head1 DESCRIPTION

  This module provides an interface for Any TOOL installed on Linux server.

=head1 METHODS

=cut

use SonusQA::Utils qw(:all);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use Net::Telnet;
our @ISA = qw(SonusQA::Base);
=head2 doInitialization

=over

=item DESCRIPTION:

  Routine to set object defaults and session prompt.

=item ARGUMENTS:

  None

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  None

=back

=cut

sub doInitialization {
    my($self, %args)=@_;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");

    $self->{COMMTYPES} = ["SSH"];
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{PROMPT} = '/.*[\$%#\}\|\>].*$/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT};
    $self->{STORE_LOGS} = 2;
}

=head2 setSystem

=over

=item DESCRIPTION:

  This function sets the system information.

=item ARGUMENTS:

  None

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  None

=back

=cut

sub setSystem {
    my($self)=@_;
    my $sub = "setSystem";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub : --> Entered Sub");
    my($cmd, $prevPrompt,$qsbc_type);
    
    $self->{conn}->cmd("bash");
    $self->{conn}->cmd("");
    $cmd = 'export PS1="AUTOMATION> "';
    $self->{conn}->last_prompt("");
    $self->{PROMPT} = '/AUTOMATION\> $/';
    $prevPrompt = $self->{conn}->prompt('/AUTOMATION\> $/');
    $logger->info(__PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->prompt . " FROM: $prevPrompt");
    $self->{conn}->cmd($cmd);
    $self->{conn}->cmd("unalias ls");
    $self->{conn}->cmd("unalias grep");
#    $self->{conn}->cmd(" ");
    $self->{conn}->waitfor(-match => $self->{PROMPT}, timeout => 2);
    $logger->info(__PACKAGE__ . ".$sub  SET PROMPT TO: " . $self->{conn}->last_prompt);
    $self->{LOG_PATH} = '/var/log';
    my ($results) = $self->{conn}->cmd("machine_info --all | grep class");
    $self->{conn}->waitfor(-match => $self->{PROMPT}, timeout => 2);
    if($results=~/class\s+=\s+sandybridge(\S+)/)
    {
      if($1 eq '2u-q21')
      {
        
        $qsbc_type = 'Q21';
      }
      elsif($1 eq '2u')
      {
        $qsbc_type = 'Q20';
      }
      elsif($1 eq '1u')
      {
        $qsbc_type = 'Q10';
      }
      else{
        $qsbc_type = 'annapolis';
      }
    }
    $logger->debug(__PACKAGE__.".$sub : The QSBC Type is $qsbc_type");
    $self->{QSBC_TYPE} = $qsbc_type;
    $logger->info(__PACKAGE__ . ".$sub : <-- Leaving sub");

}

=head2 execCmd

=over

=item DESCRIPTION:

  This function enables user to execute any command on QSBC.

=item ARGUMENTS:

  1. Command to be executed.
  2. Timeout in seconds (optional).

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  Output of the command executed. 

=item Example:

  my @results = $obj->execCmd("allstart");
  my @results = $obj->execCmd("allstart",$timeout);
  This would execute the command "allstart" on the session and return the output of the command.

=back

=cut

sub execCmd{
   my ($self,$cmd,$timeout)=@_;
   my $sub = "execCmd()";
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
   my @cmdResults;
   $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");

   if (!(defined $timeout)) {
      $timeout = $self->{DEFAULTTIMEOUT};
      $logger->debug(__PACKAGE__ . ".$sub Timeout not specified. Using $timeout seconds ");
   }
   else {
      $logger->debug(__PACKAGE__ . ".$sub Timeout specified as $timeout seconds ");
   }

   $logger->info(__PACKAGE__ . ".$sub ISSUING CMD: $cmd");
   unless (@cmdResults = $self->{conn}->cmd(string => $cmd, timeout => $timeout, errmode => "return")) {
      $logger->error(__PACKAGE__ . ".$sub  COMMAND EXECUTION ERROR OCCURRED");
      $logger->debug(__PACKAGE__ . ".$sub errmsg: " . $self->{conn}->errmsg);
      $logger->debug(__PACKAGE__ . ".$sub  lastline : ". $self->{conn}->lastline);
      $logger->debug(__PACKAGE__ . ".$sub Session Dump Log is : $self->{sessionLog1}");
      $logger->debug(__PACKAGE__ . ".$sub Session Input Log is: $self->{sessionLog2}");
   }

   chomp(@cmdResults);
   $logger->debug(__PACKAGE__ . ".$sub cmd result : ".Dumper \@cmdResults);
   $logger->info(__PACKAGE__ . ".$sub : <-- Leaving sub");
   return @cmdResults;
}

=head2 checkProcessStatus

=over

=item DESCRIPTION:

  This function checks whether all processes are up and running on QSBC.

=item ARGUMENTS:

  None

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  1 - If all processes are running 
  0 - If any of the process is not running

=back

=cut

sub checkProcessStatus {
    my $self = shift;
    my $sub = 'checkProcessStatus()';
    my ($cmd, @cmdResults);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");

    my @processName = qw(gis
                         pm
                         execd
                         dbsync
                         naf
                         reportingdaemon
                         aisexec
                         gis_sa
                         pm_sa
                        );
    #TOOLS-78301                       
    push (@processName, 'kpim') if($self->compareVersion(application=>'gis', user_version=> '9.4.1.0') <= 0); #-1 if user_version less, 0 equal, 1 greater 
 
    #TOOLS-20584
    my @results;
    unless(@results = $self->execCmd('cli ha'))
    {
      $logger->error(__PACKAGE__ . ".$sub Unable to execute command $cmd");		    
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [0]");
      return 0;
    }
    
    #Considering HA if Slave is present in output of 'cli ha'
    push (@processName,'ispd') if(grep /Cluster/, @results);
    
    $logger->debug(__PACKAGE__ . ".$sub Checking if all processes are up and running." . Dumper(\@processName));
    $cmd = "psis";
    unless(@cmdResults = $self->execCmd($cmd)) {
      $logger->error(__PACKAGE__ . ".$sub Unable to execute command $cmd");		    
      $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [0]");
      return 0;
    }
   
=sample o/p
180725 gis
180633 pm
180666 execd
180692 dbsync
180694 naf
180709 reportingdaemon
180627 aisexec
180712 gis_sa
180702 pm_sa
184540 kpim
=cut
 
    my %process = map { $_ => 1} @processName;

    foreach (@cmdResults){
        delete $process{$1} if(/\d+\s+(.+)/);
    }

    if(keys %process){
        $logger->error(__PACKAGE__ . ".$sub Processes ". join (',', keys %process) . "are not up.");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub All processes are up and running.");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [1]");
    return 1;
}

=head2 copyBuild

=over

=item DESCRIPTION:
	
	This function is used to copy the build file present in the release server to the QSBC and extract the contents and also extract the contents on the install.jar file

=item ARGUMENTS:
  Mandatory Arguments:
	'destinationPath'        -  Destination path to where the build needs to be copied.
  
  Select one mandatory argument:
	'version'                -  Version of the QSBC build. OR
  'path'                   -  Source path of the QSBC build. OR
  'file'                   -  Full path of the QSBC build on the release server.
  
  Optional argument:
  'timeout'                - Specifies the time for copying the build file.
	
=items PACKAGE:
	
	SonusQA::QSBC
	
=items OUTPUT:
	
    0   - fail
    1   - success

=items EXAMPLE:
  
  $obj->copyBuild('version' =>'9.3.x.x.','destinationPath'=>'/home/genband/builds/SBC/');
  $obj->copyBuild('path'=>'/export/home/cm/releases/home/releases/rel10.3/iserver/engtest/patches/10.3.12.0/','destinationPath'=>'/home/genband/builds/SBC/')
  $obj->copyBuild('file'=>'/export/home/cm/releases/home/releases/rel9.3/iserver/engtest/patches/9.3.12.0/i686pc-msw-9.3.12.0-110118050549.tar.gz','destinationPath'=>'/home/genband/builds/SBC/');
  
=back
	
=cut

sub copyBuild {
  my ($self,%args) = @_;
  my $sub = "copyBuild";
  $args{destinationPath} ||= "/var/builds/";
  $args{timeout} ||= 1800;
  my $remote_user = $self->{TMS_ALIAS_DATA}->{NFS}->{1}->{USERID};
  my $remote_passwd = $self->{TMS_ALIAS_DATA}->{NFS}->{1}->{PASSWD};
  my $remote_ip =  $self->{TMS_ALIAS_DATA}->{NFS}->{1}->{IP};

  my $flag = 0;
  my $file ="";
  my $version = "";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

  $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");
	
	unless ( $args{version} || $args{path} || $args{file} ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory Source File, Path or Version empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

	unless ( $args{destinationPath} ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory Destination empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
	$logger->debug(__PACKAGE__ . ".$sub --> All Parameters received");
  my $subver = "";

  if ($args{version} =~/(\d+\.\d+)\.\d+\.\d+/)
  {
    $flag=1;
    $logger->debug(__PACKAGE__.".$sub Version is defined.");
    $logger->debug(__PACKAGE__."$sub -- > Version identified, Fetching the release patch.");
    $subver = $1;
    $args{path} = "/export/home/cm/releases/home/releases/rel".$subver."/iserver/engtest/patches/".$args{version}."/";
    $logger->debug(__PACKAGE__.".$sub Release Directory is $args{path}");
  }
  if($args{path})
  {
    $flag = 1;
    $logger->debug(__PACKAGE__.".$sub Populating extension in the hash");
    $args{extension} = "tar.gz";
  }
  if($args{file})
  { 
    $flag = 1;
    $logger->debug(__PACKAGE__.".$sub Full path is defined.");
  }
  unless($flag)
  {
    $logger->error(__PACKAGE__.".$sub Invalid parameter");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
  }

  my %rtrCopyArgs;
  $rtrCopyArgs{-remoteip}            = $remote_ip;
  $rtrCopyArgs{-remoteuser}          = $remote_user;
  $rtrCopyArgs{-remotepasswd}        = $remote_passwd;
  $rtrCopyArgs{-sourceFilePath}      = $args{path} || $args{file};
  $rtrCopyArgs{-destinationFilePath} = $args{destinationPath};
  $rtrCopyArgs{-extension}           = $args{extension} ? $args{extension} : 0;
  $rtrCopyArgs{-recvrip}             = $self->{OBJ_HOST};
  $rtrCopyArgs{-recvruser}           = $self->{OBJ_USER};
  $rtrCopyArgs{-recvrport}           = $self->{OBJ_PORT};
  $rtrCopyArgs{-recvrpassword}       = $self->{OBJ_PASSWORD};
  $rtrCopyArgs{-timeout}             = $args{timeout}; #TOOLS-20584
  
  
  #Call rtrCopy to copy the file (fetch latest file if needed)
  unless($file = &SonusQA::Utils::remoteToRemoteCopy(%rtrCopyArgs))
  {
    $logger->debug(__PACKAGE__.".$sub Copy from Remote to remote failed.");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
    return 0;
  }
  
  $file =~/(\d+\.\d+\.\d+\.\d+)/;
  $version = $1;

  #Moving to destination path to extract the files
  my @result;
  unless(@result = $self->execCmd("cd $args{destinationPath}"))
  {
    $logger->error(__PACKAGE__.".$sub -->Unable to navigate to the directory: $args{destinationPath}");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
    return 0;
  }
  if(grep /No such file or directory/, @result)
  {
    $logger->error(__PACKAGE__.".$sub --> $args{destinationPath} File Not Found");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
    return 0;
  }

  #Extracting in files
  unless(@result = $self->execCmd("tar xvfz $file", $args{timeout}))
  {
    $logger->error(__PACKAGE__.".$sub -->1st tar  Unable to extract file.");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
    return 0;
  }
  if(grep /No such file or directory/, @result)
  {
    $logger->error(__PACKAGE__.".$sub --> Unable to extract file. $file File Not Found");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
    return 0;
  }

  #Moving the directory patch_8.3.x.x
  unless(@result = $self->execCmd("cd patch_$version"))
  {
    $logger->error(__PACKAGE__.".$sub -->Unable to navigate to the directory: patch_$version");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
    return 0;
  }
  if(grep /No such file or directory/, @result)
  {
    $logger->error(__PACKAGE__.".$sub --> $args{destinationPath} File Not Found");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
    return 0;
  }

  #Extracting install files.
  unless(@result = $self->execCmd("tar xvf install.tar"))
  {
    $logger->error(__PACKAGE__.".$sub --> Unable to extract file.");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
    return 0;
  }
  if(grep /No such file or directory/, @result)
  {
    $logger->error(__PACKAGE__.".$sub --> File Not Found");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
    return 0;
  }
  return 1;
}




=head2 mediaAppUnInstall

=over

=item DESCRIPTION:

  This function uninstalls the media services on the QSBC.

=item ARGUMENTS:

  None

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  1 - If all processes started 
  0 - If command execution fails

=item EXAMPLE:
  
  $obj->mediaAppUnInstall(); #Uninstalls the media app on the QSBC.

=back

=cut

sub mediaAppUnInstall{
  my $self = shift;
  my $sub = "mediaAppUnInstall";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");
  
  unless($self->execCmd("/etc/init.d/enp2611 stop"))
  {
    $logger->error(__PACKAGE__.".$sub Unable to stop the media services");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0;      
  }
  
  #Issue command for Uninstalling the media service
  my $cmd;
  $logger->debug(__PACKAGE__ . ".$sub: Uninstalling the media services on the QSBC: $self->{QSBC_TYPE}");
  if($self->{QSBC_TYPE} eq 'Q21')
  {
    $cmd = "rpm -e imedia-q21";
  }
  else
  {
    $cmd = "rpm -e hk";
  }
  
  $logger->debug(__PACKAGE__.".$sub Issuing uninstall command: $cmd");
  unless($self->execCmd($cmd))
  {
    $logger->error(__PACKAGE__.".$sub Unable uninstall the media services");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0; 
  }

  $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [1]");
  return 1;
}




=head2 mediaAppInstall

=over

=item DESCRIPTION:

  This function installs the media services on the QSBC.

=item ARGUMENTS:

  Hash with below details
          -Mandatory
                version                    Version of the QSBC
          
          -Optional
                path                       Path where the patch_9.3.X.X is present
                force                      Enable or disable the  "--force" parameter
=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  1 - If all processes started 
  0 - If command execution fails

=item EXAMPLE:
  
  $obj->mediaAppInstall('version'=>'9.1.22.0','path'=>'/tmp/')
  $obj->mediaAppInstall('version'=>'9.1.22.0','path'=>'/tmp/', 'force'=>'--force')#TOOLS-20584
  
=back

=cut

sub mediaAppInstall{
  my ($self,%args) = @_;
  $args{path} ||= "/var/builds/";
  $args{force} ||= "";
  my $sub = "mediaAppInstall";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub");
  
  
  unless($args{version})
  {
    $logger->error(__PACKAGE__.".$sub: Mandatory argument $args{version} is missing");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0;     
  }
  if($self->{QSBC_TYPE} eq 'Q21')
  {
    
    ($args{mediaFile}) = $self->execCmd("ls $args{path}/patch_$args{version}/ | grep imedia.*.rpm");
  }
  else{
    ($args{mediaFile}) = $self->execCmd("ls $args{path}/patch_$args{version}/ | grep hk.*.rpm");
  }
  
  $logger->debug(__PACKAGE__.".$sub: The QSBC version is $args{version}");
  
  unless($args{mediaFile})
  {
    $logger->error(__PACKAGE__.".$sub: Media App not found in directory $args{path}/patch_$args{version}");
    $logger->debug(__PACKAGE__.".$sub: <-- Leaving Sub [0]");
    return 0;
  }
  
  $logger->debug(__PACKAGE__.".$sub: The media app to be installed is $args{mediaFile}");
  
  #Issue command for Installing the media service
  unless($self->execCmd("rpm -ivh $args{force} /$args{path}/patch_$args{version}/$args{mediaFile}",300))
  {
    $logger->error(__PACKAGE__.".$sub Unable install the media services");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0; 
  }
  
  $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [1]");
  return 1;
}



=head2 allStart

=over

=item DESCRIPTION:

  This function starts all required processes on QSBC.

=item ARGUMENTS:

  timeout - Specifies the timeout value

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  1 - If all processes started 
  0 - If command execution fails

=back

=cut

sub allStart {
    my ($self,$timeout) = @_;
    $timeout ||= 600;
    my $sub = 'allStart()';
    my ($cmd, @cmdResults);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");

    $logger->debug(__PACKAGE__ . ".$sub Start all processes.");
    $cmd = "allstart";
    unless(@cmdResults = $self->execCmd($cmd , $timeout)) {
        $logger->error(__PACKAGE__ . ".$sub Unable to execute command $cmd");
        $logger->info(__PACKAGE__ . ".$sub : <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub Sleeping for 60 seconds");#TOOLS-20584
    sleep(60);

    $logger->debug(__PACKAGE__ . ".$sub All processes started.");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [1]");
    return 1;
}    

=head2 allStop

=over

=item DESCRIPTION:

  This function stops all running processes on QSBC.

=item ARGUMENTS:

  timeout - Specifies the timeout value

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  1 - If all processes stopped
  0 - If command execution fails

=back

=cut

sub allStop {
    my ($self,$timeout) = @_;
    $timeout ||= 600;
    my $sub = 'allStop()';
    my ($cmd, @cmdResults);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");

    $logger->debug(__PACKAGE__ . ".$sub Stop all processes.");
    $cmd = "allstop";
    unless(@cmdResults = $self->execCmd($cmd,$timeout)) {
        $logger->error(__PACKAGE__ . ".$sub Unable to execute command $cmd");
        $logger->info(__PACKAGE__ . ".$sub : <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub Sleeping for 30 seconds"); #TOOLS-20584
    sleep(30);
    $logger->debug(__PACKAGE__ . ".$sub All processes stopped.");
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [1]");
    return 1;
}

=head2 kickOff

=over

=item DESCRIPTION:

  This function helps to clear logs and set debug levels.

=item ARGUMENTS:

  1. Debug Module(optional) - To set log level for specific debug-module
  2. Log level(optional) - For specifying log level to be set  
  3. Log enable(optional) - For enabling logs.

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  None

=back

=cut

sub kickOff {
    my ($self, %args) = @_;
    my $sub = 'kickOff()';
    my ($cmd, @cmdResults);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");
    
    $logger->debug(__PACKAGE__ . ".$sub Clearing iServer log.");
    $cmd = ">/var/log/iserver.log";	
    unless(@cmdResults = $self->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub Unable to execute command $cmd");
	$logger->debug(__PACKAGE__ . ".$sub Failed to clear iServer log.");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub Clearing cdr log.");
    $cmd = ">/var/cdrs/D*.CDT";
    unless(@cmdResults = $self->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub Unable to execute command $cmd");
        $logger->debug(__PACKAGE__ . ".$sub Failed to clear iServer log.");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [0]");
        return 0;
    }
    if($args{-log_enable}){
        $logger->debug(__PACKAGE__ . ".$sub Enabling logs.");
        unless($self->setLogLevel($args{-module}, $args{-level})) {
            $logger->error(__PACKAGE__ . ".$sub Failed to set log level.");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [0]");
    	    return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub Logs enabled successfully.");
    }
    else{
	$logger->debug(__PACKAGE__ . ".$sub \$args{-log_enable} not set.");
    }
    $self->{WAS_KICKED_OFF} = 1;
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [1]"); 
}

=head2 setLogLevel

=over

=item DESCRIPTION:

  This function helps to set debug levels for specific debug module or all the modules.

=item ARGUMENTS:

  1. Debug Module(optional) - To set log level for specific debug-module
  2. Log level(optional) - For specifying log level to be set

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  1 - Success
  0 - Failure  

=back

=cut

sub setLogLevel {
    my ($self, $module, $level) = @_;
    my $sub = 'setLogLevel()';
    my ($cmd, @cmdResults);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");
 
    my @debug_module = ("debug-modsip","debug-modbridge","debug-modfce","debug-modfind","sdebug-level","debug-modlmgr");
    my $flag = 1;
    $level ||= 4;
    if ($module) {	
	$cmd = "nxconfig.pl -e $module -v $level";
	unless(@cmdResults = $self->execCmd($cmd)) {
            $logger->error(__PACKAGE__ . ".$sub Unable to execute command $cmd");
            $logger->debug(__PACKAGE__ . ".$sub Failed to set log level for module $module.");
	    $flag = 0;
	}
    }
    else {
        foreach (@debug_module) {
	    $cmd = "nxconfig.pl -e $_ -v $level";
            unless(@cmdResults = $self->execCmd($cmd)) {
                $logger->error(__PACKAGE__ . ".$sub Unable to execute command $cmd");
                $logger->debug(__PACKAGE__ . ".$sub Failed to set log level for module $_.");
                $flag = 0;
                last;
            }
        }
    }
    
    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [$flag]");
    return $flag;
}

=head2 windUp

=over

=item DESCRIPTION:

   It's wrapper function, called at the end of the test case to collect the logs and do some validation. Steps are as follows - 
	1. Storing logs either on SBX or ATS server or both 
	2. Pattern matching in logs 

=item ARGUMENTS:
  
  tcid(mandatory) - Test case id
  copyLogLocation(mandatory) - path where the logs need to be copied
  file_type(optional) - log file type to be used for parsing
  pattern(optional) - pattern to searched in the log file, it will be a hash reference
  logStoreFlag(optional) - store log flag(Default is 1)
      1 for saving the logs on the SBX itself
      2 for saving logs on ATS server only
      3 for saving logs on both ATS server and SBX

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  1 - Success
  0 - Failure

=back

=cut

sub windUp {
    my ($self, %args) = @_;
    my $sub = 'windUp()';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub");
    my (@searchpattern,%searchpattern,,$cdrhash,%cdrhash,$filename,$cdrvariation,$cdtrecordtype);
    my $parseflag = 0;
    my $passed = 0;

    unless ( $self ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $args{-tcid} ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory  input Test Case ID is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    unless ( $args{-copyLogLocation} ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory  copyLogLocation is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    # Decided to return failure if wind_Up is called without kick_Off.
    unless($self->{WAS_KICKED_OFF}){
        $logger->error(__PACKAGE__ . ".$sub: Can't do windup, since kick_Off is either failed or not called.");
        $logger->debug(__PACKAGE__ . ".$sub: Check whether you are called windup for the same object where kick_Off was success. You might created the object again instead of doing 'makeReconnection()'.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
	$main::failure_msg .= "UNKNOWN:QSBC_windup Error; ";
        return 0;
    }
    
    unless($args{-logStoreFlag}){
        $logger->warn(__PACKAGE__ . ".$sub: The flag for log storage not defined !! Using Default Value 1 ");
        $args{-logStoreFlag} = 1;
    }
    $self->{STORE_LOGS} = $args{-logStoreFlag};
    unless($self->collectCDR(%args)){
        $logger->error(__PACKAGE__ . ".$sub: Couldn't get data from collectCDR function");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
        return 0;
    }
    my @logtype = ('iserver.log');
    
    push (@logtype, @{$args{-file_type}}) if (defined $args{-file_type});
      
    my $flag = 1;
    foreach(@logtype){
      unless ($self->storeLogs($_,$args{-tcid},$args{-copyLogLocation}) ) {
          $logger->error(__PACKAGE__ . " $sub :   Failed to store the log file: $_");
          $flag = 0;
          last;
      }
    }
    unless($flag){
      $logger->debug(__PACKAGE__ .".$sub: <-- Leaving sub [0]");
      return 0;
    }
    
    %searchpattern = %{$args{-pattern}} if(ref($args{-pattern}) eq 'HASH');

      if( scalar(keys(%searchpattern))){
          my ($matchcount,$result);
          $logger->debug(__PACKAGE__ . " $sub: Looking for the following patterns in the log $_ \n ");
          map { $logger->debug("Pattern : '$_' Count : '$searchpattern{$_}'") } keys(%searchpattern);
          ($matchcount,$result) = $self->parseLogFiles($_,\%searchpattern);
          unless($result == 1){
              $logger->error(__PACKAGE__ . " $sub: Expected counts of match for the patterns NOT FOUND in the log $_");
              $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
              return 0;
          }
          $logger->debug(__PACKAGE__ . " $sub: All patterns are MATCHED in the log $_ ");
      }
    else {
        $logger->debug(__PACKAGE__ . " $sub: Input Parse log file type or Search Pattern is empty or undefined. Log Verification Skipped !!");
    }
   
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=pod

=head2 SonusQA::QSBC::nxConfig()

    DESCRIPTION:

    This subroutin configures the new value - might ask for restart of application as well

=over

=item ARGUMENTS:

        Mandatory :
               -hash=>A Name-Value pair should be passed to this subroutine.
=item PACKAGE:

    SonusQA::QSBC

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1 => on success
    0 => on failure

=item EXAMPLE(s)
    my %hash=('ip-layer-conntrack-udp-timeout' =>45 );
    unless($obj->nxConfig(%hash)){
    $logger->error("Cannot execute the subroutine");

}


=back

=cut

sub nxConfig{
    my ($self, %args) = @_;
    my $sub = "nxConfig";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__.".$sub: --> Entered Sub"); 
    my $cmd ="nxconfig.pl ";
    my $flag=1;
    my ($attribute,$attribute_value,$cmd_string);

    foreach my $param(keys %args){
        $attribute = $param;
        $attribute_value = $args{$param};
        if(ref($args{$param}) ne 'ARRAY'){ 
          $cmd  .="-e $param -v $args{$param} ";
        }else{
          $cmd .= "-e $param";
          last;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub:  Executing command: \'$cmd\'");
    unless ( $self->{conn}->print($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub:  Cannot issue \'$cmd\'");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    my ($prematch, $match);
    unless(($prematch, $match)=$self->{conn}->waitfor( -match => '/iServer restart.+:/' ,
                                                       -match => '/Error:/' ,
                                                       -match => '/Option v requires an argument/' ,
                                                       -match => '/Select your choice:/',
                                                       -match => $self->{conn}->prompt    
                                                     )){

        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    if($match =~ /iServer restart.+:/){
        unless($self->{conn}->cmd("y")){
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ .".$sub Server Restarted\n");
         
        unless($self->allStop()){
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        unless($self->allStart()){
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        unless($self->checkProcessStatus()){
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
    }
    elsif($match =~ /Error:/ and (($attribute_value < 1) or ($attribute_value > 100) or ($attribute_value =~// ) or ($attribute_value eq 'string'))){
	$logger->debug(__PACKAGE__ .".$sub Entering Ctrl+C\n");
        unless($self->{conn}->cmd("\cC")){
            $logger->debug(__PACKAGE__ . ".$sub: <-- Failed to enter Ctrl+C. Leaving sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub: Executed Ctrl+C");
    }

    elsif($match =~ /Option v requires an argument/ and $attribute_value eq '' ){
        $logger->debug(__PACKAGE__ .".$sub Entering Ctrl+C\n");
        unless($self->{conn}->cmd("\cC")){
            $logger->debug(__PACKAGE__ . ".$sub: <-- Failed to enter Ctrl+C. Leaving sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ .".$sub Executed Ctrl+C\n");
    }elsif($match =~ /Select your choice:/){
        foreach(@{$attribute_value}){
          unless ( $self->{conn}->print($_) ) {
              $logger->error(__PACKAGE__ . ".$sub:  Cannot issue \'$_\'");
              $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
              $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
              $flag =0;
              last;
          }
          if($prematch =~ /$_\)\s=>\s(.+)/){
            $cmd_string .=" $1" ;  # $cmd_string = cpu memory swap
          }
          my ($prematch1, $match1);
          unless(($prematch1, $match1)=$self->{conn}->waitfor(  -match => '/Select your choice:/' )){
            $logger->error(__PACKAGE__ . ".$sub: Couldn't get the desired match");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $flag =0;
            last;
          }
          if($prematch1 =~ /Invalid Selection:/){
            $logger->error(__PACKAGE__ . ".$sub Invalid Selection");
            $flag =0;
            last;
          }
        }
        unless($self->{conn}->cmd('q')){
            $logger->error(__PACKAGE__ . ".$sub: Coudln't execute command 'q'");
            $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
            $flag =0;
        }
        
        if($flag == 0){
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
            return $flag;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub:Verifying the Values\n");
    my @result;
    unless(@result =$self->execCmd("nxconfig.pl -S | grep $attribute")){
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    if(ref($attribute_value) ne 'ARRAY'){
      foreach my $param(keys %args){
        unless (grep (/$param\s+$args{$param}/ , @result)) {
            $logger->error(__PACKAGE__ . ".$sub: $param --> $args{$param} pair does not match the result");
            $flag=0;
            last;   
        }
      }
   }else{
=head
Sample output for command-->'nxconfig.pl -S | grep   real-time-sys-res-usage-categories'
all        system          real-time-sys-res-usage-categories       cpu memory swap File-descriptors

=cut
      if(grep /$cmd_string/, @result){
          $logger->debug(__PACKAGE__ . ".$sub:Values has been updated");
          $flag =1;
      }else{
          $logger->error(__PACKAGE__ . ".$sub:Failed to update values");
          $flag =0;
      }
      
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
    return $flag;
}

=pod

=head2 SonusQA::QSBC::tacFile()

    DESCRIPTION:

    This subroutin collects the tac files and unatring of tac files to a specified path if path is provided by the user.

=over

=item ARGUMENTS:

    Mandatory : Nothing

=item PACKAGE:

    SonusQA::QSBC

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1=> on success
    0 => on failure

=item EXAMPLE(s)
    my $path="/home/sakumari/untar";

    unless($obj->tacFile($path)){
    $logger->error("Cannot execute the subroutine");

    } 


=back

=cut

sub tacFile{
    my ($self, $path_given)= @_;
    my $sub = "tacFile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__.".$sub: --> Entered Sub");
    unless($self->execCmd("cd /usr/local/nextone/bin")){
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    my ($tar_cmd ,$cd_cmd ,$tacs ,@result);
    unless(@result=$self->execCmd("./tacs -n",300)){
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    foreach my $param(reverse(@result)){
        if($param =~/^\s+# (cd .+)$/){
            $cd_cmd=$1;
        }
        elsif($param =~/^\s+# (tar -czf\s(.+)\s.+)/){
           $tar_cmd= $1;
           $tacs =$2;
       }
       last if($cd_cmd && $tar_cmd)
    }   
    my @cmd_arr=($cd_cmd ,$tar_cmd);
    my $flag=1;

#Untaring of given file
       
    push @cmd_arr, "tar -xvzf $tacs  -C $path_given" if(defined($path_given));
        foreach my $cmd(@cmd_arr){
        unless( $self->execCmd("$cmd")){
            $flag=0;
            last;
        }    
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 saveLicense

=over

=item DESCRIPTION:

  This function saves the license .

=item ARGUMENTS:

  None

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  1 - Success
  0 - Failure

=back

=cut

sub saveLicense{
    my ($self)=@_;
    my $sub_name="saveLicense";
    my $logger=Log::Log4perl->get_logger(__PACKAGE__ .".$sub_name");
    $logger->info(__PACKAGE__ .".$sub_name: --> Entered Sub");
    my $cmd = "nxconfig.pl -L";
    unless( $self->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to save license.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ .".$sub_name: License successfully saved");
    $logger->debug(__PACKAGE__ .".$sub_name: Leaving Sub[1]");
    return 1;
}

=head2 loadLicense

=over

=item DESCRIPTION:

  This function loads the license from a specfied file.

=item ARGUMENTS:

  Optional Argument - $args{file}(file where license will be saved).

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  1 - Success
  0 - Failure

=back

=cut


sub loadLicense{
    my ($self,%args)=@_;
    my $cmd;
    my $sub_name="loadLicense";
    my $logger=Log::Log4perl->get_logger(__PACKAGE__ .".$sub_name");
    $logger->info(__PACKAGE__ .".$sub_name: --> Entered Sub");
    $cmd = "nxconfig.pl -l";
    $cmd .= " -P $args{file}" if($args{file});
    unless ($self->execCmd($cmd) ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to Load license.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: License successfuly loaded");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 saveMediaConfiguration

=over

=item DESCRIPTION:

  This function save media devices configuration.

=item ARGUMENTS:

  optional Arguments- file name (where media devices configuration will be saved)

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  1 - Success
  0 - Failure

=back

=cut


sub saveMediaConfiguration{
    my ($self,%args)=@_;
    my $cmd;
    my $sub_name="saveMediaConfiguration";
    my $logger=Log::Log4perl->get_logger(__PACKAGE__ .".$sub_name");
    $logger->info(__PACKAGE__ .".$sub_name: --> Entered Sub");
    $cmd="nxconfig.pl -M";
    $cmd .= " -f $args{file_name}" if($args{file_name});
    unless ($self->execCmd($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to save media configuration.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Media configuration successfully saved");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 loadMediaConfiguration

=over

=item DESCRIPTION:

  This function loads the media devices configuration from specfied file.

=item ARGUMENTS:

  Optional argument- path(path of the file where we load the media devices configurations)

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  1 - Success
  0 - Failure

=back

=cut


sub loadMediaConfiguration{
    my ($self,%args)=@_;
    my $sub_name="loadMediaConfiguration";
    my $logger=Log::Log4perl->get_logger(__PACKAGE__ .".$sub_name");
    $logger->info(__PACKAGE__ .".$sub_name: --> Entered Sub");
    my $cmd="nxconfig.pl -m";
    $cmd .=" -P $args{file_path}" if($args{file_path});
    $self->{conn}->print($cmd);
    if($self->{conn}->waitfor('/Please enter the hostname.+:/')){
        $logger->debug(__PACKAGE__ .".$sub_name:  Please enter the hostname for mdevices.xml ");
        $self->{conn}->print("\n");
        if($self->{conn}->waitfor('/Do you want to restart the iServer? (y/n) .+/')){
            $self->{conn}->print("y");
        }
    }
    unless ($self->allStop()){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to Stop iserver.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->allStart()){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to Start iserver.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    unless($self->checkProcessStatus()){
        $logger->error(__PACKAGE__ . ".$sub_name: All Processes are not Up");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ .".$sub_name: Media Configuration successfully loaded");
    $logger->debug(__PACKAGE__ .".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 getVersion

=over

=item DESCRIPTION:

  This function returns the application version.

=item ARGUMENTS:

  application: gis or gb application version.

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  Success: gis or gb application version
  Failure: 0

=back

=cut

sub getVersion{
    my ($self,$application)=@_;
    my $sub_name="getVersion";
    my $logger=Log::Log4perl->get_logger(__PACKAGE__ .".$sub_name");
    $logger->info(__PACKAGE__ .".$sub_name: --> Entered Sub");
    my $cmd;
    if ($application eq "gis"){
        $cmd="gis -v |grep GENBAND";
    }
    elsif($application eq "gb"){
	$cmd="gbversion |grep GENBAND";
    }
    else{
	$logger->error(__PACKAGE__ .".$sub_name: No application passed ,pass only 'gb' or 'gis'");
        $logger->debug(__PACKAGE__ .".$sub_name: Leaving Sub [0]");
        return 0;
    }
    my ($out) = $self->execCmd($cmd);
    
    if($out=~ /(\d+[.]\S+\b)/){
    	$logger->info(__PACKAGE__ .".$sub_name: Version: $1");
    	$logger->debug(__PACKAGE__ .".$sub_name: Leaving Sub [$1]");
    	return $1;
    }
    else{
        $logger->info(__PACKAGE__ .".$sub_name: Could not fetch version");
	$logger->debug(__PACKAGE__ .".$sub_name: Leaving Sub [0]");
	return 0;
    }
}

=head2 compareVersion

=over

=item DESCRIPTION:

  This function compares the user defined version with current application version.

=item ARGUMENTS:

  %args=(application=> $application,
       user_version=> $version);
  application: "gb" - for gb application version
               "gis"- for gis application version
  user_version: user defined version to compare with current version.



=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  0 - user version is equal to current version.
  1 - user version is greater than current version.
  -1- user version is smaller than current version.
  current version - if user version is not defined.
  error message- if the format of the user version is wrong or the version could not be fetch

=back

=cut


sub compareVersion {
    my($self,%args) = @_;
    my $sub_name= "compareVersion";
    my ($i, $current_version);
    my $logger= Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $return_value=0;

    unless( $current_version=$self->getVersion($args{application})){
  	$return_value = 'Could not fetch version';
        $logger->info(__PACKAGE__ .".$sub_name: $return_value");
        return $return_value;
    }
    $logger->info(__PACKAGE__ .".$sub_name: version: $current_version");
    
    unless(($args{user_version} =~ /(\d\.\d\.\d+)(\.\d)?(\-\d+)?(\w\d+)?(\_\w+\-\d+)?/)){ 
        $return_value = 'Argument pattern wrong';
        $logger->info(__PACKAGE__ .".$sub_name: $return_value");
        return $return_value;
    } 

    my @first = split /[._-]/, $args{user_version};
    my @second= split /[._-]/, $current_version;
    $logger->debug(__PACKAGE__ . ".$sub_name: User Version:: $args{user_version}");
    $logger->debug(__PACKAGE__ . ".$sub_name: Current Version:: $current_version");
    
    for($i=0;$i<4;$i++){
        if($first[$i] > $second[$i]){
            $return_value=1;
            last; 
        }
        elsif($first[$i] < $second[$i]){
            $return_value=-1;
            last;
        }
    }

    if ($return_value==0 && ((@first||@second)>3)){
	if ($first[4] eq 'SCTP' && $second[4] eq 'SCTP'){#if both versions have SCTP output is 0
        }
        elsif($second[4] eq 'SCTP') { #if current version is SCTP then current version is greater than user version
            $return_value=-1;
        }
	elsif($first[4] eq 'SCTP'){#if user version is SCTP then user version is greater than current version
  	    $return_value=1;
	}
	elsif($first[4] eq 'ACP' && $second[4] eq 'ACP'){#if both versions have ACP the following digit is checked
	    if($first[5]>$second[5]){
	        $return_value=1;
	    }
	    elsif($first[5]<$second[5]){
	        $return_value=-1;
	    }
	}	
	elsif($second[4] eq 'ACP') { #if current version is ACP then current version is greater than user version
            $return_value=-1;
        }
	elsif($first[4] eq 'ACP'){ #if user version is ACP then user version is greater than current version
	    $return_value=1;
	}
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Versions successfully compared");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [$return_value]");
    return $return_value;
}
=pod

=head2 SonusQA::QSBC::compare()

    DESCRIPTION:

    This subroutine compares files between two directories or two files.

=over

=item ARGUMENTS:

    Mandatory : Filenames between two directories should be same

=item PACKAGE:

    SonusQA::QSBC

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1=> on success
    0=> on failure

=item EXAMPLE(s)

    unless ($obj->compareFile("/usr/local/nextone/bin/check1 ","/usr/local/nextone/bin/check2")){
        print "failed";
    }



=back

=cut

sub compareFile{
    my ($self ,$file_path1 ,$file_path2) =@_;
    my $sub = "compareFile";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__.".$sub: --> Entered Sub");

    my $flag =1;
    $logger->info(__PACKAGE__.".$sub: --> Executing Command");
    my @diff =$self->{conn}->cmd("diff -br $file_path1 $file_path2");
    if(grep /.*No such file or directory/ ,@diff){
        $logger->error(__PACKAGE__ . ".$sub:  Files are not present on the server");
       return 0;
    }

    foreach my $param(@diff){
        if($param =~/^diff\s-br\s(.+)\s(.+)/){
            $file_path1 = $1;
            $file_path2 = $2;

        }
        if($param =~ /^[<>](\s+)?\n/){
            next;
        }
        elsif($param =~/^[<>]/){
           unless($param =~/.+(hk-|UTC|\bbuild\sdate|\bGIS|Copyright|imedia-|GENBAND|\bIST)/){
                $flag =0;
                last;
            }
        }


     }
     if($flag == 0){
         print "FAILURE in comparison of:\n $file_path1 $file_path2\n";
     }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
    return $flag;

}

=pod

=head2 SonusQA::QSBC::doCleardb()

    DESCRIPTION:

    This subroutine stops all running processes and clean the db .

=over

=item ARGUMENTS:

    Mandatory : Nothing

=item PACKAGE:

    SonusQA::QSBC

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1=> on success
    0=> on failure

=item EXAMPLE(s)

    unless ($obj->doCleardb()){
        print "failed";
    }


=back

=cut

sub doCleardb{
    my ($self)  =@_;
    my $sub = "doCleardb";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__.".$sub: --> Entered Sub");

    unless($self->allStop()){
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    unless($self->{conn}->print("cli db clean all")){
	$logger->error(__PACKAGE__ . ".$sub: Failed to execute command \"cli db clean all\"");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    if($self->{conn}->waitfor( -match => '/Do.+:/' )){
        unless($self->{conn}->cmd("y")){
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
    }
    unless($self->allStart()){
	$logger->error(__PACKAGE__ . ".$sub: Failed to start iserver");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    unless($self->checkProcessStatus()){
	$logger->error(__PACKAGE__ . ".$sub: All processes are not up");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__.".$sub: --> Operation Executed Sucessfully");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=pod

=head2 SonusQA::QSBC::getStatus()

    DESCRIPTION:

    This subroutine get the status of the box active/standby  .

=over

=item ARGUMENTS:

    Mandatory : Nothing

=item PACKAGE:

    SonusQA::QSBC

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1=> on success
    0=> on failure

=item EXAMPLE(s)

    unless ($obj->getStatus()){
        print "failed";
    }


=back

=cut

sub getStatus{
    my ($self)= @_;
    my $sub = "getStatus";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__.".$sub: --> Entered Sub");
    my @result;
    unless(@result =$self->execCmd("cli ha")){
	$logger->error(__PACKAGE__ . ".$sub: Unable to Execute Command \"cli ha\"");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
     my $match;
    foreach my $param( @result){
        if($param =~/^Local\s+(.+)/){
            $match =$1;
            last;
          }
      }
    if ($match eq 'Active'){
	$logger->info(__PACKAGE__ . ".$sub: Machine Staus is active");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
        return 1;

    }
    else{
	$logger->error(__PACKAGE__ . ".$sub: Failed to get Machine Status");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
}

=pod

=head2 SonusQA::QSBC::switchState()

    DESCRIPTION:

    This subroutine switches state of db .

=over

=item ARGUMENTS:

    Mandatory : Nothing

=item PACKAGE:

    SonusQA::QSBC

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1=> on success
    0=> on failure

=item EXAMPLE(s)

    unless ($obj->switchState()){
        print "failed";
    }


=back

=cut

sub switchState{
    my ($self)= @_;
    my $sub = "switchState";
    my $timeout = "120";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__.".$sub: --> Entered Sub");
    my @result;
    unless(@result =$self->execCmd("cli db status")){
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    unless( grep /Status:Master/ ,$result[1]){
        unless($self->execCmd("/usr/local/nextone/bin/setdbrole.sh stop")){
	    $logger->error(__PACKAGE__ . ".$sub: Unable to execute command: \"/usr/local/nextone/bin/setdbrole.sh stop\"");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        unless($self->execCmd("rcpostgresql stop")){
	    $logger->error(__PACKAGE__ . ".$sub: Unable to execute command: \"rcpostgresql stop\"");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        unless($self->execCmd("cli db status")){
	    $logger->error(__PACKAGE__ . ".$sub: Unable to execute command: \"cli db status\"");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        unless($self->execCmd("/usr/local/nextone/bin/setdbrole.sh start", $timeout)){
	    $logger->error(__PACKAGE__ . ".$sub: Unable to execute command: \"/usr/local/nextone/bin/setdbrole.sh start\"");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        unless($self->execCmd("cli db status")){
	    $logger->error(__PACKAGE__ . ".$sub: Unable to execute command: \"cli db status\"");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
}

=pod

=head2 SonusQA::QSBC::export()

    DESCRIPTION:

    This subroutine export to specified file  .

=over

=item ARGUMENTS:

    Mandatory : Nothing

=item PACKAGE:

    SonusQA::QSBC

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    1=> on success
    0=> on failure

=item EXAMPLE(s)

    unless ($obj->export("/root/Qcomapre")){
        print "failed";
    }


=back

=cut

sub export{
    my ($self ,$path)= @_;
    my $sub = "export";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__.".$sub: --> Entered Sub");
    $logger->info(__PACKAGE__."Executing the command\n");
    unless($self->execCmd("cli db export $path")){
	$logger->debug(__PACKAGE__ . ".$sub: Failed to take db backup");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
}

=head2 linuxHandler

=over

=item DESCRIPTION:

  This function upgrade the current build value is lower than the build specified in path or Downgrade if the current build value is greater than the build specified in path.

=item ARGUMENTS:

  Mandatory Arguments: gis_version,
  Optional Argument: path

  %args=(path=>'/var/builds/patch_',
        gis_version=>$gis_version
        );

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  0 - if rollback/upgrade is unsuccessful.
  1 - if rollback/upgrade is successful.

=item EXAMPLE:

  %args=(gis_version=>'9.3.9.0');
  $qsbc_obj->linuxHandler(%args1);

=back

=cut
sub linuxHandler{
    my ($self,%args)=@_;
    my $sub_name="linuxHandler";
    my $logger=Log::Log4perl->get_logger(__PACKAGE__ .".$sub_name");
    $logger->info(__PACKAGE__ .".$sub_name: Entered Sub");
    my ($gb_version,$path,$cmd,$upgrade_cmd,$operation);
    COMPARE:
    if (exists($args{path})){
        $path="$args{path}$args{gis_version}";
    }
    else{
        $path="/var/builds/patch_$args{gis_version}";
    }
    
    ($upgrade_cmd)=$self->execCmd("ls -t $path | grep gblinux-master");
    if($upgrade_cmd=~ /((\d)\.(\d)\.(\d)-(\d)+)/){
        $gb_version= $1;
    }
    else{
        $logger->error(__PACKAGE__ .".$sub_name: GBVERSION not found");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    my $current_version;
    unless( $current_version=$self->getVersion('gis')){
        $logger->debug(__PACKAGE__ .".$sub_name: Leaving sub[0]");
        return 0;
    }
    $logger->info(__PACKAGE__ .".$sub_name: version: $current_version");
    $logger->info(__PACKAGE__ .".$sub_name:$upgrade_cmd");
    my %a=(application=>'gb',
           user_version=>$gb_version);
    my $out=$self->compareVersion(%a);
    my ($prematch, $match) = ('','');
    if ($out==1){
        $operation='upgrade';
        $logger->info(__PACKAGE__ .".$sub_name: Upgrade operation $path/$upgrade_cmd");
        $self->{conn}->print("$path/$upgrade_cmd");
        unless (($prematch, $match) = $self->{conn}->waitfor( -match =>'/Initiating the GENBAND Master Update procedure\. Continue\? \[y\/N]\?.+/',
							      -match =>'/Installing gblinux-update/',
							      -match =>'/The installer is about to start\. Are you sure to continue \(y\/\[n\]\)\?.+/'
							    )){
            $logger->error(__PACKAGE__ .".$sub_name: FAILED to execute command");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        }

        if ( $match =~ m/Initiating the GENBAND Master Update procedure\. Continue\? \[y\/N]\?.+/ ) {
            unless($self->{conn}->print("y")){
                $logger->error(__PACKAGE__ .".$sub_name: Could not update Version");
                $logger->debug(__PACKAGE__ .".$sub_name: Leaving sub[0]");
                return 0;
            }
        }
	elsif( $match =~ m/The installer is about to start\. Are you sure to continue \(y\/\[n\]\)\?/){
   	    unless($self->{conn}->print("y")){
        	$logger->error(__PACKAGE__ .".$sub_name: Could not update Version");
        	$logger->debug(__PACKAGE__ .".$sub_name: Leaving sub[0]");
        	return 0;
    	    }
        }
      if($args{gis_version} =~ /9.4.*/ && $current_version =~ /9.3.*/){
	if($self->{conn}->waitfor( -match =>'/Do you want to overwrite the existing backup directory.+\:/' ,  -timeout => 60)){
	    unless($self->{conn}->print("y")){
               $logger->error(__PACKAGE__ .".$sub_name: Could not overwrite the the existing backup directory.");
               $logger->debug(__PACKAGE__ .".$sub_name: Leaving sub[0]");
               return 0;
            }
	}

WAITFOR:
        if($self->{conn}->waitfor( -match => '/Do you want to overwrite the existing iServer (database )?backup file.+\:/', -timeout => 500)){
           unless($self->{conn}->print("y")){
	       $logger->error(__PACKAGE__ .".$sub_name: Could not match the prompt.");
	       $logger->debug(__PACKAGE__ .".$sub_name: Leaving sub[0]");
	       return 0;
           }
	   goto WAITFOR if($match=~ m/Do you want to overwrite the existing iServer backup file.+\:/);
	}
        if($self->{conn}->waitfor( -match =>'/Enter timezone/', -timeout => 600)){
           unless($self->{conn}->print("Asia/Kolkata")){
               $logger->error(__PACKAGE__ .".$sub_name: Could not match the prompt.");
               $logger->debug(__PACKAGE__ .".$sub_name: Leaving sub[0]");
               return 0;
           }

        }
      }
    }
    
    elsif($out==-1){
        $operation="rollback";
        my (@version,$gb_ver,$pre_ver);
        my $ver;
        if($gb_version=~ /(\d\.\d\.\d).+/){
            $gb_ver= $1;
        }
        $logger->info(__PACKAGE__ .".$sub_name:GB_VER=$gb_ver");
        $cmd= "gblinux-rollback";
        my (@rollback) = $self->execCmd($cmd);
        foreach(@rollback){
            if($_=~ /(pre-\d\.\d)/){
                $pre_ver=$1;
            }
            elsif($_=~ /(\d...\d)/){
                push @version ,$1;
            }
        }
        $logger->debug(__PACKAGE__ .".$sub_name: PRE:$pre_ver");
        $logger->debug(__PACKAGE__ .".$sub_name: Versions: ". Dumper(@version));
        my $max_index=$#version;
        if(@version){
            if($gb_ver lt $version[0]){
                $gb_ver= ($pre_ver)? $pre_ver:$version[0];
            }
            elsif($gb_ver ge $version[$max_index]){
                $gb_ver=$version[$max_index];
            }
            else{
                my $i=1;
                while($gb_ver le $version[$i]){
                    $gb_ver=$version[$i];
                    $i++;
                }
            }
        }
        elsif(!@version and defined $pre_ver){
            $gb_ver=$pre_ver;
        }
        $logger->info(__PACKAGE__ . ".$sub_name:GB_VER=$gb_ver");
        $cmd .=" ".$gb_ver;
        $logger->info(__PACKAGE__ .".$sub_name: Rollback operation $cmd");
        $self->{conn}->print($cmd);
        if($gb_ver != "9.2.0" && $self->{conn}->waitfor('/Are you sure\?.+/')){
            $logger->info(__PACKAGE__ . ".$sub_name:Are you sure");
            $self->{conn}->print("y");
            if($self->{conn}->waitfor('/Are you sure\?.+/')){
                $logger->info(__PACKAGE__ . ".$sub_name:Are you sure");
                unless($self->{conn}->print("y")){
                    $logger->error(__PACKAGE__ . ".$sub_name: FAILED to execute command");
                    $logger->debug(__PACKAGE__ .".$sub_name: Leaving Sub[0]");
                    return 0;
                }
            }
        }
    }
    elsif($out==0){
        $logger->info(__PACKAGE__ . ".$sub_name: Versions are equal");
        $logger->debug(__PACKAGE__ .".$sub_name: Leaving Sub[1]");
        return 1;
    }
    unless(($prematch,$match)=$self->{conn}->waitfor(-match=>$self->{PROMPT},
                                                     -match=>'/You must RESTART/',
                                                     -match=>'/System REBOOT is required/',
						     -match=>'/System will now automatically reboot/',
                                                     -match=>'/Rebooting./',
                                                     -timeout=>2700)){
        $logger->error(__PACKAGE__ .".$sub_name: Could not update/rollback Version");
        $logger->debug(__PACKAGE__ .".$sub_name: Leaving sub[0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ .".$sub_name: Adding sleep of 20s"); 
    sleep(20);
    unless($match=~ /Rebooting./ or $match=~/System will now automatically reboot/){
        $logger->debug(__PACKAGE__ .".$sub_name: Entered Manual Rebooting mode");
        if($match=~ /You must RESTART|System REBOOT is required/){
            unless($self->{conn}->waitfor($self->{DEFAULTPROMPT})){
                $logger->error(__PACKAGE__ .".$sub_name: COULDN't encounter deafult prompt");
                $logger->debug(__PACKAGE__ .".$sub_name: Leaving Sub[0]");
                return 0;
            }
            $self->{conn}->print("reboot");
            $logger->info(__PACKAGE__ .".$sub_name: Successfully executed reboot");
        }
    }
    $logger->debug(__PACKAGE__ .".$sub_name: Sleep for 150 sec to get system rebooted");
    sleep(150);
    unless (SonusQA::Base::reconnect($self, -retry_timeout => 3600,-conn_timeout=> 300)) {
        $logger->error(__PACKAGE__. ".$sub_name: Base reconnect failed");
        $logger->debug(__PACKAGE__. ".$sub_name: <-- Leaving Sub [0]");
        $main::failure_msg .= "UNKNOWN:QSBC-Unable to reconnect; ";
        return 0;
    }
    if($operation eq 'rollback'){
        $logger->info(__PACKAGE__ . ".$sub_name: Successfully executed $operation");
        $logger->info(__PACKAGE__ . ".$sub_name: rollback for $args{gis_version}");
        goto COMPARE;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Successfully executed $operation");
    $logger->debug(__PACKAGE__ .".$sub_name: Leaving Sub[1]");
    return 1;

}

=head2 expectScriptHandler

=over

=item DESCRIPTION:

  This function upgrade/install/uninstall the expect script.

=item ARGUMENTS:

  Mandatory Arguments: -script_name => name of script,
                       -cmd_args    => arguments required to run the script accepted as a string separated by spaces.
                       -pattern     => pattern to be matched in the result to validate successful installation/uninstallation/upgradation.

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  0 - if install/uninstall/upgrade is unsuccessful.
  1 - if install/uninstall/upgrade is successful.

=item EXAMPLE:

  path=> /home/<username>/ats_repos/lib/perl/SonusQA/QSBC/EXPECT_SCRIPTS/<script_name>

  %argsin=(-script_name=>'script_install',

           -pattern=>'Server Admin Package Installation Complete',

           -cmd_args=> '172.23.73.46 /var/builds/patch_9.1.22.0/ 9.1.22.0 m 10.10.73.47 45 ');
 
  $qsbc_obj->expectScriptHandler(%argsin);

=back

=cut

sub expectScriptHandler{
    my ($self,%args)=@_;
    my $sub_name="expectScriptHandler";
    my $logger=Log::Log4perl->get_logger(__PACKAGE__ .".$sub_name");
    $logger->info(__PACKAGE__ ."$sub_name: Entered Sub");
    my ($cmd_result,$cmd);

    foreach (qw(-script_name -pattern -cmd_args )) {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument $_ not provided.");
            $logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
            return 0;
        }
    }

    my ($sec,$min,$hour,$day,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$day,$hour,$min,$sec;
    my $path="/home/$ENV{USER}/ats_repos/lib/perl/SonusQA/QSBC/EXPECT_SCRIPTS/";
    $logger->info(__PACKAGE__ . ".$sub_name: $path");
    `mkdir -p /home/$ENV{USER}/ats_user/logs/QSBC`;
    $cmd= "$path$args{-script_name} /home/$ENV{USER}/ats_user/logs/QSBC/$args{-script_name}_$timestamp.log  $args{-cmd_args}";
    $logger->debug(__PACKAGE__ . ".$sub_name: ISSUING COMMAND: $cmd");
    $cmd_result=`$cmd`;
    unless($cmd_result){
        $logger->error(__PACKAGE__ .".$sub_name: Could not execute command");
        $logger->debug(__PACKAGE__ .".$sub_name: Leaving Sub[0]");
        return 0;
    }
    unless($cmd_result=~ /$args{-pattern}/){
        $logger->debug(__PACKAGE__ . ".$sub_name: COMMAND RESULT: $cmd_result");
	$logger->error(__PACKAGE__ .".$sub_name: Could not perform operation successfully");
        $logger->debug(__PACKAGE__ .".$sub_name: Leaving Sub[0]");
        return 0;
    }
    $logger->info(__PACKAGE__ .".$sub_name: Operation successfully executed");
    $logger->debug(__PACKAGE__ .".$sub_name: Leaving Sub[1]");
    return 1;
}


=head2 coreValidation

=over

=item DESCRIPTION:
	
  This function is used to check whether core is available in /var/core or not. 

=item ARGUMENTS:
  Mandatory : Nothing

  Optional:
  '-tcid'   - TestCaseId 
  '-copyLocation' - Location of the path where core should be copied
  '-localPath'    - Path where core files are present
  '-tacpath'      - Path where tacs are present.
	
=item PACKAGE:
	
  SonusQA::QSBC
	
=item OUTPUT:
  0   - fail
  1   - success

=item EXAMPLE:
  
  $obj->coreValidation();
  
=back
	
=cut

sub coreValidation{
    my($self,%args) = @_;
    my $sub= "coreValidation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub --> Entered Sub");
    my $file;
    my $i =1;
    my ($match, $prematch, $match1, $prematch1, $res, $core, $handle);
    
    $args{-tcid} ||= "NONE";
    $args{-copyLocation} ||= "/home/$ENV{USER}/ats_user/logs";
    $args{-localpath} ||= "/var/core";
    $args{-tacpath} ||= "/var/tmp/tac";

    my (@result)=$self->execCmd("ls /var/core/  | grep -i  core ");
    foreach(@result){
        if(/core/){
            $self->storeLogs($_,$args{-tcid},$args{-copyLocation}, $args{-localpath}) ;
            if(/gis/){
                $logger->info(__PACKAGE__ . ".$sub: Core is generated and it is gis core");
                $logger->info(__PACKAGE__ . ".$sub: Collecting Backtrace of all core generated");

                $self->collectBacktrace(-core =>$_, -location =>$args{-copyLocation}, -filename =>"file$i.txt");
                $i++;   # Increasing value of $i for next core
                $logger->debug(__PACKAGE__ . ".$sub:Backtrace logs has been copied");
            }
            $core = 1;
        }
    }  
    if($core){
        $self->tacFile();
        my @res = $self->execCmd("ls $args{-tacpath} | tail -1 ");
        $self->storeLogs(@res,$args{-tcid},$args{-copyLocation}, $args{-tacpath});
        
        $logger->debug(__PACKAGE__ . ".$sub --> Sleep for 5 minutes ");
        sleep(300);
        $self->allStop();

        $self->allStart();

        $self->checkProcessStatus();
        
	      $logger->debug(__PACKAGE__ . ".$sub --> CORE FOUND ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }else{
        $logger->debug(__PACKAGE__ . ".$sub --> NO CORE FOUND ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
        return 1;
     }
     
}

=head2 collectCDR

=over

=item DESCRIPTION:

  This function check for .CDT file in /var/cdrs , pick the latest file , decode it and copy to the specified path (default path is /home/genband). 

=item ARGUMENTS:

  Mandatory :
  '-tcid'   - TestCaseId 
  '-copyLocation' - Location of the path where CDT should be copied
  '-localPath'    - Path where CDT files are present
	
=item PACKAGE:
	
  SonusQA::QSBC
	
=item OUTPUT:

  0   - fail
  1   - success

=item EXAMPLE:
  
  $obj->collectCDR();
  $obj->collectCDR(%args);
  
=back
	
=cut

sub collectCDR{
    my ($self ,%args) = @_;
    my $sub = "collectCDR";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: -->Entered Sub");
    
    $args{-tcid} ||= "NONE";
    $args{-copyLocation} ||= "/home/$ENV{USER}/ats_user/logs";
    $args{-localpath} ||= "/var/cdrs";

    $logger->info(__PACKAGE__.".$sub: checking for CDT");
    my ($file)=$self->execCmd("ls /var/cdrs  -t | grep D.*.CDT ");
    unless($file){
        $logger->error(__PACKAGE__.".$sub: CDT file not generated.");
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my $cmd=("cdr_decode.pl /var/cdrs/$file > /var/cdrs/CDT.txt");
    unless($self->execCmd($cmd)){
        $logger->error(__PACKAGE__.".$sub: Could not execute cmd ' $cmd'");
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    unless ($self->storeLogs('CDT.txt',$args{-tcid}, $args{-copyLocation}, $args{-localpath}) ) {
        $logger->error(__PACKAGE__ . " $sub :   Failed to store the log file: CDT.txt .");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub ['CDT.txt']");
    return '/var/cdrs/CDT.txt';
}




=head2 memoryValidation

=over

=item DESCRIPTION:

  This function verify that there is sufficient free disk space inthe /var directory using df -h command

=item ARGUMENTS:

  Mandatory : Nothing

=item PACKAGE:
	
  SonusQA::QSBC
	
=item OUTPUT:

  0   - used %age of /var folder is greater than 90%
  1   - used %age of /var folder is less than 90%

=item EXAMPLE:
  
  $obj->memoryValidation();
  
=back
	
=cut

sub memoryValidation{
    my($self,%args) = @_;
    my $sub= "memoryValidation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub --> Entered Sub");
    unless($self->execCmd('cd /root')){
	$logger->error(__PACKAGE__ . ".$sub: Could not cd to /root");
	$logger->debug(__PACKAGE__ .".$sub: Leaving Sub[0]");
	return 0;
    }

    unless($self->execCmd("df -h | grep /var >> var_all.txt")){
	$logger->error(__PACKAGE__ . ".$sub: Could not execute command 'df -h | grep /var >> var_all.txt'");
        $logger->debug(__PACKAGE__ .".$sub: <--Leaving Sub[0]");
        return 0;
    }

    unless($self->execCmd("cat var_all.txt  | grep  -v  /var/ >>  var.txt")){
	$logger->error(__PACKAGE__ . ".$sub: Could not execute command 'cat var_all.txt  | grep  -v  /var/ >>  var.txt'");
        $logger->debug(__PACKAGE__ .".$sub: <-- Leaving Sub[0]");
        return 0;
    }

    my ($memory) =  $self->execCmd("cat var.txt | grep -Eo \'[0-9]{1,4}%\'");
    $memory  =~ s/\D//g;
    $logger->debug(__PACKAGE__ . ".$sub: value is $memory ");

    unless($self->execCmd("rm -rf var.txt  var_all.txt")){
	$logger->error(__PACKAGE__ . ".$sub: Could not execute command 'rm -rf var.txt  var_all.txt'");
        $logger->debug(__PACKAGE__ .".$sub: <-- Leaving Sub[0]");
        return 0;
    }

    if($memory <= 90){
        $logger->debug(__PACKAGE__ . ".$sub: Used level of the /var directory is 90% or less ");
    }
    else{
        $logger->error(__PACKAGE__ .".$sub: Used level of the /var directory is greater than 90% ");
        $logger->debug(__PACKAGE__ .".$sub: Leaving Sub[0]");
        return 0;
    }
    $logger->info(__PACKAGE__ .".$sub: Operation successfully executed");
    $logger->debug(__PACKAGE__ .".$sub: Leaving Sub[1]");
    return 1;
}

=head2 dbValidation

=over

=item DESCRIPTION:

  This function verify the expected db status of the server.

=item ARGUMENTS:

  %args=('phase'=> $phase,
        'state'=> $state,
	    'version' => $version);

  phase:
   pre-upgrade               - for pre-upgrade db-state
   post-upgrade              - for post-upgrade db state (or) Pre & Interim Roll-back db state
   interim-post-os-upgrade   - for post os upgrade db state
   interim-upgrade           - for post os and gis upgrade db state
   primary-MU
   
  state:
   Primary     -  For Primary state
   Secondary    -  For Secondary state
   
  version : application version
  to_version 
  
=item PACKAGE:
	
  SonusQA::QSBC
	
=item OUTPUT:
  0   - fail
  1   - success

=item EXAMPLE:
  
  %args=('phase'=> 'pre-upgrade',
         'state'=> 'Primary',
         'version' => '9.3.12.0');
  $obj->dbValidation(%args);
  
=back
	
=cut

sub dbValidation{
    my ($self,%args)=@_;
    my $sub="dbValidation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub --> Entered Sub");
    foreach(qw/ phase state /){
    	unless($args{$_}){
	    $logger->error(__PACKAGE__ . ".$sub: Mandatory parameter $_ empty");
	    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
   	    return 0;
	}
    }
    unless($args{phase} eq "pre-upgrade" ||$args{phase} eq "interim-upgrade"||$args{phase} eq "post-upgrade"||$args{phase} eq "primary-MU"||$args{phase} eq "secondary-MU"){
	$logger->error(__PACKAGE__ . ".$sub: Mandatory parameter \$args{phase} invalid");
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
	return 0;
    }
    unless($args{state} eq "Primary" or $args{state} eq "Secondary"){
	$logger->error(__PACKAGE__ . ".$sub: Mandatory parameter \$args{state} invalid");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $cmd="cli db status";
    my @result=$self->execCmd($cmd);
    my %a=( 0=>$result[0],
	   1=>$result[1]);
    %args=(%args,%a);
    if ($args{phase} eq "pre-upgrade"){
 	if ($args{state} eq "Primary"){
   	    unless($args{0} =~/Status:Master/ and $args{1} =~/Status:Slave/ ){
		$logger->error(__PACKAGE__ . ".$sub: Unexpected db status.");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
	    }
	}
	else{
	    unless($args{0} =~/Status:Slave/ and $args{1}=~/Status:Master/){
		$logger->error(__PACKAGE__ . ".$sub: Unexpected db status.");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
	    }
	}
    }
    elsif ($args{phase} eq "interim-upgrade"){
	if($args{state} eq "Primary"){
	    unless($args{0} =~/Status:Not Available/ and $args{1} =~ /Status:Master/){
 	    	$logger->error(__PACKAGE__ . ".$sub: Unexpected db status.");
            	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            	return 0;
	    }
	}
	else{
	    unless($args{0} =~/Status:Master/ and $args{1} =~/Status:Not Available/){
	    	$logger->error(__PACKAGE__ . ".$sub: Unexpected db status.");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
	    }
        }
    }
    elsif($args{phase} eq "post-upgrade"){
        if($args{state} eq "Primary"){
  	    unless($args{0} =~ /Status:Slave/ and $args{1} =~ /Status:Master/ ){
		$logger->error(__PACKAGE__ . ".$sub: Unexpected db status.");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
	    }
	}
	else{
	    unless($args{0} =~ /Status:Master/ and $args{1} =~/Status:Slave/){
		$logger->error(__PACKAGE__ . ".$sub: Unexpected db status.");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                return 0;
	    }
	}
    }
    elsif($args{phase} eq "primary-MU"){
        if(($args{ version } ge "9.3") and ($args{ to_version } le  "9.4")){
             if($args{state} eq "Primary"){
                if((grep /error/ ,@result)){
                    $logger->error(__PACKAGE__ . ".$sub: Unexpected db status.");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
             }else{
                 unless($args{0}=~/Status:Master/ and $args{1}=~/Status:Not Available/){
                    $logger->error(__PACKAGE__ . ".$sub  Unexpected db staus ");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
        elsif ($args{version} lt "9.2"){
            if($args{state} eq "Secondary"){
                unless($args{0}=~/Status:Master/ and $args{1}=~/Status:Not Available/){
                    $logger->error(__PACKAGE__ . ".$sub  Unexpected db staus ");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }else{
                unless((grep /error/ ,@result)){
                    $logger->error(__PACKAGE__ . ".$sub: Unexpected db status.");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
        elsif($args{version} gt "9.2" and $args{version} lt "9.3.19.0"){
            if($args{state} eq "Secondary"){
                unless($args{0}=~/Status:Master/ and $args{1}=~/Status:Not Available/){
                    $logger->error(__PACKAGE__ . ".$sub  Unexpected db staus ");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }else{
                unless($args{0}=~/Status:Not Available/ and $args{1}=~/Status:Master/){
                    $logger->error(__PACKAGE__ . ".$sub  Unexpected db staus ");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
        else{
            if($args{state} eq "Secondary"){
                unless($args{0}=~/Status:Master/ and $args{1}=~/Status:Slave/){
                    $logger->error(__PACKAGE__ . ".$sub  Unexpected db staus ");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }else{
                unless($args{0}=~/Status:Slave/ and $args{1}=~/Status:Master/){
                    $logger->error(__PACKAGE__ . ".$sub  Unexpected db staus ");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
    }
    else{
        if(($args{ version } ge "9.3") and ($args{ to_version } le  "9.4")){
            if($args{state} eq "Secondary"){
                unless((grep /error/ ,@result)){
                    $logger->error(__PACKAGE__ . ".$sub: Unexpected db status.");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }else{
                 unless($args{0}=~/Status:Master/ and $args{1}=~/Status:Not Available/){
                    $logger->error(__PACKAGE__ . ".$sub  Unexpected db staus ");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }

        }
        elsif ($args{version} ge "9.2"){
            if($args{state} eq "Primary"){
                unless($args{0}=~/Status:Not Available/ and $args{1}=~/Status:Master/){
                    $logger->error(__PACKAGE__ . ".$sub  Unexpected db staus ");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }
            else{
                unless($args{0}=~/Status:Master/ and $args{1}=~/Status:Not Available/){
                    $logger->error(__PACKAGE__ . ".$sub  Unexpected db staus ");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }

            }
        }
        else{
            if($args{state} eq "Primary"){
                unless(($args{0} =~ /Status:Master/) &&  ($args{1} =~/Status:Not Available/)){
                    $logger->info(__PACKAGE__ . ".$sub  Unexpected db staus ");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }else{
                unless(grep /error/ ,@result){
                    $logger->info(__PACKAGE__ . ".$sub  Unexpected db staus ");
                    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
                    return 0;
                }
            }
        }
    }
    $logger->info(__PACKAGE__ . ".$sub  Expected db staus ");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}


=head2 verifyRDR

=over

=item DESCRIPTION:

  This function count the number of RDRs or rdrs flowing and return the count.

=item ARGUMENTS:

  Mandatory: 
  'dbstate'=> $dbstate

  dbstate:
   Active     -  For Active  state
   StandBy    -  For StandBy state
   
  Optional:
  
  rdr_no: number of rdr flowing 
  
=item PACKAGE:
	
  SonusQA::QSBC
	
=item OUTPUT:

  0   - fail
  count of RDRs    - success

=item EXAMPLE:
  
  %args=('dbstate'=> $phase);
  $obj->verifyRDR(%args);
  
=back
	
=cut


sub verifyRDR{
    my($self,%args) = @_;
    my $sub = "verifyRDR";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub --> Entered Sub");
    my $cmd;
    my (@R1,@R2);
    unless($args{dbstate} and ($args{dbstate} eq "Active" or $args{dbstate} eq "StandBy")){
        $logger->error(__PACKAGE__.".$sub: Mandatory argument dbstate is missing or invalid");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    if(exists $args{rdr_no} and $args{dbstate} ne "Active"){
        $logger->error(__PACKAGE__.".$sub: passed dbstate ($args{dbstate}) shoud be Active when rdr_no ($args{rdr_no}) is passed");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    $self->execCmd("cd");
    unless($self->execCmd("statclient hkipnat > RDR.txt")){
        $logger->error(__PACKAGE__ . ".$sub: Command Execution ERROR");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    my $final;
    if(exists $args{rdr_no}){
        $final = $args{rdr_no};
    }
    else{
        unless( @R1 = $self->execCmd("wc -l RDR.txt")){
            $logger->error(__PACKAGE__ . ".$sub: Command Execution ERROR");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        ($final) = split(/ /, $R1[0]);
    }
    $logger->debug(__PACKAGE__ .".$sub: Number of RDRs flowing: $final");
    

    if($args{dbstate} eq "Active"){
        $cmd="grep -c  RDR RDR.txt";
    }
    elsif($args{dbstate} eq "StandBy"){
        $cmd="grep -c  rdr RDR.txt";
    }
    unless( @R2 = $self->execCmd($cmd)){
        $logger->debug(__PACKAGE__ . ".$sub: Command ERROR");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ .".$sub: Number of RDRs flowing: ".Dumper(\@R2));
    unless($final == $R2[0]){
        $logger->error(__PACKAGE__ .".$sub: ERROR : no of RDRs flowing in 'wc -l RDR.txt' not equal to $cmd ");
        $logger->debug(__PACKAGE__ .".$sub:  Leaving Sub[0]");
        return 0;
    }
    unless($self->execCmd("rm -rf /root/RDR.txt")){
    	$logger->debug(__PACKAGE__ . ". Command Execution  ERROR");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$final]");
    return $final;
}

=head2 liceFilevalidation

=over

=item DESCRIPTION:

  This function take backup of license and copy to the specified path (default path is "/home/genband/") based on phase.

=item ARGUMENTS:

  Mandatory : 
  %args=('phase'=> $phase);

  phase:
   pre-upgrade               - for pre-upgrade db-state
   post-upgrade              - for post-upgrade db state
   interim-upgrade           - for post os and gis upgrade db state
   
  Optional argument:
  'path'                - Pass path where decoded CDT and CDR files should be copied.
  
=item PACKAGE:
	
  SonusQA::QSBC
	
=item OUTPUT:

  0   - fail
  1   - success

=item EXAMPLE:
  
  %args=('phase'=> 'pre-upgrade');
  $obj->liceFilevalidation(%args);
  
  %args=('phase'=> 'pre-upgrade',
         'path'  => '/home/genband/validation');
  $obj->liceFilevalidation(%args);
  
=back
	
=cut

sub liceFileValidation{
    my($self,%args) = @_;
    my $sub= "liceFileValidation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub --> Entered Sub");
    $args{path} ||= "/home/genband/";
    my $filename;
    my $flag=1;
    unless($args{phase}){
        $logger->error(__PACKAGE__ . ".$sub: Mandatory Argument Missing.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    unless($args{phase} =~ /pre_upgrade|post_upgrade|interim-upgrade|interim-rollback/ ){
        $logger->error(__PACKAGE__ . ".$sub: Invalid State");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $filename = "$args{phase}_license.xml";

    my @cmd=("cd \/root","nxconfig.pl -L","cp .\/iserverlc.xml $filename","mv $filename $args{path}","ls $args{path} \| grep  $filename");
    foreach(@cmd){
        unless($self->execCmd($_)){
    	    $logger->error(__PACKAGE__ . ". Could not execute command: $_");
	    $flag=0;
            last;
        }
    }
    unless ($flag){
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
	return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub: Operation Successfully executed");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return 1;
}

=head2 onboardxcodeValidation

=over

=item DESCRIPTION:

  This function is used for below purpose:
  If no argument passed: Return onboardxcode version
  If 'compare_version' argument  passed: Compare current onboardxcode version with  and passed version, Useful for HA pair to check whether both servers having same onboardxcode version or not.

=item ARGUMENTS:
 
  Optional:
	compare_version=>$version

=item PACKAGE:

     SonusQA::QSBC

=item OUTPUT:

  If no argument passed:
  0   - fail
  onboardxcode-1.1-2_gb34_040100B1681.x86_64  - pass  (return date in same format)

  If 'compare_version' argument  passed:
  0   - fail
  1   - success

=item EXAMPLE:

  my $onboversion = $objA->onboardxcodeValidation();
  $objB->onboardxcodeValidation('comapre_version'  => $onboversion);

=back

=cut

sub onboardxcodeValidation{
    my($self,%args) = @_;
    my $sub= "onboardxcodeValidation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub --> Entered Sub");
    my ($version) = $self->execCmd("rpm -qa | grep  onboardxcode");
    unless($version) {
        $logger->error(__PACKAGE__ . ".$sub: Unable to get onboardxcode version");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    if($args{compare_version}){
        unless($version eq $args{compare_version}){
            $logger->error(__PACKAGE__ . ".$sub: onboardxcode version does not match");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub Both onboardxcode versions are same");
        $logger->info(__PACKAGE__ . ".$sub Operation Executed Successfully ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
        return 1;
    }
    else{
        $logger->info(__PACKAGE__ . ".$sub Returning onboardxcode version : $version ");
        $logger->info(__PACKAGE__ . ".$sub Operation Executed Successfully ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
        return $version;
    }
}

=head2 slonyValidation

=over

=item DESCRIPTION:

  This function is used for below purpose:
  If no argument passed: Return slony version
  If 'compare_version' argument  passed: Compare current slony version with  and passed version, Useful for HA pair to check whether both servers having same slony version or not.

=item ARGUMENTS:

  Optional argument:
  'compare_version'                - pass output of date command only.

=item PACKAGE:

     SonusQA::QSBC

=item OUTPUT:

  If no argument passed:
  0   - fail
  slony1-2.2.4-1_PG9.2.7.os13.gb01.x86_64    - pass  (return date in same format)

  If 'compare_version' argument  passed:
  0   - fail
  1   - success

=item EXAMPLE:

  my $slonversion = $objA->slonyValidation();
  $objB->slonyValidation('comapre_version'  => $slonversion);

=back

=cut

sub slonyValidation{
    my($self,%args) = @_;
    my $sub= "slonyValidation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub --> Entered Sub");
    my ($version) = $self->execCmd("rpm -qa | grep  slony");
    unless($version) {
        $logger->error(__PACKAGE__ . ".$sub: Unable to get slony version");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    if($args{compare_version}){
        unless($version eq $args{compare_version}){
            $logger->error(__PACKAGE__ . ".$sub: slony version does not match");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub Both slony versions are same");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
        return 1;
    }
    else{
        $logger->info(__PACKAGE__ . ".$sub Operation Executed Successfully ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$version]");
        return $version;
    }
}


=head2 checkSlony

=over

=item DESCRIPTION:

  This function is used for below purpose:
  Check for slon -v and as per the passed version, check whether it is expected slony version or not.

=item ARGUMENTS:

  Optional argument:
  'compare_version'                - pass output of date command only.

=item PACKAGE:

     SonusQA::QSBC

=item OUTPUT:

  Mandatory Argument:
  'version' => Current installed version.

  1   - Pass
  0   - fail

=item EXAMPLE:
l
  $obj->checkSlony('version'  => $version);

=back

=cut

sub checkSlony{
    my($self,%args) = @_;
    my $sub= "checkSlony";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    unless ( $args{version} ) {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory Argument Missing.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my ($slon)=$self->execCmd("slon -v | grep  -o  \"[0-9]\.[0-9]\.[0-9]\"");
    unless($slon) {
        $logger->error(__PACKAGE__ . ".$sub: Unable to get Slon version");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub Slon version is : $slon");
    my @slon = split ( /\./, $slon);
    my @var = split ( /\./, $args{ version } );
    if (($var[0] == 9 ) && ($var[1] >= 2 )){
        unless($slon[2] eq 4) {
            $logger->error(__PACKAGE__ . ".$sub: Unexpected slon version: $slon[2].");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }
    $logger->info(__PACKAGE__ . ".$sub Expected Slon version ");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 machineInfoValues

=over

=item DESCRIPTION:

  This function execute command machine_inf0 -all and store Timezone, class, media_card, os, os_version, default_route, memory, eth0_netmask in hash variable and return hash reference.


=item ARGUMENTS:

  None

=item PACKAGE:

     SonusQA::QSBC

=item OUTPUT:

  0   - fail
  Hash reference for Hash value   - success

=item EXAMPLE:

  $obj->machineInfoValues();

=back

=cut

sub machineInfoValues{
    my $self = shift;
    my $sub= "machineinfoValues";
    my %hash;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub --> Entered Sub");
    my @result;
    unless(@result = $self->execCmd("machine_info -all")){
        $logger->error(__PACKAGE__.".$sub Unable to get required information");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    unless(@result = grep((/Timezone/) || (/class/) || (/media_card/) || (/os/)  || (/os_version/) || (/default_route/) || (/memory/) || (/eth0_netmask/) ,  @result)){
        $logger->error(__PACKAGE__.".$sub Unable to grep required string");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    unless(@result = grep((!/hostname/) && (!/bios_version/),  @result)){
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    unless( %hash = map {split  /=/} @result){
	$logger->error(__PACKAGE__.".$sub: Unable to save \@result in \%hash"); 
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;

    }
    $logger->info(__PACKAGE__ . ".$sub Operation Executed Successfully ");
    $logger->info(__PACKAGE__ . ".$sub Returning Hash reference for all required values ");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    my $ref = \%hash;
    return $ref ;
}


=head2 phaseValidation

=over

=item DESCRIPTION:

  This function take backup of crontab, cli db info -l, cli stats sip-reg-ep-counts, interfaces, Global Configuration, Current Configuration and copy to path "/home/genband/validation".
  If pahse is not pre-upgrade then compare backup files with pre-upgrade backup files.
  It also collects tac script pre-upgrade and post-upgrade and call memoryValidation function
  If "/home/genband/validation" directory is not there then this function will create the directory.
  
=item ARGUMENTS:

  Mandatory : 
   phase:
   pre-upgrade               - for pre-upgrade db-state
   post-upgrade              - for post-upgrade db state
   interim-post-os-upgrade   - for post os upgrade db state
   interim-upgrade           - for post os and gis upgrade db state
  
   if phase = post-upgrade, interim-post-os-upgrade, interim-upgrade 
   crontab_file         => $pre_upgrade_crontab_file,
   db_info_file         => $pre_upgrade_db_info_file,
   sip_count_file       => $pre_upgrade_sip_count_file,
   ifconfig_file        => $pre_upgrade_ifconfig_file,
   global_config_file   => $pre_upgrade_global_config_file,
   current_config_file  => $pre_upgrade_current_config_file   

=item PACKAGE:
	
  SonusQA::QSBC
	
=item OUTPUT:

  0   - fail
  1   - success

=item EXAMPLE:
  
  %args=(phase=> $phase
         crontab_file         => $pre_upgrade_crontab_file,
         db_info_file         => $pre_upgrade_db_info_file,
         sip_count_file       => $pre_upgrade_sip_count_file,
         ifconfig_file        => $pre_upgrade_ifconfig_file,
         global_config_file   => $pre_upgrade_global_config_file,
         current_config_file  => $pre_upgrade_current_config_file
        );

  $obj->validation(%args);
  
  
=back

=cut

sub phaseValidation{
    my ($self,%args)=@_;
    my $sub = "phaseValidation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub --> Entered Sub");
    my $flag=1;
    unless($args{phase} =~ /post_upgrade|pre_upgrade|interim_post_os_upgrade|interim_post_os_rollback|interim_upgrade/ ){
        $logger->error(__PACKAGE__ . ".$sub: unexpected argument passed");
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub[0]");
	return 0;
    }
    my ($sec,$min,$hour,$day,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    unless($self->execCmd("mkdir -p /home/genband/validation")){
	$logger->error(__PACKAGE__ . ".$sub: Could not create directory");
	$logger->debug(__PACKAGE__ . ".$sub: Leaving Sub[0]");
	return 0;
    }
    my $timestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$day,$hour,$min,$sec;
    my %param=(post_upgrade=>{  crontab=>'crontab -l',
				db_info=>'cli db info -l',
				sip_count=>'cli stats sip-reg-ep-counts',
				ifconfig =>'ifconfig',
				global_config=>'nxconfig.pl -S',
				current_config=>'nxconfig.pl -C',
				},
		pre_upgrade=>{ crontab=>'crontab -l',
				db_info=>'cli db info -l',
				sip_count=>'cli stats sip-reg-ep-counts',
				ifconfig =>'ifconfig',
				global_config=>'nxconfig.pl -S',
				current_config=>'nxconfig.pl -C',
				},
		interim_post_os_upgrade=>{crontab=>'crontab -l',
			        },
    interim_post_os_rollback=>{crontab=>'crontab -l',
			        },
		interim_upgrade=>{crontab=>'crontab -l',
				db_info=>'cli db info -l',
				sip_count=>'cli stats sip-reg-ep-counts',
				ifconfig =>'ifconfig',
				global_config=>'nxconfig.pl -S',
				});
    foreach my $key1(keys %{$param{$args{phase}}}){
	my $file=$key1."_".$args{phase}."_".$timestamp.".txt";
	my $cmd= "$param{$args{phase}}{$key1}";
	$cmd .=" >> /home/genband/validation/$file" if($key1 ne "current_config");
	$logger->info(__PACKAGE__ . ".$sub: Validating $key1");
	#cd to /home/genband/validation to do nxconfig.pl -C
	$self->execCmd("cd /home/genband/validation") if ($key1 eq "current_config");
        unless ( $self->execCmd($cmd)){
            $logger->error(__PACKAGE__ . ".$sub: Could not execute command $cmd");
	    $flag=0;
	    last;
        }
	if($key1 eq "current_config"){
	    unless ( $self->execCmd("mv currentConfiguration.sql $key1\_$args{phase}\_$timestamp.sql")){
                $logger->error(__PACKAGE__ . ".$sub: Could not move currentConfiguration.sql to $args{phase}_$key1\_$timestamp.sql");
            	$flag=0;
            	last;
            }
	    $file= "$key1\_$args{phase}\_$timestamp.sql";
	}
	if($args{phase} ne 'pre_upgrade'){
	    my ($pre_file)=$self->execCmd("ls -t /home/genband/validation/ | grep $key1\_pre_upgrade");	
	    $logger->info(__PACKAGE__ . ".$sub: pre_file= $pre_file");
	    unless($self->compareFile("/home/genband/validation/$file ", "/home/genband/validation/$pre_file")){
	        $logger->error(__PACKAGE__ . ".$sub: Could not compare file");
          $flag=0;
          last;
            }
        }
    }
    unless($flag){
	$logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
	return 0;
    }
     #Validating df -h
    $logger->info(__PACKAGE__ . ".$sub: Validating df -h");
    unless($self->memoryValidation()){
        $logger->error(__PACKAGE__ . ".$sub: Could not validate df -h");
	$logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
	return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub: Successfully validated $args{phase}");
    $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 upgradeMatrix
=over

=item DESCRIPTION:

  This function compares the user defined version with 8.2.x.x , 9.1.x.x, 9.2.x.x, 9.3.x.x , 9.4.x.x and returns estimated time(in ms)  for upgrade.

=item ARGUMENTS:
  mandetory arguments
  %args=(from_version=> $from_version,
       to_version=> $to_version);

  from_version: user defined version from where upgrade starts.
  to_version: user defined version to be upgraded from from_version.



=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

   13000000 - to version is equal to 9.4.x.x
   13000000 - from version is equal to 8.3.x.x
   12000000 - from version is equal to 9.1.x.x
   11200000 - from version is equal to 9.2.x.x
   7200000 - from version is equal to 9.3.x.x
   error message- if the format of the user version is wrong or the version does not match

=back

=cut


sub upgradeMatrix {
    my($self,%args) = @_;
    my $sub= "upgradeMatrix";
    my $logger= Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    my $return_value=0;


    unless ( $args{from_version} || $args{to_version})  {
        $logger->error(__PACKAGE__ . ".$sub: Mandatory Source File, Path or Version empty or undefined.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }

    unless(($args{from_version} =~ /((\d)\.(\d)\.(\d)+\.(\d))/)){
        $logger->error(__PACKAGE__ .".$sub: Argument pattern wrong");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return $return_value;
    }

    unless(($args{to_version} =~ /((\d)\.(\d)\.(\d)+\.(\d))/) || ($args{user_version}=~ /((\d)\.(\d)\.(\d)+\.(\d))_((\w)+-[\d]+)/)){
        $logger->error(__PACKAGE__ .".$sub: Argument pattern wrong");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return $return_value;
    }
    my @result_to_version  = split ( /\./,  $args{to_version});
    if (($result_to_version[0] == "9" ) && ($result_to_version[1] == "4")){
        $return_value= "13000000";
	$logger->info(__PACKAGE__ . ".$sub Returning delay: $return_value ");
	$logger->debug(__PACKAGE__ .".$sub: <-- Leaving Sub[$return_value]");
        return $return_value;
    }
    my @result = split ( /\./, $args{ from_version } );
    if (($result[0] == "8" ) && ($result[1] == "3")){
        $return_value= "13000000";
	$logger->info(__PACKAGE__ . ".$sub Returning delay: $return_value ");
        $logger->debug(__PACKAGE__ .".$sub: <-- Leaving Sub[$return_value]");
        return $return_value;
    }
    elsif (($result[0] == 9 ) && ($result[1] == 1)){
        $return_value= "12000000";
	$logger->info(__PACKAGE__ . ".$sub Returning delay: $return_value ");
        $logger->debug(__PACKAGE__ .".$sub: <-- Leaving Sub[$return_value]");
        return $return_value;
    }
    elsif (($result[0] == 9 ) && ($result[1] == 2)){
        $return_value= "11200000";
	$logger->info(__PACKAGE__ . ".$sub Returning delay: $return_value ");
        $logger->debug(__PACKAGE__ .".$sub: <-- Leaving Sub[$return_value]");
        return $return_value;
    }
    elsif (($result[0] == 9 ) && ($result[1] == 3)){
        $return_value= "7200000";
        $logger->info(__PACKAGE__ . ".$sub Returning delay: $return_value ");
        $logger->debug(__PACKAGE__ .".$sub: <-- Leaving Sub[$return_value]");
        return $return_value;
    }
    else{
        $return_value = 0;
        $logger->error(__PACKAGE__ .".$sub: Argument pattern does not match:");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return $return_value;
    }
}


=head2 switchoverValidation

=over

=item DESCRIPTION:

  This function verify cli ha and core. Created for switchover validations.
  
=item ARGUMENTS:

  Mandatory : 
  %args=('dbstate'=> $dbstate,);

   dbstate:
   Active     -  For Active  state
   Standby    -  For StandBy state
   
   
   count  - No of RDRs or rdrs flowing
   
  
=item PACKAGE:
	
  SonusQA::QSBC
	
=item OUTPUT:
 
  0   - fail
  1   - success

=item EXAMPLE:
  
  %args=('dbstate'=> 'Active' );
  $obj->switchoverValidation(%args);
  
  
=back
	
=cut

sub switchoverValidation{
    my($self,%args) = @_;
    my $sub= "switchoverValidation";
    my $result;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub --> Entered Sub");
    unless($args{dbstate}){
        $logger->error(__PACKAGE__ . ".$sub: Mandatory Argument Missing.");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    unless(($args{dbstate} eq "Active") || ($args{dbstate} eq "Standby")){
        $logger->error(__PACKAGE__ . ".$sub: Invalid State");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
     }
    $logger->info(__PACKAGE__ . ".$sub --> Validating core");
    unless($self->coreValidation()){
        $logger->error(__PACKAGE__.".$sub: Core Validation ERROR.");
        $logger->debug(__PACKAGE__ .".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub --> Core validation Completed Successfully");
    $logger->info(__PACKAGE__ . ".$sub --> Validating cli ha");
    my @result;
    unless(@result =$self->execCmd("cli ha")){
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    if(( grep /Active/ , @result) && ($args{dbstate} eq "Active")){
        $logger->info(__PACKAGE__ . ".$sub: Box is in ACTIVE state");
    }
    elsif(( grep /Standby/ , @result) && ($args{dbstate} eq "Standby")){
        $logger->info(__PACKAGE__ . ".$sub: Box is in STANDBY state");
    }
    else{
        $logger->error(__PACKAGE__ . ".$sub: Box state does not match with $args{dbstate} state");
        $logger->debug(__PACKAGE__ .".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub Switchover validation Completed Successfully");
    $logger->debug(__PACKAGE__ .".$sub  <-- Leaving Sub[1]");
    return 1;
}

=head2 postCallValidation

=over

=item DESCRIPTION:

  Function to validate post-call parameters

=item ARGUMENTS:

  log file
  pattern array

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  0   - fail
  1   - success

=item EXAMPLE:

  $postCallResult =$qsbc_obj->postCallValidation($log_file, @pattern);

=back

=cut


sub postCallValidation {

    my $sub = "postCallValidation()";
    my($self,$logFile,@pattern) = @_;
    my $logValidationResult=1;
    my $coreValidationResult=1;
    my $postCallResult=1;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->info( __PACKAGE__ . ".$sub --> Entered Sub $sub");

    #1 - Log string pattern match in specified log file
    $logger->info( __PACKAGE__ . ".$sub: Validating log string pattern in \"$logFile\" file and \"@pattern\"");
    unless($self->parseLogFiles($logFile,@pattern)) {
        $logger->error(__PACKAGE__ . ".$sub: Log validation failed. Could not find \"@pattern\" in \"$logFile\".");
        $logValidationResult=0;
    }    

    #2 Check for core dumps.
    $logger->info( __PACKAGE__ . ".$sub: Checking for core files");
    my $coreCheck = $self->coreValidation();   #coreValidation() returns 1 if no cores are found.
    if($coreCheck == 0){
        $logger->error(__PACKAGE__ . ".$sub: Core files found.");
        $coreValidationResult=0;
    }

    if ($logValidationResult == 1 && $coreValidationResult == 1) {
        $logger->debug(__PACKAGE__ . ".$sub: Log and Core Validation is successful");
        $postCallResult=1;
    } else {
        $logger->error(__PACKAGE__ . ".$sub: Log and Core Validation is failed");
        $postCallResult=0;
    }

    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub $sub [$postCallResult]");
    return $postCallResult;;

}

=head2 midcallValidation

=over

=item DESCRIPTION:

  Function to validate mid-call parameters 
 
=item ARGUMENTS:

  None
  
=item PACKAGE:
	
  SonusQA::QSBC
	
=item OUTPUT:

  0   - fail
  1   - success

=item EXAMPLE:
  
 $obj->midCallValidation(%args); 
  
=back
	
=cut


sub midCallValidation {

    my $sub = "midCallValidation";
    my($self,%args) = @_;
    my $vportResult=1;
    my $rdrResult=1;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->info( __PACKAGE__ . "--> Entered Sub [$sub]");

    # 1. Validate Used VPORT/Used Media Routed VPORTS/Used Onboard Transcoding VPORTS"
    $logger->info( __PACKAGE__ . "$sub: VPORT VALIDATION begin");
    my $cmd = 'pushd /usr/local/nextone/bin/; ./cli lstat; popd';
    $vportResult = $self->verifyTable($cmd, \%args);
    unless($vportResult){
        $logger->error(__PACKAGE__ . ".$sub:  VPORT VALIDATION failed.");
        $vportResult=0;
    }

    #2. Validate RDR
    $logger->info( __PACKAGE__ . ".$sub: RDR validation begin");
    $cmd = "statclient hkipnat | grep -c RDR";
    my @statclient_output1 = $self->execCmd($cmd);
    my $statclient_output = scalar @statclient_output1;

    if ($statclient_output != 2){
        $logger->error(__PACKAGE__ . ".$sub: RDR validation failed.");
        $rdrResult=0;
    }
    $logger->info( __PACKAGE__ . ".$sub: RDR value = $statclient_output and expected value is 2"); 

    # Return combined result
    
    $logger->info( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return ($vportResult,$rdrResult);

}

=head2 validateGlobalConfigAttribute

=over

=item DESCRIPTION:

  Function to validate global config attribute

=item ARGUMENTS:

  Mandatory:
	$attributeName

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  0   - fail
  1   - success

=item EXAMPLE:

 $obj->validateGlobalConfigAttribute($attributeName);

=back

=cut

sub validateGlobalConfigAttribute
{   
    my($self,$attributeName)=@_;
    my $sub = "validateGlobalConfigAttribute";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . "Entered $sub.");
    my $cmd = "nxconfig.pl -s $attributeName";
    
    my @output = $self->execCmd($cmd);
    
    if(grep /Invalid attribute/, @output){
      $logger->error(__PACKAGE__. " Could not find attribute $attributeName.");
      $logger->info(__PACKAGE__ . " Leaving $sub");
      return 0;
    }
    $logger->info(__PACKAGE__ . " Sucessfully retrieved record for : $attributeName.");
    $logger->info(__PACKAGE__ . " Leaving $sub.");
    return 1;
}

=head2 validateGlobalConfig

=over

=item DESCRIPTION:

  Function to validate global config attribute

=item ARGUMENTS:

  Mandatory:
        $attributeName, $flagValue

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  0   - fail
  1   - success

=item EXAMPLE:

 $GlobalConfig = "dyn-load-shed-PHID-usage-upper-threshold";
 unless($qsbc_obj->validateGlobalConfig($GlobalConfig,95)) {
        $logger->error(__PACKAGE__ . " Validation failed for $GlobalConfig");
        $result = 0;
    }

=back

=cut


sub validateGlobalConfig
{   
    my ($self,$attributeName,$flagValue)=@_; 
    my $sub = "validateGlobalConfig";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->info(__PACKAGE__ . ".$sub Entered Sub.");
    my $cmd = "nxconfig.pl -S | grep -i $attributeName";
    my $found = 0;
    my @output = $self->execCmd($cmd);
        if(grep (/$attributeName\s+$flagValue/g, @output)){
            $logger->info(__PACKAGE__ . " Found flag is: $attributeName and flag value is: $flagValue.");
            $found = 1;
            last;
        }
    
    if($found){
        $logger->info(__PACKAGE__ . ".$sub: Sucessfully matched: $attributeName with value: $flagValue.");
	$logger->info(__PACKAGE__ . ".$sub: Leaving sub [1]");
	return 1;
    } else {
        $logger->error(__PACKAGE__.".$sub: Flag/Attribute was not found.");
        $logger->info(__PACKAGE__ .".$sub: Leaving sub[0]");
        return 0;
    }
}

=head2 crontabOperation

=over

=item DESCRIPTION:

  This function used to add, delete or comment for crontab

=item ARGUMENTS:

  Mandatory Arguments: operation => operation to be performed add , delete or comment
                       line    => the command to be added , deleted or commented in crontab

=item PACKAGE:

  SonusQA::QSBC

=item OUTPUT:

  0 - if opeartion is successfull.
  1 - if opearion is not successful.

=item EXAMPLE:
%argsin=( operation=>'<add/delete/comment>',

           line=>'<command to be added/deleted/commented>')

  $qsbc_obj->crontabOperation(%argsin);


=cut
sub crontabOperation{
        my ($self,%args)=@_;
        my $sub_name="crontabOperation";
        my ($operation, $line);

        my $logger=Log::Log4perl->get_logger(__PACKAGE__ .".$sub_name");
        $logger->info(__PACKAGE__ ."$sub_name: Entered Sub");

        unless ( $args{operation} and $args{line} ) {
                $logger->error(__PACKAGE__ . ".$sub_name: Mandatory  fields operation or line is  empty or undefined.");
                $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
                return 0;
        }
        unless ($self->execCmd("crontab -l > /tmp/cron"))
        {
                $logger->error(__PACKAGE__ . ".$sub_name: crontab -l unsuccessful");
                $logger->debug(__PACKAGE__ . ".$sub_name: <--Leaving sub [0]");
                return 0;
        }
        if($args{operation} eq 'add') {
                unless( $self->execCmd("sed -i '\$a $args{line}'  /tmp/cron"))
                {
                        $logger->error(__PACKAGE__ . ".$sub_name: operation $args{operation} unsuccessful");
                        $logger->debug(__PACKAGE__ . ".$sub_name: <--Leaving sub [0]");
                        return 0;
                }
        } elsif($args{operation} eq 'delete') {
                $args{line} =  quotemeta($args{line});
                unless($self->execCmd("sed -i '/$args{line}/d'  /tmp/cron"))
                {
                        $logger->error(__PACKAGE__ . ".$sub_name: operation $args{operation} unsuccessful");
                        $logger->debug(__PACKAGE__ . ".$sub_name: <--Leaving sub [0]");
                        return 0;
                }
        } elsif($args{operation} eq 'comment') {
                $args{line} =  quotemeta($args{line});
                unless($self->execCmd("sed -i 's/$args{line}/#&/'  /tmp/cron"))
                {
                        $logger->error(__PACKAGE__ . ".$sub_name: operation $args{operation} unsuccessful");
                        $logger->debug(__PACKAGE__ . ".$sub_name: <--Leaving sub [0]");
                        return 0;
                }
        } else {
                $logger->error(__PACKAGE__ . ".$sub_name: operation specified not one of add/delete/comment");
                $logger->debug(__PACKAGE__ . ".$sub_name: Leaving sub [0]");
                return 0;
        }

        unless($self->execCmd("crontab  /tmp/cron"))
        {
                $logger->error(__PACKAGE__ . ".$sub_name: operation unsuccessful");
                $logger->debug(__PACKAGE__ . ".$sub_name: <--Leaving sub [0]");
                return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name:Leaving sub [1]");
        return 1;
}

=head2 C< verifyCDR >

=over

=item DESCRIPTION:

    Validate  the CDR.txt file (stored  in ATS server) based on passed hash reference

=item ARGUMENTS:

 Mandatory:
  '-tcid'   - TestCaseId
  '-copyLocation' - Location of the path where CDT should be copied
  '-localPath'    - Path where CDT files are present
  '-cdr_hash '    -cdr record hash with index and its corresponding value


=item PACKAGE:

    SonusQA::QSBC

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    0   - fail (even if one fails)
    1   - success (if all the records match)

=item EXAMPLES:
Usage for old one:
 my %cdrHash = ( {'0' => {'4' => "10.54.81.15", '31'=> "2614", } );

 QSBC->verifyCDR ( -tcid => $tcid, -cdr_hash => \%cdrHash , -copyLocation => $copyLocation, -localPath =>$localPath);

=back

=cut

sub verifyCDR {
    my($self, %args)=@_ ;
    my $sub_name = "verifyCDR()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "Entering $sub_name");
    my $i = -1;
    my %cdrhash = %{$args{-cdr_hash}};    
    my $size =0;
    my $flag =1;
    my ($file, @data);
    unless ($self) {
        $logger->error(__PACKAGE__ . ".$sub_name: Mandatory shell session input is empty or blank.");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    foreach (qw(-tcid -copyLocation -localPath -cdr_hash)) {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument $_ not provided.");
            $flag = 0;
	    last;
        }
    }
    unless($flag ){
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
	return 0;
    }	
	
    unless($file = $self->collectCDR(%args)){
        $logger->error(__PACKAGE__ . ".$sub_name: Couldn't get data from collectCDR function");
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }   
    unless(@data = $self->{conn}->cmd("cat $file")){
	$logger->error(__PACKAGE__ . ".$sub_name: Couldn't execute cat Command");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
   
=head
  This is somewhat @data looks like, matching 1st line of every call(1  : start-time                          = 2020-02-05 14:59:22) and correspondingly increasing value of i.

   1  : start-time                          = 2020-02-05 14:59:22
   2  : start-time                          = 1580894962

   1  : start-time                          = 2020-02-05 14:53:06
   2  : start-time                          = 1580894586
=cut
 
    foreach (@data){
      $i++ if($_ =~/^\s*1\s*:/); # Increasing value of i for every call index
      next unless(exists $cdrhash{$i}); # Checking next call index if value of current index is not present in cdrhash
      if($_ =~ /^\s*(\d+)\s*:.+=\s*(.+)\s*$/){
        my ($k, $v) = ($1,$2); # Getting index and value of the matching line 
        next unless(exists $cdrhash{$i}{$k});
        if($cdrhash{$i}{$k} =~/^$v$/){ #Comapairing value of data from the file and cdrhash value
          $logger->debug(__PACKAGE__ . ".$sub_name: MATCHED ->$cdrhash{$i}{$k}");
          delete $cdrhash{$i}{$k};
        }
        else{
          $flag = 0;
          $logger->error(__PACKAGE__ . ".$sub_name: Failed to match ->$cdrhash{$i}{$k}");
        }
      }
    }
     
    foreach my $key(keys %cdrhash){
      if(keys %{$cdrhash{$key}}){
        $logger->debug(__PACKAGE__ . ".$sub_name: following fields are not present ".Dumper(\%{$cdrhash{$key}}));
        $flag = 0;
      }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name:Leaving sub [$flag]");
    return $flag;
    
}

=head2 collectBacktrace

=over

=item DESCRIPTION:
	
  This function is used to collect the backtrace logs. 

=item ARGUMENTS:
  Mandatory : 
  '-core'   - Name of the core  
  '-copyLocation' - Location of the path where core and file should be copied
  '-filename'    - Name of file created
	
=item PACKAGE:
	
  SonusQA::QSBC
	
=item OUTPUT:
  0   - fail
  filename   - success

=item EXAMPLE:
  
  $obj->collectBacktrace(%args);
  
=back
	
=cut


sub collectBacktrace{
  my ($self, %args) = @_;
  my $sub= "collectBacktrace";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->info(__PACKAGE__ . ".$sub --> Entered Sub");
  my ($match, $match1, $prematch, $prematch1, $handle);
  my $flag =1;

  foreach (qw(-core -location -filename )){
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory argument $_ not provided.");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
            $flag = 0;
            last;
        }
  }
    return 0 unless($flag);

  unless($self->{conn}->print("gdb -c /var/core/$args{-core} /usr/local/nextone/bin/gis")){
      $logger->error(__PACKAGE__ . ".$sub: Cannot execute command.");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
      return 0;

  }

  unless(($prematch, $match) =$self->{conn}->waitfor(-match => '/\(gdb\)/')){
      $logger->error(__PACKAGE__ . ".$sub: Failed to get the prompt.");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
      return 0;

  }
  
  unless($self->{conn}->print("bt full")){
      $logger->error(__PACKAGE__ . ".$sub: Cannot execute command.");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
      return 0;

  }

  unless(($prematch1, $match1) =$self->{conn}->waitfor(-match => '/\(gdb\)/')){
      $logger->error(__PACKAGE__ . ".$sub: Failed to get the prompt.");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
      return 0;

  }
  
  unless($self->execCmd("q")){
      $logger->error(__PACKAGE__ . ".$sub: Failed to execute command.");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
      return 0;
  }

  unless(open($handle, ">", "$args{-location}/$args{-filename}")){
      $logger->error(__PACKAGE__.".$sub:Can't open $args{-location}/$args{-filename}: $!");
      $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub[0]");
      return 0;
  }
  binmode($handle);               # for raw; else set the encoding
  print $handle "$prematch\n$prematch1\n";
  close($handle);
  
  $logger->debug(__PACKAGE__ . ".$sub:Leaving sub [$args{-filename}]");
  return "$args{-filename}";
  
}

=head2 C< rollbackSwitchVersion >

=over

=item DESCRIPTION:

    This function is usde to rollback a box to its older version using switch version

=item ARGUMENTS:
Mandatory argument:
    -version :rollbackversion 

=item PACKAGE:

    SonusQA::QSBC

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    0   - fail (even if one fails)
    1   - success (if all the records match)

=item EXAMPLES:

 $QSBC->switchVersion(%args);

=back
)
=cut

  
sub switchVersion{
  my ($self, %args)=@_;
  my $sub_name="switchVersion";
  my $logger=Log::Log4perl->get_logger(__PACKAGE__ .".$sub_name");
  $logger->debug(__PACKAGE__ .".$sub_name: --> Entered Sub");

  unless($args{-version}) {
      $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument $args{-version} not provided.");
      $logger->debug(__PACKAGE__ .".$sub_name: <-- Leaving sub [0]");
      return 0;
  }

  $self->{conn}->print("sv $args{-version}");

  if($self->{conn}->waitfor('/Switch versions?/')){
      $logger->debug(__PACKAGE__ .".$sub_name: Switch versions? [n]: y ");
      unless($self->{conn}->print("y")){
          $logger->error(__PACKAGE__ .".$sub_name: Failed to Switch version");
          $logger->debug(__PACKAGE__ .".$sub_name: <-- Leaving sub [0]");
          return 0;
      }
  }

  unless($self->{conn}->waitfor(-match =>$self->{PROMPT} , -timeout =>600)){
      $logger->error(__PACKAGE__ .".$sub_name: Failed at Switch version");
      $logger->debug(__PACKAGE__ .".$sub_name: <-- Leaving sub [0]");
      return 0;
  }
  
  $logger->info(__PACKAGE__ .".$sub_name: SV to $args{-version} completed");
  $logger->debug(__PACKAGE__ .".$sub_name: <-- Leaving sub [1]");
  return 1;  
}

=head2 C< validateSipStats >

=over

=item DESCRIPTION:

    Run cli stats sip command and stores its output
    Based on label it should check the value: If value is passed compare with output and return 0/1 , else it should return the    value

=item ARGUMENTS:
Mandatory argument:
    Attribute
        ex:Invite-In
    Stats
        ex:last 10 minutes

Optional Argument:
    Value :0/1


=item PACKAGE:

    SonusQA::QSBC

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    0   - fail (even if one fails)
    1   - success (if all the records match)
    value

=item EXAMPLES:

 $qsbc_obj->validateSipStats(-attribute => 'Invite-In', -stats => 'last 10 minutes');

=back
)
=cut

sub validateSipStats{
    my ($self,%args) = @_ ;
    my $sub_name = "validateSipStats()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my $flag = 1;
    my (@cmdres, @res);
    foreach (qw( -attribute -stats)) {
        unless($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument $_ not provided.");
            $flag = 0;
	    last;
        }
    }
    unless($flag ){
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
      return 0;
    }
    my ($set, $result, $output);
    unless(@cmdres = $self->execCmd("cli stats sip")){
	      $logger->error(__PACKAGE__ . ".$sub_name: Couldn't execute 'cli stats sip'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[0]");
        return 0;
    }
    
    foreach(@cmdres){
      $set = 1 if(/$args{-stats}/);
      next unless($set);           
        
      if(/$args{-attribute}:(.+)/){
        $result = $1;
        last;
      }
      
    }
    @res = split('\s+', $result);
    foreach(@res){
      $output += $_;
    }
    if(exists $args{-val}){
      $output = ($args{-val} == $output) ? 1 : 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$output]");
    return $output;
    	
}

=head2 C< validateDSP >

=over

=item DESCRIPTION:

    Run  xstat cpp counters in ocli and validate the following cases

=item ARGUMENTS:
Mandatory argument:
  Attribute 
        ex:IP Rx Packets

Optional Argument:
  Attribute Value
        ex:15,657
  Dsp Counter (Should be in range 00 to 11)

Note: It should take maximum Three  argument.

=item PACKAGE:

    SonusQA::QSBC

=item GLOBAL VARIABLES USED:

    None

=item OUTPUT:

    0   - fail (even if one fails)
    1   - success (if all the records match)
    Value

=item EXAMPLES:

 $qsbc_obj->validateDSP( -attribute =>'IP Rx Packets', -dsp => '0', -val =>'15,657');

=back
)
=cut

sub validateDSP{
  my ($self, %args) = @_ ;
  my $sub_name = "validateDSP()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
  my (@cmdres, $cpp ,$res);
  my $flag;


  unless($args{-attribute}) {
      $logger->error(__PACKAGE__ . ".$sub_name: Mandatory argument $args{-attribute} not provided.");
      $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
      return 0;
  }
   
  $self->{conn}->prompt($self->{DEFAULTPROMPT});
  $self->execCmd("ocli");
  
  unless(@cmdres =  $self->execCmd("xstat cpp counters")){
      $logger->error(__PACKAGE__.".$sub_name: Could not execute  xstat cpp counters command");
      $logger->debug(__PACKAGE__ .".$sub_name: <-- Leaving sub [0]");
      return 0;
  }
  my $set;
  my $label = (exists $args{-dsp}) ?  'DSP CPP counters' : 'DSP CPP counters \(total\)';
  $logger->debug(__PACKAGE__ .".$sub_name: LABEL- $args{-val}");
  foreach(@cmdres){
      $set = 1 if(/$label/);
      next unless($set);
     
      if(/$args{-attribute}\s+(.+)/){
        $res = $1;
        my @result = grep /^\d/ ,split('\s+', $res);
        $res = $result[0] unless(exists $args{-dsp});	
=head
    Since some extra character|digit are coming , we are modifying the string($res) after runnnig xstat cpp counters command

    AUTOMATION> ocli
^[[?1034h                                  ^M^[[7m ocli^[[0m >> xstat cpp counters

           [DSP CPP counters]          00          01          02          03          04          05          06          07          08          09          10          11
  1             IP Rx Packets  ^[[1;31m    15,657^[[0m    ^[[1;31m   3,507^[[0m    ^[[1;31m   3,507^[[0m    ^[[1;31m   3,507^[[0m    ^[[1;31m   3,507^[[0m    ^[[1;31m   3,507^[[0m    ^[[1;31m   3,507^[[0m    ^[[1;31m   3,507^[[0m    ^[[1;31m   3,507^[[0m    ^[[1;31m      66^[[0m    ^[[1;31m      66^[[0m    ^[[1;31m      66^[[0m
=cut         
          if(exists $args{-dsp}){
            $res = $result[$args{-dsp}];
            $logger->debug(__PACKAGE__ . ".$sub_name:RES-->$res");				
          }
          last;
		  }
  }
	
  if($args{-val}){
    $res = ($args{-val} == $res) ? 1 : 0;
    
  }
 
	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub[$res]");
  return $res;

}


1;

