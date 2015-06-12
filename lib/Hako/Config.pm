package Hako::Config;
use strict;
use warnings;
use File::Spec;
use File::Basename;
use YAML;

sub import {
    my $config = YAML::LoadFile(File::Spec->catfile(dirname(__FILE__), "../../config.yaml"));

    for my $key (keys %{$config}) {
        no strict 'refs';
        no warnings 'redefine';
        my $conf_name = uc($key);
        *{__PACKAGE__."::".$conf_name} = sub() { $config->{$key} };
    }
}

sub DIR_MODE { return 0755; }

1;
