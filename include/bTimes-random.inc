#define STOP_DOORS   1<<0
#define STOP_GUNS    1<<1
#define STOP_MUSIC   1<<2
#define AUTO_BHOP    1<<3
#define HIDE_PLAYERS 1<<4
#define SHOW_HUD	 1<<5
#define SHOW_KEYS    1<<6
#define SHOW_HINT    1<<7
#define SHOW_2DVEL   1<<8
#define STOP_JOINSND 1<<9
#define STOP_RECSND	 1<<10

native GetClientSettings(client);
native SetClientSettings(client, settings);
forward OnTimerChatChanged(MessageType, String:Message[]);