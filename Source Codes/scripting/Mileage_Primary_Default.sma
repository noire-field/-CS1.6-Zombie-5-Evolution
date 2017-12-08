#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>
#include <zombie_evolution>

#define PLUGIN "[Mileage] Primary: Default"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

new g_AK47, g_M4A1, g_AUG, g_M3, g_XM1014, g_AWP

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	g_AK47 = Mileage_RegisterWeapon("ak47")
	g_M4A1 = Mileage_RegisterWeapon("m4a1")
	g_AUG = Mileage_RegisterWeapon("aug")
	g_M3 = Mileage_RegisterWeapon("m3")
	g_XM1014 = Mileage_RegisterWeapon("xm1014")
	g_AWP = Mileage_RegisterWeapon("awp")
}

public Mileage_WeaponGet(id, ItemID)
{
	if(ItemID == g_AK47) {
		give_item(id, "weapon_ak47")
		cs_set_user_bpammo(id, CSW_AK47, 210)
	} else if(ItemID == g_M4A1) {
		give_item(id, "weapon_m4a1")
		cs_set_user_bpammo(id, CSW_M4A1, 210)	
	} else if(ItemID == g_AUG) {
		give_item(id, "weapon_aug")
		cs_set_user_bpammo(id, CSW_AUG, 210)
	} else if(ItemID == g_M3) {
		give_item(id, "weapon_m3")
		cs_set_user_bpammo(id, CSW_M3, 120)
	} else if(ItemID == g_XM1014) {
		give_item(id, "weapon_xm1014")
		cs_set_user_bpammo(id, CSW_XM1014, 120)
	} else if(ItemID == g_AWP) {
		give_item(id, "weapon_awp")
		cs_set_user_bpammo(id, CSW_AWP, 100)
	} 
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
