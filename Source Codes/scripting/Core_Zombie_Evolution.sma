#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <cstrike>
#include <hamsandwich>
#include <fun>
#include <xs>
#include <infinitygame>

#define PLUGIN "Zombie Evolution"
#define VERSION "1.0"
#define AUTHOR "Dias 'Pendragon' Leon"

// Main Config
#define GAME_FOLDER "zombie_evolution"
#define GAME_SETTINGFILE "ZEvo_GameConfig.ini"
#define PLAYER_SETTINGFILE "ZEvo_PlayerConfig.ini"
#define SOUND_SETTINGFILE "ZEvo_SoundConfig.ini"
#define CONFIG_FILE "ZEvo_Cvars.cfg"
#define LANG_FILE "zombie_evolution.txt"

#define HUD_WIN_X -1.0
#define HUD_WIN_Y 0.20
#define HUD_NOTICE_X -1.0
#define HUD_NOTICE_Y 0.25
#define HUD_NOTICE2_X -1.0
#define HUD_NOTICE2_Y 0.70
#define HUD_PLAYER_X -1.0
#define HUD_PLAYER_Y 0.80

#define MAX_HUMAN_LEVEL 10
#define START_MONEY 100

#define GAME_LANG LANG_SERVER
new GameName[32] = "Zombie Evolution"

new const SoundNVG[2][] = { "items/nvg_off.wav", "items/nvg_on.wav"}
new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }

new const Zombie_ClawHud[2][] = 
{
	"sprites/knife_zombie_evo.txt",
	"sprites/knife_zombie_evo.spr"
}

// Knockback System
new KNOCKBACK_TYPE = 2 // 1 - ZP KnockBack | 2 - Dias's Knockback

new KB_DAMAGE = 1
new KB_POWER = 1
new KB_CLASS = 1
new KB_ZVEL = 0
new Float:KB_DUCKING = 0.25
new KB_DISTANCE = 500

new Float:kb_weapon_power[] = 
{
	-1.0,	// ---
	1.2,	// P228
	-1.0,	// ---
	3.5,	// SCOUT
	-1.0,	// ---
	4.0,	// XM1014
	-1.0,	// ---
	1.3,	// MAC10
	2.5,	// AUG
	-1.0,	// ---
	1.2,	// ELITE
	1.0,	// FIVESEVEN
	1.2,	// UMP45
	2.25,	// SG550
	2.25,	// GALIL
	2.25,	// FAMAS
	1.1,	// USP
	1.0,	// GLOCK18
	2.5,	// AWP
	1.25,	// MP5NAVY
	2.25,	// M249
	4.0,	// M3
	2.5,	// M4A1
	1.2,	// TMP
	3.25,	// G3SG1
	-1.0,	// ---
	2.15,	// DEAGLE
	2.5,	// SG552
	3.0,	// AK47
	-1.0,	// ---
	1.0		// P90
}

		
// Block Round Event
new g_BlockedObj_Forward
new g_BlockedObj[12][] =
{
        "func_bomb_target",
        "info_bomb_target",
        "info_vip_start",
        "func_vip_safetyzone",
        "func_escapezone",
        "hostage_entity",
        "monster_scientist",
        "func_hostage_rescue",
        "info_hostage_rescue",
        "item_longjump",
        "func_vehicle",
        "func_buyzone"
}
			
enum
{
	TEAM_NONE = 0,
	TEAM_ZOMBIE,
	TEAM_HUMAN
}

enum
{
	PLAYER_MALE = 0,
	PLAYER_FEMALE
}

enum
{
	PLAYER_HUMAN = 0,
	PLAYER_ZOMBIE
}

enum
{
	HUMAN_NORMAL = 0,
	HUMAN_SIDEKICK,
	HUMAN_HERO
}

enum
{
	ZOMBIE_NORMAL = 0,
	ZOMBIE_THANATOS
}

enum
{
	ITEM_ONCE = 0,
	ITEM_ROUND,
	ITEM_MAP
}

enum 
{
	SKILL_SELF = 0,
	SKILL_G,
	SKILL_F,
	SKILL_T
}

// Shared Code
#define PDATA_SAFE 2
#define OFFSET_CSTEAMS 114
#define OFFSET_CSDEATHS 444
#define OFFSET_PLAYER_LINUX 5
#define OFFSET_WEAPON_LINUX 4
#define OFFSET_WEAPONOWNER 41
const m_flVelocityModifier = 108
const m_flFallVelocity = 251
const m_iRadiosLeft = 192 
const UNIT_SECOND = (1<<12)

// Some shit
#define RADIO_MAXSEND 60
#define CRYSTAL_CLASSNAME "kurisutaru"
#define SUPPLY_CLASSNAME "tasukete"
#define SUPPLYBOX_TEAM CS_TEAM_CT

// Task
#define TASK_COUNTDOWN 18701
#define TASK_TRANSCRIPT 18702
#define TASK_GAMEPLAY 18703
#define TASK_REVIVE 18704
#define TASK_RESETCLAW 18705
#define TASK_SUPPLYBOX 18707
#define TASK_MENU 18708
#define TASK_AUTOSKILL 18709
#define TASK_LEVELUP 18710
#define TASK_RECHECK 18711

// Bits
#define Get_BitVar(%1,%2)		(%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2)		(%1 |= (1 << (%2 & 31)));
#define UnSet_BitVar(%1,%2)		(%1 &= ~(1 << (%2 & 31)));

// Array
new Array:Ar_GameSky, Ar2_S_CrystalModel[50], Ar2_S_SupplyModel[50], Ar2_S_SupplyIcon[50]
new Array:Ar_HumanModelMale, Array:Ar_HumanModelFemale, Ar2_S_HeroModelMale[32], Ar2_S_HeroModelFemale[32]
new Array:Ar_S_Start, Array:Ar_S_Ambience, Ar2_S_Countdown[50], Array:Ar_S_ZombieAppear, Ar2_S_MessageTutorial[64], Array:Ar_S_WinHuman, Array:Ar_S_WinZombie
new Ar2_S_Activate[50], Ar2_S_Pickup[50], Ar2_S_StunActivate[50], Ar2_S_Stun[50], Ar2_S_Reviving[50], 
Ar2_S_Revived[50], Ar2_S_StageBoost[50], Ar2_S_Supplybox_Pick[50], Array:Ar_S_ZombieAlert, Ar2_S_Supplybox_Drop[50]
new Ar2_S_BecomeHero[50], Array:Ar_S_InfectionMale, Array:Ar_S_InfectionFemale
new Ar2_S_Evolution[50], Ar2_S_Recover[50], Array:Ar_S_ClawHit, Array:Ar_S_ClawWall, Array:Ar_S_ClawSwing, 
Ar2_S_InfectionModel[50], Ar2_S_InfectionEffect[50], Ar2_S_DeathEffect[50], Ar2_S_RespawnEffect[50], 
Ar2_S_RevivedEffect[50], Ar2_S_RecoverEffect[50], Ar2_S_RecoverEffect2[50]

new Array:Ar_ZombieName, Array:Ar_ZombieDesc, Array:Ar_ZombieGravity, Array:Ar_ZombieSpeed, 
Array:Ar_ZombieKnockback, Array:Ar_ZombieDefense, Array:Ar_ZombieClawRange, Array:Ar_ZombieModel_Host, 
Array:Ar_ZombieModel_Origin, Array:Ar_ZombieClawModel_Host, Array:Ar_ZombieClawModel_Origin, 
Array:Ar_ZombieDeathSound, Array:Ar_ZombiePainSound, Array:Ar_ZombiePermCode

// Cvars
new g_Cvar_MinPlayer, g_Cvar_Transcript, g_Cvar_Countdown, g_Cvar_GameLight, g_Cvar_WinHud, g_Cvar_OriSource, g_Cvar_NightMin
new g_Cvar_HumanHealth, g_Cvar_HumanArmor, g_Cvar_HumanGravity, g_Cvar_HumanATKUPRad
new g_Cvar_Zombie_HPMax, g_Cvar_Zombie_HPMin, g_Cvar_Zombie_HPRanMax, g_Cvar_Zombie_HPRanMin,
g_Cvar_Zombie_HPLV2, g_Cvar_Zombie_HPLV3, g_Cvar_Zombie_RPHPRedc, g_Cvar_Zombie_RespawnTime,
g_Cvar_Zombie_RegenOri, g_Cvar_Zombie_RegenHos
new g_Cvar_RewardInfect, g_Cvar_RewardKill, g_Cvar_RewardKillHS
new g_Cvar_CrystalOn, g_Cvar_Crystal_RandMax
new g_Cvar_SupplyOn, g_Cvar_SupplyDropTime, g_Cvar_SupplyPer, g_Cvar_SupplyMax, g_Cvar_SupplyIcon
new g_Cvar_NVGAlpha, g_Cvar_HumanColor, g_Cvar_ZombieColor
new g_CvarPointer_RoundTime

// Setting
new g_MinPlayer, g_Transcript, g_SupplyIcon
new g_HumanHealth, g_HumanArmor, Float:g_HumanGravity, Float:g_HumanATKUPRad
new g_NVG_Alpha, g_NVG_HumanColor[3], g_NVG_ZombieColor[3]

// Vars
new g_GameAvailable, g_GameStart, g_GameEnd, g_Joined, g_Round, g_TeamScore[3],Float:g_RoundTimeLeft, 
g_CountTime, g_Countdown, Float:g_PlayerSpawn_Point[64][3], g_PlayerSpawn_Count, g_GameLight[2], Float:MyTime[33],
g_FemaleAvailable, g_NextFemale, g_MaxPlayers, g_ZombieClass_Count, Float:NoticeSound_Delay, Float:UndeadTime[33],
g_SupplyBox_Count, g_RoundEnt[64], g_RoundEnt_Count, g_Midnight

new g_PlayerType[33], g_PlayerLevel[33], g_ZombieClass[33], g_MaxHealth[33], CsTeams:g_MyCSTeam[33],
Float:g_DeadBody[33][3], g_IsFemale, g_Has_NightVision, g_UsingNVG, g_PlayerOwnModel[33][24], g_PermDeath, 
g_RespawnTimeCount[33], g_DamagePercent[33], g_PreviousPercent[33], g_RestoringHealth, Float:g_RestoreTime[33],
Float:g_Evolution[33], Float:g_PlayerIcon[33], Float:g_PlayerIcon2[33], g_NextClass[33], g_SubType[33], 
g_FirstZombie, g_MenuSelecting[33], g_IsRealHero, g_SpecWeapon[33][2], g_InTempingAttack, g_UsingSkill, g_MyMoney[33]

new m_iBlood[2], g_InfectionEffect_SprID, g_DeathEffect_SprID, g_RespawnEffect_SprID, g_Supplybox_IconSprID
new g_MsgScreenFade, g_MsgScreenShake, g_MsgScoreAttrib, g_MsgBarTime, g_MsgDeathMsg, g_MsgScoreInfo, g_MsgHostageAdd, g_MsgHostageDel, g_MsgWeaponList
new g_Hud_Notice, g_Hud_Player

// Item Merchant
#define MAX_ITEM 64
new Array:Ar_ItemName, Array:Ar_ItemCost, Array:Ar_ItemTeam, Array:Ar_ItemType
new g_ItemCount, g_Unlocked[33][MAX_ITEM]

// Special Weapno
new Array:Ar_SWpnName, Array:Ar_SWpnType
new g_SWpnCount

// Weapon bitsums
const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

// Forwards & Natives
#define MAX_FORWARD 21
enum
{
	FWD_ROUND_NEW = 0,
	FWD_ROUND_START,
	FWD_GAME_START,
	FWD_GAME_END,
	FWD_ROUND_TIMELEFT,
	FWD_USER_SPAWN,
	FWD_USER_DEATH,
	FWD_USER_NVG,
	FWD_BECOME_INFECTED,
	FWD_BECOME_ZOMBIE,
	FWD_ZOMBIE_DEACT,
	FWD_LEVELUP,
	FWD_ITEM_ACT,
	FWD_SPECWPN,
	FWD_SWPN_REMOVE,
	FWD_SWPN_REFILL,
	FWD_ZOMBIESKILL,
	FWD_TIME,
	FWD_TIME2,
	FWD_SUPPLYBOX,
	FWD_EQUIP
}
new g_Forwards[MAX_FORWARD], g_fwResult

// Random Origin Generator
#define SS_VERSION	"1.0"
#define SS_MIN_DISTANCE	500.0
#define SS_MAX_LOOPS	100000

new Array:g_vecSsOrigins
new Array:g_vecSsSpawns
new Array:g_vecSsUsed
new Float:g_flSsMinDist
new g_iSsTime

new const g_szStarts[][] = { "info_player_start", "info_player_deathmatch" }
new const Float:g_flOffsets[] = { 3500.0, 3500.0, 1500.0 }

