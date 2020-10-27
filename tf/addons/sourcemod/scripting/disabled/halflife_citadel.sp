#pragma semicolon 1
#pragma newdecls required
#pragma tabsize 0

#define PLUGIN_AUTHOR "Creators.TF Team"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CITADEL_MODEL "models/props_combine/combine_citadel_animated.mdl"
#define THUMPER_MODEL "models/props_combine/combinethumper002.mdl"

public Plugin myinfo =
{
	name = "Half-Life 2 Skybox Citadel Spawner",
	author = PLUGIN_AUTHOR,
	description = "Spawns Citadel in Map's Skyboxes",
	version = PLUGIN_VERSION,
	url = "https://creators.tf"
};

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", evRoundStart);
}

public Action ca(int client, int args)
{
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	float flPos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", flPos);
	PrintToConsole(client, "\"%s\"\n{\n 	\"x\" \"%f\"\n 	\"y\" \"%f\"\n 	\"z\" \"%f\"\n}", sMap, flPos[0], flPos[1], flPos[2]);
	Citadel_Create(flPos, 0.1, 0.0);
}

public void OnMapStart()
{
	PrecacheModel(CITADEL_MODEL);
	PrecacheModel(THUMPER_MODEL);
}

public Action evRoundStart(Event hEvent, const char[] szName, bool bDontBroadcast)
{
	char sLoc[96];
	BuildPath(Path_SM, sLoc, 96, "configs/halflife_citadel.cfg");
	KeyValues kv = new KeyValues("Citadel");
	kv.ImportFromFile(sLoc);

	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if(kv.JumpToKey(sMap))
	{
		float flPos[3];
		float flScale = kv.GetFloat("s", 0.1);
		flPos[0] = kv.GetFloat("x", 0.0);
		flPos[1] = kv.GetFloat("y", 0.0);
		flPos[2] = kv.GetFloat("z", 0.0);
		float flRotate = kv.GetFloat("r", 0.0);

		Citadel_Create(flPos, flScale, flRotate);
	}
	delete kv;
}

public void Citadel_Create(float flPos[3], float flScale, float flRotate)
{
	int iCitadel;
	iCitadel = CreateEntityByName("prop_dynamic_override");
	if(iCitadel > 0)
	{
		flPos[2] += 300.0;
		float flAng[3];
		flAng[1] = flRotate;
		TeleportEntity(iCitadel, flPos, flAng, NULL_VECTOR);
		SetEntityModel(iCitadel, CITADEL_MODEL);
		SetEntPropFloat(iCitadel, Prop_Send, "m_flModelScale", flScale);
		DispatchKeyValue(iCitadel, "targetname", "tf_citadel");
		DispatchSpawn(iCitadel);
		ActivateEntity(iCitadel);
		SetVariantString("open");
		AcceptEntityInput(iCitadel, "setanimation");
	}
}
