package Hako::Mode;
use strict;
use warnings;
use Hako::Config;
use Hako::Constants;
use Hako::DB;
use Hako::Log;
use Hako::Util;
use Hako::Command;
use Hako::Exception;
use Hako::Model::Turn;
use Data::Dumper;

#周囲2ヘックスの座標
my (@ax) = (0, 1, 1, 1, 0,-1, 0, 1, 2, 2, 2, 1, 0,-1,-1,-2,-1,-1, 0);
my (@ay) = (0,-1, 0, 1, 1, 0,-1,-2,-1, 0, 1, 2, 2, 2, 1, 0,-1,-2,-2);

# 地形の呼び方
sub landName {
    my($land, $lv) = @_;

    if ($land == Hako::Constants::LAND_SEA) {
        if ($lv == 1) {
            return '浅瀬';
        } else {
            return '海';
        }
    } elsif ($land == Hako::Constants::LAND_WASTE) {
        return '荒地';
    } elsif ($land == Hako::Constants::LAND_PLAINS) {
        return '平地';
    } elsif ($land == Hako::Constants::LAND_TOWN) {
        if ($lv < 30) {
            return '村';
        } elsif ($lv < 100) {
            return '町';
        } else {
            return '都市';
        }
    } elsif ($land == Hako::Constants::LAND_FOREST) {
        return '森';
    } elsif ($land == Hako::Constants::LAND_FARM) {
        return '農場';
    } elsif ($land == Hako::Constants::LAND_FACTORY) {
        return '工場';
    } elsif ($land == Hako::Constants::LAND_BASE) {
        return 'ミサイル基地';
    } elsif ($land == Hako::Constants::LAND_DEFENCE) {
        return '防衛施設';
    } elsif ($land == Hako::Constants::LAND_MOUNTAIN) {
        return '山';
    } elsif ($land == Hako::Constants::LAND_MONSTER) {
        my ($kind, $name, $hp) = monsterSpec($lv);
        return $name;
    } elsif ($land == Hako::Constants::LAND_SEA_BASE) {
        return '海底基地';
    } elsif ($land == Hako::Constants::LAND_OIL) {
        return '海底油田';
    } elsif ($land == Hako::Constants::LAND_MONUMENT) {
        return ${Hako::Config::MONUMEBT_NAME()}[$lv];
    } elsif ($land == Hako::Constants::LAND_HARIBOTE) {
        return 'ハリボテ';
    }
}

# 怪獣の情報
sub monsterSpec {
    my($lv) = @_;

    # 種類
    my $kind = int($lv / 10);

    # 名前
    my $name = ${Hako::Config::MONSTER_NAME()}[$kind];

    # 体力
    my $hp = $lv - ($kind * 10);

    return ($kind, $name, $hp);
}

# 周囲の町、農場があるか判定
sub countGrow {
    my($land, $landValue, $x, $y) = @_;

    for (my $i = 1; $i < 7; $i++) {
        my $sx = $x + $ax[$i];
        my $sy = $y + $ay[$i];

        # 行による位置調整
        if ((($sy % 2) == 0) && (($y % 2) == 1)) {
            $sx--;
        }

        if (($sx < 0) || ($sx >= Hako::Config::ISLAND_SIZE) ||
            ($sy < 0) || ($sy >= Hako::Config::ISLAND_SIZE)) {
        } else {
            # 範囲内の場合
            if (($land->[$sx][$sy] == Hako::Constants::LAND_TOWN) ||
                ($land->[$sx][$sy] == Hako::Constants::LAND_FARM)) {
                if($landValue->[$sx][$sy] != 1) {
                    return 1;
                }
            }
        }
    }
    return 0;
}

