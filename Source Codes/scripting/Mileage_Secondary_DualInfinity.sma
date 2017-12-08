#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <xs>
#include <zombie_evolution>

#define PLUGIN "[Mileage] Secondary: Dual Infinity"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define DAMAGE_A  60
#define DAMAGE_B 45
#define CLIP 40
#define BPAMMO 240
#define TIME_RELOAD 4.0
#define DELAY_A 0.18
#define DELAY_B 0.1

#define CSW_INFINITY CSW_ELITE
#define weapon_infinity "weapon_elite"

#define MODEL_V "models/mileage_wpn/sec/v_infinityex2.mdl"
#define MODEL_P "models//mileage_wpn/sec/p_infinityex2.mdl"
#define MODEL_W "models//mileage_wpn/sec/w_infinityex2.mdl"
#define OLD_MODEL_W "models/w_elite.mdl"

new const InfinitySound[5][] =
{
	"weapons/infi-1.wav",
	"weapons/infi_clipin.wav",
	"weapons/infi_clipon.wav",
	"weapons/infi_clipout.wav",
	"weapons/infi_draw.wav"
}

/*
new const InfinityResources[4][] =
{
	"sprites/weapon_infinityex2.txt",
	"sprites/640hud7_2.spr",
	"sprites/640hud42_2.spr",
	"sprites/640hud43_2.spr"
}*/

enum
{
	ANIME_IDLE,
	ANIME_IDLE_LEFTEMPTY,
	ANIME_SHOOTLEFT,
	ANIME_SHOOTLEFT2,
	ANIME_SHOOTLEFT3,
	ANIME_SHOOTLEFT4,
	ANIME_SHOOTLEFT5,
	ANIME_SHOOTLEFTLAST,
	ANIME_SHOOTRIGHT,
	ANIME_SHOOTRIGHT2,
	ANIME_SHOOTRIGHT3,
	ANIME_SHOOTRIGHT4,
	ANIME_SHOOTRIGHT5,
	ANIME_SHOOTRIGHTLAST,
	ANIME_RELOAD,
	ANIME_DRAW,
	ANIME_SP_SHOOTLEFT1,
	ANIME_SP_SHOOTRIGHT1,
	ANIME_SP_SHOOTLEFT2,
	ANIME_SP_SHOOTRIGHT2,
	ANIME_SP_SHOOTLEFTLAST,
	ANIME_SP_SHOOTRIGHTLAST
};

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

// Vars
new g_Infinity
new g_Had_Infinity, g_Clip[33], g_Event_Left, g_Event_Right, Float:g_MyKickBack[33][3], g_RapidAttack, g_Firing[33]
new g_MsgWeaponList, g_MsgCurWeapon
new g_SmokePuff_SprId

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33], g_HamBot

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Safety
	Register_SafetyFunc()
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")
	
	RegisterHam(Ham_Item_Deploy, weapon_infinity, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_infinity, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_infinity, "fw_Weapon_WeaponIdle_Post", 1)
	
	RegisterHam(Ham_Item_PostFrame, weapon_infinity, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_infinity, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_infinity, "fw_Weapon_Reload_Post", 1)	
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_infinity, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_infinity, "fw_Weapon_PrimaryAttack_Post", 1)
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgWeaponList = get_user_msgid("WeaponList")
	
	g_Infinity = Mileage_RegisterWeapon("infinityex2")
	register_clcmd("weapon_infinityex2", "Hook_Weapon")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	for(new i = 0; i < sizeof(InfinitySound); i++)
		precache_sound(InfinitySound[i])
		
		/*
	precache_generic(InfinityResources[0])
	precache_model(InfinityResources[1])
	precache_model(InfinityResources[2])
	precache_model(InfinityResources[3])*/
	
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/elite_left.sc", name)) g_Event_Left = get_orig_retval()
	else if(equal("events/elite_right.sc", name)) g_Event_Right = get_orig_retval()	
}

public client_putinserver(id)
{
	Safety_Connected(id)
	
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Do_Register_HamBot", id)
	}
}

