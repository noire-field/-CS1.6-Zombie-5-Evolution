#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <xs>
#include <zombie_evolution>

#define PLUGIN "[ZEVO] Zombie Class: Deimos"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define ZOMBIE_NAME "Deimos"
#define GAME_FOLDER "zombie_evolution"
#define SETTING_FILE "ZEvo_ZombieClassConfig.ini"
#define LANG_FILE "zombie_evolution.txt"

#define GAME_LANG LANG_SERVER

// Skill
#define DASH_COOLDOWN 30
#define DASH_SPEED 1500.0

#define SHOCK_COOLDOWN 10
#define SHOCK_DISTANCE 840.0
#define SHOCK_SPEED 1500

/// Zombie Class
new GameName[] = "Zombie Evolution"

new zclass_name[32] = "Deimos"
new zclass_desc[32] = "Mahadash & Shock"
new Float:zclass_speed = 280.0
new Float:zclass_gravity = 0.8
new Float:zclass_knockback = 1.5
new Float:zclass_defense = 1.0
new Float:zclass_clawrange = 48.0

new const zclass_modelorigin[] = "ev_deimos_origin"
new const zclass_modelhost[] = "ev_deimos_host"
new const zclass_clawmodel_origin[] = "v_claw_deimos_origin.mdl"
new const zclass_clawmodel_host[] = "v_claw_deimos_host.mdl"
new const zclass_deathsound[] = "zombie_evolution/zombie/regular_death.wav"
new const zclass_painsound[] = "zombie_evolution/zombie/regular_hurt.wav"
new const zclass_permcode = 6

new const ShockModel[] = "models/zombie_evolution/deimos_tail.mdl"
new const DashSound[] = "zombie_evolution/zombie/deimos_dash.wav"
new const ShockSound[] = "zombie_evolution/zombie/deimos_shock.wav"
new const ShockHitSound[] = "zombie_evolution/zombie/deimos_shock_hit.wav"
new const ShockExpSound[] = "zombie_evolution/action/zombiegrenade_exp.wav"
new const ShockSprite[] = "sprites/zombie_evolution/deimos_shock.spr"
new const ShockTrail[] = "sprites/zombie_evolution/deimos_trail.spr"

// Task
#define TASK_DASHING 25001
#define TASK_SHOCKING 25002

#define SHOCK_CLASSNAME "hiddentail"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

const WPN_NOT_DROP = ((1<<2)|(1<<CSW_HEGRENADE)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_KNIFE)|(1<<CSW_C4))

new g_zombieclass
new g_MsgFov, g_ZombieHud, g_ShockSpriteID, g_TrailSprID
new g_CanDash, g_Dashing, g_DashTime[33]
new g_CanShock, g_ShockTime[33]

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	
	register_think(SHOCK_CLASSNAME, "fw_ShockThink")
	register_touch(SHOCK_CLASSNAME, "*", "fw_ShockTouch")
	
	g_MsgFov = get_user_msgid("SetFOV")
	g_ZombieHud = CreateHudSyncObj(3)
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	formatex(GameName, sizeof(GameName), "%L", LANG_SERVER, "GAME_NAME")
	
	// Precache
	precache_model(ShockModel)
	precache_sound(DashSound)
	precache_sound(ShockSound)
	precache_sound(ShockHitSound)
	precache_sound(ShockExpSound)
	g_ShockSpriteID = precache_model(ShockSprite)
	g_TrailSprID = precache_model(ShockTrail)
	
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
	//IG_3rdView(id, 0)
	
	remove_task(id+TASK_DASHING)
	remove_task(id+TASK_SHOCKING)
	
	UnSet_BitVar(g_CanDash, id)
	UnSet_BitVar(g_CanShock, id)
	UnSet_BitVar(g_Dashing, id)
}

public zevo_become_zombie(id, attacker, zombieclass)
{
	// Reset
	remove_task(id+TASK_DASHING)
	remove_task(id+TASK_SHOCKING)

	if(zombieclass == g_zombieclass)
	{
		Set_BitVar(g_CanDash, id)
		Set_BitVar(g_CanShock, id)
		UnSet_BitVar(g_Dashing, id)
		
		g_ShockTime[id] = 0
		g_DashTime[id] = 0
	} else {
		UnSet_BitVar(g_CanDash, id)
		UnSet_BitVar(g_CanShock, id)
		UnSet_BitVar(g_Dashing, id)
		
		g_ShockTime[id] = 0
		g_DashTime[id] = 0
	}
}

public zevo_zombieclass_deactivate(id, ClassID)
{
	if(ClassID == g_zombieclass)
	{
		// Reset
		remove_task(id+TASK_DASHING)
		remove_task(id+TASK_SHOCKING)
		
		zevo_3rdview(id, 0)
		
		UnSet_BitVar(g_CanDash, id)
		UnSet_BitVar(g_CanShock, id)
		UnSet_BitVar(g_Dashing, id)
	}
}

