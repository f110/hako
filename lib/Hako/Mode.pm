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
use Data::Dumper;

#周囲2ヘックスの座標
my (@ax) = (0, 1, 1, 1, 0,-1, 0, 1, 2, 2, 2, 1, 0,-1,-1,-2,-1,-1, 0);
my (@ay) = (0,-1, 0, 1, 1, 0,-1,-2,-1, 0, 1, 2, 2, 2, 1, 0,-1,-2,-2);

#----------------------------------------------------------------------
# ターン進行モード
#----------------------------------------------------------------------
# メイン
sub turnMain {
    my ($class, $context) = @_;
    # 最終更新時間を更新
    $context->{island_last_time} += Hako::Config::UNIT_TIME;

    # 座標配列を作る
    my ($Hrpx, $Hrpy) = makeRandomPointArray($context);
    $context->{rpx} = $Hrpx;
    $context->{rpy} = $Hrpy;

    # ターン番号
    $context->{island_turn}++;

    # 順番決め
    my (@order) = randomArray($context->{island_number});

    # 収入、消費フェイズ
    for (my $i = 0; $i < $context->{island_number}; $i++) {
        estimate($context, $order[$i]);
        income($context->{islands}->[$order[$i]]);

        # ターン開始前の人口をメモる
        $context->{islands}->[$order[$i]]->{'oldPop'} = $context->{islands}->[$order[$i]]->{'pop'};
    }

    # コマンド処理
    for (my $i = 0; $i < $context->{island_number}; $i++) {
        # 戻り値1になるまで繰り返し
        while(doCommand($context, $context->{islands}->[$order[$i]]) == 0){};
    }

    # 成長および単ヘックス災害
    for (my $i = 0; $i < $context->{island_number}; $i++) {
        doEachHex($context, $context->{islands}->[$order[$i]]);
    }

    # 島全体処理
    my $remainNumber = $context->{island_number};
    for (my $i = 0; $i < $context->{island_number}; $i++) {
        my $island = $context->{islands}->[$order[$i]];
        doIslandProcess($context, $order[$i], $island);

        # 死滅判定
        if ($island->{'dead'} == 1) {
            $island->{'pop'} = 0;
            $remainNumber--;
        } elsif ($island->{'pop'} == 0) {
            $island->{'dead'} = 1;
            $remainNumber--;
            # 死滅メッセージ
            my $tmpid = $island->{'id'};
            Hako::Log->logDead($context->{island_turn}, $tmpid, $island->{'name'});
        }
    }

    # 人口順にソート
    islandSort($context);

    # ターン杯対象ターンだったら、その処理
    if (($context->{island_turn} % Hako::Config::TURN_PRIZE_UNIT) == 0) {
        my $island = $context->{islands}->[0];
        Hako::Log->logPrize($context->{island_turn}, $island->{'id'}, $island->{'name'}, $context->{island_turn} . ${Hako::Config::PRIZE()}[0]);
        $island->{'prize'} .= $context->{island_turn}.",";
    }

    # 島数カット
    $context->{island_number} = $remainNumber;

    # ファイルに書き出し
    $context->writeIslandsFile(-1);
}

# (0,0)から(size - 1, size - 1)までの数字が一回づつ出てくるように
# (@Hrpx, @Hrpy)を設定
sub makeRandomPointArray {
    my ($context) = @_;

    # 初期値
    my @Hrpx = (0..Hako::Config::ISLAND_SIZE()-1) x Hako::Config::ISLAND_SIZE;
    my @Hrpy;
    for (my $y = 0; $y < Hako::Config::ISLAND_SIZE; $y++) {
        push(@Hrpy, ($y) x Hako::Config::ISLAND_SIZE);
    }

    # シャッフル
    for (my $i = Hako::Config::POINT_NUMBER; --$i; ) {
        my $j = int(rand($i+1));
        next if ($i == $j);
        @Hrpx[$i,$j] = @Hrpx[$j,$i];
        @Hrpy[$i,$j] = @Hrpy[$j,$i];
    }

    return \@Hrpx, \@Hrpy;
}

# 0から(n - 1)までの数字が一回づつ出てくる数列を作る
sub randomArray {
    my ($n) = @_;

    # 初期値
    $n = 1 if ($n == 0);
    my @list = (0..$n-1);

    # シャッフル
    for (my $i = $n; --$i; ) {
        my ($j) = int(rand($i+1));
        next if ($i == $j);
        @list[$i,$j] = @list[$j,$i];
    }

    return @list;
}

# 人口その他の値を算出
sub estimate {
    my ($context, $number) = @_;
    my ($pop, $area, $farm, $factory, $mountain) = (0, 0, 0, 0, 0, 0);

    # 地形を取得
    my $island = $context->{islands}->[$number];
    my ($land) = $island->{'land'};
    my ($landValue) = $island->{'landValue'};

    # 数える
    for (my $y = 0; $y < Hako::Config::ISLAND_SIZE; $y++) {
        for(my $x = 0; $x < Hako::Config::ISLAND_SIZE; $x++) {
            my $kind = $land->[$x][$y];
            my $value = $landValue->[$x][$y];
            if (($kind != Hako::Constants::LAND_SEA) && ($kind != Hako::Constants::LAND_SEA_BASE) && ($kind != Hako::Constants::LAND_OIL)) {
                $area++;
                if ($kind == Hako::Constants::LAND_TOWN) {
                    # 町
                    $pop += $value;
                } elsif ($kind == Hako::Constants::LAND_FARM) {
                    # 農場
                    $farm += $value;
                } elsif ($kind == Hako::Constants::LAND_FACTORY) {
                    # 工場
                    $factory += $value;
                } elsif ($kind == Hako::Constants::LAND_MOUNTAIN) {
                    # 山
                    $mountain += $value;
                }
            }
        }
    }

    # 代入
    $island->{'pop'}      = $pop;
    $island->{'area'}     = $area;
    $island->{'farm'}     = $farm;
    $island->{'factory'}  = $factory;
    $island->{'mountain'} = $mountain;
}

# 収入、消費フェイズ
sub income {
    my($island) = @_;
    my($pop, $farm, $factory, $mountain) =
    (
        $island->{'pop'},
        $island->{'farm'} * 10,
        $island->{'factory'},
        $island->{'mountain'}
    );

    # 収入
    if ($pop > $farm) {
        # 農業だけじゃ手が余る場合
        $island->{'food'} += $farm; # 農場フル稼働
        $island->{'money'} += Hako::Util::min(int(($pop - $farm) / 10), $factory + $mountain);
    } else {
        # 農業だけで手一杯の場合
        $island->{'food'} += $pop; # 全員野良仕事
    }

    # 食料消費
    $island->{'food'} = int(($island->{'food'}) - ($pop * Hako::Config::EATEN_FOOD));
}

