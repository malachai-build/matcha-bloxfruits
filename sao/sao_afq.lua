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
      * no tweens and no fast teleports: travel is 2-stud CFrame steps at 12 Hz
        (24 studs/s horizontal, under the 26.5 sprint speed), height left to physics plus a small lift, lifting more
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
          F10 auto-parry, End unload.
    Override any CFG field before loading:
        _G.SAO_AFQ_CONFIG = { mobName = "Dire Wolf", autoQuest = false }
]]

if type(_G.SAO_AFQ) == "table" and type(_G.SAO_AFQ.unload) == "function" then
    pcall(_G.SAO_AFQ.unload)
end

-- Floor 1 kill quests, lowest level first. Ids and givers come from each NPC's
-- QuestPrompt "QuestId" attribute (what the game's prompt handler reads; Matcha returns
-- wrong values for the NPC *model* attributes, which an earlier table was built from).
-- minLevel and mob come from the MobZones names (StarterPlains_FrenzyBoar_Lv1 ...
-- HauntedPeak_RuinKoboldTrooper_Lv22-25) and are guesses; the real target is read from
-- the tracker once a quest is accepted. Tutorial quests (beginningQuest,
-- healingTutorialQuest, GUIDE, BLACKSMITH_GUIDE) are left out.
local QUESTS = {
    { id = "boarQuest", minLevel = 1, mob = "Frenzy Boar", npcs = { "World.Folder.BeginningQuestNPC" } },
    { id = "beginningWolfQuest", minLevel = 5, mob = "Dire Wolf", npcs = { "Horunka.BeginningQuestNPC6" } },
    { id = "waspHuntQuest", minLevel = 10, mob = "Wasp", npcs = { "Medai.WaspQuestNPC" } },
    { id = "medaiHuntQuest", minLevel = 10, mob = nil, npcs = { "Horunka.MedaiQuestNPC" } },
    { id = "nepenthesHuntQuest", minLevel = 15, mob = "Little Nepenthes", npcs = { "Tolbana.TolbanaQuestNPC2" } },
    { id = "secretMedicineQuest", minLevel = 15, mob = "Little Nepenthes", npcs = { "Medai.HorunkaQuestNPC2" } },
    { id = "tolbanaWolfQuest", minLevel = 20, mob = "Dire Wolf", npcs = { "Tolbana.TolbanaQuestNPC" } },
    { id = "horunkaKoboldBarsQuest", minLevel = 22, mob = "Ruin Kobold", npcs = { "Medai.HorunkaQuestNPC1" } },
}

