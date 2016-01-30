# vim: set ft=perl:
package MainApp;
use Encode qw();
use YAML ();
use File::Spec;
use File::Basename;
use Plack::Response;
use Plack::Request;
use List::MoreUtils qw();
use Text::Xslate qw(mark_raw);
use Hako::Config;
use Hako::DB;
use Hako::Model::Island;

#----------------------------------------------------------------------
# 箱庭諸島 ver2.30
# メインスクリプト(ver1.02)
# 使用条件、使用方法等は、hako-readme.txtファイルを参照
#
# 箱庭諸島のページ: http://www.bekkoame.ne.jp/~tokuoka/hakoniwa.html
#----------------------------------------------------------------------


#----------------------------------------------------------------------
# 各種設定値
# (これ以降の部分の各設定値を、適切な値に変更してください)
#----------------------------------------------------------------------

# このファイルを置くディレクトリ
# my($baseDir) = 'http://サーバー/ディレクトリ';
#
# 例)
# http://cgi2.bekkoame.ne.jp/cgi-bin/user/u5534/hakoniwa/hako-main.cgi
# として置く場合、
# my($baseDir) = 'http://cgi2.bekkoame.ne.jp/cgi-bin/user/u5534/hakoniwa';
# とする。最後にスラッシュ(/)は付けない。

my($baseDir) = Hako::Config::BASE_DIR;

# 画像ファイルを置くディレクトリ
# my($imageDir) = 'http://サーバー/ディレクトリ';
my($imageDir) = Hako::Config::IMAGE_DIR;

# マスターパスワード
# このパスワードは、すべての島のパスワードを代用できます。
# 例えば、「他の島のパスワード変更」等もできます。
my($masterPassword) = Hako::Config::MASTER_PASSWORD;

# 特殊パスワード
# このパスワードで「名前変更」を行うと、その島の資金、食料が最大値になります。
# (実際に名前を変える必要はありません。)
$HspecialPassword = Hako::Config::SPECIAL_PASSWORD;

# 管理者名
my($adminName) = Encode::encode("EUC-JP", Hako::Config::ADMIN_NAME);

# 管理者のメールアドレス
my($email) = Hako::Config::ADMIN_EMAIL;

# 掲示板アドレス
my($bbs) = Hako::Config::BBS_URL();

# ホームページのアドレス
my($toppage) = Hako::Config::TOPPAGE_URL;

# ディレクトリのパーミッション
# 通常は0755でよいが、0777、0705、0704等でないとできないサーバーもあるらしい
$HdirMode = 0755;

# データディレクトリの名前
# ここで設定した名前のディレクトリ以下にデータが格納されます。
# デフォルトでは'data'となっていますが、セキュリティのため
# なるべく違う名前に変更してください。
$HdirName = Hako::Config::DATA_DIR;

# データの書き込み方

# ロックの方式
# 1 ディレクトリ
# 2 システムコール(可能ならば最も望ましい)
# 3 シンボリックリンク
# 4 通常ファイル(あまりお勧めでない)
my($lockMode) = Hako::Config::LOCK_MODE;

# (注)
# 4を選択する場合には、'key-free'という、パーミション666の空のファイルを、
# このファイルと同位置に置いて下さい。

#----------------------------------------------------------------------
# 必ず設定する部分は以上
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# 以下、好みによって設定する部分
#----------------------------------------------------------------------
#----------------------------------------
# ゲームの進行やファイルなど
#----------------------------------------
# 1ターンが何秒か
$HunitTime = Hako::Config::UNIT_TIME; # 6時間

# 異常終了基準時間
# (ロック後何秒で、強制解除するか)
my($unlockTime) = Hako::Config::UNLOCK_TIME;

# 島の最大数
$HmaxIsland = Hako::Config::MAX_ISLAND;

# トップページに表示するログのターン数
$HtopLogTurn = Hako::Config::TOP_LOG_TURN;

# ログファイル保持ターン数
$HlogMax = Hako::Config::LOG_MAX;

# バックアップを何ターンおきに取るか
$HbackupTurn = Hako::Config::BACKUP_TURN;

# バックアップを何回分残すか
$HbackupTimes = Hako::Config::BACKUP_TIMES;

# 発見ログ保持行数
$HhistoryMax = Hako::Config::HISTORY_MAX;

# 放棄コマンド自動入力ターン数
$HgiveupTurn = Hako::Config::GIVEUP_TURN;

# コマンド入力限界数
# (ゲームが始まってから変更すると、データファイルの互換性が無くなります。)
$HcommandMax = Hako::Config::COMMAND_MAX;

# ローカル掲示板行数を使用するかどうか(0:使用しない、1:使用する)
$HuseLbbs = Hako::Config::USE_LOCAL_BBS;

# ローカル掲示板行数
$HlbbsMax = Hako::Config::LOCAL_BBS_MAX;

# 島の大きさ
# (変更できないかも)
$HislandSize = Hako::Config::ISLAND_SIZE;

# 他人から資金を見えなくするか
# 0 見えない
# 1 見える
# 2 100の位で四捨五入
$HhideMoneyMode = Hako::Config::HIDE_MONEY_MODE;

# パスワードの暗号化(0だと暗号化しない、1だと暗号化する)
my($cryptOn) = Hako::Config::CRYPT;

# デバッグモード(1だと、「ターンを進める」ボタンが使用できる)
$Hdebug = Hako::Config::DEBUG;

#----------------------------------------
# 資金、食料などの設定値と単位
#----------------------------------------
# 初期資金
$HinitialMoney = Hako::Config::INITIAL_MONEY;

# 初期食料
$HinitialFood = Hako::Config::INITIAL_FOOD;

# お金の単位
$HunitMoney = Encode::encode("EUC-JP", Hako::Config::UNIT_MONEY);

# 食料の単位
$HunitFood = Encode::encode("EUC-JP", Hako::Config::UNIT_FOOD);

# 人口の単位
$HunitPop = Encode::encode("EUC-JP", Hako::Config::UNIT_POPULATION);

# 広さの単位
$HunitArea = Encode::encode("EUC-JP", Hako::Config::UNIT_AREA);

# 木の数の単位
$HunitTree = Encode::encode("EUC-JP", Hako::Config::UNIT_TREE);

# 木の単位当たりの売値
$HtreeValue = Hako::Config::TREE_VALUE;

# 名前変更のコスト
$HcostChangeName = Hako::Config::CHANGE_NAME_COST;

# 人口1単位あたりの食料消費料
$HeatenFood = Hako::Config::EATEN_FOOD;

