#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <xs>
#include <zombie_evolution>
#include <cstrike>

#define PLUGIN "[ZEVO] Zombie Class: Victorique"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define ZOMBIE_NAME "Banshee"
#define GAME_FOLDER "zombie_evolution"
#define SETTING_FILE "ZEvo_ZombieClassConfig.ini"
#define LANG_FILE "zombie_evolution.txt"

#define GAME_LANG LANG_SERVER

// Skill
#define SUMMON_COOLDOWN 20
#define SUMMON_SPEED 500
#define SUMMON_HOLDTIME 7.0
#define SUMMON_CATCHSPEED 250.0

#define DISGUISE_COOLDOWN 25
#define DISGUISE_TIME 13

/// Zombie Class
new GameName[] = "Zombie Evolution"

new zclass_name[32] = "Banshee"
new zclass_desc[32] = "Summon & Disguise"
new Float:zclass_speed = 290.0
new Float:zclass_gravity = 0.75
new Float:zclass_knockback = 1.5
new Float:zclass_defense = 0.85
new Float:zclass_clawrange = 48.0

new const zclass_modelorigin[] = "ev_banshee_origin"
new const zclass_modelhost[] = "ev_banshee_host"
new const zclass_clawmodel_origin[] = "v_claw_banshee.mdl"
new const zclass_clawmodel_host[] = "v_claw_banshee.mdl"
new const zclass_deathsound[] = "zombie_evolution/zombie/banshee_death.wav"
new const zclass_painsound[] = "zombie_evolution/zombie/banshee_hurt.wav"
new const zclass_permcode = 7

new const BatModel[] = "models/zombie_evolution/bat_witch.mdl"
new const BatLaugh[] = "zombie_evolution/zombie/banshee_laugh.wav"
new const BatSummon[] = "zombie_evolution/zombie/banshee_batsummon.wav"
new const BatExp[] = "zombie_evolution/zombie/banshee_batfail.wav"
new const BatExp_Spr[] = "sprites/zombie_evolution/bat_exp.spr"
new const TrapVoice[2][] = 
{
	"zombie_evolution/action/trapped_male.wav",
	"zombie_evolution/action/trapped_female.wav",
}

new const Disguise[] = "zombie_evolution/zombie/banshee_disguise.wav"

// Task
#define TASK_SUMMON 26001
#define TASK_DISGUISE 26002

#define BAT_CLASSNAME "witchbat"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_zombieclass
new g_MsgFov, g_ZombieHud, g_BatExp_SprID, g_MaxPlayers
new g_CanSummon, g_Summoning, g_SummonTime[33], g_MyBat[33]
new g_CanDisguise, g_Disguising, g_DisguiseTime[33]

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	
	register_think(BAT_CLASSNAME, "fw_BatThink")
	register_touch(BAT_CLASSNAME, "*", "fw_BatTouch")
	
	g_MsgFov = get_user_msgid("SetFOV")
	g_MaxPlayers = get_maxplayers()
	g_ZombieHud = CreateHudSyncObj(3)
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	formatex(GameName, sizeof(GameName), "%L", LANG_SERVER, "GAME_NAME")
	
	// Precache
	precache_model(BatModel)
	precache_sound(BatLaugh)
	precache_sound(BatSummon)
	precache_sound(BatExp)
	precache_sound(TrapVoice[0])
	precache_sound(TrapVoice[1])
	
	g_BatExp_SprID = precache_model(BatExp_Spr)

	precache_sound(Disguise)
	
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
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public zevo_user_spawn(id)
{
	remove_task(id+TASK_SUMMON)
	remove_task(id+TASK_DISGUISE)
	
	Set_BitVar(g_CanSummon, id)
	Set_BitVar(g_CanDisguise, id)
	
	UnSet_BitVar(g_Summoning, id)
	UnSet_BitVar(g_Disguising, id)
	
	g_SummonTime[id] = 0
	g_DisguiseTime[id] = 0
}