# 広域被害ルーチン
sub wideDamage {
    my ($context, $id, $name, $land, $landValue, $x, $y) = @_;

    for (my $i = 0; $i < 19; $i++) {
        my $sx = $x + $ax[$i];
        my $sy = $y + $ay[$i];

        # 行による位置調整
        if ((($sy % 2) == 0) && (($y % 2) == 1)) {
            $sx--;
        }

        my $landKind = $land->[$sx][$sy];
        my $lv = $landValue->[$sx][$sy];
        my $landName = landName($landKind, $lv);
        my $point = "($sx, $sy)";

        # 範囲外判定
        if (($sx < 0) || ($sx >= Hako::Config::ISLAND_SIZE) ||
            ($sy < 0) || ($sy >= Hako::Config::ISLAND_SIZE)) {
            next;
        }

        # 範囲による分岐
        if ($i < 7) {
            # 中心、および1ヘックス
            if ($landKind == Hako::Constants::LAND_SEA) {
                $landValue->[$sx][$sy] = 0;
                next;
            } elsif (($landKind == Hako::Constants::LAND_SEA_BASE) ||
                ($landKind == Hako::Constants::LAND_OIL)) {
                Hako::Log->logWideDamageSea2($context->{context}->turn, $id, $name, $landName, $point);
                $land->[$sx][$sy] = Hako::Constants::LAND_SEA;
                $landValue->[$sx][$sy] = 0;
            } else {
                if ($landKind == Hako::Constants::LAND_MONSTER) {
                    Hako::Log->logWideDamageMonsterSea($context->{context}->turn, $id, $name, $landName, $point);
                } else {
                    Hako::Log->logWideDamageSea($context->{context}->turn, $id, $name, $landName, $point);
                }
                $land->[$sx][$sy] = Hako::Constants::LAND_SEA;
                if ($i == 0) {
                    # 海
                    $landValue->[$sx][$sy] = 0;
                } else {
                    # 浅瀬
                    $landValue->[$sx][$sy] = 1;
                }
            }
        } else {
            # 2ヘックス
            if (($landKind == Hako::Constants::LAND_SEA) ||
                ($landKind == Hako::Constants::LAND_OIL) ||
                ($landKind == Hako::Constants::LAND_WASTE) ||
                ($landKind == Hako::Constants::LAND_MOUNTAIN) ||
                ($landKind == Hako::Constants::LAND_SEA_BASE)) {
                next;
            } elsif($landKind == Hako::Constants::LAND_MONSTER) {
                Hako::Log->logWideDamageMonster($context->{context}->turn, $id, $name, $landName, $point);
                $land->[$sx][$sy] = Hako::Constants::LAND_WASTE;
                $landValue->[$sx][$sy] = 0;
            } else {
                Hako::Log->logWideDamageWaste($context->{context}->turn, $id, $name, $landName, $point);
                $land->[$sx][$sy] = Hako::Constants::LAND_WASTE;
                $landValue->[$sx][$sy] = 0;
            }
        }
    }
}


sub newIslandMain {
    my ($class, $context) = @_;
    # 島がいっぱいでないかチェック
    if ($context->{context}->number >= Hako::Config::MAX_ISLAND) {
        Hako::Exception::IslandFull->throw;
    }

    # 名前があるかチェック
    if ($context->{current_name} eq '') {
        Hako::Exception::NoName->throw;
    }

    # 名前が正当かチェック
    if ($context->{current_name} =~ /[,\?\(\)\<\>\$]|^無人$/) {
        Hako::Exception::BadName->throw;
    }

    # 名前の重複チェック
    if ($context->{accessor}->is_exist($context->{current_name})) {
        Hako::Exception::AlreadyExist->throw;
    }

    # passwordの存在判定
    if ($context->{input_password} eq '') {
        Hako::Exception::NoPassword->throw;
    }

    # 確認用パスワード
    if ($context->{input_password2} ne $context->{input_password}) {
        Hako::Exception::WrongPassword->throw;
    }

    # 新しい島の番号を決める
    $context->{current_number} = $context->{context}->number;
    $context->{context}->set_number($context->{current_number} + 1);
    my $island = makeNewIsland();

    # 各種の値を設定
    $island->{'name'} = $context->{current_name};
    $island->{'id'} = $context->{context}->next_id;
    $context->{context}->set_next_id($island->{id} + 1);
    $island->{'absent'} = Hako::Config::GIVEUP_TURN - 3;
    $island->{'comment'} = '(未登録)';
    $island->{'password'} = Hako::Util::encode($context->{input_password});

    # 人口その他算出
    $island->update_stat;

    # データ書き出し
    Hako::DB->save_island($island, 1000);
    $context->{current_id} = $island->id;
    Hako::Log->logDiscover($context->{context}->turn, $context->{current_name}); # ログ
    Hako::DB->init_command($island->{id});
}

