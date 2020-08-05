package SonusQA::NetConf;


=pod

=head1 NAME

SonusQA::NetConf - Perl module for NetConf interaction

=head1 SYNOPSIS

   use SonusQA::NetConf;  # This is the class for the ATS interface to a NetConf compliant device.
   
   my $netem = SonusQA::NetConf->new(-OBJ_HOST => '<host name | IP Adress>',
                                   -OBJ_USER => '<cli user name>',
                                   -OBJ_PASSWORD => '<cli user password>',
                                   -OBJ_COMMTYPE => "<NETCONF>",
                                );

=head1 REQUIRES

Perl5.8.6, Log::Log4perl, SonusQA::Base, SonusQA::Utils, Data::Dumper, POSIX, XML::DOM

=head1 DESCRIPTION

   This module provides an interface for interacting with a target device via NetConf as defined in RFC4741

=head1 AUTHORS

Malcolm Lashley <mlashley@sonusnet.com>, alternatively contact <sonus-auto-core@sonusnet.com>.
See Inline documentation for contributors.

=head1 Test/Example code

Example/Test code is included at the bottom of the module - please ensure this runs correctly when submitting changes.

=head1 SUB-ROUTINES

The following subroutines contain the guts of the implementation - subroutines considered 'private' (in the sense of C++) start with an underscore, it is not expected these are used directly.

=cut

use SonusQA::Utils qw(:errorhandlers :utilities);
use strict;
use Log::Log4perl qw(get_logger :easy);
use SonusQA::Base;
use SonusQA::UnixBase;
use Data::Dumper;
use XML::DOM;

use POSIX qw(strftime);

our $VERSION = "1.0";

use vars qw($self);
our @ISA = qw(SonusQA::Base SonusQA::UnixBase);

# INITIALIZATION ROUTINES FOR CLI
# -------------------------------


# ROUTINE: doInitialization
# Routine to set object defaults and session prompt.
sub doInitialization {
	my($self)=@_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".doInitialization");
	my($temp_file);
 	$self->{COMMTYPES} = ["NETCONF"];
	$self->{TYPE} = "NetConf";
	$self->{conn} = undef;
	$self->{PROMPT} = '/]]>]]>/';
    $self->{DEFAULTPROMPT} = $self->{PROMPT}; #used in SonusQA::Base::reconnect() to set the PROMPT back to DEFAULTPROMPT (TOOLS-4296)
	$self->{SESSIONLOG} = 0; # Set to 1 to enable session logs dumped to /tmp 
}

# Internal helper routing to wrap a netconf request inside the proper rpc tags, and to provide an 
# auto-incrementing message ID as required by the protocol.
# Not intended for public usage
# AUTHOR: Malcolm Lashley <mlashley@sonusnet.com>

sub _wrapRPC {
	my ($self,$cmd) = @_;
	$self->{RPC_MESSAGE_ID} = 100 if (!defined $self->{RPC_MESSAGE_ID});
	my $rpc_message_id = $self->{RPC_MESSAGE_ID}++;
	return '<nc:rpc message-id="'.$rpc_message_id.'"
xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0"
>'.$cmd.'</nc:rpc>';
}

# Internal helper routine to wrap a request in the proper XML tags, and add the command termination string.
# Not intended for public usage
# AUTHOR: Malcolm Lashley <mlashley@sonusnet.com>

sub _wrapXML {
	my ($self,$cmd) = @_;
	my $sub_name = "._wrapXML";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);
	$logger->debug(__PACKAGE__ . "$sub_name Pre conversion $cmd");
	$cmd =~ s/\n//g; # It's XML - whilst we might like to put in carriage returns in our test scripts for readability - no need to send them to the device (and anyway it breaks Base.pm's use of Net::Telnet's cmd_remove_mode.
	$cmd = '<?xml version="1.0"?>'.$cmd.']]>]]>';
	$logger->debug(__PACKAGE__ . "$sub_name Post conversion $cmd");
	return $cmd;
}

sub setSystem(){
	my($self)=@_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".setSystem");
        $logger->debug(__PACKAGE__ . ".setSystem: --> Entered Sub");
	my($cmd,$prompt, $prevPrompt, @results);
	