# コマンドフェイズ
sub doCommand {
    my ($context, $island) = @_;

    # コマンド取り出し
    my $comArray = $island->{'command'};
    my $command = $comArray->[0]; # 最初のを取り出し
    Hako::DB->delete_command($island->{id}, 0); # 以降を詰める

    # 各要素の取り出し
    my ($kind, $target, $x, $y, $arg) = 
    (
        $command->{'kind'},
        $command->{'target'},
        $command->{'x'},
        $command->{'y'},
        $command->{'arg'}
    );

    # 導出値
    my ($name) = $island->{'name'};
    my ($id) = $island->{'id'};
    my ($land) = $island->{'land'};
    my ($landValue) = $island->{'landValue'};
    my ($landKind) = $land->[$x][$y];
    my ($lv) = $landValue->[$x][$y];
    my ($cost) = Hako::Command->id_to_cost($kind);
    my ($comName) = Hako::Command->id_to_name($kind);
    my ($point) = "($x, $y)";
    my ($landName) = landName($landKind, $lv);

    if ($kind == Hako::Constants::COMMAND_DO_NOTHING) {
        # 資金繰り
        Hako::Log->logDoNothing($context->{island_turn}, $id, $name, $comName);
        $island->{'money'} += 10;
        $island->{'absent'} ++;

        # 自動放棄
        if ($island->{'absent'} >= Hako::Config::GIVEUP_TURN) {
            $comArray->[0] = {
                'kind' => Hako::Constants::COMMAND_GIVE_UP,
                'target' => 0,
                'x' => 0,
                'y' => 0,
                'arg' => 0
            }
        }
        return 1;
    }

    $island->{'absent'} = 0;

    # コストチェック
    if ($cost > 0) {
        # 金の場合
        if ($island->{'money'} < $cost) {
            Hako::Log->logNoMoney($context->{island_turn}, $id, $name, $comName);
            return 0;
        }
    } elsif ($cost < 0) {
        # 食料の場合
        if ($island->{'food'} < (-$cost)) {
            Hako::Log->logNoFood($context->{island_turn}, $id, $name, $comName);
            return 0;
        }
    }

    # コマンドで分岐
    if ($kind == Hako::Constants::COMMAND_PREPARE || $kind == Hako::Constants::COMMAND_PREPARE2) {
        # 整地、地ならし
        if ($landKind == Hako::Constants::LAND_SEA || 
            $landKind == Hako::Constants::LAND_SEA_BASE ||
            $landKind == Hako::Constants::LAND_OIL ||
            $landKind == Hako::Constants::LAND_MOUNTAIN ||
            $landKind == Hako::Constants::LAND_MONSTER) {
            # 海、海底基地、油田、山、怪獣は整地できない
            Hako::Log->logLandFail($context->{island_turn}, $id, $name, $comName, $landName, $point);
            return 0;
        }

        # 目的の場所を平地にする
        $land->[$x][$y] = Hako::Constants::LAND_PLAINS;
        $landValue->[$x][$y] = 0;
        Hako::Log->logLandSuc($context->{island_turn}, $id, $name, '整地', $point);

        # 金を差し引く
        $island->{'money'} -= $cost;

        if ($kind == Hako::Constants::COMMAND_PREPARE2) {
            # 地ならし
            $island->{'prepare2'}++;

            # ターン消費せず
            return 0;
        } else {
            # 整地なら、埋蔵金の可能性あり
            if (Hako::Util::random(1000) < Hako::Config::DISASTER_MAIZO) {
                my ($v) = 100 + Hako::Util::random(901);
                $island->{'money'} += $v;
                Hako::Log->logMaizo($context->{island_turn}, $id, $name, $comName, $v);
            }
            return 1;
        }
    } elsif ($kind == Hako::Constants::COMMAND_RECLAIM) {
        # 埋め立て
        if ($landKind != Hako::Constants::LAND_SEA &&
            $landKind != Hako::Constants::LAND_OIL &&
            $landKind != Hako::Constants::LAND_SEA_BASE) {
            # 海、海底基地、油田しか埋め立てできない
            Hako::Log->logLandFail($context->{island_turn}, $id, $name, $comName, $landName, $point);
            return 0;
        }

        # 周りに陸があるかチェック
        my($seaCount) =
        countAround($land, $x, $y, Hako::Constants::LAND_SEA, 7) +
        countAround($land, $x, $y, Hako::Constants::LAND_OIL, 7) +
        countAround($land, $x, $y, Hako::Constants::LAND_SEA_BASE, 7);

        if ($seaCount == 7) {
            # 全部海だから埋め立て不能
            Hako::Log->logNoLandAround($context->{island_turn}, $id, $name, $comName, $point);
            return 0;
        }

        if ($landKind == Hako::Constants::LAND_SEA && $lv == 1) {
            # 浅瀬の場合
            # 目的の場所を荒地にする
            $land->[$x][$y] = Hako::Constants::LAND_WASTE;
            $landValue->[$x][$y] = 0;
            Hako::Log->logLandSuc($context->{island_turn}, $id, $name, $comName, $point);
            $island->{'area'}++;

            if ($seaCount <= 4) {
                # 周りの海が3ヘックス以内なので、浅瀬にする
                for (my $i = 1; $i < 7; $i++) {
                    my $sx = $x + $ax[$i];
                    my $sy = $y + $ay[$i];

                    # 行による位置調整
                    if ($sy % 2 == 0 && $y % 2 == 1) {
                        $sx--;
                    }

                    if (($sx < 0) || ($sx >= Hako::Config::ISLAND_SIZE) ||
                        ($sy < 0) || ($sy >= Hako::Config::ISLAND_SIZE)) {
                    } else {
                        # 範囲内の場合
                        if ($land->[$sx][$sy] == Hako::Constants::LAND_SEA) {
                            $landValue->[$sx][$sy] = 1;
                        }
                    }
                }
            }
        } else {
            # 海なら、目的の場所を浅瀬にする
            $land->[$x][$y] = Hako::Constants::LAND_SEA;
            $landValue->[$x][$y] = 1;
            Hako::Log->logLandSuc($context->{island_turn}, $id, $name, $comName, $point);
        }

        # 金を差し引く
        $island->{'money'} -= $cost;
        return 1;
    } elsif ($kind == Hako::Constants::COMMAND_DESTROY) {
        # 掘削
        if (($landKind == Hako::Constants::LAND_SEA_BASE) ||
            ($landKind == Hako::Constants::LAND_OIL) ||
            ($landKind == Hako::Constants::LAND_MONSTER)) {
            # 海底基地、油田、怪獣は掘削できない
            Hako::Log->logLandFail($context->{island_turn}, $id, $name, $comName, $landName, $point);
            return 0;
        }

        if ($landKind == Hako::Constants::LAND_SEA && $lv == 0) {
            # 海なら、油田探し
            # 投資額決定
            $arg = 1 if($arg == 0);

            my $value = Hako::Util::min($arg * ($cost), $island->{'money'});
            my $str = "$value" . Hako::Config::UNIT_MONEY;
            my $p = int($value / $cost);
            $island->{'money'} -= $value;

            # 見つかるか判定
            if ($p > Hako::Util::random(100)) {
                # 油田見つかる
                Hako::Log->logOilFound($context->{island_turn}, $id, $name, $point, $comName, $str);
                $land->[$x][$y] = Hako::Constants::LAND_OIL;
                $landValue->[$x][$y] = 0;
            } else {
                # 無駄撃ちに終わる
                Hako::Log->logOilFail($context->{island_turn}, $id, $name, $point, $comName, $str);
            }
            return 1;
        }

        # 目的の場所を海にする。山なら荒地に。浅瀬なら海に。
        if ($landKind == Hako::Constants::LAND_MOUNTAIN) {
            $land->[$x][$y] = Hako::Constants::LAND_WASTE;
            $landValue->[$x][$y] = 0;
        } elsif ($landKind == Hako::Constants::LAND_SEA) {
            $landValue->[$x][$y] = 0;
        } else {
            $land->[$x][$y] = Hako::Constants::LAND_SEA;
            $landValue->[$x][$y] = 1;
            $island->{'area'}--;
        }
        Hako::Log->logLandSuc($context->{island_turn}, $id, $name, $comName, $point);

        # 金を差し引く
        $island->{'money'} -= $cost;
        return 1;
    } elsif ($kind == Hako::Constants::COMMAND_SELL_TREE) {
        # 伐採
        if ($landKind != Hako::Constants::LAND_FOREST) {
            # 森以外は伐採できない
            Hako::Log->logLandFail($context->{island_turn}, $id, $name, $comName, $landName, $point);
            return 0;
        }

        # 目的の場所を平地にする
        $land->[$x][$y] = Hako::Constants::LAND_PLAINS;
        $landValue->[$x][$y] = 0;
        Hako::Log->logLandSuc($context->{island_turn}, $id, $name, $comName, $point);

        # 売却金を得る
        $island->{'money'} += Hako::Config::TREE_VALUE * $lv;
        return 1;
    } elsif (($kind == Hako::Constants::COMMAND_PLANT) ||
        ($kind == Hako::Constants::COMMAND_FARM) ||
        ($kind == Hako::Constants::COMMAND_FACTORY) ||
        ($kind == Hako::Constants::COMMAND_BASE) ||
        ($kind == Hako::Constants::COMMAND_MONUMENT) ||
        ($kind == Hako::Constants::COMMAND_HARIBOTE) ||
        ($kind == Hako::Constants::COMMAND_DEFENCE_BASE)) {

        # 地上建設系
        if (!
            (($landKind == Hako::Constants::LAND_PLAINS) ||
                ($landKind == Hako::Constants::LAND_TOWN) ||
                (($landKind == Hako::Constants::LAND_MONUMENT) && ($kind == Hako::Constants::COMMAND_MONUMENT)) ||
                (($landKind == Hako::Constants::LAND_FARM) && ($kind == Hako::Constants::COMMAND_FARM)) ||
                (($landKind == Hako::Constants::LAND_FACTORY) && ($kind == Hako::Constants::COMMAND_FACTORY)) ||
                (($landKind == Hako::Constants::LAND_DEFENCE) && ($kind == Hako::Constants::COMMAND_DEFENCE_BASE)))) {
            # 不適当な地形
            Hako::Log->logLandFail($context->{island_turn}, $id, $name, $comName, $landName, $point);
            return 0;
        }

        # 種類で分岐
        if ($kind == Hako::Constants::COMMAND_PLANT) {
            # 目的の場所を森にする。
            $land->[$x][$y] = Hako::Constants::LAND_FOREST;
            $landValue->[$x][$y] = 1; # 木は最低単位
            Hako::Log->logPBSuc($context->{island_turn}, $id, $name, $comName, $point);
        } elsif($kind == Hako::Constants::COMMAND_BASE) {
            # 目的の場所をミサイル基地にする。
            $land->[$x][$y] = Hako::Constants::LAND_BASE;
            $landValue->[$x][$y] = 0; # 経験値0
            Hako::Log->logPBSuc($context->{island_turn}, $id, $name, $comName, $point);
        } elsif ($kind == Hako::Constants::COMMAND_HARIBOTE) {
            # 目的の場所をハリボテにする
            $land->[$x][$y] = Hako::Constants::LAND_HARIBOTE;
            $landValue->[$x][$y] = 0;
            Hako::Log->logHariSuc($context->{island_turn}, $id, $name, $comName, Hako::Command->id_to_name(Hako::Constants::COMMAND_DEFENCE_BASE), $point);
        } elsif($kind == Hako::Constants::COMMAND_FARM) {
            # 農場
            if ($landKind == Hako::Constants::LAND_FARM) {
                # すでに農場の場合
                $landValue->[$x][$y] += 2; # 規模 + 2000人
                if ($landValue->[$x][$y] > 50) {
                    $landValue->[$x][$y] = 50; # 最大 50000人
                }
            } else {
                # 目的の場所を農場に
                $land->[$x][$y] = Hako::Constants::LAND_FARM;
                $landValue->[$x][$y] = 10; # 規模 = 10000人
            }
            Hako::Log->logLandSuc($context->{island_turn}, $id, $name, $comName, $point);
        } elsif ($kind == Hako::Constants::COMMAND_FACTORY) {
            # 工場
            if ($landKind == Hako::Constants::LAND_FACTORY) {
                # すでに工場の場合
                $landValue->[$x][$y] += 10; # 規模 + 10000人
                if($landValue->[$x][$y] > 100) {
                    $landValue->[$x][$y] = 100; # 最大 100000人
                }
            } else {
                # 目的の場所を工場に
                $land->[$x][$y] = Hako::Constants::LAND_FACTORY;
                $landValue->[$x][$y] = 30; # 規模 = 10000人
            }
            Hako::Log->logLandSuc($context->{island_turn}, $id, $name, $comName, $point);
        } elsif ($kind == Hako::Constants::COMMAND_DEFENCE_BASE) {
            # 防衛施設
            if ($landKind == Hako::Constants::LAND_DEFENCE) {
                # すでに防衛施設の場合
                $landValue->[$x][$y] = 1; # 自爆装置セット
                Hako::Log->logBombSet($context->{island_turn}, $id, $name, $landName, $point);
            } else {
                # 目的の場所を防衛施設に
                $land->[$x][$y] = Hako::Constants::LAND_DEFENCE;
                $landValue->[$x][$y] = 0;
                Hako::Log->logLandSuc($context->{island_turn}, $id, $name, $comName, $point);
            }
        } elsif ($kind == Hako::Constants::COMMAND_MONUMENT) {
            # 記念碑
            if ($landKind == Hako::Constants::LAND_MONUMENT) {
                # すでに記念碑の場合
                # ターゲット取得
                my $tn = $context->{id_to_number}->{$target};
                if ($tn eq '') {
                    # ターゲットがすでにない
                    # 何も言わずに中止
                    return 0;
                }
                my $tIsland = $context->{islands}->[$tn];
                $tIsland->{'bigmissile'}++;

                # その場所は荒地に
                $land->[$x][$y] = Hako::Constants::LAND_WASTE;
                $landValue->[$x][$y] = 0;
                Hako::Log->logMonFly($context->{island_turn}, $id, $name, $landName, $point);
            } else {
                # 目的の場所を記念碑に
                $land->[$x][$y] = Hako::Constants::LAND_MONUMENT;
                if ($arg >= Hako::Config::MONUMENT_NUMBER) {
                    $arg = 0;
                }
                $landValue->[$x][$y] = $arg;
                Hako::Log->logLandSuc($context->{island_turn}, $id, $name, $comName, $point);
            }
        }

        # 金を差し引く
        $island->{'money'} -= $cost;

        # 回数付きなら、コマンドを戻す
        if (($kind == Hako::Constants::COMMAND_FARM) || ($kind == Hako::Constants::COMMAND_FACTORY)) {
            if ($arg > 1) {
                $arg--;
                $comArray->[0] = {
                    'kind'   => $kind,
                    'target' => $target,
                    'x'      => $x,
                    'y'      => $y,
                    'arg'    => $arg
                };
                Hako::DB->insert_command($island->{id}, 0, $comArray->[0]);
            }
        }

        return 1;
    } elsif ($kind == Hako::Constants::COMMAND_MOUNTAIN) {
        # 採掘場
        if ($landKind != Hako::Constants::LAND_MOUNTAIN) {
            # 山以外には作れない
            Hako::Log->logLandFail($context->{island_turn}, $id, $name, $comName, $landName, $point);
            return 0;
        }

        $landValue->[$x][$y] += 5; # 規模 + 5000人
        if ($landValue->[$x][$y] > 200) {
            $landValue->[$x][$y] = 200; # 最大 200000人
        }
        Hako::Log->logLandSuc($context->{island_turn}, $id, $name, $comName, $point);

        # 金を差し引く
        $island->{'money'} -= $cost;
        if ($arg > 1) {
            $arg--;
            $comArray->[0] = {
                'kind'   => $kind,
                'target' => $target,
                'x'      => $x,
                'y'      => $y,
                'arg'    => $arg
            };
            Hako::DB->insert_command($island->{id}, 0, $comArray->[0]);
        }
        return 1;
    } elsif ($kind == Hako::Constants::COMMAND_SEA_BASE) {
        # 海底基地
        if ($landKind != Hako::Constants::LAND_SEA || $lv != 0){
            # 海以外には作れない
            Hako::Log->logLandFail($context->{island_turn}, $id, $name, $comName, $landName, $point);
            return 0;
        }

        $land->[$x][$y] = Hako::Constants::LAND_SEA_BASE;
        $landValue->[$x][$y] = 0; # 経験値0
        Hako::Log->logLandSuc($context->{island_turn}, $id, $name, $comName, '(?, ?)');

        # 金を差し引く
        $island->{'money'} -= $cost;
        return 1;
    } elsif (($kind == Hako::Constants::COMMAND_MISSILE_NM) ||
        ($kind == Hako::Constants::COMMAND_MISSILE_PP) ||
        ($kind == Hako::Constants::COMMAND_MISSILE_ST) ||
        ($kind == Hako::Constants::COMMAND_MISSILE_LD)) {
        # ミサイル系
        # ターゲット取得
        my $tn = $context->{id_to_number}->{$target};
        if ($tn eq '') {
            # ターゲットがすでにない
            Hako::Log->logMsNoTarget($context->{island_turn}, $id, $name, $comName);
            return 0;
        }

        my $flag = 0;
        if ($arg == 0) {
            # 0の場合は撃てるだけ
            $arg = 10000;
        }

        # 事前準備
        my $tIsland = $context->{islands}->[$tn];
        my $tName = $tIsland->{'name'};
        my $tLand = $tIsland->{'land'};
        my $tLandValue = $tIsland->{'landValue'};
        my($tx, $ty, $err);

        # 難民の数
        my $boat = 0;

        # 誤差
        if ($kind == Hako::Constants::COMMAND_MISSILE_PP) {
            $err = 7;
        } else {
            $err = 19;
        }

        # 金が尽きるか指定数に足りるか基地全部が撃つまでループ
        my ($bx, $by, $count) = (0, 0, 0);
        while (($arg > 0) &&
            ($island->{'money'} >= $cost)) {
            # 基地を見つけるまでループ
            while ($count < Hako::Config::POINT_NUMBER) {
                $bx = $context->{rpx}->[$count];
                $by = $context->{rpy}->[$count];
                if (($land->[$bx][$by] == Hako::Constants::LAND_BASE) ||
                    ($land->[$bx][$by] == Hako::Constants::LAND_SEA_BASE)) {
                    last;
                }
                $count++;
            }
            if ($count >= Hako::Config::POINT_NUMBER) {
                # 見つからなかったらそこまで
                last;
            }
            # 最低一つ基地があったので、flagを立てる
            $flag = 1;

            # 基地のレベルを算出
            my $level = expToLevel($land->[$bx][$by], $landValue->[$bx][$by]);
            # 基地内でループ
            while (($level > 0) &&
                ($arg > 0) &&
                ($island->{'money'} > $cost)) {
                # 撃ったのが確定なので、各値を消耗させる
                $level--;
                $arg--;
                $island->{'money'} -= $cost;

                # 着弾点算出
                my $r = Hako::Util::random($err);
                my $tx = $x + $ax[$r];
                my $ty = $y + $ay[$r];
                if ($ty % 2 == 0 && $y % 2 == 1) {
                    $tx--;
                }

                # 着弾点範囲内外チェック
                if (($tx < 0) || ($tx >= Hako::Config::ISLAND_SIZE) ||
                    ($ty < 0) || ($ty >= Hako::Config::ISLAND_SIZE)) {
                    # 範囲外
                    if ($kind == Hako::Constants::COMMAND_MISSILE_ST) {
                        # ステルス
                        Hako::Log->logMsOutS($context->{island_turn}, $id, $target, $name, $tName, $comName, $point);
                    } else {
                        # 通常系
                        Hako::Log->logMsOut($context->{island_turn}, $id, $target, $name, $tName, $comName, $point);
                    }
                    next;
                }

                # 着弾点の地形等算出
                my $tL = $tLand->[$tx][$ty];
                my $tLv = $tLandValue->[$tx][$ty];
                my $tLname = landName($tL, $tLv);
                my $tPoint = "($tx, $ty)";

                # 防衛施設判定
                my $defence = 0;
                # FIXME: defence_hex が空なのでバグ？
                if ($context->{defence_hex}->[$id][$tx][$ty] == 1) {
                    $defence = 1;
                } elsif($context->{defence_hex}->[$id][$tx][$ty] == -1) {
                    $defence = 0;
                } else {
                    if ($tL == Hako::Constants::LAND_DEFENCE) {
                        # 防衛施設に命中
                        # フラグをクリア
                        my($i, $count, $sx, $sy);
                        for (my $i = 0; $i < 19; $i++) {
                            my $sx = $tx + $ax[$i];
                            my $sy = $ty + $ay[$i];

                            # 行による位置調整
                            if ($sy % 2 == 0 && $ty % 2 == 1) {
                                $sx--;
                            }

                            if (($sx < 0) || ($sx >= Hako::Config::ISLAND_SIZE) ||
                                ($sy < 0) || ($sy >= Hako::Config::ISLAND_SIZE)) {
                                # 範囲外の場合何もしない
                            } else {
                                # 範囲内の場合
                                $context->{defence_hex}->[$id][$sx][$sy] = 0;
                            }
                        }
                    } elsif (countAround($tLand, $tx, $ty, Hako::Constants::LAND_DEFENCE, 19)) {
                        $context->{defence_hex}->[$id][$tx][$ty] = 1;
                        $defence = 1;
                    } else {
                        $context->{defence_hex}->[$id][$tx][$ty] = -1;
                        $defence = 0;
                    }
                }

                if ($defence == 1) {
                    # 空中爆破
                    if ($kind == Hako::Constants::COMMAND_MISSILE_ST) {
                        # ステルス
                        Hako::Log->logMsCaughtS($context->{island_turn}, $id, $target, $name, $tName, $comName, $point, $tPoint);
                    } else {
                        # 通常系
                        Hako::Log->logMsCaught($context->{island_turn}, $id, $target, $name, $tName, $comName, $point, $tPoint);
                    }
                    next;
                }

                # 「効果なし」hexを最初に判定
                if ((($tL == Hako::Constants::LAND_SEA) && ($tLv == 0))|| # 深い海
                    ((($tL == Hako::Constants::LAND_SEA) ||   # 海または・・・
                            ($tL == Hako::Constants::LAND_SEA_BASE) ||   # 海底基地または・・・
                            ($tL == Hako::Constants::LAND_MOUNTAIN)) # 山で・・・
                        && ($kind != Hako::Constants::COMMAND_MISSILE_LD))) { # 陸破弾以外
                    # 海底基地の場合、海のフリ
                    if ($tL == Hako::Constants::LAND_SEA_BASE) {
                        $tL = Hako::Constants::LAND_SEA;
                    }
                    $tLname = landName($tL, $tLv);

                    # 無効化
                    if($kind == Hako::Constants::COMMAND_MISSILE_ST) {
                        # ステルス
                        Hako::Log->logMsNoDamageS($context->{island_turn}, $id, $target, $name, $tName, $comName, $tLname, $point, $tPoint);
                    } else {
                        # 通常系
                        Hako::Log->logMsNoDamage($context->{island_turn}, $id, $target, $name, $tName, $comName, $tLname, $point, $tPoint);
                    }
                    next;
                }

                # 弾の種類で分岐
                if ($kind == Hako::Constants::COMMAND_MISSILE_LD) {
                    # 陸地破壊弾
                    if ($tL == Hako::Constants::LAND_MOUNTAIN) {
                        # 山(荒地になる)
                        Hako::Log->logMsLDMountain($context->{island_turn}, $id, $target, $name, $tName, $comName, $tLname, $point, $tPoint);
                        # 荒地になる
                        $tLand->[$tx][$ty] = Hako::Constants::LAND_WASTE;
                        $tLandValue->[$tx][$ty] = 0;
                        next;

                    } elsif ($tL == Hako::Constants::LAND_SEA_BASE) {
                        # 海底基地
                        Hako::Log->logMsLDSbase($context->{island_turn}, $id, $target, $name, $tName, $comName, $tLname, $point, $tPoint);
                    } elsif ($tL == Hako::Constants::LAND_MONSTER) {
                        # 怪獣
                        Hako::Log->logMsLDMonster($context->{island_turn}, $id, $target, $name, $tName, $comName, $tLname, $point, $tPoint);
                    } elsif ($tL == Hako::Constants::LAND_SEA) {
                        # 浅瀬
                        Hako::Log->logMsLDSea1($context->{island_turn}, $id, $target, $name, $tName, $comName, $tLname, $point, $tPoint);
                    } else {
                        # その他
                        Hako::Log->logMsLDLand($context->{island_turn}, $id, $target, $name, $tName, $comName, $tLname, $point, $tPoint);
                    }

                    # 経験値
                    if ($tL == Hako::Constants::LAND_TOWN) {
                        if (($land->[$bx][$by] == Hako::Constants::LAND_BASE) ||
                            ($land->[$bx][$by] == Hako::Constants::LAND_SEA_BASE)) {
                            # まだ基地の場合のみ
                            $landValue->[$bx][$by] += int($tLv / 20);
                            if ($landValue->[$bx][$by] > Hako::Config::MAX_EXP_POINT) {
                                $landValue->[$bx][$by] = Hako::Config::MAX_EXP_POINT;
                            }
                        }
                    }

                    # 浅瀬になる
                    $tLand->[$tx][$ty] = Hako::Constants::LAND_SEA;
                    $tIsland->{'area'}--;
                    $tLandValue->[$tx][$ty] = 1;

                    # でも油田、浅瀬、海底基地だったら海
                    if (($tL == Hako::Constants::LAND_OIL) ||
                        ($tL == Hako::Constants::LAND_SEA) ||
                        ($tL == Hako::Constants::LAND_SEA_BASE)) {
                        $tLandValue->[$tx][$ty] = 0;
                    }
                } else {
                    # その他ミサイル
                    if ($tL == Hako::Constants::LAND_WASTE) {
                        # 荒地(被害なし)
                        if ($kind == Hako::Constants::COMMAND_MISSILE_ST) {
                            # ステルス
                            Hako::Log->logMsWasteS($context->{island_turn}, $id, $target, $name, $tName, $comName, $tLname, $point, $tPoint);
                        } else {
                            # 通常
                            Hako::Log->logMsWaste($context->{island_turn}, $id, $target, $name, $tName, $comName, $tLname, $point, $tPoint);
                        }
                    } elsif ($tL == Hako::Constants::LAND_MONSTER) {
                        # 怪獣
                        my ($mKind, $mName, $mHp) = monsterSpec($tLv);
                        my $special = ${Hako::Config::MONSTER_SPECIAL()}[$mKind];

                        # 硬化中?
                        if ((($special == 3) && (($context->{island_turn} % 2) == 1)) ||
                            (($special == 4) && (($context->{island_turn} % 2) == 0))) {
                            # 硬化中
                            if ($kind == Hako::Constants::COMMAND_MISSILE_ST) {
                                # ステルス
                                Hako::Log->logMsMonNoDamageS($context->{island_turn}, $id, $target, $name, $tName, $comName, $mName, $point, $tPoint);
                            } else {
                                # 通常弾
                                Hako::Log->logMsMonNoDamage($context->{island_turn}, $id, $target, $name, $tName, $comName, $mName, $point, $tPoint);
                            }
                            next;
                        } else {
                            # 硬化中じゃない
                            if ($mHp == 1) {
                                # 怪獣しとめた
                                if (($land->[$bx][$by] == Hako::Constants::LAND_BASE) ||
                                    ($land->[$bx][$by] == Hako::Constants::LAND_SEA_BASE)) {
                                    # 経験値
                                    $landValue->[$bx][$by] += ${Hako::Config::MONSTER_EXP()}[$mKind];
                                    if ($landValue->[$bx][$by] > Hako::Config::MAX_EXP_POINT) {
                                        $landValue->[$bx][$by] = Hako::Config::MAX_EXP_POINT;
                                    }
                                }

                                if ($kind == Hako::Constants::COMMAND_MISSILE_ST) {
                                    # ステルス
                                    Hako::Log->logMsMonKillS($context->{island_turn}, $id, $target, $name, $tName, $comName, $mName, $point, $tPoint);
                                } else {
                                    # 通常
                                    Hako::Log->logMsMonKill($context->{island_turn}, $id, $target, $name, $tName, $comName, $mName, $point, $tPoint);
                                }

                                # 収入
                                my $value = ${Hako::Config::MONSTER_VALUE()}[$mKind];
                                if ($value > 0) {
                                    $tIsland->{'money'} += $value;
                                    Hako::Log->logMsMonMoney($context->{island_turn}, $target, $mName, $value);
                                }

                                # 賞関係
                                my $prize = $island->{'prize'};
                                $prize =~ /([0-9]*),([0-9]*),(.*)/;
                                my $flags = $1;
                                my $monsters = $2;
                                my $turns = $3;
                                my $v = 2 ** $mKind;
                                $monsters |= $v;
                                $island->{'prize'} = "$flags,$monsters,$turns";
                            } else {
                                # 怪獣生きてる
                                if ($kind == Hako::Constants::COMMAND_MISSILE_ST) {
                                    # ステルス
                                    Hako::Log->logMsMonsterS($context->{island_turn}, $id, $target, $name, $tName, $comName, $mName, $point, $tPoint);
                                } else {
                                    # 通常
                                    Hako::Log->logMsMonster($context->{island_turn}, $id, $target, $name, $tName, $comName, $mName, $point, $tPoint);
                                }
                                # HPが1減る
                                $tLandValue->[$tx][$ty]--;
                                next;
                            }
                        }
                    } else {
                        # 通常地形
                        if ($kind == Hako::Constants::COMMAND_MISSILE_ST) {
                            # ステルス
                            Hako::Log->logMsNormalS($context->{island_turn}, $id, $target, $name, $tName, $comName, $tLname, $point, $tPoint);
                        } else {
                            # 通常
                            Hako::Log->logMsNormal($context->{island_turn}, $id, $target, $name, $tName, $comName, $tLname, $point, $tPoint);
                        }
                    }
                    # 経験値
                    if ($tL == Hako::Constants::LAND_TOWN) {
                        if (($land->[$bx][$by] == Hako::Constants::LAND_BASE) ||
                            ($land->[$bx][$by] == Hako::Constants::LAND_SEA_BASE)) {
                            $landValue->[$bx][$by] += int($tLv / 20);
                            $boat += $tLv; # 通常ミサイルなので難民にプラス
                            if ($landValue->[$bx][$by] > Hako::Config::MAX_EXP_POINT) {
                                $landValue->[$bx][$by] = Hako::Config::MAX_EXP_POINT;
                            }
                        }
                    }

                    # 荒地になる
                    $tLand->[$tx][$ty] = Hako::Constants::LAND_WASTE;
                    $tLandValue->[$tx][$ty] = 1; # 着弾点

                    # でも油田だったら海
                    if ($tL == Hako::Constants::LAND_OIL) {
                        $tLand->[$tx][$ty] = Hako::Constants::LAND_SEA;
                        $tLandValue->[$tx][$ty] = 0;
                    }
                }
            }

            # カウント増やしとく
            $count++;
        }

        if ($flag == 0) {
            # 基地が一つも無かった場合
            Hako::Log->logMsNoBase($context->{island_turn}, $id, $name, $comName);
            return 0;
        }

        # 難民判定
        $boat = int($boat / 2);
        if (($boat > 0) && ($id != $target) && ($kind != Hako::Constants::COMMAND_MISSILE_ST)) {
            # 難民漂着
            my $achive; # 到達難民
            for (my $i = 0; ($i < Hako::Config::POINT_NUMBER && $boat > 0); $i++) {
                $bx = $context->{rpx}->[$i];
                $by = $context->{rpy}->[$i];
                if ($land->[$bx][$by] == Hako::Constants::LAND_TOWN) {
                    # 町の場合
                    my $lv = $landValue->[$bx][$by];
                    if ($boat > 50) {
                        $lv += 50;
                        $boat -= 50;
                        $achive += 50;
                    } else {
                        $lv += $boat;
                        $achive += $boat;
                        $boat = 0;
                    }
                    if ($lv > 200) {
                        $boat += ($lv - 200);
                        $achive -= ($lv - 200);
                        $lv = 200;
                    }
                    $landValue->[$bx][$by] = $lv;
                } elsif ($land->[$bx][$by] == Hako::Constants::LAND_PLAINS) {
                    # 平地の場合
                    $land->[$bx][$by] = Hako::Constants::LAND_TOWN;;
                    if ($boat > 10) {
                        $landValue->[$bx][$by] = 5;
                        $boat -= 10;
                        $achive += 10;
                    } elsif ($boat > 5) {
                        $landValue->[$bx][$by] = $boat - 5;
                        $achive += $boat;
                        $boat = 0;
                    }
                }
                if ($boat <= 0) {
                    last;
                }
            }
            if ($achive > 0) {
                # 少しでも到着した場合、ログを吐く
                Hako::Log->logMsBoatPeople($context->{island_turn}, $id, $name, $achive);

                # 難民の数が一定数以上なら、平和賞の可能性あり
                if ($achive >= 200) {
                    my $prize = $island->{'prize'};
                    $prize =~ /([0-9]*),([0-9]*),(.*)/;
                    my $flags = $1;
                    my $monsters = $2;
                    my $turns = $3;

                    if ((!($flags & 8)) &&  $achive >= 200){
                        $flags |= 8;
                        Hako::Log->logPrize($context->{island_turn}, $id, $name, ${Hako::Config::PRIZE()}[4]);
                    } elsif ((!($flags & 16)) &&  $achive > 500){
                        $flags |= 16;
                        Hako::Log->logPrize($context->{island_turn}, $id, $name, ${Hako::Config::PRIZE()}[5]);
                    } elsif ((!($flags & 32)) &&  $achive > 800){
                        $flags |= 32;
                        Hako::Log->logPrize($context->{island_turn}, $id, $name, ${Hako::Config::PRIZE()}[6]);
                    }
                    $island->{'prize'} = "$flags,$monsters,$turns";
                }
            }
        }
        return 1;
    } elsif ($kind == Hako::Constants::COMMAND_SEND_MONSTER) {
        # 怪獣派遣
        # ターゲット取得
        my $tn = $context->{id_to_number}->{$target};
        my $tIsland  = $context->{islands}->[$tn];
        my $tName = $tIsland->{'name'};

        if ($tn eq '') {
            # ターゲットがすでにない
            Hako::Log->logMsNoTarget($context->{island_turn}, $id, $name, $comName);
            return 0;
        }

        # メッセージ
        Hako::Log->logMonsSend($context->{island_turn}, $id, $target, $name, $tName);
        $tIsland->{'monstersend'}++;

        $island->{'money'} -= $cost;
        return 1;
    } elsif ($kind == Hako::Constants::COMMAND_SELL) {
        # 輸出量決定
        $arg = 1 if ($arg == 0);
        my $value = Hako::Util::min($arg * (-$cost), $island->{'food'});

        # 輸出ログ
        Hako::Log->logSell($context->{island_turn}, $id, $name, $comName, $value);
        $island->{'food'} -=  $value;
        $island->{'money'} += ($value / 10);
        return 0;
    } elsif (($kind == Hako::Constants::COMMAND_MONEY) ||
        ($kind == Hako::Constants::COMMAND_MONEY)) {
        # 援助系
        # ターゲット取得
        my $tn = $context->{id_to_number}->{$target};
        my $tIsland  = $context->{islands}->[$tn];
        my $tName = $tIsland->{'name'};

        # 援助量決定
        $arg = 1 if($arg == 0);
        my ($value, $str);
        if ($cost < 0) {
            $value = Hako::Util::min($arg * (-$cost), $island->{'food'});
            $str = "$value" . Hako::Config::UNIT_FOOD;
        } else {
            $value = Hako::Util::min($arg * ($cost), $island->{'money'});
            $str = "$value" . Hako::Config::UNIT_MONEY;
        }

        # 援助ログ
        Hako::Log->logAid($context->{island_turn}, $id, $target, $name, $tName, $comName, $str);

        if ($cost < 0) {
            $island->{'food'} -= $value;
            $tIsland->{'food'} += $value;
        } else {
            $island->{'money'} -= $value;
            $tIsland->{'money'} += $value;
        }
        return 0;
    } elsif ($kind == Hako::Constants::COMMAND_PROPAGANDA) {
        # 誘致活動
        Hako::Log->logPropaganda($context->{island_turn}, $id, $name, $comName);
        $island->{'propaganda'} = 1;
        $island->{'money'} -= $cost;
        return 1;
    } elsif ($kind == Hako::Constants::COMMAND_GIVE_UP) {
        # 放棄
        Hako::Log->logGiveup($context->{island_turn}, $id, $name);
        $island->{'dead'} = 1;
        return 1;
    }

    return 1;
}

