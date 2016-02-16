package Hako::MainApp;
use utf8;
use strict;
use warnings;
use Encode qw();
use YAML ();
use File::Spec;
use File::Basename;
use Plack::Response;
use Plack::Request;
use List::MoreUtils qw();
use Text::Xslate qw(mark_raw);
use Hako::Config;
use Hako::Constants;
use Hako::DB;
use Hako::Model::Island;
use Hako::Util;
use Hako::Mode;
use Hako::Template::Function;
use Devel::Peek;

sub new {
    my ($class) = @_;

    return bless {}, $class;
}

sub initialize {
    my ($self) = @_;

    $self->{out_buffer} = "";
    $self->{cookie_buffer} = "";
    $self->{request} = undef;
    $self->{response} = undef;
    $self->{default_id} = 0;
    $self->{default_password} = "";
    $self->{default_target} = "";
    $self->{default_name} = "";
    $self->{default_x} = "";
    $self->{default_y} = "";
    $self->{default_kind} = "";
    $self->{current_id} = "";
    $self->{current_name} = "";
    $self->{current_number} = "";
    $self->{old_password} = "";
    $self->{input_password} = "";
    $self->{input_password2} = "";
    $self->{message} = "";
    $self->{local_bbs_name} = "";
    $self->{local_bbs_message} = "";
    $self->{local_bbs_mode} = "";
    $self->{main_mode} = "top";
    $self->{command_plan_number} = "";
    $self->{command_kind} = "";
    $self->{command_arg} = "";
    $self->{command_target} = "";
    $self->{command_x} = "";
    $self->{command_y} = "";
    $self->{command_mode} = "";
    $self->{default_kind} = "";
    $self->{island_turn} = "";
    $self->{island_last_time} = "";
    $self->{island_number} = "";
    $self->{island_next_id} = "";
    $self->{islands} = [];
    $self->{id_to_number} = {};
    $self->{id_to_name} = {};
    $self->{island_list} = "";
    $self->{target_list} = "";
    $self->{defence_hex} = []; # landをパースするときにちゃんと入れないと機能しなさそう
}

sub psgi {
    my ($self) = @_;

    return sub {
        my ($env) = @_;

        $self->initialize;
        my $request = Plack::Request->new($env);
        my $response = Plack::Response->new(200);
        $self->{request} = $request;
        $self->{response} = $response;
        $response->content_type("text/html");

        # 乱数の初期化
        srand(time^$$);

        # COOKIE読みこみ
        $self->cookieInput;

        # CGI読みこみ
        $self->cgiInput;

        # 島データの読みこみ
        if ($self->readIslandsFile($self->{current_id}) == 0) {
            $self->tempHeader;
            $self->tempNoDataFile;
            $self->tempFooter;
            $response->body($self->{out_buffer});
            return $response->finalize;
        }

        # テンプレートを初期化
        $self->tempInitialize;

        # COOKIE出力
        $self->cookieOutput;

        # ヘッダ出力
        $self->tempHeader;

        if ($self->{main_mode} eq 'turn') {
            # ターン進行
            Hako::Mode->turnMain($self);
        } elsif ($self->{main_mode} eq 'new') {
            # 島の新規作成
            Hako::Mode->newIslandMain($self);
        } elsif ($self->{main_mode} eq 'print') {
            # 観光モード
            Hako::Mode->printIslandMain($self);
        } elsif ($self->{main_mode} eq 'owner') {
            # 開発モード
            Hako::Mode->ownerMain($self);
        } elsif ($self->{main_mode} eq 'command') {
            # コマンド入力モード
            Hako::Mode->commandMain($self);
        } elsif ($self->{main_mode} eq 'comment') {
            # コメント入力モード
            Hako::Mode->commentMain($self);
        } elsif ($self->{main_mode} eq 'lbbs') {
            # ローカル掲示板モード
            Hako::Mode->localBbsMain($self);
        } elsif ($self->{main_mode} eq 'change') {
            # 情報変更モード
            Hako::Mode->changeMain($self);
        } else {
            # その他の場合はトップページモード
            $self->topPageMain;
        }

        # フッタ出力
        $self->tempFooter;

        $response->body($self->{out_buffer});
        $response->headers({"Set-Cookie" => $self->{cookie_buffer}});
        return $response->finalize;
    };
}

#cookie入力
sub cookieInput {
    my ($self) = @_;

    my $cookie = Encode::encode("EUC-JP", Encode::decode("Shift_JIS", $ENV{'HTTP_COOKIE'}));

    if ($cookie =~ /@{[Hako::Config::THIS_FILE]}OWNISLANDID=\(([^\)]*)\)/) {
        $self->{default_id} = $1;
    }
    if ($cookie =~ /@{[Hako::Config::THIS_FILE]}OWNISLANDPASSWORD=\(([^\)]*)\)/) {
        $self->{default_password} = $1;
    }
    if ($cookie =~ /@{[Hako::Config::THIS_FILE]}TARGETISLANDID=\(([^\)]*)\)/) {
        $self->{default_target} = $1;
    }
    if ($cookie =~ /@{[Hako::Config::THIS_FILE]}LBBSNAME=\(([^\)]*)\)/) {
        $self->{default_name} = $1;
    }
    if ($cookie =~ /@{[Hako::Config::THIS_FILE]}POINTX=\(([^\)]*)\)/) {
        $self->{default_x} = $1;
    }
    if ($cookie =~ /@{[Hako::Config::THIS_FILE]}POINTY=\(([^\)]*)\)/) {
        $self->{default_y} = $1;
    }
    if ($cookie =~ /@{[Hako::Config::THIS_FILE]}KIND=\(([^\)]*)\)/) {
        $self->{default_kind} = $1;
    }
}

