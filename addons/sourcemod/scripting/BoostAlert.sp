#pragma semicolon 1
#pragma newdecls required

#include <cstrike>
#include <sdktools>
#include <sourcemod>
#include <multicolors>
#include <zombiereloaded>

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
	version			= "2.1.1",
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

	char sMessage[1024];
	Format(sMessage, sizeof(sMessage), "%L Knifed %L", attacker, victim);
	LogMessage(sMessage);

	NotifyAdmins("{green}[SM] {blue}%N {default}knifed {red}%N{default}. (-%d HP)", attacker, victim, damage);
	Forward_OnBoost(attacker, victim, damage, "knife");
}

void HandleKnifedZombieInfection(int victim, int attacker, int damage)
{
	if (g_iNotificationTime[attacker] > GetTime())
	{
		int pOldKnifer = GetClientOfUserId(g_iClientUserId[attacker]);
		if (victim != pOldKnifer)
		{
			AuthIdType authType = view_as<AuthIdType>(GetConVarInt(g_cvAuthID));

			char sMessage[1024], sAtkSID[64], OldKniferSteamID[64];
			GetClientAuthId(attacker, authType, sAtkSID, sizeof(sAtkSID));
			GetClientAuthId(pOldKnifer, authType, OldKniferSteamID, sizeof(OldKniferSteamID));

			if (authType == AuthId_Steam3)
			{
				ReplaceString(sAtkSID, sizeof(sAtkSID), "[", "");
				ReplaceString(sAtkSID, sizeof(sAtkSID), "]", "");
				ReplaceString(OldKniferSteamID, sizeof(OldKniferSteamID), "[", "");
				ReplaceString(OldKniferSteamID, sizeof(OldKniferSteamID), "]", "");
			}

			Format(sAtkSID, sizeof(sAtkSID), "#%d|%s", GetClientUserId(attacker), sAtkSID);

			if (pOldKnifer != -1)
			{
				char sAtkAttackerName[MAX_NAME_LENGTH];
				GetClientName(pOldKnifer, sAtkAttackerName, sizeof(sAtkAttackerName));

				Format(sMessage, sizeof(sMessage), "%L %s %L (Recently knifed by %L)", attacker, g_Plugin_ZR ? "infected" : "killed", victim, pOldKnifer);
				LogMessage(sMessage);

				CPrintToChatAll("{green}[SM]{red} %N ({lightgreen}%s{red}){default} %s{blue} %N{default}.", attacker, sAtkSID, g_Plugin_ZR ? "infected" : "killed", victim);
				CPrintToChatAll("{green}[SM]{default} Knifed by{blue} %s{default}.", sAtkAttackerName);

				Forward_OnBoostedKill(attacker, victim, pOldKnifer, damage, "knife");
			}
			else
			{
				Format(sMessage, sizeof(sMessage), "%L %s %L (Recently knifed by a disconnected player %s)", attacker, g_Plugin_ZR ? "infected" : "killed", victim, OldKniferSteamID);
				LogMessage(sMessage);

				CPrintToChatAll("{green}[SM]{red} %N ({lightgreen}%s{red}){green} %s{blue} %N{default}.", attacker, sAtkSID, g_Plugin_ZR ? "infected" : "killed", victim);
				CPrintToChatAll("{green}[SM]{default} Knifed by a disconnected player. {lightgreen}%s", OldKniferSteamID);

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
		NotifyAdmins("{green}[SM] {blue}%N {default}boosted {red}%N{default}. ({olive}%s{default})", attacker, victim, weapon);

		char sMessage[1024];
		Format(sMessage, sizeof(sMessage), "%L Boosted %L (%s)", attacker, victim, weapon);
		LogMessage(sMessage);

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
	if (client != g_iAttackerIDs[attacker] && attacker == g_iDamagedIDs[attacker] 
		&& g_iGameTimes[attacker] >= (time - g_cvBoostDelay.IntValue))
	{
		if (IsValidClient(g_iAttackerIDs[attacker]) && IsValidClient(g_iDamagedIDs[attacker]))
		{
			AuthIdType authType = view_as<AuthIdType>(GetConVarInt(g_cvAuthID));

			char sAttackerSteamID[64], sBoosterSteamID[64];
			GetClientAuthId(g_iDamagedIDs[attacker], authType, sAttackerSteamID, sizeof(sAttackerSteamID));
			GetClientAuthId(g_iAttackerIDs[attacker], authType, sBoosterSteamID, sizeof(sBoosterSteamID));

			if (authType == AuthId_Steam3)
			{
				ReplaceString(sAttackerSteamID, sizeof(sAttackerSteamID), "[", "");
				ReplaceString(sAttackerSteamID, sizeof(sAttackerSteamID), "]", "");
				ReplaceString(sBoosterSteamID, sizeof(sBoosterSteamID), "[", "");
				ReplaceString(sBoosterSteamID, sizeof(sBoosterSteamID), "]", "");
			}

			Format(sAttackerSteamID, sizeof(sAttackerSteamID), "#%d|%s", GetClientUserId(g_iDamagedIDs[attacker]), sAttackerSteamID);
			Format(sBoosterSteamID, sizeof(sBoosterSteamID), "#%d|%s", GetClientUserId(g_iAttackerIDs[attacker]), sBoosterSteamID);

			NotifyAdmins("{green}[SM] {red}%N ({lightgreen}%s{red}) {default}infected {red}%N{default}, boosted by {blue}%N ({lightgreen}%s{blue}){default}.",
				g_iDamagedIDs[attacker], sAttackerSteamID, client, g_iAttackerIDs[attacker], sBoosterSteamID);

			Forward_OnBoostedKill(g_iDamagedIDs[attacker], client, g_iAttackerIDs[attacker], 1, "zombie_claws_of_death");
		}
	}
}

void NotifyAdmins(const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && (IsClientSourceTV(i) || GetAdminFlag(GetUserAdmin(i), Admin_Generic)))
		{
			CPrintToChat(i, buffer);
		}
	}
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
