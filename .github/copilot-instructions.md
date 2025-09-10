# BoostAlert SourceMod Plugin - Coding Agent Instructions

## Repository Overview

This repository contains **BoostAlert**, a SourceMod plugin for Source engine games (like Counter-Strike: Source) that detects and alerts administrators when players get "boosted" by high-damage weapons and subsequently get kills or infections. The plugin is essential for maintaining fair gameplay by identifying potentially suspicious player interactions.

### Key Files Structure
- `addons/sourcemod/scripting/BoostAlert.sp` - Main plugin source code
- `addons/sourcemod/scripting/include/BoostAlert.inc` - Native functions and forwards for other plugins
- `sourceknight.yaml` - Build configuration for SourceKnight build tool
- `.github/workflows/ci.yml` - Automated CI/CD pipeline

## Technology Stack

- **Language**: SourcePawn (SourceMod scripting language)
- **Platform**: SourceMod 1.12+ on Source engine games
- **Build Tool**: SourceKnight (Python-based build system)
- **Compiler**: SourcePawn compiler (spcomp)

## SourcePawn Language Specifics

### Required Pragmas
Always include these at the top of `.sp` files:
```sourcepawn
#pragma semicolon 1
#pragma newdecls required
```

### Naming Conventions
- **Global variables**: Prefix with `g_` (e.g., `g_cvNotificationTime`)
- **Function names**: PascalCase (e.g., `HandleBoostAlert`)
- **Local variables**: camelCase (e.g., `iDamage`, `sWepName`)
- **ConVars**: Use descriptive names with plugin prefix (e.g., `sm_boostalert_delay`)

### Memory Management
- Use `delete` directly without null checks: `delete handle;`
- **Never** use `.Clear()` on StringMap/ArrayList (causes memory leaks)
- Instead: `delete stringMap; stringMap = new StringMap();`
- Use methodmaps for modern SourcePawn code

### Data Types & Best Practices
- Use `StringMap`/`ArrayList` instead of arrays where appropriate
- All SQL queries must be asynchronous using methodmaps
- Use transactions for complex SQL operations
- Implement proper error handling for all API calls
- Use translation files for user-facing messages

## Plugin Architecture

### Core Components
1. **Event Handlers**: `Event_PlayerHurt`, `Event_RoundStart`
2. **Game Integration**: ZombieReloaded integration via `ZR_OnClientInfected`
3. **Admin Notifications**: Filtered messaging system for admins and SourceTV
4. **Forwards System**: Native functions for plugin integration
5. **Configuration**: ConVar-based settings with auto-config generation

### Dependencies
- **SourceMod**: Core platform (1.12+ required)
- **MultiColors**: For colored chat messages
- **ZombieReloaded**: Zombie infection detection (optional)
- **KnifeMode**: Knife game mode detection (optional)

## Build System (SourceKnight)

### Build Configuration
The `sourceknight.yaml` file defines:
- Project dependencies and their sources
- Build targets and output locations
- Dependency unpacking rules

### Build Commands
```bash
# Install dependencies and build
sourceknight build

# The CI system uses:
# maxime1907/action-sourceknight@v1 with cmd: build
```

### Output Structure
Compiled plugins go to: `addons/sourcemod/plugins/`

## Code Style Guidelines

### Indentation & Formatting
- Use **tabs** with 4-space width
- Delete trailing spaces
- Consistent bracket placement

### Documentation Standards
- **Do not** add unnecessary headers or plugin descriptions
- Document all native functions in `.inc` files with:
  - Function description
  - Parameter descriptions with types
  - Return value information
- Add comments only for complex logic sections

### Performance Considerations
- Minimize timer usage where possible
- Cache expensive operation results
- Optimize frequently called functions (avoid O(n) loops)
- Be mindful of server tick rate impact
- Avoid unnecessary string operations in event handlers

## Plugin Functionality

### Boost Detection
- Monitors high-damage weapons: AWP, Scout, Deagle, Shotguns
- Configurable minimum damage thresholds
- Hit group filtering (headshot only vs. full body)
- Spam protection with configurable delays

### Knife Detection
- Tracks knife attacks on zombies
- Links knife attacks to subsequent infections/kills
- Supports KnifeMode integration for game mode awareness

### Admin Notifications
- Filtered to admins and SourceTV only
- Includes player SteamIDs in configurable formats
- Tracks player connections and disconnections

## Development Workflow

### Making Changes
1. **Understand the game context**: SourceMod plugins run on live game servers
2. **Test on development servers**: Always test before deploying to production
3. **Check for memory leaks**: Use SourceMod's built-in profiler
4. **Validate SQL**: Ensure all queries are async and SQL-injection safe
5. **Consider server performance**: Your code runs every game tick

### Testing Approach
- **Manual testing required**: No automated unit tests for SourceMod plugins
- Set up a development game server with the plugin loaded
- Simulate boost scenarios with multiple players
- Test admin notification filtering
- Verify integration with ZombieReloaded/KnifeMode when available

### Common Patterns in This Codebase
```sourcepawn
// Client validation pattern
if (!IsValidClient(client))
    return;

// ConVar value retrieval
int value = g_cvSomeConVar.IntValue;

// Admin notification pattern
NotifyAdmins("{green}[SM] {default}Message format", param1, param2);

// Forward calling pattern
Call_StartForward(g_hFwd_OnBoost);
Call_PushCell(attacker);
Call_Finish();
```

## Integration Points

### For Other Plugins
- Include `BoostAlert.inc` to access forwards
- Subscribe to `BoostAlert_OnBoost` and `BoostAlert_OnBoostedKill` forwards
- Check library existence: `LibraryExists("BoostAlert")`

### Native Functions
The plugin provides forwards but no natives currently. Extension points are available in the include file structure.

## Debugging & Troubleshooting

### Common Issues
- **Plugin not loading**: Check SourceMod version compatibility (1.12+)
- **Events not firing**: Verify game mode compatibility (CS:S vs other Source games)
- **Memory leaks**: Review StringMap/ArrayList usage patterns
- **Performance issues**: Profile in high-player-count scenarios

### Logging
- Use `LogMessage()` for important events
- Admin notifications are automatically visible to server admins
- Check SourceMod error logs for compilation issues

## Version Control & Releases

- Use semantic versioning in plugin info: `version = "2.1.0"`
- Update version in both `BoostAlert.sp` and git tags
- CI automatically creates releases from tags and master/main branch
- Plugin compilation artifacts are automatically packaged

## Security Considerations

- Always escape user input in SQL queries
- Validate client indices before array access
- Sanitize player names in message formatting
- Be cautious with admin privilege checks

This plugin operates in a high-stakes environment where performance and reliability are critical. Always prioritize server stability and player experience when making changes.