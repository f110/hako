# vim: set ft=perl:
use utf8;
use Hako::Config;
use Hako::Template::Function;
#----------------------------------------------------------------------
# 箱庭諸島 ver2.30
# トップモジュール(ver1.00)
# 使用条件、使用方法等は、hako-readme.txtファイルを参照
#
# 箱庭諸島のページ: http://www.bekkoame.ne.jp/~tokuoka/hakoniwa.html
#----------------------------------------------------------------------


#----------------------------------------------------------------------
# トップページモード
#----------------------------------------------------------------------
# メイン
sub topPageMain {
    # テンプレート出力
    tempTopPage();
}

# トップページ
sub tempTopPage {
    # タイトル
    out(<<END);
@{[Hako::Config::TAG_TITLE_]}@{[Hako::Config::TITLE]}@{[Hako::Config::_TAG_TITLE]}
END

    # デバッグモードなら「ターンを進める」ボタン
    if(Hako::Config::DEBUG == 1) {
        out(<<END);
<FORM action="$HthisFile" method="POST">
<INPUT TYPE="submit" VALUE="ターンを進める" NAME="TurnButton">
</FORM>
END
    }

    my($mStr1) = '';
    if (Hako::Config::HIDE_MONEY_MODE != 0) {
        $mStr1 = "<TH @{[Hako::Config::BG_TITLE_CELL]} align=center nowrap=nowrap><NOBR>".Hako::Template::Function->wrap_th("資金")."</NOBR></TH>";
    }

    # フォーム
    out(<<END);
<H1>@{[Hako::Config::TAG_HEADER_]}ターン$HislandTurn@{[Hako::Config::_TAG_HEADER]}</H1>

<HR>
<H1>@{[Hako::Config::TAG_HEADER_]}自分の島へ@{[Hako::Config::_TAG_HEADER]}</H1>
<FORM action="$HthisFile" method="POST">
END
        out(<<END);
あなたの島の名前は？<BR>
<SELECT NAME="ISLANDID">
$HislandList
</SELECT><BR>

パスワードをどうぞ！！<BR>
<INPUT TYPE="password" NAME="PASSWORD" VALUE="$HdefaultPassword" SIZE=32 MAXLENGTH=32><BR>
<INPUT TYPE="submit" VALUE="開発しに行く" NAME="OwnerButton"><BR>
</FORM>

<HR>

END
        out(<<END);
<H1>@{[Hako::Config::TAG_HEADER_]}諸島の状況@{[Hako::Config::_TAG_HEADER]}</H1>
<P>
島の名前をクリックすると、<B>観光</B>することができます。
</P>
<TABLE BORDER>
<TR>
<TH @{[Hako::Config::BG_TITLE_CELL]} align=center nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("順位")]}</NOBR></TH>
<TH @{[Hako::Config::BG_TITLE_CELL]} align=center nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("島")]}</NOBR></TH>
<TH @{[Hako::Config::BG_TITLE_CELL]} align=center nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("人口")]}</NOBR></TH>
<TH @{[Hako::Config::BG_TITLE_CELL]} align=center nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("面積")]}</NOBR></TH>
$mStr1
<TH @{[Hako::Config::BG_TITLE_CELL]} align=center nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("食料")]}</NOBR></TH>
<TH @{[Hako::Config::BG_TITLE_CELL]} align=center nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("農場規模")]}</NOBR></TH>
<TH @{[Hako::Config::BG_TITLE_CELL]} align=center nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("工場規模")]}</NOBR></TH>
<TH @{[Hako::Config::BG_TITLE_CELL]} align=center nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("")]}採掘場規模</NOBR></TH>
</TR>
END

    my($island, $j, $farm, $factory, $mountain, $name, $id, $prize, $ii);
    for($ii = 0; $ii < $HislandNumber; $ii++) {
	$j = $ii + 1;
	$island = $Hislands[$ii];

	$id = $island->{'id'};
	$farm = $island->{'farm'};
	$factory = $island->{'factory'};
	$mountain = $island->{'mountain'};
	$farm = ($farm == 0) ? "保有せず" : "${farm}0" . Hako::Config::UNIT_POPULATION;
	$factory = ($factory == 0) ? "保有せず" : "${factory}0" . Hako::Config::UNIT_POPULATION;
	$mountain = ($mountain == 0) ? "保有せず" : "${mountain}0" . Hako::Config::UNIT_POPULATION;
	if($island->{'absent'}  == 0) {
		$name = "@{[Hako::Config::TAG_NAME_]}$island->{'name'}島@{[Hako::Config::_TAG_NAME]}";
	} else {
	    $name = "@{[Hako::Config::TAG_NAME2_]}$island->{'name'}島($island->{'absent'})@{[Hako::Config::_TAG_NAME2]}";
	}

	$prize = $island->{'prize'};
	my($flags, $monsters, $turns);
	$prize =~ /([0-9]*),([0-9]*),(.*)/;
	$flags = $1;
	$monsters= $2;
	$turns = $3;
	$prize = '';

	# ターン杯の表示
	while($turns =~ s/([0-9]*),//) {
	    $prize .= "<IMG SRC=\"prize0.gif\" ALT=\"$1" . ${Hako::Config::PRIZE()}[0] . "\" WIDTH=16 HEIGHT=16> ";
	}

	# 名前に賞の文字を追加
	my($f) = 1;
	my($i);
	for($i = 1; $i < 10; $i++) {
	    if($flags & $f) {
		$prize .= "<IMG SRC=\"prize${i}.gif\" ALT=\"" . ${Hako::Config::PRIZE()}[$i] . "\" WIDTH=16 HEIGHT=16> ";
	    }
	    $f *= 2;
	}

	# 倒した怪獣リスト
	$f = 1;
	my($max) = -1;
	my($mNameList) = '';
	for($i = 0; $i < Hako::Config::MONSTER_NUMBER; $i++) {
	    if($monsters & $f) {
		$mNameList .= "[" . ${Hako::Config::MONSTER_NAME()}[$i] . "] ";
		$max = $i;
	    }
	    $f *= 2;
	}
	if($max != -1) {
	    $prize .= "<IMG SRC=\"" . ${Hako::Config::MONSTER_IMAGE()}[$max] . "\" ALT=\"$mNameList\" WIDTH=16 HEIGHT=16> ";
	}


	my($mStr1) = '';
	if (Hako::Config::HIDE_MONEY_MODE == 1) {
	    $mStr1 = "<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$island->{money}@{[Hako::Config::UNIT_MONEY]}</NOBR></TD>";
	} elsif (Hako::Config::HIDE_MONEY_MODE == 2) {
	    my($mTmp) = aboutMoney($island->{'money'});
	    $mStr1 = "<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$mTmp</NOBR></TD>";
	}

	out(<<END);
<TR>
<TD @{[Hako::Config::BG_NUMBER_CELL]} ROWSPAN=2 align=center nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_number($j)]}</NOBR></TD>
<TD @{[Hako::Config::BG_NAME_CELL]} ROWSPAN=2 align=left nowrap=nowrap><NOBR><A STYlE=\"text-decoration:none\" HREF="${HthisFile}?Sight=${id}">$name</A></NOBR><BR>$prize</TD>
<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$island->{'pop'}@{[Hako::Config::UNIT_POPULATION]}</NOBR></TD>
<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$island->{'area'}@{[Hako::Config::UNIT_AREA]}</NOBR></TD>
$mStr1
<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$island->{'food'}@{[Hako::Config::UNIT_FOOD]}</NOBR></TD>
<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$farm</NOBR></TD>
<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$factory</NOBR></TD>
<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$mountain</NOBR></TD>
</TR>
<TR>
<TD @{[Hako::Config::BG_COMMENT_CELL]} COLSPAN=7 align=left nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("コメント：")]}$island->{'comment'}</NOBR></TD>
</TR>
END
    }

    out(<<END);
