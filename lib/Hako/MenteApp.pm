package Hako::MenteApp;
use strict;
use warnings;
use Plack::Request;
use Plack::Response;
use Time::Local;
use List::MoreUtils qw();
use Hako::Config;
use Hako::DB;

#----------------------------------------------------------------------
# Ȣ����� ver2.30
# ���ƥʥ󥹥ġ���(ver1.01)
# ���Ѿ�������ˡ���ϡ�hako-readme.txt�ե�����򻲾�
#
# Ȣ�����Υڡ���: http://www.bekkoame.ne.jp/~tokuoka/hakoniwa.html
#----------------------------------------------------------------------

sub new {
    my ($class) = @_;

    return bless {
        main_mode => "",
        input_pass => undef,
        delete_id => undef,
        current_id => undef,
        ct_year => undef,
        ct_mon => undef,
        ct_date => undef,
        ct_hour => undef,
        ct_min => undef,
        ct_sec => undef,
        out_buffer => "",
        cookie_buffer => "",
    }, $class;
}

sub initialize {
    my ($self) = @_;

    $self->{main_mode} = "";
    $self->{input_pass} = undef;
    $self->{delete_id} = undef;
    $self->{current_id} = undef;
    $self->{ct_year} = undef;
    $self->{ct_mon} = undef;
    $self->{ct_date} = undef;
    $self->{ct_hour} = undef;
    $self->{ct_min} = undef;
    $self->{ct_sec} = undef;
    $self->{out_buffer} = "";
    $self->{cookie_buffer} = "";
    $self->{out_buffer} = "";
    $self->{cookie_buffer} = "";
}

sub out {
    my ($self, $buf) = @_;

    $self->{out_buffer} .= $buf;
}

sub cgi_input {
    my ($self, $request) = @_;

    my $params = $request->parameters;
    if (List::MoreUtils::any {$_ =~ /DELETE([0-9]*)/} $params->keys) {
        $self->{main_mode} = 'delete';
        $self->{delete_id} = $1;
    } elsif(List::MoreUtils::any {$_ =~ /CURRENT([0-9]*)/} $params->keys) {
        $self->{main_mode} = 'current';
        $self->{current_id} = $1;
    } elsif (List::MoreUtils::any {$_ eq "NEW"} $params->keys) {
        $self->{main_mode} = 'new';
    } elsif (List::MoreUtils::any {$_ eq "NTIME"} $params->keys) {
        $self->{main_mode} = 'time';
    } elsif (List::MoreUtils::any {$_ eq "STIME"} $params->keys) {
        $self->{main_mode} = 'stime';
        $self->{ct_sec} = $params->get("SSEC");
    }

    $self->{input_pass} = $params->get("PASSWORD");
    $self->{ct_year} = $params->get("YEAR");
    $self->{ct_mon} = $params->get("MON");
    $self->{ct_date} = $params->get("DATE");
    $self->{ct_hour} = $params->get("HOUR");
    $self->{ct_min} = $params->get("MIN");
    $self->{ct_sec} = $params->get("NSEC");
}

sub pass_check {
    my ($self) = @_;

    if($self->{input_pass} eq Hako::Config::MASTER_PASSWORD) {
        return 1;
    } else {
    $self->out(<<END);
   <FONT SIZE=7>�ѥ���ɤ��㤤�ޤ���</FONT>
END
        return 0;
    }
}

sub rm_tree {
    my ($dn) = @_;
    opendir(DIN, "$dn/");
    my($fileName);
    while ($fileName = readdir(DIN)) {
        unlink("$dn/$fileName");
    }
    closedir(DIN);
    rmdir($dn);
}

sub file_copy {
    my ($src, $dist) = @_;
    open(IN, $src);
    open(OUT, ">$dist");
    while (<IN>) {
        print OUT;
    }
    close(IN);
    close(OUT);
}

sub delete_mode {
    my ($self) = @_;

    if ($self->{delete_id} eq '') {
        rm_tree(Hako::Config::DATA_DIR);
        Hako::DB->force_reset;
    } else {
        rm_tree("@{[Hako::Config::DATA_DIR]}.bak@{[$self->{delete_id}]}");
    }
    unlink "hakojimalockflock";
}

sub current_mode {
    my ($self) = @_;

    rm_tree(Hako::Config::DATA_DIR);
    mkdir("@{[Hako::Config::DATA_DIR]}", Hako::Config::DIR_MODE);
    opendir(DIN, "@{[Hako::Config::DATA_DIR]}.bak@{[$self->{current_id}]}/");
    my($fileName);
    while($fileName = readdir(DIN)) {
        file_copy("@{[Hako::Config::DATA_DIR]}.bak@{[$self->{current_id}]}/$fileName", "@{[Hako::Config::DATA_DIR]}/$fileName");
    }
    closedir(DIN);
}

sub time_mode {
    my ($self) = @_;

    $self->{ct_mon}--;
    $self->{ct_year} -= 1900;
    $self->{ct_sec} = timelocal($self->{ct_sec}, $self->{ct_min}, $self->{ct_hour}, $self->{ct_date}, $self->{ct_mon}, $self->{ct_year});
    $self->stime_mode;
};

sub stime_mode {
    my ($self) = @_;

    my ($t) = $self->{ct_sec};
    open(IN, "@{[Hako::Config::DATA_DIR]}/hakojima.dat");
    my (@lines);
    @lines = <IN>;
    close(IN);

    $lines[1] = "$t\n";

    open(OUT, "> @{[Hako::Config::DATA_DIR]}/hakojima.dat");
    print OUT @lines;
    close(OUT);

    Hako::DB->set_global_value("last_time", $t);
};

