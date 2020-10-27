#pragma semicolon 1
#pragma newdecls required

#include <ce_util>
#include <ce_core>
#include <ce_coordinator>

public Plugin myinfo =
{
	name = "Creators.TF Economy - Schema Manager",
	author = "Creators.TF Team",
	description = "Creators.TF Schema Manager",
	version = "1.00",
	url = "https://creators.tf"
};

ConVar ce_economy_schema_autoupdate;

public void OnPluginStart()
{
    ce_economy_schema_autoupdate = CreateConVar("ce_economy_schema_autoupdate", "1", "Enable economy scheme autoupdating.", FCVAR_PROTECTED);
    RegServerCmd("ce_economy_schema_update", cUpdateSchema);
}

public void OnMapStart()
{    
    CE_UpdateScheme(false);
}

public bool ShouldSchemaUpdate()
{
    return ce_economy_schema_autoupdate.BoolValue;
}

public Action cUpdateSchema(int args)
{
	LogMessage("Forcing schema update");
	CE_UpdateScheme(true);
}

public void CE_UpdateScheme(bool force)
{
	if (!ShouldSchemaUpdate() && !force)return;

	CESC_SendAPIRequest("/api/IEconomyItems/GScheme?field=Version", RequestType_GET, httpUpdateCallback);
}

public void httpUpdateCallback(const char[] content, int size, int status, any value)
{
	if (status == StatusCode_Success)
	{
		char sLoc[96];
		BuildPath(Path_SM, sLoc, 96, "configs/items.cfg");
		KeyValues kvOld = new KeyValues("Items");
		kvOld.ImportFromFile(sLoc);

		char sOldVersion[256];

		kvOld.GetString("Version/build", sOldVersion, sizeof(sOldVersion), "");
		delete kvOld;

		// Parsing recived data to compare old version to new one.
		KeyValues kvNew = new KeyValues("Items");
		kvNew.ImportFromString(content);

		if (kvNew.GetNum("failed", 0) == 0)
		{
			char sNewVersion[256];
			kvNew.GetString("build", sNewVersion, sizeof(sNewVersion), "");
			if (!StrEqual(sOldVersion, sNewVersion))
			{
				// Versions differ, so we need to redownload the full file.
				LogMessage("New Schema version detected (%s), downloading...", sNewVersion);

				CESC_SendAPIRequest("/api/IEconomyItems/GScheme", RequestType_GET, HttpDownloadCallback, _, _, sLoc);
			}
		} else {
			LogMessage("Failed loading new Creators.TF Economy Schema.");
		}
		delete kvNew;
	} else {
		LogError("Falied to reach Creators.TF Economy API Gateway. (Status Code: %d)", status);
	}
}

/**
*	Purpose: 	Callback of the item schema download request sent in httpUpdateCallback.
*/
public void HttpDownloadCallback(const char[] content, int size, int status, any value)
{
	if (status == StatusCode_Success)
	{
		LogMessage("New Creators.TF Schema downloaded successfully.");
		
		CE_FlushSchema();
	}
}
