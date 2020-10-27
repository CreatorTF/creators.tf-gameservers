#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <ce_util>

public Plugin myinfo =
{
	name = "Creators.TF Economy",
	author = "Creators.TF Team",
	description = "Creators.TF UTIL Stocks",
	version = "1.0",
	url = "https://creators.tf"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_util");

	CreateNative("UTIL_ChangeHandleOwner", Native_ChangeHandleOwner);
	CreateNative("UTIL_IsValidHandle", Native_IsValidHandle);
	CreateNative("UTIL_IsEntityValid", Native_IsEntityValid);
	
	CreateNative("MAX", Native_MAX);
	CreateNative("MIN", Native_MIN);
	CreateNative("TimeFromString", Native_TimeFromString);

	CreateNative("FindTargetBySteamID", Native_FindTargetBySteamID);
	CreateNative("IsClientReady", Native_IsClientReady);
	CreateNative("IsClientValid", Native_IsClientValid);
	CreateNative("KvSetRoot", Native_KvSetRoot);
	CreateNative("KvSubKeyCount", Native_KvSubKeyCount);
	
	return APLRes_Success;
}

public any Native_ChangeHandleOwner(Handle plugin, int numParams)
{
	Handle owner = GetNativeCell(1);
	Handle handle = GetNativeCell(2);
	
	if(!UTIL_IsValidHandle(handle)) return INVALID_HANDLE;

	Handle hResult = CloneHandle(handle, owner);
	
	return hResult;
}

public any Native_IsValidHandle(Handle plugin, int numParams)
{
	Handle hHandle = GetNativeCell(1);
	return hHandle != null && hHandle != INVALID_HANDLE;
}

public int Native_MAX(Handle plugin, int numParams)
{
	int iNum1 = GetNativeCell(1);
	int iNum2 = GetNativeCell(2);
	
	if (iNum1 > iNum2)return iNum1;
	if (iNum2 > iNum1)return iNum2;
	return iNum1;
}

public int Native_MIN(Handle plugin, int numParams)
{
	int iNum1 = GetNativeCell(1);
	int iNum2 = GetNativeCell(2);
	
	if (iNum1 < iNum2)return iNum1;
	if (iNum2 < iNum1)return iNum2;
	return iNum1;
}

/**
*	Native: FindTargetBySteamID
*	Purpose: Find a client with provided SteamID.
*/
public any Native_FindTargetBySteamID(Handle plugin, int numParams)
{
	char steamid[256];
	GetNativeString(1, steamid, 256);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientAuthorized(i))
		{
			char szAuth[256];
			GetClientAuthId(i, AuthId_SteamID64, szAuth, sizeof(szAuth));
			if (StrEqual(szAuth, steamid))return i;
		}
	}
	return -1;
}

/**
*	Native: IsClientReady
*	Purpose: Check if player is valid and ready for Economy intergation.
*/
public any Native_IsClientReady(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	if (IsFakeClient(client))return false;
	return true;
}

/**
*	Native: KvSetRoot
*	Purpose: Check if player is valid and ready for Economy intergation.
*/
public any Native_KvSetRoot(Handle plugin, int numParams)
{
	KeyValues kv = GetNativeCell(1);
	if (!UTIL_IsValidHandle(kv))return kv;
	
	char sName[PLATFORM_MAX_PATH];
	kv.GetSectionName(sName, sizeof(sName));
	
	KeyValues kv2 = new KeyValues(sName);
	kv2.Import(kv);
	
	KeyValues hResult = view_as<KeyValues>(UTIL_ChangeHandleOwner(plugin, kv2));
	delete kv2;
	
	return hResult;
}

/**
*	Native: KvSetRoot
*	Purpose: Check if player is valid and ready for Economy intergation.
*/
public int Native_KvSubKeyCount(Handle plugin, int numParams)
{
	KeyValues kv = GetNativeCell(1);
	if (!UTIL_IsValidHandle(kv))return 0;
	
	KeyValues kv1 = new KeyValues("KeyValues");
	kv1.Import(kv);
	
	int count = 0;
	if(kv1.GotoFirstSubKey(false))
	{
		do {
			count++;
		} while (kv1.GotoNextKey(false));
	}
	
	delete kv1;
	return count;
}

/**
*	Native: IsClientValid
*	Purpose: Check if player is valid.
*/
public any Native_IsClientValid(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (!IsClientAuthorized(client))return false;
	return true;
}