#----------------------------------------
# 基地の経験値
#----------------------------------------
# 経験値の最大値
$HmaxExpPoint = Hako::Config::MAX_EXP_POINT; # ただし、最大でも255まで

# レベルの最大値
my($maxBaseLevel) = Hako::Config::MAX_BASE_LEVEL;  # ミサイル基地
my($maxSBaseLevel) = Hako::Config::MAX_SEA_BASE_LEVEL; # 海底基地

# 経験値がいくつでレベルアップか
my(@baseLevelUp, @sBaseLevelUp);
@baseLevelUp = @{Hako::Config::BASE_LEVEL_UP()}; # ミサイル基地
@sBaseLevelUp = @{Hako::Config::SEA_BASE_LEVEL_UP()};         # 海底基地

#----------------------------------------
# 防衛施設の自爆
#----------------------------------------
# 怪獣に踏まれた時自爆するなら1、しないなら0
$HdBaseAuto = Hako::Config::DEFENCE_BASE_AUTO;

#----------------------------------------
# 災害
#----------------------------------------
# 通常災害発生率(確率は0.1%単位)
$HdisEarthquake = Hako::Config::DISASTER_EARTHQUAKE;  # 地震
$HdisTsunami    = Hako::Config::DISASTER_TSUNAMI; # 津波
$HdisTyphoon    = Hako::Config::DISASTER_TYPHOON; # 台風
$HdisMeteo      = Hako::Config::DISASTER_METEO; # 隕石
$HdisHugeMeteo  = Hako::Config::DISASTER_HUGE_METEO;  # 巨大隕石
$HdisEruption   = Hako::Config::DISASTER_ERUPTION; # 噴火
$HdisFire       = Hako::Config::DISASTER_FIRE; # 火災
$HdisMaizo      = Hako::Config::DISASTER_MAIZO; # 埋蔵金

# 地盤沈下
$HdisFallBorder = Hako::Config::DISASTER_FALL_BORDER; # 安全限界の広さ(Hex数)
$HdisFalldown   = Hako::Config::DISASTER_FALL_DOWN; # その広さを超えた場合の確率

# 怪獣
$HdisMonsBorder1 = Hako::Config::DISASTER_MONSTER_BORDER1; # 人口基準1(怪獣レベル1)
$HdisMonsBorder2 = Hako::Config::DISASTER_MONSTER_BORDER2; # 人口基準2(怪獣レベル2)
$HdisMonsBorder3 = Hako::Config::DISASTER_MONSTER_BORDER3; # 人口基準3(怪獣レベル3)
$HdisMonster     = Hako::Config::DISASTER_MONSTER;    # 単位面積あたりの出現率(0.01%単位)

# 種類
$HmonsterNumber  = Hako::Config::MONSTER_NUMBER;

# 各基準において出てくる怪獣の番号の最大値
$HmonsterLevel1  = Hako::Config::MONSTER_LEVEL1; # サンジラまで
$HmonsterLevel2  = Hako::Config::MONSTER_LEVEL2; # いのらゴーストまで
$HmonsterLevel3  = Hako::Config::MONSTER_LEVEL3; # キングいのらまで(全部)

# 名前
@HmonsterName = map { Encode::encode("EUC-JP", $_) } @{Hako::Config::MONSTER_NAME()};

# 最低体力、体力の幅、特殊能力、経験値、死体の値段
@HmonsterBHP     = @{Hako::Config::MONSTER_BOTTOM_HP};
@HmonsterDHP     = @{Hako::Config::MONSTER_DHP};
@HmonsterSpecial = @{Hako::Config::MONSTER_SPECIAL};
@HmonsterExp     = @{Hako::Config::MONSTER_EXP};
@HmonsterValue   = @{Hako::Config::MONSTER_VALUE};

# 特殊能力の内容は、
# 0 特になし
# 1 足が速い(最大2歩あるく)
# 2 足がとても速い(最大何歩あるくか不明)
# 3 奇数ターンは硬化
# 4 偶数ターンは硬化

# 画像ファイル
@HmonsterImage = @{Hako::Config::MONSTER_IMAGE};

# 画像ファイルその2(硬化中)
@HmonsterImage2 = @{Hako::Config::MONSTER_IMAGE2};


#----------------------------------------
# 油田
#----------------------------------------
# 油田の収入
$HoilMoney = Hako::Config::OIL_MONEY;

# 油田の枯渇確率
$HoilRatio = Hako::Config::OIL_RAITO;

#----------------------------------------
# 記念碑
#----------------------------------------
# 何種類あるか
$HmonumentNumber = Hako::Config::MONUMENT_NUMBER;

# 名前
@HmonumentName = map { Encode::encode("EUC-JP", $_) } @{Hako::Config::MONUMEBT_NAME};

# 画像ファイル
@HmonumentImage = @{Hako::Config::MONUMENT_IMAGE};

#----------------------------------------
# 賞関係
#----------------------------------------
# ターン杯を何ターン毎に出すか
$HturnPrizeUnit = Hako::Config::TURN_PRIZE_UNIT;

# 賞の名前
@Hprize = map { Encode::encode("EUC-JP", $_ ) } @{Hako::Config::PRIZE};

#----------------------------------------
# 外見関係
#----------------------------------------
# <BODY>タグのオプション
my($htmlBody) = Hako::Config::HTML_BODY;

# ゲームのタイトル文字
$Htitle = Encode::encode("EUC-JP", Hako::Config::TITLE);

# タグ
# タイトル文字
$HtagTitle_ = Hako::Config::TAG_TITLE_;
$H_tagTitle = Hako::Config::_TAG_TITLE;

# H1タグ用
$HtagHeader_ = Hako::Config::TAG_HEADER_;
$H_tagHeader = Hako::Config::_TAG_HEADER;

# 大きい文字
$HtagBig_ = Hako::Config::TAG_BIG_;
$H_tagBig = Hako::Config::_TAG_BIG;

# 島の名前など
$HtagName_ = Hako::Config::TAG_NAME_;
$H_tagName = Hako::Config::_TAG_NAME;

# 薄くなった島の名前
$HtagName2_ = Hako::Config::TAG_NAME2_;
$H_tagName2 = Hako::Config::_TAG_NAME2;

# 順位の番号など
$HtagNumber_ = Hako::Config::TAG_NUMBER_;
$H_tagNumber = Hako::Config::_TAG_NUMBER;

# 順位表における見だし
$HtagTH_ = Hako::Config::TAG_TH_;
$H_tagTH = Hako::Config::_TAG_TH;

# 開発計画の名前
$HtagComName_ = Hako::Config::TAG_COM_NAME_;
$H_tagComName = Hako::Config::_TAG_COM_NAME;

