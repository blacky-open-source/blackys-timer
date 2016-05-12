#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "bTimes-cp",
	author = "blacky",
	description = "Checkpoints plugin for the timer",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sdktools>
#include <sourcemod>
#include <bTimes-timer>
#include <bTimes-random>

new Float:g_cp[MAXPLAYERS+1][10][3][3];
new g_cpcount[MAXPLAYERS+1];

new bool:g_UsePos[MAXPLAYERS+1] = {true, ...};
new bool:g_UseVel[MAXPLAYERS+1] = {false, ...};
new bool:g_UseAng[MAXPLAYERS+1] = {false, ...};

new 	g_LastUsed[MAXPLAYERS+1],
	bool:g_HasLastUsed[MAXPLAYERS+1];
	
new 	g_LastSaved[MAXPLAYERS+1],
	bool:g_HasLastSaved[MAXPLAYERS+1];
	
new 	bool:g_BlockTpTo[MAXPLAYERS+1][MAXPLAYERS+1];

new	String:g_msg_start[128],
	String:g_msg_varcol[128],
	String:g_msg_textcol[128];

public OnPluginStart()
{
	RegConsoleCmd("sm_cp", SM_CP, "Opens the checkpoint menu.");
	RegConsoleCmd("sm_checkpoint", SM_CP, "Opens the checkpoint menu.");
	RegConsoleCmd("sm_tele", SM_Tele, "Teleports you to the specified checkpoint.");
	RegConsoleCmd("sm_tp", SM_Tele, "Teleports you to the specified checkpoint.");
	RegConsoleCmd("sm_save", SM_Save, "Saves a new checkpoint.");
	RegConsoleCmd("sm_tpto", SM_TpTo, "Teleports you to a player.");
	
	// Makes FindTarget() work properly
	LoadTranslations("common.phrases");
}

public OnClientPutInServer(client)
{
	g_cpcount[client] = 0;
	
	for(new i=1; i<=MaxClients; i++)
	{
		g_BlockTpTo[i][client] = false;
	}
}

public OnTimerChatChanged(MessageType, String:Message[])
{
	if(MessageType == 0) // msg start
	{
		Format(g_msg_start, sizeof(g_msg_start), Message);
		ReplaceString(g_msg_start, sizeof(g_msg_start), "^", "\x07", false);
	}
	else if(MessageType == 1) // variable color
	{
		Format(g_msg_varcol, sizeof(g_msg_varcol), Message);
		ReplaceString(g_msg_varcol, sizeof(g_msg_varcol), "^", "\x07", false);
	}
	else if(MessageType == 2) // text color
	{
		Format(g_msg_textcol, sizeof(g_msg_textcol), Message);
		ReplaceString(g_msg_textcol, sizeof(g_msg_textcol), "^", "\x07", false);
	}
}

public Action:SM_TpTo(client, args)
{
	if(IsPlayerAlive(client))
	{
		if(args == 0)
		{
			OpenTpToMenu(client);
		}
		else
		{
			decl String:argString[250];
			GetCmdArgString(argString, sizeof(argString));
			new target = FindTarget(client, argString, false, false);
			
			if(client != target)
			{
				if(target != -1)
				{
					if(IsPlayerAlive(target))
					{
						SendTpToRequest(client, target);
					}
					else
					{
						PrintColorText(client, "%s%sTarget not alive.",
							g_msg_start,
							g_msg_textcol);
					}
				}
				else
				{
					OpenTpToMenu(client);
				}
			}
			else
			{
				PrintColorText(client, "%s%sYou can't target yourself.",
					g_msg_start,
					g_msg_textcol);
			}
		}
	}
	else
	{
		PrintColorText(client, "%s%sYou must be alive to use the sm_tpto command.",
			g_msg_start,
			g_msg_textcol);
	}
	return Plugin_Handled;
}

