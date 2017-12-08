#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <xs>
#include <zombie_evolution>

#define PLUGIN "[ZEVO] Zombie Class: Stamper"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define ZOMBIE_NAME "Stamper"
#define GAME_FOLDER "zombie_evolution"
#define SETTING_FILE "ZEvo_ZombieClassConfig.ini"
#define LANG_FILE "zombie_evolution.txt"

#define GAME_LANG LANG_SERVER

// Skill
#define STAMP_COOLDOWN 12
#define STAMP_HOLDTIME 10
#define STAMP_FOV 105
#define STAMP_SLOWTIME 5.0
#define STAMP_SLOWSPEED 160.0

#define IRON_COOLDOWN 20

#define COFFIN_HEALTH 500.0
#define COFFIN_KNOCKPOWER 250.0

/// Zombie Class
new GameName[] = "Zombie Evolution"

new zclass_name[32] = "Stamper"
new zclass_desc[32] = "Making 'Iron Maiden'"
new Float:zclass_speed = 280.0
new Float:zclass_gravity = 0.75
new Float:zclass_knockback = 0.9
new Float:zclass_defense = 1.15
new Float:zclass_clawrange = 48.0

new const zclass_modelorigin[] = "ev_stamper_origin"
new const zclass_modelhost[] = "ev_stamper_host"
new const zclass_clawmodel_origin[] = "v_claw_stamper.mdl"
new const zclass_clawmodel_host[] = "v_claw_stamper.mdl"
new const zclass_deathsound[] = "zombie_evolution/zombie/stamper_death.wav"
new const zclass_painsound[] = "zombie_evolution/zombie/stamper_hurt.wav"
new const zclass_permcode = 8

new const CoffinModel[] = "models/zombie_evolution/iron_maiden.mdl"
new const CoffinSound[3][] = 
{
	"zombie_evolution/zombie/stamper_ironmaiden.wav",
	"zombie_evolution/zombie/stamper_ironmaiden_broken.wav",
	"zombie_evolution/zombie/stamper_ironmaiden_explosion.wav"
}
new const Zombie_StabSound[3][] =
{
	"zombie_evolution/zombie/zombi_attack_1.wav",
	"zombie_evolution/zombie/zombi_attack_2.wav",
	"zombie_evolution/zombie/zombi_attack_3.wav"
}
new const CoffinExp[] = "sprites/zombie_evolution/zombiegrenade_exp.spr"
new const SlowSpr[] = "sprites/zombie_evolution/head_slow.spr"

enum
{
	COFFIN_NONE = 0,
	COFFIN_FALL,
	COFFIN_STAND,
	COFFIN_SAYONARA
}

// Task
#define TASK_MAKING 27001
#define TASK_SLOW 27002

#define COFFIN_CLASSNAME "coffin"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_zombieclass, g_MaxPlayers
new g_MsgFov, g_ZombieHud, g_CoffinExp_SprID, g_Wood_SprID, g_Beam_SprID
new g_CanMake, g_MakeTime[33], g_HamReg

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	register_think(COFFIN_CLASSNAME, "fw_CoffinThink")
	register_touch(COFFIN_CLASSNAME, "player", "fw_CoffinTouch")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	
	g_MaxPlayers = get_maxplayers()
	g_MsgFov = get_user_msgid("SetFOV")
	g_ZombieHud = CreateHudSyncObj(3)
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	formatex(GameName, sizeof(GameName), "%L", LANG_SERVER, "GAME_NAME")
	
	// Precache
	precache_model(CoffinModel)
	for(new i = 0; i < sizeof(CoffinSound); i++)
		precache_sound(CoffinSound[i])
	for(new i = 0; i < sizeof(Zombie_StabSound); i++)
		precache_sound(Zombie_StabSound[i])
	g_CoffinExp_SprID = precache_model(CoffinExp)
	g_Wood_SprID = engfunc(EngFunc_PrecacheModel, "models/woodgibs.mdl")
	g_Beam_SprID = engfunc(EngFunc_PrecacheModel, "sprites/shockwave.spr")
	precache_model(SlowSpr)
	
	// Zombie Class
	Load_Class_Setting()
	g_zombieclass = zevo_register_zombieclass(zclass_name, zclass_desc, zclass_speed, zclass_gravity, zclass_knockback, zclass_defense, zclass_clawrange, zclass_modelorigin, zclass_modelhost, zclass_clawmodel_origin, zclass_clawmodel_host, zclass_deathsound, zclass_painsound, zclass_permcode)
}

