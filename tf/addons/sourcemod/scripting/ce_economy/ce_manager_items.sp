#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#include <ce_core>
#include <ce_util>
#include <ce_manager_items>
#include <ce_manager_attributes>
#include <tf2_stocks>
#include <tf2>

public Plugin myinfo =
{
	name = "Creators.TF Economy - Items Manager",
	author = "Creators.TF Team",
	description = "Creators.TF Economy - Items Manager",
	version = "1.0",
	url = "https://creators.tf"
}

Handle g_hOnShouldEquip, g_hOnItemEquip, g_hOnPostEquip;

bool m_bIsCustomEconItem[MAX_ENTITY_LIMIT + 1];
int m_iEconIndex[MAX_ENTITY_LIMIT + 1];
int m_iEconDefIndex[MAX_ENTITY_LIMIT + 1];
int m_iEconQuality[MAX_ENTITY_LIMIT + 1];

public void OnPluginStart()
{
	g_hOnShouldEquip = CreateGlobalForward("CE_OnShouldBlock", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_hOnItemEquip = CreateGlobalForward("CE_OnItemEquip", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_hOnPostEquip = CreateGlobalForward("CE_OnPostEquip", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_manager_items");

	CreateNative("CE_FindItemIndexByItemName", Native_FindItemIndexByItemName);
	CreateNative("CE_FindItemConfigByDefIndex", Native_FindItemConfigByDefIndex);
	CreateNative("CE_FindItemConfigByItemName", Native_FindItemConfigByItemName);
	CreateNative("CE_ParseEquipRegionString", Native_ParseEquipRegionString);
	CreateNative("CE_EquipItem", Native_EquipItem);

	CreateNative("CE_IsEntityCustomEcomItem", Native_IsEntityCustomEcomItem);

	CreateNative("CE_GetEntityEconIndex", Native_GetEntityEconIndex);
	CreateNative("CE_GetEntityEconDefinitionIndex", Native_GetEntityEconDefinitionIndex);
	CreateNative("CE_GetEntityEconQuality", Native_GetEntityEconQuality);
}

public any Native_EquipItem(Handle plugin, int numParams)
{
	int iClient = GetNativeCell(1);
	int iIndex = GetNativeCell(2);
	int iDefID = GetNativeCell(3);
	int iQuality = GetNativeCell(4);
	ArrayList hOverlayAttributes = GetNativeCell(5);

	KeyValues hConf = CE_FindItemConfigByDefIndex(iDefID);
	if (!UTIL_IsValidHandle(hConf))return false;

	bool bResult = false;

	char sType[32];
	hConf.GetString("type", sType, sizeof(sType));
	
	ArrayList hBaseAttributes;
	if(hConf.JumpToKey("attributes"))
	{
		hBaseAttributes = CE_KeyValuesToAttributesArray(hConf);
	}
	delete hConf;

	ArrayList hAttributes = CE_MergeAttributes(hBaseAttributes, hOverlayAttributes);

	Call_StartForward(g_hOnShouldEquip);
	Call_PushCell(iClient);
	Call_PushCell(iIndex);
	Call_PushCell(iDefID);
	Call_PushCell(iQuality);
	Call_PushCell(hAttributes);
	Call_PushString(sType);
	
	bool bShouldBlock = false;
	
	Call_Finish(bShouldBlock);

	// If noone responded or response is positive, equip this item.
	if (GetForwardFunctionCount(g_hOnShouldEquip) == 0 || !bShouldBlock)
	{
		// Equipping this item on client.
		Call_StartForward(g_hOnItemEquip);
		Call_PushCell(iClient);
		Call_PushCell(iIndex);
		Call_PushCell(iDefID);
		Call_PushCell(iQuality);
		Call_PushCell(hAttributes);
		Call_PushString(sType);
		int iEntity = -1;
		Call_Finish(iEntity);

		if(UTIL_IsEntityValid(iEntity))
		{
			m_bIsCustomEconItem[iEntity] = true;
			m_iEconIndex[iEntity] = iIndex;
			m_iEconDefIndex[iEntity] = iDefID;
			m_iEconQuality[iEntity] = iQuality;

			CE_SetEntityAttributes(iEntity, hAttributes);
			CE_ApplyOriginalAttributes(iEntity, hAttributes);
		}
		// Alerting subplugins that this item was equipped.
		Call_StartForward(g_hOnPostEquip);
		Call_PushCell(iClient);
		Call_PushCell(iEntity);
		Call_PushCell(iIndex);
		Call_PushCell(iDefID);
		Call_PushCell(iQuality);
		Call_PushCell(hAttributes);
		Call_PushString(sType);
		Call_Finish();

		bResult = true;
	}
	delete hBaseAttributes;
	delete hAttributes;

	return bResult;
}

public void OnEntityCreated(int entity)
{
	ClearEntityInfo(entity);
}

public void OnEntityDestroyed(int entity)
{
	ClearEntityInfo(entity);
}

public void ClearEntityInfo(int entity)
{
	if (entity < 0 || entity > MAX_ENTITY_LIMIT)return;

	m_iEconIndex[entity] = 0;
	m_iEconDefIndex[entity] = 0;
	m_iEconQuality[entity] = 0;
	m_bIsCustomEconItem[entity] = false;
}

/**
*	Native: CE_FindItemConfigByDefIndex
*	Purpose: Returns item config by its definition index.
*/
public any Native_FindItemConfigByDefIndex(Handle plugin, int numParams)
{
	int iIndex = GetNativeCell(1);
	KeyValues kv = CE_GetEconomyConfig();
	KeyValues hItem;

	char sKey[32];
	Format(sKey, sizeof(sKey), "Items/%d", iIndex);
	if(kv.JumpToKey(sKey, false))
	{
		hItem = new KeyValues("Item");
		hItem.Import(kv);
	}

	delete kv;
	KeyValues hReturn = view_as<KeyValues>(UTIL_ChangeHandleOwner(plugin, hItem));
	delete hItem;
	return hReturn;
}

/**
*	Native: CE_FindItemConfigByDefIndex
*	Purpose: Returns item config by its definition index.
*/
public any Native_FindItemIndexByItemName(Handle plugin, int numParams)
{
	char sName[128];
	GetNativeString(1, sName, sizeof(sName));

	KeyValues kv = CE_GetEconomyConfig();

	if(kv.JumpToKey("Items", false))
	{
		if(kv.GotoFirstSubKey())
		{
			do {
				char sName2[128];
				kv.GetString("name", sName2, sizeof(sName2));

				if(StrEqual(sName, sName2))
				{
					char sIndex[11];
					kv.GetSectionName(sIndex, sizeof(sIndex));
					delete kv;
					
					return StringToInt(sIndex);
				}
			} while (kv.GotoNextKey());
		}
	}
	delete kv;
	return -1;
}

public any Native_FindItemConfigByItemName(Handle plugin, int numParams)
{
	char sName[128];
	GetNativeString(1, sName, sizeof(sName));

	KeyValues kv = CE_GetEconomyConfig();
	KeyValues hItem;

	if(kv.JumpToKey("Items", false))
	{
		if(kv.GotoFirstSubKey())
		{
			do {
				char sName2[128];
				kv.GetString("name", sName2, sizeof(sName2));

				if(StrEqual(sName, sName2))
				{
					hItem = new KeyValues("Item");
					hItem.Import(kv);
					break;
				}
			} while (kv.GotoNextKey());
		}
	}

	delete kv;
	KeyValues hReturn = view_as<KeyValues>(UTIL_ChangeHandleOwner(plugin, hItem));
	delete hItem;
	return hReturn;
}

public int Native_GetEntityEconIndex(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	return m_iEconIndex[iEntity];
}

public int Native_GetEntityEconDefinitionIndex(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	return m_iEconDefIndex[iEntity];
}

public int Native_GetEntityEconQuality(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	return m_iEconQuality[iEntity];
}

public any Native_IsEntityCustomEcomItem(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	return m_bIsCustomEconItem[iEntity];
}

public int Native_ParseEquipRegionString(Handle plugin, int numParams)
{
	char string[256];
	GetNativeString(1, string, 256);

	int bits;
	if (StrContains(string, "whole_head") != -1)bits |= TFEquip_WholeHead | TFEquip_Hat | TFEquip_Face | TFEquip_Glasses;
	if (StrContains(string, "hat") != -1)bits |= TFEquip_Hat;
	if (StrContains(string, "face") != -1)bits |= TFEquip_Face;
	if (StrContains(string, "glasses") != -1)bits |= TFEquip_Glasses | TFEquip_Face | TFEquip_Lenses;
	if (StrContains(string, "lenses") != -1)bits |= TFEquip_Lenses;
	if (StrContains(string, "pants") != -1)bits |= TFEquip_Pants;
	if (StrContains(string, "beard") != -1)bits |= TFEquip_Beard;
	if (StrContains(string, "shirt") != -1)bits |= TFEquip_Shirt;
	if (StrContains(string, "medal") != -1)bits |= TFEquip_Medal;
	if (StrContains(string, "arms") != -1)bits |= TFEquip_Arms;
	if (StrContains(string, "back") != -1)bits |= TFEquip_Back;
	if (StrContains(string, "feet") != -1)bits |= TFEquip_Feet;
	if (StrContains(string, "necklace") != -1)bits |= TFEquip_Necklace;
	if (StrContains(string, "grenades") != -1)bits |= TFEquip_Grenades;
	if (StrContains(string, "arm_tatoos") != -1)bits |= TFEquip_ArmTatoos;
	if (StrContains(string, "flair") != -1)bits |= TFEquip_Flair;
	if (StrContains(string, "head_skin") != -1)bits |= TFEquip_HeadSkin;
	if (StrContains(string, "ears") != -1)bits |= TFEquip_Ears;
	if (StrContains(string, "left_shoulder") != -1)bits |= TFEquip_LeftShoulder;
	if (StrContains(string, "belt_misc") != -1)bits |= TFEquip_BeltMisc;
	if (StrContains(string, "disconnected_floating_item") != -1)bits |= TFEquip_Floating;
	if (StrContains(string, "zombie_body") != -1)bits |= TFEquip_Zombie;
	if (StrContains(string, "sleeves") != -1)bits |= TFEquip_Sleeves;
	if (StrContains(string, "right_shoulder") != -1)bits |= TFEquip_RightShoulder;

	if (StrContains(string, "pyro_spikes") != -1)bits |= TFEquip_PyroSpikes;
	if (StrContains(string, "scout_bandages") != -1)bits |= TFEquip_ScoutBandages;
	if (StrContains(string, "engineer_pocket") != -1)bits |= TFEquip_EngineerPocket;
	if (StrContains(string, "heavy_belt_back") != -1)bits |= TFEquip_HeavyBeltBack;
	if (StrContains(string, "demo_eyepatch") != -1)bits |= TFEquip_DemoEyePatch;
	if (StrContains(string, "soldier_gloves") != -1)bits |= TFEquip_SoldierGloves;
	if (StrContains(string, "spy_gloves") != -1)bits |= TFEquip_SpyGloves;
	if (StrContains(string, "sniper_headband") != -1)bits |= TFEquip_SniperHeadband;

	if (StrContains(string, "scout_backpack") != -1)bits |= TFEquip_ScoutBack;
	if (StrContains(string, "heavy_pocket") != -1)bits |= TFEquip_HeavyPocket;
	if (StrContains(string, "engineer_belt") != -1)bits |= TFEquip_EngineerBelt;
	if (StrContains(string, "soldier_pocket") != -1)bits |= TFEquip_SoldierPocket;
	if (StrContains(string, "demo_belt") != -1)bits |= TFEquip_DemoBelt;
	if (StrContains(string, "sniper_quiver") != -1)bits |= TFEquip_SniperQuiver;

	if (StrContains(string, "pyro_wings") != -1)bits |= TFEquip_PyroWings;
	if (StrContains(string, "sniper_bullets") != -1)bits |= TFEquip_SniperBullets;
	if (StrContains(string, "medigun_accessories") != -1)bits |= TFEquip_MediAccessories;
	if (StrContains(string, "soldier_coat") != -1)bits |= TFEquip_SoldierCoat;
	if (StrContains(string, "heavy_hip") != -1)bits |= TFEquip_HeavyHip;
	if (StrContains(string, "scout_hands") != -1)bits |= TFEquip_ScoutHands;

	if (StrContains(string, "engineer_left_arm") != -1)bits |= TFEquip_EngineerLeftArm;
	if (StrContains(string, "pyro_tail") != -1)bits |= TFEquip_PyroTail;
	if (StrContains(string, "sniper_legs") != -1)bits |= TFEquip_SniperLegs;
	if (StrContains(string, "medic_gloves") != -1)bits |= TFEquip_MedicGloves;
	if (StrContains(string, "soldier_cigar") != -1)bits |= TFEquip_SoldierCigar;
	if (StrContains(string, "demoman_collar") != -1)bits |= TFEquip_DemomanCollar;
	if (StrContains(string, "heavy_towel") != -1)bits |= TFEquip_HeavyTowel;

	if (StrContains(string, "engineer_wings") != -1)bits |= TFEquip_EngineerWings;
	if (StrContains(string, "pyro_head_replacement") != -1)bits |= TFEquip_PyroHead;
	if (StrContains(string, "scout_wings") != -1)bits |= TFEquip_ScoutWings;
	if (StrContains(string, "heavy_hair") != -1)bits |= TFEquip_HeavyHair;
	if (StrContains(string, "medic_pipe") != -1)bits |= TFEquip_MedicPipe;
	if (StrContains(string, "soldier_legs") != -1)bits |= TFEquip_SoldierLegs;

	if (StrContains(string, "scout_pants") != -1)bits |= TFEquip_ScoutPants;
	if (StrContains(string, "heavy_bullets") != -1)bits |= TFEquip_HeavyBullets;
	if (StrContains(string, "engineer_hair") != -1)bits |= TFEquip_EngineerHair;
	if (StrContains(string, "sniper_vest") != -1)bits |= TFEquip_SniperVest;
	if (StrContains(string, "medigun_backpack") != -1)bits |= TFEquip_MedigunBackpack;
	if (StrContains(string, "sniper_pocket_left") != -1)bits |= TFEquip_SniperPocketLeft;

	if (StrContains(string, "sniper_pocket") != -1)bits |= TFEquip_SniperPocket;
	if (StrContains(string, "heavy_hip_pouch") != -1)bits |= TFEquip_HeavyHipPouch;
	if (StrContains(string, "spy_coat") != -1)bits |= TFEquip_SpyCoat;
	if (StrContains(string, "medic_hip") != -1)bits |= TFEquip_MedicHip;
	return bits;
}
