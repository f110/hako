package Hako::DB;
use strict;
use warnings;
use DBI;

sub connect {
    return DBI->connect("DBI:mysql:database=hako;host=127.0.0.1;port=3306", "root", "");
}

sub force_reset {
    my ($class) = @_;

    my $db = $class->connect;
    for my $table (qw(hakojima islands island_commands island_bbs histories)) {
        $db->do("TRUNCATE @{[$table]}");
    }
}

sub set_global_value {
    my ($class, $key, $value) = @_;

    return $class->connect->do("INSERT INTO hakojima (id, value) VALUES (\"@{[$key]}\", \"@{[$value]}\") ON DUPLICATE KEY UPDATE value = \"@{[$value]}\"");
}

sub get_global_value {
    my ($class, $key) = @_;

    my $value = $class->connect->selectrow_arrayref("SELECT value FROM hakojima WHERE id = \"@{[$key]}\"");
    if ($value) {
        return $value->[0];
    } else {
        return undef;
    }
}

sub insert_history {
    my ($class, $turn, $msg) = @_;

    return $class->connect->do("INSERT INTO histories (turn, message) VALUES (?, ?)", {}, $turn, $msg);
}

sub save_island {
    my ($class, $island) = @_;

    return $class->connect->do("INSERT INTO islands (name, score, prize, absent, cmt, password, money, food, population, area, farm, factory, mountain, map, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())", {}, $island->{name}, $island->{score}, $island->{prize}, $island->{absent}, $island->{comment}, $island->{password}, $island->{money}, $island->{food}, $island->{pop}, $island->{area}, $island->{farm}, $island->{factory}, $island->{mountain}, $island->{map});
}

sub save_command {
    my ($class, $island_id, $commands) = @_;

    my $db = $class->connect;
    for my $command (@$commands) {
        $db->do("INSERT INTO island_commands (island_id, kind, target, x, y, arg, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())", {}, $island_id, $command->{kind}, $command->{target}, $command->{x}, $command->{y}, $command->{arg});
    }
}

1;
