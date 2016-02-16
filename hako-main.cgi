# vim: set ft=perl:
package MainApp;
use utf8;
use strict;
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

#my($baseDir) = Hako::Config::BASE_DIR;

# 画像ファイルを置くディレクトリ
# my($imageDir) = 'http://サーバー/ディレクトリ';
#my($imageDir) = Hako::Config::IMAGE_DIR;

# マスターパスワード
# このパスワードは、すべての島のパスワードを代用できます。
# 例えば、「他の島のパスワード変更」等もできます。
#my($masterPassword) = Hako::Config::MASTER_PASSWORD;

# 特殊パスワード
# このパスワードで「名前変更」を行うと、その島の資金、食料が最大値になります。
# (実際に名前を変える必要はありません。)
#$HspecialPassword = Hako::Config::SPECIAL_PASSWORD;

# 管理者名
#my($adminName) = Hako::Config::ADMIN_NAME;

# 管理者のメールアドレス
#my($email) = Hako::Config::ADMIN_EMAIL;

# 掲示板アドレス
#my($bbs) = Hako::Config::BBS_URL();

# ホームページのアドレス
#my($toppage) = Hako::Config::TOPPAGE_URL;

# ディレクトリのパーミッション
# 通常は0755でよいが、0777、0705、0704等でないとできないサーバーもあるらしい
#$HdirMode = 0755;

# データディレクトリの名前
# ここで設定した名前のディレクトリ以下にデータが格納されます。
# デフォルトでは'data'となっていますが、セキュリティのため
# なるべく違う名前に変更してください。
#$HdirName = Hako::Config::DATA_DIR;

# データの書き込み方

# ロックの方式
# 1 ディレクトリ
# 2 システムコール(可能ならば最も望ましい)
# 3 シンボリックリンク
# 4 通常ファイル(あまりお勧めでない)
#my($lockMode) = Hako::Config::LOCK_MODE;

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
#$HunitTime = Hako::Config::UNIT_TIME; # 6時間

# 島の最大数
#$HmaxIsland = Hako::Config::MAX_ISLAND;

# トップページに表示するログのターン数
#$HtopLogTurn = Hako::Config::TOP_LOG_TURN;

# ログファイル保持ターン数
#$HlogMax = Hako::Config::LOG_MAX;

# バックアップを何ターンおきに取るか
#$HbackupTurn = Hako::Config::BACKUP_TURN;

# バックアップを何回分残すか
#$HbackupTimes = Hako::Config::BACKUP_TIMES;

# 発見ログ保持行数
#$HhistoryMax = Hako::Config::HISTORY_MAX;

# 放棄コマンド自動入力ターン数
#$HgiveupTurn = Hako::Config::GIVEUP_TURN;

# コマンド入力限界数
# (ゲームが始まってから変更すると、データファイルの互換性が無くなります。)
#$HcommandMax = Hako::Config::COMMAND_MAX;

# ローカル掲示板行数を使用するかどうか(0:使用しない、1:使用する)
#$HuseLbbs = Hako::Config::USE_LOCAL_BBS;

# ローカル掲示板行数
#$HlbbsMax = Hako::Config::LOCAL_BBS_MAX;

# 島の大きさ
# (変更できないかも)
#$HislandSize = Hako::Config::ISLAND_SIZE;

# 他人から資金を見えなくするか
# 0 見えない
# 1 見える
# 2 100の位で四捨五入
#$HhideMoneyMode = Hako::Config::HIDE_MONEY_MODE;

# パスワードの暗号化(0だと暗号化しない、1だと暗号化する)
#my($cryptOn) = Hako::Config::CRYPT;

# デバッグモード(1だと、「ターンを進める」ボタンが使用できる)
#$Hdebug = Hako::Config::DEBUG;

#----------------------------------------
# 資金、食料などの設定値と単位
#----------------------------------------
# 初期資金
#$HinitialMoney = Hako::Config::INITIAL_MONEY;

# 初期食料
#$HinitialFood = Hako::Config::INITIAL_FOOD;

# お金の単位
#$HunitMoney = Hako::Config::UNIT_MONEY;

# 食料の単位
#$HunitFood = Hako::Config::UNIT_FOOD;

