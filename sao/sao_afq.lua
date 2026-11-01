--[[
    SAO: Eternity - Auto Farm Quest (Matcha Luau, standalone, Drawing status only)

    Built without a live look at the game (the Matcha inspector was offline), so
    everything game-specific is discovered at run time or set in the config:
      * quest givers: ProximityPrompts whose text or model name says "quest"
        (or matches CFG.questGiver)
      * quest target: the PlayerGui label that reads like "Defeat 10 Boars (3/10)"
        (or CFG.mobName when set)
      * mobs: Models with a living Humanoid that are not player characters

    Crash rules carried over from the Blox Fruits script (CRASH_FINDINGS.md):
      * no tweens: travel is a few long hops (HOP_HZ writes/s), never a 60 Hz glide
      * one fixed-rate root write while fighting (HOLD_HZ), nothing at frame rate
      * the local root is re-fetched before every write; nothing is ever written
        to an enemy part (no hitbox expander, no pulls)
      * no RemoteEvent/RemoteFunction calls: quests and attacks go through real
        input (E / prompt, mouse click), only while Roblox has focus
      * every loop yields with a fixed task.wait(n), never a bare task.wait()

    Keys: F6 farm on/off, F7 quest pickup on/off, F8 dump discovery to console,
          End unload.

    Override any CFG field before loading:
        _G.SAO_AFQ_CONFIG = { mobName = "Boar", questGiver = "Quest" }
]]

if type(_G.SAO_AFQ) == "table" and type(_G.SAO_AFQ.unload) == "function" then
    pcall(_G.SAO_AFQ.unload)
end

local CFG = {
    mobName = nil,          -- force a mob name (substring, case-insensitive); nil = from quest text
    questGiver = nil,       -- force a quest giver name (substring); nil = any "quest" prompt
    autoQuest = true,       -- pick up / turn in quests
    standOff = 4,           -- studs behind the mob
    standHeight = 1.5,      -- studs above the mob root
    attackRange = 10,       -- start clicking within this distance
    clickHz = 6,            -- mouse clicks per second while fighting
    holdHz = 10,            -- root writes per second while fighting
    hopDistance = 60,       -- studs per travel hop (0 = one direct teleport)
    hopHz = 6,              -- travel hops per second
    scanInterval = 1.5,     -- mob list refresh (s)
    guiInterval = 1,        -- quest text refresh (s)
    promptInterval = 20,    -- quest prompt cache refresh (s)
    interactKey = 0x45,     -- E
    equipKey = nil,         -- e.g. 0x31 (1) to press when no tool is held
    dialogueWords = { "accept", "yes", "ok", "claim", "complete", "turn in", "confirm", "continue" },
    keys = { farm = 0x75, quest = 0x76, dump = 0x77, unload = 0x23 },
}
if type(_G.SAO_AFQ_CONFIG) == "table" then
    for k, v in pairs(_G.SAO_AFQ_CONFIG) do CFG[k] = v end
end

local clock = (type(os) == "table" and type(os.clock) == "function") and os.clock or tick
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(0.1); LocalPlayer = Players.LocalPlayer end
local Workspace = game:GetService("Workspace")

local STATE = { running = true, farm = false, quest = CFG.autoQuest, status = "idle", target = nil }
local API = { unload = nil }
_G.SAO_AFQ = API

-- ---------------------------------------------------------------------------
-- Small helpers (Matcha: IsA ignores its argument, so compare ClassName)
-- ---------------------------------------------------------------------------
local function cls(inst)
    local ok, c = pcall(function() return inst.ClassName end)
    return ok and c or nil
end
local function lower(s) return string.lower(tostring(s or "")) end
local function alive() return STATE.running end
local function focused()
    if type(isrbxactive) ~= "function" then return true end
    local ok, active = pcall(isrbxactive)
    return not (ok and active == false)
end
local function keyDown(vk)
    if type(iskeypressed) ~= "function" then return false end
    local ok, s = pcall(iskeypressed, vk)
    return ok and s == true
end
local function tapKey(vk, hold)
    if not focused() then return false end
    pcall(function() keypress(vk); task.wait(hold or 0.08); keyrelease(vk) end)
    return true
end
local function setStatus(s) STATE.status = s end

