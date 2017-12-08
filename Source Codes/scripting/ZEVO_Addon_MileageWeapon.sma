#include <amxmodx>
#include <amxmisc>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <zombie_evolution>
#include <fun>

#define PLUGIN "[ZEVO] Addon: Mileage Weapon"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define SETTING_FILE "Mileage_Weapon.ini"
#define LANG_FILE "zombie_evolution.txt"
#define VIP_FLAG ADMIN_LEVEL_H

#define GAME_LANG LANG_SERVER

#define MAX_WEAPON 46
#define MAX_TYPE 4
#define MAX_FORWARD 3

enum
{
	WPN_BOUGHT = 0,
	WPN_REMOVE,
	WPN_ADDAMMO
}

enum
{
	WPN_PRIMARY = 1,
	WPN_SECONDARY,
	WPN_MELEE,
	WPN_GRENADE
}

new SystemName[42] = "Mileage Weapon"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

// Const
const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)
const NADE_WEAPONS_BIT_SUM = ((1<<CSW_HEGRENADE)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_FLASHBANG))

new g_Forwards[MAX_FORWARD], g_GotWeapon, g_CanUseWeapon
new g_WeaponList[5][MAX_WEAPON], g_WeaponListCount[5]
new g_WeaponCount[5], g_PreWeapon[33][5], g_FirstWeapon[5], g_TotalWeaponCount, g_UnlockedWeapon[33][MAX_WEAPON]
new Array:ArWeaponName, Array:ArWeaponSysName, Array:ArWeaponType, Array:ArWeaponCost, Array:ArWeaponLevel, 
Array:ArWeaponMinPlayer, Array:ArWeaponVipOnly, Array:ArWeaponSupplyBox, Array:ArWeaponID
new Array:RegWeaponSysName, g_RegWeaponCount
new g_MaxPlayers, g_fwResult, g_MsgSayText
new g_PlayerLevel[33], g_ServerPlayer;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_dictionary(LANG_FILE)
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")
	
	g_Forwards[WPN_BOUGHT] = CreateMultiForward("Mileage_WeaponGet", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forwards[WPN_REMOVE] = CreateMultiForward("Mileage_WeaponRemove", ET_IGNORE, FP_CELL, FP_CELL)
	g_Forwards[WPN_ADDAMMO] = CreateMultiForward("Mileage_WeaponRefillAmmo", ET_IGNORE, FP_CELL, FP_CELL)
	
	g_MsgSayText = get_user_msgid("SayText")
	g_MaxPlayers = get_maxplayers()
	
	formatex(SystemName, 39, "%L", GAME_LANG, "MILEAGE_WEAPON")
}

public plugin_precache()
{
	ArWeaponName = ArrayCreate(64, 1)
	ArWeaponSysName = ArrayCreate(64, 1)
	ArWeaponType = ArrayCreate(1, 1)
	ArWeaponCost = ArrayCreate(1, 1)
	ArWeaponLevel = ArrayCreate(1, 1)
	ArWeaponMinPlayer = ArrayCreate(1, 1)
	ArWeaponVipOnly = ArrayCreate(1, 1)
	ArWeaponSupplyBox = ArrayCreate(1, 1)
	ArWeaponID = ArrayCreate(1, 1)
	
	RegWeaponSysName = ArrayCreate(64, 1)
	
	// Initialize
	g_FirstWeapon[WPN_PRIMARY] = -1
	g_FirstWeapon[WPN_SECONDARY] = -1
	g_FirstWeapon[WPN_MELEE] = -1
	g_FirstWeapon[WPN_GRENADE] = -1
	
	// Read Data
	Mileage_ReadWeapon()
}

public plugin_cfg()
{
	// Initialize 2
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		g_PreWeapon[i][WPN_PRIMARY] = g_FirstWeapon[WPN_PRIMARY]
		g_PreWeapon[i][WPN_SECONDARY] = g_FirstWeapon[WPN_SECONDARY]
		g_PreWeapon[i][WPN_MELEE] = g_FirstWeapon[WPN_MELEE]
		g_PreWeapon[i][WPN_GRENADE] = g_FirstWeapon[WPN_GRENADE]
	}
	
	// Handle WeaponList
	g_WeaponListCount[WPN_PRIMARY] = 0
	g_WeaponListCount[WPN_SECONDARY] = 0
	g_WeaponListCount[WPN_MELEE] = 0
	g_WeaponListCount[WPN_GRENADE] = 0
	
	static Type
	for(new i = 0; i < g_TotalWeaponCount; i++)
	{
		Type = ArrayGetCell(ArWeaponType, i)
		
		if(Type == WPN_PRIMARY)
		{
			g_WeaponList[WPN_PRIMARY][g_WeaponListCount[WPN_PRIMARY]] = i
			g_WeaponListCount[WPN_PRIMARY]++
		} else if(Type == WPN_SECONDARY) {
			g_WeaponList[WPN_SECONDARY][g_WeaponListCount[WPN_SECONDARY]] = i
			g_WeaponListCount[WPN_SECONDARY]++
		} else if(Type == WPN_MELEE) {
			g_WeaponList[WPN_MELEE][g_WeaponListCount[WPN_MELEE]] = i
			g_WeaponListCount[WPN_MELEE]++
		} else if(Type == WPN_GRENADE) {
			g_WeaponList[WPN_GRENADE][g_WeaponListCount[WPN_GRENADE]] = i
			g_WeaponListCount[WPN_GRENADE]++
		}
	}
	
	Event_NewRound()
}

