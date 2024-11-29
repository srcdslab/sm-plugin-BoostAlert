#if defined _boostalert_included
#endinput
#endif
#define _boostalert_included

/**
 * Called right after a player gets boosted
 *
 * @param attacker       Attacker UserId
 * @param victim         Victim UserId
 * @param damage         Damage made by attacker to the victim
 * @param sWeapon        Weapon used to kill
 * @noreturn
 */
forward void BoostAlert_OnBoost(int attacker, int victim, int damage, const char[] sWeapon);

/**
 * Called right after someone gets killed by a boosted player
 *
 * @param attacker          Attacker UserId
 * @param victim            Victim UserId
 * @param iInitialAttacker  Initial booster UserId
 * @param damage            Damage made by attacker to the victim
 * @param sWeapon           Weapon used to kill
 * @noreturn
 */
forward void BoostAlert_OnBoostedKill(int attacker, int victim, int iInitialAttacker, int damage, char[] sWeapon);

public SharedPlugin __pl_boostalert =
{
	name = "BoostAlert",
	file = "BoostAlert.smx",
	#if defined REQUIRE_PLUGIN
	required = 1
	#else
	required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_boostalert_SetNTVOptional()
{
    // No natives yet
}
#endif