# 災害
$HtagDisaster_ = Hako::Config::TAG_DISASTER_;
$H_tagDisaster = Hako::Config::_TAG_DISASTER;

# ローカル掲示板、観光者の書いた文字
$HtagLbbsSS_ = Hako::Config::TAG_LOCAL_BBS_SS_;
$H_tagLbbsSS = Hako::Config::_TAG_LOCAL_BBS_SS;

# ローカル掲示板、島主の書いた文字
$HtagLbbsOW_ = Hako::Config::TAG_LOCAL_BBS_OW_;
$H_tagLbbsOW = Hako::Config::_TAG_LOCAL_BBS_OW;

# 通常の文字色(これだけでなく、BODYタグのオプションもちゃんと変更すべし
$HnormalColor = Hako::Config::NORMAL_COLOR;

# 順位表、セルの属性
$HbgTitleCell   = Hako::Config::BG_TITLE_CELL; # 順位表見出し
$HbgNumberCell  = Hako::Config::BG_NUMBER_CELL; # 順位表順位
$HbgNameCell    = Hako::Config::BG_NAME_CELL; # 順位表島の名前
$HbgInfoCell    = Hako::Config::BG_INFO_CELL; # 順位表島の情報
$HbgCommentCell = Hako::Config::BG_COMMENT_CELL; # 順位表コメント欄
$HbgInputCell   = Hako::Config::BG_INPUT_CELL; # 開発計画フォーム
$HbgMapCell     = Hako::Config::BG_MAP_CELL; # 開発計画地図
$HbgCommandCell = Hako::Config::BG_COMMAND_CELL; # 開発計画入力済み計画

#----------------------------------------------------------------------
# 好みによって設定する部分は以上
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# これ以降のスクリプトは、変更されることを想定していませんが、
# いじってもかまいません。
# コマンドの名前、値段などは解りやすいと思います。
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# 各種定数
#----------------------------------------------------------------------
# このファイル
$HthisFile = "$baseDir/hako-main.cgi";

# 地形番号
$HlandSea      = 0;  # 海
$HlandWaste    = 1;  # 荒地
$HlandPlains   = 2;  # 平地
$HlandTown     = 3;  # 町系
$HlandForest   = 4;  # 森
$HlandFarm     = 5;  # 農場
$HlandFactory  = 6;  # 工場
$HlandBase     = 7;  # ミサイル基地
$HlandDefence  = 8;  # 防衛施設
$HlandMountain = 9;  # 山
$HlandMonster  = 10; # 怪獣
$HlandSbase    = 11; # 海底基地
$HlandOil      = 12; # 海底油田
$HlandMonument = 13; # 記念碑
$HlandHaribote = 14; # ハリボテ

# コマンド
$HcommandTotal = 28; # コマンドの種類

# 計画番号の設定
# 整地系
$HcomPrepare  = 01; # 整地
$HcomPrepare2 = 02; # 地ならし
$HcomReclaim  = 03; # 埋め立て
$HcomDestroy  = 04; # 掘削
$HcomSellTree = 05; # 伐採

# 作る系
$HcomPlant    = 11; # 植林
$HcomFarm     = 12; # 農場整備
$HcomFactory  = 13; # 工場建設
$HcomMountain = 14; # 採掘場整備
$HcomBase     = 15; # ミサイル基地建設
$HcomDbase    = 16; # 防衛施設建設
$HcomSbase    = 17; # 海底基地建設
$HcomMonument = 18; # 記念碑建造
$HcomHaribote = 19; # ハリボテ設置

# 発射系
$HcomMissileNM   = 31; # ミサイル発射
$HcomMissilePP   = 32; # PPミサイル発射
$HcomMissileST   = 33; # STミサイル発射
$HcomMissileLD   = 34; # 陸地破壊弾発射
$HcomSendMonster = 35; # 怪獣派遣

# 運営系
$HcomDoNothing  = 41; # 資金繰り
$HcomSell       = 42; # 食料輸出
$HcomMoney      = 43; # 資金援助
$HcomFood       = 44; # 食料援助
$HcomPropaganda = 45; # 誘致活動
$HcomGiveup     = 46; # 島の放棄

# 自動入力系
$HcomAutoPrepare  = 61; # フル整地
$HcomAutoPrepare2 = 62; # フル地ならし
$HcomAutoDelete   = 63; # 全コマンド消去

# 順番
@HcomList =
    ($HcomPrepare, $HcomSell, $HcomPrepare2, $HcomReclaim, $HcomDestroy,
     $HcomSellTree, $HcomPlant, $HcomFarm, $HcomFactory, $HcomMountain,
     $HcomBase, $HcomDbase, $HcomSbase, $HcomMonument, $HcomHaribote,
     $HcomMissileNM, $HcomMissilePP,
     $HcomMissileST, $HcomMissileLD, $HcomSendMonster, $HcomDoNothing,
     $HcomMoney, $HcomFood, $HcomPropaganda, $HcomGiveup,
     $HcomAutoPrepare, $HcomAutoPrepare2, $HcomAutoDelete);