public client_putinserver(id)
{
	Safety_Connected(id)
	
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Register_HamBot", id)
	}
}

public Register_HamBot(id) 
{
	Register_SafetyFuncBot(id)
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack")
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public zevo_user_spawn(id)
{
	remove_task(id+TASK_MAKING)
	remove_task(id+TASK_SLOW)
	
	UnSet_BitVar(g_CanMake, id)
	g_MakeTime[id] = 0
}

public zevo_become_zombie(id, attacker, zombieclass)
{
	// Reset
	remove_task(id+TASK_MAKING)
	remove_task(id+TASK_SLOW)

	if(zombieclass == g_zombieclass)
	{
		Set_BitVar(g_CanMake, id)
		g_MakeTime[id] = 0
	} else {
		UnSet_BitVar(g_CanMake, id)
		g_MakeTime[id] = 0
	}
}

public zevo_zombieclass_deactivate(id, ClassID)
{
	if(ClassID == g_zombieclass)
	{
		// Reset
		remove_task(id+TASK_MAKING)
		remove_task(id+TASK_SLOW)
		
		UnSet_BitVar(g_CanMake, id)
		g_MakeTime[id] = 0
	}
}

public zevo_runningtime2(id, Time)
{
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
		
	// Cooldown
	if(g_MakeTime[id] > 0) 
	{
		g_MakeTime[id]--
		if(!g_MakeTime[id]) 
			Set_BitVar(g_CanMake, id)
	}
	
	// Hud
	static Skill1[32], Skill2[32], Special[16]
	formatex(Special, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LVREQ", 2)
	
	if(!g_MakeTime[id]) 
	{
		formatex(Skill1, 31, "[G] : %L", GAME_LANG, "ZOMBIE_STAMPER_SKILL_STAMP")
		if(zevo_get_playerlevel(id) >= 2) formatex(Skill2, 31, "[F] : %L", GAME_LANG, "ZOMBIE_STAMPER_SKILL_IRON")
		else formatex(Skill2, 31, "[F] : %L (%s)", GAME_LANG, "ZOMBIE_STAMPER_SKILL_IRON", Special)
	} else {
		formatex(Skill1, 31, "[G] : %L (%i)", GAME_LANG, "ZOMBIE_STAMPER_SKILL_STAMP", g_MakeTime[id])
		if(zevo_get_playerlevel(id) >= 2) formatex(Skill2, 31, "[F] : %L (%i)", GAME_LANG, "ZOMBIE_STAMPER_SKILL_IRON", g_MakeTime[id])
		else formatex(Skill2, 31, "[F] : %L (%s)", GAME_LANG, "ZOMBIE_STAMPER_SKILL_IRON", Special)
	}
	
	set_hudmessage(255, 212, 42, -1.0, 0.10, 0, 2.0, 2.0)
	ShowSyncHudMsg(id, g_ZombieHud, "[%s]^n^n%s^n%s", zclass_name, Skill1, Skill2)
}

public zevo_zombieskill(id, ClassID, SkillButton)
{
	if(ClassID != g_zombieclass)
		return
	
	switch(SkillButton)
	{
		case SKILL_G: Skill_Stamp(id)
		case SKILL_F: Skill_Iron(id)
	}
}

public Skill_Stamp(id)
{
	if(!Get_BitVar(g_CanMake, id))
		return
	if((pev(id, pev_flags) & FL_DUCKING) || !(pev(id, pev_flags) & FL_ONGROUND))
		return
		
	UnSet_BitVar(g_CanMake, id)
	g_MakeTime[id] = STAMP_COOLDOWN
	
	// Prepartion
	zevo_speed_set(id, 0.01, 1)
	SetFov(id, STAMP_FOV)
	set_pev(id, pev_velocity, {0.0, 0.0, 0.0})
	
	engclient_cmd(id, "weapon_knife")
	zevo_set_fakeattack(id, 143)
	set_pev(id, pev_framerate, 0.75)
	Set_Player_NextAttack(id, 1.0)
	set_weapons_timeidle(id, CSW_KNIFE, 1.1)
	
	Set_WeaponAnim(id, 2)

	remove_task(id+TASK_MAKING)
	set_task(0.5, "Make_Coffin", id+TASK_MAKING)
}

public Skill_Iron(id)
{
	if(zevo_get_playerlevel(id) <= 1)
		return
	if(!Get_BitVar(g_CanMake, id))
		return
	if((pev(id, pev_flags) & FL_DUCKING) || !(pev(id, pev_flags) & FL_ONGROUND))
		return
		
	UnSet_BitVar(g_CanMake, id)
	g_MakeTime[id] = IRON_COOLDOWN
	
	// Prepartion
	zevo_speed_set(id, 0.001, 1)
	SetFov(id, STAMP_FOV)
	set_pev(id, pev_velocity, {0.0, 0.0, 0.0})
	
	engclient_cmd(id, "weapon_knife")
	zevo_set_fakeattack(id, 143)
	set_pev(id, pev_framerate, 0.75)
	Set_Player_NextAttack(id, 1.0)
	set_weapons_timeidle(id, CSW_KNIFE, 1.1)
	
	Set_WeaponAnim(id, 2)

	remove_task(id+TASK_MAKING)
	set_task(0.5, "Make_Coffin2", id+TASK_MAKING)
}

public Make_Coffin(id)
{
	id -= TASK_MAKING
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
		
	SetFov(id)
	zevo_speed_set(id, zclass_speed, 1)
	set_pev(id, pev_framerate, 2.0)
	
	static Coffin; Coffin = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Coffin)) return
	
	// Origin & Angles
	static Float:Origin[3]; get_position(id, 48.0, 0.0, 0.0, Origin)
	static Float:Angles[3]; pev(id, pev_v_angle, Angles)
	
	Origin[2] += 16.0; Angles[0] = 0.0
	
	set_pev(Coffin, pev_origin, Origin)
	set_pev(Coffin, pev_angles, Angles)
	set_pev(Coffin, pev_v_angle, Angles)
	
	// Set Coffin Data
	set_pev(Coffin, pev_takedamage, DAMAGE_YES)
	set_pev(Coffin, pev_health, 10000.0 + COFFIN_HEALTH)
	
	set_pev(Coffin, pev_classname, COFFIN_CLASSNAME)
	engfunc(EngFunc_SetModel, Coffin, CoffinModel)
	
	set_pev(Coffin, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(Coffin, pev_solid, SOLID_BBOX)
	
	static Float:mins[3]; mins[0] = -16.0; mins[1] = -16.0; mins[2] = -36.0
	static Float:maxs[3]; maxs[0] = 16.0; maxs[1] = 16.0; maxs[2] = 36.0
	engfunc(EngFunc_SetSize, Coffin, mins, maxs)
	
	// Set State
	set_pev(Coffin, pev_iuser1, id)
	set_pev(Coffin, pev_iuser2, COFFIN_FALL)
	set_pev(Coffin, pev_fuser1, get_gametime() + float(STAMP_HOLDTIME))
	
	if(!g_HamReg)
	{
		g_HamReg = 1
		RegisterHamFromEntity(Ham_TraceAttack, Coffin, "fw_CoffinTrace")
	}
	
	// Set Next Think
	set_pev(Coffin, pev_nextthink, get_gametime() + 0.1)
}

public Make_Coffin2(id)
{
	id -= TASK_MAKING
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
		
	SetFov(id)
	zevo_speed_set(id, zclass_speed, 1)
	set_pev(id, pev_framerate, 2.0)
	
	static Float:Origin[6][3], Float:Angles[3]
	
	get_position(id, 60.0, 0.0, 16.0, Origin[0])
	get_position(id, 60.0, -36.0, 16.0, Origin[1])
	get_position(id, 60.0, 36.0, 16.0, Origin[2])
	get_position(id, 90.0, -20.0, 16.0, Origin[3])
	get_position(id, 90.0, 20.0, 16.0, Origin[4])
	get_position(id, 120.0, 0.0, 16.0, Origin[5])
	
	pev(id, pev_v_angle, Angles); Angles[0] = 0.0; 
	
	for(new i = 0; i < 6; i++)
	{
		static Coffin; Coffin = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
		if(!pev_valid(Coffin)) return
		
		set_pev(Coffin, pev_origin, Origin[i])
		set_pev(Coffin, pev_angles, Angles)
		set_pev(Coffin, pev_v_angle, Angles)
		
		// Set Coffin Data
		set_pev(Coffin, pev_takedamage, DAMAGE_YES)
		set_pev(Coffin, pev_health, 10000.0 + COFFIN_HEALTH)
		
		set_pev(Coffin, pev_classname, COFFIN_CLASSNAME)
		engfunc(EngFunc_SetModel, Coffin, CoffinModel)
		
		set_pev(Coffin, pev_movetype, MOVETYPE_PUSHSTEP)
		set_pev(Coffin, pev_solid, SOLID_BBOX)
		set_pev(Coffin, pev_gravity, 5.0)
		
		static Float:mins[3]; mins[0] = -10.0; mins[1] = -10.0; mins[2] = -36.0
		static Float:maxs[3]; maxs[0] = 10.0; maxs[1] = 10.0; maxs[2] = 36.0
		engfunc(EngFunc_SetSize, Coffin, mins, maxs)
		
		// Set State
		set_pev(Coffin, pev_iuser1, id)
		set_pev(Coffin, pev_iuser2, COFFIN_FALL)
		set_pev(Coffin, pev_fuser1, get_gametime() + float(STAMP_HOLDTIME) + random_float(1.0, 5.0))
		
		if(!g_HamReg)
		{
			g_HamReg = 1
			RegisterHamFromEntity(Ham_TraceAttack, Coffin, "fw_CoffinTrace")
		}
		
		// Set Next Think
		set_pev(Coffin, pev_nextthink, get_gametime() + 0.1)
	}
}

public fw_CoffinThink(Ent)
{
	if(!pev_valid(Ent))
		return
	if((pev(Ent, pev_health) - 10000.0) <= 0.0)
	{
		Coffin_Explosion(Ent)
		return
	}
	
	static id; id = pev(Ent, pev_iuser1)
	if(is_alive(id) && !zevo_is_zombie(id))
	{
		Coffin_Break(Ent)
		return
	}
	
	switch(pev(Ent, pev_iuser2))
	{
		case COFFIN_FALL:
		{
			if(is_entity_stuck(Ent))
			{
				Coffin_Explosion(Ent)
				return
			}
			
			if(!(pev(Ent, pev_flags) & FL_ONGROUND))
			{
				// Set Next Think
				set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
				return
			}
			
			Make_StampingEffect(Ent)
			
			//set_pev(Ent, pev_movetype, MOVETYPE_NONE)
			set_pev(Ent, pev_iuser2, COFFIN_STAND)
		}
		case COFFIN_STAND:
		{
			if(pev(Ent, pev_fuser1) <= get_gametime())
			{
				Coffin_Break(Ent)
				return
			}
		}
	}
		
	// Set Next Think
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public fw_CoffinTouch(Ent, id)
{
	if(!pev_valid(Ent) || !is_alive(id))
		return
		
	static Button; Button = get_user_button(id)
	
	if(Button & IN_USE)
	{
		static Float:Vel[3]; 
		pev(id, pev_velocity, Vel)
		xs_vec_mul_scalar(Vel, 0.75, Vel)
		set_pev(Ent, pev_velocity, Vel)
	}
}

public Coffin_Break(Ent)
{
	Coffin_BreakEffect(Ent)
	
	// Remove Ent
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01)
	set_pev(Ent, pev_flags, FL_KILLME)
}

public Coffin_Explosion(Ent)
{
	static Float:Origin[3]
	pev(Ent, pev_origin, Origin)
	
	// Exp Spr
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] - 26.0)
	write_short(g_CoffinExp_SprID)
	write_byte(20)
	write_byte(30)
	write_byte(14)
	message_end()
	
	Coffin_BreakEffect(Ent)
	EmitSound(Ent, CHAN_BODY, CoffinSound[2])
	
	Check_KnockPower(Ent)
	
	// Remove Ent
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01)
	set_pev(Ent, pev_flags, FL_KILLME)
}

