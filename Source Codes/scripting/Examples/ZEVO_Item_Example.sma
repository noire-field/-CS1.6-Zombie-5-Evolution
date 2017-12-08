#include <amxmodx>
#include <zombie_evolution>

#define PLUGIN "[ZEVO] Item: Sample"
#define VERSION "1.0"
#define AUTHOR "author"

new BlackBullet

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	BlackBullet = zevo_register_item("Black Bullet", TEAM_HUMAN, 100, ITEM_ONCE)
	zevo_register_item("Excalibur", TEAM_HUMAN, 250, ITEM_ROUND)
	zevo_register_item("EA", TEAM_HUMAN, 500, ITEM_MAP)
}

public zevo_item_activate(id, ItemID)
{
	if(ItemID == BlackBullet) 
	{
		// 
	}
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3076\\ f0\\ fs16 \n\\ par }
*/
