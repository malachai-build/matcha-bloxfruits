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
      * no tweens and no fast teleports: travel is 4-stud CFrame steps at 12 Hz
        (48 studs/s horizontal), height left to physics plus a small lift, lifting more
        only when terrain pushes back. The server caps movement at 50 studs/s and kicked
        a 360 studs/s hop trip that went under the terrain.
      * one fixed-rate root write while fighting (holdHz), nothing at frame rate
      * the local root is re-fetched before every write; nothing is written to a mob
      * no RemoteEvent/RemoteFunction calls: quests and attacks go through real input
        (E key, mouse click), only while Roblox has focus
      * no Workspace:GetDescendants (about 230k instances here); every loop uses a fixed wait

    Matcha notes: CFrame.new takes 3 numbers (not a Vector3), IsA is broken (compare
    ClassName), instances are not comparable with == (compare .Address).

    Keys: F6 farm on/off, F7 quest pickup on/off, F8 dump to console, F9 infinite dash,
          End unload.
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
    clickHz = 6,            -- mouse clicks per second while fighting
    holdHz = 10,            -- root writes per second while fighting
    -- Travel (the server caps movement at RemakeConfig.MAX_MOVE_SPEED = 50 studs/s; 60-stud
    -- hops at 6/s through the terrain got the user kicked on Nov 1 2026).
    stepSpeed = 48,         -- horizontal studs/s while travelling; hard-capped at MAX_STEP_SPEED (49)
    stepHz = 12,            -- root writes per second while travelling (3 studs per step)
    stepLift = 0.4,         -- studs above the current height per step; gravity takes it back
    climbLift = 4,          -- max lift per step when terrain pushes us back (slopes, steps)
    nearRange = 12,         -- inside this a fight/giver adjust is one short placement
    talkPresses = 5,        -- E presses at a giver (opens the prompt, steps dialogue, confirms)
    infiniteDash = true,    -- Ctrl dash with no stamina cost and a short cooldown (F9 toggles)
    dashCooldown = 0.3,     -- = the dash duration, so dashes chain back to back
    keys = { farm = 0x75, quest = 0x76, dump = 0x77, dash = 0x78, unload = 0x23 },
}
if type(_G.SAO_AFQ_CONFIG) == "table" then
    for k, v in pairs(_G.SAO_AFQ_CONFIG) do CFG[k] = v end
end

local VK_E = 0x45
-- Server movement cap is RemakeConfig.MAX_MOVE_SPEED = 50. A brief 57.6 studs/s spike
-- (own dash on top of 36 studs/s steps) did not kick, but travel stays just under 50.
local MAX_STEP_SPEED = 49
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

-- ---------------------------------------------------------------------------
-- Travel: short CFrame steps along the ground, horizontal speed under 50 studs/s
-- ---------------------------------------------------------------------------
-- Matcha cannot find the ground for us (Workspace:Raycast returned nil in every live
-- test and a WalkToPoint write does not start a walk), so the game's physics keeps the
-- character on the ground instead:
--   * each step moves only X/Z and keeps the root's current height plus a small lift,
--     so the character is always slightly above the ground and gravity settles it
--   * horizontal and upward velocity are cleared, downward velocity is kept, so going
--     downhill the character falls onto the slope instead of floating
--   * a step that the terrain pushed back (we end up short of the spot we wrote) means
--     a slope or wall: the next step lifts higher, up to climbLift, so we go over it,
--     never through it
local function flatDist(a, b)
    return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- CFrame.new takes 3 numbers in Matcha; CFrame.lookAt takes two Vector3s.
local function placeStep(x, y, z, dir)
    local root = myRoot()
    if not root then return false end
    local okParent, parent = pcall(function() return root.Parent end)
    if not okParent or parent == nil then return false end
    local p = Vector3.new(x, y, z)
    local ok = pcall(function()
        if dir and dir.Magnitude > 0.01 then
            root.CFrame = CFrame.lookAt(p, p + dir)
        else
            root.CFrame = CFrame.new(x, y, z)
        end
    end)
    if not ok and not pcall(function() root.Position = p end) then return false end
    pcall(function()
        local v = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(0, math.min(v.Y, 0), 0)
    end)
    return true
end

-- Steps toward pos until within 3 studs. keepGoing() false stops it.
local function stepToward(pos, keepGoing)
    local hz = math.max(1, CFG.stepHz)
    local stepWait = 1 / hz
    local stepLen = math.min(CFG.stepSpeed, MAX_STEP_SPEED) / hz
    local deadline = clock() + flatDist(pos, partPos(myRoot()) or pos) / math.min(CFG.stepSpeed, MAX_STEP_SPEED) * 3 + 20
    local lift, blocked, falling = CFG.stepLift, 0, 0
    local wrote = nil
    while alive() and clock() < deadline do
        if keepGoing and not keepGoing() then return false end
        local root = myRoot()
        local cur = partPos(root)
        if not cur then return false end
        local d = flatDist(pos, cur)
        if d < 3 then return true end

        local dir = Vector3.new(pos.X - cur.X, 0, pos.Z - cur.Z).Unit
        -- Where physics left us relative to the spot we wrote, along the travel direction:
        -- behind = terrain pushed us back (climb a little more); ahead = something else moved
        -- us forward (player input, a slope), so the next step is shortened by that much and
        -- the combined speed stays under the cap. Live test Nov 1 2026: own walking on top of
        -- the 36 studs/s steps measured 57.6 studs/s before this.
        local ahead = 0
        if wrote then
            local off = Vector3.new(cur.X - wrote.X, 0, cur.Z - wrote.Z)
            local along = off.X * dir.X + off.Z * dir.Z
            if along < -stepLen * 0.5 then
                blocked = blocked + 1
                lift = math.min(lift + 1, CFG.climbLift)
                if blocked > 30 then setStatus("travel: blocked by terrain - stopped"); STATE.farm = false; return false end
            else
                blocked = math.max(0, blocked - 1)
                if blocked == 0 then lift = CFG.stepLift end
                ahead = math.max(0, along)
            end
        end

        -- A long free fall means the ground is gone under us: stop rather than follow it down.
        local okV, v = pcall(function() return root.AssemblyLinearVelocity end)
        if okV and v and v.Y < -120 then falling = falling + 1 else falling = 0 end
        if falling > hz * 2 then setStatus("travel: falling - stopped"); STATE.farm = false; return false end

        local s = math.min(math.max(0, stepLen - ahead), d)
        local nx, nz = cur.X + dir.X * s, cur.Z + dir.Z * s
        local ny = cur.Y + lift
        -- Arriving: never end higher than the target spot plus the lift.
        if d <= stepLen then ny = math.max(math.min(ny, pos.Y + CFG.stepLift), cur.Y) end
        placeStep(nx, ny, nz, dir)
        wrote = Vector3.new(nx, ny, nz)
        task.wait(stepWait)
    end
    return false
