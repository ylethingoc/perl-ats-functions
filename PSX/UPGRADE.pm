package SonusQA::PSX::UPGRADE;

=head1 NAME

SonusQA::PSX::UPGRADE - Perl module for PSX IUG procedures

=head1 REQUIRES

Log::Log4perl, Data::Dumper, SonusQA::ILOM

=head1 DESCRIPTION

This module provides APIs for PSX ISO/APP installation & upgrade on various nodes.

=head1 AUTHORS


=head1 METHODS

=cut

use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Utils;


=head2 C< doUpgrade >

	This subroutine executes the upgrade script for different combinations of type and variant of PSX and stores the logs in $log_file path.	

=over

=item Arguments:
	This subroutine expects 5 arguments:
		testbed  = tms testbed alias.
		iso_path = path to the iso file to be used.
		type     = it should be one of the following:
			'active'  : for HA active
			'standby' : for HA standby
			'master'  : for Standalone Master
			'slave'   : for Standalone Slave
		variant  = Optional value. Required only for HA. It should be one of the following:
			'SAN'     :
			'V3700'   :
		ldm      = Optional value. Required only when type is 'slave'.


=item Returns:

	returns 1 if successful, 0 if failed.

=item Example:
	recommended to use in if/unless case to check succesful completion of command

	unless (SonusQA::UPGRADE->doUpgrade(
				testbed => "$TESTBED{ "psx:1:ce0" }",
				iso_path=> "/home/<somepath>/<filename>.iso",
				type    => "active",
				variant => "v3700"
					)
		) {
		<do your fail case procedure>
	}

=back


=cut


sub doUpgrade {
	my ($self, %args) = @_;
	my $cmd;	
	my $sub_name = 'doUpgrade';
	my $flag = 'true';
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub_name");
	$logger->info(__PACKAGE__ . ".$sub_name: <-- Entered Sub");

	$args{variant} = 'Psx' if (!$args{variant} && (($args{type} eq 'slave') || ($args{type} eq 'master')));
	
	foreach (qw(testbed iso_path type variant)) { #checking mandatory parameters defined or not
		unless ($args{$_} ) {
			$logger->error(__PACKAGE__ . ".$sub_name: ERROR: Mandatory \"$_\" parameter not provided ");
			$logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
			$flag = '';
			last;
		}
	}
	return 0 unless($flag);	

	
	if(!$args{ldm} && $args{type} eq 'slave') { #checking optional ldm value whether defined, if type is equal to 'slave'
		$logger->error(__PACKAGE__ . ".$sub_name: ERROR: Mandatory \"ldm\" parameter not provided ");
		$logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
 		return 0;
	}
	
	$args{type} = uc $args{type};
	$args{variant} = uc $args{variant};
	


	my ($iso, $version) = $args{iso_path} =~ /(psx-(V\d\d\.\d\d).+-RHEL.+.iso)/i;
	$iso =~ s/^\s+//;
    	$iso =~ s/\s+$//;
	
	$version =~ s/\.//g;

	my $testbed_alias_data = SonusQA::Utils::resolve_alias($args{testbed});
	
	my $psx_ilom_ip = $testbed_alias_data->{NODE}->{1}->{ILOM_IP};
	my $psx_ip = $testbed_alias_data->{NODE}->{1}->{IP};
	
	unless($psx_ilom_ip && $psx_ip) {
		$logger->error(__PACKAGE__ . ".$sub_name: ERROR: Mandatory \"psx_ilom_ip\" or \"psx_ip\" parameter not initialized. ");
		$logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		return 0;
	}

	my $log_file = "$ENV{ HOME }/ats_user/logs/upgrade$args{variant}"."$args{type}"."_$psx_ip"."_". time;
	
	my $upgrade_script = "$ENV{ HOME }/ats_repos/lib/perl/SonusQA/PSX/ExpectScripts/$version/UPGRADE/upgrade_$args{variant}"."_$args{type}";
	
	unless(-e $upgrade_script) {
		$logger->error(__PACKAGE__ . ".$sub_name: ERROR: required script doesn't exist: '$upgrade_script'");
		$logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [0]");
		return 0;	
	}

	$cmd = $upgrade_script. " $args{ldm} " if($args{type} = 'SLAVE' && defined($args{ldm})); #Adding ldm as a parameter if defined and if type is slave.
	
	$cmd= $cmd. "$psx_ilom_ip $psx_ip $args{iso_path} $iso > $log_file";
		
	$logger->debug(__PACKAGE__ . ".$sub_name: executing $args{type} upgrade command: $cmd");

	`$cmd`;
	

	$logger->info(__PACKAGE__ . ".$sub_name: <-- Leaving Sub [1]");
	return 1;
	
}



1;

