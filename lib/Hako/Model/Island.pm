package Hako::Model::Island;
use strict;
use warnings;

sub new {
    my ($class, $argv) = @_;

    return bless $argv, $class;
}

1;