#	$logger->info(__PACKAGE__ . ".setSystem Waiting for session ID from remote");
# Session-id and initial HELLO from remote are already consumed by Base::Connect
#	my ($prematch,$match) = $self->{conn}->waitfor('/session-id.(\d+).*session-id.*hello/');
#	my ($prematch,$match) = $self->{conn}->waitfor('/session-id/');
#	$logger->info(__PACKAGE__ . ".setSystem Got Prematch: $prematch Match: $match");

$logger->debug("Cmd remove mode is : " . $self->{conn}->cmd_remove_mode);
$logger->debug("Prompt is : " . $self->{conn}->prompt);

	$logger->info(__PACKAGE__ . ".setSystem Sending NetConf HELLO:");
	$cmd = $self->_wrapXML('<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"><capabilities><capability>urn:ietf:params:netconf:base:1.0</capability></capabilities></hello>');

	$logger->info(__PACKAGE__ . ".setSystem $cmd");
	
	$self->{conn}->cmd($cmd);
	# NB - We don't expect any response since the remote device has already sent us its hello along with the first {PROMPT} in connect()

	# TODO - Wait for error response...

        $logger->debug(__PACKAGE__ . ".setSystem: <-- Leaving Sub [1]");
        return 1;
}

=head2 $obj->execRpcCmd()

Similar to execCmd, this is a higher level interface with the following differences:

a) The addition of not requiring the user to handle adding the RPC tags, or providing the message ID attribute.
b) This method decodes the XML response according to XML::DOM - and places the DOM in $self->{DOM} for the user's later use. It is assumed - since the user is testing an XML interface - that they are familiar with the XML Document Object Model. The perl specific documentation can be found in perldoc XML::DOM and friends.

=head3 ARGUMENTS: 

$obj->execRpcCmd($cmd); where $cmd is a properly formatted NetConf XML request, minus the <rpc> and <?xml> tags.

e.g.

 $netconfObj->execRpcCmd('
	<nc:get>
		<nc:filter nc:type="xpath" nc:select="/m2pa/link"></nc:filter>
	</nc:get>');

=head3 RETURNS:  

1 - execCmd() was ok, XML response decoded and stored in $self->{DOM}
&error() is called if execCmd fails - or we were unable to decode the response as valid XML.

=head3 AUTHOR: 

Malcolm Lashley <mlashley@sonusnet.com>

=cut

sub execRpcCmd{
	my ($self,$cmd)=@_;
	my $sub_name = ".execRpcCmd";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);
#	$logger->debug(__PACKAGE__ . "$sub_name Entered");
	unless (exists $self->{PARSER}) {
		$logger->info(__PACKAGE__ . "$sub_name Initializing XML-DOM Parser");
		$self->{PARSER} = new XML::DOM::Parser;
	}
	my $response = $self->execCmd($self->_wrapRPC($cmd));
	$response =~ s/\n//g; # Remove extra newlines in output - parser will complain if the *first* line isn't <?xml ...

	# The parser will 'die' on malformed XML - so let's do perl's equivalent of C++'s try/catch.
	eval {
		$self->{DOM} = $self->{PARSER}->parse($response);
	};
	# We still die anyway, but first log the issue - if the netconf implementation we are talking to is 
	# *so* badly broken as to return malformed XML - we are likely blocked from testing anyway...
	if ($@) {
		$logger->error(__PACKAGE__ . "$sub_name XML::DOM::parse failed, error was $@");
		$logger->error(__PACKAGE__ . "$sub_name XML::DOM::parse failed, input XML was $response");
		&error(__PACKAGE__ . "$sub_name XML::DOM::parse failed: $@\n$response");
	}
	return 1;
}

