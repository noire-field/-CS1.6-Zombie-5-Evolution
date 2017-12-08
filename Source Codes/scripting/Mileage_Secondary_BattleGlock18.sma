#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <zombie_evolution>
#include <fun>

#define PLUGIN "[Mileage] Secondary: Battle Glock-18"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define DAMAGE 24
#define RECOIL 3.0

#define SUBMODEL 1
#define SPECIALSHOOT_DELAY 0.1

#define V_MODEL "models/mileage_wpn/sec/v_bglock18.mdl"
#define P_MODEL "models/mileage_wpn/sec/p_secondary.mdl"
#define W_MODEL "models/mileage_wpn/sec/w_secondary.mdl"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

enum
{
	BWGLOCK_ANIM_IDLE1 = 0,
	BWGLOCK_ANIM_IDLE2,
	BWGLOCK_ANIM_IDLE3,
	BWGLOCK_ANIM_SHOOT_BURST1,
	BWGLOCK_ANIM_SHOOT_BURST2,
	BWGLOCK_ANIM_SHOOT,
	BWGLOCK_ANIM_SHOOT_EMPTY,
	BWGLOCK_ANIM_RELOAD,
	BWGLOCK_ANIM_DRAW,
	BWGLOCK_ANIM_HOLSTER,
	BWGLOCK_ANIM_ADD_SILENCER,
	BWGLOCK_ANIM_DRAW2,
	BWGLOCK_ANIM_RELOAD2
}

new g_Glock18
new g_Had_BWGlock, g_EventGlock18, PShell_Index, g_SmokePuff_SprId, g_InSpecialShoot, g_OldWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	RegisterHam(Ham_Item_AddToPlayer, "weapon_glock18", "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_Deploy, "weapon_glock18", "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_glock18", "fw_Weapon_SecondaryAttack")
	
	g_Glock18 = Mileage_RegisterWeapon("bglock18")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	engfunc(EngFunc_PrecacheModel, W_MODEL)
	
	PShell_Index = engfunc(EngFunc_PrecacheModel, "models/pshell.mdl")
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/glock18.sc", name)) g_EventGlock18 = get_orig_retval()		
}

public Mileage_WeaponGet(id, ItemID)
{
	if(ItemID == g_Glock18) Get_BWGlock(id)
}

public Mileage_WeaponRefillAmmo(id, ItemID)
{
	if(ItemID == g_Glock18) Give_RealAmmo(id, CSW_GLOCK18)
}

public Mileage_WeaponRemove(id, ItemID)
{
	if(ItemID == g_Glock18) Remove_BWGlock(id)
}

public Get_BWGlock(id)
{
	Set_BitVar(g_Had_BWGlock, id)
	UnSet_BitVar(g_InSpecialShoot, id)
	
	give_item(id, "weapon_glock18")
	Give_RealAmmo(id, CSW_GLOCK18)
}

public Remove_BWGlock(id)
{
	UnSet_BitVar(g_Had_BWGlock, id)
	UnSet_BitVar(g_InSpecialShoot, id)
}

public Event_CurWeapon(id)
{
	static CSWID; CSWID = read_data(2)
	
	if((CSWID == CSW_GLOCK18 && g_OldWeapon[id] != CSW_GLOCK18) && Get_BitVar(g_Had_BWGlock, id))
	{
		Draw_NewWeapon(id, CSWID)
	} else if((CSWID == CSW_GLOCK18 && g_OldWeapon[id] == CSW_GLOCK18) && Get_BitVar(g_Had_BWGlock, id)) {
		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_GLOCK18)
		if(!pev_valid(Ent))
		{
			g_OldWeapon[id] = get_user_weapon(id)
			return
		}
		set_pdata_float(Ent, 46, SPECIALSHOOT_DELAY, 4)
		set_pdata_float(Ent, 47, SPECIALSHOOT_DELAY, 4)
	} else if(CSWID != CSW_GLOCK18 && g_OldWeapon[id] == CSW_GLOCK18) Draw_NewWeapon(id, CSWID)
	
	g_OldWeapon[id] = get_user_weapon(id)
}

public Draw_NewWeapon(id, CSW_ID)
{
	if(CSW_ID == CSW_GLOCK18)
	{
		static ent
		ent = fm_get_user_weapon_entity(id, CSW_GLOCK18)
		
		if(pev_valid(ent) && Get_BitVar(g_Had_BWGlock, id))
		{
			set_pev(ent, pev_effects, pev(ent, pev_effects) &~ EF_NODRAW) 
			engfunc(EngFunc_SetModel, ent, P_MODEL)	
			set_pev(ent, pev_body, SUBMODEL)
		}
	} else {
		static ent
		ent = fm_get_user_weapon_entity(id, CSW_GLOCK18)
		
		if(pev_valid(ent)) set_pev(ent, pev_effects, pev(ent, pev_effects) | EF_NODRAW) 			
	}
	
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_GLOCK18 || !Get_BitVar(g_Had_BWGlock, invoker))
		return FMRES_IGNORED
	if(eventid != g_EventGlock18)
		return FMRES_IGNORED
	
	Weapon_Shoot(invoker)
		
	return FMRES_SUPERCEDE
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
	
	if(equal(model, "models/w_glock18.mdl"))
	{
		static weapon; weapon = fm_find_ent_by_owner(-1, "weapon_glock18", entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_BWGlock, iOwner))
		{
			Remove_BWGlock(iOwner)
			
			set_pev(weapon, pev_impulse, 2013)
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			set_pev(entity, pev_body, SUBMODEL)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id))
		return
		
	static PressButton; PressButton = get_uc(uc_handle, UC_Buttons)
	static UnPressButton; UnPressButton = pev(id, pev_oldbuttons)
	if(!(PressButton & IN_ATTACK2))
		return
	if(get_user_weapon(id) != CSW_GLOCK18)
		return
	if(!Get_BitVar(g_Had_BWGlock, id))
		return
	if((UnPressButton & IN_ATTACK2))
		return
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_GLOCK18)
	if(pev_valid(Ent)) cs_set_weapon_burst(Ent, 0)
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_GLOCK18 || !Get_BitVar(g_Had_BWGlock, Attacker))
		return HAM_IGNORED
		
	if(Get_BitVar(g_InSpecialShoot, Attacker))
	{
		static Float:flEnd[3], Float:vecPlane[3]
		
		get_tr2(Ptr, TR_vecEndPos, flEnd)
		get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)		
			
		Make_BulletHole(Attacker, flEnd, Damage)
		Make_BulletSmoke(Attacker, Ptr)
	}

	SetHamParamFloat(3, float(DAMAGE))
	
	return HAM_IGNORED
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_GLOCK18 || !Get_BitVar(g_Had_BWGlock, Attacker))
		return HAM_IGNORED
		
	SetHamParamFloat(3, float(DAMAGE))
	
	return HAM_IGNORED
}

