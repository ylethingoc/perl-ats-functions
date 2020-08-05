package SonusQA::UnixBase;

=pod

=head1 NAME

SonusQA::UnixBase - Perl module for Unix interaction

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure

   The ATS Package will automatically load available packages from the Automated Testing Structure.
   SonusQA::UnixBase is an inherited package, used by server packages such as SonusQA::DSI, SonusQA::DSICLI, and SonusQA::PSX.

=head1 REQUIRES

Perl5.8.6, Sys::Hostname, Log::Log4perl, SonusQA::Base, SonusQA::Utilities::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

   SonusQA::UnixBase is an inherited package, used by server packages such as SonusQA::DSI, SonusQA::DSICLI, and SonusQA::PSX.

=head1 AUTHORS

Darren Ball <dball@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.
See Inline documentation for contributors.

=head1 METHODS

=cut

use strict; 
   
use SonusQA::Utils qw(:errorhandlers :utilities); 
use Sys::Hostname;  
use Log::Log4perl qw(get_logger :easy);
use Net::Telnet;
use XML::Simple;
use Data::Dumper;
use POSIX qw(strftime);
use ATS;   

# UNIX system routines for objects inheriting this package
# -------------------------------

# Get/Set Routines for system level retrevials

=head2 getHostIP

=over

=item DESCRIPTION:

  Method to retrieve IP address for the specified interface.

=item REQUIRED: 

    INTERFACE

=item RETURNS:

    ipaddress - Success
    0 - Failure