# 新しい島を作成する
sub makeNewIsland {
    # 地形を作る
    my ($land, $landValue) = makeNewLand();

    # 初期コマンドを生成
    my @command;
    for (my $i = 0; $i < Hako::Config::COMMAND_MAX; $i++) {
        $command[$i] = {
            'kind' => Hako::Constants::COMMAND_DO_NOTHING,
            'target' => 0,
            'x' => 0,
            'y' => 0,
            'arg' => 0
        };
    }

    # 初期掲示板を作成
    my @lbbs;
    for (my $i = 0; $i < Hako::Config::LOCAL_BBS_MAX; $i++) {
        $lbbs[$i] = "0>>";
    }

    # 島にして返す
    return Hako::Model::Island->new({
            land      => $land,
            land_value => $landValue,
            command   => \@command,
            lbbs      => \@lbbs,
            money     => Hako::Config::INITIAL_MONEY,
            food      => Hako::Config::INITIAL_FOOD,
            prize     => '0,0,',
        });
}

# 新しい島の地形を作成する
sub makeNewLand {
    # 基本形を作成
    my (@land, @landValue);

    # 海に初期化
    for (my $y = 0; $y < Hako::Config::ISLAND_SIZE; $y++) {
        for(my $x = 0; $x < Hako::Config::ISLAND_SIZE; $x++) {
            $land[$x][$y] = Hako::Constants::LAND_SEA;
            $landValue[$x][$y] = 0;
        }
    }

    # 中央の4*4に荒地を配置
    my $center = Hako::Config::ISLAND_SIZE / 2 - 1;
    for (my $y = $center - 1; $y < $center + 3; $y++) {
        for (my $x = $center - 1; $x < $center + 3; $x++) {
            $land[$x][$y] = Hako::Constants::LAND_WASTE;
        }
    }

    # 8*8範囲内に陸地を増殖
    for (my $i = 0; $i < 120; $i++) {
        # ランダム座標
        my $x = Hako::Util::random(8) + $center - 3;
        my $y = Hako::Util::random(8) + $center - 3;

        my $tmp = Hako::Model::Turn::countAround(\@land, $x, $y, Hako::Constants::LAND_SEA, 7);
        if (Hako::Model::Turn::countAround(\@land, $x, $y, Hako::Constants::LAND_SEA, 7) != 7){
            # 周りに陸地がある場合、浅瀬にする
            # 浅瀬は荒地にする
            # 荒地は平地にする
            if ($land[$x][$y] == Hako::Constants::LAND_WASTE) {
                $land[$x][$y] = Hako::Constants::LAND_PLAINS;
                $landValue[$x][$y] = 0;
            } else {
                if($landValue[$x][$y] == 1) {
                    $land[$x][$y] = Hako::Constants::LAND_WASTE;
                    $landValue[$x][$y] = 0;
                } else {
                    $landValue[$x][$y] = 1;
                }
            }
        }
    }

    # 森を作る
    my $count = 0;
    while ($count < 4) {
        # ランダム座標
        my $x = Hako::Util::random(4) + $center - 1;
        my $y = Hako::Util::random(4) + $center - 1;

        # そこがすでに森でなければ、森を作る
        if ($land[$x][$y] != Hako::Constants::LAND_FOREST) {
            $land[$x][$y] = Hako::Constants::LAND_FOREST;
            $landValue[$x][$y] = 5; # 最初は500本
            $count++;
        }
    }

    # 町を作る
    $count = 0;
    while ($count < 2) {
        # ランダム座標
        my $x = Hako::Util::random(4) + $center - 1;
        my $y = Hako::Util::random(4) + $center - 1;

        # そこが森か町でなければ、町を作る
        if (($land[$x][$y] != Hako::Constants::LAND_TOWN) &&
            ($land[$x][$y] != Hako::Constants::LAND_FOREST)) {
            $land[$x][$y] = Hako::Constants::LAND_TOWN;
            $landValue[$x][$y] = 5; # 最初は500人
            $count++;
        }
    }

    # 山を作る
    $count = 0;
    while ($count < 1) {
        # ランダム座標
        my $x = Hako::Util::random(4) + $center - 1;
        my $y = Hako::Util::random(4) + $center - 1;

        # そこが森か町でなければ、町を作る
        if (($land[$x][$y] != Hako::Constants::LAND_TOWN) &&
            ($land[$x][$y] != Hako::Constants::LAND_FOREST)) {
            $land[$x][$y] = Hako::Constants::LAND_MOUNTAIN;
            $landValue[$x][$y] = 0; # 最初は採掘場なし
            $count++;
        }
    }

    # 基地を作る
    $count = 0;
    while ($count < 1) {
        # ランダム座標
        my $x = Hako::Util::random(4) + $center - 1;
        my $y = Hako::Util::random(4) + $center - 1;

        # そこが森か町か山でなければ、基地
        if (($land[$x][$y] != Hako::Constants::LAND_TOWN) &&
            ($land[$x][$y] != Hako::Constants::LAND_FOREST) &&
            ($land[$x][$y] != Hako::Constants::LAND_MOUNTAIN)) {
            $land[$x][$y] = Hako::Constants::LAND_BASE;
            $landValue[$x][$y] = 0;
            $count++;
        }
    }

    return (\@land, \@landValue);
}

