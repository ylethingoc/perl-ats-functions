package SonusQA::TOOLS::TOOLSHELPER;

=head1 NAME

SonusQA::TOOLS::TOOLSHELPER class

=head1 SYNOPSIS

use SonusQA::TOOLS::TOOLSHELPER;

=head1 DESCRIPTION

SonusQA::TOOLS::TOOLSHELPER provides a TOOLS infrastructure on top of what is classed as base TOOLS functions. 

=head1 AUTHORS

Ramesh Pateel (rpateel@sonusnet.com)

=cut

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
require SonusQA::SBX5000::PERFHELPER;
use DBI;
#use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use Data::Dumper;
use File::Path qw(mkpath);
use File::Basename;
use POSIX qw(strftime);

=head2 cleanup_map()

    This function reverts the map configurations on SAPRO to its defaults state
                 - reverts back the map configuration to the default tcl,var,SSH,Telnet,Netconf,xmf and cmf files based on the device type
                 - By default GSX is assumed as the device type 
                 - validates the revert process

=over

=item Arguments:

    Hash with below deatils
          - Manditory
                -mapSequence   => sequence of the maps to perform cleanup on e.g., EMSPET1
          - Optional
                -deviceType  => Type of devices.The options are GSX|SBC5K|SBC1K .By default this takes GSX

=item Return Value:

    1 - on success
    0 - on failure

=item Usage:
    my %args = (-mapSequence => "EMSPET1" );

    my $result = $Obj->cleanup_map(%args);

=back

=cut

sub cleanup_map {
    my($self, %args)=@_;
    my $sub = "cleanup_map";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
    my @fileNames = ('ModelingFile','MibFile','AgentFile','NetconfModFile','SoapModFile','SSHFile','TelnetFile');
    my $deviceType = (defined $args{-deviceType}) ? uc($args{-deviceType}):'GSX';
    my @cmdResult = ();
    my ($result,$numberOfDevices) = (1,0);

    foreach ('-mapSequence') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }

    if ( $deviceType !~ m/(GSX|SBC5K|SBC1K)/) {
        $logger->error(__PACKAGE__ . ".$sub: The -deviceType can be GSX|SBC5K|SBC1K.For SBC7K/Swe use SBC5K and that of SBC2K use SBC1K");
        return 0;
    }


    #Setting the deault files for various device types
    my %defaultFiles = (
        'GSX' => {
            'ModelingFile' => 'default.tcl',
            'MibFile' => 'default.cmf',
            'AgentFile' => 'default.var',
            'NetconfModFile' => "$self->{BASEPATH}/netconf/default.ncf",
            'SoapModFile' => "$self->{BASEPATH}/xml/default.xmf",
            'SSHFile'=> "$self->{BASEPATH}/telnet/new.tel",
            'TelnetFile' => "$self->{BASEPATH}/telnet/new.tel"
        },
                
        'SBC5K' => {
            'ModelingFile' => 'defaultSbc5k.tcl',
            'MibFile' => 'defaultSbc5k.cmf',
            'AgentFile' => 'defaultSbc5k.var',
            'NetconfModFile' => "$self->{BASEPATH}/netconf/defaultSbc5k.ncf",
            'SoapModFile' => "$self->{BASEPATH}/xml/defaultSbc5k.xmf",
            'SSHFile'=> "$self->{BASEPATH}/telnet/sbx5k.tel",
            'TelnetFile' => "$self->{BASEPATH}/telnet/sbx5k.tel"
        },

        'SBC1K' => {
            'ModelingFile' => 'defaultSbc1k.tcl',
            'MibFile' => 'defaultSbc1k.cmf',
            'AgentFile' => 'defaultSbc1k.var',
            'NetconfModFile' => "$self->{BASEPATH}/netconf/defaultSbc1k.ncf",
            'SoapModFile' => "$self->{BASEPATH}/xml/defaultSbc1k.xmf",
            'SSHFile'=> "$self->{BASEPATH}/telnet/sbx5k.tel",
            'TelnetFile' => "$self->{BASEPATH}/telnet/sbx5k.tel"
        }
    );
    #deleting the PM files incase if present as it takes huge time for sapor to delete
    my $cmd = "unalias rm ";
    $self->execCmd("$cmd",3600);
    $cmd = ' rm -rf /export/home/SonusNFS/' . "$args{-mapSequence}*";
    $logger->debug(__PACKAGE__ . ".$sub: The Sapro commnad is :$cmd");
    $self->execCmd("$cmd",3600) ;

    $self->{conn}->cmd("cd $self->{BASEPATH}/map");

    #Counting Number of devices in the MAP
    $cmd = "grep  -i TopologyData $self->{BASEPATH}/map/$args{-mapSequence}" . "_*.map | wc -l ";
    unless ( @cmdResult = $self->execCmd($cmd) ) {
        $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while counting the Number of devices for map sequence $args{-mapSequence} : " . Dumper(\@cmdResult));
        return 0;
    } else {
        if ( grep(/No such file or directory/, @cmdResult))  {
            $logger->error(__PACKAGE__ . ".$sub: The $args{-mapSequence} file doesn't exists: ". Dumper(\@cmdResult));
            return 0;
        } else {
            $numberOfDevices = $cmdResult[0];
            $logger->debug(__PACKAGE__ . ".$sub: Successfully found the number of devices for sequence $args{-mapSequence} : $numberOfDevices ");
        } 
    }
    foreach my $fileType (@fileNames) {
        #Updating the files
        $cmd = 'perl -pi -e \'s|(' . $fileType . '[\s]*=[\s]*)(.*)|$1"' . $defaultFiles{$deviceType}{$fileType} . "\"|g' " . $args{-mapSequence} . "_*.map" ;
        @cmdResult = $self->execCmd("$cmd",60); 
        if(grep(/No.*such.*file*/i, @cmdResult)) {
            $logger->error(__PACKAGE__ . "$sub: Command Execution failed with error $cmdResult[0] for filetype [$fileType] and cmd is $cmd");
            return 0;     
        } else {
            $logger->debug(__PACKAGE__ . ".$sub: Successfully executed the sed/file edit cmd for filetype [$fileType] and the command is [$cmd]"); 
        }
        #Checking if all the Devices are updated
        $cmd  = "grep -i \"$fileType.*=.*$defaultFiles{$deviceType}{$fileType}\" $args{-mapSequence}" . "_*.map | wc -l";
        unless (@cmdResult = $self->execCmd("$cmd",60)) {
            $logger->error(__PACKAGE__ . "$sub For filetype [$fileType] , execCmd failed and cmd is $cmd" . Dumper(\@cmdResult));
            $result = 0;
        } else {
            if(grep(/No.*such.*file*/i, @cmdResult)) {
                $logger->error(__PACKAGE__ . "$sub: Command Execution failed with error $cmdResult[0] for filetype [$fileType] and cmd is $cmd");
                return 0;    
            } else {
                if ($cmdResult[0] == $numberOfDevices) {
                    $logger->debug(__PACKAGE__ . ".$sub: Successfully updated for filetype [$fileType] for all the $numberOfDevices devices"); 
                } else {
                    $logger->error(__PACKAGE__ . "$sub: All the devices in the map file are not updated properly for filetype [$fileType]");
                    $result = 0; 
                }
            }
        }
      
    }
    return $result;
}

=head2 update_map()

    This function updates the map configurations on SAPRO with the specifed particulars
                 - updates the specified map with the specified tcl,var,cmf,telnet,SSH,Soap,netconf file for the given number of devices starting from the  start device
                 - validates the update process

=over

=item Arguments:

    Hash with below deatils
          - Manditory
                -mapName   => map to be updated
                -numberOfDevices => number of devices to be updated starting from the first device
         - Optional
                -tcl       => tcl file name
                -var       => var file name
                -cmf       => cmf file name
                -startDevice => Sequence number of the device from which the files will be updated till the -numberOfDevices. Default is 1
                -xmf         => soap file name
                -ncf         => netconf file name
                -tel         => Telnet and SSH file name. The same will be used for both
=item Return Value:

    1 - on success
    0 - on failure

=item Usage:
    my %args = (-mapName => 'EMSPET1_02_1',
                -numberOfDevices => '49',
                -tcl => 'snmp',
                -var => 'var',
                -cmf => 'cmf'
                -xmf => 'test'
                );

    my $result = $Obj->update_map(%args);

=back

=cut

sub update_map {
    my($self, %args)=@_;
    my $sub = "update_map";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
    my $cmd = '';
    my @cmdResult = ();
    my ($result) = (1);

    foreach ('-mapName', '-numberOfDevices') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }

    my $startDevice = ( defined $args{-startDevice} ) ? $args{-startDevice}:1;
    my $endDevice = $args{-numberOfDevices} + $startDevice - 1 ;
    #Updating the hash with the given arguments
    my %listOfFiles;
    $listOfFiles{'ModelingFile'} ="$args{-tcl}.tcl" if (defined $args{-tcl});
    $listOfFiles{'MibFile'} ="$args{-cmf}.cmf" if (defined $args{-cmf});
    $listOfFiles{'AgentFile'} = "$args{-var}.var" if (defined $args{-var});
    $listOfFiles{'NetconfModFile'}="$self->{BASEPATH}/netconf/$args{-ncf}.ncf" if (defined $args{-ncf});
    $listOfFiles{'SoapModFile'} = "$self->{BASEPATH}/xml/$args{-xmf}.xmf" if (defined $args{-xmf});
    $listOfFiles{'SSHFile'} = "$self->{BASEPATH}/telnet/$args{-tel}.tel" if (defined $args{-tel});
    $listOfFiles{'TelnetFile'} = "$self->{BASEPATH}/telnet/$args{-tel}.tel" if (defined $args{-tel});

    #updating the map files
    $self->execCmd("cd $self->{BASEPATH}/map/");
    foreach my $key  ( keys%{listOfFiles}) {
        my ($startLine,$endLine) = (0,0);
        #Finding the starting line number
         $cmd = "cat -n $args{-mapName}.map | grep \"$key\" | head -$startDevice | tail -1 | awk '{print \$1}'";
         unless ( @cmdResult = $self->execCmd($cmd) ) {
             $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while finding the starting line number in $args{-mapName}.map for file type $key  : " . Dumper(\@cmdResult));
             return 0;
         } else {
             if ( grep(/No such file or directory/, @cmdResult))  {
                 $logger->error(__PACKAGE__ . ".$sub: The $args{-mapName}.map file doesn't exists: ". Dumper(\@cmdResult));
                 return 0;
             } else {
                 $startLine = $cmdResult[0];
                 $logger->debug(__PACKAGE__ . ".$sub: Successfully found the start line number for file type $key in $args{-mapName}.map : $startLine ");
             }   
        } 
        #Finding the end line number 
        $cmd = "cat -n $args{-mapName}.map | grep \"$key\" | head -$endDevice | tail -1 | awk '{print \$1}'";
        unless ( @cmdResult = $self->execCmd($cmd) ) {
             $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while finding the end line number in $args{-mapName}.map for file type $key : " . Dumper(\@cmdResult));
             $result = 0;
         } else {
             $endLine = $cmdResult[0];
             $logger->debug(__PACKAGE__ . ".$sub: Successfully found the end line number for file type $key in $args{-mapName}.map : $startLine ");
        }
        #updating the files
        $cmd = 'perl -pi -e \'s|(' . $key . '[\s]*=[\s]*)(.*)|$1"' . $listOfFiles{$key} . "\"|g if (\$. >= $startLine && \$. <= $endLine )' " . "$args{-mapName}.map" ;
        @cmdResult = $self->execCmd($cmd) ;
        $logger->debug(__PACKAGE__ . ".$sub: Successfully executed the sed/file edit cmd for file type  $key in map $args{-mapName}.map and the cmd is [$cmd]");
        #verifying the updated count
        $cmd = "grep -c \"$key.*=.*$listOfFiles{$key}\" $args{-mapName}.map";
        unless ( @cmdResult = $self->execCmd($cmd) ) {
             $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while checking updated file $args{-mapName}.map  for file type $key : " . Dumper(\@cmdResult));
             $result = 0;
         } else {
             if ($cmdResult[0] == $args{-numberOfDevices} ) {  
                $logger->debug(__PACKAGE__ . ".$sub: Successfully verfied updated the file type  $key in map $args{-mapName}.map");
             } else {
                $logger->error(__PACKAGE__ . "$sub: Updated record count is $cmdResult[0] against the expected $args{-numberOfDevices} for file type $key");
                $result = 0 ;
             }
        }
    }
    return $result;

}

=head2 start_map()

    This function starts the specified maps on SAPRO
                - Stops & Starts the given Maps 
                - validates the startng of maps
                - Then tries once more for the failed devices. Even if one device fails to start , return 0

=over

=item Arguments:

    Hash with below deatils
          - Mandtory
                -mapName => Array of MAP names
=item Return Value:

    1 - on success
    0 - on failure

=item Usage:
    my %args = (-mapName => ['EMSPET1_02','EMSPET1_03']);

    my $result = $Obj->start_map(%args);

=back

=cut

sub start_map {
    my($self, %args)=@_;
    my $sub = "start_map";
    my $cmd_staus=0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");

    foreach ('-mapName') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return $cmd_staus;
        }
    }

    
    my @allmapnames = @{$args{'-mapName'}};
    #For every Map defined start the MAP
    foreach (@allmapnames) {
    my $map_name = $_.".map";
    my ($cmd,@r,$running_count,$Number_of_devices);

    #Counting Number of devices in the MAP
    $cmd = "grep -c TopologyData $self->{BASEPATH}/map/$map_name";
    unless ( @r= $self->execCmd($cmd) ) {
    $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while counting the Number of devices in $map_name : " . Dumper(\@r));
    return $cmd_staus;
    }
    if ( grep(/No such file or directory/, $r[0]))  {
    $logger->error(__PACKAGE__ . ".$sub: The $map_name file doesn't existss: ". Dumper(\@r));
    return $cmd_staus;
    } else {
   $Number_of_devices = $r[0];
   }

   #Stopping the MAP first
   $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$map_name -c stop ";
   $logger->debug(__PACKAGE__ . ".$sub: The sapro  cmd is $cmd");
   unless ( @r = $self->execCmd("$cmd",300) ) {
   $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while stoping the device $map_name : " . Dumper(\@r));
   return $cmd_staus;
   }
   sleep 30;

   #Starting the Map
    $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$map_name -c start";
    $logger->debug(__PACKAGE__ . ".$sub: The sapro  cmd is $cmd");
    unless ( @r = $self->execCmd("$cmd",300) ) {
    $logger->error(__PACKAGE__ . "$sub The sapro command execution failed, while starting the device $map_name : " . Dumper(\@r));
    return $cmd_staus;
    }
    sleep 30;
        
    #Counting the number of started Devices
    $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$map_name -c devlist| grep \"[0-9].*R \" |wc -l";
    unless ( @r= $self->execCmd("$cmd",3600) ) {
    $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while checking the status $map_name : " . Dumper(\@r));
    return $cmd_staus;
    }
   $running_count=$r[0];        
   #Comapring the Number of devices and number of started devices
   if ( $Number_of_devices eq $running_count) {
                $logger->debug(__PACKAGE__ . ".$sub: $running_count Devices are started in $map_name");
                } else {
                $logger->debug(__PACKAGE__ . ".$sub: $($Number_of_devices - $running_count) devices not started $map_name");
                $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$map_name -c devlist | grep \"[0-9a-f]*/.*/[0-9]*\" | grep -v  \"[0-9].*R \"  | cut -f1 -d '/'";
                unless ( @r= $self->execCmd("$cmd",300) ) {
                $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while checking the status $map_name : " . Dumper(\@r));
                return $cmd_staus;
                }
                foreach (@r) {
                $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$map_name -c startdev -d $_";
                $logger->info(__PACKAGE__ . "$sub Starting again the Device with ip $_ in $map_name");
                $self->execCmd("$cmd",300);
                }
                #Counting the number of started Devices
                $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$map_name -c devlist| grep \"[0-9].*R \" |wc -l";
                unless ( @r= $self->execCmd("$cmd",300) ) {
                $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while checking the status $map_name : " . Dumper(\@r));
                return $cmd_staus;
                }
                $running_count=$r[0];
                if ( $Number_of_devices eq $running_count) {
                $logger->debug(__PACKAGE__ . ".$sub: $running_count Devices are started in $map_name");
                } else {
                my $Failed_devices = $Number_of_devices - $running_count;
                $logger->error(__PACKAGE__ . "$sub: $Failed_devices  devices not started in $map_name even after starting again" );
                return $cmd_staus;
                }
                }
                }
    $cmd_staus =1;
    return $cmd_staus;
}
=head2 stop_map()

    This function stops the specified maps on SAPRO
                - Stops all the maps listed in the array
                - validates the stopping of maps

=over

=item Arguments:

    Hash with below deatils
          - Manditory
                -mapName => Name of the MAP given in the form of array
=item Return Value:

    1 - on success
    0 - on failure

=item Usage:
    my %args = (-mapName => ['EMSPET1_02','EMSPET1_03'];

    my $result = $Obj->stop_map(%args);

=back

=cut

sub stop_map {
    my($self, %args)=@_;
    my $sub = "stop_map";
    my $cmd_staus = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");

    foreach ('-mapName') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }
    my @allmapnames = @{$args{'-mapName'}};
    #For every Map defined stop the MAP
    foreach (@allmapnames) {
    my $map_name = $_.".map";
    my ($cmd,@r,$running_count,$Number_of_devices);
        
    #Checking if the MAP exists & number of devices
    $cmd = "grep -c TopologyData $self->{'BASEPATH'}/map/$map_name";
    unless ( @r= $self->execCmd("$cmd",300) ) {
    $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while checking for the $map_name : " . Dumper(\@r));
    return $cmd_staus;
    }
    if ( grep(/No such file or directory/, $r[0]))  {
    $logger->error(__PACKAGE__ . ".$sub: The $map_name file doesn't existss: ". Dumper(\@r));
    return $cmd_staus;
    } else {
        $Number_of_devices = $r[0];
    }

    #Now Stopping the MAP 
   $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$map_name -c stop ";
   $logger->debug(__PACKAGE__ . ".$sub: The sapro  cmd is $cmd");
   unless ( @r = $self->execCmd("$cmd",300) ) {
   $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while stoping the devices in  $map_name : " . Dumper(\@r));
   return $cmd_staus;
   }
   sleep 30;
   #Counting the number of running Devices
    $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$map_name -c devlist| grep \"[0-9].*R \" |wc -l";
    unless ( @r= $self->execCmd("$cmd",300) ) {
    $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while checking the status $map_name : " . Dumper(\@r));
    return $cmd_staus;
    }
   $running_count=$r[0];
   if ($running_count eq 0 ) {
        $logger->debug(__PACKAGE__ . ".$sub: $Number_of_devices are Stopped successfully ");
   } else {
        $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$map_name -c devlist | grep  \"[0-9].*R \" | cut -f1 -d '/'";
        unless ( @r= $self->execCmd("$cmd",300) ) {
        $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while checking for the running devices in $map_name : " . Dumper(\@r));
        return $cmd_staus;
        }
        foreach (@r) {
        $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$map_name -c stopdev -d $_";
        $logger->info(__PACKAGE__ . "$sub Stoping the specfic Device with ip $_ in $map_name");
        $self->execCmd("$cmd",300);
        }
        #Counting the number of stopped Devices
        $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$map_name -c devlist| grep \"[0-9].*R \" |wc -l";
        unless ( @r= $self->execCmd("$cmd",300) ) {
        $logger->error(__PACKAGE__ . "$sub The sapro command execution failed , while checking the status $map_name : " . Dumper(\@r));
        return $cmd_staus;
        }
        $running_count=$r[0];
        if ($running_count eq 0 ) {
        $logger->debug(__PACKAGE__ . ".$sub:$Number_of_devices are Stopped successfully ");
        } else {
        $logger->error(__PACKAGE__ . "$sub: $running_count devices not stopped in $map_name even after stoping at the device level " );
        return $cmd_staus;
        }
     }
     }
    $cmd_staus = 1;
    return $cmd_staus;

}
=head2 start_curl()

    This function will start the PSX API Provisoning load after doing the folloiwng
        1) if {TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE} not defined , it fails
        2) if {TMS_ALIAS_DATA}->{NODE}->{1}->{IP}/{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6} not defined then {TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE} ip is read from the         system
        3) Respective EMSIP is updated in the conf file based on IPV6 flag 
        4) CLIENTS_NUM_MAX,CLIENTS_NUM_START and INTERFACE are updated based on -numClient  and {TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE}
        5) IP_ADDR_MIN is allways "client IP" + 1.IP_ADDR_MAX is "client IP" + $args{-numClient} is derived and updated
        6) Checks if any ols istance of curl loader runs for the same conf file . On true kills the same
        7) Reads the query.txt and executes the same in PSX-M DB and stores the same 
        8) Checks if the load is http/https and sets te flag. The same is used in stop_curl while reading the run.txt file
        9) Updates the registered psxname in the records.txt file
        10) Starts the load , if successfull returns the PID of curl loader

=over

=item Arguments:
    Mandatory
        1.-script_name : the name of the script  to start API load as created in CURL-LOADER server
        2.-ems_obj : EMS object (SUT)
        3.-psx : PSX object  registered in EMS 
    Optional
        1. -ipv6: y|Y  : Based on this the IPv6 will be picked from the TMS. Default is 'n' 
        2. -numClient : Number of Clients .Default is 1. 

=item Return Value:
        0 - on failure
        pid of the API load.

=item Usage:
        my @curlstart = $curlObj->start_curl( -script_name => "updateSubscriber",
                                      -ems_obj => $EmsObj,
                                      -psx => $psxobj1
                                      -ipv6 => 'y',
                                      -numClient => 10);

=back

=cut

