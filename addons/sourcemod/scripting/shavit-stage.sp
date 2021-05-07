/*
 * shavit's Timer - stage
 * by: Ciallo
*/

#define PLUGIN_NAME           "[shavit] Stage"
#define PLUGIN_AUTHOR         "Ciallo"
#define PLUGIN_DESCRIPTION    "A modified Stage plugin for fork's surf timer."
#define PLUGIN_VERSION        "0.1"
#define PLUGIN_URL            "https://github.com/Ciallo-Ani/surftimer"

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <shavit>

#pragma semicolon 1
#pragma newdecls required

#define gI_Styles 10
#define gS_None "N/A"

Database gH_SQL = null;
bool gB_Connected = false;
bool gB_MySQL = false;
bool gB_LinearMap;

char gS_Map[160];
int gI_Steamid[101];//this is a mysql index, i dont have any better implementation

int gI_LastStage[MAXPLAYERS + 1];
float gF_LeaveStageTime[MAXPLAYERS + 1];
float gF_StageTime[MAXPLAYERS + 1];

float gF_WrcpTime[MAX_STAGES + 1][gI_Styles];
char gS_WrcpName[MAX_STAGES + 1][gI_Styles][MAX_NAME_LENGTH];
float gF_PrStageTime[MAXPLAYERS + 1][MAX_STAGES + 1][gI_Styles];

int gI_StyleChoice[MAXPLAYERS + 1];
int gI_StageChoice[MAXPLAYERS + 1];
char gS_MapChoice[MAXPLAYERS + 1][160];
bool gB_DeleteMaptop[MAXPLAYERS + 1];
bool gB_DeleteWRCP[MAXPLAYERS + 1];
bool gB_InStageZone[MAXPLAYERS + 1];
bool gB_TimerSetting[MAXPLAYERS + 1];

// misc cache
bool gB_Late = false;

// table prefix
char gS_MySQLPrefix[32];

// timer settings
stylestrings_t gS_StyleStrings[gI_Styles];
chatstrings_t gS_ChatStrings;