# メイン
sub printIslandMain {
    my ($class, $context) = @_;

    # 名前の取得
    $context->{current_name} = $context->{accessor}->get($context->{current_id})->name;
}

sub ownerMain {
    my ($class, $context) = @_;
    # モードを明示
    $context->{main_mode} = 'owner';

    # idから島を取得
    $context->{current_number} = $context->{id_to_number}->{$context->{current_id}};
    my $island = $context->{accessor}->get($context->{current_id});
    $context->{current_name} = $island->name;

    # パスワード
    if (!Hako::Util::checkPassword($island->{'password'}, $context->{input_password})) {
        Hako::Exception::WrongPassword->throw;
    }
}

sub commandMain {
    my ($class, $context) = @_;
    # idから島を取得
    $context->{current_number} = $context->{id_to_number}->{$context->{current_id}};
    my $island = $context->{accessor}->get($context->{current_id});
    $context->{current_name} = $island->name;

    # パスワード
    if (!Hako::Util::checkPassword($island->{'password'}, $context->{input_password})) {
        Hako::Exception::WrongPassword->throw;
    }

    # モードで分岐
    my $command = $island->command;

    if ($context->{command_mode} eq 'delete') {
        Hako::DB->delete_command($island->id, $context->{command_plan_number});
        $context->tempCommandDelete;
    } elsif (($context->{command_kind} == Hako::Constants::COMMAND_AUTO_PREPARE) || ($context->{command_kind} == Hako::Constants::COMMAND_AUTO_PREPARE2)) {
        # フル整地、フル地ならし
        # 座標配列を作る
        my ($Hrpx, $Hrpy) = makeRandomPointArray($context);
        $context->{rpx} = $Hrpx;
        $context->{rpy} = $Hrpy;
        my $land = $island->land;

        # コマンドの種類決定
        my $kind = Hako::Constants::COMMAND_PREPARE;
        if ($context->{command_kind} == Hako::Constants::COMMAND_AUTO_PREPARE2) {
            $kind = Hako::Constants::COMMAND_PREPARE2;
        }

        my $i = 0;
        my $j = 0;
        while (($j < Hako::Config::POINT_NUMBER) && ($i < Hako::Config::COMMAND_MAX)) {
            my $x = $context->{rpx}->[$j];
            my $y = $context->{rpy}->[$j];
            if ($land->[$x][$y] == Hako::Constants::LAND_WASTE) {
                my $cmd = {
                    kind   => $kind,
                    target => 0,
                    x      => $x,
                    y      => $y,
                    arg    => 0,
                };
                Hako::DB->insert_command($island->id, $context->{command_plan_number}, $cmd);

                $i++;
            }
            $j++;
        }
        $context->tempCommandAdd;
    } elsif ($context->{command_kind} == Hako::Constants::COMMAND_AUTO_DELETE) {
        # 全消し
        Hako::DB->delete_all_command($island->id);
        $context->tempCommandDelete;
    } else {
        $context->tempCommandAdd;
        # コマンドを登録
        my $cmd = {
            kind   => $context->{command_kind},
            target => $context->{command_target},
            x      => $context->{command_x},
            y      => $context->{command_y},
            arg    => $context->{command_arg},
        };
        if ($context->{command_mode} eq "insert") {
            Hako::DB->insert_command($island->id, $context->{command_plan_number}, $cmd);
        } else {
            Hako::DB->insert_command($island->id, $context->{command_plan_number}, $cmd, 1);
        }
    }
    # reload
    delete($island->{command});
    $island->command;

    # owner modeへ
    $class->ownerMain($context);
}

sub commentMain {
    my ($class, $context) = @_;
    # idから島を取得
    $context->{current_number} = $context->{id_to_number}->{$context->{current_id}};
    my $island = $context->{accessor}->get($context->{current_id});
    $context->{current_name} = $island->name;

    # パスワード
    if (!Hako::Util::checkPassword($island->password, $context->{input_password})) {
        Hako::Exception::WrongPassword->throw;
    }

    # メッセージを更新
    $island->{comment} = Hako::Util::htmlEscape($context->{message});

    # データの書き出し
    Hako::DB->save_island($island);

    # コメント更新メッセージ
    $context->tempComment;

    # owner modeへ
    $class->ownerMain($context);
}

