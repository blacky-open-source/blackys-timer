#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "bTimes-ranks",
	author = "blacky",
	description = "Controls server rankings",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <bTimes-ranks>
#include <bTimes-random>
#include <mapchooser>
#include <scp>

#define CC_HASCC 1<<0
#define CC_MSGCOL 1<<1
#define CC_NAME 1<<2

new 	Handle:g_DB;
new 	String:g_mapname[64];
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
	//Handle:g_hCustomChatFlag;

public OnPluginStart()
{
	// Connect to the database
	DB_Connect();
	
	// Cvars
	g_hUseCustomChat  = CreateConVar("timer_enablecc", "1", "Allows specific players in sourcemod/configs/timer/custom.cfg to use custom chat.", 0, true, 0.0, true, 1.0);
	g_hUseChatRanks   = CreateConVar("timer_chatranks", "1", "Allows players to use chat ranks specified in sourcemod/configs/timer/ranks.cfg", 0, true, 0.0, true, 1.0);
	//g_hCustomChatFlag = CreateConVar("timer_ccflag", "s", "Admin flag that gives players custom chat abilities.");
	
	AutoExecConfig(true, "ranks", "timer");
	
	// Commands
	RegConsoleCmd("sm_rank", SM_Rank, "Shows the overall rank of you or a specified player.");
	RegConsoleCmd("sm_rankn", SM_RankN, "Shows the overall normal rank of you or a specified player.");
	RegConsoleCmd("sm_ranksw", SM_RankSW, "Shows the overall sideways rank of you or a specified player.");
	RegConsoleCmd("sm_rankw", SM_RankW, "Shows the overall w-only rank of you or a specified player.");
	RegConsoleCmd("sm_brank", SM_BRank, "Shows the overall bonus rank of you or a specified player.");
	
	RegConsoleCmd("sm_top", SM_Top, "Shows the overall ranks.");
	RegConsoleCmd("sm_topn", SM_TopN, "Shows the normal overall ranks.");
	RegConsoleCmd("sm_topsw", SM_TopSW, "Shows the sideways overall ranks.");
	RegConsoleCmd("sm_topw", SM_TopW, "Shows the w-only overall ranks.");
	RegConsoleCmd("sm_btop", SM_BTop, "Shows the bonus ranks");
	
	RegConsoleCmd("sm_mapsleft", SM_Mapsleft, "Shows your or a specified player's maps left to beat.");
	RegConsoleCmd("sm_mapsleftn", SM_MapsleftN, "Shows your or a specified player's maps left to beat on normal.");
	RegConsoleCmd("sm_mapsleftsw", SM_MapsleftSW, "Shows your or a specified player's maps left to beat on sideways.");
	RegConsoleCmd("sm_mapsleftw", SM_MapsleftW, "Shows your or a specified player's maps left to beat on w-only.");
	RegConsoleCmd("sm_bmapsleft", SM_BMapsleft, "Shows your or a specified player's bonus maps left to beat.");
	
	RegConsoleCmd("sm_mapsdone", SM_Mapsdone, "Shows your or a specified player's maps done.");
	RegConsoleCmd("sm_mapsdonen", SM_MapsdoneN, "Shows your or a specified player's maps done on normal.");
	RegConsoleCmd("sm_mapsdonesw", SM_MapsdoneSW, "Shows your or a specified player's maps done on sideways.");
	RegConsoleCmd("sm_mapsdonew", SM_MapsdoneW, "Shows your or a specified player's maps done on w-only.");
	RegConsoleCmd("sm_bmapsdone", SM_BMapsdone, "Shows your or a specified player's bonus maps done.");
	
	RegConsoleCmd("sm_stats", SM_Stats, "Shows the stats of you or a specified player.");
	RegConsoleCmd("sm_playtime", SM_Playtime, "Shows the people who played the most.");
	
	RegConsoleCmd("sm_ccname", SM_ColoredName, "Change colored name.");
	RegConsoleCmd("sm_ccmsg", SM_ColoredMsg, "Change the color of your messages.");
	RegConsoleCmd("sm_cchelp", SM_Colorhelp, "For help on creating a custom name tag with colors and a color message.");
	
	RegConsoleCmd("sm_rankings", SM_Rankings, "Shows the chat ranking tags and the ranks required to get them.");
	RegConsoleCmd("sm_ranks", SM_Rankings, "Shows the chat ranking tags and the ranks required to get them.");
	RegConsoleCmd("sm_chatranks", SM_Rankings, "Shows the chat ranking tags and the ranks required to get them.");
	
	// Admin commands
	RegAdminCmd("sm_enablecc", SM_EnableCC, ADMFLAG_ROOT, "Enable custom chat for a specified SteamID.");
	RegAdminCmd("sm_disablecc", SM_DisableCC, ADMFLAG_ROOT, "Disable custom chat for a specified SteamID.");
	RegAdminCmd("sm_cclist", SM_CCList, ADMFLAG_CHEATS, "Shows a list of players with custom chat privileges.");
	
	// Admin
	RegAdminCmd("sm_reloadranks", SM_ReloadRanks, ADMFLAG_CHEATS, "Reloads chat ranks.");
	
	// Chat ranks
	LoadChatRanks();
	
	g_hCustomSteams   = CreateArray(32);
	g_hCustomNames    = CreateArray(128);
	g_hCustomMessages = CreateArray(256);
	g_hCustomUse 	  = CreateArray();

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
	GetCurrentMap(g_mapname, sizeof(g_mapname));
	
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
		for(new i=1; i<=MaxClients; i++)
		{
			if(IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i))
			{
				PushArrayCell(recipients, i);
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
	decl String:sCustomAuth[32];
	new iSize = GetArraySize(g_hCustomSteams);
	
	for(new i=0; i<iSize; i++)
	{
		GetArrayString(g_hCustomSteams, i, sCustomAuth, sizeof(sCustomAuth));
		if(StrEqual(auth, sCustomAuth))
		{	
			g_bClientHasCustom[client] = true;
			
			g_ClientUseCustom[client]  = GetArrayCell(g_hCustomUse, i);
			break;
		}
	}
}

public bool:OnClientConnect(client)
{
	g_bClientHasCustom[client] = false;
	g_ClientUseCustom[client]  = 0;
	//g_bHasCCFlag[client]       = false;
	
	return true;
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
		
		LogMessage("%L executed sm_rank", client);
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
		
		LogMessage("%L executed sm_wr", client);
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
		
		LogMessage("%L executed sm_ranksw", client);
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
		
		LogMessage("%L executed sm_rankw", client);
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
		
		LogMessage("%L executed sm_brank", client);
	}
	return Plugin_Handled;
}

