{
package MenteApp;
use Plack::Request;
use Plack::Response;
use YAML;
use File::Spec;
use File::Basename;
use Time::Local;
use List::MoreUtils qw();

#----------------------------------------------------------------------
# Ȣ����� ver2.30
# ���ƥʥ󥹥ġ���(ver1.01)
# ���Ѿ�������ˡ���ϡ�hako-readme.txt�ե�����򻲾�
#
# Ȣ�����Υڡ���: http://www.bekkoame.ne.jp/~tokuoka/hakoniwa.html
#----------------------------------------------------------------------


# ������������������������������������������������������������
# �Ƽ�������
# ������������������������������������������������������������

my $config = YAML::LoadFile(File::Spec->catfile(dirname(__FILE__), "config.yaml"));
# �ޥ������ѥ����
my($masterpassword) = $config->{master_password};

# 1�����󤬲��ä�
my($unitTime) = $config->{unit_time}; # 6����

# �ǥ��쥯�ȥ�Υѡ��ߥå����
my($dirMode) = 0755;

# ���Υե�����
my($thisFile) = 'http://localhost:5000/mente';

# �ǡ����ǥ��쥯�ȥ��̾��
# hakojima.cgi��Τ�Τȹ�碌�Ƥ���������
my($dirName) = $config->{data_dir};


# ������������������������������������������������������������
# ������ܤϰʾ�
# ������������������������������������������������������������

# �Ƽ��ѿ�
sub to_app {
    my ($out_buffer, $cookie_buffer);

    my($mainMode);
    my($inputPass);
    my($deleteID);
    my($currentID);
    my($ctYear);
    my($ctMon);
    my($ctDate);
    my($ctHour);
    my($ctMin);
    my($ctSec);


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

    sub currentMode {
        myrmtree "${dirName}";
        mkdir("${dirName}", $dirMode);
        opendir(DIN, "${dirName}.bak$currentID/");
        my($fileName);
        while($fileName = readdir(DIN)) {
            fileCopy("${dirName}.bak$currentID/$fileName", "${dirName}/$fileName");
        }
        closedir(DIN);
    }

    sub deleteMode {
        if($deleteID eq '') {
            myrmtree "${dirName}";
        } else {
            myrmtree "${dirName}.bak$deleteID";
        }
        unlink "hakojimalockflock";
    }

    sub newMode {
        mkdir($dirName, $dirMode);

        # ���ߤλ��֤����
        my($now) = time;
        $now = $now - ($now % ($unitTime));

        open(OUT, ">$dirName/hakojima.dat"); # �ե�����򳫤�
        print OUT "1\n";         # �������1
        print OUT "$now\n";      # ���ϻ���
        print OUT "0\n";         # ��ο�
        print OUT "1\n";         # ���˳�����Ƥ�ID

        # �ե�������Ĥ���
        close(OUT);
    }

    sub timeMode {
        $ctMon--;
        $ctYear -= 1900;
        $ctSec = timelocal($ctSec, $ctMin, $ctHour, $ctDate, $ctMon, $ctYear);
        stimeMode();
    }

    sub stimeMode {
        my($t) = $ctSec;
        open(IN, "${dirName}/hakojima.dat");
        my(@lines);
        @lines = <IN>;
        close(IN);

        $lines[1] = "$t\n";

        open(OUT, ">${dirName}/hakojima.dat");
        print OUT @lines;
        close(OUT);
    }

    sub mainMode {
        opendir(DIN, "./");

        out(<<END);
    <FORM action="$thisFile" method="POST">
    <H1>Ȣ�磲 ���ƥʥ󥹥ġ���</H1>
    <B>�ѥ����:</B><INPUT TYPE=password SIZE=32 MAXLENGTH=32 NAME=PASSWORD></TD>
END

        # ����ǡ���
        if(-d "${dirName}") {
        dataPrint("");
        } else {
        out(<<END);
        <HR>
        <INPUT TYPE="submit" VALUE="�������ǡ�������" NAME="NEW">
END
        }

        # �Хå����åץǡ���
        my($dn);
        while($dn = readdir(DIN)) {
            if($dn =~ /^${dirName}.bak(.*)/) {
                dataPrint($1);
            }
        }
        closedir(DIN);
    }

    # ɽ���⡼��
    sub dataPrint {
        my($suf) = @_;

        out("<HR>");
        if($suf eq "") {
            open(IN, "${dirName}/hakojima.dat");
            out("<H1>����ǡ���</H1>");
        } else {
            open(IN, "${dirName}.bak$suf/hakojima.dat");
            out("<H1>�Хå����å�$suf</H1>");
        }

        my($lastTurn);
        $lastTurn = <IN>;
        my($lastTime);
        $lastTime = <IN>;

        my($timeString) = timeToString($lastTime);

        out(<<END);
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

            out(<<END);
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
            out(<<END);
            <INPUT TYPE="submit" VALUE="���Υǡ��������" NAME="CURRENT$suf">
END
        }
    }

    sub timeToString {
        my($sec, $min, $hour, $date, $mon, $year, $day, $yday, $dummy) =
        localtime($_[0]);
        $mon++;
        $year += 1900;

        return "${year}ǯ ${mon}�� ${date}�� ${hour}�� ${min}ʬ ${sec}��";
    }

    # CGI���ɤߤ���
    sub cgiInput {
        my $params = $request->parameters;
        if (List::MoreUtils::any {$_ =~ /DELETE([0-9]*)/} $params->keys) {
            $mainMode = 'delete';
            $deleteID = $1;
        } elsif($line =~ /CURRENT([0-9]*)/) {
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
    }

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
    sub passCheck {
        if($inputPass eq $masterpassword) {
            return 1;
        } else {
        out(<<END);
       <FONT SIZE=7>�ѥ���ɤ��㤤�ޤ���</FONT>
END
            return 0;
        }
    }

    sub out {
        $out_buffer .= shift;
    }

    return sub {
        my ($env) = @_;

        $out_buffer = "";
        $cookie_buffer = "";
        $request = Plack::Request->new($env);
        $response = Plack::Response->new(200);
        $response->content_type("text/html");

        out(<<END);
        <HTML>
        <HEAD>
        <TITLE>Ȣ�磲 ���ƥʥ󥹥ġ���</TITLE>
        </HEAD>
        <BODY>
END

        cgiInput();

        if($mainMode eq 'delete') {
            if(passCheck()) {
                deleteMode();
            }
        } elsif($mainMode eq 'current') {
            if(passCheck()) {
                currentMode();
            }
        } elsif($mainMode eq 'time') {
            if(passCheck()) {
                timeMode();
            }
        } elsif($mainMode eq 'stime') {
            if(passCheck()) {
                stimeMode();
            }
        } elsif($mainMode eq 'new') {
            if(passCheck()) {
                newMode();
            }
        }
        mainMode();

        out(<<END);
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
