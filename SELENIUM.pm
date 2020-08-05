package SonusQA::SELENIUM;

=head1 NAME

SonusQA::SELENIUM - Perl module for SELENIUM application control.

=head1 AUTHOR


=head1 IMPORTANT

This module is a work in progress, it should work as described, but has not undergone extensive testing.

=head1 DESCRIPTION

This module provides an interface for the SELENIUM test tool.
Control of command input is up to the QA Engineer implementing this class
allowing the engineer to specific which attributes to use.

=head1 METHODS

=cut

use ATS;
use Net::Telnet ;
use SonusQA::Utils qw(:all);
use strict;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use Module::Locate qw /locate/;
our $VERSION = '1.0';
use POSIX qw(strftime);
use vars qw($self);
use File::Basename;
use JSON;
our @ISA = qw(SonusQA::Base SonusQA::SessUnixBase);
our $TESTSUITE;

# INITIALIZATION ROUTINES FOR CLI

=head2 SonusQA::SELENIUM::doInitialization()

  Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically,
  use to set Object specific flags, paths, and prompts.

=over

=item Arguments

  None

=item Returns

  Nothing

=back

=cut

sub doInitialization {

    my ($self , %args)=@_ ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
    my $sub = 'doInitialization' ;
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");

    $self->{COMMTYPES} = ["SSH","TELNET"];
    $self->{COMM_TYPE} = "SSH";
    $self->{PROMPT} = '/.*[\$%\}\|\>]\s?$/';
    $self->{OBJ_COMMTYPE} = 'SSH';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $self->{TYPE} = __PACKAGE__;
    $self->{conn} = undef;
    $self->{DEFAULTTIMEOUT} = 36000  ;
    $self->{USER} = `id -un`;
    chomp $self->{USER};
    $logger->info("Initialization Complete");
    $logger->info(__PACKAGE__ . ".$sub: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::setSystem()

  Base module over-ride.  This routine is responsible to completeing the connection to the object.
  It performs some basic operations on the SELENIUM to enable a more efficient automation environment.

=over

=item Arguments

  None

=item Returns

  Nothing

=back

=cut

sub setSystem {

    my( $self, %args )=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
    my $sub = 'setSystem';
    $logger->info(__PACKAGE__ . ".$sub: --> Entered Sub");
    #$self->{conn}->cmd(String => "tlntadmn config timeoutactive=no", Timeout=> $self->{DEFAULTTIMEOUT}); #Disabling the Telnet session timeout

    $logger->debug(__PACKAGE__ . ".setSystem: ENTERED SELENIUM TESTUSER SUCCESSFULLY");
    $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
    return 1;

}

=head2 SonusQA::SELENIUM::runSeleniumSuite()

  It checks the defined mandatory parameters.
  It then runs the command ( from the path where jar file is stored... [Taken care by the function sub createPropFile] ):
    java -DPropertyFile="<PropertyFile Location>" -jar <NAME.jar>

  Note : It is mandatory to keep the property file in the same location as that of Jar file location.

=over

=item Arguments

  Mandatory :
    -jarLoc => Location of the jar file
    -propFile => Name of the Property file  (with extension)
    -jarName => Name of the jar file

=item Returns

  1 : on success
  0 : on failure

=back

=cut

sub runSeleniumSuite {

    my ($self, %args) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".runSeleniumSuite");
    my $sub_name = "runSeleniumSuite";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-jarLoc', '-propFile', '-jarName') {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }
    
    my $execCommand = '' ; 
    if (defined $args{-operation}) {
        $logger->info(__PACKAGE__ . ".$sub_name: operation parameter is defined, hence modifying the command accordingly");
        $logger->info(__PACKAGE__ . ".$sub_name: run command : java -DPropertyFile=\"$args{-propFile}\" -DOperation=\"$args{-operation}\" -jar $args{-jarName}.jar");
        $execCommand = "java -DPropertyFile=\"$args{-propFile}\" -DOperation=\"$args{-operation}\" -jar $args{-jarName}.jar";

    } else {
        $logger->info(__PACKAGE__ . ".$sub_name: run command without the operation parameter");
        $logger->info(__PACKAGE__ . ".$sub_name: run command : java -DPropertyFile=\"$args{-jarLoc}\\$args{-propFile}\"  -jar \"$args{-jarLoc}\\$args{-jarName}.jar\"");
        $execCommand = "java -DPropertyFile=\"$args{-jarLoc}\\$args{-propFile}\" -jar \"$args{-jarLoc}\\$args{-jarName}.jar\"";

    }

    my $res = '' ; 
     $logger->info(__PACKAGE__ . ".$sub_name:executing command");
    unless ( $res = $self->{conn}->cmd($execCommand)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to run the command");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    } 

    $logger->info(__PACKAGE__ . ".$sub_name:executed successfully the command");

    return 1;
}

=head2 SonusQA::SELENIUM::runSeleniumForeground()

  It checks the defined mandatory parameters.
  It then runs the command ( from the path where jar file is stored... [Taken care by the function sub createPropFile] ):
     PsExec.exe -i -s cmd /c java -DPropertyFile="<PropertyFile Location>" -jar <NAME.jar>

  NOTE : It is mandatory to keep the property file in the same location as that of Jar file location.

=over

=item Arguments

  Mandatory :
    -jarLoc => Location of the jar file
    -propFile => Name of the Property file  (with extension)
    -jarName => Name of the jar file

=item Returns

  1 : on success
  0 : on failure

=back

=cut

sub runSeleniumForeground {

    my ($self, %args) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".runSeleniumForeground");
    my $sub_name = "runSeleniumForeground";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-jarLoc', '-propFile', '-jarName') {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }

    my $execCommand = '' ;
    my (@qwinsta,$id,$userid);
    unless ( $userid = $self->{TMS_ALIAS_DATA}->{LOGIN}->{1}->{USERID}){ # gives sonusnetworks\ajames
        $logger->error(__PACKAGE__.".$sub_name USERID is not Available ");
        return 0;   
    }
    chomp($userid);
    $userid =~  /\\\s*(\w+)$/; # Get the username (i.e) ajames
    my $username = $1;
    $logger->debug(__PACKAGE__.".$sub_name: \$username is $username");
     
    @qwinsta = $self->{conn}->cmd("qwinsta $username"); # Execute 'qwinsta ajames' in command prompt 
    
    $logger->debug(__PACKAGE__.".$sub_name: Executed command \"qwinsta $username\"");
    foreach (@qwinsta) {
  	if($_ =~ /$username\s+(\d+).*/){ # Regular expression to get the Session id 
	    $id = $1;    	
            last;
	}
    }
    if (defined $args{-operation}) {
        $logger->info(__PACKAGE__ . ".$sub_name: operation parameter is defined, hence modifying the command accordingly");
        $logger->info(__PACKAGE__ . ".$sub_name: run command : PsExec.exe -i $id -s cmd /c \"java -DPropertyFile=\"$args{-propFile}\" -DOperation=\"$args{-operation}\" -jar $args{-jarName}.jari\"");
        $execCommand = "PsExec.exe -i $id -s cmd /c \"java -DPropertyFile=\"$args{-propFile}\" -DOperation=\"$args{-operation}\" -jar $args{-jarName}.jar\"";

    } else {
        $logger->info(__PACKAGE__ . ".$sub_name: run command without the operation parameter");
        $logger->info(__PACKAGE__ . ".$sub_name: run command : PsExec.exe -i $id -s cmd /c \"java -DPropertyFile=\"$args{-jarLoc}\\$args{-propFile}\" -jar \"$args{-jarName}.jar\"");
        $execCommand = "PsExec.exe -i $id -s cmd /c \"java -DPropertyFile=\"$args{-jarLoc}\\$args{-propFile}\" -jar $args{-jarName}.jar\"";

    }

    my $res = '' ;
     $logger->info(__PACKAGE__ . ".$sub_name:executing command");
    unless ( $res = $self->{conn}->cmd($execCommand)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to run the command");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }
    $res = $self->parseResultFile(%args);
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Finished parsing Result file, Return value: $res");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub.");
    return $res; 
}

=head2 SonusQA::SELENIUM::createPropFile()

  It changes the path directory to the mentioned path where the jar file is located.
  If the "content hash"(defined by user) is present, it update the value in the property file according to the mentioned parameters.
  In absence of hash, it doesn't modify the Property file.

=over

=item Arguments

  Mandatory :
    -jarLoc => Location of the jar file
    -propFile => Name of the Property file  (with extension) viz -> propFile  => 'PER_5713.properties'

=item Returns

  1 : on successful creation of file
  0 : on failure (if any error comes)

=item Example(s)

  $obj->createPropFile(content => {EMS_IP=>'10.10.10.10', Implict_TimeOut=>'UNKNOWN', Admin_User_Name=>'PASSWORD'} , jarLoc => 'D:\Sel' , propFile  => 'PER_5713.properties');

=back

=cut

sub createPropFile {

    my ($self , %args ) = @_ ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createPropFile");
    my $sub_name = "createPropFile";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
   
    foreach ( 'jarLoc' , 'propFile' ){
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
            return 0;
        }
    }

    my $drive = '' ;
    $logger->info(__PACKAGE__ . ".$sub_name: taking the first character of the path ");
    if ( $args{jarLoc} =~  m/\s*(\w+):.*$/ ) {
     $drive = $1;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: changing the drive to the mentioned Directory \'$drive\'");
    $self->{conn}->cmd("dir");
    unless ($self->{conn}->cmd("$drive:")){
        $logger->error(__PACKAGE__ . ".$sub_name: unable to change directory to \'$drive\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: changing the path to the mentioned path '$args{jarLoc}' ");
    
    unless ($self->{conn}->cmd("cd $args{jarLoc}")){
        $logger->error(__PACKAGE__ . ".$sub_name: unable to change directory to $args{jarLoc}");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    my @output = () ; 

    unless ( @output = $self->{conn}->cmd("type $args{propFile}")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Not able to print the file with the argument \'-propFile\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }      
    chomp @output ;

    @output = grep /\S/,@output;
    $logger->info(__PACKAGE__ . ".$sub_name:Output array :" . Dumper(\@output) );

     #to disable all the test cases which are already enabled 
    foreach my $output (@output){
    my ($name, $value) = split /=/, $output;
     $value =~ s/^\s+//;
     $value =~ s/\s+$//;
   		 
    if (defined($value) and ($value eq 'enabled') and ($name  =~ m/TestCaseEnabled/)){
       $logger->info(__PACKAGE__ . ".$sub_name: argument exists , hence replacing it ");
       $output = join "=", $name, " not-enabled";  
     
     }

    }
     $logger->info(__PACKAGE__ . ".$sub_name: checking for the hash if its already present"); 
     if (exists($args{content})) {
       foreach my $key (keys %{$args{content}}) {
             my $count = 0 ;
             for (my $comp=0 ; $comp<=$#output ; $comp++){
                 if ($output[$comp] =~ m/\b$key\b/i){
                  	 $logger->info(__PACKAGE__ . ".$sub_name: argument '$key' exists , hence replacing it ");
                     $output[$comp] = "$key = $args{content}{$key}" ;
                     $count++ ;
                     last ;
                 } else {
                       next ;  
                 }          
             }   
        
             $logger->info(__PACKAGE__ . ".$sub_name: value of count = $count");
                 if ($count == 0) {
                 $logger->info(__PACKAGE__ . ".$sub_name: argument doesnt exist  , hence pushing the value as key value pair ");
                 push (@output , "$key=$args{content}{$key}"  ) ;
             }     
         }

        if (defined $args{bkpPropFile}) {
  
            unless ($self->{conn}->cmd("DEL $args{bkpPropFile}") ) {
            $logger->info(__PACKAGE__ . ".$sub_name: not able to delete the property file $args{propFile}");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
            
        }
        my $fileName = "$args{bkpPropFile}" ;

        foreach(@output){
                $_ =~ s/^\s+|\s+$//g;
                $_ =~ s/(<|>)/^$1/g;             #Fix for TOOLS-15660. Replacing '< or >' symbol before writing into file
                unless ($self->{conn}->cmd("echo.$_ >>$fileName")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: unable to echo the file parameters to $fileName");
                    $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
                    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
                    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
                    return 0;
                }
        }
           

        } else {

       
        unless ($self->{conn}->cmd("DEL $args{propFile}") ) {
            $logger->info(__PACKAGE__ . ".$sub_name: not able to delete the property file $args{propFile}");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
            return 0;
        }
        my $fileName = "$args{propFile}" ;
         
        foreach(@output){
                $_ =~ s/^\s+|\s+$//g;
                $_ =~ s/(<|>)/^$1/g;             #Fix for TOOLS-15660. Replacing '< or >' symbol before writing into file
                unless ($self->{conn}->cmd("echo.$_ >>$fileName")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: unable to echo the file parameters to $fileName");
        	    $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        	    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
                    return 0;
                }
       	}  
     }
    }
    return 1 ;
}

=head2 SonusQA::SELENIUM::createPropFileAuto()

  It changes the path directory to the mentioned path where the jar file is located.
  The API automatically reads all the attributes defined in the TESTBED alais and replaces the values if found in the property file.
  The difference wrt to createPropFile function is that, this takes TESTBED as an argument. Does not rely on the user to pass each value indivudally.
  The key defined in the test bed alais should be exactly the same as defined in the property file.
  In absence of hash, it doesn't modify the Property file.

=over

=item Arguments

  Mandatory :
    -content => TESTBED hash 
    -jarLoc => Location of the jar file
    -propFile => Name of the Property file  (with extension) viz -> propFile  => 'PER_5713.properties'
    -bkpPropFile => Name of the Property file, which needs to be generated by this function  (with extension) viz -> propFile  => 'PER_5713_bkp.properties'

=item Returns

  1 : on successful creation of file
  0 : on failure (if any error comes)

=item Example(s)

  $seleniumObj->createPropFileNew(content => \%TESTBED_New , jarLoc => $jarLoc , propFile  => $propFile, bkpPropFile => $bkpProp_name);

=back

=cut
sub createPropFileAuto {

    my ($self , %args ) = @_ ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createPropFile");
    my $sub_name = "createPropFileAuto";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    my $tcId = $args{testCase};
    my $verifyAfterUpgrade = $args{verifyAfterUpgrade};
    $logger->info(__PACKAGE__ . ".$sub_name: Test case to enable: $tcId");
    $logger->info(__PACKAGE__ . ".$sub_name: Tms Alias Hash recevied:" . Dumper(\%{$args{content}}));
    $logger->info(__PACKAGE__ . ".$sub_name: Verify after upgrade:" . $verifyAfterUpgrade);
    
    #undef %CompleteTmsAliasHash;
    #&ConvertTmsAliasToSingleHash(\%{$args{content}});
    my %CompleteTmsAliasHash = %{$args{content}};
    $logger->info(__PACKAGE__ . ".$sub_name:Converted Tms Alias Hash array :" . Dumper(\%CompleteTmsAliasHash) );

    unless(exists ($CompleteTmsAliasHash{'JAR_DIR'}))
    {
       $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument JAR_DIR is not found in the TMS alias");
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
       return 0;
    }

    unless(exists ($CompleteTmsAliasHash{'ENV_FILE'}))
    {
       $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument ENV_FILE is not found in the TMS alias");
       $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
       return 0;
    }
 
    my $prop_name = $CompleteTmsAliasHash{'ENV_FILE'};
    if($verifyAfterUpgrade == 1)
    {
       $prop_name = "Verify_".$prop_name;
       $CompleteTmsAliasHash{'ENV_FILE'} = $prop_name;
       $logger->info(__PACKAGE__ . ".$sub_name: Verify after upgrade, so env file updated to  :".$prop_name);
    }
    my $jarLoc = $CompleteTmsAliasHash{'JAR_DIR'};
    	
    my @array1=split("\\.",$prop_name);
    my $bkpPropFile = $array1[0].'_bkp.properties';
    my $propFile = $jarLoc.'\\'.$prop_name;
    $bkpPropFile = $jarLoc.'\\'.$bkpPropFile;

 
    my $drive = '' ;
    $logger->info(__PACKAGE__ . ".$sub_name: taking the first character of the path ");
    if ( $jarLoc =~  m/\s*(\w+):.*$/ ) {
     $drive = $1;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: changing the drive to the mentioned Directory \'$drive\'");
    $self->{conn}->cmd("dir");
    unless ($self->{conn}->cmd("$drive:")){
        $logger->error(__PACKAGE__ . ".$sub_name: unable to change directory to \'$drive\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: changing the path to the mentioned path '$jarLoc' ");
    
    unless ($self->{conn}->cmd("cd $jarLoc}")){
        $logger->error(__PACKAGE__ . ".$sub_name: unable to change directory to $jarLoc");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    my @output = () ; 
    $logger->info(__PACKAGE__ . ".$sub_name: reading the property $propFile ");
	$self->{conn}->buffer_empty;
my $len = $self->{conn}->max_buffer_length;
    $logger->info(__PACKAGE__ . ".$sub_name: len: $len");
    $logger->info(__PACKAGE__ . ".$sub_name: len: self: ". Dumper($self));

    unless ( @output = $self->{conn}->cmd("type $propFile")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Not able to print the file with the argument \'-propFile\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->error(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }      
    chomp @output ;

    @output = grep /\S/,@output;
    $logger->info(__PACKAGE__ . ".$sub_name:Output array :" . Dumper(\@output) );
    $logger->info(__PACKAGE__ . ".$sub_name: len: last_prompt:  ". $self->{conn}->last_prompt);
    $logger->info(__PACKAGE__ . ".$sub_name: len: prompt:  ". $self->{conn}->prompt);

   #to disable all the test cases which are already enabled 
   foreach my $output (@output){
    my ($name, $value) = split /=/, $output;
     $value =~ s/^\s+//;
     $value =~ s/\s+$//;
   		 
    #if (defined($value) and ($value eq 'enabled') and ($name  =~ m/TestCaseEnabled/)){
    if (defined($value) and ($name  =~ m/TestCaseEnabled/)){
       $logger->info(__PACKAGE__ . ".$sub_name: argument exists , hence replacing it ");
       my @tc = split('_', $name);
       my $tcIdFound = $tc[1];
       if($tcIdFound eq $tcId)
       {
       	   $output = join "=", $name, " enabled";  
       }
       else
       {
       	   $output = join "=", $name, " not-enabled";  
       }
     }

    }


    #Keep command and values specific to this test case only
    my @newOutput = () ;
    foreach my $output (@output){
      my ($name, $value) = split /=/, $output;
      $value =~ s/^\s+//;
      $value =~ s/\s+$//;
      if (defined($value))
      {
        if (($name =~ /^test_/))
        {
	  #Found test_, check if its related to this test case
          my @tc = split('_', $name);
          my $tcIdFound = $tc[1];
          if($tcIdFound eq $tcId)
          {
	   push (@newOutput, $output);	
          } 
        }
	else
	{	
	   push (@newOutput, $output);	
	}
      }

    }

    $logger->info(__PACKAGE__ . ".$sub_name:New Output array :" . Dumper(\@newOutput) );

 
     $logger->info(__PACKAGE__ . ".$sub_name: checking for the hash if its already present"); 
     if (exists($args{content})) {
       foreach my $key (keys %CompleteTmsAliasHash) {
             my $count = 0 ;
             for (my $comp=0 ; $comp<=$#newOutput ; $comp++){
		 if($key =~ /^ *$/) {
			next;
		 }
                 if ($newOutput[$comp] =~ m/\b$key\b/i){
                  	 $logger->info(__PACKAGE__ . ".$sub_name: argument '$key' exists , hence replacing it ");
                     $newOutput[$comp] = "$key = $CompleteTmsAliasHash{$key}" ;
                     $count++ ;
                     last ;
                 } else {
                       next ;  
                 }          
             }   
        
             $logger->info(__PACKAGE__ . ".$sub_name: value of count = $count");
                 if ($count == 0) {
                 $logger->info(__PACKAGE__ . ".$sub_name: argument $key doesnt exist  , hence ignoring the values");
                 #push (@newOutput , "$key=$args{content}{$key}"  ) ;
             }     
         }

         unless ($self->{conn}->cmd("DEL $bkpPropFile") ) {
            $logger->info(__PACKAGE__ . ".$sub_name: not able to delete the property file $bkpPropFile");
            $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
            $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
            
         }
         my $fileName = "$bkpPropFile" ;
         $logger->info(__PACKAGE__ . ".$sub_name: Writing the property file on to the remote system");

         foreach(@newOutput){
                $_ =~ s/^\s+|\s+$//g;
                $_ =~ s/(<|>)/^$1/g;             #Fix for TOOLS-15660. Replacing '< or >' symbol before writing into file
                unless ($self->{conn}->cmd("echo.$_ >>$fileName")) {
                    $logger->error(__PACKAGE__ . ".$sub_name: unable to echo the file parameters to $fileName");
                    $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
                    $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
                    $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
                    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
                    return 0;
                }
        }
        $logger->info(__PACKAGE__ . ".$sub_name: Finsihed writing the property file on to the remote system");
           
    }
   return 1 ;
}


=head2 SonusQA::SELENIUM::parseResultFile()

  changes the working directory to the mentioned path of the logs folder.
  picks the latest log folder according to the timestamp.
  changes the directory to the picked folder and further picks the result file created in that folder (according to the time stamp).
  parses the result file for pass and fail.
  internally calls the subroutine 'tmsResultUpdate' to update the result in tms.

=over

=item Arguments

  Mandatory :
    -log_Directory => path of the Logs containing folder.

=item Returns

  @arrResult : array containing testcase id and the result (1 for pass and 0 for fail).
  0 : on failure

=item Example(s)

  $obj->parseResultFile(-log_Directory => 'D:\Selenium_Log') ;

=back

=cut

sub parseResultFile() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".parseResultFile");
    my $sub_name = "parseResultFile";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my (@arrResult, @arrDisplay) = ();
    my ( $a1, $tmsId, $tmsResult);
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    
    foreach ('-log_Directory') {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }

    my $drive = '';
    if ( $args{-log_Directory} =~  m/\s*(\w+):.*$/ ) {
        $drive = $1;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: changing the drive to the mentioned Directory \'$drive\' ");

    unless ($self->{conn}->cmd("$drive:")) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to change the directory to \'$drive\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    my $fileName= '';
 
    $logger->info(__PACKAGE__ . ".$sub_name: Changing to the mentioned Directory $args{-log_Directory}");	
    
    unless ($self->{conn}->cmd("cd $args{-log_Directory}")){
        $logger->error(__PACKAGE__ . ".$sub_name: unable to change directory to $args{-log_Directory}");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: taking the latest file created");

    my @output= ();
    unless (@output = $self->{conn}->cmd("dir /O:-D /b") ) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to get the log files Directory");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: changing directory to $output[0]");
    unless ($self->{conn}->cmd("cd $output[0]")) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to change directory to $output[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    my @fileName = (); 

    $logger->info(__PACKAGE__ . ".$sub_name: taking the latest file created");

    unless (@fileName = $self->{conn}->cmd("dir /b *res")) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to get the log file");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }   
    
    $logger->info(__PACKAGE__ . ".$sub_name: the file obtained is $fileName[0]");
    
    chomp $fileName[0]; 

    my @output1 = ();
 
    $logger->info(__PACKAGE__ . ".$sub_name: printing the file on the screen");
    unless (@output1 = $self->{conn}->cmd("TYPE $fileName[0]")) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to get the log file");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    my @arrResults = ();
    
    if (defined $args{-operation}) {
        foreach my $line(@output1) {
            #print "$line\n" ;
            $logger->debug(__PACKAGE__ . ".$sub_name: Line is :: \'$line\'");
            if ($line =~ m/pass/i) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Passed Test Case");
                if ($line =~  m/(\w+\s*\w+\s*)#(\w+)#.*$/) {
                    $tmsId = $2 ;
                    $tmsResult = 1 ;
                }
	        $logger->debug(__PACKAGE__ . ".$sub_name: Passed Test Case for the opertion : $tmsId");
                push (@arrResult, "$tmsId", "$tmsResult");
             
            }
            my $error = '' ; 
            if ($line =~ m/fail/i) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Failed Test Case");
                if ($line =~  m/(\w+\s*\w+\s*)#(\w+)#(\w+)#(\w+)#(.*$)/) {
                    $tmsId = $2 ;
	            $error = $5 ;	                     
                    $tmsResult = 0 ;
                }
	        $logger->debug(__PACKAGE__ . ".$sub_name: Failed Test Case for operation : $tmsId");
	        $logger->debug(__PACKAGE__ . ".error returned is : '$error' ") ;
                return $error ;
                    
                push (@arrResult, "$tmsId", "$tmsResult");
            
            }

            if ($line =~ m/finish/i) {
                last ;
            }
             else {
               next ;
            }
        }

    $logger->info(__PACKAGE__ . ".$sub_name: Result Obtained is @arrResult");

    } else { 
        my $error ;       
        foreach my $line(@output1){
            $logger->debug(__PACKAGE__ . ".$sub_name: Checking for the line '$line'");
            if ($line =~ m/pass/i) {
	        $logger->debug(__PACKAGE__ . ".$sub_name: Passed Test Case");
	        if ($line =~  m/(\w+\s*\w+\s*):(\w+).*$/) {
		    $tmsId = $2 ;		    
		    $tmsId =~ s/\D//g ;
                    $logger->debug(__PACKAGE__ . ".$sub_name:Passed Test Case Id : $tmsId");
		    $tmsResult = 1 ;	
	        }  
                push (@arrResult, "$tmsId", "$tmsResult");
	        push (@arrDisplay, "$tmsId\t\tPASS");			
	    }
	
	    if ($line =~ m/fail/i) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Failed Test case");
	        if ($line =~  m/(\w+\s*\w+\s*):(\w+).*$/) {
		    $tmsId = $2 ;		    
		    $tmsId =~ s/\D//g ;
                    $logger->debug(__PACKAGE__ . ".$sub_name:Failed Test Case Id : $tmsId");
		    $tmsResult = 0 ;	
	         } 
	        push (@arrResult, "$tmsId", "$tmsResult");
	        push (@arrDisplay, "$tmsId\t\tFAIL");	
	    }

            if ($line =~ m/finish/i) {
                $logger->debug(__PACKAGE__ . ".$sub_name: Coming out of the checking loop ");
	        last ;
	    }	      
              else {
	          next ;
    	    } 
        }  
    }

	   
    #$logger->info(__PACKAGE__ . ".$sub_name: Result Obtained is @arrResult");
   
    $logger->info(__PACKAGE__ . ".$sub_name: checking for the Value to be updated in TMS"); 
    
    if($ENV{ATS_LOG_RESULT}) {
        $logger->info(__PACKAGE__ . ".$sub_name: Flag is Defined For updating Result to TMS");
        
        for (my $count=0 ; $count<$#arrResult; $count++) {
            my $testcaseId = $arrResult[$count];
            my $testresult  = $arrResult[$count+1];
            $logger->info(__PACKAGE__ . ".$sub_name: Test Case ID : $testcaseId and Test Result : $testresult");
            $count++;

            $logger->info(__PACKAGE__ . ".$sub_name: Calling Subroutine tmsResultUpdate");
            

            $logger->info(__PACKAGE__ . ".$sub_name: -sons_result_release => '$args{-sons_result_release}', -sons_result_build => '$args{-sons_result_build}' , -testcaseId => '$testcaseId' ,  -testresult => '$testresult' ");
           $self->tmsResultUpdate(-sons_result_release => $args{-sons_result_release}, -sons_result_build => $args{-sons_result_build} , -sons_result_variant => $args{-sons_result_variant} , -testcaseId => $testcaseId ,  -testresult => $testresult) ;
        }
    } else {
          $logger->info(__PACKAGE__ . ".$sub_name:Flag is not defined for updating result :: Result is" . Dumper(\@arrResult)); 
    }
    return 1 ; 
}

=head2 SonusQA::SELENIUM::tmsResultUpdate()

  updates the value to TMS with the given fields.

=over

=item Arguments

  Mandatory :
    -sons_result_release -> release given by user
    -sons_result_build -> build specified
    -testcaseId -> id of the testcase
    -testresult -> result of the testcase

=item Returns

  1 : if the value is successfully updated.
  0 : on failure

=item Example(s)

  $obj->tmsResultUpdate(-sons_result_release => $args{-sons_result_release}, -sons_result_build => $args{-sons_result_build} , -testcaseId => $testcaseId ,  -testresult => $testresult) ;

=back

=cut

sub tmsResultUpdate {
    my ($self , %args) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".tmsResultUpdate");
    my ( $testcaseId , $testresult) = '' ;
    my $sub_name = "tmsResultUpdate";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
   
    $logger->info(__PACKAGE__ . ".$sub_name: -sons_result_release => $args{-sons_result_release}, -sons_result_build => $args{-sons_result_build} , -testcaseId => $args{-testcaseId} ,  -testresult => $args{-testresult}, -sons_result_variant => $args{-sons_result_variant} ");	

    if ( $ENV{ "ATS_LOG_RESULT" } ) {
        $logger->info(__PACKAGE__ . ".$sub_name: The Parameter for logging results is ON");
        $logger->info(" $args{-testcaseId}: Logging result in TMS: $testresult for testcase ID $testcaseId");
        unless ( SonusQA::Utils::log_result (
                                            -sons_result_test_result  => "$args{-testresult}",
                                            -sons_result_release      => "$args{-sons_result_release}",
                                            -testcase_id              => "$args{-testcaseId}",
                                            -sons_result_build        => "$args{-sons_result_build}",
                                            -sons_result_variant      => "$args{-sons_result_variant}",
                                       ) ) {
            $logger->error(" $testcaseId: ERROR: Logging of test result to TMS has FAILED");
        }
	$logger->info("Result Updated in TMS for $args{-testcaseId}");
    }
}

=head2 SonusQA::SELENIUM::runSelenium()
		 
  parser function for two functions.
  internally calls runSeleniumSuite() and parseResultFile().  (refer to their documentation for the better understanding of them.)

=over

=item Arguments

  Mandatory :
    -jarLoc  =>   Location of the jar file
    -jarName  => Name of the jar file 
    -propFile  => Name of the property file 
    -log_Directory => Directory for storage of log

  optional : 
    -sons_result_build => build version 
    -sons_result_variant => variant (Solaris or Linux)

=item Returns

  Nothing

=item Example(s)

  $obj->runSelenium(-jarLoc=>'D:\Sel' , -jarName=>'PER5713' , -propFile=>'PER_5713.properties', -log_Directory=>'D:\Selenium_Log') ;

=back

=cut

sub runSelenium {
    my ($self, %args) = @_ ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".runSelenium");    
    my $sub_name = "runSelenium";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-jarLoc', '-propFile', '-jarName', '-log_Directory') { 
       unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
  
    }
    
    if ( defined $args{-timeout}) {
        $self->{DEFAULTTIMEOUT} = $args{-timeout};
        $logger->info("SELENIUM EXECUTION DEFAULT TIMEOUT IS SET TO $self->{DEFAULTTIMEOUT} secs");
    }

    unless ($self->runSeleniumSuite( %args)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to invoke the command");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }

    my $res = '' ;
    $res = $self->parseResultFile(%args);
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Finished parsing Result file, Return value: $res");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub.");
    return $res;
}


=head2 SonusQA::SELENIUM::CollectLog()

  It checks whether the latest test executed with the given TestSet name passed or failed.
  It further captures the result data as well as necessary details from the log files

  Note: Any Performance related information, for instance should be recorded in the log file in the format "Result for"

=over

=item Arguments

  Mandatory :
    -log_Directory => Location of the log files
    -TestSet => Name of the test case 

=item Returns

  1 : on success
  0 : on failure

=item Example(s)

  $result = $Obj->CollectLog(-log_Directory=>'C:\Selenium_Log', -TestSet=>'PT_CreateTrapFwd'); 

=back

=cut

sub CollectLog() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".CollectLog");
    my $sub_name = "CollectLog";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $timestamp = strftime "%m-%d-%y-%H-%M", localtime;

    my $resultFile=$self->{result_path}."Selenium_"."$args{-TestSet}\_$timestamp";

    my $result=1;

    foreach ('-log_Directory', '-TestSet') {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }

    my $drive = '';
    if ( $args{-log_Directory} =~  m/\s*(\w+):.*$/ ) {
        $drive = $1;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: changing the drive to the mentioned Directory \'$drive\' ");

    unless ($self->{conn}->cmd("$drive:")) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to change the directory to \'$drive\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    my $fileName= '';

    $logger->info(__PACKAGE__ . ".$sub_name: Changing to the mentioned Directory $args{-log_Directory}");

    unless ($self->{conn}->cmd("cd $args{-log_Directory}")){
        $logger->error(__PACKAGE__ . ".$sub_name: unable to change directory to $args{-log_Directory}");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: taking the latest log files directory created");

    my @output= ();
    unless (@output = $self->{conn}->cmd("dir /O:-d /b $args{-TestSet}*") ) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to get the log files Directory");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: changing directory to $output[0]");
    unless ($self->{conn}->cmd("cd $output[0]")) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to change directory to $output[0]");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    
    my @fileName = ();

    $logger->info(__PACKAGE__ . ".$sub_name: taking the latest result file created");

    unless (@fileName = $self->{conn}->cmd("dir /b *res")) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to get the result file");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: the result file obtained is $fileName[0]");

    chomp $fileName[0];

    my @output1 = ();

    $logger->info(__PACKAGE__ . ".$sub_name: printing the result file on the screen");
    unless (@output1 = $self->{conn}->cmd("TYPE $fileName[0]")) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to get the result file");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

     
    unless(grep /Passed/is, @output1) {
        $logger->info(__PACKAGE__ . ".$sub_name: TEST FAILED with errors");
        $result=0;}
    else
    {
        $logger->info(__PACKAGE__ . ".$sub_name: TEST PASSED");
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Writing the Selenium Result to the file $resultFile.txt");

    my $f;
    unless ( open LOGFILE, $f = ">$resultFile.txt" ) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to open file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    print LOGFILE join("\n", @output1);
    unless ( close LOGFILE ) {
    $logger->error(__PACKAGE__ . ".$sub_name: Cannot close output file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Selenium Results successfully written to the file $resultFile.txt");
 
    $logger->info(__PACKAGE__ . ".$sub_name: taking the latest log file created");

    unless (@output1 = $self->{conn}->cmd('find "Result for" *.log')) {
        $logger->error(__PACKAGE__ . ".$sub_name: No necessary logged informationi found");
    }
 
    $logger->info(__PACKAGE__ . ".$sub_name: Writing the Selenium logs to the file $resultFile.txt");

    
    unless ( open LOGFILE, $f = ">>$resultFile.txt" ) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to open file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    print LOGFILE join("\n", @output1);
    unless ( close LOGFILE ) {
    $logger->error(__PACKAGE__ . ".$sub_name: Cannot close output file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Selenium logs successfully written to the file $resultFile.txt");

    return $result;

}


=head2 SonusQA::SELENIUM::CreateTrapFwd()

  It calls the createPropFile() for Creating property file or modifying existing file for Trap Forwarding Profile test case.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs 

=over

=item Arguments

  Mandatory :
    -emsObj => EMS_SUT Object Name
    -fwdObj => EMS_FWD Object Name 
    -tcase => Name of the test case
    -FWD_IP => IP of the Forwarded EMS

=item Returns

  1 : on success
  0 : on failure

=item Example(s)

  $result = $Obj->CreateTrapFwd(-emsObj=>$EMS_SUT_Obj,  -tcase=>'EMS_FM_PERF_36', -fwdObj=>$FWD_EMS_Obj);

=back

=cut

sub CreateTrapFwd() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".CreateTrapFwd");
    my $sub_name = "CreateTrapFwd";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-emsObj','-tcase', '-fwdObj'  ) {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }

   $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
   $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});

    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $FWD_IP=$args{-fwdObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};
   

   #Creating or Modifying an existing property file  

    unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd, TestSetName=>$args{-tcase}, PT_CreateTrapFwd_TrapDestinationName=>$FWD_IP , PT_CreateTrapFwd_TrapDestinationIP=>$FWD_IP , PT_CreateTrapFwd_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'CreateTrapFwd.properties')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => 'CreateTrapFwd.properties' , -jarName =>'PT_Testing')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ( $self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$args{-tcase})) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}