sub execCmd {  
  my ($self,$cmd)=@_;
  my $logger = Log::Log4perl->get_logger(__PACKAGE__ . ".execCmd");
  my(@cmdResults,$timestamp);
  $logger->info(__PACKAGE__ . ".execCmd  ISSUING CMD: $cmd WAITING FOR PROMPT: " . $self->{conn}->prompt);
  $timestamp = $self->getTime();
	$cmd = $self->_wrapXML($cmd);
  unless (@cmdResults = $self->{conn}->cmd(String =>$cmd)) {
    # Section for command execution error handling - CLI hangs, etc can be noted here.
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
    $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
    $logger->warn(__PACKAGE__ . ".execCmd  CMD RESULTS:");
    chomp(@cmdResults);
    map { $logger->warn(__PACKAGE__ . ".execCmd\t\t$_") } @cmdResults;
    $logger->warn(__PACKAGE__ . ".execCmd  *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*");
    &error(__PACKAGE__ . ".execCmd NetConf CLI CMD ERROR - EXITING");
  };
	my ($cmdResults,$prompt)= $self->{conn}->waitfor($self->{conn}->prompt);
	if($prompt =~ $self->{conn}->prompt) {
    $logger->warn(__PACKAGE__ . ".execCmd  CLI ERROR DETECTED, CMD ISSUED WAS:");
    $logger->warn(__PACKAGE__ . ".execCmd  $cmd");
		if($self->{CMDERRORFLAG}) { 
	    &error(__PACKAGE__ . ".execCmd NetConf CLI CMD ERROR - EXITING");
		}
	} elsif ( $cmdResults =~ /<rpc-error>/) {
    $logger->warn(__PACKAGE__ . ".execCmd  Got <rpc-error> response");
    $logger->warn(__PACKAGE__ . ".execCmd  $cmdResults");
		if($self->{CMDERRORFLAG}) { 
	    &error(__PACKAGE__ . ".execCmd NetConf CLI CMD ERROR <rpc-error> returned - EXITING");
		}
	}
	
  push(@{$self->{HISTORY}},"$timestamp :: $cmd");
	$logger->debug(__PACKAGE__ . ".execCmd Results: $cmdResults");

  return $cmdResults;
}

=head2 $obj->prettyPrintXML()

This helper routine formats up and XML::DOM document (such as the one stored in $self->{DOM} by execRpcCmd, but equally applicable to any DOM which has only tag elements and text elements) into a format suitable for display to the user.

=head3 ARGUMENTS:

$obj->prettyPrintXML($node); where $node is an XML::DOM::Node of type DOCUMENT, or ELEMENT.
If no arguments specified defaults to printing $self->{DOM}

e.g.

	my $string = $netconfObj->prettyPrintXML($netconfObj->{DOM});

is equivalent to:

	my $string = $netconfObj->prettyPrintXML();

=head3 RETURNS: 

A string containing the formatted response - in case of error, the string contains "Unexpected Node Type" an returns whatever *could* be parsed. (Note that this should not happen, since the XML::Parser has already validated the response.)

=head3 AUTHOR: 

Malcolm Lashley <mlashley@sonusnet.com>

=cut


sub prettyPrintXML{
	my ($self,$node,$indent) = @_;
	my $string;

	my $sub_name = ".prettyPrintXML";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);

	# If no $node is passed - default to $self->{DOM}
	unless (defined $node) { $node = $self->{DOM}; }

	if($node->getNodeType == TEXT_NODE) {
		return $node->getData;
	} elsif ($node->getNodeType == ELEMENT_NODE) {
		$string .= "\n$indent" . $node->getNodeName;
		$indent .= "  ";
		foreach my $child ($node->getChildNodes) {
			$string .=  ":" . $self->prettyPrintXML($child,$indent);
		}
		return $string;
	} elsif ($node->getNodeType == DOCUMENT_NODE) {
		return $self->prettyPrintXML($node->getFirstChild);
	} else {
		$logger->warn(__PACKAGE__ . "$sub_name : Unexpected Node Type, unable to print" . $node->getNodeType);
		return "Unexpected node type, unable to parse\nPartial parsing follows: $string";
	}
	die "Unreachable";
}

=head2 $obj->getTags()

Helper function to deal with common task of extracting one or more tags from a NetConf response.

=head3 ARGUMENTS:

$obj->getTags($tag,$node); where 

$tag is the name of the XML tag in question, 
$node is an optional argument specifying a node as per XML::DOM::Node, defaults to $self->{DOM} (as set by executeRpcCmd()) if unspecified.

e.g.

	netconfObj->getTags("dpcStatus") 
	
is equivalent to:

	$netconfObj->getTags("dpcStatus",netconfObj->{DOM})

It is expected the final argument is used to pass in subtrees from the XML formatted NetConf response in the case where the user wishes to parse only a subset of the response.

=head3 RETURNS: 

