#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#include <ce_core>
#include <ce_util>
#include <sdkhooks>
#include <ce_manager_items>
#include <ce_manager_attributes>
#include <ce_coordinator>
#include <tf2_stocks>
#include <tf2>

public Plugin myinfo =
{
	name = "Creators.TF Economy - Loadouts",
	author = "Creators.TF Team",
	description = "Creators.TF Economy - Loadouts",
	version = "1.0",
	url = "https://creators.tf"
}

KeyValues m_hLoadout[MAXPLAYERS + 1];
ArrayList m_hMyItems[MAXPLAYERS + 1];

bool m_bInRespawn[MAXPLAYERS + 1];
bool m_bFullReapplication[MAXPLAYERS + 1];
bool m_bWaitingForLoadout[MAXPLAYERS + 1];

Handle g_hOnInventoryApplication;

public void OnPluginStart()
{
	g_hOnInventoryApplication = CreateGlobalForward("CE_OnInventoryApplication", ET_Ignore, Param_Cell, Param_Cell);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_loadout");

	HookEvent("post_inventory_application", post_inventory_application);
	HookEvent("player_spawn", player_spawn);
	HookEvent("player_death", player_death);

	RegServerCmd("ce_resetloadout", cResetLoadout);

	CreateNative("CE_IsPlayerWearingEconIndex", Native_IsPlayerWearingEconIndex);
}

public void OnMapStart()
{
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "func_respawnroom")) != -1)
	{
		SDKHook(iEntity, SDKHook_StartTouchPost, OnRespawnRoomStartTouch);
		SDKHook(iEntity, SDKHook_EndTouchPost, OnRespawnRoomEndTouch);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1)return;

	if (StrEqual(classname, "func_respawnroom"))
	{
		SDKHook(entity, SDKHook_StartTouchPost, OnRespawnRoomStartTouch);
		SDKHook(entity, SDKHook_EndTouchPost, OnRespawnRoomEndTouch);
	}
}

public void OnClientAuthorized(int client, const char[] auth)
{
	ClearLoadoutCache(client);
}

public void OnClientDisconnect(int client)
{
	ClearLoadoutCache(client);
}


public void OnRespawnRoomStartTouch(int iSpawnRoom, int iClient)
{
	if(IsClientValid(iClient))
	{
		m_bInRespawn[iClient] = true;
	}
}

public void OnRespawnRoomEndTouch(int iSpawnRoom, int iClient)
{
	if(IsClientValid(iClient))
	{
		m_bInRespawn[iClient] = false;
	}
}

public any Native_IsPlayerWearingEconIndex(Handle plugin, int numParams)
{
	int iClient = GetNativeCell(1);
	int iIndex = GetNativeCell(2);
	if(!IsClientValid(iClient)) return false;
	if (!UTIL_IsValidHandle(m_hMyItems[iClient]))return false;

	return m_hMyItems[iClient].FindValue(iIndex) != -1;
}

public Action player_death(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	RemoveAllWearables(client);
	m_bInRespawn[client] = false;
}

public Action post_inventory_application(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	RequestFrame(RF_InventoryApplication, client);
}

public void RF_InventoryApplication(int client)
{
	if(m_bFullReapplication[client])
	{
		InventoryApplication(client, true);
	} else {
		InventoryApplication(client, false);
	}

	m_bFullReapplication[client] = false;
}

public Action player_spawn(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	m_bFullReapplication[client] = true;

	// Users are in respawn room by default when they spawn.
	m_bInRespawn[client] = true;

	for(int i = 0; i < 5; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if(IsValidEntity(iWeapon))
		{
			SetEntProp(iWeapon, Prop_Send, "m_bBeingRepurposedForTaunt", 0);
		}
	}
}

public void InventoryApplication(int client, bool full)
{
	if (IsClientReady(client) && !m_bWaitingForLoadout[client])
	{
		if(full)
		{
			// Full reapplication implies that player has no items equipped.
			// This means, we're safe to clear the array of wearable items.
			RemoveAllWearables(client);
		} else {
			// On partial reapplication, we only have cosmetics and weapons removed due to TF2's code.
			RemoveWearableOfType(client, "cosmetic");
			RemoveWearableOfType(client, "action");
			RemoveWearableOfType(client, "weapon");
		}

		if (HasCachedLoadout(client))
		{
			// If cached loadout is still recent, we parse cached response.
			ApplyLoadout(client, m_hLoadout[client]);
		} else {
			// Otherwise request for the most recent data.
			RequestPlayerLoadout(client, true);
		}

		Call_StartForward(g_hOnInventoryApplication);
		Call_PushCell(client);
		Call_PushCell(full);
		Call_Finish();
	}
}