# CGIの読みこみ
sub cgiInput {
    my ($self) = @_;

    my $params = $self->{request}->parameters;
    use Data::Dumper;warn Data::Dumper::Dumper($params);
    # 対象の島
    if (List::MoreUtils::any {$_ =~ /CommandButton([0-9]+)/} $params->keys) {
        my @tmp = grep {$_ =~ /^CommandButton/} $params->keys;
        $tmp[0] =~ /CommandButton([0-9]+)/;
        # コマンド送信ボタンの場合
        $self->{current_id} = $1;
        $self->{default_id} = $1;
    }

    if (List::MoreUtils::any {$_ eq "ISLANDNAME"} $params->keys) {
        # 名前指定の場合
        $self->{current_name} = Hako::Util::cutColumn($params->get("ISLANDNAME"), 32);
    }

    if (List::MoreUtils::any { $_ eq "ISLANDID" } $params->keys) {
        # その他の場合
        $self->{current_id} = $params->get("ISLANDID");
        $self->{default_id} = $params->get("ISLANDID");
    }

    # パスワード
    #if ($line =~ /OLDPASS=([^\&]*)\&/) {
        $self->{old_password} = $params->get("OLDPASS");
        $self->{default_password} = $params->get("OLDPASS");
    #}
    if (List::MoreUtils::any {$_ eq "PASSWORD"} $params->keys) {
        $self->{input_password} = $params->get("PASSWORD");
        $self->{default_password} = $params->get("PASSWORD");
    }
    if (List::MoreUtils::any {$_ eq "PASSWORD2"} $params->keys) {
        $self->{input_password2} = $params->get("PASSWORD2");
    }

    # メッセージ
    if (List::MoreUtils::any {$_ eq "MESSAGE"} $params->keys) {
        $self->{message} = Hako::Util::cutColumn($params->get("MESSAGE"), 80);
    }

    # ローカル掲示板
    if (List::MoreUtils::any {$_ eq "LBBSNAME"} $params->keys) {
        $self->{local_bbs_name} = Encode::decode("utf-8", $params->get("LBBSNAME"));
        $self->{default_name} = Encode::decode("utf-8", $params->get("LBBSNAME"));
    }
    if (List::MoreUtils::any {$_ eq "LBBSMESSAGE"} $params->keys) {
        $self->{local_bbs_message} = Hako::Util::cutColumn(Encode::decode("utf-8", $params->get("LBBSMESSAGE")), 80);
    }

    # main modeの取得
    if(List::MoreUtils::any {$_ eq "TurnButton"} $params->keys) {
        if(Hako::Config::DEBUG == 1) {
            $self->{main_mode} = 'Hdebugturn';
        }
    } elsif (List::MoreUtils::any {$_ eq "OwnerButton"} $params->keys) {
        $self->{main_mode} = 'owner';
    } elsif (List::MoreUtils::any {$_ eq "Sight"} $params->keys) {
        $self->{main_mode} = 'print';
        $self->{current_id} = $params->get("Sight");
    } elsif (List::MoreUtils::any {$_ eq "NewIslandButton"} $params->keys) {
        $self->{main_mode} = 'new';
    } elsif (List::MoreUtils::any {$_ =~ /LbbsButton(..)([0-9]*)/} $params->keys) {
        $self->{main_mode} = 'lbbs';
        my @tmp = grep {$_ =~ /^LbbsButton/} $params->keys;
        $tmp[0] =~ /LbbsButton(..)([0-9]*)/;
        if ($1 eq 'SS') {
            # 観光者
            $self->{local_bbs_mode} = 0;
        } elsif($1 eq 'OW') {
            # 島主
            $self->{local_bbs_mode} = 1;
        } else {
            # 削除
            $self->{local_bbs_mode} = 2;
        }
        $self->{current_id} = $2;

        # 削除かもしれないので、番号を取得
        $self->{command_plan_number} = $params->get("NUMBER");

    } elsif (List::MoreUtils::any {$_ eq "ChangeInfoButton"} $params->keys) {
        $self->{main_mode} = 'change';
    } elsif (List::MoreUtils::any {$_ =~ /MessageButton([0-9]*)/} $params->keys) {
        $self->{main_mode} = 'comment';
        $self->{current_id} = $1;
    } elsif (List::MoreUtils::any {$_ =~ /CommandButton/} $params->keys) {
        $self->{main_mode} = 'command';

        # コマンドモードの場合、コマンドの取得
        $self->{command_plan_number} = $params->get("NUMBER");
        $self->{command_kind} = $params->get("COMMAND");
        $self->{default_kind} = $params->get("COMMAND");
        $self->{command_arg} = $params->get("AMOUNT");
        $self->{command_target} = $params->get("TARGETID");
        $self->{default_target} = $params->get("TARGETID");
        $self->{command_x} = $params->get("POINTX");
        $self->{default_x} = $params->get("POINTX");
        $self->{command_y} = $params->get("POINTY");
        $self->{default_y} = $params->get("POINTY");
        $self->{command_mode} = $params->get("COMMANDMODE");
    } else {
        $self->{main_mode} = 'top';
    }
}

# 全島データ読みこみ
sub readIslandsFile {
    my ($self, $num) = @_; # 0だと地形読みこまず
                   # -1だと全地形を読む
                   # 番号だとその島の地形だけは読みこむ

    $self->{island_turn} = Hako::DB->get_global_value("turn"); # ターン数
    $self->{island_last_time} = Hako::DB->get_global_value("last_time"); # 最終更新時間
    $self->{island_number} = Hako::DB->get_global_value("number"); # 島の総数
    $self->{island_next_id} = Hako::DB->get_global_value("next_id"); # 次に割り当てるID

    # ターン処理判定
    my ($now) = time;
    if (((Hako::Config::DEBUG == 1) && ($self->{main_mode} eq 'Hdebugturn')) || (($now - $self->{island_last_time}) >= Hako::Config::UNIT_TIME)) {
        $self->{main_mode} = 'turn';
        $num = -1; # 全島読みこむ
    }

    # 島の読みこみ
    my $islands_from_db = Hako::DB->get_islands;
    for (my $i = 0; $i < $self->{island_number}; $i++) {
        push(@{$self->{islands}}, $self->readIsland($num, $islands_from_db));
        $self->{id_to_number}->{$self->{islands}->[$i]->{'id'}} = $i;
    }

    return 1;
}

# 島ひとつ読みこみ
sub readIsland {
    my ($self, $num, $islands_from_db) = @_;
    my $island_from_db = Hako::Model::Island->inflate(shift @$islands_from_db);

    my ($name, $id, $prize, $absent, $comment, $password, $money, $food, $pop, $area, $farm, $factory, $mountain, $score);
    $name = $island_from_db->{name}; # 島の名前
    $score = $island_from_db->{score};
    $id = $island_from_db->{id}; # ID番号
    $prize = $island_from_db->{prize}; # 受賞
    $absent = $island_from_db->{absent}; # 連続資金繰り数
    $comment = $island_from_db->{comment};
    $password = $island_from_db->{password};
    $money = $island_from_db->{money};  # 資金
    $food = $island_from_db->{food};  # 食料
    $pop = $island_from_db->{pop};  # 人口
    $area = $island_from_db->{area};  # 広さ
    $farm = $island_from_db->{farm};  # 農場
    $factory = $island_from_db->{factory};  # 工場
    $mountain = $island_from_db->{mountain}; # 採掘場

    # HidToNameテーブルへ保存
    $self->{id_to_name}->{$id} = $name;

    # 地形
    my (@land, @landValue, $line, @command, @lbbs);

    if (($num == -1) || ($num == $id)) {
        my @land_str = split(/\n/, $island_from_db->{map});
        for (my $y = 0; $y < Hako::Config::ISLAND_SIZE; $y++) {
            $line = $land_str[$y];
            for (my $x = 0; $x < Hako::Config::ISLAND_SIZE; $x++) {
                $line =~ s/^(.)(..)//;
                $land[$x][$y] = hex($1);
                $landValue[$x][$y] = hex($2);
            }
        }

        # コマンド
        my $commands_from_db = Hako::DB->get_commands($island_from_db->{id});
        @command = @$commands_from_db;

        # ローカル掲示板
        my $bbs_from_db = Hako::DB->get_bbs($island_from_db->{id});
        @lbbs = @$bbs_from_db;
    }

    # 島型にして返す
    return Hako::Model::Island->new({
        name      => $name,
        id        => $id,
        score     => $score,
        prize     => $prize,
        absent    => $absent,
        comment   => $comment,
        password  => $password,
        money     => $money,
        food      => $food,
        pop       => $pop,
        area      => $area,
        farm      => $farm,
        factory   => $factory,
        mountain  => $mountain,
        land      => \@land,
        landValue => \@landValue,
        command   => \@command,
        lbbs      => \@lbbs,
    });
}