</TABLE>

<HR>
<H1>@{[Hako::Config::TAG_HEADER_]}新しい島を探す@{[Hako::Config::_TAG_HEADER]}</H1>
END

    if($HislandNumber < Hako::Config::MAX_ISLAND) {
	out(<<END);
<FORM action="$HthisFile" method="POST">
どんな名前をつける予定？<BR>
<INPUT TYPE="text" NAME="ISLANDNAME" SIZE=32 MAXLENGTH=32>島<BR>
パスワードは？<BR>
<INPUT TYPE="password" NAME="PASSWORD" SIZE=32 MAXLENGTH=32><BR>
念のためパスワードをもう一回<BR>
<INPUT TYPE="password" NAME="PASSWORD2" SIZE=32 MAXLENGTH=32><BR>

<INPUT TYPE="submit" VALUE="探しに行く" NAME="NewIslandButton">
</FORM>
END
    } else {
	out(<<END);
        島の数が最大数です・・・現在登録できません。
END
    }

    out(<<END);
<HR>
<H1>@{[Hako::Config::TAG_HEADER_]}島の名前とパスワードの変更@{[Hako::Config::_TAG_HEADER]}</H1>
<P>
(注意)名前の変更には@{[Hako::Config::CHANGE_NAME_COST]}@{[Hako::Config::UNIT_MONEY]}かかります。
</P>
<FORM action="$HthisFile" method="POST">
どの島ですか？<BR>
<SELECT NAME="ISLANDID">
$HislandList
</SELECT>
<BR>
どんな名前に変えますか？(変更する場合のみ)<BR>
<INPUT TYPE="text" NAME="ISLANDNAME" SIZE=32 MAXLENGTH=32>島<BR>
パスワードは？(必須)<BR>
<INPUT TYPE="password" NAME="OLDPASS" SIZE=32 MAXLENGTH=32><BR>
新しいパスワードは？(変更する時のみ)<BR>
<INPUT TYPE="password" NAME="PASSWORD" SIZE=32 MAXLENGTH=32><BR>
念のためパスワードをもう一回(変更する時のみ)<BR>
<INPUT TYPE="password" NAME="PASSWORD2" SIZE=32 MAXLENGTH=32><BR>

<INPUT TYPE="submit" VALUE="変更する" NAME="ChangeInfoButton">
</FORM>

<HR>

<H1>@{[Hako::Config::TAG_HEADER_]}最近の出来事@{[Hako::Config::_TAG_HEADER]}</H1>
END
    logPrintTop();
    out(<<END);
<H1>@{[Hako::Config::TAG_HEADER_]}発見の記録@{[Hako::Config::_TAG_HEADER]}</H1>
END
    historyPrint();
}

# トップページ用ログ表示
sub logPrintTop {
    my $logs = Hako::DB->get_common_log($HislandTurn);

    for (@$logs) {
        out("<NOBR>".Hako::Template::Function->wrap_number("ターン".$_->{turn})."：@{[$_->{message}]}</NOBR><BR>\n");
    }
}

# 記録ファイル表示
sub historyPrint {
    my $histories = Hako::DB->get_history();
    for my $line (@$histories) {
        my $msg = $line->{message};
        out("<NOBR>".Hako::Template::Function->wrap_number("ターン".$line->{turn})."：@{[$msg]}</NOBR><BR>\n");
    }
}

1;