new Float:g_PassedTime
new g_LogLine, g_LogName[128]

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Check Zombie CLass
	if(!g_ZombieClass_Count) set_fail_state("No Zombie Class -> Game Stopped!")
	
	// Special & R.O.G
	Register_SafetyFunc()
	ROG_SsInit(3500.0); ROG_SsScan(); ROG_SsDump()
	
	// Continue
	register_dictionary(LANG_FILE)
	Register_SafetyFunc()
	
	// Event
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")
	register_event("TextMsg", "Event_GameRestart", "a", "2=#Game_will_restart_in")	
	register_event("DeathMsg", "Event_Death", "a")
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	register_logevent("Event_RoundStart", 2, "1=Round_Start")
	register_logevent("Event_RoundEnd", 2, "1=Round_End")	
	
	// Forward
	unregister_forward(FM_Spawn, g_BlockedObj_Forward)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_GetGameDescription, "fw_GetGameDesc")
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")
	register_forward(FM_StartFrame, "fw_StartFrame")
	
	register_touch(CRYSTAL_CLASSNAME, "player", "fw_CrystalTouch")
	register_touch(SUPPLY_CLASSNAME, "player", "fw_SupplyTouch")

	// Hamsandwich
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_PlayerTakeDamage")
	RegisterHam(Ham_TakeDamage, "player", "fw_PlayerTakeDamage_Post", 1)
	RegisterHam(Ham_TraceAttack, "player", "fw_PlayerTraceAttack_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, "weapon_knife", "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Touch, "weaponbox", "fw_TouchWeapon")
	RegisterHam(Ham_Touch, "armoury_entity", "fw_TouchWeapon")
	RegisterHam(Ham_Touch, "weapon_shield", "fw_TouchWeapon")
	for (new i = 1; i < sizeof WEAPONENTNAMES; i++)
		if (WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_Item_Deploy_Post", 1)

	// Message
	register_message(get_user_msgid("StatusIcon"), "Message_StatusIcon")
	register_message(get_user_msgid("TeamScore"), "Message_TeamScore")
	register_message(get_user_msgid("Health"), "Message_Health")
	register_message(get_user_msgid("ClCorpse"), "Message_ClCorpse")
	register_message(get_user_msgid("Money"), "Message_Money")

	// CMD ?
	register_clcmd("nightvision", "CMD_NightVision")
	register_clcmd("drop", "CMD_Drop")
	register_clcmd("radio1", "CMD_Radio") 
	register_clcmd("radio2", "CMD_Radio") 
	register_clcmd("radio3", "CMD_Radio") 
	
	// Team Mananger
	register_clcmd("chooseteam", "CMD_JoinTeam")
	register_clcmd("jointeam", "CMD_JoinTeam")
	register_clcmd("joinclass", "CMD_JoinTeam")	
	
	// Cvars
	Register_CVAR()
	
	// Get Message
	g_MsgScreenFade = get_user_msgid("ScreenFade")
	g_MsgScreenShake = get_user_msgid("ScreenShake")
	g_MsgBarTime = get_user_msgid("BarTime")
	g_MsgScoreAttrib = get_user_msgid("ScoreAttrib")
	g_MsgScoreInfo = get_user_msgid("ScoreInfo")
	g_MsgDeathMsg = get_user_msgid("DeathMsg")
	g_MsgHostageAdd = get_user_msgid("HostagePos")
	g_MsgHostageDel = get_user_msgid("HostageK")
	g_MsgWeaponList = get_user_msgid("WeaponList")
	
	g_MaxPlayers = get_maxplayers()
	
	// Forwards
	g_Forwards[FWD_ROUND_NEW] = CreateMultiForward("zevo_round_new", ET_IGNORE)
	g_Forwards[FWD_ROUND_START] = CreateMultiForward("zevo_round_start", ET_IGNORE)
	g_Forwards[FWD_GAME_START] = CreateMultiForward("zevo_game_start", ET_IGNORE)
	g_Forwards[FWD_GAME_END] = CreateMultiForward("zevo_game_end", ET_IGNORE, FP_CELL)
	g_Forwards[FWD_ROUND_TIMELEFT] = CreateMultiForward("zevo_round_time", ET_IGNORE, FP_CELL)
	g_Forwards[FWD_USER_SPAWN] = CreateMultiForward("zevo_user_spawn", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forwards[FWD_USER_DEATH] = CreateMultiForward("zevo_user_death", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_Forwards[FWD_USER_NVG] = CreateMultiForward("zevo_user_nvg", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	
	g_Forwards[FWD_BECOME_INFECTED] = CreateMultiForward("zevo_become_infected", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_Forwards[FWD_BECOME_ZOMBIE] = CreateMultiForward("zevo_become_zombie", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_Forwards[FWD_ZOMBIE_DEACT] = CreateMultiForward("zevo_zombieclass_deactivate", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forwards[FWD_LEVELUP] = CreateMultiForward("zevo_player_levelup", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_Forwards[FWD_ITEM_ACT] = CreateMultiForward("zevo_item_activate", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forwards[FWD_SPECWPN] = CreateMultiForward("zevo_specialweapon", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_Forwards[FWD_SWPN_REMOVE] = CreateMultiForward("zevo_specialweapon_remove", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forwards[FWD_SWPN_REFILL] = CreateMultiForward("zevo_specialweapon_refill", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forwards[FWD_ZOMBIESKILL] = CreateMultiForward("zevo_zombieskill", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
	g_Forwards[FWD_TIME] = CreateMultiForward("zevo_runningtime", ET_IGNORE, FP_CELL)
	g_Forwards[FWD_TIME2] = CreateMultiForward("zevo_runningtime2", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forwards[FWD_SUPPLYBOX] = CreateMultiForward("zevo_supplybox_pickup", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forwards[FWD_EQUIP] = CreateMultiForward("zevo_equipment_menu", ET_IGNORE, FP_CELL)
	
	// Collect Spawns Point
	collect_spawns_ent("info_player_start")
	collect_spawns_ent("info_player_deathmatch")

	// Check Sex
	if(ArraySize(Ar_HumanModelFemale)) g_FemaleAvailable = 1
	else g_FemaleAvailable = 0
	g_NextFemale = 0
	
	g_Hud_Notice = CreateHudSyncObj(1)
	g_Hud_Player = CreateHudSyncObj(2)
	
	formatex(GameName, sizeof(GameName), "%L", GAME_LANG, "GAME_NAME")
	IG_EndRound_Block(true, true)
	
	// Check Log
	static MapName[32]; get_mapname(MapName, 31)
	static Time[64]; get_time("%m-%d-%Y - %H-%M", Time, 63)
	
	formatex(g_LogName, 127, "%s - %s", MapName, Time)
	
	// Hook
	register_clcmd("knife_zombie_evo", "Hook_ZombieClaw")
	
	register_clcmd("say /money", "Test")
	register_clcmd("sidekick", "Test3")
	register_clcmd("hero", "Test2")
}

public plugin_precache()
{
	// Array
	Ar_HumanModelMale = ArrayCreate(32, 1)
	Ar_HumanModelFemale = ArrayCreate(32, 1)
	
	Ar_GameSky = ArrayCreate(32, 1)
	
	Ar_S_Start = ArrayCreate(64, 1)
	Ar_S_Ambience = ArrayCreate(64, 1)
	Ar_S_ZombieAppear = ArrayCreate(64, 1)
	Ar_S_WinHuman = ArrayCreate(64, 1)
	Ar_S_WinZombie = ArrayCreate(64, 1)
	Ar_S_InfectionMale = ArrayCreate(64, 1)
	Ar_S_InfectionFemale = ArrayCreate(64, 1)
	Ar_S_ClawHit = ArrayCreate(64, 1)
	Ar_S_ClawWall = ArrayCreate(64, 1)
	Ar_S_ClawSwing = ArrayCreate(64, 1)
	Ar_S_ZombieAlert = ArrayCreate(64, 1)
	
	Ar_ZombieName = ArrayCreate(64, 1)
	Ar_ZombieDesc = ArrayCreate(64, 1)
	Ar_ZombieGravity = ArrayCreate(1, 1)
	Ar_ZombieSpeed = ArrayCreate(1, 1)
	Ar_ZombieKnockback = ArrayCreate(1, 1)
	Ar_ZombieDefense = ArrayCreate(1, 1)
	Ar_ZombieClawRange = ArrayCreate(1, 1)
	Ar_ZombieModel_Host = ArrayCreate(64, 1)
	Ar_ZombieModel_Origin = ArrayCreate(64, 1)
	Ar_ZombieClawModel_Host = ArrayCreate(64, 1)
	Ar_ZombieClawModel_Origin = ArrayCreate(64, 1)
	Ar_ZombieDeathSound = ArrayCreate(64, 1)
	Ar_ZombiePainSound = ArrayCreate(64, 1)
	Ar_ZombiePermCode = ArrayCreate(1, 1)
	
	Ar_ItemName = ArrayCreate(64, 1)
	Ar_ItemCost = ArrayCreate(1, 1)
	Ar_ItemTeam = ArrayCreate(1, 1)
	Ar_ItemType = ArrayCreate(1, 1)
	
	Ar_SWpnName = ArrayCreate(64, 1)
	Ar_SWpnType = ArrayCreate(1, 1)
	
	// Claw
	precache_generic(Zombie_ClawHud[0])
	precache_model(Zombie_ClawHud[1])
	
	// Cache
	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")	
	precache_model("models/mileage_wpn/pri/p_null.mdl")
	
	// Register Forward
	g_BlockedObj_Forward = register_forward(FM_Spawn, "fw_BlockedObj_Spawn")	
	
	// Load Data
	Load_GameSetting()
	Precache_GameData()
	Environment_Setting()
}

public plugin_natives()
{
	register_native("zevo_is_zombie", "Native_IsZombie", 1)
	register_native("zevo_is_firstzombie", "Native_IsFZombie", 1)
	
	register_native("zevo_get_zombieclass", "Native_GetZBClass", 1)
	register_native("zevo_get_playertype", "Native_GetPlayerType", 1)
	register_native("zevo_get_subtype", "Native_GetSubType", 1)
	register_native("zevo_get_playersex", "Native_GetSex", 1)
	register_native("zevo_get_playerlevel", "Native_GetLevel", 1)
	register_native("zevo_get_maxhealth", "Native_GetMaxHealth", 1)
	register_native("zevo_get_nightvision", "Native_GetNVG", 1)
	register_native("zevo_set_nightvision", "Native_SetNVG", 1)
	
	register_native("zevo_set_zombie", "Native_SetZombie", 1)
	register_native("zevo_stop_zombieskill", "Native_StopZombie", 1)
	register_native("zevo_set_hero", "Native_SetHero", 1)
	register_native("zevo_set_sidekick", "Native_SetSidekick", 1)
	register_native("zevo_set_thanatos", "Native_SetThanatos", 1)
	register_native("zevo_get_playercount", "Native_GetPlayerCount", 1)
	register_native("zevo_get_livingzombie", "Native_GetLivingZombie", 1)
	register_native("zevo_get_totalplayer", "Native_GetTotalPlayer", 1)
	
	register_native("zevo_set_fakeattack", "Native_FakeAttack", 1)
	register_native("zevo_is_usingskill", "Native_Is_Skill", 1)
	register_native("zevo_set_usingskill", "Native_Set_Skill", 1)
	register_native("zevo_get_zombiecode", "Native_GetCode", 1)
	
	register_native("zevo_set_money", "Native_SetMoney", 1)
	register_native("zevo_get_money", "Native_GetMoney", 1)
	register_native("zevo_speed_set", "Native_SpeedSet", 1)
	register_native("zevo_speed_reset", "Native_SpeedReset", 1)
	register_native("zevo_model_set", "Native_ModelSet", 1)
	register_native("zevo_model_reset", "Native_ModelReset", 1)
	register_native("zevo_team_set", "Native_TeamSet", 1)
	
	register_native("zevo_playerattachment", "Native_PlayerAttachment", 1)
	register_native("zevo_3rdview", "Native_3rdView", 1)
	register_native("zevo_emitsound", "Native_EmitSound", 1)
	
	register_native("zevo_register_zombieclass", "Native_Register_ZombieClass", 1)
	register_native("zevo_register_item", "Native_Register_Item", 1)
	register_native("zevo_register_specialweapon", "Native_Register_SWpn", 1)
}

public plugin_cfg()
{
	// Exec
	new FileUrl[128]
	
	get_configsdir(FileUrl, sizeof(FileUrl))
	formatex(FileUrl, sizeof(FileUrl), "%s/%s/%s", FileUrl, GAME_FOLDER, CONFIG_FILE)
	
	server_exec()
	server_cmd("exec %s", FileUrl)
	
	// Sky
	if(ArraySize(Ar_GameSky))
	{
		new Sky[64]; ArrayGetString(Ar_GameSky, Get_RandomArray(Ar_GameSky), Sky, sizeof(Sky))
		set_cvar_string("sv_skyname", Sky)
	}
	
	set_cvar_float("sv_maxspeed", 999.0)
	
	// Update Cvar
	Update_CVAR()
	
	// New Round
	Event_NewRound()
}

public Test(id)
{	
	// Weapon
	Native_SetMoney(id, 16000, 1)
	///static DualDeagle; DualDeagle = Get_SWpnID("Dual Desert Eagle")
	//if(DualDeagle != -1) ExecuteForward(g_Forwards[FWD_SPECWPN], g_fwResult, id, HUMAN_HERO, DualDeagle)
	/*
	
	id, Ar2_S_RecoverEffect, 1.60, 0.5, 10.0)
	static Body, Target; get_user_aiming(id, Target, Body, 9999)

	if(is_connected(Target))
	{
		
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_MODEL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_coord(0)
		write_coord(0)
		write_coord(500)
		write_angle(random_num(0, 360))
		write_short(g_Ghost_SprID)
		write_byte(0)
		write_byte(5)
		message_end()
		
		client_print(id, print_chat, "target %i", Target)
	}*/
}

public Test2(id)
{	
	// Weapon
	Reset_Player(id, 0)
	Set_PlayerHero(id)
	///static DualDeagle; DualDeagle = Get_SWpnID("Dual Desert Eagle")
	//if(DualDeagle != -1) ExecuteForward(g_Forwards[FWD_SPECWPN], g_fwResult, id, HUMAN_HERO, DualDeagle)
	/*
	
	tachment(id, Ar2_S_RecoverEffect, 1.60, 0.5, 10.0)
	static Body, Target; get_user_aiming(id, Target, Body, 9999)

	if(is_connected(Target))
	{
		
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_MODEL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_coord(0)
		write_coord(0)
		write_coord(500)
		write_angle(random_num(0, 360))
		write_short(g_Ghost_SprID)
		write_byte(0)
		write_byte(5)
		message_end()
		
		client_print(id, print_chat, "target %i", Target)
	}*/
}

public Test3(id)
{	
	// Weapon
	Set_PlayerSidekick(id)
	///static DualDeagle; DualDeagle = Get_SWpnID("Dual Desert Eagle")
	//if(DualDeagle != -1) ExecuteForward(g_Forwards[FWD_SPECWPN], g_fwResult, id, HUMAN_HERO, DualDeagle)
	/*
	
	tachment(id, Ar2_S_RecoverEffect, 1.60, 0.5, 10.0)
	static Body, Target; get_user_aiming(id, Target, Body, 9999)

	if(is_connected(Target))
	{
		
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_MODEL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_coord(0)
		write_coord(0)
		write_coord(500)
		write_angle(random_num(0, 360))
		write_short(g_Ghost_SprID)
		write_byte(0)
		write_byte(5)
		message_end()
		
		client_print(id, print_chat, "target %i", Target)
	}*/
}

public Hook_ZombieClaw(id)
{
	engclient_cmd(id, "weapon_knife")
	return PLUGIN_HANDLED
}

public fw_BlockedObj_Spawn(ent)
{
	if (!pev_valid(ent))
		return FMRES_IGNORED
	
	static Ent_Classname[64]
	pev(ent, pev_classname, Ent_Classname, sizeof(Ent_Classname))
	
	for(new i = 0; i < sizeof g_BlockedObj; i++)
	{
		if (equal(Ent_Classname, g_BlockedObj[i]))
		{
			engfunc(EngFunc_RemoveEntity, ent)
			return FMRES_SUPERCEDE
		}
	}
	
	return FMRES_IGNORED
}

public Register_CVAR()
{
	// Gameplay
	g_Cvar_MinPlayer = register_cvar("zevo_minplayer", "2")
	g_Cvar_Transcript = register_cvar("zevo_transcript", "1")
	g_Cvar_Countdown = register_cvar("zevo_countdown_time", "20")
	g_Cvar_GameLight = register_cvar("zevo_gamelight", "b")
	g_Cvar_WinHud = register_cvar("zevo_winhud", "2")
	g_Cvar_OriSource = register_cvar("zevo_origin_source", "0") // 0 - Use Player Spawns | 1 - Random
	g_Cvar_NightMin = register_cvar("zevo_minplayer_night", "25")
	
	// Human
	g_Cvar_HumanHealth = register_cvar("zevo_human_health", "1000")
	g_Cvar_HumanArmor = register_cvar("zevo_human_armor", "100")
	g_Cvar_HumanGravity = register_cvar("zevo_human_gravity", "0.80")
	g_Cvar_HumanATKUPRad = register_cvar("zevo_human_atkup_radius", "200.0")
	
	// Zombie
	g_Cvar_Zombie_HPMax = register_cvar("zevo_zombie_maxhp", "14000")
	g_Cvar_Zombie_HPMin = register_cvar("zevo_zombie_minhp", "3000")
	g_Cvar_Zombie_HPRanMax = register_cvar("zevo_zombie_maxrandomhp", "10000")
	g_Cvar_Zombie_HPRanMin = register_cvar("zevo_zombie_minrandomhp", "5000")
	g_Cvar_Zombie_HPLV2 = register_cvar("zevo_zombie_lv2hp", "7000")
	g_Cvar_Zombie_HPLV3 = register_cvar("zevo_zombie_lv3hp", "14000")
	g_Cvar_Zombie_RPHPRedc = register_cvar("zevo_zombie_hpdown_pc", "20")
	g_Cvar_Zombie_RespawnTime = register_cvar("zevo_zombie_respawntime", "5")
	g_Cvar_Zombie_RegenOri = register_cvar("zevo_zombie_regen_origin", "500")
	g_Cvar_Zombie_RegenHos = register_cvar("zevo_zombie_regen_host", "200")
	
	// Rewards
	g_Cvar_RewardInfect = register_cvar("zevo_reward_infect", "75")
	g_Cvar_RewardKill = register_cvar("zevo_reward_kill", "100")
	g_Cvar_RewardKillHS = register_cvar("zevo_reward_killhs", "150")
	
	// Crystal
	g_Cvar_CrystalOn = register_cvar("zevo_crystal_enable", "1")
	g_Cvar_Crystal_RandMax = register_cvar("zevo_crystal_randommax", "2") // Min is 1
	
	// Supplybox
	g_Cvar_SupplyOn = register_cvar("zevo_supplybox_enable", "1")
	g_Cvar_SupplyDropTime = register_cvar("zevo_supplybox_droptime", "30")
	g_Cvar_SupplyPer = register_cvar("zevo_supplybox_droponce", "3")
	g_Cvar_SupplyMax = register_cvar("zevo_supplybox_max", "5")
	g_Cvar_SupplyIcon = register_cvar("zevo_supplybox_icon", "1")

	// Nightvision
	g_Cvar_NVGAlpha = register_cvar("zevo_nvg_alpha", "100")
	g_Cvar_HumanColor = register_cvar("zevo_nvg_humancolor", "90 190 90")
	g_Cvar_ZombieColor = register_cvar("zevo_nvg_zombiecolor", "255 85 85")
	
	// Pointer
	g_CvarPointer_RoundTime = get_cvar_pointer("mp_roundtime")
}

public Update_CVAR()
{
	static Buffer[64], Buffer2[3][8]
	
	// Gameplay
	g_MinPlayer = get_pcvar_num(g_Cvar_MinPlayer)
	g_Transcript = get_pcvar_num(g_Cvar_Transcript)
	get_pcvar_string(g_Cvar_GameLight, g_GameLight, 1)
	
	// Humans
	g_HumanHealth = get_pcvar_num(g_Cvar_HumanHealth)
	g_HumanArmor = get_pcvar_num(g_Cvar_HumanArmor)
	g_HumanGravity = get_pcvar_float(g_Cvar_HumanGravity)
	g_HumanATKUPRad = get_pcvar_float(g_Cvar_HumanATKUPRad)
	
	// Supplybox
	g_SupplyIcon = get_pcvar_num(g_Cvar_SupplyIcon)
	
	// Nightvision
	g_NVG_Alpha = get_pcvar_num(g_Cvar_NVGAlpha)
	
	get_pcvar_string(g_Cvar_HumanColor, Buffer, 63)
	parse(Buffer, Buffer2[0], 7, Buffer2[1], 7, Buffer2[2], 7)
	g_NVG_HumanColor[0] = str_to_num(Buffer2[0])
	g_NVG_HumanColor[1] = str_to_num(Buffer2[1])
	g_NVG_HumanColor[2] = str_to_num(Buffer2[2])
	
	get_pcvar_string(g_Cvar_ZombieColor, Buffer, 63)
	parse(Buffer, Buffer2[0], 7, Buffer2[1], 7, Buffer2[2], 7)
	g_NVG_ZombieColor[0] = str_to_num(Buffer2[0])
	g_NVG_ZombieColor[1] = str_to_num(Buffer2[1])
	g_NVG_ZombieColor[2] = str_to_num(Buffer2[2])	
}

// NATIVES
public Native_IsZombie(id)
{
	if(!is_connected(id))
		return 0
	if(g_PlayerType[id] != PLAYER_ZOMBIE)
		return 0
		
	return 1
}

public Native_IsFZombie(id)
{
	if(!is_connected(id))
		return 0
	if(g_PlayerType[id] != PLAYER_ZOMBIE)
		return 0
		
	return Get_BitVar(g_FirstZombie, id) ? 1 : 0
}
	
public Native_GetZBClass(id)
{
	if(!is_connected(id))
		return -1
	
	return g_ZombieClass[id]
}

public Native_GetPlayerType(id)
{
	if(!is_connected(id))
		return 0
		
	return g_PlayerType[id]
}

public Native_GetSubType(id)
{
	if(!is_connected(id))
		return 0
		
	return g_SubType[id]
}

public Native_GetSex(id)
{
	if(!is_connected(id))
		return 0
		
	return get_player_sex(id)
}

public Native_GetLevel(id)
{
	if(!is_connected(id))
		return 0
		
	return g_PlayerLevel[id]
}

public Native_GetMaxHealth(id)
{
	if(!is_connected(id))
		return 0
		
	return g_MaxHealth[id]
}

public Native_GetNVG(id, Have, On)
{
	if(Have && !On)
	{
		if(Get_BitVar(g_Has_NightVision, id) && !Get_BitVar(g_UsingNVG, id))
			return 1
	} else if(!Have && On) {
		if(!Get_BitVar(g_Has_NightVision, id) && Get_BitVar(g_UsingNVG, id))
			return 1
	} else if(Have && On) {
		if(Get_BitVar(g_Has_NightVision, id) && Get_BitVar(g_UsingNVG, id))
			return 1
	} else if(!Have && !On) {
		if(!Get_BitVar(g_Has_NightVision, id) && !Get_BitVar(g_UsingNVG, id))
			return 1
	}
	
	return 0
}

public Native_SetNVG(id, Give, On, Sound, IgnoredHad)
{
	if(!is_connected(id))
		return
		
	if(Give) Set_BitVar(g_Has_NightVision, id)
	set_user_nightvision(id, On, Sound, IgnoredHad)
}

public Native_SetZombie(id, Attacker)
{
	if(!is_alive(id))
		return
	if(g_GameAvailable || g_GameEnd || !g_GameStart)
		return
		
	Set_PlayerZombie(id, Attacker, 0, 0, 0)
}

public Native_StopZombie(id, ClassID)
{
	if(!is_connected(id))
		return
	if(g_PlayerType[id] != PLAYER_ZOMBIE)
		return
		
	ExecuteForward(g_Forwards[FWD_ZOMBIE_DEACT], g_fwResult, id, ClassID)
}

public Native_SetHero(id)
{
	if(!is_alive(id))
		return
	if(g_GameAvailable || g_GameEnd || !g_GameStart)
		return
		
	Set_PlayerHero(id)
}

public Native_SetSidekick(id)
{
	if(!is_alive(id))
		return
	if(g_GameAvailable || g_GameEnd || !g_GameStart)
		return
		
	Set_PlayerSidekick(id)	
}

public Native_SetThanatos(id)
{
	if(!is_alive(id))
		return
	if(g_GameAvailable || g_GameEnd || !g_GameStart)
		return
		
	Set_PlayerThanatos(id)
}

public Native_GetPlayerCount(Alive, Team)
{
	return Get_PlayerCount(Alive, Team)
}

public Native_GetLivingZombie()
{
	return Get_LivingZombie()
}

public Native_GetTotalPlayer(Alive)
{
	return Get_TotalInPlayer(Alive)
}

public Native_FakeAttack(id, Animation)
{
	if(!is_alive(id))
		return
		
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_KNIFE)
	if(!pev_valid(Ent)) return
	
	Set_BitVar(g_InTempingAttack, id)
	ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	
	// Set Real Attack Anim
	set_pev(id, pev_sequence, Animation)
	UnSet_BitVar(g_InTempingAttack, id)
}

public Native_Is_Skill(id)
{
	if(!is_connected(id))
		return 0
		
	return Get_BitVar(g_UsingSkill, id) ? 1 : 0
}

public Native_Set_Skill(id, Use)
{
	if(!is_connected(id))
		return
		
	if(Use) Set_BitVar(g_UsingSkill, id)
	else UnSet_BitVar(g_UsingSkill, id)
}

public Native_GetCode(ClassID)
{
	if(ClassID >= g_ZombieClass_Count)
		return 1
		
	return ArrayGetCell(Ar_ZombiePermCode, ClassID)
}

public Native_GetMoney(id, Amount)
{
	if(!is_connected(id))
		return 0
		
	return g_MyMoney[id]
}

public Native_SetMoney(id, Amount, Update)
{
	if(!is_connected(id))
		return
		
	g_MyMoney[id] = Amount
	
	// Update
	static MSG; if(!MSG) MSG = get_user_msgid("Money")
	
	message_begin(MSG_ONE_UNRELIABLE, MSG, _, id)
	write_long(Amount)
	write_byte(Update ? 1 : 0)
	message_end()
}

public Native_ModelSet(id, const Model[], Modelindex)
{
	param_convert(2)
	ZEVO_ModelSet(id, Model, Modelindex)
}
public Native_ModelReset(id) ZEVO_ModelReset(id)
public Native_SpeedSet(id, Float:Speed, BlockSpeed) ZEVO_SpeedSet(id, Speed, BlockSpeed)
public Native_SpeedReset(id) ZEVO_SpeedReset(id)
public Native_TeamSet(id, CsTeams:Team) ZEVO_TeamSet(id, Team)

public Native_PlayerAttachment(id, const Sprite[], Float:Time, Float:Scale, Float:Framerate)
{
	param_convert(2)
	ZEVO_PlayerAttachment(id, Sprite, Time, Scale, Framerate)
}
public Native_3rdView(id, Enable)
{
	ZEVO_3rdView(id, Enable)
}
public Native_EmitSound(id, receiver, channel, const sample[], Float:volume, Float:attn, flags, pitch, Float:origin[3])
{
	param_convert(4)
	ZEVO_EmitSound(id, receiver, channel, sample, volume, attn, flags, pitch, origin)
}
	
public Native_Register_ZombieClass(const Name[], const Desc[], Float:Speed, Float:Gravity, Float:Knockback, Float:Defense, Float:ClawRange, const ModelOrigin[], const ModelHost[], const ClawModel_Origin[], const ClawModel_Host[], const DeathSound[], const PainSound[], PermanentCode)
{
	param_convert(1)
	param_convert(2)
	param_convert(8)
	param_convert(9)
	param_convert(10)
	param_convert(11)
	param_convert(12)
	param_convert(13)
	
	ArrayPushString(Ar_ZombieName, Name)
	ArrayPushString(Ar_ZombieDesc, Desc)
	
	ArrayPushCell(Ar_ZombieSpeed, Speed)
	ArrayPushCell(Ar_ZombieGravity, Gravity)
	ArrayPushCell(Ar_ZombieKnockback, Knockback)
	ArrayPushCell(Ar_ZombieDefense, Defense)
	ArrayPushCell(Ar_ZombieClawRange, ClawRange)
	
	ArrayPushString(Ar_ZombieModel_Origin, ModelOrigin)
	ArrayPushString(Ar_ZombieModel_Host, ModelHost)
	ArrayPushString(Ar_ZombieClawModel_Origin, ClawModel_Origin)
	ArrayPushString(Ar_ZombieClawModel_Host, ClawModel_Host)
	ArrayPushString(Ar_ZombieDeathSound, DeathSound)
	ArrayPushString(Ar_ZombiePainSound, PainSound)
	
	ArrayPushCell(Ar_ZombiePermCode, PermanentCode)
	
	// Precache those shits... of course :)
	new BufferA[80]
	
	formatex(BufferA, sizeof(BufferA), "models/player/%s/%s.mdl", ModelOrigin, ModelOrigin)
	engfunc(EngFunc_PrecacheModel, BufferA); 
	formatex(BufferA, sizeof(BufferA), "models/player/%s/%s.mdl", ModelHost, ModelHost)
	engfunc(EngFunc_PrecacheModel, BufferA); 
	
	formatex(BufferA, sizeof(BufferA), "models/%s/zombie/%s", GAME_FOLDER, ClawModel_Origin)
	engfunc(EngFunc_PrecacheModel, BufferA); 
	formatex(BufferA, sizeof(BufferA), "models/%s/zombie/%s", GAME_FOLDER, ClawModel_Host)
	engfunc(EngFunc_PrecacheModel, BufferA); 
	
	engfunc(EngFunc_PrecacheSound, DeathSound)
	engfunc(EngFunc_PrecacheSound, PainSound)
	
	g_ZombieClass_Count++
	return g_ZombieClass_Count - 1
}

public Native_Register_Item(const Name[], Team, Cost, Type)
{
	param_convert(1)
	
	ArrayPushString(Ar_ItemName, Name)
	ArrayPushCell(Ar_ItemTeam, Team)
	ArrayPushCell(Ar_ItemCost, Cost)
	ArrayPushCell(Ar_ItemType, Type)
	
	g_ItemCount++
	return g_ItemCount - 1
}

public Native_Register_SWpn(const Name[], Type)
{
	param_convert(1)
	
	ArrayPushString(Ar_SWpnName, Name)
	ArrayPushCell(Ar_SWpnType, Type)
	
	g_SWpnCount++
	return g_SWpnCount - 1
}
	
// ================== PUBLIC FORWARD =====================
// =======================================================
public client_putinserver(id)
{
	Thanatos_GameLog("Client: Joined (%i)", id)
	
	Safety_Connected(id)
	set_task(0.25, "Set_ConnectInfo", id)
	set_task(0.25, "Recheck_NewPlayer", id+TASK_RECHECK)
	
	Reset_Player(id, 1)
	
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Register_HamBot", id)
	}
	
	if(g_FemaleAvailable)
	{
		if(g_NextFemale) 
		{
			Set_BitVar(g_IsFemale, id)
			g_NextFemale = 0
			
			ArrayGetString(Ar_HumanModelFemale, Get_RandomArray(Ar_HumanModelFemale), g_PlayerOwnModel[id], 23)
		} else {
			UnSet_BitVar(g_IsFemale, id)
			g_NextFemale = 1
			
			ArrayGetString(Ar_HumanModelMale, Get_RandomArray(Ar_HumanModelMale), g_PlayerOwnModel[id], 23)
		}
	} else {
		UnSet_BitVar(g_IsFemale, id)
		ArrayGetString(Ar_HumanModelMale, Get_RandomArray(Ar_HumanModelMale), g_PlayerOwnModel[id], 23)
	}
}

public Recheck_NewPlayer(id)
{
	id -= TASK_RECHECK
	
	if(!is_connected(id))
		return
	if(Get_BitVar(g_Joined, id))
		return
	if(cs_get_user_team(id) == CS_TEAM_T)
	{
		ZEVO_TeamSet(id, CS_TEAM_CT)
		Thanatos_GameLog("Client: Forced to CT (%i)", id)
		
		return
	}
	
	set_task(0.25, "Recheck_NewPlayer", id+TASK_RECHECK)
}

public Set_ConnectInfo(id)
{
	if(!is_connected(id)) 
		return

	SetPlayerLight(id, g_GameLight)
}

public Register_HamBot(id) 
{
	Register_SafetyFuncBot(id)
	
	RegisterHamFromEntity(Ham_Spawn, id, "fw_PlayerSpawn_Post", 1)
	RegisterHamFromEntity(Ham_Killed, id, "fw_PlayerKilled_Post", 1)
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_PlayerTraceAttack_Post", 1)
	RegisterHamFromEntity(Ham_TakeDamage, id, "fw_PlayerTakeDamage")
	RegisterHamFromEntity(Ham_TakeDamage, id, "fw_PlayerTakeDamage_Post", 1)
	RegisterHamFromEntity(Ham_CS_Player_ResetMaxSpeed, id, "fw_Ham_ResetMaxSpeed")
}

public client_disconnect(id)
{
	Thanatos_GameLog("Client: Disconnected (%i)", id)
	
	Safety_Disconnected(id)
	Reset_Player(id, 1)
	
	UnSet_BitVar(g_Joined, id)
}

public ZEVO_RunningTime()
{
	static Player; Player = Get_TotalInPlayer(2)
	
	if(g_GameAvailable && (Player < g_MinPlayer))
	{
		g_GameAvailable = 0
		g_GameStart = 0
		g_GameEnd = 0
	} else if(!g_GameAvailable && (Player >= g_MinPlayer)) { // START GAME NOW :D
		g_GameAvailable = 1
		g_GameStart = 0
		g_GameEnd = 0
		
		Game_Ending(5.0, 1, CS_TEAM_UNASSIGNED)
	} else if(!g_GameAvailable  && Player < g_MinPlayer) {
		client_print(0, print_center, "%L", GAME_LANG, "NOTICE_PLAYERREQUIRED")
	}	
	// Player
	static Time; Time = floatround(get_gametime())
	
	ExecuteForward(g_Forwards[FWD_TIME], g_fwResult, Time)
	Loop_Player(Time)
	
	// Check Gameplay
	Check_Gameplay()
}

public Loop_Player(Time)
{
	static ClawModel[32]
	for(new id = 0; id < g_MaxPlayers; id++)
	{
		if(!is_connected(id))
			continue
		if(is_alive(id) && g_PlayerType[id] == PLAYER_ZOMBIE)
		{
			pev(id, pev_weaponmodel2, ClawModel, 31)
			if(!equal(ClawModel, "")) set_pev(id, pev_weaponmodel2, "")
		}
		
		ExecuteForward(g_Forwards[FWD_TIME2], g_fwResult, id, Time)
	}
}

public Check_Gameplay()
{
	if(!g_GameAvailable || !g_GameStart || g_GameEnd)
		return
		
	static Zombie, Human;
	Zombie = Get_LivingZombie()
	Human = Get_PlayerCount(1, 2)
	
	if(Zombie <= 0) // All zombies are dead
	{
		StopSound(0)
		Game_Ending(5.0, 0, CS_TEAM_CT)

		g_GameEnd = 1
		
		return
	} else if(Human <= 0) { // All humans are dead
		StopSound(0)
		Game_Ending(5.0, 0, CS_TEAM_T)
		
		g_GameEnd = 1
		
		return
	}
	
	if(Zombie == Human) Game_Midnight()
	else if(abs(Human - Zombie) <= 2) Game_Midnight()
	
	static Float:TimeLeft; TimeLeft = Get_RoundTimeLeft()
	if(TimeLeft <= 0.0) 
	{
		StopSound(0)
		Game_Ending(5.0, 0, CS_TEAM_CT)

		g_GameEnd = 1
	}
	ExecuteForward(g_Forwards[FWD_ROUND_TIMELEFT], g_fwResult, floatround(TimeLeft))
}

public client_impulse(id, Impulse)
{
	if(Impulse == 100 && g_PlayerType[id] == PLAYER_ZOMBIE && g_SubType[id] == ZOMBIE_NORMAL)
	{
		if(UndeadTime[id] <= get_gametime()) ExecuteForward(g_Forwards[FWD_ZOMBIESKILL], g_fwResult, id, g_ZombieClass[id], SKILL_F)
		return PLUGIN_HANDLED
	}
	if(Impulse == 201 && g_PlayerType[id] == PLAYER_ZOMBIE && g_SubType[id] == ZOMBIE_NORMAL)
	{
		if(UndeadTime[id] <= get_gametime()) ExecuteForward(g_Forwards[FWD_ZOMBIESKILL], g_fwResult, id, g_ZombieClass[id], SKILL_T)
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}  

public client_PostThink(id)
{
	if(!is_alive(id))
		return
	if(g_PlayerType[id] == PLAYER_ZOMBIE) 
		Zombie_RegenHealth(id)
	if(g_PlayerType[id] == PLAYER_HUMAN)
	{
		if(g_SupplyIcon)
		{
			if((g_PlayerIcon[id] + 0.05) < get_gametime())
			{
				if(g_SupplyBox_Count)
				{
					for(new i = 0; i < g_RoundEnt_Count; i++)
						Show_OriginIcon(id, g_RoundEnt[i], g_Supplybox_IconSprID)
				}
				
				g_PlayerIcon[id] = get_gametime()
			}
			
			if(get_gametime() - 1.0 > g_PlayerIcon2[id])
			{
				if(g_SupplyBox_Count)
				{
					static i, Next; i = 1; Next = 0
					while(i <= g_RoundEnt_Count)
					{
						Next = g_RoundEnt[i]
						if(pev_valid(Next))
						{
							static Float:Origin[3]
							pev(Next, pev_origin, Origin)
							
							message_begin(MSG_ONE_UNRELIABLE, g_MsgHostageAdd, {0,0,0}, id)
							write_byte(id)
							write_byte(i)		
							write_coord(FloatToNum(Origin[0]))
							write_coord(FloatToNum(Origin[1]))
							write_coord(FloatToNum(Origin[2]))
							message_end()
						
							message_begin(MSG_ONE_UNRELIABLE, g_MsgHostageDel, {0,0,0}, id)
							write_byte(i)
							message_end()
						}
					
						i++
					}
	
				}
				
				g_PlayerIcon2[id] = get_gametime()
			}
		}
	}
		
	static Float:Time; Time = get_gametime()
	if(Time - 0.5 > MyTime[id])
	{
		Update_PlayerHud(id)
		MyTime[id] = Time
	}
}

public Show_OriginIcon(id, Ent, SpriteID) // By sontung0
{
	if (!pev_valid(Ent)) 
		return
	
	static Float:fMyOrigin[3]; pev(id, pev_origin, fMyOrigin)
	
	static Target; Target = Ent
	static Float:fTargetOrigin[3]; pev(Target, pev_origin, fTargetOrigin)
	fTargetOrigin[2] += 40.0
	
	if(!is_in_viewcone(id, fTargetOrigin)) 
		return

	static Float:fMiddle[3], Float:fHitPoint[3]
	xs_vec_sub(fTargetOrigin, fMyOrigin, fMiddle)
	trace_line(-1, fMyOrigin, fTargetOrigin, fHitPoint)
							
	static Float:fWallOffset[3], Float:fDistanceToWall
	fDistanceToWall = vector_distance(fMyOrigin, fHitPoint) - 10.0
	normalize(fMiddle, fWallOffset, fDistanceToWall)
	
	static Float:fSpriteOffset[3]; xs_vec_add(fWallOffset, fMyOrigin, fSpriteOffset)
	static Float:fScale; fScale = 0.01 * fDistanceToWall
	
	static scale; scale = floatround(fScale)
	scale = max(scale, 1)
	scale = min(scale, 2) // SIZE = 2
	scale = max(scale, 1)

	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id)
	write_byte(TE_SPRITE)
	engfunc(EngFunc_WriteCoord, fSpriteOffset[0])
	engfunc(EngFunc_WriteCoord, fSpriteOffset[1])
	engfunc(EngFunc_WriteCoord, fSpriteOffset[2])
	write_short(SpriteID)
	write_byte(scale) 
	write_byte(250)
	message_end()
}

public Zombie_RegenHealth(id)
{
	static Float:Velocity[3], Float:Length
	
	pev(id, pev_velocity, Velocity)
	Length = vector_length(Velocity)
	
	if(!Length)
	{
		if(!Get_BitVar(g_RestoringHealth, id))
		{
			if(get_gametime() - 3.0 > g_RestoreTime[id])
			{	
				Set_BitVar(g_RestoringHealth, id)
				
				static Float:StartHealth; StartHealth = float(g_MaxHealth[id])
				if(get_user_health(id) < floatround(StartHealth))
					ZEVO_PlayerAttachment(id, Ar2_S_RecoverEffect, 1.0, 0.5, 10.0)
					
				g_RestoreTime[id] = get_gametime()
			}
		} else {
			if(get_gametime() - 1.0 > g_RestoreTime[id])
			{
				static Float:StartHealth; StartHealth = float(g_MaxHealth[id])
				if(get_user_health(id) < floatround(StartHealth))
				{
					// get health add
					static health_add
					if(g_PlayerLevel[id] > 1) health_add = get_pcvar_num(g_Cvar_Zombie_RegenOri)
					else health_add = get_pcvar_num(g_Cvar_Zombie_RegenHos)
					
					// get health new
					static health_new; health_new = get_user_health(id) + health_add
					health_new = min(health_new, floatround(StartHealth))
					
					// set health
					Set_PlayerHealth(id, health_new, 0)
					
					// play sound heal
					PlaySound(id, Ar2_S_Recover)
					ZEVO_PlayerAttachment(id, Ar2_S_RecoverEffect2, 1.25, 0.1, 0.0)
					
					if(!Get_BitVar(g_UsingNVG, id))
					{
						// Make a screen fade 
						message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
						write_short((1<<12) * 1) // duration
						write_short(0) // hold time
						write_short(0x0000) // fade type
						write_byte(0) // red
						write_byte(150) // green
						write_byte(0) // blue
						write_byte(50) // alpha
						message_end()
					}
				} else {
					UnSet_BitVar(g_RestoringHealth, id)
					g_RestoreTime[id] = 0.0
				}
				
				g_RestoreTime[id] = get_gametime()
			}
		}
	} else {
		UnSet_BitVar(g_RestoringHealth, id)
		g_RestoreTime[id] = get_gametime()
	}
}

public Update_PlayerHud(id)
{
	static PowerUp[32], PowerDown[32]
	formatex(PowerUp, sizeof(PowerUp), "")
	formatex(PowerDown, sizeof(PowerDown), "")
	
	switch(g_PlayerType[id])
	{
		case PLAYER_HUMAN:
		{
			static Victim; Victim = -1
			static Float:Origin[3]; pev(id, pev_origin, Origin)
			static AvailableHuman; AvailableHuman = 0

			while((Victim = find_ent_in_sphere(Victim, Origin, g_HumanATKUPRad)) != 0)
			{
				if(Victim == id)
					continue
				if(!is_alive(Victim))
					continue
				if(g_PlayerType[Victim] != PLAYER_HUMAN)
					continue
				
				AvailableHuman++
			}
			
			g_DamagePercent[id] = 100
			g_DamagePercent[id] += (10 * g_PlayerLevel[id])
			g_DamagePercent[id] += (5 * AvailableHuman)

			static Level; Level = clamp(g_DamagePercent[id], 100, 200)

			for(new i = 100; i < Level; i += 10)
				formatex(PowerUp, sizeof(PowerUp), "%s||", PowerUp)
			for(new i = 0; i < ((200 - Level) / 10); i++)
				formatex(PowerDown, sizeof(PowerDown), "%s---", PowerDown)
				
			// Update
			static Colour[3]
			Colour[0] = get_color_level(g_DamagePercent[id], 0)
			Colour[1] = get_color_level(g_DamagePercent[id], 1)
			Colour[2] = get_color_level(g_DamagePercent[id], 2)	
			
			if(g_DamagePercent[id] != g_PreviousPercent[id])
			{
				if(g_DamagePercent[id] > 100) fm_set_user_rendering(id, kRenderFxGlowShell, Colour[0], Colour[1], Colour[2], kRenderNormal, 0)
				else fm_set_user_rendering(id)
				
				g_PreviousPercent[id] = g_DamagePercent[id]
			}
	
			// Hud
			set_hudmessage(Colour[0], Colour[1], Colour[2], HUD_PLAYER_X, HUD_PLAYER_Y, 0, 1.0, 1.0)
			ShowSyncHudMsg(id, g_Hud_Player, "%L: %i%% + %i%%^n[%s%s]", GAME_LANG, "HUD_ATK", 100 + (10 * g_PlayerLevel[id]), (5 * AvailableHuman), PowerUp, PowerDown)
		}
		case PLAYER_ZOMBIE:
		{
			if(UndeadTime[id] <= get_gametime() && get_gametime() - UndeadTime[id] < 5)
			{
				static Claw[64]; pev(id, pev_viewmodel2, Claw, 63)
				if(equal(Claw, Ar2_S_InfectionModel)) Set_ZombieClaw(id)
			}
			
			for(new Float:i = 0.0; i < g_Evolution[id]; i += 1.0)
				formatex(PowerUp, sizeof(PowerUp), "%s||", PowerUp)
			for(new Float:i = 10.0; i > g_Evolution[id]; i -= 1.0)
				formatex(PowerDown, sizeof(PowerDown), "%s---", PowerDown)

			set_hudmessage(0, 212, 255, HUD_PLAYER_X, HUD_PLAYER_Y, 0, 1.0, 1.0)
			if(g_PlayerLevel[id] < 3) ShowSyncHudMsg(id, g_Hud_Player, "%L: %i^n[%s%s]", GAME_LANG, "HUD_EVO", g_PlayerLevel[id], PowerUp, PowerDown)
			else ShowSyncHudMsg(id, g_Hud_Player, "%L: MAX^n[%s%s]", GAME_LANG, "HUD_EVO", PowerUp, PowerDown)
		}
	}
}

public Game_Midnight()
{
	if(!get_pcvar_num(g_Cvar_NightMin))
		return
	if(g_Midnight)
		return
		
	Thanatos_GameLog("Game: Midnight")
		
	g_Midnight = 1
	
	// Select Random: Hero
	static PlayerList[32], PlayerNum; 
	static id; PlayerNum = 0

	static Hero, Hero_Name[64], Name[32]
	Hero = Get_PlayerRate(Get_TotalInPlayer(2))
	PlayerNum = 0
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(g_PlayerType[i] != PLAYER_HUMAN)
			continue
			
		PlayerList[PlayerNum] = i
		PlayerNum++
	}
	
	static First; First = 0
	for(new i = 0; i < Hero; i++)
	{
		id = PlayerList[random(PlayerNum)]
		if(is_alive(id) && g_PlayerType[id] == PLAYER_HUMAN && g_SubType[id] != HUMAN_HERO)
		{
			Set_PlayerHero(id)
			get_user_name(id, Name, sizeof(Name))
			
			if(!First) 
			{
				formatex(Hero_Name, sizeof(Hero_Name), "%s", Name)
				First = 1
			} else formatex(Hero_Name, sizeof(Hero_Name), "%s, %s", Hero_Name, Name)
		}
	}
	
	/*
	//Set_PlayerHero(1)
	
	// Select Random:Thanatos
	static Thanatos, Thanatos_Name[64]
	Thanatos = Get_PlayerRate(Get_TotalInPlayer(2))
	PlayerNum = 0
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(g_PlayerType[i] != PLAYER_ZOMBIE)
			continue
			
		PlayerList[PlayerNum] = i
		PlayerNum++
	}
	
	First = 0
	for(new i = 0; i < Thanatos; i++)
	{
		id = PlayerList[random(PlayerNum)]
		if(is_alive(id) && g_PlayerType[id] == PLAYER_ZOMBIE && g_SubType[id] != ZOMBIE_THANATOS)
		{
			Set_PlayerThanatos(id)
			get_user_name(id, Name, sizeof(Name))
			
			if(!First) 
			{
				formatex(Thanatos_Name, sizeof(Hero_Name), "%s", Name)
				First = 1
			} else formatex(Thanatos_Name, sizeof(Hero_Name), "%s, %s", Thanatos_Name, Name)
		}
	}*/
	
	// Notice
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(Hero && g_PlayerType[i] == PLAYER_HUMAN)
			client_print(i, print_center, "%L", GAME_LANG, "NOTICE_HERO2", Hero_Name)
		//if(Thanatos && g_PlayerType[i] == PLAYER_ZOMBIE)
		//	client_print(i, print_center, "%L", GAME_LANG, "NOTICE_THANATOS2", Thanatos_Name)	
	}
	
}

public Set_PlayerHero(id)
{
	Thanatos_GameLog("Client: Become Hero (%i)", id)
	
	g_SubType[id] = HUMAN_HERO
	g_SpecWeapon[id][0] = -1;
	g_SpecWeapon[id][1] = -1;
	UnSet_BitVar(g_IsRealHero, id)

	// Hud
	set_dhudmessage(255, 170, 0, HUD_NOTICE_X, HUD_NOTICE_Y, 2, 3.0, 3.0, 0.05, 1.0)
	show_dhudmessage(id, "%L", GAME_LANG, "NOTICE_HERO")
	
	// Weapon
	Open_Special_WeaponMenu(id, HUMAN_HERO)
}

public Set_PlayerThanatos(id)
{
	g_SubType[id] = ZOMBIE_THANATOS
	
	// Hud
	set_dhudmessage(255, 170, 0, HUD_NOTICE_X, HUD_NOTICE_Y, 2, 3.0, 3.0, 0.05, 1.0)
	show_dhudmessage(id, "%L", GAME_LANG, "NOTICE_THANATOS")
}

public Open_Special_WeaponMenu(id, Type)
{
	static MenuTitle[64], ItemID[4]
	static WpnName[32]
	
	switch(Type)
	{
		case HUMAN_SIDEKICK:
		{
			g_MenuSelecting[id] = 5
			remove_task(id+TASK_MENU)
			set_task(1.0, "SidekickMenu_Repeat", id+TASK_MENU)
			
			formatex(MenuTitle, 63, "%L \r[%i]\w", GAME_LANG, "MENU_WEAPON_NAME", g_MenuSelecting[id])
			static Menu; Menu = menu_create(MenuTitle, "MenuHandle_WeaponSK")
		
			for(new i = 0; i < g_SWpnCount; i++)
			{
				if(ArrayGetCell(Ar_SWpnType, i) != HUMAN_SIDEKICK)
					continue
					
				ArrayGetString(Ar_SWpnName, i, WpnName, 31)
				
				num_to_str(i, ItemID, 3)
				menu_additem(Menu, WpnName, ItemID)
			}
			
			menu_display(id, Menu)
		}
		case HUMAN_HERO:
		{
			g_MenuSelecting[id] = 5
			remove_task(id+TASK_MENU)
			set_task(1.0, "HeroMenu_Repeat", id+TASK_MENU)
			
			formatex(MenuTitle, 63, "%L [%i]", GAME_LANG, "MENU_WEAPON_NAME", g_MenuSelecting[id])
			static Menu; Menu = menu_create(MenuTitle, "MenuHandle_WeaponHR")
		
			for(new i = 0; i < g_SWpnCount; i++)
			{
				if(ArrayGetCell(Ar_SWpnType, i) != HUMAN_HERO)
					continue
					
				ArrayGetString(Ar_SWpnName, i, WpnName, 31)
				
				num_to_str(i, ItemID, 3)
				menu_additem(Menu, WpnName, ItemID)
			}
			
			menu_display(id, Menu)
		}
	}
}

public Random_SpecialWeapon(id, Type)
{
	static WeaponList[64], WeaponCount; 
	static Random; Random = WeaponCount = 0
	
	switch(Type)
	{
		case HUMAN_SIDEKICK:
		{
			for(new i = 0; i < g_SWpnCount; i++)
			{
				if(ArrayGetCell(Ar_SWpnType, i) != HUMAN_SIDEKICK)
					continue
					
				WeaponList[WeaponCount] = i
				WeaponCount++
			}
			
			Random = random(WeaponCount)
			Activate_Sidekick(id, Random)
		}
		case HUMAN_HERO:
		{
			for(new i = 0; i < g_SWpnCount; i++)
			{
				if(ArrayGetCell(Ar_SWpnType, i) != HUMAN_HERO)
					continue
					
				WeaponList[WeaponCount] = i
				WeaponCount++
			}
			
			Random = random(WeaponCount)
			Activate_Hero(id, Random)
		}
	}
}

public SidekickMenu_Repeat(id)
{
	id -= TASK_MENU
	
	if(!is_alive(id))
		return
	if(g_PlayerType[id] != PLAYER_HUMAN || g_SubType[id] != HUMAN_SIDEKICK)
		return
		
	menu_cancel(id)
	
	static MenuTitle[64], ItemID[4]
	static WpnName[32]
	
	if(g_MenuSelecting[id] <= 0)
	{
		// Menu
		formatex(MenuTitle, 63, "%L \r[LOCKED]\w", GAME_LANG, "MENU_WEAPON_NAME")
		static Menu; Menu = menu_create(MenuTitle, "MenuHandle_WeaponSK")
	
		for(new i = 0; i < g_SWpnCount; i++)
		{
			if(ArrayGetCell(Ar_SWpnType, i) != HUMAN_SIDEKICK)
				continue
				
			ArrayGetString(Ar_SWpnName, i, WpnName, 31)
			
			num_to_str(i, ItemID, 3)
			menu_additem(Menu, WpnName, ItemID)
		}
		
		menu_display(id, Menu)
		menu_destroy(Menu)
		
		return
	}
	
	g_MenuSelecting[id]--
		
	// Menu
	formatex(MenuTitle, 63, "%L \r[%i]\w", GAME_LANG, "MENU_WEAPON_NAME", g_MenuSelecting[id])
	static Menu; Menu = menu_create(MenuTitle, "MenuHandle_WeaponSK")

	for(new i = 0; i < g_SWpnCount; i++)
	{
		if(ArrayGetCell(Ar_SWpnType, i) != HUMAN_SIDEKICK)
			continue
			
		ArrayGetString(Ar_SWpnName, i, WpnName, 31)
		
		num_to_str(i, ItemID, 3)
		menu_additem(Menu, WpnName, ItemID)
	}
	
	menu_display(id, Menu)

	// Next	
	set_task(1.0, "SidekickMenu_Repeat", id+TASK_MENU)
}

public HeroMenu_Repeat(id)
{
	id -= TASK_MENU
	
	if(!is_alive(id))
		return
	if(g_PlayerType[id] != PLAYER_HUMAN || g_SubType[id] != HUMAN_HERO)
		return
		
	menu_cancel(id)
	
	static MenuTitle[64], ItemID[4]
	static WpnName[32]
		
	if(g_MenuSelecting[id] <= 0)
	{
		// Menu
		formatex(MenuTitle, 63, "%L [LOCKED]", GAME_LANG, "MENU_WEAPON_NAME")
		static Menu; Menu = menu_create(MenuTitle, "MenuHandle_WeaponHR")
	
		for(new i = 0; i < g_SWpnCount; i++)
		{
			if(ArrayGetCell(Ar_SWpnType, i) != HUMAN_HERO)
				continue
				
			ArrayGetString(Ar_SWpnName, i, WpnName, 31)
			
			num_to_str(i, ItemID, 3)
			menu_additem(Menu, WpnName, ItemID)
		}
		
		menu_display(id, Menu)
		menu_destroy(Menu)
		
		return
	}
	
	g_MenuSelecting[id]--
		
	// Menu
	formatex(MenuTitle, 63, "%L [%i]", GAME_LANG, "MENU_WEAPON_NAME", g_MenuSelecting[id])
	static Menu; Menu = menu_create(MenuTitle, "MenuHandle_WeaponHR")

	for(new i = 0; i < g_SWpnCount; i++)
	{
		if(ArrayGetCell(Ar_SWpnType, i) != HUMAN_HERO)
			continue
			
		ArrayGetString(Ar_SWpnName, i, WpnName, 31)
		
		num_to_str(i, ItemID, 3)
		menu_additem(Menu, WpnName, ItemID)
	}
	
	menu_display(id, Menu)

	// Next	
	set_task(1.0, "HeroMenu_Repeat", id+TASK_MENU)
}

public MenuHandle_WeaponSK(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		remove_task(id+TASK_MENU)
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	if(!is_alive(id))
	{
		remove_task(id+TASK_MENU)
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	if(g_PlayerType[id] != PLAYER_HUMAN)
	{
		remove_task(id+TASK_MENU)
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}

	static Name[64], Data[4], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)

	static Weapon; Weapon = str_to_num(Data)
	Activate_Sidekick(id, Weapon)
	
	remove_task(id+TASK_MENU)
	menu_destroy(Menu)
	return PLUGIN_CONTINUE
}

public MenuHandle_WeaponHR(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		remove_task(id+TASK_MENU)
		menu_destroy(Menu)
		
		return PLUGIN_HANDLED
	}
	if(!is_alive(id))
	{
		remove_task(id+TASK_MENU)
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	if(g_PlayerType[id] != PLAYER_HUMAN)
	{
		remove_task(id+TASK_MENU)
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}

	static Name[64], Data[4], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)

	static Weapon; Weapon = str_to_num(Data)
	Activate_Hero(id, Weapon)
	
	remove_task(id+TASK_MENU)
	menu_destroy(Menu)
	return PLUGIN_CONTINUE
}

public Activate_Sidekick(id, WeaponID)
{
	Thanatos_GameLog("Client: Activate Sidekick (%i)", id)
	
	drop_weapons(id, 1)
	g_SpecWeapon[id][0] = WeaponID;
	g_SpecWeapon[id][1] = -1;
	
	ExecuteForward(g_Forwards[FWD_SPECWPN], g_fwResult, id, HUMAN_SIDEKICK, WeaponID)
}

public Activate_Hero(id, WeaponID)
{
	Thanatos_GameLog("Client: Activate Hero (%i)", id)
	
	// Model
	if(get_player_sex(id) == PLAYER_MALE) ZEVO_ModelSet(id, Ar2_S_HeroModelMale, 1)
	else if(get_player_sex(id) == PLAYER_FEMALE) ZEVO_ModelSet(id, Ar2_S_HeroModelFemale, 1)
	
	// Sound
	PlaySound(id, Ar2_S_BecomeHero)
	
	// Drop
	drop_weapons(id, 1)
	drop_weapons(id, 2)

	// Weapon
	static DualDeagle; DualDeagle = Get_SWpnID("Dual Desert Eagle")
	if(DualDeagle != -1) ExecuteForward(g_Forwards[FWD_SPECWPN], g_fwResult, id, HUMAN_HERO, DualDeagle)
	ExecuteForward(g_Forwards[FWD_SPECWPN], g_fwResult, id, HUMAN_HERO, WeaponID)
	
	// Save
	g_SpecWeapon[id][0] = WeaponID;
	g_SpecWeapon[id][1] = DualDeagle;
	
	Set_BitVar(g_IsRealHero, id)
}

public Get_SWpnID(const Name[])
{
	static Name2[64], ID; ID = -1
	for(new i = 0; i < g_SWpnCount; i++)
	{
		ArrayGetString(Ar_SWpnName, i, Name2, 63)
		if(equal(Name, Name2))
		{
			ID = i
			break
		}
	}
	
	return ID
}

// ====================== MAIN GAME ======================
// =======================================================
public Event_NewRound()
{
	Thanatos_GameLog("Event: New Round")
	
	// Update CVARS
	Update_CVAR()
	
	// Reset Round
	g_Countdown = 0
	g_GameEnd = 0
	g_GameStart = 0
	g_RoundTimeLeft = 0.0
	
	g_SupplyBox_Count = 0
	g_RoundEnt_Count = 0
	g_Midnight = 0
	
	// Reset Item
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_connected(i))
			continue
			
		for(new a = 0; a < g_ItemCount; a++)
		{
			if(ArrayGetCell(Ar_ItemType, a) == ITEM_ROUND)
				g_Unlocked[i][a] = 0
		}
	}
	
	// Remove Task
	remove_task(TASK_TRANSCRIPT)
	remove_task(TASK_COUNTDOWN)
	remove_task(TASK_GAMEPLAY)
	remove_task(TASK_SUPPLYBOX)

	remove_entity_name(CRYSTAL_CLASSNAME)
	remove_entity_name(SUPPLY_CLASSNAME)
	
	if(!g_GameAvailable || g_GameEnd)
	{
		ExecuteForward(g_Forwards[FWD_ROUND_NEW], g_fwResult)
		return
	}
		
	if(ArraySize(Ar_S_Start))
	{
		static Sound[64]; ArrayGetString(Ar_S_Start, Get_RandomArray(Ar_S_Start), Sound, sizeof(Sound))
		PlaySound(0, Sound)
	}
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		g_PlayerType[i] = PLAYER_HUMAN;
		g_PlayerLevel[i] = 0
	}
	
	Start_Countdown()
	ExecuteForward(g_Forwards[FWD_ROUND_NEW], g_fwResult)
}

public Event_RoundStart()
{
	Thanatos_GameLog("Event: Round Start")
	
	if(!g_GameAvailable || g_GameEnd)
	{
		ExecuteForward(g_Forwards[FWD_ROUND_START], g_fwResult)
		return
	}
	
	g_Countdown = 1

	g_RoundTimeLeft = get_gametime() + (get_pcvar_float(g_CvarPointer_RoundTime) * 60.0)
	ZEVO_RoundTime(get_pcvar_num(g_CvarPointer_RoundTime), 0)
	
	// Reset Countingdown
	remove_task(TASK_COUNTDOWN)
	
	g_CountTime--
	CountingDown()
	
	ExecuteForward(g_Forwards[FWD_ROUND_START], g_fwResult)
}

public Event_RoundEnd()
{
	g_GameEnd = 1
	Thanatos_GameLog("Event: Round End")
}

public Event_GameRestart()
{
	Thanatos_GameLog("Event: Game Restart")
	Event_RoundEnd()
}

public Event_Death()
{
	static Attacker, Victim, Headshot
	
	Attacker = read_data(1)
	Victim = read_data(2)
	Headshot = read_data(3)
	
	Thanatos_GameLog("Client: Death (%i/%i/%i)", Attacker, Victim, Headshot)
	
	if(Headshot) Set_BitVar(g_PermDeath, Victim)
	else UnSet_BitVar(g_PermDeath, Victim)
	
	if(is_connected(Victim) && is_connected(Attacker) && g_PlayerType[Victim] == PLAYER_ZOMBIE && g_PlayerType[Attacker] == PLAYER_HUMAN)
	{
		if(!Headshot) Native_SetMoney(Attacker, clamp(g_MyMoney[Attacker] + get_pcvar_num(g_Cvar_RewardKill), 0, 16000), 1)
		else Native_SetMoney(Attacker, clamp(g_MyMoney[Attacker] + get_pcvar_num(g_Cvar_RewardKillHS), 0, 16000), 1)
	}
}

public Event_CurWeapon(id)
{
	if(!is_alive(id)) return
	if(g_PlayerType[id] != PLAYER_HUMAN) return
	
	static Model[64]; pev(id, pev_weaponmodel2, Model, 63)
	if(equal(Model, "")) set_pev(id, pev_weaponmodel2, "models/mileage_wpn/pri/p_null.mdl")
}

public fw_GetGameDesc()
{
	forward_return(FMV_STRING, GameName)
	return FMRES_SUPERCEDE
}

// Emit Sound Forward
public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if (sample[0] == 'h' && sample[1] == 'o' && sample[2] == 's' && sample[3] == 't' && sample[4] == 'a' && sample[5] == 'g' && sample[6] == 'e')
		return FMRES_SUPERCEDE;
	if(!is_alive(id))
		return FMRES_IGNORED
	if(!Get_BitVar(g_InTempingAttack, id))
	{
		if(g_PlayerType[id] == PLAYER_ZOMBIE)
		{
			static sound[64]
			// Zombie being hit
			if (sample[7] == 'b' && sample[8] == 'h' && sample[9] == 'i' && sample[10] == 't')
			{
				ArrayGetString(Ar_ZombiePainSound, g_ZombieClass[id], sound, charsmax(sound))
				emit_sound(id, channel, sound, volume, attn, flags, pitch)
		
				return FMRES_SUPERCEDE;
			}
			
			// Zombie attacks with knife
			if (sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
			{
				if (sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a') // slash
				{
					ArrayGetString(Ar_S_ClawSwing, Get_RandomArray(Ar_S_ClawSwing), sound, charsmax(sound))
					emit_sound(id, channel, sound, volume, attn, flags, pitch)
					
					return FMRES_SUPERCEDE;
				}
				
				if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't') // hit
				{
					if (sample[17] == 'w') // wall
					{
						ArrayGetString(Ar_S_ClawWall, Get_RandomArray(Ar_S_ClawWall), sound, charsmax(sound))
						emit_sound(id, channel, sound, volume, attn, flags, pitch)
			
						return FMRES_SUPERCEDE;
					} else {
						ArrayGetString(Ar_S_ClawHit, Get_RandomArray(Ar_S_ClawHit), sound, charsmax(sound))
						emit_sound(id, channel, sound, volume, attn, flags, pitch)
						
						return FMRES_SUPERCEDE;
					}
				}
				
				if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a') // stab
				{
					ArrayGetString(Ar_S_ClawHit, Get_RandomArray(Ar_S_ClawHit), sound, charsmax(sound))
					emit_sound(id, channel, sound, volume, attn, flags, pitch)
					
					return FMRES_SUPERCEDE;
				}
			}
					
			// Zombie dies
			if (sample[7] == 'd' && ((sample[8] == 'i' && sample[9] == 'e') || (sample[8] == 'e' && sample[9] == 'a')))
			{
				ArrayGetString(Ar_ZombieDeathSound, g_ZombieClass[id], sound, charsmax(sound))
				emit_sound(id, channel, sound, volume, attn, flags, pitch)
				
				return FMRES_SUPERCEDE;
			}
		}
	} else {
		if(sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
		{
			if(sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a')
				return FMRES_SUPERCEDE
			if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't')
			{
				if (sample[17] == 'w')  return FMRES_SUPERCEDE
				else  return FMRES_SUPERCEDE
			}
			if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a')
				return FMRES_SUPERCEDE;
		}
	}

	return FMRES_IGNORED;
}

public fw_TraceLine(Float:vector_start[3], Float:vector_end[3], ignored_monster, id, handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
		
	if(!Get_BitVar(g_InTempingAttack, id))
	{
		if(g_PlayerType[id] != PLAYER_ZOMBIE)
			return FMRES_IGNORED
		
		static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
		
		pev(id, pev_origin, fOrigin)
		pev(id, pev_view_ofs, view_ofs)
		xs_vec_add(fOrigin, view_ofs, vecStart)
		pev(id, pev_v_angle, v_angle)
		
		engfunc(EngFunc_MakeVectors, v_angle)
		get_global_vector(GL_v_forward, v_forward)
	
		xs_vec_mul_scalar(v_forward, ArrayGetCell(Ar_ZombieClawRange, g_ZombieClass[id]), v_forward)
		xs_vec_add(vecStart, v_forward, vecEnd)
		
		engfunc(EngFunc_TraceLine, vecStart, vecEnd, ignored_monster, id, handle)
	} else {
		static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
		
		pev(id, pev_origin, fOrigin)
		pev(id, pev_view_ofs, view_ofs)
		xs_vec_add(fOrigin, view_ofs, vecStart)
		pev(id, pev_v_angle, v_angle)
		
		engfunc(EngFunc_MakeVectors, v_angle)
		get_global_vector(GL_v_forward, v_forward)
	
		xs_vec_mul_scalar(v_forward, 0.0, v_forward)
		xs_vec_add(vecStart, v_forward, vecEnd)
		
		engfunc(EngFunc_TraceLine, vecStart, vecEnd, ignored_monster, id, handle)
	}
	
	return FMRES_SUPERCEDE
}

public fw_TraceHull(Float:vector_start[3], Float:vector_end[3], ignored_monster, hull, id, handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
		
	if(!Get_BitVar(g_InTempingAttack, id))
	{
		if(g_PlayerType[id] != PLAYER_ZOMBIE)
			return FMRES_IGNORED
		
		static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
		
		pev(id, pev_origin, fOrigin)
		pev(id, pev_view_ofs, view_ofs)
		xs_vec_add(fOrigin, view_ofs, vecStart)
		pev(id, pev_v_angle, v_angle)
		
		engfunc(EngFunc_MakeVectors, v_angle)
		get_global_vector(GL_v_forward, v_forward)
		
		xs_vec_mul_scalar(v_forward, ArrayGetCell(Ar_ZombieClawRange, g_ZombieClass[id]), v_forward)
		xs_vec_add(vecStart, v_forward, vecEnd)
		
		engfunc(EngFunc_TraceHull, vecStart, vecEnd, ignored_monster, hull, id, handle)
	} else {
		static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
		
		pev(id, pev_origin, fOrigin)
		pev(id, pev_view_ofs, view_ofs)
		xs_vec_add(fOrigin, view_ofs, vecStart)
		pev(id, pev_v_angle, v_angle)
		
		engfunc(EngFunc_MakeVectors, v_angle)
		get_global_vector(GL_v_forward, v_forward)
		
		xs_vec_mul_scalar(v_forward, 0.0, v_forward)
		xs_vec_add(vecStart, v_forward, vecEnd)
		
		engfunc(EngFunc_TraceHull, vecStart, vecEnd, ignored_monster, hull, id, handle)
	}
	
	return FMRES_SUPERCEDE
}

public fw_StartFrame()
{
	if(get_gametime() - 1.0 > g_PassedTime)
	{
		ZEVO_RunningTime()
		g_PassedTime = get_gametime()
	}
}

public fw_CrystalTouch(Ent, id)
{
	if(!pev_valid(Ent))
		return
	if(!is_alive(id))
		return
	if(g_PlayerType[id] != PLAYER_ZOMBIE)
		return
	if(g_SubType[id] == ZOMBIE_THANATOS)
		return
	if(g_PlayerLevel[id] >= 3)
		return
		
	Thanatos_GameLog("Game: Absorb Crystal (%i)", id)
		
	// Effect
	if(!Get_BitVar(g_UsingNVG, id))
	{
		// Make a screen fade 
		message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
		write_short((1<<12) * 1) // duration
		write_short(0) // hold time
		write_short(0x0000) // fade type
		write_byte(127) // red
		write_byte(255) // green
		write_byte(127) // blue
		write_byte(50) // alpha
		message_end()
	}
		
	EmitSound(id, CHAN_ITEM, Ar2_S_Pickup)
	ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_PICKCRYSTAL")
	
	// Evolution Handle
	g_Evolution[id] += 5.0
	Zombie_Evolution(id)
	
	// Remove
	set_pev(Ent, pev_flags, FL_KILLME)
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01)
}

public fw_SupplyTouch(Ent, id)
{
	if(!pev_valid(Ent))
		return
	if(!is_alive(id))
		return
	if(g_PlayerType[id] != PLAYER_HUMAN)
		return
		
	Thanatos_GameLog("Game: Get Supplybox (%i)", id)
		
	// Effect & Sound
	emit_sound(id, CHAN_ITEM, Ar2_S_Supplybox_Pick, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	SupplyBox_GiveItem(id)
		
	for(new i = 0; i < g_RoundEnt_Count; i++)
	{
		if(g_RoundEnt[i] == Ent)
			g_RoundEnt[i] = -1
	}
		
	g_SupplyBox_Count--
	set_pev(Ent, pev_flags, FL_KILLME)
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01)
}

public SupplyBox_GiveItem(id)
{
	// Nightvision
	if(!Get_BitVar(g_Has_NightVision, id))
	{
		Set_BitVar(g_Has_NightVision, id)
		set_user_nightvision(id, 1, 1, 1)
	}
	
	// Give Grenades
	if(!cs_get_user_bpammo(id, CSW_HEGRENADE)) give_item(id, "weapon_hegrenade")
	//if(!cs_get_user_bpammo(id, CSW_FLASHBANG)) give_item(id, "weapon_flashbang")
	if(!cs_get_user_bpammo(id, CSW_SMOKEGRENADE)) give_item(id, "weapon_smokegrenade")
	
	// Refill Ammo
	if(g_SubType[id] == HUMAN_SIDEKICK)
	{
		if(g_SpecWeapon[id][0] != -1) ExecuteForward(g_Forwards[FWD_SWPN_REFILL], g_fwResult, id, g_SpecWeapon[id][0])
	
		ExecuteForward(g_Forwards[FWD_SUPPLYBOX], g_fwResult, id, 1)
	} else if(g_SubType[id] == HUMAN_HERO) {
		if(g_SpecWeapon[id][0] != -1) ExecuteForward(g_Forwards[FWD_SWPN_REFILL], g_fwResult, id, g_SpecWeapon[id][0])
		if(g_SpecWeapon[id][1] != -1) ExecuteForward(g_Forwards[FWD_SWPN_REFILL], g_fwResult, id, g_SpecWeapon[id][1])
		
		ExecuteForward(g_Forwards[FWD_SUPPLYBOX], g_fwResult, id, 1)
	} else {
		// Open Unlimited Weapon Menu
		ExecuteForward(g_Forwards[FWD_SUPPLYBOX], g_fwResult, id, 0)
	}
}

public fw_PlayerSpawn_Post(id)
{
	if(!is_connected(id)) return
	if(id < 6 && id > 0) Thanatos_GameLog("Client: Spawn (%i)", id)
	
	remove_task(id+TASK_RECHECK)
	Set_BitVar(g_Joined, id)
	
	if(g_PlayerType[id] == PLAYER_ZOMBIE)
	{
		Spawn_PlayerRandom(id)
		ExecuteForward(g_Forwards[FWD_USER_SPAWN], g_fwResult, id, 1)
		Set_PlayerZombie(id, -1, 0, -1, 1)
		
		return
	}
	
	Reset_Player(id, 0)
	Spawn_PlayerRandom(id)
	
	g_Evolution[id] = 0.0
	g_SubType[id] = HUMAN_NORMAL
	g_PlayerLevel[id] = 0
	
	// Set Human
	Set_PlayerNVG(id, 0, 0, 0, 1)
	fm_set_user_rendering(id)
	set_task(0.01, "Set_LightStart", id)

	set_pdata_int(id, m_iRadiosLeft, RADIO_MAXSEND, OFFSET_PLAYER_LINUX)

	Set_PlayerHealth(id, g_HumanHealth, 1)
	set_pev(id, pev_gravity, g_HumanGravity)
	cs_set_user_armor(id, g_HumanArmor, CS_ARMOR_KEVLAR)
	ZEVO_SpeedReset(id)
	
	// Start Weapon
	fm_strip_user_weapons(id)
	fm_give_item(id, "weapon_knife")
	fm_give_item(id, "weapon_usp")
	give_ammo(id, 1, CSW_USP)
	give_ammo(id, 1, CSW_USP)

	ZEVO_TeamSet(id, CS_TEAM_CT)
	g_MyCSTeam[id] = CS_TEAM_CT
	
	ZEVO_ModelSet(id, g_PlayerOwnModel[id], 1)
	
	// Fade Out
	message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, {0,0,0}, id)
	write_short(FixedUnsigned16(2.5, 1<<12))
	write_short(FixedUnsigned16(2.5, 1<<12))
	write_short((0x0000))
	write_byte(0)
	write_byte(0)
	write_byte(0)
	write_byte(255)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
	write_string("weapon_knife")
	write_byte(-1)
	write_byte(-1)
	write_byte(-1)
	write_byte(-1)
	write_byte(2)
	write_byte(1)
	write_byte(CSW_KNIFE)
	write_byte(0)
	message_end()

	ExecuteForward(g_Forwards[FWD_USER_SPAWN], g_fwResult, id, 0)
	
	// Show Info
	static String[96]
	formatex(String, sizeof(String), "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_REMINDHELP")
	ZEVO_ClientPrintColor(id, String)
	
	// Recheck Spawn
	set_task(random_float(0.1, 0.5), "Recheck_Spawn", id)
}

public Recheck_Spawn(id)
{
	Thanatos_GameLog("Client: Spawn POST (%i)", id)
}

public fw_UseStationary(entity, caller, activator, use_type)
{
	if (use_type == 2 && is_connected(caller) && g_PlayerType[caller] == PLAYER_ZOMBIE)
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

public fw_UseStationary_Post(entity, caller, activator, use_type)
{
	if(use_type == 0 && is_connected(caller) && g_PlayerType[caller] == PLAYER_ZOMBIE)
	{
		Thanatos_GameLog("Client: Reset Claw (%i)", caller)
		
		static ClawModel[40], ModelPath[64]
		
		if(g_PlayerLevel[caller] >= 2) ArrayGetString(Ar_ZombieClawModel_Origin, g_ZombieClass[caller], ClawModel, 79)
		else ArrayGetString(Ar_ZombieClawModel_Host, g_ZombieClass[caller], ClawModel, 79)
		
		formatex(ModelPath, sizeof(ModelPath), "models/%s/zombie/%s", GAME_FOLDER, ClawModel)
		set_pev(caller, pev_viewmodel2, ModelPath)
		set_pev(caller, pev_weaponmodel2, "")	
	}
}

public fw_TouchWeapon(weapon, id)
{
	if(!is_connected(id))
		return HAM_IGNORED
	if(g_PlayerType[id] == PLAYER_ZOMBIE)
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

public fw_Item_Deploy_Post(Ent)
{
	static id; id = fm_cs_get_weapon_ent_owner(Ent)
	if (!is_alive(id))
		return;
	
	static CSWID; CSWID = cs_get_weapon_id(Ent)
	if(g_PlayerType[id] == PLAYER_ZOMBIE)
	{
		if(CSWID == CSW_KNIFE)
		{
			Set_ZombieClaw(id)
		} else if(CSWID != CSW_HEGRENADE && CSWID != CSW_FLASHBANG && CSWID != CSW_SMOKEGRENADE) {
			strip_user_weapons(id)
			give_item(id, "weapon_knife")
			engclient_cmd(id, "weapon_knife")
			
			Set_Player_NextAttack(id, 0.75)
			set_weapons_timeidle(id, CSW_KNIFE, 1.0)
			Set_WeaponAnim(id, 3)
		}
	}
}

public Set_ZombieClaw(id)
{
	Thanatos_GameLog("Client: Set Claw (%i)", id)
	
	if(get_user_weapon(id) != CSW_KNIFE) engclient_cmd(id, "weapon_knife")
	
	static ClawModel[40], ModelPath[64]
		
	if(g_PlayerLevel[id] >= 2) ArrayGetString(Ar_ZombieClawModel_Origin, g_ZombieClass[id], ClawModel, 79)
	else ArrayGetString(Ar_ZombieClawModel_Host, g_ZombieClass[id], ClawModel, 79)
	
	if(equal(ClawModel, ""))
		return
	
	formatex(ModelPath, sizeof(ModelPath), "models/%s/zombie/%s", GAME_FOLDER, ClawModel)
	set_pev(id, pev_viewmodel2, ModelPath)
	set_pev(id, pev_weaponmodel2, "")	
	
	Set_Player_NextAttack(id, 0.75)
	set_weapons_timeidle(id, CSW_KNIFE, 1.0)
	Set_WeaponAnim(id, 3)
}

public fw_PlayerTraceAttack_Post(Victim, Attacker, Float:Damage, Float:Direction[3], Trace, DamageBits)
{
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return HAM_IGNORED
	if(Victim == Attacker)
		return HAM_IGNORED
	if(!is_alive(Victim) || !is_connected(Attacker))
		return HAM_IGNORED
	if(g_MyCSTeam[Victim] == g_MyCSTeam[Attacker])
		return HAM_IGNORED
	
	if(KNOCKBACK_TYPE == 1)
	{
		static ducking; ducking = pev(Victim, pev_flags) & (FL_DUCKING | FL_ONGROUND) == (FL_DUCKING | FL_ONGROUND)
		if(ducking && KB_DUCKING == 0.0)
			return HAM_IGNORED
		
		static origin1[3], origin2[3]
		get_user_origin(Victim, origin1)
		get_user_origin(Attacker, origin2)
		
		if(get_distance(origin1, origin2) > KB_DISTANCE)
			return HAM_IGNORED
		
		static Float:velocity[3]
		pev(Victim, pev_velocity, velocity)
	
		if(KB_DAMAGE) xs_vec_mul_scalar(Direction, Damage, Direction)
		static CSWID; CSWID = get_user_weapon(Attacker)
		
		if(KB_POWER  && kb_weapon_power[CSWID] > 0.0) xs_vec_mul_scalar(Direction, kb_weapon_power[CSWID], Direction)
		if(ducking) xs_vec_mul_scalar(Direction, KB_DUCKING, Direction)
		
		if(KB_CLASS) 
		{
			static Float:KBClass; KBClass = 1.0
			if(g_ZombieClass[Victim] != -1) KBClass = ArrayGetCell(Ar_ZombieKnockback, g_ZombieClass[Victim])
			xs_vec_mul_scalar(Direction, KBClass, Direction)
		}
		
		xs_vec_add(velocity, Direction, Direction)
		if(!KB_ZVEL) Direction[2] = velocity[2]
		
		// Set the knockback'd victim's velocity
		set_pev(Victim, pev_velocity, Direction)
	} else if(KNOCKBACK_TYPE == 2) {
		// Knockback
		static ducking; ducking = pev(Victim, pev_flags) & (FL_DUCKING | FL_ONGROUND) == (FL_DUCKING | FL_ONGROUND)
	
		if(ducking) Damage /= 1.25
		if(!(pev(Victim, pev_flags) & FL_ONGROUND)) Damage *= 2.0
	
		static Float:Origin[3]
		pev(Attacker, pev_origin, Origin)
		
		static Float:classzb_knockback; classzb_knockback = 1.0
		if(g_ZombieClass[Victim] != -1) classzb_knockback = ArrayGetCell(Ar_ZombieKnockback, g_ZombieClass[Victim])
	
		hook_ent2(Victim, Origin, Damage, classzb_knockback, 2)
	}

	return HAM_HANDLED
}

public fw_PlayerTakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return HAM_SUPERCEDE
	if(Victim == Attacker)
		SetHamParamFloat(4, 0.0)

	if((is_alive(Attacker) && is_alive(Victim)) && (g_PlayerType[Attacker] == PLAYER_ZOMBIE && g_PlayerType[Victim] == PLAYER_HUMAN))
	{
		// Zombie attacked Human
		if(DamageBits & (1<<24)) return HAM_SUPERCEDE // Grenade
		if(Damage <= 0.0) return HAM_IGNORED
	
		Set_PlayerZombie(Victim, Attacker, 0, 0, 0)
		
		return HAM_SUPERCEDE
	} else if((is_alive(Attacker) && is_alive(Victim)) && g_PlayerType[Attacker] == PLAYER_HUMAN) {
		// Human attacked Zombie
		if(UndeadTime[Victim] > get_gametime())
			return HAM_SUPERCEDE
			
		static Float:Multiple
		Multiple = float(g_DamagePercent[Attacker]) / 100.0
		
		if(Multiple > 1.0 && Multiple != 0.0)
			SetHamParamFloat(4, Damage * Multiple)
	}

	return HAM_HANDLED
}

public fw_PlayerTakeDamage_Post(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return HAM_IGNORED
	if(Victim == Attacker)
		set_pdata_float(Victim, m_flVelocityModifier, 1.0, 5)
		
	if((is_alive(Attacker) && is_alive(Victim)) && (g_PlayerType[Victim] == PLAYER_ZOMBIE && g_PlayerType[Attacker] == PLAYER_HUMAN))
	{
		// Human attacked Zombie
		//if(g_GhoulPainFree) set_pdata_float(Victim, m_flVelocityModifier, 1.0)
	}
		
	return HAM_HANDLED
}

public fw_PlayerKilled_Post(Victim, Attacker)
{
	// Handle Shit
	static Float:Origin[3]; pev(Victim, pev_origin, Origin)
	g_DeadBody[Victim] = Origin
	
	if(g_PlayerType[Victim] == PLAYER_ZOMBIE)
	{
		// Level Up
		if(is_alive(Attacker) && g_PlayerType[Attacker] == PLAYER_HUMAN)
			Human_LevelUp(Attacker)
		
		// Death Effect
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_SPRITE)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2] + 16.0)
		write_short(g_DeathEffect_SprID)
		write_byte(4)
		write_byte(255)
		message_end()
		
		// Leave Crystal
		if(get_pcvar_num(g_Cvar_CrystalOn)) Create_Crystal(Origin)
		
		// Revive?
		set_task(0.5, "Check_PlayerDeath", Victim+TASK_REVIVE)
	}
	
	ExecuteForward(g_Forwards[FWD_USER_DEATH], g_fwResult, Victim, Attacker, Get_BitVar(g_PermDeath, Victim) ? 1 : 0)
	
	// Check Gameplay
	Check_Gameplay()
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
	
	if(g_PlayerType[id] == PLAYER_ZOMBIE)
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
		write_string("knife_zombie_evo")
		write_byte(-1)
		write_byte(-1)
		write_byte(-1)
		write_byte(-1)
		write_byte(2)
		write_byte(1)
		write_byte(CSW_KNIFE)
		write_byte(0)
		message_end()
	} 
	
	return HAM_HANDLED	
}

public Create_Crystal(Float:Origin[3])
{
	Thanatos_GameLog("Game: Crystal Creation")
	
	static Kuri; Kuri = create_entity("info_target")
		
	set_pev(Kuri, pev_classname, CRYSTAL_CLASSNAME)
	engfunc(EngFunc_SetModel, Kuri, Ar2_S_CrystalModel)

	engfunc(EngFunc_SetSize, Kuri, Float:{-16.0,-16.0,0.0}, Float:{16.0,16.0,16.0})
	
	set_pev(Kuri, pev_solid, SOLID_TRIGGER)
	set_pev(Kuri, pev_movetype, MOVETYPE_TOSS)

	static Float:Ori[3]; Ori = Origin; Ori[2] += 8.0
	engfunc(EngFunc_SetOrigin, Kuri, Ori)
	
	fm_set_rendering(Kuri, kRenderFxGlowShell, 100, 255, 100, kRenderNormal, 0)
	set_pev(Kuri, pev_light_level, 180)
	
	// Animation
	set_pev(Kuri, pev_animtime, get_gametime())
	set_pev(Kuri, pev_framerate, 1.0)
	set_pev(Kuri, pev_sequence, 0)
	
	return Kuri
}

public Check_PlayerDeath(id)
{
	id -= TASK_REVIVE
	
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return
	if(!is_connected(id) || is_alive(id))
		return
	if(pev(id, pev_deadflag) != 2)
	{
		set_task(0.25, "Check_PlayerDeath", id+TASK_REVIVE)
		return
	}
	
	// Do Handle Respawn
	set_user_nightvision(id, 0, 0, 1)
	
	if(Get_BitVar(g_PermDeath, id))
	{
		client_print(id, print_center, "%L", GAME_LANG, "NOTICE_PERMDEATH")	
	} else {
		g_RespawnTimeCount[id] = get_pcvar_num(g_Cvar_Zombie_RespawnTime)

		// Bar
		message_begin(MSG_ONE_UNRELIABLE, g_MsgBarTime, {0, 0, 0}, id)
		write_byte(g_RespawnTimeCount[id])
		write_byte(0)
		message_end()
		
		// Make Effect
		static Float:fOrigin[3]
		pev(id, pev_origin, fOrigin)
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_SPRITE)
		engfunc(EngFunc_WriteCoord, g_DeadBody[id][0])
		engfunc(EngFunc_WriteCoord, g_DeadBody[id][1])
		engfunc(EngFunc_WriteCoord, g_DeadBody[id][2])
		write_short(g_RespawnEffect_SprID)
		write_byte(10)
		write_byte(255)
		message_end()
		
		// Check Respawn
		PlaySound(id, Ar2_S_Reviving)
		Start_Revive(id+TASK_REVIVE)
		
		return
	}
}

public Start_Revive(id)
{
	id -= TASK_REVIVE
	
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return
	if(!is_connected(id) || is_alive(id))
		return
	if(Get_BitVar(g_PermDeath, id))
		return
	if(g_RespawnTimeCount[id] <= 0.0)
	{
		Revive_Now(id+TASK_REVIVE)
		return
	}
		
	client_print(id, print_center, "%L", GAME_LANG, "NOTICE_REVIVING", g_RespawnTimeCount[id])
	
	g_RespawnTimeCount[id]--
	set_task(1.0, "Start_Revive", id+TASK_REVIVE)
}

public Revive_Now(id)
{
	id -= TASK_REVIVE
	
	if(!g_GameAvailable || g_GameEnd || !g_GameStart)
		return
	if(!is_connected(id) || is_alive(id))
		return
	if(Get_BitVar(g_PermDeath, id))
		return
		
	Thanatos_GameLog("Client: Zombie Revive (%i)", id)
		
	// Remove Task
	remove_task(id+TASK_REVIVE)
	
	set_pev(id, pev_deadflag, DEAD_RESPAWNABLE)
	ExecuteHamB(Ham_CS_RoundRespawn, id)
}

public SendDeathMsg(attacker, victim)
{
	message_begin(MSG_BROADCAST, g_MsgDeathMsg)
	write_byte(attacker) // killer
	write_byte(victim) // victim
	write_byte(0) // headshot flag
	write_string("claw") // killer's weapon
	message_end()
}

public UpdateFrags(attacker, victim, frags, deaths, scoreboard)
{
	if(is_user_connected(attacker) && is_user_connected(victim) && cs_get_user_team(attacker) != cs_get_user_team(victim))
	{
		if((pev(attacker, pev_frags) + frags) < 0)
			return
	}
	
	if(is_user_connected(attacker))
	{
		// Set attacker frags
		set_pev(attacker, pev_frags, float(pev(attacker, pev_frags) + frags))
		
		// Update scoreboard with attacker and victim info
		if(scoreboard)
		{
			message_begin(MSG_BROADCAST, g_MsgScoreInfo)
			write_byte(attacker) // id
			write_short(pev(attacker, pev_frags)) // frags
			write_short(cs_get_user_deaths(attacker)) // deaths
			write_short(0) // class?
			write_short(fm_cs_get_user_team(attacker)) // team
			message_end()
		}
	}
	
	if(is_user_connected(victim))
	{
		// Set victim deaths
		fm_cs_set_user_deaths(victim, cs_get_user_deaths(victim) + deaths)
		
		// Update scoreboard with attacker and victim info
		if(scoreboard)
		{
			message_begin(MSG_BROADCAST, g_MsgScoreInfo)
			write_byte(victim) // id
			write_short(pev(victim, pev_frags)) // frags
			write_short(cs_get_user_deaths(victim)) // deaths
			write_short(0) // class?
			write_short(fm_cs_get_user_team(victim)) // team
			message_end()
		}
	}
}

public Start_Countdown()
{
	g_CountTime = get_pcvar_num(g_Cvar_Countdown)
	
	remove_task(TASK_COUNTDOWN)
	CountingDown()
}

public CountingDown()
{
	if(!g_GameAvailable || g_GameEnd)
		return
	if(g_CountTime  <= 0)
	{
		Thanatos_GameLog("Game: Countdown Completed")
		set_task(0.1, "Gemu_Hajimemashou")
		return
	}
	
	client_print(0, print_center, "%L", GAME_LANG, "NOTICE_COUNTDOWN", g_CountTime)
	
	static Transcript[24]
	switch(g_CountTime)
	{
		case 18: 
		{
			if(g_Transcript) 
			{
				formatex(Transcript, 23, "TRANSCRIPT_%i%i", 1, random_num(1, 3))
				Send_Transcript(3.0, {42, 255, 127}, 0, "%L", GAME_LANG, Transcript)
			}
		}
		case 14: 
		{
			if(g_Transcript) 
			{
				formatex(Transcript, 23, "TRANSCRIPT_%i%i", 2, random_num(1, 3))
				Send_Transcript(3.0, {42, 255, 127}, 0, "%L", GAME_LANG, Transcript)
			}
		}
		case 10: 
		{
			if(g_Transcript) 
			{
				formatex(Transcript, 23, "TRANSCRIPT_%i%i", 3, random_num(1, 3))
				Send_Transcript(3.0, {42, 255, 127}, 0, "%L", GAME_LANG, Transcript)
			}
		}
		case 5: 
		{
			if(g_Transcript) 
			{
				formatex(Transcript, 23, "TRANSCRIPT_%i%i", 4, random_num(1, 5))
				Send_Transcript(3.0, {255, 212, 42}, 0, "%L", GAME_LANG, Transcript)
			}
		}
		case 2:
		{
			static Sound[64]; ArrayGetString(Ar_S_ZombieAlert, Get_RandomArray(Ar_S_ZombieAlert), Sound, 63)
			PlaySound(0, Sound)
		}
		case 1: 
		{
			if(g_Transcript) 
			{
				formatex(Transcript, 23, "TRANSCRIPT_%i%i", 5, random_num(1, 5))
				Send_Transcript(2.0, {255, 42, 0}, 1, "%L", GAME_LANG, Transcript)
			}
		}
	}
	
	if(g_CountTime <= 10)
	{
		static Sound[64]; format(Sound, charsmax(Sound), Ar2_S_Countdown, g_CountTime)
		PlaySound(0, Sound)
	} 	
	
	if(g_Countdown) g_CountTime--
	set_task(1.0, "CountingDown", TASK_COUNTDOWN)
}

public Send_Transcript(Float:Time, Colour[3], Emergency, const Text[], any:...)
{
	static szMsg[128]; vformat(szMsg, sizeof(szMsg) - 1, Text, 5)
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_connected(i))
			continue
		if(g_PlayerType[i] != PLAYER_HUMAN)
			continue

		set_hudmessage(Colour[0], Colour[1], Colour[2], HUD_NOTICE_X, HUD_NOTICE_Y, Emergency, Time, Time, 0.05, 1.0)
		ShowSyncHudMsg(i, g_Hud_Notice, szMsg)
		
		PlaySound(i, Ar2_S_MessageTutorial)
	}
}

