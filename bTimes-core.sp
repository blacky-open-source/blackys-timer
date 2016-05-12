#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "bTimes-core",
	author = "blacky",
	description = "The root of bTimes",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <bTimes-timer>
#include <bTimes-ranks>
#include <bTimes-zones>
#include <sourcemod>
#include <sdktools>

new const String:g_CommandList[][] = 
{
	"sm_auto       - Toggles auto bunnyhop.", 
	"sm_autobhop   - Toggles auto bunnyhop.",
	"sm_b          - Teleports you to the bonus area.",
	"sm_bhop       - Toggles auto bunnyhop.",
	"sm_bmapsdone  - Shows your or a specified player's maps done.",
	"sm_bmapsleft  - Shows your or a specified player's maps left to beat.",
	"sm_bonus      - Teleports you to the bonus area.",
	"sm_br         - Teleports you to the bonus area.",
	"sm_brank      - Shows the overall bonus rank of you or a specified player.",
	"sm_btime      - Like sm_time but for Bonus times.",
	"sm_btop       - Shows the bonus overall ranks.",
	"sm_bwr        - Shows bonus record for a map.",
	"sm_changes    - See the changes in the newer timer version.",
	"sm_checkpoint - Opens the checkpoint menu.",
	"sm_colorhelp  - View the help for colored chat settings.",
	"sm_colormsg   - Change your chat message color.",
	"sm_colorname  - Change colored name.",
	"sm_commands   - Shows the command list.",
	"sm_cp         - Opens the checkpoint menu.",
	"sm_display    - Shows all info in the hint text when being timed.",
	"sm_fast       - Sets your speed to fast (2.0).",
	"sm_fullhud    - Shows all info in the hint text when being timed.",
	"sm_hide       - Toggles hide.",
	"sm_hud        - Toggles hud.",
	"sm_keys       - Toggles showing pressed keys.",
	"sm_lastplayed - Shows the last played maps.",
	"sm_lowgrav    - Lowers your gravity.",
	"sm_mapsdone   - Shows your or a specified player's maps done.",
	"sm_mapsdonen  - Shows your or a specified player's maps done on normal.",
	"sm_mapsdonesw - Shows your or a specified player's maps done on sideways.",
	"sm_mapsdonew  - Shows your or a specified player's maps done on w-only.",
	"sm_mapsleft   - Shows your or a specified player's maps left to beat.",
	"sm_mapsleftn  - Shows your or a specified player's maps left to beat on normal.",
	"sm_mapsleftsw - Shows your or a specified player's maps left to beat on sideways.",
	"sm_mapsleftw  - Shows your or a specified player's maps left to beat on w-only.",
	"sm_maptime    - Shows how long the current map has been on.",
	"sm_maxinfo    - Shows all info in the hint text when being timed.",
	"sm_mode       - Switches you to normal, w, or sideways timer.",
	"sm_mostplayed - Displays the most played maps.",
	"sm_n          - Switches you to normal timer.",
	"sm_normal     - Switches you to normal timer.",
	"sm_normalgrav - Sets your gravity to normal.",
	"sm_normalspeed- Sets your speed to normal.",
	"sm_p          - Puts you in noclip. Stops your timer.",
	"sm_pad        - Toggles showing pressed keys.",
	"sm_pause      - Pauses your timer and freezes you.",
	"sm_playtime   - Shows the people who played the most.",
	"sm_practice   - Puts you in noclip. Stops your timer.",
	"sm_r          - Teleports you to the starting zone.",
	"sm_rank       - Shows the overall rank of you or a specified player.",
	"sm_rankn      - Shows the overall normal rank of you or a specified player.",
	"sm_ranksw     - Shows the overall sideways rank of you or a specified player.",
	"sm_rankw      - Shows the overall w-only rank of you or a specified player.",
	"sm_respawn    - Teleports you to the starting zone.",
	"sm_restart    - Teleports you to the starting zone.",
	"sm_resume     - Unpauses your timer and unfreezes you.",
	"sm_save       - Saves a new checkpoint.",
	"sm_setspeed   - Changes your speed to the specified value.",
	"sm_sideways   - Switches you to sideways timer.",
	"sm_slow       - Sets your speed to slow (0.5).",
	"sm_sound      - Control different sounds you want to hear when playing.",
	"sm_spec       - Be a spectator.",
	"sm_spectate   - Be a spectator.",
	"sm_speed      - Changes your speed to the specified value.",
	"sm_start      - Teleports you to the starting zone.",
	"sm_stats      - Shows the stats of you or a specified player.",
	"sm_stop       - Stops your timer.",
	"sm_style      - Switch to normal, w, or sideways timer.",
	"sm_sw         - Switches you to sideways timer.",
	"sm_tele       - Teleports you to the specified checkpoint.",
	"sm_time       - Shows your time on a given map. With no map given, it will tell you your time on the current map.",
	"sm_timesw     - Like sm_time but for Sideways times.",
	"sm_timew      - Like sm_time but for W-Only times.",
	"sm_top        - Shows the overall ranks.",
	"sm_topn       - Shows the normal overall ranks.",
	"sm_topsw      - Shows the sideways overall ranks.",
	"sm_topw       - Shows the w-only overall ranks.",
	"sm_tp         - Teleports you to the specified checkpoint.",
	"sm_tpto       - Teleports you to a player.",
	"sm_truevel    - Toggles between 2D and 3D velocity meters.",
	"sm_unhide     - Toggles hide.",
	"sm_unpause    - Unpauses your timer.",
	"sm_velocity   - Toggles between 2D and 3D velocity meters.",
	"sm_w          - Switches you to W-Only timer.",
	"sm_wonly      - Switches you to W-Only timer.",
	"sm_wr         - Shows all the times for the current map.",
	"sm_wrb        - Shows bonus record for a map",
	"sm_wrsw       - Shows all the sideways times for the current map.",
	"sm_wrw        - Shows all the W-Only times for the current map."
};