=head2 SonusQA::SELENIUM::ModifyProfile()

  It calls the createPropFile() for Creating of Modifying an existing property file for Modify Profile test case.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs

=over

=item Arguments

  Mandatory :
    -emsObj => EMS_SUT Object Name
    -tcase => Name of the test case
    -coll => Collection frequency in mins
    -export => export frequency in mins
    -dev => device whose sample profile which needs to be modified, should be exactly same as it appears in the EMS UI sample profile name 

  Optional:
    -stats => ATT or TG 
      default value is TG 

=item Returns

  1 : on success
  0 : on failure

=item Example(s)

  $result = $Obj->ModifyProfile(-emsObj=>$EMS_SUT_Obj,  -tcase=>'EMS_PM_PERF_19', -coll=> '5', -export=>'5', -stats=>'ATT', -dev=>'GSX');

=back

=cut

sub ModifyProfile() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".ModifyProfile");
    my $sub_name = "ModifyProfile";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-emsObj','-tcase', '-coll', '-export','-dev'  ) {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }
   
    $args{-stats} ||= "TG";

    $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});

 
    #Used in pm_total_loss , pm_device_loss for identfifying the device
    if($args{-dev} eq "SBC 5x00") {
       $args{-emsObj}->{dev}="SBX5K";
    } else {
       $args{-emsObj}->{dev} = uc "$args{-dev}"; 
    }
    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};

    my $test_time = `date +"%s"`;
    $test_time = $test_time - ($test_time % ($args{-export}*60)) + ($args{-export}*60*3);

    my $M=`date -d '1970-01-01 $test_time sec + 19800sec' +"%r" | cut -f2 -d ' '`;
    chomp($M);

    my $hour1=`date -d '1970-01-01 $test_time sec + 19800sec' +"%l"`;
    chomp($hour1);

    my $min1=`date -d '1970-01-01 $test_time sec + 19800sec' +"%M"`;
    chomp($min1);


    my $exportPath = "$args{-emsObj}->{TMS_ALIAS_DATA}->{NODE}->{1}->{BASEPATH}"."$main::TESTSUITE->{PM_DIR}"."/"."$args{-tcase}";

   #Creating or Modifying an existing property file

    unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd, TestSetName=>$args{-tcase}, HTTPS_Enabled=>'yes', PT_ModifyProfileATT_TestCaseEnabled => 'enabled' , PT_ModifyProfileATT_coll => $args{-coll} , PT_ModifyProfileATT_export =>$args{-export}, PT_ModifyProfileATT_dev => $args{-dev},PT_ModifyProfileATT_export_path=>$exportPath,PT_ModifyProfileATT_stats=>$args{-stats},PT_ModifyProfileATT_hour=>$hour1,PT_ModifyProfileATT_min=>$min1,PT_ModifyProfileATT_m=>$M}, jarLoc => $jarLoc , propFile  => 'ModifyProfile.properties')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => 'ModifyProfile.properties' , -jarName =>'PT_Testing')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ( $self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$args{-tcase})) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}


