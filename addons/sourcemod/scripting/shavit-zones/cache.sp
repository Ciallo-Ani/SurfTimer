void InitCaches()
{
	gA_ValidMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	gA_MapTiers = new StringMap();
}