# 計画の名前と値段
$HcomName[$HcomPrepare]      = '整地';
$HcomCost[$HcomPrepare]      = 5;
$HcomName[$HcomPrepare2]     = '地ならし';
$HcomCost[$HcomPrepare2]     = 100;
$HcomName[$HcomReclaim]      = '埋め立て';
$HcomCost[$HcomReclaim]      = 150;
$HcomName[$HcomDestroy]      = '掘削';
$HcomCost[$HcomDestroy]      = 200;
$HcomName[$HcomSellTree]     = '伐採';
$HcomCost[$HcomSellTree]     = 0;
$HcomName[$HcomPlant]        = '植林';
$HcomCost[$HcomPlant]        = 50;
$HcomName[$HcomFarm]         = '農場整備';
$HcomCost[$HcomFarm]         = 20;
$HcomName[$HcomFactory]      = '工場建設';
$HcomCost[$HcomFactory]      = 100;
$HcomName[$HcomMountain]     = '採掘場整備';
$HcomCost[$HcomMountain]     = 300;
$HcomName[$HcomBase]         = 'ミサイル基地建設';
$HcomCost[$HcomBase]         = 300;
$HcomName[$HcomDbase]        = '防衛施設建設';
$HcomCost[$HcomDbase]        = 800;
$HcomName[$HcomSbase]        = '海底基地建設';
$HcomCost[$HcomSbase]        = 8000;
$HcomName[$HcomMonument]     = '記念碑建造';
$HcomCost[$HcomMonument]     = 9999;
$HcomName[$HcomHaribote]     = 'ハリボテ設置';
$HcomCost[$HcomHaribote]     = 1;
$HcomName[$HcomMissileNM]    = 'ミサイル発射';
$HcomCost[$HcomMissileNM]    = 20;
$HcomName[$HcomMissilePP]    = 'PPミサイル発射';
$HcomCost[$HcomMissilePP]    = 50;
$HcomName[$HcomMissileST]    = 'STミサイル発射';
$HcomCost[$HcomMissileST]    = 50;
$HcomName[$HcomMissileLD]    = '陸地破壊弾発射';
$HcomCost[$HcomMissileLD]    = 100;
$HcomName[$HcomSendMonster]  = '怪獣派遣';
$HcomCost[$HcomSendMonster]  = 3000;
$HcomName[$HcomDoNothing]    = '資金繰り';
$HcomCost[$HcomDoNothing]    = 0;
$HcomName[$HcomSell]         = '食料輸出';
$HcomCost[$HcomSell]         = -100;
$HcomName[$HcomMoney]        = '資金援助';
$HcomCost[$HcomMoney]        = 100;
$HcomName[$HcomFood]         = '食料援助';
$HcomCost[$HcomFood]         = -100;
$HcomName[$HcomPropaganda]   = '誘致活動';
$HcomCost[$HcomPropaganda]   = 1000;
$HcomName[$HcomGiveup]       = '島の放棄';
$HcomCost[$HcomGiveup]       = 0;
$HcomName[$HcomAutoPrepare]  = '整地自動入力';
$HcomCost[$HcomAutoPrepare]  = 0;
$HcomName[$HcomAutoPrepare2] = '地ならし自動入力';
$HcomCost[$HcomAutoPrepare2] = 0;
$HcomName[$HcomAutoDelete]   = '全計画を白紙撤回';
$HcomCost[$HcomAutoDelete]   = 0;

#----------------------------------------------------------------------
# 変数
#----------------------------------------------------------------------

# COOKIE
my($defaultID);       # 島の名前
my($defaultTarget);   # ターゲットの名前


# 島の座標数
$HpointNumber = $HislandSize * $HislandSize;

#----------------------------------------------------------------------
# メイン
#----------------------------------------------------------------------

# 「戻る」リンク
$HtempBack = "<A HREF=\"$HthisFile\">${HtagBig_}トップへ戻る${H_tagBig}</A>";

