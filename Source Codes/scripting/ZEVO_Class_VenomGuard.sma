#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <xs>
#include <zombie_evolution>

#define PLUGIN "[ZEVO] Zombie Class: Example"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define ZOMBIE_NAME "Venom Guard"
#define GAME_FOLDER "zombie_evolution"
#define SETTING_FILE "ZEvo_ZombieClassConfig.ini"
#define LANG_FILE "zombie_evolution.txt"

#define GAME_LANG LANG_SERVER

// Skill
#define HOWL_COOLDOWN 45
#define HOWL_RADIUS 240
#define HOWL_TIME 5

#define SELF_COOLDOWN 60
#define SELF_RADIUS 300
#define DEATH_KNOCKPOWER 1200.0

/// Zombie Class
new GameName[] = "Zombie Evolution"

new zclass_name[32] = "Venom Guard"
new zclass_desc[32] = "Howling + Self-Destruction"
new Float:zclass_speed = 270.0
new Float:zclass_gravity = 1.2
new Float:zclass_knockback = 2.25
new Float:zclass_defense = 2.25
new Float:zclass_clawrange = 48.0

new const zclass_modelorigin[] = "ev_venomguard_origin"
new const zclass_modelhost[] = "ev_venomguard_host"
new const zclass_clawmodel_origin[] = "v_claw_venomguard.mdl"
new const zclass_clawmodel_host[] = "v_claw_venomguard.mdl"
new const zclass_deathsound[] = "zombie_evolution/zombie/venomguard_death.wav"
new const zclass_painsound[] = "zombie_evolution/zombie/venomguard_hurt.wav"
new const zclass_permcode = 10 

new const HowlSound[] = "zombie_evolution/zombie/venomguard_howl.wav"
new const Exp[] = "sprites/zombie_evolution/venomguard_exp.spr"
new const Exp2[] = "sprites/zombie_evolution/venomguard_poison.spr"

// Task
#define TASK_HOWLING 29001

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_zombieclass
new g_MsgFov, g_ZombieHud
new g_CanHowl, g_Howling, g_HowlTime[33], g_Ring_SprID, g_Exp_SprID, g_Exp2_SprID
new g_CanSui, g_SuiTime[33]

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	register_message(get_user_msgid("ClCorpse"), "Message_ClCorpse")
	
	g_MsgFov = get_user_msgid("SetFOV")
	g_ZombieHud = CreateHudSyncObj(3)
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	formatex(GameName, sizeof(GameName), "%L", LANG_SERVER, "GAME_NAME")
	
	// Precache
	precache_sound(HowlSound)
	g_Ring_SprID = precache_model("sprites/shockwave.spr")
	g_Exp_SprID = precache_model(Exp)
	g_Exp2_SprID = precache_model(Exp2)
	
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

public Message_ClCorpse()
{
	static id; id = get_msg_arg_int(12)
	
	if(is_connected(id) && zevo_is_zombie(id) && zevo_get_zombieclass(id) == g_zombieclass)
		return PLUGIN_HANDLED
		
	return PLUGIN_CONTINUE
}

public zevo_user_spawn(id, Zombie)
{
	// Reset
	remove_task(id+TASK_HOWLING)
	
	UnSet_BitVar(g_CanHowl, id)
	UnSet_BitVar(g_CanSui, id)
	UnSet_BitVar(g_Howling, id)
	
	if(!Zombie) g_SuiTime[id] = 0
}

public zevo_user_death(id)
{
	if(zevo_is_zombie(id) && zevo_get_zombieclass(id) == g_zombieclass)
	{
		// Hide
		set_entity_visibility(id, 0)
		
		// Origin
		static Float:Origin[3];
		pev(id, pev_origin, Origin)
		
		// Make Explosion
		message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
		write_byte(TE_EXPLOSION)
		write_coord_f(Origin[0])	// start position
		write_coord_f(Origin[1])
		write_coord_f(Origin[2] + 60.0)
		write_short(g_Exp_SprID)	// sprite index
		write_byte(7)	// scale in 0.1's
		write_byte(10)	// framerate
		write_byte(TE_EXPLFLAG_NOSOUND)	// flags
		message_end()
		
		// Make Explosion 2
		message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
		write_byte(TE_EXPLOSION)
		write_coord_f(Origin[0])	// start position
		write_coord_f(Origin[1])
		write_coord_f(Origin[2] + 40.0)
		write_short(g_Exp2_SprID)	// sprite index
		write_byte(10)	// scale in 0.1's
		write_byte(15)	// framerate
		write_byte(TE_EXPLFLAG_NOSOUND)	// flags
		message_end()
		
		Check_Effect(id, Origin)
	}
}

