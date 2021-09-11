#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <convar_class>
#include <shavit>

#undef REQUIRE_PLUGIN
// for MapChange type
#include <mapchooser>

#undef REQUIRE_EXTENSIONS
#include <cstrike>

Database2 g_hDatabase;
char g_cSQLPrefix[32];

bool g_bDebug;

/* ConVars */
Convar g_cvRTVRequiredPercentage;
Convar g_cvRTVAllowSpectators;
Convar g_cvRTVSpectatorCooldown;
Convar g_cvRTVMinimumPoints;
Convar g_cvRTVDelayTime;

Convar g_cvMapListType;
Convar g_cvMatchFuzzyMap;
Convar g_cvHijackMap;

int g_iExcludePrefixesCount;
char g_cExcludePrefixesBuffers[128][12];
Convar g_cvExcludePrefixes;
int g_iAutocompletePrefixesCount;
char g_cAutocompletePrefixesBuffers[128][12];
Convar g_cvAutocompletePrefixes;

Convar g_cvMapVoteStartTime;
Convar g_cvMapVoteDuration;
Convar g_cvMapVoteBlockMapInterval;
Convar g_cvMapVoteExtendLimit;
Convar g_cvMapVoteEnableNoVote;
Convar g_cvMapVoteExtendTime;
Convar g_cvMapVoteShowTier;
Convar g_cvMapVoteRunOff;
Convar g_cvMapVoteRunOffPerc;
Convar g_cvMapVoteRevoteTime;
Convar g_cvDisplayTimeRemaining;

Convar g_cvNominateMatches;
Convar g_cvEnhancedMenu;

Convar g_cvMinTier;
Convar g_cvMaxTier;

Convar g_cvAntiSpam;
float g_fLastRtvTime[MAXPLAYERS+1];

Convar g_cvPrefix;
char g_cPrefix[32];

/* Map arrays */
ArrayList g_aMapList;
ArrayList g_aNominateList;
ArrayList g_aAllMapsList;
ArrayList g_aOldMaps;

/* Map Data */
char g_cMapName[PLATFORM_MAX_PATH];

MapChange g_ChangeTime;

bool g_bMapVoteStarted;
bool g_bMapVoteFinished;
float g_fMapStartTime;
float g_fLastMapvoteTime = 0.0;

int g_iExtendCount;
int g_mapFileSerial = -1;

Menu g_hNominateMenu;
Menu g_hEnhancedMenu;

ArrayList g_aTierMenus;

Menu g_hVoteMenu;

