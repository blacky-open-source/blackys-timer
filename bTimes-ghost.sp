#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "[bTimes] ghost",
	author = "blacky",
	description = "Shows a bot that replays the top times",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <smlib/weapons>
#include <cstrike>
#include <bTimes-timer>
#include <bTimes-zones>

new	String:g_sMapName[64],
	Handle:g_DB;

new 	Handle:g_frame[MAXPLAYERS+1],
	bool:g_bUsedFrame[MAXPLAYERS + 1];

new 	Handle:g_hGhost[2][MAX_STYLES],
	g_ghost[2][MAX_STYLES],
	g_ghostframe[2][MAX_STYLES],
	bool:g_GhostPaused[2][MAX_STYLES],
	String:g_sGhost[2][MAX_STYLES][48],
	g_GhostPlayerID[2][MAX_STYLES],
	Float:g_fGhostTime[2][MAX_STYLES],
	Float:g_fPauseTime[2][MAX_STYLES],
	g_iBotQuota,
	bool:g_bGhostLoadedOnce[2][MAX_STYLES];
	
new 	Float:g_starttime[2][MAX_STYLES];

// Cvars
new 	Handle:g_hSaveGhost[2][MAX_STYLES],
	Handle:g_hUseGhost[2][MAX_STYLES],
	Handle:g_hGhostClanTag[2][MAX_STYLES],
	Handle:g_hGhostWeapon[2][MAX_STYLES],
	Handle:g_hGhostStartPauseTime,
	Handle:g_hGhostEndPauseTime;
	
// Weapon control
new	bool:g_bNewWeapon;
	
public OnPluginStart()
{	
	// Connect to the database
	DB_Connect();
	
	decl String:sTypeAbbr[8], String:sType[16], String:sStyleAbbr[8], String:sStyle[16], String:sTypeStyleAbbr[24], String:sCvar[32], String:sDesc[128], String:sValue[32];
	
	for(new Type = 0; Type < MAX_TYPES; Type++)
	{
		GetTypeName(Type, sType, sizeof(sType));
		GetTypeAbbr(Type, sTypeAbbr, sizeof(sTypeAbbr));
		
		for(new Style = 0; Style < MAX_STYLES; Style++)
		{
			// Don't create cvars for styles on bonus except normal style
			if(Type == TIMER_BONUS && Style != STYLE_NORMAL)
				continue;
			
			GetStyleName(Style, sStyle, sizeof(sStyle));
			GetStyleAbbr(Style, sStyleAbbr, sizeof(sStyleAbbr));
			
			Format(sTypeStyleAbbr, sizeof(sTypeStyleAbbr), "%s%s", sTypeAbbr, sStyleAbbr);
			StringToUpper(sTypeStyleAbbr);
			
			Format(sCvar, sizeof(sCvar), "timer_useghost_%s%s", sTypeAbbr, sStyleAbbr);
			Format(sDesc, sizeof(sDesc), "Use ghost for %s style on %s timer?", sStyle, sType);
			g_hUseGhost[Type][Style] = CreateConVar(sCvar, "1", sDesc, 0, true, 0.0, true, 1.0);
			
			Format(sCvar, sizeof(sCvar), "timer_saveghost_%s%s", sTypeAbbr, sStyleAbbr);
			Format(sDesc, sizeof(sDesc), "Save ghost for %s style on %s timer?", sStyle, sType);
			g_hSaveGhost[Type][Style] = CreateConVar(sCvar, "1", sDesc, 0, true, 0.0, true, 1.0);
			
			Format(sCvar, sizeof(sCvar), "timer_ghosttag_%s%s", sTypeAbbr, sStyleAbbr);
			Format(sDesc, sizeof(sDesc), "The replay bot's clan tag for the scoreboard (%s style on %s timer)", sStyle, sType);
			Format(sValue, sizeof(sValue), "Ghost :: %s", sTypeStyleAbbr);
			g_hGhostClanTag[Type][Style] = CreateConVar(sCvar, sValue, sDesc);
			
			Format(sCvar, sizeof(sCvar), "timer_ghostweapon_%s%s", sTypeAbbr, sStyleAbbr);
			Format(sDesc, sizeof(sDesc), "The weapon the replay bot will always use (%s style on %s timer)", sStyle, sType);
			g_hGhostWeapon[Type][Style] = CreateConVar(sCvar, "weapon_glock", sDesc, 0, true, 0.0, true, 1.0);
			
			HookConVarChange(g_hUseGhost[Type][Style], OnUseGhostChanged);
			HookConVarChange(g_hGhostWeapon[Type][Style], OnGhostWeaponChanged);
		}
	}
	
	g_hGhostStartPauseTime = CreateConVar("timer_ghoststartpause", "5.0", "How long the ghost will pause before starting its run.");
	g_hGhostEndPauseTime   = CreateConVar("timer_ghostendpause", "2.0", "How long the ghost will pause after it finishes its run.");
	
	AutoExecConfig(true, "ghost", "timer");
	
	// Events
	HookEvent("player_changename", Event_PlayerChangeName);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	// Create admin command that deletes the ghost
	RegAdminCmd("sm_deleteghost", SM_DeleteGhost, ADMFLAG_CHEATS, "Deletes the ghost.");
	
	new	Handle:hBotDontShoot = FindConVar("bot_dont_shoot");
	SetConVarFlags(hBotDontShoot, GetConVarFlags(hBotDontShoot) & ~FCVAR_CHEAT);
}

