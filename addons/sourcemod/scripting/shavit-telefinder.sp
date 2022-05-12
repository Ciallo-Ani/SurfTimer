#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <shavit/core>

#pragma semicolon 1
#pragma newdecls required

enum
{
	TRIGGER,
	TELEDES,
	MAX_TELES,
};

methodmap MenuEx < Menu
{
	public void PushEnt(int entity)
	{
		char sInfo[16];
		IntToString(entity, sInfo, sizeof(sInfo));

		char sName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		this.AddItem(sInfo, sName);
	}
}

bool gB_Late = false;


MenuEx gH_TriggersMenu = null;
MenuEx gH_TeleDestinationMenu = null;
int gI_MenuSection[MAXPLAYERS+1][MAX_TELES];



public Plugin myinfo = 
{
	name = "Teleport Destination Finder",
	author = "Ciallo-Ani",
	description = "Shows a list of teleport destination menu.",
	version = SHAVIT_VERSION,
	url = "null"
};



public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_Late = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("shavit-misc.phrases");

	RegConsoleCmd("sm_findtele", Command_FindTeleDestination, "Show teleport destinations menu");
	RegConsoleCmd("sm_findteles", Command_FindTeleDestination, "Show teleport destinations menu. Alias of sm_findtele");
	RegConsoleCmd("sm_telefinder", Command_FindTeleDestination, "Show teleport destinations menu. Alias of sm_findtele");

	if(gB_Late)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i) && !IsFakeClient(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	for(int i = 0; i < MAX_TELES; i++)
	{
		gI_MenuSection[client][i] = 0;
	}
}

public void OnMapStart()
{
	FindTriggers();
	FindTeles();
}

public Action Command_FindTeleDestination(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if (gH_TriggersMenu.ItemCount == 1 && gH_TeleDestinationMenu.ItemCount == 1)
	{
		Shavit_PrintToChat(client, "该地图没有传送点");

		return Plugin_Handled;
	}

	OpenFindTeleMenu(client);

	return Plugin_Handled;
}

void OpenFindTeleMenu(int client)
{
	Menu menu = new Menu(FindTele_MenuHandler);
	menu.SetTitle("选择要找的传送: ");

	menu.AddItem("teledes", "传送点");
	menu.AddItem("trigger", "触发器trigger");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int FindTele_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[64];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		if(StrEqual(sInfo, "teledes"))
		{
			OpenFindTeleDesMenu(param1);
		}
		else //if(StrEqual(sInfo, "teledes"))
		{
			OpenFindTriggersMenu(param1);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void OpenFindTeleDesMenu(int client)
{
	gH_TeleDestinationMenu.DisplayAt(client, gI_MenuSection[client][TELEDES], MENU_TIME_FOREVER);
}

public int FindTeleDestination_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_MenuSection[param1][TELEDES] = menu.Selection;

		if(!IsPlayerAlive(param1))
		{
			Shavit_PrintToChat(param1, "%T", "TeleportAlive", param1);

			OpenFindTeleDesMenu(param1);

			return 0;
		}

		char sInfo[16];
		char sDisplay[128];
		menu.GetItem(param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));

		int entity = StringToInt(sInfo);

		float position[3];
		float angles[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
		GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);

		DoTeleport(param1, sDisplay, position, angles);

		OpenFindTeleDesMenu(param1);
	}
	else if(action == MenuAction_Cancel)
	{
		OpenFindTeleMenu(param1);
	}

	return 0;
}

void OpenFindTriggersMenu(int client)
{
	gH_TriggersMenu.DisplayAt(client, gI_MenuSection[client][TRIGGER], MENU_TIME_FOREVER);
}

