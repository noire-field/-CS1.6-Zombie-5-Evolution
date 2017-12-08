#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <xs>
#include <zombie_evolution>

#define PLUGIN "[ZEVO] Zombie Class: Sting Finger"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define ZOMBIE_NAME "Sting Finger"
#define GAME_FOLDER "zombie_evolution"
#define SETTING_FILE "ZEvo_ZombieClassConfig.ini"
#define LANG_FILE "zombie_evolution.txt"

#define GAME_LANG LANG_SERVER

// Skill
#define FINGE_COOLDOWN 60
#define FINGE_DISTANCE 140
#define FLASH_COOLDOWN 45
#define FLASH_RADIUS 840
#define FLASH_BLINDTIME 3.0

/// Zombie Class
new GameName[] = "Zombie Evolution"

new zclass_name[32] = "Sting Finger"
new zclass_desc[32] = "Penetrate + Flash"
new Float:zclass_speed = 29.0
new Float:zclass_gravity = 0.7
new Float:zclass_knockback = 1.5
new Float:zclass_defense = 0.85
new Float:zclass_clawrange = 48.0

new const zclass_modelorigin[] = "ev_stingfinger_origin"
new const zclass_modelhost[] = "ev_stingfinger_host"
new const zclass_clawmodel_origin[] = "v_claw_stingfinger.mdl"
new const zclass_clawmodel_host[] = "v_claw_stingfinger.mdl"
new const zclass_deathsound[] = "zombie_evolution/zombie/stingfinger_death.wav"
new const zclass_painsound[] = "zombie_evolution/zombie/stingfinger_hurt.wav"
new const zclass_permcode = 9

new const FingeSound[] = "zombie_evolution/zombie/stingfinger_penetration.wav"
new const FlashSound[] = "zombie_evolution/zombie/stingfinger_flash.wav"
new const FlashHit[] = "zombie_evolution/action/flashscreen.wav"
new const TrapVoice[2][] = 
{
	"zombie_evolution/action/trapped_male.wav",
	"zombie_evolution/action/trapped_female.wav",
}
new const PlayerBlind[] = "sprites/zombie_evolution/head_blind.spr"

// Task
#define TASK_FLASHING 28001
#define TASK_FLASHED 28001

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_zombieclass
new g_MsgFov, g_ZombieHud, g_MaxPlayers
new g_CanFinge, g_FingeTime[33]
new g_CanFlash, g_Flashing, g_FlashTime[33]

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	
	g_MaxPlayers = get_maxplayers()
	g_MsgFov = get_user_msgid("SetFOV")
	g_ZombieHud = CreateHudSyncObj(3)
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	formatex(GameName, sizeof(GameName), "%L", LANG_SERVER, "GAME_NAME")
	
	// Precache
	precache_sound(FingeSound)
	precache_sound(FlashSound)
	precache_sound(FlashHit)
	precache_sound(TrapVoice[0])
	precache_sound(TrapVoice[1])
	precache_model(PlayerBlind)
	
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
	// Reset
	remove_task(id+TASK_FLASHING)
	remove_task(id+TASK_FLASHED)
	
	UnSet_BitVar(g_CanFinge, id)
	UnSet_BitVar(g_CanFlash, id)
	
	g_FingeTime[id] = 0
	g_FlashTime[id] = 0
}

public zevo_become_zombie(id, attacker, zombieclass)
{
	// Reset
	remove_task(id+TASK_FLASHING)
	remove_task(id+TASK_FLASHED)
	
	if(zombieclass == g_zombieclass)
	{
		Set_BitVar(g_CanFinge, id)
		Set_BitVar(g_CanFlash, id)
		UnSet_BitVar(g_Flashing, id)
		
		g_FingeTime[id] = 0
		g_FlashTime[id] = 0
	} else {
		UnSet_BitVar(g_CanFinge, id)
		UnSet_BitVar(g_CanFlash, id)
		UnSet_BitVar(g_Flashing, id)
		
		g_FingeTime[id] = 0
		g_FlashTime[id] = 0
	}
}

