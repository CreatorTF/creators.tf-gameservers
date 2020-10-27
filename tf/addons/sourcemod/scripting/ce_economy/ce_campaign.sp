#pragma semicolon 1
#pragma newdecls required

#include <ce_util>
#include <ce_core>
#include <ce_events>
#include <ce_campaign>
#include <ce_complex_conditions>
#include <ce_coordinator>

ArrayList m_hCampaigns;

public Plugin myinfo =
{
	name = "Creators.TF Economy - Campaign Manager",
	author = "Creators.TF Team",
	description = "Creators.TF Campaign Manager",
	version = "1.00",
	url = "https://creators.tf"
}

ConVar ce_campaign_force_activate;

public void OnPluginStart()
{
	ce_campaign_force_activate = CreateConVar("ce_campaign_force_activate", "", "Force activates a campaign, ignores the time limit.", FCVAR_PROTECTED);
	HookConVarChange(ce_campaign_force_activate, ce_campaign_force_activate__CHANGED);
}

public void OnAllPluginsLoaded()
{
	ParseCampaignList();
}

public void ce_campaign_force_activate__CHANGED(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ParseCampaignList();
}

public void ParseCampaignList()
{
	if (UTIL_IsValidHandle(m_hCampaigns))delete m_hCampaigns;

	KeyValues hConf = CE_GetEconomyConfig();
	if (!UTIL_IsValidHandle(hConf))return;

	if(hConf.JumpToKey("Contracker/Campaigns/0", false))
	{
		do {
			char sTime[128], sTitle[64], sCvarValue[64];
			hConf.GetString("title", sTitle, sizeof(sTitle));
			ce_campaign_force_activate.GetString(sCvarValue, sizeof(sCvarValue));

			if(!StrEqual(sTitle, sCvarValue))
			{
				hConf.GetString("start_time", sTime, sizeof(sTime));
				int iStartTime = TimeFromString("YYYY-MM-DD hh:mm:ss", sTime);

				hConf.GetString("end_time", sTime, sizeof(sTime));
				int iEndTime = TimeFromString("YYYY-MM-DD hh:mm:ss", sTime);

				if (!(GetTime() > iStartTime && GetTime() < iEndTime))continue;
			}
			AddCampaignToTrackList(hConf);

		} while (hConf.GotoNextKey());
	}
	delete hConf;
}

public void AddCampaignToTrackList(KeyValues hConf)
{
	if(!UTIL_IsValidHandle(m_hCampaigns))
	{
		m_hCampaigns = new ArrayList(sizeof(CECampaign));
	}

	CECampaign hCampaign;
	hConf.GetString("name", hCampaign.m_sName, 64);
	hConf.GetString("title", hCampaign.m_sTitle, 64);

	char sTime[64];
	hConf.GetString("start_time", sTime, sizeof(sTime));
	hCampaign.m_iStartTime = TimeFromString("YYYY-MM-DD hh:mm:ss", sTime);

	hConf.GetString("end_time", sTime, sizeof(sTime));
	hCampaign.m_iEndTime = TimeFromString("YYYY-MM-DD hh:mm:ss", sTime);

	for (int j = 0; j < MAX_HOOKS; j++)
	{
		char sKey[32];
		Format(sKey, sizeof(sKey), "hooks/%d/event", j);

		char sEvent[32];
		hConf.GetString(sKey, sEvent, sizeof(sEvent));
		if (StrEqual(sEvent, ""))continue;

		CELogicEvents nEvent = CEEvents_GetEventIndex(sEvent);
		if(nEvent > LOGIC_NULL)
		{
			hCampaign.m_nEvents[j] = nEvent;
		}
	}

	m_hCampaigns.PushArray(hCampaign);
}

public void FlushCampaignTrackList()
{
	if (!UTIL_IsValidHandle(m_hCampaigns))return;
	for (int i = 0; i < m_hCampaigns.Length; i++)
	{
		CECampaign hCampaign;
		m_hCampaigns.GetArray(i, hCampaign);

		m_hCampaigns.Erase(i);
		i--;
	}
}

public void CEEvents_OnSendEvent(int client, CELogicEvents event, int add)
{
	if (!UTIL_IsValidHandle(m_hCampaigns))return;

	for (int i = 0; i < m_hCampaigns.Length; i++)
	{
		CECampaign hCampaign;
		m_hCampaigns.GetArray(i, hCampaign);

		for (int j = 0; j < MAX_HOOKS; j++)
		{
			if (hCampaign.m_nEvents[j] != event)continue;
			CESC_SendCampaignProgressMessage(client, add, hCampaign.m_sTitle);
		}
	}
}

public void CESC_SendCampaignProgressMessage(int client, int points, const char[] title)
{
	if (!IsClientReady(client))return;

	KeyValues hMessage = new KeyValues("content");

	char sSteamID[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID, sizeof(sSteamID));

	hMessage.SetString("steamid", sSteamID);
	hMessage.SetString("campaign", title);
	hMessage.SetNum("increment_value", points);

	CESC_SendMessage(hMessage, "campaign_increment");
	delete hMessage;
}