public OnMapStart()
{	
	// Recreate the array since it's a new map
	
	for(new Type=0; Type < 2; Type++)
	{
		for(new Style=0; Style < MAX_STYLES; Style++)
		{
			if(g_bGhostLoadedOnce[Type][Style] == true)
				ClearArray(g_hGhost[Type][Style]);
			else
				g_hGhost[Type][Style] = CreateArray(6);
			
			g_ghost[Type][Style]  = 0;
			
			g_fGhostTime[Type][Style] = 0.0;
			
			g_ghostframe[Type][Style] = 0;
			
			Format(g_sGhost[Type][Style], 48, "Unknown");
		}
	}
	
	
	// Get map name to use the database
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	
	// Check path to folder that holds all the ghost data
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes");
	if(!DirExists(sPath))
	{
		// Create ghost data directory if it doesn't exist
		CreateDirectory(sPath, 511);
	}
	
	LoadGhost();
	
	// Timer to check ghost things such as clan tag
	CreateTimer(0.1, GhostCheck, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public OnConfigsExecuted()
{
	CalculateBotQuota();
}

public OnUseGhostChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	CalculateBotQuota();
}

public OnGhostWeaponChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	for(new Type=0; Type<2; Type++)
	{
		for(new Style=0; Style < MAX_STYLES; Style++)
		{
			if(0 < g_ghost[Type][Style] <= MaxClients)
			{
				if(g_hGhostWeapon[Type][Style] == convar)
				{
					CheckWeapons(Type, Style);
				}
			}
		}
	}
}

public OnMapEnd()
{
	// Remove ghost to get a clean start next map
	ServerCommand("bot_kick all");
	
	for(new Type=0; Type<2; Type++)
	{
		for(new Style=0; Style < MAX_STYLES; Style++)
		{
			g_ghost[Type][Style] = 0;
		}
	}
}

public OnClientPutInServer(client)
{
	if(IsFakeClient(client))
	{
		SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
	}
	else
	{
		// Reset player recorded movement
		if(g_bUsedFrame[client] == false)
		{
			g_frame[client] = CreateArray(6, 0);
			g_bUsedFrame[client] = true;
		}
		else
		{
			ClearArray(g_frame[client]);
		}
	}
}

public OnEntityCreated(entity, const String:classname[])
{
	if(StrContains(classname, "trigger_", false) != -1)
	{
		SDKHook(entity, SDKHook_StartTouch, OnTrigger);
		SDKHook(entity, SDKHook_EndTouch, OnTrigger);
		SDKHook(entity, SDKHook_Touch, OnTrigger);
	}
}
 
public Action:OnTrigger(entity, other)
{
	if(other >= 1 && other <= MaxClients && IsFakeClient(other))
	{
		return Plugin_Handled;
	}
   
	return Plugin_Continue;
}

