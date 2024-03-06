#if defined _boostalert_included
#endinput
#endif
#define _boostalert_included

/**
 * Called right after an Human knife a Zombie
 *
 * @param attacker       Attacker UserId
 * @param victim         Victim UserId
 * @param damage         Damage made by attacker to victim.
 * @param sWeapon        Weapon used to kill
 * @noreturn
 */
forward void BoostAlert_OnAlert(int attacker, int victim, int damage, char[] sWeapon);

/**
 * Called right after an Human knife a Zombie
 *
 * @param attacker          Attacker UserId
 * @param Auth_attacker     Attacker SteamID  
 * @param victim            Victim UserId
 * @param Auth_victim    	Victim SteamID  
 * @param pOldKnifer        Initial knifer UserId
 * @param Auth_OldKnifer    Initial knifer SteamID
 * @param damage            Damage made by attacker to victim.
 * @param sWeapon           Weapon used to kill
 * @noreturn
 */
forward void BoostAlert_OnKill(int attacker, char[] Auth_attacker, int victim, char[] Auth_victim, int pOldKnifer, char[] Auth_OldKnifer, int damage, char[] sWeapon);

/**
 * Called right after an Human knife a Zombie
 *
 * @param attacker          Attacker UserId
 * @param Auth_attacker     Attacker SteamID  
 * @param victim            Victim UserId
 * @param Auth_victim    	Victim SteamID
 * @param Auth_OldKnifer    Initial knifer SteamID
 * @param damage            Damage made by attacker to victim.
 * @param sWeapon           Weapon used to kill
 * @noreturn
 */
forward void BoostAlert_OnKillDisconnect(int attacker, char[] Auth_attacker, int victim, char[] Auth_victim, char[] Auth_OldKnifer, int damage, char[] sWeapon);

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