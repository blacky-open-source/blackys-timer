#pragma semicolon 1

#include <btimes-core>

public Plugin:myinfo = 
{
	name = "[bTimes] zones",
	author = "blacky",
	description = "Used to create zones for the bTimes mod",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <bTimes-zones>
#include <bTimes-timer>
#include <bTimes-random>
#include <sdktools>
#include <cstrike>

#define MAX_ANTI_CHEATS 64
#define MAX_FREE_STYLE 64

new 	String:g_sMapName[64],
	//g_mapteam,
	Float:g_spawnpos[3];
 
new 	Float:g_main[2][8][3],	
	bool:g_main_ready[2],
	bool:g_main_info[MAXPLAYERS+1][2];
new	const String:g_main_names[2][] = {"Main zone start", "Main zone end"};
new 	g_main_HaloSprite, 
	g_main_BeamSprite,
	g_main_color[2][4] = {{0, 255, 0, 255}, {255, 0, 0, 255}};

new 	Float:g_bonus[2][8][3],
	bool:g_bonus_ready[2],
	bool:g_bonus_info[MAXPLAYERS+1][2];
new	const String:g_bonus_names[2][] = {"Bonus zone start", "Bonus zone end"};
new	g_bonus_HaloSprite, 
	g_bonus_BeamSprite,
	g_bonus_color[2][4] = {{0, 255, 0, 255}, {255, 0, 0, 255}};
	
new Float:g_anticheat[MAX_ANTI_CHEATS][8][3],
	g_anticheat_HaloSprite,
	g_anticheat_BeamSprite,
	g_anticheat_color[4] = {255, 255, 0, 255},
	g_anticheat_count,
	g_anticheat_setup[MAXPLAYERS+1] = {-1, ...},
	bool:g_anticheat_view[MAXPLAYERS+1];
	
new Float:g_freestyle[MAX_FREE_STYLE][8][3],
	g_freestyle_HaloSprite,
	g_freestyle_BeamSprite,
	g_freestyle_color[4] = {0, 0, 255, 255},
	g_freestyle_count,
	g_freestyle_setup[MAXPLAYERS+1] = {-1, ...};

new 	g_setup[MAXPLAYERS+1] = {-1, ...};

new	g_modulate_ac = 0,
	g_modulate_f  = 0,
	bool:g_update = false;

new Handle:g_DB = INVALID_HANDLE;

// Settings
new Float:g_prespeed = 290.0;

new	String:g_msg_start[128],
	String:g_msg_varcol[128],
	String:g_msg_textcol[128];
	
// Cvar handles
new 	Handle:g_hMaxPrespeed,
	Handle:g_hMainStartColor,
	Handle:g_hMainEndColor,
	Handle:g_hBonusStartColor,
	Handle:g_hBonusEndColor,
	Handle:g_hAntiCheatColor,
	Handle:g_hFreeStyleColor;
	
// Forwards
new	Handle:g_fwdOnZonesLoaded;

public OnPluginStart()
{
	// Connect to the database
	DB_Connect();
	
	// Events
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	// Timer cvars
	g_hMaxPrespeed     = CreateConVar("timer_maxprespeed", "290.0", "Max prespeed in starting zones.", 0, true, 0.0, false);
	g_hMainStartColor  = CreateConVar("timer_mainstartcolor", "0 255 0 255", "Red/Green/Blue/Alpha of main start zone.");
	g_hMainEndColor    = CreateConVar("timer_mainendcolor", "255 0 0 255", "Red/Green/Blue/Alpha of main end zone.");
	g_hBonusStartColor = CreateConVar("timer_bonusstartcolor", "0 255 0 255", "Red/Green/Blue/Alpha of bonus start zone.");
	g_hBonusEndColor   = CreateConVar("timer_bonusendcolor", "255 0 0 255", "Red/Green/Blue/Alpha of bonus end zone.");
	g_hAntiCheatColor  = CreateConVar("timer_anticheatcolor", "255 255 0 255", "Red/Green/Blue/Alpha of anti-cheat zones.");
	g_hFreeStyleColor  = CreateConVar("timer_freestylecolor", "0 0 255 255", "Red/Green/Blue/Alpha of free style zones.");
	
	// Hook timer cvars
	HookConVarChange(g_hMaxPrespeed, OnMaxPrespeedChanged);
	HookConVarChange(g_hMainStartColor, OnMainStartChanged);
	HookConVarChange(g_hMainEndColor, OnMainEndChanged);
	HookConVarChange(g_hBonusStartColor, OnBonusStartChanged);
	HookConVarChange(g_hBonusEndColor, OnBonusEndChanged);
	HookConVarChange(g_hAntiCheatColor, OnAntiCheatChanged);
	HookConVarChange(g_hFreeStyleColor, OnFreeStyleChanged);
	
	// Create zones cfg
	AutoExecConfig(true, "zones", "timer");
	
	// Admin menu for zones
	RegAdminCmd("sm_zones", Cmd_OpenZoneMenu, ADMFLAG_CHEATS, "Open zone control menu");

	// Player Commands
	RegConsoleCmdEx("sm_b", TeleportToBonus, "Teleports you to the bonus area");
	RegConsoleCmdEx("sm_bonus", TeleportToBonus, "Teleports you to the bonus area");
	RegConsoleCmdEx("sm_br", TeleportToBonus, "Teleports you to the bonus area");
	RegConsoleCmdEx("sm_r", TeleportToMain, "Teleports you to the starting zone");
	RegConsoleCmdEx("sm_restart", TeleportToMain, "Teleports you to the starting zone");
	RegConsoleCmdEx("sm_respawn", TeleportToMain, "Teleports you to the starting zone");
	RegConsoleCmdEx("sm_start", TeleportToMain, "Teleports you to the starting zone");
	RegConsoleCmdEx("sm_end", TeleportToMainEnd, "Teleports your to the end zone");
	RegConsoleCmdEx("sm_endb", TeleportToBonusEnd, "Teleports you to the bonus end zone");
	
	// Command listeners for easier team joining
	AddCommandListener(Command_JoinTeam, "jointeam");
	AddCommandListener(Command_JoinTeam, "spectate");
}
 
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	// Natives
	CreateNative("OpenZoneMenu", Native_OpenZoneMenu);
	CreateNative("IsInAStartZone", Native_IsInAStartZone);
	CreateNative("IsInAFreeStyleZone", Native_IsInAFreeStyleZone);
	CreateNative("GoToStart", Native_GoToStart);
	CreateNative("ZoneExists", Native_ZoneExists);
	
	// Forwards
	g_fwdOnZonesLoaded = CreateGlobalForward("OnZonesLoaded", ET_Event);
	
	return APLRes_Success;
}
 
