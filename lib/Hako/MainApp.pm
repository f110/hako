package Hako::MainApp;
use utf8;
use strict;
use warnings;
use feature ":5.10";
use Encode qw();
use YAML ();
use File::Spec;
use File::Basename;
use Plack::Response;
use Plack::Request;
use List::MoreUtils qw();
use Text::Xslate qw(mark_raw);
use Hash::Merge qw();
use Hako::Config;
use Hako::Constants;
use Hako::DB;
use Hako::Model::Island;
use Hako::Model::Command;
use Hako::Util;
use Hako::Mode;
use Hako::Template::Function;
use Hako::Exception;
use Hako::Context::Game;
use Devel::Peek;
use Hako::Accessor::Islands;

sub new {
    my ($class) = @_;

    return bless {
        xslate => Text::Xslate->new(
            syntax => 'TTerse',
            function => {
                to_human => \&Hako::Template::Function::to_human,
            },
            module => ['Text::Xslate::Bridge::Star'],
        )
    }, $class;
}

sub render {
    my ($self, $template, $opt) = @_;

    $opt->{layout} ||= "base";
    $self->{vars}->{body_file} = "tmpl/".$template.".tt";

    return $self->{xslate}->render("tmpl/layout/".$opt->{layout}.".tt", $self->{vars});
}