=item EXAMPLE: 

    $ipAddr = $obj->getHostIP("hme0");
  * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub getHostIP {
  my ($self, $interface ) = @_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getHostIP");
  my(@cmdResults, $cmd, $ipAddr);
  
  $ipAddr = 0;  # default value, unretrievable
  
  unless($interface){
    $logger->warn(__PACKAGE__ . ".getHostIP  ARGUMENTS MISSING.  PLEASE PROVIDE INTERFACE NAME FOR ETHERNET ADAPTOR");
    print __PACKAGE__ . ".createDm  ARGUMENTS MISSING.  PLEASE PROVIDE INTERFACE NAME FOR ETHERNET ADAPTOR\n";
    return 0;
  };
  $cmd = sprintf("/sbin/ifconfig %s", $interface);
  unless (@cmdResults = $self->{conn}->cmd(String => $cmd, Timeout => 60) ) {
    $logger->debug(__PACKAGE__ . ".getHostIP   UNABLE TO PROCESS CMD: $cmd");
    $logger->debug(__PACKAGE__ . ".getHostIP   errmsg: " . $self->{conn}->errmsg);
    $logger->debug(__PACKAGE__ . ".getHostIP   Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".getHostIP   Session Input Log is: $self->{sessionLog2}");
    return 0;
  }
  foreach(@cmdResults){
    if(/inet ([\d.]+)/){
      $ipAddr = $1;
    }
  }
  return $ipAddr;
}

=head2 setHostIP

=over

=item DESCRIPTION:

  Routine set host IP address

=item REQUIRED: 

    IPADDRRESS
    INTERFACE

=item OPTIONAL:

    NETMASK (DEFAULTS TO 255.255.255.0)

=item RETURNS:

    1 - Success
    0 - Failure

=item Example: 

    $ok = $obj->setHostIP($ipAddr, $interface, $netmask);  
  * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub setHostIP {
  my ($self, $ipAddr, $interface, $netmask ) = @_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setHostIP");
  my(@cmdResults, $cmd);
  
  $ipAddr = 0;  # default value, unretrievable
  if(uc($self->{OBJ_USER}) ne "ROOT"){
    $logger->warn(__PACKAGE__ . ".setHostIP  MUST BE ROOT TO EXECUTE THIS METHOD");
    print __PACKAGE__ . ".setHostIP  MUST BE ROOT TO EXECUTE THIS METHOD\n";
    return 0;
  }
  unless($ipAddr && $interface){
    $logger->warn(__PACKAGE__ . ".setHostIP  ARGUMENTS MISSING.  PLEASE PROVIDE IP ADDRESS AND INTERFACE NAME FOR ETHERNET ADAPTOR");
    print __PACKAGE__ . ".setHostIP  ARGUMENTS MISSING.  PLEASE PROVIDE IP ADDRESS AND INTERFACE NAME FOR ETHERNET ADAPTOR\n";
    return 0;
  };
  if(!defined($netmask)){$netmask = "255.255.255.0";}
  
  $cmd = sprintf("/sbin/ifconfig %s %s netmask %s", $interface, $ipAddr, $netmask);
  # Execute a series of commands to re-configure ethernet interface.
  $self->{conn}->cmd(String => $cmd, Timeout => 15);
  $cmd = "/etc/init.d/inetsvc stop";
  $self->{conn}->cmd(String => $cmd, Timeout => 15);
  $cmd = "/etc/init.d/inetsvc start";
  $self->{conn}->cmd(String => $cmd, Timeout => 15);
  #check to see if interface IP address has been changed.
  if($self->getHostIP($interface) ne $ipAddr){
    $logger->warn(__PACKAGE__ . ".setHostIP  UNABLE TO SET TO SET HOST IP [$ipAddr] FOR INTERFACE [$interface]");
    return 0;
  }
  return 1;
}

=head2 getDefaultRoute

=over

=item DESCRIPTION:

  Method to retrieve default route information using /etc/defaultrouter

=item REQUIRED: 

    None

=item OPTIONAL:

    None

=item RETURNS:

    default route - Success
    0 - Failure

=item Example: 

    $defaultRoute = $obj->getDefaultRoute();
  * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub getDefaultRoute {
  my ($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getDefaultRoute");       
  # use /etc/defaultrouter to determine default route
  my(@cmdResults,$cmd, $defaultRouter);
  $defaultRouter = "0"; # Assume that default route can not be found.
  $cmd = "/usr/bin/cat /etc/defaultrouter";
  unless (@cmdResults = $self->{conn}->cmd(String => $cmd, Timeout => 15) ) {
    $logger->warn(__PACKAGE__ . ".getDefaultRoute  UNABLE TO RETRIEVE DEFAULT ROUTE");
    $logger->debug(__PACKAGE__ . ".getDefaultRoute  errmsg: " . $self->{conn}->errmsg);
    $logger->debug(__PACKAGE__ . ".getDefaultRoute  Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".getDefaultRoute  Session Input Log is: $self->{sessionLog2}");
    return 0;
  }
  foreach(@cmdResults){
    if (/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/){
      $defaultRouter = $1;
    }
  }
  if($defaultRouter eq "0"){
    $logger->warn(__PACKAGE__ . ".getDefaultRoute  UNABLE TO ETRACT DEFAULT ROUTE FROM COMMAND RESULTS");
  }
  return $defaultRouter;     
}

=head2 setDefaultRoute

=over

=item DESCRIPTION:

  Method to set default route(s) for host
  This method attempts to preserve /etc/defaultrouter to /etc/defaultrouter_YYYYMMDDHHSS
  This method overwrites /etc/defaultrouter.

=item  REQUIRED: 

    IPADDR

=item OPTIONAL:

    None

=item RETURNS:

    0 - Failure

=item Example: 

    $ok = $obj->setDefaultRoute("10.9.16.1");  
  * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub setDefaultRoute {
  my ($self,$ipAddr)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setDefaultRoute");
  if(uc($self->{OBJ_USER}) ne 'ROOT'){
    $logger->warn(__PACKAGE__ . ".setDefaultRoute  MUST BE ROOT TO PERFORM THIS CALL");
    return 0;
  }
  unless($ipAddr){
    $logger->warn(__PACKAGE__ . ".setDefaultRoute  ARGUMENTS MISSING.  PLEASE PROVIDE IP ADDRESS FOR DEFAULT ROUTE");
    print __PACKAGE__ . ".setDefaultRoute  ARGUMENTS MISSING.  PLEASE PROVIDE IP ADDRESS FOR DEFAULT ROUTE\n";
    return 0;
  };
  my ($cmd, $timestamp);
  $timestamp = strftime "%Y%m%d%H%M%S", localtime;
  # Attempt to preserve /etc/defaultrouter
  $cmd = sprintf("/usr/bin/cp /etc/defaultrouter /etc/defaultrouter_%s", $timestamp);
  $self->{conn}->cmd(String => $cmd, Timeout => 15);
  # Overwrite /etc/defaultrouter with the new default route
  $cmd = sprintf("echo %s > /etc/defaultroute",$ipAddr);  
  return $self->{conn}->cmd(String => $cmd, Timeout => 15); 
}

=head2 getHostname

=over

=item DESCRIPTION:

  Method to get hostname from a specified interface file (ex: /etc/hostname.<INTERFACE>)

=item REQUIRED: 

    INTERFACE

=item OPTIONAL: 

    None

=item RETURNS:

    hostname - Success
    0 - Failure

=item Example:

    $hmeHostName = $obj->getHostname("hme0");
  * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub getHostname {
  my ($self,$interface)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getHostname");       
  unless($interface){
    $logger->warn(__PACKAGE__ . ".getHostname  ARGUMENTS MISSING.  PLEASE PROVIDE INTERFACE NAME FOR ADAPTOR");
    print __PACKAGE__ . ".getHostname  ARGUMENTS MISSING.  PLEASE PROVIDE INTERFACE NAME FOR ADAPTOR\n";
    return 0;
  };
  my($cmdResults,$cmd);  
  $cmd = sprintf("/usr/bin/cat /etc/hostname.%s", $interface);
  $cmdResults =  $self->{conn}->cmd($cmd);
  return chomp($cmdResults);           
}

=head2 getNodename

=over

=item DESCRIPTION:

  Method to get nodename of the object (Unix System).
  This method will use /etc/nodename to discover the system nodename

=item REQUIRED:

    None

=item OPTIONAL:

    None

=item RETURNS:

    nodename

=item Example:

    $nodeName = $obj->getNodename(); 
    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub getNodename {
  my ($self)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getHostname");
  my($cmdResults,$cmd);
  $cmd = "/usr/bin/cat /etc/nodename";
  $cmdResults =  $self->{conn}->cmd($cmd);
  return chomp($cmdResults);
}

=head2 setHostName

=over

=item DESCRIPTION:

  **** ROOT ONLY METHOD ****
  Method to set the hostname for the specified interface.
  This method will overwrite /etc/hostname.<INTERFACE> with the name supplied.
  An attempt will be made to preserve /etc/hostname.<INTERFACE> to /etc/hostname.<INTERFACE>_<YYYYMMDDHHSS>

=item REQUIRED: 

    INTERACE, NAME

=item OPTIONAL:

    None

=item RETURNS:

    1 - Sunccess
    0 - Failure

=item Example: 

    $ok = $obj->setHostName("soft26", "bge0");
  * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub setHostname {
  my ($self,$interface, $name)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setHostname");       
  
  if(uc($self->{OBJ_USER}) ne 'ROOT'){
    $logger->warn(__PACKAGE__ . ".setHostname  MUST BE ROOT TO PERFORM THIS CALL");
    return 0;
  }
  unless($interface && $name){
    $logger->warn(__PACKAGE__ . ".setHostname  ARGUMENTS MISSING.  PLEASE PROVIDE INTERFACE AND NAME FOR ADAPTOR");
    print __PACKAGE__ . ".setHostname  ARGUMENTS MISSING.  PLEASE PROVIDE INTERFACE AND NAME FOR ADAPTOR\n";
    return 0;
  };
  my ($cmdResults, $cmd, $timestamp);
  $timestamp = strftime "%Y%m%d%H%M%S", localtime;
  $cmd = sprintf("/usr/bin/cp /etc/hostname.%s /etc/hostname.%s_%s",$interface, $interface, $timestamp);
  $self->{conn}->cmd(String => $cmd, Timeout => 15);
  $cmd = sprintf("echo %s > /etc/hostname.%s",$name,$interface);
  $self->{conn}->cmd(String => $cmd, Timeout => 15);
  if($self->getHostname($interface) ne $name){
    $logger->warn(__PACKAGE__ . ".setHostname  HOST NAME [$name] NOT SUCCESSFULLY SET FOR INTERFACE [$interface]");
    return 0;
  }
  return 1;  
}

=head2 setNodename

=over

=item DESCRIPTION:

  **** ROOT ONLY METHOD ****
  Method to set the nodename for the object (Unix System).
  This method will overwrite /etc/nodename with the name supplied.
  An attempt will be made to preserve /etc/nodename to /etc/nodename_<YYYYMMDDHHSS>

=item REQUIRED: 

    NAME

=item OPTIONAL:

    None

=item RETURNS:

    1 - Sunccess
    0 - Failure

=item Example: 

    $ok = $obj->setHostName("soft26", "bge0");
  * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub setNodename {
  my ($self, $name)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setHostname");       
  
  if(uc($self->{OBJ_USER}) ne 'ROOT'){
    $logger->warn(__PACKAGE__ . ".setNodename  MUST BE ROOT TO PERFORM THIS CALL");
    return 0;
  }
  unless($name){
    $logger->warn(__PACKAGE__ . ".setNodename  ARGUMENTS MISSING.  PLEASE PROVIDE NODE NAME FOR SYSTEM");
    print __PACKAGE__ . ".setNodename  ARGUMENTS MISSING.  PLEASE PROVIDE NODE NAME FOR SYSTEM\n";
    return 0;
  };
  my ($cmdResults, $cmd, $timestamp);
  $timestamp = strftime "%Y%m%d%H%M%S", localtime;
  $cmd = sprintf("/usr/bin/cp /etc/nodename /etc/nodename_%s", $timestamp);
  $self->{conn}->cmd(String => $cmd, Timeout => 15);
  $cmd = sprintf("echo %s > /etc/nodename",$name);
  $self->{conn}->cmd(String => $cmd, Timeout => 15);
  if($self->getNodename() ne $name){
    $logger->warn(__PACKAGE__ . ".setNodename  NODENAME [$name] NOT SUCCESSFULLY SET FOR SYSTEM");
    return 0;
  }
  return 1; 
}

# System monitoring routines - routines for enabling sar, prstat and others if they come to be of use.

=head2 startSAR

=over

=item DESCRIPTION:

  **** ROOT ONLY METHOD ****

  Method will start SAR utility (background process with nohup), in order to record system information during a possible testcase run.  
  If $obj->{SAR_LOGFILE} (reference created by this function) exists on $obj destruction, an attempt will be made to kill all SAR processes.
  If using this method, script should call logSARresults, which will kill the SAR processes, and include information about system process and utilitization with test case logs.

=item REQUIRED: 

    INTERVAL, COUNT

=item OPTIONAL:

    None

=item RETURNS:

    None

=item Example: 

    $ok = $obj->startSAR(30, 60); # This combination will collect sar results at an interval of 30 seconds for 60 intervals (30 minutes).
                                  # This can be extended to the entire test case run, by setting COUNT to a high value like (9999).

  * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub startSAR {
  my ($self,$interval, $count)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startSAR");
  if(uc($self->{OBJ_USER}) ne 'ROOT'){
    $logger->warn(__PACKAGE__ . ".startSAR  MUST BE ROOT TO PERFORM THIS CALL");
    return 0;
  }
  unless($interval && $count){
    $logger->warn(__PACKAGE__ . ".startSAR  ARGUMENTS MISSING.  PLEASE PROVIDE SAR INTERVAL AND COUNT");
    print __PACKAGE__ . ".startSAR  ARGUMENTS MISSING.  PLEASE PROVIDE SAR INTERVAL AND COUNT\n";
    return 0;
  };
  my($cmd, $logFile,$time);
  $time = strftime "%Y%m%d%H%M%S", localtime();
  $logFile = "sar.$$.$time.sarlog";
  $self->{SAR_LOGFILE} = $logFile;
  $cmd = sprintf('/usr/bin/nohup /bin/sar -A -o %s %d %d >/dev/null 2>&1&',$logFile,$interval,$count);
}

=head2 startPRSTAT

=over

=item DESCRIPTION:

  **** ROOT ONLY METHOD ****

  Method will start PRSTAT utility (background process with nohup), in order to record system information during a possible testcase run.  
  If $obj->{PRSTAT_LOGFILE} (reference created by this function) exists on $obj destruction, an attempt will be made to kill all PRSTAT processes.
  If using this method, script should call logPRSTATresults, which will kill the PRSTAT processes, and include information about system process and utilitization with test case logs.

  cmd = '/usr/bin/nohup /bin/prstat %d %d > %s &' % (PrstatInt, PrstatSamples, PrstatOutputFileName)

=item REQUIRED: 

    INTERVAL, COUNT

=item OPTIONAL:

    None

=item RETURNS:

    None

=item Example: 

    $ok = $obj->startPRSTAT(30, 60); # This combination will collect prstat results at an interval of 30 seconds for 60 intervals (30 minutes).
                                     # This can be extended to the entire test case run, by setting COUNT to a high value like (9999). 
  * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub startPRSTAT {
  my ($self,$interval, $count)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".startPRSTAT");
  if(uc($self->{OBJ_USER}) ne 'ROOT'){
    $logger->warn(__PACKAGE__ . ".startPRSTAT  MUST BE ROOT TO PERFORM THIS CALL");
    return 0;
  }
  unless($interval && $count){
    $logger->warn(__PACKAGE__ . ".startPRSTAT  ARGUMENTS MISSING.  PLEASE PROVIDE PRSTAT INTERVAL AND COUNT");
    print __PACKAGE__ . ".startPRSTAT  ARGUMENTS MISSING.  PLEASE PROVIDE PRSTAT INTERVAL AND COUNT\n";
    return 0;
  };
  my($cmd, $logFile,$time);
  $time = strftime "%Y%m%d%H%M%S", localtime();
  $logFile = "prstat.$$.$time.prstatlog";
  $self->{PRSTAT_LOGFILE} = $logFile;
  $cmd = sprintf('/usr/bin/nohup /bin/prstat %d %d > %s &',$interval,$count,$logFile);
}

# Verification routines - routines for verifying system level items.


=head2 verifyUnixPatchLevel

=over

=item DESCRIPTION:

    Routine to verify a specific patch exists on Unix system
    showrev -p | grep $patch | wc -l

=item REQUIRED:

    patchNum

=item OPTIONAL:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=item Example:

    $ok = $obj->verifyUnixPatchLevel($patchNum); 
    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub verifyUnixPatchLevel {
  my($self,$patchNum)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyUnixPatchLevel");
  my ($cmd, $cmdResults, $cmdResult);
  $cmd = sprintf("/usr/bin/showrev -p | grep %s | wc -l",$patchNum);
  $cmdResult = $self->{conn}->cmd(String => $cmd, Timeout => 30);
  if($cmdResult == 1 ){
      $logger->info(__PACKAGE__ . ".verifyUnixPatchLevel  UNIX PATCH LEVEL VERIFIED");
  }elsif($cmdResult >= 1){
    $logger->warn(__PACKAGE__ . ".verifyUnixPatchLevel  UNIX PATCH LEVEL VERIFIED - PATCH COUNT EXCEED 1 THOUGH???");
  }else{
      $logger->warn(__PACKAGE__ . ".verifyUnixPatchLevel  UNIX PATCH LEVEL NOT VERIFIED");
      return 0;
  }
  return 1;
}

=head2 mkDir

=over

=item DESCRIPTION:

    Routine to create a directory
    command: /usr/bin/mkdir -m <mode> -p <directory>

=item REQUIRED:

    path - directory path
    mode

=item OPTIONAL:

    None

=item RETURNS:

    $_

=item Example:

    $ok = $obj->mkDir($path, $mode);
    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub mkDir { 
   my($self,$path, $mode)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".mkDir");
   my($cmdResult,$cmd);
   $cmd = sprintf("/usr/bin/mkdir -m %s -p %s", $mode, $path);
   $cmdResult = $self->{conn}->cmd(String => $cmd, Timeout => 5);
   if($self->verifyPathExists($path)){
      $logger->info(__PACKAGE__ . ".mkDir  DIRECTORY CREATED [$path]");
      push(@{$self->{STACK}},['rmDir',["$path"]]);
   }else{
      $logger->warn(__PACKAGE__ . ".mkDir  DIRECTORY CREATION FAILURE [$path]");
   }
   
   return $_;
}

=head2 rmDir

=over

=item DESCRIPTION:

    Routine to remove the specified directory
    command: /usr/bin/rm -rf <directory>

=item REQUIRED:

    path - directory path

=item OPTIONAL:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=item Example:

    $ok = $obj->rmDir($path);
    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub rmDir { 
   my($self,$path)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".rmDir");
   my($cmdResult,$cmd);
   $cmd = sprintf("/usr/bin/rm -rf %s", $path);
   $logger->debug(__PACKAGE__ . ".rmDir  VERIFYING PATH EXISTANCE PRIOR TO REMOVAL [$path]");
   if($self->verifyPathExists($path)){
    $cmdResult = $self->{conn}->cmd(String => $cmd, Timeout => 5);
    if(!$self->verifyPathExists($path)){
       $logger->debug(__PACKAGE__ . ".rmDir  DIRECTORY REMOVED [$path]");
    }else{
       $logger->warn(__PACKAGE__ . ".rmDir  DIRECTORY REMOVAK FAILURE [$path]");
       return 0;      
    }
   }else{
      $logger->debug(__PACKAGE__ . ".rmDir PATH [$path] DID NOT EXIST.");
   }
   return 1;
}