# 人口の単位
#$HunitPop = Hako::Config::UNIT_POPULATION;

# 広さの単位
#$HunitArea = Hako::Config::UNIT_AREA;

# 木の数の単位
#$HunitTree = Hako::Config::UNIT_TREE;

# 木の単位当たりの売値
#$HtreeValue = Hako::Config::TREE_VALUE;

# 名前変更のコスト
#$HcostChangeName = Hako::Config::CHANGE_NAME_COST;

# 人口1単位あたりの食料消費料
#$HeatenFood = Hako::Config::EATEN_FOOD;

#----------------------------------------
# 基地の経験値
#----------------------------------------
# 経験値の最大値
#$HmaxExpPoint = Hako::Config::MAX_EXP_POINT; # ただし、最大でも255まで

# レベルの最大値
#my($maxBaseLevel) = Hako::Config::MAX_BASE_LEVEL;  # ミサイル基地
#my($maxSBaseLevel) = Hako::Config::MAX_SEA_BASE_LEVEL; # 海底基地

# 経験値がいくつでレベルアップか
#my(@baseLevelUp, @sBaseLevelUp);
#@baseLevelUp = @{Hako::Config::BASE_LEVEL_UP()}; # ミサイル基地
#@sBaseLevelUp = @{Hako::Config::SEA_BASE_LEVEL_UP()};         # 海底基地

#----------------------------------------
# 防衛施設の自爆
#----------------------------------------
# 怪獣に踏まれた時自爆するなら1、しないなら0
#$HdBaseAuto = Hako::Config::DEFENCE_BASE_AUTO;

#----------------------------------------
# 災害
#----------------------------------------
# 通常災害発生率(確率は0.1%単位)
#$HdisEarthquake = Hako::Config::DISASTER_EARTHQUAKE;  # 地震
#$HdisTsunami    = Hako::Config::DISASTER_TSUNAMI; # 津波
#$HdisTyphoon    = Hako::Config::DISASTER_TYPHOON; # 台風
#$HdisMeteo      = Hako::Config::DISASTER_METEO; # 隕石
#$HdisHugeMeteo  = Hako::Config::DISASTER_HUGE_METEO;  # 巨大隕石
#$HdisEruption   = Hako::Config::DISASTER_ERUPTION; # 噴火
#$HdisFire       = Hako::Config::DISASTER_FIRE; # 火災
#$HdisMaizo      = Hako::Config::DISASTER_MAIZO; # 埋蔵金

# 地盤沈下
#$HdisFallBorder = Hako::Config::DISASTER_FALL_BORDER; # 安全限界の広さ(Hex数)
#$HdisFalldown   = Hako::Config::DISASTER_FALL_DOWN; # その広さを超えた場合の確率

# 怪獣
#$HdisMonsBorder1 = Hako::Config::DISASTER_MONSTER_BORDER1; # 人口基準1(怪獣レベル1)
#$HdisMonsBorder2 = Hako::Config::DISASTER_MONSTER_BORDER2; # 人口基準2(怪獣レベル2)
#$HdisMonsBorder3 = Hako::Config::DISASTER_MONSTER_BORDER3; # 人口基準3(怪獣レベル3)
#$HdisMonster     = Hako::Config::DISASTER_MONSTER;    # 単位面積あたりの出現率(0.01%単位)

# 種類
#$HmonsterNumber  = Hako::Config::MONSTER_NUMBER;

# 各基準において出てくる怪獣の番号の最大値
#$HmonsterLevel1  = Hako::Config::MONSTER_LEVEL1; # サンジラまで
#$HmonsterLevel2  = Hako::Config::MONSTER_LEVEL2; # いのらゴーストまで
#$HmonsterLevel3  = Hako::Config::MONSTER_LEVEL3; # キングいのらまで(全部)

# 名前
#@HmonsterName = map { $_ } @{Hako::Config::MONSTER_NAME()};

# 最低体力、体力の幅、特殊能力、経験値、死体の値段
#@HmonsterBHP     = @{Hako::Config::MONSTER_BOTTOM_HP};
#@HmonsterDHP     = @{Hako::Config::MONSTER_DHP};
#@HmonsterSpecial = @{Hako::Config::MONSTER_SPECIAL};
#@HmonsterExp     = @{Hako::Config::MONSTER_EXP};
#@HmonsterValue   = @{Hako::Config::MONSTER_VALUE};

