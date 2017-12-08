#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <xs>
#include <zombie_evolution>

#define PLUGIN "[ZEVO] Zombie Class: Heavy"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define ZOMBIE_NAME "Heavy Zombie"
#define GAME_FOLDER "zombie_evolution"
#define SETTING_FILE "ZEvo_ZombieClassConfig.ini"
#define LANG_FILE "zombie_evolution.txt"

#define GAME_LANG LANG_SERVER

// Skill
#define TRAP_COOLDOWN_SET 15
#define TRAP_COOLDOWN_THROW 30
#define TRAP_FLYSPEED 500.0
#define TRAP_STAYTIME 30.0
#define TRAP_HOLDTIME 10.0
#define TRAP_FOV 105
#define TRAP_DETECT_RAD 1024.0
#define TRAP_SPEED 50.0

/// Zombie Class
new GameName[] = "Zombie Evolution"

new zclass_name[32] = "Heavy Zombie"
new zclass_desc[32] = "Make Trap"
new Float:zclass_speed = 270.0
new Float:zclass_gravity = 1.15
new Float:zclass_knockback = 0.5
new Float:zclass_defense = 1.5
new Float:zclass_clawrange = 48.0

new const zclass_modelorigin[] = "ev_heavy_origin"
new const zclass_modelhost[] = "ev_heavy_host"
new const zclass_clawmodel_origin[] = "v_claw_heavy.mdl"
new const zclass_clawmodel_host[] = "v_claw_heavy.mdl"
new const zclass_deathsound[] = "zombie_evolution/zombie/heavy_death.wav"
new const zclass_painsound[] = "zombie_evolution/zombie/heavy_hurt.wav"
new const zclass_permcode = 3

new const TrapModel[] = "models/zombie_evolution/zombitrap.mdl"
new const Sound_SetTrap[] = "zombie_evolution/zombie/heavy_trapsetup.wav"
new const Sound_ThrowTrap[] = "zombie_evolution/zombie/heavy_trapthrow.wav"

new const TrapSound[] = "zombie_evolution/action/player_trap.wav"
new const TrapVoice[2][] = 
{
	"zombie_evolution/action/trapped_male.wav",
	"zombie_evolution/action/trapped_female.wav",
}
new const TrapSprite[] = "sprites/zombie_evolution/trap.spr"

// Const
#define TRAP_CLASSNAME "heavytrap"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_zombieclass, g_SpeedChange1, g_SpeedChange2
new g_MsgFov, g_ZombieHud, g_MsgScreenShake, g_MaxPlayers, g_Trap_SprID, Float:g_PlayerIcon[33], g_Trapped
new g_CanMakeTrap, g_MakeTrapCooldown[33], Float:MyGravity[33]

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	register_touch(TRAP_CLASSNAME, "player", "fw_TrapTouch")
	register_think(TRAP_CLASSNAME, "fw_TrapThink")
	
	g_MsgFov = get_user_msgid("SetFOV")
	g_MsgScreenShake = get_user_msgid("ScreenShake")
	
	g_MaxPlayers = get_maxplayers()
	g_ZombieHud = CreateHudSyncObj(3)
}

