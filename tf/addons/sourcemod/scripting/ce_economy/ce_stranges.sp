#pragma semicolon 1
#pragma newdecls required

#include <ce_core>
#include <ce_util>
#include <sdkhooks>
#include <ce_events>
#include <ce_styles>
#include <ce_stranges>
#include <ce_manager_attributes>
#include <ce_manager_items>
#include <ce_coordinator>
#include <ce_complex_conditions>
#include <tf2_stocks>

int m_iLevel[MAX_ENTITY_LIMIT + 1];
CEStrangePart m_hParts[MAX_ENTITY_LIMIT + 1][MAX_STRANGE_PARTS + 1];
ArrayList m_hPartsList;

public Plugin myinfo =
{
	name = "Creators.TF Economy - Stranges Handler",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Stranges Handler",
	version = "1.00",
	url = "https://creators.tf"
};

Handle g_hOnEconItemNewLevel;

public void OnPluginStart()
{
	g_hOnEconItemNewLevel = CreateGlobalForward("OnEconItemNewLevel", ET_Ignore, Param_Cell, Param_Cell, Param_String);
	RegServerCmd("ce_strange_item_levelup", cItemLevelUp);
}

public void OnAllPluginsLoaded()
{
	KeyValues hSchema = CE_GetEconomyConfig();
	if(hSchema == INVALID_HANDLE) return;
	ParseEconomySchema(hSchema);
	delete hSchema;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_stranges");

	CreateNative("CEEaters_FindLevelDataByName", Native_FindLevelDataByName);
	CreateNative("CEEaters_GetItemLevelData", Native_GetItemLevelData);
	CreateNative("CEEaters_GetAttributeByPartIndex", Native_GetAttributeByPartIndex);
}

public Action cItemLevelUp(int args)
{
	char sArg1[64], sArg2[11], sArg3[128], sArg4[128];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	GetCmdArg(3, sArg3, sizeof(sArg3));
	GetCmdArg(4, sArg4, sizeof(sArg4));

	int client = FindTargetBySteamID(sArg1);
	if(IsClientReady(client))
	{
		int index = StringToInt(sArg2);

		Call_StartForward(g_hOnEconItemNewLevel);
		Call_PushCell(client);
		Call_PushCell(index);
		Call_PushString(sArg4);
		Call_Finish();

		char sTarget[512];
		Format(sTarget, sizeof(sTarget), "Your %s\nhas reached a new rank:\n\"%s\"!\n ", sArg3, sArg4);

		Panel hMenu = new Panel();
		hMenu.SetTitle(sTarget);
		hMenu.DrawItem("Close", ITEMDRAW_CONTROL);
		hMenu.DrawItem("Close", ITEMDRAW_CONTROL);
		hMenu.DrawItem("Close", ITEMDRAW_CONTROL);
		hMenu.DrawItem("Close", ITEMDRAW_CONTROL);
		hMenu.Send(client, Handler_DoNothing, 5);

		ClientCommand(client, "playgamesound Hud.Hint");

	}

	return Plugin_Handled;
}

public void CE_OnSchemaUpdated(KeyValues hConf)
{
	ParseEconomySchema(hConf);
}

public void ParseEconomySchema(KeyValues hConf)
{
	FlushPartsMemory();
	if(hConf.JumpToKey("Stranges/StrangeParts", false))
	{
		if(hConf.GotoFirstSubKey())
		{
			do {
				char sIndex[11];
				hConf.GetSectionName(sIndex, sizeof(sIndex));

				CEStrangePart hPart;
				hPart.m_iIndex = StringToInt(sIndex);

				for (int j = 0; j < MAX_HOOKS; j++)
				{
					char sKey[32];
					Format(sKey, sizeof(sKey), "hooks/%d/event", j);

					char sEvent[32];
					hConf.GetString(sKey, sEvent, sizeof(sEvent));
					if (StrEqual(sEvent, ""))continue;

					CELogicEvents nEvent = CEEvents_GetEventIndex(sEvent);
					if(nEvent > LOGIC_NULL)
					{
						hPart.m_nEvents[j] = nEvent;
					}
				}

				AddPartToMemoryList(hPart);

			} while (hConf.GotoNextKey());
		}
	}
	hConf.Rewind();
}

public void FlushPartsMemory()
{
	delete m_hPartsList;
}

public void AddPartToMemoryList(CEStrangePart hPart)
{
	if (!UTIL_IsValidHandle(m_hPartsList))m_hPartsList = new ArrayList(sizeof(CEStrangePart));
	m_hPartsList.PushArray(hPart);
}

public bool FindPartPrefab(int index, CEStrangePart hPart)
{
	if (!UTIL_IsValidHandle(m_hPartsList))return false;
	for (int i = 0; i < m_hPartsList.Length; i++)
	{
		CEStrangePart part;
		m_hPartsList.GetArray(i, part);
		if(part.m_iIndex == index)
		{
			hPart = part;
			return true;
		}
	}
	return false;
}


public int Handler_DoNothing(Menu menu, MenuAction action, int param1, int param2)
{
	/* Do nothing */
}

