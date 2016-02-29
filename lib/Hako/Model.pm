package Hako::Model;
use strict;
use warnings;

sub import {
    shift;
    my %argv = @_;
    my $caller = caller(0);
    my %a = (
        ro      => \&__make_ro_accessor,
        rw      => \&__make_rw_accessor,
        rw_lazy => \&__make_lazy_rw_accessor,
        ro_lazy => \&__make_lazy_ro_accessor,
    );

    for my $k (keys(%a)) {
        $a{$k}->($caller, $argv{$k}) if (defined $argv{$k});
    }

    __changed_accessor($caller);

    if (!exists($argv{disable_new})) {
        __make_new($caller);
    }
}

sub __setter {
    my ($self, $key, $value) = @_;

    return $value if exists($self->{$key}) && $self->{$key} eq $value;
    $self->{$key} = $value;
    $self->{changed} = 1;
    $self->{changed_column} ||= [];
    push(@{$self->{changed_column}}, $key);
}

sub __changed_accessor {
    my $caller = shift;

    {
        no strict "refs";
        *{$caller . "::is_changed"} = sub { exists(shift->{changed}) ? 1 : 0 };
        *{$caller . "::changed_columns"} = sub {
            my $self = shift;
            $self->is_changed ? $self->{changed_column} : [];
        };
    }
}

sub __make_ro_accessor {
    my ($caller, $attrs) = @_;

    for my $a (@$attrs) {
        {
            no strict "refs";
            *{$caller . "::" . $a} = sub { shift->{$a} };
        }
    }
}

sub __make_rw_accessor {
    my ($caller, $attrs) = @_;

    for my $a (@$attrs) {
        {
            no strict "refs";
            *{$caller . "::" . $a} = sub {
                my $self = shift;

                if (@_ == 0) {
                    return $self->{$a};
                } elsif (@_ == 1) {
                    __setter($self, $a, $_[0]);
                }
            };
        }
    }
}

sub __make_lazy_rw_accessor {
    my ($caller, $attrs) = @_;

    for my $a (@$attrs) {
        {
            no strict "refs";
            my $builder = "_build_$a";
            *{$caller . "::" . $a} = sub {
                my $self = shift;

                if (@_ == 0 && !exists($self->{$a})) {
                    $self->{$a} = $self->$builder;
                } elsif (@_ == 0) {
                    $self->{$a};
                } elsif (@_ == 1) {
                    __setter($self, $a, $_[0]);
                }
            };
        }
    }
}

sub __make_lazy_ro_accessor {
    my ($caller, $attrs) = @_;

    for my $a (@$attrs) {
        {
            no strict "refs";
            my $builder = "_build_$a";
            *{$caller . "::" . $a} = sub {
                my $self = shift;

                if (exists($self->{$a})) {
                    $self->{$a};
                } else {
                    $self->{$a} = $self->$builder;
                }
            };
        }
    }
}

sub __make_new {
    my $caller = shift;

    {
        no strict "refs";
        *{$caller . "::new"} = sub {
            my ($klass, %argv) = @_;

            bless \%argv, $klass;
        };
    }
}

1;
