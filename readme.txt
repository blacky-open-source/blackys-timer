Bhop timer

Author: blacky
Version: 1.1
Contact: http://steamcommunity.com/id/blaackyy/

________________________________________________________________________________________________________________
Requirements

Metamod
Sourcemod
SDKHooks
a MySQL server
Simple Chat Processor

________________________________________________________________________________________________________________
Installing

Drop addons/download folders into cstrike folder and let the folders merge together

________________________________________________________________________________________________________________
SQL

Go to cstrike/addons/sourcemod/configs/database.cfg and change the default section

"timer"
{
	"driver"			"mysql"
	"host"				"*URL TO HOST"
	"database"			"*The name given to your database"
	"user"				"*user"
	"pass"				"*pass"
	//"timeout"			"0"
	//"port"			"0"
}

Once the SQL server is connected to the game server, run the queries in sql_maps.txt and sql_zones.txt on your database

________________________________________________________________________________________________________________
Timer management

Once you run the plugin on the server, it generates some config files in cstrike/cfg/timer. There you can change some of the timer settings.
It also generates a timer_wrsounds.cfg in addons/sourcemod/configs where you can list sounds that are played when someone gets a new record.
For example, writing:

fanfare0.wav

in timer_wrsounds.cfg will play the sound located at cstrike/download/sound/btimes/fanfare0.wav

Commands admins can use (requires cheats admin flag)
sm_zones, opens up the zones menu
sm_delete, you can delete a range of values with this (sm_delete 1 5 deletes records from 1 to 5) (sm_delete 1 deletes record 1)
sm_hudfuck, use this only on players who deserve it. It removes their hud and they can't communicate because of it
sm_move, gets players out of things like walls they are stuck in. It moves them directly in the direction they're looking at by 50 units
sm_deleteghost, deletes the ghost in case of bugs
sm_reloadcc, reloads custom chat tags
sm_reloadranks, reloads chat ranks

________________________________________________________________________________________________________________
navFileReplacer (created by backwards)

In order for the ghost to appear, .nav files for maps must be on the server.
navFileReplacer creates a nav file for every instance of a map.

When you start it up, enter the directory to your maps folder, followed by a nav file to replicate.
You should pick a small nav file to make it simpler.
Ex. C:/srcds/cstrike/maps/bhop_1234.nav will copy/paste/rename bhop_1234.nav for every instance of a map bsp
in the maps folder. Just click "Create .Nav Files for all bsp File names".
If it doesn't work, you might have to do it manually.