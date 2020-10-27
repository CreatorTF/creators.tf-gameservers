#pragma semicolon 1
#pragma newdecls required

#include <ce_util>
#include <ce_coordinator>
#include <basecomm>

#define SERVER_INFO_INTERVAL 30.0

bool g_bGCEnabled = true;

public Plugin myinfo =
{
	name = "Creators.TF Economy - User Manager",
	author = "Creators.TF Team",
	description = "Creators.TF User Manager",
	version = "1.01",
	url = "https://creators.tf"
};

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "ce_coordinator"))
	{
		g_bGCEnabled = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "ce_coordinator"))
	{
		g_bGCEnabled = false;
	}
}

public void OnClientPostAdminCheck(int client)
{
	CESC_SendPlayerJoinMessage(client);
}

public void OnClientDisconnect(int client)
{
	CESC_SendPlayerLeaveMessage(client);
}

public void OnPluginStart()
{
	//AddCommandListener(Command_Say, "say");
	//AddCommandListener(Command_Say, "say_team");
	AddCommandListener(Command_Callvote, "callvote");

	CreateTimer(SERVER_INFO_INTERVAL, Timer_ServerInfo, _, TIMER_REPEAT);
}

public Action Timer_ServerInfo(Handle timer, any data)
{
	CESC_SendServerInfoMessage();
}

public Action Command_Callvote(int client, const char[] command, int args)
{
	if (args < 2) return Plugin_Continue;

	char sReason[16];
	GetCmdArg(1, sReason, sizeof(sReason));

	if (!StrEqual(sReason, "kick")) return Plugin_Continue;

	char sRest[256];
	GetCmdArg(2, sRest, sizeof(sRest));

	int iUserId = 0;
	int iSpacePos = FindCharInString(sRest, ' ');
	if (iSpacePos > -1)
	{
		char sTemp[12];
		strcopy(sTemp, MIN(iSpacePos + 1, sizeof(sTemp)), sRest);
		iUserId = StringToInt(sTemp);
	} else iUserId = StringToInt(sRest);

	int iTarget = GetClientOfUserId(iUserId);
	if (iTarget < 1) return Plugin_Continue;

	CESC_SendKickVoteMessage(client, iTarget);
	return Plugin_Continue;
}

/*
public Action Command_Say(int client, const char[] command, int args)
{
	if (!IsClientValid(client))return Plugin_Continue;
	if(BaseComm_IsClientGagged(client))
	{
		return Plugin_Handled;
	}

	char sText[512];
	GetCmdArgString(sText, sizeof(sText));
	StripQuotes(sText);
	if(StrEqual(command, "say"))
	{
		CESC_SendChatMessage(client, sText, false);
	} else if(StrEqual(command, "say_team"))
	{
		CESC_SendChatMessage(client, sText, true);
	}
	return Plugin_Continue;
}
*/
/*
public void CESC_SendChatMessage(int client, const char[] text, bool isTeam)
{
	if (!g_bGCEnabled)return;
	if (!IsClientReady(client))return;
	KeyValues hMessage = new KeyValues("content");

	char sSteamID[64], sSteamID64[64], sName[256];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	GetClientAuthId(client, AuthId_SteamID64, sSteamID64, sizeof(sSteamID64));
	GetClientName(client, sName, sizeof(sName));

	hMessage.SetString("steamid", sSteamID);
	hMessage.SetString("steamid_64", sSteamID64);
	hMessage.SetString("name", sName);
	hMessage.SetString("message", text);
	hMessage.SetNum("team", isTeam ? 1 : 0);

	CESC_SendMessage(hMessage, "player_chat_log");
	delete hMessage;
}
*/

public void CESC_SendKickVoteMessage(int client, int target)
{
	if (!g_bGCEnabled)return;
	if (!IsClientInGame(client) || !IsClientInGame(target))return;
	KeyValues hMessage = new KeyValues("content");

	char sSteamID[64], sSteamID2[64], sName[256], sName2[256];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	GetClientAuthId(target, AuthId_Steam2, sSteamID2, sizeof(sSteamID2));
	GetClientName(client, sName, sizeof(sName));
	GetClientName(target, sName2, sizeof(sName2));

	hMessage.SetString("caller", sSteamID);
	hMessage.SetString("target", sSteamID2);
	hMessage.SetString("target_name", sName);
	hMessage.SetString("caller_name", sName2);

	CESC_SendMessage(hMessage, "player_kickvote_log");
	delete hMessage;
}

public void CESC_SendServerInfoMessage()
{
	if (!g_bGCEnabled)return;
	KeyValues hMessage = new KeyValues("content");
	
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientReady(i))continue;

		char sSteamID[64];
		GetClientAuthId(i, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
		
		char sKey[32];
		Format(sKey, sizeof(sKey), "steamids/%d", count);
		hMessage.SetString(sKey, sSteamID);
		count++;
	}

	CESC_SendMessage(hMessage, "server_info");
	delete hMessage;
}

public void CESC_SendPlayerJoinMessage(int client)
{
	if (!g_bGCEnabled)return;
	if (IsFakeClient(client))return;
	KeyValues hMessage = new KeyValues("content");
	
	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	
	hMessage.SetString("steamid", sSteamID);

	CESC_SendMessage(hMessage, "player_join");
	delete hMessage;
}

public void CESC_SendPlayerLeaveMessage(int client)
{
	if (!g_bGCEnabled)return;
	if (IsFakeClient(client))return;
	KeyValues hMessage = new KeyValues("content");
	
	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	
	hMessage.SetString("steamid", sSteamID);

	CESC_SendMessage(hMessage, "player_left");
	delete hMessage;
}