public OnMapStart()
{
	// Re-init all zones
	g_anticheat_count = 0;
	g_freestyle_count = 0;
	g_main_ready[0]   = false;
	g_main_ready[1]   = false;
	g_bonus_ready[0]  = false;
	g_bonus_ready[1]  = false;
	
	// Check for t/ct spawns
	new t  = FindEntityByClassname(-1, "info_player_terrorist");
	new ct = FindEntityByClassname(-1, "info_player_counterterrorist");
	
	// Set map team and get spawn position
	if(t != -1)
	{
		//g_mapteam = 2;
		GetEntPropVector(t, Prop_Send, "m_vecOrigin", g_spawnpos);
	}
	else
	{
		//g_mapteam = 3;
		GetEntPropVector(ct, Prop_Send, "m_vecOrigin", g_spawnpos);
	}
	
	// For sql related stuff, get map name
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));

	// Needed textures for zones
	g_main_BeamSprite  		= PrecacheModel("materials/sprites/trails/bluelightning.vmt");
	g_main_HaloSprite  		= PrecacheModel("materials/sprites/halo01.vmt");
	g_bonus_BeamSprite 		= PrecacheModel("materials/sprites/trails/bluelightning.vmt");
	g_bonus_HaloSprite 		= PrecacheModel("materials/sprites/halo01.vmt");
	g_anticheat_BeamSprite 	= PrecacheModel("materials/sprites/trails/bluelightning.vmt");
	g_anticheat_HaloSprite 	= PrecacheModel("materials/sprites/halo01.vmt");
	g_freestyle_BeamSprite 	= PrecacheModel("materials/sprites/trails/bluelightning.vmt");
	g_freestyle_HaloSprite		= PrecacheModel("materials/sprites/halo01.vmt");
	
	// Add needed textures to downloads table
	AddFileToDownloadsTable("materials/sprites/trails/bluelightning.vmt");
	AddFileToDownloadsTable("materials/sprites/trails/bluelightning.vtf");
	AddFileToDownloadsTable("materials/sprites/halo01.vmt");
	
	// For showing the zones
	CreateTimer(0.1, LoopBeams, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public OnMapIDPostCheck()
{
	DB_LoadZones();
}

public OnClientPutInServer(client)
{
	// So players don't join with a zone following them
	TrackZoneSetup(g_setup[client], -1);
	TrackZoneSetup(g_anticheat_setup[client], -1);
	TrackZoneSetup(g_freestyle_setup[client], -1);
	
	// So players don't join seeing anti-cheat zones
	g_anticheat_view[client] = false;
}

public OnConfigsExecuted()
{
	// Set max prespeed
	g_prespeed = GetConVarFloat(g_hMaxPrespeed);
	
	// Color strings
	decl String:sColor[32], String:sColorExp[4][8];
	
	// Get zone colors
	GetConVarString(g_hMainStartColor, sColor, sizeof(sColor));
	ExplodeString(sColor, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_main_color[0][i] = StringToInt(sColorExp[i]);
	}
	
	GetConVarString(g_hMainEndColor, sColor, sizeof(sColor));
	ExplodeString(sColor, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_main_color[1][i] = StringToInt(sColorExp[i]);
	}
	
	GetConVarString(g_hBonusStartColor, sColor, sizeof(sColor));
	ExplodeString(sColor, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_bonus_color[0][i] = StringToInt(sColorExp[i]);
	}
	
	GetConVarString(g_hBonusStartColor, sColor, sizeof(sColor));
	ExplodeString(sColor, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_bonus_color[0][i] = StringToInt(sColorExp[i]);
	}
	
	GetConVarString(g_hBonusEndColor, sColor, sizeof(sColor));
	ExplodeString(sColor, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_bonus_color[1][i] = StringToInt(sColorExp[i]);
	}
	
	GetConVarString(g_hAntiCheatColor, sColor, sizeof(sColor));
	ExplodeString(sColor, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_anticheat_color[i] = StringToInt(sColorExp[i]);
	}
	
	GetConVarString(g_hFreeStyleColor, sColor, sizeof(sColor));
	ExplodeString(sColor, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_freestyle_color[i] = StringToInt(sColorExp[i]);
	}
}

public OnMaxPrespeedChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Set the allowed prespeed in bonus/main zones
	g_prespeed = StringToFloat(newValue);
}

public OnMainStartChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Color string
	decl String:sColorExp[4][8];
	
	// Set main zone start color
	ExplodeString(newValue, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_main_color[0][i] = StringToInt(sColorExp[i]);
	}
}

public OnMainEndChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Color string
	decl String:sColorExp[4][8];
	
	// Set main zone end color
	ExplodeString(newValue, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_main_color[1][i] = StringToInt(sColorExp[i]);
	}
}

public OnBonusStartChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Color string
	decl String:sColorExp[4][8];
	
	// Set bonus zone start color
	ExplodeString(newValue, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_bonus_color[0][i] = StringToInt(sColorExp[i]);
	}
}

public OnBonusEndChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Color string
	decl String:sColorExp[4][8];
	
	// Set bonus zone end color
	ExplodeString(newValue, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_bonus_color[1][i] = StringToInt(sColorExp[i]);
	}
}

public OnAntiCheatChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Color string
	decl String:sColorExp[4][8];
	
	// Set anti-cheat zone color
	ExplodeString(newValue, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_anticheat_color[i] = StringToInt(sColorExp[i]);
	}
}

public OnFreeStyleChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Color string
	decl String:sColorExp[4][8];
	
	// Set free style zone color
	ExplodeString(newValue, " ", sColorExp, 4, 8);
	for(new i=0; i<4; i++)
	{
		g_freestyle_color[i] = StringToInt(sColorExp[i]);
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

public Action:Command_JoinTeam(client, const String:command[], argc)
{
	if(StrEqual(command, "jointeam"))
	{
		// String that holds the jointeam argument
		decl String:sArg[192];
		
		// Get the argument
		GetCmdArgString(sArg, sizeof(sArg));
		
		// Get team number from argument
		new team = StringToInt(sArg);
		
		// if team is t/ct/auto assign
		if(team == 2 || team == 3)
		{
			// spawn player to map team
			CS_SwitchTeam(client, team);
			CS_RespawnPlayer(client);
		}
		else if(team == 0)
		{
			CS_SwitchTeam(client, GetRandomInt(2, 3));
			CS_RespawnPlayer(client);
		}
		else if(team == 1) // if team is spectators
		{
			// change player to spectator team
			ForcePlayerSuicide(client);
			ChangeClientTeam(client, 1);
		}
	}
	else // if player used the spectate command
	{
		// change player to spectate
		ForcePlayerSuicide(client);
		ChangeClientTeam(client, 1);
	}
	return Plugin_Handled;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{	
	// Get the player who spawned
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// If they're in game
	if(IsClientInGame(client))
	{
		// if the main zone is ready
		if(g_main_ready[0])
		{
			// Send them to the main zone
			TeleportToZone(client, g_main[0][0], g_main[0][7]);
		}
		
		// if main zone is not ready
		else
		{
			// Send them to a map spawn point
			TeleportEntity(client, g_spawnpos, NULL_VECTOR, NULL_VECTOR);
		}
	}
	
	return Plugin_Continue;
}

public Action:Cmd_OpenZoneMenu(client, args)
{
	OpenZoneMenu(client);
	return Plugin_Handled;
}

public Native_IsInAStartZone(Handle:plugin, numParams)
{
	return IsInsideZone(GetNativeCell(1), g_main[0]) || IsInsideZone(GetNativeCell(1), g_bonus[0]);
}

public Native_IsInAFreeStyleZone(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	for(new i=0; i<g_freestyle_count; i++)
	{
		if(IsInsideZone(client, g_freestyle[i]))
			return true;
	}
	return false;
}

public Native_GoToStart(Handle:plugin, numParams)
{
	TeleportToZone(GetNativeCell(1), g_main[0][0], g_main[0][7]);
}

public Native_OpenZoneMenu(Handle:plugin, numParams)
{
	new Handle:menu = CreateMenu(AdminMenu_ZoneCtrl);
	
	SetMenuTitle(menu, "Zones control");
	
	AddMenuItem(menu, "Add Start", "Add Start");
	AddMenuItem(menu, "Add End", "Add End");
	AddMenuItem(menu, "Add Bonus Start", "Add Bonus Start");
	AddMenuItem(menu, "Add Bonus End", "Add Bonus End");
	AddMenuItem(menu, "Add Free Style Zone", "Add Free Style Zone");
	AddMenuItem(menu, "Anti-cheat zone", "Anti-cheat zone");
	AddMenuItem(menu, "Delete zone", "Delete zone");
	
	SetMenuExitButton(menu, true);
	
	DisplayMenu(menu, GetNativeCell(1), MENU_TIME_FOREVER);
}

public Native_ZoneExists(Handle:plugin, numParams)
{
	new Type = GetNativeCell(1);
	
	if(Type == TIMER_MAIN)
		return g_main_ready[0];
	
	if(Type == TIMER_BONUS)
		return g_bonus_ready[0];
	
	return false;
}

public Native_MainZoneExists(Handle:plugin, numParams)
{
	return g_main_ready[0];
}

public Native_LoadMapZones(Handle:plugin, numParams)
{
	DB_LoadZones();
}
 
public AdminMenu_ZoneCtrl(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrEqual(info, "Add Start"))
		{
			if(g_setup[param1] == -1 && g_anticheat_setup[param1] == -1 && g_freestyle_setup[param1] == -1)
				CreateMainZone(param1, 0, 0);
			else if(g_setup[param1] == 0 && g_anticheat_setup[param1] == -1 && g_freestyle_setup[param1] == -1)
				CreateMainZone(param1, 0, 7);
			else
				PrintColorText(param1, "%s%sYou can't create two zones at once.",
					g_msg_start,
					g_msg_textcol);
			OpenZoneMenu(param1);
		}
		else if(StrEqual(info, "Add End"))
		{
			if(g_setup[param1] == -1 && g_anticheat_setup[param1] == -1 && g_freestyle_setup[param1] == -1)
				CreateMainZone(param1, 1, 0);
			else if(g_setup[param1] == 1 && g_anticheat_setup[param1] == -1 && g_freestyle_setup[param1] == -1)
				CreateMainZone(param1, 1, 7);
			else
				PrintColorText(param1, "%s%sYou can't create two zones at once.",
					g_msg_start,
					g_msg_textcol);
			OpenZoneMenu(param1);
		}
		else if(StrEqual(info, "Add Bonus Start"))
		{
			if(g_setup[param1] == -1 && g_anticheat_setup[param1] == -1 && g_freestyle_setup[param1] == -1)
				CreateBonusZone(param1, 0, 0);
			else if(g_setup[param1] == 2 && g_anticheat_setup[param1] == -1 && g_freestyle_setup[param1] == -1)
				CreateBonusZone(param1, 0, 7);
			else
				PrintColorText(param1, "%s%sYou can't create two zones at once.",
					g_msg_start,
					g_msg_textcol);
			OpenZoneMenu(param1);
		}
		else if(StrEqual(info, "Add Bonus End"))
		{
			if(g_setup[param1] == -1 && g_anticheat_setup[param1] == -1 && g_freestyle_setup[param1] == -1)
				CreateBonusZone(param1, 1, 0);
			else if(g_setup[param1] == 3 && g_anticheat_setup[param1] == -1 && g_freestyle_setup[param1] == -1)
				CreateBonusZone(param1, 1, 7);
			else
				PrintColorText(param1, "%s%sYou can't create two zones at once.",
					g_msg_start,
					g_msg_textcol);
			OpenZoneMenu(param1);
		}
		else if(StrEqual(info, "Add Free Style Zone"))
		{
			if(g_freestyle_count < MAX_FREE_STYLE)
			{
				if(g_setup[param1] == -1 && g_anticheat_setup[param1] == -1 && g_freestyle_setup[param1] == -1)
					CreateFreeStyleZone(param1, g_freestyle_count, 0);
				else if(g_setup[param1] == -1 && g_anticheat_setup[param1] == -1 && g_freestyle_setup[param1] == g_freestyle_count)
					CreateFreeStyleZone(param1, g_freestyle_count, 7);
				else
					PrintColorText(param1, "%s%sYou can't create two zones at once.",
						g_msg_start,
						g_msg_textcol);
			}
			OpenZoneMenu(param1);
		}
		else if(StrEqual(info, "Anti-cheat zone"))
			AdminCmd_ZoneCtrl_AntiCheatZone(param1);
		else if(StrEqual(info, "Delete zone"))
		{
			for(new i=0; i<g_anticheat_count; i++)
			{
				if(IsInsideZone(param1, g_anticheat[i]))
					DB_DeleteAntiCheatZone(i);
			}
			for(new i=0; i<g_freestyle_count; i++)
			{
				if(IsInsideZone(param1, g_freestyle[i]))
					DB_DeleteFreeStyleZone(i);
			}
			for(new i=0; i<2; i++)
			{
				if(IsInsideZone(param1, g_main[i]))
				{
					DB_DeleteZone(i);
					g_main_ready[i] = false;
					for(new i2=0; i2<8; i2++)
						for(new i3=0; i3<3; i3++)
							g_main[i][i2][i3] = 0.0;
					
					for(new client=1; client<=MaxClients; client++)
					{
						if(IsClientInGame(client))
						{
							if(IsBeingTimed(client, TIMER_MAIN))
							{
								StopTimer(client);
								PrintColorText(client, "%s%sYour timer was stopped because a main zone was deleted",
									g_msg_start,
									g_msg_textcol);
							}
						}
					}
				}
			}
			for(new i=0; i<2; i++)
			{
				if(IsInsideZone(param1, g_bonus[i]))
				{
					DB_DeleteZone(i+2);
					g_bonus_ready[i] = false;
					for(new i2=0; i2<8; i2++)
						for(new i3=0; i3<3; i3++)
							g_bonus[i][i2][i3] = 0.0;
						
					for(new client=1; client<=MaxClients; client++)
					{
						if(IsClientInGame(client))
						{
							if(IsBeingTimed(client, TIMER_BONUS))
							{
								StopTimer(client);
								PrintColorText(client, "%s%sYour timer was stopped because a bonus zone was deleted",
									g_msg_start,
									g_msg_textcol);
							}
						}
					}
				}
			}
			OpenZoneMenu(param1);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

AdminCmd_ZoneCtrl_AntiCheatZone(client)
{
	new Handle:menu = CreateMenu(AdminMenu_ZoneCtrl_AntiCheatZone);
	
	SetMenuTitle(menu, "Anti-cheat zone");
	AddMenuItem(menu, "Add zone", "Add zone");
	AddMenuItem(menu, "Go to zone", "Go to zone");
	AddMenuItem(menu, "View/Hide zones", "View/Hide zones");
	
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public AdminMenu_ZoneCtrl_AntiCheatZone(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		if(StrEqual(info, "Add zone"))
		{
			if(g_anticheat_count < MAX_ANTI_CHEATS)
			{
				if(g_anticheat_setup[param1] == -1 && g_setup[param1] == -1 && g_freestyle_setup[param1] == -1)
					CreateAntiCheatZone(param1, g_anticheat_count, 0);
				else if(g_anticheat_setup[param1] == g_anticheat_count && g_setup[param1] == -1 && g_freestyle_setup[param1] == -1)
					CreateAntiCheatZone(param1, g_anticheat_count, 7);
				else
					PrintColorText(param1, "%s%sYou can't create two zones at once",
						g_msg_start,
						g_msg_textcol);
				AdminCmd_ZoneCtrl_AntiCheatZone(param1);
			}
			else
			{
				PrintColorText(param1, "%s%sToo many anti-cheats. The limit is %d",
					g_msg_start,
					g_msg_textcol,
					MAX_ANTI_CHEATS);
			}
		}
		else if(StrEqual(info, "Go to zone"))
		{
			if(g_anticheat_count != 0)
			{
				AdminCmd_ZoneCtrl_AntiCheatZone_Goto(param1);
			}
			else
			{
				PrintColorText(param1, "%s%sThere are no Anti-cheat zones",
					g_msg_start,
					g_msg_textcol);
				AdminCmd_ZoneCtrl_AntiCheatZone(param1);
			}
		}
		else if(StrEqual(info, "View/Hide zones"))
		{
			g_anticheat_view[param1] = !g_anticheat_view[param1];
			AdminCmd_ZoneCtrl_AntiCheatZone(param1);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenZoneMenu(param1);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

AdminCmd_ZoneCtrl_AntiCheatZone_Goto(client)
{
	new Handle:menu = CreateMenu(AdminMenu_ZoneCtrl_AntiCheatZone_Goto);
	decl String:item[32];
	SetMenuTitle(menu, "Go to Anti-cheat zone:");
	for(new i=0; i<g_anticheat_count; i++)
	{
		Format(item, sizeof(item), "Anti-cheat %d", i+1);
		AddMenuItem(menu, item, item);
	}
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public AdminMenu_ZoneCtrl_AntiCheatZone_Goto(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[32], String:item[32];
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		for(new i=0; i<g_anticheat_count; i++)
		{
			Format(item, sizeof(item), "Anti-cheat %d", i+1);
			if(StrEqual(info, item))
				TeleportToZone(param1, g_anticheat[i][0], g_anticheat[i][7]);
		}
		
		AdminCmd_ZoneCtrl_AntiCheatZone_Goto(param1);
	}
	else if (action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			AdminCmd_ZoneCtrl_AntiCheatZone(param1);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:TeleportToMain(client, args)
{
	if(g_main_ready[0] == true)
	{
		StopTimer(client);
		TeleportToZone(client, g_main[0][0], g_main[0][7]);
		
		if(g_main_ready[1] == true)
		{
			StartTimer(client, TIMER_MAIN);
		}
	}
	else
	{
		PrintColorText(client, "%s%sThe start zone isn't ready yet",
			g_msg_start,
			g_msg_textcol);
	}
			
	return Plugin_Handled;
}

public Action:TeleportToMainEnd(client, args)
{
	if(g_main_ready[1] == true)
	{
		StopTimer(client);
		TeleportToZone(client, g_main[1][0], g_main[1][7]);
	}
	else
	{
		PrintColorText(client, "%s%sThe end zone hasn't been added yet",
			g_msg_start,
			g_msg_textcol);
	}
			
	return Plugin_Handled;
}

public Action:TeleportToBonus(client, args)
{
	if(g_bonus_ready[0] == true)
	{
		StopTimer(client);
		TeleportToZone(client, g_bonus[0][0], g_bonus[0][7]);
		
		if(g_bonus_ready[1] == true)
		{
			StartTimer(client, TIMER_BONUS);
		}
	}
	else
	{
		PrintColorText(client, "%s%sThe bonus zone hasn't been added",
			g_msg_start,
			g_msg_textcol);
	}

	return Plugin_Handled;
}

public Action:TeleportToBonusEnd(client, args)
{
	if(g_bonus_ready[1] == true)
	{
		StopTimer(client);
		TeleportToZone(client, g_bonus[1][0], g_bonus[1][7]);
	}
	else
	{
		PrintColorText(client, "%s%sThe bonus end zone hasn't been added",
			g_msg_start,
			g_msg_textcol);
	}
			
	return Plugin_Handled;
}

/*
* Teleports a player to the center lowest point of a zone
*/
TeleportToZone(client, Float:point1[3], Float:point2[3])
{
	new Float:position[3], Float:angle[3];
	
	position[0] = (point1[0]+point2[0])/2;
	position[1] = (point1[1]+point2[1])/2;
	position[2] = (point1[2]<point2[2])?point1[2]:point2[2];
	
	GetClientEyeAngles(client, angle);
	TeleportEntity(client, position, angle, Float:{0, 0, 0});
}

/*
* Generates all 8 points of a zone given just 2 of its points
*/
CreateZonePoints(Float:point[8][3])
{
	for(new i=1; i<7; i++)
	{
		for(new j=0; j<3; j++)
		{
			point[i][j] = point[((i >> (2-j)) & 1) * 7][j];
		}
	}
}
 
/*
* Graphically draws a zone
*	if client == 0, it draws it for all players in the game
*   if client index is between 0 and MaxClients+1, it draws for the specified client
*/
DrawZone(client, Float:array[8][3], beamsprite, halosprite, color[4], Float:life)
{
	for(new i=0, i2=3; i2>=0; i+=i2--)
	{
		for(new j=1; j<=7; j+=(j/2)+1)
		{
			if(j != 7-i)
			{
				TE_SetupBeamPoints(array[i], array[j], beamsprite, halosprite, 0, 0, life, 5.0, 5.0, 0, 0.0, color, 0);
				if(0 < client <= MaxClients)
					TE_SendToClient(client, 0.0);
				else
					TE_SendToAll(0.0);
			}
		}
	}
}

/*
* returns true if a player is inside the given zone
* returns false if they aren't in it
*/
bool:IsInsideZone(client, Float:point[8][3])
{
	new Float:playerPos[3];
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", playerPos);
	
	// Add 5 units to a player's height or it won't work
	playerPos[2] += 5.0;
	
	for(new i=0; i<3; i++)
	{
		if(point[0][i]>=playerPos[i] == point[7][i]>=playerPos[i])
		{
			return false;
		}
	}

	return true;
}

/*
* To tell if players will trigger the action this zone causes
*/
EnableZone(&bool:zoneready, bool:enable)
{
	zoneready = enable;
}

/*
* Makes a zone constantly update between a timer admin 
* setting up a zone and their 1st corner
*/
TrackZoneSetup(&setup, zone)
{
	setup = zone;
}

/*
* Tells a timer admin if they are allowed to set up a zone
* returns: 
*	0 if they are allowed to set it up
*	client index of timer admin already setting up this zone
*/
CanSetup(client, zone)
{
	for(new i=0; i<=MaxClients; i++)
	{
		if((g_setup[i] == zone) && (i != client))
		{
			return i;
		}
	}
	return 0;
}

/*
* Creates the start/end main zones
*/
CreateMainZone(client, type, corner)
{
	new canset = CanSetup(client, type);
	if(canset != 0)
	{
		decl String:targetname[MAX_NAME_LENGTH];
		GetClientName(canset, targetname, sizeof(targetname));
		PrintColorText(client, "%s%s%s %sis already creating %s%s",
			g_msg_start,
			g_msg_varcol,
			targetname,
			g_msg_textcol,
			g_msg_varcol,
			g_main_names[type]);
		return;
	}
	if(corner == 0)
	{
		//StopTimers(Main);
		EnableZone(g_main_ready[type], false);
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_main[type][corner]);
		TrackZoneSetup(g_setup[client], type);
	}
	else if(corner == 7)
	{
		if(g_setup[client] != type)
		{
			PrintColorText(client, "%s%sYou must set up corner one of %s%s %sfirst",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_main_names[type],
				g_msg_textcol);
			return;
		}
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_main[type][corner]);
		g_main[type][corner][2] += 128.0;
		TrackZoneSetup(g_setup[client], -1);
		CreateZonePoints(g_main[type]);
		DB_DeleteZone(type);
		DB_AddZone(type, g_main[type]);
		EnableZone(g_main_ready[type], true);
	}
}

/*
* Creates the start/end bonus zones
*/
CreateBonusZone(client, type, corner)
{
	new canset = CanSetup(client, type+2);
	if(canset != 0)
	{
		decl String:targetname[MAX_NAME_LENGTH];
		GetClientName(canset, targetname, sizeof(targetname));
		PrintColorText(client, "%s%s%s %sis already creating %s%s",
			g_msg_start,
			g_msg_varcol,
			targetname,
			g_msg_textcol,
			g_msg_varcol,
			g_bonus_names[type]);
		return;
	}
	if(corner == 0)
	{
		//StopTimers(Bonus);
		EnableZone(g_bonus_ready[type], false);
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_bonus[type][corner]);
		TrackZoneSetup(g_setup[client], type+2);
	}
	else if(corner == 7)
	{
		if(g_setup[client] != (type+2))
		{
			PrintColorText(client, "%s%sYou must set up corner one of %s%s %sfirst",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_bonus_names[type],
				g_msg_textcol);
			return;
		}
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_bonus[type][corner]);
		g_bonus[type][corner][2] += 128.0;
		TrackZoneSetup(g_setup[client], -1);
		CreateZonePoints(g_bonus[type]);
		DB_DeleteZone(type+2);
		DB_AddZone(type+2, g_bonus[type]);
		EnableZone(g_bonus_ready[type], true);
	}
}

/*
* Creates the anti-cheat zones
*/
CreateAntiCheatZone(client, zone, corner)
{
	new canset = CanSetup(client, zone);
	if(canset != 0)
	{
		decl String:targetname[MAX_NAME_LENGTH];
		GetClientName(canset, targetname, sizeof(targetname));
		PrintColorText(client, "%s%s%s%s is already creating an %sAnti-cheat zone",
			g_msg_start,
			g_msg_varcol,
			targetname,
			g_msg_textcol,
			g_msg_varcol);
		return;
	}
	if(corner == 0)
	{
		g_anticheat_view[client] = true;
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_anticheat[zone][corner]);
		TrackZoneSetup(g_anticheat_setup[client], zone);
	}
	else if(corner == 7)
	{
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_anticheat[zone][corner]);
		TrackZoneSetup(g_anticheat_setup[client], -1);
		CreateZonePoints(g_anticheat[zone]);
		DB_AddZone(4, g_anticheat[zone]);
		g_anticheat_count++;
	}
}

CreateFreeStyleZone(client, zone, corner)
{
	new canset = CanSetup(client, zone);
	if(canset != 0)
	{
		decl String:targetname[MAX_NAME_LENGTH];
		GetClientName(canset, targetname, sizeof(targetname));
		PrintColorText(client, "%s%s%s%s is already creating an %sFree style zone",
			g_msg_start,
			g_msg_varcol,
			targetname,
			g_msg_textcol,
			g_msg_varcol);
		return;
	}
	if(corner == 0)
	{
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_freestyle[zone][corner]);
		TrackZoneSetup(g_freestyle_setup[client], zone);
	}
	else if(corner == 7)
	{
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_freestyle[zone][corner]);
		TrackZoneSetup(g_freestyle_setup[client], -1);
		CreateZonePoints(g_freestyle[zone]);
		DB_AddZone(5, g_freestyle[zone]);
		g_freestyle_count++;
	}
}

