#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "bTimes-timer",
	author = "blacky",
	description = "The timer portion of the bTimes plugin",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <bTimes-zones>
#include <bTimes-timer>
#include <bTimes-ranks>
#include <bTimes-ghost>
#include <bTimes-random>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>

// database
new 	Handle:g_DB = INVALID_HANDLE;

// current map info
new 	String:g_mapname[64],
	Handle:g_MapList;
new 	Float:g_WorldRecord[3],
	Float:g_bWorldRecord;

// Player timer info
new 	Float:g_startTime[MAXPLAYERS+1],
	bool:g_timing[MAXPLAYERS+1];
	
new	Float:g_bstartTime[MAXPLAYERS+1],
	bool:g_btiming[MAXPLAYERS+1];
	
new 	g_timer_type[MAXPLAYERS+1];
new 	g_timer_style[MAXPLAYERS+1];
	
new 	Float:g_times[3][MAXPLAYERS+1],
	String:g_sTime[3][MAXPLAYERS+1][48],
	Float:g_btimes[MAXPLAYERS+1],
	String:g_sBTime[MAXPLAYERS+1][48];

new 	g_dStrafes[MAXPLAYERS+1],
	g_dJumps[MAXPLAYERS+1],
	g_dSWStrafes[MAXPLAYERS+1][2],
	Float:g_fSpawnTime[MAXPLAYERS+1];
	
new 	g_admin_delete[2];
new 	g_buttons[MAXPLAYERS+1];

new 	g_iMVPs_offset;
new 	TopTimesCount[MAXPLAYERS+1];

new	Handle:g_hSoundsArray = INVALID_HANDLE;

new	bool:g_bPaused[MAXPLAYERS+1],
	Float:g_fPauseTime[MAXPLAYERS+1],
	Float:g_fPausePos[MAXPLAYERS+1][3];
	
new	String:g_msg_start[128],
	String:g_msg_varcol[128],
	String:g_msg_textcol[128];
	
// Warning
new	Float:g_fWarningTime[MAXPLAYERS+1];
	
// Sync measurement
new	Float:g_fOldAngle[MAXPLAYERS+1],
	g_totalSync[MAXPLAYERS+1],
	g_goodSync[MAXPLAYERS+1],
	g_goodSyncVel[MAXPLAYERS+1];
	
// Hint text
new 	String:g_record[3][48],
	String:g_brecord[48];

// Settings
new 	Handle:g_hTimerDisplay,
	Handle:g_hHintSpeed,
	Handle:g_hAllowYawspeed,
	Handle:g_hAllowPause,
	Handle:g_hChangeClanTag,
	Handle:g_hTimerChangeClanTag,
	Handle:g_hShowTimeLeft;
	
// All map times
new	Handle:g_hTimes[3],
	Handle:g_hTimesUsers[3],
	Handle:g_hBTimes,
	Handle:g_hBTimesUsers;
	
// Forwards
new	Handle:g_fwdOnTimerFinished;

public OnPluginStart()
{
	// Connect to the database
	DB_Connect();
	
	// Server cvars
	g_hHintSpeed 	 = CreateConVar("timer_hintspeed", "0.1", "Changes the hint text update speed (bottom center text)", 0, true, 0.1);
	g_hAllowYawspeed = CreateConVar("timer_allowyawspeed", "0", "Lets players use +left/+right commands without stopping their timer.", 0, true, 0.0, true, 1.0);
	g_hAllowPause	 = CreateConVar("timer_allowpausing", "1", "Lets players use the !pause/!unpause commands.", 0, true, 0.0, true, 1.0);
	g_hChangeClanTag = CreateConVar("timer_changeclantag", "1", "Means player clan tags will show their current timer time.", 0, true, 0.0, true, 1.0);
	g_hShowTimeLeft  = CreateConVar("timer_showtimeleft", "1", "Shows the time left until a map change on the right side of player screens.", 0, true, 0.0, true, 1.0);
	
	HookConVarChange(g_hHintSpeed, OnTimerHintSpeedChanged);
	HookConVarChange(g_hChangeClanTag, OnChangeClanTagChanged);
	
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
	RegConsoleCmd("sm_stop", SM_StopTimer, "Stops your timer.");
	
	RegConsoleCmd("sm_wr", SM_WorldRecord, "Shows all the times for the current map.");
	RegConsoleCmd("sm_wrw", SM_WorldRecordW, "Shows all the W-Only times for the current map.");
	RegConsoleCmd("sm_wrsw", SM_WorldRecordSW, "Shows all the sideways times for the current map.");
	RegConsoleCmd("sm_bwr", SM_BWorldRecord, "Shows bonus record for a map");
	RegConsoleCmd("sm_wrb", SM_BWorldRecord, "Shows bonus record for a map");
	
	RegConsoleCmd("sm_time", SM_Time, "Usage: sm_time or nothing. Shows your time on a given map. With no map given, it will tell you your time on the current map.");
	RegConsoleCmd("sm_pr", SM_Time, "Usage: sm_pr or nothing. Shows your time on a given map. With no map given, it will tell you your time on the current map.");
	RegConsoleCmd("sm_timew", SM_TimeW, "Like sm_time but for W-Only times.");
	RegConsoleCmd("sm_prw", SM_TimeW, "Like sm_pr but for W-Only times.");
	RegConsoleCmd("sm_timesw", SM_TimeSW, "Like sm_time but for Sideways times.");
	RegConsoleCmd("sm_prsw", SM_TimeSW, "Like sm_prsw but for Sideways times.");
	RegConsoleCmd("sm_btime", SM_BTime, "Like sm_time but for Bonus times.");
	RegConsoleCmd("sm_bpr", SM_BTime, "Like sm_pr but for Bonus times.");
	
	RegConsoleCmd("sm_style", SM_Style, "Switch to normal, w, or sideways timer.");
	RegConsoleCmd("sm_mode", SM_Style, "Switches you to normal, w, or sideways timer.");
	RegConsoleCmd("sm_normal", SM_Normal, "Switches you to normal timer.");
	RegConsoleCmd("sm_n", SM_Normal, "Switches you to normal timer.");
	RegConsoleCmd("sm_wonly", SM_WOnly, "Switches you to W-Only timer.");
	RegConsoleCmd("sm_w", SM_WOnly, "Switches you to W-Only timer.");
	RegConsoleCmd("sm_sideways", SM_Sideways, "Switches you to sideways timer.");
	RegConsoleCmd("sm_sw", SM_Sideways, "Switches you to sideways timer.");
	
	RegConsoleCmd("sm_practice", SM_Practice, "Puts you in noclip. Stops your timer.");
	RegConsoleCmd("sm_p", SM_Practice, "Puts you in noclip. Stops your timer.");
	
	RegConsoleCmd("sm_fullhud", SM_Fullhud, "Shows all info in the hint text when being timed.");
	RegConsoleCmd("sm_maxinfo", SM_Fullhud, "Shows all info in the hint text when being timed.");
	RegConsoleCmd("sm_display", SM_Fullhud, "Shows all info in the hint text when being timed.");
	
	RegConsoleCmd("sm_truevel", SM_TrueVelocity, "Toggles between 2D and 3D velocity velocity meters");
	RegConsoleCmd("sm_velocity", SM_TrueVelocity, "Toggles between 2D and 3D velocity velocity meters");
	
	RegConsoleCmd("sm_pause", SM_Pause, "Pauses your timer and freezes you.");
	RegConsoleCmd("sm_unpause", SM_Unpause, "Unpauses your timer and unfreezes you.");
	RegConsoleCmd("sm_resume", SM_Unpause, "Unpauses your timer and unfreezes you.");
	
	// Makes FindTarget() work properly
	LoadTranslations("common.phrases");
	
	// Get MVP offset
	g_iMVPs_offset = FindSendPropInfo("CCSPlayerResource", "m_iMVPs");
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
	
	//g_fwdOnTimerFinished = CreateGlobalForward("OnTimerFinished", ET_Event, Param_Cell, Param_Float, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	return APLRes_Success;
}

