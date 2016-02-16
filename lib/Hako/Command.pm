package Hako::Command;
use strict;
use warnings;
use Hako::Constants;
use Data::Dumper;
use Devel::Peek;

sub id_to_name {
    my ($class, $id) = @_;

    my $com_name = __find_command_name($id);
    $com_name =~ s/^command_(.+)$/command_name_$1/g;

    return ${Hako::Constants->config()}{$com_name};
}

sub id_to_cost {
    my ($class, $id) = @_;

    (my $com_name = __find_command_name($id)) =~ s/^command_(.+)$/command_cost_$1/;

    return ${Hako::Constants->config()}{$com_name};
}

sub __find_command_name {
    my ($id) = @_;

    my $config = Hako::Constants::config();
    my $com_name;
    for my $k (keys(%$config)) {
        next unless $k =~ /^command/;
        my $v = $config->{$k};
        if ($v eq $id) {
            $com_name = $k;
            last;
        }
    }

    return $com_name;
}

1;
