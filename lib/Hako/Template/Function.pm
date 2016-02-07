package Hako::Template::Function;
use strict;
use warnings;
use Hako::Config;

sub wrap_name {
    my ($class, $value) = @_;

    return $class->_wrap_tag("NAME", $value);
}

sub wrap_command_name {
    my ($class, $value) = @_;

    return $class->_wrap_tag("COM_NAME", $value);
}

sub wrap_disaster {
    my ($class, $value) = @_;

    return $class->_wrap_tag("DISASTER", $value);
}

sub wrap_number {
    my ($class, $value) = @_;

    return $class->_wrap_tag("NUMBER", $value);
}

sub wrap_th {
    my ($class, $value) = @_;

    return $class->_wrap_tag("TH", $value);
}

sub wrap_local_bbs_ss {
    my ($class, $value) = @_;

    return $class->_wrap_tag("LOCAL_BBS_SS", $value);
}

sub wrap_local_bbs_ow {
    my ($class, $value) = @_;

    return $class->_wrap_tag("LOCAL_BBS_OW", $value);
}

sub _wrap_tag {
    my ($class, $tag, $value) = @_;

    my $start_tag = "TAG_" . $tag . "_";
    my $end_tag = "_TAG_" . $tag;
    return Hako::Config->$start_tag() . $value . Hako::Config->$end_tag();
}

1;
