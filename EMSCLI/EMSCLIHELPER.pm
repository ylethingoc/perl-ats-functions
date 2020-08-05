package SonusQA::EMSCLI::EMSCLIHELPER;

=head1 NAME

 SonusQA::EMSCLI::EMSCLIHELPER - Perl module for Sonus Networks EMS CLI interaction

=head1 REQUIRES

 Perl5.8.6, Log::Log4perl, Sonus::QA::Utilities::Utils, Data::Dumper, POSIX

=head1 DESCRIPTION

 This is a place to implement frequent activity functionality, standard non-breaking routines.
 Items placed in this library are inherited by all versions of EMS CLI - they must be generic.

=head1 METHODS

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use Data::Dumper;
use POSIX qw(strftime);

our $VERSION = "6.1";

use vars qw($self);

=head1 B<getPSXShowResults()>

=over 6

=item Description:

 This helper function was created to take the results of a PSX show command and parse into a hash of key value pairs.

=item Arguments:

 PSX output array

=item Returns:

 Hash in the form of key=>value from the array

=item Package:

  SonusQA::EMSCLI::EMSCLIHELPER
 
=back

=cut

sub getPSXShowResults {

	my ($self, @cmdResults ) = @_;
	my %keyValueMap;
	foreach ( @cmdResults ) {
		my @tmp = split /:/, $_;
		my $key = $tmp[0];
		$key =~ s/^\s+//;  # remove whitespace
			$key =~ s/\s+$//;  # remove whitespace
			my $val = $tmp[1];
		$val =~ s/^\s+//;  # remove whitespace
			$val =~ s/\s+$//;  # remove whitespace
			$val =~ s/~/""/;
		if ( $val =~ m/ / ) {
			$keyValueMap{$key} = "\"" . $val . "\"";
		} else {
			$keyValueMap{$key} = $val;
		}
	}
	return %keyValueMap;
}

=pod

=head1 B<updateIpPortFromCSV()>

=over 6

=item DESCRIPTION:

 This routine is responsible for genertaing IpSignalingPeerGroup and IPPeer commands and its execution.
 Commands are generated using .csv file and are executed using subroutine execCmd()

=item ARGUMENTS:

 Name of .csv file.

 Mandatory :
     
     $file : Name of .csv file.

 Optional:

     NONE

=item PACKAGE:

 SonusQA::EMSCLI::EMSCLIHELPER

=item GLOBAL VARIABLES USED:

 None

=item OUTPUT:

 returns 0 if  
            1. it fails to get the file name.
            2. it fails to open the file.
            3. Header is other than IpSignalingPeerGroup and IPPeer.
            4. none of the commands are executed.
 returns 1 if One or more commands are executed.

=item EXAMPLES:

 $obj->updateIpPortFromCSV('comnds.csv');

=back

=cut

sub updateIpPortFromCSV   {
    my ($self, $file ) = @_;
    my  $sub = "updateIpPortFromCSV";

    my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: --> Entering Sub ");

    unless ($file) {
        $logger->error(__PACKAGE__ . ".$sub: File name is  not passed");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    unless( open ( IN,"<$file")){
        $logger->error(__PACKAGE__ . ".$sub: Unable to open the $file");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my ($select_cmd);
    my @content = <IN>;
    close IN;
    my $frst_lne = shift @content;
    if ($frst_lne =~ /^.*(IpSignalingPeerGroup|IPPeer|Gateway_Id).*$/) {
        $select_cmd = $1;
    }
    else {
        $logger->error(__PACKAGE__ . ".$sub:Can execute the commands only for headers IpSignalingPeerGroup, IPPeer and Gateway_Id ");
        $logger->error(__PACKAGE__ . ".$sub:$frst_lne ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [0]");
        return 0;
    }
    my $flag = 0;
    my $cmd;
    foreach(@content) {
        chomp $_;
        my @values = split("," , $_);
        next unless ($values[0]);
        if ($select_cmd eq "IpSignalingPeerGroup") {
            $cmd = "update Ip_Signaling_Peer_Group_Data Ip_Signaling_Peer_Group_Id $values[0] Sequence_Number 0 Service_Status 1 Ip_Address $values[1]  Port_Number $values[2]";
        }
        elsif ($select_cmd eq "IPPeer") {
            $cmd = "update Ip_Peer Ip_peer_Id $values[0] Ipv6_Address $values[1] Ipv6_Port_Number $values[2]";
        }
        else {
            $cmd = "update Gateway Gateway_Id $values[0] Sip_Ip_st $values[1] Sip_Ip_sh $values[2]";
        }
        unless($self->execCmd($cmd)) {
                $logger->warn(__PACKAGE__ . ".$sub: Failed to execute command -->$cmd ");
        }
        else {
            $flag = 1;
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving Sub [$flag]");
    return $flag;
}




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
# Do not remove
