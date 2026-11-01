--[[
    SAO: Eternity - Auto Farm Quest (Matcha Luau, standalone, Drawing status only)

    Game layout (mapped live with the Matcha inspector, Nov 1 2026, place 108438460215241):
      * mobs:     Workspace.Mobs.<Model>; no Humanoid. State is in attributes:
                  DisplayName ("Frenzy Boar", "Corrupted Frenzy Boar"), MobKind ("Frenzy Boar"),
                  Level, Health, MaxHealth, IsDead. Position: the "Collider" MeshPart.
      * quests:   NPC Models carry a QuestId attribute; the prompt is
                  <npc>.<unnamed Model>.HumanoidRootPart.QuestPrompt. NPCs wander, so the
                  root is re-read right before interacting.
      * tracker:  PlayerGui.QuestTracker.Tracker.Card: Title, Header.Status ("COMPLETE" or "NN%"),
                  Steps.StepN.Text ("Defeat Frenzy Boar") and Steps.StepN.Count ("3/3").
      * confirm:  PlayerGui.AcceptModal (BillboardGui), "A / D to choose  E to confirm".
      * level:    PlayerGui.HUD.Main.HealthbarFrame.MainHealthBar.Level ("LV: 1").
      * AFK:      the server sends AfkConfirm; AcceptModal title "Are you still here?" and the
                  player must click a circle within 60 s. The script cannot click a BillboardGui
                  reliably, so it stops and shows a warning instead.

    Crash rules carried over from the Blox Fruits script (CRASH_FINDINGS.md):
      * no tweens: travel is a few long hops (hopHz writes/s), never a 60 Hz glide
      * one fixed-rate root write while fighting (holdHz), nothing at frame rate
      * the local root is re-fetched before every write; nothing is written to a mob
      * no RemoteEvent/RemoteFunction calls: quests and attacks go through real input
        (E key, mouse click), only while Roblox has focus
      * no Workspace:GetDescendants (about 230k instances here); every loop uses a fixed wait

    Matcha notes: CFrame.new takes 3 numbers (not a Vector3), IsA is broken (compare
    ClassName), instances are not comparable with == (compare .Address).

    Keys: F6 farm on/off, F7 quest pickup on/off, F8 dump to console, End unload.
    Override any CFG field before loading:
        _G.SAO_AFQ_CONFIG = { mobName = "Dire Wolf", autoQuest = false }
]]

if type(_G.SAO_AFQ) == "table" and type(_G.SAO_AFQ.unload) == "function" then
    pcall(_G.SAO_AFQ.unload)
end

-- Floor 1 quests, lowest level first. minLevel and mob come from the MobZones names
-- (StarterPlains_FrenzyBoar_Lv1 ... HauntedPeak_RuinKoboldTrooper_Lv22-25); the quest's
-- real target is read from the tracker once it is accepted, so a wrong guess here only
-- picks the giver.
local QUESTS = {
    { id = "boarQuest", minLevel = 1, mob = "Frenzy Boar",
      npcs = { "Medai.HorunkaQuestNPC1", "Medai.HorunkaQuestNPC2" } },
    { id = "beginningWolfQuest", minLevel = 5, mob = "Dire Wolf",
      npcs = { "Horunka.BeginningQuestNPC6" } },
    { id = "waspHuntQuest", minLevel = 10, mob = "Wasp",
      npcs = { "Medai.WaspQuestNPC" } },
    { id = "nepenthesHuntQuest", minLevel = 15, mob = "Little Nepenthes",
      npcs = { "World.Folder.BeginningQuestNPC" } },
    { id = "horunkaKoboldBarsQuest", minLevel = 22, mob = "Ruin Kobold",
      npcs = { "World.Folder.BeginningQuestNPC2", "World.Folder.BeginningQuestNPC3",
               "World.Folder.BeginningQuestNPC4", "World.Folder.BeginningQuestNPC5" } },
}

local CFG = {
    mobName = nil,          -- force a mob (DisplayName or MobKind); nil = from the tracker / quest table
    autoQuest = true,       -- accept and turn in quests at the givers
    questId = nil,          -- force one quest from QUESTS by id
    skipCorrupted = true,   -- prefer plain mobs over "Corrupted ..." (higher level)
    standOff = 4,           -- studs behind the mob
    standHeight = 1,        -- studs above the mob collider
    clickHz = 6,            -- mouse clicks per second while fighting
    holdHz = 10,            -- root writes per second while fighting
    hopDistance = 60,       -- studs per travel hop (tested: 1,200 studs in 60-stud hops, no rubberband)
    hopHz = 6,              -- travel hops per second
    talkPresses = 5,        -- E presses at a giver (opens the prompt, steps dialogue, confirms)
    keys = { farm = 0x75, quest = 0x76, dump = 0x77, unload = 0x23 },
}
if type(_G.SAO_AFQ_CONFIG) == "table" then
    for k, v in pairs(_G.SAO_AFQ_CONFIG) do CFG[k] = v end
