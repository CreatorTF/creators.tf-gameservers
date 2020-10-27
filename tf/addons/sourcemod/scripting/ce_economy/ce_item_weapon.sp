#pragma semicolon 1

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "1.0"

#define TF_ATTRIB_HOLSTER_TIME "holster_anim_time"

#include <sdkhooks>
#include <ce_core>
#include <ce_util>
#include <ce_models>
#include <ce_manager_items>
#include <ce_item_weapon>
#include <tf_econ_data>
#include <tf2attributes>
#include <tf2>
#include <tf2_stocks>
#include <tf2items>

public Plugin myinfo =
{
	name = "Creators.TF Economy - Weapons Handler",
	author = PLUGIN_AUTHOR,
	description = "Creators.TF Economy Weapons Handler",
	version = PLUGIN_VERSION,
	url = "https://creators.tf"
}

ArrayList m_hWeaponMemory;
char m_sModel[MAX_ENTITY_LIMIT + 1][256];
int m_hLastWeapon[MAXPLAYERS + 1];

CEWeaponWearables m_hModels[MAX_ENTITY_LIMIT + 1];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_item_weapon");
	return APLRes_Success;
}

public void CE_OnSchemaUpdated(KeyValues hConf)
{
	ParseEconomySchema(hConf);
}

public void OnAllPluginsLoaded()
{
	KeyValues hSchema = CE_GetEconomyConfig();
	if(hSchema == INVALID_HANDLE) return;
	ParseEconomySchema(hSchema);
	delete hSchema;
}

public void ParseEconomySchema(KeyValues hConf)
{
	FlushMemoryList();
	if(hConf.JumpToKey("Items", false))
	{
		if(hConf.GotoFirstSubKey())
		{
			do {
				char sType[32];
				hConf.GetString("type", sType, sizeof(sType));
				if (!StrEqual(sType, "weapon"))continue;

				char sIndex[11];
				hConf.GetSectionName(sIndex, sizeof(sIndex));

				CEWeapon hWeapon;
				hWeapon.m_iIndex = StringToInt(sIndex);

				hConf.GetString("world_model", hWeapon.m_sModel, 256);
				hConf.GetString("item_class", hWeapon.m_sClassName, 64);

				hWeapon.m_iBaseIndex = hConf.GetNum("item_index");
				hWeapon.m_iClip = hConf.GetNum("weapon_clip");
				hWeapon.m_iAmmo = hConf.GetNum("weapon_ammo");

				AddWeaponToMemoryList(hWeapon);

			} while (hConf.GotoNextKey());
		}
	}
	hConf.Rewind();
}

public void OnPluginStart()
{
	LateHooking();
}

public void FlushMemoryList()
{
	delete m_hWeaponMemory;
}

public void AddWeaponToMemoryList(CEWeapon hWeapon)
{
	if (!UTIL_IsValidHandle(m_hWeaponMemory))m_hWeaponMemory = new ArrayList(sizeof(CEWeapon));
	m_hWeaponMemory.PushArray(hWeapon);
}

public void OnWeaponSwitch(int client, int weapon)
{
	if (m_hLastWeapon[client] == weapon)return; // Nothing has changed.

	ClearWeaponWearables(client, m_hLastWeapon[client]);

	m_hLastWeapon[client] = weapon;
	float flHolsterTime;

	// HACK: The only weapon that has "holster_anim_time" attribute is Thermal Thruster.
	// We can check the "m_flHolsterAnimTime" netprop of the player that is always >0 when we're
	// holstering the rocketpack. However I can't understand what defines its value.
	//
	// We need to find a way to detect exact amount of time needed for the animation to play, so that
	// this doesn't break when Valve push new weapons using that attrib. (Which is probably never lol, so we're fine for now.)
	//
	// P.S. Inb4 this doesn't age well.

	if(GetEntPropFloat(client, Prop_Send, "m_flHolsterAnimTime") > 0)
	{
		// HACK: Sets the holster time to 0.8 as that's the time rocketpack uses to holster.
		flHolsterTime = 0.8;
	}

	if(CE_IsEntityCustomEcomItem(weapon))
	{
		DataPack hPack = new DataPack();
		hPack.WriteCell(client);
		hPack.WriteCell(weapon);
		hPack.Reset();

		if(flHolsterTime == 0.0)
		{
			RequestFrame(RF_OnWeaponDraw, hPack);
		} else {
			CreateTimer(flHolsterTime, Timer_OnWeaponDraw, hPack);
		}
	}
}

public Action Timer_OnWeaponDraw(Handle timer, DataPack hPack)
{
	RequestFrame(RF_OnWeaponDraw, hPack);
}

public void RF_OnWeaponDraw(DataPack hPack)
{
	int client = hPack.ReadCell();
	int weapon = hPack.ReadCell();
	hPack.Reset();
	delete hPack;

	OnDrawWeapon(client, weapon);
}