public int FindTriggers_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		gI_MenuSection[param1][TRIGGER] = menu.Selection;

		if(!IsPlayerAlive(param1))
		{
			Shavit_PrintToChat(param1, "%T", "TeleportAlive", param1);

			OpenFindTriggersMenu(param1);

			return 0;
		}

		char sInfo[16];
		char sDisplay[128];
		menu.GetItem(param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));

		int entity = StringToInt(sInfo);

		float position[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);

		DoTeleport(param1, sDisplay, position);

		OpenFindTriggersMenu(param1);
	}
	else if(action == MenuAction_Cancel)
	{
		OpenFindTeleMenu(param1);
	}

	return 0;
}



/* PRIVATE */

static void DoTeleport(int client, const char[] desName, float origin[3] = NULL_VECTOR, float ang[3] = NULL_VECTOR)
{
	Shavit_StopTimer(client);
	TeleportEntity(client, origin, ang, view_as<float>({0.0, 0.0, 0.0}));
	Shavit_PrintToChat(client, "传送至 '%s', 坐标: %.2f | %.2f | %.2f", desName, origin[0], origin[1], origin[2]);
}

static void FindTeles()
{
	delete gH_TeleDestinationMenu;
	gH_TeleDestinationMenu = view_as<MenuEx>(new Menu(FindTeleDestination_MenuHandler));
	gH_TeleDestinationMenu.SetTitle("!!! 传送后时间会停止");
	gH_TeleDestinationMenu.ExitBackButton = true;

	int iEnt = -1;

	while ((iEnt = FindEntityByClassname(iEnt, "info_teleport_destination")) != -1)
	{
		gH_TeleDestinationMenu.PushEnt(iEnt);
	}

	iEnt = -1;

	while ((iEnt = FindEntityByClassname(iEnt, "info_target")) != -1)
	{
		gH_TeleDestinationMenu.PushEnt(iEnt);
	}


	if(gH_TeleDestinationMenu.ItemCount == 0)
	{
		gH_TeleDestinationMenu.AddItem("", "没有传送点...");
	}
}

static void FindTriggers()
{
	delete gH_TriggersMenu;
	gH_TriggersMenu = view_as<MenuEx>(new Menu(FindTriggers_MenuHandler));
	gH_TriggersMenu.SetTitle("!!! 传送后时间会停止");
	gH_TriggersMenu.ExitBackButton = true;

	int iEnt = -1;
	int iCount = 1;

	while((iEnt = FindEntityByClassname(iEnt, "trigger_multiple")) != -1)
	{
		char sBuffer[128];
		GetEntPropString(iEnt, Prop_Send, "m_iName", sBuffer, 128, 0);

		if(strlen(sBuffer) == 0)
		{
			char sTargetname[64];
			FormatEx(sTargetname, 64, "trigger_multiple_#%d", iCount);
			DispatchKeyValue(iEnt, "targetname", sTargetname);
		}

		iCount++;
		gH_TriggersMenu.PushEnt(iEnt);
	}

	iCount = 1;

	while((iEnt = FindEntityByClassname(iEnt, "trigger_teleport")) != -1)
	{
		char sBuffer[128];
		GetEntPropString(iEnt, Prop_Send, "m_iName", sBuffer, 128, 0);

		if(strlen(sBuffer) == 0)
		{
			char sTargetname[64];
			FormatEx(sTargetname, 64, "trigger_teleport_#%d", iCount);
			DispatchKeyValue(iEnt, "targetname", sTargetname);
		}

		iCount++;
		gH_TriggersMenu.PushEnt(iEnt);
	}

	iCount = 1;

	while((iEnt = FindEntityByClassname(iEnt, "trigger_push")) != -1)
	{
		char sBuffer[128];
		GetEntPropString(iEnt, Prop_Send, "m_iName", sBuffer, 128, 0);

		if(strlen(sBuffer) == 0)
		{
			char sTargetname[64];
			FormatEx(sTargetname, 64, "trigger_push_#%d", iCount);
			DispatchKeyValue(iEnt, "targetname", sTargetname);
		}

		iCount++;
		gH_TriggersMenu.PushEnt(iEnt);
	}


	if(gH_TriggersMenu.ItemCount == 0)
	{
		gH_TriggersMenu.AddItem("", "没有触发器trigger区域...");
	}
}