public plugin_natives()
{
	register_native("Mileage_RegisterWeapon", "Native_RegisterWeapon", 1)
	register_native("Mileage_OpenWeapon", "Native_OpenWeapon", 1)
	register_native("Mileage_GiveRandomWeapon", "Native_GiveRandomWeapon", 1)
	
	register_native("Mileage_RemoveWeapon", "Native_RemoveWeapon", 1)
	register_native("Mileage_ResetWeapon", "Native_ResetWeapon", 1)
	register_native("Mileage_Weapon_RefillAmmo", "Native_RefillAmmo", 1)
	
	register_native("Mileage_WeaponAllow_Set", "Native_SetUseWeapon", 1)
	register_native("Mileage_WeaponAllow_Get", "Native_GetUseWeapon", 1)
	
	register_native("Mileage_PlayerLevel_Set", "Native_SetLevel", 1)
	register_native("Mileage_PlayerLevel_Get", "Native_GetLevel", 1)
}
	
public Native_RegisterWeapon(const SystemName[])
{
	param_convert(1)
	ArrayPushString(RegWeaponSysName, SystemName)
	
	// Match with setting file
	static SysName[64]
	for(new i = 0; i < g_TotalWeaponCount; i++)
	{
		ArrayGetString(ArWeaponSysName, i, SysName, 63)
		if(equal(SysName, SystemName))
		{
			ArraySetCell(ArWeaponID, i, g_RegWeaponCount)
			break
		}
	}
	
	g_RegWeaponCount++
	return g_RegWeaponCount - 1
}

public Native_GiveRandomWeapon(id)
{
	new ListPri[64], ListSec[64], g_Count[2]
	
	for(new i = 0; i < g_WeaponListCount[WPN_PRIMARY]; i++)
	{
		if(ArrayGetCell(ArWeaponSupplyBox, i)) 
		{
			ListPri[g_Count[0]] = i 
			g_Count[0]++
		}
	}
	
	for(new i = 0; i < g_WeaponListCount[WPN_SECONDARY]; i++)
	{
		if(ArrayGetCell(ArWeaponSupplyBox, i)) 
		{
			ListPri[g_Count[1]] = i 
			g_Count[1]++
		}
	}	
	
	new Pri, Sec
	
	Pri = ListPri[random(g_Count[0])]
	Sec = ListSec[random(g_Count[1])]
	
	switch(random_num(0, 100))
	{
		case 0..70:
		{
			drop_weapons(id, 1)
			ExecuteForward(g_Forwards[WPN_BOUGHT], g_fwResult, id, ArrayGetCell(ArWeaponID, Pri))
		}
		case 71..100:
		{
			drop_weapons(id, 2)
			ExecuteForward(g_Forwards[WPN_BOUGHT], g_fwResult, id, ArrayGetCell(ArWeaponID, Sec))
		}
	}
}

public Native_OpenWeapon(id) 
{
	if(!(0 <= id <= 32))
		return
		
	Show_MainEquipMenu(id)
}

public Native_RemoveWeapon(id)
{
	if(!(0 <= id <= 32))
		return
		
	Remove_PlayerWeapon(id)
}

public Native_ResetWeapon(id, NewPlayer)
{
	if(!(0 <= id <= 32))
		return
		
	Reset_PlayerWeapon(id, NewPlayer)
}

public Native_RefillAmmo(id)
{
	if(!(0 <= id <= 32))
		return
		
	Refill_PlayerWeapon(id)
}

public Native_SetUseWeapon(id, Allow)
{
	if(!(0 <= id <= 32))
		return
		
	if(Allow) Set_BitVar(g_CanUseWeapon, id)
	else UnSet_BitVar(g_CanUseWeapon, id)
}

public Native_GetUseWeapon(id)
{
	if(!(0 <= id <= 32))
		return 0
		
	return Get_BitVar(g_CanUseWeapon, id)
}

public Native_SetLevel(id, Level)
{
	if(!(0 <= id <= 32))
		return
		
	g_PlayerLevel[id] = Level
}

public Native_GetLevel(id)
{
	if(!(0 <= id <= 32))
		return 0 
		
	return g_PlayerLevel[id]
}