public bool ShouldDrawWeaponWorldModel(int client, int weapon)
{
	if (!ShouldDrawWeaponModel(client, weapon))return false;
	return true;
}

public bool ShouldDrawWeaponViewModel(int client, int weapon)
{
	if(IsFakeClient(client))return false;
	if (!ShouldDrawWeaponModel(client, weapon))return false;
	return true;
}

public bool ShouldDrawWeaponModel(int client, int weapon)
{
	if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") != weapon)return false;
	if (StrEqual(m_sModel[weapon], ""))return false;
	return true;
}

public void ClearWeaponWearables(int client, int weapon)
{
	if (!IsValidEntity(weapon))return;

	if(UTIL_IsEntityValid(m_hModels[weapon].m_hWorldModel))
	{
		char sNetClass[128];
		GetEntityNetClass(m_hModels[weapon].m_hWorldModel, sNetClass, sizeof(sNetClass));
		if(StrEqual(sNetClass, "CTFWearable"))
		{
			TF2_RemoveWearable(client, m_hModels[weapon].m_hWorldModel);
			AcceptEntityInput(m_hModels[weapon].m_hWorldModel, "Kill");
		}	
	}

	if(UTIL_IsEntityValid(m_hModels[weapon].m_hViewModel))
	{
		char sNetClass[128];
		GetEntityNetClass(m_hModels[weapon].m_hViewModel, sNetClass, sizeof(sNetClass));
		if(StrEqual(sNetClass, "CTFWearableVM"))
		{
			TF2_RemoveWearable(client, m_hModels[weapon].m_hViewModel);
			AcceptEntityInput(m_hModels[weapon].m_hViewModel, "Kill");
		}
	}
}

public void OnDrawWeapon(int client, int iWeapon)
{
	ClearWeaponWearables(client, iWeapon);
	if(ShouldDrawWeaponModel(client, iWeapon))
	{
		SetEntityRenderMode(iWeapon, RENDER_TRANSALPHA);
		SetEntityRenderColor(iWeapon, 0, 0, 0, 0);

		SetEntProp(iWeapon, Prop_Send, "m_bBeingRepurposedForTaunt", 1);

		if(ShouldDrawWeaponWorldModel(client, iWeapon))
		{
			m_hModels[iWeapon].m_hWorldModel = CEModels_CreateTiedWearable(client, m_sModel[iWeapon], false, iWeapon);
		}

		if(ShouldDrawWeaponViewModel(client, iWeapon))
		{
			m_hModels[iWeapon].m_hViewModel = CEModels_CreateTiedWearable(client, m_sModel[iWeapon], true, iWeapon);
		}
	}
}

public int CE_OnItemEquip(int client, int item_index, int index, int quality, ArrayList hAttributes, char[] type)
{
	if (!StrEqual(type, "weapon")) return -1;

	CEWeapon hWeapon;
	bool bFound = FindWeaponPrefab(index, hWeapon);
	if (!bFound) return -1;

	if(StrEqual(hWeapon.m_sClassName, "tf_wearable"))
	{

	} else {
		int iWeapon = CreateWeapon(client, hWeapon.m_iBaseIndex, hWeapon.m_sClassName, quality);
		if(iWeapon > -1)
		{
			int item_slot = TF2Econ_GetItemSlot(hWeapon.m_iBaseIndex, TF2_GetPlayerClass(client));

			// Hardcode revolvers to 0th slot.
			if(StrEqual(hWeapon.m_sClassName, "tf_weapon_revolver"))
			{
				item_slot = 0;
			}
			// Hardcode the sappers to 1th slot.
			if(StrEqual(hWeapon.m_sClassName, "tf_weapon_sapper"))
			{
				SetEntProp(iWeapon, Prop_Send, "m_iObjectType", 3, 4, 0);
				SetEntProp(iWeapon, Prop_Data, "m_iSubType", 3, 4, 0);
				item_slot = 1;
			}

			// Hardcode the PDAs to 3th slot.
			if(StrEqual(hWeapon.m_sClassName, "tf_weapon_pda_engineer_build"))
			{
				item_slot = 3;
			}

			// Hardcode the PDAs to 3th slot.
			if(StrEqual(hWeapon.m_sClassName, "tf_weapon_pda_engineer_build"))
			{
				item_slot = 3;
			}

			// Removing all wearables that take up the same slot as this weapon.
			int iEdict;
			while((iEdict = FindEntityByClassname(iEdict, "tf_wearable*")) != -1)
			{
				if (iEdict == iWeapon)continue;

				char sClass[32];
				GetEntityNetClass(iEdict, sClass, sizeof(sClass));
				if (!StrEqual(sClass, "CTFWearable"))continue;

				if (GetEntPropEnt(iEdict, Prop_Send, "m_hOwnerEntity") != client) continue;

				int idx = GetEntProp(iEdict, Prop_Send, "m_iItemDefinitionIndex");
				int iSlot = TF2Econ_GetItemSlot(idx, TF2_GetPlayerClass(client));
				if (iSlot == item_slot)
				{
					TF2_RemoveWearable(client, iEdict);
					AcceptEntityInput(iEdict, "Kill");
				}
			}

			if(hWeapon.m_iClip > 0)
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", hWeapon.m_iClip);
			}

			if(hWeapon.m_iAmmo > 0)
			{
				SetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + (item_slot == 0 ? 4 : 8), hWeapon.m_iAmmo);
			}

			strcopy(m_sModel[iWeapon], sizeof(m_sModel[]), hWeapon.m_sModel);

			// Making weapon visible.
			SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", 1);

			TF2_RemoveWeaponSlot(client, item_slot);
			EquipPlayerWeapon(client, iWeapon);
			OnDrawWeapon(client, iWeapon);

			return iWeapon;
		}
	}
	return -1;
}