# 特殊能力の内容は、
# 0 特になし
# 1 足が速い(最大2歩あるく)
# 2 足がとても速い(最大何歩あるくか不明)
# 3 奇数ターンは硬化
# 4 偶数ターンは硬化

# 画像ファイル
#@HmonsterImage = @{Hako::Config::MONSTER_IMAGE()};

# 画像ファイルその2(硬化中)
#@HmonsterImage2 = @{Hako::Config::MONSTER_IMAGE2()};


#----------------------------------------
# 油田
#----------------------------------------
# 油田の収入
#$HoilMoney = Hako::Config::OIL_MONEY;

# 油田の枯渇確率
#$HoilRatio = Hako::Config::OIL_RAITO;

#----------------------------------------
# 記念碑
#----------------------------------------
# 何種類あるか
#$HmonumentNumber = Hako::Config::MONUMENT_NUMBER;

# 名前
#@HmonumentName = map { $_ } @{Hako::Config::MONUMEBT_NAME};

# 画像ファイル
#@HmonumentImage = @{Hako::Config::MONUMENT_IMAGE};

#----------------------------------------
# 賞関係
#----------------------------------------
# ターン杯を何ターン毎に出すか
#$HturnPrizeUnit = Hako::Config::TURN_PRIZE_UNIT;

# 賞の名前
#@Hprize = map { $_  } @{Hako::Config::PRIZE};

#----------------------------------------
# 外見関係
#----------------------------------------
# <BODY>タグのオプション
#my($htmlBody) = Hako::Config::HTML_BODY;

# ゲームのタイトル文字
#$Htitle = Hako::Config::TITLE;

# タグ
# タイトル文字
#$HtagTitle_ = Hako::Config::TAG_TITLE_;
#$H_tagTitle = Hako::Config::_TAG_TITLE;

# H1タグ用
#$HtagHeader_ = Hako::Config::TAG_HEADER_;
#$H_tagHeader = Hako::Config::_TAG_HEADER;

# 大きい文字
#$HtagBig_ = Hako::Config::TAG_BIG_;
#$H_tagBig = Hako::Config::_TAG_BIG;

# 島の名前など
#$HtagName_ = Hako::Config::TAG_NAME_;
#$H_tagName = Hako::Config::_TAG_NAME;

# 薄くなった島の名前
#$HtagName2_ = Hako::Config::TAG_NAME2_;
#$H_tagName2 = Hako::Config::_TAG_NAME2;

# 順位の番号など
#$HtagNumber_ = Hako::Config::TAG_NUMBER_;
#$H_tagNumber = Hako::Config::_TAG_NUMBER;

# 順位表における見だし
#$HtagTH_ = Hako::Config::TAG_TH_;
#$H_tagTH = Hako::Config::_TAG_TH;

# 開発計画の名前
#$HtagComName_ = Hako::Config::TAG_COM_NAME_;
#$H_tagComName = Hako::Config::_TAG_COM_NAME;

# 災害
#$HtagDisaster_ = Hako::Config::TAG_DISASTER_;
#$H_tagDisaster = Hako::Config::_TAG_DISASTER;

# ローカル掲示板、観光者の書いた文字
#$HtagLbbsSS_ = Hako::Config::TAG_LOCAL_BBS_SS_;
#$H_tagLbbsSS = Hako::Config::_TAG_LOCAL_BBS_SS;

# ローカル掲示板、島主の書いた文字
#$HtagLbbsOW_ = Hako::Config::TAG_LOCAL_BBS_OW_;
#$H_tagLbbsOW = Hako::Config::_TAG_LOCAL_BBS_OW;

# 通常の文字色(これだけでなく、BODYタグのオプションもちゃんと変更すべし
#$HnormalColor = Hako::Config::NORMAL_COLOR;

