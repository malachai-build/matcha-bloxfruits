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
  - Travel is 2-stud CFrame steps at 12 Hz, 24 studs/s horizontal (hard cap 26), just under your 26.5 sprint speed. The server flags *sustained* speed: a brief 57.6 studs/s spike and 36 studs/s for 2.5 s were fine, but Matcha's own movement at 47 studs/s got a kick for "unusual movement" after about 10 s. Each step keeps your current height plus 0.4 studs and leaves falling to gravity, so you stay just above the ground. If the terrain pushes you back (a slope or wall), the next steps lift up to 4 studs to climb over it. If something else moves you forward, such as your own walking, the next step is shortened by that much.
  - It stops instead of guessing: after 30 blocked steps in a row, or 2 s of falling faster than 120 studs/s.
  - Close-range adjustments (behind a mob, in front of a giver) use the same steps at your own height.
  - Matcha can't help find the ground: `Workspace:Raycast` returned nil in every live test, and writing `Humanoid.WalkToPoint` doesn't start a walk.
  - Live test at 36 studs/s (flat ground, 120 studs, about 2.5 s): height stayed within 2 studs of the ground, no kick. 24 studs/s over a long trip is untested.
- No remotes and no writes to mobs. Only your own root is moved, and the script re-reads it before every write.
- No `Workspace:GetDescendants` (the game has about 230k instances).

## Teleport travel (default, `travelMode = "teleport"`)

- **How it works:** for trips over 30 studs, one CFrame write to 3 studs above the target, then ground steps for the rest of the way. Long teleports are at least `teleportMinGap` (8 s) apart.
- **Live test:** a single 1,142-stud teleport next to a Frenzy Boar landed 3.8 studs off after 0.5 s, with no pull-back and no kick (still in the same server afterwards). The first kick came from a fast chain of 60-stud hops through the terrain.
- **Not tested yet:** whether repeated long teleports over a farming session stay kick-free.

## Dash travel (`travelMode = "dash"`)

- **How it works:** for trips over 30 studs with Roblox focused, the script holds W and taps Ctrl every `dashGap` (0.15 s), while `mousemoverel` turns the camera toward the target. With W held the dash follows the camera. With no move key it goes backward, and the game turns the character to the camera, so the camera is what has to be steered.
- **Live tests:**
  - W + Ctrl ran at 52 studs/s at 0.15 s gaps and 45 studs/s at 0.2-0.3 s. The dash itself is 50 studs/s for 0.3 s, so faster taps only overlap. No kick in 2 s bursts.
  - Mouse steering: 100 px turned the camera 10°, and the error stayed under 1° after 0.3 s.
