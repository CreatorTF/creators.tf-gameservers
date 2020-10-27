#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#include <sdktools>
#include <ce_core>
#include <ce_util>
#include <ce_manager_responses>

KeyValues m_hResponses;
char m_sLastResponse[MAXPLAYERS + 1][128];
int m_iLastIndex[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Creators.TF Economy - Responses Manager",
	author = "Creators.TF Team",
	description = "Creators.TF Economy - Responses Manager",
	version = "1.0",
	url = "https://creators.tf"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_manager_responses");

	CreateNative("ClientPlayResponse", Native_ClientPlayResponse);
}

public void OnMapStart()
{
	// We don't really need this, becase SM Downloader is adding everything for us.
	/*
	if (!UTIL_IsValidHandle(m_hResponses))
	{
		if (!CE_LoadConfig()) return;
	}

	KeyValues hConf = m_hResponses;
	if(hConf.GotoFirstSubKey())
	{
		do {
			if(hConf.JumpToKey("rndwave", false))
			{
				if(hConf.GotoFirstSubKey(false))
				{
				 	do {
			 			char sSound[128];
			 			hConf.GetString(NULL_STRING, sSound, sizeof(sSound));

			 			AddFileToDownloadsTable(sSound);
				 	} while (hConf.GotoNextKey(false));
				 	hConf.GoBack();
				}
				hConf.GoBack();
			}
		} while (hConf.GotoNextKey());
		hConf.GoBack();
	}
	hConf.Rewind();
	*/
}

public bool CE_LoadConfig()
{
	delete m_hResponses;

	char sLoc[96];
	BuildPath(Path_SM, sLoc, 96, "configs/responses.cfg");

	m_hResponses = new KeyValues("Responses");
	if (!UTIL_IsValidHandle(m_hResponses))return false;
	m_hResponses.ImportFromFile(sLoc);
	return true;
}

public any Native_ClientPlayResponse(Handle plugin, int numParams)
{
	if (!UTIL_IsValidHandle(m_hResponses))
	{
		if (!CE_LoadConfig()) return;
	}

	int client = GetNativeCell(1);
	if (!IsClientReady(client))return;

	char response[128];
	GetNativeString(2, response, sizeof(response));

	if(!StrEqual(m_sLastResponse[client], response))
	{
		m_iLastIndex[client] = -1;
	}
	strcopy(m_sLastResponse[client], 128, response);

	KeyValues hConf = m_hResponses;

	if(hConf.JumpToKey(response, false))
	{
		if(hConf.JumpToKey("rndwave", false))
		{
			int iCount = KvSubKeyCount(hConf);
			if(iCount > 0)
			{
				int iIndex;
				if(iCount > 1)
				{
					do {
						iIndex = GetRandomInt(0, iCount - 1);
					} while (iIndex == m_iLastIndex[client]);
				}

				m_iLastIndex[client] = iIndex;

				if(hConf.GotoFirstSubKey(false))
				{
				 	int i = 0;
				 	do {
				 		if(iIndex == i)
				 		{
				 			char sSound[128];
				 			hConf.GetString(NULL_STRING, sSound, sizeof(sSound));

				 			ClientCommand(client, "playgamesound %s", sSound);
				 			break;
				 		}
				 		i++;
				 	} while (hConf.GotoNextKey(false));
				}
			}
		}
	}

	m_hResponses.Rewind();
}
