#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <xs>
#include <zombie_evolution>

#define PLUGIN "[ZEVO] Zombie Class: Light"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define ZOMBIE_NAME "Light Zombie"
#define GAME_FOLDER "zombie_evolution"
#define SETTING_FILE "ZEvo_ZombieClassConfig.ini"
#define LANG_FILE "zombie_evolution.txt"

#define GAME_LANG LANG_SERVER

// Skill
#define INVISIBLE_TIME 15
#define INVISIBLE_COOLDOWN 25
#define INVISIBLE_SPEED 230
#define INVISIBLE_FOV 100

#define LEAP_COOLDOWN 30
#define LEAP_HEIGHT 850

/// Zombie Class
new GameName[] = "Zombie Evolution"

new zclass_name[32] = "Light Zombie"
new zclass_desc[32] = "Cloak & Leap"
new Float:zclass_speed = 295.0
new Float:zclass_gravity = 0.7
new Float:zclass_knockback = 2.0
new Float:zclass_defense = 0.85
new Float:zclass_clawrange = 48.0

new const zclass_modelorigin[] = "ev_light_origin"
new const zclass_modelhost[] = "ev_light_host"
new const zclass_clawmodel_origin[] = "v_claw_light.mdl"
new const zclass_clawmodel_host[] = "v_claw_light.mdl"
new const zclass_clawmodel_inv[] = "v_claw_light_inv.mdl"
new const zclass_deathsound[] = "zombie_evolution/zombie/light_death.wav"
new const zclass_painsound[] = "zombie_evolution/zombie/light_hurt.wav"
new const zclass_permcode = 2

new const invisible_sound[] = "zombie_evolution/zombie/light_invisible.wav"
new const leap_sound[] = "zombie_evolution/zombie/light_leap.wav"

// Task
#define TASK_INVISIBLE 21001

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_zombieclass
new g_MsgFov, g_ZombieHud
new g_CanInvisible, g_Invisibling, g_CloakTime[33]
new g_CanLeap, g_LeapTime[33]

// Shared Code
#define PDATA_SAFE 2
#define OFFSET_CSTEAMS 114
#define OFFSET_CSDEATHS 444
#define OFFSET_PLAYER_LINUX 5
#define OFFSET_WEAPON_LINUX 4
#define OFFSET_WEAPONOWNER 41

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_Item_Deploy_Post", 1)
	
	g_MsgFov = get_user_msgid("SetFOV")
	g_ZombieHud = CreateHudSyncObj(3)
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	formatex(GameName, sizeof(GameName), "%L", LANG_SERVER, "GAME_NAME")
	
	// Precache
	static Buffer[128];
	formatex(Buffer, 127, "models/%s/zombie/%s", GAME_FOLDER, zclass_clawmodel_inv)
	precache_model(Buffer)
	precache_sound(invisible_sound)
	precache_sound(leap_sound)
	
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
	remove_task(id+TASK_INVISIBLE)
	
	UnSet_BitVar(g_CanInvisible, id)
	UnSet_BitVar(g_CanLeap, id)
	UnSet_BitVar(g_Invisibling, id)
}

public zevo_become_zombie(id, attacker, zombieclass)
{
	// Reset
	remove_task(id+TASK_INVISIBLE)
		
	if(zombieclass == g_zombieclass)
	{
		Set_BitVar(g_CanInvisible, id)
		Set_BitVar(g_CanLeap, id)
		UnSet_BitVar(g_Invisibling, id)
		
		zevo_set_usingskill(id, 0)
		
		g_CloakTime[id] = 0
		g_LeapTime[id] = 0
	} else {
		UnSet_BitVar(g_CanInvisible, id)
		UnSet_BitVar(g_CanLeap, id)
		UnSet_BitVar(g_Invisibling, id)
	}
}

public zevo_zombieclass_deactivate(id, ClassID)
{
	if(ClassID == g_zombieclass)
	{
		// Reset
		remove_task(id+TASK_INVISIBLE)
		
		UnSet_BitVar(g_CanInvisible, id)
		UnSet_BitVar(g_CanLeap, id)
		UnSet_BitVar(g_Invisibling, id)
	}
}

public zevo_player_levelup(id, Level, Zombie)
{
	if(!Zombie) return
	if(Level != 2) return
	
	if(Get_BitVar(g_Invisibling, id))
	{
		static Buffer[128];
		formatex(Buffer, 127, "models/zombie_evolution/zombie/%s", zclass_clawmodel_inv)
		set_pev(id, pev_viewmodel2, Buffer)
	}
}

public fw_Item_Deploy_Post(Ent)
{
	static id; id = fm_cs_get_weapon_ent_owner(Ent)
	if (!is_alive(id))
		return;
	if(!zevo_is_zombie(id))
		return
	if(zevo_get_zombieclass(id) != g_zombieclass)
		return
	if(Get_BitVar(g_Invisibling, id))
	{
		static Buffer[128];
		formatex(Buffer, 127, "models/zombie_evolution/zombie/%s", zclass_clawmodel_inv)
		set_pev(id, pev_viewmodel2, Buffer)
	}
}

