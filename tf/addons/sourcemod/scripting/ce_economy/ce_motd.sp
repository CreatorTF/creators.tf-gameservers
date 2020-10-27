#pragma semicolon 1
#pragma newdecls required

#include <ce_util>
#include <ce_core>
#include <tf2>
#include <tf2_stocks>

bool m_bIsMOTDOpen[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Creators.TF Economy - MotD",
	author = "Creators.TF Team",
	description = "Creators.TF MotD",
	version = "1.00",
	url = "https://creators.tf"
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_l", cOpenLoadout, "Opens your Creators.TF Loadout");
	RegConsoleCmd("sm_loadout", cOpenLoadout, "Opens your Creators.TF Loadout");

	RegConsoleCmd("sm_website", cOpenWebsite, "Opens Creators.TF Website");
	RegConsoleCmd("sm_w", cOpenWebsite, "Opens Creators.TF Website");

	RegConsoleCmd("sm_servers", cOpenServers, "Opens Creators.TF Servers");
	RegConsoleCmd("sm_s", cOpenServers, "Opens Creators.TF Servers");

	RegConsoleCmd("sm_contracker", cOpenContracker, "Opens your Creators.TF ConTracker");
	RegConsoleCmd("sm_c", cOpenContracker, "Opens your Creators.TF ConTracker");
	
	RegConsoleCmd("sm_campaign", cOpenCampaign, "Opens active Creators.TF Campaign");
	RegConsoleCmd("sm_ca", cOpenCampaign, "Opens active Creators.TF Campaign");

	RegConsoleCmd("sm_inventory", cOpenInventory, "Opens your Creators.TF Inventory");
	RegConsoleCmd("sm_i", cOpenInventory, "Opens your Creators.TF Inventory");

	RegConsoleCmd("sm_profile", cOpenProfile, "Opens your Creators.TF Profile");
	RegConsoleCmd("sm_p", cOpenProfile, "Opens your Creators.TF Profile");

}

public Action cOpenWebsite(int client, int args)
{
	OpenURL(client, "https://creators.tf");
	return Plugin_Handled;
}

/**
*	Purpose: 	sm_loadout / sm_l command.
*/
public Action cOpenLoadout(int client, int args)
{
	TFClassType class = TF2_GetPlayerClass(client);
	if (class == TFClass_Unknown)return Plugin_Handled;

	char url[PLATFORM_MAX_PATH];
	Format(url, sizeof(url), "https://creators.tf/loadout/");

	switch (class)
	{
		case TFClass_Scout:Format(url, sizeof(url), "%sscout", url);
		case TFClass_Soldier:Format(url, sizeof(url), "%ssoldier", url);
		case TFClass_Pyro:Format(url, sizeof(url), "%spyro", url);
		case TFClass_DemoMan:Format(url, sizeof(url), "%sdemo", url);
		case TFClass_Heavy:Format(url, sizeof(url), "%sheavy", url);
		case TFClass_Engineer:Format(url, sizeof(url), "%sengineer", url);
		case TFClass_Medic:Format(url, sizeof(url), "%smedic", url);
		case TFClass_Sniper:Format(url, sizeof(url), "%ssniper", url);
		case TFClass_Spy:Format(url, sizeof(url), "%sspy", url);
	}

	OpenURL(client, url);
	return Plugin_Handled;
}

/**
*	Purpose: 	sm_servers / sm_s command.
*/
public Action cOpenServers(int client, int args)
{
	OpenURL(client, "https://creators.tf/servers");
	return Plugin_Handled;
}

/**
*	Purpose: 	sm_contracker / sm_c command.
*/
public Action cOpenContracker(int client, int args)
{
	OpenURL(client, "https://creators.tf/contracker");
	return Plugin_Handled;
}

/**
*	Purpose: 	sm_contracker / sm_c command.
*/
public Action cOpenCampaign(int client, int args)
{
	OpenURL(client, "https://creators.tf/campaign");
	return Plugin_Handled;
}

/**
*	Purpose: 	sm_inventory / sm_i command.
*/
public Action cOpenInventory(int client, int args)
{
	char sSteamID[64];
	char url[PLATFORM_MAX_PATH];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	Format(url, sizeof(url), "https://creators.tf/profiles/%s/inventory", sSteamID);

	OpenURL(client, url);
	return Plugin_Handled;
}

/**
*	Purpose: 	sm_profile / sm_p command.
*/
public Action cOpenProfile(int client, int args)
{
	char sSteamID[64];
	char url[PLATFORM_MAX_PATH];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	Format(url, sizeof(url), "http://creators.tf/profiles/%s", sSteamID);

	OpenURL(client, url);
	return Plugin_Handled;
}

public Action OpenURL(int client, const char[] url)
{
	KeyValues hConf = new KeyValues("data");
	hConf.SetNum("type", 2);
	hConf.SetString("msg", url);
	hConf.SetNum("customsvr", 1);

	ShowVGUIPanel(client, "info", hConf);
	delete hConf;

	m_bIsMOTDOpen[client] = true;

	return Plugin_Handled;
}

public void CloseMOTD(int client)
{
	m_bIsMOTDOpen[client] = false;

	KeyValues hConf = new KeyValues("data");
	hConf.SetNum("type", 2);
	hConf.SetString("msg", "about:blank");
	hConf.SetNum("customsvr", 1);

	ShowVGUIPanel(client, "info", hConf, false);
	delete hConf;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	// Since TF2 no longer allows us to check when a MOTD is closed, we'll have to detect player's movements (indicating that motd is no longer open).
	if (m_bIsMOTDOpen[client])
	{
		if (buttons & (IN_ATTACK | IN_JUMP | IN_DUCK | IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_ATTACK2))
		{
			CloseMOTD(client);
		}
	}
}