# 成長および単ヘックス災害
sub doEachHex {
    my ($context, $island) = @_;
    my @monsterMove;

    # 導出値
    my $name = $island->{'name'};
    my $id = $island->{'id'};
    my $land = $island->{'land'};
    my $landValue = $island->{'landValue'};

    # 増える人口のタネ値
    my $addpop  = 10;  # 村、町
    my $addpop2 = 0; # 都市
    if ($island->{'food'} < 0) {
        # 食料不足
        $addpop = -30;
    } elsif ($island->{'propaganda'} == 1) {
        # 誘致活動中
        $addpop = 30;
        $addpop2 = 3;
    }

    # ループ
    for (my $i = 0; $i < Hako::Config::POINT_NUMBER; $i++) {
        my $x = $context->{rpx}->[$i];
        my $y = $context->{rpy}->[$i];
        my $landKind = $land->[$x][$y];
        my $lv = $landValue->[$x][$y];

        if ($landKind == Hako::Constants::LAND_TOWN) {
            # 町系
            if ($addpop < 0) {
                # 不足
                $lv -= (Hako::Util::random(-$addpop) + 1);
                if($lv <= 0) {
                    # 平地に戻す
                    $land->[$x][$y] = Hako::Constants::LAND_PLAINS;
                    $landValue->[$x][$y] = 0;
                    next;
                }
            } else {
                # 成長
                if ($lv < 100) {
                    $lv += Hako::Util::random($addpop) + 1;
                    if ($lv > 100) {
                        $lv = 100;
                    }
                } else {
                    # 都市になると成長遅い
                    if ($addpop2 > 0) {
                        $lv += Hako::Util::random($addpop2) + 1;
                    }
                }
            }
            if ($lv > 200) {
                $lv = 200;
            }
            $landValue->[$x][$y] = $lv;
        } elsif ($landKind == Hako::Constants::LAND_PLAINS) {
            # 平地
            if(Hako::Util::random(5) == 0) {
                # 周りに農場、町があれば、ここも町になる
                if (countGrow($land, $landValue, $x, $y)){
                    $land->[$x][$y] = Hako::Constants::LAND_TOWN;
                    $landValue->[$x][$y] = 1;
                }
            }
        } elsif ($landKind == Hako::Constants::LAND_FOREST) {
            # 森
            if ($lv < 200) {
                # 木を増やす
                $landValue->[$x][$y]++;
            }
        } elsif ($landKind == Hako::Constants::LAND_DEFENCE) {
            if ($lv == 1) {
                # 防衛施設自爆
                my $lName = landName($landKind, $lv);
                Hako::Log->logBombFire($context->{island_turn}, $id, $name, $lName, "($x, $y)");

                # 広域被害ルーチン
                wideDamage($context, $id, $name, $land, $landValue, $x, $y);
            }
        } elsif($landKind == Hako::Constants::LAND_OIL) {
            # 海底油田
            my $lName = landName($landKind, $lv);
            my $value = Hako::Config::OIL_MONEY;
            $island->{'money'} += $value;
            my $str = "$value" . Hako::Config::UNIT_MONEY;

            # 収入ログ
            Hako::Log->logOilMoney($context->{island_turn}, $id, $name, $lName, "($x, $y)", $str);

            # 枯渇判定
            if (Hako::Util::random(1000) < Hako::Config::OIL_RATIO) {
                # 枯渇
                Hako::Log->logOilEnd($context->{island_turn}, $id, $name, $lName, "($x, $y)");
                $land->[$x][$y] = Hako::Constants::LAND_SEA;
                $landValue->[$x][$y] = 0;
            }

        } elsif ($landKind == Hako::Constants::LAND_MONSTER) {
            # 怪獣
            if ($monsterMove[$x][$y] == 2) {
                # すでに動いた後
                next;
            }

            # 各要素の取り出し
            my ($mKind, $mName, $mHp) = monsterSpec($landValue->[$x][$y]);
            my $special = ${Hako::Config::MONSTER_SPECIAL()}[$mKind];

            # 硬化中?
            if ((($special == 3) && (($context->{island_turn} % 2) == 1)) ||
                (($special == 4) && (($context->{island_turn} % 2) == 0))) {
                # 硬化中
                next;
            }

            # 動く方向を決定
            my ($i, $sx, $sy);
            for ($i = 0; $i < 3; $i++) {
                my $d = Hako::Util::random(6) + 1;
                $sx = $x + $ax[$d];
                $sy = $y + $ay[$d];

                # 行による位置調整
                if ((($sy % 2) == 0) && (($y % 2) == 1)) {
                    $sx--;
                }

                # 範囲外判定
                if (($sx < 0) || ($sx >= Hako::Config::ISLAND_SIZE) ||
                    ($sy < 0) || ($sy >= Hako::Config::ISLAND_SIZE)) {
                    next;
                }

                # 海、海基、油田、怪獣、山、記念碑以外
                if (($land->[$sx][$sy] != Hako::Constants::LAND_SEA) &&
                    ($land->[$sx][$sy] != Hako::Constants::LAND_SEA_BASE) &&
                    ($land->[$sx][$sy] != Hako::Constants::LAND_OIL) &&
                    ($land->[$sx][$sy] != Hako::Constants::LAND_MOUNTAIN) &&
                    ($land->[$sx][$sy] != Hako::Constants::LAND_MONUMENT) &&
                    ($land->[$sx][$sy] != Hako::Constants::LAND_MONSTER)) {
                    last;
                }
            }

            if ($i == 3) {
                # 動かなかった
                next;
            }

            # 動いた先の地形によりメッセージ
            my $l = $land->[$sx][$sy];
            my $lv = $landValue->[$sx][$sy];
            my $lName = landName($l, $lv);
            my $point = "($sx, $sy)";

            # 移動
            $land->[$sx][$sy] = $land->[$x][$y];
            $landValue->[$sx][$sy] = $landValue->[$x][$y];

            # もと居た位置を荒地に
            $land->[$x][$y] = Hako::Constants::LAND_WASTE;
            $landValue->[$x][$y] = 0;

            # 移動済みフラグ
            if (${Hako::Config::MONSTER_SPECIAL()}[$mKind] == 2) {
                # 移動済みフラグは立てない
            } elsif (${Hako::Config::MONSTER_SPECIAL()}[$mKind] == 1) {
                # 速い怪獣
                $monsterMove[$sx][$sy] = $monsterMove[$x][$y] + 1;
            } else {
                # 普通の怪獣
                $monsterMove[$sx][$sy] = 2;
            }

            if (($l == Hako::Constants::LAND_DEFENCE) && (Hako::Config::DEFENCE_BASE_AUTO == 1)) {
                # 防衛施設を踏んだ
                Hako::Log->logMonsMoveDefence($context->{island_turn}, $id, $name, $lName, $point, $mName);

                # 広域被害ルーチン
                wideDamage($context, $id, $name, $land, $landValue, $sx, $sy);
            } else {
                # 行き先が荒地になる
                Hako::Log->logMonsMove($context->{island_turn}, $id, $name, $lName, $point, $mName);
            }
        }

        # 火災判定
        if ((($landKind == Hako::Constants::LAND_TOWN) && ($lv > 30)) ||
            ($landKind == Hako::Constants::LAND_HARIBOTE) ||
            ($landKind == Hako::Constants::LAND_FACTORY)) {
            if (Hako::Util::random(1000) < Hako::Config::DISASTER_FIRE) {
                # 周囲の森と記念碑を数える
                if ((countAround($land, $x, $y, Hako::Constants::LAND_FOREST, 7) +
                        countAround($land, $x, $y, Hako::Constants::LAND_MONUMENT, 7)) == 0) {
                    # 無かった場合、火災で壊滅
                    my $l = $land->[$x][$y];
                    my $lv = $landValue->[$x][$y];
                    my $point = "($x, $y)";
                    my $lName = landName($l, $lv);
                    Hako::Log->logFire($context->{island_turn}, $id, $name, $lName, $point);
                    $land->[$x][$y] = Hako::Constants::LAND_WASTE;
                    $landValue->[$x][$y] = 0;
                }
            }
        }
    }
}

