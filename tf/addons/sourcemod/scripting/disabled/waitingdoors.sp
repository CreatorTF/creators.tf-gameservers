#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <gamemode>


public Plugin myinfo =
{
    name        = "[TF2] Waiting Doors",
    author      = "stephanie, Nanochip, & Lange",
    description = "Open spawn doors during waiting for players round.",
    version     = "0.0.5",
    url         = "https://steph.anie.dev/"
};

public void TF2_OnWaitingForPlayersStart()
{
	TF2_GameMode mode = TF2_DetectGameMode();
    if (mode == TF2_GameMode_PL || mode == TF2_GameMode_ADCP) CreateTimer(0.1, openDoorsTimer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action openDoorsTimer(Handle timer)
{
    OpenDoors();
}

/* OpenDoors() - from SOAP-TF2DM - https://github.com/Lange/SOAP-TF2DM/blob/master/addons/sourcemod/scripting/soap_tf2dm.sp#L1181-L1207
 *
 * Initially forces all doors open and keeps them unlocked even when they close.
 * -------------------------------------------------------------------------- */
void OpenDoors()
{
    int ent = -1;
    // search for all func doors
    while ((ent = FindEntityByClassname(ent, "func_door")) != -1)
    {
        if (IsValidEntity(ent))
        {
            AcceptEntityInput(ent, "unlock", -1);
            AcceptEntityInput(ent, "open", -1);
            FixNearbyDoorRelatedThings(ent);
        }
    }
    // reset ent
    ent = -1;
    // search for all other possible doors
    while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1)
    {
        if (IsValidEntity(ent))
        {
            char tName[64];
            char modelName[64];
            GetEntPropString(ent, Prop_Data, "m_iName", tName, sizeof(tName));
            GetEntPropString(ent, Prop_Data, "m_ModelName", modelName, sizeof(modelName));
            if  (
                    StrContains(tName, "door", false)         != -1
                     || StrContains(tName, "gate", false)     != -1
                     || StrContains(modelName, "door", false) != -1
                     || StrContains(modelName, "gate", false) != -1
                )
            {
                AcceptEntityInput(ent, "unlock", -1);
                AcceptEntityInput(ent, "open", -1);
                FixNearbyDoorRelatedThings(ent);
            }
        }
    }
}

// remove any func_brushes that could be blockbullets and open area portals near those func_brushes
void FixNearbyDoorRelatedThings(int ent)
{
    float doorLocation[3];
    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", doorLocation);
    char brushName[32];
    float brushLocation[3];
    int iterEnt = -1;
    while ((iterEnt = FindEntityByClassname(iterEnt, "func_brush")) != -1)
    {
        if (IsValidEntity(iterEnt))
        {
            GetEntPropVector(iterEnt, Prop_Send, "m_vecOrigin", brushLocation);
            if (GetVectorDistance(doorLocation, brushLocation) < 50.0)
            {
                GetEntPropString(iterEnt, Prop_Data, "m_iName", brushName, sizeof(brushName));
                if ((StrContains(brushName, "bullet", false) != -1) || (StrContains(brushName, "door", false) != -1))
                {
                    AcceptEntityInput(iterEnt, "kill");
                }
            }
        }
    }
    // iterate thru all area portals near a door and open them
    iterEnt = -1;
    while ((iterEnt = FindEntityByClassname(iterEnt, "func_areaportal")) != -1)
    {
        if (IsValidEntity(iterEnt))
        {
            GetEntPropVector(iterEnt, Prop_Send, "m_vecOrigin", brushLocation);
            if (GetVectorDistance(doorLocation, brushLocation) < 10.0)
            {
                AcceptEntityInput(iterEnt, "Open");
            }
        }
    }
}
