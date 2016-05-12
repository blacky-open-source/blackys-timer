#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "[bTimes] core",
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
#include <scp>

new 	Handle:g_hCommandList,
	bool:g_bCommandListLoaded;

new Handle:g_DB = INVALID_HANDLE;

new 	String:g_sMapName[64],
	g_PlayerID[MAXPLAYERS+1],
	Handle:g_MapList;
	
new	Float:g_fSpamTime[MAXPLAYERS+1];
	
// Playtimes
new	Float:g_JoinStart[MAXPLAYERS+1];
new	Float:g_MapStart;
	
// Chat
new 	String:g_msg_start[128] = {""};
new 	String:g_msg_varcol[128] = {"\x07B4D398"};
new 	String:g_msg_textcol[128] = {"\x01"};

// Forwards
new	Handle:g_fwdMapIDPostCheck,
	Handle:g_fwdPlayerIDLoaded;

// UserID/PlayerID array
new	Handle:g_hTriePlayerID;

public OnPluginStart()
{
	// Connect
	DB_Connect();
	
	// Events
	HookEvent("player_changename", Event_PlayerChangeName, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	
	// Commands
	RegConsoleCmdEx("sm_mostplayed", SM_TopMaps, "Displays the most played maps");
	RegConsoleCmdEx("sm_lastplayed", SM_LastPlayed, "Shows the last played maps");
	RegConsoleCmdEx("sm_thelp", SM_THelp, "Shows the timer commands.");
	RegConsoleCmdEx("sm_commands", SM_THelp, "Shows the timer commands.");
	RegConsoleCmdEx("sm_search", SM_Search, "Search the command list for the given string of text.");
	RegConsoleCmdEx("sm_changes", SM_Changes, "See the changes in the newer timer version.");
	
	// Init userid array	
	g_hTriePlayerID = CreateTrie();
}

// Create natives
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("GetClientID", Native_GetClientID);
	CreateNative("GetPlaytime", Native_GetPlaytime);
	CreateNative("IsSpamming", Native_IsSpamming);
	CreateNative("SetIsSpamming", Native_SetIsSpamming);
	CreateNative("RegisterCommand", Native_RegisterCommand);
	
	g_fwdMapIDPostCheck = CreateGlobalForward("OnMapIDPostCheck", ET_Event);
	g_fwdPlayerIDLoaded = CreateGlobalForward("OnPlayerIDLoaded", ET_Event, Param_Cell);
	
	return APLRes_Success;
}

public OnMapStart()
{
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	
	g_MapStart = GetEngineTime();
	
	g_MapList = ReadMapList();
	
	// Creates map if it doesn't exist, sets map as recently played, and loads map playtime
	CreateCurrentMapID();
}

public OnMapEnd()
{
	DB_SaveMapPlaytime();
	DB_SetMapLastPlayed();
}

public OnClientDisconnect(client)
{
	// Save player's play time
	if(!IsFakeClient(client))
	{
		DB_SavePlaytime(client);
	}
	
	// Reset the playerid for the client index
	g_PlayerID[client] = 0;
}

public bool:OnClientConnect(client)
{
	g_PlayerID[client] = 0;
	
	new userid = GetClientUserId(client);
	decl String:sUserID[32];
	Format(sUserID, sizeof(sUserID), "%d", userid);
	
	// Check for any existing player ids for this player with their userid
	if(GetTrieValue(g_hTriePlayerID, sUserID, g_PlayerID[client]))
	{
		// Start forward to notify other plugins that a playerid was found for the client
		Call_StartForward(g_fwdPlayerIDLoaded);
		Call_PushCell(client);
		Call_Finish();
	}
	
	return true;
}

public OnClientPutInServer(client)
{
	g_JoinStart[client] = GetEngineTime();
}

