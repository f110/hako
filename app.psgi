use Plack::App::CGIBin;
use Plack::Builder;
use File::Spec;
use File::Basename;

require 'hako-main.cgi';

my $app = to_psgi();
builder {
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/img/)},
        root => File::Spec->catdir(dirname(__FILE__));
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/favicon.ico/)},
        root => File::Spec->catdir(dirname(__FILE__));
    mount "/" => $app;
};
