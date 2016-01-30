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
# Ȣ����� ver2.30
# �ᥤ�󥹥���ץ�(ver1.02)
# ���Ѿ�������ˡ���ϡ�hako-readme.txt�ե�����򻲾�
#
# Ȣ�����Υڡ���: http://www.bekkoame.ne.jp/~tokuoka/hakoniwa.html
#----------------------------------------------------------------------


#----------------------------------------------------------------------
# �Ƽ�������
# (����ʹߤ���ʬ�γ������ͤ�Ŭ�ڤ��ͤ��ѹ����Ƥ�������)
#----------------------------------------------------------------------

# ���Υե�������֤��ǥ��쥯�ȥ�
# my($baseDir) = 'http://�����С�/�ǥ��쥯�ȥ�';
#
# ��)
# http://cgi2.bekkoame.ne.jp/cgi-bin/user/u5534/hakoniwa/hako-main.cgi
# �Ȥ����֤���硢
# my($baseDir) = 'http://cgi2.bekkoame.ne.jp/cgi-bin/user/u5534/hakoniwa';
# �Ȥ��롣�Ǹ�˥���å���(/)���դ��ʤ���

my($baseDir) = Hako::Config::BASE_DIR;

# �����ե�������֤��ǥ��쥯�ȥ�
# my($imageDir) = 'http://�����С�/�ǥ��쥯�ȥ�';
my($imageDir) = Hako::Config::IMAGE_DIR;

# �ޥ������ѥ����
# ���Υѥ���ɤϡ����٤Ƥ���Υѥ���ɤ����ѤǤ��ޤ���
# �㤨�С���¾����Υѥ�����ѹ�������Ǥ��ޤ���
my($masterPassword) = Hako::Config::MASTER_PASSWORD;

# �ü�ѥ����
# ���Υѥ���ɤǡ�̾���ѹ��פ�Ԥ��ȡ�������λ�⡢�����������ͤˤʤ�ޤ���
# (�ºݤ�̾�����Ѥ���ɬ�פϤ���ޤ���)
$HspecialPassword = Hako::Config::SPECIAL_PASSWORD;

# ������̾
my($adminName) = Encode::encode("EUC-JP", Hako::Config::ADMIN_NAME);

# �����ԤΥ᡼�륢�ɥ쥹
my($email) = Hako::Config::ADMIN_EMAIL;

# �Ǽ��ĥ��ɥ쥹
my($bbs) = Hako::Config::BBS_URL();

# �ۡ���ڡ����Υ��ɥ쥹
my($toppage) = Hako::Config::TOPPAGE_URL;

# �ǥ��쥯�ȥ�Υѡ��ߥå����
# �̾��0755�Ǥ褤����0777��0705��0704���Ǥʤ��ȤǤ��ʤ������С��⤢��餷��
$HdirMode = 0755;

# �ǡ����ǥ��쥯�ȥ��̾��
# ���������ꤷ��̾���Υǥ��쥯�ȥ�ʲ��˥ǡ�������Ǽ����ޤ���
# �ǥե���ȤǤ�'data'�ȤʤäƤ��ޤ������������ƥ��Τ���
# �ʤ�٤��㤦̾�����ѹ����Ƥ���������
$HdirName = Hako::Config::DATA_DIR;

# �ǡ����ν񤭹�����

# ��å�������
# 1 �ǥ��쥯�ȥ�
# 2 �����ƥॳ����(��ǽ�ʤ�кǤ�˾�ޤ���)
# 3 ����ܥ�å����
# 4 �̾�ե�����(���ޤꤪ����Ǥʤ�)
my($lockMode) = Hako::Config::LOCK_MODE;

# (��)
# 4�����򤹤���ˤϡ�'key-free'�Ȥ������ѡ��ߥ����666�ζ��Υե������
# ���Υե������Ʊ���֤��֤��Ʋ�������

#----------------------------------------------------------------------
# ɬ�����ꤹ����ʬ�ϰʾ�
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# �ʲ������ߤˤ�ä����ꤹ����ʬ
#----------------------------------------------------------------------
#----------------------------------------
# ������οʹԤ�ե�����ʤ�
#----------------------------------------
# 1�����󤬲��ä�
$HunitTime = Hako::Config::UNIT_TIME; # 6����

# �۾ｪλ������
# (��å��岿�äǡ�����������뤫)
my($unlockTime) = Hako::Config::UNLOCK_TIME;

# ��κ����
$HmaxIsland = Hako::Config::MAX_ISLAND;

# �ȥåץڡ�����ɽ��������Υ������
$HtopLogTurn = Hako::Config::TOP_LOG_TURN;

# ���ե������ݻ��������
$HlogMax = Hako::Config::LOG_MAX;

# �Хå����åפ򲿥����󤪤��˼�뤫
$HbackupTurn = Hako::Config::BACKUP_TURN;

# �Хå����åפ򲿲�ʬ�Ĥ���
$HbackupTimes = Hako::Config::BACKUP_TIMES;

# ȯ�����ݻ��Կ�
$HhistoryMax = Hako::Config::HISTORY_MAX;

# �������ޥ�ɼ�ư���ϥ������
$HgiveupTurn = Hako::Config::GIVEUP_TURN;

# ���ޥ�����ϸ³���
# (�����ब�ϤޤäƤ����ѹ�����ȡ��ǡ����ե�����θߴ�����̵���ʤ�ޤ���)
$HcommandMax = Hako::Config::COMMAND_MAX;

# ������Ǽ��ĹԿ�����Ѥ��뤫�ɤ���(0:���Ѥ��ʤ���1:���Ѥ���)
$HuseLbbs = Hako::Config::USE_LOCAL_BBS;

# ������Ǽ��ĹԿ�
$HlbbsMax = Hako::Config::LOCAL_BBS_MAX;

# ����礭��
# (�ѹ��Ǥ��ʤ�����)
$HislandSize = Hako::Config::ISLAND_SIZE;