# 標準出力への出力
sub out {
    my ($self, $v) = @_;
    $self->{out_buffer} .= sprintf("%s", Encode::encode("utf-8", $v));
}

# ヘッダ
sub tempHeader {
    my ($self) = @_;

    my $xslate = Text::Xslate->new(syntax => 'TTerse');
    my %vars = (
        title     => Hako::Config::TITLE,
        image_dir => mark_raw(Hako::Config::IMAGE_DIR),
        html_body => mark_raw(Hako::Config::HTML_BODY),
    );
    $self->out($xslate->render("tmpl/header.tt", \%vars));
}

# hakojima.datがない
sub tempNoDataFile {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}データファイルが開けません。@{[Hako::Config::_TAG_BIG]}@{[Hako::Config::TEMP_BACK]}
END
}

# フッタ
sub tempFooter {
    my ($self) = @_;
    my $xslate = Text::Xslate->new(syntax => 'TTerse');
    my %vars = (
        admin_name => Hako::Config::ADMIN_NAME,
        email      => Hako::Config::ADMIN_EMAIL,
        bbs        => Hako::Config::BBS_URL,
        toppage    => Hako::Config::TOPPAGE_URL,
    );
    $self->out($xslate->render("tmpl/footer.tt", \%vars));
}

# 初期化
sub tempInitialize {
    my ($self) = @_;
    # 島セレクト(デフォルト自分)
    $self->{island_list} = $self->getIslandList($self->{default_id});
    $self->{target_list} = $self->getIslandList($self->{default_target});
}

# 島データのプルダウンメニュー用
sub getIslandList {
    my ($self, $select) = @_;

    #島リストのメニュー
    my $list = "";
    for (my $i = 0; $i < $self->{island_number}; $i++) {
        my $name = $self->{islands}->[$i]->{'name'};
        my $id = $self->{islands}->[$i]->{'id'};
        my $s = $id eq $select ? "SELECTED" : "";
        $list .= "<OPTION VALUE=\"$id\" $s>${name}島\n";
    }
    return $list;
}

#cookie出力
sub cookieOutput {
    my ($self) = @_;
    # 消える期限の設定
    my ($sec, $min, $hour, $date, $mon, $year, $day, $yday, $dummy) = gmtime(time + 30 * 86400); # 現在 + 30日

    # 2ケタ化
    $year += 1900;
    if ($date < 10) { $date = "0$date"; }
    if ($hour < 10) { $hour = "0$hour"; }
    if ($min < 10) { $min  = "0$min"; }
    if ($sec < 10) { $sec  = "0$sec"; }

    # 曜日を文字に
    $day = ("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")[$day];

    # 月を文字に
    $mon = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")[$mon];

    # パスと期限のセット
    my $info = "; expires=$day, $date\-$mon\-$year $hour:$min:$sec GMT\n";

    if ($self->{current_id} && $self->{main_mode} eq 'owner'){
        $self->{cookie_buffer} .= "@{[Hako::Config::THIS_FILE]}OWNISLANDID=(@{[$self->{current_id}]}) $info";
    }
    if ($self->{input_password}) {
        $self->{cookie_buffer} .= "@{[Hako::Config::THIS_FILE]}OWNISLANDPASSWORD=(@{[$self->{input_password}]}) $info";
    }
    if ($self->{command_target}) {
        $self->{cookie_buffer} .= "@{[Hako::Config::THIS_FILE]}TARGETISLANDID=(@{[$self->{command_target}]}) $info";
    }
    if ($self->{local_bbs_name}) {
        $self->{cookie_buffer} .= "@{[Hako::Config::THIS_FILE]}LBBSNAME=(@{[$self->{local_bbs_name}]}) $info";
    }
    if ($self->{command_x}) {
        $self->{cookie_buffer} .= "@{[Hako::Config::THIS_FILE]}POINTX=(@{[$self->{command_x}]}) $info";
    }
    if ($self->{command_y}) {
        $self->{cookie_buffer} .= "@{[Hako::Config::THIS_FILE]}POINTY=(@{[$self->{command_y}]}) $info";
    }
    if ($self->{command_kind}) {
        # 自動系以外
        $self->{cookie_buffer} .= "@{[Hako::Config::THIS_FILE]}KIND=($self->{command_kind}) $info";
    }
}

# 全島データ書き込み
sub writeIslandsFile {
    my ($self, $num) = @_;

    Hako::DB->set_global_value("turn", $self->{island_turn});
    Hako::DB->set_global_value("last_time", $self->{island_last_time});
    Hako::DB->set_global_value("number", $self->{island_number});
    Hako::DB->set_global_value("next_id", $self->{island_next_id});

    # 島の書きこみ
    for (my $i = 0; $i < $self->{island_number}; $i++) {
        $self->writeIsland($self->{islands}[$i], $num, $i);
    }

    # DB用に放棄された島を消す
    my @dead_islands = grep {$_->{dead} == 1} @{$self->{islands}};
    for my $dead_island (@dead_islands) {
        Hako::DB->delete_island($dead_island->{id});
    }
}

# 島ひとつ書き込み
sub writeIsland {
    my ($self, $island, $num, $sort) = @_;
    # 地形
    if (($num <= -1) || ($num == $island->{'id'})) {
        my $land = $island->{land};
        my $landValue = $island->{'landValue'};
        my $land_str = "";
        for (my $y = 0; $y < Hako::Config::ISLAND_SIZE; $y++) {
            for (my $x = 0; $x < Hako::Config::ISLAND_SIZE; $x++) {
                $land_str .= sprintf("%x%02x", $land->[$x][$y], $landValue->[$x][$y]);
            }
            $land_str .= "\n";
        }
        $island->{map} = $land_str;
        Hako::DB->save_island($island, $sort);
    }
}