public OnClientAuthorized(client)
{
	if(!IsFakeClient(client) && (g_PlayerID[client] == 0))
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
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(0 < client <= MaxClients)
	{
		if(IsClientInGame(client))
		{
			if(GetEventInt(event, "oldteam") == 0)
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

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	if(IsChatTrigger())
	{
		return Plugin_Stop;
	}
	else if(StrEqual(message, "spawn") || StrEqual(message, "restart") || StrEqual(message, "respawn"))
	{
		FakeClientCommand(author, "sm_r");
		return Plugin_Stop;
	}
	else if(StrEqual(message, "rank") || StrEqual(message, "brank") || StrEqual(message, "rankw") || StrEqual(message, "ranksw") || StrEqual(message, "rankn"))
	{
		FakeClientCommand(author, "sm_%s", message);
		return Plugin_Stop;
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
						
						if(FindStringInArray(g_MapList, mapname) != -1)
						{
							FormatPlayerTime(float(iTime), timeplayed, sizeof(timeplayed), false, 1);
							SplitString(timeplayed, ".", timeplayed, sizeof(timeplayed));
							Format(display, sizeof(display), "#%d: %s - %s", ++j, mapname, timeplayed);
							
							AddMenuItem(menu, display, display);
						}
					}
				}
				
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
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		FakeClientCommand(param1, "sm_nominate %s", info);
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
					
					if(FindStringInArray(g_MapList, sMapName) != -1)
					{
						FormatTime(sDate, sizeof(sDate), "%x", iTime);
						FormatTime(sTimeOfDay, sizeof(sTimeOfDay), "%X", iTime);
						
						Format(display, sizeof(display), "%s - %s - %s", sMapName, sDate, sTimeOfDay);
						
						AddMenuItem(menu, display, display);
					}
				}
			}
			
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
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		FakeClientCommand(param1, "sm_nominate %s", info);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:Event_PlayerChangeName(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	decl String:sName[MAX_NAME_LENGTH];
	GetEventString(event, "newname", sName, sizeof(sName));
	
	decl String:sEscapedName[2 * MAX_NAME_LENGTH + 1];
	SQL_LockDatabase(g_DB);
	SQL_EscapeString(g_DB, sName, sEscapedName, sizeof(sEscapedName));
	SQL_UnlockDatabase(g_DB);
	
	decl String:sAuth[32];
	GetClientAuthString(client, sAuth, sizeof(sAuth));
	
	decl String:query[128];
	Format(query, sizeof(query), "UPDATE players SET User='%s' WHERE SteamID='%s'", sEscapedName, sAuth);
	SQL_TQuery(g_DB, Event_PlayerChangeName_Callback, query);
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
	ShowMOTDPanel(client, "Timer changelog", "http://textuploader.com/14vc/raw", MOTDPANEL_TYPE_URL);
	
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
		decl String:query[512];
		
		// Create maps table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS maps(MapID INTEGER NOT NULL AUTO_INCREMENT, MapName TEXT, MapPlaytime INTEGER NOT NULL, LastPlayed INTEGER NOT NULL, PRIMARY KEY (MapID))");
		SQL_TQuery(g_DB, DB_Connect_Callback, query);
		
		// Create zones table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS zones(MapID INTEGER, Type INTEGER, point00 REAL, point01 REAL, point02 REAL, point10 REAL, point11 REAL, point12 REAL)");
		SQL_TQuery(g_DB, DB_Connect_Callback, query);
		
		// Create players table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS players(PlayerID INTEGER NOT NULL AUTO_INCREMENT, SteamID TEXT, User Text, Playtime INTEGER NOT NULL, ccname TEXT, ccmsgcol TEXT, ccuse INTEGER, PRIMARY KEY (PlayerID))");
		SQL_TQuery(g_DB, DB_Connect_Callback, query);
		
		// Create times table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS times(rownum INTEGER NOT NULL AUTO_INCREMENT, MapID INTEGER, Type INTEGER, Style INTEGER, PlayerID INTEGER, Time REAL, Jumps INTEGER, Strafes INTEGER, Points REAL, Timestamp INTEGER, Sync REAL, SyncTwo REAL, PRIMARY KEY (rownum))");
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
	FormatEx(query, sizeof(query), "INSERT INTO maps (MapName) SELECT * FROM (SELECT '%s') AS tmp WHERE NOT EXISTS (SELECT MapName FROM maps WHERE MapName = '%s') LIMIT 1",
		g_sMapName,
		g_sMapName);
	SQL_TQuery(g_DB, DB_CreateCurrentMapID_Callback1, query);
}