public Check_Effect(id, Float:Origin[3])
{
	static Victim; Victim = -1
	
	// A ring effect
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, Origin[0]) // x
	engfunc(EngFunc_WriteCoord, Origin[1]) // y
	engfunc(EngFunc_WriteCoord, Origin[2]) // z
	engfunc(EngFunc_WriteCoord, Origin[0]) // x axis
	engfunc(EngFunc_WriteCoord, Origin[1]) // y axis
	engfunc(EngFunc_WriteCoord, Origin[2] + float(SELF_RADIUS)) // z axis
	write_short(g_Ring_SprID) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(10) // life
	write_byte(25) // width
	write_byte(0) // noise
	write_byte(127) // red
	write_byte(255) // green
	write_byte(45) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()

	while((Victim = find_ent_in_sphere(Victim, Origin, float(SELF_RADIUS))) != 0)
	{
		if(Victim == id)
			continue
		if(!is_alive(Victim))
			continue
		if(zevo_is_zombie(Victim))
			continue
			
		ShakeScreen(Victim)
		hook_ent3(Victim, Origin, DEATH_KNOCKPOWER, 1.0, 2)
	}		
}

public zevo_become_zombie(id, attacker, zombieclass)
{
	// Reset
	remove_task(id+TASK_HOWLING)
	
	if(zombieclass == g_zombieclass)
	{
		Set_BitVar(g_CanHowl, id)
		UnSet_BitVar(g_Howling, id)
		
		if(!g_SuiTime[id]) Set_BitVar(g_CanSui, id)
		g_HowlTime[id] = 0
	} else {
		UnSet_BitVar(g_CanHowl, id)
		UnSet_BitVar(g_Howling, id)
		UnSet_BitVar(g_CanSui, id)
	}
}

public zevo_zombieclass_deactivate(id, ClassID)
{
	if(ClassID == g_zombieclass)
	{
		// Reset
		remove_task(id+TASK_HOWLING)
		
		UnSet_BitVar(g_CanHowl, id)
		UnSet_BitVar(g_Howling, id)
	}
}