=head2 mkFile

=over

=item DESCRIPTION:

    Routine to make file
    $cmd = sprintf("/usr/sbin/mkfile %s%s %s", $filesize, $fileunit, $filename);

=item REQUIRED:

    filename 
    filesize
    fileunit

=item OPTIONAL:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=item Example:

    $ok = $obj->mkFile($filename, $filesize, $fileunit);
    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub mkFile { 
  my($self,$filename, $filesize, $fileunit)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".mkFile");
  my($cmdResult,$cmd);
  $cmd = sprintf("/usr/sbin/mkfile %s%s %s", $filesize, $fileunit, $filename);
  $cmdResult = $self->{conn}->cmd(String => $cmd, Timeout => 60);
  if($cmdResult >= 1){
     $logger->info(__PACKAGE__ . ".mkFile  FILE CREATED [$filename $filesize $fileunit]");
     #push(@{$self->{STACK}},['deleteFSsrc', [$keyVals] ]);
     push(@{$self->{STACK}},['rmfile',["$filename"]]);
  }else{
     $logger->warn(__PACKAGE__ . ".mkFile  FILE CREATION FAILURE [$filename $filesize $fileunit]");
     return 0;
  }
  
  return 1;
}

=head2 rmFile

=over

=item DESCRIPTION:

    Routine to remove the specified file
    $cmd = sprintf("/usr/bin/rm -rf %s", $path);

