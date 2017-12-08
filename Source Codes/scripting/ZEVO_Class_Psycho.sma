#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <xs>
#include <zombie_evolution>

#define PLUGIN "[ZEVO] Zombie Class: Psycho"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define ZOMBIE_NAME "Psycho Zombie"
#define GAME_FOLDER "zombie_evolution"
#define SETTING_FILE "ZEvo_ZombieClassConfig.ini"
#define LANG_FILE "zombie_evolution.txt"

#define GAME_LANG LANG_SERVER

// Skill
#define SMOKE_COOLDOWN 15
#define SMOKE_LIFETIME 10

/// Zombie Class
new GameName[] = "Zombie Evolution"

new zclass_name[32] = "Psycho Zombie"
new zclass_desc[32] = "Smokescreen"
new Float:zclass_speed = 280.0
new Float:zclass_gravity = 0.8
new Float:zclass_knockback = 1.25
new Float:zclass_defense = 1.0
new Float:zclass_clawrange = 48.0

new const zclass_modelorigin[] = "ev_psycho_origin"
new const zclass_modelhost[] = "ev_psycho_host"
new const zclass_clawmodel_origin[] = "v_claw_psycho.mdl"
new const zclass_clawmodel_host[] = "v_claw_psycho.mdl"
new const zclass_deathsound[] = "zombie_evolution/zombie/regular_death.wav"
new const zclass_painsound[] = "zombie_evolution/zombie/regular_hurt.wav"
new const zclass_permcode = 4

new const Grenade_ModelV[] = "models/zombie_evolution/zombie/v_grenade_psycho.mdl"
new const Grenade_ModelW[] = "models/zombie_evolution/zombie/w_zombiegrenade.mdl"
new const SmokeSound[] = "zombie_evolution/zombie/psycho_smoke.wav"
new const ThrowSound[] = "zombie_evolution/zombie/heavy_trapthrow.wav"
new const SmokeSprite[] = "sprites/zombie_evolution/zombie_smoke.spr"

// Task
#define TASK_SMOKE 23001
#define TASK_CLAW 23002

#define SMOKE_CLASSNAME "smokegre"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_zombieclass
new g_MsgFov, g_ZombieHud, g_SmokeID
new g_CanSmoke, g_SmokeCooldown[33]

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	register_touch(SMOKE_CLASSNAME, "*", "fw_SmokeTouch")
	
	g_MsgFov = get_user_msgid("SetFOV")
	g_ZombieHud = CreateHudSyncObj(3)
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	formatex(GameName, sizeof(GameName), "%L", LANG_SERVER, "GAME_NAME")
	
	// Precache
	precache_model(Grenade_ModelV)
	precache_model(Grenade_ModelW)
	precache_sound(SmokeSound)
	precache_sound(ThrowSound)
	g_SmokeID = precache_model(SmokeSprite)
	
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

public zevo_round_new() remove_entity_name(SMOKE_CLASSNAME)
public zevo_user_spawn(id)
{
	remove_task(id+TASK_SMOKE)
	remove_task(id+TASK_CLAW)
	
	UnSet_BitVar(g_CanSmoke, id)
	g_SmokeCooldown[id] = 0
}

public zevo_become_zombie(id, attacker, zombieclass)
{
	// Reset
	remove_task(id+TASK_SMOKE)
	remove_task(id+TASK_CLAW)
	
	if(zombieclass == g_zombieclass)
	{
		Set_BitVar(g_CanSmoke, id)
		g_SmokeCooldown[id] = 0
	} else {
		UnSet_BitVar(g_CanSmoke, id)
		g_SmokeCooldown[id] = 0
	}
}

public zevo_zombieclass_deactivate(id, ClassID)
{
	if(ClassID == g_zombieclass)
	{
		// Reset
		remove_task(id+TASK_SMOKE)
		remove_task(id+TASK_CLAW)
			
		UnSet_BitVar(g_CanSmoke, id)
		g_SmokeCooldown[id] = 0
	}
}

