#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <xs>
#include <zombie_evolution>

#define PLUGIN "[ZEVO] Zombie Class: Voodoo"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define ZOMBIE_NAME "Voodoo Zombie"
#define GAME_FOLDER "zombie_evolution"
#define SETTING_FILE "ZEvo_ZombieClassConfig.ini"
#define LANG_FILE "zombie_evolution.txt"

#define GAME_LANG LANG_SERVER

// Skill
#define HEAL_COOLDOWN 10
#define HEAL_AMOUNT 3000

#define SET_COOLDOWN 40
#define SET_RADIUS 240.0
#define SET_TIME 20.0
#define SET_AMOUNT 200

/// Zombie Class
new GameName[] = "Zombie Evolution"

new zclass_name[32] = "Voodoo Zombie"
new zclass_desc[32] = "Healing"
new Float:zclass_speed = 280.0
new Float:zclass_gravity = 0.8
new Float:zclass_knockback = 1.25
new Float:zclass_defense = 1.15
new Float:zclass_clawrange = 48.0

new const zclass_modelorigin[] = "ev_voodoo_origin"
new const zclass_modelhost[] = "ev_voodoo_host"
new const zclass_clawmodel_origin[] = "v_claw_voodoo.mdl"
new const zclass_clawmodel_host[] = "v_claw_voodoo.mdl"
new const zclass_deathsound[] = "zombie_evolution/zombie/regular_death.wav"
new const zclass_painsound[] = "zombie_evolution/zombie/regular_hurt.wav"
new const zclass_permcode = 5

new const DeviceModel[] = "models/zombie_evolution/demonic_spirit.mdl"
new const HealSound[] = "zombie_evolution/zombie/voodoo_heal.wav"
new const DeviceSet[] = "zombie_evolution/zombie/voodoo_device_activate.wav"
new const DeviceLoop[] = "zombie_evolution/zombie/voodoo_device_loop.wav"

new const HealerSprite[] = "sprites/zombie_evolution/voodoo_heal.spr"
new const HealSprite[] = "sprites/zombie_evolution/zombie_heal.spr"

// Task
#define DEVICE_CLASSNAME "demonic_spirit"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_zombieclass
new g_MsgFov, g_ZombieHud, g_MsgScreenFade, Float:HealMe[33]
new g_CanHeal, g_HealCooldown[33]
new g_CanSet, g_SetCooldown[33]

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	register_think(DEVICE_CLASSNAME, "fw_DeviceThink")
	register_touch(DEVICE_CLASSNAME, "player", "fw_DeviceTouch")
	
	g_MsgFov = get_user_msgid("SetFOV")
	g_MsgScreenFade = get_user_msgid("ScreenFade")
	g_ZombieHud = CreateHudSyncObj(3)
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	formatex(GameName, sizeof(GameName), "%L", LANG_SERVER, "GAME_NAME")
	
	// Precache
	precache_model(DeviceModel)
	precache_sound(HealSound)
	precache_sound(DeviceSet)
	precache_sound(DeviceLoop)

	precache_model(HealerSprite)
	precache_model(HealSprite)
	
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

public zevo_round_new() remove_entity_name(DEVICE_CLASSNAME)

public zevo_user_spawn(id, Zombie)
{
	UnSet_BitVar(g_CanHeal, id)
	UnSet_BitVar(g_CanSet, id)
	
	g_HealCooldown[id] = 0
	g_SetCooldown[id] = 0
}

public zevo_become_zombie(id, attacker, zombieclass)
{
	// Reset
	if(zombieclass == g_zombieclass)
	{
		Set_BitVar(g_CanHeal, id)
		Set_BitVar(g_CanSet, id)
	
		g_HealCooldown[id] = 0
		g_SetCooldown[id] = 0
	} else {
		UnSet_BitVar(g_CanHeal, id)
		UnSet_BitVar(g_CanSet, id)
	
		g_HealCooldown[id] = 0
		g_SetCooldown[id] = 0
	}
}

