#!/ats/bin/perl

use Getopt::Long; 
use Net::Telnet ();
use Net::FTP ();
use Net::SFTP ();
use Net::SSH();
#use Time::Piece;
#use Time::Seconds;
 

############################################################
# Function: copyPsxImages
# Description: This function copies PSX images from ccview 
#              to DUT. 
#    
# Arg: hostname - host where views live
#      username - generic username
#      password - generic password
#      view        - ccview where images are
#      dut         - PSX under test
# Return:
# Example copyPsxImages(slate,psxats,sonus1,V07.03.07R000;,release.ssV07.03.07R000;
############################################################
sub copyPsxImages
{
  $cc_hostname = shift;
  $username=shift;
  $password=shift;
  $view=shift;
  $dut=shift;
  my $dut_username="ssuser";
  my $dut_password="ssuser";
  my $TMP_PKG_DIR="/tmp/psxAtsImages/";
  my $getDir="/tmp/psxAtsImages/";

  ########### Images needed to install PSX #########
  my @images=qw(sonus-agents.pkg install-agent.sh uninstall-agent.sh psxInstall.sh); 

  ########### Telnet Setview and copy to tmp ############
  $t = new Net::Telnet(Timeout => 50);
  $t->open($cc_hostname);
  $t->login($username,$password);
  @lines = $t->cmd("sv -c -f ".$view);
  print @lines;
  @lines = $t->cmd("cd /software/src/policy");
  @lines = $t->cmd("ls");
  print "Remove old TMP files\n";
  @lines = $t->cmd("/bin/rm -f $TMP_PKG_DIR/*");
 
  print "Start TMP copy\n";
  @lines = $t->cmd("cp ss-*.pkg $TMP_PKG_DIR");
  foreach my $image(@images)
  {
    @lines = $t->cmd("cp $image $TMP_PKG_DIR");
  } 
  print "Copied to host($cc_hostname) $TMP_PKG_DIR \n";

  ###########  FTP from tmp to ATS  ################
  print "Start  FTP\n";
  $ftp = new Net::FTP($cc_hostname,Timeout => 20);
  $ftp->login($username,$password);
  @lines = $ftp->binary(); # set binary mode
  @lines = $ftp->cwd($getDir);
  @files = $ftp->ls ;

  foreach $line(@files) {
  if($line =~ m/ss-/)
	{
	  #print "found file\n";
           $file=$line; 
	}
  }
  
  print "$file \n";

  @lines = $ftp->get("$file","$file");
  foreach my $image(@images)
  {
    @lines = $ftp->get("$image","$image");
    print "getting $image \n"; 
  }
 
  print @lines; 
  print "\nEnd  FTP\n";
  $ftp->quit;

  ###########  SFTP ATS to DUT  ################
  print "Start  SFTP\n";
  my $sftp = Net::SFTP->new($dut,user=>$dut_username,password =>$dut_password);

  $sftp->do_remove("$file");
  print "rm $file\n";
  foreach my $image(@images)
  {
    $sftp->do_remove("$image");
    print "rm $image \n";
  }

  $sftp->put("$file","$file");
  print "put $file \n";
  foreach my $image(@images)
  {
    $sftp->put("$image","$image");
    print "put $image \n";
  }

  print "\nEND  SFTP\n";

  ########### Telnet to PSX chmod777 images  ############
  $t = new Net::Telnet(Timeout => 20);
  $t->open($dut);
  $t->login($dut_username,$dut_password);
  @lines = $t->cmd("cd /export/home/ssuser");
  print @lines;
  @lines = $t->cmd("chmod 777 *");
  @lines = $t->cmd("ls -ltr");

  print "\nEND  SFTP\n";

  return("GOOD");
}



#######################################################



#############################################
# Function: stopPsx
# Description: telnet to PSX and stop 
# Arg: PSX
# Return:
#############################################
sub stopPsx
{
  
  $psx=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";

  print "Stopping PSX application on $psx ...\n";

  $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);
  $t->login($psx_username,$psx_password);
  @lines = $t->cmd("stop.ssoftswitch");

  foreach $line(@lines) 
  {
      print "$linen";
      if($line =~ m/Done/)
      {
          print "We are done\n";
          return("STOPPED");
      }
      if($line =~ m/not running/)
      {
          print "Already Stopped\n";
          return("ALREADY"); 
      }
   }
   return("ERROR");
}