public zevo_runningtime2(id, Time)
{
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
		
	// Cooldown
	if(g_SmokeCooldown[id] > 0) 
	{
		g_SmokeCooldown[id]--
		if(!g_SmokeCooldown[id]) 
		{
			Set_BitVar(g_CanSmoke, id)
		}
	}
	
	// Hud
	static Skill1[64], Skill2[64], Special[16]
	formatex(Special, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LVREQ", 2)
	
	if(!g_SmokeCooldown[id]) 
	{
		formatex(Skill1, 63, "[G] : %L", GAME_LANG, "ZOMBIE_PSYCHO_SKILL_POP")
		if(zevo_get_playerlevel(id) >= 2) formatex(Skill2, 63, "[F] : %L", GAME_LANG, "ZOMBIE_PSYCHO_SKILL_THROW")
		else formatex(Skill2, 63, "[F] : %L (%s)", GAME_LANG, "ZOMBIE_PSYCHO_SKILL_THROW", Special)
	} else {
		formatex(Skill1, 63, "[G] : %L (%i)", GAME_LANG, "ZOMBIE_PSYCHO_SKILL_POP", g_SmokeCooldown[id])
		if(zevo_get_playerlevel(id) >= 2) formatex(Skill2, 63, "[F] : %L (%i)", GAME_LANG, "ZOMBIE_PSYCHO_SKILL_THROW", g_SmokeCooldown[id])
		else formatex(Skill2, 63, "[F] : %L (%s)", GAME_LANG, "ZOMBIE_PSYCHO_SKILL_THROW", Special)
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
		case SKILL_G: Skill_PopSmoke(id)
		case SKILL_F: Skill_ThrowSmoke(id)
	}
}

public Skill_PopSmoke(id)
{
	if(!Get_BitVar(g_CanSmoke, id))
		return
		
	UnSet_BitVar(g_CanSmoke, id)
	g_SmokeCooldown[id] = SMOKE_COOLDOWN
	
	EmitSound(id, CHAN_ITEM, SmokeSound)
	
	static Origin[3]; get_user_origin(id, Origin)
	
	remove_task(id+TASK_SMOKE)
	set_task(1.0, "Smoke_Loop", id+TASK_SMOKE, Origin, 3)
	set_task(float(SMOKE_LIFETIME), "Smoke_End", id+TASK_SMOKE)
	
	static Float:Target[3]; pev(id, pev_origin, Target)
	Create_Smoke(Target, 4)
}

public Smoke_Loop(Origin[3], TaskID)
{
	static Float:Target[3];
	
	Target[0] = float(Origin[0])
	Target[1] = float(Origin[1])
	Target[2] = float(Origin[2])
	
	Create_Smoke(Target, 4)
	set_task(1.0, "Smoke_Loop", TaskID, Origin, 3)
}

public Smoke_End(id) remove_task(id)

public Skill_ThrowSmoke(id)
{
	if(zevo_get_playerlevel(id) <= 1)
		return
	if(!Get_BitVar(g_CanSmoke, id))
		return
		
	UnSet_BitVar(g_CanSmoke, id)
	g_SmokeCooldown[id] = SMOKE_COOLDOWN
	
	EmitSound(id, CHAN_ITEM, ThrowSound)
	
	// Set Everything
	engclient_cmd(id, "weapon_knife")
	set_pev(id, pev_viewmodel2, Grenade_ModelV)
	
	Set_Player_NextAttack(id, 1.5)
	Set_WeaponAnim(id, 2)
	
	set_task(0.25, "Create_Grenade", id+TASK_SMOKE)
	set_task(1.0, "Reset_ZombieClaw", id+TASK_CLAW)
}

public Create_Grenade(id)
{
	id -= TASK_SMOKE
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
	
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent)) return
	
	set_pev(Ent, pev_classname, SMOKE_CLASSNAME)
	set_pev(Ent, pev_solid, SOLID_TRIGGER)
	set_pev(Ent, pev_movetype, MOVETYPE_BOUNCE)
	set_pev(Ent, pev_gravity, 1.0)
	
	set_pev(Ent, pev_animtime, get_gametime())
	set_pev(Ent, pev_framerate, 5.0)
	set_pev(Ent, pev_sequence, 1)
	
	set_pev(Ent, pev_owner, id)
	
	new Float:mins[3] = { -10.0, -10.0, -10.0 }
	new Float:maxs[3] = { 10.0, 10.0, 10.0 }
	engfunc(EngFunc_SetSize, Ent, mins, maxs)
	
	// Set trap model
	engfunc(EngFunc_SetModel, Ent, Grenade_ModelW)

	// Set trap position
	static Float:Origin[3]; get_position(id, 48.0, 0.0, 0.0, Origin)
	set_pev(Ent, pev_origin, Origin)
	
	// Velo
	static Float:Vel[3], Float:Target[3]; get_position(id, 128.0, 0.0, 0.0, Target)
	Get_SpeedVector(Origin, Target, 500.0, Vel)
	
	set_pev(Ent, pev_velocity, Vel)

	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public fw_SmokeTouch(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static id; id = pev(Ent, pev_owner)
	if(!is_connected(id))
	{
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		return
	}
	
	static Float:Origin[3]; pev(Ent, pev_origin, Origin)
	static Target[3]; 
	
	Create_Smoke(Origin, 4)
	EmitSound(Ent, CHAN_BODY, SmokeSound)
	
	Target[0] = floatround(Origin[0])
	Target[1] = floatround(Origin[1])
	Target[2] = floatround(Origin[2])
	
	remove_task(id+TASK_SMOKE)
	set_task(1.0, "Smoke_Loop", id+TASK_SMOKE, Target, 3)
	set_task(float(SMOKE_LIFETIME), "Smoke_End", id+TASK_SMOKE)
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
	set_pev(Ent, pev_flags, FL_KILLME)
}