public Check_KnockPower(Ent)
{
	static Float:Origin[3]
	pev(Ent, pev_origin, Origin)
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(entity_range(Ent, i) > 120.0)
			continue
		
		ScreenShake(i)
		hook_ent3(i, Origin, COFFIN_KNOCKPOWER, 1.0, 2)
	}
}

public ScreenShake(id)
{
	static MSG; if(!MSG) MSG = get_user_msgid("ScreenShake")
	
	// ScreenShake
	message_begin(MSG_ONE_UNRELIABLE, MSG, {0,0,0}, id)
	write_short((1<<12) * 10)
	write_short((1<<12) * 2)
	write_short((1<<12) * 10)
	message_end()  
}

public Coffin_BreakEffect(Ent)
{
	static Float:Origin[3]
	pev(Ent, pev_origin, Origin)
	
	// Break Model
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_BREAKMODEL)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] - 36.0)
	engfunc(EngFunc_WriteCoord, 36)
	engfunc(EngFunc_WriteCoord, 36)
	engfunc(EngFunc_WriteCoord, 36)
	engfunc(EngFunc_WriteCoord, random_num(-25, 25))
	engfunc(EngFunc_WriteCoord, random_num(-25, 25))
	engfunc(EngFunc_WriteCoord, 25)
	write_byte(20)
	write_short(g_Wood_SprID)
	write_byte(10)
	write_byte(25)
	write_byte(0x08) // 0x08 = Wood
	message_end()
	
	EmitSound(Ent, CHAN_ITEM, CoffinSound[1])
}