# 範囲内の地形を数える
sub countAround {
    my ($land, $x, $y, $kind, $range) = @_;
    my $count = 0;
    for (my $i = 0; $i < $range; $i++) {
        my $sx = $x + $ax[$i];
        my $sy = $y + $ay[$i];

        # 行による位置調整
        if ($sy % 2 == 0 && $y % 2 == 1) {
            $sx--;
        }

        if (($sx < 0) || ($sx >= Hako::Config::ISLAND_SIZE) ||
            ($sy < 0) || ($sy >= Hako::Config::ISLAND_SIZE)) {
            # 範囲外の場合
            if ($kind == Hako::Constants::LAND_SEA) {
                # 海なら加算
                $count++;
            }
        } else {
            # 範囲内の場合
            if ($land->[$sx][$sy] == $kind) {
                $count++;
            }
        }
    }
    return $count;
}

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
                Hako::Log->logWideDamageSea2($context->{island_turn}, $id, $name, $landName, $point);
                $land->[$sx][$sy] = Hako::Constants::LAND_SEA;
                $landValue->[$sx][$sy] = 0;
            } else {
                if ($landKind == Hako::Constants::LAND_MONSTER) {
                    Hako::Log->logWideDamageMonsterSea($context->{island_turn}, $id, $name, $landName, $point);
                } else {
                    Hako::Log->logWideDamageSea($context->{island_turn}, $id, $name, $landName, $point);
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
                Hako::Log->logWideDamageMonster($context->{island_turn}, $id, $name, $landName, $point);
                $land->[$sx][$sy] = Hako::Constants::LAND_WASTE;
                $landValue->[$sx][$sy] = 0;
            } else {
                Hako::Log->logWideDamageWaste($context->{island_turn}, $id, $name, $landName, $point);
                $land->[$sx][$sy] = Hako::Constants::LAND_WASTE;
                $landValue->[$sx][$sy] = 0;
            }
        }
    }
}

