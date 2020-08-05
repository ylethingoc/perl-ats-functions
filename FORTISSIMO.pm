package SonusQA::FORTISSIMO;

=head1 NAME

SonusQA::FORTISSIMO - Perl module for Sonus Networks FORTISSIMO interaction

=head1 COPYRIGHT

Sonus Networks, Inc.
Confidential and Proprietary.

Copyright (c) 2010 Sonus Networks
All Rights Reserved
Use of copyright notice does not imply publication.
This document contains Confidential Information Trade Secrets, or both which
are the property of Sonus Networks. This document and the information it
contains may not be used disseminated or otherwise disclosed without prior
written consent of Sonus Networks.

=head1 DATE

2010-07-04

=head1 SYSOPSIS

    use ATS; # This is the base class for Automated Testing Structure

    my $FORTISSIMOObj = SonusQA::FORTISSIMO->new(
        -obj_host => "$alias_hashref->{NODE}->{1}->{IP}",
        -obj_commtype => "TELNET",
        %refined_args,
    );

=head1 PARAMETER DESCRIPTIONS:

    OBJ_HOST
        The connection address for this object.  Typically this will be a resolvable (DNS) host name or a specific IP Address.
    OBJ_COMMTYPE
        The session or connection type that will be established.

=head1 DESCRIPTION

    The Fortissimo Call Generators are used in applications that require large numbers
    of analog or IP lines or digital spans with a small footprint. They are remotely
    controlled via a workstation and can test complex interactive applications under
    extremely high call loads. They are user configurable to either ANSI or ITU standards
    and provide line or DS3 interfaces. Ameritec QoS software is also available by license.

=head1 AUTHORS

    See Inline documentation for contributors.

=head1 REQUIRES

    Perl5.8.6, Log::Log4perl, POSIX, File::Basename, Module::Locate, Data::Dumper, SonusQA::Utils

=head1 METHODS

=cut

use SonusQA::Utils qw(:all);
use strict;
use Log::Log4perl qw(get_logger :easy );
use Data::Dumper;
use POSIX qw(strftime);
use Module::Locate qw / locate / ;
use File::Basename;


our $VERSION = "1.0";
use vars qw($self);
our @ISA = qw(SonusQA::Base);

=head2 doInitialization()

=over

=item DESCRIPTION:

    Routine to set object defaults and session prompt.
    INITIALIZATION ROUTINES FOR FORTISSIMO

=back

=cut

sub doInitialization {
    my( $self, %args )=@_;
    my $subName = "doInitialization()" ;
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    #Initialising self variables
    $self->{COMMTYPES}  = ["TELNET","TFTP"];
    $self->{COMM_TYPE}  = "TELNET";
    $self->{OBJ_PORT}   = 23;
    $self->{TYPE}   = __PACKAGE__;
    $self->{conn}   = undef;
    $self->{DEFAULTPROMPT}  = '/cmd\>/';
    $self->{PROMPT} = $self->{DEFAULTPROMPT};
    $self->{PATH}   = undef;
    $self->{REVERSE_STACK}  = 1;
    $self->{DEFAULTTIMEOUT} = 10;

    $self->{STATES} = ['Running', 'Stopped', 'Finished', 'Finishing'];

    $logger->debug(__PACKAGE__ . ".$subName: Initialization Complete");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
}

=head2 setSystem()

=over

=item DESCRIPTION:

    This Function is called from Base.pm Currently used to SYNC Ameritec
    Fortissimo tool with ATS Date & time and turn RealTime reports off.

=back

=cut

sub setSystem() {
    my($self)=@_;  # NO args
    my $subName = "setSystem()" ;
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

    unless ( $self->{OBJ_HOSTNAME} ) {
        # WARN until further notice
        $logger->warn(__PACKAGE__ . ".$subName: Hostname variable (via -obj_hostname) not set.");
    }
    my $date = strftime "%Y%m%d", localtime(time);  #As this function gives last two digits of ATS year prefix it with 20
    my $time = strftime "%H%M%S", localtime(time);

    $self->{conn}->cmd_remove_mode (0); # to avoid stripping of output lines

    unless ($self->setClock(
            '-date' => "$date",
            '-time' => "$time",
        ) ) {
        $logger->warn(__PACKAGE__ . ".$subName: ERROR in set_date_time ");
    }
    # set RealTime Report to off
    $self->execCmd('-cmd' => 'RealTime Off' , '-timeout' => 1);

    $logger->debug(__PACKAGE__ . ".$subName: Set System Complete");
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return 1;
}