=head2 SonusQA::SELENIUM::GUI_Login()

  It calls the createPropFile() for Creating property file or modifying existing file for GUI Login test case.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs

=over

=item Arguments

  Mandatory :
    -emsObj => EMS_SUT Object Name
    -tcase => Name of the test case
    -dev   => registered real GSX device name

  Optional  :
    -CacheClear => y or n
      Default value is  n
    -HTTPS      => y or n
      Default value is n

=item Returns

  1 : on success
  0 : on failure

=item Example(s)

  $result = $Obj->GUI_Login(-emsObj=>$EMS_SUT_Obj,  -tcase=>'EMS_GUI_PERF_100', -dev => "Auto_GSX" , -CacheClear => "y", HTTPS => "y");

=back

=cut

sub GUI_Login() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".GUI_Login");
    my $sub_name = "GUI_Login";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-emsObj','-tcase', '-dev' ) {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }

   $args{-CacheClear} ||= "n";
   $args{-HTTPS}      ||= "n";
   $args{-BrowserType}      ||= "IE";
   
   $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
   $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});


#Clearing the cache if required
   if ( $args{-CacheClear} eq "y" || $args{-CacheClear} eq "Y" )
   {
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1");
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2");
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8");
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16");
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 32");
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255");
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 4351");
   }

    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};
    

   #Creating or Modifying an existing property file
    if ( $args{-HTTPS} eq "y" || $args{-HTTPS} eq "Y" )
    {
        unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd, HTTPS_Enabled=>'yes', CheckCertificateError=>'yes', TestSetName=>$args{-tcase},PT_GsxDiscovery_NodeName=>$args{-dev}, PT_GsxNavigator_NodeName=>$args{-dev} ,PT_EmsLogin_TestCaseEnabled=>'enabled', PT_GsxNavigator_TestCaseEnabled=>'enabled', PT_GsxDiscovery_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'GsxNavigator.properties')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;}
    }

    else {
        unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd, HTTPS_Enabled=>'no', CheckCertificateError=>'no',TestSetName=>$args{-tcase},PT_GsxDiscovery_NodeName=>$args{-dev}, PT_GsxNavigator_NodeName=>$args{-dev} ,PT_EmsLogin_TestCaseEnabled=>'enabled', PT_GsxNavigator_TestCaseEnabled=>'enabled', PT_GsxDiscovery_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'GsxNavigator.properties')) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;}
    }

    if ( $args{-BrowserType} eq "firefox" || $args{-BrowserType} eq "Firefox" )
    {
        unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd, BrowserType=>'Firefox', TestSetName=>$args{-tcase},PT_GsxDiscovery_NodeName=>$args{-dev}, PT_GsxNavigator_NodeName=>$args{-dev} ,PT_EmsLogin_TestCaseEnabled=>'enabled', PT_GsxNavigator_TestCaseEnabled=>'enabled', PT_GsxDiscovery_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'GsxNavigator.properties')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;}
    }

    else {
        unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd, BrowserType=>'InternetExplorer', TestSetName=>$args{-tcase},PT_GsxDiscovery_NodeName=>$args{-dev}, PT_GsxNavigator_NodeName=>$args{-dev} ,PT_EmsLogin_TestCaseEnabled=>'enabled', PT_GsxNavigator_TestCaseEnabled=>'enabled', PT_GsxDiscovery_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'GsxNavigator.properties')) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;}
    }

   #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => 'GsxNavigator.properties' , -jarName =>'PT_Testing')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ( $self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$args{-tcase})) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}

=head2 SonusQA::SELENIUM::SBCGUI_Login()

  It calls the createPropFile() for Creating property file or modifying existing file for GUI Login test case.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs

=over

=item Arguments

  Mandatory :
    -emsObj => EMS_SUT Object Name
    -tcase => Name of the test case
    -dev   => registered real GSX device name

  Optional  :
    -CacheClear => y or n
      Default value is  n
    -HTTPS      => y or n
      Default value is n

=item Returns

  1 : on success
  0 : on failure

=item Example(s)

  $result = $Obj->SBCGUI_Login(-emsObj=>$EMS_SUT_Obj,  -tcase=>'EMS_GUI_PERF_100', -dev => "Auto_GSX" , -CacheClear => "y", HTTPS => "y");

=back

=cut

sub SBCGUI_Login() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".GUI_Login");
    my $sub_name = "SBCGUI_Login";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-emsObj','-tcase', '-dev' ) {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }

   $args{-CacheClear} ||= "n";
   $args{-HTTPS}      ||= "n";

   $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
   $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});


#Clearing the cache if required
   if ( $args{-CacheClear} eq "y" || $args{-CacheClear} eq "Y" )
   {
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1");
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2");
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8");
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16");
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 32");
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255");
     $self->{conn}->cmd("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 4351");
   }

    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};


   #Creating or Modifying an existing property file
    if ( $args{-HTTPS} eq "y" || $args{-HTTPS} eq "Y" )
    {
        unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd, HTTPS_Enabled=>'yes', CheckCertificateError=>'yes', TestSetName=>$args{-tcase},PT_SbcDiscovery_NodeName=>$args{-dev}, PT_SbcManager_NodeName=>$args{-dev} ,PT_EmsLogin_TestCaseEnabled=>'enabled', PT_SbcManager_TestCaseEnabled=>'enabled', PT_SbcDiscovery_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'SbcManager.properties')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;}
    }

    else {
        unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd, HTTPS_Enabled=>'no', CheckCertificateError=>'no',TestSetName=>$args{-tcase},PT_SbcDiscovery_NodeName=>$args{-dev}, PT_SbcManager_NodeName=>$args{-dev} ,PT_EmsLogin_TestCaseEnabled=>'enabled', PT_SbcManager_TestCaseEnabled=>'enabled', PT_SbcDiscovery_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'SbcManager.properties')) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;}
    }

   #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => 'SbcManager.properties' , -jarName =>'PT_Testing')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ( $self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$args{-tcase})) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}


=head2 SonusQA::SELENIUM::EnableCollection()

  It calls the createPropFile() for Creating property file or modifying existing file for EnableCollection test case.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs

=over

=item Arguments

  Mandatory :
    -emsObj => EMS_SUT Object Name
    -tcase => Name of the test case
    -dev => name of the first device in the device list according to the GUI, for which collection has to be enabled
    -count => number of devices inclusive of the first device, for which collection has to be enabled

=item Returns

  1 : on success
  0 : on failure

=item Example(s)

  $result = $Obj->EnableCollection(-emsObj=>$EMS_SUT_Obj,  -tcase=>'EMS_FM_PERF_36', -dev=>'GEMINI_12_002', -count=>'200');

=back

=cut

sub EnableCollection() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".EnableCollection");
    my $sub_name = "EnableCollection";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-emsObj','-tcase', '-dev', '-count'  ) {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }

   $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
   $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});

    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};

   #Logging into EMS as oracle user to check successful enabling of collection for the specified number of nodes
    my $prePrompt = $args{-emsObj}->{conn}->prompt;

    #switching  to oracle user

    my $sql_userid = $self->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{USERID};
    my $sql_passwd = $self->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{PASSWD};
    my @cmd_res = ();
    my $enable_count=0;

    unless ( $args{-emsObj}->becomeUser(-userName => 'oracle',-password =>'oracle') ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as oracle into the EMS_SUT");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Entering SQL");
    $args{-emsObj}->{conn}->prompt('/SQL\> $/');

    unless ($args{-emsObj}->{conn}->cmd(String => "sqlplus $sql_userid\/$sql_passwd",  Timeout => '60') ) {
        $logger->error(__PACKAGE__ . ".$sub_name: UNABLE TO ENTER SQL in EMS_SUT");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $args{-emsObj}->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $args{-emsObj}->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $args{-emsObj}->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    @cmd_res = $args{-emsObj}->execCmd("select count(*) from  dbimpl.node where perfdatacollecting=1 ;",3600);
    if ($cmd_res[2] == $enable_count){
        $logger->info(__PACKAGE__ . ".$sub_name: Collection not enabled for any nodes"); 
        $logger->debug(__PACKAGE__ . ".$sub_name:   " . Dumper(\@cmd_res));
    }
    else {
    $logger->info(__PACKAGE__ . ".$sub_name: collection already enabled for $cmd_res[2] nodes");
    $logger->debug(__PACKAGE__ . ".$sub_name:   " . Dumper(\@cmd_res));
    }
    
    $enable_count = $cmd_res[2];


   #Creating or Modifying an existing property file

    unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd, TestSetName=>$args{-tcase}, PT_EnableCollection_dev=>$args{-dev} , PT_EnableCollection_count=>$args{-count} , PT_EnableCollection_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'EnableCollection.properties')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => 'EnableCollection.properties' , -jarName =>'PT_Testing')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ( $self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$args{-tcase})) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Logging into EMS as oracle user to check successful enabling of collection for the specified number of nodes


    unless ( $args{-emsObj}->becomeUser(-userName => 'oracle',-password =>'oracle') ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as oracle into the EMS_SUT");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Entering SQL");
    $args{-emsObj}->{conn}->prompt('/SQL\> $/');

    unless ($args{-emsObj}->{conn}->cmd(String => "sqlplus $sql_userid\/$sql_passwd",  Timeout => '60') ) {
        $logger->error(__PACKAGE__ . ".$sub_name: UNABLE TO ENTER SQL in EMS_SUT");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $args{-emsObj}->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $args{-emsObj}->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $args{-emsObj}->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $enable_count += $args{-count};
    @cmd_res = $args{-emsObj}->execCmd("select count(*) from  dbimpl.node where perfdatacollecting=1 ;",3600);

    $args{-emsObj}->{conn}->cmd(string => "exit;", Prompt => $args{-emsObj}->{USERPROMPT});

    # Exiting from oracle login
    unless ($args{-emsObj}->{conn}->cmd(string => 'exit', Prompt  => $prePrompt)) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to exit oracle user");
       $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $args{-emsObj}->{conn}->errmsg);
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $args{-emsObj}->{sessionLog1}");
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $args{-emsObj}->{sessionLog2}");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
       return 0;
    }
    $args{-emsObj}->{conn}->prompt($prePrompt);


    if ($cmd_res[2] == $enable_count) {
        $logger->info(__PACKAGE__ . ".$sub_name: Collection enabled successfully");
        $logger->debug(__PACKAGE__ . ".$sub_name:   " . Dumper(\@cmd_res));
    }
    else {
    $logger->error(__PACKAGE__ . ".$sub_name: collection not enabled successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name:   " . Dumper(\@cmd_res));
    return 0;   
    }
   


    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}

=head2 SonusQA::SELENIUM::AutoRefresh()

  It calls the createPropFile() for Creating property file or modifying existing file for Auto Refresh test case.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs

=over

=item Arguments

  Mandatory :
    -emsObj => EMS_SUT Object Name
    -view => ViewName and BarName (should be same)
    -tcase => Name of the test case
    -count => number of iterations for which refresh has to be monitored

=item Returns

  1 : on success
  0 : on failure

=item Example(s)

  $result = $Obj->AutoRefresh(-emsObj=>$EMS_SUT_Obj,  -tcase=>'EMS_FM_PERF_36', -count=>"20", -view=>"GEMINI_12_002");

=back

=cut


sub AutoRefresh() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".AutoRefresh");
    my $sub_name = "AutoRefresh";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-emsObj','-tcase', '-view','-count'  ) {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }

   $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
   $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});

    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};


   #Creating or Modifying an existing property file

    unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd, EMS_DB_serverName=>$EMS_IP, TestSetName=>$args{-tcase}, PT_AutoRefresh_BarName=>$args{-view} , PT_AutoRefresh_ViewName=>$args{-view} ,PT_AutoRefresh_count=>$args{-count}, PT_AutoRefresh_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'AutoRefresh.properties')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => 'AutoRefresh.properties' , -jarName =>'PT_Testing')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ( $self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$args{-tcase})) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}

=head2 SonusQA::SELENIUM::ManualRefresh()

  It calls the createPropFile() for Creating property file or modifying existing file for Manual Refresh test case.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs

  Note: Frequency of manual Refresh click is 10s

=over

=item Arguments

  Mandatory :
    -emsObj => EMS_SUT Object Name
    -view => ViewName and BarName 
    -tcase => Name of the test case
    -count => number of iterations for which refresh has to be monitored

=item Returns

  1 : on success
  0 : on failure

=item Example(s)

  $result = $Obj->ManualRefresh(-emsObj=>$EMS_SUT_Obj,  -tcase=>'EMS_FM_PERF_36', -count=>"20", -view=>"GEMINI_12_002");

=back

=cut

sub ManualRefresh() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".ManualRefresh");
    my $sub_name = "ManualRefresh";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-emsObj','-tcase', '-view','-count'  ) {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }


   $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
   $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});

    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};


   #Creating or Modifying an existing property file

    unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd,  EMS_DB_serverName=>$EMS_IP, TestSetName=>$args{-tcase}, PT_ManualRefresh_BarName=>$args{-view} , PT_ManualRefresh_ViewName=>$args{-view} , PT_ManualRefresh_count=>$args{-count}, PT_ManualRefresh_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'ManualRefresh.properties')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => 'ManualRefresh.properties' , -jarName =>'PT_Testing')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ( $self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$args{-tcase})) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}

=head2 SonusQA::SELENIUM::Pagination()

  It calls the createPropFile() for Creating property file or modifying existing file for Pagination test case.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs

=over

=item Arguments

  Mandatory :
    -emsObj => EMS_SUT Object Name
    -view => ViewName and BarName
    -tcase => Name of the test case

=item Returns

  1 : on success
  0 : on failure

=item Example(s)

  $result = $Obj->Pagination(emsObj=>$EMS_SUT_Obj,  -tcase=>'EMS_FM_PERF_36',  -view=>"GEMINI_12_002");

=back

=cut

sub Pagination() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".Pagination");
    my $sub_name = "Pagination";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-emsObj','-tcase', '-view'  ) {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }


   $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
   $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});

    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};


   #Creating or Modifying an existing property file

    unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd,  EMS_DB_serverName=>$EMS_IP, TestSetName=>$args{-tcase}, PT_Pagination_BarName=>$args{-view} , PT_Pagination_ViewName=>$args{-view} , PT_Pagination_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'Pagination.properties')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => 'Pagination.properties' , -jarName =>'PT_Testing')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ( $self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$args{-tcase})) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}

=head2 SonusQA::SELENIUM::FMTesting()

  It calls the createPropFile() for Creating property file or modifying existing file for FM GUI Response test case.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs

=over

=item Arguments

  Mandatory :
    -emsObj => EMS_SUT Object Name
    -view => ViewName and BarName
    -tcase => Name of the test case

=item Returns

  1 : on success
  0 : on failure

=item Example(s)

  $result = $Obj->FMTesting(emsObj=>$EMS_SUT_Obj,  -tcase=>'EMS_FM_PERF_36',  -view=>"GEMINI_12_002");

=back

=cut

sub FMTesting() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".FMTesting");
    my $sub_name = "FMTesting";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-emsObj','-tcase', '-view'  ) {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }


   $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
   $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});

    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};


   #Creating or Modifying an existing property file

    unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd,  EMS_DB_serverName=>$EMS_IP, TestSetName=>$args{-tcase}, PT_FMTesting_BarName=>$args{-view} , PT_FMTesting_ViewName=>$args{-view} , PT_FMTesting_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'FMTesting.properties')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => 'FMTesting.properties' , -jarName =>'PT_Testing')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ( $self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$args{-tcase})) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}

=head2 SonusQA::SELENIUM::DisableCollection()

  It calls the createPropFile() for Creating property file or modifying existing file for DisableCollection test case.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs

=over

=item Arguments

  Mandatory :
    -emsObj => EMS_SUT Object Name
    -tcase => Name of the test case
    -dev => name of the first device in the device list according to the GUI, for which collection has to be disabled
    -count => number of devices inclusive of the first device, for which collection has to be disabled

=item Returns

  1 : on success
  0 : on failure

=item Example(s)

  $result = $Obj->DisableCollection(-emsObj=>$EMS_SUT_Obj,  -tcase=>'EMS_FM_PERF_36', -dev=>'GEMINI_12_002', -count=>'200');

=back

=cut