public Make_StampingEffect(Ent)
{
	static Float:Origin[3]
	pev(Ent, pev_origin, Origin)
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_BEAMCYLINDER)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] - 16.0)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 150.0)
	write_short(g_Beam_SprID)
	write_byte(0)
	write_byte(0)
	write_byte(4)
	write_byte(15)
	write_byte(0)
	write_byte(100)
	write_byte(100)
	write_byte(100)
	write_byte(50)
	write_byte(0)
	message_end()	
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(entity_range(Ent, i) > 240.0)
			continue
		if(zevo_is_zombie(i))
			continue
		
		zevo_speed_set(i, STAMP_SLOWSPEED, 1)
		zevo_playerattachment(i, SlowSpr, STAMP_SLOWTIME, 0.5, 0.0)
		
		remove_task(i+TASK_SLOW)
		set_task(STAMP_SLOWTIME, "Remove_Slowdown", i+TASK_SLOW)
	}
	
	EmitSound(Ent, CHAN_BODY, CoffinSound[0])
}

public Remove_Slowdown(id)
{
	id -= TASK_SLOW
	
	if(!is_alive(id))
		return
	if(zevo_is_zombie(id))
		return
		
	zevo_speed_reset(id)
}

public fw_CoffinTrace(ent, attacker, Float: damage, Float: direction[3], trace, damageBits)
{
	if(!pev_valid(ent)) return HAM_IGNORED
	if(!is_alive(attacker)) return HAM_IGNORED
	
	if(zevo_is_zombie(attacker) && get_user_weapon(attacker) == CSW_KNIFE)
	{
		SetHamParamFloat(3, 125.0)
		EmitSound(attacker, CHAN_WEAPON, Zombie_StabSound[random_num(0, sizeof(Zombie_StabSound) - 1)])
		
		return HAM_IGNORED
	}
	
	return HAM_IGNORED
}