public Gemu_Hajimemashou()
{
	Thanatos_GameLog("Game: Select Zombie")
	g_GameStart = 1
	
	// Make Ghost(s)
	static ZombieNumber; ZombieNumber = Get_ServerZombie()
	static PlayerList[32], PlayerNum; PlayerNum = 0
	static id; get_players(PlayerList, PlayerNum, "a")

	for(new i = 0; i < ZombieNumber; i++)
	{
		id = PlayerList[random(PlayerNum)]
		if(is_alive(id) && g_PlayerType[id] == PLAYER_HUMAN)
			Set_PlayerZombie(id, -1, 1, 0, 0)
	}
	
	//Set_PlayerZombie(1, -1, 1, 0, 0)
	
	// Select Sidekick
	static Sidekick, Sidekick_Name[64], Name[32]
	Sidekick = Get_PlayerRate(Get_TotalInPlayer(2))
	PlayerNum = 0
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(g_PlayerType[i] != PLAYER_HUMAN)
			continue
			
		PlayerList[PlayerNum] = i
		PlayerNum++
	}
	
	static First; First = 0
	for(new i = 0; i < Sidekick; i++)
	{
		id = PlayerList[random(PlayerNum)]
		if(is_alive(id) && g_PlayerType[id] == PLAYER_HUMAN && g_SubType[id] == HUMAN_NORMAL)
		{
			Set_PlayerSidekick(id)
			get_user_name(id, Name, sizeof(Name))
			
			if(!First) 
			{
				formatex(Sidekick_Name, sizeof(Sidekick_Name), "%s", Name)
				First = 1
			} else formatex(Sidekick_Name, sizeof(Sidekick_Name), "%s, %s", Sidekick_Name, Name)
		}
	}
	
	//Set_PlayerSidekick(1)

	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(g_PlayerType[i] != PLAYER_HUMAN)
			continue
		if(cs_get_user_team(i) == CS_TEAM_T)
			ZEVO_TeamSet(i, CS_TEAM_CT)
			
		if(Sidekick) client_print(i, print_center, "%L", GAME_LANG, "NOTICE_SIDEKICK2", Sidekick_Name)
			
		// Show Message
		set_dhudmessage(85, 255, 85, HUD_NOTICE2_X, HUD_NOTICE2_Y, 2, 4.0, 4.0, 0.05, 1.0)
		show_dhudmessage(i, "%L", GAME_LANG, "NOTICE_ZOMBIEARRIVE")
	}
	
	// Supplybox
	remove_task(TASK_SUPPLYBOX)
	set_task(get_pcvar_float(g_Cvar_SupplyDropTime), "SupplyBox_Drop", TASK_SUPPLYBOX, _, _, "b")
	
	// Sound
	static Sound[64]; ArrayGetString(Ar_S_Ambience, Get_RandomArray(Ar_S_Ambience), Sound, 63)
	PlaySound(0, Sound)
	
	// Forward
	ExecuteForward(g_Forwards[FWD_GAME_START], g_fwResult)
	
	Thanatos_GameLog("Game: Select Zombie POST")
}

