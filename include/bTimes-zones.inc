native OpenZoneMenu(client);
native bool:IsInAStartZone(client);
native bool:IsInAFreeStyleZone(client);
native GoToStart(client);
native bool:ZoneExists(Type);

// Called when zones are loaded
forward OnZonesLoaded();