sub start_curl {
    
    my ($self,%args) = @_;
    my $sub = "start_curl";
    my $curl_pid = '';
    my @curl_pid = ();
    my @cmd_res = ();
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $script_name = $args{-script_name};
    my $ems_obj = $args{-ems_obj};
    my $psx = $args{-psx};
    my $script_path = $self->{BASEPATH}."/".$script_name;
    $self->{'Verification_point'}->{'Curl_loader'}->{'Before_db'}=0;
    $self->{'Verification_point'}->{'Curl_loader'}->{'After_db'}=0;
    my @query = ();
    my @r = (); # generic array to store result of execmd
    my @ipaddress =();
    $args{-numClient} = (defined $args{-numClient}) ? $args{-numClient}:1;
    $args{-ipv6} = (defined $args{-ipv6}) ? $args{-ipv6}:'n';

    $logger->debug(__PACKAGE__ . ".$sub : --> Entered Sub ");
    #Checking if the {NODE}->{1}->{INTERFACE} and {NODE}->{1}->{NEXTHOP_IPV4}/{NEXTHOP_IPV6} are defined in the TMS. Else it retruns fail
    if (!defined $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE}) {
        $logger->error(__PACKAGE__ . ".$sub : unable to get {TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE} from TMS for curl load object [$self->{TMS_ALIAS_DATA}->{ALIAS_NAME}]");
        $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [0]");
        return 0 ;
     }
   
    if ($args{-ipv6} ne 'y') {
        if (!defined $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NEXTHOP_IPV4}) {
            $logger->error(__PACKAGE__ . ".$sub : unable to get {TMS_ALIAS_DATA}->{NODE}->{1}->{NEXTHOP_IPV4} from TMS for curl load object [$self->{TMS_ALIAS_DATA}->{ALIAS_NAME}]");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [0]");
            return 0 ;
        }
     } else {
        if (!defined $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NEXTHOP_IPV6}) {
            $logger->error(__PACKAGE__ . ".$sub : unable to get {TMS_ALIAS_DATA}->{NODE}->{1}->{NEXTHOP_IPV6} from TMS for curl load object [$self->{TMS_ALIAS_DATA}->{ALIAS_NAME}]");
            $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving sub [0]");
            return 0 ;
        }
    }


    foreach('-script_name' , '-ems_obj' , '-psx' ) {
        unless(defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory input $_ is missing");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }


    #The PSX name is derived from the TMS entry. So when the PSX Is registered in EMS , it should be resgistered in the same name as TMS Alias entry
    my $psx_name = $psx->{TMS_ALIAS_DATA}->{ALIAS_NAME};

   @cmd_res = $self->execCmd("head -25 $self->{'BASEPATH'}/$script_name/$script_name.conf");
   $logger->info(__PACKAGE__ . ".$sub:First few lines of the $script_name.conf before changing all the details  are " . Dumper(\@cmd_res));


    # Editing the respective conf file to have the ems ip  based on EMS IP 
    my $cmd = 'sed -ri \'15,25 s/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b\'' . "/$ems_obj->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP}/" . " $self->{'BASEPATH'}/$script_name" . "/$script_name.conf";
    $cmd = 'sed -ri \'15,25 s/\[.*\]/[' . "$ems_obj->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IPV6}" . ']/\'' .  " $self->{'BASEPATH'}/$script_name" . "/$script_name.conf" if( lc "$args{-ipv6}" eq 'y' );
    @cmd_res = $self->execCmd($cmd); 
    if(grep ( /no.*such.*file/i, @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub $self->{'BASEPATH'}/$script_name/$script_name.conf file not present");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    } else {
        $logger->info(__PACKAGE__ . ".$sub: Replaced EMS ip $ems_obj->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP} in $self->{'BASEPATH'}/$script_name/$script_name.conf file") if ( lc "$args{-ipv6}" ne 'y' );
        $logger->info(__PACKAGE__ . ".$sub: Replaced EMS ip $ems_obj->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IPV6} in $self->{'BASEPATH'}/$script_name/$script_name.conf file") if ( lc "$args{-ipv6}" eq 'y' );
    }

    #Replacing the API client details CLIENTS_NUM_MAX , CLIENTS_NUM_START , INTERFACE 
   $self->execCmd("sed -ri '1,15 s/CLIENTS_NUM_MAX[ ]*=[ ]*[0-9]*/CLIENTS_NUM_MAX = $args{-numClient}/'  $self->{'BASEPATH'}/$script_name/$script_name.conf");
   @cmd_res = $self->execCmd("grep -c \"CLIENTS_NUM_MAX = $args{-numClient}\" $self->{'BASEPATH'}/$script_name/$script_name.conf");
   if ($cmd_res[0] == 0) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to configure CLIENTS_NUM_MAX");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
   }
         
   $self->execCmd("sed -ri '1,15 s/CLIENTS_NUM_START[ ]*=[ ]*[0-9]*/CLIENTS_NUM_START = $args{-numClient}/'  $self->{'BASEPATH'}/$script_name/$script_name.conf");
   @cmd_res = $self->execCmd("grep -c \"CLIENTS_NUM_START = $args{-numClient}\" $self->{'BASEPATH'}/$script_name/$script_name.conf");
   if ($cmd_res[0] == 0) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to configure CLIENTS_NUM_START");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
   }

   $self->execCmd("sed -ri '1,15 s/INTERFACE[ ]*=[ ]*[a-zA-Z]*[0-9]*/INTERFACE = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE}/'  $self->{'BASEPATH'}/$script_name/$script_name.conf");
   @cmd_res = $self->execCmd("grep -c \"INTERFACE = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE}\" $self->{'BASEPATH'}/$script_name/$script_name.conf");
   if ($cmd_res[0] == 0) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to configure INTERFACE");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
         return 0;
   }


    if ( lc "$args{-ipv6}" ne 'y' ) {
        #Reading the CURL loader client IPV4 from TMS if defined , if not finding the same from the machine for the INTERFACE Defined
        if (defined $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{IP} ) {
            if ($self->{TMS_ALIAS_DATA}->{NODE}->{2}->{IP} =~ m /([0-9]*)\.([0-9]*)\.([0-9]*)\.([0-9]*)/i) {
                $ipaddress[0] = $4;$ipaddress[1] = $3;$ipaddress[2] = $2;$ipaddress[3] = $1;
                $logger->info(__PACKAGE__ . ".$sub: The Ipv4 address of as per the TMS is : $ipaddress[3].$ipaddress[2].$ipaddress[1].$ipaddress[0]");
            } else {
                $logger->error(__PACKAGE__ . ".$sub : The Format of ipv4 address in TMS is wrong : $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{IP}");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
                }
        } else {
            @cmd_res = $self->execCmd( "ifconfig $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE}  | grep \"inet addr:\"  ");
            if ($cmd_res[0] =~ m /inet addr:([0-9]*)\.([0-9]*)\.([0-9]*)\.([0-9]*)/i) {
                $ipaddress[0] = $4;$ipaddress[1] = $3;$ipaddress[2] = $2;$ipaddress[3] = $1;
                $logger->info(__PACKAGE__ . ".$sub: The Ipaddress of $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE}: $ipaddress[3].$ipaddress[2].$ipaddress[1].$ipaddress[0]");
            } else {
                $logger->error(__PACKAGE__ . ".$sub : Unable to fetch the ipv4 of $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE} ");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
            }    
        }
       #Setting the IP_ADDR_MIN in the file to the required ipaddress and verifying if the same is edited
       $cmd = "sed -ri '1,15 s/IP_ADDR_MIN[ ]*=[ ]*([0-9]{1,3}\.){3}[0-9]{1,3}/IP_ADDR_MIN = $ipaddress[3].$ipaddress[2].$ipaddress[1]." . eval{$ipaddress[0]+1} . " /'  $self->{'BASEPATH'}/$script_name/$script_name.conf";
       $self->execCmd("$cmd");
       $cmd = "grep -c \"IP_ADDR_MIN = $ipaddress[3].$ipaddress[2].$ipaddress[1]." . eval{$ipaddress[0]+1} . "\" $self->{'BASEPATH'}/$script_name/$script_name.conf";
       @cmd_res = $self->execCmd("$cmd");
       if ($cmd_res[0] == 0) {
          $logger->error(__PACKAGE__ . ".$sub: Failed to configure IP_ADDR_MIN");
          $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
          return 0;
       }

        #Setting the IP_ADDR_MAX in the file to the required ipaddress and verifying if the same is edited 
       $cmd = "sed -ri '1,15 s/IP_ADDR_MAX[ ]*=[ ]*([0-9]{1,3}\.){3}[0-9]{1,3}/IP_ADDR_MAX = $ipaddress[3].$ipaddress[2].$ipaddress[1]." . eval{$ipaddress[0]+$args{-numClient}} . " /'  $self->{'BASEPATH'}/$script_name/$script_name.conf";
       $self->execCmd("$cmd");
       $cmd = "grep -c \"IP_ADDR_MAX = $ipaddress[3].$ipaddress[2].$ipaddress[1]." . eval{$ipaddress[0]+$args{-numClient}} . "\" $self->{'BASEPATH'}/$script_name/$script_name.conf";
       @cmd_res = $self->execCmd("$cmd");
       if ($cmd_res[0] == 0) {
          $logger->error(__PACKAGE__ . ".$sub: Failed to configure IP_ADDR_MAX");
          $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
          return 0;
       }

      #Adding the ip route to EMS
      unless($self->IpRouteUpdate( -DestIp => "$ems_obj->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP}/32" , -Gw => "$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NEXTHOP_IPV4}"  , -Intf => $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE})) {
          $logger->error(__PACKAGE__ . ".$sub: Failed to Update the Route for $ems_obj->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP}");
          $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
          return 0;
       } else {
          $logger->info(__PACKAGE__ . ".$sub: Succeffuly added the Route for $ems_obj->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP}");
       } 
   } else {
        #Reading the CURL loader client IPV6 from TMS if defined , if not finding the same from the machine for the INTERFACE Defined
        if (defined $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{IPV6} ) {
            if ($self->{TMS_ALIAS_DATA}->{NODE}->{2}->{IPV6} =~ m /(.*):([a-f0-9]+)/i) {
                $ipaddress[0] = $2;$ipaddress[1] = $1;
                $logger->info(__PACKAGE__ . ".$sub: The Ipv6 address of as per the TMS is : $ipaddress[1]:$ipaddress[0]");
            } else {
                $logger->error(__PACKAGE__ . ".$sub : The Format of ipv6 address in  TMS is wrong : $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{IPV6}");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
                }
        } else {
            @cmd_res = $self->execCmd( "ifconfig $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE}  | grep \"inet6 addr:\"  ");
            if ($cmd_res[0] =~ m /inet6 addr:(.*):([a-f0-9]+)/i) {
                $ipaddress[0] = $2;$ipaddress[1] = $1;
                $logger->info(__PACKAGE__ . ".$sub: The Ipaddress of $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE}: $ipaddress[1]:$ipaddress[0]");
            } else {
                $logger->error(__PACKAGE__ . ".$sub : Unable to fetch the ipv6 of $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE} ");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                return 0;
            }
        }
       #Setting the IP_ADDR_MIN in the file to the required ipaddress and verifying if the same is edited
       $cmd = "sed -ri '1,15 s/IP_ADDR_MIN[ ]*=[ ]*.+:[a-f0-9]+/IP_ADDR_MIN = $ipaddress[1]:" . eval{sprintf "%x",eval{hex($ipaddress[0])+1}} . " /'  $self->{'BASEPATH'}/$script_name/$script_name.conf";
       $self->execCmd("$cmd");
       $cmd = "grep -c \"IP_ADDR_MIN = $ipaddress[1]:" . eval{sprintf "%x",eval{hex($ipaddress[0])+1}} . "\" $self->{'BASEPATH'}/$script_name/$script_name.conf";
       @cmd_res = $self->execCmd("$cmd");
       if ($cmd_res[0] == 0) {
          $logger->error(__PACKAGE__ . ".$sub: Failed to configure IP_ADDR_MIN for Ipv6");
          $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
          return 0;
       }

        #Setting the IP_ADDR_MAX in the file to the required ipaddress and verifying if the same is edited
       $cmd = "sed -ri '1,15 s/IP_ADDR_MAX[ ]*=[ ]*.+:[a-f0-9]+/IP_ADDR_MAX = $ipaddress[1]:" . eval{sprintf "%x",eval{hex($ipaddress[0])+$args{-numClient}}} . " /'  $self->{'BASEPATH'}/$script_name/$script_name.conf";
       $self->execCmd("$cmd");
       $cmd = "grep -c \"IP_ADDR_MAX = $ipaddress[1]:" . eval{sprintf "%x",eval{hex($ipaddress[0])+$args{-numClient}}} . "\" $self->{'BASEPATH'}/$script_name/$script_name.conf";
       @cmd_res = $self->execCmd("$cmd");
       if ($cmd_res[0] == 0) {
          $logger->error(__PACKAGE__ . ".$sub: Failed to configure IP_ADDR_MAX for Ipv6");
          $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
          return 0;
       }

   }
   @cmd_res = $self->execCmd("head -25 $self->{'BASEPATH'}/$script_name/$script_name.conf");
   $logger->info(__PACKAGE__ . ".$sub:First few lines of the $script_name.conf after changing all the details  are " . Dumper(\@cmd_res)); 

 
    #checking if any old instance of curl loader is running
    $cmd = 'ps -ef | grep "curl-loader -dvuf ' . "$script_name" . '.conf"' . ' | grep -v "grep curl" | awk \'{print $2}\'';
    my @old_curlarray = $self->execCmd($cmd);
    for my $old_curl (@old_curlarray) {
    unless ($old_curl){
       $logger->debug(__PACKAGE__ . ".$sub: No Old instance of curl loader running");
    } else {
       $logger->error(__PACKAGE__ . ".$sub: Old Curl Loader running on pid : $old_curl");
       $logger->error(__PACKAGE__ . ".$sub: Killing the old curl loader on pid : $old_curl");
        $self->execCmd("kill -2 $old_curl");
    }
    }
    #Checking if the load is http or https
    $cmd = 'grep -c "^URL=https"' . "  $self->{'BASEPATH'}/$script_name/$script_name.conf";
    @cmd_res = $self->execCmd("$cmd");
    $self->{'load'} =  ($cmd_res[0] > 0) ? 'https':'http';
    $logger->info(__PACKAGE__ . ".$sub:The Load type is : \"$self->{'load'}\"");

    #Starting the API load
    $logger->info(__PACKAGE__ . ".$sub Starting PSX API Provisioning load :  $script_name");
    @cmd_res = $self->execCmd("cd $script_path");
    if(grep ( /no.*such/i, @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub $script_path directory not present");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub Changed working directory to $script_path");

    # Checking the Records in PSX DB
    unless(@query = $self->execCmd("cat query.txt")) {
        $logger->error(__PACKAGE__ . ".$sub query.txt is empty. Please check the file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    if( grep( /No such file or directory/i, @query)) {
        $logger->error(__PACKAGE__ . ".$sub  query.txt file not present in $script_path");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    } else {
    unless(@r = $psx->execSqlplusCommand("@query")) {
        $logger->error(__PACKAGE__ . ".$sub sql query failed. Check session log!!!");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        #return 0;
        }
    $self->{'Verification_point'}->{'Curl_loader'}->{'Before_db'} = $r[$#r];
    $logger->info(__PACKAGE__ . ".$sub Number of psx records before start of the load : $self->{'Verification_point'}->{'Curl_loader'}->{'Before_db'} " . Dumper(\@r));
    }


    #Changing the PSX Name in records.txt file
    @cmd_res = $self->execCmd("sed -i \'s/^[A-Za-z0-9_/-]*,/$psx_name,/1\' *records.txt");
    if(grep ( /no.*such/i, @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub records.txt file not present");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }


    @cmd_res = $self->execCmd("source ../../libenv");
    if(grep ( /no.*such/i, @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub source ../../libenv failed");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub Sourced libenv ");

    unless(@curl_pid = $self->execCmd("nohup ../../curl-loader -dvuf $script_name.conf > nohup.out &",300)) {
        $logger->error(__PACKAGE__ . ".$sub Could not start curl-loader");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub Started curl-loader");
   
    #Curloader takes some 10 secs to initialise.
    sleep 20;
    $logger->debug(__PACKAGE__ . ".$sub: Waiting for curlloader to inistialise ");

    @curl_pid = split/]/, $curl_pid[0];
    $curl_pid =  $curl_pid[1];
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [$curl_pid]");
    return  $curl_pid;
}

=head2 stop_curl()

    This function will stop the PSX API Provisoning load, fetch result of the load from CURL-LOADER and the records created in PSX DB and copies the result of the load to ATS repository.

=over

=item Arguments:

    Mandatory
        1.absolute path of the script
        2.pid of the API load
        3.PSX object
        absolute path of the script and pid of the API load will be the output of start_curl

=item Return Value:

    0 - on failure
    1 - if it successfully fetch result of the load from CURL-LOADER and the records created in PSX DB

=item Usage:

    my $curl_stop = $curlObj->stop_curl(-psx => $psxObj,
                                        -script_path => $script_path,
                                        -curl_pid => $curl_pid);

=back

=cut

sub stop_curl {

    my ($self, %args) = @_;
    my $sub = "stop_curl";
    my @cps = ();
    my $psx_records = ();
    my @query = ();
    my @pid_exists = ();
    my ($runtime,$appl,$clients,$req,$xx1,$xx2,$xx3,$xx4,$xx5,$err,$terr,$delay,$delay_2xx,$tin,$tout,$script_path, $curl_pid, $psx,$CAPS) = ();
    $args{-BulkCount} = (defined $args{-BulkCount}) ? $args{-BulkCount}:1; #if the Bulkcount is specified then the same is used otherwise it is initialised to 1
    #my $log_dir = $main::TESTSUITE->{LOG_PATH};
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my @cmd_res = ();
    my @r = (); # generic array to store result of execmd
    my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
    my $timestamp = strftime "%m-%d-%y-%H-%M", localtime;
    $logger->debug(__PACKAGE__ . ".$sub  --> Entered Sub ");

    foreach('-script_path' , '-curl_pid' , '-psx' ) {
        unless(defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory input $_ is missing");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
        }
    }

    $script_path = $self->{'BASEPATH'}."/".$args{-script_path};
    $curl_pid = $args{-curl_pid};
    $psx = $args{-psx};


    $logger->info(__PACKAGE__ . ".$sub Checking if API load is still running");
    $self->execCmd("");
    $self->execCmd("");
    @pid_exists = $self->execCmd("ps -p $curl_pid | grep $curl_pid");

    if(@pid_exists) {
        $logger->info(__PACKAGE__ . ".$sub API load still running. Killing it.");
        unless(defined ($self->execCmd("kill -2 $curl_pid "))) {
            $logger->error(__PACKAGE__ . ".$sub Failed to kill API load" );
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub Successfully stopped API load");
        sleep 3;
    }
    else {
        $logger->info(__PACKAGE__ . ".$sub API Load not running");
    }
    $self->execCmd("");
    $self->execCmd("");


    @cmd_res = $self->execCmd("ls $script_path");
    if(grep ( /no.*such/i, @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub  $script_path directory not present");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    
    $self->execCmd("");
    $self->execCmd("");

    unless(@r = $self->execCmd("tail -3 $script_path/run.txt")) {
        $logger->error(__PACKAGE__ . ".$sub Could not read from run.txt");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub Successfully read run.txt");
    $logger->debug(__PACKAGE__ . "$sub " . Dumper(\@r)); # Dumping the Execmd o/p for better debugging
    $logger->info(__PACKAGE__ . ".$sub API load summary : ");

    #Splitiing the Line 2 fo the run.txt file , as lie 1 has the name string
    ($runtime,$appl,$clients,$req,$xx1,$xx2,$xx3,$xx4,$xx5,$err,$terr,$delay,$delay_2xx,$tin,$tout) = split/,/, $r[1] if ($self->{'load'} eq 'http');
    ($runtime,$appl,$clients,$req,$xx1,$xx2,$xx3,$xx4,$xx5,$err,$terr,$delay,$delay_2xx,$tin,$tout) = split/,/, $r[2] if ($self->{'load'} eq 'https');

    $logger->info(__PACKAGE__ . ".$sub Total run time = $runtime");
    $logger->info(__PACKAGE__ . ".$sub Requests = $req");
    $logger->info(__PACKAGE__ . ".$sub 1xx = $xx1");
    $logger->info(__PACKAGE__ . ".$sub 2xx = $xx2");
    $logger->info(__PACKAGE__ . ".$sub 3xx = $xx3");
    $logger->info(__PACKAGE__ . ".$sub 4xx = $xx4");
    $logger->info(__PACKAGE__ . ".$sub 5xx = $xx5");
    $logger->info(__PACKAGE__ . ".$sub Errors = $err");
    $logger->info(__PACKAGE__ . ".$sub Timeout errors = $terr");
    $logger->info(__PACKAGE__ . ".$sub Average application server Delay(msec) = $delay");
    $logger->info(__PACKAGE__ . ".$sub Average application server Delay(msec) for 2xx = $delay_2xx");
    $logger->info(__PACKAGE__ . ".$sub through-put in = $tin");
    $logger->info(__PACKAGE__ . ".$sub through-put out = $tout");

    #setiing the resulst to theobject so that it can be acessed from the script
    $self->{'1xx'} = $xx1;
    $self->{'2xx'} = $xx2;
    $self->{'3xx'} = $xx3;
    $self->{'4xx'} = $xx4;
    $self->{'5xx'} = $xx5;
    $self->{'Errors'} = $err;
    $self->{'Timeout'} = $terr;
    $self->{'2XXResponseTime'} = $delay_2xx;
    $self->{'ResponseTime'} = $delay;
    $self->{'TotalRunTime'} = $runtime;
    $self->{'TotalRequests'} = $req;
     
    # Checking the Records in PSX DB
    unless(@query = $self->execCmd("cat $script_path/query.txt")) {
        $logger->error(__PACKAGE__ . ".$sub query.txt is empty. Please check the file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    if( grep( /No such file or directory/i, @query)) {
        $logger->error(__PACKAGE__ . ".$sub  query.txt file not present in $script_path");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    } else {
    unless(@r = $psx->execSqlplusCommand("@query")) {
        $logger->error(__PACKAGE__ . ".$sub sql query failed. Check session log!!!");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        #return 0;
        }
    $self->{'Verification_point'}->{'Curl_loader'}->{'After_db'} = $r[$#r];
    $logger->info(__PACKAGE__ . ".$sub Number of psx records after the load : $self->{'Verification_point'}->{'Curl_loader'}->{'After_db'} " . Dumper(\@r));
    }
   
    #Calculating the metrices
    my $db_loss = abs( abs($self->{'Verification_point'}->{'Curl_loader'}->{'After_db'} - $self->{'Verification_point'}->{'Curl_loader'}->{'Before_db'}) - $req*$args{-BulkCount});
    $logger->error(__PACKAGE__ . ".$sub: Loss in the DB is : $db_loss");

    $CAPS = $req*$args{-BulkCount}/$runtime;
    $logger->debug(__PACKAGE__ . ".$sub: The CPS is : $CAPS");
    $self->{'CPS'} = $CAPS;

    # Printing the Test case Results to Testcase_Results.txt
    my $fp; # File handler
    open $fp , ">>", "$self->{result_path}/Testcase_Results.txt";
    print $fp "##########################\n";
    print $fp "API Summary  \n";
    print $fp "##########################\n";
    print $fp "Total Number of Requests = $self->{'TotalRequests'} \n";
    print $fp "Total Number of 2xx responses = $self->{'2xx'} \n";
    print $fp "Total RunTime = $self->{'TotalRunTime'} \n";
    print $fp "Avg 2XX Response Time = $self->{'2XXResponseTime'} \n";
    print $fp "Avg Response Time = $self->{'ResponseTime'} \n";
    print $fp "CAPS =  $self->{'CPS'} \n";
    close $fp;


    # Copying the run files to ATS directory
    my %scpArgs;
    $scpArgs{-hostip} = $self->{OBJ_HOST};
    $scpArgs{-hostuser} = $self->{OBJ_USER};
    $scpArgs{-hostpasswd} = $self->{OBJ_PASSWORD};

    foreach my $file ('run.txt','run.log','nohup.out') {
        $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$script_path/". "$file";
        $scpArgs{-destinationFilePath} = $self->{result_path}."/".$args{-script_path}."_".$timestamp."_"."$file";
        $logger->debug(__PACKAGE__ . ".$sub: scp file $scpArgs{-sourceFilePath} to $scpArgs{-destinationFilePath}");
        unless(&SonusQA::Base::secureCopy(%scpArgs)){
            $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the $file to $self->{result_path}");
        } else {
            $logger->debug(__PACKAGE__ . ".$sub: Succesfully copied $file to $self->{result_path}");
            system("gzip --best $scpArgs{-destinationFilePath}") if ( $file ne 'run.txt' );
            $self->execCmd("rm $script_path/" . "$file") if ( $file ne 'run.txt' );
        }
    }
    
    
    #Verfiying the results 
    if(($xx5/$req) > 0.001) {
        $logger->error(__PACKAGE__ . ".$sub No. of 5xx is greater than 0.1% of Requests.Observed Total 5XX is : $xx5 ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    } elsif ($xx2 < $req*0.999 ) {
        $logger->error(__PACKAGE__ . ".$sub No of 2xx is lesser than the 99.9% of the Request. Observed Total 2XX  :$xx2");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    } elsif ($db_loss > $req*$args{-BulkCount}*0.001 ) {
        $logger->error(__PACKAGE__ . ".$sub Loss% in PSX DB is  greater than 0.1% of Requests. Observed Loss in DB is :$db_loss");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub API Test conditions have passed");
    }

    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return $CAPS;


}
=head2 start_perflogger()

    This function enables user to start perflogger script(used for collecting performance stats of SUT) as background process and returns the PID of the process in which perflogger was started.

=over

=item Arguments:

    Mandatory
        -testcase => "EMS_GUI_PERF_001" Test case ID
        -sut  => "orsted" EMS device for which Performance stats has to be collected.
        -testbed  => "A" Test bed type A for solrias and B for linux
        -upload => "n" whether we attempt to push results to the DB. If the input is not 'n|N', it is assumed pushing results to DB is required.
    Optional
        -masterpsx => "y" to notify the PSX a master. Mgmt stats won't be collected.
        -nosipe => "y" to disable sipe stats collection.
        -noscpa => "y" to disable scpa stats collection .
        -slwresd => "y" to collect slwresd stats for PSX.
        -nocheck => "y" to disable the validation of SUT specifications.
        -sessionlog => y|n to enable session log
        -log     => Log levle to be printed in perflogger log file
        -ipVersion => IP version to connect to SUT on - ipv4 or ipv6
        -cpu => "y" to enable the collection of only Processor stats in case of SBC (mpstat) for every 3 Secs.
        -proc => "y" o enable the collection of only Process stats in case of SBC (sbxprocess) for every 2 secs.
        -irtt => "y" to enable irtt the collection of only stats in case of SBC for every 3 Secs.
        -acl => "y"  to enable the collection of only acl stats in case of SBC for every 5 Secs.
        -alias_file => "<Pass the hash reference file if need to resolve alias from the file.Optional parameter>" TOOLS-71106
        -plist => Comma separated optional argument for including stats (CPU, Mem, RSS, VSZ) collection of Tools processes that are not defined in perfLogger.pl
=item Return Value:

    0 - on failure
    PID of the process in which perflogger was started.

=item Usage:

    my $pl_pid = $atsObj->start_perflogger( -testcase => "<TESTCASE_ID>",
                                            -sut  => "<EMS_SUT>",
                                            -testbed  => "<TESTBED_TYPE>",
                                            -upload => "<n|N for no, any other input will be assumed yes>",
                                            -plist => "'dbsManager.py','redis'" #optional argument
                                            );

=back

=cut

sub start_perflogger {

    my ($self,%args) = @_;
    my $sub = "start_perflogger";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");
    my $flag=1;
    foreach('-testcase' , '-sut' , '-testbed' , '-upload' ) {
    unless( defined ($args{$_})) {
            $logger->error(__PACKAGE__ . ".$sub Mandatory input $_ is not defined ");
            $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
            $flag =0;
            last;
        }
        return $flag unless($flag);
    }
    
    my @cmd_res = ();
    my $pid = ''; #Initialising two pids to null, PerfloggerPidHost is for  host machine in case of Virtual setup
    $self->{PerfloggerPidHost} = '';
    $self->{HostTmsAlias} = ''; #used in case of Virtual setup for the HOST machine TMS name
    $self->{PerfLoggerTestid} = $args{-testcase}; # Test case id used to copy the files in stop_perfloger
    $self->{PerfLoggerSut} = $args{-sut}; #SUT TMS alias used in stop_perflogger for copying the files
    my $upload_append = (defined $args{-upload} and $args{-upload} =~ /n/i) ? '-noup':'';
    my $nocheck_append = (defined $args{-nocheck} and $args{-nocheck} =~ /y/i) ? '-nocheck':'';
    my $master_append = (defined $args{-masterpsx} and $args{-masterpsx} =~ /y/i) ? '-mp':'';
    my $nosipe_append = (defined $args{-nosipe} and $args{-nosipe} =~ /y/i) ? '-nosipe':'';
    my $noscpa_append = (defined $args{-noscpa} and $args{-noscpa} =~ /y/i) ? '-noscpa':'';
    my $slwresd_append = (defined $args{-slwresd} and $args{-slwresd} =~ /y/i) ? '-slwresd':'';
    my $acl_append = (defined $args{-acl} and $args{-acl} =~ /y/i) ? '-acl': '';
    my $cpu_append = (defined $args{-cpu} and $args{-cpu} =~ /y/i) ? '-cpu': '';
    my $proc_append = (defined $args{-proc} and $args{-proc} =~ /y/i) ? '-proc': '';
    my $irtt_append = (defined $args{-irtt} and $args{-irtt} =~ /y/i) ? '-irtt': '';
    my $sessionlog_append = (defined $args{-sessionlog} and $args{-sessionlog} =~ /n/i) ? '':'-sessionlog';
    my $log_append = (defined $args{-log} ) ? "$args{-log}":'DEBUG';
    my $ipVersion = (defined $args{-ipVersion} ) ? $args{-ipVersion}:'v4'; #default will be v4 if v4 or v6 is passed, will take that
    $self->{IP_VERSION}=$ipVersion;
    my $ipVersion_append = "-ipVersion $ipVersion";
    my $basepath = $self->{BASEPATH};
    
    my $plist = (exists $args{-plist}) ? "-plist $args{-plist}" : '';
	my $http_append = (defined $args{-http} and $args{-http} =~ /y/i) ? '-http': ''; #TOOLS-75184

   #Checking if the SUT is a KVM or VM
   my $SutObj= SonusQA::ATSHELPER::newFromAlias(-tms_alias => "$args{-sut}", -DEFAULTTIMEOUT => 10, -SESSIONLOG => 1,-iptype => 'any', -return_on_fail => 1, -failures_threshold => 20, -do_not_delete => 1, -ipType => $ipVersion, -alias_file => $args{-alias_file});
   #These flags are set and the same is used somewhere else e.g. getPerfDbdata  
   $self->{sutType}= $SutObj->{'TMS_ALIAS_DATA'}->{'__OBJTYPE'} ;
   $self->{psxMaster}  = (defined $args{-masterpsx} && $args{-masterpsx} =~ /y/i) ? 'y':'n'; #We use the Scripts Flag status only as CallProcessing and Prov Master is possible

   my ($SutObj1, @resultOfUname, $alias_file_flag);

        if ($self->{sutType} eq "SBX5000"){
            if($SutObj->{CLOUD_SBC}){ #TOOLS-15041
                unless($args{-alias_file}){
                    $logger->debug(__PACKAGE__ .".$sub Creating alias file for SUT ($args{-sut})");
                    unless($args{-alias_file} = SonusQA::ATSHELPER::createAliasFile(-alias => "$args{-sut}", -path => "$ENV{HOME}/ats_user/logs")){
                        $logger->error(__PACKAGE__ . ".$sub Couldn't create alias file for $args{-sut}");
                        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
                        return 0;    
                    }
                }
                $logger->debug(__PACKAGE__ .".$sub Alias file for SUT ($args{-sut}) is $args{-alias_file}");
                $alias_file_flag = " -af $args{-alias_file}";
            }

            #Recreating Sut object as a linux object
            $logger->debug(__PACKAGE__ ." CE0LinuxObj : ". Dumper($SutObj->{'CE0LinuxObj'}));
            $SutObj1 = bless $SutObj->{'CE0LinuxObj'}, SonusQA::TOOLS;
            @resultOfUname = $SutObj1->execCmd('uname');
            $SutObj->{PLATFORM} = $resultOfUname[0];
            $logger->debug(__PACKAGE__ .".$sub Creating a Linux SUT object as the SUT is SBX5000.");
        }
        elsif($self->{sutType} eq "SBCEDGE"){
           unless($SutObj->sshRootLogin()){
               $logger->error(__PACKAGE__ . "$sub Root login failed");
               $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
               return 0;             
           }
           $SutObj1 = $SutObj->{root_obj};
           @resultOfUname = $SutObj1->execCmd('uname');
           $SutObj->{PLATFORM} = $resultOfUname[0];
           $logger->debug(__PACKAGE__ ." Creating a Linux SUT object as the SUT is SBCEDGE.");
        }
        else
        {
                $SutObj1 = $SutObj;
                $logger->debug(__PACKAGE__ ."The object isn't a SBX hence continuing to find memory without any alteration of Sut object.");
        }
   #Reading the Total memory of SUT
    my $cmd;
    if ( uc($SutObj->{PLATFORM}) eq "SUNOS" ) {
        $cmd = "prtconf | grep '^Memory' | sed -e 's/.*: //' -e 's/ Megabytes//' "
    } elsif ( uc($SutObj->{PLATFORM}) eq "LINUX" ) {
        $cmd = 'free -m | grep Mem | sed -re \'s/(Mem:)\s+([0-9]+)\s+.*/\2/\'';
    }
    unless ( @cmd_res = $SutObj1->execCmd($cmd) ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete, result: " . Dumper(\@cmd_res));
    }

    $self->{sutTotalMemMB} = $cmd_res[0];
    $logger->info(__PACKAGE__ . "$sub DUT has $self->{sutTotalMemMB} MB of RAM") ;
  
   my ($coresPerSocket,$threadsPerCore,$numOfSockets,$hypervisor) = (0,0,0,"");
   #TOOLS-19670 (for SBC GCP instance), TOOLS-72199: AWS
   unless ($SutObj->{CLOUD_PLATFORM} =~ /Google Compute Engine|OpenStack|AWS/){
        $logger->debug(__PACKAGE__ . "$sub : Platform ($SutObj->{CLOUD_PLATFORM}) type is not cloud (Google Compute Engine|OpenStack|AWS) so finding host metrics");
        if ( uc($SutObj->{PLATFORM}) eq "LINUX" ) {
        #Read lscpu for threads,Socket & cores details
                unless ( @cmd_res = $SutObj1->execCmd("lscpu",60) ) {
                        $logger->error(__PACKAGE__ . "$sub Remote command execution failed for \"lscpu \", data maybe incomplete, result: " . Dumper(\@cmd_res));
                }
                chomp @cmd_res;
                foreach my $line (@cmd_res) {
                        $threadsPerCore = $1 if ($line =~ m/Thread\(s\)\s+per\s+core\s*:\s+(\d+)/);
                        $coresPerSocket = $1 if ($line =~ m/Core\(s\)\s+per\s+socket\s*:\s+(\d+)/);
                        $numOfSockets = $1 if ($line =~ m/Socket\(s\)\s*:\s+(\d+)/);
                        $self->{hypervisor} = $1 if ($line =~ m/Hypervisor\s+vendor\s*:\s+([a-zA-Z]+)/);
                }
        }
   }
   else{
        $logger->debug(__PACKAGE__ . "$sub : Platform type is (Google Compute Engine | OpenStack Nova )cloud so not finding cpu details TOOLS-19670");
   }
        #If SUT is hypervisor based then we have to get the host CPU and memory details
        if($self->{hypervisor} eq "KVM")  {
            $logger->info(__PACKAGE__ . "$sub Chassis Type: We are running on a [$self->{hypervisor}] hypervisor with  $threadsPerCore Threads per core , $coresPerSocket Cores per Socket, $numOfSockets number of Sockets");
            if ( !defined $SutObj->{TMS_ALIAS_DATA}->{VM_HOST}->{1}->{NAME} ) {
                   $logger->error(__PACKAGE__ . "$sub Unable to fetch HOST Machine details from TMS for Test Bed :$args{-sut}.Please Update \"{VM_HOST}->{1}->{NAME}\" in TMS ");
                   return 0;
            }
                $logger->info(__PACKAGE__ . ".$sub The SUT is a virtual machine and the Host machine TMS alias name is [$SutObj->{TMS_ALIAS_DATA}->{VM_HOST}->{1}->{NAME}]");
                $self->{HostTmsAlias} = $SutObj->{TMS_ALIAS_DATA}->{VM_HOST}->{1}->{NAME};

           #Creating an object for HOST machine in order to get the Total memory details
           my $HostSutObj= SonusQA::ATSHELPER::newFromAlias(-tms_alias => $self->{HostTmsAlias}, -DEFAULTTIMEOUT => 10, -SESSIONLOG => 1);  
 
           #Reading the Total memory of HOST machine
           if ( uc($HostSutObj->{PLATFORM}) eq "LINUX" ) {
               $cmd = 'free -m | grep Mem | sed -re \'s/(Mem:)\s+([0-9]+)\s+.*/\2/\'';
           }
           unless ( @cmd_res = $HostSutObj->execCmd($cmd) ) {
               $logger->error(__PACKAGE__ . "$sub Remote command execution failed, data maybe incomplete, result: " . Dumper(\@cmd_res));
           }
           $self->{HostsutTotalMemMB} = $cmd_res[0];
           $logger->info(__PACKAGE__ . "$sub DUT has $self->{HostsutTotalMemMB} MB of RAM") ;
  
           $HostSutObj->DESTROY(); # Deleting the Object as we are done with all the data retrival from TMS
        } elsif ( $self->{hypervisor} eq "VMware") {
            $logger->info(__PACKAGE__ . "$sub Chassis Type: We are running on a [$self->{hypervisor}] hypervisor with  $threadsPerCore Threads per core , $coresPerSocket Cores per Socket, $numOfSockets number of Sockets");
            if ( !defined $SutObj->{TMS_ALIAS_DATA}->{VM_HOST}->{1}->{NAME} ) {
                   $logger->error(__PACKAGE__ . "$sub Unable to fetch HOST Machine details from TMS for Test Bed :$args{-sut}.Please Update \"{VM_HOST}->{1}->{NAME}\" in TMS ");
                   return 0;
            }
                $logger->info(__PACKAGE__ . ".$sub The SUT is a virtual machine and the Host machine TMS alias name is [$SutObj->{TMS_ALIAS_DATA}->{VM_HOST}->{1}->{NAME}]");
                $self->{HostTmsAlias} = $SutObj->{TMS_ALIAS_DATA}->{VM_HOST}->{1}->{NAME};

        } else {
           $logger->info(__PACKAGE__ . ".$sub The SUT is not Virtual machine ");
        }
   
   $SutObj1->DESTROY(); # Deleting the linux object of Sut created. 
   $SutObj->DESTROY(); # Deleting the Object as we are done with all the data retrival from TMS

 

 
  #Changing the Dir to basepath and checking the perfloger.pl
    @cmd_res = $self->execCmd("cd $basepath");
    if(grep(/no.*such.*dir/i , @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub $basepath directory not present");
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
        return 0;
    }

    #checking if any old instance of perflogger is running for the same test case alias in the Guest Machine
    $cmd = 'ps -ef | grep ' . "\"$args{-testcase} -g " ."$args{-sut} \"" .  '| grep -v "grep " | awk \'{print $2}\'';
    my @old_perflogger = $self->execCmd($cmd);
    unless ($old_perflogger[0]){
       $logger->debug(__PACKAGE__ . ".$sub: No Old instance of perflogger loader running for $args{-testcase} ");
    } else {
    for my $perflogger (@old_perflogger) {
       $logger->error(__PACKAGE__ . ".$sub: Old perflogger for $args{-testcase} is  running on pid : $perflogger");
       $logger->error(__PACKAGE__ . ".$sub: Killing the old perflogger on pid : $perflogger");
        $self->execCmd("kill -2 $perflogger");
        }
    sleep 10;
    $self->execCmd("");
    $self->execCmd("");
    }
   
    #Removing the old log,csv & sql files from the basepath for the respective test case for Guest machine
    @cmd_res = $self->execCmd("rm -rf $args{-testcase}"."_" ."$args{-sut}*");
    @cmd_res = $self->execCmd("rm -rf nohup_$self->{PerfLoggerSut}.out");
    $logger->info(__PACKAGE__ . ".$sub Removed all the old nohup_$self->{PerfLoggerSut},log,csv and sql files from the basepath for the test case $args{-testcase} run on SUT $args{-sut}");
 
    #checking if any old instance of perflogger is running for the same test case alias for the Host Machine and starting the new instance
    if ($self->{HostTmsAlias} ne '') {
        $cmd = 'ps -ef | grep ' . "\"$args{-testcase} -g " ."$self->{HostTmsAlias} \"" .  '| grep -v "grep " | awk \'{print $2}\'';
        @old_perflogger = $self->execCmd($cmd);
        unless ($old_perflogger[0]){
           $logger->debug(__PACKAGE__ . ".$sub: No Old instance of perflogger is running for  $args{-testcase} & Virtual machine $self->{HostTmsAlias}");
            } else {
                for my $perflogger (@old_perflogger) {
                   $logger->error(__PACKAGE__ . ".$sub: Old perflogger for $args{-testcase} & Virtual machine $self->{HostTmsAlias} is  running on pid : $perflogger");
                   $logger->error(__PACKAGE__ . ".$sub: Killing the old perflogger on pid : $perflogger");
                    $self->execCmd("kill -2 $perflogger");
                }
                sleep 10;
                 $self->execCmd("");
                 $self->execCmd("");
            }


     #Removing the old log,csv & sql files from the basepath for the respective test case for Host machine
    @cmd_res = $self->execCmd("rm -rf $args{-testcase}"."_" ."$self->{HostTmsAlias}*");
    @cmd_res = $self->execCmd("rm -rf nohuphost_$self->{HostTmsAlias}.out");
    $logger->info(__PACKAGE__ . ".$sub Removed all the old nohup,log,csv and sql files from the basepath for the test case $args{-testcase} run on SUT $self->{HostTmsAlias}");
    
        #Starting the perfloger for host
        if($self->{hypervisor} eq "KVM")  {
            @cmd_res = $self->execCmd("/ats/tools/perf/perfLogger.pl -tc $args{-testcase} -g $self->{HostTmsAlias} -tb $args{-testbed} $upload_append -log $log_append $sessionlog_append $nocheck_append $cpu_append $http_append $acl_append $proc_append $irtt_append >> nohuphost_$self->{HostTmsAlias}.out 2>&1& ");
            #PerfLogger takes some 60 secs to initialise
            $logger->debug(__PACKAGE__ . ".$sub: Waiting for perflogger to inistialise for the Host OS on a KVM setup");
            @cmd_res = split /]/ , $cmd_res[0];
            $self->{PerfloggerPidHost} = trim($cmd_res[1]);
            my $found = 0;
    	    while($found < 20){
                $logger->info(__PACKAGE__ . ".$sub: Waiting for 10 sec ");
                sleep(10);
                if(`grep -rni 'Initialized all devices' nohup_$self->{PerfLoggerSut}.out`){
                        $logger->info(__PACKAGE__ . ".$sub: perflogger is initialised ($found)");
                        last;
                }
                $found++;
   	        }
    	    if($found == 20){
        	    $logger->warn(__PACKAGE__ . ".$sub not able to identify whether perflogger is initialised or not from 'nohup_$self->{PerfLoggerSut}.out '");
    	    }
           
        } elsif ( $self->{hypervisor} eq "VMware") {
           #Creating an object for HOST machine 
           $self->{HostSutObj}= SonusQA::ATSHELPER::newFromAlias(-tms_alias => $self->{HostTmsAlias}, -DEFAULTTIMEOUT => 10, -SESSIONLOG => 1);
           my $nodeName    = lc($self->{HostSutObj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME});
           my ($sec,$min,$hour,$mday,$mon,$year,$wday, $yday,$isdst) = localtime(time);
           my $timestamp = sprintf "%4d%02d%02d-%02d%02d%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec;
           my $esxCmd1= 'ps | grep esxtop | grep -v grep | awk \'{print $1}\' | xargs kill -9';
           my $esxCmd2="rm -rf *.csv";
           my $esxCmd3 = "nohup  esxtop  n c m -b -d 2 > $self->{PerfLoggerTestid}-$nodeName-$timestamp.csv&";
           my @esxCmd = ($esxCmd1,$esxCmd2,$esxCmd3);
           unless ( SonusQA::SBX5000::PERFHELPER::esxCmdExecution($self->{HostSutObj},@esxCmd) ){
               $logger->error(__PACKAGE__ . ".$sub: failed to start the esxtop command on $nodeName");
           }else {
               $logger->info(__PACKAGE__ . ".$sub: Successfully started esxtop command on $nodeName");
           }

        }
           
    }
        #First start the iostat script, if it fails, exit and dont proceeed further
        #putting an if condition as iostat function does not work for SBX
        if ($self->{sutType} !~ /SBX5000|SBCEDGE/)
        {
        $logger->debug(__PACKAGE__ . ".$sub Starting iostat script on SUT");
        unless($self->startIostatScript(-ipVersion => $ipVersion)){
        $logger->error(__PACKAGE__ . ".$sub unable to start the iostat script"); 
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving sub [0]");
        return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub iostat script started successfully");
        } else{
                $logger->error(__PACKAGE__ ."The passed object is a SBX, hence not running ioscript.");
        }
    #Executing Enter to clear the shell output 
    $self->execCmd("");
    $self->execCmd("");
    #Starting the perflogger for SUT
    @cmd_res = $self->execCmd("/ats/tools/perf/perfLogger.pl -tc $args{-testcase} -g $args{-sut}$alias_file_flag -tb $args{-testbed} $upload_append $master_append $nosipe_append $noscpa_append $slwresd_append $ipVersion_append -log $log_append $sessionlog_append $nocheck_append $cpu_append $http_append $acl_append $proc_append $irtt_append $plist >> nohup_$self->{PerfLoggerSut}.out 2>&1& ");
    #PerfLogger takes some 10 secs to initialise.
    @cmd_res = split /]/ , $cmd_res[0];
    $pid = trim($cmd_res[1]); #there is an issue with extra spaces for 5 digit PID values

    my $found = 0;
    $logger->debug(__PACKAGE__ . ".$sub: Waiting for perflogger to initialize ");
    while($found < 20){
	    $logger->info(__PACKAGE__ . ".$sub: Waiting for 10 sec ");
        sleep(10);
        if(`grep -rni 'Initialized all devices' nohup_$self->{PerfLoggerSut}.out`){
            $logger->info(__PACKAGE__ . ".$sub: perflogger is initialised ($found)");
	        last;
        }
	$found++;
    }
    if($found == 20){
        $logger->warn(__PACKAGE__ . ".$sub not able to identify whether perflogger is initialised or not from 'nohup_$self->{PerfLoggerSut}.out '");
    }

    #Before we exit the function with success, check to ensure that perflogger is indeed running and return pass/fail accordingly.
    $logger->debug(__PACKAGE__ . ".$sub: Checking if perflogger PID, \"$pid\" is still running");
    @cmd_res = $self->execCmd("ps -p $pid | grep perfLogger.pl");
    $logger->debug(__PACKAGE__ . ".$sub: Command results ".Dumper(@cmd_res));
    unless($cmd_res[0] =~ $pid){
        $logger->error(__PACKAGE__ . ".$sub perflogger is not running on pid \"$pid\", returning failure");
        #changing this as iostatscript doesn't work for SBX object
        if ($self->{sutType} !~ /SBX5000|SBCEDGE/)
        {
        $self->stopIostatScript(-ipVersion => $self->{IP_VERSION}); # stop the script also if perflogger failed.
        }else
        {
                $logger->debug(__PACKAGE__ ."The passed object is a SBX OR SBCEGDE, hence not running ioscript.");
        }
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving sub [0]");
        return 0;
        }
    # Check if everything is ok on host
    if($self->{hypervisor} eq "KVM")  {
        @cmd_res = $self->execCmd("ps -p $self->{PerfloggerPidHost} | grep perfLogger.pl");
        $logger->debug(__PACKAGE__ . ".$sub Comand results are  ".Dumper(@cmd_res));
        unless($cmd_res[0] =~ $self->{PerfloggerPidHost}){
        $logger->error(__PACKAGE__ . ".$sub KVM Host perflogger is not running on pid \"$self->{PerfloggerPidHost}\" returning failure");
        #changing this as iostatscript doesn't work for SBX object
        if ($self->{sutType} !~ /SBX5000|SBCEDGE/)
        {
        $self->stopIostatScript(-ipVersion => $self->{IP_VERSION}); # stop the script also if perflogger failed on host as a cleanup.
        }else
        {
                $logger->debug(__PACKAGE__ ."The passed object is a SBX or SBCEDGE, hence not running ioscript.");
        }
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving sub [0]");
        return 0;
        }
        }
    $logger->info(__PACKAGE__ . ".$sub Perflogger started with PID = \"$pid\"");
    $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub : PID:$pid");
    return $pid;
}
#EndOfstart_perflogger

=head2 stop_perflogger()

    This function will be called to stop perfLogger.

=over

=item Arguments:
    Mandatory
        PID of the process in which perfLogger was started.

=item Return Value:

    0 - on failure
    1 - on success

=item Usage:
    my $stop_perf = $atsObj->stop_perflogger($pl_pid);

=back

=cut

sub stop_perflogger {

    my ($self,$pl_pid) = @_;
    my $sub = "stop_perflogger";
    my $basepath = $self->{BASEPATH};
    my $userid = $self->{OBJ_USER};
    my $passwd = $self->{OBJ_PASSWORD};
    my $log_dir = $main::TESTSUITE->{LOG_PATH};
    my $Ip = $self->{OBJ_HOST};
    my @cmd_res = ();
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $filename = '';
    my $testResult = 1;
    my $result;
    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");
    unless(defined($pl_pid)) {
        $logger->error(__PACKAGE__ . ".$sub Mandatory input Perflogger PID is empty or blank");
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
        return 0;
    }

    @cmd_res = $self->execCmd("cd $basepath");
    if(grep(/no.*such.*dir/i , @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub $basepath directory not present");
        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
        return 0;
    }


    #Killing the perfloggers
    $logger->info(__PACKAGE__ . ".$sub: killing the perflogger for the Guest on PID = $pl_pid");
    @cmd_res = $self->execCmd("kill -2 $pl_pid");
    if(grep (/no.*such.*process/i , @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub PID does not exist");
        $testResult = 0;
    } else {
        #Checking if the guest perfLogger is stopped completely 
        for ( my $i=0 ; $i <= 50 ; $i++) {
            @cmd_res = $self->execCmd("ps -p $pl_pid | grep perfLogger.pl");
            if(!defined $cmd_res[0]) {
                $logger->info(__PACKAGE__ . ".$sub Succefully stopped the SUT perflogger after " . eval{10*$i} ."secs");
                last;
            }
            sleep 10;
        }
    }
   
    #Killing the perflogger/esxtop for Host in case of VM 
    if ( $self->{hypervisor} eq "KVM") {
        $logger->info(__PACKAGE__ . ".$sub The SUT is a VM, so killing the perflogger for the Host OS, started on PID = $self->{PerfloggerPidHost}");
        @cmd_res = $self->execCmd("kill -2 $self->{PerfloggerPidHost}");
        if(grep (/no.*such.*process/i , @cmd_res)) {
            $logger->error(__PACKAGE__ . ".$sub PID does not existi $self->{PerfloggerPidHost} ");
            $testResult = 0;
        } else {
            #Checking if the host perfLogger is stopped completely 
            for ( my $i=0 ; $i <= 50 ; $i++) {
                @cmd_res = $self->execCmd("ps -p $self->{PerfloggerPidHost} | grep perfLogger.pl");
                if(!defined $cmd_res[0]) {
                    $logger->info(__PACKAGE__ . ".$sub Succefully stopped the host perflogger after " . eval{10*$i} ."secs");
                    last;
                }
                sleep 10;
            }
        }        
     } elsif ( $self->{hypervisor} eq "VMware") {
           #creating one more session to kill the esxstop command started in start_perflogger subroutine
           $self->{HostSutObj1}= SonusQA::ATSHELPER::newFromAlias(-tms_alias => $self->{HostTmsAlias}, -DEFAULTTIMEOUT => 10, -SESSIONLOG => 1);
           my $nodeName    = lc($self->{HostSutObj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME});
           my $esxCmd1= 'ps | grep esxtop | grep -v grep | awk \'{print $1}\' | xargs kill -9';
           my @esxCmd = ($esxCmd1);
           unless ( SonusQA::SBX5000::PERFHELPER::esxCmdExecution($self->{HostSutObj1},@esxCmd) ){
               $logger->error(__PACKAGE__ . ".$sub: failed to stop the esxtop command on $nodeName");
               $testResult = 0;
           }else { 
               $logger->info(__PACKAGE__ . ".$sub: Successfully stopped esxtop command on $nodeName");
           }
   }



   # The Test Script should be setting this is Variable so that perflogger log can be copied
   if (defined($self->{result_path})) {
       $logger->info(__PACKAGE__ . ".$sub The Result path is  defined  for perfLogger object, so copying the files after ziping the log file");
       $filename= "$basepath" . "/$self->{PerfLoggerTestid}" . "_" . "$self->{PerfLoggerSut}" . "*_20*"; #Listing the perfLogger files of SUT
       system("gzip --best $filename.log*");
       system("ls $filename.csv $filename.sql $filename.log*gz |  xargs -I {} cp {} $self->{result_path}/");
       system("cp $basepath/nohup_$self->{PerfLoggerSut}.out $self->{result_path}/");
           
       #Removing the old log,csv & sql files from the basepath for the respective test case for Guest machine
       @cmd_res = $self->execCmd("rm -rf $filename");
       @cmd_res = $self->execCmd("rm -rf nohup_$self->{PerfLoggerSut}.out");
       $logger->info(__PACKAGE__ . ".$sub Removed all the old nohup_$self->{PerfLoggerSut},log,csv and sql files from the basepath for the test case $self->{PerfLoggerTestid} run on SUT $self->{PerfLoggerSut}");
        
       if ($self->{hypervisor} eq "KVM") {
           $filename= "$basepath" . "/$self->{PerfLoggerTestid}" . "_" . "$self->{HostTmsAlias}" . "_20*" ; #Listing the perfLogger Files of Host
           system("gzip --best $filename.log*"); 
           system("ls $filename.csv $filename.sql $filename.log*gz | xargs -I {} cp {} $self->{result_path}/") ;
           system("cp $basepath/nohuphost_$self->{HostTmsAlias}.out $self->{result_path}/");
           #Removing the old log,csv & sql files from the basepath for the respective test case for Host machine
           @cmd_res = $self->execCmd("rm -rf $filename");
           @cmd_res = $self->execCmd("rm -rf nohuphost_$self->{HostTmsAlias}.out");
           $logger->info(__PACKAGE__ . ".$sub Removed all the old log,csv and sql files from the basepath for the test case $self->{PerfLoggerTestid} run on SUT $self->{HostTmsAlias}");
        } elsif ($self->{hypervisor} eq "VMware") {
            #Copying the result sheet to ATS repository.
            my %scpArgs;
            $scpArgs{-hostip} = $self->{HostSutObj1}->{OBJ_HOST};
            $scpArgs{-hostuser} = $self->{HostSutObj1}->{OBJ_USER};
            $scpArgs{-hostpasswd} = $self->{HostSutObj1}->{OBJ_PASSWORD};
            $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."/*csv";
            $scpArgs{-destinationFilePath} = $self->{result_path};

            $logger->debug(__PACKAGE__ . ".$sub: scp files $scpArgs{-sourceFilePath} to $scpArgs{-destinationFilePath}");
            unless(&SonusQA::Base::secureCopy(%scpArgs)){
                $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the result files to $self->{result_path}");
                $testResult = 0;
            }
        $self->{HostSutObj1}->DESTROY();
        $self->{HostSutObj}->DESTROY();
       }

  
   }
     #TOOLS-20260:Removed newFromalias as it is already present in start_perlogger
    if ( $self->{sutType} ){
        if($self->{sutType} !~ /SBX5000|SBCEDGE/){     
                unless($self->stopIostatScript(-ipVersion => $self->{IP_VERSION})) {
                        $logger->error(__PACKAGE__ . ".$sub Could not stop iostat script");
                        $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
                        return 0;
                }
        }else{
                $logger->warn(__PACKAGE__ ."The passed object is a SBX or SBCEDGE, hence not stoping ioscript.");
         } 
   }
   else{
        $logger->warn(__PACKAGE__ ."sut object is not created, so skipping calling stoplostatScript");
   } 


    if ( $testResult == 0 ) {
       $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [0]");
       return 0;
    } else {
       $logger->debug(__PACKAGE__ . ".$sub <-- Leaving Sub [1]");
       return 1;
    }
}#EndOfstop_perflogger
=head2 start_cli()

    This function starts the CLI load and pipes to a file clibackground

=over

=item Arguments:
    Mandatory
        1.-script_name name of the script that starts the CLI load. 
        2. -ems_obj ; Ems object to which the CLI load to be generated
        3. -devicelist - List of devices represented as a string , to which to which  the  cli commands to  be targeted for 
    Optional
        1. -ipv6 - If the Ip is ipv6

=item Return Value:

    0 - on failure
    1 - on success

=item Usage:
    my $clistart = $cliObj->start_cli(-script_name => 'test_auto.cli' , -ems_obj => $EmsObj,-devicelist =>$devicelist);

=back

=cut

sub start_cli {

    my ($self,%args) = @_;
    my $sub_name = "start_cli";
    my @cmd_res = ();
    my $script_path = $self->{BASEPATH};
    my $emsip = '';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    $args{-ipv6} = (defined $args{-ipv6}) ? $args{-ipv6}:'n';

    #Checking if the {NODE}->{1}->{INTERFACE} and {NODE}->{1}->{NEXTHOP_IPV4}/{NEXTHOP_IPV6} are defined in the TMS. Else it retruns fail
    if (!defined $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE}) {
        $logger->error(__PACKAGE__ . ".$sub_name : unable to get {TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE} from TMS for curl load object [$self->{TMS_ALIAS_DATA}->{ALIAS_NAME}]");
        $logger->debug(__PACKAGE__ . ".$sub_name : <-- Leaving sub [0]");
        return 0 ;
     }

    if ($args{-ipv6} ne 'y') {
        if (!defined $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NEXTHOP_IPV4}) {
            $logger->error(__PACKAGE__ . ".$sub_name : unable to get {TMS_ALIAS_DATA}->{NODE}->{1}->{NEXTHOP_IPV4} from TMS for curl load object [$self->{TMS_ALIAS_DATA}->{ALIAS_NAME}]");
            $logger->debug(__PACKAGE__ . ".$sub_name : <-- Leaving sub [0]");
            return 0 ;
        }
     } else {
        if (!defined $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NEXTHOP_IPV6}) {
            $logger->error(__PACKAGE__ . ".$sub_name : unable to get {TMS_ALIAS_DATA}->{NODE}->{1}->{NEXTHOP_IPV6} from TMS for curl load object [$self->{TMS_ALIAS_DATA}->{ALIAS_NAME}]");
            $logger->debug(__PACKAGE__ . ".$sub_name : <-- Leaving sub [0]");
            return 0 ;
       }
    }

    
    foreach('-script_name' , '-ems_obj', '-devicelist' ) {
        unless(defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory input $_ is missing");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my $script = $args{-script_name};
    #Adding the ip route to EMS
    if ($args{-ipv6} ne 'y') {
        $emsip = $args{-ems_obj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
        unless($self->IpRouteUpdate( -DestIp => "$emsip/32" , -Gw => "$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{NEXTHOP_IPV4}"  , -Intf => $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{INTERFACE})) {
            $logger->error(__PACKAGE__ . ".$sub_name: Failed to Update the Route for $emsip");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
            return 0;
        } else {
            $logger->info(__PACKAGE__ . ".$sub_name: Succeffuly added the Route for $emsip}");
        }
    }



    @cmd_res = $self->execCmd("cd $script_path");
    if(grep(/No.*such.*dir*/i, @cmd_res)) {
    $logger->error(__PACKAGE__ . ".$sub_name: $script_path directory not present");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
    return 0;
    }

    #Deleting old result files if any
    $self->execCmd("\\rm nohup*");
    my $cmd = "nohup ./$script $emsip $args{-devicelist}  >> clibackground 2>&1& ";
    #my $cmd = "nohup ./$script $emsip $devicelist[0] $devicelist[1]    $devicelist[2] $devicelist[3] $devicelist[4] $devicelist[5] $devicelist[6] $devicelist[7] $devicelist[8] $devicelist[9] $devicelist[10] $devicelist[11] $devicelist[12] $devicelist[13] $devicelist[14] $devicelist[15] $devicelist[16] $devicelist[17] $devicelist[18] $devicelist[19] $devicelist[20] $devicelist[21] > clibackground 2>&1&";

    $logger->info(__PACKAGE__ . ".$sub_name : Starting CLI load");
    @cmd_res = $self->execCmd("$cmd");
    if(grep(/No.*such.*file*/i, @cmd_res)) {
    $logger->error(__PACKAGE__ . ".$sub_name: $script file not present");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
    return 0;
    }

    unless (@cmd_res ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Unable to start CLI load");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [1]");
    return 1;
}

=head2 stop_cli()

        1) stops the CLI load 
        2) Builds a has table with for all the metrics of cli loadi and prints to cli_nohup_result.csv in the result_path
        3) Calculates the Total of metrics for all the CLI sessions and assigns to $self
            $self->{'Response Time between 0 and 1'}
            $self->{'Response Time between 1 and 3'}
            $self->{'Response Time greater  than 3'}
            $self->{'No of Success'}
            $self->{'No of Failures'}
            $self->{'EMS Switchover time'}
            $self->{'No of failed telnet trials'}
            $self->{'Total Time Taken'}
        4) Caluclates the Max session time among all the CLI sessions and assigns to $self->{'Max Cli Session Time'}
        5) copies the nohup files to ATS repository.
        6) Validates the %age of failures

=over

=item Arguments:
    None

=item Return Value:

    0 - on failure
    1 - on success

=item Usage:

    my $clistop = $cliObj->stop_cli();

=back 

=cut

sub stop_cli {

    my ($self) = @_;
    my $sub_name = "stop_cli";
    my @cmd_res = ();
    my @file_list = ();
    my @summary = ();
    my @queries = ('Response Time between 0 and 1', 'Response Time between 1 and 3' , 'Response Time greater  than 3' , 'No of Success' , 'No of Failures','EMS Switchover time','No of failed telnet trials','Total Time Taken');
    my ($query_res,$file) = ();
    my $script_path = $self->{BASEPATH};
    my $percentoffailures = 0 ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    $logger->info(__PACKAGE__ . ".$sub_name: Killing the process");

    @cmd_res = $self->execCmd("ps -ef | grep test.*.cli | grep -v grep | awk \'{print \$2}\' | xargs kill -2");
    if(grep(/usage/i, @cmd_res)) {
        $logger->error(__PACKAGE__ . ".$sub_name: CLI load not running");
        $self->{'status'}='Stopped';
    } else {
       $logger->info(__PACKAGE__ . ".$sub_name: CLI load is running");
       $self->{'status'}='Running';
    }

    $self->execCmd("cd $script_path");
    @file_list = $self->execCmd("ls -tr1 nohup*");
    chomp (@file_list);
    if(grep(/no.*such.*file.*/i, @file_list)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Result files not present");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    my $file_no = "1";
    my ($result,$fp) = () ;
    open $fp , ">", "$self->{result_path}/cli_nohup_result.csv";
    print $fp "File name   , Success  , Failures  ,Resp Time 0< >1,Resp Time 1< >3,Resp Time > 3 ,Total Time, failed telnet ,EMS Switchover time \n";
    foreach $file (@file_list) {
        foreach(@queries) {
             @cmd_res = $self->execCmd("grep \"$_\" $file | awk -F: \'{ sum+=\$2} END {print sum}\'");
             if ($cmd_res[0] ne '') {
                 $result->{$file_no}->{$_} = $cmd_res[0];
             } else {
                 $result->{$file_no}->{$_} = 0; # when no value retruned from grep ,then  the value is inialisted to 0
             }
        }
        printf $fp "%12s,%10s,%10s,%15s,%15s,%15s,%10s,%15s,%20s\n",$file,$result->{$file_no}->{'No of Success'},$result->{$file_no}->{'No of Failures'},$result->{$file_no}->{'Response Time between 0 and 1'},$result->{$file_no}->{'Response Time between 1 and 3'},$result->{$file_no}->{'Response Time greater  than 3'},$result->{$file_no}->{'Total Time Taken'},$result->{$file_no}->{'No of failed telnet trials'},$result->{$file_no}->{'EMS Switchover time'};
        $file_no++;
    }
    close $fp;
    
    foreach(@queries) {
        @cmd_res = $self->execCmd("grep \"$_\" nohup* | awk -F: \'{ sum+=\$3} END {print sum}\'");
        if ($cmd_res[0] ne '') {
        $query_res = $cmd_res[0];
        } else {
        $query_res = 0; # when no value retruned from grep ,then  the value is inialisted to 0
        }
        if ($_ eq 'EMS Switchover time') {
        $query_res = $query_res/($file_no - 1);
        }
        $logger->info(__PACKAGE__ . ".$sub_name: $_ : $query_res ");
        $self->{$_} = $query_res;
    }
  
  foreach my $key (sort {$result->{$b}->{'Total Time Taken'} <=> $result->{$a}->{'Total Time Taken'}} keys(%$result)) {
     $self->{'Max Cli Session Time'} = $result->{$key}->{'Total Time Taken'};
     last;
  }

    #Printing the summary results of all nohupfiles
    foreach(@queries) {
         $logger->info(__PACKAGE__ . ".$sub_name: Total \" $_ \" = $self->{$_}");
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Max CLI session time among all the CLI sessions :  $self->{'Max Cli Session Time'}");
    $self->{'CPS'} = eval{sprintf "%0.3f",$self->{'No of Success'}/$self->{'Max Cli Session Time'}};

    # Printing the Test case Results to Testcase_Results.txt
    open $fp , ">>", "$self->{result_path}/Testcase_Results.txt";
    print $fp "##########################\n";
    print $fp "CLI Load Summary  \n";
    print $fp "##########################\n";
    print $fp "Total Number of Success = $self->{'No of Success'} \n";
    print $fp "Total Number of Failures = $self->{'No of Failures'} \n";
    print $fp "Total Number of Responses for which Response Time between 0 and 1 = $self->{'Response Time between 0 and 1'} \n";
    print $fp "Total Number of Responses for which Response Time between 1 and 3 = $self->{'Response Time between 1 and 3'} \n";
    print $fp "Total Number of Responses for which Response Time greater  than 3 = $self->{'Response Time greater  than 3'} \n";
    print $fp "CAPS = $self->{'CPS'}\n";
    close $fp;

    #Copying the result sheet to ATS repository.
    my %scpArgs;
    $scpArgs{-hostip} = $self->{OBJ_HOST};
    $scpArgs{-hostuser} = $self->{OBJ_USER};
    $scpArgs{-hostpasswd} = $self->{OBJ_PASSWORD};
    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$script_path/nohup*";
    $scpArgs{-destinationFilePath} = $self->{result_path};
 
    $logger->debug(__PACKAGE__ . ".$sub_name: scp files $scpArgs{-sourceFilePath} to $scpArgs{-destinationFilePath}");
    unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the result files to $self->{result_path}");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    if ($self->{'No of Success'} != 0) {
    $percentoffailures = $self->{'No of Failures'}/($self->{'No of Failures'} + $self->{'No of Success'});
    } else {
        $logger->error(__PACKAGE__ . ".$sub_name: None of the CLI commands are successfull");
        $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
        return 0;
    }

    if ($percentoffailures <= 0.001) {
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [1]");
    return 1;
    } else {
    $logger->error(__PACKAGE__ . ".$sub_name: Percentage of CLI command failures = " . eval{$percentoffailures*100});
    $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
    return 0;
    }
}

=head2 start_psxperf()

    This function starts the psxperf load for the PSX under test
                 1)Shell script which will run the loadgen in a loop
                 2)delete old nohup files
                 3)start_psxperf will call the shellscript and pass the variables(PSX-IP , Cdrfilename , CPS) and redirect the screeno/p to nohup
                 4)return the psxperf_pid

=over

=item Arguments:

    Hash with below deatils
          - Mandatory
                -cdr_name =>CDR name based on the call load type
                -cps => CPS at which load has to be run
                -psx => PSX Object
          - Optional
                -duration - Duration of loadgen to run. If not set default value of 3600 is set
                -warmUp   - If Yes|y|Y, starts the Warmup load. By Default it is Yes
                -overload - If Yesy|y|y , then Final loop correction is not extended for minimum of 10 mins.And Loadgen instances are started immediatley one after the other.When set to N,
                            final Loop correction is done and the loadgen instances are started with a gap of 10 secs
=item Return Value:

    pid - on success
    0 -   on failure

=item Usage:
    my %args = (-cdr_name => "ISUPfilteredCdrLoad.ACT",
                -cps => "2000",-psxip => "10.54.12.144");

   my $pid_result =  $psxperfObj->start_psxperf(-cps => "2000",-psx => $psxObj,-cdr_name => "ISUPfilteredCdrLoad.ACT");

=back

=cut

sub start_psxperf {

    my ($self,%args) = @_;
    my $sub = "start_psxperf";
    my $psxperf_pid = '';
    my @psxperf_pid = ();
    my (@psxperf_res,@cmdres) = ();
    my $No_calls = '';
    my $Loops = '';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $duration = $args{-duration} || 3600;
    my $cmd;
	my $LinuxLoadGen = $self->execCmd("uname -a | grep -i linux |wc -l");#TOOLS-75184
    $args{-warmUp} = (defined $args{-warmUp}) ? $args{-warmUp}:'y';
	$args{-StirShaken} = (defined $args{-StirShaken}) ? $args{-StirShaken}:'No';#TOOLS-75184
    $args{-overload} = (defined $args{-overload}) ? $args{-overload}:'n';
    $args{-overload} = 'n' if ( lc($args{-overload}) eq 'no' );

    $logger->debug(__PACKAGE__ . ".$sub --> Entered Sub ");

    foreach ('-cdr_name','-cps','-psx' )
    {
            unless (defined $args{$_})
            {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
            }
    }

    my $psxObj = $args{-psx};
    my $psxip = $psxObj->{OBJ_HOST};
    my $psxplatform = $psxObj->{PLATFORM};
    my $recrate = (defined $args{-records}) ? $args{-records}:500;
    $logger->info(__PACKAGE__ . ".$sub Setting the Receive Buffer size of Loagen ");
    $self->execCmd('ndd -set /dev/udp  udp_recv_hiwat 1720320'); 
#Capturing the netstat -s output
    unless ( @cmdres = $self->execCmd("netstat -s") ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed \"netstat -s\", data maybe incomplete, result: " . Dumper(\@cmdres));
    }
    $logger->info(__PACKAGE__ . "$sub The netsat output " . Dumper(\@cmdres)) ;

    $self->{'udpInOverFlowBeforeLoad'} = 0;
    foreach my $line (0 ..$#cmdres) {
        if ( ($cmdres[$line] =~ m/([0-9]+)[\s]+packet receive errors/i) || ( $cmdres[$line] =~ m/.*udpInOverflows[\s]+=[\s]*([0-9]+)/i)) {
            $self->{'udpInOverFlowBeforeLoad'} += $1;
        }
    }

    $logger->info(__PACKAGE__ . ".$sub changing the directory ");
    @psxperf_res = $self->execCmd("cd $self->{'BASEPATH'}");
    if(grep ( /no.*such/i, @psxperf_res))
      {
        $logger->error(__PACKAGE__ . ".$sub psxperf directory not present");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
      }

     @psxperf_res = $self->execCmd('export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib');
    if(grep ( /no.*such/i, @psxperf_res))
     {
        $logger->error(__PACKAGE__ . ".$sub library path sourcing failed");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
      }
    $logger->debug(__PACKAGE__ . ".$sub exported library path ");

    #checking if any old instance of psxperf  is running
    $cmd = 'ps -ef | grep ' . "$self->{'BASEPATH'}" . 'psxperf.sh | grep -v grep ' . ' | awk \'{print $2}\'';
    my @old_psxperf = $self->execCmd($cmd);
    unless ($old_psxperf[0]){
       $logger->debug(__PACKAGE__ . ".$sub: No Old instance of psxperf running");
    } else {
    for my $psxperf (@old_psxperf) {
       $logger->error(__PACKAGE__ . ".$sub: Old psxperf running on pid : $psxperf");
       $logger->error(__PACKAGE__ . ".$sub: Killing the old psxperf on pid : $psxperf");
        $self->execCmd("kill -9 $psxperf");
    }
        sleep 10;
    }

    #checking if any old instance of loadGen is running
    $cmd = 'ps -ef | grep ' . "$self->{'BASEPATH'}" . 'loadGen | grep -v grep ' . ' | awk \'{print $2}\'';
    my @old_loadGen = $self->execCmd($cmd);
    unless ($old_loadGen[0]){
       $logger->debug(__PACKAGE__ . ".$sub: No Old instance of loadGen loader running");
    } else {
    for my $loadgen (@old_loadGen) {
       $logger->error(__PACKAGE__ . ".$sub: Old loadGen Loader running on pid : $loadgen");
       $logger->error(__PACKAGE__ . ".$sub: Killing the old loadGen loader on pid : $loadgen");
        $self->execCmd("kill -9 $loadgen");
        }
    sleep 10;
    }
    #Deleting old result files if any
    $self->execCmd("rm -f nohup*");
    $logger->debug(__PACKAGE__ . ".$sub removed old nohup files ");
    sleep 5;

    #Copying the psxpperf.sh to the loadgen machine and chaging the permissions
    my %scpArgs;
    $scpArgs{-hostip} = $self->{OBJ_HOST};
    $scpArgs{-hostuser} = $self->{OBJ_USER};
    $scpArgs{-hostpasswd} = $self->{OBJ_PASSWORD};
	$scpArgs{-sourceFilePath} = "/ats/tools/perf/psxperf.sh";
    $scpArgs{-destinationFilePath} = "$self->{OBJ_HOST}" . ":" . "$self->{BASEPATH}" . "/";

     unless(&SonusQA::Base::secureCopy(%scpArgs)){
     $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the psxperf.sh to $self->{BASEPATH} ");
     } else {
     $logger->info(__PACKAGE__ . ".$sub: Successfuly copied the psxperf.sh to $self->{BASEPATH} ");
     }
     $self->execCmd("chmod 755 psxperf.sh");
   
    #Starting the Load Gen at 10% of the defined CPS
    my ($initialCPS,$NumOfCalls)=0;
    if ( $args{-warmUp} =~ m/[y](es)?/i) {
        $logger->debug(__PACKAGE__ . ".$sub: Warmup Load flag is enabled, so starting the warmup");
        for ( my $temp=10 ; $temp<= 30 ; $temp=$temp+10) {
            $initialCPS = int($args{-cps} * $temp/100);
            $NumOfCalls = int($initialCPS * 300);
            $logger->info(__PACKAGE__ . ".$sub  warmup loadgen started at $temp\% for CPS=$initialCPS , Number of calls=$NumOfCalls and waiting for 400 secs");
            if ( $LinuxLoadGen ) {				#LinuxLoadGen #TOOLS-75184
				if ( $args{-StirShaken} =~ m/Yes/i) {
				    $logger->debug(__PACKAGE__ . ".$sub: StirShaken flag is enabled. -StirShaken = $args{-StirShaken} ");
					$cmd = "nohup $self->{'BASEPATH'}" .  "loadGen -h $psxip -a $args{-cdr_name} -id 2 -r $initialCPS -n $NumOfCalls -fr $NumOfCalls -ssv 11.2 -stsh -rn 1 -o nohup_temp" . "$temp.out 2>&1& ";
				} else {
					$cmd = "nohup $self->{'BASEPATH'}" .  "loadGen -h $psxip -a $args{-cdr_name} -id 2 -r $initialCPS -n $NumOfCalls -fr $NumOfCalls -frt 15000 -srt 15000 -rn 1 -o nohup_temp" . "$temp.out 2>&1& ";
				}
			} else {															   #SolarisLoadGen #TOOLS-75184
				if ( $args{-StirShaken} =~ m/Yes/i) {
				    $logger->error(__PACKAGE__ . ".$sub: StirShaken flag is enabled and Stir Shaken is not supported on Solaris LoadGen. Cannot continue Testcase Execution . Testcase Failed ");
					return 0;
				} else {
            $cmd = "nohup $self->{'BASEPATH'}" .  "loadGen -h $psxip -a $args{-cdr_name} -id 2 -r $initialCPS -n $NumOfCalls -fr $NumOfCalls -frt 15000 -srt 15000 -rn 1 -s $recrate > nohup_temp" . "$temp.out 2>&1& ";
			    }
			}	
            $self->execCmd($cmd);
            sleep 400;
        }    
    } else {
        $logger->debug(__PACKAGE__ . ".$sub: Warmup Load flag is disabled. So not running the warmup load");
    }

    #Calculating the number of instances based on Platform and CPS. Till 9.2 , linux was allways using 2 instances.From 9.3 we support more than 5000 cps because of optimisation in SUT code.
    #So we have to maintain number of instances accordingly
    my ($cps,$numberOfInstance,$loadgenMaxCpsSupported) = (0,0,2500);
    if ( $psxplatform eq 'SunOS' ) {
        $numberOfInstance = 1;
    } elsif (($psxplatform eq 'linux') && ($args{-cps} <= 5000) ) {
        $numberOfInstance = 2;
    } else {
        if ( $args{-cps}%$loadgenMaxCpsSupported > 0 ) { 
            $numberOfInstance = int($args{-cps}/$loadgenMaxCpsSupported) + 1;
        } else {
           $numberOfInstance = int($args{-cps}/$loadgenMaxCpsSupported);
        }
    }
    $cps = int($args{-cps}/$numberOfInstance); 

    #numberOfInstance is used in stop_psxperf
    $self->{'numberOfInstance'} = $numberOfInstance;

    # Starting the psxperf
	if ( $args{-StirShaken} =~ m/Yes/i) { #TOOLS-75184
	    $logger->debug(__PACKAGE__ . ".$sub: StirShaken flag is enabled");
		$cmd = 'nohup ' . "$self->{'BASEPATH'}" . "psxperf.sh  $cps $psxip $args{-cdr_name}  $duration  $psxplatform  $self->{'numberOfInstance'} $args{-overload} $recrate 1 > nohup.out 2>&1& ";
	} else {
		$cmd = 'nohup ' . "$self->{'BASEPATH'}" . "psxperf.sh  $cps $psxip $args{-cdr_name}  $duration  $psxplatform  $self->{'numberOfInstance'} $args{-overload} $recrate 0 > nohup.out 2>&1& ";
	}
	$logger->info(__PACKAGE__ . ".$sub: The CPS/Instance of LoadGen = $cps , Number of Instance = $numberOfInstance, Overload Flag = $args{-overload} , Totals cps = " . eval {$cps*$self->{'numberOfInstance'}} . ",Record Stats =$recrate" . ",STIR-SHAKEN Flag =$args{-StirShaken}" );
    $logger->info(__PACKAGE__ . ".$sub: Starting the PSXperf as \"$cmd\" ");
    $self->execCmd($cmd);
    sleep 5;
    $cmd = 'ps -ef | grep ' . "$self->{'BASEPATH'}" . 'psxperf.sh | grep -v grep ' . ' | awk \'{print $2}\'';
    unless(@psxperf_pid = $self->execCmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub Could not start psxperf");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
     }
     $logger->debug(__PACKAGE__ . ".$sub started psxperf");
     $logger->info(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
     $psxperf_pid=$psxperf_pid[0];
     return  $psxperf_pid;
     }
=head2 stop_psxperf()

    This function stops the psxperf load for the PSX under test
                   1) checks if the PID still exists, if yes kills it
                   2) Dumps last 10 lines of the file
                   3) Builds seperate  Metrics for non wamrup loads and total loads
                   4) Prints thes metrics to nohup_result.txt and copies to loadgen machine
                   5) Checks the  %age of actual load drop calls and returns success if drop/total calls <0.00001