public Do_Register_HamBot(id) 
{
	Register_SafetyFuncBot(id)
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack_Player")	
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_infinity)
	return PLUGIN_HANDLED
}

public Mileage_WeaponGet(id, ItemID)
{
	if(ItemID == g_Infinity) Get_Infinity(id)
}

public Mileage_WeaponRemove(id, ItemID)
{
	if(ItemID == g_Infinity) Remove_Infinity(id)
}

public Mileage_WeaponRefillAmmo(id, ItemID)
{
	if(ItemID == g_Infinity)
	{
		static Num; Num = BPAMMO / 30
		for(new i = 0; i < Num; i++)
			Give_Ammo(id, 0, CSW_INFINITY)
	}
}

public Get_Infinity(id)
{
	g_Firing[id] = 0
	Set_BitVar(g_Had_Infinity, id)
	give_item(id, weapon_infinity)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_INFINITY)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	
	static Num; Num = BPAMMO / 30
	
	for(new i = 0; i < Num; i++)
		Give_Ammo(id, 0, CSW_INFINITY)
	
	/*
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_INFINITY)
	write_byte(CLIP)
	message_end()*/
}

public Remove_Infinity(id)
{
	UnSet_BitVar(g_Had_Infinity, id)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_INFINITY && Get_BitVar(g_Had_Infinity, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_connected(invoker))
		return FMRES_IGNORED	
	if(get_player_weapon(invoker) != CSW_INFINITY || !Get_BitVar(g_Had_Infinity, invoker))
		return FMRES_IGNORED
		
	if(eventid == g_Event_Left)
	{
		engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
		
		if(!Get_BitVar(g_RapidAttack, invoker)) Set_WeaponAnim(invoker, ANIME_SHOOTLEFT)
		else {
			if(pev(invoker, pev_flags) & FL_DUCKING) Set_WeaponAnim(invoker, ANIME_SP_SHOOTLEFT1)
			else Set_WeaponAnim(invoker, ANIME_SP_SHOOTLEFT2)
		}
		
		emit_sound(invoker, CHAN_WEAPON, InfinitySound[0], 1.0, 0.4, 0, 94 + random_num(0, 15))

		return FMRES_SUPERCEDE
	} else if(eventid == g_Event_Right) {
		engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
		
		if(!Get_BitVar(g_RapidAttack, invoker)) Set_WeaponAnim(invoker, ANIME_SHOOTRIGHT)
		else {
			if(pev(invoker, pev_flags) & FL_DUCKING) Set_WeaponAnim(invoker, ANIME_SP_SHOOTRIGHT1)
			else Set_WeaponAnim(invoker, ANIME_SP_SHOOTRIGHT2)
		}
		
		emit_sound(invoker, CHAN_WEAPON, InfinitySound[0], 1.0, 0.4, 0, 94 + random_num(0, 15))

		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return
	if(get_player_weapon(id) != CSW_INFINITY || !Get_BitVar(g_Had_Infinity, id))
		return
	
	static NewButton; NewButton = get_uc(uc_handle, UC_Buttons)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_INFINITY)
	
	if(!pev_valid(Ent))
		return
	
	if(NewButton & IN_ATTACK2)
	{
		if(get_pdata_float(id, 83, 5) > 0.0)
			return
			
		Set_BitVar(g_RapidAttack, id)
		ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
		set_pdata_float(id, 83, DELAY_B, 5)
	} else {
		if(OldButton & IN_ATTACK2)
		{
			UnSet_BitVar(g_RapidAttack, id)
			g_Firing[id] = 0
		}
	}
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static Classname[32]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	iOwner = pev(entity, pev_owner)
	
	if(equal(model, OLD_MODEL_W))
	{
		static weapon; weapon = find_ent_by_owner(-1, weapon_infinity, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Infinity, iOwner))
		{
			set_pev(weapon, pev_impulse, 982015)
			engfunc(EngFunc_SetModel, entity, MODEL_W)
			
			Remove_Infinity(iOwner)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Infinity, Id))
		return
	
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)

	Set_WeaponAnim(Id, ANIME_DRAW)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 982015)
	{
		Set_BitVar(g_Had_Infinity, id)
		set_pev(Ent, pev_impulse, 0)
	}
	
	/*
	if(Get_BitVar(g_Had_Infinity, id))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
		write_string("weapon_infinityex2")
		write_byte(10);
		write_byte(BPAMMO);
		write_byte(-1);
		write_byte(-1);
		write_byte(1);
		write_byte(5);
		write_byte(CSW_ELITE);
		write_byte(0);
		message_end();
	}*/
	
	return HAM_HANDLED	
}