public DB_CreateCurrentMapID_Callback1(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(SQL_GetAffectedRows(hndl) > 0)
		{
			LogMessage("MapID for %s created (%d)", g_sMapName, SQL_GetInsertId(hndl));
		}
		
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
	decl String:sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));
	
	decl String:sEscapedName[(2 * MAX_NAME_LENGTH) + 1];
	SQL_LockDatabase(g_DB);
	SQL_EscapeString(g_DB, sName, sEscapedName, sizeof(sEscapedName));
	SQL_UnlockDatabase(g_DB);
	
	decl String:sAuth[32];
	GetClientAuthString(client, sAuth, sizeof(sAuth));
	
	decl String:query[512];
	FormatEx(query, sizeof(query), "INSERT INTO players (SteamID, User) SELECT * FROM (SELECT '%s', '%s') AS tmp WHERE NOT EXISTS (SELECT SteamID FROM players WHERE SteamID = '%s') LIMIT 1",
		sAuth,
		sEscapedName,
		sAuth);
	SQL_TQuery(g_DB, DB_CreatePlayerID2_Callback1, query, GetClientUserId(client));
}

public DB_CreatePlayerID2_Callback1(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl != INVALID_HANDLE)
	{
		new client = GetClientOfUserId(userid);
		
		if(client != 0)
		{
			if(SQL_GetAffectedRows(hndl) == 1)
			{
				g_PlayerID[client] = SQL_GetInsertId(hndl);
				
				// Start forward to notify other plugins that a player's id was found
				Call_StartForward(g_fwdPlayerIDLoaded);
				Call_PushCell(client);
				Call_Finish();
			}
			else
			{
				decl String:sAuth[32];
				GetClientAuthString(client, sAuth, sizeof(sAuth));
				
				decl String:query[512];
				FormatEx(query, sizeof(query), "SELECT PlayerID FROM players WHERE SteamID = '%s'",
					sAuth);
					
				SQL_TQuery(g_DB, DB_CreatePlayerID2_Callback2, query, GetClientUserId(client));
			}
		}
	}
	else
	{
		LogError(error);
	}
}

public DB_CreatePlayerID2_Callback2(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl != INVALID_HANDLE)
	{
		new client = GetClientOfUserId(userid);
		
		if(client != 0)
		{
			if(SQL_GetRowCount(hndl) > 0)
			{
				SQL_FetchRow(hndl);
				
				g_PlayerID[client] = SQL_FetchInt(hndl, 0);
				
				// Start forward to notify other plugins that a player's id was found
				Call_StartForward(g_fwdPlayerIDLoaded);
				Call_PushCell(client);
				Call_Finish();
			}
		}
	}
	else
	{
		LogError(error);
	}
}

public Native_GetClientID(Handle:plugin, numParams)
{
	return g_PlayerID[GetNativeCell(1)];
}

DB_SavePlaytime(client)
{
	new PlayerID = GetPlayerID(client);
	if(PlayerID != 0)
	{
		new Playtime = RoundToFloor(GetEngineTime() - g_JoinStart[client]);
		
		decl String:query[128];
		Format(query, sizeof(query), "UPDATE players SET Playtime=(SELECT Playtime FROM (SELECT * FROM players) AS x WHERE PlayerID=%d)+%d WHERE PlayerID=%d",
			PlayerID,
			Playtime,
			PlayerID);
			
		SQL_TQuery(g_DB, DB_SavePlaytime_Callback, query);
	}
}

public DB_SavePlaytime_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

public Native_GetPlaytime(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if(g_PlayerID[client] != 0)
	{
		return _:(GetEngineTime()-g_JoinStart[client]);
	}
	
	return _:0.0;
}

DB_SaveMapPlaytime()
{
	decl String:query[256];

	Format(query, sizeof(query), "UPDATE maps SET MapPlaytime=(SELECT MapPlaytime FROM (SELECT * FROM maps) AS x WHERE MapName='%s' LIMIT 0, 1)+%d WHERE MapName='%s'",
		g_sMapName,
		RoundToFloor(GetEngineTime()-g_MapStart),
		g_sMapName);
		
	SQL_TQuery(g_DB, DB_SaveMapPlaytime_Callback, query);
}

