package SonusQA::DSICLI;

=pod

=head1 NAME

 SonusQA::DSICLI - Perl module for DSI CLI interaction

=head1 SYNOPSIS

 use ATS;  # This is the base class for Automated Testing Structure
 my $obj = SonusQA::DSICLI->new(
                              #REQUIRED PARAMETERS
                              -OBJ_HOST => '<host name | IP Adress>',
                              -OBJ_USER => '<cli user name - usually admin>',
                              -OBJ_PASSWORD => '<cli user password>',
                              -OBJ_COMMTYPE => "<TELNET | SSH>",
                              -OBJ_NODETYPE => "<PMNODE|MNODE|CNODE>",
			            []   
                              # OPTIONAL PARAMETERS:
                              -OBJ_MAINTMODE => <1|0>       # Default is 1 or ON, maintenance mode will be switch on/off pre/post commands
                              );
 PARAMETER DESCRIPTIONS:
    OBJ_HOST
      The connection address for this object.  Typically this will be a resolvable (DNS) host name or a specific IP Address.
    OBJ_USER
      The user name or ID that is used to 'login' to the device. 
    OBJ_PASSWORD
      The user password that is used to 'login' to the device. 
    OBJ_COMMTYPE
      The session or connection type that will be established.
    OBJ_NODETYPE
      The session or connection node type that will be established.  This is most likely OUT-OF-DATE
 FLAGS:
    OBJ_MAINTMODE
      This will enable/disable a call to set maint mode on or off pre-command execution.

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::Utilities::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

 This module provides an interface for the DSI CLI. It provides methods for both postive and negative testing, most cli methods returning true or false (0|1).
 Control of command input is up to the QA Engineer implementing this class, must methods accept a key/value hash, allowing the engineer to specific which 
 attributes to use.  Complete examples are given for each method.

=head1 AUTHORS

 Darren Ball <dball@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>. See Inline documentation for contributors.

=head1 ISA

 SonusQA::Base, SonusQA::DSICLI::DSICLIHELPER

=head1 SUB-ROUTINES

=cut


use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use warnings;
#use diagnostics;

use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use Module::Locate qw / locate /;

require SonusQA::DSICLI::DSICLIHELPER;

our $VERSION = "1.0";
use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::DSICLI::DSICLIHELPER);


=pod

=head1 B<doInitialization>

  Base module over-ride.  Object session specific initialization.  Object session initialization function that is called automatically,
  use to set Object specific flags, paths, and prompts.

=over 6

=item Arguments

  NONE 

=item Returns

  NOTHING   

=back

=cut

sub doInitialization {
    my($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
    $self->{COMMTYPES} = ["TELNET", "SSH"];
    $self->{OBJ_NODETYPE} = "PMNODE";
    $self->{TYPE} = "DSICLI";
    $self->{conn}		= undef;
    $self->{PROMPT} = '/Sonus.*CLI.*\>/i';  #Sonus CLI (leafs)>  
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
    $logger->info(__PACKAGE__ . ". the prompt is :: \'$self->{PROMPT}\'"); 
    
}

sub setSystem {

    my ( $self ) = @_ ;
    my $sub = "setSystem" ;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
    $logger->debug(__PACKAGE__ . ".$sub : --> Entered Sub");

    $self->{conn}->cmd("bash");
    $self->{conn}->cmd("");
    $logger->info(__PACKAGE__ . ".$sub : Executing command \'stty rows 1000\'");
    $self->{conn}->cmd("stty rows 1000");
    $self->{conn}->cmd("");
    $self->{conn}->cmd("su - cli") ;
    $logger->info(__PACKAGE__ . ". the prompt is :: \'$self->{PROMPT}\'");

    $logger->debug(__PACKAGE__ . ".$sub : <-- Leaving Sub [1]");
    return 1 ;
}


sub execCmd {  
  my ($self,$cmd)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  my(@cmdResults,$timestamp);
  #cmdResults = $self->{conn}->cmd($cmd);
  #return @cmdResults;
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd");
  $timestamp = $self->getTime();
  unless (@cmdResults = $self->{conn}->cmd(String =>$cmd, Timeout=>600 )) {
    $logger->debug(__PACKAGE__ . ".execCmd  errmsg: " . $self->{conn}->errmsg);
    $logger->debug(__PACKAGE__ . ".execCmd  Session Dump Log is : $self->{sessionLog1}");
    $logger->debug(__PACKAGE__ . ".execCmd  Session Input Log is: $self->{sessionLog2}");
    if ((grep /AMA.*CLI.*Error/is, @cmdResults) || (grep /Error.*near/is, @cmdResults)){  # this means there was an error, and the error has the CLI hung.
      #
      #print map { __PACKAGE__ . ".execCmd\t\t$_" } @cmdResults;
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      $logger->warn(__PACKAGE__ . ".execCmd  DSI CLI HANG DETECTED");
      $logger->warn(__PACKAGE__ . ".execCmd  AMA CLI ERROR DETECTED, CMD ISSUED WAS:");
      $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
      $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
      chomp(@cmdResults);
      map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      &error(__PACKAGE__ . ".execCmd DSI CLI ERROR - EXITING");
    }else{ # this means there was an error, there is no error message displayed, and the CLI has hung
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      $logger->warn(__PACKAGE__ . ".execCmd  DSI CLI HANG DETECTED");
      $logger->warn(__PACKAGE__ . ".execCmd  DSI CLI HAS HUNG, CMD ISSUED WAS: ");
      $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
      $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
      my $promptFlag = 0; my $cnt = 0;
      my @totalErrResults = ();
      push(@totalErrResults,"INTIAL CMD RESULTS:");
      push(@totalErrResults,@cmdResults);
      my @errResults = ();
      while(!$promptFlag && $cnt <5) {
	@errResults = $self->{conn}->cmd("") or do {
	  $logger->debug(__PACKAGE__ . ".execCmd  Attempt to return to prompt failed [$cnt]");
	  $cnt++;
	  push(@totalErrResults,"ATTEMPT TO RETURN TO PROMPT: $cnt");
	  push(@totalErrResults,@errResults);
	  next;
	};
	push(@totalErrResults,"ATTEMPT TO RETURN TO PROMPT [SUCCESS]: $cnt");
	push(@totalErrResults,@errResults);
	$promptFlag =1;
      }
      if($cnt == 5){ 
	
	print map { __PACKAGE__ . ".execCmd\t\t$_" } @totalErrResults;
	$logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
	$logger->warn(__PACKAGE__ . ".execCmd  FINAL: ERROR CLI FAILED TO RETURN ");
	$logger->warn(__PACKAGE__ . ".execCmd  ATTEMPTED $cnt TIMES TO RETURN TO CLI");
	$logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
	chomp(@totalErrResults);
	map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @totalErrResults;
	$logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
	&error(__PACKAGE__ . ".execCmd DSI CLI SEEMS TO HAVE HUNG - CAN NOT REGAIN CLI");
      }else{
	
	print map { __PACKAGE__ . ".execCmd\t\t$_" } @totalErrResults;
	
	$logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
	$logger->warn(__PACKAGE__ . ".execCmd  DSI CLI ERROR, NO ERROR MESSAGE DETECTED");
	$logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
	chomp(@totalErrResults);
	map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @totalErrResults;
	$logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
	&error(__PACKAGE__ . ".execCmd DSI CLI ERROR, NO ERROR MESSAGE DETECTED");
      }
    }
  };
  if ((grep /AMA.*CLI.*Error/is, @cmdResults) || (grep /Error.*near/is, @cmdResults)){
    
    #print map { __PACKAGE__ . ".execCmd\t\t$_" } @cmdResults;
    
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    $logger->warn(__PACKAGE__ . ".execCmd  AMA CLI ERROR DETECTED, CMD ISSUED WAS:");
    $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
    $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
    chomp(@cmdResults);
    map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    &error(__PACKAGE__ . ".execCmd DSI CLI CMD ERROR - EXITING");
  }
  chomp(@cmdResults);
  if($#cmdResults == 0){
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    $logger->warn(__PACKAGE__ . ".execCmd  AMA CLI POSSIBLE ERROR DETECTED, CMD ISSUED WAS:");
    $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
    $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS WERE EMPTY - CLI MAY HAVE HUNG OR NOT RETURNED");
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
  }
  chomp(@cmdResults);
  @cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array
  push(@{$self->{HISTORY}},"$timestamp :: $cmd");
  return @cmdResults;
}

sub system_shutdown_ECLI {
       
  my ($self)=@_;
  my ($cmd,$flag);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".system_shutdown");

  $flag = 1; # Assume cmd will pass  
  my @cmdResults = $self->execCmd("system shutdown all");
  $logger->info(__PACKAGE__ . ".system_shutdown  CMD RESULTS: @cmdResults   ");
  return $flag;
}

sub system_startup_ECLI {

  my ($self)=@_;
  my ($cmd,$flag,@cmdResults);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".system_startup");

  $flag = 1; # Assume cmd will pass
  @cmdResults = $self->execCmd("system startup all");
  $logger->info(__PACKAGE__ . ".system_startup  CMD RESULTS: @cmdResults ");
  return $flag;
}

sub system_reload_ECLI {

  my ($self)=@_;
  my ($cmd,$flag,@cmdResults);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".system_reload");

  $flag = 1; # Assume cmd will pass
  @cmdResults = $self->execCmd("system reload all");
  $logger->info(__PACKAGE__ . ".system_reload  CMD RESULTS: @cmdResults   ");
  return $flag;
}

sub tail_logs {
  my ($cmd,@cmdResults);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".tail_logs");
  $cmd = "hostname";
    @cmdResults = ($self->print("hostname"));
   print "\n ##### @cmdResults #####   \n";

}


sub verifyLicenseLevel {
  my ($self,$licenselevel)=@_;
  my ($cmd,,$flag,@cmdResults);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyLicenseLevel");
  
  unless(defined($licenselevel)){
    $logger->warn(__PACKAGE__ . ".verifyLicenseLevel  ARGUMENT MISSING.  PLEASE PROVIDE LICENSE LEVEL");
    return 0;
  };
  
  $cmd = "show license";
  if($self->{MAINTMODE}){
    $self->setMaintLevel("on");
  }
  $flag = 0; # Assume cmd will fail
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".verifyLicenseLevel  CMD RESULTS:");
  foreach(@cmdResults) {
    if(m/$licenselevel.*enabled/i){
      $logger->info(__PACKAGE__ . ".verifyLicenseLevel  $_ (VERIFIED LICENSE)");
      $flag = 1;
      next;
    }
    $logger->info(__PACKAGE__ . ".verifyLicenseLevel  $_");
  }
  if($self->{MAINTMODE}){
    $self->setMaintLevel("off");
  }
  return $flag;
}



#################### Show License Level for Enhanced CLI #######################

sub showLicenseLevel_ECLI {
    my ($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".showLicenseLevel_ECLI");
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string

    $cmd = "license show";
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".showLicenseLevel_ECLI  CMD RESULTS:");
    foreach(@cmdResults) {
        if($_ !~ m//i){
            $logger->debug(__PACKAGE__ . ".showLicenseLevel_ECLI  $_ and value for flag is $flag");
            $flag = 0;
            next;
        }
        $logger->debug(__PACKAGE__ . ".showLicenseLevel_ECLI  $_ and value for flag is $flag");
    }
    return @cmdResults;
}


#################### Show Opmode for Enhanced CLI #######################

sub showOpmode_ECLI {
    my ($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".showOpmode_ECLI");
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string

    $cmd = "license opmode show";
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".showOpmodes_ECLI CMD RESULTS:");
    foreach(@cmdResults) {
        if($_ !~ m//i){
            $logger->debug(__PACKAGE__ . ".showOpmode_ECLI  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".showOpmode_ECLI  $_");
    }
    return @cmdResults;
}



################### Verification Of Opmode for Legacy CLI ########################

sub verifyOpmode {
  my ($self,$opmode)=@_;
  my ($cmd,$flag,@cmdResults);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyOpmode");
  
  unless(defined($opmode)){
    $logger->warn(__PACKAGE__ . ".verifyOpmode  ARGUMENT MISSING.  PLEASE PROVIDE OPMODE");
    return 0;
  };
  
  $cmd = "show opmode";
  if($self->{MAINTMODE}){
    $self->setMaintLevel("on");
  }
  $flag = 0; # Assume cmd will fail
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".verifyOpmode  CMD RESULTS:");
  foreach(@cmdResults) {
    chomp($_);
    if(m/^$opmode.*:.*on/i){
      $logger->info(__PACKAGE__ . ".verifyOpmode  $_ (VERIFIED OPMODE)");
      $flag = 1;
      next;
    }
    $logger->info(__PACKAGE__ . ".verifyOpmode  $_");
  }
  if($self->{MAINTMODE}){
    $self->setMaintLevel("off");
  }
  return $flag;
}

################### Verification Of Opmode for Enhanced CLI ########################

sub verifyOpmode_ECLI {
  my ($self,$opmode)=@_;
  my ($cmd,$flag,@cmdResults);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyOpmode_ECLI");

  unless(defined($opmode)){
    $logger->warn(__PACKAGE__ . ".verifyOpmode  ARGUMENT MISSING.  PLEASE PROVIDE OPMODE");
    return 0;
  };

  $cmd = "license opmode show";
  $flag = 0; # Assume cmd will fail
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".verifyOpmode_ECLI  CMD RESULTS:");
  foreach(@cmdResults) {
    chomp($_);
    if(m/^$opmode.*:.*on/i){
      $flag = 1;
      $logger->info(__PACKAGE__ . ".verifyOpmode_ECLI $_");
    }
  }

  return $flag;
}

