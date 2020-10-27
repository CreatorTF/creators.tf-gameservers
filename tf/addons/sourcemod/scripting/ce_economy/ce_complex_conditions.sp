#pragma semicolon 1
#pragma newdecls required

#include <ce_core>
#include <ce_util>
#include <ce_complex_conditions>
#include <tf2_stocks>

bool g_CoreEnabled = false;

public Plugin myinfo =
{
	name = "Creators.TF Economy - Complex Conditioning System",
	author = "Creators.TF Team",
	description = "Creators.TF Economy Complex Conditioning System",
	version = "1.0",
	url = "https://creators.tf"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_complex_conditions");

	CreateNative("CECCS_ParseLogic", Native_ParseLogic);
	CreateNative("CECCS_VariablesKeyValuesToArrayList", Native_VariablesKeyValuesToArrayList);
	CreateNative("CECCS_GetEventName", Native_GetEventName);
	CreateNative("CECCS_GetEventInteger", Native_GetEventInteger);
	CreateNative("CECCS_FindLogicPrefabByName", Native_FindLogicPrefabByName);

	return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "ce_core"))g_CoreEnabled = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "ce_core"))g_CoreEnabled = false;
}

public any Native_ParseLogic(Handle plugin, int numParams)
{
	int iClient = GetNativeCell(1);
	KeyValues hLogic = GetNativeCell(2);
	Handle hEvent = GetNativeCell(3);
	ArrayList hVars = GetNativeCell(4);
	bool isKV = GetNativeCell(5);

	KeyValues hLogic2 = new KeyValues("Logic");
	hLogic2.Import(hLogic);

	ArrayList hVars2 = hVars.Clone();
	bool bResult = CheckLogicStep(iClient, hLogic, hEvent, 0, hVars2, isKV);
	
	delete hVars2;
	delete hLogic2;
	return bResult;
}

public any Native_GetEventName(Handle plugin, int numParams)
{
	Handle hEvent = GetNativeCell(1);
	int size = GetNativeCell(3);
	bool isKV = GetNativeCell(4);

	char[] sName = new char[size + 1];

	if(isKV)
	{
		KvGetSectionName(hEvent, sName, size);
	} else {
		GetEventName(hEvent, sName, size);
	}

	SetNativeString(2, sName, size);
}

public int Native_GetEventInteger(Handle plugin, int numParams)
{
	char sName[64];
	GetNativeString(2, sName, sizeof(sName));

	Handle hEvent = GetNativeCell(1);
	bool isKV = GetNativeCell(3);

	if(isKV)
	{
		return KvGetNum(hEvent, sName);
	} else {
		return GetEventInt(hEvent, sName);
	}
}

public any Native_FindLogicPrefabByName(Handle plugin, int numParams)
{
	char sName[256];
	GetNativeString(1, sName, sizeof(sName));
	
	KeyValues hConf = CE_GetEconomyConfig();
	KeyValues kv;
	
	Format(sName, sizeof(sName), "LogicPrefabs/%s", sName);
	
	if(hConf.JumpToKey(sName, false))
	{
		kv = new KeyValues("LogicPrefab");
		kv.Import(hConf);
	}	
	
	KeyValues hReturn = view_as<KeyValues>(UTIL_ChangeHandleOwner(plugin, kv));
	delete kv;
	delete hConf;
	return hReturn;
}

public any Native_VariablesKeyValuesToArrayList(Handle plugin, int numParams)
{
	KeyValues hVars = GetNativeCell(1);
	ArrayList hResult = new ArrayList(sizeof(CELogicVariable));

	if(hVars.GotoFirstSubKey(false))
	{
		do {
			CELogicVariable hVar;
			hVars.GetSectionName(hVar.m_sName, sizeof(hVar.m_sName));
			hVars.GetString(NULL_STRING, hVar.m_sValue, sizeof(hVar.m_sValue));

			hResult.PushArray(hVar);
		} while (hVars.GotoNextKey(false));
		hVars.GoBack();
	}

	KeyValues hReturn = view_as<KeyValues>(UTIL_ChangeHandleOwner(plugin, hResult));
	delete hResult;
	delete hVars;
	return hReturn;
}