public zevo_become_zombie(id, attacker, zombieclass)
{
	// Reset
	remove_task(id+TASK_SUMMON)
	remove_task(id+TASK_DISGUISE)

	if(zombieclass == g_zombieclass)
	{
		Set_BitVar(g_CanSummon, id)
		Set_BitVar(g_CanDisguise, id)
		
		UnSet_BitVar(g_Summoning, id)
		UnSet_BitVar(g_Disguising, id)
		
		g_SummonTime[id] = 0
		g_DisguiseTime[id] = 0
	} else {
		UnSet_BitVar(g_CanSummon, id)
		UnSet_BitVar(g_CanDisguise, id)
		
		UnSet_BitVar(g_Summoning, id)
		UnSet_BitVar(g_Disguising, id)
		
		g_SummonTime[id] = 0
		g_DisguiseTime[id] = 0
	}
}

public zevo_zombieclass_deactivate(id, ClassID)
{
	if(ClassID == g_zombieclass)
	{
		set_pdata_string(id, (492) * 4, "knife", -1 , 20)
		
		// Reset
		remove_task(id+TASK_SUMMON)
		remove_task(id+TASK_DISGUISE)
		
		Set_BitVar(g_CanSummon, id)
		Set_BitVar(g_CanDisguise, id)
		
		UnSet_BitVar(g_Summoning, id)
		UnSet_BitVar(g_Disguising, id)
		
		g_SummonTime[id] = 0
		g_DisguiseTime[id] = 0
	}
}

public zevo_user_death(id)
{
	if(zevo_is_zombie(id) && Get_BitVar(g_Summoning, id))
		set_pev(id, pev_maxspeed, zclass_speed)
}