Handle gH_Forwards_EnterStage = null;
Handle gH_Forwards_LeaveStage = null;
Handle gH_Forwards_OnWRCP = null;
Handle gH_Forwards_OnWRCPDeleted = null;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Shavit_GetClientStageTime", Native_GetClientStageTime);
	CreateNative("Shavit_SetClientStageTime", Native_SetClientStageTime);
	CreateNative("Shavit_ReloadWRCPs", Native_ReloadWRCPs);
	CreateNative("Shavit_GetWRCPName", Native_GetWRCPName);
	// registers library, check "bool LibraryExists(const char[] name)" in order to use with other plugins
	RegPluginLibrary("shavit-stage");

	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("shavit-stage.phrases");

	HookEvent("player_death", Player_Death);

	//wrcp
	RegConsoleCmd("sm_wrcp", Command_WRCP, "Show WRCP menu, Select a style and a stage");
	RegConsoleCmd("sm_wrcps", Command_WRCP, "Alias of sm_wrcp");
	RegConsoleCmd("sm_srcp", Command_WRCP, "Alias of sm_wrcp");
	RegConsoleCmd("sm_srcps", Command_WRCP, "Alias of sm_wrcp");
	//maptop
	RegConsoleCmd("sm_mtop", Command_Maptop, "Actually it's alias of sm_wrcp");
	RegConsoleCmd("sm_maptop", Command_Maptop, "Alias of sm_mtop");

	//delete
	RegAdminCmd("sm_delwrcp", Command_DeleteWRCP, ADMFLAG_RCON, "Delete a WRCP. Actually it's alias of sm_wrcp");
	RegAdminCmd("sm_delwrcps", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_delsrcp", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_delsrcps", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_deletewrcp", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_deletewrcps", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_deletesrcp", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");
	RegAdminCmd("sm_deletesrcps", Command_DeleteWRCP, ADMFLAG_RCON, "Alias of sm_delwrcp");

	RegAdminCmd("sm_delmtop", Command_DeleteMaptop, ADMFLAG_RCON, "Delete a stage record. Actually it's alias of sm_delwrcp");
	RegAdminCmd("sm_delmaptop", Command_DeleteMaptop, ADMFLAG_RCON, "Alias of sm_delmtop");
	RegAdminCmd("sm_deletemtop", Command_DeleteMaptop, ADMFLAG_RCON, "Alias of sm_delmtop");
	RegAdminCmd("sm_deletemaptop", Command_DeleteMaptop, ADMFLAG_RCON, "Alias of sm_delmtop");
	//TODO:i dont care how many reg has, just need it if neccessary xD

	RegAdminCmd("sm_test", Command_Test, ADMFLAG_RCON, "do stuff");

	gH_Forwards_EnterStage = CreateGlobalForward("Shavit_OnEnterStage", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_LeaveStage = CreateGlobalForward("Shavit_OnLeaveStage", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	gH_Forwards_OnWRCP = CreateGlobalForward("Shavit_OnWRCP", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_String);
	gH_Forwards_OnWRCPDeleted = CreateGlobalForward("Shavit_OnWRCPDeleted", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_String);

	SQL_DBConnect();
}

public void OnClientPostAdminCheck(int client)
{
	gI_LastStage[client] = 1;
	for(int i = 1; i <= MAX_STAGES; i++)//init
	{
		for(int j = 0; j < gI_Styles; j++)
		{
			gF_PrStageTime[client][i][j] = 0.0;
		}
	}

	if(!gB_LinearMap)
	{
		LoadPR(client);
	}
}

public void OnMapStart()
{
	if(!gB_Connected)
	{
		return;
	}

	if(Shavit_GetMapStages() == 1)
	{
		gB_LinearMap = true;
		return;
	}

	else
	{
		gB_LinearMap = false;
	}

	GetCurrentMap(gS_Map, 160);
	GetMapDisplayName(gS_Map, gS_Map, 160);

	Reset(Shavit_GetMapStages(), gI_Styles, true);

	if(gB_Late)
	{
		Shavit_OnStyleConfigLoaded(gI_Styles);
		Shavit_OnChatConfigLoaded();
	}
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("shavit-zones"))
	{
		SetFailState("shavit-zones is required for the plugin to work.");
	}
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStrings(i, sStyleName, gS_StyleStrings[i].sStyleName, sizeof(stylestrings_t::sStyleName));
	}
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStrings(sMessagePrefix, gS_ChatStrings.sPrefix, sizeof(chatstrings_t::sPrefix));
	Shavit_GetChatStrings(sMessageText, gS_ChatStrings.sText, sizeof(chatstrings_t::sText));
	Shavit_GetChatStrings(sMessageWarning, gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning));
	Shavit_GetChatStrings(sMessageVariable, gS_ChatStrings.sVariable, sizeof(chatstrings_t::sVariable));
	Shavit_GetChatStrings(sMessageVariable2, gS_ChatStrings.sVariable2, sizeof(chatstrings_t::sVariable2));
	Shavit_GetChatStrings(sMessageStyle, gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle));
}

void Reset(int stage, int style, bool all = false)
{
	if(all)
	{
		for(int i = 1; i <= stage; i++)
		{
			for(int j = 0; j < style; j++)
			{
				gF_WrcpTime[i][j] = -1.0;
				strcopy(gS_WrcpName[i][j], 16, gS_None);
			}
		}
	}
	else
	{
		gF_WrcpTime[stage][style] = -1.0;
		strcopy(gS_WrcpName[stage][style], 16, gS_None);
	}

	LoadWRCP();
}

public Action Command_Test(int client, int args)
{

	return Plugin_Handled;
}

public Action Command_WRCP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteWRCP[client] = false;

	if(args == 0)
	{
		if(gB_LinearMap)
		{
			Shavit_PrintToChat(client, "This is a linear map");

			return Plugin_Handled;
		}

		OpenWRCPMenu(client, gS_Map);
	}

	else
	{
		char sMap[160];
		GetCmdArg(1, sMap, 160);
		OpenWRCPMenu(client, sMap);
	}

	return Plugin_Handled;
}