# ¾�ͤ�����򸫤��ʤ����뤫
# 0 �����ʤ�
# 1 ������
# 2 100�ΰ̤ǻͼθ���
$HhideMoneyMode = Hako::Config::HIDE_MONEY_MODE;

# �ѥ���ɤΰŹ沽(0���ȰŹ沽���ʤ���1���ȰŹ沽����)
my($cryptOn) = Hako::Config::CRYPT;

# �ǥХå��⡼��(1���ȡ��֥������ʤ��ץܥ��󤬻��ѤǤ���)
$Hdebug = Hako::Config::DEBUG;

#----------------------------------------
# ��⡢�����ʤɤ������ͤ�ñ��
#----------------------------------------
# ������
$HinitialMoney = Hako::Config::INITIAL_MONEY;

# �������
$HinitialFood = Hako::Config::INITIAL_FOOD;

# �����ñ��
$HunitMoney = Encode::encode("EUC-JP", Hako::Config::UNIT_MONEY);

# ������ñ��
$HunitFood = Encode::encode("EUC-JP", Hako::Config::UNIT_FOOD);

# �͸���ñ��
$HunitPop = Encode::encode("EUC-JP", Hako::Config::UNIT_POPULATION);

# ������ñ��
$HunitArea = Encode::encode("EUC-JP", Hako::Config::UNIT_AREA);

# �ڤο���ñ��
$HunitTree = Encode::encode("EUC-JP", Hako::Config::UNIT_TREE);

# �ڤ�ñ�������������
$HtreeValue = Hako::Config::TREE_VALUE;

# ̾���ѹ��Υ�����
$HcostChangeName = Hako::Config::CHANGE_NAME_COST;

# �͸�1ñ�̤�����ο���������
$HeatenFood = Hako::Config::EATEN_FOOD;

#----------------------------------------
# ���Ϥηи���
#----------------------------------------
# �и��ͤκ�����
$HmaxExpPoint = Hako::Config::MAX_EXP_POINT; # ������������Ǥ�255�ޤ�

# ��٥�κ�����
my($maxBaseLevel) = Hako::Config::MAX_BASE_LEVEL;  # �ߥ��������
my($maxSBaseLevel) = Hako::Config::MAX_SEA_BASE_LEVEL; # �������

# �и��ͤ������Ĥǥ�٥륢�åפ�
my(@baseLevelUp, @sBaseLevelUp);
@baseLevelUp = @{Hako::Config::BASE_LEVEL_UP()}; # �ߥ��������
@sBaseLevelUp = @{Hako::Config::SEA_BASE_LEVEL_UP()};         # �������

#----------------------------------------
# �ɱһ��ߤμ���
#----------------------------------------
# ���ä�Ƨ�ޤ줿����������ʤ�1�����ʤ��ʤ�0
$HdBaseAuto = Hako::Config::DEFENCE_BASE_AUTO;

#----------------------------------------
# �ҳ�
#----------------------------------------
# �̾�ҳ�ȯ��Ψ(��Ψ��0.1%ñ��)
$HdisEarthquake = Hako::Config::DISASTER_EARTHQUAKE;  # �Ͽ�
$HdisTsunami    = Hako::Config::DISASTER_TSUNAMI; # ����
$HdisTyphoon    = Hako::Config::DISASTER_TYPHOON; # ����
$HdisMeteo      = Hako::Config::DISASTER_METEO; # ���
$HdisHugeMeteo  = Hako::Config::DISASTER_HUGE_METEO;  # �������
$HdisEruption   = Hako::Config::DISASTER_ERUPTION; # ʮ��
$HdisFire       = Hako::Config::DISASTER_FIRE; # �к�
$HdisMaizo      = Hako::Config::DISASTER_MAIZO; # ��¢��

# ��������
$HdisFallBorder = Hako::Config::DISASTER_FALL_BORDER; # �����³��ι���(Hex��)
$HdisFalldown   = Hako::Config::DISASTER_FALL_DOWN; # ���ι�����Ķ�������γ�Ψ

# ����
$HdisMonsBorder1 = Hako::Config::DISASTER_MONSTER_BORDER1; # �͸����1(���å�٥�1)
$HdisMonsBorder2 = Hako::Config::DISASTER_MONSTER_BORDER2; # �͸����2(���å�٥�2)
$HdisMonsBorder3 = Hako::Config::DISASTER_MONSTER_BORDER3; # �͸����3(���å�٥�3)
$HdisMonster     = Hako::Config::DISASTER_MONSTER;    # ñ�����Ѥ�����νи�Ψ(0.01%ñ��)

# ����
$HmonsterNumber  = Hako::Config::MONSTER_NUMBER;

# �ƴ��ˤ����ƽФƤ�����ä��ֹ�κ�����
$HmonsterLevel1  = Hako::Config::MONSTER_LEVEL1; # ���󥸥�ޤ�
$HmonsterLevel2  = Hako::Config::MONSTER_LEVEL2; # ���Τ饴�����Ȥޤ�
$HmonsterLevel3  = Hako::Config::MONSTER_LEVEL3; # ���󥰤��Τ�ޤ�(����)

# ̾��
@HmonsterName = map { Encode::encode("EUC-JP", $_) } @{Hako::Config::MONSTER_NAME()};

# �������ϡ����Ϥ������ü�ǽ�ϡ��и��͡����Τ�����
@HmonsterBHP     = @{Hako::Config::MONSTER_BOTTOM_HP};
@HmonsterDHP     = @{Hako::Config::MONSTER_DHP};
@HmonsterSpecial = @{Hako::Config::MONSTER_SPECIAL};
@HmonsterExp     = @{Hako::Config::MONSTER_EXP};
@HmonsterValue   = @{Hako::Config::MONSTER_VALUE};

# �ü�ǽ�Ϥ����Ƥϡ�
# 0 �äˤʤ�
# 1 ­��®��(����2�⤢�뤯)
# 2 ­���ȤƤ�®��(���粿�⤢�뤯������)
# 3 ���������ϹŲ�
# 4 ����������ϹŲ�

# �����ե�����
@HmonsterImage = @{Hako::Config::MONSTER_IMAGE};

# �����ե����뤽��2(�Ų���)
@HmonsterImage2 = @{Hako::Config::MONSTER_IMAGE2};


#----------------------------------------
# ����
#----------------------------------------
# ���Ĥμ���
$HoilMoney = Hako::Config::OIL_MONEY;

# ���Ĥθϳ��Ψ
$HoilRatio = Hako::Config::OIL_RAITO;

#----------------------------------------
# ��ǰ��
#----------------------------------------
# �����ढ�뤫
$HmonumentNumber = Hako::Config::MONUMENT_NUMBER;

# ̾��
@HmonumentName = map { Encode::encode("EUC-JP", $_) } @{Hako::Config::MONUMEBT_NAME};

# �����ե�����
@HmonumentImage = @{Hako::Config::MONUMENT_IMAGE};

#----------------------------------------
# �޴ط�
#----------------------------------------
# �������դ򲿥�������˽Ф���
$HturnPrizeUnit = Hako::Config::TURN_PRIZE_UNIT;

# �ޤ�̾��
@Hprize = map { Encode::encode("EUC-JP", $_ ) } @{Hako::Config::PRIZE};

#----------------------------------------
# �����ط�
#----------------------------------------
# <BODY>�����Υ��ץ����
my($htmlBody) = Hako::Config::HTML_BODY;

# ������Υ����ȥ�ʸ��
$Htitle = Encode::encode("EUC-JP", Hako::Config::TITLE);

# ����
# �����ȥ�ʸ��
$HtagTitle_ = Hako::Config::TAG_TITLE_;
$H_tagTitle = Hako::Config::_TAG_TITLE;

# H1������
$HtagHeader_ = Hako::Config::TAG_HEADER_;
$H_tagHeader = Hako::Config::_TAG_HEADER;

# �礭��ʸ��
$HtagBig_ = Hako::Config::TAG_BIG_;
$H_tagBig = Hako::Config::_TAG_BIG;

# ���̾���ʤ�
$HtagName_ = Hako::Config::TAG_NAME_;
$H_tagName = Hako::Config::_TAG_NAME;

# �����ʤä����̾��
$HtagName2_ = Hako::Config::TAG_NAME2_;
$H_tagName2 = Hako::Config::_TAG_NAME2;

# ��̤��ֹ�ʤ�
$HtagNumber_ = Hako::Config::TAG_NUMBER_;
$H_tagNumber = Hako::Config::_TAG_NUMBER;

# ���ɽ�ˤ����븫����
$HtagTH_ = Hako::Config::TAG_TH_;
$H_tagTH = Hako::Config::_TAG_TH;

# ��ȯ�ײ��̾��
$HtagComName_ = Hako::Config::TAG_COM_NAME_;
$H_tagComName = Hako::Config::_TAG_COM_NAME;

# �ҳ�
$HtagDisaster_ = Hako::Config::TAG_DISASTER_;
$H_tagDisaster = Hako::Config::_TAG_DISASTER;

# ������Ǽ��ġ��Ѹ��Ԥν񤤤�ʸ��
$HtagLbbsSS_ = Hako::Config::TAG_LOCAL_BBS_SS_;
$H_tagLbbsSS = Hako::Config::_TAG_LOCAL_BBS_SS;

# ������Ǽ��ġ����ν񤤤�ʸ��
$HtagLbbsOW_ = Hako::Config::TAG_LOCAL_BBS_OW_;
$H_tagLbbsOW = Hako::Config::_TAG_LOCAL_BBS_OW;

# �̾��ʸ����(��������Ǥʤ���BODY�����Υ��ץ�����������ѹ����٤�
$HnormalColor = Hako::Config::NORMAL_COLOR;

# ���ɽ�������°��
$HbgTitleCell   = Hako::Config::BG_TITLE_CELL; # ���ɽ���Ф�
$HbgNumberCell  = Hako::Config::BG_NUMBER_CELL; # ���ɽ���
$HbgNameCell    = Hako::Config::BG_NAME_CELL; # ���ɽ���̾��
$HbgInfoCell    = Hako::Config::BG_INFO_CELL; # ���ɽ��ξ���
$HbgCommentCell = Hako::Config::BG_COMMENT_CELL; # ���ɽ��������
$HbgInputCell   = Hako::Config::BG_INPUT_CELL; # ��ȯ�ײ�ե�����
$HbgMapCell     = Hako::Config::BG_MAP_CELL; # ��ȯ�ײ��Ͽ�
$HbgCommandCell = Hako::Config::BG_COMMAND_CELL; # ��ȯ�ײ����ϺѤ߷ײ�

#----------------------------------------------------------------------
# ���ߤˤ�ä����ꤹ����ʬ�ϰʾ�
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# ����ʹߤΥ�����ץȤϡ��ѹ�����뤳�Ȥ����ꤷ�Ƥ��ޤ��󤬡�
# �����äƤ⤫�ޤ��ޤ���
# ���ޥ�ɤ�̾�������ʤʤɤϲ��䤹���Ȼפ��ޤ���
#----------------------------------------------------------------------

#----------------------------------------------------------------------
# �Ƽ����
#----------------------------------------------------------------------
# ���Υե�����
$HthisFile = "$baseDir/hako-main.cgi";

# �Ϸ��ֹ�
$HlandSea      = 0;  # ��
$HlandWaste    = 1;  # ����
$HlandPlains   = 2;  # ʿ��
$HlandTown     = 3;  # Į��
$HlandForest   = 4;  # ��
$HlandFarm     = 5;  # ����
$HlandFactory  = 6;  # ����
$HlandBase     = 7;  # �ߥ��������
$HlandDefence  = 8;  # �ɱһ���
$HlandMountain = 9;  # ��
$HlandMonster  = 10; # ����
$HlandSbase    = 11; # �������
$HlandOil      = 12; # ��������
$HlandMonument = 13; # ��ǰ��
$HlandHaribote = 14; # �ϥ�ܥ�

# ���ޥ��
$HcommandTotal = 28; # ���ޥ�ɤμ���

# �ײ��ֹ������
# ���Ϸ�
$HcomPrepare  = 01; # ����
$HcomPrepare2 = 02; # �Ϥʤ餷
$HcomReclaim  = 03; # ���Ω��
$HcomDestroy  = 04; # ����
$HcomSellTree = 05; # Ȳ��

# ����
$HcomPlant    = 11; # ����
$HcomFarm     = 12; # ��������
$HcomFactory  = 13; # �������
$HcomMountain = 14; # �η�������
$HcomBase     = 15; # �ߥ�������Ϸ���
$HcomDbase    = 16; # �ɱһ��߷���
$HcomSbase    = 17; # ������Ϸ���
$HcomMonument = 18; # ��ǰ���¤
$HcomHaribote = 19; # �ϥ�ܥ�����

# ȯ�ͷ�
$HcomMissileNM   = 31; # �ߥ�����ȯ��
$HcomMissilePP   = 32; # PP�ߥ�����ȯ��
$HcomMissileST   = 33; # ST�ߥ�����ȯ��
$HcomMissileLD   = 34; # Φ���˲���ȯ��
$HcomSendMonster = 35; # �����ɸ�

# ���ķ�
$HcomDoNothing  = 41; # ��ⷫ��
$HcomSell       = 42; # ����͢��
$HcomMoney      = 43; # �����
$HcomFood       = 44; # �������
$HcomPropaganda = 45; # Ͷ�׳�ư
$HcomGiveup     = 46; # �������

# ��ư���Ϸ�
$HcomAutoPrepare  = 61; # �ե�����
$HcomAutoPrepare2 = 62; # �ե��Ϥʤ餷
$HcomAutoDelete   = 63; # �����ޥ�ɾõ�

# ����
@HcomList =
    ($HcomPrepare, $HcomSell, $HcomPrepare2, $HcomReclaim, $HcomDestroy,
     $HcomSellTree, $HcomPlant, $HcomFarm, $HcomFactory, $HcomMountain,
     $HcomBase, $HcomDbase, $HcomSbase, $HcomMonument, $HcomHaribote,
     $HcomMissileNM, $HcomMissilePP,
     $HcomMissileST, $HcomMissileLD, $HcomSendMonster, $HcomDoNothing,
     $HcomMoney, $HcomFood, $HcomPropaganda, $HcomGiveup,
     $HcomAutoPrepare, $HcomAutoPrepare2, $HcomAutoDelete);

# �ײ��̾��������
$HcomName[$HcomPrepare]      = '����';
$HcomCost[$HcomPrepare]      = 5;
$HcomName[$HcomPrepare2]     = '�Ϥʤ餷';
$HcomCost[$HcomPrepare2]     = 100;
$HcomName[$HcomReclaim]      = '���Ω��';
$HcomCost[$HcomReclaim]      = 150;
$HcomName[$HcomDestroy]      = '����';
$HcomCost[$HcomDestroy]      = 200;
$HcomName[$HcomSellTree]     = 'Ȳ��';
$HcomCost[$HcomSellTree]     = 0;
$HcomName[$HcomPlant]        = '����';
$HcomCost[$HcomPlant]        = 50;
$HcomName[$HcomFarm]         = '��������';
$HcomCost[$HcomFarm]         = 20;
$HcomName[$HcomFactory]      = '�������';
$HcomCost[$HcomFactory]      = 100;
$HcomName[$HcomMountain]     = '�η�������';
$HcomCost[$HcomMountain]     = 300;
$HcomName[$HcomBase]         = '�ߥ�������Ϸ���';
$HcomCost[$HcomBase]         = 300;
$HcomName[$HcomDbase]        = '�ɱһ��߷���';
$HcomCost[$HcomDbase]        = 800;
$HcomName[$HcomSbase]        = '������Ϸ���';
$HcomCost[$HcomSbase]        = 8000;
$HcomName[$HcomMonument]     = '��ǰ���¤';
$HcomCost[$HcomMonument]     = 9999;
$HcomName[$HcomHaribote]     = '�ϥ�ܥ�����';
$HcomCost[$HcomHaribote]     = 1;
$HcomName[$HcomMissileNM]    = '�ߥ�����ȯ��';
$HcomCost[$HcomMissileNM]    = 20;
$HcomName[$HcomMissilePP]    = 'PP�ߥ�����ȯ��';
$HcomCost[$HcomMissilePP]    = 50;
$HcomName[$HcomMissileST]    = 'ST�ߥ�����ȯ��';
$HcomCost[$HcomMissileST]    = 50;
$HcomName[$HcomMissileLD]    = 'Φ���˲���ȯ��';
$HcomCost[$HcomMissileLD]    = 100;
$HcomName[$HcomSendMonster]  = '�����ɸ�';
$HcomCost[$HcomSendMonster]  = 3000;
$HcomName[$HcomDoNothing]    = '��ⷫ��';
$HcomCost[$HcomDoNothing]    = 0;
$HcomName[$HcomSell]         = '����͢��';
$HcomCost[$HcomSell]         = -100;
$HcomName[$HcomMoney]        = '�����';
$HcomCost[$HcomMoney]        = 100;
$HcomName[$HcomFood]         = '�������';
$HcomCost[$HcomFood]         = -100;
$HcomName[$HcomPropaganda]   = 'Ͷ�׳�ư';
$HcomCost[$HcomPropaganda]   = 1000;
$HcomName[$HcomGiveup]       = '�������';
$HcomCost[$HcomGiveup]       = 0;
$HcomName[$HcomAutoPrepare]  = '���ϼ�ư����';
$HcomCost[$HcomAutoPrepare]  = 0;
$HcomName[$HcomAutoPrepare2] = '�Ϥʤ餷��ư����';
$HcomCost[$HcomAutoPrepare2] = 0;
$HcomName[$HcomAutoDelete]   = '���ײ�����ű��';
$HcomCost[$HcomAutoDelete]   = 0;

