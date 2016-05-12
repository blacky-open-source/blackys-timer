#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "bTimes-ghost",
	author = "blacky",
	description = "Shows a bot that replays the top times",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sdktools>
#include <cstrike>
#include <bTimes-timer>
#include <bTimes-ghost>

new	String:g_mapname[64],
	Handle:g_DB;

new 	Handle:g_frame[MAXPLAYERS+1];

new 	Handle:g_hGhost,
	g_ghost,
	g_ghostframe,
	bool:g_GhostPaused = false,
	String:g_sGhost[48];
	
new 	Float:g_starttime;

// Cvars
new 	Handle:g_hGhostClanTag;

// Model
new	g_GhostModel;

public OnPluginStart()
{	
	// Connect to the database
	DB_Connect();
	
	// Cvars
	g_hGhostClanTag = CreateConVar("timer_ghosttag", "Ghost ::", "The replay bot's clan tag for the scoreboard", 0);
	
	AutoExecConfig(true, "ghost", "timer");
	
	// Events
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	// Create admin command that deletes the ghost
	RegAdminCmd("sm_deleteghost", SM_DeleteGhost, ADMFLAG_CHEATS, "Deletes the ghost.");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("ResetPlayerFrames", Native_ResetPlayerFrames);
	CreateNative("SaveGhost", Native_SaveGhost);
	CreateNative("DeleteGhost", Native_DeleteGhost);
}

public OnMapStart()
{	
	// Recreate the array since it's a new map
	g_hGhost = CreateArray(5, 0);
	
	// Reset ghost name
	Format(g_sGhost, sizeof(g_sGhost), "Unknown");
	
	// Get map name to use the database
	GetCurrentMap(g_mapname, sizeof(g_mapname));
	
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
	
	AddGhost();
}

public OnMapEnd()
{
	// Remove ghost to get a clean start next map
	ServerCommand("bot_kick all");
	g_ghost = 0;
}

public OnClientPutInServer(client)
{
	// Reset player recorded movement
	if(g_frame[client] != INVALID_HANDLE)
	{
		ClearArray(g_frame[client]);
	}
	else
	{
		g_frame[client] = CreateArray(5, 0);
	}
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen)
{
	// Find out if it's the bot added from another time
	if(IsFakeClient(client))
	{
		g_ghost = client;
		
		CS_RespawnPlayer(g_ghost);
	}
	return true;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsClientInGame(client))
	{
		if(client == g_ghost)
		{
			//SetEntityModel(client, "models/player/vad36dishonored/corvo.mdl");
		}
	}
}

public Action:SM_DeleteGhost(client, args)
{
	DeleteGhost();
	
	// Log this because it's something that can be abused
	LogMessage("%L deleted the ghost", client);
}

public Action:GhostCheck(Handle:timer, any:data)
{
	if(g_ghost)
	{
		if(IsClientInGame(g_ghost))
		{
			// Check clan tag
			decl String:sClanTag[64], String:sCvarClanTag[64];
			CS_GetClientClanTag(g_ghost, sClanTag, sizeof(sClanTag));
			GetConVarString(g_hGhostClanTag, sCvarClanTag, sizeof(sCvarClanTag));
			
			if(!StrEqual(sCvarClanTag, sClanTag))
			{
				CS_SetClientClanTag(g_ghost, sCvarClanTag);
			}
			
			// Check name
			if(strlen(g_sGhost) > 0)
			{
				decl String:ghostname[48];
				GetClientName(g_ghost, ghostname, sizeof(ghostname));
				if(!StrEqual(ghostname, g_sGhost))
				{
					SetClientInfo(g_ghost, "name", g_sGhost);
				}
			}
			
			// Check if ghost is dead
			if(!IsPlayerAlive(g_ghost))
			{
				CS_RespawnPlayer(g_ghost);
			}
		
			// Display ghost's current time to spectators
			new iSize = GetArraySize(g_hGhost);
			for(new client=1; client <= MaxClients; client++)
			{
				if(IsClientInGame(client))
				{
					if(!IsPlayerAlive(client))
					{
						new target 	 = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
						new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
						
						if(target == g_ghost && (ObserverMode == 4 || ObserverMode == 5))
						{
							if(!g_GhostPaused && (0 < g_ghostframe < iSize))
							{
								new Float:time = GetEngineTime() - g_starttime;
								decl String:sTime[32];
								FormatPlayerTime(time, sTime, sizeof(sTime), false, 0);
								PrintHintText(client, "Replay\n%s", sTime);
							}
						}
					}
				}
			}
		}
	}
}