sub to_app {
    my $out_buffer = "";
    my $cookie_buffer = "";
    my $response;
    my $request;

    # コマンドを前にずらす
    sub slideFront {
        my($command, $number) = @_;
        my($i);

        # それぞれずらす
        splice(@$command, $number, 1);

        # 最後に資金繰り
        $command->[$HcommandMax - 1] = {
        'kind' => $HcomDoNothing,
        'target' => 0,
        'x' => 0,
        'y' => 0,
        'arg' => 0
        };
    }

# コマンドを後にずらす
    sub slideBack {
        my($command, $number) = @_;
        my($i);

        # それぞれずらす
        return if $number == $#$command;
        pop(@$command);
        splice(@$command, $number, 0, $command->[$number]);
    }

#----------------------------------------------------------------------
# 島データ入出力
#----------------------------------------------------------------------

# 全島データ読みこみ
    sub readIslandsFile {
        my($num) = @_; # 0だと地形読みこまず
                       # -1だと全地形を読む
                       # 番号だとその島の地形だけは読みこむ

        # データファイルを開く
        if(!open(IN, "${HdirName}/hakojima.dat")) {
        rename("${HdirName}/hakojima.tmp", "${HdirName}/hakojima.dat");
        if(!open(IN, "${HdirName}/hakojima.dat")) {
            return 0;
        }
        }

        my $tmp = <IN>;
        $HislandTurn = Hako::DB->get_global_value("turn"); # ターン数
        if ($HislandTurn == 0) {
            return 0;
        }
        my $tmp = <IN>;
        $HislandLastTime = Hako::DB->get_global_value("last_time"); # 最終更新時間
        if ($HislandLastTime == 0) {
            return 0;
        }
        my $tmp = <IN>;
        my $tmp = <IN>;
        $HislandNumber = Hako::DB->get_global_value("number"); # 島の総数
        $HislandNextID = Hako::DB->get_global_value("next_id"); # 次に割り当てるID

        # ターン処理判定
        my($now) = time;
        if ((($Hdebug == 1) && ($HmainMode eq 'Hdebugturn')) || (($now - $HislandLastTime) >= $HunitTime)) {
            $HmainMode = 'turn';
            $num = -1; # 全島読みこむ
        }

        # 島の読みこみ
        my $islands_from_db = Hako::DB->get_islands;
        for (my $i = 0; $i < $HislandNumber; $i++) {
            $Hislands[$i] = readIsland($num, $islands_from_db);
            $HidToNumber{$Hislands[$i]->{'id'}} = $i;
        }

        # ファイルを閉じる
        close(IN);

        return 1;
    }

    # 島ひとつ読みこみ
    sub readIsland {
        my ($num, $islands_from_db) = @_;
        my $island_from_db = Hako::Model::Island->inflate(shift @$islands_from_db);

        my ($name, $id, $prize, $absent, $comment, $password, $money, $food, $pop, $area, $farm, $factory, $mountain, $score);
        my $tmp = <IN>;
        $name = $island_from_db->{name};
        $score = $island_from_db->{score};
        #$name = <IN>; # 島の名前
        #chomp($name);
        #if($name =~ s/,(.*)$//g) {
            #$score = int($1);
        #} else {
            #$score = 0;
        #}
        $id = int(<IN>); # ID番号
        unless (int($island_from_db->{id}) == $id) {
            warn "wrong id: @{[$island_from_db->{id}]}(db) $id(dat)";
        }
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
        $tmp = <IN>;
        $tmp = <IN>;
        $tmp = <IN>;
        $tmp = <IN>;
        $tmp = <IN>;
        $tmp = <IN>;
        $tmp = <IN>;
        $tmp = <IN>;
        $tmp = <IN>;
        $tmp = <IN>;
        $tmp = <IN>;
        #$prize = <IN>;
        #chomp($prize);
        #$absent = int(<IN>);
        #$comment = <IN>; # コメント
        #chomp($comment);
        #$password = <IN>; # 暗号化パスワード
        #chomp($password);
        #$money = int(<IN>);  
        #$food = int(<IN>);   
        #$pop = int(<IN>);    
        #$area = int(<IN>);   
        #$farm = int(<IN>);   
        #$factory = int(<IN>);
        #$mountain = int(<IN>);

        # HidToNameテーブルへ保存
        $HidToName{$id} = $name;

        # 地形
        my(@land, @landValue, $line, @command, @lbbs);

        if(($num == -1) || ($num == $id)) {
            if(!open(IIN, "${HdirName}/island.$id")) {
                rename("${HdirName}/islandtmp.$id", "${HdirName}/island.$id");
                if(!open(IIN, "${HdirName}/island.$id")) {
                    warn "koko?";
                    exit(0);
                }
            }

            my($x, $y);
            for($y = 0; $y < $HislandSize; $y++) {
                $line = <IIN>;
                for($x = 0; $x < $HislandSize; $x++) {
                    $line =~ s/^(.)(..)//;
                    $land[$x][$y] = hex($1);
                    $landValue[$x][$y] = hex($2);
                }
            }

            # コマンド
            for(my $i = 0; $i < $HcommandMax; $i++) {
                $line = <IIN>;
                $line =~ /^([0-9]*),([0-9]*),([0-9]*),([0-9]*),([0-9]*)$/;
                $command[$i] = {
                'kind' => int($1),
                'target' => int($2),
                'x' => int($3),
                'y' => int($4),
                'arg' => int($5)
                }
            }

            # ローカル掲示板
            for($i = 0; $i < $HlbbsMax; $i++) {
                $line = <IIN>;
                chomp($line);
                $lbbs[$i] = $line;
            }

            close(IIN);
        }

        # 島型にして返す
        return Hako::Model::Island->new({
         'name' => $name,
         'id' => $id,
         'score' => $score,
         'prize' => $prize,
         'absent' => $absent,
         'comment' => $comment,
         'password' => $password,
         'money' => $money,
         'food' => $food,
         'pop' => $pop,
         'area' => $area,
         'farm' => $farm,
         'factory' => $factory,
         'mountain' => $mountain,
         'land' => \@land,
         'landValue' => \@landValue,
         'command' => \@command,
         'lbbs' => \@lbbs,
        });
    }

    # 全島データ書き込み
    sub writeIslandsFile {
        my($num) = @_;

        # ファイルを開く
        open(OUT, ">${HdirName}/hakojima.tmp");

        # 各パラメータ書き込み
        print OUT "$HislandTurn\n";
        print OUT "$HislandLastTime\n";
        print OUT "$HislandNumber\n";
        print OUT "$HislandNextID\n";

        Hako::DB->set_global_value("turn", $HislandTurn);
        Hako::DB->set_global_value("last_time", $HislandLastTime);
        Hako::DB->set_global_value("number", $HislandNumber);
        Hako::DB->set_global_value("next_id", $HislandNextID);

        # 島の書きこみ
        for (my $i = 0; $i < $HislandNumber; $i++) {
            writeIsland($Hislands[$i], $num, $i);
        }

        # DB用に放棄された島を消す
        my @dead_islands = grep {$_->{dead} == 1} @Hislands;
        for my $dead_island (@dead_islands) {
            Hako::DB->delete_island($dead_island->{id});
        }

        # ファイルを閉じる
        close(OUT);

        # 本来の名前にする
        unlink("${HdirName}/hakojima.dat");
        rename("${HdirName}/hakojima.tmp", "${HdirName}/hakojima.dat");
    }

    # 島ひとつ書き込み
    sub writeIsland {
        my($island, $num, $sort) = @_;
        my($score);
        $score = int($island->{'score'});
        print OUT $island->{'name'} . ",$score\n";
        print OUT $island->{'id'} . "\n";
        print OUT $island->{'prize'} . "\n";
        print OUT $island->{'absent'} . "\n";
        print OUT $island->{'comment'} . "\n";
        print OUT $island->{'password'} . "\n";
        print OUT $island->{'money'} . "\n";
        print OUT $island->{'food'} . "\n";
        print OUT $island->{'pop'} . "\n";
        print OUT $island->{'area'} . "\n";
        print OUT $island->{'farm'} . "\n";
        print OUT $island->{'factory'} . "\n";
        print OUT $island->{'mountain'} . "\n";

        # 地形
        if(($num <= -1) || ($num == $island->{'id'})) {
            open(IOUT, ">${HdirName}/islandtmp.$island->{'id'}");

            my($land, $landValue);
            $land = $island->{'land'};
            $landValue = $island->{'landValue'};
            my $land_str = "";
            my($x, $y);
            for($y = 0; $y < $HislandSize; $y++) {
                for($x = 0; $x < $HislandSize; $x++) {
                    printf IOUT ("%x%02x", $land->[$x][$y], $landValue->[$x][$y]);
                    $land_str .= sprintf("%x%02x", $land->[$x][$y], $landValue->[$x][$y]);
                }
                $land_str .= "\n";
                print IOUT "\n";
            }
            $island->{map} = $land_str;
            Hako::DB->save_island($island, $sort);

            # コマンド
            my($command, $cur, $i);
            $command = $island->{'command'};
            for($i = 0; $i < $HcommandMax; $i++) {
                printf IOUT ("%d,%d,%d,%d,%d\n", 
                     $command->[$i]->{'kind'},
                     $command->[$i]->{'target'},
                     $command->[$i]->{'x'},
                     $command->[$i]->{'y'},
                     $command->[$i]->{'arg'}
                     );
            }
            Hako::DB->save_command($island->{id}, $island->{command});

            # ローカル掲示板
            my($lbbs);
            $lbbs = $island->{'lbbs'};
            for($i = 0; $i < $HlbbsMax; $i++) {
                print IOUT $lbbs->[$i] . "\n";
            }

            close(IOUT);
            unlink("${HdirName}/island.$island->{'id'}");
            rename("${HdirName}/islandtmp.$island->{'id'}", "${HdirName}/island.$island->{'id'}");
        }
    }

#----------------------------------------------------------------------
# 入出力
#----------------------------------------------------------------------

    # 標準出力への出力
    sub out {
        $out_buffer .= sprintf("%s", Encode::encode("Shift_JIS", Encode::decode("EUC-JP", $_[0])));
    }

    # デバッグログ
    sub HdebugOut {
       open(DOUT, ">>debug.log");
       print DOUT ($_[0]);
       close(DOUT);
    }

    # CGIの読みこみ
    sub cgiInput {
        my $params = $request->parameters;
        use Data::Dumper;warn Data::Dumper::Dumper($params);
        # 対象の島
        if (List::MoreUtils::any {$_ =~ /CommandButton([0-9]+)/} $params->keys) {
            my @tmp = grep {$_ =~ /^CommandButton/} $params->keys;
            $tmp[0] =~ /CommandButton([0-9]+)/;
            # コマンド送信ボタンの場合
            $HcurrentID = $1;
            $defaultID = $1;
        }

        if (List::MoreUtils::any {$_ eq "ISLANDNAME"} $params->keys) {
            # 名前指定の場合
            $HcurrentName = cutColumn($params->get("ISLANDNAME"), 32);
        }

        if (List::MoreUtils::any { $_ eq "ISLANDID" } $params->keys) {
            # その他の場合
            $HcurrentID = $params->get("ISLANDID");
            $defaultID = $params->get("ISLANDID");
        }

        # パスワード
        if ($line =~ /OLDPASS=([^\&]*)\&/) {
            $HoldPassword = $params->get("OLDPASS");
            $HdefaultPassword = $params->get("OLDPASS");
        }
        if (List::MoreUtils::any {$_ eq "PASSWORD"} $params->keys) {
            $HinputPassword = $params->get("PASSWORD");
            $HdefaultPassword = $params->get("PASSWORD");
        }
        if (List::MoreUtils::any {$_ eq "PASSWORD2"} $params->keys) {
            $HinputPassword2 = $params->get("PASSWORD2");
        }

        # メッセージ
        if (List::MoreUtils::any {$_ eq "MESSAGE"} $params->keys) {
            $Hmessage = cutColumn($params->get("MESSAGE"), 80);
        }

        # ローカル掲示板
        if (List::MoreUtils::any {$_ eq "LBBSNAME"} $params->keys) {
            $HlbbsName = $params->get("LBBSNAME");
            $HdefaultName = $params->get("LBBSNAME");
        }
        if (List::MoreUtils::any {$_ eq "LBBSMESSAGE"} $params->keys) {
            $HlbbsMessage = cutColumn($params->get("LBBSMESSAGE"), 80);
        }

        # main modeの取得
        $HmainMode = "top";
        if(List::MoreUtils::any {$_ eq "TurnButton"} $params->keys) {
            if($Hdebug == 1) {
                $HmainMode = 'Hdebugturn';
            }
        } elsif (List::MoreUtils::any {$_ eq "OwnerButton"} $params->keys) {
            $HmainMode = 'owner';
        } elsif (List::MoreUtils::any {$_ eq "Sight"} $params->keys) {
            $HmainMode = 'print';
            $HcurrentID = $params->get("Sight");
        } elsif (List::MoreUtils::any {$_ eq "NewIslandButton"} $params->keys) {
            $HmainMode = 'new';
        } elsif (List::MoreUtils::any {$_ =~ /LbbsButton(..)([0-9]*)/} $params->keys) {
            $HmainMode = 'lbbs';
            if ($1 eq 'SS') {
                # 観光者
                $HlbbsMode = 0;
            } elsif($1 eq 'OW') {
                # 島主
                $HlbbsMode = 1;
            } else {
                # 削除
                $HlbbsMode = 2;
            }
            $HcurrentID = $2;

            # 削除かもしれないので、番号を取得
            $HcommandPlanNumber = $params->get("NUMBER");

        } elsif (List::MoreUtils::any {$_ eq "ChangeInfoButton"} $params->keys) {
            $HmainMode = 'change';
        } elsif (List::MoreUtils::any {$_ =~ /MessageButton([0-9]*)/} $params->keys) {
            $HmainMode = 'comment';
            $HcurrentID = $1;
        } elsif (List::MoreUtils::any {$_ =~ /CommandButton/} $params->keys) {
            $HmainMode = 'command';

            # コマンドモードの場合、コマンドの取得
            $HcommandPlanNumber = $params->get("NUMBER");
            $HcommandKind = $params->get("COMMAND");
            $HdefaultKind = $params->get("COMMAND");
            $HcommandArg = $params->get("AMOUNT");
            $HcommandTarget = $params->get("TARGETID");
            $defaultTarget = $params->get("TARGETID");
            $HcommandX = $params->get("POINTX");
            $HdefaultX = $params->get("POINTX");
            $HcommandY = $params->get("POINTY");
            $HdefaultY = $params->get("POINTY");
            $HcommandMode = $params->get("COMMANDMODE");
        } else {
            $HmainMode = 'top';
        }
    }


    #cookie入力
    sub cookieInput {
        my($cookie);

        $cookie = Encode::encode("EUC-JP", Encode::decode("Shift_JIS", $ENV{'HTTP_COOKIE'}));

        if($cookie =~ /${HthisFile}OWNISLANDID=\(([^\)]*)\)/) {
            $defaultID = $1;
        }
        if($cookie =~ /${HthisFile}OWNISLANDPASSWORD=\(([^\)]*)\)/) {
            $HdefaultPassword = $1;
        }
        if($cookie =~ /${HthisFile}TARGETISLANDID=\(([^\)]*)\)/) {
            $defaultTarget = $1;
        }
        if($cookie =~ /${HthisFile}LBBSNAME=\(([^\)]*)\)/) {
            $HdefaultName = $1;
        }
        if($cookie =~ /${HthisFile}POINTX=\(([^\)]*)\)/) {
            $HdefaultX = $1;
        }
        if($cookie =~ /${HthisFile}POINTY=\(([^\)]*)\)/) {
            $HdefaultY = $1;
        }
        if($cookie =~ /${HthisFile}KIND=\(([^\)]*)\)/) {
            $HdefaultKind = $1;
        }

    }

    #cookie出力
    sub cookieOutput {
        my($cookie, $info);

        # 消える期限の設定
        my($sec, $min, $hour, $date, $mon, $year, $day, $yday, $dummy) =
        gmtime(time + 30 * 86400); # 現在 + 30日

        # 2ケタ化
        $year += 1900;
        if ($date < 10) { $date = "0$date"; }
        if ($hour < 10) { $hour = "0$hour"; }
        if ($min < 10) { $min  = "0$min"; }
        if ($sec < 10) { $sec  = "0$sec"; }

        # 曜日を文字に
        $day = ("Sunday", "Monday", "Tuesday", "Wednesday",
            "Thursday", "Friday", "Saturday")[$day];

        # 月を文字に
        $mon = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")[$mon];

        # パスと期限のセット
        $info = "; expires=$day, $date\-$mon\-$year $hour:$min:$sec GMT\n";

        if(($HcurrentID) && ($HmainMode eq 'owner')){
            $cookie_buffer .= "${HthisFile}OWNISLANDID=($HcurrentID) $info";
        }
        if($HinputPassword) {
            $cookie_buffer .= "${HthisFile}OWNISLANDPASSWORD=($HinputPassword) $info";
        }
        if($HcommandTarget) {
            $cookie_buffer .= "${HthisFile}TARGETISLANDID=($HcommandTarget) $info";
        }
        if($HlbbsName) {
            $cookie_buffer .= "${HthisFile}LBBSNAME=($HlbbsName) $info";
        }
        if($HcommandX) {
            $cookie_buffer .= "${HthisFile}POINTX=($HcommandX) $info";
        }
        if($HcommandY) {
            $cookie_buffer .= "${HthisFile}POINTY=($HcommandY) $info";
        }
        if($HcommandKind) {
            # 自動系以外
            $cookie_buffer .= "${HthisFile}KIND=($HcommandKind) $info";
        }
    }