public bool CheckLogicStep(int client, KeyValues logic, Handle hEvent, int depth, ArrayList hVars, bool isKV)
{
	// Don't do anything if core plugin is disabled.
	if (!g_CoreEnabled)return false;

	char sType[64];
	logic.GetString("type", sType, sizeof(sType), "AND");


	// Treat this as a group of comparition blocks.
	if(StrEqual(sType, "AND") || StrEqual(sType, "OR"))
	{
		bool bResponse;

		// By default AND is true, and OR is false.
		if (StrEqual(sType, "AND")) bResponse = true;
		if (StrEqual(sType, "OR")) bResponse = false;

		if(logic.JumpToKey("0", false))
		{
			do{
				bool bAccepted = CheckLogicStep(client, logic, hEvent, depth + 1, hVars, isKV);

				// If AND, all blocks should be true. So we immediately return false
				// if we encounter a false bResponse.
				if (StrEqual(sType, "AND") && !bAccepted){
					bResponse = false;
					break;
				}

				// If OR, only one block is needed to be true. So we return true
				// if we encounter a true bResponse.
				if (StrEqual(sType, "OR") && bAccepted){
					bResponse = true;
					break;
				}

			} while (logic.GotoNextKey());
			logic.GoBack();
		}
		return bResponse;
	} else {
		// This is comparition block.
		bool bResponse = false;

		/**
		* player_is_owner
		*
		* @param player_key Event key that contains client index.
		* @param get_by Method of retrieving the client index from event.
		*
		* @return True if client is owner of the event.
		*/

		if(StrEqual(sType,"player_is_owner"))
		{
			char player_key[32], get_by[32];
			logic.GetString("player_key", player_key, sizeof(player_key));
			logic.GetString("get_by", get_by, sizeof(get_by));

			int iClient;
			if (StrEqual(get_by, "by_userid"))
			{
				iClient = GetClientOfUserId(isKV ? KvGetNum(hEvent, player_key) : GetEventInt(hEvent, player_key));
			}

			if (StrEqual(get_by, "by_id"))
			{
				iClient = isKV ? KvGetNum(hEvent, player_key) : GetEventInt(hEvent, player_key);
			}

			if (StrEqual(get_by, "in_array"))
			{
				char cappers[512];
				if (isKV)KvGetString(hEvent, player_key, cappers, sizeof(cappers)); else GetEventString(hEvent, player_key, cappers, sizeof(cappers));

				int length = strlen(cappers);
				for (int i = 0; i < length; i++)
				{
					int capper = cappers[i];
					if (capper == client)iClient = capper;
				}
			}
			bResponse = iClient == client;
		}

		/**
		* bitwise_contains
		*
		* @param bit_key		Event key that contains bitfield integer.
		* @param value Value we find in the bitfield.
		*
		* @return True if value is in the bitfield.
		*/
		if(StrEqual(sType,"bitwise_contains"))
		{
			char bit_key[32];
			logic.GetString("bit_key", bit_key, sizeof(bit_key));
			int haystack = isKV ? KvGetNum(hEvent, bit_key) : GetEventInt(hEvent, bit_key);
			int needle = logic.GetNum("value");

			bResponse = view_as<bool>(haystack & needle);
		}

		/**
		* math_compare
		*
		* @param compare_key Event key that contains number that we compare;
		* @param sign Sign of comparation.
		* @param value Value we compare to.
		*
		* @return True if math statement is true.
		*/
		if(StrEqual(sType,"math_compare"))
		{
			char sKey[32];
			logic.GetString("compare_key", sKey, sizeof(sKey));
			char sSign[5];
			logic.GetString("sign", sSign, sizeof(sSign));
			float compare = logic.GetFloat("value");
			float value = isKV ? KvGetFloat(hEvent, sKey) : GetEventFloat(hEvent, sKey);

			if (StrEqual(sSign, "<"))bResponse = value < compare;
			if (StrEqual(sSign, "<="))bResponse = value <= compare;
			if (StrEqual(sSign, "="))bResponse = value == compare;
			if (StrEqual(sSign, ">="))bResponse = value >= compare;
			if (StrEqual(sSign, ">"))bResponse = value > compare;
		}

		/**
		*	math_compare
		*
		* 	@param gamerule					Gamerule prop that contains number that we compare.
		*	@param sign 					Sign of comparation.
		* 	@param value 					Value we compare to.
		*
		*	@return True if math statement is true.
		*/
		if (StrEqual(sType, "gamerule_compare"))
		{
			char sKey[32];
			logic.GetString("gamerule", sKey, sizeof(sKey));
			char sSign[5];
			logic.GetString("sign", sSign, sizeof(sSign));
			int compare = logic.GetNum("value");
			int value = GameRules_GetProp(sKey);

			if (StrEqual(sSign, "<"))bResponse = value < compare;
			if (StrEqual(sSign, "<="))bResponse = value <= compare;
			if (StrEqual(sSign, "="))bResponse = value == compare;
			if (StrEqual(sSign, ">="))bResponse = value >= compare;
			if (StrEqual(sSign, ">"))bResponse = value > compare;
		}

		/**
		* string_compare
		*
		* @param compare_key		Event key that contains string that we compare.
		* @param value 				Value we compare to.
		* @param *strict 			(Optional) Is comparation strict?
		*
		* @return True if comparation is true.
		*/
		if(StrEqual(sType,"string_compare"))
		{
			char compare_key[32], value[128], compare[128];
			logic.GetString("compare_key", compare_key, sizeof(compare_key));
			logic.GetString("value", value, sizeof(value));
			bool bStrict = logic.GetNum("strict", 0) == 1;

			ParseAllVariables(hVars, compare, sizeof(compare));

			if (isKV)KvGetString(hEvent, compare_key, compare, sizeof(compare)); else GetEventString(hEvent, compare_key, compare, sizeof(compare));

			if (bStrict)
			{
				bResponse = StrEqual(compare, value);
			} else {
				bResponse = StrContains(compare, value) != -1;
			}

		}

		/**
		* server_map
		*
		* @param map Map name we compare server map to.
		* @param *strict (Optional)Is comparation strict.
		*
		* @return True if comparation is true.
		*/
		if(StrEqual(sType,"server_map"))
		{
			char map[64], real_map[64];
			logic.GetString("map", map, sizeof(map));
			bool bStrict = logic.GetNum("strict", 0) == 1;
			GetCurrentMap(real_map, sizeof(real_map));

			ParseAllVariables(hVars, map, sizeof(map));

			if (bStrict)
			{
				bResponse = StrEqual(map, real_map);
			} else {
				bResponse = StrContains(real_map, map) != -1;
			}
		}

		/**
		* player_class
		*
		* @param player_key Event key that contains client index.
		* @param get_by Method of retrieving the client index from event.
		* @param class Class we compare player to.
		*
		* @return True if player is indeed playing that class.
		*/
		if(StrEqual(sType,"player_class"))
		{
			char player_key[32], get_by[32], class[32];
			logic.GetString("player_key", player_key, sizeof(player_key));
			logic.GetString("get_by", get_by, sizeof(get_by));
			logic.GetString("class", class, sizeof(class));

			ParseAllVariables(hVars, class, sizeof(class));

			int iClient;
			if (StrEqual(get_by, "by_userid"))iClient = GetClientOfUserId(isKV ? KvGetNum(hEvent, player_key) : GetEventInt(hEvent, player_key));
			if (StrEqual(get_by, "by_id"))iClient = isKV ? KvGetNum(hEvent, player_key) : GetEventInt(hEvent, player_key);
			if (StrEqual(get_by, "owner"))iClient = client;
			if (StrEqual(get_by, "in_array"))
			{
				char cappers[512];
				if (isKV)KvGetString(hEvent, player_key, cappers, sizeof(cappers)); else GetEventString(hEvent, player_key, cappers, sizeof(cappers));
				int len = strlen(cappers);
				for (int i = 0; i < len; i++)
				{
					int capper = cappers[i];
					if (capper == client)iClient = capper;
				}
			}

			if(IsClientValid(client))
			{
				bResponse = TF2_GetPlayerClass(iClient) == TF2_GetClass(class);
			} else bResponse = false;
		}

		/**
		* player_has_condition
		*
		* @param player_key		Event key that contains client index.
		* @param get_by Method of retrieving the client index from event.
		* @param condition Condition we check if player has.
		*
		* @return True if player has condition.
		*/
		if(StrEqual(sType,"player_has_condition"))
		{
			char player_key[32], get_by[32];
			logic.GetString("player_key", player_key, sizeof(player_key));
			logic.GetString("get_by", get_by, sizeof(get_by));
			int cond = logic.GetNum("condition");

			int iClient;
			if (StrEqual(get_by, "by_userid"))iClient = GetClientOfUserId(isKV ? KvGetNum(hEvent, player_key) : GetEventInt(hEvent, player_key));
			if (StrEqual(get_by, "by_id"))iClient = isKV ? KvGetNum(hEvent, player_key) : GetEventInt(hEvent, player_key);
			if (StrEqual(get_by, "owner"))iClient = client;

			if (IsClientValid(iClient))
			{
				bResponse = TF2_IsPlayerInCondition(iClient, view_as<TFCond>(cond));
			} else bResponse = false;
		}

		/**
		* player_flag
		*
		* @param player_key Event key that contains client index.
		* @param get_by Method of retrieving the client index from event.
		* @param flag Entity flag we see if player has.
		*
		* @return True if player has entity flag.
		*/
		if(StrEqual(sType,"player_flag"))
		{
			char player_key[32], get_by[32];
			logic.GetString("player_key", player_key, sizeof(player_key));
			logic.GetString("get_by", get_by, sizeof(get_by));
			int flag = logic.GetNum("flag");

			int iClient;
			if (StrEqual(get_by, "by_userid"))iClient = GetClientOfUserId(isKV ? KvGetNum(hEvent, player_key) : GetEventInt(hEvent, player_key));
			if (StrEqual(get_by, "by_id"))iClient = isKV ? KvGetNum(hEvent, player_key) : GetEventInt(hEvent, player_key);
			if (StrEqual(get_by, "owner"))iClient = client;

			if (IsClientValid(iClient))
			{
				bResponse = view_as<bool>(GetEntityFlags(iClient) & flag);
			} else bResponse = false;
		}

		/**
		* player_team_role
		*
		* @param player_key		Event key that contains client index.
		* @param get_by Method of retrieving the client index from event.
		* @param role Desired team's role index.
		*
		* @return True if player's team has role index.
		*/
		if (StrEqual(sType, "player_team_role"))
		{
			char player_key[32], get_by[32];
			logic.GetString("player_key", player_key, sizeof(player_key));
			logic.GetString("get_by", get_by, sizeof(get_by));
			int role = logic.GetNum("role");

			int iClient;
			if (StrEqual(get_by, "by_userid"))iClient = GetClientOfUserId(isKV ? KvGetNum(hEvent, player_key) : GetEventInt(hEvent, player_key));
			if (StrEqual(get_by, "by_id"))iClient = isKV ? KvGetNum(hEvent, player_key) : GetEventInt(hEvent, player_key);
			if (StrEqual(get_by, "owner"))iClient = client;

			int iTeam = GetClientTeam(iClient);
			int iEnt = -1;
			while ((iEnt = FindEntityByClassname(iEnt, "tf_team")) != -1)
			{
				int iT = GetEntProp(iEnt, Prop_Send, "m_iTeamNum");
				int iR = GetEntProp(iEnt, Prop_Send, "m_iRole");
				if(iT == iTeam && iR == role) {
					bResponse = true;
					break;
				}
			}
		}

		/**
		* owner_is_in_team
		*
		* @param team_key Event key that contains team index.
		*
		* @return True if owner is in the team.
		*/
		if (StrEqual(sType, "owner_is_in_team"))
		{
			char team_key[32];
			logic.GetString("team_key", team_key, sizeof(team_key));
			int iTeam = isKV ? KvGetNum(hEvent, team_key) : GetEventInt(hEvent, team_key);

			bResponse = GetClientTeam(client) == iTeam;
		}

		if(logic.GetNum("invert", 0) == 1)
		{
			bResponse = !bResponse;
		}
		return bResponse;
	}
}