#----------------------------------------------------------------------
# �ѿ�
#----------------------------------------------------------------------

# COOKIE
my($defaultID);       # ���̾��
my($defaultTarget);   # �������åȤ�̾��


# ��κ�ɸ��
$HpointNumber = $HislandSize * $HislandSize;

#----------------------------------------------------------------------
# �ᥤ��
#----------------------------------------------------------------------

# �����ץ��
$HtempBack = "<A HREF=\"$HthisFile\">${HtagBig_}�ȥåפ����${H_tagBig}</A>";

sub to_app {
    my $out_buffer = "";
    my $cookie_buffer = "";
    my $response;
    my $request;

    # ���ޥ�ɤ����ˤ��餹
    sub slideFront {
        my($command, $number) = @_;
        my($i);

        # ���줾�줺�餹
        splice(@$command, $number, 1);

        # �Ǹ�˻�ⷫ��
        $command->[$HcommandMax - 1] = {
        'kind' => $HcomDoNothing,
        'target' => 0,
        'x' => 0,
        'y' => 0,
        'arg' => 0
        };
    }

# ���ޥ�ɤ��ˤ��餹
    sub slideBack {
        my($command, $number) = @_;
        my($i);

        # ���줾�줺�餹
        return if $number == $#$command;
        pop(@$command);
        splice(@$command, $number, 0, $command->[$number]);
    }

#----------------------------------------------------------------------
# ��ǡ���������
#----------------------------------------------------------------------

# ����ǡ����ɤߤ���
    sub readIslandsFile {
        my($num) = @_; # 0�����Ϸ��ɤߤ��ޤ�
                       # -1�������Ϸ����ɤ�
                       # �ֹ���Ȥ�������Ϸ��������ɤߤ���

        # �ǡ����ե�����򳫤�
        if(!open(IN, "${HdirName}/hakojima.dat")) {
        rename("${HdirName}/hakojima.tmp", "${HdirName}/hakojima.dat");
        if(!open(IN, "${HdirName}/hakojima.dat")) {
            return 0;
        }
        }

        my $tmp = <IN>;
        $HislandTurn = Hako::DB->get_global_value("turn"); # �������
        if ($HislandTurn == 0) {
            return 0;
        }
        my $tmp = <IN>;
        $HislandLastTime = Hako::DB->get_global_value("last_time"); # �ǽ���������
        if ($HislandLastTime == 0) {
            return 0;
        }
        my $tmp = <IN>;
        my $tmp = <IN>;
        $HislandNumber = Hako::DB->get_global_value("number"); # ������
        $HislandNextID = Hako::DB->get_global_value("next_id"); # ���˳�����Ƥ�ID

        # ���������Ƚ��
        my($now) = time;
        if ((($Hdebug == 1) && ($HmainMode eq 'Hdebugturn')) || (($now - $HislandLastTime) >= $HunitTime)) {
            $HmainMode = 'turn';
            $num = -1; # �����ɤߤ���
        }

        # ����ɤߤ���
        my $islands_from_db = Hako::DB->get_islands;
        for (my $i = 0; $i < $HislandNumber; $i++) {
            $Hislands[$i] = readIsland($num, $islands_from_db);
            $HidToNumber{$Hislands[$i]->{'id'}} = $i;
        }

        # �ե�������Ĥ���
        close(IN);

        return 1;
    }

    # ��ҤȤ��ɤߤ���
    sub readIsland {
        my ($num, $islands_from_db) = @_;
        my $island_from_db = Hako::Model::Island->inflate(shift @$islands_from_db);

        my ($name, $id, $prize, $absent, $comment, $password, $money, $food, $pop, $area, $farm, $factory, $mountain, $score);
        my $tmp = <IN>;
        $name = $island_from_db->{name};
        $score = $island_from_db->{score};
        #$name = <IN>; # ���̾��
        #chomp($name);
        #if($name =~ s/,(.*)$//g) {
            #$score = int($1);
        #} else {
            #$score = 0;
        #}
        $id = int(<IN>); # ID�ֹ�
        unless (int($island_from_db->{id}) == $id) {
            warn "wrong id: @{[$island_from_db->{id}]}(db) $id(dat)";
        }
        $prize = $island_from_db->{prize}; # ����
        $absent = $island_from_db->{absent}; # Ϣ³��ⷫ���
        $comment = $island_from_db->{comment};
        $password = $island_from_db->{password};
        $money = $island_from_db->{money};  # ���
        $food = $island_from_db->{food};  # ����
        $pop = $island_from_db->{pop};  # �͸�
        $area = $island_from_db->{area};  # ����
        $farm = $island_from_db->{farm};  # ����
        $factory = $island_from_db->{factory};  # ����
        $mountain = $island_from_db->{mountain}; # �η���
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
        #$comment = <IN>; # ������
        #chomp($comment);
        #$password = <IN>; # �Ź沽�ѥ����
        #chomp($password);
        #$money = int(<IN>);  
        #$food = int(<IN>);   
        #$pop = int(<IN>);    
        #$area = int(<IN>);   
        #$farm = int(<IN>);   
        #$factory = int(<IN>);
        #$mountain = int(<IN>);

        # HidToName�ơ��֥����¸
        $HidToName{$id} = $name;

        # �Ϸ�
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

            # ���ޥ��
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

            # ������Ǽ���
            for($i = 0; $i < $HlbbsMax; $i++) {
                $line = <IIN>;
                chomp($line);
                $lbbs[$i] = $line;
            }

            close(IIN);
        }

        # �緿�ˤ����֤�
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

    # ����ǡ����񤭹���
    sub writeIslandsFile {
        my($num) = @_;

        # �ե�����򳫤�
        open(OUT, ">${HdirName}/hakojima.tmp");

        # �ƥѥ�᡼���񤭹���
        print OUT "$HislandTurn\n";
        print OUT "$HislandLastTime\n";
        print OUT "$HislandNumber\n";
        print OUT "$HislandNextID\n";

        Hako::DB->set_global_value("turn", $HislandTurn);
        Hako::DB->set_global_value("last_time", $HislandLastTime);
        Hako::DB->set_global_value("number", $HislandNumber);
        Hako::DB->set_global_value("next_id", $HislandNextID);

        # ��ν񤭤���
        for (my $i = 0; $i < $HislandNumber; $i++) {
            writeIsland($Hislands[$i], $num, $i);
        }

        # DB�Ѥ��������줿���ä�
        my @dead_islands = grep {$_->{dead} == 1} @Hislands;
        for my $dead_island (@dead_islands) {
            Hako::DB->delete_island($dead_island->{id});
        }

        # �ե�������Ĥ���
        close(OUT);

        # �����̾���ˤ���
        unlink("${HdirName}/hakojima.dat");
        rename("${HdirName}/hakojima.tmp", "${HdirName}/hakojima.dat");
    }

    # ��ҤȤĽ񤭹���
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

        # �Ϸ�
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

            # ���ޥ��
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

            # ������Ǽ���
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
# ������
#----------------------------------------------------------------------

    # ɸ����Ϥؤν���
    sub out {
        $out_buffer .= sprintf("%s", Encode::encode("Shift_JIS", Encode::decode("EUC-JP", $_[0])));
    }

    # �ǥХå���
    sub HdebugOut {
       open(DOUT, ">>debug.log");
       print DOUT ($_[0]);
       close(DOUT);
    }

    # CGI���ɤߤ���
    sub cgiInput {
        my $params = $request->parameters;
        use Data::Dumper;warn Data::Dumper::Dumper($params);
        # �оݤ���
        if (List::MoreUtils::any {$_ =~ /CommandButton([0-9]+)/} $params->keys) {
            my @tmp = grep {$_ =~ /^CommandButton/} $params->keys;
            $tmp[0] =~ /CommandButton([0-9]+)/;
            # ���ޥ�������ܥ���ξ��
            $HcurrentID = $1;
            $defaultID = $1;
        }

        if (List::MoreUtils::any {$_ eq "ISLANDNAME"} $params->keys) {
            # ̾������ξ��
            $HcurrentName = cutColumn($params->get("ISLANDNAME"), 32);
        }

        if (List::MoreUtils::any { $_ eq "ISLANDID" } $params->keys) {
            # ����¾�ξ��
            $HcurrentID = $params->get("ISLANDID");
            $defaultID = $params->get("ISLANDID");
        }

        # �ѥ����
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

        # ��å�����
        if (List::MoreUtils::any {$_ eq "MESSAGE"} $params->keys) {
            $Hmessage = cutColumn($params->get("MESSAGE"), 80);
        }

        # ������Ǽ���
        if (List::MoreUtils::any {$_ eq "LBBSNAME"} $params->keys) {
            $HlbbsName = $params->get("LBBSNAME");
            $HdefaultName = $params->get("LBBSNAME");
        }
        if (List::MoreUtils::any {$_ eq "LBBSMESSAGE"} $params->keys) {
            $HlbbsMessage = cutColumn($params->get("LBBSMESSAGE"), 80);
        }

        # main mode�μ���
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
                # �Ѹ���
                $HlbbsMode = 0;
            } elsif($1 eq 'OW') {
                # ���
                $HlbbsMode = 1;
            } else {
                # ���
                $HlbbsMode = 2;
            }
            $HcurrentID = $2;

            # ������⤷��ʤ��Τǡ��ֹ�����
            $HcommandPlanNumber = $params->get("NUMBER");

        } elsif (List::MoreUtils::any {$_ eq "ChangeInfoButton"} $params->keys) {
            $HmainMode = 'change';
        } elsif (List::MoreUtils::any {$_ =~ /MessageButton([0-9]*)/} $params->keys) {
            $HmainMode = 'comment';
            $HcurrentID = $1;
        } elsif (List::MoreUtils::any {$_ =~ /CommandButton/} $params->keys) {
            $HmainMode = 'command';

            # ���ޥ�ɥ⡼�ɤξ�硢���ޥ�ɤμ���
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


    #cookie����
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

    #cookie����
    sub cookieOutput {
        my($cookie, $info);

        # �ä�����¤�����
        my($sec, $min, $hour, $date, $mon, $year, $day, $yday, $dummy) =
        gmtime(time + 30 * 86400); # ���� + 30��

        # 2������
        $year += 1900;
        if ($date < 10) { $date = "0$date"; }
        if ($hour < 10) { $hour = "0$hour"; }
        if ($min < 10) { $min  = "0$min"; }
        if ($sec < 10) { $sec  = "0$sec"; }

        # ������ʸ����
        $day = ("Sunday", "Monday", "Tuesday", "Wednesday",
            "Thursday", "Friday", "Saturday")[$day];

        # ���ʸ����
        $mon = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")[$mon];

        # �ѥ��ȴ��¤Υ��å�
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
            # ��ư�ϰʳ�
            $cookie_buffer .= "${HthisFile}KIND=($HcommandKind) $info";
        }
    }