#----------------------------------------------------------------------
# ユーティリティ
#----------------------------------------------------------------------
    sub hakolock {
        if($lockMode == 1) {
        # directory式ロック
        return hakolock1();

        } elsif($lockMode == 2) {
        # flock式ロック
        return hakolock2();
        } elsif($lockMode == 3) {
        # symlink式ロック
        return hakolock3();
        } else {
        # 通常ファイル式ロック
        return hakolock4();
        }
    }

    sub hakolock1 {
        # ロックを試す
        if(mkdir('hakojimalock', $HdirMode)) {
        # 成功
        return 1;
        } else {
        # 失敗
        my($b) = (stat('hakojimalock'))[9];
        if(($b > 0) && ((time() -  $b)> $unlockTime)) {
            # 強制解除
            unlock();

            # ヘッダ出力
            tempHeader();

            # 強制解除メッセージ
            tempUnlock();

            # フッタ出力
            tempFooter();

            # 終了
            warn "no way";
            exit(0);
        }
        return 0;
        }
    }

    sub hakolock2 {
        open(LOCKID, '>>hakojimalockflock');
        if(flock(LOCKID, 2)) {
        # 成功
        return 1;
        } else {
        # 失敗
        return 0;
        }
    }

    sub hakolock3 {
        # ロックを試す
        if(symlink('hakojimalockdummy', 'hakojimalock')) {
        # 成功
        return 1;
        } else {
        # 失敗
        my($b) = (lstat('hakojimalock'))[9];
        if(($b > 0) && ((time() -  $b)> $unlockTime)) {
            # 強制解除
            unlock();

            # ヘッダ出力
            tempHeader();

            # 強制解除メッセージ
            tempUnlock();

            # フッタ出力
            tempFooter();

            # 終了
            warn "ihr";
            exit(0);
        }
        return 0;
        }
    }

    sub hakolock4 {
        # ロックを試す
        if(unlink('key-free')) {
        # 成功
        open(OUT, '>key-locked');
        print OUT time;
        close(OUT);
        return 1;
        } else {
        # ロック時間チェック
        if(!open(IN, 'key-locked')) {
            return 0;
        }

        my($t);
        $t = <IN>;
        close(IN);
        if(($t != 0) && (($t + $unlockTime) < time)) {
            # 120秒以上経過してたら、強制的にロックを外す
            unlock();

            # ヘッダ出力
            tempHeader();

            # 強制解除メッセージ
            tempUnlock();

            # フッタ出力
            tempFooter();

            # 終了
            warn "hoge";
            exit(0);
        }
        return 0;
        }
    }