public SupplyBox_Drop()
{
	if(!get_pcvar_num(g_Cvar_SupplyOn))
	{
		remove_task(TASK_SUPPLYBOX)
		return
	}
	
	for(new i = 0; i < get_pcvar_num(g_Cvar_SupplyPer); i++)
	{
		if(g_SupplyBox_Count >= get_pcvar_num(g_Cvar_SupplyMax))
			return
		
		SupplyBox_Create()
	}
	
	// Play Sound
	for(new id = 0; id < g_MaxPlayers; id++)
	{
		if(!is_alive(id))
			continue
		if(!(cs_get_user_team(id) & SUPPLYBOX_TEAM))
			continue
			
		PlaySound(id, Ar2_S_Supplybox_Drop)
		client_print(id, print_center, "%L", GAME_LANG, "NOTICE_SUPPLYDROP")
	}
}

public SupplyBox_Create()
{
	static Float:Origin[3]
	
	if(!get_pcvar_num(g_Cvar_OriSource))
	{
		static Supply; Supply = create_entity("info_target")
			
		set_pev(Supply, pev_classname, SUPPLY_CLASSNAME)
		engfunc(EngFunc_SetModel, Supply, Ar2_S_SupplyModel)
	
		engfunc(EngFunc_SetSize, Supply, Float:{-10.0,-10.0,0.0}, Float:{10.0,10.0,6.0})
		
		set_pev(Supply, pev_solid, SOLID_TRIGGER)
		set_pev(Supply, pev_movetype, MOVETYPE_TOSS)
	
		Origin[2] += 8.0
		engfunc(EngFunc_SetOrigin, Supply, Origin)
		
		g_SupplyBox_Count++
		g_RoundEnt[g_RoundEnt_Count] = Supply
		g_RoundEnt_Count++
		
		Ent_SpawnRandom(Supply)
	} else {
		if(ROG_SsGetOrigin(Origin))
		{
			static Supply; Supply = create_entity("info_target")
			
			set_pev(Supply, pev_classname, SUPPLY_CLASSNAME)
			engfunc(EngFunc_SetModel, Supply, Ar2_S_SupplyModel)
		
			engfunc(EngFunc_SetSize, Supply, Float:{-10.0,-10.0,0.0}, Float:{10.0,10.0,6.0})
			
			set_pev(Supply, pev_solid, SOLID_TRIGGER)
			set_pev(Supply, pev_movetype, MOVETYPE_TOSS)
		
			Origin[2] += 8.0
			engfunc(EngFunc_SetOrigin, Supply, Origin)
			
			g_SupplyBox_Count++
			g_RoundEnt[g_RoundEnt_Count] = Supply
			g_RoundEnt_Count++
		}
	}
}

