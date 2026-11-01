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
