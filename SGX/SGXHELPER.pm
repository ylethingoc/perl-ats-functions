package SonusQA::SGX::SGXHELPER;

=head1 NAME

SonusQA::SGX::SGXHELPER - Perl module for Sonus Networks SGX interaction

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, Sonus::QA::Utilities::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

This is a place to implement frequent activity functionality, standard non-breaking routines.
Items placed in this library are inherited by all versions of SGX - they must be generic.

=head2 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);
use SonusQA::Base;
use SonusQA::UnixBase;
use Module::Locate qw / locate /;
use File::Basename;
use Tie::File;
use ATS;
our @ISA = qw(SonusQA::Base SonusQA::UnixBase);
my $logger = get_logger();
chomp ( my $whoami = qx/whoami/ );
my $appender = Log::Log4perl::Appender->new("Log::Dispatch::File",filename => "/tmp/sgxhelper_${whoami}.log",mode => "append");
$logger->add_appender($appender);
#my $layout = Log::Log4perl::Layout::PatternLayout->new("%d %p> %F{1}:%L %M -%m %n");
my $layout = Log::Log4perl::Layout::PatternLayout->new("%d %p> %L -%m %n");
$appender->layout($layout);
use vars qw($self);
use XML::Simple qw(:strict);

our $VERSION = "6.1";

use vars qw($self);

# Documentation format (Less comment markers '#'):

#=head3 $obj-><FUNCTION>({'<key>' => '<value>', ...});
#Example: 
#
#$obj-><FUNCTION>({...});
#
#Mandatory Key Value Pairs:
#        'KEY' => '<TYPE>'
#
#Optional Key Value Pairs:
#       none
#=cut
## ROUTINE:<FUNCTION>

# ******************* INSERT BELOW THIS LINE:

=head1 METHODS

=head2 confPlat()

 confPlat method configures the platform for the SGX based on the parameter input passed.The mandatory parameters are root user id and password,CE0 and CE1 hostname,number of boards and one protocol type and board type.Based on the number of boards you can specify the other protocol types and board types.This method should be invoked as omni user.
 This method uses conf_plat.xml present in same directory as SGXHELPER.pm

=over

=item Argument

 -rootuser
 -rootpass
 -sgx_ce0
     SGX primary CE0 hostname
 -sgx_ce1
     SGX secondary CE1 hostname or none
 -num_of_board
     number of boards in the SGX
 -protocol_1
     choose from A7,C7,CH7 or J7
 -board_1
     choose from PC0200,PS0204,PH0301
 -protocol_2
 -board_2
 -protocol_3
 -board_3
 -protocol_4
 -board_4
 -protocol_5
 -board_5

=item Returns 

 0 - When inputs are not present or When unable to Terminate Signalware and proceed to configure Platform or when errors are found during configure platform
 1 - Success when configure platform has been done properly

=item Notes 

  1> Even if for all  boards configuration is same ,specify the combination of protocol type and board type for each of the boards.
  2> Right now the following combinations of protocol type and board type are allowed
     A7 PC0200,A7 PH0301,C7 PC0200,C7 PH0301,J7 PC0200,J7 PH0301,J7 PS0204
  3> Maximum of 5 boards can be configured.
  4> CH7 is not supported now

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::confPlat( -rootuser => "root",-rootpass => "sonus",-sgx_ce0 => "calvin", -sgx_ce1 => "hobbes", -num_of_board => 2, -protocol_1 => "A7",-board_1 => "PC0200",-protocol_2 => "A7",-board_2 => "PC0200");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub confPlat {

    my ($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "confPlat()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
 
    # Set default values before args are processed
    my %a1 = ( -rootuser => undef,
               -rootpass => undef,
               -sgx_ce0 => undef,
               -sgx_ce1 => undef,
               -num_of_board => 0,
               -protocol_1 => undef,
               -board_1 => undef,
               -protocol_2 => undef,
               -board_2 => undef,
               -protocol_3 => undef,
               -board_3 => undef,
               -protocol_4 => undef,
               -board_4 => undef,
               -protocol_5 => undef,
               -board_5 => undef);

    while ( my ($key,$value) = each %args ) { $a1{$key} = $value; }

    # Variable Declarations
    my $i=0;
    my $numce=2;
    my ($x,$j,$set,$paramptr1,$paramptr,@paramset1,@paramset,@result,$numconf,$r,$mess,$p,$p1,$numconf1,@combo,@protocoltype,@boardtype,$numboard,$pname,$p2,$res,$counter,$countofboard,$pvalue,$selp);
    my $protoset = "";
    my $boardset="";
    my %prototype_boardtype = ('A7 PC0200' => 1,'A7 PH0301' => 1,'C7 PC0200' => 1,'C7 PH0301' => 1,'J7 PC0200' => 1,'J7 PS0204' => 1,'J7 PH0301' => 1);
    my $pcimb = 0;
    my $pcimb3 =0;

    # Set xml file which has inputs to configurePlatform
    $self->{LOCATION} = locate __PACKAGE__;
    my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm");
    $self->{DIRECTORY_LOCATION} = $path;
    my $xml = $self->{DIRECTORY_LOCATION} . "conf_plat.xml";
    my $config = XMLin($xml, ForceArray => 0, KeyAttr => 0);

    my $rootuser = $a1{-rootuser};
    my $rootpass = $a1{-rootpass};

    # Error is root user is not specified
    if (!defined $rootuser) {
        $logger->error(__PACKAGE__ . "$sub Root user id is not specified");
        return 0;
    } 

    # Error if root password is not specified
    if (!defined $rootpass) {
        $logger->error(__PACKAGE__ . "$sub Root password is not specified");
        return 0;
    } 

    # Error if sgx_ce0 is not specified 
    if (!defined $a1{-sgx_ce0}) {
        $logger->error(__PACKAGE__ . "$sub SGX primary ce name is not specified");
        return 0;
    } 

    # Error if sgx_ce1 is not specified
    if (!defined $a1{-sgx_ce1}) {
        $numce = 1;
    } 

    # Error is number of boards is not specified
    $numboard = $a1{-num_of_board};
    if ($a1{-num_of_board} eq 0) {
        $logger->error(__PACKAGE__ . "$sub Number of boards is not specified");
        return 0;
    } 

    # Extract protocol types and board types specified by user
    for ($i=1;$i<=$numboard;$i++) {
        foreach my $k (keys %a1) {
            if (($k =~ /protocol_$i/) && ($a1{$k} ne undef)) {
                push @protocoltype,$a1{$k};
            } 

            if (($k =~ /board_$i/) && ($a1{$k} ne undef)) {
                push @boardtype,$a1{$k};
            } 
        } # End foreach
    } # End foreach

    # Prepare array with combination of protocol type and board type for each board
    for ($i=0;$i<$numboard;$i++) {
        push @combo,(join "\ ",$protocoltype[$i],$boardtype[$i]); 
    } # End for

    # Error if protocol - board combination is invalid
    for ($i=0;$i<$numboard;$i++) {
        if(!defined($prototype_boardtype{$combo[$i]})) {

            $logger->error(__PACKAGE__ . "$sub Protocol and Board Type combination invalid");
            $logger->error(__PACKAGE__ . "$sub Valid combinations are /A7 PC0200/ or /A7 PH0301/ or /C7 PC0200/ or /C7 PH0301/ or  /J7 PC0200/ or  /J7 PS0204/ or /J7 PH0301/");
            return 0;

        } 
    } # End for

    # Join protocol names for verification stage 
    ($protoset = join " ",@protocoltype) =~ tr [ACJ] [acj];

    # Join board names for verification stage 
    $boardset = join " ",@boardtype ;

    # Count PCIMB and PCIMB3 boards 
    for ($r=0;$r<$numboard;$r++) {
        if (($boardtype[$r] =~ /PC0200/) or ($boardtype[$r] =~ /PS0204/))
            { $pcimb++; }
        if ($boardtype[$r] =~ /PH0301/)
            { $pcimb3++; }
    } # End for

    $conn->prompt('/[\$%#>\?:] +$/');

    # Check if signalware is stopped before proceeding to configureplatform
    $res = $self->checkSignalwareStopped();
   
    # If Signalware not stopped ,Executing Terminate 0 since configurePlatform cannot be run on running instance of SignalWare 
    if (!$res) { 
        $logger->debug(__PACKAGE__ . "$sub Executing Terminate 0 since signalware is not stopped");
        my @result = $conn->cmd("Terminate 0");

        # Check for error from Terminate 0
        foreach (@result) {
            if ($_ =~ /error/) {
                $logger->error(__PACKAGE__ . "$sub Terminate 0 has thrown an error , so we cannot run configureplatform");
                return 0; 
            } 
        } # End foreach

        # Wait for Signalware to stop if Terminate 0 has not thrown error
        sleep(8); 
        my $res1 = $self->checkSignalwareStopped();
        if (!$res1) {
            $logger->error(__PACKAGE__ . "$sub Unable to stop signalware");
            return 0;
        } 
    } 

    $logger->debug(__PACKAGE__ . "$sub **Start of configure Platform script execution**");
    @result = $conn->cmd("su $rootuser");
    @result = $conn->cmd("$rootpass");
 
    foreach (@result) {
        if ($_ =~ /Sorry|Incorrect password/i) {
            $logger->error(__PACKAGE__ . "$sub Unable to login to root");
            return 0;
        } 
    } # End foreach

    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("cd \$OMNI_HOME/conf");
    @result = $conn->cmd("./configurePlatform");
    $logger->debug(__PACKAGE__ . "$sub @result");

    # Passing common parameters 
    # Read the XML values into a PERL reference 
    foreach $set (@{$config->{set}}) {
        if ($set->{confset} =~ /Common Params/) {
            $numconf = $#{$set->{paramset}->{param}};
            for($x=0;$x<=$numconf;$x++) {
	        foreach $res (@result) {
                    if ($res =~ /Continue with configurePlatform procedure/) {
	                $x = $x+2;
                    } 
                } # End foreach
                $paramptr =  ${$set->{paramset}->{param}}[$x];
                my @vals = values(%$paramptr);
                $paramset[$x] = shift @vals;
            } # End for
        } 
    } # End foreach

    # Pass inputs to configureplatform based on user input & conf_plat.xml values
    foreach $p1 (@paramset) {
        @result = $conn->cmd("$p1");
        $logger->debug(__PACKAGE__ . "$sub $p1\n@result");

        # Pass the number of ces
        foreach $res (@result) {
            if ($res =~ /How many CEs/) {
                @result = $conn->cmd("$numce");
                $logger->debug(__PACKAGE__ . "$sub $numce\n@result");
            } 
        } # End foreach

        # Pass the SGX CE0 host name 
        foreach $res (@result) {
            if ($res =~ /Enter name of CE1/) {
                @result = $conn->cmd("$a1{-sgx_ce0}");
                $logger->debug(__PACKAGE__ . "$sub $a1{-sgx_ce0}\n@result");
            } 
        } # End foreach

        # Pass the SGX CE1 host name
        foreach $res (@result) {
            if ($res =~ /Enter name of CE2/) {
                @result = $conn->cmd("$a1{-sgx_ce1}");
                $logger->debug(__PACKAGE__ . "$sub $a1{-sgx_ce1}\n@result");
            } 
        } # End foreach

        # Pass the number of SS7 boards
        foreach $res (@result) {
            if ($res =~ /How many SS7 boards/) {
                @result = $conn->cmd("$numboard");
                $logger->debug(__PACKAGE__ . "$sub $numboard\n@result");
            } 
        } # End foreach

        foreach $res (@result) {
            if ($res =~ /configured the same way/) {
                @result = $conn->cmd("no");
                $logger->debug(__PACKAGE__ . "$sub no\n@result");
            } 
        } # End foreach

        foreach $res (@result) {
            if ($res =~ /Select protocol/) {
                $selp = $res;
            } # Enf if
        } # End foreach

        if ($selp =~ /Select protocol/) {
            last;
        } 

        sleep(1);
    } # End foreach    

    # Passing protocol/board specific parameters
    $conn->prompt('/[\$%#>\?:] +$/');
    for ($j=0;$j<$numce;$j++) {

        foreach $res (@result) {
            if ($res =~ /How many SS7 boards/) {
                @result = $conn->cmd("$numboard");
                $logger->debug(__PACKAGE__ . "$sub $numboard\n@result");
                sleep(1);
            } # Enf if
        } # End foreach

        foreach $res (@result) {
            if ($res =~ /configured the same way/) {
                @result = $conn->cmd("no");
                $logger->debug(__PACKAGE__ . "$sub no\n@result");
                sleep(1);
            } 
        } # End foreach

        for ($i=0;$i<$numboard;$i++) {
            my @paramset1;
            foreach $set (@{$config->{set}}) {
                if ($set->{confset} =~ $combo[$i]) {
                    $numconf1 = $#{$set->{paramset}->{param}};
                    for($x=0;$x<=$numconf1;$x++) {
                        $paramptr1 =  ${$set->{paramset}->{param}}[$x];
                        my @vals = values(%$paramptr1);
                        $paramset1[$x] = shift @vals;
                    } # End for
                } 
            } # End foreach

            foreach $res (@result) {
                if ($res =~ /Select protocol/) {
                    @result =  $conn->cmd("$protocoltype[$i]");
                    $logger->debug(__PACKAGE__ . "$sub $protocoltype[$i]\n@result");
                } 
            } # End foreach

            foreach $res (@result) {
                if ($res =~ /Select board type/) {
                    @result =  $conn->cmd("$boardtype[$i]");
                    $logger->debug(__PACKAGE__ . "$sub $boardtype[$i]\n@result");
                } 
            } # End foreach

            if ($combo[$i] =~ /J7 PS0204/) {
                for ($counter=0;$counter<=7;$counter++) {
                    @result = $conn->cmd("$paramset1[0]");
                    $logger->debug(__PACKAGE__ . "$sub $paramset1[0]\n@result");
                } # End for
                @result = $conn->cmd("$paramset1[1]");
                $logger->debug(__PACKAGE__ . "$sub $paramset1[1]\n@result");
                $logger->debug(__PACKAGE__ . "$sub Done");
                sleep(1);
            } 
            else  {
                foreach $p2 (@paramset1) {
                    @result = $conn->cmd("$p2");
                    $logger->debug(__PACKAGE__ . "$sub $p2\n@result");
                    sleep(2);
                } # End foreach
            } # End if 
        } # End for   
    } # End for       

    $conn->prompt('/[\$%#>\?:] +$/');
    foreach $res (@result) {
        if ($res =~ /Apply/) {
            @result = $conn->cmd("yes");
            $logger->debug(__PACKAGE__ . "$sub yes\n@result");
        } 
        if ($res =~ /Send configuration/) {
            @result = $conn->cmd("no");
            $logger->debug(__PACKAGE__ . "$sub no\n@result");
            @result = $conn->cmd("yes");
            $logger->debug(__PACKAGE__ . "$sub yes\n@result");
        } 
    } # End foreach

    # Verification Steps 
    # Extraction of important lines from configurePlatform.Conf 

    $conn->prompt('/[\$%#>\?:] +$/');
    my @NumberOfCEs = $conn->cmd("grep NumberOfCEs configurePlatform.Conf");
    my @CE1 =  $conn->cmd("grep \"CE\\\[1\\\]\" configurePlatform.Conf");
    my @CE2 =  $conn->cmd("grep \"CE\\\[2\\\]\" configurePlatform.Conf");
    my @NumberOfBoards1 = $conn->cmd("grep \"NumberOfBoards\\\[1\\\]\" configurePlatform.Conf");
    my @NumPcimbBoards1 =  $conn->cmd("grep \"NumPcimbBoards\\\[1\\\]\" configurePlatform.Conf");
    my @NumPcimb3Boards1 = $conn->cmd("grep \"NumPcimb3Boards\\\[1\\\]\" configurePlatform.Conf");
    my @BoardTypes1 = $conn->cmd("grep \"BoardTypes\\\[1\\\]\" configurePlatform.Conf");
    my @BoardProtocols1 = $conn->cmd("grep \"BoardProtocols\\\[1\\\]\" configurePlatform.Conf");
    my @NumberOfBoards2 = $conn->cmd("grep \"NumberOfBoards\\\[2\\\]\" configurePlatform.Conf");
    my @NumPcimbBoards2 =  $conn->cmd("grep \"NumPcimbBoards\\\[2\\\]\" configurePlatform.Conf");
    my @NumPcimb3Boards2 = $conn->cmd("grep \"NumPcimb3Boards\\\[2\\\]\" configurePlatform.Conf");
    my @BoardTypes2 = $conn->cmd("grep \"BoardTypes\\\[2\\\]\" configurePlatform.Conf");
    my @BoardProtocols2 = $conn->cmd("grep \"BoardProtocols\\\[2\\\]\" configurePlatform.Conf");

    # Extraction of important lines from multiconf.cnf 

    my @board_type = $conn->cmd("grep board_type multiconf.cnf");

    # Evaluation of values extracted from configurePlatform.Conf & multiconf.cnf 
    my $status = "NOTHING";
    my $error =0;
    my $item;

    # Verification steps for dual CE
    if ($numce == 2) {

        my  $countofboard = (($#board_type+1)/2) ;

        # Check if configurePlatform.Conf has correct number of CEs
        foreach $item (@NumberOfCEs) {

            $status =  ($item =~ /$numce/) ? "DONE" : "FAILURE - NumberOfCEs is incorrect";
            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @NumberOfCEs");
            } 
            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct SGX CE0 name
        foreach $item (@CE1) {

            $status =  ($item =~ /$a1{-sgx_ce0}/) ? "DONE" : "FAILURE - CE1 is incorrect";
            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @CE1");
            } 
            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++;
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct SGX CE1 name
        foreach $item (@CE2) {

            $status =  ($item =~ /$a1{-sgx_ce1}/) ? "DONE" : "FAILURE - CE2 is incorrect";
            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @CE2");
            } 
            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct number of boards for CE0
        foreach $item (@NumberOfBoards1) {

            $status =  ($item =~ /$numboard/) ? "DONE" : "FAILURE - NumberOfBoards1 is incorrect";
            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @NumberOfBoards1");
            } 
            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct board types for CE0
        foreach $item (@BoardTypes1) {

            $status = ($item =~ /$boardset/) ? "DONE" : "FAILURE - BoardTypes1 is incorrect";
            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @BoardTypes1");
            } 
            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        }

        # Check if configurePlatform.Conf has correct protocol types for CE0
        foreach $item (@BoardProtocols1) {

            $status = ($item =~ /$protoset/) ? "DONE" : "FAILURE - BoardProtocols1 is incorrect";

            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @BoardProtocols1");
            } 
            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct number of boards for CE1
        foreach $item (@NumberOfBoards2) {

            $status =  ($item =~ /$numboard/) ? "DONE" : "FAILURE - NumberOfBoards2 is incorrect";
            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @NumberOfBoards2");
            } 
            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct  board types for CE1
        foreach $item (@BoardTypes2) {

            $status = ($item =~ /$boardset/) ? "DONE" : "FAILURE - BoardTypes2 is incorrect";

            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @BoardTypes2");
            } 
            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct protocol types for CE1
        foreach $item (@BoardProtocols2) {

            $status = ($item =~ /$protoset/) ? "DONE" : "FAILURE - BoardProtocols2 is incorrect";
            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @BoardProtocols2");
            } 
            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct number of pcimb boards for CE0
        if ($pcimb >0 ) {
            foreach $item (@NumPcimbBoards1) {

                $status = ($item =~ /$pcimb/) ? "DONE" : "FAILURE - NumPcimbBoards1 is incorrect";
                if ($status =~ /DONE/) {
                    $logger->debug(__PACKAGE__ . "$sub Verification done for @NumPcimbBoards1");
                } 
                else { $logger->debug(__PACKAGE__ . "$sub $status");
                    $error++; 
                } # End if
            } # End foreach
        } 
 
        # Check if configurePlatform.Conf has correct number of pcimb3 boards for CE0
        if ($pcimb3 > 0) {
            foreach $item (@NumPcimb3Boards1) {

                $status = ($item =~ /$pcimb3/) ? "DONE" : "FAILURE - NumPcimbBoards1 is incorrect";
                if ($status =~ /DONE/) {
                    $logger->debug(__PACKAGE__ . "$sub Verification done for @NumPcimb3Boards1");
                } 
                else { $logger->debug(__PACKAGE__ . "$sub $status");
                    $error++; 
                } # End if
            } # End foreach
        } 

        # Check if configurePlatform.Conf has correct number of pcimb boards for CE1
        if ($pcimb > 0) {
            foreach $item (@NumPcimbBoards2) {

                $status = ($item =~ /$pcimb/) ? "DONE" : "FAILURE - NumPcimbBoards1 is incorrect";
                if ($status =~ /DONE/) {
                    $logger->debug(__PACKAGE__ . "$sub Verification done for @NumPcimbBoards2");
                } 
                else { $logger->debug(__PACKAGE__ . "$sub $status");
                    $error++; 
                } # End if
            } # End foreach
        } 

        # Check if configurePlatform.Conf has correct number of pcimb3 boards for CE1
        if ($pcimb3 > 0) {
            foreach $item (@NumPcimb3Boards2) {

                $status = ($item =~ /$pcimb3/) ? "DONE" : "FAILURE - NumPcimbBoards1 is incorrect";
                if ($status =~ /DONE/) {
                    $logger->debug(__PACKAGE__ . "$sub Verification done for @NumPcimb3Boards2");
                } 
                else { $logger->debug(__PACKAGE__ . "$sub $status");
                    $error++; 
                } # End if
            } # End foreach
        } 

        # Check if multiconf.cnf has correct boardtypes     
        for ($j=0;$j<$countofboard;$j++)  {

            $status = ($board_type[$j] =~ $boardtype[$j]) ? "DONE" : "FAILURE - BoardTypes are incorrect in multiconf.cnf";
            ($board_type[$j]) =~ s/^\s+//g;

            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for $board_type[$j]");
            } 
            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } #  End for
    } 

    # Verification for single CE
    else { 
 
        $countofboard = $#board_type+1;

        # Check if configurePlatform.Conf has correct number of CEs
        foreach $item (@NumberOfCEs) {

            $status =  ($item =~ /$numce/) ? "DONE" : "FAILURE - NumberOfCEs is incorrect";
            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @NumberOfCEs");
            } 
            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct CE hostname
        foreach $item (@CE1) {

            $status =  ($item =~ /$a1{-sgx_ce0}/) ? "DONE" : "FAILURE - CE1 is incorrect";

            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @CE1");
            } 

            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct number of boards
        foreach $item (@NumberOfBoards1) {

            $status =  ($item =~ /$numboard/) ? "DONE" : "FAILURE - NumberOfBoards1 is incorrect";

            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @NumberOfBoards1");
            } 

            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct board types
        foreach $item (@BoardTypes1) {

            $status = ($item =~ /$boardset/) ? "DONE" : "FAILURE - BoardTypes1 is incorrect";

            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @BoardTypes1");
            } 

            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct protocol types
        foreach $item (@BoardProtocols1) {

            $status = ($item =~ /$protoset/) ? "DONE" : "FAILURE - BoardProtocols1 is incorrect";

            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for @BoardProtocols1");
            } 

            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End foreach

        # Check if configurePlatform.Conf has correct number of pcimb boards
        if ($pcimb > 0) {
            foreach $item (@NumPcimbBoards1) {

                $status = ($item =~ /$pcimb/) ? "DONE" : "FAILURE - NumPcimbBoards1 is incorrect";

                if ($status =~ /DONE/) {
                    $logger->debug(__PACKAGE__ . "$sub Verification done for @NumPcimbBoards1");
                } 

                else { $logger->debug(__PACKAGE__ . "$sub $status");
                    $error++; 
                } # End if
            } # End foreach
        } 

        # Check if configurePlatform.Conf has correct number of pcimb3 boards
        if ($pcimb3 > 0) {
            foreach $item (@NumPcimb3Boards1) {

                $status = ($item =~ /$pcimb3/) ? "DONE" : "FAILURE - NumPcimbBoards1 is incorrect";

                if ($status =~ /DONE/) {
                    $logger->debug(__PACKAGE__ . "$sub Verification done for @NumPcimb3Boards1");
                } 

                else { $logger->debug(__PACKAGE__ . "$sub $status");
                    $error++; 
                } # End if
            } # End foreach
        } 

        # Check for boardtypes in multiconf.cnf
        for ($j=0;$j<$countofboard;$j++)  {

            $status = ($board_type[$j] =~ $boardtype[$j]) ? "DONE" : "FAILURE - BoardTypes are incorrect in multiconf.cnf";
            $board_type[$j] =~ s/^\s+//g;

            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ . "$sub Verification done for $board_type[$j]");
            } 

            else { $logger->debug(__PACKAGE__ . "$sub $status");
                $error++; 
            } # End if
        } # End for
    } # End Else

    # If errors are present return 0 else do swcommission
    if ($error > 0) {

        $logger->error(__PACKAGE__ . "$sub $error Errors present in configure Platform execution");
        return 0;
    } 
    else {

        $conn->prompt('/\# +$/');
        $logger->debug(__PACKAGE__ . "$sub  Starting swcommission");
        my @result = $conn->cmd(String => "./swcommission",
				Errmode => "die",
				Timeout => "240");         
        $logger->debug(__PACKAGE__ . "$sub swcommission returned @result MATCHED PROMPT:".$conn->last_prompt);

        @result =  $conn->cmd("echo \$?");
        chomp($result[0]);
        $logger->debug(__PACKAGE__ . "$sub ***$result[0]***");

        if (!$result[0]) {
            $logger->debug(__PACKAGE__ . "$sub *** Done swcommission ***");
            $conn->prompt('/[\$%#>\?:] +$/');
            @result = $conn->cmd("exit");
            return 1;
        } 
        else {
            $logger->error(__PACKAGE__ . "$sub *** Swcommission Failed ***");
            $conn->prompt('/[\$%#>\?:] +$/');
            @result = $conn->cmd("exit");
            return 0;
        } # End if
    } # End if
} # End sub confPlat

