native OpenTimerMenu(client);
native StopTimer(client);
native StartTimer(client, Type);
native bool:IsBeingTimed(client, Type);
native FinishTimer(client);
native GetClientStyle(client);
native bool:IsTimerPaused(client);
native bool:IsStyleAllowed(Style);

// Fowards
forward OnTimerFinished(client, Float:Time, Type, Style);
forward Action:OnTimerStart_Pre(client, Type, Style);
forward OnTimerStart_Post(client, Type, Style);
forward OnTimesDeleted(Type, Style, RecordOne, RecordTwo);