AddGhost()
{
	g_ghostframe = 0;
	
	if(g_ghost == 0)
	{
		new t  = FindEntityByClassname(-1, "info_player_terrorist");
		if(t != -1)
			ServerCommand("bot_add_t");
		else
			ServerCommand("bot_add_ct");
	}
	
	new Handle:hBotQuota = FindConVar("bot_quota");
	new iBotQuota = GetConVarInt(hBotQuota);
	
	if(iBotQuota != 1)
		ServerCommand("bot_quota 1");
	
	CloseHandle(hBotQuota);
}

LoadGhost()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s.rec", g_mapname);
	if(FileExists(sPath))
	{ 
		// Open file for reading
		new Handle:hFile = OpenFile(sPath, "r");
		
		// Load all data into the ghost handle
		decl String:line[512], String:expLine[5][64];
		new iSize = 0;
		
		ReadFileLine(hFile, line, sizeof(line));
		new id = StringToInt(line);
		while(!IsEndOfFile(hFile))
		{
			ReadFileLine(hFile, line, sizeof(line));
			ExplodeString(line, "|", expLine, 5, 64);
			
			iSize = GetArraySize(g_hGhost)+1;
			ResizeArray(g_hGhost, iSize);
			SetArrayCell(g_hGhost, iSize-1, StringToFloat(expLine[0]), 0);
			SetArrayCell(g_hGhost, iSize-1, StringToFloat(expLine[1]), 1);
			SetArrayCell(g_hGhost, iSize-1, StringToFloat(expLine[2]), 2);
			SetArrayCell(g_hGhost, iSize-1, StringToFloat(expLine[3]), 3);
			SetArrayCell(g_hGhost, iSize-1, StringToFloat(expLine[4]), 4);
		}
		CloseHandle(hFile);
		
		// Query for name/time of player the ghost is following the path of
		decl String:query[256];
		Format(query, sizeof(query), "SELECT MapID FROM maps WHERE MapName='%s'", g_mapname);
		SQL_TQuery(g_DB, LoadGhost_Callback1, query, id);
	}
}

public LoadGhost_Callback1(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(SQL_GetRowCount(hndl) == 1)
		{
			SQL_FetchRow(hndl);
			new MapID = SQL_FetchInt(hndl, 0);
			
			decl String:query[256];
			Format(query, sizeof(query), "SELECT t2.User, t1.Time FROM times AS t1, players AS t2 WHERE t1.PlayerID=t2.PlayerID AND t1.PlayerID=%d AND t1.MapID=%d AND t1.Type=0 AND t1.Style=0",
				data,
				MapID);
			SQL_TQuery(g_DB, LoadGhost_Callback2, query);
		}
	}
	else
	{
		LogError(error);
	}
}

public LoadGhost_Callback2(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		SQL_FetchRow(hndl);
		
		if(SQL_GetRowCount(hndl) != 0)
		{
			decl String:name[MAX_NAME_LENGTH];
			SQL_FetchString(hndl, 0, name, sizeof(name));
			
			new Float:time, String:sTime[32];
			time = SQL_FetchFloat(hndl, 1);
			FormatPlayerTime(time, sTime, sizeof(sTime), false, 0);
			
			Format(g_sGhost, sizeof(g_sGhost), "%s - %s", name, sTime);
			AddGhost();
		}
	}
	else
	{
		LogError(error);
	}
}

public Native_SaveGhost(Handle:plugin, numParams)
{
	new client     = GetNativeCell(1);
	new Float:time = GetNativeCell(2);
	
	// Delete existing ghost for the map
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s.rec", g_mapname);
	if(FileExists(sPath))
	{
		DeleteFile(sPath);
	}
	
	// Open a file for writing
	new Handle:hFile = OpenFile(sPath, "w");
	
	// save playerid to file to grab name and time for later times map is played
	decl String:playerid[16];
	IntToString(GetClientID(client), playerid, sizeof(playerid));
	WriteFileLine(hFile, playerid);
	
	new iSize = GetArraySize(g_frame[client]);
	decl String:buffer[512];
	new Float:data[5];
	
	ClearArray(g_hGhost);
	for(new i=0; i<iSize; i++)
	{
		GetArrayArray(g_frame[client], i, data, 5);
		PushArrayArray(g_hGhost, data, 5);
		
		FormatEx(buffer, sizeof(buffer), "%f|%f|%f|%f|%f", data[0], data[1], data[2], data[3], data[4]);
		WriteFileLine(hFile, buffer);
	}
	CloseHandle(hFile);
	
	g_ghostframe = 0;
	AddGhost();
	
	decl String:name[MAX_NAME_LENGTH], String:sTime[32];
	GetClientName(client, name, sizeof(name));
	FormatPlayerTime(time, sTime, sizeof(sTime), false, 0);
	Format(g_sGhost, sizeof(g_sGhost), "%s - %s", name, sTime);
}