public plugin_precache()
{
	register_dictionary(LANG_FILE)
	formatex(GameName, sizeof(GameName), "%L", LANG_SERVER, "GAME_NAME")
	
	// Precache
	precache_model(TrapModel)
	precache_sound(Sound_SetTrap)
	precache_sound(Sound_ThrowTrap)
	
	precache_sound(TrapSound)
	precache_sound(TrapVoice[0])
	precache_sound(TrapVoice[1])
	
	g_Trap_SprID = precache_model(TrapSprite)
	
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

public zevo_round_new() remove_entity_name(TRAP_CLASSNAME)
public zevo_user_spawn(id, Zombie) 
{
	UnSet_BitVar(g_Trapped, id)
	UnSet_BitVar(g_CanMakeTrap, id)
}

public zevo_become_zombie(id, attacker, zombieclass)
{
	// Reset
	UnSet_BitVar(g_Trapped, id)
	
	if(zombieclass == g_zombieclass)
	{
		Set_BitVar(g_CanMakeTrap, id)
		g_MakeTrapCooldown[id] = 0
	} else {
		UnSet_BitVar(g_CanMakeTrap, id)
		g_MakeTrapCooldown[id] = 0
	}
}

public zevo_zombieclass_deactivate(id, ClassID)
{
	if(ClassID == g_zombieclass)
	{
		// Reset
		UnSet_BitVar(g_Trapped, id)
		
		UnSet_BitVar(g_CanMakeTrap, id)
		g_MakeTrapCooldown[id] = 0
	}
}

public zevo_runningtime2(id, Time)
{
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
		
	// Cooldown
	if(g_MakeTrapCooldown[id] > 0) 
	{
		g_MakeTrapCooldown[id]--
		if(!g_MakeTrapCooldown[id]) 
		{
			Set_BitVar(g_CanMakeTrap, id)
		}
	}
	
	// Hud
	static Skill1[32], Skill2[32], Special[16]
	formatex(Special, 15, "%L", GAME_LANG, "ZOMBIE_SKILL_LVREQ", 2)
	
	if(!g_MakeTrapCooldown[id]) 
	{
		formatex(Skill1, 31, "[G] : %L", GAME_LANG, "ZOMBIE_HEAVY_SKILL_SET")
		if(zevo_get_playerlevel(id) >= 2) formatex(Skill2, 31, "[F] : %L", GAME_LANG, "ZOMBIE_HEAVY_SKILL_THROW")
		else formatex(Skill2, 31, "[F] : %L (%s)", GAME_LANG, "ZOMBIE_HEAVY_SKILL_THROW", Special)
	} else {
		formatex(Skill1, 31, "[G] : %L (%i)", GAME_LANG, "ZOMBIE_HEAVY_SKILL_SET", g_MakeTrapCooldown[id])
		if(zevo_get_playerlevel(id) >= 2) formatex(Skill2, 31, "[F] : %L (%i)", GAME_LANG, "ZOMBIE_HEAVY_SKILL_THROW", g_MakeTrapCooldown[id])
		else formatex(Skill2, 31, "[F] : %L (%s)", GAME_LANG, "ZOMBIE_HEAVY_SKILL_THROW", Special)
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
		case SKILL_G: Skill_SetTrap(id)
		case SKILL_F: Skill_ThrowTrap(id)
	}
}

public client_PostThink(id)
{
	if(!is_alive(id))
		return
	if(Get_BitVar(g_Trapped, id) && zevo_get_playertype(id) == PLAYER_HUMAN)
	{
		if((g_PlayerIcon[id] + 0.05) < get_gametime())
		{
			for(new i = 0; i < g_MaxPlayers; i++)
			{
				if(!is_connected(i))
					continue
				if(!zevo_is_zombie(i))
					continue
					
				Show_OriginIcon(i, id, g_Trap_SprID)
			}
			
			g_PlayerIcon[id] = get_gametime()
		}
		return
	}
	if(!zevo_is_zombie(id) || zevo_get_zombieclass(id) != g_zombieclass)
		return
		
	static Ducking; Ducking = (pev(id, pev_flags) & FL_DUCKING)
	if(Ducking)
	{
		if(!Get_BitVar(g_SpeedChange1, id))
		{
			Set_BitVar(g_SpeedChange1, id)
			UnSet_BitVar(g_SpeedChange2, id)
			
			zevo_speed_set(id, zclass_speed * 1.5, 1)
		} 
	} else {
		if(!Get_BitVar(g_SpeedChange2, id))
		{
			Set_BitVar(g_SpeedChange2, id)
			UnSet_BitVar(g_SpeedChange1, id)
			
			zevo_speed_set(id, zclass_speed, 1)
		} 
	}
}

public Skill_SetTrap(id)
{
	if(!Get_BitVar(g_CanMakeTrap, id))
		return
		
	UnSet_BitVar(g_CanMakeTrap, id)
	g_MakeTrapCooldown[id] = TRAP_COOLDOWN_SET
	
	SetFov(id, TRAP_FOV); set_task(0.25, "Reset_Fov", id)
	static Trap; Trap = Create_Trap(id)
	if(pev_valid(Trap)) set_pev(Trap, pev_nextthink, get_gametime() + 0.1)
	
	// Effect
	EmitSound(id, CHAN_ITEM, Sound_SetTrap)
}

public Skill_ThrowTrap(id)
{
	if(zevo_get_playerlevel(id) <= 1)
		return
	if(!Get_BitVar(g_CanMakeTrap, id))
		return
		
	UnSet_BitVar(g_CanMakeTrap, id)
	g_MakeTrapCooldown[id] = TRAP_COOLDOWN_THROW
	
	SetFov(id, TRAP_FOV); set_task(0.25, "Reset_Fov", id)
	static Trap; Trap = Create_Trap(id)
	if(!pev_valid(Trap)) return
	
	static Float:Vel[3], Float:Origin[3], Float:Target[3]
	
	pev(id, pev_origin, Origin)
	get_position(id, 100.0, 0.0, 0.0, Target)
	Get_SpeedVector(Origin, Target, TRAP_FLYSPEED, Vel)
	
	set_pev(Trap, pev_velocity, Vel)
	set_pev(Trap, pev_nextthink, get_gametime() + 1.0)
	
	// Effect
	EmitSound(id, CHAN_ITEM, Sound_ThrowTrap)
}

public Reset_Fov(id)
{
	if(!is_connected(id))
		return
		
	SetFov(id)
}

public Create_Trap(id)
{
	static Trap; Trap = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Trap)) return -1
	
	set_pev(Trap, pev_classname, TRAP_CLASSNAME)
	set_pev(Trap, pev_solid, SOLID_TRIGGER)
	set_pev(Trap, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(Trap, pev_gravity, 1.0)
	
	set_pev(Trap, pev_animtime, get_gametime())
	set_pev(Trap, pev_framerate, 1.0)
	set_pev(Trap, pev_sequence, 0)
	
	set_pev(Trap, pev_owner, id)
	set_pev(Trap, pev_iuser1, 0)
	set_pev(Trap, pev_iuser2, 0)
	set_pev(Trap, pev_fuser1, get_gametime() + TRAP_STAYTIME)
	
	new Float:mins[3] = { -20.0, -20.0, 0.0 }
	new Float:maxs[3] = { 20.0, 20.0, 30.0 }
	engfunc(EngFunc_SetSize, Trap, mins, maxs)
	
	// Set trap model
	engfunc(EngFunc_SetModel, Trap, TrapModel)

	// Set trap position
	static Float:Origin[3]; pev(id, pev_origin, Origin)
	set_pev(Trap, pev_origin, Origin)
	
	// set invisible
	fm_set_rendering(Trap, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 100)
	
	return Trap
}

