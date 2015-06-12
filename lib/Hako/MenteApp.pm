package Hako::MenteApp;
use strict;
use warnings;
use Plack::Request;
use Plack::Response;
use Time::Local;
use List::MoreUtils qw();
use Hako::Config;

#----------------------------------------------------------------------
# 箱庭諸島 ver2.30
# メンテナンスツール(ver1.01)
# 使用条件、使用方法等は、hako-readme.txtファイルを参照
#
# 箱庭諸島のページ: http://www.bekkoame.ne.jp/~tokuoka/hakoniwa.html
#----------------------------------------------------------------------

sub to_app {
    my ($request, $response);
    my ($out_buffer, $cookie_buffer);

    my $mainMode = "";
    my($inputPass);
    my($deleteID);
    my($currentID);
    my($ctYear);
    my($ctMon);
    my($ctDate);
    my($ctHour);
    my($ctMin);
    my($ctSec);

    my $out = sub {
        $out_buffer .= shift;
    };

    # 表示モード
    my $dataPrint = sub {
        my($suf) = @_;

        $out->("<HR>");
        if($suf eq "") {
            open(IN, "@{[Hako::Config::DATA_DIR]}/hakojima.dat");
            $out->("<H1>現役データ</H1>");
        } else {
            open(IN, "@{[Hako::Config::DATA_DIR]}.bak$suf/hakojima.dat");
            $out->("<H1>バックアップ$suf</H1>");
        }

        my($lastTurn);
        $lastTurn = <IN>;
        my($lastTime);
        $lastTime = <IN>;

        my($timeString) = timeToString($lastTime);

        $out->(<<END);
        <B>ターン$lastTurn</B><BR>
        <B>最終更新時間</B>:$timeString<BR>
        <B>最終更新時間(秒数表示)</B>:1970年1月1日から$lastTime 秒<BR>
        <INPUT TYPE="submit" VALUE="このデータを削除" NAME="DELETE$suf">
END

        if($suf eq "") {
            my($sec, $min, $hour, $date, $mon, $year, $day, $yday, $dummy) =
                localtime($lastTime);
            $mon++;
            $year += 1900;

            $out->(<<END);
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
        } else {
            $out->(<<END);
            <INPUT TYPE="submit" VALUE="このデータを現役に" NAME="CURRENT$suf">
END
        }
    };


    sub myrmtree {
        my($dn) = @_;
        opendir(DIN, "$dn/");
        my($fileName);
        while($fileName = readdir(DIN)) {
            unlink("$dn/$fileName");
        }
        closedir(DIN);
        rmdir($dn);
    }

    my $currentMode = sub {
        myrmtree(Hako::Config::DATA_DIR);
        mkdir("@{[Hako::Config::DATA_DIR]}", Hako::Config::DIR_MODE);
        opendir(DIN, "@{[Hako::Config::DATA_DIR]}.bak$currentID/");
        my($fileName);
        while($fileName = readdir(DIN)) {
            fileCopy("@{[Hako::Config::DATA_DIR]}.bak$currentID/$fileName", "@{[Hako::Config::DATA_DIR]}/$fileName");
        }
        closedir(DIN);
    };

    my $deleteMode = sub {
        if($deleteID eq '') {
            myrmtree(Hako::Config::DATA_DIR);
        } else {
            myrmtree "@{[Hako::Config::DATA_DIR]}.bak$deleteID";
        }
        unlink "hakojimalockflock";
    };

    sub newMode {
        mkdir(Hako::Config::DATA_DIR, Hako::Config::DIR_MODE);

        # 現在の時間を取得
        my($now) = time;
        $now = $now - ($now % (Hako::Config::UNIT_TIME));

        open(OUT, "> @{[Hako::Config::DATA_DIR]}/hakojima.dat"); # ファイルを開く
        print OUT "1\n";         # ターン数1
        print OUT "$now\n";      # 開始時間
        print OUT "0\n";         # 島の数
        print OUT "1\n";         # 次に割り当てるID

        # ファイルを閉じる
        close(OUT);
    }

    my $timeMode = sub {
        $ctMon--;
        $ctYear -= 1900;
        $ctSec = timelocal($ctSec, $ctMin, $ctHour, $ctDate, $ctMon, $ctYear);
        stimeMode();
    };

    my $stimeMode = sub {
        my($t) = $ctSec;
        open(IN, "@{[Hako::Config::DATA_DIR]}/hakojima.dat");
        my(@lines);
        @lines = <IN>;
        close(IN);

        $lines[1] = "$t\n";

        open(OUT, "> @{[Hako::Config::DATA_DIR]}/hakojima.dat");
        print OUT @lines;
        close(OUT);
    };

    my $mainModeSub = sub {
        opendir(DIN, "./");

        $out->(<<END);
    <FORM action="/mente" method="POST">
    <H1>箱島２ メンテナンスツール</H1>
    <B>パスワード:</B><INPUT TYPE=password SIZE=32 MAXLENGTH=32 NAME=PASSWORD></TD>
END

        # 現役データ
        if(-d Hako::Config::DATA_DIR) {
        $dataPrint->("");
        } else {
        $out->(<<END);
        <HR>
        <INPUT TYPE="submit" VALUE="新しいデータを作る" NAME="NEW">
END
        }

        # バックアップデータ
        my($dn);
        while($dn = readdir(DIN)) {
            if($dn =~ /^@{[Hako::Config::DATA_DIR]}.bak(.*)/) {
                $dataPrint->($1);
            }
        }
        closedir(DIN);
    };

    sub timeToString {
        my($sec, $min, $hour, $date, $mon, $year, $day, $yday, $dummy) =
        localtime($_[0]);
        $mon++;
        $year += 1900;

        return "${year}年 ${mon}月 ${date}日 ${hour}時 ${min}分 ${sec}秒";
    }

    # CGIの読みこみ
    my $cgiInput = sub {
        my $params = $request->parameters;
        if (List::MoreUtils::any {$_ =~ /DELETE([0-9]*)/} $params->keys) {
            $mainMode = 'delete';
            $deleteID = $1;
        } elsif(List::MoreUtils::any {$_ =~ /CURRENT([0-9]*)/} $params->keys) {
            $mainMode = 'current';
            $currentID = $1;
        } elsif (List::MoreUtils::any {$_ eq "NEW"} $params->keys) {
            $mainMode = 'new';
        } elsif (List::MoreUtils::any {$_ eq "NTIME"} $params->keys) {
            $mainMode = 'time';
        } elsif (List::MoreUtils::any {$_ eq "STIME"} $params->keys) {
            $mainMode = 'stime';
            $ctSec = $params->get("SSEC");
        }

        $inputPass = $params->get("PASSWORD");
        $ctYear = $params->get("YEAR");
        $ctMon = $params->get("MON");
        $ctDate = $params->get("DATE");
        $ctHour = $params->get("HOUR");
        $ctMin = $params->get("MIN");
        $ctSec = $params->get("NSEC");
    };

    # ファイルのコピー
    sub fileCopy {
        my($src, $dist) = @_;
        open(IN, $src);
        open(OUT, ">$dist");
        while(<IN>) {
            print OUT;
        }
        close(IN);
        close(OUT);
    }

    # パスチェック
    my $passCheck = sub {
        if($inputPass eq Hako::Config::MASTER_PASSWORD) {
            return 1;
        } else {
        $out->(<<END);
       <FONT SIZE=7>パスワードが違います。</FONT>
END
            return 0;
        }
    };

    return sub {
        my ($env) = @_;

        $out_buffer = "";
        $cookie_buffer = "";
        $request = Plack::Request->new($env);
        $response = Plack::Response->new(200);
        $response->content_type("text/html");

        $out->(<<END);
        <HTML>
        <HEAD>
        <TITLE>箱島２ メンテナンスツール</TITLE>
        </HEAD>
        <BODY>
END

        $cgiInput->();

        if($mainMode eq 'delete') {
            if($passCheck->()) {
                $deleteMode->();
            }
        } elsif($mainMode eq 'current') {
            if($passCheck->()) {
                $currentMode->();
            }
        } elsif($mainMode eq 'time') {
            if($passCheck->()) {
                $timeMode->();
            }
        } elsif($mainMode eq 'stime') {
            if($passCheck->()) {
                $stimeMode->();
            }
        } elsif($mainMode eq 'new') {
            if($passCheck->()) {
                newMode();
            }
        }
        $mainModeSub->();

        $out->(<<END);
        </FORM>
        </BODY>
        </HTML>
END

        $response->body($out_buffer);
        $response->headers({"Set-Cookie" => $cookie_buffer});
        return $response->finalize;
    };
}

}
1;