public fw_TraceAttack(Victim, Attacker, Float:Damage, Float:Direction[3], TrResult, DamageType)
{
	if(!is_connected(Victim) || !is_connected(Attacker))
		return HAM_IGNORED
		
	static Float:OriginA[3], Float:OriginB[3]
	
	pev(Attacker, pev_origin, OriginA)
	pev(Victim, pev_origin, OriginB)
	
	if(Is_Coffin_Between(Attacker, OriginA, OriginB))
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

public EmitSound(id, chan, const file_sound[]) emit_sound(id, chan, file_sound, 1.0, ATTN_NORM, 0, PITCH_NORM)

public Load_Class_Setting()
{
	static Temp[128]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_SERVER, "ZOMBIE_STAMPER_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_SERVER, "ZOMBIE_STAMPER_DESC")
	
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "STAMPER_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "STAMPER_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "STAMPER_KNOCKBACK", Temp, sizeof(Temp)); zclass_knockback = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "STAMPER_DEFENSE", Temp, sizeof(Temp)); zclass_defense = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "STAMPER_CLAWRANGE", Temp, sizeof(Temp)); zclass_clawrange = str_to_float(Temp)
}

stock SetFov(id, num = 90)
{
	message_begin(MSG_ONE_UNRELIABLE, g_MsgFov, {0,0,0}, id)
	write_byte(num)
	message_end()
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
	if(pev_valid(id) != 2)
		return
		
	set_pdata_float(id, 83, Time, 5)
}