# トップページ
sub topPageMain {
    my ($self) = @_;

    # タイトル
    $self->out(<<END);
@{[Hako::Config::TAG_TITLE_]}@{[Hako::Config::TITLE]}@{[Hako::Config::_TAG_TITLE]}
END

    # デバッグモードなら「ターンを進める」ボタン
    if (Hako::Config::DEBUG == 1) {
        $self->out(<<END);
<FORM action="@{[Hako::Config::THIS_FILE]}" method="POST">
<INPUT TYPE="submit" VALUE="ターンを進める" NAME="TurnButton">
</FORM>
END
    }

    my $mStr1 = '';
    if (Hako::Config::HIDE_MONEY_MODE != 0) {
        $mStr1 = "<TH @{[Hako::Config::BG_TITLE_CELL]} align=center nowrap=nowrap><NOBR>".Hako::Template::Function->wrap_th("資金")."</NOBR></TH>";
    }

    # フォーム
    $self->out(<<END);
<H1>@{[Hako::Config::TAG_HEADER_]}ターン@{[$self->{island_turn}]}@{[Hako::Config::_TAG_HEADER]}</H1>

<HR>
<H1>@{[Hako::Config::TAG_HEADER_]}自分の島へ@{[Hako::Config::_TAG_HEADER]}</H1>
<FORM action="@{[Hako::Config::THIS_FILE]}" method="POST">
END
        $self->out(<<END);
あなたの島の名前は？<BR>
<SELECT NAME="ISLANDID">
@{[$self->{island_list}]}
</SELECT><BR>

パスワードをどうぞ！！<BR>
<INPUT TYPE="password" NAME="PASSWORD" VALUE="@{[$self->{default_password}]}" SIZE=32 MAXLENGTH=32><BR>
<INPUT TYPE="submit" VALUE="開発しに行く" NAME="OwnerButton"><BR>
</FORM>

<HR>

END
        $self->out(<<END);
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
<TH @{[Hako::Config::BG_TITLE_CELL]} align=center nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("採掘場規模")]}</NOBR></TH>
</TR>
END

    my $name;
    for (my $ii = 0; $ii < $self->{island_number}; $ii++) {
        my $j = $ii + 1;
        my $island = $self->{islands}->[$ii];

        my $id = $island->{'id'};
        my $farm = $island->{'farm'};
        my $factory = $island->{'factory'};
        my $mountain = $island->{'mountain'};
        $farm = ($farm == 0) ? "保有せず" : "${farm}0" . Hako::Config::UNIT_POPULATION;
        $factory = ($factory == 0) ? "保有せず" : "${factory}0" . Hako::Config::UNIT_POPULATION;
        $mountain = ($mountain == 0) ? "保有せず" : "${mountain}0" . Hako::Config::UNIT_POPULATION;
        if ($island->{'absent'}  == 0) {
            $name = "@{[Hako::Config::TAG_NAME_]}$island->{'name'}島@{[Hako::Config::_TAG_NAME]}";
        } else {
            $name = "@{[Hako::Config::TAG_NAME2_]}$island->{'name'}島($island->{'absent'})@{[Hako::Config::_TAG_NAME2]}";
        }

        my $prize = $island->{'prize'};
        $prize =~ /([0-9]*),([0-9]*),(.*)/;
        my $flags = $1;
        my $monsters= $2;
        my $turns = $3;
        $prize = '';

        # ターン杯の表示
        while ($turns =~ s/([0-9]*),//) {
            $prize .= "<IMG SRC=\"prize0.gif\" ALT=\"$1" . ${Hako::Config::PRIZE()}[0] . "\" WIDTH=16 HEIGHT=16> ";
        }

        # 名前に賞の文字を追加
        my $f = 1;
        for (my $i = 1; $i < 10; $i++) {
            if ($flags & $f) {
                $prize .= "<IMG SRC=\"prize${i}.gif\" ALT=\"" . ${Hako::Config::PRIZE()}[$i] . "\" WIDTH=16 HEIGHT=16> ";
            }
            $f *= 2;
        }

        # 倒した怪獣リスト
        $f = 1;
        my $max = -1;
        my $mNameList = '';
        for (my $i = 0; $i < Hako::Config::MONSTER_NUMBER; $i++) {
            if ($monsters & $f) {
                $mNameList .= "[" . ${Hako::Config::MONSTER_NAME()}[$i] . "] ";
                $max = $i;
            }
            $f *= 2;
        }
        if ($max != -1) {
            $prize .= "<IMG SRC=\"" . ${Hako::Config::MONSTER_IMAGE()}[$max] . "\" ALT=\"$mNameList\" WIDTH=16 HEIGHT=16> ";
        }


        my $mStr1 = '';
        if (Hako::Config::HIDE_MONEY_MODE == 1) {
            $mStr1 = "<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$island->{money}@{[Hako::Config::UNIT_MONEY]}</NOBR></TD>";
        } elsif (Hako::Config::HIDE_MONEY_MODE == 2) {
            my $mTmp = Hako::Util::aboutMoney($island->{'money'});
            $mStr1 = "<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$mTmp</NOBR></TD>";
        }

        $self->out(<<END);
<TR>
<TD @{[Hako::Config::BG_NUMBER_CELL]} ROWSPAN=2 align=center nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_number($j)]}</NOBR></TD>
<TD @{[Hako::Config::BG_NAME_CELL]} ROWSPAN=2 align=left nowrap=nowrap><NOBR><A STYlE=\"text-decoration:none\" HREF="@{[Hako::Config::THIS_FILE]}?Sight=${id}">$name</A></NOBR><BR>$prize</TD>
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

    $self->out(<<END);
</TABLE>

<HR>
<H1>@{[Hako::Config::TAG_HEADER_]}新しい島を探す@{[Hako::Config::_TAG_HEADER]}</H1>
END

    if ($self->{island_number} < Hako::Config::MAX_ISLAND) {
        $self->out(<<END);
<FORM action="@{[Hako::Config::THIS_FILE]}" method="POST">
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
        $self->out(<<END);
        島の数が最大数です・・・現在登録できません。
END
    }

    $self->out(<<END);
<HR>
<H1>@{[Hako::Config::TAG_HEADER_]}島の名前とパスワードの変更@{[Hako::Config::_TAG_HEADER]}</H1>
<P>
(注意)名前の変更には@{[Hako::Config::CHANGE_NAME_COST]}@{[Hako::Config::UNIT_MONEY]}かかります。
</P>
<FORM action="@{[Hako::Config::THIS_FILE]}" method="POST">
どの島ですか？<BR>
<SELECT NAME="ISLANDID">
@{[$self->{island_list}]}
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
    $self->logPrintTop();
    $self->out(<<END);
<H1>@{[Hako::Config::TAG_HEADER_]}発見の記録@{[Hako::Config::_TAG_HEADER]}</H1>
END
    $self->historyPrint();
}

# トップページ用ログ表示
sub logPrintTop {
    my ($self) = @_;
    my $logs = Hako::DB->get_common_log($self->{island_turn});

    for (@$logs) {
        $self->out("<NOBR>".Hako::Template::Function->wrap_number("ターン".$_->{turn})."：@{[$_->{message}]}</NOBR><BR>\n");
    }
}

# 記録ファイル表示
sub historyPrint {
    my ($self) = @_;
    my $histories = Hako::DB->get_history();
    for my $line (@$histories) {
        my $msg = $line->{message};
        $self->out("<NOBR>".Hako::Template::Function->wrap_number("ターン".$line->{turn})."：@{[$msg]}</NOBR><BR>\n");
    }
}

# 島がいっぱいな場合
sub tempNewIslandFull {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}申し訳ありません、島が一杯で登録できません！！@{[Hako::Config::_TAG_BIG]}@{[Hako::Config::TEMP_BACK]}
END
}

# 新規で名前がない場合
sub tempNewIslandNoName {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}島につける名前が必要です。@{[Hako::Config::_TAG_BIG]}@{[Hako::Config::TEMP_BACK]}
END
}

# 新規で名前が不正な場合
sub tempNewIslandBadName {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}',?()<>\$'とか入ってたり、「無人島」とかいった変な名前はやめましょうよ〜@{[Hako::Config::_TAG_BIG]}@{[Hako::Config::TEMP_BACK]}
END
}

# すでにその名前の島がある場合
sub tempNewIslandAlready {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}その島ならすでに発見されています。@{[Hako::Config::_TAG_BIG]}@{[Hako::Config::TEMP_BACK]}
END
}

# パスワードがない場合
sub tempNewIslandNoPassword {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}パスワードが必要です。@{[Hako::Config::_TAG_BIG]}@{[Hako::Config::TEMP_BACK]}
END
}