public OnMapStart()
{
	// Set the map id
	GetCurrentMap(g_mapname, sizeof(g_mapname));
	
	if(g_MapList != INVALID_HANDLE)
		CloseHandle(g_MapList);
	g_MapList = ReadMapList();
	
	// Start hud hint timer display
	if(g_hTimerDisplay != INVALID_HANDLE)
	{
		KillTimer(g_hTimerDisplay);
		CloseHandle(g_hTimerDisplay);
	}
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
		CloseHandle(g_hTimerChangeClanTag);
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
	for(new i=0; i<3; i++)
	{
		Format(g_sTime[i][client], 48, "Best: Loading..");
	}
	Format(g_sBTime[client], 48, "Best: Loading..");
	
	return true;
}

public OnPlayerIDLoaded(client)
{
	DB_LoadPlayerInfo(client);
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

public OnMapIDPostCheck()
{
	DB_LoadTimes();
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
		CloseHandle(g_hTimerChangeClanTag);
	}
	else
	{
		g_hTimerChangeClanTag = CreateTimer(1.0, SetClanTag, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
}

public PlayerManager_OnThinkPost(entity)
{
	// Set MVP stars to top times
	SetEntDataArray(entity, g_iMVPs_offset, TopTimesCount, MAXPLAYERS+1, 4, true);
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
		g_dJumps[client]++;
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
	Format(query, sizeof(query), "SELECT User, SPJ, SteamID, MStrafes, MJumps FROM (SELECT t2.User, t2.SteamID, AVG(t1.Strafes/t1.Jumps) AS SPJ, SUM(t1.Strafes) AS MStrafes, SUM(t1.Jumps) AS MJumps FROM times AS t1, players AS t2 WHERE t1.PlayerID=t2.PlayerID GROUP BY t1.PlayerID ORDER BY AVG(t1.Strafes/t1.Jumps) DESC) AS x WHERE MStrafes > 100");
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
		
	g_admin_delete[0] = value1;
	g_admin_delete[1] = value2;
	
	AddMenuItem(menu, "Normal", "Normal");
	AddMenuItem(menu, "Sideways", "Sideways");
	AddMenuItem(menu, "W-Only", "W-Only");
	AddMenuItem(menu, "Bonus", "Bonus");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public AdminMenu_DeleteRecord(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		if(StrEqual(info, "Normal"))
		{
			DB_DeleteRecord(param1, TIMER_MAIN, STYLE_NORMAL, g_admin_delete[0], g_admin_delete[1]);
			DB_UpdateRanks(g_mapname, TIMER_MAIN, STYLE_NORMAL);
		}
		else if(StrEqual(info, "Sideways"))
		{
			DB_DeleteRecord(param1, TIMER_MAIN, STYLE_SIDEWAYS, g_admin_delete[0], g_admin_delete[1]);
			DB_UpdateRanks(g_mapname, TIMER_MAIN, STYLE_SIDEWAYS);
		}
		else if(StrEqual(info, "W-Only"))
		{
			DB_DeleteRecord(param1, TIMER_MAIN, STYLE_WONLY, g_admin_delete[0], g_admin_delete[1]);
			DB_UpdateRanks(g_mapname, TIMER_MAIN, STYLE_WONLY);
		}
		else if(StrEqual(info, "Bonus"))
		{
			DB_DeleteRecord(param1, TIMER_BONUS, STYLE_NORMAL, g_admin_delete[0], g_admin_delete[1]);
			DB_UpdateRanks(g_mapname, TIMER_BONUS, STYLE_NORMAL);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

/*
AdminCmd_DeleteRecord_All(client)
{
	new Handle:menu = CreateMenu(AdminMenu_DeleteRecord_All);
	SetMenuTitle(menu, "Delete all records");
	AddMenuItem(menu, "Normal", "Normal");
	AddMenuItem(menu, "Sideways", "Sideways");
	AddMenuItem(menu, "W-Only", "W-Only");
	AddMenuItem(menu, "Bonus", "Bonus");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public AdminMenu_DeleteRecord_All(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		if(StrEqual(info, "Normal"))
		{
			DB_DeleteRecord(param1, TIMER_MAIN, STYLE_NORMAL, 1, DB_GetMapTimesCount(g_mapname, TIMER_MAIN, STYLE_NORMAL));
			DB_UpdateRanks(g_mapname, TIMER_MAIN, STYLE_NORMAL);
		}
		else if(StrEqual(info, "Sideways"))
		{
			DB_DeleteRecord(param1, TIMER_MAIN, STYLE_SIDEWAYS, 1, DB_GetMapTimesCount(g_mapname, TIMER_MAIN, STYLE_SIDEWAYS));
			DB_UpdateRanks(g_mapname, TIMER_MAIN, STYLE_SIDEWAYS);
		}
		else if(StrEqual(info, "W-Only"))
		{
			DB_DeleteRecord(param1, TIMER_MAIN, STYLE_WONLY, 1, DB_GetMapTimesCount(g_mapname, TIMER_MAIN, STYLE_WONLY));
			DB_UpdateRanks(g_mapname, TIMER_MAIN, STYLE_WONLY);
		}
		else if(StrEqual(info, "Bonus"))
		{
			DB_DeleteRecord(param1, TIMER_BONUS, STYLE_NORMAL, 1, DB_GetMapTimesCount(g_mapname, TIMER_BONUS, STYLE_NORMAL));
			DB_UpdateRanks(g_mapname, TIMER_BONUS, STYLE_NORMAL);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}
*/

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
			DB_DisplayRecords(client, g_mapname, TIMER_MAIN, STYLE_NORMAL);
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
		
		LogMessage("%L executed sm_wr", client);
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
			DB_DisplayRecords(client, g_mapname, TIMER_MAIN, STYLE_WONLY);
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
		
		LogMessage("%L executed sm_wrw", client);
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
			DB_DisplayRecords(client, g_mapname, TIMER_MAIN, STYLE_SIDEWAYS);
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
		
		LogMessage("%L executed sm_wrsw", client);
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
			DB_DisplayRecords(client, g_mapname, TIMER_BONUS, STYLE_NORMAL);
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
		
		LogMessage("%L executed sm_bwr", client);
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
			DB_ShowTime(client, client, g_mapname, TIMER_MAIN, STYLE_NORMAL);
		}
		else if(args == 1)
		{
			decl String:arg[250];
			GetCmdArgString(arg, sizeof(arg));
			if(arg[0] == '@')
			{
				ReplaceString(arg, 250, "@", "");
				DB_ShowTimeAtRank(client, g_mapname, StringToInt(arg), TIMER_MAIN, STYLE_NORMAL);
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
					DB_ShowTime(client, target, g_mapname, TIMER_MAIN, STYLE_NORMAL);
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
		
		LogMessage("%L executed sm_time", client);
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
			DB_ShowTime(client, client, g_mapname, TIMER_MAIN, STYLE_WONLY);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(arg[0] == '@')
			{
				ReplaceString(arg, 250, "@", "");
				DB_ShowTimeAtRank(client, g_mapname, StringToInt(arg), TIMER_MAIN, STYLE_WONLY);
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
					DB_ShowTime(client, target, g_mapname, TIMER_MAIN, STYLE_WONLY);
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
		
		LogMessage("%L executed sm_timew", client);
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
			DB_ShowTime(client, client, g_mapname, TIMER_MAIN, STYLE_SIDEWAYS);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(arg[0] == '@')
			{
				ReplaceString(arg, 250, "@", "");
				DB_ShowTimeAtRank(client, g_mapname, StringToInt(arg), TIMER_MAIN, STYLE_SIDEWAYS);
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
					DB_ShowTime(client, target, g_mapname, TIMER_MAIN, STYLE_SIDEWAYS);
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
		
		LogMessage("%L executed sm_timesw", client);
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
			DB_ShowTime(client, client, g_mapname, TIMER_BONUS, STYLE_NORMAL);
		}
		else if(args == 1)
		{
			decl String:arg[64];
			GetCmdArgString(arg, sizeof(arg));
			if(arg[0] == '@')
			{
				ReplaceString(arg, 250, "@", "");
				DB_ShowTimeAtRank(client, g_mapname, StringToInt(arg), TIMER_BONUS, STYLE_NORMAL);
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
					DB_ShowTime(client, target, g_mapname, TIMER_BONUS, STYLE_NORMAL);
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
		
		LogMessage("%L executed sm_btime", client);
	}
	return Plugin_Handled;
}

public Action:SM_Style(client, args)
{
	new Handle:menu = CreateMenu(Menu_Style);
	
	SetMenuTitle(menu, "Change Style");
	AddMenuItem(menu, "Normal", "Normal");
	AddMenuItem(menu, "Sideways", "Sideways");
	AddMenuItem(menu, "W-Only", "W-Only");
	
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
		if(StrEqual(info, "Normal"))
		{
			StopTimer(param1);
			g_timer_style[param1] = STYLE_NORMAL;
			GoToStart(param1);
		}
		else if(StrEqual(info, "Sideways"))
		{
			StopTimer(param1);
			g_timer_style[param1] = STYLE_SIDEWAYS;
			GoToStart(param1);
		}
		else if(StrEqual(info, "W-Only"))
		{
			StopTimer(param1);
			g_timer_style[param1] = STYLE_WONLY;
			GoToStart(param1);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_Normal(client, args)
{
	StopTimer(client);
	g_timer_style[client] = STYLE_NORMAL;
	GoToStart(client);
	
	return Plugin_Handled;
}

public Action:SM_Sideways(client, args)
{
	StopTimer(client);
	g_timer_style[client] = STYLE_SIDEWAYS;
	GoToStart(client);
	
	return Plugin_Handled;
}

public Action:SM_WOnly(client, args)
{
	StopTimer(client);
	g_timer_style[client] = STYLE_WONLY;
	GoToStart(client);
	
	return Plugin_Handled;
}

public Action:SM_Practice(client, args)
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
					if(GetEntityFlags(client) & FL_ONGROUND)
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
						PrintColorText(client, "%s%sYou need to be on the ground to pause your timer.",
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
			PrintColorText(client, "%s%sYou cannot pause while inside a starting zone.",
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
				
				// Get their new start time
				if(IsBeingTimed(client, TIMER_MAIN))
				{
					g_startTime[client] = GetEngineTime() - (g_fPauseTime[client] - g_startTime[client]);
				}
				else
				{
					g_bstartTime[client] = GetEngineTime() - (g_fPauseTime[client] - g_bstartTime[client]);
				}
				
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

public Action:SetClanTag(Handle:timer, any:data)
{
	for(new client=1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(IsPlayerAlive(client))
			{
				if(!IsFakeClient(client))
				{
					if(IsBeingTimed(client, TIMER_MAIN))
					{
						new const String:stylename[3][] = {"N", "SW", "W"};
						decl String:formattime[32], String:taginfo[32];
						
						new Float:time = GetClientTimer(client, TIMER_MAIN);
						FormatPlayerTime(time, formattime, sizeof(formattime), false, 0);
						SplitString(formattime, ".", formattime, sizeof(formattime));
						Format(taginfo, sizeof(taginfo), "%s :: %s ::", stylename[g_timer_style[client]], formattime);
						
						CS_SetClientClanTag(client, taginfo);
					}
					else if(IsBeingTimed(client, TIMER_BONUS))
					{
						decl String:bformattime[32];
						
						new Float:btime = GetClientTimer(client, TIMER_BONUS);
						FormatPlayerTime(btime, bformattime, sizeof(bformattime), false, 0);
						SplitString(bformattime, ".", bformattime, sizeof(bformattime));
						Format(bformattime, sizeof(bformattime), "B :: %s ::", bformattime);
						
						CS_SetClientClanTag(client, bformattime);
					}
					else
					{
						CS_SetClientClanTag(client, "No timer");
					}
				}
			}
		}
	}
}

ResetClientInfo(client)
{
	// Set player times to null
	for(new i=0; i<3; i++)
	{
		g_times[i][client] = 0.0;
	}
	g_btimes[client] = 0.0;
	
	// Set style to normal (default)
	g_timer_style[client] = 0;
	
	// Set their top times count for mvp stars
	TopTimesCount[client] = 0;
	
	// Unpause timers
	g_bPaused[client] = false;
}

public Action:LoopTimerDisplay(Handle:timer, any:data)
{
	new String:timerString[256];
	for(new client=1; client<=MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(IsPlayerAlive(client))
			{
				if(GetClientID(client) != 0)
				{
					new time = RoundToFloor(g_times[0][client]);
					if(g_times[0][client] == 0.0 || g_times[0][client] > 2000.0)
						time = 2000;
					SetEntProp(client, Prop_Data, "m_iFrags", -time);
				}
				if(IsBeingTimed(client, TIMER_ANY))
				{
					if(g_bPaused[client] == false)
					{
						if(GetClientButtons(client) & IN_USE || GetClientSettings(client) & SHOW_HINT)
						{
							GetTimerAdvancedString(client, timerString);
							PrintHintText(client, "%s", timerString);
						}
						else
						{
							GetTimerSimpleString(client, timerString);
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
								GetTimerAdvancedString(Target, timerString);
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

GetTimerAdvancedString(client, String:result[256])
{
	if(IsInAStartZone(client))
	{
		Format(result, sizeof(result), "In start zone");
	}
	else
	{
		new Float:RealTime = GetClientTimer(client, g_timer_type[client]);
		new String:num[32];
		FormatPlayerTime(RealTime, num, sizeof(num), false, 0);
			
		if(g_timer_type[client] == TIMER_MAIN)
		{
			if(g_timer_style[client] == STYLE_NORMAL)
			{
				Format(result, sizeof(result), "Time: %s (%d)\nJumps: %d\nStrafes: %d\nSpeed: %d",
					num,
					GetPlayerPosition(RealTime, TIMER_MAIN, STYLE_NORMAL),
					g_dJumps[client],
					g_dStrafes[client],
					RoundToFloor(GetClientVelocity(client, true, true, bool:(GetClientSettings(client) & SHOW_2DVEL))));
			}
			else if(g_timer_style[client] == STYLE_WONLY)
			{
				Format(result, sizeof(result), "W-Only%s\nTime: %s (%d)\nJumps: %d\nSpeed: %d",
					(IsInAFreeStyleZone(client))?" (FS)":"",
					num, 
					GetPlayerPosition(RealTime, TIMER_MAIN, STYLE_WONLY),
					g_dJumps[client],
					RoundToFloor(GetClientVelocity(client, true, true, bool:(GetClientSettings(client) & SHOW_2DVEL))));
			}
			else if(g_timer_style[client] == STYLE_SIDEWAYS)
			{
				Format(result, sizeof(result), "Sideways%s\nTime: %s (%d)\nJumps: %d\nStrafes: %d\nSpeed: %d",
					(IsInAFreeStyleZone(client))?" (FS)":"",
					num, 
					GetPlayerPosition(RealTime, TIMER_MAIN, STYLE_SIDEWAYS),
					g_dJumps[client],
					g_dStrafes[client],
					RoundToFloor(GetClientVelocity(client, true, true, bool:(GetClientSettings(client) & SHOW_2DVEL))));
			}
		}
		else if(g_timer_type[client] == TIMER_BONUS)
		{
			Format(result, sizeof(result), "Bonus\nTime: %s (%d)\nJumps: %d\nStrafes: %d\nSpeed: %d",
				num, 
				GetPlayerPosition(RealTime, TIMER_BONUS, STYLE_NORMAL),
				g_dJumps[client],
				g_dStrafes[client],
				RoundToFloor(GetClientVelocity(client, true, true, bool:(GetClientSettings(client) & SHOW_2DVEL))));
		}
	}
}

GetTimerSimpleString(client, String:result[256])
{
	decl String:num[32];
	if(IsInAStartZone(client))
	{
		Format(result, sizeof(result), "In start zone");
	}
	else
	{
		new Float:RealTime = GetClientTimer(client, g_timer_type[client]);
		FormatPlayerTime(RealTime, num, sizeof(num), false, 0);
		Format(result, sizeof(result), "%s", num);
	}
}

GetTimerPauseString(client, String:buffer[], maxlen)
{
	decl String:sTime[32];
	new Float:fTime;
	if(g_timer_type[client] == TIMER_MAIN)
	{
		fTime = g_fPauseTime[client] - g_startTime[client];
	}
	else
	{
		fTime = g_fPauseTime[client] - g_bstartTime[client];
	}
	FormatPlayerTime(fTime, sTime, sizeof(sTime), false, 0);
	Format(buffer, maxlen, "Paused\n \nTime: %s", sTime);
}

GetPlayerPosition(const Float:time, Type, Style)
{	
	if(Type == TIMER_MAIN)
	{
		new iSize = GetArraySize(g_hTimes[Style]);
		
		for(new i=0; i<iSize; i++)
		{
			if(time <= GetArrayCell(g_hTimes[Style], i, 1))
			{
				return i+1;
			}
		}
		
		return iSize;
	}
	else
	{
		new iSize = GetArraySize(g_hBTimes);
		
		for(new i=0; i<iSize; i++)
		{
			if(time <= GetArrayCell(g_hBTimes, i, 1))
			{
				return i+1;
			}
		}
		
		return iSize;
	}
}

GetPlayerPositionByID(PlayerID, Type, Style)
{
	new Handle:hTimes;
	
	if(Type == TIMER_MAIN)
	{
		hTimes = CloneHandle(g_hTimes[Style]);
	}
	else
	{
		hTimes = CloneHandle(g_hBTimes);
	}
	
	new iSize = GetArraySize(hTimes);
	
	for(new i=0; i<iSize; i++)
	{
		if(PlayerID == GetArrayCell(hTimes, i, 0))
			return i+1;
	}
	
	CloseHandle(hTimes);
	return iSize;
}

// Controls what shows up on the right side of players screen, KeyHintText
public Action:Timer_SpecList(Handle:timer, any:data)
{
	// Different arrays for admins and non-admins
	new 	SpecCount[MaxClients+1], AdminSpecCount[MaxClients+1];
	SpecCountToArrays(SpecCount, AdminSpecCount);

	new String:message[256];
	for(new client=1; client<=MaxClients; client++)
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
	for(new client=1; client <= MaxClients; client++)
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
	
	new timelimit;
	GetMapTimeLimit(timelimit);
	if(GetConVarBool(g_hShowTimeLeft) && timelimit != 0)
	{
		new timeleft;
		GetMapTimeLeft(timeleft);
		
		if(timeleft <= 0)
		{
			Format(message, maxlength, "Time left: Map finished\n \n");
		}
		else if(timeleft < 60)
		{
			Format(message, maxlength, "Time left: <1 minute\n \n");
		}
		else
		{
			// Format the time left
			new minutes 	= RoundToFloor(float(timeleft)/60);
			
			Format(message, maxlength, "Time left: %d minutes\n \n", minutes);
		}
	}
	
	if(!IsFakeClient(target))
	{
		new position;
		if(IsBeingTimed(target, TIMER_BONUS))
		{
			Format(message, maxlength, "%s%s\n%s", message, g_brecord, g_sBTime[target]);
			
			if(g_btimes[target] != 0.0)
			{
				position = GetPlayerPositionByID(GetClientID(target), TIMER_BONUS, STYLE_NORMAL);
				Format(message, maxlength, "%s (#%d)", message, position);
			}
		}
		else
		{
			Format(message, maxlength, "%s%s\n%s", message, g_record[g_timer_style[target]], g_sTime[g_timer_style[target]][target]);
			
			if(g_times[g_timer_style[target]][target] != 0.0)
			{
				position = GetPlayerPositionByID(GetClientID(target), TIMER_MAIN, g_timer_style[target]);
				Format(message, maxlength, "%s (#%d)", message, position);
			}
		}
	}
	
	new bool:bClientIsAdmin = GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective);
	if(IsBeingTimed(target, TIMER_ANY) && !IsFakeClient(target) && bClientIsAdmin && (g_timer_style[target] == STYLE_NORMAL || g_timer_type[target] == TIMER_BONUS))
		Format(message, maxlength, "%s\nSync: %.1f", message, GetClientSync(target));
	else
		Format(message, maxlength, "%s\n", message);
	
	Format(message, maxlength, "%s\n \nSpectators: %d\n", message, (bClientIsAdmin)?AdminSpecCount[target]:SpecCount[target]);
	
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
	
	if(TimerCanStart(client))
	{
		// for the ghost
		ResetPlayerFrames(client);

		g_dJumps[client] 		= 0;
		g_dStrafes[client] 		= 0;
		g_dSWStrafes[client][0] 	= 1;
		g_dSWStrafes[client][1] 	= 1;
		g_bPaused[client]		= false;
		g_totalSync[client]		= 0;
		g_goodSync[client]		= 0;
		g_goodSyncVel[client]    	= 0;

		new TimerType = GetNativeCell(2);

		if(TimerType == TIMER_MAIN)
		{
			StopTimer(client);
			g_timer_type[client] = TIMER_MAIN;
			g_timing[client]     = true;
			g_startTime[client]  = GetEngineTime();
		}
		else if(TimerType == TIMER_BONUS)
		{
			StopTimer(client);
			g_timer_type[client]  = TIMER_BONUS;
			g_btiming[client]     = true;
			g_bstartTime[client]  = GetEngineTime();
		}
	}
}

bool:TimerCanStart(client)
{
	// Fixes a bug for players to completely cheat times by spawning in weird parts of the map
	if(GetEngineTime() < (g_fSpawnTime[client] + 0.1))
	{
		return false;
	}
	
	// Don't start if their speed isn't default
	if(GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") != 1.0)
	{
		WarnClient(client, "Your movement speed is off. Type !normalspeed to set it to default.");
		return false;
	}
	
	// Don't start if they are in noclip
	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
	{
		return false;
	}
	
	// Don't start if their gravity isn't normal
	if(GetEntityGravity(client) != 0.0)
	{
		SetEntityGravity(client, 0.0);
		return false;
	}
	
	// Don't start if they are a fake client
	if(IsFakeClient(client))
	{
		return false;
	}
	
	return true;
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
			g_timing[client]  = false;
			g_btiming[client] = false;
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
	new client    = GetNativeCell(1);
	new TimerType = GetNativeCell(2);
	
	if(TimerType == TIMER_ANY)
	{
		return (g_timing[client] || g_btiming[client]);
	}
	else if(TimerType == TIMER_MAIN)
	{
		return g_timing[client];
	}
	else if(TimerType == TIMER_BONUS)
	{
		return g_btiming[client];
	}
	return false;
}

bool:ShouldTimerFinish(client, Type, Style)
{
	if(GetClientID(client) == 0)
		return false;
	
	if(g_bPaused[client] == true)
		return false;
	
	// Anti-cheat sideways
	if(Type == TIMER_MAIN && Style == STYLE_SIDEWAYS)
	{
		new Float:WSRatio = float(g_dSWStrafes[client][0])/float(g_dSWStrafes[client][1]);
		if((WSRatio > 2.0) || (g_dStrafes[client] < 10))
		{
			PrintColorText(client, "%s%sThat time did not count because your W:S ratio (%s%4.1f%s) was too large or your strafe count (%s%d%s) was too small.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				WSRatio*100.0,
				g_msg_textcol,
				g_msg_varcol,
				g_dStrafes[client],
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
	new Type   = g_timer_type[client];
	new Style  = g_timer_style[client];
	
	if(ShouldTimerFinish(client, Type, Style))
	{
		// get their time
		new Float:newTime;
		if(IsBeingTimed(client, TIMER_MAIN))
		{
			newTime = GetClientTimer(client, TIMER_MAIN);
		}
		else if(IsBeingTimed(client, TIMER_BONUS))
		{
			newTime = GetClientTimer(client, TIMER_BONUS);
		}
		
		//new Pos = GetPlayerPosition(client, newTime);
		
		StopTimer(client);
		
		// If time is an improvement
		if(((newTime < g_times[Style][client] || g_times[Style][client] == 0.0) && Type == TIMER_MAIN) || ((newTime < g_btimes[client] || g_btimes[client] == 0.0) && Type == TIMER_BONUS))
		{
			// save the time
			if(Type == TIMER_MAIN)
				DB_UpdateTime(client, Type, Style, newTime, g_dJumps[client], g_dStrafes[client], GetClientSync(client));
			else
				DB_UpdateTime(client, Type, 0, newTime, g_dJumps[client], g_dStrafes[client], GetClientSync(client));
			
			new const String:StyleString[3][] = {"", "[SIDEWAYS] ", "[W-ONLY] "};
			decl String:newTimeString[32], String:name[MAX_NAME_LENGTH];
			GetClientName(client, name, sizeof(name));
			FormatPlayerTime(newTime, newTimeString, sizeof(newTimeString), false, 1);
			
			if(Type == TIMER_MAIN)
			{
				// Set players new time string for key hint
				Format(g_sTime[Style][client], 48, "Best: %s", newTimeString);
				
				// Set client's personal best variable
				g_times[Style][client] = newTime;
				
				// If it's a WR
				if(newTime < g_WorldRecord[Style] || g_WorldRecord[Style] == 0.0)
				{
					// Set the worldrecord variable to the new time
					g_WorldRecord[Style] = newTime;
					
					// Save new ghost if it's on normal style
					if(Style == STYLE_NORMAL)
						SaveGhost(client, newTime);
					
					PlayRecordSound();
					
					// Set new key hint text message
					Format(g_record[Style], 48, "%s (%s)", newTimeString, name);
					
					// Print WR message to all players
					if(Style != STYLE_WONLY)
					{
						PrintColorTextAll("%s%sNEW %s%s%sRecord by %s%s %sin %s%s%s (%s%d%s jumps, %s%d%s strafes)",
							g_msg_start,
							g_msg_textcol,
							g_msg_varcol,
							StyleString[Style],
							g_msg_textcol,
							g_msg_varcol,
							name,
							g_msg_textcol,
							g_msg_varcol,
							newTimeString,
							g_msg_textcol,
							g_msg_varcol,
							g_dJumps[client],
							g_msg_textcol,
							g_msg_varcol,
							g_dStrafes[client],
							g_msg_textcol);
					}
					else
					{
						PrintColorTextAll("%s%sNEW %s%s%sRecord by %s%s %sin %s%s%s (%s%d%s jumps)",
							g_msg_start,
							g_msg_textcol,
							g_msg_varcol,
							StyleString[Style],
							g_msg_textcol,
							g_msg_varcol,
							name,
							g_msg_textcol,
							g_msg_varcol,
							newTimeString,
							g_msg_textcol,
							g_msg_varcol,
							g_dJumps[client],
							g_msg_textcol);
					}
				}
				else //If it's just an improvement
				{
					FormatPlayerTime(newTime, newTimeString, sizeof(newTimeString), false, 1);
					if(Style != STYLE_WONLY)
					{
						PrintColorTextAll("%s%s%s%s %sfinished in %s%s%s (%s%d%s jumps, %s%d%s strafes)", 
							g_msg_start,
							g_msg_varcol,
							StyleString[Style], 
							name, 
							g_msg_textcol,
							g_msg_varcol,
							newTimeString,
							g_msg_textcol,
							g_msg_varcol,
							g_dJumps[client],
							g_msg_textcol,
							g_msg_varcol,
							g_dStrafes[client],
							g_msg_textcol);
					}
					else
					{
						PrintColorTextAll("%s%s%s%s %sfinished in %s%s%s (%s%d%s jumps)", 
							g_msg_start,
							g_msg_varcol,
							StyleString[Style], 
							name, 
							g_msg_textcol,
							g_msg_varcol,
							newTimeString,
							g_msg_textcol,
							g_msg_varcol,
							g_dJumps[client],
							g_msg_textcol);
					}
				}
			}
			else if(Type == TIMER_BONUS)
			{
				// Set players new time string for key hint
				Format(g_sBTime[client], 48, "Best: %s", newTimeString);
				
				// Set client's personal best
				g_btimes[client] = newTime;
				
				// If it's a top time
				if(newTime < g_bWorldRecord || g_bWorldRecord == 0.0)
				{
					// Set the worldrecord variable to the new time
					g_bWorldRecord = newTime;
					
					PlayRecordSound();
					
					//Set new key hint text message
					Format(g_brecord, sizeof(g_brecord), "%s (%s)", newTimeString, name);
					
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
						g_dJumps[client],
						g_msg_textcol,
						g_msg_varcol,
						g_dStrafes[client],
						g_msg_textcol);
				}
				else // If it's just an improvement
				{
					FormatPlayerTime(newTime, newTimeString, sizeof(newTimeString), false, 1);
					PrintColorTextAll("%s%s[BONUS] %s %sfinished in %s%s%s (%s%d%s jumps, %s%d%s strafes)", 
						g_msg_start,
						g_msg_varcol,
						name, 
						g_msg_textcol,
						g_msg_varcol,
						newTimeString,
						g_msg_textcol,
						g_msg_varcol,
						g_dJumps[client],
						g_msg_textcol,
						g_msg_varcol,
						g_dStrafes[client],
						g_msg_textcol);
				}
			}
		}
		else
		{
			new const String:styleString[3][] = {"", "[SIDEWAYS] ", "[W-ONLY] "};
			decl String:time[32], String:personalBest[32];
			FormatPlayerTime(newTime, time, sizeof(time), false, 2);
			
			if(Type == TIMER_MAIN)
			{
				FormatPlayerTime(g_times[g_timer_style[client]][client], personalBest, sizeof(personalBest), true, 1);
				
				PrintColorText(client, "%s%s%s%sYou finished in %s%s%s, but did not improve on your previous time of %s%s",
					g_msg_start,
					g_msg_varcol,
					styleString[Style],
					g_msg_textcol,
					g_msg_varcol,
					time,
					g_msg_textcol,
					g_msg_varcol,
					personalBest);
			}
			else
			{
				FormatPlayerTime(g_btimes[client], personalBest, sizeof(personalBest), true, 1);
				
				PrintColorText(client, "%s%s[BONUS] %sYou finished in %s%s%s, but did not improve on your previous time of %s%s",
					g_msg_start,
					g_msg_varcol,
					g_msg_textcol,
					g_msg_varcol,
					time,
					g_msg_textcol,
					g_msg_varcol,
					personalBest);
			}
		}
	}
}

Float:GetClientTimer(client, TimerType)
{
	if(TimerType == TIMER_MAIN)
	{
		return GetEngineTime() - g_startTime[client];
	}
	else if(TimerType == TIMER_BONUS)
	{
		return GetEngineTime() - g_bstartTime[client];
	}
	else
	{
		return 0.0;
	}
}

LoadRecordSounds()
{
	
	
	// Re-intizialize array to remove any current sounds loaded
	if(g_hSoundsArray != INVALID_HANDLE)
		ClearArray(g_hSoundsArray);
	else
		g_hSoundsArray = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	
	// Create path and file variables
	decl String:sPath[PLATFORM_MAX_PATH], Handle:hFile;
	
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
		
		// Close it if it was opened succesfully
		if(hFile != INVALID_HANDLE)
			CloseHandle(hFile);
	}
	
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
		
		for(new client=1; client<=MaxClients; client++)
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
	if(!IsFakeClient(client))
	{
		decl String:query[512];
		Format(query, sizeof(query), "SELECT Type, Style, Time FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND PlayerID=%d",
			g_mapname,
			GetClientID(client));
		SQL_TQuery(g_DB, DB_LoadPlayerInfo_Callback, query, client);
	}
}

public DB_LoadPlayerInfo_Callback(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if(hndl != INVALID_HANDLE)
	{
		new rows = SQL_GetRowCount(hndl), Type, Style, Float:Time;
		
		for(new i=0; i<rows; i++)
		{
			SQL_FetchRow(hndl);
			
			Type  = SQL_FetchInt(hndl, 0);
			Style = SQL_FetchInt(hndl, 1);
			Time  = SQL_FetchFloat(hndl, 2);
			
			if(Type == TIMER_MAIN)
			{
				// Set player's time
				g_times[Style][client] = Time;
			}
			else if(Type == TIMER_BONUS)
			{
				// Set player's time
				g_btimes[client] = Time;
			}
		}
		
		for(new i=0; i<3; i++)
		{
			if(g_times[i][client])
			{
				FormatPlayerTime(g_times[i][client], g_sTime[i][client], 48, false, 1);
				Format(g_sTime[i][client], 48, "Best: %s", g_sTime[i][client]);
			}
			else
			{
				Format(g_sTime[i][client], 48, "Best: No time");
			}
		}
		
		if(g_btimes[client])
		{
			// Format key hint text
			FormatPlayerTime(g_btimes[client], g_sBTime[client], 48, false, 1);
			Format(g_sBTime[client], 48, "Best: %s", g_sBTime[client]);
		}
		else
		{
			// Format key hint text
			Format(g_sBTime[client], 48, "Best: No time");
		}
		
		
	}
	else
	{
		LogError(error);
	}
}

public Native_GetClientStyle(Handle:plugin, numParams)
{
	return g_timer_style[GetNativeCell(1)];
}

public Native_IsTimerPaused(Handle:plugin, numParams)
{
	return g_bPaused[GetNativeCell(1)];
}

// Adds or updates a player's record on the map
DB_UpdateTime(client, Type, Style, Float:Time, Jumps, Strafes, Float:Sync)
{
	if(GetClientID(client) != 0)
	{
		if(!IsFakeClient(client))
		{
			new Handle:data = CreateDataPack();
			WritePackCell(data, client);
			WritePackCell(data, Type);
			WritePackCell(data, Style);
			WritePackFloat(data, Time);
			WritePackCell(data, Jumps);
			WritePackCell(data, Strafes);
			WritePackFloat(data, Sync);
			
			decl String:query[256];
			Format(query, sizeof(query), "DELETE FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND Type=%d AND Style=%d AND PlayerID=%d",
				g_mapname,
				Type,
				Style,
				GetClientID(client));
			SQL_TQuery(g_DB, DB_UpdateTime_Callback1, query, data);
		}
	}
}

public DB_UpdateTime_Callback1(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client		= ReadPackCell(data);
		new Type		= ReadPackCell(data);
		new Style 		= ReadPackCell(data);
		new Float:Time 	= ReadPackFloat(data);
		new Jumps 		= ReadPackCell(data);
		new Strafes 	= ReadPackCell(data);
		new Float:Sync  = ReadPackFloat(data);
		
		decl String:query[512];
		Format(query, sizeof(query), "INSERT INTO times (MapID, Type, Style, PlayerID, Time, Jumps, Strafes, Points, Timestamp, Sync) VALUES ((SELECT MapID FROM maps WHERE MapName='%s'), %d, %d, %d, %f, %d, %d, 0, %d, %f)", 
			g_mapname,
			Type,
			Style,
			GetClientID(client),
			Time,
			Jumps,
			Strafes,
			GetTime(),
			Sync);
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
		ResetPack(data);
		ReadPackCell(data);
		new Type  = ReadPackCell(data);
		new Style = ReadPackCell(data);
		
		DB_UpdateRanks(g_mapname, Type, Style);
		DB_LoadTimes();
		
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
DB_DisplayRecords(client, String:mapname[], Type, Style)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, Type);
	WritePackCell(pack, Style);
	WritePackString(pack, mapname);
	
	decl String:query[256];
	Format(query, sizeof(query), "SELECT Time, User, Jumps, Strafes, Points, Timestamp, T.PlayerID, Sync FROM times AS T JOIN players AS P ON T.PlayerID=P.PlayerID AND MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND Type=%d AND Style=%d ORDER BY Time",
		mapname,
		Type,
		Style);
	SQL_TQuery(g_DB, DB_DisplayRecords_Callback1, query, pack);
}

public DB_DisplayRecords_Callback1(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		decl String:mapname[64];
		ResetPack(data);
		new client = ReadPackCell(data);
		new Type   = ReadPackCell(data);
		new Style  = ReadPackCell(data);
		ReadPackString(data, mapname, sizeof(mapname));
		
		new rowcount = SQL_GetRowCount(hndl);
		if(rowcount != 0)
		{	
			decl String:name[(MAX_NAME_LENGTH*2)+1], String:title[128], String:item[256], String:info[256], String:sTime[32], Float:time, 
			Float:points, jumps, strafes, timestamp, PlayerID, Float:ClientTime, MapRank, Float:Sync;
			new const String:type_Name[2][] = {" ", " Bonus "};
			new const String:style_Name[3][] = {" ", " (Sideways)", " (W-Only)"};
			
			new Handle:menu = CreateMenu(Menu_WorldRecord);	
			new RowCount = SQL_GetRowCount(hndl);
			for(new i=1; i<=RowCount; i++)
			{
				SQL_FetchRow(hndl);
				time 	= SQL_FetchFloat(hndl, 0);
				SQL_FetchString(hndl, 1, name, sizeof(name));
				jumps 	= SQL_FetchInt(hndl, 2);
				FormatPlayerTime(time, sTime, sizeof(sTime), false, 1);
				strafes 	= SQL_FetchInt(hndl, 3);
				points 	= SQL_FetchFloat(hndl, 4);
				timestamp 	= SQL_FetchInt(hndl, 5);
				PlayerID 	= SQL_FetchInt(hndl, 6);
				Sync     	= SQL_FetchFloat(hndl, 7);
				
				if(PlayerID == GetClientID(client))
				{
					ClientTime	= time;
					MapRank	= i;
				}
				
				// 33 spaces because names can't hold that many characters
				Format(info, sizeof(info), "%s                                 %d %d %s %f %d %d %d %d %d %s %f",
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
					mapname,
					Sync);
					
				if(Style == STYLE_WONLY)
				{
					Format(item, sizeof(item), "#%d: %s - %s",
						i,
						sTime,
						name);
				}
				else
				{
					Format(item, sizeof(item), "#%d: %s - %s",
						i,
						sTime,
						name);
				}
				
				if((i % 7) == 0)
					Format(item, sizeof(item), "%s\n--------------------------------------", item);
				else if(i == RowCount)
					Format(item, sizeof(item), "%s\n--------------------------------------", item);
				AddMenuItem(menu, info, item);
			}
			
			decl String:sClientTime[32];
			if(ClientTime != 0.0)
			{
				FormatPlayerTime(ClientTime, sClientTime, sizeof(sClientTime), false, 1);
				Format(title, sizeof(title), "%s%srecords%s\n \nYour time: %s ( %d / %d )\n--------------------------------------",
					mapname,
					type_Name[Type],
					style_Name[Style],
					sClientTime,
					MapRank,
					rowcount);
			}
			else
			{
				Format(title, sizeof(title), "%s%srecords%s\n \n%d total\n--------------------------------------",
					mapname,
					type_Name[Type],
					style_Name[Style],
					rowcount);
			}
			SetMenuTitle(menu, title);
			
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
		else
		{
			PrintColorText(client, "%s%sNo one has beaten the map yet",
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
		
		decl String:infosplode[11][128], String:infosplodetwo[2][256];
		ExplodeString(info, "                                 ", infosplodetwo, 2, 256);
		
		ExplodeString(infosplodetwo[1], " ", infosplode, 11, 128);
		
		ShowRecordInfo(param1, infosplodetwo[0], infosplode);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

ShowRecordInfo(client, String:name[256], String:info[11][128])//, const String:name[MAX_NAME_LENGTH])
{
	new Type  			= StringToInt(info[0]);
	new Style 			= StringToInt(info[1]);
	
	new Handle:menu = CreatePanel(INVALID_HANDLE);
	
	decl String:title[48];
	Format(title, sizeof(title), "Record details of %s", name);
	DrawPanelText(menu, title);
	DrawPanelText(menu, " ");
	
	decl String:sMap[128];
	Format(sMap, sizeof(sMap), "Map: %s", info[9]);
	DrawPanelText(menu, sMap);
	DrawPanelText(menu, " ");
	
	decl String:sTime[48];
	Format(sTime, sizeof(sTime), "Time: %s (%s/%s)", info[2], info[4], info[5]);
	DrawPanelText(menu, sTime);
	DrawPanelText(menu, " ");
	
	decl String:sPoints[24];
	Format(sPoints, sizeof(sPoints), "Points earned: %s", info[3]);
	DrawPanelText(menu, sPoints);
	DrawPanelText(menu, " ");
	
	new const String:sType[2][] = {"Type: Main", "Type: Bonus"};
	DrawPanelText(menu, sType[Type]);
	
	new const String:sStyle[3][] = {"Style: Normal", "Style: Sideways", "Style: W-Only"};
	DrawPanelText(menu, sStyle[Style]);
	DrawPanelText(menu, " ");
	
	if(Style != STYLE_WONLY)
	{
		decl String:sStrafes[32];
		Format(sStrafes, sizeof(sStrafes), "Jumps/Strafes: %s/%s", info[7], info[8]);
		DrawPanelText(menu, sStrafes);
	}
	else
	{
		decl String:sJumps[16];
		Format(sJumps, sizeof(sJumps), "Jumps: %s", info[7]);
		DrawPanelText(menu, sJumps);
	}
	DrawPanelText(menu, " ");
	
	decl String:sTimeStamp[32];
	FormatTime(sTimeStamp, sizeof(sTimeStamp), "%x %X", StringToInt(info[6]));
	Format(sTimeStamp, sizeof(sTimeStamp), "Date: %s", sTimeStamp);
	DrawPanelText(menu, sTimeStamp);
	
	
	if(GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective) && Style == STYLE_NORMAL)
	{
		decl String:sSync[32];
		Format(sSync, sizeof(sSync), "\n \nSync: %.1f%%", StringToFloat(info[10]));
		DrawPanelText(menu, sSync);
	}
	
	DrawPanelText(menu, "\n \n0. Close");
	
	SendPanelToClient(menu, client, Menu_ShowRecordInfo, MENU_TIME_FOREVER);
}

public Menu_ShowRecordInfo(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//new String:info[128];
		//GetMenuItem(menu, param2, info, sizeof(info));		
	}
	else if (action == MenuAction_End)
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
	Format(query, sizeof(query), "SELECT t2.User, t1.Time, t1.Jumps, t1.Strafes, t1.Points, t1.Timestamp FROM times AS t1, players AS t2 WHERE t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND t1.PlayerID=t2.PlayerID AND t1.Type=%d AND t1.Style=%d ORDER BY t1.Time LIMIT %d, 1",
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
			new const String:sStyle[3][] = {"", "[SIDEWAYS] ", "[W-ONLY] "};
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
			
			if(Style == STYLE_WONLY)
			{
				PrintColorText(client, "%s%s%s%s%s has time %s%s%s\n(%s%d%s jumps, %s%.1f%s points)\nDate: %s%s %s%s.",
					g_msg_start,
					g_msg_varcol,
					(Type==0)?sStyle[Style]:"[BONUS] ",
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
				PrintColorText(client, "%s%s%s%s%s has time %s%s%s\n(%s%d%s jumps, %s%d%s strafes, %s%f%s points)\nDate: %s%s %s%s.",
					g_msg_start,
					g_msg_varcol,
					(Type==0)?sStyle[Style]:"[BONUS] ",
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
	
	new PlayerID = GetClientID(target);
	
	decl String:query[800];
	FormatEx(query, sizeof(query), "SELECT (SELECT count(*) FROM times WHERE Time<=(SELECT Time FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND Type=%d AND Style=%d AND PlayerID=%d) AND MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND Type=%d AND Style=%d) AS Rank, (SELECT count(*) FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND Type=%d AND Style=%d) AS Timescount, Time, Jumps, Strafes, Points, Timestamp FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND Type=%d AND Style=%d AND PlayerID=%d", 
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
		new Type	= ReadPackCell(pack);
		new Style 	= ReadPackCell(pack);
		
		new TargetID = GetClientID(target);
		
		if(IsClientInGame(client) && IsClientInGame(target) && TargetID)
		{
			new const String:sStyleString[3][] = {"", "[SIDEWAYS] ", "[W-ONLY] "};
			decl String:sTime[32], String:sDate[32], String:sDateDay[32], String:sName[MAX_NAME_LENGTH];
			GetClientName(target, sName, sizeof(sName));
			
			if(SQL_GetRowCount(hndl) == 1)
			{
				SQL_FetchRow(hndl);
				new Rank 		 = SQL_FetchInt(hndl, 0);
				new Timescount   = SQL_FetchInt(hndl, 1);
				new Float:Time 	 = SQL_FetchFloat(hndl, 2);
				new Jumps 		 = SQL_FetchInt(hndl, 3);
				new Strafes 	 = SQL_FetchInt(hndl, 4);
				new Float:Points = SQL_FetchFloat(hndl, 5);
				new TimeStamp 	 = SQL_FetchInt(hndl, 6);
				
				FormatPlayerTime(Time, sTime, sizeof(sTime), false, 1);
				FormatTime(sDate, sizeof(sDate), "%x", TimeStamp);
				FormatTime(sDateDay, sizeof(sDateDay), "%X", TimeStamp);
				
				if(Style != STYLE_WONLY)
				{
					PrintColorText(client, "%s%s%s%s %shas time %s%s%s (%s%d%s / %s%d%s)",
						g_msg_start,
						g_msg_varcol,
						(Type==0)?sStyleString[Style]:"[BONUS] ",
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
				PrintColorText(client, "%s%s%s%s %shas no time on the map.",
					g_msg_start,
					g_msg_varcol,
					(Type==0)?sStyleString[Style]:"[BONUS] ",
					sName,
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

DB_GetTopOneTimesCount(client)
{
	if(IsClientInGame(client) && GetClientID(client) != 0)
	{
		decl String:query[512];
		Format(query, sizeof(query), "SELECT COUNT(*) FROM (SELECT PlayerID, MIN(Time) FROM times GROUP BY MapID, Type, Style) AS t1 WHERE PlayerID=%d",
			GetClientID(client));
		SQL_TQuery(g_DB, DB_GetTopOneTimesCount_Callback, query, client);
	}
}

public DB_GetTopOneTimesCount_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		SQL_FetchRow(hndl);
		TopTimesCount[data] = SQL_FetchInt(hndl, 0);
	}
	else
	{
		LogError(error);
	}
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
	Format(query, sizeof(query), "SELECT COUNT(*) FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND Type=%d AND Style=%d",
		g_mapname,
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
		
		new const String:type_Name[2][] = {"", "[BONUS] "};
		new const String:style_Name[3][] = {"(Normal)", "(Sideways)", "(W-Only)"};
		if(RecordTwo > timesCount)
		{
			PrintColorText(client, "%s%s%s%sThere is no record %s%d %s", 
				g_msg_start,
				g_msg_varcol,
				type_Name[Type], 
				g_msg_textcol,
				g_msg_varcol,
				RecordTwo, 
				style_Name[Style]);
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
		Format(query, sizeof(query), "DELETE FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND Type=%d AND Style=%d AND Time BETWEEN (SELECT t1.Time FROM (SELECT * FROM times) AS t1 WHERE t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND t1.Type=%d AND t1.Style=%d ORDER BY t1.Time LIMIT %d, 1) AND (SELECT t2.Time FROM (SELECT * FROM times) AS t2 WHERE t2.MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND t2.Type=%d AND t2.Style=%d ORDER BY t2.Time LIMIT %d, 1)",
			g_mapname,
			Type,
			Style,
			g_mapname,
			Type,
			Style,
			RecordOne-1,
			g_mapname,
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
		new Type 		= ReadPackCell(data);
		new Style		= ReadPackCell(data);
		new RecordOne   = ReadPackCell(data);
		new RecordTwo   = ReadPackCell(data);
		
		new PlayerID;
		for(new client=1; client<=MaxClients; client++)
		{
			PlayerID = GetClientID(client);
			if(GetClientID(client) != 0 && IsClientInGame(client))
			{
				for(new idx=RecordOne-1; idx<RecordTwo; idx++)
				{
					if(Type == TIMER_MAIN)
					{
						if(GetArrayCell(g_hTimes[Style], idx, 0) == PlayerID)
						{
							g_times[Style][client] = 0.0;
							Format(g_sTime[Style][client], 48, "Best: No time");
						}
					}
					else
					{
						if(GetArrayCell(g_hTimes[Style], idx, 0) == PlayerID)
						{
							g_btimes[client] = 0.0;
							Format(g_sBTime[client], 48, "Best: No time");
						}
					}
				}
			}
		}
		
		DB_LoadTimes();
		
		// If the top time was deleted
		if(RecordOne <= 1 <= RecordTwo)
		{			
			// Delete ghost if it's main timer on normal style
			if(Type == TIMER_MAIN && Style == STYLE_NORMAL)
			{
				DeleteGhost();
			}
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

DB_LoadTimes()
{	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT t1.rownum, t1.MapID, t1.Type, t1.Style, t1.PlayerID, t1.Time, t1.Jumps, t1.Strafes, t1.Points, t1.Timestamp, t2.User FROM times AS t1, players AS t2 WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND t1.PlayerID=t2.PlayerID ORDER BY Type, Style, Time",
		g_mapname);
	SQL_TQuery(g_DB, LoadTimes_Callback, query);
}

public LoadTimes_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		for(new i=0; i<3; i++)
		{
			if(g_hTimes[i] != INVALID_HANDLE)
				ClearArray(g_hTimes[i]);
			else
				g_hTimes[i]      = CreateArray(6, 1);
			
			if(g_hTimesUsers[i] != INVALID_HANDLE)
				ClearArray(g_hTimesUsers[i]);
			else
				g_hTimesUsers[i] = CreateArray(ByteCountToCells(MAX_NAME_LENGTH), 0);
		}
		
		if(g_hBTimes != INVALID_HANDLE)
			ClearArray(g_hBTimes);
		else
			g_hBTimes      = CreateArray(6, 1);
		
		if(g_hBTimesUsers != INVALID_HANDLE)
			ClearArray(g_hBTimesUsers);
		else
			g_hBTimesUsers = CreateArray(ByteCountToCells(MAX_NAME_LENGTH), 0);
		
		new rows = SQL_GetRowCount(hndl), Type, Style, iSize, String:sUser[MAX_NAME_LENGTH];
		
		for(new i=0; i<rows; i++)
		{
			SQL_FetchRow(hndl);
			
			Type  = SQL_FetchInt(hndl, eType);
			Style = SQL_FetchInt(hndl, eStyle);
			
			SQL_FetchString(hndl, 10, sUser, sizeof(sUser));
			
			if(Type == TIMER_MAIN)
			{
				iSize = GetArraySize(g_hTimes[Style]);
				
				SetArrayCell(g_hTimes[Style], iSize-1, SQL_FetchInt(hndl, ePlayerID), 0);
				SetArrayCell(g_hTimes[Style], iSize-1, SQL_FetchFloat(hndl, eTime), 1);
				SetArrayCell(g_hTimes[Style], iSize-1, SQL_FetchInt(hndl, eJumps), 2);
				SetArrayCell(g_hTimes[Style], iSize-1, SQL_FetchInt(hndl, eStrafes), 3);
				SetArrayCell(g_hTimes[Style], iSize-1, SQL_FetchFloat(hndl, ePoints), 4);
				SetArrayCell(g_hTimes[Style], iSize-1, SQL_FetchInt(hndl, eTimestamp), 5);
				
				PushArrayString(g_hTimesUsers[Style], sUser);
				
				ResizeArray(g_hTimes[Style], iSize+1);
			}
			else
			{
				iSize = GetArraySize(g_hBTimes);
				
				SetArrayCell(g_hBTimes, iSize-1, SQL_FetchInt(hndl, ePlayerID), 0);
				SetArrayCell(g_hBTimes, iSize-1, SQL_FetchFloat(hndl, eTime), 1);
				SetArrayCell(g_hBTimes, iSize-1, SQL_FetchInt(hndl, eJumps), 2);
				SetArrayCell(g_hBTimes, iSize-1, SQL_FetchInt(hndl, eStrafes), 3);
				SetArrayCell(g_hBTimes, iSize-1, SQL_FetchFloat(hndl, ePoints), 4);
				SetArrayCell(g_hBTimes, iSize-1, SQL_FetchInt(hndl, eTimestamp), 5);
				
				PushArrayString(g_hBTimesUsers, sUser);
				
				ResizeArray(g_hBTimes, iSize+1);
			}
		}
		
		LoadWorldRecordInfo();
	}
	else
	{
		LogError(error);
	}
}

LoadWorldRecordInfo()
{
	new const String:sStyle[3][] = {"", "SW", "W"};
	decl String:sUser[MAX_NAME_LENGTH];
	new iSize;
	for(new i=0; i<3; i++)
	{
		iSize = GetArraySize(g_hTimes[i]);
		if(iSize > 1)
		{
			g_WorldRecord[i] = GetArrayCell(g_hTimes[i], 0, 1);
			
			FormatPlayerTime(g_WorldRecord[i], g_record[i], 48, false, 1);
			GetArrayString(g_hTimesUsers[i], 0, sUser, MAX_NAME_LENGTH);
			
			Format(g_record[i], 48, "WR%s: %s (%s)", sStyle[i], g_record[i], sUser);
		}
		else
		{
			g_WorldRecord[i] = 0.0;
			
			Format(g_record[i], 48, "WR%s: No record", sStyle[i]);
		}
	}
	
	iSize = GetArraySize(g_hBTimes);
	
	if(iSize > 1)
	{
		g_bWorldRecord = GetArrayCell(g_hBTimes, 0, 1);
		
		FormatPlayerTime(g_bWorldRecord, g_brecord, 48, false, 1);
		GetArrayString(g_hBTimesUsers, 0, sUser, MAX_NAME_LENGTH);
		
		Format(g_brecord, 48, "BWR: %s (%s)", g_brecord, sUser);
	}
	else
	{
		g_bWorldRecord = 0.0;
		
		Format(g_brecord, 48, "BWR: No record");
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
	if(IsBeingTimed(client, TIMER_ANY))
	{
		if(IsBeingTimed(client, TIMER_MAIN))
		{
			new bool:infreestylezone = IsInAFreeStyleZone(client);
			if(g_timer_style[client] == STYLE_SIDEWAYS)
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
					if(!(g_buttons[client] & IN_BACK) && (buttons & IN_BACK))
					{
						g_dStrafes[client]++;
						g_dSWStrafes[client][1]++;
					}
					else if(!(g_buttons[client] & IN_FORWARD) && (buttons & IN_FORWARD))
					{
						g_dStrafes[client]++;
						g_dSWStrafes[client][0]++;
					}
				}
			}
			else if(g_timer_style[client] == STYLE_WONLY)
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
		}
		if(g_timer_style[client] == STYLE_NORMAL || IsBeingTimed(client, TIMER_BONUS))
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				if(!(g_buttons[client] & IN_MOVELEFT) && (buttons & IN_MOVELEFT))
					g_dStrafes[client]++;
				else if(!(g_buttons[client] & IN_MOVERIGHT) && (buttons & IN_MOVERIGHT))
					g_dStrafes[client]++;
			}
		}
		
		// Anti-+left/+right
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
		g_buttons[client] = buttons;
		
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
}

PrintHelp(client)
{
	PrintToChat(client, "[SM] Look in your console for help.");
	PrintToConsole(client, "[SM] Usage:\n\
sm_delete        		 - Opens delete menu.\n\
sm_delete record 		 - Deletes a specific record.\n\
sm_delete record1 record2	 - Deletes all times from record1 to record2.");
}