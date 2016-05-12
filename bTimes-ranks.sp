#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "[bTimes] ranks",
	author = "blacky",
	description = "Controls server rankings",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <bTimes-ranks>
#include <bTimes-random>
#include <scp>

#define CC_HASCC 1<<0
#define CC_MSGCOL 1<<1
#define CC_NAME 1<<2

new 	Handle:g_DB;
new	Handle:g_MapList;

new 	g_rank[MAXPLAYERS+1];

new	String:g_msg_start[128],
	String:g_msg_varcol[128],
	String:g_msg_textcol[128];

// Chat ranks
new 	Handle:g_hChatRanksRanges,
	Handle:g_hChatRanksNames;
	
// Custom chat
new	Handle:g_hCustomSteams,
	Handle:g_hCustomNames,
	Handle:g_hCustomMessages,
	Handle:g_hCustomUse,
	bool:g_bClientHasCustom[MAXPLAYERS+1],
	g_ClientUseCustom[MAXPLAYERS+1];
	
new	bool:g_bNewMessage;
	
// Settings
new	Handle:g_hUseCustomChat,
	Handle:g_hUseChatRanks;
	
// Points recalculation
new	g_RecalcTotal,
	g_RecalcProgress;

public OnPluginStart()
{
	// Connect to the database
	DB_Connect();
	
	// Cvars
	g_hUseCustomChat  = CreateConVar("timer_enablecc", "1", "Allows specific players in sourcemod/configs/timer/custom.cfg to use custom chat.", 0, true, 0.0, true, 1.0);
	g_hUseChatRanks   = CreateConVar("timer_chatranks", "1", "Allows players to use chat ranks specified in sourcemod/configs/timer/ranks.cfg", 0, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "ranks", "timer");
	
	// Commands
	RegConsoleCmdEx("sm_rank", SM_Rank, "Shows the overall rank of you or a specified player.");
	RegConsoleCmdEx("sm_rankn", SM_RankN, "Shows the overall normal rank of you or a specified player.");
	RegConsoleCmdEx("sm_ranksw", SM_RankSW, "Shows the overall sideways rank of you or a specified player.");
	RegConsoleCmdEx("sm_rankw", SM_RankW, "Shows the overall w-only rank of you or a specified player.");
	RegConsoleCmdEx("sm_rankstam", SM_RankStam, "Shows the overall stamina rank of you or a specified player.");
	RegConsoleCmdEx("sm_rankhsw", SM_RankHSW, "Shows the overall half-sideways rank of you or a specified player.");
	RegConsoleCmdEx("sm_brank", SM_BRank, "Shows the overall bonus rank of you or a specified player.");
	
	RegConsoleCmdEx("sm_top", SM_Top, "Shows the overall ranks.");
	RegConsoleCmdEx("sm_topn", SM_TopN, "Shows the normal overall ranks.");
	RegConsoleCmdEx("sm_topsw", SM_TopSW, "Shows the sideways overall ranks.");
	RegConsoleCmdEx("sm_topw", SM_TopW, "Shows the w-only overall ranks.");
	RegConsoleCmdEx("sm_topstam", SM_TopStam, "Shows the stamina overall ranks.");
	RegConsoleCmdEx("sm_tophsw", SM_TopHSW, "Shows the half-sideways overall ranks.");
	RegConsoleCmdEx("sm_btop", SM_BTop, "Shows the bonus ranks");
	
	RegConsoleCmdEx("sm_mapsleft", SM_Mapsleft, "Shows your or a specified player's maps left to beat.");
	RegConsoleCmdEx("sm_mapsleftn", SM_MapsleftN, "Shows your or a specified player's maps left to beat on normal.");
	RegConsoleCmdEx("sm_mapsleftsw", SM_MapsleftSW, "Shows your or a specified player's maps left to beat on sideways.");
	RegConsoleCmdEx("sm_mapsleftw", SM_MapsleftW, "Shows your or a specified player's maps left to beat on w-only.");
	RegConsoleCmdEx("sm_mapsleftstam", SM_MapsleftStam, "Shows your or a specified player's maps left to beat on stamina.");
	RegConsoleCmdEx("sm_mapslefthsw", SM_MapsleftHSW, "Shows your or a specified player's maps left to beat on half-sideways.");
	RegConsoleCmdEx("sm_bmapsleft", SM_BMapsleft, "Shows your or a specified player's bonus maps left to beat.");
	
	RegConsoleCmdEx("sm_mapsdone", SM_Mapsdone, "Shows your or a specified player's maps done.");
	RegConsoleCmdEx("sm_mapsdonen", SM_MapsdoneN, "Shows your or a specified player's maps done on normal.");
	RegConsoleCmdEx("sm_mapsdonesw", SM_MapsdoneSW, "Shows your or a specified player's maps done on sideways.");
	RegConsoleCmdEx("sm_mapsdonew", SM_MapsdoneW, "Shows your or a specified player's maps done on w-only.");
	RegConsoleCmdEx("sm_mapsdonestam", SM_MapsdoneStam, "Shows your or a specified player's maps done on stamina.");
	RegConsoleCmdEx("sm_mapsdonehsw", SM_MapsdoneHSW, "Shows your or a specified player's maps done on half-sideways.");
	RegConsoleCmdEx("sm_bmapsdone", SM_BMapsdone, "Shows your or a specified player's bonus maps done.");
	
	RegConsoleCmdEx("sm_stats", SM_Stats, "Shows the stats of you or a specified player.");
	RegConsoleCmdEx("sm_playtime", SM_Playtime, "Shows the people who played the most.");
	
	RegConsoleCmdEx("sm_ccname", SM_ColoredName, "Change colored name.");
	RegConsoleCmdEx("sm_ccmsg", SM_ColoredMsg, "Change the color of your messages.");
	RegConsoleCmdEx("sm_cchelp", SM_Colorhelp, "For help on creating a custom name tag with colors and a color message.");
	
	RegConsoleCmdEx("sm_rankings", SM_Rankings, "Shows the chat ranking tags and the ranks required to get them.");
	RegConsoleCmdEx("sm_ranks", SM_Rankings, "Shows the chat ranking tags and the ranks required to get them.");
	RegConsoleCmdEx("sm_chatranks", SM_Rankings, "Shows the chat ranking tags and the ranks required to get them.");
	
	// Admin commands
	RegAdminCmd("sm_enablecc", SM_EnableCC, ADMFLAG_ROOT, "Enable custom chat for a specified SteamID.");
	RegAdminCmd("sm_disablecc", SM_DisableCC, ADMFLAG_ROOT, "Disable custom chat for a specified SteamID.");
	RegAdminCmd("sm_cclist", SM_CCList, ADMFLAG_CHEATS, "Shows a list of players with custom chat privileges.");
	RegAdminCmd("sm_recalcpts", SM_RecalcPts, ADMFLAG_CHEATS, "Recalculates all the points in the database.");
	
	// Admin
	RegAdminCmd("sm_reloadranks", SM_ReloadRanks, ADMFLAG_CHEATS, "Reloads chat ranks.");
	
	// Chat ranks
	LoadChatRanks();
	
	g_hCustomSteams  	= CreateArray(32);
	g_hCustomNames   	= CreateArray(128);
	g_hCustomMessages	= CreateArray(256);
	g_hCustomUse 	   	= CreateArray();

	// Makes FindTarget() work properly
	LoadTranslations("common.phrases");
	
	// Command listeners
	AddCommandListener(Command_Say, "say");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("DB_UpdateRanks", Native_UpdateRanks);
	
	return APLRes_Success;
}