#----------------------------------------------------------------------
# �桼�ƥ���ƥ�
#----------------------------------------------------------------------
    sub hakolock {
        if($lockMode == 1) {
        # directory����å�
        return hakolock1();

        } elsif($lockMode == 2) {
        # flock����å�
        return hakolock2();
        } elsif($lockMode == 3) {
        # symlink����å�
        return hakolock3();
        } else {
        # �̾�ե����뼰��å�
        return hakolock4();
        }
    }

    sub hakolock1 {
        # ��å���
        if(mkdir('hakojimalock', $HdirMode)) {
        # ����
        return 1;
        } else {
        # ����
        my($b) = (stat('hakojimalock'))[9];
        if(($b > 0) && ((time() -  $b)> $unlockTime)) {
            # �������
            unlock();

            # �إå�����
            tempHeader();

            # ���������å�����
            tempUnlock();

            # �եå�����
            tempFooter();

            # ��λ
            warn "no way";
            exit(0);
        }
        return 0;
        }
    }

    sub hakolock2 {
        open(LOCKID, '>>hakojimalockflock');
        if(flock(LOCKID, 2)) {
        # ����
        return 1;
        } else {
        # ����
        return 0;
        }
    }

    sub hakolock3 {
        # ��å���
        if(symlink('hakojimalockdummy', 'hakojimalock')) {
        # ����
        return 1;
        } else {
        # ����
        my($b) = (lstat('hakojimalock'))[9];
        if(($b > 0) && ((time() -  $b)> $unlockTime)) {
            # �������
            unlock();

            # �إå�����
            tempHeader();

            # ���������å�����
            tempUnlock();

            # �եå�����
            tempFooter();

            # ��λ
            warn "ihr";
            exit(0);
        }
        return 0;
        }
    }

    sub hakolock4 {
        # ��å���
        if(unlink('key-free')) {
        # ����
        open(OUT, '>key-locked');
        print OUT time;
        close(OUT);
        return 1;
        } else {
        # ��å����֥����å�
        if(!open(IN, 'key-locked')) {
            return 0;
        }

        my($t);
        $t = <IN>;
        close(IN);
        if(($t != 0) && (($t + $unlockTime) < time)) {
            # 120�ðʾ�вᤷ�Ƥ��顢����Ū�˥�å��򳰤�
            unlock();

            # �إå�����
            tempHeader();

            # ���������å�����
            tempUnlock();

            # �եå�����
            tempFooter();

            # ��λ
            warn "hoge";
            exit(0);
        }
        return 0;
        }
    }

