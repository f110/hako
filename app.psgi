use Plack::App::CGIBin;
use Plack::Builder;
use File::Spec;
use File::Basename;

my $app = Plack::App::CGIBin->new(
    root => File::Spec->catdir(dirname(__FILE__)),
    exec_cb => sub { 1 },
)->to_app;
builder {
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/img/)},
        root => File::Spec->catdir(dirname(__FILE__));
    mount "/" => $app;
};