public int CreateWeapon(int client, int index, const char[] classname, int quality)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);

	char class[128];
	strcopy(class, sizeof(class), classname);

	if (TF2_GetPlayerClass(client) == TFClass_Unknown)return 0;

	if(StrEqual(class, "tf_weapon_saxxy"))
	{
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: Format(class, sizeof(class), "tf_weapon_bat");
			case TFClass_Sniper: Format(class, sizeof(class), "tf_weapon_club");
			case TFClass_Soldier: Format(class, sizeof(class), "tf_weapon_shovel");
			case TFClass_DemoMan: Format(class, sizeof(class), "tf_weapon_bottle");
			case TFClass_Medic: Format(class, sizeof(class), "tf_weapon_bonesaw");
			case TFClass_Spy: Format(class, sizeof(class), "tf_weapon_knife");
			case TFClass_Engineer: Format(class, sizeof(class), "tf_weapon_wrench");
			case TFClass_Pyro: Format(class, sizeof(class), "tf_weapon_fireaxe");
			case TFClass_Heavy: Format(class, sizeof(class), "tf_weapon_fireaxe");
		}
	}else if(StrEqual(class, "tf_weapon_shotgun"))
	{
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Soldier: Format(class, sizeof(class), "tf_weapon_shotgun_soldier");
			case TFClass_Engineer: Format(class, sizeof(class), "tf_weapon_shotgun_primary");
			case TFClass_Pyro: Format(class, sizeof(class), "tf_weapon_shotgun_pyro");
			case TFClass_Heavy: Format(class, sizeof(class), "tf_weapon_shotgun_hwg");
		}
	}else if(StrEqual(class, "tf_weapon_pistol"))
	{
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: Format(class, sizeof(class), "tf_weapon_pistol_scout");
			case TFClass_Engineer: Format(class, sizeof(class), "tf_weapon_pistol");
		}
	}

	TF2Items_SetClassname(hWeapon, class);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetQuality(hWeapon, quality);

	int iWep = TF2Items_GiveNamedItem(client, hWeapon);
	delete hWeapon;
	SetEntProp(iWep, Prop_Send, "m_iEntityLevel", -1);

	return iWep;
}

public void OnWeaponDropped(int weapon)
{
	if(IsValidEntity(weapon) && GetEntProp(weapon, Prop_Send, "m_iEntityLevel") == -1)
	{
		AcceptEntityInput(weapon, "Kill");
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1)return;
	strcopy(m_sModel[entity], PLATFORM_MAX_PATH, "");

	if (StrEqual(classname, "tf_dropped_weapon"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnWeaponDropped);
	}

	if(StrEqual(classname, "player"))
	{
		SDKHook(entity, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
	}
}

public void LateHooking()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			SDKHook(i, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	if (entity < 1)return;
	strcopy(m_sModel[entity], PLATFORM_MAX_PATH, "");
}

public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	if (cond == TFCond_Taunting)
	{
		for (int i = 0; i < 5; i++)
		{
			int iWeapon = GetPlayerWeaponSlot(client, i);
			if (!IsValidEntity(iWeapon))continue;
			if (!CE_IsEntityCustomEcomItem(iWeapon))continue;

			OnDrawWeapon(client, iWeapon);
		}
	}
}

public bool FindWeaponPrefab(int index, CEWeapon hWeapon)
{
	if (!UTIL_IsValidHandle(m_hWeaponMemory))return false;
	for (int i = 0; i < m_hWeaponMemory.Length; i++)
	{
		CEWeapon wep;
		m_hWeaponMemory.GetArray(i, wep);
		if(wep.m_iIndex == index)
		{
			hWeapon = wep;
			return true;
		}
	}
	return false;
}
