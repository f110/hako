package Hako::Util;
use strict;
use warnings;
use utf8;
use Hako::Config;

# 0から(n - 1)の乱数
sub random {
    return int(rand(1) * $_[0]);
}

# 小さい方を返す
sub min {
    return ($_[0] < $_[1]) ? $_[0] : $_[1];
}

# 1000億単位丸めルーチン
sub aboutMoney {
    my $m = @_;
    if ($m < 500) {
        return "推定500@{[Hako::Config::UNIT_MONEY]}未満";
    } else {
        $m = int(($m + 500) / 1000);
        return "推定${m}000@{[Hako::Config::UNIT_MONEY]}";
    }
}

# パスワードエンコード
sub encode {
    if(Hako::Config::CRYPT == 1) {
        return crypt($_[0], 'h2');
    } else {
        return $_[0];
    }
}

# 経験地からレベルを算出
sub expToLevel {
    my ($kind, $exp) = @_;
    if ($kind == Hako::Constants::LAND_BASE) {
        # ミサイル基地
        for (my $i = Hako::Config::MAX_BASE_LEVEL; $i > 1; $i--) {
            if ($exp >= ${Hako::Config::BASE_LEVEL_UP()}[$i - 2]) {
                return $i;
            }
        }
        return 1;
    } else {
        # 海底基地
        for (my $i = Hako::Config::MAX_SEA_BASE_LEVEL; $i > 1; $i--) {
            if ($exp >= ${Hako::Config::SEA_BASE_LEVEL_UP()}[$i - 2]) {
                return $i;
            }
        }
        return 1;
    }
}

# パスワードチェック
sub checkPassword {
    my ($p1, $p2) = @_;

    # nullチェック
    if ($p2 eq '') {
        return 0;
    }

    # マスターパスワードチェック
    if (Hako::Config::MASTER_PASSWORD eq $p2) {
        return 1;
    }

    # 本来のチェック
    if ($p1 eq encode($p2)) {
        return 1;
    }

    return 0;
}

# 80ケタに切り揃え
sub cutColumn {
    my($s, $c) = @_;

    if (length($s) <= $c) {
        return $s;
    } else {
        # 合計80ケタになるまで切り取り
        my $ss = '';
        my $count = 0;
        while ($count < $c) {
            $s =~ s/(^[\x80-\xFF][\x80-\xFF])|(^[\x00-\x7F])//;
            if($1) {
                $ss .= $1;
                $count ++;
            } else {
                $ss .= $2;
            }
            $count ++;
        }
        return $ss;
    }
}

# エスケープ文字の処理
sub htmlEscape {
    my $s = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/\"/&quot;/g; #"
    return $s;
}

1;
