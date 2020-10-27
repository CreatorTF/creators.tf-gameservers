#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "0x1"

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <system2>


const float HEARTBEAT_RATE = 30.0;

public Plugin myinfo =
{
	name = "Creators.TF Heartbeat",
	author = PLUGIN_AUTHOR,
	description = "Creators.TF Server List Heartbeat",
	version = PLUGIN_VERSION,
	url = "https://creators.tf"
};

Database g_hDB;
ConVar g_ServerID;

public void OnPluginStart()
{
	g_ServerID = CreateConVar("hb_serverid", "0", "Server ID to heartbeat");

	char error[256];
	g_hDB = SQL_Connect("creators", true, error, sizeof(error));

	if(g_hDB == INVALID_HANDLE)
	{
		CloseHandle(g_hDB);
		SetFailState("Error: Can't connect to Creators.TF Heartbeat database!");
	}else{
		SQL_FastQuery(g_hDB, "SET NAMES \"UTF8\"");
		LogMessage("[ Creators.TF Heartbeat ] Connection to heartbeat database successful.");
		CreateTimer(HEARTBEAT_RATE, Timer_Heartbeat, _, TIMER_REPEAT);
		CreateTimer(0.1, Timer_Heartbeat);
	}
}

public Action Timer_Heartbeat(Handle timer, any data)
{
	char sMap[64], sHostName[128], sPassword[128];
	GetCurrentMap(sMap, sizeof(sMap));

	ConVar hostname = FindConVar("hostname");
	GetConVarString(hostname, sHostName, sizeof(sHostName));
	ConVar password = FindConVar("sv_password");
	GetConVarString(password, sPassword, sizeof(sPassword));

	int iMaxPlayers = MaxClients;
	int iOnline = GetRealClientCount(false);

	for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && (IsClientReplay(i) || IsClientSourceTV(i)))
        {
            iMaxPlayers--;
        }
    }

	char query[256];
	Format(query, 256, "UPDATE tf_servers SET cache = 'm=%s,o=%d,mp=%d,h=%s,p=%d', cache_ts = NOW() WHERE id = %d", sMap, iOnline, iMaxPlayers, sHostName, (StrEqual(sPassword, "") || StrEqual(sPassword, "none")) ? 0 : 1, g_ServerID.IntValue);
	g_hDB.Query(HeartbeatQuery_Respone, query);
}

public void HeartbeatQuery_Respone(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("Failed to Heartbeat. :o");
	}
}

stock int GetRealClientCount(bool inGameOnly = true)
{
    int clients = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (((inGameOnly) ? IsClientInGame(i) : IsClientConnected(i)) && !IsFakeClient(i) && !IsClientReplay(i) && !IsClientSourceTV(i))
        {
            clients++;
        }
    }
    return clients;
}