public Action Command_DeleteWRCP(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteWRCP[client] = true;

	if(args == 0)
	{
		if(gB_LinearMap)
		{
			Shavit_PrintToChat(client, "This is a linear map");

			return Plugin_Handled;
		}

		OpenWRCPMenu(client, gS_Map);
	}

	else
	{
		char sMap[160];
		GetCmdArg(1, sMap, 160);
		OpenWRCPMenu(client, sMap);
	}

	return Plugin_Handled;
}

void OpenWRCPMenu(int client, const char[] map)
{
	strcopy(gS_MapChoice[client], 160, map);

	Menu menu = new Menu(WRCPMenu_Handler);
	menu.SetTitle("%T", "WrcpMenuTitle-Style", client);

	for(int i = 0; i < gI_Styles; i++)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%s", gS_StyleStrings[i].sStyleName);

		menu.AddItem("", sDisplay);
	}

	menu.Display(client, -1);
}

public int WRCPMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StyleChoice[param1] = param2;

		WRCP_StageMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void WRCP_StageMenu(int client)
{
	Menu stagemenu = new Menu(WRCPMenu2_Handler);
	stagemenu.SetTitle("%T", "WrcpMenuTitle-Stage", client);

	for(int i = 1; i <= Shavit_GetMapStages(); i++)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%T %d", "WrcpMenuItem-Stage", client, i);

		stagemenu.AddItem("", sDisplay);
	}

	stagemenu.ExitBackButton = true;
	stagemenu.Display(client, -1);
}

