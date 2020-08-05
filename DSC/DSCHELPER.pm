package SonusQA::DSC::DSCHELPER;

use SonusQA::Utils qw(:errorhandlers :utilities logSubInfo);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::DSC;

=head1 B<sub dsc_pattern_search()>

=over 6

=item  DESCRIPTION:

 The function is called to match pattern with count in DSC logs.

=item ARGUMENTS:

 1. Host Object
 2. Testcase Alias
 3. Array refrence for patterns
 4. log type e.g. dbg, sys
 5. Expected count of pattern match

=item PACKAGE:

 SonusQA::DSC::DSCHELPER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - success
 0 - failure 

=item EXAMPLE:

 @pattern = ("Pattern 1","Pattern 2");
 @logtypes = ("dbg","sys");
 $obj->dsc_pattern_search($testId,\@pattern,$logtypes,$count)

=back

=cut

sub dsc_pattern_search {

    my ( $self, $testId, $patterns, $log, $count ) = @_;

    my $sub    = "dsc_pattern_search()";
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );
    $logger->debug( __PACKAGE__ . ".$sub: --> Entered Sub" );

    my @array = @$patterns;
    my ( $file, $cmd1, $string, @find );
    $log = uc($log);

    unless ( $self->{conn}->cmd("cd /var/log") ) {
        $logger->error( __PACKAGE__ . ". $sub  COULD NOT CHANGE TO DSC LOG DIR " );
        $logger->debug(__PACKAGE__ . ".$sub: errmsg: " . $self->{conn}->errmsg);
	$logger->debug(__PACKAGE__ . ".$sub: Session Dump Log is : $self->{sessionLog1}");
        $logger->debug(__PACKAGE__ . ".$sub: Session Input Log is: $self->{sessionLog2}");
        return 0;
    }

    if (   ( $log =~ /^SYS/ )
        || ( $log =~ /^DBG/ ) )
    {
        $file = "$testId" . "." . "$log"
          unless ( $file =~ "\.$log" );

        foreach (@array) {
            $cmd1   = "grep -a " . "\"$_\"" . " $file \| wc \-l";
            @find   = $self->execCmd($cmd1);
            $string = $find[0];
            $string =~ s/^\s+//;
            $logger->debug( __PACKAGE__ . ".$sub Number of occurences of the string $_ in $file is $string" );
            unless ($string) {
                $logger->error( __PACKAGE__ . ".$sub No OCCURENCE of $_ in $file...Waiting 5 seconds" );
                sleep(5);
                @find   = $self->execCmd($cmd1);
                $string = $find[0];
                $string =~ s/^\s+//;
                $logger->debug( __PACKAGE__ . ".$sub Number of occurences of the string $_ in $file is $string" );
                unless ($string) {
                    $logger->error( __PACKAGE__ . ".$sub No OCCURENCE of $_ in $file even after waiting for 5 seconds" );
                    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
                    return 0;
                }
            }

            if ( defined $count and $count ) {
                if ( $string == $count ) {
                    $logger->info( __PACKAGE__ . ".$sub  Number of occurences of the string $_ in $file is $string is matches to required count -> $count" );
                }
                else {
                    $logger->info( __PACKAGE__ . ".$sub  Number of occurences of the string $_ in $file is $string is does not matches to required count -> $count" );
                    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
                    return 0;
                }
            }

        }
        $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
        return 1;
    }
    else {
        $logger->error( __PACKAGE__ . ".$sub Invalid Log File Name...Leaving $sub [0]" );
    }
    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
    return 0;
}

=head1 B<sub collectDscLogs()>

=over 6

=item DESCRIPTION:

 The function is called to collect DSC logs in a specific file. Logs are tailed from ptidbglog for DBG logs and ptisyslog for SYS logs and redirected to test_alias.DBG and 
 test_alias.SYS respectively.

=item ARGUMENTS:

 1. Host Object
 2. Array refrence for log types

=item PACKAGE:

 SonusQA::DSC::DSCHELPER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - success
 0 - failure 

=item EXAMPLE:

 @logtypes = ("dbg","sys");
 $obj->collectDscLogs($test_alias,\@logtypes)

=back

=cut

sub collectDscLogs {
    my $sub    = "collectDscLogs";
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );
    $logger->debug( __PACKAGE__ . ".$sub: --> Entered Sub" );

    my ( $self, $testId, $logtypes ) = @_;
    my %logfile = (
        'DBG' => 'ptidbglog',
        'SYS' => 'ptisyslog'
    );
    my @cmdResult;
    foreach (@$logtypes) {
        unless ( $self->execShellCmd("cd /var/log") ) {
            $logger->error( __PACKAGE__ . ".$sub Could not enter log directory " );
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
            return 0;
        }
        @cmdResult                 = $self->execCmd( "tail -f $logfile{uc($_)} > $testId" . "." . uc($_) . " &" );
        @cmdResult                 = split( /]/, $cmdResult[0] );
        $self->{ uc($_) . "_PID" } = $cmdResult[1];
        unless ( $self->{ uc($_) . "_PID" } =~ m/(\s+)(\d+)/ ) {
            $logger->error( __PACKAGE__ . ".$sub Could not start log collection" );
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
            return 0;
        }
        $logger->info( __PACKAGE__ . ".$sub Started $_ log collection on process ID $cmdResult[1]" );
    }
    $logger->info( __PACKAGE__ . ".$sub Started log collection for all the processes successfully" );
    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
    return 1;
}