# パスワード間違い
sub tempWrongPassword {
    my ($self) = @_;
    $self->out(<<END);
    @{[Hako::Config::TAG_BIG_]}パスワードが違います。@{[Hako::Config::_TAG_BIG]}@{[Hako::Config::TEMP_BACK]}
END
}

# 島を発見しました!!
sub tempNewIslandHead {
    my ($self, $current_name) = @_;
    $self->out(<<END);
<CENTER>
@{[Hako::Config::TAG_BIG_]}島を発見しました！！@{[Hako::Config::_TAG_BIG]}<BR>
@{[Hako::Config::TAG_BIG_]}@{[Hako::Config::TAG_NAME_]}「${current_name}島」@{[Hako::Config::_TAG_NAME]}と命名します。@{[Hako::Config::_TAG_BIG]}<BR>
@{[Hako::Config::TEMP_BACK]}<BR>
</CENTER>
END
}

sub tempProblem {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}問題発生、とりあえず戻ってください。@{[Hako::Config::_TAG_BIG]}@{[Hako::Config::TEMP_BACK]}
END
}

# 島の名前から番号を得る(IDじゃなくて番号)
sub nameToNumber {
    my ($self, $name) = @_;

    # 全島から探す
    for (my $i = 0; $i < $self->{island_number}; $i++) {
        if($self->{islands}->[$i]->{'name'} eq $name) {
            return $i;
        }
    }

    # 見つからなかった場合
    return -1;
}

# 情報の表示
sub islandInfo {
    my ($self) = @_;
    my $island = $self->{islands}->[$self->{current_number}];
    # 情報表示
    my $rank = $self->{current_number} + 1;
    my $farm = $island->{'farm'};
    my $factory = $island->{'factory'};
    my $mountain = $island->{'mountain'};
    $farm = ($farm == 0) ? "保有せず" : "${farm}0" . Hako::Config::UNIT_POPULATION;
    $factory = ($factory == 0) ? "保有せず" : "${factory}0" . Hako::Config::UNIT_POPULATION;
    $mountain = ($mountain == 0) ? "保有せず" : "${mountain}0" . Hako::Config::UNIT_POPULATION;

    my $mStr1 = '';
    my $mStr2 = '';
    if((Hako::Config::HIDE_MONEY_MODE == 1) || ($self->{main_mode} eq 'owner')) {
        # 無条件またはownerモード
        $mStr1 = "<TH @{[Hako::Config::BG_TITLE_CELL]} nowrap=nowrap><NOBR>".Hako::Template::Function->wrap_th("資金")."</NOBR></TH>";
        $mStr2 = "<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$island->{money}@{[Hako::Config::UNIT_MONEY]}</NOBR></TD>";
    } elsif(Hako::Config::HIDE_MONEY_MODE == 2) {
        my $mTmp = aboutMoney($island->{'money'});

        # 1000億単位モード
        $mStr1 = "<TH @{[Hako::Config::BG_TITLE_CELL]} nowrap=nowrap><NOBR>".Hako::Template::Function->wrap_th("資金")."</NOBR></TH>";
        $mStr2 = "<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$mTmp</NOBR></TD>";
    }
    $self->out(<<END);
<CENTER>
<TABLE BORDER>
<TR>
<TH @{[Hako::Config::BG_TITLE_CELL]} nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("順位")]}</NOBR></TH>
<TH @{[Hako::Config::BG_TITLE_CELL]} nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("人口")]}</NOBR></TH>
$mStr1
<TH @{[Hako::Config::BG_TITLE_CELL]} nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("食料")]}</NOBR></TH>
<TH @{[Hako::Config::BG_TITLE_CELL]} nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("面積")]}</NOBR></TH>
<TH @{[Hako::Config::BG_TITLE_CELL]} nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("農場規模")]}</NOBR></TH>
<TH @{[Hako::Config::BG_TITLE_CELL]} nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("工場規模")]}</NOBR></TH>
<TH @{[Hako::Config::BG_TITLE_CELL]} nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_th("採掘場規模")]}</NOBR></TH>
</TR>
<TR>
<TD @{[Hako::Config::BG_NUMBER_CELL]} align=middle nowrap=nowrap><NOBR>@{[Hako::Template::Function->wrap_number($rank)]}</NOBR></TD>
<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$island->{'pop'}@{[Hako::Config::UNIT_POPULATION]}</NOBR></TD>
$mStr2
<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$island->{'food'}@{[Hako::Config::UNIT_FOOD]}</NOBR></TD>
<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>$island->{'area'}@{[Hako::Config::UNIT_AREA]}</NOBR></TD>
<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>${farm}</NOBR></TD>
<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>${factory}</NOBR></TD>
<TD @{[Hako::Config::BG_INFO_CELL]} align=right nowrap=nowrap><NOBR>${mountain}</NOBR></TD>
</TR>
</TABLE></CENTER>
END
}

# 地図の表示
# 引数が1なら、ミサイル基地等をそのまま表示
sub islandMap {
    my ($self, $mode) = @_;
    my $island = $self->{islands}->[$self->{current_number}];

    $self->out(<<END);
<CENTER><TABLE BORDER><TR><TD>
END
    # 地形、地形値を取得
    my $land = $island->{'land'};
    my $landValue = $island->{'landValue'};
    my ($l, $lv);

    # コマンド取得
    my $command = $island->{'command'};
    my @comStr;
    if($self->{main_mode} eq 'owner') {
        for (my $i = 0; $i < Hako::Config::COMMAND_MAX; $i++) {
            my $j = $i + 1;
            my $com = $command->[$i];
            if($com->{'kind'} < 20) {
                $comStr[$com->{'x'}][$com->{'y'}] .= " [${j}]" . Hako::Command->id_to_name($com->{'kind'});
            }
        }
    }

    # 座標(上)を出力
    $self->out("<IMG SRC=\"xbar.gif\" width=400 height=16><BR>");

    # 各地形および改行を出力
    for (my $y = 0; $y < Hako::Config::ISLAND_SIZE; $y++) {
        # 偶数行目なら番号を出力
        if (($y % 2) == 0) {
            $self->out("<IMG SRC=\"space${y}.gif\" width=16 height=32>");
        }

        # 各地形を出力
        for (my $x = 0; $x < Hako::Config::ISLAND_SIZE; $x++) {
            my $l = $land->[$x][$y];
            my $lv = $landValue->[$x][$y];
            $self->landString($l, $lv, $x, $y, $mode, $comStr[$x][$y]);
        }

        # 奇数行目なら番号を出力
        if (($y % 2) == 1) {
            $self->out("<IMG SRC=\"space${y}.gif\" width=16 height=32>");
        }

        # 改行を出力
        $self->out("<BR>");
    }
    $self->out("</TD></TR></TABLE></CENTER>\n");
}

