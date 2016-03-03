package Hako::Context::Game;
use strict;
use warnings;
use Hako::DB;
use Data::Dumper;

sub new { bless {}, shift; }

sub turn      { shift->_get_global_value("turn") }
sub last_time { shift->_get_global_value("last_time") }
sub number    { shift->_get_global_value("number") }
sub next_id   { shift->_get_global_value("next_id") }

sub set_last_time { shift->_set_global_value("last_time", shift) }
sub set_number    { shift->_set_global_value("number", shift) }
sub set_next_id   { shift->_set_global_value("next_id", shift) }

sub forward_turn {
    my $self = shift;

    die "already forwarded turn" if ($self->{already_forwarded});

    $self->{already_forwarded} = 1;
    my $turn = $self->_get_global_value("turn");
    $self->{turn} = $turn + 1;

    return $self->{turn};
}

sub save {
    my $self = shift;

    my @target_keys;
    for my $k (keys %$self) {
        next unless ($k =~ /^flag_/);
        push(@target_keys, $self->{$k});
    }

    for my $k (@target_keys) {
        Hako::DB->set_global_value($k, $self->{$k});
    }
}

sub _get_global_value {
    my ($self, $key) = @_;

    $self->{$key} ||= Hako::DB->get_global_value($key);
}

sub _set_global_value {
    my ($self, $key, $value) = @_;

    return $value if $self->{$key} eq $value;
    $self->{$key} = $value;
    $self->{"flag_".$key} = $key;

    return $self->{$key};
}

1;
