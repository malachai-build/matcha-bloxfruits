# SAO: Eternity AFQ (Matcha)

A standalone Auto Farm Quest script for Sword Art Online: Eternity (place 108438460215241). It is a single file and doesn't depend on the Blox Fruits chunks.

```lua
loadstring(httpget("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/sao/sao_afq.lua"))()
```

Keys: **F6** turns farming on or off, **F7** turns quest pickup on or off, **F8** prints a dump to the console, and **End** unloads the script. Roblox must be the focused window, because the script presses E and clicks the mouse.

## What it does

1. It reads your level from the HUD and picks the highest Floor 1 quest you meet the level for: boar (Lv1), wolf (Lv5), wasp (Lv10), nepenthes (Lv15) or kobold (Lv22).
2. It hops to that quest's giver and presses E a few times, which opens the prompt, steps through the dialogue and confirms the accept box.
3. It reads the quest tracker ("Defeat Frenzy Boar 1/3") and farms that mob from `Workspace.Mobs`, standing behind it and clicking.
4. When the tracker says COMPLETE, it returns to the giver and presses E to turn the quest in.

## Crash rules (from the Blox Fruits findings)

- No tweens. Travel uses 60-stud hops at 6 writes/s; a 1,200-stud trip was tested live with no rubberbanding. While fighting, the script places the character at 10 writes/s.
- No remotes and no writes to mobs. Only your own root is moved, and the script re-reads it before every write.
- No `Workspace:GetDescendants` (the game has about 230k instances).

## Not verified yet

- Quest accept and turn-in by pressing E. Matcha disconnected during that test.
- Damage from clicks. The test ran with Roblox unfocused, so no clicks were sent.
- The AFK check ("Are you still here?"). It needs a click on a circle in a 3D popup, so the script stops and shows a warning instead of answering it.

## Overrides

```lua
_G.SAO_AFQ_CONFIG = {
    mobName = "Dire Wolf",   -- farm this mob, ignore the tracker
    questId = "boarQuest",   -- force one quest giver
    autoQuest = false,       -- just farm, never talk to givers
    hopDistance = 60, hopHz = 6, holdHz = 10, clickHz = 6,
}
```