local function myRoot()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not root or not hum then return nil, nil end
    local ok, hp = pcall(function() return hum.Health end)
    if not ok or not hp or hp <= 0 then return nil, nil end
    return root, char
end

local function partPos(part)
    local ok, parent, p = pcall(function() return part.Parent, part.Position end)
    if ok and parent ~= nil then return p end
    return nil
end

-- One root write, velocity zeroed so gravity cannot build up between writes.
local function placeAt(pos, lookAt)
    local root = myRoot()
    if not root or not pos then return false end
    local ok = pcall(function()
        if lookAt then root.CFrame = CFrame.new(pos, lookAt) else root.CFrame = CFrame.new(pos) end
    end)
    if not ok and not pcall(function() root.Position = pos end) then return false end
    pcall(function() root.Velocity = Vector3.new(0, 0, 0) end)
    pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
    return true
end

-- Travel in long hops at HOP_HZ instead of a 60 Hz tween. checkFn() false stops it.
local function travelTo(pos, checkFn)
    local stepWait = 1 / math.max(1, CFG.hopHz)
    for _ = 1, 400 do
        if not alive() or (checkFn and not checkFn()) then return false end
        local root = myRoot()
        local cur = root and partPos(root)
        if not cur then task.wait(0.5); return false end
        local delta = pos - cur
        local dist = delta.Magnitude
        if dist < 3 then return true end
        if CFG.hopDistance <= 0 or dist <= CFG.hopDistance then
            placeAt(pos)
            task.wait(stepWait)
            return true
        end
        placeAt(cur + delta.Unit * CFG.hopDistance)
        task.wait(stepWait)
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Discovery: mobs
-- ---------------------------------------------------------------------------
local MOB_FOLDER_WORDS = { "mob", "enem", "monster", "npc", "entit", "spawn", "alive", "creature" }
local mobCache, mobScanAt = {}, -1e9

local function playerChars()
    local set = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        if c then set[c] = true end
    end
    return set
end

local function mobRootOf(model)
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        or model:FindFirstChild("UpperTorso") or model.PrimaryPart
end

local function livingHumanoid(model)
    local hum = model:FindFirstChild("Humanoid")
    if not hum or cls(hum) ~= "Humanoid" then return nil end
    local ok, hp, maxHp = pcall(function() return hum.Health, hum.MaxHealth end)
    if not ok or not hp or hp <= 0 or maxHp == math.huge then return nil end
    return hum
end