stock Get_SpeedVector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= (num * 2.0)
	new_velocity[1] *= (num * 2.0)
	new_velocity[2] *= (num / 2.0)
}  

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs, vUp) //for player
	xs_vec_add(vOrigin, vUp, vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	vAngle[0] = 0.0
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD, vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT, vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP, vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock hook_ent2(ent, Float:VicOrigin[3], Float:speed)
{
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	
	pev(ent, pev_origin, EntOrigin)
	
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	fl_Time = distance_f / speed
		
	fl_Velocity[0] = (VicOrigin[0] - EntOrigin[0]) / fl_Time
	fl_Velocity[1] = (VicOrigin[1] - EntOrigin[1]) / fl_Time
	fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time

	set_pev(ent, pev_velocity, fl_Velocity)
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

stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}

stock is_entity_stuck(ent)
{
	static Float:originF[3]
	pev(ent, pev_origin, originF)
	
	engfunc(EngFunc_TraceHull, originF, originF, 0, (pev(ent, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN, ent, 0)
	
	if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
		return 1
	
	return 0
}

public Is_Coffin_Between(Ignore, Float:OriginA[3], Float:OriginB[3])
{
	static Ptr; Ptr = create_tr2()
	engfunc(EngFunc_TraceLine, OriginA, OriginB, DONT_IGNORE_MONSTERS, Ignore, Ptr)
	
	static pHit; pHit = get_tr2(Ptr, TR_pHit)
	free_tr2(Ptr)
	
	if(!pev_valid(pHit))
		return 0

	static Classname[32]; pev(pHit, pev_classname, Classname, sizeof(Classname))
	if(!equal(Classname, COFFIN_CLASSNAME)) 
		return 0
		
	return 1
}

stock hook_ent3(ent, Float:VicOrigin[3], Float:speed, Float:multi, type)
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
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
