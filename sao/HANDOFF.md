# Handoff

## Where things are

- **Script:** `sao/sao_afq.lua` on branch `claude/sao-eternity-afq`.
- **Loading it:** copy it to `C:/matcha/workspace`, then run `loadstring(readfile("sao_afq.lua"))()` in Matcha.
- **Docs:** `sao/README.md` covers every feature and test result.

## What works with Roblox unfocused

These remotes:

- `Combat`: Swing, Hit, Parry, Block, Dash.
- `SwordSkillCast`.
- `QuestTalk` and `QuestAccept`. These use InvokeServer, which returns only `true` here.
- `QuestCancel`.

Quest ids come from each NPC's `QuestPrompt` attribute, not the NPC model's attribute.

## Kick limits

- Keep sustained movement at or below about 26 studs/s.
- A single long teleport is fine.
- A rapid chain of hops gets you kicked.

## Matcha quirks

- `task.delay` never fires; use `task.spawn` with `task.wait` instead.
- `Raycast` doesn't work, and `GetServerTimeNow` doesn't exist.
- `getgctbl` errors.
- Model attributes are misread.

The settings menu uses the UE library and saves to `sao_afq_settings.json`.

## Next task: mining and fishing

- **Mining:** nodes are in `Workspace.OreNodes`; the swing remote is `MineSwing`.
- **Fishing:** the remotes are `FishingAction` and `FishingState`. Also look at `UI.Fishing` and `FishingConfig`.
- **Equipping:** the pickaxe or rod has to replace the sword. Look at the `EquipItem` and `ToggleTool` remotes, and the character's `Tool` attribute.
- **Loop:** track node respawns, then go back to quest grinding.

## Findings (2026-11-01, read-only, from decompiles)

### Fishing (`Client.UI.Fishing`, `Shared.Config.FishingConfig`)

- Remote: `FishingAction` is a RemoteFunction; every call is `InvokeServer(action, arg)` and returns a table (`ok`, `message`, ...).
- Flow:
  1. `InvokeServer("cast", waterPos)`. `waterPos` is the water surface point, 5–22 studs out (`CAST_MIN`/`CAST_MAX`), and no more than 14 studs below the root (`CAST_DROP`). The client passes `castPoint.Position - (0, 2.5, 0)`, which is the surface hit. It returns `{ok, target, level}`.
  2. Wait for `FishingState.OnClientEvent("bite", hookWindow)`. Bites come after `BITE_MIN`–`BITE_MAX` (3–9s), and get faster with level.
  3. Within `HOOK_WINDOW` (2.2s) plus 0.4s of grace, call `InvokeServer("hook")`. It returns `{ok, difficulty, zone, rarity}`.
  4. The reel minigame runs on the client only. Then call `InvokeServer("finish", true)`, which returns `{ok, kind, rarity}`. The fastest legitimate reel takes `(1-0.35)/0.4 = 1.625s`, so wait about 2–4s before calling finish. `REEL_MAX_TIME` is 45s.
  5. Other events: `FishingState("ended", msg)` means the server dropped the session. `InvokeServer("cancel")` aborts.
- Gate: the rod is checked as an **accessory slot** (`State.getEquipped("rod").kind == "FishingRod"`), set from Menu > Equipment > Accessories. It doesn't replace the sword. Fishing does sheathe first (`ToggleSheathe:FireServer(true)` when `Sheathed == false`).
- Finding water: the client raycasts Terrain for `Enum.Material.Water`. Matcha's `Raycast` is broken, so either hardcode fishing spots or read the `FishingCastPoint` part the game itself places while you stand facing water.
- `WALK_AWAY` is 30 studs, so stay within 30 studs of the bobber.

### Mining (`Client.Systems.Mining`, `Shared.Config.MiningConfig`)

- Remote: `MineSwing:FireServer(nodeModel)`. The node is a Model tagged `OreNode` (under `Workspace.OreNodes.Area1/Area2`, plus the loose `CrystalliteOre` and `ObsidianOre`), with an `Ore` child.
- A node is valid when `Parent ~= nil`, its `MinedOut` attribute isn't true, and it has an `Ore` child. Its centre is the `OreCenter` attribute, or `Ore:GetPivot().Position` (the attribute may be misread in Matcha, so prefer the pivot).
- Range: horizontal distance at most `REACH` (7.5) plus 1, and `|dy|` at most 8.
- Rate: one swing per `SWING_TIME / MiningSpeed` (1s at speed 1). The impact fires at 0.7s.
- `RESPAWN` is 45s and `CLAIM_TIME` is 6s, which is probably a node-ownership lock.
- Character gates: `Tool == "Pickaxe"`, `ToolDrawn == true`, `WeaponType == nil`, and not `Stunned` or `Paralyzed`. So the pickaxe **does** replace the weapon. Right now the character shows `WeaponType=Greatsword`, `Tool=""` and `Sheathed=true`.
- Ore types: Iron, Steel, Kobold, Crystallite, Obsidian, Verdite. Pickaxe tiers: Iron, Crystallite, Obsidian, Verdite.

### Observed pickaxe equip (attribute watcher, manual equip from Menu > Tools)

| t | Change | Likely action |
|---|---|---|
| 28.8s | `Tool=Pickaxe`, `WeaponType=""`, sword model `Weapon` replaced by `PickaxeBack` | Tools-menu click (`ToggleTool`?) |
| 31.6s | `ToolDrawn=true` | draw (probably `ToggleSheathe`) |
| 34.6s | `ToolDrawn=false` | stow |
| 38.3s | `Tool=""`, `PickaxeBack` removed | Tools-menu click again |
| 40.4s | `WeaponType=Greatsword`, `Weapon` model back, `ToolDrawn=nil` | server restores sword about 2s later |

Equipping the tool and drawing it are separate steps. `Sheathed` stayed `true` the whole time, so drawing a tool sets `ToolDrawn` rather than `Sheathed`.

### Live test (2026-11-01, approved by the user)

- **Not confirmed:** after `Remotes.ToggleTool:FireServer("Pickaxe")`, the character's attributes read `Tool=Pickaxe`, `WeaponType=""` and `PickaxeBack`, but the user saw no pickaxe equipped in game. Treat this call as unknown.
- **Don't guess remote arguments.** The user rejected guess-and-fire testing. Get the real arguments from a working decompile first.
- **Did not unequip:** firing `"Pickaxe"` again (twice), `()` and `("Pickaxe", false)` all left `Tool=Pickaxe`. So unequipping is still unknown.
- **Matcha quirk:** a `task.spawn` thread inside `matcha_exec` only advances while an exec is running, and its prints show up late in `matcha_logs`. A plain `task.wait` in the main body makes the exec return early. To test timing, fire in one exec and read state in the next.

### Still unknown

- The arguments for `ToggleTool` (in `Systems.CharacterController`) and `EquipItem` (in `UI.Accessories` and `UI.Menu`). Matcha's decompiler started returning nil for every uncached script after a sweep over all PlayerScripts, so don't sweep. Restart Matcha or rejoin, then decompile those two directly. Alternatively, equip a pickaxe by hand and watch how the `Tool`, `ToolDrawn` and `WeaponType` attributes change.