/*
* Loops beams to clients
* Updates at different times to bypass the TempEnt limit of 32/update
*/
public Action:LoopBeams(Handle:timer, any:data)
{
	for(new client=1; client<=MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(g_setup[client] == 0 || g_setup[client] == 1)
			{
				GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_main[g_setup[client]][7]);
				g_main[g_setup[client]][7][2] += 128.0;
				CreateZonePoints(g_main[g_setup[client]]);
				DrawZone(0, g_main[g_setup[client]], g_main_BeamSprite, g_main_HaloSprite, g_main_color[g_setup[client]], Float:0.3);
			}
			else if(g_setup[client] == 2 || g_setup[client] == 3)
			{
				GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_bonus[g_setup[client]%2][7]);
				g_bonus[g_setup[client]%2][7][2] += 128.0;
				CreateZonePoints(g_bonus[g_setup[client]%2]);
				DrawZone(0, g_bonus[g_setup[client]%2], g_bonus_BeamSprite, g_bonus_HaloSprite, g_bonus_color[g_setup[client]%2], Float:0.3);
			}
			
			if(g_anticheat_setup[client] != -1)
			{
				GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_anticheat[g_anticheat_setup[client]][7]);
				CreateZonePoints(g_anticheat[g_anticheat_setup[client]]);
				DrawZone(client, g_anticheat[g_anticheat_setup[client]], g_anticheat_BeamSprite, g_anticheat_HaloSprite, g_anticheat_color, Float:0.3);
			}
			
			if(g_freestyle_setup[client] != -1)
			{
				GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_freestyle[g_freestyle_setup[client]][7]);
				CreateZonePoints(g_freestyle[g_freestyle_setup[client]]);
				DrawZone(client, g_freestyle[g_freestyle_setup[client]], g_freestyle_BeamSprite, g_freestyle_HaloSprite, g_freestyle_color, Float:0.3);
			}
			
			if(g_anticheat_view[client] == true && g_anticheat_count != 0)
			{
				DrawZone(client, g_anticheat[g_modulate_ac], g_anticheat_BeamSprite, g_anticheat_HaloSprite, g_anticheat_color, (float(g_anticheat_count)/10.0)+0.2);
			}
		}
	}
	
	for(new x=0; x<2; x++)
	{
		if(g_main_ready[x] == true && g_update == false)
			DrawZone(0, g_main[x], g_main_BeamSprite, g_main_HaloSprite, g_main_color[x], Float:0.4);
		if(g_bonus_ready[x] == true && g_update == true)
			DrawZone(0, g_bonus[x], g_bonus_BeamSprite, g_bonus_HaloSprite, g_bonus_color[x], Float:0.4);
	}
	
	if(g_freestyle_count != 0)
	{
		DrawZone(0, g_freestyle[g_modulate_f], g_freestyle_BeamSprite, g_freestyle_HaloSprite, g_freestyle_color, (float(g_freestyle_count)/10.0)+0.2);
	}
	
	g_modulate_ac  = (g_anticheat_count==0)?0:(g_modulate_ac+1)%g_anticheat_count;
	g_modulate_f   = (g_freestyle_count==0)?0:(g_modulate_f+1)%g_freestyle_count;
	g_update       = !g_update;
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	if(entity == data)
		return false;
	
	return true;
}