public int WRCPMenu2_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StageChoice[param1] = param2 + 1;
		
		int stage = gI_StageChoice[param1];
		int style = gI_StyleChoice[param1];
		float time = gF_WrcpTime[stage][style];
		char sName[MAX_NAME_LENGTH];
		strcopy(sName, MAX_NAME_LENGTH, gS_WrcpName[stage][style]);

		if(gB_DeleteWRCP[param1])
		{
			DeleteWRCPConfirm(param1);
		}

		else
		{
			char sMessage[255];
			if(time > 0.0)
			{
				FormatEx(sMessage, 255, "%T", "Chat-WRCP", param1, 
					gS_ChatStrings.sVariable, sName, gS_ChatStrings.sText, 
					gS_ChatStrings.sVariable2, stage, gS_ChatStrings.sText, 
					gS_ChatStrings.sVariable2, time, gS_ChatStrings.sText);
			}
			else
			{
				FormatEx(sMessage, 255, "%T", "Chat-WRCP-NoRecord", param1, 
				gS_ChatStrings.sVariable2, stage, gS_ChatStrings.sText, 
				gS_ChatStrings.sVariable, style, gS_ChatStrings.sText);
			}
			Shavit_PrintToChat(param1, "%s", sMessage);
		}
	}

	else if(action == MenuAction_Cancel)
	{
		OpenWRCPMenu(param1, gS_MapChoice[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void DeleteWRCPConfirm(int client)
{
	Menu menu = new Menu(DeleteWRCPMenu_Handler);

	char sTitle[64];
	FormatEx(sTitle, 64, "%T", "DeleteWrcpMenuTitle-Confirm", client, gI_StageChoice[client], gI_StyleChoice[client]);
	menu.SetTitle(sTitle);

	menu.AddItem("", "Yes");
	menu.AddItem("", "No");

	menu.ExitBackButton = true;
	menu.Display(client, -1);
}

public int DeleteWRCPMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(param2 == 0)
		{
			int stage = gI_StageChoice[param1];
			int style = gI_StyleChoice[param1];

			char sQuery[256];//i write 2 callbacks in order to find wrcp auth index, but seems to have a better implementation(mysql syntax)
			FormatEx(sQuery, 256, 
					"SELECT auth, time FROM %sstage " ...
					"WHERE (stage = '%d' AND style = '%d') AND map = '%s' " ...
					"ORDER BY time ASC " ...
					"LIMIT 1;", 
			gS_MySQLPrefix, stage, style, gS_Map);

			gH_SQL.Query(SQL_DeleteWRCP_Callback, sQuery, GetClientSerial(param1), DBPrio_High);
		}
	}

	else if(action == MenuAction_Cancel)
	{
		WRCP_StageMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_DeleteWRCP_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);

	if(results == null)
	{
		LogError("Timer (single WRCP delete) SQL query failed. Reason: %s", error);

		return;
	}

	int stage = gI_StageChoice[client];
	int style = gI_StyleChoice[client];
	int index = -1;
	if(results.FetchRow())
	{
		index = results.FetchInt(0);
	}

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(index);

	char sQuery[256];
	FormatEx(sQuery, 256, "DELETE FROM %sstage WHERE (stage = '%d' AND style = '%d') AND (auth = '%d' AND map = '%s');", 
			gS_MySQLPrefix, stage, style, index, gS_Map);
	
	gH_SQL.Query(SQL_DeleteWRCP_Callback2, sQuery, dp, DBPrio_High);
}

public void SQL_DeleteWRCP_Callback2(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int steamid = dp.ReadCell();

	delete dp;

	int stage = gI_StageChoice[client];
	int style = gI_StyleChoice[client];

	if(results == null)
	{
		LogError("Timer (single WRCP delete2) SQL query failed. Reason: %s", error);

		return;
	}

	LoadWRCP();
	Reset(stage, style);

	Call_StartForward(gH_Forwards_OnWRCPDeleted);
	Call_PushCell(stage);
	Call_PushCell(style);
	Call_PushCell(steamid);
	Call_PushString(gS_Map);
	Call_Finish();

	Shavit_PrintToChat(client, "%T", "WRCPDeleteSuccessful", client, gS_ChatStrings.sText, 
		gS_ChatStrings.sVariable, stage, gS_ChatStrings.sText, 
		gS_ChatStrings.sVariable2, style, gS_ChatStrings.sText);
}

public Action Command_Maptop(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteMaptop[client] = false;

	if(args == 0)
	{
		if(gB_LinearMap)
		{
			Shavit_PrintToChat(client, "This is a linear map");

			return Plugin_Handled;
		}

		OpenMaptopMenu(client, gS_Map);
	}

	else
	{
		char sMap[128];
		GetCmdArg(1, sMap, 128);
		OpenMaptopMenu(client, sMap);
	}

	return Plugin_Handled;
}

public Action Command_DeleteMaptop(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_DeleteMaptop[client] = true;

	if(args == 0)
	{
		if(gB_LinearMap)
		{
			Shavit_PrintToChat(client, "This is a linear map");

			return Plugin_Handled;
		}
		
		OpenMaptopMenu(client, gS_Map);
	}

	else
	{
		char sMap[128];
		GetCmdArg(1, sMap, 128);
		OpenMaptopMenu(client, sMap);
	}

	return Plugin_Handled;
}

void OpenMaptopMenu(int client, const char[] map)
{
	strcopy(gS_MapChoice[client], 160, map);

	Menu menu = new Menu(MaptopMenu_Handler);
	menu.SetTitle("%T", "WrcpMenuTitle-Style", client);

	for(int i = 0; i < gI_Styles; i++)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%s", gS_StyleStrings[i].sStyleName);

		menu.AddItem("", sDisplay);
	}

	menu.Display(client, -1);
}

public int MaptopMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StyleChoice[param1] = param2;

		Maptop_StageMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void Maptop_StageMenu(int client)
{
	Menu stagemenu = new Menu(MaptopMenu2_Handler);
	stagemenu.SetTitle("%T", "WrcpMenuTitle-Stage", client);

	for(int i = 1; i <= Shavit_GetMapStages(); i++)
	{
		char sDisplay[64];
		FormatEx(sDisplay, 64, "%T %d", "WrcpMenuItem-Stage", client, i);

		stagemenu.AddItem("", sDisplay);
	}

	stagemenu.ExitBackButton = true;
	stagemenu.Display(client, -1);
}