#############################################
# Function: startPsx
# Description: telnet to PSX and start 
# Arg: PSX
# Return:
#############################################
sub startPsx
{
  
  $psx=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";

  print "Starting PSX application on $psx ...\n";

  $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);
  $t->login($psx_username,$psx_password);
  @lines = $t->cmd("start.ssoftswitch \n");
  @lines = $t->cmd("ls                \n");
  print "Send cmd to n $psx ...\n";
  foreach $line(@lines) 
  {
      if($line =~ m/Started/)
      {
          print "Started PSX\n";
          return("STARTED");
      }
      if($line =~ m/Already Running/)
      {
          print "Already Started\n";
          $t->cmd("n \n");
          return("ALREADY");
      }
  }
  return("OK");
}

#############################################
# Function: getPsxVer
# Description: telnet to PSX and get version 
# Arg: PSX
# Return:
#############################################
sub getPsxVer
{
  $psx=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";

  $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);
  $t->login($psx_username,$psx_password);
  @lines = $t->cmd("pes -ver \n");

  foreach $line(@lines) 
  {
    if($line =~ m/V/)
    {
        print "$line \n";
        return($line);
    }
  }
  return("ERROR");
}


#############################################
# Function: uninstallPsx
# Description: telnet to PSX and uninstall 
# Arg: PSX
# Return:
#############################################
sub uninstallPsx
{
  
  $psx=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";

  print "Uninstall PSX application on $psx ...\n";

  $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);

  $t->login("root","sonus");
  @lines = $t->cmd(Prompt=> '/] $/',Errmode=>'return',String =>"/export/home/ssuser/SOFTSWITCH/BIN/psxUninstall.sh");
  @lines = $t->cmd(Prompt=> '/] $/',Errmode=>'return',String =>"y");
  @lines = $t->cmd(Prompt=> '/# $/',Errmode=>'return',String =>"y");  
  
  foreach $line(@lines) 
  {
      print "$line \n";  
      if($line =~ m/was successful/)
      {
          print "Uninstall was good!\n";
          return("GOOD");
      } 
 }
 return("ERROR");
}

