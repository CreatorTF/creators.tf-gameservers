#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "1.0"

#include <ce_core>
#include <ce_util>

public Plugin myinfo =
{
	name = "Creators.TF",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Core Plugin",
	version = "1.0",
	url = "https://creators.tf"
};

KeyValues m_hConfig;
Handle g_hOnSchemaUpdate;

// TODO: Unhardcode this.
char m_sPlugins[][] = {

	// Core Subplugins
	"ce_util",
	"ce_events",
	"ce_coordinator",
	"ce_complex_conditions",
	"ce_models",

	// Manager Subplugins
	"ce_manager_attributes",
	"ce_manager_items",
	"ce_manager_responses",
	"ce_manager_schema",
	"ce_manager_users",

	// Econ Item Subplugins
	"ce_item_cosmetic",
	"ce_item_weapon",

	// Econ Subplugins
	"ce_styles",
	"ce_stranges",
	"ce_campaign",
	"ce_contracts",
	"ce_loadout",

	// Misc Subplugins
	"ce_testing",
	"ce_mann_vs_machines"
};

public void OnAllPluginsLoaded()
{
	CE_LoadConfig();
}

public void OnPluginStart()
{
	for (int i = 0; i < sizeof(m_sPlugins); i++)
	{
		ServerCommand("sm plugins unload %s", m_sPlugins[i]);
	}

	for (int i = 0; i < sizeof(m_sPlugins); i++)
	{
		ServerCommand("sm plugins load %s", m_sPlugins[i]);
	}

	RegServerCmd("ce_broadcast_announce", cBroadcast);

	g_hOnSchemaUpdate = CreateGlobalForward("CE_OnSchemaUpdated", ET_Ignore, Param_Cell);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_core");

	CreateNative("CE_GetEconomyConfig", Native_GetEconomyConfig);
	CreateNative("CE_FlushSchema", Native_FlushSchema);
	return APLRes_Success;
}

public any Native_FlushSchema(Handle plugin, int numParams)
{
	CE_LoadConfig();
}

public void NotifySchemaUpdated()
{
	Call_StartForward(g_hOnSchemaUpdate);
	Call_PushCell(CE_GetEconomyConfig());
	Call_Finish();
}

public Action cBroadcast(int args)
{
	char sSteamID[64], sText[256];
	GetCmdArg(1, sSteamID, sizeof(sSteamID));
	GetCmdArgString(sText, sizeof(sText));

	ReplaceString(sText, sizeof(sText), sSteamID, "");
	TrimString(sText);

	int iTarget = FindTargetBySteamID(sSteamID);

	if(!StrEqual(sText, ""))
	{
		char sTeamColor[10];
		char sClientName[128];
		if(IsClientValid(iTarget))
		{
			strcopy(sTeamColor, sizeof(sTeamColor), "f5eed2");
			switch(GetClientTeam(iTarget))
			{
				case 2:strcopy(sTeamColor, sizeof(sTeamColor), "f84549");
				case 3:strcopy(sTeamColor, sizeof(sTeamColor), "adcff4");
				default:strcopy(sTeamColor, sizeof(sTeamColor), "f5eed2");
			}

			GetClientName(iTarget, sClientName, sizeof(sClientName));
		}

		ReplaceString(sText, sizeof(sText), "#", "\x07");

		ReplaceString(sText, sizeof(sText), "@1", "\x01");
		ReplaceString(sText, sizeof(sText), "@2", "\x02");
		ReplaceString(sText, sizeof(sText), "@3", "\x03");
		ReplaceString(sText, sizeof(sText), "@4", "\x04");
		ReplaceString(sText, sizeof(sText), "@5", "\x05");
		ReplaceString(sText, sizeof(sText), "@6", "\x06");

		ReplaceString(sText, sizeof(sText), "{team}", sTeamColor);
		ReplaceString(sText, sizeof(sText), "{name}", sClientName);

		PrintToChatAll(sText);
	}

	return Plugin_Handled;
}

public bool CE_LoadConfig()
{
	delete m_hConfig;

	char sLoc[96];
	BuildPath(Path_SM, sLoc, 96, "configs/items.cfg");

	m_hConfig = new KeyValues("Economy");
	if (!UTIL_IsValidHandle(m_hConfig))return false;
	m_hConfig.ImportFromFile(sLoc);

	NotifySchemaUpdated();

	return true;
}

public any Native_GetEconomyConfig(Handle plugin, int numParams)
{
	if (!UTIL_IsValidHandle(m_hConfig))
	{
		if (!CE_LoadConfig())
		{
			return INVALID_HANDLE;
		}
	}

	KeyValues kv = new KeyValues("Economy");
	kv.Import(m_hConfig);

	KeyValues hReturn = view_as<KeyValues>(UTIL_ChangeHandleOwner(plugin, kv));
	delete kv;
	return hReturn;
}