sub localBbsMain {
    my ($class, $context) = @_;
    # idから島番号を取得
    $context->{current_number} = $context->{id_to_number}->{$context->{current_id}};
    my $island = $context->{accessor}->get($context->{current_id});

    # なぜかその島がない場合
    if ($context->{current_number} eq '') {
        Hako::Exception::SomethingWrong->throw;
    }

    # 削除モードじゃなくて名前かメッセージがない場合
    if ($context->{local_bbs_mode} != 2) {
        if (($context->{local_bbs_name} eq '') || ($context->{local_bbs_name} eq '')) {
            Hako::Exception::LocalBBSNoMessage->throw;
        }
    }

    # 観光者モードじゃない時はパスワードチェック
    if ($context->{local_bbs_mode} != 0) {
        if (!Hako::Util::checkPassword($island->{'password'}, $context->{input_password})) {
            Hako::Exception::WrongPassword->throw;
        }
    }

    my $lbbs = $island->lbbs;

    # モードで分岐
    if ($context->{local_bbs_mode} == 2) {
        # FIXME: 実装
        # 削除モード
        # メッセージを前にずらす
        #slideBackLbbsMessage($lbbs, $context->{command_plan_number});
        $context->tempLbbsDelete;
    } else {
        # 記帳モード
        # メッセージを後ろにずらす
        #slideLbbsMessage($lbbs);

        # メッセージ書き込み
        my $message;
        if ($context->{local_bbs_mode} == 0) {
            $message = '0';
        } else {
            $message = '1';
        }
        $context->{local_bbs_name} = $context->{context}->turn."：" . Hako::Util::htmlEscape($context->{local_bbs_name});
        $context->{local_bbs_message} = Hako::Util::htmlEscape($context->{local_bbs_message});
        my $bbs_message = "$message>@{[$context->{local_bbs_name}]}>@{[$context->{local_bbs_message}]}";
        $lbbs->[0] = $bbs_message;
        Hako::DB->insert_bbs($island->{id}, $bbs_message);

        $context->tempLbbsAdd();
    }
}

sub changeMain {
    my ($class, $context) = @_;
    # idから島を取得
    $context->{current_number} = $context->{id_to_number}->{$context->{current_id}};
    my $island = $context->{accessor}->get($context->{current_id});
    my $flag = 0;

    # パスワードチェック
    if ($context->{input_password} eq Hako::Config::SPECIAL_PASSWORD) {
        # 特殊パスワード
        $island->{'money'} = 9999;
        $island->{'food'} = 9999;
    } elsif (!Hako::Util::checkPassword($island->password, $context->{input_password})) {
        Hako::Exception::WrongPassword->throw;
    }

    # 確認用パスワード
    if ($context->{input_password2} ne $context->{input_password}) {
        Hako::Exception::WrongPassword->throw;
    }

    if ($context->{current_name} ne '') {
        # 名前変更の場合	
        # 名前が正当かチェック
        if ($context->{current_name} =~ /[,\?\(\)\<\>]|^無人$/) {
            Hako::Exception::BadName->throw;
        }

        # 名前の重複チェック
        unless ($context->{accessor}->is_exist($context->{current_name})) {
            Hako::Exception::AlreadyExist->throw;
        }

        if ($island->money < Hako::Config::CHANGE_NAME_COST) {
            Hako::Exception::NoMoney->throw;
        }

        # 代金
        if ($context->{input_password} ne Hako::Config::SPECIAL_PASSWORD) {
            $island->{'money'} -= Hako::Config::CHANGE_NAME_COST;
        }

        # 名前を変更
        Hako::Log->logChangeName($context->{context}->turn, $island->name, $context->{current_name});
        $island->{'name'} = $context->{current_name};
        $flag = 1;
    }

    # password変更の場合
    if ($context->{input_password} ne '') {
        # パスワードを変更
        $island->{'password'} = Hako::Util::encode($context->{input_password});
        $flag = 1;
    }

    if (($flag == 0) && ($context->{input_password} ne Hako::Config::SPECIAL_PASSWORD)) {
        Hako::Exception::ChangeNothing->throw;
    }

    # データ書き出し
    Hako::DB->save_island(($island);

    # 変更成功
    $context->tempChange;
}

1;
