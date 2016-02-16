package Hako::Log;
use strict;
use warnings;
use Hako::Template::Function;
use Hako::DB;

# 資金繰り
sub logDoNothing {
    my ($class, $turn, $id, $name, $comName) = @_;
#    logOut($turn, "@{[Hako::Template::Function->wrap_name($name."島")]}で@{[Hako::Template::Function->wrap_command_name($comName)]}が行われました。",$id);
}

# 資金足りない
sub logNoMoney {
    my ($class, $turn, $id, $name, $comName) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."で予定されていた".Hako::Template::Function->wrap_command_name($comName)."は、資金不足のため中止されました。", $id);
}

# 食料足りない
sub logNoFood {
    my ($class, $turn, $id, $name, $comName) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."で予定されていた".Hako::Template::Function->wrap_command_name($comName)."は、備蓄食料不足のため中止されました。",$id);
}

# 対象地形の種類による失敗
sub logLandFail {
    my ($class, $turn, $id, $name, $comName, $kind, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."で予定されていた".Hako::Template::Function->wrap_command_name($comName)."は、予定地の".Hako::Template::Function->wrap_name($point)."が<B>$kind</B>だったため中止されました。",$id);
END
}

# 整地系成功
sub logLandSuc {
    my ($class, $turn, $id, $name, $comName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."で".Hako::Template::Function->wrap_command_name($comName)."が行われました。",$id);
END
}

# 埋蔵金
sub logMaizo {
    my ($class, $turn, $id, $name, $comName, $value) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."での@{[Hako::Template::Function->wrap_command_name($comName)]}中に、<B>$value@{[Hako::Config::UNIT_MONEY]}もの埋蔵金</B>が発見されました。",$id);
}

# 周りに陸がなくて埋め立て失敗
sub logNoLandAround {
    my ($class, $turn, $id, $name, $comName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."で予定されていた".Hako::Template::Function->wrap_command_name($comName)."は、予定地の".Hako::Template::Function->wrap_name($point)."の周辺に陸地がなかったため中止されました。",$id);
END
}

# 油田発見
sub logOilFound {
    my ($class, $turn, $id, $name, $point, $comName, $str) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."で<B>$str</B>の予算をつぎ込んだ@{[Hako::Template::Function->wrap_command_name($comName)]}が行われ、<B>油田が掘り当てられました</B>。",$id);
END
}

# 油田発見ならず
sub logOilFail {
    my ($class, $turn, $id, $name, $point, $comName, $str) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."で<B>$str</B>の予算をつぎ込んだ@{[Hako::Template::Function->wrap_command_name($comName)]}が行われましたが、油田は見つかりませんでした。",$id);
END
}

# 油田からの収入
sub logOilMoney {
    my ($class, $turn, $id, $name, $lName, $point, $str) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>から、<B>$str</B>の収益が上がりました。",$id);
END
}

# 油田枯渇
sub logOilEnd {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>は枯渇したようです。",$id);
END
}

# 植林orミサイル基地
sub logPBSuc {
    my ($class, $turn, $id, $name, $comName, $point) = @_;
    logSecret($turn, Hako::Template::Function->wrap_name($name."島".$point)."で".Hako::Template::Function->wrap_command_name($comName)."が行われました。",$id);
    logOut($turn, "こころなしか、".Hako::Template::Function->wrap_name($name."島")."の<B>森</B>が増えたようです。",$id);
END
}

# ハリボテ
sub logHariSuc {
    my ($class, $turn, $id, $name, $comName, $comName2, $point) = @_;
    logSecret($turn, Hako::Template::Function->wrap_name($name."島".$point)."で".Hako::Template::Function->wrap_command_name($comName)."が行われました。",$id);
    $class->logLandSuc($turn, $id, $name, $comName2, $point);
END
}

# 防衛施設、自爆セット
sub logBombSet {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>の<B>自爆装置がセット</B>されました。",$id);
END
}

# 防衛施設、自爆作動
sub logBombFire {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>、".Hako::Template::Function->wrap_disaster("自爆装置作動！！"),$id);
END
}

