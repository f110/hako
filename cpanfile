requires 'Plack';
requires 'YAML';

# Plack で CGI アプリを動かすために必要なやつ
requires 'Plack::App::CGIBin';
requires 'CGI::Emulate::PSGI';
requires 'CGI::Compile';