/*
* Connects to the database
*/
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

/*
* Deletes either a main or bonus zone
*/
DB_DeleteZone(Type)
{
	decl String:query[512], String:mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
	Format(query, sizeof(query), "SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1", mapname);
	SQL_TQuery(g_DB, DB_DeleteZone_Callback1, query, Type);
}

public DB_DeleteZone_Callback1(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(SQL_GetRowCount(hndl) != 0)
		{
			SQL_FetchRow(hndl);
			new mapid = SQL_FetchInt(hndl, 0);
			decl String:query[256];
			Format(query, sizeof(query), "DELETE FROM zones WHERE MapID=%d AND Type=%d", mapid, data);
			SQL_TQuery(g_DB, DB_DeleteZone_Callback2, query, data);
		}
		
	}
	else
	{
		LogError(error);
	}
}

public DB_DeleteZone_Callback2(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new const String:zoneNames[4][] = {"[Main start]", "[Main end]", "[Bonus start]", "[Bonus end]"};
		LogMessage("Zone %s deleted", zoneNames[data]);
	}
	else
	{
		LogError(error);
	}
}

/*
* Deletes an anti-cheat zone
*/
DB_DeleteAntiCheatZone(Zone)
{
	decl String:query[512], String:mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
	Format(query, sizeof(query), "SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1", mapname);
	SQL_TQuery(g_DB, DB_DeleteAntiCheatZone_Callback1, query, Zone);
}