/* Player Data */
bool g_bRockTheVote[MAXPLAYERS + 1];
char g_cNominatedMap[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
float g_fSpecTimerStart[MAXPLAYERS+1];

Handle g_hRetryTimer = null;
Handle g_hForward_OnRTV = null;
Handle g_hForward_OnUnRTV = null;
Handle g_hForward_OnSuccesfulRTV = null;

StringMap g_mMapList;
bool gB_Late = false;

enum
{
	MapListZoned,
	MapListFile,
	MapListFolder,
	MapListMixed,
	MapListZonedMixedWithFolder,
}

public Plugin myinfo =
{
	name = "[shavit] MapChooser",
	author = "SlidyBat, kidfearless, mbhound, lilac, rtldg",
	description = "Automated Map Voting and nominating with Shavit's bhoptimer integration",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hForward_OnRTV = CreateGlobalForward("SMC_OnRTV", ET_Event, Param_Cell);
	g_hForward_OnUnRTV = CreateGlobalForward("SMC_OnUnRTV", ET_Event, Param_Cell);
	g_hForward_OnSuccesfulRTV = CreateGlobalForward("SMC_OnSuccesfulRTV", ET_Event);

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	if (gB_Late)
	{
		Shavit_OnDatabaseLoaded();
	}

	LoadTranslations("mapchooser.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("rockthevote.phrases");
	LoadTranslations("nominations.phrases");

	g_aMapList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_aAllMapsList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_aNominateList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_aOldMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_aTierMenus = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

	g_mMapList = new StringMap();

	g_cvMapListType = new Convar("smc_maplist_type", "2", "Where the plugin should get the map list from.\n0 - zoned maps from database\n1 - from maplist file (mapcycle.txt)\n2 - from maps folder\n3 - from zoned maps and confirmed by maplist file\n4 - from zoned maps and confirmed by maps folder", _, true, 0.0, true, 4.0);
	g_cvMatchFuzzyMap = new Convar("smc_match_fuzzy", "1", "If set to 1, the plugin will accept partial map matches from the database. Useful for workshop maps, bad for duplicate map names", _, true, 0.0, true, 1.0);
	g_cvHijackMap = new Convar("smc_hijack_sm_map_so_its_faster", "1", "Hijacks sourcemod's built-in sm_map command so it's faster.", 0, true, 0.0, true, 1.0);
	g_cvExcludePrefixes = new Convar("smc_exclude_prefixes", "de_,cs_,as_,ar_,dz_,gd_,lobby_,training1,mg_,gg_,jb_,coop_,aim_,awp_,cp_,ctf_,fy_,dm_,hg_,rp_,ze_,zm_,arena_,pl_,plr_,mvm_,db_,trade_,ba_,mge_,ttt_,ph_,hns_,", "Exclude maps based on these prefixes.\nA good reference: https://developer.valvesoftware.com/wiki/Map_prefixes");
	g_cvAutocompletePrefixes = new Convar("smc_autocomplete_prefixes", "bhop_,surf_,kz_,kz_bhop_,bhop_kz_,xc_,trikz_,jump_,rj_", "Some prefixes that are attempted when using !nominate");

	g_cvMapVoteBlockMapInterval = new Convar("smc_mapvote_blockmap_interval", "1", "How many maps should be played before a map can be nominated again", _, true, 0.0, false);
	g_cvMapVoteEnableNoVote = new Convar("smc_mapvote_enable_novote", "1", "Whether players are able to choose 'No Vote' in map vote", _, true, 0.0, true, 1.0);
	g_cvMapVoteExtendLimit = new Convar("smc_mapvote_extend_limit", "3", "How many times players can choose to extend a single map (0 = block extending)", _, true, 0.0, false);
	g_cvMapVoteExtendTime = new Convar("smc_mapvote_extend_time", "10", "How many minutes should the map be extended by if the map is extended through a mapvote", _, true, 1.0, false);
	g_cvMapVoteShowTier = new Convar("smc_mapvote_show_tier", "1", "Whether the map tier should be displayed in the map vote", _, true, 0.0, true, 1.0);
	g_cvMapVoteDuration = new Convar("smc_mapvote_duration", "1", "Duration of time in minutes that map vote menu should be displayed for", _, true, 0.1, false);
	g_cvMapVoteStartTime = new Convar("smc_mapvote_start_time", "5", "Time in minutes before map end that map vote starts", _, true, 1.0, false);

	g_cvRTVAllowSpectators = new Convar("smc_rtv_allow_spectators", "1", "Whether spectators should be allowed to RTV", _, true, 0.0, true, 1.0);
	g_cvRTVSpectatorCooldown = new Convar("smc_rtv_spectator_cooldown", "60", "When `smc_rtv_allow_spectators` is `0`, wait this many seconds before removing a spectator's RTV", 0, true, 0.0);
	g_cvRTVMinimumPoints = new Convar("smc_rtv_minimum_points", "-1", "Minimum number of points a player must have before being able to RTV, or -1 to allow everyone", _, true, -1.0, false);
	g_cvRTVDelayTime = new Convar("smc_rtv_delay", "5", "Time in minutes after map start before players should be allowed to RTV", _, true, 0.0, false);
	g_cvRTVRequiredPercentage = new Convar("smc_rtv_required_percentage", "50", "Percentage of players who have RTVed before a map vote is initiated", _, true, 1.0, true, 100.0);

	g_cvMapVoteRunOff = new Convar("smc_mapvote_runoff", "1", "Hold run of votes if winning choice is less than a certain margin", _, true, 0.0, true, 1.0);
	g_cvMapVoteRunOffPerc = new Convar("smc_mapvote_runoffpercent", "50", "If winning choice has less than this percent of votes, hold a runoff", _, true, 0.0, true, 100.0);
	g_cvMapVoteRevoteTime = new Convar("smc_mapvote_revotetime", "0", "How many minutes after a failed mapvote before rtv is enabled again", _, true, 0.0);
	g_cvDisplayTimeRemaining = new Convar("smc_display_timeleft", "1", "Display remaining messages in chat", _, true, 0.0, true, 1.0);

	g_cvNominateMatches = new Convar("smc_nominate_matches", "1", "Prompts a menu which shows all maps which match argument",  _, true, 0.0, true, 1.0);
	g_cvEnhancedMenu = new Convar("smc_enhanced_menu", "1", "Nominate menu can show maps by alphabetic order and tiers",  _, true, 0.0, true, 1.0);

	g_cvMinTier = new Convar("smc_min_tier", "0", "The minimum tier to show on the enhanced menu",  _, true, 0.0, true, 10.0);
	g_cvMaxTier = new Convar("smc_max_tier", "10", "The maximum tier to show on the enhanced menu",  _, true, 0.0, true, 10.0);

	g_cvAntiSpam = new Convar("smc_anti_spam", "2.0", "The number of seconds a player needs to wait before rtv/unrtv.", 0, true, 0.0, true, 60.0);

	g_cvPrefix = new Convar("smc_prefix", "[SMC] ", "The prefix SMC messages have");
	g_cvPrefix.AddChangeHook(OnConVarChanged);

	Convar.AutoExecConfig();

	RegAdminCmd("sm_extendmap", Command_Extend, ADMFLAG_RCON, "Admin command for extending map");
	RegAdminCmd("sm_forcemapvote", Command_ForceMapVote, ADMFLAG_RCON, "Admin command for forcing the end of map vote");
	RegAdminCmd("sm_reloadmaplist", Command_ReloadMaplist, ADMFLAG_CHANGEMAP, "Admin command for forcing maplist to be reloaded");

	RegAdminCmd("sm_loadunzonedmap", Command_LoadUnzonedMap, ADMFLAG_ROOT, "Loads the next map from the maps folder that is unzoned.");

	RegConsoleCmd("sm_nominate", Command_Nominate, "Lets players nominate maps to be on the end of map vote");
	RegConsoleCmd("sm_unnominate", Command_UnNominate, "Removes nominations");
	RegConsoleCmd("sm_rtv", Command_RockTheVote, "Lets players Rock The Vote");
	RegConsoleCmd("sm_unrtv", Command_UnRockTheVote, "Lets players un-Rock The Vote");
	RegConsoleCmd("sm_nomlist", Command_NomList, "Shows currently nominated maps");

	RegAdminCmd("sm_smcdebug", Command_Debug, ADMFLAG_RCON);

	AddCommandListener(Command_MapButFaster, "sm_map");
}

public void OnMapStart()
{
	GetCurrentMap(g_cMapName, sizeof(g_cMapName));

	SetNextMap(g_cMapName);

	// disable rtv if delay time is > 0
	g_fMapStartTime = GetGameTime();
	g_fLastMapvoteTime = 0.0;

	g_iExtendCount = 0;

	g_bMapVoteFinished = false;
	g_bMapVoteStarted = false;

	g_aNominateList.Clear();
	for(int i = 1; i <= MaxClients; ++i)
	{
		g_cNominatedMap[i][0] = '\0';
	}
	ClearRTV();

	CreateTimer(0.5, Timer_SpecCooldown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(2.0, Timer_OnMapTimeLeftChanged, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnConfigsExecuted()
{
	// reload maplist array
	LoadMapList();
	// cache the nominate menu so that it isn't being built every time player opens it
}

public void OnMapEnd()
{
	if(g_cvMapVoteBlockMapInterval.IntValue > 0)
	{
		g_aOldMaps.PushString(g_cMapName);
		if(g_aOldMaps.Length > g_cvMapVoteBlockMapInterval.IntValue)
		{
			g_aOldMaps.Erase(0);
		}
	}

	g_iExtendCount = 0;


	g_bMapVoteFinished = false;
	g_bMapVoteStarted = false;

	g_aNominateList.Clear();
	for(int i = 1; i <= MaxClients; i++)
	{
		g_cNominatedMap[i][0] = '\0';
	}

	ClearRTV();
}

int ExplodeCvar(ConVar cvar, char[][] buffers, int maxStrings, int maxStringLength)
{
	char cvarstring[2048];
	cvar.GetString(cvarstring, sizeof(cvarstring));
	LowercaseString(cvarstring);

	while (ReplaceString(cvarstring, sizeof(cvarstring), ",,", ",", true)) {}

	int count = ExplodeString(cvarstring, ",", buffers, maxStrings, maxStringLength);

	for (int i = 0; i < count; i++)
	{
		TrimString(buffers[i]);

		if (buffers[i][0] == 0)
		{
			strcopy(buffers[i], maxStringLength, buffers[--count]);
		}
	}

	return count;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvPrefix)
	{
		strcopy(g_cPrefix, sizeof(g_cPrefix), newValue);
	}
}

public Action Timer_SpecCooldown(Handle timer)
{
	float cooldown = g_cvRTVSpectatorCooldown.FloatValue;
	float now = GetEngineTime();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) > CS_TEAM_SPECTATOR)
		{
			g_fSpecTimerStart[i] = 0.0;
			continue;
		}

		if (!g_fSpecTimerStart[i])
		{
			g_fSpecTimerStart[i] = now;
		}

		if (g_bRockTheVote[i] && (now - g_fSpecTimerStart[i]) >= cooldown)
		{
			UnRTVClient(i);
		}
	}
}

public Action Timer_OnMapTimeLeftChanged(Handle Timer)
{
	DebugPrint("%sOnMapTimeLeftChanged: maplist_length=%i mapvote_started=%s mapvotefinished=%s", g_cPrefix, g_aMapList.Length, g_bMapVoteStarted ? "true" : "false", g_bMapVoteFinished ? "true" : "false");

	int timeleft;
	if(GetMapTimeLeft(timeleft))
	{
		if(!g_bMapVoteStarted && !g_bMapVoteFinished)
		{
			int mapvoteTime = timeleft - RoundFloat(g_cvMapVoteStartTime.FloatValue * 60.0) + 3;
			switch(mapvoteTime)
			{
				case (10 * 60), (5 * 60):
				{
					PrintToChatAll("%s%d minutes until map vote", g_cPrefix, mapvoteTime/60);
				}
			}
			switch(mapvoteTime)
			{
				case (10 * 60) - 3:
				{
					PrintToChatAll("%s10 minutes until map vote", g_cPrefix);
				}
				case 60, 30, 5:
				{
					PrintToChatAll("%s%s seconds until map vote", g_cPrefix, mapvoteTime);
				}
			}
		}
		else if(g_bMapVoteFinished && g_cvDisplayTimeRemaining.BoolValue)
		{
			timeleft += 3;
			switch(timeleft)
			{
				case (30 * 60), (20 * 60), (10 * 60), (5 * 60):
				{
					PrintToChatAll("%s%d minutes remaining", g_cPrefix, timeleft/60);
				}
				case 60, 10, 5, 3, 2:
				{
					PrintToChatAll("%s%d seconds remaining", g_cPrefix, timeleft);
				}
				case 1:
				{
					PrintToChatAll("%s1 second remaining", g_cPrefix);
				}
			}
		}
	}

	if(g_aMapList.Length && !g_bMapVoteStarted && !g_bMapVoteFinished)
	{
		CheckTimeLeft();
	}
}

void CheckTimeLeft()
{
	int timeleft;
	if(GetMapTimeLeft(timeleft) && timeleft > 0)
	{
		int startTime = RoundFloat(g_cvMapVoteStartTime.FloatValue * 60.0);
		DebugPrint("%sCheckTimeLeft: timeleft=%i startTime=%i", g_cPrefix, timeleft, startTime);

		if(timeleft - startTime <= 0)
		{
			DebugPrint("%sCheckTimeLeft: Initiating map vote ...", g_cPrefix, timeleft, startTime);
			InitiateMapVote(MapChange_MapEnd);
		}
	}
	else
	{
		DebugPrint("%sCheckTimeLeft: GetMapTimeLeft=%s timeleft=%i", g_cPrefix, GetMapTimeLeft(timeleft) ? "true" : "false", timeleft);
	}
}

public void OnClientConnected(int client)
{
	g_fSpecTimerStart[client] = 0.0;
}

public void OnClientDisconnect(int client)
{
	// clear player data
	g_bRockTheVote[client] = false;
	g_cNominatedMap[client][0] = '\0';

	CheckRTV();
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if(StrEqual(sArgs, "rtv", false) || StrEqual(sArgs, "rockthevote", false))
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);

		Command_RockTheVote(client, 0);

		SetCmdReplySource(old);
	}
	else if(StrEqual(sArgs, "nominate", false))
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);

		Command_Nominate(client, 0);

		SetCmdReplySource(old);
	}
}