public fw_Weapon_WeaponIdle_Post( iEnt )
{
	if(pev_valid(iEnt) != 2)
		return
	static Id; Id = get_pdata_cbase(iEnt, 41, 4)
	if(get_pdata_cbase(Id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_Infinity, Id))
		return
		
	if(get_pdata_float(iEnt, 48, 4) <= 0.25)
	{
		Set_WeaponAnim(Id, ANIME_IDLE)
		set_pdata_float(iEnt, 48, 20.0, 4)
	}	
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Infinity, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_INFINITY)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_INFINITY, bpammo - temp1)		
		
		set_pdata_int(ent, 54, 0, 4)
		fInReload = 0
	}		
	
	return HAM_IGNORED
}

public fw_Weapon_Reload(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Infinity, id))
		return HAM_IGNORED	

	g_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_INFINITY)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
		
	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE		
			
	g_Clip[id] = iClip	
	
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Infinity, id))
		return HAM_IGNORED	
	
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Clip[id], 4)
		Set_WeaponAnim(id, ANIME_RELOAD)
		
		Set_PlayerNextAttack(id, TIME_RELOAD)
	}
	
	return HAM_HANDLED
}

public fw_Weapon_PrimaryAttack(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Infinity, Id))
		return
		
	pev(Id, pev_punchangle, g_MyKickBack[Id])
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Infinity, Id))
		return
		
	static Ammo; Ammo = cs_get_weapon_ammo(Ent)
	if(Ammo) g_Firing[Id]++
		
	static iShotsFired; iShotsFired = get_pdata_int(Ent, 64, 4, 4)
	if(!Get_BitVar(g_RapidAttack, Id))
	{
		if(iShotsFired == 1)
		{
			g_MyKickBack[Id][0] -= 2.0
			if(Ammo) set_pev(Id, pev_punchangle, g_MyKickBack[Id])
		}
		
		set_pdata_float(Ent, 62, 1.0, 4);
	} else {
		if(Ammo) 
		{
			static flags; flags = pev(Id, pev_flags)
			static Float:velocity[3]; pev(Id, pev_velocity, velocity)
			
			if (!(flags & FL_ONGROUND))
				KickBack(Id, g_Firing[Id], g_MyKickBack[Id], 1.0, 1.0, 0.8, 0.8, 5.0, 5.0);
			else if (Vector__Length2D(velocity) > 0.0)
				KickBack(Id, g_Firing[Id], g_MyKickBack[Id], 0.35, 0.4, 0.1, 0.15, 2.3, 3.3);
			else if (flags & FL_DUCKING)
				KickBack(Id, g_Firing[Id], g_MyKickBack[Id], 0.2, 0.35, 0.07, 0.1, 2.0, 3.0);
			else
				KickBack(Id, g_Firing[Id], g_MyKickBack[Id], 0.2, 0.35, 0.07, 0.1, 2.0, 3.0);
		
			set_pdata_float(Ent, 62, g_Firing[Id] == 1 ? 1.0 : random_float(0.6, 0.9), 4)
			set_pdata_int(Ent, 64, -1, 4);
		}
	}
}

Float:Vector__Length2D(Float:vec[3])
{
	return (vec[0] * vec[0] + vec[1] * vec[1]);
}

