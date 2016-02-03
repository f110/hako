package Hako::Model::Island;
use strict;
use warnings;
use Hako::DB;
use Encode qw();

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

sub get {
    my ($class, $island_id) = @_;

    my $island = $class->inflate(Hako::DB->get_island($island_id));
}

1;
