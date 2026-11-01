# SAO: Eternity AFQ (Matcha)

A standalone Auto Farm Quest script for Sword Art Online: Eternity. It is a single file and doesn't depend on the Blox Fruits chunks.

```lua
loadstring(httpget("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/sao/sao_afq.lua"))()
```

Keys: **F6** turns farming on or off, **F7** turns quest pickup on or off, **F8** prints a discovery dump to the console, and **End** unloads the script.

## Crash rules (from the Blox Fruits findings)

- No tweens. Travel uses long hops at about 6 writes/s. While fighting, the script places the character at 10 writes/s instead of 60.
- The script re-reads the local root before every write. It never writes to enemy parts, so there is no hitbox expander and no mob pulls.
- No remotes. Quests and attacks use real input: proximity prompt or E, mouse click, and dialogue button click. Input only goes out while Roblox is the focused window.

## Tuning

Everything game-specific is found while the script runs, because the game hasn't been inspected live yet. If the script picks the wrong thing, press F8, read the dump, and set overrides before loading:

```lua
_G.SAO_AFQ_CONFIG = {
    mobName = "Boar",        -- skip quest-text parsing and farm this mob
    questGiver = "Quest",    -- substring of the quest NPC / prompt text
    equipKey = 0x31,         -- press 1 when no weapon is held
    hopDistance = 60, hopHz = 6, holdHz = 10, clickHz = 6,
}
```