=item REQUIRED:

    filename with path

=item OPTIONAL:

    None

=item RETURNS:

    1 - Success

=item Example:

    $ok = $obj->rmFile($filename);
    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub rmFile { 
   my($self,$path)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".rmFile");
   my($cmdResult,$cmd, $ok);
   $cmd = sprintf("/usr/bin/rm -rf %s", $path);
   $logger->info(__PACKAGE__ . ".rmFile  VERIFYING PATH EXISTANCE PRIOR TO REMOVAL [$path]");
   if($self->verifyPathExists($path)){
    $ok = $self->{conn}->cmd(String => $cmd, Timeout => 5);
    if(!$self->verifyPathExists($path)){
       $logger->debug(__PACKAGE__ . ".rmFile  FILE REMOVED [$path]");
    }else{
       $logger->warn(__PACKAGE__ . ".rmFile  FILE REMOVAL FAILURE [$path]");
    }
   }else{
      $logger->debug(__PACKAGE__ . ".rmFile PATH [$path] DID NOT EXIST.");
   }
   return 1;
}

=head2 retrieveDirListing

=over

=item DESCRIPTION:

    Routine to list of files in  the specified directory.
    $cmd = sprintf("ls -1 %s", $path);

=item REQUIRED:

    path

=item OPTIONAL:

    None

