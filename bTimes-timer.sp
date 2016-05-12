#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "[bTimes] timer",
	author = "blacky",
	description = "The timer portion of the bTimes plugin",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <bTimes-zones>
#include <bTimes-timer>
#include <bTimes-ranks>
#include <bTimes-random>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>

// database
new Handle:g_DB = INVALID_HANDLE;

// current map info
new 	String:g_sMapName[64],
	Handle:g_MapList;
new 	Float:g_WorldRecord[MAX_TYPES][MAX_STYLES];
	
//new	bool:g_bTimesLoadedOnce = false;

// Player timer info
new 	Float:g_fStartTime[MAXPLAYERS + 1],
	bool:g_bTiming[MAXPLAYERS + 1];

new 	g_Type[MAXPLAYERS + 1];
new 	g_Style[MAXPLAYERS + 1];
	
new	bool:g_bTimeIsLoaded[MAXPLAYERS + 1],
	Float:g_fTime[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES],
	String:g_sTime[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES][48];

new 	g_Strafes[MAXPLAYERS + 1],
	g_Jumps[MAXPLAYERS + 1],
	g_SWStrafes[MAXPLAYERS + 1][2],
	Float:g_HSWCounter[MAXPLAYERS + 1],
	Float:g_fSpawnTime[MAXPLAYERS + 1];
	
new 	g_Delete[2];
new 	g_Buttons[MAXPLAYERS + 1];

new	Handle:g_hSoundsArray = INVALID_HANDLE;

new	bool:g_bPaused[MAXPLAYERS + 1],
	Float:g_fPauseTime[MAXPLAYERS + 1],
	Float:g_fPausePos[MAXPLAYERS + 1][3];
	
new	String:g_msg_start[128],
	String:g_msg_varcol[128],
	String:g_msg_textcol[128];
	
// Warning
new	Float:g_fWarningTime[MAXPLAYERS + 1];
	
// Sync measurement
new	Float:g_fOldAngle[MAXPLAYERS + 1],
	g_totalSync[MAXPLAYERS + 1],
	g_goodSync[MAXPLAYERS + 1],
	g_goodSyncVel[MAXPLAYERS + 1];
	
// Hint text
new 	String:g_sRecord[MAX_TYPES][MAX_STYLES][48];

// Settings
new 	Handle:g_hTimerDisplay,
	Handle:g_hHintSpeed,
	Handle:g_hAllowYawspeed,
	Handle:g_hAllowPause,
	Handle:g_hChangeClanTag,
	Handle:g_hTimerChangeClanTag,
	Handle:g_hShowTimeLeft,
	Handle:g_hEZHop,
	Handle:g_hAllowStyle[MAX_STYLES];
	
// All map times
new	Handle:g_hTimes[MAX_TYPES][MAX_STYLES],
	Handle:g_hTimesUsers[MAX_TYPES][MAX_STYLES],
	bool:g_bTimesAreLoaded = false;
	
// Forwards
new	Handle:g_fwdOnTimerFinished,
	Handle:g_fwdOnTimerStart_Pre,
	Handle:g_fwdOnTimerStart_Post,
	Handle:g_fwdOnTimesDeleted;