# 記念碑、発射
sub logMonFly {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>が<B>轟音とともに飛び立ちました</B>。",$id);
END
}

# ミサイル撃とうとした(or 怪獣派遣しようとした)がターゲットがいない
sub logMsNoTarget {
    my ($class, $turn, $id, $name, $comName) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."で予定されていた".Hako::Template::Function->wrap_command_name($comName)."は、目標の島に人が見当たらないため中止されました。",$id);
END
}

# ミサイル撃とうとしたが基地がない
sub logMsNoBase {
    my ($class, $turn, $id, $name, $comName) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."で予定されていた@{[Hako::Template::Function->wrap_command_name($comName)]}は、<B>ミサイル設備を保有していない</B>ために実行できませんでした。",$id);
END
}

# ミサイル撃ったが範囲外
sub logMsOut {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行いましたが、<B>領域外の海</B>に落ちた模様です。",$id, $tId);
}

# ステルスミサイル撃ったが範囲外
sub logMsOutS {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $point) = @_;
    logSecret($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行いましたが、<B>領域外の海</B>に落ちた模様です。",$id, $tId);
    logLate($turn, "<B>何者か</B>が".Hako::Template::Function->wrap_name($tName."島".$point)."へ向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行いましたが、<B>領域外の海</B>に落ちた模様です。",$tId);
}

# ミサイル撃ったが防衛施設でキャッチ
sub logMsCaught {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $point, $tPoint) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行いましたが、@{[Hako::Template::Function->wrap_name($tPoint)]}地点上空にて力場に捉えられ、<B>空中爆発</B>しました。",$id, $tId);
}

# ステルスミサイル撃ったが防衛施設でキャッチ
sub logMsCaughtS {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $point, $tPoint) = @_;
    logSecret($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行いましたが、@{[Hako::Template::Function->wrap_name($tPoint)]}地点上空にて力場に捉えられ、<B>空中爆発</B>しました。",$id, $tId);
    logLate($turn, "<B>何者か</B>が".Hako::Template::Function->wrap_name($tName."島".$point)."へ向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行いましたが、@{[Hako::Template::Function->wrap_name($tPoint)]}地点上空にて力場に捉えられ、<B>空中爆発</B>しました。",$tId);
}

# ミサイル撃ったが効果なし
sub logMsNoDamage {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行いましたが、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>$tLname</B>に落ちたので被害がありませんでした。",$id, $tId);
}

# ステルスミサイル撃ったが効果なし
sub logMsNoDamageS {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logSecret($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行いましたが、@{[Hako::Template::Function->wrap_name($point)]}の<B>$tLname</B>に落ちたので被害がありませんでした。",$id, $tId);

    logLate($turn, "<B>何者か</B>が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行いましたが、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>$tLname</B>に落ちたので被害がありませんでした。",$tId);
}

# 陸地破壊弾、山に命中
sub logMsLDMountain {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>$tLname</B>に命中。<B>$tLname</B>は消し飛び、荒地と化しました。",$id, $tId);
}

# 陸地破壊弾、海底基地に命中
sub logMsLDSbase {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}に着水後爆発、同地点にあった<B>$tLname</B>は跡形もなく吹き飛びました。",$id, $tId);
}

# 陸地破壊弾、怪獣に命中
sub logMsLDMonster {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、".Hako::Template::Function->wrap_name($name."島")."に着弾し爆発。陸地は<B>怪獣$tLname</B>もろとも水没しました。",$id, $tId);
}

# 陸地破壊弾、浅瀬に命中
sub logMsLDSea1 {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>$tLname</B>に着弾。海底がえぐられました。",$id, $tId);
}

# 陸地破壊弾、その他の地形に命中
sub logMsLDLand {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>$tLname</B>に着弾。陸地は水没しました。",$id, $tId);
}

# 通常ミサイル、荒地に着弾
sub logMsWaste {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行いましたが、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>$tLname</B>に落ちました。",$id, $tId);
}

