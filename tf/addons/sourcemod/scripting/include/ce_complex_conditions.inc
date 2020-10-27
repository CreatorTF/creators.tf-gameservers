enum struct CELogicVariable {
	char m_sName[64];
	char m_sValue[128];
}

/**
* Checks if an event is meeting the requirements defined in logic.
*
* @param event 			Event itself.
* @param isCustom 		Is this event custom? (Treat as KV or as Event)
* @param client 		Client who refers to this event.
*
* @return					Does nothing.
*/
native bool CECCS_ParseLogic(int client, KeyValues logic, Handle hEvent, ArrayList hVars, bool isKV);

/**
* Transforms a KeyValues into an ArrayList of CELogicVariable structs.
*
* @param kv 			KeyValues itself.
*
* @return				ArrayList of CELogicVariable.
*/
native ArrayList CECCS_VariablesKeyValuesToArrayList(KeyValues kv);

/**
* Returns the name of the event.
*
* @param event 			Event handle.
* @param buffer 		Buffer to store the name into.
* @param size 			Size of the buffer.
* @param isKV 			Is KeyValues or not.
*
* @return				Nothing.
*/
native void CECCS_GetEventName(Handle event, char[] buffer, int size, bool isKV);

/**
* Returns the name of the event.
*
* @param event 			Event handle.
*
* @return				Nothing.
*/
native int CECCS_GetEventInteger(Handle event, char[] name, bool isKV);

native KeyValues CECCS_FindLogicPrefabByName(const char[] name);