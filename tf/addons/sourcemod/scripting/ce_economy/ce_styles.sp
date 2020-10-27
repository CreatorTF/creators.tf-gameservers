#pragma semicolon 1
#pragma newdecls required

#include <ce_manager_items>
#include <ce_styles>
#include <ce_util>
#include <tf2_stocks>
#include <tf2attributes>

public Plugin myinfo =
{
	name = "Creators.TF Economy - Styles Handler",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Styles Handler",
	version = "1.00",
	url = "https://creators.tf"
};

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_styles");
   	CreateNative("CEStyles_SetStyle", Native_SetStyle);
   	return APLRes_Success;
}

public void CE_OnPostEquip(int client, int entity, int index, int defid, int quality, ArrayList hAttributes, const char[] type)
{
}

public any Native_SetStyle(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	int style = GetNativeCell(2);

	CEStyles_ApplyStyle(entity, style);
}

public void CEStyles_ApplyStyle(int entity, int style)
{
	int iDefID = CE_GetEntityEconDefinitionIndex(entity);

	KeyValues hConf = CE_FindItemConfigByDefIndex(iDefID);
	if (!UTIL_IsValidHandle(hConf))return;

	char sPath[32];
	Format(sPath, sizeof(sPath), "visuals/styles/%d", style);

	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	if(hConf.JumpToKey(sPath, false))
	{
		int iNative = hConf.GetNum("model_style", -1);
		if (iNative > -1)
		{
			TF2Attrib_SetByName(entity, "item style override", float(iNative));
		}

		char sModel[128];
		hConf.GetString("world_model", sModel, sizeof(sModel), "");
		if(!StrEqual(sModel, ""))
		{
			switch (TF2_GetPlayerClass(client))
			{
				case TFClass_Scout:ReplaceString(sModel, 256, "%s", "scout");
				case TFClass_Soldier:ReplaceString(sModel, 256, "%s", "soldier");
				case TFClass_Pyro:ReplaceString(sModel, 256, "%s", "pyro");
				case TFClass_DemoMan:ReplaceString(sModel, 256, "%s", "demo");
				case TFClass_Heavy:ReplaceString(sModel, 256, "%s", "heavy");
				case TFClass_Engineer:ReplaceString(sModel, 256, "%s", "engineer");
				case TFClass_Medic:ReplaceString(sModel, 256, "%s", "medic");
				case TFClass_Sniper:ReplaceString(sModel, 256, "%s", "sniper");
				case TFClass_Spy:ReplaceString(sModel, 256, "%s", "spy");
			}
			SetEntProp(entity, Prop_Send, "m_nModelIndex", PrecacheModel(sModel, false));
		}
	}
	delete hConf;
}

public void RF_Pog(int entity)
{
	
}