=over

=item Arguments:

    Hash with below deatils
          - Mandatory
                -psxperf_pid =>PID value of the script
                -cps => CPS at which load has to be run
=item Return Value:

    1 - on  success
    0 - on  failure
    Assigns the metrics to psxperf obj
    $self->{'Sent'}= $total_sent;
    $self->{'Dropped'}=$total_drop;
    $self->{'RequestRate'}=$total_request_rate;
    $self->{'ResponseRate'}=$total_response_rate;
    $self->{'RoutingLabelMismatch'}=$total_routlabel_mismatch;
    $self->{'ResponseDelay'}=$avg_resp_delay;
    $self->{'StdDevResponseDelay'}=$sd_resp_delay;
    $self->{'95PercentileResponseDelay'}=$per95_resp_delay;
    $self->{'MaxResponseDelay'}=$max_avg_response;
    $self->{'Retransmitted'}=$total_retransmitted;
    $self->{'SentNoWarmup'}= $total_sent_nowarmup;
    $self->{'DroppedNoWarmup'}=$total_drop_nowarmup;
    $self->{'RoutingLabelMismatchNoWarmup'}=$total_routlabel_mismatch_nowarmup;
    $self->{'RetransmittedNoWarmup'}=$total_retransmitted_nowarmup;


=item Usage:

    my %args = (-psxperf_pid => "$psxperf_pid",
                -cps => "2000");

    my $result = $psxperfObj->stop_psxperf(-psxperf_pid => $pid_result,-cps => "2000",-psx => $psxObj);

