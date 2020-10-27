#define MAX_HOOKS 10

enum CELogicEvents
{
    LOGIC_NULL,
	LOGIC_KILL,
	LOGIC_ASSIST,
	LOGIC_KILL_OR_ASSIST,

	// Kill Events
	LOGIC_KILL_DOMINATE,
	LOGIC_KILL_REVENGE,

	LOGIC_KILL_CLASS_SCOUT,
	LOGIC_KILL_CLASS_SOLDIER,
	LOGIC_KILL_CLASS_PYRO,
	LOGIC_KILL_CLASS_DEMOMAN,
	LOGIC_KILL_CLASS_HEAVY,
	LOGIC_KILL_CLASS_ENGINEER,
	LOGIC_KILL_CLASS_MEDIC,
	LOGIC_KILL_CLASS_SNIPER,
	LOGIC_KILL_CLASS_SPY,

	LOGIC_KILL_HEADSHOT,
	LOGIC_KILL_BACKSTAB,

	LOGIC_KILL_AIRBORNE_ENEMY,
	LOGIC_KILL_WHILE_AIRBORNE,

	LOGIC_KILL_OBJECT,
	LOGIC_KILL_WITH_OBJECT,

	LOGIC_KILL_WITH_REFLECT,
	LOGIC_KILL_WHILE_UBERCHARGED,
    LOGIC_KILL_CLOAKED_SPY,
    LOGIC_KILL_UBERED_MEDIC,
    LOGIC_KILL_STREAK_ENDED,
    LOGIC_KILL_NON_CRITICAL,
    LOGIC_KILL_CRITICAL,
    LOGIC_KILL_MINI_CRITICAL,
    LOGIC_KILL_GIB,

    LOGIC_KILL_TAUNTING,
    LOGIC_KILL_WHILE_TAUNTING,

    LOGIC_KILL_ENVIRONMENTAL,

    // Healing
    LOGIC_HEALING_TEAMMATES,

	// Assist
	LOGIC_ASSIST_WHILE_UBERCHARGED,

	// CP / PL Events
	LOGIC_CAPTURE_POINT,
	LOGIC_DEFEND_POINT,

	// CTF Events
	LOGIC_CAPTURE_FLAG,
	LOGIC_DEFEND_FLAG,

	// Payload Events
	LOGIC_PAYLOAD_PUSH,
	LOGIC_PAYLOAD_PROGRESS,

	// General Objectives Events
	LOGIC_OBJECTIVE_DEFEND,
	LOGIC_OBJECTIVE_CAPTURE,
	LOGIC_OBJECTIVE_CAPTURE_OR_DEFEND,

	// Scoreboard Events
	LOGIC_MVP,
	LOGIC_SCORE_POINTS,

	// Damage Events
	LOGIC_TAKE_DAMAGE,
	LOGIC_DEAL_DAMAGE,

	// Halloween Events
	LOGIC_ESCAPE_LOOT_ISLAND,
	LOGIC_ESCAPE_HELL,
	LOGIC_ESCAPE_UNDERWORLD,
	LOGIC_COLLECT_SOULS,
	LOGIC_COLLECT_DUCK,
	LOGIC_COLLECT_CRIT_PUMPKIN,
	LOGIC_BUMPER_CARS_REVIVE,
	LOGIC_BUMPER_CARS_KILL,
	LOGIC_KILL_WITH_CRIT_PUMPKIN,
	LOGIC_KILL_IN_HELL,
	LOGIC_KILL_IN_PURGATORY,
	LOGIC_KILL_IN_LOOT_ISLAND,

    // Misc Events
    LOGIC_HIT_PLAYER,
    LOGIC_REFLECT,

    // Merasmus
    LOGIC_MERASMUS_STUN,
    LOGIC_MERASMUS_KILL,
    LOGIC_MERASMUS_PROP_FOUND,

    // Eyeball
    LOGIC_EYEBALL_STUN,
    LOGIC_EYEBALL_KILL,

    // Eyeball
    LOGIC_HHH_KILL,
    LOGIC_HHH_TARGET_IT,
    LOGIC_SKELETON_KILL,

    LOGIC_DEATH,
    LOGIC_SPAWN,
    LOGIC_KILL_OBJECT_SENTRY,
    LOGIC_KILL_OBJECT_DISPENSER,
    LOGIC_KILL_OBJECT_TELEPORTER,
    LOGIC_KILL_OBJECT_SAPPER,
    LOGIC_WEAPON_SWITCH,
    LOGIC_ASSIST_WHILE_UBERCHARGED_OBJECT_SENTRY,
    LOGIC_ASSIST_WHILE_UBERCHARGED_OBJECT_DISPENSER,
    LOGIC_ASSIST_WHILE_UBERCHARGED_OBJECT_TELEPORTER,
    LOGIC_OBJECT_DESTROYED_SENTRY,
    LOGIC_OBJECT_DESTROYED_DISPENSER,
    LOGIC_OBJECT_DESTROYED_TELEPORTER,
    LOGIC_WIN,

    LOGIC_KILL_STUNNED,
    LOGIC_KILL_PUMPKIN_BOMB,
    LOGIC_KILL_MAGIC,
    LOGIC_PICKUP_FLAG,
    LOGIC_KILL_LEADER
}


/**
* Called when an event is fired for a participating user
*
* @param event 			Event itself.
* @param isCustom 		Is this event custom? (Treat as KV or as Event)
* @param client 		Client who refers to this event.
*
* @return					Does nothing.
*/
forward void CEEvents_OnBroadcast(Handle event, bool isCustom, int client);

native CELogicEvents CEEvents_GetEventIndex(const char[] name);

native int CEEvents_SendEventToClient(int client, CELogicEvents event, int add, int unique);

native int CEEvents_LastUsedWeapon(int client);

/**
* Called when an event is fired
*
* @param event 			Event itself.
* @param isCustom 		Is this event custom? (Treat as KV or as Event)
*
* @return					Does nothing.
*/
forward void CEEvents_OnBroadcastToAll(Handle event, bool isCustom);

/**
* Called when an event is fired
*
* @param event 			Event itself.
* @param isCustom 		Is this event custom? (Treat as KV or as Event)
* @param client 		Client who refers to this event.
*
* @return				Does nothing.
*/
native void CEEvents_BroadcastEvent(Handle event, bool isCustom, int ...);

/**
* Called when an event is fired
*
* @param event 			Event itself.
* @param isCustom 		Is this event custom? (Treat as KV or as Event)
*
* @return					Does nothing.
*/
native void CEEvents_BroadcastEventToAll(Handle event, bool isCustom);
