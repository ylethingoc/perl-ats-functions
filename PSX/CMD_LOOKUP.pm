package SonusQA::PSX::CMD_LOOKUP;

use Data::Dumper;

=head1 NAME 

SonusQA::PSX::PSX_LOOKUP

=head1 AUTHOR

sonus-ats-dev@sonusnet.com

=head1 DESCRIPTION

   This module provides the hash which is used to lookup the CLOUD PSX commands.

=head2 Variable

  %CMD_LIST - The hash contains the keywords of commands which has to be run on MASTER and SLAVE.

=cut 

our %CMD_LIST = ( 
'MASTER' => [
               'vbrrsprsr',
               'vbrrsldr',
               'vbrrptr',
               'vbrkpildr',
               'vbrcapldr',
               'lcrrsprsr',
               'lcrrsldr',
               'lcrrptr',
               'lcrkpildr',
               'lcrcapldr',
               'lcrrsdel',
               'ssoftswitch'
            ],
'SLAVE' =>  [
               'ssoftswitch'
            ]
);