- **Obstacles:** if a run stalls (under 3 studs gained in 1 s), the script jumps, then makes short teleport hops up and over (10, 14, 18, then 22 studs up, 6 forward). After 6 stalls it falls back to ground steps. While the run is clear it adds a 6-stud boost hop every 3 s. Hops are at least 1.5 s apart and at most 26 studs. In the live run this still went poorly, so teleport travel became the default.
- **Rests:** it pauses for `dashRest` (1 s) after every `dashBurst` (10 s) of dashing.
- **Finish:** within `dashArrive` (12 studs) it finishes with ground steps.
- **Without focus** it uses the slower ground steps instead.
- **Stamina:** the server still takes about 10 per dash, but with the infinite-dash patch the dash keeps working at 0.
- **Not tested yet:** whole quest trips with the full script.

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
- **Remote mode (`parryMode = "remote"`, the default):** sends the game's own call, `Remotes.Combat:FireServer("Parry", serverTime)`, so it works without Roblox focus and without an F press. Matcha has no `GetServerTimeNow`, so the server time is rebuilt from `os.time()` (whole seconds, caught at the moment it ticks over) plus `os.clock()`. With `parryFace` on, the script turns you toward the attacker first, in case the server checks facing. It's one-way `FireServer`, not the `InvokeServer` that crashed the Blox Fruits script. Live test (hands off, 90 s, one Frenzy Boar): 32 parries sent, 0 damage taken (HP stayed at 270), 28 of them with Roblox unfocused.
- **Two boars, remote mode:** 53 of 61 attacks did no damage (attacks came about 0.25-0.5 s apart; each boar attack shows two telegraphs about 0.55 s apart). 4 hits were blocked to 6 damage, and 4 full 33-damage hits came while the server's 0.9 s parry cooldown was still running. Since then, inside `parryServerCooldown` (0.9 s) the script sends `Combat:FireServer("Block", true)` and releases it `blockHold` (0.45 s) later, so those hits should be blocked to about 6 instead of 33. The block fallback is untested.
- **Several attackers:** the client parry cooldown is patched from 0.9 to 0.25 s (`parryCooldown`), and taps can be as close as 0.12 s apart (`parryMinGap`). The server may still have its own cooldown.
- **Crowds:** target choice adds 40 studs of cost for every other mob within 15 studs of a candidate (`crowdRadius`, `crowdPenalty`), so lone mobs win.
- **Low HP:** below 35% HP (`retreatHp`) the script leaves the fight, moves 80 studs away from nearby mobs, and waits until 80% HP (`resumeHp`, at most 45 s).
- **Click pause:** the game ignores F while a light attack is mid-swing, so the fight loop stops clicking from the moment a telegraph appears until 0.35 s after the planned F tap.
- **Live tests:**
  - Detection works: Frenzy Boar windup measured 0.47 s, and the highlight lasted 0.57 s.
  - With you clicking non-stop and the script tapping F, 0 of 3 attacks were parried.
  - Hands-off test, with three boars attacking for most of it: the script parried most hits (HP stayed flat across many attacks), but the overlapping attacks eventually killed the character. That's what the cooldown patch, crowd avoidance and retreat are for. None of those three are tested yet.
  - The mob's `Staggered` attribute is not a reliable success signal. Damage taken is.

## Sword skills (1-4)

- **Client patch:** the 42 skill definitions (`Name`, `Cooldown` 4-30 s, `Duration`, `Stamina`) get `Cooldown = 0` (`zeroSkillCooldown`), and the originals are restored on unload.
- **The server still enforces cooldowns:** it rejects an early cast and sends back its remaining cooldown, which the client then waits out.
- **Rapid-recast window:** right after a skill's animation ends there's a short window where a recast is accepted without starting the cooldown (found by hand; inconsistent).
- **Auto-casting:** while fighting, the script taps the keys in `skillSlots` (default 1 and 2) 12 times a second. The client refuses taps during the animation by itself, so the first tap it lets through goes out right as the animation ends. Taps pause around auto-parry, like clicks do.
- **Not verified yet:** whether auto-casting hits the window more often than casting by hand. Exact press timings couldn't be logged, because the game's input handling consumes 1-4 before `UserInputService.InputBegan` sees them.
- **Stamina:** skills still cost it on the server, and so does each dash, about 10 (logged live).
- **Sprint stamina can't be removed from the client.** The client only sends `Sprint:FireServer(true/false)`; the server drains the stamina and turns `Sprinting` off at 0.
  - Setting the `BaseWalkSpeed` attribute to the sprint speed on the client didn't change your walking speed.
  - Moving faster with Matcha's own position/velocity tools got a kick, and walking at sprint speed without the server's sprint flag would likely be flagged the same way.

## To do


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
    skillSlots = { 1, 2 }, skillTapHz = 12, zeroSkillCooldown = true,
    parryMode = "remote", parryFace = true,
    autoParry = true, parryRange = 25, parryLead = 0.2, parryCooldown = 0.25, parryMinGap = 0.12,
    crowdRadius = 15, crowdPenalty = 40, retreatHp = 0.35, resumeHp = 0.8,
    holdHz = 10, clickHz = 6,
}
```
