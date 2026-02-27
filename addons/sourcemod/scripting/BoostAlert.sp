#pragma semicolon 1
#pragma newdecls required

#include <cstrike>
#include <sdktools>
#include <sourcemod>
#include <multicolors>
#include <zombiereloaded>

#define BA_TAG "[BA]"

bool g_Plugin_ZR = false;
bool g_bPlugin_KnifeMode = false;

#undef REQUIRE_PLUGIN
#tryinclude <knifemode>
#define REQUIRE_PLUGIN

ConVar g_cvNotificationTime, g_cvKnifeModMsgs, g_cvMinKnifeDamage;
ConVar g_cvBoostHitGroup, g_cvBoostSpam, g_cvBoostDelay;
ConVar g_cvMinimumDamage;
ConVar g_cvAuthID;

int g_iNotificationTime[MAXPLAYERS + 1];
int g_iClientUserId[MAXPLAYERS + 1];
int g_iGameTimeSpam[MAXPLAYERS + 1] = { -1, ... };
int g_iGameTimes[MAXPLAYERS + 1] = { -1, ... };
int g_iDamagedIDs[MAXPLAYERS + 1] = { -1, ... };
int g_iAttackerIDs[MAXPLAYERS + 1] = { -1, ... };

Handle g_hFwd_OnBoost = INVALID_HANDLE;
Handle g_hFwd_OnBoostedKill = INVALID_HANDLE;

public Plugin myinfo =
{
	name			= "Boost Notifications",
	description		= "Notify admins when a zombie gets boosted",
	author			= "Kelyan3, Obus + BotoX, maxime1907, .Rushaway",
	version			= "3.0.0",
	url				= "https://github.com/srcdslab/sm-plugin-BoostAlert"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hFwd_OnBoost = CreateGlobalForward("BoostAlert_OnBoost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_hFwd_OnBoostedKill = CreateGlobalForward("BoostAlert_OnBoostedKill", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);

	RegPluginLibrary("BoostAlert");
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("BoostAlert.phrases");

	// Knife Alert
	g_cvNotificationTime = CreateConVar("sm_knifenotifytime", "5", "Time before a knifed zombie is considered \"not knifed\"", 0, true, 0.0, true, 60.0);
	g_cvKnifeModMsgs = CreateConVar("sm_knifemod_blocked", "1", "Block Alert messages when KnifeMode library is detected [0 = Print Alert | 1 = Block Alert]");
	g_cvMinKnifeDamage = CreateConVar("sm_knifemin_damage", "15", "Minimum damage needed for knife warning.");

	// Boost Alert
	g_cvBoostHitGroup = CreateConVar("sm_boostalert_hitgroup", "1", "0 = Detect the whole body, 1 = Headshot only.");
	g_cvBoostSpam = CreateConVar("sm_boostalert_spam", "3", "Time (seconds) before a boost warning can be sent again.");
	g_cvBoostDelay = CreateConVar("sm_boostalert_delay", "15", "Time (seconds) a zombie can still trigger warning by infecting after boost.");
	g_cvMinimumDamage = CreateConVar("sm_boostalert_min_damage", "80", "Minimum damage needed for boost warning.");

	// SteamID Format
	g_cvAuthID = CreateConVar("sm_boostalert_authid", "1", "AuthID type used [0 = Engine, 1 = Steam2, 2 = Steam3, 3 = Steam64]", FCVAR_NONE, true, 0.0, true, 3.0);

	// Hook Events
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

	AutoExecConfig(true);
}

public void OnAllPluginsLoaded()
{
	g_Plugin_ZR = LibraryExists("zombiereloaded");
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "zombiereloaded"))
		g_Plugin_ZR = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "zombiereloaded"))
		g_Plugin_ZR = false;
}

