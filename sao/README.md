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

- No tweens and no fast teleports. A 2,700-stud trip in 60-stud hops (about 360 studs/s, partly under the terrain) got the account kicked; the server caps movement at `MAX_MOVE_SPEED = 50`.
  - `travelMode = "walk"` (default): the script sets `Humanoid.WalkToPoint` to ground-snapped waypoints 60 studs apart and the game walks you there at normal speed. The script writes no position. If you gain less than 2 studs in 2.5 s, it does a 2 s step burst to get unstuck.
  - `travelMode = "step"`: grounded CFrame steps at 10 Hz, 40 studs/s at most.
  - Close-range adjustments (behind a mob, in front of a giver) move at most 4 studs per write, which is the same 40 studs/s, and are snapped to the ground by raycast.
- No remotes and no writes to mobs. Only your own root is moved, and the script re-reads it before every write.
- No `Workspace:GetDescendants` (the game has about 230k instances).

## Not verified yet

- Walking with `WalkToPoint`. The game's own character controller could override it, and walking is slow: about 16 studs/s, so roughly 2.5 minutes from the boar givers to the boar fields.
- Whether 40 studs/s steps stay under the server's limit. The limit is 50, but the exact server check is unknown.
- Quest accept and turn-in by pressing E. Matcha disconnected during that test.
- Damage from clicks. The test ran with Roblox unfocused, so no clicks were sent.
- The AFK check ("Are you still here?"). It needs a click on a circle in a 3D popup, so the script stops and shows a warning instead of answering it.

## Overrides

```lua
_G.SAO_AFQ_CONFIG = {
    mobName = "Dire Wolf",   -- farm this mob, ignore the tracker
    questId = "boarQuest",   -- force one quest giver
    autoQuest = false,       -- just farm, never talk to givers
    travelMode = "walk",     -- or "step"
    stepSpeed = 40, stepHz = 10, holdHz = 10, clickHz = 6,
}
```