########### Verification Of License Level for Enhanced CLI #####################

sub verifyLicenseLevel_ECLI {
  my ($self,$licenselevel)=@_;
  my ($cmd,$flag,@cmdResults);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyLicenseLevel for ECLI");

  unless(defined($licenselevel)){
    $logger->warn(__PACKAGE__ . ".verifyLicenseLevel_ECLI  ARGUMENT MISSING.  PLEASE PROVIDE LICENSE LEVEL");
    return 0;
  };

  $cmd = "license show";
  $flag = 0; # Assume cmd will fail
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".verifyLicenseLevel_ECLI  CMD RESULTS:");
  $logger->info(__PACKAGE__ . ".verifyLicenseLevel _ECLI License to be verified : $licenselevel");
  foreach(@cmdResults) {
    if(m/$licenselevel.*enabled/i){
      $flag = 1;
      $logger->info(__PACKAGE__ . ".verifyLicenseLevel_ECLI  $licenselevel: (VERIFIED LICENSE)");
    }else {
      $logger->info(__PACKAGE__ . ".verifyLicenseLevel_ECLI  $licenselevel: (LICENSE MISSING)");
    }
  }

  return $flag;
}




sub verifyFSsrc {
  my ($self,$id)=@_;
  my ($cmd,$flag,@cmdResults);
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyFSsrc");
  
  unless(defined($id)){
    $logger->warn(__PACKAGE__ . ".verifyFSsrc  ARGUMENT MISSING.  PLEASE PROVIDE SOURCE IDENTIFIER");
    return 0;
  };
  
  $cmd = "show fileservices source";
  if($self->{MAINTMODE}){
    $self->setMaintLevel("on");
  }
  $flag = 0; # Assume cmd will fail
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".verifyFSsrc  CMD RESULTS:");
  foreach(@cmdResults) {
    chomp($_);
    if(m/^$id/i){
      $logger->info(__PACKAGE__ . ".verifyFSsrc  $_ (VERIFIED FS SOURCE)");
      $flag = 1;
      next;
    }
  }
  if($self->{MAINTMODE}){
    $self->setMaintLevel("off");
  }
  return $flag;
}
# CREATE/ADD ROUTINES FOR CLI
# ------------------------

=head1 B<createAdbi(KEYVALUEPAIRS)>

  Method to create ancillary database interface.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.
  Example: 
    $dsicli->createAdbi({<key> => "<value>",
		         ...
		        }
		       );  
  CLI COMMAND (V06.01.03R002):
  create adbi [name|active|configfile] <value>

=cut

# ROUTINE: createAdbi
# Purpose: To create a neew ancillary database interface
# create adbi name <name> active <0|1> configfile <fullpath/filename>
sub createAdbi {
  my ($self,$keyVals)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createAdbi");
  if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
    $logger->warn(__PACKAGE__ . ".createAdbi  MUST PERFORM THIS FUNCTION ON MNODE");
    return 0;
  }
  unless(defined($keyVals)){
    $logger->warn(__PACKAGE__ . ".createAdbi  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
    
    return 0;
  };
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
  # build command string
  foreach $key (keys %$keyVals) {
    #print "$key => $$keyVals{$key}\n";
    $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
  }
  $cmd = sprintf("create adbi %s ",$cmdTmp);
  if($self->{MAINTMODE}){
    $self->setMaintLevel("on");
  }
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".createAdbi  CMD RESULTS:");
  foreach(@cmdResults) {
    if(!m//i){
      $logger->warn(__PACKAGE__ . ".createAdbi  $_");
      $flag = 0;
      next;
    }
    $logger->info(__PACKAGE__ . ".createAdbi  $_");
    
  }
  if($self->{MAINTMODE}){
    $self->setMaintLevel("off");
  }
  return $flag;
}

=head1 B<createDm(ID, KEYVALUEPAIRS)>

  Method to create data manager interface.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.
  Example: 
    $dsicli->createDm({<key> => "<value>",
		     ...
		     }
		    );  
  CLI COMMAND (V06.01.03R002):
  create dm[1-4] host <hostname> puship <IP address> pushport <port> pushlogin <login ID> pushpassword <password> pulllogin <login ID> pullpassword <password> passiveftp <y|n>

=cut

# ROUTINE: createDm
# Purpose: To create a data manager
# create dm[1-4] host <hostname> puship <IP address> pushport <port> pushlogin <login ID> pushpassword <password> pulllogin <login ID> pullpassword <password> passiveftp <y|n>
sub createDm {
  my ($self,$id, $keyVals)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createDm");
  if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
    $logger->warn(__PACKAGE__ . ".createDm  MUST PERFORM THIS FUNCTION ON MNODE");
    return 0;
  }
  unless(defined($id) && defined($keyVals)){
    $logger->warn(__PACKAGE__ . ".createDm  ARGUMENTS MISSING.  PLEASE PROVIDE DATA MANAGER NUMBER AND KEY VALUE PAIRS");
    
    return 0;
  };
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
  # build command string
  foreach $key (keys %$keyVals) {
    #print "$key => $$keyVals{$key}\n";
    $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
  }
  $cmd = sprintf("create dm%s %s ",$id,$cmdTmp);
  if($self->{MAINTMODE}){
    $self->setMaintLevel("on");
  }
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".createDm  CMD RESULTS:");
  foreach(@cmdResults) {
    if(!m//i){
      $logger->warn(__PACKAGE__ . ".createDm  $_");
      $flag = 0;
      next;
    }
    $logger->info(__PACKAGE__ . ".createDm  $_");
    
  }
  if($self->{MAINTMODE}){
    $self->setMaintLevel("off");
  }
  return $flag;
}

=head1 B<createConnector(KEYVALUEPAIRS)>

  Method to create connector interface.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->createConnector({<key> => "<value>",
			    ...
			    }
			   );  
  CLI COMMAND (V06.01.03R002):
  create connector [name|inputconfig|outputconfig|dll|protocol|address|port|options|timerstring|inputtimeout|linkeddef|maxoutputqueuesize|priority|sensorid|sensortype] <value>

=cut

# ROUTINE: createConnector
# Purpose: To create a connector
# create connector [name|inputconfig|outputconfig|dll|protocol|address|port|options|timerstring|inputtimeout|linkeddef|maxoutputqueuesize|priority|sensorid|sensortype] <value>
sub createConnector {
  my ($self,$keyVals)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createConnector");
  if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
    $logger->warn(__PACKAGE__ . ".createConnector  MUST PERFORM THIS FUNCTION ON MNODE");
    return 0;
  }
  unless(defined($keyVals)){
    $logger->warn(__PACKAGE__ . ".createConnector  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
    
    return 0;
  };
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
  # build command string
  foreach $key (keys %$keyVals) {
    #print "$key => $$keyVals{$key}\n";
    $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
  }
  $cmd = sprintf("create connector %s ",$cmdTmp);
  if($self->{MAINTMODE}){
    $self->setMaintLevel("on");
  }
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".createConnector  CMD RESULTS:");
  foreach(@cmdResults) {
    if(!m//i){
      $logger->warn(__PACKAGE__ . ".createConnector  $_");
      $flag = 0;
      next;
    }
    $logger->info(__PACKAGE__ . ".createConnector  $_");
    
  }
  if($self->{MAINTMODE}){
    $self->setMaintLevel("off");
  }
  return $flag;
}

=head1 B<createDSTdest(KEYVALUEPAIRS)>

  Method to create dst transporter destination interface.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.
  Example: 
  $dsicli->createDSTdest({<key> => "<value>",
			    ...
			    }
			   );  
  CLI COMMAND (V06.01.03R002):
  create dstdest name <name> ip <IP address> port <port> desttype <DSI|3RD> conntype <0-3> destdir <path> archive <0|1> archdir <path> user <name> password <password> srcdir <path>

=cut

# ROUTINE: createDSTdest
# Purpose: To create a dstdest
# create dstdest name <name> ip <IP address> port <port> desttype <DSI|3RD> conntype <0-3> destdir <path> archive <0|1> archdir <path> user <name> password <password> srcdir <path>
sub createDSTdest {
  my ($self,$keyVals)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createDSTdest");
  if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
    $logger->warn(__PACKAGE__ . ".createDSTdest  MUST PERFORM THIS FUNCTION ON MNODE");
    return 0;
  }
  unless(defined($keyVals)){
    $logger->warn(__PACKAGE__ . ".createDSTdest  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
    
    return 0;
  };
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
  # build command string
  foreach $key (keys %$keyVals) {
    #print "$key => $$keyVals{$key}\n";
    $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
  }
  $cmd = sprintf("create dstdest %s ",$cmdTmp);
  if($self->{MAINTMODE}){
    $self->setMaintLevel("on");
  }
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".createDSTdest  CMD RESULTS:");
  foreach(@cmdResults) {
    if(!m//i){
      $logger->warn(__PACKAGE__ . ".createDSTdest  $_");
      $flag = 0;
      next;
    }
    $logger->info(__PACKAGE__ . ".createDSTdest  $_");
    
  }
  if($self->{MAINTMODE}){
    $self->setMaintLevel("off");
  }
  return $flag;
}


################ Creation of Transporter Destination using ECLI ######################


sub createDSTdest_ECLI {
  my ($self,$keyVals)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createDSTdest_ECLI");
  if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
    $logger->warn(__PACKAGE__ . ".createDSTdest_ECLI  MUST PERFORM THIS FUNCTION ON MNODE");
    return 0;
  }
  unless(defined($keyVals)){
    $logger->warn(__PACKAGE__ . ".createDSTdest_ECLI  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");

    return 0;
  };
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
  # build command string
   my @sortorder= sort keys %$keyVals; # sorts $keys
   foreach $key (@sortorder) {     # extracts values for each key on the basis of the sorted array
    $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
  }

  $cmd = sprintf("work trans dest create %s",$cmdTmp);
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".createDSTdest_ECLI  CMD RESULTS:");
  foreach(@cmdResults) {
    if((m/.*added/i) || (m/.*already exists/i))
    {
      $flag =1;
      $logger->info(__PACKAGE__ . ".createDSTdest_ECLI  $_ ");
    }else {
      $flag =0;
      $logger->info(__PACKAGE__ . ".createDSTdest_ECLI $_");
    }
 
  }
  return $flag;
}



=head1 B<createDSTsrc(KEYVALUEPAIRS)>

  Method to create dst transporter source interface.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.
  Example: 
  $dsicli->createDSTsrc({<key> => "<value>",
			 ...
			}
		        );  
  CLI COMMAND (V06.01.03R002):
  create dstdest name <name> ip <IP address> port <port> desttype <DSI|3RD> conntype <0-3> destdir <path> archive <0|1> archdir <path> user <name> password <password> srcdir <path>

=cut

# *** FIX ***   cmd above and below is wrong.
# ROUTINE: createDSTsrc
# Purpose: To create a neew ancillary database interface
# create dstdest name <name> ip <IP address> port <port> desttype <DSI|3RD> conntype <0-3> destdir <path> archive <0|1> archdir <path> user <name> password <password> srcdir <path>

sub createDSTsrc {
  my ($self,$keyVals)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createDSTsrc");
  if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
    $logger->warn(__PACKAGE__ . ".createDSTsrc  MUST PERFORM THIS FUNCTION ON MNODE");
    return 0;
  }
  unless(defined($keyVals)){
    $logger->warn(__PACKAGE__ . ".createDSTsrc  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
    
    return 0;
  };
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
  # build command string
  foreach $key (keys %$keyVals) {
    #print "$key => $$keyVals{$key}\n";
    $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
  }
  $cmd = sprintf("create dstsrc %s ",$cmdTmp);
  if($self->{MAINTMODE}){
    $self->setMaintLevel("on");
  }
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".createDSTsrc  CMD RESULTS:");
  foreach(@cmdResults) {
    if(!m//i){
      $logger->warn(__PACKAGE__ . ".createDSTsrc  $_");
      $flag = 0;
      next;
        }
    $logger->info(__PACKAGE__ . ".createDSTsrc  $_");
    
  }
  if($self->{MAINTMODE}){
    $self->setMaintLevel("off");
  }
  return $flag;
}


################ Creation of Transporter Source using ECLI ######################


sub createDSTsrc_ECLI {
  my ($self,@Vals)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createDSTsrc_ECLI");
  if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
    $logger->warn(__PACKAGE__ . ".createDSTsrc_ECLI  MUST PERFORM THIS FUNCTION ON MNODE");
    return 0;
  }

  unless(@Vals){
    $logger->warn(__PACKAGE__ . ".createDSTsrc_ECLI  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");

    return 0;
  };
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
  # build command string
  $cmd = sprintf("work trans src create %s ",@Vals);
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".createDSTsrc_ECLI  CMD RESULTS:");
  foreach(@cmdResults) {
    if((m/.*added/i) || (m/.*already exists/i))
    {
      $flag =1;
      $logger->info(__PACKAGE__ . ".createDSTsrc_ECLI  $_ ");
    }else {
      $flag =0;
      $logger->info(__PACKAGE__ . ".createDSTsrc_ECLI $_");
    }

  }
  return $flag;
}


=head1 B<createFSsrc(KEYVALUEPAIRS)>

  Method to create file services source interface.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.
  Example: 
  $dsicli->createFSsrc({<key> => "<value>",
			 ...
			}
		        );  
  CLI COMMAND (V06.01.03R002):
  create fileservices source name <name> srcdir <dir> workdir <dir>

=cut