sub DisableCollection() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".DisableCollection");
    my $sub_name = "DisableCollection";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    foreach ('-emsObj','-tcase', '-dev', '-count'  ) {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }

   $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
   $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});

    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};
   
    #Logging into EMS as oracle user to check successful enabling of collection for the specified number of nodes
    my $prePrompt = $args{-emsObj}->{conn}->prompt;

    #switching  to oracle user

    my $sql_userid = $self->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{USERID};
    my $sql_passwd = $self->{TMS_ALIAS_DATA}->{ORACLE}->{1}->{PASSWD};
    my @cmd_res = ();
    my $enable_count=0;

    unless ( $args{-emsObj}->becomeUser(-userName => 'oracle',-password =>'oracle') ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as oracle into the EMS_SUT");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Entering SQL");
    $args{-emsObj}->{conn}->prompt('/SQL\> $/');

    unless ($args{-emsObj}->{conn}->cmd(String => "sqlplus $sql_userid\/$sql_passwd",  Timeout => '60') ) {
        $logger->error(__PACKAGE__ . ".$sub_name: UNABLE TO ENTER SQL in EMS_SUT");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $args{-emsObj}->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $args{-emsObj}->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $args{-emsObj}->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    @cmd_res = $args{-emsObj}->execCmd("select count(*) from  dbimpl.node where perfdatacollecting=1 ;",3600);
    if ($cmd_res[2] == $enable_count){
        $logger->info(__PACKAGE__ . ".$sub_name: Collection not enabled for any nodes");
        $logger->debug(__PACKAGE__ . ".$sub_name:   " . Dumper(\@cmd_res));
    }
    else {
    $logger->info(__PACKAGE__ . ".$sub_name: collection enabled for $cmd_res[2] nodes");
    $logger->debug(__PACKAGE__ . ".$sub_name:   " . Dumper(\@cmd_res));
    }

    $enable_count = $cmd_res[2];


   #Creating or Modifying an existing property file

    unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd, TestSetName=>$args{-tcase}, PT_DisableCollection_dev=>$args{-dev} , PT_DisableCollection_count=>$args{-count} , PT_DisableCollection_TestCaseEnabled=>'enabled'} , jarLoc => $jarLoc , propFile  => 'DisableCollection.properties')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => 'DisableCollection.properties' , -jarName =>'PT_Testing')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ( $self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$args{-tcase})) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Logging into EMS as oracle user to check successful enabling of collection for the specified number of nodes


    unless ( $args{-emsObj}->becomeUser(-userName => 'oracle',-password =>'oracle') ) {
        $logger->error(__PACKAGE__ . ".$sub_name:  failed to login as oracle into the EMS_SUT");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Entering SQL");
    $args{-emsObj}->{conn}->prompt('/SQL\> $/');

    unless ($args{-emsObj}->{conn}->cmd(String => "sqlplus $sql_userid\/$sql_passwd",  Timeout => '60') ) {
        $logger->error(__PACKAGE__ . ".$sub_name: UNABLE TO ENTER SQL in EMS_SUT");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $args{-emsObj}->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $args{-emsObj}->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $args{-emsObj}->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    $enable_count -= $args{-count};
    @cmd_res = $args{-emsObj}->execCmd("select count(*) from  dbimpl.node where perfdatacollecting=1 ;",3600);
    $args{-emsObj}->{conn}->cmd(string => "exit;", Prompt => $args{-emsObj}->{USERPROMPT});

    # Exiting from oracle login
    unless ($args{-emsObj}->{conn}->cmd(string => 'exit', Prompt  => $prePrompt)) {
       $logger->error(__PACKAGE__ . ".$sub_name: failed to exit oracle user");
       $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $args{-emsObj}->{conn}->errmsg);
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $args{-emsObj}->{sessionLog1}");
       $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $args{-emsObj}->{sessionLog2}");
       $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
       return 0;
    }
    $args{-emsObj}->{conn}->prompt($prePrompt);

    if ($cmd_res[2] == $enable_count) {
        $logger->info(__PACKAGE__ . ".$sub_name: Collection disabled successfully");
        $logger->debug(__PACKAGE__ . ".$sub_name:   " . Dumper(\@cmd_res));
    }
    else {
    $logger->error(__PACKAGE__ . ".$sub_name: collection not disabled successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name:   " . Dumper(\@cmd_res));
    return 0;
    }


    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}

=head2 SonusQA::SELENIUM::InventoryReports()

  It calls the createPropFile() for Creating property file or modifying existing file for DisableCollection test case.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs

=over

=item Arguments

  Mandatory :
    -emsObj => EMS_SUT Object Name

=item Returns

  1 : on success
  0 : on failure

=back

=cut

sub InventoryReports() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".INS21571InventoryManagementSuite1");
    my $sub_name = "INS21571InventoryManagementSuite1";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");



    $args{-stats} ||= "TG";

    $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});


    #Used in pm_total_loss , pm_device_loss for identfifying the device

    my $EMS_IP=$args{-emsObj}->{TMS_ALIAS_DATA}->{WELLKNOWN}->{1}->{IP};
    my $user=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{USERID};
    my $pwd=$args{-emsObj}->{TMS_ALIAS_DATA}->{GUI}->{1}->{PASSWD};
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};





   #Creating or Modifying an existing property file

    unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,  Admin_User_Name=>$user, Admin_Password =>$pwd, TestSetName=>$args{-tcase}, PT_Inventory_TestCaseEnabled => 'enabled'}, jarLoc => $jarLoc, propFile  => 'Inventory.properties')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => 'Inventory.properties' , -jarName =>'PT_Testing')) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

   #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ( $self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$args{-tcase})) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}



sub AUTOLOAD {
    our $AUTOLOAD;
    my $warn = "$AUTOLOAD  ATTEMPT TO CALL $AUTOLOAD FAILED (POSSIBLY INVALID METHOD)";
    if(Log::Log4perl::initialized()){
        my $logger = Log::Log4perl->get_logger($AUTOLOAD);
        $logger->warn($warn);
    } else {
          Log::Log4perl->easy_init($DEBUG);
          WARN($warn);
    }

}	

=head2 SonusQA::SELENIUM::Jenkins()

  It calls the createPropFile() for Creating property file or modifying existing file for editing EMS IP.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs

=over

=item Returns

  1 : on success
  0 : on failure

=back

=cut



sub Jenkins() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".Jenkins");
    my $sub_name = "Jenkins";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    unless (defined $args{'-tcase'}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
    }

    $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});


    my $EMS_IP= $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP_ADDRESS};
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};
    my $jar_name = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{KEY_FILE};
    my $prop_name = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{ENV_FILE};
    my $sbcEdge_name = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{NAME};
    my $sbcEdge_userName = $self->{TMS_ALIAS_DATA}->{NODE}->{3}->{USERID};
    my $sbcEdge_password = $self->{TMS_ALIAS_DATA}->{NODE}->{3}->{PASSWD};
    my $sbcEdge_RestUsername = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{USERID};
    my $sbcEdge_RestPassword = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{PASSWD}; 
    my $emsRegistrationName = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{HOSTNAME};
    my $imageName = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{IMAGE};
    my $imagePath = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{PROFILE_PATH};
    my $type = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{TYPE};
    my $nodeType = $self->{TMS_ALIAS_DATA}->{NODE}->{3}->{TYPE};
    my $Sbc_edge_Ip = $self->{TMS_ALIAS_DATA}->{NODE}->{2}->{IP};

    my $testcase = "test_" . $args{'-tcase'} . "_TestCaseEnabled"; 
    #Creating or Modifying an existing property file
    unless ( $self->createPropFile(content => {EMS_IP=>$EMS_IP,Sbc_edge_Name=>$sbcEdge_name,Sbc_edge_Ip=>$Sbc_edge_Ip,Sbc_edge_RestUserName=>$sbcEdge_RestUsername,Sbc_edge_RestPassword=>$sbcEdge_RestPassword,Sbc_edge_Type=>$type,Sbc_edge_UserName=>$sbcEdge_userName,Sbc_edge_Password=>$sbcEdge_password,Sbc_edge_ImageName=>$imageName,Sbc_edge_fileAbsolutePath=>$imagePath,NodeType=>$nodeType,EMSRegistrationName=>$emsRegistrationName,$testcase => 'enabled',}, propFile  => $prop_name, jarLoc => $jarLoc)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => $prop_name , -jarName => $jar_name)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }


    #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ($self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$sub_name)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}





=head2 SonusQA::SELENIUM::JenkinsSBCCloud()

  It calls the createPropFile() for Creating property file or modifying existing file for editing EMS IP.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs
=item Returns

  1 : on success
  0 : on failure

=back

=cut





sub JenkinsSBCCloud() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".Jenkins");
    my $sub_name = "JenkinsCloudSBC";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");


     foreach ('-dnsObject', '-tcase', '-stackDetails','-emsObject', '-openStackObject'  ) {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }



    $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});

    $logger->error( "\n DNS Object $args{-dnsObject}\n");


    my $openstackObj = $args{-openStackObject};

     $logger->debug('Openstack details : '. Dumper($openstackObj));




    #Selenium Details
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};
    my $jar_name = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{KEY_FILE};
    my $prop_name = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{ENV_FILE};
    my @array1=split("\\.",$prop_name);
    
    my $bkpProp_name = $array1[0].'_bkp.properties'; 
    
    $logger->debug('bkp properties file name:'. $bkpProp_name); 
   
    my $seleniumLogDir = $log_dir;
   $seleniumLogDir =~ s|\\|/|g;

    #DNS Server Details
    my $DnsIP=$args{-dnsObject}->{NODE}->{1}->{IP};




    my $DNSServerZoneFileName=$args{-dnsObject}->{NODE}->{1}->{KEY_FILE};

    $logger->debug('Openstack details : '. $DNSServerZoneFileName);


    my $DNSServerZoneFilePath=$args{-dnsObject}->{NODE}->{1}->{BASEPATH};
    my $DnsPassword=$args{-dnsObject}->{LOGIN}->{1}->{PASSWD};
    my $DNSUserName=$args{-dnsObject}->{LOGIN}->{1}->{USERID};
    my $DnsServerZoneName=$args{-dnsObject}->{NODE}->{1}->{ZONE};


    #StackDetails 
    my $NTPIp=$args{-stackDetails}->{NTP}->{1}->{IP};
    my $ConfiguratorHeatTemplate=$args{-stackDetails}->{NODE}->{1}->{TEMPLATE_FILE};
    my $ssbc11SRIOVHeatTemplate=$args{-stackDetails}->{NODE}->{2}->{TEMPLATE_FILE};
    my $msbc21SRIOVHeatTemplate=$args{-stackDetails}->{NODE}->{3}->{TEMPLATE_FILE};
    my $timeZone=$args{-stackDetails}->{NODE}->{1}->{TIMEZONE};
    my $sbcNodeVersion=$args{-stackDetails}->{S_SBC}->{1}->{VERSION};
     my $ssbc11HeatTemplate=$args{-stackDetails}->{NODE}->{5}->{TEMPLATE_FILE};
     my $msbc21HeatTemplate=$args{-stackDetails}->{NODE}->{6}->{TEMPLATE_FILE};
    my $SbcSriovEnabled=$args{-stackDetails}->{CONFIG}->{1}->{TYPE};

   $logger->debug('EMS details : '. Dumper($args{-emsObject}));


   my $EMSNodeName=$args{-emsObject}->{NODE}->{1}->{HOSTNAME};
   my $EMSIP=$args{-emsObject}->{NODE}->{1}->{IP};
   my $EMSGUIPassword=$args{-emsObject}->{NODE}->{1}->{PASSWD};
   my $EMSCliPassword=$args{-emsObject}->{NODE}->{2}->{PASSWD};
   my $EMSRestPassword=$args{-emsObject}->{NODE}->{3}->{PASSWD};
   my $EMSGuiLogin=$args{-emsObject}->{NODE}->{1}->{USERID};
   my $EMSCliLogin=$args{-emsObject}->{NODE}->{2}->{USERID};
   my $EMSRestLogin=$args{-emsObject}->{NODE}->{3}->{USERID};

   
   $logger->debug('EMS Node Name : '. $EMSNodeName);


    #openStack details
   my $pkt0Gateway=$args{-openStackObject}->{VM_CTRL}->{1}->{DEFAULT_GATEWAY};
   my $openstackDomainName=$args{-openStackObject}->{VM_CTRL}->{1}->{DOMAIN};
   my $pkt0sriovExtNetwork=$args{-openStackObject}->{VM_CTRL}->{1}->{E1ISDNPort1};
   my $externalSRIOVPkt0Subnet=$args{-openStackObject}->{VM_CTRL}->{2}->{E1ISDNPort1};
   my $pkt1_sriovext_network=$args{-openStackObject}->{VM_CTRL}->{1}->{E1ISDNPort2};
   my $externalSRIOVPkt1Subnet=$args{-openStackObject}->{VM_CTRL}->{2}->{E1ISDNPort2};
   my $InternalMgmt=$args{-openStackObject}->{VM_CTRL}->{1}->{E1Port1};
   my $InternalMgmtSubnet=$args{-openStackObject}->{VM_CTRL}->{2}->{E1Port1};
   my $ExternalMgmt=$args{-openStackObject}->{VM_CTRL}->{3}->{E1Port1};
   my $externalMgmtSubnet=$args{-openStackObject}->{VM_CTRL}->{4}->{E1Port1};
   my $InternalHA=$args{-openStackObject}->{VM_CTRL}->{1}->{E1Port2};
   my $InternalHASubnet=$args{-openStackObject}->{VM_CTRL}->{2}->{E1Port2};
   my $pkt0ExtNetwork =$args{-openStackObject}->{VM_CTRL}->{3}->{E1Port2};
   my $externalPkt0Subnet =$args{-openStackObject}->{VM_CTRL}->{4}->{E1Port2};
   my $InternalPkt0=$args{-openStackObject}->{VM_CTRL}->{1}->{E1Port3};
   my $InternalPkt0Subnet=$args{-openStackObject}->{VM_CTRL}->{2}->{E1Port3};
   my $externalPkt1Subnet=$args{-openStackObject}->{VM_CTRL}->{4}->{E1Port3};
   my $internalPkt1=$args{-openStackObject}->{VM_CTRL}->{1}->{E1Port4};
   my $internalPkt1Subnet=$args{-openStackObject}->{VM_CTRL}->{2}->{E1Port4};
   my $sbcflavor=$args{-openStackObject}->{VM_CTRL}->{1}->{FLAVOR};
   my $sbcImageName=$args{-openStackObject}->{VM_CTRL}->{1}->{IMAGE};
   my $openstackIpAddress=$args{-openStackObject}->{VM_CTRL}->{1}->{IP};
   my $openstackTenantName=$args{-openStackObject}->{VM_CTRL}->{1}->{NAME};
   my $openstackPassword=$args{-openStackObject}->{VM_CTRL}->{1}->{PASSWD};
   my $openstackAccessPort=$args{-openStackObject}->{VM_CTRL}->{1}->{PORT};
   my $openstackSecurityGroupName=$args{-openStackObject}->{VM_CTRL}->{1}->{SECURITY_GROUPS};
   my $openstackAdminPrivelage=$args{-openStackObject}->{VM_CTRL}->{1}->{SERVER};
   my $OpenstackHttpsEnabled=$args{-openStackObject}->{VM_CTRL}->{1}->{TYPE};
   my $OpenstackUserName=$args{-openStackObject}->{VM_CTRL}->{1}->{USERID};
   my $OpenstackVersion=$args{-openStackObject}->{VM_CTRL}->{1}->{VERSION};
   my $pkt1Gateway=$args{-openStackObject}->{VM_CTRL}->{2}->{GATEWAY};
   my $pkt1ExtNetwork =$args{-openStackObject}->{VM_CTRL}->{5}->{E1Port1};
   my $openstackHostName=$args{-openStackObject}->{VM_CTRL}->{1}->{HOSTNAME};
 


    my $testcase = "test_" . $args{'-tcase'} . "_TestCaseEnabled";
    #Creating or Modifying an existing property file
    unless ( $self->createPropFile(content => {DNSServerIP=>$DnsIP,DNSServerZoneFileName=>$DNSServerZoneFileName,DNSServerZoneFilePath=>$DNSServerZoneFilePath,DNSServerPassword=>$DnsPassword,Log_Directory=>$seleniumLogDir,TestSetName=>$sub_name,DNSServerUserName=>$DNSUserName,DNSServerZoneName=>$DnsServerZoneName,ntpServer=>$NTPIp,SbcSriovEnabled=>$SbcSriovEnabled,configuratorHeatTemplate=>$ConfiguratorHeatTemplate,ssbc11SRIOVHeatTemplate=>$ssbc11SRIOVHeatTemplate,msbc21SRIOVHeatTemplate=>$msbc21SRIOVHeatTemplate,ssbc11HeatTemplate=>$ssbc11HeatTemplate,msbc21HeatTemplate=>$msbc21HeatTemplate,timeZone=>$timeZone,sbcNodeVersion=>$sbcNodeVersion,EMS_InsightNode=>$EMSNodeName,EMS_IP=>$EMSIP,Password=>$EMSGUIPassword,InsightSshUserPassword=>$EMSCliPassword,restUserPassword=>$EMSRestPassword,User_Name=>$EMSGuiLogin,InsightSshUserName=>$EMSCliLogin,restUserName=>$EMSRestLogin,pktoGateway=>$pkt0Gateway,Domain=>$openstackDomainName,pkt0_sriovext_network=>$pkt0sriovExtNetwork,externalSRIOVPkt0Subnet=>$externalSRIOVPkt0Subnet,pkt1_sriovext_network=>$pkt1_sriovext_network,externalSRIOVPkt1Subnet=>$externalSRIOVPkt1Subnet,internalMgmt=>$InternalMgmt,internalMgmtSubnet=>$InternalMgmtSubnet,externalMgmt=>$ExternalMgmt,externalMgmtSubnet=>$externalMgmtSubnet,internalHa=>$InternalHA,internalHaSubnet=>$InternalHASubnet,pkt0_ext_network=>$pkt0ExtNetwork,pkt1_ext_network=>$pkt1ExtNetwork,externalPkt0Subnet=>$externalPkt0Subnet,internalpkt0=>$InternalPkt0,internalpkt0Subnet=>$InternalPkt0Subnet,externalPkt1Subnet=>$externalPkt1Subnet,internalpkt1=>$internalPkt1,internalpkt1Subnet=>$internalPkt1Subnet,sbcOpenstackFlavor=>$sbcflavor,pkt1Gateway=>$pkt1Gateway,openStackHostName=>$openstackHostName,sbcImageName=>$sbcImageName,openStackIpAddress=>$openstackIpAddress,openStackTenantName=>$openstackTenantName,openStackPassword=>$openstackPassword,openStackPortNumber=>$openstackAccessPort,sbcOpenstackSecurityGroup=>$openstackSecurityGroupName,openStackAdminPrivelage=>$openstackAdminPrivelage,OpenstackHttpsEnabled=>$OpenstackHttpsEnabled,openStackUserName=>$OpenstackUserName,openStackVersion=>$OpenstackVersion,$testcase => 'enabled',}, propFile  => $prop_name, bkpPropFile => $bkpProp_name, jarLoc => $jarLoc)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => $bkpProp_name , -jarName => $jar_name)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }


    #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ($self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$sub_name)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}

=head2 SonusQA::SELENIUM::JenkinsPSXCloud()

  It calls the createPropFile() for Creating property file or modifying existing file for editing EMS IP.
  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs
=item Returns

  1 : on success
  0 : on failure

=back

=cut