# 島全体
sub doIslandProcess {
    my ($context, $number, $island) = @_;

    # 導出値
    my $name = $island->{'name'};
    my $id = $island->{'id'};
    my $land = $island->{'land'};
    my $landValue = $island->{'landValue'};

    # 地震判定
    if (Hako::Util::random(1000) < (($island->{'prepare2'} + 1) * Hako::Config::DISASTER_EARTHQUAKE)) {
        # 地震発生
        Hako::Log->logEarthquake($context->{island_turn}, $id, $name);

        for (my $i = 0; $i < Hako::Config::POINT_NUMBER; $i++) {
            my $x = $context->{rpx}->[$i];
            my $y = $context->{rpy}->[$i];
            my $landKind = $land->[$x][$y];
            my $lv = $landValue->[$x][$y];

            if ((($landKind == Hako::Constants::LAND_TOWN) && ($lv >= 100)) ||
                ($landKind == Hako::Constants::LAND_HARIBOTE) ||
                ($landKind == Hako::Constants::LAND_FACTORY)) {
                # 1/4で壊滅
                if (Hako::Uitl::random(4) == 0) {
                    Hako::Log->logEQDamage($context->{island_turn}, $id, $name, landName($landKind, $lv), "($x, $y)");
                    $land->[$x][$y] = Hako::Constants::LAND_WASTE;
                    $landValue->[$x][$y] = 0;
                }
            }

        }
    }

    # 食料不足
    if ($island->{'food'} <= 0) {
        # 不足メッセージ
        Hako::Log->logStarve($context->{island_turn}, $id, $name);
        $island->{'food'} = 0;

        my($x, $y, $landKind, $lv, $i);
        for (my $i = 0; $i < Hako::Config::POINT_NUMBER; $i++) {
            my $x = $context->{rpx}->[$i];
            my $y = $context->{rpy}->[$i];
            my $landKind = $land->[$x][$y];
            my $lv = $landValue->[$x][$y];

            if (($landKind == Hako::Constants::LAND_FARM) ||
                ($landKind == Hako::Constants::LAND_FACTORY) ||
                ($landKind == Hako::Constants::LAND_BASE) ||
                ($landKind == Hako::Constants::LAND_DEFENCE)) {
                # 1/4で壊滅
                if (Hako::Util::random(4) == 0) {
                    Hako::Log->logSvDamage($context->{island_turn}, $id, $name, landName($landKind, $lv), "($x, $y)");
                    $land->[$x][$y] = Hako::Constants::LAND_WASTE;
                    $landValue->[$x][$y] = 0;
                }
            }
        }
    }

    # 津波判定
    if (Hako::Util::random(1000) < Hako::Config::DISASTER_TSUNAMI) {
        # 津波発生
        Hako::Log->logTsunami($context->{island_turn}, $id, $name);

        for (my $i = 0; $i < Hako::Config::POINT_NUMBER; $i++) {
            my $x = $context->{rpx}->[$i];
            my $y = $context->{rpy}->[$i];
            my $landKind = $land->[$x][$y];
            my $lv = $landValue->[$x][$y];

            if (($landKind == Hako::Constants::LAND_TOWN) ||
                ($landKind == Hako::Constants::LAND_FARM) ||
                ($landKind == Hako::Constants::LAND_FACTORY) ||
                ($landKind == Hako::Constants::LAND_BASE) ||
                ($landKind == Hako::Constants::LAND_DEFENCE) ||
                ($landKind == Hako::Constants::LAND_HARIBOTE)) {
                # 1d12 <= (周囲の海 - 1) で崩壊
                if (Hako::Util::random(12) <
                    (countAround($land, $x, $y, Hako::Constants::LAND_OIL, 7) +
                        countAround($land, $x, $y, Hako::Constants::LAND_SEA_BASE, 7) +
                        countAround($land, $x, $y, Hako::Constants::LAND_SEA, 7) - 1)) {
                    Hako::Log->logTsunamiDamage($context->{island_turn}, $id, $name, landName($landKind, $lv), "($x, $y)");
                    $land->[$x][$y] = Hako::Constants::LAND_WASTE;
                    $landValue->[$x][$y] = 0;
                }
            }
        }
    }

    # 怪獣判定
    my $r = Hako::Util::random(10000);
    my $pop = $island->{'pop'};
    do{
        if ((($r < (Hako::Config::DISASTER_MONSTER * $island->{'area'})) &&
                ($pop >= Hako::Config::DISASTER_MONSTER_BORDER1)) ||
            ($island->{'monstersend'} > 0)) {
            # 怪獣出現
            # 種類を決める
            my $kind;
            if($island->{'monstersend'} > 0) {
                # 人造
                $kind = 0;
                $island->{'monstersend'}--;
            } elsif ($pop >= Hako::Config::DISASTER_MONSTER_BORDER3) {
                # level3まで
                $kind = Hako::Util::random(Hako::Config::MONSTER_LEVEL3) + 1;
            } elsif ($pop >= Hako::Config::DISASTER_MONSTER_BORDER2) {
                # level2まで
                $kind = Hako::Util::random(Hako::Config::MONSTER_LEVEL2) + 1;
            } else {
                # level1のみ
                $kind = Hako::Util::random(Hako::Config::MONSTER_LEVEL1) + 1;
            }

            # lvの値を決める
            my $lv = $kind * 10 + ${Hako::Config::MONSTER_BOTTOM_HP()}[$kind] + Hako::Util::random(${Hako::Config::MONSTER_DHP()}[$kind]);

            # どこに現れるか決める
            for (my $i = 0; $i < Hako::Config::POINT_NUMBER; $i++) {
                my $bx = $context->{rpx}->[$i];
                my $by = $context->{rpy}->[$i];
                if ($land->[$bx][$by] == Hako::Constants::LAND_TOWN) {
                    # 地形名
                    my $lName = landName(Hako::Constants::LAND_TOWN, $landValue->[$bx][$by]);

                    # そのヘックスを怪獣に
                    $land->[$bx][$by] = Hako::Constants::LAND_MONSTER;
                    $landValue->[$bx][$by] = $lv;

                    # 怪獣情報
                    my ($mKind, $mName, $mHp) = monsterSpec($lv);

                    # メッセージ
                    Hako::Log->logMonsCome($context->{island_turn}, $id, $name, $mName, "($bx, $by)", $lName);
                    last;
                }
            }
        }
    } while ($island->{'monstersend'} > 0);

    # 地盤沈下判定
    if (($island->{'area'} > Hako::Config::DISASTER_FALL_BORDER) &&
        (Hako::Util::random(1000) < Hako::Config::DISASTER_FALL_DOWN)) {
        # 地盤沈下発生
        Hako::Log->logFalldown($context->{island_turn}, $id, $name);

        for (my $i = 0; $i < Hako::Config::POINT_NUMBER; $i++) {
            my $x = $context->{rpx}->[$i];
            my $y = $context->{rpy}->[$i];
            my $landKind = $land->[$x][$y];
            my $lv = $landValue->[$x][$y];

            if (($landKind != Hako::Constants::LAND_SEA) &&
                ($landKind != Hako::Constants::LAND_SEA_BASE) &&
                ($landKind != Hako::Constants::LAND_OIL) &&
                ($landKind != Hako::Constants::LAND_MOUNTAIN)) {

                # 周囲に海があれば、値を-1に
                if(countAround($land, $x, $y, Hako::Constants::LAND_SEA, 7) + 
                    countAround($land, $x, $y, Hako::Constants::LAND_SEA_BASE, 7)) {
                    Hako::Log->logFalldownLand($context->{island_turn}, $id, $name, landName($landKind, $lv), "($x, $y)");
                    $land->[$x][$y] = -1;
                    $landValue->[$x][$y] = 0;
                }
            }
        }

        for (my $i = 0; $i < Hako::Config::POINT_NUMBER; $i++) {
            my $x = $context->{rpx}->[$i];
            my $y = $context->{rpy}->[$i];
            my $landKind = $land->[$x][$y];

            if ($landKind == -1) {
                # -1になっている所を浅瀬に
                $land->[$x][$y] = Hako::Constants::LAND_SEA;
                $landValue->[$x][$y] = 1;
            } elsif ($landKind == Hako::Constants::LAND_SEA) {
                # 浅瀬は海に
                $landValue->[$x][$y] = 0;
            }
        }
    }

    # 台風判定
    if (Hako::Util::random(1000) < Hako::Config::DISASTER_TYPHOON) {
        # 台風発生
        Hako::Log->logTyphoon($context->{island_turn}, $id, $name);

        for (my $i = 0; $i < Hako::Config::POINT_NUMBER; $i++) {
            my $x = $context->{rpx}->[$i];
            my $y = $context->{rpy}->[$i];
            my $landKind = $land->[$x][$y];
            my $lv = $landValue->[$x][$y];

            if (($landKind == Hako::Constants::LAND_FARM) ||
                ($landKind == Hako::Constants::LAND_HARIBOTE)) {

                # 1d12 <= (6 - 周囲の森) で崩壊
                if (Hako::Util::random(12) <
                    (6
                        - countAround($land, $x, $y, Hako::Constants::LAND_FOREST, 7)
                        - countAround($land, $x, $y, Hako::Constants::LAND_MONUMENT, 7))) {
                    Hako::Log->logTyphoonDamage($context->{island_turn}, $id, $name, landName($landKind, $lv), "($x, $y)");
                    $land->[$x][$y] = Hako::Constants::LAND_PLAINS;
                    $landValue->[$x][$y] = 0;
                }
            }
        }
    }

    # 巨大隕石判定
    if (Hako::Util::random(1000) < Hako::Config::DISASTER_HUGE_METEO) {
        # 落下
        my $x = random(Hako::Config::ISLAND_SIZE);
        my $y = random(Hako::Config::ISLAND_SIZE);
        my $landKind = $land->[$x][$y];
        my $lv = $landValue->[$x][$y];
        my $point = "($x, $y)";

        # メッセージ
        Hako::Log->logHugeMeteo($context->{island_turn}, $id, $name, $point);

        # 広域被害ルーチン
        wideDamage($context, $id, $name, $land, $landValue, $x, $y);
    }

    # 巨大ミサイル判定
    while ($island->{'bigmissile'} > 0) {
        $island->{'bigmissile'} --;

        # 落下
        my $x = random(Hako::Config::ISLAND_SIZE);
        my $y = random(Hako::Config::ISLAND_SIZE);
        my $landKind = $land->[$x][$y];
        my $lv = $landValue->[$x][$y];
        my $point = "($x, $y)";

        # メッセージ
        Hako::Log->logMonDamage($context->{island_turn}, $id, $name, $point);

        # 広域被害ルーチン
        wideDamage($context, $id, $name, $land, $landValue, $x, $y);
    }

    # 隕石判定
    if (Hako::Util::random(1000) < Hako::Config::DISASTER_METEO) {
        my $first = 1;
        while ((Hako::Util::random(2) == 0) || ($first == 1)) {
            $first = 0;

            # 落下
            my $x = Hako::Util::random(Hako::Config::ISLAND_SIZE);
            my $y = Hako::Util::random(Hako::Config::ISLAND_SIZE);
            my $landKind = $land->[$x][$y];
            my $lv = $landValue->[$x][$y];
            my $point = "($x, $y)";

            if (($landKind == Hako::Constants::LAND_SEA) && ($lv == 0)){
                # 海ポチャ
                Hako::Log->logMeteoSea($context->{island_turn}, $id, $name, landName($landKind, $lv), $point);
            } elsif ($landKind == Hako::Constants::LAND_MOUNTAIN) {
                # 山破壊
                Hako::Log->logMeteoMountain($context->{island_turn}, $id, $name, landName($landKind, $lv), $point);
                $land->[$x][$y] = Hako::Constants::LAND_WASTE;
                $landValue->[$x][$y] = 0;
                next;
            } elsif ($landKind == Hako::Constants::LAND_SEA_BASE) {
                Hako::Log->logMeteoSbase($context->{island_turn}, $id, $name, landName($landKind, $lv), $point);
            } elsif ($landKind == Hako::Constants::LAND_MONSTER) {
                Hako::Log->logMeteoMonster($context->{island_turn}, $id, $name, landName($landKind, $lv), $point);
            } elsif ($landKind == Hako::Constants::LAND_SEA) {
                # 浅瀬
                Hako::Log->logMeteoSea1($context->{island_turn}, $id, $name, landName($landKind, $lv), $point);
            } else {
                Hako::Log->logMeteoNormal($context->{island_turn}, $id, $name, landName($landKind, $lv), $point);
            }
            $land->[$x][$y] = Hako::Constants::LAND_SEA;
            $landValue->[$x][$y] = 0;
        }
    }

    # 噴火判定
    if (Hako::Util::random(1000) < Hako::Config::DISASTER_ERUPTION) {
        my $x = Hako::Util::random(Hako::Config::ISLAND_SIZE);
        my $y = Hako::Util::random(Hako::Config::ISLAND_SIZE);
        my $landKind = $land->[$x][$y];
        my $lv = $landValue->[$x][$y];
        my $point = "($x, $y)";
        Hako::Log->logEruption($context->{island_turn}, $id, $name, landName($landKind, $lv), $point);
        $land->[$x][$y] = Hako::Constants::LAND_MOUNTAIN;
        $landValue->[$x][$y] = 0;

        for (my $i = 1; $i < 7; $i++) {
            my $sx = $x + $ax[$i];
            my $sy = $y + $ay[$i];

            # 行による位置調整
            if ((($sy % 2) == 0) && (($y % 2) == 1)) {
                $sx--;
            }

            $landKind = $land->[$sx][$sy];
            $lv = $landValue->[$sx][$sy];
            $point = "($sx, $sy)";

            if (($sx < 0) || ($sx >= Hako::Config::ISLAND_SIZE) ||
                ($sy < 0) || ($sy >= Hako::Config::ISLAND_SIZE)) {
            } else {
                # 範囲内の場合
                $landKind = $land->[$sx][$sy];
                $lv = $landValue->[$sx][$sy];
                $point = "($sx, $sy)";
                if (($landKind == Hako::Constants::LAND_SEA) ||
                    ($landKind == Hako::Constants::LAND_OIL) ||
                    ($landKind == Hako::Constants::LAND_SEA_BASE)) {
                    # 海の場合
                    if ($lv == 1) {
                        # 浅瀬
                        Hako::Log->logEruptionSea1($context->{island_turn}, $id, $name, landName($landKind, $lv), $point);
                    } else {
                        Hako::Log->logEruptionSea($context->{island_turn}, $id, $name, landName($landKind, $lv), $point);
                        $land->[$sx][$sy] = Hako::Constants::LAND_SEA;
                        $landValue->[$sx][$sy] = 1;
                        next;
                    }
                } elsif (($landKind == Hako::Constants::LAND_MOUNTAIN) ||
                    ($landKind == Hako::Constants::LAND_MONSTER) ||
                    ($landKind == Hako::Constants::LAND_WASTE)) {
                    next;
                } else {
                    # それ以外の場合
                    Hako::Log->logEruptionNormal($context->{island_turn}, $id, $name, landName($landKind, $lv), $point);
                }
                $land->[$sx][$sy] = Hako::Constants::LAND_WASTE;
                $landValue->[$sx][$sy] = 0;
            }
        }
    }

    # 食料があふれてたら換金
    if ($island->{'food'} > 9999) {
        $island->{'money'} += int(($island->{'food'} - 9999) / 10);
        $island->{'food'} = 9999;
    }

    # 金があふれてたら切り捨て
    if ($island->{'money'} > 9999) {
        $island->{'money'} = 9999;
    }

    # 各種の値を計算
    estimate($context, $number);

    # 繁栄、災難賞
    $pop = $island->{'pop'};
    my $damage = $island->{'oldPop'} - $pop;
    my $prize = $island->{'prize'};
    $prize =~ /([0-9]*),([0-9]*),(.*)/;
    my $flags = $1;
    my $monsters = $2;
    my $turns = $3;

    # 繁栄賞
    if ((!($flags & 1)) &&  $pop >= 3000){
        $flags |= 1;
        Hako::Log->logPrize($context->{island_turn}, $id, $name, ${Hako::Config::PRIZE()}[1]);
    } elsif ((!($flags & 2)) &&  $pop >= 5000){
        $flags |= 2;
        Hako::Log->logPrize($context->{island_turn}, $id, $name, ${Hako::Config::PRIZE()}[2]);
    } elsif ((!($flags & 4)) &&  $pop >= 10000){
        $flags |= 4;
        Hako::Log->logPrize($context->{island_turn}, $id, $name, ${Hako::Config::PRIZE()}[3]);
    }

    # 災難賞
    if ((!($flags & 64)) &&  $damage >= 500){
        $flags |= 64;
        Hako::Log->logPrize($context->{island_turn}, $id, $name, ${Hako::Config::PRIZE()}[7]);
    } elsif ((!($flags & 128)) &&  $damage >= 1000){
        $flags |= 128;
        Hako::Log->logPrize($context->{island_turn}, $id, $name, ${Hako::Config::PRIZE()}[8]);
    } elsif ((!($flags & 256)) &&  $damage >= 2000){
        $flags |= 256;
        Hako::Log->logPrize($context->{island_turn}, $id, $name, ${Hako::Config::PRIZE()}[9]);
    }

    $island->{'prize'} = "$flags,$monsters,$turns";
}

