#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "1.00"

#include <sdkhooks>
#include <tf2_stocks>
#include <ce_manager_attributes>
#include <ce_core>
#include <ce_util>
#include <ce_models>

#define HEAL_SOUND "creators/weapons/syringe_heal.wav"
#define HEAL_READY "player/recharged.wav"
#define HEAL_READY_VO "vo/medic_mvm_say_ready01.mp3"
#define HEAL_DONE_VO "vo/medic_specialcompleted07.mp3"
#define MEDIGUN_CLASSNAME "tf_weapon_medigun"
#define DEFAULT_OVERHEAL 1.5
#define HUD_RATE 0.5

#define CHAR_FULL "■"
#define CHAR_EMPTY "□"
#define SYRINGE_HEALING_CAP 15

public Plugin myinfo =
{
	name = "[CE Attribute] syringe blood mod",
	author = PLUGIN_AUTHOR,
	description = "syringe blood mod",
	version = PLUGIN_VERSION,
	url = "https://creators.tf"
};

int m_iBlood[MAXPLAYERS + 1];
int m_iCap[MAXPLAYERS + 1];
int m_iLastValue[MAXPLAYERS + 1];

bool m_bReady[MAXPLAYERS + 1];
bool m_bChecked[MAXPLAYERS + 1];

public Action evPlayerDeath(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	m_iBlood[client] = 0;
	m_bReady[client] = false;
	m_bChecked[client] = false;
	m_iLastValue[client] = GetEntProp(client, Prop_Send, "m_iHealPoints");

	return Plugin_Continue;
}

public Action evPlayerSpawn(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	m_bReady[client] = false;
	m_bChecked[client] = false;
	m_iLastValue[client] = GetEntProp(client, Prop_Send, "m_iHealPoints");

	return Plugin_Continue;
}

public Action evRoundStart(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		m_iBlood[i] = 0;
		if(IsClientInGame(i))
		{
			m_iLastValue[i] = GetEntProp(i, Prop_Send, "m_iHealPoints");
			for (int j = 0; j < 5; j++)
			{
				int iWeapon = GetPlayerWeaponSlot(i, j);
				if(IsValidEntity(iWeapon) && CE_GetAttributeInteger(iWeapon, "syringe blood mode") > 0)
				{
					CEModels_WearSetEntPropFloatOfWeapon(iWeapon, Prop_Send, "m_flPoseParameter", 0.0);
				}
			}
		}
	}
	return Plugin_Continue;
}

public void OnMapStart()
{
	PrecacheSound(HEAL_SOUND);
	PrecacheSound(HEAL_DONE_VO);
	PrecacheSound(HEAL_READY_VO);
}

public void CE_OnPostEquip(int client, int entity, int index, int defid, int quality, ArrayList hAttributes, const char[] type)
{
	if (!StrEqual(type, "weapon"))return;
	if(CE_GetAttributeInteger(entity, "syringe blood mode") > 0)
	{
		int m_iCapacity = CE_GetAttributeInteger(entity, "syringe blood mode capacity");
		m_iCap[client] = m_iCapacity;
		if(m_iCapacity > 0)
		{
			float flPose = float(m_iBlood[client]) / float(m_iCapacity);
			CEModels_WearSetEntPropFloatOfWeapon(entity, Prop_Send, "m_flPoseParameter", flPose);
		}
	}
}

public int TF2_GetUberValue(int client)
{
	int iMedigun = GetPlayerWeaponSlot(client, 1);
	if (iMedigun > 0 && HasEntProp(iMedigun, Prop_Send, "m_flChargeLevel"))
	{
		return RoundToFloor(GetEntPropFloat(iMedigun, Prop_Send, "m_flChargeLevel") * 100);
	}
	return 0;
}

public void OnPluginStart()
{
	HookEvent("player_death", evPlayerDeath);
	HookEvent("teamplay_round_start", evRoundStart);
	HookEvent("player_spawn", evPlayerSpawn);
	HookEvent("post_inventory_application", evPlayerSpawn);
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientPostAdminCheck(i);
		}
	}
	CreateTimer(HUD_RATE, Timer_Think, _, TIMER_REPEAT);
}