new const String:g_ChangeLog[][] =
{
	"Fixed a bug where ghost wouldn't delete.",
	"Fixed WR sounds.",
	"Added chat ranks/custom chat names. !colorhelp for more info",
	"Mapsleft shows number of maps left in title.",
	"Expanded on !time command. \"!time @3\" will show who has #3 on the map.",
	"!keys now shows what direction a player is turning."
};

new Handle:g_DB = INVALID_HANDLE;

new 	String:g_mapname[64],
	g_clientID[MAXPLAYERS+1];
	
new	bool:g_IsSpamming[MAXPLAYERS+1] = {false, ...};
	
// Play time
new	Float:g_JoinStart[MAXPLAYERS+1];
	
new	Float:g_MapStart,
	Float:g_MapPlaytime;
	
// Chat
new 	String:g_msg_start[128] = {""};
new 	String:g_msg_varcol[128] = {"\x07B4D398"};
new 	String:g_msg_textcol[128] = {"\x01"};

// Forwards
new	Handle:g_fwdMapIDPostCheck;

public OnPluginStart()
{
	DB_Connect();
	
	HookEvent("player_changename", Event_PlayerChangeName, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	
	RegConsoleCmd("sm_mostplayed", SM_TopMaps, "Displays the most played maps");
	RegConsoleCmd("sm_lastplayed", SM_LastPlayed, "Shows the last played maps");
	RegConsoleCmd("sm_thelp", SM_THelp, "Shows the timer commands.");
	RegConsoleCmd("sm_commands", SM_THelp, "Shows the timer commands.");
	RegConsoleCmd("sm_search", SM_Search, "Search the command list for the given string of text.");
	RegConsoleCmd("sm_changes", SM_Changes, "See the changes in the newer timer version.");
	
	AddCommandListener(CMD_Say, "say");
	AddCommandListener(CMD_Say, "say_team");
}

// Create natives
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("GetClientID", Native_GetClientID);
	CreateNative("GetPlaytime", Native_GetPlaytime);
	CreateNative("IsSpamming", Native_IsSpamming);
	CreateNative("SetIsSpamming", Native_SetIsSpamming);
	
	g_fwdMapIDPostCheck = CreateGlobalForward("OnMapIDPostCheck", ET_Event);
	return APLRes_Success;
}

public OnMapStart()
{
	GetCurrentMap(g_mapname, sizeof(g_mapname));
	
	g_MapStart = GetEngineTime();
	
	// Creates map if it doesn't exist, sets map as recently played, and loads map playtime
	CreateCurrentMapID();
}

public OnMapIDPostCheck()
{
	DB_LoadMapPlaytime();
}

public OnMapEnd()
{
	DB_SaveMapPlaytime();
	DB_SetMapLastPlayed();
}

public OnClientDisconnect(client)
{
	if(!IsFakeClient(client))
		DB_SavePlaytime(client);
	g_clientID[client] = 0;
}

public OnClientPutInServer(client)
{
	g_JoinStart[client] = GetEngineTime();
}