=item RETURNS:

    list of files - Success

=item Example:

    @list = $obj->retrieveDirListing($path);
    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub retrieveDirListing { 
   my($self,$path)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".retrieveDirListing");
   my(@cmdResult,$cmd, $ok);
   #$self->{conn}->cmd("cd $path");
   $cmd = sprintf("ls -1 %s", $path);
   $logger->info(__PACKAGE__ . ".retrieveDirListing  ISSUING CMD: $cmd");
   $logger->info(__PACKAGE__ . ".retrieveDirListing  RETRIEVING DIRECTORY LISTING [$path]");
   @cmdResult = $self->{conn}->cmd(String => $cmd, Timeout => 60);
   foreach(@cmdResult){
    $logger->info(__PACKAGE__ . ".retrieveDirListing  FILE: $_");
   }
   return @cmdResult;
}

=head2 cleanDir

=over

=item DESCRIPTION:

    Routine to clean the specified directory.
    $cmd = sprintf("rm %s/*", $path);

=item REQUIRED:

    path

=item OPTIONAL:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=item Example:

    $ok = $obj->cleanDir($path);
    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub cleanDir { 
   my($self,$path)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".cleanDir");
   my(@cmdResult,$cmd, $ok);
   $cmd = sprintf("rm %s/*", $path);
   $logger->info(__PACKAGE__ . ".cleanDir  CLEANING [$path]");
   $ok = $self->{conn}->cmd(String => $cmd, Timeout => 60);
   return $ok;
}

