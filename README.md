# matcha-bloxfruits

Blox Fruits automation menu for the Matcha Luau executor (laced.club UI, Drawing-based).
The script is shipped as ten chunks that a small loader fetches and runs in order, so the
Matcha VM compiles pieces of 30-1,400 lines instead of one 8,500-line chunk.

## Load (one line)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/loader.lua"))()
```

Matcha's global `httpget` works the same way:

```lua
loadstring(httpget("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/loader.lua"))()
```

Single-file fallback (same code, one chunk):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits/main/dist/test.full.lua"))()
```

To load from a mirror or a dev build, set `_G.LACED_BASE = "https://.../src/"` before running the loader.

## Layout

| File | Lines | Contents |
|---|---|---|
| `loader.lua` | ~55 | Fetches and runs the chunks below, validating each download. |
| `src/00_core.lua` | 785 | Matcha shims (clock, frameWait, keyDown, isA), safeRemote, Drawing helpers, `S` and `AFL` state, data tables. |
| `src/10_ui.lua` | 1,043 | UE library download + adapter, window, tabs, first control sections. |
| `src/20_ui2.lua` | 1,134 | Remaining control sections, boat seat and danger-level dropdowns, settings popups. |
| `src/30_esp.lua` | 705 | Berry/chest/boat/flower/fruit ESP builders and renderers. |
| `src/40_combat.lua` | 629 | Movement helpers, head expander, remote M1 (`BasicM1`/`basicAttack`), Dungeon. |
| `src/50_farms.lua` | 746 | Chest/fruit farms, Level Farm data and positions. |
| `src/60_afq.lua` | 1,368 | Level Farm loop, Auto Farm Quest (quest switch, boss interleave, Underwater City pads). |
| `src/70_misc.lua` | 1,102 | Pull loops, PvP, auras, fishing, ship repair. |
| `src/80_misc2.lua` | 1,037 | Mastery, materials, mirage, status buttons, Auto Stat, remaining loops. |
| `src/90_main.lua` | 35 | Unload hook and the keep-alive loop (must stay last). |
| `dist/test.full.lua` | 8,584 | The ten chunks concatenated (single-chunk fallback). |
| `test.txt` | 8,537 | The pre-split single file, kept for the Matcha paste workflow. |
| `CHANGES.md` | | Per-change log with live test results. |

## How the split works

- Chunks are cut only at top-level statement boundaries and keep the original statement order,
  so anything that ran before something else in the single file still does.
- Every top-level `local` in the single file (130 of them) is a plain global in the chunks, because a
  chunk's locals are invisible to the next chunk (Matcha also drops a chunk's top-level return values,
  so globals are the only channel). No call sites changed.
- Two names keep per-execution identity: each chunk after `00_core` starts with
  `local alive = alive` and `local SCRIPT_STATE = SCRIPT_STATE`, captured at load time. Re-running the
  script unloads the previous copy, and that copy's loops must keep checking *their own* state table,
  not the new copy's (a live-found bug in the single-file build; see CHANGES.md).
- The `notify` wrapper captures Matcha's real `notify` once (`_G.__lacedRealNotify`) so a re-run does not
  wrap the previous wrapper.
- Each chunk begins with a `-- @chunk <name>` marker that the loader checks before running it.

## Rebuild

```bash
bash build.sh    # concatenates src/*.lua into dist/test.full.lua
bash check.sh    # luau-lsp analyze on every chunk and on the concatenation
```

`check.sh` expects zero syntax errors everywhere and, for the concatenation, no unknown globals beyond the
48 Matcha/Roblox API names the single file already used.

## Matcha notes

`loadstring` never returns nil (a syntax error surfaces when the chunk runs), top-level `return` values
are dropped, `error()` does not raise (use `assert`), `task.defer`/`task.delay` are no-ops, a bare
`task.wait()` spins about 2,400 times a second (the script uses `frameWait()`), `IsA` always returns true
(the script compares `ClassName`), and `InvokeServer` returns a boolean in Hybrid mode.