public DB_DeleteAntiCheatZone_Callback1(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		SQL_FetchRow(hndl);
		new mapid = SQL_FetchInt(hndl, 0);
		
		decl String:query[256];
		
		Format(query, sizeof(query), "DELETE FROM zones WHERE MapID=%d AND Type=4 AND point00=%f AND point01=%f AND point02=%f AND point10=%f AND point11=%f AND point12=%f",
			mapid,
			g_anticheat[data][0][0], g_anticheat[data][0][1], g_anticheat[data][0][2],
			g_anticheat[data][7][0], g_anticheat[data][7][1], g_anticheat[data][7][2]);
		SQL_TQuery(g_DB, DB_DeleteAntiCheatZone_Callback2, query, data);
	}
	else
	{
		LogError(error);
	}
}

public DB_DeleteAntiCheatZone_Callback2(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		LogMessage("An Anti-cheat zone has been deleted");
		
		for(new z=data; z<g_anticheat_count-1; z++)
			for(new slot=0; slot<8; slot++)
				for(new slottwo=0; slottwo<3; slottwo++)
					g_anticheat[z][slot][slottwo] = g_anticheat[z+1][slot][slottwo];
				
		g_anticheat_count--;
	}
	else
	{
		LogError(error);
	}
}

DB_DeleteFreeStyleZone(Zone)
{
	decl String:query[512], String:mapname[64];
	
	GetCurrentMap(mapname, sizeof(mapname));
	
	Format(query, sizeof(query), "SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1", mapname);
	SQL_TQuery(g_DB, DB_DeleteFreeStyleZone_Callback1, query, Zone);
}