public Action Timer_Think(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && m_iCap[i] > 0)
		{
			Syringe_UpdateCheck(i);
			Syringe_UpdateCharge(i);
			Syringe_DrawHUD(i);
		}
	}
}

public void Syringe_UpdateCheck(int client)
{
	if (m_bChecked[client])return;

	for (int j = 0; j <= 5; j++)
	{
		int iWeapon = GetPlayerWeaponSlot(client, j);
		if(iWeapon > 0 && IsValidEntity(iWeapon) && CE_GetAttributeInteger(iWeapon, "syringe blood mode") > 0)
		{
			m_bChecked[client] = true;
			break;
		}
	}

	if(!m_bChecked[client])
	{
			m_iBlood[client] = 0;
			m_iCap[client] = 0;
	}
}

public void Syringe_UpdateCharge(int client)
{
	int iActualValue  = GetEntProp(client, Prop_Send, "m_iHealPoints");
	int iAmount = iActualValue - m_iLastValue[client];

	if (iAmount > SYRINGE_HEALING_CAP)iAmount = SYRINGE_HEALING_CAP;
	m_iLastValue[client] = iActualValue;

	if(m_bChecked[client] && m_iCap[client] > 0)
	{
		m_iBlood[client] += iAmount;
		if (m_iBlood[client] > m_iCap[client]) m_iBlood[client] = m_iCap[client];
		if(!m_bReady[client] && m_iBlood[client] == m_iCap[client])
		{
			ClientCommand(client, "playgamesound %s", HEAL_READY);
			EmitSoundToAll(HEAL_READY_VO, client);
			m_bReady[client] = true;
		}

		float flPose = float(m_iBlood[client]) / float(m_iCap[client]);
		for (int j = 0; j <= 5; j++)
		{
			int iWeapon = GetPlayerWeaponSlot(client, j);
			if(iWeapon > 0 && IsValidEntity(iWeapon) && CE_GetAttributeInteger(iWeapon, "syringe blood mode") > 0)
			{
				CEModels_WearSetEntPropFloatOfWeapon(iWeapon, Prop_Send, "m_flPoseParameter", flPose);
			}
		}
	}
}

public void Syringe_DrawHUD(int client)
{
	if (!m_bChecked[client])return;

	char sHUDText[128];
	char sProgress[32];
	int iPercents = RoundToCeil(float(m_iBlood[client]) / float(m_iCap[client]) * 100.0);

	for (int j = 1; j <= 10; j++)
	{
		if (iPercents >= j * 10)StrCat(sProgress, sizeof(sProgress), CHAR_FULL);
		else StrCat(sProgress, sizeof(sProgress), CHAR_EMPTY);
	}

	Format(sHUDText, sizeof(sHUDText), "Syringe: %d%%%%   \n%s   ", iPercents, sProgress);

	if(m_bReady[client])
	{
		SetHudTextParams(1.0, 0.8, 0.5, 255, 0, 0, 255);
	} else {
		SetHudTextParams(1.0, 0.8, 0.5, 255, 255, 255, 255);
	}
	ShowHudText(client, -1, sHUDText);
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_TraceAttack, TraceAttack);
	m_iLastValue[client] = GetEntProp(client, Prop_Send, "m_iHealPoints");
}

public Action TraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if(!IsClientValid(attacker)) return Plugin_Continue;
	if(!IsClientValid(victim)) return Plugin_Continue;
	if(!IsPlayerAlive(attacker)) return Plugin_Continue;
	if(!IsPlayerAlive(victim)) return Plugin_Continue;
	if(GetClientTeam(attacker) != GetClientTeam(victim)) return Plugin_Continue;

	int iWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
	if(iWeapon > 0 && CE_GetAttributeInteger(iWeapon, "syringe blood mode") > 0 && m_iCap[attacker] > 0)
	{
		int iHealth = GetClientHealth(victim);
		int iMaxHealth = TF2_GetOverheal(victim, 1.5);

		if(iHealth <= iMaxHealth && m_iBlood[attacker] >= m_iCap[attacker])
		{
			Syringe_ApplyEffect(victim, attacker, iWeapon);
		}
	}
	return Plugin_Continue;
}