=head2 confNode()

confNode method configures the nodes for the SGX based on the parameter input passed.The mandatory parameters arenumber of nodes,and one node name and protocol type.Based on the number of nodes you wish to configure ,you may specify as many node -protocol pairs.If the old configuration needs to be maintained , then just use option => keep.This method should be invoked as omni user.This method uses conf_node.xml in same directory as SGXHELPER.pm.

=over

=item Arguments

 -option
     Specify "keep" if you want to retain the old configuration.
 -num_of_node
     number of nodes in the SGX
 -node_1
     choose from a7n1,c7n1,ch7n1,j7n1,a7m3ua1,c7m3ua1,j7m3ua1,ch7m3ua1(replace number accordingly)
 -protocol_1
     choose from a7,c7,j7,ch7,a7m3uasg,c7m3uasg,ch7m3uasg,j7m3uasg
 -node_2
 -protocol_2
 -node_3
 -protocol_3
 -node_4
 -protocol_4
 -node_5
 -protocol_5

=item Return Values

 1- Success
 0- Failure

=item Notes

  1>  Even if for all nodes, configuration is same ,specify the combination of protocol type and board type for each of the boards.
  2> Maximum of 5 nodes can be configured.
  3> When option = keep , we do not need to specify the other arguments.

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::confNode(-num_of_node => 2,node_1 => "a7n1" , protocol_1 => "a7" ,node_2 => "a7m3ua1",-protocol_2 => "a7m3uasg");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub confNode {

    my ($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "confNode()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # Set default values before args are processed
    my %a1 = (  -option => undef,
                -num_of_node => 0,
                -node_1 => undef,
                -protocol_1 => undef,
                -node_2 => undef,
                -protocol_2 => undef,
                -node_3 => undef,
                -protocol_3 => undef,
                -node_4 => undef,
                -protocol_4 => undef,
                -node_5 => undef,
                -protocol_5 => undef);

    # Storing user input into %a1 table
    while ( my ($key,$value) = each %args ) { $a1{$key} = $value; }

    # Variable declarations
    my $i=0;
    my $numce=2;
    my $keyset1 = "";
    my %nodename_proto_combo = ('a7 a7' => 1,'a7m3ua a7m3uasg' => 1,'c7 c7' => 1,'c7m3ua c7m3uasg' => 1,'j7 j7' => 1,'j7m3ua j7m3uasg' => 1,'ch7 ch7' => 1,'ch7m3ua ch7m3uasg' => 1);
    my $j=1;
    my $numnodes =0;
    my $l="";
    my $input = "";
    my (@inputstring,@opt,$numconf1,@paramset1,$p2,$x,@PROTOCOL,@NODENAME,@OPTIONS,$option,@op,$p,$nod,$config,$paramptr1,@c1,$obj,$sgxobj,$set,$keys1,$z,@NODE,$status,$error,$s,@paramset,@nodename,@protocol,@combo,@noden,%opset);

    # Set xml file which has inputs to configurePlatform
    $self->{LOCATION} = locate __PACKAGE__;
    my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm");
    $self->{DIRECTORY_LOCATION} = $path;
    my $xml = $self->{DIRECTORY_LOCATION} . "conf_node.xml";
    $config = XMLin($xml, ForceArray => 0, KeyAttr => 0);

    $numnodes = $a1{-num_of_node}; 

    # Error if number of nodes is not specified and option is not keep 
    if ($a1{-option} ne "keep" && $numnodes eq 0) {
        $logger->error(__PACKAGE__ . "$sub Number of nodes is not specified");
        return 0;
    } 

    # Get value of $SHM from SignalWare
    my @SHM = $conn->cmd("echo \$SHM");
    chomp($SHM[0]);

    if ($SHM[0] eq "") {
        $logger->error(__PACKAGE__ . ".$sub SHM value is not defined, please check environment");
        return 0;
    }

    # Extract input string to be passed into configurenodes script
    for ($i=1;$i<=$numnodes;$i++) {

        my $node = "-node_".$i;
        my $proto = "-protocol_".$i;
        push @inputstring,$a1{$node};
        push @inputstring,$a1{$proto};  
        push @noden,$a1{$node};
        if ($a1{$node} =~ /c7m3ua/ or $a1{$node} =~ /a7m3ua/ or $a1{$node} =~ /j7m3ua/ or $a1{$node} =~ /ch7m3ua/) 
            { substr($a1{$node},-1,1) = ""; }
        else { substr($a1{$node},-2,2) = ""; }
        push @nodename,$a1{$node}; 
        push @protocol,$a1{$proto};

    } # End for

    $input = join "\ ",@inputstring;

    # Prepare combination string with node name and protocol
    for ($i=0;$i<$numnodes;$i++) {
        push @combo,(join "\ ",$nodename[$i],$protocol[$i]);
    } # End for

    # Check user input for valid node and protocol combination
    for ($i=0;$i<$numnodes;$i++) {

        # Is the nodename and protocol combo (held in $combo[$i] ) also defined in the hash ?
        if(!defined($nodename_proto_combo{$combo[$i]})) { 

            $logger->error(__PACKAGE__ . "$sub Node name and Protocol combination invalid");
            $logger->error(__PACKAGE__ . "$sub Valid combinations are /a7n1 a7/ or /a7m3ua1 m3uasg/ or /c7n1 c7/ or /c7m3ua1 m3uasg/ or  /j7n1 j7/ or  /j7m3ua1 m3uasg/ or /ch7n1 ch7/ or /ch7m3ua1 ch7m3uasg/");
            return 0;
        } 
    } # End for

    $conn->prompt('/[\$%#>\?:] +$/');
    my @result = $conn->cmd("cd \$OMNI_HOME/bin");

    # Check user option whether keep or clean
    if ($a1{-option} eq "keep") {
        $logger->debug(__PACKAGE__ . "$sub Running Configure Nodes with option Keep");
        @result = $conn->cmd("./configureNodes -keep");
        $logger->debug(__PACKAGE__ . "$sub @result");
        foreach (@result) {
            if ($_ = /not licensed/) {
                $logger->error(__PACKAGE__ . "$sub License is not available on the system,please check license file before proceeding");
                return 0;
            } 
        } # End foreach
    } 
    else {
        @result = $conn->cmd("./configureNodes -clean");
        foreach (@result) {
            if ($_ =~ /not licensed/) {
                $logger->error(__PACKAGE__ . "$sub License file is not available on the system,please check license file before proceeding");
                return 0;
            } 
            if ($_ =~ /error/) {
                $logger->error(__PACKAGE__ . "$sub Errors occurred while executing configureNodes");
                return 0;
            } 
        } # End foreach

        my @result1 = $conn->cmd("y");
        $logger->debug(__PACKAGE__ ."$sub @result");
        $logger->debug(__PACKAGE__ ."$sub @result1");
        $conn->prompt('/[\$%#>\?:] +$/');

        # Execute configureNodes with user input string
        @result = $conn->cmd("./configureNodes $input");
        @result1 = $conn->cmd("no");
        $logger->debug(__PACKAGE__ . "$sub @result");
        $logger->debug(__PACKAGE__ ."$sub @result1");

        # Read the XML into a PERL reference 
        for ($i=0;$i<$numnodes;$i++) {

            my @paramset1;
            foreach $set (@{$config->{set}}) {

                if ($set->{confset} eq $combo[$i]) {
                    $numconf1 = $#{$set->{paramset}->{param}};
                    my @tmp="";
                    my $k="";
                    for($x=0;$x<=$numconf1;$x++) {

                        $paramptr1 =  ${$set->{paramset}->{param}}[$x];
                        my @vals = values(%$paramptr1);
                        if ($vals[0] ne "") {

                            $paramset1[$x] = shift @vals;
		        } 

                        if ($paramset1[$x] eq "y") {
                            my @keys = keys(%$paramptr1);
                            $keys1 = shift @keys;
                            push(@tmp,$keys1);
                        } 

                    } # End for

                    @tmp = sort @tmp;
                    for ($z=1;$z<=2;$z++) {
                        if ($tmp[$z] =~ /ch7sccp/) {
                            $l = $tmp[$z];
                            $tmp[$z] = $tmp[$z+1];
                            $tmp[$z+1] = $l;
                        } 
                    } # End for

                    foreach $s (@tmp) {
                        $k = join " ",$k,$s;
                    } # End foreach
                    $k =~ s/^\s+//g;
                    $opset{$set->{confset}} = $k;

                }    
            } # End foreach  
           
            # Pass in the values for configureNodes from xml file 
            foreach $p2 (@paramset1) {

                sleep(2);
                $conn->prompt('/[\$%#>\?:] +$/');
                my @result = $conn->cmd("$p2");
                $logger->debug(__PACKAGE__ ."$sub $p2");
                $logger->debug(__PACKAGE__ ."$sub @result");

            } # End foreach
        } # End for

        # Verification Steps #
        # Extraction of important lines from DFcat configureNodes.Conf.$SHM[0] #
        @PROTOCOL = $conn->cmd("DFcat configureNodes.Conf.\$SHM | grep PROTOCOL");
        @NODENAME = $conn->cmd("DFcat configureNodes.Conf.\$SHM | grep NODENAME");
        @OPTIONS = $conn->cmd("DFcat configureNodes.Conf.\$SHM | grep OPTIONS");

        foreach $option (@OPTIONS) {
            @op = split /=/,$option;
            @op = split /\"/,$op[1];
            $op[1] =~ tr/[A-Z]/[a-z]/;
            $op[1] =~ s/^\s+|\s+$//g;
            push(@opt,$op[1]);
        } # End foreach

        # Evaluation of values extracted from DFcat configureNodes.Conf.$SHM[0] & DFcat tapdes.$SHM[0] #
        $status = "NOTHING";
        $error =0;

        for ($i=0;$i<$numnodes;$i++) {

            my @err;
            $protocol[$i] =~ tr/[a-z]/[A-Z]/;

            $status = ($PROTOCOL[$i] =~ $protocol[$i]) ? "DONE" : "FAILURE - $protocol[$i] configuration is incorrect";
            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ ."$sub Verification done for $PROTOCOL[$i]"); }
            else { $logger->debug(__PACKAGE__ ."$sub $status");
                $error++; }

            $status = ($NODENAME[$i] =~ $noden[$i]) ? "DONE" : "FAILURE - $noden[$i] configuration is incorrect";
            if ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ ."$sub Verification done for $NODENAME[$i]"); }
            else { $logger->debug(__PACKAGE__ ."$sub $status");
                $error++; }

            $status = ($opt[$i] =~ $opset{$combo[$i]}) ? "DONE" : "FAILURE - $opset{$combo[$i]} configuration is incorrect";
            if  ($status =~ /DONE/) {
                $logger->debug(__PACKAGE__ ."$sub Verification done for $OPTIONS[$i]"); }
            else { $logger->debug(__PACKAGE__ ."$sub $status");
                $error++; }

            @NODE = $conn->cmd("DFcat tapdes.\$SHM | grep $noden[$i]");
            my $found=0;

            foreach $nod (@NODE) {
                $nod =~ s/\n//g;

                if ($combo[$i] eq "a7 a7" && $opt[$i] =~ /ca7/ && $nod =~ /$noden[$i]_TCMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "a7 a7" && $opt[$i] =~ /a7iu/ && $nod =~ /$noden[$i]_ISMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "a7m3ua a7m3uasg" && $opt[$i] =~ /a7iu/ && $nod =~ /$noden[$i]_ISMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "a7m3ua a7m3uasg" && $opt[$i] =~ /a7sccp/ && $nod =~ /$noden[$i]_SCMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "c7 c7" && $opt[$i] =~ /c7iu/ && $nod =~ /$noden[$i]_ISMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "c7 c7" && $opt[$i] =~ /c7ip/ && $nod =~ /$noden[$i]_IPMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "c7 c7" && $opt[$i] =~ /ac7/ && $nod =~ /$noden[$i]_TCMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "c7m3ua c7m3uasg" && $opt[$i] =~ /c7sccp/ && $nod =~ /$noden[$i]_SCMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "c7m3ua c7m3uasg" && $opt[$i] =~ /c7iu/ && $nod =~ /$noden[$i]_ISMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "c7m3ua c7m3uasg" && $opt[$i] =~ /c7ip/ && $nod =~ /$noden[$i]_IPMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "j7 j7" && $opt[$i] =~ /j7iu/ && $nod =~ /$noden[$i]_ISMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "j7m3ua j7m3uasg" && $opt[$i] =~ /j7sccp/ && $nod =~ /$noden[$i]_SCMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "j7m3ua j7m3uasg" && $opt[$i] =~ /j7iu/ && $nod =~ /$noden[$i]_ISMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "ch7 ch7" && $opt[$i] =~ /chiu/ && $nod =~ /$noden[$i]_ISMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "ch7 ch7" && $opt[$i] =~ /ach7/ && $nod =~ /$noden[$i]_TCMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "ch7m3ua ch7m3uasg" && $opt[$i] =~ /ch7sccp/ && $nod =~ /$noden[$i]_SCMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "ch7m3ua ch7m3uasg" && $opt[$i] =~ /chiu/ && $nod =~ /$noden[$i]_ISMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "ch7m3ua ch7m3uasg" && $opt[$i] =~ /ach7/ && $nod =~ /$noden[$i]_TCMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "ch7 ch7" && $opt[$i] =~ /chtu/ && $nod =~ /$noden[$i]_TPMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "ch7m3ua ch7m3uasg" && $opt[$i] =~ /chtu/ && $nod =~ /$noden[$i]_TPMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "c7 c7" && $opt[$i] =~ /c7tu/ && $nod =~ /$noden[$i]_TPMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

                if ($combo[$i] eq "c7m3ua c7m3uasg" && $opt[$i] =~ /c7tu/ && $nod =~ /$noden[$i]_TPMG/) {
                    $logger->debug(__PACKAGE__ ."$sub Verification done for $nod");
                    $found++;
                } 

            } # End foreach    

            my $k = $opset{$combo[$i]};
            my $c = 0;
            @c1 = split /\s/,$k;
            $c = $#c1;

            if ($error > 0) {
                $logger->error(__PACKAGE__ . "$sub FAILURE - configureNodes.Conf.\$SHM has errors");
                return 0;
            } 

            if ($found != ($c+1)) {

                $logger->error(__PACKAGE__ . "$sub FAILURE - tapdes.\$SHM has errors");
                return 0;
            } 
        } # End for (numnodes)    
    } # End if (configurenodes -clean)  
    return 1;
} # End sub confNode

