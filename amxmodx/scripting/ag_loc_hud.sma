#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <hlstocks>

#define PLUGIN	"Loc-Hud"
#define VERSION	"2.0"
#define AUTHOR	"Kemal & teylo"

new gHudLoc

new Array:gLocations;
new players[32], inum, player;
new g_msg[512];
new g_loc_enable;

new g_aLoc[33]


public plugin_init() 
{
	register_plugin(PLUGIN,VERSION,AUTHOR);
	
	gHudLoc = CreateHudSyncObj();
	gLocations = ArrayCreate(32);
	
	LoadLocations();
	register_clcmd( "say /loc", "set_loc" );
	g_loc_enable = register_cvar("sv_start_loc","1")

}

public plugin_end() 
{
	ArrayDestroy(gLocations);
}

public client_putinserver(id)
{
	if(get_pcvar_num(g_loc_enable) == 1)
	{
		g_aLoc[id] = 1;
	} else {
		g_aLoc[id] = 0;
	}

	if(!is_user_bot(id))
		set_task(1.0,"set_hud_msg",id,_,_,"b");
}

public client_disconnected(id)
{
	// turn id to 0 or 1 when disconnect (opposite to cvar value)
	if(get_pcvar_num(g_loc_enable) == 1)
	{
		g_aLoc[id] = 0;
	} else {
		g_aLoc[id] = 1;
	}
}

public set_hud_msg(id)
{
	if (hl_get_user_spectator(id))
		return PLUGIN_HANDLED;

	new szTeama[32],szTeamb[32];
	hl_get_user_model(id, szTeama, charsmax(szTeama));

	static g_pName[32], pos
	new str[32]
	pos = 0
	
	get_players(players, inum)
	
	for(new i; i < inum; i++) 
	{
		player = players[i]
		get_user_name(player, g_pName, 31)
		GetPlayerLocation(player, str, charsmax(str));	

		// get other user team id
		hl_get_user_model(player, szTeamb, charsmax(szTeamb));
		if(equal(szTeama, szTeamb)) 
		{
			pos += formatex(g_msg[pos], 511-pos, "^^8%s ^^8[H:^^2%i^^8 | A:^^2%i^^8] -  ^^1%s ^n", g_pName, get_user_health(player),get_user_armor(player), str );
		}
	}
	if (g_aLoc[id] == 1)
		print_hud(id);

	return PLUGIN_CONTINUE;
}

public print_hud(id)
{

	get_players(players, inum)
	
	for(new i; i < inum; i++) 
	{
		player = players[i]
		set_hudmessage(255,255,255,0.02, 0.5,0,1.0,3.0,0.1,0.1);
		ShowSyncHudMsg(id, gHudLoc, "%s", g_msg);

	}
	return PLUGIN_HANDLED;	
}

public set_loc(id)
{	
	if(g_aLoc[id] == 0)
	{
		g_aLoc[id]=1;
		client_print(id,print_chat,"^^2 Locations activated.");
	}else{
		g_aLoc[id]=0;
		client_print(id,print_chat,"^^1 Locations deactivated.");
	}	
	return PLUGIN_CONTINUE;
}

public LoadLocations() 
{
	new mapFile[64];
	
	{
		new mapName[32];
		get_mapname(mapName, charsmax(mapName));

		new file[64];
		new handleDir = open_dir("locs", file, charsmax(file));
		do {
			if (equali(file, fmt("%s.loc", mapName))) {
				formatex(mapFile, charsmax(mapFile), "locs/%s", file);
				break;
			}
		} while (next_file(handleDir, file, charsmax(file)));
		close_dir(handleDir);
	}

	new handle = fopen(mapFile, "r");

	if (!handle)
		return false;

	new name[32], Float:origin[3];

	new buffer[32], numHash, c, i;
	while ((c = fgetc(handle)) != -1) {
		// hash signs marks the end of the string
		if (c == '#') {
			// put null character in the buffer to make it safe to read
			if (i < charsmax(buffer))
				buffer[i] = '^0';	

			// reset position for buffer
			i = 0;

			if (numHash == 0) {
				copy(name, charsmax(name), buffer);
			} else if (numHash > 0 && numHash <= 3) {
				origin[numHash - 1] = str_to_float(buffer);
			}
			
			// finish to read this loc and put it into the array
			if (numHash == 3) {
				ArrayPushArray(gLocations, origin, sizeof(origin));
				ArrayPushString(gLocations, name);
				
				// reset everything so we can read a new location
				arrayset(origin, 0.0, sizeof(origin));
				numHash = 0;
				continue;
			}
			numHash++;
		} else if (i < charsmax(buffer)) { // copy until the buffer is full
			buffer[i++] = c;
		}
	}

	fclose(handle);

	return true;
}

public FindNearestLocation(Float:origin[3], output[], len) 
{
	new Float:nearestOrigin[3], idxNearestLoc;
	new Float:locOrigin[3];

	if (!ArraySize(gLocations))
		return false;

	// initialize nearest origin with the first location
	ArrayGetArray(gLocations, 0, nearestOrigin, sizeof(nearestOrigin));
	
	for (new i; i < ArraySize(gLocations); i += 2) {
		ArrayGetArray(gLocations, i, locOrigin, sizeof(locOrigin));
		if (vector_distance(origin, locOrigin) <= vector_distance(origin, nearestOrigin)) {
			nearestOrigin = locOrigin;
			idxNearestLoc = i;
		}
	}

	// save location name in the output
	return ArrayGetString(gLocations, idxNearestLoc + 1, output, len) > 0 ? true : false;
}

public GetPlayerLocation(id, locName[], len) 
{
	new Float:origin[3];
	pev(id, pev_origin, origin);
	if (!FindNearestLocation(origin, locName, len)) {
		locName[0] = '^0';
	}
}

