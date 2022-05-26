/*
 * shavit's Timer - rankings.inc file
 * by: shavit
 *
 * This file is part of shavit's Timer (https://github.com/shavitush/bhoptimer)
 *
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#if defined _shavit_rankings_included
	#endinput
#endif
#define _shavit_rankings_included



/**
 * Gets called when the server acknowledges the client's ranking status.
 * It is called after OnClientPostAdminCheck and at forced rank recalculations.
 *
 * @param client                    Client index.
 * @param rank                      Client's rank. (0 if unranked or unassigned)
 * @param points                    Client's points. (0.0 if unranked or unassigned)
 * @param first                     True if the forward is called after the initial connection, false if it is caused by recalculation.
 * @noreturn
 */
forward void Shavit_OnRankAssigned(int client, int rank, float points, bool first);

/**
 * Gets player points.
 *
 * @param client                    Client index.
 * @return                          Points. 0.0 if unranked.
 */
native float Shavit_GetPoints(int client);

/**
 * Gets player rank.
 *
 * @param client                    Client index.
 * @return                          Rank. 0 if unranked.
 */
native int Shavit_GetRank(int client);

/**
 * Gets the amount of players with over 0 points.
 *
 * @return                          Amount of ranked players.
 */
native int Shavit_GetRankedPlayers();

/**
 * Deletes tier setting for the specified map.
 * Points recalculation will run right after this is finished.
 *
 * @param map                       Map name.
 * @noreturn
 */
native void Shavit_Rankings_DeleteMap(const char[] map);

/**
 * Retrieves the amount of #1 records a player has.
 * Requires shavit-rankings.
 *
 * @param client                    Client index.
 * @param track                     Track to retrieve WRs from. -1 to use all tracks. All bonus tracks are combined.
 * @param style                     Style to retrieve WRs from. -1 to use all styles.
 * @param usecvars                  Whether to depend on the value of `shavit_stats_mvprankones` and `shavit_stats_mvprankones_maintrack`.
 * @return                          The number of WRs.
 */
native int Shavit_GetWRCount(int client, int track = -1, int style = -1, bool usecvars = true);

/**
 * Retrieves the number of players who hold #1 records.
 * Requires shavit-rankings.
 *
 * @param track                     Track to retrieve WRs from. -1 to use all tracks. All bonus tracks are combined.
 * @param style                     Style to retrieve WRs from. -1 to use all styles.
 * @param usecvars                  Whether to depend on the value of `shavit_stats_mvprankones` and `shavit_stats_mvprankones_maintrack`.
 * @return                          The number of WR holders. 0 if none.
 */
native int Shavit_GetWRHolders(int track = -1, int style = -1, bool usecvars = true);

/**
 * Retrieves the player's rank based on how many #1 records they hold.
 * Requires shavit-rankings.
 * Only works with MySQL 8.0+ or with MariaDB 10.2+.
 *
 * @param client                    Client index.
 * @param track                     Track to retrieve WRs from. -1 to use all tracks. All bonus tracks are combined.
 * @param style                     Style to retrieve WRs from. -1 to use all styles.
 * @param usecvars                  Whether to depend on the value of `shavit_stats_mvprankones` and `shavit_stats_mvprankones_maintrack`.
 * @return                          The rank. 0 if none, or not supported.
 */
native int Shavit_GetWRHolderRank(int client, int track = -1, int style = -1, bool usecvars = true);

/*
 * Calculates how many points a time will give.
 * Used to minimize number of SQL queries.
 * Requires shavit-rankings.
 *
 * @param track                     The track the time is from.
 * @param style                     The style the time is from.
 * @param tier                      The map tier. -1 to use the current map's tier.
 * @param time                      The time you want to calculate the points for.
 * @param wr                        WR.
 *
 * @return                          The number of points the time would give.
 */
native float Shavit_GuessPointsForTime(int track, int style, int tier, float time, float wr);

public SharedPlugin __pl_shavit_rankings =
{
	name = "shavit-rankings",
	file = "shavit-rankings.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shavit_rankings_SetNTVOptional()
{
	MarkNativeAsOptional("Shavit_GetPoints");
	MarkNativeAsOptional("Shavit_GetRank");
	MarkNativeAsOptional("Shavit_GetRankedPlayers");
	MarkNativeAsOptional("Shavit_Rankings_DeleteMap");
	MarkNativeAsOptional("Shavit_GetWRCount");
	MarkNativeAsOptional("Shavit_GetWRHolders");
	MarkNativeAsOptional("Shavit_GetWRHolderRank");
	MarkNativeAsOptional("Shavit_GuessPointsForTime");
}
#endif
