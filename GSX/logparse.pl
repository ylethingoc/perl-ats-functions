#!/ats/bin/perl -w

use lib "/local/home/atd/ats_repos/lib/perl";

use Pod::Usage;
use strict;

use SonusQA::GSX::UKLogParser;
Log::Log4perl->init( \&SonusQA::Utils::testLoggerConf( "UKGSXEvlogCDRChecker", "INFO" ) );

$SonusQA::GSX::UKLogParser::debuglevel = "INFO";

SonusQA::GSX::UKLogParser::parse_cmdline;
SonusQA::GSX::UKLogParser::validate_options;
SonusQA::GSX::UKLogParser::expand_filenames;
SonusQA::GSX::UKLogParser::get_parse_strings_from_db;
SonusQA::GSX::UKLogParser::get_generic_parse_strings;
my $result = SonusQA::GSX::UKLogParser::matchmaker;
exit !$result;
