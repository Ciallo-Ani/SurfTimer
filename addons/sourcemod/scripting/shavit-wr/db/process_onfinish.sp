/*
	Processing Shavit_OnFinish for wr.
*/



void DB_OnFinish(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float avgvel, float maxvel, int timestamp)
{
	// do not risk overwriting the player's data if their PB isn't loaded to cache yet
	if (!gB_LoadedCache[client])
	{
		return;
	}

	if(time <= 2.0) // buged
	{
		Shavit_PrintToChat(client, "系统判定该记录为bug记录, 已移除.");
		Shavit_LogMessage("Client %N bugged, style -> %d, track -> %d, time -> %f, map -> %s", client, style, track, time, gS_Map);
		return;
	}

	// client pb
	oldtime = gF_PlayerRecord[client][style][track];

	int iOverwrite = PB_NoQuery;

	if(Shavit_GetStyleSettingInt(style, "unranked") || Shavit_IsPracticeMode(client))
	{
		iOverwrite = PB_UnRanked;
	}
	else if(oldtime == 0.0)
	{
		iOverwrite = PB_Insert;
	}
	else if(time < oldtime)
	{
		iOverwrite = PB_Update;
	}

	int iSteamID = GetSteamAccountID(client);
	int iRank = GetRankForTime(style, time, track);
	int iRecords = GetRecordAmount(style, track);
	float fPrestrafe = gF_CurrentPrestrafe[client];
	float fOldWR = gF_WRTime[style][track];

	if(iOverwrite > PB_NoQuery)
	{
		gF_PlayerRecord[client][style][track] = time;

		if(time < gF_WRTime[style][track] || gF_WRTime[style][track] == 0.0) // WR?
		{
			gF_WRTime[style][track] = time;
			gI_WRSteamID[style][track] = iSteamID;

			Call_OnWorldRecord(client, style, time, jumps, strafes, sync, track, fOldWR, oldtime, avgvel, maxvel, timestamp);
		}
		else if(iRank >= iRecords)
		{
			Call_OnWorstRecord(client, style, time, jumps, strafes, sync, track, oldtime, avgvel, maxvel, timestamp);
		}

		float fPoints = 0.0;

		char sQuery[1024];

		if(iOverwrite == PB_Insert)
		{
			FormatEx(sQuery, sizeof(sQuery), mysql_onfinish_insert_new, 
				iSteamID, gS_Map, time, jumps, timestamp, style, strafes, sync, fPoints, track, view_as<int>(time), fPrestrafe);
		}
		else
		{
			FormatEx(sQuery, sizeof(sQuery), mysql_onfinish_update, 
				time, jumps, timestamp, strafes, sync, fPoints, view_as<int>(time), fPrestrafe, gS_Map, iSteamID, style, track);
		}

		gH_SQL.Query(SQL_OnFinish_Callback, sQuery, GetClientSerial(client), DBPrio_High);
	}
	else if(iOverwrite == PB_NoQuery)
	{
		char sQuery[512];
		FormatEx(sQuery, sizeof(sQuery), mysql_onfinish_update_completions, 
			gS_Map, iSteamID, style, track);
		gH_SQL.Query(SQL_OnIncrementCompletions_Callback, sQuery, 0, DBPrio_Low);

		gI_PlayerCompletion[client][style][track]++;
	}

	Call_OnFinish_Post(client, style, time, jumps, strafes, sync, iRank, iOverwrite, track, oldtime, fOldWR, avgvel, maxvel, timestamp);
}

public void SQL_OnFinish_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR OnFinish) SQL query failed. Reason: %s", error);

		return;
	}

	int client = GetClientFromSerial(data);

	if(client == 0)
	{
		return;
	}

	UpdateWRCache(client);
}

public void SQL_OnIncrementCompletions_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Timer (WR OnIncrementCompletions) SQL query failed. Reason: %s", error);

		return;
	}
}