public client_putinserver(id)
{
	g_ServerPlayer++
	Reset_PlayerWeapon(id, 1)
}

public client_disconnect(id)
{
	g_ServerPlayer--
	Reset_PlayerWeapon(id, 1)
}

// Zombie 5: Evolution - Sync
public zevo_user_spawn(id, Zombie)
{
	if(Zombie) return

	// Reset
	Native_ResetWeapon(id, 0)
	Native_RemoveWeapon(id)
	Native_SetUseWeapon(id, 1)
	
	// Open
	Player_Equipment(id)
}

public zevo_user_death(id, Attacker, Headshot)
{
	if(zevo_is_zombie(id))
		return 
		
	Native_SetUseWeapon(id, 0)
}

public zevo_become_infected(id, Attacker, ClassID)
{
	Native_SetUseWeapon(id, 0)
}

public zevo_become_zombie(id, Attacker)
{
	if(is_user_connected(Attacker)) Native_RemoveWeapon(id)
	else if(zevo_is_firstzombie(id)) Native_RemoveWeapon(id)
}

public zevo_equipment_menu(id) Show_MainEquipMenu(id)
public zevo_supplybox_pickup(id, Special)
{
	if(Special == HUMAN_HERO) return
	
	if(!is_user_bot(id))
	{
		Refill_PlayerWeapon(id)
		
		// Ask
		static LangText[64]; formatex(LangText, 63, "%L", GAME_LANG, "MILEAGE_ASK")
		static Menu; Menu = menu_create(LangText, "MenuHandle_MileageAsk")
		
		// Yes
		formatex(LangText, 63, "%L", GAME_LANG, "MILEAGE_YES")
		menu_additem(Menu, LangText, "yes")
		
		// No
		formatex(LangText, 63, "%L", GAME_LANG, "MILEAGE_NO")
		menu_additem(Menu, LangText, "no")
		
		// Dis
		menu_display(id, Menu)
	} else {
		// Reset
		Native_ResetWeapon(id, 0)
		Native_RemoveWeapon(id)
		Native_SetUseWeapon(id, 1)
		
		// Strip
		strip_user_weapons(id)
		give_item(id, "weapon_knife")
		
		// Open
		Player_Equipment(id)
	}
}

public MenuHandle_MileageAsk(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	if(!is_user_alive(id))
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	if(zevo_is_zombie(id))
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}

	new Name[64], Data[16], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)

	if(equal(Data, "yes"))
	{
		// Reset
		Native_ResetWeapon(id, 0)
		Native_RemoveWeapon(id)
		Native_SetUseWeapon(id, 1)
		
		// Strip
		strip_user_weapons(id)
		give_item(id, "weapon_knife")
		
		// Open
		Player_Equipment(id)
	} 
	
	menu_destroy(Menu)
	return PLUGIN_HANDLED
}

// End of Zombie Evolution - Sync

public Event_NewRound() g_ServerPlayer = Get_TotalInPlayer(2) // Update Player Numbers every new round
public Remove_PlayerWeapon(id)
{
	ExecuteForward(g_Forwards[WPN_REMOVE], g_fwResult, id, ArrayGetCell(ArWeaponID, g_PreWeapon[id][WPN_PRIMARY]))
	ExecuteForward(g_Forwards[WPN_REMOVE], g_fwResult, id, ArrayGetCell(ArWeaponID, g_PreWeapon[id][WPN_SECONDARY]))
	ExecuteForward(g_Forwards[WPN_REMOVE], g_fwResult, id, ArrayGetCell(ArWeaponID, g_PreWeapon[id][WPN_MELEE]))
	ExecuteForward(g_Forwards[WPN_REMOVE], g_fwResult, id, ArrayGetCell(ArWeaponID, g_PreWeapon[id][WPN_GRENADE]))
}

public Refill_PlayerWeapon(id)
{
	ExecuteForward(g_Forwards[WPN_ADDAMMO], g_fwResult, id, ArrayGetCell(ArWeaponID, g_PreWeapon[id][WPN_PRIMARY]))
	ExecuteForward(g_Forwards[WPN_ADDAMMO], g_fwResult, id, ArrayGetCell(ArWeaponID, g_PreWeapon[id][WPN_SECONDARY]))
	ExecuteForward(g_Forwards[WPN_ADDAMMO], g_fwResult, id, ArrayGetCell(ArWeaponID, g_PreWeapon[id][WPN_MELEE]))
	ExecuteForward(g_Forwards[WPN_ADDAMMO], g_fwResult, id, ArrayGetCell(ArWeaponID, g_PreWeapon[id][WPN_GRENADE]))
}