#############################################
# Function: installPsx2
# Description: telnet to PSX and install 
# Arg: PSX
# Return:
#############################################
sub installPsx2
{
  
  $psx=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";

  print "Install2 PSX application on $psx ...\n";

  $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);
  $t->login("root","sonus");
  
  @lines = $t->cmd("cd /export/home/ssuser\n");
  @lines = $t->cmd(Prompt=> '/ $/',Timeout => 30,Errmode=>'die',String =>"./psxInstall.sh");
  print @lines;

 

  #Do you want to install these conflicting files [y,n,?,q]
  #@lines = $t->cmd(Prompt=> '/.: $/',Errmode=>'die',String =>"y"); 
  #print @lines;

  #Do you want to continue with the installation of <SONSss> [y,n,?]
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>"y"); 
  print @lines;   

  # (default: /export/home):
  @lines = $t->cmd(Prompt=> '/ $/',Errmode=>'die',String =>""); 
  print @lines;   

  #Is this value correct? (default: N) [y|Y,n|N]: y
  @lines = $t->cmd(Prompt=> '/]:? $/',Errmode=>'die',String =>"y"); 
  print @lines;   

  #Enter admin account password (default: admin):
  @lines = $t->cmd(Prompt=> '/:? $/',Errmode=>'die',String =>""); 
  print @lines;  

  foreach $line(@lines) 
  {
      print "$line \n";
      if($line =~ m/Starting sonusAgent/)
      {
          print "Started PSX AGENT\n";
           $t->close;
          return("STARTED");
      }
  }
  $t->close;
  return("DONE");
}
#############################################
# Function: installPsx
# Description: telnet to PSX and install 
# Arg: PSX
# Return:
#############################################
sub installPsx
{
  
  $psx=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";

  print "Install PSX application on $psx ...\n";

  $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);
  $t->login("root","sonus");
  
  @lines = $t->cmd("cd /export/home/ssuser\n");
  @lines = $t->cmd(Prompt=> '/ $/',Timeout => 30,Errmode=>'die',String =>"./psxInstall.sh");
  print @lines;

  #Host Name (default: arctic)...........: 
  @lines = $t->cmd(Prompt=> '/: $/',Errmode=>'die',String =>""); 
  print @lines;

  #Ip Address (default: 10.6.30.155)...........: 
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>""); 
  print @lines;

  #Are the values correct (default:N) [y|Y,n|N] ? y
  @lines = $t->cmd(Prompt=> '/.: $/',Errmode=>'die',String =>"y"); 
  print @lines;

  #User Name (default: ssuser) ..........................................: 
  @lines = $t->cmd(Prompt=> '/ $/',Errmode=>'die',String =>""); 
  print @lines;

  #Group Name (default: ssgroup) ........................................: 
  @lines = $t->cmd(Prompt=> '/ $/',Errmode=>'die',String =>""); 
  print @lines;

  #Are the values correct (default:N) [y|Y,n|N] ? y
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>"y"); 
  print @lines; 

  #Do you want to automatically start the Sonus SoftSwitch on system startup [y|Y,n|N] ? y
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>"y"); 
  print @lines; 

  #Do you want to automatically stop the Sonus SoftSwitch on system shutdown [y|Y,n|N] ? y
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>"y"); 
  print @lines;

  #Base Directory (default: /export/home/ssuser)...........:
  @lines = $t->cmd(Prompt=> '/ $/',Errmode=>'die',String =>""); 
  print @lines;    
 
  #Is the value correct (default:N) [y|Y,n|N] ?
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>"y"); 
  print @lines;   

  #Do you want to continue with the installation of <SONSss> [y,n,?]
  @lines = $t->cmd(Prompt=> '/]? $/',Errmode=>'die',String =>"y"); 
  print @lines;   

  # (default: /export/home):
  @lines = $t->cmd(Prompt=> '/ $/',Errmode=>'die',String =>""); 
  print @lines;   

  #Is this value correct? (default: N) [y|Y,n|N]: y
  @lines = $t->cmd(Prompt=> '/]:? $/',Errmode=>'die',String =>"y"); 
  print @lines;   

  #Enter admin account password (default: admin):
  @lines = $t->cmd(Prompt=> '/:? $/',Errmode=>'die',String =>""); 
  print @lines;  

  foreach $line(@lines) 
  {
      print "$line \n";
      if($line =~ m/Starting sonusAgent/)
      {
          print "Started PSX AGENT\n";
           $t->close;
          return("STARTED");
      }
  }
  $t->close;
  return("DONE");
}