=head2 execCmd()

=over

=item DESCRIPTION:

    The function is to execute in FORTISSIMO Cmd shell.
    The function will then return 1 or 0 depending on whether the echo command yielded 0 or not.
    ie. in the FORTISSIMO 0 is PASS (and so the perl function returns 1)
    any other value is FAIL (and so the perl function returns 0).
    In the case of timeout 0 is returned.

    The command output from the command is then accessible from $self->{CMDRESULTS}.

=item ARGUMENTS:

    1. The command to be issued
    2. Timeout value (Optional)

=item PACKAGE:

    SonusQA::FORTISSIMO

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1 - success
    0 - failure

=item EXAMPLE:

    my $cmd = 'stop all';

    unless ( $FORTISSIMOObj->execShellCmd(
                -cmd => $cmd,
                -timeout => 30,
                ) ) {
        $TESTSUITE->{$TestId}->{METADATA} .= "Could not execute Shell command \'$cmd\':--\n@{ $FORTISSIMOObj->{CMDRESULTS}}";
        printFailTest (__PACKAGE__, $TestId, "$TESTSUITE->{$TestId}->{METADATA}");
        $logger->error(".$TestId:  Cannot execute Shell command \'$cmd\':--\n@{ $FORTISSIMOObj->{CMDRESULTS}}");
        return 0;
    }
    $logger->debug(".$TestId:  Executed shell command \'$cmd\' - SUCCESS.");

=back

=cut

sub execCmd {
# Due to the frequency of running this command there will only be log output
# if there is a failure

# If successful ther cmd response is stored in $self->{CMDRESULTS}

    my ($self, %args) = @_;
    my $subName   = "execCmd()";
    my $logger= Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");
    my $retValue = 0; # set to fail
    my @cmdResults;

# Check Mandatory Parameters
    unless ( defined $args{"-cmd"} ) {
        $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument \'-cmd\' has not been specified or is blank.");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return 0;
    }

    my %a = (
        -cmd => '',
        -timeout => $self->{DEFAULTTIMEOUT},
    );

    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }
#    $self->_info( -subName => $subName, %a );

    $self->{LASTCMD}= $args{-cmd};
    $self->{CMDRESULTS} = ();

    my $timestamp = $self->getTime();

    $self->{conn}->buffer_empty;
    unless ( @cmdResults = $self->{conn}->cmd (
            -string  => $a{-cmd},
            -timeout => $a{-timeout},
        ) ) {
        $logger->warn(__PACKAGE__ . ".$subName: ERROR CMD TIMEOUT or ATS FAILED TO EXECUTE: \'$a{-cmd}\'");
        $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $retValue;
    }

    foreach(@cmdResults) {
        if( $_ =~ /Error:\s+(\d+)\s+\-\s+([\S\s]+)/i ) {
            # command has produced an error. This maybe intended, but the least we can do is warn
            $logger->warn(__PACKAGE__ . ".$subName:  COMMAND ERROR. CMD: \'$a{-cmd}\'");
            $logger->warn(__PACKAGE__ . ".$subName:  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
            $logger->warn(__PACKAGE__ . ".$subName:  Command   : $a{-cmd}");
            $logger->warn(__PACKAGE__ . ".$subName:  ERROR CODE: $1");
            $logger->warn(__PACKAGE__ . ".$subName:  ERROR MSG : $2");
            $logger->warn(__PACKAGE__ . ".$subName:  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
            $logger->debug(__PACKAGE__ .".$subName: <-- Leaving Sub [0]");
            push( @{$self->{CMDRESULTS}}, @cmdResults );
            push( @{$self->{HISTORY}}, "$timestamp :: $a{-cmd}" );
            return $retValue;
        }
    }
    $retValue = 1 ;
    $logger->debug(__PACKAGE__ . ".$subName:  CLI command executed successfully");
    $logger->debug(__PACKAGE__ . ".$subName:  cmd result = @cmdResults");

#@cmdResults = grep /\S/, @cmdResults; # remove empty elements or spaces in the array

    chomp(@cmdResults);
    push( @{$self->{CMDRESULTS}}, @cmdResults );
    push( @{$self->{HISTORY}}, "$timestamp :: $a{-cmd}" );


    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return $retValue;
}

=head2 downloadConfiguration()

=over

=item DESCRIPTION:

    Connects to the tftp server on <IP Address>, port 69 (or <port#> if specified)
    and transfers file <file name> from the server to the unit. If a valid
    configuration file, loads the configuration in to the unit.
    Verifies/cross checks whether the configuration is loaded properly

=item ARGUMENTS:

    1. configuration file name <MANDATROY>
    2. tftp ip address

=item PACKAGE:

    SonusQA::FORTISSIMO

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    showConfigurationInformation

=item OUTPUT:

    1 on success
    0 on failure

=item EXAMPLE:

        unless($fortissimoObj->downloadConfiguration($configuration_file $tftpIPaddress)){
            $logger->error(" $sub .FAILED Download Configuration Failed");
            return 0;
        }

=back

=cut

sub downloadConfiguration{
    my( $self,$configurationFileName,$tftpIPaddress )=@_;
    my $subName = "downloadConfiguration()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    my $retValue = 0 ; # FAIL
    my $configurationFilePath = $self->{PATH};
    $logger->info(__PACKAGE__ . ".$subName: --> Entered Sub");

    unless ( defined ( $configurationFilePath ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  The mandatory $configurationFilePath Configuration file Path is missing or blank.");
        $logger->debug(__PACKAGE__ . ".$subName:  <-- Leaving sub. [0]");
        return $retValue;
    }

    unless ( defined ( $configurationFileName ) ) {
        $logger->error(__PACKAGE__ . ".$subName:  The mandatory Configuration file name is missing or blank.");
        $logger->debug(__PACKAGE__ . ".$subName:  <-- Leaving sub. [0]");
        return $retValue;
    }

    unless ( defined ( $tftpIPaddress ) ) {
        $tftpIPaddress = $self->{TMS_ALIAS_DATA}->{'TFTP'}->{'1'}->{'IP'};
        chomp($tftpIPaddress);
        $logger->debug(__PACKAGE__ . ".$subName:  The TFTP IP $tftpIPaddress retrieved from TMS.");
        unless ( defined ($tftpIPaddress)){
            $logger->error(__PACKAGE__ . ".$subName:  The TFTP IP is blank or empty");
            $logger->info( ".$subName: <-- Leaving Sub [0]");
            return $retValue;
        }
    }

    my $cmd = "LOAD \"$configurationFilePath\/$configurationFileName\" $tftpIPaddress";

    unless ( $self->execCmd('-cmd' => $cmd , '-timeout' => 8) ) {
        $logger->debug(__PACKAGE__ . ".$subName: FAILED - to load CONFIGURATION  ($cmd)");
        return $retValue;
    } else {
        $logger->info("$subName . Loading Configuration file $configurationFileName SUCCESS");
    }

    unless ( grep (/$configurationFileName/, $self->showConfigurationInformation ) ) {
        $logger->error("$subName . MISMATCH in Configuration file @{$self->{CMDRESULTS}} & $configurationFileName FAILED");
        return $retValue;
    }

    $retValue = 1 ;
    $logger->info("$subName . Loading Configuration file $configurationFileName SUCCESS");
    $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return $retValue;
}

=head2 setClock()

=over

=item DESCRIPTION:

    Sets the unit clock to the date/time specified by yyyymmddhhmmss.
    Leading zeros for all parameters are required. Hours are specified in 24-hour clock format.
    The clock command with no parameters returns the current system time in
    date format as specified in the DateFormat command with the time in the hh:mm:ss format.

=item Arguments:

    1. Date - mandatory  20070616
    2.time - mandatory   150000

=item Returns:

    Nothing

=item Examples:

    unless ($self->setClock(
                '-date' => "$date",
                '-time' => "$time",
                   ) );
    Clock 20070616150000 // Set to 3:00 pm on June 16, 2007

=back

=cut

sub setClock {
    my ( $self, %args ) = @_;
    my $subName = "setClock()";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");


# Check Mandatory Parameters
    foreach ( qw/ date time / ) {
        unless ( defined ( $args{"-$_"} ) ) {
            $logger->error(__PACKAGE__ . ".$subName:  The mandatory argument for -$_ has not been specified or is blank.");
            $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            return 0;
        }
    }

    my %a;
    while ( my ($key, $value) = each %args ) { $a{$key} = $value; }

#    $self->_info( '-subName' => $subName, %a );

    my $cmd = 'Clock ' ."$a{'-date'}" . "$a{'-time'}";
    $self->execCmd( -cmd => "$cmd" ) ;

    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub ");
}

=head2 showConfigurationInformation()

=over

=item DESCRIPTION:

    Displays the name of the loaded configuration file
    The command output from the command is then accessible from $self->{CMDRESULTS}.

=item ARGUMENTS:

    1. The command to be issued (configuration)
    2. Timeout value (Optional)

=item PACKAGE:

    SonusQA::FORTISSIMO

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    COnfiguration file name loaded

=item EXAMPLE:

    my $cmd = 'Configuration';
    my @cmdResults ;

    unless (@cmdResults = $self->execCmd('-cmd' => $cmd , '-timeout' => 1)) {
        $logger->debug(__PACKAGE__ . ".$subName: Fortissimo command Failed ($cmd)");
    }
   else{
    $logger->debug(__PACKAGE__ . ".$subName: SUCCESS - Fortissimo command ($cmd)");
   }

=back

=cut

sub showConfigurationInformation {
    my($self)=@_;
    my $subName = "showConfigurationInformation()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->info(__PACKAGE__ . ".$subName: --> Entered Sub");

    my $retValue = 0 ; # FAIL
    my $cmd = 'Configuration';

    unless ( $self->execCmd('-cmd' => $cmd  ) ) {
        $logger->error(__PACKAGE__ . ".$subName: FAILED - Fortissimo  command  ($cmd)");
        return $retValue;
    }

    unless( @{$self->{CMDRESULTS}} ) {
        $logger->error(__PACKAGE__ . ".$subName: FAILED to capture or store the $cmd output");
        return $retValue;
    }

#    $logger->debug(__PACKAGE__ . ".$subName: SUCCESS - $cmd loaded currently is @{$self->{CMDRESULTS}}");
    $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [ @{$self->{CMDRESULTS}} ]");
    return @{$self->{CMDRESULTS}};
}

=head2 getState()

=over

=item DESCRIPTION:

    Queries the run state of the unit

=item ARGUMENTS:

    Nothing

=item PACKAGE:

    SonusQA::FORTISSIMO

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

        1 on success returns Running  or Stopped or Finished or Finishing
        0 on failure

=item EXAMPLE:

     my ( $result, $state ) = $self->getState();

=back

=cut

sub getState {
    my($self)=@_;
    my $subName = "getState()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->info(__PACKAGE__ . ".$subName: --> Entered Sub");

    my $retValue = 0 ; # FAIL
    my $cmd = 'State';
    my $currentState ;

    unless ( $self->execCmd('-cmd' => $cmd  ) ) {
        $logger->error(__PACKAGE__ . ".$subName: FAILED - Fortissimo  command  ($cmd)");
        return $retValue;
    }

    unless( @{$self->{CMDRESULTS}} ) {
        $logger->error(__PACKAGE__ . ".$subName: FAILED to capture or store the $cmd output");
        return $retValue;
    }

    foreach (@{$self->{STATES}}) {
        my $state = $_ ;
        foreach ( @{$self->{CMDRESULTS}} ) {
            if ( $_ eq $state ) {
                $currentState = $_ ;
                $retValue = 1;
                last;
            }
        }
        if ( defined $currentState ) {
            last;
        }
    }

    $retValue = 1 ;
    $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [$retValue] $currentState");
    return ( $retValue, $currentState );
}

=head2 runCmd()

=over

=item DESCRIPTION:

    Starts the currently loaded test

=item ARGUMENTS:

    Nothing

=item PACKAGE:

    SonusQA::FORTISSIMO

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    getState()

=item OUTPUT:

    1 on  success
    0 on Failure

=item EXAMPLE:

    unless ($fortissimoObj->runCmd){
        $logger->error(" $sub .FAILED to complete runCmd()");
        return 0;
    }

=back

=cut

sub runCmd {
    my($self)=@_;
    my $subName = "runCmd()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->info(__PACKAGE__ . ".$subName: --> Entered Sub");

    my $retValue = 0 ; # FAIL
    my $cmd = 'Run All';

    my ( $result, $state ) = $self->getState();
    unless ($result) {
        $logger->error(__PACKAGE__ . ".$subName:  FAILED - getState()");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $retValue;
    }
    # check the unit pre state is 'Stopped'
    unless ( $state eq "Stopped" ) {
        $logger->error(__PACKAGE__ . ".$subName:  FAILED Current state : $state expected state : Stopped");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $retValue;
    }

    unless ( $self->execCmd('-cmd' => $cmd   ) ) {
        $logger->error(__PACKAGE__ . ".$subName: FAILED - Fortissimo  command  ($cmd)");
        $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
        return $retValue;
    }

    $retValue = 1 ;
    $logger->info(__PACKAGE__ . ".$subName: SUCCESS ");
    $logger->info(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
    return $retValue;
}

=head2 checkForStatistics()

=over

=item DESCRIPTION:

    Generates a statistics report based on the input parameters. 
    The 'Data Type' parameter determines whether the report will be for the standard call attempts
    and completes data, or the extended error reports from the specified script.
    The 'Report Type' parameter determines whether the report will be a Summary report

    Once the statistics are collected its compared to analyse the call Success & failure rate

=item ARGUMENTS:

    1. The command to be issued (configuration)
    2. Timeout value (Optional)

=item PACKAGE:

    SonusQA::FORTISSIMO

=item GLOBAL VARIABLES USED:

    None

=item EXTERNAL FUNCTIONS USED:

    None

=item OUTPUT:

    1 - Success
    0 - Failure


=item EXAMPLE:

    my $cmd = 'Statistics Standard Summary';
    my @cmdResults ;
    unless (@cmdResults = $self->execCmd('-cmd' => $cmd , '-timeout' => 1)) {

        $logger->debug(__PACKAGE__ . ".$subName: Fortissimo command Failed ($cmd)");
    }

=back

=cut

sub checkForStatistics {
    my($self)=@_;
    my $retvalue = 0 ; # set to fail
    my $subName = "checkForStatistics()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");
    my $cmd = 'Statistics Standard Summary';
    my @cmdResults ;
    unless (@cmdResults = $self->execCmd('-cmd' => $cmd ) ){
        $logger->debug(__PACKAGE__ . ".$subName: Fortissimo command Failed ($cmd)");
    }
    else{
        $logger->debug(__PACKAGE__ . ".$subName: SUCCESS - Fortissimo command ($cmd)");
    }

    foreach (  @{$self->{CMDRESULTS}} ) {
        if(/.*\S+\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
         # $1 = Orig Attmpt $2 = Orig Compl $3= Term Attmpt $4= Term Compl
            if ($1>0 && $3>0 && $2==$4) {
                $logger->debug(__PACKAGE__ . ".$subName: SUCCESS :  ");
                $retvalue = 1 ; # Pass
                $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
            }
            else {
                $logger->debug(__PACKAGE__ . ".$subName: ERROR : Test Failed $1 = Orig Attmpt $2 = Orig Compl $3= Term Attmpt $4= Term Compl ");
                $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            }
        }
        elsif(/.*\S+\s+(\d+)\s+(\d+)/) {
	    if ($1 == $2){
                $logger->debug(__PACKAGE__ . ".$subName: SUCCESS :  ");
                $retvalue = 1 ; # Pass
                $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [1]");
            }
	    else{
               $logger->debug(__PACKAGE__ . ".$subName: ERROR : Test Failed $1 = Attmpt $2 = Compl ");
               $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub [0]");
            }
        }
    }
    return $retvalue;
}

=head2 _info

=over

=item DESCRIPTION:

    subroutine to print all arguments passed to a sub.
    Used for debuging only.

=back

=cut

sub _info {
    my ($self, %args) = @_;
    my @info = %args;
    my $logger = Log::Log4perl->get_logger("_info");

    unless ($args{-subName}) {
        $logger->error("._info Argument \"-subName\" must be specified and not be blank. $args{-subName}");
        return 0;
    }

    $logger->debug(".$args{-subName} ===================================");
    $logger->debug(".$args{-subName} Entering $args{-subName} function");
    $logger->debug(".$args{-subName} ===================================");

    foreach ( keys %args ) {
        if (defined $args{$_}) {
            $logger->debug(".$args{-subName}\t$_ => $args{$_}");
        } else {
            $logger->debug(".$args{-subName}\t$_ => undef");
        }
    }

    $logger->debug(".$args{-subName} ===================================");

    return 1;
}

=head2 DESTROY

=over

=item DESCRIPTION:

    Override the DESTROY method inherited from Base.pm in order to remove any config if we bail out.

=back

=cut

sub DESTROY {
    my ($self,@args)=@_;
    my $subName: = "DESTROY()";
    my $logger;

    unless ( Log::Log4perl->initialized() ) {
# No, not initialized yet ...
        Log::Log4perl->easy_init($DEBUG);
    }
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$subName");
    $logger->debug(__PACKAGE__ . ".$subName: --> Entered Sub");

# Fall thru to regulare Base::DESTROY method.
    SonusQA::Base::DESTROY($self);
    $logger->debug(__PACKAGE__ . ".$subName: <-- Leaving Sub");
}

=head2 AUTOLOAD

=over

=item DESCRIPTION:

 This subroutine will be called if any undefined subroutine is called.

=back

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

__END__
