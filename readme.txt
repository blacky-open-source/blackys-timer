CS:S Bhop timer

Author: blacky
Version: 1.8.2
Contact: http://steamcommunity.com/id/blaackyy/

-------------------------------------------------------------------
Requirements

Metamod 		      - http://www.sourcemm.net/
Sourcemod 		      - http://www.sourcemod.net/snapshots.php
MySQL server
Simple Chat Processor (Redux) - https://forums.alliedmods.net/showthread.php?p=1820365
-------------------------------------------------------------------

Installing

Drop addons and download folders into cstrike folder and let the folders merge together. After that, remove the addons/sourcemod/scripting folder from the server. There is a download exploit which allows hackers to download files from the server.

Import the zones.sql and maps.sql files into your MySQL server's timer database, this way, you will have nearly every bhop map zone already set up, preventing several hours of work.



-------------------------------------------------------------------

Convenient Stuff

The folder named 'convenient stuff' contains things that will save you time, mostly.

The mapcycle.txt contains a large list of bunnyhop maps, place it into your server's cstrike folder unless you already have your own map list.

navFileReplacer (created by backwards)
In order for the ghost to appear, .nav files for maps must be on the server.
navFileReplacer creates a nav file for every instance of a map.
When you start it up, enter the directory to your maps folder, followed by a nav file to replicate.
You should pick a small nav file to make it simpler.
Ex. C:/srcds/cstrike/maps/bhop_1234.nav will copy/paste/rename bhop_1234.nav for every instance of a map bsp
in the maps folder. Just click "Create .Nav Files for all bsp File names".
If it doesn't work, you might have to do it manually.
-
OR
-
Extract the nav.rar and upload all those .nav files to your server's maps folder

-------------------------------------------------------------------

Connecting to your MySQL server

Go to cstrike/addons/sourcemod/configs/database.cfg and change the default section

"timer"
{
	"driver"			"mysql"
	"host"				"URL TO HOST"
	"database"			"The name given to your database"
	"user"				"user"
	"pass"				"pass"
	//"timeout"			"0"
	//"port"			"0"
}

-------------------------------------------------------------------
Timer management

Once you run the plugin on the server, it generates some config files in cstrike/cfg/timer. There you can change some of the timer settings.

---- Map Finish Sounds ---

To get sounds playing when a player finishes the map, you first need to choose if you are going to go with the advanced sound playing option or the simple sound playing option (timer_advancedsounds 1 or 0). The advanced option allows you to control what sounds play when someone gets a specific map rank, beats their personal record, or fails to beat their own time. To use it, there is an example within this rar file's contents (located in sourcemod/configs/timer/sounds.txt). With the simple option, you can just list a sound file in wrsounds.cfg (located in sourcemod/configs/timer/wrsounds.cfg) after auto-generating by running the plugins). The sound files must be located inside the sound/btimes folder. 

--- Chat Ranks ---

To create chat ranks, there will be an auto-generated file named ranks.cfg located in sourcemod/configs/timer. After it auto-generates, there is an example written inside that looks like:

//"Range"     "Tag/Name"
"0-0"     "[Unranked] {name}"
"1-1"     "[Master] {name}"
"2-2"     "[Champion] {name}"

The first line is commented so it doesn't effect the plugin. It says "Range" and "Tag/Name". Range is the range of ranks that will get the corresponding chat rank. So people ranked 0 (Unranked) will show up with "[Unranked]" before their name. The person at rank 1 will have [Master] before their name. If you put "10-20" "[Brilliant] {name}", the people who are between the ranks 10 and 20 will have "[Brilliant]" show up between their names.

To add colors inside the chat ranks, you can put a caret symbol followed by a hexadecimal code. Everything following that until the next color will appear as the specified color. Example: "^000000[^00FF00Unranked^000000] ^0000FF{name}" will give a player black brackets around their tag, their tag will be green, and their name will appear blue. There are other ways to effect color in a name like {team} will be replaced with the talking player's team color. {rand} will replace with a random color. and {norm} will become the normal chat-yellow color.

--- Admin commands ---

sm_zones opens up the zones menu (Cheats flag)
sm_delete you can delete a range of values with this (sm_delete 1 5 deletes records from 1 to 5) (sm_delete 1 deletes record 1) (Cheats flag)
sm_hudfuck use this only on players who deserve it. It removes their hud and they can't communicate because of it (Generic flag)
sm_move gets players out of things like walls they are stuck in. It moves them forward in the direction they look. (Generic flag)
sm_deleteghost deletes the ghost in case of bugs (Cheats flag)
sm_reloadranks reloads chat ranks (Root flag)
sm_enablecc <steamid> to give someone custom chat privileges (Root flag)
sm_disablecc <steamid> to remove someone's custom chat privileges (Root flag)
sm_cclist to see a list of every player with custom chat privileges (Cheats flag)

--- Style configuration ---

Inside addons/sourcemod/configs/timer, there is a file named styles.cfg. There you can create your own styles. If you are upgrading from a lower timer version than 1.8, you should not remove any of these styles. If you don't want any of them to show, it's best that you disable them by setting "enable" to "0". If you are not upgrading, then this is a good chance for you to completely edit styles the way you want them to be.

-------------------------------------------------------------------