public OnClientAuthorized(client)
{
	if(!IsFakeClient(client))
	{
		CreatePlayerID(client);
	}
}

public OnTimerChatChanged(MessageType, String:Message[])
{
	if(MessageType == 0)
	{
		Format(g_msg_start, sizeof(g_msg_start), Message);
		ReplaceString(g_msg_start, sizeof(g_msg_start), "^", "\x07", false);
	}
	else if(MessageType == 1)
	{
		Format(g_msg_varcol, sizeof(g_msg_varcol), Message);
		ReplaceString(g_msg_varcol, sizeof(g_msg_varcol), "^", "\x07", false);
	}
	else if(MessageType == 2)
	{
		Format(g_msg_textcol, sizeof(g_msg_textcol), Message);
		ReplaceString(g_msg_textcol, sizeof(g_msg_textcol), "^", "\x07", false);
	}
}

public Action:Event_PlayerTeam_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client  = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(0 < client <= MaxClients)
	{
		if(IsClientInGame(client))
		{
			new oldteam = GetEventInt(event, "oldteam");
			if(oldteam == 0)
			{
				PrintColorText(client, "%s%sType in console %ssm_thelp %sfor a command list. %ssm_changes%s to see the changelog.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					g_msg_textcol,
					g_msg_varcol,
					g_msg_textcol);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:CMD_Say(client, const String:command[], argc)
{
	if(0 < client <= MaxClients)
	{
		if(IsClientInGame(client))
		{
			if(!IsSpamming(client))
			{			
				decl String:name[MAX_NAME_LENGTH], String:arg[300];
				GetClientName(client, name, sizeof(name));
				GetCmdArgString(arg, sizeof(arg));
				StripQuotes(arg);
				
				// Check if it's a chat command
				if(IsChatTrigger())
				{
					return Plugin_Handled;
				}
				else if(StrEqual(arg, "spawn") || StrEqual(arg, "restart") || StrEqual(arg, "respawn"))
				{
					FakeClientCommand(client, "sm_r");
					return Plugin_Handled;
				}
				else if(StrEqual(arg, "rank") || StrEqual(arg, "brank") || StrEqual(arg, "rankw") || StrEqual(arg, "ranksw"))
				{
					FakeClientCommand(client, "sm_%s", arg);
					return Plugin_Handled;
				}
				
				// Prevent chat spam for 0.3 seconds
				SetIsSpamming(client, 0.3);
			}
		}
	}
	return Plugin_Continue;
}

public Action:SM_TopMaps(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		decl String:query[256];
		Format(query, sizeof(query), "SELECT MapName, MapPlaytime FROM maps ORDER BY MapPlaytime DESC");
		SQL_TQuery(g_DB, TopMaps_Callback, query, client);
		
		LogMessage("%L executed sm_topmaps", client);
	}
	return Plugin_Handled;
}

public TopMaps_Callback(Handle:owner, Handle:hndl, String:error[], any:client)
{
	if(hndl != INVALID_HANDLE)
	{
		if(IsClientInGame(client))
		{
			new Handle:menu = CreateMenu(Menu_TopMaps);
			SetMenuTitle(menu, "Most played maps\n---------------------------------------");
			
			new rows = SQL_GetRowCount(hndl);
			if(rows > 0)
			{
				decl String:mapname[64], String:timeplayed[32], String:display[128], iTime;
				for(new i=0, j=0; i<rows; i++)
				{
					SQL_FetchRow(hndl);
					iTime = SQL_FetchInt(hndl, 1);
					
					if(iTime != 0)
					{
						SQL_FetchString(hndl, 0, mapname, sizeof(mapname));
						
						if(IsMapValid(mapname))
						{
							FormatPlayerTime(float(iTime), timeplayed, sizeof(timeplayed), false, 1);
							SplitString(timeplayed, ".", timeplayed, sizeof(timeplayed));
							Format(display, sizeof(display), "#%d: %s - %s", ++j, mapname, timeplayed);
							
							AddMenuItem(menu, display, display);
						}
					}
				}
				
				SetMenuExitBackButton(menu, true);
				SetMenuExitButton(menu, true);
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
			}
		}
	}
	else
	{
		LogError(error);
	}
}

public Menu_TopMaps(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//new String:info[32];
		//GetMenuItem(menu, param2, info, sizeof(info));
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_LastPlayed(client, argS)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		decl String:query[256];
		Format(query, sizeof(query), "SELECT MapName, LastPlayed FROM maps ORDER BY LastPlayed DESC");
		SQL_TQuery(g_DB, LastPlayed_Callback, query, client);
		
		LogMessage("%L executed sm_lastplayed", client);
	}
	return Plugin_Handled;
}

public LastPlayed_Callback(Handle:owner, Handle:hndl, String:error[], any:client)
{
	if(hndl != INVALID_HANDLE)
	{
		if(IsClientInGame(client))
		{
			new Handle:menu = CreateMenu(Menu_LastPlayed);
			SetMenuTitle(menu, "Last played maps\n---------------------------------------");
			
			decl String:sMapName[64], String:sDate[32], String:sTimeOfDay[32], String:display[256], iTime;
			
			new rows = SQL_GetRowCount(hndl);
			for(new i=1; i<=rows; i++)
			{
				SQL_FetchRow(hndl);
				iTime = SQL_FetchInt(hndl, 1);
				
				if(iTime != 0)
				{
					SQL_FetchString(hndl, 0, sMapName, sizeof(sMapName));
					
					if(IsMapValid(sMapName))
					{
						FormatTime(sDate, sizeof(sDate), "%x", iTime);
						FormatTime(sTimeOfDay, sizeof(sTimeOfDay), "%X", iTime);
						
						Format(display, sizeof(display), "%s - %s - %s", sMapName, sDate, sTimeOfDay);
						
						AddMenuItem(menu, display, display);
					}
				}
			}
			
			SetMenuExitBackButton(menu, true);
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
	}
	else
	{
		LogError(error);
	}
}

public Menu_LastPlayed(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//new String:info[32];
		//GetMenuItem(menu, param2, info, sizeof(info));
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:Event_PlayerChangeName(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	new PlayerID = GetClientID(client);
	if(GetClientID(client) != 0)
	{
		decl String:newname[(MAX_NAME_LENGTH*2)+1], String:query[128];
		
		GetEventString(event, "newname", newname, sizeof(newname));
		
		SQL_LockDatabase(g_DB);
		SQL_EscapeString(g_DB, newname, newname, sizeof(newname));
		SQL_UnlockDatabase(g_DB);
		
		Format(query, sizeof(query), "UPDATE players SET User='%s' WHERE PlayerID=%d", newname, PlayerID);
		SQL_TQuery(g_DB, Event_PlayerChangeName_Callback, query);
	}
}

public Event_PlayerChangeName_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

public Action:SM_Changes(client, args)
{
	if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		PrintColorText(client, "%s%sLook in console for a list of changes in the newer timer version.",
			g_msg_start,
			g_msg_textcol);
	}
	
	new iSize = sizeof(g_ChangeLog);
	
	for(new i=0; i<iSize; i++)
	{
		PrintToConsole(client, g_ChangeLog[i]);
	}
	
	return Plugin_Handled;
}

DB_Connect()
{
	if(g_DB != INVALID_HANDLE)
		CloseHandle(g_DB);
	new String:error[255];
	g_DB = SQL_Connect("timer", true, error, sizeof(error));
	if(g_DB == INVALID_HANDLE)
	{
		LogError(error);
		CloseHandle(g_DB);
	}
	else
	{
		decl String:query[256];
		
		// Create maps table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS maps(MapID INTEGER NOT NULL AUTO_INCREMENT, MapName TEXT, MapPlaytime INTEGER NOT NULL, LastPlayed INTEGER NOT NULL, PRIMARY KEY (MapID))");
		SQL_TQuery(g_DB, DB_Connect_Callback, query);
		
		// Create zones table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS zones(MapID INTEGER, Type INTEGER, point00 REAL, point01 REAL, point02 REAL, point10 REAL, point11 REAL, point12 REAL)");
		SQL_TQuery(g_DB, DB_Connect_Callback, query);
		
		// Create players table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS players(PlayerID INTEGER NOT NULL AUTO_INCREMENT, SteamID TEXT, User Text, Playtime INTEGER NOT NULL, PRIMARY KEY (PlayerID))");
		SQL_TQuery(g_DB, DB_Connect_Callback, query);
		
		// Create times table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS times(rownum INTEGER NOT NULL AUTO_INCREMENT, MapID INTEGER, Type INTEGER, Style INTEGER, PlayerID INTEGER, Time REAL, Jumps INTEGER, Strafes INTEGER, Points REAL, Timestamp INTEGER, Sync REAL, PRIMARY KEY (rownum))");
		SQL_TQuery(g_DB, DB_Connect_Callback, query);
	}
}

public DB_Connect_Callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

CreateCurrentMapID()
{	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT MapID FROM maps WHERE MapName='%s'", g_mapname);
	SQL_TQuery(g_DB, DB_CreateCurrentMapID_Callback1, query);
}

public DB_CreateCurrentMapID_Callback1(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		decl String:query[512];
		if(SQL_GetRowCount(hndl) == 0)
		{
			Format(query, sizeof(query), "INSERT INTO maps (MapName) VALUES ('%s')", g_mapname);
			SQL_TQuery(g_DB, DB_CreateCurrentMapID_Callback2, query);
		}
		else
		{
			Call_StartForward(g_fwdMapIDPostCheck);
			Call_Finish();
		}
	}
	else
	{
		LogError(error);
	}
}

public DB_CreateCurrentMapID_Callback2(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		LogMessage("MapID for %s created", g_mapname);
		
		Call_StartForward(g_fwdMapIDPostCheck);
		Call_Finish();
	}
	else
	{
		LogError(error);
	}
}