# ロックを外す
    sub unlock {
        if($lockMode == 1) {
        # directory式ロック
        rmdir('hakojimalock');

        } elsif($lockMode == 2) {
        # flock式ロック
        close(LOCKID);

        } elsif($lockMode == 3) {
        # symlink式ロック
        unlink('hakojimalock');
        } else {
        # 通常ファイル式ロック
        my($i);
        $i = rename('key-locked', 'key-free');
        }
    }

# 小さい方を返す
    sub min {
        return ($_[0] < $_[1]) ? $_[0] : $_[1];
    }

# パスワードエンコード
    sub encode {
        if($cryptOn == 1) {
        return crypt($_[0], 'h2');
        } else {
        return $_[0];
        }
    }

# パスワードチェック
    sub checkPassword {
        my($p1, $p2) = @_;

        # nullチェック
        if($p2 eq '') {
        return 0;
        }

        # マスターパスワードチェック
        if($masterPassword eq $p2) {
        return 1;
        }

        # 本来のチェック
        if($p1 eq encode($p2)) {
        return 1;
        }

        return 0;
    }

# 1000億単位丸めルーチン
    sub aboutMoney {
        my($m) = @_;
        if($m < 500) {
        return "推定500${HunitMoney}未満";
        } else {
        $m = int(($m + 500) / 1000);
        return "推定${m}000${HunitMoney}";
        }
    }

# エスケープ文字の処理
    sub htmlEscape {
        my($s) = @_;
        $s =~ s/&/&amp;/g;
        $s =~ s/</&lt;/g;
        $s =~ s/>/&gt;/g;
        $s =~ s/\"/&quot;/g; #"
        return $s;
    }

