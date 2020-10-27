#define MAX_STRANGE_PARTS 10

enum struct CEStrangePart
{
    int m_iIndex;
    CELogicEvents m_nEvents[MAX_HOOKS];
}

native KeyValues CEEaters_FindLevelDataByName(const char[] name);
native KeyValues CEEaters_GetItemLevelData(int index);
native void CEEaters_GetAttributeByPartIndex(int part, char[] name, int size);