=back

=cut

sub stop_psxperf{

    my ($self,%args) = @_;
    my $sub = "stop_psxperf";
    my ($total_sent,$WarmUpLoadcalls,$total_drop,$total_routlabel_mismatch,$total_retransmitted,$avg_resp_delay,$sd_resp_delay,$per95_resp_delay,$max_avg_response,$total_request_rate)=(0,0,0,0,0,0,0,0,0,0);
    my ($total_response_rate,$sent,$drop,$request_rate,$response_rate,$complete_nohup,$numberOfTempLoadFiles)=(0,0,0,0,0,0,0);
    my ($total_sent_nowarmup,$total_drop_nowarmup,$total_routlabel_mismatch_nowarmup,$total_retransmitted_nowarmup,$cmd,$stat)=(0,0,0,0,0,0);
    my @pid_exists = ();
    my $psxperf_pid ='';
    my @nohup_array=();
    my @nohup_result=();
    my @totalarray;
    my @cmdres;
	my $LinuxLoadGen = $self->execCmd("uname -a | grep -i linux |wc -l");
    require Statistics::Descriptive;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub  --> Entered Sub ");
    foreach('-psxperf_pid' ,'-cps','-psx' )
    {
        unless(defined $args{$_})
         {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory input $_ is missing");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
            return 0;
         }
    }

#checking if any old instance of psxperf is running   
   $psxperf_pid = $args{-psxperf_pid};
   $logger->info(__PACKAGE__ . ".$sub: Checking if old psxperf is still running");
   @cmdres=$self->execCmd("kill -9 $psxperf_pid ");
   if(grep ( /no.*such/i, @cmdres))
     {
        $logger->info(__PACKAGE__ . ".$sub: psxperf not running");
    } else {
      $logger->info(__PACKAGE__ . ".$sub: found psxperf still running");
      @pid_exists = $self->execCmd("ps -p $psxperf_pid | grep $psxperf_pid");
        if($pid_exists[0] =~ $psxperf_pid)
        {
                $logger->error(__PACKAGE__ . ".$sub: Failed to kill psxperf load" );
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        } else {
                $logger->info(__PACKAGE__ . ".$sub: killed psxperf successfully ");
        }
  }

#checking if any old instance of loadGen is running
    $cmd = 'ps -ef | grep ' . "$self->{'BASEPATH'}" . 'loadGen | grep -v grep ' . ' | awk \'{print $2}\'';
    my @old_loadGen = ();
    for ( my $i = 0 ; $i <= 5 ; $i++) {
        @old_loadGen = $self->execCmd($cmd);
        unless ($old_loadGen[0]){
           $logger->debug(__PACKAGE__ . ".$sub: loadGen  instance is not  running,so start processing the records for summary");
           last;
        } else {
            if ( $i >= 5 ) {
                for my $loadgen (@old_loadGen) {
                   $logger->error(__PACKAGE__ . ".$sub: LoadGen instance running on pid : [$loadgen]. Killing the same");
                   $self->execCmd("kill -9 $loadgen");
                }
                last;
            } else {
                 $logger->info(__PACKAGE__ . ".$sub: LoadGen instance is still running. Already waited for " . eval {$i*120} . " Secs.Sleeping for additional 120 secs");
                 sleep 120;
            }
        }
    }
    sleep 10;

#Capturing the netstat -s output
    unless ( @cmdres = $self->execCmd("netstat -s") ) {
        $logger->error(__PACKAGE__ . "$sub Remote command execution failed \"netstat -s\", data maybe incomplete, result: " . Dumper(\@cmdres));
    }
    $logger->info(__PACKAGE__ . "$sub The netsat output " . Dumper(\@cmdres)) ;
    $self->{'udpInOverFlowAfterLoad'} = 0;
    foreach my $line (0 ..$#cmdres) {
        if ( ($cmdres[$line] =~ m/([0-9]+)[\s]+packet receive errors/i) || ( $cmdres[$line] =~ m/.*udpInOverflows[\s]+=[\s]*([0-9]+)/i)) {
            $self->{'udpInOverFlowAfterLoad'} += $1;
        }
    }
   
   $self->execCmd("cd $self->{BASEPATH}");
   $logger->info(__PACKAGE__ . ".$sub: changed the directory ");
   my $nohup_cmd  = ($LinuxLoadGen)?"ls -lrt nohup*log | awk \'{print $9}\'":"ls -lrt nohup* | awk \'{print $9}\'"; #TOOLS-75184
   @nohup_array = $self->execCmd($nohup_cmd);
   my $i=0;
   my $result;

#Metrics of LoadGen we are interested for
my @metrics = ('Total number of sent requests so far' , 'Total number of retransmitted requests so far' , 'Total number of dropped requests so far' , 'Simulation duartion so far' , 'Request Rate' ,'Response Rate' , 'Policy Request Drop Rate');

#parsing the nohup files and building a hash table
    foreach my $nohup (@nohup_array)
     {
     if ($nohup ne 'nohup.out' ){
     @nohup_result = $self->execCmd("tail -10 $nohup");
     $logger->info(__PACKAGE__ . ".$sub:Last 10 lines are of $nohup" . Dumper(\@nohup_result));
     $result->{'Nohup File Name'}->{$i} = $nohup;
    
     foreach my $LoadgenMetric (@metrics) {
        $cmd = 'grep ' . "\'$LoadgenMetric\'" ." $nohup" . ' | tail -1 ' . '  | awk -F":" ' . ' \'{ print $2 }\'';
        @cmdres = $self->execCmd($cmd);
        $result->{$LoadgenMetric}->{$i}=$cmdres[0];
     }
      
     $cmd = 'grep "Number of Routing Label Mismatch:"' ." $nohup" .'  | awk -F":" ' . '\'{ sum += $2 } END{ print sum }\'';
     @cmdres = $self->execCmd($cmd);
     $result->{'Number of Routing Label Mismatch'}->{$i}=$cmdres[0];
     
     $cmd =  ' grep "Average Response Delay" ' . " $nohup" . ' | awk -F":" \'BEGIN {i = 0} {TotalRespTime += $2 ; i++} END {AvgRespTime = TotalRespTime/i ; print AvgRespTime }\'';
     @cmdres = $self->execCmd($cmd);
     $result->{'Average Response Delay'}->{$i}=$cmdres[0];

     $cmd = 'grep "Average Response Delay" ' . "$nohup" . '  | awk -F":" \'{print $2}\'';
     @cmdres = $self->execCmd($cmd);
     $stat=Statistics::Descriptive::Full->new();
     $stat->add_data(@cmdres);
     $result->{'Standard Deviation in Response Delay'}->{$i}=$stat->standard_deviation();
     $result->{'95 percentile value in Response Delay'}->{$i}=$stat->percentile(95);
     $result->{'Max Response Delay'}->{$i}=$stat->max();
     push (@totalarray,@cmdres) if (!($result->{'Nohup File Name'}->{$i} =~ m/temp/i)) ; #ignoring the values from warmup load
     $i++;
     }
     }
#Calculating the Statistics/Avg values for delay for overal run
    $stat=Statistics::Descriptive::Full->new();
    $stat->add_data(@totalarray);
    $sd_resp_delay = $stat->standard_deviation();
    $per95_resp_delay = $stat->percentile(95);  
    $max_avg_response = $stat->max();
     for ($i = 0 ; $i <= $#nohup_array; $i++ )
     {
     $complete_nohup++ if ($result->{'Total number of sent requests so far'}->{$i} != 0); #Ignoring the Invalid Loadgen output 
     $numberOfTempLoadFiles++ if ($result->{'Nohup File Name'}->{$i} =~ m/temp/i); 
     $total_sent=$total_sent + $result->{'Total number of sent requests so far'}->{$i};
     $WarmUpLoadcalls = $WarmUpLoadcalls + $result->{'Total number of sent requests so far'}->{$i} if ($result->{'Nohup File Name'}->{$i} =~ m/temp/i); #considering only temp files
     $total_drop=$total_drop + $result->{'Total number of dropped requests so far'}->{$i};
     $total_routlabel_mismatch=$total_routlabel_mismatch + $result->{'Number of Routing Label Mismatch'}->{$i};
     $total_retransmitted=$total_retransmitted + $result->{'Total number of retransmitted requests so far'}->{$i};
     #Getting the seperate Metrics for Actual load, execluding warmup loads
     if (!($result->{'Nohup File Name'}->{$i} =~ m/temp/i)) {
        $total_request_rate=$total_request_rate + $result->{'Request Rate'}->{$i};
        $total_response_rate=$total_response_rate + $result->{'Response Rate'}->{$i};
        $avg_resp_delay=$avg_resp_delay + ( $result->{'Total number of sent requests so far'}->{$i} * $result->{'Average Response Delay'}->{$i});
        $total_sent_nowarmup=$total_sent_nowarmup + $result->{'Total number of sent requests so far'}->{$i};
        $total_drop_nowarmup=$total_drop_nowarmup + $result->{'Total number of dropped requests so far'}->{$i};
        $total_routlabel_mismatch_nowarmup=$total_routlabel_mismatch_nowarmup + $result->{'Number of Routing Label Mismatch'}->{$i};
        $total_retransmitted_nowarmup=$total_retransmitted_nowarmup + $result->{'Total number of retransmitted requests so far'}->{$i};
        }
     }

     #Finding the psx platform type
     my $psxObj = $args{-psx};
     my $psxplatform = $psxObj->{PLATFORM};

     
     #Avergaing and Multiplying by numberOfInstance of loadgen.Ignoring the nohup_temp1.out,nohup_temp2.out,nohup_temp3.out in the length of array
     $total_request_rate=($total_request_rate/($complete_nohup - $numberOfTempLoadFiles))*$self->{'numberOfInstance'}; 
     $total_response_rate=($total_response_rate/($complete_nohup - $numberOfTempLoadFiles))*$self->{'numberOfInstance'};

     $avg_resp_delay=$avg_resp_delay/($total_sent - $WarmUpLoadcalls); #Ignoring the calls in nohup_temp10.out,nohup_temp20.out,nohup_temp30.out
     $logger->info(__PACKAGE__ . ".$sub :Total number of sent requests so far = $total_sent");
     $logger->info(__PACKAGE__ . ".$sub :Total number of dropped requests so far = $total_drop");
     $logger->info(__PACKAGE__ . ".$sub :Request Rate (request/Sec) =" .  int($total_request_rate));
     $logger->info(__PACKAGE__ . ".$sub :Response Rate (responses/Sec) =" .  int($total_response_rate));
     $logger->info(__PACKAGE__ . ".$sub :Number of Routing Label Mismatch = $total_routlabel_mismatch");
     $logger->info(__PACKAGE__ . ".$sub :Average Response Delay =" .  int($avg_resp_delay));
     $logger->info(__PACKAGE__ . ".$sub :Total number of retransmitted requests so far = $total_retransmitted");
     
     $logger->info(__PACKAGE__ . ".$sub :Total number of sent requests so far ,excluding warmuploads = $total_sent_nowarmup");
     $logger->info(__PACKAGE__ . ".$sub :Total number of dropped requests so far,excluding warmuploads  = $total_drop_nowarmup");
     $logger->info(__PACKAGE__ . ".$sub :Number of Routing Label Mismatch,excluding warmuploads  = $total_routlabel_mismatch_nowarmup");
     $logger->info(__PACKAGE__ . ".$sub :Total number of retransmitted requests so far,excluding warmuploads  = $total_retransmitted_nowarmup");

   
     #Printing the stats to nohup_result.txt in local server 
     my $fp; # File handler
     open $fp , ">", "nohup_result.txt"; #Creating the nohup_recult.txt file to print all the collected metrics

     for ($i = 0 ; $i <= $#nohup_array; $i++ )
     {
         print $fp eval{'Nohup File Name = ' . "$result->{'Nohup File Name'}->{$i}\n"};
         print $fp eval{'Total number of sent requests so far = '. "$result->{'Total number of sent requests so far'}->{$i}\n"};
         print $fp eval{'Total number of retransmitted requests so far = '. "$result->{'Total number of retransmitted requests so far'}->{$i}\n"};
         print $fp eval{'Total number of dropped requests so far = '. "$result->{'Total number of dropped requests so far'}->{$i}\n"};
         print $fp eval{'Total Number of Routing Label Mismatch = '. "$result->{'Number of Routing Label Mismatch'}->{$i}\n"};
         printf $fp "Response Delay Avg = %.2f,", $result->{'Average Response Delay'}->{$i};
         printf $fp " Std Dev = %.2f,", $result->{'Standard Deviation in Response Delay'}->{$i};
         printf $fp " 95 percentile  = %.2f,", $result->{'95 percentile value in Response Delay'}->{$i};
         printf $fp " Max = %.5f \n", $result->{'Max Response Delay'}->{$i};
         print $fp eval{'Simulation duartion so far = '. "$result->{'Simulation duartion so far'}->{$i}\n"};
         print $fp eval{'Request Rate = '. "$result->{'Request Rate'}->{$i}\n"};
         print $fp eval{'Response Rate = '. "$result->{'Response Rate'}->{$i}\n"};
         print $fp eval{'Policy Request Drop Rate = '. "$result->{'Policy Request Drop Rate'}->{$i}\n"};
         print $fp "======================================================\n\n\n";
     }
     
     print $fp "Summary statistics: \n";
     print $fp "Total number of sent requests so far = $total_sent \n";
     print $fp "Total number of dropped requests so far = $total_drop \n";
     print $fp eval{"Request Rate (request/Sec) =" .  int($total_request_rate) . " \n"};
     print $fp eval{"Response Rate (responses/Sec) =" . int($total_response_rate) . " \n"};
     print $fp "Number of Routing Label Mismatch = $total_routlabel_mismatch \n";
     print $fp eval{"Average Response Delay = " . int($avg_resp_delay) . "\n"};
     print $fp "Total number of retransmitted requests so far = $total_retransmitted \n";
     print $fp "======================================================\n\n\n";
     print $fp "Summary statistics excluding Warmup Loads: \n";
     print $fp "Total number of sent requests so far excluding warmup loads = $total_sent_nowarmup \n";
     print $fp "Total number of dropped requests so far excluding warmup loads  = $total_drop_nowarmup \n";
     print $fp eval{"Request Rate (request/Sec) excluding warmup loads  =" .  int($total_request_rate) . " \n"};
     print $fp eval{"Response Rate (responses/Sec) excluding warmup loads  =" . int($total_response_rate) . " \n"};
     print $fp "Number of Routing Label Mismatch excluding warmup loads  = $total_routlabel_mismatch_nowarmup \n";
     print $fp eval{"Average Response Delay excluding warmup loads  = " . int($avg_resp_delay) . "\n"};
     printf $fp "Standard Deviation of Response Delay, excluding warmpup  = %.2f \n" , $sd_resp_delay;
     printf $fp "95 percentile value of Response Delay, excluding warmpup =   %.2f \n" , $per95_resp_delay ;
     printf $fp "Maximum Value of Response Delay, excluding warmpup  =  %.5f \n",  $max_avg_response ; 
     print $fp "Total number of retransmitted requests so far = $total_retransmitted_nowarmup \n";
     print $fp "======================================================\n\n\n";
     print $fp "Loadgen Machine statistics\n";
     print $fp "UdpBufferOverFlow Before Start of Load = $self->{'udpInOverFlowBeforeLoad'} , UdpBufferOverFlow at the end of Load = $self->{'udpInOverFlowAfterLoad'}, ";
     printf $fp "Udp Packet Loss at Loadgen Machine = %.0f \n" , ($self->{'udpInOverFlowAfterLoad'}-$self->{'udpInOverFlowBeforeLoad'}) ;
     close $fp;

    #Setting the Metrics to the object
    $self->{'Sent'}= $total_sent;
    $self->{'Dropped'}=$total_drop;
    $self->{'RequestRate'}=$total_request_rate;
    $self->{'ResponseRate'}=$total_response_rate;
    $self->{'RoutingLabelMismatch'}=$total_routlabel_mismatch;
    $self->{'ResponseDelay'}=$avg_resp_delay;
    $self->{'StdDevResponseDelay'}=$sd_resp_delay;
    $self->{'95PercentileResponseDelay'}=$per95_resp_delay;
    $self->{'MaxResponseDelay'}=$max_avg_response;
    $self->{'Retransmitted'}=$total_retransmitted; 
    $self->{'SentNoWarmup'}= $total_sent_nowarmup;
    $self->{'DroppedNoWarmup'}=$total_drop_nowarmup;
    $self->{'RoutingLabelMismatchNoWarmup'}=$total_routlabel_mismatch_nowarmup;
    $self->{'RetransmittedNoWarmup'}=$total_retransmitted_nowarmup;
 
    
    #currently SCPing the files to loadgen server as all the nohup files are copied to /sonus/issue/PerfTest from the test scrripst
    my %scpArgs;
    $scpArgs{-hostip} = $self->{OBJ_HOST};
    $scpArgs{-hostuser} = $self->{OBJ_USER};
    $scpArgs{-hostpasswd} = $self->{OBJ_PASSWORD};
    $scpArgs{-sourceFilePath} = "nohup_result.txt";
    $scpArgs{-destinationFilePath} = "$self->{OBJ_HOST}" . ":" ."$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH}";
     
     unless(&SonusQA::Base::secureCopy(%scpArgs)){
     $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the nohup_result.txt to $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH} ");
     } else {
     $logger->info(__PACKAGE__ . ".$sub: Successfuly copied the nohup_result.txt to $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH} ");
     }

    my($drop_percentage,$response_rate_percentage);
    #Caluclating drop &  response rate  percentage
    if( $total_sent_nowarmup  and $args{'-cps'}){
     $drop_percentage = ($total_drop_nowarmup/$total_sent_nowarmup)*100;
     $response_rate_percentage = ($total_response_rate/$args{'-cps'})*100;
     }else{
      $logger->error(__PACKAGE__ . ".$sub: The drop rate 0");
      $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
     return 0;
      }
     #Veridct declaration
     if ($total_drop_nowarmup > eval{sprintf "%0.5f",0.00001*$total_sent_nowarmup})
     {
      $logger->error(__PACKAGE__ . ".$sub: The drop percentage  is $drop_percentage and number of dropped calls are $total_drop_nowarmup ");
      $logger->error(__PACKAGE__ . ".$sub: Failed to meet 99.999% pass criterion");
      $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
      return 0;
     }
     else {
      $logger->info(__PACKAGE__ . "returning the total sent value = $total_sent_nowarmup");
      $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
      return $total_sent_nowarmup;
     }
}

=head2 start_dns()

 This Function stops ,changes the TTL value for e164,DNS and starts the named service

=over

=item Arguments:
   -TTLENUM=>300 ; #TTL value of ENUM
   -TTLDNS=> 0; #TTL value fro DNS
   If not set , then it assumes 86400 as the TTL values for these services

=item Return Value:

    1 - on  success
    0 - on  failure

=item Usage:

=back

=cut


sub start_dns{
my ($self,%args) = @_;
    my $sub = "start_dns";
    my @enumdns_res = ();
    my $cmd = '';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub  --> Entered Sub ");

#setting the TTL values based on argugments
$args{-TTLENUM} = (defined $args{-TTLENUM}) ? $args{-TTLENUM}:86400;
$args{-TTLDNS} = (defined $args{-TTLDNS}) ? $args{-TTLDNS}:86400;

#checking the directory path
 @enumdns_res = $self->execCmd("cd $self->{'BASEPATH'}");
    if(grep ( /no.*such/i, @enumdns_res))
      {
        $logger->error(__PACKAGE__ . ".$sub /var/named directory not present");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
      }

      $logger->debug(__PACKAGE__ . ".$sub changed the  path to /var/named");

#stopping the named service

     @enumdns_res = $self->execCmd('service named stop');
    if(grep ( /FAILED/i, @enumdns_res))
     {
        $logger->error(__PACKAGE__ . ".$sub stopping the named service failed ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
      }
    $logger->debug(__PACKAGE__ . ".$sub stopping the named service succeded ");

#changing the TTL values
    @enumdns_res = $self->execCmd('grep \'^$TTL\' sonusenum.com.zone');
    $logger->info(__PACKAGE__ . ".$sub:The Current TTL value in sonusenum.com.zone before changning ". Dumper(\@enumdns_res));
    $cmd='sed -i \'s/^$TTL [0-9]*/$TTL ' . "$args{-TTLDNS}" . '/1\' sonusenum.com.zone';
    @enumdns_res = $self->execCmd($cmd);
    $cmd = 'grep -c \'^$TTL ' . "$args{-TTLDNS}"  . '\' sonusenum.com.zone';
    @enumdns_res = $self->execCmd($cmd);
    if($enumdns_res[0] == 1 ) {
       $logger->info(__PACKAGE__ . ".$sub: The TTL value in sonusenum.com.zone is changed to: $args{-TTLDNS}");
    } else {
       $logger->error(__PACKAGE__ . ".$sub: The TTL value could not be chnaged in sonusenum.com.zone");
       return 0;
    }

    @enumdns_res = $self->execCmd('grep \'^$TTL\' master.1.e164.arpa');
    $logger->info(__PACKAGE__ . ".$sub:The Current TTL value in master.1.e164.arpa before changning ". Dumper(\@enumdns_res));
    $cmd='sed -i \'s/^$TTL [0-9]*/$TTL ' . "$args{-TTLENUM}" . '/1\' master.1.e164.arpa';
    @enumdns_res = $self->execCmd($cmd);
    $cmd = 'grep -c \'^$TTL ' . "$args{-TTLENUM}"  . '\' master.1.e164.arpa';
    @enumdns_res = $self->execCmd($cmd);
    if($enumdns_res[0] == 1 ) {
       $logger->info(__PACKAGE__ . ".$sub: The TTL value in master.1.e164.arpa is changed to: $args{-TTLENUM}");
    } else {
       $logger->error(__PACKAGE__ . ".$sub: The TTL value could not be chnaged in master.1.e164.arpa");
       return 0;
    }




#starting the named service

 @enumdns_res = $self->execCmd('service named start');
    if(grep ( /FAILED/i, @enumdns_res))
     {
        $logger->error(__PACKAGE__ . ".$sub starting of the named service failed ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
      }
    $logger->debug(__PACKAGE__ . ".$sub starting the named service succeded ");

#checking the named status
   @enumdns_res = $self->execCmd('service named  status | grep "named (pid "  | grep "is running"');
    if(grep ( /STOPPED/i, @enumdns_res))
     {
        $logger->error(__PACKAGE__ . ".$sub  named service is not running ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
      }
    $logger->debug(__PACKAGE__ . ".$sub  named service is running ");


#Returning success
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return 1;

}

=head2 loadgen_scp()

        This Function creates a Result file with  Loadgen Metrics and do scp to copy the file to the specified destination.

=over

=item Arguments:

        -dest = destination file 
        -orgi = source path 

=item Return Value:

    1 - on  success
    0 - on  failure

=item Usage:

=back

=cut

sub loadgen_scp {
my ($self,%args) = @_;
my $sub = ".loadgen_scp";
my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
my @cmd_res = ();

$logger->debug(__PACKAGE__ . ".$sub  --> Entered Sub ");

unless ( defined ( $args{-dest} ) ) {
    $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -dest has not been specified or is blank.");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0;
}

unless ( defined ( $args{-orig} ) ) {
    $logger->error(__PACKAGE__ . ".$sub:  The mandatory argument for -orig has not been specified or is blank.");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
    return 0;
}

   #Printing the Loadgen Metrics to the result file.All object varibales are set in stop_psxperf
    my $fp;
    open $fp , ">>", "$args{-dest}/Result/Testcase_Results.txt";
    print $fp "##########################################################\n";
    print $fp "#      Loadgen Metrics Excluding Warmupload              #\n";
    print $fp "##########################################################\n";
    print $fp "Total number of sent requests            = $self->{'SentNoWarmup'} \n";
    print $fp "Total number of dropped requests         = $self->{'DroppedNoWarmup'} \n";
    print $fp eval{"Request Rate (request/Sec)          = " .  int($self->{'RequestRate'}) . " \n"};
    print $fp eval{"Response Rate (responses/Sec)       = " . int($self->{'ResponseRate'}) . " \n"};
    print $fp "Number of Routing Label Mismatch         = $self->{'RoutingLabelMismatchNoWarmup'} \n";
    printf $fp "Response Delay Avg = %.0f, Std Dev = %.2f , 95ile = %.2f , Max = %.2f \n", $self->{'ResponseDelay'},$self->{'StdDevResponseDelay'},$self->{'95PercentileResponseDelay'},$self->{'MaxResponseDelay'} ;
    print $fp "Total number of retransmitted requests   = $self->{'RetransmittedNoWarmup'} \n";
    printf $fp "Udp Packet Loss at Loadgen Machine = %.0f \n" , ($self->{'udpInOverFlowAfterLoad'}-$self->{'udpInOverFlowBeforeLoad'}) ;
    close $fp;

my $timestamp = strftime("%Y%m%d%H%M%S",localtime);
my $orig = $args{-orig};
my $dest = $args{-dest}."/loadGen_DATA_$timestamp/";


@cmd_res = $self->execCmd("cd $orig ; ls");
if(grep ( /no.*such/i, @cmd_res)) {
    $logger->error(__PACKAGE__ . ".$sub $orig directory not present");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
    return 0;
}
     $logger->debug(__PACKAGE__ . ".$sub Changed working directory to $orig");

$logger->info(".$sub Creating dir : $dest");
unless (mkpath($dest)) {
    $logger->error(__PACKAGE__ . ".$sub:  Failed to create dir: $dest");
}


    my %scpArgs;
    $scpArgs{-hostip} = $self->{OBJ_HOST};
    $scpArgs{-hostuser} = $self->{OBJ_USER};
    $scpArgs{-hostpasswd} = $self->{OBJ_PASSWORD};
    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$orig/nohup*";
    $scpArgs{-destinationFilePath} = $dest;

    $logger->debug(__PACKAGE__ . ".$sub: scp files $scpArgs{-sourceFilePath} to $scpArgs{-destinationFilePath}");
    unless(&SonusQA::Base::secureCopy(%scpArgs)){
       $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the result files to $dest");
       $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
       return 0;
    }

$logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [1]");
return 1;
}

=head2 restartAndCheckStatus()

    This function delete the zone file created.

=over

=item Arguments:

   -domainName  => domain name

=item Return Value:

    1 - on success

=item Usage:

    $Obj->restartAndCheckStatus(-domainName => 'ram.com');

=back

=cut

sub restartAndCheckStatus {
    my($self, %args)=@_;
    my $sub_name = 'restartAndCheckStatus';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");

    unless(defined $args{-domainName}) {
        $logger->error(__PACKAGE__ . ".$sub_name: manditory argument \"-domainName\" is empty");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
        return 0;
    }

    unless ($self->execCmd('service named restart')) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed  to restart named service");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
        return 0;
    }

    my @status = $self->execCmd('service named status');

    unless (grep(/server is up and running/i, @status)) {
        $logger->error(__PACKAGE__ . ".$sub_name: server not up and running after the restarting named service");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
        return 0;
    }
@status = $self->execCmd('tail -50 /var/log/messages');

    unless (grep(/zone\s+$args{-domainName}.*loaded serial/i, @status)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to load $args{-domainName}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: successfully added DNS record");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub[1]");
    return 1;
}

=head2 Collect_jstat()

    This function collects jstat logs for EMS_SUT from jstat logging machine.

=over

=item Arguments:

    No arguments

=item Return Value:

    1 - on success
    0 - on failure

=item Usage:

    $Obj->Collect_jstat();

=back

=cut

sub Collect_jstat {
    my($self)=@_;
    my $sub = 'Collect_jstat';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
    $self->execCmd("");
    $self->execCmd("");
    my @cmd_res;
  
    my %scpArgs;
    $scpArgs{-hostip} = $self->{OBJ_HOST};
    $scpArgs{-hostuser} = $self->{OBJ_USER};
    $scpArgs{-hostpasswd} = $self->{OBJ_PASSWORD};
    $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'."$self->{jstat_path}/*";
    $scpArgs{-destinationFilePath} = $self->{result_path};

   $logger->info(__PACKAGE__ . ".$sub Changing the working directory to $self->{jstat_path}/");

   @cmd_res= $self->execCmd("cd $self->{jstat_path}/");
        if(grep ( /no.*such/i, @cmd_res)) {
           $logger->error(__PACKAGE__ . ".$sub $self->{jstat_path}/ directory not present");
           $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub ");
           return 0;
        }
        $logger->info(__PACKAGE__ . ".$sub Changed the working directory to $self->{jstat_path}/");

     @cmd_res =$self->execCmd("$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH}/jana-unix1 $self->{ems_ip} insight_jstat.log >> insight_jstat.csv"); 
     sleep 10;
     @cmd_res =$self->execCmd("$self->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH}/jana-unix1 $self->{ems_ip} fm_jstat.log >> fm_jstat.csv");
     sleep 10;       
 

     $logger->debug(__PACKAGE__ . ".$sub: scp jstat files from $self->{jstat_path} to $self->{result_path}");
     unless(&SonusQA::Base::secureCopy(%scpArgs)){
        $logger->error(__PACKAGE__ . ".$sub:  SCP failed to copy the jstat files to $self->{result_path}");
        $logger->debug(__PACKAGE__ . ".$sub:  <-- Leaving sub. [0]");
        return 0;
     }
     sleep 10;
    $logger->info(__PACKAGE__ . ".$sub: successfully copied jstat log files");
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub[1]");
  
    #Removing the jstat log files from jstat machine

     @cmd_res= $self->execCmd("cd");
     @cmd_res= $self->execCmd("rm -rf $self->{jstat_path}");
     $logger->info(__PACKAGE__ . ".$sub Successfully removed the jstat log files from Jstat Machine");
     return 1;
} 
=head2 IpRouteUpdate()

    This function  checks the routes in linux OS and updates them based of the required route criteris
        1) Parese the DestIp, that is derives the IP adress and Subnet mask length. If length is not specfied then it assumes as 32
        2) Verfies if the netstat -anr has the route entry for the Destip. If yes and if it matches the GW and interface then doesn't modify the routes
        3) If the Route entry doesn't exists , it adds the route entry based on the required GW and Interface
        4) If the Route exists with through different GW/Interface then deletes the entries one by one  and adds the Route for the new GW and Interface
        5) Returns 0 , if can't delete thr route or add the route
        6) Prints the netstat , ifconfig and Tracepath o/p for the Destip
                