# 順位表、セルの属性
#$HbgTitleCell   = Hako::Config::BG_TITLE_CELL; # 順位表見出し
#$HbgNumberCell  = Hako::Config::BG_NUMBER_CELL; # 順位表順位
#$HbgNameCell    = Hako::Config::BG_NAME_CELL; # 順位表島の名前
#$HbgInfoCell    = Hako::Config::BG_INFO_CELL; # 順位表島の情報
#$HbgCommentCell = Hako::Config::BG_COMMENT_CELL; # 順位表コメント欄
#$HbgInputCell   = Hako::Config::BG_INPUT_CELL; # 開発計画フォーム
#$HbgMapCell     = Hako::Config::BG_MAP_CELL; # 開発計画地図
#$HbgCommandCell = Hako::Config::BG_COMMAND_CELL; # 開発計画入力済み計画

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
#$HthisFile = "$baseDir/hako-main.cgi";

# 地形番号
#$HlandSea      = Hako::Constants::LAND_SEA;  # 海
#$HlandWaste    = Hako::Constants::LAND_WASTE;  # 荒地
#$HlandPlains   = Hako::Constants::LAND_PLAINS;  # 平地
#$HlandTown     = Hako::Constants::LAND_TOWN;  # 町系
#$HlandForest   = Hako::Constants::LAND_FOREST;  # 森
#$HlandFarm     = Hako::Constants::LAND_FARM;  # 農場
#$HlandFactory  = Hako::Constants::LAND_FACTORY;  # 工場
#$HlandBase     = Hako::Constants::LAND_BASE;  # ミサイル基地
#$HlandDefence  = Hako::Constants::LAND_DEFENCE;  # 防衛施設
#$HlandMountain = Hako::Constants::LAND_MOUNTAIN;  # 山
#$HlandMonster  = Hako::Constants::LAND_MONSTER; # 怪獣
#$HlandSbase    = Hako::Constants::LAND_SEA_BASE; # 海底基地
#$HlandOil      = Hako::Constants::LAND_OIL; # 海底油田
#$HlandMonument = Hako::Constants::LAND_MONUMENT; # 記念碑
#$HlandHaribote = Hako::Constants::LAND_HARIBOTE; # ハリボテ

# コマンド
#$HcommandTotal = Hako::Constants::COMMAND_TOTAL_NUM; # コマンドの種類

# 計画番号の設定
# 整地系
#$HcomPrepare  = Hako::Constants::COMMAND_PREPARE; # 整地
#$HcomPrepare2 = Hako::Constants::COMMAND_PREPARE2; # 地ならし
#$HcomReclaim  = Hako::Constants::COMMAND_RECLAIM; # 埋め立て
#$HcomDestroy  = Hako::Constants::COMMAND_DESTROY; # 掘削
#$HcomSellTree = Hako::Constants::COMMAND_SELL_TREE; # 伐採

# 作る系
#$HcomPlant    = Hako::Constants::COMMAND_PLANT; # 植林
#$HcomFarm     = Hako::Constants::COMMAND_FARM; # 農場整備
#$HcomFactory  = Hako::Constants::COMMAND_FACTORY; # 工場建設
#$HcomMountain = Hako::Constants::COMMAND_MOUNTAIN; # 採掘場整備
#$HcomBase     = Hako::Constants::COMMAND_BASE; # ミサイル基地建設
#$HcomDbase    = Hako::Constants::COMMAND_DEFENCE_BASE; # 防衛施設建設
#$HcomSbase    = Hako::Constants::COMMAND_SEABASE; # 海底基地建設
#$HcomMonument = Hako::Constants::COMMAND_MONUMENT; # 記念碑建造
#$HcomHaribote = Hako::Constants::COMMAND_HARIBOTE; # ハリボテ設置

# 発射系
#$HcomMissileNM   = Hako::Constants::COMMAND_MISSILE_NM; # ミサイル発射
#$HcomMissilePP   = Hako::Constants::COMMAND_MISSILE_PP; # PPミサイル発射
#$HcomMissileST   = Hako::Constants::COMMAND_MISSILE_ST; # STミサイル発射
#$HcomMissileLD   = Hako::Constants::COMMAND_MISSILE_LD; # 陸地破壊弾発射
#$HcomSendMonster = Hako::Constants::COMMAND_SEND_MONSTER; # 怪獣派遣