public zevo_runningtime2(id, Time)
{
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
		
	// Cooldown
	if(g_HowlTime[id] > 0) 
	{
		g_HowlTime[id]--
		if(!g_HowlTime[id]) 
		{
			Set_BitVar(g_CanHowl, id)
			UnSet_BitVar(g_Howling, id)
		}
	}
	if(g_SuiTime[id] > 0) 
	{
		g_SuiTime[id]--
		if(!g_SuiTime[id]) Set_BitVar(g_CanSui, id)
	}
	
	// Hud
	static Skill1[32], Skill2[32], Special[16], Special2[16]
	
	formatex(Special, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LEFTMOUSE")
	formatex(Special2, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LVREQ", 2)
	
	if(!g_HowlTime[id]) formatex(Skill1, 31, "[G] : %L", GAME_LANG, "ZOMBIE_VENOMGUARD_SKILL_HOWL")
	else formatex(Skill1, 31, "[G] : %L (%i)", GAME_LANG, "ZOMBIE_VENOMGUARD_SKILL_HOWL", g_HowlTime[id])
	
	if(zevo_get_playerlevel(id) >= 2)
	{
		if(!g_SuiTime[id]) formatex(Skill2, 31, "[F] : %L", GAME_LANG, "ZOMBIE_VENOMGUARD_SKILL_SELF")
		else formatex(Skill2, 31, "[F] : %L (%i)", GAME_LANG, "ZOMBIE_VENOMGUARD_SKILL_SELF", g_SuiTime[id])
	} else formatex(Skill2, 31, "[F] : %L (%s)", GAME_LANG, "ZOMBIE_VENOMGUARD_SKILL_SELF", Special2)
	
	set_hudmessage(255, 212, 42, -1.0, 0.10, 0, 2.0, 2.0)
	ShowSyncHudMsg(id, g_ZombieHud, "[%s]^n^n%s^n%s", zclass_name, Skill1, Skill2)
}

public zevo_zombieskill(id, ClassID, SkillButton)
{
	if(ClassID != g_zombieclass)
		return
		
	switch(SkillButton)
	{
		case SKILL_G: Skill_Howl(id)
		case SKILL_F: Skill_SelfExp(id)
	}
}

public Skill_Howl(id)
{
	if(!Get_BitVar(g_CanHowl, id))
		return
	if(Get_BitVar(g_Howling, id))
		return
		
	UnSet_BitVar(g_CanHowl, id)
	Set_BitVar(g_Howling, id)
	g_HowlTime[id] = HOWL_COOLDOWN
	
	EmitSound(id, CHAN_ITEM, HowlSound)
	EmitSound(id, CHAN_STATIC, HowlSound)
	
	static Origin[3]
	get_user_origin(id, Origin)
	
	message_begin(MSG_PVS, SVC_TEMPENTITY, Origin) 
	write_byte(TE_LAVASPLASH)
	write_coord(Origin[0]) 
	write_coord(Origin[1]) 
	write_coord(Origin[2]) 
	message_end()
	
	remove_task(id+TASK_HOWLING)
	set_task(0.1, "Howling_Handle", id+TASK_HOWLING, _, _, "b")
	set_task(float(HOWL_TIME), "Howling_Stop", id+TASK_HOWLING)
}

public Howling_Handle(id)
{
	id -= TASK_HOWLING
	
	if(!is_alive(id))
	{
		remove_task(id+TASK_HOWLING)
		return
	}
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
	{
		remove_task(id+TASK_HOWLING)
		return
	}
		
	static Victim; Victim = -1
	static Float:Origin[3]; pev(id, pev_origin, Origin)
	static Float:Velocity[3]
	
	// A ring effect
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_BEAMCYLINDER) // TE id
	engfunc(EngFunc_WriteCoord, Origin[0]) // x
	engfunc(EngFunc_WriteCoord, Origin[1]) // y
	engfunc(EngFunc_WriteCoord, Origin[2]) // z
	engfunc(EngFunc_WriteCoord, Origin[0]) // x axis
	engfunc(EngFunc_WriteCoord, Origin[1]) // y axis
	engfunc(EngFunc_WriteCoord, Origin[2] + float(HOWL_RADIUS)) // z axis
	write_short(g_Ring_SprID) // sprite
	write_byte(0) // startframe
	write_byte(0) // framerate
	write_byte(10) // life
	write_byte(25) // width
	write_byte(0) // noise
	write_byte(255) // red
	write_byte(45) // green
	write_byte(45) // blue
	write_byte(200) // brightness
	write_byte(0) // speed
	message_end()
	
	// Screen effects for him self
	ShakeScreen(id)

	while((Victim = find_ent_in_sphere(Victim, Origin, float(HOWL_RADIUS))) != 0)
	{
		if(Victim == id)
			continue
		if(!is_alive(Victim))
			continue
		if(zevo_is_zombie(Victim))
			continue
			
		// Shake
		ShakeScreen(Victim)
	
		// Slow
		get_user_velocity(Victim, Velocity)
		xs_vec_mul_scalar(Velocity, 0.75, Velocity)
		set_user_velocity(Victim, Velocity)
		
		// Screen ?
		static Float:Angles[3];
		Angles[0] = random_float(0.0, 15.0)
		Angles[1] = random_float(0.0, 15.0)
		Angles[2] = random_float(0.0, 15.0)
		
		set_pev(Victim, pev_punchangle, Angles)
	}
}

public ShakeScreen(id)
{
	static MSG
	if(!MSG) MSG = get_user_msgid("ScreenShake")
	
	// Screen Shake
	message_begin(MSG_ONE_UNRELIABLE, MSG, _, id)
	write_short((1<<12) * 5) // amplitude
	write_short((1<<12) * 1) // duration
	write_short((1<<12) * 5) // frequency
	message_end()
}

public Howling_Stop(id)
{
	id -= TASK_HOWLING
	
	if(!is_alive(id))
	{
		remove_task(id+TASK_HOWLING)
		return
	}
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
	{
		remove_task(id+TASK_HOWLING)
		return
	}
		
	remove_task(id+TASK_HOWLING)
}

public Skill_SelfExp(id)
{
	if(zevo_get_playerlevel(id) <= 1)
		return
	if(!Get_BitVar(g_CanSui, id))
		return
	if(Get_BitVar(g_Howling, id))
		return
		
	UnSet_BitVar(g_CanSui, id)
	g_SuiTime[id] = SELF_COOLDOWN
		
	user_kill(id, 0)
}

public EmitSound(id, chan, const file_sound[]) emit_sound(id, chan, file_sound, 1.0, ATTN_NORM, 0, PITCH_NORM)

public Load_Class_Setting()
{
	static Temp[128]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_SERVER, "ZOMBIE_VENOMGUARD_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_SERVER, "ZOMBIE_VENOMGUARD_DESC")
	
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "VENOMGUARD_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "VENOMGUARD_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "VENOMGUARD_KNOCKBACK", Temp, sizeof(Temp)); zclass_knockback = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "VENOMGUARD_DEFENSE", Temp, sizeof(Temp)); zclass_defense = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "VENOMGUARD_CLAWRANGE", Temp, sizeof(Temp)); zclass_clawrange = str_to_float(Temp)
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

stock hook_ent3(ent, Float:VicOrigin[3], Float:speed, Float:multi, type)
{
	static Float:fl_Velocity[3]
	static Float:EntOrigin[3]
	static Float:EntVelocity[3]
	
	VicOrigin[2] -= 36.0
	
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
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