# ステルスミサイル、荒地に着弾
sub logMsWasteS {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logSecret($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行いましたが、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>$tLname</B>に落ちました。",$id, $tId);
    logLate($turn, "<B>何者か</B>が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行いましたが、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>$tLname</B>に落ちました。",$tId);
}

# 通常ミサイル、怪獣に命中、硬化中にて無傷
sub logMsMonNoDamage {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>怪獣$tLname</B>に命中、しかし硬化状態だったため効果がありませんでした。",$id, $tId);
}

# ステルスミサイル、怪獣に命中、硬化中にて無傷
sub logMsMonNoDamageS {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logSecret($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>怪獣$tLname</B>に命中、しかし硬化状態だったため効果がありませんでした。",$id, $tId);
    logOut($turn, "<B>何者か</B>が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>怪獣$tLname</B>に命中、しかし硬化状態だったため効果がありませんでした。",$tId);
}

# 通常ミサイル、怪獣に命中、殺傷
sub logMsMonKill {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>怪獣$tLname</B>に命中。<B>怪獣$tLname</B>は力尽き、倒れました。",$id, $tId);
}

# ステルスミサイル、怪獣に命中、殺傷
sub logMsMonKillS {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logSecret($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>怪獣$tLname</B>に命中。<B>怪獣$tLname</B>は力尽き、倒れました。",$id, $tId);
    logLate($turn, "<B>何者か</B>が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>怪獣$tLname</B>に命中。<B>怪獣$tLname</B>は力尽き、倒れました。", $tId);
}

# 怪獣の死体
sub logMsMonMoney {
    my ($class, $turn, $tId, $mName, $value) = @_;
    logOut($turn, "<B>怪獣$mName</B>の残骸には、<B>$value@{[Hako::Config::UNIT_MONEY]}</B>の値が付きました。",$tId);
}

# ステルスミサイル、怪獣に命中、ダメージ
sub logMsMonsterS {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logSecret($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>怪獣$tLname</B>に命中。<B>怪獣$tLname</B>は苦しそうに咆哮しました。",$id, $tId);
    logLate($turn, "<B>何者か</B>が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>怪獣$tLname</B>に命中。<B>怪獣$tLname</B>は苦しそうに咆哮しました。",$tId);
}

# 通常ミサイル、怪獣に命中、ダメージ
sub logMsMonster {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>怪獣$tLname</B>に命中。<B>怪獣$tLname</B>は苦しそうに咆哮しました。",$id, $tId);
}

# ステルスミサイル通常地形に命中
sub logMsNormalS {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logSecret($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>$tLname</B>に命中、一帯が壊滅しました。",$id, $tId);
    logLate($turn, "<B>何者か</B>が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>$tLname</B>に命中、一帯が壊滅しました。",$tId);
}

# 通常ミサイル通常地形に命中
sub logMsNormal {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $tLname, $point, $tPoint) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島".$point)."地点に向けて@{[Hako::Template::Function->wrap_command_name($comName)]}を行い、@{[Hako::Template::Function->wrap_name($tPoint)]}の<B>$tLname</B>に命中、一帯が壊滅しました。",$id, $tId);
}

# ミサイル難民到着
sub logMsBoatPeople {
    my ($class, $turn, $id, $name, $achive) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."にどこからともなく<B>$achive@{[Hako::Config::UNIT_POPULATION]}もの難民</B>が漂着しました。".Hako::Template::Function->wrap_name($name."島")."は快く受け入れたようです。",$id);
}

# 受賞
sub logPrize {
    my ($class, $turn, $id, $name, $pName) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が<B>$pName</B>を受賞しました。",$id);
    logHistory($turn, Hako::Template::Function->wrap_name($name."島")."、<B>$pName</B>を受賞");
}

# 怪獣派遣
sub logMonsSend {
    my ($class, $turn, $id, $tId, $name, $tName) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が<B>人造怪獣</B>を建造。".Hako::Template::Function->wrap_name($tName."島")."へ送りこみました。",$id, $tId);
}

# 輸出
sub logSell {
    my ($class, $turn, $id, $name, $comName, $value) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が<B>$value@{[Hako::Config::UNIT_FOOD]}</B>の@{[Hako::Template::Function->wrap_command_name($comName)]}を行いました。",$id);
}

# 援助
sub logAid {
    my ($class, $turn, $id, $tId, $name, $tName, $comName, $str) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."が".Hako::Template::Function->wrap_name($tName."島")."へ<B>$str</B>の@{[Hako::Template::Function->wrap_command_name($comName)]}を行いました。",$id, $tId);
}

# 誘致活動
sub logPropaganda {
    my ($class, $turn, $id, $name, $comName) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."で@{[Hako::Template::Function->wrap_command_name($comName)]}が行われました。",$id);
}

# 放棄
sub logGiveup {
    my ($class, $turn, $id, $name) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."は放棄され、<B>無人島</B>になりました。",$id);
    logHistory($turn, Hako::Template::Function->wrap_name($name."島")."、放棄され<B>無人島</B>となる。");
}