CreatePlayerID(client)
{
	decl String:query[256], String:authid[32];
	
	GetClientAuthString(client, authid, sizeof(authid));
	
	Format(query, sizeof(query), "SELECT * FROM players WHERE SteamID = '%s'", authid);
	SQL_TQuery(g_DB, DB_CreatePlayerID_Callback1, query, client);
}

public DB_CreatePlayerID_Callback1(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if(hndl != INVALID_HANDLE)
	{
		if(IsClientConnected(client) && !IsFakeClient(client))
		{
			decl String:query[256], String:authid[32], String:name[(MAX_NAME_LENGTH*2)+1];
			
			GetClientName(client, name, sizeof(name));
			
			SQL_LockDatabase(g_DB);
			SQL_EscapeString(g_DB, name, name, sizeof(name));
			SQL_UnlockDatabase(g_DB);
			
			GetClientAuthString(client, authid, sizeof(authid));
			
			if(SQL_GetRowCount(hndl) == 0)
			{
				Format(query, sizeof(query), "INSERT INTO players (SteamID, User) VALUES ('%s', '%s')", authid, name);
				SQL_TQuery(g_DB, DB_CreatePlayerID_Callback2, query, client);
			}
			else
			{
				Format(query, sizeof(query), "UPDATE players SET User='%s' WHERE SteamID='%s'", name, authid);
				SQL_TQuery(g_DB, DB_CreatePlayerID_Callback2, query, client);
			}
		}
	}
	else
	{
		LogError(error);
	}
}