=head1 B<sub moveDscLogs()>

=over 6

=item DESCRIPTION:

 The function is called to stop the tailing of logs for the specific testcase and to transfer the logs specific server.

=item ARGUMENTS:

 1. Host Object
 2. Logtypes array refrence
 3. Hash with scp arguments

=item PACKAGE:

 SonusQA::DSC::DSCHELPER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - success
 0 - failure 

=item EXAMPLE:
	
 @dscLogTypes = ("DBG","SYS");
 $dscScpArgs{-hostip} = $dscObj->{TMS_ALIAS_DATA}->{'NODE'}->{'1'}->{'IP'};
 $dscScpArgs{-hostuser} = "root";
 $dscScpArgs{-hostpasswd} = $dscObj->{TMS_ALIAS_DATA}->{'LOGIN'}->{'1'}->{'ROOTPASSWD'};
 $dscScpArgs{-scpPort} = "22";
 $dscScpArgs{-sourceFilePath} = $dscScpArgs{-hostip}.":"."/var/log/$test_alias";
 $dscScpArgs{-destinationFilePath} = $localpath;
 $dscObj->moveDscLogs(\@dscLogTypes,%dscScpArgs);

=back

=cut

sub moveDscLogs {
    my $sub    = "moveDscLogs";
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );
    $logger->debug( __PACKAGE__ . ".$sub: --> Entered Sub" );
    my ( $self, $logtypes, %logscpargs ) = @_;
    my @cmdResult;
    my $tmp = $logscpargs{-sourceFilePath};
    foreach (@$logtypes) {

        $logscpargs{-sourceFilePath} = $logscpargs{-sourceFilePath} . "." . uc($_);
        my $log = $1
          if ( $logscpargs{-sourceFilePath} =~ m{/var/log/(.*)$} );

        unless ( $self->execShellCmd("kill -9 $self->{uc($_).'_PID'}") ) {
            $logger->error( __PACKAGE__ . ".$sub Could not kill $_ PID. Could not stop tailing the log " );
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
            return 0;
        }
        unless ( $self->execShellCmd("cd /var/log") ) {
            $logger->error( __PACKAGE__ . ".$sub Could not enter log directory " );
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
            return 0;
        }
        unless ( $self->execShellCmd("gzip -f $log") ) {
            $logger->error( __PACKAGE__ . ".$sub Could not zip the log files successfully" );
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
            return 0;
        }
        $logscpargs{-sourceFilePath} = $logscpargs{-sourceFilePath} . ".gz";

        unless ( &SonusQA::Base::secureCopy(%logscpargs) ) {
            print "Error copying $logscpargs{-sourceFilePath} log file to Log server!\n";
            $logger->error( __PACKAGE__ . " Error copying $logscpargs{-sourceFilePath} logs to log server" );
        }
        else {
            print "SCP of $logscpargs{-sourceFilePath} log to Log server successful \n";
            $logger->debug( __PACKAGE__ . " SCP of $logscpargs{-sourceFilePath} log to Log server successful" );
        }

        $log .= ".gz";
        unless ( $self->execShellCmd("rm -f $log") ) {
            $logger->error( __PACKAGE__ . ".$sub Could not remove $log " );
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
            return 0;
        }
        $logscpargs{-sourceFilePath} = $tmp;
    }

    #scp the logs like testId* to DUTlogs and remove them
    $logger->info( __PACKAGE__ . ".$sub Successfully copied the logs to remote server" );
    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );

    return 1;
}

=head1 B<sub restartDsc()>

=over 6

=item DESCRIPTION:

 The function is called to restart dsc processes. The following processes are killed. 
       npgw
       dsc.1
       dsc.2
       dinamo
  Since watchdog process monitors DSC processes it starts the processes again.

=item ARGUMENTS:

 1. Host Object

=item PACKAGE:

 SonusQA::DSC::DSCHELPER

=item GLOBAL VARIABLES USED:

 None

=item EXTERNAL FUNCTIONS USED:

 None

=item OUTPUT:

 1 - success
 0 - failure 

=item EXAMPLE:

 $dscObj->restartDsc;

=back 

=cut

sub restartDsc {
    my $sub    = "restartDsc";
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ . ".$sub" );
    $logger->debug( __PACKAGE__ . ".$sub: --> Entered Sub" );
    my ($self) = @_;

    my @processes = $self->execCmd("wd | grep \"dinamo \\| dsc.2 \\| dsc.1 \\| npgw\" | awk -F\" \" '{printf \"%8s%8d\\n\",\$8,\$2}'");
    shift @processes;
    foreach (@processes) {
        $_ =~ s/^\s+//;
        my ( $p_name, $pid ) = split( /\s+/, $_ );
        $self->execShellCmd("kill -9 $pid");
        sleep 5;
        my @new_pid = $self->execCmd("wd | grep \"$p_name\" | awk -F\" \" '{print \$2}'");
        if ( $pid == $new_pid[0] ) {
            $logger->error( __PACKAGE__ . ".$sub Failed to restart $p_name process" );
            $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );
            return 0;
        }
        else {
            $logger->info( __PACKAGE__ . ".$sub Restarted $p_name process successfully" );
        }
    }
    $logger->debug( __PACKAGE__ . ".$sub: <-- Leaving Sub [1]" );

    return 1;
}

1;
