package SonusQA::VIGIL::HADOOP;

=head1 NAME

SonusQA::VIGIL::HADOOP- Perl module for VIGIL

=head1 AUTHOR

Vishwas Gururaja - vgururaja@sonusnet.com

=head1 IMPORTANT

B<This module is a work in progress, it should work as described, but has not undergone extensive testing.>

=head1 SYNOPSIS

   use ATS;           # This is the base class for Automated Testing Structure
   
=head1 REQUIRES

Perl5.8.7, Log::Log4perl, SonusQA::Base, Data::Dumper, Module::Locate, SonusQA::VIGIL::HADOOP

=head1 DESCRIPTION

This module provides an interface to execute SQL commands on Hadoop node.

=head1 METHODS

=cut

use strict;
use warnings;

use Log::Log4perl qw(get_logger :easy);
use Module::Locate qw /locate/;
use Data::Dumper;

our $VERSION = "1.0";
our @ISA = qw(SonusQA::VIGIL);

=head2 B<executeSQL()>

=over 6

=item DESCRIPTION:

 This function connects to impala-shell in the hadoop-data node and executes the SQL commands passed to it as the argument and returns a hash containing column name as the key and the records in the column as an array of values.

=item ARGUMENTS:

 %params - ('nodename' => 'hadoop-data-1', 'database' => 'sensorstore', 'command' => 'select * from sonuscdrtable limit 5;')

=item RETURNS:

 A hash - %output
    If the command is a 'select' command
 0
    If the command results in an error
 1
    If the command executed is anything other than select command like 'INSERT', 'DELETE' etc.

=item PACKAGE:

 SonusQA::VIGIL::HADOOP

=item EXAMPLE:

 $vigilObj->{'H-DATA'}->executeSQL('nodename' => 'hadoop-data-1', 'database' => 'sensorstore', 'command' => 'select * from sonuscdrtable limit 5;');

=back

=cut

sub executeSQL{
    my ($self, %params)=@_;
    my (@cmd_Result, $logger, %output, $record_Count, @sorted_table);
    my $sub = "executeSQL";
    $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".$sub");
    $logger->debug(__PACKAGE__ . ".$sub: Entered sub");

    unless($params{'nodename'} and $params{'database'} and $params{'command'}){
        $logger->error(__PACKAGE__ . ".$sub: One or more of the mandatory parameters not present");
        $logger->debug(__PACKAGE__ . ".$sub: Nodename is: \'$params{'nodename'}\', Database is: \'$params{'database'}\', Command is: \'$params{'command'}\'");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }

    my $prompt = '/.*\s*[#>]\s*$/';
    unless ($self->{conn}->cmd(String => "su -s /bin/bash impala -c \"impala-shell --ssl -k -i $params{'nodename'}\"", Prompt => $prompt)) {
        $logger->error(__PACKAGE__ . ".$sub: UNABLE TO ENTER SQL ");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    unless ($self->{conn}->cmd(String => "use $params{'database'}\;", Prompt => $prompt)) {
        $logger->error(__PACKAGE__ . ".$sub: UNABLE TO ENTER DATABASE ");
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    unless (@cmd_Result = $self->{conn}->cmd(String => $params{'command'}, Prompt => $prompt)) {
        $logger->error(__PACKAGE__ . ".$sub: Failed to execute command");
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
        $logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub: sending the exit");
    $self->{conn}->cmd("exit;");


    if (grep (/ERROR:/, @cmd_Result)) {
        $logger->error(__PACKAGE__ . ".$sub: Command \'$params{'command'}\' resulted in error. Result:".Dumper(\@cmd_Result));
        $self->{'SQL_ERROR'} = \@cmd_Result;
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    $logger->info(__PACKAGE__ . ".$sub: successfully executed SQL command: \'$params{'command'}\'");

    unless($params{'command'} =~ /select/i){
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [1]");
        return 1;
    }

    chomp (@cmd_Result);
    @cmd_Result = grep /\S/, @cmd_Result;
    foreach(@cmd_Result){
        if (/\|\s+/) {
            s/^\s+|\s+$//g ;
            my @array = split(/\|/);
            s/^\s+|\s+$//g foreach(@array);
             push(@sorted_table, [@array[1..$#array]]);
        }
    }
    unless((scalar @sorted_table) > 0){
        $logger->error(__PACKAGE__ . ".$sub: No Data found ");
        $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [0]");
        return 0;
    }
    my $len = scalar @{$sorted_table[0]};
    for (my $i = 0;$i<$len;$i++){
        for(my $j = 1;$j<@sorted_table;$j++){
            push (@{$output{$sorted_table[0][$i]}}, $sorted_table[$j][$i]);
        }
    }
    $logger->debug(__PACKAGE__ . ".$sub: <-- Leaving sub [$#sorted_table]");
    return %output;
}

1;
