enum struct CECampaign
{
    char m_sName[64];
    char m_sTitle[64];
    CELogicEvents m_nEvents[MAX_HOOKS];

    int m_iStartTime;
    int m_iEndTime;
}
