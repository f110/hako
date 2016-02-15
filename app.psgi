use Plack::Builder;
use Plack::Session::Store::DBI;
use File::Spec;
use File::Basename;
use Hako::Config;
use Hako::Admin::App;
use Hako::DB;

require 'hako-main.cgi';

my $main_app = MainApp->new;
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
    enable 'Plack::Middleware::Session',
        store => Plack::Session::Store::DBI->new(
            dbh => Hako::DB->connect,
        );
    mount "/admin" => $admin_app->psgi;
    mount "/" => $main_app->psgi;
};