# 80ケタに切り揃え
    sub cutColumn {
        my($s, $c) = @_;
        if(length($s) <= $c) {
        return $s;
        } else {
        # 合計80ケタになるまで切り取り
        my($ss) = '';
        my($count) = 0;
        while($count < $c) {
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

# 島の名前から番号を得る(IDじゃなくて番号)
    sub nameToNumber {
        my($name) = @_;

        # 全島から探す
        my($i);
        for($i = 0; $i < $HislandNumber; $i++) {
        if($Hislands[$i]->{'name'} eq $name) {
            return $i;
        }
        }

        # 見つからなかった場合
        return -1;
    }

# 怪獣の情報
    sub monsterSpec {
        my($lv) = @_;

        # 種類
        my($kind) = int($lv / 10);

        # 名前
        my($name);
        $name = $HmonsterName[$kind];

        # 体力
        my($hp) = $lv - ($kind * 10);
        
        return ($kind, $name, $hp);
    }

# 経験地からレベルを算出
    sub expToLevel {
        my($kind, $exp) = @_;
        my($i);
        if($kind == $HlandBase) {
        # ミサイル基地
        for($i = $maxBaseLevel; $i > 1; $i--) {
            if($exp >= $baseLevelUp[$i - 2]) {
            return $i;
            }
        }
        return 1;
        } else {
        # 海底基地
        for($i = $maxSBaseLevel; $i > 1; $i--) {
            if($exp >= $sBaseLevelUp[$i - 2]) {
            return $i;
            }
        }
        return 1;
        }

    }

# (0,0)から(size - 1, size - 1)までの数字が一回づつ出てくるように
# (@Hrpx, @Hrpy)を設定
    sub makeRandomPointArray {
        # 初期値
        my($y);
        @Hrpx = (0..$HislandSize-1) x $HislandSize;
        for($y = 0; $y < $HislandSize; $y++) {
        push(@Hrpy, ($y) x $HislandSize);
        }

        # シャッフル
        my ($i);
        for ($i = $HpointNumber; --$i; ) {
        my($j) = int(rand($i+1)); 
        if($i == $j) { next; }
        @Hrpx[$i,$j] = @Hrpx[$j,$i];
        @Hrpy[$i,$j] = @Hrpy[$j,$i];
        }
    }

# 0から(n - 1)の乱数
    sub random {
        return int(rand(1) * $_[0]);
    }

#----------------------------------------------------------------------
# ログ表示
#----------------------------------------------------------------------
# ファイル番号指定でログ表示
    sub logFilePrint {
        my($fileNumber, $id, $mode) = @_;
        open(LIN, "${HdirName}/hakojima.log$_[0]");
        my($line, $m, $turn, $id1, $id2, $message);
        while($line = <LIN>) {
        $line =~ /^([0-9]*),([0-9]*),([0-9]*),([0-9]*),(.*)$/;
        ($m, $turn, $id1, $id2, $message) = ($1, $2, $3, $4, $5);

        # 機密関係
        if($m == 1) {
            if(($mode == 0) || ($id1 != $id)) {
            # 機密表示権利なし
            next;
            }
            $m = '<B>(機密)</B>';
        } else {
            $m = '';
        }

        # 表示的確か
        if($id != 0) {
            if(($id != $id1) &&
               ($id != $id2)) {
            next;
            }
        }

        # 表示
        out("<NOBR>${HtagNumber_}ターン$turn$m${H_tagNumber}：$message</NOBR><BR>\n");
        }
        close(LIN);
    }

#----------------------------------------------------------------------
# テンプレート
#----------------------------------------------------------------------
# 初期化
    sub tempInitialize {
        # 島セレクト(デフォルト自分)
        $HislandList = getIslandList($defaultID);
        $HtargetList = getIslandList($defaultTarget);
    }

# 島データのプルダウンメニュー用
    sub getIslandList {
        my($select) = @_;
        my($list, $name, $id, $s, $i);

        #島リストのメニュー
        $list = '';
        for($i = 0; $i < $HislandNumber; $i++) {
        $name = $Hislands[$i]->{'name'};
        $id = $Hislands[$i]->{'id'};
        if($id eq $select) {
            $s = 'SELECTED';
        } else {
            $s = '';
        }
        $list .=
            "<OPTION VALUE=\"$id\" $s>${name}島\n";
        }
        return $list;
    }


# ヘッダ
    sub tempHeader {
        my $xslate = Text::Xslate->new(syntax => 'TTerse');
        my %vars = (
            title => Encode::decode("EUC-JP", $Htitle),
            image_dir => mark_raw($imageDir),
            html_body => mark_raw($htmlBody),
        );
        out(Encode::encode("EUC-JP", $xslate->render("tmpl/header.tt", \%vars)));
    }

# フッタ
    sub tempFooter {
        my $xslate = Text::Xslate->new(syntax => 'TTerse');
        my %vars = (
            admin_name => Encode::decode("EUC-JP", $adminName),
            email => $email,
            bbs => $bbs,
            toppage => $toppage,
        );
        out(Encode::encode("EUC-JP", $xslate->render("tmpl/footer.tt", \%vars)));
    }

# ロック失敗
    sub tempLockFail {
        # タイトル
        out(<<END);
    ${HtagBig_}同時アクセスエラーです。<BR>
    ブラウザの「戻る」ボタンを押し、<BR>
    しばらく待ってから再度お試し下さい。${H_tagBig}$HtempBack
END
    }

# 強制解除
    sub tempUnlock {
        # タイトル
        out(<<END);
    ${HtagBig_}前回のアクセスが異常終了だったようです。<BR>
    ロックを強制解除しました。${H_tagBig}$HtempBack
END
    }

# hakojima.datがない
    sub tempNoDataFile {
        out(<<END);
    ${HtagBig_}データファイルが開けません。${H_tagBig}$HtempBack
END
    }

# パスワード間違い
    sub tempWrongPassword {
        out(<<END);
    ${HtagBig_}パスワードが違います。${H_tagBig}$HtempBack
END
    }

# 何か問題発生
    sub tempProblem {
        out(<<END);
    ${HtagBig_}問題発生、とりあえず戻ってください。${H_tagBig}$HtempBack
END
    }

    return sub {
        my ($env) = @_;

        $out_buffer = "";
        $cookie_buffer = "";
        $request = Plack::Request->new($env);
        $response = Plack::Response->new(200);
        $response->content_type("text/html");

        # ロックをかける
        if(!hakolock()) {
            # ロック失敗
            # ヘッダ出力
            tempHeader();

            # ロック失敗メッセージ
            tempLockFail();

            # フッタ出力
            tempFooter();

            # 終了
            exit(0);
        }

        # 乱数の初期化
        srand(time^$$);

        # COOKIE読みこみ
        cookieInput();

        # CGI読みこみ
        cgiInput();

        # 島データの読みこみ
        if(readIslandsFile($HcurrentID) == 0) {
            unlock();
            tempHeader();
            tempNoDataFile();
            tempFooter();
            exit(0);
        }

        # テンプレートを初期化
        tempInitialize();

        # COOKIE出力
        cookieOutput();

        # ヘッダ出力
        tempHeader();

        if($HmainMode eq 'turn') {
            # ターン進行
            require('hako-turn.cgi');
            require('hako-top.cgi');
            turnMain();

        } elsif($HmainMode eq 'new') {
            # 島の新規作成
            require('hako-turn.cgi');
            require('hako-map.cgi');
            newIslandMain();

        } elsif($HmainMode eq 'print') {
            # 観光モード
            require('hako-map.cgi');
            printIslandMain();

        } elsif($HmainMode eq 'owner') {

            # 開発モード
            require('hako-map.cgi');
            ownerMain();

        } elsif($HmainMode eq 'command') {
            # コマンド入力モード
            require('hako-map.cgi');
            commandMain();

        } elsif($HmainMode eq 'comment') {
            # コメント入力モード
            require('hako-map.cgi');
            commentMain();

        } elsif($HmainMode eq 'lbbs') {

            # ローカル掲示板モード
            require('hako-map.cgi');
            localBbsMain();

        } elsif($HmainMode eq 'change') {
            # 情報変更モード
            require('hako-turn.cgi');
            require('hako-top.cgi');
            changeMain();

        } else {
            # その他の場合はトップページモード
            require('hako-top.cgi');
            topPageMain();
        }

        # フッタ出力
        tempFooter();

        $response->body($out_buffer);
        $response->headers({"Set-Cookie" => $cookie_buffer});
        return $response->finalize;
    };
}

1;