end

local VK_E = 0x45
local clock = (type(os) == "table" and type(os.clock) == "function") and os.clock or tick
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(0.1); LocalPlayer = Players.LocalPlayer end
local Workspace = game:GetService("Workspace")

local STATE = { running = true, farm = false, quest = CFG.autoQuest, status = "idle", giver = nil }
local API = { unload = function() end }
_G.SAO_AFQ = API

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function lower(s) return string.lower(tostring(s or "")) end
local function alive() return STATE.running end
local function farming() return STATE.running and STATE.farm end
local function setStatus(s) STATE.status = s end
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
    pcall(function() keypress(vk); task.wait(hold or 0.1); keyrelease(vk) end)
    return true
end
local function attr(inst, name)
    local ok, v = pcall(function() return inst:GetAttribute(name) end)
    if ok then return v end
    return nil
end
local function text(label)
    local ok, t = pcall(function() return label.Text end)
    if ok and type(t) == "string" then return t end
    return nil
end
local function child(inst, path)
    for part in string.gmatch(path, "[^%.]+") do
        if not inst then return nil end
        inst = inst:FindFirstChild(part)
    end
    return inst
end
local function partPos(part)
    if not part then return nil end
    local ok, parent, p = pcall(function() return part.Parent, part.Position end)
    if ok and parent ~= nil then return p end
    return nil
end

local function myRoot()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not root or not hum then return nil end
    local ok, hp = pcall(function() return hum.Health end)
    if not ok or not hp or hp <= 0 then return nil end
    return root
end

-- One root write, velocity zeroed so gravity cannot build up between writes.
-- CFrame.new takes 3 numbers in Matcha; CFrame.lookAt takes two Vector3s.
local function placeAt(pos, lookAt)
    local root = myRoot()
    if not root or not pos then return false end
    local ok = pcall(function()
        if lookAt then
            root.CFrame = CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z))
        else
            root.CFrame = CFrame.new(pos.X, pos.Y, pos.Z)
        end
    end)
    if not ok and not pcall(function() root.Position = pos end) then return false end
    pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
    return true
end

-- Travel in long hops at hopHz instead of a 60 Hz tween. keepGoing() false stops it.
local function travelTo(pos, keepGoing)
    local stepWait = 1 / math.max(1, CFG.hopHz)
    for _ = 1, 600 do
        if not alive() or (keepGoing and not keepGoing()) then return false end
        local cur = partPos(myRoot())
        if not cur then return false end
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
-- Player level and quest tracker
-- ---------------------------------------------------------------------------
local function playerGui() return LocalPlayer:FindFirstChild("PlayerGui") end

local function playerLevel()
    local label = child(playerGui(), "HUD.Main.HealthbarFrame.MainHealthBar.Level")
    local n = tonumber(string.match(text(label) or "", "(%d+)"))
    return n or 1
end

