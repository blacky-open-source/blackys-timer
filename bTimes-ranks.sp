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

new 	Handle:g_DB = INVALID_HANDLE;
new 	String:g_mapname[64];

new 	g_rank[MAXPLAYERS+1];

new	String:g_msg_start[128],
	String:g_msg_varcol[128],
	String:g_msg_textcol[128];
	
new 	bool:g_MapChooser;

// Chat ranks
new 	Handle:g_hChatRanksRanges,
	Handle:g_hChatRanksNames;
	
// Custom chat
new	Handle:g_hCustomSteams,
	Handle:g_hCustomNames,
	Handle:g_hCustomMessages,
	Handle:g_hCustomUse,
	bool:g_bClientHasCustom[MAXPLAYERS+1],
	bool:g_bClientUseCustom[MAXPLAYERS+1];
	
// Settings
new	Handle:g_hUseCustomChat,
	Handle:g_hUseChatRanks;

public OnPluginStart()
{
	// Connect to the database
	DB_Connect();
	
	// Cvars
	g_hUseCustomChat = CreateConVar("timer_customchat", "1", "Allows specific players in sourcemod/configs/timer/custom.cfg to use custom chat.", 0, true, 0.0, true, 1.0);
	g_hUseChatRanks  = CreateConVar("timer_chatranks", "1", "Allows players to use chat ranks specified in sourcemod/configs/timer/ranks.cfg", 0, true, 0.0, true, 1.0);
	
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
	
	RegConsoleCmd("sm_colorname", SM_ColoredName, "Change colored name.");
	RegConsoleCmd("sm_colormsg", SM_ColoredMsg, "Change the color of your messages.");
	RegConsoleCmd("sm_colorhelp", SM_Colorhelp, "For help on creating a custom name tag with colors and a color message.");
	
	// Admin
	RegAdminCmd("sm_reloadranks", SM_ReloadRanks, ADMFLAG_CHEATS, "Reloads chat ranks.");
	RegAdminCmd("sm_reloadcc", SM_ReloadCC, ADMFLAG_CHEATS, "Reload custom chat.");
	
	// Chat ranks
	LoadChatRanks();
	
	// Custom chat tags
	LoadCustomChat();

	// Makes FindTarget() work properly
	LoadTranslations("common.phrases");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("DB_UpdateRanks", Native_UpdateRanks);
	CreateNative("SetClientRank", Native_SetClientRank);
	return APLRes_Success;
}

public OnLibraryAdded(const String:name[])
{
	if(StrEqual("mapchooser", name))
	{
		g_MapChooser = true;
	}
}

public OnLibraryRemoved(const String:name[])
{
	if(StrEqual("mapchooser", name))
	{
		g_MapChooser = false;
	}
}