public int MaptopMenu2_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_StageChoice[param1] = param2 + 1;
		
		int stage = gI_StageChoice[param1];
		int style = gI_StyleChoice[param1];

		DataPack dp = new DataPack();
		dp.WriteCell(GetClientSerial(param1));
		dp.WriteCell(stage);
		dp.WriteCell(style);
		dp.WriteString(gS_MapChoice[param1]);

		char sQuery[512];
		FormatEx(sQuery, 512, 
				"SELECT p1.auth, p1.time, p1.completions, p2.name FROM %sstage p1 " ...
				"JOIN (SELECT auth, name FROM %susers) p2 " ...
				"ON p1.auth = p2.auth " ...
				"WHERE (stage = '%d' AND style = '%d') AND map = '%s' " ...
				"ORDER BY p1.time ASC " ...
				"LIMIT 100;", 
				gS_MySQLPrefix, gS_MySQLPrefix, stage, style, gS_MapChoice[param1]);
		gH_SQL.Query(SQL_Maptop_Callback, sQuery, dp, DBPrio_High);
	}

	else if(action == MenuAction_Cancel)
	{
		OpenMaptopMenu(param1, gS_MapChoice[param1]);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_Maptop_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int stage = dp.ReadCell();
	int style = dp.ReadCell();
	char sMap[160];
	dp.ReadString(sMap, 160);

	delete dp;

	if(results == null)
	{
		LogError("Timer (GetWrcp) SQL query failed. Reason: %s", error);
		return;
	}

	Menu maptopmenu = new Menu(MaptopMenu3_Handler);

	char sTitle[128];
	if(gB_DeleteMaptop[client])
	{
		FormatEx(sTitle, 128, "%T", "DeleteMaptopMenuTitle-Maptop", client, sMap, stage);
	}
	else
	{
		FormatEx(sTitle, 128, "%T", "WrcpMenuTitle-Maptop", client, sMap, stage);
	}

	maptopmenu.SetTitle(sTitle);

	int iCount = 0;

	while(results.FetchRow())
	{
		if(++iCount <= 100)
		{
			// 0 - steamid (mysql delete index)
			gI_Steamid[iCount] = results.FetchInt(0);

			// 1 - time
			float time = results.FetchFloat(1);
			char sTime[32];
			FormatSeconds(time, sTime, 32, true);

			// compareTime
			float compareTime = time - gF_WrcpTime[stage][style];
			char sCompareTime[32];
			FormatSeconds(compareTime, sCompareTime, 32, true);

			// 2 - completions
			int completions = results.FetchInt(2);

			// 3 - name
			char sName[MAX_NAME_LENGTH];
			results.FetchString(3, sName, MAX_NAME_LENGTH);

			char sDisplay[128];
			FormatEx(sDisplay, 128, "#%d | %s (+%s) - %s (%d)", iCount, sTime, sCompareTime, sName, completions, client);
			maptopmenu.AddItem("", sDisplay, ITEMDRAW_DEFAULT);
		}
	}

	if(maptopmenu.ItemCount == 0)
	{
		char sNoRecords[64];
		FormatEx(sNoRecords, 64, "%t", "WrcpMenuItem-NoRecord", client);

		maptopmenu.AddItem("-1", sNoRecords, ITEMDRAW_DISABLED);
	}

	maptopmenu.ExitBackButton = true;
	maptopmenu.Display(client, -1);
}