public Reset_PlayerWeapon(id, NewPlayer)
{
	if(NewPlayer)
	{
		g_PreWeapon[id][WPN_PRIMARY] = g_FirstWeapon[WPN_PRIMARY]
		g_PreWeapon[id][WPN_SECONDARY] = g_FirstWeapon[WPN_SECONDARY]
		g_PreWeapon[id][WPN_MELEE] = g_FirstWeapon[WPN_MELEE]
		g_PreWeapon[id][WPN_GRENADE] = g_FirstWeapon[WPN_GRENADE]
		
		for(new i = 0; i < MAX_WEAPON; i++)
			g_UnlockedWeapon[id][i] = 0
			
		g_PlayerLevel[id] = 0
		UnSet_BitVar(g_CanUseWeapon, id)
	}
	
	UnSet_BitVar(g_GotWeapon, id)
}

public Player_Equipment(id)
{
	if(!is_user_bot(id)) Show_MainEquipMenu(id)
	else set_task(random_float(0.25, 1.0), "Bot_RandomWeapon", id)
}

public Show_MainEquipMenu(id)
{
	if(!Can_Use_Weapon(id))
		return
	if(Get_BitVar(g_GotWeapon, id))
		return
	
	static LangText[64];
	static Menu; Menu = menu_create(SystemName, "MenuHandle_MainEquip")
	static WeaponName[32]
	
	if(g_PreWeapon[id][WPN_PRIMARY] != -1)
	{
		ArrayGetString(ArWeaponName, g_PreWeapon[id][WPN_PRIMARY], WeaponName, sizeof(WeaponName))
		formatex(LangText, sizeof(LangText), "%L [\y%s\w]", GAME_LANG, "MILEAGE_PRIMARY", WeaponName)
	} else {
		formatex(LangText, sizeof(LangText), "%L \d[ ]\w", GAME_LANG, "MILEAGE_PRIMARY")
	}
	menu_additem(Menu, LangText, "wpn_pri")
	
	if(g_PreWeapon[id][WPN_SECONDARY] != -1)
	{
		ArrayGetString(ArWeaponName, g_PreWeapon[id][WPN_SECONDARY], WeaponName, sizeof(WeaponName))
		formatex(LangText, sizeof(LangText), "%L [\y%s\w]", GAME_LANG, "MILEAGE_SECONDARY", WeaponName)
	} else {
		formatex(LangText, sizeof(LangText), "%L \d[ ]\w", GAME_LANG, "MILEAGE_SECONDARY")
	}
	menu_additem(Menu, LangText, "wpn_sec")
	
	if(g_PreWeapon[id][WPN_MELEE] != -1)
	{
		ArrayGetString(ArWeaponName, g_PreWeapon[id][WPN_MELEE], WeaponName, sizeof(WeaponName))
		formatex(LangText, sizeof(LangText), "%L [\y%s\w]", GAME_LANG, "MILEAGE_MELEE", WeaponName)
	} else {
		formatex(LangText, sizeof(LangText), "%L \d[ ]\w", GAME_LANG, "MILEAGE_MELEE")
	}
	menu_additem(Menu, LangText, "wpn_melee")
	
	if(g_PreWeapon[id][WPN_GRENADE] != -1)
	{
		ArrayGetString(ArWeaponName, g_PreWeapon[id][WPN_GRENADE], WeaponName, sizeof(WeaponName))
		formatex(LangText, sizeof(LangText), "%L [\y%s\w]^n", GAME_LANG, "MILEAGE_GRENADE", WeaponName)
	} else {
		formatex(LangText, sizeof(LangText), "%L \d[ ]\w^n", GAME_LANG, "MILEAGE_GRENADE")
	}
	menu_additem(Menu, LangText, "wpn_grenade")
   
	formatex(LangText, sizeof(LangText), "\y%L", GAME_LANG, "MILEAGE_GET")
	menu_additem(Menu, LangText, "get_wpn")
   
	menu_setprop(Menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, Menu, 0)
}

public Bot_RandomWeapon(id)
{
	g_PreWeapon[id][WPN_PRIMARY] = g_WeaponList[WPN_PRIMARY][random(g_WeaponListCount[WPN_PRIMARY])]
	g_PreWeapon[id][WPN_SECONDARY] = g_WeaponList[WPN_SECONDARY][random(g_WeaponListCount[WPN_SECONDARY])]
	g_PreWeapon[id][WPN_MELEE] = g_WeaponList[WPN_MELEE][random(g_WeaponListCount[WPN_MELEE])]
	g_PreWeapon[id][WPN_GRENADE] = g_WeaponList[WPN_GRENADE][random(g_WeaponListCount[WPN_GRENADE])]
	
	Equip_Weapon(id)
}