public fw_TrapTouch(Trap, id)
{
	if(!pev_valid(Trap) || !is_alive(id))
		return
	if(zevo_is_zombie(id))
		return
	if(pev(Trap, pev_iuser1))
		return
		
	set_pev(Trap, pev_iuser1, 1)
	set_pev(Trap, pev_iuser2, id)
	set_pev(Trap, pev_fuser2, get_gametime() + TRAP_HOLDTIME)
	
	fm_set_rendering(Trap)
	set_pev(id, pev_velocity, {0.0, 0.0, 0.0})
	
	static Float:Origin[3]; pev(id, pev_origin, Origin); Origin[2] -= 26.0
	
	set_pev(Trap, pev_velocity, {0.0, 0.0, 0.0})
	set_pev(Trap, pev_origin, Origin)
		
	// Trap
	Trap_User(id)
	
	// Trap Sound
	EmitSound(Trap, CHAN_BODY, TrapSound)
	
	// Animation
	set_pev(Trap, pev_animtime, get_gametime())
	set_pev(Trap, pev_framerate, 1.0)
	set_pev(Trap, pev_sequence, 1)
}

public fw_TrapThink(Ent)
{
	if(!pev_valid(Ent))
		return
		
	if(!pev(Ent, pev_iuser1))
	{
		static Float:Time; pev(Ent, pev_fuser1, Time)
		if(Time < get_gametime())
		{
			set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
			set_pev(Ent, pev_flags, FL_KILLME)
			
			return
		} 
		
		static Target; Target = FindClosetEnemy(Ent)
		if(is_alive(Target))
		{
			static Float:Origin[3]; pev(Target, pev_origin, Origin)
			hook_ent2(Ent, Origin, TRAP_SPEED)
		}
	} else {
		static Float:Time; pev(Ent, pev_fuser2, Time)
		if(Time < get_gametime())
		{
			static id; id = pev(Ent, pev_iuser2)
			if(is_alive(id) && !zevo_is_zombie(id)) Release_Player(id)
			
			set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
			set_pev(Ent, pev_flags, FL_KILLME)
			
			return
		} else {
			static id; id = pev(Ent, pev_iuser2)
			if(!is_alive(id) || (is_alive(id) && zevo_is_zombie(id)))
			{
				set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
				set_pev(Ent, pev_flags, FL_KILLME)
			
				return
			} else if(is_alive(id) && !zevo_is_zombie(id)) {
				if(pev(id, pev_maxspeed) != 0.01) 
				{
					zevo_speed_set(id, 0.01, 1)
					set_pev(id, pev_gravity, 10.0)
				}
			}
		}
	}
		
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public Trap_User(id)
{
	Set_BitVar(g_Trapped, id)
	
	// Voice
	if(zevo_get_playersex(id) == PLAYER_MALE) EmitSound(id, CHAN_ITEM, TrapVoice[0])
	else if(zevo_get_playersex(id) == PLAYER_FEMALE) EmitSound(id, CHAN_ITEM, TrapVoice[1])
	
	// Set Speed
	pev(id, pev_gravity, MyGravity[id])
	zevo_speed_set(id, 0.01, 1)
	set_pev(id, pev_gravity, 10.0)
	
	// ScreenShake
	message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenShake, {0,0,0}, id)
	write_short((1<<12) * 1)
	write_short(1<<12)
	write_short((1<<12) * 1)
	message_end()  
}