sub landString {
    my ($self, $l, $lv, $x, $y, $mode, $comStr) = @_;
    my $point = "($x,$y)";
    my ($image, $alt);

    if ($l == Hako::Constants::LAND_SEA) {
        if ($lv == 1) {
            # 浅瀬
            $image = 'land14.gif';
            $alt = '海(浅瀬)';
        } else {
            # 海
            $image = 'land0.gif';
            $alt = '海';
        }
    } elsif ($l == Hako::Constants::LAND_WASTE) {
        # 荒地
        if ($lv == 1) {
            $image = 'land13.gif'; # 着弾点
            $alt = '荒地';
        } else {
            $image = 'land1.gif';
            $alt = '荒地';
        }
    } elsif ($l == Hako::Constants::LAND_PLAINS) {
        # 平地
        $image = 'land2.gif';
        $alt = '平地';
    } elsif ($l == Hako::Constants::LAND_FOREST) {
        # 森
        if ($mode == 1) {
            $image = 'land6.gif';
            $alt = "森(${lv}@{[Hako::Config::UNIT_TREE]})";
        } else {
            # 観光者の場合は木の本数隠す
            $image = 'land6.gif';
            $alt = '森';
        }
    } elsif ($l == Hako::Constants::LAND_TOWN) {
        # 町
        my ($p, $n);
        if ($lv < 30) {
            $p = 3;
            $n = '村';
        } elsif ($lv < 100) {
            $p = 4;
            $n = '町';
        } else {
            $p = 5;
            $n = '都市';
        }

        $image = "land${p}.gif";
        $alt = "$n(${lv}@{[Hako::Config::UNIT_POPULATION]})";
    } elsif ($l == Hako::Constants::LAND_FARM) {
        # 農場
        $image = 'land7.gif';
        $alt = "農場(${lv}0@{[Hako::Config::UNIT_POPULATION]}規模)";
    } elsif ($l == Hako::Constants::LAND_FACTORY) {
        # 工場
        $image = 'land8.gif';
        $alt = "工場(${lv}0@{[Hako::Config::UNIT_POPULATION]}規模)";
    } elsif ($l == Hako::Constants::LAND_BASE) {
        if ($mode == 0) {
            # 観光者の場合は森のふり
            $image = 'land6.gif';
            $alt = '森';
        } else {
            # ミサイル基地
            my $level = Hako::Util::expToLevel($l, $lv);
            $image = 'land9.gif';
            $alt = "ミサイル基地 (レベル ${level}/経験値 $lv)";
        }
    } elsif ($l == Hako::Constants::LAND_SEA_BASE) {
        # 海底基地
        if ($mode == 0) {
            # 観光者の場合は海のふり
            $image = 'land0.gif';
            $alt = '海';
        } else {
            my $level = Hako::Util::expToLevel($l, $lv);
            $image = 'land12.gif';
            $alt = "海底基地 (レベル ${level}/経験値 $lv)";
        }
    } elsif ($l == Hako::Constants::LAND_DEFENCE) {
        # 防衛施設
        $image = 'land10.gif';
        $alt = '防衛施設';
    } elsif ($l == Hako::Constants::LAND_HARIBOTE) {
        # ハリボテ
        $image = 'land10.gif';
        if ($mode == 0) {
            # 観光者の場合は防衛施設のふり
            $alt = '防衛施設';
        } else {
            $alt = 'ハリボテ';
        }
    } elsif ($l == Hako::Constants::LAND_OIL) {
        # 海底油田
        $image = 'land16.gif';
        $alt = '海底油田';
    } elsif ($l == Hako::Constants::LAND_MOUNTAIN) {
        # 山
        my $str = '';
        if ($lv > 0) {
            $image = 'land15.gif';
            $alt = "山(採掘場${lv}0@{[Hako::Config::UNIT_POPULATION]}規模)";
        } else {
            $image = 'land11.gif';
            $alt = '山';
        }
    } elsif ($l == Hako::Constants::LAND_MONUMENT) {
        # 記念碑
        $image = ${Hako::Config::MONUMENT_IMAGE()}[$lv];
        $alt = ${Hako::Config::MONUMEBT_NAME()}[$lv];
    } elsif ($l == Hako::Constants::LAND_MONSTER) {
        # 怪獣
        my ($kind, $name, $hp) = Hako::Mode::monsterSpec($lv);
        my $special = ${Hako::Config::MONSTER_SPECIAL()}[$kind];
        $image = ${Hako::Config::MONSTER_IMAGE()}[$kind];

        # 硬化中?
        if ((($special == 3) && (($self->{island_turn} % 2) == 1)) ||
            (($special == 4) && (($self->{island_turn} % 2) == 0))) {
            # 硬化中
            $image = ${Hako::Config::MONSTER_IMAGE2()}[$kind];
        }
        $alt = "怪獣$name(体力${hp})";
    }


    # 開発画面の場合は、座標設定
    if ($mode == 1) {
        $self->out("<A HREF=\"JavaScript:void(0);\" onclick=\"ps($x,$y)\">");
    }

    $self->out("<IMG SRC=\"$image\" ALT=\"$point $alt $comStr\" width=32 height=32 BORDER=0>");

    # 座標設定閉じ
    if ($mode == 1) {
        $self->out("</A>");
    }
}

# ○○島へようこそ！！
sub tempPrintIslandHead {
    my ($self, $current_name) = @_;
    $self->out(<<END);
<CENTER>
@{[Hako::Config::TAG_BIG_]}@{[Hako::Config::TAG_NAME_]}「${current_name}島」@{[Hako::Config::_TAG_NAME]}へようこそ！！@{[Hako::Config::_TAG_BIG]}<BR>
@{[Hako::Config::TEMP_BACK]}<BR>
</CENTER>
END
}

# ローカル掲示板
sub tempLbbsHead {
    my ($self, $current_name) = @_;
    $self->out(<<END);
<HR>
<CENTER>
@{[Hako::Config::TAG_BIG_]}@{[Hako::Config::TAG_NAME_]}${current_name}島@{[Hako::Config::_TAG_NAME]}観光者通信@{[Hako::Config::_TAG_BIG]}<BR>
</CENTER>
END
}

# ローカル掲示板入力フォーム
sub tempLbbsInput {
    my ($self) = @_;
    $self->out(<<END);
<CENTER>
<FORM action="@{[Hako::Config::THIS_FILE]}" method="POST">
<TABLE BORDER>
<TR>
<TH>名前</TH>
<TH>内容</TH>
<TH>動作</TH>
</TR>
<TR>
<TD><INPUT TYPE="text" SIZE=32 MAXLENGTH=32 NAME="LBBSNAME" VALUE="@{[$self->{default_name}]}"></TD>
<TD><INPUT TYPE="text" SIZE=80 NAME="LBBSMESSAGE"></TD>
<TD><INPUT TYPE="submit" VALUE="記帳する" NAME="LbbsButtonSS@{[$self->{current_id}]}"></TD>
</TR>
</TABLE>
</FORM>
</CENTER>
END
}

# ローカル掲示板内容
sub tempLbbsContents {
    my ($self) = @_;
    my $lbbs = $self->{islands}[$self->{current_number}]->{'lbbs'};
    $self->out(<<END);
<CENTER>
<TABLE BORDER>
<TR>
<TH>番号</TH>
<TH>記帳内容</TH>
</TR>
END

    for (my $i = 0; $i < Hako::Config::LOCAL_BBS_MAX; $i++) {
        my $line = $lbbs->[$i];
        if ($line =~ /([0-9]*)\>(.*)\>(.*)$/) {
            my $j = $i + 1;
            $self->out("<TR><TD align=center>@{[Hako::Template::Function->wrap_number($j)]}</TD>");
            if ($1 == 0) {
                # 観光者
                $self->out("<TD>".Hako::Template::Function->wrap_local_bbs_ss($2." > ".$3)."</TD></TR>");
            } else {
                # 島主
                $self->out("<TD>".Hako::Template::Function->wrap_local_bbs_ow($2." > ".$3)."</TD></TR>");
            }
        }
    }

    $self->out(<<END);
</TD></TR></TABLE></CENTER>
END
}

