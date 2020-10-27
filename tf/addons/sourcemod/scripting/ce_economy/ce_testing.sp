#pragma semicolon 1
#pragma newdecls required

#include <ce_util>
#include <ce_coordinator>

public Plugin myinfo =
{
	name = "Creators.TF Testing Server",
	author = "Creators.TF Team",
	description = "Creators.TF Testing Server",
	version = "1.00",
	url = "https://creators.tf"
};

ConVar ce_testing_enabled, ce_testing_domain;

bool m_bIsChangeInProgress = false;
bool m_bForcedChange = false;
KeyValues m_hUGC;
int m_iChangeCaller;

public void OnPluginStart()
{
    ce_testing_enabled = CreateConVar("ce_testing_enabled", "0", "Enabled testing server commands and functionality.", FCVAR_PROTECTED);
    ce_testing_domain = CreateConVar("ce_testing_domain", "testing.creators.tf", "Creators.TF Testing web panel domain.", FCVAR_PROTECTED);
    RegAdminCmd("sm_testing_loadmap_force", cTestingLoadMapForce, ADMFLAG_CHANGEMAP, "Load a testing map.");
    RegConsoleCmd("sm_testing_loadmap", cTestingLoadMap, "Load a testing map.");
}

public bool CE_IsTestingEnabled()
{
    return ce_testing_enabled.BoolValue;
}

/**
*	Purpose: 	sm_testing_loadmap command.
*/
public Action cTestingLoadMap(int client, int args)
{
	if (!CE_IsTestingEnabled())
	{
		// Let's pretend this command does not exist.
		return Plugin_Continue;
	}

	char sArg[11];
	GetCmdArg(1, sArg, sizeof(sArg));

	int iIndex = StringToInt(sArg);
	if(iIndex == 0)
	{
		ReplyToCommand(client, "[SM] Your input index is invalid.");
	} else {
		m_bIsChangeInProgress = true;
		m_bForcedChange = false;
		m_iChangeCaller = client;

		CE_FetchUGCMap(iIndex);
	}
	return Plugin_Handled;
}

public Action cTestingLoadMapForce(int client, int args)
{
	if (!CE_IsTestingEnabled())
	{
		// Let's pretend this command does not exist.
		return Plugin_Continue;
	}

	char sArg[11];
	GetCmdArg(1, sArg, sizeof(sArg));

	int iIndex = StringToInt(sArg);
	if(iIndex == 0)
	{
		ReplyToCommand(client, "[SM] Your input index is invalid.");
	} else {
		if(m_bIsChangeInProgress)
		{
			ReplyToCommand(client, "[SM] Change is already requested by %N.", m_iChangeCaller);
		} else {
			m_bIsChangeInProgress = true;
			m_bForcedChange = true;
			m_iChangeCaller = client;

			CE_FetchUGCMap(iIndex);
		}
	}
	return Plugin_Handled;
}

public void CE_FetchUGCMap(int index)
{
	if (!CE_IsTestingEnabled())return;

	char sURL[128];
	ce_testing_domain.GetString(sURL, sizeof(sURL));
	Format(sURL, sizeof(sURL), "http://%s/api/IUploads/GContent?id=%d", sURL, index);

	CESC_SendAPIRequest(sURL, RequestType_GET, HttpFetchCallback);
}

public void HttpFetchCallback(const char[] content, int length, int status, any value)
{
	if (content[0] != '"')return;
	if (status == StatusCode_Success)
	{
		KeyValues kv = new KeyValues("Response");
		kv.ImportFromString(content);
		m_hUGC = kv;

		CE_ReadUGCResponse(kv, true);
	}
}