void InitiateMapVote(MapChange when)
{
	g_ChangeTime = when;
	g_bMapVoteStarted = true;

	if (IsVoteInProgress())
	{
		// Can't start a vote, try again in 5 seconds.
		//g_RetryTimer = CreateTimer(5.0, Timer_StartMapVote, _, TIMER_FLAG_NO_MAPCHANGE);

		DataPack data;
		g_hRetryTimer = CreateDataTimer(5.0, Timer_StartMapVote, data, TIMER_FLAG_NO_MAPCHANGE);
		data.WriteCell(when);
		data.Reset();
		return;
	}

	// create menu
	Menu menu = new Menu(Handler_MapVoteMenu, MENU_ACTIONS_ALL);
	menu.VoteResultCallback = Handler_MapVoteFinished;
	menu.Pagination = MENU_NO_PAGINATION;
	menu.SetTitle("Vote Nextmap");

	int mapsToAdd = 8;
	if(g_cvMapVoteExtendLimit.IntValue > 0 && g_iExtendCount < g_cvMapVoteExtendLimit.IntValue)
	{
		mapsToAdd--;
	}

	if(g_cvMapVoteEnableNoVote.BoolValue)
	{
		mapsToAdd--;
	}

	char map[PLATFORM_MAX_PATH];
	char mapdisplay[PLATFORM_MAX_PATH + 32];

	StringMap tiersMap = Shavit_GetMapTiers();

	int nominateMapsToAdd = (mapsToAdd > g_aNominateList.Length) ? g_aNominateList.Length : mapsToAdd;
	for(int i = 0; i < nominateMapsToAdd; i++)
	{
		g_aNominateList.GetString(i, map, sizeof(map));
		GetMapDisplayName(map, mapdisplay, sizeof(mapdisplay));

		if(g_cvMapVoteShowTier.BoolValue)
		{
			int tier = 0;
			tiersMap.GetValue(mapdisplay, tier);
			Format(mapdisplay, sizeof(mapdisplay), "[T%i] %s", tier, mapdisplay);
		}
		else
		{
			strcopy(mapdisplay, sizeof(mapdisplay), map);
		}

		menu.AddItem(map, mapdisplay);

		mapsToAdd--;
	}

	for(int i = 0; i < mapsToAdd; i++)
	{
		int rand = GetRandomInt(0, g_aMapList.Length - 1);
		g_aMapList.GetString(rand, map, sizeof(map));

		GetMapDisplayName(map, mapdisplay, sizeof(mapdisplay));

		if(StrEqual(map, g_cMapName))
		{
			// don't add current map to vote
			i--;
			continue;
		}

		int idx = g_aOldMaps.FindString(map);
		if(idx != -1)
		{
			// map already played recently, get another map
			i--;
			continue;
		}

		if(g_cvMapVoteShowTier.BoolValue)
		{
			int tier = 0;
			tiersMap.GetValue(mapdisplay, tier);

			Format(mapdisplay, sizeof(mapdisplay), "[T%i] %s", tier, mapdisplay);
		}


		menu.AddItem(map, mapdisplay);
	}

	delete tiersMap;

	if(when == MapChange_MapEnd && g_cvMapVoteExtendLimit.IntValue > 0 && g_iExtendCount < g_cvMapVoteExtendLimit.IntValue)
	{
		menu.AddItem("extend", "Extend Map");
	}
	else if(when == MapChange_Instant)
	{
		menu.AddItem("dontchange", "Don't Change");
	}

	menu.NoVoteButton = g_cvMapVoteEnableNoVote.BoolValue;
	menu.ExitButton = false;
	menu.DisplayVoteToAll(RoundFloat(g_cvMapVoteDuration.FloatValue * 60.0));

	PrintToChatAll("%s%t", g_cPrefix, "Nextmap Voting Started");
}

public void Handler_MapVoteFinished(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	if (g_cvMapVoteRunOff.BoolValue && num_items > 1)
	{
		float winningvotes = float(item_info[0][VOTEINFO_ITEM_VOTES]);
		float required = num_votes * (g_cvMapVoteRunOffPerc.FloatValue / 100.0);

		if (winningvotes < required)
		{
			/* Insufficient Winning margin - Lets do a runoff */
			g_hVoteMenu = new Menu(Handler_MapVoteMenu, MENU_ACTIONS_ALL);
			g_hVoteMenu.SetTitle("Runoff Vote Nextmap");
			g_hVoteMenu.VoteResultCallback = Handler_VoteFinishedGeneric;

			char map[PLATFORM_MAX_PATH];
			char info1[PLATFORM_MAX_PATH];
			char info2[PLATFORM_MAX_PATH];

			menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], map, sizeof(map), _, info1, sizeof(info1));
			g_hVoteMenu.AddItem(map, info1);
			menu.GetItem(item_info[1][VOTEINFO_ITEM_INDEX], map, sizeof(map), _, info2, sizeof(info2));
			g_hVoteMenu.AddItem(map, info2);

			g_hVoteMenu.ExitButton = true;
			g_hVoteMenu.DisplayVoteToAll(RoundFloat(g_cvMapVoteDuration.FloatValue * 60.0));

			/* Notify */
			float map1percent = float(item_info[0][VOTEINFO_ITEM_VOTES])/ float(num_votes) * 100;
			float map2percent = float(item_info[1][VOTEINFO_ITEM_VOTES])/ float(num_votes) * 100;


			PrintToChatAll("%s%t", "Starting Runoff", g_cPrefix, g_cvMapVoteRunOffPerc.FloatValue, info1, map1percent, info2, map2percent);
			LogMessage("Voting for next map was indecisive, beginning runoff vote");

			return;
		}
	}

	Handler_VoteFinishedGeneric(menu, num_votes, num_clients, client_info, num_items, item_info);
}