sub initialize {
    my ($self) = @_;

    $self->{vars} = {};

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
    $self->{islands} = [];
    $self->{id_to_number} = {};
    $self->{id_to_name} = {};
    $self->{island_list} = "";
    $self->{target_list} = "";
    $self->{defence_hex} = []; # landをパースするときにちゃんと入れないと機能しなさそう

    $self->{context} = Hako::Context::Game->new;
    $self->{accessor} = Hako::Accessor::Islands->new;
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

        # COOKIE出力
        $self->cookieOutput;

        my $template;
        eval {
            # テンプレートを初期化
            $self->tempInitialize;

            if ($self->{main_mode} eq 'new') {
                # 島の新規作成
                Hako::Mode->newIslandMain($self);

                $self->tempNewIslandHead($self->{current_name}); # 発見しました!!
                $self->islandInfo; # 島の情報
                $self->islandMap(1); # 島の地図、ownerモード
                $template = "new";
            } elsif ($self->{main_mode} eq 'print') {
                # 観光モード
                Hako::Mode->printIslandMain($self);
                # 観光画面
                $self->tempPrintIslandHead($self->{current_name}); # ようこそ!!
                $self->islandInfo; # 島の情報
                $self->islandMap(0); # 島の地図、観光モード

                # ○○島ローカル掲示板
                if (Hako::Config::USE_LOCAL_BBS) {
                    $self->tempLbbsHead($self->{current_name});     # ローカル掲示板
                    $self->tempLbbsInput;   # 書き込みフォーム
                    $self->tempLbbsContents; # 掲示板内容
                }

                # 近況
                $self->tempRecent(0);
                $template = "sight";
            } elsif ($self->{main_mode} eq 'owner') {
                # 開発モード
                Hako::Mode->ownerMain($self);

                # 開発画面
                $self->tempOwner; # 「開発計画」
                $self->islandInfo;
                $self->tempCommandForm;
                $self->islandMap(1);
                $self->tempOwnerEnd;

                # ○○島ローカル掲示板
                if (Hako::Config::USE_LOCAL_BBS) {
                    $self->tempLbbsHead($self->{current_name});     # ローカル掲示板
                    $self->tempLbbsInputOW;   # 書き込みフォーム
                    $self->tempLbbsContents; # 掲示板内容
                }

                # 近況
                $self->tempRecent(1);
                $template = "owner";
            } elsif ($self->{main_mode} eq 'command') {
                # コマンド入力モード
                Hako::Mode->commandMain($self);

                # 開発画面
                $self->tempOwner; # 「開発計画」
                $self->islandInfo;
                $self->tempCommandForm;
                $self->islandMap(1);
                $self->tempOwnerEnd;

                # ○○島ローカル掲示板
                if (Hako::Config::USE_LOCAL_BBS) {
                    $self->tempLbbsHead($self->{current_name});     # ローカル掲示板
                    $self->tempLbbsInputOW;   # 書き込みフォーム
                    $self->tempLbbsContents; # 掲示板内容
                }

                # 近況
                $self->tempRecent(1);
                $template = "command";
            } elsif ($self->{main_mode} eq 'comment') {
                # コメント入力モード
                Hako::Mode->commentMain($self);

                # 開発画面
                $self->tempOwner; # 「開発計画」
                $self->islandInfo;
                $self->tempCommandForm;
                $self->islandMap(1);
                $self->tempOwnerEnd;

                # ○○島ローカル掲示板
                if (Hako::Config::USE_LOCAL_BBS) {
                    $self->tempLbbsHead($self->{current_name});     # ローカル掲示板
                    $self->tempLbbsInputOW;   # 書き込みフォーム
                    $self->tempLbbsContents; # 掲示板内容
                }

                # 近況
                $self->tempRecent(1);
                $template = "comment";
            } elsif ($self->{main_mode} eq 'lbbs') {
                # ローカル掲示板モード
                Hako::Mode->localBbsMain($self);

                # もとのモードへ
                if ($self->{local_bbs_mode} == 0) {
                    # 観光画面
                    $self->tempPrintIslandHead($self->{current_name}); # ようこそ!!
                    $self->islandInfo; # 島の情報
                    $self->islandMap(0); # 島の地図、観光モード

                    # ○○島ローカル掲示板
                    if (Hako::Config::USE_LOCAL_BBS) {
                        $self->tempLbbsHead($self->{current_name});     # ローカル掲示板
                        $self->tempLbbsInput;   # 書き込みフォーム
                        $self->tempLbbsContents; # 掲示板内容
                    }

                    # 近況
                    $self->tempRecent(0);
                } else {
                    # 開発画面
                    $self->tempOwner; # 「開発計画」
                    $self->islandInfo;
                    $self->tempCommandForm;
                    $self->islandMap(1);
                    $self->tempOwnerEnd;

                    # ○○島ローカル掲示板
                    if (Hako::Config::USE_LOCAL_BBS) {
                        $self->tempLbbsHead($self->{current_name});     # ローカル掲示板
                        $self->tempLbbsInputOW;   # 書き込みフォーム
                        $self->tempLbbsContents; # 掲示板内容
                    }

                    # 近況
                    $self->tempRecent(1);
                }
                $template = "local_bbs";
            } elsif ($self->{main_mode} eq 'change') {
                # 情報変更モード
                Hako::Mode->changeMain($self);
                $template = "change_name";
            } else {
                # その他の場合はトップページモード
                $self->topPageMain;
                $template = "top";
            }
        };
        given ($@) {
            when (Hako::Exception::IslandFull->caught($_)) {
                $self->tempNewIslandFull;
                $template = "error";
            }
            when (Hako::Exception::NoName->caught($_)) {
                $self->tempNewIslandNoName;
                $template = "error";
            }
            when (Hako::Exception::BadName->caught($_)) {
                $self->tempNewIslandBadName;
                $template = "error";
            }
            when (Hako::Exception::AlreadyExist->caught($_)) {
                $self->tempNewIslandAlready;
                $template = "error";
            }
            when (Hako::Exception::NoPassword->caught($_)) {
                $self->tempNewIslandNoPassword;
                $template = "error";
            }
            when (Hako::Exception::WrongPassword->caught($_)) {
                $self->tempWrongPassword;
                $template = "error";
            }
            when (Hako::Exception::LocalBBSNoMessage->caught($_)) {
                $self->tempLbbsNoMessage;
                $template = "error";
            }
            when (Hako::Exception::SomethingWrong->caught($_)) {
                $self->tempProblem;
                $template = "error";
            }
            when (Hako::Exception::NoMoney->caught($_)) {
                $self->tempChangeNoMoney;
                $template = "error";
            }
            when (Hako::Exception::ChangeNothing->caught($_)) {
                $self->tempChangeNothing;
                $template = "error";
            }
            when (Hako::Exception::NoData->caught($_)) {
                $self->tempNoDataFile;
                $template = "error";
            }
            default {
                warn $@ if $@;
            }
        }

        $self->common_assign;
        $response->body(Encode::encode("utf-8", $self->render($template)));
        $response->headers({"Set-Cookie" => $self->{cookie_buffer}});

        # 最後にゲームの状態を保存する
        $self->{context}->save;
        return $response->finalize;
    };
}

sub vars_merge {
    my ($self, %vars) = @_;

    $self->{vars} = Hash::Merge::merge($self->{vars}, \%vars);
}