public OnMapStart()
{	
	g_MapList = ReadMapList();
	
	CreateTimer(1.0, UpdateDeaths, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public OnPlayerIDLoaded(client)
{
	DB_SetClientRank(client);
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

public Action:Command_Say(client, const String:command[], argc)
{
	g_bNewMessage = true;
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	GetChatName(author, name, MAXLENGTH_NAME);
	GetChatMessage(author, message, MAXLENGTH_MESSAGE);
	
	if(g_bNewMessage && GetMessageFlags() & CHATFLAGS_ALL && !IsPlayerAlive(author))
	{
		for(new client = 1; client <= MaxClients; client++)
		{
			if(IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client))
			{
				PushArrayCell(recipients, client);
			}
		}
		g_bNewMessage = false;
	}
	g_bNewMessage = false;
	
	return Plugin_Changed;
}

FormatTag(client, String:buffer[], maxlength)
{
	ReplaceString(buffer, maxlength, "{team}", "\x03", true);
	ReplaceString(buffer, maxlength, "^", "\x07", true);
	
	new rand[3], String:sRandHex[15];
	while(StrContains(buffer, "{rand}", true) != -1)
	{
		for(new i=0; i<3; i++)
			rand[i] = GetRandomInt(0, 255);
		
		FormatEx(sRandHex, sizeof(sRandHex), "\x07%02X%02X%02X", rand[0], rand[1], rand[2]);
		ReplaceStringEx(buffer, maxlength, "{rand}", sRandHex);
	}
	
	ReplaceString(buffer, maxlength, "{norm}", "\x01", true);
	
	if(0 < client <= MaxClients)
	{
		decl String:sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		ReplaceString(buffer, maxlength, "{name}", sName, true);
	}
}

GetChatName(client, String:buffer[], maxlength)
{	
	if(g_bClientHasCustom[client] && (g_ClientUseCustom[client] & CC_NAME) && GetConVarBool(g_hUseCustomChat))
	{
		decl String:sAuth[32];
		GetClientAuthString(client, sAuth, sizeof(sAuth));
		
		new idx;
		if((idx = FindStringInArray(g_hCustomSteams, sAuth)) != -1)
		{
			GetArrayString(g_hCustomNames, idx, buffer, maxlength);
			FormatTag(client, buffer, maxlength);
		}
	}
	else if(GetConVarBool(g_hUseChatRanks))
	{
		new iSize = GetArraySize(g_hChatRanksRanges);
		for(new i=0; i<iSize; i++)
		{
			if(GetArrayCell(g_hChatRanksRanges, i, 0) <= g_rank[client] <= GetArrayCell(g_hChatRanksRanges, i, 1))
			{
				GetArrayString(g_hChatRanksNames, i, buffer, maxlength);
				FormatTag(client, buffer, maxlength);
				return;
			}
		}
	}
}

GetChatMessage(client, String:message[], maxlength)
{
	if(g_bClientHasCustom[client] && (g_ClientUseCustom[client] & CC_MSGCOL) && GetConVarBool(g_hUseCustomChat))
	{
		decl String:sAuth[32];
		GetClientAuthString(client, sAuth, sizeof(sAuth));
		
		new idx;
		if((idx = FindStringInArray(g_hCustomSteams, sAuth)) != -1)
		{
			decl String:buffer[MAXLENGTH_MESSAGE];
			GetArrayString(g_hCustomMessages, idx, buffer, MAXLENGTH_MESSAGE);
			FormatTag(client, buffer, maxlength);
			Format(message, maxlength, "%s%s", buffer, message);
		}
	}
}

public OnClientAuthorized(client, const String:auth[])
{
	new idx;
	if((idx = FindStringInArray(g_hCustomSteams, auth)) != -1)
	{
		g_bClientHasCustom[client] = true;
			
		g_ClientUseCustom[client]  = GetArrayCell(g_hCustomUse, idx);
	}
}

public bool:OnClientConnect(client)
{
	g_bClientHasCustom[client] = false;
	g_ClientUseCustom[client]  = 0;
	
	g_rank[client] = 0;
	
	return true;
}

public Action:SM_RecalcPts(client, args)
{
	new	Handle:menu = CreateMenu(Menu_RecalcPts);
	
	SetMenuTitle(menu, "Recalculating the points takes a while.\nAre you sure you want to do this?");
	
	AddMenuItem(menu, "y", "Yes");
	AddMenuItem(menu, "n", "No");
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Menu_RecalcPts(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[16];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(info[0] == 'y')
		{
			RecalcPoints(param1);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

RecalcPoints(client)
{
	PrintColorTextAll("%s%sRecalculating the ranks, see console for progress.",
		g_msg_start,
		g_msg_textcol);
	
	decl	String:query[128];
	FormatEx(query, sizeof(query), "SELECT MapName, MapID FROM maps");
	
	SQL_TQuery(g_DB, RecalcPoints_Callback, query, client);
}

public RecalcPoints_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new  rows = SQL_GetRowCount(hndl);
		decl String:sMapName[64], String:query[128];
		
		g_RecalcTotal    = rows * 4;
		g_RecalcProgress = 0;
		
		for(new i=0; i<rows; i++)
		{
			SQL_FetchRow(hndl);
			
			SQL_FetchString(hndl, 0, sMapName, sizeof(sMapName));
			
			if(FindStringInArray(g_MapList, sMapName) != -1)
			{
				UpdateRanks(sMapName, TIMER_MAIN, STYLE_NORMAL, true);
				UpdateRanks(sMapName, TIMER_MAIN, STYLE_SIDEWAYS, true);
				UpdateRanks(sMapName, TIMER_MAIN, STYLE_WONLY, true);
				UpdateRanks(sMapName, TIMER_BONUS, STYLE_NORMAL, true);
			}
			else
			{
				FormatEx(query, sizeof(query), "UPDATE times SET Points = 0 WHERE MapID = %d",
					SQL_FetchInt(hndl, 1));
					
				new	Handle:pack = CreateDataPack();
				WritePackString(pack, sMapName);
					
				SQL_TQuery(g_DB, RecalcPoints_Callback2, query, pack);
			}
		}
	}
	else
	{
		LogError(error);
	}
}

public RecalcPoints_Callback2(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		
		decl String:sMapName[64];
		ReadPackString(data, sMapName, sizeof(sMapName));
		
		g_RecalcProgress += 4;
		
		for(new client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client))
			{
				if(!IsFakeClient(client))
				{
					PrintToConsole(client, "[%.1f%%] %s's points deleted.",
						float(g_RecalcProgress)/float(g_RecalcTotal) * 100.0,
						sMapName);
				}
			}
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

public Action:SM_Rank(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		if(args == 0)
		{
			DB_ShowRank(client, client, ALL, ALL);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowRank(client, target, ALL, ALL);
		}
	}
	return Plugin_Handled;
}

public Action:SM_RankN(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		if(args == 0)
		{
			DB_ShowRank(client, client, TIMER_MAIN, STYLE_NORMAL);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowRank(client, target, TIMER_MAIN, STYLE_NORMAL);
		}
	}
	return Plugin_Handled;
}

public Action:SM_RankSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowRank(client, client, TIMER_MAIN, STYLE_SIDEWAYS);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowRank(client, target, TIMER_MAIN, STYLE_SIDEWAYS);
		}
	}
	return Plugin_Handled;
}

public Action:SM_RankW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowRank(client, client, TIMER_MAIN, STYLE_WONLY);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowRank(client, target, TIMER_MAIN, STYLE_WONLY);
		}
	}	
	return Plugin_Handled;
}

public Action:SM_RankStam(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowRank(client, client, TIMER_MAIN, STYLE_STAMINA);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowRank(client, target, TIMER_MAIN, STYLE_STAMINA);
		}
	}	
	return Plugin_Handled;
}

