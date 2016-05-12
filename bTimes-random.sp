#pragma semicolon 1

#include <bTimes-core>

public Plugin:myinfo = 
{
	name = "[bTimes] random",
	author = "blacky",
	description = "Handles events and modifies them to fit bTimes' needs",
	version = VERSION,
	url = "http://steamcommunity.com/id/blaackyy/"
}

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <bTimes-timer>
#include <bTimes-zones>
#include <bTimes-random>
#include <clientprefs>

#define HUD_OFF (1<<0|1<<3|1<<4|1<<8)
#define HUD_ON  0
#define HUD_FUCK (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9|1<<10|1<<11)
 
new	g_Settings[MAXPLAYERS+1] = {SHOW_HINT, ...},
	g_bHooked;
	
new 	Float:g_fMapStart;
	
new 	Handle:g_hSettingsCookie;

new 	g_iSoundEnts[2048];
new 	g_iNumSounds;

// Settings
new 	Handle:g_AllowAuto,
	Handle:g_hAllowKeysAlive,
	Handle:g_hKeysShowsJumps,
	Handle:g_hAllowKnifeDrop,
	Handle:g_WeaponDespawn,
	Handle:g_hAutoStopsTimer;
	
new	Handle:g_MessageStart,
	Handle:g_MessageVar,
	Handle:g_MessageText,
	Handle:g_fwdChatChanged;
	
new 	String:g_msg_start[128] = {""};
new 	String:g_msg_varcol[128] = {"\x07B4D398"};
new 	String:g_msg_textcol[128] = {"\x01"};
 
public OnPluginStart()
{
	// Server settings
	g_AllowAuto 		= CreateConVar("timer_allowauto", "1", "Allows players to use auto bunnyhop.", 0, true, 0.0, true, 1.0);
	g_hAllowKeysAlive	= CreateConVar("timer_allowkeysalive", "1", "Allows players to see !keys while alive.", 0, true, 0.0, true, 1.0);
	g_hKeysShowsJumps	= CreateConVar("timer_keysshowsjumps", "1", "The !keys features shows when a player is using their jump button.", 0, true, 0.0, true, 1.0);
	g_hAllowKnifeDrop = CreateConVar("timer_allowknifedrop", "1", "Allows players to drop any weapons (including knives and grenades)", 0, true, 0.0, true, 1.0);
	g_WeaponDespawn	= CreateConVar("timer_weapondespawn", "1", "Kills weapons a second after spawning to prevent flooding server.", 0, true, 0.0, true, 1.0);
	g_MessageStart	= CreateConVar("timer_msgstart", "^556b2f[Timer] ^daa520- ", "Sets the start of all timer messages.");
	g_MessageVar		= CreateConVar("timer_msgvar", "^B4D398", "Sets the color of variables in timer messages such as player names.");
	g_MessageText		= CreateConVar("timer_msgtext", "^daa520", "Sets the color of general text in timer messages.");
	g_hAutoStopsTimer	= CreateConVar("timer_autostopstimer", "0", "Players can't get times with autohop on.");
	
	// Hook specific convars
	HookConVarChange(g_MessageStart, OnMessageStartChanged);
	HookConVarChange(g_MessageVar, OnMessageVarChanged);
	HookConVarChange(g_MessageText, OnMessageTextChanged);
	HookConVarChange(g_hAutoStopsTimer, OnAutoStopsTimerChanged);
	
	// Create config file if it doesn't exist
	AutoExecConfig(true, "random", "timer");
	
	// Event hooks
	HookEvent("player_spawn", Event_PlayerSpawn_Pre, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn_Post, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	AddNormalSoundHook(NormalSHook);
	AddAmbientSoundHook(AmbientSHook);
	AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);
	
	// Command hooks
	AddCommandListener(DropItem, "drop");
	
	// Player commands
	RegConsoleCmdEx("sm_auto", SM_Auto, "Toggles auto bunnyhop");
	RegConsoleCmdEx("sm_autobhop", SM_Auto, "Toggles auto bunnyhop");
	RegConsoleCmdEx("sm_bhop", SM_Auto, "Toggles auto bunnyhop");
	RegConsoleCmdEx("sm_hide", SM_Hide, "Toggles hide");
	RegConsoleCmdEx("sm_unhide", SM_Hide, "Toggles hide");
	RegConsoleCmdEx("sm_keys", SM_Keys, "Toggles showing pressed keys");
	RegConsoleCmdEx("sm_pad", SM_Keys, "Toggles showing pressed keys");
	RegConsoleCmdEx("sm_showkeys", SM_Keys, "Toggles showing pressed keys");
	RegConsoleCmdEx("sm_spec", SM_Spec, "Be a spectator");
	RegConsoleCmdEx("sm_spectate", SM_Spec, "Be a spectator");
	RegConsoleCmdEx("sm_maptime", SM_Maptime, "Shows how long the current map has been on.");
	RegConsoleCmdEx("sm_sound", SM_Sound, "Choose different sounds to stop when they play.");
	RegConsoleCmdEx("sm_specinfo", SM_Specinfo, "Shows who is spectating you.");
	RegConsoleCmdEx("sm_specs", SM_Specinfo, "Shows who is spectating you.");
	RegConsoleCmdEx("sm_speclist", SM_Specinfo, "Shows who is spectating you.");
	RegConsoleCmdEx("sm_normalspeed", SM_Normalspeed, "Sets your speed to normal speed.");
	RegConsoleCmdEx("sm_speed", SM_Speed, "Changes your speed to the specified value.");
	RegConsoleCmdEx("sm_setspeed", SM_Speed, "Changes your speed to the specified value.");
	RegConsoleCmdEx("sm_slow", SM_Slow, "Sets your speed to slow (0.5)");
	RegConsoleCmdEx("sm_fast", SM_Fast, "Sets your speed to fast (2.0)");
	RegConsoleCmdEx("sm_lowgrav", SM_Lowgrav, "Lowers your gravity.");
	RegConsoleCmdEx("sm_normalgrav", SM_Normalgrav, "Sets your gravity to normal.");
	
	// Admin commands
	RegAdminCmd("sm_move", SM_Move, ADMFLAG_KICK, "For getting players out of places they are stuck in");
	RegAdminCmd("sm_hudfuck", SM_Hudfuck, ADMFLAG_SLAY, "Removes a player's hud so they can only leave the server/game through task manager (Use only on players who deserve it)");
	
	// Client settings
	g_hSettingsCookie = RegClientCookie("timer", "Timer settings", CookieAccess_Public);
	
	// Makes FindTarget() work properly..
	LoadTranslations("common.phrases");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	// Native functions
	CreateNative("GetClientSettings", Native_GetClientSettings);
	CreateNative("SetClientSettings", Native_SetClientSettings);
	
	// Forwards
	g_fwdChatChanged = CreateGlobalForward("OnTimerChatChanged", ET_Event, Param_Cell, Param_String);
	
	return APLRes_Success;
}