public int ParseAllVariablesInteger(ArrayList hVars, char[] input, int size)
{
	if (!UTIL_IsValidHandle(hVars))
	{
		return StringToInt(input);
	}
	
	char[] buffer = new char[size + 1];
	strcopy(buffer, size, input);

	ParseAllVariables(hVars, buffer, size);

	return StringToInt(buffer);
}

public float ParseAllVariablesFloat(ArrayList hVars, char[] input, int size)
{
	if (!UTIL_IsValidHandle(hVars))
	{
		return StringToFloat(input);
	}
	
	char[] buffer = new char[size + 1];
	strcopy(buffer, size, input);

	ParseAllVariables(hVars, buffer, size);

	return StringToFloat(buffer);
}

public void ParseAllVariables(ArrayList hVars, char[] input, int size)
{
	char[] buffer = new char[size + 1];
	strcopy(buffer, size, input);

	// tf2.inc
	ReplaceString(buffer, size, "TF_STUNFLAG_SLOWDOWN", 		"1");
	ReplaceString(buffer, size, "TF_STUNFLAG_BONKSTUCK", 		"2");
	ReplaceString(buffer, size, "TF_STUNFLAG_LIMITMOVEMENT", 	"4");
	ReplaceString(buffer, size, "TF_STUNFLAG_CHEERSOUND", 		"8");
	ReplaceString(buffer, size, "TF_STUNFLAG_NOSOUNDOREFFECT",	"16");
	ReplaceString(buffer, size, "TF_STUNFLAG_THIRDPERSON", 		"32");
	ReplaceString(buffer, size, "TF_STUNFLAG_GHOSTEFFECT", 		"64");
	ReplaceString(buffer, size, "TF_STUNFLAG_SOUND", 			"128");

	ReplaceString(buffer, size, "TF_TEAM_UNASSIGNED", 			"0");
	ReplaceString(buffer, size, "TF_TEAM_SPECTATOR", 			"1");
	ReplaceString(buffer, size, "TF_TEAM_RED", 					"2");
	ReplaceString(buffer, size, "TF_TEAM_BLUE", 				"3");

	ReplaceString(buffer, size, "TF_CLASS_UNKNOWN", 			"0");
	ReplaceString(buffer, size, "TF_CLASS_SCOUT", 				"1");
	ReplaceString(buffer, size, "TF_CLASS_SNIPER", 				"2");
	ReplaceString(buffer, size, "TF_CLASS_SOLDIER", 			"3");
	ReplaceString(buffer, size, "TF_CLASS_DEMOMAN", 			"4");
	ReplaceString(buffer, size, "TF_CLASS_MEDIC", 				"5");
	ReplaceString(buffer, size, "TF_CLASS_HEAVY", 				"6");
	ReplaceString(buffer, size, "TF_CLASS_PYRO", 				"7");
	ReplaceString(buffer, size, "TF_CLASS_SPY", 				"8");
	ReplaceString(buffer, size, "TF_CLASS_ENGINEER", 			"9");


	if (UTIL_IsValidHandle(hVars))
	{
		for (int i = 0; i < hVars.Length; i++)
		{
			CELogicVariable hVar;
			hVars.GetArray(i, hVar);

			char search[32];
			Format(search, sizeof(search), "$%s", hVar.m_sName);

			ReplaceString(buffer, size, search, hVar.m_sValue);
		}
	}

	strcopy(input, size, buffer);
}