public OnMapStart()
{
	GetCurrentMap(g_mapname, sizeof(g_mapname));
	
	CreateTimer(1.0, UpdateDeaths, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
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

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	if(g_bClientUseCustom[author] && g_bClientHasCustom[author] && GetConVarBool(g_hUseCustomChat))
	{
		new iSize = GetArraySize(g_hCustomSteams);
		decl String:sAuth[32], String:sCustomAuth[32], String:sMessageCol[MAXLENGTH_MESSAGE];
		
		GetClientAuthString(author, sAuth, sizeof(sAuth));
		for(new i=0; i<iSize; i++)
		{
			GetArrayString(g_hCustomSteams, i, sCustomAuth, sizeof(sCustomAuth));
			
			if(StrEqual(sAuth, sCustomAuth))
			{
				GetArrayString(g_hCustomNames, i, name, MAXLENGTH_NAME);
				FormatTag(author, name, MAXLENGTH_NAME);
				
				GetArrayString(g_hCustomMessages, i, sMessageCol, sizeof(sMessageCol));
				ReplaceString(sMessageCol, sizeof(sMessageCol), "^", "\x07");
				Format(message, MAXLENGTH_MESSAGE, "%s%s", sMessageCol, message);
				
				return Plugin_Changed;
			}
		}
	}
	else if(GetConVarBool(g_hUseChatRanks))
	{
		new iSize = GetArraySize(g_hChatRanksNames);
		
		for(new i=0; i<iSize; i++)
		{
			if(GetArrayCell(g_hChatRanksRanges, i, 0) <= g_rank[author] <= GetArrayCell(g_hChatRanksRanges, i, 1))
			{
				GetArrayString(g_hChatRanksNames, i, name, MAXLENGTH_NAME);
				FormatTag(author, name, MAXLENGTH_NAME);
				
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

stock FormatTag(client, String:buffer[], maxlength)
{
	ReplaceString(buffer, maxlength, "{team}", "\x03");
	ReplaceString(buffer, maxlength, "^", "\x07");
	
	decl String:sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));
	ReplaceString(buffer, maxlength, "{name}", sName);
}

public OnClientAuthorized(client, const String:auth[])
{
	new iSize = GetArraySize(g_hCustomSteams);
	decl String:sCustomAuth[32];
	
	for(new i=0; i<iSize; i++)
	{
		GetArrayString(g_hCustomSteams, i, sCustomAuth, sizeof(sCustomAuth));
		if(StrEqual(auth, sCustomAuth))
		{	
			g_bClientHasCustom[client] = true;
			
			if(GetArrayCell(g_hCustomUse, i, 0) == 1)
			{
				g_bClientUseCustom[client] = true;
			}
		}
	}
}


public bool:OnClientConnect(client)
{
	g_bClientHasCustom[client] = false;
	g_bClientUseCustom[client] = false;
	
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
	if(g_bClientHasCustom[client])
	{
		new iSize = GetArraySize(g_hCustomSteams);
		decl String:sAuth[32], String:sCustomAuth[32];
		GetClientAuthString(client, sAuth, sizeof(sAuth));
		
		if(args == 0)
		{
			g_bClientUseCustom[client] = !g_bClientUseCustom[client];
			if(g_bClientUseCustom[client])
			{
				PrintColorText(client, "%s%sNow using custom chat.",
					g_msg_start,
					g_msg_textcol);
			}
			else
			{
				PrintColorText(client, "%s%sNo longer using custom chat.",
					g_msg_start,
					g_msg_textcol);
			}
			
			for(new i=0; i<iSize; i++)
			{
				GetArrayString(g_hCustomSteams, i, sCustomAuth, sizeof(sCustomAuth));
				if(StrEqual(sCustomAuth, sAuth))
				{
					SetArrayCell(g_hCustomUse, i, g_bClientUseCustom[client]);
					RewriteCustomChat();
					break;
				}
			}
		}
		else
		{
			decl String:sArg[250];
			GetCmdArgString(sArg, sizeof(sArg));
			ReplaceString(sArg, sizeof(sArg), "; ", "");
			PrintColorText(client, "%s%sColor name set to %s%s%s.",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				sArg,
				g_msg_textcol);
			
			for(new i=0; i<iSize; i++)
			{
				GetArrayString(g_hCustomSteams, i, sCustomAuth, sizeof(sCustomAuth));
				if(StrEqual(sCustomAuth, sAuth))
				{
					SetArrayString(g_hCustomNames, i, sArg);
					RewriteCustomChat();
					break;
				}
			}
		}
	}
	else
	{
		PrintColorText(client, "%s%sYou do not have custom chat privileges.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action:SM_ColoredMsg(client, args)
{	
	if(g_bClientHasCustom[client])
	{
		new iSize = GetArraySize(g_hCustomSteams);
		decl String:sAuth[32], String:sCustomAuth[32];
		GetClientAuthString(client, sAuth, sizeof(sAuth));
		
		for(new i=0; i<iSize; i++)
		{
			GetArrayString(g_hCustomSteams, i, sCustomAuth, sizeof(sCustomAuth));
			if(StrEqual(sAuth, sCustomAuth))
			{
				decl String:sArg[250];
				GetCmdArgString(sArg, sizeof(sArg));
				ReplaceString(sArg, sizeof(sArg), "; ", "");
				SetArrayString(g_hCustomMessages, i, sArg);
				PrintColorText(client, "%s%sMessages now beginning with %s", 
					g_msg_start,
					g_msg_textcol,
					sArg);
				
				RewriteCustomChat();
				break;
			}
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
	
	PrintToConsole(client, "sm_colorname <arg> to set your name.");
	PrintToConsole(client, "sm_colormsg <arg> to set your message.");
	PrintToConsole(client, "With sm_colorname, putting the actual text {name} in there will replace it with your steam name.");
	PrintToConsole(client, "To add color, use the '^' character, followed by a hexadecimal code such as FFFFFF. Example: sm_colormsg ^FFFFFF");
	
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

public Action:SM_ReloadCC(client, args)
{
	LoadCustomChat();
	
	decl String:sAuth[32], String:sCustomAuth[32];
	
	new iSize = GetArraySize(g_hCustomSteams);
	for(new i=1; i<=MaxClients; i++)
	{
		g_bClientHasCustom[i] = false;
		g_bClientUseCustom[i] = false;
		
		if(IsClientInGame(i))
		{
			GetClientAuthString(i, sAuth, sizeof(sAuth));
		
			for(new j=0; j<iSize; j++)
			{
				GetArrayString(g_hCustomSteams, j, sCustomAuth, sizeof(sCustomAuth));
				if(StrEqual(sAuth, sCustomAuth))
				{	
					g_bClientHasCustom[i] = true;
					
					if(GetArrayCell(g_hCustomUse, j, 0) == 1)
					{
						g_bClientUseCustom[i] = true;
					}
				}
			}
		}
	}
	
	PrintColorText(client, "%s%sCustom chat reloaded.",
		g_msg_start,
		g_msg_textcol);
		
	return Plugin_Handled;
}

public Action:SM_Stats(client, args)
{
	
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
	// Check if timer config path exists
	decl String:sPath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer");
	if(!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}
	
	// If it doesn't exist, create a default custom config
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/custom.cfg");
	if(!FileExists(sPath))
	{
		new Handle:hFile = OpenFile(sPath, "w");
		WriteFileLine(hFile, "//SteamID; Chattag {name}; Chatcolor; 1 = Use Custom chat, 0 = Don't use custom chat (client preference)");
		WriteFileLine(hFile, "STEAM_0:0:1739936; ^FFFFFF[^E0531BCreator^FFFFFF] ^000000{name}; ^FFFFFF; 1");
		CloseHandle(hFile);
	}
	
	// init custom chat arrays
	g_hCustomSteams   = CreateArray(128, 1);
	g_hCustomNames    = CreateArray(128, 1);
	g_hCustomMessages = CreateArray(128, 1);
	g_hCustomUse      = CreateArray(1, 1);
	
	new String:line[PLATFORM_MAX_PATH], String:oldLine[PLATFORM_MAX_PATH], String:expLine[4][128];
	new iSize = 1;
	
	new Handle:hFile = OpenFile(sPath, "r");
	while(!IsEndOfFile(hFile))
	{
		ReadFileLine(hFile, line, sizeof(line));
		ReplaceString(line, sizeof(line), "\n", "");
		
		if(line[0] != '/' && line[1] != '/')
		{
			if(!StrEqual(line, oldLine))
			{
				ExplodeString(line, "; ", expLine, 4, 128);
				
				SetArrayString(g_hCustomSteams, iSize-1, expLine[0]);
				SetArrayString(g_hCustomNames, iSize-1, expLine[1]);
				SetArrayString(g_hCustomMessages, iSize-1, expLine[2]);
				SetArrayCell(g_hCustomUse, iSize-1, StringToInt(expLine[3]), 0);
				
				ResizeArray(g_hCustomSteams, iSize+1);
				ResizeArray(g_hCustomNames, iSize+1);
				ResizeArray(g_hCustomMessages, iSize+1);
				ResizeArray(g_hCustomUse, iSize+1);
				
				iSize++;
			}
		}
		
		Format(oldLine, sizeof(oldLine), line);
	}
	CloseHandle(hFile);
}

RewriteCustomChat()
{
	// Check if timer config path exists
	decl String:sPath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer");
	if(!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}
	
	// If it doesn't exist, create a default custom config
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/custom.cfg");
	if(FileExists(sPath))
	{
		DeleteFile(sPath);
		
		decl String:expLine[3][128], String:sLine[512]; new canUse;
		new Handle:hFile = OpenFile(sPath, "w");
		
		if(hFile != INVALID_HANDLE)
		{
			WriteFileLine(hFile, "//SteamID; Chattag {name}; Chatcolor; 1 = Use Custom chat, 0 = Don't use custom chat (client preference)");
			new iSize = GetArraySize(g_hCustomSteams);
			for(new i=0; i<iSize-1; i++)
			{
				GetArrayString(g_hCustomSteams, i, expLine[0], 128);
				GetArrayString(g_hCustomNames, i, expLine[1], 128);
				GetArrayString(g_hCustomMessages, i, expLine[2], 128);
				canUse = GetArrayCell(g_hCustomUse, i, 0);
				
				Format(sLine, sizeof(sLine), "%s; %s; %s; %d", expLine[0], expLine[1], expLine[2], canUse);
				WriteFileLine(hFile, sLine);
			}	
		}
		
		CloseHandle(hFile);
	}
}

DB_ShowRank(client, target, Type, Style)
{	
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, target);
	WritePackCell(pack, Type);
	WritePackCell(pack, Style);
	
	decl String:query[256];
	if(Type == ALL && Style == ALL)
		Format(query, sizeof(query), "SELECT count(*) AS Rank FROM (SELECT SUM(Points) AS Points FROM times GROUP BY PlayerID ORDER BY SUM(Points)) AS t1 WHERE Points>=(SELECT SUM(Points) FROM times WHERE PlayerID=%d)", 
			GetClientID(target));
	else
		Format(query, sizeof(query), "SELECT count(*) AS Rank FROM (SELECT SUM(Points) AS Points FROM times WHERE Type=%d AND Style=%d GROUP BY PlayerID ORDER BY SUM(Points)) AS t1 WHERE Points>=(SELECT SUM(Points) FROM times WHERE Type=%d AND Style=%d AND PlayerID=%d)", 
			Type,
			Style,
			Type,
			Style,
			GetClientID(target));
	SQL_TQuery(g_DB, DB_ShowRank_Callback1, query, pack);
}

public DB_ShowRank_Callback1(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client	= ReadPackCell(data);
		new target	= ReadPackCell(data);
		new Type	= ReadPackCell(data);
		new Style 	= ReadPackCell(data);
		
		SQL_FetchRow(hndl);
		new rank = SQL_FetchInt(hndl, 0);
		if(rank == 0)
		{
			new const String:typeString[3][] = {"", "", "[BONUS] "};
			new const String:styleString[4][] = {"", " (Normal)", " (Sideways)", " (W-only)"};
			if(client == target)
			{
				PrintColorText(client, "%s%s%s%sYou are not ranked yet%s%s",
					g_msg_start,
					g_msg_varcol,
					typeString[Type+1],
					g_msg_textcol,
					(Style != -1)?g_msg_varcol:"",
					styleString[Style+1]);
			}
			else
			{
				decl String:targetname[MAX_NAME_LENGTH];
				GetClientName(target, targetname, sizeof(targetname));
				
				PrintColorText(client, "%s%s%s%s%s is not ranked yet %s%s",
					g_msg_start,
					g_msg_varcol,
					typeString[Type+1],
					targetname,
					g_msg_textcol,
					(Style != -1)?g_msg_varcol:"",
					styleString[Style+1]);
			}
		}
		else
		{
			WritePackCell(data, rank);
			decl String:query[256];
			if(Type == ALL && Style == ALL)
				Format(query, sizeof(query), "SELECT count(*) FROM (SELECT SUM(Points) AS Points FROM times GROUP BY PlayerID ORDER BY SUM(Points)) AS t1");
			else
				Format(query, sizeof(query), "SELECT count(*) FROM (SELECT SUM(Points) AS Points FROM times WHERE Type=%d AND Style=%d GROUP BY PlayerID ORDER BY SUM(Points)) AS t1",
				Type,
				Style);
			SQL_TQuery(g_DB, DB_ShowRank_Callback2, query, data);
		}
	}
	else
	{
		LogError(error);
	}
}

public DB_ShowRank_Callback2(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		ReadPackCell(data);
		new target	= ReadPackCell(data);
		new Type	= ReadPackCell(data);
		new Style 	= ReadPackCell(data);
		ReadPackCell(data);
		
		SQL_FetchRow(hndl);
		new total 	= SQL_FetchInt(hndl, 0);
		WritePackCell(data, total);
		
		decl String:query[256];
		if(Type == ALL && Style == ALL)
			Format(query, sizeof(query), "SELECT SUM(Points) FROM times WHERE PlayerID=%d",
				GetClientID(target));
		else
			Format(query, sizeof(query), "SELECT SUM(Points) FROM times WHERE PlayerID=%d AND Type=%d AND Style=%d",
				GetClientID(target),
				Type,
				Style);
		SQL_TQuery(g_DB, DB_ShowRank_Callback3, query, data);
	}
	else
	{
		LogError(error);
	}
}

public DB_ShowRank_Callback3(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		ReadPackCell(data);
		new target	= ReadPackCell(data);
		new Type	= ReadPackCell(data);
		new Style 	= ReadPackCell(data);
		new rank	= ReadPackCell(data);
		new total	= ReadPackCell(data);
		
		SQL_FetchRow(hndl);
		new Float:points = SQL_FetchFloat(hndl, 0);
		
		new const String:typeString[3][] = {"", "", "[BONUS] "};
		new const String:styleString[4][] = {" ", " (Normal)", " (Sideways)", " (W-only)"};
		decl String:targetname[MAX_NAME_LENGTH];
		
		GetClientName(target, targetname, sizeof(targetname));
		
		PrintColorTextAll("%s%s%s%s%s is ranked %s%d%s of %s%d%s players with %s%6.3f%s points %s%s",
			g_msg_start,
			g_msg_varcol,
			typeString[Type+1],
			targetname,
			g_msg_textcol,
			g_msg_varcol,
			rank,
			g_msg_textcol,
			g_msg_varcol,
			total,
			g_msg_textcol,
			g_msg_varcol,
			points,
			g_msg_textcol,
			g_msg_varcol,
			styleString[Style+1]);
	}
	else
	{
		LogError(error);
	}
}

DB_ShowTopAll(client)
{
	decl String:query[256];
	Format(query, sizeof(query), "SELECT t1.User, SUM(t2.Points) FROM players AS t1, times AS t2 WHERE t1.PlayerID=t2.PlayerID GROUP BY t2.PlayerID ORDER BY SUM(t2.Points) DESC");
	SQL_TQuery(g_DB, DB_ShowTopAll_Callback, query, client);
}

public DB_ShowTopAll_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new String:name[MAX_NAME_LENGTH], String:item[128], Float:points;
		new rows = SQL_GetRowCount(hndl);
		new Handle:menu = CreateMenu(Menu_ShowTopAll);
		SetMenuTitle(menu, "Overall Rankings");
		for(new itemnum=1; itemnum<=rows; itemnum++)
		{
			SQL_FetchRow(hndl);
			SQL_FetchString(hndl, 0, name, sizeof(name));
			points = SQL_FetchFloat(hndl, 1);
			Format(item, sizeof(item), "#%d: %s - %6.3f", itemnum, name, points);
			AddMenuItem(menu, item, item);
		}
		SetMenuExitBackButton(menu, true);
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
	Format(query, sizeof(query), "SELECT t1.User, SUM(t2.Points) FROM players AS t1, times AS t2 WHERE t1.PlayerID=t2.PlayerID AND t2.Type=%d AND t2.Style=%d GROUP BY t2.PlayerID ORDER BY SUM(t2.Points) DESC",
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
		Format(title, sizeof(title), "%sRankings %s",
			typeString[Type],
			(Type == TIMER_BONUS)?"":styleString[Style]);
		SetMenuTitle(menu, title);

		for(new itemnum=1; itemnum<=rows; itemnum++)
		{
			SQL_FetchRow(hndl);
			SQL_FetchString(hndl, 0, name, sizeof(name));
			points = SQL_FetchFloat(hndl, 1);
			Format(item, sizeof(item), "#%d: %s - %6.3f", itemnum, name, points);
			AddMenuItem(menu, item, item);
		}
		SetMenuExitBackButton(menu, true);
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
	{
		LogError(error);
	}
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
				if(IsMapValid(mapname))
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
		
		SetMenuExitBackButton(menu, true);
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
	{
		LogError(error);
	}
}

public Menu_ShowMapsleft(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[64];
		GetMenuItem(menu, param2, info, sizeof(info));
		NominateMap(info, false, param1);
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
			
			for(new i=0; i<rows; i++)
			{
				SQL_FetchRow(hndl);
				
				SQL_FetchString(hndl, 0, sMapName, sizeof(sMapName));
				
				AddMenuItem(menu, sMapName, sMapName);
			}
			
			if(client == target)
			{
				SetMenuTitle(menu, "%sYour maps done%s",
					sType[Type+1],
					sStyle[Style+1]);
			}
			else
			{
				decl String:sTargetName[MAX_NAME_LENGTH];
				GetClientName(target, sTargetName, sizeof(sTargetName));
				
				SetMenuTitle(menu, "%sMaps done by %s%s",
					sType[Type+1],
					sTargetName,
					sStyle[Style+1]);
			}
			
			SetMenuExitBackButton(menu, true);
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
}
 
public Menu_ShowMapsdone(Handle:menu, MenuAction:action, param1, param2)
{
        if (action == MenuAction_Select)
        {
			new String:info[64];
			GetMenuItem(menu, param2, info, sizeof(info));
			
			if(g_MapChooser == true)
			{
				NominateMap(info, false, param1);
			}
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

public Native_SetClientRank(Handle:plugin, numParams)
{
	DB_SetClientRank(GetNativeCell(1));
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
	Format(query, sizeof(query), "SELECT User, Playtime, PlayerID FROM players ORDER BY Playtime DESC");
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
		
			decl String:name[MAX_NAME_LENGTH], String:timeformatted[32], time, PlayerID, fTargetPlaytime;
				
			decl String:item[64];
			for(new i=1; i<=rows && i<500; i++)
			{
				SQL_FetchRow(hndl);
				
				SQL_FetchString(hndl, 0, name, sizeof(name));
				time = SQL_FetchInt(hndl, 1);
				
				FormatPlayerTime(float(time), timeformatted, sizeof(timeformatted), false, 1);
				SplitString(timeformatted, ".", timeformatted, sizeof(timeformatted));
				
				Format(item, sizeof(item), "#%d: %s: %s", i, name, timeformatted);
				
				if(i%7 == 0)
					Format(item, sizeof(item), "%s\n--------------------------------------", item);
				else if(i == rows)
					Format(item, sizeof(item), "%s\n--------------------------------------", item);
				
				AddMenuItem(menu, item, item);
				
				PlayerID = SQL_FetchInt(hndl, 2);
				
				if(PlayerID == GetClientID(target))
				{
					fTargetPlaytime = time;
				}
			}
			
			GetClientName(target, name, sizeof(name));
			FormatPlayerTime(GetPlaytime(target)+fTargetPlaytime, timeformatted, sizeof(timeformatted), false, 1);
			SplitString(timeformatted, ".", timeformatted, sizeof(timeformatted));
			
			SetMenuTitle(menu, "Playtimes\n \n%s: %s\n--------------------------------------",
				name,
				timeformatted);
			
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
}