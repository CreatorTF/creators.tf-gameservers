#pragma semicolon 1
#pragma newdecls required

#include <ce_core>
#include <ce_util>
#include <ce_manager_attributes>
#include <tf2attributes>

public Plugin myinfo =
{
	name = "Creators.TF Economy - Attributes Manager",
	author = "Creators.TF Team",
	description = "Creators.TF Economy - Attributes Manager",
	version = "1.0",
	url = "https://creators.tf"
}

ArrayList m_hAttributes[MAX_ENTITY_LIMIT + 1];
ArrayList m_hMemory;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_manager_attributes");

	CreateNative("CE_ClearEntityAttributes", Native_ClearEntityAttributes);
	CreateNative("CE_SetEntityAttributes", Native_SetEntityAttributes);
	CreateNative("CE_KeyValuesToAttributesArray", Native_KeyValuesToAttributesArray);

	CreateNative("CE_MergeAttributes", Native_MergeAttributes);
	CreateNative("CE_ApplyOriginalAttributes", Native_ApplyOriginalAttributes);

	CreateNative("CE_GetAttributeInteger", Native_GetEntityAttribute_Integer);
	CreateNative("CE_GetAttributeFloat", Native_GetEntityAttribute_Float);
	CreateNative("CE_SetAttributeInteger", Native_SetEntityAttribute_Integer);
	CreateNative("CE_SetAttributeFloat", Native_SetEntityAttribute_Float);
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

	if(hConf.JumpToKey("Attributes", false))
	{
		if(hConf.GotoFirstSubKey())
		{
			do {
				CEAttribute hAttr;

				char sType[11];
				hConf.GetString("type", sType, 11, "integer");

				hAttr.m_bOriginal = hConf.GetNum("original", 0) == 1;

				if (StrEqual(sType, "integer"))
				{
					hAttr.m_nType = Type_Integer;
				} else if (StrEqual(sType, "float"))
				{
					hAttr.m_nType = Type_Float;
				} else if (StrEqual(sType, "boolean"))
				{
					hAttr.m_nType = Type_Boolean;
				} else if (StrEqual(sType, "string"))
				{
					hAttr.m_nType = Type_String;
				}

				hConf.GetSectionName(hAttr.m_sName, MAX_ATTRIBUTE_NAME_LENGTH);
				hConf.GetString("sub_attribute", hAttr.m_sSubAttribute, MAX_ATTRIBUTE_NAME_LENGTH, "");
				AddAttributeToMemoryList(hAttr);

			} while (hConf.GotoNextKey());
		}
	}
	hConf.Rewind();
}

public void FlushMemoryList()
{
	delete m_hMemory;
}

public void AddAttributeToMemoryList(CEAttribute hAttr)
{
	if (!UTIL_IsValidHandle(m_hMemory))m_hMemory = new ArrayList(sizeof(CEAttribute));
	m_hMemory.PushArray(hAttr);
}

public bool FindAttributePrefab(const char[] name, CEAttribute hAttr)
{
	if (!UTIL_IsValidHandle(m_hMemory))return false;
	for (int i = 0; i < m_hMemory.Length; i++)
	{
		CEAttribute attr;
		m_hMemory.GetArray(i, attr);

		if(StrEqual(attr.m_sName, name))
		{
			hAttr = attr;
			return true;
		}
	}
	return false;
}

public any Native_ClearEntityAttributes(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);

	delete m_hAttributes[iEntity];
}

public any Native_SetEntityAttributes(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	if (!IsValidEntity(iEntity))return;

	CE_ClearEntityAttributes(iEntity);

	ArrayList hAttrs = GetNativeCell(2);
	m_hAttributes[iEntity] = hAttrs.Clone();
}

