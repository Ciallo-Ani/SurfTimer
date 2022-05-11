#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <shavit/core>

#pragma newdecls required
#pragma semicolon 1

#define PAINT_DISTANCE_SQ 1.0

/* Colour name, file name */
char gS_PaintColours[][][64] =    // Modify this to add/change colours
{
	{ "随机",     "random"         },
	{ "白色",      "paint_white"    },
	{ "黑色",      "paint_black"    },
	{ "蓝色",       "paint_blue"     },
	{ "浅蓝色", "paint_lightblue"},
	{ "棕色",      "paint_brown"    },
	{ "天蓝色",       "paint_cyan"     },
	{ "绿色",      "paint_green"    },
	{ "暗绿色", "paint_darkgreen"},
	{ "红色",        "paint_red"      },
	{ "橙色",     "paint_orange"   },
	{ "黄色",     "paint_yellow"   },
	{ "粉色",       "paint_pink"     },
	{ "淡粉色", "paint_lightpink"},
	{ "紫色",     "paint_purple"   },
};

/* Size name, size suffix */
char gS_PaintSizes[][][64] =    // Modify this to add more sizes
{
	{ "小",  ""      },
	{ "中", "_med"  },
	{ "大",  "_large"},
};

int gI_Sprites[sizeof(gS_PaintColours) - 1][sizeof(gS_PaintSizes)];

int gI_PlayerPaintColour[MAXPLAYERS+1];
int gI_PlayerPaintSize[MAXPLAYERS+1];

float gF_LastPaint[MAXPLAYERS+1][3];
bool gB_IsPainting[MAXPLAYERS+1];
bool gB_ShouldPaintToAll[MAXPLAYERS+1];

/* COOKIES */
Cookie gH_PlayerPaintColour;
Cookie gH_PlayerPaintSize;
Cookie gH_PlayerPaintObject;

public Plugin myinfo =
{
	name = "[shavit] Paint",
	author = "SlidyBat, Ciallo-Ani",
	description = "Allow players to paint on walls.",
	version = "2.1",
	url = "null"
}

public void OnPluginStart()
{
	/* Register Cookies */
	gH_PlayerPaintColour = new Cookie("paint_playerpaintcolour", "paint_playerpaintcolour", CookieAccess_Protected);
	gH_PlayerPaintSize = new Cookie("paint_playerpaintsize", "paint_playerpaintsize", CookieAccess_Protected);
	gH_PlayerPaintObject = new Cookie("paint_playerpaintobject", "paint_playerpaintobject", CookieAccess_Protected);

	/* COMMANDS */
	RegConsoleCmd("+paint", Command_EnablePaint, "开始喷漆");
	RegConsoleCmd("-paint", Command_DisablePaint, "结束喷漆. \n 注: +paint按完一次即可自动结束, 无需绑定该指令");
	RegConsoleCmd("sm_paint", Command_Paint, "喷漆菜单");
	RegConsoleCmd("sm_paintcolour", Command_PaintColour, "修改喷漆颜色");
	RegConsoleCmd("sm_paintcolor", Command_PaintColour, "修改喷漆颜色");
	RegConsoleCmd("sm_paintsize", Command_PaintSize, "修改喷漆尺寸");
	RegConsoleCmd("sm_painto", Command_PaintToWho, "修改喷漆可视化对象");

	/* Late loading */
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char sValue[64];

	gH_PlayerPaintColour.Get(client, sValue, sizeof(sValue));
	gI_PlayerPaintColour[client] = StringToInt(sValue);

	gH_PlayerPaintSize.Get(client, sValue, sizeof(sValue));
	gI_PlayerPaintSize[client] = StringToInt(sValue);

	gH_PlayerPaintObject.Get(client, sValue, sizeof(sValue));
	gB_ShouldPaintToAll[client] = view_as<bool>(StringToInt(sValue));
}