# 広域被害、海の建設
sub logWideDamageSea2 {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>は跡形もなくなりました。",$id);
}

# 広域被害、怪獣水没
sub logWideDamageMonsterSea {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の陸地は<B>怪獣$lName</B>もろとも水没しました。",$id);
}

# 広域被害、水没
sub logWideDamageSea {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>は<B>水没</B>しました。",$id);
}

# 広域被害、怪獣
sub logWideDamageMonster {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>怪獣$lName</B>は消し飛びました。",$id);
}

# 広域被害、荒地
sub logWideDamageWaste {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>は一瞬にして<B>荒地</B>と化しました。",$id);
}

# 怪獣、防衛施設を踏む
sub logMonsMoveDefence {
    my ($class, $turn, $id, $name, $lName, $point, $mName) = @_;
    logOut($turn, "<B>怪獣$mName</B>が".Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>へ到達、<B>${lName}の自爆装置が作動！！</B>",$id);
}

# 怪獣動く
sub logMonsMove {
    my ($class, $turn, $id, $name, $lName, $point, $mName) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>が<B>怪獣$mName</B>に踏み荒らされました。",$id);
}

# 火災
sub logFire {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>が".Hako::Template::Function->wrap_disaster("火災")."により壊滅しました。",$id);
}

# 地震発生
sub logEarthquake {
    my ($class, $turn, $id, $name) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."で大規模な".Hako::Template::Function->wrap_disaster("地震")."が発生！！",$id);
}

# 地震被害
sub logEQDamage {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>は".Hako::Template::Function->wrap_disaster("地震")."により壊滅しました。",$id);
}

# 飢餓
sub logStarve {
    my ($class, $turn, $id, $name) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."の".Hako::Template::Function->wrap_disaster("食料が不足")."しています！！", $id);
}

# 食料不足被害
sub logSvDamage {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>に<B>食料を求めて住民が殺到</B>。<B>$lName</B>は壊滅しました。",$id);
}

# 津波発生
sub logTsunami {
    my ($class, $turn, $id, $name) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."付近で".Hako::Template::Function->wrap_disaster("津波")."発生！！",$id);
}

# 津波被害
sub logTsunamiDamage {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>は".Hako::Template::Function->wrap_disaster("津波")."により崩壊しました。",$id);
}

# 怪獣現る
sub logMonsCome {
    my ($class, $turn, $id, $name, $mName, $point, $lName) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."に<B>怪獣$mName</B>出現！！@{[Hako::Template::Function->wrap_name($point)]}の<B>$lName</B>が踏み荒らされました。",$id);
}

# 地盤沈下発生
sub logFalldown {
    my ($class, $turn, $id, $name) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."で".Hako::Template::Function->wrap_disaster("地盤沈下")."が発生しました！！",$id);
}

# 地盤沈下被害
sub logFalldownLand {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>は海の中へ沈みました。",$id);
}

# 台風発生
sub logTyphoon {
    my ($class, $turn, $id, $name) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."に".Hako::Template::Function->wrap_disaster("台風")."上陸！！",$id);
}

# 台風被害
sub logTyphoonDamage {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>は".Hako::Template::Function->wrap_disaster("台風")."で飛ばされました。",$id);
}

