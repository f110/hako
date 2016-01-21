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
# 箱庭諸島 ver2.30
# メンテナンスツール(ver1.01)
# 使用条件、使用方法等は、hako-readme.txtファイルを参照
#
# 箱庭諸島のページ: http://www.bekkoame.ne.jp/~tokuoka/hakoniwa.html
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
   <FONT SIZE=7>パスワードが違います。</FONT>
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

    # 現在の時間を取得
    my ($now) = time;
    $now = $now - ($now % (Hako::Config::UNIT_TIME));

    open(OUT, "> @{[Hako::Config::DATA_DIR]}/hakojima.dat"); # ファイルを開く
    print OUT "1\n";         # ターン数1
    print OUT "$now\n";      # 開始時間
    print OUT "0\n";         # 島の数
    print OUT "1\n";         # 次に割り当てるID

    Hako::DB->set_global_value("turn", 1);
    Hako::DB->set_global_value("last_time", $now);
    Hako::DB->set_global_value("number", 0);
    Hako::DB->set_global_value("next_id", 1);

    # ファイルを閉じる
    close(OUT);
}

sub time_to_string {
    my ($sec, $min, $hour, $date, $mon, $year, $day, $yday, $dummy) = localtime($_[0]);
    $mon++;
    $year += 1900;

    return "${year}年 ${mon}月 ${date}日 ${hour}時 ${min}分 ${sec}秒";
}

sub data_print {
    my ($self) = @_;

    $self->out("<HR>");
    $self->out("<H1>現役データ</H1>");

    my $lastTurn = Hako::DB->get_global_value("turn");
    my $lastTime = Hako::DB->get_global_value("last_time");

    my $timeString = time_to_string($lastTime);

    $self->out(<<END);
    <B>ターン$lastTurn</B><BR>
    <B>最終更新時間</B>:$timeString<BR>
    <B>最終更新時間(秒数表示)</B>:1970年1月1日から$lastTime 秒<BR>
    <INPUT TYPE="submit" VALUE="このデータを削除" NAME="DELETE">
END

    my ($sec, $min, $hour, $date, $mon, $year, $day, $yday, $dummy) = localtime($lastTime);
    $mon++;
    $year += 1900;

    $self->out(<<END);
    <H2>最終更新時間の変更</H2>
    <INPUT TYPE="text" SIZE=4 NAME="YEAR" VALUE="$year">年
    <INPUT TYPE="text" SIZE=2 NAME="MON" VALUE="$mon">月
    <INPUT TYPE="text" SIZE=2 NAME="DATE" VALUE="$date">日
    <INPUT TYPE="text" SIZE=2 NAME="HOUR" VALUE="$hour">時
    <INPUT TYPE="text" SIZE=2 NAME="MIN" VALUE="$min">分
    <INPUT TYPE="text" SIZE=2 NAME="NSEC" VALUE="$sec">秒
    <INPUT TYPE="submit" VALUE="変更" NAME="NTIME"><BR>
    1970年1月1日から<INPUT TYPE="text" SIZE=32 NAME="SSEC" VALUE="$lastTime">秒
    <INPUT TYPE="submit" VALUE="秒指定で変更" NAME="STIME">
END
};

sub main_mode_sub {
    my ($self) = @_;

    opendir(DIN, "./");

    $self->out(<<END);
<FORM action="/mente" method="POST">
<H1>箱島２ メンテナンスツール</H1>
<B>パスワード:</B><INPUT TYPE=password SIZE=32 MAXLENGTH=32 NAME=PASSWORD></TD>
END

    # 現役データ
    if (-d Hako::Config::DATA_DIR) {
        $self->data_print("");
    } else {
    $self->out(<<END);
    <HR>
    <INPUT TYPE="submit" VALUE="新しいデータを作る" NAME="NEW">
END
    }

    # バックアップデータ
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
        <TITLE>箱島２ メンテナンスツール</TITLE>
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