public Action Timer_StartMapVote(Handle timer, DataPack data)
{
	if (timer == g_hRetryTimer)
	{
		g_hRetryTimer = null;
	}

	if (!g_aMapList.Length || g_bMapVoteFinished || g_bMapVoteStarted)
	{
		return Plugin_Stop;
	}

	MapChange when = view_as<MapChange>(data.ReadCell());

	InitiateMapVote(when);

	return Plugin_Stop;
}

public void Handler_VoteFinishedGeneric(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	char map[PLATFORM_MAX_PATH];
	char displayName[PLATFORM_MAX_PATH];

	menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], map, sizeof(map), _, displayName, sizeof(displayName));

	PrintToChatAll("#1 vote was %s (%s)", map, (g_ChangeTime == MapChange_Instant) ? "instant" : "map end");

	if(StrEqual(map, "extend"))
	{
		g_iExtendCount++;

		int time;
		if(GetMapTimeLimit(time))
		{
			if(time > 0)
			{
				ExtendMapTimeLimit(g_cvMapVoteExtendTime.IntValue * 60);
			}
		}

		PrintToChatAll("%s%t", g_cPrefix, "Current Map Extended", RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes);
		LogAction(-1, -1, "Voting for next map has finished. The current map has been extended.");

		// We extended, so we'll have to vote again.
		g_bMapVoteStarted = false;
		g_fLastMapvoteTime = GetGameTime();

		ClearRTV();
	}
	else if(StrEqual(map, "dontchange"))
	{
		PrintToChatAll("%s%t", g_cPrefix, "Current Map Stays", RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes);
		LogAction(-1, -1, "Voting for next map has finished. 'No Change' was the winner");

		g_bMapVoteFinished = false;
		g_bMapVoteStarted = false;
		g_fLastMapvoteTime = GetGameTime();

		ClearRTV();
	}
	else
	{
		if(g_ChangeTime == MapChange_MapEnd)
		{
			SetNextMap(map);
		}
		else if(g_ChangeTime == MapChange_Instant)
		{
			if(GetRTVVotesNeeded() <= 0)
			{
				Call_StartForward(g_hForward_OnSuccesfulRTV);
				Call_Finish();
			}

			DataPack data;
			CreateDataTimer(2.0, Timer_ChangeMap, data);
			data.WriteString(map);
			ClearRTV();
		}

		g_bMapVoteStarted = false;
		g_bMapVoteFinished = true;

		PrintToChatAll("%s%t", g_cPrefix, "Nextmap Voting Finished", displayName, RoundToFloor(float(item_info[0][VOTEINFO_ITEM_VOTES])/float(num_votes)*100), num_votes);
		LogAction(-1, -1, "Voting for next map has finished. Nextmap: %s.", map);
	}
}

public int Handler_MapVoteMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}

		case MenuAction_Display:
		{
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle("Vote Nextmap");
		}

		case MenuAction_DisplayItem:
		{
			if (menu.ItemCount - 1 == param2)
			{
				char map[PLATFORM_MAX_PATH], buffer[255];
				menu.GetItem(param2, map, sizeof(map));
				if (strcmp(map, "extend", false) == 0)
				{
					Format(buffer, sizeof(buffer), "Extend Map");
					return RedrawMenuItem(buffer);
				}
				else if (strcmp(map, "novote", false) == 0)
				{
					Format(buffer, sizeof(buffer), "No Vote");
					return RedrawMenuItem(buffer);
				}
			}
		}

		case MenuAction_VoteCancel:
		{
			// If we receive 0 votes, pick at random.
			if(param1 == VoteCancel_NoVotes)
			{
				int count = menu.ItemCount;
				char map[PLATFORM_MAX_PATH];
				menu.GetItem(0, map, sizeof(map));

				// Make sure the first map in the menu isn't one of the special items.
				// This would mean there are no real maps in the menu, because the special items are added after all maps. Don't do anything if that's the case.
				if(strcmp(map, "extend", false) != 0 && strcmp(map, "dontchange", false) != 0)
				{
					// Get a random map from the list.

					// Make sure it's not one of the special items.
					do
					{
						int item = GetRandomInt(0, count - 1);
						menu.GetItem(item, map, sizeof(map));
					}
					while(strcmp(map, "extend", false) == 0 || strcmp(map, "dontchange", false) == 0);

					SetNextMap(map);
					PrintToChatAll("%s%t", g_cPrefix, "Nextmap Voting Finished", map, 0, 0);
					LogAction(-1, -1, "Voting for next map has finished. Nextmap: %s.", map);
					g_bMapVoteFinished = true;
				}
			}
			else
			{
				// We were actually cancelled. I guess we do nothing.
			}

			g_bMapVoteStarted = false;
		}
	}

	return 0;
}

// extends map while also notifying players and setting plugin data
void ExtendMap(int time = 0)
{
	if(time == 0)
	{
		time = RoundFloat(g_cvMapVoteExtendTime.FloatValue * 60);
	}

	ExtendMapTimeLimit(time);
	PrintToChatAll("%sThe map was extended for %.1f minutes", g_cPrefix, time / 60.0);

	g_bMapVoteStarted = false;
	g_bMapVoteFinished = false;
}

public void Shavit_OnDatabaseLoaded()
{
	GetTimerSQLPrefix(g_cSQLPrefix, sizeof(g_cSQLPrefix));
	g_hDatabase = view_as<Database2>(Shavit_GetDatabase());
}

void RemoveExcludesFromArrayList(ArrayList list, bool lowercase, char[][] exclude_prefixes, int exclude_count)
{
	int length = list.Length;

	for (int i = 0; i < length; i++)
	{
		char buffer[PLATFORM_MAX_PATH];
		list.GetString(i, buffer, sizeof(buffer));

		for (int x = 0; x < exclude_count; x++)
		{
			if (strncmp(buffer, exclude_prefixes[i], strlen(exclude_prefixes[i]), lowercase) == 0)
			{
				list.SwapAt(i, --length);
				break;
			}
		}
	}

	list.Resize(length);
}

