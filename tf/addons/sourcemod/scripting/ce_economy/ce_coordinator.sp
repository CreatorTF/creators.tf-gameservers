#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ce_core>
#include <ce_coordinator>
#include <ce_util>
#include <system2>

#define MESSAGE_DELAY 5
#define JOB_FETCH_INTERVAL 5.0
#define MAX_RESPONSE_LENGTH 8192

public Plugin myinfo =
{
	name = "Creators.TF Economy - Server System",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Server System",
	version = "1.00",
	url = "https://creators.tf"
};

bool g_CoreEnabled;

ArrayList m_hMsgQueue;

ConVar ce_economy_backend_domain;
ConVar ce_economy_backend_secure;
ConVar ce_economy_backend_auth;
ConVar ce_server_index;

public void OnPluginStart()
{
	m_hMsgQueue = new ArrayList();
	CreateTimer(JOB_FETCH_INTERVAL, Timer_JobFetch, _, TIMER_REPEAT);

	ce_economy_backend_domain = CreateConVar("ce_economy_backend_domain", "creators.tf", "Creators Economy backend domain.", FCVAR_PROTECTED);
	ce_economy_backend_auth = CreateConVar("ce_economy_backend_auth", "", "", FCVAR_PROTECTED);
	ce_economy_backend_secure = CreateConVar("ce_economy_backend_secure", "1", "", FCVAR_PROTECTED);
	ce_server_index = CreateConVar("ce_server_index", "-1", "", FCVAR_PROTECTED);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_coordinator");
	CreateNative("CESC_SendMessage", Native_SendMessage);
	CreateNative("CESC_SendAPIRequest", Native_SendAPIRequest);
	CreateNative("CESC_GetServerID", Native_GetServerID);
	CreateNative("CESC_GetServerAccessKey", Native_GetServerAccessKey);
}

public Action Timer_JobFetch(Handle timer, any data)
{
	int iServerID = CESC_GetServerID();
	if(iServerID == -1) return;

	char sURL[128];
	Format(sURL, sizeof(sURL), "/api/IServers/GServerCoordinator?server=%d", iServerID);

	int j = 0;
	KeyValues hConf = new KeyValues("messages");
	if(hConf.JumpToKey("messages", true))
	{
		for (int i = 0; i < m_hMsgQueue.Length; i++)
		{
			char sId[11];
			IntToString(j, sId, sizeof(sId));

			KeyValues hMsg = m_hMsgQueue.Get(i);
			if(hConf.JumpToKey(sId, true))
			{
				hConf.Import(hMsg);
				hConf.GoBack();
			}

			delete hMsg;
			m_hMsgQueue.Erase(i);
			i--;
			j++;
		}
		hConf.GoBack();
	}

	char sName[10000];
	hConf.ExportToString(sName, sizeof(sName));
	delete hConf;

	CESC_SendAPIRequest(sURL, RequestType_POST, httpJobCallback, _, sName);
}

public void httpJobCallback(const char[] content, int size, int status, any value)
{
	if(status == StatusCode_Success)
	{
		KeyValues kvResponse = new KeyValues("Jobs");
		kvResponse.ImportFromString(content);

		if(kvResponse.JumpToKey("jobs", false))
		{
			for (int i = 0; i < 512; i++)
			{
				char sName[11];
				IntToString(i, sName, sizeof(sName));
				char sCommand[512];
				kvResponse.GetString(sName, sCommand, sizeof(sCommand));
				if (StrEqual(sCommand, ""))break;
				ReplaceString(sCommand, sizeof(sCommand), "&quot;", "\"");

				LogMessage("[CE Jobs] Executing command: %s", sCommand);
				ServerCommand(sCommand);
			}
		}
		delete kvResponse;
	}
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "ce_core"))
	{
		g_CoreEnabled = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "ce_core"))
	{
		g_CoreEnabled = false;
	}
}

