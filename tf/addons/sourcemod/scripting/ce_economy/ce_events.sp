#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "1.0"

#include <sdktools>
#include <sdkhooks>
#include <ce_util>
#include <ce_events>
#include <ce_complex_conditions>
#include <tf2>
#include <tf2_stocks>

#define TF_BUILDING_DISPENSER 0
#define TF_BUILDING_TELEPORTER 1
#define TF_BUILDING_SENTRY 2
#define TF_BUILDING_SAPPER 3

#define TF_BOSS_HHH 1
#define TF_BOSS_EYEBALL 2
#define TF_BOSS_MERASMUS 3

#define MAX_EVENT_UNIQUE_INDEX_INT 10000

int m_hLastWeapon[MAXPLAYERS + 1];
bool g_CoreEnabled = false;
Handle g_hOnSendEvent;

float m_flEscortProgress = -1.0;

public Plugin myinfo =
{
	name = "Creators.TF Economy - Events Handler",
	author = PLUGIN_AUTHOR,
	description = "Creators.TF Economy Events Handler",
	version = PLUGIN_VERSION,
	url = "https://creators.tf"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ce_events");
	
	CreateNative("CEEvents_GetEventIndex", Native_GetEventIndex);
	CreateNative("CEEvents_SendEventToClient", Native_SendEventToClient);
	CreateNative("CEEvents_LastUsedWeapon", Native_LastUsedWeapon);
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Misc Events
	HookEvent("payload_pushed", payload_pushed);
	HookEvent("killed_capping_player", killed_capping_player);
	HookEvent("environmental_death", environmental_death);
	HookEvent("medic_death", medic_death);

	// Teamplay Events
	HookEvent("teamplay_point_captured", teamplay_point_captured);
	HookEvent("teamplay_flag_event", teamplay_flag_event);
	HookEvent("teamplay_win_panel", evTeamplayWinPanel);
	HookEvent("teamplay_round_win", evTeamplayRoundWin);
	HookEvent("teamplay_round_start", evTeamplayRoundStart);
	HookEvent("teamplay_round_active", evTeamplayRoundActive);
	HookEvent("teamplay_setup_finished", teamplay_setup_finished);


	// Object Events
	HookEvent("object_destroyed", object_destroyed);
	HookEvent("object_detonated", object_detonated);
	HookEvent("object_deflected", object_deflected);


	// Player Events
	HookEvent("player_score_changed", player_score_changed);
	HookEvent("player_hurt", player_hurt);
	HookEvent("player_spawn", player_spawn);
	HookEvent("player_healed", player_healed);
	HookEvent("player_chargedeployed", player_chargedeployed);
	HookEvent("player_death", player_death);


	// Halloween Events
	HookEvent("halloween_soul_collected", halloween_soul_collected);
	HookEvent("halloween_duck_collected", halloween_duck_collected);
	HookEvent("halloween_skeleton_killed", halloween_skeleton_killed);
	HookEvent("halloween_boss_killed", halloween_boss_killed);
	HookEvent("halloween_pumpkin_grab", halloween_pumpkin_grab);
	HookEvent("respawn_ghost", respawn_ghost);
	HookEvent("tagged_player_as_it", tagged_player_as_it);
	HookEvent("merasmus_stunned", merasmus_stunned);
	HookEvent("merasmus_prop_found", merasmus_prop_found);
	HookEvent("eyeball_boss_stunned", eyeball_boss_stunned);
	HookEvent("eyeball_boss_killer", eyeball_boss_killer);
	HookEvent("escaped_loot_island", escaped_loot_island);
	HookEvent("escape_hell", escape_hell);
	
	HookEvent("team_leader_killed", team_leader_killed);

	g_hOnSendEvent = CreateGlobalForward("CEEvents_OnSendEvent", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

	CreateTimer(0.5, Timer_EscordProgressUpdate, _, TIMER_REPEAT);
	RegAdminCmd("ce_test_event", cTestEvnt, ADMFLAG_ROOT, "");

	LateHooking();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "obj_") != -1)
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	if(StrEqual(classname, "player"))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	if(StrContains(classname, "item_healthkit") != -1)
	{
		SDKHook(entity, SDKHook_Touch, OnTouch);
	}
}

