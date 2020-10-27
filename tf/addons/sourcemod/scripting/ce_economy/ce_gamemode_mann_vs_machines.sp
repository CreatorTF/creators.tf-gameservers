#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "1.00"

#include <sdktools>
#include <ce_util>
#include <ce_core>
#include <ce_manager_items>
#include <ce_manager_attributes>

#define Q_UNIQUE 6

public Plugin myinfo =
{
	name = "Creators.TF - Mann vs Machines",
	author = PLUGIN_AUTHOR,
	description = "Creators.TF - Mann vs Machines",
	version = PLUGIN_VERSION,
	url = "https://creators.tf"
};

ConVar ce_mvm_check_itemname_cvar;

public void OnPluginStart()
{
	RegServerCmd("ce_mvm_equip_itemname", cMvMEquipItemName, "");
	RegServerCmd("ce_mvm_get_itemdef_id", cMvMGetItemDefID, "");
	RegServerCmd("ce_mvm_set_attribute", cMvMSetEntityAttribute, "");
	ce_mvm_check_itemname_cvar = CreateConVar("ce_mvm_check_itemname_cvar", "-1", "", FCVAR_PROTECTED);
}

public bool TF2MvM_IsPlayingMvM()
{
	return (GameRules_GetProp("m_bPlayingMannVsMachine") != 0);
}

/**
*	Purpose: 	ce_mvm_equip_itemname command.
*/
public Action cMvMEquipItemName(int args)
{
	char sArg1[11], sArg2[128];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	int iClient = StringToInt(sArg1);
	
	if (!StrEqual(sArg2, "")) 
	{
		KeyValues hConf = CE_FindItemConfigByItemName(sArg2);
		if(UTIL_IsValidHandle(hConf))
		{
			if(IsClientValid(iClient)) 
			{
				ArrayList hAttribs = new ArrayList(sizeof(CEAttribute));
				
				int iIndex = hConf.GetNum("index");
				CE_EquipItem(iClient, -1, iIndex, Q_UNIQUE, hAttribs);
				delete hAttribs;
			}
			delete hConf;
			return Plugin_Handled;
		}
	}
	
	
	return Plugin_Handled;
}

/**
*	Purpose: 	ce_mvm_get_itemdef_id command.
*/
public Action cMvMGetItemDefID(int args)
{
	char sArg1[128];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	
	if (!StrEqual(sArg1, "")) 
	{
		KeyValues hConf = CE_FindItemConfigByItemName(sArg1);
		if(hConf != null)
		{
			ce_mvm_check_itemname_cvar.SetInt(hConf.GetNum("item_index", -1));
			return Plugin_Handled;
		}
	}
	ce_mvm_check_itemname_cvar.SetInt(-1);
	
	
	return Plugin_Handled;
}

/**
*	Purpose: 	ce_mvm_set_attribute command.
*/
public Action cMvMSetEntityAttribute(int args)
{	
	char sName[128], sEntity[11], sValue[11];
	GetCmdArg(1, sEntity, sizeof(sEntity));
	int iEntity = StringToInt(sEntity);
	if (!IsValidEntity(iEntity))return Plugin_Handled;
	
	GetCmdArg(2, sName, sizeof(sName));
	GetCmdArg(3, sValue, sizeof(sValue));
	float flValue = StringToFloat(sValue);
	
	CE_SetAttributeFloat(iEntity, sName, flValue);
	
	return Plugin_Handled;
}