public OnPluginStart()
{
	// Connect to the database
	DB_Connect();
	
	// Server cvars
	g_hHintSpeed 	  	= CreateConVar("timer_hintspeed", "0.1", "Changes the hint text update speed (bottom center text)", 0, true, 0.1);
	g_hAllowYawspeed 	= CreateConVar("timer_allowyawspeed", "0", "Lets players use +left/+right commands without stopping their timer.", 0, true, 0.0, true, 1.0);
	g_hAllowPause	 	= CreateConVar("timer_allowpausing", "1", "Lets players use the !pause/!unpause commands.", 0, true, 0.0, true, 1.0);
	g_hChangeClanTag 	= CreateConVar("timer_changeclantag", "1", "Means player clan tags will show their current timer time.", 0, true, 0.0, true, 1.0);
	g_hShowTimeLeft  	= CreateConVar("timer_showtimeleft", "1", "Shows the time left until a map change on the right side of player screens.", 0, true, 0.0, true, 1.0);
	g_hEZHop 		= CreateConVar("timer_ezhop", "1", "No jump height loss when bunnyhopping.", 0, true, 0.0, true, 1.0);
	
	HookConVarChange(g_hHintSpeed, OnTimerHintSpeedChanged);
	HookConVarChange(g_hChangeClanTag, OnChangeClanTagChanged);
	
	decl String:sCvar[32], String:sDesc[128];
	for(new Style = 1; Style < MAX_STYLES; Style++)
	{
		GetStyleAbbr(Style, sCvar, sizeof(sCvar));
		Format(sCvar, sizeof(sCvar), "timer_allowstyle_%s", sCvar);
		
		GetStyleName(Style, sDesc, sizeof(sDesc));
		Format(sDesc, sizeof(sDesc), "Allow %s style?", sDesc);
		
		g_hAllowStyle[Style] = CreateConVar(sCvar, "1", sDesc, 0, true, 0.0, true, 1.0);
	}
	
	AutoExecConfig(true, "timer", "timer");
	
	// Event hooks
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("player_jump", Event_PlayerJump, EventHookMode_Pre);
	
	// Admin control
	RegAdminCmd("sm_timer", SM_Timer, ADMFLAG_CHEATS, "Opens the admin timer menu.");
	RegAdminCmd("sm_delete", SM_Delete, ADMFLAG_CHEATS, "Deletes map times.");
	RegAdminCmd("sm_spj", SM_SPJ, ADMFLAG_GENERIC, "Check the strafes per jump ratios for any player.");
	
	// Player commands
	RegConsoleCmdEx("sm_stop", SM_StopTimer, "Stops your timer.");
	
	RegConsoleCmdEx("sm_wr", SM_WorldRecord, "Shows all the times for the specified map.");
	RegConsoleCmdEx("sm_wrw", SM_WorldRecordW, "Shows all the W-Only times for the specified map.");
	RegConsoleCmdEx("sm_wrsw", SM_WorldRecordSW, "Shows all the sideways times for the specified map.");
	RegConsoleCmdEx("sm_wrstam", SM_WorldRecordStam, "Shows all the Stamina times for the specified map.");
	RegConsoleCmdEx("sm_wrhsw", SM_WorldRecordHSW, "Shows all the Half-Sideways times for the specified map.");
	RegConsoleCmdEx("sm_bwr", SM_BWorldRecord, "Shows bonus record for a map");
	RegConsoleCmdEx("sm_wrb", SM_BWorldRecord, "Shows bonus record for a map");
	
	RegConsoleCmdEx("sm_time", SM_Time, "Usage: sm_time or nothing. Shows your time on a given map. With no map given, it will tell you your time on the current map.");
	RegConsoleCmdEx("sm_pr", SM_Time, "Usage: sm_pr or nothing. Shows your time on a given map. With no map given, it will tell you your time on the current map.");
	RegConsoleCmdEx("sm_timew", SM_TimeW, "Like sm_time but for W-Only times.");
	RegConsoleCmdEx("sm_prw", SM_TimeW, "Like sm_pr but for W-Only times.");
	RegConsoleCmdEx("sm_timesw", SM_TimeSW, "Like sm_time but for Sideways times.");
	RegConsoleCmdEx("sm_prsw", SM_TimeSW, "Like sm_prsw but for Sideways times.");
	RegConsoleCmdEx("sm_timestam", SM_TimeStam, "Like sm_time but for Stamina times.");
	RegConsoleCmdEx("sm_prstam", SM_TimeStam, "Like sm_prsw but for Stamina times.");
	RegConsoleCmdEx("sm_timehsw", SM_TimeHSW, "Like sm_time but for Half-Sideways times.");
	RegConsoleCmdEx("sm_prhsw", SM_TimeHSW, "Like sm_prsw but for Half-Sideways times.");
	RegConsoleCmdEx("sm_btime", SM_BTime, "Like sm_time but for Bonus times.");
	RegConsoleCmdEx("sm_bpr", SM_BTime, "Like sm_pr but for Bonus times.");
	
	RegConsoleCmdEx("sm_style", SM_Style, "Switch to normal, w, or sideways style.");
	RegConsoleCmdEx("sm_mode", SM_Style, "Switches you to normal, w, or sideways style.");
	RegConsoleCmdEx("sm_normal", SM_Normal, "Switches you to normal style.");
	RegConsoleCmdEx("sm_n", SM_Normal, "Switches you to normal style.");
	RegConsoleCmdEx("sm_wonly", SM_WOnly, "Switches you to W-Only style.");
	RegConsoleCmdEx("sm_w", SM_WOnly, "Switches you to W-Only style.");
	RegConsoleCmdEx("sm_sideways", SM_Sideways, "Switches you to sideways style.");
	RegConsoleCmdEx("sm_sw", SM_Sideways, "Switches you to sideways style.");
	RegConsoleCmdEx("sm_stamina", SM_Stamina, "Switches you to stamina style.");
	RegConsoleCmdEx("sm_stam", SM_Stamina, "Switches you to stamina style.");
	RegConsoleCmdEx("sm_hsw", SM_HalfSideways, "Switches you to half-sideways timer.");
	
	RegConsoleCmdEx("sm_practice", SM_Practice, "Puts you in noclip. Stops your timer.");
	RegConsoleCmdEx("sm_p", SM_Practice, "Puts you in noclip. Stops your timer.");
	
	RegConsoleCmdEx("sm_fullhud", SM_Fullhud, "Shows all info in the hint text when being timed.");
	RegConsoleCmdEx("sm_maxinfo", SM_Fullhud, "Shows all info in the hint text when being timed.");
	RegConsoleCmdEx("sm_display", SM_Fullhud, "Shows all info in the hint text when being timed.");
	RegConsoleCmdEx("sm_hud", SM_Hud, "Change what shows up on the right side of your hud.");
	
	RegConsoleCmdEx("sm_truevel", SM_TrueVelocity, "Toggles between 2D and 3D velocity velocity meters");
	RegConsoleCmdEx("sm_velocity", SM_TrueVelocity, "Toggles between 2D and 3D velocity velocity meters");
	
	RegConsoleCmdEx("sm_pause", SM_Pause, "Pauses your timer and freezes you.");
	RegConsoleCmdEx("sm_unpause", SM_Unpause, "Unpauses your timer and unfreezes you.");
	RegConsoleCmdEx("sm_resume", SM_Unpause, "Unpauses your timer and unfreezes you.");
	
	// Makes FindTarget() work properly
	LoadTranslations("common.phrases");
	
	for(new Style = 0; Style < MAX_STYLES; Style++)
	{
		g_hTimes[TIMER_MAIN][Style]      = CreateArray(2, 1);
		g_hTimesUsers[TIMER_MAIN][Style] = CreateArray(ByteCountToCells(MAX_NAME_LENGTH), 0);
	}
	
	g_hTimes[TIMER_BONUS][STYLE_NORMAL]      = CreateArray(2, 1);
	g_hTimesUsers[TIMER_BONUS][STYLE_NORMAL] = CreateArray(ByteCountToCells(MAX_NAME_LENGTH), 0);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	// Create natives
	CreateNative("OpenTimerMenu", Native_OpenTimerMenu);
	CreateNative("StartTimer", Native_StartTimer);
	CreateNative("StopTimer", Native_StopTimer);
	CreateNative("IsBeingTimed", Native_IsBeingTimed);
	CreateNative("FinishTimer", Native_FinishTimer);
	CreateNative("GetClientStyle", Native_GetClientStyle);
	CreateNative("IsTimerPaused", Native_IsTimerPaused);
	CreateNative("IsStyleAllowed", Native_IsStyleAllowed);
	
	g_fwdOnTimerStart_Pre  = CreateGlobalForward("OnTimerStart_Pre", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnTimerStart_Post = CreateGlobalForward("OnTimerStart_Post", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnTimerFinished   = CreateGlobalForward("OnTimerFinished", ET_Event, Param_Cell, Param_Float, Param_Cell, Param_Cell);
	g_fwdOnTimesDeleted    = CreateGlobalForward("OnTimesDeleted", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	
	return APLRes_Success;
}

public OnMapStart()
{
	// Set the map id
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	
	g_MapList = ReadMapList();
	
	g_bTimesAreLoaded = false;
	
	decl String:sStyleAbbr[8];
	for(new Style = 0; Style < MAX_STYLES; Style++)
	{
		GetStyleAbbr(Style, sStyleAbbr, sizeof(sStyleAbbr));
		StringToUpper(sStyleAbbr);
		
		FormatEx(g_sRecord[TIMER_MAIN][Style], 48, "WR%s: Loading..", sStyleAbbr);
	}
	
	FormatEx(g_sRecord[TIMER_BONUS][STYLE_NORMAL], 48, "BWR: Loading..");
	
	// Start hud hint timer display
	g_hTimerDisplay = CreateTimer(GetConVarFloat(g_hHintSpeed), LoopTimerDisplay, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	
	// record sounds are held in a config file
	LoadRecordSounds();
	
	// Key hint text messages
	CreateTimer(1.0, Timer_SpecList, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public OnEntityCreated(entity, const String:classname[])
{
	// For the MVP thing
	if(StrContains(classname, "player_manager") != -1)
	{
		SDKHook(entity, SDKHook_ThinkPost, PlayerManager_OnThinkPost);
	}
}

public OnConfigsExecuted()
{
	if(GetConVarInt(g_hChangeClanTag) == 0)
	{
		KillTimer(g_hTimerChangeClanTag);
	}
	else
	{
		g_hTimerChangeClanTag = CreateTimer(1.0, SetClanTag, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
}

public OnClientDisconnect(client)
{
	// Remove client's time in memory for other clients that take that client index later
	ResetClientInfo(client);
}

public bool:OnClientConnect(client)
{
	for(new Style = 0; Style < MAX_STYLES; Style++)
	{
		Format(g_sTime[client][TIMER_MAIN][Style], 48, "Best: Loading..");
	}
	Format(g_sTime[client][TIMER_BONUS][STYLE_NORMAL], 48, "Best: Loading..");
	
	return true;
}

public OnPlayerIDLoaded(client)
{
	if(g_bTimesAreLoaded == true)
	{ 
		DB_LoadPlayerInfo(client);
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

public OnZonesLoaded()
{
	DB_LoadTimes(true);
}

public Action:OnTimerStart_Pre(client, Type, Style)
{
	// Fixes a bug for players to completely cheat times by spawning in weird parts of the map
	if(GetEngineTime() < (g_fSpawnTime[client] + 0.1))
	{
		return Plugin_Handled;
	}
	
	// Don't start if their speed isn't default
	if(GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") != 1.0)
	{
		WarnClient(client, "Your movement speed is off. Type !normalspeed to set it to default.");
		return Plugin_Handled;
	}
	
	// Don't start if they are in noclip
	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
	{
		return Plugin_Handled;
	}
	
	// Don't start if they are a fake client
	if(IsFakeClient(client))
	{
		return Plugin_Handled;
	}
	
	// Don't start if their gravity isn't normal
	if(GetEntityGravity(client) != 0.0)
	{
		SetEntityGravity(client, 0.0);
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

public OnTimerStart_Post(client, Type, Style)
{
	SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
}

public OnTimerHintSpeedChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	KillTimer(g_hTimerDisplay);
	g_hTimerDisplay = CreateTimer(GetConVarFloat(convar), LoopTimerDisplay, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public OnChangeClanTagChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(GetConVarInt(convar) == 0)
	{
		KillTimer(g_hTimerChangeClanTag);
	}
	else
	{
		g_hTimerChangeClanTag = CreateTimer(1.0, SetClanTag, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
}

public PlayerManager_OnThinkPost(entity)
{
	// Set MVP stars to top times
	//SetEntDataArray(entity, g_iMVPs_offset, TopTimesCount, MAXPLAYERS+1, 4, true);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Player timers should stop when they die
	StopTimer(client);
}

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Player timers should stop when they switch teams
	StopTimer(client);
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Anti-time cheat
	g_fSpawnTime[client] = GetEngineTime();
	
	// Player timers should stop when they spawn
	StopTimer(client);
}

public Action:Event_PlayerJump(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Increase jump count for the hud hint text, it resets to 0 when StartTimer for the client is called
	if(IsBeingTimed(client, TIMER_ANY))
		g_Jumps[client]++;
	
	// if server allows ezhop, use it
	if(GetConVarBool(g_hEZHop) == true && (g_Style[client] != STYLE_STAMINA || g_Type[client] == TIMER_BONUS))
	{
		SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
	}
	
	if(GetConVarBool(g_hEZHop) == false && g_Style[client] == STYLE_STAMINA)
	{
		SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
	}
}

// Toggles amount of info display in hint text area
public Action:SM_Fullhud(client, args)
{
	if(!(GetClientSettings(client) & SHOW_HINT))
	{
		PrintColorText(client, "%s%sShowing advanced timer hint text.", 
			g_msg_start, 
			g_msg_textcol);
	}
	else
	{
		PrintColorText(client, "%s%sShowing simple timer hint text.", 
			g_msg_start, 
			g_msg_textcol);
	}
	
	SetClientSettings(client, GetClientSettings(client)^SHOW_HINT);
	
	return Plugin_Handled;
}

// Toggles between 2d vector and 3d vector velocity
public Action:SM_TrueVelocity(client, args)
{	
	if(GetClientSettings(client) & SHOW_2DVEL)
	{
		PrintColorText(client, "%s%sShowing %strue %svelocity",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol);
	}
	else
	{
		PrintColorText(client, "%s%sShowing %snormal %svelocity",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol);
	}
	
	SetClientSettings(client, GetClientSettings(client)^SHOW_2DVEL);
	
	return Plugin_Handled;
}

public Action:SM_SPJ(client, args)
{
	// Get target
	decl String:sArg[255];
	GetCmdArgString(sArg, sizeof(sArg));
	
	// Write data to send to query callback
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, GetClientUserId(client));
	WritePackString(pack, sArg);
	
	// Do query
	decl String:query[512];
	Format(query, sizeof(query), "SELECT User, SPJ, SteamID, MStrafes, MJumps FROM (SELECT t2.User, t2.SteamID, AVG(t1.Strafes/t1.Jumps) AS SPJ, SUM(t1.Strafes) AS MStrafes, SUM(t1.Jumps) AS MJumps FROM times AS t1, players AS t2 WHERE t1.PlayerID=t2.PlayerID  AND t1.Style=0 GROUP BY t1.PlayerID ORDER BY AVG(t1.Strafes/t1.Jumps) DESC) AS x WHERE MStrafes > 100");
	SQL_TQuery(g_DB, SPJ_Callback, query, pack);
	
	return Plugin_Handled;
}

public SPJ_Callback(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{
		// Get data from command arg
		decl String:sTarget[MAX_NAME_LENGTH];
		
		ResetPack(pack);
		new client = GetClientOfUserId(ReadPackCell(pack));
		ReadPackString(pack, sTarget, sizeof(sTarget));
		
		new len = strlen(sTarget);
		
		decl String:item[255], String:info[255], String:sAuth[32], String:sName[MAX_NAME_LENGTH];
		new 	Float:SPJ, Strafes, Jumps;
		
		// Create menu
		new Handle:menu = CreateMenu(Menu_ShowSPJ);
		
		new 	rows = SQL_GetRowCount(hndl);
		for(new i=0; i<rows; i++)
		{
			SQL_FetchRow(hndl);
			
			SQL_FetchString(hndl, 0, sName, sizeof(sName));
			SPJ = SQL_FetchFloat(hndl, 1);
			SQL_FetchString(hndl, 2, sAuth, sizeof(sAuth));
			Strafes = SQL_FetchInt(hndl, 3);
			Jumps = SQL_FetchInt(hndl, 4);
			
			if(StrContains(sName, sTarget) != -1 || len == 0)
			{
				Format(item, sizeof(item), "%.1f - %s",
					SPJ,
					sName);
				
				Format(info, sizeof(info), "%s <%s> SPJ: %.1f, Strafes: %d, Jumps: %d",
					sName,
					sAuth,
					SPJ,
					Strafes,
					Jumps);
					
				AddMenuItem(menu, info, item);
			}
		}
		SetMenuTitle(menu, "Showing strafes per jump\nSelect an item for more info\n ");
		
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
	{
		LogError(error);
	}
	CloseHandle(pack);
}

public Menu_ShowSPJ(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[255];
		GetMenuItem(menu, param2, info, sizeof(info));
		PrintToChat(param1, info);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_Timer(client, args)
{
	return Plugin_Handled;
}

// Admin command for deleting times
public Action:SM_Delete(client, args)
{
	if(args == 0)
	{
		PrintHelp(client);
	}
	else if(args == 1)
	{
		decl String:input[128];
		GetCmdArgString(input, sizeof(input));
		new value = StringToInt(input);
		if(value != 0)
		{
			AdminCmd_DeleteRecord(client, value, value);
		}
		/*
		else if(StrEqual(input, "all", false))
		{
			AdminCmd_DeleteRecord_All(client);
		}
		*/
	}
	else if(args == 2)
	{
		decl String:sValue0[128], String:sValue1[128];
		GetCmdArg(1, sValue0, sizeof(sValue0));
		GetCmdArg(2, sValue1, sizeof(sValue1));
		AdminCmd_DeleteRecord(client, StringToInt(sValue0), StringToInt(sValue1));
	}
	return Plugin_Handled;
}

AdminCmd_DeleteRecord(client, value1, value2)
{
	new Handle:menu = CreateMenu(AdminMenu_DeleteRecord);
	
	if(value1 == value2)
		SetMenuTitle(menu, "Delete record %d", value1);
	else
		SetMenuTitle(menu, "Delete records %d to %d", value1, value2);
		
	g_Delete[0] = value1;
	g_Delete[1] = value2;
	
	decl String:sType[32], String:sStyle[32], String:sTypeStyle[64], String:sInfo[8];
	
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
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public AdminMenu_DeleteRecord(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[16], String:sTypeStyle[2][8];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrContains(info, ";") != -1)
		{
			ExplodeString(info, ";", sTypeStyle, 2, 8);
			
			new Type  = StringToInt(sTypeStyle[0]);
			new Style = StringToInt(sTypeStyle[1]);
			
			DB_DeleteRecord(param1, Type, Style, g_Delete[0], g_Delete[1]);
			DB_UpdateRanks(g_sMapName, Type, Style);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_StopTimer(client, args)
{
	StopTimer(client);
	return Plugin_Handled;
}

public Action:SM_WorldRecord(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
			DB_DisplayRecords(client, g_sMapName, TIMER_MAIN, STYLE_NORMAL);
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(FindStringInArray(g_MapList, arg) != -1)
			{
				DB_DisplayRecords(client, arg, TIMER_MAIN, STYLE_NORMAL);
			}
			else
			{
				PrintColorText(client, "%s%sNo map found named %s%s",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					arg);
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_WorldRecordW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_DisplayRecords(client, g_sMapName, TIMER_MAIN, STYLE_WONLY);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(FindStringInArray(g_MapList, arg) != -1)
			{
				DB_DisplayRecords(client, arg, TIMER_MAIN, STYLE_WONLY);
			}
			else
			{
				PrintColorText(client, "%s%sNo map found named %s%s",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					arg);
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_WorldRecordSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_DisplayRecords(client, g_sMapName, TIMER_MAIN, STYLE_SIDEWAYS);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(FindStringInArray(g_MapList, arg) != -1)
			{
				DB_DisplayRecords(client, arg, TIMER_MAIN, STYLE_SIDEWAYS);
			}
			else
			{
				PrintColorText(client, "%s%sNo map found named %s%s",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					arg);
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_WorldRecordStam(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_DisplayRecords(client, g_sMapName, TIMER_MAIN, STYLE_STAMINA);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(FindStringInArray(g_MapList, arg) != -1)
			{
				DB_DisplayRecords(client, arg, TIMER_MAIN, STYLE_STAMINA);
			}
			else
			{
				PrintColorText(client, "%s%sNo map found named %s%s",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					arg);
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_WorldRecordHSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_DisplayRecords(client, g_sMapName, TIMER_MAIN, STYLE_HALFSIDEWAYS);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(FindStringInArray(g_MapList, arg) != -1)
			{
				DB_DisplayRecords(client, arg, TIMER_MAIN, STYLE_HALFSIDEWAYS);
			}
			else
			{
				PrintColorText(client, "%s%sNo map found named %s%s",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					arg);
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_BWorldRecord(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_DisplayRecords(client, g_sMapName, TIMER_BONUS, STYLE_NORMAL);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(FindStringInArray(g_MapList, arg) != -1)
			{
				DB_DisplayRecords(client, arg, TIMER_BONUS, STYLE_NORMAL);
			}
			else
			{
				PrintColorText(client, "%s%sNo map found named %s%s",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					arg);
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_Time(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowTime(client, client, g_sMapName, TIMER_MAIN, STYLE_NORMAL);
		}
		else if(args == 1)
		{
			decl String:arg[250];
			GetCmdArgString(arg, sizeof(arg));
			if(arg[0] == '@')
			{
				ReplaceString(arg, 250, "@", "");
				DB_ShowTimeAtRank(client, g_sMapName, StringToInt(arg), TIMER_MAIN, STYLE_NORMAL);
			}
			else
			{
				new target = FindTarget(client, arg, true, false);
				new bool:mapValid = (FindStringInArray(g_MapList, arg) != -1);
				if(mapValid == true)
				{
					DB_ShowTime(client, client, arg, TIMER_MAIN, STYLE_NORMAL);
				}
				if(target != -1)
				{
					DB_ShowTime(client, target, g_sMapName, TIMER_MAIN, STYLE_NORMAL);
				}
				if(!mapValid && target == -1)
				{
					PrintColorText(client, "%s%sNo map or player found named %s%s",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						arg);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_TimeW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowTime(client, client, g_sMapName, TIMER_MAIN, STYLE_WONLY);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(arg[0] == '@')
			{
				ReplaceString(arg, 250, "@", "");
				DB_ShowTimeAtRank(client, g_sMapName, StringToInt(arg), TIMER_MAIN, STYLE_WONLY);
			}
			else
			{
				new target = FindTarget(client, arg, true, false);
				new bool:mapValid = (FindStringInArray(g_MapList, arg) != -1);
				
				if(mapValid)
				{
					DB_ShowTime(client, client, arg, TIMER_MAIN, STYLE_WONLY);
				}
				
				if(0 < target <= MaxClients)
				{
					DB_ShowTime(client, target, g_sMapName, TIMER_MAIN, STYLE_WONLY);
				}
				
				if(!mapValid && !(0 < target <= MaxClients))
				{
					PrintColorText(client, "%s%sNo map or player found named %s%s",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						arg);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_TimeSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowTime(client, client, g_sMapName, TIMER_MAIN, STYLE_SIDEWAYS);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(arg[0] == '@')
			{
				ReplaceString(arg, 250, "@", "");
				DB_ShowTimeAtRank(client, g_sMapName, StringToInt(arg), TIMER_MAIN, STYLE_SIDEWAYS);
			}
			else
			{
				new target = FindTarget(client, arg, true, false);
				new bool:mapValid = (FindStringInArray(g_MapList, arg) != -1);
				
				if(mapValid)
				{
					DB_ShowTime(client, client, arg, TIMER_MAIN, STYLE_SIDEWAYS);
				}
				
				if(0 < target <= MaxClients)
				{
					DB_ShowTime(client, target, g_sMapName, TIMER_MAIN, STYLE_SIDEWAYS);
				}
				
				if(!mapValid && !(0 < target <= MaxClients))
				{
					PrintColorText(client, "%s%sNo map or player found named %s%s",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						arg);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_TimeStam(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowTime(client, client, g_sMapName, TIMER_MAIN, STYLE_STAMINA);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(arg[0] == '@')
			{
				ReplaceString(arg, 250, "@", "");
				DB_ShowTimeAtRank(client, g_sMapName, StringToInt(arg), TIMER_MAIN, STYLE_STAMINA);
			}
			else
			{
				new target = FindTarget(client, arg, true, false);
				new bool:mapValid = (FindStringInArray(g_MapList, arg) != -1);
				
				if(mapValid)
				{
					DB_ShowTime(client, client, arg, TIMER_MAIN, STYLE_STAMINA);
				}
				
				if(0 < target <= MaxClients)
				{
					DB_ShowTime(client, target, g_sMapName, TIMER_MAIN, STYLE_STAMINA);
				}
				
				if(!mapValid && !(0 < target <= MaxClients))
				{
					PrintColorText(client, "%s%sNo map or player found named %s%s",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						arg);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_TimeHSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowTime(client, client, g_sMapName, TIMER_MAIN, STYLE_HALFSIDEWAYS);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(arg[0] == '@')
			{
				ReplaceString(arg, 250, "@", "");
				DB_ShowTimeAtRank(client, g_sMapName, StringToInt(arg), TIMER_MAIN, STYLE_HALFSIDEWAYS);
			}
			else
			{
				new target = FindTarget(client, arg, true, false);
				new bool:mapValid = (FindStringInArray(g_MapList, arg) != -1);
				
				if(mapValid)
				{
					DB_ShowTime(client, client, arg, TIMER_MAIN, STYLE_HALFSIDEWAYS);
				}
				
				if(0 < target <= MaxClients)
				{
					DB_ShowTime(client, target, g_sMapName, TIMER_MAIN, STYLE_HALFSIDEWAYS);
				}
				
				if(!mapValid && !(0 < target <= MaxClients))
				{
					PrintColorText(client, "%s%sNo map or player found named %s%s",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						arg);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_BTime(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowTime(client, client, g_sMapName, TIMER_BONUS, STYLE_NORMAL);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(arg[0] == '@')
			{
				ReplaceString(arg, 250, "@", "");
				DB_ShowTimeAtRank(client, g_sMapName, StringToInt(arg), TIMER_BONUS, STYLE_NORMAL);
			}
			else
			{
				new target = FindTarget(client, arg, true, false);
				new bool:mapValid = (FindStringInArray(g_MapList, arg) != -1);
				
				if(mapValid)
				{
					DB_ShowTime(client, client, arg, TIMER_BONUS, STYLE_NORMAL);
				}
				
				if(0 < target <= MaxClients)
				{
					DB_ShowTime(client, target, g_sMapName, TIMER_BONUS, STYLE_NORMAL);
				}
				
				if(!mapValid && !(0 < target <= MaxClients))
				{
					PrintColorText(client, "%s%sNo map or player found named %s%s",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						arg);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_Style(client, args)
{
	new Handle:menu = CreateMenu(Menu_Style);
	
	SetMenuTitle(menu, "Change Style");
	decl String:sStyle[32], String:sInfo[16];
	
	for(new Style = 0; Style < MAX_STYLES; Style++)
	{
		if(IsStyleAllowed(Style))
		{
			GetStyleName(Style, sStyle, sizeof(sStyle));
			
			IntToString(Style, sInfo, sizeof(sInfo));
			Format(sInfo, sizeof(sInfo), ";%s", sInfo);
			
			AddMenuItem(menu, sInfo, sStyle);
		}
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Menu_Style(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(info[0] == ';')
		{
			ReplaceString(info, sizeof(info), ";", "");
			
			StopTimer(param1);
			g_Style[param1] = StringToInt(info);
			GoToStart(param1);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_Normal(client, args)
{
	StopTimer(client);
	g_Style[client] = STYLE_NORMAL;
	GoToStart(client);
	
	return Plugin_Handled;
}

public Action:SM_Sideways(client, args)
{
	if(IsStyleAllowed(STYLE_SIDEWAYS))
	{
		StopTimer(client);
		g_Style[client] = STYLE_SIDEWAYS;
		GoToStart(client);
	}
	
	return Plugin_Handled;
}

public Action:SM_WOnly(client, args)
{
	if(IsStyleAllowed(STYLE_WONLY))
	{
		StopTimer(client);
		g_Style[client] = STYLE_WONLY;
		GoToStart(client);
	}
	
	return Plugin_Handled;
}

public Action:SM_Stamina(client, args)
{
	if(IsStyleAllowed(STYLE_STAMINA))
	{
		StopTimer(client);
		g_Style[client] = STYLE_STAMINA;
		GoToStart(client);
	}
	
	return Plugin_Handled;
}

public Action:SM_HalfSideways(client, args)
{
	if(IsStyleAllowed(STYLE_HALFSIDEWAYS))
	{
		StopTimer(client);
		g_Style[client] = STYLE_HALFSIDEWAYS;
		GoToStart(client);
	}
	
	return Plugin_Handled;
}

public Action:SM_Practice(client, args)
{
	if(StrContains(g_sMapName, "bhop_exodus") == -1)
	{
		StopTimer(client);
		
		new MoveType:movetype = GetEntityMoveType(client);
		if (movetype != MOVETYPE_NOCLIP)
		{
			SetEntityMoveType(client, MOVETYPE_NOCLIP);
		}
		else
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
		}
	}
	else
	{
		PrintColorText(client, "%s%sYou can't noclip on %s to prevent server crashes.",
			g_msg_start,
			g_msg_textcol,
			g_sMapName);
	}
	
	return Plugin_Handled;
}

public Action:SM_Pause(client, args)
{
	if(GetConVarBool(g_hAllowPause))
	{
		if(!IsInAStartZone(client))
		{
			if(IsBeingTimed(client, TIMER_ANY))
			{
				if(g_bPaused[client] == false)
				{
					if(GetClientVelocity(client, true, true, true) == 0.0)
					{
						GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_fPausePos[client]);
						g_fPauseTime[client]	= GetEngineTime();
						g_bPaused[client] 	= true;
						
						PrintColorText(client, "%s%sTimer paused.",
							g_msg_start,
							g_msg_textcol);
					}
					else
					{
						PrintColorText(client, "%s%sYou can't pause while moving.",
							g_msg_start,
							g_msg_textcol);
					}
				}
				else
				{
					PrintColorText(client, "%s%sYou are already paused.",
						g_msg_start,
						g_msg_textcol);
				}
			}
			else
			{
				PrintColorText(client, "%s%sYou have no timer running.",
					g_msg_start,
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(client, "%s%sYou can't pause while inside a starting zone.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Unpause(client, args)
{
	if(GetConVarBool(g_hAllowPause))
	{
		if(IsBeingTimed(client, TIMER_ANY))
		{
			if(g_bPaused[client] == true)
			{
				// Teleport player to the position they paused at
				TeleportEntity(client, g_fPausePos[client], NULL_VECTOR, Float:{0, 0, 0});
				
				// Set their new start time
				g_fStartTime[client] = GetEngineTime() - (g_fPauseTime[client] - g_fStartTime[client]);
				
				// Unpause
				g_bPaused[client] = false;
				
				PrintColorText(client, "%s%sTimer unpaused.",
					g_msg_start,
					g_msg_textcol);
			}
			else
			{
				PrintColorText(client, "%s%sYou are not currently paused.",
					g_msg_start,
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(client, "%s%sYou have no timer running.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Hud(client, args)
{
	OpenHudMenu(client);
	
	return Plugin_Handled;
}

OpenHudMenu(client)
{
	new Handle:menu = CreateMenu(Menu_Hud);
	SetMenuTitle(menu, "Hud control");
	
	new settings = GetClientSettings(client);
	
	decl String:sInfo[16];
	
	IntToString(KH_TIMELEFT, sInfo, sizeof(sInfo));
	Format(sInfo, sizeof(sInfo), ";%s", sInfo);
	AddMenuItem(menu, sInfo, (settings & KH_TIMELEFT)?"Timeleft: On":"Timeleft: Off");
	
	IntToString(KH_RECORD, sInfo, sizeof(sInfo));
	Format(sInfo, sizeof(sInfo), ";%s", sInfo);
	AddMenuItem(menu, sInfo, (settings & KH_RECORD)?"World record: On":"World record: Off");
	
	IntToString(KH_BEST, sInfo, sizeof(sInfo));
	Format(sInfo, sizeof(sInfo), ";%s", sInfo);
	AddMenuItem(menu, sInfo, (settings & KH_BEST)?"Personal best: On":"Personal best: Off");
	
	IntToString(KH_SPECS, sInfo, sizeof(sInfo));
	Format(sInfo, sizeof(sInfo), ";%s", sInfo);
	AddMenuItem(menu, sInfo, (settings & KH_SPECS)?"Spectator count: On":"Spectator count: Off");
	
	IntToString(KH_SYNC, sInfo, sizeof(sInfo));
	Format(sInfo, sizeof(sInfo), ";%s", sInfo);
	AddMenuItem(menu, sInfo, (settings & KH_SYNC)?"Sync: On":"Sync: Off");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_Hud(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:sInfo[32];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		if(sInfo[0] == ';')
		{
			ReplaceString(sInfo, sizeof(sInfo), ";", "");
			
			new iInfo = StringToInt(sInfo);
			SetClientSettings(param1, GetClientSettings(param1) ^ iInfo);
			
			OpenHudMenu(param1);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SetClanTag(Handle:timer, any:data)
{
	decl String:sTag[32];
	for(new client=1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(IsPlayerAlive(client) && !IsFakeClient(client))
			{
				GetClanTagString(client, sTag, sizeof(sTag));
				CS_SetClientClanTag(client, sTag);
			}
		}
	}
}

GetClanTagString(client, String:tag[], maxlength)
{
	if(g_bTiming[client] == true)
	{
		if(g_Type[client] == TIMER_BONUS)
		{
			FormatEx(tag, maxlength, "B :: ");
		}
		else
		{
			decl String:sStyleAbbr[8];
			GetStyleAbbr(g_Style[client], sStyleAbbr, sizeof(sStyleAbbr));
			StringToUpper(sStyleAbbr);
			
			FormatEx(tag, maxlength, "%s :: ", sStyleAbbr);
		}
		
		if(IsInAStartZone(client))
		{
			FormatEx(tag, maxlength, "START");
			return;
		}
		
		if(g_bPaused[client])
		{
			FormatEx(tag, maxlength, "PAUSED");
			return;
		}
		
		decl String:sTime[32];
		
		new Float:fTime = GetClientTimer(client);
		FormatPlayerTime(fTime, sTime, sizeof(sTime), false, 0);
		SplitString(sTime, ".", sTime, sizeof(sTime));
		Format(tag, maxlength, "%s%s", tag, sTime);
	}
	else
	{
		FormatEx(tag, maxlength, "NO TIMER");
	}
}

ResetClientInfo(client)
{
	// Set player times to null
	for(new Style=0; Style<MAX_STYLES; Style++)
	{
		g_fTime[client][TIMER_MAIN][Style] = 0.0;
	}
	
	g_fTime[client][TIMER_BONUS][STYLE_NORMAL] = 0.0;
	
	// Set style to normal (default)
	g_Style[client] = STYLE_NORMAL;
	
	// Unpause timers
	g_bPaused[client] = false;
	
	g_bTimeIsLoaded[client] = false;
}

public Action:LoopTimerDisplay(Handle:timer, any:data)
{
	new String:timerString[256];
	for(new client=1; client<=MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(!(GetClientButtons(client) & IN_SCORE))
			{
				if(IsPlayerAlive(client))
				{
					if(GetPlayerID(client) != 0)
					{
						new time = RoundToFloor(g_fTime[client][TIMER_MAIN][STYLE_NORMAL]);
						if(g_fTime[client][TIMER_MAIN][STYLE_NORMAL] == 0.0 || g_fTime[client][TIMER_MAIN][STYLE_NORMAL] > 2000.0)
							time = 2000;
						SetEntProp(client, Prop_Data, "m_iFrags", -time);
					}
					if(IsBeingTimed(client, TIMER_ANY))
					{					
						if(g_bPaused[client] == false)
						{
							if(GetClientButtons(client) & IN_USE || GetClientSettings(client) & SHOW_HINT)
							{
								GetTimerAdvancedString(client, timerString, sizeof(timerString));
								PrintHintText(client, "%s", timerString);
							}
							else
							{
								GetTimerSimpleString(client, timerString, sizeof(timerString));
								PrintHintText(client, "%s", timerString);
							}
						}
						else
						{
							GetTimerPauseString(client, timerString, sizeof(timerString));
							PrintHintText(client, timerString);
						}
					}
					else
					{
						new Float:vel = GetClientVelocity(client, true, true, bool:(GetClientSettings(client) & SHOW_2DVEL));
						PrintHintText(client, "%d", RoundToFloor(vel));
					}
				}
				else
				{
					new Target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
					new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
					if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
					{
						if(!IsFakeClient(Target))
						{
							if(IsBeingTimed(Target, TIMER_ANY))
							{
								if(g_bPaused[Target] == false)
								{
									GetTimerAdvancedString(Target, timerString, sizeof(timerString));
									PrintHintText(client, timerString);
								}
								else
								{
									GetTimerPauseString(Target, timerString, sizeof(timerString));
									PrintHintText(client, timerString);
								}
							}
							else
							{
								new Float:vel = GetClientVelocity(Target, true, true, bool:(GetClientSettings(Target) & SHOW_2DVEL));
								PrintHintText(client, "%d", RoundToFloor(vel));
							}
						}
					}
				}
			}
		}
	}
}

GetTimerAdvancedString(client, String:sResult[], maxlength)
{
	if(IsInAStartZone(client))
	{
		Format(sResult, maxlength, "In start zone\n \n%d", 
			RoundToFloor(GetClientVelocity(client, true, true, bool:(GetClientSettings(client) & SHOW_2DVEL))));
	}
	else
	{
		new Float:fTime = GetClientTimer(client);
		new String:sTime[32];
		FormatPlayerTime(fTime, sTime, sizeof(sTime), false, 0);
			
		if(g_Type[client] == TIMER_MAIN)
		{
			decl String:sStyle[32];
			GetStyleName(g_Style[client], sStyle, sizeof(sStyle));
			
			if(g_Style[client] == STYLE_NORMAL || g_Style[client] == STYLE_STAMINA || g_Style[client] == STYLE_HALFSIDEWAYS)
			{
				Format(sResult, maxlength, "%s\nTime: %s (%d)\nJumps: %d\nStrafes: %d\nSpeed: %d",
					sStyle,
					sTime,
					GetPlayerPosition(fTime, TIMER_MAIN, g_Style[client]),
					g_Jumps[client],
					g_Strafes[client],
					RoundToFloor(GetClientVelocity(client, true, true, bool:(GetClientSettings(client) & SHOW_2DVEL))));
			}
			else if(g_Style[client] == STYLE_WONLY)
			{
				Format(sResult, maxlength, "%s%s\nTime: %s (%d)\nJumps: %d\nSpeed: %d",
					sStyle,
					(IsInAFreeStyleZone(client))?" (FS)":"",
					sTime, 
					GetPlayerPosition(fTime, TIMER_MAIN, g_Style[client]),
					g_Jumps[client],
					RoundToFloor(GetClientVelocity(client, true, true, bool:(GetClientSettings(client) & SHOW_2DVEL))));
			}
			else if(g_Style[client] == STYLE_SIDEWAYS)
			{
				Format(sResult, maxlength, "%s%s\nTime: %s (%d)\nJumps: %d\nStrafes: %d\nSpeed: %d",
					sStyle,
					(IsInAFreeStyleZone(client))?" (FS)":"",
					sTime, 
					GetPlayerPosition(fTime, TIMER_MAIN, g_Style[client]),
					g_Jumps[client],
					g_Strafes[client],
					RoundToFloor(GetClientVelocity(client, true, true, bool:(GetClientSettings(client) & SHOW_2DVEL))));
			}
		}
		else if(g_Type[client] == TIMER_BONUS)
		{
			Format(sResult, maxlength, "Bonus\nTime: %s (%d)\nJumps: %d\nStrafes: %d\nSpeed: %d",
				sTime, 
				GetPlayerPosition(fTime, TIMER_BONUS, STYLE_NORMAL),
				g_Jumps[client],
				g_Strafes[client],
				RoundToFloor(GetClientVelocity(client, true, true, bool:(GetClientSettings(client) & SHOW_2DVEL))));
		}
	}
}

GetTimerSimpleString(client, String:sResult[], maxlength)
{
	if(IsInAStartZone(client))
	{
		Format(sResult, maxlength, "In start zone\n \n%d", 
			RoundToFloor(GetClientVelocity(client, true, true, bool:(GetClientSettings(client) & SHOW_2DVEL))));
	}
	else
	{
		new Float:fTime = GetClientTimer(client);
		
		decl String:sTime[32];
		FormatPlayerTime(fTime, sTime, sizeof(sTime), false, 0);
		Format(sResult, maxlength, "%s", sTime);
	}
}

GetTimerPauseString(client, String:buffer[], maxlen)
{
	new Float:fTime = g_fPauseTime[client] - g_fStartTime[client];
	
	decl String:sTime[32];
	FormatPlayerTime(fTime, sTime, sizeof(sTime), false, 0);
	
	Format(buffer, maxlen, "Paused\n \nTime: %s", sTime);
}

GetPlayerPosition(const Float:fTime, Type, Style)
{	
	if(g_bTimesAreLoaded == true)
	{
		new iSize = GetArraySize(g_hTimes[Type][Style]);
		
		for(new idx = 0; idx < iSize; idx++)
		{
			if(fTime <= GetArrayCell(g_hTimes[Type][Style], idx, 1))
			{
				return idx + 1;
			}
		}
		
		return iSize;
	}
	
	return 0;
}

GetPlayerPositionByID(PlayerID, Type, Style)
{
	if(g_bTimesAreLoaded == true)
	{
		new iSize = GetArraySize(g_hTimes[Type][Style]);
		
		for(new idx = 0; idx < iSize; idx++)
		{
			if(PlayerID == GetArrayCell(g_hTimes[Type][Style], idx, 0))
			{
				return idx + 1;
			}
		}
		
		return iSize;
	}
	
	return 0;
}

// Controls what shows up on the right side of players screen, KeyHintText
public Action:Timer_SpecList(Handle:timer, any:data)
{
	// Different arrays for admins and non-admins
	new 	SpecCount[MaxClients+1], AdminSpecCount[MaxClients+1];
	SpecCountToArrays(SpecCount, AdminSpecCount);
	
	new String:message[256];
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(GetKeyHintMessage(client, message, sizeof(message), SpecCount, AdminSpecCount))
			{
				PrintKeyHintText(client, message);
			}
		}
	}
}

SpecCountToArrays(clients[], admins[])
{
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(!IsPlayerAlive(client))
			{
				new Target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
				new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
				if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
				{
					if(!GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective))
						clients[Target]++;
					admins[Target]++;
				}
			}
		}
	}
}

bool:GetKeyHintMessage(client, String:message[], maxlength, SpecCount[], AdminSpecCount[])
{
	FormatEx(message, maxlength, "");
	
	new target;
	
	if(IsPlayerAlive(client))
	{
		target = client;
	}
	else
	{
		target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		new mode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if(!((0 < target <= MaxClients) && (mode == 4 || mode == 5)))
		{
			return false;
		}
	}
	
	new settings = GetClientSettings(client);
	
	if(settings & KH_TIMELEFT)
	{
		new timelimit;
		GetMapTimeLimit(timelimit);
		if(GetConVarBool(g_hShowTimeLeft) && timelimit != 0)
		{
			new timeleft;
			GetMapTimeLeft(timeleft);
			
			if(timeleft <= 0)
			{
				FormatEx(message, maxlength, "Time left: Map finished\n \n");
			}
			else if(timeleft < 60)
			{
				FormatEx(message, maxlength, "Time left: <1 minute\n \n");
			}
			else
			{
				// Format the time left
				new minutes = RoundToFloor(float(timeleft)/60);
				
				FormatEx(message, maxlength, "Time left: %d minutes\n \n", minutes);
			}
		}
	}
	
	if(!IsFakeClient(target))
	{
		new position;
		if(g_Type[target] == TIMER_BONUS)
		{
			if(settings & KH_RECORD)
			{
				Format(message, maxlength, "%s%s\n", message, g_sRecord[TIMER_BONUS][STYLE_NORMAL]);
			}
			
			if(settings & KH_BEST)
			{
				Format(message, maxlength, "%s%s", message, g_sTime[target][TIMER_BONUS][STYLE_NORMAL]);
				if(g_fTime[target][TIMER_BONUS][STYLE_NORMAL] != 0.0)
				{
					position = GetPlayerPositionByID(GetPlayerID(target), TIMER_BONUS, STYLE_NORMAL);
					Format(message, maxlength, "%s (#%d)", message, position);
				}
			}
		}
		else
		{
			if(settings & KH_RECORD)
			{
				Format(message, maxlength, "%s%s\n", message, g_sRecord[TIMER_MAIN][g_Style[target]]);
			}
			
			if(settings & KH_BEST)
			{
				Format(message, maxlength, "%s%s", message, g_sTime[target][TIMER_MAIN][g_Style[target]]);
				if(g_fTime[target][TIMER_MAIN][g_Style[target]] != 0.0)
				{
					position = GetPlayerPositionByID(GetPlayerID(target), TIMER_MAIN, g_Style[target]);
					Format(message, maxlength, "%s (#%d)", message, position);
				}
			}
		}
	}
	
	new bool:bClientIsAdmin = GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective);
	
	if(settings & KH_SYNC)
	{
		if((g_Style[target] == STYLE_NORMAL || g_Style[target] == STYLE_STAMINA) && IsFakeClient(target) == false)
		{
			if(g_bTiming[target] == true)
			{
				if(bClientIsAdmin)
				{
					Format(message, maxlength, "%s\nSync 1: %.2f", message, GetClientSync(target));
					Format(message, maxlength, "%s\nSync 2: %.2f", message, GetClientSync2(target));
				}
				else
				{
					Format(message, maxlength, "%s\nSync: %.2f", message, GetClientSync(target));
				}
			}
			else
			{
				Format(message, maxlength, "%s\n", message);
			}
		}
	}
	
	if(settings & KH_SPECS)
	{
		if(!IsFakeClient(target))
			Format(message, maxlength, "%s\n \nSpectators: %d", message, (bClientIsAdmin)?AdminSpecCount[target]:SpecCount[target]);
		else
			Format(message, maxlength, "%sSpectators: %d", message, (bClientIsAdmin)?AdminSpecCount[target]:SpecCount[target]);
	}
	
	return true;
}

PrintKeyHintText(client, const String:message[])
{
	new Handle:hMessage = StartMessageOne("KeyHintText", client);
	if (hMessage != INVALID_HANDLE) 
	{ 
		BfWriteByte(hMessage, 1); 
		BfWriteString(hMessage, message);
	}
	EndMessage();
}

Float:GetClientSync(client)
{
	if(g_totalSync[client] == 0)
		return 0.0;
	
	return float(g_goodSync[client])/float(g_totalSync[client]) * 100.0;
}

Float:GetClientSync2(client)
{
	if(g_totalSync[client] == 0)
		return 0.0;
	
	return float(g_goodSyncVel[client])/float(g_totalSync[client]) * 100.0;
}

public Native_OpenTimerMenu(Handle:plugin, numParams)
{
	
}

public Native_StartTimer(Handle:plugin, numParams)
{
	new client    = GetNativeCell(1);
	
	new Action:fResult;
	new Type = GetNativeCell(2);
	
	Call_StartForward(g_fwdOnTimerStart_Pre);
	
	Call_PushCell(client);
	Call_PushCell(Type);
	Call_PushCell(g_Style[client]);
	
	Call_Finish(fResult);
	
	if(fResult != Plugin_Handled)
	{
		// for the ghost
		g_Jumps[client]          = 0;
		g_Strafes[client]        = 0;
		g_SWStrafes[client][0]   = 1;
		g_SWStrafes[client][1]   = 1;
		g_bPaused[client]         = false;
		g_totalSync[client]       = 0;
		g_goodSync[client]        = 0;
		g_goodSyncVel[client]     = 0;
		
		StopTimer(client);
		g_Type[client]        = Type;
		g_bTiming[client]     = true;
		g_fStartTime[client]  = GetEngineTime();
		
		Call_StartForward(g_fwdOnTimerStart_Post);
		
		Call_PushCell(client);
		Call_PushCell(Type);
		Call_PushCell(g_Style[client]);
		
		Call_Finish();
	}
}

WarnClient(client, const String:message[])
{
	if(GetEngineTime() > (g_fWarningTime[client] + 10.0))
	{
		PrintColorText(client, "%s%s%s",
			g_msg_start,
			g_msg_textcol,
			message);
			
		g_fWarningTime[client] = GetEngineTime();	
	}
}

public Native_StopTimer(Handle:plugin, numParams)
{
	new client        = GetNativeCell(1);
	
	// prevents a free style zone bug
	if(!IsInAStartZone(client))
	{
		SetEntityFlags(client, GetEntityFlags(client) & ~FL_ATCONTROLS);
	}
	
	// stop timer
	if(0 < client <= MaxClients)
	{
		if(!IsFakeClient(client))
		{
			g_bTiming[client]  = false;
		}
	}
	
	g_bPaused[client] = false;
	
	if(GetEntityMoveType(client) == MOVETYPE_NONE)
	{
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
}

public Native_IsBeingTimed(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new Type   = GetNativeCell(2);
	
	if(g_bTiming[client] == true)
	{
		if(Type == TIMER_ANY)
		{
			return true;
		}
		else
		{
			return g_Type[client] == Type;
		}
	}
	
	return false;
}

bool:ShouldTimerFinish(client, Type, Style)
{
	if(g_bTimeIsLoaded[client] == false)
		return false;
	
	if(GetPlayerID(client) == 0)
		return false;
	
	if(g_bPaused[client] == true)
		return false;
	
	// Anti-cheat sideways
	if(Type == TIMER_MAIN && Style == STYLE_SIDEWAYS)
	{
		new Float:WSRatio = float(g_SWStrafes[client][0])/float(g_SWStrafes[client][1]);
		if((WSRatio > 2.0) || (g_Strafes[client] < 10))
		{
			PrintColorText(client, "%s%sThat time did not count because your W:S ratio (%s%4.1f%s) was too large or your strafe count (%s%d%s) was too small.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				WSRatio*100.0,
				g_msg_textcol,
				g_msg_varcol,
				g_Strafes[client],
				g_msg_textcol);
			StopTimer(client);
			return false;
		}
	}
	
	return true;
}

public Native_FinishTimer(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new Type   = g_Type[client];
	new Style  = (Type == TIMER_MAIN)?g_Style[client]:STYLE_NORMAL;
	
	if(ShouldTimerFinish(client, Type, Style))
	{
		// get their time
		new Float:fNewTime = GetClientTimer(client);
		
		StopTimer(client);
		
		// Do the OnTimerFinished forward
		Call_StartForward(g_fwdOnTimerFinished);
		Call_PushCell(client);
		Call_PushFloat(fNewTime);
		Call_PushCell(Type);
		Call_PushCell(Style);
		Call_Finish();
		
		decl String:sStyle[32];
		GetStyleName(Style, sStyle, sizeof(sStyle));
		StringToUpper(sStyle);
		AddBracketsToString(sStyle, sizeof(sStyle));
		AddSpaceToEnd(sStyle, sizeof(sStyle));
		
		// If time is an improvement
		if(fNewTime < g_fTime[client][Type][Style] || g_fTime[client][Type][Style] == 0.0)
		{
			// Save the time
			DB_UpdateTime(client, Type, Style, fNewTime, g_Jumps[client], g_Strafes[client], GetClientSync(client), GetClientSync2(client));
			
			decl String:newTimeString[32], String:name[MAX_NAME_LENGTH];
			GetClientName(client, name, sizeof(name));
			FormatPlayerTime(fNewTime, newTimeString, sizeof(newTimeString), false, 1);
			
			if(Type == TIMER_MAIN)
			{
				// Set players new time string for key hint
				Format(g_sTime[client][Type][Style], 48, "Best: %s", newTimeString);
				
				// Set client's personal best variable
				g_fTime[client][Type][Style] = fNewTime;
				
				// If it's a WR
				if(fNewTime < g_WorldRecord[Type][Style] || g_WorldRecord[Type][Style] == 0.0)
				{
					// Set the worldrecord variable to the new time
					g_WorldRecord[Type][Style] = fNewTime;
					
					PlayRecordSound();
					
					// Set new key hint text message
					decl String:sStyleAbbr[8];
					GetStyleAbbr(Style, sStyleAbbr, sizeof(sStyleAbbr));
					StringToUpper(sStyleAbbr);
					
					Format(g_sRecord[Type][Style], 48, "WR%s: %s (%s)", sStyleAbbr, newTimeString, name);
					
					// Print WR message to all players
					if(Style != STYLE_WONLY)
					{
						PrintColorTextAll("%s%sNEW %s%s%sRecord by %s%s %sin %s%s%s (%s%d%s jumps, %s%d%s strafes)",
							g_msg_start,
							g_msg_textcol,
							g_msg_varcol,
							sStyle,
							g_msg_textcol,
							g_msg_varcol,
							name,
							g_msg_textcol,
							g_msg_varcol,
							newTimeString,
							g_msg_textcol,
							g_msg_varcol,
							g_Jumps[client],
							g_msg_textcol,
							g_msg_varcol,
							g_Strafes[client],
							g_msg_textcol);
					}
					else
					{
						PrintColorTextAll("%s%sNEW %s%s%sRecord by %s%s %sin %s%s%s (%s%d%s jumps)",
							g_msg_start,
							g_msg_textcol,
							g_msg_varcol,
							sStyle,
							g_msg_textcol,
							g_msg_varcol,
							name,
							g_msg_textcol,
							g_msg_varcol,
							newTimeString,
							g_msg_textcol,
							g_msg_varcol,
							g_Jumps[client],
							g_msg_textcol);
					}
				}
				else //If it's just an improvement
				{
					FormatPlayerTime(fNewTime, newTimeString, sizeof(newTimeString), false, 1);
					if(Style != STYLE_WONLY)
					{
						PrintColorTextAll("%s%s%s%s %sfinished in %s%s%s (%s%d%s jumps, %s%d%s strafes)", 
							g_msg_start,
							g_msg_varcol,
							sStyle, 
							name, 
							g_msg_textcol,
							g_msg_varcol,
							newTimeString,
							g_msg_textcol,
							g_msg_varcol,
							g_Jumps[client],
							g_msg_textcol,
							g_msg_varcol,
							g_Strafes[client],
							g_msg_textcol);
					}
					else
					{
						PrintColorTextAll("%s%s%s%s %sfinished in %s%s%s (%s%d%s jumps)", 
							g_msg_start,
							g_msg_varcol,
							sStyle, 
							name, 
							g_msg_textcol,
							g_msg_varcol,
							newTimeString,
							g_msg_textcol,
							g_msg_varcol,
							g_Jumps[client],
							g_msg_textcol);
					}
				}
			}
			else if(Type == TIMER_BONUS)
			{
				// Set players new time string for key hint
				Format(g_sTime[client][Type][Style], 48, "Best: %s", newTimeString);
				
				// Set client's personal best
				g_fTime[client][Type][Style] = fNewTime;
				
				// If it's a top time
				if(fNewTime < g_WorldRecord[Type][Style] || g_WorldRecord[Type][Style] == 0.0)
				{
					// Set the worldrecord variable to the new time
					g_WorldRecord[Type][Style] = fNewTime;
					
					PlayRecordSound();
					
					//Set new key hint text message
					Format(g_sRecord[Type][Style], 48, "BWR: %s (%s)", newTimeString, name);
					
					// Print BWR message to all players
					PrintColorTextAll("%s%sNEW %s[BONUS] %sRecord by %s%s %sin %s%s%s (%s%d%s jumps, %s%d%s strafes)",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						g_msg_textcol,
						g_msg_varcol,
						name,
						g_msg_textcol,
						g_msg_varcol,
						newTimeString,
						g_msg_textcol,
						g_msg_varcol,
						g_Jumps[client],
						g_msg_textcol,
						g_msg_varcol,
						g_Strafes[client],
						g_msg_textcol);
				}
				else // If it's just an improvement
				{
					FormatPlayerTime(fNewTime, newTimeString, sizeof(newTimeString), false, 1);
					PrintColorTextAll("%s%s[BONUS] %s %sfinished in %s%s%s (%s%d%s jumps, %s%d%s strafes)", 
						g_msg_start,
						g_msg_varcol,
						name, 
						g_msg_textcol,
						g_msg_varcol,
						newTimeString,
						g_msg_textcol,
						g_msg_varcol,
						g_Jumps[client],
						g_msg_textcol,
						g_msg_varcol,
						g_Strafes[client],
						g_msg_textcol);
				}
			}
		}
		else
		{
			decl String:time[32], String:personalBest[32];
			FormatPlayerTime(fNewTime, time, sizeof(time), false, 1);
			FormatPlayerTime(g_fTime[client][Type][Style], personalBest, sizeof(personalBest), true, 1);
			
			PrintColorText(client, "%s%s%s%sYou finished in %s%s%s, but did not improve on your previous time of %s%s",
				g_msg_start,
				g_msg_varcol,
				(Type == TIMER_MAIN)?sStyle:"[BONUS] ",
				g_msg_textcol,
				g_msg_varcol,
				time,
				g_msg_textcol,
				g_msg_varcol,
				personalBest);
				
			PrintColorTextObservers(client, "%s%s%s%N %sfinished in %s%s%s, but did not improve on their previous time of %s%s",
				g_msg_start,
				g_msg_varcol,
				(Type == TIMER_MAIN)?sStyle:"[BONUS] ",
				client,
				g_msg_textcol,
				g_msg_varcol,
				time,
				g_msg_textcol,
				g_msg_varcol,
				personalBest);
		}
	}
}

Float:GetClientTimer(client)
{
	return GetEngineTime() - g_fStartTime[client];
}

LoadRecordSounds()
{
	// Re-intizialize array to remove any current sounds loaded
	if(g_hSoundsArray != INVALID_HANDLE)
		ClearArray(g_hSoundsArray);
	else
		g_hSoundsArray = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	
	// Create path and file variables
	decl	String:sPath[PLATFORM_MAX_PATH]; 
	new	Handle:hFile;
	
	// Build a path to check if it exists
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer");
	
	// If it doesn't exist, create it
	if(!DirExists(sPath))
		CreateDirectory(sPath, 511);
	
	// Build a path to check if the config file exists
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/wrsounds.cfg");
	
	// If the wrsounds exists, load the sounds
	if(FileExists(sPath))
	{
		hFile = OpenFile(sPath, "r");
		
		if(hFile != INVALID_HANDLE)
		{
			decl String:sSound[PLATFORM_MAX_PATH], String:sPSound[PLATFORM_MAX_PATH];
			while(!IsEndOfFile(hFile))
			{
				// get the next line in the file
				ReadFileLine(hFile, sSound, sizeof(sSound));
				ReplaceString(sSound, sizeof(sSound), "\n", "");
				
				if(StrContains(sSound, ".") != -1)
				{					
					// precache the sound
					Format(sPSound, sizeof(sPSound), "btimes/%s", sSound);
					PrecacheSound(sPSound);
					
					// make clients download it
					Format(sPSound, sizeof(sPSound), "sound/%s", sPSound);
					AddFileToDownloadsTable(sPSound);
					
					// add it to array for later downloading
					PushArrayString(g_hSoundsArray, sSound);
				}
			}
		}
	}
	else
	{
		// Create the file if it doesn't exist
		hFile = OpenFile(sPath, "w");
	}
	
	// Close it if it was opened succesfully
	if(hFile != INVALID_HANDLE)
		CloseHandle(hFile);
	
}

PlayRecordSound()
{
	decl String:sSound[PLATFORM_MAX_PATH];
	
	new iSize = GetArraySize(g_hSoundsArray);
	if(iSize > 0)
	{
		new iSound = GetRandomInt(0, iSize-1);
		GetArrayString(g_hSoundsArray, iSound, sSound, sizeof(sSound));
		Format(sSound, sizeof(sSound), "btimes/%s", sSound);
		
		for(new client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				if(!(GetClientSettings(client) & STOP_RECSND))
				{
					EmitSoundToClient(client, sSound);
				}
			}
		}
	}
}

DB_Connect()
{
	if(g_DB != INVALID_HANDLE)
	{
		CloseHandle(g_DB);
	}
	
	decl String:error[255];
	
	g_DB = SQL_Connect("timer", true, error, sizeof(error));
	if(g_DB == INVALID_HANDLE)
	{
		LogError(error);
		CloseHandle(g_DB);
	}
}

// loads player times on the map
DB_LoadPlayerInfo(client)
{
	if(IsClientConnected(client) && GetPlayerID(client) != 0)
	{
		if(!IsFakeClient(client))
		{
			new Position;
			
			for(new Style = 0; Style < MAX_STYLES; Style++)
			{
				Position = 0;
				if((Position = GetPlayerPositionByID(GetPlayerID(client), TIMER_MAIN, Style)) != GetArraySize(g_hTimes[TIMER_MAIN][Style]))
				{
					g_fTime[client][TIMER_MAIN][Style] = GetArrayCell(g_hTimes[TIMER_MAIN][Style], Position - 1, 1);
					FormatPlayerTime(g_fTime[client][TIMER_MAIN][Style], g_sTime[client][TIMER_MAIN][Style], 48, false, 1);
					Format(g_sTime[client][TIMER_MAIN][Style], 48, "Best: %s", g_sTime[client][TIMER_MAIN][Style]);
				}
				else
				{
					Format(g_sTime[client][TIMER_MAIN][Style], 48, "Best: No time");
				}
			}
			
			Position = 0;
			if((Position = GetPlayerPositionByID(GetPlayerID(client), TIMER_BONUS, STYLE_NORMAL)) != GetArraySize(g_hTimes[TIMER_BONUS][STYLE_NORMAL]))
			{
				g_fTime[client][TIMER_BONUS][STYLE_NORMAL] = GetArrayCell(g_hTimes[TIMER_BONUS][STYLE_NORMAL], Position - 1, 1);
				FormatPlayerTime(g_fTime[client][TIMER_BONUS][STYLE_NORMAL], g_sTime[client][TIMER_BONUS][STYLE_NORMAL], 48, false, 1);
				Format(g_sTime[client][TIMER_BONUS][STYLE_NORMAL], 48, "Best: %s", g_sTime[client][TIMER_BONUS][STYLE_NORMAL]);
			}
			else
			{
				// Format key hint text
				Format(g_sTime[client][TIMER_BONUS][STYLE_NORMAL], 48, "Best: No time");
			}
			
			g_bTimeIsLoaded[client] = true;
		}
	}
}

public Native_GetClientStyle(Handle:plugin, numParams)
{
	return g_Style[GetNativeCell(1)];
}

public Native_IsTimerPaused(Handle:plugin, numParams)
{
	return g_bPaused[GetNativeCell(1)];
}

public Native_IsStyleAllowed(Handle:plugin, numParams)
{
	new Style = GetNativeCell(1);
	
	if(Style == STYLE_NORMAL)
		return true;
	
	return GetConVarBool(g_hAllowStyle[Style]);
}

// Adds or updates a player's record on the map
DB_UpdateTime(client, Type, Style, Float:Time, Jumps, Strafes, Float:Sync, Float:Sync2)
{
	if(GetPlayerID(client) != 0)
	{
		if(!IsFakeClient(client))
		{
			new Handle:data = CreateDataPack();
			WritePackString(data, g_sMapName);
			WritePackCell(data, client);
			WritePackCell(data, Type);
			WritePackCell(data, Style);
			WritePackFloat(data, Time);
			WritePackCell(data, Jumps);
			WritePackCell(data, Strafes);
			WritePackFloat(data, Sync);
			WritePackFloat(data, Sync2);
			
			decl String:query[256];
			Format(query, sizeof(query), "DELETE FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d AND PlayerID=%d",
				g_sMapName,
				Type,
				Style,
				GetPlayerID(client));
			SQL_TQuery(g_DB, DB_UpdateTime_Callback1, query, data);
		}
	}
}

public DB_UpdateTime_Callback1(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		decl String:sMapName[64];
		
		ResetPack(data);
		ReadPackString(data, sMapName, sizeof(sMapName));
		new client       = ReadPackCell(data);
		new Type         = ReadPackCell(data);
		new Style        = ReadPackCell(data);
		new Float:Time   = ReadPackFloat(data);
		new Jumps        = ReadPackCell(data);
		new Strafes      = ReadPackCell(data);
		new Float:Sync   = ReadPackFloat(data);
		new Float:Sync2  = ReadPackFloat(data);
		
		decl String:query[512];
		Format(query, sizeof(query), "INSERT INTO times (MapID, Type, Style, PlayerID, Time, Jumps, Strafes, Points, Timestamp, Sync, SyncTwo) VALUES ((SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1), %d, %d, %d, %f, %d, %d, 0, %d, %f, %f)", 
			sMapName,
			Type,
			Style,
			GetPlayerID(client),
			Time,
			Jumps,
			Strafes,
			GetTime(),
			Sync,
			Sync2);
		SQL_TQuery(g_DB, DB_UpdateTime_Callback2, query, data);
	}
	else
	{
		CloseHandle(data);
		LogError(error);
	}
}

public DB_UpdateTime_Callback2(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		decl String:sMapName[64];//, String:sName[MAX_NAME_LENGTH];
		
		ResetPack(data);
		
		ReadPackString(data, sMapName, sizeof(sMapName));
		/*new client      = */
		ReadPackCell(data);
		new Type        = ReadPackCell(data);
		new Style       = ReadPackCell(data);
		//new Float:fTime = ReadPackFloat(data);
		
		DB_UpdateRanks(sMapName, Type, Style);
		
		if(StrEqual(g_sMapName, sMapName))
		{
			DB_LoadTimes(false);
			
			/*
			new	pos;
			if(Type == TIMER_MAIN)
			{
				// If player already has a time, remove it from the array
				if((pos = GetPlayerPositionByID(GetPlayerID(client), Type, Style)) != GetArraySize(g_hTimes[Style]))
				{
					RemoveFromArray(g_hTimes[Style], pos - 1);
					RemoveFromArray(g_hTimesUsers[Style], pos - 1);
				}
				
				pos = GetPlayerPosition(fTime, Type, Style);
				
				PrintToServer("Position: %d", pos);
				
				new iSize = GetArraySize(g_hTimes[Style]);
				if(iSize >= pos)
				{
					PrintToServer("Times array resized to %d", GetArraySize(g_hTimes[Style]));
					ResizeArray(g_hTimes[Style], iSize + 1);
					ResizeArray(g_hTimesUsers[Style], iSize + 1);
				}
				else
				{
					PrintToServer("Times array shifting up. Size: %d", GetArraySize(g_hTimes[Style]));
					ShiftArrayUp(g_hTimes[Style], pos);
					ShiftArrayUp(g_hTimesUsers[Style], pos);
					PrintToServer("Times array shifted up. Size: %d", GetArraySize(g_hTimes[Style]));
				}
				
				SetArrayCell(g_hTimes[Style], pos, GetPlayerID(client), 0);
				SetArrayCell(g_hTimes[Style], pos, fTime, 1);
				
				GetClientName(client, sName, sizeof(sName));
				SetArrayString(g_hTimesUsers[Style], pos, sName);
			}
			else if(Type == TIMER_BONUS)
			{
				// If player already has a time, remove it from the array
				if((pos = GetPlayerPositionByID(GetPlayerID(client), Type, Style)) != GetArraySize(g_hBTimes))
				{
					RemoveFromArray(g_hTimes[Style], pos - 1);
					RemoveFromArray(g_hTimesUsers[Style], pos - 1);
				}
				
				pos = GetPlayerPosition(fTime, Type, Style);
					
				new iSize;
				if((iSize = GetArraySize(g_hBTimes)) == pos)
				{
					ResizeArray(g_hBTimes, iSize + 1);
					ResizeArray(g_hBTimesUsers, iSize + 1);
				}
				else
				{
					ShiftArrayUp(g_hBTimes, pos);
					ShiftArrayUp(g_hBTimesUsers, pos);
				}
				
				SetArrayCell(g_hBTimes, pos, GetPlayerID(client), 0);
				SetArrayCell(g_hBTimes, pos, fTime, 1);
				
				GetClientName(client, sName, sizeof(sName));
				SetArrayString(g_hBTimesUsers, pos, sName);
			}
			*/
		}
		
		//for(new i=1; i<=MaxClients; i++)
			//DB_GetTopOneTimesCount(i);
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

// Opens a menu that displays the records on the given map
DB_DisplayRecords(client, String:sMapName[], Type, Style)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, Type);
	WritePackCell(pack, Style);
	WritePackString(pack, sMapName);
	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT Time, User, Jumps, Strafes, Points, Timestamp, T.PlayerID, Sync, SyncTwo FROM times AS T JOIN players AS P ON T.PlayerID=P.PlayerID AND MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d ORDER BY Time, Timestamp",
		sMapName,
		Type,
		Style);
	SQL_TQuery(g_DB, DB_DisplayRecords_Callback1, query, pack);
}

public DB_DisplayRecords_Callback1(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		decl String:sMapName[64];
		
		ResetPack(data);
		new client = ReadPackCell(data);
		new Type   = ReadPackCell(data);
		new Style  = ReadPackCell(data);
		ReadPackString(data, sMapName, sizeof(sMapName));
		
		new rowcount = SQL_GetRowCount(hndl);
		if(rowcount != 0)
		{	
			decl String:name[(MAX_NAME_LENGTH*2)+1], String:title[128], String:item[256], String:info[256], String:sTime[32];
			new Float:time, Float:points, jumps, strafes, timestamp, PlayerID, Float:ClientTime, MapRank, Float:Sync, Float:Sync2;
			
			new Handle:menu = CreateMenu(Menu_WorldRecord);	
			new RowCount = SQL_GetRowCount(hndl);
			for(new i = 1; i <= RowCount; i++)
			{
				SQL_FetchRow(hndl);
				time 		= SQL_FetchFloat(hndl, 0);
				SQL_FetchString(hndl, 1, name, sizeof(name));
				jumps 		= SQL_FetchInt(hndl, 2);
				FormatPlayerTime(time, sTime, sizeof(sTime), false, 1);
				strafes 		= SQL_FetchInt(hndl, 3);
				points 		= SQL_FetchFloat(hndl, 4);
				timestamp 	= SQL_FetchInt(hndl, 5);
				PlayerID 	= SQL_FetchInt(hndl, 6);
				Sync     	= SQL_FetchFloat(hndl, 7);
				Sync2 		= SQL_FetchFloat(hndl, 8);
				
				if(PlayerID == GetPlayerID(client))
				{
					ClientTime	= time;
					MapRank		= i;
				}
				
				// 33 spaces because names can't hold that many characters
				Format(info, sizeof(info), "%s                                 %d %d %s %.1f %d %d %d %d %d %s %f %f",
					name,
					Type,
					Style,
					sTime,
					points,
					i,
					rowcount,
					timestamp,
					jumps,
					strafes,
					sMapName,
					Sync,
					Sync2);
					
				Format(item, sizeof(item), "#%d: %s - %s",
					i,
					sTime,
					name);
				
				if((i % 7) == 0 || i == RowCount)
					Format(item, sizeof(item), "%s\n--------------------------------------", item);
				
				AddMenuItem(menu, info, item);
			}
			
			decl String:sType[32];
			GetTypeName(Type, sType, sizeof(sType));
			AddBracketsToString(sType, sizeof(sType));
			Format(sType, sizeof(sType), " %s ", sType);
			
			decl String:sStyle[32];
			GetStyleName(Style, sStyle, sizeof(sStyle));
			AddBracketsToString(sStyle, sizeof(sStyle));
			Format(sStyle, sizeof(sStyle), " %s", sStyle);
			
			if(ClientTime != 0.0)
			{
				decl String:sClientTime[32];
				FormatPlayerTime(ClientTime, sClientTime, sizeof(sClientTime), false, 1);
				Format(title, sizeof(title), "%s%srecords%s\n \nYour time: %s ( %d / %d )\n--------------------------------------",
					sMapName,
					sType,
					sStyle,
					sClientTime,
					MapRank,
					rowcount);
			}
			else
			{
				Format(title, sizeof(title), "%s%srecords%s\n \n%d total\n--------------------------------------",
					sMapName,
					sType,
					sStyle,
					rowcount);
			}
			
			SetMenuTitle(menu, title);
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
		else
		{
			if(Type == TIMER_MAIN)
				PrintColorText(client, "%s%sNo one has beaten the map yet",
					g_msg_start,
					g_msg_textcol);
			else
				PrintColorText(client, "%s%sNo one has beaten the bonus on this map yet.",
					g_msg_start,
					g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
	CloseHandle(data);
}

public Menu_WorldRecord(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[256];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		decl String:infosplode[12][128], String:infosplodetwo[2][256];
		ExplodeString(info, "                                 ", infosplodetwo, 2, 256);
		
		ExplodeString(infosplodetwo[1], " ", infosplode, 12, 128);
		
		ShowRecordInfo(param1, infosplodetwo[0], infosplode);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

ShowRecordInfo(client, String:name[256], String:info[12][128])//, const String:name[MAX_NAME_LENGTH])
{
	new Type  = StringToInt(info[0]);
	new Style = StringToInt(info[1]);
	
	new Handle:menu = CreatePanel(INVALID_HANDLE);
	
	decl String:title[48];
	Format(title, sizeof(title), "Record details of %s\n \n", name);
	DrawPanelText(menu, title);
	
	decl String:sMap[128];
	Format(sMap, sizeof(sMap), "Map: %s\n \n", info[9]);
	DrawPanelText(menu, sMap);
	
	decl String:sTime[48];
	Format(sTime, sizeof(sTime), "Time: %s (%s/%s)\n \n", info[2], info[4], info[5]);
	DrawPanelText(menu, sTime);
	
	decl String:sPoints[24];
	Format(sPoints, sizeof(sPoints), "Points earned: %s\n \n", info[3]);
	DrawPanelText(menu, sPoints);
	
	decl String:sType[32];
	GetTypeName(Type, sType, sizeof(sType));
	Format(sType, sizeof(sType), "Type: %s", sType);
	DrawPanelText(menu, sType);
	
	decl String:sStyle[32];
	GetStyleName(Style, sStyle, sizeof(sStyle));
	Format(sStyle, sizeof(sStyle), "Style: %s\n \n", sStyle);
	DrawPanelText(menu, sStyle);
	
	if(Style != STYLE_WONLY)
	{
		decl String:sStrafes[32];
		Format(sStrafes, sizeof(sStrafes), "Jumps/Strafes: %s/%s\n \n", info[7], info[8]);
		DrawPanelText(menu, sStrafes);
	}
	else
	{
		decl String:sJumps[16];
		Format(sJumps, sizeof(sJumps), "Jumps: %s\n \n", info[7]);
		DrawPanelText(menu, sJumps);
	}
	
	decl String:sTimeStamp[32];
	FormatTime(sTimeStamp, sizeof(sTimeStamp), "%x %X", StringToInt(info[6]));
	Format(sTimeStamp, sizeof(sTimeStamp), "Date: %s\n \n", sTimeStamp);
	DrawPanelText(menu, sTimeStamp);
	
	if(Style == STYLE_NORMAL || Style == STYLE_STAMINA)
	{
		decl String:sSync[32];
		if(GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective))
		{
			Format(sSync, sizeof(sSync), "Sync 1: %.3f%%\n", StringToFloat(info[10]));
			DrawPanelText(menu, sSync);
			
			Format(sSync, sizeof(sSync), "Sync 2: %.3f%%\n \n", StringToFloat(info[11]));
			DrawPanelText(menu, sSync);
		}
		else
		{
			Format(sSync, sizeof(sSync), "Sync: %.3f%%\n \n", StringToFloat(info[10]));
			DrawPanelText(menu, sSync);
		}
	}
	
	DrawPanelText(menu, "0. Close");
	
	SendPanelToClient(menu, client, Menu_ShowRecordInfo, MENU_TIME_FOREVER);
}

public Menu_ShowRecordInfo(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
}

DB_ShowTimeAtRank(client, const String:MapName[], rank, Type, Style)
{		
	if(rank < 1)
	{
		PrintColorText(client, "%s%s%d%s is not a valid rank.",
			g_msg_start,
			g_msg_varcol,
			rank,
			g_msg_textcol);
			
		return;
	}
	
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, rank);
	WritePackCell(pack, Type);
	WritePackCell(pack, Style);
	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT t2.User, t1.Time, t1.Jumps, t1.Strafes, t1.Points, t1.Timestamp FROM times AS t1, players AS t2 WHERE t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.PlayerID=t2.PlayerID AND t1.Type=%d AND t1.Style=%d ORDER BY t1.Time LIMIT %d, 1",
		MapName,
		Type,
		Style,
		rank-1);
	SQL_TQuery(g_DB, DB_ShowTimeAtRank_Callback1, query, pack);
}

public DB_ShowTimeAtRank_Callback1(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{		
		ResetPack(pack);
		new client = ReadPackCell(pack);
		ReadPackCell(pack);
		new Type   = ReadPackCell(pack);
		new Style  = ReadPackCell(pack);
		
		if(SQL_GetRowCount(hndl) == 1)
		{
			decl String:sUserName[MAX_NAME_LENGTH], String:sTimeStampDay[255], String:sTimeStampTime[255], String:sfTime[255];
			new Float:fTime, iJumps, iStrafes, Float:fPoints, iTimeStamp;
			
			SQL_FetchRow(hndl);
			
			SQL_FetchString(hndl, 0, sUserName, sizeof(sUserName));
			fTime      = SQL_FetchFloat(hndl, 1);
			iJumps     = SQL_FetchInt(hndl, 2);
			iStrafes   = SQL_FetchInt(hndl, 3);
			fPoints    = SQL_FetchFloat(hndl, 4);
			iTimeStamp = SQL_FetchInt(hndl, 5);
			
			FormatPlayerTime(fTime, sfTime, sizeof(sfTime), false, 1);
			FormatTime(sTimeStampDay, sizeof(sTimeStampDay), "%x", iTimeStamp);
			FormatTime(sTimeStampTime, sizeof(sTimeStampTime), "%X", iTimeStamp);
			
			decl String:sStyle[32];
			GetStyleName(Style, sStyle, sizeof(sStyle));
			StringToUpper(sStyle);
			AddBracketsToString(sStyle, sizeof(sStyle));
			Format(sStyle, sizeof(sStyle), "%s ", sStyle);
			
			if(Style == STYLE_WONLY)
			{
				PrintColorText(client, "%s%s%s%s%s has time %s%s%s\n(%s%d%s jumps, %s%.1f%s points)\nDate: %s%s %s%s.",
					g_msg_start,
					g_msg_varcol,
					(Type==0)?sStyle:"[BONUS] ",
					sUserName,
					g_msg_textcol,
					g_msg_varcol,
					sfTime,
					g_msg_textcol,
					g_msg_varcol,
					iJumps,
					g_msg_textcol,
					g_msg_varcol,
					fPoints,
					g_msg_textcol,
					g_msg_varcol,
					sTimeStampDay,
					sTimeStampTime,
					g_msg_textcol);
			}
			else
			{
				PrintColorText(client, "%s%s%s%s%s has time %s%s%s\n(%s%d%s jumps, %s%d%s strafes, %s%.1f%s points)\nDate: %s%s %s%s.",
					g_msg_start,
					g_msg_varcol,
					(Type==0)?sStyle:"[BONUS] ",
					sUserName,
					g_msg_textcol,
					g_msg_varcol,
					sfTime,
					g_msg_textcol,
					g_msg_varcol,
					iJumps,
					g_msg_textcol,
					g_msg_varcol,
					iStrafes,
					g_msg_textcol,
					g_msg_varcol,
					fPoints,
					g_msg_textcol,
					g_msg_varcol,
					sTimeStampDay,
					sTimeStampTime,
					g_msg_textcol);
			}
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(pack);
}

DB_ShowTime(client, target, const String:MapName[], Type, Style)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, target);
	WritePackCell(pack, Type);
	WritePackCell(pack, Style);
	
	new PlayerID = GetPlayerID(target);
	
	decl String:query[800];
	FormatEx(query, sizeof(query), "SELECT (SELECT count(*) FROM times WHERE Time<=(SELECT Time FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d AND PlayerID=%d) AND MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d) AS Rank, (SELECT count(*) FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d) AS Timescount, Time, Jumps, Strafes, Points, Timestamp FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d AND PlayerID=%d", 
		MapName, 
		Type, 
		Style, 
		PlayerID, 
		MapName, 
		Type, 
		Style, 
		MapName, 
		Type, 
		Style, 
		MapName, 
		Type, 
		Style, 
		PlayerID);	
	SQL_TQuery(g_DB, DB_ShowTime_Callback1, query, pack);
}

public DB_ShowTime_Callback1(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(pack);
		new client	= ReadPackCell(pack);
		new target	= ReadPackCell(pack);
		new Type		= ReadPackCell(pack);
		new Style 	= ReadPackCell(pack);
		
		new TargetID = GetPlayerID(target);
		
		if(IsClientInGame(client) && IsClientInGame(target) && TargetID)
		{
			decl String:sTime[32], String:sDate[32], String:sDateDay[32], String:sName[MAX_NAME_LENGTH];
			GetClientName(target, sName, sizeof(sName));
			
			decl String:sStyle[32];
			GetStyleName(Style, sStyle, sizeof(sStyle));
			StringToUpper(sStyle);
			AddBracketsToString(sStyle, sizeof(sStyle));
			Format(sStyle, sizeof(sStyle), "%s ", sStyle);
			
			if(SQL_GetRowCount(hndl) == 1)
			{
				SQL_FetchRow(hndl);
				new Rank 		 = SQL_FetchInt(hndl, 0);
				new Timescount   	 = SQL_FetchInt(hndl, 1);
				new Float:Time 	 = SQL_FetchFloat(hndl, 2);
				new Jumps 		 = SQL_FetchInt(hndl, 3);
				new Strafes 	 	 = SQL_FetchInt(hndl, 4);
				new Float:Points 	 = SQL_FetchFloat(hndl, 5);
				new TimeStamp 	 = SQL_FetchInt(hndl, 6);
				
				FormatPlayerTime(Time, sTime, sizeof(sTime), false, 1);
				FormatTime(sDate, sizeof(sDate), "%x", TimeStamp);
				FormatTime(sDateDay, sizeof(sDateDay), "%X", TimeStamp);
				
				if(Style != STYLE_WONLY)
				{
					PrintColorText(client, "%s%s%s%s %shas time %s%s%s (%s%d%s / %s%d%s)",
						g_msg_start,
						g_msg_varcol,
						(Type==0)?sStyle:"[BONUS] ",
						sName,
						g_msg_textcol,
						g_msg_varcol,
						sTime,
						g_msg_textcol,
						g_msg_varcol,
						Rank,
						g_msg_textcol,
						g_msg_varcol,
						Timescount,
						g_msg_textcol);
					
					PrintColorText(client, "%sDate: %s%s %s",
						g_msg_textcol,
						g_msg_varcol,
						sDate,
						sDateDay);
					
					PrintColorText(client, "%s(%s%d%s jumps, %s%d%s strafes, and %s%4.1f%s points)",
						g_msg_textcol,
						g_msg_varcol,
						Jumps,
						g_msg_textcol,
						g_msg_varcol,
						Strafes,
						g_msg_textcol,
						g_msg_varcol,
						Points,
						g_msg_textcol);
				}
				else
				{
					PrintColorText(client, "%s%s[W-ONLY] %s %shas time %s%s%s (%s%d%s / %s%d%s)",
						g_msg_start,
						g_msg_varcol,
						sName,
						g_msg_textcol,
						g_msg_varcol,
						sTime,
						g_msg_textcol,
						g_msg_varcol,
						Rank,
						g_msg_textcol,
						g_msg_varcol,
						Timescount,
						g_msg_textcol);
					
					PrintColorText(client, "%sDate: %s%s %s",
						g_msg_textcol,
						g_msg_varcol,
						sDate,
						sDateDay);
					
					PrintColorText(client, "%s(%s%d%s jumps and %s%4.1f%s points)",
						g_msg_textcol,
						g_msg_varcol,
						Jumps,
						g_msg_textcol,
						g_msg_varcol,
						Points,
						g_msg_textcol);
				}
			}
			else
			{
				if(GetPlayerID(client) != TargetID)
					PrintColorText(client, "%s%s%s%s %shas no time on the map.",
						g_msg_start,
						g_msg_varcol,
						(Type==TIMER_MAIN)?sStyle:"[BONUS] ",
						sName,
						g_msg_textcol);
				else
					PrintColorText(client, "%s%s%s%sYou have no time on the map.",
						g_msg_start,
						g_msg_varcol,
						(Type==TIMER_MAIN)?sStyle:"[BONUS] ",
						g_msg_textcol);	
			}
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(pack);
}

DB_DeleteRecord(client, Type, Style, RecordOne, RecordTwo)
{
	new Handle:data = CreateDataPack();
	WritePackCell(data, client);
	WritePackCell(data, Type);
	WritePackCell(data, Style);
	WritePackCell(data, RecordOne);
	WritePackCell(data, RecordTwo);
	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT COUNT(*) FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d",
		g_sMapName,
		Type,
		Style);
	SQL_TQuery(g_DB, DB_DeleteRecord_Callback1, query, data);
}

public DB_DeleteRecord_Callback1(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client		= ReadPackCell(data);
		new Type      	= ReadPackCell(data);
		new Style 	   	= ReadPackCell(data);
		new RecordOne 	= ReadPackCell(data);
		new RecordTwo 	= ReadPackCell(data);
		
		SQL_FetchRow(hndl);
		new timesCount = SQL_FetchInt(hndl, 0);
		
		decl String:sType[32];
		GetTypeName(Type, sType, sizeof(sType));
		AddBracketsToString(sType, sizeof(sType));
		
		decl String:sStyle[32];
		GetStyleName(Style, sStyle, sizeof(sStyle));
		AddBracketsToString(sStyle, sizeof(sStyle));
		Format(sStyle, sizeof(sStyle), "%s ", sStyle);
		
		if(RecordTwo > timesCount)
		{
			PrintColorText(client, "%s%s%s%sThere is no record %s%d %s", 
				g_msg_start,
				g_msg_varcol,
				sType, 
				g_msg_textcol,
				g_msg_varcol,
				RecordTwo, 
				sStyle);
			PrintHelp(client);
			return;
		}
		if(RecordOne < 1)
		{
			PrintColorText(client, "%s%sThe minimum record number is 1.",
				g_msg_start,
				g_msg_textcol);
			PrintHelp(client);
			return;
		}
		if(RecordOne > RecordTwo)
		{
			PrintColorText(client, "%s%sRecord 1 can't be larger than record 2.",
				g_msg_start,
				g_msg_textcol);
			PrintHelp(client);
			return;
		}
		
		decl String:query[700];
		Format(query, sizeof(query), "DELETE FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d AND Time BETWEEN (SELECT t1.Time FROM (SELECT * FROM times) AS t1 WHERE t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.Type=%d AND t1.Style=%d ORDER BY t1.Time LIMIT %d, 1) AND (SELECT t2.Time FROM (SELECT * FROM times) AS t2 WHERE t2.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t2.Type=%d AND t2.Style=%d ORDER BY t2.Time LIMIT %d, 1)",
			g_sMapName,
			Type,
			Style,
			g_sMapName,
			Type,
			Style,
			RecordOne-1,
			g_sMapName,
			Type,
			Style,
			RecordTwo-1);
		SQL_TQuery(g_DB, DB_DeleteRecord_Callback2, query, data);
	}
	else
	{
		CloseHandle(data);
		LogError(error);
	}
}

public DB_DeleteRecord_Callback2(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		// Get pack data
		ResetPack(data);
		ReadPackCell(data);
		new Type      = ReadPackCell(data);
		new Style     = ReadPackCell(data);
		new RecordOne = ReadPackCell(data);
		new RecordTwo = ReadPackCell(data);
		
		new PlayerID;
		for(new client = 1; client <= MaxClients; client++)
		{
			PlayerID = GetPlayerID(client);
			if(GetPlayerID(client) != 0 && IsClientInGame(client))
			{
				for(new idx = RecordOne - 1; idx < RecordTwo; idx++)
				{
					if(GetArrayCell(g_hTimes[Type][Style], idx, 0) == PlayerID)
					{
						g_fTime[client][Type][Style] = 0.0;
						Format(g_sTime[client][Type][Style], 48, "Best: No time");
					}
				}
			}
		}
		
		// Reload the times because some were deleted
		DB_LoadTimes(false);
		
		// Start the OnTimesDeleted forward
		Call_StartForward(g_fwdOnTimesDeleted);
		Call_PushCell(Type);
		Call_PushCell(Style);
		Call_PushCell(RecordOne);
		Call_PushCell(RecordTwo);
		Call_Finish();
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

DB_LoadTimes(bool:bFirstTime)
{	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT t1.rownum, t1.MapID, t1.Type, t1.Style, t1.PlayerID, t1.Time, t1.Jumps, t1.Strafes, t1.Points, t1.Timestamp, t2.User FROM times AS t1, players AS t2 WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.PlayerID=t2.PlayerID ORDER BY Type, Style, Time, Timestamp",
		g_sMapName);
		
	new	Handle:pack = CreateDataPack();
	WritePackCell(pack, bFirstTime);
	WritePackString(pack, g_sMapName);
	
	SQL_TQuery(g_DB, LoadTimes_Callback, query, pack);
}

public LoadTimes_Callback(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(pack);
		new	bool:bFirstTime = bool:ReadPackCell(pack);
		
		decl String:sMapName[64];
		ReadPackString(pack, sMapName, sizeof(sMapName));
		
		if(StrEqual(g_sMapName, sMapName))
		{
			for(new Style = 0; Style < MAX_STYLES; Style++)
			{
				ResizeArray(g_hTimes[TIMER_MAIN][Style], 1);
				ResizeArray(g_hTimesUsers[TIMER_MAIN][Style], 0);
			}
			
			ResizeArray(g_hTimes[TIMER_BONUS][STYLE_NORMAL], 1);
			ResizeArray(g_hTimesUsers[TIMER_BONUS][STYLE_NORMAL], 0);
			
			new rows = SQL_GetRowCount(hndl), Type, Style, iSize, String:sUser[MAX_NAME_LENGTH];
			for(new i = 0; i < rows; i++)
			{
				SQL_FetchRow(hndl);
				
				Type  = SQL_FetchInt(hndl, eType);
				Style = SQL_FetchInt(hndl, eStyle);
				
				SQL_FetchString(hndl, 10, sUser, sizeof(sUser));
				
				iSize = GetArraySize(g_hTimes[Type][Style]);
				
				SetArrayCell(g_hTimes[Type][Style], iSize-1, SQL_FetchInt(hndl, ePlayerID), 0);
				SetArrayCell(g_hTimes[Type][Style], iSize-1, SQL_FetchFloat(hndl, eTime), 1);
				
				ResizeArray(g_hTimes[Type][Style], iSize+1);
				
				PushArrayString(g_hTimesUsers[Type][Style], sUser);
			}
			
			g_bTimesAreLoaded  = true;
			//g_bTimesLoadedOnce = true;
			
			LoadWorldRecordInfo();
			
			if(bFirstTime)
			{
				for(new client = 1; client <= MaxClients; client++)
				{
					DB_LoadPlayerInfo(client);
				}
			}
		}
	}
	else
	{
		LogError(error);
	}
}

LoadWorldRecordInfo()
{
	decl String:sUser[MAX_NAME_LENGTH], String:sStyleAbbr[8];
	new iSize;
	for(new Style = 0; Style < MAX_STYLES; Style++)
	{
		GetStyleAbbr(Style, sStyleAbbr, sizeof(sStyleAbbr));
		StringToUpper(sStyleAbbr);
		
		iSize = GetArraySize(g_hTimes[TIMER_MAIN][Style]);
		if(iSize > 1)
		{
			g_WorldRecord[TIMER_MAIN][Style] = GetArrayCell(g_hTimes[TIMER_MAIN][Style], 0, 1);
			
			FormatPlayerTime(g_WorldRecord[TIMER_MAIN][Style], g_sRecord[TIMER_MAIN][Style], 48, false, 1);
			
			GetArrayString(g_hTimesUsers[TIMER_MAIN][Style], 0, sUser, MAX_NAME_LENGTH);
			
			Format(g_sRecord[TIMER_MAIN][Style], 48, "WR%s: %s (%s)", sStyleAbbr, g_sRecord[TIMER_MAIN][Style], sUser);
		}
		else
		{
			g_WorldRecord[TIMER_MAIN][Style] = 0.0;
			
			Format(g_sRecord[TIMER_MAIN][Style], 48, "WR%s: No record", sStyleAbbr);
		}
	}
	
	iSize = GetArraySize(g_hTimes[TIMER_BONUS][STYLE_NORMAL]);
	
	if(iSize > 1)
	{
		g_WorldRecord[TIMER_BONUS][STYLE_NORMAL] = GetArrayCell(g_hTimes[TIMER_BONUS][STYLE_NORMAL], 0, 1);
		
		FormatPlayerTime(g_WorldRecord[TIMER_BONUS][STYLE_NORMAL], g_sRecord[TIMER_BONUS][STYLE_NORMAL], 48, false, 1);
		GetArrayString(g_hTimesUsers[TIMER_BONUS][STYLE_NORMAL], 0, sUser, MAX_NAME_LENGTH);
		
		Format(g_sRecord[TIMER_BONUS][STYLE_NORMAL], 48, "BWR: %s (%s)", g_sRecord[TIMER_BONUS][STYLE_NORMAL], sUser);
	}
	else
	{
		g_WorldRecord[TIMER_BONUS][STYLE_NORMAL] = 0.0;
		
		Format(g_sRecord[TIMER_BONUS][STYLE_NORMAL], 48, "BWR: No record");
	}
}

VectorAngles(Float:vel[3], Float:angles[3])
{
	new Float:tmp, Float:yaw, Float:pitch;
	
	if (vel[1] == 0 && vel[0] == 0)
	{
		yaw = 0.0;
		if (vel[2] > 0)
			pitch = 270.0;
		else
			pitch = 90.0;
	}
	else
	{
		yaw = (ArcTangent2(vel[1], vel[0]) * (180 / 3.141593));
		if (yaw < 0)
			yaw += 360;

		tmp = SquareRoot(vel[0]*vel[0] + vel[1]*vel[1]);
		pitch = (ArcTangent2(-vel[2], tmp) * (180 / 3.141593));
		if (pitch < 0)
			pitch += 360;
	}
	
	angles[0] = pitch;
	angles[1] = yaw;
	angles[2] = 0.0;
}

GetDirection(client)
{
	new Float:vVel[3], Float:vAngles[3];
	vVel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	vVel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	vVel[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
	GetClientEyeAngles(client, vAngles);
	new Float:fTempAngle = vAngles[1];

	VectorAngles(vVel, vAngles);

	if(fTempAngle < 0)
		fTempAngle += 360;

	new Float:fTempAngle2 = fTempAngle - vAngles[1];

	if(fTempAngle2 < 0)
		fTempAngle2 = -fTempAngle2;
	
	if(fTempAngle2 < 22.5 || fTempAngle2 > 337.5)
		return 1; // Forwards
	if(fTempAngle2 > 22.5 && fTempAngle2 < 67.5 || fTempAngle2 > 292.5 && fTempAngle2 < 337.5 )
		return 2; // Half-sideways
	if(fTempAngle2 > 67.5 && fTempAngle2 < 112.5 || fTempAngle2 > 247.5 && fTempAngle2 < 292.5)
		return 3; // Sideways
	if(fTempAngle2 > 112.5 && fTempAngle2 < 157.5 || fTempAngle2 > 202.5 && fTempAngle2 < 247.5)
		return 4; // Backwards Half-sideways
	if(fTempAngle2 > 157.5 && fTempAngle2 < 202.5)
		return 5; // Backwards
	
	return 0; // Unknown
}

CheckSync(client, buttons, Float:vel[3], Float:angles[3])
{
	new Direction = GetDirection(client);
	
	if(Direction == 1 && GetClientVelocity(client, true, true, false) != 0)
	{	
		new flags = GetEntityFlags(client);
		new MoveType:movetype = GetEntityMoveType(client);
		if(!(flags & (FL_ONGROUND|FL_INWATER)) && (movetype != MOVETYPE_LADDER))
		{
			// Normalize difference
			new Float:fAngleDiff = angles[1] - g_fOldAngle[client];
			if (fAngleDiff > 180)
				fAngleDiff -= 360;
			else if(fAngleDiff < -180)
				fAngleDiff += 360;
			
			// Add to good sync if client buttons match up
			if(fAngleDiff > 0)
			{
				g_totalSync[client]++;
				if((buttons & IN_MOVELEFT) && !(buttons & IN_MOVERIGHT))
				{
					g_goodSync[client]++;
				}
				if(vel[1] < 0)
				{
					g_goodSyncVel[client]++;
				}
			}
			else if(fAngleDiff < 0)
			{
				g_totalSync[client]++;
				if((buttons & IN_MOVERIGHT) && !(buttons & IN_MOVELEFT))
				{
					g_goodSync[client]++;
				}
				if(vel[1] > 0)
				{
					g_goodSyncVel[client]++;
				}
			}
		}
	}
	
	g_fOldAngle[client] = angles[1];
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{	
	if(g_bTiming[client] == true)
	{
		// Style cheating prevention
		if(g_Type[client] == TIMER_MAIN)
		{
			new bool:infreestylezone = IsInAFreeStyleZone(client);
			if(g_Style[client] == STYLE_SIDEWAYS)
			{
				if(infreestylezone == false)
				{
					if(vel[1] != 0)
						SetEntityFlags(client, GetEntityFlags(client) | FL_ATCONTROLS);
					else
						SetEntityFlags(client, GetEntityFlags(client) & ~FL_ATCONTROLS);
				}
				else
					SetEntityFlags(client, GetEntityFlags(client) & ~FL_ATCONTROLS);
					
				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					if(!(g_Buttons[client] & IN_BACK) && (buttons & IN_BACK))
					{
						g_Strafes[client]++;
						g_SWStrafes[client][1]++;
					}
					else if(!(g_Buttons[client] & IN_FORWARD) && (buttons & IN_FORWARD))
					{
						g_Strafes[client]++;
						g_SWStrafes[client][0]++;
					}
				}
			}
			else if(g_Style[client] == STYLE_WONLY)
			{
				if(infreestylezone == false)
				{
					if(vel[1] != 0 || vel[0] < 0)
						SetEntityFlags(client, GetEntityFlags(client) | FL_ATCONTROLS);
					else
						SetEntityFlags(client, GetEntityFlags(client) & ~FL_ATCONTROLS);
				}
				else
					SetEntityFlags(client, GetEntityFlags(client) & ~FL_ATCONTROLS);
			}
			else if(g_Style[client] == STYLE_HALFSIDEWAYS)
			{
				if(vel[0] > 0 && vel[1] != 0)
					g_HSWCounter[client] = GetEngineTime();
				
				if(((GetEngineTime() - g_HSWCounter[client] > 0.7) || vel[0] <= 0) && !(GetEntityFlags(client) & FL_ONGROUND))
					SetEntityFlags(client, GetEntityFlags(client) | FL_ATCONTROLS);
				else
					SetEntityFlags(client, GetEntityFlags(client) & ~FL_ATCONTROLS);
			}
		}
		
		// Counting strafes
		if(g_Style[client] == STYLE_NORMAL || g_Style[client] == STYLE_STAMINA || g_Style[client] == STYLE_HALFSIDEWAYS || g_Type[client] == TIMER_BONUS)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				if(!(g_Buttons[client] & IN_MOVELEFT) && (buttons & IN_MOVELEFT))
					g_Strafes[client]++;
				else if(!(g_Buttons[client] & IN_MOVERIGHT) && (buttons & IN_MOVERIGHT))
					g_Strafes[client]++;
			}
		}
		
		// Anti - +left/+right
		if(GetConVarBool(g_hAllowYawspeed) == false)
		{
			if(buttons & (IN_LEFT|IN_RIGHT))
			{
				StopTimer(client);
				
				if(!IsInAStartZone(client))
				{
					PrintColorText(client, "%s%sYour timer was stopped for using +left/+right",
						g_msg_start,
						g_msg_textcol);
				}
			}
		}
		
		// Pausing
		if(g_bPaused[client] == true)
		{
			if(GetEntityMoveType(client) == MOVETYPE_WALK)
			{
				SetEntityMoveType(client, MOVETYPE_NONE);
			}
		}
		else
		{
			if(GetEntityMoveType(client) == MOVETYPE_NONE)
			{
				SetEntityMoveType(client, MOVETYPE_WALK);
			}
		}
		
		CheckSync(client, buttons, vel, angles);
	}
	
	g_Buttons[client] = buttons;
}

PrintHelp(client)
{
	PrintToChat(client, "[SM] Look in your console for help.");
	PrintToConsole(client, "[SM] Usage:\n\
sm_delete        		 - Opens delete menu.\n\
sm_delete record 		 - Deletes a specific record.\n\
sm_delete record1 record2	 - Deletes all times from record1 to record2.");
}