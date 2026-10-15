# Auto Farm Quest: native client crash investigation (Oct 15 2026)

Scope: why the Roblox client sometimes crashes while Auto Farm Quest (AFQ) runs under Matcha, plus a mitigation patch (`crash_patch.luau`, **not applied**). The audit is static, done on `src/*.lua` as it was on Oct 15 2026 (60_afq.lua was being edited by another agent at the same time; its new remote-accept path is included). No file under `src/` was changed.

Sources for the crash history: the brief, `CHANGES.md` (item "What was running at each crash", and point 4 of the remote-accept item for crash 4), and the scratch backup `test.CHANGES.bak.md`. `CHANGES.md` was absent from the folder when this investigation started and was re-created at 14:15.

## 1. Crash data points

| # | When (local) | Script state | What was running | AFQ writes? |
|---|---|---|---|---|
| 1 | 07:01:47 | **unloaded** (`S.unloaded == true`, 0 waits, no Drawings) | One `matcha_exec`: a 25.7 s `getgc({...})` heap scan, then about 1.2M loop iterations with no yield | none |
| 2 | 07:08:17 | loaded about 17 s earlier through `loadstring(readfile())` | AFQ switched on by a watchdog thread spawned from an exec. Steps: tween to The Mayor (character CanCollide off), StartQuest, tween to the wait spot, Enemies scan, then the fight loop in click mode (Head.Size 50, 60 Hz hard lock, ~16 clicks/s). Also the watchdog polling at 5 Hz plus the idle loops | yes |
| 3 | (no details in the notes I had) | - | The brief counts three crashes today; only 1 and 2 are written up | ? |
| 4 | ~14:13 EDT (user report received during this investigation) | loaded (`S.unloaded == false`), **old** `afq_step` (the user's copy predates the remote-accept edit) | The coordinator first described this as the other agent redefining `afq_step` and running a sub-10 s AFQ cycle. The other agent's own record (CHANGES.md, remote-accept item, point 4) contradicts that: it had **not loaded the Matcha tools, sent no `matcha_exec` and redefined nothing at runtime**, and the toggles were not touched. Whether the user had AFQ running is unknown; the user reports the crashes as happening while AFQ runs | unknown (yes if AFQ was on) |

**What this investigation's probes were doing at crash 4: nothing.** When the stop order arrived I had not loaded the Matcha tools at all. No `ToolSearch` for matcha, no `matcha_status`, no `matcha_exec`, no `matcha_logs`. No global was wrapped (`task.wait`, `wait`, `frameWait`, `Drawing.new` and `:Remove` were untouched) and no counting load was added. I saw no `matcha_logs` lines. Both agents' probes can be ruled out for crash 4: **the client crashed with no agent activity at all**, under the user's own play with the chunked build loaded.

**What the crashes have in common.**
- Crashes 1 and 2 both came within seconds of an agent's `matcha_exec` (the long getgc and non-yielding loop in 1, the loadstring plus watchdog exec in 2).
- Crash 4 had no agent activity, so exec activity is **not** a common factor across all three documented crashes.
- Crash 1 had the script unloaded: the client can crash under Matcha with no AFQ, no CFrame writes, no Drawings and no remotes.
- Crashes 2 and 4 share the script being loaded, with its ~30 idle loops, ~1,800 resumes/s and the UE menu drawing every frame. AFQ was on in 2 and probably on in 4.
- The only factor common to all three is Matcha attached to the client.
- The seven-step isolation run (each piece off in turn, 10 s each, all PASS) shows that no single AFQ piece crashes the client within 10 s. Whatever causes the AFQ crashes is therefore low-probability per second and builds up over time.

## 2. Per-frame / per-second inventory (static, actual code rates)

Matcha facts used below: `frameWait()` = `task.wait(1/60)`. Property writes go through Matcha's external memory bridge (Matcha is an external VM emulator; it writes into the Roblox process). Instance handles are address-based (`.Address`). `pcall` catches Lua errors only, never a native fault inside the Roblox process.

### 2.1 Fight loop (`afq_fight`, 60_afq.lua), one iteration per `frameWait()`

| Item | Click mode (`S.remoteMode == false`) | Remote mode (`S.remoteMode == true`, the default) |
|---|---|---|
| Loop rate | 60/s | ~40/s (each swing adds a frameWait inside `BasicM1.fire`) |
| Root CFrame write (`hardLockNpcCFrame` -> `moveRoot`) | 60/s | ~40/s |
| Root Velocity + AssemblyLinearVelocity writes | 120/s (read + write each) | ~80/s |
| Enemy `Head.Size` + `Head.CanCollide` writes (`headExpander.apply`) | **120/s, unconditional**, including the frames right before death. The `while` checks Health > 0 once per frame, then the write happens. No Parent check before the write | 0 (head expander off in remote mode) |
| `head.restore()` after the fight | 1 write of Size + CanCollide to the **dead** enemy's head (checks `target.Parent` only) | same |
| Attack | `farmClick` with a 0.06 s gate = every 4th frame, **~15/s** | `remoteAttack` with a 0.05 s gate -> `BasicM1.fire` (minInterval 0.045) = **~20 swings/s = ~40 FireServer/s** |
| Enemies scans | none | `BasicM1.collect` on **every** call (~20/s): `Enemies:GetChildren()` and, per enemy, Parent, FindFirstChildOfClass, Health, up to 9 FindFirstChild, Position, Address. With 10 enemies that is **~2,600 bridge reads/s** |
| Stale handles in remotes | - | `RegisterHit` sends the primary part and up to 9 `{rig, part}` pairs collected **one frame earlier** (yield between RegisterAttack and RegisterHit), never re-checked |
| Other reads per iteration | ~20 (Parent x2, Health, Character, FindFirstChild x5 incl. `getNormalFarmOffsets` Backpack/Sanguine Art, Position x2, CFrame for `rootRotation`, Velocity x2) = **~1,200/s** | similar per iteration |
| Allocation per iteration | ~12 `pcall(function() ... end)` closures plus ~6 Vector3/CFrame values = ~1,000 objects/s | similar |
| Level check | every 3 s (`afq_checkSwitchPending`: Data.Level + one `afq_select` pass over QUEST_LEVELS) | same |

Bridge **writes** during a click-mode fight total about **300/s** (CFrame 60 + velocities 120 + Head 120). In remote mode they are about 120/s, plus 40 remote calls/s that carry Instance arguments.

### 2.2 Travel and waiting

| Item | Rate |
|---|---|
| `tweenTo` (30_esp.lua) | `task.wait(0.01)` per step = **up to ~100 CFrame writes/s**, plus a `hrp.Parent` read and the checkFn (`afq_farming()` + `char.Parent`). It holds the **same `hrp` handle for the whole tween** (seconds), so a death or respawn mid-tween leaves it writing through a stale handle until Parent reads nil. Velocity is not zeroed during the tween: gravity builds to about -540 studs/s, then `zeroVelocity` on arrival |
| `afl_setCanCollide` | CanCollide write on every character part (~15-20), twice per `afq_teleportTo` |
| `afq_holdAt` | per frame: CFrame read + write and 2 velocity writes = **180 writes/s**. Used for 0.5 s at the giver (twice), 0.5 s at the wait spot, and in the scan loop |
| Scan loop (`afq_step`) | up to 16 x (`afq_nearestEnemy` + `afq_holdAt(0.05)`) = **~20 Enemies scans/s for up to 0.8 s**, each ~7 reads per enemy |
| `afq_spawnCentroid` / `afq_bossPos` | one `_WorldOrigin.EnemySpawns:GetChildren()` per wait-spot trip |
| `afq_bossFind` | cached by `afq_bossAlive` for 5 s (AFQ_BOSS_POLL) |

### 2.3 Tracker, status label, Drawings

| Item | Rate |
|---|---|
| `afq_trackerQuestIs` / `afq_trackerProgress` (`GetDescendants` on PlayerGui.TrackedQuestFrame, a small tree) | 1-3 per `afq_step` (≈ per kill). **New:** `afq_waitTrackerFor` polls it at **10 Hz for up to 2 s per remote accept** |
| Status label (`afq_updateLabel` -> UE label `.Text`) | 1-3 writes per step, **even when the text is unchanged**. Peak a few per second, not per frame |
| Drawing objects created by AFQ | none. ESP render loop: one 60 Hz loop that writes `label.Visible` / `Position` per entry every frame while an ESP is on; caches are pruned on every rebuild (1-2 s) and cleared when a toggle goes off. The UE menu draws every frame |

### 2.4 Loops that could spin without yielding

None in AFQ. Every `while` / `repeat` in 60_afq.lua yields on every path (`frameWait`, `wait(0.05..3)`, `task.wait(0.1)`). `afq_select` loops over QUEST_LEVELS (~116 rows) without yielding, which takes microseconds. The 20_ui2 boat-fly loop uses `continue` only after its `frameWait()`.

### 2.5 Idle cost and loops left running

- **26 top-level loops yield with `frameWait()` (60 Hz) even when their feature is off**: boat seat and boat fly (20_ui2), magnet farm (10_ui), the shared ESP render loop (60_afq), 3 pull loops, freeze position, freeze enemies, tween ember, teleport ember velocity, kitsune, void pull, sky pull (70_misc), and 11 key-combo loops (80_misc2). That is ~1,560 resumes/s. About 13 loops at 0.1 s add ~130/s, plus mirage at 0.05 s and assorted 0.25-2 s loops. Total ≈ 1,750-1,800/s, which matches the earlier live measurement (~2,000 wait calls/s idle; the earlier note counted ~33 60 Hz loops).
- AFQ adds **one** loop (`wait(0.3)` when idle, 3.3/s). Once the toggle goes off, `afq_fight`, `afq_holdAt`, `tweenTo` (checkFn) and `afq_abandon` all exit within a frame or one `wait`. **No AFQ loop keeps running after the toggle goes off.**
- Feature loops that write enemy parts at 60 Hz when on (not AFQ, but they can run together with it): the pull loops write `CanCollide` + `Position` on **every** enemy HRP every frame (`N x 120` writes/s), and the PvP engage thread writes CanCollide on the target every frame. Neither yields to AFQ.

### 2.6 Memory

No AFQ cache grows without bound. AFQ holds a few scalars and `AFQ.selectedNpc` (one enemy handle kept across steps). `BasicM1.lastFireBy`, `RemoteFailures` and `warnTimes` are keyed by a fixed set of tags. ESP caches are pruned on every rebuild and cleared on toggle off. `S.frozenEnemies` is pruned every frame while on and reset on toggle. `MagnetNearestFarm.visited` grows until its own reset (10_ui.lua:888), but it is not used by AFQ. The fight's garbage (~1,000 short-lived objects/s) is ordinary Luau GC load. The cost of finalising Matcha's Instance userdata is unknown.

## 3. Live measurements

**None were taken.** Following the coordinator's stop order (Roblox crashed during this investigation, see crash 4), no Matcha tool was called at all: no status, no exec, no logs. The idle figures in 2.5 are a static count cross-checked against the earlier live measurement (~2,000 wait calls/s idle). The Drawing count, `gcinfo()` trend and live-coroutine count were not measured.

Recommendation for whoever measures next: **do not wrap `task.wait` / `wait` globally on the user's live client.** Every one of the ~30 loops would run through the wrapper, and heavy exec activity preceded crashes 1 and 2 (see H3). Use a fresh server, script loaded, AFQ off, with nobody playing. A `gcinfo()` sampler (one `task.spawn` with `task.wait(2)`, 10 samples) is the least intrusive probe.

## 4. Ranked hypotheses

**H1 (most likely for the user's long sessions): raw writes and reads through handles to instances that are being destroyed or streamed out.**
Evidence:
- Matcha is external and address-based. A write through the handle of an instance Roblox has freed lands in freed or reused process memory. That is silent heap corruption, which crashes later at a random point, and `pcall` cannot catch it.
- AFQ does exactly this at the riskiest moments. It writes `Head.Size` and `CanCollide` every frame up to the frame the enemy dies, with no Parent or Health check before the write. `head.restore()` writes the dead enemy's head after every kill. `RegisterHit` serialises rigs one frame stale (remote mode), and up to 10 rigs go out per swing. `tweenTo` keeps one root handle for seconds, across a possible death or respawn. With the pull loops on, CanCollide and Position go to every enemy HRP every frame, including despawning ones.
- The chance of a crash scales with the number of kills and despawns, so the crash shows up "occasionally over longer sessions" and not in 10 s isolation runs.
- Crash 2 came during the first AFQ fight with the head expander on.
- Crash 4 came during the user's own play with no agent activity, which is the setting this hypothesis is meant to explain.

**H2: write volume and torn writes racing the engine.**
Evidence:
- In a click-mode fight about 300 bridge writes/s hit two physics-owned parts (the player root and the enemy head). Holding, scanning and tweening add 100-180 writes/s.
- An external multi-field write (a 12-float CFrame) is not atomic with respect to Roblox's physics and replication threads, so a write can be torn by a physics step.
- An external `Size` write bypasses the engine's property setter. The collision shape, mass and broadphase bounds of a part going 2 -> 50 studs are left stale, and physics or collision code can trip on that.
- Each event is rare, so the crash rate scales with writes/s multiplied by hours. That fits "occasional", and also the early crash 2.

**H3: Matcha VM load and exec activity, independent of AFQ.**
Evidence:
- Crash 1 happened with the script unloaded and no game writes at all, only a 25.7 s getgc scan and a 1.2M-iteration non-yielding loop. So Matcha alone can take the client down.
- Crash 2 came seconds after a loadstring exec.
- Against: crash 4 happened with no agent exec at all. This hypothesis therefore covers agent sessions but cannot be the whole story for the user's own sessions.
- A related baseline factor, present whenever the script is loaded, is ~1,800 coroutine resumes/s from idle loops plus the UE menu's per-frame Drawing work.

Lower-ranked:
- **(e) Remote spam.** About 40 FireServer/s with Instance arguments in remote mode, against the client's own ~3-4 M1/s. This is more likely to trigger server-side kicks than a native client crash, but each Hybrid-mode call goes into the game, and the stale-rig part of it belongs to H1.
- **(c) GetDescendants.** The tracker tree is small. The rate is per step, plus 10 Hz for 2 s after a remote accept. Low.
- **(d) Memory growth.** No unbounded AFQ cache; garbage is ordinary. Low.
- **(f) Drawing churn.** AFQ creates no Drawings, and the label writes are a few per second. Low.

## 5. Mitigation plan

1. **Operational (H3, no code).** Do not run `matcha_exec` probes, `getgc` scans, global `task.wait` wrappers or hot redefinitions of script functions on the user's live client while AFQ runs. Reload the full chunked build instead of patching functions in place. Run tests on a fresh server where nobody is playing.
2. **Apply `crash_patch.luau` (H1 + H2, low risk).** Pairs and what each changes:

| Pair | File | Change |
|---|---|---|
| P01 | src/00_core.lua | `ROOT_WRITE_HZ = 30`, `writeInterval()` (doubled in safe mode), `WRITE_BUDGET` link. `moveRoot` never writes to a detached root and skips the write within 0.05 studs of the target. `zeroVelocity` writes only a non-zero velocity and never to a detached part |
| P02 | src/40_combat.lua | `hardLockNpcCFrame` capped at 30 Hz (15 Hz safe mode) for every caller; vertical velocity written only when not ~0 |
| P03 | src/40_combat.lua | `headExpander`: checks at most 4 Hz, writes Size / CanCollide only when they differ, never on a detached head or a dead or missing Humanoid; `restore()` skips dead enemies |
| P04 | src/40_combat.lua | `BasicM1.minInterval` 0.045 -> 0.25 s (4 swings/s; 2/s safe mode) |
| P05 | src/40_combat.lua | `BasicM1.ready()` gate; after the one-frame yield, re-check the primary part and every extra rig before RegisterHit |
| P06 | src/40_combat.lua | `basicAttack` checks the swing gate before `BasicM1.collect`, so the Enemies scan runs at 4/s, not ~20/s |
| P07 | src/30_esp.lua | `tweenTo` step 0.01 s -> 1/60 s (1/30 s safe mode); the local root is re-fetched every step by key, so a dead or respawned root is never written |
| P08 | src/20_ui2.lua | `AFQ_DEBUG.safeMode = false` added and linked to `WRITE_BUDGET.debug` (needs P01) |
| P09 | src/20_ui2.lua | `afq_updateLabel`: writes only when the text changed, at most 4 Hz, with one trailing update |
| P10 | src/60_afq.lua | `afq_trackerTexts()`: at most one `GetDescendants` per second; caches strings, not Instances; a new frame invalidates it; `afq_trackerProgress` uses it |
| P11, P12 | src/60_afq.lua | `afq_trackerQuestIs` uses the cached strings (needs P10) |
| P13 | src/60_afq.lua | `afq_holdAt` writes at 30 Hz (15 Hz safe mode) instead of 60 Hz |
| P14 | src/60_afq.lua | `afq_fight` click gate becomes safe-mode aware (0.06 s / 0.12 s) |

   Effect on a click-mode fight: root writes go from 180/s to at most 90/s (fewer when velocity is already 0), and Head writes from 120/s to at most a few per fight. Remote mode drops from ~40 to 8 FireServer/s and from ~2,600 to ~500 reads/s. A tween drops from ~100 to 60 CFrame writes/s. No write goes to a detached or dead instance through any patched path.

3. **A/B test.** After applying, run AFQ for long sessions (for example 4 x 20 min) with `AFQ_DEBUG.safeMode = false` and again with `true`, with no agent connected. Log crash count and kills per minute. If crashes fall with safe mode, H2 is confirmed. If they stay the same and the per-kill rate matters, H1 is the remaining suspect (try `AFQ_DEBUG.noHead = true` too, since remote mode does not need the head expander).
4. **Watch-outs after applying.**
   - P04 lowers remote DPS. If the kill time per enemy becomes unacceptable, raise the rate step by step (0.15 s, 0.1 s) instead of going back to 0.045.
   - P10 caches tracker text for up to 1 s. A k/n read right after a kill can lag one kill; today's tracker shows no k/n label anyway (isolation-run note), so progress stays local. `afq_waitTrackerFor` still sees a new tracker at once, because a new frame invalidates the cache.
   - The pull loops (70_misc.lua `doPullLoop`) and the PvP CanCollide thread still write every enemy every frame. Do not combine them with AFQ; a follow-up should gate them on `farmPriorityBlocked()` and on enemy Health > 0.
5. **Follow-ups (not in the patch, larger changes).**
   - Make the 26 idle 60 Hz loops wait 0.25 s while their toggle is off (cuts ~1,500 resumes/s).
   - Re-validate `AFQ.selectedNpc` against `Workspace.Enemies` at the start of each step, instead of reading `.Name` / `.Parent` through a handle that may be minutes old.
   - Existing bug noticed in passing: `farmAttack` calls `task.spawn(attackFn, nearest)`, but Matcha's `task.spawn` does not forward arguments, so `attackFn` receives nil.
