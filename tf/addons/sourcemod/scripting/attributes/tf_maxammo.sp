#pragma semicolon 1
#pragma newdecls required

#include <ce_core>
#include <tf2attributes>
#include <tf_econ_data>
#include <ce_manager_attributes>

public Plugin myinfo =
{
	name = "[CE Attribute] weapon maxammo",
	author = "Creators.TF Team",
	description = "weapon maxammo",
	version = "1.00",
	url = "https://creators.tf"
};

public void CE_OnPostEquip(int client, int entity, int index, int defid, int quality, ArrayList hAttributes, char[] type)
{
	if(IsValidEntity(entity) && HasEntProp(entity, Prop_Send, "m_iItemDefinitionIndex"))
	{
		int idx = GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
		int iSlot = TF2Econ_GetItemSlot(idx, TF2_GetPlayerClass(client));
		if(iSlot > -1)
		{
			float flBonus = CE_GetAttributeFloat(entity, "weapon maxammo bonus");
			if(flBonus > 0.0)
			{
				switch(iSlot)
				{
					case 0: TF2Attrib_SetByName(entity, "maxammo primary increased", flBonus);
					case 1: TF2Attrib_SetByName(entity, "maxammo secondary increased", flBonus);
				}

			}

			float flPenalty = CE_GetAttributeFloat(entity, "weapon maxammo penalty");
			if(flPenalty > 0.0)
			{
				switch(iSlot)
				{
					case 0: TF2Attrib_SetByName(entity, "maxammo primary reduced", flPenalty);
					case 1: TF2Attrib_SetByName(entity, "maxammo secondary reduced", flPenalty);
				}
			}
		}
	}
}
