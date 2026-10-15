--[[ crash_patch.luau  (Oct 15 2026)  -- NOT APPLIED.
  Find/replace pairs for the Auto Farm Quest crash mitigations described in
  CRASH_FINDINGS.md. Each FIND is verbatim text from the src chunk named in
  `file` and occurs exactly once in that file (checked against the src tree
  of Oct 15 2026; 60_afq.lua was being edited by another agent at the time,
  so re-check its FIND texts before applying). Apply in order; `depends`
  names a pair that must be applied too. Applying all pairs to a copy of the
  tree passes `luau-lsp analyze` with zero syntax errors and no new unknown
  globals in the concatenation.
  Long strings: Lua drops the newline right after `[==[`, so every FIND /
  REPLACE below is exactly the text between that newline and `]==]`.
  A/B switch after applying: AFQ_DEBUG.safeMode = true halves every patched rate.
]]
return {
  {
    id = "P01",
    file = "src/00_core.lua",
    what = [==[Root write helpers: ROOT_WRITE_HZ (30), writeInterval() (doubles every interval when AFQ_DEBUG.safeMode is true); moveRoot never writes to a detached root and skips the CFrame write when the root is already within 0.05 studs of the target; zeroVelocity writes only a non-zero velocity and never to a detached part.]==],
    find = [==[
function moveRoot(part, x, y, z, rotation)
    if not part then return false end
    local okCFrame = pcall(function()
        local positionCF = CFrame.new(x, y, z)
        part.CFrame = rotation and (positionCF * rotation) or positionCF
    end)
    if okCFrame then return true end
    return (pcall(function() part.Position = Vector3.new(x, y, z) end))
end

function setPartPosition(part, position)
    if not part or not position then return false end
    return (pcall(function() part.Position = position end))
end

function zeroVelocity(part)
    if not part then return end
    pcall(function() part.Velocity = Vector3.new(0, 0, 0) end)
    pcall(function() part.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
end]==],
    replace = [==[
-- Bridge write budget (crash mitigation, see CRASH_FINDINGS.md). Every root
-- CFrame/velocity write goes through Matcha's external memory bridge; the
-- hard-lock, holdAt and tween loops used to write 180-300 times a second.
-- AFQ_DEBUG.safeMode = true doubles every interval that uses writeInterval()
-- (halves those rates) for A/B crash testing.
ROOT_WRITE_HZ = 30
ROOT_SKIP_DIST_SQ = 0.05 * 0.05
-- WRITE_BUDGET.debug is linked to the AFQ_DEBUG table by 20_ui2 (pair P08),
-- so AFQ_DEBUG.safeMode = true switches safe mode on at runtime.
WRITE_BUDGET = { debug = nil }
function safeModeOn()
    local debug = WRITE_BUDGET.debug
    return type(debug) == "table" and debug.safeMode == true
end
function writeInterval(base)
    return safeModeOn() and base * 2 or base
end

function moveRoot(part, x, y, z, rotation)
    if not part then return false end
    -- Never write to a root that left the DataModel (died, respawned, streamed
    -- out); skip the write when it already sits on the target.
    local okState, parent, current = pcall(function() return part.Parent, part.Position end)
    if not okState or parent == nil then return false end
    if current and current.X then
        local dx, dy, dz = current.X - x, current.Y - y, current.Z - z
        if dx * dx + dy * dy + dz * dz <= ROOT_SKIP_DIST_SQ then return true end
    end
    local okCFrame = pcall(function()
        local positionCF = CFrame.new(x, y, z)
        part.CFrame = rotation and (positionCF * rotation) or positionCF
    end)
    if okCFrame then return true end
    return (pcall(function() part.Position = Vector3.new(x, y, z) end))
end

function setPartPosition(part, position)
    if not part or not position then return false end
    return (pcall(function() part.Position = position end))
end

local function nearZeroVector(v)
    return v ~= nil and v.X ~= nil and math.abs(v.X) + math.abs(v.Y) + math.abs(v.Z) < 0.01
end
function zeroVelocity(part)
    if not part then return end
    local okState, parent, velocity, assembly = pcall(function()
        return part.Parent, part.Velocity, part.AssemblyLinearVelocity
    end)
    if okState and parent == nil then return end
    if not (okState and nearZeroVector(velocity)) then
        pcall(function() part.Velocity = Vector3.new(0, 0, 0) end)
    end
    if not (okState and nearZeroVector(assembly)) then
        pcall(function() part.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
    end
end]==],
  },
  {
    id = "P02",
    file = "src/40_combat.lua",
    what = [==[hardLockNpcCFrame capped at ROOT_WRITE_HZ (30 Hz; 15 Hz in safe mode) for every caller (AFQ, Level Farm, farmAttack, Dungeon); vertical velocity is written only when it is not already ~0, and nothing is written when moveRoot refused (detached root).]==],
    find = [==[
function hardLockNpcCFrame(hrp,targetPos)
    if not hrp or not targetPos then return end
    moveRoot(hrp,targetPos.X,targetPos.Y,targetPos.Z,rootRotation(hrp))

    pcall(function()
        local velocity=hrp.Velocity
        if velocity and velocity.X and velocity.Z then
            hrp.Velocity=Vector3.new(velocity.X,0,velocity.Z)
        end
    end)
    pcall(function()
        local assemblyVelocity=hrp.AssemblyLinearVelocity
        if assemblyVelocity and assemblyVelocity.X and assemblyVelocity.Z then
            hrp.AssemblyLinearVelocity=Vector3.new(assemblyVelocity.X,0,assemblyVelocity.Z)
        end
    end)
end]==],
    replace = [==[
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
end]==],
  },
  {
    id = "P03",
    file = "src/40_combat.lua",
    what = [==[headExpander: apply() runs its checks at most 4 Hz (2 Hz safe mode), writes Head.Size / CanCollide only when they differ, never on a detached Head or on a model whose Humanoid is dead or missing; restore() skips dead or detached enemies (they are despawning).]==],
    find = [==[
function headExpander(model)
    local state={head=nil,size=nil,canCollide=nil}
    local okHead,head=pcall(function() return model:FindFirstChild("Head") end)
    if okHead and head then
        state.head=head
        pcall(function()
            state.size=head.Size
            state.canCollide=head.CanCollide
        end)
    end
    function state.apply()
        local okCurrent,current=pcall(function() return model:FindFirstChild("Head") end)
        if okCurrent and current then state.head=current end
        if state.head then
            local size=S.bigHitbox and 200 or 50
            pcall(function()
                state.head.Size=Vector3.new(size,size,size)
                state.head.CanCollide=false
            end)
        end
    end
    function state.restore()
        local target=state.head
        if not target or not state.size then return end
        pcall(function()
            if target.Parent then
                target.Size=state.size
                if state.canCollide~=nil then target.CanCollide=state.canCollide end
            end
        end)
    end
    return state
end]==],
    replace = [==[
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
end]==],
  },
  {
    id = "P04",
    file = "src/40_combat.lua",
    what = [==[BasicM1.minInterval 0.045 s -> 0.25 s (at most 4 swings/s per caller tag, 2/s in safe mode). Revert to 0.045 only if a live test proves the remote farm needs it.]==],
    find = [==[
    minInterval  = 0.045, -- per caller tag; farms call at 0.05 s
]==],
    replace = [==[
    minInterval  = 0.25,  -- per caller tag (was 0.045: ~20 swings = 40 FireServer/s); the client's own M1 is ~3-4/s
]==],
  },
  {
    id = "P05",
    file = "src/40_combat.lua",
    what = [==[BasicM1.ready(tag) gate (safe-mode aware) used by fire(); after fire()'s one-frame yield the primary part and every extra rig are re-validated (Parent ~= nil, Humanoid alive), so RegisterHit never serialises a part that despawned during that frame.]==],
    find = [==[
function BasicM1.fire(tagPrefix, primaryPart, extras)
    if not primaryPart or not ensureRemotes() then return false end
    local now = clock()
    if now - (BasicM1.lastFireBy[tagPrefix] or 0) < BasicM1.minInterval then return false end
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
    local okHit = safeRemote(tagPrefix .. "RegisterHit", _remoteRegHit, "FireServer",
        primaryPart, extras or {}, nil, BasicM1.sessionId())
    _lastRemoteFire = clock()
    return okHit
end]==],
    replace = [==[
function BasicM1.ready(tagPrefix)
    return clock() - (BasicM1.lastFireBy[tagPrefix] or 0) >= writeInterval(BasicM1.minInterval)
end

function BasicM1.fire(tagPrefix, primaryPart, extras)
    if not primaryPart or not ensureRemotes() then return false end
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
    if not attached(primaryPart) then return false end
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
end]==],
  },
  {
    id = "P06",
    file = "src/40_combat.lua",
    what = [==[basicAttack checks the swing gate before BasicM1.collect, so the Workspace.Enemies scan (GetChildren plus up to 9 FindFirstChild per enemy) runs at the swing rate (4/s) instead of on every call (~20/s).]==],
    depends = "P05",
    find = [==[
function basicAttack(target)
    if S.remoteMode then
]==],
    replace = [==[
function basicAttack(target)
    if S.remoteMode then
        -- Swing gate first: also skips the Enemies scan in BasicM1.collect.
        if not BasicM1.ready("") then return false end
]==],
  },
  {
    id = "P07",
    file = "src/30_esp.lua",
    what = [==[tweenTo: step 0.01 s (~100 CFrame writes/s) -> 1/60 s (1/30 s safe mode); the local root is re-fetched from LocalPlayer.Character every step and matched by instKey, so a root that died or respawned mid-tween is never written again.]==],
    depends = "P01",
    find = [==[
TWEEN_STEP_TIME=0.01

-- Lerps the root part to targetPos at `speed` studs/s. Returns true when the
-- target was reached, false when stopped (checkFn false, part gone, unload).
function tweenTo(hrp, targetPos, speed, checkFn)
    if not hrp or not targetPos then return false end
    local okStart,startPos=pcall(function() return hrp.Position end)
    if not okStart or not startPos then return false end
    local rotationCF=rootRotation(hrp)
    local function keepGoing()
        if not alive() then return false end
        if not checkFn then return true end
        local okCheck,result=pcall(checkFn)
        return okCheck and result and true or false
    end
    local dx=targetPos.X-startPos.X; local dy=targetPos.Y-startPos.Y; local dz=targetPos.Z-startPos.Z
    local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
    if distance<=1 then
        return moveRoot(hrp,targetPos.X,targetPos.Y,targetPos.Z,rotationCF)
    end
    local moveSpeed=tonumber(speed) or 320
    if moveSpeed<=0 then moveSpeed=320 end
    local duration=distance/moveSpeed; local startTime=clock()
    while keepGoing() do
        local okParent,parent=pcall(function() return hrp.Parent end)
        if not okParent or not parent then return false end
        local alpha=math.min((clock()-startTime)/duration,1)
        if not moveRoot(hrp,startPos.X+dx*alpha,startPos.Y+dy*alpha,startPos.Z+dz*alpha,rotationCF) then
            return false
        end
        if alpha>=1 then return true end
        task.wait(TWEEN_STEP_TIME)
    end
    return false
end]==],
    replace = [==[
TWEEN_STEP_TIME=1/60 -- was 0.01 (~100 CFrame writes/s through the bridge); safe mode doubles it

-- Lerps the root part to targetPos at `speed` studs/s. Returns true when the
-- target was reached, false when stopped (checkFn false, part gone, unload).
function tweenTo(hrp, targetPos, speed, checkFn)
    if not hrp or not targetPos then return false end
    local okStart,startPos=pcall(function() return hrp.Position end)
    if not okStart or not startPos then return false end
    local rotationCF=rootRotation(hrp)
    -- The local character's root is re-fetched every step and compared by key:
    -- after a death or respawn the old root (possibly freed) is never touched.
    local rootKey=instKey(hrp)
    local isLocalRoot=false
    pcall(function()
        local char=LocalPlayer.Character
        local cur=char and char:FindFirstChild("HumanoidRootPart")
        isLocalRoot=cur~=nil and instKey(cur)==rootKey
    end)
    local function currentPart()
        if not isLocalRoot then
            local okParent,parent=pcall(function() return hrp.Parent end)
            return (okParent and parent) and hrp or nil
        end
        local okCur,cur=pcall(function()
            local char=LocalPlayer.Character
            return char and char:FindFirstChild("HumanoidRootPart")
        end)
        if okCur and cur and instKey(cur)==rootKey then return cur end
        return nil
    end
    local function keepGoing()
        if not alive() then return false end
        if not checkFn then return true end
        local okCheck,result=pcall(checkFn)
        return okCheck and result and true or false
    end
    local dx=targetPos.X-startPos.X; local dy=targetPos.Y-startPos.Y; local dz=targetPos.Z-startPos.Z
    local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
    if distance<=1 then
        return moveRoot(hrp,targetPos.X,targetPos.Y,targetPos.Z,rotationCF)
    end
    local moveSpeed=tonumber(speed) or 320
    if moveSpeed<=0 then moveSpeed=320 end
    local duration=distance/moveSpeed; local startTime=clock()
    while keepGoing() do
        local part=currentPart()
        if not part then return false end
        local alpha=math.min((clock()-startTime)/duration,1)
        if not moveRoot(part,startPos.X+dx*alpha,startPos.Y+dy*alpha,startPos.Z+dz*alpha,rotationCF) then
            return false
        end
        if alpha>=1 then return true end
        task.wait(writeInterval(TWEEN_STEP_TIME))
    end
    return false
end]==],
  },
  {
    id = "P08",
    file = "src/20_ui2.lua",
    what = [==[AFQ_DEBUG gains safeMode=false (the A/B switch read by writeInterval()).]==],
    depends = "P01",
    find = [==[
AFQ_DEBUG={noAccept=false,noFight=false,noHead=false,noLock=false,noClick=false,forceLevel=nil,forceBossAlive=nil,phase="idle"}
]==],
    replace = [==[
-- safeMode (false in normal use): true doubles every bridge-write / swing
-- interval (root lock, holdAt, tween step, head expander, BasicM1, clicks)
-- for A/B crash tests.
AFQ_DEBUG={noAccept=false,noFight=false,noHead=false,noLock=false,noClick=false,forceLevel=nil,forceBossAlive=nil,phase="idle",safeMode=false}
WRITE_BUDGET.debug=AFQ_DEBUG -- writeInterval() (00_core) reads safeMode through this link
]==],
  },
  {
    id = "P09",
    file = "src/20_ui2.lua",
    what = [==[afq_updateLabel writes the status label only when the text changed and at most 4 Hz, with one trailing update so the newest status still shows (task.spawn + task.wait; task.delay is a no-op in Matcha).]==],
    find = [==[
function afq_updateLabel()
    local label=AFQ_STATUS_LABEL
    if type(label)=="table" then
        pcall(function() label.Text="Auto Farm Quest: "..tostring(AFQ.status) end)
    end
end]==],
    replace = [==[
AFQ_LABEL_INTERVAL=0.25 -- s between two status label writes (4 Hz)
AFQ_LABEL={last=nil,at=-1e9,pending=false}
function afq_updateLabel()
    local label=AFQ_STATUS_LABEL
    if type(label)~="table" then return end
    local text="Auto Farm Quest: "..tostring(AFQ.status)
    if text==AFQ_LABEL.last then return end
    local now=clock()
    local left=AFQ_LABEL_INTERVAL-(now-AFQ_LABEL.at)
    if left>0 then
        -- Throttled: one trailing update shows the newest status.
        if not AFQ_LABEL.pending then
            AFQ_LABEL.pending=true
            task.spawn(function()
                task.wait(left)
                AFQ_LABEL.pending=false
                if alive() then pcall(afq_updateLabel) end
            end)
        end
        return
    end
    AFQ_LABEL.last=text; AFQ_LABEL.at=now
    pcall(function() label.Text=text end)
end]==],
  },
  {
    id = "P10",
    file = "src/60_afq.lua",
    what = [==[Tracker reads: new afq_trackerTexts(frame) does one GetDescendants at most once per AFQ_TRACKER_TTL (1 s) and caches the strings (never the Instances); a different TrackedQuestFrame invalidates the cache. afq_trackerProgress uses it.]==],
    find = [==[
function afq_trackerFrame()
    local ok,frame=pcall(function() return LocalPlayer.PlayerGui:FindFirstChild("TrackedQuestFrame") end)
    return ok and frame or nil
end

-- "k/n" progress from the tracker when it shows one; nil otherwise.
function afq_trackerProgress()
    local frame=afq_trackerFrame()
    if not frame then return nil end
    local okDesc,descendants=pcall(function() return frame:GetDescendants() end)
    if not okDesc or not descendants then return nil end
    for _,d in pairs(descendants) do
        local okText,text=pcall(function() return d.Text end)
        if okText and type(text)=="string" then
            local k,n=string.match(text,"(%d+)%s*/%s*(%d+)")
            if k and n then return tonumber(k),tonumber(n) end
        end
    end
    return nil
end]==],
    replace = [==[
function afq_trackerFrame()
    local ok,frame=pcall(function() return LocalPlayer.PlayerGui:FindFirstChild("TrackedQuestFrame") end)
    return ok and frame or nil
end

-- Text of every TrackedQuestFrame descendant, from one GetDescendants at most
-- every AFQ_TRACKER_TTL s (afq_waitTrackerFor polls at 10 Hz). Strings are
-- cached, never Instances, so a React re-render leaves no stale handles; a
-- different frame (tracker closed and reopened) invalidates the cache.
AFQ_TRACKER_TTL=1
AFQ_TRACKER_CACHE={key=nil,at=-1e9,texts=nil}
function afq_trackerTexts(frame)
    if not frame then return nil end
    local key=instKey(frame)
    local cache=AFQ_TRACKER_CACHE
    local now=clock()
    if cache.texts and cache.key==key and now-cache.at<AFQ_TRACKER_TTL then return cache.texts end
    local okDesc,descendants=pcall(function() return frame:GetDescendants() end)
    if not okDesc or not descendants then return nil end
    local texts={}
    for _,d in pairs(descendants) do
        local okText,text=pcall(function() return d.Text end)
        if okText and type(text)=="string" and text~="" then texts[#texts+1]=text end
    end
    cache.key=key; cache.at=now; cache.texts=texts
    return texts
end

-- "k/n" progress from the tracker when it shows one; nil otherwise.
function afq_trackerProgress()
    local texts=afq_trackerTexts(afq_trackerFrame())
    if not texts then return nil end
    for _,text in ipairs(texts) do
        local k,n=string.match(text,"(%d+)%s*/%s*(%d+)")
        if k and n then return tonumber(k),tonumber(n) end
    end
    return nil
end]==],
  },
  {
    id = "P11",
    file = "src/60_afq.lua",
    what = [==[afq_trackerQuestIs reads the cached tracker strings (part 1 of 2: the GetDescendants call).]==],
    depends = "P10",
    find = [==[
    local okDesc,descendants=pcall(function() return frame:GetDescendants() end)
    if not okDesc or not descendants then return "unknown" end
]==],
    replace = [==[
    local texts=afq_trackerTexts(frame)
    if not texts then return "unknown" end
]==],
  },
  {
    id = "P12",
    file = "src/60_afq.lua",
    what = [==[afq_trackerQuestIs reads the cached tracker strings (part 2 of 2: the loop head; `do` keeps the old `if ... end` block balanced).]==],
    depends = "P11",
    find = [==[
    for _,d in pairs(descendants) do
        local okText,text=pcall(function() return d.Text end)
        if okText and type(text)=="string" then
            local lower=string.lower(string.match(text,"^%s*(.-)%s*$") or text)
]==],
    replace = [==[
    for _,text in ipairs(texts) do
        do
            local lower=string.lower(string.match(text,"^%s*(.-)%s*$") or text)
]==],
  },
  {
    id = "P13",
    file = "src/60_afq.lua",
    what = [==[afq_holdAt writes root CFrame/velocity at ROOT_WRITE_HZ (30 Hz; 15 Hz safe mode) instead of every frame; it still yields on every pass.]==],
    depends = "P01",
    find = [==[
function afq_holdAt(position,seconds)
    local deadline=clock()+(seconds or 0)
    repeat
        local _,root=afl_getCharacter()
        if root and position and afq_farming() then
            moveRoot(root,position.X,position.Y,position.Z,rootRotation(root))
            zeroVelocity(root)
        end
        frameWait()
    until clock()>=deadline or not afq_farming()
end]==],
    replace = [==[
function afq_holdAt(position,seconds)
    local deadline=clock()+(seconds or 0)
    repeat
        local _,root=afl_getCharacter()
        if root and position and afq_farming() then
            moveRoot(root,position.X,position.Y,position.Z,rootRotation(root))
            zeroVelocity(root)
        end
        task.wait(writeInterval(1/ROOT_WRITE_HZ))
    until clock()>=deadline or not afq_farming()
end]==],
  },
  {
    id = "P14",
    file = "src/60_afq.lua",
    what = [==[afq_fight click interval becomes safe-mode aware (0.06 s, 0.12 s when AFQ_DEBUG.safeMode); remote swings are capped by P04-P06.]==],
    depends = "P01",
    find = [==[
        elseif useRemote then
            if now-lastRemoteAttack>=0.05 then remoteAttack(npc); lastRemoteAttack=now end
        else
            if now-lastClick>=0.06 then farmClick(); lastClick=now end
]==],
    replace = [==[
        elseif useRemote then
            if now-lastRemoteAttack>=0.05 then remoteAttack(npc); lastRemoteAttack=now end
        else
            if now-lastClick>=writeInterval(0.06) then farmClick(); lastClick=now end
]==],
  },
}