public MenuHandle_MainEquip(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}
	if(!is_user_alive(id) || !Can_Use_Weapon(id))
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}

	new Name[64], Data[16], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)

	if(equal(Data, "wpn_pri"))
	{
		if(g_WeaponCount[WPN_PRIMARY]) Show_WpnSubMenu(id, WPN_PRIMARY, 0)
		else Show_MainEquipMenu(id)
	} else if(equal(Data, "wpn_sec")) {
		if(g_WeaponCount[WPN_SECONDARY]) Show_WpnSubMenu(id, WPN_SECONDARY, 0)
		else Show_MainEquipMenu(id)
	} else if(equal(Data, "wpn_melee")) {
		if(g_WeaponCount[WPN_MELEE]) Show_WpnSubMenu(id, WPN_MELEE, 0)
		else Show_MainEquipMenu(id)
	} else if(equal(Data, "wpn_grenade")) {
		if(g_WeaponCount[WPN_MELEE]) Show_WpnSubMenu(id, WPN_GRENADE, 0)
		else Show_MainEquipMenu(id)
	} else if(equal(Data, "get_wpn")) {
		Equip_Weapon(id)
	}
	
	menu_destroy(Menu)
	return PLUGIN_CONTINUE
}

public Show_WpnSubMenu(id, WpnType, Page)
{
	static MenuName[64]
	
	if(WpnType == WPN_PRIMARY) formatex(MenuName, sizeof(MenuName), "%L", GAME_LANG, "MILEAGE_PRIMARY")
	else if(WpnType == WPN_SECONDARY) formatex(MenuName, sizeof(MenuName), "%L", GAME_LANG, "MILEAGE_SECONDARY")
	else if(WpnType == WPN_MELEE) formatex(MenuName, sizeof(MenuName), "%L", GAME_LANG, "MILEAGE_MELEE")
	else if(WpnType == WPN_GRENADE) formatex(MenuName, sizeof(MenuName), "%L", GAME_LANG, "MILEAGE_GRENADE")
	
	new Menu = menu_create(MenuName, "MenuHandle_WpnSubMenu")

	static WeaponType, WeaponName[32], MenuItem[64], ItemID[4]
	static WeaponPrice, Money; Money = zevo_get_money(id)
	static WeaponLevel, WeaponMinPlayer;
	
	for(new i = 0; i < g_TotalWeaponCount; i++)
	{
		WeaponType = ArrayGetCell(ArWeaponType, i)
		if(WpnType != WeaponType)
			continue
		
		ArrayGetString(ArWeaponName, i, WeaponName, sizeof(WeaponName))
		WeaponPrice = ArrayGetCell(ArWeaponCost, i)
		WeaponLevel = ArrayGetCell(ArWeaponLevel, i)
		WeaponMinPlayer = ArrayGetCell(ArWeaponMinPlayer, i)
		
		// Check Vip Only?
		if(ArrayGetCell(ArWeaponVipOnly, i))
		{
			if(get_user_flags(id) & VIP_FLAG)
			{
				if(g_ServerPlayer >= WeaponMinPlayer)
				{
					if(g_PlayerLevel[id] >= WeaponLevel)
					{
						if(WeaponPrice > 0)
						{
							if(g_UnlockedWeapon[id][i]) 
								formatex(MenuItem, sizeof(MenuItem), "%s", WeaponName)
							else {
								if(Money >= WeaponPrice) formatex(MenuItem, sizeof(MenuItem), "%s \y($%i)\w", WeaponName, WeaponPrice)
								else formatex(MenuItem, sizeof(MenuItem), "\d%s \r($%i)\w", WeaponName, WeaponPrice)
							}
						} else {
							formatex(MenuItem, sizeof(MenuItem), "%s", WeaponName)
						}
					} else formatex(MenuItem, sizeof(MenuItem), "\d%s \r(Lv.%i)\w", WeaponName, WeaponLevel)
				} else formatex(MenuItem, sizeof(MenuItem), "\d%s \r(%L: %i)\w", WeaponName, GAME_LANG, "MILEAGE_MINPL", WeaponMinPlayer)
			} else formatex(MenuItem, sizeof(MenuItem), "\d%s \r(%L)\w", WeaponName, GAME_LANG, "MILEAGE_VIPONLY")
		} else {
			if(g_ServerPlayer >= WeaponMinPlayer)
			{
				if(g_PlayerLevel[id] >= WeaponLevel)
				{
					if(WeaponPrice > 0)
					{
						if(g_UnlockedWeapon[id][i]) 
							formatex(MenuItem, sizeof(MenuItem), "%s", WeaponName)
						else {
							if(Money >= WeaponPrice) formatex(MenuItem, sizeof(MenuItem), "%s \y($%i)\w", WeaponName, WeaponPrice)
							else formatex(MenuItem, sizeof(MenuItem), "\d%s \r($%i)\w", WeaponName, WeaponPrice)
						}
					} else {
						formatex(MenuItem, sizeof(MenuItem), "%s", WeaponName)
					}
				} else formatex(MenuItem, sizeof(MenuItem), "\d%s \r(Lv.%i)\w", WeaponName, WeaponLevel)
			} else formatex(MenuItem, sizeof(MenuItem), "\d%s \r(%L: %i)\w", WeaponName, GAME_LANG, "MILEAGE_MINPL", WeaponMinPlayer)
		}
		
		num_to_str(i, ItemID, sizeof(ItemID))
		menu_additem(Menu, MenuItem, ItemID)
	}
   
	menu_setprop(Menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, Menu, Page)
}