# ROUTINE: createFSsrc
# Purpose: To create a neew ancillary database interface
# create fileservices source name <name> srcdir <dir> workdir <dir>
sub createFSsrc {
  my ($self,$keyVals)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createFSsrc");
  if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
    $logger->warn(__PACKAGE__ . ".createFSsrc  MUST PERFORM THIS FUNCTION ON MNODE");
    return 0;
  }
  unless(defined($keyVals)){
    $logger->warn(__PACKAGE__ . ".createFSsrc  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
    
    return 0;
  };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
  # build command string
  foreach $key (keys %$keyVals) {
    #print "$key => $$keyVals{$key}\n";
    $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
  }
  $cmd = sprintf("create fileservices source %s ",$cmdTmp);
  if($self->{MAINTMODE}){
    $self->setMaintLevel("on");
  }
  $flag = 0; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".createFSsrc  CMD RESULTS:");
  foreach(@cmdResults) {
    chomp($_);
    if(m/entry.*added/i){
      $logger->info(__PACKAGE__ . ".createFSsrc  $_ (SOURCE ADDED)");
      $flag = 1;
      push(@{$self->{STACK}},['deleteFSsrc', [$keyVals] ]);
      next;
    }else{
	&fail(__PACKAGE__ . ".createFSsrc  $_");
    }
  }
  if($self->{MAINTMODE}){
    $self->setMaintLevel("off");
  }
  return $flag;
}

=head1 B<createRoute(KEYVALUEPAIRS)>

  Method to create routing interface.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->createRoute({<key> => "<value>",
			 ...
			}
		        );  
  CLI COMMAND (V06.01.03R002):
  create fileservices source name <name> srcdir <dir> workdir <dir>

=cut

# ROUTINE: createRoute
# Purpose: To create a route
# create route [inputconn|outputconn|response] <value>
sub createRoute {
  my ($self,$keyVals)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createRoute");
  if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
    $logger->warn(__PACKAGE__ . ".createRoute  MUST PERFORM THIS FUNCTION ON MNODE");
    return 0;
  }
  unless(defined($keyVals)){
    $logger->warn(__PACKAGE__ . ".createRoute  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
    
    return 0;
  };
  my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
  # build command string
  foreach $key (keys %$keyVals) {
    #print "$key => $$keyVals{$key}\n";
    $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
  }
  $cmd = sprintf("create route %s ", $cmdTmp);
  if($self->{MAINTMODE}){
    $self->setMaintLevel("on");
  }
  $flag = 1; # Assume cmd will work
  @cmdResults = $self->execCmd($cmd);
  $logger->info(__PACKAGE__ . ".createRoute  CMD RESULTS:");
  
  
  foreach(@cmdResults) {
    if(!m//i){
      $logger->warn(__PACKAGE__ . ".createRoute  $_");
      $flag = 0;
      next;
    }
    $logger->info(__PACKAGE__ . ".createRoute  $_");
    
    }
  if($self->{MAINTMODE}){
    $self->setMaintLevel("off");
  }
  return $flag;
}

=head1 B<createHouseKeeping(KEYVALUEPAIRS)>

  Method to create housekeeping task.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->createHouseKeeping({<key> => "<value>",
			       ...
			       }
			       );  
  CLI COMMAND (V06.01.03R002):
  create housekeeping [name|timerstring|age|size|number|function|farg] <value>

=cut

