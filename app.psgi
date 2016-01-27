use Plack::Builder;
use File::Spec;
use File::Basename;
use Hako::Config;
use Hako::Admin::App;

require 'hako-main.cgi';

my $main_app = MainApp::to_app();
my $admin_app = Hako::Admin::App->new;

builder {
    #enable 'Plack::Middleware::Static',
        #path => sub {print shift; 0},
        #root => File::Spec->catdir(dirname(__FILE__));
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/img/)},
        root => File::Spec->catdir(dirname(__FILE__));
    enable 'Plack::Middleware::Static',
        path => qr{(?:favicon.ico)},
        root => File::Spec->catdir(dirname(__FILE__));
    mount "/admin" => $admin_app->psgi;
    mount "/" => $main_app;
};