public MenuHandle_WpnSubMenu(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu)
		Show_MainEquipMenu(id)
		
		return PLUGIN_HANDLED
	}
	if(!is_user_alive(id) || !Can_Use_Weapon(id))
	{
		menu_destroy(Menu)
		return PLUGIN_HANDLED
	}

	new Name[64], Data[16], ItemAccess, ItemCallback
	menu_item_getinfo(Menu, Item, ItemAccess, Data, charsmax(Data), Name, charsmax(Name), ItemCallback)

	new ItemId = str_to_num(Data)
	new WeaponType, WeaponPrice, WeaponLevel, WeaponMinPlayer, WeaponName[32]
	
	WeaponType = ArrayGetCell(ArWeaponType, ItemId)
	WeaponPrice = ArrayGetCell(ArWeaponCost, ItemId)
	WeaponLevel = ArrayGetCell(ArWeaponLevel, ItemId)
	WeaponMinPlayer = ArrayGetCell(ArWeaponMinPlayer, ItemId)
	ArrayGetString(ArWeaponName, ItemId, WeaponName, sizeof(WeaponName))

	new Money = zevo_get_money(id)
	new OutputInfo[80]
	
	// Check Vip Only?
	if(ArrayGetCell(ArWeaponVipOnly, ItemId))
	{
		if(get_user_flags(id) & VIP_FLAG)
		{
			if(g_ServerPlayer >= WeaponMinPlayer)
			{
				if(g_PlayerLevel[id] >= WeaponLevel)
				{
					if(WeaponPrice > 0)
					{
						if(g_UnlockedWeapon[id][ItemId]) 
						{
							g_PreWeapon[id][WeaponType] = ItemId
							Show_MainEquipMenu(id)
						} else {
							if(Money >= WeaponPrice) 
							{
								g_UnlockedWeapon[id][ItemId] = 1
								g_PreWeapon[id][WeaponType] = ItemId

								formatex(OutputInfo, sizeof(OutputInfo), "!g[%s]!n %L", SystemName, GAME_LANG, "MILEAGE_UNLOCK", WeaponName, WeaponPrice)
								client_printc(id, OutputInfo)
								
								zevo_set_money(id, Money - WeaponPrice, 1)
								Show_MainEquipMenu(id)
							} else {
								formatex(OutputInfo, sizeof(OutputInfo), "!g[%s]!n %L", SystemName, GAME_LANG, "MILEAGE_MONEYREQ", WeaponPrice, WeaponName)
								client_printc(id, OutputInfo)	
							}
						}
					} else {
						if(!g_UnlockedWeapon[id][ItemId]) 
							g_UnlockedWeapon[id][ItemId] = 1
								
						g_PreWeapon[id][WeaponType] = ItemId
						Show_MainEquipMenu(id)
					}
				} else {
					formatex(OutputInfo, sizeof(OutputInfo), "!g[%s]!n %L", SystemName, GAME_LANG, "MILEAGE_LEVELREQ", WeaponLevel, WeaponName)
					client_printc(id, OutputInfo)	
					
					Show_WpnSubMenu(id, WeaponType, 0)
				}
			} else {
				formatex(OutputInfo, sizeof(OutputInfo), "!g[%s]!n %L", SystemName, GAME_LANG, "MILEAGE_PLAYERREQ", WeaponName, WeaponMinPlayer)
				client_printc(id, OutputInfo)
				
				Show_WpnSubMenu(id, WeaponType, 0)
			}
		} else {
			formatex(OutputInfo, sizeof(OutputInfo), "!g[%s]!n %L", SystemName, GAME_LANG, "MILEAGE_VIPREQ", WeaponName)
			client_printc(id, OutputInfo)
			
			Show_WpnSubMenu(id, WeaponType, 0)
		}
	} else {
		if(g_ServerPlayer >= WeaponMinPlayer)
		{
			if(g_PlayerLevel[id] >= WeaponLevel)
			{
				if(WeaponPrice > 0)
				{
					if(g_UnlockedWeapon[id][ItemId]) 
					{
						g_PreWeapon[id][WeaponType] = ItemId
						Show_MainEquipMenu(id)
					} else {
						if(Money >= WeaponPrice) 
						{
							g_UnlockedWeapon[id][ItemId] = 1
							g_PreWeapon[id][WeaponType] = ItemId
							
							formatex(OutputInfo, sizeof(OutputInfo), "!g[%s]!n %L", SystemName, GAME_LANG, "MILEAGE_UNLOCK", WeaponName, WeaponPrice)
							client_printc(id, OutputInfo)
							
							zevo_set_money(id, Money - WeaponPrice, 1)
							Show_MainEquipMenu(id)
						} else {
							formatex(OutputInfo, sizeof(OutputInfo), "!g[%s]!n %L", SystemName, GAME_LANG, "MILEAGE_MONEYREQ", WeaponPrice, WeaponName)
							client_printc(id, OutputInfo)	
							
							Show_WpnSubMenu(id, WeaponType, 0)
						}
					}
				} else {
					if(!g_UnlockedWeapon[id][ItemId]) 
						g_UnlockedWeapon[id][ItemId] = 1
							
					g_PreWeapon[id][WeaponType] = ItemId
					Show_MainEquipMenu(id)
				}
			} else {
				formatex(OutputInfo, sizeof(OutputInfo), "!g[%s]!n %L", SystemName, GAME_LANG, "MILEAGE_LEVELREQ", WeaponLevel, WeaponName)
				client_printc(id, OutputInfo)
				
				Show_WpnSubMenu(id, WeaponType, 0)
			}
		} else {
			formatex(OutputInfo, sizeof(OutputInfo), "!g[%s]!n %L", SystemName, GAME_LANG, "MILEAGE_PLAYERREQ", WeaponName, WeaponMinPlayer)
			client_printc(id, OutputInfo)
			
			Show_WpnSubMenu(id, WeaponType, 0)
		}
	}
	
	menu_destroy(Menu)
	return PLUGIN_CONTINUE
}