=head2 confRsrc()

confRsrc method configures the resources for the SGX with Client Server option or without based on parameter inputs.option parameter should be specified either as CS or S.If option not specified default is "no client server configuration".Root user id and password are mandatory parameters. This method should be invoked as omni user.

=over

=item Arguments

-option 
   CS for Client Server configuration
   S for without Client Server Configuration
-rootuser
   root user id for sgx 
-rootpass
   root password for sgx

=item Return

 1- Success
 0-Failure

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::confRsrc(-option => "CS");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub confRsrc {

    my ($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "confRsrc()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # Set default values before args are processed
    my %a1 = ( -option => "S",
               -rootuser => undef,
               -rootpass => undef);

    # Store values into %a1
    while ( my ($key,$value) = each %args ) { $a1{$key} = $value; }

    # Variable declaration
    my $i=0;
    my (@result,$sgxobj,$std_sq_max_size,$std_ce_no_tx_lb,$std_ce_tx_ring_size);
    my (@sq_max_size,$sq_max,@ce_no_tx_lb,$ce_no,@ce_tx_ring_size,$ce_tx);
    my ($s,$k,@lineset,$st);
    my $rootuser = $a1{-rootuser};
    my $rootpass = $a1{-rootpass};
 
    # Error if root user is not specified 
    if (!defined $rootuser) {
        $logger->error(__PACKAGE__ . "$sub root user not specified");
        return 0;
    }

    # Error if root password is not specified
    if (!defined $rootpass) {
        $logger->error(__PACKAGE__ . "$sub root password not specified");
        return 0;
    }

    # Get value of $SHM from SignalWare
    my @SHM = $conn->cmd("echo \$SHM");
    chomp($SHM[0]);

    if ($SHM[0] eq "") {
        $logger->error(__PACKAGE__ . ".$sub SHM value is not defined, please check the system");
        return 0;
    }

    # Check if DFdaemon is running before doing DF operations
    my @res1 = $conn->cmd("ps -aef | grep DFdaemon | grep -v grep");
    chomp($res1[0]);

    if ($res1[0] !~ /DFdaemon/) {
        $logger->error(__PACKAGE__ . ".$sub DFdaemon is not running");
        return 0;
    }

    $logger->debug(__PACKAGE__ . "$sub Logging in as root user");

    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("su $rootuser");
    @result = $conn->cmd("$rootpass");

    foreach (@result) {
        if ($_ =~ /Sorry|Incorrect password/i) {
            $logger->error(__PACKAGE__ . "$sub Unable to login to root");
            return 0;
        } 
    } # End foreach

    @result = $conn->cmd("cd /export/home/sonusComm/blades/sgx/omni");
    $logger->debug(__PACKAGE__ . "$sub Running ./sonusAgtSetup.sh start");
    @result = $conn->cmd("./sonusAgtSetup.sh start");
    $logger->debug(__PACKAGE__ . "$sub @result");

    foreach (@result) {
        if ($_ =~ /error/) {
            $logger->error(__PACKAGE__ . ".$sub Errors present during execution of sonusAgtSetup.sh script");
            return 0;
        } 
    } # End foreach

    $logger->debug(__PACKAGE__ . "$sub Exit from root login");
    @result = $conn->cmd("exit");
    $conn->prompt('/[\$%#>\?:] +$/');

    @result = $conn->cmd("cd \$OMNI_HOME/conf");
    if ($a1{-option} eq "CS") {
        $logger->debug(__PACKAGE__ . "$sub This configuration is meant for Client Server SGX Only");
        $logger->debug(__PACKAGE__ . "$sub Running ./configureSwcsServer -nch -hi 2 -ht 12 as omni user");
        @result = $conn->cmd("./configureSwcsServer -nch -hi 2 -ht 12");
        $logger->debug(__PACKAGE__ . "$sub @result");
        foreach (@result) {
            if ($_ =~ /error/) {
                $logger->error(__PACKAGE__ . ".$sub Errors present during execution of configureSwcsServer script");
                return 0;
            } 
        } # End foreach
    } 

    $conn->prompt('/\$ +$/');    
    $logger->debug(__PACKAGE__ . "$sub Running ./configureMomqEventSev as omni user");
    @result = $conn->cmd(String => "./configureMomqEventSev",Timeout => "240",Errmode => "die");
    $logger->debug(__PACKAGE__ . "$sub @result");

    foreach (@result) {
        if ($_ =~ /error/) {
            $logger->error(__PACKAGE__ . ".$sub Errors present during execution of configureMomqEventSev script");
            return 0;
        } 
    } # End foreach

    $logger->debug(__PACKAGE__ . "$sub Logging in as root user");
    $conn->prompt('/[Password:] +$/');
    @result = $conn->cmd("su - $rootuser");
    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("$rootpass");

    foreach (@result) {
        if ($_ =~ /Sorry|Incorrect password/i) {
            $logger->error(__PACKAGE__ . "$sub Unable to login to root");
            return 0;
        } 
    } # End foreach

    $conn->prompt('/[\$%#>\?:] +$/');
    @result=$conn->cmd("rm -f cestart.\$SHM");

    $std_sq_max_size = "set sq_max_size=200";
    $std_ce_no_tx_lb = "set ce:ce_no_tx_lb=1";
    $std_ce_tx_ring_size = "set ce:ce_tx_ring_size=8192";
    @sq_max_size = $conn->cmd("grep -i  sq_max_size /etc/system");
    chomp($sq_max_size[0]);
    @ce_no_tx_lb = $conn->cmd("grep -i  ce_no_tx_lb /etc/system");
    chomp($ce_no_tx_lb[0]);
    @ce_tx_ring_size = $conn->cmd("grep -i  ce_tx_ring_size /etc/system");
    chomp($ce_tx_ring_size[0]);

    if ($sq_max_size[0] !~ "set sq_max_size=200") {
        push(@lineset,$std_sq_max_size);
    }

    if ($ce_no_tx_lb[0] !~ "set ce:ce_no_tx_lb=1") {
        push(@lineset,$std_ce_no_tx_lb);
    }

    if ($ce_tx_ring_size[0] !~ "set ce:ce_tx_ring_size=8192") {
        push(@lineset,$std_ce_tx_ring_size);
    }

    if ($#lineset != -1) {
        @result =  $conn->cmd("rm -rf /etc/tmp.txt");
        @result =  $conn->cmd("cat /etc/system >> /etc/tmp.txt");
        foreach $st (@lineset) {
            @result = $conn->cmd("echo $st >> /etc/tmp.txt");
        } # End foreach

        @result =  $conn->cmd("cp /etc/tmp.txt /etc/system");

        @sq_max_size = $conn->cmd("grep -i  sq_max_size /etc/system");
        @ce_no_tx_lb = $conn->cmd("grep -i  ce_no_tx_lb /etc/system");
        @ce_tx_ring_size = $conn->cmd("grep -i  ce_tx_ring_size /etc/system");
    } 

    @result = $conn->cmd("exit");
    $conn->prompt('/[\$%#>\?:] +$/');
    $logger->debug(__PACKAGE__ . "$sub Running ./configureCeScore as omni user");
    @result = $conn->cmd(String => "./configureCeScore",Timeout => "120",Errmode => "die");
    $logger->debug(__PACKAGE__ . "$sub @result");

    foreach (@result) {
        if ($_ =~ /error/) {
            $logger->error(__PACKAGE__ . ".$sub Errors present during execution of configureCeScore script");
            return 0;
        } 
    } # End foreach

    @result = $conn->cmd("DFcat cestart.\$SHM");
    $logger->debug(__PACKAGE__ . "$sub @result");
    chomp($result[0]);
    my @result2 = $conn->cmd("echo \$?");
    chomp($result2[0]);

    # Check on command results and see if DFcat was successful
    if (($result[0] =~ /failed/) || ($result2[0] != 0)) {
        $logger->error(__PACKAGE__ . ".$sub DFcat was not successful,File cestart.\$SHM was not found");
        $logger->error(__PACKAGE__ . ".$sub $_");
        return 0;
    }

    @result = $conn->cmd("DFcat cestart.\$SHM > \$OMNI_HOME/conf/cestart.\$SHM");
    
    return 1;
} # End sub confRsrc

=head2 confDFFile()

confDFFile method configures the files in the distributed file system of the sgx based on the release version,protocol,network configuration,node names.The actual values for the DF files will be got from the <version>.txt file in ats_repos/lib/perl/SonusQA/SGX/ folder.

=over

=item Arguments

 -protocol
    specify the protocol for the different nodes(choose from A7,C7,J7,CH7) seperated by comma
 -network_config
    specify the network config for the different nodes seperated by comma (GR or CS)
 -node_name
    specify the list of node names(a7n[1..5],c7n[1..5],j7n[1..5],ch7n[1..5],a7m3ua[1..5]..)

=item Return Values

 1 - Success
 0 - Failure

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::confDFFile(-protocol => "A7",-network_config => "GR",-node_name => "a7m3ua1");

 If more than one node,specify as below,
 \$obj->SonusQA::SGX::SGXHELPER::confDFFile(-protocol => "A7,A7",-network_config=> "GR,CS",-node_name => "a7m3ua1,a7n1");
=item Notes

 The version in sgx will be derived using "pkginfo -l SONSgxVer".Based on the version in the system,protocol specified and network configuration,specific set of file types to be created and flags to be set will be chosen.Files will be created based on number of node names will be placed in the distributed file system.After all files are configured sgx will be started. When network configuration is GR, configuration meant for M3UA will be applied.

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub confDFFile() {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "confDFFile()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($version,$mat);
    my $list_of_files; # List of DF file names extracted from version file
    
    # Get value of $SHM from SignalWare
    my @SHM = $conn->cmd("echo \$SHM");
    chomp($SHM[0]);

    if ($SHM[0] eq "") {
        $logger->error(__PACKAGE__ . ".$sub SHM value is not defined, please check environment");
        return 0;
    }

    # Check if DFdaemon is running before doing DF operations
    my @res1 = $conn->cmd("ps -aef | grep DFdaemon | grep -v grep");
    chomp($res1[0]);

    if ($res1[0] !~ /DFdaemon/) {
        $logger->error(__PACKAGE__ . ".$sub DFdaemon is not running");
        return 0;
    }

    # Check if all arguments are specified if not return 0
    foreach (qw/ -protocol -network_config -node_name/) { unless ( $args{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return 0; } }

    # Extract protocol ,node names and network config into arrays
    my @nodelist = split ",",$args{-node_name};
    my @protolist = split ",",$args{-protocol};
    my @configlist = split ",",$args{-network_config};
    $#nodelist++;
    $#protolist++;
    $#configlist++;
    my $num_of_nodes = $#nodelist;
  
    # Check if number of protocol and config match with number of node names 
    if ($#protolist ne $num_of_nodes) {
        $logger->error(__PACKAGE__ . ".$sub The number of protocol specified is not equal to number of nodes specified");
        return 0;
    }

    if ($#configlist ne $num_of_nodes) {
        $logger->error(__PACKAGE__ . ".$sub The number of network config specified is not equal to number of nodes specified");
        return 0;
    }

    # Check the version in SignalWare and see if it is greater than 6.1.3
    my $cmd = "pkginfo -l SONSgxVer";
    my @result = $conn->cmd($cmd);

    foreach (@result) {
        
        chomp($_);

        # Check for error
        if (m/error/i){
            $logger->error(__PACKAGE__ . ".$sub CMD: $cmd CMD RESULT: $_");
            return 0;
        }

        # Extract VERSION from command output
        if (m/VERSION/) {
            $version = $_;
            substr($version,0,13) = "";
            substr($version,-6,6) = "";
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub SGX Version is $version");

    # Set the version file for getting the df file settings
    $self->{LOCATION} = locate __PACKAGE__;
    my ($name,$path,$suffix) = fileparse($self->{LOCATION},"\.pm");
    $self->{DIRECTORY_LOCATION} = $path;
    my $settings = $self->{DIRECTORY_LOCATION} . "$version.txt";

    # Check if $version.txt exists in same directory as SGXHELPER.pm
    if (!(-e $settings)) {
        $logger->error(__PACKAGE__ . ".$sub File $settings is missing.Please create $version.txt for DF file configuration to proceed");
        return 0;
    } 
    else {
        $logger->debug(__PACKAGE__ . ".$sub File $settings is found and will be used for the DF file configuration");
    } # End if

    # Extract filenames from $version.txt from the line "List of Files"
    open (INPUTFILE,$settings);
    my @lines = <INPUTFILE>;
    close INPUTFILE;
    
    foreach (@lines) {
        if (m/List of Files/) {
            my @temp = split /:/,$_; 
            $list_of_files = $temp[1];
            chomp($list_of_files);
        }
    } # End foreach

    ($list_of_files) =~ s/^\s//g;
    my @list = split / /,$list_of_files;

    # Start loop for node list 
    for (my $i=0;$i < $#nodelist;$i++) {

        # List of files which need to be created 
        foreach (@list) {
            my $send_ucic = 0; # Flag to decide whether to add common values into issp_conf_info
            my $file = $_;
            my ($filename);

            # For csf file it is not node specific so only attach the $SHM
            if ($file =~ /csf/) {
                $filename = join ".",$file,$SHM[0];
            } 

            # For usam_conf_info ,it is not node specific and does not contain the $SHM
            elsif ($file =~ /usam_conf_info/) {
                $filename = $file;
            } #End elsif
           
            # For issp_conf_info , check if isup_conf_info file has an entry SEND_UCIC=E
            # If entry absent,then Common Values mentioned for issp_conf_info should not be added
            elsif ($file =~ /issp_conf_info/) {
                my @result3 = $conn->cmd("DFcat isup_conf_info.$nodelist[$i].$SHM[0] | grep \"SEND_UCIC\=E\" | grep -v grep");
                chomp($result3[0]);
                if ($result3[0] =~ /SEND_UCIC/) {
                    $send_ucic = 1;
                } #End if
                $filename = join ".",$file,$nodelist[$i],$SHM[0];
            } # End elsif

            # For all other files append the node name and the $SHM to the file name
            else {
                $filename = join ".",$file,$nodelist[$i],$SHM[0];
            } # End if
    
            # Remove any $filename.tmp files in the /tmp folder
            $cmd = "rm -f /tmp/$filename.tmp";
            @result = $conn->cmd($cmd);

            # Create a new empty file for writing the flags from $version.txt
            @result = $conn->cmd("touch /tmp/$filename.tmp");

            # Open $version.txt file and read line by line to check for values
            open (INPUTFILE,$settings);
            my @lines = <INPUTFILE>;

            foreach (@lines) {
                if (m/.*($file)\s+(\/)(\w+)\s+(\w+)(\/)\s+(\")(\w+)/) {
                    my $group = join " ",$3,$4;
                    my @f = split /"/,$_;
                    my @flags = split /"/,$f[1]; 
                    @flags = split /,/,$flags[0];

                    # All flags mentioned as Common Values will be written onto DF files
                    # Other flags will be written into DF file based on the config type and protocol specified by the user and the tags in $version file such as Common CS/Common GR/Common A7/Common C7/Common J7
                   
                    if (($group =~ /Common Values/ && $file !~ /issp_conf_info/ && !$send_ucic) || ($group =~ /Common Values/ && $file =~ /issp_conf_info/ && $send_ucic) || ($group =~ /Common CS/ && $configlist[$i] =~ /CS/) || ($group =~ /Common GR/ && $configlist[$i] =~ /GR/) || ($group =~ /Common A7/ && $protolist[$i] =~ /A7/) || ($group =~ /Common C7/ && $protolist[$i] =~ /C7/) || ($group =~ /Common J7/ && $protolist[$i] =~ /J7/) || ($group =~ /Common CH7/ && $protolist[$i] =~ /CH7/)) { 

                        foreach (@flags) {

                            $cmd = "echo $_ >> /tmp/$filename.tmp";
                            @result = $conn->cmd($cmd);                      

                        } # End foreach    
                    } 
                } 
            } # End foreach

            # Close the df_setting file
            close INPUTFILE;

            # Copy file from /tmp folder to $OMNI_HOME/tmp and DFconvert
            @result = $conn->cmd("mv /tmp/$filename.tmp \$OMNI_HOME/conf/$filename");
            @result = $conn->cmd("cd \$OMNI_HOME/conf");
            @result = $conn->cmd("DFconvert $filename");
            chomp($result[0]);
            my @result2 = $conn->cmd("echo \$?");
            chomp($result2[0]);

            # Check on command results and see if DFconvert was successful
            if (($result[0] =~ /Cannot open/) || ($result2[0] != 0)) {
                $logger->error(__PACKAGE__ . ".$sub DFconvert was not successful");
                return 0;
            }
            else {
                $logger->debug(__PACKAGE__ . ".$sub DF File $filename was created successfully");
            }

        } # End for loop for file list

    } # End for loop for nodelist  

    # Return 1 when all files are created properly
    $logger->debug(__PACKAGE__ . ".$sub All DF Files were created successfully");
    return 1;

} # End sub confDFFile()

=head2 dfCheckFlag()

dfCheckFlag method checks a file in the distributed file system for a file entry.
The mandatory arguments are filename,flag_name.If the flag has a value attached to it ,then we need to specify the flag value.

=over

=item Arguments

 -filename
    specify the DF file name
 -flag_name
    specify the name of the flag - for example - UA_GEOGRAPHIC_REDUNDANCY
 -flag_value
    specify the value related to the flag - for example - TRUE

=item Return Values

  1 - Success - string and value are present in the file
  0 - Failure - string and value not present in the file or file not present or filename/flagname not specified

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::dfCheckFlag(-filename => "omni_conf_info.a7n1.1040",-flag_name => "UA_GEOGRAPHIC_REDUNDANCY",-flag_value => "TRUE");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub dfCheckFlag() {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "dfCheckFlag()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $filename = undef;
    my $flagname = undef;
    my $flagvalue = "";

    $filename = $args{-filename};
    $flagname = $args{-flag_name};
    $flagvalue = $args{-flag_value};

    # Error if filename is not set
    if (!defined $filename) {

        $logger->error(__PACKAGE__ . ".$sub file name is not specified");
        return 0;
    }

    # Error if flag name is not set
    if (!defined $flagname) {
       
        $logger->error(__PACKAGE__ . ".$sub flag name is not specified");
        return 0;
    }
    
    # Check if DFdaemon is running before doing DF operations
    $conn->prompt('/[\$%#>\?] +$/');
    my @res1 = $conn->cmd("ps -aef | grep DFdaemon | grep -v grep");
    chomp($res1[0]);

    if ($res1[0] !~ /DFdaemon/) {
        $logger->error(__PACKAGE__ . ".$sub DFdaemon is not running");
        return 0;
    }

    my $cmd = "DFcat $filename";

    # Execute command on SGX
    $conn->prompt('/[\$] +$/');
    my @result =  $conn->cmd($cmd);

    chomp($result[0]);
    my @result2 = $conn->cmd("echo \$?");
    chomp($result2[0]);

    # Check on command results and see if DFcat was successful
    if (($result[0] =~ /failed/) || ($result2[0] != 0)) {
        $logger->error(__PACKAGE__ . ".$sub DFcat was not successful,File $filename was not found");
        $logger->error(__PACKAGE__ . ".$sub $_");
        return 0;
    }
  
    if ($flagvalue eq "") {
        $cmd = "DFcat $filename \| grep -i \"$flagname\"" ;
    }
    else {
        $cmd = "DFcat $filename \| grep -i \"$flagname\=$flagvalue\"";
    }

    # Check for flagname and flag value
    @result = $conn->cmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub $cmd $result[0]");
    @result = $conn->cmd("echo \$?");
    chomp($result[0]);

    if ($result[0]) {
        $logger->error(__PACKAGE__ . ".$sub String $flagname $flagvalue not present in file $filename");
        return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub String $flagname $flagvalue present in file $filename");
        return 1;
    }

} # End sub dfCheckFlag()

=head2 dfDeleteFlag()

dfDeleteFlag method removes a entry in the file in distributed file system.
The mandatory arguments are filename and flag_name.

=over

=item Arguments

 -filename
    specify the DF file name
 -flag_name
    specify the name of the flag - for example - UA_GEOGRAPHIC_REDUNDANCY

=item Return Values

  1 - Success - string and value removed from file 
  0 - Failure - file not present or filename not specified or flag not removed from file

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::dfRemoveFlag(-filename => "omni_conf_info.a7n1.1040",-flag_name => "UA_GEOGRAPHIC_REDUNDANCY");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub dfDeleteFlag() {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "dfDeleteFlag()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $filename = undef;
    my $flagname = undef;

    $filename = $args{-filename};
    $flagname = $args{-flag_name};
  
    # Error if filename is not set
    if (!defined $filename) {

        $logger->error(__PACKAGE__ . ".$sub file name is not specified");
        return 0;
    }

    # Error if flag name is not set
    if (!defined $flagname) {

        $logger->error(__PACKAGE__ . ".$sub flag name is not specified");
        return 0;
    }
 
    # Check if DFdaemon is running before doing DF operations
    $conn->prompt('/[\$%#>\?] +$/');
    my @res1 = $conn->cmd("ps -aef | grep DFdaemon | grep -v grep");
    chomp($res1[0]);

    if ($res1[0] !~ /DFdaemon/) {
        $logger->error(__PACKAGE__ . ".$sub DFdaemon is not running");
        return 0;
    }

    my $flagcheck = $self->SonusQA::SGX::SGXHELPER::dfCheckFlag(-filename => $filename,-flag_name => $flagname);
    chomp($flagcheck);
    if (!$flagcheck) {
        return 1;
    }

    # Move the contents of the DF file to tmp directory excluding the specified flagname
    my $cmd = "DFcat $filename | grep -v $flagname > /tmp/$filename.saved";

    $conn->prompt('/[\$] +$/'); 
    my @result = $conn->cmd($cmd);

    chomp($result[0]);
    my @result2 = $conn->cmd("echo \$?");
    chomp($result2[0]);

    # Check on command results and see if DFcat was successful
    if (($result[0] =~ /failed/) || ($result2[0] != 0)) {
        $logger->error(__PACKAGE__ . ".$sub DFcat was not successful. Unable to execute command $cmd and file $filename in tmp directory was not created");
        $logger->error(__PACKAGE__ . ".$sub $_");
        return 0;
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub String was removed and tmp file is ready");
    }

    # Copy the contents of tmp file to file in $OMNI_HOME/conf and DFconvert
    @result = $conn->cmd("cd \$OMNI_HOME/conf");
    @result = $conn->cmd("mv /tmp/$filename.saved $filename");

    @result = $conn->cmd("DFconvert $filename");

    chomp($result[0]);
    @result2 = $conn->cmd("echo \$?");
    chomp($result2[0]);

    # Check on command results and see if DFconvert was successful
    if (($result[0] =~ /Cannot open/) || ($result2[0] != 0)) {
        $logger->error(__PACKAGE__ . ".$sub DFconvert was not successful for file $filename ");
        $logger->error(__PACKAGE__ . ".$sub $_");
        return 0;
    }

    # Check for string in the DF file to report final status
    $cmd = "DFcat $filename \| grep -i \"$flagname\"";

    @result = $conn->cmd($cmd);

    $cmd = "echo \$\?";

    @result = $conn->cmd($cmd);

    chomp($result[0]);

    if ($result[0]) {
        $logger->debug(__PACKAGE__ . ".$sub String $flagname is removed in file $filename");
        return 1;
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub String $flagname is still present in the file $filename");
        return 0;
    }
} # End sub dfDeleteFlag()

=head2 dfAddFlag()

dfAddFlag method adds a entry in a file in the distributed file system.

=over

=item Arguments

 -filename
    specify the DF File name
 -flag_name
    specify the name of the flag - for example - UA_GEOGRAPHIC_REDUNDANCY
 -flag_value
    specify the value for the flag - for example - TRUE

=item Return Values

 1 - Success - string is added to the file or already present in the file
 0 - Failure - filename/flag name not specified or file not present or unable to add the string in file 

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::dfAddFlag(-filename => "omni_conf_info.a7n1.1040",-flag_name => "UA_GEOGRAPHIC_REDUNDANCY",-flag_value => "TRUE");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub dfAddFlag() {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "dfAddFlag()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $filename = undef;
    my $flagname = undef;
    my $flagvalue = "";
    my ($string,$cmd);

    $filename = $args{-filename};
    $flagname = $args{-flag_name};
    $flagvalue = $args{-flag_value};

    # Error if filename is not set
    if (!defined $filename) {

        $logger->error(__PACKAGE__ . ".$sub file name is not specified");
        return 0;
    }

    # Error if flag name is not set
    if (!defined $flagname) {

        $logger->error(__PACKAGE__ . ".$sub flag name is not specified");
        return 0;
    }

    # Check if DFdaemon is running before doing DF operations
    $conn->prompt('/[\$%#>\?] +$/');
    my @res1 = $conn->cmd("ps -aef | grep DFdaemon | grep -v grep");
    chomp($res1[0]);

    if ($res1[0] !~ /DFdaemon/) {
        $logger->error(__PACKAGE__ . ".$sub DFdaemon is not running");
        return 0;
    }

    if ($flagvalue eq "") {
        $string = $flagname;
        $cmd = "DFcat $filename \| grep -i \"$string\"";
    }
    else {
        $string = join "\=",$flagname,$flagvalue;
        $cmd = "DFcat $filename \| grep -i \"$string\"";
    }
 
    # Check for flagname and flag value
    $conn->prompt('/[\$] +$/');
    my @result = $conn->cmd($cmd);
   
    # DFcat open failed error check 
    if ($result[0] =~ /failed/) {
        $logger->error(__PACKAGE__ . ".$sub File not present");
        return 0;
    }
  
    $cmd = "echo \$\?";
 
    @result = $conn->cmd($cmd);
    chomp($result[0]);
  
    if ($result[0]) {
        $logger->debug(__PACKAGE__ . ".$sub String $string not present in file $filename");
        @result = $conn->cmd("DFcat $filename | grep -i \"$flagname\"");
        chomp($result[0]);

        if ($result[0] =~ /$flagname/) {
            $logger->debug(__PACKAGE__ . ".$sub Flag $flagname is present with a different value");
            my $res2 = $self->SonusQA::SGX::SGXHELPER::dfDeleteFlag(-flag_name => $flagname,-filename => $filename);
            if ($res2) {
                $logger->debug(__PACKAGE__ . ".$sub Flag $flagname has been deleted from the file $filename and new entry will be added");
            }
            else {
                $logger->error(__PACKAGE__ . ".$sub Flag $flagname was not possible to delete from the file $filename");
                return 0;
            }
        }
        $cmd = "DFcat $filename | grep -v $flagname > /tmp/$filename.saved"; 
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub String $string already present in file $filename");
        return 1;
    }
    
    # Move contents of DF file into /tmp/filename.saved and add the string at the end of the file
    @result = $conn->cmd($cmd); 
    chomp($result[0]);
    my @result2 = $conn->cmd("echo \$?");
    chomp($result2[0]);

    # Check on command results and see if DFcat was successful
    if (($result[0] =~ /failed/) || ($result2[0] != 0)) {
        $logger->error(__PACKAGE__ . ".$sub DFcat was not successful");
        $logger->error(__PACKAGE__ . ".$sub $_");
        return 0;
    }

    $cmd = "echo $string >> /tmp/$filename.saved";
   
    @result = $conn->cmd($cmd);

    # Copy the /tmp/filename.saved to $OMNI_HOME/conf/$filename and perform DFconvert
    $cmd = "mv /tmp/$filename\.saved \$OMNI_HOME/conf/$filename";

    @result = $conn->cmd($cmd);

    $cmd = "cd \$OMNI_HOME/conf";

    @result = $conn->cmd($cmd);
    
    $cmd = "DFconvert $filename";

    @result = $conn->cmd($cmd);
    chomp($result[0]);
    @result2 = $conn->cmd("echo \$?");
    chomp($result2[0]);

    # Check on command results and see if DFconvert was successful
    if (($result[0] =~ /Cannot open/) || ($result2[0] != 0)) {
        $logger->error(__PACKAGE__ . ".$sub DFconvert was not successful");
        $logger->error(__PACKAGE__ . ".$sub $_");
        return 0;
    }

    # Check for string in the DF file to report final status
    $cmd = "DFcat $filename \| grep -i \"$string\"";
 
    @result = $conn->cmd($cmd);

    $cmd = "echo \$\?";

    @result = $conn->cmd($cmd);

    chomp($result[0]);
   
    if ($result[0]) {
        $logger->error(__PACKAGE__ . ".$sub String $string not added in file $filename");
        return 0; 
    }
    else {
        $logger->debug(__PACKAGE__ . ".$sub String $string added in file $filename");
        return 1;
    }

}  # End sub dfAddFlag()

=head2 getAllUlticomBoardTypes()

 getAllUlticomBoardTypes method returns number of boards,board type,slot number and status of the board in the SGX.No arguments need to be passed in.

=over

=item Arguments

 None

=item Returns

 Returns an array with following elements,,
 $res[0] - Number of boards
 $res[1] - Slot Number of board 1
 $res[2] - Board Type of board 1 
 $res[3] - Board Status of board 1
 $res[4] - Slot Number of board 2
 ..and so on.

 Slot Number will be of format PCI1

 0 - if no board found

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::getAllUlticomBoardTypes()

=item Notes

 Executes prtdiag command on the specified sgx and fetches the board details.Searches for string "12d4".
 if prtdiag is not found in the CE , fetch the type from /etc/path_to_inst file.

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub getAllUlticomBoardTypes() {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "getAllUlticomBoardTypes()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($i,$j,$board_type,$board_status,$slot_num,$num_of_board);    
    my $n = 0;
    my @res;
    my $prtdiagfound = 1; # Assume prtdiag is present in the CE

    # Set the prompt
    $conn->prompt('/[\$] +$/');

    # Execute prtdiag command on SGX to find number of boards
    my @result = $conn->cmd("grep -c 12d4 /etc/path_to_inst");
    chomp($result[0]);
    $num_of_board = $result[0];
    push @res,$num_of_board;

    # Get the machine type 
    my @machine = $conn->cmd("uname -i");
    chomp($machine[0]);

    $logger->debug(__PACKAGE__ . ".$sub Machine type of SGX is $machine[0]");

    # Check if prtdiag is present in the SGX CE
    @result = $conn->cmd("prtdiag");
    chomp($result[0]);

    if ($result[0] =~ /not found/) {
        $prtdiagfound = 0;
    }

    if (($machine[0] =~ /Netra-240|Netra-440/) && $prtdiagfound) {
        # Check the slot number,board type and board status from prtdiag output
        @result = $conn->cmd("prtdiag \| grep -i 12d4");
        foreach (@result) {
            chomp($_);
            if (m/.*(\w+)\s+(\d+)\s+(\w+)\s+(\w+),(\d+)/) {
                $slot_num = $3;
                substr($slot_num,0,3) = "";
                push @res,$slot_num;
                if ($5 eq 200) {
                    $board_type = "PC0200";
                }
                elsif ($5 eq 301) {
                    $board_type = "PH0301";
                }
                elsif ($5 eq 204) {
                    $board_type = "PS0204";
                }
                else {
                    $board_type = "unknown";
                }
                push @res,$board_type;
            }   
            if (m/okay/) {
                $board_status = "okay";
            } 
            elsif (m/faulty/) {
                $board_status = "faulty";
            } # End elsif
            else {
                $board_status = "";
            } # End if
            if ($board_status ne "") {
                push @res,$board_status;
            }
        } # End foreach
    } 
    elsif (($machine[0] =~ /Netra-240|Netra-440/) && !$prtdiagfound) {
    
        push @res,"UNAVAILABLE" ; # For slot num    
        # prtdiag is not found , so retrieve details from /etc/path_to_inst
        my @result = $conn->cmd("grep 12d4 /etc/path_to_inst");
        chomp($result[0]);
 
        my @result1 = split /12d4/,$result[0];

        if ($result1[1] =~ /200/) {
            $board_type = "PC0200";
        }
        elsif ($result1[1] =~ /204/) {
            $board_type = "PS0204";
        }
        elsif ($result1[1] =~ /301/) {
            $board_type = "PH0301";
        } # End if

        push @res,$board_type;
        push @res,"UNAVAILABLE";
    } 
    elsif (($machine[0] =~ /Ultra-60/) && $prtdiagfound) {
        # Check the slot number,board type and board status from prtdiag output
        @result = $conn->cmd("prtdiag \| grep -i 12d4");
        foreach (@result) {
            chomp($_);
            if (m/(pci12d4),(\d+)/) {
                $slot_num = "UNAVAILABLE";
                push @res,$slot_num;
                if ($2 eq 200) {
                    $board_type = "PC0200";
                }
                elsif ($2 eq 301) {
                    $board_type = "PH0301";
                }
                elsif ($2 eq 204) {
                    $board_type = "PS0204";
                }
                else {
                    $board_type = "unknown";
                }
                push @res,$board_type;
            } 
            $board_status = "UNAVAILABLE";
            push @res,$board_status;
        } # End foreach
    } 
    elsif (($machine[0] =~ /Ultra-60/) && !$prtdiagfound) {

        push @res,"UNAVAILABLE" ; # For slot num
        # prtdiag is not found , so retrieve details from /etc/path_to_inst
        my @result = $conn->cmd("grep 12d4 /etc/path_to_inst");
        chomp($result[0]);

        my @result1 = split /12d4/,$result[0];

        if ($result1[1] =~ /200/) {
            $board_type = "PC0200";
        }
        elsif ($result1[1] =~ /204/) {
            $board_type = "PS0204";
        }
        elsif ($result1[1] =~ /301/) {
            $board_type = "PH0301";
        } # End if

        push @res,$board_type;
        push @res,"UNAVAILABLE";
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub This subroutine is not supported for this machine type");
    } # End if

    $logger->debug(__PACKAGE__ . ".$sub Number of boards is $res[0]");

    # Print the details of the boards present 
    $i = 1;
    $j = 1;
    while ($j <= $res[0]) {
        $logger->debug(__PACKAGE__ . ".$sub Slot Number of board $j is $res[$i++]");
        $logger->debug(__PACKAGE__ . ".$sub Board Type of board $j is $res[$i++]");
        $logger->debug(__PACKAGE__ . ".$sub Board Status of board $j is $res[$i++]");
        $j++;
    }
    return @res; 
} # End sub getAllUlticomBoardTypes()

=head2 checkForUlticomBoardType()

checkForUlticomBoardType method checks if a particular board type exists and returns success/failure.

=over

=item Arguments

 -board_type
   specify the board type , example - PC0200

=item Return Values

  Success - if board is present returns the number of boards present of the specified type
  Failure - 0 (Board not present)

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::checkForUlticomBoardType(-board_type => "PC0200");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back 

=cut

sub checkForUlticomBoardType {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "checkForUlticomBoardType()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my $boardtype = undef;
    $boardtype = $args{-board_type};

    # Set the prompt
    $conn->prompt('/[\$] +$/');

    # Error if board type is not set
    if (!defined $boardtype) {

        $logger->error(__PACKAGE__ . ".$sub BoardType is not specified");
        return 0;
    } 

    my @result = $self->getAllUlticomBoardTypes();

    my $numboards = $result[0];

    if ($numboards == 0) {
        $logger->debug(__PACKAGE__ . ".$sub No Ulticom boards present in SGX"); 
        return 0;
    } 
    else {
        my $i = 1;
        my $j = 1;
        my $board_count = 0;

        while ($j <= $numboards) {
            my $slot_number = $result[$i++];
            my $sgx_board_type = $result[$i++];
            my $board_status = $result[$i++];
            if ($sgx_board_type =~ /$boardtype/) {
                $logger->debug(__PACKAGE__ . ".$sub Specified board type $boardtype is present in the SGX");
                $logger->debug(__PACKAGE__ . ".$sub Slot number of board $boardtype is $slot_number and status is $board_status");
                $board_count++;
            } 
            $j++;
        } # End While

        if ($board_count > 0) {
            $logger->debug(__PACKAGE__ . ".$sub Number of Specified board type $boardtype is $board_count");
            return $board_count;
        } 
        else {
            $logger->error(__PACKAGE__ . ".$sub Specified board type $boardtype is not available");
            return 0;
        }
    } # End if

} # End sub checkForUlticomBoardType

=head2 backupDFFile()

backupDFFile method takes a backup of the DF file specified.

=over

=item Arguments

 -file
    name of the DF file
 -backup_dir
   name of the directory where the file needs to be stored in the ce.
 -backup_file
   name of the backup file

=item Return

 1 - Success when DF file backup is done
 0 - Failure when backup failed or when file or directory not specified.

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::backupDFFile(-file => "omni_conf_info.a7n1.1040",-backup_dir => "/tmp/backup",-backup_file => "temp.txt");

=item Notes 

 The backup is taken and is placed in backup_dir in SGX.

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub backupDFFile() {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "backupDFFile()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my $file = undef;
    my $backupdir = undef;
    my $backupfile = undef;

    $file = $args{-file};
    $backupdir = $args{-backup_dir};
    $backupfile = $args{-backup_file};

    # Error if filename is not set
    if (!defined $file) {

        $logger->error(__PACKAGE__ . ".$sub file name is not specified");
        return 0;
    } 

    # Error if backup dir is not set
    if (!defined $backupdir) {
 
        $logger->error(__PACKAGE__ . ".$sub Backup Directory is not specified");
        return 0;
    } 

    # Error if backup file is not set
    if (!defined $backupfile) {

        $logger->error(__PACKAGE__ . ".$sub Backup File is not specified");
        return 0;
    } 

    # Check if DFdaemon is running before doing DF operations
    $conn->prompt('/[\$%#>\?] +$/');
    my @res1 = $conn->cmd("ps -aef | grep DFdaemon | grep -v grep");
    chomp($res1[0]);

    if ($res1[0] !~ /DFdaemon/) {
        $logger->error(__PACKAGE__ . ".$sub DFdaemon is not running");
        return 0;
    }

    # Save contents of Df file to backdup directory 
    my $cmd = "DFcat $file > $backupdir/$backupfile";
 
    my @result = $conn->cmd($cmd);
    
    $cmd = "echo \$?";

    @result = $conn->cmd($cmd);
    chomp($result[0]);

    # Check on command results and see if backup was successful
    if ($result[0]) {
    
        $logger->error(__PACKAGE__ . ".$sub Backup process was not successful");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub Backup was taken for $file and placed in $backupdir as $backupfile");
    return 1;

} # End sub backupDFFile()

=head2 restoreDFFile()

restoreDFFile method restores a file to the DF File system.We need to specify the file to restore in the DF file system and the back up file.The backup file could be timestamped and prefixed.

=over

=item Arguments

 -backup_file
    name of the file (complete path for example /tmp/tst.saved) 
 -df_file
    name of the DF file

=item Returns

 1 - Success when file is written into DF file system
 0 - Failure to write file to DF file system or inputs are not sufficient

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::restoreDFFile(-backup_file => "/tmp/backup",-df_file => "omni_conf_info.a7n1.1040");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub restoreDFFile() {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "restoreDFFile()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my $dffile = undef;
    my $backupfile = undef;

    $dffile = $args{-df_file};
    $backupfile = $args{-backup_file};
    $conn->prompt('/[\$%#>\?] +$/');

    # Error if df filename is not set
    if (!defined $dffile) {

        $logger->error(__PACKAGE__ . ".$sub DF file name is not specified");
        return 0;
    }

    # Error if backupfile is not set
    if (!defined $backupfile) {

        $logger->error(__PACKAGE__ . ".$sub Backup file path is not specified");
        return 0;
    }

    # Check if DFdaemon is running before doing DF operations
    my @res1 = $conn->cmd("ps -aef | grep DFdaemon | grep -v grep");
    chomp($res1[0]);

    if ($res1[0] !~ /DFdaemon/) {
        $logger->error(__PACKAGE__ . ".$sub DFdaemon is not running");
        return 0;
    }

    # Save contents of remote file to file in $OMNI_HOME/conf directory
    my @result = $conn->cmd("cd \$OMNI_HOME/conf");
    @result = $conn->cmd("cat $backupfile > $dffile");
 
    # Check if command to save contents worked 
    foreach(@result) {

        if (m/cannot open/) {
            $logger->error(__PACKAGE__ . ".$sub Unable to access remote file specified");
            return 0;
        }
    }

    # DFconvert file 
    @result = $conn->cmd("DFconvert $dffile");
    chomp($result[0]);
    my @result2 = $conn->cmd("echo \$?");
    chomp($result2[0]);

    # Check on command results and see if DFconvert was successful
    if (($result[0] =~ /Cannot open/) || ($result2[0] != 0)) {
        $logger->error(__PACKAGE__ . ".$sub DFconvert was not successful");
        $logger->error(__PACKAGE__ . ".$sub $_");
        return 0;
    }

    $logger->debug(__PACKAGE__ . ".$sub DF File $dffile was restored from $backupfile");

    # Remove the backup file after restoration
    @result = $conn->cmd("rm -f $backupfile");
    @result = $conn->cmd("file $backupfile");
    chomp($result[0]);
    if ($result[0] =~ /cannot open/) {
        $logger->debug(__PACKAGE__ . ".$sub Backup file $backupfile has been removed after restoration to DF File system");
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub Backup file $backupfile was not removed");
        return 0;
    }

    return 1;

} # End sub restoreDFFile()

=head2 getSS7LinkState()

getSS7LinkState fetches the linkstate (eg ACTIVE) and link status (eg inbolraP) for a specified link and returns the values in an array.

=over

=item Arguments

 -link
    specify the link name ( only one link at a time)
 -node_name
    specify the node name in which we need to check the link status.

=item Returns

 Success - linkstate and linkstatus
 Failure - 0

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::getSS7LinksState(-link => "LNK21",-node_name => "a7n1");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub getSS7LinkState {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "getSS7LinkState()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my (@retvalues);
    my ($linkstate,$linkstatus);

    my $link = undef;
    my $node = undef;

    $link = $args{-link};
    $node = $args{-node_name};

    # Error if link is not set
    if (!defined $link) {
        $logger->error(__PACKAGE__ . ".$sub link name is not specified");
        return 0;
    } 

    # Error if node name is not set
    if (!defined $node) {
        $logger->error(__PACKAGE__ . ".$sub node name is not specified");
        return 0;
    } 

    # Node is chosen using USE-NODE command
    $conn->prompt('/[\$%#>\?] +$/');
    my $cmd = "swmml -e USE-NODE:LN=$node";

    my @result = $conn->cmd($cmd);

    # Check if use node command execution was successful
    foreach(@result) {
        if (m/Unknown node/) {
            $logger->error(__PACKAGE__ . ".$sub Node specified is not known");
            return 0;
        } 
        if (m/(syntax\s+error|M\s+DENY)/i){
            $logger->error(__PACKAGE__ . ".$sub  CMD: $cmd CMD RESULT: $_");
            return 0;
        }  
    } # End foreach


    # Execute DISPLAY-SLK command for each link specified
    $cmd = "swmml -e DISPLAY-SLK:SLK=$link -n $node";
    @result = $conn->cmd($cmd);

    foreach (@result) {

        chomp($_);
        # Check if error has occured during command execution
        if (m/(syntax\s+error|M\s+DENY)/i){
            $logger->error(__PACKAGE__ . ".$sub CMD: $cmd CMD RESULT: $_");
            return 0;
        } 

        # Check if link is provisioned and return 0 if not provisioned
        if (m/not provisioned/i) {
            $logger->error(__PACKAGE__ . ".$sub Link $link is not provisioned");
            return 0;
        } 

        # Check if link status is active,installed,normal and not locally blocked
        if (m/($link)\s+(\d+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)-(\d+)-(\d+)\s+(\w+)\s+(\w+)/) {
            my $linkstate = $12;
            my $linkstatus = $13;
            push @retvalues,$linkstate;
            push @retvalues,$linkstatus;
        } 

    } # End foreach
   
    return @retvalues;

} # End sub getSS7LinkState

=head2 checkSS7Links()

checkSS7Links methods checks if the specified links are in specified link state and link status in the SGX.Link,node_name,link_state and link_status are mandatory arguments.

=over

=item Arguments

 -link
    specify the link names seperated by comma
 -node_name
    specify the node name in which we need to check the link status.
 -link_state
    specify the link state - "ACTIVE"
 -link_status
    specify the link status as in cmd output - "inbolraP"

=item Returns

 1 - Success when all links are installed,normal and active.
 0 - Failure even when one of the links are down or inputs not specified or command execution failed due to some reason.

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::checkSS7Links(-link => "LNK21,LNK22",-node_name => "a7n1",-link_state => "ACTIVE",-link_status => "inbolraP");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub checkSS7Links() {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "checkSS7Links()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
 
    my $link = undef;
    my $node = undef;
    my $linkstate = undef;
    my $linkstatus = undef;
 
    $link = $args{-link};
    $node = $args{-node_name};
    $linkstate = $args{-link_state};
    $linkstatus = $args{-link_status};
    $conn->prompt('/[\$%#>\?] +$/');
 
    # Error if link is not set
    if (!defined $link) {
        $logger->error(__PACKAGE__ . ".$sub link name is not specified");
        return 0;
    } 
 
    # Error if node name is not set
    if (!defined $node) {
        $logger->error(__PACKAGE__ . ".$sub node name is not specified");
        return 0;
    } 

    # Error if link state is not set
    if (!defined $linkstate) {
        $logger->error(__PACKAGE__ . ".$sub link state is not specified");
        return 0;
    }  

    # Error if link status is not set
    if (!defined $linkstatus) {
        $logger->error(__PACKAGE__ . ".$sub link status is not specified");
        return 0;
    } 

    # Find number of links specified in input (seperated by comma)
    my @links = split(",",$link);

    foreach (@links) {

        my $lnk = $_;
        my @linkvalues = $self->getSS7LinkState(-node_name => $node,-link => $lnk);
        $logger->debug(__PACKAGE__ . ".$sub @linkvalues");
          
        if ($linkvalues[0] eq "0") {
            $logger->error(__PACKAGE__ . ".$sub Unable to get link state for link $lnk");
            return 0;
        } 

        if ($linkvalues[0] =~ /$linkstate/) {
            $logger->debug(__PACKAGE__ . ".$sub Link $lnk is in specified link state $linkstate");
        } 
        else {
            $logger->error(__PACKAGE__ . ".$sub Link $lnk is not in specified link state $linkstate");
            return 0;
        } 

        if ($linkvalues[1] =~ /$linkstatus/) {
            $logger->debug(__PACKAGE__ . ".$sub Link $lnk is in specified link status $linkstatus");
        } 
        else {
            $logger->error(__PACKAGE__ . ".$sub Link $lnk is not in specified link status $linkstatus");
            return 0;
        } 
     
    } # End foreach

    # When all links are in specified state and link status 

    $logger->debug(__PACKAGE__ . ".$sub Links @links are $linkstate and $linkstatus");
    return 1; 
 
} # End sub checkSS7Links()

=head2 activateSS7Links()

activateSS7Links method activates the SS7 links in specified node.Link and node_name are mandatory arguments.

=over

=item Arguments

 -link
    specify the link names seperated by comma
 -node_name
    specify the node name in which we need to activate the link.

=item Returns

 1 - Success if link are in installed,normal,active state.
 0 - Failure  even when one of the links is down or inputs are not specified or command execution fails due to some reason.

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::activateSS7Links(-link => "LNK21,LNK22",-node_name => "a7n1");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub activateSS7Links() {
 
    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "activateSS7Links()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($cmd,@result);
 
    my $link = undef;
    my $node = undef;
 
    $link = $args{-link};
    $node = $args{-node_name};
 
    # Error if link is not set
    if (!defined $link) {
 
        $logger->error(__PACKAGE__ . ".$sub link name is not specified");
        return 0;
    }
 
    # Error if node name is not set
    if (!defined $node) {
 
        $logger->error(__PACKAGE__ . ".$sub node name is not specified");
        return 0;
    }

    # Find number of links specified in input (seperated by comma)
    my @links = split(",",$link);
 
    foreach (@links) {
 
        my $lnk = $_;
        my @linkvalues = $self->getSS7LinkState(-node_name => $node,-link => $lnk);

        if ($linkvalues[0] eq "0") {
            $logger->error(__PACKAGE__ . ".$sub Unable to get link state for link $lnk");
            return 0;
        } 

        if ($linkvalues[1] =~ /B|O/) {

            # Execute UNBLOCK-SLK command for each link specified
            $cmd = "swmml -e UNBLOCK-SLK:SLK=$lnk -n $node";
            @result = $conn->cmd($cmd);

            foreach (@result) {

                # Check if error has occured during command execution
                if (m/(syntax\s+error|M\s+DENY)/i){
                    $logger->error(__PACKAGE__ . ".$sub CMD: $cmd CMD RESULT: $_");
                    return 0;
                }
                # Check if command execution completed
                elsif (m/COMPLETED/i) {
                    $logger->debug(__PACKAGE__ . ".$sub Link $lnk Unblocking completed");
                }
            } # End foreach

            # Wait for links to come to unblocked state
            sleep(5);
            my @linkrecheck = $self->getSS7LinkState(-node_name => $node,-link => $lnk);
            if ($linkrecheck[1] =~ /B/) {
                $logger->error(__PACKAGE__ . ".$sub Link $lnk is locally blocked");
                return 0;
            } 
            elsif ($linkrecheck[1] =~ /O/) {
                $logger->error(__PACKAGE__ . ".$sub Link $lnk is remotely blocked");
                return 0;
            } # End elsif
        } 

        if ($linkvalues[1] =~ /L|R/) {
            # Execute UNINHIBIT-SLK command for each link specified
            $cmd = "swmml -e UNINHIBIT-SLK:SLK=$lnk -n $node";
            @result = $conn->cmd($cmd);

            foreach (@result) {

                # Check if error has occured during command execution
                if (m/(syntax\s+error|M\s+DENY)/i){
                    $logger->error(__PACKAGE__ . ".$sub CMD: $cmd CMD RESULT: $_");
                    return 0;
                }
                # Check if command execution completed
                elsif (m/COMPLETED/i) {
                    $logger->debug(__PACKAGE__ . ".$sub Link $lnk Uninhibit completed");
                }
            } # End foreach

            # Wait for 5 sec
            sleep(5);
            my @linkrecheck = $self->getSS7LinkState(-node_name => $node,-link => $lnk);
            if ($linkrecheck[1] =~ /L/) {
                $logger->error(__PACKAGE__ . ".$sub Link $lnk is locally inhibited");
                return 0;
            } 
            elsif ($linkrecheck[1] =~ /R/) {
                $logger->error(__PACKAGE__ . ".$sub Link $lnk is remotely inhibited");
                return 0;
            } # End elsif
        } 

        # Check if link is inactive or not installed or failed and try to activate
        if (($linkvalues[0] =~ /INACTIVE/) || ($linkvalues[1] =~ /I|F/)) {

            # Execute DEACTIVATE-SLK command for each link specified
            $cmd = "swmml -e DEACTIVATE-SLK:SLK=$lnk -n $node";
            @result = $conn->cmd($cmd);

            foreach (@result) {
                # Check if error has occured during command execution
                if (m/(syntax\s+error|M\s+DENY)/i){
                    $logger->error(__PACKAGE__ . ".$sub CMD: $cmd CMD RESULT: $_");
                    return 0;
                } 
                # Check if command execution completed
                elsif (m/COMPLETED/i) {
                    $logger->debug(__PACKAGE__ . ".$sub Link $lnk deactivation completed");
                } # End elsif
            } # End foreach
            
            sleep(5);
            # Execute ACTIVATE-SLK command for each link specified
            $cmd = "swmml -e ACTIVATE-SLK:SLK=$lnk -n $node";
            @result = $conn->cmd($cmd);

            foreach (@result) {
                # Check if error has occured during command execution
                if (m/(syntax\s+error|M\s+DENY)/i){
                    $logger->error(__PACKAGE__ . ".$sub CMD: $cmd CMD RESULT: $_");
                    return 0;
                } 
                # Check if command execution completed
                elsif (m/COMPLETED/i) {
                    $logger->debug(__PACKAGE__ . ".$sub Link $lnk activation completed");
                } # End elsif
            } # End foreach
          
            sleep(5); 
            # Recheck link state after activation 
            my @linkrecheck = $self->getSS7LinkState(-node_name => $node,-link => $lnk);
            if ($linkrecheck[0] =~ /INACTIVE/) {
                $logger->error(__PACKAGE__ . ".$sub Link $lnk is INACTIVE");
                return 0;
            } 
            elsif ($linkrecheck[1] =~ /I/) {
                $logger->error(__PACKAGE__ . ".$sub Link $lnk is not Installed");
                return 0; 
            } # End elsif
            elsif ($linkrecheck[1] =~ /F/) {
                $logger->error(__PACKAGE__ . ".$sub Link $lnk is FAILED");
                return 0;
            } # End elsif
        }     

    } # End foreach

    # When all links are active and normal 

    $logger->debug(__PACKAGE__ . ".$sub Links @links are ACTIVE and inbolr");
    return 1;

} # End sub activateSS7Links()

=head2 checkSgxM3UALinksUP()

checkSgxM3UALinksUP method checks if M3UA link is active in SGX and reports the status.Link and node_name are mandatory arguments.

=over

=item Arguments

 -link
    specify the link names seperated by comma
 -node_name
    specify the node name in which link status needs to be checked

=item Returns

 1 - Success when all links are UP.
 0 - Failure even when one of the links are down.

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::checkSgxM3UALinksUP(-link => "TOMCAT11,TOMCAT12",-node_name => "a7n1");

=item Notes 

 DISPLAY-M3UA-SLK:SLK=<link specified> is executed and State field is checked for "UP".

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub checkSgxM3UALinksUP() {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "checkSgxM3UALinksUP()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my $link = undef;
    my $node = undef;

    $link = $args{-link};
    $node = $args{-node_name};
    $conn->prompt('/[\$%#>\?] +$/');

    # Error if link is not set
    if (!defined $link) {

        $logger->error(__PACKAGE__ . ".$sub link name is not specified");
        return 0;
    }

    # Error if node name is not set
    if (!defined $node) {

        $logger->error(__PACKAGE__ . ".$sub node name is not specified");
        return 0;
    }

    # Node is chosen using USE-NODE command
    my $cmd = "swmml -e USE-NODE:LN=$node";

    my @result = $conn->cmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub $cmd");
    $logger->debug(__PACKAGE__ . ".$sub @result");

    # Check if use node command execution was successful
    foreach(@result) {
        if (m/Unknown node/) {
            $logger->error(__PACKAGE__ . ".$sub Node specified is not known");
            return 0;
        }
        if (m/(syntax\s+error|M\s+DENY)/i){
            $logger->error(__PACKAGE__ . ".$sub CMD:$cmd CMD RESULT: $_");
            return 0;
        }
    }

    # Find number of links specified in input (seperated by comma)
    my @links = split(",",$link);

    foreach (@links) {

        my $lnk = $_;
        # Execute DISPLAY-M3UA-SLK command for each link specified
        $cmd = "swmml -e DISPLAY-M3UA-SLK:SLK=$lnk -n $node";
        @result = $conn->cmd($cmd);
        $logger->debug(__PACKAGE__ . ".$sub @result");

        foreach (@result) {

            chomp($_);
            # Check if error has occured during command execution
            if (m/(syntax\s+error|M\s+DENY)/i){
                $logger->error(__PACKAGE__ . ".$sub CMD:$cmd CMD RESULT: $_");
                return 0;
            }

            # Check if link is provisioned and return 0 if not provisioned
            if (m/not provisioned/i) {
                $logger->error(__PACKAGE__ . ".$sub Link $lnk is not provisioned");
                return 0;
            }

            # Check if link status is UP
            if (m/.*($lnk)\s+(\d+)\s+(\w+)\s+(\w+)/) {
                my $state = $4;
                $logger->debug(__PACKAGE__ . ".$sub Link $lnk is $state");
                if ($state !~ /UP/) {
                    return 0;
                } 
            } 
        } # End foreach
    } # End foreach

    # When all links are UP
    $logger->debug(__PACKAGE__ . ".$sub Links @links are UP");
    return 1;

} # End sub checkSgxM3UALinksUP()

=head2 activateSgxM3UALinks()

activateSgxM3UALinks method tries to activate the M3UA Link ,checks on the status and reports success/failure.Link and node_name are mandatory arguments.

=over

=item Arguments

 -link
    specify the link names seperated by comma
 -node_name
    specify the node name in which link status needs to be checked

=item Returns

 1 - Success when all links are UP.
 0 - Failure even when one of the links are down.

=item Example 

 \$obj->SonusQA::SGX::SGXHELPER::activateSgxM3UALinks(-link => "TOMCAT11,TOMCAT12",-node_name => "a7n1");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back 

=cut

sub activateSgxM3UALinks() {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "activateSgxM3UALinks()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($cmd,@result);

    my $link = undef;
    my $node = undef;

    $link = $args{-link};
    $node = $args{-node_name};
    $conn->prompt('/[\$%#>\?] +$/');

    # Error if link is not set
    if (!defined $link) {

        $logger->error(__PACKAGE__ . ".$sub link name is not specified");
        return 0;
    }

    # Error if node name is not set
    if (!defined $node) {

        $logger->error(__PACKAGE__ . ".$sub node name is not specified");
        return 0;
    }

    my $res = $self->checkSgxM3UALinksUP(-link => $link,-node_name => $node);
    if ($res) {
        $logger->debug(__PACKAGE__ . ".$sub Links $link are UP");
        return 1;
    }  
    else {
        $logger->error(__PACKAGE__ . ".$sub Links $link are not UP, will try to activate them");
        # Find number of links specified in input (seperated by comma)
        my @links = split(",",$link);

        foreach (@links) {

            my $lnk = $_;
            $cmd = "swmml -e ACTIVATE-M3UA-SLK:SLK=$lnk -n $node";
            @result = $conn->cmd($cmd);
            
            $logger->debug(__PACKAGE__ . ".$sub @result");

            foreach (@result) {

                chomp($_);
                # Check if error has occured during command execution
                if (m/(syntax\s+error|M\s+DENY)/i){
                    $logger->error(__PACKAGE__ . ".$sub CMD:$cmd CMD RESULT: $_");
                    return 0;
                }

                #  Check if link is provisioned and return 0 if not provisioned
                if (m/not provisioned/i) {
                    $logger->error(__PACKAGE__ . ".$sub Link $lnk is not provisioned");
                    return 0;
                }

            } # End foreach
 
            # Recheck link state
            my $res = $self->checkSgxM3UALinksUP(-link => $link,-node_name => $node);
            if ($res) {
                $logger->debug(__PACKAGE__ . ".$sub Link $link is UP");
            } 
            else {
                $logger->error(__PACKAGE__ . ".$sub Link $link is not UP");
                return 0;
            } # End if

        } # End foreach

    } # End if

    return 1;

} # End sub activateSgxM3UALinks

=head2 getClientState()

getClientState method is used to return the state of client server connection for a particular client host and alt host.Client host and service are mandatory.Alt host is optional.But if alt host is present in the connection , then it should be specified to return the correct lan connectivity states.

=over

=item Arguments

 -client_host
 -alt_host
 -service

=item Returns

 Returns an array with lan connectivty state for ce0 and ce1 -Success
 0 - Failure

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::getClientState(-client_host => "ernie11",-service => "C7_IUP_CC");

=item Notes 

 DISPLAY-ACTIVE-CLIENT command is executed and in the output all the lines containing the client host specified are taken.The LAN connectivity state is returned for ce0 and ce1.If alt host is specified ,both client host and alt host match is checked.If service is specified then ,service is also checked for.

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub getClientState() {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "getClientState()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my ($cmd,@result,@states);

    my $clienthost = undef;
    my $althost = undef;
    my $service = undef;

    $clienthost = $args{-client_host};
    $althost = $args{-alt_host};
    $service = $args{-service};

    # Move the client host and alt host into arrays & Find number of client hosts specified in input (seperated by comma)
    my @clhosts = split(",",$clienthost);
    my @alhosts = split(",",$althost);
    my @service = split(",",$service);
    my $numhosts = $#clhosts + 1  ;

    # Error if client host is not set
    if (!defined $clienthost) {

        $logger->error(__PACKAGE__ . ".$sub Client Host is not specified");
        return 0;
    } 

    # Error if service is not set
    if (!defined $service) {

        $logger->error(__PACKAGE__ . ".$sub Service is not specified");
        return 0;
    } 

    # Execute DISPLAY-ACTIVE-CLIENT command and check the client state
    $conn->prompt('/[\$%#>\?] +$/');
    $cmd = "swmml -e DISPLAY-ACTIVE-CLIENT";
    @result = $conn->cmd($cmd);

    foreach (@result) {

        chomp($_);
        # Check if error has occured during command execution
        if (m/(syntax\s+error|M\s+DENY)/i){
            $logger->error(__PACKAGE__ . ".$sub CMD: $cmd  CMD RESULT: $_");
            return 0;
        } 

        for(my $i=0;$i<$numhosts;$i++) {
            my ($ce0,$ce1); 
            # Check for client host only if alt host not specified
            if (!defined $althost) {
                # Check if specified host is found in command result and get the status
                if (m/.*($clhosts[$i])\s+(\d+)\s+(\d+)\s+(\d+)\s+($service[$i])\s+(\w+)\s+(\w+)/) {
                    $ce0 = $6;
                    $ce1 = $7;
                    $logger->debug(__PACKAGE__ . ".$sub The lan connectivity state of $clhosts[$i] is $ce0 $ce1");
                    push @states,$ce0;
                    push @states,$ce1;
                } 
            } 
            # Check for client host and alt host if althost specified
            else {
                if (m/.*($clhosts[$i])\s+($alhosts[$i])\s+(\d+)\s+(\d+)\s+(\d+)\s+($service[$i])\s+(\w+)\s+(\w+)/) {
                    $ce0 = $7;
                    $ce1 = $8;
                    $logger->debug(__PACKAGE__ . ".$sub The lan connectivity state of $clhosts[$i] is $ce0 $ce1");
                    push @states,$ce0;
                    push @states,$ce1;
                } #End if
            } # End if
        } # End for
    } # End foreach 
  
    if ($#states >=0) { 
        return @states;
    } #End if
    else {
        return 0;
    } #End else
} # End sub getClientState()

=head2 checkClientState()

 checkClientState checks if the lan connectivity state of the hosts in SGX is as specified.A list of hosts can be specified along with list of states to be checked for.(seperated by commas)

=over

=item Arguments

 -client_host
 -alt_host
 -service
 -ce0_state
 -ce1_state
All arguments are mandatory except for alt_host.If present in SGX , needs to be specified to obtain the correct lan connectivity states.

=item Returns

 1- Success
 0 -Failure

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::checkClientState(-client_host => "SNOW12",-alt_host => "SNOW11",-service => "C7_ISUP_CC",-ce0_state => "uu",-ce1_state => "uu");

For specifying more than one host , see example below
 \$obj->SonusQA::SGX::SGXHELPER::checkClientState(-client_host => "TINT12,SNOW12",-alt_host => "TINT11,SNOW11",-service => "C7_ISUP_CC,C7_ISUP_CC",-ce0_state => "uu,uu",-ce1_state => "uu,DD");
  where -ce0_state has ce0 state of TINT12 and SNOW12
        -ce1_state has ce1 state of TINT12 and SNOW12


=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub checkClientState {
    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "checkClientState()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my (@result,@states);
    $conn->prompt('/[\$%#>\?] +$/');

    my $clienthost = undef;
    my $althost = undef;
    my $service = undef;
    my $ce0_state = undef;
    my $ce1_state = undef;

    $clienthost = $args{-client_host};
    $althost = $args{-alt_host};
    $service = $args{-service};
    $ce0_state = $args{-ce0_state};
    $ce1_state = $args{-ce1_state};

    # Move the client host and alt host into arrays & Find number of client hosts specified in input (seperated by comma)
    my @clhosts = split(",",$clienthost);
    my @alhosts = split(",",$althost);
    my @service = split(",",$service);
    my @ce0states = split(",",$ce0_state);
    my @ce1states = split(",",$ce1_state);
    my $numhosts = $#clhosts + 1  ;

    # Error if client host is not set
    if (!defined $clienthost) {
        $logger->error(__PACKAGE__ . ".$sub Client Host is not specified");
        return 0;
    } 

    # Error if service is not set
    if (!defined $service) {
        $logger->error(__PACKAGE__ . ".$sub Service is not specified");
        return 0;
    } 

    # Error if ce0_state is not set
    if (!defined $ce0_state) {
        $logger->error(__PACKAGE__ . ".$sub ce0 state is not specified");
        return 0;
    } 

    # Error if ce1_state is not set
    if (!defined $ce1_state) {
        $logger->error(__PACKAGE__ . ".$sub ce1 state is not specified");
        return 0;
    } 

    for(my $i=0;$i<$numhosts;$i++) {

        if (!defined $althost) {
            my @values = $self->SonusQA::SGX::SGXHELPER::getClientState(-client_host => $clhosts[$i],-service => $service[$i]);
            if ($values[0] =~ /$ce0states[$i]/) {
                $logger->debug(__PACKAGE__ . ".$sub CE0 State of $clhosts[$i] is $ce0states[$i]");
            } 
            else {
                $logger->error(__PACKAGE__ . ".$sub CE0 State of $clhosts[$i] is not $ce0states[$i]");
                return 0;
            } # End if

            if ($values[1] =~ /$ce1states[$i]/) {
                $logger->debug(__PACKAGE__ . ".$sub CE1 State of $clhosts[$i] is $ce1states[$i]");
            } 
            else {
                $logger->error(__PACKAGE__ . ".$sub CE1 State of $clhosts[$i] is not $ce1states[$i]");
                return 0;
            } # End if

        } 

        else {
            my @values = $self->SonusQA::SGX::SGXHELPER::getClientState(-client_host => $clhosts[$i],-alt_host => $alhosts[$i],-service => $service[$i]); 
            if ($values[0] =~ /$ce0states[$i]/) {
                $logger->debug(__PACKAGE__ . ".$sub CE0 State of $clhosts[$i] is $ce0states[$i]");
            } 
            else {
                $logger->error(__PACKAGE__ . ".$sub CE0 State of $clhosts[$i] is not $ce0states[$i]");
                return 0;
            } # End if

            if ($values[1] =~ /$ce1states[$i]/) {
                $logger->debug(__PACKAGE__ . ".$sub CE1 State of $clhosts[$i] is $ce1states[$i]");
            } 
            else {
                $logger->error(__PACKAGE__ . ".$sub CE1 State of $clhosts[$i] is not $ce1states[$i]");
                return 0;
            } # End if
        } # End if
    } # End foreach
         
    return 1;

} # End sub checkClientState

=head2 checkDcic()

checkDcic method checks whether a specified cic range for a certain OPC/DPC exists in the DCIC table.All arguments specified are mandatory.Please note the cic range specified will be checked for against the range of cics in the DISPLAY-DCIC command output.If the specified range of cics is split between 2 lines in the command output , the function will return failure.So please specify the range of cics correctly.If the specified cic range is a subset of the cic range in the command output , the function will return success.

=over

=item Arguments

 -opc 
 -dpc
 -cic_start
 -cic_end
 -node_name

=item Returns

 1-Success if specified cic range is in dcic table.
 0-Failure if specified cic range is not in dcic table or inputs not sufficient or command execution fails due to some reason.

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::checkDcic(-dpc => "3-003-003",-opc => "6-006-006",-cic_start => "2",-cic_end => "5",-node_name => "a7m3ua1");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub checkDcic() {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "checkDcic()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    # Check if all arguments are specified if not return 0
    foreach (qw/ -opc -dpc -cic_start -cic_end -node_name /) { unless ( $args{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return 0; } }

    # Format dpc and opc ( ANSI adaptation)
    foreach (qw/ -opc -dpc /) {
        if ($args{$_} =~ /(.*)-(\d){2}-(\d){1}/){
            $args{$_} =~ s#(.*)-(.*)-(.*)#$1-0$2-00$3#;
        }
        elsif ($args{$_} =~ /(.*)-(\d){1}-(\d){2}/){
            $args{$_} =~ s#(.*)-(.*)-(.*)#$1-00$2-0$3#;
        }
        elsif ($args{$_} =~ /(.*)-(\d){1}-(\d){1}/){
            $args{$_} =~ s#(.*)-(.*)-(.*)#$1-00$2-00$3#;
        }
        elsif($args{$_} =~ /(.*)-((\d){2})-((\d){2})/){
            $args{$_} =~ s#(.*)-(.*)-(.*)#$1-0$2-0$3#;
        } # End if
    } # End for
    
    # Extract SHM value from SGX
    $conn->prompt('/[\$%#>\?:] +$/');
    my @SHM = $conn->cmd("echo \$SHM");
    chomp($SHM[0]);
  
    # Check if SEND_UCIC = N is set in the SGX , if yes DCIC functionality is disabled , so exit function
    if ($self->dfCheckFlag(-filename => "isup_conf_info.$args{-node_name}.$SHM[0]",-flag_name => "SEND_UCIC",-flag_value => "N")) {
        $logger->error(__PACKAGE__ . ".$sub DCIC functionality is disabled");
        return 0;
    } # End if 

    # Node is chosen using USE-NODE command
    my $cmd = "swmml -e USE-NODE:LN=$args{-node_name}";

    my @result = $conn->cmd($cmd);
    $logger->debug(__PACKAGE__ . ".$sub $cmd");
    $logger->debug(__PACKAGE__ . ".$sub @result");

    # Check if use node command execution was successful
    foreach(@result) {
        if (m/Unknown node/) {
            $logger->error(__PACKAGE__ . ".$sub Node specified is not known");
            return 0;
        }
        if (m/(syntax\s+error|M\s+DENY)/i){
            $logger->error(__PACKAGE__ . ".$sub CMD: $cmd CMD RESULT: $_");
            return 0;
        }
    } # End foreach

    # Execute DISPLAY-DCIC command and check results
    $cmd = "DISPLAY-DCIC";
    @result = $conn->cmd("swmml -e $cmd -n $args{-node_name}");
    $logger->debug(__PACKAGE__ . ".$sub $cmd");
    $logger->debug(__PACKAGE__ . ".$sub @result");

    for (my $cic=$args{-cic_start};$cic<=$args{-cic_end};$cic++) {

        my $cic_in_dcic = 0; # Assume $cic will not be present in the cic range in DCIC output
        foreach (@result) {
    
            chomp($_);
            # Check if error has occured during command execution
            if (m/(syntax\s+error|M\s+DENY)/i){
                $logger->error(__PACKAGE__ . ".$sub CMD: $cmd CMD RESULT: $_");
                return 0;
            }
        
            # Check if cic exists in cic range (ANSI)
            if (m/.*($args{-dpc})\s+($args{-opc}|-)\s+(\d+)\s+(\d+)/) {
                my $cicstart = $3;
                my $cicend = $4;
                if (($cic >= $cicstart) && ($cic <= $cicend)) {
                    $cic_in_dcic = 1;
                    $logger->debug(__PACKAGE__ . ".$sub CIC $cic is found in the range $_");
                }
            }

            # Check if cic exists in cic range (ITU/JAPAN)
            if (m/.*($args{-dpc})\((0x)\s+(\d+)\)\s+($args{-opc}|-)\((0x)\s+(\d+)\)\s+(\d+)\s+(\d+)/) {
                 my $cicstart = $7;
                 my $cicend = $8;
                 if (($cic >= $cicstart) && ($cic <= $cicend)) {
                    $cic_in_dcic = 1; 
                    $logger->debug(__PACKAGE__ . ".$sub CIC $cic is found in the range $_");
                }
            }
        } # End foreach

        if (!$cic_in_dcic) {
            $logger->error(__PACKAGE__ . ".$sub CIC $cic is not found in the range $_");
            return 0;
        }
    } # End for
   
    # Return 1 when cic range is found in DCIC table
    $logger->error(__PACKAGE__ . ".$sub Cic Range specified $args{-cic_start} to $args{-cic_end} specified for OPC $args{-opc} and DPC $args{-dpc} is found in DCIC table");
    return 1;
 
} # End sub checkDcic()

=head2 sgxLogStart()

 sgxLogStart method is used to start capture of logs per testcase in SGX. tmpEvents/logEvents/logMonitor/logCEScore logs are captured. The name of the log file will be of the format <Testcase-id>_SGX_<sgx hostname>_timestamp.log. Timestamp will be of format yyyymmdd_HH:MM:SS.log. The mandatory arguments are test_case,host_name.The optional arguments are ats_xtail_dir,nfs_mount and sgx_nfs_mount. After using sgxLogStart ,use sgxLogStop function in the test script to kill the processes.

=over

=item NOTE 

	---> For log capture, tail process will fetch the logs and store in AUTOMATION folder in NFS mount directory in the SGX.If AUTOMATION directory is not present , it will be created.

Assumptions made:
 It is assumed that NFS is mounted on the SGX machine.Default is set as /export/home/SonusNFS. If NFS is not mounted ,please mount it and then start the test script.

=item Arguments

 -test_case
     specify testcase id for which log needs to be generated.
 -host_name
     specify the sgx/gsx hostname
 -ats_xtail_dir
     This is an optional parameter to specify the ats location for copying the xtail file, default is /ats/bin
 -nfs_mount
     This is an optional parameter to specify the nfs directory from where subroutine is invoked,default is /sonus/SonusNFS
 -sgx_nfs_mount
     This is an optional parameter to specify nfs mount directory within SGX ,default value is /export/home/SonusNFS

=item Returns

 Success - Return an array with following contents,
           Process id of eventlog,
           Process id of monitor log,
           Process id of cescore log,
           Process id of tmpevent log,
           Filename of event log stored in AUTOMATION folder(NFS mount directory)
           Filename of monitor log stored in AUTOMATION folder(NFS mount directory) 
           Filename of cescore log stored in AUTOMATION folder(NFS mount directory) 
           Filename of tmpEvent log stored in AUTOMATION folder(NFS mount directory) 
           If for some reason we are unable to xtail , then that procid will be returned as null
 0 - Failure

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::sgxLogStart(-test_case => "15804",-host_name => "VIPER",-nfs_mount => "/export/home/SonusNFS");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub sgxLogStart {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "sgxLogStart()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");

    my $ats_xtail_dir = "/ats/solaris_tools";
    my $nfs_mount = "/sonus/SonusNFS";
    my $sgx_nfs_mount = "/export/home/SonusNFS";
    my (@result,$pid,$procid,@result1);
    my @retvalues;
    my ($eventlog,$monitorlog,$cescorelog,$eventtxt); # Log File names
  
    # Check if mandatory arguments are specified if not return 0
    foreach (qw/ -test_case -host_name/) { unless ( $args{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return 0; } }

    # Setting ats_xtail_dir
    $ats_xtail_dir = $args{-ats_xtail_dir} if ($args{-ats_xtail_dir});
    my $ats_xtail = $ats_xtail_dir . "/" . "xtail";

    # Setting nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});
   
    # Setting sgx_nfs_mount
    $sgx_nfs_mount = $args{-sgx_nfs_mount} if ($args{-sgx_nfs_mount}); 

    # Prepare timestamp format
    my $timestamp = `date \'\+\%F\_\%H\:\%M\:\%S\'`;
    chomp($timestamp);

    $conn->prompt('/[\$%#>\?:] +$/');
    my @date = $conn->cmd("date \'\+\%m\%d\'");
    chomp($date[0]);    

    # Test if xtail exists in $ats_xtail_dir
    if (!(-e $ats_xtail)) {
        $logger->error(__PACKAGE__ . ".$sub $ats_xtail does not exist");
        return 0;
    } 
    else {
        $logger->debug(__PACKAGE__ . ".$sub $ats_xtail exists");
    } # End if

    # Test if $nfs_mount exixts
    if (!(-e $nfs_mount)) {
        $logger->error(__PACKAGE__ . ".$sub $nfs_mount does not exist");
        return 0;
    } 
    else {
        $logger->debug(__PACKAGE__ . ".$sub $nfs_mount exists");
    } # End if

    # Test if $sgx_nfs_mount exists
    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("file -h $sgx_nfs_mount");
    chomp($result[0]);

    if ($result[0] =~ /cannot open: No such file or directory/) {
        $logger->error(__PACKAGE__ . "$sub NFS is not mounted in SGX machine");
        return 0;
    } 

    # Test if AUTOMATION directory exists in $nfs_mount
    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("file -h $sgx_nfs_mount/AUTOMATION");
    chomp($result[0]);
    
    if ($result[0] =~ /cannot open: No such file or directory/) {
        $logger->debug(__PACKAGE__ . "$sub AUTOMATION directory does not exist");
        @result1 = $conn->cmd("mkdir $sgx_nfs_mount/AUTOMATION");
        chomp($result1[0]);
        if ($result1[0] !~ /Failed to make directory/) {
            $logger->debug(__PACKAGE__ . "$sub AUTOMATION directory created");
            my @result2 = $conn->cmd("chmod 777 $sgx_nfs_mount/AUTOMATION");
            my @result3 = $conn->cmd("echo \$?");
            if (($result2[0] =~ /can't access/) || ($result3[0] != 0)) {
                $logger->error(__PACKAGE__ . "$sub chmod for $sgx_nfs_mount/AUTOMATION was not possible");
                return 0;
            } 
        } 
    } 

    # Test if xtail present in AUTOMATION directory else Copy xtail from $ats_xtail_dir to $nfs_mount/AUTOMATION
    @result = $conn->cmd("file -h $sgx_nfs_mount/AUTOMATION/xtail");
    chomp($result[0]);

    if ($result[0] =~ /cannot open: No such file or directory/) {
        $logger->debug(__PACKAGE__ . "$sub xtail does not exist in $sgx_nfs_mount/AUTOMATION directory");
        if (system("cp -rf $ats_xtail $nfs_mount/AUTOMATION/")) {
            $logger->error(__PACKAGE__ . "$sub Unable to copy xtail from $ats_xtail to $nfs_mount/AUTOMATION/");
            return 0;
        } 
        else {
            $logger->debug(__PACKAGE__ . "$sub Copied xtail from $ats_xtail to $nfs_mount/AUTOMATION/");
        } # End if
    } 
    else {
        $logger->debug(__PACKAGE__ . "$sub xtail exists in $sgx_nfs_mount/AUTOMATION directory");
    } # End if

    $conn->prompt('/[\$%#>\?:] +$/'); 
    # Prepare $eventlog name
    $eventlog = join "_",$args{-test_case},"SGX","eventLog",uc($args{-host_name}),$timestamp;
    $eventlog = join ".",$eventlog,"log";

    @result = $conn->cmd("cd \$OMNI_HOME/Logs");
    @result = $conn->cmd("$sgx_nfs_mount/AUTOMATION/xtail Event* > $sgx_nfs_mount/AUTOMATION/$eventlog &");
    chomp($result[$#result]);

    @result1 = $conn->cmd("echo \$?");
    chomp($result1[0]);

    if ($result1[0] == 0) {
        if ($result[$#result] =~ /\]/) {
            my @pid = split /\]/,$result[$#result]; 
            ($pid[1]) =~ s/^\s+//g;
            $procid = $pid[1];
        }
        else {
            ($result[$#result]) =~ s/^\s+//g;
            $procid = $result[$#result];
        }
        $logger->debug(__PACKAGE__ . ".$sub Started xtail for $eventlog - process id is $procid");
        push @retvalues,$procid;    
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Unable to start xtail for eventLog,Process id set to null");
        push @retvalues,"null";
    } # End if

    # Prepare $monitorlog name
    $conn->prompt('/[\$%#>\?:] +$/');
    $monitorlog = join "_",$args{-test_case},"SGX","monitorLog",uc($args{-host_name}),$timestamp;
    $monitorlog = join ".",$monitorlog,"log";

    @result = $conn->cmd("$sgx_nfs_mount/AUTOMATION/xtail Monitor* > $sgx_nfs_mount/AUTOMATION/$monitorlog &");
    chomp($result[$#result]);
    @result1 = $conn->cmd("echo \$?");
    chomp($result1[0]);

    if ($result1[0] == 0) {
        if ($result[$#result] =~ /\]/) {
            my @pid = split /\]/,$result[$#result];
            ($pid[1]) =~ s/^\s+//g;
            $procid = $pid[1];
        }
        else {
            ($result[$#result]) =~ s/^\s+//g;
            $procid = $result[$#result];
        }
        $logger->debug(__PACKAGE__ . ".$sub Started xtail for $monitorlog - process id is $procid");
        push @retvalues,$procid;
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Unable to start xtail for monitorLog,Process id set to null");
        push @retvalues,"null";
    } # End if

    # Check if cescore log in enabled in cescore.conf
    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("cd \$OMNI_HOME/conf");
    @result = $conn->cmd("cat cescore.conf | grep \"DEBUG_LOG \=: ON\"");
    chomp($result[0]);
    @result1 = $conn->cmd("echo \$?");
    chomp($result1[0]);

    if (($result1[0] == 0) && ($result[0] =~ /ON/)) {  
 
        # Prepare $cescorelog name
        $cescorelog = join "_",$args{-test_case},"SGX","ceScoreLog",uc($args{-host_name}),$timestamp;
        $cescorelog = join ".",$cescorelog,"log";

        # Start xtail
        @result = $conn->cmd("cd \$OMNI_HOME/Logs");
        @result = $conn->cmd("$sgx_nfs_mount/AUTOMATION/xtail cescore* > $sgx_nfs_mount/AUTOMATION/$cescorelog &");
        chomp($result[$#result]);
        @result1 = $conn->cmd("echo \$?");
        chomp($result1[0]);

        if ($result1[0] == 0) {
            if ($result[$#result] =~ /\]/) {
                my @pid = split /\]/,$result[$#result];
                ($pid[1]) =~ s/^\s+//g;
                $procid = $pid[1];
            }
            else {
                ($result[$#result]) =~ s/^\s+//g;
                $procid = $result[$#result];
            }
            $logger->debug(__PACKAGE__ . ".$sub Started xtail for $cescorelog - process id is $procid");
            push @retvalues,$procid;
        } 
        else {
            $logger->error(__PACKAGE__ . ".$sub Unable to start xtail for cescoreLog,Process id set to null");
            push @retvalues,"null";
        } # End if

    } 
    else {
        push @retvalues,"null";
        $cescorelog = "";
    }
    
    # Prepare $eventtxt name
    $conn->prompt('/[\$%#>\?:] +$/');
    $eventtxt = join "_",$args{-test_case},"SGX","eventTxt",uc($args{-host_name}),$timestamp;
    $eventtxt = join ".",$eventtxt,"log";

    # Start tail for tmpEvent logs
    @result = $conn->cmd("cd \$OMNI_HOME/lc($args{-host_name})/tmp");
    @result = $conn->cmd("$sgx_nfs_mount/AUTOMATION/xtail Event*.txt* > $sgx_nfs_mount/AUTOMATION/$eventtxt &");
    chomp($result[$#result]);
    @result1 = $conn->cmd("echo \$?");
    chomp($result1[0]);

    if ($result1[0] == 0) {
        if ($result[$#result] =~ /\]/) {
            my @pid = split /\]/,$result[$#result];
            ($pid[1]) =~ s/^\s+//g;
            $procid = $pid[1];
        }
        else {
            ($result[$#result]) =~ s/^\s+//g;
            $procid = $result[$#result];
        }
        $logger->debug(__PACKAGE__ . ".$sub Started xtail for $eventtxt- process id is $procid");
        push @retvalues,$procid;
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Unable to start xtail for eventtxtLog,Process id set to null");
        push @retvalues,"null";
    } # End if

    # Push filenames of log files created into @retvalues
    push @retvalues,$eventlog;
    push @retvalues,$monitorlog;
    push @retvalues,$cescorelog;
    push @retvalues,$eventtxt;
           
    return @retvalues; 
    
} # End sub sgxLogStart

=head2 sgxlogStop()

 sgxLogStop method is used to kill the tail processes started by sgxLogStart and copy the files from AUTOMATION folder in NFS mount directory to log directory specified by the user.
 The mandatory arguments are process_list,file_list and log dir.

=over

=item Arguments

 -process_list
    List of processes seperated by comma
 -file_list
    List of filenames seperated by comma present in AUTOMATION folder in NFS mount directory(as in sgxLogStart)
 -log_dir
    local log directory where all the log files will be copied to
 -nfs_mount
    specify the nfs mount directory,default is /sonus/SonusNFS

=item Returns

 1-Success
 0-Failure

=item Example

 \$obj->SonusQA::SGX::SGXHELPER::sgxLogStop-process_list => "24761,27567",-file_list => "17461_SGX_logEvent_CALVIN_2008-02-19_13:11:47.log,17461_SGX_tmpEvent_CALVIN_2008-02-19_13:11:47.log",-log_dir => "/home/ukarthik/Logs");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub sgxLogStop {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "sgxLogStop()";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my (@result);
    my $flag = 1; # Assume success
    $conn->prompt('/[\$%#>\?] +$/');

    # Check if mandatory arguments are specified if not return 0
    foreach (qw/ -process_list -file_list -log_dir/) { unless ( $args{$_} ) { $logger->error(__PACKAGE__ . ".$sub $_ required"); return 0; } }

    my $nfs_mount = "/sonus/SonusNFS";
    # Settings nfs mount
    $nfs_mount = $args{-nfs_mount} if ($args{-nfs_mount});

    # Test if $nfs_mount exists
    if (!(-e $nfs_mount)) {
        $logger->error(__PACKAGE__ . ".$sub Directory $nfs_mount does not exist");
        return 0;
    }

    # Test if $args{-log_dir} exists
    if (!(-e $args{-log_dir})) {
        $logger->error(__PACKAGE__ . ".$sub Directory $args{-logdir} does not exist");
        return 0;
    }

    my @procs = split /,/,$args{-process_list};
    my @files = split /,/,$args{-file_list};

    $conn->prompt('/[\$%#>\?:] +$/');    

    foreach (@procs) {
        if ($_ ne "null") {
            @result = $conn->cmd("ps -p $_");
            @result = $conn->cmd("echo \$?");
            chomp($result[0]);
            if ($result[0] == 0) {
                @result = $conn->cmd("kill -9 $_");
                @result = $conn->cmd("echo \$\?");
                chomp($result[0]);

                if ($result[0]) {
                    $logger->error(__PACKAGE__ . ".$sub Process $_ has not been killed");
                    $flag = 0;
                } 
                else {
                    $logger->debug(__PACKAGE__ . ".$sub Process $_ has been killed");
                } # End if
            } 
            else {
                $logger->error(__PACKAGE__ . ".$sub Process $_ does not exist");
                $flag =0;
            } # End if
        } 
        else {
            $logger->error(__PACKAGE__ . ".$sub Process id is null");
            $flag = 0;
        } # End if
    } # End foreach

    foreach (@files) {
        if ($_ ne "") {
            if (system("mv $nfs_mount/AUTOMATION/$_ $args{-log_dir}/")) {
                $logger->error(__PACKAGE__ . ".$sub Move failed for $nfs_mount/AUTOMATION/$_ to $args{-log_dir}");
                $flag = 0;
            } 
            else {
                $logger->debug(__PACKAGE__ . ".$sub File $nfs_mount/AUTOMATION/$_ has been moved to $args{-log_dir}/");
            } # End if
        } 
        else {
            $logger->error(__PACKAGE__ . ".$sub File name is empty");
        } # End if
    } # End foreach
    return $flag;
    
} # End sgxLogStop

=head2 sgxCoreCheck

 sgxCoreCheck checks for cores generated by SGX.The mandatory arguments are testcase and root password.Cores are checked in /export/home/omniusr , /,$OMNI_HOME/conf  and $OMNI_HOME/bin.When a core is found it is renamed to testcase_core in the same directory for future reference.Before calling this function, rename or move the cores in the mentioned directory since this function will try to find file core in the mentioned directories.

=over

=item Arguments

 test_case
 root_password

=item Returns

  Success - Number of cores found
  Failure - 0 - also for no cores found case

=item Example

 $res = $sgxobj->SonusQA::SGX::SGXHELPER::sgxCoreCheck(-root_password => $sgx1_rootpass,-test_case => "17461");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub sgxCoreCheck {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "sgxCoreCheck";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my @result;
    my $corecount = 0;

    # Error if testcase is not set
    if (!defined $args{-test_case}) {

        $logger->error(__PACKAGE__ . ".$sub Test case is not specified");
        return 0;
    } 

    # Error if root password is not set
    if (!defined $args{-root_password}) {

        $logger->error(__PACKAGE__ . ".$sub Root Password is not specified");
        return 0;
    } 

    # Check in $HOME(/export/home/omniusr) core file is generated
    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("find \$HOME -name core");

    foreach (@result) {
        chomp($_);
        if (($_ != "") && ($_ =~ /core/)) {

            $logger->debug(__PACKAGE__ . ".$sub $_");
            my @result1 = $conn->cmd("mv $_ \$HOME/$args{-test_case}_core");
            
            my @result2 = $conn->cmd("echo \$?");
            chomp($result2[0]);
            
            if ($result2[0] == 0) { 
                $logger->debug(__PACKAGE__ . ".$sub Core file found in \$HOME/$args{-test_case}_core");
                $corecount++;
            }
        } 
    } # End foreach

    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("su");
    @result = $conn->cmd("$args{-root_password}");
    
    chomp($result[0]);

    if ($result[0] =~ /Sorry|Incorrect Password/i) {
        $logger->error(__PACKAGE__ . ".$sub Root password was incorrect , unable to login to root");
        return 0;
    } 

    # Check in / if core file is generated
    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("cd /");
    @result = $conn->cmd("ls | grep \"core\"");

    foreach (@result) {
        chomp($_);
        if (($_ != "") && ($_ =~ /core/)) {
            $logger->debug(__PACKAGE__ . ".$sub $_");
            my @result1 = $conn->cmd("mv $_ /$args{-test_case}_core");

            my @result2 = $conn->cmd("echo \$?");
            chomp($result2[0]);
            
            if ($result2[0] == 0) {
                $logger->debug(__PACKAGE__ . ".$sub Core file found in /$args{-test_case}_core");
                $corecount++;
            }
        } 
    } # End foreach

    # Exit from root user
    @result = $conn->cmd("exit");

    # Check in $OMNI_HOME/bin if core file is generated
    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("find \$OMNI_HOME/bin -name \"core\"");

    foreach (@result) {
        chomp($_);
        if (($_ != "") && ($_ =~ /core/)) {
            $logger->debug(__PACKAGE__ . ".$sub $_");
            my @result1 = $conn->cmd("mv $_ \$OMNI_HOME/bin/$args{-test_case}_core");

            my @result2 = $conn->cmd("echo \$?");
            chomp($result2[0]);

            if ($result2[0] == 0) {
                $logger->debug(__PACKAGE__ . ".$sub Core file found in \$OMNI_HOME/bin/$args{-test_case}_core");
                $corecount++;
            }
        } 
    } # End foreach

    # Check in $OMNI_HOME/conf if core file is present
    @result = $conn->cmd("find \$OMNI_HOME/conf -name \"core\"");

    foreach (@result) {
        chomp($_);
        if (($_ != "") && ($_ =~ /core/)) {
            $logger->debug(__PACKAGE__ . ".$sub $_");
            my @result1 = $conn->cmd("mv $_ \$OMNI_HOME/conf/$args{-test_case}_core");

            my @result2 = $conn->cmd("echo \$?");
            chomp($result2[0]);

            if ($result2[0] == 0) {
                $logger->debug(__PACKAGE__ . ".$sub Core file found in \$OMNI_HOME/conf/$args{-test_case}_core");
                $corecount++;
            }
        } 
    } # End foreach

    # Check if cores present and print no cores found if corecount = 0
    if ($corecount == 0) {
        $logger->debug(__PACKAGE__ . ".$sub No Cores found");
    } 

    # Return the corecount value
    return $corecount;

} # End sub sgxCoreCheck

=head2 removeSgxCore()

 This function removes any cores present in /,$OMNI_HOME/bin , $OMNI_HOME/conf and $HOME.

=over

=item Arguments

 -root_password

=item Returns

 1 -Success
 0 -Failure

=item Example

 $res = $sgxobj->SonusQA::SGX::SGXHELPER::removeSgxCore(-root_password => "sonus");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub removeSgxCore {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "removeSgxCore";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my @result;

    # Error if root password is not set
    if (!defined $args{-root_password}) {

        $logger->error(__PACKAGE__ . ".$sub Root Password is not specified");
        return 0;
    } 

    # Login to root
    $conn->prompt('/[\$%#>\?:] +$/');
    @result = $conn->cmd("su");
    @result = $conn->cmd("$args{-root_password}");
    chomp($result[0]);

    if ($result[0] =~ /Sorry|Incorrect Password/i) {
        $logger->error(__PACKAGE__ . ".$sub Root password was incorrect , unable to login to root");
        return 0;
    } 

    $conn->prompt('/[\$%#>\?] +$/');
    @result = $conn->cmd("rm -f \$HOME/core");
    @result = $conn->cmd("ls \$HOME/core");
    chomp($result[0]);
 
    if ($result[0] =~ /No such file/) {
        $logger->debug(__PACKAGE__ . ".$sub No cores in \$HOME");
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Core could not be removed from \$HOME");
        return 0;
    } # End if

    $conn->prompt('/[\$%#>\?] +$/');
    @result = $conn->cmd("rm -f /core");
    @result = $conn->cmd("ls /core");
    
    if ($result[0] =~ /No such file/) {
        $logger->debug(__PACKAGE__ . ".$sub No cores in /");
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Core could not be removed from /");
        return 0;
    } # End if

    $conn->prompt('/[\$%#>\?] +$/');
    @result = $conn->cmd("rm -f \$OMNI_HOME/bin/core");
    @result = $conn->cmd("ls \$OMNI_HOME/bin/core");

    if ($result[0] =~ /No such file/) {
        $logger->debug(__PACKAGE__ . ".$sub No cores in \$OMNI_HOME/bin");
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Core could not be removed from \$OMNI_HOME/bin");
        return 0;
    } 

    $conn->prompt('/[\$%#>\?] +$/');
    @result = $conn->cmd("rm -f \$OMNI_HOME/conf/core");
    @result = $conn->cmd("ls \$OMNI_HOME/conf/core");
  
    if ($result[0] =~ /No such file/) {
        $logger->debug(__PACKAGE__ . ".$sub No cores in \$OMNI_HOME/conf");
    } 
    else {
        $logger->error(__PACKAGE__ . ".$sub Core could not be removed from \$OMNI_HOME/conf");
        return 0;
    } # End if

    # Exit from root
    $conn->prompt('/[\$%#>\?] +$/');
    @result = $conn->cmd("exit");

    return 1;
} # End sub removeSgxCore

=head2 checkSignalwareStopped()

 This functions checks if signalware is stopped by checking if pop, go.omni and port_daemon processes are not running on signalware.

=over

=item Arguments

	None

=item Returns

  Return 1 - If signalware is stopped
  Return 0 - If signalware is running

=item Example

 $res = $sgxobj->SonusQA::SGX::SGXHELPER::checkSignalwareStopped();

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub checkSignalwareStopped {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "checkSignalwareStopped";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my @result;

    $conn->prompt('/[\$%#>\?] +$/');

    # Extract $OMNI_HOME/bin value
    my @path = $conn->cmd("echo \$OMNI_HOME/bin");
    chomp($path[0]);

    my $poppath = $path[0] . "/" . "pop";
    my $omnipath = $path[0] . "/" . "go.omni";
    my $daemonpath = $path[0] . "/" . "port_daemon";
    
    # Check if neither of pop,go.omni or port_daemon are running before proceeding to configureplatform
    my @proc1 = $conn->cmd("ps -aef | grep pop | grep -v grep");
    $proc1[0] =~ s/^\s+|\s+$//g;
    my @proc2 = $conn->cmd("ps -aef | grep go.omni | grep -v grep");
    $proc2[0] =~ s/^\s+|\s+$//g;
    my @proc3 = $conn->cmd("ps -aef | grep port_daemon | grep -v grep");
    $proc3[0] =~ s/^\s+|\s+$//g;
    $logger->debug(__PACKAGE__ . ".$sub **$proc1[0]**$proc2[0]**$proc3[0]**");

    if (($proc1[0] =~ /$poppath/) || ($proc2[0] =~ /$omnipath/) || ($proc3[0] =~ /$daemonpath/)) {
        $logger->debug(__PACKAGE__ . ".$sub Signalware is not stopped");
        return 0;
    } 
    else {
        $logger->debug(__PACKAGE__ . ".$sub Signalware is stopped");
        return 1;
    } # End if

} # End sub checkSignalwareStopped

=head2 checkSignalwareRunning()

 This functions checks if signalware is running by checking if pop process is running on signalware.

=over

=item Arguments

 None

=item Returns

  Return 1 - If signalware is running
  Return 0 - If signalware is not running

=item Example

 $res = $sgxobj->SonusQA::SGX::SGXHELPER::checkSignalwareRunning();

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub checkSignalwareRunning {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "checkSignalwareRunning";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my @result;

    $conn->prompt('/[\$%#>\?] +$/');

    # Extract $OMNI_HOME/bin value
    my @path = $conn->cmd("echo \$OMNI_HOME/bin");
    chomp($path[0]);

    my $poppath = $path[0] . "/" . "pop";

    # Check if pop is  running 
    my @proc1 = $conn->cmd("ps -aef | grep pop | grep -v grep");
    $proc1[0] =~ s/^\s+|\s+$//g;

    $logger->debug(__PACKAGE__ . ".$sub **$proc1[0]**");

    if ($proc1[0] =~ /$poppath/) {
        $logger->debug(__PACKAGE__ . ".$sub Signalware is running");
        return 1;
    } 
    else {
        $logger->debug(__PACKAGE__ . ".$sub Signalware is not running");
        return 0;
    } # End if

} # End sub checkSignalwareRunning

=head2 restartSignalware()

 This functions restarts signalware.

=over

=item Arguments

 -root_password - Root password

=item Returns

  Return 1 - If signalware is successfully stopped and started 
  Return 0 - If signalware is not possible to stop and start 

=item Example

 $res = $sgxobj->SonusQA::SGX::SGXHELPER::restartSignalware(-root_password => "sonus");

=item Author

 P.Uma Maheswari
 ukarthik@sonusnet.com

=back

=cut

sub restartSignalware {

    my($self,%args) = @_;
    my $conn = $self->{conn};
    my $sub = "restartSignalware";
    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    my @result;

    $conn->prompt('/[\$%#>\?:] +$/');

    # Error if root password is not set
    if (!defined $args{-root_password}) {

        $logger->error(__PACKAGE__ . ".$sub Root Password is not specified");
        return 0;
    }

    # Check if signalware is stopped 
    my $res = $self->checkSignalwareStopped();

    # If Signalware not stopped ,Executing Terminate 0 
    if (!$res) {
        $logger->debug(__PACKAGE__ . "$sub Executing Terminate 0 since signalware is not stopped");
        @result = $conn->cmd("Terminate 0");

        # Check for error from Terminate 0
        foreach (@result) {
            if ($_ =~ /error/i) {
                $logger->error(__PACKAGE__ . "$sub Terminate 0 has thrown an error , so we cannot stop Signalware");
                return 0;
            } 
        } # End foreach

        # Wait for Signalware to stop if Terminate 0 has not thrown error
        sleep(20);
        my $res1 = $self->checkSignalwareStopped();
        if (!$res1) {
            $logger->error(__PACKAGE__ . "$sub Unable to stop signalware");
            return 0;
        } 
    } 

    $conn->prompt('/[\$%#>\?:] +$/'); 
    @result = $conn->cmd("su");
    sleep(2);
    @result = $conn->cmd("$args{-root_password}");
    chomp($result[0]);
    if ($result[0] =~ /Sorry|Incorrect/i) {
        $logger->error(__PACKAGE__ . ".$sub Root login failed, checked root password,Signalware stopped but not started");
        return 0;
    } 

    $conn->prompt('/[\$%#>\?:] +$/');
    $conn->cmd("/etc/rc2.d/S95omnistart &");
    sleep(30);

    $conn->cmd("exit");
 
    my $counter = 0;

    while ($counter <=3) {
        if ($self->checkSignalwareRunning()) { 
            $logger->debug(__PACKAGE__ . "$sub Signalware started successfully");
            return 1;
        }  
        sleep(15);
        $counter++;
    } 
        
    $logger->error(__PACKAGE__ . "$sub Unable to restart Signalware");
    return 0;
    
} # End sub restartSignalware

# ******************* INSERT ABOVE THIS LINE:

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

1; # Do not remove