public void OnMapStart()
{
	char buffer[PLATFORM_MAX_PATH];

	AddFileToDownloadsTable("materials/decals/paint/paint_decal.vtf");
	for (int colour = 1; colour < sizeof(gS_PaintColours); colour++)
	{
		for (int size = 0; size < sizeof(gS_PaintSizes); size++)
		{
			Format(buffer, sizeof(buffer), "decals/paint/%s%s.vmt", gS_PaintColours[colour][1], gS_PaintSizes[size][1]);
			gI_Sprites[colour - 1][size] = PrecachePaint(buffer); // colour - 1 because starts from [1], [0] is reserved for random
		}
	}

	CreateTimer(0.1, Timer_Paint, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Command_EnablePaint(int client, int args)
{
	TraceEye(client, gF_LastPaint[client]);
	gB_IsPainting[client] = true;

	return Plugin_Handled;
}

public Action Command_DisablePaint(int client, int args)
{
	gB_IsPainting[client] = false;

	return Plugin_Handled;
}

public Action Command_Paint(int client, int args)
{
	OpenPaintHelperMenu(client);

	return Plugin_Continue;
}

void OpenPaintHelperMenu(int client)
{
	Menu menu = new Menu(PaintHelper_MenuHandler);

	menu.SetTitle("喷漆枪菜单\n  ");

	menu.AddItem("help", 
		"如何喷漆?\n  "...
		"控制台绑定指令: \n  "...
		"bind mouse4 \"+paint\" \n  "...
		"该指令表示, 按住鼠标侧键, 即可喷漆",
		ITEMDRAW_DISABLED);

	menu.AddItem("color", "修改颜色");
	menu.AddItem("size", "修改尺寸");
	menu.AddItem("object", "修改可视对象");
	menu.AddItem("clear", "清除喷漆");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int PaintHelper_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[16];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		if(StrEqual(sInfo, "color"))
		{
			OpenPaintColorMenu(param1);
		}
		else if(StrEqual(sInfo, "size"))
		{
			OpenPaintSizeMenu(param1);
		}
		else if(StrEqual(sInfo, "object"))
		{
			OpenPaintToWhoMenu(param1);
		}
		else if(StrEqual(sInfo, "clear"))
		{
			Shavit_PrintToChat(param1, "将指令复制到控制台: r_cleardecals");

			OpenPaintHelperMenu(param1);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action Command_PaintColour(int client, int args)
{
	OpenPaintColorMenu(client);

	return Plugin_Continue;
}

void OpenPaintColorMenu(int client)
{
	Menu menu = new Menu(PaintColour_MenuHandler);

	menu.SetTitle("选择喷漆颜色:");

	for (int i = 0; i < sizeof(gS_PaintColours); i++)
	{
		menu.AddItem(gS_PaintColours[i][0], gS_PaintColours[i][0], 
			gI_PlayerPaintColour[client] == i ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int PaintColour_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sValue[64];
		gI_PlayerPaintColour[param1] = param2;
		IntToString(param2, sValue, sizeof(sValue));
		gH_PlayerPaintColour.Set(param1, sValue);

		Shavit_PrintToChat(param1, "喷漆颜色已修改为: \x10%s", gS_PaintColours[param2][0]);

		OpenPaintColorMenu(param1);
	}
	else if(action == MenuAction_Cancel)
	{
		OpenPaintHelperMenu(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action Command_PaintSize(int client, int args)
{
	OpenPaintSizeMenu(client);

	return Plugin_Continue;
}

void OpenPaintSizeMenu(int client)
{
	Menu menu = new Menu(PaintSize_MenuHandler);

	menu.SetTitle("选择喷漆尺寸:");

	for (int i = 0; i < sizeof(gS_PaintSizes); i++)
	{
		menu.AddItem(gS_PaintSizes[i][0], gS_PaintSizes[i][0], 
			gI_PlayerPaintSize[client] == i ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int PaintSize_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sValue[64];
		gI_PlayerPaintSize[param1] = param2;
		IntToString(param2, sValue, sizeof(sValue));
		gH_PlayerPaintSize.Set(param1, sValue);

		Shavit_PrintToChat(param1, "喷漆尺寸已修改为: \x10%s", gS_PaintSizes[param2][0]);

		OpenPaintSizeMenu(param1);
	}
	else if(action == MenuAction_Cancel)
	{
		OpenPaintHelperMenu(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action Command_PaintToWho(int client, int args)
{
	OpenPaintToWhoMenu(client);

	return Plugin_Continue;
}

void OpenPaintToWhoMenu(int client)
{
	Menu menu = new Menu(PaintToWho_MenuHandler);

	menu.SetTitle("你想喷漆给谁看? ");

	menu.AddItem("me", "给自己看", gB_ShouldPaintToAll[client]?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	menu.AddItem("all", "给所有人看", gB_ShouldPaintToAll[client]?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int PaintToWho_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sInfo[8];
		char sDisplay[32];
		int style;
		menu.GetItem(param2, sInfo, sizeof(sInfo), style, sDisplay, sizeof(sDisplay));

		gB_ShouldPaintToAll[param1] = StrEqual(sInfo, "all");

		char sValue[8];
		IntToString(param2, sValue, sizeof(sValue));
		gH_PlayerPaintObject.Set(param1, sValue);

		Shavit_PrintToChat(param1, "喷漆可视化对象已修改为: \x10%s", sDisplay);

		OpenPaintToWhoMenu(param1);
	}
	else if(action == MenuAction_Cancel)
	{
		OpenPaintHelperMenu(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

public Action Timer_Paint(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && gB_IsPainting[i])
		{
			static float pos[3];
			TraceEye(i, pos);

			if (GetVectorDistance(pos, gF_LastPaint[i], true) > PAINT_DISTANCE_SQ)
			{
				AddPaint(i, pos, gI_PlayerPaintColour[i], gI_PlayerPaintSize[i]);

				gF_LastPaint[i] = pos;
			}
		}
	}

	return Plugin_Continue;
}

void AddPaint(int client, float pos[3], int paint = 0, int size = 0)
{
	if(paint == 0)
	{
		paint = GetRandomInt(1, sizeof(gS_PaintColours) - 1);
	}

	TE_SetupWorldDecal(pos, gI_Sprites[paint - 1][size]);

	if(gB_ShouldPaintToAll[client])
	{
		TE_SendToAll();
	}
	else
	{
		TE_SendToClient(client);
	}
}

int PrecachePaint(char[] filename)
{
	char tmpPath[PLATFORM_MAX_PATH];
	Format(tmpPath, sizeof(tmpPath), "materials/%s", filename);
	AddFileToDownloadsTable(tmpPath);

	return PrecacheDecal(filename, true);
}

stock void TE_SetupWorldDecal(const float vecOrigin[3], int index)
{
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", vecOrigin);
	TE_WriteNum("m_nIndex", index);
}

stock void TraceEye(int client, float pos[3])
{
	float vAngles[3], vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	TR_TraceRayFilter(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

	if (TR_DidHit())
	{
		TR_GetEndPosition(pos);
	}
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return (entity > MaxClients || !entity);
}