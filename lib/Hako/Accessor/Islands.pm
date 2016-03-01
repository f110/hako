package Hako::Accessor::Islands;
use strict;
use warnings;
use Hako::DB;
use Data::Dumper;

sub new {
    bless {
        cache => {},
    }, shift
}

sub get {
    my ($self, $id) = @_;

    $self->{cache}->{$id} ||= $self->_get_island($id);
}

sub ranking {
    my $self = shift;

    my $islands = Hako::DB->get_islands;
    [map {$_->{id}} @$islands];
}

sub is_exist {
    my ($self, $name) = @_;

    Hako::DB->is_exist_island($name);
}

sub _get_island {
    my ($self, $id) = @_;

    my $island = Hako::DB->get_island($id);

    Hako::Model::Island->inflate($island);
}

1;