public Set_PlayerZombie(id, Attacker, FirstZombie, Evolved, Respawn)
{
	if(!is_alive(id))
		return
		
	Thanatos_GameLog("Game: Make Zombie (%i/%i)", id, Attacker)
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 1", id)
		
	static PreLevel; PreLevel = g_PlayerLevel[id]
	static First; First = Get_BitVar(g_FirstZombie, id) ? 1 : 0
	
	Reset_Player(id, 0)
	
	if(First) Set_BitVar(g_FirstZombie, id)
	
	// Set Zombie
	g_PlayerType[id] = PLAYER_ZOMBIE;
	g_SubType[id] = ZOMBIE_NORMAL
	
	if(is_user_bot(id)) g_ZombieClass[id] = random(g_ZombieClass_Count)
	else {
		if(g_ZombieClass[id] == -1 || g_ZombieClass[id] >= g_ZombieClass_Count)
			g_ZombieClass[id] = random(g_ZombieClass_Count)
			
		if(g_NextClass[id] != -1) 
		{
			g_ZombieClass[id] = g_NextClass[id]
			g_NextClass[id] = -1
		}
	}
	
	ExecuteForward(g_Forwards[FWD_BECOME_INFECTED], g_fwResult, id, Attacker, g_ZombieClass[id])
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 2", id)
	
	if(is_connected(Attacker))
	{
		UpdateFrags(Attacker, id, 1, 1, 1)
		SendDeathMsg(Attacker, id)
		
		Native_SetMoney(Attacker, clamp(g_MyMoney[Attacker] + get_pcvar_num(g_Cvar_RewardInfect), 0, 16000), 1)
		
		// Level Up Around
		static Victim; Victim = -1
		static Float:Origin[3]; pev(id, pev_origin, Origin)

		while((Victim = find_ent_in_sphere(Victim, Origin, g_HumanATKUPRad * 2)) != 0)
		{
			if(Victim == id)
				continue
			if(!is_alive(Victim))
				continue
			if(g_PlayerType[Victim] == PLAYER_HUMAN) Human_LevelUp(Victim)
		}
		
		// Evolution Handle
		if(g_PlayerLevel[Attacker] == 1) g_Evolution[Attacker] += 4.0
		else if(g_PlayerLevel[Attacker] == 2) g_Evolution[Attacker] += 2.0
		Zombie_Evolution(Attacker)
	
		// Create Crystal
		if(get_pcvar_num(g_Cvar_CrystalOn))
		{
			static Float:ScanOri[3], Start; Start = random_num(1, get_pcvar_num(g_Cvar_Crystal_RandMax))
			static Ent;
			if(!get_pcvar_num(g_Cvar_OriSource))
			{
				for(new i = 0 ; i < Start; i++)
				{
					Ent = Create_Crystal(ScanOri)
					Ent_SpawnRandom(Ent)
				}
			} else {
				for(new i = 0 ; i < Start; i++)
				{
					if(ROG_SsGetOrigin(ScanOri)) 
						Create_Crystal(ScanOri)
				}
			}
		}
	}
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 3", id)
	
	// Clear Data
	set_pdata_int(id, m_iRadiosLeft, 0, OFFSET_PLAYER_LINUX)
	Set_Scoreboard_Attrib(id, 0)

	// Set Classic Info
	g_MyCSTeam[id] = CS_TEAM_T

	// Health Setting
	static StartHealth; StartHealth = g_MaxHealth[id]
	static ScreamSound[64]
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 4", id)
	
	if(FirstZombie)
	{
		g_Evolution[id] = 0.0
		g_PlayerLevel[id] = 2
		
		static TotalPlayer; TotalPlayer = Get_TotalInPlayer(1)
		static ZombieNumber; ZombieNumber = Get_ServerZombie()
		
		StartHealth = clamp((TotalPlayer / ZombieNumber) * 1000, get_pcvar_num(g_Cvar_Zombie_HPRanMin), get_pcvar_num(g_Cvar_Zombie_HPRanMax))
		
		if(!Get_BitVar(g_IsFemale, id)) ArrayGetString(Ar_S_InfectionMale, Get_RandomArray(Ar_S_InfectionMale), ScreamSound, 63)
		else ArrayGetString(Ar_S_InfectionFemale, Get_RandomArray(Ar_S_InfectionFemale), ScreamSound, 63)
		EmitSound(id, CHAN_VOICE, ScreamSound)
		
		Set_BitVar(g_FirstZombie, id)
		ZEVO_TeamSet(id, CS_TEAM_T)
	} else {
		if(Respawn)
		{
			g_PlayerLevel[id] = PreLevel
			StartHealth = clamp((StartHealth / 100) * (100 - get_pcvar_num(g_Cvar_Zombie_RPHPRedc)), get_pcvar_num(g_Cvar_Zombie_HPMin), get_pcvar_num(g_Cvar_Zombie_HPMax))
			
			PlaySound(id, Ar2_S_Revived)
			ZEVO_TeamSet(id, CS_TEAM_T)
		} else {
			g_Evolution[id] = 0.0
			
			if(Evolved)
			{
				g_PlayerLevel[id] = 2
				
				static TotalPlayer; TotalPlayer = Get_TotalInPlayer(1)
				static ZombieNumber; ZombieNumber = Get_PlayerCount(1, 1)
		
				StartHealth = clamp((TotalPlayer / ZombieNumber) * 1000, get_pcvar_num(g_Cvar_Zombie_HPRanMin), get_pcvar_num(g_Cvar_Zombie_HPRanMax))
			} else {
				g_PlayerLevel[id] = 1
				
				if(is_connected(Attacker)) 
				{
					static Float:TargetHealth; 
					TargetHealth = float(g_MaxHealth[Attacker]) / 1.3
					StartHealth = clamp(floatround(TargetHealth), get_pcvar_num(g_Cvar_Zombie_HPMin), get_pcvar_num(g_Cvar_Zombie_HPMax))
				} else {
					static TotalPlayer; TotalPlayer = Get_TotalInPlayer(1)
					static ZombieNumber; ZombieNumber = Get_PlayerCount(1, 1)
					
					StartHealth = clamp((TotalPlayer / ZombieNumber) * 1000, get_pcvar_num(g_Cvar_Zombie_HPRanMin), get_pcvar_num(g_Cvar_Zombie_HPRanMax))
				}
			}
			
			if(!Get_BitVar(g_IsFemale, id)) ArrayGetString(Ar_S_InfectionMale, Get_RandomArray(Ar_S_InfectionMale), ScreamSound, 63)
			else ArrayGetString(Ar_S_InfectionFemale, Get_RandomArray(Ar_S_InfectionFemale), ScreamSound, 63)
			EmitSound(id, CHAN_VOICE, ScreamSound)
		}
	}
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 5", id)
	
	UndeadTime[id] = get_gametime() + 1.5
	g_MaxHealth[id] = StartHealth
	Set_PlayerHealth(id, StartHealth, 1)
	cs_set_user_armor(id, 100, CS_ARMOR_KEVLAR)
	
	ZEVO_SpeedSet(id, ArrayGetCell(Ar_ZombieSpeed, g_ZombieClass[id]), 1)
	set_pev(id, pev_gravity, ArrayGetCell(Ar_ZombieGravity, g_ZombieClass[id]))

	static PlayerModel[40]
	if(g_PlayerLevel[id] >= 2) ArrayGetString(Ar_ZombieModel_Origin, g_ZombieClass[id], PlayerModel, sizeof(PlayerModel))
	else ArrayGetString(Ar_ZombieModel_Host, g_ZombieClass[id], PlayerModel, sizeof(PlayerModel))
	ZEVO_ModelSet(id, PlayerModel, 1)
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 6", id)
	
	// Bug Fix
	ZEVO_3rdView(id, 0)
	cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
	set_user_rendering(id)
	
	static MSG; if(!MSG) MSG = get_user_msgid("SetFOV")
	message_begin(MSG_ONE_UNRELIABLE, MSG, {0,0,0}, id)
	write_byte(90)
	message_end()
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 7", id)
	
	// Strip zombies from guns and give them a knife
	strip_user_weapons(id)
	
	if(!Respawn)
	{
		give_item(id, "weapon_hegrenade")
		give_item(id, "weapon_flashbang")
	} else {
		give_item(id, "weapon_hegrenade")
	}
	
	give_item(id, "weapon_knife")
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 8", id)
	
	// Play Draw Animation
	if(!Respawn)
	{
		engclient_cmd(id, "weapon_knife")
		set_pev(id, pev_viewmodel2, Ar2_S_InfectionModel)
		Set_Player_NextAttack(id, 2.0)
		Set_WeaponAnim(id, 0)
	
		remove_task(id+TASK_RESETCLAW)
		set_task(1.5, "Nani_Koreha", id+TASK_RESETCLAW)
	} else {
		Set_Player_NextAttack(id, 0.75)
		set_weapons_timeidle(id, CSW_KNIFE, 1.0)
		Set_WeaponAnim(id, 3)
		
		remove_task(id+TASK_RESETCLAW)
	}
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 9", id)
	
	// Set NVG & Flashlight
	Set_PlayerNVG(id, 1, 1, 0, 1)
	if(pev(id, pev_effects) & EF_DIMLIGHT) set_pev(id, pev_impulse, 100)
	else set_pev(id, pev_impulse, 0)	
	
	// Effect
	static Float:Origin[3]; pev(id, pev_origin, Origin); Origin[2] += 16.0
	Infection_Effect(id, Origin)
	
	// Show Info
	set_dhudmessage(255, 170, 0, HUD_NOTICE2_X, HUD_NOTICE2_Y, 2, 4.0, 4.0, 0.05, 1.0)
	show_dhudmessage(id, "%L", GAME_LANG, "NOTICE_INFECTED")
	
	static String[96]
	formatex(String, sizeof(String), "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_ZOMBIE", StartHealth)
	ZEVO_ClientPrintColor(id, String)
	formatex(String, sizeof(String), "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_REMINDZBCLASS")
	ZEVO_ClientPrintColor(id, String)
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 10", id)
	
	// Auto Zombie
	remove_task(id+TASK_AUTOSKILL)
	if(is_user_bot(id)) set_task(random_float(3.5, 10.0), "Bot_AutoSkill", id+TASK_AUTOSKILL, _, _, "b")
	
	// Check Gameplay
	set_task(0.01, "Handle_BugFix", id)
	ExecuteForward(g_Forwards[FWD_BECOME_ZOMBIE], g_fwResult, id, Attacker, g_ZombieClass[id])
}
/*
public Set_PlayerZombie(id, Attacker, FirstZombie, Evolved, Respawn)
{
	if(!is_alive(id))
		return
		
	static Param[6]
	Param[0] = id 
	Param[1] = Attacker
	Param[2] = FirstZombie
	Param[3] = Evolved
	Param[4] = Respawn
	
	
	Thanatos_GameLog("Game: Make Zombie (%i/%i)", id, Attacker)
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 0", id)
		
	static PreLevel; PreLevel = g_PlayerLevel[id]
	static First; First = Get_BitVar(g_FirstZombie, id) ? 1 : 0
	Param[5] = PreLevel
	Reset_Player(id, 0)
	
	if(First) Set_BitVar(g_FirstZombie, id)
	
	// Set Zombie
	g_PlayerType[id] = PLAYER_ZOMBIE;
	g_SubType[id] = ZOMBIE_NORMAL
	
	if(is_user_bot(id)) g_ZombieClass[id] = random(g_ZombieClass_Count)
	else {
		if(g_ZombieClass[id] == -1 || g_ZombieClass[id] >= g_ZombieClass_Count)
			g_ZombieClass[id] = random(g_ZombieClass_Count)
			
		if(g_NextClass[id] != -1) 
		{
			g_ZombieClass[id] = g_NextClass[id]
			g_NextClass[id] = -1
		}
	}
	
	ExecuteForward(g_Forwards[FWD_BECOME_INFECTED], g_fwResult, id, Attacker, g_ZombieClass[id])
	
	set_task(0.1, "Part1", _, Param, 5)
	
	set_task(0.2, "Part2", _, Param, 5)
	
	set_task(0.3, "Part3", _, Param, 5)
	
	set_task(0.4, "Part4", _, Param, 5)
	
	set_task(0.5, "Part5", _, Param, 5)
	
	set_task(0.6, "Part6", _, Param, 5)
	
	set_task(0.7, "Part7", _, Param, 5)
	
	set_task(0.8, "Part8", _, Param, 5)
	
	// Check Gameplay
	set_task(0.9, "Handle_BugFix", id)
	ExecuteForward(g_Forwards[FWD_BECOME_ZOMBIE], g_fwResult, id, Attacker, g_ZombieClass[id])
}

public Part1(Param[])
{
	static id, Attacker, FirstZombie, Evolved, Respawn
	id = Param[0]
	Attacker = Param[1]
	FirstZombie = Param[2]
	Evolved = Param[3]
	Respawn = Param[4]
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 1", id)
	
	if(is_connected(Attacker))
	{
		UpdateFrags(Attacker, id, 1, 1, 1)
		SendDeathMsg(Attacker, id)
		
		Native_SetMoney(Attacker, clamp(g_MyMoney[Attacker] + get_pcvar_num(g_Cvar_RewardInfect), 0, 16000), 1)
		
		// Level Up Around
		static Victim; Victim = -1
		static Float:Origin[3]; pev(id, pev_origin, Origin)

		while((Victim = find_ent_in_sphere(Victim, Origin, g_HumanATKUPRad * 2)) != 0)
		{
			if(Victim == id)
				continue
			if(!is_alive(Victim))
				continue
			if(g_PlayerType[Victim] == PLAYER_HUMAN) Human_LevelUp(Victim)
		}
		
		// Evolution Handle
		if(g_PlayerLevel[Attacker] == 1) g_Evolution[Attacker] += 4.0
		else if(g_PlayerLevel[Attacker] == 2) g_Evolution[Attacker] += 2.0
		Zombie_Evolution(Attacker)
	
		// Create Crystal
		if(get_pcvar_num(g_Cvar_CrystalOn))
		{
			static Float:ScanOri[3], Start; Start = random_num(1, get_pcvar_num(g_Cvar_Crystal_RandMax))
			static Ent;
			if(!get_pcvar_num(g_Cvar_OriSource))
			{
				for(new i = 0 ; i < Start; i++)
				{
					Ent = Create_Crystal(ScanOri)
					Ent_SpawnRandom(Ent)
				}
			} else {
				for(new i = 0 ; i < Start; i++)
				{
					if(ROG_SsGetOrigin(ScanOri)) 
						Create_Crystal(ScanOri)
				}
			}
		}
	}
}

public Part2(Param[])
{
	static id, Attacker, FirstZombie, Evolved, Respawn
	id = Param[0]
	Attacker = Param[1]
	FirstZombie = Param[2]
	Evolved = Param[3]
	Respawn = Param[4]
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 2", id)
	
	// Clear Data
	set_pdata_int(id, m_iRadiosLeft, 0, OFFSET_PLAYER_LINUX)
	Set_Scoreboard_Attrib(id, 0)

	// Set Classic Info
	g_MyCSTeam[id] = CS_TEAM_T
}

public Part3(Param[])
{
	static id, Attacker, FirstZombie, Evolved, Respawn
	id = Param[0]
	Attacker = Param[1]
	FirstZombie = Param[2]
	Evolved = Param[3]
	Respawn = Param[4]
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 3", id)
	
	// Health Setting
	static StartHealth; StartHealth = g_MaxHealth[id]
	static ScreamSound[64]
	
	if(FirstZombie)
	{
		g_Evolution[id] = 0.0
		g_PlayerLevel[id] = 2
		
		static TotalPlayer; TotalPlayer = Get_TotalInPlayer(1)
		static ZombieNumber; ZombieNumber = Get_ServerZombie()
		
		StartHealth = clamp((TotalPlayer / ZombieNumber) * 1000, get_pcvar_num(g_Cvar_Zombie_HPRanMin), get_pcvar_num(g_Cvar_Zombie_HPRanMax))
		
		if(!Get_BitVar(g_IsFemale, id)) ArrayGetString(Ar_S_InfectionMale, Get_RandomArray(Ar_S_InfectionMale), ScreamSound, 63)
		else ArrayGetString(Ar_S_InfectionFemale, Get_RandomArray(Ar_S_InfectionFemale), ScreamSound, 63)
		EmitSound(id, CHAN_VOICE, ScreamSound)
		
		Set_BitVar(g_FirstZombie, id)
		ZEVO_TeamSet(id, CS_TEAM_T)
	} else {
		if(Respawn)
		{
			g_PlayerLevel[id] = Param[5]
			StartHealth = clamp((StartHealth / 100) * (100 - get_pcvar_num(g_Cvar_Zombie_RPHPRedc)), get_pcvar_num(g_Cvar_Zombie_HPMin), get_pcvar_num(g_Cvar_Zombie_HPMax))
			
			PlaySound(id, Ar2_S_Revived)
			ZEVO_TeamSet(id, CS_TEAM_T)
		} else {
			g_Evolution[id] = 0.0
			
			if(Evolved)
			{
				g_PlayerLevel[id] = 2
				
				static TotalPlayer; TotalPlayer = Get_TotalInPlayer(1)
				static ZombieNumber; ZombieNumber = Get_PlayerCount(1, 1)
		
				StartHealth = clamp((TotalPlayer / ZombieNumber) * 1000, get_pcvar_num(g_Cvar_Zombie_HPRanMin), get_pcvar_num(g_Cvar_Zombie_HPRanMax))
			} else {
				g_PlayerLevel[id] = 1
				
				if(is_connected(Attacker)) 
				{
					static Float:TargetHealth; 
					TargetHealth = float(g_MaxHealth[Attacker]) / 1.3
					StartHealth = clamp(floatround(TargetHealth), get_pcvar_num(g_Cvar_Zombie_HPMin), get_pcvar_num(g_Cvar_Zombie_HPMax))
				} else {
					static TotalPlayer; TotalPlayer = Get_TotalInPlayer(1)
					static ZombieNumber; ZombieNumber = Get_PlayerCount(1, 1)
					
					StartHealth = clamp((TotalPlayer / ZombieNumber) * 1000, get_pcvar_num(g_Cvar_Zombie_HPRanMin), get_pcvar_num(g_Cvar_Zombie_HPRanMax))
				}
			}
			
			if(!Get_BitVar(g_IsFemale, id)) ArrayGetString(Ar_S_InfectionMale, Get_RandomArray(Ar_S_InfectionMale), ScreamSound, 63)
			else ArrayGetString(Ar_S_InfectionFemale, Get_RandomArray(Ar_S_InfectionFemale), ScreamSound, 63)
			EmitSound(id, CHAN_VOICE, ScreamSound)
		}
	}
	
	g_MaxHealth[id] = StartHealth
	Set_PlayerHealth(id, StartHealth, 1)
	
	static String[96]
	formatex(String, sizeof(String), "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_ZOMBIE", StartHealth)
	IG_ClientPrintColor(id, String)
}

public Part4(Param[])
{
	static id, Attacker, FirstZombie, Evolved, Respawn
	id = Param[0]
	Attacker = Param[1]
	FirstZombie = Param[2]
	Evolved = Param[3]
	Respawn = Param[4]
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 4", id)
	
	UndeadTime[id] = get_gametime() + 1.5
	cs_set_user_armor(id, 100, CS_ARMOR_KEVLAR)
	
	ZEVO_SpeedSet(id, ArrayGetCell(Ar_ZombieSpeed, g_ZombieClass[id]), 1)
	set_pev(id, pev_gravity, ArrayGetCell(Ar_ZombieGravity, g_ZombieClass[id]))

	static PlayerModel[40]
	if(g_PlayerLevel[id] >= 2) ArrayGetString(Ar_ZombieModel_Origin, g_ZombieClass[id], PlayerModel, sizeof(PlayerModel))
	else ArrayGetString(Ar_ZombieModel_Host, g_ZombieClass[id], PlayerModel, sizeof(PlayerModel))
	ZEVO_ModelSet(id, PlayerModel, 1)
}

public Part5(Param[])
{
	static id, Attacker, FirstZombie, Evolved, Respawn
	id = Param[0]
	Attacker = Param[1]
	FirstZombie = Param[2]
	Evolved = Param[3]
	Respawn = Param[4]

	Thanatos_GameLog("Game: Make Zombie Stage (%i) 5", id)
	
	// Bug Fix
	IG_3rdView(id, 0)
	cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
	set_user_rendering(id)
	
	static MSG; if(!MSG) MSG = get_user_msgid("SetFOV")
	message_begin(MSG_ONE_UNRELIABLE, MSG, {0,0,0}, id)
	write_byte(90)
	message_end()
}

public Part6(Param[])
{
	static id, Attacker, FirstZombie, Evolved, Respawn
	id = Param[0]
	Attacker = Param[1]
	FirstZombie = Param[2]
	Evolved = Param[3]
	Respawn = Param[4]

	Thanatos_GameLog("Game: Make Zombie Stage (%i) 6", id)
	
// Strip zombies from guns and give them a knife
	strip_user_weapons(id)
	
	if(!Respawn)
	{
		give_item(id, "weapon_hegrenade")
		give_item(id, "weapon_flashbang")
	} else {
		give_item(id, "weapon_hegrenade")
	}
	
	give_item(id, "weapon_knife")
	
}

public Part7(Param[])
{
	static id, Attacker, FirstZombie, Evolved, Respawn
	id = Param[0]
	Attacker = Param[1]
	FirstZombie = Param[2]
	Evolved = Param[3]
	Respawn = Param[4]
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 7", id)
	
	// Play Draw Animation
	if(!Respawn)
	{
		engclient_cmd(id, "weapon_knife")
		set_pev(id, pev_viewmodel2, Ar2_S_InfectionModel)
		Set_Player_NextAttack(id, 2.0)
		Set_WeaponAnim(id, 0)
	
		remove_task(id+TASK_RESETCLAW)
		set_task(1.5, "Nani_Koreha", id+TASK_RESETCLAW)
	} else {
		Set_Player_NextAttack(id, 0.75)
		set_weapons_timeidle(id, CSW_KNIFE, 1.0)
		Set_WeaponAnim(id, 3)
		
		remove_task(id+TASK_RESETCLAW)
	}
}

public Part8(Param[])
{
	static id, Attacker, FirstZombie, Evolved, Respawn
	id = Param[0]
	Attacker = Param[1]
	FirstZombie = Param[2]
	Evolved = Param[3]
	Respawn = Param[4]
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 8", id)

// Set NVG & Flashlight
	Set_PlayerNVG(id, 1, 1, 0, 1)
	if(pev(id, pev_effects) & EF_DIMLIGHT) set_pev(id, pev_impulse, 100)
	else set_pev(id, pev_impulse, 0)	
	
	// Effect
	static Float:Origin[3]; pev(id, pev_origin, Origin); Origin[2] += 16.0
	Infection_Effect(id, Origin)
	
	// Show Info
	set_dhudmessage(255, 170, 0, HUD_NOTICE2_X, HUD_NOTICE2_Y, 2, 4.0, 4.0, 0.05, 1.0)
	show_dhudmessage(id, "%L", GAME_LANG, "NOTICE_INFECTED")
	
	static String[96]
	formatex(String, sizeof(String), "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_REMINDZBCLASS")
	IG_ClientPrintColor(id, String)
	
	Thanatos_GameLog("Game: Make Zombie Stage (%i) 10", id)
	
	// Auto Zombie
	remove_task(id+TASK_AUTOSKILL)
	if(is_user_bot(id)) set_task(random_float(3.5, 10.0), "Bot_AutoSkill", id+TASK_AUTOSKILL, _, _, "b")
	
}*/