# ROUTINE: createHouseKeeping
# Purpose: To create a housekeeping task
# create housekeeping [name|timerstring|age|size|number|function|farg] <value>
sub createHouseKeeping {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createHouseKeeping");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".createHouseKeeping  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".createHouseKeeping  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      if($key =~ /timerstring/i){
	$cmd .= $key . "\"". $$keyVals{$key} . "\"";  # the timerstring has to be in quotes
      }else{
	$cmdTmp .= $key . " ". $$keyVals{$key} . " ";
      }
    }
    
    $cmd = sprintf("create housekeeping %s ", $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".createHouseKeeping  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m/job.*added.*housekeeping.*file/i){
            $logger->warn(__PACKAGE__ . ".createHouseKeeping  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".createHouseKeeping  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<createCommRoute(KEYVALUEPAIRS)>

  Method to create communication route.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->createCommRoute({<key> => "<value>",
			    ...
			    }
			    );  
  CLI COMMAND (V06.01.03R002):
  create commroute [name|ip|port|handler|connect|directory|archive|archivedirectory|user|password|workingdirectory|active|ftpfreq|pasvport|pasvportrng] <value>

=cut

# ROUTINE: createCommRoute
# Purpose: To create a commroute 
# create commroute [name|ip|port|handler|connect|directory|archive|archivedirectory|user|password|workingdirectory|active|ftpfreq|pasvport|pasvportrng] <value>

sub createCommRoute {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createCommRoute");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".createCommRoute  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".createCommRoute  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("create commroute %s ",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".createCommRoute  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m/route.*added.*config.*file/i){
            $logger->warn(__PACKAGE__ . ".createCommRoute  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".createCommRoute  $_");
        # ".createCommRoute  $_\n";
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<createClientCommRoute(KEYVALUEPAIRS)>

  Method to create client communication route.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->createClientCommRoute({<key> => "<value>",
				  ...
				  }
				  );  
  CLI COMMAND (V06.01.03R002):
  create client commroute [name|ip|port|handler|connect|directory|archive|archivedirectory|user|password|workingdirectory|active|ftpfreq|pasvport|pasvportrng] <value>

=cut

# ROUTINE: createClientCommRoute
# Purpose: To create a client commroute
# create client commroute [name|ip|port|handler|connect|directory|archive|archivedirectory|user|password|workingdirectory|active|ftpfreq|pasvport|pasvportrng] <value>
sub createClientCommRoute {
    my ($self, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createClientCommRoute");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".createClientCommRoute  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".createClientCommRoute  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("create client commroute %s ", $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".createClientCommRoute  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".createClientCommRoute  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".createClientCommRoute  $_");
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

sub createClientCommroute_ECLI{
    my ($self, @fields)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createClientCommRoute");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".createClientCommRoute_ECLI  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    my(@cmdResults,$cmd,$flag,$cmdTmp);
    # build command string
   for(my $j=0; $j<=15; $j++) {     # extracts values for each key on the basis of the sorted array
        $cmdTmp .= $fields[$j] . " ". $fields[$j+16] . " ";
   }

    $cmd = sprintf("workflow communicator client create %s ", $cmdTmp);
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".createClientCommRoute_ECLI  CMD RESULTS:");
    foreach(@cmdResults) {
        if((m/.*exists/i) || (m/.*added/i)){
            $logger->info(__PACKAGE__ . ".createClientCommRoute_ECLI  $_");
            $flag = 1;
        }else {
            $logger->warn(__PACKAGE__ . ".createClientCommRoute_ECLI  $_");
            $flag = 0;
        }
    }
    return $flag;
}


=head1 B<createSaiConfig(KEYVALUEPAIRS)>

  Method to create SAI configuration/interface.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->createSaiConfig({<key> => "<value>",
			    ...
			    }
			    );  
  CLI COMMAND (V06.01.03R002):
  create saiconfig [name|ipport|outport|bpaipaddr|bpaipport|reconnAttempt|reconnInterval|reconnPause|active|reboot|start|stop|attempt|
  switchover|intermediate|alive|aliveFreq|outConfig|saistream|numRecord|fileSize|fileTmInterval] <value>

=cut

# ROUTINE: createSaiConfig
# Purpose: To create a saiconfig
# create saiconfig [name|ipport|outport|bpaipaddr|bpaipport|reconnAttempt|reconnInterval|reconnPause|active|reboot|start|stop|attempt|switchover|intermediate|alive|aliveFreq|outConfig|saistream|numRecord|fileSize|fileTmInterval] <value>
sub createSaiConfig {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createSaiConfig");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".createSaiConfig  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless($keyVals){
        $logger->warn(__PACKAGE__ . ".createSaiConfig  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("create saiconfig %s ",$cmdTmp);
    #print $cmd . "\n"; 
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".createSaiConfig  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m/saiconfig.*added/i){
            $logger->warn(__PACKAGE__ . ".createSaiConfig  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".createSaiConfig  $_");
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<createStreamConfig(KEYVALUEPAIRS)>

  Method to create stream configuration/interface.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->createStreamConfig({<key> => "<value>",
			       ...
			       }
			       );  
  CLI COMMAND (V06.01.03R002):
  create streamconfig [name|outport|srcipaddr1|srcipaddr2|srcipaddr3|srcipaddr4|srcipaddr5|srcipaddr6|srcipaddr7|srcipaddr8|
  username|userauth|bpaipaddr|bpaipport|reconnAttempt|reconnInterval|reconnPause|active|outConfig|besvropt|numRecord|fileSize|fileTmInterval|closing|logfileSize|maxlogfile] <value>

=cut

# ROUTINE: createStreamConfig
# Purpose: To create a streamconfig
# create streamconfig [name|outport|srcipaddr1|srcipaddr2|srcipaddr3|srcipaddr4|srcipaddr5|srcipaddr6|srcipaddr7|srcipaddr8|username|userauth|bpaipaddr|bpaipport|reconnAttempt|reconnInterval|reconnPause|active|outConfig|besvropt|numRecord|fileSize|fileTmInterval|closing|logfileSize|maxlogfile] <value>
sub createStreamConfig {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createSaiConfig");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".createStreamConfig  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".createStreamConfig  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("create saiconfig %s ",$cmdTmp);
    print $cmd . "\n";
    return 1;
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".createStreamConfig  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".createStreamConfig  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".createStreamConfig  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<createCodeset(KEYVALUEPAIRS)>

  Method to create codeset table entry.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->createCodeset({<key> => "<value>",
			  ...
			  }
			  );  
  CLI COMMAND (V06.01.03R002):
  create codeset <codeset table> <key> <value>

=cut

# ROUTINE: createCodeset
# Purpose: To create codeset table entry
# create codeset <codeset table> <key> <value>
sub createCodeset {
    my ($self,$codeSetTable, $key, $value)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createCodeset");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".createCodeset  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($codeSetTable) && defined($key) && defined($value)){
        $logger->warn(__PACKAGE__ . ".createCodeset  ARGUMENTS MISSING.  PLEASE PROVIDE CODESET TABLE, KEY AND VALUE");
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("create codeset %s \"%s\" \"%s\" ",$codeSetTable, $key, $value);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".createCodeset  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".createCodeset  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".createCodeset  $_");        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<createCorrelateRule(KEYVALUEPAIRS)>

  Method to create corrleation rule entry.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->createCorrelateRule({<key> => "<value>",
			        ...
			        }
			        );  
  CLI COMMAND (V06.01.03R002):
  create correlaterule <rulename> sensorid <sensorid value>

=cut

# ROUTINE: createCorrelateRule
# Purpose: To create a correlaterule
# create/delete correlaterule <rulename> sensorid <sensorid value>
sub createCorrelateRule {
    my ($self,$ruleName, $sensorid)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createCorrelateRule");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".createCorrelateRule  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($ruleName) && defined($sensorid)){    
        $logger->warn(__PACKAGE__ . ".createCorrelateRule  ARGUMENTS MISSING.  PLEASE PROVIDE RULE NAME AND SENSORID");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("create correlaterule %s sensorid %s ",$ruleName, $sensorid);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".createCorrelateRule  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".createCorrelateRule  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".createCorrelateRule  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

# GET ROUTINES FOR CLI
# ------------------------

sub getVersion {
    my ($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getVersion");
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    
    $cmd = "show version";
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".getVersion  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->debug(__PACKAGE__ . ".getVersion  $_");
            $flag = 0;
            next;
        }
        $logger->debug(__PACKAGE__ . ".getVersion  $_");
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return @cmdResults;
}

sub getVersion_ECLI {
    my ($self)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getVersion_ECLI");
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string

    $cmd = "sys version show";
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".getVersion  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->debug(__PACKAGE__ . ".getVersion  $_");
            $flag = 0;
            next;
        }
        $logger->debug(__PACKAGE__ . ".getVersion  $_");
    }
    return @cmdResults;
}


sub getFSconfig {
    my ($self,$attribute)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getFSconfig");
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    
    $cmd = "show fileservices config";
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 0; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".getFSconfig  CMD RESULTS:");
    $logger->info(__PACKAGE__ . ".getFSconfig  ATTRIBUTE: $attribute");
    foreach(@cmdResults) {
        if(m/$attribute.*\<(.*)\>/i){
            $logger->info(__PACKAGE__ . ".getFSconfig  RETRIEVE ATTRIBUTE $attribute=$1");
            $flag = $1;
            next;
        }
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

#*******************************************************************************
#  DO NOT USE THIS FUNCTION UNTIL THERE IS A METHOD TO DISABLE PAGING ON THE 
#  DSI.
#
#
#*******************************************************************************
sub showPrimaryAMA {
    my ($self,$amaFileNumber)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".showPrimaryAMA");
    if(uc($self->{OBJ_NODETYPE}) !~ /PMNODE/){
        $logger->warn(__PACKAGE__ . ".showPrimaryAMA  MUST PERFORM THIS FUNCTION ON PNODE");
        return 0;
    }
    unless( defined($amaFileNumber) ){
        $logger->warn(__PACKAGE__ . ".showPrimaryAMA  ARGUMENTS MISSING.  PLEASE PROVIDE AMA FILE NAME (MUST BE 24 CHARS)");
        return 0;
    };
    my $length = length($amaFileNumber);
    if($length < 24){
        $logger->warn(__PACKAGE__ . ".showPrimaryAMA  PLEASE PROVIDE AMA FILE MUST BE 24 CHARS [CURRENTLY: $length]");
	return 0;
    }
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("show primary %s",$amaFileNumber);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".showPrimaryAMA  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->debug(__PACKAGE__ . ".getVersion  $_");
            $flag = 0;
            next;
        }
        $logger->debug(__PACKAGE__ . ".getVersion  $_");
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return @cmdResults;
}
# SET ROUTINES FOR CLI
# ------------------------

=head1 B<setAdbi(ID, KEYVALUEPAIRS)>

  Method to set or alter anicllary database interface attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setAdbi(ID, {<key> => "<value>",
			...
			}
			);  
  CLI COMMAND (V06.01.03R002):
  set adbi <ID> name <name> active <0|1> configfile <fullpath/filename>

=cut

# ROUTINE: setAdbi
# Purpose: To set ancillary database interface attributes
# set adbi <ID> name <name> active <0|1> configfile <fullpath/filename>
sub setAdbi {
    my ($self, $id, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setAdbi");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setAdbi  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id) && defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setAdbi  ARGUMENTS MISSING.  PLEASE PROVIDE ADBI ID AND KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set adbi %s %s",$id,$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setAdbi  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setAdbi  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setAdbi  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setDm(ID, KEYVALUEPAIRS)>

  Method to set or alter data manager interface attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setDm(ID, {<key> => "<value>",
		      ...
		      }
		      );  
  CLI COMMAND (V06.01.03R002):
  set dm[1-4] [host|puship|pushport|pushlogin|pushpassword|pulllogin|pullpassword|absolutepath|passiveftp|rename|primary] <value>

=cut

# ROUTINE: setDm
# Purpose: To set a Data Manager attributes
# set dm[1-4] [host|puship|pushport|pushlogin|pushpassword|pulllogin|pullpassword|absolutepath|passiveftp|rename|primary] <value>
sub setDm {
    my ($self, $id, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setDm");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setDm  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id) && defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setDm  ARGUMENTS MISSING.  PLEASE PROVIDE DATA MANAGER NUMBER AND KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set dm%s %s ",$id,$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setDm  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setDm  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setDm  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setDs(KEYVALUEPAIRS)>

  Method to set or alter DS interface attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setDs({<key> => "<value>",
		  ...
		  }
		  );  
  CLI COMMAND (V06.01.03R002):
  set ds [????] <value>

=cut

# *** FIX ***
# ROUTINE: setDs
# Purpose: To set a Data Manager attributes
# set ds [????] <value>
sub setDs {
    my ($self, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setDs");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setDs  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setDs  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set ds %s",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setDs  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setDs  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setDs  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setConnector(ID, KEYVALUEPAIRS)>

  Method to set or alter connector interface attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.
  Example: 
  $dsicli->setConnector({<key> => "<value>",
			 ...
			 }
			 );  
  CLI COMMAND (V06.01.03R002):
  set connector <id> [name|inputconfig|outputconfig|dll|protocol|address|port|options|timerstring|inputtimeout|linkeddef|maxoutputqueuesize|priority|sensorid|sensortype] <value>

=cut

# ROUTINE: setConnector
# Purpose: To set connector attributes
# set connector <id> [name|inputconfig|outputconfig|dll|protocol|address|port|options|timerstring|inputtimeout|linkeddef|maxoutputqueuesize|priority|sensorid|sensortype] <value>
sub setConnector {
    my ($self, $id, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setConnector");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setConnector  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id) && defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setConnector  ARGUMENTS MISSING.  PLEASE PROVIDE CONNECTOR ID AND KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set connector %s %s ",$id, $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setConnector  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setConnector  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setConnector  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setDSTconfig(KEYVALUEPAIRS)>

  Method to set or alter DST transporter interface attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setDSTconfig({<key> => "<value>",
			 ...
			 }
			 );  
  CLI COMMAND (V06.01.03R002):
  set dstconfig ip <IP address> port <port>

=cut


# ROUTINE: setDSTconfig
# Purpose: To set dst transporter attributes
# set dstconfig ip <IP address> port <port>
sub setDSTconfig {
    my ($self, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setDSTconfig");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setDSTconfig  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setDSTconfig  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set dstconfig %s ", $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setDSTconfig  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setDSTconfig  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setDSTconfig  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
} 

=head1 B<setDSTdest(KEYVALUEPAIRS)>

  Method to set or alter DST transporter destination interface attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setDSTdest({<key> => "<value>",
		       ...
		       }
		       );  
  CLI COMMAND (V06.01.03R002):
  set dstdest name <name> ip <IP address> port <port> desttype <DSI|3RD> conntype <0-3> destdir <path> archive <0|1> archdir <path> user <name> password <password> srcdir <path>

=cut

# ROUTINE: setDSTdest 
# Purpose: To set dstdest config attributes
# set dstdest name <name> ip <IP address> port <port> desttype <DSI|3RD> conntype <0-3> destdir <path> archive <0|1> archdir <path> user <name> password <password> srcdir <path>
sub setDSTdest {
    my ($self, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setDSTdest");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setDSTdest  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setDSTdest  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set dstdest %s ", $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setDSTdest  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setDSTdest  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setDSTdest  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
} 


sub setDSTdest_ECLI {
    my ($self, @vals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setDSTdest_ECLI");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setDSTdest  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(@vals){
        $logger->warn(__PACKAGE__ . ".setDSTdest  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");

        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    foreach(@vals){
        $cmdTmp .= $_. " ";
    }
    $cmd = sprintf("work trans dest set  %s ", $cmdTmp);
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setDSTdest  CMD RESULTS:");
    foreach(@cmdResults) {
        if(m/.*updated/i){
            $logger->info(__PACKAGE__ . ".setDSTdest_ECLI  $_");
        }else {
            $flag =0;
            $logger->info(__PACKAGE__ . ".setDSTdest_ECLI $_");
        }
   }
    return $flag;
}

=head1 B<setDSTsrc(KEYVALUEPAIRS)>

  Method to set or alter DST transporter source interface attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setDSTsrc({<key> => "<value>",
		      ...
		      }
		      );  
  CLI COMMAND (V06.01.03R002):
  set dstsrc id <ID> srcname <name> srctype <GSX|PSX|ASX> delorig <0|1> srcdir <dir> workdir <dir> destdir <dir> archdir <dir> 
  archive <0|1> ext <extension> filtatt <0|1> filtsta <0|1> filtsto <0|1> filtint <0|1> filtreb <0|1> filtswt <0|1> scantime <seconds> 
  dupchksize <num> numrec <num> filesize <num> interval <seconds> closetime <0000|2400> pridest <IP> secdest <IP> 

=cut

# ROUTINE: setDSTsrc 
# Purpose: To set dstdest config attributes
# set dstsrc id <ID> srcname <name> srctype <GSX|PSX|ASX> delorig <0|1> srcdir <dir> workdir <dir> destdir <dir> archdir <dir> archive <0|1> ext <extension> filtatt <0|1> filtsta <0|1> filtsto <0|1> filtint <0|1> filtreb <0|1> filtswt <0|1> scantime <seconds> dupchksize <num> numrec <num> filesize <num> interval <seconds> closetime <0000—2400> pridest <IP> secdest <IP> 
sub setDSTsrc {
    my ($self, $id, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setDSTsrc");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setDSTsrc  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id) && defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setDSTsrc  ARGUMENTS MISSING.  PLEASE PROVIDE DSTSRC ID AND KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set dstsrc %s %s ", $id, $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setDSTsrc  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setDSTsrc  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setDSTsrc  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
} 


sub setDSTsrc_ECLI {
    my ($self, @vals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setDSTsrc_ECLI");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setDSTsrc_ECLI  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(@vals){
        $logger->warn(__PACKAGE__ . ".setDSTsrc_ECLI  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");

        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
 #   my @sortorder= sort keys %$keyVals;
 #   foreach $key (@sortorder) {
      $cmdTmp .= $vals[0]. " ". $vals[1] . " ";
 #   }

    $cmd = sprintf("work trans src set  %s ", $cmdTmp);
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setDSTsrc_ECLI  CMD RESULTS:");
    foreach(@cmdResults) {
        if(m/.*updated/i){
            $logger->info(__PACKAGE__ . ".setDSTsrc_ECLI  $_");
        }else {
            $flag =0;
            $logger->info(__PACKAGE__ . ".setDSTsrc_ECLI $_");
        }
   }
    return $flag;
}




=head1 B<setClientCommroute(KEYVALUEPAIRS)>

  Method to set or alter Client Commroute interface attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.
  Example:
  $dsicli->setClientCommroute({<key> => "<value>",
                       ...
                       }
                       );
  CLI COMMAND (V08.00.00R001):
  Sonus CLI (kangra)-workflow-communicator-client-> set <.{1,56}> ip <ip-address> handler <DSI|3RD> [ port <1-65535> | connect <0-2> | 
  user <.{1,12}> | password <.{1,12}> | directory <directory> | archive <0|1|y|n> | archivedirectory <directory> | 
  workingdirectory <directory> | active <0|1|y|n> | ftpfreq <1-86400> | pasvport <10000-65535> | pasvportrng <1-55535> | audit <0|1> ]*

=cut

# ROUTINE: setClientCommroute
# Purpose: To set client commroute (TRC) config attributes
# Sonus CLI (kangra)-workflow-communicator-client-> set <.{1,56}> ( ip <ip-address> | port <1-65535> | handler <DSI|3RD> | connect <0-2> | user <.{1,12}> | password <.{1,12}> | directory <directory> | archive <0|1|y|n> | archivedirectory <directory> | workingdirectory <directory> | active <0|1|y|n> | ftpfreq <1-86400> | pasvport <10000-65535> | pasvportrng <1-55535> | audit <0|1> )*



sub setClientCommroute_ECLI {
    my ($self, @vals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setClientCommroute_ECLI");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setClientCommroute  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(@vals){
        $logger->warn(__PACKAGE__ . ".setClientCommroute  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");

        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    foreach(@vals){
        $cmdTmp .= $_. " ";
    }
    $cmd = sprintf("work comm client set  %s ", $cmdTmp);
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setClientCommroute  CMD RESULTS:");
    foreach(@cmdResults) {
        if(m/.*updated/i){
            $logger->info(__PACKAGE__ . ".setClientCommroute_ECLI  $_");
        }else {
            $flag =0;
            $logger->info(__PACKAGE__ . ".setClientCommroute_ECLI $_");
        }
   }
    return $flag;
}

sub associate_Clientroute_ECLI{

    my ($self, @vals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".associate_Clientroute_ECLI");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".associate_Clientroute_ECLI  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(@vals){
        $logger->warn(__PACKAGE__ . ".associate_Clientroute_ECLI  ARGUMENTS MISSING.  PLEASE PROVIDE HOSTS NAMES");

        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    $cmdTmp .= $vals[0]. " ". $vals[1] . " ";
    $cmd = sprintf("work comm client associate %s ", $cmdTmp);
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".associate_Clientroute_ECLI  CMD RESULTS:");
    foreach(@cmdResults) {
        if(m/.*associated/i){
            $logger->info(__PACKAGE__ . ".associate_Clientroute_ECLI  $_");
        }else {
            $flag =0;
            $logger->info(__PACKAGE__ . ".associate_Clientroute_ECLI $_");
        }
    }
    return $flag;
}

sub disassociate_Clientroute_ECLI{

    my ($self, @vals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".disassociate_Clientroute_ECLI");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".disassociate_Clientroute_ECLI  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(@vals){
        $logger->warn(__PACKAGE__ . ".disassociate_Clientroute_ECLI  ARGUMENTS MISSING.  PLEASE PROVIDE HOSTS NAMES");

        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    $cmdTmp .= $vals[0]. " ". $vals[1] . " ";
    $cmd = sprintf("work comm client disassociate %s ", $cmdTmp);
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".disassociate_Clientroute_ECLI  CMD RESULTS:");
    foreach(@cmdResults) {
        if(m/.*disassociated/i){
            $logger->info(__PACKAGE__ . ".disassociate_Clientroute_ECLI  $_");
        }else {
            $flag =0;
            $logger->info(__PACKAGE__ . ".disassociate_Clientroute_ECLI $_");
        }
    }
    return $flag;
}

=head1 B<setFSconfig(KEYVALUEPAIRS)>

  Method to set or alter file services configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setFSconfig({<key> => "<value>",
		        ...
			}
			);  
  CLI COMMAND (V06.01.03R002):
  set set fileservices config peerport <port> peerhost <name> scantime <seconds> nofileactivity <timespan> filterset <list>

=cut

# ROUTINE: setFSconfig
# Purpose: To set fileservices config attributes
# set set fileservices config peerport <port> peerhost <name> scantime <seconds> nofileactivity <timespan> filterset <list>
sub setFSconfig {
    my ($self, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setFSconfig");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setFSconfig  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setFSconfig  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set fileservices config %s ", $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 0; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setFSconfig  CMD RESULTS:");
    foreach(@cmdResults) {
        if(m/config.*modified/i){
            $logger->warn(__PACKAGE__ . ".setFSconfig  $_");
            $flag = 1;
            next;
        }
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
} 

=head1 B<setFSsrc(STRING ID, KEYVALUEPAIRS)>

  Method to set or alter file services source configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setFSsrc('ID', {<key> => "<value>",
		     ...
		     }
		     );  
  CLI COMMAND (V06.01.03R002):
  set fileservices source name <name> srcdir <dir> workdir <dir>

=cut

# ROUTINE: setFSsrc
# Purpose: To set fileservices source attributes
# set fileservices source name <name> srcdir <dir> workdir <dir>
sub setFSsrc {
    my ($self, $id, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setFSsrc");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setFSsrc  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id) && defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setFSsrc  ARGUMENTS MISSING.  PLEASE PROVIDE ID AND KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set fileservices source %s %s", $id, $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 0; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setFSsrc  CMD RESULTS:");
    foreach(@cmdResults) {
        if(m/entry.*modified/i){
            $logger->warn(__PACKAGE__ . ".setFSsrc  $_");
            $flag = 1;
            next;
        }        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setHouseKeeping(ID,KEYVALUEPAIRS)>

  Method to set or alter housekeeping taks configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setHouseKeeping(ID, {<key> => "<value>",
		                ...
				}
				);  
  CLI COMMAND (V06.01.03R002):
  set housekeeping <id> [name|timerstring|age|size|number|function|farg] <value>

=cut

# ROUTINE: setHouseKeeping
# Purpose: To set housekeeping attributes
# set housekeeping <id> [name|timerstring|age|size|number|function|farg] <value>
sub setHouseKeeping {
    my ($self, $id, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setHouseKeeping");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setHouseKeeping  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id) && defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setHouseKeeping  ARGUMENTS MISSING.  PLEASE PROVIDE HOUSEKEEPING ID AND KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      if($key =~ /timerstring/i){
	$cmd .= $key . "\"" . $$keyVals{$key} . "\"";  # timerstring must be in quotes
      }else{
	$cmdTmp .= $key . " ". $$keyVals{$key} . " ";
      }
    }
    $cmd = sprintf("set housekeeping %s %s ", $id, $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setHouseKeeping  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m/job.*modified.*housekeeping.*file/i){
            $logger->warn(__PACKAGE__ . ".setHouseKeeping  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setHouseKeeping  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setCommRoute(ID,KEYVALUEPAIRS)>

  Method to set or alter communication route configuration attributes.
  Key value pairs represent keyword parameters and values that will be assigned to them.
  ID is representative of the name that was configured when the commroute was first provisioned.  
  Example: 
  $dsicli->setCommRoute("nfs1", {ip => "10.9.16.250",
			     port => 14022,
                             });  
  CLI COMMAND (V06.01.03R002):
  set commroute <id> name <name> ip <IP address> port <port> handler <DSI|3RD> connect <0|1|2|3> directory <directory path> 
  archive <0|1> archivedirectory <path> workingdirectory <path> active <0|1|y|n> user <user ID> password <password>

=cut

# ROUTINE: setCommRoute
# Purpose: To set commroute attributes
# set commroute <id> name <name> ip <IP address> port <port> handler <DSI|3RD> connect <0|1|2|3> directory <directory path> archive <0|1> archivedirectory <path> workingdirectory <path> active <0|1|y|n> user <user ID> password <password>
sub setCommRoute {
    my ($self, $id, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setCommRoute");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setCommRoute  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id) && defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setCommRoute  ARGUMENTS MISSING.  PLEASE PROVIDE COMMROUTE ID AND KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }	
    $cmd = sprintf("set commroute %s %s ",$id,$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setCommRoute  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m/updated.*config.*file/i){
            $logger->warn(__PACKAGE__ . ".setCommRoute  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setCommRoute  $_");
        #
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setClientCommRoute(ID,KEYVALUEPAIRS)>

  Method to set or alter client communication route configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setClientCommRoute(ID, {<key> => "<value>",
				   ...
				   }
				   );  
  CLI COMMAND (V06.01.03R002):
  set client commroute <id> name <name> ip <IP address> port <port> handler <string> connect <0|1|2|3> directory <directory path> 
  archive <0|1> archivedirectory <path> workingdirectory <path> active <0|1|y|n> user <user ID> password <password> ftpfreq <seconds> 
  pasvport <beginning port number in passive port range> pasvportrng <range>

=cut

# ROUTINE: setClientCommRoute
# Purpose: To set client commroute attributes
# set client commroute <id> name <name> ip <IP address> port <port> handler <string> connect <0|1|2|3> directory <directory path> archive <0|1> archivedirectory <path> workingdirectory <path> active <0|1|y|n> user <user ID> password <password> ftpfreq <seconds> pasvport <beginning port number in passive port range> pasvportrng <range>
sub setClientCommRoute {
    my ($self, $id, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setClientCommRoute");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setClientCommRoute  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id) && defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setClientCommRoute  ARGUMENTS MISSING.  PLEASE PROVIDE CLIENT COMMROUTE ID AND KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set client commroute %s %s ", $id, $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setClientCommRoute  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setClientCommRoute  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setClientCommRoute  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setSaiConfig(NAME, KEYVALUEPAIRS)>

  Method to set or alter SAI configuration attributes.
  Key value pairs represent keyword parameters and values that will be assigned to them.
  NAME is required and may or may not be included in KEYVALUEPAIRS.  
  Example: 
  $dsicli->setSaiConfig("kddisvr1", {bpaipaddr => "10.9.16.250",
                                     bpaipport => 5050,
				    });  
  CLI COMMAND (V06.01.03R002):
  set saiconfig <NAME> [name|ipport|outport|bpaipaddr|bpaipport|reconnAttempt|reconnInterval|reconnPause|active|reboot|
  start|stop|attempt|switchover|intermediate|alive|aliveFreq|outConfig|saistream|numRecord|fileSize|fileTmInterval] <value>

=cut

# ROUTINE: setSaiConfig
# Purpose: To set saiconfig attributes (same parameters as createSaiConfig)
# set saiconfig [name|ipport|outport|bpaipaddr|bpaipport|reconnAttempt|reconnInterval|reconnPause|active|reboot|start|stop|attempt|switchover|intermediate|alive|aliveFreq|outConfig|saistream|numRecord|fileSize|fileTmInterval] <value>
sub setSaiConfig {
    my ($self, $name, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSaiConfig");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setSaiConfig  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless($name && $keyVals){
        $logger->warn(__PACKAGE__ . ".setSaiConfig  ARGUMENTS MISSING.  PLEASE PROVIDE SAI CONFIG NAME AND KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set saiconfig %s %s ",$name, $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setSaiConfig  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m/updated.*config.*file/i){
            $logger->warn(__PACKAGE__ . ".setSaiConfig  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setSaiConfig  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setStreamConfig(KEYVALUEPAIRS)>

  Method to set or alter stream configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setStreamConfig({<key> => "<value>",
			   ...
			   }
			   );  
  CLI COMMAND (V06.01.03R002):
  set streamconfig [name|outport|srcipaddr1|srcipaddr2|srcipaddr3|srcipaddr4|srcipaddr5|srcipaddr6|srcipaddr7|srcipaddr8|username|
  userauth|bpaipaddr|bpaipport|reconnAttempt|reconnInterval|reconnPause|active|outConfig|besvropt|numRecord|fileSize|fileTmInterval|
  closing|logfileSize|maxlogfile] <value>

=cut

# ROUTINE: setStreamConfig
# Purpose: To set attribtues for streamconfig    (same parameters as createSaiConfig)
# set streamconfig [name|outport|srcipaddr1|srcipaddr2|srcipaddr3|srcipaddr4|srcipaddr5|srcipaddr6|srcipaddr7|srcipaddr8|username|userauth|bpaipaddr|bpaipport|reconnAttempt|reconnInterval|reconnPause|active|outConfig|besvropt|numRecord|fileSize|fileTmInterval|closing|logfileSize|maxlogfile] <value>
sub setStreamConfig {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setStreamConfig");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setStreamConfig  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setStreamConfig  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set saiconfig %s ",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setStreamConfig  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setStreamConfig  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setStreamConfig  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setAma(KEYVALUEPAIRS)>

  Method to set or alter AMA configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setAma({<key> => "<value>",
		   ...
		   }
		   );  
  CLI COMMAND (V06.01.03R002):
  set ama [maxrecoverysize|ascii|header|tracer|limitfilerecout|limitfilebytesout|forceclosure|altfilename|comptype|compid|scrtracer|markrec] <value>

=cut

# ROUTINE: setAma
# Purpose: To set attribtues for ama configuration
# set ama [maxrecoverysize|ascii|header|tracer|limitfilerecout|limitfilebytesout|forceclosure|altfilename|comptype|compid|scrtracer|markrec] <value>
sub setAma {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setAma");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setAma  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setAma  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set ama %s ",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setAma  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setAma  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setAma  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setMaintainer(KEYVALUEPAIRS)>

  Method to set or alter maintainer configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setMaintainer({<key> => "<value>",
			  ...
			  }
			  );  
  CLI COMMAND (V06.01.03R002):
  set ama [maxrecoverysize|ascii|header|tracer|limitfilerecout|limitfilebytesout|forceclosure|altfilename|comptype|compid|scrtracer|markrec] <value>

=cut

# ROUTINE: setMaintainer
# Purpose: To set attribtues for maintainer configuration
# set maintainer [inputretries|archive|scannerperiod] <value>
sub setMaintainer {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setMaintainer");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setMaintainer  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setMaintainer  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set maintainer %s ",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setMaintainer  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setMaintainer  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setMaintainer  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setLogger(KEYVALUEPAIRS)>

  Method to set or alter logger configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setLogger({<key> => "<value>",
		      ...
		      }
		      );  
  CLI COMMAND (V06.01.03R002):
  set logger [keeplogs|maxlogsize|audit|maxlogs] <value>

=cut

# ROUTINE: setLogger
# Purpose: To set attribtues for logger configuration
# set logger [keeplogs|maxlogsize|audit|maxlogs] <value>
sub setLogger {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setLogger");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setLogger  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setLogger  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set logger %s ",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setLogger  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setLogger  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setLogger  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setFTPDaemon(KEYVALUEPAIRS)>

  Method to set or alter FTP daemon configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setFTPDaemon({<key> => "<value>",
		         ...
		         }
		         );  
  CLI COMMAND (V06.01.03R002):
  set ftpdaemon [rename|passiveftp] <value>

=cut

# ROUTINE: setFTPDaemon
# Purpose: To set attribtues for ftpdaemon configuration
# set ftpdaemon [rename|passiveftp] <value>
sub setFTPDaemon {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setFTPDaemon");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setFTPDaemon  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setFTPDaemon  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set ftpdaemon %s ",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setFTPDaemon  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setFTPDaemon  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setFTPDaemon  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setFTPClient(KEYVALUEPAIRS)>

  Method to set or alter FTP client configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setFTPClient({<key> => "<value>",
		         ...
		         }
		         );  
  CLI COMMAND (V06.01.03R002):
  set ftpclient [maxretries|retrywait|pushcriteriavalue|pushcriteria] <value>

=cut

# ROUTINE: setFTPClient
# Purpose: To set attribtues for ftpclient configuration
# set ftpclient [maxretries|retrywait|pushcriteriavalue|pushcriteria] <value>
sub setFTPClient {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setFTPClient");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setFTPClient  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setFTPClient  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set ftpclient %s ",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setFTPClient  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setFTPClient  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setFTPClient  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setSystem(KEYVALUEPAIRS)>

  Method to set or alter system configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setSystem({<key> => "<value>",
		      ...
		      }
		      );  
  CLI COMMAND (V06.01.03R002):
  set system [orphanwindow|dbconn|synchrequest|primaryrequest|haltreplication|outputbatchsize] <value>

=cut

# ROUTINE: setSystem
# Purpose: To set attribtues for system configuration
# set system [orphanwindow|dbconn|synchrequest|primaryrequest|haltreplication|outputbatchsize] <value>
sub setSystem_dsi {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setSystem  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setSystem  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set ftpclient %s ",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setSystem  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setSystem  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setSystem  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setStreamStats(NAME,OPTION)>

  Method to set or alter stream statistics configuration attributes.
  Method accepts NAME and OPTION, representing the attributes of the CLI command.    
  Example: 
  $dsicli->setStreamStats(NAME, OPTION);  
  CLI COMMAND (V06.01.03R002):
  set streamstats [<name> reset|shutdown]

=cut

# ROUTINE: setStreamStats
# Purpose: To set attribtues for streamstats configuration
# set streamstats [<name> reset|shutdown]
sub setStreamStats {
    my ($self,$name,$option)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setStreamStats");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setStreamStats  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($name) && defined($option)){
        $logger->warn(__PACKAGE__ . ".setStreamStats  ARGUMENTS MISSING.  PLEASE PROVIDE STREAMSTATS NAME AND OPTION");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    
    $cmd = sprintf("set streamstats %s %s ",$name, $option);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setStreamStats  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setStreamStats  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setStreamStats  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setLogLevel(CSV LIST)>

  Method to set or alter log level configuration attributes.
  Method accepts an enquoted, delimited set of logging levels (ex: "+APPT,-APPT"), representing the attributes of the CLI command.
  Positive and negative signs for each logging level are required.    
  Example: 
  $dsicli->setLogLevel("+OPTION1,-OPTION2,.....");  
  CLI COMMAND (V06.01.03R002):
  set loglevel (+|-)XXXX

=cut


# *** FIX ***
# ROUTINE: setLogLevel
# Purpose: To set the DSI logging level
# set loglevel (+|-)XXXX
sub setLogLevel {
    my($self, $level)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setLogLevel");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setLogLevel  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    my (@validLogLevels,@cmdResults,$cmd,$logLevel,$logAction,$flag);
    @validLogLevels = ("INFP","INFT","SYSE","SYSW","SYST","APPE","APPW","APPT","MI_E","MI_W","MI_T","DB_E","DB_W","DB_T","AUDE","AUDW","AUDT");
    $flag = 1; # Assume everything will go OK
    $logger->info(__PACKAGE__ . ".setLogLevel  SETTING LOGLEVEL(S)");
    foreach (split(/,/,$level)) {
        $_ =~ /([+|-])(\S+)/;
        $logLevel = uc($2);
        $logAction = $1;
        if(grep /$logLevel/i, @validLogLevels) {
            $cmd = sprintf("set loglevel %s", uc($_));
            @cmdResults = $self->execCmd($cmd);
            if($logAction eq "+"){
                if(grep /$logLevel/is, @cmdResults) {
                    $logger->info(__PACKAGE__ . ".setLogLevel  LOGLEVEL $_ SET");
                }else{
                    $logger->warn(__PACKAGE__ . ".setLogLevel  LOGLEVEL $_ WAS NOT SET");
                    $flag=0;
                }
            }elsif($logAction eq "-"){
                if(grep /$logLevel/is, @cmdResults) {
                    $logger->warn(__PACKAGE__ . ".setLogLevel  LOGLEVEL $_ WAS NOT UNSET");
                    $flag=0;
                }else{
                    $logger->info(__PACKAGE__ . ".setLogLevel  LOGLEVEL $_ WAS UNSET");
                }
            }
        }else{
            $logger->warn(__PACKAGE__ . ".setLogLevel  LOGLEVEL $_ INVALID.  IGNORING.");
        }
    }
    return $flag; 
}


################### Set opmode using ECLI #############################


sub setOpmode_ECLI {
    my ($self,$mode)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setOpmode_ECLI");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setOpmode_ECLI  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($mode)){
        $logger->warn(__PACKAGE__ . ".setOpmode_ECLI  ARGUMENTS MISSING.  PLEASE PROVIDE OPMODE");

        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("license opmode set mode %s active 1 ",$mode);
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setOpmode_ECLI  CMD RESULTS:");
    foreach(@cmdResults) {
        if((m/.*$mode is enabled/i) || (m/.*$mode is already enabled/i)){
            $logger->info(__PACKAGE__ . ".setOpmode_ECLI  $_ ");
            $flag = 1;
        }else {
            $flag = 0;
            $logger->info(__PACKAGE__ . ".setOpmode_ECLI  $_");
       }
    }
    $logger->info(__PACKAGE__ . ".setOpmode_ECLI  $_");
    return $flag;
}






=head1 B<setPorts(KEYVALUEPAIRS)>

  Method to set or alter system port configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setPorts({<key> => "<value>",
		      ...
		      }
		      );  
  CLI COMMAND (V06.01.03R002):
  set ports [ftp|telnet|amaftp|amatelnet] <port-value>

=cut

# ROUTINE: setPorts
# Purpose: To set attribtues for system configuration
# set ports [ftp|telnet|amaftp|amatelnet] <port-value>
sub setPorts {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setPorts");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setPorts  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setPorts  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set ports %s ",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setPorts  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setPorts  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setPorts  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setLoadPolicy(LOAD POLICY)>

  Method to set or alter load policy configuration attributes.
  Method accepts string, representing the one of the settable attributes of the CLI command.    
  Example: 
  $dsicli->setLoadPolicy("VALID LOAD POLICY");  
  CLI COMMAND (V06.01.03R002):
  set loadpolicy [WeightedRoundRobin|LeastLoaded|RoundRobin]

=cut

# ROUTINE: setLoadPolicy
# Purpose: To set attribtues for system configuration
# set loadpolicy [WeightedRoundRobin|LeastLoaded|RoundRobin]
sub setLoadPolicy {
    my ($self,$policy)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setLoadPolicy");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setLoadPolicy  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($policy)){
        $logger->warn(__PACKAGE__ . ".setLoadPolicy  ARGUMENTS MISSING.  PLEASE PROVIDE LOAD POLICY");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("set loadpolicy %s ",$policy);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setLoadPolicy  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setLoadPolicy  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setLoadPolicy  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setAlarmConf(KEYVALUEPAIRS)>

  Method to set or alter alarm configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setAlarmConf({<key> => "<value>",
		         ...
		         }
		         );  
  CLI COMMAND (V06.01.03R002):
  set alarmconf [connectiontype|enableincomingidle|incomingidletimer|enableoutgoingidle|outgoingidletimer] <value>

=cut

# ROUTINE: setAlarmConf
# Purpose: To set attribtues for system configuration
# set alarmconf [connectiontype|enableincomingidle|incomingidletimer|enableoutgoingidle|outgoingidletimer] <value>
sub setAlarmConf {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setAlarmConf");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setAlarmConf  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setAlarmConf  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set alarmconf %s ",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setAlarmConf  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setAlarmConf  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setAlarmConf  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setMaint(OPTION)>

  Method to set or alter maintenance level configuration attributes.
  Method accepts string, representing the one of the settable attributes of the CLI command.    
  Example: 
  $dsicli->setMaint("ON");  
  CLI COMMAND (V06.01.03R002):
  set maint <on/off>

=cut

# *** FIX ***
# ROUTINE: setMaint
# Purpose: To set the DSI maint level
# set maint <on/off>
sub setMaint {
    my ($self,$maintLevel)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setMaint");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setMaint  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    my (@cmdResults,$cmd);
    $cmd = sprintf("set maint %s",lc($maintLevel));
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setMaint  CMD RESULTS:");
    foreach(@cmdResults) {
        if(lc($maintLevel) eq "on") {
            if((!m/.*OK/i) && (!m/Maintenance.*in.*progress.*/i)){
               $logger->warn(__PACKAGE__ . ".setMaint  $_");
                return 0;
            }
        }elsif(lc($maintLevel) eq "off") {
            if((!m/.*OK/i) && (!m/Maintenance.*not.*progress.*/i)){
                $logger->warn(__PACKAGE__ . ".setMaint  $_");
                return 0;
            }
        }
        $logger->info(__PACKAGE__ . ".setMaint  $_");
    }
    return 1;
}

=head1 B<setSRS(OPTION)>

  Method to set or alter SRS level configuration attributes.
  Method accepts string, representing the one of the settable attributes of the CLI command.    
  Example: 
  $dsicli->setSRS("ON");  
  CLI COMMAND (V06.01.03R002):
  set srs <on/off>

=cut

# *** FIX ***
# ROUTINE: setSRS
# Purpose: To set srs on / off
# set srs <on/off>
sub setSRS {
    my ($self,$option)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSRS");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setSRS  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    my (@cmdResults,$cmd);
    $cmd = sprintf("set srs %s",lc($option));
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setSRS  CMD RESULTS:");
    foreach(@cmdResults) {
        if(lc($option) eq "on") {
            if(!m//i){
               $logger->warn(__PACKAGE__ . ".setSRS  $_");
                return 0;
            }
        }elsif(lc($option) eq "off") {
            if(!m//i){
                $logger->warn(__PACKAGE__ . ".setSRS  $_");
                return 0;
            }
        }
        $logger->info(__PACKAGE__ . ".setSRS  $_");
    }
    return 1;
}

=head1 B<setSRSconfig(KEYVALUEPAIRS)>

  Method to set or alter SRS configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setSRSconfig({<key> => "<value>",
		         ...
		         }
		         );  
  CLI COMMAND (V06.01.03R002):
  set srsconfig user <username> pass <password> sid <SID> workdir <path> controlfile <filename> llogfile <path> lsleep <sleep period> 
  ltimeout <seconds> rscriptdir <path> routputdir <path> rprocessdir <path>

=cut

# ROUTINE: setSRSconfig
# Purpose: To set srs configuration item.
# set srsconfig user <username> pass <password> sid <SID> workdir <path> controlfile <filename> llogfile <path> lsleep <sleep period> ltimeout <seconds> rscriptdir <path> routputdir <path> rprocessdir <path>
sub setSRSconfig {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSRSconfig");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setSRSconfig  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setSRSconfig  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set srsconfig %s",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setSRSconfig  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setSRSconfig  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setSRSconfig  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setVRS(OPTION)>

  Method to set or alter VRS level configuration attributes.
  Method accepts string, representing the one of the settable attributes of the CLI command.    
  Example: 
  $dsicli->setVRS("ON");  
  CLI COMMAND (V06.01.03R002):
  set vrs <on/off>

=cut

# *** FIX ***
# ROUTINE: setVRS
# Purpose: To set vrs on / off
# set vrs <on/off>
sub setVRS {
    my ($self,$maintLevel)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setVRS");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setVRS  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    my (@cmdResults,$cmd);
    $cmd = sprintf("set vrs %s",lc($maintLevel));
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setVRS  CMD RESULTS:");
    foreach(@cmdResults) {
        if(lc($maintLevel) eq "on") {
            if(!m//i){
               $logger->warn(__PACKAGE__ . ".setVRS  $_");
                return 0;
            }
        }elsif(lc($maintLevel) eq "off") {
            if(!m//i){
                $logger->warn(__PACKAGE__ . ".setVRS  $_");
                return 0;
            }
        }
        $logger->info(__PACKAGE__ . ".setVRS  $_");
    }
    return 1;
}

=head1 B<setVRSconfig(KEYVALUEPAIRS)>

  Method to set or alter VRS configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setVRSconfig({<key> => "<value>",
		         ...
		         }
		         );  
  CLI COMMAND (V06.01.03R002):
  set vrsconfig user <username> pass <password> sid <SID> lsleep <sleep period> lworkdir <path> lprocessdir <path> 
  larchivedir <path> lcontrolfile <name> llogfile <path> rscriptdir <path> routputdir <path> rprocessdir <path> 

=cut

# ROUTINE: setVRSconfig
# Purpose: To set vrs configuration item.
# set vrsconfig user <username> pass <password> sid <SID> lsleep <sleep period> lworkdir <path> lprocessdir <path> larchivedir <path> lcontrolfile <name> llogfile <path> rscriptdir <path> routputdir <path> rprocessdir <path> 
sub setVRSconfig {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setVRSconfig");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setVRSconfig  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setVRSconfig  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set vrsconfig %s",$cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setVRSconfig  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setVRSconfig  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setVRSconfig  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<setOpmode(INT MODE, STRING STATE, OPTIONAL STRING USERNAME, OPTIONAL STRING PASSWORD)>

  Method to set or alter operation mode configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.
  Example: 
  $dsicli->setOpmode(1,'y');  
  CLI COMMAND (V06.01.03R002):
  set opmode [mode|active|username|password] <value>

=cut

# ROUTINE: setOpmode
# Purpose: To set opmode
# set opmode [mode|active|username|password] <value>
sub setOpmode {
    my ($self,$mode, $state, $username, $password)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setOpmode");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setOpmode  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($mode) && defined($state)){
        $logger->warn(__PACKAGE__ . ".setOpmode  ARGUMENTS MISSING.  PLEASE PROVIDE BOTH MODE AND STATE");
        return 0;
    };
    if(($mode == 2)){
	unless(defined($username) && defined($password)){
        $logger->warn(__PACKAGE__ . ".setOpmode  ARGUMENTS MISSING.  OPMODE 2 REQUIRES USERNAME AND PASSWORD");
        return 0;
    };
    }
    my $cmd = sprintf("set opmode mode %s active %s ",$mode, $state);
    if(defined($username) && defined($password)){
	$cmd = sprintf("$cmd username %s password %s",$username, $password);
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    my @cmdResults = $self->execCmd($cmd);
    $logger->debug(__PACKAGE__ . ".setOpmode  CMD RESULTS:");
    foreach(@cmdResults) {
        $logger->debug(__PACKAGE__ . ".setOpmode  $_");
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    $logger->debug(__PACKAGE__ . ".setOpmode  GIVING 10 SECONDS FOR PROCESS DEPLOYMENT/RETRACTION");
    sleep(10); 
	# Ternary conditional op - sets the rollback state to the opposite of the state specified
    # in the call to this function.  First match the current opmode state with the desired state
    # then provide the opposite state as a rollback state.

    if( $self->verifyOpmode($mode) == (($state =~ m/[y|1]/i) ? 1 : 0) )
    {
	    my $rstate = ($state =~ m/[y|1]/i) ? 'n' : 'y';
	    push(@{$self->{STACK}},['setOpmode',[$mode, $rstate, $username, $password]]);
	    return 1;
    }else{
	    return 0;
    }
}

=head1 B<setDiskUsage(INTERVAL,KEYVALUEPAIRS)>

  Method to set or alter disk usage configuration attributes.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->setDiskUsage(INTERVAL, {<key> => "<value>",
				   ...
				   }
				   );  
  CLI COMMAND (V06.01.03R002):
  set disk usage <50|75|90|98> [scan <seconds> | repeat <seconds> | rmfiles <[0,4294967295]|-1> | raise <alarm-id> | clear <alarm-id>]

=cut

# ROUTINE: setDiskUsage
# Purpose: To set attribtues for diskusage configuration
# set disk usage <50|75|90|98> [scan <seconds> | repeat <seconds> | rmfiles <[0,4294967295]|-1> | raise <alarm-id> | clear <alarm-id>]
sub setDiskUsage {
    my ($self, $interval, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setDiskUsage");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".setDiskUsage  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($interval) && defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".setDiskUsage  ARGUMENTS MISSING.  PLEASE PROVIDE DISK USAGE INTERVAL AND KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("set diskusage %s %s ",$interval, $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".setDiskUsage  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".setDiskUsage  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".setDiskUsage  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

# GET ROUTINES FOR CLI
# --------------------

=head1 B<getHouseKeepingID(NAME)>

  Method to get housekeeping ID for a given housekeeping task name.
  This will attempt to retrieve the housekeeping id for the specified name.  If the name does not exist, it will return 0.
  0 is not a valid housekeeping ID.
  This will retrive the first instance of a task containing the specified name.  Housekeeping task names are supposed to be unique.  
  Example: 
  $kddiHKid = $dsicli->getHouseKeepingID("kddi");  

=cut

# ROUTINE: getHouseKeeping
# Purpose: To get housekeeping ID for a specified housekeeping task
sub getHouseKeeping {
    my ($self, $name)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".getHouseKeeping");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".getHouseKeeping  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless($name){
        $logger->warn(__PACKAGE__ . ".getHouseKeeping  ARGUMENTS MISSING.  PLEASE PROVIDE HOUSEKEEPING TASK NAME");
        
        return 0;
    };
    my $cmd = "show housekeeping";
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    my $flag = 0; # Assume housekeeping task will not be found
    my @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".getHouseKeeping  CMD RESULTS:");
    foreach(@cmdResults) {
	my($taskID,$taskName) = split($_);
        if($taskName =~ /^$name$/i){  # hopefully an extact match
            $logger->info(__PACKAGE__ . ".getHouseKeeping  RETRIEVED HOUSKEEPING ID FOR TASK: $taskName");
            $flag = $taskID;
            last;
        }
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;  # should return 0 or $taskID
}

# UPDATE ROUTINES FOR CLI
# ------------------------

=head1 B<updateFields(TYPE,VERSION, RECORD, KEYVALUEPAIRS)>

  Method to set or alter stream statistics configuration attributes.
  Method accepts NAME and OPTION, representing the attributes of the CLI command.    
  Example: 
  $dsicli->updateFields(TYPE,VERSION, RECORD, {<key> => "<value>",
				               ...
                                              });  
  CLI COMMAND (V06.01.03R002):
  update fields type <element> version <number> record <name> fieldids <(field-id | lower - upper),* | all | nil>

=cut

# *** FIX ***
# ROUTINE: updateFields
# Purpose: To set attribtues for system configuration
# update fields type <element> version <number> record <name> fieldids <(field-id | lower - upper),* | all | nil>
sub updateFields {
    my ($self, $type, $version, $record, $keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".updateFields");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".updateFields  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($type) && defined($version) && defined($record) && defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".updateFields  ARGUMENTS MISSING.  PLEASE PROVIDE TYPE, VERSION, RECORD AND FIELD ID KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = sprintf("update fields type %s version %s record %s fieldids %s ",$type, $version, $record, $cmdTmp);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".updateFields  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".updateFields  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".updateFields  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}


# ADD ROUTINES FOR CLI
# ------------------------

=head1 B<addCnode(KEYVALUEPAIRS)>

  Method to add compute node to cluster configuration.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->addCnode({<key> => "<value>",
		         ...
		         }
		         );  
  CLI COMMAND (V06.01.03R002):
  add cnode name <hostname> priip <host or ip on private LAN1> secip <host or ip on private LAN2>

=cut

# ROUTINE: addCnode
# Purpose: To add cnode to primary node
# add cnode name <hostname> priip <host or ip on private LAN1> secip <host or ip on private LAN2>
sub addCnode {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".addCnode");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".addCnode  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".addCnode  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = "add cnode " . $cmdTmp;
    $flag = 1; # Assume add will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".addCnode  CMD RESULTS:");
    foreach(@cmdResults) {
        if((!m/.*OK/i) && (!m/Node.*added/i)){
            $logger->warn(__PACKAGE__ . ".addCnode  $_");
            print "WARN: ". __PACKAGE__ . ".addCnode  $_\n";
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".addCnode  $_");
        
    }
    return $flag;
}

=head1 B<addMnode(KEYVALUEPAIRS)>

  Method to add master node to cluster configuration.
  Method accepts a hash of key value pairs, representing the attributes of the CLI command.
  Key value pairs represent keyword parameters and values that will be assigned to them.  
  Example: 
  $dsicli->addMnode({<key> => "<value>",
		         ...
		         }
		         );  
  CLI COMMAND (V06.01.03R002):
  add mnode name <hostname> rephost <direct cabled replication hostname> nondsihost <hostname of non-dsi server> 
  priip <host or ip on private LAN1> priport <port on private LAN1, default 15711> secip <host or ip on private LAN2> 
  secport <port on private LAN2, default 15711>

=cut

# ROUTINE: addMnode
# Purpose: To add cnode to primary node

#To add a master node to the cluster :
#add mnode name <hostname> rephost <direct cabled replication hostname> nondsihost <hostname of non-dsi server> priip <host or ip on private LAN1> priport <port on private LAN1, default 15711> secip <host or ip on private LAN2> secport <port on private LAN2, default 15711>
#Where the priport, secip and secport are optional
#@reqKeys = ('name','rephost','nondsihost','priip');
#@optKeys = ('priport','secip','secport');
sub addMnode {
    my ($self,$keyVals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".addMnode");
    if(uc($self->{OBJ_NODETYPE}) !~ /PMNODE/){
        $logger->warn(__PACKAGE__ . ".addMnode  MUST PERFORM THIS FUNCTION ON PMNODE");
        return 0;
    }
    unless(defined($keyVals)){
        $logger->warn(__PACKAGE__ . ".addMnode  ARGUMENTS MISSING.  PLEASE PROVIDE KEY VALUE PAIRS");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag,@reqKeys,@optKeys,$key,$value,$cmdTmp);
    # build command string
    foreach $key (keys %$keyVals) {
      #print "$key => $$keyVals{$key}\n";
      $cmdTmp .= $key . " ". $$keyVals{$key} . " ";
    }
    $cmd = "add mnode " . $cmdTmp;
    $flag = 1; # Assume add will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".addMnode  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m/node.*$keyVals->{name}.*added/i){
            $logger->warn(__PACKAGE__ . ".addMnode  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".addMnode  $_");
        
    }
    return $flag;
}


# INSTALL ROUTINES FOR CLI
# ------------------------

=head1 B<installAdaptor(PACKAGE, ADAPTOR)>

  Method to install adaptor using package.
  Method accepts PACKAGE AND ADAPTOR representing the attributes of the CLI command.   
  Example: 
  $dsicli->installAdaptor(PACKAGE, ADAPTOR);  
  CLI COMMAND (V06.01.03R002):
  install package <package> adaptor <adaptor>

=cut

# ROUTINE: installAdaptor
# Purpose: To install package/adaptor
# install package <package> adaptor <adaptor> 
sub installAdaptor {
    my ($self,$package,$adaptor)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".installAdaptor");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".installAdaptor  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    my(@cmdResults,$cmd,$flag);
    unless(defined($adaptor) && defined($package)){
        $logger->warn(__PACKAGE__ . ".installAdaptor  ARGUMENTS MISSING.  PLEASE PROVIDE PACKAGE,ADAPTOR");
        
        return 0;
    };
    $cmd = sprintf("install package %s adaptor %s",uc($package),lc($adaptor));
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    # verify package(s) installed
    $logger->info(__PACKAGE__ . ".installAdaptor  CMD RESULTS:");
    
    foreach(@cmdResults) {
        if(!m/.*OK/i){
            $logger->warn(__PACKAGE__ . ".installAdaptor  $_");
            $flag = 0;
        }
        $logger->info(__PACKAGE__ . ".installAdaptor  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}


# DELETE ROUTINES FOR CLI
# -----------------------

=head1 B<deleteAdbi(ID)>

  Method to delete ancillary database interface.
  Method accepts ID representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteAdbi(ID);  
  CLI COMMAND (V06.01.03R002):
  delete adbi <id>

=cut

# ROUTINE: deleteAdbi
# Purpose: To delete ancillary database interface
# delete adbi <id>
sub deleteAdbi {
    my ($self, $id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteAdbi");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteAdbi  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".deleteAdbi  ARGUMENTS MISSING.  PLEASE PROVIDE DATA MANAGER NUMBER");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("delete adbi ",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteAdbi  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".deleteAdbi  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteAdbi  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

# DELETE ROUTINES FOR CLI
# -----------------------

=head1 B<deleteDm(ID)>

  Method to delete data manager interface.
  Method accepts ID representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteDm(ID);  
  CLI COMMAND (V06.01.03R002):
  delete dm[1-4]

=cut

# ROUTINE: deleteDm
# Purpose: To delete data manager interface
# delete dm[1-4]
sub deleteDm {
    my ($self, $id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteDm");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteDm  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".deleteDm  ARGUMENTS MISSING.  PLEASE PROVIDE DATA MANAGER NUMBER");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("delete dm%s ",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteDm  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".deleteDm  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteDm  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteConnector(ID)>

  Method to delete connector interface.
  Method accepts ID representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteConnector(ID);  
  CLI COMMAND (V06.01.03R002):
  delete connector <id>

=cut

# ROUTINE: deleteConnector
# Purpose: To delete connector definition
# delete connector <id>
sub deleteConnector {
    my ($self,$id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createDm");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteConnector  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".deleteConnector  ARGUMENTS MISSING.  PLEASE PROVIDE CONNECTOR ID");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    
    $cmd = sprintf("delete connector %s ",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteConnector  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".deleteConnector  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteConnector  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteRoute(ID)>

  Method to delete route interface.
  Method accepts ID representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteRoute(ID);  
  CLI COMMAND (V06.01.03R002):
  delete route <id>

=cut

# ROUTINE: deleteRoute
# delete route <id>
sub deleteRoute {
    my ($self,$id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".createDm");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteRoute  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".deleteRoute  ARGUMENTS MISSING.  PLEASE PROVIDE ROUTE ID");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    
    $cmd = sprintf("delete route %s ",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteRoute  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".deleteRoute  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteRoute  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteHouseKeeping(ID)>

  Method to delete housekeeping task.
  Method accepts ID representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteHouseKeeping(ID);  
  CLI COMMAND (V06.01.03R002):
  delete housekeeping <id>

=cut

# ROUTINE: deleteHouseKeeping
# delete housekeeping <id>
sub deleteHouseKeeping {
    my ($self,$id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteHouseKeeping");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteHouseKeeping  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".deleteHouseKeeping  ARGUMENTS MISSING.  PLEASE PROVIDE HOUSEKEEPING ID");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    
    $cmd = sprintf("delete housekeeping %s ",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteHouseKeeping  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m/housekeeping.*job.*removed/i){
            $logger->warn(__PACKAGE__ . ".deleteHouseKeeping  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteHouseKeeping  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteCommRoute(NAME)>

  Method to delete communication route.
  Method accepts NAME representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteCommRoute(NAME);  
  CLI COMMAND (V06.01.03R002):
  delete commroute <name>

=cut


# ROUTINE: deleteCommRoute
# delete commroute <name>
sub deleteCommRoute {
    my ($self,$id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteCommRoute");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteCommRoute  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".deleteCommRoute  ARGUMENTS MISSING.  PLEASE PROVIDE COMMROUTE ID");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    
    $cmd = sprintf("delete commroute %s ",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteCommRoute  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".deleteCommRoute  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteCommRoute  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteClientCommRoute(NAME)>

  Method to delete client communication route.
  Method accepts NAME representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteClientCommRoute(NAME);  
  CLI COMMAND (V06.01.03R002):
  delete client commroute <name>

=cut

# ROUTINE: deleteClientCommRoute
# delete client commroute <name>
sub deleteClientCommRoute {
    my ($self,$id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteClientCommRoute");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteClientCommRoute  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".deleteClientCommRoute  ARGUMENTS MISSING.  PLEASE PROVIDE CLIENT COMMROUTE ID");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    
    $cmd = sprintf("delete client commroute %s ",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteClientCommRoute  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".deleteClientCommRoute  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteClientCommRoute  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteSaiConfig(NAME)>

  Method to delete SAI configuration.
  Method accepts NAME representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteSaiConfig(NAME);  
  CLI COMMAND (V06.01.03R002):
  delete saiconfig <name>

=cut

# ROUTINE: deleteSaiConfig
# delete saiconfig <name>
sub deleteSaiConfig {
    my ($self,$id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteSaiConfig");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteSaiConfig  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".deleteSaiConfig  ARGUMENTS MISSING.  PLEASE PROVIDE CLIENT COMMROUTE ID");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    
    $cmd = sprintf("delete saiconfig %s ",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteSaiConfig  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m/deleted/i){
            $logger->warn(__PACKAGE__ . ".deleteSaiConfig  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteSaiConfig  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteStreamConfig(NAME)>

  Method to delete stream configuration.
  Method accepts NAME representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteStreamConfig(NAME);  
  CLI COMMAND (V06.01.03R002):
  delete streamconfig <name>

=cut

# ROUTINE: deleteStreamConfig
#delete streamconfig <name>
sub deleteStreamConfig {
    my ($self,$id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteStreamConfig");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteStreamConfig  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".deleteStreamConfig  ARGUMENTS MISSING.  PLEASE PROVIDE CLIENT COMMROUTE ID");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    
    $cmd = sprintf("delete streamconfig %s ",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteStreamConfig  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".deleteStreamConfig  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteStreamConfig  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteAdaptor(NAME)>

  Method to delete adaptor.
  Method accepts NAME representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteAdaptor(NAME);  
  CLI COMMAND (V06.01.03R002):
  delete adaptor <name>

=cut

# ROUTINE: deleteAdaptor
#delete adaptor <name>
sub deleteAdaptor {
    my ($self,$id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteAdaptor");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteAdaptor  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".deleteAdaptor  ARGUMENTS MISSING.  PLEASE PROVIDE ADAPTOR NAME");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    
    $cmd = sprintf("delete adaptor %s ",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteAdaptor  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m/Adaptor.*deleted/i){
            $logger->warn(__PACKAGE__ . ".deleteAdaptor  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteAdaptor  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteCodeset(CODESET TABLE, CODESET KEY)>

  Method to delete adaptor.
  Method accepts CODESET TABLE NAME AND CODESET KEY representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteCodeset("VA", "VIRGINIA");  
  CLI COMMAND (V06.01.03R002):
  delete codeset <codeset table> <codeset key>

=cut

# ROUTINE: deleteCodeset
# Purpose: To delete codeset <ccodesset table> <codeset entry>
# delete codeset <codeset table> <codeset key>
sub deleteCodeset {
    my ($self,$codeSetTable, $codeSetEntry)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteCodeset");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteCodeset  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($codeSetTable) && defined($codeSetEntry)){
        $logger->warn(__PACKAGE__ . ".deleteCodeset  ARGUMENTS MISSING.  PLEASE PROVIDE CODESET  TABLE AND ENTRY");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    
    $cmd = sprintf("delete codeset %s \"%s\"", $codeSetTable, $codeSetEntry);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteCodeset  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".deleteCodeset  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteCodeset  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteCorrelateRule(RULE NAME, SENSOR ID)>

  Method to delete correlation rule/sensor id.
  Method accepts RULE NAME AND SENSOR ID representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteCorrelateRule("rulename", "sensorid value");  
  CLI COMMAND (V06.01.03R002):
  delete correlaterule <rulename> sensorid <sensorid value>

=cut

# ROUTINE: deleteCorrelateRule
# Purpose: To delete sensorid from correlate rule for DSI
# create/delete correlaterule <rulename> sensorid <sensorid value>
sub deleteCorrelateRule {
    my ($self,$ruleName, $sensorid)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteCorrelateRule");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteCorrelateRule  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($ruleName) && defined($sensorid)){
        $logger->warn(__PACKAGE__ . ".deleteCorrelateRule  ARGUMENTS MISSING.  PLEASE PROVIDE RULE NAME AND SENSORID");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("delete correlaterule %s sensorid %s",$ruleName, $sensorid);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteCorrelateRule  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".deleteCorrelateRule  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteCorrelateRule  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteDSTdest(ID)>

  Method to delete DST trasporter destination.
  Method accepts ID representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteDSTdest(ID);  
  CLI COMMAND (V06.01.03R002):
  delete dstdest <ID>

=cut

# ROUTINE: deleteDSTdest
# Purpose: To delete dstdest
# delete dstdest <ID>
sub deleteDSTdest {
    my ($self,$id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteDSTdest");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteDSTdst  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".deleteDSTdest  ARGUMENTS MISSING.  PLEASE PROVIDE DSTSRC ID");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("delete dstdest %s ",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteDSTdest  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".deleteDSTdest  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteDSTdest  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteDSTdest(ID)>

  Method to delete DST trasporter source.
  Method accepts ID representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteDSTsrc(ID);  
  CLI COMMAND (V06.01.03R002):
  delete dstsrc <ID>

=cut

# ROUTINE: deleteDSTsrc
# Purpose: To delete dstsrc 
# delete dstsrc <ID>
sub deleteDSTsrc {
    my ($self,$id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteDSTsrc");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteDSTsrc  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".deleteDSTsrc  ARGUMENTS MISSING.  PLEASE PROVIDE DSTSRC ID");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("delete dstsrc %s ",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteDSTsrc  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".deleteDSTsrc  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteDSTsrc  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteFSsrc(ID)>

  Method to delete fileservices source.
  Method accepts ID representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteFSsrc(ID);  
  CLI COMMAND (V06.01.03R002):
  delete fileservices source  <ID>

=cut

# ROUTINE: deleteFSsrc
# Purpose: To delete fileservces source
# delete fileservices source  <ID>
sub deleteFSsrc {
    my ($self,$keyvals)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteFSsrc");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteFSsrc  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($keyvals->{name})){
        $logger->warn(__PACKAGE__ . ".deleteFSsrc  ARGUMENTS MISSING.  PLEASE PROVIDE NAME ELEMENT");
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("delete fileservices source %s ", $keyvals->{name});
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 0; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteFSsrc  CMD RESULTS:");
    foreach(@cmdResults) {
	chomp($_);
        if(m/definition.*removed/i){
            $logger->warn(__PACKAGE__ . ".deleteFSsrc  $_ (SOURCE REMOVED).");
            $flag = 1;
            next;
        }
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

=head1 B<deleteNode(NAME)>

  Method to delete node from cluster configuration.
  Method accepts NAME representing the attributes of the CLI command.    
  Example: 
  $dsicli->deleteNode(NAME);  
  CLI COMMAND (V06.01.03R002):
  delete node <NAME>

=cut

# ROUTINE: deleteNode
# Purpose: To delete node from primary node/cluster
sub deleteNode {
    my ($self,$node)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".deleteNode");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".deleteNode  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($node)){
        $logger->warn(__PACKAGE__ . ".deleteNode  ARGUMENTS MISSING.  PLEASE PROVIDE NODE NAME");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("delete node %s",$node);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".deleteNode  CMD RESULTS:");
    foreach(@cmdResults) {
        if((!m/.*OK/i) && (!m/Node.*deleted/i)){
            $logger->warn(__PACKAGE__ . ".deleteNode  $_");
            print "WARN: ". __PACKAGE__ . ".deleteNode  $_\n";
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".deleteNode  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;

}

# VERIFY ROUTINES FOR CLI
# -----------------------

# ROUTINE: verifyAdaptor
# Purpose: To verify adaptor installation
sub verifyAdaptor {
    my ($self,$adaptor)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyAdaptor");
    my(@cmdResults,$cmd, $flag);
    $cmd = "show adaptors";
    unless(defined($adaptor)){
        $logger->warn(__PACKAGE__ . ".verifyAdaptor  ARGUMENTS MISSING.  PLEASE PROVIDE ADAPTOR NAME");
        return 0;
    };
    @cmdResults = $self->execCmd($cmd);
    # verify package(s) installed
    $flag = 0; # assume adaptor is missing
    foreach(@cmdResults) {
        if(m/^$adaptor$/i){
            $logger->info(__PACKAGE__ . ".verifyAdaptor  ADAPTOR [$adaptor] VERIFIED");
            $flag = 1;
            last;
        }
    }
    if(!$flag){
        $logger->warn(__PACKAGE__ . ".verifyAdaptor  ADAPTOR [$adaptor] NOT VERIFIED");
    }
    return $flag;
}
# ROUTINE: verifyAdaptorVersion
# Purpose: To verify package/adaptor installation and version
sub verifyAdaptorVersion {
    my ($self,$package)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyAdaptorVersion");
    my(@cmdResults,$cmd, $flag);
    $cmd = "show version";
    unless(defined($package)){
        $logger->warn(__PACKAGE__ . ".verifyAdaptorVersion  ARGUMENTS MISSING.  PLEASE PROVIDE PACKAGE NAME");
        print "MISSING\n";
        return 0;
    };    
    @cmdResults = $self->execCmd($cmd);
    $flag = 0; # assume package is missing
    foreach(@cmdResults) {
        if(m/^$package$/i){
            $logger->info(__PACKAGE__ . ".verifyAdaptorVersion  ADAPTOR/PACKAGE [$package] VERSION VERIFIED");
            
            $flag = 1;
            last;
        }
    }
    if(!$flag){
        $logger->warn(__PACKAGE__ . ".verifyAdaptorVersion  ADAPTOR/PACKAGE [$package] VERSION NOT VERIFIED");
        
    }
    return $flag;
}

# ROUTINE: verifyPackageContents
# Purpose: To verify package/adaptor contents
sub verifyPackageContents {
    my ($self,$package,$adaptor)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyPackageContents");
    my(@cmdResults,$cmd, $flag);
    $cmd = sprintf("show package %s",$package);
    unless(defined($package) && defined($adaptor)){
        $logger->warn(__PACKAGE__ . ".verifyAdaptorVersion  ARGUMENTS MISSING.  PLEASE PROVIDE PACKAGE, ADAPTOR NAMES");
        print "MISSING\n";
        return 0;
    };
    @cmdResults = $self->execCmd($cmd);
    $flag = 0; # assume package is missing
    foreach(@cmdResults) {
        if(m/^$adaptor$/i){
            $logger->info(__PACKAGE__ . ".verifyAdaptorVersion  PACKAGE [$package] ADAPTOR [$adaptor] VERSION VERIFIED");
            
            $flag = 1;
            last;
        }
    }
    if(!$flag){
        $logger->warn(__PACKAGE__ . ".verifyAdaptorVersion  PACKAGE [$package] ADAPTOR [$adaptor] VERSION NOT VERIFIED");
        
    }
    return $flag;
}
# ROUTINE: verifyStatusProcess
# Purpose: To verify process id's via the CLI status command
sub verifyStatusProcess {
    my ($self,$process)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".verifyStatusProcess");
    if(uc($self->{OBJ_NODETYPE}) !~ /MNODE/){
        $logger->warn(__PACKAGE__ . ".verifyStatusProcess  MUST PERFORM THIS FUNCTION ON MNODE");
        return 0;
    }
    unless(defined($process)){
        $logger->warn(__PACKAGE__ . ".verifyStatusProcess  ARGUMENTS MISSING.  PLEASE PROVIDE PROCESS TO VERIFY");
        return 0;
    };
    my(@cmdResults,$cmd,$flag,$key,$value,$cmdTmp);
    # build command string
    $cmd = "status";
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 0; # Assume cmd will not work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".verifyStatusProcess  CMD RESULTS:");
    foreach(@cmdResults) {
	chomp($_);
        if(m/$process\s(\d+)/i){
            $logger->info(__PACKAGE__ . ".verifyStatusProcess  $_ (PROCESS VERIFIED)");
            $flag = 1;
            next;
        }else{
	    $logger->info(__PACKAGE__ . ".verifyStatusProcess  $_");
	}
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

# MISC ROUTINES FOR CLI
# -----------------------


# ROUTINE: bootstrap
# Purpose: To bootstrap node
# bootstrap
sub bootstrap {
    my ($self,$all)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".bootstrap");    
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = "bootstrap";
		if(defined($all)){
		  $cmd .= " all";
		}
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".bootstrap  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".bootstrap  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".bootstrap  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}
# ROUTINE: bootstrapRemote
# Purpose: To bootstrap remote node
# bootstrap remote <node name>:
sub bootstrapRemote {
    my ($self,$nodeName)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".bootstrapRemote");    
    unless(defined($nodeName)){
        $logger->warn(__PACKAGE__ . ".bootstrapRemote  ARGUMENTS MISSING.  PLEASE PROVIDE NODE NAME");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("bootstrap remote %s",$nodeName);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".bootstrapRemote  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".bootstrapRemote  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".bootstrapRemote  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

# ROUTINE: clearAlarm
# Purpose: To clearalarm
# clearalarm <alarm id> | all
sub clearAlarm {
    my ($self,$id)=@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".clearAlarm");    
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".clearAlarm  ARGUMENTS MISSING.  PLEASE PROVIDE ALARM ID");
        
        return 0;
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = sprintf("clearalarm %s",$id);
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 1; # Assume cmd will work
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".clearAlarm  CMD RESULTS:");
    foreach(@cmdResults) {
        if(!m//i){
            $logger->warn(__PACKAGE__ . ".clearAlarm  $_");
            $flag = 0;
            next;
        }
        $logger->info(__PACKAGE__ . ".clearAlarm  $_");
        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}

# ROUTINE: reloadFS
# Purpose: reload File services
# reload fileservices
sub reloadFS {
    my ($self,$id)=@_;
    my($regex);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".reloadFS");    
    unless(defined($id)){
        $logger->warn(__PACKAGE__ . ".reloadFS  ARGUMENT MISSING.  FS SOURCE ID WILL BE BLANK");
	$id = "";
    };
    my(@cmdResults,$cmd,$flag);
    # build command string
    $cmd = "reload fileservices";
    if($self->{MAINTMODE}){
        $self->setMaintLevel("on");
    }
    $flag = 0; 
    @cmdResults = $self->execCmd($cmd);
    $logger->info(__PACKAGE__ . ".reloadFS  CMD RESULTS:");
    foreach(@cmdResults) {
        if(m/reload.*signal.*sent/i){ #Currently nothing to verify, as the command will always come back - either showing nothing or the supplied SOURCE ID.
            $logger->info(__PACKAGE__ . ".reloadFS  $_");
            $flag = 1;
            next;
        }        
    }
    if($self->{MAINTMODE}){
        $self->setMaintLevel("off");
    }
    return $flag;
}


sub help(){
  my $cmd="pod2text " . locate __PACKAGE__;
  print `$cmd`;
}

sub usage(){
  my $cmd="pod2usage " . locate __PACKAGE__ ;
  print `$cmd`;
}

sub manhelp(){
  eval {
   require Pod::Help;
   Pod::Help->help(__PACKAGE__);
  };
  if ($@) {
    my $cmd="pod2text " . locate __PACKAGE__ ;
    print `$cmd`;
  }
}

sub closeConn {
  my ($self) = @_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".closeConn");
  $logger->info(__PACKAGE__ . ".closeConn  EXITING CONNECTION");
  if(($self->{OBJ_PORT}) && ( $self->{OBJ_PORT} >= 2000)){  # this is a console session, and must use exit command
    $self->{conn}->cmd("exit");
    $self->{conn}->cmd("exit");
  }
  $logger->info(__PACKAGE__ . ".closeConn  CALLING CLOSE");
  $self->{conn}->close;
}

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