local CFG = {
    mobName = nil,          -- force a mob (DisplayName or MobKind); nil = from the tracker / quest table
    autoQuest = true,       -- accept and turn in quests at the givers
    questId = nil,          -- force one quest from QUESTS by id
    skipCorrupted = true,   -- prefer plain mobs over "Corrupted ..." (higher level)
    standOff = 4,           -- studs behind the mob
    attackMode = "remote",  -- "remote": Combat Swing + Hit remotes (no focus); "click": mouse1click
    swingInterval = 0.65,   -- s between remote swings
    hitDelay = 0.25,        -- s from Swing to Hit (the animation's hit frame)
    clickHz = 6,            -- mouse clicks per second while fighting (attackMode "click")
    holdHz = 10,            -- root writes per second while fighting
    -- Travel (the server caps movement at RemakeConfig.MAX_MOVE_SPEED = 50 studs/s; 60-stud
    -- hops at 6/s through the terrain got the user kicked on Nov 1 2026).
    travelMode = "teleport", -- "teleport": one long CFrame write, then steps (live: 1,142 studs, no kick)
                            -- "dash": hold W + tap Ctrl, mouse steers the camera (needs focus)
                            -- "step": CFrame steps at stepSpeed only
    teleportMinGap = 8,     -- s between long teleports (a fast chain of hops got a kick)
    longTeleport = 300,     -- studs: teleports longer than this wait teleportMinGap
    shortTeleportGap = 1.5, -- s between shorter teleports (next mob after a kill)
    dashGap = 0.15,         -- s between Ctrl taps (0.15 = 52 studs/s live)
    dashArrive = 12,        -- studs: stop dashing this close and finish with steps
    dashBurst = 10,         -- s of continuous dashing before a short rest
    dashRest = 1,           -- s rest between dash bursts
    hopMinGap = 1.5,        -- s between short teleports (unstuck and boost)
    hopMaxLen = 26,         -- studs: longest single short teleport (up + forward)
    hopMaxTries = 6,        -- stalled checks before dash travel gives up (1 jump, then hops)
    boostHop = 6,           -- studs of forward hop while dashing (0 = off)
    boostEvery = 3,         -- s between boost hops
    stepSpeed = 24,         -- horizontal studs/s while travelling; hard-capped at MAX_STEP_SPEED (26)
    stepHz = 12,            -- root writes per second while travelling (3 studs per step)
    stepLift = 0.4,         -- studs above the current height per step; gravity takes it back
    climbLift = 4,          -- max lift per step when terrain pushes us back (slopes, steps)
    nearRange = 12,         -- inside this a fight/giver adjust is one short placement
    questMode = "remote",   -- "remote": QuestTalk / QuestAccept remotes (no focus); "keys": press E
    talkPresses = 5,        -- E presses at a giver in "keys" mode (prompt, dialogue, confirm)
    turnInTries = 6,        -- quest NPCs to try when the giver of a finished quest is unknown
    acceptTries = 4,        -- quests to try per pickup (highest eligible level first)
    questSkipTime = 600,    -- s to skip a quest that would not start (done / cooldown / locked)
    questGivers = {},       -- learned: tracker quest title -> giver path (saved with settings)
    infiniteDash = true,    -- Ctrl dash with no stamina cost and no cooldown (F9 toggles)
    dashCooldown = 0,       -- game value 0.55; 0.3 = the dash duration, 0 = every press dashes
    autoParry = true,       -- tap F when a nearby mob telegraphs an attack (F10 toggles)
    parryRange = 25,        -- studs: mobs watched for telegraphs
    parryLead = 0.2,        -- s before the hit to press F (server parry window is 0.4 s)
    parryCooldown = nil,    -- key mode only: e.g. 0.25 patches the client 0.9 s parry cooldown (heap scan);
                            -- remote mode does not use it, so nil skips the scan on load/unload
    parryMinGap = 0.12,     -- s between auto-parry taps
    -- "remote": Combat:FireServer("Parry", t), no focus needed (live: 32 parries, 0 damage,
    -- 28 of them unfocused); "key": tap F (needs Roblox focus)
    parryMode = "remote",
    parryFace = true,       -- remote mode: turn toward the attacker first (enemy behind you)
    parryServerCooldown = 0.9, -- remote mode: inside this since the last parry, block instead
    blockHold = 0.45,       -- s to hold that block before releasing it
    skillMode = "remote",   -- "remote": SwordSkillCast remote (no focus); "keys": tap skillSlots
    slotSkills = { "none", "Avalanche", "none", "none" }, -- skill id per slot 1-4 (menu: Skills);
                                    -- Greatsword: Avalanche, Cyclone, TitansVerdict, ExecutionersCross
    remoteSkills = { "Avalanche" }, -- rebuilt from slotSkills at load and on every menu change
    skillRecast = 9,        -- s between casts of one skill (server cooldown measured ~8.5 s)
    skillSlots = { 1, 2 },  -- sword skill keys to tap while fighting in "keys" mode ({} = none)
    skillTapHz = 12,        -- skill key taps per second (the client drops taps it is not ready for)
    zeroSkillCooldown = true, -- patch the client skill cooldowns to 0 (server still enforces its own)
    avoidPlayers = true,    -- never target a mob with another player near it
    playerRadius = 50,      -- studs
    crowdRadius = 15,       -- studs: other mobs this close to a target count as a crowd
    crowdPenalty = 40,      -- studs of distance each crowding mob adds to a target's cost
    retreatHp = 0.35,       -- below this HP fraction, leave the fight
    resumeHp = 0.8,         -- go back to farming at this HP fraction
    retreatDistance = 80,   -- studs to move away from nearby mobs
    retreatMaxWait = 60,    -- s to wait for health before farming again anyway
    townPos = Vector3.new(45, 87, -3026), -- Town of Beginnings spawn area: HP regen (2%/s) works here
                                          -- only; nil = just back off retreatDistance studs
    keys = { farm = 0x75, quest = 0x76, dump = 0x77, dash = 0x78, parry = 0x79, unload = 0x23 },
}
if type(_G.SAO_AFQ_CONFIG) == "table" then
    for k, v in pairs(_G.SAO_AFQ_CONFIG) do CFG[k] = v end
end

local VK_E = 0x45
local VK_F = 0x46
-- The server flags sustained speed, not just RemakeConfig.MAX_MOVE_SPEED = 50: a brief
-- 57.6 studs/s spike and 36 studs/s for 2.5 s did not kick, but Matcha's own movement at
-- 47 studs/s kicked for "unusual movement" after about 10 s (Nov 1 2026). Legit speeds are
-- BaseWalkSpeed 16.3 / BaseSprintSpeed 26.5 (dash 50 only for 0.3 s), so sustained
-- travel stays under the sprint speed.
local MAX_STEP_SPEED = 26
local clock = (type(os) == "table" and type(os.clock) == "function") and os.clock or tick
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do task.wait(0.1); LocalPlayer = Players.LocalPlayer end
local Workspace = game:GetService("Workspace")

local STATE = { running = true, farm = false, quest = CFG.autoQuest, parry = CFG.autoParry, status = "idle", giver = nil }
-- Auto-parry state (see the Auto-parry section). holdClicksUntil pauses the fight
-- clicks: the game ignores F while a light attack is mid-swing, and a live test with
-- non-stop clicking landed 0 parries out of 3 telegraphs.
local PARRY = { near = {}, seen = {}, windup = {}, pressedAt = -1e9, count = 0, holdClicksUntil = -1e9,
    lastRemoteParry = -1e9, blockSeq = 0 }
-- Remote sword skill casts: next allowed time per skill id, and our own cast counter.
local SKILLCAST = { nextAt = {}, castId = 5000 }
-- Set by the settings menu loop: the mouse is over the menu, so click-mode attacks wait.
local MENU_MOUSE = { over = false }
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

-- Dash travel: hold W and tap Ctrl while the mouse turns the camera toward the target.
-- Live tests Nov 1 2026: W + Ctrl every 0.15 s = 52 studs/s (dash is 50 studs/s for
-- 0.3 s, so faster taps only overlap), no kick; with no move key the dash goes backward,
-- and the game turns the character to the camera, so steering has to move the camera.
-- 100 px of mousemoverel turned the camera 10 deg; the proportional steer held <1 deg.
-- A wall stopped one run dead, so a stalled dash jumps, then sidesteps, then gives up.
local VK_W, VK_SPACE, VK_LCTRL = 0x57, 0x20, 0xA2
local DASHNAV = { radPerPx = nil }
local function camYaw()
    local cam = Workspace.CurrentCamera
    local ok, lv = pcall(function() return cam.CFrame.LookVector end)
    if not ok or not lv then return nil end
    return math.atan2(-lv.X, -lv.Z)
end
local function wrapAngle(a)
    while a > math.pi do a = a - 2 * math.pi end
    while a < -math.pi do a = a + 2 * math.pi end
    return a
end
local function calibrateMouse()
    if DASHNAV.radPerPx then return DASHNAV.radPerPx end
    local before = camYaw()
    pcall(mousemoverel, 100, 0)
    task.wait(0.15)
    local after = camYaw()
    if before and after then
        local r = wrapAngle(after - before) / 100
        if math.abs(r) > 1e-5 then DASHNAV.radPerPx = r end
    end
    return DASHNAV.radPerPx
end
local function holdKey(vk, down)
    pcall(function() if down then keypress(vk) else keyrelease(vk) end end)
end

-- One short teleport: up and toward the target in a single write, gravity brings us down.
-- Live Nov 1 2026: a town wall stopped dash travel dead and jump + sidestep did not get past
-- it. Hops are short (<= hopMaxLen) and at least hopMinGap apart so they never add up to the
-- sustained speed the server kicks for.
local lastHop = -1e9
local function hopToward(pos, up, forward)
    if clock() - lastHop < CFG.hopMinGap then return false end
    local root = myRoot()
    local here = partPos(root)
    if not here then return false end
    local dir = Vector3.new(pos.X - here.X, 0, pos.Z - here.Z)
    if dir.Magnitude < 0.1 then return false end
    forward = math.min(forward, dir.Magnitude)
    if up + forward > CFG.hopMaxLen then forward = math.max(0, CFG.hopMaxLen - up) end
    local p = here + dir.Unit * forward + Vector3.new(0, up, 0)
    lastHop = clock()
    return (pcall(function()
        root.CFrame = CFrame.lookAt(p, p + dir.Unit)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end))
end

local function dashToward(pos, keepGoing)
    if not focused() or type(mousemoverel) ~= "function" then return false end
    local radPerPx = calibrateMouse()
    if not radPerPx then setStatus("travel: mouse does not turn the camera, using steps"); return false end
    holdKey(VK_W, true)
    local nextDash, burstStart = 0, clock()
    local checkAt, checkPos, stuck = clock() + 1, partPos(myRoot()), 0
    local result = false
    while alive() do
        if keepGoing and not keepGoing() then break end
        if not focused() then setStatus("travel: lost Roblox focus, using steps"); break end
        local here = partPos(myRoot())
        if not here then break end
        local to = Vector3.new(pos.X - here.X, 0, pos.Z - here.Z)
        if to.Magnitude <= CFG.dashArrive then
            result = true
            break
        end
        local yaw = camYaw()
        local err = yaw and wrapAngle(math.atan2(-to.X, -to.Z) - yaw) or 0
        local px = math.clamp(err / radPerPx * 0.5, -80, 80)
        if math.abs(px) >= 1 then pcall(mousemoverel, math.floor(px + 0.5), 0) end
        if clock() >= nextDash and math.abs(err) < math.rad(30) then
            nextDash = clock() + CFG.dashGap
            pcall(function() keypress(VK_LCTRL); task.wait(0.03); keyrelease(VK_LCTRL) end)
        end
        if clock() >= checkAt then
            if checkPos and flatDist(here, checkPos) < 3 then
                stuck = stuck + 1
                if stuck >= CFG.hopMaxTries + 1 then break end
                if stuck == 1 then
                    setStatus("travel: blocked, jumping")
                    pcall(function() keypress(VK_SPACE); task.wait(0.05); keyrelease(VK_SPACE) end)
                else
                    -- Each further stall hops higher: 10, 14, 18, 22 studs up.
                    local up = math.min(10 + (stuck - 2) * 4, 22)
                    setStatus(string.format("travel: blocked (%d), hopping %d up", stuck, up))
                    hopToward(pos, up, 6)
                end
            else
                stuck = 0
                setStatus(string.format("travel: dashing, %d studs left", math.floor(to.Magnitude)))
                -- Small forward boost hop now and then while the run is clear.
                if CFG.boostHop > 0 and clock() - lastHop >= CFG.boostEvery then
                    hopToward(pos, 1, CFG.boostHop)
                end
            end
            checkAt, checkPos = clock() + 1, partPos(myRoot())
        end
        -- Rest between bursts: the server flags long stretches of high speed.
        if clock() - burstStart >= CFG.dashBurst then
            holdKey(VK_W, false)
            task.wait(CFG.dashRest)
            holdKey(VK_W, true)
            burstStart = clock()
            checkAt, checkPos = clock() + 1, partPos(myRoot())
        end
        task.wait(1 / 30)
    end
    holdKey(VK_W, false)
    return result
end

-- One long teleport straight to the destination. Live Nov 1 2026: a single 1,142-stud
-- CFrame write next to a Frenzy Boar landed (3.8 studs off after 0.5 s), no pull-back and
-- no kick. The earlier kick came from a fast chain of 60-stud hops under the terrain, so
-- long teleports are kept at least teleportMinGap apart.
local lastLongTp = -1e9
local function teleportTo(pos, keepGoing)
    -- Long jumps (> longTeleport studs) wait teleportMinGap; the short hop to the next mob
    -- after a kill only waits shortTeleportGap (live: 74-111 stud hops sat out the full 8 s).
    local here0 = partPos(myRoot())
    local gap = (here0 and flatDist(here0, pos) > CFG.longTeleport) and CFG.teleportMinGap or CFG.shortTeleportGap
    while alive() and clock() - lastLongTp < gap do
        if keepGoing and not keepGoing() then return false end
        setStatus(string.format("travel: next teleport in %.0fs", gap - (clock() - lastLongTp)))
        task.wait(0.25)
    end
    local root = myRoot()
    local here = partPos(root)
    if not here then return false end
    local dest = pos + Vector3.new(0, 3, 0)
    local face = Vector3.new(pos.X - here.X, 0, pos.Z - here.Z)
    lastLongTp = clock()
    setStatus(string.format("travel: teleporting %d studs", math.floor(flatDist(here, pos))))
    local ok = pcall(function()
        if face.Magnitude > 0.1 then root.CFrame = CFrame.lookAt(dest, dest + face.Unit) else root.CFrame = CFrame.new(dest.X, dest.Y, dest.Z) end
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end)
    task.wait(0.3)
    return ok
end

local function travelTo(pos, keepGoing)
    local here = partPos(myRoot())
    local far = here and flatDist(here, pos) > 30
    if far and CFG.travelMode == "teleport" then
        teleportTo(pos, keepGoing)
    elseif far and CFG.travelMode == "dash" then
        dashToward(pos, keepGoing)
    end
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
    -- Live Nov 1 2026: a finished quest was not turned in and the script went to pick a new
    -- one instead. Count a quest whose every step is full as complete too, whatever the
    -- Status label says.
    if not out.complete and #out.steps > 0 then
        local allDone = true
        for _, s in ipairs(out.steps) do
            if s.have < s.need then allDone = false end
        end
        out.complete = allDone
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

-- Other players' root positions (keyed by UserId; Matcha instances do not compare with ==).
local function otherPlayerPositions()
    local out = {}
    local myId = LocalPlayer.UserId
    for _, pl in ipairs(Players:GetPlayers()) do
        local okId, id = pcall(function() return pl.UserId end)
        if okId and id ~= myId then
            local char = pl.Character
            local p = partPos(char and char:FindFirstChild("HumanoidRootPart"))
            if p then out[#out + 1] = p end
        end
    end
    return out
end

-- Live Nov 1 2026: the teleport landed on a boar another player was fighting and the user
-- left. A mob with another player within playerRadius is never picked (and a fight stops
-- when one walks up, see fight()).
local function playerNear(p, players)
    if not CFG.avoidPlayers or not p then return false end
    for _, q in ipairs(players or otherPlayerPositions()) do
        if flatDist(p, q) <= CFG.playerRadius then return true end
    end
    return false
end

local function bestMob(want)
    local folder = Workspace:FindFirstChild("Mobs")
    local here = partPos(myRoot())
    if not folder or not here then return nil end
    local players = otherPlayerPositions()
    -- Live test Nov 1 2026: three Frenzy Boars at once overwhelmed auto-parry and killed
    -- the character, so every other live mob within crowdRadius costs crowdPenalty studs.
    local live = {}
    for _, m in ipairs(folder:GetChildren()) do
        if mobAlive(m) then
            local p = partPos(m:FindFirstChild("Collider") or m.PrimaryPart)
            if p then live[#live + 1] = { m = m, p = p } end
        end
    end
    local best, bestScore = nil, -math.huge
    for _, e in ipairs(live) do
        local match = mobMatch(e.m, want)
        if match > 0 and not playerNear(e.p, players) then
            local score = -(e.p - here).Magnitude
            for _, o in ipairs(live) do
                if o ~= e and flatDist(o.p, e.p) <= CFG.crowdRadius then score = score - CFG.crowdPenalty end
            end
            if match == 2 or not CFG.skipCorrupted then score = score + 100000 end
            if score > bestScore then best, bestScore = e.m, score end
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
        if lvl >= q.minLevel and q.mob then pick = q end
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
-- The giver's quest id from its QuestPrompt (the attribute the game's prompt handler reads).
local function questIdOf(path)
    local npc = child(Workspace, path)
    if not npc then return nil end
    for _, d in ipairs(npc:GetDescendants()) do
        if d.ClassName == "ProximityPrompt" then
            local id = attr(d, "QuestId")
            if type(id) == "string" and id ~= "" then return id end
        end
    end
    return nil
end

local function questRemote(name)
    local rs = game:GetService("ReplicatedStorage")
    return rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild(name)
end

local function talkTo(path, accept)
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
    if CFG.questMode == "remote" then
        -- The game's dialogue does QuestTalk:InvokeServer(questId) (this also turns a finished
        -- quest in) and, for an offer, QuestAccept:InvokeServer(id) (UI.Dialogue). Live Nov 1
        -- 2026: QuestTalk("boarQuest") at the town giver turned in "Show your Strength", and
        -- QuestTalk + QuestAccept started a quest, all unfocused. Matcha's InvokeServer only
        -- returns true, so the caller reads the tracker to see what happened.
        local id = questIdOf(path)
        local talk = questRemote("QuestTalk")
        if not id or not talk then setStatus("quest: no quest id/remote for " .. path); return false end
        setStatus("quest: talking to " .. path .. " (" .. id .. ")")
        pcall(function() return talk:InvokeServer(id) end)
        task.wait(0.5)
        if accept then
            local acc = questRemote("QuestAccept")
            if acc then pcall(function() return acc:InvokeServer(id) end) end
        end
        task.wait(0.8)
        STATE.giver = path
        return true
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

-- Every quest NPC we know of (QUESTS givers plus the other QuestPrompt NPCs and the story
-- NPCs), for turning in a quest whose giver is not known yet.
local EXTRA_GIVERS = { "Tolbana.TolbanaQuestNPC", "Tolbana.TolbanaQuestNPC2", "Horunka.MedaiQuestNPC",
    "ElfNPC.BeginningQuestNPC3", "StoryLine.Kirito", "StoryLine.Asuna", "StoryLine.Kayaba",
    "Dungeon.BossRoom.MainDungeonQuestNPC1" }
local function allGiversByDistance()
    local seen, list = {}, {}
    local function add(path)
        if seen[path] then return end
        seen[path] = true
        local p = partPos(giverRoot(path))
        if p then list[#list + 1] = { path = path, p = p } end
    end
    for _, q in ipairs(QUESTS) do for _, path in ipairs(q.npcs) do add(path) end end
    for _, path in ipairs(EXTRA_GIVERS) do add(path) end
    local here = partPos(myRoot())
    if here then table.sort(list, function(a, b) return flatDist(a.p, here) < flatDist(b.p, here) end) end
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = e.path end
    return out
end

-- Quest title (tracker) -> giver path, learned from accepts and successful turn-ins and
-- saved with the settings, so a quest the script did not accept itself is turned in at
-- the right NPC next time.
local SETTINGS_HOOK = { save = nil }
local function learnGiver(title, path)
    if not title or not path or CFG.questGivers[title] == path then return end
    CFG.questGivers[title] = path
    if SETTINGS_HOOK.save then pcall(SETTINGS_HOOK.save) end
end

-- Turn in the tracker's finished quest: the learned giver for its title, then the giver
-- we accepted from, then every known quest NPC nearest first, until the tracker moves on.
local function turnIn(tr)
    local title = tr and tr.title
    -- In "keys" mode talking needs the E key, which only reaches a focused Roblox window;
    -- without focus the search would teleport between NPCs for nothing.
    if CFG.questMode ~= "remote" and not focused() then
        setStatus("quest: '" .. tostring(title) .. "' done - focus Roblox to turn it in")
        return false
    end
    local tried, order = {}, {}
    local function push(path) if path and not tried[path] then tried[path] = true; order[#order + 1] = path end end
    push(title and CFG.questGivers[title])
    push(STATE.giver)
    for _, path in ipairs(allGiversByDistance()) do push(path) end
    for i = 1, math.min(#order, CFG.turnInTries) do
        if not farming() then return false end
        setStatus(string.format("quest: turning in '%s' at %s (%d/%d)", tostring(title), order[i], i, math.min(#order, CFG.turnInTries)))
        talkTo(order[i])
        task.wait(1)
        local now = readTracker()
        if not now or now.title ~= title or not now.complete then
            learnGiver(title, order[i])
            STATE.giver = nil
            return true
        end
    end
    setStatus("quest: could not find where to turn in '" .. tostring(title) .. "'")
    return false
end

-- Accept a kill quest: eligible quests (minLevel <= level) highest first, skipping ones
-- that recently would not start (completed and not repeatable, on cooldown, level-locked).
-- A quest that starts without a "Defeat X" step (tutorials, fetch quests) is cancelled
-- again with QuestCancel:FireServer() (the menu's cancelQuest does exactly that).
local QUEST_SKIP = {}
local function acceptQuest(tr)
    local lvl = playerLevel()
    local cands = {}
    for _, q in ipairs(QUESTS) do
        if (not CFG.questId or q.id == CFG.questId) and lvl >= q.minLevel and clock() >= (QUEST_SKIP[q.id] or 0) then
            cands[#cands + 1] = q
        end
    end
    table.sort(cands, function(a, b) return a.minLevel > b.minLevel end)
    local before = tr and tr.title
    for i = 1, math.min(#cands, CFG.acceptTries) do
        if not farming() then return false end
        local q = cands[i]
        local giver = nearestGiver(q)
        if giver then
            setStatus(string.format("quest: accepting %s at %s", q.id, giver))
            talkTo(giver, true)
            local after = readTracker()
            if after and after.title and after.title ~= before then
                if trackerTarget(after) then
                    learnGiver(after.title, giver)
                    return true
                end
                -- Started something we cannot farm: drop it and do not offer it again soon.
                local cancel = questRemote("QuestCancel")
                if cancel then pcall(function() cancel:FireServer() end) end
                task.wait(0.8)
                before = (readTracker() or {}).title
            end
        end
        QUEST_SKIP[q.id] = clock() + CFG.questSkipTime
    end
    setStatus("quest: no kill quest would start (level " .. lvl .. ")")
    return false
end

-- ---------------------------------------------------------------------------
-- Fight
-- ---------------------------------------------------------------------------
-- ReplicatedStorage.Remotes.Combat (RemoteEvent): Swing / Hit / Parry / Block / Dash.
local combatRemote = nil
local function getCombatRemote()
    if not combatRemote then
        local rs = game:GetService("ReplicatedStorage")
        combatRemote = rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("Combat")
    end
    return combatRemote
end

local function hpFraction()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local ok, hp, maxHp = pcall(function() return hum.Health, hum.MaxHealth end)
    if not ok or not hp or not maxHp or maxHp <= 0 then return 1 end
    return hp / maxHp
end

-- Low HP: step away from the nearest mobs and wait for health to come back.
local function retreat()
    local here = partPos(myRoot())
    local folder = Workspace:FindFirstChild("Mobs")
    if not here or not folder then return end
    local away, n = Vector3.new(0, 0, 0), 0
    for _, m in ipairs(folder:GetChildren()) do
        local p = mobAlive(m) and partPos(m:FindFirstChild("Collider") or m.PrimaryPart)
        if p and flatDist(p, here) <= 40 then
            away = away + Vector3.new(here.X - p.X, 0, here.Z - p.Z)
            n = n + 1
        end
    end
    -- HP only regenerates in town (RemakeConfig.TOWN_REGEN_PER_SECOND = 0.02 of max HP);
    -- field healing (BATTLE_HEALING) needs vitality 5, so at low level the field never heals.
    if CFG.townPos then
        setStatus(string.format("retreating to town at %d%% HP", math.floor(hpFraction() * 100)))
        travelTo(CFG.townPos, farming)
    elseif n > 0 and away.Magnitude > 0.01 then
        setStatus(string.format("retreating at %d%% HP", math.floor(hpFraction() * 100)))
        travelTo(here + away.Unit * CFG.retreatDistance, farming)
    end
    local untilT = clock() + CFG.retreatMaxWait
    while farming() and clock() < untilT and hpFraction() < CFG.resumeHp do
        setStatus(string.format("recovering %d%% HP", math.floor(hpFraction() * 100)))
        task.wait(1)
    end
end

local function fight(mob)
    local holdWait = 1 / math.max(1, CFG.holdHz)
    local clickEvery = 1 / math.max(1, CFG.clickHz)
    local nextClick, startedAt = 0, clock()
    local nextSkill, skillIdx = 0, 0
    local nextPlayerCheck, nextStatus = 0, 0
    while farming() and mobAlive(mob) do
        if afkCheckOpen() then return end
        if hpFraction() < CFG.retreatHp then retreat(); return end
        local col = mob:FindFirstChild("Collider") or mob.PrimaryPart
        local mp = partPos(col)
        local here = partPos(myRoot())
        if not mp or not here then break end
        if clock() - startedAt > 60 then break end -- immune / unreachable target
        if clock() >= nextPlayerCheck then
            nextPlayerCheck = clock() + 0.5
            if playerNear(mp) then setStatus("player near target, switching"); break end
        end
        local okL, look = pcall(function() return col.CFrame.LookVector end)
        local back = (okL and look) and Vector3.new(-look.X, 0, -look.Z) or Vector3.new(0, 0, 1)
        if back.Magnitude < 0.01 then back = Vector3.new(0, 0, 1) end
        local stand = mp + back.Unit * CFG.standOff
        if flatDist(here, stand) > CFG.nearRange then
            travelTo(stand, farming)
        elseif flatDist(here, stand) > 0.75 then
            nudgeToward(stand, mp, CFG.holdHz)
        end
        -- travelTo overwrites the status; show the fight again once we are on the mob.
        if clock() >= nextStatus then
            nextStatus = clock() + 0.5
            setStatus(string.format("fighting %s (%s HP)", tostring(attr(mob, "DisplayName") or mob.Name), tostring(attr(mob, "Health") or "?")))
        end
        if CFG.attackMode == "remote" then
            -- The game's light attack is Combat:FireServer("Swing", "Light", combo) and, at the
            -- hit frame, FireServer("Hit", "Light", combo, { mobModel }) (Systems.Combat). Live:
            -- Swing + Hit 0.25 s later every 0.65 s killed a Lv1 Frenzy Boar in 7 swings, 4.6 s,
            -- with no click and no focus.
            if clock() >= nextClick and (here - mp).Magnitude <= CFG.standOff + 6 and clock() >= PARRY.holdClicksUntil then
                nextClick = clock() + CFG.swingInterval
                local target = mob
                task.spawn(function()
                    local remote = getCombatRemote()
                    if not remote then return end
                    pcall(function() remote:FireServer("Swing", "Light", 1) end)
                    task.wait(CFG.hitDelay)
                    if mobAlive(target) then pcall(function() remote:FireServer("Hit", "Light", 1, { target }) end) end
                end)
            end
        elseif clock() >= nextClick and (here - mp).Magnitude <= CFG.standOff + 6 then
            nextClick = clock() + clickEvery
            if focused() and clock() >= PARRY.holdClicksUntil and not MENU_MOUSE.over then pcall(mouse1click) end
        end
        -- Sword skills: tap the slot keys often. The client refuses early taps by itself
        -- (Duration lock while the animation plays, server-synced cooldown after a reject),
        -- so the first tap it lets through goes out right as the animation ends, which is
        -- the user's rapid-recast window.
        if CFG.skillMode == "remote" then
            -- SwordSkillCast:FireServer(skillId, aimDir, rootPos, castId) is the whole cast
            -- (SwordSkills.Controller); the server runs the skill and its damage. Live: one
            -- remote Avalanche took a Lv1 Frenzy Boar from 78 to 7 HP, the next killed it.
            if (here - mp).Magnitude <= CFG.standOff + 6 and clock() >= PARRY.holdClicksUntil then
                for _, id in ipairs(CFG.remoteSkills) do
                    if clock() >= (SKILLCAST.nextAt[id] or 0) then
                        SKILLCAST.nextAt[id] = clock() + CFG.skillRecast
                        SKILLCAST.castId = SKILLCAST.castId + 1
                        local aim = Vector3.new(mp.X - here.X, 0, mp.Z - here.Z)
                        aim = aim.Magnitude > 0.1 and aim.Unit or Vector3.new(0, 0, -1)
                        local castId = SKILLCAST.castId
                        task.spawn(function()
                            local rs = game:GetService("ReplicatedStorage")
                            local remote = rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("SwordSkillCast")
                            if remote then pcall(function() remote:FireServer(id, aim, here, castId) end) end
                        end)
                        break
                    end
                end
            end
        elseif #CFG.skillSlots > 0 and clock() >= nextSkill and (here - mp).Magnitude <= CFG.standOff + 6
            and focused() and clock() >= PARRY.holdClicksUntil then
            nextSkill = clock() + 1 / math.max(1, CFG.skillTapHz)
            skillIdx = skillIdx % #CFG.skillSlots + 1
            local vk = 0x30 + CFG.skillSlots[skillIdx]
            pcall(function() keypress(vk); task.wait(0.02); keyrelease(vk) end)
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
        elseif not focused() and CFG.attackMode ~= "remote" then
            -- Remote attacks, remote parry and teleport travel need no focus; quest dialogue
            -- (E) and skill keys still check focus themselves.
            setStatus("waiting for Roblox focus (keys and clicks go to the focused window)")
            task.wait(0.5)
        else
            local tr = readTracker()
            local target = CFG.mobName or trackerTarget(tr)
            local q = pickQuest()
            if STATE.quest and tr and tr.complete and clock() - lastTalk > 6 then
                lastTalk = clock()
                turnIn(tr)
                target = trackerTarget(readTracker())
            elseif STATE.quest and not target and clock() - lastTalk > 6 and (CFG.questMode == "remote" or focused()) then
                lastTalk = clock()
                if CFG.questMode == "remote" then
                    acceptQuest(tr)
                else
                    local giver = nearestGiver(q)
                    local before = tr and tr.title
                    if giver then talkTo(giver) else setStatus("quest: no giver loaded for " .. q.id); task.wait(1) end
                    local after = readTracker()
                    if giver and after and after.title and after.title ~= before then learnGiver(after.title, giver) end
                end
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

-- ---------------------------------------------------------------------------
-- Auto-parry (F)
-- ---------------------------------------------------------------------------
-- How the game does it (Systems.Combat / Systems.Effects, read Nov 1 2026):
--   * a mob attack fires the MobTelegraph effect: a Highlight (default Name "Highlight")
--     is parented to the mob model and destroyed after windup + 0.1 s, windup clamped to
--     0.15-0.8 s (default 0.4). The hit lands when the windup ends.
--   * F with the weapon drawn sends FireServer("Parry", serverTime) when the client
--     parry cooldown (CombatConfig.block.parryCooldown = 0.9) is over, else it blocks.
--     The server judges the parry with block.parryWindow = 0.4.
-- So: watch nearby mobs for a new "Highlight" child, tap F so the press lands about
-- parryLead s before the hit, and learn each MobKind's windup from how long its
-- highlight lived. Highlights named CombatPlusFlash / CombatPlusBlade are hit effects.

-- Server time for the remote parry. The game sends workspace:GetServerTimeNow() (Unix
-- seconds with a fraction), which Matcha does not bind, and Matcha's tick()/os.clock()
-- count from boot. os.time() is Unix time in whole seconds, so catch the moment it ticks
-- over and carry the fraction with os.clock() from there (about one frame of error plus
-- the PC clock offset, small next to the 0.4 s parry window).
local SERVER_CLOCK = { base = nil, at = nil }
task.spawn(function()
    local s0 = os.time()
    local untilT = clock() + 2
    while clock() < untilT do
        local s = os.time()
        if s ~= s0 then
            SERVER_CLOCK.base, SERVER_CLOCK.at = s, clock()
            break
        end
        task.wait()
    end
end)
local function serverTimeNow()
    if SERVER_CLOCK.base then return SERVER_CLOCK.base + (clock() - SERVER_CLOCK.at) end
    return os.time()
end

-- Turn the root toward the attacker (one write) so a parry from behind still faces it.
local function faceToward(p)
    local root = myRoot()
    local here = partPos(root)
    if not here or not p then return end
    local dir = Vector3.new(p.X - here.X, 0, p.Z - here.Z)
    if dir.Magnitude < 0.1 then return end
    pcall(function() root.CFrame = CFrame.lookAt(here, here + dir) end)
end

local function tapParry(attacker)
    PARRY.pressedAt = clock()
    PARRY.count = PARRY.count + 1
    if CFG.parryMode == "remote" then
        -- Same call the game's F handler makes (Systems.Combat): Combat:FireServer("Parry",
        -- serverTime). FireServer is one-way; works without Roblox focus or an F press.
        if CFG.parryFace and attacker then
            faceToward(partPos(attacker:FindFirstChild("Collider") or attacker.PrimaryPart))
        end
        local combatRemote = getCombatRemote()
        if not combatRemote then return false end
        -- The server keeps its own parry cooldown (block.parryCooldown 0.9 s). Live test vs
        -- two boars (attacks ~0.25-0.5 s apart): 53/61 attacks did no damage, the 4 full
        -- 33-damage hits came while a parry was still cooling down. Inside that cooldown send
        -- a block instead (damageReduction 0.8: those hits measured 6), released after the hit.
        if clock() - (PARRY.lastRemoteParry or -1e9) < CFG.parryServerCooldown then
            local ok = pcall(function() combatRemote:FireServer("Block", true) end)
            PARRY.blockSeq = (PARRY.blockSeq or 0) + 1
            local seq = PARRY.blockSeq
            task.spawn(function()
                task.wait(CFG.blockHold)
                if PARRY.blockSeq == seq then pcall(function() combatRemote:FireServer("Block", false) end) end
            end)
            return ok
        end
        PARRY.lastRemoteParry = clock()
        return (pcall(function() combatRemote:FireServer("Parry", serverTimeNow()) end))
    end
    if not focused() then return false end
    pcall(function() keypress(VK_F); task.wait(0.05); keyrelease(VK_F) end)
    return true
end

-- Collector (2 Hz): mobs within parryRange.
task.spawn(function()
    while alive() do
        local out = {}
        if STATE.parry then
            local here = partPos(myRoot())
            local folder = Workspace:FindFirstChild("Mobs")
            if here and folder then
                for _, m in ipairs(folder:GetChildren()) do
                    if mobAlive(m) then
                        local p = partPos(m:FindFirstChild("Collider") or m.PrimaryPart)
                        if p and (p - here).Magnitude <= CFG.parryRange then out[#out + 1] = m end
                    end
                end
            end
        end
        PARRY.near = out
        task.wait(0.5)
    end
end)

-- Watcher (30 Hz): new telegraph highlight -> schedule one F tap.
task.spawn(function()
    while alive() do
        if STATE.parry then
            local now = clock()
            for _, m in ipairs(PARRY.near) do
                local h = m.Parent and m:FindFirstChild("Highlight")
                local okA, mobKey = pcall(function() return m.Address end)
                mobKey = okA and mobKey or m.Name
                local entry = PARRY.seen[mobKey]
                if h and h.ClassName == "Highlight" then
                    local okH, hKey = pcall(function() return h.Address end)
                    hKey = okH and hKey or now
                    if not entry or entry.h ~= hKey then
                        local kind = tostring(attr(m, "MobKind") or m.Name)
                        PARRY.seen[mobKey] = { h = hKey, at = now, kind = kind }
                        local windup = PARRY.windup[kind] or 0.4
                        local delay = math.max(0, windup - CFG.parryLead)
                        PARRY.holdClicksUntil = math.max(PARRY.holdClicksUntil, now + delay + 0.35)
                        -- task.delay callbacks never ran in Matcha (live test Nov 1 2026); spawn + wait does.
                        task.spawn(function()
                            task.wait(delay)
                            -- 0.12 s spacing: one tap can cover attacks that land together
                            -- (parry window 0.4 s), but a later attacker still gets its own.
                            if alive() and STATE.parry and clock() - PARRY.pressedAt > CFG.parryMinGap then tapParry(m) end
                        end)
                    end
                elseif entry and entry.h and not entry.done then
                    -- Highlight gone: it lived windup + 0.1 s. Learn the windup for this kind.
                    local lived = now - entry.at - 0.1
                    if lived >= 0.1 and lived <= 0.9 then
                        local old = PARRY.windup[entry.kind]
                        PARRY.windup[entry.kind] = old and (old * 0.6 + lived * 0.4) or lived
                    end
                    entry.done = true
                end
            end
        end
        task.wait(1 / 30)
    end
end)

-- Sword skill cooldowns (client side only). The skill definitions are tables with
-- Name / Cooldown / Duration / Stamina (42 found live, cooldowns 4-30 s). Zeroing
-- Cooldown removes the client's own wait; the server still rejects early casts and
-- sends back its remaining cooldown (SwordSkills.Controller), so this only makes the
-- client send each cast at the earliest moment, which is what the rapid-recast
-- window needs.
local SKILL = { state = "off", saved = nil, cache = nil }
local function setSkillCooldowns(on)
    if SKILL.state == "patching" then return end
    SKILL.state = "patching"
    task.spawn(function()
        local ok = pcall(function()
            if not SKILL.cache then
                SKILL.cache = findgc("Name", { Cooldown = "number", Duration = "number", Stamina = "number" })
                SKILL.saved = {}
                for _, e in ipairs(SKILL.cache) do
                    if e.key == "Cooldown" then SKILL.saved[#SKILL.saved + 1] = { e = e, v = e.value } end
                end
            end
            if on then
                applygc(SKILL.cache, "Cooldown", 0)
            else
                for _, s in ipairs(SKILL.saved) do pcall(applygc, { s.e }, "Cooldown", s.v) end
            end
        end)
        SKILL.state = ok and (on and "on" or "off") or "failed"
    end)
end

-- Optional: shorten the client parry cooldown (0.9 s) so back-to-back attacks can both be
-- parried. The server may keep its own cooldown; nil leaves the game value alone.
local PARRY_ORIGINAL_COOLDOWN = 0.9
local function patchParryCooldown(on)
    if not CFG.parryCooldown then return end
    task.spawn(function()
        if on then
            pcall(setgc, "parryCooldown", CFG.parryCooldown, PARRY_ORIGINAL_COOLDOWN)
        else
            pcall(setgc, "parryCooldown", PARRY_ORIGINAL_COOLDOWN, CFG.parryCooldown)
        end
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
                elseif name == "parry" then STATE.parry = not STATE.parry
                elseif name == "unload" then API.unload() end
            end
            was[name] = down
        end
        if label then
            pcall(function()
                label.Text = string.format("SAO AFQ  farm:%s  quest:%s  dash:%s  parry:%s(%d)  |  %s",
                    STATE.farm and "ON" or "off", STATE.quest and "ON" or "off", DASH.state,
                    STATE.parry and "ON" or "off", PARRY.count, STATE.status)
            end)
        end
        task.wait(0.1)
    end
end)

-- ---------------------------------------------------------------------------
-- Settings menu (UE library, the same laced.club UI as the Blox Fruits script)
-- ---------------------------------------------------------------------------
-- Main tab: Farm (farm, quest pickup, target mob) and Travel (mode, infinite dash, retreat
-- HP). Combat tab: Attacks (attack/skill mode, skill slots 1-4, recast) and Parry.
-- UE's own Settings tab has the menu key and configs. Our settings are also saved to
-- sao_afq_settings.json on every change and loaded at start.
local SKILL_OPTIONS = { "none", "Avalanche", "Cyclone", "TitansVerdict", "ExecutionersCross" }
local MOB_OPTIONS = { "auto (quest)", "Frenzy Boar", "Dire Wolf", "Wind Wasp", "Little Nepenthes",
    "Ruin Kobold Trooper", "Ruin Kobold Sentinel" }
local SETTINGS_FILE = "sao_afq_settings.json"

local function rebuildRemoteSkills()
    local out = {}
    for i = 1, 4 do
        local id = CFG.slotSkills[i]
        if id and id ~= "none" then out[#out + 1] = id end
    end
    CFG.remoteSkills = out
end

local function saveSettings()
    pcall(function()
        local data = {
            travelMode = CFG.travelMode, attackMode = CFG.attackMode, skillMode = CFG.skillMode,
            slotSkills = CFG.slotSkills, skillRecast = CFG.skillRecast, parryMode = CFG.parryMode,
            retreatHp = CFG.retreatHp, mobName = CFG.mobName or false, infiniteDash = CFG.infiniteDash,
            autoQuest = STATE.quest, autoParry = STATE.parry, questGivers = CFG.questGivers,
            avoidPlayers = CFG.avoidPlayers,
        }
        writefile(SETTINGS_FILE, game:GetService("HttpService"):JSONEncode(data))
    end)
end

local function loadSettings()
    pcall(function()
        if type(isfile) == "function" and not isfile(SETTINGS_FILE) then return end
        local d = game:GetService("HttpService"):JSONDecode(readfile(SETTINGS_FILE))
        if type(d) ~= "table" then return end
        for _, k in ipairs({ "travelMode", "attackMode", "skillMode", "skillRecast", "parryMode", "retreatHp", "infiniteDash" }) do
            if d[k] ~= nil then CFG[k] = d[k] end
        end
        if type(d.slotSkills) == "table" then
            for i = 1, 4 do CFG.slotSkills[i] = d.slotSkills[i] or d.slotSkills[tostring(i)] or CFG.slotSkills[i] end
        end
        if d.mobName ~= nil then CFG.mobName = d.mobName or nil end
        if type(d.questGivers) == "table" then
            for title, path in pairs(d.questGivers) do
                if type(title) == "string" and type(path) == "string" then CFG.questGivers[title] = path end
            end
        end
        if d.avoidPlayers ~= nil then CFG.avoidPlayers = d.avoidPlayers end
        if d.autoQuest ~= nil then STATE.quest = d.autoQuest end
        if d.autoParry ~= nil then STATE.parry = d.autoParry end
    end)
    rebuildRemoteSkills()
end
loadSettings()
SETTINGS_HOOK.save = saveSettings

-- The menu is the same UE library (laced.club UI) the Blox Fruits script uses:
-- src/10_ui.lua downloads it, runs it, and finds it through the UELibrary global
-- (Matcha's loadstring drops top-level returns).
local UE_URL = "https://raw.githubusercontent.com/hauntedscripts/Scripts2/refs/heads/main/matcha%20ue"
local UI = { lib = nil, window = nil, controls = {}, unloading = false }

local function findUE()
    local envs = {}
    if type(_G.getgenv) == "function" then
        local ok, genv = pcall(_G.getgenv)
        if ok and type(genv) == "table" then envs[#envs + 1] = genv end
    end
    envs[#envs + 1] = _G
    for _, env in ipairs(envs) do
        local c = env.UELibrary
        if type(c) == "table" and type(c.CreateWindow) == "function" then return c end
    end
    return nil
end

local function loadUE()
    local src = nil
    for attempt = 1, 3 do
        local ok, body = pcall(httpget, UE_URL)
        if ok and type(body) == "string" and #body > 2000 and string.find(body, "UELibrary", 1, true) then
            src = body
            break
        end
        task.wait(attempt)
    end
    if not src then return nil, "UE download failed" end
    local previous = findUE()
    local chunk = loadstring(src, "laced.club UE")
    if type(chunk) ~= "function" then return nil, "UE compile failed" end
    local okRun, err = pcall(chunk)
    if not okRun then return nil, "UE run failed: " .. tostring(err) end
    local ue = findUE()
    if not ue or ue == previous or ue._unloaded then return nil, "UE did not expose a fresh UELibrary" end
    return ue
end

local function control(id) return UI.controls[id] end
local function syncControl(id, value)
    local c = control(id)
    if c and c.Value ~= value and c.SetValue then pcall(function() c:SetValue(value) end) end
end

local function buildMenu()
    local ue, err = loadUE()
    if not ue then
        warn("[SAO AFQ] menu failed to load: " .. tostring(err) .. " (hotkeys still work)")
        return
    end
    UI.lib = ue
    -- Own look (SAO system-menu blue on dark navy, gradient) and own UE files, so nothing
    -- is shared with the Blox Fruits menu's settings or configs.
    local accent = Color3.fromRGB(90, 200, 255)
    ue.AccentColor, ue.StaticAccentColor = accent, accent
    ue.BackgroundColor = Color3.fromRGB(10, 14, 24)
    ue.MainColor = Color3.fromRGB(18, 26, 42)
    ue.OutlineColor = Color3.fromRGB(44, 70, 108)
    ue.FontColor = Color3.fromRGB(226, 238, 255)
    ue.GradientEnabled = true
    ue.GradientTopColor = Color3.fromRGB(22, 44, 78)
    ue.GradientBottomColor = Color3.fromRGB(8, 10, 20)
    ue.SettingsFile = "sao_afq.ui.json"
    ue.ConfigFolder = "sao_afq_configs"
    local win = ue:CreateWindow({ Title = "Aincrad Assist  |  SAO: Eternity", Width = 540, Height = 470, AutoShow = true, Center = true })
    UI.window = win
    -- UE draws each control the moment it is added, so building on a visible window showed
    -- every tab's text on top of each other until the next refresh. Build hidden, show once.
    pcall(function() win:Hide() end)
    local function reg(id, c) UI.controls[id] = c; return c end

    local main = win:AddTab("Main")
    local farm = main:AddLeftGroupbox("Farm")
    reg("farm", farm:AddToggle("farm", { Text = "Auto Farm Quest (F6)", Default = STATE.farm,
        Tooltip = "Pick up the quest for your level, farm its mob, turn it in",
        Callback = function(v) STATE.farm = v == true end }))
    reg("quest", farm:AddToggle("quest", { Text = "Auto Quest Pickup (F7)", Default = STATE.quest,
        Tooltip = "Talk to quest givers to accept and turn in quests",
        Callback = function(v) STATE.quest = v == true; saveSettings() end }))
    reg("mob", farm:AddDropdown("mob", { Text = "Target Mob", Values = MOB_OPTIONS, Default = CFG.mobName or "auto (quest)",
        Tooltip = "auto (quest) farms the mob your quest tracker names",
        Callback = function(v) CFG.mobName = (v and v ~= "auto (quest)") and v or nil; saveSettings() end }))
    reg("avoidPlayers", farm:AddToggle("avoidPlayers", { Text = "Avoid Players", Default = CFG.avoidPlayers,
        Tooltip = "Skip mobs with another player nearby; leave a fight when one walks up",
        Callback = function(v) CFG.avoidPlayers = v == true; saveSettings() end }))
    reg("playerRadius", farm:AddSlider("playerRadius", { Text = "Player Avoid Radius", Default = CFG.playerRadius,
        Min = 10, Max = 200, Rounding = 0, Suffix = " studs",
        Callback = function(v) CFG.playerRadius = tonumber(v) or 50 end }))
    farm:AddButton({ Text = "Print discovery dump (F8)", Func = function() task.spawn(dump) end })

    local travel = main:AddRightGroupbox("Travel")
    reg("travelMode", travel:AddDropdown("travelMode", { Text = "Travel Mode", Values = { "teleport", "dash", "step" }, Default = CFG.travelMode,
        Tooltip = "teleport: one long jump; dash: W + Ctrl with camera steering (needs focus); step: slow ground steps",
        Callback = function(v) if v then CFG.travelMode = v; saveSettings() end end }))
    reg("dash", travel:AddToggle("dash", { Text = "Infinite Dash (F9)", Default = CFG.infiniteDash,
        Tooltip = "Ctrl dash with no stamina cost and no cooldown (heap patch, 15-30 s)",
        Callback = function(v) CFG.infiniteDash = v == true; setDash(v == true); saveSettings() end }))
    reg("retreatHp", travel:AddSlider("retreatHp", { Text = "Retreat to town below HP", Default = math.floor(CFG.retreatHp * 100 + 0.5),
        Min = 10, Max = 90, Rounding = 0, Suffix = "%",
        Callback = function(v) CFG.retreatHp = (tonumber(v) or 35) / 100; saveSettings() end }))

    local combat = win:AddTab("Combat")
    local attacks = combat:AddLeftGroupbox("Attacks")
    reg("attackMode", attacks:AddDropdown("attackMode", { Text = "Attack Mode", Values = { "remote", "click" }, Default = CFG.attackMode,
        Tooltip = "remote: Combat Swing + Hit (no focus); click: mouse clicks",
        Callback = function(v) if v then CFG.attackMode = v; saveSettings() end end }))
    reg("skillMode", attacks:AddDropdown("skillMode", { Text = "Skill Mode", Values = { "remote", "keys" }, Default = CFG.skillMode,
        Tooltip = "remote: SwordSkillCast for the slots below (no focus); keys: tap 1-4",
        Callback = function(v) if v then CFG.skillMode = v; saveSettings() end end }))
    for i = 1, 4 do
        reg("slot" .. i, attacks:AddDropdown("slot" .. i, { Text = "Skill Slot " .. i, Values = SKILL_OPTIONS, Default = CFG.slotSkills[i] or "none",
            Tooltip = "Skill fired automatically in fights",
            Callback = function(v) CFG.slotSkills[i] = v or "none"; rebuildRemoteSkills(); saveSettings() end }))
    end
    reg("skillRecast", attacks:AddSlider("skillRecast", { Text = "Skill Recast", Default = CFG.skillRecast,
        Min = 1, Max = 30, Rounding = 1, Suffix = "s",
        Callback = function(v) CFG.skillRecast = tonumber(v) or 9; saveSettings() end }))

    local parry = combat:AddRightGroupbox("Parry")
    reg("parry", parry:AddToggle("parry", { Text = "Auto Parry (F10)", Default = STATE.parry,
        Tooltip = "Parry when a nearby mob telegraphs an attack",
        Callback = function(v) STATE.parry = v == true; saveSettings() end }))
    reg("parryMode", parry:AddDropdown("parryMode", { Text = "Parry Mode", Values = { "remote", "key" }, Default = CFG.parryMode,
        Tooltip = "remote: Combat Parry remote (no focus); key: tap F",
        Callback = function(v) if v then CFG.parryMode = v; saveSettings() end end }))
    reg("parryFace", parry:AddToggle("parryFace", { Text = "Face Attacker", Default = CFG.parryFace,
        Tooltip = "Turn toward the attacker before a remote parry",
        Callback = function(v) CFG.parryFace = v == true end }))

    if type(ue.OnUnload) == "function" then
        pcall(function() ue:OnUnload(function() if not UI.unloading then API.unload() end end) end)
    end
    pcall(function()
        win:Show()
        win._visibilityDirty = true
    end)
end

-- Mouse over a visible UE window: click-mode attacks wait (the menu reads the real button).
task.spawn(function()
    local mouse = nil
    pcall(function() mouse = LocalPlayer:GetMouse() end)
    while alive() do
        local over = false
        local ue = UI.lib
        if ue and ue.Toggled and not ue._unloaded and mouse then
            pcall(function()
                local mx, my = mouse.X, mouse.Y
                for _, w in ipairs(ue.Windows or {}) do
                    local p, s = w.Position, w.Size
                    if w.Visible and not w.Destroyed and p and s and mx >= p.X - 8 and mx <= p.X + s.X + 8
                        and my >= p.Y - 8 and my <= p.Y + s.Y + 8 then
                        over = true
                    end
                end
            end)
        end
        MENU_MOUSE.over = over
        task.wait(0.1)
    end
end)

task.spawn(buildMenu)

-- Hotkeys change STATE directly; keep the menu toggles showing the same values.
task.spawn(function()
    while alive() do
        syncControl("farm", STATE.farm)
        syncControl("quest", STATE.quest)
        syncControl("parry", STATE.parry)
        if DASH.state == "on" or DASH.state == "off" then syncControl("dash", DASH.state == "on") end
        task.wait(0.3)
    end
end)

API.unload = function()
    STATE.running, STATE.farm = false, false
    if DASH.state == "on" then setDash(false) end
    patchParryCooldown(false)
    if SKILL.state == "on" then setSkillCooldowns(false) end
    if label then pcall(function() label:Remove() end); label = nil end
    UI.unloading = true
    if UI.lib and not UI.lib._unloaded and type(UI.lib.Unload) == "function" then pcall(function() UI.lib:Unload() end) end
    if _G.SAO_AFQ == API then _G.SAO_AFQ = nil end
end
API.state, API.config, API.dump, API.quests, API.setDash = STATE, CFG, dump, QUESTS, setDash

-- Heap patches one after another: each scan takes 15-30 s and they are heavy together.
task.spawn(function()
    if CFG.infiniteDash then
        setDash(true)
        while alive() and DASH.state == "patching" do task.wait(0.5) end
    end
    patchParryCooldown(true)
    task.wait(1)
    if alive() and CFG.zeroSkillCooldown then setSkillCooldowns(true) end
end)
print("[SAO AFQ] loaded - F6 farm, F7 quest pickup, F8 dump, F9 infinite dash, F10 auto-parry, End unload")
