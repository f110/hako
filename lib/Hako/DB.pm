package Hako::DB;
use strict;
use warnings;
use DBI;
use Encode qw();
use Data::Dumper;

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

    return $class->connect->do("INSERT INTO histories (turn, message, created_at) VALUES (?, ?, NOW())", {}, $turn, Encode::decode("EUC-JP", $msg));
}

sub get_history {
    my ($class) = @_;

    return $class->connect->selectall_arrayref("SELECT * FROM histories ORDER BY id DESC LIMIT @{[Hako::Config::HISTORY_MAX]}", {Slice => +{}});
}

sub insert_log {
    my $class = shift;

    return $class->_insert_log_common(1, @_);
}

sub get_log {
    my ($class, $island_id, $current_turn) = @_;

    return $class->connect->selectall_arrayref("SELECT * FROM logs WHERE island_id = ? AND turn >= ? ORDER BY id DESC", {Slice => +{}}, $island_id, $current_turn - Hako::Config::LOG_MAX);
}

sub get_common_log {
    my ($class, $current_turn) = @_;

    return $class->connect->selectall_arrayref("SELECT * FROM logs WHERE log_type <> 3 AND turn >= ? ORDER BY id DESC", {Slice => +{}}, $current_turn - Hako::Config::TOP_LOG_TURN);
}

sub insert_late_log {
    my $class = shift;

    return $class->_insert_log_common(2, @_);
}

sub insert_secret_log {
    my $class = shift;

    return $class->_insert_log_common(3, @_);
}

sub save_island {
    my ($class, $island, $sort) = @_;

    my $db = $class->connect;
    my $value = $db->selectrow_arrayref("SELECT 1 FROM islands WHERE id = \"@{[$island->{id}]}\"");
    if ($value) {
        return $db->do("UPDATE islands SET name = ?, score = ?, prize = ?, absent = ?, cmt = ?, password = ?, money = ?, food = ?, population = ?, area = ?, farm = ?, factory = ?, mountain = ?, map = ?, sort = ?, updated_at = NOW() WHERE id = ?", {}, $island->{name}, $island->{score}, $island->{prize}, $island->{absent}, Encode::decode("EUC-JP", $island->{comment}), $island->{password}, $island->{money}, $island->{food}, $island->{pop}, $island->{area}, $island->{farm}, $island->{factory}, $island->{mountain}, $island->{map}, $sort, $island->{id});
    } else {
        return $db->do("INSERT INTO islands (id, name, score, prize, absent, cmt, password, money, food, population, area, farm, factory, mountain, map, sort, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())", {}, $island->{id}, $island->{name}, $island->{score}, $island->{prize}, $island->{absent}, Encode::decode("EUC-JP", $island->{comment}), $island->{password}, $island->{money}, $island->{food}, $island->{pop}, $island->{area}, $island->{farm}, $island->{factory}, $island->{mountain}, $island->{map}, $sort);
    }
}

sub get_islands {
    my ($class) = @_;

    $class->connect->selectall_arrayref("SELECT * FROM islands ORDER BY sort ASC", {Slice => +{}});
}

sub get_island {
    my ($class, $island_id) = @_;
    my $island = $class->connect->selectrow_arrayref("SELECT * FROM islands WHERE id = ?", {}, $island_id);

    if ($island) {
        return $island->[0];
    }

    return undef;
}

sub delete_island {
    my ($class, $island_id) = @_;

    return $class->connect->do("DELETE FROM islands WHERE id = ?", {}, $island_id);
}

sub save_command {
    my ($class, $island_id, $commands) = @_;

    my $db = $class->connect;
    $db->do("DELETE FROM island_commands WHERE island_id = ?", {}, $island_id);
    for my $command (@$commands) {
        $db->do("INSERT INTO island_commands (island_id, kind, target, x, y, arg, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())", {}, $island_id, $command->{kind}, $command->{target}, $command->{x}, $command->{y}, $command->{arg});
    }
}

sub get_commands {
    my ($class, $island_id) = @_;

    return $class->connect->selectall_arrayref("SELECT * FROM island_commands WHERE island_id = ? ORDER BY id ASC", {Slice => +{}}, $island_id);
}

sub save_bbs {
    my ($class, $island_id, $bbs) = @_;

    my $db = $class->connect;
    $db->do("DELETE FROM island_bbs WHERE island_id = ?", {}, $island_id);

    for my $v (@$bbs) {
        $db->do("INSERT INTO island_bbs (island_id, value) values (?, ?)", {}, $island_id, Encode::decode("EUC-JP", $v));
    }
}

sub get_bbs {
    my ($class, $island_id) = @_;

    my $bbs = $class->connect->selectcol_arrayref("SELECT value FROM island_bbs WHERE island_id = ? ORDER BY id", {}, $island_id);
    return [map {Encode::encode("EUC-JP", Encode::decode("UTF-8", $_))} @$bbs];
}

sub _insert_log_common {
    my ($class, $type, $turn, $island_id, $target_id, $message) = @_;

    return $class->connect->do("INSERT INTO logs (log_type, turn, island_id, target_id, message, created_at) VALUES (?, ?, ?, ?, ?, NOW())", {}, $type, $turn, $island_id, $target_id, Encode::decode("EUC-JP", $message));
}

1;