public OnMapStart()
{
	//set map start time
	g_fMapStart = GetEngineTime();
}

public OnClientPutInServer(client)
{
	// for !hide
	SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
	
	// prevents damage
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public OnClientDisconnect_Post(client)
{
	CheckHooks();
}

public OnClientCookiesCached(client)
{	
	// get client settings
	decl String:cookies[16];
	GetClientCookie(client, g_hSettingsCookie, cookies, sizeof(cookies));
	
	if(strlen(cookies) == 0)
	{
		g_Settings[client] = SHOW_HINT|AUTO_BHOP|KH_TIMELEFT|KH_SYNC|KH_RECORD|KH_BEST|KH_SPECS;
	}
	else
	{
		g_Settings[client] = StringToInt(cookies);
	}
}

public OnConfigsExecuted()
{
	// load timer message colors
	GetConVarString(g_MessageStart, g_msg_start, sizeof(g_msg_start));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(0);
	Call_PushString(g_msg_start);
	Call_Finish();
	ReplaceString(g_msg_start, sizeof(g_msg_start), "^", "\x07", false);
	
	GetConVarString(g_MessageVar, g_msg_varcol, sizeof(g_msg_varcol));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(1);
	Call_PushString(g_msg_varcol);
	Call_Finish();
	ReplaceString(g_msg_varcol, sizeof(g_msg_varcol), "^", "\x07", false);
	
	GetConVarString(g_MessageText, g_msg_textcol, sizeof(g_msg_textcol));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(2);
	Call_PushString(g_msg_textcol);
	Call_Finish();
	ReplaceString(g_msg_textcol, sizeof(g_msg_textcol), "^", "\x07", false);
}

public OnMessageStartChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarString(g_MessageStart, g_msg_start, sizeof(g_msg_start));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(0);
	Call_PushString(g_msg_start);
	Call_Finish();
	ReplaceString(g_msg_start, sizeof(g_msg_start), "^", "\x07", false);
}

public OnMessageVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarString(g_MessageVar, g_msg_varcol, sizeof(g_msg_varcol));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(1);
	Call_PushString(g_msg_varcol);
	Call_Finish();
	ReplaceString(g_msg_varcol, sizeof(g_msg_varcol), "^", "\x07", false);
}

public OnMessageTextChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarString(g_MessageText, g_msg_textcol, sizeof(g_msg_textcol));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(2);
	Call_PushString(g_msg_textcol);
	Call_Finish();
	ReplaceString(g_msg_textcol, sizeof(g_msg_textcol), "^", "\x07", false);
}

public OnAutoStopsTimerChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(StringToInt(newValue) == 1)
	{
		for(new client=1; client<=MaxClients; client++)
		{
			if(IsClientInGame(client) && IsBeingTimed(client, TIMER_ANY) && g_Settings[client] & AUTO_BHOP)
			{
				StopTimer(client);
			}
		}
	}
}

public Action:Timer_StopMusic(Handle:timer, any:data)
{
	new ientity, String:sSound[128];
	for (new i = 0; i < g_iNumSounds; i++)
	{
		ientity = EntRefToEntIndex(g_iSoundEnts[i]);
		
		if (ientity != INVALID_ENT_REFERENCE)
		{
			for(new client=1; client<=MaxClients; client++)
			{
				if(IsClientInGame(client))
				{
					if(g_Settings[client] & STOP_MUSIC)
					{
						GetEntPropString(ientity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
						EmitSoundToClient(client, sSound, ientity, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
					}
				}
			}
		}
	}
}

public Action:CSS_Hook_ShotgunShot(const String:te_name[], const Players[], numClients, Float:delay)
{
	if(!g_bHooked)
		return Plugin_Continue;
	
	// Check which clients need to be excluded.
	decl newClients[MaxClients], client, i;
	new newTotal = 0;
	
	for (i = 0; i < numClients; i++)
	{
		client = Players[i];
		
		if (!(g_Settings[client] & STOP_GUNS))
		{
			newClients[newTotal++] = client;
		}
	}
	
	// No clients were excluded.
	if (newTotal == numClients)
		return Plugin_Continue;
	
	// All clients were excluded and there is no need to broadcast.
	else if (newTotal == 0)
		return Plugin_Stop;
	
	// Re-broadcast to clients that still need it.
	decl Float:vTemp[3];
	TE_Start("Shotgun Shot");
	TE_ReadVector("m_vecOrigin", vTemp);
	TE_WriteVector("m_vecOrigin", vTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_iWeaponID", TE_ReadNum("m_iWeaponID"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
	TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
	TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
	TE_Send(newClients, newTotal, delay);
	
	return Plugin_Stop;
}

CheckHooks()
{
	new bool:bShouldHook = false;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if (g_Settings[i] & STOP_GUNS)
			{
				bShouldHook = true;
				break;
			}
		}
	}
	
	// Fake (un)hook because toggling actual hooks will cause server instability.
	g_bHooked = bShouldHook;
}

public Action:AmbientSHook(String:sample[PLATFORM_MAX_PATH], &entity, &Float:volume, &level, &pitch, Float:pos[3], &flags, &Float:delay)
{
	// Stop music
	CreateTimer(0.1, Timer_StopMusic);
}
 
public Action:NormalSHook(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	decl String:sClassName[128];
	GetEntityClassname(entity, sClassName, sizeof(sClassName));
	
	new iSoundType;
	if(StrEqual(sClassName, "func_door"))
		iSoundType = STOP_DOORS;
	else if(strncmp(sample, "weapons", 7) == 0 || strncmp(sample[1], "weapons", 7) == 0)
		iSoundType = STOP_GUNS;
	else
		return Plugin_Continue;

	for (new i = 0; i < numClients; i++)
	{
		if(g_Settings[clients[i]] & iSoundType)
		{
			// Remove the client from the array.
			for (new j = i; j < numClients-1; j++)
			{
				clients[j] = clients[j+1];
			}
			numClients--;
			i--;
		}
	}
	
	return (numClients > 0) ? Plugin_Changed : Plugin_Stop;
}

public OnEntityCreated(entity, const String:classname[])
{
	if(GetConVarBool(g_WeaponDespawn) == true)
	{
		if(IsValidEdict(entity) && IsValidEntity(entity))
		{
			CreateTimer(1.0, KillEntity, EntIndexToEntRef(entity));
		}
	}
}

public Action:OnTimerStart_Pre(client, Type, Style)
{
	if(g_Settings[client] & AUTO_BHOP && GetConVarBool(g_hAutoStopsTimer))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
 
public Action:KillEntity(Handle:timer, any:ref)
{
	// anti-weapon spam
	new ent = EntRefToEntIndex(ref);
	if(IsValidEdict(ent) && IsValidEntity(ent))
	{
		decl String:entClassname[128];
		GetEdictClassname(ent, entClassname, sizeof(entClassname));
		if(StrContains(entClassname, "weapon_") != -1 || StrContains(entClassname, "item_") != -1)
		{
			new m_hOwnerEntity = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
			if(m_hOwnerEntity == -1)
				AcceptEntityInput(ent, "Kill");
		}
	}
}
 
public Action:Event_PlayerSpawn_Pre(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	StopTimer(client);
}
 
public Action:Event_PlayerSpawn_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// no block
	SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
	
	return Plugin_Continue;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Ents are recreated every round.
	g_iNumSounds = 0;
	
	// Find all ambient sounds played by the map.
	decl String:sSound[PLATFORM_MAX_PATH];
	new entity = INVALID_ENT_REFERENCE;
	
	while ((entity = FindEntityByClassname(entity, "ambient_generic")) != INVALID_ENT_REFERENCE)
	{
		GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
		
		new len = strlen(sSound);
		if (len > 4 && (StrEqual(sSound[len-3], "mp3") || StrEqual(sSound[len-3], "wav")))
		{
			g_iSoundEnts[g_iNumSounds++] = EntIndexToEntRef(entity);
		}
	}
}

// drop any weapon
public Action:DropItem(client, const String:command[], argc)
{
	// Allow ghosts to drop all weapons and allow players if the cvar allows them to
	if(GetConVarBool(g_hAllowKnifeDrop) || IsFakeClient(client))
	{
		new weaponIndex = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		
		if(weaponIndex != -1)
		{
			CS_DropWeapon(client, weaponIndex, true, false);
		}
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
 
// kill weapon and weapon attachments on drop
public Action:CS_OnCSWeaponDrop(client, weaponIndex)
{
	if(weaponIndex != -1)
	{
		AcceptEntityInput(weaponIndex, "KillHierarchy");
		AcceptEntityInput(weaponIndex, "Kill");
	}
}

// Auto bhop
public Action:SM_Auto(client, args)
{
	if(GetConVarBool(g_AllowAuto) == true)
	{
		if (args < 1)
		{
			g_Settings[client] ^= AUTO_BHOP;
			
			if(GetConVarBool(g_hAutoStopsTimer))
				StopTimer(client);
			
			if (g_Settings[client] & AUTO_BHOP)
			{
				PrintColorText(client, "%s%sAuto bhop %senabled",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol);
			}
			else
			{
				PrintColorText(client, "%s%sAuto bhop %sdisabled",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol);
			}
				
			if(AreClientCookiesCached(client))
			{
				decl String:sAutoCookie[16];
				IntToString(g_Settings[client], sAutoCookie, sizeof(sAutoCookie));
				SetClientCookie(client, g_hSettingsCookie, sAutoCookie);
			}
		}
		else if (args == 1)
		{
			decl String:TargetArg[128];
			GetCmdArgString(TargetArg, sizeof(TargetArg));
			new TargetID = FindTarget(client, TargetArg, true, false);
			if(TargetID != -1)
			{
				decl String:TargetName[128];
				GetClientName(TargetID, TargetName, sizeof(TargetName));
				if (g_Settings[TargetID] & AUTO_BHOP)
				{
					PrintColorText(client, "%s%sPlayer %s%s%s has auto bhop %senabled",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						TargetName,
						g_msg_textcol,
						g_msg_varcol);
				}
				else
				{
					PrintColorText(client, "%s%sPlayer %s%s%s has auto bhop %sdisabled",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						TargetName,
						g_msg_textcol,
						g_msg_varcol);
				}
			}
		}
	}
	return Plugin_Handled;
}

// Tells a player who is spectating them
public Action:SM_Specinfo(client, args)
{
	if(IsPlayerAlive(client))
	{
		ShowSpecinfo(client, client);
	}
	else
	{
		new Target 	 = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
			
		if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
		{
			ShowSpecinfo(client, Target);
		}
		else
		{
			PrintColorText(client, "%s%sYou are not spectating anyone.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	return Plugin_Handled;
}

ShowSpecinfo(client, target)
{
	decl String:sNames[MaxClients][MAX_NAME_LENGTH];
	new index;
	new bool:bClientHasAdmin = GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective);
	
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(!bClientHasAdmin && GetAdminFlag(GetUserAdmin(i), Admin_Generic, Access_Effective))
			{
				continue;
			}
				
			if(!IsPlayerAlive(i))
			{
				new iTarget 	 = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
				new ObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
				
				if((ObserverMode == 4 || ObserverMode == 5) && (iTarget == target))
				{
					GetClientName(i, sNames[index++], MAX_NAME_LENGTH);
				}
			}
		}
	}
	
	decl String:sTarget[MAX_NAME_LENGTH];
	GetClientName(target, sTarget, sizeof(sTarget));
	
	if(index != 0)
	{
		new Handle:menu = CreatePanel();
		
		decl String:sTitle[64];
		Format(sTitle, sizeof(sTitle), "Spectating %s", sTarget);
		DrawPanelText(menu, sTitle);
		DrawPanelText(menu, " ");
		
		for(new i=0; i<index; i++)
		{
			DrawPanelText(menu, sNames[i]);
		}
		
		DrawPanelText(menu, " ");
		DrawPanelText(menu, "0. Close");
		
		SendPanelToClient(menu, client, Menu_SpecInfo, 10);
	}
	else
	{
		PrintColorText(client, "%s%s%s%s has no spectators.",
			g_msg_start,
			g_msg_varcol,
			sTarget,
			g_msg_textcol);
	}
}

public Menu_SpecInfo(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_End)
		CloseHandle(menu);
}

// Hide other players
public Action:SM_Hide(client, args)
{
	g_Settings[client] ^= HIDE_PLAYERS;
	
	if(g_Settings[client] & HIDE_PLAYERS)
	{
		PrintColorText(client, "%s%sPlayers are now %sinvisible",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol);
	}
	else
	{
		PrintColorText(client, "%s%sPlayers are now %svisible",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol);
	}
	
	// Save cookies
	if(AreClientCookiesCached(client))
	{
		decl String:sHideCookie[16];
		IntToString(g_Settings[client], sHideCookie, sizeof(sHideCookie));
		SetClientCookie(client, g_hSettingsCookie, sHideCookie);
	}
	return Plugin_Handled;
}

// Spectate command
public Action:SM_Spec(client, args)
{
	StopTimer(client);
	ForcePlayerSuicide(client);
	ChangeClientTeam(client, 1);
	if(args != 0)
	{
		decl String:arg[128];
		GetCmdArgString(arg, sizeof(arg));
		new target = FindTarget(client, arg, true, false);
		if(target != -1)
		{
			if(client != target)
			{
				if(IsPlayerAlive(target))
				{
					SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", target);
				}
				else
				{
					decl String:name[MAX_NAME_LENGTH];
					GetClientName(target, name, sizeof(name));
					PrintColorText(client, "%s%s%s %sis not alive.", 
						g_msg_start,
						g_msg_varcol,
						name,
						g_msg_textcol);
				}
			}
			else
			{
				PrintColorText(client, "%s%sYou can't spectate yourself.",
					g_msg_start,
					g_msg_textcol);
			}
		}
	}
	return Plugin_Handled;
}

// Move stuck players
public Action:SM_Move(client, args)
{
	if(args != 0)
	{
		decl String:name[MAX_NAME_LENGTH];
		GetCmdArgString(name, sizeof(name));
		
		new Target = FindTarget(client, name, true, false);
		
		if(Target != -1)
		{
			new Float:angles[3], Float:pos[3];
			GetClientEyeAngles(Target, angles);
			GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);
			GetEntPropVector(Target, Prop_Send, "m_vecOrigin", pos);
			
			for(new i=0; i<3; i++)
				pos[i] += (angles[i] * 50);
			
			TeleportEntity(Target, pos, NULL_VECTOR, NULL_VECTOR);
			
			decl String:clientname[MAX_NAME_LENGTH], String:targetname[MAX_NAME_LENGTH];
			GetClientName(client, clientname, sizeof(clientname));
			GetClientName(Target, targetname, sizeof(targetname));
			
			LogMessage("%s moved %s", clientname, targetname);
		}
	}
	else
	{
		PrintToChat(client, "[SM] Usage: sm_move <target>");
	}
	return Plugin_Handled;
}

// Punish players
public Action:SM_Hudfuck(client, args)
{
	decl String:arg[250];
	GetCmdArgString(arg, sizeof(arg));
	
	new target = FindTarget(client, arg, false, false);
	
	if(target != -1)
	{
		SetEntProp(target, Prop_Send, "m_iHideHUD", HUD_FUCK);
		
		decl String:targetname[MAX_NAME_LENGTH];
		GetClientName(target, targetname, sizeof(targetname));
		PrintColorTextAll("%s%s%s %shas been HUD-FUCKED for their negative actions", 
			g_msg_start,
			g_msg_varcol,
			targetname,
			g_msg_textcol);
		
		// Log the hudfuck event
		decl String:sName[MAX_NAME_LENGTH], String:sAuth[32], String:sTargetAuth[32];
		GetClientName(client, sName, sizeof(sName));
		GetClientAuthString(client, sAuth, sizeof(sAuth));
		GetClientAuthString(target, sTargetAuth, sizeof(sTargetAuth));
		
		LogMessage("%s <%s> executed sm_hudfuck command on %s <%s>", sName, sAuth, targetname, sTargetAuth);
	}
	else
	{
		new Handle:menu = CreateMenu(Menu_HudFuck);
		SetMenuTitle(menu, "Select player to HUD FUCK");
		
		decl String:itargetname[MAX_NAME_LENGTH], String:authid[32], String:display[64], String:index[8];
		for(new itarget=1; itarget <= MaxClients; itarget++)
		{
			if(IsClientInGame(itarget))
			{
				GetClientName(itarget, itargetname, sizeof(itargetname));
				GetClientAuthString(itarget, authid, sizeof(authid));
				Format(display, sizeof(display), "%s <%s>", itargetname, authid);
				IntToString(itarget, index, sizeof(index));
				AddMenuItem(menu, index, display);
			}
		}
		
		SetMenuExitBackButton(menu, true);
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public Menu_HudFuck(Handle:menu, MenuAction:action, param1, param2)
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
					decl String:name[MAX_NAME_LENGTH];
					GetClientName(target, name, sizeof(name));
					PrintToChatAll(name);
					SetEntProp(target, Prop_Send, "m_iHideHUD", HUD_FUCK);
				}
				else
				{
					PrintColorText(param1, "%s%s Target not in game",
						g_msg_start,
						g_msg_textcol);
				}
			}
		}	
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