public void LateHooking()
{
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "obj_*")) != -1)
	{
		SDKHook(ent, SDKHook_OnTakeDamage, OnTakeDamage);
	}

	ent = -1;
	while ((ent = FindEntityByClassname(ent, "item_healthkit_*")) != -1)
	{
		SDKHook(ent, SDKHook_Touch, OnTouch);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public Action OnTouch(int entity, int toucher)
{
	if (!IsClientValid(toucher))return Plugin_Continue;

	int hOwner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (hOwner == toucher)return Plugin_Continue;

	// If someone touched a sandvich, mark heavy's secondary weapon as last used.
	if(IsClientValid(hOwner))
	{
		if(TF2_GetPlayerClass(hOwner) == TFClass_Heavy)
		{
			int iLunchBox = GetPlayerWeaponSlot(hOwner, 1);
			if(IsValidEntity(iLunchBox))
			{
				m_hLastWeapon[hOwner] = iLunchBox;
			}
		}
	}

	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if(IsClientValid(attacker))
	{
		if(IsValidEntity(inflictor))
		{
			// If inflictor entity has a "m_hBuilder" prop, that means we've killed with a building.
			// Setting our wrench as last weapon.
			if(HasEntProp(inflictor, Prop_Send, "m_hBuilder"))
			{
				if(TF2_GetPlayerClass(attacker) == TFClass_Engineer)
				{
					int iWrench = GetPlayerWeaponSlot(attacker, 2);
					if(IsValidEntity(iWrench))
					{
						m_hLastWeapon[attacker] = iWrench;
					}
				}
			} else {
				// Player killed someone with a hitscan weapon. Saving the one.
				m_hLastWeapon[attacker] = weapon;
			}
		}
	}
}

public Action cTestEvnt(int client, int args)
{
	if(IsClientValid(client))
	{
		char sArg1[128], sArg2[11];
		GetCmdArg(1, sArg1, sizeof(sArg1));
		GetCmdArg(2, sArg2, sizeof(sArg2));
		CELogicEvents iEvent = CEEvents_GetEventIndex(sArg1);

		CEEvents_SendEventToClient(client, iEvent, MAX(StringToInt(sArg2), 1), MakeRandomEventIndex());
	}

	return Plugin_Handled;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "ce_core"))g_CoreEnabled = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "ce_core"))g_CoreEnabled = false;
}

public any Native_LastUsedWeapon(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	return m_hLastWeapon[client];
}

public any Native_SendEventToClient(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int event = GetNativeCell(2);
	int add = GetNativeCell(3);
	int unique_id = GetNativeCell(4);

	Call_StartForward(g_hOnSendEvent);
	Call_PushCell(client);
	Call_PushCell(event);
	Call_PushCell(add);
	Call_PushCell(unique_id);
	Call_Finish();
}

public Action Timer_EscordProgressUpdate(Handle timer, any data)
{
	float flCart = Payload_GetProgress();

	if(flCart != m_flEscortProgress)
	{
		m_flEscortProgress = flCart;
	}
}

/**
*	NATIVE EVENTS ARE HANDLED HERE.
		-- Event
*/