=over

=item Arguments:

     Mandatory
        -DestIp - The Detination ip along with series. If the Series length is not given then 32 is assumed in case of IPv4
        -Gw     - This is Gateway ip 
        -Intf   - The Interface Name through which the packest have to be routed
     Optional
        -ipv6   - Flag for ipv6. If Not specfied then Ipv4 is assumed

=item Return Value:

    1 - on success
    0 - on failure

=item Usage:

   $Obj->IpRouteUpdate( -DestIp => '10.54.12.105' , -Gw => '10.54.88.1' , -Intf => 'eth4');
   $Obj->IpRouteUpdate( -DestIp => '10.54.12.0/24' , -Gw => '10.54.88.1' , -Intf => 'eth0');

=back

=cut

sub IpRouteUpdate {
    my ($self,%args) = @_;
    my $sub_name = "IpRouteUpdate";
    my (@cmd_res,@cmd_res1) = ();
    my ($DestIp,$MaskBitsLength,$netmask,$cmd,$routemode,$gateway,$interface) = '';
    my $RouteAddFlag = 1;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name: --> Entered Sub ");
    #If the -ipv6 flag is not set then it assumes it as ipv4
    $args{-ipv6} = (defined $args{-ipv6}) ?  $args{-ipv6}:'n';

    #Validating the manadatory Arguments
    foreach('-DestIp' , '-Gw', '-Intf' ) {
        unless(defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory input $_ is missing");
            $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
            return 0;
        }
    }
    if ($args{-ipv6} ne 'y') {
        #Parsing the -DestIp to get the Destip and Mask length
        if ($args{-DestIp}  =~ m /([0-9\.]+)\/*([0-9]*)/i) {
            #If Mask lenth is specified then assumes as 32 else takes the given value
            $MaskBitsLength = ($2 ne '') ? $2:32;
            $DestIp = $1;
         }
         #Sets the Route mode based on Mask Length
         $routemode = ($MaskBitsLength == 32) ? '-host':'-net';
         #Gets the netstat -anr o/p and checks foe the Destip entries 
         @cmd_res = $self->execCmd("netstat -anr | grep \"$DestIp\"");
         if (!defined $cmd_res[0]) {
             $logger->info(__PACKAGE__ . ".$sub_name: Currently No Route Exists for IP: $DestIp");
         } else {
             $logger->info(__PACKAGE__ . ".$sub_name: " . eval{$#cmd_res +1 } . " Route already Exists for IP: $DestIp. Checking one by one to match our requirement " . Dumper(\@cmd_res));
         }
         my $i = 1 ;
         foreach (@cmd_res ) {
                 #Matches the Destip, Gw and Interface .If it macthes then unset the routeaddflag so that the same can be skipped
                 if ( $_  =~ m/($DestIp)([\s]+)($args{-Gw})([\s]+)([0-9\.]+)([\s]+)(.+)([\s]+)($args{-Intf})/i) {
                     $netmask = $5;
                     $logger->info(__PACKAGE__ . ".$sub_name: Existing Route[$i] for IP: $1, GW : $3, Mask:$netmask, Interface :$9 matching  . So Not Modifying the Route");
                     $logger->info(__PACKAGE__ . ".$sub_name: The Route entry is [$_]");
                     $RouteAddFlag = 0 ;
                 } else {
                     #If the Gw,Intf does not match then deletes entries
                     $logger->info(__PACKAGE__ . ".$sub_name: Existing Route[$i] is Conflicting .The route is [$_]");
                     $logger->info(__PACKAGE__ . ".$sub_name: Route Expected is IP: $args{-DestIp}, GW : $args{-Gw}, Interface :$args{-Intf}. So deleting the current Route[$i]");
                     if ( $_ =~ m/($DestIp)([\s]+)([0-9\.]+)([\s]+)([0-9\.]+)([\s]+)(.+)([\s]+)(eth[0-9]+)/i) {
                         $netmask = $5;
                         $gateway = $3;
                         $interface = $9;
                     }
                     @cmd_res1  = $self->execCmd("route delete $routemode $DestIp gw $gateway netmask $netmask dev $interface ") if ($routemode eq '-net');
                     @cmd_res1  = $self->execCmd("route delete $routemode $DestIp gw $gateway dev $interface ") if ($routemode eq '-host');
                     if ( defined $cmd_res1[0] ) {
                         $logger->error(__PACKAGE__ . ".$sub_name: Failed to delete the route" . Dumper(\@cmd_res1));
                         $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                         return 0;
                      } else {
                         $logger->info(__PACKAGE__ . ".$sub_name: \"route delete $routemode DestIp gw $gateway dev $interface \" is successfull ");
                      }
                  }
            $i++;
        }
        #if the route add flag is set then adds the route
        if ($RouteAddFlag == 1) { 
             $logger->info(__PACKAGE__ . ".$sub_name:Adding the route ");
             @cmd_res = $self->execCmd("route add  $routemode $DestIp/$MaskBitsLength gw $args{-Gw} dev $args{-Intf}") ;
             @cmd_res = $self->execCmd("netstat -anr | grep \"$DestIp\"");
             if ( defined $cmd_res[0] ) {
                 if ( $cmd_res[0] =~ m/($DestIp)([\s]+)($args{-Gw})([\s]+)([0-9\.]+)([\s]+)(.+)([\s]+)($args{-Intf})/i) {
                     $netmask = $5;
                     $logger->info(__PACKAGE__ . ".$sub_name: Route Added succesffully for IP: $1, GW : $3, Mask:$netmask, Interface :$9"); 
                     $logger->info(__PACKAGE__ . ".$sub_name: After Adding, The Route entry is  " . Dumper(\@cmd_res));
                 } else {
                     $logger->error(__PACKAGE__ . ".$sub_name: Added the Route , but not macthing the Gw/Mask/Interface");
                     $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                     return 0;
                 }
             } else {
                $logger->error(__PACKAGE__ . ".$sub_name: Failed to add route");
                $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
                return 0;
            }
        }
        #Prints the netstat,ifconfig and Tracepath o/p
        @cmd_res = $self->execCmd("netstat -anr");
        $logger->info(__PACKAGE__ . ".$sub_name: Routing table is :" . Dumper(\@cmd_res));
        @cmd_res = $self->execCmd("ifconfig $args{-Intf}");
        $logger->info(__PACKAGE__ . ".$sub_name: Ifconfig for $args{-Intf} is " . Dumper(\@cmd_res));
        sleep 5;
        if ($routemode eq '-host'){
            @cmd_res = $self->execCmd("tracepath $DestIp",360);
            $logger->info(__PACKAGE__ . ".$sub_name: Tracepath output is :" . Dumper(\@cmd_res));
        }
        $logger->info(__PACKAGE__ . ".$sub_name: Successfully added or updated the route");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
        return 1
    }
}

=head2 CheckProcessStatus()

    This function checks if the given process is active and updates $self{ProcessName} with the process name

=over

=item Arguments:

    Process id

=item Return Value:

    1 - If the Process is active
    0 - If the Process is not active
    -1 - Any other errors

=item Usage:

    $Obj->CheckProcessStatus(-pid => 100);

=back

=cut

sub CheckProcessStatus {
    my($self,%args)=@_;
    my $sub = 'CheckProcessStatus';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my @r = ();
    my @PidString = ();
    $self->{ProcessName} = '';
    $self->{ProcessRunTime} = '';
    if((!defined $args{-'pid'}) || ($args{-'pid'} == 0)) {
            $logger->error(__PACKAGE__ . ".$sub: Mandatory input \'-pid\' is missing or the Process id is '0'");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [-1]");
            return -1;
        }

    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
    @r = $self->execCmd("ps -p $args{-pid} | grep -v PID ");
    
    if( !defined $r[0]) {
        $logger->error(__PACKAGE__ . ".$sub: The Process \'$args{'-pid'}\' is not active");
        return 0 ;
    } else {
        $logger->info(__PACKAGE__ . ".$sub The Process \'$args{'-pid'}\' is active");
        @PidString = split( " ",$r[0]);
        $self->{ProcessName} = $PidString[3];
        $self->{ProcessRunTime} = $PidString[2];
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
        return 1;
    }
        
}
=head2 getPerfDBdata()

    This function collects the data from perfdbhost db for the given test case id , Matching release & Matching chassis type. This function has to be called after starting the perflogger for the same SUT

=over

=item Arguments:

        Mandatory
           -testcase    => Test case id as in segirt DB
           -sut         => Sut object, for which the perflogger collects the data
        Optional
            -matchingRelease    => Array of releases against whihc data has to be compared e.g ['V09.0']. This will collect data for all the releases starting as V09.0. 
                                   If not set , all the releases are considered.
            -matchingChassis    => Chasis type as collected in perflogger. e.g "Netra-T5220", "ProLiant DL380p Gen8". If not set , sut->{chassistype} is used
            -loadDuration       => Duration of data for which the value has to be collected. If not set , default of 1800 secs is used
            -loadEndTime        => Elapsed time at which the load ends
            -lessLoadEndTime    => The Time is secs which has to be sbstracted from max(pt_elapsed_time).If not set, the default value is 60 secs
            -psxMaster          => y|n. Default is n.Value set in start_pserfloger takes precendence over this 


=item Return Value:

        0 - If the Mandatory
        %hash - Hash map of the data
        VAR1 = {
          '1' => {
                   'max_pt_elapsed' => 4521,
                   'pt_devicetype' => 'ProLiant DL380p Gen8',
                   'pt_mem_avg' => '15.0000',
                   'pt_run_uuid' => '6C859444406511E3A0C5B4CC2B7D2F5F',
                   'pt_cpu_avg' => '6.1436',
                   'pt_release' => 'V09.01.00R000'
                   'pt_date' => '2014-09-15'
                   'pt_host' => 'ptpsx2'
                   'pt_diam_dips' => 995
                   'pt_ext_dips' => 0
                   'normalised_diam_dips' => 1000
                   'normalised_ext_dips' => 0
                 },
        }
        1. Constructs the release string based on the array input for -matchingRelease
        2. Deletes all the content in the hash as part of initialisation
        3. Opens a Db connection with the perfdb
        4. Runs the query on the summary table for the give condition and constructs an hash having pt_devicetype,pt_run_uuid,pt_run_uuid,pt_host,pt_date sorted by pt_date in descending order
        5. Runs the query on result table of the respective product and derives the max_pt_elapsed time. If the load duration is defined then the same is used for max_pt_lepased time. if not lessLoadEndTime is subtracted. The default value of lessLoadEndTime is 60 secs
        6. If the max_pt_elapsed time is < LoadDuration time then the respective has is deleted
        7. Runs a next query to get the Avg(pt_cpu_avg),Avg(pt_mem_Avg),Avg(pt_ext_dip),Avg(pt_Diam_dip) in the result table for the range of pt_elapsed_time between max_pt_elpased <> max_pt_elapsed - ${-loadDuration}
        8. Normalised_ext_dip and Normalised_Diam_dip are dervied by rounding off to the nearest 25 base units
        8. Again the hash is updated with pt_cpu_avg ,pt_mem_avg,Avg(pt_ext_dip),Avg(pt_Diam_dip),normalised_diam_dips,normalised_ext_dips

=item Usage:

    $Obj->getPerfDBdata(-testCase => "$testId" , -sut => "$EmsObj_SUT" , -matchingRelease => ['V09.0'], -matchingChassis => "Netra-T5220" ,-loadDuration =>  400 );

=back

=cut

sub getPerfDBdata {
    my($self,%args)=@_;
    my $sub = 'getPerfDBdata';
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
     $logger->debug(__PACKAGE__ . ".$sub: --> Entered sub");
    foreach ( '-testCase' , '-sut') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: mandatory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
            return 0;
        }
    }


    #Setting the default values for the optional parameters
    $self->{sutType} =  $args{-sut}->{TMS_ALIAS_DATA}->{__OBJTYPE} if ( !defined $self->{sutType});
    $args{-loadDuration} = (defined $args{-loadDuration}) ? $args{-loadDuration}:1800 if ($self->{sutType} eq "EMS_SUT");
    $args{-loadDuration} = (defined $args{-loadDuration}) ? $args{-loadDuration}:200 if ($self->{sutType} eq "PSX");
    $args{-matchingChassis} = (defined $args{-matchingChassis}) ? "%$args{-matchingChassis}%":"%$args{-sut}->{chassistype}%" ;
    $args{-lessLoadEndTime} = (defined $args{-lessLoadEndTime}) ? $args{-lessLoadEndTime}:60 ;
    $args{-loadEndTime} = (defined $args{-loadEndTime}) ? $args{-loadEndTime}:'';
    $args{-psxMaster} = (defined $args{-psxMaster}) ?  $args{-psxMaster}:'n';
    my @releaseList = (defined $args{-matchingRelease}) ? @{$args{-matchingRelease}}:'%';

    #Setting the values to the Object as the same is used in compareOldData
    $self->{lessLoadEndTime} = $args{-lessLoadEndTime};
    $self->{loadEndTime} = $args{-loadEndTime};
    $self->{loadDuration} = $args{-loadDuration};
    $self->{psxMaster} = $args{-psxMaster} if ( !defined $self->{psxMaster}) ;

    



    #Constructing the release string from the given inputs.If no i/p then the string will have %%, still it works with mysql
    my $releasestring = '';
    foreach (@releaseList) {
        if ( $_ ne "$releaseList[$#releaseList]") {
            $releasestring = "$releasestring " .  'pt_release like \'%' . $_ . '%\' or';
         } else {
            $releasestring = "$releasestring " .   'pt_release like \'%' . $_ . '%\'';
         }
    }
    $logger->info(__PACKAGE__ . ".$sub : The releases compared are $releasestring");

    #Initialising the Hash for the results.Deleting the old elements if any 
    my %perf =();
    for (keys %perf) {
        delete $perf{$_};
    }

    #Creating the Connection to perfdbhost
    my $gDbh = DBI->connect("DBI:mysql:database=perfdb;host=perfdbhost.in.sonusnet.com", "perflogger", "perflogger", {'RaiseError' => 1});

    #Querying the DB to get the results for the given test case,release list & device type
    my $sql =  'select  pt_release,HEX(pt_run_uuid),pt_devicetype,pt_date,pt_host from pt_ems_summary  where pt_test = ' .  "'$args{-testCase}'" . ' and (' . "$releasestring" .  ')  and pt_devicetype like  ' . "'$args{-matchingChassis}'" . ' order by pt_release desc,pt_date desc'  if ($self->{sutType} eq "EMS_SUT")  ;
    $sql =  'select  pt_release,HEX(pt_run_uuid),pt_devicetype,pt_date,pt_host from pt_psx_summary  where pt_test = ' .  "'$args{-testCase}'" . ' and (' . "$releasestring" .  ')  and pt_devicetype like  ' . "'$args{-matchingChassis}'" . ' order by pt_release desc,pt_date desc'  if ($self->{sutType} eq "PSX")  ;
    $logger->info(__PACKAGE__ . ".$sub:The Sql query to indentify the list of results : $sql");
    my $query_handle = $gDbh->prepare($sql);
    $query_handle->execute();
    my ($key,$pt_release,$pt_run_uuid,$pt_devicetype,$max_pt_elapsed,$pt_cpu_avg,$pt_mem_avg,$pt_elapsed,$pt_diam_dips,$pt_ext_dips,$pt_date,$pt_host) = (0,0,0,0,0,0,0,0,0,0);
    $query_handle->bind_columns(undef,\$pt_release,\$pt_run_uuid,\$pt_devicetype,\$pt_date,\$pt_host );

    #Preparing the hash  
    my $i = 0;
    while($query_handle->fetch()) {
        $perf{$i}{pt_release} = $pt_release;
        $perf{$i}{pt_run_uuid} = $pt_run_uuid;
        $perf{$i}{pt_devicetype} = $pt_devicetype;
        $perf{$i}{pt_date} = $pt_date;
        $perf{$i}{pt_host} = $pt_host;
        $i++;
    }
                                                                                                                                                               

    #Getting the Elapsed time for the uuid, lesser by $args{-lessLoadEndTime} secs the max elaspsed in the db
    foreach $key ( keys(%perf)) {
        $sql = 'select max(pt_elapsed) from pt_ems_results where pt_run_uuid =0x' . "$perf{$key}{pt_run_uuid}" if ($self->{sutType} eq "EMS_SUT") ;
        $sql = 'select max(pt_elapsed) from pt_psx_results where pt_run_uuid =0x' . "$perf{$key}{pt_run_uuid}" if (($self->{sutType} eq "PSX") && ($self->{psxMaster} eq 'y' )) ;
        $sql = 'select max(pt_elapsed) from pt_psx_results where pt_run_uuid =0x' . "$perf{$key}{pt_run_uuid}"  . ' and (pt_ext_dips > 0 or pt_diam_dips > 0)' if (($self->{sutType} eq "PSX") && ($self->{psxMaster} eq 'n' )) ;
        $query_handle = $gDbh->prepare($sql);
        $query_handle->execute();
        $query_handle->bind_columns(undef,\$pt_elapsed);
        while($query_handle->fetch()) {
            $perf{$key}{max_pt_elapsed} = $pt_elapsed - $self->{lessLoadEndTime} if ($args{-loadEndTime} eq '');
             if ($args{-loadEndTime} ne '') {
                 $perf{$key}{max_pt_elapsed} = $self->{loadEndTime};    
                 $logger->info(__PACKAGE__ . ".$sub: Not using the Max Elapsed time $pt_elapsed, from PerfDB  . The max_pt_elapsed time used is $self->{loadEndTime} as pased from the script ");
            }
        }
    }

    #Getting the Avg_CPU and Avg_Mem for the run_uuid  and for the given range of elapsed time
    foreach $key ( keys(%perf)) {
        if ($perf{$key}{max_pt_elapsed}-$args{-loadDuration} < 0 ) {
            $logger->error(__PACKAGE__ . ".$sub:\"pt_run_uuid = $perf{$key}{pt_run_uuid}\" is less than $args{-loadDuration}secs and the pt_elapsedTime= " . eval {$perf{$key}{max_pt_elapsed} + $self->{lessLoadEndTime}}) if ($args{-loadEndTime} eq '');
             $logger->error(__PACKAGE__ . ".$sub:\"pt_run_uuid = $perf{$key}{pt_run_uuid}\" is less than $args{-loadDuration}secs and the pt_elapsedTime= $perf{$key}{max_pt_elapsed}") if ($args{-loadEndTime} ne '');
            delete $perf{$key};
            next;
        } else {
           $sql = 'select avg(pt_cpu_avg),avg(pt_mem_avg)  from pt_ems_results where pt_run_uuid =0x'  . "$perf{$key}{pt_run_uuid}" .  " and pt_elapsed <= $perf{$key}{max_pt_elapsed} and  pt_elapsed >="  . eval {$perf{$key}{max_pt_elapsed} - $args{-loadDuration}} if ($self->{sutType} eq "EMS_SUT");
           $sql = 'select avg(pt_cpu_avg),avg(pt_mem_avg),avg(pt_diam_dips),avg(pt_ext_dips)  from pt_psx_results where pt_run_uuid =0x'  . "$perf{$key}{pt_run_uuid}" .  " and pt_elapsed <= $perf{$key}{max_pt_elapsed} and  pt_elapsed >="  . eval {$perf{$key}{max_pt_elapsed} - $args{-loadDuration}} if (($self->{sutType} eq "PSX") && ($self->{psxMaster} eq 'y' )) ;
           if (($self->{sutType} eq "PSX") && ($self->{psxMaster} ne 'y' )) {
               $sql = 'select avg(pt_diam_dips),avg(pt_ext_dips)  from pt_psx_results where pt_run_uuid =0x'  . "$perf{$key}{pt_run_uuid}" .  " and pt_elapsed <= $perf{$key}{max_pt_elapsed} and  pt_elapsed >="  . eval {$perf{$key}{max_pt_elapsed} - $args{-loadDuration}};
               $query_handle = $gDbh->prepare($sql);
               $query_handle->execute();
               $query_handle->bind_columns(undef,\$pt_diam_dips,\$pt_ext_dips);
               while($query_handle->fetch()) {
                   #Normalising the dips to 25 CPS base
                   $pt_diam_dips = 25*eval{sprintf "%4.0f",$pt_diam_dips/25};
                   $pt_ext_dips = 25*eval{sprintf "%4.0f",$pt_ext_dips/25};
               
                   if (($pt_diam_dips != 0 ) && ($pt_ext_dips != 0 )) {
                       $sql = 'select avg(pt_cpu_avg),avg(pt_mem_avg),avg(pt_diam_dips),avg(pt_ext_dips)  from pt_psx_results where pt_run_uuid =0x' . "$perf{$key}{pt_run_uuid}" . '  and  ( pt_diam_dips > ' . eval{0.95*$pt_diam_dips} . ' and  pt_ext_dips > ' . eval{0.95*$pt_ext_dips}  . ' ) and db_id != (select min(db_id) from pt_psx_results where pt_run_uuid = 0x' . "$perf{$key}{pt_run_uuid}" . ")"  ;
                   } else {
                       $sql = 'select avg(pt_cpu_avg),avg(pt_mem_avg),avg(pt_diam_dips),avg(pt_ext_dips)  from pt_psx_results where pt_run_uuid =0x' . "$perf{$key}{pt_run_uuid}" . '  and  ( pt_diam_dips > ' . eval{0.95*$pt_diam_dips} . ' or pt_ext_dips > ' . eval{0.95*$pt_ext_dips}  . ' ) and db_id != (select min(db_id) from pt_psx_results where pt_run_uuid = 0x' . "$perf{$key}{pt_run_uuid}" . ")" ;
                   }
               }
           }
        }
        $logger->info(__PACKAGE__ . ".$sub:The Sql query to get the AvgCpu and AvgMem : $sql");
        $query_handle = $gDbh->prepare($sql);
        $query_handle->execute();
        $query_handle->bind_columns(undef,\$pt_cpu_avg,\$pt_mem_avg)if ($self->{sutType} eq "EMS_SUT");
        $query_handle->bind_columns(undef,\$pt_cpu_avg,\$pt_mem_avg,\$pt_diam_dips,\$pt_ext_dips)if ($self->{sutType} eq "PSX");
        while($query_handle->fetch()) {
            $perf{$key}{pt_cpu_avg} = $pt_cpu_avg ;
            $perf{$key}{pt_mem_avg} = $pt_mem_avg ;
            if ($self->{sutType} eq "PSX") {
                $perf{$key}{pt_diam_dips} = $pt_diam_dips  ;
                $perf{$key}{normalised_diam_dips} = 25*eval{sprintf "%4.0f",$pt_diam_dips/25} ;
                $perf{$key}{pt_ext_dips} = $pt_ext_dips ;
                $perf{$key}{normalised_ext_dips} = 25*eval{sprintf "%4.0f",$pt_ext_dips/25} ;
            }
        }
    }

    $gDbh->disconnect;
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
    return \%perf;
}
=head2 compareOldRelease()

    This function compares the new Avg CPu,Avg mem and CPS against the old set of metrics given in the form of hash.
    Prints all the metrics in "$self->{result_path}/Result/Testcase_Results.txt

=over

=item Arguments:

        Mandatory
           %hash    => The Hash as given by getPerfDBdata
           '1' => {
                   'max_pt_elapsed' => 4521,
                   'pt_devicetype' => 'ProLiant DL380p Gen8',
                   'pt_mem_avg' => '15.0000',
                   'pt_run_uuid' => '6C859444406511E3A0C5B4CC2B7D2F5F',
                   'pt_cpu_avg' => '6.1436',
                   'pt_release' => 'V09.01.00R000'
                   'pt_date' => '2014-09-15'
                   'pt_host' => 'ptpsx2'
                   'pt_diam_dips' => 995
                   'pt_ext_dips' => 0
                   'normalised_diam_dips' => 1000
                   'normalised_ext_dips' => 0
                   'max_pt_elpased' => 2400
                 },
        Optional
                None

=item Return Value:

        1 - On Success 

=item Usage:

        $perfLoggerObj->compareOldRelease(%$tests);

=back

=cut

sub compareOldRelease {
    my($self,%oldData,%args)=@_;
    my $sub = 'compareOldRelease';
    require Statistics::Descriptive;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub: --> Entering sub ");
    my $fp; # File Handler
    my $result ;
    my ($cmd,$endRecord) = () ;
    my @cmd_res = () ;

    #Parsing the files for the performance metrics.The file list will varry if the SUT is virtulaised  
    my @files = ($self->{PerfLoggerSut},$self->{HostTmsAlias}) if ($self->{hypervisor} eq 'KVM');
    @files = ($self->{PerfLoggerSut}) if (($self->{HostTmsAlias} eq  '') || ($self->{hypervisor} eq 'VMware'));
    my $testResult = 1;
    foreach(@files) {
        #Exit if csv file doesn't exist
        my @cmdResult = $self->execCmd("ls $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");    
        if(grep(/No such file or directory/, @cmdResult)){
                $logger->error(__PACKAGE__ . ".$sub: perfLogger CSV file doesn't exist");
                $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
                $testResult = 0;
                last;
        }
    }
    return 0 if($testResult == 0); # Used this to avoid exiting from inside the loop
    $logger->info(__PACKAGE__ . ".$sub: The necessary CSV files exist, now let's move on to some not so simple awk calculations on the CSV files.");
    foreach (@files) {
        #Reading the headers of perlogger csv file
        my @line1 =  $self->execCmd("head -1 $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
        my $scalar_line1 = $line1[0];
        my @array_line1 = split(',',$scalar_line1);
        my $array_size = @array_line1;
        $logger->info(__PACKAGE__ . ".$sub The size of perflogger csv file header line is $array_size\n");

        #Finding the location of desired headers. The intented headers differ based on SUT and if SUT is VM
        my @perflogger_headers = ("Slot0-CPUIdle" , "Slot0-MemFree" , "Slot0-TaskCpu-insight" , "Slot0-TaskCpu-oracle" , "Slot0-TaskCpu-traprecv","Slot0-CollectionIntv" ) if (($self->{sutType} eq "EMS_SUT") and ($_ eq $self->{PerfLoggerSut}));
        @perflogger_headers = ("Slot0-CPUIdle" , "Slot0-MemFree" , "Slot0-TaskCpu-kvm-irqfd-clean" , "Slot0-TaskCpu-kvm-pit-wq" , "Slot0-TaskCpu-qemu-kvm","Slot0-CollectionIntv" ) if ($_ eq $self->{HostTmsAlias});
        @perflogger_headers = ("Slot0-CPUIdle" , "Slot0-MemFree" , "Slot0-ExtReqs" , "Slot0-NoExtReqs" , "Slot0-TaskCpu-oracle","Slot0-TaskCpu-pes","Slot0-TaskCpu-sipe","Slot0-TaskCpu-dbrepd","Slot0-TaskCpu-pipe","Slot0-TaskCpu-scpa","Slot0-CollectionIntv" ) if (($self->{sutType} eq "PSX") and ($_ eq $self->{PerfLoggerSut}));
        foreach my $pos (@perflogger_headers) {
            my $index = 0;
            ++$index until $array_line1[$index] eq $pos or $index >$#array_line1;
            $result->{$pos} = $index+1;
            $logger->info(__PACKAGE__ . ".$sub: $pos = $result->{$pos}");
        }
        
        #$self->{lessLoadEndTime},$self->{loadEndTime} and $self->{loadDuration} are set in getPerfDbData. endRecord  Values can be different for Host as the host perflogger starts earlier , but the error will not be significant
        if (($self->{sutType} eq "PSX") and ($_ eq $self->{PerfLoggerSut}) and $self->{psxMaster} eq 'n') {
            #Getting the total number of lines in the file
            @cmd_res = $self->execCmd(" wc -l $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
            $endRecord = $cmd_res[0];
   
            #Gettting the Line number for which CPS value is non zero from the last
            $cmd = 'awk \'{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--] }\'  ' . "$self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv"  . ' | awk -F"," \'{ if ($'  . "$result->{'Slot0-NoExtReqs'}" . ' > 0 || $' . "$result->{'Slot0-ExtReqs'}" . " > 0  ) { print NR; exit}} '"  ;
            @cmd_res = $self->execCmd("$cmd"); 

            $endRecord = $endRecord - (1 + $cmd_res[0] + int($self->{lessLoadEndTime}/10)) if ($self->{loadEndTime} eq '');
        } else {
            @cmd_res = $self->execCmd(" wc -l $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
            $endRecord = $cmd_res[0] - (1 + int($self->{lessLoadEndTime}/10)) if ($self->{loadEndTime} eq '');   
        }

        #If loadEndTime is specified then the same overides found value 
        $endRecord  = $self->{loadEndTime}/10 if ($self->{loadEndTime} ne '');
        my $startRecord = $endRecord - int($self->{loadDuration}/10);
        $startRecord = $endRecord - $self->{'Total_Samples'} if ($_ eq $self->{HostTmsAlias}); # 'Total_Samples' is derived from the SUT awk script. This will tell us how many samples are to be considered as load
        $logger->info(__PACKAGE__ . ".$sub: The AvgCpu and Avgmem will be calculated only between $startRecord and $endRecord ");


        #Constructing the awk script based on the SUT type and if the SUT is virtuliased or not
        my $cmd = 'awk -F"," \'BEGIN {count=0;memtotal=0;cputotal=0;insightcpu=0;oraclecpu=0;trapcpu=0} { if (NR >= ' . "$startRecord"  . ' && NR <= ' . "$endRecord" . ') {count += 1; memtotal += $' . "$result->{'Slot0-MemFree'}" . '; cputotal += $' . "$result->{'Slot0-CPUIdle'}" . '; insightcpu += $' . "$result->{'Slot0-TaskCpu-insight'}" . '; oraclecpu += $' . "$result->{'Slot0-TaskCpu-oracle'}" . '; trapcpu += $' . "$result->{'Slot0-TaskCpu-traprecv'}" . ' }} END { printf "Total_Samples= %10s\n avgMem= %10s\n  avgCpu= %10s\n' . "$perflogger_headers[2]" . '= %10s\n' . "$perflogger_headers[3]" .  '=%10s\n' . "$perflogger_headers[4]" . '= %10s\n" , count , 100*(1 - memtotal/(' . "$self->{sutTotalMemMB}" . '*1024*count)) , 100 - cputotal/count , insightcpu/count , oraclecpu/count ,trapcpu/count}\''  if (($self->{sutType} eq "EMS_SUT") and ($_ eq $self->{PerfLoggerSut}));
 
       $cmd = 'awk -F"," \'BEGIN {count=0;memtotal=0;cputotal=0;dbrepdcpu=0;pipecpu=0;oraclecpu=0;pescpu=0}  { if (NR >= ' . "$startRecord"  . ' && NR <= ' . "$endRecord" . ') {count += 1; memtotal += $' . "$result->{'Slot0-MemFree'}" . '; cputotal += $' . "$result->{'Slot0-CPUIdle'}" . '; oraclecpu += $' . "$result->{'Slot0-TaskCpu-oracle'}" . '; dbrepdcpu += $' . "$result->{'Slot0-TaskCpu-dbrepd'}" . '; pipecpu += $' . "$result->{'Slot0-TaskCpu-pipe'}" . '; pescpu += $' . "$result->{'Slot0-TaskCpu-pes'}" . ' }} END { printf "Total_Samples= %10s\n avgMem= %10s\n  avgCpu= %10s\n' . "$perflogger_headers[4]" . '= %10s\n' . "$perflogger_headers[7]" .  '=%10s\n' . "$perflogger_headers[8]" .  '=%10s\n' . "$perflogger_headers[5]"  . '= %10s\n" , count , 100*(1 - memtotal/(' . "$self->{sutTotalMemMB}" . '*1024*count)) , 100 - cputotal/count ,oraclecpu/count,dbrepdcpu/count,pipecpu/count,pescpu/count}\'' if (($self->{sutType} eq "PSX") and ($_ eq $self->{PerfLoggerSut}) and  ($self->{psxMaster} eq 'y')) ;
 
      $cmd = 'awk -F"," \'BEGIN {count=0;memtotal=0;cputotal=0;irqfdcpu=0;pitcpu=0;qemucpu=0} {  if (NR >= ' . "$startRecord" . ' && NR <= ' . "$endRecord" .') {count += 1; memtotal += $' . "$result->{'Slot0-MemFree'}" . '; cputotal += $' . "$result->{'Slot0-CPUIdle'}" . '; irqfdcpu += $' . "$result->{'Slot0-TaskCpu-kvm-irqfd-clean'}" . '; pitcpu += $' . "$result->{'Slot0-TaskCpu-kvm-pit-wq'}" . '; qemucpu += $' . "$result->{'Slot0-TaskCpu-qemu-kvm'}" . ' }} END { printf "Total_Samples= %10s\n HostavgMem= %10s\n  HostavgCpu= %10s\n' . "$perflogger_headers[2]" . '= %10s\n' . "$perflogger_headers[3]" . '= %10s\n' . "$perflogger_headers[4]" . '= %10s\n ", count , 100*(1 - memtotal/(' . "$self->{HostsutTotalMemMB}" . '*1024*count)) , 100 - cputotal/count , irqfdcpu/count , pitcpu/count , qemucpu/count}\''  if ($_ eq $self->{HostTmsAlias});

      #In case of PSX we getting the CPS from the last few secs and normalising it to 25 Basic units 
      my ($noExtReqSample,$extReqSample) = (0,0);
      if (($self->{sutType} eq "PSX") and ($_ eq $self->{PerfLoggerSut}) and  ($self->{psxMaster} eq 'n') ) {
          $cmd = 'awk -F"," \'BEGIN {count=0;extreq=0} { if (NR >= ' . "$startRecord"  . ' && NR <= ' . "$endRecord". ') {count += 1; extreq += $' . "$result->{'Slot0-ExtReqs'}" . ' }} END { printf "%10s\n",extreq/(count*10)}\'';
          @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
          $extReqSample = 25*eval{sprintf "%5.0f",$cmd_res[0]/25} ;
          $cmd = 'awk -F"," \'BEGIN {count=0;noextreq=0} { if (NR >= ' . "$startRecord"  . ' && NR <= ' . "$endRecord". ') {count += 1; noextreq += $' . "$result->{'Slot0-NoExtReqs'}" . ' }} END { printf "%10s\n",noextreq/(count*10)}\'';
          @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
          $noExtReqSample =  25*eval{sprintf "%5.0f",$cmd_res[0]/25} ;
          if ( $noExtReqSample != 0 && $extReqSample != 0 ) {
              $cmd = 'awk -F"," \'BEGIN {count=0;memtotal=0;cputotal=0;pescpu=0;oraclecpu=0;sipecpu=0;scpacpu=0;dbrepdcpu=0;pipecpu=0;extreq=0;noextreq=0} { if ( NR > 1 && ( $'  . "$result->{'Slot0-ExtReqs'}" . ' > ' . eval{0.95*$extReqSample*10}  . ' && $' .  "$result->{'Slot0-NoExtReqs'}" . ' > ' . eval{0.95*$noExtReqSample*10} . ' )) {count += 1; memtotal += $' . "$result->{'Slot0-MemFree'}" . '; cputotal += $' . "$result->{'Slot0-CPUIdle'}" . '; pescpu += $' . "$result->{'Slot0-TaskCpu-pes'}" . '; oraclecpu += $' . "$result->{'Slot0-TaskCpu-oracle'}" . '; sipecpu += $' . "$result->{'Slot0-TaskCpu-sipe'}" . '; scpacpu += $' . "$result->{'Slot0-TaskCpu-scpa'}" . '; dbrepdcpu += $' . "$result->{'Slot0-TaskCpu-dbrepd'}" . '; pipecpu += $' . "$result->{'Slot0-TaskCpu-pipe'}" . '; extreq += $' . "$result->{'Slot0-ExtReqs'}" . '; noextreq += $' . "$result->{'Slot0-NoExtReqs'}" . ' }} END { printf "Total_Samples= %10s\n avgMem= %10s\n  avgCpu= %10s\n' . "$perflogger_headers[2]" . '= %10s\n' . "$perflogger_headers[3]" .  '=%10s\n' . "$perflogger_headers[4]" .  '= %10s\n' . "$perflogger_headers[5]" . '= %10s\n'. "$perflogger_headers[6]" . '= %10s\n'. "$perflogger_headers[7]" . '= %10s\n'. "$perflogger_headers[8]" . '= %10s\n'. "$perflogger_headers[9]"   . '= %10s\n" , count , 100*(1 - memtotal/(' . "$self->{sutTotalMemMB}" . '*1024*count)) , 100 - cputotal/count ,extreq/(count*10),noextreq/(count*10),oraclecpu/count,pescpu/count,sipecpu/count,dbrepdcpu/count,pipecpu/count,scpacpu/count}\'';
          } else {
             $cmd = 'awk -F"," \'BEGIN {count=0;memtotal=0;cputotal=0;pescpu=0;oraclecpu=0;sipecpu=0;scpacpu=0;dbrepdcpu=0;pipecpu=0;extreq=0;noextreq=0} { if ( NR > 1 && ( $'  . "$result->{'Slot0-ExtReqs'}" . ' > ' . eval{0.95*$extReqSample*10}  . ' || $' .  "$result->{'Slot0-NoExtReqs'}" . ' > ' . eval{0.95*$noExtReqSample*10} . ' )) {count += 1; memtotal += $' . "$result->{'Slot0-MemFree'}" . '; cputotal += $' . "$result->{'Slot0-CPUIdle'}" . '; pescpu += $' . "$result->{'Slot0-TaskCpu-pes'}" . '; oraclecpu += $' . "$result->{'Slot0-TaskCpu-oracle'}" . '; sipecpu += $' . "$result->{'Slot0-TaskCpu-sipe'}" . '; scpacpu += $' . "$result->{'Slot0-TaskCpu-scpa'}" . '; dbrepdcpu += $' . "$result->{'Slot0-TaskCpu-dbrepd'}" . '; pipecpu += $' . "$result->{'Slot0-TaskCpu-pipe'}" . '; extreq += $' . "$result->{'Slot0-ExtReqs'}" . '; noextreq += $' . "$result->{'Slot0-NoExtReqs'}" . ' }} END { printf "Total_Samples= %10s\n avgMem= %10s\n  avgCpu= %10s\n' . "$perflogger_headers[2]" . '= %10s\n' . "$perflogger_headers[3]" .  '=%10s\n' . "$perflogger_headers[4]" .  '= %10s\n' . "$perflogger_headers[5]" . '= %10s\n'. "$perflogger_headers[6]" . '= %10s\n'. "$perflogger_headers[7]" . '= %10s\n'. "$perflogger_headers[8]" . '= %10s\n'. "$perflogger_headers[9]"   . '= %10s\n" , count , 100*(1 - memtotal/(' . "$self->{sutTotalMemMB}" . '*1024*count)) , 100 - cputotal/count ,extreq/(count*10),noextreq/(count*10),oraclecpu/count,pescpu/count,sipecpu/count,dbrepdcpu/count,pipecpu/count,scpacpu/count}\'';
        }
      }
        
      @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");        


       #Printing the stats in the file
       my $fp;
       open $fp , ">>", "$self->{result_path}/../Result/Testcase_Results.txt";
       print $fp "################################################\n";
       print $fp "#         Perflogger Statistics of $_          #\n";
       print $fp "################################################\n";

       foreach my $line (@cmd_res) {
           if($line =~ m/\s*(.+)\s*=\s*(.+)/) {
               print $fp "$1=$2\n";
               $self->{$1}=$2;
           }
       }

       printf $fp "Load Start Time = %4s\n", eval{$startRecord * 10 };
       printf $fp "Load End Time = %4s\n", eval{$endRecord * 10 };
      
       #Analysing the perflogger error
       $cmd = $cmd =  'awk -F"," \'BEGIN {count=0} {if ( NR > 1  &&  $' . "$result->{'Slot0-CollectionIntv'}" . ' > 10  ) { count += 1 }} END { print count }\''; 
       @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
       printf $fp "Time Lapse Errors in perflogger files  = %4s\n", $cmd_res[0];

       #Printing the StdDev , Max and 95ile values for CPU,Memory & CPS
       my ($cpuStdDev,$cpu95ile,$cpuMax,$memStdDev,$mem95ile,$memMax,$extReqStdDev,$extReq95ile,$extReqMax,$noExtReqStdDev,$noExtReq95ile,$noExtReqMax) = (0,0,0,0,0,0,0,0,0,0,0,0);
       if (($self->{sutType} eq "EMS_SUT") and ($_ eq $self->{PerfLoggerSut})) {
           #Calculating the CPU metrics
           $cmd = 'awk -F"," \'{ if ( NR >= ' . "$startRecord"  . ' && NR <= ' . "$endRecord" . ' ) { print  100-$' . "$result->{'Slot0-CPUIdle'}"  . ' }}\'';
           @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
           my $stat=Statistics::Descriptive::Full->new();
           $stat->add_data(@cmd_res);
           $cpuStdDev = $stat->standard_deviation();
           $cpu95ile =$stat->percentile(95) ;
           $cpuMax = $stat->max(); 
  
           #Calculating the memory metrics 
           $cmd = 'awk -F"," \'{ if ( NR >= ' . "$startRecord"  . ' && NR <= ' . "$endRecord" . ' ) { print  100*(1-$' .  "$result->{'Slot0-MemFree'}"  . '/' . eval{"$self->{sutTotalMemMB}"*1024}   . ') }}\'';
           @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
           $stat=Statistics::Descriptive::Full->new();
           $stat->add_data(@cmd_res);
           $memStdDev = $stat->standard_deviation();
           $mem95ile =$stat->percentile(95) ;
           $memMax = $stat->max();
       }

       if (($self->{sutType} eq "PSX") and ($_ eq $self->{PerfLoggerSut}) and  ($self->{psxMaster} eq 'y')) {
           #Calculating the CPU metrics
           $cmd = 'awk -F"," \'{ if ( NR >= ' . "$startRecord"  . ' && NR <= ' . "$endRecord" . ' ) { print  100-$' . "$result->{'Slot0-CPUIdle'}"  . ' }}\'';
           @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
           my $stat=Statistics::Descriptive::Full->new();
           $stat->add_data(@cmd_res);
           $cpuStdDev = $stat->standard_deviation();
           $cpu95ile =$stat->percentile(95) ;
           $cpuMax = $stat->max();

           #Calculating the memory metrics 
           $cmd = 'awk -F"," \'{ if ( NR >= ' . "$startRecord"  . ' && NR <= ' . "$endRecord" . ' ) { print  100*(1-$' .  "$result->{'Slot0-MemFree'}"  . '/' . eval{"$self->{sutTotalMemMB}"*1024}   . ') }}\'';
           @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
           $stat=Statistics::Descriptive::Full->new();
           $stat->add_data(@cmd_res);
           $memStdDev = $stat->standard_deviation();
           $mem95ile =$stat->percentile(95) ;
           $memMax = $stat->max();
       } 
           
       if ($_ eq $self->{HostTmsAlias}) {
           #Calculating the CPU metrics
           $cmd = 'awk -F"," \'{ if ( NR >= ' . "$startRecord"  . ' && NR <= ' . "$endRecord" . ' ) { print  100-$' . "$result->{'Slot0-CPUIdle'}"  . ' }}\'';
           @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
           my $stat=Statistics::Descriptive::Full->new();
           $stat->add_data(@cmd_res);
           $cpuStdDev = $stat->standard_deviation();
           $cpu95ile =$stat->percentile(95) ;
           $cpuMax = $stat->max();
          
           #Calculating the memory metrics 
           $cmd = 'awk -F"," \'{ if ( NR >= ' . "$startRecord"  . ' && NR <= ' . "$endRecord" . ' ) { print  100*(1-$' .  "$result->{'Slot0-MemFree'}"  . '/' . eval{"$self->{HostsutTotalMemMB}"*1024}   . ') }}\'';
           @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
           $stat=Statistics::Descriptive::Full->new();
           $stat->add_data(@cmd_res);
           $memStdDev = $stat->standard_deviation();
           $mem95ile =$stat->percentile(95) ;
           $memMax = $stat->max(); 
       } 
           
       if (($self->{sutType} eq "PSX") and  ($self->{psxMaster} eq 'n') and ($_ eq $self->{PerfLoggerSut})) {
           #Calculating the CPU metrics
           if ( $noExtReqSample != 0 && $extReqSample != 0 ) {
               $cmd =  'awk -F"," \'{ if (  NR > 1 && ( $' . "$result->{'Slot0-ExtReqs'}" . ' > ' . eval{0.95*$extReqSample*10}  . ' && $' .  "$result->{'Slot0-NoExtReqs'}" . ' > ' . eval{0.95*$noExtReqSample*10} . ' )) { print  100-$' . "$result->{'Slot0-CPUIdle'}"  . ' }}\'';
           } else {
               $cmd =  'awk -F"," \'{ if (  NR > 1 && ( $' . "$result->{'Slot0-ExtReqs'}" . ' > ' . eval{0.95*$extReqSample*10}  . ' || $' .  "$result->{'Slot0-NoExtReqs'}" . ' > ' . eval{0.95*$noExtReqSample*10} . ' ) ) { print  100-$' . "$result->{'Slot0-CPUIdle'}"  . ' }}\'';
           }
           @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
           my $stat=Statistics::Descriptive::Full->new();
           $stat->add_data(@cmd_res);
           $cpuStdDev = $stat->standard_deviation();
           $cpu95ile =$stat->percentile(95) ;
           $cpuMax = $stat->max();
                
           #Calculating the memory metrics      
           if ( $noExtReqSample != 0 && $extReqSample != 0 ) {
               $cmd =  'awk -F"," \'{ if ( NR > 1 && ( $' . "$result->{'Slot0-ExtReqs'}" . ' > ' . eval{0.95*$extReqSample*10}  . ' && $' .  "$result->{'Slot0-NoExtReqs'}" . ' > ' . eval{0.95*$noExtReqSample*10} . ' )) { print  100*(1-$' .  "$result->{'Slot0-MemFree'}"  . '/' . eval{"$self->{sutTotalMemMB}"*1024}   . ') }}\'';
           } else {
               $cmd =  'awk -F"," \'{ if (  NR > 1 && ( $' . "$result->{'Slot0-ExtReqs'}" . ' > ' . eval{0.95*$extReqSample*10}  . ' || $' .  "$result->{'Slot0-NoExtReqs'}" . ' > ' . eval{0.95*$noExtReqSample*10} . ' )) { print  100*(1-$' .  "$result->{'Slot0-MemFree'}"  . '/' . eval{"$self->{sutTotalMemMB}"*1024}   . ') }}\'';
           }
           @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
           $stat=Statistics::Descriptive::Full->new();
           $stat->add_data(@cmd_res);
           $memStdDev = $stat->standard_deviation();  
           $mem95ile =$stat->percentile(95) ;
           $memMax = $stat->max();
         
           #Calculating the CPS(Internal & external ) metrics
           $cmd =  'awk -F"," \'{ if (  NR > 1 && ( $' . "$result->{'Slot0-ExtReqs'}" . ' > ' . eval{0.95*$extReqSample*10}  . ' )) { print  $' . "$result->{'Slot0-ExtReqs'}"  . ' }}\'';
           @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
           $stat=Statistics::Descriptive::Full->new();
           $stat->add_data(@cmd_res);
           $extReqStdDev = $stat->standard_deviation();
           $extReq95ile =$stat->percentile(95) ;
           $extReqMax = $stat->max();

           $cmd =  'awk -F"," \'{ if (  NR > 1 && ( $' . "$result->{'Slot0-NoExtReqs'}" . ' > ' . eval{0.95*$noExtReqSample*10}  . ' )) { print  $' . "$result->{'Slot0-NoExtReqs'}"  . ' }}\'';
           @cmd_res = $self->execCmd("$cmd" . " $self->{result_path}/"."/$self->{PerfLoggerTestid}"."_"."$_"."_20*.csv");
           $stat=Statistics::Descriptive::Full->new();
           $stat->add_data(@cmd_res);
           $noExtReqStdDev = $stat->standard_deviation();
           $noExtReq95ile =$stat->percentile(95) ;
           $noExtReqMax = $stat->max();
           
           printf $fp "95ile ExtReq = %5.1F , Std Dev  ExtReq = %5.1F , Max ExtReq = %5.2F \n", $extReq95ile/10,$extReqStdDev/10,$extReqMax/10;
           printf $fp "95ile NoExtReq = %5.1F , Std Dev  NoExtReq = %5.1F , Max NoExtReq = %5.2F \n", $noExtReq95ile/10,$noExtReqStdDev/10,$noExtReqMax/10;


       }
       printf $fp "95ile CPU = %5.1F , Std Dev  CPU = %5.1F , Max CPU = %5.2F \n", $cpu95ile,$cpuStdDev,$cpuMax;
       printf $fp "95ile Mem = %5.1F , Std Dev  Mem = %5.1F , Max Mem = %5.2F \n", $mem95ile,$memStdDev,$memMax; 
       close $fp;
    }


   
    #If the SUT Type is EMS_SUT then compare only the CPU and memory. The SUT type is defined in start_perflogger 
    open $fp , ">>", "$self->{result_path}/../Result/Testcase_Results.txt";
    print $fp "###################################################\n";
    print $fp "#      Comparison against old version data        #\n";
    print $fp "###################################################\n";
    print $fp "Release        Chassis Type                      Host Name         pt_run_uuid                       OldCPU  %devCPU  OldMem  %devMem  StartTime  EndTime  \n" if ($self->{sutType} eq "EMS_SUT") ;
    print $fp "Release        Chassis Type                      Host Name         pt_run_uuid                       OldCPU  %devCPU  OldMem  %devMem  StartTime  EndTime  ExtDip  NorExt  IntDip  NorInt \n" if ($self->{sutType} eq "PSX") ;
    #The Releases are stored in descending order in the sql query of getperfDbData.So the keys have to be in ascending order
    foreach my $key ( sort {$a <=> $b} keys(%oldData)) {
       print $fp sprintf ("%-15s" ,$oldData{$key}{pt_release})   ;
       print $fp sprintf ("%-34s" ,$oldData{$key}{pt_devicetype})   ;
       print $fp sprintf ("%-18s",$oldData{$key}{pt_host});
       print $fp sprintf ("%-34s" ,$oldData{$key}{pt_run_uuid})     ;
       print $fp eval{ sprintf "%-8.1f", $oldData{$key}{pt_cpu_avg}   };
       print $fp eval{ sprintf "%-9.1f", 100*(1-$self->{avgCpu}/$oldData{$key}{pt_cpu_avg})};
       # Earlier to PSX 9.1 we don't have mem data
       if ($oldData{$key}{pt_mem_avg} ne "") {
           print $fp eval{ sprintf "%-8.1f", $oldData{$key}{pt_mem_avg}};
           print $fp eval{ sprintf "%-9.1f", 100*(1-$self->{avgMem}/$oldData{$key}{pt_mem_avg})};
       } else {
           print $fp eval{ sprintf "%-8s","NA"};
           print $fp eval{ sprintf "%-9s","NA"};
       }
       print $fp eval{ sprintf "%-11d", $oldData{$key}{max_pt_elapsed} - $self->{loadDuration}};
       print $fp sprintf( "%-9d",$oldData{$key}{max_pt_elapsed});
       if ($self->{sutType} eq "PSX") {
           print $fp sprintf ("%-8.0f" ,$oldData{$key}{pt_ext_dips});
           print $fp sprintf ("%-8.0f" ,$oldData{$key}{normalised_ext_dips});
           print $fp sprintf ("%-8.0f" ,$oldData{$key}{pt_diam_dips});
           print $fp sprintf ("%-8.0f" ,$oldData{$key}{normalised_diam_dips});
       }
       print $fp "\n";
    }
   $logger->info(__PACKAGE__ . ".$sub: Adding additional Metadata");
   unless($self->addSutDetails())
   {
       $logger->error(__PACKAGE__ . ".$sub: Failed to add DUT details to Results file");
       return 0;
   }
   $logger->info(__PACKAGE__ . ".$sub: Successfully added DUT details to Results file");
   close $fp;
   $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
   return 1;
}

=head2 sendFlagActionMap()

    This functions triggers sending of flagaction to the tcl files in a map file. Based on the flag action configured in the TCL file , Traps can be sent by the devices
    at the rate defined in the TCL file. After calling the sapcncl command ,sapro response is validated to declare sucess

=over

=item Arguments:

    Mandatory
                -mapName:  Array of Map name/s for which the flag action should be sent
    Optional
                -flagAction : Value of Flagaction to be sent. Default is 10 

=item Return Value:

    1 - on success
    0 - on failure

=item Usage:
    $saproObj->sendFlagActionMap(-mapName => "EMSPET1_1");

=back

=cut

sub sendFlagActionMap {
    my($self, %args)=@_;
    my $sub = "sendFlagActionMap";
    my $cmdStaus=1;
    my $flagAction = (defined $args{-flagAction})  ? $args{-flagAction}:10;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");

    foreach ('-mapName') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }


    my @allmapnames = @{$args{'-mapName'}};
    #For every Map defined in trigger_trap the MAP

    my ($cmd,@r);
    foreach (@allmapnames) {
        #Start sending the flagAction
        my $mapName = $_.".map";
        $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$mapName -c flagaction -s $flagAction";
        $logger->debug(__PACKAGE__ . ".$sub: The sapro  cmd is $cmd");
        if ( @r = $self->execCmd("$cmd",300) ) {
            if ($r[0] =~ m/PACKET_EVALUATED[:]*[\s]+.*FlagActionSetRequest sent to.*/i) {
                $logger->debug(__PACKAGE__ . "$sub The sapro command to send flagAction executed successfully for $mapName ");
            } else {
                $logger->debug(__PACKAGE__ . "$sub The sapro command response is not as expected for map $mapName " . Dumper(\@r));
                $cmdStaus = 0;
            }
        } else {
            $logger->error(__PACKAGE__ . "$sub The sapro command to send flagAction failed for $mapName : " . Dumper(\@r));
            $cmdStaus = 0;
        }
    }
    return $cmdStaus;
}