sub new_mode {
    my ($self) = @_;
    mkdir(Hako::Config::DATA_DIR, Hako::Config::DIR_MODE);

    # ���ߤλ��֤����
    my ($now) = time;
    $now = $now - ($now % (Hako::Config::UNIT_TIME));

    open(OUT, "> @{[Hako::Config::DATA_DIR]}/hakojima.dat"); # �ե�����򳫤�
    print OUT "1\n";         # �������1
    print OUT "$now\n";      # ���ϻ���
    print OUT "0\n";         # ��ο�
    print OUT "1\n";         # ���˳�����Ƥ�ID

    Hako::DB->set_global_value("turn", 1);
    Hako::DB->set_global_value("last_time", $now);
    Hako::DB->set_global_value("number", 0);
    Hako::DB->set_global_value("next_id", 1);

    # �ե�������Ĥ���
    close(OUT);
}

sub time_to_string {
    my ($sec, $min, $hour, $date, $mon, $year, $day, $yday, $dummy) = localtime($_[0]);
    $mon++;
    $year += 1900;

    return "${year}ǯ ${mon}�� ${date}�� ${hour}�� ${min}ʬ ${sec}��";
}

sub data_print {
    my ($self) = @_;

    $self->out("<HR>");
    $self->out("<H1>����ǡ���</H1>");

    my $lastTurn = Hako::DB->get_global_value("turn");
    my $lastTime = Hako::DB->get_global_value("last_time");

    my $timeString = time_to_string($lastTime);

    $self->out(<<END);
    <B>������$lastTurn</B><BR>
    <B>�ǽ���������</B>:$timeString<BR>
    <B>�ǽ���������(�ÿ�ɽ��)</B>:1970ǯ1��1������$lastTime ��<BR>
    <INPUT TYPE="submit" VALUE="���Υǡ�������" NAME="DELETE">
END

    my ($sec, $min, $hour, $date, $mon, $year, $day, $yday, $dummy) = localtime($lastTime);
    $mon++;
    $year += 1900;

    $self->out(<<END);
    <H2>�ǽ��������֤��ѹ�</H2>
    <INPUT TYPE="text" SIZE=4 NAME="YEAR" VALUE="$year">ǯ
    <INPUT TYPE="text" SIZE=2 NAME="MON" VALUE="$mon">��
    <INPUT TYPE="text" SIZE=2 NAME="DATE" VALUE="$date">��
    <INPUT TYPE="text" SIZE=2 NAME="HOUR" VALUE="$hour">��
    <INPUT TYPE="text" SIZE=2 NAME="MIN" VALUE="$min">ʬ
    <INPUT TYPE="text" SIZE=2 NAME="NSEC" VALUE="$sec">��
    <INPUT TYPE="submit" VALUE="�ѹ�" NAME="NTIME"><BR>
    1970ǯ1��1������<INPUT TYPE="text" SIZE=32 NAME="SSEC" VALUE="$lastTime">��
    <INPUT TYPE="submit" VALUE="�û�����ѹ�" NAME="STIME">
END
};

sub main_mode_sub {
    my ($self) = @_;

    opendir(DIN, "./");

    $self->out(<<END);
<FORM action="/mente" method="POST">
<H1>Ȣ�磲 ���ƥʥ󥹥ġ���</H1>
<B>�ѥ����:</B><INPUT TYPE=password SIZE=32 MAXLENGTH=32 NAME=PASSWORD></TD>
END

    # ����ǡ���
    if (-d Hako::Config::DATA_DIR) {
        $self->data_print("");
    } else {
    $self->out(<<END);
    <HR>
    <INPUT TYPE="submit" VALUE="�������ǡ�������" NAME="NEW">
END
    }

    # �Хå����åץǡ���
    my($dn);
    while($dn = readdir(DIN)) {
        if($dn =~ /^@{[Hako::Config::DATA_DIR]}.bak(.*)/) {
            $self->data_print($1);
        }
    }
    closedir(DIN);
};

sub psgi {
    my ($self) = @_;

    return sub {
        my ($env) = @_;

        $self->initialize;
        my $request = Plack::Request->new($env);
        my $response = Plack::Response->new(200);
        $response->content_type("text/html");

        $self->out(<<END);
        <HTML>
        <HEAD>
        <TITLE>Ȣ�磲 ���ƥʥ󥹥ġ���</TITLE>
        </HEAD>
        <BODY>
END

        $self->cgi_input($request);

        if ($self->{main_mode} eq 'delete') {
            if ($self->pass_check) {
                $self->delete_mode;
            }
        } elsif ($self->{main_mode} eq 'current') {
            if ($self->pass_check) {
                $self->current_mode;
            }
        } elsif ($self->{main_mode} eq 'time') {
            if ($self->pass_check) {
                $self->time_mode;
            }
        } elsif ($self->{main_mode} eq 'stime') {
            if ($self->pass_check) {
                $self->stime_mode;
            }
        } elsif ($self->{main_mode} eq 'new') {
            if ($self->pass_check) {
                $self->new_mode;
            }
        }
        $self->main_mode_sub;

        $self->out(<<END);
        </FORM>
        </BODY>
        </HTML>
END

        $response->body($self->{out_buffer});
        $response->headers({"Set-Cookie" => $self->{cookie_buffer}});
        return $response->finalize;
    };
}

1;
