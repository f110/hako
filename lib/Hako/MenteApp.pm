package Hako::MenteApp;
use strict;
use warnings;
use Plack::Request;
use Plack::Response;
use Time::Local;
use List::MoreUtils qw();
use Hako::Config;

#----------------------------------------------------------------------
# Ȣ����� ver2.30
# ���ƥʥ󥹥ġ���(ver1.01)
# ���Ѿ�������ˡ���ϡ�hako-readme.txt�ե�����򻲾�
#
# Ȣ�����Υڡ���: http://www.bekkoame.ne.jp/~tokuoka/hakoniwa.html
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

    # ɽ���⡼��
    my $dataPrint = sub {
        my($suf) = @_;

        $out->("<HR>");
        if($suf eq "") {
            open(IN, "@{[Hako::Config::DATA_DIR]}/hakojima.dat");
            $out->("<H1>����ǡ���</H1>");
        } else {
            open(IN, "@{[Hako::Config::DATA_DIR]}.bak$suf/hakojima.dat");
            $out->("<H1>�Хå����å�$suf</H1>");
        }

        my($lastTurn);
        $lastTurn = <IN>;
        my($lastTime);
        $lastTime = <IN>;

        my($timeString) = timeToString($lastTime);

        $out->(<<END);
        <B>������$lastTurn</B><BR>
        <B>�ǽ���������</B>:$timeString<BR>
        <B>�ǽ���������(�ÿ�ɽ��)</B>:1970ǯ1��1������$lastTime ��<BR>
        <INPUT TYPE="submit" VALUE="���Υǡ�������" NAME="DELETE$suf">
END

        if($suf eq "") {
            my($sec, $min, $hour, $date, $mon, $year, $day, $yday, $dummy) =
                localtime($lastTime);
            $mon++;
            $year += 1900;

            $out->(<<END);
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
        } else {
            $out->(<<END);
            <INPUT TYPE="submit" VALUE="���Υǡ��������" NAME="CURRENT$suf">
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

        # ���ߤλ��֤����
        my($now) = time;
        $now = $now - ($now % (Hako::Config::UNIT_TIME));

        open(OUT, "> @{[Hako::Config::DATA_DIR]}/hakojima.dat"); # �ե�����򳫤�
        print OUT "1\n";         # �������1
        print OUT "$now\n";      # ���ϻ���
        print OUT "0\n";         # ��ο�
        print OUT "1\n";         # ���˳�����Ƥ�ID

        # �ե�������Ĥ���
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
    <H1>Ȣ�磲 ���ƥʥ󥹥ġ���</H1>
    <B>�ѥ����:</B><INPUT TYPE=password SIZE=32 MAXLENGTH=32 NAME=PASSWORD></TD>
END

        # ����ǡ���
        if(-d Hako::Config::DATA_DIR) {
        $dataPrint->("");
        } else {
        $out->(<<END);
        <HR>
        <INPUT TYPE="submit" VALUE="�������ǡ�������" NAME="NEW">
END
        }

        # �Хå����åץǡ���
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

        return "${year}ǯ ${mon}�� ${date}�� ${hour}�� ${min}ʬ ${sec}��";
    }

    # CGI���ɤߤ���
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

    # �ե�����Υ��ԡ�
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

    # �ѥ������å�
    my $passCheck = sub {
        if($inputPass eq Hako::Config::MASTER_PASSWORD) {
            return 1;
        } else {
        $out->(<<END);
       <FONT SIZE=7>�ѥ���ɤ��㤤�ޤ���</FONT>
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
        <TITLE>Ȣ�磲 ���ƥʥ󥹥ġ���</TITLE>
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
