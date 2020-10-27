enum struct CEWeapon
{
    int m_iIndex;

    int m_iBaseIndex;
    char m_sClassName[64];

    int m_iClip;
    int m_iAmmo;

    char m_sModel[256];
}

enum struct CEWeaponWearables
{
	int m_hWorldModel;
	int m_hViewModel;
	int m_hArms;
}
