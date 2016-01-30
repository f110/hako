package Hako::Model::Island;
use strict;
use warnings;

sub new {
    my ($class, $argv) = @_;

    return bless $argv, $class;
}

sub inflate {
    my ($class, $argv) = @_;

    $argv->{comment} = $argv->{cmt};
    $argv->{pop} = $argv->{population};

    return $class->new($argv);
}

1;
