#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <zombie_evolution>

#define PLUGIN "[ZEVO] Addon: Human Ability"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define GAME_LANG LANG_SERVER
#define LANG_FILE "zombie_evolution.txt"

#define TASK_STUN 546464

new const SprintSprite[] = "sprites/zombie_evolution/head_speedup.spr"
new const DeadlyShotSprite[] = "sprites/zombie_evolution/deadlyshot.spr"
new const DeadlyShot2Sprite[] = "sprites/zombie_evolution/deadlyshot2.spr"
new const StunSprite[] = "sprites/zombie_evolution/head_stun.spr"
new const StunEffect[] = "sprites/zombie_evolution/stun_activate.spr"
new const ActivateSound[] = "zombie_evolution/action/activate.wav"
new const StunSound[] = "zombie_evolution/action/player_stun.wav"

new g_SprintPercent[33], g_Sprinting, g_CanDeadlyShot, g_DeadlyShoting, g_DeadlyShotTime[33], g_CanStun
new g_HumanHud, g_PlayerKey[33][2], Float:CheckTime[33], Float:CheckTime2[33], g_Stunning, Float:g_MySpeed[33]
new g_Cvar_SprintPercent, g_Cvar_DeadlyShotTime, g_Cvar_SprintSpeed, g_Cvar_StunRadius, g_Cvar_StunTime
new g_BuyZone, g_ShockWave_SprID, g_GameStart, g_Stun_EffectID

#define TIME_INTERVAL 0.15
#define TASK_CHECKTIME 3125365
#define TASK_AUTOSKILL 18710

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_dictionary(LANG_FILE)
	Register_SafetyFunc()
	
	register_impulse(201, "CMD_Spray")	
	g_HumanHud = CreateHudSyncObj(3)
	
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")

	// Cvars
	g_Cvar_SprintPercent = register_cvar("zevo_sprint_percent", "100")
	g_Cvar_SprintSpeed = register_cvar("zevo_sprint_speed", "350.0")
	g_Cvar_DeadlyShotTime = register_cvar("zevo_deadlyshot_time", "5")
	g_Cvar_StunRadius = register_cvar("zevo_stun_radius", "240.0")
	g_Cvar_StunTime = register_cvar("zevo_stun_time", "5.0")
}

