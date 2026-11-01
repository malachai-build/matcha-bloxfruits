# SAO: Eternity AFQ (Matcha)

A standalone Auto Farm Quest script for Sword Art Online: Eternity (place 108438460215241). It is a single file and doesn't depend on the Blox Fruits chunks.

```lua
loadstring(httpget("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/sao/sao_afq.lua"))()
```

Keys: **F6** turns farming on or off, **F7** turns quest pickup on or off, **F8** prints a dump to the console, and **End** unloads the script. Roblox must be the focused window, because the script presses E and clicks the mouse.

## What it does

1. It reads your level from the HUD and picks the highest Floor 1 quest you meet the level for: boar (Lv1), wolf (Lv5), wasp (Lv10), nepenthes (Lv15) or kobold (Lv22).
2. It travels to that quest's giver and presses E a few times, which opens the prompt, steps through the dialogue and confirms the accept box.
3. It reads the quest tracker ("Defeat Frenzy Boar 1/3") and farms that mob from `Workspace.Mobs`, standing behind it and clicking.
4. When the tracker says COMPLETE, it returns to the giver and presses E to turn the quest in.

## Crash rules (from the Blox Fruits findings)

- No tweens and no fast teleports. A 2,700-stud trip in 60-stud hops (about 360 studs/s, partly under the terrain) got the account kicked; the server caps movement at `MAX_MOVE_SPEED = 50`.
  - Travel is 3-stud CFrame steps at 12 Hz, 36 studs/s horizontal (hard cap 45). Each step keeps your current height plus 0.4 studs and leaves falling to gravity, so you stay just above the ground. If the terrain pushes you back (a slope or wall), the next steps lift up to 4 studs to climb over it. If something else moves you forward, such as your own walking, the next step is shortened by that much.
  - It stops instead of guessing: after 30 blocked steps in a row, or 2 s of falling faster than 120 studs/s.
  - Close-range adjustments (behind a mob, in front of a giver) use the same steps at your own height.
  - Matcha can't help find the ground: `Workspace:Raycast` returned nil in every live test, and writing `Humanoid.WalkToPoint` doesn't start a walk.
  - Live test (flat ground, 120 studs): 32-36 studs/s, height stayed within 2 studs of the ground, no kick.
- No remotes and no writes to mobs. Only your own root is moved, and the script re-reads it before every write.
- No `Workspace:GetDescendants` (the game has about 230k instances).

## Not verified yet

- Long trips and hills. Only a 120-stud flat trip has been tested. The server's exact check is unknown, beyond its 50 studs/s cap.
- Quest accept and turn-in by pressing E. Matcha disconnected during that test.
- Damage from clicks. The test ran with Roblox unfocused, so no clicks were sent.
- The AFK check ("Are you still here?"). It needs a click on a circle in a 3D popup, so the script stops and shows a warning instead of answering it.

## Overrides

```lua
_G.SAO_AFQ_CONFIG = {
    mobName = "Dire Wolf",   -- farm this mob, ignore the tracker
    questId = "boarQuest",   -- force one quest giver
    autoQuest = false,       -- just farm, never talk to givers
    stepSpeed = 36, stepHz = 12, stepLift = 0.4, climbLift = 4,
    holdHz = 10, clickHz = 6,
}
```
