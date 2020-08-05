package SonusQA::GSX::ART;

=head1 NAME

SonusQA::GSX::ART - Perl module for Sonus UK GSX ART functions.

=head1 SYNOPSIS

run_art [options]

 Options:
    -cfg <ART tool cfg file>
        ART tool configuration file containing variables and functions for ART run - mandatory

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, Sonus::QA::Utils, Data::Dumper

=head1 DESCRIPTION

=head2 METHODS

=cut

use Module::Locate qw(locate);
use Pod::Usage;
use Getopt::Long qw(GetOptions);
use Log::Log4perl qw(get_logger :easy :levels);
use Data::Dumper;
use Switch;
use SonusQA::SGX;
use SonusQA::GSX;
use SonusQA::GSX::UKLogParser;
use SonusQA::Utils;
use SonusQA::MGTS;
use SonusQA::PSX;
use SonusQA::EMSCLI;
use SonusQA::GBL;
use SonusQA::ATSHELPER;
use Tie::DxHash;
use Time::HiRes qw(gettimeofday tv_interval);

# Define global %artcfg variable to represent ART tool configuration file
our %artcfg = ();
our %testcfg = ();

=head1 B<SonusQA::GSX::DESTROY()>

  Override the GSX object destroy method so that we can close the GSX logs cleanly before the GSX object gets destroyed

=over 6

=item Package:

 SonusQA::GSX::ART

=back

=cut

sub SonusQA::GSX::DESTROY {
    my ($self)=@_;
    my ($logger);
    my $sub = "SonusQA::GSX.DESTROY";
    if(Log::Log4perl::initialized()){
        $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".DESTROY");
    }else{
        $logger = Log::Log4perl->easy_init($DEBUG);
    }

    $logger->debug("$sub Entered function");

    $self->{HISTORY} = ();

    if (defined($artobj->{GSX})) {
        # Stop any xtail processes started for gsx
        # Loop thru GSX objects in $artobj->{GSX}
        foreach my $gsxObj ( @{$artobj->{GSX}} )
        {
            if (exists($gsxObj->{GSX_LOG_INFO}->{PID})) {
                my $procList = $gsxObj->{GSX_LOG_INFO}->{PID}->{ACT} . "," . 
                               $gsxObj->{GSX_LOG_INFO}->{PID}->{DBG} . "," . 
                               $gsxObj->{GSX_LOG_INFO}->{PID}->{SYS} . "," . 
                               $gsxObj->{GSX_LOG_INFO}->{PID}->{TRC}; 
                $logger->debug(__PACKAGE__ . ".$sub stopping logging on GSX \"$gsxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}\" procList-$procList.");
            
                $gsxObj->gsxLogStop(-process_list => "$procList");
                $logger->debug("$sub Stopped GSX Xtail processes " . $procList);
            } else {
                $logger->debug("$sub No GSX Log Xtail processes to stop.");
            }
        }
    }

    if($self->can("_DUMPSTACK") && defined($self->{DUMPSTACK}) && $self->{DUMPSTACK}){
	$self->_DUMPSTACK();
    }else{
	 $logger->debug("$sub OBJECT DOES NOT HAVE DUMPSTACK METHOD (OR NO HISTORY IS AVAILABLE)");
    }
    if($self->can("_REVERSESTACK")  && defined($self->{STACK}) && @{$self->{STACK}}){
	$self->_REVERSESTACK();
    }else{
	 $logger->debug("$sub OBJECT DOES NOT HAVE REVERSESTACK METHOD (OR NO HISTORY IS AVAILABLE)");
    }
    
    if($self->can("_COMMANDHISTORY") && defined($self->{HISTORY}) && @{$self->{HISTORY}}){
	$self->_COMMANDHISTORY();
    }else{
	 $logger->debug("$sub OBJECT DOES NOT HAVE COMMANDHISTORY METHOD (OR NO HISTORY IS AVAILABLE)");
    }
    
    if($self->can("resetNode")){
	$self->resetNode();
    }
    $logger->info("$sub [$self->{OBJ_HOST}] Cleaning up...");
    $logger->debug("$sub [$self->{OBJ_HOST}] Destroying object");
    $self->closeConn();
    $logger->debug("$sub [$self->{OBJ_HOST}] Destroyed object");
}

=head1 B<SonusQA::PSX::DESTROY()>

  Override the PSX object destroy method so that we can close the PSX logs cleanly before the PSX object gets destroyed

=over 6

=item Package:

 SonusQA::GSX::ART

=back

=cut

sub SonusQA::PSX::DESTROY {
    my ($self)=@_;
    my ($logger);
    my $sub = "SonusQA::PSX.DESTROY";
    if(Log::Log4perl::initialized()){
        $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".DESTROY");
    }else{
        $logger = Log::Log4perl->easy_init($DEBUG);
    }

    $logger->debug("$sub Entered function");

    $self->{HISTORY} = ();

    if (defined($artobj->{PSX})) {
        # Stop any xtail processes started for psx
        # Loop thru PSX objects in $artobj->{PSX}
        foreach my $psxObj ( @{$artobj->{PSX}} )
        {
            if (exists($psxObj->{PSX_LOG_INFO}->{PID}->{PES})) {
                $logger->debug(__PACKAGE__ . ".$sub Stopping pes logging on PSX \"$psxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}\" for PID:" . $psxObj->{PSX_LOG_INFO}->{PID}->{PES});
            
                $psxObj->pesLogStop(-pid       => $psxObj->{PSX_LOG_INFO}->{PID}->{PES},
                                    -filename  => $psxObj->{PSX_LOG_INFO}->{LOGNAME}->{PES},
                                    -log_dir   => $artcfg->{USER_LOG_DIR});
                $logger->debug("$sub Stopped PSX PES Log Xtail process " . $psxObj->{PSX_LOG_INFO}->{PID}->{PES});
            } else {
                $logger->debug("$sub No PSX Pes Log Xtail process to stop.");
            }
        }
    }

    if($self->can("_DUMPSTACK") && defined($self->{DUMPSTACK}) && $self->{DUMPSTACK}){
	$self->_DUMPSTACK();
    }else{
	 $logger->debug("$sub OBJECT DOES NOT HAVE DUMPSTACK METHOD (OR NO HISTORY IS AVAILABLE)");
    }
    if($self->can("_REVERSESTACK")  && defined($self->{STACK}) && @{$self->{STACK}}){
	$self->_REVERSESTACK();
    }else{
	 $logger->debug("$sub OBJECT DOES NOT HAVE REVERSESTACK METHOD (OR NO HISTORY IS AVAILABLE)");
    }
    
    if($self->can("_COMMANDHISTORY") && defined($self->{HISTORY}) && @{$self->{HISTORY}}){
	$self->_COMMANDHISTORY();
    }else{
	 $logger->debug("$sub OBJECT DOES NOT HAVE COMMANDHISTORY METHOD (OR NO HISTORY IS AVAILABLE)");
    }
    
    $logger->info("$sub [$self->{OBJ_HOST}] Cleaning up...");
    $logger->debug("$sub [$self->{OBJ_HOST}] Destroying object");
    $self->closeConn();
    $logger->debug("$sub [$self->{OBJ_HOST}] Destroyed object");
}


=head1 B<handleControlC()>

  Typical inner library usage: handleControlC(). This method gets invoked when user hits ^C.

  Ensure all the default PSX commands get executed before destroying the ART objects one by one.

=over 6

=item Arguments:

 None

=item Package:

 SonusQA::GSX::ART

=back

=cut

sub handleControlC
{
    my $sub = "handleControlC()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub Entered $sub function");
   
    # Restore any default PSX commands if appropriate
    unless (defined($testcfg->{EXECUTE_DEFAULT_PSX_CMDS}) && $testcfg->{EXECUTE_DEFAULT_PSX_CMDS} == 0) {	
        # Hash structure is : $testcfg->{DEFAULT_PSX_CMDS}->{$arrayindex}->{$command} = 1;
        if (exists($testcfg->{DEFAULT_PSX_CMDS})) {
            foreach my $index ( keys %{$testcfg->{DEFAULT_PSX_CMDS}})
            {
                for my $command ( keys %{$testcfg->{DEFAULT_PSX_CMDS}->{$index}})
                {
		    my $psx_ind = $index+1;		
                    my $option = "-psx" . $psx_ind;
                    if ( execPsxControl( $option => "$command", -default_psx_cmd => "$command" ) == 0 )
                    {
                        $logger->error(__PACKAGE__ . ".$sub execPsxControl returned error while trying to execute DEFAULT PSX control.");
                        $logger->debug(__PACKAGE__ . "Leaving $sub.");
                        $error_found++; 
                    }
                }
	        delete($testcfg->{DEFAULT_PSX_CMDS}->{$index}); 
            }
        } 
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Bypassing execution of default PSX commands due to \$testcfg->{EXECUTE_DEFAULT_PSX_CMDS} flag being set to '0'");
	$testcfg->{DEFAULT_PSX_CMDS} = ();
	$testcfg->{EXECUTE_DEFAULT_PSX_CMDS} = 1;		
    }


    if (defined($artobj->{GSX}))
    {
        # Stop any xtail processes started for gsx
        # Loop thru GSX objects in $artobj->{GSX}
        foreach my $gsxObj ( @{$artobj->{GSX}} )
        {
            $gsxObj->DESTROY();
        }
    }
    
    if (defined($artobj->{PSX}))
    {
        foreach my $psxObj ( @{$artobj->{PSX}} )
        {
            $psxObj->DESTROY();
        }
    }
    
    
    if (defined($artobj->{EMSCLI}))
    {
        foreach my $emsCliObj ( @{$artobj->{EMSCLI}} )
        {
            $emsCliObj->DESTROY();
        }
    }
    
    if (defined($artobj->{MGTS}))
    {
        foreach my $mgtsObj ( @{$artobj->{MGTS}} )
        {
            $mgtsObj->DESTROY();
        }
    }
    
    if (defined($artobj->{GBL}))
    {
        foreach my $gblObj ( @{$artobj->{GBL}} )
        {
            $gblObj->DESTROY();
        }
    }
    
    $logger->debug(__PACKAGE__ . ".$sub Leaving function\n");
    exit;
}

=head1 B<validateToolCfgVars()>

  Function to validate the variables defined in the ART tool configuration Perl file and initialise global variables required for the ART run.

=over 6

=item RETURNS

    1 - success
    0 - failed

=item Package:

 SonusQA::GSX::ART

=back

=cut

sub validateToolCfgVars {

    my $sub_name = "validateToolCfgVars()"; 
    my $logger;

    unless(defined($artcfg->{LOG_LEVEL})) {
        $artcfg->{LOG_LEVEL} = "INFO";
    } 

    unless (defined($artcfg->{USER_LOG_DIR}) and ("$artcfg->{USER_LOG_DIR}" !~ m/^\s*$/ )) {
        $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
        $logger->error(__PACKAGE__ . ".$sub_name Mandatory \"\$artcfg->\{USER_LOG_DIR\}\" variable not defined or is blank in ART tool cfg file \"$artcfg->{FILENAME}\"");
        exit -1;
    }

    # Slap a trailing slash onto logdir if none specified
    if(!($artcfg->{USER_LOG_DIR} =~ /\/$/)) { $artcfg->{USER_LOG_DIR} .= "/"; }

    # Check for existence of directory - attempt to create if missing - else die, no point in running if we can't log anything.
    if ( !(-d $artcfg->{USER_LOG_DIR}) ) {
        if ( !(mkdir ($artcfg->{USER_LOG_DIR}, 0777) ) ) {
            die "$sub_name - FATAL ERROR - Log Directory $artcfg->{USER_LOG_DIR} does not exist, and unable to create - please check permissions and try again";
        }
    }
    if(Log::Log4perl->initialized()) {
        $logger = Log::Log4perl->get_logger("");
        if ( $artcfg->{LOG_LEVEL} =~ /DEBUG|INFO|WARN|ERROR|FATAL/ ){
            $logger->level(${$artcfg->{LOG_LEVEL}});
            $logger->warn(__PACKAGE__ . ".$sub_name Someone already initialized our logger - changed level to '$artcfg->{LOG_LEVEL}' - please make your checks, this may not be what you want...");
        } else {
            $logger->level($INFO);
            $logger->warn(__PACKAGE__ . ".$sub_name Unknown log level '$artcfg->{LOG_LEVEL}' set in ART tool cfg file \"$artcfg->{FILENAME}\", expected one of DEBUG,INFO,WARN,ERROR,FATAL");
            $logger->warn(__PACKAGE__ . ".$sub_name Someone already initialized our logger - defaulting to 'INFO' level - please make your checks, this may not be what you want...");
        }
        
    } else {
        if ( $artcfg->{LOG_LEVEL} eq "DEBUG" ) {
            $logger = Log::Log4perl->easy_init($DEBUG);
        } elsif ( $artcfg->{LOG_LEVEL} eq "INFO" ) {
            $logger = Log::Log4perl->easy_init($INFO);
        } elsif ( $artcfg->{LOG_LEVEL} eq "WARN" ) {
            $logger = Log::Log4perl->easy_init($WARN);
        } elsif ( $artcfg->{LOG_LEVEL} eq "ERROR" ) {
            $logger = Log::Log4perl->easy_init($ERROR);
        } elsif ( $artcfg->{LOG_LEVEL} eq "FATAL" ) {
            $logger = Log::Log4perl->easy_init($FATAL);
        } else {
            # Default to INFO level logging
            $logger = Log::Log4perl->easy_init($INFO);
            $logger->warn(__PACKAGE__ . ".$sub_name Unknown log level '$artcfg->{LOG_LEVEL}' set in ART tool cfg file \"$artcfg->{FILENAME}\", expected one of DEBUG,INFO,WARN,ERROR,FATAL");
        }
    }

    # Now tailor our default easy_init'd logger to our needs...

    my $result_logger = get_logger("RESULT");
    my $skip_logger = get_logger("SKIP");
    my $date = localtime;
    $date =~ tr/ : /_/;

#    my $layout = Log::Log4perl::Layout::PatternLayout->new("%d %c %m%n");
    my $layout = Log::Log4perl::Layout::PatternLayout->new("%d %-5p %-4L %m%n");

    # Create our new appender and point it to results log file
    # We don't set additivity() since we want these categories of logs to also bubble-up to the root logger.
    my $appender = Log::Log4perl::Appender->new(
        "Log::Dispatch::File",
        filename => $artcfg->{USER_LOG_DIR}."RESULTS_".$date,
    );

    $appender->layout($layout);
    $result_logger->add_appender($appender);

    # Create our new appender and point it to skip log file
    $appender = Log::Log4perl::Appender->new(
        "Log::Dispatch::File",
        filename => $artcfg->{USER_LOG_DIR}."SKIP_".$date,
    );

    $appender->layout($layout);
    $skip_logger->add_appender($appender);

    # Other categories of logger may be inserted here in future, if required.

    # Fixup the root logger
    my $root_logger = get_logger("");
    $appender = Log::Log4perl::Appender->new(
        "Log::Dispatch::File",
        filename => $artcfg->{USER_LOG_DIR}."LOG_".$date,
    );

    $appender->layout($layout);
    $root_logger->add_appender($appender);

    $root_logger->debug(__PACKAGE__ . ".$sub_name All loggers initialized");

    # Initialize some vars (Design step 3.)
    $artobj->{GSX} = $artobj->{PSX} = $artobj->{SGX} = $artobj->{EMSCLI} = $artobj->{MGTS} = $artobj->{GBL} = [];
    %testcfg = ();

    # Init more vars (Design step 4.)
    undef @testgrp_config_stack;

    # HEF - Design says exit with 0, UNIX standard says we should exit with non-zero (Design step 5.)
    unless (checkMandatoryToolCfgVars()) {
        $root_logger->error(__PACKAGE__ . ".$sub_name Failed to parse mandatory tool config variables - exiting");
        exit -1;
    }

    # HEF - Design says exit with 0, UNIX standard says we should exit with non-zero (Design step 6.)
    unless (checkDutAlloc()) {
        $root_logger->error(__PACKAGE__ . ".$sub_name Failed to parse DUT allocation varables - exiting");
        exit -1;
    }

    if( !(defined $artcfg->{MGTS_ALLOC}) ) {
        $root_logger->info(__PACKAGE__ . ".$sub_name No MGTS allocation defined - defaulting to none");
        $artcfg->{MGTS_ALLOC} = [];
    }
    
    if( !(defined $artcfg->{GBL_ALLOC}) ) {
        $root_logger->info(__PACKAGE__ . ".$sub_name No GBL allocation defined - defaulting to none");
        $artcfg->{GBL_ALLOC} = [];
    }

    if( !(defined $artcfg->{TEST_CHECK_REF}) ) {
        $root_logger->info(__PACKAGE__ . ".$sub_name No global post-test check function defined");
    }

    $root_logger->debug(__PACKAGE__ . ".$sub_name returning 1");
    return 1;

}

=head1 B<createArtObjects()>

  Function to create all the ATS objects required for a particular ART run - EMSCLI, GSX, PSX, MGTS and GBL 
  (SGX is created at a later date - see design section 2.1.7.2 for details)  

=over 6

=item RETURNS

 1 - success
 exit(-1)'s on failure.

=item Package:

 SonusQA::GSX::ART

=back

=cut

sub createArtObjects {
    my $sub_name = "createArtObjects()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

     $logger->debug(__PACKAGE__ . ".$sub_name Invoked");

    # Create GSX object(s) - design steps 1 & 2.
    $logger->debug(__PACKAGE__ . ".$sub_name Creating GSX object(s)");
    unless (defined ($artobj->{GSX} = createObjectsFromAliases( -alias_ary => $artcfg->{GSX_ALLOC},
                                                                -obj_type  => "GSX") ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name Failed to create one or more GSX objects from TMS Aliases - exiting");
        exit -1; # HEF - I(malc) modified exit code.
    }

    if ($#{$artobj->{GSX}} == 0) {
        $logger->info(__PACKAGE__ . ".$sub_name Single GSX allocated - duplicating to GSX2 for non GW-GW testing (DISABLED)");
        #$artobj->{GSX}[1] = $artobj->{GSX}[0];
    }

    # PSX object(s) - design steps 3 & 4.
    $logger->debug(__PACKAGE__ . ".$sub_name Creating PSX object(s)");
    unless (defined ($artobj->{PSX} = createObjectsFromAliases( -alias_ary => $artcfg->{PSX_ALLOC},
                                                                -obj_type  => "PSX") ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name Failed to create one or more PSX objects from TMS Aliases - exiting");
        exit -1; # HEF - I(malc) modified exit code.
    }

    if ($#{$artobj->{PSX}} == 0) {
        $logger->info(__PACKAGE__ . ".$sub_name Single PSX allocated - duplicating to PSX2 for GW-GW testing (DISABLED)");
        #$artobj->{PSX}[1] = $artobj->{PSX}[0];
    }

    # EMS CLI object(s) - design steps 5 & 6.
    # Note additional argument to create..Aliases() in this case.
    
    $logger->debug(__PACKAGE__ . ".$sub_name Creating EMS CLI object(s)");
    unless (defined ($artobj->{EMSCLI} = createObjectsFromAliases(-alias_ary => $artcfg->{EMSCLI_ALLOC},
                                                                  -obj_type  => "EMSCLI",
                                                                  -psx_array => $artcfg->{PSX_ALLOC}) ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name Failed to create one or more PSX objects from TMS Aliases - exiting");
        exit -1; # HEF - I(malc) modified exit code.
    }

    if ($#{$artobj->{EMSCLI}} == 0) {
        $logger->info(__PACKAGE__ . ".$sub_name Single EMS CLI allocated - duplicating to EMSCLI2 for GW-GW testing (DISABLED)");
        #$artobj->{EMSCLI}[1] = $artobj->{EMSCLI}[0];
    }

    if ($artcfg->{MGTS_ALLOC}) {
        $logger->debug(__PACKAGE__ . ".$sub_name Creating MGTS object(s)");
        unless (defined ($artobj->{MGTS} = createObjectsFromAliases( -alias_ary => $artcfg->{MGTS_ALLOC},
                                                                     -obj_type  => "MGTS" ) ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name Failed to create one or more MGTS objects from TMS Aliases - exiting");
            exit -1; # HEF - I(malc) modified exit code.
        }
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name No MGTS objects to create");
    }
    

    if ($artcfg->{GBL_ALLOC}) {
        $logger->debug(__PACKAGE__ . ".$sub_name Creating GBL object(s)");
        unless (defined ($artobj->{GBL} = createObjectsFromAliases( -alias_ary => $artcfg->{GBL_ALLOC},
                                                                    -obj_type  => "GBL" ) ) ) {
            $logger->error(__PACKAGE__ . ".$sub_name Failed to create one or more GBL objects from TMS Aliases - exiting");
            exit -1; # HEF - I(malc) modified exit code.
        }
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name No GBL objects to create");
    }

    $logger->debug(__PACKAGE__ . ".$sub_name returning 1");
    return 1;
}


=head1 B<runArt()>

  Function to execute the top-level test group config file.

=over 6

=item RETURNS

 1 - success
 0 - failure

=item Package:

 SonusQA::GSX::ART

=back

=cut

sub runArt {
    my $sub_name = "runArt()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Invoked");
    my $full_testgrp_filename = $artcfg->{TEST_GRP_FILE_DIR} . "/" . $artcfg->{TEST_GRP_FILE};
    $testcfg->{TEST_GRP} =  $artcfg->{TEST_GRP_FILE};
    
    # Check file exists, if so execute it
    if ( -e "$full_testgrp_filename") {
        if ( -z "$full_testgrp_filename") {
            $logger->error(__PACKAGE__ . ".$sub_name Test Group File \"$full_testgrp_filename\" is a zero length file. File is invalid.");
            $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
            return 0;
        }
        unless (my $return_val = do $full_testgrp_filename ) {
            $logger->error(__PACKAGE__ . ".$sub_name Couldn't parse test group configuration file \"$full_testgrp_filename\": $@") if $@;
            $logger->error(__PACKAGE__ . ".$sub_name Couldn't 'do' test group configuration file \"$full_testgrp_filename\": $!") unless defined $return_val ;
            $logger->error(__PACKAGE__ . ".$sub_name Couldn't run test group configuration file \"$full_testgrp_filename\": $!") unless $return_val ;
            $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
            return 1;
        }
        
        $logger->debug(__PACKAGE__ . ".$sub_name returning 1");

        return 1; # HEF - Design conflict - design said to return retval, (which might not be 1 for success depending on what we 'do()') - but preamble says 1=success.
    } else {
        $logger->error(__PACKAGE__ . ".$sub_name Failed to find test group configuration file \"$full_testgrp_filename\"");
        $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
        return 0;
    }

    die "'Unreachable' statement reached, My name is chicken-licken and the sky is falling in";

}

=head1 B<checkMandatoryToolCfgVars()>

  This function ensures that the mandatory variables are defined in the ART tool configuration file. 

=over 6

=item ARGUMENTS:

 None

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 All the global variables should be defined in the ART tool configuration file. This function checks for their existence and values.	
 $artcfg->{PROJECT}
 $artcfg->{TEST_GRP_FILE}
 $artcfg->{TEST_GRP_FILE_DIR}
 $artcfg->{GSX_ALLOC}
 $artcfg->{PSX_ALLOC}
 $artcfg->{EMSCLI_ALLOC}
 $artcfg->{SRC_GSX_IMG_DIR}
 $artcfg->{GSX_IMAGE_VERSIONS}
 $artcfg->{EMAIL}

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - if all mandatory variables successfully validated
 0 - otherwise (failure)

=item EXAMPLE: 

 unless ( checkMandatoryToolCfgVars() ) {
     exit 0;
 }

=back

=cut

sub checkMandatoryToolCfgVars {

    my $sub_name = "checkMandatoryToolCfgVars()";
    my $errors_found = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Entering $sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name Checking mandatory tool cfg vars");

    foreach (qw /TEST_GRP_FILE_DIR TEST_GRP_FILE PROJECT EMAIL/) {
        unless (defined($artcfg->{$_}) and ("$artcfg->{$_}" !~ m/^\s*$/ )) {
            $logger->error(__PACKAGE__ . ".$sub_name Mandatory \"\$artcfg->\{$_\}\" variable not defined or is blank in ART tool cfg file \"$artcfg->{FILENAME}\"");
            $errors_found++;
        }
    }

    if ($#{$artcfg->{GSX_ALLOC}} >= 0) {
        for (my $gsx_index=0; $gsx_index<= $#{$artcfg->{GSX_ALLOC}}; $gsx_index++) {
            unless (defined($artcfg->{GSX_ALLOC}[$gsx_index]) and ("$artcfg->{GSX_ALLOC}[$gsx_index]" !~ m/^\s*$/ )) {
                $logger->error(__PACKAGE__ . ".$sub_name Mandatory \"\$artcfg->\{GSX_ALLOC\}\[$gsx_index\]\" variable not defined or is blank in ART tool cfg file \"$artcfg->{FILENAME}\"");
                $errors_found++;
            }
        }
    } else {
        $logger->error(__PACKAGE__ . ".$sub_name Mandatory \"\$artcfg->\{GSX_ALLOC\}\" variable not defined or is blank in ART tool cfg file \"$artcfg->{FILENAME}\"");
        $errors_found++;
    }

    foreach (qw /PSX_ALLOC EMSCLI_ALLOC SRC_GSX_IMG_DIR GSX_IMAGE_VERSIONS/) {
        if ($#{$artcfg->{$_}} < 0) {
            $logger->error(__PACKAGE__ . ".$sub_name Mandatory \"\$artcfg->\{$_\}\" variable should have at least one element defined in ART tool cfg file \"$artcfg->{FILENAME}\"");
            $errors_found++;
        }
    }

    if ($errors_found) {
        $logger->error(__PACKAGE__ . ".$sub_name Failed to validate all mandatory variables");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub_name Successfully validated all mandatory variables");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 1;
    }

} # End sub checkMandatoryToolCfgVars

=head1 B<checkDutAlloc()>

  This function loops through $artcfg->{GSX_ALLOC} calling sub-functions to validate $artcfg->{SRC_GSX_IMG_DIR}, $artcfg->{GSX_IMAGE_VERSIONS}, 
  $artcfg->{PSX_ALLOC} and $artcfg->{EMSCLI_ALLOC} ART tool configuration file defined variables.

=over 6

=item ARGUMENTS:

 None

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $artcfg->{GSX_ALLOC}

=item EXTERNAL FUNCTIONS USED:

 checkGsxImagesAlloc()
 checkGsxImageVersionsAlloc()
 checkPsxAlloc()
 checkEmscliAlloc()

=item OUTPUT:

 1 - if validation of all variables is successful
 0 - otherwise.

=item EXAMPLE:

 checkDutAlloc()

=back

=cut

sub checkDutAlloc {

    my $sub_name = "checkDutAlloc()";
    my $errors_found = 0;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Entering $sub_name");
    for (my $gsx_index=0; $gsx_index <= $#{$artcfg->{GSX_ALLOC}}; $gsx_index++) {

        $logger->debug(__PACKAGE__ . ".$sub_name Performing DUT alloc checks for index $gsx_index in \$artcfg->\{GSX_ALLOC\}");
        unless ( checkGsxImagesAlloc($gsx_index) ) {
            $errors_found++;
        }

        unless ( checkGsxImageVersionsAlloc($gsx_index) ) {
            $errors_found++;
        }

        unless ( checkPsxAlloc($gsx_index) ) {
            $errors_found++;
        }

        unless ( checkEmscliAlloc($gsx_index) ) {
            $errors_found++;
        }

    }

    if ($errors_found) {
        $logger->error(__PACKAGE__ . ".$sub_name Failed to validate all DUT alloc variables");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    } else {
        $logger->debug(__PACKAGE__ . ".$sub_name Successfully validated all DUT alloc variables");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 1;
    }

} # End sub checkDutAlloc

=head1 B<checkGsxImagesAlloc()>

  This function checks to see if there any GSX image directories specified to copy images to the relevant GSX.

=over 6

=item ARGUMENTS:

 $array_index - array index from $artcfg->{GSX_ALLOC} used to index the $artcfg->{SRC_GSX_IMG_DIR}.

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $artcfg->{FILENAME}
 $artcfg->{SRC_GSX_IMG_DIR}
 $artcfg->{GSX_ALLOC}

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - if validation of all variables are successful.
 0 - otherwise

=item EXAMPLE:

 unless (checkGsxImagesAlloc($gsx_index)) {
     $errors_found++;
 }

=back

=cut

sub checkGsxImagesAlloc {

    my $array_index = shift;
    my $sub_name = "checkGsxImagesAlloc()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name Entering $sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Checking if there any GSX image directories specified to copy images to the relevant GSX");

    # Check array index is specified and is a digit. Return failure otherwise
    unless ( defined($array_index) && ($array_index !~ m/^\D*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name \$array_index undefined or is not a digit");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0 ;
    }

    # Check if Number of GSX image directories specified is greater than the number of GSX specified
    unless ($#{$artcfg->{SRC_GSX_IMG_DIR}} <= $#{$artcfg->{GSX_ALLOC}}) {
        $logger->error(__PACKAGE__ . ".$sub_name Number of GSX image directories specified is greater than the number of GSX specified in ART tool cfg file \"$artcfg->{FILENAME}\"");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    # Check if $artcfg->{SRC_GSX_IMG_DIR} has one element only ,if so whether it is defined and not blank
    if ($#{$artcfg->{SRC_GSX_IMG_DIR}} == 0) {
        unless (defined($artcfg->{SRC_GSX_IMG_DIR}[0]) && ($artcfg->{SRC_GSX_IMG_DIR}[0] !~ m/^\s*$/)) {
            $logger->error(__PACKAGE__ . ".$sub_name \$artcfg->\{SRC_GSX_IMG_DIR\}\[0\] is not defined or is blank in ART tool cfg file \"$artcfg->{FILENAME}\"");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
    } else {
        # Check if element in $artcfg->{SRC_GSX_IMG_DIR} for specified index is  defined and not blank
        unless (defined($artcfg->{SRC_GSX_IMG_DIR}[$array_index]) && ("$artcfg->{SRC_GSX_IMG_DIR}[$array_index]" !~ m/^\s*$/)) {
            $logger->error(__PACKAGE__ . ".$sub_name \$artcfg->\{SRC_GSX_IMG_DIR\}\[$array_index\] is not defined or is blank in ART tool cfg file \"$artcfg->{FILENAME}\"");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name GSX image directories are specified for the relevant GSX");
    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
    return 1;

} # End sub checkGsxImagesAlloc

=head1 B<checkGsxImageVersionsAlloc()>

  This function checks to see if there any GSX image versions specified to check against the loaded images on the relevant GSX.

=over 6

=item ARGUMENTS:

 $array_index - array index from $artcfg->{GSX_ALLOC} used to index the
 $artcfg->{GSX_IMAGE_VERSIONS}.

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $artcfg->{FILENAME}
 $artcfg->{GSX_IMAGE_VERSIONS}
 $artcfg->{GSX_ALLOC}

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - if validation of all variables are successful.
 0 - otherwise

=item EXAMPLE:

 unless (checkGsxImageVersionsAlloc($array_index)) {
     $logger->debug(__PACKAGE__ . ".$sub_name Exiting function);
     exit 0;
 }

=back

=cut

sub checkGsxImageVersionsAlloc {

    my $array_index = shift;
    my $sub_name = "checkGsxImageVersionsAlloc()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Entering $sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name Checking if there any GSX image versions specified to check against the loaded images on the relevant GSX");

    # Check array index is specified and is a digit. Return failure otherwise
    unless ( defined($array_index) && ($array_index !~ m/^\D*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name \$array_index undefined or is not a digit");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0 ;
    }

    # Check if Number of GSX image versions specified is greater than the number of GSX specified
    unless ($#{$artcfg->{GSX_IMAGE_VERSIONS}} <= $#{$artcfg->{GSX_ALLOC}}) {
        $logger->error(__PACKAGE__ . ".$sub_name Number of GSX image versions specified is greater than the number of GSX specified in ART tool cfg file \"$artcfg->{FILENAME}\"");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    # Check if $artcfg->{GSX_IMAGE_VERSIONS} has one element only ,if so whether it is defined and not blank
    if ($#{$artcfg->{GSX_IMAGE_VERSIONS}} == 0) {
        unless (defined($artcfg->{GSX_IMAGE_VERSIONS}[0]) && ($artcfg->{GSX_IMAGE_VERSIONS}[0] !~ m/^\s*$/)) {
            $logger->error(__PACKAGE__ . ".$sub_name \$artcfg->\{GSX_IMAGE_VERSIONS\}\[0\] is not defined or is blank in ART tool cfg file \"$artcfg->{FILENAME}\"");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
    } else {
        # Check if element in $artcfg->{GSX_IMAGE_VERSIONS} for specified index is  defined and not blank
        unless (defined($artcfg->{GSX_IMAGE_VERSIONS}[$array_index]) && ("$artcfg->{GSX_IMAGE_VERSIONS}[$array_index]" !~ m/^\s*$/)) {
            $logger->error(__PACKAGE__ . ".$sub_name \$artcfg->\{GSX_IMAGE_VERSIONS\}\[$array_index\] is not defined or is blank in ART tool cfg file \"$artcfg->{FILENAME}\"");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name GSX image versions directories are specified for the relevant GSX");
    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
    return 1;

} # End sub checkGsxImageVersionsAlloc

=head1 B<checkPsxAlloc()>

  This function checks which PSX is assigned to each GSX.

=over 6

=item ARGUMENTS:

 $array_index - array index from $artcfg->{GSX_ALLOC} used to index the $artcfg->{PSX_ALLOC}.

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $artcfg->{FILENAME}
 $artcfg->{PSX_ALLOC}
 $artcfg->{GSX_ALLOC}

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - if validation of all variables is successful.
 0 - otherwise

=item EXAMPLE:

 unless (checkPsxAlloc($array_index)) {
     $logger->debug(__PACKAGE__ . ".$sub_name Exiting function);
     exit 0;
 }

=back

=cut

sub checkPsxAlloc {

    my $array_index = shift;
    my $sub_name = "checkPsxAlloc()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Entering $sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name Checking if there any PSX specified for each GSX");

    # Check array index is specified and is a digit. Return failure otherwise
    unless ( defined($array_index) && ($array_index !~ m/^\D*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name \$array_index undefined or is not a digit");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0 ;
    }

    # Check if Number of PSX specified is greater than the number of GSX specified
    unless ($#{$artcfg->{PSX_ALLOC}} <= $#{$artcfg->{GSX_ALLOC}}) {
        $logger->error(__PACKAGE__ . ".$sub_name Number of PSX specified via \$artcfg->{PSX_ALLOC} is greater than the number of GSX specified via \$artcfg->{GSX_ALLOC} in ART tool cfg file \"$artcfg->{FILENAME}\"");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    # Check if $artcfg->{PSX_ALLOC} has one element only ,if so whether it is defined and not blank
    if ($#{$artcfg->{PSX_ALLOC}} == 0) {
        unless (defined($artcfg->{PSX_ALLOC}[0]) && ($artcfg->{PSX_ALLOC}[0] !~ m/^\s*$/)) {
            $lgger->error(__PACKAGE__ . ".$sub_name \$artcfg->\{PSX_ALLOC\}\[0\] is not defined or is blank in ART tool cfg file \"$artcfg->{FILENAME}\"");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
    } else {
        # Check if element in $artcfg->{PSX_ALLOC} for specified index is  defined and not blank
        unless (defined($artcfg->{PSX_ALLOC}[$array_index]) && ("$artcfg->{PSX_ALLOC}[$array_index]" !~ m/^\s*$/)) {
            $logger->error(__PACKAGE__ . ".$sub_name \$artcfg->\{PSX_ALLOC\}\[$array_index\] is not defined or is blank in ART tool cfg file \"$artcfg->{FILENAME}\"");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
    $logger->debug(__PACKAGE__ . ".$sub_name PSX names are specified for the relevant GSX");
    return 1;

} # End sub checkPsxAlloc

=head1 B<checkEmscliAlloc()>

  This function checks which EMS is assigned to each PSX.

=over 6

=item ARGUMENTS:

 Array index from $artcfg->{GSX_ALLOC} used to index the $artcfg->{EMSCLI_ALLOC}.

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED

 $artcfg->{FILENAME}
 $artcfg->{EMSCLI_ALLOC}
 $artcfg->{PSX_ALLOC}

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - if validation of all variables and creation of EMSCLI object is successful.
 0 - otherwise

=item EXAMPLE:

 unless (checkEmscliAlloc($array_index)) {
     $logger->debug(__PACKAGE__ . ".$sub_name Exiting function);
     exit 0;
 }

=back

=cut

sub checkEmscliAlloc {

    my $array_index = shift;
    my $sub_name = "checkEmscliAlloc()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Entering $sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name Checking if there are EMS specified for each PSX");

    # Check array index is specified and is a digit. Return failure otherwise
    unless ( defined($array_index) && ($array_index !~ m/^\D*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name \$array_index undefined or is not a digit");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0 ;
    }

    # Check if Number of EMS specified is greater than the number of PSX specified
    unless ($#{$artcfg->{EMSCLI_ALLOC}} <= $#{$artcfg->{PSX_ALLOC}}) {
        $logger->error(__PACKAGE__ . ".$sub_name Number of EMSCLI specified is greater than the number of PSX specified in ART tool cfg file \"$artcfg->{FILENAME}\"");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    # Check if $artcfg->{EMSCLI_ALLOC} has one element only ,if so whether it is defined and not blank
    if ($#{$artcfg->{EMSCLI_ALLOC}} == 0) {
        unless (defined($artcfg->{EMSCLI_ALLOC}[0]) && ($artcfg->{EMSCLI_ALLOC}[0] !~ m/^\s*$/)) {
            $logger->error(__PACKAGE__ . ".$sub_name \$artcfg->\{EMSCLI_ALLOC\}\[0\] is not defined or is blank in ART tool cfg file \"$artcfg->{FILENAME}\"");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
    } else {
        # Check if element in $artcfg->{EMSCLI_ALLOC} for specified index is  defined and not blank
        unless (defined($artcfg->{EMSCLI_ALLOC}[$array_index]) && ("$artcfg->{EMSCLI_ALLOC}[$array_index]" !~ m/^\s*$/)) {
            $logger->error(__PACKAGE__ . ".$sub_name \$artcfg->\{EMSCLI_ALLOC\}\[$array_index\] is not defined or is blank in ART tool cfg file \"$artcfg->{FILENAME}\"");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
    $logger->debug(__PACKAGE__ . ".$sub_name EMSCLI are specified for the relevant PSX");
    return 1;

} # End sub checkEmscliAlloc

=head1 B<initTestGrpVars()>

    This function initialises the test group configuration variables that need to be reinitialised for each individual test group 
    i.e. the value of the variables cannot be shared between different test group configuration files.
    Called from the setupTestGrpConfig() function.

=over 6

=item ARGUMENTS:

 None

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $testcfg->{TEST_POSITION}
 $testcfg->{USED_MGTS_OBJ}
 $testcfg->{UNUSED_MGTS}
 $testcfg->{USED_GBL_OBJ}
 $testcfg->{UNUSED_GBL}
 $testcfg->{DEFAULT_PSX_CMDS} 
 $artcfg->{MGTS_ALLOC}
 $artcfg->{GBL_ALLOC}

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 Test group variables are defined

=item EXAMPLE: 

 initTestGrpVars()

=back

=cut

sub initTestGrpVars {

    my $sub_name = "initTestGrpVars()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Invoked");

    $testcfg->{TEST_POSITION} = 0;
    $testcfg->{USED_MGTS_OBJ} = [];
    $testcfg->{UNUSED_MGTS} = $artcfg->{MGTS_ALLOC};
    $testcfg->{USED_GBL_OBJ} = [];
    $testcfg->{DEFAULT_PSX_COMMANDS} = (); # NB - This is a hash of hashes.
    $testcfg->{SKIP_GROUP} = 0;
    $logger->debug(__PACKAGE__ . ".$sub_name returning");
    return;

}

=head1 B<linkTestGrp()>

 This function takes a copy of the current test group configuration variables defined under the %testcfg hash and then loads the linked 
 test group configuration file via the Perl 'require' syntax. The function also resets the $testcfg->{MGTS_SEQGRPS} variable.
 This function is called directly from the test group configuration file.

=over 6

=item ARGUMENTS:

 Name of the test group configuration file to load

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $testcfg

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - success and test group configuration file loaded
 exit - otherwise

=item EXAMPLE: 

 linkTestGrp(<test group config file>)

=back

=cut

sub linkTestGrp {

    my $file = shift;
    my $sub_name = "linkTestGrp()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Invoked with arg=\"$file\"");

    # Validate args (Design step 1.)
    if( !($file) ) {
        $logger->error(__PACKAGE__ . ".$sub_name Test group config filename not specified - Exiting");
        exit -1;
    }

    # HEF - Extra step - not in design
    # Validate the file exists at the correct path.
    # I considered pushing TEST_GRP_FILE_DIR to @INC somewhere, and let require do the searching 
    # and reporting, but I didn't want to pickup false matches from elsewhere in @INC.
    unless( -e "$artcfg->{TEST_GRP_FILE_DIR}/$file") {
        $logger->error(__PACKAGE__ . ".$sub_name Test group config file not found \"$artcfg->{TEST_GRP_FILE_DIR}/$file\" - Exiting");
        exit -1;
    }

    # Push the current groups config onto the stack for later retrieval. (Design step 2.)
    push @testgrp_config_stack, $testcfg;

    $testcfg->{MGTS_SEQGRPS} = [];
    $testcfg->{TEST_GRP} = $file;

    # HEF 'require' is going to die() of its own accord if the imported code doesn't return 1 - so we cannot test it's return value to log anything useful.
    # Unless we wrap it in an eval - but this is not called for by the design.
    $logger->info(__PACKAGE__ . ".$sub_name Executing test group config file $file");
    return require "$artcfg->{TEST_GRP_FILE_DIR}/$file";

} # end sub linkTestGrp

=head1 B<checkRequiredMgts()>

 This function validates the number of required MGTS defined in the $testcfg->{REQ_MGTS} array against the length of the $artcfg->{MGTS_ALLOC} array.
 Called from the setupTestGrpConfig() function.

=over 6

=item ARGUMENTS:

 NONE

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $testcfg->{REQ_MGTS}
 $artcfg->{MGTS_ALLOC}

=item EXTERNAL FUNCTIONS USED:

 SonusQA::ART::setSkipGrpData()

=item OUTPUT:

 1 - validation successful
 0 - validation failed

=item EXAMPLE: 

 unless ( $testcfg->{SKIP_GROUP} ) {
     checkRequiredMgts()
 }

=back

=cut

sub checkRequiredMgts {
    my $sub_name = "checkRequiredMgts()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Invoked");

    if($#{$testcfg->{REQ_MGTS}} > 0) {
        unless($#{$artcfg->{MGTS_ALLOC}} >= $#{$testcfg->{REQ_MGTS}}) {

            setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: checkRequiredMgts, Reason: Not enough MGTS allocated in \$artcfg->{MGTS_ALLOC}. Number of required MGTS = " . $#{$testcfg->{REQ_MGTS}} ); 
            $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name returning 1");
    return 1;
}

=head1 B<checkRequiredGbl()>

 This function validates the number of required GBL servers defined in the $testcfg->{REQ_GBL} array against the length of the $artcfg->{GBL_ALLOC} array.
 Called from the setupTestGrpConfig() function.

=over 6

=item ARGUMENTS:

 NONE

=item PACKAGE:

 SonuusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $testcfg->{REQ_GBL}
 $artcfg->{GBL_ALLOC}

=item EXTERNAL FUNCTIONS USED:

 SonusQA::ART::setSkipGrpData()

=item OUTPUT:

 1 - validation successful
 0 - validation failed

=item EXAMPLE: 

 unless ( defined($testcfg->{SKIP_GROUP}) && $testcfg->{SKIP_GROUP} == 1) {
     checkRequiredGbl()
 }

=back

=cut

sub checkRequiredGbl {
    my $sub_name = "checkRequiredGbl()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Invoked");

    if($#{$testcfg->{REQ_GBL}} > 0) {
        unless($#{$artcfg->{GBL_ALLOC}} >= $#{$testcfg->{REQ_GBL}}) {

            setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: checkRequiredGbl, Reason: Not enough GBL servers allocated in \$artcfg->{GBL_ALLOC}. Number of required GBL = " . $#{$testcfg->{REQ_GBL}} ); 
            $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
            return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub_name returning 1");
    return 1;
}

=head1 B<assignRequiredGbl()>

 This function assigns the required GBL servers to the $testcfg->{USED_GBL_OBJ} array based on what is defined in $artcfg->{GBL_ALLOC}. 
 If successful, the $testcfg-> {USED_GBL_OBJ} will be populated with all the required GBL servers.
 Called from the setupTestGrpConfig() function.

=over 6

=item ARGUMENTS:

 NONE

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $testcfg->{USED_GBL_OBJ}
 $testcfg->{REQ_GBL}
 $artcfg->{GBL_ALLOC}

=item EXTERNAL FUNCTIONS USED:

 SonusQA::ART::setSkipGrpData()

=item OUTPUT:

 1 - if GBL servers got assigned successfully
 0 - otherwise (with $testcfg->{SKIP_GROUP} being set)

=item EXAMPLE: 

 unless ( defined($testcfg->{SKIP_GROUP}) && $testcfg->{SKIP_GROUP} == 1) {
      assignRequiredGbl();
 }

=back

=cut

sub assignRequiredGbl {
    my $sub_name = "assignRequiredGbl()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Invoked");

    $testcfg->{USED_GBL_OBJ} = (); # Clear out any previous cruft

    foreach (@{$testcfg->{REQ_GBL}}) {
        $logger->debug(__PACKAGE__ . ".$sub_name LOOP1: Iterator: $_");
        my $match_found = 0;
        LOOP: foreach (@{$_}) {
            $logger->debug(__PACKAGE__ . ".$sub_name \tLOOP2: Iterator: $_");
            my $req_gbl_index = 0;
            foreach $allocated_gbl (@{$artcfg->{GBL_ALLOC}}) {
                $logger->debug(__PACKAGE__ . ".$sub_name \t\tLOOP3: Index $req_gbl_index Iterator: $allocated_gbl");
                if($_ eq $allocated_gbl) {
                    $logger->debug(__PACKAGE__ . ".$sub_name Match found");
                    $match_found = 1;
                    push @{$testcfg->{USED_GBL_OBJ}}, $artobj->{GBL}[$req_gbl_index];
                    last LOOP;
                }
                $req_gbl_index++; 
            }
        }

        unless($match_found) {
            setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: assignRequiredGbl, Reason: Unable to assign GBL server from required GBL list @($_} (required_gbl_list) and allocation list @{$artcfg->{GBL_ALLOC}}"); 
            $logger->info(__PACKAGE__ . ".$sub_name returning 0");
            return 0;
        }
    }
    
    # If we have only allocated a single instance (array length counts from 0...)
    if($#{$testcfg->{USED_GBL_OBJ}} == 0) {
        $logger->debug(__PACKAGE__ . ".$sub_name Duplicating Used GBL Instance 1 from Instance 0");
        $testcfg->{USED_GBL_OBJ}[1] = $testcfg->{USED_GBL_OBJ}[0];
    }
    $logger->debug(__PACKAGE__ . ".$sub_name returning 1");
    return 1;

}

############################################

=head1 B<setSkipGrpData()>

 This function sets the $testcfg->{SKIP_GROUP} flag to 1 to indicate that there is an issue with the test group configuration file and 
 it needs to skip execution of any tests contained within it. 
 The first argument is the string specifying the reason the test or group was skipped and gets printed to the skip test ATS logger file.

=over 6

=item ARGUMENTS:

 1st ARG: Skip reason

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $testcfg->{USED_GROUP}
 $testcfg->{SKIP_REASON}

=item EXTERNAL FUNCTIONS USED:

 NONE.

=item OUTPUT:

 1 - Success
 0 - Failure

 NOTE: Error information is printed to the ATS skip test logger

=item EXAMPLE: 

 setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, Function: randomFunction(), Reason: Failed to find MGTS");

=back

=cut

############################################
sub setSkipGrpData {
############################################

    my $sub_name = "setSkipGrpData()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    # Assuming logger has been initialised
    #
    my $skip_logger = Log::Log4perl->get_logger("SKIP");
    
    $logger->debug(__PACKAGE__ . ".$sub_name ---> Entered $sub_name");

    my $skip_reason         = shift;

    $logger->debug(__PACKAGE__ . ".$sub_name ---> SKIP REASON:\n$skip_reason");

    unless ( defined ( $skip_reason ) && $skip_reason ne "" ) {
        
        $logger->error(__PACKAGE__ . ".$sub Missing or blank information, textual skip reason field required"); 
        return 0;
    }
    else {
        $logger->debug("Setting \$testcfg->{SKIP_REASON} = $skip_reason");
        $testcfg->{SKIP_REASON} = $skip_reason;
    }

    $logger->debug("Setting \$testcfg->{SKIP_GROUP} = 1");
    $testcfg->{SKIP_GROUP}  = 1;

    $skip_logger->debug(__PACKAGE__ . ".$sub_name: $testcfg->{SKIP_REASON} ");

    return 1;    
    
}

############################################

sub getUserFromMgtsPath {
############################################

    my $sub_name = "getUserFromMgtsPath()";
    my $logger  = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    my $path    = shift;

    unless ( defined ( $path ) && $path ne "" ) {
        
        $logger->error(__PACKAGE__ . ".$sub Missing or blank information, path required"); 
        return 0;
    }
    else {
        $logger->debug("Setting \$path = $path");
    }

    if ( $path =~ /\/home\/(\S+)\// ) {

        my $user    = $1;
        $logger->debug("Found user $user from path $path");
        return $user;
    }
    else {
        $logger->error("Cannot find user from path $path");
        return 0;
    }
}
############################################

=head1 B<configureMgts()>

 This function will configure each MGTS being used by copying the MGTS assignment and sequence 
 group files, modifying the Network Maps, UK def.csh file and PASM databases, restarting the 
 MGTS session with the correct protocol for the sequence group and downloading the assignments. 
 The function will return 1 if successful and 0 otherwise. On failure the setSkipGrpData() 
 function will be called to set the skip group flag and the reason why the group is being skipped.

=over 6

=item ARGUMENTS:

 1st ARG: Skip reason

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $testcfg->{USED_MGTS_OBJ}
 $testcfg->{MGTS_ASSIGNMENTS}
 $testcfg->{MGTS_ASSIGN_PATH}
 $testcfg->{MGTS_SEQGRPS}
 $testcfg->{MGTS_SEQGRP_PATH}
 $artobj->{GSX}
 $artobj->{PSX}

=item EXTERNAL FUNCTIONS USED:

 SonusQA::MGTS::uploadFromRepository()
 SonusQA::MGTS::getNetworkMapName()
 SonusQA::MGTS::modifyNetworkMap()
 SonusQA::MGTS::getSeqFlavor()
 SonusQA::MGTS::startSession()
 SonusQA::MGTS::modifyUkDefDotCsh()
 SonusQA::MGTS::modifyUkPasmDB()
 SonusQA::MGTS::downloadAssignment()
 SonusQA::GSX::ART::setSkipGrpData()

=item OUTPUT:

 1 - If all MGTS configuration successful
 0 - Failure 

 NOTE: On failure $testcfg->{SKIP_GROUP} is set via a call to setSkipGrpData()

=back

=cut


############################################
sub configureMgts {
############################################

    my $sub_name = "configureMgts()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    my $mgts_object;
    my $mgts_assignment;
    my $mgts_protocol;                  # Stores return from getSeqFlavor() to be used in startSession()
    my $mgts_index              = 0;
    my %network_map_option      = ();   # Hash to hold values of node and sequence group found in foreach seq grp loop
    my $mgts_assignment_account;        # Variable to hold user name drawn from $testcfg->{MGTS_ASSIGN_PATH}
    my $mgts_seq_grp_account;           # Variable to hold user name drawn from $testcfg->{MGTS_SEQGRP_PATH}

    $logger->debug(__PACKAGE__ . ".$sub_name ---> Entered $sub_name");

    unless( defined ( $testcfg->{USED_MGTS_OBJ} ) && @{ $testcfg->{USED_MGTS_OBJ} } ) { 
        $logger->error(__PACKAGE__ . ".$sub_name ERROR: \$testcfg->{USED_MGTS_OBJ} not defined or empty");
        return 0;
    }

    foreach $mgts_object ( @{ $testcfg->{USED_MGTS_OBJ} } ) {    

        # If the object is blank we should skip
        #
        if ( $mgts_object eq "" ) {
            
            $logger->debug(__PACKAGE__ . ".$sub_name Value of \$testcfg->{USED_MGTS_OBJ} at index $mgts_index is blank. Skipping...");
            $mgts_index++
        }
        else {
            # Buckle up...
            #
            $logger->debug(__PACKAGE__ . ".$sub_name ========================== ");
            $logger->debug(__PACKAGE__ . ".$sub_name     Configuring MGTS $mgts_index");
            $logger->debug(__PACKAGE__ . ".$sub_name ========================== ");

            unless( $mgts_assignment = "$testcfg->{MGTS_ASSIGNMENTS}[$mgts_index]" ) {
                setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                . "Function: configureMgts, "
                                . "Reason: MGTS assignment is blank for MGTS" . ($mgts_index + 1) );
                return 0;
            }

            $logger->debug(__PACKAGE__ . ".$sub_name MGTS assignment is $testcfg->{MGTS_ASSIGNMENTS}[$mgts_index]");            
                
            # Upload MGTS Assignment from Repository
            #
            unless( $mgts_assignment_account = getUserFromMgtsPath( $testcfg->{MGTS_ASSIGN_PATH} ) ) {

                setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                . "Function: configureMgts, "
                                . "Reason: Cannot get user account from MGTS assignment path");
                return 0;
            }

            unless( $mgts_object->uploadFromRepository(-account         => "$mgts_assignment_account",
                                                        -path           => "$testcfg->{MGTS_ASSIGN_PATH}",
                                                        -file_to_copy   => "$mgts_assignment",
                                                      ) ) {
                setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                . "Function: configureMgts, "
                                . "Reason: Failed to copy MGTS assignment file");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name Uploaded MGTS Assignment from Repository");
    
            # Get Network Map from MGTS assignment
            #
            unless( $mgts_object->getNetworkMapName(-assignment => $mgts_assignment) ) {
                
                setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                . "Function: configureMgts, "
                                . "Reason: Failed to get Network Map name from MGTS assignment file");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name Got Network Map from Assignment. \$mgts_object->{NETMAP} set to $mgts_object->{NETMAP}");

            # Loop through node name/sequence group name pairs defined in $testcfg->{MGTS_SEQGRPS} to copy
            # MGTS sequence group files and modify network maps
            #
            my $node_count          = 1;    # Incremented in foreach loop
    
            unless (defined($testcfg->{MGTS_SEQGRPS}) && $testcfg->{MGTS_SEQGRPS}[$mgts_index] ne "" ) {
                    setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                  . "Function: configureMgts, "
                                  . "Reason: MGTS sequence group(s) not defined");
                    return 0;
            }
   
            $logger->debug(__PACKAGE__ . ".$sub_name \$testcfg->{MGTS_SEQGRPS}[$mgts_index] = ". Dumper( $testcfg->{MGTS_SEQGRPS}[$mgts_index] ) );

            my @pairs;
            my @tmpary = @{$testcfg->{MGTS_SEQGRPS}[$mgts_index]};
            while(@tmpary) {
                push @pairs, [ splice(@tmpary,0,2) ];
            }

            my $iterator            = 1;    # iterator to use in next foreach loop
            my $last_mgts_flavor    = "";   # string for comparing flavor on multiple nodes
            my @db_list;

            foreach( @pairs ) {

                $node = @{$_}[0];
                $sequence_group = @{$_}[1];
                
                if ($sequence_group =~ /\.sequenceGroup$/ ) {
                    $sequence_group =~ s/\.sequenceGroup//g ;
                }

                $logger->debug(__PACKAGE__ . ".$sub_name Iterating foreach \(seqgrp\) loop ($iterator) with Node: $node, SeqGrp: $sequence_group");

                # Get user for sequence group copying from path and then copy...
                #
                unless( $mgts_seq_grp_account = getUserFromMgtsPath( $testcfg->{MGTS_SEQGRP_PATH} ) ) {

                    setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                    . "Function: con(igureMgts, "
                                    . "Reason: Cannot get user account from MGTS assignment path");
                    return 0;
                }

                unless( $mgts_object->uploadFromRepository(-account         => "$mgts_seq_grp_account",
                                                            -path           => "$testcfg->{MGTS_SEQGRP_PATH}",
                                                            -file_to_copy   => "${sequence_group}.sequenceGroup",
                                                          ) ) {
                    setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                  . "Function: configureMgts, "
                                  . "Reason: Failed to copy MGTS sequence group file \(${sequence_group}.sequenceGroup\)");
                    return 0;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name uploaded SeqGrp: $sequence_group from repository");

                # We need to gather the MGTS PASM Databse names from the tar
                # output of the uploadFromRepository function
                # '$mgts_object->{OUTPUT}' for use with the modifyUkPasmDb
                # function
                my @seq_tar_results = split /\n/, $mgts_object->{OUTPUT};
                my @tmp_db_list = grep(/\.pdb/,@seq_tar_results);
                push @db_list, @tmp_db_list;  
                
                $network_map_option{ "-node${node_count}"   }   = $node;
                $network_map_option{ "-seqgrp${node_count}" }   = $sequence_group;
                
                $logger->debug(__PACKAGE__ . ".$sub_name \%network_map_option: " . Dumper( %network_map_option ) );

                # Get MGTS protocol string using getSeqFlavor() on the MGTS object and the sequence group names from
                # $testcfg->{MGTS_SEQGRPS}[$mgts_index]. We need to check they are present and all the same.
                #
                unless( $mgts_protocol  = $mgts_object->getSeqFlavor(-seqgrp         => "$sequence_group",
                                                                     -seqgrp_path    => "$testcfg->{MGTS_SEQGRP_PATH}",
                                                                       ) ) {
                    setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                    . "Function: configureMgts, "
                                    . "Reason: Failed to identify protocol from MGTS Sequence Group $sequence_group");
                    return 0;
            
                }

                if ( $mgts_protocol =~ /none/ ) {

                    $logger->error(__PACKAGE__ . ".$sub_name Found \'none\' in protocol string (Flavor) in $sequence_group");

                    setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                    . "Function: configureMgts, "
                                    . "Reason: Failed to get valid protocol string (Flavor) from $sequence_group");
                    return 0;
                }
                    
                $logger->debug(__PACKAGE__ . ".$sub_name Got protocol string (Flavor) $mgts_protocol from $sequence_group");

                if ( $last_mgts_flavor ne "" ) {
                    
                    # We need to ensure all flavors on all sequence groups are the same
                    #
                    unless ( $last_mgts_flavor eq $mgts_protocol ) {
                    
                        $logger->error(__PACKAGE__ . ".$sub_name Mis-matched flavor $mgts_protocol found in $sequence_group. Last match was $last_mgts_flavor");

                        setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                        . "Function: configureMgts, "
                                        . "Reason: Mis-matched flavor $mgts_protocol found in $sequence_group. Last match was $last_mgts_flavor");
                        return 0;
                    }
                        
                }                     
                $last_mgts_flavor = $mgts_protocol;

                $node_count++;
                $iterator++;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name Left foreach \(seqgrp\) loop with \$mgts_protocol $mgts_protocol.");

            # Modify Network map to use newly copied MGTS sequence group(s)
            # Args passed in inside the hash populated in the last step
            #
            unless( $mgts_object->modifyNetworkMap(-network => $mgts_object->{NETMAP},
                                                    %network_map_option ) ) {
                setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                . "Function: configureMgts, "
                                . "Reason: Failed to modify Network Map $mgts_object->{NETMAP} to use defined sequence group");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name Modified Network Map $mgts_object->{NETMAP}");

            # Ensure the MGTS session for the object is using the correct protocol by re-starting the MGTS session
            # 
            unless( $mgts_object->startSession(-protocol    => $mgts_protocol,
                                                -display    => $mgts_object->{DISPLAY},
                                              ) ) {
                setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                . "Function: configureMgts, "
                                . "Reason: Failed to restart MGTS Session");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name Started MGTS session...");

            # NOTE: TMS Test Element database will need to have the GSX number added as:
            # {TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID}
            #
            unless (defined($artobj->{GSX}[0]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID} )) {
                setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                . "Function: configureMgts, "
                                . "Reason: Lab Identification number not found in TMS ALIAS data for GSX 1");
                return 0;    
            }
            
            my ($egress_gsx_lab_id, $egress_gsx_ip, $egress_gsx_name);
            
            #$logger->debug(__PACKAGE__ . ".$sub_name Length of \$artobj->{GSX} = $#{$artobj->{GSX}} and contents = " . Dumper(@{$artobj->{GSX}}));
            if ($#{$artobj->{GSX}} > 0 ) {
                unless (defined($artobj->{GSX}[1]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID} )) {
                    setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                    . "Function: configureMgts, "
                                    . "Reason: Lab Identification number not found in TMS ALIAS data for GSX 2");
                   return 0;
                } else {
                    $egress_gsx_lab_id = $artobj->{GSX}[1]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID};
                }
                $egress_gsx_ip     = $artobj->{GSX}[1]->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
                $egress_gsx_name   = $artobj->{GSX}[1]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};
            } else {
                $egress_gsx_lab_id = $artobj->{GSX}[0]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID};
                $egress_gsx_ip     = $artobj->{GSX}[0]->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP};
                $egress_gsx_name   = $artobj->{GSX}[0]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};
            }
            # Modify UK MGTS def.csh file that is used within some scripts used in Unica Asction states in some MGTS
            # test scripts

            # NOTE: The old mething of using MGTS GSX and PSX control test scripts is no longer supported. These
            # use the new mechanism of execTest and execPsxControl respectively.
            
            # NOTE 2: Removed the following for now:-pt2    => $artobj->{PSX}[1]->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP},
            unless( $mgts_object->modifyUkDefDotCsh(-gt1    => $artobj->{GSX}[0]->{TMS_ALIAS_DATA}->{MGMTNIF}->{1}->{IP},
                                                    -gn1    => $artobj->{GSX}[0]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME},
                                                    -pt1    => $artobj->{PSX}[0]->{TMS_ALIAS_DATA}->{NODE}->{1}->{IP},
                                                    -gt2    => $egress_gsx_ip,
                                                    -gn2    => $egress_gsx_name,
                                                   ) ) {
                setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                . "Function: configureMgts, "
                                . "Reason: Failed to modify UK def.csh file");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name Modified def.csh");

            # Modify UK PASM databases for testing

            
            unless (defined($testcfg->{EG_PROTOCOL})) {
                setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                . "Function: configureMgts, "
                                . "Reason: Egress Protocol not specified in Test Group Config file '$testcfg->{TEST_GRP}'");
                return 0;    
            }
          
            unless ($#db_list == -1) {
                my $db_list_string = join ",", @db_list; 
                unless( $mgts_object->modifyUkPasmDB( -ing_gsx    => $artobj->{GSX}[0]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID},
                                                      -eg_gsx     => $egress_gsx_lab_id,
                                                      -ing_ptcl   => "ANSI",
                                                      -eg_ptcl    => $testcfg->{EG_PROTOCOL},
                                                      -db_list    => "$db_list_string",
                                                     ) ) {
                    setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                    . "Function: configureMgts, "
                                    . "Reason: Failed to modify UK PASM DB files");
                    return 0;
                } 
                $logger->debug(__PACKAGE__ . ".$sub_name Modified PASM DB Files");
            } else {
                $logger->debug(__PACKAGE__ . ".$sub_name Bypassed the modification of MGTS PASM DB files as none were found");
            } 

            # Download MGTS assignment to MGTS
            # 
            unless( $mgts_object->downloadAssignment(-assignment    => $mgts_assignment) ) {

                setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                . "Function: configureMgts, "
                                . "Reason: Failed to download MGTS assignment $mgts_assignment");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name Downloaded Assignment $mgts_assignment");

            

            # Get downloaded nodes on the MGTS
            #

            unless( $mgts_object->getNodeList() ) {

                setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                . "Function: configureMgts, "
                                . "Reason: Failed to identify any nodes downloaded to MGTS");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name Got nodelist from MGTS");

            # Get the Sequence Group list and cleanup state machine for each node
            #
            
             $logger->debug(__PACKAGE__ . ".$sub_name ". Dumper ( $mgts_object->{NODELIST} ) );

            foreach $node ( @{ $mgts_object->{NODELIST} } ) {
                $logger->debug(__PACKAGE__ . ".$sub_name Iterating foreach (node) loop with $node");
                my $number_of_states;
                unless( $number_of_states = $mgts_object->getSeqList(-node => $node) ) {

                    setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                    . "Function: configureMgts, "
                                    . "Reason: Failed to get sequence group list for node $node");
                    return 0;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name $number_of_states state machines have been downloaded on node $node");

                # Get CLEANUP state
                #
                unless( $mgts_object->getCleanupState(-node => "$node") ) {

                    setSkipGrpData("Test Grp: $testcfg->{TEST_GRP}, "
                                    . "Function: configureMgts, "
                                    . "Reason: Failed to identify CLEANUP state machine for node $node");
                    return 0;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name Got CLEANUP state $mgts_object->{CLEANUP}->{${node}}->{MACHINE} from Node $node");

            } # End foreach (node)

        } # End if ($mgts_object blank) else...      

        # Increment $mgtsindex for the next MGTS object in the array
        #
        $mgts_index++

    } # End foreach (MGTS object)

    $logger->debug(__PACKAGE__ . ".$sub_name <--- Leaving function");
    return 1;
}

############################################

=head1 B<assignRequiredMgts()>

  Given an array of arrays of requested mgts, one per 'instance' - assign the allocated mgts obj in such that each row 
  or the request array is satisfied (see design below for further detail)

=over 6

=item ARGUMENTS:

 $test_cfg->{REQ_MGTS} array of arrays stating what mgts *can* be used to execute the tests, array index at top level corresponds to the 
 -mgts<index-1> argument to execTest(). Each sub array is a list of possible ATS aliases for MGTS that can be used for this half of the call.

 (i.e.   [ [ "mgtsA", "mgtsC", "mgtsE" ] 
        [ "mgtsB", "mgtsD", "mgtsF" ]
        [ "mgtsA", "mgtsB"          ] ]

 Would be used for a 3 party setup where the -mgts1 execTest arg can be any of A,C,E, -mgts2 can be any of B,D,F, and -mgts3 any of A,B.

=item GLOBAL VARIABLES USED:

 $artobj->{MGTS} array of pre-createt SonusQA::MGTS objects (i.e. [ objA, objB, objC ]
 $artcfg->{MGTS_ALLOC} array of ATS alias for above objects (i.e. [ "mgtsA", "mgtsB", "mgtsC" ] )
 Note 1-1 mapping of above arrays by index.

=item Transient global (initialized and used by this function, of no consequence outside it)

 $testcfg->{MGTS_ALLOC_USAGE_MASK} - Mask against MGTS/MGTS_ALLOC arrays above showing which entries have been used (initialized by this subroutine)

=item PACKAGE:

 SonusQA::GSX::ART

=item EXTERNAL FUNCTIONS USED:

 SonusQA::ART::setSkipGrpData()

=item OUTPUT:

 $testcfg->{USED_MGTS_OBJ} an array of mgts objects selected from $artobj->{MGTS} where the n=array_index+1 corresponds to the -mgts<n> 
 of execTest() and the contraints imposed by REQ_MGTS are satisfied.

=item RETURNS:

 1 - Success
 0 - Failed to allocate

=item EXAMPLE:

 assignRequiredMgts(@{$test_cfg->{REQ_MGTS}})

=item Procedure (recursive)

 C<   if input array empty (length of input array = -1)
       if (length of REQ_MGTS = length of USED_MGTS_OBJ)
           We are done - return success and unravel the recursion 
       else
           We were invoked with an empty array - shouldn't happen - set skipGroupData and return failure
       endif
   endif
   if (length of input array = length of REQ_MGTS)
       First time thru - initialize the USED_MASK array to all 'FREE' (1) (1-1 mapping with MGTS_ALLOC, each entry is either 'USED'(0) or 'FREE'(1))
       Initialize USED_MGTS_OBJ to empty array
   endif

   select 1st row from input array
   if row empty - assume any mgts and use the conents of MGTS_ALLOC in place of row.
   foreach row_element in row
       foreach index 0 to length of MGTS_ALLOC
           if row_element == MGTS_ALLOC[index] AND USED_MASK[index] == 'FREE'
               We found a match for the -mgts<index+1> requirement
               Set USED_MASK[index] = 'USED'
               Push the corresponding object from $artobj->{MGTS}[index] onto the USED_MGTS_OBJ array
               if length of input array == 0 (0 in perl means 1 element)
                   We're done - this was the last criteria to satisfy - return success and unwind the recursion
               else 
                   More to do - invoke self with an array slice of input array from 1 .. length of input array (i.e. remove the 1st sub-array.)
                   if result == success
                       We're done - return success and unwind recursion.
                   else
                       Pop the object from USED_MGTS_OBJ since it was a bad choice
                       Reset the USED_MASK[index] to 'FREE' - and carry on thru the loops
                   endif
               endif
           endif
       endfor
   endfor
   So we got here - we've got to the end of input array without finding a match 
   if this is the top-level call - then setSkipGrpData.
   return failure 
 >

=back

=cut

sub assignRequiredMgts {
    my $sub_name = "assignRequiredMgts()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Invoked");

    # @_ *is* our input array and will be used in place of this except in the center of the loops
    my @input_array = @_;
    my $length_of_input_array = $#input_array;

    if ($length_of_input_array == -1) {
            $logger->error(__PACKAGE__ . ".$sub_name Invoked with an empty array - returning 0 (failure)");
            setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: assignRequiredMgts, Reason: Unable to assign MGTS from allocation (invoked with empty array)");
            return 0;
    } elsif ($length_of_input_array == $#{$testcfg->{REQ_MGTS}}) {
        $logger->debug(__PACKAGE__ . ".$sub_name Top level call, initializing MGTS_ALLOC_USAGE_MASK, USED_MGTS_OBJ");
        $testcfg->{MGTS_ALLOC_USAGE_MASK} = [];
        foreach (@{$artcfg->{MGTS_ALLOC}}) {
            push @{$testcfg->{MGTS_ALLOC_USAGE_MASK}},1;
        }
        $testcfg->{USED_MGTS_OBJ} = ();
    }
    if($#{$_[0]} == -1) {
        $logger->info(__PACKAGE__ . ".$sub_name Empty row in REQ_MGTS, assuming any and using MGTS_ALLOC");
        @{$_[0]}=@{$artcfg->{MGTS_ALLOC}};
    }
    foreach (@{$_[0]}) {
        $logger->debug(__PACKAGE__ . ".$sub_name LOOP1: Iterator " . Dumper $_ );
        foreach $idx (0 .. $#{$artcfg->{MGTS_ALLOC}}) {
            $logger->debug(__PACKAGE__ . ".$sub_name LOOP2: Idx $idx" );
            if ((m/^$artcfg->{MGTS_ALLOC}[$idx]/) && ($testcfg->{MGTS_ALLOC_USAGE_MASK}[$idx])) {
                $logger->debug(__PACKAGE__ . ".$sub_name Found match for $_ at index $idx");
                $testcfg->{MGTS_ALLOC_USAGE_MASK}[$idx] = 0;
                $logger->debug(__PACKAGE__ . ".$sub_name MASK". Dumper \@{$testcfg->{MGTS_ALLOC_USAGE_MASK}});
                push @{$testcfg->{USED_MGTS_OBJ}}, $artobj->{MGTS}[$idx];
                if($length_of_input_array == 0) {
                    $logger->info(__PACKAGE__ . ".$sub_name Found final match - returning 1(success)");
                    return 1;
                } else {
                    my $saved = shift @input_array;
                    if( assignRequiredMgts(@input_array) ) {
                        $logger->info(__PACKAGE__ . ".$sub_name Child call returned success - returning 1(success)");
                        return 1;
                    } else {
                        $logger->info(__PACKAGE__ . ".$sub_name Child call returned failure - popping object,resetting mask and continuing");
                        pop @{$testcfg->{USED_MGTS_OBJ}};
                        unshift @input_array,$saved;
                        $testcfg->{MGTS_ALLOC_USAGE_MASK}[$idx] = 1;
                    }
                }
            }
        }
    }
    if($length_of_input_array == $#{$testcfg->{REQ_MGTS}}) {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: assignRequiredMgts, Reason: Unable to assign MGTS from allocation (all combinations tried)");
    } else {
        $logger->info(__PACKAGE__ . ".$sub_name I'm sorry Dave, I'm afraid I can't do that (This is an expected failure causing recursion to unroll) - returning failure(0)");
    }
    return 0;

}
            
            
=head1 B<checkMgtsSeqgrps()>

 This function checks the specified MGTS node names and sequence group files to ensure there is one foreach required MGTS. 
 $testcfg->{MGTS_SEQGRPS} is an array of arrays where there is an array of "MGTS_NODE:MGTS_SEQUENCE GROUP" strings for each required MGTS. 
 Each unique MGTS Node on an MGTS has an unique sequence group defined. Typically there is one MGTS node and sequence group per required MGTS. 
 Functionality allows more complex MGTS Network Maps to be used which can have multiple nodes.
 The function also checks the path to the MGTS sequence groups to ensure it is defined and exists.
 Called from the setupTestGrpConfig() function.

=over 6

=item ARGUMENTS:

 None

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $testcfg->{MGTS_SEQGRP_PATH}
 $testcfg->{MGTS_SEQGRPS}
 $mgts_repos{PATH}

=item EXTERNAL FUNCTIONS USED:

 SonusQA::ART::setSkipGrpData()

=item OUTPUT:

 1 - if all MGTS configuration successful
 0 - otherwise (with $testcfg->{SKIP_GROUP} being set)

=item EXAMPLE: 

 unless ( defined($testcfg->{SKIP_GROUP}) && $testcfg->{SKIP_GROUP} == 1) {
    # No need to execute if skip_group flag set
    checkMgtsSeqgrps();
 } 

=back

=cut

sub checkMgtsSeqgrps {
    my $sub_name = "checkMgtsSeqgrps()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");

    $logger->debug(__PACKAGE__ . ".$sub_name Invoked");

    # Step 1.
    unless(defined($testcfg->{MGTS_SEQGRP_PATH}) && $testcfg->{MGTS_SEQGRP_PATH} !~ /^\s*$/) {
        unless (defined($mgts_repos{PATH}) && $mgts_repos{PATH} !~ /^\s*$/) {
            $logger->error(__PACKAGE__ . ".$sub_name MGTS_SEQGRP_PATH not set - and no default in regional config file");
            setSkipGrpData( "Test Group: $testcfg->{TEST_GRP}, Function: checkMgtsSeqgrps, Reason: Unable to find regional default value for MGTS sequence Group path"); 
            $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
            return 0;
        } else {
            $logger->info(__PACKAGE__ . ".$sub_name MGTS_SEQGRP_PATH not set - defaulting from regional config file to '$mgts_repos{PATH}'");
            $testcfg->{MGTS_SEQGRP_PATH} = $mgts_repos{PATH};
        }
    }

    # Check path exists on remote MGTS server. (Design Step 2.)
    if ( my $exit_code = $testcfg->{USED_MGTS_OBJ}[0]->cmd( -cmd => "\[ -d $testcfg->{MGTS_SEQGRP_PATH} \] && echo okiedokie", -timeout => 5 ) ) {
        $logger->error(__PACKAGE__ . ".$sub_name Failed to check MGTS_SEQGRP_PATH existence - Command failure; return code was: $exit_code\n");
        setSkipGrpData( "Test Group: $testcfg->{TEST_GRP}, Function: checkMgtsSeqgrps, Reason: Unable to determine existence of MGTS sequence Group path - Command failure"); 
        $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $testcfg->{USED_MGTS_OBJ}[0]->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $testcfg->{USED_MGTS_OBJ}[0]->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $testcfg->{USED_MGTS_OBJ}[0]->{sessionLog2}");
        return 0;
    }

    unless ($testcfg->{USED_MGTS_OBJ}[0]->{OUTPUT} =~ "okiedokie") {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: checkMgtsSeqgrps, Reason: MGTS sequence path does not exist on MGTS shelf");  
        $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
        return 0;
    }

    # Step 3.
    unless (defined $testcfg->{MGTS_SEQGRPS}) {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: checkMgtsSeqgrps, Reason: MGTS sequence group not defined");
        $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
        return 0;
    }

    # Step 4.
    if($#{$testcfg->{MGTS_SEQGRPS}} > $#{$testcfg->{REQ_MGTS}}) {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: checkMgtsSeqgrps, Reason: More sequence groups defined than the number of MGTS required");
        $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
        return 0;
    }

    # Step 5.
    $testcfg->{MGTS_PROTOCOL} = ();

    # Step 6.
    foreach $seqgrp_index (0 .. ($#{$testcfg->{REQ_MGTS}}-1) ) {
        $logger->debug(__PACKAGE__ . ".$sub_name LOOP1: Iterator $seqgrp_index");
        # i.
        if($testcfg->{MGTS_SEQGRPS}[$seqgrp_index] eq "") {
            setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: checkMgtsSeqgrps, Reason: MGTS sequence group not defined");  
            $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
            return 0;
        }

        # HEF - addition to design by malc - Take the crazy datastructure (See $testcfg->{MGTS_SEQGRPS} in design doc.) and make it sane(r)
        my @pairs;
        my @tmpary = @{$testcfg->{MGTS_SEQGRPS}[$seqgrp_index]};
        while(@tmpary) {
              push @pairs, [ splice(@tmpary,0,2) ];
        }

        # ii.
        foreach (@pairs) {
            $logger->debug(__PACKAGE__ . ".$sub_name LOOP2: Iterator [ @{$_}[0], @{$_}[1]");
            # a.
            if (@{$_}[0] eq "" ) { # NODE
                setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: checkMgtsSeqgrps, Reason: MGTS node name not defined in \$testcfg->{MGTS_SEQGRPS} array position $seqgrp_index");  
                $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
                return 0;
            }
            # b.
            if (@{$_}[1] eq "" ) { # Sequence Group
                setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: checkMgtsSeqgrps, Reason: MGTS sequence group name not defined in \$testcfg->{MGTS_SEQGRPS} array position $seqgrp_index");  
                $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
                return 0;
            }
            # c.
            unless (@{$_}[1] =~ /.sequenceGroup/) {
                @{$_}[1] .= ".sequenceGroup";
            }
            # d.
            # -s size greater than zero, -r readable.
            if ( my $exit_code = $testcfg->{USED_MGTS_OBJ}[0]->cmd( -cmd => "\[ -s $testcfg->{MGTS_SEQGRP_PATH}/@{$_}[1] \] && \[ -r $testcfg->{MGTS_SEQGRP_PATH}/@{$_}[1] \] && echo okiedokie", -timeout => 5 ) ) {
                $logger->error(__PACKAGE__ . ".$sub_name Failed to check sequence group readability/size - Command failure; return code was: $exit_code\n");
                setSkipGrpData( "Test Group: $testcfg->{TEST_GRP}, Function: checkMgtsSeqgrps, Reason: MGTS sequence group file '@{$_}[1]' readbility/size check failed - Command failure"); 
	        $logger->debug(__PACKAGE__ . ".$sub_name: errmsg: " . $testcfg->{USED_MGTS_OBJ}[0]->errmsg);
	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Dump Log is : $testcfg->{USED_MGTS_OBJ}[0]->{sessionLog1}");
	        $logger->debug(__PACKAGE__ . ".$sub_name: Session Input Log is: $testcfg->{USED_MGTS_OBJ}[0]->{sessionLog2}");
                $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
                return 0;
            }

            unless ($testcfg->{USED_MGTS_OBJ}[0]->{OUTPUT} =~ "okiedokie") {
                setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: checkMgtsSeqgrps, Reason: MGTS sequence group file '@{$_}[1]' does not exist/is not readable/has zero size");  
                $logger->debug(__PACKAGE__ . ".$sub_name returning 0");
                return 0;
            }
        }

        # HEF - addition to design - reconstruct original datastructure with any modifications made in above loop
        foreach (@pairs) {
            push  @tmpary, @{$_};
        }
        @{$testcfg->{MGTS_SEQGRPS}[$seqgrp_index]} = @tmpary;

    }
    $logger->debug(__PACKAGE__ . ".$sub_name returning 1");
    return 1;

}

=head1 B<createObjectsFromAliases()>

  This function takes a list (array) of TMS aliases and an object type name and attempts to create the ATS objects from the resolved 
 alias properties. It returns an array of ATS object references if successful.  Otherwise it prints the appropriate errors and exits the tool.

=over 6

=item ARGUMENTS:

 -alias_ary - array of ATS TMS aliases
 -obj_type  - Type of object (GSX, PSX, EMSCLI, MGTS, GBL)
 -psx_array - array of PSX TMS aliases which is only passed in if object type is "EMSCLI"

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 SonusQA::ATSHELPER::newFromAlias()

=item OUTPUT:

 $ats_obj_ary - array of ATS objects ONLY if creation of all objects are successful.
 exit - exit otherwise

=item EXAMPLE:

 $artobj->{PSX} =  createObjectsFromAliases(-alias_ary => $artcfg->{PSX_ALLOC}),-obj_type => "PSX");

=back

=cut

sub createObjectsFromAliases {

    my (%args) = @_;
    my $sub_name = "createObjectsFromAliases()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my $ats_obj_ref;

    $logger->debug(__PACKAGE__ . ".$sub_name Entering $sub_name");
    # Check if alias_ary is defined
    unless (defined($args{-alias_ary}) && ($args{-alias_ary} !~ m/^\s*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name alias_ary undefined or is blank ");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        exit;
    }

    # Check if obj_type is defined
    unless ( defined($args{-obj_type}) && ($args{-obj_type} !~ m/^\s*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name obj_type undefined or is blank");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        exit;
    }

    my @ats_obj_ary;

    for (my $gsx_index=0; $gsx_index<= $#{$args{-alias_ary}}; $gsx_index++) {

        $logger->debug(__PACKAGE__ . ".$sub_name Creating objects for $args{-alias_ary}[$gsx_index] of object type $args{-obj_type}");

        # Check $tms_ats_alias exists using newFromAlias function
        switch ($args{-obj_type})
        {
            case /GSX|PSX|MGTS|GBL/
            {
                # Create ATS object
                $ats_obj_ref = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $args{-alias_ary}[$gsx_index],
                                                                -obj_type => $args{-obj_type});
            }

            case /EMSCLI/
            {
                # Check if psx_array has been specified
                unless (defined($args{-psx_array}) && ($args{-psx_array} !~ m/^\s*$/)) {
                    $logger->error(__PACKAGE__ . ".$sub_name psx_array undefined or is blank");
                    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                    exit;
                }

                $ats_obj_ref = SonusQA::ATSHELPER::newFromAlias(-tms_alias => $args{-alias_ary}[$gsx_index],
                                                                -obj_type => $args{-obj_type},
                                                                -target_instance => $args{-psx_array}[$gsx_index]);
            }
            else {
                $logger->error(__PACKAGE__ . ".$sub_name Invalid object type $args{-obj_type} specified");
                $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                exit;
            }
        } # End switch

        # Check if $ats_obj_ref defined
        unless (defined($ats_obj_ref)) {
            $logger->error(__PACKAGE__ . ".$sub_name ATS object couldn't be created for alias");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            exit;
        }

        push @ats_obj_ary,$ats_obj_ref;

    } # End for

    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
    return \@ats_obj_ary;

} # End sub createObjectsFromAliases

=head1 B<copyImagesToGsx()>

  This function copies GSX images from a specified source directory ($src_img_dir) to the GSX NFS directory ($nfs_dir). 
  The source directory is specified by the first argument to the function and the images stored within this directory can either 
 be in ClearCase format or in the Sonus Release Engineering format.
 The GSX NFS directory is specified as the second argument.
 A third argument indicates the type of GSX i.e. GSX9000 or GSX4000. This is used to prevent the unnecessary copying of unused image binary and TCL files.

=over 6

=item Clearcase format:

      $src_img_dir/
              *[05].bin

              CLI/
                  GSX4000/screens_gsx4000.sda (if applicable)
                  GSX9000/screens_gsx9000.sda (if applicable)
                        SCREENS/showscreens.sda (if applicable)
                        CMDS/commands.def (if applicable)
                  SCRIPTS/*.tcl

=item Release Eng format:

      $src_img_dir/
            MNS10/mns10.bin
                  *.tcl
                  *.sda
                  commands.def (if available)
            MNS20/mns20.bin
            PNS10/pns10.bin
            PNS30/pns30.bin
            PNS40/pns40.bin
            CNS10/cns10.bin
            CNS20/cns20.bin
            CNS25/cns25.bin
            CNS30/cns30.bin
            CNS60/cns60.bin
            CNS70/cns70.bin
            CNS80/cns80.bin
            GNS15/gns15.bin
            SPS70/sps70.bin

=item ARGUMENTS:

 1st arg - Source image directory ($src_img_dir)
 2nd arg - Destination GSX NFS images directory ($dest_img_dir)
 3rd arg - GSX Type ($gsx_type)

=item PACKAGE:

 SonusQA::GSX::GSXHELPER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item ASSUMPTIONS

 NFS is mounted on ATS server

=item OUTPUT:

 1 - images Gcopied successfully
 0 - otherwise

=item EXAMPLE:

 unless (SonusQA::GSX::GSXHELPER::copyImagesToGsx($src_img_dir_path,$dest_img_dir_path,$gsx_type)) {
     print error to ATS logger stating that images did not copy successfully.
     return 0;
 }

=back

=cut

sub copyImagesToGsx {

    my $src_img_dir = shift;
    my $dest_img_dir = shift;
    my $gsx_type = shift;

    my $sub_name = "copyImagesToGsx()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name Entering $sub_name");

    # Check if $src_img_dir is defined and not blank
    unless (defined($src_img_dir) && ($src_img_dir !~ m/^\s*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name src_img_dir undefined or is blank ");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name Source Image Directory is $src_img_dir");
    }

    # Check if $dest_img_dir is defined and not blank
    unless (defined($dest_img_dir) && ($dest_img_dir !~ m/^\s*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name dest_img_dir undefined or is blank ");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name Destination Image Directory is $dest_img_dir");
    }

    # Check if $gsx_type is defined and not blank
    unless (defined($gsx_type) && ($gsx_type !~ m/^\s*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name gsx_type undefined or is blank ");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub_name GSX Type is '$gsx_type'");
    }

    # Check if $src_img_dir exists
    unless (-d $src_img_dir) {
        $logger->error(__PACKAGE__ . ".$sub_name Source image directory '$src_img_dir' does not exist");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    # Check if $dest_img_dir exists
    unless (-d $dest_img_dir) {
        $logger->error(__PACKAGE__ . ".$sub_name Destination image directory '$dest_img_dir' does not exist");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    # Check format of $src_img_dir
    my $format1 = $src_img_dir . "/" . "CLI/SCRIPTS";
    my $format2 = $src_img_dir . "/" . "MNS10";

    unless ((-d $format1) || (-d $format2)) {
        $logger->error(__PACKAGE__ . ".$sub_name Source directory format cannot be deduced");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    # Check if format is clearcase format and copy files accordingly
    if (-d $format1) {
        if ($gsx_type =~ /GSX4000/) {
            $logger->debug(__PACKAGE__ . ".$sub_name Copying $src_img_dir/gns15.bin to the $dest_img_dir/images directory");
            if (system("cp -rf $src_img_dir/gns15.bin $dest_img_dir/images/")) {
                $logger->error(__PACKAGE__ . ".$sub_name Unable to copy $src_img_dir/gns15.bin to $dest_img_dir/images directory");
                $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/gns15.bin to the $dest_img_dir/images directory");
                           
            if (-e "$src_img_dir/CLI/GSX4000/screens_gsx4000.sda") {
                if (system("cp -rf $src_img_dir/CLI/GSX4000/screens_gsx4000.sda $dest_img_dir/cli/sys/")) {
                    $logger->error(__PACKAGE__ . ".$sub_name Unable to copy $src_img_dirCLI/GSX4000/screens_gsx4000.sda to $dest_img_dir/cli/sys directory");
                    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                    return 0;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/CLI/GSX4000/screens_gsx4000.sda to the $dest_img_dir/cli/sys directory");
            }
            else {
                $logger->error(__PACKAGE__ . ".$sub_name $src_img_dir/CLI/GSX4000/screens_gsx4000.sda File not found");
                $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                return 0;
            }
        }
        elsif ($gsx_type =~ /GSX9000/) {
            $logger->debug(__PACKAGE__ . ".$sub_name Copying $src_img_dir/[cmps][np]s*[0-9].bin to the $dest_img_dir/images directory");
            if (system("cp -rf $src_img_dir/[cmps][np]s*[0-9].bin $dest_img_dir/images/")) {
                $logger->error(__PACKAGE__ . ".$sub_name Unable to copy $src_img_dir/[cmps][np]s*[0-9].bin to $dest_img_dir/images directoory");
                $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/[cmps][np]s*[0-9].bin to the $dest_img_dir/images directory");

            if (-d "$src_img_dir/CLI/SCREENS") {
                # We are using the old showscreens format and commands.def is used
                if (-e "$src_img_dir/CLI/SCREENS/showscreens.sda") {
                    if (system("cp -rf $src_img_dir/CLI/SCREENS/showscreens.sda $dest_img_dir/cli/sys")) {
                        $logger->error(__PACKAGE__ . ".$sub_name Unable to copy $src_img_dir/CLI/SCREENS/showscreens.sda to $dest_img_dir/cli/sys directory");
                        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                        return 0;
                    }
                    $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/CLI/SCREENS/showscreens.sda to the $dest_img_dir/cli/sys directory");
                } else {
                    $logger->error(__PACKAGE__ . ".$sub_name $src_img_dir/CLI/SCREENS/showscreens.sda File not found");
                    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                    return 0;
                }    
                
                if (-e "$src_img_dir/CLI/CMDS/commands.def") {
                    if (system("cp -rf $src_img_dir/CLI/CMDS/commands.def $dest_img_dir/cli/sys/")) {
                        $logger->error(__PACKAGE__ . ".$sub_name Unable to copy $src_img_dir/CLI/CMDS/commands.def to $dest_img_dir/cli/sys directory");
                        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                        return 0;
                    }
                    $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/CLI/CMDS/commands.def to the $dest_img_dir/cli/sys directory");
                } else {
                    $logger->error(__PACKAGE__ . ".$sub_name $src_img_dir/CLI/CMDS/commands.def File not found");
                    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                    return 0;
                }
            } else {
                # We are using the new showscreens format and commands.def is no longer used
                if (-e "$src_img_dir/CLI/GSX9000/screens_gsx9000.sda") {
                    if (system("cp -rf $src_img_dir/CLI/GSX9000/screens_gsx9000.sda $dest_img_dir/cli/sys/")) {
                        $logger->error(__PACKAGE__ . ".$sub_name Unable to copy $src_img_dirCLI/GSX9000/screens_gsx9000.sda to $dest_img_dir/cli/sys directory");
                        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                        return 0;
                    }
                    $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/CLI/GSX9000/screens_gsx9000.sda to the $dest_img_dir/cli/sys directory");
                }
                else {
                    $logger->error(__PACKAGE__ . ".$sub_name $src_img_dir/CLI/GSX9000/screens_gsx9000.sda File not found");
                    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                    return 0;
                }
            }
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name Could not recognise GSX type");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
  
        if (system("cp -rf $src_img_dir/CLI/SCRIPTS/*.tcl $dest_img_dir/cli/scripts/")) {
            $logger->error(__PACKAGE__ . ".$sub_name Unable to copy tcl files from $src_img_dir/CLI/SCRIPTS to $dest_img_dir/cli/scripts directory");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/CLI/SCRIPTS/*.tcl to the $dest_img_dir/cli/scripts directory");
    }

    if (-d $format2) {
        if ($gsx_type =~ /GSX4000/) {
            $logger->debug(__PACKAGE__ . ".$sub_name Copying $src_img_dir/GNS15/gns15.bin to the $dest_img_dir/images directory");
            if (system("cp -rf $src_img_dir/GNS15/gns15.bin $dest_img_dir/images/")) {
                $logger->error(__PACKAGE__ . ".$sub_name Unable to copy $src_img_dir/GNS15/gns15.bin to $dest_img_dir/images directory");
                $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/GNS15/gns15.bin to the $dest_img_dir/images directory");
            
            if (-e "$src_img_dir/MNS10/screens_gsx4000.sda") {
                if (system("cp -rf $src_img_dir/MNS10/screens_gsx4000.sda $dest_img_dir/cli/sys/")) {
                    $logger->error(__PACKAGE__ . ".$sub_name Unable to copy $src_img_dir/MNS10/screens_gsx4000.sda to $dest_img_dir/cli/sys directory");
                    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                    return 0;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/MNS10/screens_gsx4000.sda to the $dest_img_dir/cli/sys directory");
            }
            else {
                $logger->error(__PACKAGE__ . ".$sub_name $src_img_dir/MNS10/screens_gsx4000.sda File not found");
                $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                return 0;
            }
        }
        elsif ($gsx_type =~ /GSX9000/) {
            $logger->debug(__PACKAGE__ . ".$sub_name Copying $src_img_dir/[CMPS][NP]S*[0-9]/[cmps][np]s*[0-9].bin to the $dest_img_dir/images directory");
            if (system("cp -rf $src_img_dir/[CMPS][NP]S*[0-9]/[cmps][np]s*[0-9].bin $dest_img_dir/images/")) {
                $logger->error(__PACKAGE__ . ".$sub_name Unable to copy $src_img_dir/[CMPS][NP]S*[0-9]/[cmps][np]s*[0-9].bin to $dest_img_dir/images directory");
                $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                return 0;
            }
            $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/[CMPS][NP]S*[0-9]/[cmps][np]s*[0-9].bin to the $dest_img_dir/images directory");

            if (-e "$src_img_dir/MNS10/screens_gsx9000.sda") {
                if (system("cp -rf $src_img_dir/MNS10/screens_gsx9000.sda $dest_img_dir/cli/sys/")) {
                    $logger->error(__PACKAGE__ . ".$sub_name Unable to copy $src_img_dir/MNS10/screens_gsx9000.sda to $dest_img_dir/cli/sys directory");
                    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                    return 0;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/MNS10/screens_gsx9000.sda to the $dest_img_dir/cli/sys directory");
            }
            elsif (-e "$src_img_dir/MNS10/showscreens.sda") {
                if (system("cp -rf $src_img_dir/MNS10/showscreens.sda $dest_img_dir/cli/sys")) {
                    $logger->error(__PACKAGE__ . ".$sub_name Unable to copy $src_img_dir/MNS10/showscreens.sda to $dest_img_dir/cli/sys");
                    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                    return 0;
                }
                $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/MNS10/showscreens.sda to the $dest_img_dir/cli/sys directory");
                
                if (-e "$src_img_dir/MNS10/commands.def") {
                    if (system("cp -rf $src_img_dir/MNS10/commands.def $dest_img_dir/cli/sys/")) {
                        $logger->error(__PACKAGE__ . ".$sub_name Unable to copy $src_img_dir/MNS10/commands.def to $dest_img_dir/cli/sys directory");
                        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                        return 0;
                    }
                    $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/MNS10/commands.def to the $dest_img_dir/cli/sys directory");
                }
                else {
                    $logger->error(__PACKAGE__ . ".$sub_name $src_img_dir/MNS10/commands.def File not found");
                    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                    return 0;
                }
            }
            else {
                $logger->error(__PACKAGE__ . ".$sub_name Unable to idenify any showscreen files in the $src_img_dir/MNS10 directory");
                $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                return 0;
            }
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name Could not recognise GSX type");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }

        if (system("cp -rf $src_img_dir/MNS10/*.tcl $dest_img_dir/cli/scripts/")) {
            $logger->error(__PACKAGE__ . ".$sub_name Unable to copy tcl files from $src_img_dir/MNS10/ to $dest_img_dir/cli/scripts directory");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub_name Copied $src_img_dir/MNS10/*.tcl to the $dest_img_dir/cli/scripts directory");
    }

    $logger->info(__PACKAGE__ . ".$sub_name GSX Images were copied to $dest_img_dir/images");
    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");

    return 1;
        
} # End sub copyImagesToGsx

=head1 B<copyGsxImagesAlloc()>

  This function loops through all the source image directories $artcfg->{SRC_GSX_IMG_DIR} and copies the images to the NFS images 
  directory of the corresponding GSX object $artobj->{GSX} array.Assumes GSX objects are all created.

=over 6

=item ARGUMENTS:

 None

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $artcfg->{SRC_GSX_IMG_DIR}
 $artobj->{GSX}

=item EXTERNAL FUNCTIONS USED:

 SonusQA::GSX::GSXHELPER::copyImagesToGsx()

=item OUTPUT:

 1 - if validation of all variables and GSX images copied successfully or are assumed to be preloaded.
 0 - otherwise

=item EXAMPLE:

 unless (copyGsxImagesAlloc() {
     $logger->debug(__PACKAGE__ . ".$sub_name Exiting function);
     exit 0;
 }

=back

=cut

sub copyGsxImagesAlloc {

    my $sub_name = "copyGsxImagesAlloc()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");   
    my ($dest_img_dir_path,$gsx_type);

    $logger->debug(__PACKAGE__ . ".$sub_name Entering $sub_name");
    my $array_index = 0;

    foreach my $gsxobj (@{$artobj->{GSX}}) {
       
        # If $artcfg->{SRC_GSX_IMG_DIR} array only has one element then use
        # this element for all GSXs
        if ( $#{$artcfg->{SRC_GSX_IMG_DIR}} == 0 ) {
            $array_index = 0;
        }
      
        my $src_img_dir_path = $artcfg->{SRC_GSX_IMG_DIR}->[$array_index];

        if ($src_img_dir_path =~ /PRELOADED/) {
            next;
        }
 
        unless (defined($gsxobj)) {
            $logger->error(__PACKAGE__ . ".$sub_name No GSX object in \$artobj->\{GSX\} for index $array_index");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }

        unless (defined($gsxobj->{TMS_ALIAS_DATA}->{NFS}->{1}->{BASEPATH}) && $gsxobj->{TMS_ALIAS_DATA}->{NFS}->{1}->{BASEPATH} !~ /^\s*$/) {
            $logger->error(__PACKAGE__ . ".$sub_name GSX NFS BASEPATH could not be found or is blank");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
        else {
            $dest_img_dir_path = $gsxobj->{TMS_ALIAS_DATA}->{NFS}->{1}->{BASEPATH};
        }

        unless (defined($gsxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{HW_PLATFORM}) && $gsxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{HW_PLATFORM} !~ /^\s*$/) {
            $logger->error(__PACKAGE__ . ".$sub_name GSX NODE Hardware Type could not be found or is blank.");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
        else {
            $gsx_type = $gsxobj->{TMS_ALIAS_DATA}->{NODE}->{1}->{HW_PLATFORM};
        }

        unless (SonusQA::GSX::ART::copyImagesToGsx($src_img_dir_path,$dest_img_dir_path,$gsx_type)) {
            $logger->error(__PACKAGE__ . ".$sub_name GSX Images Copy was not successful");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
        $array_index++;
    }
    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
    return 1;

} # End sub copyGsxImagesAlloc


=head1 B<populateGsxVarsInStr()>

 This function substitutes the following patterns if found in the string passed in as an argument (-str)  
 with the appropriate substring dedudced from data held in the GSX object in $artobj->{GSX} indexed from
 the value provided by the -index arg

 These patterns are likely to be used in GSX and PSX commands used in execTest and execPsxControl respectively.

			#+#ING_GSX_NAME#+#	- NAME of -ing_gsx
			#+#ING_GSX#+#		- GSX ID for -ing_gsx (not padded for single digit GSXs)
                        #+#ING_GSX_PAD#+#	- GSX ID for -ing_gsx (padded with 0 for single digit GSXs)
			#+#ING_GSX_DIG1#+#	- 1st digit of GSX ID for -ing_gsx
			#+#ING_GSX_DIG2#+#	- 2nd digit of GSX ID for -ing_gsx
			#+#ING_SS7_NODE#+#      - Name of ingress GSX SS7 node 
			#+#EG_GSX#+#		- GSX ID for -eg_gsx (not padded for single digit GSXs) 
			#+#EG_GSX_PAD#+#	- GSX ID for -eg_gsx (padded with 0 for single digit GSXs)
			#+#EG_GSX_DIG1#+#	- 1st digit of GSX ID for -eg_gsx
 			#+#EG_GSX_DIG2#+#	- 2nd digit of GSX ID for -eg_gsx
			#+#EG_SS7_NODE#+#       - Name of egress GSX SS7 node

=over 6

=item ARGUMENTS:

 -str <String that needs to be checked for any patterns to be substitued>
 -index <the value of n in -gsx<n> when issued from a GSX control>

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $artobj->{GSX} 
   Array containing the GSX objects

=item EXTERNAL FUNCTIONS USED:

 NONE

=item OUTPUT:

 string with relevant substitutions made - if command successful
 "" - (empty string) otherwise (failure)

=item EXAMPLE: 

 populateGsxVarsInStr(-str => "update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#ITU1 Gateway_Id #+#ING_GSX_NAME#+# Billing_Noa 0", -gsx_index => 0);

=back

=cut

sub populateGsxVarsInStr {
    my (%args) = @_;
    my $sub = "populateGsxVarsInStr()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $gsx_obj_ref;

    $logger->debug(__PACKAGE__ . ".$sub Entering $sub");
    # Check if -str arg is defined and not blank
    unless (defined($args{-str}) && ($args{-str} !~ m/^\s*$/)) {
        $logger->error(__PACKAGE__ . ".$sub -str <string> argument undefined or is blank ");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function with empty string");
        return "";
    }

    # Check if -index arg is defined and greater or equal than 1
    unless ( defined($args{-index}) && ($args{-index} >= 1)) {
        $logger->error(__PACKAGE__ . ".$sub -index argument is undefined or is not greaterh or equal to 1");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function with empty string");
        return "";
    }

    my $array_index = $args{-index} - 1;

    # Check if egress GSX is defined
    # It is assumed here that egress GSX array index is one more then the array
    # index for the ingress GSX unless only one GSX defined.
    my $egress_gsx_idx = $array_index+1;
    if ($#{$artobj->{GSX}} == 0) {
       $egress_gsx_idx = 0;
       $array_index = 0;
    }

    my $modified_string = $args{-str};           
        
    # Substitute patterns in $modified_string
    unless (defined(${$artobj->{GSX}}[$array_index])) {
        $logger->error(__PACKAGE__ . ".$sub No GSX object defined for array index $array_index");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function with blank string");
        return ""; 
    }
    my $ingress_gsx_name = "";
    if (defined(${$artobj->{GSX}}[$array_index]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME})) {
        $ingress_gsx_name = uc(${$artobj->{GSX}}[$array_index]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME});
        $logger->debug(__PACKAGE__ . ".$sub Found ingress GSX Name '$ingress_gsx_name '");
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub TMS ALIAS \"NAME\" data for GSX object indexed '$array_index' is missing");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function with blank string");
        return "";
    }

    if ($modified_string =~ /\#\+\#ING_GSX_NAME\#\+\#/) {
        $logger->debug(__PACKAGE__ . ".$sub Substituting '\#\+\#ING_GSX_NAME\#\+\#' with '$ingress_gsx_name' in '$modified_string'");
        $modified_string =~ s/\#\+\#ING_GSX_NAME\#\+\#/$ingress_gsx_name/g;
    }

    my $ing_gsx_id = "";
    my $ing_padded_gsx_id = "";
    if (defined(${$artobj->{GSX}}[$array_index]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID})) {
        $ing_gsx_id = ${$artobj->{GSX}}[$array_index]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID};
        $ing_padded_gsx_id = $ing_gsx_id;

        if (length($ing_gsx_id) == 1) {
            $ing_padded_gsx_id = "0" . $ing_gsx_id;
        }
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub TMS ALIAS \"LAB_ID\" data for GSX object indexed $array_index is missing");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function with blank string");
        return "";
    }

    if ($modified_string =~ /\#\+\#ING_GSX\#\+\#/) {
        $logger->debug(__PACKAGE__ . ".$sub Substituting '\#\+\#ING_GSX\#\+\#' with '$ing_gsx_id' in '$modified_string'");
        $modified_string =~ s/\#\+\#ING_GSX\#\+\#/$ing_gsx_id/g; 
    }
 
    if ($modified_string =~ /\#\+\#ING_GSX_PAD\#\+\#/) { 
        $logger->debug(__PACKAGE__ . ".$sub Substituting '\#\+\#ING_GSX_PAD\#\+\#' with '$ing_padded_gsx_id' in '$modified_string'");
        $modified_string =~ s/\#\+\#ING_GSX_PAD\#\+\#/$ing_padded_gsx_id/g;
    }

    if ($modified_string =~ /\#\+\#ING_GSX_DIG1\#\+\#/) {
        my $firstchar = substr($ing_padded_gsx_id,0,1);
        $logger->debug(__PACKAGE__ . ".$sub Substituting '\#\+\#ING_GSX_DIG1\#\+\#' with '$firstchar' in '$modified_string'");
        $modified_string =~ s/\#\+\#ING_GSX_DIG1\#\+\#/$firstchar/g;
    }

    if ($modified_string =~ /\#\+\#ING_GSX_DIG2\#\+\#/) {
        my $secondchar = substr($ing_padded_gsx_id,1,1);
        $logger->debug(__PACKAGE__ . ".$sub Substituting '\#\+\#ING_GSX_DIG2\#\+\#' with '$secondchar' in '$modified_string'");
        $modified_string =~ s/\#\+\#ING_GSX_DIG2\#\+\#/$secondchar/g;
    }
    
    # We are making the assumption here that the ingress SS7 Node is the one
    # assigned to the first trunk group TG<GSX_NAME><PROTOCOL>1
    if ($modified_string =~ /\#\+\#ING_SS7_NODE_(\w+)\#\+\#/) { 
        my $prot_str = $1;
        my $ss7_node_name = "";
        my $tg_name = "TG" . ${ingress_gsx_name} . ${prot_str} . "1";
        if (defined(${$artobj->{GSX}}[$array_index]->{TG_CONFIG}->{$tg_name}->{SS7_NODE})) { 
              my @ss7_node_name_ary = keys %{${$artobj->{GSX}}[$array_index]->{TG_CONFIG}->{$tg_name}->{SS7_NODE}};
              $ss7_node_name = $ss7_node_name_ary[0] if defined($ss7_node_name_ary[0]); 
        } else {
            $logger->error(__PACKAGE__ . ".$sub Could not deduce or find SS7_NODE for Ingress Trunk group '$tg_name'");
            $logger->debug(__PACKAGE__ . ".$sub Leaving function with blank string");
            return "";
        }
        $logger->debug(__PACKAGE__ . ".$sub Substituting '\#\+\#ING_SS7_NODE_${prot_str}\#\+\#' with '$ss7_node_name' in '$modified_string'");
        $modified_string =~ s/\#\+\#ING_SS7_NODE_${prot_str}\#\+\#/$ss7_node_name/g; 
    }

    unless (defined(${$artobj->{GSX}}[$egress_gsx_idx])) {
        $logger->error(__PACKAGE__ . ".$sub No GSX object defined for array index $egress_gsx_idx for egress GSX");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function with blank string");
        return "";
    } 

    my $egress_gsx_name = ""; 
    if (defined(${$artobj->{GSX}}[$egress_gsx_idx]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME})) {
        $egress_gsx_name = uc(${$artobj->{GSX}}[$egress_gsx_idx]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME});
        $logger->debug(__PACKAGE__ . ".$sub Found egress GSX Name '$egress_gsx_name'");
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub TMS ALIAS \"NAME\" data for GSX object indexed '$egress_gsx_idx' is missing");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function with blank string");
        return "";
    }

    if ($modified_string =~ /\#\+\#EG_GSX_NAME\#\+\#/) {
        $logger->debug(__PACKAGE__ . ".$sub Substituting '\#\+\#EG_GSX_NAME\#\+\#' with '$egress_gsx_name' in '$modified_string'");
        $modified_string =~ s/\#\+\#EG_GSX_NAME\#\+\#/$egress_gsx_name/g;
    }

    my $eg_gsx_id = "";
    my $eg_padded_gsx_id = "";
    if (defined(${$artobj->{GSX}}[$egress_gsx_idx]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID})) { 
        $eg_gsx_id = ${$artobj->{GSX}}[$egress_gsx_idx]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID}; 
        $eg_padded_gsx_id = $eg_gsx_id; 
 
        if (length($eg_gsx_id) == 1) { 
            $eg_padded_gsx_id = "0" . $eg_gsx_id;
        } 
    } 
    else { 
        $logger->error(__PACKAGE__ . ".$sub TMS ALIAS \"LAB_ID\" data for GSX object indexed '$egress_gsx_idx' is missing");
        $logger->debug(__PACKAGE__ . ".$sub Leaving function with blank string");
        return "";
    }

    if ($modified_string =~ /\#\+\#EG_GSX\#\+\#/) { 
        $logger->debug(__PACKAGE__ . ".$sub Substituting '\#\+\#EG_GSX\#\+\#' with '$eg_gsx_id' in '$modified_string'");
        $modified_string =~ s/\#\+\#EG_GSX\#\+\#/$eg_gsx_id/g;  
    } 
  
    if ($modified_string =~ /\#\+\#EG_GSX_PAD\#\+\#/) {  
        $logger->debug(__PACKAGE__ . ".$sub Substituting '\#\+\#EG_GSX_PAD\#\+\#' with '$eg_padded_gsx_id' in '$modified_string'");
        $modified_string =~ s/\#\+\#EG_GSX_PAD\#\+\#/$eg_padded_gsx_id/g; 
    } 
 
    if ($modified_string =~ /\#\+\#EG_GSX_DIG1\#\+\#/) { 
        my $firstchar = substr($eg_padded_gsx_id,0,1); 
        $logger->debug(__PACKAGE__ . ".$sub Substituting '\#\+\#EG_GSX_DIG1\#\+\#' with '$firstchar' in '$modified_string'");
        $modified_string =~ s/\#\+\#EG_GSX_DIG1\#\+\#/$firstchar/g; 
    } 

    if ($modified_string =~ /\#\+\#EG_GSX_DIG2\#\+\#/) { 
        my $secondchar = substr($eg_padded_gsx_id,1,1); 
        $logger->debug(__PACKAGE__ . ".$sub Substituting '\#\+\#EG_GSX_DIG1\#\+\#' with '$secondchar' in '$modified_string'");
        $modified_string =~ s/\#\+\#EG_GSX_DIG2\#\+\#/$secondchar/g; 
    }

    # We are making the assumption here that the egress SS7 Node is the one
    # assigned to the second trunk group TG<GSX_NAME><PROTOCOL>2
    if ($modified_string =~ /\#\+\#EG_SS7_NODE_(\w+)\#\+\#/) { 
        my $prot_str = $1;
        my $ss7_node_name = "";
        my $tg_name = "TG" . ${egress_gsx_name} . ${prot_str} . "2";
        if (defined(${$artobj->{GSX}}[$egress_gsx_idx]->{TG_CONFIG}->{$tg_name}->{SS7_NODE})) { 
              my @ss7_node_name_ary = keys %{${$artobj->{GSX}}[$egress_gsx_idx]->{TG_CONFIG}->{$tg_name}->{SS7_NODE}};
              $ss7_node_name = $ss7_node_name_ary[0] if defined($ss7_node_name_ary[0]); 
        } else {
            $logger->error(__PACKAGE__ . ".$sub Could not deduce or find SS7_NODE for Egress Trunk group '$tg_name'");
            $logger->debug(__PACKAGE__ . ".$sub Leaving function with blank string");
            return "";
        }
        $logger->debug(__PACKAGE__ . ".$sub Substituting '\#\+\#EG_SS7_NODE_${prot_str}\#\+\#' with '$ss7_node_name' in '$modified_string'");
        $modified_string =~ s/\#\+\#EG_SS7_NODE_${prot_str}\#\+\#/$ss7_node_name/g; 
    }
    
    
    $logger->debug(__PACKAGE__ . ".$sub Leaving function successfully with populated string");
    return "$modified_string";
}


=head1 B<execPsxControl()>

 This function executes a PSX EMS CLI command using $emsobj->execCmd()and returns command success or failure. 
 The PSX EMS CLI commands that are passed in as arguments (-psx<n> ) are able to contain the following patterns 
 which will be substituted by the values corresponding to GSX <n-1> (array index value to $artobj->{gsx} array). 
 If the pattern contains "EG_" then <n> is used as the array index to $artobj->{gsx} array.

			#+#ING_GSX_NAME#+#	- NAME of -ing_gsx
			#+#ING_GSX#+#		- GSX ID for -ing_gsx (not padded for single digit GSXs)
                        #+#ING_GSX_PAD#+#	- GSX ID for -ing_gsx (padded with 0 for single digit GSXs)
			#+#ING_GSX_DIG1#+#	- 1st digit of GSX ID for -ing_gsx
			#+#ING_GSX_DIG2#+#	- 2nd digit of GSX ID for -ing_gsx
			#+#EG_GSX#+#		- GSX ID for -eg_gsx (not padded for single digit GSXs) 
			#+#EG_GSX_PAD#+#	- GSX ID for -eg_gsx (padded with 0 for single digit GSXs)
			#+#EG_GSX_DIG1#+#	- 1st digit of GSX ID for -eg_gsx
 			#+#EG_GSX_DIG2#+#	- 2nd digit of GSX ID for -eg_gsx

=over 6

=item ARGUMENTS:

 -psx<n> <PSX EMS CLI command to action>
 -default_psx_cmd <PSX EMS CLI command to set default value of command specified by psx<n>>

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 $artcfg->{EMSCLI_ALLOC} 
   Defined in ART tool configuration file and used to identify EMS object. 

 $testcfg->{SKIP_GROUP}
   Indicates whether PSX control execution should be skipped as the rest of the group is to be skipped.

 $testcfg->{TEST_POSITION}
   Initialised in setupTestGrpConfig() function and used to note position of test or control in test group configuration file.

 %default_psx_cmds
   Initialised in setupTestGrpConfig() function and used to set PSX back to default values at end of group.

=item EXTERNAL FUNCTIONS USED:

 SonusQA::EMSCLI::execCmd()

=item OUTPUT:

 1 - if command successful
 0 - otherwise (failure)

=item EXAMPLE: 

 execPsxControl(-psx1 => "update Trunkgroup Trunkgroup_Id <TG> Gateway_Id <GSX> Feature_Control_Profile_Id <FCP>");

=back

=cut

sub execPsxControl {

    my (%args) = @_;
    my $sub_name = "execPsxControl()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my ($psx_index,$array_index,$key);
    my $psx_option = 0;
    my ($psx_cli_cmd,$emsobj);

    $logger->debug(__PACKAGE__ . ".$sub_name Entering $sub_name");

    # Increment test position by 1
    $testcfg->{TEST_POSITION} = $testcfg->{TEST_POSITION} + 1;

    # Do not execute any PSX controls if the skip_group flag is true
    if ( defined($testcfg->{SKIP_GROUP}) && $testcfg->{SKIP_GROUP} == 1) {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:execPsxControl, TestPos: $testcfg->{TEST_POSITION}, Reason: Due to previous error.");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    # Check if -psx<n> option specified
    foreach my $k (sort keys %args) {
        if ($k =~ m/.*(-psx)(\d+)/i) {
            if ($psx_option == 1) {
                $logger->error(__PACKAGE__ . ".$sub_name More than one -psx<n> option specified");
                $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                return 0;    
            }
            $psx_option = 1;
            # This $array_index value is used to index both the $artobj->{emscli} and $artobj->{gsx} arrays.
            $psx_index = $2;
	    $array_index = $psx_index - 1;	
            $key = $k;
        } 
    }

    unless ($psx_option) {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:execPsxControl, TestPos: $testcfg->{TEST_POSITION}, Reason: -psx<n> not specified");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    } 


    unless (defined($args{$key}) and ($args{$key} !~ /^\s*$/)) {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:execPsxControl, TestPos: $testcfg->{TEST_POSITION}, Reason: PSX EMS CLI cmd not specified or is blank");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    $psx_cli_cmd = $args{$key};

    $logger->debug(__PACKAGE__ . ".$sub_name PSX CLI CMD is $psx_cli_cmd");
    
    # Check if egress GSX is defined
    # It is assumed here that egress GSX array index is one more then the array
    # index for the ingress GSX unless only one GSX defined.

    my $egress_gsx_idx = 1;
    if ($#{$artobj->{GSX}} == 0) {
       $egress_gsx_idx = 0;
       $array_index = 0;
    }
                    
    # Check EMS CLI object exists
    unless (defined(${$artobj->{EMSCLI}}[$array_index])) {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:execPsxControl, TestPos: $testcfg->{TEST_POSITION}, Reason: No allocated EMS object");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    $emsobj = ${$artobj->{EMSCLI}}[$array_index];

    # Check -default_psx_cmd option is specified
    unless (exists($args{-default_psx_cmd})) {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:execPsxControl, TestPos: $testcfg->{TEST_POSITION}, Reason: -default_psx_cmd not specified");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function"); 
        return 0;
    }

    unless (defined($args{-default_psx_cmd}) and ($args{-default_psx_cmd} !~ /^\s*$/)) {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:execPsxControl, TestPos: $testcfg->{TEST_POSITION}, Reason: Default PSX EMS CLI cmd not specified or is blank");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    $default_psx_cmd = $args{-default_psx_cmd};
                       
    # Substitute patterns in $psx_cli_cmd and $default_psx_cmd strings
    my $tmp_psx_cli_cmd = populateGsxVarsInStr(-str => $psx_cli_cmd, -index => $psx_index);
    my $tmp_default_cli_cmd = populateGsxVarsInStr(-str => $default_psx_cmd, -index => $psx_index); 

    if ($tmp_psx_cli_cmd eq "") {
        $logger->error(__PACKAGE__ . ".$sub_name String substitution failure in '$psx_cli_cmd'");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        exit; 
    } else {
        $logger->debug(__PACKAGE__ . ".$sub_name Substituted '$psx_cli_cmd' with '$tmp_psx_cli_cmd'");
        $psx_cli_cmd = $tmp_psx_cli_cmd;
    }     
             
	
    if ($tmp_default_cli_cmd eq "") {
        $logger->error(__PACKAGE__ . ".$sub_name String substitution failure in '$default_psx_cmd'");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        exit; 
    } else {
        $logger->debug(__PACKAGE__ . ".$sub_name Substituted '$default_psx_cmd' with '$tmp_default_cli_cmd'");
        $default_psx_cmd = $tmp_default_cli_cmd;
    }     

    $testcfg->{DEFAULT_PSX_CMDS}->{$array_index}->{$default_psx_cmd} = 1;

    $logger->debug(__PACKAGE__ . ".$sub_name PSX CLI CMD : $psx_cli_cmd");
    $logger->debug(__PACKAGE__ . ".$sub_name DEFAULT PSX CMD : $default_psx_cmd");

     
    if ($psx_cli_cmd =~ m/^(update)(.*) (Element_)?Attributes ([\-]?)(.*)$/i) {
        # Element attributes command passed in has the hex value of the flag to
        # set or unset. A '-' in front of the hex value indicates that the
        # flag is to be unset.
        
        # Extract the parts of the command as follows:
        my $psx_tmp_cmd = $2; # strip off the update
        my $elem_str = $3;
	$elem_str = "" unless defined($elem_str);		
        my $sign = $4;
	$sign = "" unless defined($sign);		
        my $attrib_val = $5;
        
        # We first need to get the current element attribute value
        # Build up show command
        my $psx_show_cmd = "show" . $psx_tmp_cmd;
        # Execute show command
        my @psx_show_cmd_output =  $emsobj->execCmd("$psx_show_cmd");
    
        foreach (@psx_show_cmd_output) {

            if ($_ =~ /^error/i) {
                $logger->error(__PACKAGE__ . ".$sub_name FAILURE:Error encountered during cmd execution CMD: '$psx_show_cmd' CMDRESULT: @psx_show_cmd_output");
                setSkipGrpData("Function: execPsxControl() Cmd: '$psx_cli_cmd' Reason: Failed to show data for '$psx_show_cmd'");  
                $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                return 0;
            }
       }

        # Loop through show command result until Elemnt_Attributes is found
        foreach my $line (@psx_show_cmd_output) {
          chomp($line);
          if ($line =~ m/^\s+(Element_)?Attributes\s+\: (.*)$/) {
              # Extract existing Element_Attributes or Attributes  value 
              my $existing_attrib_val = $2;
              # convert to decimal
		
              $logger->debug(__PACKAGE__ . ".$sub_name Exisiting ${elem_str}Attributes value is '$existing_attrib_val'");
              my $existing_attrib_val_hex = oct($existing_attrib_val);
              # Convert the new flag value to decimal 
              my $attrib_val_hex = oct($attrib_val);

              # AND the two values together
              my $hex1 = $existing_attrib_val_hex & $attrib_val_hex;
              # If we AND the new hex value $attrib_val_hex to the existing
              # value then if then if already set the AND will return
              # $attrib__val_hex, otherwise it will return 0
              $logger->debug(__PACKAGE__ . ".$sub_name Sign ='$sign' hex1='$hex1'");
              my $new_attrib_val = "";
              if ($hex1 == 0 && $sign eq "") { 
                  # If flag wasn't set and $sign is blank indicating that we
                  # actually want to set this flag then set new Element
                  # Attributes value to the old hex value + $attrib_val_hex
                  $hex1 =  $attrib_val_hex + $existing_attrib_val_hex; 
                  $new_attrib_val = sprintf "0x%x", $hex1;
                  $logger->debug(__PACKAGE__ . ".$sub_name Setting '$attrib_val' ${elem_str}Attributes flag from '$existing_attrib_val' to new value of '$new_attrib_val'");
              } elsif ($hex1 == $attrib_val_hex && $sign =~ /^\-$/) {
                  # If flag was set and $sign is '-' indicating that we
                  # actually want to unset this flag then set new Element
                  # Attributes value to the old hex value - $attrib_val_hex
                  $hex1 =  $existing_attrib_val_hex - $attrib_val_hex; 
                  $new_attrib_val = sprintf "0x%x", $hex1;
                  $logger->debug(__PACKAGE__ . ".$sub_name Unsetting '$attrib_val' ${elem_str}Attributes flag from '$existing_attrib_val' to new value of '$new_attrib_val'");
              } else {
                  my $set_str = "set";
                  $set_str = "unset" if $sign =~ /^\-$/;
                  $logger->debug(__PACKAGE__ . ".$sub_name ${elem_str}Attributes flag '$attrib_val' already $set_str in '$existing_attrib_val'");
              }

              if ($new_attrib_val eq "") {
                  # We are (Element) Attributes but value must already be set
                  # correctly. Just return null $psx_cli_cmd
                  $psx_cli_cmd = "null";
              } else {
                  # Construct new (Element_)Attributes update cmd
                  $psx_cli_cmd = "update " . $psx_tmp_cmd . " ${elem_str}Attributes " . $new_attrib_val;
              }
              # jump out of loop as we have completed processing
              last;
          }
        }  
    } 
    

    if ($psx_cli_cmd =~ m/^(update)\s+(Service_Definition\s+Service_Id\s+\w+\s+)(.*)$/i) {
        # We need to find the SCP_Query_Priority for the Service Definition table
        
        # Extract the parts of the command as follows:
        my $psx_tmp_cmd = $2; # strip off the update
        my $rest_of_psx_tmp_cmd = $3;

        # We first need to get the current Scp_Query_Priority value
        # Build up show command
        my $psx_show_cmd = "show " . $psx_tmp_cmd;
        # Execute show command
        my @psx_show_cmd_output =  $emsobj->execCmd("$psx_show_cmd");

        foreach (@psx_show_cmd_output) {

            if ($_ =~ /^error/i) {
                $logger->error(__PACKAGE__ . ".$sub_name FAILURE:Error encountered during cmd execution CMD: '$psx_show_cmd' CMDRESULT: @psx_show_cmd_output");
                setSkipGrpData("Function: execPsxControl() Cmd: '$psx_cli_cmd' Reason: Failed to show data for '$psx_show_cmd'");  
                $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
                return 0;
            }
       }

        my $existing_priority_val;

        # Loop through show command result until Scp_Query_Priority is found
        foreach my $line (@psx_show_cmd_output) {
          chomp($line);
          if ($line =~ m/^\s+Scp_Query_Priority\s+\: (.*)$/) {
              # Extract existing SCP QUERY PRIORITY  value 
              $existing_priority_val = $1;
              # jump out of loop
              last;
          }
        }

       if (defined($existing_priority_val)) {
          # Construct new Service_Defintion update cmd
          $psx_cli_cmd = "update " . $psx_tmp_cmd . " Scp_Query_Priority " . $existing_priority_val . " " . $rest_of_psx_tmp_cmd;
          $logger->info(__PACKAGE__ . ".$sub_name Updated PSX CLI cmd to '$psx_cli_cmd'");
       } else {  
            $logger->error(__PACKAGE__ . ".$sub_name FAILURE: Failed to find Scp_Query_Priority for psx cmd '$psx_show_cmd'");
            setSkipGrpData("Function: execPsxControl() Cmd: '$psx_cli_cmd' Reason: Failed to find Scp_Query_Prioirty via show cmd");  
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
       } 

    }

    if ($psx_cli_cmd eq "null") {
        @psx_cmd_output = ();
    } else {
        # execute the psx cli command 
        @psx_cmd_output = $emsobj->execCmd("$psx_cli_cmd");
    }

    foreach (@psx_cmd_output) {

        if ($_ =~ /^error/i) {
            $logger->error(__PACKAGE__ . ".$sub_name FAILURE:Error encountered during cmd execution CMD: '$psx_cli_cmd' CMDRESULT: @psx_cmd_output");
            setSkipGrpData("Function: execPsxControl() Cmd: '$psx_cli_cmd' Reason: @psx_cmd_output");  
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
    }
 
    $logger->debug(__PACKAGE__ . ".$sub_name SUCCESS - CMD: $psx_cli_cmd CMDRESULT: @psx_cmd_output");
    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
    return 1;

} # End sub execPsxControl

=head1 B<convertMgtsPsxControl()>

  This function takes the name of a MGTS PSX Control state machine and identifies the current Unix Exec Action state within 
  the state machine and converts the Unix command to an equivalent EMS CLI PSX update command. The mappings also include the 
 default setting for the PSX field being modified. The function returns two values, the first being the converted EMS CLI string 
 and the second being the default update EMS CLI command to reset the PSX field.

=over 6

=item ARGUMENTS: 

 -psx_control => MGTS PSX control state machine name(without .states)
 -dir_path => Location of the statemachine

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 An array containing two values:(<EMS CLI update string>,<Default EMS CLI update string>)
 0 - Otherwise

=back

=cut

sub convertMgtsPsxControl {
    
    my (%args) = @_;
    my $sub_name = "convertMgtsPsxControl()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my @returnvalues;
    my $section = "";

    $logger->debug(__PACKAGE__ . ".$sub_name Entering $sub_name");

    unless (defined($args{-psx_control}) and ($args{-psx_control} !~ /^\s*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name Psx Control is undefined or blank");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    unless (defined($args{-dir_path}) and ($args{-dir_path} !~ /^\s*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name Directory path is undefined or blank");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    my $statemachine = $args{-dir_path} . "/" . $args{-psx_control} . ".states";

    unless (-e $statemachine) {
        $logger->error(__PACKAGE__ . ".$sub_name Statemachine $statemachine does not exist");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    my $grep_result = `grep \"\^ACTION\=0 PARAM\=\/h\/\" $statemachine`;

    unless ($grep_result =~ /ACTION\=0 PARAM\=\/h\//) {
        $logger->error(__PACKAGE__ . ".$sub_name Statemachine $statemachine does not have pattern \"\^ACTION\=0 PARAM\=\/h\/\"");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name Statemachine $statemachine has pattern $grep_result");

    if ($grep_result =~ /(psx_car_tandem.e)\s+(\d+)\s+(\d+)\s+(\w+)/) {
        $section = $1;
        push @returnvalues,"update Carrier Carrier_Id $3 Tandem_Script_Id $4";
        push @returnvalues,"update Carrier Carrier_Id $3 Tandem_Script_Id PRESUB_NO_RET_IMM";
    }

    elsif ($grep_result =~ /(psx_dest.e)\s+(\d+)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        my $flag = $5;
        my $country = $3;
        $section = $1;
        if ($flag =~ /OFF/i) {
            push @returnvalues,"update Destination National_Id 5#+#EG_GSX_PAD#+#0702123 Country_Id $country Element_Attributes -0x00000003";
        }
        else {
            push @returnvalues,"update Destination National_Id 5#+#EG_GSX_PAD#+#0702123 Country_Id $country Element_Attributes 0x00000003";
        }
        push @returnvalues,"update Destination National_Id 5#+#EG_GSX_PAD#+#0702123 Country_Id $country Element_Attributes -0x00000003";
    }

    elsif ($grep_result =~ /(psx_gw_cb.e)\s+(\d+)\s+(\w+)/) {
        $section = $1;
        my $chgband = $3;
        if ($chgband =~ /NONE/i) {
            $chgband = "\\\"\\\"";
        }
        push @returnvalues,"update Gateway Gateway_Id #+#ING_GSX_NAME#+# Charge_Band_Profile_Id $chgband";
        push @returnvalues,"update Gateway Gateway_Id #+#ING_GSX_NAME#+# Charge_Band_Profile_Id \\\"\\\"";
    }

    elsif ($grep_result =~ /(psx_gw_pcli.e)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
        $section = $1;
        push @returnvalues,"update Gateway Gateway_Id #+#ING_GSX_NAME#+# Use_Partial_CLI 1 Switch_Type $3 Switch_Number $4 Switch_Identifier $5  Optional_Digits $6";
        push @returnvalues,"update Gateway Gateway_Id #+#ING_GSX_NAME#+# Use_Partial_CLI 0 Switch_Type \\\"\\\" Switch_Number \\\"\\\" Switch_Identifier \\\"\\\"  Optional_Digits \\\"\\\"";
    }
    elsif ($grep_result =~ /(psx_gw_pcli.e)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
        $section = $1;
        push @returnvalues,"update Gateway Gateway_Id #+#ING_GSX_NAME#+# Use_Partial_CLI 1 Switch_Type $3 Switch_Number $4 Switch_Identifier $5  Optional_Digits \\\"\\\"";
        push @returnvalues,"update Gateway Gateway_Id #+#ING_GSX_NAME#+# Use_Partial_CLI 0 Switch_Type \\\"\\\" Switch_Number \\\"\\\" Switch_Identifier \\\"\\\"  Optional_Digits \\\"\\\"";
    }
    elsif ($grep_result =~ /(psx_gw_pcli.e)\s+(\d+)\s+(\d+)\s+(\d+)/) {
        $section = $1;
        push @returnvalues,"update Gateway Gateway_Id #+#ING_GSX_NAME#+# Use_Partial_CLI 1 Switch_Type $3 Switch_Number $4 Switch_Identifier \\\"\\\" Optional_Digits \\\"\\\"";
        push @returnvalues,"update Gateway Gateway_Id #+#ING_GSX_NAME#+# Use_Partial_CLI 0 Switch_Type \\\"\\\" Switch_Number \\\"\\\" Switch_Identifier \\\"\\\"  Optional_Digits \\\"\\\"";
    }

    elsif ($grep_result =~ /(psx_gw_pcli_off.e)\s+(\d+)/) {
        $section = $1;
        push @returnvalues,"update Gateway Gateway_Id #+#ING_GSX_NAME#+# Use_Partial_CLI 0 Switch_Type \\\"\\\" Switch_Number \\\"\\\" Switch_Identifier \\\"\\\" Optional_Digits \\\"\\\"";
        push @returnvalues,"update Gateway Gateway_Id #+#ING_GSX_NAME#+# Use_Partial_CLI 0 Switch_Type \\\"\\\" Switch_Number \\\"\\\" Switch_Identifier \\\"\\\" Optional_Digits \\\"\\\"";
    }

    elsif ($grep_result =~ /(psx_pp_ovlap.e)\s+(\d+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
        $section = $1;
        push @returnvalues,"update Prefix_Profile_Data Prefix_Profile_Id $3 Prefix 5#+#EG_GSX_PAD#+# Match_Start_Location 0 Total_Min_Digits 0 Total_Max_Digits 0 Route_Min_Digits $4 Valid_Ph_No_Min_Digits $5 Valid_Ph_No_Max_Digits $6";
        push @returnvalues,"update Prefix_Profile_Data Prefix_Profile_Id $3 Prefix 5#+#EG_GSX_PAD#+# Match_Start_Location 0 Total_Min_Digits 0 Total_Max_Digits 0 Route_Min_Digits 0 Valid_Ph_No_Min_Digits 0 Valid_Ph_No_Max_Digits 0";
    }

    elsif ($grep_result =~ /(psx_rl_scr.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
	my $suffix = $3; 
        my $script = $4;
        my $action = 2;
        if ($script =~ /NONE/i) {
            $script = "\\\"\\\"";
            $action = 1;
        }
        push @returnvalues,"update Routing_Label Routing_Label_Id #+#EG_GSX_NAME#+#_${suffix} Script_Id $script Action $action";
        push @returnvalues,"update Routing_Label Routing_Label_Id #+#EG_GSX_NAME#+#_${suffix} Script_Id \\\"\\\" Action 1";
    }

    elsif ($grep_result =~ /(psx_sd_flag.e)\s+(\d+)\s+(\w+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $attr;

        my $type = $4;
        my $flag = $5;
        if ($type =~ /LNP/i) {
            $attr = "0x0020";
        }
        elsif ($type =~ /RAC/i) {
            $attr = "0x0010";
        }

        if ($flag =~ /OFF/i) {
            push @returnvalues,"update Service_Definition Service_Id GSX_#+#ING_GSX_NAME#+#_JPN_SRV Attributes -$attr";
        }
        elsif ($flag =~ /ON/i) {
            push @returnvalues,"update Service_Definition Service_Id GSX_#+#ING_GSX_NAME#+#_JPN_SRV Attributes $attr";
        }

        push @returnvalues,"update Service_Definition Service_Id GSX_#+#ING_GSX_NAME#+#_JPN_SRV Attributes -$attr";
    }

    elsif ($grep_result =~ /(psx_sd_tc.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $trig = $4;
        if ($trig =~ /NONE/i) {
            push @returnvalues,"update Service_Definition Service_Id GSX_#+#ING_GSX_NAME#+#_JPN_SRV Trigger_Filter_Criteria \\\"\\\"";
        }
        else {
            push @returnvalues,"update Service_Definition Service_Id GSX_#+#ING_GSX_NAME#+#_JPN_SRV Trigger_Filter_Criteria GSX_#+#ING_GSX_NAME#+#_JPN_NT";
        }

        push @returnvalues,"update Service_Definition Service_Id GSX_#+#ING_GSX_NAME#+#_JPN_SRV Trigger_Filter_Criteria \\\"\\\"";
    }

    elsif ($grep_result =~ /(psx_tg.e)\s+(\d+)\s+(\w+)\s+(\w+)\s*(\w*)/) {
        $section = $1;
        my $db_field = $4;
        my $tg_suffix = $3;
        my $db_val = $5;
        unless (defined($db_val) && $db_val !~ /^\s*$/) {
            $db_val = "\\\"\\\"";
        }
        my $cli_attr = "";
        my $default_val = "\\\"\\\"";

        if ($db_field =~ /CALLING_PARTY_ID/i) {
            $cli_attr = "Calling_Party_Id";
        }
        elsif ($db_field =~ /CALLING_PARTY_NOA/i) {
            $cli_attr = "Calling_Party_Noa";
        }
        elsif ($db_field =~ /CALLING_PARTY_NPI/i) {
            $cli_attr = "Calling_Party_Npi";
        }
        elsif ($db_field =~ /CARRIER_TYPE_PROFILE_ID/i) {
            $cli_attr = "Carrier_Type_Profile_Id";
        }
        elsif ($db_field =~ /CPN_PRESENTATION/i) {
            $cli_attr = "Cpn_Presentation";
        }
        elsif ($db_field =~ /CPN_SCREENING/i) {
            $cli_attr = "Cpn_Screening";
        }
        elsif ($db_field =~ /LRBTID/i) {
            $cli_attr = "Local_Ring_Back_Tone_Id";
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# $cli_attr $db_val";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# $cli_attr $default_val";
    }

    elsif ($grep_result =~ /(psx_tg_billnoa.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $bill_noa = $4;
        my $tg_suffix = $3;
        if ($bill_noa =~ /NONE/i) {
            $bill_noa = "0";
        }
        elsif ($bill_noa =~ /NATIONAL/i) {
            $bill_noa = "3";
        }
        elsif ($bill_noa =~ /ANI_NOT_AVAIL/i) {
            $bill_noa = "15";
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Billing_Noa $bill_noa";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Billing_Noa 0";
    }

    elsif ($grep_result =~ /(psx_tg_billnum.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $bill_num = $4;
        my $tg_suffix = $3;
        if ($bill_num =~ /NONE/i) {
            $bill_num = "\\\"\\\"";
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Billing_Id $bill_num";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Billing_Id \\\"\\\"";
    }

    elsif ($grep_result =~ /(psx_tg_carr_ingtg.e)\s+(\d+)\s+(\w+)\s+(\d+)/) {
        $section = $1;
        my $transit_cid = $4;
        my $tg_suffix = $3;
        if ($transit_cid == 0) {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x00000010";
        }
        else {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes 0x00000010";
        }
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x00000010";
    }

    elsif ($grep_result =~ /(psx_tg_carsel.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$3 Gateway_Id #+#ING_GSX_NAME#+# Carrier_Selection_Priority_Id $4";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$3 Gateway_Id #+#ING_GSX_NAME#+# Carrier_Selection_Priority_Id DEFAULT_CSP_JAPAN";
    }

    elsif ($grep_result =~ /(psx_tg_cartype.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $carrier_type = $4;
        my $tg_suffix = $3;
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Carrier_Type_Profile_Id $carrier_type";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Carrier_Type_Profile_Id DEFAULT";
    }

    elsif ($grep_result =~ /(psx_tg_citinfo.e)\s+(\d+)\s+(\w+)\s+(\d+)/) {
        $section = $1;
        my $sendcitinfo_flag = $4;
        if ($sendcitinfo_flag == 0) {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$3 Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x00000080";
        }
        else {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$3 Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes 0x00000080";
        }
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$3 Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x00000080";
    }

    elsif ($grep_result =~ /(psx_tg_cos.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$3 Gateway_Id #+#ING_GSX_NAME#+# Class_Of_Service_Id $4";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$3 Gateway_Id #+#ING_GSX_NAME#+# Class_Of_Service_Id SPGT5";
    }

    elsif ($grep_result =~ /(psx_tg_country.e)\s+(\d+)\s+(\w+)\s+(\d+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $def_countryid;
        my $countryid = $4;
        if ($tg_suffix =~ /JAPAN/i) {
            $def_countryid = 81;
        }
        elsif ($tg_suffix =~ /BT/i) {
            $def_countryid = 44;
        }
        else {
            $def_countryid = 1;
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Country_Id $countryid";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Country_Id $def_countryid";
    }

    elsif ($grep_result =~ /(psx_tg_cri.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $chgrate_info = $4;
        my $tg_suffix = $3;
        if ($chgrate_info =~ /NONE/i) {
            $chgrate_info = "\\\"\\\"";
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Charge_Information_Id $chgrate_info";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Charge_Information_Id \\\"\\\"";
    }

    elsif ($grep_result =~ /(psx_tg_dm.e)\s+(\d+)\s+(\w+)\s+(\w+)\s+(\w+)(\s+(\w+))?/) {
        $section = $1;
        my $gw_ind = "";
        $gw_ind = $6 if $6;
        my $inout_ind = $4;
        my $dm_rule = $5;
        my $tg_suffix = $3;

       my $gateway_id;
        if ($gw_ind =~ /H323/i) {
            $gateway_id = "#+#ING_GSX_NAME#+#_H323";
        }
        else {
            $gateway_id = "#+#ING_GSX_NAME#+#";
        }

        my $dm_rule_field;
        if ($inout_ind eq "I") {
            $dm_rule_field = "In_Pm_Rule_Id";
        }
        else {
            $dm_rule_field = "Out_Pm_Rule_Id";
        }

        if ($dm_rule =~ /NONE/i) {
            $dm_rule = "\\\"\\\"";
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id $gateway_id $dm_rule_field $dm_rule";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id $gateway_id $dm_rule_field \\\"\\\"";
    }

    elsif ($grep_result =~ /(psx_tg_fcp.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $fcp = $4;
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Feature_Control_Profile_Id $fcp";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Feature_Control_Profile_Id DEFAULT_FC_IXC";
    }

    elsif ($grep_result =~ /(psx_tg_jip.e)\s+(\d+)\s+(\w+)\s+(\d+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $jip = $4;

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Jip_Id $jip";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Jip_Id 123456";
    }

    elsif ($grep_result =~ /(psx_tg_jtls.e)\s+(\d+)\s+(\w+)\s+(\d+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $jtls = $4;

        if ($jtls eq 0) {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x00000004";
        }
        else {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes 0x00000004";
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x00000004";
    }

    elsif ($grep_result =~ /(psx_tg_net_id.e)\s+(\d+)\s+(\w+)\s+(\d+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $netid = $4;
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Networkdata_Net $netid";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Networkdata_Net $netid";
    }

    elsif ($grep_result =~ /(psx_tg_no_fb_bearcap.e)\s+(\d+)\s+(\w+)\s+(\d+)/) {
        $section = $1;
        my $fb_bearcap_flag = $4;
        my $tg_suffix = $3;
        if ($fb_bearcap_flag == 0) {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x00100000";
        }
        else {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes 0x00100000";
        }
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x00100000";
    }

    elsif ($grep_result =~ /(psx_tg_np.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $def_np;
        my $np_id = $4;
        if ($tg_suffix =~ /BT/i) {
            $def_np = "UK_NUM_PLAN";
        }
        else {
            $default_np = "NANP_IXC";
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Numbering_Plan_Id $np_id";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Numbering_Plan_Id $default_np";
    }

    elsif ($grep_result =~ /(psx_tg_olip.e)\s+(\d+)\s+(\w+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $olip_ind = $4;
        my $olip_value = $5;

        if ($olip_ind =~ /FORCED/i) {
            $olip_field = "Forced_Olip";
        }
        else {
            $olip_field = "Default_Olip";
        }

        if ($olip_value =~ /NONE/i) {
            $olip_value = "-1";
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# $olip_field $olip_value";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# $olip_field -1";
    }
    elsif ($grep_result =~ /(psx_tg_ovlap.e)\s+(\d+)\s+(\w+)\s+(\d+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $ovlap = $4;
        if ($ovlap eq 0) {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x20000000";
        }
        else {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes 0x20000000";
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x20000000";
    }

    elsif ($grep_result =~ /(psx_tg_owncar.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $owncar = $4;
        if ($owncar eq "NONE") {
            $owncar="\\\"\\\"";
        }
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Own_Carrier_Id $owncar";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Own_Carrier_Id 0077";
    }

    elsif ($grep_result =~ /(psx_tg_part_id.e)\s+(\d+)\s+(\w+)\s+(\d+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $part_id = $4;
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Networkdata_Partition $part_id";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Networkdata_Partition 0";
    }

    elsif ($grep_result =~ /(psx_tg_poi_chg.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $poichg = $4;
        if ($poichg =~ /NONE/i) {
           $poichg = "\\\"\\\"";
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Poi_Charge_Area $poichg"; 
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Poi_Charge_Area 00777";
    }

    elsif ($grep_result =~ /(psx_tg_poi.e)\s+(\d+)\s+(\w+)\s+(\d+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $poilevel = $4;
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Poi_Level $poilevel";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Poi_Level 0";
    }

    elsif ($grep_result =~ /(psx_tg_sigflag.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $sig_flag = $4;
        switch ($sig_flag)
        {
            case /GR394/i
            {
                $sigflag_id = 1;
            }
            case /GR317/i
            {
                $sigflag_id = 2;
            }
            case /ISDN/i
            {
                $sigflag_id = 3;
            }
            case /CAS/i
            {
                $sigflag_id = 4;
            }
            case /ITU/i
            {
                $sigflag_id = 5;
            }
            case /JAPAN/i
            {
                $sigflag_id = 6;
            }
            case /BT/i
            {
                $sigflag_id = 10;
            }
            case /CHINA/i
            {
                $sigflag_id = 12;
            }
            else {
                $sigflag_id = 7;
            }
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Signaling_Flag $sigflag_id";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Signaling_Flag 2";
    }

    elsif ($grep_result =~ /(psx_tg_sp.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $sig_prof = $4;
        my $def_sigprof;
        if ($tg_suffix =~ /ANSI/i) {
            $def_sigprof = "GR317_TRANSALL";
        }
        elsif ($tg_suffix =~ /JAPAN/i) {
            $def_sigprof = "SP_JAPAN";
        }
        else {
            $def_sigprof = "SIGPROFILE_1";
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Signaling_Profile_Id $sig_prof";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Signaling_Profile_Id $def_sigprof";
    }
    elsif ($grep_result =~ /(psx_tg_switcht.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $switchtype = $4;
        switch ($switchtype)
        {
            case /ACCESS|INTRANET/i
            {
                $switch_type_id = 1;
            }
            case /TANDEM/i
            {
                $switch_type_id = 2;
            }
            case /ENDOFFIC|EAEO/i
            {
                $switch_type_id = 3;
            }
            case /NON/i
            {
                $switch_type_id = 4;
            }
            case /IXC|NATIONAL/i
            {
                $switch_type_id = 5;
            }
            case /INTERNAT/i
            {
                $switch_type_id = 6;
            }
            else {
                $switch_type_id = 1;
            }
        }

        my $default_switch_type;
        if ($tg_suffix =~ /ANSI/i) {
            $default_switch_type = 3;
        }
        elsif ($tg_suffix =~ /JAPAN/i) {
            $default_switch_type = 5;
        }
        else {
            $default_switch_type = 2;
        }

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Destination_Switch_Type $switch_type_id";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Destination_Switch_Type $default_switch_type";
    }
    elsif ($grep_result =~ /(psx_tg_tdm.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $tdm_type = $4;
        switch ($tdm_type)
        {
            case /IMT$/i
            {
                $tdm_type = 1;
            }
            case /NTT/i
            {
                $tdm_type = 8;
                if ($grep_result =~ /(psx_tg_tdm.e)\s+(\d+)\s+(\w+)\s+(\w+)\s+(\w+)/) {
                    my $tdm_type1 = $5;
                    if ($tdm_type1 =~ /GC/i) {
                        $tdm_type = 9;
                    }
                }
            }
            case /GC/i
            {
                $tdm_type = 9;
            }
            case /IMT1/i
            {
                $tdm_type = 10;
            }
            case /LS$/i
            {
                $tdm_type = 11;
            }
            case /LS3/i
            {
                $tdm_type = 12;
            }
            case /CT/i
            {
                $tdm_type = 13;
            }
            case /INT1/i
            {
                $tdm_type = 14;
            }
            case /INT2/i
            {
                $tdm_type = 15;
            }
            case /INT3/i
            {
                $tdm_type = 16;
            }
            case /INT4/i
            {
                $tdm_type = 17;
            }
            case /INT5/i
            {
                $tdm_type = 18;
            }
            case /INT7/i
            {
                $tdm_type = 19;
            }
            case /SSP/i
            {
                $tdm_type = 20;
            }
            case /INTS/i
            {
                $tdm_type = 21;
            }
            case /TST/i
            {
                $tdm_type = 22;
            }
            else {
                $tdm_type = 0;
            }
        } # End switch

        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Tdm_Trunk_Type $tdm_type";
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Tdm_Trunk_Type 0";
    }

    elsif ($grep_result =~ /(psx_tg_tns.e)\s+(\d+)\s+(\w+)\s+(\d+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $tns_flag = $4;
        if ($tns_flag eq 0) {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x00400000";
        }
        else {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes 0x00400000";
        }
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x00400000";
    }
 
    elsif ($grep_result =~ /(psx_tg_zz.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $zz = $4;
        if ($zz =~ /NONE/i) {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Zz_Profile_Id \\\"\\\"";
        }
        else {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Zz_Profile_Id $zz";
        }
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Zz_Profile_Id \\\"\\\"";
    }

    elsif ($grep_result =~ /(psx_tg_sat.e)\s+(\d+)\s+(\w+)\s+(\d+)/) {
        $section = $1;
        my $tg_suffix = $3;
        my $sat_flag = $4;
        if ($sat_flag eq 0) {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x4000000";
        }
        else {
            push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes 0x4000000";
        }
        push @returnvalues,"update Trunkgroup Trunkgroup_Id TG#+#ING_GSX_NAME#+#$tg_suffix Gateway_Id #+#ING_GSX_NAME#+# Element_Attributes -0x4000000";
    }

    else {
        $logger->error(__PACKAGE__ . ".$sub_name Unix Exec Script '$grep_result' not recognised");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function with retcode-0");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name Return Values - @returnvalues");
    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function from section '$section'");
    return @returnvalues;

} # End sub convertMgtsPsxControl

=head1 B<convertMgtsGsxControl(>)

  This function takes the name of a MGTS GSX Control state machine and identifies the current Unix Exec Action state within the 
 state machine and converts the Unix command to an equivalent GSX CLI command. The function returns an array of GSX CLI strings 
 that are mapped from the current MGTS GSX Control state machine.

=over 6

=item ARGUMENTS:

 -gsx_control => MGTS GSX control state machine name(without .states)
 -dir_path => Location of the statemchine

=item PACKAGE:

 SonusQA::GSX::ART

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 An array of GSX CLI strings 

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

sub convertMgtsGsxControl {

    my (%args) = @_; 
    my $sub_name = "convertMgtsGsxControl()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    my @returnvalues;
    my $section = "";

    $logger->debug(__PACKAGE__ . ".$sub_name Entering $sub_name");

    unless (defined($args{-gsx_control}) and ($args{-gsx_control} !~ /^\s*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name GSX Control is undefined or blank");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function retcode-0");
        return 0;
    }

    unless (defined($args{-dir_path}) and ($args{-dir_path} !~ /^\s*$/)) {
        $logger->error(__PACKAGE__ . ".$sub_name Directory path is undefined or blank");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function retcode-0");
        return 0;
    }

    my $statemachine = trim ($args{-dir_path}) . "/" . trim( $args{-gsx_control} ) . ".states";

    unless (-e $statemachine) {
        $logger->error(__PACKAGE__ . ".$sub_name Statemachine $statemachine does not exist");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function retcode-0");
        return 0;
    }

    my $grep_result = `grep \"\^ACTION\=0 PARAM\=\/h\/\" $statemachine`;

    unless ($grep_result =~ /ACTION\=0 PARAM\=\/h\//) {
        $logger->error(__PACKAGE__ . ".$sub_name Statemachine $statemachine does not have pattern \"\^ACTION\=0 PARAM\=\/h\/\"");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function retcode-0");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub_name Statemachine $statemachine has pattern $grep_result");

    if ($grep_result =~ /(acct_setup.e)\s+(\d+)\s+/) {
        my $args = $';
        $section = $1;
        push @returnvalues, "CONFIGURE ACCOUNTING $args";
    }
    elsif ($grep_result =~ /(circ_srv_prf.e)\s+(\d+)\s+(\w+)\s+/) {
        my $gsx_index = $2;
        my $args = $';
        $section = $1;
        push @returnvalues, "CONFIGURE CIRCUIT SERVICE PROFILE circ_serv_prof$gsx_index STATE DISABLED";
        push @returnvalues, "CONFIGURE CIRCUIT SERVICE PROFILE circ_serv_prof$gsx_index $args";
        push @returnvalues, "CONFIGURE CIRCUIT SERVICE PROFILE circ_serv_prof$gsx_index STATE ENABLED";
    }
    elsif ($grep_result =~ /(crkbck.e)\s+(\d+)\s+(\w+)\s+(\w+)\s+/) {
        my $args = $'; 
        my $cmd = $4;
        my $profile = $3;
        $section = $1;
        if ($cmd =~ /CREATE|DELETE/i) {
            push @returnvalues, "$cmd CRANKBACK PROFILE $profile";
        }
        else {
            push @returnvalues, "CONFIGURE CRANKBACK PROFILE $profile $args";
        }
    }
    elsif ($grep_result =~ /(dbg_cmd.e)\s+(\d+)\s+/) {
        my $args = $';
        $section = $1;
        push @returnvalues, "$args";
    }
    elsif ($grep_result =~ /(discSigSeq.e)\s+(\d+)\s+(\w+)\s+(\d+)\s+/) {
        my $args = $';
        my $ssp_name = $3;
        my $ssp_index = $4;
        $section = $1;
        if ($args =~ /CREATE|DELETE/i) {
            push @returnvalues, "$args DISCONNECT SIGNALSEQ SSP $ssp_name INDEX $ssp_index";
        }
        elsif ($args =~ /ENABLE|DISABLE/i) {
            push @returnvalues, "CONFIGURE DISCONNECT SIGNALSEQ SSP $ssp_name INDEX $ssp_index STATE $args";
        }
        else {
            push @returnvalues, "CONFIGURE DISCONNECT SIGNALSEQ SSP $ssp_name INDEX $ssp_index $args";
        }
    }
    elsif ($grep_result =~ /(discSsp.e)\s+(\d+)\s+(\w+)\s+(\w+)/) {
        my $dt_cmd = $4;
        my $dt_name = $3;
        $section = $1;
        push @returnvalues, "$dt_cmd DISCONNECT SSP $dt_name";
    }
    elsif ($grep_result =~ /(discTrt.e)\s+(\d+)\s+(\w+)\s+(\d+)\s*(\w*)/) {
        my $gsx_index = $2;
        my $dt_cmd = $3;
        my $dt_cause = $4;
        my $profile = "";
        $profile = $5 if defined($5);
        $section = $1;

        if ($gsx_index =~ /1|4/) {
            $gsx_index = 1;
        }
        if ($gsx_index =~ /2|3/) {
            $gsx_index = 2;
        }
            
        if ($dt_cmd =~ /DEL/i) {
            push @returnvalues, "CONFIGURE DISCONNECT TREATMENT PROFILE disc_treat_prof$gsx_index DELETE REASON $dt_cause";
        }
        else {
            push @returnvalues, "CONFIGURE DISCONNECT TREATMENT PROFILE disc_treat_prof$gsx_index $dt_cmd REASON $dt_cause DISCONNECT SSP $profile";
        }
    }
    elsif ($grep_result =~ /(isdn_disable.e)\s+(\d+)\s+(\S+)\s*/) {
        my $gsxIndex = $2;
        my $portType = $3;
        my $chanRange;
        $section = $1;

        if ( $portType =~ /E1/i )
        {
            $chanRange = "1-15,17-31";
        }
        else
        {
            $chanRange = "1-23";
        }
         
        push @returnvalues, "CONFIGURE ISDN BCHANNEL SERVICE is$gsxIndex INTERFACE 0 BCHANNEL $chanRange MODE OUTOFSERVICE";
        push @returnvalues, "CONFIGURE ISDN BCHANNEL SERVICE is$gsxIndex INTERFACE 0 BCHANNEL $chanRange STATE DISABLED";
        push @returnvalues, "CONFIGURE ISDN SERVICE is$gsxIndex PRIMARY DCHANNEL MODE OUTOFSERVICE";
        push @returnvalues, "CONFIGURE ISDN INTERFACE SERVICE is$gsxIndex INTERFACE 0 STATE DISABLED";
        push @returnvalues, "CONFIGURE ISDN SERVICE is$gsxIndex STATE DISABLED";
    }
    elsif ($grep_result =~ /(isdn_enable.e)\s+(\d+)\s+(\S+)\s*/) {
        my $gsxIndex = $2;
        my $portType = $3;
        my $chanRange;
        $section = $1;

        if ( $portType =~ /E1/i )
        {
            $chanRange = "1-15,17-31";
        }
        else
        {
            $chanRange = "1-23";
        }
        
        push @returnvalues, "CONFIGURE ISDN SERVICE is$gsxIndex STATE ENABLED";
        push @returnvalues, "CONFIGURE ISDN INTERFACE SERVICE is$gsxIndex INTERFACE 0 STATE ENABLED";
        push @returnvalues, "CONFIGURE ISDN SERVICE is$gsxIndex PRIMARY DCHANNEL MODE INSERVICE";
        push @returnvalues, "CONFIGURE ISDN BCHANNEL SERVICE is$gsxIndex INTERFACE 0 BCHANNEL $chanRange STATE ENABLED";
        push @returnvalues, "CONFIGURE ISDN BCHANNEL SERVICE is$gsxIndex INTERFACE 0 BCHANNEL $chanRange MODE INSERVICE";
    }
    elsif ($grep_result =~ /(isup_inrinf\.e)\s+(\d+)\s+(\S+)\s+/) {
        my $args     = trim($');
        my $gsxIndex = $2;
        my $protocol = $3;
        $section = $1;
        push @returnvalues, "CONFIGURE ISUP INR INF PROFILE sigprof$gsxIndex STATE DISABLED";
        push @returnvalues, "CONFIGURE ISUP INR INF PROFILE sigprof$gsxIndex $args";
        push @returnvalues, "CONFIGURE ISUP INR INF PROFILE sigprof$gsxIndex STATE ENABLED";
    }
    elsif ($grep_result =~ /(isup_rev\.e)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
        my $gsxIndex = $2;
        my $protocol = $3;
        my $isup_rev = $4;
        my $isup_base = trim ($5);
        my $inrProfile = "DISABLED";
        $section = $1;

        if ( $isup_base =~ /mexico_ic/i )
        {
            $inrProfile = "sigprof$gsxIndex";
        }

        push @returnvalues, "CONFIGURE ISUP SIGNALING PROFILE sigprof$gsxIndex STATE DISABLED";
        push @returnvalues, "CONFIGURE ISUP SIGNALING PROFILE sigprof$gsxIndex BASEPROFILE  Default_$isup_base";
        push @returnvalues, "CONFIGURE ISUP SIGNALING PROFILE sigprof$gsxIndex STATE ENABLED";
        push @returnvalues, "CONFIGURE ISUP SERVICE SS7$gsxIndex REVISION $isup_rev";
        push @returnvalues, "CONFIGURE ISUP SERVICE SS7$gsxIndex SIGNALING PROFILE sigprof$gsxIndex";
        push @returnvalues, "CONFIGURE ISUP SERVICE SS7$gsxIndex INR INF PROFILE $inrProfile";
    }
    elsif ($grep_result =~ /(isupsgdbg\.e)\s+(\d+)\s+/) {
        my $args = trim ($');

        $section = $1;
        push @returnvalues, "isupsgdebug $args";
    }
    elsif ($grep_result =~ /(isup_sigprf\.e)\s+(\d+)\s+(\S+)\s*/) {
        my $args = trim ($');
        my $gsxIndex = $2;
        $section = $1; 
        my $firstArg = (split (/ /, $args))[0];
        my $finalArgs = $args;

        if ( $firstArg =~ /specialdigits/i )
        {
            $finalArgs = "SPECIALDIGITS ";
            foreach my $arg ( split (/ /, $args) )
            {
                if ($arg =~ /special/i){
                    next;
                }

                $finalArgs = $finalArgs . "DIGIT$arg ";
            }
        }

        push @returnvalues, "CONFIGURE ISUP SIGNALING PROFILE sigprof$gsxIndex $finalArgs";
    }
    elsif ($grep_result =~ /(jap_disable\.e)\s+(\d+)\s*/) {
        my $gsxIndex = $2;
        my $cicRange;

        $section = $1;
        switch($gsxIndex)
        {
            case /1/i   { $cicRange = "1-24"; }
            case /2/i   { $cicRange = "101-124"; }
            case /3/i   { $cicRange = "201-224"; }
            case /4/i   { $cicRange = "301-324"; }
        }

        push @returnvalues, "CONFIGURE ISUP CIRCUIT SERVICE SS7$gsxIndex $cicRange MODE BLOCK";
        push @returnvalues, "CONFIGURE ISUP CIRCUIT SERVICE SS7$gsxIndex $cicRange STATE DISABLED";
        push @returnvalues, "CONFIGURE ISUP SERVICE SS7$gsxIndex MODE OUTOFSERVICE";
        push @returnvalues, "CONFIGURE ISUP SERVICE SS7$gsxIndex STATE DISABLED";
        push @returnvalues, "CONFIGURE ISUP SIGNALING PROFILE sigprof$gsxIndex STATE DISABLED";
    }
    elsif ($grep_result =~ /(jap_enable\.e)\s+(\d+)\s*/) {
        my $gsxIndex = $2;
        my $cicRange;
        $section = $1;

        switch($gsxIndex)
        {
            case /1/i   { $cicRange = "1-24"; }
            case /2/i   { $cicRange = "101-124"; }
            case /3/i   { $cicRange = "201-224"; }
            case /4/i   { $cicRange = "301-324"; }
        }

        push @returnvalues, "CONFIGURE ISUP SIGNALING PROFILE sigprof$gsxIndex STATE ENABLED";
        push @returnvalues, "CONFIGURE ISUP SERVICE SS7$gsxIndex STATE ENABLED";
        push @returnvalues, "CONFIGURE ISUP SERVICE SS7$gsxIndex MODE INSERVICE";
        push @returnvalues, "CONFIGURE ISUP CIRCUIT SERVICE SS7$gsxIndex $cicRange STATE ENABLED";
        push @returnvalues, "CONFIGURE ISUP CIRCUIT SERVICE SS7$gsxIndex $cicRange MODE UNBLOCK";
    }
    elsif ($grep_result =~ /(ss7_circ_disable\.e)\s+(\d+)\s+(\S+)\s*/) {
        my $gsxIndex = $2;
        my $protocol = $3;
        my $ss7ProtType = "";
        my $cicRange = "";
        $section = $1;

        my $data = processGsxData($protocol, $gsxIndex);
        if ( $data eq "")
        {
            $logger->error(__PACKAGE__ . ".$sub_name error in processGsxData()");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function from ss7_circ_disable.e section. retcode-0");
            return 0;
        }

        $ss7ProtType = trim ( (split(/,/, $data))[0] );
        $cicRange    = trim ( (split(/,/, $data))[1] );

        push @returnvalues, "CONFIGURE $ss7ProtType CIRCUIT SERVICE SS7$gsxIndex CIC $cicRange MODE BLOCK";
        push @returnvalues, "CONFIGURE $ss7ProtType CIRCUIT SERVICE SS7$gsxIndex CIC $cicRange STATE DISABLED";
    }
    elsif ($grep_result =~ /(\/ss7_circ\.e)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*/) {

        my $gsxIndex = $2;
        my $protocol = $3;
        my $args = trim ($');
        $section = $1;
        my $ss7ProtType = "";
        my $cicRange = "";

        my $data = processGsxData($protocol, $gsxIndex);
        if ( $data eq "")
        {
            $logger->error(__PACKAGE__ . ".$sub_name ss7_circ error in processGsxData()");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function from ss7_circ.e section. retcode-0");
            return 0;
        }

        $ss7ProtType = trim ( (split(/,/, $data))[0] );
        $cicRange    = trim ( (split(/,/, $data))[1] );

        push @returnvalues, "CONFIGURE $ss7ProtType CIRCUIT SERVICE SS7$gsxIndex CIC $cicRange $args";
    }
    elsif ($grep_result =~ /(\/ss7_circ_enable\.e)\s+(\d+)\s+(\S+)\s*/) {

        my $gsxIndex = $2;
        my $protocol = $3;
        my $ss7ProtType = "";
        my $cicRange = "";
        $section = $1;
        my $data = processGsxData($protocol, $gsxIndex);
        if ( $data eq "")
        {
            $logger->error(__PACKAGE__ . ".$sub_name ss7_circ_enable error in processGsxData()");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function from ss7_circ_enable.e section. retcode-0");
            return 0;
        }

        $ss7ProtType = trim ( (split(/,/, $data))[0] );
        $cicRange    = trim ( (split(/,/, $data))[1] );

        push @returnvalues, "CONFIGURE $ss7ProtType CIRCUIT SERVICE SS7$gsxIndex CIC $cicRange STATE ENABLED";
        push @returnvalues, "CONFIGURE $ss7ProtType CIRCUIT SERVICE SS7$gsxIndex CIC $cicRange MODE UNBLOCK";
    }
    elsif ($grep_result =~ /(\/ss7_disable\.e)\s+(\d+)\s+(\S+)\s*/) {

        my $gsxIndex = $2;
        my $protocol = $3;
        my $ss7ProtType = "";
        my $cicRange = "";
        $section = $1;
        my $data = processGsxData($protocol, $gsxIndex);
        if ( $data eq "")
        {
            $logger->error(__PACKAGE__ . ".$sub_name ss7_disable error in processGsxData()");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function from ss7_disable.e section. retcode-0");
            return 0;
        }

        $ss7ProtType = trim ( (split(/,/, $data))[0] );
        $cicRange    = trim ( (split(/,/, $data))[1] );
        push @returnvalues, "CONFIGURE $ss7ProtType CIRCUIT SERVICE SS7$gsxIndex CIC $cicRange MODE BLOCK";
        push @returnvalues, "CONFIGURE $ss7ProtType CIRCUIT SERVICE SS7$gsxIndex CIC $cicRange STATE DISABLED";
        push @returnvalues, "CONFIGURE $ss7ProtType SERVICE SS7$gsxIndex MODE OUTOFSERVICE";
        push @returnvalues, "CONFIGURE $ss7ProtType SERVICE SS7$gsxIndex STATE DISABLED";

        if ( $ss7ProtType =~ /ISUP/i )
        {
            push @returnvalues, "CONFIGURE ISUP SIGNALING PROFILE sigprof$gsxIndex STATE DISABLED";
        }

    }
    elsif ($grep_result =~ /(\/ss7_enable\.e)\s+(\d+)\s+(\S+)\s*/) {

        my $gsxIndex = $2;
        my $protocol = $3;
        my $ss7ProtType = "";
        my $cicRange = "";
        $section = $1;
        my $data = processGsxData($protocol, $gsxIndex);
        if ( $data eq "")
        {
            $logger->error(__PACKAGE__ . ".$sub_name ss7_enable error in processGsxData()");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function from ss7_enable.e section. retcode-0");
            return 0;
        }

        $ss7ProtType = trim ( (split(/,/, $data))[0] );
        $cicRange    = trim ( (split(/,/, $data))[1] );

        if ( $ss7ProtType =~ /ISUP/i )
        {
            push @returnvalues, "CONFIGURE ISUP SIGNALING PROFILE sigprof$gsxIndex STATE ENABLED";
        }

        push @returnvalues, "CONFIGURE $ss7ProtType SERVICE SS7$gsxIndex STATE ENABLE";
        push @returnvalues, "CONFIGURE $ss7ProtType SERVICE SS7$gsxIndex MODE INSERVICE";
        push @returnvalues, "CONFIGURE $ss7ProtType CIRCUIT SERVICE SS7$gsxIndex CIC $cicRange STATE ENABLED";
        push @returnvalues, "CONFIGURE $ss7ProtType CIRCUIT SERVICE SS7$gsxIndex CIC $cicRange MODE UNBLOCK";

    }
    elsif ($grep_result =~ /(\/ss7node_disable\.e)\s+(\d+)\s+(\S+)\s*/) {

        $section = $1;
        $protocol = $3;

        $prot_str = getProtocolFromProtId(-prot_id => "$protocol");
        if ( $prot_str eq "")
        {
            $logger->error(__PACKAGE__ . ".$sub_name ss7node_disable error in getProtocolFromProtId()");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function from ss7node_disable.e section. retcode-0");
            return 0;
        }

        push @returnvalues, "CONFIGURE SS7 NODE #+#ING_SS7_NODE_${prot_str}#+# MODE OUTOFSERVICE";
        push @returnvalues, "CONFIGURE SS7 NODE #+#ING_SS7_NODE_${prot_str}#+# STATE DISABLED";
    }
    elsif ($grep_result =~ /(\/ss7nodeTimerDefaults\.e)\s+(\d+)\s+(\S+)\s*/) {

        my $protocol = $3;
        my $prot_str;
        my %TimerHash = ();
        if ($protocol =~ m/^[aA]$/i) {
            $prot_str = "ANSI";
            $TimerHash{"T5"} = 60;
            $TimerHash{"T6"} = 22;
            $TimerHash{"T7"} = 25;
            $TimerHash{"T8"} = 13;
            $TimerHash{"T11"} = 17;
            $TimerHash{"T12"} = 10;
            $TimerHash{"T13"} = 60;
            $TimerHash{"T14"} = 10;
            $TimerHash{"T15"} = 60;
            $TimerHash{"T16"} = 10;
            $TimerHash{"T17"} = 60;
            $TimerHash{"T18"} = 10;
            $TimerHash{"T19"} = 60;
            $TimerHash{"T20"} = 10;
            $TimerHash{"T21"} = 60;
            $TimerHash{"T22"} = 10;
            $TimerHash{"T23"} = 60;
            $TimerHash{"T24"} = 1;
            $TimerHash{"T25"} = 5;
            $TimerHash{"T26"} = 120;
            $TimerHash{"T27"} = 240;
            $TimerHash{"T28"} = 10;
            $TimerHash{"T33"} = 14;
            $TimerHash{"TA"} = 0;
            $TimerHash{"TAcc"} = 5;
            $TimerHash{"TCcr"} = 2;
            $TimerHash{"TCcrr"} = 20;
            $TimerHash{"TCGB"} = 5;
            $TimerHash{"TCotd"} = 250;
            $TimerHash{"TCotl"} = 250;
            $TimerHash{"TCra"} = 20;
            $TimerHash{"TCvt"} = 10;
            $TimerHash{"TExm"} = 600;
            $TimerHash{"TGrs"} = 5;
            $TimerHash{"TSus"} = 15;
        }     
        elsif ($protocol =~ m/^[bB]$/i) {
            $prot_str = "BT";
            $TimerHash{"T1a"} = 60;
            $TimerHash{"T1b"} = 120;
            $TimerHash{"T1c"} = 5;
            $TimerHash{"T1d"} = 86400;
            $TimerHash{"T2"} = 120;
            $TimerHash{"T3"} = 120;
            $TimerHash{"T4"} = 120;
            $TimerHash{"T5"} = 120;
            $TimerHash{"T6"} = 4;
            $TimerHash{"T8"} = 30;
            $TimerHash{"T8a"} = 600;
            $TimerHash{"T9"} = 30;
            $TimerHash{"T10"} = 25;
            $TimerHash{"T12"} = 25;
            $TimerHash{"T12a"} = 600;
            $TimerHash{"T14"} = 5;
            $TimerHash{"T16"} = 180;
            $TimerHash{"T17"} = 20;
            $TimerHash{"T18"} = 60;
            $TimerHash{"T21"} = 180;
        }
        elsif ($protocol =~ m/^[cC]$/i) {
            $prot_str = "CHINA";
            $TimerHash{"T2"} = 180;
            $TimerHash{"T3"} = 120;
            $TimerHash{"T4"} = 300;
            $TimerHash{"T5"} = 300;
            $TimerHash{"T6"} = 10;
            $TimerHash{"T6Trans"} = 1200;
            $TimerHash{"T6Term"} = 140;
            $TimerHash{"T7"} = 25;
            $TimerHash{"T8"} = 13;
            $TimerHash{"T9"} = 220;
            $TimerHash{"T9Orig"} = 600;
            $TimerHash{"T9Trans"} = 600;
            $TimerHash{"T9Int"} = 200;
            $TimerHash{"T10"} = 5;
            $TimerHash{"T11"} = 17;
            $TimerHash{"T12"} = 15;
            $TimerHash{"T13"} = 300;
            $TimerHash{"T14"} = 15;
            $TimerHash{"T15"} = 300;
            $TimerHash{"T16"} = 15;
            $TimerHash{"T17"} = 300;
            $TimerHash{"T18"} = 15;
            $TimerHash{"T19"} = 300;
            $TimerHash{"T20"} = 15;
            $TimerHash{"T21"} = 300;
            $TimerHash{"T22"} = 15;
            $TimerHash{"T23"} = 300;
            $TimerHash{"T24"} = 1;
            $TimerHash{"T25"} = 5;
            $TimerHash{"T26"} = 120;
            $TimerHash{"T27"} = 240;
            $TimerHash{"T28"} = 10;
            $TimerHash{"T29"} = 450;
            $TimerHash{"T30"} = 8;
            $TimerHash{"T31"} = 420;
            $TimerHash{"T32"} = 4;
            $TimerHash{"T33"} = 14;
            $TimerHash{"T34"} = 3;
            $TimerHash{"T35"} = 18;
            $TimerHash{"T36"} = 12;
            $TimerHash{"T37"} = 3;
            $TimerHash{"T38"} = 30;
            $TimerHash{"T39"} = 9;
        }
        elsif ($protocol =~ m/^[iI]$/i) {
            $prot_str = "ITU";
            $TimerHash{"T2"} = 180;
            $TimerHash{"T3"} = 120;
            $TimerHash{"T4"} = 600;
            $TimerHash{"T5"} = 600;
            $TimerHash{"T6"} = 22;
            $TimerHash{"T6Trans"} = 1200;
            $TimerHash{"T6Term"} = 140;
            $TimerHash{"T7"} = 25;
            $TimerHash{"T8"} = 13;
            $TimerHash{"T9"} = 220;
            $TimerHash{"T9Orig"} = 600;
            $TimerHash{"T9Trans"} = 600;
            $TimerHash{"T9Int"} = 200;
            $TimerHash{"T10"} = 5;
            $TimerHash{"T11"} = 17;
            $TimerHash{"T12"} = 38;
            $TimerHash{"T13"} = 800;
            $TimerHash{"T14"} = 38;
            $TimerHash{"T15"} = 600;
            $TimerHash{"T16"} = 38;
            $TimerHash{"T17"} = 600;
            $TimerHash{"T18"} = 38;
            $TimerHash{"T19"} = 600;
            $TimerHash{"T20"} = 38;
            $TimerHash{"T21"} = 600;
            $TimerHash{"T22"} = 38;
            $TimerHash{"T23"} = 600;
            $TimerHash{"T24"} = 1;
            $TimerHash{"T25"} = 5;
            $TimerHash{"T26"} = 120;
            $TimerHash{"T27"} = 240;
            $TimerHash{"T28"} = 10;
            $TimerHash{"T29"} = 450;
            $TimerHash{"T30"} = 8;
            $TimerHash{"T31"} = 420;
            $TimerHash{"T32"} = 4;
            $TimerHash{"T33"} = 14;
            $TimerHash{"T34"} = 3;
            $TimerHash{"T35"} = 18;
            $TimerHash{"T36"} = 12;
            $TimerHash{"T37"} = 3;
            $TimerHash{"T38"} = 30;
            $TimerHash{"T39"} = 9;
        }
        elsif ($protocol =~ m/^[jJ]$/i) {
            $prot_str = "JAPAN";
            $TimerHash{"T2"} = 180;
            $TimerHash{"T5"} = 60;
            $TimerHash{"T6"} = 3;
            $TimerHash{"T7"} = 25;
            $TimerHash{"T11"} = 17;
            $TimerHash{"T12"} = 10;
            $TimerHash{"T13"} = 60;
            $TimerHash{"T14"} = 10;
            $TimerHash{"T15"} = 60;
            $TimerHash{"T16"} = 10;
            $TimerHash{"T17"} = 60;
            $TimerHash{"T22"} = 10;
            $TimerHash{"T23"} = 60;
            $TimerHash{"T28"} = 10;
            $TimerHash{"T34"} = 3;
            $TimerHash{"TECSR"} = 30;
        }
        else {
            $logger->error(__PACKAGE__ . ".$sub_name Protocol'$protocol' not recognised for ss7nodeDefaults script");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
            return 0;
        }
        while ( my ($timerName, $timerValue) = each(%TimerHash)) {
          push @returnvalues, "CONFIGURE SS7 NODE #+#ING_SS7_NODE_${prot_str}#+# TIMER $timerName $timerValue";
        }
    }
    elsif ($grep_result =~ /(\/ss7node_enable\.e)\s+(\d+)\s+(\S+)\s*/) {
        $section = $1;
        my $protocol = $3;

        my $prot_str = getProtocolFromProtId(-prot_id => "$protocol");
        if ( $prot_str eq "")
        {
            $logger->error(__PACKAGE__ . ".$sub_name ss7node_enable error in getProtocolFromProtId()");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function from ss7node_enable.e section. retcode-0");
            return 0;
        }

        push @returnvalues, "CONFIGURE SS7 NODE #+#ING_SS7_NODE_${prot_str}#+# STATE ENABLED";
        push @returnvalues, "CONFIGURE SS7 NODE #+#ING_SS7_NODE_${prot_str}#+# MODE INSERVICE";
    }
    elsif ($grep_result =~ /(\/ss7node\.e)\s+(\d+)\s+(\S+)\s*/) {

        my $gsxIndex = $2;
        my $protocol = $3;
        my $args = trim ($');
        $section = $1;

        my $prot_str = getProtocolFromProtId(-prot_id => "$protocol");
        if ( $prot_str eq "")
        {
            $logger->error(__PACKAGE__ . ".$sub_name ss7node error in getProtocolFromProtId()");
            $logger->debug(__PACKAGE__ . ".$sub_name Leaving function from ss7node.e section. retcode-0");
            return 0;
        }


        push @returnvalues, "CONFIGURE SS7 NODE #+#ING_SS7_NODE_${prot_str}#+# $args";
    }
    elsif ($grep_result =~ /(\/ss7_serv\.e)\s+(\d+)\s+(\S+)\s*/) {

        my $gsxIndex = $2;
        my $protocol = $3;
        my $ss7Sig = "ISUP";
        my $args = trim ($');
        $section = $1;
        if ( $protocol =~ /b/i )
        {
            $ss7Sig = "BT"; 
        }

        push @returnvalues, "CONFIGURE $ss7Sig SERVICE SS7$gsxIndex $args";
    }
    elsif ($grep_result =~ /(\/ss7_serv_inr\.e)\s+(\d+)\s+(\S+)\s*(\w*)/) {

        my $gsxIndex = $2;
        my $protocol = $3;
        my $prof_state = "";
        $prof_state = $4 if defined($4);
        my $args = trim ($');
        $section = $1;
        my $prefix = "";
        if ($protocol =~ m/^u(k*)/i) 
        {
            $prefix = "UKISUP_";
        } 
        elsif ($protocol =~  m/^a(n*)/i) 
        {
            $prefix = "ANSI_";
        } 
        elsif ($protocol =~  m/^c(h*)/i) 
        {
            $prefix = "CHINA_";
        } 
        elsif ($protocol =~  m/^j([ap]*)/i) 
        {
            $prefix = "JAPAN_";
        }
        push @returnvalues, "CONFIGURE ISUP SERVICE SS7$gsxIndex INR INF PROFILE ${prefix}INRPROF${gsxIndex} $prof_state";
    }
    elsif ($grep_result =~ /(\/tg_disable\.e)\s+(\d+)\s*/) {

        my $args     = trim($');
        $section = $1;
        push @returnvalues, "CONFIGURE TRUNK GROUP TG#+#ING_GSX_NAME#+#$args MODE OUTOFSERVICE";
        push @returnvalues, "CONFIGURE TRUNK GROUP TG#+#ING_GSX_NAME#+#$args STATE DISABLED";
    }
    elsif ($grep_result =~ /(\/tg\.e)\s+(\d+)\s+(\S+)\s*/) {

        my $tgSuffix = $3;
        my $args     = trim($');
        $section = $1;
        push @returnvalues, "CONFIGURE TRUNK GROUP TG#+#ING_GSX_NAME#+#$tgSuffix $args";
    }
    elsif ($grep_result =~ /(\/tg_enable\.e)\s+(\d+)\s+(\S+)\s*/) {

        my $tgSuffix = $3;
        $section = $1;
        push @returnvalues, "CONFIGURE TRUNK GROUP TG#+#ING_GSX_NAME#+#$tgSuffix STATE ENABLED";
        push @returnvalues, "CONFIGURE TRUNK GROUP TG#+#ING_GSX_NAME#+#$tgSuffix MODE INSERVICE";
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub_name Unix Exec Script not recognised '$grep_result'");
        $logger->debug(__PACKAGE__ . ".$sub_name Leaving function");
        return 0;

    } 
 
    $logger->debug(__PACKAGE__ . ".$sub_name Return Values - @returnvalues");
    $logger->debug(__PACKAGE__ . ".$sub_name Leaving function from section '$section'.");
    return @returnvalues;

} # End sub convertMgtsGsxControl

=head1 B<processGsxData()>

  This subroutine is used to process the GSX Data.

=over 6

=item ARGUMENTS:

 $protocol
 $gsxIndex

=item PACKAGE:

 SonusQA::GSX::ART

=item RETURN:

 $ss7ProtType,
 $cicRange

=back

=cut

sub processGsxData
{
    my $sub_name = "processgsxData()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
    $logger->debug(__PACKAGE__ . ".$sub_name entered with args: " . Dumper(@_));
    my $protocol = shift;
    my $gsxIndex = shift;

    my $ss7ProtType = 'ISUP';
    my $cicRange = "";

        if ( $protocol =~ /B/i )
        {
            $ss7ProtType = 'BT';
            switch($gsxIndex)
            {
                case /1/i   { $cicRange = "50-53"; }
                case /2/i   { $cicRange = "64-67"; }
                case /3/i   { $cicRange = "68-71"; }
                case /4/i   { $cicRange = "72-75"; }
                else        { $logger->error(__PACKAGE__ . ".$sub_name ss7_circ_disable - invalid gsxId-$gsxIndex for protocol-$protocol."); return "";}
            }
        }
        elsif ( $protocol =~ /J/i )
        {
            switch($gsxIndex)
            {
                case /1/i   { $cicRange = "1-24"; }
                case /2/i   { $cicRange = "101-124"; }
                case /3/i   { $cicRange = "201-224"; }
                case /4/i   { $cicRange = "301-324"; }
                else        { $logger->error(__PACKAGE__ . ".$sub_name ss7_circ_disable - invalid gsxId-$gsxIndex for protocol-$protocol."); return "";}
            }
        }
        elsif ( $protocol =~ /A/i )
        {
            switch($gsxIndex)
            {
                case /1/i   { $cicRange = "2-10"; }
                case /2/i   { $cicRange = "11-20"; }
                case /3/i   { $cicRange = "21-22"; }
                case /4/i   { $cicRange = "41-50"; }
                case /5/i   { $cicRange = "31-40"; }
                else        { $logger->error(__PACKAGE__ . ".$sub_name ss7_circ_disable - invalid gsxId-$gsxIndex for protocol-$protocol."); return "";}
            }
        }
        else 
        {
            switch($gsxIndex)
            {
                case /1/i   { $cicRange = "2-10"; }
                case /2/i   { $cicRange = "11-20"; }
                case /3/i   { $cicRange = "21-30"; }
                case /4/i   { $cicRange = "31-40"; }
                else        { $logger->error(__PACKAGE__ . ".$sub_name ss7_circ_disable - invalid gsxId-$gsxIndex for protocol-$protocol."); return "";}
            }
        }

    $logger->debug(__PACKAGE__ . ".$sub_name returning $ss7ProtType,$cicRange.");
    return "$ss7ProtType,$cicRange";
}


sub compareArrays
{
  my $sub = "compareArrays()";
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
  $logger->debug("Entered $sub.");

  my ($fa, $sa) = @_;
  if ( @$fa != @$sa )
  {
      $logger->error(__PACKAGE__ . ".$sub arrays have unequal lengths.");
      $logger->debug("Leaving $sub retCode-0.");
      return 0;
  }

  my $counter;
  for ($counter=0; $counter<@$fa; $counter++)
  {
      if ( $fa->[$counter] ne $sa->[$counter] )
      {
          $logger->error(__PACKAGE__ . ".$sub array element mismatch." . 
          " firstArray-$fa->[$counter] / secondArray-$sa->[$counter].");
          $logger->debug("Leaving $sub retCode-0.");
          return 0;
      }
  }
  $logger->debug("Leaving $sub retCode-1.");
  return 1;
}

sub compareArrayOfArrays
{
    my $sub = "compareArrayOfArrays()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($faa, $saa) = @_;
    $logger->debug("Entered $sub.");

    if ( @$faa != @$saa )
    {
        $logger->error(__PACKAGE__ . ".$sub array length mismatch.");
        $logger->debug("Leaving $sub retCode-0.");
        return 0;
    }
    else
    {
        my $i=0;
        for($i=0; $i<  @$faa; $i++)
        {
            if ( compareArrays( \@{$faa->[$i]}, \@{$saa->[$i]} ) == 0 )
            {
                $logger->error(__PACKAGE__ . ".$sub array mismatch");
                $logger->debug("Leaving $sub retCode-0.");
                return 0;
            }
        }
    } 
    $logger->debug("Leaving $sub retCode-1.");
    return 1;
}


#Function to remove leading/trailing spaces.
sub trim($)
{
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

=pod

=head1 B<compareTestCfg()>

  This function compares two test group configuration hashes to identify whether the configurations are different and if they differ enough to require a reboot.

=over 6

=item Arguments :

 1st arg - %testcfg_hash1
 2nd arg - %testcfg_hash2

=item Return Values :

 3 - config changed and requires reboot
 2 . config changed and NO reboot required
 1 . config unchanged 
 exit - otherwise

=item Example :

 $status = compareTestCfg(%testcfg, $testgrp_config_stack[n]);

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

sub compareTestCfg 
{

    my($firstHash, $secondHash) = @_;
    my $sub = "compareTestCfg()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug("Entered $sub.");

    unless( keys %$firstHash )
    {
        $logger->error(__PACKAGE__ . ".$sub first hash is empty.");
        $logger->debug("Leaving $sub");
        return 0;
    }
    unless( keys %$secondHash )
    {
        $logger->error(__PACKAGE__ . ".$sub secondHash hash is empty.");
        $logger->debug("Leaving $sub");
        return 0;
    }

    my %dummyHash = ( NUM_GSX => '',
                      SS7_SIG => '');

    foreach my $k (sort keys %dummyHash)
    {
        if ( $firstHash->{$k} ne $secondHash->{$k} )
        {
            $logger->error(__PACKAGE__ . ".$sub \"$k\" mismatch, " .
                " firstHash-$firstHash->{$k} / secondHash-$secondHash->{$k}.");
            $logger->debug("Leaving $sub retCode-3.");
            return 3;
        }
    }

    %dummyHash2 = ( MGTS_ASSIGN_PATH => '',
                    MGTS_SEQGRP_PATH => '' );

    foreach my $k (sort keys %dummyHash)
    {
        if ( $firstHash->{$k} ne $secondHash->{$k} )
        {
            $logger->error(__PACKAGE__ . ".$sub \"$k\" mismatch, " .
                " firstHash-$firstHash->{$k} / secondHash-$secondHash->{$k}.");
            $logger->debug("Leaving $sub retCode-2.");
            return 2;
        }
    }


    if ( compareArrays( \@{$firstHash->{GSX_TCL_SCRIPTS}}, \@{$secondHash->{GSX_TCL_SCRIPTS}} ) == 0 )
    {
        $logger->error(__PACKAGE__ . ".$sub GSX_TCL_SCRIPTS array mismatch.");
        $logger->debug("Leaving $sub retCode-3.");
        return 3;
    }
    if ( compareArrays( \@{$firstHash->{GBL_TEST_PATHS}}, \@{$secondHash->{GBL_TEST_PATHS}} ) == 0 )
    {
        $logger->error(__PACKAGE__ . ".$sub GBL_TEST_PATHS array mismatch.");
        $logger->debug("Leaving $sub retCode-2.");
        return 2;
    }
    if ( compareArrays( \@{$firstHash->{MGTS_ASSIGNMENTS}}, \@{$secondHash->{MGTS_ASSIGNMENTS}} ) == 0 )
    {
        $logger->error(__PACKAGE__ . ".$sub MGTS_ASSIGNMENTS array mismatch.");
        $logger->debug("Leaving $sub retCode-3.");
        return 3;
    }

    if ( compareArrayOfArrays( \@{$firstHash->{REQ_GBL}}, \@{$secondHash->{REQ_GBL}} ) == 0 )
    {
      $logger->error(__PACKAGE__ . ".$sub REQ_GBL element mismatch.");
      $logger->debug("Leaving $sub retCode-2.");
      return 2;
    }
    if ( compareArrayOfArrays( \@{$firstHash->{REQ_MGTS}}, \@{$secondHash->{REQ_MGTS}} ) == 0 )
    {
      $logger->error(__PACKAGE__ . ".$sub REQ_MGTS element mismatch.");
      $logger->debug("Leaving $sub retCode-3.");
      return 3;
    }
    if ( compareArrayOfArrays( \@{$firstHash->{MGTS_SEQGRPS}}, \@{$secondHash->{MGTS_SEQGRPS}} ) == 0 )
    {
      $logger->error(__PACKAGE__ . ".$sub MGTS_SEQGRPS element mismatch.");
      $logger->debug("Leaving $sub retCode-2.");
      return 2;
    }

    # Compare GSX_TCL_VARS
    foreach my $k (sort keys %{$firstHash->{GSX_TCL_VARS}})
    {
        foreach my $k2 (sort keys %{$firstHash->{GSX_TCL_VARS}->{$k}})
        {
            my $val1 = $firstHash->{GSX_TCL_VARS}->{$k}->{$k2};
            my $val2 = $secondHash->{GSX_TCL_VARS}->{$k}->{$k2};
            if ( $val1 ne $val2 )
            {
                $logger->error(__PACKAGE__ . ".$sub GSX_TCL_VARS-$k-$k2" .
                " value mismatch first-$val1 / second-$val2.");
                $logger->debug("Leaving $sub retCode-3.");
                return 3;
            }
        }
    }
    return 1;
}


=pod

=head1 B<restorePrevTestGrpConfig()>

  This function is called at the end of the test group configuration file and firstly disconnects the MGTS assignment and terminates the MGTS PASM 
  scripting session. It then reverts the test group configuration to the previous configuration and will set the GSX reboot flag if the 
 configuration has significantly changed after analysing the current configuration against what was left on the @testgrp_config_stack stack.

=over 6 

=item Arguments:

 None.

=item Return Values :

 None (Test group configuration reset.).

=item Example :

 restorePrevTestGrpConfig()

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

sub restorePrevTestGrpConfig
{
    my $sub = "restorePrevTestGrpConfig()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub Entered function.");
   
    my $error_found = 0; 

    unless (defined($testcfg->{EXECUTE_DEFAULT_PSX_CMDS}) && $testcfg->{EXECUTE_DEFAULT_PSX_CMDS} == 0) {	
        # Hash structure is : $testcfg->{DEFAULT_PSX_CMDS}->{$arrayindex}->{$command} = 1;
        if (exists($testcfg->{DEFAULT_PSX_CMDS})) {
            foreach my $index ( keys %{$testcfg->{DEFAULT_PSX_CMDS}})
            {
                for my $command ( keys %{$testcfg->{DEFAULT_PSX_CMDS}->{$index}})
                {
		    my $psx_ind = $index+1;		
                    my $option = "-psx" . $psx_ind;
                    if ( execPsxControl( $option => "$command", -default_psx_cmd => "$command" ) == 0 )
                    {
                        $logger->error(__PACKAGE__ . ".$sub execPsxControl returned error while trying to execute DEFAULT PSX control.");
                        $logger->debug(__PACKAGE__ . "Leaving $sub.");
                        $error_found++; 
                    }
                }
	        delete($testcfg->{DEFAULT_PSX_CMDS}->{$index}); 
            }
        } 
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Bypassing execution of default PSX commands due to \$testcfg->{EXECUTE_DEFAULT_PSX_CMDS} flag being set to '0'");
	$testcfg->{DEFAULT_PSX_CMDS} = ();
	$testcfg->{EXECUTE_DEFAULT_PSX_CMDS} = 1;		
    }


    if (exists($testcfg->{USED_MGTS_OBJ})) {
        foreach my $entity ( @{$testcfg->{USED_MGTS_OBJ}})
        {
            $entity->endSession();
        }
    }

    my $lastConfig = pop( @testgrp_config_stack );
    unless( keys %{$lastConfig} )
    {
        $logger->warn(__PACKAGE__ . ".$sub Test group configuration has not changed.");
    	$logger->debug(__PACKAGE__. ".$sub Leaving $sub with $error_found errors.");
        return;
    }

    $logger->debug(__PACKAGE__ . ".$sub Test Config \$testcfg BEFORE restore is:");
    print Dumper $testcfg;
    my $retCode = compareTestCfg(\%{$lastConfig}, \%testcfg);
    if ( $retCode == 3 )
    {
        %testcfg = %{$lastConfig};

        foreach my $gsxObj ( @{$artobj->{GSX}} )
        {
            $gsxObj->{RESET_NODE} = 1;
        }
    }
    elsif( $retCode == 2 )
    {
        %testcfg = %{$lastConfig};
    }
    $logger->debug(__PACKAGE__ . ".$sub Test Config \$testcfg AFTER restore is:");
    print Dumper $testcfg;
    $logger->debug(__PACKAGE__. ".$sub Leaving $sub with $error_found errors.");
}

=pod

=head1 B<checkMgtsAssignment()>

  This function substitute any patterns in the assignment name and then checks the specified MGTS assignment files to ensure there is one for each MGTS.

=over 6

=item Arguments:

 None.

=item Return Values:

 1 . if all MGTS configuration successful
 0 . otherwise (with $testcfg->{SKIP_GROUP} being set)

=item Example:

 checkMgtsAssignment()

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

sub checkMgtsAssignment
{
    my $sub = "checkMgtsAssignment()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $exit_code;
    
    $logger->debug("Entered $sub.");

    unless(defined($testcfg->{MGTS_ASSIGN_PATH}) && $testcfg->{MGTS_ASSIGN_PATH} !~ /^\s*$/)
    {
        unless (defined($mgts_repos{PATH}) || $mgts_repos{PATH} !~ /^\s*$/)
        {
            $logger->error(__PACKAGE__ . ".$sub MGTS_ASSIGN_PATH not set - and no default in regional config file");
            setSkipGrpData( "Test Group: $testcfg->{TEST_GRP}, Function: checkMgtsAssignment, Reason: Unable to find regional default value for MGTS assignment path"); 
            $logger->debug(__PACKAGE__ . ".$sub returning 0");
            return 0;
        } else {
            $logger->info(__PACKAGE__ . ".$sub MGTS_ASSIGN_PATH not set - defaulting from regional config file to '$mgts_repos{PATH}'");
            $testcfg->{MGTS_ASSIGN_PATH} = $mgts_repos{PATH};
        }
    }

    # Test mgts_assign_path
    if ( !defined $testcfg->{USED_MGTS_OBJ}[0] )
    {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:$sub, Reason: unable to get MGTS object.");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    }
    my $mgtsObj = $testcfg->{USED_MGTS_OBJ}[0];
    my $cmd = "test -d $testcfg->{MGTS_ASSIGN_PATH}";
    $exit_code = $mgtsObj->cmd( -cmd => $cmd,
                                -timeout => 5 );
    $logger->debug(__PACKAGE__ . ".$sub command - [$cmd], exit_code - [$exit_code].");

    if ( $exit_code != 0 )
    {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:$sub, Reason: MGTS assignment path [$testcfg->{MGTS_ASSIGN_PATH}] does not exist.");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    }

    unless ( defined($testcfg->{MGTS_ASSIGNMENTS} ))
    {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:$sub, Reason: MGTS assignment not defined.");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    }

    if ( @{$testcfg->{MGTS_ASSIGNMENTS}} > @{$testcfg->{REQ_MGTS}} )
    {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:$sub, Reason: More MGTS assignments defined than the number of MGTS required.");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    }

    for (my $counter=0; $counter < @{$testcfg->{REQ_MGTS}}; $counter++)
    {
        my $mgtsAssignment = trim ($testcfg->{MGTS_ASSIGNMENTS}[$counter] );
        unless ( defined $mgtsAssignment && $mgtsAssignment ne "" )
        {
            setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:$sub, Reason: MGTS assignment not defined at index-" . eval($counter+1));
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }
        if ( $mgtsAssignment !~ /\.AssignM5k$/ )
        {
            $mgtsAssignment = $mgtsAssignment . "\.AssignM5k";
            $testcfg->{MGTS_ASSIGNMENTS}[$counter] = $mgtsAssignment; 
        }

        # Get MGTS alias-name
        if ( $mgtsAssignment =~ /\#\+\#MGTS\#\+\#/ )
        {
            unless (defined $testcfg->{USED_MGTS_OBJ}[$counter]->{TMS_ALIAS_DATA}->{ALIAS_NAME} && $testcfg->{USED_MGTS_OBJ}[$counter]->{TMS_ALIAS_DATA}->{ALIAS_NAME} !~ /^\s*$/ )
            {
                setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:$sub, Reason: ALIAS NAME not found or is blank in TMS_ALIAS_DATA for MGTS object at index-" . eval($counter+1));
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }
            
            my $mgtsAliasName = $testcfg->{USED_MGTS_OBJ}[$counter]->{TMS_ALIAS_DATA}->{ALIAS_NAME};
            
            $mgtsAssignment =~ s/\#\+\#MGTS\#\+\#/$mgtsAliasName/g;
        }

        if ( $mgtsAssignment =~ /\#\+\#SS7_SIG\#\+\#/ )
        {
            unless (defined($testcfg->{SS7_SIG}) && $testcfg->{SS7_SIG} !~ /^\s*$/ ) 
            {
                setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:$sub, Reason: failed to substitute SS7_SIG in mgts-assignment-name - " .
                               "\"$testcfg->{MGTS_ASSIGNMENTS}[$counter]\" as \$testcfg->\{SS7_SIG\} is blank or undefined" );
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }
            my $ss7Sig = $testcfg->{SS7_SIG};
            $mgtsAssignment =~ s/\#\+\#SS7_SIG\#\+\#/$ss7Sig/g;
        }
        $testcfg->{MGTS_ASSIGNMENTS}[$counter] = $mgtsAssignment;

        # check mgtsAssignment
        my $mgtsObj = $testcfg->{USED_MGTS_OBJ}[$counter];
        $exit_code = $mgtsObj->cmd( -cmd => "test -s $testcfg->{MGTS_ASSIGN_PATH}/$mgtsAssignment",
                                    -timeout => 5 );
        $logger->debug(__PACKAGE__ . ".$sub command - [\"test -s $testcfg->{MGTS_ASSIGN_PATH}/$mgtsAssignment\"], exit_code - [$exit_code].");
        if ( $exit_code != 0 )
        {
                setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:$sub, Reason: $mgtsAssignment does not exist/is of 0 length.");
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
        }
        $exit_code = $mgtsObj->cmd( -cmd => "test -r $testcfg->{MGTS_ASSIGN_PATH}/$mgtsAssignment",
                                       -timeout => 5 );
        $logger->debug(__PACKAGE__ . ".$sub command - [\"test -r $testcfg->{MGTS_ASSIGN_PATH}/$mgtsAssignment\"], exit_code - [$exit_code].");
        if ( $exit_code != 0 )
        {
                setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function:$sub, Reason: $mgtsAssignment does not have read permissions.");
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-1.");
    return 1;
}



=pod

=head1 B<execTest()>

 This function executes each of the defined test scripts in order and logs progress and results. 

=over 6

=item Arguments :

 MANDATORY ARGUMENTS:

    -testid => .<TMS test id, .config_change. for control test or 
         .cleanup. while executing cleanup script>.     
        NOTE: tests with the -testid option set to .config_change. or .cleanup. 
              do not have the test result logged to TMS.

    -feature => .<TMS feature name>.
        NOTE: only required if test_id is not .config_change. or .cleanup.

    -requirement .<TMS requirement>.
        NOTE: only required if test_id is not .config_change. or .cleanup.

 REPEATABLE ARGUMENTS:

    The following are arguments which can be specified multiple times 
    where the order specified is the order they are executed.
    -mgts<n> => .<MGTS node name>:<MGTS state machine name>.
    -gbl<n> => .<name of GBL script file>.
    -gsx<n> => .<GSX CLI Command>.

 OPTIONAL ARGUMENTS:

    -skip_post_checks      => < 1 (skip check) or 0 (execute check).  Default is 0 (execute check)>        
    -skip_cic_check      => < 1 (skip cic checking) or 0 (execute cic check). Default is 0 to check cics>
    -post_check_function => <test or test group specific function reference>
    -timeout <test script timeout in seconds. Default is 60 seconds>

=item Return Values :

 1 . successful
 0 . otherwise

=item Example :

 execTest()

=item Author :

 Nimit Sarup
 nsarup@sonusnet.com

=back

=cut

sub execTest
{
    my (%args);
    tie %args, 'Tie::DxHash', [LIST];
    (%args) = @_;
    my $sub = "execTest()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug("Entered $sub with args =>". Dumper(%args));

    $testcfg->{TEST_POSITION}++;
    my ($testId, $feature, $requirement, $expectArgString, $skip_data_header, $postCheckFn);
    my $skipCicChecks=0, $skipPostChecks=0, $gsxSwitchOverFound=0;
    my $timeout = 60, $stopScriptFlag=0, $gblMgtsStarted=0;
    my @scriptHashArray;
    my $gblLogFileName;
    my $cicsNonIdleAfterTestFound = 0;
    my $cicsNonIdleAfterCleanupFound = 0;
    my $globalPostCheckErrorFound=0,$localPostCheckErrorFound=0, $gsxCoreDumpFound=0, $mgtsLogErrorFound=0;

    # START CHECKS OPTIONS
    $logger->debug(__PACKAGE__ . ".$sub Start CHECK OPTIONS.");
    $testId = $args{-testid}; 
    if ( (!defined $testId) ||
         ($testId eq "") )
    {
        setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: $sub, TestPos: $testcfg->{TEST_POSITION}," .
                       " Reason: No valid test_id specified.");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    }

    if ( $testId =~ /cleanup/i )
    {
        $testcfg->{TEST_POSITION}--;
    }

    if ( $testId !~ /cleanup|config/i )
    {
        unless (defined $args{-feature} && $args{-feature} !~ /^\s*$/ )
        {
            setSkipGrpData("Test Grp:$testcfg->{TEST_GRP}, Function: $sub, Test_ID: $testId, TestPos: $testcfg->{TEST_POSITION}," .
                           " Reason: No valid feature specified");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        } else {
            $feature = $args{-feature};
        }


        $skip_data_header = "Test Grp:$testcfg->{TEST_GRP}, Function: $sub, Test_ID: $testId," .
                            " Feature: $feature, TestPos: $testcfg->{TEST_POSITION}";


        unless (defined $args{-requirement} && $args{-requirement} !~ /^\s*$/ )
        {
            setSkipGrpData("${skip_data_header} , Reason: No valid requirement specified");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        } else {
            $requirement = $args{-requirement};
        }
    }
    else
    {
        $skip_data_header = "Test Grp:$testcfg->{TEST_GRP}, Function: execTest, Test_ID: $testId";
    }

    if ( defined($testcfg->{SKIP_GROUP}) && $testcfg->{SKIP_GROUP} == 1 )
    {
        setSkipGrpData("$skip_data_header, Reason: Due to previous error.");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0;
    }

    my $argIndex = 0;
    foreach my $key ( keys %args )
    {
        if ( $key =~ /^-gsx(\d+)$/i )
        {
            my $number  = $1;
            my $command = $args{$key};

            unless ( defined($artobj->{GSX}->[$number-1]) )
            {
                if (($number == 2) && defined($artobj->{GSX}->[0])) 
                {
                    # So $artobj->{GSX}->[1] does not exist -
                    # If only a single GSX object and -gsx2 used then set the
                    # number to 1 to reference object identified by -gsx1
                    # ($artobj->{GSX}[0]).
                    $number--;
                } else {
                    setSkipGrpData("${skip_data_header}, Reason: No GSX object exists for test id-$testId for $key - $command option"); 
                    $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                    return 0;
                }
            }

            my $tmp_command = populateGsxVarsInStr(-str => $command, -index => $number);

	    if ($tmp_command eq "") {
                setSkipGrpData("${skip_data_header}, Reason: Problem substituting patterns in '$command' GSX command"); 
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            } else {
                $logger->debug(__PACKAGE__ . ".$sub Substituted patterns in '$command' with '$tmp_command'");
                $command = $tmp_command; 
            }

            $scriptHashArray[$argIndex]->{TYPE} = "GSX";
            $scriptHashArray[$argIndex]->{OBJ} = $artobj->{GSX}[$number-1];
            $scriptHashArray[$argIndex]->{ACTION} = $command;
            $argIndex++; 
        }
        elsif ( $key =~ /^-mgts(\d+)$/i )
        {
            my $number  = $1;
            my ($mgtsNodeName,$mgtsStateMachine);
            if ($args{$key} =~ /^(.+):(.*ID:[0-9]+.*)$/)
            {
                $mgtsNodeName     = $1;
                $mgtsStateMachine = $2;
            } else 
            {
                $mgtsNodeName = "SSP";      
                if ($args{$key} =~ /^SSP:.+$/) 
                {
                    $mgtsStateMachine = "$args{$key}"; 
                    $mgtsStateMachine =~ s/^SSP://g;
                }
                else
                {
                    $mgtsStateMachine = "$args{$key}"; 
                }
            }

            if ( $mgtsNodeName eq "" || $mgtsStateMachine eq "")
            {
                $logger->error(__PACKAGE__ . ".$sub incorrect syntax for $key [nodeName:StateMachineName].");
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }

            unless ( defined($testcfg->{USED_MGTS_OBJ}->[$number-1])) 
            {
                setSkipGrpData("${skip_data_header}, Reason: No MGTS object exists for test id-$testId for $key - $args{$key} option"); 
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }
            else
            {
                $scriptHashArray[$argIndex]->{TYPE} = "MGTS";
                $scriptHashArray[$argIndex]->{OBJ} = $testcfg->{USED_MGTS_OBJ}[$number-1];
                $scriptHashArray[$argIndex]->{ACTION} = "$mgtsNodeName:$mgtsStateMachine";
                $argIndex++; 
            }
        }
        elsif ( $key =~ /^-gbl(\d+)$/i )
        {
            my $number  = $1;
            my $gblScriptName = $args{$key};

            if ( $gblScriptName eq "" )
            {
                $logger->error(__PACKAGE__ . ".$sub incorrect syntax for $key [no gblScriptName].");
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }

            if ( $testcfg->{USED_GBL_OBJ}[$number-1] == undef )
            {
                setSkipGrpData("${skip_data_header}, Reason: No GBL object exists for test id-$testId for $key - $args{$key} option"); 
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }
            else
            {
                $scriptHashArray[$argIndex]->{TYPE} = "GBL";
                $scriptHashArray[$argIndex]->{OBJ} = $testcfg->{USED_GBL_OBJ}->[$number-1];
                $scriptHashArray[$argIndex]->{ACTION} = eval($number-1) . ":$args{$key}";
                $argIndex++; 
            }
        }
        elsif ( $key =~ /testid|requirement|feature/i )
        {
            next;
        }
        elsif ( $key =~ /^-timeout$/i )
        {
            $timeout = $args{$key};

            if ( $timeout <= 0 )
            {
               setSkipGrpData("${skip_data_header}, Reason: -timeout option must have " .
                              "a timeout value greater than 0. Currently set to $timeout.");  
               $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
               return 0;
            }
        }
        elsif ( $key =~ /^-post_check_function$/i )
        {
            if (defined($args{$key})) {
                $postCheckFn = $args{$key};
            } else {
                $postCheckFn = "";
            }

            if ( $postCheckFn eq "" )
            {
                setSkipGrpData("${skip_data_header}, Reason: -post_check_function option specified but function reference is undefined"); 
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }
        }
        elsif ( $key =~ /^-skip_post_checks$/i )
        {
            $skipPostChecks = $args{$key};

            if( $skipPostChecks eq "" ||
                $skipPostChecks > 1  ||
                $skipPostChecks < 0)
            {
                setSkipGrpData("${skip_data_header}, Reason: -skip_post_checks option has a missing or invalid value $skipPostChecks.");
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }
        }
        elsif ( $key =~ /^-skip_cic_check$/i )
        {
            $skipCicChecks = $args{$key};

            if( $skipCicChecks eq "" ||
                $skipCicChecks > 1  ||
                $skipCicChecks < 0)
            {
                setSkipGrpData("${skip_data_header}, Reason: -skip_cic_check option has a missing or invalid value $skipCicChecks.");
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }
        }
        else
        {
            setSkipGrpData("${skip_data_header}, Reason: Invalid option $key specified."); 
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }
    } # foreach args

    # END CHECKS OPTIONS
    $logger->debug(__PACKAGE__ . ".$sub End of CHECK OPTIONS.");

    # START LOG START
    $logger->debug(__PACKAGE__ . ".$sub Start of LOG START.");
    
    foreach my $gsxObj ( @{$artobj->{GSX}} )
    {
        unless ( my @tmp_ary = $gsxObj->gsxLogStart(-test_case => $testId,
                                                    -host_name => $gsxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME},
                                                    -log_dir   => $artcfg->{USER_LOG_DIR}) )
        {
            $gsxObj->{GSX_LOG_INFO} = undef;

            setSkipGrpData("${skip_data_header}, Reason: Failed to start logging " .
                           "on GSX $gsxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}."); 
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        } else {
            if ($#tmp_ary >= 7) {
                $gsxObj->{GSX_LOG_INFO}->{PID}->{ACT} = $tmp_ary[0];
                $gsxObj->{GSX_LOG_INFO}->{PID}->{DBG} = $tmp_ary[1];
                $gsxObj->{GSX_LOG_INFO}->{PID}->{SYS} = $tmp_ary[2];
                $gsxObj->{GSX_LOG_INFO}->{PID}->{TRC} = $tmp_ary[3];
                $gsxObj->{GSX_LOG_INFO}->{LOGNAME}->{ACT} = $tmp_ary[4]; 
                $gsxObj->{GSX_LOG_INFO}->{LOGNAME}->{DBG} = $tmp_ary[5];
                $gsxObj->{GSX_LOG_INFO}->{LOGNAME}->{SYS} = $tmp_ary[6];
                $gsxObj->{GSX_LOG_INFO}->{LOGNAME}->{TRC} = $tmp_ary[7];
            } else {
                $gsxObj->{GSX_LOG_INFO} = undef;
                setSkipGrpData("${skip_data_header}, Reason: Failed to get GSX log PIDs and filenames " .
                               "on GSX $gsxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}."); 
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }
        }
    }

    if (defined($artobj->{SGX}) && $#{$artobj->{SGX}} > 0 ) {
        
        foreach my $sgxceArrOfArr ( @{$artobj->{SGX}} )
        {
            my ($sgxce0, $sgxce1);
            $sgxce0 = ${@{$sgxceArrOfArr}}[0];
            $sgxce1 = ${@{$sgxceArrOfArr}}[1];

            unless ( defined($sgxce0) ) { die ("execTest()- sgxce0 undefined."); }

            unless ( @{$sgxce0->{SGX_LOG_INFO}} =
                    $sgxce0->sgxLogStart(-test_case => $testId,
                                          -host_name => $sgxce0->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} ))
            {
                $sgxce0->{SGX_LOG_INFO} = undef;

                setSkipGrpData("${skip_data_header}, Reason: Failed to start logging " .
                              "on SGX CE0 $sgxce0->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}.");
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }

            if (defined $sgxce1 )
            {
                unless ( @{$sgxce1->{SGX_LOG_INFO}} =
                      $sgxce1->sgxLogStart(-test_case => $testId,
                                          -host_name => $sgxce1->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} ))
                {
                    $sgxce1->{SGX_LOG_INFO} = undef;

                    setSkipGrpData("${skip_data_header}, Reason: Failed to start logging " .
                                "on SGX CE0 $sgxce1->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}.");
                    $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                    return 0;
                }
            }
        }
    } else {
        $logger->warn(__PACKAGE__ . ".$sub No SGXs in use. Are you using F-Link?");
    }


    foreach my $psxObj ( @{$artobj->{PSX}} )
    {
        unless ( my @tmp_ary = $psxObj->pesLogStart(-test_case => $testId,
                                                    -host_name => $psxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME},
                                                    -log_dir   => $artcfg->{USER_LOG_DIR}) )
        {
            $psxObj->{PSX_LOG_INFO} = undef;

            setSkipGrpData("${skip_data_header}, Reason: Failed to start PES logging " .
                           "on PSX $psxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}.");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        } else {
            if ($#tmp_ary == 1) {
                $logger->debug(__PACKAGE__ . ".$sub Setting PSX_LOG_INFO to respective PID and LOGNAME.");
                $psxObj->{PSX_LOG_INFO}->{PID}->{PES} = $tmp_ary[0];
                $psxObj->{PSX_LOG_INFO}->{LOGNAME}->{PES} = $tmp_ary[1];
            } else {
                $psxObj->{PSX_LOG_INFO} = undef;
                setSkipGrpData("${skip_data_header}, Reason: Failed to get PSX Pes log PID and filename " .
                               "on PSX $psxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}."); 
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            }
        }
    }
    # END LOG START
    $logger->debug(__PACKAGE__ . ".$sub End of LOG START.");

    $logger->debug(__PACKAGE__ . ".$sub Start of START SCRIPTS.");
    # START OF STARTSCRIPTS

    foreach my $script ( @scriptHashArray )
    {
        unless (defined($script->{TYPE})) {
            setSkipGrpData("${skip_data_header}, Reason: TYPE undefined on script object." . Dumper($script));
            return 0;
        }

        if ( $script->{TYPE} =~ /MGTS/i )
        {
            my ($node, $stateName) = split /:/, "$script->{ACTION}", 2;

            my $date = localtime;
            $date =~ tr/ : /_/;
            my $logFileName = 'MGTS_' . $testId . "_$date" .  "_" . $script->{OBJ}->{TMS_ALIAS_DATA}->{ALIAS_NAME} . ".log";

            $script->{LOGFILE} = $logFileName;
            $logger->debug(__PACKAGE__ . ".$sub Starting MGTS test '$stateName' on node '$node' logging to logfile '$logFileName'.");
            if ( $script->{OBJ}->startExecContinue(-node => $node,
                                 -machine => $stateName,
                                 -logfile => $logFileName) )
            {
                $script->{STATUS} = "RUNNING";
                $gblMgtsStarted = 1;
            }
            else
            {
                $logger->debug(__PACKAGE__ . ".$sub Failed to execute MGTS test '$stateName' on node '$node'.");
                $script->{RESULT} = 1; # TMS-FAIL = 1
                $script->{FAIL_REASON} = "Failed to execute MGTS test $stateName on node $node";
                $stopScriptFlag = 1;
                last;
            }
        }
        elsif ( $script->{TYPE} =~ /GBL/i )
        {
            my ($index, $gblScript) = split /:/, "$script->{ACTION}", 2;
            my $date = localtime;
            $date =~ tr/ : /_/;
            $gblLogFileName = 'GBL_' . $testId . "_$date" . "_" .
                            $script->{OBJ}->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} . ".log";

            $logger->debug(__PACKAGE__ . ".$sub Starting GBL test '$gblScript' with varfile '$artobj->{GBL}->[$index]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}'.var logging to logfile '$gblLogFileName'.");
            if ( my $gblPid = $script->{OBJ}->startExecContinue(
                              -varfile => $artobj->{GBL}->[$index]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} . "\.var",
                              -script  => $gblScript,
                              -script_path => $testcfg->{GBL_TEST_PATHS}[$index],
                              -logfile => $gblLogFileName) )
            {
                $script->{STATUS} = "RUNNING PID=$gblPid";
                $gblMgtsStarted = 1;
            }
            else
            {
                $logger->debug(__PACKAGE__ . ".$sub Failed to execute GBL test '$gblScript' with varfile '$artobj->{GBL}->[$index]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}'.var.");
                $script->{RESULT} = 1; # TMS-FAIL = 1
                $script->{FAIL_REASON} = "Failed to execute GBL test $script->{ACTION}.";
                $stopScriptFlag = 1;
                last;
            }
        }
        elsif ( $script->{TYPE} =~ /GSX/i )
        {
            $logger->debug(__PACKAGE__ . ".$sub Executing GSX command '$script->{ACTION}'.");
            
            my @result = $script->{OBJ}->execCmd($script->{ACTION}); 
            #$logger->debug(__PACKAGE__ . ".$sub execCmd debug = " .Dumper($script->{OBJ}->{CMDRESULTS}));

            if ( $#result >=0 && ( $result[0] =~ /^error/i || $result[0] =~ /ATS ERROR/i )) {
                $script->{RESULT} = 1; # TMS-FAIL = 1
                $script->{STATUS} = "COMPLETED";
                my $fail_reason = join /\n/,@result;
                $logger->error(__PACKAGE__ . ".$sub Failed to execute GSX command '$script->{ACTION}' due to:\n${fail_reason}.");
                $script->{FAIL_REASON} = "Failed to execute gsx-cli command $script->{ACTION} due to:\n${fail_reason}\n";
                # MY-FLAG
                # $stop_script_flag = 1;
                # last;
            }
            else
            {
                $logger->debug(__PACKAGE__ . ".$sub Successfully executed GSX command '$script->{ACTION}'.");
                $script->{STATUS} = "COMPLETED";
                $script->{RESULT} = 0;
            }
        }
        else
        {
            setSkipGrpData("${skip_data_header}, Reason: Unknown script TYPE \"$script->{TYPE}\" in execTest function.");
            return 0;
        }
    }

    # END OF STARTSCRIPTS
    $logger->debug(__PACKAGE__ . ".$sub End of START SCRIPTS.");


    # START OF LOOP TESTING FOR SCRIPT COMPLETION
    $logger->debug(__PACKAGE__ . ".$sub Start of LOOP testing for SCRIPT COMPLETION.");

    my $allTestsComplete = 0;
   
    if ( $gblMgtsStarted == 1 && $stopScriptFlag == 0 )
    {
        my $pollingPeriod = 1;
        if ( $timeout > 60 ) { $pollingPeriod = $timeout/10; }

        my $allTestsComplete = 0;
        my $startLoopTime    = [gettimeofday];
        my $loopTimer        = 0;

    while  ( (!$allTestsComplete) && (tv_interval($startLoopTime) < $timeout) )   
    {
        sleep($pollingPeriod);
        $allTestsComplete = 1;

        foreach my $scriptInst ( @scriptHashArray )
        {
            if ( defined($scriptInst->{STATUS}) && $scriptInst->{STATUS}  =~ /RUNNING/i )
            {
                if ( defined($scriptInst->{TYPE}) && $scriptInst->{TYPE} =~ /MGTS/i )
                {
                    my ($mName, $mStateMc) = split /:/, "$scriptInst->{ACTION}", 2;
                    my $areStatesRunning = $scriptInst->{OBJ}->areStatesRunning(-node => $mName);

                    if ( $areStatesRunning == 0 )
                    {
                        $scriptInst->{STATUS} = "COMPLETED";

                        my $mgtsResult = $scriptInst->{OBJ}->checkResult( -node => $mName,
                                                                          -machine => $mStateMc);
                        if ( $mgtsResult == 1)
                        {
                            $scriptInst->{RESULT} = 0;
                        }
                        elsif ( $mgtsResult == 0)
                        {
                            $scriptInst->{RESULT} = 1;
                        }
                        elsif ( $mgtsResult == -1)
                        {
                            $scriptInst->{RESULT} = 1;
                            $scriptInst->{FAIL_REASON} = "MGTS script did not transition through PASS/FAIL node".
                                                         " OR MGTS::checkResult returned inconclusive result";
                        }
                        elsif ( $mgtsResult == -2 )
                        {
                            $scriptInst->{RESULT} = 1;
                            $scriptInst->{FAIL_REASON} = "Failed to get result via MGTS::checkResult (see ATS log).";
                        }
                        else
                        {
                            die("Unexpected return code from MGTS::checkResult ".
                                "for test-$testId, mgtsStateMachine-$mStateMc.");
                        }
                    }
                    elsif ( $areStatesRunning == -1 )
                    {
                        $scriptInst->{FAIL_REASON} = "Failed to get result via MGTS::areStatesRunning (see ATS log).";
                    }
                    elsif ( $areStatesRunning == 1 )
                    {
                        $allTestsComplete = 0;
                    }
                    else
                    {
                        die("Unexpected return code from MGTS::areStatesRunning.");
                    }
                }
                elsif ( defined($scriptInst->{TYPE}) && $scriptInst->{TYPE} =~ /GBL/i )
                {
                    my $gblProcessId = trim( (split(/PID=/, $scriptInst->{STATUS}))[1]);
                    my $isGblScriptRunning = $scriptInst->{OBJ}->isScriptRunning(-pid => $gblProcessId);

                    if ( $isGblScriptRunning == 0 )
                    {
                        $scriptInst->{STATUS} = "COMPLETED";

                        my $logLocation = "/sonus/SonusNFS/AUTOMATION/" . $gblLogFileName;
                        my $cmd = "grep \"TRACE ENDS FOR TEST CASE $scriptInst->{ACTION}\" $logLocation";
                        my @result = $scriptInst->{OBJ}->execCmd($cmd);
                        $logger->debug(__PACKAGE__ . ".$sub command [$cmd] result - [@result].");
                        @result = $scriptInst->{OBJ}->execCmd("echo \$?");

                        if( $result[0] == 0 )
                        {
                            my $cmdPass = "grep \"CALL FLOW FOR TEST CASE $scriptInst->{ACTION} SUCCESSFULLY COMPLETED\" $logLocation";
                            my $cmdFail = "grep \"TEST CASE $scriptInst->{ACTION} FAILED\" $logLocation";

                            my @result = $scriptInst->{OBJ}->execCmd($cmdPass);
                            $logger->debug(__PACKAGE__ . ".$sub command [$cmdPass] result - [@result].");
                            @result = $scriptInst->{OBJ}->execCmd("echo \$?");

                            my @result2 = $scriptInst->{OBJ}->execCmd($cmdFail);
                            $logger->debug(__PACKAGE__ . ".$sub command [$cmdFail] result - [@result2].");
                            @result2 = $scriptInst->{OBJ}->execCmd("echo \$?");

                            if ( $result[0] == 0 )
                            {
                                $scriptInst->{RESULT} = 0;
                            }
                            elsif ( $result2[0] == 0 )
                            {
                                $scriptInst->{RESULT} = 1;
                                $scriptInst->{FAIL_REASON} = "GBL script transitioned through FAIL leg.";
                            }
                            else
                            {
                                $scriptInst->{RESULT} = 1;
                                $scriptInst->{FAIL_REASON} = "GBL script finished but could not get status PASS/FAIL.";
                            }
                        }
                        else
                        {
                            $scriptInst->{RESULT} = 1;
                            $scriptInst->{FAIL_REASON} = "GBL script finished but could not find \"TRACE ENDS FOR TEST CASE\" string.";
                        }
                    }
                    elsif ( $isGblScriptRunning == -1 )
                    {
                        $scriptInst->{RESULT} = 1;
                        $scriptInst->{FAIL_REASON} = "Failed to identify whether GBL scripts are still" .
                                                     " running via GBL::isScriptRunning() function, see ATS log.";
                    }
                    else
                    {
                        $allTestsComplete = 0;
                    }
                }
            }
        }
    } # while loop
  } # enclosing if

    # END OF LOOP TESTING FOR SCRIPT COMPLETION
    $logger->debug(__PACKAGE__ . ".$sub End of LOOP testing for SCRIPT COMPLETION.");

    # START OF FORCEFUL STOP OF SCRIPTS
    
    if ( $allTestsComplete == 0 || $stopScriptFlag == 1)
    {
        $logger->debug(__PACKAGE__ . ".$sub Start of FORCEFUL STOP OF SCRIPTS.");
        foreach my $scriptHash ( @scriptHashArray )
        {
            unless (defined($scriptHash->{STATUS})){
                  #$logger->debug(__PACKAGE__ . ".$sub DEBUG scriptHash = " . Dumper($scriptHash));
                  next; 
            }

            if ( $scriptHash->{STATUS} =~ /RUNNING/i )
            {
                $scriptHash->{STATUS} = "TIMED OUT";
                $scriptHash->{RESULT} = 1;
                $scriptHash->{FAIL_REASON} = "Script has been forcibly stopped due to timing out.";

                if ( $scriptHash->{TYPE} =~ /MGTS/i )
                {
                    my ($node, $stName) = split /:/, "$scriptHash->{ACTION}", 2;
                    unless ($scriptHash->{OBJ}->stopExec(-node => $node))
                    {
                        setSkipGrpData("${skip_data_header}, Reason: Unable to stop MGTS script \"$stName\" on MGTS node \"$node\".");
                    }
                }
                elsif ( $scriptHash->{TYPE} =~ /GBL/i )
                {
                    my $gblPID = trim( (split(/PID=/, $scriptHash->{STATUS}))[1]);
                    my ($gblIndex, $gblScrName) = split /:/, "$scriptHash->{ACTION}", 2;

                    unless ( $scriptHash->{OBJ}->stopExec( -pid => $gblPID ) )
                    {
                        setSkipGrpData("${skip_data_header}, Reason: Unable to stop GBL script \"$gblScrName\"" .
                                       " on GBL server $scriptHash->{OBJ}->{TMS_ALIAS_DATA}->{NODE}->{1}->{HOSTNAME}.");
                    }
                }
            }
        }
        $logger->debug(__PACKAGE__ . ".$sub End of FORCEFUL STOP OF SCRIPTS.");
    }
    # END OF FORCEFUL STOP OF SCRIPTS

    # START OF CHECK CIRCUITS/CHANNELS

    unless ( $skipCicChecks == 1 )
    {
        $logger->debug(__PACKAGE__ . ".$sub Start of CHECK CIRCUITS/CHANNELS.");
      
        my @cleanupRebootStatus;
        my $cleanup_required;

         foreach my $gsxOb ( @{$artobj->{GSX}} )
        {
            my $cleanRebootStat = $gsxOb->isCleanupOrRebootRequired();
            push(@cleanupRebootStatus, $cleanRebootStat);

            if ($cleanRebootStat == 1)
            {
                $cleanup_required = 1;
            }
        }

        if ($cleanup_required)
        {
            foreach my $mgtsOb ( @{$testcfg->{USED_MGTS_OBJ}} )
            {
                foreach my $cleanupNode ( keys %{$mgtsOb->{CLEANUP}} )
                {
       	            $logger->debug(__PACKAGE__ . ".$sub MGTS Statename for node '$cleanupNode' = $mgtsOb->{CLEANUP}->{$cleanupNode}->{MACHINE}\n" );
			
                    my $cleanupStateName = $mgtsOb->{CLEANUP}->{$cleanupNode}->{MACHINE};
                    my $cleanupStateLogName = $cleanupStateName;
                    $cleanupStateLogName =~ s/\s+/_/g;
                    my $cleanupLogFile = "CLEANUP_${testId}_${cleanupNode}_${cleanupStateLogName}\.log";

                    if ( defined $cleanupNode && defined $cleanupStateName )
                    {
                        unless ( $mgtsOb->startExecContinue(-node => $cleanupNode,
                                                            -machine => $cleanupStateName,
                                                            -logfile => $cleanupLogFile) )
                        {
                            setSkipGrpData("${skip_data_header}, Reason: Failed to start MGTS cleanup state-mc $cleanupStateName on node $cleanupNode ");
                            return 0;
                        }
                    }
                    else
                    {
                        setSkipGrpData("${skip_data_header}, Reason: Unable to find cleanup state-mc " .
                                       "data for MGTS - $mgtsOb->{TMS_ALIAS_DATA}->{ALIAS_NAME}.");  
                        return 0;
                    }
                }
            }
        }

        my $gsxObjIndex = 0;
        #my $cicsNonIdleAfterTestFound = 0;

        foreach my $status ( @cleanupRebootStatus )
        {
            if ( $status == 2 || $status == 1 )
            {
                $cicsNonIdleAfterTestFound = 1;
                my $date = localtime;
                $date =~ tr/ : /_/;

                # write cleanup array to a file
                my $dumpFileName = $artcfg->{USER_LOG_DIR} . "CLEANUP_REASON_${testId}_$date"."\.dump";
                open (DUMPFILE, ">$dumpFileName");
                print DUMPFILE Dumper( $artobj->{GSX}[$gsxObjIndex]->{CLEANUP_REASON} );
                close (DUMPFILE); 
            }

            if ( $status == 2 )
            {
                setSkipGrpData("${skip_data_header}, Reason: Reboot required, identified by isCleanupRebootRequired().");
            }
            elsif ( $status == 1 )
            {
                foreach my $cleanArr ( @{$artobj->{GSX}->[$gsxObjIndex]->{CIC_CLEANUP_ARRAY}} )
                {
                    # Format of $cleanArr = '<ISUP|BT>,<service grp name>,<cic number>'
                    my ($serviceType, $serviceGrp, $cic) = split /,/, $cleanArr;
                    $logger->debug(__PACKAGE__.".$sub extracted $serviceType, $serviceGrp, $cic.");

                    my $cicStatusHash = $artobj->{GSX}->[$gsxObjIndex]->{CICSTATE}->{$serviceType . ',' . $serviceGrp}->[$cic];
                    my @result;
                    if ( $cicStatusHash->{STATUS} =~ /N\/A/i )
                    {
                        @result = $artobj->{GSX}->[$gsxObjIndex]->execCmd("CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic STATE ENABLED");
                        $logger->debug(__PACKAGE__.".$sub CIC STATE ENABLED command result - @result");
                        @result = $artobj->{GSX}->[$gsxObjIndex]->execCmd("CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic MODE UNBLOCK");
                        $logger->debug(__PACKAGE__.".$sub CIC MODE UNBLOCK command result - @result");
                    }
                    else
                    {
                        @result = $artobj->{GSX}->[$gsxObjIndex]->execCmd("CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic MODE RESET");
                        $logger->debug(__PACKAGE__.".$sub CIC MODE RESET command result - @result");
                        @result = $artobj->{GSX}->[$gsxObjIndex]->execCmd("CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic MODE UNBLOCK");
                        $logger->debug(__PACKAGE__.".$sub CIC MODE UNBLOCK command result - @result");
                    }
                }

                foreach my $chancleanArr ( @{$artobj->{GSX}[$gsxObjIndex]->{CHAN_CLEANUP_ARRAY}} )
                {
                    # Format of $chancleanArr = '<service grp name>,<chan number>'
                    my ($serviceGrp, $chan) = split /,/, $chancleanArr;
                    $logger->debug(__PACKAGE__.".$sub cleaning up servicegroup/channel - $serviceGrp/$chan.");

                    my @result = $artobj->{GSX}->[$gsxObjIndex]->execCmd("CONFIGURE ISDN BCHANNEL SERVICE $serviceGrp INTERFACE 0 BCHANNEL $chan STATE DISABLED");
                    $logger->debug(__PACKAGE__.".$sub STATE DISABLED command result - @result");
                    @result = $artobj->{GSX}->[$gsxObjIndex]->execCmd("CONFIGURE ISDN BCHANNEL SERVICE $serviceGrp INTERFACE 0 BCHANNEL $chan STATE ENABLED");
                    $logger->debug(__PACKAGE__.".$sub STATE ENABLED command result - @result");
                }

                my $cleanupReq = 0;
                $cleanRebootStat = $artobj->{GSX}->[$gsxObjIndex]->isCleanupOrRebootRequired();

                if ( $cleanRebootStat == 1 ) { $cleanupReq = 1; }

                $cicsNonIdleAfterCleanupFound = 0;

                if ( $cleanRebootStat == 1 || $cleanRebootStat == 2 )
                {
                    $cicsNonIdleAfterCleanupFound = 1;
                    my $date = localtime;
                    $date =~ tr/ : /_/;

                    # write cleanup array to a file
                    my $dumpFileName = $artcfg->{USER_LOG_DIR} . "CLEANUP_REASON_${testId}_$date"."\.dump";
                    open (DUMPFILE, ">$dumpFileName");
                    print DUMPFILE Dumper( $artobj->{GSX}->[$gsxObjIndex]->{CLEANUP_REASON} );
                    close (DUMPFILE); 
                }

                if ( $cleanRebootStat == 2 )
                {
                    setSkipGrpData("${skip_data_header}, Reason: Reboot required, after attempt to cleanup circuits/channels.");
                }
                elsif ( $cleanRebootStat == 1 )
                {
                    setSkipGrpData("${skip_data_header}, Reason: Failed to cleanup circuits/channels.");
                    #$artobj->{GSX}->[$gsxObjIndex]->{RESET_NODE} = 1;
                }
                else
                {
                    $logger->debug(__PACKAGE__.".$sub circuits/channels cleared successfully.");
                }

                # Stop mgts cleanup st-mc's
                foreach my $localMgtsObj ( @{$testcfg->{USED_MGTS_OBJ}} )
                {
                    foreach my $cupNode ( keys %{$localMgtsObj->{CLEANUP}} )
                    {
                        my $cleanupStateName = $localMgtsObj->{CLEANUP}->{$cupNode}->{MACHINE};

                        if ( defined $cupNode && defined $cleanupStateName )
                        {
                            if ( $localMgtsObj->areStatesRunning( -node => $cupNode ) )
                            {
                                unless ( $localMgtsObj->stopExec( -node => $cupNode,
                                                                  -machine => $cleanupStateName) )
                                {
                                    setSkipGrpData("${skip_data_header}, Reason: Failed to stop MGTS cleanup ".
                                                   "state machine \"$cleanupStateName\" on node \"$cupNode\".");
                                    return 0;
                                }
                            }
                        }
                        else
                        {
                            setSkipGrpData("${skip_data_header}, Reason: Failed to find cleanup ".
                                           "state machine for MGTS object - $localMgtsObj->{TMS_ALIAS_DATA}->{ALIAS_NAME}.");
                            return 0;
                        }
                    }
                }

            }
            else
            {
                $logger->debug(__PACKAGE__.".$sub all circuits/channels are IDLE, no cleanup or reboot required");
            }
            $gsxObjIndex++;
        }
        $logger->debug(__PACKAGE__ . ".$sub End of CHECK CIRCUITS/CHANNELS.");
    } #outermost unless

    # END OF CHECK CIRCUITS/CHANNELS

    # START OF POST TEST CHECKS

    $logger->debug(__PACKAGE__ . ".$sub Start of POST TEST CHECKS.");
    foreach my $gsxObjRefr ( @{$artobj->{GSX}} )
    {
        my $retCode = $gsxObjRefr->detectSwOverAndRevert();
        if ( $retCode == 0 )
        {
            $gsxSwitchOverFound = 1;
            $gsxObjRefr->execCmd("debugindicator 1");
            $gsxObjRefr->execCmd("ds diameter enable");
            $gsxObjRefr->execCmd("sipfesetprintpdu on");
            # T.B.D
            # Re-add any other gsx debug commands:
            #   dabreakpoint
        }

        if ( $skipPostChecks != 1 )
        {
            if (defined($artcfg->{TEST_CHECK_REF})) 
            {
                my $funcName = $artcfg->{TEST_CHECK_REF};
                my $retVal = 1; #&$funcName();
                $logger->debug(__PACKAGE__ . ".$sub globalPostCheck - called $funcName, retVal - $retVal.");

                if ( $retVal == 0 )
                {
                    $globalPostCheckErrorFound = 1;
                }
            }
        }
            
        if ( defined($postCheckFn) )
        {
            my $retVal = 1; #&$postCheckFn();
            $logger->debug(__PACKAGE__ . ".$sub localPostCheck - called $postCheckFn, retVal - $retVal.");
    
            if ( $retVal == 0 )
            {
                $localPostCheckErrorFound = 1;
            }
        }

        my $gsxName = $gsxObjRefr->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};
        if ( $gsxObjRefr->gsxCoreCheck( -host_name => $gsxName,
                                        -test_case => $testId ) > 0 )
        {
            $gsxCoreDumpFound = 1;
            my $mvCmd = "\\mv /sonus/SonusNFS/$gsxName/coredump/${testId}\* $artcfg->{USER_LOG_DIR}";
            if (system($mvCmd))
            {
                $logger->error(__PACKAGE__ . ".$sub Unable to execute [$mvCmd].");
            }
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub End of POST TEST CHECKS.");

    # END OF POST TEST CHECKS

    # START OF STOP-LOGGING

    $logger->debug(__PACKAGE__ . ".$sub Start of STOP LOGGING.");
    foreach my $gsxObjRef ( @{$artobj->{GSX}} )
    {
        if (exists($gsxObjRef->{GSX_LOG_INFO}->{PID})) {
            my $procList = $gsxObjRef->{GSX_LOG_INFO}->{PID}->{ACT} . "," . 
                           $gsxObjRef->{GSX_LOG_INFO}->{PID}->{DBG} . "," . 
                           $gsxObjRef->{GSX_LOG_INFO}->{PID}->{SYS} . "," . 
                           $gsxObjRef->{GSX_LOG_INFO}->{PID}->{TRC}; 
            $logger->debug(__PACKAGE__ . ".$sub stopping logging on GSX \"$gsxObjRef->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}\" procList-$procList.");
            if ( $gsxObjRef->gsxLogStop( -process_list => $procList ) != 1 )
            {
                setSkipGrpData("${skip_data_header}, Reason: Failed to stop logging ".
                               "on GSX \"$gsxObjRef->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}\"."); 
            } else {
                delete($gsxObjRef->{GSX_LOG_INFO}->{PID});
            }
        }
    }

    foreach my $sgxceAOfA ( @{$artobj->{SGX}} )
    {
        my ($sgxce0, $sgxce1);
        $sgxce0 = ${@{$sgxceAOfA}}[0];
        $sgxce1 = ${@{$sgxceAOfA}}[1];

        if (defined $sgxce0)
        {
            my @logInfo = @{$sgxce0->{SGX_LOG_INFO}};
            my $procsList = "$logInfo[0],$logInfo[1],$logInfo[2],$logInfo[3]";
            my $fileList  = "$logInfo[4],$logInfo[5],$logInfo[6],$logInfo[7]";

            $logger->debug(__PACKAGE__ . ".$sub calling sgxLogStop on $sgxce0->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}" .
                           " -process_list [$procsList] and -file_list [$fileList].");
            $sgxce0->sgxLogStop(-log_dir => $artcfg->{USER_LOG_DIR},
                                -process_list => $procsList,
                                -file_list => $fileList);
        }

        if (defined $sgxce1)
        {
            my @logInfo = @{$sgxce1->{SGX_LOG_INFO}};
            my $procsList = "$logInfo[0],$logInfo[1],$logInfo[2],$logInfo[3]";
            my $fileList  = "$logInfo[4],$logInfo[5],$logInfo[6],$logInfo[7]";

            $logger->debug(__PACKAGE__ . ".$sub calling sgxLogStop on $sgxce1->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}" .
                           " -process_list [$procsList] and -file_list [$fileList].");
            $sgxce1->sgxLogStop(-log_dir => $artcfg->{USER_LOG_DIR},
                                -process_list => $procsList,
                                -file_list => $fileList);
        }
    }

    foreach my $psxObjRef (@{$artobj->{PSX}})
    {
        if (exists($psxObjRef->{PSX_LOG_INFO}->{PID}->{PES})) {
            $logger->debug(__PACKAGE__ . ".$sub stopping PES logging on PSX \"$psxObjRef->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}\" PID:$psxObjRef->{PSX_LOG_INFO}->{PID}->{PES}, File:$psxObjRef->{PSX_LOG_INFO}->{LOGNAME}->{PES}.");
            
            if ( $psxObjRef->pesLogStop( -pid => $psxObjRef->{PSX_LOG_INFO}->{PID}->{PES},
                                         -filename => $psxObjRef->{PSX_LOG_INFO}->{LOGNAME}->{PES},
                                         -log_dir   => $artcfg->{USER_LOG_DIR}) != 1)
            {
                setSkipGrpData("${skip_data_header}, Reason: Failed to stop logging ".
                               "on PSX \"$psxObjRef->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}\"."); 
            } else {
                delete($psxObjRef->{PSX_LOG_INFO}->{PID}->{PES});
            }
        }
    }

    foreach my $script ( @scriptHashArray )
    {
        unless (defined($script->{TYPE})) {
            setSkipGrpData("${skip_data_header}, Reason: TYPE undefined on script object." . Dumper($script));
            return 0;
        }

        if ( $script->{TYPE} =~ /MGTS/i )
        {
            my $mgtsLogFileName = $script->{LOGFILE};
        
            if ( $script->{OBJ}->downloadLog(-logfile => $mgtsLogFileName,
                             -local_dir => $artcfg->{USER_LOG_DIR}) == 1 )
            {
                my $grepCmd1 = "\\grep \"Warning: The following message does not match any templates\" $artcfg->{USER_LOG_DIR}" . $mgtsLogFileName;
                my $grepCmd2 = "\\grep \"Sequence Completed by Stop\" $artcfg->{USER_LOG_DIR}" . $mgtsLogFileName;
                my $grepResult1 = `$grepCmd1`;
                my $grepResult2 = `$grepCmd2`;
                if ( $grepResult1 ne "" || $grepResult2 ne "" )
                {
                    $mgtsLogErrorFound=1;
                }
            }
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub End of STOP LOGGING.");
    # END OF STOP-LOGGING

    # START OF PARSE GSX LOGS
    $logger->debug(__PACKAGE__ . ".$sub Start of PARSE GSX LOGS.");

    $SonusQA::GSX::UKLogParser::test_id = $testId;

    # NOTE 1ST GSX->INGRESS 2ND -> EGRESS
    my @gsxArr = @{$artobj->{GSX}};
    my $gsxObjRef = $gsxArr[0];
    $SonusQA::GSX::UKLogParser::gsx_file{ACTING} = $artcfg->{USER_LOG_DIR} . $gsxObjRef->{GSX_LOG_INFO}->{LOGNAME}->{ACT};
    $SonusQA::GSX::UKLogParser::gsx_file{DBGING} = $artcfg->{USER_LOG_DIR} . $gsxObjRef->{GSX_LOG_INFO}->{LOGNAME}->{DBG};
    $SonusQA::GSX::UKLogParser::gsx_file{SYSING} = $artcfg->{USER_LOG_DIR} . $gsxObjRef->{GSX_LOG_INFO}->{LOGNAME}->{SYS};  
    $SonusQA::GSX::UKLogParser::gsx_file{TRCING} = $artcfg->{USER_LOG_DIR} . $gsxObjRef->{GSX_LOG_INFO}->{LOGNAME}->{TRC}; 

    if (defined($gsxArr[1]))
    {
        $gsxObjRef = $gsxArr[1];
    } else {
        $gsxObjRef = $gsxArr[0];
    }

    $SonusQA::GSX::UKLogParser::gsx_file{ACTEG} = $artcfg->{USER_LOG_DIR} . $gsxObjRef->{GSX_LOG_INFO}->{LOGNAME}->{ACT};
    $SonusQA::GSX::UKLogParser::gsx_file{DBGEG} = $artcfg->{USER_LOG_DIR} . $gsxObjRef->{GSX_LOG_INFO}->{LOGNAME}->{DBG};
    $SonusQA::GSX::UKLogParser::gsx_file{SYSEG} = $artcfg->{USER_LOG_DIR} . $gsxObjRef->{GSX_LOG_INFO}->{LOGNAME}->{SYS};  
    $SonusQA::GSX::UKLogParser::gsx_file{TRCEG} = $artcfg->{USER_LOG_DIR} . $gsxObjRef->{GSX_LOG_INFO}->{LOGNAME}->{TRC}; 

    if ( -e $artcfg->{GENERIC_LOGPARSE_FILE} )
    {
        $SonusQA::GSX::UKLogParser::gen_file = $artcfg->{GENERIC_LOGPARSE_FILE};
    }

    SonusQA::GSX::UKLogParser::get_parse_strings_from_db();

    $numGenStrings = SonusQA::GSX::UKLogParser::get_generic_parse_strings();

    $logger->debug(__PACKAGE__ . ".$sub Adding 4 generic parse strings to check for SYS Errors and software failures in Ingress and Egress SYS Logs.");
    push(@{SonusQA::GSX::UKLogParser::input_matchstrings} , [ "GEN_".$numGenStrings++, "!SYS:ING:\"SYS ERR\"", "generic" ]);
    push(@{SonusQA::GSX::UKLogParser::input_matchstrings} , [ "GEN_".$numGenStrings++, "!SYS:EG:\"SYS ERR\"", "generic" ]);
    push(@{SonusQA::GSX::UKLogParser::input_matchstrings} , [ "GEN_".$numGenStrings++, "!SYS:ING:\"software failure\"", "generic" ]);
    push(@{SonusQA::GSX::UKLogParser::input_matchstrings} , [ "GEN_".$numGenStrings++, "!SYS:EG:\"software failure\"", "generic" ]);
    #print Dumper @{SonusQA::GSX::UKLogParser::input_matchstrings}; 

    if (SonusQA::GSX::UKLogParser::matchmaker() == 0 )
    {
        $gsxLogParseErrorFound = 1;
    }
    else
    {
        $gsxLogParseErrorFound = 0;
    }
    $logger->debug(__PACKAGE__ . ".$sub End of PARSE GSX LOGS.");
    # END OF PARSE GSX LOGS

    # START OF LOG RESULT
    $logger->debug(__PACKAGE__ . ".$sub Start of LOG RESULT.");

    my $mgtsTimeout = 0;
    my $mgtsFailure = 0;
    my $gblTimeout  = 0;
    my $gblFailure  = 0;
    my $gsxFailure  = 0;
    my $overAllFailure = 0;

    foreach my $script (@scriptHashArray)
    {
        if (defined($script->{RESULT}) &&  $script->{RESULT} == 1)
        {
            unless (defined($script->{TYPE}))
            {
                die "Script type is undefined";
            }

            if ( $script->{TYPE} =~ /MGTS/i )
            {
                if ($script->{STATUS} =~ /TIMED OUT/i )
                {
                    $mgtsTimeout = 1;
                }
                else
                {
                    $mgtsFailure = 1;
                }
            }
            elsif ( $script->{TYPE} =~ /GBL/i )
            {
                if ($script->{STATUS} =~ /TIMED OUT/i )
                {
                    $gblTimeout = 1;
                }
                else
                {
                    $gblFailure = 1;
                }
            }
            elsif ( $script->{TYPE} =~ /GSX/i )
            {
                $gsxFailure  = 1;
            }
            else
            {
                die"No other script types [$script->{TYPE}] are recognised.";
            }
            $logger->debug(__PACKAGE__.".$sub FAILURE reason : [$script->{FAIL_REASON}].");
        }
    }
    my $result_logger = get_logger("RESULT");

    if ( $mgtsTimeout == 1 || $mgtsFailure == 1 ||
         $gblTimeout == 1  || $gblFailure == 1 ||
         $gsxFailure == 1  || $mgtsLogErrorFound == 1 ||
         $cicsNonIdleAfterCleanupFound == 1 || $cicsNonIdleAfterTestFound == 1 ||
         $gsxSwitchOverFound == 1 || $gsxCoreDumpFound == 1 ||
         $gsxLogParseErrorFound == 1 || $globalPostCheckErrorFound == 1 ||
         $localPostCheckErrorFound == 1 )
    {
        $overAllFailure = 1;
        $result_logger->info(__PACKAGE__.".$sub OVERALL VERDICT [FAIL] FOR TEST-CASE [$testId].");
    }
    else
    {
        $result_logger->info(__PACKAGE__.".$sub OVERALL VERDICT [PASS] FOR TEST-CASE [$testId].");
    }

    if ( $testId !~ /config_update/i || $testId !~ /cleanup/i )
    {
        my $metadata = "
        MGTS_SCRIPT_FAIL: $mgtsFailure
        MGTS_SCRIPT_TIMEOUT: $mgtsTimeout
        MGTS_LOG_ERROR: $mgtsLogErrorFound
        GBL_SCRIPT_FAIL: $gblFailure
        GBL_SCRIPT_TIMEOUT: $gblTimeout
        GSX_CLI_FAIL: $gsxFailure
        CIC/CHANNEL NON-IDLE AFTER TEST: $cicsNonIdleAfterTestFound
        CIC/CHANNEL NON-IDLE AFTER CLEANUP: $cicsNonIdleAfterCleanupFound
        GSX CARD SWITCHOVER: $gsxSwitchOverFound
        GSX CORE FOUND: $gsxCoreDumpFound
        GSX LOG PARSE ERROR: $gsxLogParseErrorFound
        GLOBAL POST TEST CHECK: $globalPostCheckErrorFound
        LOCAL POST TEST CHECK: $localPostCheckErrorFound
        ";

        $result_logger->info(__PACKAGE__.".$sub METADATA:\n$metadata") if $overAllFailure;
    }
    
    if ( $overAllFailure == 0 )
    {
        $logger->debug("Leaving $sub retCode-1.");
        return 1;
    }
    else
    {
        $logger->debug("Leaving $sub retCode-0.");
        return 0;
    }
    # END OF LOG RESULT
}


=pod

=head1 B<setupTestGrpConfig()>

  This function is called form within every test group configuration file and will validate the variables specified in 
  the test group configuration file.

=over 6

=item Arguments :

 None.

=item Return Values :

 1 . on success
 0 . otherwise (with $testcfg->{SKIP_GROUP} being set)

=item Example :

 setupTestGrpConfig()

=item Author :

 Hefin Hamblin 
 hhamblin@sonusnet.com

=back

=cut

sub setupTestGrpConfig
{
    my $sub = "setupTestGrpConfig()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    $logger->debug(__PACKAGE__ . ".$sub Entered function.");
  
    # Initialise test group config variables  
    initTestGrpVars();

    # Set out header data for every time the setSkipGrpData() function is
    # called
    my $skip_data_header = "Test Grp: " . "$testcfg->{TEST_GRP}" . ", Function: " . $sub ; 

    # Loop thru GSX objects in $artobj->{GSX}
    foreach my $gsxObj ( @{$artobj->{GSX}} )
    {
        # Get GSX name
        my $gsx_name = $gsxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME};

        # Remove GSX core files from NFS coredump directory
        unless ($gsxObj->removeGsxCore( -host_name => "$gsx_name" )) 
        {
            $logger->error(__PACKAGE__ . ".$sub Unable to remove core files from /sonus/SonusNFS/${gsx_name}/coredump directory.");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }

        # Start GSX Event Logging
        my @tmp_ary;
        unless (@tmp_ary = $gsxObj->gsxLogStart(-test_case => $testcfg->{TEST_GRP} . "_config",
                                                               -host_name => "$gsx_name",
                                                               -log_dir   => "$artcfg->{USER_LOG_DIR}")) 
        {
            # Print the fail reason and skip the group
            setSkipGrpData("${skip_data_header}, Reason: Failed to start logging on GSX ${gsx_name}");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0 ;
        }
       
        if ($#tmp_ary == 7) {
            $gsxObj->{GSX_LOG_INFO}->{PID}->{ACT} = $tmp_ary[0];
            $gsxObj->{GSX_LOG_INFO}->{PID}->{DBG} = $tmp_ary[1];
            $gsxObj->{GSX_LOG_INFO}->{PID}->{SYS} = $tmp_ary[2];
            $gsxObj->{GSX_LOG_INFO}->{PID}->{TRC} = $tmp_ary[3];
            $gsxObj->{GSX_LOG_INFO}->{LOGNAME}->{ACT} = $tmp_ary[4]; 
            $gsxObj->{GSX_LOG_INFO}->{LOGNAME}->{DBG} = $tmp_ary[5];
            $gsxObj->{GSX_LOG_INFO}->{LOGNAME}->{SYS} = $tmp_ary[6];
            $gsxObj->{GSX_LOG_INFO}->{LOGNAME}->{TRC} = $tmp_ary[7];
        }
    } # end gsx object loop

    unless ( checkRequiredMgts() ) 
    {
        # Print the fail reason. Skip group flag set within checkRequiredMgts()
        # function
        $logger->error(__PACKAGE__ . ".$sub Problem encountered while checking required MGTS");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0 ;
    }

    unless ( checkRequiredGbl() ) 
    {
        # Print the fail reason. Skip group flag set within checkRequiredGbl()
        # function
        $logger->error(__PACKAGE__ . ".$sub Problem encountered while checking required GBL servers");
        $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
        return 0 ;

    } 
       
    if ($#{$testcfg->{REQ_MGTS}} >= 0) 
    {
        unless ( assignRequiredMgts(@{$testcfg->{REQ_MGTS}}) ) 
        {
            # Print the fail reason. Skip group flag set within
            # assignRequiredMgts() function
            $logger->error(__PACKAGE__ . ".$sub Problem encountered while assigning required MGTS");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }
        
        unless ( checkMgtsSeqgrps() ) 
        {
            # Print the fail reason. Skip group flag set within
            # checkMgtsSeqgrps() function
            $logger->error(__PACKAGE__ . ".$sub Problem encountered while checking MGTS Sequence groups");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }

        unless ( checkMgtsAssignment() ) 
        {
            # Print the fail reason. Skip group flag set within
            # checkMgtsAssignment() function
            $logger->error(__PACKAGE__ . ".$sub Problem encountered while checking MGTS Assignments");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }

        unless ( configureMgts() ) 
        {
            # Print the fail reason. Skip group flag set within
            # checkMgtsAssignment() function
            $logger->error(__PACKAGE__ . ".$sub Problem encountered while configuring MGTS");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }
        
    } else {
        $logger->debug(__PACKAGE__ . ".$sub Assumed no MGTS required for this test group file '$testcfg->{TEST_GRP}' as \$testcfg->{REQ_MGTS} is not specified");
    }


    if ($#{$testcfg->{REQ_GBL}} >= 0) 
    {
        unless ( assignRequiredGbl() ) 
        {
            # Print the fail reason. Skip group flag set within
            # assignRequiredGbl() function
            $logger->error(__PACKAGE__ . ".$sub Problem encountered while assigning required GBL");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }

        unless ( checkGblPaths() ) 
        {
            # Print the fail reason. Skip group flag set within
            # checkGblPaths() function
            $logger->error(__PACKAGE__ . ".$sub Problem encountered while checking GBL paths");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }

        # Build Varfiles for each GBL server
        foreach my $gblObj ( @{$artobj->{GBL}} )
        {
            unless ( $gblObj->createVarfileFromTemplate(
                        -filename     => $artobj->{GSX}[0]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} . ".var",
                        -template     => ""#<template location>#,
                        -ing_gsx_id   => $artobj->{GSX}[0]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID},
                        -eg_gsx_id    => $artobj->{GSX}[1]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID},
                        -ing_gsx_name => $artobj->{GSX}[0]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} . ".var",
                     )) 
            {
                setSkipGrpData($skip_data_header . ", Reason: Failed to create Varfile '/tmp/GBL_VARFILES/${$artobj->{GSX}[0]->{TMS_ALAIS_DATA}->{NODE}->{1}->{NAME}}.var' on GBL Server '$gblObj->{TMS_ALIAS_DATA}->{ALIAS_NAME}}' ");
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }

            if ( $artobj->{GSX}[0]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} ne $artobj->{GSX}[1]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} )
            {
                unless ( $gblObj->createVarfileFromTemplate(
                            -filename     => $artobj->{GSX}[1]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} . ".var",
                            -template     => #<template location>#,
                            -ing_gsx_id   => $artobj->{GSX}[1]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID},
                            -eg_gsx_id    => $artobj->{GSX}[0]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID},
                            -ing_gsx_name => $artobj->{GSX}[1]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME} . ".var",
                        )) 
                {
                    setSkipGrpData($skip_data_header . ", Reason: Failed to create Varfile '/tmp/GBL_VARFILES/${$artobj->{GSX}[1]->{TMS_ALAIS_DATA}->{NODE}->{1}->{NAME}}.var' on GBL Server '$gblObj->{TMS_ALIAS_DATA}->{ALIAS_NAME}}' ");
                    $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                    return 0;
                }
            }
        } # end of loop on GBL object

    } else {
        $logger->debug(__PACKAGE__ . ".$sub Assumed no GBL servers required for this test group file '$testcfg->{TEST_GRP}' as \$testcfg->{REQ_GBL} is not specified");
    }

    my $gsxobj_idx = 0;
    my @gsx_reset_array;

    foreach my $gsxObj ( @{$artobj->{GSX}} )
    {
        if ( $gsxObj->{RESET_NODE} == 1) 
        {
           my $gsx_name = uc($gsxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME});
           # print md5 checksum for each binary image
           foreach ( qx{md5sum /sonus/SonusNFS/${gsx_name}/images/*.bin} )
           {
               chomp($_);
               $logger->info(__PACKAGE__ . ".$sub MD5 Check Sum = $_");  
           }

           # Reboot GSX
          
           $logger->debug(__PACKAGE__ . ".$sub \n\n\n\n***DEBUG**** NOTE GSX REBOOT DISABLED for testing\n\n\n\n\n");
           $gsxObj->resetNode();

           # Reset reboot flag to off (do not reboot)
           $gsxObj->{RESET_NODE} = 0;
           
           # Add index to gsx reset array
           push @gsx_reset_array, $gsxobj_idx;

        }

        # increment the gsx object index 
        $gsxobj_idx++;
    }

    if ( $#gsx_reset_array < 0 ) {
        $logger->debug(__PACKAGE__ . ".$sub No GSXs found requring a reboot");
    }

    foreach my $gsx_index (@gsx_reset_array) 
    {

        my $gsxObj = $artobj->{GSX}->[$gsx_index];
        # Set GSX object t return on error rather than call error function.
        $gsxObj->{RETURN_ON_FAIL} = 1;
        unless ($gsxObj->reconnect( -retry_timeout => 180,
                                    -conn_timeout  => 10, ))
        {
            $logger->error(__PACKAGE__ . ".$sub Failed to reconnect GSX object '$gsxObj->{TMS_ALIAS_DATA}->{ALIAS_NAME}' to GSX within 3 minutes of rebooting. Exiting...");  
            $logger->debug(__PACKAGE__ . ".$sub Exiting with retcode-0.");
            exit 0;
        }

        unless ($gsxObj->areServerCardsUp( -timeout => 240 ))
        {
            $logger->error(__PACKAGE__ . ".$sub GSX server cards did not boot within 4 minutes of MNS connection becoming available on GSX '$gsxObj->{TMS_ALIAS_DATA}->{ALIAS_NAME}. Exiting...'");  
            $logger->debug(__PACKAGE__ . ".$sub Exiting with retcode-0.");
            exit 0;
        }

        my $img_idx = 0;
        if ( $#{$artcfg->{GSX_IMAGE_VERSIONS}} > 0 )
        {
            $img_idx = $_;
        }

        unless ( $gsxObj->verifyImageVersion( -version => "$artcfg->{GSX_IMAGE_VERSIONS}->[$img_idx]" ))
        {
            $logger->error(__PACKAGE__ . ".$sub GSX images loaded on GSX '$gsxObj->{TMS_ALIAS_DATA}->{ALIAS_NAME}' do not match what is defined in \$artcfg->{GSX_IMAGE_VERSIONS}->[$img_idx] '$artcfg->{GSX_IMAGE_VERSIONS}->[$img_idx]'. Exiting...");  
            $logger->debug(__PACKAGE__ . ".$sub Exiting with retcode-0.");
            exit 0;
        }

        # We are assuming here that the iterator for the MGTS object matches the
        # iterator for the GSX objecta
        if (defined($testcfg->{USED_MGTS_OBJ}->[$gsx_index] )) 
        {
            if (defined($testcfg->{USED_MGTS_OBJ}->[$gsx_index]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID}))
            {
                my $mgts_no = $testcfg->{USED_MGTS_OBJ}->[$gsx_index]->{TMS_ALIAS_DATA}->{NODE}->{1}->{LAB_ID};                $logger->debug(__PACKAGE__ . ".$sub Setting GSX TCL var 'mgtsNo' to '$mgts_no' on GSX '$gsxObj->{TMS_ALIAS_DATA}->{ALIAS_NAME}'");

                $gsxObj->execCmd("set mgtsNo $mgts_no");
                # Need to check output of execCmd here
            } else {
                setSkipGrpData($skip_data_header . ", Reason:  MGTS '$testcfg->{USED_MGTS_OBJ}->[$gsx_index]->{TMS_ALIAS_DATA}->{ALIAS_NAME}' does not have a LAB_ID set in the TMS Test Bed Element Mgmt database. Please contact TMS admin."); 
                $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
                return 0;
            }
        }
  
        if (defined($artobj->{PSX}->[$gsx_index]->{TMS_ALIAS_DATA}->{ALIAS_NAME})) {
            my $psx_tcl_script = lc($artobj->{PSX}->[$gsx_index]->{TMS_ALIAS_DATA}->{ALIAS_NAME}) . "_softswitch.tcl";            $logger->debug(__PACKAGE__ . ".$sub Setting GSX TCL var 'psx_tcl' to '$psx_tcl_script' on GSX '$gsxObj->{TMS_ALIAS_DATA}->{ALIAS_NAME}'");

            $gsxObj->execCmd("set psx_tcl $psx_tcl_script;set clean_psx yes");
            # Need to check output of execCmd here
        }
  
        if (defined($testcfg->{SS7_SIG}))
        {
            my $sgx_name = lc($testcfg->{SS7_SIG});            $logger->debug(__PACKAGE__ . ".$sub Setting GSX TCL var 'sgx_version' to '$sgx_name' on GSX '$gsxObj->{TMS_ALIAS_DATA}->{ALIAS_NAME}'");

            $gsxObj->execCmd("set sgx_version $sgx_name");
            # Need to check output of execCmd here
        }
  
        if (defined($testcfg->{GSX_TCL_VARS}->{$gsx_index}))
        {
            foreach my $key (keys %{$testcfg->{GSX_TCL_VARS}->{$gsx_index}}) 
            {
                $logger->debug(__PACKAGE__ . ".$sub Adding GSX TCL Var '$key' with value '$testcfg->{GSX_TCL_VARS}->{$gsx_index}->{$key}' to GSX '$gsxObj->{TMS_ALIAS_DATA}->{ALIAS_NAME}'");
                $gsxObj->execCmd("set $key $testcfg->{GSX_TCL_VARS}->{$gsx_index}->{$key}");
                # Need to check output of execCmd here
            }
        } else {
            $logger->debug(__PACKAGE__ . ".$sub No GSX TCL Vars specified via \$testcfg->{GSX_TCL_VARS} in test grp config file '$testcfg->{TEST_GRP}'");
        }
 
        unless ($testcfg->{GSX_TCL_SCRIPTS}->[$gsx_index]) {
            setSkipGrpData($skip_data_header . ", Reason: No GSX TCL Script is specified for GSX '$gsxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}'  (index=$gsx_index in \$testcfg->{GSX_TCL_SCRIPTS})" . Dumper($testcfg));
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        } 

        $logger->debug(__PACKAGE__ . ".$sub \n\n\n\n***DEBUG**** NOTE source GSX TCL FILE  DISABLED for testing\n\n\n\n\n");
        unless ( $gsxObj->sourceGsxTclFile( -tcl_file     => "$testcfg->{GSX_TCL_SCRIPTS}->[$gsx_index]",
                                            -location     => "/sonus/SonusNFS/C",
                                           -gsx_hostname => $gsxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME},
                                            -nfs_mount    => "/sonus/SonusNFS",
                                          ))
        {
            setSkipGrpData($skip_data_header . ", Reason: Failed to source GSX TCL file '$testcfg->{GSX_TCL_SCRIPTS}->[$gsx_index]' on GSX '$gsxObj->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}' (index=$gsx_index in \$testcfg->{GSX_TCL_SCRIPTS})");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }       

        # Ensure the following GSX debug commands are set
        $gsxObj->execCmd("debugindicator 1");
        $gsxObj->execCmd("ds diameter enable");
        $gsxObj->execCmd("sipfesetprintpdu on");
    }

    foreach my $gsx_index (@gsx_reset_array) 
    {
        unless ($artobj->{GSX}->[$gsx_index]->getGsxConfigFromTG())
        {
            setSkipGrpData($skip_data_header . ", Reason: Unable to get GSX Configuration From Trunk Group data.");
            $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-0.");
            return 0;
        }
        
        foreach my $sgx_aoa (@{$artobj->{SGX}->[$gsx_index]})
        {

            my $ce0 = $sgx_aoa[0];
            my $ce1 = $sgx_aoa[1];

            if (defined($ce0))
            {
                $ce0->DESTROY();
            }
            else
            {
                # what do we do here?
            }
            
            if (defined($ce1))
            {
                $ce1->DESTROY();
            }
            else
            {
                # what do we do here?
            }            
        }

        # Get list (array) of current SGX CEs assigned to a node on the GSX
        # $artobj->{GSX}->[$gsx_index]->{TG_CONFIG}->{<tg_name>}->{SS7_NODE}->{<ss7_node_name>}->{GATEWAYS}->{<gw_name>} = [<ce0>,<ce1>]; 
        # TBD
    }
   
    if (defined($testcfg->{SS7_SIG}) && $testcfg->{SS7_SIG} eq "F-LINK") {
    	$logger->debug(__PACKAGE__ . ".$sub Waiting 70 seconds for F-LINK MTP3 proving to occur before checking circuit status");
	sleep(70);
    } else {				
    	$logger->debug(__PACKAGE__ . ".$sub Waiting 5 seconds for SGX registration to occur before checking circuit status");
	sleep(5);
    }
		
    # START OF CHECK CIRCUITS/CHANNELS
    $logger->debug(__PACKAGE__ . ".$sub Start of check circuits/channels");
    my @cleanupRebootStatus;
    my $cleanup_required;

    foreach my $gsxOb ( @{$artobj->{GSX}} )
    {
        $logger->debug(__PACKAGE__ . ".$sub Checking whether cleanup or reboot required for GSX '$gsxOb->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}'.");
        my $cleanRebootStat = $gsxOb->isCleanupOrRebootRequired();
        push(@cleanupRebootStatus, $cleanRebootStat);

        if ($cleanRebootStat == 1)
        {
            $cleanup_required = 1;
        }
    }

    my (%execTestArgs);
    tie %execTestArgs, 'Tie::DxHash', [LIST];
    %execTestArgs = ();
    
    if ($cleanup_required)
    {

        $logger->debug(__PACKAGE__ . ".$sub Cleanup required. Identifying MGTS cleanup states.");
        my $mgtsIndex = 0;
        foreach my $mgtsOb ( @{$testcfg->{USED_MGTS_OBJ}} )
        {
            $logger->debug(__PACKAGE__ . ".$sub Identifying MGTS cleanup states for '$mgtsOb->{TMS_ALIAS_DATA}->{ALIAS_NAME}'");
            unless (defined($mgtsOb->{CLEANUP})) 
            {
                #setSkipGrpData("${skip_data_header}, Reason: No CLEANUP variable assigned to MGTS object  " .
                #               "data for MGTS - $mgtsOb->{TMS_ALIAS_DATA}->{ALIAS_NAME}.");  
                $logger->error(__PACKAGE__ . ".$sub no cleanup variable assigned to MGTS object!");
                return 0;
              
            }
            foreach my $cleanupNode ( keys %{$mgtsOb->{CLEANUP}} )
            {
                chomp($cleanupNode);
                
                if ( defined($cleanupNode) )
                {
                    my $cleanupStateName = $mgtsOb->{CLEANUP}->{$cleanupNode}->{MACHINE};
                    #my $cleanupLogFile = "CLEANUP_" . $testcfg->{TEST_GRP} . "_" . ${cleanupNode} . "_" .${cleanupStateName}. "\.log";
                    my $mgtsOptionNum = $mgtsIndex + 1;
                    $logger->debug(__PACKAGE__ . ".$sub Adding MGTS <node:cleanup_state> '$cleanupNode:$cleanupStateName' to execTestArgs hash");
                    $execTestArgs{"-mgts${mgtsOptionNum}"} = $cleanupNode . ":" . $cleanupStateName;
                    $logger->debug(__PACKAGE__ . ".$sub Added MGTS <node:cleanup_state> '$cleanupNode:$cleanupStateName' to execTestArgs hash");
                }
                else
                {
                    setSkipGrpData("${skip_data_header}, Reason: Unable to find cleanup state-mc " .
                                   "data for MGTS - $mgtsOb->{TMS_ALIAS_DATA}->{ALIAS_NAME}.");  
                    return 0;
                }
            }
            $mgtsIndex++;
        }
    }

    my $gsxObjIndex = 0;
    my $cicsNonIdleAfterTestFound = 0;

    foreach my $tmpStatus ( @cleanupRebootStatus )
    {
        chomp($tmpStatus);
        $logger->debug(__PACKAGE__ . ".$sub Looping through \@cleanupRebootStatus array - Staus = '$tmpStatus'");
        my $gsxOptionNum = $gsxObjIndex + 1;
        
        if ( $tmpStatus == 2 || $tmpStatus == 1 )
        {
            $cicsNonIdleAfterTestFound = 1;
            my $date = localtime;
            $date =~ tr/ : /_/;

            # write cleanup array to a file
            my $dumpFileName = $artcfg->{USER_LOG_DIR} . "CLEANUP_REASON_setupTestGrpCfg_" . $testcfg->{TEST_GRP} . "_$date"."\.dump";
            $logger->debug(__PACKAGE__ . ".$sub Opening file '$dumpFileName' to record CLEANUP REASON");
            open (DUMPFILE, ">$dumpFileName");
            print DUMPFILE Dumper( $artobj->{GSX}->[$gsxObjIndex]->{CLEANUP_REASON} );
            close (DUMPFILE); 
            $logger->debug(__PACKAGE__ . ".$sub CLEANUP file '$dumpFileName' closed");
        }

        if ( $tmpStatus == 2 )
        {
            setSkipGrpData("${skip_data_header}, Reason: Reboot required on GSX '$artobj->{GSX}->[$gsxObjIndex]->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}', identified by isCleanupRebootRequired().");
        }
        elsif ( $tmpStatus == 1 )
        {
            foreach my $cleanArr ( @{$artobj->{GSX}->[$gsxObjIndex]->{CIC_CLEANUP_ARRAY}} )
            {
                # Format of $cleanArr = '<ISUP|BT>,<service grp name>,<cic number>'
                my ($serviceType, $serviceGrp, $cic) = split /,/, $cleanArr;

                $logger->debug(__PACKAGE__.".$sub extracted $serviceType, $serviceGrp, $cic.");

                print Dumper $artobj->{GSX}->[$gsxObjIndex]->{CICSTATE}->{$serviceType . ','. $serviceGrp};
                my $cicStatusHash = $artobj->{GSX}->[$gsxObjIndex]->{CICSTATE}->{$serviceType . ',' . $serviceGrp}->[$cic];
                #print "CicStateHash = \n" . Dumper($cicStatusHash); 

                if ( $cicStatusHash->{STATUS} =~ /N\/A/i )
                {
                    $logger->debug(__PACKAGE__ . ".$sub Adding args to execTestArgs hash");
                    $execTestArgs{"-gsx${gsxOptionNum}"} = "CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic STATE ENABLED";
                    $logger->debug(__PACKAGE__ . ".$sub Added -gsx${gsxOptionNum} => \"CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic STATE ENABLED\" to execTestArgs hash");
                    $execTestArgs{"-gsx${gsxOptionNum}"} = "CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic MODE UNBLOCK";
                    $logger->debug(__PACKAGE__ . ".$sub Added -gsx${gsxOptionNum} => \"CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic MODE UNBLOCK\" to execTestArgs hash");
                }
                else
                {
                    $logger->debug(__PACKAGE__ . ".$sub Adding args to execTestArgs hash");
                    $execTestArgs{"-gsx${gsxOptionNum}"} = "CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic MODE BLOCK";
                    $logger->debug(__PACKAGE__ . ".$sub Added -gsx${gsxOptionNum} => \"CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic MODE BLOCK\" to execTestArgs hash");
                    $execTestArgs{"-gsx${gsxOptionNum}"} = "CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic STATE DISABLED";
                    $logger->debug(__PACKAGE__ . ".$sub Added -gsx${gsxOptionNum} => \"CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic STATE DISABLED\" to execTestArgs hash");
                    $execTestArgs{"-gsx${gsxOptionNum}"} = "CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic STATE ENABLED";
                    $logger->debug(__PACKAGE__ . ".$sub Added -gsx${gsxOptionNum} => \"CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic STATE ENABLED\" to execTestArgs hash");
                    $execTestArgs{"-gsx${gsxOptionNum}"} = "CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic MODE UNBLOCK";
                    $logger->debug(__PACKAGE__ . ".$sub Added -gsx${gsxOptionNum} => \"CONFIGURE $serviceType CIRCUIT SERVICE $serviceGrp CIC $cic MODE UNBLOCK\" to execTestArgs hash");
                }
            }

            foreach my $chancleanArr ( @{$artobj->{GSX}->[$gsxObjIndex]->{CHAN_CLEANUP_ARRAY}} )
            {
                # Format of $chancleanArr = '<service grp name>,<chan number>'
                my ($serviceGrp, $chan) = split /,/, $chancleanArr;
                $logger->debug(__PACKAGE__.".$sub cleaning up servicegroup/channel - $serviceGrp/$chan.");
                $execTestArgs{"-gsx${gsxOptionNum}"} = "CONFIGURE ISDN BCHANNEL SERVICE $serviceGrp INTERFACE 0 BCHANNEL $chan STATE DISABLED";
                $logger->debug(__PACKAGE__ . ".$sub Added -gsx${gsxOptionNum} => \"CONFIGURE ISDN BCHANNEL SERVICE $serviceGrp INTERFACE 0 BCHANNEL $chan STATE DISABLED\" to execTestArgs hash");
                $execTestArgs{"-gsx${gsxOptionNum}"} = "CONFIGURE ISDN BCHANNEL SERVICE $serviceGrp INTERFACE 0 BCHANNEL $chan STATE ENABLED";
                $logger->debug(__PACKAGE__ . ".$sub Added -gsx${gsxOptionNum} => \"CONFIGURE ISDN BCHANNEL SERVICE $serviceGrp INTERFACE 0 BCHANNEL $chan STATE ENABLED\" to execTestArgs hash");
            }

          
            $logger->debug(__PACKAGE__.".$sub Starting execTest for cleanup.");
            unless (execTest(-testid => "cleanup", %execTestArgs, -skip_cic_check => 1)) 
            {
                setSkipGrpData("${skip_data_header}, Reason: Problem executing execTest() function for cleanup. Setting RESET_NODE flag to 1.");
                $artobj->{GSX}->[$gsxObjIndex]->{RESET_NODE} = 1;
            }

            my $cleanupReq = 0;
            $cleanRebootStat = $artobj->{GSX}->[$gsxObjIndex]->isCleanupOrRebootRequired();

            if ( $cleanRebootStat == 1 ) { $cleanupReq = 1; }

            $cicsNonIdleAfterCleanupFound = 0;

            if ( $cleanRebootStat == 1 || $cleanRebootStat == 2 )
            {
                $cicsNonIdleAfterCleanupFound = 1;
                my $date = localtime;
                $date =~ tr/ : /_/;

                # write cleanup array to a file
                my $dumpFileName = $artcfg->{USER_LOG_DIR} . "CLEANUP_REASON_RECHECK_setupTestGrpCfg_" . $testcfg->{TEST_GRP} . "_$date"."\.dump";
                open (DUMPFILE, ">$dumpFileName");
                print DUMPFILE Dumper( $artobj->{GSX}->[$gsxObjIndex]->{CLEANUP_REASON} );
                close (DUMPFILE); 
            }

            if ( $cleanRebootStat == 2 )
            {
                setSkipGrpData("${skip_data_header}, Reason: Reboot required, after attempt to cleanup circuits/channels.");
            }
            elsif ( $cleanRebootStat == 1 )
            {
                setSkipGrpData("${skip_data_header}, Reason: Failed to cleanup circuits/channels.");
                #$artobj->{GSX}->[$gsxObjIndex]->{RESET_NODE} = 1;
            }
            else
            {
                $logger->debug(__PACKAGE__.".$sub circuits/channels cleared successfully.");
            }
        }
        else
        {
            $logger->debug(__PACKAGE__.".$sub all circuits/channels are IDLE, no cleanup or reboot required");
        }
        $gsxObjIndex++;
    }

    $logger->debug(__PACKAGE__ . ".$sub End of check circuits/channels");
    # END OF CHECK CIRCUITS/CHANNELS
    
    # START OF STOP-LOGGING
    $logger->debug(__PACKAGE__ . ".$sub Start of stop logging");
    foreach my $gsxObjRef ( @{$artobj->{GSX}} )
    {
        if (exists($gsxObjRef->{GSX_LOG_INFO}->{PID})) {
            my $procList = $gsxObjRef->{GSX_LOG_INFO}->{PID}->{ACT} . "," . 
                           $gsxObjRef->{GSX_LOG_INFO}->{PID}->{DBG} . "," . 
                           $gsxObjRef->{GSX_LOG_INFO}->{PID}->{SYS} . "," . 
                           $gsxObjRef->{GSX_LOG_INFO}->{PID}->{TRC}; 
            $logger->debug(__PACKAGE__ . ".$sub stopping logging on GSX \"$gsxObjRef->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}\" procList-$procList.");
            if ( $gsxObjRef->gsxLogStop( -process_list => $procList ) != 1 )
            {
                setSkipGrpData("${skip_data_header}, Reason: Failed to stop logging ".
                              "on GSX \"$gsxObjRef->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}\"."); 
                return 0;
            } else {
                delete($gsxObjRef->{GSX_LOG_INFO}->{PID});
            }
        }
        
        if ($gsxObjRef->gsxCoreCheck(-host_name => "",
                                     -test_case => "$gsxObjRef->{TMS_ALIAS_DATA}->{NODE}->{1}->{NAME}" . "_setupTestGrpCfg"))
        {
            #foreach 
            #{
            #    print;
            #}
        }
    }

    $logger->debug(__PACKAGE__ . ".$sub End of stop logging");
    # END OF STOP-LOGGING
    
    $logger->debug(__PACKAGE__ . ".$sub leaving with retcode-1.");
    return 1;
}

=head1 B<getFlavorFromLocalSeqGrp()>

  This subroutine takes the sequence group file as the input and returns the sequence flavor.

=over 6

=item Arguments:

 -seqgrp

=item Package:

 SonusQA::GSX::ART

=item Return:

 $seq_flavor if exists else 0

=back

=cut

sub getFlavorFromLocalSeqGrp
{
    my (%args) = @_;
    my $sub = "getFlavorFromLocalSeqGrp()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    $logger->debug("Entered $sub.");
    
    unless ($args{-seqgrp})
    {
        $logger->error(__PACKAGE__ . ".$sub Mandatory '-seqgrp' option not specified or is blank");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
        return 0;    
    }
 
    my $seqgrp = $args{-seqgrp};
    
    # Ensure the specified sequence group exists and is readable
    unless (-r $seqgrp)
    {
        $logger->error(__PACKAGE__ . ".$sub Specified sequence group file \"$seqgrp\" does not exist or is not readable on ATS server.");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
        return 0;
    }
    
    my @grep_flavor_result;
    unless ( @grep_flavor_result = qx{ grep "FLAVOR=" ${seqgrp} } )
    {
        $logger->error(__PACKAGE__ . ".$sub Failed to get 'FLAVOR' from '$seqgrp': @grep_flavor_result");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
        return 0;
    }
    
    # Find FLAVOR in sequence group file grp output
    my $seq_flavor = "";
    my $grep_result_string = join('',@grep_flavor_result);
    if ( $grep_result_string =~ /FLAVOR=(.*)/ )
    {
        $seq_flavor = "$1";
        if ($seq_flavor =~ /^\s*$/)
        {
            $logger->error(__PACKAGE__ . ".$sub Found flavor is blank in sequence group '$seqgrp'");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0;
        }
        $logger->debug(__PACKAGE__ . ".$sub Flavor of seqgrp '$seqgrp' is '$seq_flavor'");
    }
    else
    {   
        $logger->error(__PACKAGE__ . ".$sub Sequence group '$seqgrp' does not contain a flavor line");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
        return 0;
    }
    
    return $seq_flavor;
}

=head1 B<getProtocolFromMgtsFlavor()>
   
  This subrotine take the MGTS flavor as the input and returns the proocol.

=over 6

=item Arguments:

 -flavor

=item Package:

 SonusQA::GSX::ART

=item Return:

 $protocol_string

=back

=cut

sub getProtocolFromMgtsFlavor
{
    my (%args) = @_;
    my $sub = "getProtocolFromMgtsFlavor()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    $logger->debug("Entered $sub.");
    
    unless ($args{-flavor})
    {
        $logger->error(__PACKAGE__ . ".$sub Mandatory '-flavor' option not specified or is blank");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
        return 0;    
    }
    
    my $protocol_string = "";
    my $seq_flavor = $args{-flavor};
    
    if ( $seq_flavor eq "ANSI-SS7" || $seq_flavor eq "ATT-SS7" )
    {
        $protocol_string = "ANSI";
    }
    elsif ( $seq_flavor eq "CCITT-SS7" || $seq_flavor eq "WHITE-SS7" || $seq_flavor eq "UK-SS7" )
    {
       $protocol_string = "ITU";
    }
    elsif ( $seq_flavor eq "PNOISC-SS7" )
    {
        $protocol_string = "BT";
    }
    elsif ( $seq_flavor eq "JAPAN-SS7" )
    {
        $protocol_string = "JAPAN";
    }
    elsif ( $seq_flavor eq "CHINA-SS7" )
    {
        $protocol_string = "CHINA";
    }
    elsif ( $seq_flavor eq "Q931" || $seq_flavor1 eq "NATISDN2P"  )
    {
        $protocol_string = "ISDN";
    }
    else
    {
        $logger->error(__PACKAGE__ . ".$sub Specified MGTS Flavor '$seq_flavor' unrecognised");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
        return 0;
    }
    
    return $protocol_string;
}

=head1 B<getProtocolFromProtId()>

  This subroutine is used to obtain the protocol using the protocol id as the input.

=over 6

=item Arguments:

 -prot_id

=item Package:

 SonusQA::GSX::ART

=item Return:

 $protocol

=back

=cut

sub getProtocolFromProtId
{
    my (%args) = @_;
    my $sub = "getProtocolFromProtId()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    $logger->debug("Entered $sub.");
     
    unless ($args{-prot_id})
    {
        $logger->error(__PACKAGE__ . ".$sub Mandatory '-prot_id' option not specified or is blank");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with empty string.");
        return "";    
    }

    my $prot_id = $args{-prot_id};
    my $protocol;
    
    if ($prot_id =~ m/^u(k*)/i || $prot_id =~ m/^i(t*)/i ) 
    {
        $protocol = "ITU";
    } 
    elsif ($prot_id =~  m/^a(n*)/i) 
    {
        $protocol = "ANSI";
    } 
    elsif ($prot_id =~  m/^c(h*)/i) 
    {
        $protocol = "CHINA";
    } 
    elsif ($prot_id =~  m/^j([ap]*)/i) 
    {
        $protocol = "JAPAN";
    }
    elsif ($prot_id =~  m/^b([t]*)/i) 
    {
        $protocol = "BT";
    } 
    else 
    {
        $protocol = "";
    }
    return $protocol;
}

=pod

=head1 B<generateTestGrpFile()>

    This function generates a test group configuration file (name specified by
    -output_file option) based off a template specified by -template option and
    substituting variable values depending on the type of testing (SIP <--> MGTS
    or MGTS <--> MGTS).
    The template to be used for this function will be based on the test group
    configuration file defined in Section 2.1.6.2 "Format of Test Group
    configuration file" of the ART to ATS dessign document and will have
    patterns to identify where to define specific variables. These patterns are
    as follows:
    #+#TEST_GRP#+# - susbtitute with name of test group config file	
    #+#REQ_MGTS#+# - substitute with full $testcfg->{REQ_MGTS} definition.	
    #+#MGTS_ASSIGN#+# - substitute with full $testcfg->{MGTS_ASSIGNMENTS} definition.	
    #+#MGTS_SEQGRPS#+# - substitute with full $testcfg->{MGTS_SEQGRPS} definition.	
    #+#REQ_GBL#+# - substitute with full $testcfg->{REQ_GBL} definition.
    #+#GBL_PATH#+# - substitute with full $testcfg->{REQ_GBL} definition. 	
    #+#TEST_CASES#+# - substitute with execTest, execPsxControl function calls

=over 6

=item Arguments :

 For single MGTS testing (ISUP/IUP/ISDN) the following argument is mandatory:
	-seqgrp        => </path/sequence group>
 For GBL MGTS testing (SIP ISUP/IUP/ISDN) the following three arguments are mandatory:
	-seqgrp        => </path/sequence group>
	-sip_direction => <calling|called>
	-gbl_path      => <full path to GBL files on server>
 For MGTS MGTS testing (ISUP/IUP/ISDN ISUP/IUP/ISDN) the following two arguments are mandatory:
        -seqgrp_calling => </path/sequence_group>
        -seqgrp_called  => </path/sequence_group>
 Mandatory arguments in ALL instances:
	-template    => </path/template_filename>
	-output_file => </path/output_filename>
        -mgts_obj_ref => Reference to MGTS object

=item Output:

 Test group variables are defined in test group configuration file output.

=item Return Values :

 1 . on success
 0 . otherwise (with $testcfg->{SKIP_GROUP} being set)

=item Example :

 generateTestGrpFile()

=item Author :

 Hefin Hamblin 
 hhamblin@sonusnet.com

=back

=cut

sub generateTestGrpFile
{
    my (%args) = @_;
    my $sub = "generateTestGrpFile()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    
    my ($seqgrp1, $seqgrp2, $seqgrp1_path, $seqgrp2_path, $seqgrp1_name, $seqgrp2_name);
    my ($gbl_path,$sip_direction);
    my $ignore_pod = 0;
    
    $logger->debug("Entered $sub.");
    
    foreach ( qw/ -template -output_file -mgts_obj_ref/ )
    {
        unless ($args{$_})
        {
            $logger->error(__PACKAGE__ . ".$sub Mandatory \"$_\" parameter not provided or is blank");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0;
        }
    }

    if ((defined($args{-ignore_pod})) && ($args{-ignore_pod} == 1))
    {
        $ignore_pod = 1;
    }
    
    my $templateFile = $args{-template};
    my $outputFile = $args{-output_file};
    my $outputFilename = "";
    my $outputFilePath = "";
    
    if ($outputFile =~ m/^(.*)\/(.*)$/ ) 
    {
        $outputFilePath = $1;
        $outputFilename = $2;
    }
    
    unless ($outputFilePath eq "")
    {
        unless (-d $outputFilePath)
        {
            if ( system("mkdir -p $outputFilePath" ))
            {
                $logger->error(__PACKAGE__ . ".$sub Failed to create directory '$outputFilePath' for output file");
                $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
                return 0;    
            }
            else
            {
                $logger->debug(__PACKAGE__ . ".$sub Created directory '$outputFilePath' for output file");                
            }
        }
    }
    
    # Ensure the specified template file exists and is readable
    unless (-r $templateFile)
    {
        $logger->error(__PACKAGE__ . ".$sub Specified '-template' test group config file '$templateFile' does not exist or is not readable on ATS server.");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
        return 0;
    }
        
    # Ensure the specified output file can be 'touch'ed
    if (system( "touch $outputFile")) {
        $logger->error(__PACKAGE__ . ".$sub Failed to touch specified '-output_file' test group config file '$outputFile'");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
        return 0;   
    }
    
    unless (-w $outputFile)
    {
        $logger->error(__PACKAGE__ . ".$sub Specified '-output_file' test group config file '$outputFile' is not writable.");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
        return 0;
    }

        
    if ($args{-seqgrp})
    {
        $seqgrp1 = $args{-seqgrp};
        
        if ($args{-seqgrp_calling} || $args{-seqgrp_called})
        {
            $logger->error(__PACKAGE__ . ".$sub \"-seqgrp_calling\" or \"-seqgrp_called\" options are invalid with the \"-seqgrp\" option");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0;    
        }
    
        # Ensure the specified sequence group exists and is readable
        unless (-r $seqgrp1)
        {
            $logger->error(__PACKAGE__ . ".$sub Specified sequence group file \"$seqgrp1\" does not exist or is not readable on ATS server.");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0;
        }
            
        unless ($seqgrp1=~ m/(^.*\/)(.*)\.sequenceGroup/ )
        {
            $logger->error(__PACKAGE__ . ".$sub Ensure full path is specified for the sequence group");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0;  
        } else {
            $seqgrp1_path = $1; 
            $seqgrp1_name = $2;
        } 
        
        unless ($seq_flavor1 = getFlavorFromLocalSeqGrp(-seqgrp => $seqgrp1))
        {
            $logger->error(__PACKAGE__ . ".$sub Problem obtaining flavor from MGTS sequence group '$seqgrp1'");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0; 
        }
        
        unless ($protocol_string1 = getProtocolFromMgtsFlavor(-flavor => $seq_flavor1))
        {
            $logger->error(__PACKAGE__ . ".$sub Problem obtaining protocol string from MGTS sequence group flavor '$seq_flavor1'");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0; 
        }
                        

        $eg_protocol = $protocol_string1;
        
        if ($args{-sip_direction} || $args{-gbl_path})
        {
            unless ( $args{-sip_direction} && $args{-gbl_path} ) 
            {
                $logger->error(__PACKAGE__ . ".$sub Both \"-sip_direction\" and \"-gbl_path\" must be provided together and not be blank");
                $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
                return 0;    
            }
            
            unless ( $args{-sip_direction} =~ /^calling$/i || $args{-sip_direction} =~ /^called$/i )
            {
                $logger->error(__PACKAGE__ . ".$sub \"-sip_direction\" option value must be either \"called\" or \"calling\".");
                $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
                return 0;    
            }
            
            $gbl_path = $args{-gbl_path};
            $sip_direction = lc($args{-sip_direction});
            
            # Check if $gbl_path directory exists
            unless (-d $gbl_path)
            {
                $logger->error(__PACKAGE__ . ".$sub Specified GBL file path \"$gbl_path\" does not exist on ATS server.");
                $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
                return 0;
            }
            
            if ( $sip_direction eq "called" )
            {
                $eg_protocol = "SIP" . $protocol_string1;   
            }
        }
        else
        {
            # We assume we are a single sequence group with no interworking
            # Need to check that no other options are specified.
            $logger->debug(__PACKAGE__ . ".$sub Assuming single seqgrp");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
        }  
    }
    elsif ( $args{-seqgrp_calling} && $args{-seqgrp_called} ) 
    {
        $seqgrp1 = $args{-seqgrp_calling};
        $seqgrp2 = $args{-seqgrp_called};
        
        unless ($seqgrp1=~ m/(^.*\/)(.*)\.sequenceGroup/ )
        {
            $logger->error(__PACKAGE__ . ".$sub Ensure full path is specified for the sequence group specified by '-seqgrp_calling' option");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0;  
        } else {
            $seqgrp1_path = $1;
            $seqgrp1_name = $2;

        }
        
        unless ($seqgrp2=~ m/(^.*\/)(.*)\.sequenceGroup/ )
        {
            $logger->error(__PACKAGE__ . ".$sub Ensure full path is specified for the sequence group specified by '-seqgrp_called' option");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0;  
        } else {
            $seqgrp2_path = $1;
            $seqgrp2_name = $2;
        }
        
        # Ensure the specified sequence group exists and is readable
        unless (-r $seqgrp1)
        {
            $logger->error(__PACKAGE__ . ".$sub Specified '-seqgrp_calling' sequence group file \"$seqgrp1\" does not exist or is not readable on ATS server.");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0;
        }
        
        # Ensure the specified sequence group exists and is readable
        unless (-r $seqgrp2)
        {
            $logger->error(__PACKAGE__ . ".$sub Specified '-seqgrp_called' sequence group file \"$seqgrp2\" does not exist or is not readable on ATS server.");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0;
        }
        
        unless ($seq_flavor1 = getFlavorFromLocalSeqGrp(-seqgrp => $seqgrp1))
        {
            $logger->error(__PACKAGE__ . ".$sub Problem obtaining flavor from MGTS sequence group '$seqgrp1'");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0; 
        }
        
        unless ($protocol_string1 = getProtocolFromMgtsFlavor(-flavor => $seq_flavor1))
        {
            $logger->error(__PACKAGE__ . ".$sub Problem obtaining protocol string from MGTS sequence group flavor '$seq_flavor1'");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0; 
        }
        
        unless ($seq_flavor2 = getFlavorFromLocalSeqGrp(-seqgrp => $seqgrp2))
        {
            $logger->error(__PACKAGE__ . ".$sub Problem obtaining flavor from MGTS sequence group '$seqgrp2'");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0; 
        }
        
        unless ($protocol_string2 = getProtocolFromMgtsFlavor(-flavor => $seq_flavor2))
        {
            $logger->error(__PACKAGE__ . ".$sub Problem obtaining protocol string from MGTS sequence group flavor '$seq_flavor2'");
            $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
            return 0; 
        }
        
        $eg_protocol = $protocol_string2;
        
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
    }
    else
    {
        $logger->error(__PACKAGE__ . ".$sub Invalid arguments specified.");
        $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-0.");
        return 0;    
    }


    my $tmpMgtsObjRef = $args{-mgts_obj_ref};
   
    open (TEMPLATE_FILE, "$templateFile") or die $!;
    open (OUTPUT_TESTGRP_FILE, ">$outputFile") or die $!;
    my $in_pod = 0;
    my $error_found=0;
 
    my $state1_timeout = 0;
    my $state1_timeout_string = "";
    my $state2_timeout = 0;
    my $state2_timeout_string = "";
     
    # Loop through the template line-by-line
    while (<TEMPLATE_FILE>)
    {
        chomp $_;
        my $line = $_;
	
	if ($error_found) {
	   last;	
	}
	
        if ( $line =~ /^\=pod/ )
        {
            $in_pod = 1;
        }
        elsif ( $line =~ /^\=cut/ )
        {
            $in_pod = 0;
        }
        elsif ( $line =~ /\#\+\#TEST_GRP\#\+\#/ )
        {
            $line =~ s/\#\+\#TEST_GRP\#\+\#/${outputFilename}/;
            $logger->debug(__PACKAGE__ . ".$sub '\#\+\#TEST_GRP\#\+\#' line substituted with \"${outputFilename}\"");
        }
        elsif ( $line =~ /^\#\+\#REQ_MGTS\#\+\#/ )
        {
            if (defined $seqgrp1 && defined $seqgrp2)
            {
                # We assume this is the -seqgrp_calling and -seqgrp_called version
                # i.e. 2 MGTS required for interworking
                $line =~ s/^\#\+\#REQ_MGTS\#\+\#/\$testcfg\-\>\{REQ_MGTS\} \= \[\n\t\[\@\{\$mgts_list\{${protocol_string1}_MGTS\}\}\],\n\t\[\@\{\$mgts_list\{${protocol_string2}_MGTS\}\}\]\n\]\;/;
                $logger->debug(__PACKAGE__ . ".$sub '\#\+\#REQ_MGTS\#\+\#' line substituted with \$testcfg\-\>\{REQ_MGTS\} \= \[\n\t\[\@\{\$mgts_list\{${protocol_string1}_MGTS\}\}\],\n\t\[\@i\{\$mgts_list\{${protocol_string2}_MGTS\}\}\]\n\]\;");
            }
            elsif (defined $seqgrp1)
            {
                # We assume only a single MGTS required
               $line =~ s/^\#\+\#REQ_MGTS\#\+\#/\$testcfg\-\>\{REQ_MGTS\} \= \[\n\t\[\@\{\$mgts_list\{${protocol_string1}_MGTS\}\}\]\n\]\;/;
                $logger->debug(__PACKAGE__ . ".$sub '\#\+\#REQ_MGTS\#\+\#' line substituted with \$testcfg\-\>\{REQ_MGTS\} \= \[\n\t\[\@\{\$mgts_list\{${protocol_string1}_MGTS\}\}\]\n\t\]\;");   
            }
            else
            {
                $logger->info(__PACKAGE__ . ".$sub Ignoring '\#\+\#REQ_MGTS\#\+\#' substitution because no MGTS required");
            }
        }
        elsif ( $line =~ /^\#\+\#MGTS_ASSIGN\#\+\#/ )
        {
            if (defined $seqgrp1 && defined $seqgrp2)            {
                # We assume this is the -seqgrp_calling and -seqgrp_called version
                # i.e. 2 MGTS assignments required
                $line =~ s/^\#\+\#MGTS_ASSIGN\#\+\#/\$testcfg\-\>\{MGTS_ASSIGNMENTS\} \= \[\"\#\+\#MGTS\#\+\#_${protocol_string1}_\#\+\#SS7_SIG\#\+\#\", \"\#\+\#MGTS\#\+\#_${protocol_string2}_\#\+\#SS7_SIG\#\+\#\"\]\;/;  
                $logger->debug(__PACKAGE__ . ".$sub '\#\+\#MGTS_ASSIGN\#\+\#' line substituted with \$testcfg\-\>\{MGTS_ASSIGNMENTS\} \= \[\"\#\+\#MGTS\#\+\#_${protocol_string1}_\#\+\#SS7_SIG\#\+\#\", \"\#\+\#MGTS\#\+\#_${protocol_string2}_\#\+\#SS7_SIG\#\+\#\"\]\;");
            }
            elsif (defined $seqgrp1)
            {
                # We assume only a single MGTS assignment required
                $line =~ s/^\#\+\#MGTS_ASSIGN\#\+\#/\$testcfg\-\>\{MGTS_ASSIGNMENTS\} \= \[\"\#\+\#MGTS\#\+\#_${protocol_string1}_\#\+\#SS7_SIG\#\+\#\"\]\;/;
                $logger->debug(__PACKAGE__ . ".$sub '\#\+\#MGTS_ASSIGN\#\+\#' line substituted with \$testcfg\-\>\{MGTS_ASSIGNMENTS\} \= \[\"\#\+\#MGTS\#\+\#_${protocol_string1}_\#\+\#SS7_SIG\#\+\#\"\]\;"); 
            }
            else
            {
                $logger->info(__PACKAGE__ . ".$sub Ignoring '\#\+\#MGTS_ASSIGN\#\+\#' substitution because no MGTS required");
            }
        }
        elsif ( $line =~ /^\#\+\#MGTS_SEQGRPS\#\+\#/ )
        {
            if (defined $seqgrp1 && defined $seqgrp2)
            {
                # We assume this is the -seqgrp_calling and -seqgrp_called version
                # i.e. 2 MGTS seq grps required for interworking
                $line =~ s/^\#\+\#MGTS_SEQGRPS\#\+\#/\$testcfg\-\>\{MGTS_SEQGRPS\} \= \[\n\t\[\"SSP\",\"${seqgrp1_name}\"\],\n\t\[\"SSP\",\"${seqgrp2_name}\"\]\n\]\;/;
                $logger->debug(__PACKAGE__ . ".$sub '\#\+\#MGTS_SEQGRPS\#\+\#' line substituted with \$testcfg\-\>\{MGTS_SEQGRPS\} \= \[\n\t\[\"SSP\",\"${seqgrp1_name}\"\],\n\t\[\"SSP\",\"${seqgrp2_name}\"\]\n\]\;");
            }
            elsif (defined $seqgrp1)
            {
                # We assume only a single MGTS seq grp required
                $line =~ s/^\#\+\#MGTS_SEQGRPS\#\+\#/\$testcfg\-\>\{MGTS_SEQGRPS\} \= \[\n\t\[\"SSP\",\"${seqgrp1_name}\"\]\n\]\;/;
                $logger->debug(__PACKAGE__ . ".$sub '\#\+\#MGTS_SEQGRPS\#\+\#' line substituted with \$testcfg\-\>\{MGTS_SEQGRPS\} \= \[\n\t\[\"SSP\",\"${seqgrp1_name}\"\]\n\]\;"); 
            }
            else
            {
                $logger->info(__PACKAGE__ . ".$sub Ignoring '\#\+\#MGTS_SEQGRPS\#\+\#' substitution because no MGTS required");
            }
        }
        elsif ( $line =~ /^\#\+\#REQ_GBL\#\+\#/ )
        {
            if (defined($sip_direction))
            {
                # We assume only a single GBL server is required. More can be added manually if required
                $line =~ s/^\#\+\#REQ_GBL\#\+\#/\$testcfg\-\>\{REQ_GBL\} \= \[\n\t\[\@\{\$gbl_list\{ANY_GBL\}\}\]\n\]\;/;
                $logger->debug(__PACKAGE__ . ".$sub '\#\+\#REQ_GBL\#\+\#' line substituted with \$testcfg\-\>\{REQ_GBL\} \= \[\n\t\[\@\{\$gbl_list\{ANY_GBL\}\}\]\n]\;");
            }
        }
        elsif ( $line =~ /^\#\+\#GBL_PATH\#\+\#/ )
        {
            if (defined $gbl_path) {
                # We assume all GBL tests are in the same path for a single test group config file
                $line =~ s/^\#\+\#GBL_PATH\#\+\#/\$testcfg\-\>\{GBL_TEST_PATHS\} \= \[\"${gbl_path}\"\]\;/;
                $logger->debug(__PACKAGE__ . ".$sub '\#\+\#GBL_PATH\#\+\#' line substituted with \$testcfg\-\>\{GBL_TEST_PATHS\} \= \[\"${gbl_path}\"\]\;");
            }
            else
            {
                $logger->info(__PACKAGE__ . ".$sub Ignoring '\#\+\#GBL_PATH\#\+\#' substitution because '-gbl_path' option not specified");
            }
        }
        elsif ( $line =~ /^\#\+\#EG_PROTOCOL\#\+\#/ )
        {
            if (defined $seqgrp1) {
                $line =~ s/^\#\+\#EG_PROTOCOL\#\+\#/\$testcfg\-\>\{EG_PROTOCOL\} \= \"${eg_protocol}\";/;
                $logger->debug(__PACKAGE__ . ".$sub '\#\+\#EG_PROTOCOL\#\+\#' line substituted with \$testcfg\-\>\{EG_PROTOCOL\} \= \"${eg_protocol}\"\;"); 
            }
        }
        elsif ( $line =~ /^\#\+\#TEST_CASES\#\+\#/ )
        {
            if ((defined $seqgrp1) && (! (defined $seqgrp2)))
            {
                my @seqgrp1_states = qx {grep "^STATE=States\/" $seqgrp1};
                if ($#seqgrp1_states == -1)
                {
                    $logger->error(__PACKAGE__ . ".$sub Failed to grep any state machines from sequence group '$seqgrp1'");
			
                    $error_found++;
	            last;	
                }

                my $seqgrp1_cleanup = "";
                my @cleanup_states = qx { grep "^STATE=States\/.*CLEANUP " $seqgrp1};
                if ($#cleanup_states == -1) 
                {
                    $logger->error(__PACKAGE__ . ".$sub Failed to find a 'CLEANUP' state machine in sequence group '$seqgrp1'");
                    $error_found++;
	            last;	
                } 
                elsif ($cleanup_states[0] =~ /STATE=States\/(.*CLEANUP) /)
                {
                    unless  ($seqgrp1_cleanup = $tmpMgtsObjRef->getStateDesc(-full_statename => $seqgrp1_path . "States/" . $1 . ".states")) {
                        $logger->error(__PACKAGE__ . ".$sub Failed to get state machine description for \"" . $seqgrp1_path . "States/". $1 . ".states" ."\"");
                        $error_found++;
	                last;	
                    }
                }
                else
                {
                    $logger->error(__PACKAGE__ . ".$sub Failed to extract 'CLEANUP' state machine name from '$cleanup_states[0]' in sequence group '$seqgrp1'");
                    $error_found++;
	            last;	
                }

                #Loop through sequence group 1
                my $seqgrp1_index = 0;
                foreach my $state_line (@seqgrp1_states)
                {
                    chomp $state_line;
                    my @gsx_commands;
                    if ( $state_line =~ m/STATE=States\/(.*\/)?(.+) TYPE=/ )
                    {
                        my $workgroup = "";
                        if ($1)
                        {
                            $workgroup = $1;
                            $workgroup =~ s/\/$//;
                        }
                        my $state_filename = $2;

                        if ("$workgroup" eq "PSX_CONTROLS")
                        {
                            $logger->debug(__PACKAGE__ . ".$sub Adding *PSX_CONTROL* WORKGROUP='$workgroup' STATE='$state_filename'\n");
                            print OUTPUT_TESTGRP_FILE "execPsxControl(";
                            my $psx_side = 1;
                            $psx_side = 2 if ($state_filename =~ /SS7([235])$|sigprof([235])$/);

                            @psx_commands = convertMgtsPsxControl(-psx_control => "${state_filename}", -dir_path => "${seqgrp1_path}/States/${workgroup}");
                            if ($#psx_commands != 1 ) 
                            {
                                # Error as convertMgtsPsxControl function has returned 0
                                $logger->error(__PACKAGE__ . ".$sub Failed to convert PSX Control \"${state_filename}\". Please correct in file.");
                                $error_found++;
	                        last;	
                            }
                            my $psx_cmd = $psx_commands[0];
                            my $def_psx_cmd = $psx_commands[1];
                            chomp $psx_cmd;
                            chomp $def_psx_cmd;
                            print OUTPUT_TESTGRP_FILE " -psx${psx_side}            => \"$psx_cmd\",\n";
                            print OUTPUT_TESTGRP_FILE "                -default_psx_cmd => \"$def_psx_cmd\",\n";
                            print OUTPUT_TESTGRP_FILE ");\n\n";
                        }
                        elsif ($workgroup =~ /CONTROLS/ )
                        {
                            print OUTPUT_TESTGRP_FILE "execTest( -testid => \"config_update_" . $state_filename . "\",\n";
                            my $gsx_side = 1;
                            $gsx_side = 2 if ($state_filename =~ /SS7([235])$|sigprof([235])$/);

                            @gsx_commands = convertMgtsGsxControl(-gsx_control => "${state_filename}", -dir_path => "${seqgrp1_path}/States/${workgroup}");
                            if ($#gsx_commands == 0 && (! $gsx_commands[0]) ) 
                            {
                                # Error as convertMgtsControl function has returned 0
                                $logger->error(__PACKAGE__ . ".$sub Failed to convert GSX Control \"${state_filename}\". Please correct in file.");
 
                                $error_found++;
	                        last;	
                            }
                            my $skip_cic_check = 1;
                            if ($state_filename =~ /ABLE_SIGNALING_PROFILE_sigprof|ABLE_SERVICE_GROUP_SS7|ISUP_CIRC_(EN|DIS)ABLE/) 
                            {
                                print OUTPUT_TESTGRP_FILE "          -mgts1  => \"$seqgrp1_cleanup\",\n";
                                if (($state_filename =~ /ENABLE/) && 
                                    (defined($seqgrp1_states[$seqgrp1_index+1])) && 
                                    ($seqgrp1_states[$seqgrp1_index+1] =~ /\/[1-9][0-9]* |PSX_CONTROLS/))
                                {
                                   $skip_cic_check = 0;
                                }
                            }
                            foreach my $cmd (@gsx_commands)
                            {
                                chomp $cmd;
                                print OUTPUT_TESTGRP_FILE "          -gsx${gsx_side}   => \"$cmd\",\n";
                            }
                            if ($skip_cic_check)
                            {
                                print OUTPUT_TESTGRP_FILE "          -skip_cic_check => 1,\n";
                            }
                            print OUTPUT_TESTGRP_FILE ");\n\n";
                        }
                        elsif ($state_filename =~ /CLEANUP|AUTORESPONDER/  )
                        {
                            $logger->debug(__PACKAGE__ . ".$sub Found and ignoring CLEANUP WORKGROUP='$workgroup' STATE='$state_filename'\n");
                        }
                        elsif ($state_filename =~ /^[1-9][0-9]*$/ )
                        {
                            my $state_description; 
                            unless  ($state_description = $tmpMgtsObjRef->getStateDesc(-full_statename => $seqgrp1_path . "States/" . $workgroup . "/" . $state_filename . ".states")) {
                                $logger->error(__PACKAGE__ . ".$sub Failed to get state machine description for \"" . $seqgrp1_path . $workgroup . "/" . $state_filename ."\"");
                                $error_found++;
	                        last;	
                            }
                            $state1_timeout = $tmpMgtsObjRef->getStateTotalTime(-full_statename => $seqgrp1_path . "States/" . $workgroup . "/" . $state_filename . ".states");
                            if ($state1_timeout > 60) {
                                  $state1_timeout_string = "          -timeout     => $state1_timeout,\n";
                            } else {
                                  $state1_timeout_string = "";
                            }
                            if (defined $sip_direction)
                            {
                                if ($sip_direction eq "called")
                                {
                                    print OUTPUT_TESTGRP_FILE "execTest( -testid      => \"${state_filename}\",\n          -feature     => \"\$feature\",\n          -requirement => \"\$requirement\",\n          -gbl1        => \"UK${state_filename}_Called.gbl\",\n          -mgts1       => \"${state_description}\",\n${state1_timeout_string});\n\n";
                                }
                                elsif ($sip_direction eq "calling")
                                {        
                                    print OUTPUT_TESTGRP_FILE "execTest( -testid      => \"${state_filename}\",\n          -feature     => \"\$feature \",\n          -requirement => \"\$requirement\",\n          -mgts1       => \"${state_description}\",\n          -gbl1        => \"UK${state_filename}_Calling.gbl\",\n${state1_timeout_string});\n\n";
                                }
                            }
                            else
                            {
                               # $sip_direction not defined so assuming we are a single MGTS sequence group
                               $logger->debug(__PACKAGE__ . ".$sub Adding *TEST* WORKGROUP='$workgroup' STATE='$state_filename'\n");
                               print OUTPUT_TESTGRP_FILE "execTest( -testid      => \"${state_filename}\",\n          -feature     => \"\$feature \",\n          -requirement => \"\$requirement\",\n          -mgts1       => \"${state_description}\",\n${state1_timeout_string});\n\n";
                            }
                        }
                        else 
                        {
                            $logger->error(__PACKAGE__ . ".$sub Invalid state machine id in sequence group '$seqgrp1'. SM_ID=\"$workgroup/$state_filename\"");
                            $error_found++;
	                    last;	
                        }
                    }
                    else
                    {
                        $logger->error(__PACKAGE__ . ".$sub Invalid line in sequence group '$seqgrp1' Line\#${seqgrp1_index}=\"$state_line\"\n");
                        $error_found++;
	                last;	
                    }
                    $seqgrp1_index++;
                }
            }
            elsif ((defined $seqgrp1) && (defined $seqgrp2))
            {
                my @seqgrp1_states = qx {grep "^STATE=States\/" $seqgrp1};
                if ($#seqgrp1_states == -1)
                {
                    $logger->error(__PACKAGE__ . ".$sub Failed to grep any state machines from sequence group '$seqgrp1'");
                    $error_found++;
	            last;	
                }
                my $seqgrp1_cleanup = "";
                my @cleanup_states = qx { grep "^STATE=States\/.*CLEANUP " $seqgrp1};
                if ($#cleanup_states == -1) 
                {
                    $logger->error(__PACKAGE__ . ".$sub Failed to find a 'CLEANUP' state machine in sequence group '$seqgrp1'");
                    $error_found++;
	            last;	
                } 
                elsif ($cleanup_states[0] =~ /STATE=States\/(.*CLEANUP) /)
                {
                    unless  ($seqgrp1_cleanup = $tmpMgtsObjRef->getStateDesc(-full_statename => $seqgrp1_path . "States/" . $1 . ".states")) {
                        $logger->error(__PACKAGE__ . ".$sub Failed to get state machine description for \"" . $seqgrp1_path . "States/". $1 . ".states" ."\"");
                        $error_found++;
	                last;	
                    }
                }
                else
                {
                    $logger->error(__PACKAGE__ . ".$sub Failed to extract 'CLEANUP' state machine name from '$cleanup_states[0]' in sequence group '$seqgrp1'");
                    $error_found++;
	            last;	
                }
                
                my @seqgrp2_states = qx {grep "^STATE=States\/" $seqgrp2};
                if ($#seqgrp2_states == -1)
                {
                    $logger->error(__PACKAGE__ . ".$sub Failed to grep any state machines from sequence group '$seqgrp2'");
                    $error_found++;
	            last;	
                }
                my $seqgrp2_cleanup = "";
                @cleanup_states = qx { grep "^STATE=States\/.*CLEANUP " $seqgrp2};
                if ($#cleanup_states == -1) 
                {
                    $logger->error(__PACKAGE__ . ".$sub Failed to find a 'CLEANUP' state machine in sequence group '$seqgrp2'");
                    $error_found++;
	            last;	
                } 
                elsif ($cleanup_states[0] =~ /STATE=States\/(.*CLEANUP) /)
                {
                    unless  ($seqgrp2_cleanup = $tmpMgtsObjRef->getStateDesc(-full_statename => $seqgrp1_path . "States/" . $1 . ".states")) {
                        $logger->error(__PACKAGE__ . ".$sub Failed to get state machine description for \"" . $seqgrp1_path . "States/". $1 . ".states" ."\"");
                        $error_found++;
	                last;	
                    }
                }
                else
                {
                    $logger->error(__PACKAGE__ . ".$sub Failed to extract 'CLEANUP' state machine name from '$cleanup_states[0]' in sequence group '$seqgrp2'");
                    $error_found++;
	            last;	
                }
                
                my $seqgrp1_index = 0;
                my $seqgrp2_index = 0;
                while (($seqgrp1_index <= $#seqgrp1_states) or ($seqgrp2_index <= $#seqgrp2_states))  
                {
                    my $seqgrp1_stateline;
                    my $seqgrp2_stateline;
                    if ($seqgrp1_index > $#seqgrp1_states) 
                    {
                        # We have come to the end of the ingress seq grp but
                        # not the egress seq grp
                        # Get the state line for the egress group 
                        $seqgrp2_stateline = $seqgrp2_states[$seqgrp2_index];
                        chomp $seqgrp2_stateline;
                        if ( $seqgrp2_stateline =~ m/STATE=States\/(.*\/)?(.+) TYPE=/ ) 
                        {
                            my $seqgrp2_workgroup = "";
                            if ($1)
                            {
                               $seqgrp2_workgroup = $1;
                               $seqgrp2_workgroup =~ s/\/$//;
                            }
                            my $seqgrp2_state = $2;
                            

                            if ("$seqgrp2_workgroup" eq "PSX_CONTROLS")
                            {
                                # Egress side (seqgrp2) is a PSX control
                                # We'll add the control, then skip around the loop again
                                $logger->debug(__PACKAGE__ . ".$sub Adding *PSX_CONTROL [2]* WORKGROUP='$seqgrp2_workgroup' STATE='$seqgrp2_state'\n");
                                print OUTPUT_TESTGRP_FILE "execPsxControl(";
                                my $psx_side = 1;
                                $psx_side = 2 if ($seqgrp2_state =~ /SS7([235])$|sigprof([235])$/);

                                @psx_commands = convertMgtsPsxControl(-psx_control => "${seqgrp2_state}", -dir_path => "${seqgrp2_path}/States/${seqgrp2_workgroup}");
                                if ($#psx_commands != 1 ) 
                                {
                                    # Error as convertMgtsPsxControl function has returned 0
                                    $logger->error(__PACKAGE__ . ".$sub Failed to convert PSX Control \"${seqgrp2_state}\". Please correct in file.");
				    $error_found++;
                                    last;
                                }
                                my $psx_cmd = $psx_commands[0];
                                my $def_psx_cmd = $psx_commands[1];
                                chomp $psx_cmd;
                                chomp $def_psx_cmd;
                                print OUTPUT_TESTGRP_FILE " -psx${psx_side}            => \"$psx_cmd\",\n";
                                print OUTPUT_TESTGRP_FILE "                -default_psx_cmd => \"$def_psx_cmd\",\n";
                                print OUTPUT_TESTGRP_FILE ");\n\n";
                                  
                                $seqgrp2_index++;
                            }
                            elsif ($seqgrp2_workgroup =~ /CONTROLS/)
                            {
                                # Egress side (seqgrp2) is a GSX control
                                # We'll add the control, then skip around the loop again
                                $logger->debug(__PACKAGE__ . ".$sub Adding *GSX_CONTROL [2]* WORKGROUP='$seqgrp2_workgroup' STATE='$seqgrp2_state'\n");
                                  
                                print OUTPUT_TESTGRP_FILE "execTest( -testid => \"config_update_" . ${seqgrp2_state} . "\",\n";
                                my $gsx_side = 1;
                                $gsx_side = 2 if ($seqgrp2_state =~ /SS7([235])$|sigprof([235])$/);

                                @gsx_commands = convertMgtsGsxControl(-gsx_control => "${seqgrp2_state}", -dir_path => "${seqgrp2_path}/States/${seqgrp2_workgroup}");
                                if ($#gsx_commands == 0 && (! $gsx_commands[0]) ) 
                                {
                                    # Error as convertMgtsControl function has returned 0
                                    $logger->error(__PACKAGE__ . ".$sub Failed to convert GSX Control \"${seqgrp2_state}\". Please correct in file.");
				    $error_found++;
                                    last;
                                }
                                my $skip_cic_check = 1;
                                if ($seqgrp2_state =~ /ABLE_SIGNALING_PROFILE_sigprof|ABLE_SERVICE_GROUP_SS7|ISUP_CIRC_(EN|DIS)ABLE/) 
                                {
                                    print OUTPUT_TESTGRP_FILE "          -mgts1  => \"$seqgrp1_cleanup\",\n          -mgts2  => \"$seqgrp2_cleanup\",\n";
                                    if (($seqgrp2_state =~ /ENABLE/) && 
                                        (defined($seqgrp2_states[$seqgrp2_index+1])) && 
                                        ( $seqgrp2_states[$seqgrp2_index+1] =~ /\/[1-9][0-9]* |PSX_CONTROLS/))
                                    {
                                        $skip_cic_check = 0;
                                    }
                                }
                                foreach my $cmd (@gsx_commands)
                                {
                                    chomp $cmd;
                                    print OUTPUT_TESTGRP_FILE "          -gsx${gsx_side}   => \"$cmd\",\n";
                                }
                                if ($skip_cic_check ) 
                                {
                                    print OUTPUT_TESTGRP_FILE "          -skip_cic_check => 1,\n";

                                }
                                print OUTPUT_TESTGRP_FILE ");\n\n";

                                $seqgrp2_index++;
                            }
                            elsif ($seqgrp2_state =~ /CLEANUP|AUTORESPONDER/)
                            {
                                # Ignoring CLEANUP state
                                $seqgrp2_index++;

                            }
                            else 
                            {  
                                # Must be an MGTS test
                                $logger->error(__PACKAGE__ . ".$sub Invalid EGRESS sequence group '$seqgrp2'. Contains state machine '$seqgrp2_state' that does not have an ingress equivalent\n");             
				$error_found++;
                                last;
                            }
                        }
                        else
                        {
                            $logger->error(__PACKAGE__ . ".$sub Invalid line in sequence group '$seqgrp2' Line\#${seqgrp2_index}=\"$seqgrp2_stateline\"\n");
			    $error_found++;
                            last;
                        }
                    }
                    elsif ($seqgrp2_index > $#seqgrp2_states) 
                    {
                        # We have come to the end of the egress seq grp but
                        # not the ingress seq grp
                        # Get the state line for the egress group 
                        $seqgrp1_stateline = $seqgrp1_states[$seqgrp1_index];
                        chomp $seqgrp1_stateline;

                        if ( $seqgrp1_stateline =~ m/STATE=States\/(.*\/)?(.+) TYPE=/ ) 
                        {
                            my $seqgrp1_workgroup = "";
                            if ($1)
                            {
                              $seqgrp1_workgroup = $1;
                              $seqgrp1_workgroup =~ s/\/$//;
                            } 

                            my $seqgrp1_state = $2;

                            if ("$seqgrp1_workgroup" eq "PSX_CONTROLS")
                            {
                                # Ingress side (seqgrp1) is a PSX control
                                # We'll add the control, then skip around the loop again
                                $logger->debug(__PACKAGE__ . ".$sub Adding *PSX_CONTROL [1]* WORKGROUP='$seqgrp1_workgroup' STATE='$seqgrp1_state'\n");
                                print OUTPUT_TESTGRP_FILE "execPsxControl(";
                                my $psx_side = 1;
                                $psx_side = 2 if ($seqgrp1_state =~ /SS7([235])$|sigprof([235])$/);

                                @psx_commands = convertMgtsPsxControl(-psx_control => "${seqgrp1_state}", -dir_path => "${seqgrp1_path}/States/${seqgrp1_workgroup}");
                                if ($#psx_commands != 1 ) 
                                {
                                    # Error as convertMgtsPsxControl function has returned 0
                                    $logger->error(__PACKAGE__ . ".$sub Failed to convert PSX Control \"${seqgrp1_state}\". Please correct in file.");
			            $error_found++;
                                    last;
                                }
                                my $psx_cmd = $psx_commands[0];
                                my $def_psx_cmd = $psx_commands[1];
                                chomp $psx_cmd;
                                chomp $def_psx_cmd;
                                print OUTPUT_TESTGRP_FILE " -psx${psx_side}            => \"$psx_cmd\",\n";
                                print OUTPUT_TESTGRP_FILE "                -default_psx_cmd => \"$def_psx_cmd\",\n";
                                print OUTPUT_TESTGRP_FILE ");\n\n";
                                  
                                $seqgrp1_index++;
                            }
                            elsif ($seqgrp1_workgroup =~ /CONTROLS/)
                            {
                                # Ingress side (seqgrp1) is a GSX control
                                # We'll add the control, then skip around the loop again
                                $logger->debug(__PACKAGE__ . ".$sub Adding *GSX__CONTROL [1]* WORKGROUP='$seqgrp1_workgroup' STATE='$seqgrp1_state'\n");
                                
                                print OUTPUT_TESTGRP_FILE "execTest( -testid => \"config_update_" . ${seqgrp1_state} . "\",\n";
                                my $gsx_side = 1;
                                $gsx_side = 2 if ($seqgrp1_state =~ /SS7([235])$|sigprof([235])$/);

                                @gsx_commands = convertMgtsGsxControl(-gsx_control => "${seqgrp1_state}", -dir_path => "${seqgrp1_path}/States/${seqgrp1_workgroup}");
                                if ($#gsx_commands == 0 && (! $gsx_commands[0]) ) 
                                {
                                    # Error as convertMgtsControl function has returned 0
                                    $logger->error(__PACKAGE__ . ".$sub Failed to convert GSX Control \"${seqgrp1_state}\". Please correct in file.");
			            $error_found++;
                                    last;
                                }
                                my $skip_cic_check = 1;
                                if ($seqgrp1_state =~ /ABLE_SIGNALING_PROFILE_sigprof|ABLE_SERVICE_GROUP_SS7|ISUP_CIRC_(EN|DIS)ABLE/) 
                                {
                                    print OUTPUT_TESTGRP_FILE "          -mgts1  => \"$seqgrp1_cleanup\",\n          -mgts2  => \"$seqgrp2_cleanup\",\n";
                                    if (($seqgrp1_state =~ /ENABLE/) && 
                                        (defined($seqgrp1_states[$seqgrp1_index+1])) && 
                                        ( $seqgrp1_states[$seqgrp1_index+1] =~ /\/[1-9][0-9]* |PSX_CONTROLS/))
                                    {
                                        $skip_cic_check = 0;
                                    }
                                }
                                foreach my $cmd (@gsx_commands)
                                {
                                    chomp $cmd;
                                    print OUTPUT_TESTGRP_FILE "          -gsx${gsx_side}   => \"$cmd\",\n";
                                }
                                if ($skip_cic_check)
                                {
                                    print OUTPUT_TESTGRP_FILE "          -skip_cic_check => 1,\n";
                                }  
                                print OUTPUT_TESTGRP_FILE ");\n\n";
                                  
                                $seqgrp1_index++;
                            }
                            elsif ($seqgrp1_state =~ /CLEANUP|AUTORESPONDER/)
                            {
                                # Ignoring CLEANUP state
                                $seqgrp1_index++;

                            }
                            else 
                            {  
                                # Must be an ingress MGTS test
                                my $state_description1; 
                                unless  ($state_description1 = $tmpMgtsObjRef->getStateDesc(-full_statename => $seqgrp1_path . "States/" . $seqgrp1_workgroup . "/" . $seqgrp1_state . ".states")) {
                                    $logger->error(__PACKAGE__ . ".$sub Failed to get state machine description for \"" . $seqgrp1_path . $seqgrp1_workgroup . "/" . $seqgrp1_state  ."\"");
			            $error_found++;
                                    last;
                                }
                                $state1_timeout = $tmpMgtsObjRef->getStateTotalTime(-full_statename => $seqgrp1_path . "States/" . $seqgrp1_workgroup . "/" . $seqgrp1_state . ".states");
                                if ($state1_timeout > 60) {
                                    $state1_timeout_string = "          -timeout     => $state1_timeout,\n";
                                } else {
                                    $state1_timeout_string = "";
                                }
                                # Add test
                                print OUTPUT_TESTGRP_FILE "execTest( -testid      => \"${seqgrp1_state}\",\n          -feature     => \"\$feature \",\n          -requirement => \"\$requirement\",\n          -mgts1       => \"${state_description1}\",\n${state1_timeout_string});\n\n";
                                $seqgrp1_index++;
                            }
                        }
                        else
                        {
                            $logger->error(__PACKAGE__ . ".$sub Invalid line in sequence group '$seqgrp1' Line\#${seqgrp1_index}=\"$seqgrp1_stateline\"\n");
			    $error_found++;
                            last;
                        }
                    }
                    else 
                    {
                        $seqgrp1_stateline = $seqgrp1_states[$seqgrp1_index];
                        chomp $seqgrp1_stateline;
                        $seqgrp2_stateline = $seqgrp2_states[$seqgrp2_index];
                        chomp $seqgrp2_stateline; 

                        if ( $seqgrp1_stateline =~ m/STATE=States\/(.*\/)?(.+) TYPE=/ ) 
                        {
                            my $seqgrp1_workgroup = "";
                            if ($1)
                            { 
                                $seqgrp1_workgroup = $1;
                                $seqgrp1_workgroup =~ s/\/$//;
                            }
                            my $seqgrp1_state = $2;
    
                            if ("$seqgrp1_workgroup" eq "PSX_CONTROLS")
                            {
                                # Ingress side (seqgrp1) is a PSX control
                                if ( $seqgrp2_stateline =~ m/STATE=States\/(.*\/)?([0-9]+) TYPE=/ ) 
                                {
                                    # This is an MGTS called test
                                    # We do not allow solo egress halfcalls, so the egress half-test must match some later row in the ingress list
                                    # Dump out the ingress control and loop around
                                    $logger->debug(__PACKAGE__ . ".$sub Adding *PSX_CONTROL [1]* WORKGROUP='$seqgrp1_workgroup' STATE='$seqgrp1_state'\n");
                                    print OUTPUT_TESTGRP_FILE "execPsxControl(";
                                    my $psx_side = 1;
                                    $psx_side = 2 if ($seqgrp1_state =~ /SS7([235])$|sigprof([235])$/);

                                    @psx_commands = convertMgtsPsxControl(-psx_control => "${seqgrp1_state}", -dir_path => "${seqgrp1_path}/States/${seqgrp1_workgroup}");
                                    if ($#psx_commands != 1 ) 
                                    {
                                        # Error as convertMgtsPsxControl function has returned 0
                                        $logger->error(__PACKAGE__ . ".$sub Failed to convert PSX Control \"${seqgrp1_state}\". Please correct in file.");
			                $error_found++;
                                        last;
                                    }
                                    my $psx_cmd = $psx_commands[0];
                                    my $def_psx_cmd = $psx_commands[1];
                                    chomp $psx_cmd;
                                    chomp $def_psx_cmd;
                                    print OUTPUT_TESTGRP_FILE " -psx${psx_side}            => \"$psx_cmd\",\n";
                                    print OUTPUT_TESTGRP_FILE "                -default_psx_cmd => \"$def_psx_cmd\",\n";
                                    print OUTPUT_TESTGRP_FILE ");\n\n";

                                    $seqgrp1_index++;
                                }
                                else
                                {
                                    my $seqgrp2_workgroup = "";
                                    if ( $seqgrp2_stateline =~ m/STATE=States\/(.*\/)?(PSX_.*) TYPE=/ ) 
                                    {
                                        if ($1) 
                                        {
                                            $seqgrp2_workgroup = $1;
                                            $seqgrp2_workgroup =~ s/\/$//;
                                        }

                                        my $seqgrp2_state = $2;

                                        # We have ingress *and* egress PSX controls. 
                                        $logger->debug(__PACKAGE__ . ".$sub Adding *PSX_CONTROL [1]* WORKGROUP='$seqgrp1_workgroup' STATE='$seqgrp1_state'\n");
                                        print OUTPUT_TESTGRP_FILE "execPsxControl(";
                                        my $psx_side = 1;
                                        $psx_side = 2 if ($seqgrp1_state =~ /SS7([235])$|sigprof([235])$/);

                                        @psx_commands = convertMgtsPsxControl(-psx_control => "${seqgrp1_state}", -dir_path => "${seqgrp1_path}/States/${seqgrp1_workgroup}");
                                        if ($#psx_commands != 1 ) 
                                        {
                                            # Error as convertMgtsPsxControl function has returned 0
                                            $logger->error(__PACKAGE__ . ".$sub Failed to convert PSX Control \"${seqgrp1_state}\". Please correct in file.");
			                    $error_found++;
                                            last;
                                        }
                                        my $psx_cmd = $psx_commands[0];
                                        my $def_psx_cmd = $psx_commands[1];
                                        chomp $psx_cmd;
                                        chomp $def_psx_cmd;
                                        print OUTPUT_TESTGRP_FILE " -psx${psx_side}            => \"$psx_cmd\",\n";
                                        print OUTPUT_TESTGRP_FILE "                -default_psx_cmd => \"$def_psx_cmd\",\n";
                                        print OUTPUT_TESTGRP_FILE ");\n\n";
                                       
                                        $logger->debug(__PACKAGE__ . ".$sub Adding *PSX_CONTROL [2]* WORKGROUP='$seqgrp2_workgroup' STATE='$seqgrp2_state'\n");
                                        print OUTPUT_TESTGRP_FILE "execPsxControl(";
                                        $psx_side = 1;
                                        $psx_side = 2 if ($seqgrp2_state =~ /SS7([235])$|sigprof([235])$/);

                                        @psx_commands = convertMgtsPsxControl(-psx_control => "${seqgrp2_state}", -dir_path => "${seqgrp2_path}/States/${seqgrp2_workgroup}");
                                        if ($#psx_commands != 1 ) 
                                        {
                                            # Error as convertMgtsPsxControl function has returned 0
                                            $logger->error(__PACKAGE__ . ".$sub Failed to convert PSX Control \"${seqgrp2_state}\". Please correct in file.");
			                    $error_found++;
                                            last;
                                        }
                                        $psx_cmd = $psx_commands[0];
                                        $def_psx_cmd = $psx_commands[1];
                                        chomp $psx_cmd;
                                        chomp $def_psx_cmd;
                                        print OUTPUT_TESTGRP_FILE " -psx${psx_side}            => \"$psx_cmd\",\n";
                                        print OUTPUT_TESTGRP_FILE "                -default_psx_cmd => \"$def_psx_cmd\",\n";
                                        print OUTPUT_TESTGRP_FILE ");\n\n";
                                    }
                                    elsif ( $seqgrp2_stateline =~ m/STATE=States\/(.*CONTROLS\/)(.+) TYPE=/ ) 
                                    {
                                        if ($1)
                                        {
                                          $seqgrp2_workgroup = $1;
                                          $seqgrp2_workgroup =~ s/\/$//;
                                        }
                                        my $seqgrp2_state = $2;
                                        # We have an ingress PSX control and an egress GSX control. 
                                        $logger->debug(__PACKAGE__ . ".$sub Adding *PSX_CONTROL [1]* WORKGROUP='$seqgrp1_workgroup' STATE='$seqgrp1_state'\n");
                                        print OUTPUT_TESTGRP_FILE "execPsxControl(";
                                        my $psx_side = 1;
                                        $psx_side = 2 if ($seqgrp1_state =~ /SS7([235])$|sigprof([235])$/);

                                        @psx_commands = convertMgtsPsxControl(-psx_control => "${seqgrp1_state}", -dir_path => "${seqgrp1_path}/States/${seqgrp1_workgroup}");
                                        if ($#psx_commands != 1 ) 
                                        {
                                            # Error as convertMgtsPsxControl function has returned 0
                                            $logger->error(__PACKAGE__ . ".$sub Failed to convert PSX Control \"${seqgrp1_state}\". Please correct in file.");
			                    $error_found++;
                                            last;
                                        }
                                        my $psx_cmd = $psx_commands[0];
                                        my $def_psx_cmd = $psx_commands[1];
                                        chomp $psx_cmd;
                                        chomp $def_psx_cmd;
                                        print OUTPUT_TESTGRP_FILE " -psx${psx_side}            => \"$psx_cmd\",\n";
                                        print OUTPUT_TESTGRP_FILE "                -default_psx_cmd => \"$def_psx_cmd\",\n";
                                        print OUTPUT_TESTGRP_FILE ");\n\n";
                                        
                                        $logger->debug(__PACKAGE__ . ".$sub Adding *GSX_CONTROL [2]* WORKGROUP='$seqgrp2_workgroup' STATE='$seqgrp2_state'\n");
                                        print OUTPUT_TESTGRP_FILE "execTest( -testid => \"config_update_" . ${seqgrp2_state} . "\",\n";
                                        my $gsx_side = 1;
                                        $gsx_side = 2 if ($seqgrp2_state =~ /SS7([235])$|sigprof([235])$/);

                                        @gsx_commands = convertMgtsGsxControl(-gsx_control => "${seqgrp2_state}", -dir_path => "${seqgrp2_path}/States/${seqgrp2_workgroup}");
                                        if ($#gsx_commands == 0 && (! $gsx_commands[0]) ) 
                                        {
                                            # Error as convertMgtsControl function has returned 0
                                            $logger->error(__PACKAGE__ . ".$sub Failed to convert GSX Control \"${seqgrp2_state}\". Please correct in file.");
			                    $error_found++;
                                            last;
                                        }
                                        my $skip_cic_check=1;
                                        if ($seqgrp2_state =~ /ABLE_SIGNALING_PROFILE_sigprof|ABLE_SERVICE_GROUP_SS7|ISUP_CIRC_(EN|DIS)ABLE/) 
                                        {
                                            print OUTPUT_TESTGRP_FILE "          -mgts1  => \"$seqgrp1_cleanup\",\n          -mgts2  => \"$seqgrp2_cleanup\",\n";
                                            if ($seqgrp2_state =~ /ENABLE/ ) 
                                            { 
                                                if (defined($seqgrp2_states[$seqgrp2_index+1])) 
                                                {
                                                    if ( $seqgrp2_states[$seqgrp2_index+1] =~ /\/[1-9][0-9]* / && 
                                                        ((!defined($seqgrp1_states[$seqgrp1_index+1])) || $seqgrp1_states[$seqgrp1_index+1] =~ /\/[1-9][0-9]* /))
                                                    {
                                                        $skip_cic_check = 0;
                                                    }
                                                } 
                                                elsif (defined($seqgrp1_states[$seqgrp1_index+1]) && $seqgrp1_states[$seqgrp1_index+1] =~ /\/[1-9][0-9]* /)
                                                {
                                                    $skip_cic_check = 0;
                                                }                                      
                                            }
                                        }
                                        foreach my $cmd (@gsx_commands)
                                        {
                                            chomp $cmd;
                                            print OUTPUT_TESTGRP_FILE "          -gsx${gsx_side}   => \"$cmd\",\n";
                                        }
                                        if ($skip_cic_check)
                                        {
                                            print OUTPUT_TESTGRP_FILE "          -skip_cic_check => 1,\n";
                                        }
                                        print OUTPUT_TESTGRP_FILE ");\n\n";
                                    }
                                    else  
                                    {
                                        # We must be a CLEANUP on the egress side
                                        # Ignore cleanup and add ingress PSX control 
                                        $logger->debug(__PACKAGE__ . ".$sub Adding *PSX_CONTROL [1]* WORKGROUP='$seqgrp1_workgroup' STATE='$seqgrp1_state'\n");
                                        print OUTPUT_TESTGRP_FILE "execPsxControl(";
                                        my $psx_side = 1;
                                        $psx_side = 2 if ($seqgrp1_state =~ /SS7([235])$|sigprof([235])$/);

                                        @psx_commands = convertMgtsPsxControl(-psx_control => "${seqgrp1_state}", -dir_path => "${seqgrp1_path}/States/${seqgrp1_workgroup}");
                                        if ($#psx_commands != 1 ) 
                                        {
                                            # Error as convertMgtsPsxControl function has returned 0
                                            $logger->error(__PACKAGE__ . ".$sub Failed to convert PSX Control \"${seqgrp1_state}\". Please correct in file.");
			                    $error_found++;
                                            last;
                                        }
                                        my $psx_cmd = $psx_commands[0];
                                        my $def_psx_cmd = $psx_commands[1];
                                        chomp $psx_cmd;
                                        chomp $def_psx_cmd;
                                        print OUTPUT_TESTGRP_FILE " -psx${psx_side}            => \"$psx_cmd\",\n";
                                        print OUTPUT_TESTGRP_FILE "                -default_psx_cmd => \"$def_psx_cmd\",\n";
                                        print OUTPUT_TESTGRP_FILE ");\n\n";
                                    }
                                    $seqgrp1_index++;
                                    $seqgrp2_index++;
                                } 
                            }
                            elsif ($seqgrp1_workgroup =~ /CONTROLS/ )
                            {
                                # Ingress side (seqgrp1) is a GSX control
                                if ( $seqgrp2_stateline =~ m/STATE=States\/(.*\/)?([0-9]+) TYPE=/ ) 
                                {
                                    # This is an MGTS called test
                                    # We do not allow solo egress halfcalls, so the egress half-test must match some later row in the ingress list
                                    # Dump out the ingress control and loop around
                                    $logger->debug(__PACKAGE__ . ".$sub Adding *GSX_CONTROL [1]* WORKGROUP='$seqgrp1_workgroup' STATE='$seqgrp1_state'\n");
                                    print OUTPUT_TESTGRP_FILE "execTest( -testid => \"config_update_" . ${seqgrp1_state} . "\",\n";
                                    my $gsx_side = 1;
                                    $gsx_side = 2 if ($seqgrp1_state =~ /SS7([235])$|sigprof([235])$/);

                                    @gsx_commands = convertMgtsGsxControl(-gsx_control => "${seqgrp1_state}", -dir_path => "${seqgrp1_path}/States/${seqgrp1_workgroup}");
                                    if ($#gsx_commands == 0 && (! $gsx_commands[0]) ) 
                                    {
                                        # Error as convertMgtsControl function has returned 0
                                        $logger->error(__PACKAGE__ . ".$sub Failed to convert GSX Control \"${seqgrp1_state}\". Please correct in file.");
			                $error_found++;
                                        last;
                                    }
                                    my $skip_cic_check = 1;
                                    if ($seqgrp1_state =~ /ABLE_SIGNALING_PROFILE_sigprof|ABLE_SERVICE_GROUP_SS7|ISUP_CIRC_(EN|DIS)ABLE/) 
                                    {
                                        print OUTPUT_TESTGRP_FILE "          -mgts1  => \"$seqgrp1_cleanup\",\n          -mgts2  => \"$seqgrp2_cleanup\",\n";
                                        if ($seqgrp1_state =~ /ENABLE/ ) 
                                        { 
                                            if (defined($seqgrp1_states[$seqgrp1_index+1])) 
                                            {
                                                if ( $seqgrp1_states[$seqgrp1_index+1] =~ /\/[1-9][0-9]* / && 
                                                    ((!defined($seqgrp2_states[$seqgrp2_index+1])) || $seqgrp2_states[$seqgrp2_index+1] =~ /\/[1-9][0-9]* /))
                                                {
                                                    $skip_cic_check = 0;
                                                }
                                            } 
                                            elsif (defined($seqgrp2_states[$seqgrp2_index+1]) && $seqgrp2_states[$seqgrp2_index+1] =~ /\/[1-9][0-9]* /)
                                            {
                                                $skip_cic_check = 0;
                                            }                                      
                                        } 
                                    }
                                    foreach my $cmd (@gsx_commands)
                                    {
                                        chomp $cmd;
                                        print OUTPUT_TESTGRP_FILE "          -gsx${gsx_side}   => \"$cmd\",\n";
                                    }
                                    if ($skip_cic_check) 
                                    {
                                        print OUTPUT_TESTGRP_FILE "          -skip_cic_check => 1,\n";
                                    }  
                                    print OUTPUT_TESTGRP_FILE ");\n\n";
                                    $seqgrp1_index++;
                                }
                                else
                                {
                                    my $seqgrp2_workgroup = "";
                                    if ( $seqgrp2_stateline =~ m/STATE=States\/(.*\/)?(PSX_.*) TYPE=/ ) 
                                    {
                                        if ($1)
                                        {  
                                            $seqgrp2_workgroup = $1;
                                            $seqgrp2_workgroup =~ s/\/$//;
                                        }
                                        my $seqgrp2_state = $2;

                                        # We have ingress GSX control *and* egress PSX controls. 
                                        $logger->debug(__PACKAGE__ . ".$sub Adding *GSX_CONTROL [1]* WORKGROUP='$seqgrp1_workgroup' STATE='$seqgrp1_state'\n");
                                        print OUTPUT_TESTGRP_FILE "execTest( -testid => \"config_update_" . ${seqgrp1_state} . "\",\n";
                                        my $gsx_side = 1;
                                        $gsx_side = 2 if ($seqgrp1_state =~ /SS7([235])$|sigprof([235])$/);

                                        @gsx_commands = convertMgtsGsxControl(-gsx_control => "${seqgrp1_state}", -dir_path => "${seqgrp1_path}/States/${seqgrp1_workgroup}");
                                        if ($#gsx_commands == 0 && (! $gsx_commands[0]) ) 
                                        {
                                            # Error as convertMgtsControl function has returned 0
                                            $logger->error(__PACKAGE__ . ".$sub Failed to convert GSX Control \"${seqgrp1_state}\". Please correct in file.");
			                    $error_found++;
                                            last;
                                        }
                                        my $skip_cic_check = 1;
                                        if ($seqgrp1_state =~ /ABLE_SIGNALING_PROFILE_sigprof|ABLE_SERVICE_GROUP_SS7|ISUP_CIRC_(EN|DIS)ABLE/) 
                                        {
                                            print OUTPUT_TESTGRP_FILE "          -mgts1  => \"$seqgrp1_cleanup\",\n          -mgts2  => \"$seqgrp2_cleanup\",\n";
                                            if ($seqgrp1_state =~ /ENABLE/ ) 
                                            { 
                                                if (defined($seqgrp1_states[$seqgrp1_index+1])) 
                                                {
                                                    if ( $seqgrp1_states[$seqgrp1_index+1] =~ /\/[1-9][0-9]* / && 
                                                        ((!defined($seqgrp2_states[$seqgrp2_index+1])) || $seqgrp2_states[$seqgrp2_index+1] =~ /\/[1-9][0-9]* /))
                                                    {
                                                        $skip_cic_check = 0;
                                                    }
                                                } 
                                                elsif (defined($seqgrp2_states[$seqgrp2_index+1]) && $seqgrp2_states[$seqgrp2_index+1] =~ /\/[1-9][0-9]* /)
                                                {
                                                    $skip_cic_check = 0;
                                                }                                      
                                            } 
                                        }
                                        foreach my $cmd (@gsx_commands)
                                        {
                                            chomp $cmd;
                                            print OUTPUT_TESTGRP_FILE "          -gsx${gsx_side}   => \"$cmd\",\n";
                                        }
                                        if ($skip-cic_check) 
                                        {
                                            print OUTPUT_TESTGRP_FILE "          -skip_cic_check => 1,\n";
                                        }
                                        print OUTPUT_TESTGRP_FILE ");\n\n";

                                        $logger->debug(__PACKAGE__ . ".$sub Adding *PSX_CONTROL [2]* WORKGROUP='$seqgrp2_workgroup' STATE='$seqgrp2_state'\n");
                                        print OUTPUT_TESTGRP_FILE "execPsxControl(";
                                        $psx_side = 1;
                                        $psx_side = 2 if ($seqgrp2_state =~ /SS7([235])$|sigprof([235])$/);

                                        @psx_commands = convertMgtsPsxControl(-psx_control => "${seqgrp2_state}", -dir_path => "${seqgrp2_path}/States/${seqgrp2_workgroup}");
                                        if ($#psx_commands != 1 ) 
                                        {
                                            # Error as convertMgtsPsxControl function has returned 0
                                            $logger->error(__PACKAGE__ . ".$sub Failed to convert PSX Control \"${seqgrp2_state}\". Please correct in file.");
			                    $error_found++;
                                            last;
                                        }
                                        my $psx_cmd = $psx_commands[0];
                                        my $def_psx_cmd = $psx_commands[1];
                                        chomp $psx_cmd;
                                        chomp $def_psx_cmd;
                                        print OUTPUT_TESTGRP_FILE " -psx${psx_side}            => \"$psx_cmd\",\n";
                                        print OUTPUT_TESTGRP_FILE "                -default_psx_cmd => \"$def_psx_cmd\",\n";
                                        print OUTPUT_TESTGRP_FILE ");\n\n";
                                    }
                                    elsif ( $seqgrp2_stateline =~ m/STATE=States\/(.*CONTROLS\/)(.+) TYPE=/ ) 
                                    {
                                        if ($1) 
                                        {
                                            $seqgrp2_workgroup = $1;
                                            $seqgrp2_workgroup =~ s/\/$//;
                                        }
                                        my $seqgrp2_state = $2;

                                        # We have an ingress *and* egress GSX controls. 
                                        $logger->debug(__PACKAGE__ . ".$sub Adding *GSX_CONTROL [1]* WORKGROUP='$seqgrp1_workgroup' STATE='$seqgrp1_state'\n");
                                        print OUTPUT_TESTGRP_FILE "execTest( -testid => \"config_update_" . ${seqgrp1_state} . "\",\n";
                                        my $gsx_side = 1;
                                        $gsx_side = 2 if ($seqgrp1_state =~ /SS7([235])$|sigprof([235])$/);

                                        @gsx_commands = convertMgtsGsxControl(-gsx_control => "${seqgrp1_state}", -dir_path => "${seqgrp1_path}/States/${seqgrp1_workgroup}");
                                        if ($#gsx_commands == 0 && (! $gsx_commands[0]) ) 
                                        {
                                            # Error as convertMgtsControl function has returned 0
                                            $logger->error(__PACKAGE__ . ".$sub Failed to convert GSX Control \"${seqgrp1_state}\". Please correct in file.");
			                    $error_found++;
                                            last;
                                        }
                                        my $skip_cic_check = 1;
                                        if ($seqgrp1_state =~ /ABLE_SIGNALING_PROFILE_sigprof|ABLE_SERVICE_GROUP_SS7|ISUP_CIRC_(EN|DIS)ABLE/) 
                                        {
                                            print OUTPUT_TESTGRP_FILE "          -mgts1  => \"$seqgrp1_cleanup\",\n          -mgts2  => \"$seqgrp2_cleanup\",\n";
                                            if ($seqgrp1_state =~ /ENABLE/ ) 
                                            { 
                                                if (defined($seqgrp1_states[$seqgrp1_index+1])) 
                                                {
                                                    if ( $seqgrp1_states[$seqgrp1_index+1] =~ /\/[1-9][0-9]* / && 
                                                        ((!defined($seqgrp2_states[$seqgrp2_index+1])) || $seqgrp2_states[$seqgrp2_index+1] =~ /\/[1-9][0-9]* /))
                                                    {
                                                        $skip_cic_check = 0;
                                                    }
                                                } 
                                                elsif (defined($seqgrp2_states[$seqgrp2_index+1]) && $seqgrp2_states[$seqgrp2_index+1] =~ /\/[1-9][0-9]* /)
                                                {
                                                    $skip_cic_check = 0;
                                                }                                      
                                            } 
                                        }
                                        foreach my $cmd (@gsx_commands)
                                        {
                                            chomp $cmd;
                                            print OUTPUT_TESTGRP_FILE "          -gsx${gsx_side}   => \"$cmd\",\n";
                                        }
                                        if ($skip_cic_check) 
                                        {
                                            print OUTPUT_TESTGRP_FILE "          -skip_cic_check => 1,\n";
                                        }
                                        print OUTPUT_TESTGRP_FILE ");\n\n";

                                        $logger->debug(__PACKAGE__ . ".$sub Adding *GSX_CONTROL [2]* WORKGROUP='$seqgrp2_workgroup' STATE='$seqgrp2_state'\n");
                                        print OUTPUT_TESTGRP_FILE "execTest( -testid => \"config_update_" . ${seqgrp2_state} . "\",\n";
                                        $gsx_side = 1;
                                        $gsx_side = 2 if ($seqgrp2_state =~ /SS7([235])$|sigprof([235])$/);

                                        @gsx_commands = convertMgtsGsxControl(-gsx_control => "${seqgrp2_state}", -dir_path => "${seqgrp2_path}/States/${seqgrp2_workgroup}");
                                        if ($#gsx_commands == 0 && (! $gsx_commands[0]) ) 
                                        {
                                            # Error as convertMgtsControl function has returned 0
                                            $logger->error(__PACKAGE__ . ".$sub Failed to convert GSX Control \"${seqgrp2_state}\". Please correct in file.");
					    $error_found++;
                                            last;
                                        }
                                        $skip_cic_check = 1;
                                        if ($seqgrp2_state =~ /ABLE_SIGNALING_PROFILE_sigprof|ABLE_SERVICE_GROUP_SS7|ISUP_CIRC_(EN|DIS)ABLE/) 
                                        {
                                            print OUTPUT_TESTGRP_FILE "          -mgts1  => \"$seqgrp1_cleanup\",\n          -mgts2  => \"$seqgrp2_cleanup\",\n";
                                            if ($seqgrp2_state =~ /ENABLE/ ) 
                                            { 
                                                if (defined($seqgrp2_states[$seqgrp2_index+1])) 
                                                {
                                                    if ( $seqgrp2_states[$seqgrp2_index+1] =~ /\/[1-9][0-9]* / && 
                                                        ((!defined($seqgrp1_states[$seqgrp1_index+1])) || $seqgrp1_states[$seqgrp1_index+1] =~ /\/[1-9][0-9]* /))
                                                    {
                                                        $skip_cic_check = 0;
                                                    }
                                                } 
                                                elsif (defined($seqgrp1_states[$seqgrp1_index+1]) && $seqgrp1_states[$seqgrp1_index+1] =~ /\/[1-9][0-9]* /)
                                                {
                                                    $skip_cic_check = 0;
                                                }                                      
                                            }
                                        }
                                        foreach my $cmd (@gsx_commands)
                                        {
                                            chomp $cmd;
                                            print OUTPUT_TESTGRP_FILE "          -gsx${gsx_side}   => \"$cmd\",\n";
                                        }
                                        if ($skip_cic_check)
                                        {
                                            print OUTPUT_TESTGRP_FILE "          -skip_cic_check => 1,\n";
                                        }
                                        print OUTPUT_TESTGRP_FILE ");\n\n";
                                    }
                                    else  
                                    {
                                        # We must be a CLEANUP on the egress side
                                        # Ignore cleanup and add ingress GSX
                                        # control 
                                        $logger->debug(__PACKAGE__ . ".$sub Adding *GSX_CONTROL [1]* WORKGROUP='$seqgrp1_workgroup' STATE='$seqgrp1_state'\n");
                                        print OUTPUT_TESTGRP_FILE "execTest( -testid => \"config_update_" . ${seqgrp1_state} . "\",\n";
                                        my $gsx_side = 1;
                                        $gsx_side = 2 if ($seqgrp1_state =~ /SS7([235])$|sigprof([235])$/);

                                        @gsx_commands = convertMgtsGsxControl(-gsx_control => "${seqgrp1_state}", -dir_path => "${seqgrp1_path}/States/${seqgrp1_workgroup}");
                                        if ($#gsx_commands == 0 && (! $gsx_commands[0]) ) 
                                        {
                                            # Error as convertMgtsControl function has returned 0
                                            $logger->error(__PACKAGE__ . ".$sub Failed to convert GSX Control \"${seqgrp1_state}\". Please correct in file.");
					    $error_found++;
                                            last;
                                        }
                                        my $skip_cic_check = 1;
                                        if ($seqgrp1_state =~ /ABLE_SIGNALING_PROFILE_sigprof|ABLE_SERVICE_GROUP_SS7|ISUP_CIRC_(EN|DIS)ABLE/) 
                                        {
                                            print OUTPUT_TESTGRP_FILE "          -mgts1  => \"$seqgrp1_cleanup\",\n          -mgts2  => \"$seqgrp2_cleanup\",\n";
                                            if ($seqgrp1_state =~ /ENABLE/ ) 
                                            { 
                                                if (defined($seqgrp1_states[$seqgrp1_index+1])) 
                                                {
                                                    if ( $seqgrp1_states[$seqgrp1_index+1] =~ /\/[1-9][0-9]* / && 
                                                        ((!defined($seqgrp2_states[$seqgrp2_index+1])) || $seqgrp2_states[$seqgrp2_index+1] =~ /\/[1-9][0-9]* /))
                                                    {
                                                        $skip_cic_check = 0;
                                                    }
                                                } 
                                                elsif (defined($seqgrp2_states[$seqgrp2_index+1]) && $seqgrp2_states[$seqgrp2_index+1] =~ /\/[1-9][0-9]* /)
                                                {
                                                    $skip_cic_check = 0;
                                                }                                      
                                            } 
                                        }
                                        foreach my $cmd (@gsx_commands)
                                        {
                                            chomp $cmd;
                                            print OUTPUT_TESTGRP_FILE "          -gsx${gsx_side}   => \"$cmd\",\n";
                                        }
                                        if ($skip_cic_check)
                                        {
                                            print OUTPUT_TESTGRP_FILE "          -skip_cic_check => 1,\n";
                                        } 
                                        print OUTPUT_TESTGRP_FILE ");\n\n";
                                    }
                                    $seqgrp1_index++;
                                    $seqgrp2_index++;
                                } 
                            }
                            elsif ($seqgrp1_state =~ /CLEANUP|AUTORESPONDER/  )
                            {
                                $logger->debug(__PACKAGE__ . ".$sub Found and ignoring CLEANUP [1]* WORKGROUP='$seqgrp1_workgroup' STATE='$seqgrp1_state'\n");
                                $seqgrp1_index++;
                            }
                            elsif ($seqgrp1_state =~ /^[1-9][0-9]*$/ )
                            {
                                # We are an MGTS calling test
                                if ( $seqgrp2_stateline =~ m/STATE=States\/(.*\/)?(.+) TYPE=/ ) 
                                {
                                    my $seqgrp2_workgroup = "";
                                    if ($1) 
                                    {
                                        $seqgrp2_workgroup = $1;
                                        $seqgrp2_workgroup =~ s/\/$//;
                                    }  
                                    my $seqgrp2_state = $2;
                                                                    
                                    if ($seqgrp2_workgroup eq "PSX_CONTROLS")
                                    {
                                        # Egress side (seqgrp2) is a PSX control
                                        # We'll add the control, then skip around the loop again
                                        $logger->debug(__PACKAGE__ . ".$sub Adding *PSX_CONTROL [2]* WORKGROUP='$seqgrp2_workgroup' STATE='$seqgrp2_state'\n");
                                        print OUTPUT_TESTGRP_FILE "execPsxControl(";
                                        $psx_side = 1;
                                        $psx_side = 2 if ($seqgrp2_state =~ /SS7([235])$|sigprof([235])$/);

                                        @psx_commands = convertMgtsPsxControl(-psx_control => "${seqgrp2_state}", -dir_path => "${seqgrp2_path}/States/${seqgrp2_workgroup}");
                                        if ($#psx_commands != 1 ) 
                                        {
                                            # Error as convertMgtsPsxControl function has returned 0
                                            $logger->error(__PACKAGE__ . ".$sub Failed to convert PSX Control \"${seqgrp2_state}\". Please correct in file.");
					    $error_found++;
                                            last;
                                        }
                                        my $psx_cmd = $psx_commands[0];
                                        my $def_psx_cmd = $psx_commands[1];
                                        chomp $psx_cmd;
                                        chomp $def_psx_cmd;
                                        print OUTPUT_TESTGRP_FILE " -psx${psx_side}            => \"$psx_cmd\",\n";
                                        print OUTPUT_TESTGRP_FILE "                -default_psx_cmd => \"$def_psx_cmd\",\n";
                                        print OUTPUT_TESTGRP_FILE ");\n\n";
                                        
                                        $seqgrp2_index++;
                                    }
                                    elsif ($seqgrp2_workgroup =~ /CONTROLS/ )
                                    {
                                        # Egress side (seqgrp2) is a GSX control
                                        # We'll add the control, then skip around the loop again
                                        $logger->debug(__PACKAGE__ . ".$sub Adding *CONTROL [2]* WORKGROUP='$seqgrp2_workgroup' STATE='$seqgrp2_state'\n");
                                        print OUTPUT_TESTGRP_FILE "execTest( -testid => \"config_update_" . ${seqgrp2_state} . "\",\n";
                                        $gsx_side = 1;
                                        $gsx_side = 2 if ($seqgrp2_state =~ /SS7([235])$|sigprof([235])$/);

                                        @gsx_commands = convertMgtsGsxControl(-gsx_control => "${seqgrp2_state}", -dir_path => "${seqgrp2_path}/States/${seqgrp2_workgroup}");
                                        if ($#gsx_commands == 0 && (! $gsx_commands[0]) ) 
                                        {
                                            # Error as convertMgtsControl function has returned 0
                                            $logger->error(__PACKAGE__ . ".$sub Failed to convert GSX Control \"${seqgrp2_state}\". Please correct in file.");
					    $error_found++;
                                            last;
                                        }
                                        my $skip_cic_check = 1;
                                        if ($seqgrp2_state =~ /ABLE_SIGNALING_PROFILE_sigprof|ABLE_SERVICE_GROUP_SS7|ISUP_CIRC_(EN|DIS)ABLE/) 
                                        {
                                            print OUTPUT_TESTGRP_FILE "          -mgts1  => \"$seqgrp1_cleanup\",\n          -mgts2  => \"$seqgrp2_cleanup\",\n";
                                            if ($seqgrp2_state =~ /ENABLE/ ) 
                                            { 
                                                if (defined($seqgrp2_states[$seqgrp2_index+1])) 
                                                {
                                                    if ( $seqgrp2_states[$seqgrp2_index+1] =~ /\/[1-9][0-9]* / && 
                                                        ((!defined($seqgrp1_states[$seqgrp1_index+1])) || $seqgrp1_states[$seqgrp1_index+1] =~ /\/[1-9][0-9]* /))
                                                    {
                                                        $skip_cic_check = 0;
                                                    }
                                                } 
                                                elsif (defined($seqgrp1_states[$seqgrp1_index+1]) && $seqgrp1_states[$seqgrp1_index+1] =~ /\/[1-9][0-9]* /)
                                                {
                                                    $skip_cic_check = 0;
                                                }                                      
                                            }
                                        }
                                        foreach my $cmd (@gsx_commands)
                                        {
                                            chomp $cmd;
                                            print OUTPUT_TESTGRP_FILE "          -gsx${gsx_side}   => \"$cmd\",\n";
                                        }
                                        if ($skip_check)
                                        {
                                            print OUTPUT_TESTGRP_FILE "          -skip_cic_check => 1,\n";
                                        }  
                                        print OUTPUT_TESTGRP_FILE ");\n\n";
                                        
                                        $seqgrp2_index++;
                                    }
                                    elsif ($seqgrp2_state =~ /CLEANUP|AUTORESPONDER/  )
                                    {
                                        # Egress side (seqgrp2) is a CLEANUP state machine
                                        $logger->debug(__PACKAGE__ . ".$sub Adding *CLEANUP [2]* WORKGROUP='$seqgrp2_workgroup' STATE='$seqgrp2_state'\n");
                                        
                                        # We do not care if CLEANUP is not at the bottom of the sequence group
                                        $seqgrp2_index++;
                                    }
                                    elsif ($seqgrp2_state =~ /^[1-9][0-9]*$/ )
                                    {
                                        my $state_description1; 
                                        unless  ($state_description1 = $tmpMgtsObjRef->getStateDesc(-full_statename => $seqgrp1_path . "States/" . $seqgrp1_workgroup . "/" . $seqgrp1_state . ".states")) {
                                            $logger->error(__PACKAGE__ . ".$sub Failed to get state machine description for \"" . $seqgrp1_path . $seqgrp1_workgroup . "/" . $seqgrp1_state  ."\"");
					    $error_found++;
                                            last;
                                        }
                                        $state1_timeout = $tmpMgtsObjRef->getStateTotalTime(-full_statename => $seqgrp1_path . "States/" . $seqgrp1_workgroup . "/" . $seqgrp1_state . ".states");
                                        my $state_description2; 
                                        unless  ($state_description2 = $tmpMgtsObjRef->getStateDesc(-full_statename => $seqgrp2_path . "States/" . $seqgrp2_workgroup . "/" . $seqgrp2_state . ".states")) {
                                            $logger->error(__PACKAGE__ . ".$sub Failed to get state machine description for \"" . $seqgrp2_path . $seqgrp2_workgroup . "/" . $seqgrp2_state  ."\"");
					    $error_found++;
                                            last;
                                        }
                                        $state2_timeout = $tmpMgtsObjRef->getStateTotalTime(-full_statename => $seqgrp2_path . "States/" . $seqgrp2_workgroup . "/" . $seqgrp2_state . ".states");
                                        my $state_timeout_string = "";
                                        if (($state1_timeout > 60) || ($state2_timeout > 60))  {
                                            if ($state1_timeout >= $state2_timeout) {
                                                $state_timeout_string = "          -timeout     => $state1_timeout,\n";
                                            } else {
                                                $state_timeout_string = "          -timeout     => $state2_timeout,\n";
                                            }
                                        }
                                        # We are an MGTS called test
                                        if ("$seqgrp1_state" eq "$seqgrp2_state")
                                        {
                                            # Great - 2 halves of the same test
                                            print OUTPUT_TESTGRP_FILE "execTest( -testid      => \"${seqgrp1_state}\",\n          -feature     => \"\$feature \",\n          -requirement => \"\$requirement\",\n          -mgts2       => \"${state_description2}\",\n          -mgts1       => \"${state_description1}\",\n${state_timeout_string});\n\n";
                                            $seqgrp1_index++;
                                            $seqgrp2_index++;
                                        }
                                        else
                                        {
                                            # check to see if egress state is in
                                            # the ingress seq grp. If not we have
                                            # an error and need to exit.
                                            my $seqgrp1_string = join "\n",@seqgrp1_states;
                                            if ($seqgrp1_string !~ /\/${seqgrp2_state} /)
                                            {
                                                $logger->error(__PACKAGE__ . ".$sub Invalid EGRESS sequence group '$seqgrp2'. Contains state machine '$seqgrp2_state' that is not contained in INGRESS seq grp '$seqgrp1'.\n");             
					        $error_found++;
                                                last;  
                                            }
    
                                            # Ingress test must be half call with no other half - i.e. call doesn't route.
                                            print OUTPUT_TESTGRP_FILE "execTest( -testid      => \"${seqgrp1_state}\",\n          -feature     => \"\$feature \",\n          -requirement => \"\$requirement\",\n          -mgts1       => \"${state_description1}\",\n${state_timeout_string});\n\n";
                                            $seqgrp1_index++;
                                        }
                                    }
                                    else 
                                    {
                                        $logger->error(__PACKAGE__ . ".$sub Invalid state machine id in sequence group '$seqgrp2'. SM_ID=\"${seqgrp2_workgroup}/${seqgrp2_state}\"");
					$error_found++;
                                        last;
                                    }
                                }
                                else
                                {
                                    $logger->error(__PACKAGE__ . ".$sub Invalid line in sequence group '$seqgrp2' Line\#${seqgrp2_index}=\"$seqgrp2_stateline\"\n");
				    $error_found++;
                                    last;
                                }
                            }
                            else 
                            {
                                $logger->error(__PACKAGE__ . ".$sub Invalid state machine id in sequence group '$seqgrp1'. SM_ID=\"${seqgrp1_workgroup}/${seqgrp1_state}\"");
				$error_found++;
                                last;
                            }
                        }
                        else
                        {
                            $logger->error(__PACKAGE__ . ".$sub Invalid line in sequence group '$seqgrp1' Line\#${seqgrp1_index}=\"$seqgrp1_stateline\"\n");
			    $error_found++;
                            last;
                        }
                    }
                }
            }
            else
            {
                $logger->error(__PACKAGE__ . ".$sub seqgrp1 undefined\"\n");             
            }
        }
        else
        {
            $logger->debug(__PACKAGE__ . ".$sub No substitution identified on line \"$line\"\n"); 
        }
        
        unless ($ignore_pod && ($line =~ /^=cut/ || $line =~ /^\#===========/ || $in_pod))
        {
            print OUTPUT_TESTGRP_FILE $line . "\n";
        }
    };

    close (OUTPUT_TESTGRP_FILE);
    close (TEMPLATE_FILE);
    
    if ($error_found > 0) {
        $logger->error(__PACKAGE__ . ".$sub Error found - leaving function");
        return 0;
    }		
    
    $logger->debug(__PACKAGE__ . ".$sub Leaving with retcode-1.");
    return 1;
}

return 1;

# vim: set ts=4 
