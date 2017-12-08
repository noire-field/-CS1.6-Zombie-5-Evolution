#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <zombie_evolution>

#define PLUGIN "[Mileage] Equipment: Plasma Grenade"
#define VERSION "2014"
#define AUTHOR "Dias 'Pendragon' Leon"

#define DAMAGE 600 // 800 for Zombies
#define GRENADE_RADIUS 350.0

#define CSW_PLASMAGRENADE CSW_HEGRENADE
#define weapon_plasmagrenade "weapon_hegrenade"

#define MODEL_V "models/mileage_wpn/equip/v_sfgrenade.mdl"
#define MODEL_P "models/mileage_wpn/equip/p_sfgrenade.mdl"
#define MODEL_W "models/mileage_wpn/equip/w_sfgrenade.mdl"

new const GrenadeSounds[4][] = 
{
	"weapons/sfgrenade_explode.wav",
	"weapons/sfgrenade_deploy.wav",
	"weapons/sfgrenade_pullpin.wav",
	"weapons/sfgrenade_ready.wav"
}

#define EXPLOSION_SPRITE "sprites/explodeup.spr"

#define PLASMAGRE_SECRETCODE 231114
#define MODEL_W_OLD "models/w_hegrenade.mdl"

#define Get_BitVar(%1,%2)		(%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2)		(%1 |= (1 << (%2 & 31)));
#define UnSet_BitVar(%1,%2)		(%1 &= ~(1 << (%2 & 31)));

const pev_code = pev_iuser1
const pev_entteam = pev_iuser2
const pev_victim = pev_iuser3
const pev_work = pev_iuser4

const pev_time = pev_fuser1

enum
{
	TEAM_NONE = 0,
	TEAM_T,
	TEAM_CT
}

new g_PlasmaGrenade
new g_Had_PlasmaGrenade
new g_ExpSprId, g_SmokeSprId, g_MaxPlayers

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_Touch, "fw_Touch")
	
	RegisterHam(Ham_Think, "grenade", "fw_ThinkGrenade")
	RegisterHam(Ham_Item_Deploy, weapon_plasmagrenade, "fw_Item_Deploy_Post", 1)	
	
	g_MaxPlayers = get_maxplayers()
	g_PlasmaGrenade = Mileage_RegisterWeapon("plasmagrenade")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	for(new i = 0; i < sizeof(GrenadeSounds); i++)
		precache_sound(GrenadeSounds[i])
	
	g_ExpSprId = precache_model(EXPLOSION_SPRITE)
	g_SmokeSprId = engfunc(EngFunc_PrecacheModel, "sprites/steam1.spr")
}

public Mileage_WeaponGet(id, ItemID)
{
	if(ItemID == g_PlasmaGrenade) Get_PlasmaGrenade(id)
}

public Mileage_WeaponRefillAmmo(id, ItemID)
{
	if(ItemID == g_PlasmaGrenade) Get_PlasmaGrenade(id)
}

public Mileage_WeaponRemove(id, ItemID)
{
	if(ItemID == g_PlasmaGrenade) UnSet_BitVar(g_Had_PlasmaGrenade, id)
}

public Get_PlasmaGrenade(id)
{
	Set_BitVar(g_Had_PlasmaGrenade, id)
	give_item(id, weapon_plasmagrenade)
	
	if(get_user_weapon(id) == CSW_PLASMAGRENADE)
	{
		set_pev(id, pev_viewmodel2, MODEL_V)
		set_pev(id, pev_weaponmodel2, MODEL_P)
	}
}

public fw_SetModel(Ent, const Model[])
{
	if(!pev_valid(Ent))
		return FMRES_IGNORED
		
	static Classname[32]; pev(Ent, pev_classname, Classname, sizeof(Classname))
	if(equal(Model, MODEL_W_OLD))
	{
		static Id; Id = pev(Ent, pev_owner)
		
		if(Get_BitVar(g_Had_PlasmaGrenade, Id))
		{
			engfunc(EngFunc_SetModel, Ent, MODEL_W)
			
			set_pev(Ent, pev_entteam, Get_PlayerTeam(Id))
			set_pev(Ent, pev_code, PLASMAGRE_SECRETCODE)
			set_pev(Ent, pev_victim, 0)
			set_pev(Ent, pev_work, 0)
			
			UnSet_BitVar(g_Had_PlasmaGrenade, Id)
			
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED	
}

public fw_Touch(Grenade, Target)
{
	if(!pev_valid(Grenade))
		return
		
	static ClassName[32]; pev(Grenade, pev_classname, ClassName, sizeof(ClassName))
	if(equal(ClassName, "grenade"))
	{
		if(pev(Grenade, pev_code) != PLASMAGRE_SECRETCODE)
			return
		if(pev(Grenade, pev_work))
			return
			
		if(is_user_alive(Target)) // Player
		{
			set_pev(Grenade, pev_victim, Target)
			set_pev(Grenade, pev_work, 1)
		} else { // Wall
			set_pev(Grenade, pev_movetype, MOVETYPE_NONE)
			set_pev(Grenade, pev_velocity, {0.0, 0.0, 0.0})
			set_pev(Grenade, pev_work, 2)
		}
	}
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_PlasmaGrenade, Id))
		return

	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
}