void LoadMapList()
{
	g_aMapList.Clear();
	g_aAllMapsList.Clear();
	g_mMapList.Clear();

	g_iExcludePrefixesCount = ExplodeCvar(g_cvExcludePrefixes, g_cExcludePrefixesBuffers, sizeof(g_cExcludePrefixesBuffers), sizeof(g_cExcludePrefixesBuffers[]));

	GetTimerSQLPrefix(g_cSQLPrefix, sizeof(g_cSQLPrefix));

	switch(g_cvMapListType.IntValue)
	{
		case MapListZoned:
		{
			if (g_hDatabase == null)
			{
				g_hDatabase = GetTimerDatabaseHandle2();
			}

			char buffer[512];

			FormatEx(buffer, sizeof(buffer), "SELECT `map` FROM `%smapzones` WHERE `type` = 1 AND `track` = 0 ORDER BY `map`", g_cSQLPrefix);
			g_hDatabase.Query(LoadZonedMapsCallback, buffer, _, DBPrio_High);
		}
		case MapListFolder:
		{
			ReadMapsFolderArrayList(g_aMapList, true, false, true, true, g_cExcludePrefixesBuffers, g_iExcludePrefixesCount);
			CreateNominateMenu();
		}
		case MapListFile:
		{
			ReadMapList(g_aMapList, g_mapFileSerial, "default", MAPLIST_FLAG_CLEARARRAY);
			RemoveExcludesFromArrayList(g_aMapList, false, g_cExcludePrefixesBuffers, g_iExcludePrefixesCount);
			CreateNominateMenu();
		}
		case MapListMixed, MapListZonedMixedWithFolder:
		{
			if (g_hDatabase == null)
			{
				g_hDatabase = GetTimerDatabaseHandle2();
			}

			if (g_cvMapListType.IntValue == MapListMixed)
			{
				ReadMapList(g_aAllMapsList, g_mapFileSerial, "default", MAPLIST_FLAG_CLEARARRAY);
				RemoveExcludesFromArrayList(g_aAllMapsList, false, g_cExcludePrefixesBuffers, g_iExcludePrefixesCount);
			}
			else
			{
				ReadMapsFolderArrayList(g_aAllMapsList, true, false, true, true, g_cExcludePrefixesBuffers, g_iExcludePrefixesCount);
			}

			char buffer[512];
			FormatEx(buffer, sizeof(buffer), "SELECT `map` FROM `%smapzones` WHERE `type` = 1 AND `track` = 0 ORDER BY `map`", g_cSQLPrefix);
			g_hDatabase.Query(LoadZonedMapsCallbackMixed, buffer, _, DBPrio_High);
		}
	}
}

public void LoadZonedMapsCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("[shavit-mapchooser] - (LoadMapZonesCallback) - %s", error);
		return;
	}

	char map[PLATFORM_MAX_PATH];
	char map2[PLATFORM_MAX_PATH];
	while(results.FetchRow())
	{
		results.FetchString(0, map, sizeof(map));
		FindMapResult res = FindMap(map, map2, sizeof(map2));

		if (res == FindMap_Found || (g_cvMatchFuzzyMap.BoolValue && res == FindMap_FuzzyMatch))
		{
			g_aMapList.PushString(map2);
		}
	}

	CreateNominateMenu();
}

public void LoadZonedMapsCallbackMixed(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("[shavit-mapchooser] - (LoadMapZonesCallbackMixed) - %s", error);
		return;
	}

	char map[PLATFORM_MAX_PATH];

	for (int i = 0; i < g_aAllMapsList.Length; ++i)
	{
		g_aAllMapsList.GetString(i, map, sizeof(map));
		LessStupidGetMapDisplayName(map, map, sizeof(map));
		g_mMapList.SetValue(map, i, true);
	}

	while(results.FetchRow())
	{
		results.FetchString(0, map, sizeof(map));//db mapname
		LowercaseString(map);

		int index;
		if (g_mMapList.GetValue(map, index))
		{
			g_aMapList.PushString(map);
		}
	}

	CreateNominateMenu();
}

bool SMC_FindMap(const char[] mapname, char[] output, int maxlen)
{
	int length = g_aMapList.Length;
	for(int i = 0; i < length; i++)
	{
		char entry[PLATFORM_MAX_PATH];
		g_aMapList.GetString(i, entry, sizeof(entry));

		if(StrContains(entry, mapname) != -1)
		{
			strcopy(output, maxlen, entry);
			return true;
		}
	}

	return false;
}

void SMC_NominateMatches(int client, const char[] mapname)
{
	Menu subNominateMenu = new Menu(NominateMenuHandler);
	subNominateMenu.SetTitle("Nominate\nMaps matching \"%s\"\n ", mapname);
	bool isCurrentMap = false;
	bool isOldMap = false;
	char map[PLATFORM_MAX_PATH];
	char oldMapName[PLATFORM_MAX_PATH];
	StringMap tiersMap = Shavit_GetMapTiers();

	int length = g_aMapList.Length;
	for(int i = 0; i < length; i++)
	{
		char entry[PLATFORM_MAX_PATH];
		g_aMapList.GetString(i, entry, sizeof(entry));

		if(StrContains(entry, mapname) != -1)
		{
			if(StrEqual(entry, g_cMapName))
			{
				isCurrentMap = true;
				continue;
			}

			int idx = g_aOldMaps.FindString(entry);
			if(idx != -1)
			{
				isOldMap = true;
				oldMapName = entry;
				continue;
			}

			map = entry;
			char mapdisplay[PLATFORM_MAX_PATH];
			LessStupidGetMapDisplayName(entry, mapdisplay, sizeof(mapdisplay));

			int tier = 0;
			tiersMap.GetValue(mapdisplay, tier);

			char mapdisplay2[PLATFORM_MAX_PATH];
			FormatEx(mapdisplay2, sizeof(mapdisplay2), "%s | T%i", mapdisplay, tier);

			subNominateMenu.AddItem(entry, mapdisplay2);
		}
	}

	delete tiersMap;

	switch (subNominateMenu.ItemCount)
	{
		case 0:
		{
			if (isCurrentMap)
			{
				ReplyToCommand(client, "%s%t", g_cPrefix, "Can't Nominate Current Map");
			}
			else if (isOldMap)
			{
				ReplyToCommand(client, "%s%s %t", g_cPrefix, oldMapName, "Recently Played");
			}
			else
			{
				ReplyToCommand(client, "%s%t", g_cPrefix, "Map was not found", mapname);
			}

			if (subNominateMenu != INVALID_HANDLE)
			{
				CloseHandle(subNominateMenu);
			}
		}
		case 1:
		{
			Nominate(client, map);

			if (subNominateMenu != INVALID_HANDLE)
			{
				CloseHandle(subNominateMenu);
			}
		}
		default:
		{
			subNominateMenu.Display(client, MENU_TIME_FOREVER);
		}
	}
}

bool IsRTVEnabled()
{
	float time = GetGameTime();

	if(g_fLastMapvoteTime != 0.0)
	{
		if(time - g_fLastMapvoteTime > g_cvMapVoteRevoteTime.FloatValue * 60)
		{
			return true;
		}
	}
	else if(time - g_fMapStartTime > g_cvRTVDelayTime.FloatValue * 60)
	{
		return true;
	}
	return false;
}

void ClearRTV()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_bRockTheVote[i] = false;
	}
}

/* Timers */
public Action Timer_ChangeMap(Handle timer, DataPack data)
{
	char map[PLATFORM_MAX_PATH];
	data.Reset();
	data.ReadString(map, sizeof(map));

	ForceChangeLevel(map, "RTV Mapvote");
}

// ugh
public Action Timer_ChangeMap222(Handle timer, DataPack data)
{
	char map[PLATFORM_MAX_PATH];
	data.Reset();
	data.ReadString(map, sizeof(map));

	ForceChangeLevel(map, "sm_loadunzonedmap");
}

/* Commands */
public Action Command_Extend(int client, int args)
{
	int extendtime;
	if(args > 0)
	{
		char sArg[8];
		GetCmdArg(1, sArg, sizeof(sArg));
		extendtime = RoundFloat(StringToFloat(sArg) * 60);
	}
	else
	{
		extendtime = RoundFloat(g_cvMapVoteExtendTime.FloatValue * 60.0);
	}

	ExtendMap(extendtime);

	return Plugin_Handled;
}