public Action:SM_Top(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		DB_ShowTopAll(client);
		
		LogMessage("%L executed sm_top", client);
	}
	return Plugin_Handled;
}

public Action:SM_TopN(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		DB_ShowTopAllSpec(client, TIMER_MAIN, STYLE_NORMAL);
		
		LogMessage("%L executed sm_topn", client);
	}
	return Plugin_Handled;
}

public Action:SM_TopSW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		DB_ShowTopAllSpec(client, TIMER_MAIN, STYLE_SIDEWAYS);
		
		LogMessage("%L executed sm_topsw", client);
	}
	return Plugin_Handled;
}

public Action:SM_TopW(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		DB_ShowTopAllSpec(client, TIMER_MAIN, STYLE_WONLY);
		
		LogMessage("%L executed sm_topw", client);
	}
	return Plugin_Handled;
}

public Action:SM_BTop(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		DB_ShowTopAllSpec(client, TIMER_BONUS, STYLE_NORMAL);
		
		LogMessage("%L executed sm_btop", client);
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
		
		LogMessage("%L executed sm_mapsleft", client);
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
		
		LogMessage("%L executed sm_mapsleftn", client);
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
		
		LogMessage("%L executed sm_mapsleftsw", client);
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
		
		LogMessage("%L executed sm_mapsleftw", client);
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
		
		LogMessage("%L executed sm_bmapsleft", client);
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
		
		LogMessage("%L executed sm_mapsdone", client);
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
		
		LogMessage("%L executed sm_mapsdonen", client);
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
		
		LogMessage("%L executed sm_mapsdonesw", client);
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
		
		LogMessage("%L executed sm_mapsdonew", client);
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
		
		LogMessage("%L executed sm_bmapsdone", client);
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
		
		LogMessage("%L executed sm_playtime", client);
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
		// Check and enable cc for any clients in the game
		decl String:sAuth[32];
		for(new i=1; i<=MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				GetClientAuthString(client, sAuth, sizeof(sAuth));
				if(StrEqual(sAuth, sArg))
				{
					g_bClientHasCustom[client] = true;
					g_ClientUseCustom[client]  = CC_HASCC|CC_MSGCOL|CC_NAME;
				}
			}
		}
		
		decl String:query[512];
		FormatEx(query, sizeof(query), "UPDATE players SET ccuse=%d, ccname='{rand}{name}', ccmsgcol='^000000' WHERE SteamID='%s'",
			CC_HASCC|CC_MSGCOL|CC_NAME,
			sArg);
		SQL_TQuery(g_DB, EnableCC_Callback, query);
		
		PushArrayString(g_hCustomSteams, sArg);
		PushArrayString(g_hCustomNames, "{rand}{name}");
		PushArrayString(g_hCustomMessages, "^000000");
		PushArrayCell(g_hCustomUse, CC_HASCC|CC_MSGCOL|CC_NAME);
	}
	else
	{
		PrintColorText(client, "%s%ssm_enablecc example: \"sm_enablecc STEAM_0:1:12345\"",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
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
		// Check and disable cc for any clients in the game
		decl String:sAuth[32];
		for(new i=1; i<=MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				GetClientAuthString(client, sAuth, sizeof(sAuth));
				if(StrEqual(sAuth, sArg))
				{
					g_bClientHasCustom[client] = false;
					g_ClientUseCustom[client]  = 0;
				}
			}
		}
		
		decl String:query[512];
		FormatEx(query, sizeof(query), "UPDATE players SET ccuse=0 WHERE SteamID='%s'",
			sArg);
		SQL_TQuery(g_DB, EnableCC_Callback, query);
	}
	else
	{
		PrintColorText(client, "%s%ssm_disablecc example: \"sm_disablecc STEAM_0:1:12345\"",
			g_msg_start,
			g_msg_textcol);
	}
	return Plugin_Handled;
}