OpenTpToMenu(client)
{
	new Handle:menu = CreateMenu(Menu_Tpto);
	SetMenuTitle(menu, "Select player to teleport to");

	decl String:itargetname[MAX_NAME_LENGTH], String:index[8];
	for(new itarget=1; itarget <= MaxClients; itarget++)
	{
		if(itarget != client && IsClientInGame(itarget))
		{
			if(IsPlayerAlive(itarget))
			{
				GetClientName(itarget, itargetname, sizeof(itargetname));
				IntToString(itarget, index, sizeof(index));
				AddMenuItem(menu, index, itargetname);
			}
		}
	}

	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_Tpto(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		new selection = StringToInt(info);
		for(new target=1; target <= MaxClients; target++)
		{
			if(target == selection)
			{
				if(IsClientInGame(target))
				{
					if(IsPlayerAlive(target))
					{
						if(IsPlayerAlive(param1))
						{
							SendTpToRequest(param1, target);
						}
						else
						{
							PrintColorText(param1, "%s%sYou must be alive to use the sm_tpto command.",
								g_msg_start,
								g_msg_textcol);
						}
					}
					else
					{
						PrintColorText(param1, "%s%sTarget not alive.",
							g_msg_start,
							g_msg_textcol);
					}
				}
				else
				{
					PrintColorText(param1, "%s%sTarget not in game.",
						g_msg_start,
						g_msg_textcol);
				}
			}
		}	
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

SendTpToRequest(client, target)
{
	if(g_BlockTpTo[target][client] == false)
	{
		new Handle:menu = CreateMenu(Menu_TpRequest);
		
		decl String:sClient[8], String:sInfo[10], String:sClientName[MAX_NAME_LENGTH];
		IntToString(client, sClient, sizeof(sClient));
		GetClientName(client, sClientName, sizeof(sClientName));
		
		SetMenuTitle(menu, "%s wants to teleport to you", sClientName);
		
		Format(sInfo, sizeof(sInfo), "%saccept", sClient);
		AddMenuItem(menu, sInfo, "Accept");
		
		Format(sInfo, sizeof(sInfo), "%sdeny", sClient);
		AddMenuItem(menu, sInfo, "Deny");
		
		Format(sInfo, sizeof(sInfo), "%sblock", sClient);
		AddMenuItem(menu, sInfo, "Deny & Block");
		
		DisplayMenu(menu, target, 20);
	}
	else
	{
		decl String:sTargetName[MAX_NAME_LENGTH];
		GetClientName(target, sTargetName, sizeof(sTargetName));
		
		PrintColorText(client, "%s%s %s %sblocked all tpto requests from you.",
			g_msg_start,
			g_msg_varcol,
			sTargetName,
			g_msg_textcol);
	}
}

public Menu_TpRequest(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[32], String:sTarget[MAX_NAME_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));
		GetClientName(param1, sTarget, sizeof(sTarget));
		
		new client;
		if(StrContains(info, "accept") != -1) // accept
		{
			SplitString(info, "accept", info, sizeof(info));
			client = StringToInt(info);
			
			if(IsClientInGame(client) && IsClientInGame(param1))
			{
				new Float:pos[3];
				GetEntPropVector(param1, Prop_Send, "m_vecOrigin", pos);
				
				StopTimer(client);
				TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
				
				PrintColorText(client, "%s%s%s %saccepted your request.",
					g_msg_start,
					g_msg_varcol,
					sTarget,
					g_msg_textcol);
			}
		}
		else if(StrContains(info, "deny") != -1) // deny
		{
			SplitString(info, "deny", info, sizeof(info));
			client = StringToInt(info);
			
			PrintColorText(client, "%s%s%s %sdenied your request.",
				g_msg_start,
				g_msg_varcol,
				sTarget,
				g_msg_textcol);
		}
		else if(StrContains(info, "block") != -1) // deny and block
		{
			SplitString(info, "block", info, sizeof(info));
			client = StringToInt(info);
			
			g_BlockTpTo[param1][client] = true;
			PrintColorText(client, "%s%s%s %sdenied denied your request and blocked future requests from you.",
				g_msg_start,
				g_msg_varcol,
				sTarget,
				g_msg_textcol);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_CP(client, args)
{
	OpenCheckpointMenu(client);
	return Plugin_Handled;
}

OpenCheckpointMenu(client)
{
	new Handle:menu = CreateMenu(Menu_Checkpoint);
	
	SetMenuTitle(menu, "Checkpoint menu");
	AddMenuItem(menu, "Save", "Save");
	AddMenuItem(menu, "Teleport", "Teleport");
	AddMenuItem(menu, "Delete", "Delete");
	AddMenuItem(menu, "usepos", g_UsePos[client]?"Use position: Yes":"Use position: No");
	AddMenuItem(menu, "usevel", g_UseVel[client]?"Use velocity: Yes":"Use velocity: No");
	AddMenuItem(menu, "useang", g_UseAng[client]?"Use angles: Yes":"Use angles: No");
	AddMenuItem(menu, "Noclip", "Noclip");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_Checkpoint(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrEqual(info, "Save"))
		{
			SaveCheckpoint(param1);
			OpenCheckpointMenu(param1);
		}
		else if(StrEqual(info, "Teleport"))
		{
			OpenTeleportMenu(param1);
		}
		else if(StrEqual(info, "Delete"))
		{
			OpenDeleteMenu(param1);
		}
		else if(StrEqual(info, "usepos"))
		{
			g_UsePos[param1] = !g_UsePos[param1];
			OpenCheckpointMenu(param1);
		}
		else if(StrEqual(info, "usevel"))
		{
			g_UseVel[param1] = !g_UseVel[param1];
			OpenCheckpointMenu(param1);
		}
		else if(StrEqual(info, "useang"))
		{
			g_UseAng[param1] = !g_UseAng[param1];
			OpenCheckpointMenu(param1);
		}
		else if(StrEqual(info, "Noclip"))
		{
			FakeClientCommand(param1, "sm_practice");
			OpenCheckpointMenu(param1);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

OpenTeleportMenu(client)
{
	new Handle:menu = CreateMenu(Menu_Teleport);
	SetMenuTitle(menu, "Teleport");
	AddMenuItem(menu, "lastused", "Last used");
	AddMenuItem(menu, "lastsaved", "Last saved");
	
	decl String:tpString[8], String:infoString[8];
	for(new i=0; i < g_cpcount[client]; i++)
	{
		Format(tpString, sizeof(tpString), "CP %d", i+1);
		Format(infoString, sizeof(infoString), "%d", i);
		AddMenuItem(menu, infoString, tpString);
	}
	
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_Teleport(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrEqual(info, "lastused"))
		{
			TeleportToLastUsed(param1);
			OpenTeleportMenu(param1);
		}
		else if(StrEqual(info, "lastsaved"))
		{
			TeleportToLastSaved(param1);
			OpenTeleportMenu(param1);
		}
		else
		{
			decl String:infoGuess[8];
			for(new i=0; i < g_cpcount[param1]; i++)
			{
				Format(infoGuess, sizeof(infoGuess), "%d", i);
				if(StrEqual(info, infoGuess))
				{
					TeleportToCheckpoint(param1, i);
					OpenTeleportMenu(param1);
					break;
				}
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			OpenCheckpointMenu(param1);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

OpenDeleteMenu(client)
{
	new Handle:menu = CreateMenu(Menu_Delete);
	SetMenuTitle(menu, "Delete");
	
	decl String:display[16], String:info[8];
	if(g_cpcount[client] != 0)
	{
		for(new i=0; i < g_cpcount[client]; i++)
		{
			Format(display, sizeof(display), "Delete %d", i+1);
			IntToString(i, info, sizeof(info));
			AddMenuItem(menu, info, display);
		}
	}
	else
	{
		PrintColorText(client, "%s%sYou have no checkpoints saved.",
			g_msg_start,
			g_msg_textcol);
		OpenCheckpointMenu(client);
	}
	
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_Delete(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		decl String:infoString[8];
		for(new i=0; i < g_cpcount[param1]; i++)
		{
			IntToString(i, infoString, sizeof(infoString));
			if(StrEqual(info, infoString))
			{
				DeleteCheckpoint(param1, i);
				OpenDeleteMenu(param1);
				break;
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			OpenCheckpointMenu(param1);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
	
}

public Action:SM_Tele(client, args)
{
	if(args != 0)
	{
		decl String:ArgString[255];
		GetCmdArgString(ArgString, sizeof(ArgString));
		
		new cpnum = StringToInt(ArgString)-1;
		TeleportToCheckpoint(client, cpnum);
	}
	else
	{
		PrintToChat(client, "[SM] Usage: sm_tele <Checkpoint number>");
	}
	return Plugin_Handled;
}

public Action:SM_Save(client, argS)
{
	SaveCheckpoint(client);
	return Plugin_Handled;
}

SaveCheckpoint(client)
{
	if(g_cpcount[client] < 10)
	{
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_cp[client][g_cpcount[client]][0]);
		g_cp[client][g_cpcount[client]][1][0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
		g_cp[client][g_cpcount[client]][1][1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
		g_cp[client][g_cpcount[client]][1][2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
		GetClientEyeAngles(client, g_cp[client][g_cpcount[client]][2]);
		
		g_HasLastSaved[client] = true;
		g_LastSaved[client] = g_cpcount[client];
		
		g_cpcount[client]++;
		
		PrintColorText(client, "%s%sCheckpoint %s%d%s saved.", 
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_cpcount[client],
			g_msg_textcol);
	}
	else
	{
		PrintColorText(client, "%s%sYou have too many checkpoints.",
			g_msg_start,
			g_msg_textcol);
	}
}

DeleteCheckpoint(client, cpnum)
{
	if(0 <= cpnum <= g_cpcount[client])
	{
		for(new i=cpnum+1; i<10; i++)
			for(new i2=0; i2<3; i2++)
				for(new i3=0; i3<3; i3++)
					g_cp[client][i-1][i2][i3] = g_cp[client][i][i2][i3];
		g_cpcount[client]--;
		
		if(cpnum == g_LastUsed[client] || g_cpcount[client] < g_LastUsed[client])
			g_HasLastUsed[client] = false;
		else if(cpnum < g_LastUsed[client])
			g_LastUsed[client]--;
		
		if(cpnum == g_LastSaved[client] || g_cpcount[client] < g_LastSaved[client])
			g_HasLastSaved[client] = false;
		else if(cpnum < g_LastSaved[client])
			g_LastSaved[client]--;
			
	}
	else
	{
		PrintColorText(client, "%s%sCheckpoint %s%d%s doesn't exist", 
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			cpnum+1,
			g_msg_textcol);
	}
}

TeleportToCheckpoint(client, cpnum)
{
	if(0 <= cpnum < g_cpcount[client])
	{
		StopTimer(client);
		if(g_UsePos[client])
			TeleportEntity(client, g_cp[client][cpnum][0], NULL_VECTOR, NULL_VECTOR);
		if(g_UseVel[client])
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, g_cp[client][cpnum][1]);
		if(g_UseAng[client])
			TeleportEntity(client, NULL_VECTOR, g_cp[client][cpnum][2], NULL_VECTOR);
		
		g_HasLastUsed[client] = true;
		g_LastUsed[client] = cpnum;
	}
	else
	{
		PrintColorText(client, "%s%sCheckpoint %s%d%s doesn't exist", 
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			cpnum+1,
			g_msg_textcol);
	}
}

TeleportToLastUsed(client)
{
	if(g_HasLastUsed[client] == true)
		TeleportToCheckpoint(client, g_LastUsed[client]);
	else
		PrintColorText(client, "%s%sYou have no last used checkpoint.",
			g_msg_start,
			g_msg_textcol);
}

TeleportToLastSaved(client)
{
	if(g_HasLastSaved[client] == true)
		TeleportToCheckpoint(client, g_LastSaved[client]);
	else
		PrintColorText(client, "%s%sYou have no last saved checkpoint.",
			g_msg_start,
			g_msg_textcol);
}