-- Returns { title, complete, steps = { {text, have, need} } } or nil.
local function readTracker()
    local card = child(playerGui(), "QuestTracker.Tracker.Card")
    if not card then return nil end
    local out = { title = text(card:FindFirstChild("Title")), steps = {} }
    local status = text(child(card, "Header.Status")) or ""
    out.complete = string.find(string.upper(status), "COMPLETE", 1, true) ~= nil
    local steps = card:FindFirstChild("Steps")
    if steps then
        for _, s in ipairs(steps:GetChildren()) do
            if string.sub(s.Name, 1, 4) == "Step" then
                local t = text(s:FindFirstChild("Text"))
                local have, need = string.match(text(s:FindFirstChild("Count")) or "", "(%d+)%s*/%s*(%d+)")
                if t then
                    out.steps[#out.steps + 1] = { text = t, have = tonumber(have) or 0, need = tonumber(need) or 1 }
                end
            end
        end
    end
    return out
end

-- The first unfinished "Defeat X" step names the mob to farm.
local function trackerTarget(tr)
    if not tr then return nil end
    for _, s in ipairs(tr.steps) do
        local name = string.match(s.text, "^%s*[Dd]efeat%s+%d*%s*(.-)%s*$")
            or string.match(s.text, "^%s*[Kk]ill%s+%d*%s*(.-)%s*$")
            or string.match(s.text, "^%s*[Ss]lay%s+%d*%s*(.-)%s*$")
        if name and name ~= "" and s.have < s.need then return name, s end
    end
    return nil
end

local function afkCheckOpen()
    local title = text(child(playerGui(), "AcceptModal.Group.Container.Content.Title"))
    return title ~= nil and string.find(lower(title), "still here", 1, true) ~= nil
end

-- ---------------------------------------------------------------------------
-- Mobs (Workspace.Mobs, attribute based)
-- ---------------------------------------------------------------------------
local function mobAlive(m)
    if not m or m.Parent == nil then return false end
    if attr(m, "IsDead") == true then return false end
    local hp = tonumber(attr(m, "Health"))
    return hp == nil or hp > 0
end

local function singular(s)
    s = lower(s)
    s = string.gsub(s, "ves$", "f")
    s = string.gsub(s, "([^s])s$", "%1")
    return s
end

-- 2 = exact plain mob, 1 = same kind (corrupted variant / plural), 0 = no match
local function mobMatch(m, want)
    if not want or want == "" then return 1 end
    local disp, kind, w = lower(attr(m, "DisplayName") or m.Name), lower(attr(m, "MobKind") or ""), singular(want)
    if singular(disp) == w then return 2 end
    if singular(kind) == w or string.find(singular(disp), w, 1, true) then return 1 end
    return 0
end

local function bestMob(want)
    local folder = Workspace:FindFirstChild("Mobs")
    local here = partPos(myRoot())
    if not folder or not here then return nil end
    local best, bestScore = nil, -math.huge
    for _, m in ipairs(folder:GetChildren()) do
        if mobAlive(m) then
            local match = mobMatch(m, want)
            if match > 0 then
                local p = partPos(m:FindFirstChild("Collider") or m.PrimaryPart)
                if p then
                    local score = -(p - here).Magnitude
                    if match == 2 or not CFG.skipCorrupted then score = score + 100000 end
                    if score > bestScore then best, bestScore = m, score end
                end
            end
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Quest givers
-- ---------------------------------------------------------------------------
local function pickQuest()
    if CFG.questId then
        for _, q in ipairs(QUESTS) do if q.id == CFG.questId then return q end end
    end
    local lvl, pick = playerLevel(), QUESTS[1]
    for _, q in ipairs(QUESTS) do
        if lvl >= q.minLevel then pick = q end
    end
    return pick
end

local function giverRoot(path)
    local npc = child(Workspace, path)
    if not npc then return nil end
    for _, c in ipairs(npc:GetChildren()) do
        if c.ClassName == "Model" then
            local r = c:FindFirstChild("HumanoidRootPart")
            if r then return r end
        end
    end
    return npc:FindFirstChild("HumanoidRootPart")
end

local function nearestGiver(q)
    local here = partPos(myRoot())
    local best, bestDist = nil, math.huge
    for _, path in ipairs(q.npcs) do
        local r = giverRoot(path)
        local p = partPos(r)
        if p and here then
            local d = (p - here).Magnitude
            if d < bestDist then best, bestDist = path, d end
        end
    end
    return best
end

-- Walk up to a giver (it wanders, so re-read its root) and press E a few times:
-- the first press fires the QuestPrompt, the rest step the dialogue and confirm
-- the AcceptModal (accept is the default choice).
local function talkTo(path)
    local r = giverRoot(path)
    local np = partPos(r)
    if not np then setStatus("quest: giver " .. path .. " not loaded"); return false end
    setStatus("quest: travelling to " .. path)
    if not travelTo(np + Vector3.new(0, 1, 4), farming) then return false end
    for _ = 1, 3 do
        np = partPos(r)
        if not np then return false end
        local okL, look = pcall(function() return r.CFrame.LookVector end)
        local front = (okL and look) and Vector3.new(look.X, 0, look.Z) or Vector3.new(0, 0, 1)
        if front.Magnitude < 0.01 then front = Vector3.new(0, 0, 1) end
        placeAt(np + front.Unit * 4, np)
        task.wait(0.3)
    end
    if not focused() then setStatus("quest: waiting for Roblox focus"); return false end
    setStatus("quest: talking to " .. path)
    for _ = 1, CFG.talkPresses do
        if not farming() then return false end
        tapKey(VK_E, 0.15)
        task.wait(0.7)
    end
    STATE.giver = path
    return true
end

-- ---------------------------------------------------------------------------
-- Fight
-- ---------------------------------------------------------------------------
local function fight(mob)
    local holdWait = 1 / math.max(1, CFG.holdHz)
    local clickEvery = 1 / math.max(1, CFG.clickHz)
    local nextClick, startedAt = 0, clock()
    while farming() and mobAlive(mob) do
        if afkCheckOpen() then return end
        local col = mob:FindFirstChild("Collider") or mob.PrimaryPart
        local mp = partPos(col)
        local here = partPos(myRoot())
        if not mp or not here then break end
        if clock() - startedAt > 60 then break end -- immune / unreachable target
        local okL, look = pcall(function() return col.CFrame.LookVector end)
        local back = (okL and look) and Vector3.new(-look.X, 0, -look.Z) or Vector3.new(0, 0, 1)
        if back.Magnitude < 0.01 then back = Vector3.new(0, 0, 1) end
        local stand = mp + back.Unit * CFG.standOff + Vector3.new(0, CFG.standHeight, 0)
        if (here - stand).Magnitude > CFG.hopDistance then
            travelTo(stand, farming)
        else
            placeAt(stand, mp)
        end
        if clock() >= nextClick and (here - mp).Magnitude <= CFG.standOff + 6 then
            nextClick = clock() + clickEvery
            if focused() then pcall(mouse1click) end
        end
        task.wait(holdWait)
    end
end

-- ---------------------------------------------------------------------------
-- Main AFQ loop
-- ---------------------------------------------------------------------------
task.spawn(function()
    local lastTalk = -1e9
    while alive() do
        if not STATE.farm then
            setStatus("off  (F6 to start)")
            task.wait(0.3)
        elseif not myRoot() then
            setStatus("waiting for character")
            task.wait(1)
        elseif afkCheckOpen() then
            setStatus("AFK CHECK - click the circle in Roblox now")
            task.wait(0.5)
        elseif not focused() then
            setStatus("waiting for Roblox focus (keys and clicks go to the focused window)")
            task.wait(0.5)
        else
            local tr = readTracker()
            local target = CFG.mobName or trackerTarget(tr)
            local q = pickQuest()
            if STATE.quest and tr and tr.complete and clock() - lastTalk > 6 then
                lastTalk = clock()
                talkTo(STATE.giver or nearestGiver(q))
            elseif STATE.quest and not target and clock() - lastTalk > 6 then
                lastTalk = clock()
                local giver = nearestGiver(q)
                if giver then talkTo(giver) else setStatus("quest: no giver loaded for " .. q.id); task.wait(1) end
                target = trackerTarget(readTracker())
            end
            target = target or q.mob
            if STATE.farm and myRoot() then
                local mob = bestMob(target)
                if mob then
                    local _, step = trackerTarget(tr)
                    setStatus(string.format("fighting %s%s", tostring(attr(mob, "DisplayName") or mob.Name),
                        step and string.format(" (%d/%d)", step.have, step.need) or ""))
                    fight(mob)
                    task.wait(0.2)
                else
                    setStatus("no live " .. tostring(target) .. " in Workspace.Mobs")
                    task.wait(1)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Dump (F8)
-- ---------------------------------------------------------------------------
local function dump()
    print("[SAO AFQ] ---- dump ----")
    print("[SAO AFQ] level " .. playerLevel() .. ", quest pick " .. pickQuest().id .. ", giver " .. tostring(STATE.giver))
    local tr = readTracker()
    if tr then
        print("[SAO AFQ] tracker '" .. tostring(tr.title) .. "' complete=" .. tostring(tr.complete) .. " target=" .. tostring(trackerTarget(tr)))
        for _, s in ipairs(tr.steps) do print(string.format("[SAO AFQ]   %s %d/%d", s.text, s.have, s.need)) end
    end
    local counts, folder = {}, Workspace:FindFirstChild("Mobs")
    for _, m in ipairs(folder and folder:GetChildren() or {}) do
        local k = tostring(attr(m, "DisplayName") or m.Name) .. " Lv" .. tostring(attr(m, "Level"))
        counts[k] = (counts[k] or 0) + 1
    end
    for k, n in pairs(counts) do print("[SAO AFQ] mob " .. k .. " x" .. n) end
    for _, q in ipairs(QUESTS) do
        for _, path in ipairs(q.npcs) do
            print("[SAO AFQ] giver " .. q.id .. " " .. path .. " at " .. tostring(partPos(giverRoot(path))))
        end
    end
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
                label.Text = string.format("SAO AFQ  farm:%s  quest:%s  |  %s",
                    STATE.farm and "ON" or "off", STATE.quest and "ON" or "off", STATE.status)
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
API.state, API.config, API.dump, API.quests = STATE, CFG, dump, QUESTS

print("[SAO AFQ] loaded - F6 farm, F7 quest pickup, F8 dump, End unload")
