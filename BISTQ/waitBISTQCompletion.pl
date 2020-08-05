#!/usr/bin/env perl

# I guess we no longer need below perl
# #!/sonus/p4/common/perl/bin/perl -w -I/sonus/p4/common/perl/site/lib -I/sonus/p4/common/perl/lib
# Note - we use the /p4/common/bin/perl above as it is known to have DBI and DBD::mysql and should be shared accross build machines.

=head1 waitBISTQCompletion.pl

Does exactly what it says on the tin - given a BISTQ JobID - polls the DB every 60s and waits for the Job to complete - printing status as it goes.

B<This is intended to be called by Jenkins on a *build* slave -  and not from an ATS machine.>

=head1 Usage

    waitBISTQCompletion.pl <jobId> [ Optional wait-timeout in minutes ]

=cut

use strict;
use JSON;
use REST::Client;

local $| = 1; # Turn on autoflush so we get more timely feedback in the Jenkins log viewer

my $jobId = $ARGV[0];
my $timeout = $ARGV[1] ? $ARGV[1] : -1 ; # Minutes, -1 == infinite wait (or at least until negative integer wraps ;-)

print "START - Waiting for Job ID $jobId\n";
my $count=0;
my $seen=0;

do {
    $count=0;

    my $client = REST::Client->new();

    my $headers = {'Content-Type' => 'application/json', Accept => 'application/json'};
    my $url = "https://tms.rbbn.com/api/v1/bistq/$jobId/";
    $client->request('GET', $url, '', $headers);

    my $response = decode_json($client->responseContent());
    if(defined $response->{'jobid'}){
        $seen=1;
        $count++;
        if($response->{'currenttest'} ne 'Null') { ## Our test is running as it has a status
	        print "Job: $jobId Qslot: $response->{'qslot'} Status: $response->{'currenttest'}\n";
        } else {
            print "Job: $jobId Qslot: $response->{'qslot'} Status: WAITING FOR TESTBED AVAILABILITY\n";
        }
    }

    sleep 60 unless ($count == 0);
    $timeout-- 
} until ($count == 0 or $timeout == 0); 

if($seen) {
    if($timeout == 0) {
            print "END - Job $jobId did not complete in $ARGV[1] minutes - TIMEOUT\n";
    } else {
            print "END - Job $jobId has finished executing\n";
    }
    # Temporary (30/11/2018) Disable this as we re-work centralized logging) - Malc
=cut
    # Query elasticsearch (centralized logging) for anything matching this JOBUUID which isn't DEBUG or INFO level.
    my $client = REST::Client->new();
    $client->setFollow(1);

    my $headers = {'Content-Type' => 'application/json', Accept => 'application/json'};

    $client->request('GET', 'http://masterats3.sonusnet.com:9200/_search', '{"sort":[{"time":{"order":"asc","unmapped_type":"boolean"}}],"query": { "bool": { "must": [ { "query_string": { "query": "jobuuid:\"'.$jobId.'\"", "analyze_wildcard": true } } ], "must_not": [ { "match_phrase": { "level": { "query": "DEBUG" } } }, { "match_phrase": { "level": { "query": "INFO" } } } ] } } }', $headers);

    my $response = decode_json($client->responseContent());
    print "Found log output with WARN or above from the Installation/Suite kick-off:\n" if (@{$response->{hits}->{hits}});
    foreach my $hit (@{$response->{hits}->{hits}}) {
        my $h = $hit->{_source};
        print "$h->{time} $h->{level} $h->{message}\n";
    }
=cut

} else {
    print "END - Job $jobId was not found in queue\n";
}

