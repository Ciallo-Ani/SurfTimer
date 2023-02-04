static GlobalForward H_Forwards_OnTierAssigned = null;



// =====[ NATIVES ]=====

void CreateNatives()
{
	CreateNative("Shavit_GetMapTier", Native_GetMapTier);
	CreateNative("Shavit_GetMapTiers", Native_GetMapTiers);
	CreateNative("Shavit_GetMapLimitspeed", Native_GetMapLimitspeed);
	CreateNative("Shavit_GetMapMaxvelocity", Native_GetMapMaxvelocity);
}

public int Native_GetMapTier(Handle handler, int numParams)
{
	int tier = 0;
	char sMap[PLATFORM_MAX_PATH];
	GetNativeString(1, sMap, sizeof(sMap));

	if (!sMap[0])
	{
		return gI_Tier;
	}

	gA_MapTiers.GetValue(sMap, tier);
	return tier;
}

public int Native_GetMapTiers(Handle handler, int numParams)
{
	return view_as<int>(CloneHandle(gA_MapTiers, handler));
}

public int Native_GetMapLimitspeed(Handle handler, int numParams)
{
	return gB_Maplimitspeed;
}

public int Native_GetMapMaxvelocity(Handle handler, int numParams)
{
	return view_as<int>(gF_Maxvelocity);
}



// =====[ FORWARDS ]=====

void CreateGlobalForwards()
{
	H_Forwards_OnTierAssigned = new GlobalForward("Shavit_OnTierAssigned", ET_Event, Param_String, Param_Cell);
}

void Call_OnTierAssigned(const char[] map, int tier)
{
	Call_StartForward(H_Forwards_OnTierAssigned);
	Call_PushString(map);
	Call_PushCell(tier);
	Call_Finish();
}