# 隕石、その他
sub logHugeMeteo {
    my ($class, $turn, $id, $name, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."地点に".Hako::Template::Function->wrap_disaster("巨大隕石")."が落下！！",$id);
}

# 記念碑、落下
sub logMonDamage {
    my ($class, $turn, $id, $name, $point) = @_;
    logOut($turn, "<B>何かとてつもないもの</B>が".Hako::Template::Function->wrap_name($name."島".$point)."地点に落下しました！！",$id);
}

# 隕石、海
sub logMeteoSea {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>に".Hako::Template::Function->wrap_disaster("隕石")."が落下しました。",$id);
}

# 隕石、山
sub logMeteoMountain {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>に".Hako::Template::Function->wrap_disaster("隕石")."が落下、<B>$lName</B>は消し飛びました。",$id);
}

# 隕石、海底基地
sub logMeteoSbase {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."の<B>$lName</B>に".Hako::Template::Function->wrap_disaster("隕石")."が落下、<B>$lName</B>は崩壊しました。",$id);
}

# 隕石、怪獣
sub logMeteoMonster {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, "<B>怪獣$lName</B>がいた".Hako::Template::Function->wrap_name($name."島".$point)."地点に".Hako::Template::Function->wrap_disaster("隕石")."が落下、陸地は<B>怪獣$lName</B>もろとも水没しました。",$id);
}

# 隕石、浅瀬
sub logMeteoSea1 {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."地点に".Hako::Template::Function->wrap_disaster("隕石")."が落下、海底がえぐられました。",$id);
}

# 隕石、その他
sub logMeteoNormal {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."地点の<B>$lName</B>に".Hako::Template::Function->wrap_disaster("隕石")."が落下、一帯が水没しました。",$id);
}

# 噴火
sub logEruption {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."地点で".Hako::Template::Function->wrap_disaster("火山が噴火")."、<B>山</B>が出来ました。",$id);
}

# 噴火、浅瀬
sub logEruptionSea1 {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."地点の<B>$lName</B>は、".Hako::Template::Function->wrap_disaster("噴火")."の影響で陸地になりました。",$id);
}

# 噴火、海or海基
sub logEruptionSea {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."地点の<B>$lName</B>は、".Hako::Template::Function->wrap_disaster("噴火")."の影響で海底が隆起、浅瀬になりました。",$id);
}

# 噴火、その他
sub logEruptionNormal {
    my ($class, $turn, $id, $name, $lName, $point) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島".$point)."地点の<B>$lName</B>は、".Hako::Template::Function->wrap_disaster("噴火")."の影響で壊滅しました。",$id);
}

# 死滅
sub logDead {
    my ($class, $turn, $id, $name) = @_;
    logOut($turn, Hako::Template::Function->wrap_name($name."島")."から人がいなくなり、<B>無人島</B>になりました。",$id);
    logHistory($turn, Hako::Template::Function->wrap_name($name."島")."、人がいなくなり<B>無人島</B>となる。");
}

# 発見
sub logDiscover {
    my ($class, $turn, $name) = @_;
    logHistory($turn, Hako::Template::Function->wrap_name($name."島")."が発見される。");
}

sub logChangeName {
    my ($class, $turn, $name1, $name2) = @_;
    logHistory($turn, Hako::Template::Function->wrap_name($name1."島")."、名称を".Hako::Template::Function->wrap_name($name2."島")."に変更する。");
}

sub logOut {
    my ($turn, $message, $island_id, $target_id) = @_;

    Hako::DB->insert_log($turn, $island_id, $target_id, $message);
}

# 機密ログ
sub logSecret {
    my ($turn, $message, $island_id, $target_id) = @_;

    Hako::DB->insert_secret_log($turn, $island_id, $target_id, $message);
}

# 記録ログ
sub logHistory {
    my ($turn, $message);
    Hako::DB->insert_history($turn, $message);
}

# 遅延ログ
sub logLate {
    my ($turn, $message, $island_id, $target_id) = @_;

    Hako::DB->insert_late_log($turn, $island_id, $target_id, $message);
}


1;
