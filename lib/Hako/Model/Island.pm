package Hako::Model::Island;
use strict;
use warnings;
use Data::Dumper;
use Hako::Config;
use Hako::Constants;

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

sub map {
    my $self = shift;

    my $land = $self->land;
    my $land_value = $self->land_value;
    my $land_str = "";
    for (my $y = 0; $y < Hako::Config::ISLAND_SIZE; $y++) {
        for (my $x = 0; $x < Hako::Config::ISLAND_SIZE; $x++) {
            $land_str .= sprintf("%x%02x", $land->[$x][$y], $land_value->[$x][$y]);
        }
        $land_str .= "\n";
    }

    return $land_str;
}

sub update_stat {
    my $self = shift;

    my ($pop, $area, $farm, $factory, $mountain);

    for (my $y = 0; $y < Hako::Config::ISLAND_SIZE; $y++) {
        for (my $x = 0; $x < Hako::Config::ISLAND_SIZE; $x++) {
            my $kind = $self->land->[$x][$y];
            my $value = $self->land_value->[$x][$y];
            if (($kind != Hako::Constants::LAND_SEA) && ($kind != Hako::Constants::LAND_SEA_BASE) && ($kind != Hako::Constants::LAND_OIL)) {
                $area++;
                if ($kind == Hako::Constants::LAND_TOWN) {
                    # 町
                    $pop += $value;
                } elsif ($kind == Hako::Constants::LAND_FARM) {
                    # 農場
                    $farm += $value;
                } elsif ($kind == Hako::Constants::LAND_FACTORY) {
                    # 工場
                    $factory += $value;
                } elsif ($kind == Hako::Constants::LAND_MOUNTAIN) {
                    # 山
                    $mountain += $value;
                }
            }
        }
    }

    $self->{pop}      = $pop;
    $self->{area}     = $area;
    $self->{farm}     = $farm ? $farm : 0;
    $self->{factory}  = $factory ? $factory : 0;
    $self->{mountain} = $mountain ? $mountain : 0;
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
