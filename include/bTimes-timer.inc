native OpenTimerMenu(client);
native StopTimer(client);
native StartTimer(client, Type);
native bool:IsBeingTimed(client, Type);
native FinishTimer(client);
native Float:GetAverageTime(String:mapname[], Type, Style);
native DB_LoadPlayerInfo(client);
native GetClientStyle(client);
native bool:IsTimerPaused(client);