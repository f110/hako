package Hako::Constants;
use strict;
use warnings;
use File::Spec;
use File::Basename;
use YAML;

my $config;

sub import {
    $config = YAML::LoadFile(File::Spec->catfile(dirname(__FILE__), "../../constants.yaml"));

    for my $key (keys %{$config}) {
        no strict 'refs';
        no warnings 'redefine';
        my $conf_name = uc($key);
        *{__PACKAGE__."::".$conf_name} = sub() { $config->{$key} };
    }
}

sub DIR_MODE { return 0755; }

sub config { $config; }

1;