# 近況
sub tempRecent {
    my ($self, $mode) = @_;
    $self->out(<<END);
<HR>
@{[Hako::Config::TAG_BIG_]}@{[Hako::Config::TAG_NAME_]}@{[$self->{current_name}]}島@{[Hako::Config::_TAG_NAME]}の近況@{[Hako::Config::_TAG_BIG]}<BR>
END
    $self->logPrintLocal($mode);
}

# 個別ログ表示
sub logPrintLocal {
    my ($self, $mode) = @_;

    my $logs = Hako::DB->get_log($self->{current_id}, $self->{island_turn});
    my (@secrets, @lates, @normals);
    for my $log (@$logs) {
        if ($log->{log_type} == 3) {
            push @secrets, $log;
        } elsif ($log->{log_type} == 2) {
            push @lates, $log;
        } elsif ($log->{log_type} == 1) {
            push @normals, $log;
        }
    }
    if ($mode == 1) {
        for (@secrets) {
            $self->out("<NOBR>".Hako::Template::Function->wrap_number("ターン".$_->{turn}."<B>(機密)</B>")."：@{[$_->{message}]}</NOBR><BR>\n");
        }
    }
    for (@lates) {
        $self->out("<NOBR>".Hako::Template::Function->wrap_number("ターン".$_->{turn})."：@{[$_->{message}]}</NOBR><BR>\n");
    }
    for (@normals) {
        $self->out("<NOBR>".Hako::Template::Function->wrap_number("ターン".$_->{turn})."：@{[$_->{message}]}</NOBR><BR>\n");
    }
}

# ○○島開発計画
sub tempOwner {
    my ($self) = @_;

    $self->out(<<END);
<CENTER>
@{[Hako::Config::TAG_BIG_]}@{[Hako::Config::TAG_NAME_]}@{[$self->{current_name}]}島@{[Hako::Config::_TAG_NAME]}開発計画@{[Hako::Config::_TAG_BIG]}<BR>
@{[Hako::Config::TEMP_BACK]}<BR>
</CENTER>
<SCRIPT Language="JavaScript">
<!--
function ps(x, y) {
    document.forms[0].elements[4].options[x].selected = true;
    document.forms[0].elements[5].options[y].selected = true;
    return true;
}

function ns(x) {
    document.forms[0].elements[2].options[x].selected = true;
    return true;
}

//-->
</SCRIPT>
END

    $self->islandInfo;

    my $current_id = $self->{islands}->[$self->{current_number}]->{id};
    $self->out(<<END);
<CENTER>
<TABLE BORDER>
<TR>
<TD @{[Hako::Config::BG_INPUT_CELL]} >
<CENTER>
<FORM action="@{[Hako::Config::THIS_FILE]}" method=POST>
<INPUT TYPE=submit VALUE="計画送信" NAME=CommandButton$current_id>
<HR>
<B>パスワード</B></BR>
<INPUT TYPE=password NAME=PASSWORD VALUE="@{[$self->{default_password}]}">
<HR>
<B>計画番号</B><SELECT NAME=NUMBER>
END
    # 計画番号
    for (my $i = 0; $i < Hako::Config::COMMAND_MAX; $i++) {
        my $j = $i + 1;
        $self->out("<OPTION VALUE=$i>$j\n");
    }

    $self->out(<<END);
</SELECT><BR>
<HR>
<B>開発計画</B><BR>
<SELECT NAME=COMMAND>
END

    #コマンド
    for (my $i = 0; $i < Hako::Constants::COMMAND_TOTAL_NUM; $i++) {
        my $kind = ${Hako::Constants::COM_LIST()}[$i];
        my $cost = Hako::Command->id_to_cost($kind);
        my $s;
        if ($cost == 0) {
            $cost = '無料'
        } elsif($cost < 0) {
            $cost = - $cost;
            $cost .= Hako::Config::UNIT_FOOD;
        } else {
            $cost .= Hako::Config::UNIT_MONEY;
        }
        if ($kind == $self->{default_kind}) {
            $s = 'SELECTED';
        } else {
            $s = '';
        }
        my $name = Hako::Command->id_to_name("$kind");
        $self->out("<OPTION VALUE=$kind $s>".$name."($cost)\n");
    }

    $self->out(<<END);
</SELECT>
<HR>
<B>座標(</B>
<SELECT NAME=POINTX>

END
    for (my $i = 0; $i < Hako::Config::ISLAND_SIZE; $i++) {
        if ($i == $self->{default_x}) {
            $self->out("<OPTION VALUE=$i SELECTED>$i\n");
        } else {
            $self->out("<OPTION VALUE=$i>$i\n");
        }
    }

    $self->out(<<END);
</SELECT>, <SELECT NAME=POINTY>
END

    for (my $i = 0; $i < Hako::Config::ISLAND_SIZE; $i++) {
        if($i == $self->{default_y}) {
            $self->out("<OPTION VALUE=$i SELECTED>$i\n");
        } else {
            $self->out("<OPTION VALUE=$i>$i\n");
        }
    }
    $self->out(<<END);
</SELECT><B>)</B>
<HR>
<B>数量</B><SELECT NAME=AMOUNT>
END

    # 数量
    for (my $i = 0; $i < 100; $i++) {
        $self->out("<OPTION VALUE=$i>$i\n");
    }

    $self->out(<<END);
</SELECT>
<HR>
<B>目標の島</B><BR>
<SELECT NAME=TARGETID>
@{[$self->{target_list}]}<BR>
</SELECT>
<HR>
<B>動作</B><BR>
<INPUT TYPE=radio NAME=COMMANDMODE VALUE=insert CHECKED>挿入
<INPUT TYPE=radio NAME=COMMANDMODE VALUE=write>上書き<BR>
<INPUT TYPE=radio NAME=COMMANDMODE VALUE=delete>削除
<HR>
<INPUT TYPE=submit VALUE="計画送信" NAME=CommandButton$current_id>

</CENTER>
</FORM>
</TD>
<TD @{[Hako::Config::BG_MAP_CELL]}>
END
    $self->islandMap(1);    # 島の地図、所有者モード
    $self->out(<<END);
</TD>
<TD @{[Hako::Config::BG_COMMAND_CELL]}>
END
    for (my $i = 0; $i < Hako::Config::COMMAND_MAX; $i++) {
        $self->tempCommand($i, $self->{islands}->[$self->{current_number}]->{'command'}->[$i]);
    }

    $self->out(<<END);

</TD>
</TR>
</TABLE>
</CENTER>
<HR>
<CENTER>
@{[Hako::Config::TAG_BIG_]}コメント更新@{[Hako::Config::_TAG_BIG]}<BR>
<FORM action="@{[Hako::Config::THIS_FILE]}" method="POST">
コメント<INPUT TYPE=text NAME=MESSAGE SIZE=80><BR>
パスワード<INPUT TYPE=password NAME=PASSWORD VALUE="@{[$self->{default_password}]}">
<INPUT TYPE=submit VALUE="コメント更新" NAME=MessageButton$current_id>
</FORM>
</CENTER>
END
}