public fw_Weapon_SecondaryAttack(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(!Get_BitVar(g_Had_BWGlock, Id))
		return HAM_IGNORED
	if(get_pdata_float(Id, 83, 5) > 0.0)
		return HAM_SUPERCEDE
	if(cs_get_weapon_ammo(Ent) <= 0)
		return HAM_SUPERCEDE
	
	Set_BitVar(g_InSpecialShoot, Id)
	
	ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	Weapon_SpecialShoot(Id)
	
	set_pdata_float(Id, 83, get_pdata_float(Id, 83, 5) + SPECIALSHOOT_DELAY, 5)	
	set_pdata_int(Ent, 64, 0, 4)
	
	UnSet_BitVar(g_InSpecialShoot, Id)
	
	return HAM_SUPERCEDE
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
		
	if(pev(ent, pev_impulse) == 2013)
	{
		Set_BitVar(g_Had_BWGlock, id)
		set_pev(ent, pev_impulse, 0)
	}		

	return HAM_HANDLED	
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_BWGlock, Id))
		return
	
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, "")
}

public Weapon_SpecialShoot(id)
{
	set_weapon_anim(id, BWGLOCK_ANIM_SHOOT)
	emit_sound(id, CHAN_WEAPON, "weapons/glock18-2.wav", 1.0, 0.4, 0, 94 + random_num(0, 15))
	
	Eject_Shell(id, PShell_Index, 0.1)
}

public Weapon_Shoot(id)
{
	static Float:Recoil[3]
	
	pev(id, pev_punchangle, Recoil)
	Recoil[0] = random_float(-(RECOIL / 1.5), -RECOIL)
	Recoil[1] = random_float(-(RECOIL / 12.0), (RECOIL / 12.0))
	set_pev(id, pev_punchangle, Recoil)
}

public Give_RealAmmo(id, CSWID)
{
	static Amount, Max
	switch(CSWID)
	{
		case CSW_P228: {Amount = 10; Max = 104;}
		case CSW_SCOUT: {Amount = 6; Max = 180;}
		case CSW_XM1014: {Amount = 8; Max = 64;}
		case CSW_MAC10: {Amount = 16; Max = 200;}
		case CSW_AUG: {Amount = 6; Max = 180;}
		case CSW_ELITE: {Amount = 16; Max = 200;}
		case CSW_FIVESEVEN: {Amount = 4; Max = 200;}
		case CSW_UMP45: {Amount = 16; Max = 200;}
		case CSW_SG550: {Amount = 6; Max = 180;}
		case CSW_GALIL: {Amount = 6; Max = 180;}
		case CSW_FAMAS: {Amount = 6; Max = 180;}
		case CSW_USP: {Amount = 18; Max = 200;}
		case CSW_GLOCK18: {Amount = 16; Max = 200;}
		case CSW_AWP: {Amount = 6; Max = 60;}
		case CSW_MP5NAVY: {Amount = 16; Max = 200;}
		case CSW_M249: {Amount = 4; Max = 200;}
		case CSW_M3: {Amount = 8; Max = 64;}
		case CSW_M4A1: {Amount = 7; Max = 180;}
		case CSW_TMP: {Amount = 7; Max = 200;}
		case CSW_G3SG1: {Amount = 7; Max = 180;}
		case CSW_DEAGLE: {Amount = 10; Max = 70;}
		case CSW_SG552: {Amount = 7; Max = 180;}
		case CSW_AK47: {Amount = 7; Max = 180;}
		case CSW_P90: {Amount = 4; Max = 200;}
		default: {Amount = 3; Max = 200;}
	}

	for(new i = 0; i < Amount; i++) give_ammo(id, 0, CSWID, Max)
}

public give_ammo(id, silent, CSWID, Max)
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
	ExecuteHamB(Ham_GiveAmmo, id, Amount, Name, Max)
}

stock Eject_Shell(id, Shell_ModelIndex, Float:Time) // By Dias
{
	static Ent; Ent = get_pdata_cbase(id, 373, 5)
	if(!pev_valid(Ent))
		return

        set_pdata_int(Ent, 57, Shell_ModelIndex, 4)
        set_pdata_float(id, 111, get_gametime() + Time)
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

stock set_weapon_anim(id, anim)
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