local function collectFrom(container, out, chars, depth)
    local okKids, kids = pcall(function() return container:GetChildren() end)
    if not okKids then return end
    for _, child in ipairs(kids) do
        local c = cls(child)
        if c == "Model" and not chars[child] then
            if livingHumanoid(child) and mobRootOf(child) then out[#out + 1] = child end
        elseif (c == "Folder" or c == "Model") and depth > 0 then
            collectFrom(child, out, chars, depth - 1)
        end
    end
end

local function scanMobs()
    local out, chars = {}, playerChars()
    local folders = {}
    for _, child in ipairs(Workspace:GetChildren()) do
        local n = lower(child.Name)
        for _, w in ipairs(MOB_FOLDER_WORDS) do
            if string.find(n, w, 1, true) then folders[#folders + 1] = child; break end
        end
    end
    for _, f in ipairs(folders) do collectFrom(f, out, chars, 3) end
    if #out == 0 then collectFrom(Workspace, out, chars, 1) end
    mobCache, mobScanAt = out, clock()
    return out
end

local function nameMatches(modelName, want)
    if not want or want == "" then return true end
    local a, b = lower(modelName), lower(want)
    if string.find(a, b, 1, true) or string.find(b, a, 1, true) then return true end
    local bs = string.gsub(b, "e?s$", "") -- "Boars" -> "boar", "Wolves" stays close enough
    return #bs >= 3 and string.find(a, bs, 1, true) ~= nil
end

local function bestMob(want)
    if clock() - mobScanAt > CFG.scanInterval then scanMobs() end
    local root = myRoot()
    local here = root and partPos(root)
    if not here then return nil end
    local best, bestDist = nil, math.huge
    for _, m in ipairs(mobCache) do
        if m.Parent ~= nil and livingHumanoid(m) and nameMatches(m.Name, want) then
            local p = partPos(mobRootOf(m))
            if p then
                local d = (p - here).Magnitude
                if d < bestDist then best, bestDist = m, d end
            end
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Discovery: quest text in PlayerGui
-- ---------------------------------------------------------------------------
local QUEST_VERBS = { "defeat", "kill", "slay", "hunt", "eliminate", "destroy" }
local quest = { mob = nil, have = nil, need = nil, text = nil, at = -1e9 }

local function stripTags(s) return (string.gsub(tostring(s or ""), "<[^>]->", "")) end

local function parseQuest(text)
    local t = stripTags(text)
    local l = lower(t)
    -- A quest line carries progress ("3/10"); without it "Kills: 50" and the like would match.
    local have, need = string.match(t, "(%d+)%s*/%s*(%d+)")
    if not have then return nil end
    for _, verb in ipairs(QUEST_VERBS) do
        local i = string.find(l, "%f[%a]" .. verb .. "%f[%A]")
        if i then
            local rest = string.sub(t, i + #verb)
            rest = string.gsub(rest, "^%s*[xX]?%d*%s*", "")
            local name = string.match(rest, "^([%a][%a%s'%-]-)%s*[%(%[:%d]") or string.match(rest, "^([%a][%a%s'%-]+)")
            if name then
                name = string.gsub(name, "%s+$", "")
                if #name >= 3 then return name, tonumber(have), tonumber(need) end
            end
        end
    end
    return nil
end

local function readQuest()
    if clock() - quest.at < CFG.guiInterval then return quest end
    quest.at = clock()
    quest.mob, quest.have, quest.need, quest.text = nil, nil, nil, nil
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then return quest end
    local ok, all = pcall(function() return gui:GetDescendants() end)
    if not ok then return quest end
    for _, d in ipairs(all) do
        local c = cls(d)
        if c == "TextLabel" or c == "TextButton" then
            local okT, text, vis = pcall(function() return d.Text, d.Visible end)
            if okT and vis and type(text) == "string" and #text < 200 then
                local name, have, need = parseQuest(text)
                if name then
                    quest.mob, quest.have, quest.need, quest.text = name, have, need, text
                    return quest
                end
            end
        end
    end
    return quest
end

local function questDone(q) return q.have ~= nil and q.need ~= nil and q.have >= q.need end

-- ---------------------------------------------------------------------------
-- Discovery: quest givers (ProximityPrompts) and dialogue buttons
-- ---------------------------------------------------------------------------
local prompts, promptAt = {}, -1e9

local function promptModel(prompt)
    local p = prompt.Parent
    while p and p ~= Workspace do
        if cls(p) == "Model" then return p end
        p = p.Parent
    end
    return nil
end

local function promptPart(prompt)
    local p = prompt.Parent
    if p and partPos(p) then return p end
    local m = promptModel(prompt)
    return m and mobRootOf(m) or nil
end

local function scanPrompts()
    local out = {}
    local ok, all = pcall(function() return Workspace:GetDescendants() end)
    if ok then
        for _, d in ipairs(all) do
            if cls(d) == "ProximityPrompt" then
                local okT, action, object = pcall(function() return d.ActionText, d.ObjectText end)
                local m = promptModel(d)
                local hay = lower((okT and action or "") .. " " .. (okT and object or "") .. " " .. (m and m.Name or ""))
                local want = CFG.questGiver and lower(CFG.questGiver)
                if (want and string.find(hay, want, 1, true)) or (not want and string.find(hay, "quest", 1, true)) then
                    out[#out + 1] = d
                end
            end
        end
    end
    prompts, promptAt = out, clock()
    return out
end

local function nearestPrompt()
    if clock() - promptAt > CFG.promptInterval then scanPrompts() end
    local root = myRoot()
    local here = root and partPos(root)
    if not here then return nil end
    local best, bestDist = nil, math.huge
    for _, pr in ipairs(prompts) do
        local part = pr.Parent and promptPart(pr)
        local p = part and partPos(part)
        if p then
            local d = (p - here).Magnitude
            if d < bestDist then best, bestDist = pr, d end
        end
    end
    return best
end

local function guiInsetY(button)
    local sg = button
    while sg and cls(sg) ~= "ScreenGui" do sg = sg.Parent end
    local okI, ignore = pcall(function() return sg and sg.IgnoreGuiInset end)
    if okI and ignore then return 0 end
    local okG, inset = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
    if okG and inset and inset.Y then return inset.Y end
    return 58
end

local function clickGui(button)
    if not focused() or type(mousemoveabs) ~= "function" then return false end
    local ok, pos, size = pcall(function() return button.AbsolutePosition, button.AbsoluteSize end)
    if not ok or not pos or not size then return false end
    local x = math.floor(pos.X + size.X / 2 + 0.5)
    local y = math.floor(pos.Y + size.Y / 2 + guiInsetY(button) + 0.5)
    pcall(mousemoveabs, x, y)
    task.wait(0.08)
    pcall(mouse1click)
    return true
end

-- Click the first visible dialogue button whose text is an accept/claim word.
local function clickDialogue()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then return false end
    local ok, all = pcall(function() return gui:GetDescendants() end)
    if not ok then return false end
    for _, d in ipairs(all) do
        local c = cls(d)
        if c == "TextButton" or c == "ImageButton" then
            local label = d
            if c == "ImageButton" then label = d:FindFirstChildWhichIsA("TextLabel") or d end
            local okT, text, vis = pcall(function() return label.Text, d.Visible end)
            if okT and vis and type(text) == "string" then
                local l = lower(stripTags(text))
                for _, w in ipairs(CFG.dialogueWords) do
                    if string.find(l, w, 1, true) then return clickGui(d) end
                end
            end
        end
    end
    return false
end

local function interact(prompt)
    local part = promptPart(prompt)
    local p = part and partPos(part)
    if not p then return false end
    setStatus("quest: travelling to " .. tostring((promptModel(prompt) or part).Name))
    if not travelTo(p + Vector3.new(0, 2, 3), function() return STATE.farm and STATE.quest end) then return false end
    task.wait(0.3)
    if not focused() then setStatus("quest: waiting for Roblox focus"); return false end
    local fired = false
    if type(fireproximityprompt) == "function" then fired = pcall(fireproximityprompt, prompt) end
    if not fired then
        local okH, hold = pcall(function() return prompt.HoldDuration end)
        tapKey(CFG.interactKey, (okH and hold or 0) + 0.1)
    end
    for _ = 1, 6 do
        task.wait(0.4)
        if not STATE.farm then return false end
        clickDialogue()
    end
    quest.at = -1e9
    return true
end

-- ---------------------------------------------------------------------------
-- Fight
-- ---------------------------------------------------------------------------
local function holdingTool()
    local _, char = myRoot()
    return char ~= nil and char:FindFirstChildWhichIsA("Tool") ~= nil
end

local function fight(mob, keepGoing)
    STATE.target = mob
    local holdWait = 1 / math.max(1, CFG.holdHz)
    local clickEvery = 1 / math.max(1, CFG.clickHz)
    local nextClick = 0
    local startedAt = clock()
    while alive() and keepGoing() do
        if not mob.Parent or not livingHumanoid(mob) then break end
        local mp = partPos(mobRootOf(mob))
        local root = myRoot()
        if not mp or not root then break end
        if clock() - startedAt > 90 then break end -- stuck target (immune / unreachable)
        local okL, look = pcall(function() return mobRootOf(mob).CFrame.LookVector end)
        local back = (okL and look) and Vector3.new(-look.X, 0, -look.Z) or Vector3.new(0, 0, 1)
        if back.Magnitude < 0.01 then back = Vector3.new(0, 0, 1) end
        local stand = mp + back.Unit * CFG.standOff + Vector3.new(0, CFG.standHeight, 0)
        local here = partPos(root)
        if here and (here - stand).Magnitude > CFG.hopDistance and CFG.hopDistance > 0 then
            travelTo(stand, keepGoing)
        else
            placeAt(stand, mp)
        end
        if CFG.equipKey and not holdingTool() then tapKey(CFG.equipKey); task.wait(0.2) end
        if here and (here - mp).Magnitude <= CFG.attackRange + CFG.standOff and clock() >= nextClick then
            nextClick = clock() + clickEvery
            if focused() then pcall(mouse1click) end
        end
        task.wait(holdWait)
    end
    STATE.target = nil
end

-- ---------------------------------------------------------------------------
-- Main AFQ loop
-- ---------------------------------------------------------------------------
local function farming() return alive() and STATE.farm end

task.spawn(function()
    local lastPickup = -1e9
    while alive() do
        if not STATE.farm then
            setStatus("off  (F6 to start)")
            task.wait(0.3)
        elseif not myRoot() then
            setStatus("waiting for character")
            task.wait(1)
        else
            local q = readQuest()
            local want = CFG.mobName or q.mob
            if STATE.quest and (not q.mob or questDone(q)) and clock() - lastPickup > 4 then
                local pr = nearestPrompt()
                if pr then
                    lastPickup = clock()
                    interact(pr)
                elseif not want then
                    setStatus("no quest prompt found (set CFG.questGiver / CFG.mobName, F8 to dump)")
                    task.wait(1)
                end
            end
            if STATE.farm then
                local mob = bestMob(want)
                if mob then
                    setStatus("fighting " .. mob.Name .. (q.need and string.format(" (%s/%s)", tostring(q.have), tostring(q.need)) or ""))
                    fight(mob, farming)
                    task.wait(0.15)
                else
                    setStatus("no mob found" .. (want and (" named " .. want) or ""))
                    task.wait(0.5)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Discovery dump (F8): prints what the script can see, for tuning CFG
-- ---------------------------------------------------------------------------
local function dump()
    print("[SAO AFQ] ---- discovery dump ----")
    local wsKids = {}
    for _, c in ipairs(Workspace:GetChildren()) do wsKids[#wsKids + 1] = c.Name .. ":" .. tostring(cls(c)) end
    print("[SAO AFQ] Workspace children: " .. table.concat(wsKids, ", ", 1, math.min(#wsKids, 60)))
    local mobs, names = scanMobs(), {}
    for _, m in ipairs(mobs) do names[m.Name] = (names[m.Name] or 0) + 1 end
    for n, k in pairs(names) do print(string.format("[SAO AFQ] mob %s x%d (in %s)", n, k, tostring(mobs[1] and mobs[1].Parent and mobs[1].Parent.Name))) end
    local ok, all = pcall(function() return Workspace:GetDescendants() end)
    if ok then
        local shown = 0
        for _, d in ipairs(all) do
            if cls(d) == "ProximityPrompt" and shown < 40 then
                shown = shown + 1
                local m = promptModel(d)
                print(string.format("[SAO AFQ] prompt '%s' / '%s' on %s", tostring(d.ActionText), tostring(d.ObjectText), m and m.Name or d.Parent.Name))
            end
        end
    end
    quest.at = -1e9
    local q = readQuest()
    print("[SAO AFQ] quest text: " .. tostring(q.text) .. " -> mob=" .. tostring(q.mob) .. " " .. tostring(q.have) .. "/" .. tostring(q.need))
    print("[SAO AFQ] ---- end ----")
end

-- ---------------------------------------------------------------------------
-- Status text + hotkeys
-- ---------------------------------------------------------------------------
local label = nil
pcall(function()
    label = Drawing.new("Text")
    label.Size = 16
    label.Outline = true
    label.Color = Color3.fromRGB(120, 220, 255)
    label.Position = Vector2.new(12, 300)
    label.Visible = true
end)

task.spawn(function()
    local was = {}
    while alive() do
        for name, vk in pairs(CFG.keys) do
            local down = keyDown(vk)
            if down and not was[name] then
                if name == "farm" then STATE.farm = not STATE.farm
                elseif name == "quest" then STATE.quest = not STATE.quest
                elseif name == "dump" then task.spawn(dump)
                elseif name == "unload" then API.unload() end
            end
            was[name] = down
        end
        if label then
            pcall(function()
                label.Text = string.format("SAO AFQ  farm:%s  quest:%s  |  %s", STATE.farm and "ON" or "off", STATE.quest and "ON" or "off", STATE.status)
            end)
        end
        task.wait(0.1)
    end
end)

API.unload = function()
    STATE.running, STATE.farm = false, false
    if label then pcall(function() label:Remove() end); label = nil end
    if _G.SAO_AFQ == API then _G.SAO_AFQ = nil end
end
API.state, API.config, API.dump = STATE, CFG, dump

print("[SAO AFQ] loaded - F6 farm, F7 quest pickup, F8 dump, End unload")
