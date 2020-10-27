#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "0.01"

#include <ce_util>
#include <ce_models>
#include <ce_manager_items>
#include <tf_econ_data>

#define MAX_COSMETICS 4 // 3 cosmetic slots + 1 action slot.

int m_iMyWearables[MAXPLAYERS + 1][MAX_COSMETICS];
int m_iTFWearables[MAXPLAYERS + 1][MAX_COSMETICS];

public Plugin myinfo =
{
	name = "Creators.TF Economy - Cosmetics Handler",
	author = PLUGIN_AUTHOR,
	description = "Creators.TF Economy Cosmetics Handler",
	version = PLUGIN_VERSION,
	url = "https://creators.tf"
};

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_item_cosmetic");
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("post_inventory_application", post_inventory_application);
}

public Action post_inventory_application(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	int iTFWearables[MAX_COSMETICS];
	
	for (int i = 0; i < MAX_COSMETICS; i++)
	{
		m_iMyWearables[client][i] = -1;
	}
	
	int iCount = 0;
	int iEdict = -1;
	while((iEdict = FindEntityByClassname(iEdict, "tf_wearable*")) != -1)
	{
		char sClass[32];
		GetEntityNetClass(iEdict, sClass, sizeof(sClass));
		if (!StrEqual(sClass, "CTFWearable") && !StrEqual(sClass, "CTFWearableCampaignItem"))continue;

		if (GetEntPropEnt(iEdict, Prop_Send, "m_hOwnerEntity") != client)continue;
		int idx = GetEntProp(iEdict, Prop_Send, "m_iItemDefinitionIndex");
		
		// Check if index is valid.
		if(idx < 0xFFFF)
		{
			iTFWearables[iCount] = idx;
			m_iMyWearables[client][iCount] = iEdict;
			iCount++;
		}
		if (iCount == MAX_COSMETICS)break;
	}
	
	bool bChanged = false;
	int iSizeA, iSizeB;
	
	// We need to identify whether the TF cosmetic list has changed.
	
	// First we see if cosmetics' amount has changed from previous one.
	for (int i = 0; i < MAX_COSMETICS; i++)if (iTFWearables[i] > 0)iSizeA++;
	for (int i = 0; i < MAX_COSMETICS; i++)if (m_iTFWearables[client][i] > 0)iSizeB++;
	// If it did, clearly something has changed.
	if (iSizeA != iSizeB)bChanged = true;
	
	
	// Otherwise, check if every single new cosmetic is in the old cosmetic list.
	if(!bChanged)
	{
		bool bFound = false;
		for (int i = 0; i < MAX_COSMETICS; i++)
		{
			if (iTFWearables[i] <= 0)continue;
			for (int j = 0; j< MAX_COSMETICS; j++)
			{
				if (m_iTFWearables[client][i] <= 0)continue;
				if(iTFWearables[i] == m_iTFWearables[client][i])
				{
					bFound = true;
					break;
				}
			}
		}
		if (!bFound)bChanged = true;
	}
	
	// Do the same thing vice versa.
	if(!bChanged)
	{
		bool bFound = false;
		for (int i = 0; i < MAX_COSMETICS; i++)
		{
			if (m_iTFWearables[client][i] <= 0)continue;
			for (int j = 0; j< MAX_COSMETICS; j++)
			{
				if (iTFWearables[i] <= 0)continue;
				if(iTFWearables[i] == m_iTFWearables[client][i])
				{
					bFound = true;
					break;
				}
			}
		}
		if (!bFound)bChanged = true;
	}
	
	if(bChanged)
	{
		for (int i = 0; i < MAX_COSMETICS; i++)
		{
			m_iTFWearables[client][i] = iTFWearables[i];
		}
	}
}

