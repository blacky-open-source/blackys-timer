#define VERSION "1.3"

// Timer enums
enum
{
	TIMER_MAIN,
	TIMER_BONUS,
	TIMER_ANY
};

// Style enums
enum
{
	STYLE_NORMAL,
	STYLE_SIDEWAYS,
	STYLE_WONLY
};

enum
{
	ALL = -1
};

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

// Core forwards

/*
* 
*/
forward OnMapIDPostCheck();

/*
* 
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
		Format(sPrecision, sizeof(sPrecision), "%04.1f", seconds);
	else if(precision == 1)
		Format(sPrecision, sizeof(sPrecision), "%06.3f", seconds);
	else if(precision == 2)
		Format(sPrecision, sizeof(sPrecision), "%09.6f", seconds);
	
	if(hours > 0)
		Format(result, maxlength, "%d:%02d:%s", hours, minutes, sPrecision);
	else if(minutes > 0)
		Format(result, maxlength, "%d:%s", minutes, sPrecision);
	else
		Format(result, maxlength, "%s", sPrecision);
}


stock FormatPlayerTimeEx(Float:time, String:buffer[], maxlength, const String:precision[], bool:showdash)
{
	if(time <= 0.0 && showdash == true)
	{
		Format(buffer, maxlength, "-");
		return;
	}
	
	new hours     = RoundToFloor(time/3600);
	time          -= hours*3600;
	new minutes   = RoundToFloor(time/60);
	time        -= minutes*60;
	new Float:seconds = time;
	
	decl String:sPrecision[16];
	Format(sPrecision, sizeof(sPrecision), "%%sf", precision, seconds);
	
	if(hours > 0)
		Format(buffer, maxlength, "%d:%02d:%s", hours, minutes, sPrecision);
	else if(minutes > 0)
		Format(buffer, maxlength, "%d:%s", minutes, sPrecision);
	else
		Format(buffer, maxlength, "%s", sPrecision);
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