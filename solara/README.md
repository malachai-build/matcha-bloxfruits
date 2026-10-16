# Blox Fruits script for Solara

This repository contains the separate Solara build of the script. The original Matcha repository and its script files are unchanged.

## Run in Solara

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/malachai-build/matcha-bloxfruits-solara/main/loader.lua"))()
```

The small loader downloads, compiles, and runs the ten files in `src/` one at a time. This avoids compiling the 475 KB `full.lua` as a single chunk. It still loads the complete script and does not reduce the total downloaded code or its in-game runtime work. Keep `full.lua` only as a fallback.

To use another host, set `getgenv().SOLARA_BASE` to a plain-text URL ending in `/` that serves the ten `src/*.lua` files before running the loadstring.

## Crash diagnostics

The hosted loader prints checkpoints and writes them to `laced_solara_diag.txt` in Solara's workspace. After a crash, inspect the log **before another run**, because the next run replaces it. The last line identifies the stage reached: chunk fetch/compile/run, UI library download/compile/run, window creation, or tween travel. A missing log means the script stopped before logging began or workspace writes were unavailable.

For local diagnosis, place the ten `src/` files in Solara's `laced_solara/src/` workspace directory and execute `local_loader.lua`. The UI still downloads the upstream Drawing-based library, so network access is required.

## Compatibility changes

- Uses `game:HttpGet` and checks `loadstring` compilation and runtime errors.
- Uses Roblox `UserInputService` for keys and mouse input.
- Removes Matcha-only `setrobloxinput` calls and uses `Instance:IsA` for class checks.
- Runs the final keep-alive loop in a spawned task.
- Patches the downloaded Drawing UI's mouse reads to use screen coordinates for clicks and dragging.
- Lowers the default character tween speed to 100 studs/s and stops a tween when local ownership is lost or Roblox corrects the character backward. Only 5 such faults within 20 s unload the automation. Mastery and raid travel use the same checked tween.
- Moves parts with CFrame writes (`setPos`), never `BasePart.Position`: in real Roblox a Position write on a jointed part (character root, boat PrimaryPart) rewrites its joints instead of moving the assembly.
- Routes every Drawing (the UE menu and the ESP) through a write cache that skips unchanged property writes and ignores writes to removed objects.
- Uses `task.wait()` for per-frame loops (one frame in Solara) and `task.wait` instead of the deprecated `wait`.

Rebuild `full.lua` after editing a chunk with `python build.py`. This build has passed static syntax checks; live Solara/Blox Fruits behavior still needs testing.