public int CE_OnItemEquip(int client, int item_index, int index, int quality, ArrayList hAttributes, char[] type)
{
	if (!StrEqual(type, "cosmetic"))return -1;
	
	KeyValues hConf = CE_FindItemConfigByDefIndex(index);
	if (!UTIL_IsValidHandle(hConf)) return -1;

	char sEquipRegion[256];
	hConf.GetString("equip_region", sEquipRegion, sizeof(sEquipRegion));

	int iBits = CE_ParseEquipRegionString(sEquipRegion);

	if(HasOverlappingWeapons(client, iBits))
	{
		delete hConf;
		return -1;
	}

	int iItemIndex = hConf.GetNum("item_index", 0);
	char sModel[256];
	hConf.GetString("world_model", sModel, sizeof(sModel));
	delete hConf;

	ParseCosmeticModel(client, sModel, sizeof(sModel));
	
	int iWearIndex = -1;
	for (int i = 0; i < MAX_COSMETICS; i++)
	{
		int iWearable = m_iMyWearables[client][i];
		if (!IsValidEntity(iWearable))continue;
		if (CE_IsEntityCustomEcomItem(iWearable))continue;
		if (!HasEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex"))continue;
		
		// First we check if we have any TF cosmetics 
		// that have same equip regions. And remove them if needed.
		int iDefIndex = GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex");
		int iCompareBits = TF2Econ_GetItemEquipRegionGroupBits(iDefIndex);
		if (iBits & iCompareBits != 0)
		{
			// We found a merging TF cosmetic.
			TF2_RemoveWearable(client, iWearable);
			AcceptEntityInput(iWearable, "Kill");
			
			if(iWearIndex == -1)
			{
				iWearIndex = i;
			}
		}
	}
	
	if(iWearIndex == -1)
	{
		for (int i = 0; i < MAX_COSMETICS; i++)
		{
			int iWearable = m_iMyWearables[client][i];
			if (IsValidEntity(iWearable))continue;
			
			// We've found an empty slot. Let's use it.
			iWearIndex = i;
			break;
		}
	}
	
	if(iWearIndex == -1)
	{
		bool bFound;
		
		for (int i = 0; i < MAX_COSMETICS; i++)
		{
			int iDefIndex = m_iTFWearables[client][i];
			for (int j = 0; j < MAX_COSMETICS; j++)
			{
				int iWearable = m_iMyWearables[client][j];
				if (!IsValidEntity(iWearable))continue;
				if (CE_IsEntityCustomEcomItem(iWearable))continue;
				if (!HasEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex"))continue;
				
				if(iDefIndex == GetEntProp(iWearable, Prop_Send, "m_iItemDefinitionIndex"))
				{
					int iSlotCandidate = TF2Econ_GetItemSlot(iDefIndex, TF2_GetPlayerClass(client));
					int iSlotReplacement = TF2Econ_GetItemSlot(iItemIndex, TF2_GetPlayerClass(client));
					if (iSlotCandidate != iSlotReplacement)continue;
					
					TF2_RemoveWearable(client, iWearable);
					AcceptEntityInput(iWearable, "Kill");
					
					iWearIndex = j;
					
					bFound = true;
					break;
				}
			}
			if (bFound)break;
		}
	}
	
	if(iWearIndex > -1)
	{
		int iWear = CEModels_CreateWearable(client, sModel, false, quality);
		SetEntProp(iWear, Prop_Send, "m_iItemDefinitionIndex", iItemIndex);
		m_iMyWearables[client][iWearIndex] = iWear;
		
		return iWear;
	}
	return -1;
}

public bool HasOverlappingWeapons(int client, int bits)
{
	for (int i = 0; i < 5; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, i);
		if(iWeapon != -1)
		{
			int idx = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
			int iCompareBits = TF2Econ_GetItemEquipRegionGroupBits(idx);
			if (bits & iCompareBits != 0)return true;
		}
	}
	return false;
}

public void ParseCosmeticModel(int client, char[] sModel, int size)
{
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:ReplaceString(sModel, size, "%s", "scout");
		case TFClass_Soldier:ReplaceString(sModel, size, "%s", "soldier");
		case TFClass_Pyro:ReplaceString(sModel, size, "%s", "pyro");
		case TFClass_DemoMan:ReplaceString(sModel, size, "%s", "demo");
		case TFClass_Heavy:ReplaceString(sModel, size, "%s", "heavy");
		case TFClass_Engineer:ReplaceString(sModel, size, "%s", "engineer");
		case TFClass_Medic:ReplaceString(sModel, size, "%s", "medic");
		case TFClass_Sniper:ReplaceString(sModel, size, "%s", "sniper");
		case TFClass_Spy:ReplaceString(sModel, size, "%s", "spy");
	}
}