public Action cResetLoadout(int args)
{
	char sArg1[64], sArg2[11];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));

	int iTarget = FindTargetBySteamID(sArg1);
	if (IsClientValid(iTarget))
	{
		RequestPlayerLoadout(iTarget, false);

	}
	return Plugin_Handled;
}

public Action evPlayerDeath(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));

	if(UTIL_IsValidHandle(m_hMyItems[client]))
	{
		// We died, we have no equipped items.
		delete m_hMyItems[client];
	}
}

public bool IsWearingItemIndex(int client, int index)
{
	if (!UTIL_IsValidHandle(m_hMyItems[client]))return false;


	for (int i = 0; i < m_hMyItems[client].Length; i++)
	{
		CEEconItem hItem;
		m_hMyItems[client].GetArray(i, hItem);
		if(hItem.m_iIndex == index)
		{
			return true;
		}
	}
	return false;
}

public bool HasLoadoutItemIndex(KeyValues loadout, int index)
{
	KeyValues kv = new KeyValues("Loadout");
	kv.Import(loadout);

	bool bResult = false;
	if(kv.GotoFirstSubKey())
	{
		do {
			int iIndex = kv.GetNum("id");
			if (index == iIndex)
			{
				bResult = true;
				break;
			}
		} while (kv.GotoNextKey());
	}

	delete kv;
	return bResult;
}

public void RequestPlayerLoadout(int client, bool apply)
{
	m_bWaitingForLoadout[client] = true;

	DataPack pack = new DataPack();
	pack.WriteCell(client);
	pack.WriteCell(apply);
	pack.Reset();

	CESC_SendAPIRequest("/api/IUsers/GLoadout", RequestType_GET, httpPlayerLoadout, client, _, _, pack);
}

public void httpPlayerLoadout(const char[] content, int size, int status, any pack)
{
	DataPack hPack = pack;
	int client = hPack.ReadCell();
	bool apply = hPack.ReadCell();
	delete hPack;

	if(status == StatusCode_Success)
	{
		if (content[0] != '"')return;

		if (!IsClientReady(client))return;

		KeyValues kv = new KeyValues("Loadout");
		KeyValues hLoadout;

		kv.ImportFromString(content);
		if(kv.JumpToKey("loadout"))
		{
			hLoadout = KvSetRoot(kv);
		}
		delete kv;

		int bChanged = HasClassLoadoutChanged(client, TF2_GetPlayerClass(client), hLoadout);

		ClearLoadoutCache(client);
		m_bWaitingForLoadout[client] = false;
		m_hLoadout[client] = hLoadout;

		if(bChanged && m_bInRespawn[client])
		{
			TF2_RespawnPlayer(client);

		} else if(apply)
		{
			ApplyLoadout(client, m_hLoadout[client]);
		}
	}
}

public bool HasClassLoadoutChanged(int client, TFClassType class, KeyValues kv)
{
	if (class == TFClass_Unknown)return false;
	if (!UTIL_IsValidHandle(m_hLoadout[client]))return false;
	if (!UTIL_IsValidHandle(kv))return false;

	KeyValues kv1 = new KeyValues("Loadout");
	kv1.Import(m_hLoadout[client]);

	KeyValues kv2 = new KeyValues("Loadout");
	kv2.Import(kv);

	char sClass[16];
	switch (class)
	{
		case TFClass_Scout:strcopy(sClass, sizeof(sClass), "scout");
		case TFClass_Soldier:strcopy(sClass, sizeof(sClass), "soldier");
		case TFClass_Pyro:strcopy(sClass, sizeof(sClass), "pyro");
		case TFClass_DemoMan:strcopy(sClass, sizeof(sClass), "demo");
		case TFClass_Heavy:strcopy(sClass, sizeof(sClass), "heavy");
		case TFClass_Engineer:strcopy(sClass, sizeof(sClass), "engineer");
		case TFClass_Medic:strcopy(sClass, sizeof(sClass), "medic");
		case TFClass_Sniper:strcopy(sClass, sizeof(sClass), "sniper");
		case TFClass_Spy:strcopy(sClass, sizeof(sClass), "spy");
	}

	if(kv1.JumpToKey(sClass, true) && kv2.JumpToKey(sClass, true))
	{
		int iCount1 = KvSubKeyCount(kv1);
		int iCount2 = KvSubKeyCount(kv2);

		// If counts differ, it's obvious that something got changed.
		if (iCount1 != iCount2)
		{
			delete kv1;
			delete kv2;
			return true;
		}

		// Otherwise, all items should match with their counterparts.
		if(kv1.GotoFirstSubKey())
		{
			do {
				char sName[11];
				kv1.GetSectionName(sName, sizeof(sName));

				int iIndex1 = kv1.GetNum("id");

				Format(sName, sizeof(sName), "%s/id", sName);
				int iIndex2 = kv2.GetNum(sName);

				if(iIndex1 != iIndex2)
				{
					delete kv1;
					delete kv2;
					return true;
				}
			} while (kv1.GotoNextKey());
		}
	}

	delete kv1;
	delete kv2;
	return false;
}