public zevo_runningtime2(id, Time)
{
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
		
	// Cooldown
	if(g_SummonTime[id] > 0) 
	{
		g_SummonTime[id]--
		if(!g_SummonTime[id]) 
		{
			Set_BitVar(g_CanSummon, id)
			UnSet_BitVar(g_Summoning, id)
		}
	}
	if(g_DisguiseTime[id] > 0) 
	{
		g_DisguiseTime[id]--
		if(!g_DisguiseTime[id]) 
		{
			Set_BitVar(g_CanDisguise, id)
			UnSet_BitVar(g_Disguising, id)
		}
	}
	
	// Hud
	static Skill1[32], Skill2[32], Special[16], Special2[16]
	
	formatex(Special, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LEFTMOUSE")
	formatex(Special2, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LVREQ", 2)
	
	if(!g_SummonTime[id]) formatex(Skill1, 31, "[G] : %L", GAME_LANG, "ZOMBIE_BANSHEE_SKILL_BAT")
	else formatex(Skill1, 31, "[G] : %L (%i)", GAME_LANG, "ZOMBIE_BANSHEE_SKILL_BAT", g_SummonTime[id])
	if(zevo_get_playerlevel(id) >= 2)
	{
		if(!g_DisguiseTime[id]) formatex(Skill2, 31, "[F] : %L", GAME_LANG, "ZOMBIE_BANSHEE_SKILL_DISGUISE")
		else formatex(Skill2, 31, "[F] : %L (%i)", GAME_LANG, "ZOMBIE_BANSHEE_SKILL_DISGUISE", g_DisguiseTime[id])
	} else formatex(Skill2, 31, "[F] : %L (%s)", GAME_LANG, "ZOMBIE_BANSHEE_SKILL_DISGUISE", Special2)
	
	set_hudmessage(255, 212, 42, -1.0, 0.10, 0, 2.0, 2.0)
	ShowSyncHudMsg(id, g_ZombieHud, "[%s]^n^n%s^n%s", zclass_name, Skill1, Skill2)
}

public zevo_zombieskill(id, ClassID, SkillButton)
{
	if(ClassID != g_zombieclass)
		return
		
	switch(SkillButton)
	{
		case SKILL_G: Skill_Summon(id)
		case SKILL_F: Skill_Disguise(id)
	}
}

public Skill_Summon(id)
{
	if(!Get_BitVar(g_CanSummon, id))
		return
	if(Get_BitVar(g_Summoning, id) || Get_BitVar(g_Disguising, id))
		return
	if((pev(id, pev_flags) & FL_DUCKING) || !(pev(id, pev_flags) & FL_ONGROUND))
		return
		
	UnSet_BitVar(g_CanSummon, id)
	Set_BitVar(g_Summoning, id)
	g_SummonTime[id] = SUMMON_COOLDOWN
	
	// Prepartion
	zevo_speed_set(id, 0.01, 1)
	set_pev(id, pev_gravity, 10.0)
	
	// Prepartion
	engclient_cmd(id, "weapon_knife")
	set_pdata_string(id, (492) * 4, "bat", -1 , 20)
	zevo_set_fakeattack(id, 151)
	//set_pev(id, pev_framerate, 1.0)
	Set_Player_NextAttack(id, 360.0)
	set_weapons_timeidle(id, CSW_KNIFE, 360.0)
	// g_MyNumber[id] = pev(id, pev_weapons); 
	
	Set_WeaponAnim(id, 2)
	EmitSound(id, CHAN_ITEM, BatLaugh)
	
	remove_task(id+TASK_SUMMON)
	set_task(1.0, "Summon_Bat", id+TASK_SUMMON)
	set_task(SUMMON_HOLDTIME, "Finish_Bat", id+TASK_SUMMON)
}

public Skill_Disguise(id)
{
	if(zevo_get_playerlevel(id) <= 1)
		return
	if(!Get_BitVar(g_CanDisguise, id))
		return
	if(Get_BitVar(g_Disguising, id) || Get_BitVar(g_Summoning, id))
		return
	
	UnSet_BitVar(g_CanDisguise, id)
	Set_BitVar(g_Disguising, id)
	g_DisguiseTime[id] = DISGUISE_COOLDOWN
	
	static Model[40], Model2[64], Model3[64]
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(zevo_is_zombie(i))
			continue
			
		cs_get_user_model(i, Model, 39)
		pev(i, pev_viewmodel2, Model2, 63)
		pev(i, pev_weaponmodel2, Model3, 63)
	
		break
	}
	
	engclient_cmd(id, "weapon_knife")
	
	zevo_speed_set(id, 250.0, 1)
	zevo_model_set(id, Model, 1)
	set_pev(id, pev_viewmodel2, Model2)
	set_pev(id, pev_weaponmodel2, Model3)
	
	set_pdata_string(id, (492) * 4, "carbine", -1 , 20)
	EmitSound(id, CHAN_ITEM, Disguise)
	
	remove_task(id+TASK_DISGUISE)
	set_task(float(DISGUISE_TIME), "Finish_Disguise", id+TASK_DISGUISE)
}

public Finish_Disguise(id)
{
	id -= TASK_DISGUISE
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
	if(!Get_BitVar(g_Disguising, id))
		return
		
	UnSet_BitVar(g_Disguising, id)
	zevo_speed_set(id, zclass_speed, 1)
	
	static Claws[80]
	formatex(Claws, sizeof(Claws), "models/zombie_evolution/zombie/%s", zevo_get_playerlevel(id) <= 1 ? zclass_clawmodel_host : zclass_clawmodel_origin)
	set_pev(id, pev_viewmodel2, Claws)
	set_pev(id, pev_weaponmodel2, "")
	
	zevo_model_set(id, zevo_get_playerlevel(id) <= 1 ? zclass_modelhost : zclass_modelorigin, 1)
	set_pdata_string(id, (492) * 4, "knife", -1 , 20)
	
	Set_Player_NextAttack(id, 0.75)
	set_weapons_timeidle(id, CSW_KNIFE, 1.0)
	Set_WeaponAnim(id, 3)
}

public Summon_Bat(id)
{
	id -= TASK_SUMMON
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
	if(!Get_BitVar(g_Summoning, id))
		return
		
	// check
	static Float:Origin[3], Float:Angles[3], Float:Vel[3]
	
	pev(id, pev_v_angle, Angles)
	Angles[0] *= -1.0
	get_position(id, 48.0, 0.0, -6.0, Origin)
	VelocityByAim(id, SUMMON_SPEED, Vel)
	
	// create ent
	static Bat; Bat = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Bat)) return
	
	g_MyBat[id] = Bat
	
	set_pev(Bat, pev_classname, BAT_CLASSNAME)
	engfunc(EngFunc_SetModel, Bat, BatModel)
	
	set_pev(Bat, pev_mins, Float:{-10.0, -10.0, 0.0})
	set_pev(Bat, pev_maxs, Float:{10.0, 10.0, 6.0})
	
	set_pev(Bat, pev_origin, Origin)
	
	set_pev(Bat, pev_movetype, MOVETYPE_FLY)
	set_pev(Bat, pev_gravity, 0.01)
	
	set_pev(Bat, pev_velocity, Vel)
	set_pev(Bat, pev_owner, id)
	set_pev(Bat, pev_angles, Angles)
	set_pev(Bat, pev_solid, SOLID_TRIGGER)		//store the enitty id
	
	set_pev(Bat, pev_iuser1, 0)
	set_pev(Bat, pev_iuser2, 0)
	
	set_pev(Bat, pev_animtime, get_gametime())
	set_pev(Bat, pev_framerate, 1.0)
	set_pev(Bat, pev_sequence, 0)
	
	set_pev(Bat, pev_nextthink, get_gametime() + 0.01)
	emit_sound(Bat, CHAN_BODY, BatSummon, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

public Finish_Bat(id)
{
	id -= TASK_SUMMON
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
	if(!Get_BitVar(g_Summoning, id))
		return
		
	UnSet_BitVar(g_Summoning, id)
	if(pev_valid(g_MyBat[id])) Bat_Explosion(g_MyBat[id])
	g_MyBat[id] = -1
	
	// Reset
	set_pdata_string(id, (492) * 4, "knife", -1 , 20)
	zevo_set_fakeattack(id, 1)
	
	zevo_speed_set(id, zclass_speed, 1)
	set_pev(id, pev_gravity, zclass_gravity)
	
	Set_Player_NextAttack(id, 0.25)
	set_weapons_timeidle(id, CSW_KNIFE, 1.0)
	Set_WeaponAnim(id, 3)
}

public fw_BatThink(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static id; id = pev(Ent, pev_owner)
	if(!is_alive(id) || !zevo_is_zombie(id))
	{
		Bat_Explosion(Ent)
		return
	}
	
	static Found, Target;
	Found = pev(Ent, pev_iuser1)
	Target = pev(Ent, pev_iuser2)
	
	if(Found)
	{
		if(!is_alive(Target))
		{
			Bat_Explosion(Ent)
			return
		} else {
			if(entity_range(id, Target) > 36.0)
			{
				static Float:Origin[3]; pev(id, pev_origin, Origin)
				hook_ent2(Target, Origin, SUMMON_CATCHSPEED)
			} else {
				static Float:Origin[3]; pev(Target, pev_origin, Origin)
				set_pev(Ent, pev_origin, Origin)
				
				Bat_Explosion(Ent)
				return
			}
		}
	} else {
		static Victim; Victim = FindClosetEnemy(Ent, 1)
		if(is_alive(Victim) && entity_range(Victim, Ent) <= 240.0)
		{
			static Float:Origin[3]; pev(Victim, pev_origin, Origin)
			
			hook_ent2(Ent, Origin, float(SUMMON_SPEED))
			Aim_To(Ent, Origin, 2.0, 0)
		}
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public fw_BatTouch(Ent, id)
{
	if(!pev_valid(Ent))
		return
	if(pev(Ent, pev_iuser1))
		return
		
	static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		
	if(is_alive(id))
	{
		set_pev(Ent, pev_iuser1, 1)
		set_pev(Ent, pev_iuser2, id)
		
		// Voice
		if(zevo_get_playersex(id) == PLAYER_MALE) EmitSound(id, CHAN_ITEM, TrapVoice[0])
		else if(zevo_get_playersex(id) == PLAYER_FEMALE) EmitSound(id, CHAN_ITEM, TrapVoice[1])
		
		set_pev(Ent, pev_aiment, id)
	} else {
		Bat_Explosion(Ent)
	}
}

public Bat_Explosion(Ent)
{
	static Float:Origin[3]; pev(Ent, pev_origin, Origin)
	
	// create effect
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY); 
	write_byte(TE_EXPLOSION) // TE_EXPLOSION
	write_coord_f(Origin[0]) // origin x
	write_coord_f(Origin[1]) // origin y
	write_coord_f(Origin[2]); // origin z
	write_short(g_BatExp_SprID) // sprites
	write_byte(20) // scale in 0.1's
	write_byte(20) // framerate
	write_byte(14) // flags 
	message_end() // message end
	
	EmitSound(Ent, CHAN_BODY, BatExp)
	
	// Check Owner
	static id; id = pev(Ent, pev_owner)
	
	// Shit
	set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
	set_pev(Ent, pev_flags, FL_KILLME)
	
	// Do
	if(is_alive(id) && zevo_is_zombie(id) && zevo_get_zombieclass(id) == g_zombieclass)
	{
		remove_task(id+TASK_SUMMON)
		Finish_Bat(id+TASK_SUMMON)
	}
}

public EmitSound(id, chan, const file_sound[]) emit_sound(id, chan, file_sound, 1.0, ATTN_NORM, 0, PITCH_NORM)

public Load_Class_Setting()
{
	static Temp[128]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_SERVER, "ZOMBIE_BANSHEE_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_SERVER, "ZOMBIE_BANSHEE_DESC")
	
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "BANSHEE_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "BANSHEE_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "BANSHEE_KNOCKBACK", Temp, sizeof(Temp)); zclass_knockback = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "BANSHEE_DEFENSE", Temp, sizeof(Temp)); zclass_defense = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "BANSHEE_CLAWRANGE", Temp, sizeof(Temp)); zclass_clawrange = str_to_float(Temp)
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
	
	//vAngle[0] = 0.0
	
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