=head2 verifyUnixPackage

=over

=item DESCRIPTION:

    Routine to verify a Unix pacakge exists on Unix system
    $cmd = sprintf("/usr/bin/pkginfo | grep %s | wc -l",$package);

=item REQUIRED:

    package name

=item OPTIONAL:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=item Example:

    $ok = $obj->verifyUnixPackage($package);
    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub verifyUnixPackage { 
   my($self,$package)=@_;
   my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyUnixPackage");
   my($cmdResult,$cmd);
   $cmd = sprintf("/usr/bin/pkginfo | grep %s | wc -l",$package);
   $cmdResult = $self->{conn}->cmd(String => $cmd, Timeout => 30);
   if($cmdResult == 1 ){
      $logger->info(__PACKAGE__ . ".verifyUnixPackage  UNIX PACKAGE VERIFIED");
   }elsif($cmdResult >= 1){
    $logger->warn(__PACKAGE__ . ".verifyUnixPackage  UNIX PACKAGE VERIFIED - PACKAGE COUNT EXCEED 1 THOUGH???");
   }else{
      $logger->warn(__PACKAGE__ . ".verifyUnixPackage  UNIX PACKAGE NOT VERIFIED");
      return 0;
   }
   return 1;
}

=head2 verifyPathExists

=over

=item DESCRIPTION:

    Method to verify specified path exists. 

=item REQUIRED:

    path