public Bot_AutoSkill(id)
{
	id -= TASK_AUTOSKILL
	
	if(!is_alive(id))
		return
	if(!is_user_bot(id))
	{
		remove_task(id+TASK_AUTOSKILL)
		return
	}
	if(g_PlayerType[id] != PLAYER_ZOMBIE)
		return
		
	if(g_PlayerLevel[id] > 1) 
	{
		if(random_num(0, 1) == 1)ExecuteForward(g_Forwards[FWD_ZOMBIESKILL], g_fwResult, id, g_ZombieClass[id], SKILL_F)
		else ExecuteForward(g_Forwards[FWD_ZOMBIESKILL], g_fwResult, id, g_ZombieClass[id], SKILL_G)
	} else ExecuteForward(g_Forwards[FWD_ZOMBIESKILL], g_fwResult, id, g_ZombieClass[id], SKILL_G)
}

public Set_PlayerSidekick(id)
{
	Thanatos_GameLog("Game: Become Sidekick (%i)", id)
	
	g_SubType[id] = HUMAN_SIDEKICK
	
	// Hud
	set_dhudmessage(255, 170, 0, HUD_NOTICE_X, HUD_NOTICE_Y, 2, 3.0, 3.0, 0.0, 1.0)
	show_dhudmessage(id, "%L", GAME_LANG, "NOTICE_SIDEKICK")
	
	// Weapon
	if(!is_user_bot(id)) Open_Special_WeaponMenu(id, HUMAN_SIDEKICK)
	else Random_SpecialWeapon(id, HUMAN_SIDEKICK)
}

public Ent_SpawnRandom(id)
{
	if (!g_PlayerSpawn_Count)
		return;	
	
	static hull, sp_index, i
	
	hull = HULL_HUMAN
	sp_index = random_num(0, g_PlayerSpawn_Count - 1)
	
	for (i = sp_index + 1; /*no condition*/; i++)
	{
		if(i >= g_PlayerSpawn_Count) i = 0
		
		if(is_hull_vacant(g_PlayerSpawn_Point[i], hull))
		{
			engfunc(EngFunc_SetOrigin, id, g_PlayerSpawn_Point[i])
			break
		}

		if (i == sp_index) break
	}
}

public Zombie_Evolution(id)
{
	if(g_PlayerLevel[id] > 2 || g_PlayerLevel[id] < 1)
		return
	if(g_Evolution[id] < 10.0)
		return
		
	Thanatos_GameLog("Client: Evolution (%i)", id)
	
	g_Evolution[id] = g_PlayerLevel[id] < 3 ? 0.0 : 10.0
	if(g_PlayerLevel[id] < 3) g_PlayerLevel[id]++
	
	static NewHealth, NewArmor
	if(g_PlayerLevel[id] == 2) 
	{
		NewHealth = clamp(get_pcvar_num(g_Cvar_Zombie_HPLV2), get_pcvar_num(g_Cvar_Zombie_HPMin), get_pcvar_num(g_Cvar_Zombie_HPMax))
		NewArmor = 200
	} else if(g_PlayerLevel[id] == 3) {
		NewHealth = clamp(get_pcvar_num(g_Cvar_Zombie_HPLV3), get_pcvar_num(g_Cvar_Zombie_HPMin), get_pcvar_num(g_Cvar_Zombie_HPMax))
		NewArmor = 500
	}

	// Update Health & Armor
	Set_PlayerHealth(id, NewHealth, 1)
	cs_set_user_armor(id, NewArmor, CS_ARMOR_KEVLAR)
	
	// Model
	static PlayerModel[40]
	ArrayGetString(Ar_ZombieModel_Origin, g_ZombieClass[id], PlayerModel, sizeof(PlayerModel))
	ZEVO_ModelSet(id, PlayerModel, 1)
	
	// Play Evolution Sound
	EmitSound(id, CHAN_STATIC, Ar2_S_Evolution)
	
	// Reset Claws
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_KNIFE)
	if(pev_valid(Ent)) fw_Item_Deploy_Post(Ent)
	
	// Show Hud
	set_dhudmessage(85, 255, 85, HUD_NOTICE2_X, HUD_NOTICE2_Y, 2, 4.0, 4.0, 0.05, 1.0)
	show_dhudmessage(id, "%L", GAME_LANG, "NOTICE_EVOLVED", g_PlayerLevel[id])
	
	// Exec Forward
	ExecuteForward(g_Forwards[FWD_LEVELUP], g_fwResult, id, g_PlayerLevel[id], 1)
	set_task(0.1, "Recheck_Evol", id)
}

public Recheck_Evol(id) Thanatos_GameLog("Client: Evolution [POST] (%i)", id)

public Human_LevelUp(id)
{
	if(g_PlayerLevel[id] >= MAX_HUMAN_LEVEL)
		return
		
	Thanatos_GameLog("Client: LV UP (%i)", id)
	
	// Up
	g_PlayerLevel[id] = clamp(g_PlayerLevel[id] + 1, 0, MAX_HUMAN_LEVEL)
	
	// Task
	remove_task(id+TASK_LEVELUP)
	set_task(0.1, "Human_LevelUp2", id+TASK_LEVELUP)
}

public Human_LevelUp2(id)
{
	id -= TASK_LEVELUP
	
	if(!is_alive(id))
		return
	if(g_PlayerType[id] != PLAYER_HUMAN)
		return
	
	// Effect
	if(Get_PlayerCount(1, 2) <= 1)
		return
	
	set_dhudmessage(255, 170, 0, HUD_NOTICE_X, HUD_NOTICE_Y, 2, 3.0, 3.0, 0.0, 1.0)
	show_dhudmessage(id, "%L", GAME_LANG, "NOTICE_ATKUP", 100 + (10 * g_PlayerLevel[id]))
	
	PlaySound(id, Ar2_S_StageBoost)
	
	// Exec Forward
	ExecuteForward(g_Forwards[FWD_LEVELUP], g_fwResult, id, g_PlayerLevel[id], 0)	
	
	Thanatos_GameLog("Client: LEVEL UP [POST] (%i)", id)
}

public Handle_BugFix(id)
{
	Thanatos_GameLog("Client: Make Zombie [POST] (%i)", id)
	
	// Hud
	static Transcript[64]
	formatex(Transcript, 23, "TRANSCRIPT_ZOMBIE%i", random_num(1, 3))
	
	set_hudmessage(255, 42, 42, HUD_NOTICE_X, HUD_NOTICE_Y, 0, 4.0, 4.0, 0.05, 1.0)
	ShowSyncHudMsg(id, g_Hud_Notice, "%L", GAME_LANG, Transcript)
	
	// Team
	ZEVO_TeamSet(id, CS_TEAM_T)
	//Check_Gameplay()
}

public Nani_Koreha(id)
{
	id -= TASK_RESETCLAW
	
	if(!is_alive(id))
		return
	if(g_PlayerType[id] != PLAYER_ZOMBIE)
		return
		
	Set_ZombieClaw(id)
		
	if(get_gametime() - 0.25 > NoticeSound_Delay)
	{
		static Sound[64]; ArrayGetString(Ar_S_ZombieAppear, Get_RandomArray(Ar_S_ZombieAppear), Sound, 63)
		PlaySound(0, Sound)
		
		NoticeSound_Delay = get_gametime()
	}
	
	Thanatos_GameLog("Client: Knief Activate (%i)", id)
}

public Infection_Effect(id, Float:Origin[3])
{
	// Blood
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_BLOODSPRITE)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(m_iBlood[1])
	write_short(m_iBlood[0])
	write_byte(75)
	write_byte(5)
	message_end()
	
	// Effect
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_SPRITE)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 5.0)
	write_short(g_InfectionEffect_SprID)
	write_byte(8)
	write_byte(255)
	message_end()
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin)
	write_byte(TE_DLIGHT) // TE id
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_byte(10) // radius
	write_byte(0) // r
	write_byte(85) // g
	write_byte(255) // b
	write_byte(2) // life
	write_byte(0) // decay rate
	message_end()
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin)
	write_byte(TE_PARTICLEBURST) // TE id
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(25) // radius
	write_byte(70) // color
	write_byte(3) // duration (will be randomized a bit)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenShake, _, id)
	write_short(UNIT_SECOND*4) // amplitude
	write_short(UNIT_SECOND*2) // duration
	write_short(UNIT_SECOND*10) // frequency
	message_end()
}

public Set_PlayerHealth(id, Health, FullHealth)
{
	set_user_health(id, Health)
	if(FullHealth) 
	{
		g_MaxHealth[id] = Health
		set_pev(id, pev_max_health, float(Health))
	}
}

public Set_Scoreboard_Attrib(id, Attrib) // 0 - Nothing; 1 - Dead; 2 - VIP
{
	message_begin(MSG_BROADCAST, g_MsgScoreAttrib)
	write_byte(id) // id
	switch(Attrib)
	{
		case 1: write_byte(1<<0)
		case 2: write_byte(1<<2)
		default: write_byte(0)
	}
	message_end()	
}
public Set_LightStart(id) SetPlayerLight(id, g_GameLight)
public Spawn_PlayerRandom(id)
{
	if (!g_PlayerSpawn_Count)
		return;	
	
	static hull, sp_index, i
	
	hull = (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN
	sp_index = random_num(0, g_PlayerSpawn_Count - 1)
	
	for (i = sp_index + 1; /*no condition*/; i++)
	{
		if(i >= g_PlayerSpawn_Count) i = 0
		
		if(is_hull_vacant(g_PlayerSpawn_Point[i], hull))
		{
			engfunc(EngFunc_SetOrigin, id, g_PlayerSpawn_Point[i])
			break
		}

		if (i == sp_index) break
	}
}

public Set_PlayerNVG(id, Give, On, OnSound, Ignored_HadNVG)
{
	if(Give) Set_BitVar(g_Has_NightVision, id)
	set_user_nightvision(id, On, OnSound, Ignored_HadNVG)
}

public set_user_nightvision(id, On, OnSound, Ignored_HadNVG)
{
	if(!Ignored_HadNVG)
	{
		if(!Get_BitVar(g_Has_NightVision, id))
			return
	}

	if(On) Set_BitVar(g_UsingNVG, id)
	else UnSet_BitVar(g_UsingNVG, id)
	
	if(OnSound) PlaySound(id, SoundNVG[On])
	set_user_nvision(id)
	
	ExecuteForward(g_Forwards[FWD_USER_NVG], g_fwResult, id, On, g_PlayerType[id] == PLAYER_ZOMBIE ? 1 : 0)
	
	return
}

public set_user_nvision(id)
{	
	static Alpha
	if(Get_BitVar(g_UsingNVG, id)) Alpha = g_NVG_Alpha
	else Alpha = 0
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
	write_short(0) // duration
	write_short(0) // hold time
	write_short(0x0004) // fade type
	if(g_PlayerType[id] == PLAYER_HUMAN)
	{
		write_byte(g_NVG_HumanColor[0]) // r
		write_byte(g_NVG_HumanColor[1]) // g
		write_byte(g_NVG_HumanColor[2]) // b
	} else {
		write_byte(g_NVG_ZombieColor[0]) // r
		write_byte(g_NVG_ZombieColor[1]) // g
		write_byte(g_NVG_ZombieColor[2]) // b
	}
	write_byte(Alpha) // alpha
	message_end()
	
	if(Get_BitVar(g_UsingNVG, id)) SetPlayerLight(id, "#")
	else SetPlayerLight(id, g_GameLight)
}

public Reset_Player(id, NewPlayer)
{
	if(NewPlayer)
	{
		UnSet_BitVar(g_IsFemale, id)
		
		g_ZombieClass[id] = -1
		g_NextClass[id] = -1
		g_MyCSTeam[id] = CS_TEAM_UNASSIGNED
		
		for(new i = 0; i < g_ItemCount; i++)
			g_Unlocked[id][i] = 0
			
		g_MyMoney[id] = START_MONEY
	} else {
		
	}
	
	UnSet_BitVar(g_UsingSkill, id)
	UnSet_BitVar(g_IsRealHero, id)
	UnSet_BitVar(g_FirstZombie, id)
	g_MenuSelecting[id] = 0
	g_SpecWeapon[id][0] = g_SpecWeapon[id][1] = -1
	
	remove_task(id+TASK_REVIVE)
	remove_task(id+TASK_RESETCLAW)
	remove_task(id+TASK_AUTOSKILL)

	g_PlayerType[id] = PLAYER_HUMAN;
	g_PlayerLevel[id] = 0;
	g_SubType[id] = HUMAN_NORMAL;
	UnSet_BitVar(g_Has_NightVision, id)
	UnSet_BitVar(g_UsingNVG, id)
	UnSet_BitVar(g_PermDeath, id)
	
	if(is_connected(id))
	{
		for(new i = 0; i < g_SWpnCount; i++)
			ExecuteForward(g_Forwards[FWD_SWPN_REMOVE], g_fwResult, id, i)
	}
}

public Game_Ending(Float:EndTime, RoundDraw, CsTeams:Team)
// RoundDraw: Draw or Team Win
// Team: 1 - T | 2 - CT
{
	if(g_GameEnd) return
	
	Thanatos_GameLog("Client: Force Game End")
	
	remove_task(TASK_TRANSCRIPT)
	remove_task(TASK_COUNTDOWN)
	remove_task(TASK_GAMEPLAY)
	remove_task(TASK_SUPPLYBOX)
	
	if(RoundDraw) 
	{
		IG_TerminateRound(WIN_DRAW, EndTime, 0)
		ExecuteForward(g_Forwards[FWD_GAME_END], g_fwResult, TEAM_NONE)
		
		client_print(0, print_center, "%L", GAME_LANG, "NOTICE_GAMESTART")
	} else {
		new Sound[64];
		if(Team == CS_TEAM_T) 
		{
			g_Round++
			g_TeamScore[TEAM_ZOMBIE]++
			
			IG_TerminateRound(WIN_TERRORIST, EndTime, 0)
			
			ArrayGetString(Ar_S_WinZombie, Get_RandomArray(Ar_S_WinZombie), Sound, sizeof(Sound))
			PlaySound(0, Sound)
			
			Show_WinHUD(CS_TEAM_T, EndTime)
			ExecuteForward(g_Forwards[FWD_GAME_END], g_fwResult, TEAM_ZOMBIE)
		} else if(Team == CS_TEAM_CT) {
			g_Round++
			g_TeamScore[TEAM_HUMAN]++
			
			IG_TerminateRound(WIN_CT, EndTime, 0)
			
			ArrayGetString(Ar_S_WinHuman, Get_RandomArray(Ar_S_WinHuman), Sound, sizeof(Sound))
			PlaySound(0, Sound)
			
			Show_WinHUD(CS_TEAM_CT, EndTime)
			ExecuteForward(g_Forwards[FWD_GAME_END], g_fwResult, TEAM_HUMAN)
		}
	}
	
	g_GameEnd = 1
}

public Show_WinHUD(CsTeams:WinTeam, Float:EndTime)
{
	switch(get_pcvar_num(g_Cvar_WinHud))
	{
		case 1:
		{
			if(WinTeam == CS_TEAM_T) 
			{
				set_dhudmessage(200, 0, 0, HUD_WIN_X, HUD_WIN_Y, 0, EndTime, EndTime, 0.0, 1.5)
				show_dhudmessage(0, "%L", GAME_LANG, "HUD_WIN_ZOMBIE")
			} else if(WinTeam == CS_TEAM_CT) {
				set_dhudmessage(0, 200, 0, HUD_WIN_X, HUD_WIN_Y, 0, EndTime, EndTime, 0.0, 1.5)
				show_dhudmessage(0, "%L", GAME_LANG, "HUD_WIN_HUMAN")
			}
		}
		case 2:
		{
			static Title[32], Motd[80]
			if(WinTeam == CS_TEAM_T) 
			{
				formatex(Title, sizeof(Title), "%L", GAME_LANG, "HUD_WIN_ZOMBIE")
				formatex(Motd, sizeof(Motd), "zombie_evolution/MOTD/MOTD_WINZOMBIE.txt")
			} else if(WinTeam == CS_TEAM_CT) {
				formatex(Title, sizeof(Title), "%L", GAME_LANG, "HUD_WIN_HUMAN")
				formatex(Motd, sizeof(Motd), "zombie_evolution/MOTD/MOTD_WINHUMAN.txt")
			}
			
			show_motd(0, Motd, Title)
		}
	}
}

public give_ammo(id, silent, CSWID)
{
	static Amount, Name[32]
		
	switch(CSWID)
	{
		case CSW_P228: {Amount = 13; formatex(Name, sizeof(Name), "357sig");}
		case CSW_SCOUT: {Amount = 30; formatex(Name, sizeof(Name), "762nato");}
		case CSW_XM1014: {Amount = 8; formatex(Name, sizeof(Name), "buckshot");}
		case CSW_MAC10: {Amount = 12; formatex(Name, sizeof(Name), "45acp");}
		case CSW_AUG: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_ELITE: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_FIVESEVEN: {Amount = 50; formatex(Name, sizeof(Name), "57mm");}
		case CSW_UMP45: {Amount = 12; formatex(Name, sizeof(Name), "45acp");}
		case CSW_SG550: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_GALIL: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_FAMAS: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_USP: {Amount = 12; formatex(Name, sizeof(Name), "45acp");}
		case CSW_GLOCK18: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_AWP: {Amount = 10; formatex(Name, sizeof(Name), "338magnum");}
		case CSW_MP5NAVY: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_M249: {Amount = 30; formatex(Name, sizeof(Name), "556natobox");}
		case CSW_M3: {Amount = 8; formatex(Name, sizeof(Name), "buckshot");}
		case CSW_M4A1: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_TMP: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_G3SG1: {Amount = 30; formatex(Name, sizeof(Name), "762nato");}
		case CSW_DEAGLE: {Amount = 7; formatex(Name, sizeof(Name), "50ae");}
		case CSW_SG552: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_AK47: {Amount = 30; formatex(Name, sizeof(Name), "762nato");}
		case CSW_P90: {Amount = 50; formatex(Name, sizeof(Name), "57mm");}
	}
	
	if(!silent) emit_sound(id, CHAN_ITEM, "items/9mmclip1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	ExecuteHamB(Ham_GiveAmmo, id, Amount, Name, 254)
}

public CMD_NightVision(id)
{
	if(!Get_BitVar(g_Has_NightVision, id))
		return PLUGIN_HANDLED

	if(!Get_BitVar(g_UsingNVG, id)) set_user_nightvision(id, 1, 1, 0)
	else set_user_nightvision(id, 0, 1, 0)
	
	return PLUGIN_HANDLED;
}

public CMD_Drop(id)
{
	if(!is_alive(id))
		return PLUGIN_CONTINUE
	if(g_PlayerType[id] == PLAYER_ZOMBIE && g_SubType[id] == ZOMBIE_NORMAL)
	{
		if(UndeadTime[id] <= get_gametime()) ExecuteForward(g_Forwards[FWD_ZOMBIESKILL], g_fwResult, id, g_ZombieClass[id], SKILL_G)
		return PLUGIN_HANDLED
	}
	if(g_PlayerType[id] == PLAYER_HUMAN && g_SubType[id] == HUMAN_HERO && Get_BitVar(g_IsRealHero, id))
		return PLUGIN_HANDLED
		
	return PLUGIN_CONTINUE
}

public CMD_Radio(id)
{
	if(!is_alive(id))
		return PLUGIN_CONTINUE
	if(g_PlayerType[id] != PLAYER_HUMAN)
		return PLUGIN_HANDLED
		
	return PLUGIN_CONTINUE
}

public CMD_JoinTeam(id)
{
	if(!Get_BitVar(g_Joined, id))
		return PLUGIN_CONTINUE
		
	Open_GameMenu(id)
		
	return PLUGIN_HANDLED
}

public Message_StatusIcon(msg_id, msg_dest, msg_entity)
{
	static szMsg[8];
	get_msg_arg_string(2, szMsg ,7)
	
	if(equal(szMsg, "buyzone") && get_msg_arg_int(1))
	{
		if(pev_valid(msg_entity) != PDATA_SAFE)
			return  PLUGIN_CONTINUE;
	
		set_pdata_int(msg_entity, 235, get_pdata_int(msg_entity, 235) & ~(1<<0))
		//return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public Message_TeamScore()
{
	static Team[2]
	get_msg_arg_string(1, Team, charsmax(Team))
	
	switch(Team[0])
	{
		case 'C': set_msg_arg_int(2, get_msg_argtype(2), g_TeamScore[TEAM_HUMAN])
		case 'T': set_msg_arg_int(2, get_msg_argtype(2), g_TeamScore[TEAM_ZOMBIE])
	}
}

public Message_Health(msg_id, msg_dest, id)
{
	// Get player's health
	static health; health = get_user_health(id)
	
	// Don't bother
	if(health < 1) 
		return
	
	static Float:NewHealth, RealHealth, Health
	
	NewHealth = (float(health) / float(g_MaxHealth[id])) * 100.0; 
	RealHealth = floatround(NewHealth)
	Health = clamp(RealHealth, 1, 255)
	
	set_msg_arg_int(1, get_msg_argtype(1), Health)
}

public Message_ClCorpse()
{
	static id; id = get_msg_arg_int(12)
	//set_msg_arg_string(1, g_CustomPlayerModel[id])
	
	if(g_PlayerType[id] == PLAYER_ZOMBIE && !Get_BitVar(g_PermDeath, id))
		return PLUGIN_HANDLED
		
	return PLUGIN_CONTINUE
}

public Message_Money(msg_id, msg_dest, id)
{
	if(!is_connected(id))
		return
		
	set_msg_arg_int(1, get_msg_argtype(1), g_MyMoney[id])
}

public get_player_sex(id)
{
	if(!is_connected(id))
		return 0	
	if(Get_BitVar(g_IsFemale, id))
		return PLAYER_FEMALE
		
	return PLAYER_MALE
}

public Open_GameMenu(id)
{
	static LangText[64]; formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "MENU_GAME_NAME")
	static Menu; Menu = menu_create(LangText, "MenuHandle_GameMenu")
	
	// 1. Equipment
	formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "MENU_GAME_EQUIP")
	menu_additem(Menu, LangText, "equip")
	
	// 2. Items Merchant
	formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "MENU_GAME_ITEM")
	menu_additem(Menu, LangText, "item")
	
	// 3. Zombie Class
	formatex(LangText, sizeof(LangText), "%L", GAME_LANG, "MENU_GAME_CLASS")
	menu_additem(Menu, LangText, "zbclass")
	
	// 4. Player Enhancement
	formatex(LangText, sizeof(LangText), "\d%L", GAME_LANG, "MENU_GAME_ENHANCE")
	menu_additem(Menu, LangText, "enhance")
	
	// 5. Help
	formatex(LangText, sizeof(LangText), "%L^n", GAME_LANG, "MENU_GAME_HELP")
	menu_additem(Menu, LangText, "help")
	
	// 6. Thanatos
	formatex(LangText, sizeof(LangText), "\d%L", GAME_LANG, "MENU_GAME_THANATOS")
	menu_additem(Menu, LangText, "thanatos")
	
	menu_setprop(Menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, Menu)
}

public MenuHandle_GameMenu(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	if(!is_connected(id))
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}

	static Name[64], Data[16], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)

	if(equal(Data, "equip"))
	{
		if(g_PlayerType[id] == PLAYER_HUMAN) ExecuteForward(g_Forwards[FWD_EQUIP], g_fwResult, id)
	} else if(equal(Data, "item")) {
		Open_ItemMerchant(id)
	} else if(equal(Data, "zbclass")) {
		Open_MenuClass(id)
	} else if(equal(Data, "enhance")) {
		
	} else if(equal(Data, "help")) {
		Open_MenuHelp(id)
	} else if(equal(Data, "thanatos")) {
		
	}
	
	menu_destroy(Menu)
	return PLUGIN_CONTINUE
}

