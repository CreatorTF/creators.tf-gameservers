#pragma semicolon 1

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "1.0"

#include <sdkhooks>
#include <ce_core>
#include <ce_manager_attributes>
#include <tf2_stocks>

public Plugin myinfo =
{
	name = "[CE Attribute] allowed in medieval mode",
	author = PLUGIN_AUTHOR,
	description = "allowed in medieval mode",
	version = PLUGIN_VERSION,
	url = "https://creators.tf"
}

public bool CE_OnShouldBlock(int client, int index, int def, int quality, ArrayList hAttributes, const char[] type)
{
	if (!StrEqual(type, "weapon"))return false;
	
	if(GameRules_GetProp("m_bPlayingMedieval") == 1)
	{
		for (int i = 0; i < hAttributes.Length; i++)
		{
			// TODO: Make this a native to check an attr in ArrayList.
			CEAttribute hAttr;
			hAttributes.GetArray(i, hAttr);
			
			if(StrEqual(hAttr.m_sName, "allowed in medieval mode"))
			{
				if(view_as<int>(hAttr.m_hValue) > 0)
				{
					return false;
				}
			}
		}
		return true;
	}
	return false;
}