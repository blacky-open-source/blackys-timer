native OpenTimerMenu(client);
native StopTimer(client);
native StartTimer(client, Type);
native bool:IsBeingTimed(client, Type);
native FinishTimer(client);
native GetClientStyle(client);
native bool:IsTimerPaused(client);

// Fowards
forward OnTimerFinished(client, Float:Time, Position, Type, Style, bool:IsNewTime);