public Native_DeleteGhost(Handle:plugin, numParams)
{
	// delete map ghost file
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s.rec", g_mapname);
	if(FileExists(sPath))
		DeleteFile(sPath);
	
	// reset ghost
	if(g_ghost != 0)
	{
		ClearArray(g_hGhost);
		Format(g_sGhost, sizeof(g_sGhost), "Unknown");
		CS_RespawnPlayer(g_ghost);
	}
}

public Native_ResetPlayerFrames(Handle:plugin, numParams)
{
	ClearArray(g_frame[GetNativeCell(1)]);
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

public Action:Timer_UnpauseGhost(Handle:timer)
{
	g_GhostPaused = false;
	
	new iSize = GetArraySize(g_hGhost);
	if(iSize > 0)
	{
		g_ghostframe  = (g_ghostframe+1) % GetArraySize(g_hGhost);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(IsClientInGame(client))
	{
		if(IsPlayerAlive(client))
		{
			if(IsBeingTimed(client, TIMER_MAIN) && !IsTimerPaused(client))
			{
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
			}
		}
	}
	if(client == g_ghost)
	{
		if(IsPlayerAlive(g_ghost))
		{
			new iSize = GetArraySize(g_hGhost);
			
			new Float:pos[3], Float:ang[3];
			if(g_ghostframe == 0)
			{
				g_starttime = GetEngineTime();
				
				if(iSize > 0)
				{
					pos[0] = GetArrayCell(g_hGhost, g_ghostframe, 0);
					pos[1] = GetArrayCell(g_hGhost, g_ghostframe, 1);
					pos[2] = GetArrayCell(g_hGhost, g_ghostframe, 2);
					ang[0] = GetArrayCell(g_hGhost, g_ghostframe, 3);
					ang[1] = GetArrayCell(g_hGhost, g_ghostframe, 4);
					TeleportEntity(g_ghost, pos, ang, Float:{0.0, 0.0, 0.0});
				}
				
				if(g_GhostPaused == false)
				{
					g_GhostPaused = true;
					CreateTimer(5.0, Timer_UnpauseGhost);
				}
			}
			else if(g_ghostframe == (iSize - 1))
			{
				if(iSize > 0)
				{
					pos[0] = GetArrayCell(g_hGhost, g_ghostframe, 0);
					pos[1] = GetArrayCell(g_hGhost, g_ghostframe, 1);
					pos[2] = GetArrayCell(g_hGhost, g_ghostframe, 2);
					ang[0] = GetArrayCell(g_hGhost, g_ghostframe, 3);
					ang[1] = GetArrayCell(g_hGhost, g_ghostframe, 4);
					TeleportEntity(g_ghost, pos, ang, Float:{0.0, 0.0, 0.0});
				}
				
				if(g_GhostPaused == false)
				{
					g_GhostPaused = true;
					CreateTimer(2.0, Timer_UnpauseGhost);
				}
			}
			else if(g_ghostframe < iSize)
			{
				new Float:pos2[3];
				GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos2);
				
				pos[0] = GetArrayCell(g_hGhost, g_ghostframe, 0);
				pos[1] = GetArrayCell(g_hGhost, g_ghostframe, 1);
				pos[2] = GetArrayCell(g_hGhost, g_ghostframe, 2);
				ang[0] = GetArrayCell(g_hGhost, g_ghostframe, 3);
				ang[1] = GetArrayCell(g_hGhost, g_ghostframe, 4);
				
				// Get the new velocity from the the 2 points
				new Float:vector[3];
				MakeVectorFromPoints(pos2, pos, vector);
				for(new i=0; i<3; i++)
					vector[i] *= 100.0;
				
				//d = sqrt[(x1-x2)2 + (y1-y2)2 + (z1-z2)2]
				new Float:distance = SquareRoot(Pow(pos[0]-pos2[0], Float:2.0) + Pow(pos[1]-pos2[1], Float:2.0) + Pow(pos[2]-pos2[2], Float:2.0));
				
				// teleport bot to next position if the distance is too far, prevents ghost from getting stuck
				if(distance > 50.0)
				{
					TeleportEntity(g_ghost, pos, NULL_VECTOR, NULL_VECTOR);
				}
				else
				{
					TeleportEntity(g_ghost, NULL_VECTOR, ang, vector);
				}
				
				if(GetEntityFlags(g_ghost) & FL_ONGROUND)
				{
					SetEntityMoveType(g_ghost, MOVETYPE_WALK);
				}
				else
				{
					SetEntityMoveType(g_ghost, MOVETYPE_NOCLIP);
				}
				
				g_ghostframe = (g_ghostframe + 1) % iSize;
			}
			
			if(g_GhostPaused == true)
			{
				if(GetEntityMoveType(g_ghost) != MOVETYPE_NONE)
				{
					SetEntityMoveType(g_ghost, MOVETYPE_NONE);
				}
			}
		}
	}
}