public DB_SaveMapPlaytime_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

DB_SetMapLastPlayed()
{
	decl String:query[128];
	
	Format(query, sizeof(query), "UPDATE maps SET LastPlayed=%d WHERE MapName='%s'",
		GetTime(),
		g_sMapName);
		
	SQL_TQuery(g_DB, DB_SetMapLastPlayed_Callback, query);
}

public DB_SetMapLastPlayed_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError(error);
}

public Action:SM_THelp(client, args)
{	
	new iSize = GetArraySize(g_hCommandList);
	decl String:sResult[256];
	
	if(0 < client <= MaxClients)
	{
		if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
			ReplyToCommand(client, "[SM] Look in your console for timer command list.");
		
		decl String:sCommand[256];
		GetCmdArg(0, sCommand, sizeof(sCommand));
		
		if(args == 0)
		{
			ReplyToCommand(client, "[SM] %s 10 for the next page.", sCommand);
			for(new i=0; i<10 && i < iSize; i++)
			{
				GetArrayString(g_hCommandList, i, sResult, sizeof(sResult));
				PrintToConsole(client, sResult);
			}
		}
		else
		{
			decl String:arg[250];
			GetCmdArgString(arg, sizeof(arg));
			new iStart = StringToInt(arg);
			
			if(iStart < (iSize-10))
			{
				ReplyToCommand(client, "[SM] %s %d for the next page.", sCommand, iStart+10);
			}
			
			for(new i=iStart; i < (iStart+10) && (i < iSize); i++)
			{
				GetArrayString(g_hCommandList, i, sResult, sizeof(sResult));
				PrintToConsole(client, sResult);
			}
		}
	}
	else if(client == 0)
	{
		for(new i=0; i<iSize; i++)
		{
			GetArrayString(g_hCommandList, i, sResult, sizeof(sResult));
			PrintToServer(sResult);
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Search(client, args)
{
	if(args > 0)
	{
		decl String:sArgString[255], String:sResult[256];
		GetCmdArgString(sArgString, sizeof(sArgString));
		
		new iSize = GetArraySize(g_hCommandList);
		for(new i=0; i<iSize; i++)
		{
			GetArrayString(g_hCommandList, i, sResult, sizeof(sResult));
			if(StrContains(sResult, sArgString, false) != -1)
			{
				PrintToConsole(client, sResult);
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
	return GetEngineTime() < g_fSpamTime[GetNativeCell(1)];
}

public Native_SetIsSpamming(Handle:plugin, numParams)
{
	g_fSpamTime[GetNativeCell(1)] = Float:GetNativeCell(2) + GetEngineTime();
}

public Native_RegisterCommand(Handle:plugin, numParams)
{
	if(g_bCommandListLoaded == false)
	{
		g_hCommandList = CreateArray(ByteCountToCells(255));
		g_bCommandListLoaded = true;
	}
	
	decl String:sListing[256], String:sCommand[32], String:sDesc[224];
	
	GetNativeString(1, sCommand, sizeof(sCommand));
	GetNativeString(2, sDesc, sizeof(sDesc));
	
	FormatEx(sListing, sizeof(sListing), "%s - %s", sCommand, sDesc);
	
	decl String:sIndex[256];
	new idx, idxlen, listlen = strlen(sListing), iSize = GetArraySize(g_hCommandList), bool:bIdxFound;
	for(; idx < iSize; idx++)
	{
		GetArrayString(g_hCommandList, idx, sIndex, sizeof(sIndex));
		idxlen = strlen(sIndex);
		
		for(new cmpidx = 0; cmpidx < listlen && cmpidx < idxlen; cmpidx++)
		{
			if(sListing[cmpidx] < sIndex[cmpidx])
			{
				bIdxFound = true;
				break;
			}
			else if(sListing[cmpidx] > sIndex[cmpidx])
			{
				break;
			}
		}
		
		if(bIdxFound == true)
			break;
	}
	
	if(idx >= iSize)
		ResizeArray(g_hCommandList, idx + 1);
	else
		ShiftArrayUp(g_hCommandList, idx);
	
	SetArrayString(g_hCommandList, idx, sListing);
}