public Equip_Weapon(id)
{
	// Equip: Melee
	if(g_PreWeapon[id][WPN_MELEE] != -1)
		ExecuteForward(g_Forwards[WPN_BOUGHT], g_fwResult, id, ArrayGetCell(ArWeaponID, g_PreWeapon[id][WPN_MELEE]))
		
	// Equip: Grenade
	if(g_PreWeapon[id][WPN_GRENADE] != -1)
	{
		ExecuteForward(g_Forwards[WPN_BOUGHT], g_fwResult, id, ArrayGetCell(ArWeaponID, g_PreWeapon[id][WPN_GRENADE]))
	}
		
	// Equip: Secondary
	if(g_PreWeapon[id][WPN_SECONDARY] != -1)
	{
		drop_weapons(id, 2)
		ExecuteForward(g_Forwards[WPN_BOUGHT], g_fwResult, id, ArrayGetCell(ArWeaponID, g_PreWeapon[id][WPN_SECONDARY]))
	}
		
	// Equip: Primary
	if(g_PreWeapon[id][WPN_PRIMARY] != -1)
	{
		drop_weapons(id, 1)
		ExecuteForward(g_Forwards[WPN_BOUGHT], g_fwResult, id, ArrayGetCell(ArWeaponID, g_PreWeapon[id][WPN_PRIMARY]))
	}
	
	Set_BitVar(g_GotWeapon, id)
}

public Mileage_ReadWeapon()
{
	new Path[128]; get_configsdir(Path, charsmax(Path))
	format(Path, charsmax(Path), "%s/zombie_evolution/%s", Path, SETTING_FILE)
	
	if (!file_exists(Path))
	{
		log_error(AMX_ERR_NATIVE, "[Mileage Weapon] Can't Load File: %s", Path)
		return 
	}
	
	// Open customization file for reading
	new File = fopen(Path, "rt")
	new linedata[1024]
	new TempType[4], TempName[64], TempSysName[64], TempCost[16], TempLevel[8], 
	TempPlayer[4], TempVip[4], TempSupplyBox[4]
	
	// Seek to setting's key
	while (!feof(File))
	{
		// Read one line at a time
		fgets(File, linedata, charsmax(linedata))
		
		// Replace newlines with a null character to prevent headaches
		replace(linedata, charsmax(linedata), "^n", "")
		
		// Blank line or comment
		if (!linedata[0] || linedata[0] == ';') continue;
		
		replace_all(linedata, 1023, "[TYPE]", "")
		replace_all(linedata, 1023, "[NAME]", " ")
		replace_all(linedata, 1023, "[SYSNAME]", " ")
		replace_all(linedata, 1023, "[COST]", " ")
		replace_all(linedata, 1023, "[LEVEL]", " ")
		replace_all(linedata, 1023, "[MINPLAYER]", " ")
		replace_all(linedata, 1023, "[VIP]", " ")
		replace_all(linedata, 1023, "[RANDOMGIVE]", " ")

		if(linedata[0] == '1')
		{
			parse(linedata, TempType, 3, TempName, 63, TempSysName, 63, TempCost, 15, TempLevel, 7, TempPlayer, 3, TempVip, 3, TempSupplyBox, 3)
			Register_MileageWeapon(1, TempName, TempSysName, str_to_num(TempCost), str_to_num(TempLevel), str_to_num(TempPlayer), str_to_num(TempVip), str_to_num(TempSupplyBox))
		} else if(linedata[0] == '2') {
			parse(linedata, TempType, 3, TempName, 63, TempSysName, 63, TempCost, 15, TempLevel, 7, TempPlayer, 3, TempVip, 3, TempSupplyBox, 3)
			Register_MileageWeapon(2, TempName, TempSysName, str_to_num(TempCost), str_to_num(TempLevel), str_to_num(TempPlayer), str_to_num(TempVip), str_to_num(TempSupplyBox))
		} else if(linedata[0] == '3') {
			parse(linedata, TempType, 3, TempName, 63, TempSysName, 63, TempCost, 15, TempLevel, 7, TempPlayer, 3, TempVip, 3, TempSupplyBox, 3)
			Register_MileageWeapon(3, TempName, TempSysName, str_to_num(TempCost), str_to_num(TempLevel), str_to_num(TempPlayer), str_to_num(TempVip), str_to_num(TempSupplyBox))
		} else if(linedata[0] == '4') {
			parse(linedata, TempType, 3, TempName, 63, TempSysName, 63, TempCost, 15, TempLevel, 7, TempPlayer, 3, TempVip, 3, TempSupplyBox, 3)
			Register_MileageWeapon(4, TempName, TempSysName, str_to_num(TempCost), str_to_num(TempLevel), str_to_num(TempPlayer), str_to_num(TempVip), str_to_num(TempSupplyBox))
		}
	}
}

