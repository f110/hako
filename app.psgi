use Plack::Builder;
use File::Spec;
use File::Basename;

require 'hako-main.cgi';
require 'hako-mente.cgi';

my $main_app = Main::to_app();
my $mente_app = Mente::to_app();

builder {
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/img/)},
        root => File::Spec->catdir(dirname(__FILE__));
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/favicon.ico/)},
        root => File::Spec->catdir(dirname(__FILE__));
    mount "/mente" => $mente_app;
    mount "/" => $main_app;
};
