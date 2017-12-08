#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <xs>
#include <zombie_evolution>

#define PLUGIN "[ZEVO] Zombie Class: Regular"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define ZOMBIE_NAME "Regular Zombie"
#define GAME_FOLDER "zombie_evolution"
#define SETTING_FILE "ZEvo_ZombieClassConfig.ini"
#define LANG_FILE "zombie_evolution.txt"

#define GAME_LANG LANG_SERVER

// Skill
#define BERSERK_COLOR_R 255
#define BERSERK_COLOR_G 3
#define BERSERK_COLOR_B 0

#define BERSERK_FOV 105
#define BERSERK_SPEED 375
#define BERSERK_GRAVITY 0.65
#define BERSERK_FRAMERATE 1.5

#define BERSERK_TIME 7
#define BERSERK_COOLDOWN 14

/// Zombie Class
new GameName[] = "Zombie Evolution"

new zclass_name[32] = "Regular Zombie"
new zclass_desc[32] = "Berserk & Climb"
new Float:zclass_speed = 285.0
new Float:zclass_gravity = 0.75
new Float:zclass_knockback = 1.0
new Float:zclass_defense = 1.0
new Float:zclass_clawrange = 48.0

new const zclass_modelorigin[] = "ev_regular_origin"
new const zclass_modelhost[] = "ev_regular_host"
new const zclass_clawmodel_origin[] = "v_claw_regular.mdl"
new const zclass_clawmodel_host[] = "v_claw_regular.mdl"
new const zclass_deathsound[] = "zombie_evolution/zombie/regular_death.wav"
new const zclass_painsound[] = "zombie_evolution/zombie/regular_hurt.wav"
new const zclass_permcode = 1

new const Berserk_Start[] = "zombie_evolution/zombie/regular_pressure.wav"
new const Berserk_Keep[2][] = 
{
	"zombie_evolution/zombie/regular_pre_idle1.wav",
	"zombie_evolution/zombie/regular_pre_idle2.wav"
}
new const BerserkSprite[] = "sprites/zombie_evolution/regular_berserk.spr"

// Task
#define TASK_BERSERKING 20000
#define TASK_BERSERK_SOUND 20001
#define TASK_AURA 21002

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_zombieclass
new g_CanBerserk, g_Berserking, g_BerserkCooldown[33]
new Float:g_WallOrigin[32][3]

new g_MsgFov, g_ZombieHud

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	
	register_forward(FM_Touch, "fw_Touch")
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
	
	g_MsgFov = get_user_msgid("SetFOV")
	g_ZombieHud = CreateHudSyncObj(3)
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	formatex(GameName, sizeof(GameName), "%L", LANG_SERVER, "GAME_NAME")
	
	// Precache
	precache_sound(Berserk_Start)
	precache_sound(Berserk_Keep[0])
	precache_sound(Berserk_Keep[1])
	precache_model(BerserkSprite)
	
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
	remove_task(id+TASK_BERSERKING)
	remove_task(id+TASK_BERSERK_SOUND)
	remove_task(id+TASK_AURA)
	
	UnSet_BitVar(g_CanBerserk, id)
	UnSet_BitVar(g_Berserking, id)
		
	g_BerserkCooldown[id] = 0
}

public zevo_become_zombie(id, attacker, zombieclass)
{
	// Reset
	remove_task(id+TASK_BERSERKING)
	remove_task(id+TASK_BERSERK_SOUND)
	remove_task(id+TASK_AURA)

	if(zombieclass == g_zombieclass)
	{
		Set_BitVar(g_CanBerserk, id)
		UnSet_BitVar(g_Berserking, id)
		
		g_BerserkCooldown[id] = 0
	} else {
		UnSet_BitVar(g_CanBerserk, id)
		UnSet_BitVar(g_Berserking, id)
		
		g_BerserkCooldown[id] = 0
	}
}

