void RegisterCommands()
{
	RegConsoleCmd("sm_tier", Command_Tier, "Prints the map's tier to chat.");
	RegConsoleCmd("sm_maptier", Command_Tier, "Prints the map's tier to chat. (sm_tier alias)");

	RegConsoleCmd("sm_m", Command_MapDetails, "Prints the map's details information");

	RegAdminCmd("sm_settier", Command_SetTier, ADMFLAG_RCON, "Change the map's tier. Usage: sm_settier <tier>");
	RegAdminCmd("sm_setmaptier", Command_SetTier, ADMFLAG_RCON, "Change the map's tier. Usage: sm_setmaptier <tier> (sm_settier alias)");
	RegAdminCmd("sm_mapsettings", Command_MapSettings, ADMFLAG_RCON, "Change the map's tier, limitspeed and maxvelocity.");
	RegAdminCmd("sm_mapsetting", Command_MapSettings, ADMFLAG_RCON, "Change the map's tier, limitspeed and maxvelocity. Alias of sm_mapsettings");
	RegAdminCmd("sm_ms", Command_MapSettings, ADMFLAG_RCON, "Change the map's tier, limitspeed and maxvelocity. Alias of sm_mapsettings");

	RegConsoleCmd("sm_showtrigger", Command_ShowTriggers, "Command to dynamically toggle trigger visibility");
	RegConsoleCmd("sm_showtriggers", Command_ShowTriggers, "Command to dynamically toggle trigger visibility");
	RegConsoleCmd("sm_showzones", Command_ShowTriggers, "Command to dynamically toggle shavit's zones trigger visibility");
	RegConsoleCmd("sm_findtele", Command_FindTeleDestination, "Show teleport_destination entities menu");
	RegConsoleCmd("sm_findteles", Command_FindTeleDestination, "Show teleport_destination entities menu. Alias of sm_findtele");
	RegConsoleCmd("sm_telefinder", Command_FindTeleDestination, "Show teleport_destination entities menu. Alias of sm_findtele");

	// menu
	RegAdminCmd("sm_zone", Command_Zones, ADMFLAG_RCON, "Opens the mapzones menu.");
	RegAdminCmd("sm_zones", Command_Zones, ADMFLAG_RCON, "Opens the mapzones menu.");
	RegAdminCmd("sm_addzone", Command_AddZones, ADMFLAG_RCON, "Opens the addzones menu.");
	RegAdminCmd("sm_addzones", Command_AddZones, ADMFLAG_RCON, "Opens the addzones menu.");
	RegAdminCmd("sm_mapzone", Command_AddZones, ADMFLAG_RCON, "Opens the addzones menu. Alias of sm_addzones.");
	RegAdminCmd("sm_mapzones", Command_AddZones, ADMFLAG_RCON, "Opens the addzones menu. Alias of sm_addzones.");
	RegAdminCmd("sm_hookzone", Command_HookZones, ADMFLAG_RCON, "Opens the addHookzones menu.");
	RegAdminCmd("sm_hookzones", Command_HookZones, ADMFLAG_RCON, "Opens the addHookzones menu. Alias of sm_hookzone.");

	RegAdminCmd("sm_delzone", Command_DeleteZone, ADMFLAG_RCON, "Delete a mapzone");
	RegAdminCmd("sm_delzones", Command_DeleteZone, ADMFLAG_RCON, "Delete a mapzone");
	RegAdminCmd("sm_deletezone", Command_DeleteZone, ADMFLAG_RCON, "Delete a mapzone");
	RegAdminCmd("sm_deletezones", Command_DeleteZone, ADMFLAG_RCON, "Delete a mapzone");
	RegAdminCmd("sm_deleteallzones", Command_DeleteAllZones, ADMFLAG_RCON, "Delete all mapzones");

	RegAdminCmd("sm_modifier", Command_Modifier, ADMFLAG_RCON, "Changes the axis modifier for the zone editor. Usage: sm_modifier <number>");

	RegAdminCmd("sm_editzone", Command_ZoneEdit, ADMFLAG_RCON, "Modify an existing zone.");
	RegAdminCmd("sm_editzones", Command_ZoneEdit, ADMFLAG_RCON, "Modify an existing zone.");

	RegAdminCmd("sm_prebuild", Command_ZonePreBuild, ADMFLAG_RCON, "Prebuild zones.");

	RegAdminCmd("sm_reloadzonesettings", Command_ReloadZoneSettings, ADMFLAG_ROOT, "Reloads the zone settings.");

	RegConsoleCmd("sm_stages", Command_Stages, "Opens the stage menu. Usage: sm_stages [stage #]");
	RegConsoleCmd("sm_stage", Command_Stages, "Opens the stage menu. Usage: sm_stage [stage #]");
	RegConsoleCmd("sm_s", Command_Stages, "Opens the stage menu. Usage: sm_stage [stage #]");

	RegConsoleCmd("sm_back", Command_Back, "Go back to the current stage zone.");
	RegConsoleCmd("sm_teleport", Command_Back, "Go back to the current stage zone. Alias of sm_back");

	RegConsoleCmd("sm_setstart", Command_Startpos, "Set track/stage startzones position.");
	RegConsoleCmd("sm_startpos", Command_Startpos, "Set track/stage startzones position. Alias of sm_setstart.");
}

public Action Command_Tier(int client, int args)
{
	int tier = gI_Tier;

	char sMap[PLATFORM_MAX_PATH];

	if(args == 0)
	{
		sMap = gS_Map;
	}
	else
	{
		GetCmdArgString(sMap, sizeof(sMap));
		LowercaseString(sMap);

		if(!GuessBestMapName(gA_ValidMaps, sMap, sMap) || !gA_MapTiers.GetValue(sMap, tier))
		{
			Shavit_PrintToChat(client, "%t", "Map was not found", sMap);
			return Plugin_Continue;
		}
	}

	Shavit_PrintToChat(client, "%T", "CurrentTier", client, sMap, tier);

	return Plugin_Continue;
}

public Action Command_MapDetails(int client, int args)
{
	int iBonuses = Shavit_GetMapBonuses();

	if(Shavit_IsLinearMap())
	{
		int iCps = Shavit_GetMapCheckpoints();
		Shavit_PrintToChat(client, "当前竞速图信息: 难度 %d | 检查点数 %d | 奖励关数 %d", gI_Tier, iCps, iBonuses);
	}
	else
	{
		int iStages = Shavit_GetMapStages();
		Shavit_PrintToChat(client, "当前关卡图信息: 难度 %d | 关卡数 %d | 奖励关数 %d", gI_Tier, iStages, iBonuses);
	}

	return Plugin_Continue;
}

public Action Command_SetTier(int client, int args)
{
	char sArg[8];
	GetCmdArg(1, sArg, 8);

	int tier = StringToInt(sArg);

	if(args == 0 || tier < 1 || tier > 10)
	{
		ReplyToCommand(client, "%T", "ArgumentsMissing", client, "sm_settier <tier> (1-10)");

		return Plugin_Continue;
	}

	gI_Tier = tier;
	gA_MapTiers.SetValue(gS_Map, tier);

	Call_OnTierAssigned(gS_Map, tier);

	Shavit_PrintToChat(client, "%T", "SetTier", client, tier);

	DB_SetTier(tier);

	return Plugin_Continue;
}

public Action Command_MapSettings(int client, int args)
{
	SetMapSettingsPre(client);

	return Plugin_Continue;
}