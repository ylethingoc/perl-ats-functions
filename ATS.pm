package ATS;

=pod

=head1 NAME

ATS - Perl module for Automated Test System intergration

=head1 SYNOPSIS

   use ATS;  # This is the base class for Automated Testing Structure
   
   The ATS Package will automatically load available packages from the Automated Testing Structure.
   Currently this package loads:
   
    require SonusQA::ATSHELPER;
    require SonusQA::Utils;
    require SonusQA::Base;
    require SonusQA::UnixBase;
    require SonusQA::SessUnixBase;
    require SonusQA::HARNESS;
    require SonusQA::DSI;
    require SonusQA::DSI::DSIHELPER;
    require SonusQA::DSICLI;
    require SonusQA::DSICLI::DSICLIHELPER;
    require SonusQA::GBL;
    require SonusQA::GSX;
    require SonusQA::GSX::GSXHELPER;
    require SonusQA::SBX5000;
    require SonusQA::SBX5000::SBX5000HELPER;
    require SonusQA::EMSCLI;
    require SonusQA::EMSCLI::EMSCLIHELPER;
    require SonusQA::EMS;
    require SonusQA::EMS::EMSHELPER;
    require SonusQA::SIPP;
    require SonusQA::DIAMAPP;
    require SonusQA::PSX;
    require SonusQA::PSX::PSXHELPER;
    require SonusQA::SGX;
    require SonusQA::SGX::SGXHELPER;
    require SonusQA::SGX::SGXUNIX;
    require SonusQA::NISTnet;
    require SonusQA::EAST;
    require SonusQA::ORACLE;
    require SonusQA::ORACLE::ORACLEHELPER;
    require SonusQA::Inet;
    require SonusQA::SPECTRA2;
    require SonusQA::MGTS;
    require SonusQA::MGTS::MGTSHELPER;
    require SonusQA::SGX4000;
    require SonusQA::SGX4000::SGX4000HELPER;
    require SonusQA::MSX;
    require SonusQA::MSX::MSXHELPER;
    require SonusQA::BSX;
    require SonusQA::BSX::BSXHELPER;
    require SonusQA::MGW9000;
    require SonusQA::MGW9000::MGW9000HELPER;
    require SonusQA::MGW9000::MGW9000LTT;
    require SonusQA::FORTISSIMO;
    require SonusQA::NAVTEL;
    require SonusQA::NAVTEL::NAVTELSTATSHELPER;
    require SonusQA::SIMS;
    require SonusQA::SIMS::SIMSHELPER;
    require SonusQA::TSHARK;
    require SonusQA::DIAMETER;
    require SonusQA::LISERVER;   
    require SonusQA::SEAGULL;
    require SonusQA::PROLAB;
    require SonusQA::DNS;
    require SonusQA::TOOLS;
    require SonusQA::TOOLS::TOOLSHELPER;
    require SonusQA::SELENIUM ;
    # require SonusQA::TMAGUI ;
    require SonusQA::RACOON ;
    require SonusQA::VALID8;
    require SonusQA::VIGIL;
    Please see individual  documentation for the above libraries independently.

=head1 REQUIRES

Perl5.8.6, L<Module::Locate>, L<File::Basename>

=head1 DESCRIPTION

   This is an all in one include for all Perl Modules related to Sonus Automation.

=head2 AUTHORS

Darren Ball <dball@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.
See Inline documentation for contributors.

=head2 SUB-ROUTINES

=cut



use Module::Locate qw / locate /;
use File::Basename;

our (
     $Root,
     $ReleaseEngPath,
     $ReleaseEngServer,
     $location,
    );

BEGIN {
    # Retrieve package location, and pickup SonusQA namespace libraries.
    my $location = locate __PACKAGE__;
    my ($name,$path,$suffix) = fileparse($location,"\.pm"); 
    $path .= "SonusQA";
    push(@INC,$path);
    opendir(DIR, $path);
    foreach $name (sort readdir(DIR)) {
        if(-d $name){
            push(@INC,$name)
        }
    }
    closedir(DIR);
};

## Include the rest of the SonusQA library.

use SonusQA::Utils qw(:all);
use Log::Log4perl qw(:easy get_logger :levels);
Log::Log4perl->easy_init($DEBUG);
use Class::Autouse qw {
SonusQA::ATSHELPER 
Sonus::Utils 
SonusQA::Base 
SonusQA::UnixBase 
SonusQA::SessUnixBase 
SonusQA::HARNESS 
SonusQA::DSI 
SonusQA::DSI::DSIHELPER 
SonusQA::DSICLI 
SonusQA::DSICLI::DSICLIHELPER 
SonusQA::GBL 
SonusQA::GSX 
SonusQA::GSX::GSXHELPER 
SonusQA::DSC 
SonusQA::DSC::DSCHELPER 
SonusQA::SBX5000 
SonusQA::SBX5000::HARNESS
SonusQA::SBX5000::SBX5000HELPER 
SonusQA::SBX5000::SBXLSWUHELPER 
SonusQA::SBX5000::PERFHELPER
SonusQA::SBCEDGE
SonusQA::EMSCLI 
SonusQA::EMSCLI::EMSCLIHELPER  
SonusQA::PSX 
SonusQA::PSX::PSXHELPER 
SonusQA::SGX 
SonusQA::SGX::SGXHELPER 
SonusQA::SGX::SGXUNIX 
SonusQA::NISTnet 
SonusQA::EAST 
SonusQA::SIPP 
SonusQA::ORACLE 
SonusQA::ORACLE::ORACLEHELPER 
SonusQA::Inet 
SonusQA::SPECTRA2 
SonusQA::MGTS 
SonusQA::MGTS::MGTSHELPER 
SonusQA::SGX4000 
SonusQA::SGX4000::SGX4000HELPER 
SonusQA::MSX 
SonusQA::MSX::MSXHELPER 
SonusQA::BSX 
SonusQA::BSX::BSXHELPER 
SonusQA::BRX 
SonusQA::BRX::BRXHELPER 
SonusQA::MGW9000 
SonusQA::MGW9000::MGW9000HELPER 
SonusQA::MGW9000::MGW9000LTT 
SonusQA::FORTISSIMO  
SonusQA::NAVTEL 
SonusQA::NAVTEL::NAVTELSTATSHELPER 
SonusQA::SIMS 
SonusQA::SIMS::SIMSHELPER 
SonusQA::TSHARK 
SonusQA::DIAMETER 
SonusQA::LISERVER 
SonusQA::IXIA 
SonusQA::SEAGULL  
SonusQA::PROLAB 
SonusQA::SELENIUM 
# SonusQA::TMAGUI
SonusQA::DNS 
SonusQA::TOOLS 
SonusQA::TOOLS::TOOLSHELPER 
SonusQA::EMS 
SonusQA::EMS::EMSHELPER 
SonusQA::POLYCOM 
SonusQA::RACOON 
SonusQA::VMCTRL
SonusQA::CDA
SonusQA::ILOM
SonusQA::VALID8
SonusQA::C3
SonusQA::CRS
SonusQA::AMA
SonusQA::NDM
SonusQA::VNFM
SonusQA::SCPATS
SonusQA::VIGIL
SonusQA::SWITCH
SonusQA::QSBC};

1;
