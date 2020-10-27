#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>

public Plugin myinfo =
{
    name             =  "StuckSpec",
    author           =  "steph&nie",
    description      =  "Free players stuck in spec without having to have them retry to the server!",
    version          =  "0.0.2",
    url              =  "https://steph.anie.dev/"
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_stuckspec", StuckSpecCalled, "Put clients on a team if stuck in spectator!");
    RegConsoleCmd("sm_stuck", StuckSpecCalled, "Put clients on a team if stuck in spectator!");
}

public Action StuckSpecCalled(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "This command cannot be run by the console!");
        return;
    }

    if (TF2_GetClientTeam(client) != TFTeam_Unassigned && TF2_GetClientTeam(client) != TFTeam_Spectator)
    {
        ReplyToCommand(client, "You are not in spectator!");
        return;
    }

    int redPlayers;
    int bluPlayers;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            TFTeam iTeam = TF2_GetClientTeam(i);
            if (iTeam == TFTeam_Red)
            {
                redPlayers++;
            }
            else if (iTeam == TFTeam_Blue )
            {
                bluPlayers++;
            }
        }
    }

    if (TF2_GetPlayerClass(client) == TFClass_Unknown)
    {
        TF2_SetPlayerClass(client, TFClass_Scout, true, true);
        ReplyToCommand(client, "Your most recent player class was unknown. Defaulting to Scout to avoid bugs!");
    }

    if (redPlayers > bluPlayers)
    {
        TF2_ChangeClientTeam(client, TFTeam_Blue);
    }
    else if (redPlayers < bluPlayers)
    {
        TF2_ChangeClientTeam(client, TFTeam_Red);
    }
    // flip a coin
    else
    {
        if (GetURandomFloat() > 0.5)
        {
            TF2_ChangeClientTeam(client, TFTeam_Red);
        }
        else
        {
            TF2_ChangeClientTeam(client, TFTeam_Blue);
        }
    }

    ReplyToCommand(client, "You have been freed from spectator!");
}

stock bool IsValidClient(int client)
{
    return ((0 < client <= MaxClients) && IsClientInGame(client) && !IsFakeClient(client));
}