public void ClearLoadoutCache(int client)
{
	LogMessage("Cleaned loadout info for %N", client);
	delete m_hLoadout[client];
}

public bool HasCachedLoadout(int client)
{
	return UTIL_IsValidHandle(m_hLoadout[client]);
}

public void ApplyLoadout(int client, KeyValues loadout)
{
	KeyValues kv = new KeyValues("Loadout");
	kv.Import(loadout);

	// First we check if player has a valid TFClass.
	TFClassType nClass = TF2_GetPlayerClass(client);

	// Getting class type of the client in a string.
	char sClass[16];
	switch (nClass)
	{
		case TFClass_Scout:strcopy(sClass, sizeof(sClass), "scout");
		case TFClass_Soldier:strcopy(sClass, sizeof(sClass), "soldier");
		case TFClass_Pyro:strcopy(sClass, sizeof(sClass), "pyro");
		case TFClass_DemoMan:strcopy(sClass, sizeof(sClass), "demo");
		case TFClass_Heavy:strcopy(sClass, sizeof(sClass), "heavy");
		case TFClass_Engineer:strcopy(sClass, sizeof(sClass), "engineer");
		case TFClass_Medic:strcopy(sClass, sizeof(sClass), "medic");
		case TFClass_Sniper:strcopy(sClass, sizeof(sClass), "sniper");
		case TFClass_Spy:strcopy(sClass, sizeof(sClass), "spy");
	}

	kv.JumpToKey(sClass, false);

	// First we check if we need to unequip anything.
	if(UTIL_IsValidHandle(m_hMyItems[client]))
	{
		for (int i = 0; i < m_hMyItems[client].Length; i++)
		{
			CEEconItem hItem;
			m_hMyItems[client].GetArray(i, hItem);

			if(!HasLoadoutItemIndex(kv, hItem.m_iIndex))
			{
				RemoveWearableItem(client, hItem);
				i--;
			}
		}
	}

	// Now check if we need to equip anything.
	if(kv.GotoFirstSubKey())
	{
		do {
			CEEconItem hItem;

			int iIndex = kv.GetNum("id");
			int iDefID = kv.GetNum("defid");
			int iQuality = kv.GetNum("quality");

			KeyValues hConf = CE_FindItemConfigByDefIndex(iDefID);
			if (!UTIL_IsValidHandle(hConf))continue;

			char sType[32];
			hConf.GetString("type", sType, sizeof(sType));
			delete hConf;

			CreateCEEconItem(hItem, iIndex, iDefID, iQuality, sType);
			if(!IsWearingItemIndex(client, hItem.m_iIndex))
			{
				ArrayList hAttributes;

				if(kv.JumpToKey("attributes", false))
				{
					hAttributes = CE_KeyValuesToAttributesArray(kv);
					kv.GoBack();
				}

				CE_EquipItem(client, iIndex, iDefID, iQuality, hAttributes);
				delete hAttributes;

				AddWearableItem(client, hItem);

			}
		} while (kv.GotoNextKey());
	}

	delete kv;
}

public void RemoveAllWearables(int client)
{
	delete m_hMyItems[client];
}

public void AddWearableItem(int client, CEEconItem item)
{
	if(!UTIL_IsValidHandle(m_hMyItems[client]))
	{
		m_hMyItems[client] = new ArrayList(sizeof(CEEconItem));
	}

	m_hMyItems[client].PushArray(item);
}

public void RemoveWearableItem(int client, CEEconItem item)
{
	if (!UTIL_IsValidHandle(m_hMyItems[client]))return;

	// Making sure we don't have duplicates.
	for (int i = 0; i < m_hMyItems[client].Length; i++)
	{
		CEEconItem hItem;
		m_hMyItems[client].GetArray(i, hItem);
		if(hItem.m_iIndex == item.m_iIndex)
		{
			m_hMyItems[client].Erase(i);
			i--;
		}
	}
}

public void CreateCEEconItem(CEEconItem item, int index, int def, int quality, const char[] type)
{
	item.m_iIndex = index;
	item.m_iDefinitionIndex = def;
	item.m_iQuality = quality;
	strcopy(item.m_sType, 32, type);
}

public void RemoveWearableOfType(int client, const char[] type)
{
	if (!UTIL_IsValidHandle(m_hMyItems[client]))return;

	for (int i = 0; i < m_hMyItems[client].Length; i++)
	{
		CEEconItem hItem;
		m_hMyItems[client].GetArray(i, hItem);

		if(StrEqual(hItem.m_sType, type))
		{
			RemoveWearableItem(client, hItem);
			i--;
		}
	}
}