sub common_assign {
    my ($self) = @_;

    $self->vars_merge(
        title         => Hako::Config::TITLE,
        image_dir     => mark_raw(Hako::Config::IMAGE_DIR),
        html_body     => mark_raw(Hako::Config::HTML_BODY),
        admin_name    => Hako::Config::ADMIN_NAME,
        email         => Hako::Config::ADMIN_EMAIL,
        bbs           => Hako::Config::BBS_URL,
        toppage       => Hako::Config::TOPPAGE_URL,
        debug_mode    => Hako::Config::DEBUG,
        temp_back     => mark_raw(Hako::Config::TEMP_BACK),
        use_local_bbs => Hako::Config::USE_LOCAL_BBS,
    );
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

# hakojima.datがない
sub tempNoDataFile {
    my ($self) = @_;
    $self->vars_merge(message => "データファイルが開けません。");
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
    for my $id (@{$self->{accessor}->ranking}) {
        my $island = $self->{accessor}->get($id);
        my $name = $island->name;
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

# トップページ
sub topPageMain {
    my ($self) = @_;

    my $mStr1 = '';
    if (Hako::Config::HIDE_MONEY_MODE != 0) {
        $mStr1 = "<TH @{[Hako::Config::BG_TITLE_CELL]} align=center nowrap=nowrap><NOBR>".Hako::Template::Function->wrap_th("資金")."</NOBR></TH>";
    }

    my @islands;
    for my $id (@{$self->{accessor}->ranking}) {
        my $island = $self->{accessor}->get($id);

        my $prize = $island->{'prize'};
        $prize =~ /([0-9]*),([0-9]*),(.*)/;
        my $flags = $1;
        my $monsters= $2;
        my $turns = $3;
        $prize = '';

        my $prizes = $island->prizes;
        for my $p (@$prizes) {
            next unless $p->{turn};
            $prize .= "<IMG SRC=\"prize0.gif\" ALT=\"$1" . ${Hako::Config::PRIZE()}[0] . "\" WIDTH=16 HEIGHT=16> ";
        }

        for my $p (@$prizes) {
            next unless $p->{flag};
            $prize .= "<IMG SRC=\"prize@{[$p->{flag}-1]}.gif\" ALT=\"" . ${Hako::Config::PRIZE()}[$p->{flag}-1] . "\" WIDTH=16 HEIGHT=16> ";
        }

        my $max = 0;
        my $mNameList = "";
        for my $p (@$prizes) {
            next unless $p->{monster};
            $mNameList .= "[" . ${Hako::Config::MONSTER_NAME()}[$p->{monster}-1] . "] ";
            $max = $p->{monster};
        }
        if ($max != 0) {
            $prize .= "<IMG SRC=\"" . ${Hako::Config::MONSTER_IMAGE()}[$max-1] . "\" ALT=\"$mNameList\" WIDTH=16 HEIGHT=16> ";
        }

        push(@islands, {
                %$island,
                prize => mark_raw($prize),
                about_money => Hako::Util::aboutMoney($island->money),
            });
    }

    $self->vars_merge(
        hide_money_mode  => Hako::Config::HIDE_MONEY_MODE,
        turn             => $self->{context}->turn,
        default_id       => $self->{default_id},
        default_password => $self->{default_password},
        islands          => \@islands,
        unit_population  => Hako::Config::UNIT_POPULATION,
        unit_area        => Hako::Config::UNIT_AREA,
        unit_food        => Hako::Config::UNIT_FOOD,
        unit_money       => Hako::Config::UNIT_MONEY,
        max_island       => Hako::Config::MAX_ISLAND,
        island_number    => $self->{context}->number,
        change_name_cost => Hako::Config::CHANGE_NAME_COST,
        logs             => [map {$_->{message} = mark_raw($_->{message}); $_} @{Hako::DB->get_common_log($self->{context}->turn)}],
        histories        => [map {$_->{message} = mark_raw($_->{message}); $_} @{Hako::DB->get_history()}],
    );
}

# 島がいっぱいな場合
sub tempNewIslandFull {
    my ($self) = @_;
    $self->vars_merge(message => "申し訳ありません、島が一杯で登録できません！！");
}

# 新規で名前がない場合
sub tempNewIslandNoName {
    my ($self) = @_;

    $self->vars_merge(message => "島につける名前が必要です。");
}

# 新規で名前が不正な場合
sub tempNewIslandBadName {
    my ($self) = @_;
    $self->vars_merge(message => "',?()<>\$'とか入ってたり、「無人島」とかいった変な名前はやめましょうよ〜");
}

# すでにその名前の島がある場合
sub tempNewIslandAlready {
    my ($self) = @_;
    $self->vars_merge(message => "その島ならすでに発見されています。");
}

# パスワードがない場合
sub tempNewIslandNoPassword {
    my ($self) = @_;
    $self->vars_merge(message => "パスワードが必要です。");
}

# パスワード間違い
sub tempWrongPassword {
    my ($self) = @_;
    $self->vars_merge(message => "パスワードが違います。");
}

# 島を発見しました!!
sub tempNewIslandHead {
    my ($self, $current_name) = @_;
    $self->vars_merge(current_name => $current_name);
}

sub tempProblem {
    my ($self) = @_;
    $self->vars_merge(message => "問題発生、とりあえず戻ってください。");
}

# 情報の表示
sub islandInfo {
    my ($self) = @_;
    my $island = $self->{accessor}->get($self->{current_id});
    # 情報表示
    my $rank = $self->{current_number} + 1;

    my $money_mode = 2;
    if((Hako::Config::HIDE_MONEY_MODE == 1) || ($self->{main_mode} eq 'owner')) {
        $money_mode = 1;
    } elsif(Hako::Config::HIDE_MONEY_MODE == 2) {
        $money_mode = 2;
    }

    $self->vars_merge(
        rank            => $rank,
        island          => $island->to_hash,
        about_money     => Hako::Util::aboutMoney($island->money),
        money_mode      => $money_mode,
        unit_population => Hako::Config::UNIT_POPULATION,
        unit_area       => Hako::Config::UNIT_AREA,
        unit_food       => Hako::Config::UNIT_FOOD,
        unit_money      => Hako::Config::UNIT_MONEY,
    );
}

# 地図の表示
# 引数が1なら、ミサイル基地等をそのまま表示
sub islandMap {
    my ($self, $mode) = @_;
    my $island = $self->{accessor}->get($self->{current_id});

    # 地形、地形値を取得
    my $land = $island->land;
    my $landValue = $island->land_value;
    my ($l, $lv);

    # コマンド取得
    my $command = $island->command;
    my @comStr;
    if ($self->{main_mode} eq 'owner') {
        for (my $i = 0; $i < Hako::Config::COMMAND_MAX; $i++) {
            my $j = $i + 1;
            my $com = $command->[$i];
            if ($com->{'kind'} < 20) {
                $comStr[$com->{'x'}][$com->{'y'}] .= " [${j}]" . Hako::Command->id_to_name($com->{'kind'});
            }
        }
    }

    # 各地形および改行を出力
    my @island_land;
    for (my $y = 0; $y < Hako::Config::ISLAND_SIZE; $y++) {
        # 各地形を出力
        my @island_land_value;
        for (my $x = 0; $x < Hako::Config::ISLAND_SIZE; $x++) {
            my $l = $land->[$x][$y];
            my $lv = $landValue->[$x][$y];
            my ($image, $alt) = $self->landString($l, $lv, $x, $y, $mode, $comStr[$x][$y]);
            push(@island_land_value, {image => $image, alt => $alt});
        }
        push(@island_land, \@island_land_value);
    }

    my $island_size = Hako::Config::ISLAND_SIZE - 1;
    $self->vars_merge(
        island_size           => Hako::Config::ISLAND_SIZE,
        map_island_size_range => [map {$_} 0..$island_size],
        mode                  => $mode,
        land                  => \@island_land,
    );
}

sub landString {
    my ($self, $l, $lv, $x, $y, $mode, $comStr) = @_;
    my $point = "($x,$y)";
    my ($image, $alt);

    $comStr ||= "";
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
        if ((($special == 3) && (($self->{context}->turn % 2) == 1)) ||
            (($special == 4) && (($self->{context}->turn % 2) == 0))) {
            # 硬化中
            $image = ${Hako::Config::MONSTER_IMAGE2()}[$kind];
        }
        $alt = "怪獣$name(体力${hp})";
    }


    return $image, "$point $alt $comStr";
}

# ○○島へようこそ！！
sub tempPrintIslandHead {
    my ($self, $current_name) = @_;

    $self->vars_merge(current_name => $current_name);
}

# ローカル掲示板
sub tempLbbsHead {
    my ($self, $current_name) = @_;
    $self->vars_merge(current_name => $current_name);
}

# ローカル掲示板入力フォーム
sub tempLbbsInput {
    my ($self) = @_;
    $self->vars_merge(
        default_name => $self->{default_name},
        current_id   => $self->{current_id},
    );
}

# ローカル掲示板内容
sub tempLbbsContents {
    my ($self) = @_;
    my $island = $self->{accessor}->get($self->{current_id});
    my $lbbs = $island->lbbs;
    my @local_bbs;
    for (my $i = 0; $i < Hako::Config::LOCAL_BBS_MAX; $i++) {
        my $line = $lbbs->[$i];
        if ($line =~ /([0-9]*)\>(.*)\>(.*)$/) {
            my $content;
            if ($1 == 0) {
                # 観光者
                $content = "<TD>".Hako::Template::Function->wrap_local_bbs_ss($2." > ".$3)."</TD></TR>";
            } else {
                # 島主
                $content = "<TD>".Hako::Template::Function->wrap_local_bbs_ow($2." > ".$3)."</TD></TR>";
            }
            push(@local_bbs, {content => mark_raw($content)});
        }
    }
    $self->vars_merge(local_bbs_contents => \@local_bbs);
}

# 近況
sub tempRecent {
    my ($self, $mode) = @_;
    $self->vars_merge(
        current_name => $self->{current_name},
    );
    $self->logPrintLocal($mode);
}

# 個別ログ表示
sub logPrintLocal {
    my ($self, $mode) = @_;

    my $logs = Hako::DB->get_log($self->{current_id}, $self->{context}->turn);
    my (@secrets, @lates, @normals);
    for my $log (@$logs) {
        $log->{message} = mark_raw($log->{message});
        if ($log->{log_type} == 3) {
            push @secrets, $log;
        } elsif ($log->{log_type} == 2) {
            push @lates, $log;
        } elsif ($log->{log_type} == 1) {
            push @normals, $log;
        }
    }
    $self->vars_merge(
        recent_mode => $mode,
        secrets     => \@secrets,
        lates       => \@lates,
        normals     => \@normals,
    );
}

# ○○島開発計画
sub tempOwner {
    my ($self) = @_;

    $self->vars_merge(current_name => $self->{current_name});
}

sub tempOwnerEnd {
    my ($self) = @_;
    my @command_list;
    my $island = $self->{accessor}->get($self->{current_id});

    my $command_max = Hako::Config::COMMAND_MAX - 1;
    $self->vars_merge(
        command_range    => [(0..$command_max)],
        command_list     => [map {Hako::Model::Command->new(%$_)} @{$island->command}],
        default_password => $self->{default_password},
    );
}

sub tempCommandForm {
    my ($self) = @_;

    my $current_id  = $self->{current_id};
    my $command_max = Hako::Config::COMMAND_MAX - 1;
    my $island_size = Hako::Config::ISLAND_SIZE - 1;

    #コマンド
    my @commands;
    for (my $i = 0; $i < Hako::Constants::COMMAND_TOTAL_NUM; $i++) {
        my $kind = ${Hako::Constants::COM_LIST()}[$i];
        push(@commands, {
                kind => $kind,
                name => Hako::Command->id_to_name($kind),
                cost => Hako::Command->id_to_cost($kind),
            });
    }

    $self->vars_merge(
        current_id        => $current_id,
        default_password  => $self->{default_password},
        default_kind      => $self->{default_kind},
        unit_money        => Hako::Config::UNIT_MONEY,
        unit_food         => Hako::Config::UNIT_FOOD,
        command_range     => [(0..$command_max)],
        commands          => \@commands,
        island_size_range => [(0..$island_size)],
        default_x         => $self->{default_x},
        default_y         => $self->{default_y},
        num_range         => [(0..99)],
        target_list       => $self->{target_list},
    );
}

# ローカル掲示板入力フォーム owner mode用
sub tempLbbsInputOW {
    my ($self) = @_;

    my $local_bbs_max = Hako::Config::LOCAL_BBS_MAX - 1;
    $self->vars_merge(
        default_name        => $self->{default_name},
        default_password    => $self->{default_password},
        current_id          => $self->{current_id},
        local_bbs_max_range => [(0..$local_bbs_max)],
    );
}

# コマンド削除
sub tempCommandDelete {
    my ($self) = @_;
    $self->vars_merge(command_message => "コマンドを削除しました");
}

# コマンド登録
sub tempCommandAdd {
    my ($self) = @_;
    $self->vars_merge(command_message => "コマンドを登録しました");
}

# コメント変更成功
sub tempComment {
    my ($self) = @_;
    $self->vars_merge(command_message => "コメントを更新しました");
}

# ローカル掲示板で名前かメッセージがない場合
sub tempLbbsNoMessage {
    my ($self) = @_;
    $self->vars_merge(message => "名前または内容の欄が空欄です。");
}

# 書きこみ削除
sub tempLbbsDelete {
    my ($self) = @_;
    $self->vars_merge(local_bbs_message => "記帳内容を削除しました");
}

# コマンド登録
sub tempLbbsAdd {
    my ($self) = @_;
    $self->vars_merge(local_bbs_message => "記帳を行いました");
}

# 名前変更資金足りず
sub tempChangeNoMoney {
    my ($self) = @_;
    $self->vars_merge(message => "資金不足のため変更できません");
}

# 名前変更失敗
sub tempChangeNothing {
    my ($self) = @_;
    $self->vars_merge(message => "名前、パスワードともに空欄です");
}

1;
