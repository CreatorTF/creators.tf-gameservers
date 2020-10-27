#pragma semicolon 1

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "1.0"

#include <sdkhooks>
#include <ce_core>
#include <ce_manager_attributes>
#include <tf2_stocks>

public Plugin myinfo =
{
	name = "[CE Attribute] holiday restricted",
	author = PLUGIN_AUTHOR,
	description = "holiday restricted",
	version = PLUGIN_VERSION,
	url = "https://creators.tf"
}

enum CEHoliday
{
	CEHoliday_Invalid,
	CEHoliday_Birthday,
	CEHoliday_Halloween,
	CEHoliday_HalloweenOrFullMoon
}

public bool CE_OnShouldBlock(int client, int index, int def, int quality, ArrayList hAttributes, const char[] type)
{
	if (!StrEqual(type, "cosmetic"))return false;
	
	
	for (int i = 0; i < hAttributes.Length; i++)
	{
		// TODO: Make this a native to check an attr in ArrayList.
		CEAttribute hAttr;
		hAttributes.GetArray(i, hAttr);
		
		if(StrEqual(hAttr.m_sName, "holiday restricted"))
		{	
			CEHoliday nHoliday = view_as<CEHoliday>(hAttr.m_hValue);
			switch(nHoliday)
			{
				case CEHoliday_Halloween:
				{
					return !TF2_IsHolidayActive(TFHoliday_Halloween); 
				}
				case CEHoliday_HalloweenOrFullMoon:
				{
					return !TF2_IsHolidayActive(TFHoliday_HalloweenOrFullMoon); 
				}
			}
		}
	}
	return false;
}