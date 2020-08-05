use strict;
use warnings;


=head1 NAME

launchBISTQ.pl - Perl file for launching BISTQ Installation.

=head1 DESCRIPTION

    This file takes complete build file path as argument as given below, 
    perl launchBISTQ.pl /sonus/ReleaseEng/Images/SBX5000/sbc-V05.00.00-A040.x86_64.tar.gz CONFIG.pm </sonus/ReleaseEng/Images/EPX/V09.03.00R000/ePSX-V09.03.00R000.ova> 
 
    Creates a Time stamp based Directory on ATS Server and copies the CONFIG.pm to that directory
    changes the current directory to the newly created directory on ATS Server and launches STARTBISTQAUTOMATION 
    with CONFIG.pm, buildserverIpAdd and buildPath as arguments as below,

    ssh $atsServer "cd $dir; nohup /ats/bin/perl -I /home/$usrName/ats_repos/lib/perl /home/$usrName/ats_repos/lib/perl/SonusQA/BISTQ/STARTBISTQAUTOMATION $dir/CONFIG.pm $buildserverIpAdd $build > /dev/null &"`     

=head2 METHODS

=cut

if(@ARGV < 2){
    print "ERROR: Insufficient arguments.\n\n";
    print "Usage: perl launchBISTQ.pl <build file (.tar.gz|.iso)> <CONFIG.pm> [ePSX build (.ova)] \n\n";
    exit;
}


my $build = $ARGV[0];
my $config = $ARGV[1];
my $epsx_build = $ARGV[2];
my ($tempPath,$buildPath,$exitStatus,$dir,%configValues,$location,%locToAts,$buildServer,$atsServer,$usrName,$getIp,$buildserverIpAdd,@ipResult,$hash);

unless (-e $build){
	print "ERROR: build file, $build doesn't exist.\n";
	exit;
}

if($build =~ /(.*)\.tar\.gz$/){
    $buildPath = $1 ;
    unless((-e "$buildPath.md5") or (-e "$buildPath.sha256")){
        print"ERROR: $buildPath.md5 or $buildPath.sha256 file doesn't exist in build location.\n";
        exit;
    }
    $hash = (-e "$buildPath.md5") ? 'md5' : 'sha256';
    `cp $buildPath.$hash /sonus/ReleaseEng/Images/SBX5000/BISTQ/`;
}
elsif($build=~ /(.*)\.iso$/){
    $buildPath = $1 ;
    unless((-e "$buildPath.iso.md5") or (-e "$buildPath.iso.sha256")){
        print"ERROR: $buildPath.iso.md5 or $buildPath.iso.sha256 file doesn't exist in build location.\n";
        exit;
    }
    $hash = (-e "$buildPath.iso.md5") ? 'md5' : 'sha256';
    `cp $buildPath.iso.$hash /sonus/ReleaseEng/Images/SBX5000/BISTQ/`;
}
elsif($build !~/\.(iso|qcow2)$/){
    print "ERROR: Given build file, $build is not .tar.gz or .iso or .qcow2 file\n";
    exit;
}

print "Copying $build to /sonus/ReleaseEng/Images/SBX5000/BISTQ/\n";
`mkdir -p /sonus/ReleaseEng/Images/SBX5000/BISTQ`;
`cp $build /sonus/ReleaseEng/Images/SBX5000/BISTQ/`;
if($build =~/.*\/(.*\.tar\.gz|.*iso)$/){
    $tempPath ="/sonus/ReleaseEng/Images/SBX5000/BISTQ/$1";
}
$build = $tempPath;
unless (-e $build){
        print "ERROR: build file, $build doesn't exist.\n";
        exit;
}

unless(-e $config){
    print"ERROR: CONFIG.pm file doesn't exist.\n";
    exit;
}

if(defined $epsx_build && not -e $epsx_build){
    print "ERROR: ePSX build, $epsx_build doesn't exist.\n";
    exit;
}

$dir = `date +"%d%m%y_%H%M%S"`;
chomp($dir);
$dir = $dir."$$";

my $testbed = `grep "testbedAlias" $config`;
if($testbed =~ /.*\"(IN_.*|WF_.*)\".*/){
    $configValues{'testbedAlias'}=$1;
}else{
    print"ERROR: Unable to read testbedAlias.\n";
    exit;
}
$location = $1 if($configValues{'testbedAlias'} =~ /(\w{2})_.*/);
%locToAts = ('WF'=>'wfats3','IN'=>'bats12'); 

$buildServer = `hostname`;
chomp($buildServer);
$atsServer = $locToAts{$location};

$usrName = `whoami`;
chomp($usrName);

print "date Value: $dir\n";
$dir =  "/home/$usrName/ats_user/logs/$configValues{'testbedAlias'}/BISTQ/Temp_Sanity".$dir;
print "DIR: $dir\n";
`ssh -o StrictHostKeyChecking=no $atsServer "mkdir -p $dir "`;
print "Created directory $dir\n";

print "Copying the CONFIG.pm to ATS server\n";
`scp $config $atsServer:$dir/CONFIG.pm`;
    print "Copied $dir/CONFIG.pm to ATS server \n";

$getIp = `/sbin/ifconfig -a`;
@ipResult = split (/\n/,$getIp);
foreach(@ipResult){
    if($_ =~ /inet addr:(.*)\s+Bcast/){
        $buildserverIpAdd = $1;
        last;
    }elsif($_ =~ /inet (.*)\s+netmask.*broadcast /){
        $buildserverIpAdd = $1;
        last;
    }
}
unless(defined $buildserverIpAdd){
    print "ERROR: BuildServer IP could not be determined\n";
    exit;
}
$buildserverIpAdd=~s/\s//g;

if(!$epsx_build) { # Our ARGV[2] was undefined - and this this is too - set it to empty string to avoid 'use of uninitialized var warnings in ssh/print string concats below
    $epsx_build="";
}

print "Running STARTBISTQAUTOMATION on ATS Server\n";
print "ssh -o StrictHostKeyChecking=no $atsServer \"cd $dir; /ats/bin/perl -I $dir  /home/$usrName/ats_repos/lib/perl/SonusQA/BISTQ/STARTBISTQAUTOMATION $dir/CONFIG.pm $buildserverIpAdd $build $epsx_build\"\n"; 
`ssh -o StrictHostKeyChecking=no $atsServer "cd $dir; /ats/bin/perl -I $dir  /home/$usrName/ats_repos/lib/perl/SonusQA/BISTQ/STARTBISTQAUTOMATION $dir/CONFIG.pm $buildserverIpAdd $build $epsx_build"`;


print "End\n";