public Action Event_PlayerHurt(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (!IsValidClient(victim))
		return Plugin_Continue;

	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if (!IsValidClient(attacker) || victim == attacker)
		return Plugin_Continue;

	char sWepName[64];
	GetEventString(hEvent, "weapon", sWepName, sizeof(sWepName));

	int iDamage = GetEventInt(hEvent, "dmg_health");
	int iVictimTeam = GetClientTeam(victim);
	int iAttackerTeam = GetClientTeam(attacker);

	if (iVictimTeam == CS_TEAM_T && iAttackerTeam == CS_TEAM_CT)
	{
		if (g_bPlugin_KnifeMode && g_cvKnifeModMsgs.IntValue > 0)
			return Plugin_Continue;

		if (StrEqual(sWepName, "knife") && iDamage >= g_cvMinKnifeDamage.IntValue)
			HandleKnifeAlert(victim, attacker, iDamage);

		int hitgroup = GetEventInt(hEvent, "hitgroup");
		bool isValidHitgroup = (g_cvBoostHitGroup.IntValue == 0) || (g_cvBoostHitGroup.IntValue != 0 && g_cvBoostHitGroup.IntValue == hitgroup);

		if (iDamage >= g_cvMinimumDamage.IntValue && isValidHitgroup && IsBoostWeapon(sWepName))
		{
			HandleBoostAlert(victim, attacker, sWepName, iDamage);
		}

		return Plugin_Continue;
	}

	if (iVictimTeam == CS_TEAM_CT && iAttackerTeam == CS_TEAM_T)
	{
		HandleKnifedZombieInfection(victim, attacker, iDamage);
		return Plugin_Continue;
	}

	
	return Plugin_Continue;
}

bool IsBoostWeapon(const char[] weapon)
{
	return (StrEqual(weapon, "m3") || StrEqual(weapon, "xm1014") // CS:S Shotguns
		|| StrEqual(weapon, "awp") || StrEqual(weapon, "scout") // Snipers
		|| StrEqual(weapon, "sg550") || StrEqual(weapon, "g3sg1")); // Semi-Auto Snipers
}

void HandleKnifeAlert(int victim, int attacker, int damage)
{
	g_iClientUserId[victim] = GetClientUserId(attacker);
	g_iNotificationTime[victim] = (GetTime() + g_cvNotificationTime.IntValue);

	LogMessage("%L Knifed %L (-%d HP)", attacker, victim, damage);

	char sAttackerId[64], sVictimId[64];
	BuildUserIdString(attacker, sAttackerId, sizeof(sAttackerId));
	BuildUserIdString(victim, sVictimId, sizeof(sVictimId));
	NotifyKnifeEvent(attacker, sAttackerId, victim, sVictimId, damage);
	Forward_OnBoost(attacker, victim, damage, "knife");
}

void HandleKnifedZombieInfection(int victim, int attacker, int damage)
{
	if (g_iNotificationTime[attacker] > GetTime())
	{
		int pOldKnifer = GetClientOfUserId(g_iClientUserId[attacker]);
		if (victim != pOldKnifer)
		{
			char sAtkSID[64], sVictimId[64];
			BuildUserIdString(attacker, sAtkSID, sizeof(sAtkSID));
			BuildUserIdString(victim, sVictimId, sizeof(sVictimId));

			if (pOldKnifer != -1)
			{
				char sOldKniferId[64];
				BuildUserIdString(pOldKnifer, sOldKniferId, sizeof(sOldKniferId));
				LogMessage("%L %s %L (Recently knifed by %L)", attacker, g_Plugin_ZR ? "infected" : "killed", victim, pOldKnifer);

				NotifyKnifeFollowupConnected(attacker, sAtkSID, victim, sVictimId, pOldKnifer, sOldKniferId, g_Plugin_ZR);
				Forward_OnBoostedKill(attacker, victim, pOldKnifer, damage, "knife");
			}
			else
			{
				char sOldKniferSteamID[64];
				BuildStoredUserIdString(g_iClientUserId[attacker], sOldKniferSteamID, sizeof(sOldKniferSteamID));
				LogMessage("%L %s %L (Recently knifed by a disconnected player %s)", attacker, g_Plugin_ZR ? "infected" : "killed", victim, sOldKniferSteamID);

				NotifyKnifeFollowupDisconnected(attacker, sAtkSID, victim, sVictimId, sOldKniferSteamID, g_Plugin_ZR);
				Forward_OnBoostedKill(attacker, victim, -1, damage, "knife");
			}
		}
	}
}