// Display current map session time
public Action:SM_Maptime(client, args)
{
	new Float:mapTime = GetEngineTime() - g_fMapStart;
	new hours, minutes, seconds;
	hours    = RoundToFloor(mapTime/3600);
	mapTime -= (hours * 3600);
	minutes  = RoundToFloor(mapTime/60);
	mapTime -= (minutes * 60);
	seconds  = RoundToFloor(mapTime);
	
	PrintColorText(client, "%sMaptime: %s%d%s %s, %s%d%s %s, %s%d%s %s", 
		g_msg_textcol,
		g_msg_varcol,
		hours,
		g_msg_textcol,
		(hours==1)?"hour":"hours", 
		g_msg_varcol,
		minutes,
		g_msg_textcol,
		(minutes==1)?"minute":"minutes", 
		g_msg_varcol,
		seconds, 
		g_msg_textcol,
		(seconds==1)?"second":"seconds");
}

// Show player key presses
public Action:SM_Keys(client, args)
{
	g_Settings[client] ^= SHOW_KEYS;
	if(g_Settings[client] & SHOW_KEYS)
	{
		PrintColorText(client, "%s%sShowing key presses",
			g_msg_start,
			g_msg_textcol);
	}
	else
	{
		PrintCenterText(client, "");
		
		PrintColorText(client, "%s%sNo longer showing key presses",
			g_msg_start,
			g_msg_textcol);
	}
		
	if(AreClientCookiesCached(client))
	{
		decl String:sKeysCookie[16];
		IntToString(g_Settings[client], sKeysCookie, sizeof(sKeysCookie));
		SetClientCookie(client, g_hSettingsCookie, sKeysCookie);
	}
	return Plugin_Handled;
}