When called in a SCALAR context, the number of tags found - thus you can check if a tag is present with:

	if($netconfObj->getTags("mytag") { # tags found } else { # no tag found }

When called in an ARRAY context, returns an array of XML::DOM Elements for each tag found, or an empty array e.g.

	foreach $elem ($netconfObj->getTags("mytag")) { $elem->getFirstChild->toString }

=head3 AUTHOR: 

Malcolm Lashley <mlashley@sonusnet.com>

=cut

sub getTags{
	my ($self,$tag,$node) = @_;

	my $sub_name = ".getTags";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);

	# If no $node is passed - default to $self->{DOM}
	unless (defined $node) { $node = $self->{DOM}; }

	# Find nodes with the specified tag name
	my @elements = $node->getElementsByTagName($tag);
	return @elements;
}
=head2 $obj->tagHasValue()

Helper function to deal with common task of checking an tag in a NetConf response has a particular value.

=head3 ARGUMENTS:

$obj->tagHasValue($tag, $value, $node); where 

$tag is the name of the XML tag in question, 
$value is the expected value of its textual child. 
$node is an optional argument specifying a node as per XML::DOM::Node, defaults to $self->{DOM} (as set by executeRpcCmd()) if unspecified.

e.g.

	if($netconfObj->tagHasValue("dpcStatus","available") { ...  
	
is equivalent to:

	if($netconfObj->tagHasValue("dpcStatus","available",$netconfObj->{DOM}) { ...  

It is expected the final argument is used to pass in subtrees from the XML formatted NetConf response in the case where the user wishes to parse only a subset of the response.

=head3 RETURNS: 

>=1 - *All* matching tag(s) exist with the specified value, return value indicates the number of matches.
0 - Otherwise (At least one tag was found, but it does not have the specified value, or no tags found)

=head3 AUTHOR: 

Malcolm Lashley <mlashley@sonusnet.com>

=cut

sub tagHasValue {
	my ($self,$tag,$value,$node) = @_;

	my $sub_name = ".tagHasValue";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);

	# If no $node is passed - default to $self->{DOM}
	unless (defined $node) { $node = $self->{DOM}; }

	my $result = 0; # Assume failure until we find a match

	# Find nodes with the specified tag name
	for my $elem ($node->getElementsByTagName($tag)) {
		if($elem->getNodeType == ELEMENT_NODE) {
			if($elem->getFirstChild->getNodeType == TEXT_NODE) {
				my $actualValue = $elem->getFirstChild->toString;
				if($actualValue eq $value) {
					$logger->debug(__PACKAGE__ . "$sub_name Found tag '$tag' with value '$value'");
					$result++;
				} else {
					$logger->warn(__PACKAGE__ . "$sub_name Found tag '$tag' but actual value '$actualValue' not as expected '$value'");
					return 0;
				}
			} else {
				$logger->warn(__PACKAGE__ . "$sub_name Found tag '$tag', but child is not text type");
				return 0; # TODO - consider &error here? User should know the format they are expecting...
			}
		}
	}
	$logger->info(__PACKAGE__ . "$sub_name Found a total of $result tag(s) '$tag' with value '$value'");
	return $result;
}

=head2 $obj->closeConn();

Override closeConn() from SonusQA::Base as it makes retarded assumptions about the type of session based on the port number...

AUTHOR: 

Malcolm Lashley <mlashley@sonusnet.com>

=cut

sub closeConn {
	my ($self) = @_;
	my $sub_name = ".closeConn";
	my $logger = Log::Log4perl->get_logger(__PACKAGE__ . $sub_name);

	if ( $self->{COMM_TYPE} ne 'NETCONF') {
		# We'll likely be being called from destroy anyway - but let's flag the error...
		&error(__PACKAGE__ . "$sub_name from SonusQA::NetConf called but COMM_TYPE=$self->{COMM_TYPE}");
	}

	# TODO - Send the proper NetConf message to close the session (not really needed - EMS doesn't do it as far as I am aware, dropping the ssh session works just fine ;-)

	if ($self->{conn}) {
		$self->{conn}->close;
	}
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

=head1 TEST CODE 

The following code can be extracted and used to test the module - it is included here as additional examples of how (not) to use this module:

Please change the IP address before attempting to execute it!


 use SonusQA::NetConf;
 use Data::Dumper;
 use Log::Log4perl qw(get_logger :levels);
 use XML::DOM;
 Log::Log4perl->easy_init($DEBUG);
 
 my ($netconf_user, $netconf_password) = (admin,admin);
 
 my $logger = get_logger("NetConf Example");
 $logger->level($DEBUG);
 my $sub_name = ".netConfTest";
 
 
 # Create a new instance of the object and connect to the NetConf API
 
 my $netConfObj= new SonusQA::NetConf(  -obj_host => "10.33.3.120",
 -obj_user => $netconf_user,
 -obj_password => $netconf_password,
 -obj_port => 2022,
 -comm_type => NETCONF,
 -defaulttimeout => 10,
 -sessionlog => 1,
 );
 
 $netConfObj->{conn}->cmd_remove_mode(1);
 $logger->info("Cmd remove mode is : " . $netConfObj->{conn}->cmd_remove_mode);
 $logger->info("Prompt is : " . $netConfObj->{conn}->prompt);
 
 #my ($prematch,$match)= $netConfObj->{conn}->waitfor($netConfObj->{conn}->prompt);
 #$logger->debug("START: Prematch : $prematch Match: $match");
 
 $netConfObj->{CMDERRORFLAG} = 0; # We expect the following calls to fail - suppress calling &error
 
 my $cmd2 = $netConfObj->execCmd('<thisiswrong>');
 $logger->debug("Cmd2 returned: $cmd2");
 #my ($prematch,$match)= $netConfObj->{conn}->waitfor($netConfObj->{conn}->prompt);
 #$logger->debug("Prematch : $prematch Match: $match");
 
 
 my $cmd1 = $netConfObj->execCmd('<ncdfgsdfgsdfs>');
 $logger->debug("Cmd1 Returned: $cmd1");
 
 $netConfObj->{CMDERRORFLAG} = 1; # We expect the following calls to work - DO NOT suppress calling &error
 
 my $cmd3 = $netConfObj->execRpcCmd('
    <nc:get>
       <nc:filter nc:type="xpath" nc:select="/m2pa/link"></nc:filter>
    </nc:get> ');
 $logger->debug("Cmd3 Returned: $cmd3");
 
 $cmd3 =~ s/\n//g;
 
 foreach my $link ($netConfObj->{DOM}->getElementsByTagName('link')) {
 	$logger->debug("XML Stuff: " . Dumper($link->getElementsByTagName('name')->item(0)->getFirstChild->toString));
 }
 
 
 
 #      <nc:filter nc:type="xpath" nc:select="/m2pa/*"></nc:filter>
 
 # Example using XPATH with attribute filtering to select just certain elements
 #      <nc:filter nc:type="xpath" nc:select="/system/*[serverName=\'heckle.uk.sonusnet.com\']"></nc:filter>
 #      <nc:filter nc:type="xpath" nc:select="/m2pa/*[linkName=\`node1m2palink1\`]"></nc:filter>
 
 # Complex XPATH queries can be written (see RFC for the complete documentation on XPATH
 # <nc:filter nc:type="xpath" nc:select="/m2pa/*[linkName=\'node1m2palink1\'] | /system/serverStatus"></nc:filter>
 # Get msuTransmitted from both Current and historic interval stats, filtering on link node1m2palink1.
 # <nc:filter nc:type="xpath" nc:select="/m2pa/*[linkName=\'node1m2palink1\']/msuTransmitted"></nc:filter>
 
 my $cmd4 = $netConfObj->execRpcCmd('
    <nc:get>
  <nc:filter nc:type="xpath" nc:select="/m2pa/*[linkName=\'node1m2palink1\'] | /system/serverStatus"></nc:filter>
    </nc:get>');
 
 $logger->debug("XML Stuff2: " . $netConfObj->prettyPrintXML());
 
 # The following commands show how to check a tag has a specific value in the response.
 # Positive testcases, device config dependant. (Return 1 and 8 matches on my M2PA loopback setup)
 $logger->debug("Looking for element=status, value=inServiceNeitherEndBusy - Found " . $netConfObj->tagHasValue("status","inServiceNeitherEndBusy") . " matches");
 $logger->debug("Looking for element=intervalValid, value=true - Found " . $netConfObj->tagHasValue("intervalValid","true") . " matches");
 
 $logger->debug("Negative test cases - zero values expected.");
 $logger->debug("Looking for element=status, value=sticks - Found " . $netConfObj->tagHasValue("status","sticks") . " matches");
 $logger->debug("Looking for element=crap, value=sticks - Found " . $netConfObj->tagHasValue("crap","sticks") . " matches");
 
 my $count = $netConfObj->getTags("status");
 $logger->debug("getTags(SCALAR) returned: $count");
 my @ary = $netConfObj->getTags("status");
 
 map { $logger->debug("getTags(ARRAY) returned: " . $_); } @ary;
 
 
 # Example using NetConf action commands to provoke a request/action (in this case SGX4000 LSWU)
 
 $netConfObj->execRpcCmd('
    <nca:action xmlns:nca="http://tail-f.com/ns/netconf/actions/1.0">
       <nca:data>
          <system xmlns="http://sonusnet.com/ns/mibs/SONUS-SYSTEM-MIB/1.0">
             <admin>
                <name>SGX_heckle_jeckle</name>
                <startSoftwareUpgrade>
                   <package>sgx4000-V07.03.09-A009.x86_64.tar.gz</package>
                   <upgradeMode>normal</upgradeMode>
                   <rpmName>none</rpmName>
                   <versionCheck>perform</versionCheck>
                </startSoftwareUpgrade>
             </admin>
          </system>
       </nca:data>
    </nca:action> ');
 $logger->debug("LSWU Action Response: " . $netConfObj->prettyPrintXML());
 
 if($netConfObj->tagHasValue("result","failure")) {
 	$logger->info("LSWU Failed to start, reason : " . 
 			$netConfObj->{DOM}->getElementsByTagName('reason')->item(0)->getFirstChild->toString
 	);
 }
 
 # Example using all functions - check m2pa links are all inservice.
 
 use Time::HiRes qw( usleep );
 
 my $res = 2;
 
 while($res == 2) {
 
 my $cmd6 = $netConfObj->execRpcCmd('
    <nc:get>
  <nc:filter nc:type="xpath" nc:select="/m2pa/m2paLinkStatus"></nc:filter>
    </nc:get>');
 if($res = $netConfObj->tagHasValue("status","inServiceNeitherEndBusy")) {
 	$logger->info("All $res Links inService");
 } else {
 	$logger->info("At least one link not inService: " . $netConfObj->prettyPrintXML());
 }
 
 usleep(3000000);
 
 }
 
=head3 Scratch Area 

Scratch aread for SGX4000 (and possibly common platform, but untested there)  NetConf actions you may wish to use - included to give new users some idea of the protocol, but not intended to replace proper training on the subject ;-)
 
 Example Command to execute a CE switchover.
 
    <nca:action xmlns:nca="http://tail-f.com/ns/netconf/actions/1.0">
       <nca:data>
          <system xmlns="http://sonusnet.com/ns/mibs/SONUS-SYSTEM-MIB/1.0">
             <admin>
                <name>SGX_chip_dale</name>
                <switchover>
                   <type>normal</type>
                </switchover>
             </admin>
          </system>
       </nca:data>
    </nca:action>
 
 # Softreset
 
   <nca:action xmlns:nca="http://tail-f.com/ns/netconf/actions/1.0">
       <nca:data>
          <system xmlns="http://sonusnet.com/ns/mibs/SONUS-SYSTEM-MIB/1.0">
             <admin>
                <name>esteban_zia</name>
                <softReset></softReset>
             </admin>
          </system>
       </nca:data>
    </nca:action>
 
 #
 # Software upgrade
 #
 
    <nca:action xmlns:nca="http://tail-f.com/ns/netconf/actions/1.0">
       <nca:data>
          <system xmlns="http://sonusnet.com/ns/mibs/SONUS-SYSTEM-MIB/1.0">
             <admin>
                <name>SGX_chip_dale</name>
                <startSoftwareUpgrade>
                   <package>sgx4000-V07.03.01-A009.x86_64.tar.gz</package>
                   <upgradeMode>normal</upgradeMode>
                   <rpmName>none</rpmName>
                   <versionCheck>perform</versionCheck>
                </startSoftwareUpgrade>
             </admin>
          </system>
       </nca:data>
    </nca:action>
 
 #
 # Revert LSWU
 #
 
    <nca:action xmlns:nca="http://tail-f.com/ns/netconf/actions/1.0">
       <nca:data>
          <system xmlns="http://sonusnet.com/ns/mibs/SONUS-SYSTEM-MIB/1.0">
             <admin>
                <name>SGX_chip_dale</name>
                <revertSoftwareUpgrade>
                   <revertMode>normal</revertMode>
                </revertSoftwareUpgrade>
             </admin>
          </system>
       </nca:data>
    </nca:action>
 
=cut
 
1;
 
 
