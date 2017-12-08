#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <zombie_evolution>
#include <cstrike>
#include <fun>

#define PLUGIN "[ZEVO] Addon: Zombie Grenade"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define GAME_LANG LANG_SERVER
#define LANG_FILE "zombie_evolution.txt"

#define RADIUS 240
#define KNOCKPOWER 800

new const ModelP[] = "models/zombie_evolution/zombie/p_zombiegrenade.mdl"
new const ModelW[] = "models/zombie_evolution/zombie/w_zombiegrenade.mdl"
new const ModelV[10][] =
{
	"v_grenade_regular.mdl",
	"v_grenade_light.mdl",
	"v_grenade_heavy.mdl",
	"v_grenade_psycho.mdl",
	"v_grenade_voodoo.mdl",
	"v_grenade_deimos_host.mdl",
	"v_grenade_banshee.mdl",
	"v_grenade_stamper.mdl",
	"v_grenade_stingfinger.mdl",
	"v_grenade_venomguard.mdl"
}

new const ModelV2[2][] =
{
	"v_grenade_light_inv.mdl",
	"v_grenade_deimos_origin.mdl"
}

new const GrenadeSound[5][] =
{
	"zombie_evolution/zombie/grenade/zombiegrenade_bounce1.wav",
	"zombie_evolution/zombie/grenade/zombiegrenade_bounce2.wav",
	"zombie_evolution/zombie/grenade/zombiegrenade_deploy.wav",
	"zombie_evolution/zombie/grenade/zombiegrenade_pull.wav",
	"zombie_evolution/zombie/grenade/zombiegrenade_throw.wav"
}

new const ExpSound[] = "zombie_evolution/action/zombiegrenade_exp.wav"
new const GrenadeExp[] = "sprites/zombie_evolution/zombiegrenade_exp.spr"
new const GrenadeExp2[] = "sprites/zombie_evolution/zombiegrenade_exp2.spr"
new const GodEffect[] = "sprites/zombie_evolution/head_god.spr"

// Shared Code
#define PDATA_SAFE 2
#define OFFSET_CSTEAMS 114
#define OFFSET_CSDEATHS 444
#define OFFSET_PLAYER_LINUX 5
#define OFFSET_WEAPON_LINUX 4
#define OFFSET_WEAPONOWNER 41

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_ExpID, g_ExpID2, g_MaxPlayers

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_SetModel, "fw_SetModel")	
	RegisterHam(Ham_Item_Deploy, "weapon_hegrenade", "fw_Item_Deploy_Post", 1)
	RegisterHam(Ham_Item_Deploy, "weapon_flashbang", "fw_Item_Deploy_Post", 1)
	RegisterHam(Ham_Think, "grenade", "fw_ThinkGrenade")
	
	g_MaxPlayers = get_maxplayers()
	
	register_dictionary(LANG_FILE)
	Register_SafetyFunc()
}