public zevo_runningtime2(id, Time)
{
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
		
	// Cooldown
	if(g_DashTime[id] > 0) 
	{
		g_DashTime[id]--
		if(!g_DashTime[id]) 
		{
			Set_BitVar(g_CanDash, id)
			UnSet_BitVar(g_Dashing, id)
		}
	}
	if(g_ShockTime[id] > 0) 
	{
		g_ShockTime[id]--
		if(!g_ShockTime[id]) Set_BitVar(g_CanShock, id)
	}
	
	// Hud
	static Skill1[32], Skill2[32], Special[16], Special2[16]
	
	formatex(Special, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LEFTMOUSE")
	formatex(Special2, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LVREQ", 2)
	
	if(!g_ShockTime[id]) formatex(Skill1, 31, "[G] : %L", GAME_LANG, "ZOMBIE_DEIMOS_SKILL_SHOCK")
	else formatex(Skill1, 31, "[G] : %L (%i)", GAME_LANG, "ZOMBIE_DEIMOS_SKILL_SHOCK", g_ShockTime[id])
	
	if(zevo_get_playerlevel(id) >= 2)
	{
		if(!g_DashTime[id]) formatex(Skill2, 31, "[F] : %L", GAME_LANG, "ZOMBIE_DEIMOS_SKILL_DASH")
		else formatex(Skill2, 31, "[F] : %L (%i)", GAME_LANG, "ZOMBIE_DEIMOS_SKILL_DASH", g_DashTime[id])
	} else formatex(Skill2, 31, "[F] : %L (%s)", GAME_LANG, "ZOMBIE_DEIMOS_SKILL_DASH", Special2)
	
	set_hudmessage(255, 212, 42, -1.0, 0.10, 0, 2.0, 2.0)
	ShowSyncHudMsg(id, g_ZombieHud, "[%s]^n^n%s^n%s", zclass_name, Skill1, Skill2)
}

public zevo_zombieskill(id, ClassID, SkillButton)
{
	if(ClassID != g_zombieclass)
		return
		
	switch(SkillButton)
	{
		case SKILL_F: Skill_Mahadash(id)
		case SKILL_G: Skill_Shock(id)
	}
}

public Skill_Mahadash(id)
{
	if(zevo_get_playerlevel(id) <= 1)
		return
	if(!Get_BitVar(g_CanDash, id))
		return
	if(Get_BitVar(g_Dashing, id))
		return
	if((pev(id, pev_flags) & FL_DUCKING) || !(pev(id, pev_flags) & FL_ONGROUND))
		return
		
	UnSet_BitVar(g_CanDash, id)
	Set_BitVar(g_Dashing, id)
	g_DashTime[id] = DASH_COOLDOWN
	
	// Prepartion
	engclient_cmd(id, "weapon_knife")
	
	zevo_3rdview(id, 1)
	zevo_speed_set(id, 0.01, 1)
	set_pev(id, pev_gravity, 10.0)
	
	zevo_set_fakeattack(id, 111)
	Set_Player_NextAttack(id, 1.8)
	
	remove_task(id+TASK_DASHING)
	set_task(0.75, "Mahadashing", id+TASK_DASHING)
	set_task(1.75, "Mahadash_End", id+TASK_DASHING)
}

public Skill_Shock(id)
{
	if(!Get_BitVar(g_CanShock, id))
		return
	if(Get_BitVar(g_Dashing, id))
		return
	
	UnSet_BitVar(g_CanShock, id)
	g_ShockTime[id] = SHOCK_COOLDOWN
	
	// Prepartion
	engclient_cmd(id, "weapon_knife")
	
	zevo_set_fakeattack(id, 10)
	Set_Player_NextAttack(id, 1.5)
	
	Set_WeaponAnim(id, 8)
	EmitSound(id, CHAN_ITEM, ShockSound)
	
	remove_task(id+TASK_SHOCKING)
	set_task(0.5, "Shocking", id+TASK_SHOCKING)
}

public Shocking(id)
{
	id -= TASK_SHOCKING
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
	
	// check
	static Float:Origin[3], Float:Angles[3], Float:Vel[3]
	
	pev(id, pev_v_angle, Angles)
	Angles[0] *= -1.0
	get_position(id, 48.0, 0.0, 0.0, Origin)
	VelocityByAim(id, SHOCK_SPEED, Vel)
	
	// create ent
	static Tail; Tail = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Tail)) return
	
	set_pev(Tail, pev_classname, SHOCK_CLASSNAME)
	engfunc(EngFunc_SetModel, Tail, ShockModel)
	
	set_pev(Tail, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(Tail, pev_maxs, Float:{1.0, 1.0, 1.0})
	
	set_pev(Tail, pev_origin, Origin)
	
	set_pev(Tail, pev_movetype, MOVETYPE_FLY)
	set_pev(Tail, pev_gravity, 0.01)
	
	set_pev(Tail, pev_velocity, Vel)
	set_pev(Tail, pev_owner, id)
	set_pev(Tail, pev_angles, Angles)
	set_pev(Tail, pev_solid, SOLID_TRIGGER)						//store the enitty id
	
	set_pev(Tail, pev_nextthink, get_gametime() + 0.05)
	
	// show trail	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY )
	write_byte(TE_BEAMFOLLOW)
	write_short(Tail)				//entity
	write_short(g_TrailSprID)		//model
	write_byte(20)		//10)//life
	write_byte(2)		//5)//width
	write_byte(0)					//r, hegrenade
	write_byte(170)					//g, gas-grenade
	write_byte(255)					//b
	write_byte(250)		//brightness
	message_end()					//move PHS/PVS data sending into here (SEND_ALL, SEND_PVS, SEND_PHS)
}

public Mahadashing(id)
{
	id -= TASK_DASHING
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
	if(!Get_BitVar(g_Dashing, id))
		return
		
	static Float:Origin[3], Float:Target[3], Float:Vel[3]
	
	EmitSound(id, CHAN_ITEM, DashSound)
	
	pev(id, pev_origin, Origin)
	get_position(id, 640.0, 0.0, 0.0, Target)
	Get_SpeedVector(Origin, Target, DASH_SPEED, Vel)
	
	set_pev(id, pev_gravity, zclass_gravity)
	set_pev(id, pev_velocity, Vel)
}

public Mahadash_End(id)
{
	id -= TASK_DASHING
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
	if(!Get_BitVar(g_Dashing, id))
		return
		
	UnSet_BitVar(g_Dashing, id)
	
	zevo_3rdview(id, 0)
	zevo_speed_set(id, zclass_speed, 1)
	set_pev(id, pev_gravity, zclass_gravity)
	
	Set_Player_NextAttack(id, 0.75)
	set_weapons_timeidle(id, CSW_KNIFE, 1.0)
	Set_WeaponAnim(id, 3)
}

public fw_ShockThink(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static id; id = pev(Ent, pev_owner)
	if(!is_alive(id) || !zevo_is_zombie(id) || entity_range(Ent, id) >= SHOCK_DISTANCE)
	{
		static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		Shock_Explosion(Origin)
		
		set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		return
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
}

public fw_ShockTouch(Ent, id)
{
	if(!pev_valid(Ent))
		return
		
	static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		
	if(is_alive(id) && !zevo_is_zombie(id) && zevo_get_subtype(id) != HUMAN_HERO)
	{
		Shock_Explosion(Origin)
		
		static CSW, WeaponName[32]
		CSW = get_user_weapon(id)
		
		if(!(WPN_NOT_DROP & (1<<CSW)) && get_weaponname(CSW, WeaponName, charsmax(WeaponName)))
			engclient_cmd(id, "drop", WeaponName)
		
		set_pdata_float(id, 108, 0.8)
		
		static MSG; if(!MSG) MSG = get_user_msgid("ScreenShake")
		message_begin(MSG_ONE_UNRELIABLE, MSG, _, id)
		write_short(255<<14)
		write_short(10<<14)
		write_short(255<<14)
		message_end()	
		
		PlaySound(id, ShockHitSound)
	} else {
		Shock_Explosion(Origin)
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
	set_pev(Ent, pev_flags, FL_KILLME)
}

public Shock_Explosion(Float:Origin[3])
{
	zevo_emitsound(0, 0, CHAN_BODY, ShockExpSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM, Origin)
	
	// create effect
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY); 
	write_byte(TE_EXPLOSION) // TE_EXPLOSION
	write_coord_f(Origin[0]) // origin x
	write_coord_f(Origin[1]) // origin y
	write_coord_f(Origin[2]); // origin z
	write_short(g_ShockSpriteID) // sprites
	write_byte(20) // scale in 0.1's
	write_byte(30) // framerate
	write_byte(14) // flags 
	message_end() // message end
}

public EmitSound(id, chan, const file_sound[]) emit_sound(id, chan, file_sound, 1.0, ATTN_NORM, 0, PITCH_NORM)

public Load_Class_Setting()
{
	static Temp[128]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_SERVER, "ZOMBIE_DEIMOS_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_SERVER, "ZOMBIE_DEIMOS_DESC")
	
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "DEIMOS_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "DEIMOS_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "DEIMOS_KNOCKBACK", Temp, sizeof(Temp)); zclass_knockback = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "DEIMOS_DEFENSE", Temp, sizeof(Temp)); zclass_defense = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "DEIMOS_CLAWRANGE", Temp, sizeof(Temp)); zclass_clawrange = str_to_float(Temp)
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
