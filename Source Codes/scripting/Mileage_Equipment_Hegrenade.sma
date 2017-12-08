#include <amxmodx>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <zombie_evolution>

#define PLUGIN "[Mileage] Equipment: HE Grenade"
#define VERSION "1.0"
#define AUTHOR "Dias"

new g_HE, g_Had_HE[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	RegisterHam(Ham_TakeDamage, "player", "fw_PlayerTakeDamage")
	g_HE = Mileage_RegisterWeapon("hegrenade")
}

public Mileage_WeaponGet(id, ItemID)
{
	if(ItemID == g_HE) 
	{
		g_Had_HE[id] = 1
		give_item(id, "weapon_hegrenade")
	}
}

public Mileage_WeaponRefillAmmo(id, ItemID)
{
	if(ItemID == g_HE) 
	{
		g_Had_HE[id] = 1
		give_item(id, "weapon_hegrenade")
	}
}

public Mileage_WeaponRemove(id, ItemID)
{
	if(ItemID == g_HE) 
	{
		g_Had_HE[id] = 0
	}
}

public fw_PlayerTakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(is_user_alive(Attacker) && (DamageBits & (1<<24)) && g_Had_HE[Attacker])
		SetHamParamFloat(4, Damage * 5.0)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
