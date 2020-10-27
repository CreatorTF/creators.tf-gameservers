/**
* Runs EquipWearable SDKCall.
*
* @param entity				entity.
* @param model				Model to set entity to.
*
* @return					Nothing.
*/
native void CEModels_SetModelIndex(int entity, char[] model);

/**
* Creates Wearable entity. 
*
* @param client				Client.
* @param model				Model of the wearable.
* @param vm					Is this wearable a ViewModel?
* @param quality			Quality of the wearable
*
* @return					Nothing.
*/
native int CEModels_CreateWearable(int client, char[] model, bool vm, int quality);

/**
* Creates Tied Wearable entity. 
*
* @param client				Client.
* @param model				Model of the wearable.
* @param vm					Is this wearable a ViewModel?
* @param weapon				Weapon to tie wear to.
*
* @return					Nothing.
*/
native int CEModels_CreateTiedWearable(int client, char[] model, bool vm, int weapon);

/**
* Runs EquipWearable SDKCall.
*
* @param client				Client.
* @param entity			Wearable.
*
* @return					Nothing.
*/
native void TF2_EquipWearable(int client, int entity);

/**
* Sets all tied wearables' props to float value;
*
* @param weapon				weapon.
* @param type				type.
* @param type				type.
* @param propname			propname.
* @param value				value.
* @param children			children.
*
* @return					Nothing.
*/
native void CEModels_WearSetEntPropFloatOfWeapon(int weapon, PropType type, char[] propname, float value, int children = 0);

/**
* Clears all wearables of client;
*
* @param client				weapon.
*
* @return					Nothing.
*/
native void CEModels_KillCustomAttachments(int client);