# 入力済みコマンド表示
sub tempCommand {
    my ($self, $number, $command) = @_;
    my($kind, $target, $x, $y, $arg) = (
        $command->{'kind'},
        $command->{'target'},
        $command->{'x'},
        $command->{'y'},
        $command->{'arg'}
    );
    my $name = Hako::Config::TAG_COM_NAME_ . Hako::Command->id_to_name($kind) . Hako::Config::_TAG_COM_NAME;
    my $point = Hako::Config::TAG_NAME_ . "($x,$y)" . Hako::Config::_TAG_NAME;
    $target = $self->{id_to_name}->{$target};
    if ($target eq '') {
        $target = "無人";
    }
    $target = Hako::Config::TAG_NAME_ . "${target}島" . Hako::Config::_TAG_NAME;
    my $value = $arg * Hako::Command->id_to_cost($kind);
    if ($value == 0) {
        $value = Hako::Command->id_to_cost($kind);
    }
    if ($value < 0) {
        $value = -$value;
        $value = "$value" . Hako::Config::UNIT_FOOD;
    } else {
        $value = "$value" . Hako::Config::UNIT_MONEY;
    }
    $value = Hako::Template::Function->wrap_name($value);

    my $j = sprintf("%02d：", $number + 1);

    $self->out("<A STYlE=\"text-decoration:none\" HREF=\"JavaScript:void(0);\" onClick=\"ns($number)\"><NOBR>@{[Hako::Template::Function->wrap_number($j)]}<FONT COLOR=\"@{[Hako::Config::NORMAL_COLOR]}\">");

    if (($kind == Hako::Constants::COMMAND_DO_NOTHING) || ($kind == Hako::Constants::COMMAND_GIVE_UP)) {
        $self->out("@{[$name]}");
    } elsif (($kind == Hako::Constants::COMMAND_MISSILE_NM) || ($kind == Hako::Constants::COMMAND_MISSILE_PP) || ($kind == Hako::Constants::COMMAND_MISSILE_ST) || ($kind == Hako::Constants::COMMAND_MISSILE_LD)) {
        # ミサイル系
        my $n = ($arg == 0 ? '無制限' : "${arg}発");
        $self->out("@{[$target]}@{[$point]}へ@{[$name]}(@{[Hako::Config::TAG_NAME_]}@{[$n]}@{[Hako::Config::_TAG_NAME]})");
    } elsif ($kind == Hako::Constants::COMMAND_SEND_MONSTER) {
        # 怪獣派遣
        $self->out("@{[$target]}へ@{[$name]}");
    } elsif ($kind == Hako::Constants::COMMAND_SELL) {
        # 食料輸出
        $self->out("@{[$name]}@{[$value]}");
    } elsif ($kind == Hako::Constants::COMMAND_PROPAGANDA) {
        # 誘致活動
        $self->out("@{[$name]}");
    } elsif (($kind == Hako::Constants::COMMAND_MONEY) || ($kind == Hako::Constants::COMMAND_MONEY)) {
        # 援助
        $self->out("@{[$target]}へ@{[$name]}@{[$value]}");
    } elsif ($kind == Hako::Constants::COMMAND_DESTROY) {
        # 掘削
        if ($arg != 0) {
            $self->out("@{[$point]}で@{[$name]}(予算@{[$value]})");
        } else {
            $self->out("@{[$point]}で@{[$name]}");
        }
    } elsif (($kind == Hako::Constants::COMMAND_FARM) || ($kind == Hako::Constants::COMMAND_FACTORY) || ($kind == Hako::Constants::COMMAND_MOUNTAIN)) {
        # 回数付き
        if ($arg == 0) {
            $self->out("@{[$point]}で@{[$name]}");
        } else {
            $self->out("@{[$point]}で@{[$name]}(@{[$arg]}回)");
        }
    } else {
        # 座標付き
        $self->out("@{[$point]}で@{[$name]}");
    }

    $self->out("</FONT></NOBR></A><BR>");
}

# ローカル掲示板入力フォーム owner mode用
sub tempLbbsInputOW {
    my ($self) = @_;
    $self->out(<<END);
<CENTER>
<FORM action="@{[Hako::Config::THIS_FILE]}" method="POST">
<TABLE BORDER>
<TR>
<TH>名前</TH>
<TH COLSPAN=2>内容</TH>
</TR>
<TR>
<TD><INPUT TYPE="text" SIZE=32 MAXLENGTH=32 NAME="LBBSNAME" VALUE="@{[$self->{default_name}]}"></TD>
<TD COLSPAN=2><INPUT TYPE="text" SIZE=80 NAME="LBBSMESSAGE"></TD>
</TR>
<TR>
<TH>パスワード</TH>
<TH COLSPAN=2>動作</TH>
</TR>
<TR>
<TD><INPUT TYPE=password SIZE=32 MAXLENGTH=32 NAME=PASSWORD VALUE="@{[$self->{default_password}]}"></TD>
<TD align=right>
<INPUT TYPE="submit" VALUE="記帳する" NAME="LbbsButtonOW@{[$self->{current_id}]}">
</TD>
<TD align=right>
番号
<SELECT NAME=NUMBER>
END
    # 発言番号
    for (my $i = 0; $i < Hako::Config::LOCAL_BBS_MAX; $i++) {
        my $j = $i + 1;
        $self->out("<OPTION VALUE=$i>$j\n");
    }
    $self->out(<<END);
</SELECT>
<INPUT TYPE="submit" VALUE="削除する" NAME="LbbsButtonDL@{[$self->{current_id}]}">
</TD>
</TR>
</TABLE>
</FORM>
</CENTER>
END
}

# コマンド削除
sub tempCommandDelete {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}コマンドを削除しました@{[Hako::Config::_TAG_BIG]}<HR>
END
}

# コマンド登録
sub tempCommandAdd {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}コマンドを登録しました@{[Hako::Config::_TAG_BIG]}<HR>
END
}

# コメント変更成功
sub tempComment {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}コメントを更新しました@{[Hako::Config::_TAG_BIG]}<HR>
END
}

# ローカル掲示板で名前かメッセージがない場合
sub tempLbbsNoMessage {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}名前または内容の欄が空欄です。@{[Hako::Config::_TAG_BIG]}@{[Hako::Config::TEMP_BACK]}
END
}

# 書きこみ削除
sub tempLbbsDelete {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}記帳内容を削除しました@{[Hako::Config::_TAG_BIG]}<HR>
END
}

# コマンド登録
sub tempLbbsAdd {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}記帳を行いました@{[Hako::Config::_TAG_BIG]}<HR>
END
}

# 名前変更資金足りず
sub tempChangeNoMoney {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}資金不足のため変更できません@{[Hako::Config::_TAG_BIG]}@{[Hako::Config::TEMP_BACK]}
END
}

# 名前変更失敗
sub tempChangeNothing {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}名前、パスワードともに空欄です@{[Hako::Config::_TAG_BIG]}@{[Hako::Config::TEMP_BACK]}
END
}

# 名前変更成功
sub tempChange {
    my ($self) = @_;
    $self->out(<<END);
@{[Hako::Config::TAG_BIG_]}変更完了しました@{[Hako::Config::_TAG_BIG]}@{[Hako::Config::TEMP_BACK]}
END
}
1;