public Action player_death(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;

	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int assister = GetClientOfUserId(GetEventInt(hEvent, "assister"));

	int death_flags = GetEventInt(hEvent, "death_flags");
	int customkill = GetEventInt(hEvent, "customkill");
	int kill_streak_victim = GetEventInt(hEvent, "kill_streak_victim");
	int crit_type = GetEventInt(hEvent, "crit_type");
	
	int unique = view_as<int>(hEvent);

	char weapon[64];
	GetEventString(hEvent, "weapon", weapon, sizeof(weapon));

	if(IsClientValid(client))
	{
		CEEvents_SendEventToClient(client, LOGIC_DEATH, 1, unique);
		if(IsClientValid(attacker))
		{
			if(attacker != client)
			{
				CEEvents_SendEventToClient(attacker, LOGIC_KILL, 1, unique);
				CEEvents_SendEventToClient(attacker, LOGIC_KILL_OR_ASSIST, 1, unique);

				if(death_flags & TF_DEATHFLAG_KILLERDOMINATION)
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_DOMINATE, 1, unique);
				}

				if(death_flags & TF_DEATHFLAG_KILLERREVENGE)
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_REVENGE, 1, unique);
				}

				switch(TF2_GetPlayerClass(client))
				{
					case TFClass_Scout:CEEvents_SendEventToClient(attacker, LOGIC_KILL_CLASS_SCOUT, 1, unique);
					case TFClass_Soldier:CEEvents_SendEventToClient(attacker, LOGIC_KILL_CLASS_SOLDIER, 1, unique);
					case TFClass_Pyro:CEEvents_SendEventToClient(attacker, LOGIC_KILL_CLASS_PYRO, 1, unique);
					case TFClass_DemoMan:CEEvents_SendEventToClient(attacker, LOGIC_KILL_CLASS_DEMOMAN, 1, unique);
					case TFClass_Heavy:CEEvents_SendEventToClient(attacker, LOGIC_KILL_CLASS_HEAVY, 1, unique);
					case TFClass_Engineer:CEEvents_SendEventToClient(attacker, LOGIC_KILL_CLASS_ENGINEER, 1, unique);
					case TFClass_Medic:CEEvents_SendEventToClient(attacker, LOGIC_KILL_CLASS_MEDIC, 1, unique);
					case TFClass_Sniper:CEEvents_SendEventToClient(attacker, LOGIC_KILL_CLASS_SNIPER, 1, unique);
					case TFClass_Spy:CEEvents_SendEventToClient(attacker, LOGIC_KILL_CLASS_SPY, 1, unique);
				}

				switch(customkill)
				{
					case TF_CUSTOM_BACKSTAB: CEEvents_SendEventToClient(attacker, LOGIC_KILL_BACKSTAB, 1, unique);
					case TF_CUSTOM_HEADSHOT: CEEvents_SendEventToClient(attacker, LOGIC_KILL_HEADSHOT, 1, unique);
					case TF_CUSTOM_PUMPKIN_BOMB: CEEvents_SendEventToClient(attacker, LOGIC_KILL_PUMPKIN_BOMB, 1, unique);

					case TF_CUSTOM_SPELL_BATS: CEEvents_SendEventToClient(attacker, LOGIC_KILL_MAGIC, 1, unique);
					case TF_CUSTOM_SPELL_BLASTJUMP: CEEvents_SendEventToClient(attacker, LOGIC_KILL_MAGIC, 1, unique);
					case TF_CUSTOM_SPELL_FIREBALL: CEEvents_SendEventToClient(attacker, LOGIC_KILL_MAGIC, 1, unique);
					case TF_CUSTOM_SPELL_LIGHTNING: CEEvents_SendEventToClient(attacker, LOGIC_KILL_MAGIC, 1, unique);
					case TF_CUSTOM_SPELL_METEOR: CEEvents_SendEventToClient(attacker, LOGIC_KILL_MAGIC, 1, unique);
					case TF_CUSTOM_SPELL_MIRV: CEEvents_SendEventToClient(attacker, LOGIC_KILL_MAGIC, 1, unique);
					case TF_CUSTOM_SPELL_MONOCULUS: CEEvents_SendEventToClient(attacker, LOGIC_KILL_MAGIC, 1, unique);
					case TF_CUSTOM_SPELL_SKELETON: CEEvents_SendEventToClient(attacker, LOGIC_KILL_MAGIC, 1, unique);
					case TF_CUSTOM_SPELL_TELEPORT: CEEvents_SendEventToClient(attacker, LOGIC_KILL_MAGIC, 1, unique);
					case TF_CUSTOM_SPELL_TINY: CEEvents_SendEventToClient(attacker, LOGIC_KILL_MAGIC, 1, unique);
				}

				// Airborne
				if(!(GetEntityFlags(attacker) & FL_ONGROUND))
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_WHILE_AIRBORNE, 1, unique);
				}

				if(!(GetEntityFlags(client) & FL_ONGROUND))
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_AIRBORNE_ENEMY, 1, unique);
				}

				// Reflect
				if(StrContains(weapon, "deflect") != -1)
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_WITH_REFLECT, 1, unique);
				}

				// Objects
				if(StrContains(weapon, "obj_") != -1)
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_WITH_OBJECT, 1, unique);
				}

				// Uber
				if (IsUbercharged(attacker))
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_WHILE_UBERCHARGED, 1, unique);
				}

				// Cloaked spy
				if(TF2_IsPlayerInCondition(client, TFCond_Stealthed))
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_CLOAKED_SPY, 1, unique);
				}

				if(kill_streak_victim > 5)
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_STREAK_ENDED, 1, unique);
				}

				// Crits
				switch(crit_type)
				{
					case 0: CEEvents_SendEventToClient(attacker, LOGIC_KILL_NON_CRITICAL, 1, unique);
					case 1: CEEvents_SendEventToClient(attacker, LOGIC_KILL_MINI_CRITICAL, 1, unique);
					case 2: CEEvents_SendEventToClient(attacker, LOGIC_KILL_CRITICAL, 1, unique);
				}

				if(death_flags & TF_DEATHFLAG_GIBBED)
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_GIB, 1, unique);
				}

				if(TF2_IsPlayerInCondition(attacker, TFCond_Taunting))
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_WHILE_TAUNTING, 1, unique);
				}

				if(TF2_IsPlayerInCondition(client, TFCond_Taunting))
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_TAUNTING, 1, unique);
				}

				// Halloween
				if(TF2_IsPlayerInCondition(attacker, TFCond_HalloweenInHell))
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_IN_HELL, 1, unique);
				}

				if(TF2_IsPlayerInCondition(attacker, TFCond_EyeaductUnderworld))
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_IN_PURGATORY, 1, unique);
				}

				if(TF2_IsPlayerInCondition(attacker, TFCond_HalloweenKart))
				{
					CEEvents_SendEventToClient(attacker, LOGIC_BUMPER_CARS_KILL, 1, unique);
				}

				if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
				{
					CEEvents_SendEventToClient(attacker, LOGIC_KILL_STUNNED, 1, unique);
				}
			}
		}

		if(IsClientValid(assister))
		{
			if(assister != client)
			{
				CEEvents_SendEventToClient(assister, LOGIC_ASSIST, 1, unique);
				CEEvents_SendEventToClient(assister, LOGIC_KILL_OR_ASSIST, 1, unique);

				if(death_flags & TF_DEATHFLAG_ASSISTERDOMINATION)
				{
					CEEvents_SendEventToClient(assister, LOGIC_KILL_DOMINATE, 1, unique);
				}

				if(death_flags & TF_DEATHFLAG_ASSISTERREVENGE)
				{
					CEEvents_SendEventToClient(assister, LOGIC_KILL_REVENGE, 1, unique);
				}

				// Uber
				if (IsUbercharged(assister))
				{
					CEEvents_SendEventToClient(assister, LOGIC_ASSIST_WHILE_UBERCHARGED, 1, unique);
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action team_leader_killed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int killer = GetEventInt(hEvent, "killer");
	int victim = GetEventInt(hEvent, "victim");
	
	if(killer != victim)
	{
		CEEvents_SendEventToClient(killer, LOGIC_KILL_LEADER, 1, view_as<int>(hEvent));
	}

	return Plugin_Continue;
}

public Action escaped_loot_island(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	CEEvents_SendEventToClient(player, LOGIC_ESCAPE_LOOT_ISLAND, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action escape_hell(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	CEEvents_SendEventToClient(player, LOGIC_ESCAPE_HELL, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action halloween_pumpkin_grab(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int player = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	CEEvents_SendEventToClient(player, LOGIC_COLLECT_CRIT_PUMPKIN, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action merasmus_stunned(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	CEEvents_SendEventToClient(player, LOGIC_MERASMUS_STUN, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action halloween_boss_killed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int boss = GetEventInt(hEvent, "boss");
	int player = GetClientOfUserId(GetEventInt(hEvent, "killer"));

	switch(boss)
	{
		case TF_BOSS_HHH: CEEvents_SendEventToClient(player, LOGIC_HHH_KILL, 1, view_as<int>(hEvent));
		case TF_BOSS_MERASMUS: CEEvents_SendEventToClient(player, LOGIC_MERASMUS_KILL, 1, view_as<int>(hEvent));
	}
	return Plugin_Continue;
}

public Action halloween_skeleton_killed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	CEEvents_SendEventToClient(player, LOGIC_SKELETON_KILL, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action merasmus_prop_found(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	CEEvents_SendEventToClient(player, LOGIC_MERASMUS_PROP_FOUND, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action eyeball_boss_stunned(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int player = GetEventInt(hEvent, "player_entindex");

	CEEvents_SendEventToClient(player, LOGIC_EYEBALL_STUN, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action eyeball_boss_killer(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int player = GetEventInt(hEvent, "player_entindex");

	CEEvents_SendEventToClient(player, LOGIC_EYEBALL_KILL, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action tagged_player_as_it(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int player = GetClientOfUserId(GetEventInt(hEvent, "player"));

	CEEvents_SendEventToClient(player, LOGIC_HHH_TARGET_IT, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action respawn_ghost(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int reviver = GetClientOfUserId(GetEventInt(hEvent, "reviver"));

	CEEvents_SendEventToClient(reviver, LOGIC_BUMPER_CARS_REVIVE, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action halloween_duck_collected(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int collector = GetClientOfUserId(GetEventInt(hEvent, "collector"));

	CEEvents_SendEventToClient(collector, LOGIC_COLLECT_DUCK, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action halloween_soul_collected(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int collector = GetClientOfUserId(GetEventInt(hEvent, "collecting_player"));
	int soul_count = GetEventInt(hEvent, "soul_count");

	CEEvents_SendEventToClient(collector, LOGIC_COLLECT_SOULS, soul_count, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action object_destroyed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int assister = GetClientOfUserId(GetEventInt(hEvent, "assister"));
	int objecttype = GetEventInt(hEvent, "objecttype");

	if(IsClientValid(client))
	{
		switch(objecttype)
		{
			case TF_BUILDING_SENTRY: CEEvents_SendEventToClient(client, LOGIC_OBJECT_DESTROYED_SENTRY, 1, view_as<int>(hEvent));
			case TF_BUILDING_DISPENSER: CEEvents_SendEventToClient(client, LOGIC_OBJECT_DESTROYED_DISPENSER, 1, view_as<int>(hEvent));
			case TF_BUILDING_TELEPORTER: CEEvents_SendEventToClient(client, LOGIC_OBJECT_DESTROYED_TELEPORTER, 1, view_as<int>(hEvent));
		}
	}

	if(IsClientValid(attacker) && attacker != client)
	{
		CEEvents_SendEventToClient(attacker, LOGIC_KILL_OBJECT, 1, view_as<int>(hEvent));
		switch(objecttype)
		{
			case TF_BUILDING_SENTRY: CEEvents_SendEventToClient(attacker, LOGIC_KILL_OBJECT_SENTRY, 1, view_as<int>(hEvent));
			case TF_BUILDING_DISPENSER: CEEvents_SendEventToClient(attacker, LOGIC_KILL_OBJECT_DISPENSER, 1, view_as<int>(hEvent));
			case TF_BUILDING_TELEPORTER: CEEvents_SendEventToClient(attacker, LOGIC_KILL_OBJECT_TELEPORTER, 1, view_as<int>(hEvent));
			case TF_BUILDING_SAPPER: CEEvents_SendEventToClient(attacker, LOGIC_KILL_OBJECT_SAPPER, 1, view_as<int>(hEvent));
		}
	}

	if(IsClientValid(assister))
	{
		if(IsUbercharged(assister))
		{
			switch(objecttype)
			{
				case TF_BUILDING_SENTRY: CEEvents_SendEventToClient(attacker, LOGIC_ASSIST_WHILE_UBERCHARGED_OBJECT_SENTRY, 1, view_as<int>(hEvent));
				case TF_BUILDING_DISPENSER: CEEvents_SendEventToClient(attacker, LOGIC_ASSIST_WHILE_UBERCHARGED_OBJECT_DISPENSER, 1, view_as<int>(hEvent));
				case TF_BUILDING_TELEPORTER: CEEvents_SendEventToClient(attacker, LOGIC_ASSIST_WHILE_UBERCHARGED_OBJECT_TELEPORTER, 1, view_as<int>(hEvent));
			}
		}
	}

	return Plugin_Continue;
}

public Action teamplay_setup_finished(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;

	return Plugin_Continue;
}

public Action evTeamplayRoundStart(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;

	return Plugin_Continue;
}

public Action evTeamplayRoundActive(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;

	return Plugin_Continue;
}

public Action object_detonated(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int objecttype = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

	if(IsClientValid(client))
	{
		switch(objecttype)
		{
			case TF_BUILDING_SENTRY: CEEvents_SendEventToClient(client, LOGIC_OBJECT_DESTROYED_SENTRY, 1, view_as<int>(hEvent));
			case TF_BUILDING_DISPENSER: CEEvents_SendEventToClient(client, LOGIC_OBJECT_DESTROYED_DISPENSER, 1, view_as<int>(hEvent));
			case TF_BUILDING_TELEPORTER: CEEvents_SendEventToClient(client, LOGIC_OBJECT_DESTROYED_TELEPORTER, 1, view_as<int>(hEvent));
		}
	}

	return Plugin_Continue;
}

public Action object_deflected(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	CEEvents_SendEventToClient(client, LOGIC_REFLECT, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action player_hurt(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int damage = GetEventInt(hEvent, "damageamount");

	if(IsClientValid(attacker) && attacker != client)
	{
		CEEvents_SendEventToClient(attacker, LOGIC_HIT_PLAYER, 1, view_as<int>(hEvent));
		CEEvents_SendEventToClient(attacker, LOGIC_DEAL_DAMAGE, damage, view_as<int>(hEvent));
	}

	if(IsClientValid(client))
	{
		CEEvents_SendEventToClient(client, LOGIC_TAKE_DAMAGE, damage, view_as<int>(hEvent));
	}

	return Plugin_Continue;
}

public Action player_score_changed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int player = GetEventInt(hEvent, "player");
	int delta = GetEventInt(hEvent, "delta");

	CEEvents_SendEventToClient(player, LOGIC_SCORE_POINTS, delta, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action environmental_death(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int killer = GetEventInt(hEvent, "killer");
	int victim = GetEventInt(hEvent, "victim");

	if(IsClientValid(killer) && killer != victim)
	{
		CEEvents_SendEventToClient(killer, LOGIC_KILL_ENVIRONMENTAL, 1, view_as<int>(hEvent));
	}

	return Plugin_Continue;
}

public Action medic_death(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	bool charged = GetEventBool(hEvent, "charged");

	if(charged)
	{
		CEEvents_SendEventToClient(attacker, LOGIC_KILL_UBERED_MEDIC, 1, view_as<int>(hEvent));
	}

	return Plugin_Continue;
}

public Action evTeamplayRoundWin(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;

	return Plugin_Continue;
}

public Action player_spawn(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	CEEvents_SendEventToClient(client, LOGIC_SPAWN, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action teamplay_flag_event(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int player = GetEventInt(hEvent, "player");
	int eventtype = GetEventInt(hEvent, "eventtype");
	
	if(IsClientValid(player))
	{
		switch(eventtype)
		{
			case TF_FLAGEVENT_PICKEDUP:CEEvents_SendEventToClient(player, LOGIC_PICKUP_FLAG, 1, view_as<int>(hEvent));
			case TF_FLAGEVENT_CAPTURED:
			{
				CEEvents_SendEventToClient(player, LOGIC_CAPTURE_FLAG, 1, view_as<int>(hEvent));
				CEEvents_SendEventToClient(player, LOGIC_OBJECTIVE_CAPTURE, 1, view_as<int>(hEvent));
				CEEvents_SendEventToClient(player, LOGIC_OBJECTIVE_CAPTURE_OR_DEFEND, 1, view_as<int>(hEvent));
			}
			case TF_FLAGEVENT_DEFENDED:
			{
				CEEvents_SendEventToClient(player, LOGIC_DEFEND_FLAG, 1, view_as<int>(hEvent));
				CEEvents_SendEventToClient(player, LOGIC_OBJECTIVE_DEFEND, 1, view_as<int>(hEvent));
				CEEvents_SendEventToClient(player, LOGIC_OBJECTIVE_CAPTURE_OR_DEFEND, 1, view_as<int>(hEvent));
			}
		}
	}

	return Plugin_Continue;
}

public Action player_healed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int patient = GetClientOfUserId(GetEventInt(hEvent, "patient"));
	int healer = GetClientOfUserId(GetEventInt(hEvent, "healer"));
	int amount = GetEventInt(hEvent, "amount");

	if(IsClientValid(healer) && healer != patient)
	{
		if(TF2_GetPlayerClass(healer) == TFClass_Medic)
		{
			m_hLastWeapon[healer] = GetEntPropEnt(healer, Prop_Send, "m_hActiveWeapon");
		}
		CEEvents_SendEventToClient(healer, LOGIC_HEALING_TEAMMATES, amount, view_as<int>(hEvent));
	}

	return Plugin_Continue;
}

public Action player_chargedeployed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;

	return Plugin_Continue;
}

public Action killed_capping_player(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int attacker = GetEventInt(hEvent, "killer");

	if(IsClientValid(attacker))
	{
		CEEvents_SendEventToClient(attacker, LOGIC_DEFEND_POINT, 1, view_as<int>(hEvent));
		CEEvents_SendEventToClient(attacker, LOGIC_OBJECTIVE_DEFEND, 1, view_as<int>(hEvent));
		CEEvents_SendEventToClient(attacker, LOGIC_OBJECTIVE_CAPTURE_OR_DEFEND, 1, view_as<int>(hEvent));
	}

	return Plugin_Continue;
}

public Action payload_pushed(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int pusher = GetClientOfUserId(GetEventInt(hEvent, "pusher"));
	int distance = GetEventInt(hEvent, "distance");

	if(IsClientValid(pusher))
	{
		CEEvents_SendEventToClient(pusher, LOGIC_PAYLOAD_PUSH, distance, view_as<int>(hEvent));
	}

	return Plugin_Continue;
}

public bool IsUbercharged(int client)
{
	return 	TF2_IsPlayerInCondition(client, TFCond_Ubercharged) ||
			TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) ||
			TF2_IsPlayerInCondition(client, TFCond_MegaHeal) ||
			TF2_IsPlayerInCondition(client, TFCond_UberBlastResist) ||
			TF2_IsPlayerInCondition(client, TFCond_UberFireResist) ||
			TF2_IsPlayerInCondition(client, TFCond_UberBulletResist);
}

public Action evTeamplayWinPanel(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;
	int player_1 = GetEventInt(hEvent, "player_1");
	int player_2 = GetEventInt(hEvent, "player_2");
	int player_3 = GetEventInt(hEvent, "player_3");

	if (IsClientValid(player_1))CEEvents_SendEventToClient(player_1, LOGIC_MVP, 1, view_as<int>(hEvent));
	if (IsClientValid(player_2))CEEvents_SendEventToClient(player_2, LOGIC_MVP, 1, view_as<int>(hEvent));
	if (IsClientValid(player_3))CEEvents_SendEventToClient(player_3, LOGIC_MVP, 1, view_as<int>(hEvent));

	return Plugin_Continue;
}

public Action teamplay_point_captured(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if (!g_CoreEnabled)return Plugin_Continue;

	char cappers[1024];
	GetEventString(hEvent, "cappers", cappers, sizeof(cappers));
	int len = strlen(cappers);
	for (int i = 0; i < len; i++)
	{
		int client = cappers[i];
		if (!IsClientValid(client))continue;

		CEEvents_SendEventToClient(client, LOGIC_CAPTURE_POINT, 1, view_as<int>(hEvent));
		CEEvents_SendEventToClient(client, LOGIC_OBJECTIVE_CAPTURE, 1, view_as<int>(hEvent));
		CEEvents_SendEventToClient(client, LOGIC_OBJECTIVE_CAPTURE_OR_DEFEND, 1, view_as<int>(hEvent));
	}
	return Plugin_Continue;
}

/**
*	MISC FUNCTIONS
*/

public float Payload_GetProgress()
{
	int iEnt = -1;
	float flProgress = 0.0;
	while((iEnt = FindEntityByClassname(iEnt, "team_train_watcher")) != -1 )
	{
		if (IsValidEntity(iEnt))
		{
			// If cart is of appropriate team.
			float flProgress2 = GetEntPropFloat(iEnt, Prop_Send, "m_flTotalProgress");
			if (flProgress < flProgress2)flProgress = flProgress2;
		}
	}
	return flProgress;
}

public any Native_GetEventIndex(Handle plugin, int numParams)
{
	char sName[128];
	GetNativeString(1, sName, sizeof(sName));

	if(StrEqual(sName, "LOGIC_KILL")) return LOGIC_KILL;
	if(StrEqual(sName, "LOGIC_ASSIST")) return LOGIC_ASSIST;
	if(StrEqual(sName, "LOGIC_KILL_OR_ASSIST")) return LOGIC_KILL_OR_ASSIST;
	if(StrEqual(sName, "LOGIC_KILL_DOMINATE")) return LOGIC_KILL_DOMINATE;
	if(StrEqual(sName, "LOGIC_KILL_REVENGE")) return LOGIC_KILL_REVENGE;
	if(StrEqual(sName, "LOGIC_KILL_CLASS_SCOUT")) return LOGIC_KILL_CLASS_SCOUT;
	if(StrEqual(sName, "LOGIC_KILL_CLASS_SOLDIER")) return LOGIC_KILL_CLASS_SOLDIER;
	if(StrEqual(sName, "LOGIC_KILL_CLASS_PYRO")) return LOGIC_KILL_CLASS_PYRO;
	if(StrEqual(sName, "LOGIC_KILL_CLASS_DEMOMAN")) return LOGIC_KILL_CLASS_DEMOMAN;
	if(StrEqual(sName, "LOGIC_KILL_CLASS_HEAVY")) return LOGIC_KILL_CLASS_HEAVY;
	if(StrEqual(sName, "LOGIC_KILL_CLASS_ENGINEER")) return LOGIC_KILL_CLASS_ENGINEER;
	if(StrEqual(sName, "LOGIC_KILL_CLASS_MEDIC")) return LOGIC_KILL_CLASS_MEDIC;
	if(StrEqual(sName, "LOGIC_KILL_CLASS_SNIPER")) return LOGIC_KILL_CLASS_SNIPER;
	if(StrEqual(sName, "LOGIC_KILL_CLASS_SPY")) return LOGIC_KILL_CLASS_SPY;
	if(StrEqual(sName, "LOGIC_KILL_HEADSHOT")) return LOGIC_KILL_HEADSHOT;
	if(StrEqual(sName, "LOGIC_KILL_BACKSTAB")) return LOGIC_KILL_BACKSTAB;
	if(StrEqual(sName, "LOGIC_KILL_AIRBORNE_ENEMY")) return LOGIC_KILL_AIRBORNE_ENEMY;
	if(StrEqual(sName, "LOGIC_KILL_WHILE_AIRBORNE")) return LOGIC_KILL_WHILE_AIRBORNE;
	if(StrEqual(sName, "LOGIC_KILL_OBJECT")) return LOGIC_KILL_OBJECT;
	if(StrEqual(sName, "LOGIC_KILL_WITH_OBJECT")) return LOGIC_KILL_WITH_OBJECT;
	if(StrEqual(sName, "LOGIC_KILL_WITH_REFLECT")) return LOGIC_KILL_WITH_REFLECT;
	if(StrEqual(sName, "LOGIC_KILL_WHILE_UBERCHARGED")) return LOGIC_KILL_WHILE_UBERCHARGED;
	if(StrEqual(sName, "LOGIC_KILL_UBERED_MEDIC")) return LOGIC_KILL_UBERED_MEDIC;
	if(StrEqual(sName, "LOGIC_KILL_STREAK_ENDED")) return LOGIC_KILL_STREAK_ENDED;
	if(StrEqual(sName, "LOGIC_KILL_NON_CRITICAL")) return LOGIC_KILL_NON_CRITICAL;
	if(StrEqual(sName, "LOGIC_KILL_CRITICAL")) return LOGIC_KILL_CRITICAL;
	if(StrEqual(sName, "LOGIC_KILL_MINI_CRITICAL")) return LOGIC_KILL_MINI_CRITICAL;
	if(StrEqual(sName, "LOGIC_KILL_GIB")) return LOGIC_KILL_GIB;
	if(StrEqual(sName, "LOGIC_KILL_TAUNTING")) return LOGIC_KILL_TAUNTING;
	if(StrEqual(sName, "LOGIC_KILL_WHILE_TAUNTING")) return LOGIC_KILL_WHILE_TAUNTING;
	if(StrEqual(sName, "LOGIC_KILL_ENVIRONMENTAL")) return LOGIC_KILL_ENVIRONMENTAL;
	if(StrEqual(sName, "LOGIC_HEALING_TEAMMATES")) return LOGIC_HEALING_TEAMMATES;
	if(StrEqual(sName, "LOGIC_ASSIST_WHILE_UBERCHARGED")) return LOGIC_ASSIST_WHILE_UBERCHARGED;
	if(StrEqual(sName, "LOGIC_CAPTURE_POINT")) return LOGIC_CAPTURE_POINT;
	if(StrEqual(sName, "LOGIC_DEFEND_POINT")) return LOGIC_DEFEND_POINT;
	if(StrEqual(sName, "LOGIC_CAPTURE_FLAG")) return LOGIC_CAPTURE_FLAG;
	if(StrEqual(sName, "LOGIC_DEFEND_FLAG")) return LOGIC_DEFEND_FLAG;
	if(StrEqual(sName, "LOGIC_PAYLOAD_PUSH")) return LOGIC_PAYLOAD_PUSH;
	if(StrEqual(sName, "LOGIC_PAYLOAD_PROGRESS")) return LOGIC_PAYLOAD_PROGRESS;
	if(StrEqual(sName, "LOGIC_OBJECTIVE_DEFEND")) return LOGIC_OBJECTIVE_DEFEND;
	if(StrEqual(sName, "LOGIC_OBJECTIVE_CAPTURE")) return LOGIC_OBJECTIVE_CAPTURE;
	if(StrEqual(sName, "LOGIC_OBJECTIVE_CAPTURE_OR_DEFEND")) return LOGIC_OBJECTIVE_CAPTURE_OR_DEFEND;
	if(StrEqual(sName, "LOGIC_MVP")) return LOGIC_MVP;
	if(StrEqual(sName, "LOGIC_SCORE_POINTS")) return LOGIC_SCORE_POINTS;
	if(StrEqual(sName, "LOGIC_TAKE_DAMAGE")) return LOGIC_TAKE_DAMAGE;
	if(StrEqual(sName, "LOGIC_DEAL_DAMAGE")) return LOGIC_DEAL_DAMAGE;
	if(StrEqual(sName, "LOGIC_ESCAPE_LOOT_ISLAND")) return LOGIC_ESCAPE_LOOT_ISLAND;
	if(StrEqual(sName, "LOGIC_ESCAPE_HELL")) return LOGIC_ESCAPE_HELL;
	if(StrEqual(sName, "LOGIC_ESCAPE_UNDERWORLD")) return LOGIC_ESCAPE_UNDERWORLD;
	if(StrEqual(sName, "LOGIC_COLLECT_SOULS")) return LOGIC_COLLECT_SOULS;
	if(StrEqual(sName, "LOGIC_COLLECT_DUCK")) return LOGIC_COLLECT_DUCK;
	if(StrEqual(sName, "LOGIC_COLLECT_CRIT_PUMPKIN")) return LOGIC_COLLECT_CRIT_PUMPKIN;
	if(StrEqual(sName, "LOGIC_BUMPER_CARS_REVIVE")) return LOGIC_BUMPER_CARS_REVIVE;
	if(StrEqual(sName, "LOGIC_BUMPER_CARS_KILL")) return LOGIC_BUMPER_CARS_KILL;
	if(StrEqual(sName, "LOGIC_KILL_WITH_CRIT_PUMPKIN")) return LOGIC_KILL_WITH_CRIT_PUMPKIN;
	if(StrEqual(sName, "LOGIC_KILL_IN_HELL")) return LOGIC_KILL_IN_HELL;
	if(StrEqual(sName, "LOGIC_KILL_IN_PURGATORY")) return LOGIC_KILL_IN_PURGATORY;
	if(StrEqual(sName, "LOGIC_KILL_IN_LOOT_ISLAND")) return LOGIC_KILL_IN_LOOT_ISLAND;
	if(StrEqual(sName, "LOGIC_HIT_PLAYER")) return LOGIC_HIT_PLAYER;
	if(StrEqual(sName, "LOGIC_REFLECT")) return LOGIC_REFLECT;
	if(StrEqual(sName, "LOGIC_MERASMUS_STUN")) return LOGIC_MERASMUS_STUN;
	if(StrEqual(sName, "LOGIC_MERASMUS_KILL")) return LOGIC_MERASMUS_KILL;
	if(StrEqual(sName, "LOGIC_MERASMUS_PROP_FOUND")) return LOGIC_MERASMUS_PROP_FOUND;
	if(StrEqual(sName, "LOGIC_EYEBALL_STUN")) return LOGIC_EYEBALL_STUN;
	if(StrEqual(sName, "LOGIC_EYEBALL_KILL")) return LOGIC_EYEBALL_KILL;
	if(StrEqual(sName, "LOGIC_HHH_KILL")) return LOGIC_HHH_KILL;
	if(StrEqual(sName, "LOGIC_HHH_TARGET_IT")) return LOGIC_HHH_TARGET_IT;
	if(StrEqual(sName, "LOGIC_SKELETON_KILL")) return LOGIC_SKELETON_KILL;

	if(StrEqual(sName, "LOGIC_DEATH")) return LOGIC_DEATH;
	if(StrEqual(sName, "LOGIC_SPAWN")) return LOGIC_SPAWN;
	if(StrEqual(sName, "LOGIC_KILL_OBJECT_SENTRY")) return LOGIC_KILL_OBJECT_SENTRY;
	if(StrEqual(sName, "LOGIC_KILL_OBJECT_DISPENSER")) return LOGIC_KILL_OBJECT_DISPENSER;
	if(StrEqual(sName, "LOGIC_KILL_OBJECT_TELEPORTER")) return LOGIC_KILL_OBJECT_TELEPORTER;
	if(StrEqual(sName, "LOGIC_KILL_OBJECT_SAPPER")) return LOGIC_KILL_OBJECT_SAPPER;
	if(StrEqual(sName, "LOGIC_WEAPON_SWITCH")) return LOGIC_WEAPON_SWITCH;
	if(StrEqual(sName, "LOGIC_ASSIST_WHILE_UBERCHARGED_OBJECT_SENTRY")) return LOGIC_ASSIST_WHILE_UBERCHARGED_OBJECT_SENTRY;
	if(StrEqual(sName, "LOGIC_ASSIST_WHILE_UBERCHARGED_OBJECT_DISPENSER")) return LOGIC_ASSIST_WHILE_UBERCHARGED_OBJECT_DISPENSER;
	if(StrEqual(sName, "LOGIC_ASSIST_WHILE_UBERCHARGED_OBJECT_TELEPORTER")) return LOGIC_ASSIST_WHILE_UBERCHARGED_OBJECT_TELEPORTER;
	if(StrEqual(sName, "LOGIC_OBJECT_DESTROYED_SENTRY")) return LOGIC_OBJECT_DESTROYED_SENTRY;
	if(StrEqual(sName, "LOGIC_OBJECT_DESTROYED_DISPENSER")) return LOGIC_OBJECT_DESTROYED_DISPENSER;
	if(StrEqual(sName, "LOGIC_OBJECT_DESTROYED_TELEPORTER")) return LOGIC_OBJECT_DESTROYED_TELEPORTER;
	if(StrEqual(sName, "LOGIC_WIN")) return LOGIC_WIN;
	if(StrEqual(sName, "LOGIC_KILL_STUNNED")) return LOGIC_KILL_STUNNED;
	if(StrEqual(sName, "LOGIC_KILL_PUMPKIN_BOMB")) return LOGIC_KILL_PUMPKIN_BOMB;
	if(StrEqual(sName, "LOGIC_KILL_MAGIC")) return LOGIC_KILL_MAGIC;
	if(StrEqual(sName, "LOGIC_PICKUP_FLAG")) return LOGIC_PICKUP_FLAG;
	if(StrEqual(sName, "LOGIC_KILL_LEADER")) return LOGIC_KILL_LEADER;

	return LOGIC_NULL;
}

public void FlushClientInfo(int client)
{
	m_hLastWeapon[client] = -1;
}

public void OnClientDisconnect(int client)
{
	FlushClientInfo(client);
}

public void OnClientAuthorized(int client)
{
	FlushClientInfo(client);
}

public void TF2_OnConditionAdded(int client, TFCond cond)
{
}

public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	switch(cond)
	{
		case TFCond_EyeaductUnderworld:
		{
			if(IsPlayerAlive(client))
			{
				CEEvents_SendEventToClient(client, LOGIC_ESCAPE_UNDERWORLD, 1, MakeRandomEventIndex());
			}
		}
	}
}

public int MakeRandomEventIndex()
{
	return GetRandomInt(0, MAX_EVENT_UNIQUE_INDEX_INT);
}