public Action Command_ForceMapVote(int client, int args)
{
	if(g_bMapVoteStarted || g_bMapVoteFinished)
	{
		ReplyToCommand(client, "%sMap vote already %s", g_cPrefix, (g_bMapVoteStarted) ? "initiated" : "finished");
	}
	else
	{
		InitiateMapVote(MapChange_Instant);
	}

	return Plugin_Handled;
}

public Action Command_ReloadMaplist(int client, int args)
{
	LoadMapList();

	return Plugin_Handled;
}

public Action Command_Nominate(int client, int args)
{
	if(args < 1)
	{
		if (g_cvEnhancedMenu.BoolValue)
		{
			OpenEnhancedMenu(client);
		}
		else
		{
			OpenNominateMenu(client);
		}
		return Plugin_Handled;
	}

	char mapname[PLATFORM_MAX_PATH];
	GetCmdArg(1, mapname, sizeof(mapname));

	if (g_cvNominateMatches.BoolValue)
	{
		SMC_NominateMatches(client, mapname);
	}
	else {
		if(SMC_FindMap(mapname, mapname, sizeof(mapname)))
		{
			if(StrEqual(mapname, g_cMapName))
			{
				ReplyToCommand(client, "%s%t", "Can't Nominate Current Map");
				return Plugin_Handled;
			}

			int idx = g_aOldMaps.FindString(mapname);
			if(idx != -1)
			{
				ReplyToCommand(client, "%s%s %t", g_cPrefix, mapname, "Recently Played");
				return Plugin_Handled;
			}

			ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);
			Nominate(client, mapname);
			SetCmdReplySource(old);
		}
		else
		{
			ReplyToCommand(client, "%s%t", g_cPrefix, "Map was not found", mapname);
		}
	}

	return Plugin_Handled;
}

public Action Command_UnNominate(int client, int args)
{
	if(g_cNominatedMap[client][0] == '\0')
	{
		ReplyToCommand(client, "%sYou haven't nominated a map", g_cPrefix);
		return Plugin_Handled;
	}

	int idx = g_aNominateList.FindString(g_cNominatedMap[client]);
	if(idx != -1)
	{
		ReplyToCommand(client, "%sSuccessfully removed nomination for '%s'", g_cPrefix, g_cNominatedMap[client]);
		g_aNominateList.Erase(idx);
		g_cNominatedMap[client][0] = '\0';
	}

	return Plugin_Handled;
}

int SlowSortThatSkipsFolders(int index1, int index2, Handle array, Handle stupidgarbage)
{
	char a[PLATFORM_MAX_PATH], b[PLATFORM_MAX_PATH];
	ArrayList list = view_as<ArrayList>(array);
	list.GetString(index1, a, sizeof(a));
	list.GetString(index2, b, sizeof(b));
	return strcmp(a[FindCharInString(a, '/', true)+1], b[FindCharInString(b, '/', true)+1], true);
}

void CreateNominateMenu()
{
	delete g_hNominateMenu;
	g_hNominateMenu = new Menu(NominateMenuHandler);

	g_hNominateMenu.SetTitle("Nominate");
	StringMap tiersMap = Shavit_GetMapTiers();

	g_aMapList.SortCustom(SlowSortThatSkipsFolders);

	int length = g_aMapList.Length;
	for(int i = 0; i < length; ++i)
	{
		int style = ITEMDRAW_DEFAULT;
		char mapname[PLATFORM_MAX_PATH];
		g_aMapList.GetString(i, mapname, sizeof(mapname));

		if(StrEqual(mapname, g_cMapName))
		{
			style = ITEMDRAW_DISABLED;
		}

		int idx = g_aOldMaps.FindString(mapname);
		if(idx != -1)
		{
			style = ITEMDRAW_DISABLED;
		}

		char mapdisplay[PLATFORM_MAX_PATH];
		char mapdisplay2[PLATFORM_MAX_PATH];
		LessStupidGetMapDisplayName(mapname, mapdisplay, sizeof(mapdisplay));

		int tier = 0;
		tiersMap.GetValue(mapdisplay, tier);

		FormatEx(mapdisplay2, sizeof(mapdisplay2), "%s | T%i", mapdisplay, tier);
		g_hNominateMenu.AddItem(mapname, mapdisplay2, style);
	}

	delete tiersMap;

	if (g_cvEnhancedMenu.BoolValue)
	{
		CreateTierMenus();
	}
}

void CreateEnhancedMenu()
{
	delete g_hEnhancedMenu;

	g_hEnhancedMenu = new Menu(EnhancedMenuHandler);
	g_hEnhancedMenu.ExitButton = true;

	g_hEnhancedMenu.SetTitle("Nominate");
	g_hEnhancedMenu.AddItem("Alphabetic", "Alphabetic");

	for(int i = GetConVarInt(g_cvMinTier); i <= GetConVarInt(g_cvMaxTier); ++i)
	{
		if (GetMenuItemCount(g_aTierMenus.Get(i-GetConVarInt(g_cvMinTier))) > 0)
		{
			char tierDisplay[32];
			FormatEx(tierDisplay, sizeof(tierDisplay), "Tier %i", i);

			char tierString[16];
			IntToString(i, tierString, sizeof(tierString));
			g_hEnhancedMenu.AddItem(tierString, tierDisplay);
		}
	}
}

void CreateTierMenus()
{
	int min = GetConVarInt(g_cvMinTier);
	int max = GetConVarInt(g_cvMaxTier);

	if (max < min)
	{
		int temp = max;
		max = min;
		min = temp;
		SetConVarInt(g_cvMinTier, min);
		SetConVarInt(g_cvMaxTier, max);
	}

	InitTierMenus(min,max);
	StringMap tiersMap = Shavit_GetMapTiers();

	int length = g_aMapList.Length;
	for(int i = 0; i < length; ++i)
	{
		int style = ITEMDRAW_DEFAULT;
		char mapname[PLATFORM_MAX_PATH];
		g_aMapList.GetString(i, mapname, sizeof(mapname));

		char mapdisplay[PLATFORM_MAX_PATH];
		LessStupidGetMapDisplayName(mapname, mapdisplay, sizeof(mapdisplay));

		int mapTier = 0;
		mapTier = tiersMap.GetValue(mapdisplay, mapTier);

		if(StrEqual(mapname, g_cMapName))
		{
			style = ITEMDRAW_DISABLED;
		}

		int idx = g_aOldMaps.FindString(mapname);
		if(idx != -1)
		{
			style = ITEMDRAW_DISABLED;
		}

		char mapdisplay2[PLATFORM_MAX_PATH];
		FormatEx(mapdisplay2, sizeof(mapdisplay2), "%s | T%i", mapdisplay, mapTier);

		if (min <= mapTier <= max)
		{
			AddMenuItem(g_aTierMenus.Get(mapTier-min), mapname, mapdisplay2, style);
		}
	}

	delete tiersMap;

	CreateEnhancedMenu();
}

void InitTierMenus(int min, int max)
{
	g_aTierMenus.Clear();

	for(int i = min; i <= max; i++)
	{
		Menu TierMenu = new Menu(NominateMenuHandler);
		TierMenu.SetTitle("Nominate\nTier \"%i\" Maps\n ", i);
		TierMenu.ExitBackButton = true;

		g_aTierMenus.Push(TierMenu);
	}
}