public plugin_precache()
{
	static Buffer[100]
	
	precache_model(ModelP)
	precache_model(ModelW)
	for(new i = 0; i < sizeof(ModelV); i++)
	{
		formatex(Buffer, 99, "models/zombie_evolution/zombie/%s", ModelV[i])
		precache_model(Buffer)
	}
	for(new i = 0; i < sizeof(ModelV2); i++)
	{
		formatex(Buffer, 99, "models/zombie_evolution/zombie/%s", ModelV2[i])
		precache_model(Buffer)
	}
	
	for(new i = 0; i < sizeof(GrenadeSound); i++)
		precache_sound(GrenadeSound[i])
		
	precache_sound(ExpSound)
	precache_model(GodEffect)
	g_ExpID = precache_model(GrenadeExp)
	g_ExpID2 = precache_model(GrenadeExp2)
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
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public zevo_become_zombie(id, Attacker, Class)
{
	if(is_connected(id) && is_connected(Attacker))
		zevo_playerattachment(id, GodEffect, 1.5, 0.35, 0.0)
}

public fw_SetModel(Ent, const Model[])
{
	if(!pev_valid(Ent))
		return FMRES_IGNORED;

	static Float:dmgtime
	pev(Ent, pev_dmgtime, dmgtime)
	
	if(dmgtime == 0.0) return FMRES_IGNORED;
	
	// Get attacker
	static id; id = pev(Ent, pev_owner)
	if(is_connected(id) && zevo_is_zombie(id))
	{
		if(Model[9] == 'h' && Model[10] == 'e') // Zombie Bomb
		{
			set_pev(Ent, pev_flTimeStepSound, 1246)
			engfunc(EngFunc_SetModel, Ent, ModelW)

			return FMRES_SUPERCEDE
		} else if(Model[9] == 'f' && Model[10] == 'l') // Zombie Bomb 2
		{
			set_pev(Ent, pev_dmgtime, dmgtime + 1.75)
			
			set_pev(Ent, pev_flTimeStepSound, 1247)
			engfunc(EngFunc_SetModel, Ent, ModelW)

			return FMRES_SUPERCEDE
		}
	}
	
	return FMRES_IGNORED
}

public fw_Item_Deploy_Post(Ent)
{
	static id; id = fm_cs_get_weapon_ent_owner(Ent)
	if (!is_alive(id))
		return;
	if(!zevo_is_zombie(id))
		return
	
	static CSWID; CSWID = cs_get_weapon_id(Ent)
	if(CSWID == CSW_HEGRENADE || CSWID == CSW_FLASHBANG)
	{
		static ZombieCode; ZombieCode = zevo_get_zombiecode(zevo_get_zombieclass(id))
		static Model[80];
		
		switch(ZombieCode)
		{
			case 2: 
			{
				ZombieCode--
				if(!zevo_is_usingskill(id)) formatex(Model, 79, "models/zombie_evolution/zombie/%s", ModelV[ZombieCode])
				else formatex(Model, 79, "models/zombie_evolution/zombie/%s", ModelV2[0])
			}
			case 6:
			{
				ZombieCode--
				if(zevo_get_playerlevel(id) <= 1) formatex(Model, 79, "models/zombie_evolution/zombie/%s", ModelV[ZombieCode])
				else formatex(Model, 79, "models/zombie_evolution/zombie/%s", ModelV2[1])
			}
			default:
			{
				ZombieCode--
				formatex(Model, 79, "models/zombie_evolution/zombie/%s", ModelV[ZombieCode])
			}
		}
		
		set_pev(id, pev_viewmodel2, Model)
		set_pev(id, pev_weaponmodel2, ModelP)
	}
}

public fw_ThinkGrenade(Ent)
{
	if(!pev_valid(Ent)) return HAM_IGNORED

	static Float:dmgtime
	pev(Ent, pev_dmgtime, dmgtime)
	
	if(dmgtime - 2.0 <= get_gametime())
	{
		
		static Victim; Victim = -1
		static Float:Origin[3]; pev(Ent, pev_origin, Origin)
	
		while((Victim = find_ent_in_sphere(Victim, Origin, 16.0)) != 0)
		{
			if(!is_alive(Victim))
				continue
				
			break
		}
		
		if(is_alive(Victim) && pev(Ent, pev_flTimeStepSound) == 1247)
		{
			ZombieGrenade_Explosion(Ent)
			return HAM_SUPERCEDE
		}
	}
	
	if(dmgtime > get_gametime())
		return HAM_IGNORED
	if(pev(Ent, pev_flTimeStepSound) == 1246)
	{
		ZombieGrenade_Explosion(Ent)
		return HAM_SUPERCEDE
	} else if(pev(Ent, pev_flTimeStepSound) == 1247) {
		ZombieGrenade_Explosion(Ent)
		return HAM_SUPERCEDE
	}
	
	return HAM_IGNORED
}

public ZombieGrenade_Explosion(Ent)
{
	static Float:Origin[3]
	pev(Ent, pev_origin, Origin)
	
	// Make the explosion
	EffectZombieBomExp(Origin)
	engfunc(EngFunc_EmitSound, Ent, CHAN_WEAPON, ExpSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// Collisions
	static Float:MaxKB
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(entity_range(Ent, i) > float(RADIUS))
			continue
			
		ShakeScreen(i)
		
		ExecuteHamB(Ham_TakeDamage, i, 0, i, 0.0, DMG_SLASH)
		MaxKB = float(KNOCKPOWER) - (entity_range(Ent, i) * (float(KNOCKPOWER) / float(RADIUS)))
		HookEnt(i, Origin, MaxKB)
		
		if(!zevo_is_zombie(i))
		{
			static Float:Angles[3]
			pev(i, pev_v_angle, Angles)
			
			Angles[0] += random_float(-50.0, 50.0)
			Angles[0] = float(clamp(floatround(Angles[0]), -180, 180))
			
			Angles[1] += random_float(-50.0, 50.0)
			Angles[1] = float(clamp(floatround(Angles[1]), -180, 180))
			
			set_pev(i, pev_fixangle, 1)
			set_pev(i, pev_v_angle, Angles)
		}
	}

	// Remove
	engfunc(EngFunc_RemoveEntity, Ent)
}

public ShakeScreen(id)
{
	static MSG; if(!MSG) MSG = get_user_msgid("ScreenShake")

	message_begin(MSG_ONE_UNRELIABLE, MSG, {0,0,0}, id)
	write_short(1<<14)
	write_short(1<<13)
	write_short(1<<13)
	message_end()
}

public EffectZombieBomExp(Float:Origin[3])
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 16.0)
	write_short(g_ExpID)
	write_byte(30)
	write_byte(20)
	write_byte(14)
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 16.0)
	write_short(g_ExpID)
	write_byte(35)
	write_byte(20)
	write_byte(14)
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 16.0)
	write_short(g_ExpID2)
	write_byte(10)
	write_byte(15)
	write_byte(14)
	message_end()
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	// Prevent server crash if entity's private data not initalized
	if (pev_valid(ent) != PDATA_SAFE)
		return -1;
	
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_WEAPON_LINUX);
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

stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}

stock SetFov(id, num = 90)
{
	static g_MsgFov; 
	if(!g_MsgFov) g_MsgFov = get_user_msgid("SetFOV")
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgFov, {0,0,0}, id)
	write_byte(num)
	message_end()
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

stock HookEnt(ent, Float:VicOrigin[3], Float:speed)
{
	static Float:fl_Velocity[3]
	static Float:EntOrigin[3]
	
	pev(ent, pev_origin, EntOrigin)
	static Float:distance_f
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	
	static Float:fl_Time; fl_Time = distance_f / speed
	
	fl_Velocity[0] = ((EntOrigin[0] - VicOrigin[0]) / fl_Time) * 1.5
	fl_Velocity[1] = ((EntOrigin[1] - VicOrigin[1]) / fl_Time) * 1.5
	fl_Velocity[2] = (EntOrigin[2] - VicOrigin[2]) / fl_Time

	set_pev(ent, pev_velocity, fl_Velocity)
}

