#pragma semicolon 1

#include <sourcemod>
#include <multicolors>

#pragma newdecls required

#define CHAT_PREFIX "{green}[SM]{default}"

ConVar g_CVar_BoostHitGroup, g_CVar_BoostDelay, g_CVar_Logs;
ConVar g_CVar_KnifeModMsgs;

int g_iGameTimeSpam[MAXPLAYERS + 1] = { -1, ... };
int g_iGameTimes[MAXPLAYERS+1] = { -1, ... };
int g_iOriginalAttacker[MAXPLAYERS+1] = { -1, ... };
int g_iOriginalAttackerID[MAXPLAYERS + 1] = { -1, ... };
int g_iNotificationTime[MAXPLAYERS + 1] = { -1, ... };

bool g_Plugin_ZR = false;
bool g_bPlugin_KnifeMode = false;

Handle g_hFwd_OnAlert = INVALID_HANDLE;
Handle g_hFwd_OnKill = INVALID_HANDLE;
Handle g_hFwd_OnKillDisconnect = INVALID_HANDLE;

public Plugin myinfo =
{
	name			= "Boost Notifications",
	description		= "Notify admins when a zombie gets boosted",
	author			= "Kelyan3, Obus + BotoX, maxime1907, .Rushaway",
	version			= "1.1",
	url				= ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hFwd_OnAlert = CreateGlobalForward("BoostAlert_OnAlert", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_hFwd_OnKill = CreateGlobalForward("BoostAlert_OnKill", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell, Param_String, Param_Cell, Param_String);
	g_hFwd_OnKillDisconnect = CreateGlobalForward("BoostAlert_OnKillDisconnect", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_String, Param_String, Param_Cell, Param_String);

	RegPluginLibrary("BoostAlert");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_CVar_BoostHitGroup	= CreateConVar("sm_boostalert_hitgroup", "1", "0 = Detect the whole body, 1 = Headshot only.");
	g_CVar_BoostDelay		= CreateConVar("sm_boostalert_delay", "15", "The amount of time (in seconds) after a zombie can still print the warning by infecting someone due to being boosted.", 0, true, 0.0, true, 60.0);
	g_CVar_KnifeModMsgs		= CreateConVar("sm_boostalert_knifemod", "1", "Block Alert messages when KnifeMode library is detected [0 = Print Alert | 1 = Block Alert]");
	g_CVar_Logs				= CreateConVar("sm_boostalert_log", "1", "Should we log boost? [0 = Disabled, 1 = Enabled]");

	AutoExecConfig(true);

	if (!HookEventEx("player_hurt", Event_PlayerHurt, EventHookMode_Post))
		SetFailState("Failed to hook \"player_hurt\" event.");

	if (!HookEventEx("round_start", Event_RoundStart, EventHookMode_Post))
		SetFailState("Failed to hook \"round_start\" event.");
}

public void OnAllPluginsLoaded()
{
	g_Plugin_ZR = LibraryExists("zombiereloaded");
	g_bPlugin_KnifeMode = LibraryExists("KnifeMode");
}

public void OnLibraryAdded(const char[] sName)
{
	if (strcmp(sName, "KnifeMode", false) == 0)
		g_bPlugin_KnifeMode = true;
	if (strcmp(sName, "zombiereloaded", false) == 0)
		g_Plugin_ZR = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (strcmp(sName, "KnifeMode", false) == 0)
		g_bPlugin_KnifeMode = false;
	if (strcmp(sName, "zombiereloaded", false) == 0)
		g_Plugin_ZR = false;
}

public Action Event_PlayerHurt(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (g_bPlugin_KnifeMode && g_CVar_KnifeModMsgs.BoolValue)
		return Plugin_Continue;

	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

	if (victim == 0 || attacker == 0)
		return Plugin_Continue;

	if (!IsClientInGame(victim) || !IsClientInGame(attacker) || !IsPlayerAlive(victim) || !IsPlayerAlive(attacker))
		return Plugin_Continue;

	char sWeapon[64];
	GetEventString(hEvent, "weapon", sWeapon, sizeof(sWeapon));
	int iKnife = StrContains(sWeapon, "knife", false);
	int iHitgroup = GetEventInt(hEvent, "hitgroup");

	if (victim != attacker && (g_CVar_BoostHitGroup.IntValue == iHitgroup || g_CVar_BoostHitGroup.IntValue == 0  || iKnife != -1))
	{
		char sMessage[256], sAtkSID[32], sVictSID[32], sType[32], sDetails[32];
		GetClientAuthId(attacker, AuthId_Steam2, sAtkSID, sizeof(sAtkSID), false);
		GetClientAuthId(victim, AuthId_Steam2, sVictSID, sizeof(sVictSID), false);

		int iMinDamageByWeapon = 0;
		int iDamage = GetEventInt(hEvent, "dmg_health");

		// CS:S ShotsGun
		if (strcmp(sWeapon, "m3", false) == 0 || strcmp(sWeapon, "xm1014", false) == 0)
			iMinDamageByWeapon = 40;
		// CS:GO ShotsGun
		if (strcmp(sWeapon, "nova", false) == 0 || strcmp(sWeapon, "sawedoff", false) == 0 || strcmp(sWeapon, "mag7", false) == 0)
			iMinDamageByWeapon = 240;
		// Snipers
		if (strcmp(sWeapon, "awp", false) == 0 || strcmp(sWeapon, "scout", false) == 0 || strcmp(sWeapon, "ssg08", false) == 0)
			iMinDamageByWeapon = 180;
		// Semi-Auto Snipers
		if (strcmp(sWeapon, "sg550", false) == 0 || strcmp(sWeapon, "g3sg1", false) == 0 || strcmp(sWeapon, "scar20", false) == 0)
			iMinDamageByWeapon = 120;
		// Pistols
		if (strcmp(sWeapon, "deagle", false) == 0 || strcmp(sWeapon, "revolver", false) == 0)
			iMinDamageByWeapon = 80;
		// Knife
		if (iKnife != -1)
			iMinDamageByWeapon = 1;

		// Allow knife
		if (iDamage < iMinDamageByWeapon || iMinDamageByWeapon == 0)
			return Plugin_Continue;

		int time = GetTime();
		int iVictimTeam = GetClientTeam(victim);
		int iAttackerTeam = GetClientTeam(attacker);
		int diffTime = time - 1; // Prevent spam from ShotsGun (Firing multiple bullets at once)

		g_iGameTimes[victim] = time;
		g_iOriginalAttacker[victim] = attacker;
		g_iOriginalAttackerID[victim] = GetClientUserId(attacker);
		g_iNotificationTime[victim] = (time + g_CVar_BoostDelay.IntValue);

		if (iKnife != -1)
		{
			sType = "Knifed";
			FormatEx(sDetails, sizeof(sDetails), "(-%d HP)", iDamage);
		}
		else
		{
			sType = "Boosted";
			FormatEx(sDetails, sizeof(sDetails), "(-%d HP with %s)", iDamage, sWeapon);
		}

		if ((iDamage > 35 || g_iGameTimeSpam[victim] <= diffTime) && iAttackerTeam == 3 && iVictimTeam == 2)
		{
			if (g_CVar_Logs.BoolValue)
				LogMessage("%L %s %L %s", attacker, sType, victim, sDetails);

			FormatEx(sMessage, sizeof(sMessage), "{blue}%N {default}%s {red}%N{default}. %s", attacker, sType, victim, sDetails);
			PrintMessage(sMessage);

			g_iGameTimeSpam[victim] = time;

			Forward_OnAlert(attacker, victim, iDamage, sWeapon);
		}
		else if (iAttackerTeam == 2 && iVictimTeam == 3 && (g_iNotificationTime[attacker] >= time || iDamage > 35))
		{
			int iInitialAttacker = GetClientOfUserId(g_iOriginalAttackerID[attacker]);
			if (victim != iInitialAttacker)
			{
				char sPluginZR[32], sOriginalAttacker[32];
				sPluginZR = g_Plugin_ZR ? "infected" : "killed";
				GetClientAuthId(iInitialAttacker, AuthId_Steam2, sOriginalAttacker, sizeof(sOriginalAttacker), false);

				CPrintToChatAll("%s {red}%N {green}({lightgreen}%s{green}) {default}%s {blue}%N{default}.", CHAT_PREFIX, attacker, sAtkSID, sPluginZR, victim);

				if (iInitialAttacker != 1)
				{
					if (g_CVar_Logs.BoolValue)
						LogMessage("%L %s %L (Recently %s %s by %L)", attacker, sPluginZR, victim, sType, sDetails, iInitialAttacker);

					CPrintToChatAll("%s {red}%N {default}was recently %s %s by{blue} %N{default}.", CHAT_PREFIX, attacker, sType, sDetails, iInitialAttacker);
					Forward_OnKill(attacker, sAtkSID, victim, sVictSID, iInitialAttacker, sOriginalAttacker, iDamage, sWeapon);
				}
				else
				{
					if (g_CVar_Logs.BoolValue)
						LogMessage("%L %s %L (Recently %s %s by a disconnected player [%s])", attacker, sPluginZR, victim, sType, sDetails, sOriginalAttacker);

					CPrintToChatAll("%s {red}%N {default}was recently %s %s by a disconnected player. {lightgreen}[%s]", CHAT_PREFIX, attacker, sType, sDetails, sOriginalAttacker);
					Forward_OnKillDisconnect(attacker, sAtkSID, victim, sVictSID, sOriginalAttacker, iDamage, sWeapon);
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	for (int i = 0; i <= MaxClients; i++)
	{
		g_iOriginalAttacker[i] = -1;
		g_iGameTimes[i] = -1;
		g_iGameTimeSpam[i] = -1;
		g_iNotificationTime[i] = -1;
		g_iOriginalAttackerID[i] = -1;
	}
	return Plugin_Continue;
}

stock bool IsValidClient(int client, bool bNobots = false)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (bNobots && IsFakeClient(client)))
		return false;

	return IsClientInGame(client);
}

stock bool IsValidAttack(int attacker, int victim)
{
	if (victim != g_iOriginalAttacker[attacker] && g_iGameTimes[attacker] >= g_iNotificationTime[attacker]
		&& IsValidClient(g_iOriginalAttacker[attacker]) && IsValidClient(attacker))
		return true;

	return false;
}

stock void PrintMessage(const char[] sMessage)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && (IsClientSourceTV(i) || GetAdminFlag(GetUserAdmin(i), Admin_Generic)))
		{
			CPrintToChat(i, "%s %s", CHAT_PREFIX, sMessage);
		}
	}
}