# 運営系
#$HcomDoNothing  = Hako::Constants::COMMAND_DO_NOTHING; # 資金繰り
#$HcomSell       = Hako::Constants::COMMAND_SELL; # 食料輸出
#$HcomMoney      = Hako::Constants::COMMAND_MONEY; # 資金援助
#$HcomFood       = Hako::Constants::COMMAND_FOOD; # 食料援助
#$HcomPropaganda = Hako::Constants::COMMAND_PROPAGANDA; # 誘致活動
#$HcomGiveup     = Hako::Constants::COMMAND_GIVE_UP; # 島の放棄

# 自動入力系
#$HcomAutoPrepare  = Hako::Constants::COMMAND_AUTO_PREPARE; # フル整地
#$HcomAutoPrepare2 = Hako::Constants::COMMAND_AUTO_PREPARE2; # フル地ならし
#$HcomAutoDelete   = Hako::Constants::COMMAND_AUTO_DELETE; # 全コマンド消去

# 順番
#@HcomList =
    #($HcomPrepare, $HcomSell, $HcomPrepare2, $HcomReclaim, $HcomDestroy,
     #$HcomSellTree, $HcomPlant, $HcomFarm, $HcomFactory, $HcomMountain,
     #$HcomBase, $HcomDbase, $HcomSbase, $HcomMonument, $HcomHaribote,
     #$HcomMissileNM, $HcomMissilePP,
     #$HcomMissileST, $HcomMissileLD, $HcomSendMonster, $HcomDoNothing,
     #$HcomMoney, $HcomFood, $HcomPropaganda, $HcomGiveup,
     #$HcomAutoPrepare, $HcomAutoPrepare2, $HcomAutoDelete);