public Action:SM_RankHSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowRank(client, client, TIMER_MAIN, STYLE_HALFSIDEWAYS);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowRank(client, target, TIMER_MAIN, STYLE_HALFSIDEWAYS);
		}
	}	
	return Plugin_Handled;
}

public Action:SM_BRank(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowRank(client, client, TIMER_BONUS, STYLE_NORMAL);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowRank(client, target, TIMER_BONUS, STYLE_NORMAL);
		}
	}
	return Plugin_Handled;
}

public Action:SM_Top(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		DB_ShowTopAll(client);
	}
	return Plugin_Handled;
}

public Action:SM_TopN(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		DB_ShowTopAllSpec(client, TIMER_MAIN, STYLE_NORMAL);
	}
	return Plugin_Handled;
}

public Action:SM_TopSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		DB_ShowTopAllSpec(client, TIMER_MAIN, STYLE_SIDEWAYS);
	}
	return Plugin_Handled;
}

public Action:SM_TopW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		DB_ShowTopAllSpec(client, TIMER_MAIN, STYLE_WONLY);
	}
	return Plugin_Handled;
}

public Action:SM_TopStam(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		DB_ShowTopAllSpec(client, TIMER_MAIN, STYLE_STAMINA);
	}
	return Plugin_Handled;
}

public Action:SM_TopHSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		DB_ShowTopAllSpec(client, TIMER_MAIN, STYLE_HALFSIDEWAYS);
	}
	return Plugin_Handled;
}

public Action:SM_BTop(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		DB_ShowTopAllSpec(client, TIMER_BONUS, STYLE_NORMAL);
	}
	return Plugin_Handled;
}

public Action:SM_Mapsleft(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsleft(client, client, ALL, ALL);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsleft(client, target, ALL, ALL);
		}
	}
	return Plugin_Handled;
}

public Action:SM_MapsleftN(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsleft(client, client, TIMER_MAIN, STYLE_NORMAL);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsleft(client, target, TIMER_MAIN, STYLE_NORMAL);
		}
	}
	return Plugin_Handled;
}

public Action:SM_MapsleftSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsleft(client, client, TIMER_MAIN, STYLE_SIDEWAYS);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsleft(client, target, TIMER_MAIN, STYLE_SIDEWAYS);
		}
	}
	return Plugin_Handled;
}

public Action:SM_MapsleftW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsleft(client, client, TIMER_MAIN, STYLE_WONLY);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsleft(client, target, TIMER_MAIN, STYLE_WONLY);
		}
	}
	return Plugin_Handled;
}

public Action:SM_MapsleftStam(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsleft(client, client, TIMER_MAIN, STYLE_STAMINA);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsleft(client, target, TIMER_MAIN, STYLE_STAMINA);
		}
	}
	return Plugin_Handled;
}

public Action:SM_MapsleftHSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsleft(client, client, TIMER_MAIN, STYLE_HALFSIDEWAYS);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsleft(client, target, TIMER_MAIN, STYLE_HALFSIDEWAYS);
		}
	}
	return Plugin_Handled;
}

public Action:SM_BMapsleft(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsleft(client, client, TIMER_BONUS, ALL);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsleft(client, target, TIMER_BONUS, ALL);
		}
	}
	return Plugin_Handled;
}

public Action:SM_Mapsdone(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsdone(client, client, ALL, ALL);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsdone(client, target, ALL, ALL);
		}
	}
	return Plugin_Handled;
}

public Action:SM_MapsdoneN(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsdone(client, client, TIMER_MAIN, STYLE_NORMAL);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsdone(client, target, TIMER_MAIN, STYLE_NORMAL);
		}
	}
	return Plugin_Handled;
}

public Action:SM_MapsdoneSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsdone(client, client, TIMER_MAIN, STYLE_SIDEWAYS);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsdone(client, target, TIMER_MAIN, STYLE_SIDEWAYS);
		}
	}
	return Plugin_Handled;
}

public Action:SM_MapsdoneW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsdone(client, client, TIMER_MAIN, STYLE_WONLY);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsdone(client, target, TIMER_MAIN, STYLE_WONLY);
		}
	}
	return Plugin_Handled;
}

public Action:SM_MapsdoneStam(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsdone(client, client, TIMER_MAIN, STYLE_STAMINA);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsdone(client, target, TIMER_MAIN, STYLE_STAMINA);
		}
	}
	return Plugin_Handled;
}

public Action:SM_MapsdoneHSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsdone(client, client, TIMER_MAIN, STYLE_HALFSIDEWAYS);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsdone(client, target, TIMER_MAIN, STYLE_HALFSIDEWAYS);
		}
	}
	return Plugin_Handled;
}

public Action:SM_BMapsdone(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowMapsdone(client, client, TIMER_BONUS, ALL);
		}
		else
		{
			decl String:targetName[128];
			GetCmdArgString(targetName, sizeof(targetName));
			new target = FindTarget(client, targetName, true, false);
			if(target != -1)
				DB_ShowMapsdone(client, target, TIMER_BONUS, ALL);
		}
	}
	return Plugin_Handled;
}

public Action:SM_Playtime(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			DB_ShowPlaytime(client, client);
		}
		else
		{
			decl String:arg[250];
			GetCmdArgString(arg, sizeof(arg));
			
			new target = FindTarget(client, arg, true, false);
			if(target != -1)
			{
				DB_ShowPlaytime(client, target);
			}
		}
	}
	return Plugin_Handled;
}

public Action:SM_ColoredName(client, args)
{	
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(g_bClientHasCustom[client])
		{
			decl String:query[512], String:sAuth[32];
			GetClientAuthString(client, sAuth, sizeof(sAuth));
			
			if(args == 0)
			{
				// Get new ccname setting
				g_ClientUseCustom[client] ^= CC_NAME;
				
				// Acknowledge change to client
				if(g_ClientUseCustom[client] & CC_NAME)
				{
					PrintColorText(client, "%s%sColored name enabled.",
						g_msg_start,
						g_msg_textcol);
				}
				else
				{
					PrintColorText(client, "%s%sColored name disabled.",
						g_msg_start,
						g_msg_textcol);
				}
				
				// Set the new ccname setting
				new idx = FindStringInArray(g_hCustomSteams, sAuth);
				
				if(idx != -1)
					SetArrayCell(g_hCustomUse, idx, g_ClientUseCustom[client]);
				
				// Format the query
				FormatEx(query, sizeof(query), "UPDATE players SET ccuse=%d WHERE SteamID='%s'",
					g_ClientUseCustom[client],
					sAuth);
			}
			else
			{
				// Get new ccname
				decl String:sArg[250];
				GetCmdArgString(sArg, sizeof(sArg));
				decl String:sEscapeArg[(strlen(sArg)*2)+1];
				
				// Escape the ccname for SQL insertion
				SQL_LockDatabase(g_DB);
				SQL_EscapeString(g_DB, sArg, sEscapeArg, (strlen(sArg)*2)+1);
				SQL_UnlockDatabase(g_DB);
				
				// Modify player's ccname
				new idx = FindStringInArray(g_hCustomSteams, sAuth);
				
				if(idx != -1)
					SetArrayString(g_hCustomNames, idx, sEscapeArg);
				
				// Prepare query
				FormatEx(query, sizeof(query), "UPDATE players SET ccname='%s' WHERE SteamID='%s'",
					sEscapeArg,
					sAuth);
					
				PrintColorText(client, "%s%sColored name set to %s%s",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sArg);
			}
			
			// Execute query
			SQL_TQuery(g_DB, ColoredName_Callback, query);
		}
	}
	return Plugin_Handled;
}

public ColoredName_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