void HandleBoostAlert(int victim, int attacker, const char[] weapon, int damage)
{
	int time = GetTime();
	g_iGameTimes[victim] = time;
	g_iDamagedIDs[victim] = victim;
	g_iAttackerIDs[victim] = attacker;

	if (time - g_cvBoostSpam.IntValue >= g_iGameTimeSpam[victim])
	{
		g_iGameTimeSpam[victim] = time;

		char sAttackerId[64], sVictimId[64];
		BuildUserIdString(attacker, sAttackerId, sizeof(sAttackerId));
		BuildUserIdString(victim, sVictimId, sizeof(sVictimId));
		NotifyBoostEvent(attacker, sAttackerId, victim, sVictimId, weapon, damage);

		LogMessage("%L boosted %L with %s (-%d HP)", attacker, victim, weapon, damage);
		Forward_OnBoost(attacker, victim, damage, weapon);
	}
}

public Action Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	for (int i = 0; i <= MaxClients; i++)
	{
		g_iGameTimes[i] = -1;
		g_iDamagedIDs[i] = -1;
		g_iAttackerIDs[i] = -1;
		g_iGameTimeSpam[i] = -1;
		g_iNotificationTime[i] = 0;
		g_iClientUserId[i] = 0;
	}
	return Plugin_Continue;
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if (!IsValidClient(client) || !IsValidClient(attacker))
		return;

	int time = GetTime();
	if (client != g_iAttackerIDs[attacker] && attacker == g_iDamagedIDs[attacker] && g_iGameTimes[attacker] >= (time - g_cvBoostDelay.IntValue))
	{
		if (IsValidClient(g_iAttackerIDs[attacker]) && IsValidClient(g_iDamagedIDs[attacker]))
		{
			char sAttackerSteamID[64], sBoosterSteamID[64], sVictimId[64];
			BuildUserIdString(g_iDamagedIDs[attacker], sAttackerSteamID, sizeof(sAttackerSteamID));
			BuildUserIdString(g_iAttackerIDs[attacker], sBoosterSteamID, sizeof(sBoosterSteamID));
			BuildUserIdString(client, sVictimId, sizeof(sVictimId));

			NotifyBoostInfectionEvent(g_iDamagedIDs[attacker], sAttackerSteamID, client, sVictimId, g_iAttackerIDs[attacker], sBoosterSteamID);

			Forward_OnBoostedKill(g_iDamagedIDs[attacker], client, g_iAttackerIDs[attacker], 1, "zombie_claws_of_death");
			LogMessage("%L infected (%s) infected %L (%s), boosted by %L (%s)", g_iDamagedIDs[attacker], sAttackerSteamID, client, sVictimId, g_iAttackerIDs[attacker], sBoosterSteamID);
		}
	}

}

bool ShouldNotifyClient(int client)
{
	return IsValidClient(client) && (IsClientSourceTV(client) || GetAdminFlag(GetUserAdmin(client), Admin_Generic));
}

void NotifyKnifeEvent(int attacker, const char[] attackerId, int victim, const char[] victimId, int damage)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!ShouldNotifyClient(i))
			continue;

		CPrintToChat(i, "%t", "BA_Chat_Knife", BA_TAG, attacker, victim, damage);
		PrintToConsole(i, "%T", "BA_Console_Knife", i, BA_TAG, attacker, attackerId, victim, victimId, damage);
	}
}

void NotifyBoostEvent(int attacker, const char[] attackerId, int victim, const char[] victimId, const char[] weapon, int damage)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!ShouldNotifyClient(i))
			continue;

		CPrintToChat(i, "%t", "BA_Chat_Boost", BA_TAG, attacker, victim, weapon, damage);
		PrintToConsole(i, "%T", "BA_Console_Boost", i, BA_TAG, attacker, attackerId, victim, victimId, weapon, damage);
	}
}