public any Native_SendAPIRequest(Handle plugin, int numParams)
{
	char sUrl[128], sOutput[256], sData[4096];
	// Getting URL that we have to send req to.
	GetNativeString(1, sUrl, sizeof(sUrl));

	// Request type of the request.
	RequestTypes nType = GetNativeCell(2);

	// Request callback.
	Function callback = GetNativeFunction(3);

	// Send a request as a client.
	int client = GetNativeCell(4);

	// Getting data that we need to provide.
	GetNativeString(5, sData, sizeof(sData));

	// Local file path we should save output to.
	GetNativeString(6, sOutput, sizeof(sOutput));

	// Custom value.
	any value = GetNativeCell(7);

	// Make sure we have a valid server id set.
	int iServerID = CESC_GetServerID();
	if(iServerID == -1) return;

	// Preparing url of the request.
	char sURL[128];

	// If we don't have :// in the URL that means this is
	// not the full URL. We add base domain name
	// in the beginning.
	if(StrContains(sURL, "://") == -1)
	{
		if(sURL[0] != '/')
		{
			// We need to make sure we have a slash before URL, so we
			// can form a proper link in the end.
			Format(sURL, sizeof(sURL), "/%s", sURL);
		}
		ce_economy_backend_domain.GetString(sURL, sizeof(sURL));

		if(ce_economy_backend_secure.BoolValue)
		{
			Format(sURL, sizeof(sURL), "https://%s%s", sURL, sUrl);
		} else {
			Format(sURL, sizeof(sURL), "http://%s%s", sURL, sUrl);
		}
	}

	System2HTTPRequest httpMessage = new System2HTTPRequest(httpRequestCallback, sURL);

	// Access Header
	char sHeaderAuth[PLATFORM_MAX_PATH];
	CESC_GetServerAccessKey(sHeaderAuth, sizeof(sHeaderAuth));
	Format(sHeaderAuth, sizeof(sHeaderAuth), "server %s %d", sHeaderAuth, iServerID);

	if(IsClientReady(client))
	{
		char sSteamID[64];
		GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));
		Format(sHeaderAuth, sizeof(sHeaderAuth), "%s %s", sHeaderAuth, sSteamID);
	}

	httpMessage.SetHeader("Access", sHeaderAuth);

	// Authorization Header
	ce_economy_backend_auth.GetString(sHeaderAuth, sizeof(sHeaderAuth));
	httpMessage.SetHeader("Authorization", sHeaderAuth);

	// Accept Header
	httpMessage.SetHeader("Content-Type", "text/keyvalues");
	httpMessage.SetHeader("Accept", "text/keyvalues");

	// Setting data of the request.
	if(!StrEqual(sData, ""))
	{
		httpMessage.SetData(sData);
	}

	// Setting output file of the request.
	if(!StrEqual(sOutput, ""))
	{
		httpMessage.SetOutputFile(sOutput);
	}

	DataPack hPack = new DataPack();
	hPack.WriteFunction(callback);
	hPack.WriteCell(plugin);
	hPack.WriteCell(value);
	hPack.Reset();

	// Saving callback.
	httpMessage.Any = hPack;

	// Making proper request type.
	if (nType == RequestType_GET)
	{
		httpMessage.GET();
	}else if (nType == RequestType_POST)
	{
		httpMessage.POST();
	}

	delete httpMessage;
}

public void httpRequestCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if (!UTIL_IsValidHandle(response))return;

	char content[MAX_RESPONSE_LENGTH];
	if(response.ContentLength <= MAX_RESPONSE_LENGTH)
	{
		response.GetContent(content, response.ContentLength + 1);
	}

	DataPack hPack = request.Any;
	if (!UTIL_IsValidHandle(hPack))return;
	Function fnCallback = hPack.ReadFunction();
	Handle plugin = hPack.ReadCell();

	any value = hPack.ReadCell();
	delete hPack;

	Call_StartFunction(plugin, fnCallback);
	Call_PushString(content);
	Call_PushCell(response.ContentLength);
	Call_PushCell(response.StatusCode);
	Call_PushCell(value);
	Call_Finish();
}

/**
*	Native: CESC_SendMessage
*	Purpose: 	Sends message to coordinator.
*/
public any Native_SendMessage(Handle plugin, int numParams)
{
	if (!g_CoreEnabled)return;

	// Getting content of a message.
	KeyValues hContent = GetNativeCell(1);
	// Name of the message.
	char sName[128];
	GetNativeString(2, sName, sizeof(sName));

	// Create message KeyValue.
	KeyValues hMessage = new KeyValues("Message");

	// Set message name.
	hMessage.SetString("msg_name", sName);

	// If we have a valid content KeyValues provided, we import the content to
	// msg_content subkey.
	if(hMessage.JumpToKey("msg_content", true))
	{
		if(UTIL_IsValidHandle(hContent))
		{
			hMessage.Import(hContent);
		}
	}
	// Rewind the KeyValues to prepare for execution.
	hMessage.Rewind();

	// Add the message intot the queue.
	m_hMsgQueue.Push(hMessage);
}

/**
*	Native: CESC_GetServerID
*	Purpose: Returns this server id.
*/
public any Native_GetServerID(Handle plugin, int numParams)
{
	return ce_server_index.IntValue;
}

public any Native_GetServerAccessKey(Handle plugin, int numParams)
{
	int length = GetNativeCell(2);
	char[] buffer = new char[length + 1];

	char sLoc[96];
	BuildPath(Path_SM, sLoc, 96, "configs/creators.cfg");
	KeyValues kv = new KeyValues("Creators");
	if (kv.ImportFromFile(sLoc))
	{
		kv.GetString("key", buffer, length, "");
	}
	delete kv;

	SetNativeString(1, buffer, length);
}