public int MaptopMenu3_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(gB_DeleteMaptop[param1])
		{
			gB_DeleteMaptop[param1] = false;

			int index = gI_Steamid[param2 + 1];
			int stage = gI_StageChoice[param1];
			int style = gI_StyleChoice[param1];

			char sQuery[256];
			FormatEx(sQuery, 256, "DELETE FROM %sstage WHERE (stage = '%d' AND style = '%d') AND (auth = '%d' AND map = '%s');", 
					gS_MySQLPrefix, stage, style, index, gS_MapChoice[param1]);

			DataPack dp = new DataPack();
			dp.WriteCell(GetClientSerial(param1));
			dp.WriteCell(stage);
			dp.WriteCell(style);

			gH_SQL.Query(SQL_DeleteMaptop_Callback, sQuery, dp);
		}
		else
		{
			return 0;//do stuff here
		}
	}

	else if(action == MenuAction_Cancel)
	{
		Maptop_StageMenu(param1);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public void SQL_DeleteMaptop_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int client = GetClientFromSerial(data.ReadCell());
	int stage = data.ReadCell();
	int style = data.ReadCell();

	delete data;

	if(results == null)
	{
		LogError("Timer (single stage record delete) SQL query failed. Reason: %s", error);

		return;
	}

	LoadWRCP();
	Reset(stage, style);

	Shavit_PrintToChat(client, "%T", "StageRecordDeleteSuccessful", client, gS_ChatStrings.sText, 
		gS_ChatStrings.sVariable, stage, gS_ChatStrings.sText, 
		gS_ChatStrings.sVariable2, style, gS_ChatStrings.sText);
}

public void Shavit_OnRestart(int client, int track)
{
	gF_StageTime[client] = 0.0;
	gI_LastStage[client] = 1;
}

public void Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	gI_LastStage[client] = 1;
}

public void Shavit_OnProcessMovementPost(int client)
{
	if(!gB_InStageZone[client] && !gB_TimerSetting[client])
	{
		gF_StageTime[client] = GetGameTime() - gF_LeaveStageTime[client];
	}
}

public Action Shavit_OnStart(int client)
{
	ResetTimer(client);
}

public Action Shavit_OnStage(int client)
{
	ResetTimer(client);
}

public Action Shavit_OnEndZone(int client)
{
	ResetTimer(client);
}

void ResetTimer(int client)
{
	gB_InStageZone[client] = true;
	gB_TimerSetting[client] = false;
	gF_StageTime[client] = 0.0;
}

public void Shavit_OnEnterZone(int client, int type, int track, int id, int entity, int data)
{
	if(track != Track_Main || gB_LinearMap)
	{
		return;
	}

	if(type == Zone_Stage || type == Zone_Start || type == Zone_Start_2 || type == Zone_End || type == Zone_End_2)
	{
		int stage = Shavit_GetClientStage(client);
		int style = Shavit_GetBhopStyle(client);

		Call_StartForward(gH_Forwards_EnterStage);
		Call_PushCell(client);
		Call_PushCell(stage);
		Call_PushCell(style);
		Call_Finish();

		if(gF_StageTime[client] > 0.0)
		{
			char sMessage[255];
			char sTime[32];

			if(stage > gI_LastStage[client] && stage - gI_LastStage[client] == 1)//1--->2 2--->3 ... n--->n+1
			{
				if(stage == 2)
				{
					gF_StageTime[client] = Shavit_GetClientTime(client);//pretend that i'm getting a accurent time
				}

				OnWRCPCheck(client, stage - 1, style, gF_StageTime[client]);//check if wrcp
				Insert_WRCP_PR(client, stage - 1, style, gF_StageTime[client]);//check if wrcp and pr, insert or update

				FormatSeconds(gF_StageTime[client], sTime, 32, true);
				FormatEx(sMessage, 255, "%T", "ZoneStageTime", client, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, stage, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, sTime, gS_ChatStrings.sText);
			}

			else
			{
				if(stage - gI_LastStage[client] <= 0)
				{
					return;
				}

				FormatEx(sMessage, 255, "%T", "ZoneStageAvoidSkip", client, gS_ChatStrings.sWarning, gS_ChatStrings.sWarning);
			}

			Shavit_PrintToChat(client, "%s", sMessage);

			//total time
			FormatSeconds(Shavit_GetClientTime(client), sTime, 32, true);
			FormatEx(sMessage, 255, "%T", "ZoneStageEnterTotalTime", 
				client, gS_ChatStrings.sText, gS_ChatStrings.sVariable2, sTime, gS_ChatStrings.sText);
			Shavit_PrintToChat(client, "%s", sMessage);
		}

		gI_LastStage[client] = stage;
	}
}

