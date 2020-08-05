package SonusQA::SessUnixBase;

use strict; 
use warnings;   
use SonusQA::Utils qw(:errorhandlers :utilities); 
use Sys::Hostname;
use File::Basename;
use Log::Log4perl qw(get_logger :easy);
use Net::Telnet;
use XML::Simple;
use Data::Dumper;
use POSIX qw(strftime);
require ATS;   

=head1 NAME

SonusQA::SessUnixBase- SonusQA session Unix Base class

=head1 DESCRIPTION

	SonusQA::SessUnixBase is used by Base.pm and PSX.pm

=head2 METHODS


=head3 _sessFileExists

	Used to check whether a file exists or not	

=over 

=item Argument

	LogPath  

=item Returns

	Return size of the file, If successful
	Return undef,If Failed	

=back

=cut

sub _sessFileExists {
  my ($self, $logPath)=@_;
  my (@cmdResults, $cmd, $logger, $line, $size);
  $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".removeLog");
  if(!defined($logPath)){
    $logger->warn(__PACKAGE__ . "._sessFileExists  PATH MISSING OR NOT DEFINED - REQUIRED");
    return 0;
  }
  $self->{conn}->prompt($self->{PROMPT});  # This is required.
  ($line) = $self->{conn}->cmd("/bin/ls -l $logPath");
  my ($size_bsd, $size_sysv) = (split ' ', $line)[3,4];
  if ( ($size_sysv =~ /^(\d+)$/)  || ($size_bsd =~ /^(\d+)$/) ){
    $size = $1;
    return $size;
  }
  else {
    return undef;
  }  
}

=head3 _sessFileExtension

         Used to get the File extension

=over

=item Argument

        file_path

=item Returns

        Return the file extension  

=back

=cut

sub _sessFileExtension {
  my ($self, $file)=@_;
  my(undef, undef, $ftype) = fileparse($file,qr{\..*});
  return $ftype;
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