void Forward_OnAlert(int attacker, int victim, int damage, const char[] sWeapon)
{
	Call_StartForward(g_hFwd_OnAlert);
	Call_PushCell(attacker);
	Call_PushCell(victim);
	Call_PushCell(damage);
	Call_PushString(sWeapon);
	Call_Finish();
}

void Forward_OnKill(int attacker, char[] Auth_attacker, int victim, char[] Auth_victim, int iInitialAttacker, char[] Auth_OldKnifer, int damage, char[] sWeapon)
{
	Call_StartForward(g_hFwd_OnKill);
	Call_PushCell(attacker);
	Call_PushString(Auth_attacker);
	Call_PushCell(victim);
	Call_PushString(Auth_victim);
	Call_PushCell(iInitialAttacker);
	Call_PushString(Auth_OldKnifer);
	Call_PushCell(damage);
	Call_PushString(sWeapon);
	Call_Finish();
}

void Forward_OnKillDisconnect(int attacker, char[] Auth_attacker, int victim, char[] Auth_victim, char[] Auth_OldKnifer, int damage, char[] sWeapon)
{
	Call_StartForward(g_hFwd_OnKillDisconnect);
	Call_PushCell(attacker);
	Call_PushString(Auth_attacker);
	Call_PushCell(victim);
	Call_PushString(Auth_victim);
	Call_PushString(Auth_OldKnifer);
	Call_PushCell(damage);
	Call_PushString(sWeapon);
	Call_Finish();
}