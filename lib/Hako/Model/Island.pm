package Hako::Model::Island;
use strict;
use warnings;
use Data::Dumper;
use Hako::Model (
    ro          => [qw/id/],
    rw          => [qw/name password score money food population area farm factory mountain land land_value/],
    rw_lazy     => [qw/command lbbs/],
    disable_new => 1,
);

sub new {
    my ($class, $argv) = @_;

    my (@land, @land_value);
    if (exists $argv->{map}) {
        my @land_str = split(/\n/, $argv->{map});
        for (my $y = 0; $y < Hako::Config::ISLAND_SIZE; $y++) {
            my $line = $land_str[$y];
            for (my $x = 0; $x < Hako::Config::ISLAND_SIZE; $x++) {
                $line =~ s/^(.)(..)//;
                $land[$x][$y] = hex($1);
                $land_value[$x][$y] = hex($2);
            }
        }
        $argv->{land} = \@land;
        $argv->{land_value} = \@land_value;
    }

    return bless $argv, $class;
}

sub inflate {
    my ($class, $argv) = @_;

    $argv->{comment} = $argv->{cmt};
    $argv->{pop} = $argv->{population};

    return $class->new($argv);
}

sub delete {
    my $self = shift;

    Hako::DB->delete_island($self->id);
}

sub _build_command {
    my $self = shift;

    Hako::DB->get_commands($self->{id});
}

sub _build_lbbs {
    my $self = shift;

    Hako::DB->get_bbs($self->{id});
}

1;