public DB_CreatePlayerID_Callback2(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if(hndl != INVALID_HANDLE)
	{
		if(IsClientConnected(client) && !IsFakeClient(client))
		{
			decl String:name[MAX_NAME_LENGTH], String:authid[32];
			
			GetClientName(client, name, sizeof(name));
			GetClientAuthString(client, authid, sizeof(authid));
			
			LogMessage("Player ID entry for %s <%s> updated", name, authid);
			
			decl String:query[512];
			
			Format(query, sizeof(query), "SELECT PlayerID FROM players WHERE SteamID = '%s'", authid);
			SQL_TQuery(g_DB, DB_CreatePlayerID_Callback3, query, client);
		}
	}
	else
	{
		LogError(error);
	}
}

public DB_CreatePlayerID_Callback3(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if(hndl != INVALID_HANDLE)
	{	
		if(IsClientConnected(client) && !IsFakeClient(client))
		{
			SQL_FetchRow(hndl);
			g_clientID[client] = SQL_FetchInt(hndl, 0);
			
			DB_LoadPlayerInfo(client);
			SetClientRank(client);
		}
	}
}

public Native_GetClientID(Handle:plugin, numParams)
{
	return g_clientID[GetNativeCell(1)];
}

DB_SavePlaytime(client)
{
	new ClientID = GetClientID(client);
	if(GetClientID(client) != 0)
	{
		new addplaytime = RoundToFloor(GetEngineTime() - g_JoinStart[client]);
		
		decl String:query[128];
		Format(query, sizeof(query), "UPDATE players SET Playtime=(SELECT Playtime FROM (SELECT * FROM players) AS x WHERE PlayerID=%d)+%d WHERE PlayerID=%d",
			ClientID,
			addplaytime,
			ClientID);
			
		SQL_TQuery(g_DB, DB_SavePlaytime_Callback2, query);
	}
}