# 人口順にソート
sub islandSort {
    my ($context) = @_;
    my($flag, $i, $tmp);

    my @islands = @{$context->{islands}};
    # 人口が同じときは直前のターンの順番のまま
    my @idx = (0..$#islands);
    @idx = sort { $context->{islands}->[$b]->{'pop'} <=> $context->{islands}->[$a]->{'pop'} || $a <=> $b } @idx;
    my @new_islands = @islands[@idx];
    $context->{islands} = \@new_islands;
}

sub newIslandMain {
    my ($class, $context) = @_;
    # 島がいっぱいでないかチェック
    if ($context->{island_number} >= Hako::Config::MAX_ISLAND) {
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
    if ($context->nameToNumber($context->{current_name}) != -1) {
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
    $context->{current_number} = $context->{island_number};
    $context->{island_number}++;
    $context->{islands}->[$context->{current_number}] = makeNewIsland();
    my $island = $context->{islands}->[$context->{current_number}];

    # 各種の値を設定
    $island->{'name'} = $context->{current_name};
    $island->{'id'} = $context->{island_next_id};
    $context->{island_next_id}++;
    $island->{'absent'} = Hako::Config::GIVEUP_TURN - 3;
    $island->{'comment'} = '(未登録)';
    $island->{'password'} = Hako::Util::encode($context->{input_password});

    # 人口その他算出
    estimate($context, $context->{current_number});

    # データ書き出し
    $context->writeIslandsFile($island->{'id'});
    Hako::Log->logDiscover($context->{island_turn}, $context->{current_name}); # ログ
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
            landValue => $landValue,
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

        my $tmp = countAround(\@land, $x, $y, Hako::Constants::LAND_SEA, 7);
        if (countAround(\@land, $x, $y, Hako::Constants::LAND_SEA, 7) != 7){
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
    # idから島番号を取得
    $context->{current_number} = $context->{id_to_number}->{$context->{current_id}};

    # なぜかその島がない場合
    if ($context->{current_number} eq '') {
        Hako::Exception::SomethingWrong->throw;
    }

    # 名前の取得
    $context->{current_name} = $context->{islands}->[$context->{current_number}]->{'name'};
}

sub ownerMain {
    my ($class, $context) = @_;
    # モードを明示
    $context->{main_mode} = 'owner';

    # idから島を取得
    $context->{current_number} = $context->{id_to_number}->{$context->{current_id}};
    my $island = $context->{islands}->[$context->{current_number}];
    $context->{current_name} = $island->{'name'};

    # パスワード
    if (!Hako::Util::checkPassword($island->{'password'}, $context->{input_password})) {
        Hako::Exception::WrongPassword->throw;
    }
}

sub commandMain {
    my ($class, $context) = @_;
    # idから島を取得
    $context->{current_number} = $context->{id_to_number}->{$context->{current_id}};
    my $island = $context->{islands}->[$context->{current_number}];
    $context->{current_name} = $island->{'name'};

    # パスワード
    if (!Hako::Util::checkPassword($island->{'password'}, $context->{input_password})) {
        Hako::Exception::WrongPassword->throw;
    }

    # モードで分岐
    my $command = $island->{'command'};

    if ($context->{command_mode} eq 'delete') {
        Hako::DB->delete_command($island->{id}, $context->{command_plan_number});
        $context->tempCommandDelete;
    } elsif (($context->{command_kind} == Hako::Constants::COMMAND_AUTO_PREPARE) || ($context->{command_kind} == Hako::Constants::COMMAND_AUTO_PREPARE2)) {
        # フル整地、フル地ならし
        # 座標配列を作る
        my ($Hrpx, $Hrpy) = makeRandomPointArray($context);
        $context->{rpx} = $Hrpx;
        $context->{rpy} = $Hrpy;
        my $land = $island->{'land'};

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
                Hako::DB->insert_command($island->{id}, $context->{command_plan_number}, $cmd);

                $i++;
            }
            $j++;
        }
        $context->tempCommandAdd;
    } elsif ($context->{command_kind} == Hako::Constants::COMMAND_AUTO_DELETE) {
        # 全消し
        Hako::DB->delete_all_command($island->{id});
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
            Hako::DB->insert_command($island->{id}, $context->{command_plan_number}, $cmd);
        } else {
            Hako::DB->insert_command($island->{id}, $context->{command_plan_number}, $cmd, 1);
        }
    }
    $island->{command} = Hako::DB->get_commands($island->{id});

    # データの書き出し
    $context->writeIslandsFile($context->{current_id});

    # owner modeへ
    $class->ownerMain($context);
}

sub commentMain {
    my ($class, $context) = @_;
    # idから島を取得
    $context->{current_number} = $context->{id_to_number}->{$context->{current_id}};
    my $island = $context->{islands}->[$context->{current_number}];
    $context->{current_name} = $island->{'name'};

    # パスワード
    if (!Hako::Util::checkPassword($island->{'password'}, $context->{input_password})) {
        Hako::Exception::WrongPassword->throw;
    }

    # メッセージを更新
    $island->{'comment'} = Hako::Util::htmlEscape($context->{message});

    # データの書き出し
    $context->writeIslandsFile($context->{current_id});

    # コメント更新メッセージ
    $context->tempComment;

    # owner modeへ
    $class->ownerMain($context);
}

sub localBbsMain {
    my ($class, $context) = @_;
    # idから島番号を取得
    $context->{current_number} = $context->{id_to_number}->{$context->{current_id}};
    my $island = $context->{islands}->[$context->{current_number}];

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

    my $lbbs = $island->{'lbbs'};

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
        $context->{local_bbs_name} = $context->{island_turn}."：" . Hako::Util::htmlEscape($context->{local_bbs_name});
        $context->{local_bbs_message} = Hako::Util::htmlEscape($context->{local_bbs_message});
        my $bbs_message = "$message>@{[$context->{local_bbs_name}]}>@{[$context->{local_bbs_message}]}";
        $lbbs->[0] = $bbs_message;
        Hako::DB->insert_bbs($island->{id}, $bbs_message);

        $context->tempLbbsAdd();
    }

    # データ書き出し
    $context->writeIslandsFile($context->{current_id});
}

sub changeMain {
    my ($class, $context) = @_;
    # idから島を取得
    $context->{current_number} = $context->{id_to_number}->{$context->{current_id}};
    my $island = $context->{islands}->[$context->{current_number}];
    my $flag = 0;

    # パスワードチェック
    if ($context->{input_password} eq Hako::Config::SPECIAL_PASSWORD) {
        # 特殊パスワード
        $island->{'money'} = 9999;
        $island->{'food'} = 9999;
    } elsif (!Hako::Util::checkPassword($island->{'password'}, $context->{input_password})) {
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
        if ($context->nameToNumber($context->{current_name}) != -1) {
            Hako::Exception::AlreadyExist->throw;
        }

        if ($island->{'money'} < Hako::Config::CHANGE_NAME_COST) {
            Hako::Exception::NoMoney->throw;
        }

        # 代金
        if ($context->{input_password} ne Hako::Config::SPECIAL_PASSWORD) {
            $island->{'money'} -= Hako::Config::CHANGE_NAME_COST;
        }

        # 名前を変更
        Hako::Log->logChangeName($context->{island_turn}, $island->{'name'}, $context->{current_name});
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
    $context->writeIslandsFile($context->{current_id});

    # 変更成功
    $context->tempChange;
}
1;