public zevo_zombieclass_deactivate(id, ClassID)
{
	if(ClassID == g_zombieclass)
	{
		// Reset
		remove_task(id+TASK_BERSERKING)
		remove_task(id+TASK_BERSERK_SOUND)
		remove_task(id+TASK_AURA)
	
		UnSet_BitVar(g_CanBerserk, id)
		UnSet_BitVar(g_Berserking, id)
		
		g_BerserkCooldown[id] = 0
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
	if(g_BerserkCooldown[id] > 0) 
	{
		g_BerserkCooldown[id]--
		if(!g_BerserkCooldown[id]) 
		{
			Set_BitVar(g_CanBerserk, id)
			UnSet_BitVar(g_Berserking, id)
		}
	}
	
	// Hud
	static Skill1[32], Skill2[32], Special[16], Special2[16]
	
	formatex(Special, 15, "W + %L", GAME_LANG, "ZOMBIE_SKILL_LEFTMOUSE")
	formatex(Special2, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LVREQ", 2)
	
	if(!g_BerserkCooldown[id]) formatex(Skill1, 31, "[G] : %L", GAME_LANG, "ZOMBIE_REGULAR_SKILL_BERSERK")
	else formatex(Skill1, 31, "[G] : %L (%i)", GAME_LANG, "ZOMBIE_REGULAR_SKILL_BERSERK", g_BerserkCooldown[id])
	if(zevo_get_playerlevel(id) >= 2) formatex(Skill2, 31, "[%s] : %L", Special, GAME_LANG, "ZOMBIE_REGULAR_SKILL_CLIMB")
	else formatex(Skill2, 31, "[%s] : %L (%s)", Special, GAME_LANG, "ZOMBIE_REGULAR_SKILL_CLIMB", Special2)
	
	set_hudmessage(255, 212, 42, -1.0, 0.10, 0, 2.0, 2.0)
	ShowSyncHudMsg(id, g_ZombieHud, "[%s]^n^n%s^n%s", zclass_name, Skill1, Skill2)
}

public zevo_zombieskill(id, ClassID, SkillButton)
{
	if(ClassID != g_zombieclass)
		return
		
	switch(SkillButton)
	{
		case SKILL_G: Skill_Berserk(id)
	}
}

public Skill_Berserk(id)
{
	if(!Get_BitVar(g_CanBerserk, id))
		return
	if(Get_BitVar(g_Berserking, id))
		return
		
	// Set Vars
	UnSet_BitVar(g_CanBerserk, id)
	Set_BitVar(g_Berserking, id)
	g_BerserkCooldown[id] = BERSERK_COOLDOWN
	
	// Decrease Health & Set Render
	set_user_rendering(id, kRenderFxGlowShell, BERSERK_COLOR_R, BERSERK_COLOR_G, BERSERK_COLOR_B, kRenderNormal, 0)

	// Set Fov
	SetFov(id, BERSERK_FOV)
	Effect_RedAura(id+TASK_AURA)
	
	// Set MaxSpeed & Gravity
	set_pev(id, pev_gravity, BERSERK_GRAVITY)
	set_pev(id, pev_framerate, BERSERK_FRAMERATE)
	zevo_speed_set(id, float(BERSERK_SPEED), 1)
	
	// Play Berserk Sound
	EmitSound(id, CHAN_VOICE, Berserk_Start)
	zevo_playerattachment(id, BerserkSprite, 1.0, 0.25, 12.0)
	
	// Set Task
	set_task(2.0, "Berserk_HeartBeat", id+TASK_BERSERK_SOUND)
	set_task(float(BERSERK_TIME), "Remove_Berserk", id+TASK_BERSERKING)
}

public Effect_RedAura(id)
{
	id -= TASK_AURA
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id))
		return
	if(zevo_get_zombieclass(id) != g_zombieclass)
		return
	if(!Get_BitVar(g_Berserking, id))
		return
		
	static Float:Origin[3]
	pev(id, pev_origin, Origin)
		
	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id)
	write_byte(TE_DLIGHT) // TE id
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_byte(10) // radius
	write_byte(BERSERK_COLOR_R) // r
	write_byte(BERSERK_COLOR_G) // g
	write_byte(BERSERK_COLOR_B) // b
	write_byte(2) // life
	write_byte(0) // decay rate
	message_end()
	
	set_task(0.1, "Effect_RedAura", id+TASK_AURA)
}

public Remove_Berserk(id)
{
	id -= TASK_BERSERKING

	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id))
		return
	if(zevo_get_zombieclass(id) != g_zombieclass)
		return
	if(!Get_BitVar(g_Berserking, id))
		return

	// Set Vars
	UnSet_BitVar(g_Berserking, id)
	UnSet_BitVar(g_CanBerserk, id)
	
	// Reset 
	set_user_rendering(id)
	SetFov(id)
	
	// Reset Speed
	zevo_speed_set(id, zclass_speed, 1)
	set_pev(id, pev_framerate, 1.0)
}

public Berserk_HeartBeat(id)
{
	id -= TASK_BERSERK_SOUND
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id))
		return
	if(zevo_get_zombieclass(id) != g_zombieclass)
		return
	if(!Get_BitVar(g_Berserking, id))
		return
		
	EmitSound(id, CHAN_VOICE, Berserk_Keep[random(sizeof(Berserk_Keep))])
	set_task(2.0, "Berserk_HeartBeat", id+TASK_BERSERK_SOUND)
}

public fw_Touch(id, world)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return FMRES_IGNORED
		
	pev(id, pev_origin, g_WallOrigin[id])

	return FMRES_IGNORED
}

public fw_PlayerPreThink(id)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return FMRES_IGNORED
	if(zevo_get_playerlevel(id) < 2)
		return FMRES_IGNORED
		
	static Button; Button = get_user_button(id)
		
	if(Button & IN_ATTACK) WallClimb(id, Button)

	return FMRES_IGNORED
}

public WallClimb(id, button)
{
	static Float:origin[3]
	pev(id, pev_origin, origin)

	if(get_distance_f(origin, g_WallOrigin[id]) > 25.0)
		return 
	
	if(pev(id, pev_flags) & FL_ONGROUND)
		return
		
	static Float:velocity[3]
	if(button & IN_FORWARD)
	{
		velocity_by_aim(id, 120, velocity)
		fm_set_user_velocity(id, velocity)
	}
	
	return
}	

public EmitSound(id, chan, const file_sound[]) emit_sound(id, chan, file_sound, 1.0, ATTN_NORM, 0, PITCH_NORM)

public Load_Class_Setting()
{
	static Temp[128]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_SERVER, "ZOMBIE_REGULAR_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_SERVER, "ZOMBIE_REGULAR_DESC")
	
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "REGULAR_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "REGULAR_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "REGULAR_KNOCKBACK", Temp, sizeof(Temp)); zclass_knockback = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "REGULAR_DEFENSE", Temp, sizeof(Temp)); zclass_defense = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "REGULAR_CLAWRANGE", Temp, sizeof(Temp)); zclass_clawrange = str_to_float(Temp)
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
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