public Reset_ZombieClaw(id)
{
	id -= TASK_CLAW
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
	if(get_user_weapon(id) != CSW_KNIFE)
		return
	
	static ClawModel[80]
	formatex(ClawModel, sizeof(ClawModel), "models/zombie_evolution/zombie/%s", zevo_get_playerlevel(id) <= 1 ? zclass_clawmodel_host : zclass_clawmodel_origin)
	
	set_pev(id, pev_viewmodel2, ClawModel)
	Set_Player_NextAttack(id, 0.75)
	Set_WeaponAnim(id, 3)
}

public EmitSound(id, chan, const file_sound[]) emit_sound(id, chan, file_sound, 1.0, ATTN_NORM, 0, PITCH_NORM)

public Load_Class_Setting()
{
	static Temp[128]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_SERVER, "ZOMBIE_PSYCHO_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_SERVER, "ZOMBIE_PSYCHO_DESC")
	
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "PSYCHO_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "PSYCHO_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "PSYCHO_KNOCKBACK", Temp, sizeof(Temp)); zclass_knockback = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "PSYCHO_DEFENSE", Temp, sizeof(Temp)); zclass_defense = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "PSYCHO_CLAWRANGE", Temp, sizeof(Temp)); zclass_clawrange = str_to_float(Temp)
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

public Create_Smoke(Float:position[3], Size)
{
	static Num; Num = clamp(Size, 1, 12)
	new Float:origin[12][3]
	get_spherical_coord(position, 40.0, 0.0, 0.0, origin[0])
	get_spherical_coord(position, 40.0, 90.0, 0.0, origin[1])
	get_spherical_coord(position, 40.0, 180.0, 0.0, origin[2])
	get_spherical_coord(position, 40.0, 270.0, 0.0, origin[3])
	get_spherical_coord(position, 100.0, 0.0, 0.0, origin[4])
	get_spherical_coord(position, 100.0, 45.0, 0.0, origin[5])
	get_spherical_coord(position, 100.0, 90.0, 0.0, origin[6])
	get_spherical_coord(position, 100.0, 135.0, 0.0, origin[7])
	get_spherical_coord(position, 100.0, 180.0, 0.0, origin[8])
	get_spherical_coord(position, 100.0, 225.0, 0.0, origin[9])
	get_spherical_coord(position, 100.0, 270.0, 0.0, origin[10])
	get_spherical_coord(position, 100.0, 315.0, 0.0, origin[11])
	
	for (new i = 0; i < Num; i++)
		create_Smoke(origin[i], g_SmokeID, 75, 0)
}

public create_Smoke(const Float:position[3], sprite_index, life, framerate)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_SMOKE) // TE_SMOKE (5)
	engfunc(EngFunc_WriteCoord, position[0]) // position.x
	engfunc(EngFunc_WriteCoord, position[1]) // position.y
	engfunc(EngFunc_WriteCoord, position[2] - 16.0) // position.z
	write_short(sprite_index) // sprite index
	write_byte(life) // scale in 0.1's
	write_byte(framerate) // framerate
	message_end()
}

public get_spherical_coord(const Float:ent_origin[3], Float:redius, Float:level_angle, Float:vertical_angle, Float:origin[3])
{
	new Float:length
	length  = redius * floatcos(vertical_angle, degrees)
	origin[0] = ent_origin[0] + length * floatcos(level_angle, degrees)
	origin[1] = ent_origin[1] + length * floatsin(level_angle, degrees)
	origin[2] = ent_origin[2] + redius * floatsin(vertical_angle, degrees)
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
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD, vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT, vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP, vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