public zevo_runningtime2(id, Time)
{
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
	if(zevo_get_subtype(id) != ZOMBIE_NORMAL)
		return
		
	// Cooldown
	if(g_CloakTime[id] > 0) 
	{
		g_CloakTime[id]--
		if(!g_CloakTime[id]) 
		{
			Set_BitVar(g_CanInvisible, id)
			UnSet_BitVar(g_Invisibling, id)
		}
	}
	if(g_LeapTime[id] > 0) 
	{
		g_LeapTime[id]--
		if(!g_LeapTime[id]) Set_BitVar(g_CanLeap, id)
	}
	
	// Hud
	static Skill1[32], Skill2[32], Special[16], Special2[16]
	
	formatex(Special, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LEFTMOUSE")
	formatex(Special2, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LVREQ", 2)
	
	if(!g_CloakTime[id]) formatex(Skill1, 31, "[G] : %L", GAME_LANG, "ZOMBIE_LIGHT_SKILL_INV")
	else formatex(Skill1, 31, "[G] : %L (%i)", GAME_LANG, "ZOMBIE_LIGHT_SKILL_INV", g_CloakTime[id])
	if(zevo_get_playerlevel(id) >= 2)
	{
		if(!g_LeapTime[id]) formatex(Skill2, 31, "[F] : %L", GAME_LANG, "ZOMBIE_LIGHT_SKILL_LEAP")
		else formatex(Skill2, 31, "[F] : %L (%i)", GAME_LANG, "ZOMBIE_LIGHT_SKILL_LEAP", g_LeapTime[id])
	} else formatex(Skill2, 31, "[F] : %L (%s)", GAME_LANG, "ZOMBIE_LIGHT_SKILL_LEAP", Special2)
	
	set_hudmessage(255, 212, 42, -1.0, 0.10, 0, 2.0, 2.0)
	ShowSyncHudMsg(id, g_ZombieHud, "[%s]^n^n%s^n%s", zclass_name, Skill1, Skill2)
}

public zevo_zombieskill(id, ClassID, SkillButton)
{
	if(ClassID != g_zombieclass)
		return
		
	switch(SkillButton)
	{
		case SKILL_G: Skill_Invisible(id)
		case SKILL_F: Skill_Leap(id)
	}
}

public Skill_Invisible(id)
{
	if(!Get_BitVar(g_CanInvisible, id))
		return
	if(Get_BitVar(g_Invisibling, id))
		return
	
	// Set Vars
	Set_BitVar(g_Invisibling, id)
	UnSet_BitVar(g_CanInvisible, id)
	g_CloakTime[id] = INVISIBLE_COOLDOWN
	zevo_set_usingskill(id, 1)
	
	engclient_cmd(id, "weapon_knife")
	
	// Set Render Red
	set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 16)

	// Set Fov
	SetFov(id, INVISIBLE_FOV)
	zevo_speed_set(id, float(INVISIBLE_SPEED), 1)
	
	// Play Berserk Sound
	EmitSound(id, CHAN_ITEM, invisible_sound)
	
	// Set Invisible Claws
	static Buffer[128];
	formatex(Buffer, 127, "models/zombie_evolution/zombie/%s", zclass_clawmodel_inv)
	set_pev(id, pev_viewmodel2, Buffer)
	
	// Set Time
	set_task(float(INVISIBLE_TIME), "Remove_Invisible", id+TASK_INVISIBLE)
}

public Remove_Invisible(id)
{
	id -= TASK_INVISIBLE

	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id))
		return
	if(zevo_get_zombieclass(id) != g_zombieclass)
		return
	if(!Get_BitVar(g_Invisibling, id))
		return	

	// Set Vars
	UnSet_BitVar(g_Invisibling, id)
	UnSet_BitVar(g_CanInvisible, id)
	zevo_set_usingskill(id, 0)
	
	engclient_cmd(id, "weapon_knife")
	
	// Reset 
	set_user_rendering(id)
	SetFov(id)
	
	// Remove Invisible Claws
	static Claws[128];
	if(get_user_weapon(id) == CSW_KNIFE)
	{
		formatex(Claws, sizeof(Claws), "models/zombie_evolution/zombie/%s", zevo_get_playerlevel(id) <= 1 ? zclass_clawmodel_host : zclass_clawmodel_origin)
		set_pev(id, pev_viewmodel2, Claws)
	}
	
	// Reset Speed
	zevo_speed_set(id, zclass_speed, 1)
}

public Skill_Leap(id)
{
	if(!Get_BitVar(g_CanLeap, id))
		return
	if(zevo_get_playerlevel(id) <= 1)
		return
	if(pev(id, pev_flags) & FL_DUCKING)
		return
		
	UnSet_BitVar(g_CanLeap, id)
	g_LeapTime[id] = LEAP_COOLDOWN

	static Float:Origin1[3], Float:Origin2[3]
	pev(id, pev_origin, Origin1)

	set_pdata_float(id, 83, 3.0, 5)
	
	get_position(id, 180.0, 0.0, 650.0, Origin2)
	static Float:Velocity[3]; Get_SpeedVector(Origin1, Origin2, float(LEAP_HEIGHT), Velocity)
	
	set_pev(id, pev_velocity, Velocity)
	emit_sound(id, CHAN_VOICE, leap_sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
}

public EmitSound(id, chan, const file_sound[]) emit_sound(id, chan, file_sound, 1.0, ATTN_NORM, 0, PITCH_NORM)

public Load_Class_Setting()
{
	static Temp[128]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_SERVER, "ZOMBIE_LIGHT_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_SERVER, "ZOMBIE_LIGHT_DESC")
	
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "LIGHT_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "LIGHT_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "LIGHT_KNOCKBACK", Temp, sizeof(Temp)); zclass_knockback = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "LIGHT_DEFENSE", Temp, sizeof(Temp)); zclass_defense = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "LIGHT_CLAWRANGE", Temp, sizeof(Temp)); zclass_clawrange = str_to_float(Temp)
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

stock fm_cs_get_weapon_ent_owner(ent)
{
	// Prevent server crash if entity's private data not initalized
	if (pev_valid(ent) != PDATA_SAFE)
		return -1;
	
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_WEAPON_LINUX);
}