public Register_MileageWeapon(Type, Name[], SysName[], Cost, Level, MinPlayer, Vip, SupplyBox)
{
	static SAIGON[64]; copy(SAIGON, 63, Name)
	replace_all(SAIGON, 63, "_", " ")
	
	ArrayPushCell(ArWeaponType, Type)
	ArrayPushString(ArWeaponName, SAIGON)
	ArrayPushString(ArWeaponSysName, SysName)
	ArrayPushCell(ArWeaponCost, Cost)
	ArrayPushCell(ArWeaponLevel, Level)
	ArrayPushCell(ArWeaponMinPlayer, MinPlayer)
	ArrayPushCell(ArWeaponVipOnly, Vip)
	ArrayPushCell(ArWeaponSupplyBox, SupplyBox)
	ArrayPushCell(ArWeaponID, -1)
	
	if(g_FirstWeapon[Type] == -1) 
		g_FirstWeapon[Type] = g_TotalWeaponCount
	
	g_WeaponCount[Type]++
	g_TotalWeaponCount++
}

public Can_Use_Weapon(id)
{
	return Get_BitVar(g_CanUseWeapon, id)
}

// Drop primary/secondary weapons
stock drop_weapons(id, dropwhat)
{
	// Get user weapons
	static weapons[32], num, i, weaponid
	num = 0 // reset passed weapons count (bugfix)
	get_user_weapons(id, weapons, num)
	
	// Loop through them and drop primaries or secondaries
	for (i = 0; i < num; i++)
	{
		// Prevent re-indexing the array
		weaponid = weapons[i]
		
		if ((dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)) || (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM)))
		{
			// Get weapon entity
			static wname[32]; get_weaponname(weaponid, wname, charsmax(wname))
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock client_printc(index, const text[], any:...)
{
	static szMsg[128]; vformat(szMsg, sizeof(szMsg) - 1, text, 3)

	replace_all(szMsg, sizeof(szMsg) - 1, "!g", "^x04")
	replace_all(szMsg, sizeof(szMsg) - 1, "!n", "^x01")
	replace_all(szMsg, sizeof(szMsg) - 1, "!t", "^x03")

	if(index)
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgSayText, _, index);
		write_byte(index);
		write_string(szMsg);
		message_end();
	}
} 

stock Get_PlayerCount(Alive, Team)
// Alive: 0 - Dead | 1 - Alive | 2 - Both
// Team: 1 - T | 2 - CT
{
	new Flag[4], Flag2[12]
	new Players[32], PlayerNum

	if(!Alive) formatex(Flag, sizeof(Flag), "%sb", Flag)
	else if(Alive == 1) formatex(Flag, sizeof(Flag), "%sa", Flag)
	
	if(Team == 1) 
	{
		formatex(Flag, sizeof(Flag), "%se", Flag)
		formatex(Flag2, sizeof(Flag2), "TERRORIST", Flag)
	} else if(Team == 2) 
	{
		formatex(Flag, sizeof(Flag), "%se", Flag)
		formatex(Flag2, sizeof(Flag2), "CT", Flag)
	}
	
	get_players(Players, PlayerNum, Flag, Flag2)
	
	return PlayerNum
}

stock Get_TotalInPlayer(Alive)
{
	return Get_PlayerCount(Alive, 1) + Get_PlayerCount(Alive, 2)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