public DB_SavePlaytime_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(SQL_GetRowCount(hndl) != 0)
		{
			ResetPack(data);
			new clientid    = ReadPackCell(data);
			new addplaytime = RoundToFloor(GetEngineTime() - ReadPackFloat(data));
			
			SQL_FetchRow(hndl);
			
			decl String:query[128];
			Format(query, sizeof(query), "UPDATE players SET Playtime=(SELECT Playtime FROM players WHERE PlayerID=%d)+%d WHERE PlayerID=%d",
				clientid,
				addplaytime,
				clientid);
				
			SQL_TQuery(g_DB, DB_SavePlaytime_Callback2, query);
		}
	}
	else
	{
		LogError(error);
	}
}

public DB_SavePlaytime_Callback2(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError(error);
}

public Native_GetPlaytime(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if(g_clientID[client] != 0)
	{
		return _:(GetEngineTime()-g_JoinStart[client]);
	}
	
	return _:0.0;
}

DB_SaveMapPlaytime()
{
	decl String:query[128];

	Format(query, sizeof(query), "UPDATE maps SET MapPlaytime=%d+%d WHERE MapName='%s'",
		RoundToFloor(g_MapPlaytime),
		RoundToFloor(GetEngineTime()-g_MapStart),
		g_mapname);
		
	SQL_TQuery(g_DB, DB_SaveMapPlaytime_Callback, query);
}

public DB_SaveMapPlaytime_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError(error);
}

DB_SetMapLastPlayed()
{
	decl String:query[128];
	
	Format(query, sizeof(query), "UPDATE maps SET LastPlayed=%d WHERE MapName='%s'",
		GetTime(),
		g_mapname);
		
	SQL_TQuery(g_DB, DB_SetMapLastPlayed_Callback, query);
}

public DB_SetMapLastPlayed_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError(error);
}

DB_LoadMapPlaytime()
{
	decl String:query[128];
	Format(query, sizeof(query), "SELECT MapPlaytime FROM maps WHERE MapName='%s'",
		g_mapname);
	SQL_TQuery(g_DB, DB_LoadMapPlaytime_Callback, query);
}

public DB_LoadMapPlaytime_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(SQL_GetRowCount(hndl) != 0)
		{
			SQL_FetchRow(hndl);
			g_MapPlaytime = float(SQL_FetchInt(hndl, 0));
		}
	}
	else
	{
		LogError(error);
	}
}

public Action:SM_THelp(client, args)
{	
	if(0 < client <= MaxClients)
	{
		if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
			ReplyToCommand(client, "[SM] Look in your console for timer command list.");
		
		decl String:sCommand[32];
		GetCmdArg(0, sCommand, sizeof(sCommand));
		
		if(args == 0)
		{
			ReplyToCommand(client, "[SM] %s 10 for the next page.", sCommand);
			for(new i=0; i<10; i++)
			{
				PrintToConsole(client, g_CommandList[i]);
			}
		}
		else
		{
			decl String:arg[250];
			GetCmdArgString(arg, sizeof(arg));
			new iStart = StringToInt(arg);
			new iSize  = sizeof(g_CommandList);
			
			if(iStart < (iSize-10))
			{
				ReplyToCommand(client, "[SM] %s %d for the next page.", sCommand, iStart+10);
			}
			
			for(new i=iStart; i < (iStart+10) && (i < iSize); i++)
			{
				PrintToConsole(client, g_CommandList[i]);
			}
		}
	}
	else if(client == 0)
	{
		new iSize = sizeof(g_CommandList);
		for(new i=0; i<iSize; i++)
		{
			PrintToServer(g_CommandList[i]);
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Search(client, args)
{
	if(args > 0)
	{
		decl String:sArgString[255];
		GetCmdArgString(sArgString, sizeof(sArgString));
		
		new iSize = sizeof(g_CommandList);
		for(new i=0; i<iSize; i++)
		{
			if(StrContains(g_CommandList[i], sArgString, false) != -1)
			{
				PrintToConsole(client, g_CommandList[i]);
			}
		}
	}
	else
	{
		PrintColorText(client, "%s%ssm_search must have a string to search with after it.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Native_IsSpamming(Handle:plugin, numParams)
{
	return g_IsSpamming[GetNativeCell(1)];
}

public Native_SetIsSpamming(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	g_IsSpamming[client] = true;
	CreateTimer(GetNativeCell(2), Timer_SpamFilter, client);
}

public Action:Timer_SpamFilter(Handle:timer, any:client)
{
	g_IsSpamming[client] = false;
}