public void Shavit_OnLeaveZone(int client, int type, int track, int id, int entity, int data)
{
	if(track != Track_Main || gB_LinearMap)
	{
		return;
	}

	if(type == Zone_Stage || type == Zone_Start || type == Zone_Start_2)
	{
		gB_InStageZone[client] = false;
		gF_LeaveStageTime[client] = GetGameTime();

		int stage = Shavit_GetClientStage(client);
		int style = Shavit_GetBhopStyle(client);

		Call_StartForward(gH_Forwards_LeaveStage);
		Call_PushCell(client);
		Call_PushCell(stage);
		Call_PushCell(style);
		Call_Finish();

		/* //TODO:prestrafe
		bool onGround = false;
		if(GetEntityFlags(client) & FL_ONGROUND)
		{
			onGround = true;
		}

		if(!onGround)
		{
			float fVelocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
			float prespeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0) + Pow(fVelocity[2], 2.0));

			char sMessage[64];
			FormatEx(sMessage, 255, "%T", "ZoneStagePrestrafe", client, gS_ChatStrings.sText, gS_ChatStrings.sVariable, prespeed, gS_ChatStrings.sText);
			Shavit_PrintToChat(client, "%s", sMessage);
		} */
	}
}

void OnWRCPCheck(int client, int stage, int style, float time)
{
	if(gF_StageTime[client] < gF_WrcpTime[stage][style] || gF_WrcpTime[stage][style] == -1.0)//check if wrcp
	{
		char sMessage[255];
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		FormatEx(sMessage, 255, "%T", "OnWRCP", client, 
			gS_ChatStrings.sVariable, sName, gS_ChatStrings.sText, 
			gS_ChatStrings.sVariable2, stage, gS_ChatStrings.sText, 
			gS_ChatStrings.sVariable2, time, gS_ChatStrings.sText);
		Shavit_PrintToChatAll("%s", sMessage);


		Call_StartForward(gH_Forwards_OnWRCP);
		Call_PushCell(client);
		Call_PushCell(stage);
		Call_PushCell(style);
		Call_PushCell(GetSteamAccountID(client));
		Call_PushFloat(time);
		Call_PushString(gS_Map);
		Call_Finish();
	}
}

void Insert_WRCP_PR(int client, int stage, int style, float time)
{
	char sQuery[512];
	FormatEx(sQuery, 512, "SELECT completions FROM %sstage WHERE (stage = '%d' AND style = '%d') AND (map = '%s' AND auth = '%d');", 
			gS_MySQLPrefix, stage, style, gS_Map, GetSteamAccountID(client));

	DataPack dp = new DataPack();
	dp.WriteCell(GetClientSerial(client));
	dp.WriteCell(stage);
	dp.WriteCell(style);
	dp.WriteFloat(time);

	gH_SQL.Query(SQL_WRCP_PR_Check_Callback, sQuery, dp, DBPrio_High);
}

public void SQL_WRCP_PR_Check_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();

	int client = GetClientFromSerial(dp.ReadCell());
	int stage = dp.ReadCell();
	int style = dp.ReadCell();
	float time = dp.ReadFloat();
	delete dp;

	if(results == null)
	{
		LogError("Timer SQL query failed. Reason: %s", error);

		return;
	}

	char sQuery[512];

	if(results.FetchRow())
	{
		float prTime = gF_PrStageTime[client][stage][style];
		if(time < prTime || prTime == 0.0)
		{
			FormatEx(sQuery, 512,
			"UPDATE `%sstage` SET time = %f, date = %d, completions = completions + 1 WHERE (stage = '%d' AND style = '%d') AND (map = '%s' AND auth = '%d');", 
			gS_MySQLPrefix, time, GetTime(), stage, style, gS_Map, GetSteamAccountID(client));
		}
		else
		{
			FormatEx(sQuery, 512,
			"UPDATE `%sstage` SET completions = completions + 1 WHERE (stage = '%d' AND style = '%d') AND (map = '%s' AND auth = '%d');", 
			gS_MySQLPrefix, stage, style, gS_Map, GetSteamAccountID(client));
		}
	}
	else
	{
		FormatEx(sQuery, 512,
		"INSERT INTO `%sstage` (auth, map, time, style, stage, date, completions) VALUES (%d, '%s', %f, %d, %d, %d, 1);",
		gS_MySQLPrefix, GetSteamAccountID(client), gS_Map, time, style, stage, GetTime());
	}

	gH_SQL.Query(SQL_PrCheck_Callback2, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_PrCheck_Callback2(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Insert PR error! Reason: %s", error);

		return;
	}

	LoadPR(GetClientFromSerial(data));
	LoadWRCP();
}