public Action:SM_ColoredMsg(client, args)
{	
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		if(g_bClientHasCustom[client])
		{
			decl String:query[512], String:sAuth[32];
			GetClientAuthString(client, sAuth, sizeof(sAuth));
			
			if(args == 0)
			{
				g_ClientUseCustom[client] ^= CC_MSGCOL;
				
				new idx = FindStringInArray(g_hCustomSteams, sAuth);
				
				if(idx != -1)
					SetArrayCell(g_hCustomUse, idx, g_ClientUseCustom[client]);
				
				FormatEx(query, sizeof(query), "UPDATE players SET ccuse=%d WHERE SteamID='%s'",
					g_ClientUseCustom[client],
					sAuth);
					
				if(g_ClientUseCustom[client] & CC_MSGCOL)
					PrintColorText(client, "%s%sColored message enabled.",
						g_msg_start,
						g_msg_textcol);
				else
					PrintColorText(client, "%s%sColored message disabled.",
						g_msg_start,
						g_msg_textcol);
			}
			else
			{
				decl String:sArg[128];
				GetCmdArgString(sArg, sizeof(sArg));
				decl String:sEscapeArg[(strlen(sArg)*2)+1];
				
				SQL_LockDatabase(g_DB);
				SQL_EscapeString(g_DB, sArg, sEscapeArg, (strlen(sArg)*2)+1);
				SQL_UnlockDatabase(g_DB);
					
				new idx = FindStringInArray(g_hCustomSteams, sAuth);
				
				if(idx != -1)
					SetArrayString(g_hCustomMessages, idx, sEscapeArg);
				
				FormatEx(query, sizeof(query), "UPDATE players SET ccmsgcol='%s' WHERE SteamID='%s'",
					sEscapeArg,
					sAuth);
					
				PrintColorText(client, "%s%sColored message set to %s%s",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sArg);
			}
			
			// Execute query
			SQL_TQuery(g_DB, ColoredName_Callback, query);
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Colorhelp(client, args)
{
	if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
	{
		PrintColorText(client, "%s%sLook in console for help with custom color chat.",
			g_msg_start,
			g_msg_textcol);
	}
	
	PrintToConsole(client, "\nsm_ccname <arg> to set your name.");
	PrintToConsole(client, "sm_ccname without an argument to turn colored name off.\n");
	
	PrintToConsole(client, "sm_ccmsg <arg> to set your message.");
	PrintToConsole(client, "sm_ccmsg without an argument to turn colored message off.\n");
	
	PrintToConsole(client, "Custom chat functions:");
	PrintToConsole(client, "'^' followed by a hexadecimal code to use any custom color.");
	PrintToConsole(client, "{name} will be replaced with your steam name.");
	PrintToConsole(client, "{team} will be replaced with your team color.");
	PrintToConsole(client, "{rand} will be replaced with a random color.");
	PrintToConsole(client, "{norm} will be replaced with normal chat-yellow color.\n");
	
	return Plugin_Handled;
}

public Action:SM_ReloadRanks(client, args)
{
	LoadChatRanks();
	
	PrintColorText(client, "%s%sChat ranks reloaded.",
		g_msg_start,
		g_msg_textcol);
	
	return Plugin_Handled;
}

public Action:SM_Stats(client, args)
{
	
}

public Action:SM_EnableCC(client, args)
{
	decl String:sArg[256];
	GetCmdArgString(sArg, sizeof(sArg));
	
	if(StrContains(sArg, "STEAM_0:") != -1)
	{
		decl String:query[256];
		FormatEx(query, sizeof(query), "SELECT User, ccuse FROM players WHERE SteamID='%s'",
			sArg);
			
		new	Handle:pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackString(pack, sArg);
			
		SQL_TQuery(g_DB, EnableCC_Callback1, query, pack);
	}
	else
	{
		PrintColorText(client, "%s%ssm_enablecc example: \"sm_enablecc STEAM_0:1:12345\"",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public EnableCC_Callback1(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(pack);
		new client = ReadPackCell(pack);
		
		decl String:sAuth[32];
		ReadPackString(pack, sAuth, sizeof(sAuth));
		
		if(SQL_GetRowCount(hndl) > 0)
		{
			SQL_FetchRow(hndl);
			
			decl String:sName[MAX_NAME_LENGTH];
			SQL_FetchString(hndl, 0, sName, sizeof(sName));
			
			new ccuse = SQL_FetchInt(hndl, 1);
			
			if(!(ccuse & CC_HASCC))
			{
				PrintColorText(client, "%s%sA player with the name '%s%s%s' <%s%s%s> will be given custom chat privileges.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sName,
					g_msg_textcol,
					g_msg_varcol,
					sAuth,
					g_msg_textcol);
				
				EnableCustomChat(sAuth);
			}
			else
			{
				PrintColorText(client, "%s%sA player with the given SteamID '%s%s%s' (name '%s%s%s') already has custom chat privileges.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sAuth,
					g_msg_textcol,
					g_msg_varcol,
					sName,
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(client, "%s%sNo player in the database found with '%s%s%s' as their SteamID.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				sAuth,
				g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(pack);
}

EnableCustomChat(const String:sAuth[])
{
	// Check and enable cc for any clients in the game
	decl String:sAuth2[32];
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			GetClientAuthString(i, sAuth2, sizeof(sAuth2));
			if(StrEqual(sAuth, sAuth2))
			{
				g_bClientHasCustom[i] = true;
				g_ClientUseCustom[i]  = CC_HASCC|CC_MSGCOL|CC_NAME;
				
				PrintColorText(i, "%s%sYou have been given custom chat privileges. Type sm_cchelp or ask for help to learn how to use it.",
					g_msg_start,
					g_msg_textcol);
					
				break;
			}
		}
	}
	
	decl String:query[512];
	FormatEx(query, sizeof(query), "UPDATE players SET ccuse=%d, ccname='{rand}{name}', ccmsgcol='^FFFFFF' WHERE SteamID='%s'",
		CC_HASCC|CC_MSGCOL|CC_NAME,
		sAuth);
	SQL_TQuery(g_DB, EnableCC_Callback, query);
	
	PushArrayString(g_hCustomSteams, sAuth);
	PushArrayString(g_hCustomNames, "{rand}{name}");
	PushArrayString(g_hCustomMessages, "^FFFFFF");
	PushArrayCell(g_hCustomUse, CC_HASCC|CC_MSGCOL|CC_NAME);
}

public EnableCC_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

public Action:SM_DisableCC(client, args)
{
	decl String:sArg[256];
	GetCmdArgString(sArg, sizeof(sArg));
	
	if(StrContains(sArg, "STEAM_0:") != -1)
	{
		decl String:query[256];
		FormatEx(query, sizeof(query), "SELECT User, ccuse FROM players WHERE SteamID='%s'",
			sArg);
			
		new	Handle:pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackString(pack, sArg);
			
		SQL_TQuery(g_DB, DisableCC_Callback1, query, pack);
	}
	else
	{
		PrintColorText(client, "%s%ssm_disablecc example: \"sm_disablecc STEAM_0:1:12345\"",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public DisableCC_Callback1(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(pack);
		new client = ReadPackCell(pack);
		
		decl String:sAuth[32];
		ReadPackString(pack, sAuth, sizeof(sAuth));
		
		if(SQL_GetRowCount(hndl) > 0)
		{
			SQL_FetchRow(hndl);
			
			decl String:sName[MAX_NAME_LENGTH];
			SQL_FetchString(hndl, 0, sName, sizeof(sName));
			
			new ccuse = SQL_FetchInt(hndl, 1);
			
			if(ccuse & CC_HASCC)
			{
				PrintColorText(client, "%s%sA player with the name '%s%s%s' <%s%s%s> will have their custom chat privileges removed.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sName,
					g_msg_textcol,
					g_msg_varcol,
					sAuth,
					g_msg_textcol);
				
				DisableCustomChat(sAuth);
			}
			else
			{
				PrintColorText(client, "%s%sA player with the given SteamID '%s%s%s' (name '%s%s%s') doesn't have custom chat privileges to remove.",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					sAuth,
					g_msg_textcol,
					g_msg_varcol,
					sName,
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(client, "%s%sNo player in the database found with '%s%s%s' as their SteamID.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				sAuth,
				g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
}

DisableCustomChat(const String:sAuth[])
{
	new idx = FindStringInArray(g_hCustomSteams, sAuth);	
	if(idx != -1)
	{
		RemoveFromArray(g_hCustomSteams, idx);
		RemoveFromArray(g_hCustomNames, idx);
		RemoveFromArray(g_hCustomMessages, idx);
		RemoveFromArray(g_hCustomUse, idx);
	}
	
	// Check and disable cc for any clients in the game
	decl String:sAuth2[32];
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			GetClientAuthString(i, sAuth2, sizeof(sAuth2));
			if(StrEqual(sAuth, sAuth2))
			{
				g_bClientHasCustom[i] = false;
				g_ClientUseCustom[i]  = 0;
				
				PrintColorText(i, "%s%sYou have lost your custom chat privileges.",
					g_msg_start,
					g_msg_textcol);
			}
		}
	}
	
	decl String:query[512];
	FormatEx(query, sizeof(query), "UPDATE players SET ccuse=0 WHERE SteamID='%s'",
		sAuth);
	SQL_TQuery(g_DB, EnableCC_Callback, query);
}

public DisableCC_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

public Action:SM_CCList(client, args)
{
	decl String:query[512];
	FormatEx(query, sizeof(query), "SELECT SteamID, User, ccname, ccmsgcol, ccuse FROM players WHERE ccuse != 0");
	SQL_TQuery(g_DB, CCList_Callback, query, client);
	
	return Plugin_Handled;
}

public CCList_Callback(Handle:owner, Handle:hndl, String:error[], any:client)
{
	if(hndl != INVALID_HANDLE)
	{
		new Handle:menu = CreateMenu(Menu_CCList);
		SetMenuTitle(menu, "Players with custom chat privileges");
		
		decl String:sAuth[32], String:sName[MAX_NAME_LENGTH], String:sCCName[128], String:sCCMsg[256], String:info[512], String:display[70], ccuse;
		new rows = SQL_GetRowCount(hndl);
		for(new i=0; i<rows; i++)
		{
			SQL_FetchRow(hndl);
			
			SQL_FetchString(hndl, 0, sAuth, sizeof(sAuth));
			SQL_FetchString(hndl, 1, sName, sizeof(sName));
			SQL_FetchString(hndl, 2, sCCName, sizeof(sCCName));
			SQL_FetchString(hndl, 3, sCCMsg, sizeof(sCCMsg));
			ccuse = SQL_FetchInt(hndl, 4);
			
			FormatEx(info, sizeof(info), "%s%%%s%%%s%%%s%%%d",
				sAuth, 
				sName,
				sCCName,
				sCCMsg,
				ccuse);
				
			FormatEx(display, sizeof(display), "<%s> - %s",
				sAuth,
				sName);
				
			AddMenuItem(menu, info, display);
		}
		
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
		
	}
	else
	{
		LogError(error);
	}
}

public Menu_CCList(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[512];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		decl String:expInfo[5][256];
		ExplodeString(info, "\%", expInfo, 5, 256);
		ReplaceString(expInfo[2], 256, "{name}", expInfo[1]);
		ReplaceString(expInfo[2], 256, "{team}", "\x03");
		ReplaceString(expInfo[2], 256, "^", "\x07");

		ReplaceString(expInfo[3], 256, "^", "\x07");
		
		PrintColorText(param1, "%sSteamID          : %s%s", g_msg_textcol, g_msg_varcol, expInfo[0]);
		PrintColorText(param1, "%sName               : %s%s", g_msg_textcol, g_msg_varcol, expInfo[1]);
		PrintColorText(param1, "%sCCName          : %s%s", g_msg_textcol, g_msg_varcol, expInfo[2]);
		PrintColorText(param1, "%sCCMessage      : %s%sExample text", g_msg_textcol, g_msg_varcol, expInfo[3]);
		
		new ccuse = StringToInt(expInfo[4]);
		PrintColorText(param1, "%sUses CC Name: %s%s", g_msg_textcol, g_msg_varcol, (ccuse & CC_NAME)?"Yes":"No");
		PrintColorText(param1, "%sUses CC Msg   : %s%s", g_msg_textcol, g_msg_varcol, (ccuse & CC_MSGCOL)?"Yes":"No");
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_Rankings(client, args)
{
	new iSize = GetArraySize(g_hChatRanksNames);
	
	decl String:sChatRank[MAXLENGTH_NAME];
	
	for(new i=0; i<iSize-1; i++)
	{
		GetArrayString(g_hChatRanksNames, i, sChatRank, MAXLENGTH_NAME);
		FormatTag(client, sChatRank, MAXLENGTH_NAME);
		
		PrintColorText(client, "%s%5d %s-%s %5d%s: %s",
			g_msg_varcol,
			GetArrayCell(g_hChatRanksRanges, i, 0),
			g_msg_textcol,
			g_msg_varcol,
			GetArrayCell(g_hChatRanksRanges, i, 1),
			g_msg_textcol,
			sChatRank);
	}
	
	return Plugin_Handled;
}

public Action:UpdateDeaths(Handle:timer, any:data)
{
	for(new client=1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(IsPlayerAlive(client))
			{
				if(IsFakeClient(client))
				{
					SetEntProp(client, Prop_Data, "m_iDeaths", 0);
				}
				else
				{
					SetEntProp(client, Prop_Data, "m_iDeaths", g_rank[client]);
				}
			}
		}
	}
}

LoadChatRanks()
{
	// Check if timer config path exists
	decl String:sPath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer");
	if(!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}
	
	// If it doesn't exist, create a default ranks config
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/ranks.cfg");
	if(!FileExists(sPath))
	{
		new Handle:hFile = OpenFile(sPath, "w");
		WriteFileLine(hFile, "//\"Range\"     \"Tag/Name\"");
		WriteFileLine(hFile, "\"0-0\"     \"[Unranked] {name}\"");
		WriteFileLine(hFile, "\"1-1\"     \"[Master] {name}\"");
		WriteFileLine(hFile, "\"2-2\"     \"[Champion] {name}\"");
		CloseHandle(hFile);
	}
	
	// init chat ranks
	g_hChatRanksRanges = CreateArray(2, 1);
	g_hChatRanksNames  = CreateArray(128, 1);
	
	// Read file lines and get chat ranks and ranges out of them
	new String:line[PLATFORM_MAX_PATH], String:oldLine[PLATFORM_MAX_PATH], String:sRange[PLATFORM_MAX_PATH], String:sName[PLATFORM_MAX_PATH], String:expRange[2][128];
	new idx, iSize = 1;
	
	new Handle:hFile = OpenFile(sPath, "r");
	while(!IsEndOfFile(hFile))
	{
		ReadFileLine(hFile, line, sizeof(line));
		ReplaceString(line, sizeof(line), "\n", "");
		if(line[0] != '/' && line[1] != '/' && strlen(line) > 2)
		{
			if(!StrEqual(line, oldLine))
			{
				idx = BreakString(line, sRange, sizeof(sRange));
				BreakString(line[idx], sName, sizeof(sName));
				ExplodeString(sRange, "-", expRange, 2, 128);
				
				SetArrayCell(g_hChatRanksRanges, iSize-1, StringToInt(expRange[0]), 0);
				SetArrayCell(g_hChatRanksRanges, iSize-1, StringToInt(expRange[1]), 1);
				SetArrayString(g_hChatRanksNames, iSize-1, sName);
				
				ResizeArray(g_hChatRanksRanges, iSize+1);
				ResizeArray(g_hChatRanksNames, iSize+1);
				
				iSize++;
			}
		}
		Format(oldLine, sizeof(oldLine), line);
	}
	
	CloseHandle(hFile);
}

LoadCustomChat()
{	
	decl String:query[512];
	FormatEx(query, sizeof(query), "SELECT SteamID, ccname, ccmsgcol, ccuse FROM players WHERE ccuse != 0");
	SQL_TQuery(g_DB, LoadCustomChat_Callback, query);
}

public LoadCustomChat_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		// Init adt_arrays
		g_hCustomSteams   = CreateArray(32);
		g_hCustomNames    = CreateArray(128);
		g_hCustomMessages = CreateArray(256);
		g_hCustomUse 	  = CreateArray();
		
		decl String:sAuth[32], String:sName[128], String:sMsg[256];
		new rows = SQL_GetRowCount(hndl);
		
		for(new i=0; i<rows; i++)
		{
			SQL_FetchRow(hndl);
			
			SQL_FetchString(hndl, 0, sAuth, sizeof(sAuth));
			SQL_FetchString(hndl, 1, sName, sizeof(sName));
			SQL_FetchString(hndl, 2, sMsg, sizeof(sMsg));
			
			PushArrayString(g_hCustomSteams, sAuth);
			PushArrayString(g_hCustomNames, sName);
			PushArrayString(g_hCustomMessages, sMsg);
			PushArrayCell(g_hCustomUse, SQL_FetchInt(hndl, 3));
		}
	}
	else
	{
		LogError(error);
	}
}

DB_ShowRank(client, target, Type, Style)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, target);
	
	new PlayerID = GetPlayerID(target);
	
	decl String:query[512];
	if(Type == ALL && Style == ALL)
		FormatEx(query, sizeof(query), "SELECT (SELECT count(*) AS Rank FROM (SELECT SUM(Points) AS Points FROM times GROUP BY PlayerID ORDER BY SUM(Points)) AS t1 WHERE Points>=(SELECT SUM(Points) FROM times WHERE PlayerID=%d)) AS Rank, (SELECT count(*) FROM (SELECT PlayerID FROM times GROUP BY PlayerID) x) AS Total, SUM(Points) AS Points FROM times WHERE PlayerID=%d",
			PlayerID,
			PlayerID);
	else
		FormatEx(query, sizeof(query), "SELECT (SELECT count(*) AS Rank FROM (SELECT SUM(Points) AS Points FROM times WHERE Type=%d AND Style=%d GROUP BY PlayerID ORDER BY SUM(Points)) AS t1 WHERE Points>=(SELECT SUM(Points) FROM times WHERE Type=%d AND Style=%d AND PlayerID=%d)) AS Rank, (SELECT count(*) FROM (SELECT PlayerID FROM times WHERE Type=%d AND Style=%d GROUP BY PlayerID) x) AS Total, SUM(Points) AS Points FROM times WHERE Type=%d AND Style=%d AND PlayerID=%d",
			Type,
			Style,
			Type,
			Style,
			PlayerID,
			Type,
			Style,
			Type,
			Style,
			PlayerID);
		
	SQL_TQuery(g_DB, DB_ShowRank_Callback, query, pack);
}

public DB_ShowRank_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client = ReadPackCell(data);
		new target = ReadPackCell(data);
		
		decl String:sTarget[MAX_NAME_LENGTH];
		GetClientName(target, sTarget, sizeof(sTarget));
		
		SQL_FetchRow(hndl);
		
		if(SQL_FetchInt(hndl, 0) != 0)
		{
			new Rank         = SQL_FetchInt(hndl, 0);
			new Total        = SQL_FetchInt(hndl, 1);
			new Float:Points = SQL_FetchFloat(hndl, 2);
			
			PrintColorText(client, "%s%s%s%s is ranked %s%d%s of %s%d%s players with %s%.1f%s points.",
				g_msg_start,
				g_msg_varcol,
				sTarget,
				g_msg_textcol,
				g_msg_varcol,
				Rank,
				g_msg_textcol,
				g_msg_varcol,
				Total,
				g_msg_textcol,
				g_msg_varcol,
				Points,
				g_msg_textcol);
		}
		else
		{
			PrintColorText(client, "%s%s%s%s is not ranked yet.",
				g_msg_start,
				g_msg_varcol,
				sTarget,
				g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

DB_ShowTopAll(client)
{
	decl String:query[256];
	Format(query, sizeof(query), "SELECT t1.User, SUM(t2.Points) FROM players AS t1, times AS t2 WHERE t1.PlayerID=t2.PlayerID GROUP BY t2.PlayerID ORDER BY SUM(t2.Points) DESC LIMIT 0, 100");
	SQL_TQuery(g_DB, DB_ShowTopAll_Callback, query, client);
}

public DB_ShowTopAll_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new String:name[MAX_NAME_LENGTH], String:item[128], Float:points;
		new rows = SQL_GetRowCount(hndl);
		new Handle:menu = CreateMenu(Menu_ShowTopAll);
		SetMenuTitle(menu, "TOP 100 Players\n------------------------------------");
		for(new itemnum=1; itemnum<=rows; itemnum++)
		{
			SQL_FetchRow(hndl);
			SQL_FetchString(hndl, 0, name, sizeof(name));
			points = SQL_FetchFloat(hndl, 1);
			Format(item, sizeof(item), "#%d: %s - %6.3f", itemnum, name, points);
			
			if((itemnum % 7 == 0) || (itemnum == rows))
				Format(item, sizeof(item), "%s\n------------------------------------", item);
			
			AddMenuItem(menu, item, item);
		}
		
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, data, MENU_TIME_FOREVER);
	}
	else
	{
		LogError(error);
	}
}

public Menu_ShowTopAll(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_End)
		CloseHandle(menu);
}

DB_ShowTopAllSpec(client, Type, Style)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, Type);
	WritePackCell(pack, Style);
	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT t1.User, SUM(t2.Points) FROM players AS t1, times AS t2 WHERE t1.PlayerID=t2.PlayerID AND t2.Type=%d AND t2.Style=%d GROUP BY t2.PlayerID ORDER BY SUM(t2.Points) DESC LIMIT 0, 100",
		Type,
		Style);
	SQL_TQuery(g_DB, DB_ShowTopAllSpec_Callback, query, pack);
}

public DB_ShowTopAllSpec_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client	= ReadPackCell(data);
		new Type	= ReadPackCell(data);
		new Style 	= ReadPackCell(data);
		
		new Handle:menu   = CreateMenu(Menu_ShowTopAllSpec);
		
		decl String:sType[16];
		GetTypeName(Type, sType, sizeof(sType));
		Format(sType, sizeof(sType), "%s timer - ", sType);
		
		decl String:sStyle[16];
		GetStyleName(Style, sStyle, sizeof(sStyle));
		AddBracketsToString(sStyle, sizeof(sStyle));
		
		decl String:sTitle[128];
		Format(sTitle, sizeof(sTitle), "%sTOP 100 %s\n------------------------------------",
			sType,
			sStyle);
		SetMenuTitle(menu, sTitle);
		
		new rows = SQL_GetRowCount(hndl), String:sName[MAX_NAME_LENGTH], String:item[128], Float:points;
		for(new itemnum=1; itemnum<=rows; itemnum++)
		{
			SQL_FetchRow(hndl);
			SQL_FetchString(hndl, 0, sName, sizeof(sName));
			points = SQL_FetchFloat(hndl, 1);
			FormatEx(item, sizeof(item), "#%d: %s - %6.2f", itemnum, sName, points);
			
			if((itemnum % 7 == 0) || (itemnum == rows))
				Format(item, sizeof(item), "%s\n------------------------------------", item);
			AddMenuItem(menu, item, item);
		}
		
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
	{
		LogError(error);
	}
	CloseHandle(data);
}

public Menu_ShowTopAllSpec(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
}

DB_ShowMapsleft(client, target, Type, Style)
{
	if(GetPlayerID(target) != 0)
	{
		new Handle:pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackCell(pack, target);
		WritePackCell(pack, Type);
		WritePackCell(pack, Style);
		
		decl String:query[512];
		if(Type == ALL && Style == ALL)
			Format(query, sizeof(query), "SELECT t2.MapName FROM (SELECT maps.MapID AS MapID1, t1.MapID AS MapID2 FROM maps LEFT JOIN (SELECT MapID FROM times WHERE PlayerID=%d) t1 ON maps.MapID=t1.MapID) AS t1, maps AS t2 WHERE t1.MapID1=t2.MapID AND t1.MapID2 IS NULL ORDER BY t2.MapName",
				GetPlayerID(target));
		else
			Format(query, sizeof(query), "SELECT t2.MapName FROM (SELECT maps.MapID AS MapID1, t1.MapID AS MapID2 FROM maps LEFT JOIN (SELECT MapID FROM times WHERE Type=%d AND Style=%d AND PlayerID=%d) t1 ON maps.MapID=t1.MapID) AS t1, maps AS t2 WHERE t1.MapID1=t2.MapID AND t1.MapID2 IS NULL ORDER BY t2.MapName",
				Type,
				Style,
				GetPlayerID(target));
		SQL_TQuery(g_DB, DB_ShowMapsLeft_Callback, query, pack);
	}
	else
	{
		if(client == target)
		{
			PrintColorText(client, "%s%sYour SteamID is not authorized. Steam servers may be down. If not, try reconnecting.",
				g_msg_start,
				g_msg_textcol);
		}
		else
		{
			decl String:name[MAX_NAME_LENGTH];
			GetClientName(target, name, sizeof(name));
			
			PrintColorText(client, "%s%s%s's %sSteamID is not authorized. Steam servers may be down.", 
				g_msg_start,
				g_msg_varcol,
				name,
				g_msg_textcol);
		}
	}
}

public DB_ShowMapsLeft_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client	= ReadPackCell(data);
		new target	= ReadPackCell(data);
		new Type		= ReadPackCell(data);
		new Style 	= ReadPackCell(data);
		
		new rows = SQL_GetRowCount(hndl), count;
		new String:mapname[128];
		new Handle:menu = CreateMenu(Menu_ShowMapsleft);
		
		decl String:sType[16];
		if(Type != ALL)
		{
			GetTypeName(Type, sType, sizeof(sType));
			StringToUpper(sType);
			AddBracketsToString(sType, sizeof(sType));
			AddSpaceToEnd(sType, sizeof(sType));
		}
		
		decl String:sStyle[16];
		if(Style != ALL)
		{
			GetStyleName(Style, sStyle, sizeof(sStyle));
			
			Format(sStyle, sizeof(sStyle)," on %s", sStyle);
		}
		
		decl String:title[128];
		if (rows > 0)
		{
			for(new itemnum=1; itemnum<=rows; itemnum++)
			{
				SQL_FetchRow(hndl);
				SQL_FetchString(hndl, 0, mapname, sizeof(mapname));
				if(FindStringInArray(g_MapList, mapname) != -1)
				{
					count++;
					AddMenuItem(menu, mapname, mapname);
				}
			}
			
			if(client == target)
			{
				Format(title, sizeof(title), "%d %sMaps left to complete%s",
					count,
					sType,
					sStyle);
			}
			else
			{
				decl String:targetName[MAX_NAME_LENGTH];
				GetClientName(target, targetName, sizeof(targetName));
				Format(title, sizeof(title), "%d %sMaps left to complete%s for player %s",
					count,
					sType,
					sStyle,
					targetName);
			}
			SetMenuTitle(menu, title);
		}
		else
		{
			if(client == target)
			{
				PrintColorText(client, "%s%s%s%sYou have no maps left to beat%s%s.", 
					g_msg_start,
					g_msg_varcol,
					sType,
					g_msg_textcol,
					g_msg_varcol,
					sStyle);
			}
			else
			{
				decl String:targetname[MAX_NAME_LENGTH];
				GetClientName(target, targetname, sizeof(targetname));
				
				PrintColorText(client, "%s%s has no maps left to beat%s.", 
					g_msg_start,
					g_msg_varcol,
					sType,
					targetname,
					g_msg_textcol,
					g_msg_varcol,
					sStyle);
			}
		}
		
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
	{
		LogError(error);
	}
	CloseHandle(data);
}

public Menu_ShowMapsleft(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[64];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		FakeClientCommand(param1, "sm_nominate %s", info);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

//Maps done
DB_ShowMapsdone(client, target, Type, Style)
{
	if(GetPlayerID(target) != 0)
	{
		new Handle:pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackCell(pack, target);
		WritePackCell(pack, Type);
		WritePackCell(pack, Style);
	   
		decl String:query[512];
		if(Type == ALL && Style == ALL)
			Format(query, sizeof(query), "SELECT t2.MapName FROM times AS t1, maps AS t2 WHERE t1.MapID=t2.MapID AND t1.PlayerID=%d GROUP BY t1.MapID ORDER BY t2.MapName",
				GetPlayerID(target));
		else if(Type != ALL && Style == ALL)
			Format(query, sizeof(query), "SELECT t2.MapName FROM times AS t1, maps AS t2 WHERE t1.MapID=t2.MapID AND t1.Type=%d AND t1.PlayerID=%d GROUP BY t1.MapID ORDER BY t2.MapName",
				Type,
				GetPlayerID(target));
		else if(Type != ALL && Style != ALL)
			Format(query, sizeof(query), "SELECT t2.MapName FROM times AS t1, maps AS t2 WHERE t1.MapID=t2.MapID AND t1.Type=%d AND t1.Style=%d AND t1.PlayerID=%d GROUP BY t1.MapID ORDER BY t2.MapName",
				Type,
				Style,
				GetPlayerID(target));
		SQL_TQuery(g_DB, DB_ShowMapsdone_Callback, query, pack);
	}
	else
	{
		if(client == target)
		{
			PrintColorText(client, "%s%sYour SteamID is not authorized. Steam servers may be down. If not, try reconnecting.",
				g_msg_start,
				g_msg_textcol);
		}
		else
		{
			decl String:name[MAX_NAME_LENGTH];
			GetClientName(target, name, sizeof(name));
			
			PrintColorText(client, "%s%s%s's %sSteamID is not authorized. Steam servers may be down.", 
				g_msg_start,
				g_msg_varcol,
				name,
				g_msg_textcol);
		}
	}
}
 
public DB_ShowMapsdone_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client      = ReadPackCell(data);
		new target      = ReadPackCell(data);
		new Type        = ReadPackCell(data);
		new Style       = ReadPackCell(data);
	   
		new rows = SQL_GetRowCount(hndl);
		
		new String:sType[16];
		if(Type != ALL)
		{
			GetTypeName(Type, sType, sizeof(sType));
			StringToUpper(sType);
			AddBracketsToString(sType, sizeof(sType));
			AddSpaceToEnd(sType, sizeof(sType));
		}
		
		new String:sStyle[16];
		if(Style != ALL)
		{
			GetStyleName(Style, sStyle, sizeof(sStyle));
			
			Format(sStyle, sizeof(sStyle)," on %s", sStyle);
		}
		
		if(rows != 0)
		{
			new Handle:menu = CreateMenu(Menu_ShowMapsdone);
			decl String:sMapName[64];
			new mapsdone;
			
			for(new i=0; i<rows; i++)
			{
				SQL_FetchRow(hndl);
				
				SQL_FetchString(hndl, 0, sMapName, sizeof(sMapName));
				
				if(FindStringInArray(g_MapList, sMapName) != -1)
				{
					AddMenuItem(menu, sMapName, sMapName);
					mapsdone++;
				}
			}
			
			if(client == target)
			{
				SetMenuTitle(menu, "%s%d maps done%s",
					sType,
					mapsdone,
					sStyle);
			}
			else
			{
				decl String:sTargetName[MAX_NAME_LENGTH];
				GetClientName(target, sTargetName, sizeof(sTargetName));
				
				SetMenuTitle(menu, "%s%d maps done by %s%s",
					sType,
					mapsdone,
					sTargetName,
					sStyle);
			}
			
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
		else
		{
			if(client == target)
			{
				PrintColorText(client, "%s%s%s%sYou haven't finished any maps%s%s.",
					g_msg_start,
					g_msg_varcol,
					sType,
					g_msg_textcol,
					g_msg_varcol,
					sStyle);
			}
			else
			{
				decl String:targetname[MAX_NAME_LENGTH];
				GetClientName(target, targetname, sizeof(targetname));
					
				PrintColorText(client, "%s%s doesn't have any maps finished%s.",
					g_msg_start,
					g_msg_varcol,
					sType,
					targetname,
					g_msg_textcol,
					g_msg_varcol,
					sStyle);
			}
		}
	}
	else
	{
		LogError(error);
	}
	CloseHandle(data);
}
 
public Menu_ShowMapsdone(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[64];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		FakeClientCommand(param1, "sm_nominate %s", info);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

UpdateRanks(const String:sMapName[], Type, Style, bool:recalc = false)
{
	decl String:query[700];
	Format(query, sizeof(query), "UPDATE times SET Points = (SELECT t1.Rank FROM (SELECT count(*)*(SELECT AVG(Time) FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d)/10 AS Rank, t1.rownum FROM times AS t1, times AS t2 WHERE t1.MapID=t2.MapID AND t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.Type=t2.Type AND t1.Type=%d AND t1.Style=t2.Style AND t1.Style=%d AND t1.Time <= t2.Time GROUP BY t1.PlayerID ORDER BY t1.Time) AS t1 WHERE t1.rownum=times.rownum) WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d",
		sMapName,
		Type,
		Style,
		sMapName,
		Type,
		Style,
		sMapName,
		Type,
		Style);
	
	new	Handle:pack = CreateDataPack();
	WritePackCell(pack, recalc);
	WritePackString(pack, sMapName);
	WritePackCell(pack, Type);
	WritePackCell(pack, Style);
	
	SQL_TQuery(g_DB, DB_UpdateRanks_Callback, query, pack);
	
	if(recalc == false)
	{
		for(new client=1; client <= MaxClients; client++)
			DB_SetClientRank(client);
	}
}

public Native_UpdateRanks(Handle:plugin, numParams)
{
	decl String:sMapName[128];
	GetNativeString(1, sMapName, sizeof(sMapName));
	
	UpdateRanks(sMapName, GetNativeCell(2), GetNativeCell(3));
}

public DB_UpdateRanks_Callback(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(pack);
		new bool:recalc = bool:ReadPackCell(pack);
		
		if(recalc == true)
		{
			decl String:sMapName[64];
			ReadPackString(pack, sMapName, sizeof(sMapName));
			new Type  = ReadPackCell(pack);
			new Style = ReadPackCell(pack);
			
			decl String:sType[16];
			GetTypeName(Type, sType, sizeof(sType));
			StringToUpper(sType);
			AddBracketsToString(sType, sizeof(sType));
			AddSpaceToEnd(sType, sizeof(sType));
			
			decl String:sStyle[16];
			GetStyleName(Style, sStyle, sizeof(sStyle));
			StringToUpper(sStyle);
			AddBracketsToString(sStyle, sizeof(sStyle));
			
			g_RecalcProgress += 1;
			
			for(new client = 1; client <= MaxClients; client++)
			{
				if(IsClientInGame(client))
				{
					if(!IsFakeClient(client))
					{
						PrintToConsole(client, "[%.1f%%] %s %s%s finished recalculation.",
							float(g_RecalcProgress)/float(g_RecalcTotal) * 100.0,
							sMapName,
							sType[Type],
							sStyle[Style]);
					}
				}
			}
		}
		else
		{
			LogMessage("Ranks updated.");
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(pack);
}

DB_SetClientRank(client)
{
	if(GetPlayerID(client) != 0 && IsClientConnected(client))
	{
		if(!IsFakeClient(client))
		{
			decl String:query[512];
			Format(query, sizeof(query), "SELECT count(*) AS Rank FROM (SELECT SUM(Points) AS Points FROM times GROUP BY PlayerID ORDER BY SUM(Points)) AS t1 WHERE Points>=(SELECT SUM(Points) FROM times WHERE PlayerID=%d)", 
				GetPlayerID(client));
			SQL_TQuery(g_DB, DB_SetClientRank_Callback, query, client);
		}
	}
}

public DB_SetClientRank_Callback(Handle:owner, Handle:hndl, String:error[], any:client)
{
	if(hndl != INVALID_HANDLE)
	{
		if(IsClientConnected(client))
		{
			if(!IsFakeClient(client))
			{
				SQL_FetchRow(hndl);
				g_rank[client] = SQL_FetchInt(hndl, 0);
			}
		}
	}
	else
	{
		LogError(error);
	}
}

DB_ShowPlaytime(client, target)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, target);
	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT (SELECT Playtime FROM players WHERE PlayerID=%d) AS TargetPlaytime, User, Playtime FROM players ORDER BY Playtime DESC LIMIT 0, 100",
		GetPlayerID(target));
	SQL_TQuery(g_DB, DB_ShowPlaytime_Callback, query, pack);
}