sub JenkinsPSXCloud() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".Jenkins");
    my $sub_name = "JenkinsCloudPSX";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");


     foreach ('-sippObject', '-tcase', '-psxStackDetails','-emsObject', '-openStackObject') {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }



    $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});

    

    


    #Selenium Details
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};
    my $jar_name = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{KEY_FILE};
    my $prop_name = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{ENV_FILE};


    my @array1=split("\\.",$prop_name);

    my $bkpProp_name = $array1[0].'_bkp.properties';

    $logger->debug('bkp properties file name:'. $bkpProp_name);
    	

   my $seleniumLogDir = $log_dir;
   $seleniumLogDir =~ s|\\|/|g;

   


    #StackDetails 
    my $adminSshKey=$args{-psxStackDetails}->{NODE}->{1}->{KEY_FILE};
	my $psxUnixPassword=$args{-psxStackDetails}->{LOGIN}->{1}->{PASSWD};
	my $ssuserPassword=$args{-psxStackDetails}->{LOGIN}->{2}->{PASSWD};
	my $psxAdminPassword=$args{-psxStackDetails}->{NODE}->{1}->{PASSWD};
	my $psxIpv6MasterHeatTemplate=$args{-psxStackDetails}->{CONFIG}->{1}->{TEMPLATE_FILE};
	my $psxIpv6MasterRecoveryHeatTemplate=$args{-psxStackDetails}->{CONFIG}->{2}->{TEMPLATE_FILE};
	my $psxIpv6SlaveHeatTemplate=$args{-psxStackDetails}->{CONFIG}->{3}->{TEMPLATE_FILE};
	my $psxIpv4MasterHeatTemplate=$args{-psxStackDetails}->{NODE}->{1}->{TEMPLATE_FILE};
	my $psxIpv4MasterRecoveryHeatTemplate=$args{-psxStackDetails}->{NODE}->{2}->{TEMPLATE_FILE};
	my $psxIpv4SlaveHeatTemplate=$args{-psxStackDetails}->{NODE}->{3}->{TEMPLATE_FILE};
	my $psxUnixUserName=$args{-psxStackDetails}->{LOGIN}->{1}->{USERID};
        my $psxNodeVersion=$args{-psxStackDetails}->{NODE}->{1}->{VERSION};     
  
    #EMS status
	my $EMSNodeName=$args{-emsObject}->{NODE}->{1}->{HOSTNAME};
	my $EMSIP=$args{-emsObject}->{NODE}->{1}->{IP};
	my $EMSGUIPassword=$args{-emsObject}->{NODE}->{1}->{PASSWD};
	my $EMSCliPassword=$args{-emsObject}->{NODE}->{2}->{PASSWD};
	my $EMSRestPassword=$args{-emsObject}->{NODE}->{3}->{PASSWD};
	my $EMSGuiLogin=$args{-emsObject}->{NODE}->{1}->{USERID};
	my $EMSCliLogin=$args{-emsObject}->{NODE}->{2}->{USERID};
	my $EMSRestLogin=$args{-emsObject}->{NODE}->{3}->{USERID};

	
	
	#SIPP Object
	my $uaServerDplusCall=$args{-sippObject}->{CONFIG}->{1}->{ENV_FILE};
	my $sipPServerIp=$args{-sippObject}->{NODE}->{1}->{IP};
	my $sipPClientIp=$args{-sippObject}->{NODE}->{1}->{IP_ADDRESS};
	my $uacClient=$args{-sippObject}->{CONFIG}->{1}->{KEY_FILE};
	my $clientPort=$args{-sippObject}->{NODE}->{1}->{M3UA_CLIENT_PORT};
	my $serverPort2=$args{-sippObject}->{NODE}->{1}->{M3UA_SERVER_PORT};
	my $uaServerFile=$args{-sippObject}->{CONFIG}->{1}->{SERVER};
	my $psxCliLocation=$args{-sippObject}->{NODE}->{1}->{STATS_PATH};
	my $psxCallConfig=$args{-sippObject}->{NODE}->{2}->{STATS_PATH};
	my $psxCallConfigV6=$args{-sippObject}->{NODE}->{3}->{STATS_PATH};
	
	
	

    #openStack details
   my $pkt0Gateway=$args{-openStackObject}->{VM_CTRL}->{1}->{DEFAULT_GATEWAY};
   my $openstackDomainName=$args{-openStackObject}->{VM_CTRL}->{1}->{DOMAIN};
   my $pkt0sriovExtNetwork=$args{-openStackObject}->{VM_CTRL}->{1}->{E1ISDNPort1};
   my $externalSRIOVPkt0Subnet=$args{-openStackObject}->{VM_CTRL}->{2}->{E1ISDNPort1};
   my $pkt1_sriovext_network=$args{-openStackObject}->{VM_CTRL}->{1}->{E1ISDNPort2};
   my $externalSRIOVPkt1Subnet=$args{-openStackObject}->{VM_CTRL}->{2}->{E1ISDNPort2};
   my $InternalMgmt=$args{-openStackObject}->{VM_CTRL}->{1}->{E1Port1};
   my $InternalMgmtSubnet=$args{-openStackObject}->{VM_CTRL}->{2}->{E1Port1};
   my $ExternalMgmt=$args{-openStackObject}->{VM_CTRL}->{3}->{E1Port1};
   my $externalMgmtSubnet=$args{-openStackObject}->{VM_CTRL}->{4}->{E1Port1};
   my $InternalHA=$args{-openStackObject}->{VM_CTRL}->{1}->{E1Port2};
   my $InternalHASubnet=$args{-openStackObject}->{VM_CTRL}->{2}->{E1Port2};
   my $pkt0ExtNetwork =$args{-openStackObject}->{VM_CTRL}->{3}->{E1Port2};
   my $externalPkt0Subnet =$args{-openStackObject}->{VM_CTRL}->{4}->{E1Port2};
   my $InternalPkt0=$args{-openStackObject}->{VM_CTRL}->{1}->{E1Port3};
   my $InternalPkt0Subnet=$args{-openStackObject}->{VM_CTRL}->{2}->{E1Port3};
   my $externalPkt1Subnet=$args{-openStackObject}->{VM_CTRL}->{4}->{E1Port3};
   my $internalPkt1=$args{-openStackObject}->{VM_CTRL}->{1}->{E1Port4};
   my $internalPkt1Subnet=$args{-openStackObject}->{VM_CTRL}->{2}->{E1Port4};
   my $sbcflavor=$args{-openStackObject}->{VM_CTRL}->{1}->{FLAVOR};
   my $sbcImageName=$args{-openStackObject}->{VM_CTRL}->{1}->{IMAGE};
   my $openstackIpAddress=$args{-openStackObject}->{VM_CTRL}->{1}->{IP};
   my $openstackTenantName=$args{-openStackObject}->{VM_CTRL}->{1}->{NAME};
   my $openstackPassword=$args{-openStackObject}->{VM_CTRL}->{1}->{PASSWD};
   my $openstackAccessPort=$args{-openStackObject}->{VM_CTRL}->{1}->{PORT};
   my $openstackSecurityGroupName=$args{-openStackObject}->{VM_CTRL}->{1}->{SECURITY_GROUPS};
   my $openstackAdminPrivelage=$args{-openStackObject}->{VM_CTRL}->{1}->{SERVER};
   my $OpenstackHttpsEnabled=$args{-openStackObject}->{VM_CTRL}->{1}->{TYPE};
   my $OpenstackUserName=$args{-openStackObject}->{VM_CTRL}->{1}->{USERID};
   my $OpenstackVersion=$args{-openStackObject}->{VM_CTRL}->{1}->{VERSION};
   my $pkt1Gateway=$args{-openStackObject}->{VM_CTRL}->{2}->{GATEWAY};
   my $pkt1ExtNetwork =$args{-openStackObject}->{VM_CTRL}->{5}->{E1Port1};
   my $openstackHostName=$args{-openStackObject}->{VM_CTRL}->{1}->{HOSTNAME};
   my $psxFlavor=$args{-openStackObject}->{VM_CTRL}->{2}->{FLAVOR};
   my $psxImage=$args{-openStackObject}->{VM_CTRL}->{2}->{IMAGE};


    my $testcase = "test_" . $args{'-tcase'} . "_TestCaseEnabled";
    #Creating or Modifying an existing property file
    unless ( $self->createPropFile(content => {EMS_IP=>$EMSIP,Password=>$EMSGUIPassword,InsightSshUserPassword=>$EMSCliPassword,Log_Directory=>$seleniumLogDir,TestSetName=>$sub_name,restUserPassword=>$EMSRestPassword,User_Name=>$EMSGuiLogin,InsightSshUserName=>$EMSCliLogin,restUserName=>$EMSRestLogin,psxNodeVersion=>$psxNodeVersion,pktoGateway=>$pkt0Gateway,Domain=>$openstackDomainName,pkt0_sriovext_network=>$pkt0sriovExtNetwork,externalSRIOVPkt0Subnet=>$externalSRIOVPkt0Subnet,pkt1_sriovext_network=>$pkt1_sriovext_network,externalSRIOVPkt1Subnet=>$externalSRIOVPkt1Subnet,internalMgmt=>$InternalMgmt,internalMgmtSubnet=>$InternalMgmtSubnet,externalMgmt=>$ExternalMgmt,externalMgmtSubnet=>$externalMgmtSubnet,internalHa=>$InternalHA,internalHaSubnet=>$InternalHASubnet,pkt0_ext_network=>$pkt0ExtNetwork,pkt1_ext_network=>$pkt1ExtNetwork,externalPkt0Subnet=>$externalPkt0Subnet,internalpkt0=>$InternalPkt0,internalpkt0Subnet=>$InternalPkt0Subnet,externalPkt1Subnet=>$externalPkt1Subnet,internalpkt1=>$internalPkt1,internalpkt1Subnet=>$internalPkt1Subnet,sbcOpenstackFlavor=>$sbcflavor,pkt1Gateway=>$pkt1Gateway,openStackHostName=>$openstackHostName,sbcImageName=>$sbcImageName,openStackIpAddress=>$openstackIpAddress,openStackTenantName=>$openstackTenantName,openStackPassword=>$openstackPassword,openStackPortNumber=>$openstackAccessPort,sbcOpenstackSecurityGroup=>$openstackSecurityGroupName,openStackAdminPrivelage=>$openstackAdminPrivelage,OpenstackHttpsEnabled=>$OpenstackHttpsEnabled,openStackUserName=>$OpenstackUserName,openStackVersion=>$OpenstackVersion,AdminSshKeys=>$adminSshKey,PSX_password=>$psxUnixPassword,PSX_Ssuser_Password=>$ssuserPassword,psxMasterHeatTemplateV6=>$psxIpv6MasterHeatTemplate,psxRecoveryMasterStackTemplateUrlV6=>$psxIpv6MasterRecoveryHeatTemplate,psxSlaveStackTemplateUrlV6=>$psxIpv6SlaveHeatTemplate,psxMasterHeatTemplate=>$psxIpv4MasterHeatTemplate,psxRecoveryMasterStackTemplateUrl=>$psxIpv4MasterRecoveryHeatTemplate,psxSlaveStackTemplateUrl=>$psxIpv4SlaveHeatTemplate,PSX_username=>$psxUnixUserName,psxCliLocation=>$psxCliLocation,psxCallConfig=>$psxCallConfig,psxCallConfigV6=>$psxCallConfigV6,psxOpenstackFlavor=>$psxFlavor,psxImageName=>$psxImage,$testcase => 'enabled',}, propFile  => $prop_name, bkpPropFile => $bkpProp_name, jarLoc => $jarLoc)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => $bkpProp_name , -jarName => $jar_name)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }


    #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ($self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$sub_name)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 1;

}
=head2 SonusQA::SELENIUM::JenkinsEMSCloudInstall()

  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs
=item Returns

  1 : on success
  0 : on failure

=back

=cut