#############################################
# Function: switchPsxDb
# Description: telnet to PSX and switchDbs
# Arg: PSX, Version
# Return:
#############################################
sub switchPsxDb
{ 
  $psx=shift;
  $version=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";
  my $oracle_username="oracle";
  my $oracle_password="oracle";
  my $root_username="root";
  my $root_password="sonus";

  print "Switch $psx 's DB to  $version..\n";

  print "Change profile Start \n";
  $o = new Net::Telnet(Timeout => 20);
  $o->open($psx);
  $o->login($oracle_username,$oracle_password);
  if($version =~ m/V07.03/)
  {
      @lines = $o->cmd("cp .profile.SIT73DB .profile");
  }
  elsif($version =~ m/V08.02/)
  {
      @lines = $o->cmd("cp .profile.SIT82DB .profile");
  }
  elsif($version =~ m/V08.03/)
  {
      @lines = $o->cmd("cp .profile.SIT83DB .profile");
  }
  else
  {
     print "Unknown Version\n";
     return("ERROR");
  }
  $o->close;
   print "Change profile End \n";


  $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);
  $t->login($psx_username,$psx_password);
  @lines = $t->cmd("cd /export/home/ssuser/\n");
  if($version =~ m/V07.03/)
  {
      @lines = $t->cmd("cp .cshrc.SIT73DB .cshrc");
  }
  if($version =~ m/V08.02/)
  {
      @lines = $t->cmd("cp .cshrc.SIT82DB .cshrc");
  }
  if($version =~ m/V08.03/)
  {
      @lines = $t->cmd("cp .cshrc.SIT83DB .cshrc");
  }

  @lines = $t->cmd("cd /export/home/ssuser/SOFTSWITCH/SQL \n");
  @lines = $t->cmd("chmod777 * \n");
  @lines = $t->cmd(Prompt=> '/% $/',String =>"rm -f /export/home/ssuser/SOFTSWITCH/SQL/MigrateDb"); 
  @lines = $t->cmd(Prompt=> '/% $/',String =>"rm -f /export/home/ssuser/SOFTSWITCH/SQL/UpdateDb"); 
  if($version =~ m/V07.03/)
  {
      @lines = $t->cmd(Prompt=> '/% $/',String =>"cp /export/home/ssuser/MigrateDb.SIT73DB /export/home/ssuser/SOFTSWITCH/SQL/MigrateDb"); 
      @lines = $t->cmd(Prompt=> '/% $/',String =>"cp /export/home/ssuser/UpdateDb.SIT73DB /export/home/ssuser/SOFTSWITCH/SQL/UpdateDb");
      @lines = $t->cmd(Prompt=> '/% $/',String =>"ls");          
  }
  elsif($version =~ m/V08.02/)
  {
     @lines = $t->cmd(Prompt=> '/% $/',String =>"cp /export/home/ssuser/MigrateDb.SIT82DB MigrateDb"); 
     @lines = $t->cmd(Prompt=> '/% $/',String =>"cp /export/home/ssuser/UpdateDb.SIT82DB UpdateDb");
     @lines = $t->cmd(Prompt=> '/% $/',String =>"ls");      
  }
  elsif($version =~ m/V08.03/)
  {
     @lines = $t->cmd(Prompt=> '/% $/',String =>"cp /export/home/ssuser/MigrateDb.SIT83DB MigrateDb"); 
     @lines = $t->cmd(Prompt=> '/% $/',String =>"cp /export/home/ssuser/UpdateDb.SIT83DB UpdateDb");
     @lines = $t->cmd(Prompt=> '/% $/',String =>"ls");      
  }
  else
  {
     print "Unknown Version\n";
     $t->close;
     return("ERROR");
  }

   $t->close;
   print "Change Update - end\n";

  print "Start Update";
  $u = new Net::Telnet(Timeout => 20);
  $u->open($psx);
  $u->login($root_username,$root_password);
  @lines = $u->cmd(Prompt=>'/# $/',String =>"cd /export/home/ssuser/SOFTSWITCH/SQL");
  @lines = $u->cmd(Prompt=>'/ $/',String =>"./UpdateDb");
  print @lines;
  @lines = $u->cmd(Prompt=>'/ $/',String =>"y");
  print @lines;
  $u->close;
  print "Change profile End";

  return("DONE");
}

#############################################
# Function:patchSsreqCli
# Description: telnet to PSX and patch 
# ssreqCLI. Needed until fix is back ported
# Arg: 
# Return:
#############################################
sub patchSsreqCli
{
  
  $psx=shift;
  my $psx_username="ssuser";
  my $psx_password="ssuser";

  print "Patch SSREQCLI on $psx ...\n";

  $t = new Net::Telnet(Timeout => 20);
  $t->open($psx);
  $t->login($psx_username,$psx_password);
  @lines = $t->cmd(Prompt=> '/% $/',,String =>"cd /export/home/ssuser/SOFTSWITCH/BIN/");
  @lines = $t->cmd(Prompt=> '/% $/',Errmode=>'return',String =>"rm -f ssreqCLI");  
  @lines = $t->cmd(Prompt=> '/% $/',Errmode=>'return',String =>"cp /export/home/ssuser/ssreqCLI.ind5 ssreqCLI");  
  @lines = $t->cmd(Prompt=> '/% $/',Errmode=>'return',String =>"cp /export/home/ssuser/ssreqCLI.jar.ind5 ssreqCLI.jar"); 
  @lines = $t->cmd(Prompt=> '/% $/',Errmode=>'return',String =>"chmod 777 ssreqCLI");
  $t->close;

 return("DONE");
}