GetKeysMessage(client, String:sKeys[], maxlen)
{
	new buttons = GetClientButtons(client);
	
	new String:sForward[1], String:sBack[1], String:sMoveleft[2], String:sMoveright[2];
	if(buttons & IN_FORWARD)
		sForward[0] = 'W';
	else
		sForward[0] = 32;
		
	if(buttons & IN_MOVELEFT)
	{
		sMoveleft[0] = 'A';
		sMoveleft[1] = 0;
	}
	else
	{
		sMoveleft[0] = 32;
		sMoveleft[1] = 32;
	}
	
	if(buttons & IN_MOVERIGHT)
	{
		sMoveright[0] = 'D';
		sMoveright[1] = 0;
	}
	else
	{
		sMoveright[0] = 32;
		sMoveright[1] = 32;
	}
	
	if(buttons & IN_BACK)
		sBack[0] = 'S';
	else
		sBack[0] = 32;
	
	Format(sKeys, maxlen, "   %s\n%s     %s\n    %s", sForward, sMoveleft, sMoveright, sBack);
	
	if(buttons & IN_DUCK)
		Format(sKeys, maxlen, "%s\nDUCK", sKeys);
	else
		Format(sKeys, maxlen, "%s\n ", sKeys);
		
	if(GetConVarBool(g_hKeysShowsJumps))
	{
		if(buttons & IN_JUMP)
			Format(sKeys, maxlen, "%s\nJUMP", sKeys);
		else
			Format(sKeys, maxlen, "%s\n ", sKeys);
	}
}