public Aim_To(iEnt, Float:vTargetOrigin[3], Float:flSpeed, Style)
{
	if(!pev_valid(iEnt))	
		return
		
	if(!Style)
	{
		static Float:Vec[3], Float:Angles[3]
		pev(iEnt, pev_origin, Vec)
		
		Vec[0] = vTargetOrigin[0] - Vec[0]
		Vec[1] = vTargetOrigin[1] - Vec[1]
		Vec[2] = vTargetOrigin[2] - Vec[2]
		engfunc(EngFunc_VecToAngles, Vec, Angles)
		Angles[0] = Angles[2] = 0.0 
		
		set_pev(iEnt, pev_v_angle, Angles)
		set_pev(iEnt, pev_angles, Angles)
	} else {
		new Float:f1, Float:f2, Float:fAngles, Float:vOrigin[3], Float:vAim[3], Float:vAngles[3];
		pev(iEnt, pev_origin, vOrigin);
		xs_vec_sub(vTargetOrigin, vOrigin, vOrigin);
		xs_vec_normalize(vOrigin, vAim);
		vector_to_angle(vAim, vAim);
		
		if (vAim[1] > 180.0) vAim[1] -= 360.0;
		if (vAim[1] < -180.0) vAim[1] += 360.0;
		
		fAngles = vAim[1];
		pev(iEnt, pev_angles, vAngles);
		
		if (vAngles[1] > fAngles)
		{
			f1 = vAngles[1] - fAngles;
			f2 = 360.0 - vAngles[1] + fAngles;
			if (f1 < f2)
			{
				vAngles[1] -= flSpeed;
				vAngles[1] = floatmax(vAngles[1], fAngles);
			}
			else
			{
				vAngles[1] += flSpeed;
				if (vAngles[1] > 180.0) vAngles[1] -= 360.0;
			}
		}
		else
		{
			f1 = fAngles - vAngles[1];
			f2 = 360.0 - fAngles + vAngles[1];
			if (f1 < f2)
			{
				vAngles[1] += flSpeed;
				vAngles[1] = floatmin(vAngles[1], fAngles);
			}
			else
			{
				vAngles[1] -= flSpeed;
				if (vAngles[1] < -180.0) vAngles[1] += 360.0;
			}		
		}
	
		set_pev(iEnt, pev_v_angle, vAngles)
		set_pev(iEnt, pev_angles, vAngles)
	}
}