public Open_ItemMerchant(id)
{
	static ItemName[32], ItemTitle[64], ItemCost, ItemType
	static MenuTitle[64], MyTeam, MyMoney, ItemID[4]
	
	formatex(MenuTitle, 63, "%L", GAME_LANG, "MENU_ITEM_NAME")
	static Menu; Menu = menu_create(MenuTitle, "MenuHandle_Item")
	
	MyTeam = Get_PlayerTeam(id)
	MyMoney = cs_get_user_money(id)
	
	for(new i = 0; i < g_ItemCount; i++)
	{
		if(ArrayGetCell(Ar_ItemTeam, i) != MyTeam)
			continue
			
		ArrayGetString(Ar_ItemName, i, ItemName, 31)
		ItemCost = ArrayGetCell(Ar_ItemCost, i)
		ItemType = ArrayGetCell(Ar_ItemType, i)
		
		switch(ItemType)
		{
			case ITEM_ROUND: 
			{
				if(g_Unlocked[id][i]) formatex(ItemTitle, 63, "\d%s", ItemName)
				else {
					if(ItemCost)
					{
						if(MyMoney >= ItemCost) formatex(ItemTitle, 63, "%s \y($%i/Round)\w", ItemName, ItemCost)
						else formatex(ItemTitle, 63, "\d%s \r($%i/Round)\w", ItemName, ItemCost)
					} else formatex(ItemTitle, 63, "%s", ItemName, ItemCost)
				}
			}
			case ITEM_MAP:
			{
				if(g_Unlocked[id][i]) formatex(ItemTitle, 63, "\d%s", ItemName)
				else {
					if(ItemCost)
					{
						if(MyMoney >= ItemCost) formatex(ItemTitle, 63, "%s \y($%i/Unlimited)\w", ItemName, ItemCost)
						else formatex(ItemTitle, 63, "\d%s \r($%i/Unlimited)\w", ItemName, ItemCost)
					} else formatex(ItemTitle, 63, "%s", ItemName, ItemCost)
				}
			}
			default:
			{
				if(ItemCost)
				{
					if(MyMoney >= ItemCost) formatex(ItemTitle, 63, "%s \y($%i)\w", ItemName, ItemCost)
					else formatex(ItemTitle, 63, "\d%s \r($%i)\w", ItemName, ItemCost)
				} else formatex(ItemTitle, 63, "%s", ItemName, ItemCost)
			}
		}
		
		num_to_str(i, ItemID, 3)
		menu_additem(Menu, ItemTitle, ItemID)
	}
	
	menu_display(id, Menu)
}

public MenuHandle_Item(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	if(!is_alive(id))
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	
	static Name[64], Data[4], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)

	static Item; Item = str_to_num(Data)
	
	static ItemName[32], ItemTeam, ItemCost, ItemType
	static MyTeam, MyMoney
	
	MyTeam = Get_PlayerTeam(id)
	MyMoney = cs_get_user_money(id)
	
	ArrayGetString(Ar_ItemName, Item, ItemName, 31)
	ItemTeam = ArrayGetCell(Ar_ItemTeam, Item)
	ItemCost = ArrayGetCell(Ar_ItemCost, Item)
	ItemType = ArrayGetCell(Ar_ItemType, Item)
	
	if(ItemTeam != MyTeam)
	{
		menu_destroy(Menu)
		Open_ItemMerchant(id)
		
		return PLUGIN_CONTINUE
	}
	
	switch(ItemType)
	{
		case ITEM_ROUND: 
		{
			if(g_Unlocked[id][Item]) 
			{
				ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_ITEMALREADY", ItemName)
					
				menu_destroy(Menu)
				Open_ItemMerchant(id)
				
				return PLUGIN_CONTINUE
			} else {
				if(ItemCost)
				{
					if(MyMoney >= ItemCost) 
					{
						g_Unlocked[id][Item] = 1
						PlaySound(id, Ar2_S_Pickup)
						ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_ITEMBUY", ItemName, ItemCost)
					
						cs_set_user_money(id, MyMoney - ItemCost)
						ItemMerchant_Deliver(id, Item)
					} else {
						ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_MONEYREQ", ItemCost, ItemName)
					
						menu_destroy(Menu)
						Open_ItemMerchant(id)
						
						return PLUGIN_CONTINUE
					} 
				} else {
					PlaySound(id, Ar2_S_Pickup)
					ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_ITEMFREE", ItemName)
					
					ItemMerchant_Deliver(id, Item)
				}
			}
		}
		case ITEM_MAP:
		{
			if(g_Unlocked[id][Item]) 
			{
				ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_ITEMALREADY", ItemName)
					
				menu_destroy(Menu)
				Open_ItemMerchant(id)
				
				return PLUGIN_CONTINUE
			} else {
				if(ItemCost)
				{
					if(MyMoney >= ItemCost) 
					{
						g_Unlocked[id][Item] = 1
						PlaySound(id, Ar2_S_Pickup)
						ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_ITEMBUY", ItemName, ItemCost)
					
						cs_set_user_money(id, MyMoney - ItemCost)
						ItemMerchant_Deliver(id, Item)
					} else {
						ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_MONEYREQ", ItemCost, ItemName)
					
						menu_destroy(Menu)
						Open_ItemMerchant(id)
						
						return PLUGIN_CONTINUE
					} 
				} else {
					PlaySound(id, Ar2_S_Pickup)
					ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_ITEMFREE", ItemName)
					
					ItemMerchant_Deliver(id, Item)
				}
			}
		}
		default:
		{
			if(ItemCost)
			{
				if(MyMoney >= ItemCost)
				{
					PlaySound(id, Ar2_S_Pickup)
					ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_ITEMBUY", ItemName, ItemCost)
					
					cs_set_user_money(id, MyMoney - ItemCost)
					ItemMerchant_Deliver(id, Item)
				} else {
					ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_MONEYREQ", ItemCost, ItemName)
					
					menu_destroy(Menu)
					Open_ItemMerchant(id)
					
					return PLUGIN_CONTINUE
				}
			} else {
				PlaySound(id, Ar2_S_Pickup)
				ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_ITEMFREE", ItemName)
				
				ItemMerchant_Deliver(id, Item)
			}
		}
	}
	
	menu_destroy(Menu)
	return PLUGIN_CONTINUE
}

public Open_MenuHelp(id)
{
	static MenuTitle[64], ItemTitle[64]
	
	formatex(MenuTitle, 63, "%L", GAME_LANG, "MENU_GAME_HELP")
	static Menu; Menu = menu_create(MenuTitle, "MenuHandle_Help")
	
	// Gameplay
	formatex(ItemTitle, 63, "%L", GAME_LANG, "GAME_HELP_GAMEPLAY")
	menu_additem(Menu, ItemTitle, "gp")
	
	/*
	// Features
	formatex(ItemTitle, 63, "%L", GAME_LANG, "GAME_HELP_FEATURE")
	menu_additem(Menu, ItemTitle, "fe")*/
	
	// Human
	formatex(ItemTitle, 63, "%L", GAME_LANG, "GAME_HELP_HUMAN")
	menu_additem(Menu, ItemTitle, "hm")
	
	// Zombie
	formatex(ItemTitle, 63, "%L", GAME_LANG, "GAME_HELP_ZOMBIE")
	menu_additem(Menu, ItemTitle, "zb")
	
	// Zombie Class
	formatex(ItemTitle, 63, "%L", GAME_LANG, "GAME_HELP_ZOMBIECLASS")
	menu_additem(Menu, ItemTitle, "zbc")
	
	menu_display(id, Menu)
}

public MenuHandle_Help(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		Open_GameMenu(id)
		
		return PLUGIN_HANDLED
	}
	if(!is_connected(id))
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	
	static Name[64], Data[4], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)
	static Motd[80]

	if(equal(Data, "gp"))
	{
		formatex(Name, sizeof(Name), "%L", GAME_LANG, "GAME_HELP_GAMEPLAY")
		formatex(Motd, sizeof(Motd), "zombie_evolution/MOTD/MOTD_GAMEPLAY.txt")
		
		show_motd(id, Motd, Name)
	} else if(equal(Data, "hm")) {
		formatex(Name, sizeof(Name), "%L", GAME_LANG, "GAME_HELP_HUMAN")
		formatex(Motd, sizeof(Motd), "zombie_evolution/MOTD/MOTD_HUMAN.txt")
		
		show_motd(id, Motd, Name)
	} else if(equal(Data, "zb")) {
		formatex(Name, sizeof(Name), "%L", GAME_LANG, "GAME_HELP_ZOMBIE")
		formatex(Motd, sizeof(Motd), "zombie_evolution/MOTD/MOTD_ZOMBIE.txt")
		
		show_motd(id, Motd, Name)
	} else if(equal(Data, "zbc")) {
		Open_MenuHelpZombie(id)
	} 
	
	return PLUGIN_HANDLED
}

public Open_MenuHelpZombie(id)
{
	static MenuTitle[64]
	static ClassName[40], NumID[3]
	
	formatex(MenuTitle, 63, "%L", GAME_LANG, "GAME_HELP_ZOMBIECLASS")
	static Menu; Menu = menu_create(MenuTitle, "MenuHandle_HelpZombie")
	
	for(new i = 0; i < g_ZombieClass_Count; i++)
	{
		ArrayGetString(Ar_ZombieName, i, ClassName, 39)
		num_to_str(ArrayGetCell(Ar_ZombiePermCode, i), NumID, 2)
		
		menu_additem(Menu, ClassName, NumID)
	}
	
	menu_display(id, Menu)
}

public MenuHandle_HelpZombie(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		Open_MenuHelp(id)
		
		return PLUGIN_HANDLED
	}
	if(!is_connected(id))
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	
	static Name[64], Data[4], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)
	static Motd[80]
	
	formatex(Motd, sizeof(Motd), "zombie_evolution/MOTD/MOTD_ZB%s.txt", Data)
	show_motd(id, Motd, Name)
	
	return PLUGIN_HANDLED
}

public ItemMerchant_Deliver(id, Item) ExecuteForward(g_Forwards[FWD_ITEM_ACT], id, Item)

public Open_MenuClass(id)
{
	static ClassName[32], ClassDesc[64]
	static ClassTitle[64], MenuTitle[64], ClassID[4]
	
	formatex(MenuTitle, 63, "%L", GAME_LANG, "MENU_CLASS_NAME")
	static Menu; Menu = menu_create(MenuTitle, "MenuHandle_Class")
	
	for(new i = 0; i < g_ZombieClass_Count; i++)
	{
		ArrayGetString(Ar_ZombieName, i, ClassName, 31)
		ArrayGetString(Ar_ZombieDesc, i, ClassDesc, 65)
		
		if(g_NextClass[id] != -1)
		{
			if(g_NextClass[id] == i) formatex(ClassTitle, 63, "\d%s \y(%s)\w", ClassName, ClassDesc)
			else formatex(ClassTitle, 63, "%s \y(%s)\w", ClassName, ClassDesc)
		} else {
			if(g_ZombieClass[id] == i) formatex(ClassTitle, 63, "\d%s \y(%s)\w", ClassName, ClassDesc)
			else formatex(ClassTitle, 63, "%s \y(%s)\w", ClassName, ClassDesc)
		}
		
		num_to_str(i, ClassID, 3)
		menu_additem(Menu, ClassTitle, ClassID)
	}

	menu_display(id, Menu)
}

public MenuHandle_Class(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	if(!is_connected(id))
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}

	static Name[64], Data[16], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)

	static Class; Class = str_to_num(Data)
	static ClassName[32]; ArrayGetString(Ar_ZombieName, Class, ClassName, 31)
	
	g_NextClass[id] = Class
	ZEVO_ClientPrintColor(id, "!g[%s]!n %L", GameName, GAME_LANG, "GAME_NOTICE_NEXTCLASS", ClassName)
	
	menu_destroy(Menu)
	return PLUGIN_CONTINUE
}

public Thanatos_GameLog(const Message[], any:...)
{
	static Text[128]; vformat(Text, sizeof(Text) - 1, Message, 2)
	server_print("[Thanatos System] Log: %s", Text)
	
	g_LogLine++
	static Url[128]
	
	formatex(Url, 127, "zombie_evolution/log/%s.txt", g_LogName)
	write_file(Url, Text, g_LogLine)
}

public ZEVO_ModelSet(id, const Model[], Modelindex) 
{
	if(equal(Model, "") || strlen(Model) <= 0)
		return
	if(!is_connected(id))
		return
		
	IG_ModelSet(id, Model, Modelindex)
}

public ZEVO_ModelReset(id) 
{
	if(!is_connected(id))
		return
		
	IG_ModelReset(id)
}

public ZEVO_SpeedSet(id, Float:Speed, BlockSpeed)
{
	if(!is_alive(id))
		return
	
	IG_SpeedSet(id, Speed, BlockSpeed)
}

public ZEVO_SpeedReset(id)
{
	if(!is_alive(id))
		return
		
	IG_SpeedReset(id)
}

public ZEVO_TeamSet(id, CsTeams:Team)
{
	if(!is_connected(id))
		return
	if(pev_valid(id) != PDATA_SAFE)
		return
		
	IG_TeamSet(id, Team)
}

public ZEVO_PlayerAttachment(id, const Sprite[], Float:Time, Float:Scale, Float:Framerate) 
{
	IG_PlayerAttachment(id, Sprite, Time, Scale, Framerate)
}
public ZEVO_RoundTime(Minute, Second) 
{
	IG_RoundTime_Set(Minute, Second)
}
public ZEVO_ClientPrintColor(id, const Text[], any:...)
{
	static Text2[256]; vformat(Text2, sizeof(Text2) - 1, Text, 3)
	IG_ClientPrintColor(id, Text2)
}

public ZEVO_3rdView(id, Enable) 
{
	IG_3rdView(id, Enable)
}

stock ZEVO_EmitSound(id, receiver, channel, const sample[], Float:volume, Float:attn, flags, pitch, Float:origin[3] = {0.0,0.0,0.0}) 
{
	IG_EmitSound(id, receiver, channel, sample, volume, attn, flags, pitch, origin)
}

/* ===============================
------------- SAFETY -------------
=================================*/
public Register_SafetyFunc()
{
	register_event("CurWeapon", "Safety_CurWeapon", "be", "1=1")
	
	RegisterHam(Ham_Spawn, "player", "fw_Safety_Spawn_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_Safety_Killed_Post", 1)
}

public Register_SafetyFuncBot(id)
{
	RegisterHamFromEntity(Ham_Spawn, id, "fw_Safety_Spawn_Post", 1)
	RegisterHamFromEntity(Ham_Killed, id, "fw_Safety_Killed_Post", 1)
}

public Safety_Connected(id)
{
	Set_BitVar(g_IsConnected, id)
	UnSet_BitVar(g_IsAlive, id)
	
	g_PlayerWeapon[id] = 0
}

public Safety_Disconnected(id)
{
	UnSet_BitVar(g_IsConnected, id)
	UnSet_BitVar(g_IsAlive, id)
	
	g_PlayerWeapon[id] = 0
}

public Safety_CurWeapon(id)
{
	if(!is_alive(id))
		return
		
	static CSW; CSW = read_data(2)
	if(g_PlayerWeapon[id] != CSW) g_PlayerWeapon[id] = CSW
}

public fw_Safety_Spawn_Post(id)
{
	if(!is_user_alive(id))
		return
		
	Set_BitVar(g_IsAlive, id)
}

public fw_Safety_Killed_Post(id)
{
	UnSet_BitVar(g_IsAlive, id)
}

public is_connected(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0

	return 1
}

public is_alive(id)
{
	if(!is_connected(id))
		return 0
	if(!Get_BitVar(g_IsAlive, id))
		return 0
		
	return 1
}

public get_player_weapon(id)
{
	if(!is_alive(id))
		return 0
	
	return g_PlayerWeapon[id]
}

// ===================== DATA LOAD =======================
// =======================================================
public Load_GameSetting()
{
	// Gameplay
	Setting_Load_String(GAME_SETTINGFILE, "Gameplay", "CRYSTAL_MODEL", Ar2_S_CrystalModel, sizeof(Ar2_S_CrystalModel))
	Setting_Load_String(GAME_SETTINGFILE, "Gameplay", "SUPPLYBOX_MODEL", Ar2_S_SupplyModel, sizeof(Ar2_S_SupplyModel))
	Setting_Load_String(GAME_SETTINGFILE, "Gameplay", "SUPPLYBOX_ICON", Ar2_S_SupplyIcon, sizeof(Ar2_S_SupplyIcon))
	
	// Human
	Setting_Load_StringArray(GAME_SETTINGFILE, "Human", "HUMAN_MODEL_MALE", Ar_HumanModelMale)
	Setting_Load_StringArray(GAME_SETTINGFILE, "Human", "HUMAN_MODEL_FEMALE", Ar_HumanModelFemale)
	Setting_Load_String(GAME_SETTINGFILE, "Human", "HERO_MODEL_MALE", Ar2_S_HeroModelMale, sizeof(Ar2_S_HeroModelMale))
	Setting_Load_String(GAME_SETTINGFILE, "Human", "HERO_MODEL_FEMALE", Ar2_S_HeroModelFemale, sizeof(Ar2_S_HeroModelFemale))
	
	// zombie
	Setting_Load_String(GAME_SETTINGFILE, "Zombie", "INFECTION_MODEL", Ar2_S_InfectionModel, sizeof(Ar2_S_InfectionModel))
	Setting_Load_String(GAME_SETTINGFILE, "Zombie", "INFECTION_EFFECT", Ar2_S_InfectionEffect, sizeof(Ar2_S_InfectionEffect))
	Setting_Load_String(GAME_SETTINGFILE, "Zombie", "DEATH_EFFECT", Ar2_S_DeathEffect, sizeof(Ar2_S_DeathEffect))
	Setting_Load_String(GAME_SETTINGFILE, "Zombie", "RESPAWN_EFFECT", Ar2_S_RespawnEffect, sizeof(Ar2_S_RespawnEffect))
	Setting_Load_String(GAME_SETTINGFILE, "Zombie", "RESPAWNED_HEFFECT", Ar2_S_RevivedEffect, sizeof(Ar2_S_RevivedEffect))
	Setting_Load_String(GAME_SETTINGFILE, "Zombie", "RECOVER_EFFECT", Ar2_S_RecoverEffect, sizeof(Ar2_S_RecoverEffect))
	Setting_Load_String(GAME_SETTINGFILE, "Zombie", "RECOVER_EFFECT2", Ar2_S_RecoverEffect2, sizeof(Ar2_S_RecoverEffect2))
	
	// Sounds
	Setting_Load_StringArray(SOUND_SETTINGFILE, "Gameplay", "START", Ar_S_Start)
	Setting_Load_StringArray(SOUND_SETTINGFILE, "Gameplay", "AMBIENCE", Ar_S_Ambience)
	Setting_Load_String(SOUND_SETTINGFILE, "Gameplay", "COUNTDOWN", Ar2_S_Countdown, sizeof(Ar2_S_Countdown))
	Setting_Load_StringArray(SOUND_SETTINGFILE, "Gameplay", "ZOMBIE_APPEAR", Ar_S_ZombieAppear)
	Setting_Load_String(SOUND_SETTINGFILE, "Gameplay", "MESSAGE_TUTORIAL", Ar2_S_MessageTutorial, sizeof(Ar2_S_MessageTutorial))
	Setting_Load_StringArray(SOUND_SETTINGFILE, "Gameplay", "WIN_HUMAN", Ar_S_WinHuman)
	Setting_Load_StringArray(SOUND_SETTINGFILE, "Gameplay", "WIN_ZOMBIE", Ar_S_WinZombie)
	Setting_Load_String(SOUND_SETTINGFILE, "Gameplay", "SUPPLYBOX_DROP", Ar2_S_Supplybox_Drop, sizeof(Ar2_S_Supplybox_Drop))
	Setting_Load_StringArray(SOUND_SETTINGFILE, "Gameplay", "ZOMBIE_ALERT", Ar_S_ZombieAlert)
	Setting_Load_String(SOUND_SETTINGFILE, "Action", "ACTIVATE", Ar2_S_Activate, sizeof(Ar2_S_Activate))
	Setting_Load_String(SOUND_SETTINGFILE, "Action", "PICKUP", Ar2_S_Pickup, sizeof(Ar2_S_Pickup))
	Setting_Load_String(SOUND_SETTINGFILE, "Action", "STUN_ACTIVATE", Ar2_S_StunActivate, sizeof(Ar2_S_StunActivate))
	Setting_Load_String(SOUND_SETTINGFILE, "Action", "STUN", Ar2_S_Stun, sizeof(Ar2_S_Stun))
	Setting_Load_String(SOUND_SETTINGFILE, "Action", "REVIVING", Ar2_S_Reviving, sizeof(Ar2_S_Reviving))
	Setting_Load_String(SOUND_SETTINGFILE, "Action", "REVIVED", Ar2_S_Revived, sizeof(Ar2_S_Revived))
	Setting_Load_String(SOUND_SETTINGFILE, "Action", "STAGE_BOOST", Ar2_S_StageBoost, sizeof(Ar2_S_StageBoost))
	Setting_Load_String(SOUND_SETTINGFILE, "Action", "SUPPLYBOX_PICKUP", Ar2_S_Supplybox_Pick, sizeof(Ar2_S_Supplybox_Pick))
	
	Setting_Load_String(SOUND_SETTINGFILE, "Human", "BECOME_HERO", Ar2_S_BecomeHero, sizeof(Ar2_S_BecomeHero))
	Setting_Load_StringArray(SOUND_SETTINGFILE, "Human", "INFECTION_MALE", Ar_S_InfectionMale)
	Setting_Load_StringArray(SOUND_SETTINGFILE, "Human", "INFECTION_FEMALE", Ar_S_InfectionFemale)
	
	Setting_Load_String(SOUND_SETTINGFILE, "Zombie", "EVOLUTION", Ar2_S_Evolution, sizeof(Ar2_S_Evolution))
	Setting_Load_String(SOUND_SETTINGFILE, "Zombie", "RECOVER", Ar2_S_Recover, sizeof(Ar2_S_Recover))
	Setting_Load_StringArray(SOUND_SETTINGFILE, "Zombie", "ZOMBIE_HIT_PLAYER", Ar_S_ClawHit)
	Setting_Load_StringArray(SOUND_SETTINGFILE, "Zombie", "ZOMBIE_HIT_WALL", Ar_S_ClawWall)
	Setting_Load_StringArray(SOUND_SETTINGFILE, "Zombie", "ZOMBIE_SWING", Ar_S_ClawSwing)
}