public void CE_ReadUGCResponse(KeyValues kv, bool vote)
{
	char sResult[32];
	kv.GetString("result", sResult, sizeof(sResult));
	LogMessage("Response (result \"%s\")", sResult);

	if(StrEqual(sResult, "SUCCESS"))
	{
		char sSystemName[64], sName[64], sDir[64], sOutput[128], sHash[256];
		kv.GetString("system_name", sSystemName, sizeof(sSystemName));
		kv.GetString("name", sName, sizeof(sName));
		kv.GetString("dir", sDir, sizeof(sDir));
		kv.GetString("hash", sHash, sizeof(sHash));

		Format(sOutput, sizeof(sOutput), "%s/%s", sDir, sSystemName);

		if(vote && !m_bForcedChange)
		{
			CE_RunMapVote();
		} else {
			LogMessage("[SM] Changing testing map to: %s", sName);
			if(FileExists(sOutput))
			{
				m_bIsChangeInProgress = false;
				// We already downloaded this map. Just load it.
				LogMessage("%s is already downloaded. Changing map.", sSystemName);
				CE_ChangeMap(sSystemName);
			} else {
				LogMessage("Downloading %s (%s) in %s", sName, sSystemName, sOutput);
				CE_DownloadHash(kv, sHash, sOutput);
				return;
			}
		}
	} else {
		m_bIsChangeInProgress = false;
		PrintToChat(m_iChangeCaller, "[SM] This map index was not found.");
	}
}

public void CE_DownloadHash(KeyValues kv, const char[] hash, const char[] output)
{
	if (!CE_IsTestingEnabled())return;
	
	char sURL[128];
	ce_testing_domain.GetString(sURL, sizeof(sURL));
	Format(sURL, sizeof(sURL), "http://%s/api/IUploads/GDownload?hash=%s", sURL, hash);

	CESC_SendAPIRequest(sURL, RequestType_GET, HttpDownloadCallback, _, _, output, kv);
}

public void HttpDownloadCallback(const char[] content, int size, int status, any value)
{
	KeyValues kv = value;
	if (status == StatusCode_Success)
	{
		m_bIsChangeInProgress = false;
		char sSystemName[64];
		kv.GetString("system_name", sSystemName, sizeof(sSystemName));
		LogMessage("Changing map to: %s", sSystemName);
		CE_ChangeMap(sSystemName);
	}
	delete kv;
}

public void CE_ChangeMap(const char[] map)
{
	if (!CE_IsTestingEnabled())return;

	char sMap[128];
	strcopy(sMap, sizeof(sMap), map);
	CleanMapExtension(sMap, sizeof(sMap));

	ServerCommand("sm_map %s", sMap);
}

public void CE_RunMapVote()
{
	if(IsVoteInProgress())
	{
		PrintToChat(m_iChangeCaller, "[SM] Can't initiate vote. One is already in progress.");
		delete m_hUGC;
		return;
	}

	char sName[64], sSystemName[64];
	m_hUGC.GetString("name", sName, sizeof(sName));
	CleanMapExtension(sName, sizeof(sName));
	m_hUGC.GetString("system_name", sSystemName, sizeof(sSystemName));

	Menu menu = new Menu(Handle_VoteMenu);
	menu.SetTitle("%N wants to:\nChange testing map to:\n%s?\n ", m_iChangeCaller, sName);
	menu.AddItem(sSystemName, "Yes");
	menu.AddItem("no", "No");

	menu.ExitButton = false;
	menu.DisplayVoteToAll(20);
}

public int Handle_VoteMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	} else if (action == MenuAction_VoteEnd)
	{
		switch(param1)
		{
			case 0: {
				char map[64];
				menu.GetItem(param1, map, sizeof(map));

				CE_ReadUGCResponse(m_hUGC, false);
			}

			case 1: {
				m_bIsChangeInProgress = false;
				delete m_hUGC;
			}
		}
	}
}

public void CleanMapExtension(char[] map, int length)
{
	char[] sMap = new char[length + 1];
	strcopy(sMap, length, map);

	ReplaceString(sMap, length, ".bsp", "");
	strcopy(map, length, sMap);
}