sub JenkinsEMSCloudInstall() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".Jenkins");
    my $sub_name = "JenkinsEMSCloudInstall";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");


   foreach ('-tcase', '-emsObject', '-openStackObject') {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }

    $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});

    #Selenium Details
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};
    my $jar_name = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{KEY_FILE};
    my $prop_name = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{ENV_FILE};
    my $seleniumLogDir = $log_dir;
    $seleniumLogDir =~ s|\\|/|g;
    my $propLoc= $jarLoc. "\\".$prop_name;

    #EMS status
    my $EMSNodeName=$args{-emsObject}->{NODE}->{1}->{HOSTNAME};
    my $EMSIP=$args{-emsObject}->{NODE}->{1}->{IP};
    my $EMSGUIUser=$args{-emsObject}->{GUI}->{1}->{USERID};
    my $EMSGUIPassword=$args{-emsObject}->{GUI}->{1}->{PASSWD};
    my $EMSCliLogin=$args{-emsObject}->{NODE}->{2}->{USERID};
    my $EMSCliPassword=$args{-emsObject}->{NODE}->{2}->{PASSWD};

    #EMS statck details
    my $emsHeatTemplate=$args{-stackDetails}->{NODE}->{1}->{TEMPLATE_FILE};
    my $adminSshKey=$args{-stackDetails}->{NODE}->{1}->{KEY_FILE};
    my $emsAdminPassword = $args{-stackDetails}->{NODE}->{1}->{PASSWD};
    my $timeZone = $args{-stackDetails}->{NODE}->{1}->{TIMEZONE};

   #openStack details
   my $openStackIpAddress=$args{-openStackObject}->{VM_CTRL}->{1}->{IP};
   my $openStackTenantName=$args{-openStackObject}->{VM_CTRL}->{1}->{NAME};
   my $openStackPassword=$args{-openStackObject}->{VM_CTRL}->{1}->{PASSWD};
   my $openStackPortNumber=$args{-openStackObject}->{VM_CTRL}->{1}->{PORT};
   my $openStackAdminPrivelage=$args{-openStackObject}->{VM_CTRL}->{1}->{SERVER};
   my $OpenstackHttpsEnabled=$args{-openStackObject}->{VM_CTRL}->{1}->{TYPE};

   my $openStackUserName=$args{-openStackObject}->{VM_CTRL}->{1}->{USERID};
   my $openStackVersion=$args{-openStackObject}->{VM_CTRL}->{1}->{VERSION};
   my $openStackHostName=$args{-openStackObject}->{VM_CTRL}->{1}->{HOSTNAME};

   my $ExternalMgmt=$args{-openStackObject}->{VM_CTRL}->{3}->{E1Port1};
   my $externalMgmtSubnet=$args{-openStackObject}->{VM_CTRL}->{4}->{E1Port1};
   my $pkt0ExtNetwork =$args{-openStackObject}->{VM_CTRL}->{3}->{E1Port2};
   my $externalPkt0Subnet =$args{-openStackObject}->{VM_CTRL}->{4}->{E1Port2};
   my $emsflavor=$args{-openStackObject}->{VM_CTRL}->{3}->{FLAVOR};
   my $emsImageName=$args{-openStackObject}->{VM_CTRL}->{3}->{IMAGE};


    my $testcase = "test_" . $args{'-tcase'} . "_TestCaseEnabled";
   # Updating Property file
   unless ( $self->createPropFile(content => {EMS_MGMT_IP=>$EMSIP,Password=>$EMSGUIPassword,EMS_username=>$EMSCliLogin,EMS_password=>$EMSCliPassword,Log_Directory=>$seleniumLogDir,TestSetName=>$sub_name,openStackIpAddress=>$openStackIpAddress,openStackPortNumber=>$openStackPortNumber,openStackUserName=>$openStackUserName,openStackPassword=>$openStackPassword,openStackTenantName=>$openStackTenantName,openStackAdminPrivelage=>$openStackAdminPrivelage,openStackHostName=>$openStackHostName,openStackVersion=>$openStackVersion,OpenstackHttpsEnabled=>$OpenstackHttpsEnabled,externalMgmt=>$ExternalMgmt,pkt0_Ext_Network=>$pkt0ExtNetwork,externalMgmtSubnet=>$externalMgmtSubnet,externalPkt0Subnet=>$externalPkt0Subnet,emsOpenstackFlavour=>$emsflavor,emsHeatTemplate=>$emsHeatTemplate,emsAdminPassword=>$emsAdminPassword,AdminSshKeys=>$adminSshKey,emsImageName=>$emsImageName,$testcase => 'enabled',}, propFile  => $prop_name, jarLoc => $jarLoc)) {

    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    #calling the subroutine for running the jar by specifying the property file
        #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => $prop_name , -jarName => $jar_name)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }


     $logger->debug('EMS details : '. Dumper($args{-emsObject}));

=head
    my @output = () ;
    unless ( @output = $self->{conn}->cmd("type $propLoc")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Not able to print the file with the argument \'-propFile\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }
    chomp @output ;
    unless ( @output = $self->{conn}->cmd("for \/f \"tokens=3\" %a in ('findstr EMS_MGMT_IP  $propLoc') do echo %a")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Not able to fetch management IP from  \'-propFile\' file");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }

  #}

    $logger->debug( 'output array : '.@output);
    $output[0] =~ s/^\s+|\s+$//g;
    $logger->debug( 'output array : '.$output[0]);

     $args{-emsObject}->{NODE}->{1}->{IP} = "$output[0]";
     $logger->debug( 'Updated EMS details : '.Dumper($args{-emsObject}));
=cut
    #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ($self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$sub_name)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");


    return 1;
}


=head2 SonusQA::SELENIUM::JenkinsEMSCloudUpgrade()

  It calls runSeleniumSuite() to excute the selenium suite.
  It calls CollectLog() to collect the Selenium Results and Logs
=item Returns

  1 : on success
  0 : on failure

=back

=cut

sub JenkinsEMSCloudUpgrade() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".JenkinsEMSCloudUpgrade");
    my $sub_name = "JenkinsEMSCloudUpgrade";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");


   foreach ('-tcase', '-emsObject', '-openStackObject') {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }

    $self->{conn}->cmd(String => "taskkill /t /F /IM javaw.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    #Selenium Details
    my $jarLoc = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{JAR_DIR};
    my $log_dir = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{LOG_DIR};
    my $jar_name = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{KEY_FILE};
    my $prop_name = $self->{TMS_ALIAS_DATA}->{NODE}->{1}->{ENV_FILE};
    my $seleniumLogDir = $log_dir;
    $seleniumLogDir =~ s|\\|/|g;
    my $propLoc= $jarLoc. "\\".$prop_name;

    #EMS status
    my $EMSNodeName=$args{-emsObject}->{NODE}->{1}->{HOSTNAME};
    my $EMSIP=$args{-emsObject}->{NODE}->{1}->{IP};
    my $EMSGUIUser=$args{-emsObject}->{GUI}->{1}->{USERID};
    my $EMSGUIPassword=$args{-emsObject}->{GUI}->{1}->{PASSWD};
    my $EMSCliLogin=$args{-emsObject}->{NODE}->{2}->{USERID};
    my $EMSCliPassword=$args{-emsObject}->{NODE}->{2}->{PASSWD};

    #EMS statck details
    my $emsHeatTemplate=$args{-stackDetails}->{NODE}->{1}->{TEMPLATE_FILE};
    my $emsStackName=$args{-stackDetails}->{NODE}->{1}->{EMS_ALIAS_NAME};

   #openStack details
   my $openStackIpAddress=$args{-openStackObject}->{VM_CTRL}->{1}->{IP};
   my $openStackTenantName=$args{-openStackObject}->{VM_CTRL}->{1}->{NAME};
   my $openStackPassword=$args{-openStackObject}->{VM_CTRL}->{1}->{PASSWD};
   my $openStackPortNumber=$args{-openStackObject}->{VM_CTRL}->{1}->{PORT};
   my $openStackAdminPrivelage=$args{-openStackObject}->{VM_CTRL}->{1}->{SERVER};
   my $OpenstackHttpsEnabled=$args{-openStackObject}->{VM_CTRL}->{1}->{TYPE};

   my $openStackUserName=$args{-openStackObject}->{VM_CTRL}->{1}->{USERID};
   my $openStackVersion=$args{-openStackObject}->{VM_CTRL}->{1}->{VERSION};
   my $openStackHostName=$args{-openStackObject}->{VM_CTRL}->{1}->{HOSTNAME};

   my $emsUpgradeImageName=$args{-openStackObject}->{VM_CTRL}->{4}->{IMAGE};


    my $testcase = "test_" . $args{'-tcase'} . "_TestCaseEnabled";
   # Updating Property file
   unless ( $self->createPropFile(content => {EMS_MGMT_IP=>$EMSIP,Password=>$EMSGUIPassword,EMS_username=>$EMSCliLogin,EMS_password=>$EMSCliPassword,Log_Directory=>$seleniumLogDir,TestSetName=>$sub_name,openStackIpAddress=>$openStackIpAddress,openStackPortNumber=>$openStackPortNumber,openStackUserName=>$openStackUserName,openStackPassword=>$openStackPassword,openStackTenantName=>$openStackTenantName,openStackAdminPrivelage=>$openStackAdminPrivelage,openStackHostName=>$openStackHostName,openStackVersion=>$openStackVersion,OpenstackHttpsEnabled=>$OpenstackHttpsEnabled,emsHeatTemplate=>$emsHeatTemplate,emsUpgradeImageName=>$emsUpgradeImageName,emsStackName=>$emsStackName,$testcase => 'enabled',}, propFile  => $prop_name, jarLoc => $jarLoc)) {

    $logger->error(__PACKAGE__ . ".$sub_name: failed to create property file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    #calling the subroutine for running the jar by specifying the property file
        #calling the subroutine for running the jar by specifying the property file

    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => $prop_name , -jarName => $jar_name)) {

    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }


     $logger->debug('EMS details : '. Dumper($args{-emsObject}));
    #Calling the subroutine for fetching the result file and necessary log information and declaring the result

    unless ($self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$sub_name)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");


    return 1;
}

=head2 SonusQA::SELENIUM::runSeleniumTestCase()

  It runs a selenium testcase on the windows system
  It writes the required property file on the windows system
  It calls CollectLog() to collect the Selenium Results and Logs
=item Returns

  1 : on success
  0 : on failure

=back

=cut

sub runSeleniumTestCase() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".Jenkins");
    my $sub_name = "runSeleniumTestCase";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Going to start running the selenium test case");

    my $tcid = $args{tCase};
    my $verifyAfterUpgrade = $args{verifyAfterUpgrade};
    
    $logger->info(__PACKAGE__ . ".$sub_name: Test Case id:$tcid");
    $logger->info(__PACKAGE__ . ".$sub_name: Test Bed Received :" . Dumper(\%{$args{tBed}}));
    $logger->info(__PACKAGE__ . ".$sub_name: Verify after upgrade :".$verifyAfterUpgrade);

    $self->createPropFileAuto(content => \%{$args{tBed}}, testCase => $tcid, verifyAfterUpgrade => $verifyAfterUpgrade);

    my $prop_name = $args{tBed}->{ENV_FILE};
    my $jarLoc = $args{tBed}->{JAR_DIR};
    my $jarFile = $args{tBed}->{KEY_FILE};
    my $log_dir = $args{tBed}->{SELENIUM_LOG_DIR};
    my $testSetName = $args{tBed}->{TestSetName};
    
    #my $prop_name = $CompleteTmsAliasHash{'ENV_FILE'};
    #my $jarLoc = $CompleteTmsAliasHash{'JAR_DIR'};
    #my $jarFile = $CompleteTmsAliasHash{'KEY_FILE'};
    #my $log_dir = $CompleteTmsAliasHash{'SELENIUM_LOG_DIR'};
    #my $testSetName = $CompleteTmsAliasHash{'TestSetName'};

    if($verifyAfterUpgrade == 1)
    {
       $prop_name = "Verify_".$prop_name;
       $logger->info(__PACKAGE__ . ".$sub_name: Verify after upgrade, so env file updated to  :".$prop_name);
    }
    my @array1=split("\\.",$prop_name);
    my $bkpPropFile = $array1[0].'_bkp.properties';


    $self->{conn}->cmd(String => "taskkill /t /F /IM chrome.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    $self->{conn}->cmd(String => "taskkill /t /F /IM firefox.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    $self->{conn}->cmd(String => "taskkill /t /F /IM iexplore.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    $self->{conn}->cmd(String => "taskkill /t /F /IM iedriver.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    $self->{conn}->cmd(String => "taskkill /t /F /IM chromedriver.exe", Timeout=> $self->{DEFAULTTIMEOUT});
    $self->{conn}->cmd(String => "taskkill /t /F /IM gekodriver.exe", Timeout=> $self->{DEFAULTTIMEOUT});


    unless ( $self->runSeleniumSuite( -jarLoc => $jarLoc , -propFile => $bkpPropFile, -jarName =>$jarFile)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to run Selenium ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

    unless ( $self->CollectLog(-log_Directory=>$log_dir, -TestSet=>$testSetName)) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }

}


=head2 SonusQA::SELENIUM::runSeleniumTestCaseLinux()

        Sub Routine to create a temp executable script, copy the jar and script to linux server and execute the test case. 
=over

=item Arguments

 testCase,verifyAfterUpgrade,testBedDetails 

=item Returns

  none

=back

=cut

sub runSeleniumTestCaseLinux()
{
        my ($self , %args ) = @_;
        my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".runSeleniumTestCaseLinux");
        my $sub_name = "runSeleniumTestCaseLinux";
        my @res; 
	#print Dumper($self);
        my $tcid = $args{tCase};
        my $verifyAfterUpgrade = $args{verifyAfterUpgrade};
	#my $jarFile = "/home/nvandiyar/ats_repos/lib/perl/QATEST/EMS/EMSSANITY/CloudCicdComplete.jar";
	#my $propFile = "/home/nvandiyar/ats_repos/lib/perl/QATEST/EMS/EMSSANITY/CloudCicdComplete.properties";
	my $jarLoc = "/home/jenkins/";

	my $propFile = $args{tBed}->{PROPERTY_FILE};
    	my $jarFile = $args{tBed}->{JAR_FILE};
	my $testSetName = $args{tBed}->{TestSetName};
       
        my $dockerIp = $args{tBed}->{'DOCKER_IP'};
        my $dockerUserName = $args{tBed}->{'DOCKER_USERNAME'};
        my $dockerPassw = $args{tBed}->{'DOCKER_PASSWORD'};


	unless (defined $propFile) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument PROPERTY_FILE not defined empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
        unless (defined $jarFile) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument JAR_FILE not defined empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
	
        my $bkpPropfile = $self->createPropFileAutoLinux(content => \%{$args{tBed}}, testCase => $tcid, jarFile => $jarFile, propFile => $propFile, verifyAfterUpgrade => $verifyAfterUpgrade);
        $logger->debug(__PACKAGE__ . "new Env file: $bkpPropfile");
	#print Dumper($args{tBed});


	#Copy the JAR and property file to Server
	my %scpArgs;
        $scpArgs{-hostip} = $args{tBed}->{IP};
        $scpArgs{-hostuser} =  $args{tBed}->{USERID};
        $scpArgs{-hostpasswd} = $args{tBed}->{PASSWD};

        #foreach my $file ($jarFile,$bkpPropfile){
        foreach my $file ($bkpPropfile){
           $scpArgs{-sourceFilePath} = $file;
           $scpArgs{-destinationFilePath} = "$scpArgs{-hostip}:$jarLoc";
           unless(&SonusQA::Base::secureCopy(%scpArgs)){
             $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the file $file to $jarLoc");
             $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
             return 0;
          }
       }

        my $jarFileOnly = basename($jarFile,  ".jar");
        $jarFileOnly = $jarFileOnly.".jar";
        my $propFileOnly = basename($bkpPropfile,  ".properties");
        $propFileOnly = $propFileOnly.".properties";

	#Create executable file
	my $execName = $self->{sessionLog1};
	$execName =~ s/sessionDump.log/start.sh/g ;
	$execName =~ s/SELENIUM-UNKNOWN-//g ;
        my $execNameOnly = basename($execName,  ".sh");
        $execNameOnly = $execNameOnly.int(rand(1000)).".sh";
	my $execDir = dirname($execName);
	$execName = $execDir."/".$execNameOnly;


        $logger->info(__PACKAGE__ . ".$sub_name: execNameOnly:$execNameOnly");

	unlink($execName);
	my $handle;
    $logger->info(__PACKAGE__ . ".$sub_name: Writing the exectuable script file on to the remote system $execName");
    unless (open $handle, '>', $execName ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Not able to write the property file $execName");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->error(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }
    my @newOutput = () ;
    push (@newOutput, "#!/bin/sh");
    push (@newOutput, "export DISPLAY=:1.0");
    push (@newOutput, "rm -rf /home/jenkins/video.mp4");
    push (@newOutput, "rm -rf /home/jenkins/Jenkins*");
    push (@newOutput, "ffmpeg -video_size 1280x1024 -framerate 15 -f x11grab -i :1.0 /home/jenkins/video.mp4 -v 0&");
    push (@newOutput, "java -DPropertyFile=/home/jenkins/".$propFileOnly." -jar /home/jenkins/".$jarFileOnly." >> /home/jenkins/JenkinsJava.log");
    push (@newOutput, "pkill -2 ffmpeg");
    push (@newOutput, "sleep 10");
    push (@newOutput, "MP4Box -isma -inter 500 /home/jenkins/video.mp4");
    #push (@newOutput, "ffmpeg -i /home/jenkins/video.mp4 -vcodec libx264 -crf 42 /home/jenkins/Jenkins_out.mp4");

    foreach(@newOutput){
          $_ =~ s/^\s+|\s+$//g;
          $_ =~ s/(<|>)/^$1/g;             #Fix for TOOLS-15660. Replacing '< or >' symbol before writing into file
          print $handle "$_\n";
    }
        close $handle; # Not necessary, but nice to do

	#Copy the executable to server
           $scpArgs{-sourceFilePath} = $execName;
           $scpArgs{-destinationFilePath} = "$scpArgs{-hostip}:$jarLoc";
           unless(&SonusQA::Base::secureCopy(%scpArgs)){
             $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the file $execName to $jarLoc");
             $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
             return 0;
          }

        $logger->info(__PACKAGE__ . ".$sub_name: Executing chmod +x /home/jenkins/$execNameOnly");
	#print Dumper($self);
        unless (@res = $self->{conn}->cmd("chmod +x /home/jenkins/".$execNameOnly)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to run the command");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
        }
        print Dumper(\@res);

	
        $logger->info(__PACKAGE__ . ".$sub_name: Executing /home/jenkins/$execNameOnly");
        unless (@res = $self->{conn}->cmd("/home/jenkins/".$execNameOnly)) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to run the command");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
        }
        #print Dumper(\@res);

        $logger->info(__PACKAGE__ . ".$sub_name: Executing video compression command");
        unless (@res = $self->{conn}->cmd("ffmpeg -y -i /home/jenkins/video.mp4 -vcodec libx264 -crf 42 /home/jenkins/Jenkins_out.mp4 -v 0")) {
        #unless (@res = $self->{conn}->cmd("date")) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to run the command");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
        }
        #print Dumper(\@res);
	sleep(10);

        $logger->info(__PACKAGE__ . ".$sub_name: Executing tar -czvf /home/jenkins/Jenkins.tar.gz /home/jenkins/Jenkins*");
        @res = ();
        unless (@res = $self->{conn}->cmd("tar -czvf /home/jenkins/Jenkins.tar.gz /home/jenkins/Jenkins*")) {
        $logger->error(__PACKAGE__ . ".$sub_name: failed to run the command");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
        }	
        print Dumper(\@res);

	my $dest = $self->{sessionLog1};
	$dest =~ s/sessionDump.log/Jenkins.tar.gz/g ;
	$dest =~ s/SELENIUM-UNKNOWN-//g ;
	my $destNameOnly = basename($dest,  ".tar.gz");
        $destNameOnly = $destNameOnly.int(rand(1000)).".tar.gz";
        my $destDir = dirname($dest);
        $dest = $destDir."/".$destNameOnly;

        $scpArgs{-destinationFilePath} = $dest;
        $scpArgs{-srcFileName} = "/home/jenkins/Jenkins.tar.gz";

        $scpArgs{-sourceFilePath} = $scpArgs{-hostip}.':'.$scpArgs{-srcFileName};
        unless(&SonusQA::Base::secureCopy(%scpArgs)){
           $logger->error(__PACKAGE__ . ".$sub_name:  SCP failed to copy the files");
           $logger->debug(__PACKAGE__ . ".$sub_name:  <-- Leaving sub. [0]");
           return 0;
        }
	print "Log_File :$dest \n";
	
 	#Calling the subroutine for fetching the result file and necessary log information and declaring the result
	sleep(10);
	my $result = 0;
    	unless ($result = $self->CollectLogLinux(-log_Directory=>"/home/jenkins", -TestSet=>$testSetName)) {
    	$logger->error(__PACKAGE__ . ".$sub_name: failed to collect logs or test case failed");
    	$logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    	return 0;
    	}
	return $result;	
}

=head2 SonusQA::SELENIUM::createPropFileAutoLinux()

        Sub Routine to create a selenium test case property file and scp it to the linux server
=over

=item Arguments

  testCase,jarFile,propFile

=item Returns

  none

=back

=cut