public Release_Player(id)
{
	UnSet_BitVar(g_Trapped, id)
	
	// Set Speed
	zevo_speed_reset(id)
	set_pev(id, pev_gravity, MyGravity[id])
}

public EmitSound(id, chan, const file_sound[]) emit_sound(id, chan, file_sound, 1.0, ATTN_NORM, 0, PITCH_NORM)

public Load_Class_Setting()
{
	static Temp[128]
	
	formatex(zclass_name, sizeof(zclass_name), "%L", LANG_SERVER, "ZOMBIE_HEAVY_NAME")
	formatex(zclass_desc, sizeof(zclass_desc), "%L", LANG_SERVER, "ZOMBIE_HEAVY_DESC")
	
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "HEAVY_SPEED", Temp, sizeof(Temp)); zclass_speed = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "HEAVY_GRAVITY", Temp, sizeof(Temp)); zclass_gravity = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "HEAVY_KNOCKBACK", Temp, sizeof(Temp)); zclass_knockback = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "HEAVY_DEFENSE", Temp, sizeof(Temp)); zclass_defense = str_to_float(Temp)
	Setting_Load_String(SETTING_FILE, ZOMBIE_NAME, "HEAVY_CLAWRANGE", Temp, sizeof(Temp)); zclass_clawrange = str_to_float(Temp)
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

public FindClosetEnemy(ent)
{
	static indexid; indexid = 0	
	static Float:current_dis; current_dis = 4980.0

	for(new i = 0; i <= g_MaxPlayers; i++)
	{
		if(is_alive(i) && entity_range(ent, i) < current_dis && !zevo_is_zombie(i))
		{
			current_dis = entity_range(ent, i)
			indexid = i
		}			
	}	
	
	return indexid
}

stock hook_ent2(ent, Float:VicOrigin[3], Float:speed)
{
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	
	pev(ent, pev_origin, EntOrigin)
	
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	fl_Time = distance_f / speed
		
	fl_Velocity[0] = (VicOrigin[0] - EntOrigin[0]) / fl_Time
	fl_Velocity[1] = (VicOrigin[1] - EntOrigin[1]) / fl_Time
	//fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time

	set_pev(ent, pev_velocity, fl_Velocity)
}

public Show_OriginIcon(id, Ent, SpriteID) // By sontung0
{
	static Float:fMyOrigin[3]; pev(id, pev_origin, fMyOrigin)
	
	static Target; Target = Ent
	static Float:fTargetOrigin[3]; pev(Target, pev_origin, fTargetOrigin)
	fTargetOrigin[2] += 40.0
	
	if(!is_in_viewcone(id, fTargetOrigin)) 
		return

	static Float:fMiddle[3], Float:fHitPoint[3]
	xs_vec_sub(fTargetOrigin, fMyOrigin, fMiddle)
	trace_line(-1, fMyOrigin, fTargetOrigin, fHitPoint)
							
	static Float:fWallOffset[3], Float:fDistanceToWall
	fDistanceToWall = vector_distance(fMyOrigin, fHitPoint) - 10.0
	normalize(fMiddle, fWallOffset, fDistanceToWall)
	
	static Float:fSpriteOffset[3]; xs_vec_add(fWallOffset, fMyOrigin, fSpriteOffset)
	static Float:fScale; fScale = 0.01 * fDistanceToWall
	
	static scale; scale = floatround(fScale)
	scale = max(scale, 1)
	scale = min(scale, 2) // SIZE = 2
	scale = max(scale, 1)

	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id)
	write_byte(TE_SPRITE)
	engfunc(EngFunc_WriteCoord, fSpriteOffset[0])
	engfunc(EngFunc_WriteCoord, fSpriteOffset[1])
	engfunc(EngFunc_WriteCoord, fSpriteOffset[2])
	write_short(SpriteID)
	write_byte(scale) 
	write_byte(250)
	message_end()
}

stock normalize(Float:fIn[3], Float:fOut[3], Float:fMul) // By sontung0
{
	static Float:fLen; fLen = xs_vec_len(fIn)
	xs_vec_copy(fIn, fOut)
	
	fOut[0] /= fLen, fOut[1] /= fLen, fOut[2] /= fLen
	fOut[0] *= fMul, fOut[1] *= fMul, fOut[2] *= fMul
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