public DB_DeleteFreeStyleZone_Callback1(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		SQL_FetchRow(hndl);
		new mapid = SQL_FetchInt(hndl, 0);
		
		decl String:query[256];
		
		Format(query, sizeof(query), "DELETE FROM zones WHERE MapID=%d AND Type=5 AND point00=%f AND point01=%f AND point02=%f AND point10=%f AND point11=%f AND point12=%f",
			mapid,
			g_freestyle[data][0][0], g_freestyle[data][0][1], g_freestyle[data][0][2],
			g_freestyle[data][7][0], g_freestyle[data][7][1], g_freestyle[data][7][2]);
		SQL_TQuery(g_DB, DB_DeleteFreeStyleZone_Callback2, query, data);
	}
	else
	{
		LogError(error);
	}
}

public DB_DeleteFreeStyleZone_Callback2(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		LogMessage("A Free Style zone has been deleted");
		
		for(new z=data; z<g_freestyle_count-1; z++)
			for(new slot=0; slot<8; slot++)
				for(new slottwo=0; slottwo<3; slottwo++)
					g_freestyle[z][slot][slottwo] = g_freestyle[z+1][slot][slottwo];
				
		g_freestyle_count--;
	}
	else
	{
		LogError(error);
	}
}

/*
* Adds a main, bonus, or anti-cheat zone
*/
DB_AddZone(ZoneType, Float:point[8][3])
{
	new Handle:data = CreateDataPack();
	WritePackCell(data, ZoneType);
	
	for(new i=0; i<8; i++)
		for(new x=0; x<3; x++)
			WritePackFloat(data, point[i][x]);
		
	decl String:query[512], String:mapname[64];
	
	GetCurrentMap(mapname, sizeof(mapname));
	
	Format(query, sizeof(query), "SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1", mapname);
	SQL_TQuery(g_DB, DB_AddZone_Callback1, query, data);
}