public any Native_KeyValuesToAttributesArray(Handle plugin, int numParams)
{
	KeyValues kv = GetNativeCell(1);
	ArrayList hArray = new ArrayList(sizeof(CEAttribute));

	KeyValues hConf = new KeyValues("Attributes");
	hConf.Import(kv);

	if (hConf.GotoFirstSubKey())
	{
		do {
			char sName[MAX_ATTRIBUTE_NAME_LENGTH];
			hConf.GetString("name", sName, sizeof(sName), "");

			CEAttribute hAttr;
			bool bFound = FindAttributePrefab(sName, hAttr);
			if (!bFound)continue;

			switch(hAttr.m_nType)
			{
				case Type_Integer:hAttr.m_hValue = hConf.GetNum("value", 0);
				case Type_Float:hAttr.m_hValue = hConf.GetFloat("value", 0.0);
				case Type_Boolean:hAttr.m_hValue = hConf.GetNum("value", 0) == 1;
			}
			hConf.GetString("value", hAttr.m_sValue, MAX_ATTRIBUTE_VALUE_LENGTH, "");
			hArray.PushArray(hAttr);

		} while (hConf.GotoNextKey());
	}

	delete hConf;

	ArrayList hReturn = view_as<ArrayList>(UTIL_ChangeHandleOwner(plugin, hArray));
	delete hArray;
	return hReturn;
}


/**
*	Native: CE_MergeAttributes
*	Purpose: Merges two ArrayLists of attributes into one.
*/
public any Native_MergeAttributes(Handle plugin, int numParams)
{
	ArrayList hStaticAttrs = GetNativeCell(1);
	ArrayList hOverlapAttrs = GetNativeCell(2);

	if(!UTIL_IsValidHandle(hStaticAttrs) && !UTIL_IsValidHandle(hOverlapAttrs))
	{
		// If no attributes provided at all, we return an empty array.
		ArrayList hArray = new ArrayList(sizeof(CEAttribute));
		ArrayList hReturn = view_as<ArrayList>(UTIL_ChangeHandleOwner(plugin, hArray));
		delete hArray;
		return hReturn;

	} else if(!UTIL_IsValidHandle(hStaticAttrs))
	{
		// If static attributes are not provided, we return overlay attributes.
		ArrayList hArray = hOverlapAttrs.Clone();
		ArrayList hReturn = view_as<ArrayList>(UTIL_ChangeHandleOwner(plugin, hArray));
		delete hArray;
		return hReturn;

	} else if(!UTIL_IsValidHandle(hOverlapAttrs))
	{
		// If overlay attributes are not provided, we return static attributes.
		ArrayList hArray = hStaticAttrs.Clone();
		ArrayList hReturn = view_as<ArrayList>(UTIL_ChangeHandleOwner(plugin, hArray));
		delete hArray;
		return hReturn;

	}

	ArrayList hArray = hStaticAttrs.Clone();

	int size = hArray.Length;
	for (int i = 0; i < hOverlapAttrs.Length; i++)
	{
		CEAttribute newAttr;
		hOverlapAttrs.GetArray(i, newAttr);
		for (int j = 0; j < size; j++)
		{
			CEAttribute oldAttr;
			hArray.GetArray(j, oldAttr);
			if (StrEqual(oldAttr.m_sName, newAttr.m_sName))
			{
				hArray.Erase(j);
				j--;
				size--;
			}
		}
		hArray.PushArray(newAttr);
	}

	ArrayList hReturn = view_as<ArrayList>(UTIL_ChangeHandleOwner(plugin, hArray));
	delete hArray;
	return hReturn;
}

public any Native_ApplyOriginalAttributes(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	ArrayList hAttributes = GetNativeCell(2);

	for (int i = 0; i < hAttributes.Length; i++)
	{
		CEAttribute attr;
		hAttributes.GetArray(i, attr);

		if (attr.m_bOriginal)
		{
			if (StrEqual(attr.m_sSubAttribute, ""))
			{
				switch(attr.m_nType)
				{
					case Type_Integer: TF2Attrib_SetByName(iEntity, attr.m_sName, float(attr.m_hValue));
					case Type_Float: TF2Attrib_SetByName(iEntity, attr.m_sName, attr.m_hValue);
					case Type_Boolean: TF2Attrib_SetByName(iEntity, attr.m_sName, attr.m_hValue ? 1.0 : 0.0);
					case Type_String: TF2Attrib_SetByName(iEntity, attr.m_sName, StringToFloat(attr.m_sValue));
				}
			} else
			{
				switch(attr.m_nType) {
					case Type_Integer: TF2Attrib_SetByName(iEntity, attr.m_sSubAttribute, float(attr.m_hValue));
					case Type_Float: TF2Attrib_SetByName(iEntity, attr.m_sSubAttribute, attr.m_hValue);
					case Type_Boolean: TF2Attrib_SetByName(iEntity, attr.m_sSubAttribute, attr.m_hValue ? 1.0 : 0.0);
					case Type_String: TF2Attrib_SetByName(iEntity, attr.m_sSubAttribute, StringToFloat(attr.m_sValue));
				}
			}
		}
	}
}

