#define MAX_ATTRIBUTE_NAME_LENGTH 128
#define MAX_ATTRIBUTE_VALUE_LENGTH 128

enum struct CEAttribute
{
    char        m_sName[MAX_ATTRIBUTE_NAME_LENGTH];
    bool        m_bOriginal;
    any         m_hValue;
    char        m_sValue[MAX_ATTRIBUTE_VALUE_LENGTH];
    CEValueType m_nType;
    char        m_sSubAttribute[MAX_ATTRIBUTE_NAME_LENGTH];
}

/* 
* Clears attributes of an entity.

* @param entity Entity.

* @return Nothing
*/
native void CE_ClearEntityAttributes(int entity);

/* 
* Sets entity attributes.

* @param entity Entity.
* @param hAttrs Attributes array.

* @return Nothing
*/
native void CE_SetEntityAttributes(int entity, ArrayList hAttrs);

/* 
* Gets attribute config by name.

* @param name Name of the config.

* @return KeyValues config of the attribute.
*/
native KeyValues CE_FindAttributeConfigByName(const char[] name);

/* 
* Transforms KeyValues to ArrayList of CEAttribute.

* @param kv Original KeyValues.

* @return ArrayList of CEAttribute.
*/
native ArrayList CE_KeyValuesToAttributesArray(KeyValues kv);

/* 
* Merges two attribute arrays together.

* @param arr1 First ArrayList.
* @param arr2 Second ArrayList.

* @return Merged ArrayList.
*/
native ArrayList CE_MergeAttributes(ArrayList arr1, ArrayList arr2);

/* 
* Applies all native TF2 attributes using TF2Attributes.

* @param entity Entity.
* @param attributes ArrayList of attributes.

* @return Nothing.
*/
native void CE_ApplyOriginalAttributes(int entity, ArrayList attributes);

/* 
* Returns integer value of an attribute.

* @param entity Entity.
* @param attributes Name of the attribute.

* @return Integer value.
*/
native int CE_GetAttributeInteger(int entity, const char[] name);

/* 
* Returns float value of an attribute.

* @param entity Entity.
* @param attributes Name of the attribute.

* @return Float value.
*/
native float CE_GetAttributeFloat(int entity, const char[] name);

/* 
* Sets integer value of an attribute.

* @param entity Entity.
* @param attributes Name of the attribute.
* @param value Value itself.

* @return Nothing.
*/
native void CE_SetAttributeInteger(int entity, const char[] name, int value);

/* 
* Sets float value of an attribute.

* @param entity Entity.
* @param attributes Name of the attribute.
* @param value Value itself.

* @return Nothing.
*/
native void CE_SetAttributeFloat(int entity, const char[] name, float value);