# ��å��򳰤�
    sub unlock {
        if($lockMode == 1) {
        # directory����å�
        rmdir('hakojimalock');

        } elsif($lockMode == 2) {
        # flock����å�
        close(LOCKID);

        } elsif($lockMode == 3) {
        # symlink����å�
        unlink('hakojimalock');
        } else {
        # �̾�ե����뼰��å�
        my($i);
        $i = rename('key-locked', 'key-free');
        }
    }

# �����������֤�
    sub min {
        return ($_[0] < $_[1]) ? $_[0] : $_[1];
    }

# �ѥ���ɥ��󥳡���
    sub encode {
        if($cryptOn == 1) {
        return crypt($_[0], 'h2');
        } else {
        return $_[0];
        }
    }

# �ѥ���ɥ����å�
    sub checkPassword {
        my($p1, $p2) = @_;

        # null�����å�
        if($p2 eq '') {
        return 0;
        }

        # �ޥ������ѥ���ɥ����å�
        if($masterPassword eq $p2) {
        return 1;
        }

        # ����Υ����å�
        if($p1 eq encode($p2)) {
        return 1;
        }

        return 0;
    }

# 1000��ñ�̴ݤ�롼����
    sub aboutMoney {
        my($m) = @_;
        if($m < 500) {
        return "����500${HunitMoney}̤��";
        } else {
        $m = int(($m + 500) / 1000);
        return "����${m}000${HunitMoney}";
        }
    }

# ����������ʸ���ν���
    sub htmlEscape {
        my($s) = @_;
        $s =~ s/&/&amp;/g;
        $s =~ s/</&lt;/g;
        $s =~ s/>/&gt;/g;
        $s =~ s/\"/&quot;/g; #"
        return $s;
    }