=item OPTIONAL:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=item Example:

    if($obj->verifyPathExists("/dsi/files")){
      # Perform another task...
    }else{
      # Error handling here...
    }

  * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub verifyPathExists{
    my($self,$path)=@_;
    my(@cmdResults, $cmd, $flag);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyPathExists");
    unless($path){
     $logger->warn(__PACKAGE__ . ".verifyPathExists  ARGUMENTS MISSING.  PLEASE PROVIDE PATH TO VALIDATE");
     return 0;
    };
    $cmd = "ls -d $path";
    #$cmd = sprintf ("/usr/bin/perl -le 'print -e shift' %s",$path);
    $logger->debug(__PACKAGE__ . ".verifyPathExists   ISSUING CMD: $cmd");
    @cmdResults = $self->{conn}->cmd($cmd);
    $flag = 1;
    foreach(@cmdResults){
      if(m/no.*such.*file/i){
        $flag=0;
        $logger->warn(__PACKAGE__ . ".verifyPathExists  $_");
      }
      $logger->debug(__PACKAGE__ . ".verifyPathExists  $_");
    }
    return $flag;
}


# Root orientated routines, mounting etc...
# Unix system level functions, primarily root functionality
# Mostly for Jumpstart verification purposes

=head2 _changePassword

=over

=item DESCRIPTION:

  **** ROOT ONLY METHOD **** 
  Method to change DSI related user password.  This method is restricted to changing passwords of users: dsi, cli, rocli, and dstuser

=item REQUIRED:

    USER, PASSWORD

=item OPTIONAL:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=item Example:

    $ok = $obj->_changePassword("dsi', "dsi123"); 

    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub _changePassword {  # needs to be re-written
  my($self, $user, $pass)=@_;
  
  my($bFlag, $cmd, @results);
  
  $bFlag = 1;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "._changePassword");
  if(uc($self->{OBJ_USER}) ne 'ROOT'){
    $logger->warn(__PACKAGE__ . "._changePassword  MUST BE ROOT TO PERFORM THIS CALL");
    return 0;
  }
  unless($user && $pass){
    $logger->warn(__PACKAGE__ . "._changePassword  ARGUMENTS MISSING.  PLEASE PROVIDE USER AND PASSWORD");
    print __PACKAGE__ . "._changePassword  ARGUMENTS MISSING.  PLEASE PROVIDE USER AND PASSWORD\n";
    return 0;
  };
  $cmd = sprintf("/usr/bin/passwd %s" ,$user);
  $self->{conn}->print($cmd);
  @results = $self->{conn}->waitfor(-match => "/.*new.*password.*/i",
      				    -timeout => 5) 
  or do {
    $logger->warn(__PACKAGE__ . "._changePassword  ATTEMPT FAILED.  UNABLE TO GET NEW PASSWORD PROMPT");
    $logger->debug(__PACKAGE__ . "._changePassword  Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . "._changePassword  Session Input Log is: $self->{sessionLog2}");
    return 0;
  };
  $self->{conn}->print($pass);
  @results = $self->{conn}->waitfor(-match => "/.*re-enter.*new.*password:.*/i",
      				    -timeout => 5) 
  or do {
    $logger->warn(__PACKAGE__ . "._changePassword  ATTEMPT FAILED.  UNABLE TO GET PASSWORD CONFIRMATION PROMPT");
    $logger->debug(__PACKAGE__ . "._changePassword  Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . "._changePassword  Session Input Log is: $self->{sessionLog2}");
    return 0;
  };
  $self->{conn}->print($pass);
  @results = $self->{conn}->waitfor(-match => "/.*passwd.*password.*successfully.*changed.*for.*$user.*/i",
      				    -timeout => 5)
  or do {
    $logger->warn(__PACKAGE__ . "._changePassword  ATTEMPT FAILED.  UNABLE TO GET PASSWORD CHANGE CONFIRMATION");
    return 0;
  };
  $logger->info(__PACKAGE__ . "._changePassword  PASSWORD SUCCESSFULLY CHANGED FOR USER: $user");
  return 1;
}

=head2 _reboot

=over

=item DESCRIPTION:

    Routine to reboot unix system

=item REQUIRED:

    None

=item OPTIONAL:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=item Example:

    $ok = $obj->_reboot();

    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub _reboot {
  my($self)=@_;
  my($bFlag, @results);
  $bFlag = 0;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . "._REBOOT");
  if($self->{OBJ_PORT} > 2000){
    $logger->info(__PACKAGE__ . "._REBOOT [$self->{TYPE}:$self->{OBJ_HOST}:$self->{OBJ_PORT}] Rebooting [$self->{OBJ_HOST}:$self->{OBJ_PORT} host: ], coming back in 120 ticks");
    my $cmd = "reboot -- -r";   # reboot with -r for rediscovery (doesn't hurt), and solves passing in args.
    $bFlag=1;
    $self->{conn}->print($cmd);
    @results = $self->{conn}->waitfor(-match => "/login:/i",
				      -timeout => 120)
    or do {
      $logger->debug(__PACKAGE__ . "._REBOOT [$self->{TYPE}:$self->{OBJ_HOST}:$self->{OBJ_PORT}] Command result:  @results");
      &error(__PACKAGE__ . "._REBOOT REBOOT [$self->{TYPE}:$self->{OBJ_HOST}:$self->{OBJ_PORT}] REQUEST FAILED - TIME LIMIT REACHED (120)");
    };
    $logger->info(__PACKAGE__ . "._REBOOT [$self->{TYPE}:$self->{OBJ_HOST}:$self->{OBJ_PORT}] REBOOT SUCCESSFUL - SYTEM READY FOR LOGIN");
    $logger->info(__PACKAGE__ . "._REBOOT [$self->{TYPE}:$self->{OBJ_HOST}:$self->{OBJ_PORT}] ATTEMPTING TO RE-LOGIN");
    $self->login();
    ## Verify results are as expected....else change flag
  }else{
    $logger->warn(__PACKAGE__ . "._REBOOT [$self->{TYPE}:$self->{OBJ_HOST}:$self->{OBJ_PORT}] REBOOT IS AVAILABLE ONLY VIA CONSOLE SESSION");
  }
  return $bFlag;

}

=head2 mountNFS

=over

=item DESCRIPTION:

    Routine to mount NFS directory
    $cmd = sprintf("mount %s %s:%s %s",$mntOpts,$mntLoc,$mntDirFE,$mntDirNE);

=item REQUIRED:

    $mntOpts :  e.x. -o soft,intr     [mount command options]
    $mntLoc  :  e.x. 10.1.1.20        [mount location, should be reachable IP address]
    $mntDirFE:  e.x. /vol/ReleaseEng  [mount location, NFS share directory]
    $mntDirNE:  e.x. /ReleaseEng      [mounting directory on session obj (local machine)] 

=item OPTIONAL:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=item Example:

    $ok = $obj->mountNFS($mntOpts, $mntLoc, $mntDirFE, $mntDirNE);
    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut


sub mountNFS {
  my ($self,$mntOpts, $mntLoc, $mntDirFE, $mntDirNE)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".mountNFS");       
  my ($cmd,$ok);
  if(uc($self->{OBJ_USER}) ne 'ROOT'){
    $logger->warn(__PACKAGE__ . ".mountNFS  MUST BE ROOT TO PERFORM THIS CALL");
    return 0;
  }
  $cmd = sprintf("mount %s %s:%s %s",$mntOpts,$mntLoc,$mntDirFE,$mntDirNE);
  # Verify mount does not already exist
  # Verify $mntDirNE exists, if not create it
  # Attempt mount procedure  
  $self->{conn}->cmd($cmd); 
  # Verify mount has taken place
  # return whether or not mount was ok
  return 1;
}