public zevo_zombieclass_deactivate(id, ClassID)
{
	if(ClassID == g_zombieclass)
	{
		// Reset
		UnSet_BitVar(g_CanHeal, id)
		UnSet_BitVar(g_CanSet, id)
	
		g_HealCooldown[id] = 0
		g_SetCooldown[id] = 0
	}
}

public zevo_runningtime2(id, Time)
{
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
		
	// Cooldown
	if(g_HealCooldown[id] > 0) 
	{
		g_HealCooldown[id]--
		if(!g_HealCooldown[id]) 
			Set_BitVar(g_CanHeal, id)
	}
	if(g_SetCooldown[id] > 0) 
	{
		g_SetCooldown[id]--
		if(!g_SetCooldown[id]) Set_BitVar(g_CanSet, id)
	}
	
	// Hud
	static Skill1[64], Skill2[64], Special2[16]
	formatex(Special2, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LVREQ", 2)
	
	if(!g_HealCooldown[id]) formatex(Skill1, 31, "[G] : %L", GAME_LANG, "ZOMBIE_VOODOO_SKILL_HEAL")
	else formatex(Skill1, 63, "[G] : %L (%i)", GAME_LANG, "ZOMBIE_VOODOO_SKILL_HEAL", g_HealCooldown[id])
	if(zevo_get_playerlevel(id) >= 2)
	{
		if(!g_SetCooldown[id]) formatex(Skill2, 31, "[F] : %L", GAME_LANG, "ZOMBIE_VOODOO_SKILL_SET")
		else formatex(Skill2, 31, "[F] : %L (%i)", GAME_LANG, "ZOMBIE_VOODOO_SKILL_SET", g_SetCooldown[id])
	} else formatex(Skill2, 63, "[F] : %L (%s)", GAME_LANG, "ZOMBIE_VOODOO_SKILL_SET", Special2)
	
	set_hudmessage(255, 212, 42, -1.0, 0.10, 0, 2.0, 2.0)
	ShowSyncHudMsg(id, g_ZombieHud, "[%s]^n^n%s^n%s", zclass_name, Skill1, Skill2)
}

public zevo_zombieskill(id, ClassID, SkillButton)
{
	if(ClassID != g_zombieclass)
		return
		
	switch(SkillButton)
	{
		case SKILL_G: Skill_SelfHealing(id)
		case SKILL_F: Skill_SetDevice(id)
	}
}

public Skill_SelfHealing(id)
{
	if(!Get_BitVar(g_CanHeal, id))
		return
		
	static Float:StartHealth; StartHealth = float(zevo_get_maxhealth(id))
	if(get_user_health(id) < floatround(StartHealth))
	{
		UnSet_BitVar(g_CanHeal, id)
		g_HealCooldown[id] = HEAL_COOLDOWN
		
		// get health new
		static health_new; health_new = get_user_health(id) + HEAL_AMOUNT
		health_new = min(health_new, floatround(StartHealth))
		
		// set health
		set_user_health(id, health_new)
		
		// play sound heal
		PlaySound(id, HealSound)
		zevo_playerattachment(id, HealerSprite, 1.0, 0.5, 10.0)
		
		if(!zevo_get_nightvision(id, 1, 1))
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
		client_print(id, print_center, "%L", GAME_LANG, "ZOMBIE_VOODOO_FULL")
	}
}

public Skill_SetDevice(id)
{
	if(zevo_get_playerlevel(id) <= 1)
		return
	if(!Get_BitVar(g_CanSet, id))
		return
	if(!(pev(id, pev_flags) & FL_ONGROUND) || (pev(id, pev_flags) & FL_DUCKING))
		return
		
	UnSet_BitVar(g_CanSet, id)
	g_SetCooldown[id] = SET_COOLDOWN
	
	Create_EvilDevice(id)
}

public Create_EvilDevice(id)
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent)) return
	
	set_pev(Ent, pev_classname, DEVICE_CLASSNAME)
	set_pev(Ent, pev_solid, SOLID_TRIGGER)
	set_pev(Ent, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(Ent, pev_gravity, 1.0)
	
	set_pev(Ent, pev_animtime, get_gametime())
	set_pev(Ent, pev_framerate, 1.0)
	set_pev(Ent, pev_sequence, 0)
	
	set_pev(Ent, pev_iuser1, 0)
	set_pev(Ent, pev_owner, id)
	set_pev(Ent, pev_fuser1, get_gametime() + SET_TIME)
	
	new Float:mins[3] = { -10.0, -10.0, 0.0 }
	new Float:maxs[3] = { 10.0, 10.0, 16.0 }
	engfunc(EngFunc_SetSize, Ent, mins, maxs)
	
	// Set trap model
	engfunc(EngFunc_SetModel, Ent, DeviceModel)

	// Set trap position
	static Float:Origin[3]; get_position(id, 48.0, 0.0, 0.0, Origin)
	set_pev(Ent, pev_origin, Origin)
	
	// set invisible
	//fm_set_rendering(Ent, kRenderFxGlowShell, 250, 100, 100, kRenderTransAlpha, 16)
	
	EmitSound(Ent, CHAN_BODY, DeviceSet)
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.5)
}

