# matcha-bloxfruits

Blox Fruits automation menu for the Matcha Luau executor (laced.club UI, Drawing-based).
The script is shipped as ten chunks that a small loader fetches and runs in order, so the
Matcha VM compiles pieces of 25-1,700 lines instead of one 9,500-line chunk.

## Load (one line)

Use Matcha's own `httpget` global for the outer fetch. Matcha lists `game:HttpGet` as unsupported for
this purpose, and `loadstring(game:HttpGet(...))()` does not work from the Matcha paste box.

```lua
loadstring(httpget("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/loader.lua"))()
```

Verbose form that reports a failed download instead of running an empty chunk:

```lua
local src = httpget("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/loader.lua")
assert(type(src) == "string" and #src > 100 and string.sub(src, 1, 2) == "--", "loader download failed (" .. tostring(#src) .. " bytes)")
loadstring(src, "laced.loader")()
```

Single-file fallback (same code, one chunk; it has no loader, so a failure part-way is not cleaned up):

```lua
loadstring(httpget("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/dist/test.full.lua"))()
```

To load from a mirror or a dev build, set `_G.LACED_BASE = "https://.../src/"` before running the loader.

**If the client crashes when a quest is picked up remotely** (reported Oct 15 2026), run
`AFQ_DEBUG.remoteAcceptOff = true` in the console after loading: no `StartQuest`/`AbandonQuest` remote is
sent any more and quests are accepted through the giver dialogue instead (see "Debug and A/B switches").

## Layout

| File | Lines | Contents |
|---|---|---|
| `loader.lua` | 155 | Fetches and runs the chunks below; validates each download, pcalls each chunk, checks its load markers, cleans up on failure. |
| `src/00_core.lua` | 976 | Matcha shims (clock, frameWait, idleWait, keyDown, isA, robloxFocused), write budget, remote quiet window (`quietInvoke`), safeRemote, Drawing helpers, `S` and `AFL` state, run-bound `alive`/`shutdownScript`/`onShutdown`, data tables. |
| `src/10_ui.lua` | 1,092 | UE library download (3 tries) + adapter, window, unload hook, tabs, first control sections. |
| `src/20_ui2.lua` | 1,206 | Remaining control sections, boat seat and danger-level dropdowns, settings popups, `AFQ`/`AFQ_DEBUG`. |
| `src/30_esp.lua` | 782 | Berry/chest/boat/flower/fruit ESP builders and renderers, `tweenTo`. |
| `src/40_combat.lua` | 691 | Movement helpers, head expander, remote M1 (`BasicM1`/`basicAttack`), Dungeon. |
| `src/50_farms.lua` | 791 | Chest/fruit farms, Level Farm data and positions, character collisions. |
| `src/60_afq.lua` | 1,693 | Level Farm loop, Auto Farm Quest (quest switch, boss interleave, Underwater City pads, accept/abandon), ESP loops. |
| `src/70_misc.lua` | 1,145 | Pull loops, PvP, auras, fishing, ship repair. |
| `src/80_misc2.lua` | 1,112 | Mastery, materials, mirage, status buttons, Auto Stat, remaining loops. |
| `src/90_main.lua` | 25 | Keep-alive loop (must stay last). |
| `dist/test.full.lua` | 9,513 | The ten chunks concatenated (single-chunk fallback). |
| `tests/` | | Static stability rules and the loader failure-path harness generator (both run by `check.sh`). |
| `test.txt` | 8,537 | The pre-split single file, kept for the Matcha paste workflow (not updated by the stability pass). |
| `CHANGES.md` | | Per-change log with live test results. |

## How the split works

- Chunks are cut only at top-level statement boundaries and keep the original statement order,
  so anything that ran before something else in the single file still does.
- Every top-level `local` in the single file (130 of them) is a plain global in the chunks, because a
  chunk's locals are invisible to the next chunk (Matcha also drops a chunk's top-level return values,
  so globals are the only channel). No call sites changed.
- Per-execution identity: `00_core` creates the run's state table once and defines `alive()`,
  `shutdownScript()` and `onShutdown()` as closures over it. Each later chunk starts with
  `local alive = alive`, `local SCRIPT_STATE = SCRIPT_STATE` and `local S = S` (plus `AFL`, `AFQ` and
  `AFQ_DEBUG` where used), captured at load time, so a re-run cannot make an older copy's loops, callbacks
  or shutdown read the new copy's state. (Until Oct 15 2026 `alive()` read the global `SCRIPT_STATE`, which
  made this capture ineffective in the chunked build.)
- The `notify` wrapper captures Matcha's real `notify` once (`_G.__lacedRealNotify`) so a re-run does not
  wrap the previous wrapper.
- Each chunk begins with a `-- @chunk <name>` line and a start marker, and ends with an end marker
  (`LACED_LOAD.started[...]` / `LACED_LOAD.done[...]` in `_G.__lacedLoad`; in `90_main` the end marker
  comes before the keep-alive loop). Outside the loader the markers do nothing.

## Loader behaviour

1. Downloads one chunk and rejects an empty body, an error page, a body without its `-- @chunk` line, or a
   truncated body (no end marker).