end

local function travelTo(pos, keepGoing)
    return stepToward(pos, keepGoing)
end

-- One short placement toward pos, at most stepSpeed / rateHz studs, at our own height
-- (physics keeps us on the ground), so close-range adjustments stay under the speed cap.
local function nudgeToward(pos, lookAt, rateHz)
    local cur = partPos(myRoot())
    if not cur then return false end
    local maxStep = math.min(CFG.stepSpeed, MAX_STEP_SPEED) / math.max(1, rateHz)
    local delta = Vector3.new(pos.X - cur.X, 0, pos.Z - cur.Z)
    local tx, tz = pos.X, pos.Z
    if delta.Magnitude > maxStep then
        local u = delta.Unit
        tx, tz = cur.X + u.X * maxStep, cur.Z + u.Z * maxStep
    end
    local face = lookAt and Vector3.new(lookAt.X - tx, 0, lookAt.Z - tz) or nil
    return placeStep(tx, cur.Y + 0.2, tz, face)
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
    if not travelTo(np + Vector3.new(0, 0, 4), farming) then return false end
    for _ = 1, 8 do
        np = partPos(r)
        if not np then return false end
        local okL, look = pcall(function() return r.CFrame.LookVector end)
        local front = (okL and look) and Vector3.new(look.X, 0, look.Z) or Vector3.new(0, 0, 1)
        if front.Magnitude < 0.01 then front = Vector3.new(0, 0, 1) end
        local spot = np + front.Unit * 4
        local here = partPos(myRoot())
        if here and flatDist(here, spot) < 1.5 then break end
        if here and flatDist(here, spot) > CFG.nearRange then travelTo(spot, farming) else nudgeToward(spot, np, 4) end
        task.wait(0.25)
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
        local stand = mp + back.Unit * CFG.standOff
        if flatDist(here, stand) > CFG.nearRange then
            travelTo(stand, farming)
        elseif flatDist(here, stand) > 0.75 then
            nudgeToward(stand, mp, CFG.holdHz)
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
-- ---------------------------------------------------------------------------
-- Infinite dash (Ctrl): patches the client dodge config in the Luau heap
-- ---------------------------------------------------------------------------
-- The CombatPlus dodge table holds { staminaCost = 10, speed = 50, duration = 0.3,
-- cooldown = 0.55, invulnerable = 0.22 } (read live Nov 1 2026; the only table with a
-- numeric staminaCost). staminaCost 0 + cooldown 0.3 let 33 dashes chain in 12 s at 0-5
-- stamina with no kick. It is a client value: the server did not refuse the dashes.
-- getgc/findgc are full heap scans (15-30 s), so this runs once in the background.
local DASH_ORIGINAL = { staminaCost = 10, cooldown = 0.55 }
local DASH = { state = "off", cache = nil }
local function setDash(on)
    if DASH.state == "patching" then return end
    DASH.state = "patching"
    task.spawn(function()
        local ok = pcall(function()
            if not DASH.cache then
                DASH.cache = findgc("staminaCost", { speed = "number", duration = "number", cooldown = "number" })
            end
            if on then
                setgc("staminaCost", 0, DASH_ORIGINAL.staminaCost)
                applygc(DASH.cache, "cooldown", CFG.dashCooldown)
            else
                setgc("staminaCost", DASH_ORIGINAL.staminaCost, 0)
                applygc(DASH.cache, "cooldown", DASH_ORIGINAL.cooldown)
            end
        end)
        DASH.state = ok and (on and "on" or "off") or "failed"
    end)
end

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
                elseif name == "dash" then setDash(DASH.state ~= "on")
                elseif name == "unload" then API.unload() end
            end
            was[name] = down
        end
        if label then
            pcall(function()
                label.Text = string.format("SAO AFQ  farm:%s  quest:%s  dash:%s  |  %s",
                    STATE.farm and "ON" or "off", STATE.quest and "ON" or "off", DASH.state, STATE.status)
            end)
        end
        task.wait(0.1)
    end
end)

API.unload = function()
    STATE.running, STATE.farm = false, false
    if DASH.state == "on" then setDash(false) end
    if label then pcall(function() label:Remove() end); label = nil end
    if _G.SAO_AFQ == API then _G.SAO_AFQ = nil end
end
API.state, API.config, API.dump, API.quests, API.setDash = STATE, CFG, dump, QUESTS, setDash

if CFG.infiniteDash then setDash(true) end
print("[SAO AFQ] loaded - F6 farm, F7 quest pickup, F8 dump, F9 infinite dash, End unload")