public any Native_GetEntityAttribute_Integer(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	char sAttr[MAX_ATTRIBUTE_NAME_LENGTH];
	GetNativeString(2, sAttr, sizeof(sAttr));

	if (!UTIL_IsEntityValid(iEntity))return 0;
	if (!UTIL_IsValidHandle(m_hAttributes[iEntity]))return 0;


	for (int i = 0; i < m_hAttributes[iEntity].Length; i++)
	{
		CEAttribute attr;
		m_hAttributes[iEntity].GetArray(i, attr);

		if (StrEqual(sAttr, attr.m_sName))
		{
			switch(attr.m_nType)
			{
				case Type_Integer:return attr.m_hValue;
				case Type_Float:return RoundToFloor(attr.m_hValue);
				case Type_Boolean:return attr.m_hValue ? 1 : 0;
				case Type_String:return StringToInt(attr.m_sValue);
			}
		}
	}
	return 0;
}

public any Native_GetEntityAttribute_Float(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	char sAttr[MAX_ATTRIBUTE_NAME_LENGTH];
	GetNativeString(2, sAttr, sizeof(sAttr));

	if (!UTIL_IsEntityValid(iEntity))return 0.0;
	if (!UTIL_IsValidHandle(m_hAttributes[iEntity]))return 0.0;

	for (int i = 0; i < m_hAttributes[iEntity].Length; i++)
	{
		CEAttribute attr;
		m_hAttributes[iEntity].GetArray(i, attr);
		if (StrEqual(sAttr, attr.m_sName))
		{
			switch(attr.m_nType)
			{
				case Type_Float:return attr.m_hValue;
				case Type_Integer:return float(attr.m_hValue);
				case Type_Boolean:return attr.m_hValue ? 1.0 : 0.0;
				case Type_String:return StringToFloat(attr.m_sValue);
			}
		}
	}
	return 0.0;
}

public any Native_SetEntityAttribute_Integer(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	char sAttr[128];
	GetNativeString(2, sAttr, 128);
	int iValue = GetNativeCell(3);

	if (!UTIL_IsEntityValid(iEntity))return;

	KeyValues kv = new KeyValues("Attributes");
	kv.SetString("0/name", sAttr);
	kv.SetNum("0/value", iValue);

	ArrayList hNewAttrs = CE_KeyValuesToAttributesArray(kv);
	delete kv;

	ArrayList hAttrs = CE_MergeAttributes(m_hAttributes[iEntity], hNewAttrs);
	CE_ApplyOriginalAttributes(iEntity, hNewAttrs);
	CE_SetEntityAttributes(iEntity, hAttrs);

	delete hNewAttrs;
	delete hAttrs;
	return;
}


public any Native_SetEntityAttribute_Float(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	char sAttr[128];
	GetNativeString(2, sAttr, 128);
	float flValue = GetNativeCell(3);

	if (!UTIL_IsEntityValid(iEntity))return;

	KeyValues kv = new KeyValues("attributes");
	kv.SetString("0/name", sAttr);
	kv.SetFloat("0/value", flValue);

	ArrayList hNewAttrs = CE_KeyValuesToAttributesArray(kv);
	delete kv;

	ArrayList hAttrs = CE_MergeAttributes(m_hAttributes[iEntity], hNewAttrs);
	CE_ApplyOriginalAttributes(iEntity, hNewAttrs);
	CE_SetEntityAttributes(iEntity, hAttrs);

	delete hNewAttrs;
	delete hAttrs;
	return;
}

public void OnEntityCreated(int entity)
{
	if (entity <= 0)return;
	FlushEntityData(entity);
}

public void OnEntityDestroyed(int entity)
{
	if (entity <= 0)return;
	FlushEntityData(entity);
}

public void FlushEntityData(int entity)
{
	CE_ClearEntityAttributes(entity);
}