public Precache_GameData()
{
	new BufferA[128], BufferB[128]
	new i
	
	// Gameplay
	precache_model(Ar2_S_CrystalModel)
	precache_model(Ar2_S_SupplyModel)

	// Human
	for(i = 0; i < ArraySize(Ar_HumanModelMale); i++) 
	{
		ArrayGetString(Ar_HumanModelMale, i, BufferA, sizeof(BufferA)); formatex(BufferB, sizeof(BufferB), "models/player/%s/%s.mdl", BufferA, BufferA)
		engfunc(EngFunc_PrecacheModel, BufferB); 
	}
	for(i = 0; i < ArraySize(Ar_HumanModelFemale); i++) 
	{
		ArrayGetString(Ar_HumanModelFemale, i, BufferA, sizeof(BufferA)); formatex(BufferB, sizeof(BufferB), "models/player/%s/%s.mdl", BufferA, BufferA)
		engfunc(EngFunc_PrecacheModel, BufferB); 
	}
	
	formatex(BufferB, sizeof(BufferB), "models/player/%s/%s.mdl", Ar2_S_HeroModelMale, Ar2_S_HeroModelMale)
	engfunc(EngFunc_PrecacheModel, BufferB); 
	formatex(BufferB, sizeof(BufferB), "models/player/%s/%s.mdl", Ar2_S_HeroModelFemale, Ar2_S_HeroModelFemale)
	engfunc(EngFunc_PrecacheModel, BufferB); 	
	
	// Zombie
	precache_model(Ar2_S_InfectionModel)
	g_InfectionEffect_SprID = precache_model(Ar2_S_InfectionEffect)
	g_DeathEffect_SprID = precache_model(Ar2_S_DeathEffect)
	g_RespawnEffect_SprID = precache_model(Ar2_S_RespawnEffect)
	g_Supplybox_IconSprID = precache_model(Ar2_S_SupplyIcon)
	precache_model(Ar2_S_RevivedEffect)
	precache_model(Ar2_S_RecoverEffect)
	precache_model(Ar2_S_RecoverEffect2)
	
	// Sounds
	for(i = 0; i < ArraySize(Ar_S_Start); i++) { ArrayGetString(Ar_S_Start, i, BufferA, sizeof(BufferA)); engfunc(EngFunc_PrecacheSound, BufferA); }
	for(i = 0; i < ArraySize(Ar_S_Ambience); i++) { ArrayGetString(Ar_S_Ambience, i, BufferA, sizeof(BufferA)); engfunc(EngFunc_PrecacheSound, BufferA); }
	for(i = 1; i <= 10; i++)
	{
		formatex(BufferB, charsmax(BufferB), Ar2_S_Countdown, i); 
		engfunc(EngFunc_PrecacheSound, BufferB); 
	}	
	for(i = 0; i < ArraySize(Ar_S_ZombieAppear); i++) { ArrayGetString(Ar_S_ZombieAppear, i, BufferA, sizeof(BufferA)); engfunc(EngFunc_PrecacheSound, BufferA); }
	engfunc(EngFunc_PrecacheSound, Ar2_S_MessageTutorial)
	for(i = 0; i < ArraySize(Ar_S_WinHuman); i++) { ArrayGetString(Ar_S_WinHuman, i, BufferA, sizeof(BufferA)); engfunc(EngFunc_PrecacheSound, BufferA); }
	for(i = 0; i < ArraySize(Ar_S_WinZombie); i++) { ArrayGetString(Ar_S_WinZombie, i, BufferA, sizeof(BufferA)); engfunc(EngFunc_PrecacheSound, BufferA); }
	for(i = 0; i < ArraySize(Ar_S_ZombieAlert); i++) { ArrayGetString(Ar_S_ZombieAlert, i, BufferA, sizeof(BufferA)); engfunc(EngFunc_PrecacheSound, BufferA); }
	
	precache_sound(Ar2_S_Activate)
	precache_sound(Ar2_S_Pickup)
	precache_sound(Ar2_S_StunActivate)
	precache_sound(Ar2_S_Stun)
	precache_sound(Ar2_S_Reviving)
	precache_sound(Ar2_S_Revived)
	precache_sound(Ar2_S_StageBoost)
	precache_sound(Ar2_S_Supplybox_Pick)
	precache_sound(Ar2_S_Supplybox_Drop)
	
	precache_sound(Ar2_S_BecomeHero)
	for(i = 0; i < ArraySize(Ar_S_InfectionMale); i++) { ArrayGetString(Ar_S_InfectionMale, i, BufferA, sizeof(BufferA)); engfunc(EngFunc_PrecacheSound, BufferA); }
	for(i = 0; i < ArraySize(Ar_S_InfectionFemale); i++) { ArrayGetString(Ar_S_InfectionFemale, i, BufferA, sizeof(BufferA)); engfunc(EngFunc_PrecacheSound, BufferA); }

	precache_sound(Ar2_S_Evolution)
	precache_sound(Ar2_S_Recover)
	for(i = 0; i < ArraySize(Ar_S_ClawHit); i++) { ArrayGetString(Ar_S_ClawHit, i, BufferA, sizeof(BufferA)); engfunc(EngFunc_PrecacheSound, BufferA); }
	for(i = 0; i < ArraySize(Ar_S_ClawWall); i++) { ArrayGetString(Ar_S_ClawWall, i, BufferA, sizeof(BufferA)); engfunc(EngFunc_PrecacheSound, BufferA); }
	for(i = 0; i < ArraySize(Ar_S_ClawSwing); i++) { ArrayGetString(Ar_S_ClawSwing, i, BufferA, sizeof(BufferA)); engfunc(EngFunc_PrecacheSound, BufferA); }
}

public Environment_Setting()
{
	new BufferA[64], BufferB[128]
	
	// Weather & Sky
	if(Setting_Load_Int(GAME_SETTINGFILE, "Environment", "RAIN")) engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_rain"))
	if(Setting_Load_Int(GAME_SETTINGFILE, "Environment", "SNOW")) engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_snow"))	
	if(Setting_Load_Int(GAME_SETTINGFILE, "Environment", "FOG"))
	{
		remove_entity_name("env_fog")
		
		new D_FogDensity[12], D_FogColor[12]
		Setting_Load_String(GAME_SETTINGFILE, "Environment", "FOG_DENSITY", D_FogDensity, sizeof(D_FogDensity))
		Setting_Load_String(GAME_SETTINGFILE, "Environment", "FOG_COLOR", D_FogColor, sizeof(D_FogColor))
		
		new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_fog"))
		if (pev_valid(ent))
		{
			fm_set_kvd(ent, "density", D_FogDensity, "env_fog")
			fm_set_kvd(ent, "rendercolor", D_FogColor, "env_fog")
		}
	}
	
	// Sky
	Setting_Load_StringArray(GAME_SETTINGFILE, "Environment", "SKY", Ar_GameSky)
	
	for(new i = 0; i < ArraySize(Ar_GameSky); i++)
	{
		ArrayGetString(Ar_GameSky, i, BufferA, charsmax(BufferA)); 
		
		// Preache custom sky files
		formatex(BufferB, charsmax(BufferB), "gfx/env/%sbk.tga", BufferA); engfunc(EngFunc_PrecacheGeneric, BufferB)
		formatex(BufferB, charsmax(BufferB), "gfx/env/%sdn.tga", BufferA); engfunc(EngFunc_PrecacheGeneric, BufferB)
		formatex(BufferB, charsmax(BufferB), "gfx/env/%sft.tga", BufferA); engfunc(EngFunc_PrecacheGeneric, BufferB)
		formatex(BufferB, charsmax(BufferB), "gfx/env/%slf.tga", BufferA); engfunc(EngFunc_PrecacheGeneric, BufferB)
		formatex(BufferB, charsmax(BufferB), "gfx/env/%srt.tga", BufferA); engfunc(EngFunc_PrecacheGeneric, BufferB)
		formatex(BufferB, charsmax(BufferB), "gfx/env/%sup.tga", BufferA); engfunc(EngFunc_PrecacheGeneric, BufferB)		
	}		
}

stock Setting_Load_Int(const filename[], const setting_section[], setting_key[])
{
	if (strlen(filename) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[%s] Can't load settings: empty filename", GameName)
		return false;
	}
	
	if (strlen(setting_section) < 1 || strlen(setting_key) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[%s] Can't load settings: empty section/key", GameName)
		return false;
	}
	
	// Build customization file path
	new path[128]
	get_configsdir(path, charsmax(path))
	format(path, charsmax(path), "%s/%s/%s", path, GAME_FOLDER, filename)
	
	// File not present
	if (!file_exists(path))
	{
		static DataA[128]; formatex(DataA, sizeof(DataA), "[%s] Can't load: %s", GameName, path)
		set_fail_state(DataA)
		
		return false;
	}
	
	// Open customization file for reading
	new file = fopen(path, "rt")
	
	// File can't be opened
	if (!file)
		return false;
	
	// Set up some vars to hold parsing info
	new linedata[1024], section[64]
	
	// Seek to setting's section
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// New section starting
		if (linedata[0] == '[')
		{
			// Store section name without braces
			copyc(section, charsmax(section), linedata[1], ']')
			
			// Is this our setting's section?
			if (equal(section, setting_section))
				break;
		}
	}
	
	// Section not found
	if (!equal(section, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Set up some vars to hold parsing info
	new key[64], current_value[32]
	
	// Seek to setting's key
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// Blank line or comment
		if (!linedata[0] || linedata[0] == ';') continue;
		
		// Section ended?
		if (linedata[0] == '[')
			break;
		
		// Get key and value
		strtok(linedata, key, charsmax(key), current_value, charsmax(current_value), '=')
		
		// Trim spaces
		trim(key)
		trim(current_value)
		
		// Is this our setting's key?
		if (equal(key, setting_key))
		{
			static return_value
			// Return int by reference
			return_value = str_to_num(current_value)
			
			// Values succesfully retrieved
			fclose(file)
			return return_value
		}
	}
	
	// Key not found
	fclose(file)
	return false;
}

stock Setting_Load_StringArray(const filename[], const setting_section[], setting_key[], Array:array_handle)
{
	if (strlen(filename) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[%s] Can't load settings: empty filename", GameName)
		return false;
	}

	if (strlen(setting_section) < 1 || strlen(setting_key) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[%s] Can't load settings: empty section/key", GameName)
		return false;
	}
	
	if (array_handle == Invalid_Array)
	{
		log_error(AMX_ERR_NATIVE, "[%s] Array not initialized", GameName)
		return false;
	}
	
	// Build customization file path
	new path[128]
	get_configsdir(path, charsmax(path))
	format(path, charsmax(path), "%s/%s/%s", path, GAME_FOLDER, filename)
	
	// File not present
	if (!file_exists(path))
	{
		static DataA[128]; formatex(DataA, sizeof(DataA), "[%s] Can't load: %s", GameName, path)
		set_fail_state(DataA)
		
		return false;
	}
	
	// Open customization file for reading
	new file = fopen(path, "rt")
	
	// File can't be opened
	if (!file)
		return false;
	
	// Set up some vars to hold parsing info
	new linedata[1024], section[64]
	
	// Seek to setting's section
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// New section starting
		if (linedata[0] == '[')
		{
			// Store section name without braces
			copyc(section, charsmax(section), linedata[1], ']')
			
			// Is this our setting's section?
			if (equal(section, setting_section))
				break;
		}
	}
	
	// Section not found
	if (!equal(section, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Set up some vars to hold parsing info
	new key[64], values[1024], current_value[128]
	
	// Seek to setting's key
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// Blank line or comment
		if (!linedata[0] || linedata[0] == ';') continue;
		
		// Section ended?
		if (linedata[0] == '[')
			break;
		
		// Get key and values
		strtok(linedata, key, charsmax(key), values, charsmax(values), '=')
		
		// Trim spaces
		trim(key)
		trim(values)
		
		// Is this our setting's key?
		if (equal(key, setting_key))
		{
			// Parse values
			while (values[0] != 0 && strtok(values, current_value, charsmax(current_value), values, charsmax(values), ','))
			{
				// Trim spaces
				trim(current_value)
				trim(values)
				
				// Add to array
				ArrayPushString(array_handle, current_value)
			}
			
			// Values succesfully retrieved
			fclose(file)
			return true;
		}
	}
	
	// Key not found
	fclose(file)
	return false;
}

stock Setting_Load_String(const filename[], const setting_section[], setting_key[], return_string[], string_size)
{
	if (strlen(filename) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[%s] Can't load settings: empty filename", GameName)
		return false;
	}

	if (strlen(setting_section) < 1 || strlen(setting_key) < 1)
	{
		log_error(AMX_ERR_NATIVE, "[%s] Can't load settings: empty section/key", GameName)
		return false;
	}
	
	// Build customization file path
	new path[128]
	get_configsdir(path, charsmax(path))
	format(path, charsmax(path), "%s/%s/%s", path, GAME_FOLDER, filename)
	
	// File not present
	if (!file_exists(path))
	{
		static DataA[128]; formatex(DataA, sizeof(DataA), "[%s] Can't load: %s", GameName, path)
		set_fail_state(DataA)
		
		return false;
	}
	
	// Open customization file for reading
	new file = fopen(path, "rt")
	
	// File can't be opened
	if (!file)
		return false;
	
	// Set up some vars to hold parsing info
	new linedata[1024], section[64]
	
	// Seek to setting's section
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// New section starting
		if (linedata[0] == '[')
		{
			// Store section name without braces
			copyc(section, charsmax(section), linedata[1], ']')
			
			// Is this our setting's section?
			if (equal(section, setting_section))
				break;
		}
	}
	
	// Section not found
	if (!equal(section, setting_section))
	{
		fclose(file)
		return false;
	}
	
	// Set up some vars to hold parsing info
	new key[64], current_value[128]
	
	// Seek to setting's key
	while (!feof(file))
	{
		// Read one line at a time
		fgets(file, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// Blank line or comment
		if (!linedata[0] || linedata[0] == ';') continue;
		
		// Section ended?
		if (linedata[0] == '[')
			break;
		
		// Get key and value
		strtok(linedata, key, charsmax(key), current_value, charsmax(current_value), '=')
		
		// Trim spaces
		trim(key)
		trim(current_value)
		
		// Is this our setting's key?
		if (equal(key, setting_key))
		{
			formatex(return_string, string_size, "%s", current_value)
			
			// Values succesfully retrieved
			fclose(file)
			return true;
		}
	}
	
	// Key not found
	fclose(file)
	return false;
}

// =========================== Random Origin Generator =============================
// =================================================================================
public ROG_SsInit(Float:mindist)
{
	new cmd[32]
	format(cmd, 15, "_ss_dump%c%c%c%c", random_num('A', 'Z'), random_num('A', 'Z'), random_num('A', 'Z'), random_num('A', 'Z'))
	register_cvar("sv_rog", SS_VERSION, (FCVAR_SERVER|FCVAR_SPONLY))
	register_concmd(cmd, "ROG_SsDump")

	g_flSsMinDist = mindist
	g_vecSsOrigins = ArrayCreate(3, 1)
	g_vecSsSpawns = ArrayCreate(3, 1)
	g_vecSsUsed = ArrayCreate(3, 1)
}

stock ROG_SsClean()
{
	g_flSsMinDist = 0.0
	ArrayClear(g_vecSsOrigins)
	ArrayClear(g_vecSsSpawns)
	ArrayClear(g_vecSsUsed)
}

stock ROG_SsGetOrigin(Float:origin[3])
{
	new Float:data[3], size
	new ok = 1

	while((size = ArraySize(g_vecSsOrigins)))
	{
		new idx = random_num(0, size - 1)

		ArrayGetArray(g_vecSsOrigins, idx, origin)

		new used = ArraySize(g_vecSsUsed)
		for(new i = 0; i < used; i++)
		{
			ok = 0
			ArrayGetArray(g_vecSsUsed, i, data)
			if(get_distance_f(data, origin) >= g_flSsMinDist)
			{
				ok = 1
				break
			}
		}

		ArrayDeleteItem(g_vecSsOrigins, idx)
		if(ok)
		{
			ArrayPushArray(g_vecSsUsed, origin)
			return true
		}
	}
	return false
}

public ROG_SsDump()
{
	new count = ArraySize(g_vecSsOrigins)
	server_print("Thanatos System: Found %i Origin(s)!", count)
	server_print("Thanatos System: Scanning Time %i", g_iSsTime)
}

public ROG_SsScan()
{
	new start, Float:origin[3], starttime
	starttime = get_systime()
	for(start = 0; start < sizeof(g_szStarts); start++)
	{
		server_print("Thanatos System: Searching for %s", g_szStarts[start])
		new ent
		if((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", g_szStarts[start])))
		{
			new counter
			pev(ent, pev_origin, origin)
			ArrayPushArray(g_vecSsSpawns, origin)
			while(counter < SS_MAX_LOOPS)
			{
				counter = ROG_GetLocation(origin, counter)
			}
		}
	}
	g_iSsTime = get_systime()
	g_iSsTime -= starttime
}

ROG_GetLocation(Float:start[3], &counter)
{
	new Float:end[3]
	for(new i = 0; i < 3; i++)
	{
		end[i] += random_float(0.0 - g_flOffsets[i], g_flOffsets[i])
	}

	if(ROG_IsValid(start, end))
	{
		start[0] = end[0]
		start[1] = end[1]
		start[2] = end[2]
		ArrayPushArray(g_vecSsOrigins, end)
	}
	counter++
	return counter
}

ROG_IsValid(Float:start[3], Float:end[3])
{
	ROG_SetFloor(end)
	end[2] += 36.0
	new point = engfunc(EngFunc_PointContents, end)
	if(point == CONTENTS_EMPTY)
	{
		if(ROG_CheckPoints(end) && ROG_CheckDistance(end) && ROG_CheckVisibility(start, end))
		{
			if(!trace_hull(end, HULL_LARGE, -1))
			{
				return true
			}
		}
	}
	return false
}

ROG_CheckVisibility(Float:start[3], Float:end[3])
{
	new tr
	engfunc(EngFunc_TraceLine, start, end, IGNORE_GLASS, -1, tr)
	return (get_tr2(tr, TR_pHit) < 0)
}

ROG_SetFloor(Float:start[3])
{
	new tr, Float:end[3]
	end[0] = start[0]
	end[1] = start[1]
	end[2] = -99999.9
	engfunc(EngFunc_TraceLine, start, end, DONT_IGNORE_MONSTERS, -1, tr)
	get_tr2(tr, TR_vecEndPos, start)
}

ROG_CheckPoints(Float:origin[3])
{
	new Float:data[3], tr, point
	data[0] = origin[0]
	data[1] = origin[1]
	data[2] = 99999.9
	engfunc(EngFunc_TraceLine, origin, data, DONT_IGNORE_MONSTERS, -1, tr)
	get_tr2(tr, TR_vecEndPos, data)
	point = engfunc(EngFunc_PointContents, data)
	if(point == CONTENTS_SKY && get_distance_f(origin, data) < 250.0)
	{
		return false
	}
	data[2] = -99999.9
	engfunc(EngFunc_TraceLine, origin, data, DONT_IGNORE_MONSTERS, -1, tr)
	get_tr2(tr, TR_vecEndPos, data)
	point = engfunc(EngFunc_PointContents, data)
	if(point < CONTENTS_SOLID)
		return false
	
	return true
}

ROG_CheckDistance(Float:origin[3])
{
	new Float:dist, Float:data[3]
	new count = ArraySize(g_vecSsSpawns)
	for(new i = 0; i < count; i++)
	{
		ArrayGetArray(g_vecSsSpawns, i, data)
		dist = get_distance_f(origin, data)
		if(dist < SS_MIN_DISTANCE)
			return false
	}

	count = ArraySize(g_vecSsOrigins)
	for(new i = 0; i < count; i++)
	{
		ArrayGetArray(g_vecSsOrigins, i, data)
		dist = get_distance_f(origin, data)
		if(dist < SS_MIN_DISTANCE)
			return false
	}

	return true
}

// ===================== STOCK.... =======================
// =======================================================
stock Get_PlayerRate(PlayerNum)
{
	static Return;
	switch(PlayerNum)
	{
		case 8..12: Return = 1
		case 13..27: Return = 2
		case 28..32: Return = 3
		default: Return = 0
	}
	
	return Return
}

stock Get_RandomArray(Array:ArrayName)
{
	return random_num(0, ArraySize(ArrayName) - 1)
}

stock Get_PlayerCount(Alive, Team)
// Alive: 0 - Dead | 1 - Alive | 2 - Both
// Team: 1 - T | 2 - CT
{
	new Flag[4], Flag2[12]
	new Players[32], PlayerNum

	if(!Alive) formatex(Flag, sizeof(Flag), "%sb", Flag)
	else if(Alive == 1) formatex(Flag, sizeof(Flag), "%sa", Flag)
	
	if(Team == 1) 
	{
		formatex(Flag, sizeof(Flag), "%se", Flag)
		formatex(Flag2, sizeof(Flag2), "TERRORIST", Flag)
	} else if(Team == 2) 
	{
		formatex(Flag, sizeof(Flag), "%se", Flag)
		formatex(Flag2, sizeof(Flag2), "CT", Flag)
	}
	
	get_players(Players, PlayerNum, Flag, Flag2)
	
	return PlayerNum
}

stock GetPlayerCount(Alive)
{
	static PlayerNum, id; PlayerNum = id = 0
	
	for(id = 1; id <= g_MaxPlayers; id++)
	{
		if(Alive)
		{
			if(is_user_alive(id) && (cs_get_user_team(id) == CS_TEAM_CT || cs_get_user_team(id) == CS_TEAM_T))
				PlayerNum++
		} else {
			if(is_user_connected(id) && (cs_get_user_team(id) == CS_TEAM_CT || cs_get_user_team(id) == CS_TEAM_T))
				PlayerNum++
		}
	}

	return PlayerNum
}

stock Get_LivingZombie()
{
	static Count; Count = 0
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_connected(i))
			continue
		if(g_PlayerType[i] != PLAYER_ZOMBIE)
			continue
		if(is_alive(i))
		{
			Count++
		} else {
			if(Get_BitVar(g_PermDeath, i))
				continue
				
			Count++
		}
	}
	
	return Count
}

stock Get_ServerZombie()
{
	static Zombie;
	switch(Get_TotalInPlayer(2))
	{
		case 0..9: Zombie = 1;
		case 10..19: Zombie = 2;
		case 20..32: Zombie = 3;
		default: Zombie = 1;
	}
	
	return Zombie
}

stock Get_TotalInPlayer(Alive)
{
	return Get_PlayerCount(Alive, 1) + Get_PlayerCount(Alive, 2)
}

stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}

stock get_color_level(percent, num)
{
	static Color[3]
	switch(percent)
	{
		case 100..139: Color = {0,177,0}
		case 140..159: Color = {137,191,20}
		case 160..179: Color = {250,229,0}
		case 180..199: Color = {243,127,1}
		case 200..209: Color = {255,3,0}
		case 210..1000: Color = {127,40,208}
		default: Color = {100, 100, 100}
	}
	
	return Color[num]
}

stock StopSound(id) client_cmd(id, "mp3 stop; stopsound")
stock EmitSound(id, Channel, const Sound[]) emit_sound(id, Channel, Sound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
stock collect_spawns_ent(const classname[])
{
	static ent; ent = -1
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", classname)) != 0)
	{
		// get origin
		static Float:originF[3]
		pev(ent, pev_origin, originF)
		
		g_PlayerSpawn_Point[g_PlayerSpawn_Count][0] = originF[0]
		g_PlayerSpawn_Point[g_PlayerSpawn_Count][1] = originF[1]
		g_PlayerSpawn_Point[g_PlayerSpawn_Count][2] = originF[2]
		
		// increase spawn count
		g_PlayerSpawn_Count++
		if(g_PlayerSpawn_Count >= sizeof g_PlayerSpawn_Point) break;
	}
}

stock fm_cs_get_user_team(id)
{
	// Prevent server crash if entity's private data not initalized
	if (pev_valid(id) != PDATA_SAFE)
		return 0;
	
	return get_pdata_int(id, OFFSET_CSTEAMS, OFFSET_PLAYER_LINUX)
}

stock fm_cs_set_user_deaths(id, value)
{
	// Prevent server crash if entity's private data not initalized
	if (pev_valid(id) != PDATA_SAFE)
		return;
	
	set_pdata_int(id, OFFSET_CSDEATHS, value, OFFSET_PLAYER_LINUX)
}

stock is_hull_vacant(Float:Origin[3], hull)
{
	engfunc(EngFunc_TraceHull, Origin, Origin, 0, hull, 0, 0)
	
	if (!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen))
		return true
	
	return false
}

stock SetPlayerLight(id, const LightStyle[])
{
	if(id != 0)
	{
		message_begin(MSG_ONE_UNRELIABLE, SVC_LIGHTSTYLE, .player = id)
		write_byte(0)
		write_string(LightStyle)
		message_end()		
	} else {
		message_begin(MSG_BROADCAST, SVC_LIGHTSTYLE)
		write_byte(0)
		write_string(LightStyle)
		message_end()	
	}
}

stock FixedUnsigned16(Float:flValue, iScale)
{
	new iOutput;

	iOutput = floatround(flValue * iScale);

	if ( iOutput < 0 )
		iOutput = 0;

	if ( iOutput > 0xFFFF )
		iOutput = 0xFFFF;

	return iOutput;
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	// Prevent server crash if entity's private data not initalized
	if (pev_valid(ent) != PDATA_SAFE)
		return -1;
	
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_WEAPON_LINUX);
}

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id)
	write_byte(anim)
	write_byte(0)
	message_end()	
}

stock Set_Player_NextAttack(id, Float:Time)
{
	if(pev_valid(id) != PDATA_SAFE)
		return
		
	set_pdata_float(id, 83, Time, 5)
}

stock Float:Get_RoundTimeLeft()
{
	return (g_RoundTimeLeft > 0.0) ? (g_RoundTimeLeft - get_gametime()) : -1.0
}

stock normalize(Float:fIn[3], Float:fOut[3], Float:fMul) // By sontung0
{
	static Float:fLen; fLen = xs_vec_len(fIn)
	xs_vec_copy(fIn, fOut)
	
	fOut[0] /= fLen, fOut[1] /= fLen, fOut[2] /= fLen
	fOut[0] *= fMul, fOut[1] *= fMul, fOut[2] *= fMul
}

stock FloatToNum(Float:floatn)
{
	new str[64], num
	float_to_str(floatn, str, 63)
	num = str_to_num(str)
	
	return num
}

stock Get_PlayerTeam(id)
{
	if(!is_connected(id))
		return TEAM_NONE
		
	if(g_PlayerType[id] == PLAYER_ZOMBIE) return TEAM_ZOMBIE
	else if(g_PlayerType[id] == PLAYER_HUMAN) return TEAM_HUMAN
	
	return TEAM_NONE
}

// Drop primary/secondary weapons
stock drop_weapons(id, dropwhat)
{
	// Get user weapons
	static weapons[32], num, i, weaponid
	num = 0 // reset passed weapons count (bugfix)
	get_user_weapons(id, weapons, num)
	
	// Loop through them and drop primaries or secondaries
	for (i = 0; i < num; i++)
	{
		// Prevent re-indexing the array
		weaponid = weapons[i]
		
		if ((dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)) || (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM)))
		{
			// Get weapon entity
			static wname[32]; get_weaponname(weaponid, wname, charsmax(wname))
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock set_weapons_timeidle(id, WeaponId ,Float:TimeIdle)
{
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 0.5, 4)
}

stock hook_ent2(ent, Float:VicOrigin[3], Float:speed, Float:multi, type)
{
	static Float:fl_Velocity[3]
	static Float:EntOrigin[3]
	static Float:EntVelocity[3]
	
	pev(ent, pev_velocity, EntVelocity)
	pev(ent, pev_origin, EntOrigin)
	static Float:distance_f
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	
	static Float:fl_Time; fl_Time = distance_f / speed
	static Float:fl_Time2; fl_Time2 = distance_f / (speed * multi)
	
	if(type == 1)
	{
		fl_Velocity[0] = ((VicOrigin[0] - EntOrigin[0]) / fl_Time2) * 1.5
		fl_Velocity[1] = ((VicOrigin[1] - EntOrigin[1]) / fl_Time2) * 1.5
		fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time		
	} else if(type == 2) {
		fl_Velocity[0] = ((EntOrigin[0] - VicOrigin[0]) / fl_Time2) * 1.5
		fl_Velocity[1] = ((EntOrigin[1] - VicOrigin[1]) / fl_Time2) * 1.5
		fl_Velocity[2] = (EntOrigin[2] - VicOrigin[2]) / fl_Time
	}

	xs_vec_add(EntVelocity, fl_Velocity, fl_Velocity)
	set_pev(ent, pev_velocity, fl_Velocity)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