=head2 collectMapStats()
      This functions collects the statistcis data provided by sapro and builds a hash with the  all stats. 
      For the list of maps given, sapcnsl comman is executed. Even if one of the map fails , failure is reported 

=over

=item Arguments:
        Mandatory
                -mapName : Array of Map name/s for which the stats has to be collected 
        Optional
                None

=item Return Value:
        hash structure on success - On Success
        0 - On failure
        Hash structure is
        $stats->{"statsName"}->{ipaddress} where stats is variable declared as hash

=item Usage:
        $result = $saproObj->collectMapStats(-mapName => "EMSPET1_1"); where result is the returned hash structure
        Returned hash for Traps
        $result->{Traps}->{10.54.131.201} .... $result->{Traps}->{10.54.131.250}

=back

=cut

sub collectMapStats {
    my($self, %args)=@_;
    my $sub = "collectMapStats";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
    my $cmd = '';
    my (@r,@statsResult);
    my $status = 1;
    my %stats;

    foreach ('-mapName') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }

    my @allMapNames = @{$args{'-mapName'}};

    #Executing sapcsnl command for all the maps and collecting the response
    foreach (@allMapNames) {
        my $mapName = $_.".map";
        $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$mapName -c stats";
        $logger->debug(__PACKAGE__ . ".$sub: The sapro  cmd is $cmd");
        unless ( @r = $self->execCmd("$cmd",300) ) {
            $logger->error(__PACKAGE__ . "$sub The sapro command to trigger traps failed : " . Dumper(\@r));
            $status = 0;
        }
        push (@statsResult,@r);
    }
  
    #reading the headers 
    my @headerList = ();
    foreach  (@statsResult) {
        if ($_ =~ m/(Device Name)(.*)(Traps)(.*)/i) {
            $_   = "Device_Name $2 $3 $4";
            my @array = split' ', $_;
            @headerList = @array;
            shift @headerList;
            foreach my $header (@headerList) {
                my ($index) = grep  $array[$_] eq "$header" , 0..$#array;
                $stats{'headerIndex'}{"$header"} = $index;
            }
        last;
        }
    }

   
    #Building the hash for the stats
    foreach  (@statsResult) {
        if ($_ =~ m/([0-9\.]+)\/*([0-9]*)[\s+]([0-9\s]+)/i) {
            my @line = split ' ' , $_;
            foreach my $header  (@headerList) {
                $stats{"$header"}{"$line[0]"} = $line[$stats{'headerIndex'}{"$header"}];
            }
    
        }
    }

    return \%stats;

}

=head2 collectMapAllStats()
      This functions collects the statistcis data provided by sapro and returns a hash for all the  stats reported by sapro.
      For the list of maps given, sapcnsl comman is executed and return hash the data for all . Even if one of the map fails , failure is reported 

=over

=item Arguments:
        Mandatory
                -mapName : Array of Map name/s for which the stats has to be collected 
        Optional
                None

=item Return Value:
        hash structure on success - On Success
        0 - On failure
        Hash structure is
        $stats->{"statsName"}->{ipaddress} where stats is variable declared as hash

=item Usage:
        $result = $saproObj->collectMapAllStats(-mapName => "EMSPET1_1"); where result is the returned hash structure
        Returned hash for Traps
        $result->{Traps}->{10.54.131.201} .... $result->{Traps}->{10.54.131.250}

=back

=cut

sub collectMapAllStats {
    my($self, %args)=@_;
    my $sub = "collectMapAllStats";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entered Sub ");
    my $cmd = '';
    my (@r,@statsResult);
    my $status = 1;
    my %stats;

    foreach ('-mapName') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub: manditory argument $_ is blank");
            $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub");
            return 0;
        }
    }

    my @allMapNames = @{$args{'-mapName'}};

    #Executing sapcsnl command for all the maps and collecting the response
    foreach (@allMapNames) {
        my $mapName = $_.".map";
        $cmd = "$self->{'BASEPATH'}/bin/sapcnsl -p 2100 -m $self->{'BASEPATH'}/map/$mapName -c allstats";
        $logger->debug(__PACKAGE__ . ".$sub: The sapro  cmd is $cmd");
        unless ( @r = $self->execCmd("$cmd",300) ) {
            $logger->error(__PACKAGE__ . "$sub The sapro command to trigger traps failed : " . Dumper(\@r));
            $status = 0;
        }
        push (@statsResult,@r);
    }

    my @headerList = ();
    #reading the headers  and building the index for each of the element
    foreach  (@statsResult) {
        if ($_ =~ m/(Device Name)(.*)(Traps)(.*)/i) {
            $_   = "Device_Name $2 $3 $4";
            my @array = split' ', $_;
            @headerList = @array;
            shift @headerList;
            foreach my $header (@headerList) {
                my ($index) = grep  $array[$_] eq "$header" , 0..$#array;
                $stats{'headerIndex'}{"$header"} = $index;
            }
        last;
        }
    }
    #Building the hash for the stats
    foreach  (@statsResult) {
        if ($_ =~ m/(^[0-9\.]+)\/*([0-9]*)[\s+]([0-9\s]+)/i) {
            my @line = split ' ' , $_;
            foreach my $header  (@headerList) {
                $stats{"$header"}{"$line[0]"} = $line[$stats{'headerIndex'}{"$header"}];
            }

        }
    }

    return \%stats;

}

=head2 addSutDetails()

    This function obtains DUT details w.r.t memory,cpu and other hardware specifications.
    Prints all the metrics in "$self->{result_path}/Result/Testcase_Results.txt

=over

=item Arguments:

        No arguments necessary. It is called by the perfLogger Object in compareOldRelease subroutine.

=item Return Value:

        1 - On Success 

=item Usage:

        $perfLoggerObj->addSutDetails();

=item Author:

        Sukruth Sridharan (ssridharan@sonusnet.com)

=back

=cut

sub addSutDetails
{
    my $sub = "addSutDetails";
    my $self = shift;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    #Parsing the files for the performance metrics.The file list will varry if the SUT is virtulaised  
    my @files = ($self->{PerfLoggerSut},$self->{HostTmsAlias}) if ($self->{hypervisor} eq 'KVM');
    @files = ($self->{PerfLoggerSut}) if (($self->{HostTmsAlias} eq  '') || ($self->{hypervisor} eq 'VMware'));
    my $runIdfile = `ls $self->{result_path}/*$self->{PerfLoggerSut}*sql`;
    my $runUID;
    my $fp;
    my @sqlfile;
    my $type = "\L$self->{sutType}";
    $type =~ s/_sut//g; #EMS_SUT should be converted to ems
    foreach(@files)
    {
      my $file = `ls $self->{result_path}/*$_*sql`;
      push(@sqlfile,$file);
    }
    my @keys    = qw(pt_run_uuid pt_test pt_host pt_release pt_devicetype pt_date pt_metadata);
    open( $fp, '>>', "$self->{result_path}/../Result/Testcase_Results.txt" );
    my $psxObj = SonusQA::ATSHELPER::newFromAlias(-tms_alias => "$self->{PerfLoggerSut}", -ignore_xml => 0,-sessionlog => 1 );
    if ($#sqlfile < 0) 
    {
        $logger->fatal(__PACKAGE__ . ".$sub: Perflogger has not run properly. There are no sql files. Exiting the subroutine");
        return 0;        
    }   
    foreach (@sqlfile)
    {
        chomp( my $line = `head -1 $_` );
        $line =~ s/.*VALUES//g;
        $line =~ s/[(|)]//g;
        my @values = split( /,/, $line );
        my %hash = map { $keys[$_] => $values[$_] } 0 .. $#keys;
        $runUID = $hash{'pt_run_uuid'} if ( $_ eq $runIdfile );
        $runUID =~ s/0x//g ;
        if ((grep( /VMware/,$hash{'pt_devicetype'} )) || (grep( /KVM/,$hash{'pt_devicetype'} )))
        {
             my $hostPort = (defined $psxObj->{TMS_ALIAS_DATA}->{VM_HOST}->{1}->{PORT}) ? $psxObj->{TMS_ALIAS_DATA}->{VM_HOST}->{1}->{PORT}:22 ;
             #Connect to the host to get the details
             my %refined_args;
             $refined_args{-sessionlog} = 1;
             unless ( $psxObj->{HostMachine_session} ) {
                 $psxObj->{HostMachine_session} = new SonusQA::TOOLS(
                                          -obj_host       => "$psxObj->{TMS_ALIAS_DATA}->{VM_HOST}->{1}->{IP}",
                                          -obj_user       => "root",
                                          -obj_password   => "$psxObj->{TMS_ALIAS_DATA}->{VM_HOST}->{1}->{ROOTPASSWD}",
                                          -comm_type      => 'SSH',
                                          -obj_port       => $hostPort,
                                          -return_on_fail => 1,
                                          -defaulttimeout => 120,
                                            %refined_args,
                                        );
                 unless ( $psxObj->{HostMachine_session} ) {
                 $logger->error(__PACKAGE__ . ".$sub: Could not open connection to Host Machine on $psxObj->{TMS_ALIAS_DATA}->{VM_HOST}->{1}->{IP} on port $hostPort with credentials root/$psxObj->{TMS_ALIAS_DATA}->{VM_HOST}->{1}->{ROOTPASSWD}");
                 return 0;
                 }
            }
            my @r;
            if (($self->{hypervisor} eq 'VMware'))
            {
                    $logger->info(__PACKAGE__ . ".$sub: Obtaining VMware ESXi version");
                    @r = $psxObj->{HostMachine_session}->execCmd("vmware -vl") ;
                    print $fp "\n\nVMware host version details:\n@r\n";
            }
            else
            {
                    $logger->info(__PACKAGE__ . ".$sub: Obtaining OS version of KVM host");
                    my $cmd = "dmidecode -s system-product-name | grep -v \"^#\"";
                    my @res = $psxObj->{HostMachine_session}->execCmd("$cmd");                          
                    @r = ( grep( /ConnexIP/, @res ) ) ? @res : $psxObj->{HostMachine_session}->execCmd("cat /etc/redhat-release");  
                    print $fp "\n\nKVM host version details:\n@r\n";
                    @r = $psxObj->{HostMachine_session}->execCmd("uname -a");
                    print $fp "@r\n";
                    @res = $psxObj->{HostMachine_session}->execCmd("unalias grep");  # TOOLS-6589 to remove specical charcter
                    $cmd = "rpm -qa | grep nova-common";
                    @res = $psxObj->{HostMachine_session}->execCmd("$cmd");
                    print $fp "\nOpenStack controller version:\n$res[0]\n" if ( grep (/[O|o]pen/,@res));
            }
        }
        print $fp "\n***********DUT RELATED INFO ******************\nThe device $hash{'pt_host'} has the following config\n";
        print $fp "Hostname = $hash{'pt_host'}\n";
        print $fp "Device type = $hash{'pt_devicetype'}\n";
        print $fp "Device Specifications = $hash{'pt_metadata'}\n";
        print $fp "Seagirt link(if uploaded) = http://perfdbhost.in.sonusnet.com/PTDATA/plot.php?product=$type&runuuid=$runUID\n";
        print $fp "\n**********************************************\n";
    }
    $psxObj->DESTROY();
    close($fp);
    return 1;
}


=head2 startIostatScript
       This subroutine scps a perl script to the PSX and starts the script in background
       SCP is options and controlled by flag.
        
       Functionality:
                Picks up login credentials from perflogger object, transfers the perl script to SUT, starts the perl script in background (stores pid in perflogger object)

=over

=item Arguments :

 Mandatory:
        -testId : test id  (default is PerfLoggerTestid from perflogger object : Generated only when start_perflogger is called)
        -sutTmsAlias : tms alias of the sut (default is PerfLoggerSut of the perflogger object :Generated only when start_perflogger is called)
 Optional:
        -filePath : path of the script to be SCPed and started in background on the SUT (optional : default is /ats/tools/perf/Tools/iostat.pl)
        -shouldScp : yes/no  ::: to transfer the file(via scp) or not (optional : default is yes)

=item Return Values :

        0 : failure
        1 : Success

=item Example :

        $perfLoggerObject->startIostatScript(
                                -testId         => "PSX-607",
                                -sutTmsAlias    => "galileo",
                                -filePath       => "/ats/tools/perf/iostat.pl",
                                -shouldScp            => "yes");
        If start_perflogger is used, this script is started automatically and stopped , no need to call it explicitly.
        If called explicitly, use stopIostatScript to stop the script
                Example : $perfloggerObj->stopIostatScript(-sutTmsAlias => "galileo");
        output file sample : IOSTAT_PSX-221_galileo_SCRIPT_Wed_17_Aug_2016_11_47_44.csv


=item Author:

        Satya Nemana (snemana)

=back

=cut

sub startIostatScript{
        my ($self,%args) = @_;
        my $sub = 'startIostatScript';
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
        $logger->info(__PACKAGE__ . ".$sub Entered Sub ");
        $logger->info(__PACKAGE__ . ".$sub args are ".Dumper(%args));
        my $testId = defined $args{-testId}?$args{-testId}:$self->{PerfLoggerTestid};
        my $sutTmsAlias=defined $args{-sutTmsAlias}?$args{-sutTmsAlias}:$self->{PerfLoggerSut};
        my $filePath = defined $args{-filePath}?$args{-filePath}:"/ats/tools/perf/iostat.pl"; # we pick up the .pl from /ats/tools/perf/
        my $shouldScp=defined $args{-shouldScp}?$args{-shouldScp}:"yes"; #default is yes
        my $ipVersion=defined $args{-ipVersion}?$args{-ipVersion}:"v4"; #default is v4
        $logger->info(__PACKAGE__ . ".$sub testId:$testId sutTmsAlias:$sutTmsAlias filepath:$filePath, shouldSCP=$shouldScp, ipVersion:\"$ipVersion\"");
        if(defined $self->{IOSTAT_PID}){
                        $logger->error( __PACKAGE__ . ".$sub:  Already a script is running , cant start a new one");
                        $logger->debug( __PACKAGE__ . ".$sub:  <-- Leaving sub. [0]" );
                        return 0;
        }
        unless(defined $testId and defined $sutTmsAlias){
                        $logger->error( __PACKAGE__ . ".$sub:  Must arguments testId or tms alias missing");
                        $logger->debug( __PACKAGE__ . ".$sub:  <-- Leaving sub. [0]" );
                        return 0;
        }
        #this is treated as a common path across all linux and solaris boxes and has a large size allocation
        my $pathOnSut="/export/home/";
        my $outputFile="null";
        my $SutObj= SonusQA::ATSHELPER::newFromAlias(-tms_alias => $sutTmsAlias, -DEFAULTTIMEOUT => 10, -SESSIONLOG => 1, -iptype => $ipVersion);
        #First SCP the file to the SUT
        if(defined $shouldScp and lc($shouldScp) eq "yes")
        {
        my %scpArgs;
        my $destinationPath=$pathOnSut;
        $scpArgs{-hostip}              = ($ipVersion eq "v6")?($SutObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6}):($SutObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP});
        $scpArgs{-hostuser}            = "root";
        $scpArgs{-hostpasswd}          = $SutObj->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
        $scpArgs{-scpPort}             = 22;
        $scpArgs{-destinationFilePath} = $scpArgs{-hostip} . ':'.$destinationPath;
        $scpArgs{-sourceFilePath} = $filePath;
        $logger->info(__PACKAGE__ . ".$sub scpArgs is ".Dumper(%scpArgs));
        unless ( &SonusQA::Base::secureCopy(%scpArgs) ) {
                        $logger->error( __PACKAGE__ . ".$sub:  SCP failed" );
                        $logger->debug( __PACKAGE__ . ".$sub:  <-- Leaving sub. [0]" );
                        $SutObj->DESTROY();
                        return 0;
                }
        }
        my $hostname=$SutObj->{SYS_HOSTNAME};
        my ($name,$path,$suffix) = fileparse($filePath, '.pl');
        $logger->info(__PACKAGE__ . ".$sub Filename:$name,Path:$path");
        my $fullFileName=$pathOnSut.$name.$suffix;
        my $datestring = strftime "%a_%d_%b_%Y_%H_%M_%S", localtime;
        $logger->info(__PACKAGE__ . ".$sub hostname:$hostname, datestring:$datestring");
        $outputFile=$pathOnSut."IOSTAT_".$testId."_".$hostname."_SCRIPT_".$datestring.".csv";
        #Run the command as root to be safest
        $SutObj->enterRootSessionViaSU();
        my @cmdResults=$SutObj->execCmd("chmod 777 $fullFileName");
        $logger->debug( __PACKAGE__ . ".$sub:  Cmd results ".Dumper(@cmdResults));
        @cmdResults=$SutObj->execCmd("perl  $fullFileName >> $outputFile &");
        $self->{IOSTAT_SCRIPT_CSV_FILE}=$outputFile;
        $logger->debug( __PACKAGE__ . ".$sub:  Cmd results ".Dumper(@cmdResults));
        my $pid="-99999";
        foreach(@cmdResults){
        my $currentLine=$_;
        if($currentLine =~ m/[\w]/i ){
                my @tokens=split(/\s/,$currentLine);
                $pid=$tokens[1];
                $logger->info( __PACKAGE__ . ".$sub:  PID is $pid");
                }
        }
        $self->{IOSTAT_PID}=trim($pid);
        $logger->debug( __PACKAGE__ . ".$sub:  Destroying SUT object that we created");
        $SutObj->DESTROY();
        if($pid != -99999){
        $logger->info( __PACKAGE__ . ".$sub: Returning success");
        return 1;
        }
        $logger->error( __PACKAGE__ . ".$sub: Returning failure as PID is not valid : PID is \"$pid\"");
        return 0;
}

=head2 stopIostatScript

        This subroutine stops the iostat script and transfers the file to perflogger path through scp.

=over

=item Arguments : 
            (arguments are indirectly picked up from the perflogger object when used implicitly from start_perflogger)
            When used explicitly, the following rules apply

=item Mandatory:

        -sutTmsAlias

 Optional:

=item Return Values :

        0 : failure
        1 : Success

=item Example :
        $perfloggerObj->stopIostatScript(-sutTmsAlias => $psxTmsAlias);
        When using stop_perflogger, no need to call explicitly, this script is called implicitly.

=item Author :

        Satya Nemana (snemana)

=back

=cut

sub stopIostatScript{
        my ($self, %args ) = @_ ;
        my $sub = 'stopIostatScript';
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
        $logger->info(__PACKAGE__ . ".$sub Entered Sub ");
        $logger->info(__PACKAGE__ . ".$sub args are ".Dumper(%args));
        my $sutTmsAlias=defined $args{-sutTmsAlias}?$args{-sutTmsAlias}:$self->{PerfLoggerSut};
        my $ipVersion=defined $args{-ipVersion}?$args{-ipVersion}:"v4"; #default is v4
        unless(defined $sutTmsAlias){
                        $logger->error( __PACKAGE__ . ".$sub:  mandatory argument -sutTmsAlias is missing");
                        $logger->info( __PACKAGE__ . ".$sub:  <-- Leaving sub. [0]" );
                        return 0;
        }
        $logger->debug( __PACKAGE__ . ".$sub: SUT alis received is $sutTmsAlias, ipVersion is \"$ipVersion\"");
        my $SutObj= SonusQA::ATSHELPER::newFromAlias(-tms_alias => $sutTmsAlias, -DEFAULTTIMEOUT => 10, -SESSIONLOG => 1,-iptype => $ipVersion);
        $logger->info(__PACKAGE__ . ".$sub doing a kill -2 on PID:$self->{IOSTAT_PID}");
        $SutObj->enterRootSessionViaSU();
        $logger->info( __PACKAGE__ . ".$sub: Command results of kill".Dumper($SutObj->execCmd("kill -2 $self->{IOSTAT_PID}")));
        sleep 2; #just a little pause before we check if killed
        $logger->info( __PACKAGE__ . ".$sub: Command results of ps grep".Dumper($SutObj->execCmd("ps -eaf | grep iostat")));
        undef $self->{IOSTAT_PID}; #undefine the variable so that same perflogger object can be used to call the function again and again.
        #copying the .csv file from SUT to our result path
        if(defined $self->{result_path})
        {
        my %scpArgs;
        #my $destinationPath=$pathOnSut;
        $scpArgs{-hostip}              = ($ipVersion eq "v6")?($SutObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IPV6}):($SutObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP});
        $scpArgs{-hostuser}             = "root";
        $scpArgs{-hostpasswd}           = $SutObj->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{ROOTPASSWD};
        $scpArgs{-scpPort}              = 22;
        $scpArgs{-destinationFilePath}  = $self->{result_path};
        $scpArgs{-sourceFilePath}       = $scpArgs{-hostip}.':'.$self->{IOSTAT_SCRIPT_CSV_FILE};
        unless ( &SonusQA::Base::secureCopy(%scpArgs) ) {
                        $logger->error( __PACKAGE__ . ".$sub:  SCP failed" );
                        $logger->info( __PACKAGE__ . ".$sub:  <-- Leaving sub. [0]" );
                        $SutObj->DESTROY();
                        return 0;
                }
        }
        else
        {
        $logger->info( __PACKAGE__ . ".$sub: The result CSV file, $self->{IOSTAT_SCRIPT_CSV_FILE} is not SCPed to result path as \"result_path\" is not defined for the perflogger object");
        }
        $logger->info( __PACKAGE__ . ".$sub: Command results of removing .csv file from SUT".$SutObj->execCmd("rm -f $self->{IOSTAT_SCRIPT_CSV_FILE}"));        
        $logger->info( __PACKAGE__ . ".$sub: Destroying SUT object that we created");
        $SutObj->DESTROY();
        $logger->info( __PACKAGE__ . ".$sub: Returning success");
        return 1;
}

#simple function to remove spaces at the begining and ending of strings
sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s; }



1;