public plugin_precache()
{
	precache_model(SprintSprite)
	precache_model(DeadlyShotSprite)
	precache_model(DeadlyShot2Sprite)
	precache_model(StunSprite)
	
	precache_sound(ActivateSound)
	precache_sound(StunSound)
	
	g_Stun_EffectID = precache_model(StunEffect)
	g_ShockWave_SprID = precache_model("sprites/shockwave.spr")
	
	// Buyzone
	g_BuyZone = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_buyzone"))
	dllfunc(DLLFunc_Spawn, g_BuyZone)
	engfunc(EngFunc_SetSize, g_BuyZone, {-8192.0, -8192.0, -8192.0}, {-8191.0, -8191.0, -8191.0})
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
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack")
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public fw_TraceAttack(victim, attacker, Float:damage, Float:direction[3], tracehandle, damage_type)
{
	if(!is_connected(attacker))
		return HAM_IGNORED
	if(Get_BitVar(g_DeadlyShoting, attacker))
		set_tr2(tracehandle, TR_iHitgroup, HIT_HEAD)

	return HAM_IGNORED
}

public zevo_round_new() g_GameStart = 0
public zevo_game_start() g_GameStart = 1

public zevo_user_spawn(id, Zombie)
{
	if(Zombie) return
	
	remove_task(id+TASK_STUN)
	remove_task(id+TASK_AUTOSKILL)
	
	// Sprint
	UnSet_BitVar(g_Sprinting, id)
	g_SprintPercent[id] = get_pcvar_num(g_Cvar_SprintPercent)
	
	// Deadly Shot
	Set_BitVar(g_CanDeadlyShot, id)
	UnSet_BitVar(g_DeadlyShoting, id)
	g_DeadlyShotTime[id] = get_pcvar_num(g_Cvar_DeadlyShotTime)
	
	// Stun
	Set_BitVar(g_CanStun, id)
	
	if(is_user_bot(id))
	{
		remove_task(id+TASK_AUTOSKILL)
		if(is_user_bot(id)) set_task(random_float(30.0, 60.0), "Bot_AutoSkill", id+TASK_AUTOSKILL)
	}
}

public Bot_AutoSkill(id)
{
	id -= TASK_AUTOSKILL
	
	if(!is_alive(id))
		return
	if(!is_user_bot(id))
	{
		remove_task(id+TASK_AUTOSKILL)
		return
	}
	if(zevo_is_zombie(id))
		return
		
	if(Get_BitVar(g_CanDeadlyShot, id)) CMD_Spray(id)
	else if(Get_BitVar(g_CanStun, id)) CMD_Buy(id)
	
	if(is_user_bot(id)) set_task(random_float(10.0, 20.0), "Bot_AutoSkill", id+TASK_AUTOSKILL)
}

public zevo_become_zombie(id)
{
	remove_task(id+TASK_STUN)
	remove_task(id+TASK_AUTOSKILL)
	
	UnSet_BitVar(g_Sprinting, id)
	UnSet_BitVar(g_CanDeadlyShot, id)
	UnSet_BitVar(g_DeadlyShoting, id)
	UnSet_BitVar(g_CanStun, id)
	UnSet_BitVar(g_Stunning, id)
	
	set_hudmessage(0, 255, 0, -1.0, 0.10, 0, 0.25, 0.25)
	ShowSyncHudMsg(id, g_HumanHud, "")
	
	// SetFov(id)
}

public zevo_runningtime2(id, Time)
{
	if(!is_alive(id))
		return
	if(zevo_is_zombie(id))
		return
	if(Get_BitVar(g_DeadlyShoting, id))
	{
		if(g_DeadlyShotTime[id] > 0) g_DeadlyShotTime[id]--
		else {
			g_DeadlyShotTime[id] = 0
			UnSet_BitVar(g_DeadlyShoting, id)
			
			if(!zevo_get_nightvision(id, 1, 1) && !Get_BitVar(g_Sprinting, id))
			{
				// Effect
				static g_MsgScreenFade;
				if(!g_MsgScreenFade) g_MsgScreenFade = get_user_msgid("ScreenFade")
				
				// Reset
				message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
				write_short(0) // duration
				write_short(0) // hold time
				write_short(0x0000) // fade type
				write_byte(0) // r
				write_byte(0) // g
				write_byte(0) // b
				write_byte(0) // alpha
				message_end()
			}
		}
	}
		
	Load_Hud(id, 2.0)
}

public Load_Hud(id, Float:Time)
{
	// Hud
	static Skill1[64], Skill2[64], Skill3[64]
	
	// Skill 1
	if(g_SprintPercent[id] >= 100) formatex(Skill1, 63, "  [W] + [W] : %L (%i%%)", GAME_LANG, "HUMAN_SKILL_SPRINT", g_SprintPercent[id])
	else formatex(Skill1, 63, "[W] + [W] : %L (%i%%)", GAME_LANG, "HUMAN_SKILL_SPRINT", g_SprintPercent[id])
	
	// Skill 2
	if(Get_BitVar(g_DeadlyShoting, id)) formatex(Skill2, 63, "           [T] : %L (%i)", GAME_LANG, "HUMAN_SKILL_DEADLYSHOT", g_DeadlyShotTime[id])
	else {
		if(Get_BitVar(g_CanDeadlyShot, id)) formatex(Skill2, 63, "      [T] : %L", GAME_LANG, "HUMAN_SKILL_DEADLYSHOT")
		else formatex(Skill2, 63, "           [T] : %L (X)", GAME_LANG, "HUMAN_SKILL_DEADLYSHOT")
	}
	
	// Skill 3
	if(Get_BitVar(g_CanStun, id)) formatex(Skill3, 63, "               [B] : %L", GAME_LANG, "HUMAN_SKILL_STUN")
	else formatex(Skill3, 63, "                    [B] : %L (X)", GAME_LANG, "HUMAN_SKILL_STUN")
	
	set_hudmessage(0, 255, 0, -1.0, 0.10, 0, Time, Time)
	ShowSyncHudMsg(id, g_HumanHud, "[Human Ability]^n^n%s^n%s^n%s", Skill1, Skill2, Skill3)
}

public client_PreThink(id)
{
	if(!is_alive(id))
		return
	if(zevo_is_zombie(id))
		return
		
	static CurButton; CurButton = pev(id, pev_button)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
	
	if((CurButton & IN_FORWARD)) 
	{
		if(Get_BitVar(g_Sprinting, id) && (get_gametime() - 0.1 > CheckTime[id]))
		{
			if(g_SprintPercent[id] <= 0)
			{
				Deactivate_Sprint(id)
				return
			}
		
			g_SprintPercent[id]--
			Load_Hud(id, 0.2)
			
			CheckTime[id] = get_gametime()
		}	
		
		if(Get_BitVar(g_Sprinting, id) && (get_gametime() - 1.0 > CheckTime2[id]))
		{
			if(g_SprintPercent[id] <= 0)
				return
				
			zevo_playerattachment(id, SprintSprite, 1.25, 0.25, 0.0)
			CheckTime2[id] = get_gametime()
		}
		
		if(OldButton & IN_FORWARD)
			return
		
		if(!task_exists(id+TASK_CHECKTIME))
		{
			g_PlayerKey[id][0] = 'w'
			
			remove_task(id+TASK_CHECKTIME)
			set_task(TIME_INTERVAL, "Recheck_Key", id+TASK_CHECKTIME)
		} else {
			g_PlayerKey[id][1] = 'w'
		}
	} else {
		if(OldButton & IN_FORWARD)
		{
			Deactivate_Sprint(id)
		}
		
		return
	}
	
	if(equali(g_PlayerKey[id], "ww"))
	{
		Reset_Key(id)
		Activate_Sprint(id)
	}
	
	return
}

public client_PostThink(id)
{
	if(!is_alive(id))
		return
	if(zevo_is_zombie(id))
	{
		if(Get_BitVar(g_Stunning, id) && pev(id, pev_maxspeed) != 0.01)
			zevo_speed_set(id, 0.01, 1)
			
		return
	}
		
	dllfunc(DLLFunc_Touch, g_BuyZone, id)
}

public Recheck_Key(id)
{
	id -= TASK_CHECKTIME
	
	if(!is_user_connected(id))
		return
		
	Reset_Key(id)
}

public Reset_Key(id)
{
	g_PlayerKey[id][0] = 0
	g_PlayerKey[id][1] = 0
}

public Activate_Sprint(id)
{
	if(g_SprintPercent[id] <= 0)
		return
	if(!g_GameStart)
	{
		client_print(id, print_center, "%L", GAME_LANG, "NOTICE_GAMENOTSTART")
		return
	}
	
	Set_BitVar(g_Sprinting, id)
	
	if(!zevo_get_nightvision(id, 1, 1))
	{
		// Effect
		static g_MsgScreenFade;
		if(!g_MsgScreenFade) g_MsgScreenFade = get_user_msgid("ScreenFade")
		
		message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
		write_short(0) // duration
		write_short(0) // hold time
		write_short(0x0004) // fade type
		write_byte(255) // r
		write_byte(255) // g
		write_byte(255) // b
		write_byte(40) // alpha
		message_end()
	}
	
	SetFov(id, 105)
	
	// Set
	zevo_speed_set(id, get_pcvar_float(g_Cvar_SprintSpeed), 1)
	PlaySound(id, ActivateSound)
}

public Deactivate_Sprint(id)
{
	UnSet_BitVar(g_Sprinting, id)
	
	if(!zevo_get_nightvision(id, 1, 1) && !Get_BitVar(g_Sprinting, id))
	{
		// Effect
		static g_MsgScreenFade;
		if(!g_MsgScreenFade) g_MsgScreenFade = get_user_msgid("ScreenFade")
		
		// Reset
		message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
		write_short(0) // duration
		write_short(0) // hold time
		write_short(0x0000) // fade type
		write_byte(0) // r
		write_byte(0) // g
		write_byte(0) // b
		write_byte(0) // alpha
		message_end()
	}
	
	SetFov(id)
	
	zevo_speed_reset(id)
	Load_Hud(id, 1.0)
}

public CMD_Spray(id)
{
	if(!is_alive(id))
		return
	if(zevo_is_zombie(id))
		return
	if(!g_GameStart)
	{
		client_print(id, print_center, "%L", GAME_LANG, "NOTICE_GAMENOTSTART")
		return
	}
	if(!Get_BitVar(g_CanDeadlyShot, id))
		return
		
	UnSet_BitVar(g_CanDeadlyShot, id)
	Set_BitVar(g_DeadlyShoting, id)
	
	// Effect
	zevo_playerattachment(id, DeadlyShotSprite, float(g_DeadlyShotTime[id]), 0.25, 0.0)
	zevo_playerattachment(id, DeadlyShot2Sprite, float(g_DeadlyShotTime[id]), 0.75, 15.0)
	
	if(!zevo_get_nightvision(id, 1, 1))
	{
		// Effect
		static g_MsgScreenFade;
		if(!g_MsgScreenFade) g_MsgScreenFade = get_user_msgid("ScreenFade")
		
		message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
		write_short(0) // duration
		write_short(0) // hold time
		write_short(0x0004) // fade type
		write_byte(255) // r
		write_byte(255) // g
		write_byte(255) // b
		write_byte(40) // alpha
		message_end()
	}
	
	// Sound
	emit_sound(id, CHAN_ITEM, ActivateSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

public client_command(id)
{
	if(!is_alive(id))
		return PLUGIN_CONTINUE

	static cmd_list[][] = { "buyequip", "autobuy", "cl_autobuy", "cl_rebuy" }
	static command[16], i; read_argv(0, command, 15)
	
	for(i = 0; i < sizeof cmd_list; i++) if(equal(command, cmd_list[i]))
	return PLUGIN_HANDLED
	
	if(equal(command, "client_buy_open") || equal(command, "buy"))
	{
		static msg_buyclose; if(!msg_buyclose) msg_buyclose = get_user_msgid("BuyClose")
		message_begin(MSG_ONE_UNRELIABLE, msg_buyclose, _, id), message_end()
		
		CMD_Buy(id)
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public CMD_Buy(id)
{
	if(!is_alive(id))
		return
	if(zevo_is_zombie(id))
		return
	if(!g_GameStart)
	{
		client_print(id, print_center, "%L", GAME_LANG, "NOTICE_GAMENOTSTART")
		return
	}
	if(!Get_BitVar(g_CanStun, id))
		return
		
	UnSet_BitVar(g_CanStun, id)

	// Effect
	if(!zevo_get_nightvision(id, 1, 1))
	{
		// Effect
		static g_MsgScreenFade;
		if(!g_MsgScreenFade) g_MsgScreenFade = get_user_msgid("ScreenFade")
		
		message_begin(MSG_ONE_UNRELIABLE, g_MsgScreenFade, _, id)
		write_short(FixedUnsigned16(0.5, 1<<12)) // duration
		write_short(FixedUnsigned16(0.5, 1<<12)) // hold time
		write_short(0x0000) // fade type
		write_byte(255) // r
		write_byte(255) // g
		write_byte(255) // b
		write_byte(40) // alpha
		message_end()
	}
	
	static Float:Origin[3]; pev(id, pev_origin, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_Stun_EffectID)
	write_byte(20)
	write_byte(30)
	write_byte(14)
	message_end()
		
	engfunc(EngFunc_MessageBegin, MSG_BROADCAST, SVC_TEMPENTITY, Origin)
	write_byte(TE_BEAMCYLINDER)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + get_pcvar_num(g_Cvar_StunRadius))
	write_short(g_ShockWave_SprID)
	write_byte(0) // Start Frame
	write_byte(20) // Framerate
	write_byte(4) // Live Time
	write_byte(25) // Width
	write_byte(10) // Noise
	write_byte(0) // R
	write_byte(255) // G
	write_byte(255) // B
	write_byte(255) // Bright
	write_byte(9) // Speed
	message_end()	
	
	engfunc(EngFunc_MessageBegin, MSG_BROADCAST, SVC_TEMPENTITY, Origin)
	write_byte(TE_BEAMCYLINDER)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + get_pcvar_num(g_Cvar_StunRadius))
	write_short(g_ShockWave_SprID)
	write_byte(0) // Start Frame
	write_byte(10) // Framerate
	write_byte(4) // Live Time
	write_byte(20) // Width
	write_byte(20) // Noise
	write_byte(0) // R
	write_byte(255) // G
	write_byte(0) // B
	write_byte(150) // Bright
	write_byte(9) // Speed
	message_end()		
	
	// Find
	static Victim; Victim = -1
	while((Victim = find_ent_in_sphere(Victim, Origin, get_pcvar_float(g_Cvar_StunRadius))) != 0)
	{
		if(Victim == id)
			continue
		if(!is_alive(Victim))
			continue
		if(!zevo_is_zombie(Victim))
			continue
			
		pev(Victim, pev_maxspeed, g_MySpeed[Victim])
		
		Set_BitVar(g_Stunning, Victim)
		zevo_speed_set(Victim, 0.01, 1)
			
		emit_sound(Victim, CHAN_ITEM, StunSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		zevo_playerattachment(Victim, StunSprite, get_pcvar_float(g_Cvar_StunTime), 1.0, 10.0)
			
		remove_task(Victim+TASK_STUN)
		set_task(get_pcvar_float(g_Cvar_StunTime), "Remove_Stun", Victim+TASK_STUN)
	}
	
	// Sound
	emit_sound(id, CHAN_ITEM, ActivateSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

public Remove_Stun(id)
{
	id -= TASK_STUN
	
	if(!is_alive(id))
		return
	if(!zevo_is_zombie(id))
		return
	if(!Get_BitVar(g_Stunning, id))
		return

	UnSet_BitVar(g_Stunning, id)
	
	set_pev(id, pev_maxspeed, g_MySpeed[id])
	remove_task(id+TASK_STUN)
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

stock SetFov(id, num = 90)
{
	static g_MsgFov; 
	if(!g_MsgFov) g_MsgFov = get_user_msgid("SetFOV")
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgFov, {0,0,0}, id)
	write_byte(num)
	message_end()
}

stock FixedUnsigned16(Float:flValue, iScale)
{
	new iOutput;

	iOutput = floatround(flValue * iScale);

	if ( iOutput < 0 )
		iOutput = 0;

	if ( iOutput > 0xFFFF )
		iOutput = 0xFFFF;

	return iOutput;
}
