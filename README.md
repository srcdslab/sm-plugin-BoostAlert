# BoostAlert

BoostAlert is a SourceMod plugin for ZombieReloaded servers that detects CT -> ZM boost patterns and knife follow-up interactions, then notifies admins with:

- concise chat messages (localized)
- detailed console lines (localized)

## Features

- Detects high-impact boost hits from CT to T/ZM (shotguns/snipers).
- Detects knife hits from CT to T/ZM with configurable minimum damage.
- Detects follow-up infection/kill events after a recent knife hit.
- Detects boost-assisted infection chains in ZR.
- Sends notifications only to admins (or SourceTV).
- Logs relevant events to SourceMod logs.
- Exposes forwards for integrations with other plugins.
- Includes multilingual phrases: English, French, Spanish, Russian, Simplified Chinese.

Optional:

- `knifemode` (if present, alerts can be suppressed via cvar)

## Installation

1. Compile `addons/sourcemod/scripting/BoostAlert.sp` or download latest release.
2. Copy `BoostAlert.smx` to `addons/sourcemod/plugins/`.
3. Copy `addons/sourcemod/translations/BoostAlert.phrases.txt` to your server.
4. Restart map/server (or reload plugin).

## Configuration (ConVars)

### Knife

- `sm_knifenotifytime` (default: `5`)
  - Time window (seconds) where a recently knifed zombie is tracked for follow-up events.
- `sm_knifemod_blocked` (default: `1`)
  - If KnifeMode is loaded: `1` blocks alerts, `0` allows alerts.
- `sm_knifemin_damage` (default: `15`)
  - Minimum knife damage to trigger a knife alert.

### Boost

- `sm_boostalert_hitgroup` (default: `1`)
  - `0` = any hitgroup, `1` = head-only (event hitgroup match).
- `sm_boostalert_spam` (default: `3`)
  - Anti-spam delay before another boost warning can be sent for the same target.
- `sm_boostalert_delay` (default: `15`)
  - Time window where a boosted target can still trigger follow-up infection warning.
- `sm_boostalert_min_damage` (default: `80`)
  - Minimum damage to trigger boost warning.

### Auth ID

- `sm_boostalert_authid` (default: `1`)
  - Auth ID type in detailed output:
  - `0` = Engine
  - `1` = Steam2
  - `2` = Steam3
  - `3` = Steam64

## Notifications

### Chat

Chat notifications are compact and intended for quick admin awareness.

Examples:

- `[BA] Wyatt boosted Yahn (awp, -84 HP)`
- `[BA] Wyatt infected Yahn (Recently knifed by Rushaway)`

### Console

Console notifications are detailed and include userid/auth details.

Examples:

- `[BA] Wyatt (#1390|U:1:...) boosted Yahn (#1391|U:1:...) with awp (-84 HP)`
- `[BA] Wyatt (#...) infected Yahn (#...) (Recently knifed by Rushaway (#...))`

## Forwards

BoostAlert exposes two global forwards:

```pawn
BoostAlert_OnBoost(int attacker, int victim, int damage, const char[] weapon)
BoostAlert_OnBoostedKill(int attacker, int victim, int initialAttacker, int damage, const char[] weapon)
```

## Translation

Translation file:

- `addons/sourcemod/translations/BoostAlert.phrases.txt`

Supported language keys:

- `en`
- `fr`
- `es`
- `ru`
- `chi` (Simplified Chinese)

## Notes

- Boost detection weapon list is currently: `m3`, `xm1014`, `awp`, `scout`, `sg550`, `g3sg1`.
- Admin notification target is: SourceTV or users with `Admin_Generic`.
- config is Auto generated.