public OnPlayerIDLoaded(client)
{
	new PlayerID = GetPlayerID(client);
	
	for(new Type=0; Type<2; Type++)
	{
		for(new Style=0; Style<MAX_STYLES; Style++)
		{
			if(PlayerID == g_GhostPlayerID[Type][Style])
			{
				decl String:sTime[32];
				FormatPlayerTime(g_fGhostTime[Type][Style], sTime, sizeof(sTime), false, 0);
				
				decl String:sName[20];
				GetClientName(client, sName, sizeof(sName));
				
				FormatEx(g_sGhost[Type][Style], 48, "%s - %s", sName, sTime);
			}
		}
	}
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen)
{
	// Find out if it's the bot added from another time
	if(IsFakeClient(client) && !IsClientSourceTV(client))
	{
		for(new Type = 0; Type < MAX_TYPES; Type++)
		{
			for(new Style = 0; Style < MAX_STYLES; Style++)
			{
				if(Type == TIMER_BONUS && Style != STYLE_NORMAL)
					continue;
				
				if(g_ghost[Type][Style] == 0 && GetConVarBool(g_hUseGhost[Type][Style]) && IsStyleAllowed(Style))
				{
					g_ghost[Type][Style] = client;
					
					return true;
				}
				
			}
		}
	}
	return true;
}

public OnClientDisconnect(client)
{
	// Prevent players from becoming the ghost.
	if(IsFakeClient(client))
	{
		for(new Type=0; Type<2; Type++)
		{
			for(new Style=0; Style<MAX_STYLES; Style++)
			{
				if(client == g_ghost[Type][Style])
				{
					g_ghost[Type][Style] = 0;
					break;
				}
			}
		}
	}
}

public OnTimesDeleted(Type, Style, RecordOne, RecordTwo)
{
	if(RecordOne <= 1 <= RecordTwo)
	{
		DeleteGhost(Type, Style);
	}
}

public Action:Event_PlayerChangeName(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsClientInGame(client))
	{
		new PlayerID = GetPlayerID(client);
		
		if(PlayerID != 0)
		{
			for(new Type = 0; Type < MAX_TYPES; Type++)
			{
				for(new Style=0; Style<MAX_STYLES; Style++)
				{
					if(Type == TIMER_BONUS && Style != STYLE_NORMAL)
						continue;
					
					if(PlayerID == g_GhostPlayerID[Type][Style])
					{
						decl String:sNewName[20];
						GetEventString(event, "newname", sNewName, sizeof(sNewName));
						
						decl String:sTime[32];
						FormatPlayerTime(g_fGhostTime[Type][Style], sTime, sizeof(sTime), false, 0);
						
						Format(g_sGhost[Type][Style], 48, "%s - %s", sNewName, sTime);
					}
				}
			}
		}
	}
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsFakeClient(client))
	{
		for(new Type = 0; Type < MAX_TYPES; Type++)
		{
			for(new Style = 0; Style < MAX_STYLES; Style++)
			{
				if(Type == TIMER_BONUS && Style != STYLE_NORMAL)
					continue;
				
				if(g_ghost[Type][Style] == client)
				{
					CreateTimer(0.1, Timer_CheckWeapons, client);
				}
			}
		}
	}
}

public Action:Timer_CheckWeapons(Handle:timer, any:client)
{
	for(new Type = 0; Type < MAX_TYPES; Type++)
	{
		for(new Style = 0; Style < MAX_STYLES; Style++)
		{
			if(Type == TIMER_BONUS && Style != STYLE_NORMAL)
				continue;
			
			if(g_ghost[Type][Style] == client)
			{
				CheckWeapons(Type, Style);
			}
		}
	}
}

CheckWeapons(Type, Style)
{
	for(new i = 0; i < 8; i++)
	{
		FakeClientCommand(g_ghost[Type][Style], "drop");
		
		decl String:sWeapon[32];
		GetConVarString(g_hGhostWeapon[Type][Style], sWeapon, sizeof(sWeapon));
		
		g_bNewWeapon = true;
		GivePlayerItem(g_ghost[Type][Style], sWeapon);
	}
}

public Action:SM_DeleteGhost(client, args)
{
	OpenDeleteGhostMenu(client);
	
	// Log this because it's something that can be abused
	LogMessage("%L deleted the ghost", client);
	
	return Plugin_Handled;
}

