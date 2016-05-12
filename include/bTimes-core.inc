#include <console>

#define VERSION "1.6.1"

#define MAX_TYPES 2

#define TIMER_MAIN 0
#define TIMER_BONUS 1
#define TIMER_ANY 2

#define MAX_STYLES 5

#define STYLE_NORMAL 0
#define STYLE_SIDEWAYS 1
#define STYLE_WONLY 2
#define STYLE_STAMINA 3
#define STYLE_HALFSIDEWAYS 4

#define ALL -1

enum
{
	eType = 2,
	eStyle,
	ePlayerID,
	eTime,
	eJumps,
	eStrafes,
	ePoints,
	eTimestamp
};

// Core natives

/*
* Gets a client's player id in the database.
* 
* @param client		Client index.
* 
* @return			Client's player id.
*/
native GetClientID(client);

// A better name for GetClientID function
stock GetPlayerID(client)
{
	return GetClientID(client);
}

/*
* Get a client's current session playtime.
* 
* @param client		Client index.
* 
* @return 			Client's current map session playtime
*/
native Float:GetPlaytime(client);

/*
* Gets if a client is spamming SQL related commands or not.
* 
* @param client		Client index.
* 
* @return 			True if client is spamming; false otherwise.
*/
native bool:IsSpamming(client);

/*
* Sets a client as spamming commands.
* 
* @param client		Client index.
* 
* @noreturn
*/
native SetIsSpamming(client, Float:BlockTime);

native RegisterCommand(const String:sCommand[], const String:sDescription[]);

stock RegConsoleCmdEx(const String:sCommand[], ConCmd:callback, const String:sDescription[])
{
	RegConsoleCmd(sCommand, callback, sDescription);
	
	RegisterCommand(sCommand, sDescription);
}
// Core forwards

/*
* Called when a map's MapID is gauranteed to be in the database
*/
forward OnMapIDPostCheck();

/*
* Called when a player's PlayerID is retrieved and gauranteed to be in the database
*/
forward OnPlayerIDLoaded(client);

stock PrintColorTextAll(const String:msg[], any:...)
{
	decl String:buffer[300];
	VFormat(buffer, sizeof(buffer), msg, 2);
	new Handle:hMessage = StartMessageAll("SayText2"); 
	if (hMessage != INVALID_HANDLE) 
	{ 
		BfWriteByte(hMessage, -1); 
		BfWriteByte(hMessage, true);
		BfWriteString(hMessage, buffer);
		EndMessage();
	}
}

stock PrintColorText(client, const String:msg[], any:...)
{
	if(IsClientInGame(client))
	{
		new String:buffer[300];
		VFormat(buffer, sizeof(buffer), msg, 3);
		new Handle:hMessage = StartMessageOne("SayText2", client); 
		if (hMessage != INVALID_HANDLE) 
		{ 
			BfWriteByte(hMessage, client); 
			BfWriteByte(hMessage, true);
			BfWriteString(hMessage, buffer);
			EndMessage();
		}
	}
}

stock FormatPlayerTime(Float:Time, String:result[], maxlength, bool:showDash, precision)
{
	if(Time <= 0.0 && showDash == true)
	{
		Format(result, maxlength, "-");
		return;
	}
	
	new hours 	= RoundToFloor(Time/3600);
	Time         -= hours*3600;
	new minutes 	= RoundToFloor(Time/60);
	Time         -= minutes*60;
	new Float:seconds = Time;
	
	decl String:sPrecision[16];
	
	if(precision == 0)
		Format(sPrecision, sizeof(sPrecision), (hours > 0 || minutes > 0)?"%04.1f":"%.1f", seconds);
	else if(precision == 1)
		Format(sPrecision, sizeof(sPrecision), (hours > 0 || minutes > 0)?"%06.3f":"%.3f", seconds);
	else if(precision == 2)
		Format(sPrecision, sizeof(sPrecision), (hours > 0 || minutes > 0)?"%09.6f":"%.6f", seconds);
	
	if(hours > 0)
		Format(result, maxlength, "%d:%02d:%s", hours, minutes, sPrecision);
	else if(minutes > 0)
		Format(result, maxlength, "%d:%s", minutes, sPrecision);
	else
		Format(result, maxlength, "%s", sPrecision);
}

stock Float:GetClientVelocity(client, bool:UseX, bool:UseY, bool:UseZ)
{
	new Float:vVel[3];
	
	if(UseX)
	{
		vVel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	}
	
	if(UseY)
	{
		vVel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	}
	
	if(UseZ)
	{
		vVel[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
	}
	
	return GetVectorLength(vVel);
}

stock GetTypeName(Type, String:sType[], maxlength, bool:bBlankIfMain = false)
{
	if((Type == TIMER_MAIN && bBlankIfMain == true) || Type == ALL)
	{
		FormatEx(sType, maxlength, "");
		return;
	}
	
	decl String:sTypeList[MAX_TYPES][] = {"Main", "Bonus"};
	
	FormatEx(sType, maxlength, sTypeList[Type]);
}

stock GetTypeAbbr(Type, String:sAbbr[], maxlength, bool:bBlankIfMain = false)
{
	if((Type == TIMER_MAIN && bBlankIfMain == true) || Type == ALL)
	{
		FormatEx(sAbbr, maxlength, "");
		return;
	}
	
	decl String:sAbbrList[MAX_TYPES][] = {"", "b"};
	
	FormatEx(sAbbr, maxlength, sAbbrList[Type]);
}

stock GetStyleName(Style, String:sStyle[], maxlength)
{
	if(Style == ALL)
	{
		FormatEx(sStyle, maxlength, "");
		return;
	}
	
	decl String:sStyleList[MAX_STYLES][] = {"Normal", "Sideways", "W-Only", "Stamina", "Half-Sideways"};
	
	FormatEx(sStyle, maxlength, sStyleList[Style]);
}

stock GetStyleAbbr(Style, String:sAbbr[], maxlength)
{
	if(Style == ALL)
	{
		FormatEx(sAbbr, maxlength, "");
		return;
	}
	
	decl String:sAbbrList[MAX_STYLES][] = {"n", "sw", "w", "stam", "hsw"};
	
	FormatEx(sAbbr, maxlength, sAbbrList[Style]);
}

stock StringToUpper(String:buffer[])
{
	new len = strlen(buffer);
	
	for(new idx = 0; idx < len; idx++)
	{
		buffer[idx] = CharToUpper(buffer[idx]);
	}
}

stock AddBracketsToString(String:buffer[], maxlength)
{
	if(strlen(buffer) > 0)
		Format(buffer, maxlength, "[%s]", buffer);
}

stock AddSpaceToEnd(String:buffer[], maxlength)
{
	if(strlen(buffer) > 0)
		Format(buffer, maxlength, "%s ", buffer);
}