2. Runs it inside `pcall`. Matcha's `loadstring` reports a syntax error only by printing when the chunk is
   called, and a chunk that yields returns at its first yield, so the loader also requires the chunk's
   start marker right after the call and its end marker within 30 s.
3. On any failure, or when a newer load or an unload took over, it runs **this load's own**
   `shutdownScript("loader")`: toggles off, loops stopped, this run's Drawings removed, enlarged heads and
   character collisions restored, held mouse released, `setrobloxinput(true)`, this run's UE menu
   unloaded. If `00_core` failed before defining it, the loader marks this run's state unloaded, releases
   the mouse and unloads a UE copy this load created. A previous copy that is still running is never
   touched. Then it raises (`assert`) with the chunk name.
4. The UE unload hook is registered right after the window exists (`10_ui`), so the menu's Unload button
   stops everything even when a later chunk failed. `shutdownScript` is idempotent; on a re-run the old
   copy's shutdown skips the toggle sweep (the new copy is loading) and its loops stop on `alive()`.

## Debug and A/B switches (`AFQ_DEBUG`, all off in normal use)

- `AFQ_DEBUG.safeMode = true`: doubles every bridge-write and swing interval (root lock, hold, tween step,
  head expander, remote M1, clicks) for crash A/B tests.
- `AFQ_DEBUG.quietAccept = false`: skips the quiet window around CommF_ invokes (they stay serialised).
- `AFQ_DEBUG.remoteAcceptOff = true`: escape hatch for the reported crash on the remote quest pickup.
  No `StartQuest` or `AbandonQuest` is sent at all; Auto Farm Quest accepts at the giver through the
  dialogue (needs Roblox in front; a held quest must be finished or abandoned by hand) and Level Farm
  clicks its dialogue.
- `noAccept`, `noFight`, `noHead`, `noLock`, `noClick`, `forceLevel`, `forceBossAlive`: isolation switches
  from the live tests (see CHANGES.md).

## New globals (stability pass, Oct 15 2026)

`IDLE_POLL`, `idleWait`, `robloxFocused`, `writesPaused`, `remoteInvokePending`, `quietInvoke`,
`AFQ_REMOTE_QUIET_BEFORE`/`AFTER`, `onShutdown`, `ROOT_WRITE_HZ`, `ROOT_SKIP_DIST_SQ`, `WRITE_BUDGET`,
`writeInterval`, `safeModeOn`, `HARD_LOCK_LAST`, `HEAD_APPLY_INTERVAL`, `UE_DOWNLOAD_ATTEMPTS`,
`PULL_WRITE_HZ`, `BERRY_RESCAN_INTERVAL`, `BERRY_SCAN_MAX_OBJECTS`, `BERRY_SCAN_SKIP_ROOTS`,
`berryNextScanAt`, `AFQ_REMOTE_MIN_INTERVAL`, `questRemoteLastAt`, `afl_questRemoteWait`,
`AFQ_TRACKER_POLL`, `AFQ_TRACKER_GONE_SECS`, `AFQ_TRACKER_TTL`, `AFQ_TRACKER_CACHE`, `AFQ_LABEL`,
`AFQ_LABEL_INTERVAL`, `AUTO_STAT_CONFIRM_SECS`, `enhancedCommMissUntil`, `namedRemoteMissUntil`, and the
functions `afq_trackerTexts`, `afq_trackerKey`, `afq_trackerGone`, `afq_clearHeld`, `afq_sleep`,
`afq_backoff`, `afq_acceptWait`, `afq_acceptByDialogue`. `AFQ_REMOTE_ACCEPT_WAIT` changed from 2 to 3 s.
All of them are defined before use in file order, so none is an unknown global in the concatenation.

One name was added to `dist/ug_baseline.txt`: `afl_setCanCollide` (the NPC farm loop in `50_farms` now
calls it, and its definition comes later in the same chunk; the loop only calls it after the chunk loaded).

## Rebuild

```bash
bash build.sh    # concatenates src/*.lua into dist/test.full.lua
bash check.sh    # luau-lsp analyze on every chunk, the concatenation, loader.lua and the loader harness,
                 # plus tests/static_stability.py
```

`check.sh` expects zero syntax errors everywhere, no unknown globals in the concatenation beyond
`dist/ug_baseline.txt` (Matcha/Roblox API names plus forward uses of the script's own globals), and every
static stability rule to pass. Both test files are static: no Luau runtime is installed on the build
machine, so the generated harness (`python -I tests/make_loader_harness.py dist/loader_harness.luau`, then
`luau dist/loader_harness.luau` where a runtime exists) is only syntax-checked by `check.sh`.

## Matcha notes

`loadstring` never returns nil (a syntax error surfaces when the chunk runs), top-level `return` values
are dropped, `error()` does not raise (use `assert`), `task.defer`/`task.delay` are no-ops, `task.spawn`
forwards no arguments (use a closure), a bare `task.wait()` spins about 2,400 times a second (the script
uses `frameWait()`), `IsA` always returns true (the script compares `ClassName`), Instance wrappers are not
stable table keys (the script keys by `.Address`), and `InvokeServer` returns a boolean in Hybrid mode
(quest accepts and stat spends are verified through the quest tracker and `Data` instead).