# 計画の名前と値段
#$HcomName[$HcomPrepare]      = Hako::Constants::COMMAND_NAME_PREPARE;
#$HcomCost[$HcomPrepare]      = Hako::Constants::COMMAND_COST_PREPARE;
#$HcomName[$HcomPrepare2]     = Hako::Constants::COMMAND_NAME_PREPARE2;
#$HcomCost[$HcomPrepare2]     = Hako::Constants::COMMAND_COST_PREPARE2;
#$HcomName[$HcomReclaim]      = Hako::Constants::COMMAND_NAME_RECLAIM;
#$HcomCost[$HcomReclaim]      = Hako::Constants::COMMAND_COST_RECLAIM;
#$HcomName[$HcomDestroy]      = Hako::Constants::COMMAND_NAME_DESTROY;
#$HcomCost[$HcomDestroy]      = Hako::Constants::COMMAND_COST_DESTROY;
#$HcomName[$HcomSellTree]     = Hako::Constants::COMMAND_NAME_SELL_TREE;
#$HcomCost[$HcomSellTree]     = Hako::Constants::COMMAND_COST_SELL_TREE;
#$HcomName[$HcomPlant]        = Hako::Constants::COMMAND_NAME_PLANT;
#$HcomCost[$HcomPlant]        = Hako::Constants::COMMAND_COST_PLANT;
#$HcomName[$HcomFarm]         = Hako::Constants::COMMAND_NAME_FARM;
#$HcomCost[$HcomFarm]         = Hako::Constants::COMMAND_COST_FARM;
#$HcomName[$HcomFactory]      = Hako::Constants::COMMAND_NAME_FACTORY;
#$HcomCost[$HcomFactory]      = Hako::Constants::COMMAND_COST_FACTORY;
#$HcomName[$HcomMountain]     = Hako::Constants::COMMAND_NAME_MOUNTAIN;
#$HcomCost[$HcomMountain]     = Hako::Constants::COMMAND_COST_MOUNTAIN;
#$HcomName[$HcomBase]         = Hako::Constants::COMMAND_NAME_BASE;
#$HcomCost[$HcomBase]         = Hako::Constants::COMMAND_COST_BASE;
#$HcomName[$HcomDbase]        = Hako::Constants::COMMAND_NAME_DEFENCE_BASE;
#$HcomCost[$HcomDbase]        = Hako::Constants::COMMAND_COST_DEFENCE_BASE;
#$HcomName[$HcomSbase]        = Hako::Constants::COMMAND_NAME_SEA_BASE;
#$HcomCost[$HcomSbase]        = Hako::Constants::COMMAND_COST_SEA_BASE;
#$HcomName[$HcomMonument]     = Hako::Constants::COMMAND_NAME_MONUMENT;
#$HcomCost[$HcomMonument]     = Hako::Constants::COMMAND_COST_MONUMENT;
#$HcomName[$HcomHaribote]     = Hako::Constants::COMMAND_NAME_HARIBOTE;
#$HcomCost[$HcomHaribote]     = Hako::Constants::COMMAND_COST_HARIBOTE;
#$HcomName[$HcomMissileNM]    = Hako::Constants::COMMAND_NAME_MISSILE_NM;
#$HcomCost[$HcomMissileNM]    = Hako::Constants::COMMAND_COST_MISSILE_NM;
#$HcomName[$HcomMissilePP]    = Hako::Constants::COMMAND_NAME_MISSILE_PP;
#$HcomCost[$HcomMissilePP]    = Hako::Constants::COMMAND_COST_MISSILE_PP;
#$HcomName[$HcomMissileST]    = Hako::Constants::COMMAND_NAME_MISSILE_ST;
#$HcomCost[$HcomMissileST]    = Hako::Constants::COMMAND_COST_MISSILE_ST;
#$HcomName[$HcomMissileLD]    = Hako::Constants::COMMAND_NAME_MISSILE_LD;
#$HcomCost[$HcomMissileLD]    = Hako::Constants::COMMAND_COST_MISSILE_LD;
#$HcomName[$HcomSendMonster]  = Hako::Constants::COMMAND_NAME_SEND_MONSTER;
#$HcomCost[$HcomSendMonster]  = Hako::Constants::COMMAND_COST_SEND_MONSTER;
#$HcomName[$HcomDoNothing]    = Hako::Constants::COMMAND_NAME_DO_NOTHING;
#$HcomCost[$HcomDoNothing]    = Hako::Constants::COMMAND_COST_DO_NOTHING;
#$HcomName[$HcomSell]         = Hako::Constants::COMMAND_NAME_SELL;
#$HcomCost[$HcomSell]         = Hako::Constants::COMMAND_COST_SELL;
#$HcomName[$HcomMoney]        = Hako::Constants::COMMAND_NAME_MONEY;
#$HcomCost[$HcomMoney]        = Hako::Constants::COMMAND_COST_MONEY;
#$HcomName[$HcomFood]         = Hako::Constants::COMMAND_NAME_FOOD;
#$HcomCost[$HcomFood]         = Hako::Constants::COMMAND_COST_FOOD;
#$HcomName[$HcomPropaganda]   = Hako::Constants::COMMAND_NAME_PROPAGANDA;
#$HcomCost[$HcomPropaganda]   = Hako::Constants::COMMAND_COST_PROPAGANDA;
#$HcomName[$HcomGiveup]       = Hako::Constants::COMMAND_NAME_GIVE_UP;
#$HcomCost[$HcomGiveup]       = Hako::Constants::COMMAND_COST_GIVE_UP;
#$HcomName[$HcomAutoPrepare]  = Hako::Constants::COMMAND_NAME_AUTO_PREPARE;
#$HcomCost[$HcomAutoPrepare]  = Hako::Constants::COMMAND_COST_AUTO_PREPARE;
#$HcomName[$HcomAutoPrepare2] = Hako::Constants::COMMAND_NAME_AUTO_PREPARE2;
#$HcomCost[$HcomAutoPrepare2] = Hako::Constants::COMMAND_COST_AUTO_PREPARE2;
#$HcomName[$HcomAutoDelete]   = Hako::Constants::COMMAND_NAME_AUTO_DELETE;
#$HcomCost[$HcomAutoDelete]   = Hako::Constants::COMMAND_COST_AUTO_DELETE;

#----------------------------------------------------------------------
# 変数
#----------------------------------------------------------------------

# COOKIE
#my($defaultID);       # 島の名前
#my($defaultTarget);   # ターゲットの名前


# 島の座標数
#$HpointNumber = Hako::Config::ISLAND_SIZE * Hako::Config::ISLAND_SIZE;

#----------------------------------------------------------------------
# メイン
#----------------------------------------------------------------------

# 「戻る」リンク
#$HtempBack = "<A HREF=\"@{[Hako::Config::THIS_FILE]}\">@{[Hako::Config::TAG_BIG_]}トップへ戻る@{[Hako::Config::_TAG_BIG]}</A>";

1;
