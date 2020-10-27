enum struct CEEconItem
{
	int m_iIndex;
	int m_iDefinitionIndex;
	int m_iQuality;
	char m_sType[32];
}

/*
* Gets item config by name.

* @param index Index of the item.

* @return KeyValues config of the item.
*/
native KeyValues CE_FindItemConfigByDefIndex(int index);


/*
* Gets item config by name.

* @param name Name of the item.

* @return KeyValues config of the item.
*/
native KeyValues CE_FindItemConfigByItemName(const char[] name);
native int CE_FindItemIndexByItemName(const char[] name);

/*
* Parses Equip regions string to bitfield

* @return Bitfield of equip region.
*/
native int CE_ParseEquipRegionString(char[] string);

/*
* Returns if this entity is custom econ entity.

* @return True if custom.
*/
native bool CE_IsEntityCustomEcomItem(int entity);

/*
* Request to equip an item on player.

* @param client	Client to equip item on.
* @param index Index of the item.
* @param def Definition index of the item.
* @param quality Client to equip item on.
* @param attributes	Attributes of the item.

* @return True if item was equipped.
*/
native bool CE_EquipItem(int client, int index, int def, int quality, ArrayList attributes);

/*
* Returns if this entity is custom econ entity.

* @return True if custom.
*/
native int CE_GetEntityEconIndex(int entity);

/*
* Returns if this entity is custom econ entity.

* @return True if custom.
*/
native int CE_GetEntityEconDefinitionIndex(int entity);

/*
* Returns if this entity is custom econ entity.

* @return True if custom.
*/
native int CE_GetEntityEconQuality(int entity);