public void FlushEntityData(int entity)
{
	for(int i = 0; i < MAX_STRANGE_PARTS; i++)
	{
		for (int j = 0; j < MAX_HOOKS; j++)
		{
			m_hParts[entity][i].m_iIndex = 0;
			m_hParts[entity][i].m_nEvents[j] = LOGIC_NULL;
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1)return;
	FlushEntityData(entity);
}

public void OnEntityDestroyed(int entity)
{
	if (entity < 1)return;
	FlushEntityData(entity);
}

public void CEEvents_OnSendEvent(int client, CELogicEvents event, int add)
{
	if (!IsClientValid(client))return;
	
	int iActiveWeapon = CEEvents_LastUsedWeapon(client);
	for (int i = 0; i < 5; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if (!IsValidEntity(iWeapon))continue;
		if (iWeapon != iActiveWeapon)continue;
		if (!CE_IsEntityCustomEcomItem(iWeapon))continue;

		CEStranges_TickleStrangeParts(client, iWeapon, event, add);
	}

	int iEdict = -1;
	while((iEdict = FindEntityByClassname(iEdict, "tf_wearable*")) != -1)
	{
		char sClass[32];
		GetEntityNetClass(iEdict, sClass, sizeof(sClass));
		if (!StrEqual(sClass, "CTFWearable") && !StrEqual(sClass, "CTFWearableCampaignItem"))continue;

		if (GetEntPropEnt(iEdict, Prop_Send, "m_hOwnerEntity") != client)continue;
		if (!CE_IsEntityCustomEcomItem(iEdict))continue;

		CEStranges_TickleStrangeParts(client, iEdict, event, add);
	}
}

public void CE_OnPostEquip(int client, int entity, int index, int defid, int quality, ArrayList hAttributes, char[] type)
{
	if(entity == -1) return;
	FlushEntityData(entity);

	int iPart = CE_GetAttributeInteger(entity, "strange eater");
	if(iPart > 0)
	{
		int iValue = CE_GetAttributeInteger(entity, "strange eater value");
		KeyValues hLevels = CEEaters_GetItemLevelData(defid);

		int iLevel, iStyle;

		if(hLevels.GotoFirstSubKey())
		{
			do{
				char sPoints[11];
				hLevels.GetSectionName(sPoints, sizeof(sPoints));
				int iPoints = StringToInt(sPoints);

				if (iPoints > iValue)break;

				iLevel = iPoints;
				iStyle = hLevels.GetNum("item_style", 0);

			} while (hLevels.GotoNextKey());
		}
		m_iLevel[entity] = iLevel;

		bool bLevelChangesStyle = CE_GetAttributeInteger(entity, "style changes on strange level") > 0;
		if(bLevelChangesStyle)
		{
			CEStyles_SetStyle(entity, iStyle);
		}

		delete hLevels;
	}

	if (CE_GetAttributeInteger(entity, "is_operation_pass") > 0)return;

	for(int i = 0; i < MAX_STRANGE_PARTS; i++)
	{
		char sName[96];
		CEEaters_GetAttributeByPartIndex(i, sName, sizeof(sName));

		int iPartID = CE_GetAttributeInteger(entity, sName);
		if(iPartID > 0)
		{
			bool bFound = FindPartPrefab(iPartID, m_hParts[entity][i]);
			if (!bFound)continue;
		}
	}
}

public any Native_GetItemLevelData(Handle plugin, int numParams)
{
	int iIndex = GetNativeCell(1);
	KeyValues kv = CE_FindItemConfigByDefIndex(iIndex);
	if(!UTIL_IsValidHandle(kv)) return INVALID_HANDLE;

	char sName[128];
	kv.GetString("strange_level_data", sName, sizeof(sName));
	delete kv;

	KeyValues hConf = CEEaters_FindLevelDataByName(sName);

	KeyValues hReturn = view_as<KeyValues>(UTIL_ChangeHandleOwner(plugin, hConf));
	delete hConf;
	return hReturn;
}

public any Native_GetAttributeByPartIndex(Handle plugin, int numParams)
{
	int iPart = GetNativeCell(1);
	int iSize = GetNativeCell(3);

	char sName[96];
	if(iPart == 0) Format(sName, sizeof(sName), "strange eater");
	else Format(sName, sizeof(sName), "strange eater part %d", iPart);

	SetNativeString(2, sName, iSize);
}

public any Native_FindLevelDataByName(Handle plugin, int numParams)
{
	char sName[512];
	GetNativeString(1, sName, sizeof(sName));
	Format(sName, sizeof(sName), "Stranges/LevelData/%s", sName);

	KeyValues hConf = CE_GetEconomyConfig();
	KeyValues hLevelData;
	
	if(hConf.JumpToKey(sName, false))
	{
		hLevelData = KvSetRoot(hConf);
		delete hConf;

		KeyValues hReturn = view_as<KeyValues>(UTIL_ChangeHandleOwner(plugin, hLevelData));
		delete hLevelData;
		return hReturn;
	}

	delete hConf;
	return INVALID_HANDLE;
}


public void CEStranges_TickleStrangeParts(int client, int entity, CELogicEvents event, int add)
{
	for (int i = 0; i < MAX_STRANGE_PARTS; i++)
	{
		for (int j = 0; j < MAX_HOOKS; j++)
		{
			if (m_hParts[entity][i].m_nEvents[j] != event)continue;

			char sAttribute[96];
			CEEaters_GetAttributeByPartIndex(i, sAttribute, sizeof(sAttribute));
			Format(sAttribute, sizeof(sAttribute), "%s value", sAttribute);

			CE_SetAttributeInteger(entity, sAttribute, CE_GetAttributeInteger(entity, sAttribute) + add);

			CESC_SendStrangeEaterMessage(client, entity, i, add);
			break;
		}
	}
}

public void CESC_SendStrangeEaterMessage(int client, int iEntity, int part_id, int increment_value)
{
	int iIndex = CE_GetEntityEconIndex(iEntity);
	if (!IsClientReady(client) || iIndex <= 0)return;

	KeyValues hMessage = new KeyValues("content");

	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));

	hMessage.SetString("steamid", sSteamID);
	hMessage.SetNum("item", iIndex);
	hMessage.SetNum("part_id", part_id);
	hMessage.SetNum("increment_value", increment_value);

	CESC_SendMessage(hMessage, "strange_eater_increment");
	delete hMessage;
}
