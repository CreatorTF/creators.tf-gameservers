#define MAX_ENTITY_LIMIT 2049

/**
* Changes the owner of a handle to a different plugin.
*
* @param plugin New Handle owner.
* @param handle The Handle itself.
*
* @return Does nothing.
*/
native Handle UTIL_ChangeHandleOwner(Handle plugin, Handle handle);

/**
* Checks if a Handle is valid.
*
* @param handle The Handle itself.
*
* @return True if valid.
*/
native bool UTIL_IsValidHandle(Handle handle);

/**
* Returns the smallest int out of two.
*
* @param num1 Number 1;
* @param num2 Number 2;
*
* @return Smallest int.
*/
native int MIN(int num1, int num2);


/**
* Returns the biggest int out of two.
*
* @param num1 Number 1;
* @param num2 Number 2;
*
* @return Biggest int.
*/
native int MAX(int num1, int num2);

/**
* Returns whether client is ready
*
* @param client				Client.
*
* @return					bool ready.
*/
native bool IsClientReady(int client);

/**
* Returns whether client is valid
*
* @param client				Client.
*
* @return					bool valid.
*/
native bool IsClientValid(int client);

/**
* Returns whether an entity is valid.
*
* @param client				Entity.
*
* @return					True if valid.
*/
native bool UTIL_IsEntityValid(int entity);

/**
* Gets client index from steamid
*
* @param char 				SteamID
*
* @return					Client Index.
*/
native int FindTargetBySteamID(char[] steamid);

/**
* Sets current traversal stack as root node.
*
* @param kv 				KeyValues
*
* @return					Nothing.
*/
native KeyValues KvSetRoot(KeyValues kv);

/**
* Gets the amount of subkeys in this stack.
*
* @param kv 				KeyValues
*
* @return					Count.
*/
native int KvSubKeyCount(KeyValues kv);

//-----------------------------------------------------------------------------
// Purpose: Calculate and return a time value corresponding to given sting
//			Using a format string to convert
// Input:	pchFmt -	Format string that describes how to parse the value
//						YY or YYYY is year, MM month, DD day of the month,
//						hh mm ss is hour minute second.
//						Z0000 is a time-zone offset, eg -0700.
//						Everything except YY is optional (will be considered 0 if not given)
//			pchValue -	String containing the value to covert
// Output:	RTime32
//-----------------------------------------------------------------------------
native int TimeFromString(const char[] format, const char[] value);