public DB_ShowPlaytime_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client = ReadPackCell(data);
		new target = ReadPackCell(data);
		
		new rows = SQL_GetRowCount(hndl);
		if(rows != 0)
		{
			new Handle:menu = CreateMenu(Menu_ShowPlaytime);
		
			decl String:name[MAX_NAME_LENGTH], String:timeformatted[32], time, TargetPlaytime;
				
			decl String:item[64];
			for(new i=1; i<=rows; i++)
			{
				SQL_FetchRow(hndl);
				
				TargetPlaytime = SQL_FetchInt(hndl, 0);
				SQL_FetchString(hndl, 1, name, sizeof(name));
				time = SQL_FetchInt(hndl, 2);
				
				FormatPlayerTime(float(time), timeformatted, sizeof(timeformatted), false, 1);
				SplitString(timeformatted, ".", timeformatted, sizeof(timeformatted));
				
				Format(item, sizeof(item), "#%d: %s: %s", i, name, timeformatted);
				
				if(i%7 == 0)
					Format(item, sizeof(item), "%s\n--------------------------------------", item);
				else if(i == rows)
					Format(item, sizeof(item), "%s\n--------------------------------------", item);
				
				AddMenuItem(menu, item, item);
			}
			
			GetClientName(target, name, sizeof(name));
			FormatPlayerTime(GetPlaytime(target)+float(TargetPlaytime), timeformatted, sizeof(timeformatted), false, 1);
			SplitString(timeformatted, ".", timeformatted, sizeof(timeformatted));
			
			SetMenuTitle(menu, "Playtimes\n \n%s: %s\n--------------------------------------",
				name,
				timeformatted);
			
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
	}
	else
	{
		LogError(error);
	}
	CloseHandle(data);
}

public Menu_ShowPlaytime(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
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
	else
	{
		// Custom chat tags
		LoadCustomChat();
	}
}