sub createPropFileAutoLinux {

    my ($self , %args ) = @_ ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createPropFileAutoLinux");
    my $sub_name = "createPropFileAutoLinux";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $tcId = $args{testCase};
    my $jarFile = $args{jarFile};
    my $propFile = $args{propFile};

    $logger->info(__PACKAGE__ . "testCase .$tcId");
    $logger->info(__PACKAGE__ . "jarFile .$jarFile");
    $logger->info(__PACKAGE__ . "propFile .$propFile");

    my $verifyAfterUpgrade = $args{verifyAfterUpgrade};
    $logger->info(__PACKAGE__ . ".$sub_name: Test case to enable: $tcId");
    $logger->info(__PACKAGE__ . ".$sub_name: Tms Alias Hash recevied:" . Dumper(\%{$args{content}}));
    $logger->info(__PACKAGE__ . ".$sub_name: Verify after upgrade:" . $verifyAfterUpgrade);
    
    #undef %CompleteTmsAliasHash;
    #&ConvertTmsAliasToSingleHash(\%{$args{content}});
    my %CompleteTmsAliasHash = %{$args{content}};
    $logger->info(__PACKAGE__ . ".$sub_name:Converted Tms Alias Hash array :" . Dumper(\%CompleteTmsAliasHash) );

    unless(-e ($propFile))
    {
       $logger->error(__PACKAGE__ . "$propFile not found");
       $logger->debug(__PACKAGE__ . "$propFile not found Leaving Sub [0]");
       return 0;
    }

    my $prop_name_temp = basename($propFile,  ".properties");
    my $prop_name = $prop_name_temp + ".properties";
    my $propLoc = dirname($propFile);
    $logger->info(__PACKAGE__ . "prop_name $prop_name");
    $logger->info(__PACKAGE__ . "propLoc $propLoc");

    if($verifyAfterUpgrade == 1)
    {
       $prop_name = "Verify_".$prop_name;
       $CompleteTmsAliasHash{'ENV_FILE'} = $prop_name;
       $logger->info(__PACKAGE__ . ".$sub_name: Verify after upgrade, so env file updated to  :".$prop_name);
    }

    my $jarName = basename($jarFile,  ".jar")+".jar";
    my $jarLoc = dirname($jarFile);
    $logger->info(__PACKAGE__ . "jarName $jarName");
    $logger->info(__PACKAGE__ . "jarLoc $jarLoc");
    	
    my $bkpPropFile = $prop_name_temp.(int rand(10000)).'.properties';
    $logger->info(__PACKAGE__ . "bkpPropFile $bkpPropFile");
    $CompleteTmsAliasHash{'ENV_FILE_NEW'} = $bkpPropFile;

    my @output = () ; 
    my $handle; 
    unless (open $handle, '<', $propFile ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Not able to read the property file \'-propFile\'");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->error(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }      
    chomp(@output = <$handle>);
    close $handle;
    chomp @output;

    @output = grep /\S/,@output;
    $logger->info(__PACKAGE__ . ".$sub_name:Output array :" . Dumper(\@output) );

    #to disable all the test cases which are already enabled 
    foreach my $output (@output){
    my ($name, $value) = split /=/, $output;
     $value =~ s/^\s+//;
     $value =~ s/\s+$//;
   		 
    #if (defined($value) and ($value eq 'enabled') and ($name  =~ m/TestCaseEnabled/)){
    if (defined($value) and ($name  =~ m/TestCaseEnabled/)){
       $logger->info(__PACKAGE__ . ".$sub_name: argument exists , hence replacing it ");
       my @tc = split('_', $name);
       my $tcIdFound = $tc[1];
       if($tcIdFound eq $tcId)
       {
       	   $output = join "=", $name, " enabled";  
       }
       else
       {
       	   $output = join "=", $name, " not-enabled";  
       }
     }

    }

    #Keep command and values specific to this test case only
    my @newOutput = () ;
    foreach my $output (@output){
      my ($name, $value) = split /=/, $output;
      $value =~ s/^\s+//;
      $value =~ s/\s+$//;
      if (defined($value))
      {
        if (($name =~ /^test_/))
        {
	  #Found test_, check if its related to this test case
          my @tc = split('_', $name);
          my $tcIdFound = $tc[1];
          if($tcIdFound eq $tcId)
          {
	   push (@newOutput, $output);	
          } 
        }
	else
	{	
	   push (@newOutput, $output);	
	}
      }

    }

    $logger->info(__PACKAGE__ . ".$sub_name:New Output array :" . Dumper(\@newOutput) );

 
    $logger->info(__PACKAGE__ . ".$sub_name: checking for the hash if its already present"); 
     if (exists($args{content})) {
       foreach my $key (keys %CompleteTmsAliasHash) {
             my $count = 0 ;
             for (my $comp=0 ; $comp<=$#newOutput ; $comp++){
		 if($key =~ /^ *$/) {
			next;
		 }
                 if ($newOutput[$comp] =~ m/\b$key\b/i){
                  	 $logger->info(__PACKAGE__ . ".$sub_name: argument '$key' exists , hence replacing it ");
                     $newOutput[$comp] = "$key = $CompleteTmsAliasHash{$key}" ;
                     $count++ ;
                     last ;
                 } else {
                       next ;  
                 }          
             }   
        
             $logger->info(__PACKAGE__ . ".$sub_name: value of count = $count");
                 if ($count == 0) {
                 $logger->info(__PACKAGE__ . ".$sub_name: argument $key doesnt exist  , hence ignoring the values");
                 #push (@newOutput , "$key=$args{content}{$key}"  ) ;
             }     
         }

    #Delete the backup file if it already exists
    my $fileName  = $self->{sessionLog1};
    
    $fileName =~ s/sessionDump.log/$bkpPropFile/g ;
    $fileName =~ s/SELENIUM-UNKNOWN-//g ;
    
    unlink($bkpPropFile);
    $logger->info(__PACKAGE__ . ".$sub_name: Writing the property file on to the remote system $fileName");
    unless (open $handle, '>', $fileName ) {
        $logger->error(__PACKAGE__ . ".$sub_name: Not able to write the property file $fileName");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->error(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
        return 0;
    }      
    
    foreach(@newOutput){
          $_ =~ s/^\s+|\s+$//g;
          $_ =~ s/(<|>)/^$1/g;             #Fix for TOOLS-15660. Replacing '< or >' symbol before writing into file
          print $handle "$_\n";
    }
	close $handle; # Not necessary, but nice to do
        $logger->info(__PACKAGE__ . ".$sub_name: Finsihed writing the property file on to the remote system");
          
	return $fileName; 
    }

   return 1 ;
}

=head2 SonusQA::SELENIUM::CollectLogLinux()

        Sub Routine to fetch selenium log file from a linux server
=over

=item Arguments

  none

=item Returns

  testResult

=back

=cut

sub CollectLogLinux() {

    my ($self , %args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".CollectLogLinux");
    my $sub_name = "CollectLogLinux";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $timestamp = strftime "%m-%d-%y-%H-%M", localtime;

    my $resultFile=$self->{result_path}."Selenium_"."$args{-TestSet}\_$timestamp";

    my $result=1;

    foreach ('-log_Directory', '-TestSet') {
        unless (defined $args{$_}) {
           $logger->error(__PACKAGE__ . ".$sub_name: mandatory argument \'$_\' empty");
           $logger->debug(__PACKAGE__ . ".$sub_name: Leaving Sub [0]");
           return 0;
        }
    }

    my @output= ();
    unless (@output = $self->{conn}->cmd("cat /home/jenkins/$args{-TestSet}*/*.res") ) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to get the log files Directory");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    unless(grep /Passed/is, @output) {
        $logger->info(__PACKAGE__ . ".$sub_name: TEST FAILED with errors");
        $result=0;}
    else
    {
        $logger->info(__PACKAGE__ . ".$sub_name: TEST PASSED");
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Writing the Selenium Result to the file $resultFile.txt");

    my $f;
    unless ( open LOGFILE, $f = ">$resultFile.txt" ) {
    $logger->error(__PACKAGE__ . ".$sub_name: failed to open file ");

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    print LOGFILE join("\n", @output);
    unless ( close LOGFILE ) {
    $logger->error(__PACKAGE__ . ".$sub_name: Cannot close output file ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub");
    return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Selenium Results successfully written to the file $resultFile.txt");
    return $result;
}

=head2 SonusQA::SELENIUM::FectchFreeDockerIp()

        Sub Routine to fectch a free docker IP.
=over

=item Arguments

  -dockerHostIp,-dockerPassw,-dockerUserName

=item Returns

  dockerInstnaceIp

=back

=cut

sub FectchFreeDockerIp()
{
    my (%args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".FectchFreeDockerIp");
    my $sub_name = "FectchFreeDockerIp";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    print Dumper(%args);

    my $dockerHostIp = $args{-dockerHostIp};
    my $dockerPassw = $args{-dockerPassw};
    my $dockerUserName = $args{-dockerUserName};
    $logger->info(__PACKAGE__ . ".$sub_name: dockerHostIp: $dockerHostIp");
    $logger->info(__PACKAGE__ . ".$sub_name: dockerPassw: $dockerPassw");
    $logger->info(__PACKAGE__ . ".$sub_name: dockerUserName: $dockerUserName");
 
    my $url = "http://".$dockerHostIp.":9000/getFreeDockerIp";
    my ($responcecode,$responcecontent) = SonusQA::Base::restAPI( -url            => $url,
                                                    -contenttype    => 'JSON',
                                                    -method         => 'GET',
                                                    -username       => 'admin',
                                                    -password       => 'Sonus@123',
                                                    -arguments      => '');
    $logger->info(__PACKAGE__ . ".$sub_name:responcecode $responcecode");
    $logger->info(__PACKAGE__ . ".$sub_name:responcecontent $responcecontent");
    my $json = decode_json($responcecontent);
    my $freeIp = $json->{'instanceIp'};
    return $freeIp;
 

    my $dockerSession = new SonusQA::Base( -obj_host       => "$dockerHostIp",
                                         -obj_user       => "$dockerUserName",
                                         -obj_password   => "$dockerPassw",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 33300,
                                         -sessionlog => 1,
                                       );
    unless ($dockerSession) {
       $logger->error(__PACKAGE__ . ".$sub_name: Could not open connection to Docker on $dockerHostIp");
       return 0;
     }
    my @output= ();
    unless (@output = $dockerSession->{conn}->cmd("docker ps | grep -v ID | awk -F \" \" '{print \$NF}'") ) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to get the list of dockers running");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    } 
    print Dumper(@output);

    my @dockerAvaialble = ();
        unless (@dockerAvaialble = $dockerSession->{conn}->cmd("cat /root/dockerIpList.txt") ) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to get the list of docker ips available");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    print Dumper(@dockerAvaialble);

    $logger->debug(__PACKAGE__ . ".$sub_name checking the free IPs");
    my %totalIps;
    @totalIps{ @dockerAvaialble } = ();            # All files are the keys.
    delete @totalIps{ @output }; # Remove the links.
    my @freeIps = keys %totalIps;
    print "Free IPs:".Dumper(@freeIps);

    if(@freeIps == 0)
    {
	$logger->error(__PACKAGE__ . ".$sub_name: No More Free Docker IPs avaiable");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    chomp$freeIps[0];
    return $freeIps[0];
}


=head2 SonusQA::SELENIUM::CreateDockerInstance()

        Sub Routine to create a given docker instance by IP.
=over

=item Arguments

  -dockerHostIp,-dockerPassw,-dockerUserName,-dockerInstnaceIp

=item Returns

  dockerInstnaceId

=back

=cut

sub CreateDockerInstance()
{
    my (%args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".CreateDocker");
    my $sub_name = "CreateDocker";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    #print Dumper(%args);

    my $dockerHostIp = $args{-dockerHostIp};
    my $dockerPassw = $args{-dockerPassw};
    my $dockerUserName = $args{-dockerUserName};
    my $dockerInstnaceIp = $args{-dockerInstnaceIp};
    my $dockerImage = $args{-dockerImage};

    $logger->info(__PACKAGE__ . ".$sub_name: dockerHostIp: $dockerHostIp");
    $logger->info(__PACKAGE__ . ".$sub_name: dockerPassw: $dockerPassw");
    $logger->info(__PACKAGE__ . ".$sub_name: dockerUserName: $dockerUserName");
    $logger->info(__PACKAGE__ . ".$sub_name: dockerInstnaceIp: $dockerInstnaceIp");
    $logger->info(__PACKAGE__ . ".$sub_name: dockerImage: $dockerImage");


    my $dockerSession = new SonusQA::Base( -obj_host       => "$dockerHostIp",
                                         -obj_user       => "$dockerUserName",
                                         -obj_password   => "$dockerPassw",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 33300,
                                         -sessionlog => 1,
                                       );
    unless ($dockerSession) {
       $logger->error(__PACKAGE__ . ".$sub_name: Could not open connection to Docker on $dockerHostIp");
       return 0;
     }
    my @output= ();

    unless (@output = $dockerSession->{conn}->cmd("docker container ls -a | grep $dockerInstnaceIp | wc -l") ) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to get check if docker is already running");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    print Dumper(@output);
    foreach my $line (@output) {
	if($line =~ m/"1"/g)
	{
		$logger->error(__PACKAGE__ . ".$sub_name: $dockerInstnaceIp already running");
		return 0;
	}
    } 
    
    unless (@output = $dockerSession->{conn}->cmd("docker ps -aq --no-trunc -f status=exited | xargs docker rm") ) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to delete wrongly terminated dockers");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    print Dumper(@output);
 
    my @startDocker = ();
        unless (@startDocker = $dockerSession->{conn}->cmd("docker run -d --net iptastic --ip $dockerInstnaceIp -it -e VNC_SERVER_PASSWORD=jenkins --user jenkins --privileged --name $dockerInstnaceIp $dockerImage") ) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to create a docker instance with $dockerInstnaceIp");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    print Dumper(@startDocker);

    if(@startDocker == 0)
    {
        $logger->error(__PACKAGE__ . ".$sub_name: Could not start the docker with $dockerInstnaceIp");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }

    return $startDocker[0];
}



=head2 SonusQA::SELENIUM::StopDeleteDockerInstance()

	Sub Routine to stop a given docker instance.
=over

=item Arguments

  -dockerHostIp,-dockerPassw,-dockerUserName,-dockerInstnaceId,-dockerInstanceIp

=item Returns

  Nothing

=back

=cut

sub StopDeleteDockerInstance()
{
    my (%args ) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".StopDeleteDockerInstance");
    my $sub_name = "StopDeleteDockerInstance";
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    #print Dumper(%args);

    my $dockerHostIp = $args{-dockerHostIp};
    my $dockerPassw = $args{-dockerPassw};
    my $dockerUserName = $args{-dockerUserName};
    my $dockerInstnaceId = $args{-dockerInstnaceId};
    my $dockerInstanceIp = $args{-dockerInstanceIp};
    $logger->info(__PACKAGE__ . ".$sub_name: dockerHostIp: $dockerHostIp");
    $logger->info(__PACKAGE__ . ".$sub_name: dockerPassw: $dockerPassw");
    $logger->info(__PACKAGE__ . ".$sub_name: dockerUserName: $dockerUserName");
    $logger->info(__PACKAGE__ . ".$sub_name: dockerInstnaceId: $dockerInstnaceId");
    $logger->info(__PACKAGE__ . ".$sub_name: dockerInstanceIp: $dockerInstanceIp");


    my $dockerSession = new SonusQA::Base( -obj_host       => "$dockerHostIp",
                                         -obj_user       => "$dockerUserName",
                                         -obj_password   => "$dockerPassw",
                                         -comm_type      => 'SSH',
                                         -obj_port       => 22,
                                         -return_on_fail => 1,
                                         -defaulttimeout => 33300,
                                         -sessionlog => 1,
                                       );
    unless ($dockerSession) {
       $logger->error(__PACKAGE__ . ".$sub_name: Could not open connection to Docker on $dockerHostIp");
       return 0;
     }
    my @output= ();

    unless (@output = $dockerSession->{conn}->cmd("docker container stop $dockerInstnaceId") ) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to stop docker $dockerInstnaceId running");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    print Dumper(@output);

    unless (@output = $dockerSession->{conn}->cmd("docker container rm $dockerInstnaceId") ) {
        $logger->error(__PACKAGE__ . ".$sub_name: unable to stop rm $dockerInstnaceId running");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    print Dumper(@output);

    my $url = "http://".$dockerHostIp.":9000/ReleaseDockerIp/".$dockerInstanceIp;
    my ($responcecode,$responcecontent) = SonusQA::Base::restAPI( -url            => $url,
                                                    -contenttype    => 'JSON',
                                                    -method         => 'DELETE',
                                                    -username       => 'admin',
                                                    -password       => 'Sonus@123',
                                                    -arguments      => '');
    $logger->info(__PACKAGE__ . ".$sub_name:responcecode $responcecode");
    $logger->info(__PACKAGE__ . ".$sub_name:responcecontent $responcecontent");
}

=head2 SonusQA::SELENIUM::initialize()

  It open a browser and initialize a GUI session.
  
=item Agruments
    Mandatory: 
                -sourceCodePath: Directory that leads to selenium jar file, the folder must contains selenium.jar and folder driver
                -browser: firefox is recommended. Can input firefox, chrome, ie
                -url: url will be tested
=item Returns
                - $sessionId: session GUI id
                - $localUrl: local url that returned when browser is launched

=item Example:
                my ($sessionId, $localUrl) = $obj->initialize(-sourceCodePath => "D:\\Auto_ATS_Selenium\\selenium", -browser => "firefox", -url => "https://172.29.4.75");
=back

=cut

sub initialize() {

    my ($self , %args ) = @_;
    my $sub_name = "initialize";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-sourceCodePath', '-browser', '-url') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
   
    my @output;
	if (defined($args{-password})) {
	    @output = $self->{conn}->cmd("dir $args{-sourceCodePath}\\selenium.jar");
		my ($windosSide, $atsSide);
		for (@output) {
			if ($_ =~ /[A|P]M\s+(.*) selenium.jar/) {
				$windosSide = $1; 
				$windosSide =~ s/,//g;
				last;
			}
		} 
	    @output = `ls -l /home/$ENV{ USER }/ats_repos/lib/perl/SonusQA/selenium.jar`;
	    my ($atsSide) = $output[0] =~ /(\d+) \w{3} \d{1,2}.*selenium.jar/;	
		   
	   	unless ($windosSide == $atsSide) {
	   		$self->{conn}->cmd("mkdir $args{-sourceCodePath}");
	   		$self->{conn}->cmd("pscp -r -pw $args{-password} $args{-username}\@$args{-ip}:/home/$ENV{ USER }/ats_repos/lib/perl/SonusQA/selenium.jar $args{-sourceCodePath}");
	   	}
	}    
	$self->{conn}->prompt('/.*[\$%\}\|\>\n]\s?$/');
   	$self->{conn}->cmd("cd");
	$self->{conn}->prompt($self->{PROMPT});
   	@output = $self->{conn}->cmd("$args{-sourceCodePath}");
	if (grep/is not recognized/, @output) {
	    unless ($self->{conn}->cmd("cd /d $args{-sourceCodePath}")){
	        $logger->error(__PACKAGE__ . ".$sub_name: Can not go to the source code folder: $args{-sourceCodePath}");
	        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
	        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
	        return 0;
	    }		
	}

    unless (@output = $self->{conn}->cmd("java -jar selenium.jar initialize $args{-browser} $args{-url}")){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to initialize a GUI session ");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    
    foreach (@output) {
        if ($_ =~ /Session ID:\s*(.+)/) {
            $self->{SESSION_ID} = $1;
        }
        if ($_ =~ /Local URL:\s*(.+)/) {
            $self->{LOCAL_URL} = $1;
        }
    }
    
    foreach ($self->{SESSION_ID}, $self->{LOCAL_URL}) {
        unless (defined ($_)) {
            $logger->error(__PACKAGE__ . ".$sub_name: '$_' not defined");
            $flag = 0;
            last;
        }        
    }    

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 SonusQA::SELENIUM::inputText()

  It is used to input text to Element.
  
=item Agruments
    Mandatory: 
                -xPath: xpath of an element
                -text: text to input
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->inputText(-xPath => "//input[\@id='userName']", -text => "admin");
=back

=cut

sub inputText() {

    my ($self , %args ) = @_;
    my $sub_name = "inputText";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath', '-text') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar inputText $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\" \"$args{-text}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Can not input text '$args{-text}' to element '$args{-xPath}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    } 
    
    $logger->info(__PACKAGE__ . ".$sub_name: Input text '$args{-text}' to element '$args{-xPath}' successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::clickElement()

  It is used to Click an element.
  
=item Agruments
    Mandatory: 
                -xPath: xpath of an element
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->clickElement(-xPath => "//button[\@type='submit']");
=back

=cut

sub clickElement() {

    my ($self , %args ) = @_;
    my $sub_name = "clickElement";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
 
    my $cmd = "java -jar selenium.jar clickElement $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Can not click to element '$args{-xPath}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    } 
    
    $logger->info(__PACKAGE__ . ".$sub_name: Click to element '$args{-xPath}' successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::elementShouldExisted()

  It is used to  verify if element located by given locator is existed
  
=item Agruments
    Mandatory: 
                -xPath: xpath of an element
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->elementShouldExisted(-xPath => ".//*[@id='manageElement']/div[2]/h2");
=back

=cut

sub elementShouldExisted() {
    my ($self , %args ) = @_;
    my $sub_name = "elementShouldExisted";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar elementShouldExisted $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Element with xpath: '$args{-xPath}' is not exist ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Element '$args{-xPath}' is exist . ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::elementShouldBeDisplayed()

  It is used to  verify if element located by given locator is displayed. It means style attribute not contains "none" or "hidden"
  
=item Agruments
    Mandatory: 
                -xPath: xpath of an element
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->elementShouldBeDisplayed(-xPath => ".//*[@id='manageElement']/div[2]/h2");
=back

=cut

sub elementShouldBeDisplayed() {
    my ($self , %args ) = @_;
    my $sub_name = "elementShouldBeDisplayed";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar elementShouldBeDisplayed $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Element with xpath: '$args{-xPath}' is not displayed ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Element '$args{-xPath}' is displayed . ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::getText()

  It is used to  get text of an element
  
=item Agruments
    Mandatory: 
                -xPath
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->getText(-xPath => "");
=back

=cut

sub getText() {
    my ($self , %args ) = @_;
    my $sub_name = "getText";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar getText $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    my @output = $self->runSeleniumJar($cmd);
    unless ($output[0]){    
        $logger->error(__PACKAGE__ . ".$sub_name: Getting text of xPath : '$args{-xPath}' is failed ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- -======   ".Dumper(\@output));
    
    my $text;
    foreach (@output) {
        if ($_ =~ /Text is:\s*(.+)/) {
            $text = $1;
            last;
        }
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Completing get text element ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$text]");
    return $text;
}

=head2 SonusQA::SELENIUM::getAttribute()

  It is used to  get attribute value of an element (name, style, value, ...)
  
=item Agruments
    Mandatory: 
                -xPath
                -attribute: such as style, name,...
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->getAttribute(-xPath => "", -attribute => "");
=back

=cut

sub getAttribute() {
    my ($self , %args ) = @_;
    my $sub_name = "getAttribute";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath', '-attribute') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar getAttribute $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\" \"$args{-attribute}\"";
    my @output = $self->runSeleniumJar($cmd);
    unless ($output[0]){     
        $logger->error(__PACKAGE__ . ".$sub_name: Getting attribute of xPath : '$args{-xPath}' is failed ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $attrValue;
    foreach (@output) {
        if ($_ =~ /Attribute value is:\s*(.+)/) {
            $attrValue = $1;
            last;
        }
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Completing get attribute element ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$attrValue]");
    return $attrValue;
}

=head2 SonusQA::SELENIUM::acceptConfirmation()

  It is used to  handle confirmation alert
  
=item Agruments
    Mandatory: 
                -alertText
                -confirm: true - accept , false - cancel
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->acceptConfirmation(-alertText => "", -confirm => "");
=back

=cut

sub acceptConfirmation() {
    my ($self , %args ) = @_;
    my $sub_name = "acceptConfirmation";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-alertText', '-confirm') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar acceptConfirmation $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-alertText}\" \"$args{-confirm}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot do confirm '$args{-confirm}' for alert '$args{-alertText}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Do confirm '$args{-confirm}' for alert '$args{-alertText}' successfully. ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::elementEnable()

  It is used to  Check if element is enable
  
=item Agruments
    Mandatory: 
                -xPath
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->elementEnable(-xPath => "");
=back

=cut

sub elementEnable() {
    my ($self , %args ) = @_;
    my $sub_name = "elementEnable";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar elementEnable $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    my @output = $self->runSeleniumJar($cmd);
    unless ($output[0]){      
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot check elment is enable or not");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $result;
    foreach (@output) {
        if ($_ =~ /Check if element enable or not returns:\s*(.+)/) {
            $result = $1;
        }
    }
    if ($result eq "false") { # result = true or false
        $flag = 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Completing do check element is enable or not . ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 SonusQA::SELENIUM::elementIsSelected()

  It is used to  To check if checkbox is seleted or not
  
=item Agruments
    Mandatory: 
                -xPath
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->elementIsSelected(-xPath => "");
=back

=cut

sub elementIsSelected() {
    my ($self , %args ) = @_;
    my $sub_name = "elementIsSelected";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar elementIsSelected $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    my @output = $self->runSeleniumJar($cmd);
    unless ($output[0]){     
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot check elment is select or not");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $result;
    foreach (@output) {
        if ($_ =~ /Check if checkbox is check or not:\s*(.+)/) {
            $result = $1;
        }
    }
    if ($result eq "false") { # result = true or false
        $flag = 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Completing do check element is select or not . ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 SonusQA::SELENIUM::checkCSSValue()

  It is used to  check if value of css attribute is correct or not
  
=item Agruments
    Mandatory: 
                -xPath
                -cssAttribute
                -cssValue
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->checkCSSValue(-xPath => "", -cssAttribute => "", -cssValue => "");
=back

=cut

sub checkCSSValue() {
    my ($self , %args ) = @_;
    my $sub_name = "checkCSSValue";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath', '-cssAttribute', '-cssValue') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar checkCSSValue $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\" \"$args{-cssAttribute}\" \"$args{-cssValue}\"";
    my @output = $self->runSeleniumJar($cmd);
    unless ($output[0]){   
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot check value of css attribute element");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $result;
    foreach (@output) {
        if ($_ =~ /Value of css attribute is:\s*(.+)/) {
            $result = $1;
        }
    }
    if ($result eq "false") { # result = true or false
        $flag = 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Completing check value of css attribute element");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$flag]");
    return $flag;
}

=head2 SonusQA::SELENIUM::mouseHover()

  It is used to  Mouse hover to element located by given locator
  
=item Agruments
    Mandatory: 
                -xPath
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->mouseHover(-xPath => "");
=back

=cut

sub mouseHover() {
    my ($self , %args ) = @_;
    my $sub_name = "mouseHover";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar mouseHover $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Can not mouse hover to element");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Mouse hover to element successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::selectByVisibleText()

  It is used to  Select dropdown list by visible text
  
=item Agruments
    Mandatory: 
                -xPath
                -visibleText
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->selectByVisibleText(-xPath => "", -visibleText => "");
=back

=cut

sub selectByVisibleText() {
    my ($self , %args ) = @_;
    my $sub_name = "selectByVisibleText";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath', '-visibleText') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar selectByVisibleText $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\" \"$args{-visibleText}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot select text '$args{-visibleText}' in element '$args{-xPath}' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Select text '$args{-visibleText}' successfully. ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::selectByValue()

  It is used to  Select dropdown list by value
  
=item Agruments
    Mandatory: 
                -xPath
                -value
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->selectByValue(-xPath => "", -value => "");
=back

=cut

sub selectByValue() {
    my ($self , %args ) = @_;
    my $sub_name = "selectByValue";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath', '-value') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar selectByValue $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\" \"$args{-value}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot select '$args{-value}' in dropdown list ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Select  '$args{-value}' in dropdown list successfully. ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::selectByIndex()

  It is used to   Select dropdown list by index
  
=item Agruments
    Mandatory: 
                -xPath
                -index
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->selectByIndex(-xPath => "", -index => "");
=back

=cut

sub selectByIndex() {
    my ($self , %args ) = @_;
    my $sub_name = "selectByIndex";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath', '-index') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar selectByIndex $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\" \"$args{-index}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot select element '$args{-index}' in dropdown list ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Select element  '$args{-index}' in dropdown list successfully. ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::getSelectedValueOfDropdown()

  It is used to   get the selected label 
  
=item Agruments
    Mandatory: 
                -xPath
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->getSelectedValueOfDropdown(-xPath => "");
=back

=cut

sub getSelectedValueOfDropdown() {
    my ($self , %args ) = @_;
    my $sub_name = "getSelectedValueOfDropdown";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar getSelectedValueOfDropdown $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    my @output = $self->runSeleniumJar($cmd);
    unless ($output[0]){      
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot get selected value in dropdown list ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- -======   ".Dumper(\@output));
     
    my $value;
    foreach (@output) {
        if ($_ =~ /Value is:\s*(.+)/) {
            $value = $1;
            last;
        }
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Completing getSelectedValueOfDropdown");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$value]");
    return $value;
}

=head2 SonusQA::SELENIUM::getCurrentWindow()

  It is used to  get current window
  
=item Agruments

=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->getCurrentWindow();
=back

=cut

sub getCurrentWindow() {
    my ($self , %args ) = @_;
    my $sub_name = "getCurrentWindow";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $cmd = "java -jar selenium.jar getCurrentWindow $self->{SESSION_ID} $self->{LOCAL_URL}";
    my @output = $self->runSeleniumJar($cmd);
    unless ($output[0]){    
        $logger->error(__PACKAGE__ . ".$sub_name: Getting currentWindow is failed ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $currentWindow;
    foreach (@output) {
        if ($_ =~ /The current windows handle is:\s*(.+)/) {
            $currentWindow = $1;
            last;
        }
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Completing get current Window ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$currentWindow]");
    return $currentWindow;
}

=head2 SonusQA::SELENIUM::moveToWindowByName()

  It is used to  move to a given window name
  
=item Agruments
                -windowName: name of window
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->moveToWindowByName(-windowName => "");
=back

=cut

sub moveToWindowByName() {
    my ($self , %args ) = @_;
    my $sub_name = "moveToWindowByName";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-windowName') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar moveToWindowByName $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-windowName}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot move to window name:  '$args{-windowName}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Move to window name:  '$args{-windowName}' successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::moveToFirstWindows()

  It is used to  Moving back to the first window.
  
=item Agruments

=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->moveToFirstWindows();
=back

=cut

sub moveToFirstWindows() {
    my ($self , %args ) = @_;
    my $sub_name = "moveToFirstWindows";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $cmd = "java -jar selenium.jar moveToFirstWindows $self->{SESSION_ID} $self->{LOCAL_URL}";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot move to first window ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Move to first window! ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::checkPageTitle()

  It is used to  check page title is correct or not.
  
=item Agruments
    Mandatory: 
                -title: page title
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->checkPageTitle(-title => "");
=back

=cut

sub checkPageTitle() {
    my ($self , %args ) = @_;
    my $sub_name = "checkPageTitle";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-title') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar checkPageTitle $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-title}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot check page title:  '$args{-title}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Check page title :  '$args{-title}' successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::scrollToElement()

  It is used to  scroll to an element
  
=item Agruments
    Mandatory: 
                -xPath: xpath of an element
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->scrollToElement(-xPath => ".//*[@id='manageElement']/div[2]/h2");
=back

=cut

sub scrollToElement() {
    my ($self , %args ) = @_;
    my $sub_name = "scrollToElement";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar scrollToElement $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to Scroll to Element '$args{-xPath}' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Scroll to Element '$args{-xPath}' successfully . ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::switchToFrameIndex()

  It is used to  Switch to frame by locator and frame index
  
=item Agruments
    Mandatory: 
                -xPath: xpath of frame
                -index
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->switchToFrameIndex(-xPath => ".//*[@id='manageElement']/div[2]/h2", -index => "");
=back

=cut

sub switchToFrameIndex() {
    my ($self , %args ) = @_;
    my $sub_name = "switchToFrameIndex";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath', '-index') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar switchToFrameIndex $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\" \"$args{-index}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to switch to frame '$args{-xPath}' index '$args{-index}' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Switch to frame '$args{-xPath}' successfully . ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::switchToFrameName()

  It is used to  Switch to frame by locator and frame name
  
=item Agruments
    Mandatory: 
                -xPath: xpath of frame
                -name
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->switchToFrameName(-xPath => ".//*[@id='manageElement']/div[2]/h2", -name => "");
=back

=cut

sub switchToFrameName() {
    my ($self , %args ) = @_;
    my $sub_name = "switchToFrame";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-name') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar switchframe $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-name}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to switch to frame '$args{-name}' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Switch to frame '$args{-name}' successfully . ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::switchTodefaultContent()

  It is used to   Switch to default content frame
  
=item Agruments

=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->switchTodefaultContent();
=back

=cut

sub switchTodefaultContent() {
    my ($self , %args ) = @_;
    my $sub_name = "switchTodefaultContent";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");


    my $cmd = "java -jar selenium.jar switchTodefaultContent $self->{SESSION_ID} $self->{LOCAL_URL}";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to switch to default frame ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Switch to default frame successfully . ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::takeScreenshot()

  It is used to  take a screenshot and transfer file to ATS logs
  
=item Agruments
    Mandatory: 
                -path: path to save img
                -ip: ATS ip
                -username: username login to ATS
                -password
                
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->takeScreenshot(-path => $Image_Path, -ip => $ats_ip, -username => $ats_usrname, -password => $ats_passwd);
=back

=cut

sub takeScreenshot() {
    my ($self , %args ) = @_;
    my $sub_name = "takeScreenshot";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-path', '-ip', '-username', '-password') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $cmd = "java -jar selenium.jar takeScreenshot $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-path}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to Take screenshot ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }      
    
    my $locallogname = $main::log_dir;
    # Transfer img file to ats logs
	my $cmd = "echo y | pscp -pw $args{-password} $args{-path} $args{-username}\@$args{-ip}:$locallogname";
    unless (/No such file or directory|unable to open/, $self->{conn}->cmd($cmd)) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to transfer img file to ATS logs");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
	
    unless ($self->{conn}->cmd("del $args{-path}")) {
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to delete img file in window server");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Take screenshot and transfer to ATS log successfully. ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::inspect()

  This is used to define an element is exist/not exist/isDisplayed/isEnabled/isSelected .
  It also is used to get class, get text or get size of a given xpath.
  
=item Agruments
    Mandatory: 
                -action: validate/ checknotexist/ gettext/ getclass/ getsize/ isdisplayed/ isenable/ isselected
                -xPath: xpath of an element
                
=item Returns
                - 0 if success
                - 1 if failed

=item Example:
                $obj->inspect(-action => "validate", -xPath => "//input[\@name='j_username']");
=back

=cut

sub inspect() {

    my ($self , %args ) = @_;
    my $sub_name = "inspect";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-action', '-xPath') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $result = 1;    
    my @output;
    my $cmd = "java -jar selenium.jar inspect $self->{SESSION_ID} $self->{LOCAL_URL} $args{-action} \"$args{-xPath}\"";
    @output = $self->runSeleniumJar($cmd);
    unless ($output[0]){    
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to $args{-action}  for xPath: $args{-xPath}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }        

    if ($args{-action} eq 'checknotexist') {
        unless (grep /Element not found/, @output) {
            $result = 0;
            $logger->error(__PACKAGE__ . ".$sub_name: Found the element. Expected: NOT FOUND ");
        }
    } else {
        unless ($output[0]) {
            $result = 0;
            $logger->error(__PACKAGE__ . ".$sub_name: Can not $args{-action} the element");
        }
    }
    
    if ($result == 1) {
        $logger->info(__PACKAGE__ . ".$sub_name: Check $args{-action} for '$args{-xPath}' element is success!!! ");
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$result]");
    return $result;
}

=head2 SonusQA::SELENIUM::keyboard()

  This is used to sendKey/ selectVisiableText 
  It also is used to get attribute, get css value of  a given xpath.
  
=item Agruments
    Mandatory: 
                -action: sendkey/ selectvisiabletext/ getattribute/ getcssvalue
                -xPath: xpath of an element
                -value: the value input from keyboard
                
=item Returns
                - 0 if success
                - 1 if failed

=item Example:
                $obj->keyboard(-action => "sendkey", -xPath => "//input[\@name='j_username']", -value => "sysadmin");
=back

=cut

sub keyboard() {

    my ($self , %args ) = @_;
    my $sub_name = "keyboard";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-action', '-xPath', '-value') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $cmd = "java -jar selenium.jar keyboard $self->{SESSION_ID} $self->{LOCAL_URL} $args{-action} \"$args{-xPath}\" \"$args{-value}\"";
    unless ($self->runSeleniumJar($cmd)){    
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to $args{-action}  for xPath: $args{-xPath}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Did $args{-action}  for xPath: $args{-xPath} successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::mouse()

  This is used to click/ clear/ submit/ quit an element 
  
=item Agruments
    Mandatory: 
                -action: click/ clear/ submit/ quit
                -xPath: xpath of an element
                
=item Returns
                - 0 if success
                - 1 if failed

=item Example:
                $obj->mouse(-action => "sendkey", -xPath => "//input[\@name='j_username']");
=back

=cut

sub mouse() {

    my ($self , %args ) = @_;
    my $sub_name = "mouse";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-action', '-xPath') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    
    my $cmd = "java -jar selenium.jar mouse $self->{SESSION_ID} $self->{LOCAL_URL} $args{-action} \"$args{-xPath}\"";
    unless ($self->runSeleniumJar($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to do $args{-action}  for xPath: $args{-xPath}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Did $args{-action}  for xPath: $args{-xPath} successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");
    return 1;
}


=head2 SonusQA::SELENIUM::quit()

  Quit the current session if no input is provided 
  or to close a browser window if -closeWindow is provided
  
=item Agruments

  optional : 
    -closeWindow

=item Returns
                - 0 if success
                - 1 if failed

=item Example:
                $obj->quit();
                $obj->quit(-closeWindow => "yes");
=back

=cut

sub quit() {

    my ($self , %args ) = @_;
    my $sub_name = "quit";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my $type_of_execution = (lc $args{-closeWindow} eq "yes") ? "close" : "quit";

	my $cmd = "java -jar selenium.jar quit $self->{SESSION_ID} $self->{LOCAL_URL} $type_of_execution";
    unless ($self->runSeleniumJar($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to perform $type_of_execution action ");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub_name: Perform $type_of_execution action successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [1]");    
}

=head2 SonusQA::SELENIUM::runSeleniumJar()

  This is used in every function to run selenium.jar file.
  
=item Agruments

    Mandatory: 
                $cmd: command input from other wrapper functions.

=item Returns
                - 0 if failed
                - command output if passed

=item Example:
                $obj->runSeleniumJar($cmd);
=back

=cut

sub runSeleniumJar() {
    my ($self, $cmd) = @_;
    my $sub_name = "runSeleniumJar";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");
    
    my @output;
    unless (@output = $self->{conn}->cmd($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to execute '$cmd' ");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }    
    
    if (grep/ERROR|Exception/, @output){
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub. [0]");
        return 0;
    }  

    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return @output;
}

=head2 SonusQA::SELENIUM::javaScriptExeClick()

  This helps to click web elements using JavaScript.
  
=item Agruments

    Mandatory: 
                -xPath 

=item Returns
                - 0 (fail)
                - 1 (pass)

=item Example:
                $obj->javaScriptExeClick(-xPath => "");
=back

=cut

sub javaScriptExeClick() {

    my ($self , %args ) = @_;
    my $sub_name = "javaScriptExeClick";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar javaScriptExeClick $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    unless ($self->runSeleniumJar($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Can not click element '$args{-xPath}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Click element '$args{-xPath}' successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;    
}

=head2 SonusQA::SELENIUM::switchToFrameElement()

  It is used to Switch to frame by locator and frame element
  
=item Agruments
    Mandatory: 
                -xPath: xpath of frame
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->switchToFrameElement(-xPath => ".//*[@id='manageElement']/div[2]/h2");
=back

=cut

sub switchToFrameElement() {

    my ($self , %args ) = @_;
    my $sub_name = "switchToFrameElement";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar switchToFrameElement $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    unless ($self->runSeleniumJar($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Failed to switch to frame '$args{-xPath}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: Switch to frame '$args{-xPath}' successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::moveToWindowByIndex()

  It is used to move to window with particular index.
  
=item Agruments
    Mandatory: 
                -sessionId: Session Id  is returned from 'initialize' subroutine
                -localUrl: Local Url is returned from 'initialize' subroutine
                -index: index of 
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->moveToWindowByIndex(-sessionId => "", -localUrl => "", -index => "");
=back

=cut

sub moveToWindowByIndex() {

    my ($self , %args ) = @_;
    my $sub_name = "moveToWindowByIndex";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-index') {
        unless (defined $args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar moveToWindowByIndex $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-index}\"";
    unless ($self->runSeleniumJar($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Cannot move to window indexed '$args{-index}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Move to window indexed '$args{-index}' successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;
}

=head2 SonusQA::SELENIUM::rightClick()

  It is used to perform right-lick on an element.
  
=item Agruments
    Mandatory: 
                -xPath: xpath of an element
=item Returns
                - 1: if passed
                - 0: if failed

=item Example:
                $obj->rightClick(-xPath => "//button[\@type='submit']");
=back

=cut

sub rightClick() {

    my ($self , %args ) = @_;
    my $sub_name = "rightClick";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar rightClick $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    unless ($self->runSeleniumJar($cmd)){
        $logger->error(__PACKAGE__ . ".$sub_name: Can not perform righ-click on element '$args{-xPath}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving sub [0]");
        return 0;
    }

    $logger->info(__PACKAGE__ . ".$sub_name: Perform righ-click on element '$args{-xPath}' successfully");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
    return 1;    
}

=head2 SonusQA::SELENIUM::tableRowCol()

  Get number of rows/column of a table.
  
=item Agruments
    Mandatory: 
                -xPath: xpath of an element
=item Returns
                - number of rows/columns: if passed
                - 0: if failed

=item Example:
                $obj->tableRowCol(-xPath => "//input[\@id='userName']");
=back

=cut

sub tableRowCol() {

    my ($self , %args ) = @_;
    my $sub_name = "tableRowCol";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->info(__PACKAGE__ . ".$sub_name: --> Entered Sub");

    my $flag = 1;
    foreach ('-xPath') {
        unless ($args{$_}) {
            $logger->error(__PACKAGE__ . ".$sub_name: Mandatory parameter '$_' not present");
            $flag = 0;
            last;
        }
    }
    
    if ($flag == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }

    my $cmd = "java -jar selenium.jar tableRowCol $self->{SESSION_ID} $self->{LOCAL_URL} \"$args{-xPath}\"";
    my @output = $self->runSeleniumJar($cmd);
    unless ($output[0]){    
        $logger->error(__PACKAGE__ . ".$sub_name: Can not get size of table with element '$args{-xPath}'");
        $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
        return 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- -======   ".Dumper(\@output));

    my $text;
    foreach (@output) {
        if ($_ =~ /tableRowCol completed. Result:\s*(.+)/) {
            $text = $1;
            last;
        }
    }
    
    $logger->info(__PACKAGE__ . ".$sub_name: get size of table with element '$args{-xPath}' successfully ");
    $logger->debug(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [$text]");
    return $text;
}


1;