void LoadPR(int client)
{
	char sQuery[512];
	FormatEx(sQuery, 512, 
			"SELECT stage, style, time FROM %sstage WHERE auth = %d AND map = '%s';", 
		gS_MySQLPrefix, GetSteamAccountID(client), gS_Map);

	gH_SQL.Query(SQL_LoadPR_Callback, sQuery, GetClientSerial(client), DBPrio_High);
}

public void SQL_LoadPR_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (LoadPR) SQL query failed. Reason: %s", error);
		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	while(results.FetchRow())
	{
		int stage = results.FetchInt(0);
		int style = results.FetchInt(1);
		float time = results.FetchFloat(2);
		gF_PrStageTime[client][stage][style] = time;
	}
}

void LoadWRCP()
{
	char sQuery[512];
	FormatEx(sQuery, 512, 
			"SELECT p1.auth, p1.stage, p1.style, p1.time, p2.name FROM %sstage p1 " ...
			"JOIN (SELECT auth, name FROM %susers) p2 " ...
			"ON p1.auth = p2.auth " ...
			"WHERE map = '%s' " ...
			"ORDER BY p1.time ASC;", 
			gS_MySQLPrefix, gS_MySQLPrefix, gS_Map);

	gH_SQL.Query(SQL_LoadWRCP_Callback, sQuery, 0, DBPrio_High);
}

public void SQL_LoadWRCP_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (LoadWRCP) SQL query failed. Reason: %s", error);
		return;
	}

	while(results.FetchRow())
	{
		int stage = results.FetchInt(1);
		int style = results.FetchInt(2);
		float time = results.FetchFloat(3);
		if(time < gF_WrcpTime[stage][style] || gF_WrcpTime[stage][style] == -1.0)
		{
			gF_WrcpTime[stage][style] = time;

			results.FetchString(4, gS_WrcpName[stage][style], MAX_NAME_LENGTH);
		}
	}
}

public int Native_GetClientStageTime(Handle handler, int numParams)
{
	return view_as<int>(gF_StageTime[GetNativeCell(1)]);
}

public int Native_SetClientStageTime(Handle handler, int numParams)
{
	gF_StageTime[GetNativeCell(1)] = view_as<float>(GetNativeCell(2));
	gB_TimerSetting[GetNativeCell(1)] = true;
}

public int Native_ReloadWRCPs(Handle handler, int numParams)
{
	OnMapStart();
}

public int Native_GetWRCPName(Handle handler, int numParams)
{
	SetNativeString(2, gS_WrcpName[GetNativeCell(4)][GetNativeCell(1)], GetNativeCell(3));
}

void SQL_DBConnect()
{
	GetTimerSQLPrefix(gS_MySQLPrefix, 32);
	gH_SQL = GetTimerDatabaseHandle();
	gB_MySQL = IsMySQLDatabase(gH_SQL);

	char sQuery[1024];
	FormatEx(sQuery, 1024, 
			"CREATE TABLE IF NOT EXISTS `%sstage` (`id` INT NOT NULL AUTO_INCREMENT, `auth` INT, `map` VARCHAR(128), `time` FLOAT, `style` TINYINT, `stage` INT, `date` INT, `completions` INT, PRIMARY KEY (`id`))%s;",
			gS_MySQLPrefix, (gB_MySQL) ? " ENGINE=INNODB" : "");

	gH_SQL.Query(SQL_CreateTable_Callback, sQuery);
}

public void SQL_CreateTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (wrcp module) error! 'stage' table creation failed. Reason: %s", error);

		return;
	}

	gB_Connected = true;

	OnMapStart();
}