void OpenNominateMenu(int client)
{
	if (g_cvEnhancedMenu.BoolValue)
	{
		g_hNominateMenu.ExitBackButton = true;
	}
	g_hNominateMenu.Display(client, MENU_TIME_FOREVER);
}

void OpenEnhancedMenu(int client)
{
	g_hEnhancedMenu.Display(client, MENU_TIME_FOREVER);
}

void OpenNominateMenuTier(int client, int tier)
{
	DisplayMenu(g_aTierMenus.Get(tier-GetConVarInt(g_cvMinTier)), client, MENU_TIME_FOREVER);
}

public int NominateMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char mapname[PLATFORM_MAX_PATH];
		menu.GetItem(param2, mapname, sizeof(mapname));

		Nominate(param1, mapname);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && GetConVarBool(g_cvEnhancedMenu))
	{
		OpenEnhancedMenu(param1);
	}
	else if (action == MenuAction_End)
	{
		if (menu != g_hNominateMenu && menu != INVALID_HANDLE && FindValueInArray(g_aTierMenus, menu) == -1)
		{
			CloseHandle(menu);
		}
	}
}

public int EnhancedMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char option[PLATFORM_MAX_PATH];
		menu.GetItem(param2, option, sizeof(option));

		if (StrEqual(option , "Alphabetic"))
		{
			OpenNominateMenu(client);
		}
		else
		{
			OpenNominateMenuTier(client, StringToInt(option));
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		OpenEnhancedMenu(client);
	}
}

void Nominate(int client, const char mapname[PLATFORM_MAX_PATH])
{
	int idx = g_aNominateList.FindString(mapname);
	if(idx != -1)
	{
		ReplyToCommand(client, "%s%t", g_cPrefix, "Map Already Nominated");
		return;
	}

	if(g_cNominatedMap[client][0] != '\0')
	{
		RemoveString(g_aNominateList, g_cNominatedMap[client]);
	}

	g_aNominateList.PushString(mapname);
	g_cNominatedMap[client] = mapname;
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	PrintToChatAll("%s%t", g_cPrefix, "Map Nominated", name, mapname);
}

public Action Command_RockTheVote(int client, int args)
{
	if(!IsRTVEnabled())
	{
		ReplyToCommand(client, "%s%t", g_cPrefix, "RTV Not Allowed");
	}
	else if(g_bMapVoteStarted)
	{
		ReplyToCommand(client, "%s%t", g_cPrefix, "RTV Started");
	}
	else if(g_bRockTheVote[client])
	{
		int needed = GetRTVVotesNeeded();
		ReplyToCommand(client, "%sYou have already RTVed, if you want to un-RTV use the command sm_unrtv (%i more %s needed)", g_cPrefix, needed, (needed == 1) ? "vote" : "votes");
	}
	else if(g_cvRTVMinimumPoints.IntValue != -1 && Shavit_GetPoints(client) <= g_cvRTVMinimumPoints.FloatValue)
	{
		ReplyToCommand(client, "%sYou must be a higher rank to RTV!", g_cPrefix);
	}
	else if(GetClientTeam(client) == CS_TEAM_SPECTATOR && !g_cvRTVAllowSpectators.BoolValue)
	{
		ReplyToCommand(client, "%sSpectators have been blocked from RTVing", g_cPrefix);
	}
	else
	{
		if (g_fLastRtvTime[client] && (GetEngineTime() - g_fLastRtvTime[client]) < g_cvAntiSpam.FloatValue)
		{
			ReplyToCommand(client, "%sStop doing that so fast", g_cPrefix);
			return Plugin_Handled;
		}

		g_fLastRtvTime[client] = GetEngineTime();

		RTVClient(client);
		CheckRTV(client);
	}

	return Plugin_Handled;
}

void CheckRTV(int client = 0)
{
	int needed = GetRTVVotesNeeded();
	int rtvcount = GetRTVCount();
	int total = GetRTVTotalNeeded();
	char name[MAX_NAME_LENGTH];

	if(client != 0)
	{
		GetClientName(client, name, sizeof(name));
	}
	if(needed > 0)
	{
		if(client != 0)
		{
			PrintToChatAll("%s%t", "RTV Requested", g_cPrefix, name, rtvcount, total);
		}
	}
	else
	{
		if(g_bMapVoteFinished)
		{
			char map[PLATFORM_MAX_PATH];
			GetNextMap(map, sizeof(map));

			if(client != 0)
			{
				PrintToChatAll("%s%N wants to rock the vote! Map will now change to %s ...", g_cPrefix, client, map);
			}
			else
			{
				PrintToChatAll("%sRTV vote now majority, map changing to %s ...", g_cPrefix, map);
			}

			SetNextMap(map);
			ChangeMapDelayed(map);
		}
		else
		{
			if(client != 0)
			{
				PrintToChatAll("%s%N wants to rock the vote! Map vote will now start ...", g_cPrefix, client);
			}
			else
			{
				PrintToChatAll("%sRTV vote now majority, map vote starting ...", g_cPrefix);
			}

			InitiateMapVote(MapChange_Instant);
		}
	}
}

public Action Command_UnRockTheVote(int client, int args)
{
	if(!IsRTVEnabled())
	{
		ReplyToCommand(client, "%sRTV has not been enabled yet", g_cPrefix);
	}
	else if(g_bMapVoteStarted || g_bMapVoteFinished)
	{
		ReplyToCommand(client, "%sMap vote already %s", g_cPrefix, (g_bMapVoteStarted) ? "initiated" : "finished");
	}
	else if(g_bRockTheVote[client])
	{
		if (g_fLastRtvTime[client] && (GetEngineTime() - g_fLastRtvTime[client]) < g_cvAntiSpam.FloatValue)
		{
			ReplyToCommand(client, "[SMC] Stop doing that so fast");
			return Plugin_Handled;
		}

		g_fLastRtvTime[client] = GetEngineTime();

		UnRTVClient(client);

		int needed = GetRTVVotesNeeded();
		if(needed > 0)
		{
			PrintToChatAll("%s%N no longer wants to rock the vote! (%i more votes needed)", g_cPrefix, client, needed);
		}
	}

	return Plugin_Handled;
}

public Action Command_NomList(int client, int args)
{
	if(g_aNominateList.Length < 1)
	{
		ReplyToCommand(client, "%sNo Maps Nominated", g_cPrefix);
		return Plugin_Handled;
	}

	Menu nomList = new Menu(Null_Callback);
	nomList.SetTitle("Nominated Maps");
	for(int i = 0; i < g_aNominateList.Length; ++i)
	{
		char buffer[PLATFORM_MAX_PATH];
		g_aNominateList.GetString(i, buffer, sizeof(buffer));

		nomList.AddItem(buffer, buffer, ITEMDRAW_DISABLED);
	}

	nomList.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int Null_Callback(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void FindUnzonedMapCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[shavit-mapchooser] - (FindUnzonedMapCallback) - %s", error);
		return;
	}

	StringMap mapList = new StringMap();

	g_iExcludePrefixesCount = ExplodeCvar(g_cvExcludePrefixes, g_cExcludePrefixesBuffers, sizeof(g_cExcludePrefixesBuffers), sizeof(g_cExcludePrefixesBuffers[]));

	ReadMapsFolderStringMap(mapList, true, true, true, true, g_cExcludePrefixesBuffers, g_iExcludePrefixesCount);

	char buffer[PLATFORM_MAX_PATH];

	while (results.FetchRow())
	{
		results.FetchString(0, buffer, sizeof(buffer));
		mapList.SetValue(buffer, true, true);
	}

	delete results;

	StringMapSnapshot snapshot = mapList.Snapshot();
	bool foundMap = false;

	for (int i = 0; i < snapshot.Length; i++)
	{
		snapshot.GetKey(i, buffer, sizeof(buffer));

		bool hasZones = false;
		mapList.GetValue(buffer, hasZones);

		if (!hasZones && !StrEqual(g_cMapName, buffer, false))
		{
			foundMap = true;
			break;
		}
	}

	delete snapshot;
	delete mapList;

	if (foundMap)
	{
		Shavit_PrintToChatAll("Loading unzoned map %s", buffer);

		DataPack dp;
		CreateDataTimer(1.0, Timer_ChangeMap222, dp);
		dp.WriteString(buffer);
	}
}

