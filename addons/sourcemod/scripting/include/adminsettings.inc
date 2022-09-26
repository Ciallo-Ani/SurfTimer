#if defined _adminsettings_included_
	#endinput
#endif
#define _adminsettings_included_

#define SETTING_DEFAULT		(SETTING_HIDE)
#define SETTING_HIDE		(1 << 0)
#define SETTING_BITCOUNT	1


/**
 * Gets the settings of a admin.
 * See the SETTING_* defines for information.
 *
 * @param admin					Client index.
 * @return                      Admin settings.
 */
native int Admin_GetSettings(int admin);



/**
 * Do not edit below this line!
 */
public SharedPlugin __pl_adminsettings = 
{
	name = "adminsettings",
	file = "adminsettings.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_adminsettings_SetNTVOptional()
{
	MarkNativeAsOptional("Admin_GetSettings");
}
#endif
