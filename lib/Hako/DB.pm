package Hako::DB;
use strict;
use warnings;
use DBI;

sub connect {
    return DBI->connect("DBI:mysql:database=hako;host=127.0.0.1;port=3306", "root", "");
}

sub set_global_value {
    my ($class, $key, $value) = @_;

    return $class->connect->do("INSERT INTO hakojima (id, value) VALUES (\"@{[$key]}\", \"@{[$value]}\") ON DUPLICATE KEY UPDATE value = \"@{[$value]}\"");
}

sub get_global_value {
    my ($class, $key) = @_;

    return $class->connect->selectrow_arrayref("SELECT value FROM hakojima WHERE id = \"@{[$key]}\"")->[0];
}

sub insert_history {
    my ($class, $turn, $msg) = @_;

    return $class->connect->do("INSERT INTO histories (turn, message) VALUES (\"@{[$turn]}\", \"@{[$msg]}\")");
}

1;