=head2 mountReleaseEng

=over

=item DESCRIPTION:

    Routineo mount release engineering if this not already mounted

=item REQUIRED:

    hostname

=item OPTIONAL:

    None

=item RETURNS:

    1 - Success
    0 - Failure

=item Example:

    $ok = $obj->mountReleaseEng($hostname);
    * Where $obj is an object created by an inherited Package (ex: SonusQA::DSI)

=back

=cut

sub mountReleaseEng {
  my ($self,$hostname)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".mountReleaseEng");       
  if(uc($self->{OBJ_USER}) ne 'ROOT'){
    $logger->warn(__PACKAGE__ . ".mountReleaseEng  MUST BE ROOT TO PERFORM THIS CALL");
    return 0;
  }
  # Create /ReleaseEng if necessary (chmod 777) if it does not exist
  # Possibly check for subdirectory within /ReleaseEng or determine if it is already mounted
  # mount release engineering
  return $self->mountNFS("-o soft,intr","10.1.1.20","/vol/ReleaseEng","/tmp/ReleaseEng");
}


# Scratch area...

# ps -u dsi -lf   <---- user
# ps -lf | grep -i /dsi/bin/tp <---- process
# ps -u dsi -lf | grep -i /dsi/bin/tp  <--- user + process

=head2 AUTOLOAD

 This subroutine will be called if any undefined subroutine is called.

=cut

sub AUTOLOAD {
  our $AUTOLOAD;
  my $warn = "$AUTOLOAD  ATTEMPT TO CALL $AUTOLOAD FAILED (POSSIBLY INVALID METHOD)";
  if(Log::Log4perl::initialized()){
    my $logger = Log::Log4perl->get_logger($AUTOLOAD);
    $logger->warn($warn);
  }else{
    Log::Log4perl->easy_init($DEBUG);
    WARN($warn);
  }
}

1;