public FindClosetEnemy(ent, can_see)
{
	static indexid; indexid = 0	
	static Float:current_dis; current_dis = 4960.0

	for(new i = 1 ;i <= g_MaxPlayers; i++)
	{
		if(can_see)
		{
			if(is_alive(i) && !zevo_is_zombie(i) && can_see_fm(ent, i) && entity_range(ent, i) < current_dis)
			{
				current_dis = entity_range(ent, i)
				indexid = i
			}
		} else {
			if(is_alive(i) && !zevo_is_zombie(i) && entity_range(ent, i) < current_dis)
			{
				current_dis = entity_range(ent, i)
				indexid = i
			}			
		}
	}	
	
	return indexid
}

public bool:can_see_fm(entindex1, entindex2)
{
	if (!entindex1 || !entindex2)
		return false

	if (pev_valid(entindex1) && pev_valid(entindex1))
	{
		new flags = pev(entindex1, pev_flags)
		if (flags & EF_NODRAW || flags & FL_NOTARGET)
		{
			return false
		}

		new Float:lookerOrig[3]
		new Float:targetBaseOrig[3]
		new Float:targetOrig[3]
		new Float:temp[3]

		pev(entindex1, pev_origin, lookerOrig)
		pev(entindex1, pev_view_ofs, temp)
		lookerOrig[0] += temp[0]
		lookerOrig[1] += temp[1]
		lookerOrig[2] += temp[2]

		pev(entindex2, pev_origin, targetBaseOrig)
		pev(entindex2, pev_view_ofs, temp)
		targetOrig[0] = targetBaseOrig [0] + temp[0]
		targetOrig[1] = targetBaseOrig [1] + temp[1]
		targetOrig[2] = targetBaseOrig [2] + temp[2]

		engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the had of seen player
		if (get_tr2(0, TraceResult:TR_InOpen) && get_tr2(0, TraceResult:TR_InWater))
		{
			return false
		} 
		else 
		{
			new Float:flFraction
			get_tr2(0, TraceResult:TR_flFraction, flFraction)
			if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
			{
				return true
			}
			else
			{
				targetOrig[0] = targetBaseOrig [0]
				targetOrig[1] = targetBaseOrig [1]
				targetOrig[2] = targetBaseOrig [2]
				engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the body of seen player
				get_tr2(0, TraceResult:TR_flFraction, flFraction)
				if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
				{
					return true
				}
				else
				{
					targetOrig[0] = targetBaseOrig [0]
					targetOrig[1] = targetBaseOrig [1]
					targetOrig[2] = targetBaseOrig [2] - 17.0
					engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the legs of seen player
					get_tr2(0, TraceResult:TR_flFraction, flFraction)
					if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
					{
						return true
					}
				}
			}
		}
	}
	return false
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
