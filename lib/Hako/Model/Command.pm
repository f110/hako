package Hako::Model::Command;
use strict;
use warnings;
use utf8;
use Data::Dumper;
use Hako::Config;
use Hako::Constants;
use Text::Xslate qw(mark_raw);
use Hako::Model (
    ro => [qw(kind target x y arg)],
);

sub point {
    my $self = shift;
    Hako::Config::TAG_NAME_ . "(@{[$self->x]},@{[$self->y]})" . Hako::Config::_TAG_NAME;
}

sub name {
    my $self = shift;

    Hako::Config::TAG_COM_NAME_ . Hako::Model::Command->_id_to_name($self->kind) . Hako::Config::_TAG_COM_NAME;
}

sub cost {
    my $self = shift;

    my $value = $self->arg * Hako::Model::Command->_id_to_cost($self->kind);
    if ($value == 0) {
        $value = Hako::Model::Command->id_to_cost($self->kind);
    }
    if ($value < 0) {
        $value = -$value;
        $value = "$value" . Hako::Config::UNIT_FOOD;
    } else {
        $value = "$value" . Hako::Config::UNIT_MONEY;
    }

    Hako::Template::Function->wrap_name($value);
}

sub to_human {
    my $self = shift;

    my $buf;
    if (
        $self->kind == Hako::Constants::COMMAND_DO_NOTHING
        || $self->kind == Hako::Constants::COMMAND_GIVE_UP) {
        $buf .= "@{[$self->name]}";
    } elsif (
        $self->kind == Hako::Constants::COMMAND_MISSILE_NM
        || $self->kind == Hako::Constants::COMMAND_MISSILE_PP
        || $self->kind == Hako::Constants::COMMAND_MISSILE_ST
        || $self->kind == Hako::Constants::COMMAND_MISSILE_LD) {
        # ミサイル系
        my $n = $self->arg == 0 ? '無制限' : "@{[$self->arg]}発";
        $buf .= "@{[$self->target]}@{[$self->point]}へ@{[$self->name]}(@{[Hako::Config::TAG_NAME_]}@{[$n]}@{[Hako::Config::_TAG_NAME]})";
    } elsif ($self->kind == Hako::Constants::COMMAND_SEND_MONSTER) {
        # 怪獣派遣
        $buf .= "@{[$self->target]}へ@{[$self->name]}";
    } elsif ($self->kind == Hako::Constants::COMMAND_SELL) {
        # 食料輸出
        $buf .= "@{[$self->name]}@{[$self->cost]}";
    } elsif ($self->kind == Hako::Constants::COMMAND_PROPAGANDA) {
        # 誘致活動
        $buf .= "@{[$self->name]}";
    } elsif (($self->kind == Hako::Constants::COMMAND_MONEY) || ($self->kind == Hako::Constants::COMMAND_MONEY)) {
        # 援助
        $buf .= "@{[$self->target]}へ@{[$self->name]}@{[$self->cost]}";
    } elsif ($self->kind == Hako::Constants::COMMAND_DESTROY) {
        # 掘削
        if ($self->arg != 0) {
            $buf .= "@{[$self->point]}で@{[$self->name]}(予算@{[$self->cost]})";
        } else {
            $buf .= "@{[$self->point]}で@{[$self->name]}";
        }
    } elsif (
        $self->kind == Hako::Constants::COMMAND_FARM
        || $self->kind == Hako::Constants::COMMAND_FACTORY
        || $self->kind == Hako::Constants::COMMAND_MOUNTAIN) {
        # 回数付き
        if ($self->arg == 0) {
            $buf .= "@{[$self->point]}で@{[$self->name]}";
        } else {
            $buf .= "@{[$self->point]}で@{[$self->name]}(@{[$self->arg]}回)";
        }
    } else {
        # 座標付き
        $buf .= "@{[$self->point]}で@{[$self->name]}";
    }

    return mark_raw($buf);
}

sub _id_to_name {
    my ($class, $id) = @_;

    my $com_name = __find_command_name($id);
    $com_name =~ s/^command_(.+)$/command_name_$1/g;

    return ${Hako::Constants->config()}{$com_name};
}

sub _id_to_cost {
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