# 80�������ڤ�·��
    sub cutColumn {
        my($s, $c) = @_;
        if(length($s) <= $c) {
        return $s;
        } else {
        # ���80�����ˤʤ�ޤ��ڤ���
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

# ���̾�������ֹ������(ID����ʤ����ֹ�)
    sub nameToNumber {
        my($name) = @_;

        # ���礫��õ��
        my($i);
        for($i = 0; $i < $HislandNumber; $i++) {
        if($Hislands[$i]->{'name'} eq $name) {
            return $i;
        }
        }

        # ���Ĥ���ʤ��ä����
        return -1;
    }

# ���äξ���
    sub monsterSpec {
        my($lv) = @_;

        # ����
        my($kind) = int($lv / 10);

        # ̾��
        my($name);
        $name = $HmonsterName[$kind];

        # ����
        my($hp) = $lv - ($kind * 10);
        
        return ($kind, $name, $hp);
    }

# �и��Ϥ����٥�򻻽�
    sub expToLevel {
        my($kind, $exp) = @_;
        my($i);
        if($kind == $HlandBase) {
        # �ߥ��������
        for($i = $maxBaseLevel; $i > 1; $i--) {
            if($exp >= $baseLevelUp[$i - 2]) {
            return $i;
            }
        }
        return 1;
        } else {
        # �������
        for($i = $maxSBaseLevel; $i > 1; $i--) {
            if($exp >= $sBaseLevelUp[$i - 2]) {
            return $i;
            }
        }
        return 1;
        }

    }

# (0,0)����(size - 1, size - 1)�ޤǤο��������ŤĽФƤ���褦��
# (@Hrpx, @Hrpy)������
    sub makeRandomPointArray {
        # �����
        my($y);
        @Hrpx = (0..$HislandSize-1) x $HislandSize;
        for($y = 0; $y < $HislandSize; $y++) {
        push(@Hrpy, ($y) x $HislandSize);
        }

        # ����åե�
        my ($i);
        for ($i = $HpointNumber; --$i; ) {
        my($j) = int(rand($i+1)); 
        if($i == $j) { next; }
        @Hrpx[$i,$j] = @Hrpx[$j,$i];
        @Hrpy[$i,$j] = @Hrpy[$j,$i];
        }
    }

# 0����(n - 1)�����
    sub random {
        return int(rand(1) * $_[0]);
    }

#----------------------------------------------------------------------
# ��ɽ��
#----------------------------------------------------------------------
# �ե������ֹ����ǥ�ɽ��
    sub logFilePrint {
        my($fileNumber, $id, $mode) = @_;
        open(LIN, "${HdirName}/hakojima.log$_[0]");
        my($line, $m, $turn, $id1, $id2, $message);
        while($line = <LIN>) {
        $line =~ /^([0-9]*),([0-9]*),([0-9]*),([0-9]*),(.*)$/;
        ($m, $turn, $id1, $id2, $message) = ($1, $2, $3, $4, $5);

        # ��̩�ط�
        if($m == 1) {
            if(($mode == 0) || ($id1 != $id)) {
            # ��̩ɽ�������ʤ�
            next;
            }
            $m = '<B>(��̩)</B>';
        } else {
            $m = '';
        }

        # ɽ��Ū�Τ�
        if($id != 0) {
            if(($id != $id1) &&
               ($id != $id2)) {
            next;
            }
        }

        # ɽ��
        out("<NOBR>${HtagNumber_}������$turn$m${H_tagNumber}��$message</NOBR><BR>\n");
        }
        close(LIN);
    }

#----------------------------------------------------------------------
# �ƥ�ץ졼��
#----------------------------------------------------------------------
# �����
    sub tempInitialize {
        # �祻�쥯��(�ǥե���ȼ�ʬ)
        $HislandList = getIslandList($defaultID);
        $HtargetList = getIslandList($defaultTarget);
    }

# ��ǡ����Υץ�������˥塼��
    sub getIslandList {
        my($select) = @_;
        my($list, $name, $id, $s, $i);

        #��ꥹ�ȤΥ�˥塼
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
            "<OPTION VALUE=\"$id\" $s>${name}��\n";
        }
        return $list;
    }


# �إå�
    sub tempHeader {
        my $xslate = Text::Xslate->new(syntax => 'TTerse');
        my %vars = (
            title => Encode::decode("EUC-JP", $Htitle),
            image_dir => mark_raw($imageDir),
            html_body => mark_raw($htmlBody),
        );
        out(Encode::encode("EUC-JP", $xslate->render("tmpl/header.tt", \%vars)));
    }

# �եå�
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

# ��å�����
    sub tempLockFail {
        # �����ȥ�
        out(<<END);
    ${HtagBig_}Ʊ�������������顼�Ǥ���<BR>
    �֥饦���Ρ����ץܥ���򲡤���<BR>
    ���Ф餯�ԤäƤ�����٤����������${H_tagBig}$HtempBack
END
    }

# �������
    sub tempUnlock {
        # �����ȥ�
        out(<<END);
    ${HtagBig_}����Υ����������۾ｪλ���ä��褦�Ǥ���<BR>
    ��å�����������ޤ�����${H_tagBig}$HtempBack
END
    }

# hakojima.dat���ʤ�
    sub tempNoDataFile {
        out(<<END);
    ${HtagBig_}�ǡ����ե����뤬�����ޤ���${H_tagBig}$HtempBack
END
    }

# �ѥ���ɴְ㤤
    sub tempWrongPassword {
        out(<<END);
    ${HtagBig_}�ѥ���ɤ��㤤�ޤ���${H_tagBig}$HtempBack
END
    }

# ��������ȯ��
    sub tempProblem {
        out(<<END);
    ${HtagBig_}����ȯ�����Ȥꤢ������äƤ���������${H_tagBig}$HtempBack
END
    }

    return sub {
        my ($env) = @_;

        $out_buffer = "";
        $cookie_buffer = "";
        $request = Plack::Request->new($env);
        $response = Plack::Response->new(200);
        $response->content_type("text/html");

        # ��å��򤫤���
        if(!hakolock()) {
            # ��å�����
            # �إå�����
            tempHeader();

            # ��å����ԥ�å�����
            tempLockFail();

            # �եå�����
            tempFooter();

            # ��λ
            exit(0);
        }

        # ����ν����
        srand(time^$$);

        # COOKIE�ɤߤ���
        cookieInput();

        # CGI�ɤߤ���
        cgiInput();

        # ��ǡ������ɤߤ���
        if(readIslandsFile($HcurrentID) == 0) {
            unlock();
            tempHeader();
            tempNoDataFile();
            tempFooter();
            exit(0);
        }

        # �ƥ�ץ졼�Ȥ�����
        tempInitialize();

        # COOKIE����
        cookieOutput();

        # �إå�����
        tempHeader();

        if($HmainMode eq 'turn') {
            # ������ʹ�
            require('hako-turn.cgi');
            require('hako-top.cgi');
            turnMain();

        } elsif($HmainMode eq 'new') {
            # ��ο�������
            require('hako-turn.cgi');
            require('hako-map.cgi');
            newIslandMain();

        } elsif($HmainMode eq 'print') {
            # �Ѹ��⡼��
            require('hako-map.cgi');
            printIslandMain();

        } elsif($HmainMode eq 'owner') {

            # ��ȯ�⡼��
            require('hako-map.cgi');
            ownerMain();

        } elsif($HmainMode eq 'command') {
            # ���ޥ�����ϥ⡼��
            require('hako-map.cgi');
            commandMain();

        } elsif($HmainMode eq 'comment') {
            # ���������ϥ⡼��
            require('hako-map.cgi');
            commentMain();

        } elsif($HmainMode eq 'lbbs') {

            # ������Ǽ��ĥ⡼��
            require('hako-map.cgi');
            localBbsMain();

        } elsif($HmainMode eq 'change') {
            # �����ѹ��⡼��
            require('hako-turn.cgi');
            require('hako-top.cgi');
            changeMain();

        } else {
            # ����¾�ξ��ϥȥåץڡ����⡼��
            require('hako-top.cgi');
            topPageMain();
        }

        # �եå�����
        tempFooter();

        $response->body($out_buffer);
        $response->headers({"Set-Cookie" => $cookie_buffer});
        return $response->finalize;
    };
}

1;