public Action Command_LoadUnzonedMap(int client, int args)
{
	char sQuery[256];
	FormatEx(sQuery, sizeof(sQuery), "SELECT DISTINCT map FROM %smapzones;", g_cSQLPrefix);
	g_hDatabase.Query(FindUnzonedMapCallback, sQuery, 0, DBPrio_Normal);
	return Plugin_Handled;
}

public Action BaseCommands_Command_Map(int client, int args)
{
	char map[PLATFORM_MAX_PATH];
	char displayName[PLATFORM_MAX_PATH];
	GetCmdArg(1, map, sizeof(map));
	LowercaseString(map);
	ReplaceString(map, sizeof(map), "\\", "/", true);

	g_iAutocompletePrefixesCount = ExplodeCvar(g_cvAutocompletePrefixes, g_cAutocompletePrefixesBuffers, sizeof(g_cAutocompletePrefixesBuffers), sizeof(g_cAutocompletePrefixesBuffers[]));

	StringMap maps = new StringMap();
	ReadMapsFolderStringMap(maps);

	int temp;
	bool foundMap;
	char buffer[PLATFORM_MAX_PATH];

	for (int i = -1; i < g_iAutocompletePrefixesCount; i++)
	{
		char prefix[12];

		if (i > -1)
		{
			prefix = g_cAutocompletePrefixesBuffers[i];
		}

		FormatEx(buffer, sizeof(buffer), "%s%s", prefix, map);

		if ((foundMap = maps.GetValue(buffer, temp)) != false)
		{
			map = buffer;
			break;
		}
	}

	if (!foundMap)
	{
		// do a smaller 

		StringMapSnapshot snapshot = maps.Snapshot();
		int length = snapshot.Length;

		for (int i = 0; i < length; i++)
		{
			snapshot.GetKey(i, buffer, sizeof(buffer));

			if (StrContains(buffer, map, true) != -1)
			{
				foundMap = true;
				map = buffer;
				break;
			}
		}

		delete snapshot;
	}

	delete maps;

	if (!foundMap)
	{
		ReplyToCommand(client, "[SM] %t", "Map was not found", map);
		return Plugin_Handled;
	}

	LessStupidGetMapDisplayName(map, displayName, sizeof(displayName));

	ShowActivity2(client, "[SM] ", "%t", "Changing map", displayName);
	LogAction(client, -1, "\"%L\" changed map to \"%s\"", client, map);

	DataPack dp;
	CreateDataTimer(3.0, BaseCommands_Timer_ChangeMap, dp);
	dp.WriteString(map);

	return Plugin_Handled;
}

public Action BaseCommands_Timer_ChangeMap(Handle timer, DataPack dp)
{
	char map[PLATFORM_MAX_PATH];

	dp.Reset();
	dp.ReadString(map, sizeof(map));

	ForceChangeLevel(map, "sm_map Command");

	return Plugin_Stop;
}

public Action Command_MapButFaster(int client, const char[] command, int args)
{
	if (!g_cvHijackMap.BoolValue || !CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP) || args < 1)
	{
		return Plugin_Continue;
	}

	BaseCommands_Command_Map(client, args);
	return Plugin_Stop;
}

public Action Command_Debug(int client, int args)
{
	g_bDebug = !g_bDebug;
	ReplyToCommand(client, "%sDebug mode: %s", g_cPrefix, g_bDebug ? "ENABLED" : "DISABLED");
	return Plugin_Handled;
}

void RTVClient(int client)
{
	g_bRockTheVote[client] = true;
	Call_StartForward(g_hForward_OnRTV);
	Call_PushCell(client);
	Call_Finish();
}

void UnRTVClient(int client)
{
	g_bRockTheVote[client] = false;
	Call_StartForward(g_hForward_OnUnRTV);
	Call_PushCell(client);
	Call_Finish();
}

/* Stocks */
stock void RemoveString(ArrayList array, const char[] target)
{
	int idx = array.FindString(target);
	if(idx != -1)
	{
		array.Erase(idx);
	}
}

stock void ChangeMapDelayed(const char[] map, float delay = 2.0)
{
	DataPack data;
	CreateDataTimer(delay, Timer_ChangeMap, data);
	data.WriteString(map);
}

stock int GetRTVVotesNeeded()
{
	int total = 0;
	int rtvcount = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			// dont count players that can't vote
			if(!g_cvRTVAllowSpectators.BoolValue && IsClientObserver(i))
			{
				continue;
			}

			if(g_cvRTVMinimumPoints.IntValue != -1 && Shavit_GetPoints(i) <= g_cvRTVMinimumPoints.FloatValue)
			{
				continue;
			}

			total++;
			if(g_bRockTheVote[i])
			{
				rtvcount++;
			}
		}
	}

	int Needed = RoundToCeil(total * (g_cvRTVRequiredPercentage.FloatValue / 100));

	// always clamp to 1, so if rtvcount is 0 it never initiates RTV
	if(Needed < 1)
	{
		Needed = 1;
	}

	return Needed - rtvcount;
}

stock int GetRTVCount()
{
	int rtvcount = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			// dont count players that can't vote
			if(!g_cvRTVAllowSpectators.BoolValue && IsClientObserver(i))
			{
				continue;
			}

			if(g_cvRTVMinimumPoints.IntValue != -1 && Shavit_GetPoints(i) <= g_cvRTVMinimumPoints.FloatValue)
			{
				continue;
			}

			if(g_bRockTheVote[i])
			{
				rtvcount++;
			}
		}
	}

	return rtvcount;
}

stock int GetRTVTotalNeeded()
{
	int total = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			// dont count players that can't vote
			if(!g_cvRTVAllowSpectators.BoolValue && IsClientObserver(i))
			{
				continue;
			}

			if(g_cvRTVMinimumPoints.IntValue != -1 && Shavit_GetPoints(i) <= g_cvRTVMinimumPoints.FloatValue)
			{
				continue;
			}

			total++;
		}
	}

	int Needed = RoundToCeil(total * (g_cvRTVRequiredPercentage.FloatValue / 100));

	// always clamp to 1, so if rtvcount is 0 it never initiates RTV
	if(Needed < 1)
	{
		Needed = 1;
	}
	return Needed;
}

void DebugPrint(const char[] message, any ...)
{
	if (!g_bDebug)
	{
		return;
	}

	char buffer[256];
	VFormat(buffer, sizeof(buffer), message, 2);

	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && CheckCommandAccess(i, "sm_smcdebug", ADMFLAG_RCON))
		{
			PrintToChat(i, buffer);
			return;
		}
	}
}