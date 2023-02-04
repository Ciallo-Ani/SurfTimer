/*
	zones Plugin Include
	
	Website: https://github.com/Ciallo-Ani/surftimer
*/

#if defined _shavit_zones_included_
#endinput
#endif
#define _shavit_zones_included_



// ======[ ENUMS ]======



// ======[ ENUM STRUCTS ]======





// =====[ NATIVES ]=====

/**
 * Gets the map tier for a specified map.
 * Use the map's display name.
 *
 * @param map						Map to get the tier of. Using "" will get the current map's tier.
 * @return							Map tier. 0 if no results were found.
 */
native int Shavit_GetMapTier(const char[] map = "");

/**
 * Gets a StringMap that contains all the cached map tiers.
 * The returned StringMap must be deleted from memory after use!
 *
 * @return							StringMap with {const char[]: map, int: tier} structure.
 */
native StringMap Shavit_GetMapTiers();

/**
 * Detect current map if limitting stage speed.
 *
 * @return							Boolean. false if no limit.
 */
native bool Shavit_GetMapLimitspeed();

/**
 * Get current map's maxvelocity.
 *
 * @return							Current map's maxvelocity.
 */
native float Shavit_GetMapMaxvelocity();



// =====[ FORWARDS ]=====

/**
 * Gets called when a map's tier is assigned.
 * Only called once per map, if the rankings plugin is enabled.
 * The exception is if the admin changes the current map's tier.
 *
 * @param map						Map display name.
 * @param tier						Map's tier.
 * @noreturn
 */
forward void Shavit_OnTierAssigned(const char[] map, int tier);



// =====[ DEPENDENCY ]=====

public SharedPlugin __pl_shavit_zones = 
{
	name = "shavit-zones", 
	file = "shavit-zones.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shavit_zones_SetNTVOptional()
{
	MarkNativeAsOptional("Shavit_GetMapTier");
	MarkNativeAsOptional("Shavit_GetMapTiers");
	MarkNativeAsOptional("Shavit_GetMapLimitspeed");
	MarkNativeAsOptional("Shavit_GetMapMaxvelocity");
}
#endif