// Open sound control menu
public Action:SM_Sound(client, args)
{
	new Handle:menu = CreateMenu(Menu_StopSound);
	SetMenuTitle(menu, "Control Sounds");
	
	decl String:info[16];
	IntToString(STOP_DOORS, info, sizeof(info));
	AddMenuItem(menu, info, (g_Settings[client] & STOP_DOORS)?"Door sounds: Off":"Door sounds: On");
	
	IntToString(STOP_GUNS, info, sizeof(info));
	AddMenuItem(menu, info, (g_Settings[client] & STOP_GUNS)?"Gun sounds: Off":"Gun sounds: On");
	
	IntToString(STOP_MUSIC, info, sizeof(info));
	AddMenuItem(menu, info, (g_Settings[client] & STOP_MUSIC)?"Music: Off":"Music: On");
	
	IntToString(STOP_RECSND, info, sizeof(info));
	AddMenuItem(menu, info, (g_Settings[client] & STOP_RECSND)?"WR sound: Off":"WR sound: On");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Menu_StopSound(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		new iInfo = StringToInt(info);
		g_Settings[param1] ^= iInfo;
		
		if(iInfo == STOP_GUNS)
			CheckHooks();
		
		if(iInfo == STOP_MUSIC && (g_Settings[param1] & STOP_MUSIC))
		{
			new ientity, String:sSound[128];
			for (new i = 0; i < g_iNumSounds; i++)
			{
				ientity = EntRefToEntIndex(g_iSoundEnts[i]);
				
				if (ientity != INVALID_ENT_REFERENCE)
				{
					GetEntPropString(ientity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
					EmitSoundToClient(param1, sSound, ientity, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
				}
			}
		}
		
		// Save settings
		if(AreClientCookiesCached(param1))
		{
			decl String:sSoundCookie[16];
			IntToString(g_Settings[param1], sSoundCookie, sizeof(sSoundCookie));
			SetClientCookie(param1, g_hSettingsCookie, sSoundCookie);
		}
		
		FakeClientCommand(param1, "sm_sound");
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_Speed(client, args)
{
	if(args == 1)
	{
		// Get the specified speed
		decl String:sArg[250];
		GetCmdArgString(sArg, sizeof(sArg));
		new Float:fSpeed = StringToFloat(sArg);
		
		// Check if the speed value is in a valid range
		if(!(0 <= fSpeed <= 100))
		{
			PrintColorText(client, "%s%sYour speed must be between 0 and 100",
				g_msg_start,
				g_msg_textcol);
			return Plugin_Handled;
		}
		
		StopTimer(client);
		
		// Set the speed
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", fSpeed);
		
		// Notify them
		PrintColorText(client, "%s%sSpeed changed to %s%f%s%s",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			fSpeed,
			g_msg_textcol,
			(fSpeed != 1.0)?" (Default is 1)":" (Default)");
	}
	else
	{
		// Show how to use the command
		PrintColorText(client, "%s%sExample: sm_speed 2.0",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action:SM_Fast(client, args)
{
	StopTimer(client);
	
	// Set the speed
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 2.0);
	
	return Plugin_Handled;
}

public Action:SM_Slow(client, args)
{
	StopTimer(client);
	
	// Set the speed
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.5);
	
	return Plugin_Handled;
}

public Action:SM_Normalspeed(client, args)
{
	StopTimer(client);
	
	// Set the speed
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	
	return Plugin_Handled;
}

public Action:SM_Lowgrav(client, args)
{
	StopTimer(client);
	
	SetEntityGravity(client, 0.6);
	
	PrintColorText(client, "%s%sUsing low gravity. Use !normalgrav to switch back to normal gravity.",
		g_msg_start,
		g_msg_textcol);
}

public Action:SM_Normalgrav(client, args)
{
	SetEntityGravity(client, 0.0);
	
	PrintColorText(client, "%s%sUsing normal gravity.",
		g_msg_start,
		g_msg_textcol);
}

public Action:Hook_SetTransmit(entity, client)
{
	if (client != entity && (0 < entity <= MaxClients) && (g_Settings[client] & HIDE_PLAYERS) && IsPlayerAlive(client))
		return Plugin_Handled;
	
	if(client != entity && (0 < entity <= MaxClients) && GetEntityMoveType(entity) == MOVETYPE_NOCLIP && IsPlayerAlive(client))
		if(!IsFakeClient(entity))
			return Plugin_Handled;
		
	if(client != entity && (0 < entity <= MaxClients) && (g_Settings[client] & HIDE_PLAYERS))
		if(!IsPlayerAlive(entity))
			return Plugin_Handled;
			
	return Plugin_Continue;
}

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	SetEntPropVector(victim, Prop_Send, "m_vecPunchAngle", NULL_VECTOR);
	SetEntPropVector(victim, Prop_Send, "m_vecPunchAngleVel", NULL_VECTOR);
	return Plugin_Handled;
}
 
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{	
	// keys check
	if(g_Settings[client] & SHOW_KEYS)
	{
		if((GetConVarBool(g_hAllowKeysAlive) && IsPlayerAlive(client)) || !IsPlayerAlive(client))
		{
			new String:keys[64];
			if(IsPlayerAlive(client))
			{
				GetKeysMessage(client, keys, sizeof(keys));
				PrintCenterText(client, keys);
			}
			else
			{
				new Target 	 = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
				new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
				
				if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
				{
					GetKeysMessage(Target, keys, sizeof(keys));
					PrintCenterText(client, keys);
				}
			}
		}
	}
	
	// auto bhop check
	if(GetConVarBool(g_AllowAuto) == true)
	{
		if((g_Settings[client] & AUTO_BHOP) && IsPlayerAlive(client))
		{
			if (buttons & IN_JUMP)
			{
				if (!(GetEntityFlags(client) & FL_ONGROUND))
				{
					if (!(GetEntityMoveType(client) & MOVETYPE_LADDER))
					{
						if (GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1)
						{
							buttons &= ~IN_JUMP;
						}
					}
				}
			}
		}
	}
}

// get a player's settings
public Native_GetClientSettings(Handle:plugin, numParams)
{
	return g_Settings[GetNativeCell(1)];
}

// set a player's settings
public Native_SetClientSettings(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	g_Settings[client] = GetNativeCell(2);
	
	if(AreClientCookiesCached(client))
	{
		decl String:sSettingsCookie[16];
		IntToString(g_Settings[client], sSettingsCookie, sizeof(sSettingsCookie));
		SetClientCookie(client, g_hSettingsCookie, sSettingsCookie);
	}
}