OpenDeleteGhostMenu(client)
{
	new Handle:menu = CreateMenu(Menu_DeleteGhost);
	
	SetMenuTitle(menu, "Select ghost to delete\n ");
	
	decl String:sType[16], String:sStyle[16], String:sTypeStyle[32], String:sInfo[8];
	
	for(new Type = 0; Type < MAX_TYPES; Type++)
	{
		GetTypeName(Type, sType, sizeof(sType));
		
		for(new Style=0; Style < MAX_STYLES; Style++)
		{
			if(Type == TIMER_BONUS && Style != STYLE_NORMAL)
				continue;
			
			GetStyleName(Style, sStyle, sizeof(sStyle));
			
			Format(sInfo, sizeof(sInfo), "%d;%d", Type, Style);
			Format(sTypeStyle, sizeof(sTypeStyle), "%s %s", sType, sStyle);
			
			AddMenuItem(menu, sInfo, sTypeStyle);
		}
	}
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_DeleteGhost(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[16], String:sTypeStyle[2][8];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrContains(info, ";") != -1)
		{
			ExplodeString(info, ";", sTypeStyle, 2, 8);
			
			DeleteGhost(StringToInt(sTypeStyle[0]), StringToInt(sTypeStyle[1]));
			
			LogMessage("%L deleted the ghost", param1);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:GhostCheck(Handle:timer, any:data)
{
	new Handle:hBotQuota = FindConVar("bot_quota");
	new iBotQuota = GetConVarInt(hBotQuota);
	
	if(iBotQuota != g_iBotQuota)
		ServerCommand("bot_quota %d", g_iBotQuota);
	
	CloseHandle(hBotQuota);
	
	for(new Type=0; Type<2; Type++)
	{
		for(new Style=0; Style<MAX_STYLES; Style++)
		{
			if(Type == TIMER_BONUS && Style != STYLE_NORMAL)
				continue;
			
			if(g_ghost[Type][Style] != 0)
			{
				if(IsClientInGame(g_ghost[Type][Style]))
				{
					// Check clan tag
					decl String:sClanTag[64], String:sCvarClanTag[64];
					CS_GetClientClanTag(g_ghost[Type][Style], sClanTag, sizeof(sClanTag));
					GetConVarString(g_hGhostClanTag[Type][Style], sCvarClanTag, sizeof(sCvarClanTag));
					
					if(!StrEqual(sCvarClanTag, sClanTag))
					{
						CS_SetClientClanTag(g_ghost[Type][Style], sCvarClanTag);
					}
					
					// Check name
					if(strlen(g_sGhost[Type][Style]) > 0)
					{
						decl String:sGhostname[48];
						GetClientName(g_ghost[Type][Style], sGhostname, sizeof(sGhostname));
						if(!StrEqual(sGhostname, g_sGhost[Type][Style]))
						{
							SetClientInfo(g_ghost[Type][Style], "name", g_sGhost[Type][Style]);
						}
					}
					
					// Check if ghost is dead
					if(!IsPlayerAlive(g_ghost[Type][Style]))
					{
						CS_RespawnPlayer(g_ghost[Type][Style]);
					}
				
					// Display ghost's current time to spectators
					new iSize = GetArraySize(g_hGhost[Type][Style]);
					for(new client=1; client <= MaxClients; client++)
					{
						if(IsClientInGame(client))
						{
							if(!IsPlayerAlive(client))
							{
								new target 	 = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
								new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
								
								if(target == g_ghost[Type][Style] && (ObserverMode == 4 || ObserverMode == 5))
								{
									if(!g_GhostPaused[Type][Style] && (0 < g_ghostframe[Type][Style] < iSize))
									{
										new Float:time = GetEngineTime() - g_starttime[Type][Style];
										decl String:sTime[32];
										FormatPlayerTime(time, sTime, sizeof(sTime), false, 0);
										PrintHintText(client, "Replay\n%s", sTime);
									}
								}
							}
						}
					}
					
					new weaponIndex = GetEntPropEnt(g_ghost[Type][Style], Prop_Send, "m_hActiveWeapon");
					
					if(weaponIndex != -1)
					{
						new ammo = Weapon_GetPrimaryClip(weaponIndex);
						
						if(ammo < 1)
							Weapon_SetPrimaryClip(weaponIndex, 9999);
					}
				}
			}
		}
	}
}

public Action:Hook_WeaponCanUse(client, weapon)
{
	if(g_bNewWeapon == false)
		return Plugin_Handled;
	
	g_bNewWeapon = false;
	
	return Plugin_Continue;
}

CalculateBotQuota()
{
	g_iBotQuota = 0;
	
	for(new Type = 0; Type < MAX_TYPES; Type++)
	{
		for(new Style=0; Style<MAX_STYLES; Style++)
		{
			if(Type == TIMER_BONUS && Style != STYLE_NORMAL)
				continue;
			
			if(GetConVarBool(g_hUseGhost[Type][Style]) && IsStyleAllowed(Style))
			{
				g_iBotQuota++;
				
				if(!g_ghost[Type][Style])
					ServerCommand("bot_add");
			}
			else if(g_ghost[Type][Style])
				KickClient(g_ghost[Type][Style]);
		}
	}
	
	new Handle:hBotQuota = FindConVar("bot_quota");
	new iBotQuota = GetConVarInt(hBotQuota);
	
	if(iBotQuota != g_iBotQuota)
		ServerCommand("bot_quota %d", g_iBotQuota);
}

LoadGhost()
{
	// Rename old version files
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s.rec", g_sMapName);
	if(FileExists(sPath))
	{
		decl String:sPathTwo[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPathTwo, sizeof(sPathTwo), "data/btimes/%s_0_0.rec", g_sMapName);
		RenameFile(sPathTwo, sPath);
	}
	
	for(new Type=0; Type<2; Type++)
	{
		for(new Style=0; Style<MAX_STYLES; Style++)
		{
			if(Type == TIMER_BONUS && Style != STYLE_NORMAL)
				continue;
			
			g_fGhostTime[Type][Style] = 0.0;
			g_GhostPlayerID[Type][Style] = -1;
			
			BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d.rec", g_sMapName, Type, Style);
			
			if(FileExists(sPath))
			{
				// Open file for reading
				new Handle:hFile = OpenFile(sPath, "r");
				
				// Load all data into the ghost handle
				new String:line[512], String:expLine[6][64], String:expLine2[2][10];
				new iSize = 0;
				
				ReadFileLine(hFile, line, sizeof(line));
				ExplodeString(line, "|", expLine2, 2, 10);
				g_GhostPlayerID[Type][Style] = StringToInt(expLine2[0]);
				g_fGhostTime[Type][Style]    = StringToFloat(expLine2[1]);
				
				while(!IsEndOfFile(hFile))
				{
					ReadFileLine(hFile, line, sizeof(line));
					ExplodeString(line, "|", expLine, 6, 64);
					
					iSize = GetArraySize(g_hGhost[Type][Style])+1;
					ResizeArray(g_hGhost[Type][Style], iSize);
					SetArrayCell(g_hGhost[Type][Style], iSize-1, StringToFloat(expLine[0]), 0);
					SetArrayCell(g_hGhost[Type][Style], iSize-1, StringToFloat(expLine[1]), 1);
					SetArrayCell(g_hGhost[Type][Style], iSize-1, StringToFloat(expLine[2]), 2);
					SetArrayCell(g_hGhost[Type][Style], iSize-1, StringToFloat(expLine[3]), 3);
					SetArrayCell(g_hGhost[Type][Style], iSize-1, StringToFloat(expLine[4]), 4);
					SetArrayCell(g_hGhost[Type][Style], iSize-1, StringToInt(expLine[5]), 5);
				}
				CloseHandle(hFile);
				
				g_bGhostLoadedOnce[Type][Style] = true;
				
				new Handle:pack = CreateDataPack();
				WritePackCell(pack, Type);
				WritePackCell(pack, Style);
				WritePackString(pack, g_sMapName);
				
				// Query for name/time of player the ghost is following the path of
				decl String:query[512];
				Format(query, sizeof(query), "SELECT t2.User, t1.Time FROM times AS t1, players AS t2 WHERE t1.PlayerID=t2.PlayerID AND t1.PlayerID=%d AND t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.Type=%d AND t1.Style=%d",
					g_GhostPlayerID[Type][Style],
					g_sMapName,
					Type,
					Style);
				SQL_TQuery(g_DB, LoadGhost_Callback, query, pack);
			}
		}
	}
}

public LoadGhost_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new Type  = ReadPackCell(data);
		new Style = ReadPackCell(data);
		
		decl String:sMapName[64];
		ReadPackString(data, sMapName, sizeof(sMapName));
		
		if(StrEqual(g_sMapName, sMapName))
		{
			SQL_FetchRow(hndl);
			
			if(SQL_GetRowCount(hndl) != 0)
			{
				decl String:name[20];
				SQL_FetchString(hndl, 0, name, sizeof(name));
				
				decl String:sTime[32];
				
				if(g_fGhostTime[Type][Style] == 0.0)
					g_fGhostTime[Type][Style] = SQL_FetchFloat(hndl, 1);
				
				FormatPlayerTime(g_fGhostTime[Type][Style], sTime, sizeof(sTime), false, 0);
				
				Format(g_sGhost[Type][Style], 48, "%s - %s", name, sTime);
			}
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

public OnTimerStart_Post(client, Type, Style)
{
	// Reset saved ghost data
	ClearArray(g_frame[client]);
}

public OnTimerFinished(client, Float:Time, Type, Style)
{
	if(Time < g_fGhostTime[Type][Style] || g_fGhostTime[Type][Style] == 0.0)
	{
		SaveGhost(client, Time, Type, Style);
	}
}

SaveGhost(client, Float:Time, Type, Style)
{
	g_fGhostTime[Type][Style] = Time;
	
	g_GhostPlayerID[Type][Style] = GetPlayerID(client);
	
	// Delete existing ghost for the map
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d.rec", g_sMapName, Type, Style);
	if(FileExists(sPath))
	{
		DeleteFile(sPath);
	}
	
	// Open a file for writing
	new Handle:hFile = OpenFile(sPath, "w");
	
	// save playerid to file to grab name and time for later times map is played
	decl String:playerid[16];
	IntToString(GetPlayerID(client), playerid, sizeof(playerid));
	WriteFileLine(hFile, "%d|%f", GetPlayerID(client), Time);
	
	new iSize = GetArraySize(g_frame[client]);
	decl String:buffer[512];
	new Float:data[5], buttons;
	
	ClearArray(g_hGhost[Type][Style]);
	for(new i=0; i<iSize; i++)
	{
		GetArrayArray(g_frame[client], i, data, 5);
		PushArrayArray(g_hGhost[Type][Style], data, 5);
		
		buttons = GetArrayCell(g_frame[client], i, 5);
		SetArrayCell(g_hGhost[Type][Style], i, buttons, 5);
		
		FormatEx(buffer, sizeof(buffer), "%f|%f|%f|%f|%f|%d", data[0], data[1], data[2], data[3], data[4], buttons);
		WriteFileLine(hFile, buffer);
	}
	CloseHandle(hFile);
	
	g_ghostframe[Type][Style] = 0;
	//AddGhost();
	
	decl String:name[20], String:sTime[32];
	GetClientName(client, name, sizeof(name));
	FormatPlayerTime(g_fGhostTime[Type][Style], sTime, sizeof(sTime), false, 0);
	Format(g_sGhost[Type][Style], 48, "%s - %s", name, sTime);
}

DeleteGhost(Type, Style)
{
	// delete map ghost file
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d.rec", g_sMapName, Type, Style);
	if(FileExists(sPath))
		DeleteFile(sPath);
	
	// reset ghost
	if(g_ghost[Type][Style] != 0)
	{
		g_fGhostTime[Type][Style] = 0.0;
		ClearArray(g_hGhost[Type][Style]);
		Format(g_sGhost[Type][Style], 48, "Unknown");
		CS_RespawnPlayer(g_ghost[Type][Style]);
	}
}

DB_Connect()
{
	if(g_DB != INVALID_HANDLE)
		CloseHandle(g_DB);
	decl String:error[255];
	g_DB = SQL_Connect("timer", true, error, sizeof(error));
	if(g_DB == INVALID_HANDLE)
	{
		LogError(error);
		CloseHandle(g_DB);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(IsClientInGame(client))
	{
		if(IsPlayerAlive(client))
		{
			if(IsBeingTimed(client, TIMER_ANY) && !IsTimerPaused(client))
			{
				// Record player movement data
				new framenum = GetArraySize(g_frame[client])+1;
				ResizeArray(g_frame[client], framenum);
				
				new Float:lpos[3], Float:lvel[3], Float:lang[3];
				
				GetEntPropVector(client, Prop_Send, "m_vecOrigin", lpos);
				lvel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
				lvel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
				lvel[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
				GetClientEyeAngles(client, lang);
				
				SetArrayCell(g_frame[client], framenum-1, lpos[0], 0);
				SetArrayCell(g_frame[client], framenum-1, lpos[1], 1);
				SetArrayCell(g_frame[client], framenum-1, lpos[2], 2);
				SetArrayCell(g_frame[client], framenum-1, lang[0], 3);
				SetArrayCell(g_frame[client], framenum-1, lang[1], 4);
				SetArrayCell(g_frame[client], framenum-1, buttons, 5);
			}
		}
	}
	if(IsFakeClient(client))
	{
		for(new Type=0; Type<2; Type++)
		{
			for(new Style=0; Style<MAX_STYLES; Style++)
			{
				if(client == g_ghost[Type][Style])
				{
					if(IsPlayerAlive(g_ghost[Type][Style]))
					{
						new iSize = GetArraySize(g_hGhost[Type][Style]);
						
						new Float:pos[3], Float:ang[3];
						if(g_ghostframe[Type][Style] == 0)
						{
							g_starttime[Type][Style] = GetEngineTime();
							
							if(iSize > 0)
							{
								pos[0] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 0);
								pos[1] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 1);
								pos[2] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 2);
								ang[0] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 3);
								ang[1] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 4);
								TeleportEntity(g_ghost[Type][Style], pos, ang, Float:{0.0, 0.0, 0.0});
							}
							
							if(g_GhostPaused[Type][Style] == false)
							{					
								g_GhostPaused[Type][Style] = true;
								g_fPauseTime[Type][Style] = GetEngineTime();
							}
							
							if(GetEngineTime() > g_fPauseTime[Type][Style] + GetConVarFloat(g_hGhostStartPauseTime))
							{
								g_GhostPaused[Type][Style] = false;
								g_ghostframe[Type][Style]++;
							}
						}
						else if(g_ghostframe[Type][Style] == (iSize - 1))
						{
							if(iSize > 0)
							{
								pos[0] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 0);
								pos[1] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 1);
								pos[2] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 2);
								ang[0] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 3);
								ang[1] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 4);
								TeleportEntity(g_ghost[Type][Style], pos, ang, Float:{0.0, 0.0, 0.0});
							}
							
							if(g_GhostPaused[Type][Style] == false)
							{					
								g_GhostPaused[Type][Style] = true;
								g_fPauseTime[Type][Style] = GetEngineTime();
							}
							
							if(GetEngineTime() > g_fPauseTime[Type][Style] + GetConVarFloat(g_hGhostEndPauseTime))
							{
								g_GhostPaused[Type][Style] = false;
								g_ghostframe[Type][Style] = (g_ghostframe[Type][Style] + 1) % iSize;
							}
						}
						else if(g_ghostframe[Type][Style] < iSize)
						{
							new Float:pos2[3];
							GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos2);
							
							pos[0] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 0);
							pos[1] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 1);
							pos[2] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 2);
							ang[0] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 3);
							ang[1] = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 4);
							
							// Get the new velocity from the the 2 points
							new Float:vector[3];
							MakeVectorFromPoints(pos2, pos, vector);
							for(new i=0; i<3; i++)
								vector[i] *= 100.0;
							
							//d = sqrt[(x1-x2)2 + (y1-y2)2 + (z1-z2)2]
							//new Float:distance = SquareRoot(Pow(pos[0]-pos2[0], Float:2.0) + Pow(pos[1]-pos2[1], Float:2.0) + Pow(pos[2]-pos2[2], Float:2.0));
							new Float:distance = GetVectorDistance(pos, pos2);
							
							// teleport bot to next position if the distance is too far, prevents ghost from getting stuck
							//new Float:fTickrate = 1.0 / GetTickInterval();
							
							if(distance > 50.0)
								TeleportEntity(g_ghost[Type][Style], pos, ang, NULL_VECTOR);
							else
								TeleportEntity(g_ghost[Type][Style], NULL_VECTOR, ang, vector);
							
							if(GetEntityFlags(g_ghost[Type][Style]) & FL_ONGROUND)
								SetEntityMoveType(g_ghost[Type][Style], MOVETYPE_WALK);
							else
								SetEntityMoveType(g_ghost[Type][Style], MOVETYPE_NOCLIP);
							
							g_ghostframe[Type][Style] = (g_ghostframe[Type][Style] + 1) % iSize;
							
							buttons = GetArrayCell(g_hGhost[Type][Style], g_ghostframe[Type][Style], 5);
						}
						
						if(g_GhostPaused[Type][Style] == true)
						{
							if(GetEntityMoveType(g_ghost[Type][Style]) != MOVETYPE_NONE)
							{
								SetEntityMoveType(g_ghost[Type][Style], MOVETYPE_NONE);
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Changed;
}