public void Syringe_ApplyEffect(int victim, int attacker, int iWeapon)
{
	int iHealth = GetClientHealth(victim);
	int iMaxHealth = TF2_GetOverheal(victim, 1.5);

	int iHeal = CE_GetAttributeInteger(iWeapon, "syringe blood mode heal");
	EmitSoundToAll(HEAL_SOUND, victim);

	EmitSoundToAll(HEAL_DONE_VO, attacker);
	iHealth = iHealth + iHeal;
	if (iHealth > iMaxHealth)iHealth = iMaxHealth;
	SetEntityHealth(victim, iHealth);

	m_iBlood[attacker] = 0;
	m_bReady[attacker] = false;

	CEModels_WearSetEntPropFloatOfWeapon(iWeapon, Prop_Send, "m_flPoseParameter", 0.0);

	// Getting Ubercharge type
	int iMedigun = GetPlayerWeaponSlot(attacker, 1);
	if(IsValidEntity(iMedigun))
	{
		// Check if this weapon is medigun.
		char sClassName[64];
		GetEntityClassname(iMedigun, sClassName, sizeof(sClassName));
		if(StrEqual(sClassName, MEDIGUN_CLASSNAME))
		{
			TFCond iCond;
			int iDefIndex = GetEntProp(iMedigun, Prop_Send, "m_iItemDefinitionIndex");
			switch(iDefIndex)
			{
				case 35:iCond = TFCond_Buffed; 			// Kritzkrieg
				case 411:iCond = TFCond_RegenBuffed;	// Megahealer
				case 998: {								// Vacc
					int iCharge = GetEntProp(iMedigun, Prop_Send, "m_nChargeResistType");
					switch(iCharge)
					{
						case 0:iCond = TFCond_UberBulletResist;		// Bullet Resist
						case 1:iCond = TFCond_UberBlastResist;		// Blast Resist
						case 2:iCond = TFCond_UberFireResist;		// Fire Resist
					}
				}
				default:iCond = TFCond_DefenseBuffed; 	// Stock Uber
			}
			TF2_AddCondition(victim, iCond, CE_GetAttributeFloat(iWeapon, "syringe blood mode uber"), attacker);
		}
	}

	Event hEvent = CreateEvent("player_healed");
	if (hEvent == null)return;
	hEvent.SetInt("sourcemod", 1);
	hEvent.SetInt("patient", GetClientUserId(victim));
	hEvent.SetInt("healer", GetClientUserId(attacker));
	hEvent.SetInt("amount", iHeal);
	hEvent.Fire();

	hEvent = CreateEvent("player_healonhit", true);
	hEvent.SetInt("amount", iHeal);
	hEvent.SetInt("entindex", victim);
	hEvent.Fire();
}

public void OnClientDisconnect(int client)
{
	m_iCap[client] = 0;
	m_iBlood[client] = 0;
	m_bReady[client] = false;
}

public void OnClientConnected(int client)
{
	m_iCap[client] = 0;
	m_iBlood[client] = 0;
	m_bReady[client] = false;
}

public int TF2_GetOverheal(int iClient, float flOverHeal)
{
	int iEnt = -1;
	while((iEnt = FindEntityByClassname(iEnt, "tf_wearable_razorback")) != INVALID_ENT_REFERENCE)
	{
		if(GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") != iClient) continue;
		return TF2_GetMaxHealth(iClient);
	}

	return RoundToFloor(TF2_GetMaxHealth(iClient) * flOverHeal);
}

public int TF2_GetMaxHealth(int iClient)
{
    return GetEntProp(iClient, Prop_Data, "m_iMaxHealth");
}
