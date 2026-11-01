# SAO: Eternity AFQ (Matcha)

A standalone Auto Farm Quest script for Sword Art Online: Eternity (place 108438460215241). It is a single file and doesn't depend on the Blox Fruits chunks.

```lua
loadstring(httpget("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/sao/sao_afq.lua"))()
```

Keys: **F6** turns farming on or off, **F7** turns quest pickup on or off, **F8** prints a dump to the console, **F9** turns infinite dash on or off, **F10** turns auto-parry on or off, and **End** unloads the script. Roblox must be the focused window, because the script presses E and clicks the mouse.

## What it does

1. It reads your level from the HUD and picks the highest Floor 1 quest you meet the level for: boar (Lv1), wolf (Lv5), wasp (Lv10), nepenthes (Lv15) or kobold (Lv22).
2. It travels to that quest's giver and presses E a few times, which opens the prompt, steps through the dialogue and confirms the accept box.
3. It reads the quest tracker ("Defeat Frenzy Boar 1/3") and farms that mob from `Workspace.Mobs`, standing behind it and clicking.
4. When the tracker says COMPLETE, it returns to the giver and presses E to turn the quest in.

## Crash rules (from the Blox Fruits findings)

- No tweens and no fast teleports. A 2,700-stud trip in 60-stud hops (about 360 studs/s, partly under the terrain) got the account kicked; the server caps movement at `MAX_MOVE_SPEED = 50`.
  - Travel is 4-stud CFrame steps at 12 Hz, 48 studs/s horizontal (hard cap 49). A brief 57.6 studs/s spike (your own dash on top of the steps) did not kick, so faster may be possible later. Each step keeps your current height plus 0.4 studs and leaves falling to gravity, so you stay just above the ground. If the terrain pushes you back (a slope or wall), the next steps lift up to 4 studs to climb over it. If something else moves you forward, such as your own walking, the next step is shortened by that much.
  - It stops instead of guessing: after 30 blocked steps in a row, or 2 s of falling faster than 120 studs/s.
  - Close-range adjustments (behind a mob, in front of a giver) use the same steps at your own height.
  - Matcha can't help find the ground: `Workspace:Raycast` returned nil in every live test, and writing `Humanoid.WalkToPoint` doesn't start a walk.
  - Live test at the old 36 studs/s (flat ground, 120 studs): 32-36 studs/s, height stayed within 2 studs of the ground, no kick. 48 studs/s is untested.
- No remotes and no writes to mobs. Only your own root is moved, and the script re-reads it before every write.
- No `Workspace:GetDescendants` (the game has about 230k instances).

## Infinite dash (Ctrl)

On by default (`infiniteDash = true`), toggled with F9, and undone on unload. The CombatPlus dodge config is a client table, `{ staminaCost = 10, speed = 50, duration = 0.3, cooldown = 0.55, invulnerable = 0.22 }`. The script finds it in the Luau heap (`findgc`) and sets `staminaCost` to 0 and `cooldown` to 0 (`dashCooldown`), so every Ctrl press dashes. The heap scan takes 15-30 s after load; the status line shows `dash:patching` until it's done.

Live test with cooldown 0.3: 33 dashes in 12 s with stamina at 0-5, up to 89 studs/s while sprinting, and no kick. The server didn't refuse any of them. Cooldown 0 is applied but untested.

The dash's i-frames (`invulnerable = 0.22`) can't be changed from the client. The client only sends `Combat:FireServer("Dash")` and never reads `invulnerable`, so the server grants i-frames from its own copy of the config. Constant invulnerability would mean spamming that remote. The script doesn't do this, because remote calls are what crashed the Blox Fruits script.

## Auto-parry (F)

On by default (`autoParry = true`), toggled with F10.

- **What the game does:**
  - A mob attack fires the `MobTelegraph` effect: a red `Highlight` (named "Highlight") goes on the mob model and is destroyed after `windup + 0.1` s. The windup is 0.15-0.8 s, default 0.4.
  - F with your weapon drawn sends `Combat:FireServer("Parry", serverTime)` if the client parry cooldown (`block.parryCooldown = 0.9`) is over; otherwise it blocks.
  - The server judges the parry against `block.parryWindow = 0.4`.
- **What the script does:**
  - Every 0.5 s it lists mobs within `parryRange` (25 studs).
  - 30 times a second it checks those mobs for a new "Highlight" child.
  - It taps F so the press lands `parryLead` (0.2 s) before the expected hit.
  - It learns each mob type's windup from how long the highlight lasted.
  - Your weapon has to be drawn: a sheathed F press does nothing.
- **Optional:** set `parryCooldown = 0.3` to shorten the client cooldown. The server may still have its own.
- **Click pause:** the game ignores F while a light attack is mid-swing, so the fight loop stops clicking from the moment a telegraph appears until 0.35 s after the planned F tap.
- **Live tests:**
  - Detection works: Frenzy Boar windup measured 0.47 s, and the highlight lasted 0.57 s.
  - With you clicking non-stop and the script tapping F, 0 of 3 attacks were parried.
  - Your own manual F presses did stagger the boar.
  - The click pause is not tested yet.

## To do

- **Dash travel.** Use the infinite dash for travel instead of CFrame steps: face the target and press Ctrl, about 15 studs per dash at the game's own 50 studs/s dash speed.

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
    stepSpeed = 48, stepHz = 12, stepLift = 0.4, climbLift = 4,
    infiniteDash = true, dashCooldown = 0,
    autoParry = true, parryRange = 25, parryLead = 0.2, parryCooldown = nil,
    holdHz = 10, clickHz = 6,
}
```