public fw_DeviceThink(Ent)
{
	if(!pev_valid(Ent))
		return
		
	if(!pev(Ent, pev_iuser1))
	{
		set_pev(Ent, pev_iuser1, 1)
		
		new Float:mins[3] = { -160.0, -160.0, 0.0 }
		new Float:maxs[3] = { 160.0, 160.0, 64.0 }
		engfunc(EngFunc_SetSize, Ent, mins, maxs)
			
		set_pev(Ent, pev_animtime, get_gametime())
		set_pev(Ent, pev_framerate, 1.0)
		set_pev(Ent, pev_sequence, 1)
	}
	
	static Float:Time; pev(Ent, pev_fuser1, Time)
	if(Time < get_gametime())
	{
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		return
	} 
	
	static Float:Time2; pev(Ent, pev_fuser2, Time2)
	if(get_gametime() - 4.0 > Time2)
	{
		EmitSound(Ent, CHAN_ITEM, DeviceLoop)
		
		static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
		write_byte(TE_ELIGHT)
		write_short(Ent)
		write_coord_f(Origin[0])
		write_coord_f(Origin[1])
		write_coord_f(Origin[2] + 26.0)
		write_coord(10)
		write_byte(255) // ROJO, lo puse rojo para que se notara mas.
		write_byte(100) // VERDE
		write_byte(100) // AZUL
		write_byte(4 * 10)
		write_coord(0)
		message_end()
		
		set_pev(Ent, pev_fuser2, get_gametime())
	} 

	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public fw_DeviceTouch(Ent, id)
{
	if(!pev_valid(Ent) || !is_alive(id))
		return
	if(!zevo_is_zombie(id))
		return
		
	if(get_gametime() - 0.5 > HealMe[id])
	{
		static Float:StartHealth; StartHealth = float(zevo_get_maxhealth(id))
		if(get_user_health(id) < floatround(StartHealth))
		{
			// get health new
			static health_new; health_new = get_user_health(id) + SET_AMOUNT
			health_new = min(health_new, floatround(StartHealth))
			
			// set health
			set_user_health(id, health_new)
			zevo_playerattachment(id, HealSprite, 0.75, 0.1, 0.0)
		}
		
		HealMe[id] = get_gametime()
	}
}

public EmitSound(id, chan, const file_sound[]) emit_sound(id, chan, file_sound, 1.0, ATTN_NORM, 0, PITCH_NORM)

public Load_Class_Setting()
{
	static Temp[128]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_SERVER, "ZOMBIE_VOODOO_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_SERVER, "ZOMBIE_VOODOO_DESC")
	
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "VOODOO_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "VOODOO_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "VOODOO_KNOCKBACK", Temp, sizeof(Temp)); zclass_knockback = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "VOODOO_DEFENSE", Temp, sizeof(Temp)); zclass_defense = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "VOODOO_CLAWRANGE", Temp, sizeof(Temp)); zclass_clawrange = str_to_float(Temp)
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


stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
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