public fw_ThinkGrenade(Ent)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
	if(pev(Ent, pev_code) != PLASMAGRE_SECRETCODE)
		return HAM_IGNORED
		
	if(pev(Ent, pev_work) == 1)
	{
		static Target; Target = pev(Ent, pev_victim)
		if(is_user_alive(Target))
		{
			static Float:Origin[3];
			pev(Target, pev_origin, Origin)
			
			Hook_Ent(Ent, Origin, 100.0)
		} else {
			PlasmaGrenade_Explosion(Ent)
	
			engfunc(EngFunc_RemoveEntity, Ent)
			return HAM_SUPERCEDE
		}
	}
	
	if(pev(Ent, pev_work) != 0 && (get_gametime() - 0.1 > pev(Ent, pev_time)))
	{
		if(pev(Ent, pev_renderfx) != kRenderFxGlowShell) 
		{
			set_pev(Ent, pev_rendermode, kRenderTransAdd)
			set_pev(Ent, pev_renderfx, kRenderFxGlowShell)
			set_pev(Ent, pev_renderamt, 100.0)
		} else {
			set_pev(Ent, pev_rendermode, kRenderTransAlpha)
			set_pev(Ent, pev_renderfx, kRenderFxNone)
			set_pev(Ent, pev_renderamt, 255.0)
		}
		
		set_pev(Ent, pev_time, get_gametime())
	}
		
	static Float:Time; pev(Ent, pev_dmgtime, Time)
	if(Time > get_gametime())
		return HAM_IGNORED
	
	PlasmaGrenade_Explosion(Ent)
	
	engfunc(EngFunc_RemoveEntity, Ent)
	return HAM_SUPERCEDE
}

public PlasmaGrenade_Explosion(Ent)
{
	static Float:Origin[3];
	pev(Ent, pev_origin, Origin)
	
	// Do Effect
	static ExpFlag; ExpFlag = 0
	ExpFlag |= 2; ExpFlag |= 4; ExpFlag |= 8
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 36.0)
	write_short(g_ExpSprId)
	write_byte(20)	// scale in 0.1's
	write_byte(30)	// framerate
	write_byte(ExpFlag)	// flags
	message_end()  
	
	// Put decal on "world" (a wall)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_WORLDDECAL)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_byte(random_num(46, 48))
	message_end()	
	
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_SMOKE)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_SmokeSprId)	// sprite index 
	write_byte(30)	// scale in 0.1's 
	write_byte(10)	// framerate 
	message_end()
	
	// Play Sound
	emit_sound(Ent, CHAN_BODY, GrenadeSounds[0], 1.0, ATTN_NORM, 0, PITCH_HIGH)
	emit_sound(Ent, CHAN_WEAPON, GrenadeSounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)

	static Float:PlayerOrigin[3], Owner, Team;
	
	Owner = pev(Ent, pev_owner)
	Team = pev(Ent, pev_entteam)
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_user_alive(i))
			continue
		if(Get_PlayerTeam(i) == Team)
			continue
		pev(i, pev_origin, PlayerOrigin)
		if(get_distance_f(Origin, PlayerOrigin) > GRENADE_RADIUS)
			continue
			
		if(!is_user_connected(Owner)) Owner = i
		Check_Damage(i, Owner, Origin, PlayerOrigin)
	}
}

public Check_Damage(Victim, Attacker, Float:Start[3], Float:VicOrigin[3])
{
	static Float:FinalDamage;
	FinalDamage = float(DAMAGE) - ((float(DAMAGE) / GRENADE_RADIUS) * get_distance_f(Start, VicOrigin))
	
	ExecuteHamB(Ham_TakeDamage, Victim, "grenade", Attacker, FinalDamage, DMG_BURN)
}

stock Get_PlayerTeam(id)
{
	if(!is_user_alive(id))
		return TEAM_NONE
		
	if(cs_get_user_team(id) == CS_TEAM_T) return TEAM_T
	else if(cs_get_user_team(id) == CS_TEAM_CT) return TEAM_CT
	
	return TEAM_NONE
}

stock Hook_Ent(ent, Float:VicOrigin[3], Float:speed)
{
	if(!pev_valid(ent))
		return
	
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	
	pev(ent, pev_origin, EntOrigin)
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	fl_Time = distance_f / speed
		
	fl_Velocity[0] = (VicOrigin[0] - EntOrigin[0]) / fl_Time
	fl_Velocity[1] = (VicOrigin[1] - EntOrigin[1]) / fl_Time
	fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time
	
	set_pev(ent, pev_velocity, fl_Velocity)
}
