void ShowHUDMenu(int client, int item)
{
	if(!IsValidClient(client))
	{
		return;
	}

	Menu menu = new Menu(MenuHandler_HUD, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
	menu.SetTitle("%T", "HUDMenuTitle", client);

	char sInfo[16];
	char sHudItem[64];

	for(int i = 0; i < HUD_BITCOUNT; i++)
	{
		FormatEx(sInfo, sizeof(sInfo), "!%d", (1 << i));
		FormatEx(sHudItem, sizeof(sHudItem), "%T", gS_HudSettings[i], client);
		menu.AddItem(sInfo, sHudItem);
	}

	// HUD2 - disables selected elements
	FormatEx(sInfo, 16, "@%d", HUD2_TIME);
	FormatEx(sHudItem, 64, "%T", "HudTimeText", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "@%d", HUD2_SPEED);
	FormatEx(sHudItem, 64, "%T", "HudSpeedText", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "@%d", HUD2_WRPB);
	FormatEx(sHudItem, 64, "%T", "HudWRPBText", client);
	menu.AddItem(sInfo, sHudItem);

	FormatEx(sInfo, 16, "@%d", HUD2_PRESTRAFE);
	FormatEx(sHudItem, 64, "%T", "HudPrestrafeText", client);
	menu.AddItem(sInfo, sHudItem);

	menu.ExitButton = true;
	menu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

public int MenuHandler_HUD(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sCookie[16];
		menu.GetItem(param2, sCookie, sizeof(sCookie));

		int type = (sCookie[0] == '!')? 1:2;
		ReplaceString(sCookie, sizeof(sCookie), "!", "");
		ReplaceString(sCookie, sizeof(sCookie), "@", "");

		int iSelection = StringToInt(sCookie);

		if(type == 1)
		{
			gI_HUDSettings[param1] ^= iSelection;
			IntToString(gI_HUDSettings[param1], sCookie, sizeof(sCookie));
			gH_HUDCookie.Set(param1, sCookie);
		}

		else
		{
			gI_HUD2Settings[param1] ^= iSelection;
			IntToString(gI_HUD2Settings[param1], sCookie, sizeof(sCookie));
			gH_HUDCookieMain.Set(param1, sCookie);
		}

		ShowHUDMenu(param1, GetMenuSelectionPosition());
	}

	else if(action == MenuAction_DisplayItem)
	{
		char sInfo[16];
		char sDisplay[64];
		int style = 0;
		menu.GetItem(param2, sInfo, 16, style, sDisplay, 64);

		int type = (sInfo[0] == '!')? 1:2;
		ReplaceString(sInfo, 16, "!", "");
		ReplaceString(sInfo, 16, "@", "");

		if(type == 1)
		{
			Format(sDisplay, 64, "[%s] %s", ((gI_HUDSettings[param1] & StringToInt(sInfo)) > 0)? "＋":"－", sDisplay);
		}

		else
		{
			Format(sDisplay, 64, "[%s] %s", ((gI_HUD2Settings[param1] & StringToInt(sInfo)) == 0)? "＋":"－", sDisplay);
		}

		return RedrawMenuItem(sDisplay);
	}

	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void ToggleHUD(int client, int hud, bool chat)
{
	if(!(1 <= client <= MaxClients))
	{
		return;
	}

	char sCookie[16];
	gI_HUDSettings[client] ^= hud;
	IntToString(gI_HUDSettings[client], sCookie, sizeof(sCookie));
	gH_HUDCookie.Set(client, sCookie);

	if(chat)
	{
		char sHUDSetting[64];

		for(int i = 0; i < HUD_BITCOUNT; i++)
		{
			if(hud == (1 << i))
			{
				FormatEx(sHUDSetting, sizeof(sHUDSetting), "%T", gS_HudSettings[i], client);
				break;
			}
		}

		if((gI_HUDSettings[client] & hud) > 0)
		{
			Shavit_PrintToChat(client, "%T", "HudEnabledComponent", client, sHUDSetting);
		}
		else
		{
			Shavit_PrintToChat(client, "%T", "HudDisabledComponent", client, sHUDSetting);
		}
	}
}