/**
*	Native: UTIL_IsEntityValid
*	Purpose: Check if entity is valid.
*/
public any Native_IsEntityValid(Handle plugin, int numParams)
{
	int iEntity = GetNativeCell(1);
	return iEntity > 0 && iEntity < MAX_ENTITY_LIMIT && IsValidEntity(iEntity);
}

// Logic is taken from CRTime::RTime32FromFmtString method. 

public any Native_TimeFromString(Handle plugin, int numParams)
{
	enum tm
	{
		m_iYear,
		m_iMon,
		m_iDay,
		m_iHour,
		m_iMin,
		m_iSec
	}
	
	int time[tm];
	
	char sValue[64];
	char sFormat[64];
	
	GetNativeString(1, sFormat, sizeof(sFormat));
	GetNativeString(2, sValue, sizeof(sValue));
	
	int iFormatLen = strlen(sFormat);
	int iValueLen = strlen(sValue);
	if(iFormatLen != iValueLen || iFormatLen < 4)
	{
		LogError("Format size should be bigger than 4 symbols.");
		return -1;
	}
	
	int iPosYYYY = StrContains(sFormat, "YYYY");
	int iPosYY = StrContains(sFormat, "YY");
	int iPosMM = StrContains(sFormat, "MM");
	int iPosMnt = StrContains(sFormat, "Mnt");
	int iPosDD = StrContains(sFormat, "DD");
	int iPosThh = StrContains(sFormat, "hh");
	int iPosTmm = StrContains(sFormat, "mm");
	int iPosTss = StrContains(sFormat, "ss");
		
	if(iPosYYYY > -1)
	{
		char sYYYY[5];
		strcopy(sYYYY, sizeof(sYYYY), sValue[iPosYYYY]);
		time[m_iYear] = StringToInt(sYYYY) - 1900;
		
	} else if(iPosYY > -1) 
	{
		
		char sYY[3];
		strcopy(sYY, sizeof(sYY), sValue[iPosYY]);
		time[m_iYear] = StringToInt(sYY) + 100;
		
	} else {
		
		return -1; // Must have a year.
	}
	
	time[m_iYear] -= 70; // Substracting this, so we have 1970 as the base year.
	
	if(iPosMM > -1)
	{
		char sMM[3];
		strcopy(sMM, sizeof(sMM), sValue[iPosMM]);
		time[m_iMon] = StringToInt(sMM) - 1;
	}
	
	if(iPosMnt > -1)
	{
		char sMonthNames[][] =  { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
		
		char sMnt[4];
		strcopy(sMnt, sizeof(sMnt), sValue[iPosMnt]);
		
		int i;
		for (i = 0; i < 12; i++)
		{
			if (StrEqual(sMonthNames[i], sMnt))break;
		}
		
		if(i < 12) 
		{
			time[m_iMon] = i;
		}
	}
	
	if(iPosDD > -1)
	{
		char sDD[3];
		strcopy(sDD, sizeof(sDD), sValue[iPosDD]);
		time[m_iDay] = StringToInt(sDD);
	}
	
	if(iPosThh > -1)
	{
		char sHH[3];
		strcopy(sHH, sizeof(sHH), sValue[iPosThh]);
		time[m_iHour] = StringToInt(sHH);
	}
	
	if(iPosTmm > -1)
	{
		char sMM[3];
		strcopy(sMM, sizeof(sMM), sValue[iPosTmm]);
		time[m_iMin] = StringToInt(sMM);
	}
	
	if(iPosTss > -1)
	{
		char sSS[3];
		strcopy(sSS, sizeof(sSS), sValue[iPosTss]);
		time[m_iSec] = StringToInt(sSS);
	}
	
	int iTime = 0;
	iTime += YearToDays(time[m_iYear]) * 24 * 60 * 60;
	iTime += MonthToDays(time[m_iMon]) * 24 * 60 * 60;
	iTime += time[m_iDay] * 24 * 60 * 60;
	iTime += time[m_iHour] * 60 * 60;
	iTime += time[m_iMin] * 60;
	iTime += time[m_iSec];
	
	return iTime;
}

public int YearToDays(int year)
{
	int iDays = year * 365;
	iDays += RoundToFloor(float(year - 2) / 4.0) + 1; // Every 4 years we have 366 days.
	return iDays;
}

public int MonthToDays(int month)
{
	int iDays = 0;
	for (int i = 0; i < month; i++)
	{
		if (i == 1)iDays += 28; // February has 28 days.
		else if (i & 2 == 0)iDays += 31;
		else iDays += 30;
	}
	return iDays;
}