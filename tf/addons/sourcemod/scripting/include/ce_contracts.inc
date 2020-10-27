#define MAX_OBJECTIVES 10

#define QUEST_OBJECTIVE_PRIMARY 0
#define QUEST_INDEX_ACTIVE -1

enum CEQuestActions
{
	ACTION_SINGLEFIRE,
	ACTION_INCREMENT,
	ACTION_RESET,
	ACTION_SUBSTRACT,
	ACTION_SET
}

enum struct CEObjective
{
	int m_iProgress;
	int m_iCounter;

	char m_sName[64];
	int m_iEnd;
	int m_iPoints;
	int m_iLimit;

	bool m_bMarked;

	CEQuestActions m_nActions[MAX_HOOKS];
	CELogicEvents m_nEvent[MAX_HOOKS];

	int m_iCEWeaponIndex;
}

enum struct CEQuest
{
	int m_iIndex;

	ArrayList m_hObjectives;

	char m_sPostfix[5];
	char m_sName[64];

	int m_iSource;
	int m_iLastIndex;

	// Restrictions
	char m_sRestrictionMap[64];
	char m_sRestrictionStrictMap[64];
	TFClassType m_nRestrictionClass;
	int m_iCEWeaponIndex;
}

native void CEQuest_SetPlayerQuest(int client, int contract);
native bool CEQuest_CanObjectiveTrigger(int client, int objective);
native KeyValues CEQuest_FindQuestByIndex(int index);
native void CEQuest_GetObjectiveName(int client, int objective, char[] buffer, int length);