public zevo_zombieclass_deactivate(id, ClassID)
{
	if(ClassID == g_zombieclass)
	{
		// Reset
		remove_task(id+TASK_FLASHING)
		remove_task(id+TASK_FLASHED)
		
		UnSet_BitVar(g_CanFinge, id)
		UnSet_BitVar(g_CanFlash, id)
		UnSet_BitVar(g_Flashing, id)
		
		g_FingeTime[id] = 0
		g_FlashTime[id] = 0
	}
}

public zevo_runningtime2(id, Time)
{
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
		
	// Cooldown
	if(g_FingeTime[id] > 0) 
	{
		g_FingeTime[id]--
		if(!g_FingeTime[id]) 
			Set_BitVar(g_CanFinge, id)
	}
	if(g_FlashTime[id] > 0) 
	{
		g_FlashTime[id]--
		if(!g_FlashTime[id]) 
		{
			Set_BitVar(g_CanFlash, id)
			UnSet_BitVar(g_Flashing, id)
		}
	}
	
	// Hud
	static Skill1[32], Skill2[32], Special[16], Special2[16]
	
	formatex(Special, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LEFTMOUSE")
	formatex(Special2, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LVREQ", 2)
	
	if(!g_FingeTime[id]) formatex(Skill1, 31, "[G] : %L", GAME_LANG, "ZOMBIE_STINGFINGER_SKILL_FINGE")
	else formatex(Skill1, 31, "[G] : %L (%i)", GAME_LANG, "ZOMBIE_STINGFINGER_SKILL_FINGE", g_FingeTime[id])
	if(zevo_get_playerlevel(id) >= 2)
	{
		if(!g_FlashTime[id]) formatex(Skill2, 31, "[F] : %L", GAME_LANG, "ZOMBIE_STINGFINGER_SKILL_FLASH")
		else formatex(Skill2, 31, "[F] : %L (%i)", GAME_LANG, "ZOMBIE_STINGFINGER_SKILL_FLASH", g_FlashTime[id])
	} else formatex(Skill2, 31, "[F] : %L (%s)", GAME_LANG, "ZOMBIE_STINGFINGER_SKILL_FLASH", Special2)
	
	set_hudmessage(255, 212, 42, -1.0, 0.10, 0, 2.0, 2.0)
	ShowSyncHudMsg(id, g_ZombieHud, "[%s]^n^n%s^n%s", zclass_name, Skill1, Skill2)
}

public zevo_zombieskill(id, ClassID, SkillButton)
{
	if(ClassID != g_zombieclass)
		return

	switch(SkillButton)
	{
		case SKILL_G: Skill_Finge(id)
		case SKILL_F: Skill_Flashing(id)
	}
}

public Skill_Finge(id)
{
	if(!Get_BitVar(g_CanFinge, id))
		return
	if(Get_BitVar(g_Flashing, id))
		return
	
	UnSet_BitVar(g_CanFinge, id)
	g_FingeTime[id] = FINGE_COOLDOWN
	
	// Prepartion
	engclient_cmd(id, "weapon_knife")
	
	zevo_set_fakeattack(id, 94)
	set_pev(id, pev_framerate, 2.0)
	Set_Player_NextAttack(id, 1.5)
	set_weapons_timeidle(id, CSW_KNIFE, 1.65)
	
	Set_WeaponAnim(id, 8)
	EmitSound(id, CHAN_WEAPON, FingeSound)
	
	Check_FingeTarget(id)
}

public Check_FingeTarget(id)
{
	static Float:Max_Distance, Float:Point[4][3], Float:TB_Distance
	
	Max_Distance = float(FINGE_DISTANCE)
	TB_Distance = Max_Distance / 4.0
	
	static Float:VicOrigin[3], Float:MyOrigin[3]
	pev(id, pev_origin, MyOrigin); MyOrigin[2] += 26.0
	
	for(new i = 0; i < 4; i++) get_position(id, TB_Distance * (i + 1), 0.0, 0.0, Point[i])
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(zevo_is_zombie(i))
			continue
		if(entity_range(id, i) > Max_Distance)
			continue
	
		pev(i, pev_origin, VicOrigin)
		VicOrigin[2] += 16.0
		if(is_wall_between_points(MyOrigin, VicOrigin, id))
			continue

		if(get_distance_f(VicOrigin, Point[0]) <= 32.0 
		|| get_distance_f(VicOrigin, Point[1]) <= 32.0
		|| get_distance_f(VicOrigin, Point[2]) <= 32.0
		|| get_distance_f(VicOrigin, Point[3]) <= 32.0)
			ExecuteHamB(Ham_TakeDamage, i, fm_get_user_weapon_entity(id, CSW_KNIFE), id, 125.0, DMG_SLASH)
	}	
}

public Skill_Flashing(id)
{
	if(zevo_get_playerlevel(id) <= 1)
		return
	if(!Get_BitVar(g_CanFlash, id))
		return
	if(Get_BitVar(g_Flashing, id))
		return
	
	UnSet_BitVar(g_CanFlash, id)
	g_FlashTime[id] = FLASH_COOLDOWN
	
	// Prepartion
	engclient_cmd(id, "weapon_knife")
	
	zevo_set_fakeattack(id, 98)
	set_pev(id, pev_framerate, 2.0)
	Set_Player_NextAttack(id, 1.45)
	set_weapons_timeidle(id, CSW_KNIFE, 1.5)
	
	Set_WeaponAnim(id, 9)
	
	remove_task(id+TASK_FLASHING)
	set_task(0.5, "Flashing", id+TASK_FLASHING)
}

public Flashing(id)
{
	id -= TASK_FLASHING
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
		
	EmitSound(id, CHAN_WEAPON, FlashSound)
	
	zevo_set_nightvision(id, 1, 0, 0, 1)
	ScreenFade(id, 0.5, 255, 255, 255, 255)
	
	// Level Up Around
	static Victim; Victim = -1
	static Float:Origin[3]; pev(id, pev_origin, Origin); Origin[2] += 26.0
	static Float:Target[3]

	while((Victim = find_ent_in_sphere(Victim, Origin, float(FLASH_RADIUS))) != 0)
	{
		if(Victim == id)
			continue
		if(!is_alive(Victim))
			continue
		if(zevo_is_zombie(Victim))
			continue
		pev(Victim, pev_origin, Target);
		Target[2] += 16.0
		if(is_wall_between_points(Origin, Target, id))
			continue
		if(!is_in_viewcone(Victim, Origin))
			continue
			
		if(zevo_get_playersex(Victim) == PLAYER_MALE) EmitSound(Victim, CHAN_VOICE, TrapVoice[0])
		else if(zevo_get_playersex(Victim) == PLAYER_FEMALE) EmitSound(Victim, CHAN_VOICE, TrapVoice[1])
		
		zevo_playerattachment(Victim, PlayerBlind, FLASH_BLINDTIME, 1.0, 0.0)
		
		zevo_set_nightvision(Victim, 1, 0, 0, 1)
		ScreenFade(Victim, FLASH_BLINDTIME, 255, 255, 255, 255)
	}
	
}

public ScreenFade(id, Float:fDuration, red, green, blue, alpha)
{
	static MSG 
	if(!MSG) MSG = get_user_msgid("ScreenFade")
	
	message_begin(MSG_ONE_UNRELIABLE, MSG, {0, 0, 0}, id)
	write_short(floatround(4096.0 * fDuration, floatround_round));
	write_short(floatround(4096.0 * fDuration, floatround_round));
	write_short(4096);
	write_byte(red);
	write_byte(green);
	write_byte(blue);
	write_byte(alpha);
	message_end();}

public EmitSound(id, chan, const file_sound[]) emit_sound(id, chan, file_sound, 1.0, ATTN_NORM, 0, PITCH_NORM)

public Load_Class_Setting()
{
	static Temp[128]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_SERVER, "ZOMBIE_STINGFINGER_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_SERVER, "ZOMBIE_STINGFINGER_DESC")
	
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "STINGFINGER_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "STINGFINGER_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "STINGFINGER_KNOCKBACK", Temp, sizeof(Temp)); zclass_knockback = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "STINGFINGER_DEFENSE", Temp, sizeof(Temp)); zclass_defense = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "STINGFINGER_CLAWRANGE", Temp, sizeof(Temp)); zclass_clawrange = str_to_float(Temp)
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

stock is_wall_between_points(Float:start[3], Float:end[3], ignore_ent)
{
	static ptr
	ptr = create_tr2()

	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ignore_ent, ptr)
	
	static Float:EndPos[3]
	get_tr2(ptr, TR_vecEndPos, EndPos)

	return floatround(get_distance_f(end, EndPos))
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
