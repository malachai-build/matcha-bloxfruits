-- @chunk 40_combat  (lines 3651-4274 of the single-file build)
local LACED_LOAD = type(_G.__lacedLoad) == "table" and _G.__lacedLoad or nil -- load marker (loader.lua)
if LACED_LOAD and type(LACED_LOAD.started) == "table" then LACED_LOAD.started["40_combat"] = true end
-- Per-execution bindings: captured at chunk load so a re-run of the script
-- cannot make this copy's loops read the new copy's state (alive is a
-- closure over this run's state since the Oct 15 stability pass).
local alive = alive
local SCRIPT_STATE = SCRIPT_STATE
local S = S
function localRootPosition()
    local char=LocalPlayer.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local okPos,pos=pcall(function() return hrp.Position end)
    return okPos and pos or nil
end

HARD_LOCK_LAST = 0
function hardLockNpcCFrame(hrp,targetPos)
    if not hrp or not targetPos then return end
    -- 30 Hz cap (was every frame, 60 Hz). 4 ms slack so 60 Hz frame jitter
    -- does not turn every other frame into every third.
    local now=clock()
    if now-HARD_LOCK_LAST<writeInterval(1/ROOT_WRITE_HZ)-0.004 then return end
    HARD_LOCK_LAST=now
    if not moveRoot(hrp,targetPos.X,targetPos.Y,targetPos.Z,rootRotation(hrp)) then return end

    pcall(function()
        local velocity=hrp.Velocity
        if velocity and velocity.X and velocity.Z and math.abs(velocity.Y)>0.01 then
            hrp.Velocity=Vector3.new(velocity.X,0,velocity.Z)
        end
    end)
    pcall(function()
        local assemblyVelocity=hrp.AssemblyLinearVelocity
        if assemblyVelocity and assemblyVelocity.X and assemblyVelocity.Z and math.abs(assemblyVelocity.Y)>0.01 then
            hrp.AssemblyLinearVelocity=Vector3.new(assemblyVelocity.X,0,assemblyVelocity.Z)
        end
    end)
end

function getNormalFarmOffsets()
    local sanguine=false
    local backpack=LocalPlayer:FindFirstChild("Backpack")
    if backpack and backpack:FindFirstChild("Sanguine Art") then sanguine=true end
    local char=LocalPlayer.Character
    if char and char:FindFirstChild("Sanguine Art") then sanguine=true end
    if S.customOffset then
        return tonumber(S.customOffsetX) or 0,
               tonumber(S.customOffsetY) or 23,
               tonumber(S.customOffsetZ) or 0
    end
    if sanguine then return 0,23,10 end
    return 0,23,0
end

function isAlive(model)
    if not model then return false end
    local okAlive,result=pcall(function()
        if not model.Parent then return false end
        local hum=model:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health<=0 then return false end
        return true
    end)
    return okAlive and result==true
end

function enemyRoot(model)
    if not model then return nil end
    local root=nil
    pcall(function()
        root=model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
    end)
    return root
end

-- Head hitbox expansion shared by every click-farm loop. Remembers the
-- original size so it can be restored when the fight ends.
HEAD_APPLY_INTERVAL = 0.25
function headExpander(model)
    local state={head=nil,size=nil,canCollide=nil,nextApply=0}
    local okHead,head=pcall(function() return model:FindFirstChild("Head") end)
    if okHead and head then
        state.head=head
        pcall(function()
            state.size=head.Size
            state.canCollide=head.CanCollide
        end)
    end
    -- A dying enemy is destroyed shortly after its Humanoid reaches 0 HP: no
    -- write may race that destroy.
    local function modelAlive()
        local okAlive,result=pcall(function()
            if not model.Parent then return false end
            local hum=model:FindFirstChildOfClass("Humanoid")
            return hum~=nil and hum.Health~=nil and hum.Health>0
        end)
        return okAlive and result==true
    end
    function state.apply()
        if writesPaused() then return end -- CommF_ quiet window
        local now=clock()
        if now<state.nextApply then return end
        state.nextApply=now+writeInterval(HEAD_APPLY_INTERVAL)
        if not modelAlive() then return end
        local okCurrent,current=pcall(function() return model:FindFirstChild("Head") end)
        if not okCurrent or not current then return end
        state.head=current
        local size=S.bigHitbox and 200 or 50
        pcall(function()
            if not current.Parent then return end
            local s=current.Size
            if not (s and s.X and math.abs(s.X-size)<0.01 and math.abs(s.Y-size)<0.01 and math.abs(s.Z-size)<0.01) then
                current.Size=Vector3.new(size,size,size)
            end
            if current.CanCollide~=false then current.CanCollide=false end
        end)
    end
    function state.restore()
        local target=state.head
        if not target or not state.size then return end
        if not modelAlive() then return end
        pcall(function()
            if target.Parent then
                target.Size=state.size
                if state.canCollide~=nil then target.CanCollide=state.canCollide end
            end
        end)
    end
    return state
end

function farmAttack(hrp, checkFn, enemyName, useTween, maxDistance, attackFn, attackDelay)
    local attackRange=maxDistance or 500
    local folder=Workspace:FindFirstChild("Enemies")
    if not folder or not hrp then return false end
    local okMine,myPos=pcall(function() return hrp.Position end)
    if not okMine or not myPos then return false end
    local nearest, bestDist=nil, math.huge
    for _, model in pairs(folder:GetChildren()) do
        local okModel,isModel=pcall(function() return isA(model,"Model") end)
        if okModel and isModel and isAlive(model) then
            local okName,modelName=pcall(function() return model.Name end)
            if not enemyName or (okName and modelName==enemyName) then
                local root=enemyRoot(model)
                local okPos,rootPos=pcall(function() return root and root.Position end)
                if okPos and rootPos then
                    local dx=rootPos.X-myPos.X
                    local dy=rootPos.Y-myPos.Y
                    local dz=rootPos.Z-myPos.Z
                    local d=math.sqrt(dx*dx+dy*dy+dz*dz)
                    if d<bestDist and d<=attackRange then bestDist=d; nearest=model end
                end
            end
        end
    end
    if not nearest then return false end

    local function running()
        if not alive() then return false end
        local okCheck,result=pcall(checkFn)
        return okCheck and result and isAlive(nearest) or false
    end

    local head=headExpander(nearest)
    task.spawn(function()
        while running() do
            if not S.remoteMode then head.apply() end
            frameWait()
        end
        head.restore()
    end)
    local lastClick=0
    local hitDelay=attackDelay or 0.06
    local reachedNpc=false
    while running() do
        local tr=enemyRoot(nearest)
        local okPos,trPos=pcall(function() return tr and tr.Position end)
        if okPos and trPos then
            local ox,oy,oz=getNormalFarmOffsets()
            local targetPos=Vector3.new(trPos.X+ox, trPos.Y+oy, trPos.Z+oz)
            if useTween and not reachedNpc then
                tweenTo(hrp,targetPos,S.FARM_SPEED,running)
                reachedNpc=true
            else
                hardLockNpcCFrame(hrp,targetPos)
            end
        end
        local now=clock()
        if now-lastClick>=hitDelay then
            lastClick=now
            if attackFn then
                -- Matcha's task.spawn forwards no arguments: attackFn used to
                -- get nil and hit the first enemy in range, not this target.
                local target=nearest
                task.spawn(function() attackFn(target) end)
            else
                farmClick()
            end
        end
        frameWait()
    end
    return true
end

REMOTE_SESSION_ID = "32501259"
REMOTE_MAX_DIST   = 60
_remoteNet        = nil
_remoteRegAtk     = nil
_remoteRegHit     = nil
_lastRemoteFire   = 0

function ensureRemotes()
    if _remoteRegAtk and _remoteRegHit then return true end
    local okNet,net=pcall(function()
        local modules=game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
        return modules and modules:FindFirstChild("Net")
    end)
    if not okNet or not net then return false end
    _remoteNet    = net
    _remoteRegAtk = net:FindFirstChild("RE/RegisterAttack")
    _remoteRegHit = net:FindFirstChild("RE/RegisterHit")
    return _remoteRegAtk ~= nil and _remoteRegHit ~= nil
end

-- Remote Mode only works on Matcha Pro. When RegisterAttack/RegisterHit keep
-- failing, switch Remote Mode off so the farms fall back to click farming.
function remoteModeFallbackCheck()
    if S.remoteMode and (remoteFailing("RegisterAttack") or remoteFailing("RegisterHit")) then
        warnThrottled("remoteModeOff","[laced.club] Remote Mode turned off: RegisterAttack/RegisterHit keep failing "
            .."(needs Matcha Pro / Hybrid mode). Falling back to click farming.",60)
        S.remoteMode=false
        pcall(function() Window:Set("remote_mode",false) end)
    end
end

-- Basic attack without synthetic clicks. Mirrors the game's own M1 path
-- (ReplicatedStorage.Controllers.CombatController attackMelee +
-- Modules.CombatUtil RunHitDetection, decompiled 2026-10-15):
--   RE/RegisterAttack:FireServer(animLength / SpeedMult, comboIndex)
--   RE/RegisterHit:FireServer(primaryHitPart, otherHits, nil, sessionId)
--     otherHits = { {rigModel, hitPart}, ... } WITHOUT the primary rig
--     (empty unless Buddha: the client caps a swing at 10 rigs)
-- The hit parts the client accepts are limbs/Head/ModelHitbox, never the
-- HumanoidRootPart. No timestamps travel with either remote.
BasicM1 = {
    attackLen    = 0.5,   -- RegisterAttack arg 1 (client: anim Length / SpeedMult)
    comboLen     = 3,     -- WeaponData: 58 weapons have 4 Basic steps, 2 have 3; 1..3 is valid for all and skips the knock-back finisher
    comboReset   = 0.75,  -- client resets the combo after 0.75 s without a swing
    maxExtra     = 9,     -- extra rigs per swing (client cap: 10 rigs total, Buddha only)
    maxDist      = REMOTE_MAX_DIST,
    minInterval  = 0.25,  -- per caller tag (was 0.045: ~20 swings = 40 FireServer/s); the client's own M1 is ~3-4/s
    noDamageSecs = 2.0,   -- watchdog: advance profile after this long with no HP loss
    requireTool  = true,  -- the server-side M1 needs an equipped weapon
    hitParts     = { "Head", "UpperTorso", "LowerTorso", "LeftLowerLeg", "RightLowerLeg",
                     "LeftUpperArm", "RightUpperArm", "ModelHitbox" },
    -- Wire profiles, tried in order; the watchdog moves to the next one when
    -- an in-range target takes no damage for noDamageSecs.
    --  1 client-faithful args with the session id that is proven to work
    --  2 the exact pre-patch remoteAttack shape (live-proven 2026-10-15)
    --  3 client-faithful args with a session id derived like the client does
    profiles = {
        { name = "client+legacyId", clientShape = true,  sendCombo = true,  derivedId = false },
        { name = "legacy",          clientShape = false, sendCombo = false, derivedId = false },
        { name = "client+derivedId",clientShape = true,  sendCombo = true,  derivedId = true  },
    },
    profile      = 1,
    combo        = 0,
    lastSwing    = 0,
    lastFireBy   = {},
    derived      = nil,
    watchKey     = nil,
    watchHp      = 0,
    watchSince   = 0,
}

-- Client: tostring(UserId):sub(2,4) .. tostring(coroutine.running()):sub(11,15)
-- (3 digits of the UserId + 5 hex digits). The script's hard-coded
-- "32501259"/"325bb15e" carry another account's UserId digits ("325"; this
-- account's are "468") and still worked live, so the server does not check it.
function BasicM1.sessionId()
    local prof = BasicM1.profiles[BasicM1.profile] or BasicM1.profiles[1]
    if not prof.derivedId then return REMOTE_SESSION_ID end
    if BasicM1.derived then return BasicM1.derived end
    local okUid, uid = pcall(function() return LocalPlayer.UserId end)
    local prefix = okUid and string.sub(tostring(uid), 2, 4) or ""
    if #prefix ~= 3 then prefix = string.sub(REMOTE_SESSION_ID, 1, 3) end
    local hex = {}
    for i = 1, 5 do hex[i] = string.format("%x", math.random(0, 15)) end
    BasicM1.derived = prefix .. table.concat(hex)
    return BasicM1.derived
end

function BasicM1.alive(model)
    local okAlive, result = pcall(function()
        if not model or not model.Parent then return false end
        local hum = model:FindFirstChildOfClass("Humanoid")
        return hum ~= nil and hum.Health ~= nil and hum.Health > 0
    end)
    return okAlive and result == true
end

function BasicM1.hitPart(model)
    if not model then return nil end
    for _, name in ipairs(BasicM1.hitParts) do
        local okPart, part = pcall(function() return model:FindFirstChild(name) end)
        if okPart and part and part.Parent then return part end
    end
    local okRoot, root = pcall(function() return model:FindFirstChild("HumanoidRootPart") end)
    if okRoot and root then return root end
    return nil
end

-- Returns primaryPart, otherHits, primaryModel. `target` (an enemy model or a
-- player character) is the primary when alive and in range; otherwise the
-- first live enemy in range is. otherHits never repeats the primary rig unless
-- the active profile is the legacy shape.
function BasicM1.collect(target)
    local extras = {}
    local okMine, myPos = pcall(function()
        local char = LocalPlayer and LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        return hrp and hrp.Position
    end)
    if not okMine or not myPos then return nil, extras, nil end
    local maxDist = BasicM1.maxDist
    local function inRange(part)
        local okPos, pos = pcall(function() return part.Position end)
        if not okPos or not pos then return false end
        local dx, dy, dz = pos.X - myPos.X, pos.Y - myPos.Y, pos.Z - myPos.Z
        return math.sqrt(dx * dx + dy * dy + dz * dz) <= maxDist
    end

    local primaryPart, primaryModel, primaryKey = nil, nil, nil
    if target and BasicM1.alive(target) then
        local part = BasicM1.hitPart(target)
        if part and inRange(part) then
            primaryPart, primaryModel, primaryKey = part, target, instKey(target)
        end
    end

    local okKids, kids = pcall(function()
        local folder = Workspace and Workspace:FindFirstChild("Enemies")
        return folder and folder:GetChildren()
    end)
    if okKids and kids then
        for _, enemy in ipairs(kids) do
            if primaryPart and #extras >= BasicM1.maxExtra then break end
            if BasicM1.alive(enemy) and (primaryKey == nil or instKey(enemy) ~= primaryKey) then
                local part = BasicM1.hitPart(enemy)
                if part and inRange(part) then
                    if not primaryPart then
                        primaryPart, primaryModel, primaryKey = part, enemy, instKey(enemy)
                    else
                        table.insert(extras, { enemy, part })
                    end
                end
            end
        end
    end

    local prof = BasicM1.profiles[BasicM1.profile] or BasicM1.profiles[1]
    if primaryPart and not prof.clientShape then
        table.insert(extras, 1, { primaryModel, primaryPart })
    end
    return primaryPart, extras, primaryModel
end

-- One swing: RegisterAttack, one frame, RegisterHit. tagPrefix keeps the
-- existing safeRemote/remoteFailing tags ("" -> "RegisterAttack"/"RegisterHit",
-- "NPC Aura " -> "NPC Aura RegisterHit", ...), so the back-off and the Remote
-- Mode auto-off keep working unchanged.
function BasicM1.ready(tagPrefix)
    return clock() - (BasicM1.lastFireBy[tagPrefix] or 0) >= writeInterval(BasicM1.minInterval)
end

function BasicM1.fire(tagPrefix, primaryPart, extras)
    if not primaryPart or not ensureRemotes() then return false end
    -- Never swing while a CommF_ invoke (quest accept/abandon, AddPoint) is
    -- pending: the remotes are serialised (see quietInvoke in 00_core).
    if remoteInvokePending() then return false end
    if not BasicM1.ready(tagPrefix) then return false end
    local now = clock()
    BasicM1.lastFireBy[tagPrefix] = now
    local prof = BasicM1.profiles[BasicM1.profile] or BasicM1.profiles[1]
    if now - BasicM1.lastSwing > BasicM1.comboReset then BasicM1.combo = 0 end
    BasicM1.combo = BasicM1.combo % BasicM1.comboLen + 1
    BasicM1.lastSwing = now
    if prof.sendCombo then
        safeRemote(tagPrefix .. "RegisterAttack", _remoteRegAtk, "FireServer", BasicM1.attackLen, BasicM1.combo)
    else
        safeRemote(tagPrefix .. "RegisterAttack", _remoteRegAtk, "FireServer", BasicM1.attackLen)
    end
    frameWait()
    -- The frame above can despawn rigs collected before it: re-check them so
    -- RegisterHit never carries a part that has left the DataModel.
    local function attached(part)
        local okParent, parent = pcall(function() return part.Parent end)
        return okParent and parent ~= nil
    end
    if not attached(primaryPart) or remoteInvokePending() then return false end
    local fresh = {}
    for _, pair in ipairs(extras or {}) do
        if type(pair) == "table" and pair[1] and pair[2] and BasicM1.alive(pair[1]) and attached(pair[2]) then
            fresh[#fresh + 1] = pair
        end
    end
    local okHit = safeRemote(tagPrefix .. "RegisterHit", _remoteRegHit, "FireServer",
        primaryPart, fresh, nil, BasicM1.sessionId())
    _lastRemoteFire = clock()
    return okHit
end

-- No-damage watchdog: FireServer is fire-and-forget, so the only signal that
-- a profile works is the target's Health going down.
function BasicM1.watch(model)
    local okHp, hp = pcall(function()
        local hum = model:FindFirstChildOfClass("Humanoid")
        return hum and hum.Health
    end)
    if not okHp or type(hp) ~= "number" then return end
    local now = clock()
    local key = instKey(model)
    if key ~= BasicM1.watchKey then
        BasicM1.watchKey, BasicM1.watchHp, BasicM1.watchSince = key, hp, now
        return
    end
    if hp < BasicM1.watchHp - 0.01 then
        BasicM1.watchHp, BasicM1.watchSince = hp, now
        return
    end
    if hp > BasicM1.watchHp then BasicM1.watchHp = hp end
    if now - BasicM1.watchSince >= BasicM1.noDamageSecs then
        BasicM1.profile = BasicM1.profile % #BasicM1.profiles + 1
        BasicM1.watchSince = now
        warnThrottled("basicM1Profile", "[laced.club] Remote M1 dealt no damage for "
            .. tostring(BasicM1.noDamageSecs) .. "s; switching to profile "
            .. BasicM1.profiles[BasicM1.profile].name, 5)
    end
end

-- The one basic-attack entry point for every farm. Remote path when Remote
-- Mode is on (no clicks, no window focus needed, no head expander needed);
-- farmClick() only as the fallback when Remote Mode is off.
function basicAttack(target)
    if S.remoteMode then
        -- Swing gate first: also skips the Enemies scan in BasicM1.collect.
        if not BasicM1.ready("") then return false end
        if BasicM1.requireTool and type(getCurrentlyHeldTool) == "function" then
            local okTool, tool = pcall(getCurrentlyHeldTool)
            if okTool and not tool then return false end
        end
        local primary, extras, model = BasicM1.collect(target)
        if not primary then return false end
        local okHit = BasicM1.fire("", primary, extras)
        if okHit and model then BasicM1.watch(model) end
        remoteModeFallbackCheck()
        return okHit
    end
    return farmClick()
end

-- Kept for the existing call sites (farmAttack attackFn, Dungeon, Level
-- Farm, Auto Farm Quest). Now takes the fight target.
function remoteAttack(target)
    return basicAttack(target)
end

do
    local Dungeon={
        target=nil,
        targetingObjective=false,
        doorWaypoint=nil,
    }

    local function dungeonDistance(a,b)
        local dx=a.X-b.X
        local dy=a.Y-b.Y
        local dz=a.Z-b.Z
        return math.sqrt(dx*dx+dy*dy+dz*dz)
    end

    local function dungeonRoot(object)
        if not object then return nil end
        return object:FindFirstChild("HumanoidRootPart")
            or object:FindFirstChild("UpperTorso")
            or object:FindFirstChild("Head")
            or object:FindFirstChildWhichIsA("BasePart")
    end

    local function dungeonIsSummon(object)
        if not object then return true end
        if object:FindFirstChild("Summoner") or object:FindFirstChild("Creator") or object:FindFirstChild("Owner") then return true end
        local name=string.lower(object.Name or "")
        return string.find(name,"shadow",1,true)~=nil
            or string.find(name,"buddy",1,true)~=nil
            or string.find(name,"blank",1,true)~=nil
            or string.find(name,"clone",1,true)~=nil
            or string.find(name,"summon",1,true)~=nil
            or string.find(name,"decoy",1,true)~=nil
            or string.find(name,"dummy",1,true)~=nil
    end

    local function dungeonIsAlive(object)
        if not object or not object.Parent or dungeonIsSummon(object) then return false end
        local humanoid=object:FindFirstChildOfClass("Humanoid")
        return humanoid~=nil and humanoid.Health>0 and dungeonRoot(object)~=nil
    end

    local function dungeonIsObjective(object)
        if not dungeonIsAlive(object) then return false end
        local name=string.lower(object.Name or "")
        local objective=name=="prophitboxplaceholder"
            or string.find(name,"placeholder",1,true)~=nil
            or string.find(name,"gasvent",1,true)~=nil
            or string.find(name,"vent",1,true)~=nil
            or string.find(name,"shrine",1,true)~=nil
            or string.find(name,"rock",1,true)~=nil
            or string.find(name,"totem",1,true)~=nil
            or (string.find(name,"prop",1,true)~=nil and string.find(name,"knight",1,true)==nil and string.find(name,"boss",1,true)==nil)
        if not objective then return false end
        local humanoid=object:FindFirstChildOfClass("Humanoid")
        return humanoid and humanoid.MaxHealth<50000
    end

    local function dungeonNearestIsland(position)
        local map=Workspace:FindFirstChild("Map")
        local dungeon=map and map:FindFirstChild("Dungeon") or nil
        if not dungeon then return nil end
        local best=nil
        local bestDistance=math.huge
        for _,island in pairs(dungeon:GetChildren()) do
            local root=island:FindFirstChild("Root") or island:FindFirstChildWhichIsA("BasePart")
            if root then
                local dx=position.X-root.Position.X
                local dz=position.Z-root.Position.Z
                local distance=math.sqrt(dx*dx+dz*dz)
                if distance<bestDistance then
                    bestDistance=distance
                    best=island
                end
            end
        end
        return best
    end

    local function dungeonDoorWaypoint(position)
        local island=dungeonNearestIsland(position)
        local exit=island and island:FindFirstChild("ExitTeleporter") or nil
        local door=exit and (exit:FindFirstChild("Root") or exit:FindFirstChildWhichIsA("BasePart")) or nil
        if not door then return nil end
        local doorPosition=door.Position
        local dx=doorPosition.X-position.X
        local dz=doorPosition.Z-position.Z
        local distanceXZ=math.sqrt(dx*dx+dz*dz)
        if distanceXZ>30 then
            local islandRoot=island:FindFirstChild("Root") or island:FindFirstChildWhichIsA("BasePart")
            local islandY=islandRoot and islandRoot.Position.Y or 200
            return Vector3.new(doorPosition.X,math.max(position.Y,doorPosition.Y,islandY)+35,doorPosition.Z)
        end
        return Vector3.new(doorPosition.X,doorPosition.Y+3,doorPosition.Z)
    end

    local function dungeonFindTarget(playerPosition)
        local folder=Workspace:FindFirstChild("Enemies")
        if not folder then return nil,false end
        local bestObjective=nil
        local bestObjectiveDistance=math.huge
        local bestEnemy=nil
        local bestEnemyDistance=S.dungeonLocalRadius or 800

        for _,enemy in pairs(folder:GetChildren()) do
            if dungeonIsAlive(enemy) then
                local root=dungeonRoot(enemy)
                if root then
                    local distance=dungeonDistance(playerPosition,root.Position)
                    if S.dungeonDestroyObj and dungeonIsObjective(enemy) then
                        if distance<bestObjectiveDistance then
                            bestObjectiveDistance=distance
                            bestObjective=enemy
                        end
                    elseif distance<bestEnemyDistance then
                        bestEnemyDistance=distance
                        bestEnemy=enemy
                    end
                end
            end
        end
        if bestObjective then return bestObjective,true end
        return bestEnemy,false
    end

    task.spawn(function()
        while alive() do
            if S.dungeonEnabled then
                local head=nil
                local okStep,stepError=pcall(function()
                local character=LocalPlayer.Character
                local root=character and character:FindFirstChild("HumanoidRootPart") or nil
                local humanoid=character and character:FindFirstChildOfClass("Humanoid") or nil
                if root and humanoid and humanoid.Health>0 then
                    local target,isObjective=dungeonFindTarget(root.Position)
                    Dungeon.target=target
                    Dungeon.targetingObjective=isObjective
                    Dungeon.doorWaypoint=nil
                    local targetRoot=dungeonRoot(target)
                    if targetRoot then
                        local useRemote=S.remoteMode
                        if not useRemote then head=headExpander(target) end
                        local function engaged()
                            return alive() and S.dungeonEnabled and S.remoteMode==useRemote
                                and Dungeon.target==target and dungeonIsAlive(target)
                        end
                        local p=targetRoot.Position
                        local ox,oy,oz=getNormalFarmOffsets()
                        local targetPosition=Vector3.new(p.X+ox,p.Y+oy,p.Z+oz)
                        tweenTo(root,targetPosition,S.FARM_SPEED,engaged)

                        local lastAttack=0
                        while engaged() do
                            targetRoot=dungeonRoot(target)
                            if not targetRoot then break end
                            p=targetRoot.Position
                            ox,oy,oz=getNormalFarmOffsets()
                            targetPosition=Vector3.new(p.X+ox,p.Y+oy,p.Z+oz)
                            hardLockNpcCFrame(root,targetPosition)
                            if head then head.apply() end

                            local now=clock()
                            local attackDelay=useRemote and 0.05 or 0.06
                            if now-lastAttack>=attackDelay then
                                lastAttack=now
                                if useRemote then
                                    local swingTarget=target -- task.spawn forwards no arguments
                                    task.spawn(function() remoteAttack(swingTarget) end)
                                else farmClick() end
                            end
                            frameWait()
                        end
                    elseif S.dungeonAutoDoor then
                        Dungeon.doorWaypoint=dungeonDoorWaypoint(root.Position)
                        if Dungeon.doorWaypoint then
                            tweenTo(root,Dungeon.doorWaypoint,S.FARM_SPEED,function()
                                return S.dungeonEnabled and S.dungeonAutoDoor
                            end)
                        end
                    end
                end
                end)
                -- Restore the hitbox even when the step failed half-way.
                if head then head.restore() end
                if not okStep then
                    Dungeon.target=nil
                    Dungeon.targetingObjective=false
                    warnThrottled("dungeon","[laced.club] Dungeon step failed: "..tostring(stepError),15)
                end
            else
                Dungeon.target=nil
                Dungeon.targetingObjective=false
                Dungeon.doorWaypoint=nil
            end
            task.wait(0.1)
        end
    end)

    task.spawn(function()
        local skillKeys={0x5A,0x58,0x43,0x56}
        while alive() do
            if S.dungeonEnabled and S.dungeonUseMoves
                and Dungeon.targetingObjective and dungeonIsAlive(Dungeon.target) then
                for _,keyCode in pairs(skillKeys) do
                    if not S.dungeonEnabled or not dungeonIsAlive(Dungeon.target) then break end
                    -- Keys go to whatever window has focus: only with Roblox in front.
                    if robloxFocused() then
                        pcall(function()
                            keypress(keyCode)
                            task.wait(0.04)
                            keyrelease(keyCode)
                        end)
                    end
                    task.wait(0.16)
                end
            end
            task.wait(0.3)
        end
    end)

end

-- Load marker: this chunk ran to the end.
if LACED_LOAD and type(LACED_LOAD.done) == "table" then LACED_LOAD.done["40_combat"] = true end