void NotifyKnifeFollowupConnected(int attacker, const char[] attackerId, int victim, const char[] victimId, int oldKnifer, const char[] oldKniferId, bool isInfection)
{
	char chatKey[48], consoleKey[40];
	strcopy(chatKey, sizeof(chatKey), isInfection ? "BA_Chat_Knife_Followup_Infect" : "BA_Chat_Knife_Followup_Kill");
	strcopy(consoleKey, sizeof(consoleKey), isInfection ? "BA_Console_Knife_Followup_Infect" : "BA_Console_Knife_Followup_Kill");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!ShouldNotifyClient(i))
			continue;

		CPrintToChat(i, "%t", chatKey, BA_TAG, attacker, victim, oldKnifer);
		PrintToConsole(i, "%T", consoleKey, i, BA_TAG, attacker, attackerId, victim, victimId, oldKnifer, oldKniferId);
	}
}

void NotifyKnifeFollowupDisconnected(int attacker, const char[] attackerId, int victim, const char[] victimId, const char[] oldKniferId, bool isInfection)
{
	char chatKey[61], consoleKey[47];
	strcopy(chatKey, sizeof(chatKey), isInfection ? "BA_Chat_Knife_Followup_Infect_Disconnected" : "BA_Chat_Knife_Followup_Kill_Disconnected");
	strcopy(consoleKey, sizeof(consoleKey), isInfection ? "BA_Console_Knife_Followup_Infect_Disconnected" : "BA_Console_Knife_Followup_Kill_Disconnected");

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!ShouldNotifyClient(i))
			continue;

		CPrintToChat(i, "%t", chatKey, BA_TAG, attacker, victim, oldKniferId);
		PrintToConsole(i, "%T", consoleKey, i, BA_TAG, attacker, attackerId, victim, victimId, oldKniferId);
	}
}

void NotifyBoostInfectionEvent(int attacker, const char[] attackerId, int victim, const char[] victimId, int booster, const char[] boosterId)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!ShouldNotifyClient(i))
			continue;

		CPrintToChat(i, "%t", "BA_Chat_Boost_Infection", BA_TAG, attacker, victim, booster);
		PrintToConsole(i, "%T", "BA_Console_Boost_Infection", i, BA_TAG, attacker, attackerId, victim, victimId, booster, boosterId);
	}
}

void BuildUserIdString(int client, char[] buffer, int maxlen)
{
	AuthIdType authType = view_as<AuthIdType>(g_cvAuthID.IntValue);
	GetClientAuthId(client, authType, buffer, maxlen, false);

	if (authType == AuthId_Steam3)
	{
		ReplaceString(buffer, maxlen, "[", "");
		ReplaceString(buffer, maxlen, "]", "");
	}

	Format(buffer, maxlen, "#%d|%s", GetClientUserId(client), buffer);
}

void BuildStoredUserIdString(int userId, char[] buffer, int maxlen)
{
	if (userId <= 0)
	{
		strcopy(buffer, maxlen, "unknown");
		return;
	}

	int client = GetClientOfUserId(userId);
	if (IsValidClient(client))
	{
		BuildUserIdString(client, buffer, maxlen);
		return;
	}

	Format(buffer, maxlen, "#%d|disconnected", userId);
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
		return false;

	return IsClientInGame(client);
}

void Forward_OnBoost(int attacker, int victim, int damage, const char[] sWeapon)
{
	Call_StartForward(g_hFwd_OnBoost);
	Call_PushCell(attacker);
	Call_PushCell(victim);
	Call_PushCell(damage);
	Call_PushString(sWeapon);
	Call_Finish();
}

void Forward_OnBoostedKill(int attacker, int victim, int iInitialAttacker, int damage, char[] sWeapon)
{
	Call_StartForward(g_hFwd_OnBoostedKill);
	Call_PushCell(attacker);
	Call_PushCell(victim);
	Call_PushCell(iInitialAttacker);
	Call_PushCell(damage);
	Call_PushString(sWeapon);
	Call_Finish();
}

#if defined _KnifeMode_Included
public void KnifeMode_OnToggle(bool bEnabled)
{
	g_bPlugin_KnifeMode = bEnabled;
}
#endif