KickBack(pPlayer, iShotsFired, Float:punchangle[3], Float:up_base, Float:lateral_base, Float:up_modifier, Float:lateral_modifier, Float:up_max, Float:lateral_max)
{
	new Float:up = up_base * 0.1 * (rand() % 10);
	new Float:lateral = lateral_base * 0.1 * (rand() % 10);
	
	if (iShotsFired > 1)
	{
		up += up_modifier * (rand() % floatround(iShotsFired * 2.0, floatround_floor));
		lateral += lateral_modifier * (rand() % floatround(iShotsFired * 2.5, floatround_floor));
	}
	
	new i = rand() & 0x80000001;
	new j = i == 0;
	if (i & 0x80000000) j = ((i - 1) | 0xfffffffe) == -1;
	if (j) punchangle[0] = floatmin(punchangle[0] + up, up_max);
	else punchangle[0] = floatmax(punchangle[0] - up, -up_max);
	
	if (rand() % 2) punchangle[1] = floatmin(punchangle[1] + lateral, lateral_max);
	else punchangle[1] = floatmax(punchangle[1] - lateral, -lateral_max);
	
	set_pev(pPlayer, pev_punchangle, punchangle);
}

rand()
{
	return random_num(0, 0x7fffffff);
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_INFINITY || !Get_BitVar(g_Had_Infinity, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
		
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)		
			
	Make_BulletHole(Attacker, flEnd, Damage)
	Make_BulletSmoke(Attacker, Ptr)

	SetHamParamFloat(3, float(DAMAGE_A))
	
	return HAM_HANDLED
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_INFINITY || !Get_BitVar(g_Had_Infinity, Attacker))
		return HAM_IGNORED

	SetHamParamFloat(3, float(DAMAGE_A))
	
	return HAM_HANDLED
}


public Give_Ammo(id, silent, CSWID)
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

public is_alive(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	if(!Get_BitVar(g_IsAlive, id)) 
		return 0
	
	return 1
}

public is_connected(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	
	return 1
}

public get_player_weapon(id)
{
	if(!is_alive(id))
		return 0
	
	return g_PlayerWeapon[id]
}

/* ===============================
--------- End of SAFETY ----------
=================================*/


stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock Make_BulletHole(id, Float:Origin[3], Float:Damage)
{
	// Find target
	static Decal; Decal = random_num(41, 45)
	static LoopTime; 
	
	if(Damage > 100.0) LoopTime = 2
	else LoopTime = 1
	
	for(new i = 0; i < LoopTime; i++)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_byte(Decal)
		message_end()
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(id)
		write_byte(Decal)
		message_end()
	}
}

stock Make_BulletSmoke(id, TrResult)
{
	static Float:vecSrc[3], Float:vecEnd[3], TE_FLAG
	
	get_weapon_attachment(id, vecSrc)
	global_get(glb_v_forward, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	get_tr2(TrResult, TR_vecEndPos, vecSrc)
	get_tr2(TrResult, TR_vecPlaneNormal, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 2.5, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)
    
	TE_FLAG |= TE_EXPLFLAG_NODLIGHTS
	TE_FLAG |= TE_EXPLFLAG_NOSOUND
	TE_FLAG |= TE_EXPLFLAG_NOPARTICLES
	
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecEnd, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, vecEnd[0])
	engfunc(EngFunc_WriteCoord, vecEnd[1])
	engfunc(EngFunc_WriteCoord, vecEnd[2] - 10.0)
	write_short(g_SmokePuff_SprId)
	write_byte(2)
	write_byte(50)
	write_byte(TE_FLAG)
	message_end()
}

stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
	static Float:vfEnd[3], viEnd[3] 
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	static Float:fOrigin[3], Float:fAngle[3]
	
	pev(id, pev_origin, fOrigin) 
	pev(id, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	static Float:fAttack[3]
	
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	static Float:fRate
	
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	
	xs_vec_add(fOrigin, fAttack, output)
}

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	new Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	
	return 1;
}

stock Set_WeaponIdleTime(id, WeaponId ,Float:TimeIdle)
{
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 0.5, 4)
}

stock Set_PlayerNextAttack(id, Float:nexttime)
{
	set_pdata_float(id, 83, nexttime, 5)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