#############################################
# Function: installPsxImages
# Description: main function to perform all 
#    the steps needed to install PSX Images
# Arg: PSX,VERSION
# Return:
#############################################
sub installPsxImages
{ 
  $psx=shift;
  $version=shift;
  #$version = "release.ssV07.03.07R000";
  #$version = "release.ssV08.02.00R000";
  my $status ="ERROR";

   $status=stopPsx($psx);
  print "\n stop_status is $status \n"; 

   $status=uninstallPsx($psx);
  print "\n Uninstall_status is $status \n"; 

   $status=installPsx($psx);
  print "\n Install_status is $status\n"; 

   $status=switchPsxDb($psx,$version);
  
  if($status eq "ERROR")
  {
   print " \n switchPsxDb FAILED - Stopping PSX INSTALL !!!\n";
    return($status);
  }

  $status=startPsx($psx);
  print " \n StartPsx status is $status \n";

  $status=getPsxVer($psx);
  print " \n PSX version is $status\n";

   $status=patchSsreqCli($psx);
  print " \n PSX ssreq patch is $status\n";

 return($status);
}

########################
# Help info
########################

my $usage_string = "    Usage:  atsInstallPsx  -psx <psx>,-ver <version> ,-ccview <ccview>, -loc <W,I,N,U>";

my $help_string = q{
    atsInstallPsx 

}.$usage_string. q{

    Options:
        -psx       Specify cc view to test 
        -ver       version of images to test
        -ccview    Specify cc view where images are located
        -loc       Location of ccview (W,I,N,U) Westford,India,NJ,UK
        -usr       username of account where files will be copied to
        -pass      password of  username above

        --help          Print this summary
        --usage         Print the usage line 

};

sub usage {
    # Print this if user needs a little help...
    die "$usage_string\n\n";
}

sub help {
    # Print this if user needs a little more help...
    die "$help_string";
}

sub handleControlC {
    print "\nOh my God, you killed Kenny\n\n";
    exit;
}
$SIG{INT} = \&handleControlC;

########################
# Read CMD LINE options
########################

GetOptions (
    "-psx=s"     => \$psx,
    "-ver=s"     => \$ver,
    "-ccview=s"     => \$ccview,
    "-loc=s"     => \$loc, 
    "-usr=s"     => \$uname,
    "-pass=s"     => \$upass,
    "usage"     => \&usage,
    "help"      => \&help
) or help; 


#######################
# main
#######################
#atsInstallPsx psx,version,ccview, location of view (W,I,N,U)
#example atsInstallPsx.pl -psx arctic -ver V07.03.07R00 -ccview release.ssV07.03.07R000 -loc W
my $startTime=localtime;
#$user="psxats";
#$pass="sonus1";

if($loc eq 'W')
{
   print"Westford Location \n"; 
    $host ="slate"; 
}
elsif($loc eq 'I')
{
    print"India Location \n"; 
    $host ="water"; 
}
elsif($loc eq 'N')
{
    print"NJ Location  - Currently not supported using Westford\n"; 
    $host ="slate"; 
}
elsif($loc eq 'U')
{
    print"UK Location  - Currently not supported using Westford\n"; 
    $host ="slate"; 
}
else
{
 print"Unknown Location \n";
 $host ="slate"; 
}


print "START COPYING PSX IMAGES \n";
$status=copyPsxImages($host,$uname,$upass,$ccview,$psx);
print "CopyImages Status -> $status from $ARGV[3]\n"; 

$status=installPsxImages($psx,$ver);
print " \n installPsxImages is $status\n";
#my $endTime=localtime;
#my $totalTime=$endTime-$startTime;
print " \n Total time to copy and install ==> $totalTime\n";