public DB_AddZone_Callback1(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new ZoneType = ReadPackCell(data);
		
		new Float:point[8][3];
		for(new i=0; i<8; i++)
			for(new x=0; x<3; x++)
				point[i][x] = ReadPackFloat(data);
			
		SQL_FetchRow(hndl);
		new mapid = SQL_FetchInt(hndl, 0);
		
		decl String:query[256];
		
		Format(query, sizeof(query), "INSERT INTO zones (MapID, Type, point00, point01, point02, point10, point11, point12) VALUES (%d, %d, %f, %f, %f, %f, %f, %f)", 
			mapid, 
			ZoneType,
			point[0][0], point[0][1], point[0][2], 
			point[7][0], point[7][1], point[7][2]);
		SQL_TQuery(g_DB, DB_AddZone_Callback2, query, ZoneType);
	}
	else
	{
		LogError(error);
	}
}

public DB_AddZone_Callback2(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new const String:zoneNames[6][] = {"[Main start]", "[Main end]", "[Bonus start]", "[Bonus end]", "[Anti-cheat]", "[Free Style]"};
		LogMessage("Zone %s has been created.", zoneNames[data]);
	}
	else
	{
		LogError(error);
	}
}

/*
* Loads all the zones for a map when it starts
*/
DB_LoadZones()
{	
	// Select zones query
	decl String:query[512];
	Format(query, sizeof(query), "SELECT point00, point01, point02, point10, point11, point12, Type FROM zones WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1)", 
		g_sMapName);
	SQL_TQuery(g_DB, DB_LoadZones_Callback, query);
}

public DB_LoadZones_Callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new rows = SQL_GetRowCount(hndl), Type;
		
		for(new i=0; i<rows; i++)
		{
			SQL_FetchRow(hndl);
			
			Type = SQL_FetchInt(hndl, 6);
			
			if(0 <= Type <= 1) // main start/end zones
			{
				for(new z=0; z<6; z++)
				{
					g_main[Type][(z/3)*7][z%3] = SQL_FetchFloat(hndl, z);
				}
				
				CreateZonePoints(g_main[Type]);
				EnableZone(g_main_ready[Type], true);
			}
			else if(2 <= Type <= 3) // bonus start/end zones
			{
				for(new z=0; z<6; z++)
				{
					g_bonus[Type%2][(z/3)*7][z%3] = SQL_FetchFloat(hndl, z);
				}
				
				CreateZonePoints(g_bonus[Type%2]);
				EnableZone(g_bonus_ready[Type%2], true);
			}
			else if(Type == 4) // anti-cheat zone
			{
				for(new z=0; z<6; z++)
				{
					g_anticheat[g_anticheat_count][(z/3)*7][z%3] = SQL_FetchFloat(hndl, z);
				}
				
				CreateZonePoints(g_anticheat[g_anticheat_count++]);
			}
			else if(Type == 5) // free style zone
			{
				for(new z=0; z<6; z++)
				{
					g_freestyle[g_freestyle_count][(z/3)*7][z%3] = SQL_FetchFloat(hndl, z);
				}
				
				CreateZonePoints(g_freestyle[g_freestyle_count++]);
			}
		}
		
		Call_StartForward(g_fwdOnZonesLoaded);
		Call_Finish();
	}
	else
	{
		LogError(error);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(!IsFakeClient(client))
	{
		if(IsPlayerAlive(client))
		{
			if(g_main_ready[0] && g_main_ready[1])
			{
				g_main_info[client][0] = IsInsideZone(client, g_main[0]);
				g_main_info[client][1] = IsInsideZone(client, g_main[1]);
				if(g_main_info[client][0]) // Is in starting zone
				{
					if(GetClientVelocity(client, true, true, true) > g_prespeed)
					{
						if(GetEntityMoveType(client) != MOVETYPE_NOCLIP)
							TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, Float:{0, 0, 0});
					}
					
					if(GetEntityFlags(client) & FL_ONGROUND)
						StartTimer(client, TIMER_MAIN);
				}
				else if(g_main_info[client][1]) // Is in end zone
				{
					if(IsBeingTimed(client, TIMER_MAIN))
						FinishTimer(client);
				}
			}
			if(g_bonus_ready[0] && g_bonus_ready[1])
			{
				g_bonus_info[client][0] = IsInsideZone(client, g_bonus[0]);
				g_bonus_info[client][1] = IsInsideZone(client, g_bonus[1]);
				if(g_bonus_info[client][0]) // Is in starting zone
				{
					if(GetClientVelocity(client, true, true, true) > g_prespeed)
					{
						if(GetEntityMoveType(client) != MOVETYPE_NOCLIP)
							TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, Float:{0, 0, 0});
					}
					
					if(GetEntityFlags(client) & FL_ONGROUND)
						StartTimer(client, TIMER_BONUS);
				}
				else if(g_bonus_info[client][1]) // Is in end zone
				{
					if(IsBeingTimed(client, TIMER_BONUS))
						FinishTimer(client);
				}
			}
			
			for(new i=0; i<g_anticheat_count; i++)
				if(IsInsideZone(client, g_anticheat[i]))
				{
					if(IsBeingTimed(client, TIMER_ANY))
					{
						StopTimer(client);
						PrintColorText(client, "%s%sYour timer has been stopped for using a shortcut.",
							g_msg_start,
							g_msg_textcol);
					}
				}
		}
	}
}