public DisableCC_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		LoadCustomChat();
	}
	else
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
		
		PrintColorText(client, "%s%05d %s-%s %05d%s: %s",
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
				SetEntProp(client, Prop_Data, "m_iDeaths", g_rank[client]);
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
	WritePackCell(pack, Type);
	WritePackCell(pack, Style);
	
	new PlayerID = GetClientID(target);
	
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
		new Type   = ReadPackCell(data);
		new Style  = ReadPackCell(data);
		
		new const String:sType[3][] = {"", "", "[BONUS] "};
		new const String:sStyle[4][] = {"", "[NORMAL] ", "[SIDEWAYS] ", "[W-ONLY] "};
		
		decl String:sTarget[MAX_NAME_LENGTH];
		GetClientName(target, sTarget, sizeof(sTarget));
		
		SQL_FetchRow(hndl);
		
		if(SQL_FetchInt(hndl, 0) != 0)
		{
			new Rank 		 = SQL_FetchInt(hndl, 0);
			new Total 		 = SQL_FetchInt(hndl, 1);
			new Float:Points = SQL_FetchFloat(hndl, 2);
		
			PrintColorText(client, "%s%s%s%s%s%s is ranked %s%d%s of %s%d%s players with %s%.1f%s points.",
				g_msg_start,
				g_msg_varcol,
				sType[Type+1],
				(Type == TIMER_BONUS)?"":sStyle[Style+1],
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
			PrintColorText(client, "%s%s%s%s%s%s is not ranked yet.",
				g_msg_start,
				g_msg_varcol,
				sType[Type+1],
				(Type == TIMER_BONUS)?"":sStyle[Style+1],
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
	if (action == MenuAction_Select)
	{
		//new String:info[32];
		//GetMenuItem(menu, param2, info, sizeof(info));
	}
	else if (action == MenuAction_End)
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
		
		new String:name[MAX_NAME_LENGTH], String:item[128], Float:points;
		new rows = SQL_GetRowCount(hndl);
		new Handle:menu   = CreateMenu(Menu_ShowTopAllSpec);
		new const String:typeString[2][] = {"", "[BONUS] "};
		new const String:styleString[3][] = {"(Normal)", "(Sideways)", "(W-only)"};
		decl String:title[128];
		Format(title, sizeof(title), "%sTOP 100 %s\n------------------------------------",
			typeString[Type],
			(Type == TIMER_BONUS)?"":styleString[Style]);
		SetMenuTitle(menu, title);

		for(new itemnum=1; itemnum<=rows; itemnum++)
		{
			SQL_FetchRow(hndl);
			SQL_FetchString(hndl, 0, name, sizeof(name));
			points = SQL_FetchFloat(hndl, 1);
			FormatEx(item, sizeof(item), "#%d: %s - %6.2f", itemnum, name, points);
			
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
	if (action == MenuAction_Select)
	{
		//new String:info[32];
		//GetMenuItem(menu, param2, info, sizeof(info));
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

DB_ShowMapsleft(client, target, Type, Style)
{
	if(GetClientID(target) != 0)
	{
		new Handle:pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackCell(pack, target);
		WritePackCell(pack, Type);
		WritePackCell(pack, Style);
		
		decl String:query[512];
		if(Type == ALL && Style == ALL)
			Format(query, sizeof(query), "SELECT t2.MapName FROM (SELECT maps.MapID AS MapID1, t1.MapID AS MapID2 FROM maps LEFT JOIN (SELECT MapID FROM times WHERE PlayerID=%d) t1 ON maps.MapID=t1.MapID) AS t1, maps AS t2 WHERE t1.MapID1=t2.MapID AND t1.MapID2 IS NULL ORDER BY t2.MapName",
				GetClientID(target));
		else
			Format(query, sizeof(query), "SELECT t2.MapName FROM (SELECT maps.MapID AS MapID1, t1.MapID AS MapID2 FROM maps LEFT JOIN (SELECT MapID FROM times WHERE Type=%d AND Style=%d AND PlayerID=%d) t1 ON maps.MapID=t1.MapID) AS t1, maps AS t2 WHERE t1.MapID1=t2.MapID AND t1.MapID2 IS NULL ORDER BY t2.MapName",
				Type,
				Style,
				GetClientID(target));
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
		new Type	= ReadPackCell(data);
		new Style 	= ReadPackCell(data);
		
		new rows = SQL_GetRowCount(hndl), count;
		new String:mapname[128];
		new Handle:menu = CreateMenu(Menu_ShowMapsleft);
		new const String:typeString[3][] = {"", "", "[Bonus] "};
		new const String:styleString[4][] = {"", " on Normal", " on Sideways", " on W-Only"};
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
					typeString[Type+1],
					styleString[Style+1]);
			}
			else
			{
				decl String:targetName[MAX_NAME_LENGTH];
				GetClientName(target, targetName, sizeof(targetName));
				Format(title, sizeof(title), "%d %sMaps left to complete%s for player %s",
					count,
					typeString[Type+1],
					styleString[Style+1],
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
					typeString[Type+1],
					g_msg_textcol,
					g_msg_varcol,
					styleString[Style+1]);
			}
			else
			{
				decl String:targetname[MAX_NAME_LENGTH];
				GetClientName(target, targetname, sizeof(targetname));
				
				PrintColorText(client, "%s%s has no maps left to beat%s.", 
					g_msg_start,
					g_msg_varcol,
					typeString[Type+1],
					targetname,
					g_msg_textcol,
					g_msg_varcol,
					styleString[Style+1]);
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
        if(GetClientID(target) != 0)
        {
                new Handle:pack = CreateDataPack();
                WritePackCell(pack, client);
                WritePackCell(pack, target);
                WritePackCell(pack, Type);
                WritePackCell(pack, Style);
               
                decl String:query[512];
                if(Type == ALL && Style == ALL)
                        Format(query, sizeof(query), "SELECT t2.MapName FROM times AS t1, maps AS t2 WHERE t1.MapID=t2.MapID AND t1.PlayerID=%d GROUP BY t1.MapID ORDER BY t2.MapName",
                                GetClientID(target));
                else if(Type != ALL && Style == ALL)
                        Format(query, sizeof(query), "SELECT t2.MapName FROM times AS t1, maps AS t2 WHERE t1.MapID=t2.MapID AND t1.Type=%d AND t1.PlayerID=%d GROUP BY t1.MapID ORDER BY t2.MapName",
                                Type,
                                GetClientID(target));
			else if(Type != ALL && Style != ALL)
					Format(query, sizeof(query), "SELECT t2.MapName FROM times AS t1, maps AS t2 WHERE t1.MapID=t2.MapID AND t1.Type=%d AND t1.Style=%d AND t1.PlayerID=%d GROUP BY t1.MapID ORDER BY t2.MapName",
						Type,
						Style,
						GetClientID(target));
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
		
		if(rows != 0)
		{
			new Handle:menu = CreateMenu(Menu_ShowMapsdone);
			decl String:sMapName[64];
			new const String:sType[3][] = {"", "[MAIN] ", "[BONUS] "};
			new const String:sStyle[4][] = {"", " on normal", " on sideways", " on w-only"};
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
					sType[Type+1],
					mapsdone,
					sStyle[Style+1]);
			}
			else
			{
				decl String:sTargetName[MAX_NAME_LENGTH];
				GetClientName(target, sTargetName, sizeof(sTargetName));
				
				SetMenuTitle(menu, "%s%d maps done by %s%s",
					sType[Type+1],
					mapsdone,
					sTargetName,
					sStyle[Style+1]);
			}
			
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
		else
		{
			new const String:typeString[3][]  = {"", " [MAIN]", " [BONUS]"};
			new const String:styleString[4][] = {"", " [NORMAL]", " [SIDEWAYS]", " [W-ONLY]"};
			
			if(client == target)
			{
				PrintColorText(client, "%s%s%s%sYou haven't finished any maps%s%s.",
					g_msg_start,
					g_msg_varcol,
					typeString[Type+1],
					g_msg_textcol,
					g_msg_varcol,
					styleString[Style+1]);
			}
			else
			{
				decl String:targetname[MAX_NAME_LENGTH];
				GetClientName(target, targetname, sizeof(targetname));
					
				PrintColorText(client, "%s%s doesn't have any maps finished%s.",
					g_msg_start,
					g_msg_varcol,
					typeString[Type+1],
					targetname,
					g_msg_textcol,
					g_msg_varcol,
					styleString[Style+1]);
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

public Native_UpdateRanks(Handle:plugin, numParams)
{
	decl String:sMapName[128];
	GetNativeString(1, sMapName, sizeof(sMapName));
	
	decl String:query[700];
	Format(query, sizeof(query), "UPDATE times SET Points = (SELECT t1.Rank FROM (SELECT count(*)*(SELECT AVG(Time) FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND Type=%d AND Style=%d)/10 AS Rank, t1.rownum FROM times AS t1, times AS t2 WHERE t1.MapID=t2.MapID AND t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND t1.Type=t2.Type AND t1.Type=%d AND t1.Style=t2.Style AND t1.Style=%d AND t1.Time <= t2.Time GROUP BY t1.PlayerID ORDER BY t1.Time) AS t1 WHERE t1.rownum=times.rownum) WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s') AND Type=%d AND Style=%d",
		sMapName,
		GetNativeCell(2),
		GetNativeCell(3),
		sMapName,
		GetNativeCell(2),
		GetNativeCell(3),
		sMapName,
		GetNativeCell(2),
		GetNativeCell(3));
	SQL_TQuery(g_DB, DB_UpdateRanks_Callback, query);
	
	for(new client=1; client <= MaxClients; client++)
		DB_SetClientRank(client);
}

public DB_UpdateRanks_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		LogMessage("Ranks updated.");
	}
	else
	{
		LogError(error);
	}
}

DB_SetClientRank(client)
{
	if(GetClientID(client) != 0 && IsClientConnected(client))
	{
		if(!IsFakeClient(client))
		{
			decl String:query[512];
			Format(query, sizeof(query), "SELECT count(*) AS Rank FROM (SELECT SUM(Points) AS Points FROM times GROUP BY PlayerID ORDER BY SUM(Points)) AS t1 WHERE Points>=(SELECT SUM(Points) FROM times WHERE PlayerID=%d)", 
				GetClientID(client));
			SQL_TQuery(g_DB, DB_SetClientRank_Callback, query, client);
		}
	}
}

public DB_SetClientRank_Callback(Handle:owner, Handle:hndl, String:error[], any:client)
{
	if(hndl != INVALID_HANDLE)
	{
		if(!IsFakeClient(client))
		{
			SQL_FetchRow(hndl);
			g_rank[client] = SQL_FetchInt(hndl, 0);
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
		GetClientID(target));
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
	if (action == MenuAction_Select)
	{
		//new String:info[32];
		//GetMenuItem(menu, param2, info, sizeof(info));
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
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
	else
	{
		// Custom chat tags
		LoadCustomChat();
	}
}
