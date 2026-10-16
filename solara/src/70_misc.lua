-- @chunk 70_misc  (lines 6379-7475 of the single-file build)
local LACED_LOAD = type(getgenv().__lacedLoad) == "table" and getgenv().__lacedLoad or nil -- load marker (loader.lua)
if LACED_LOAD and type(LACED_LOAD.started) == "table" then LACED_LOAD.started["70_misc"] = true end
-- Per-execution bindings: captured at chunk load so a re-run of the script
-- cannot make this copy's loops read the new copy's state (alive is a
-- closure over this run's state since the Oct 15 stability pass).
local alive = alive
local SCRIPT_STATE = SCRIPT_STATE
local S = S
function localRoot()
    local char=LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end

-- Stability pass (Oct 15 2026): 30 Hz instead of every frame, only living
-- enemies (no write races a despawn), CanCollide written only when it is
-- still true, nothing during a CommF_ quiet window, idle cadence while off.
PULL_WRITE_HZ=30
function doPullLoop(flag, getPoint)
    task.spawn(function()
        while alive() do
            local on=flag()
            if on and not writesPaused() then
                local myHrp=localRoot()
                local okPoint,pullPoint=pcall(getPoint,myHrp)
                local folder=Workspace:FindFirstChild("Enemies")
                if myHrp and okPoint and pullPoint and folder then
                    -- Inline per enemy: the old code spawned one thread per enemy every frame.
                    for _, model in pairs(folder:GetChildren()) do
                        pcall(function()
                            if isA(model,"Model") and isAlive(model) then
                                local hrp=model:FindFirstChild("HumanoidRootPart")
                                if hrp then
                                    if hrp.CanCollide~=false then hrp.CanCollide=false end
                                    hrp.Position=pullPoint
                                end
                            end
                        end)
                    end
                end
            end
            if on then task.wait(writeInterval(1/PULL_WRITE_HZ)) else task.wait(IDLE_POLL) end
        end
    end)
end

doPullLoop(function() return S.pullEnemies end,  function(h) return Vector3.new(h.Position.X, h.Position.Y-10, h.Position.Z) end)
doPullLoop(function() return S.buddhaPull end,   function(h) return Vector3.new(h.Position.X+37, h.Position.Y-3, h.Position.Z) end)
doPullLoop(function() return S.customPull end,   function(h) return Vector3.new(h.Position.X+S.customPullX, h.Position.Y+S.customPullY, h.Position.Z+S.customPullZ) end)

-- Auto Ken / Auto Haki: keys only with Roblox in front (they went to any
-- window), and after 5 presses that did not turn the state on (attribute
-- missing or renamed: Matcha reads it as nil) one press every 10 s instead of
-- every pass.
task.spawn(function()
    local misses,nextPress=0,0
    while alive() do
        task.wait(0.1)
        if S.autoKen then
            local okAttr,kenActive=pcall(function() return LocalPlayer:GetAttribute("KenActive") end)
            if okAttr and kenActive then misses=0 end
            if okAttr and not kenActive and robloxFocused() and clock()>=nextPress then
                pcall(function() keypress(0x45); task.wait(0.1); keyrelease(0x45) end)
                misses=misses+1
                if misses>=5 then nextPress=clock()+10 end
            end
        else
            misses,nextPress=0,0
        end
    end
end)

task.spawn(function()
    local misses,nextPress=0,0
    while alive() do
        task.wait(0.25)
        if S.autoHaki then
            local char=LocalPlayer.Character
            if char and char:FindFirstChild("HasBuso") then misses=0 end
            if char and not char:FindFirstChild("HasBuso") and robloxFocused() and clock()>=nextPress then
                pcall(function()
                                keypress(0x4A)
                    task.wait(0.1)
                    keyrelease(0x4A)
                end)
                misses=misses+1
                if misses>=5 then nextPress=clock()+10 end
            end
        else
            misses,nextPress=0,0
        end
    end
end)

task.spawn(function()
    while alive() do
        -- 30 Hz while on (two root writes per pass), idle cadence while off.
        if S.freezePos then task.wait(writeInterval(1/30)) else task.wait(IDLE_POLL) end
        if S.freezePos then
            local hrp=localRoot()
            if hrp then
                -- Toggled on before the character existed: lock where it spawns.
                if not S.freezePosition then
                    local okPos,pos=pcall(function() return hrp.Position end)
                    if okPos and pos then S.freezePosition=pos end
                end
                -- No second mover while a tween owns the root (Oct 15 2026).
                if S.freezePosition and not rootTweenOwned() then
                    setPartPosition(hrp,S.freezePosition)
                    zeroVelocity(hrp)
                end
            end
        end
    end
end)

task.spawn(function()
    while alive() do
        if S.freezeEnemies then task.wait(writeInterval(1/30)) else task.wait(IDLE_POLL) end
        if S.freezeEnemies and not writesPaused() then
            -- Keyed by Instance.Address: Instance userdata are not guaranteed to be
            -- the same table key between GetChildren calls.
            local folder=Workspace:FindFirstChild("Enemies")
            if folder then
                for _, model in pairs(folder:GetChildren()) do
                    pcall(function()
                        local key=instKey(model)
                        if isA(model,"Model") and not S.frozenEnemies[key] then
                            local hrp=model:FindFirstChild("HumanoidRootPart")
                            if hrp then S.frozenEnemies[key]={model=model,position=hrp.Position} end
                        end
                    end)
                end
            end
            for key, frozen in pairs(S.frozenEnemies) do
                local model=frozen.model
                -- Dead enemies are dropped: no write may race their despawn.
                if partStillThere(model) and isAlive(model) then
                    pcall(function()
                        local hrp=model:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.Position=frozen.position
                            zeroVelocity(hrp)
                        end
                    end)
                else S.frozenEnemies[key]=nil end
            end
        end
    end
end)

task.spawn(function()
    while alive() do
        task.wait(0.05)
        if S.tweenEmber then
            local okStep=pcall(function()
            local hrp=localRoot()
            if hrp then
                local currentPos=hrp.Position
                local closestModel=nil
                local closestPart=nil
                local closestDistance=math.huge
                for _, obj in pairs(Workspace:GetChildren()) do
                    if obj.Name=="EmberTemplate" and isA(obj,"Model") then
                        local part=obj:FindFirstChild("Part") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                        if part and isA(part,"BasePart") then
                            local emberPos=part.Position
                            local dx=emberPos.X-currentPos.X
                            local dy=emberPos.Y-currentPos.Y
                            local dz=emberPos.Z-currentPos.Z
                            local distance=dx*dx+dy*dy+dz*dz
                            if distance<closestDistance then
                                closestDistance=distance
                                closestModel=obj
                                closestPart=part
                            end
                        end
                    end
                end
                if closestModel and closestPart then
                    local emberPos=closestPart.Position
                    local targetPos=Vector3.new(emberPos.X,emberPos.Y+3,emberPos.Z)
                    tweenTo(hrp,targetPos,1200,function()
                        return S.tweenEmber and partStillThere(closestModel) and partStillThere(closestPart)
                    end)
                    zeroVelocity(hrp)
                    task.wait(0.08)
                else
                    task.wait(0.2)
                end
            end
            end)
            if not okStep then task.wait(0.2) end
        end
    end
end)

task.spawn(function()
    while alive() do
        idleWait(S.tweenEmber)
        if S.tweenEmber then
            zeroVelocity(localRoot())
        end
    end
end)

task.spawn(function()
    while alive() do
        task.wait(0.5)
        if S.teleportEmber and not S.tweenEmber then
            local hrp=localRoot()
            if hrp then
                for _,obj in pairs(Workspace:GetChildren()) do
                    -- Stop mid-list as soon as the toggle goes off (it used to finish
                    -- the whole list, 0.5 s per ember, after being disabled).
                    if not (alive() and S.teleportEmber and not S.tweenEmber) then break end
                    local okEmber,part=pcall(function()
                        if obj.Name=="EmberTemplate" and isA(obj,"Model") then
                            local candidate=obj:FindFirstChild("Part")
                            if candidate and isA(candidate,"BasePart") then return candidate end
                        end
                        return nil
                    end)
                    if okEmber and part then
                        local okPos,partPos=pcall(function() return part.Position end)
                        if okPos and partPos then
                            setPartPosition(hrp,Vector3.new(partPos.X,partPos.Y+3,partPos.Z))
                            zeroVelocity(hrp)
                            task.wait(0.5)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while alive() do
        idleWait(S.teleportEmber and not S.tweenEmber)
        if S.teleportEmber and not S.tweenEmber and not writesPaused() then
            local hrp=localRoot()
            if hrp then
                pcall(function()
                    hrp.Velocity=Vector3.new(0,1,0)
                    hrp.AssemblyLinearVelocity=Vector3.new(0,1,0)
                end)
            end
        end
    end
end)

task.spawn(function()
    while alive() do
        task.wait(2)
        if S.teleportKitsune then
            local okStep=pcall(function()
            local hrp=localRoot()
            if hrp then
                local map=Workspace:FindFirstChild("Map")
                if map then
                    local kitsune=map:FindFirstChild("KitsuneIsland")
                    if kitsune then
                        local lampPost=kitsune:FindFirstChild("LampPost")
                        if lampPost then
                            local part=lampPost:FindFirstChild("Part")
                            if part and isA(part,"BasePart") then
                                local startPos=hrp.Position
                                local endPos=Vector3.new(part.Position.X, part.Position.Y+3, part.Position.Z)
                                local duration=2; local startTime=clock()
                                while alive() and S.teleportKitsune and clock()-startTime<duration do
                                    local progress=(clock()-startTime)/duration
                                    if not setPartPosition(hrp,Vector3.new(
                                        startPos.X+(endPos.X-startPos.X)*progress,
                                        startPos.Y+(endPos.Y-startPos.Y)*progress,
                                        startPos.Z+(endPos.Z-startPos.Z)*progress
                                    )) then break end
                                    task.wait(0.05)
                                end
                                if S.teleportKitsune then
                                    setPartPosition(hrp,endPos)
                                    zeroVelocity(hrp)
                                end
                            end
                        end
                    end
                end
            end
            end)
            if not okStep then warnThrottled("kitsune","[laced.club] Kitsune tween step failed",30) end
        end
    end
end)

task.spawn(function()
    while alive() do
        idleWait(S.teleportKitsune)
        if S.teleportKitsune then
            zeroVelocity(localRoot())
        end
    end
end)

task.spawn(function()
    while alive() do
        task.wait(0.5)
        if not S.autoRaid or S.autoBossFarm or S.autoMaterialFarm or S.autoSeaEvent or S.autoMirageTween or S.autoMirageGear or S.fruitPriorityActive then
            S.raidDetected=false
            S.raidTweenActive=false
            S.raidLastIslandNum=0
            S.raidLastIslandKey=nil
            S.raidMapKey=nil
        else
            local okScan,scanError=pcall(function()
            local map=Workspace:FindFirstChild("Map")
            local raidMap=map and map:FindFirstChild("RaidMap")
            local origin=Workspace:FindFirstChild("_WorldOrigin")
            local locations=origin and origin:FindFirstChild("Locations")
            local raidContainer=raidMap
            if not raidContainer and locations then
                for index=1,5 do
                    if locations:FindFirstChild("Island "..tostring(index)) then raidContainer=locations; break end
                end
            end
            if not raidContainer then
                S.raidDetected=false
                if S.raidMapKey~=nil or S.raidTweenActive then
                    S.raidMoveGeneration=S.raidMoveGeneration+1
                end
                S.raidTweenActive=false
                S.raidLastIslandNum=0
                S.raidLastIslandKey=nil
                S.raidMapKey=nil
            else
                S.raidDetected=true
                local currentMapKey=trackedInstanceKey(raidContainer)
                if S.raidMapKey~=currentMapKey then
                    if S.raidMapKey~=nil or S.raidTweenActive then
                        S.raidMoveGeneration=S.raidMoveGeneration+1
                    end
                    S.raidTweenActive=false
                    S.raidMapKey=currentMapKey
                    S.raidLastIslandNum=0
                    S.raidLastIslandKey=nil
                end

                local highestIsland=0
                local highestIslandModel=nil
                for _,child in pairs(raidContainer:GetChildren()) do
                    local name=child.Name
                    local num=nil
                    if type(name)=="string" and string.sub(name,1,10)=="RaidIsland" then
                        num=tonumber(string.sub(name,11))
                    elseif type(name)=="string" and string.sub(name,1,7)=="Island " then
                        num=tonumber(string.sub(name,8))
                    end
                    if num and num>highestIsland then
                        highestIsland=num
                        highestIslandModel=child
                    end
                end

                if not highestIslandModel then
                    if S.raidLastIslandKey~=nil or S.raidTweenActive then
                        S.raidMoveGeneration=S.raidMoveGeneration+1
                    end
                    S.raidTweenActive=false
                    S.raidLastIslandNum=0
                    S.raidLastIslandKey=nil
                else
                    local islandKey=trackedInstanceKey(highestIslandModel)
                    if islandKey~=S.raidLastIslandKey then
                        S.raidLastIslandNum=highestIsland
                        S.raidLastIslandKey=islandKey
                        S.raidMoveGeneration=S.raidMoveGeneration+1
                        local moveGeneration=S.raidMoveGeneration
                        S.raidTweenActive=true
                        notify("Raid Island "..highestIsland.." - Going there!","laced.club",2)
                        task.spawn(function()
                            -- If this thread dies, raidTweenActive must still be cleared or
                            -- the raid farm loop would wait on it forever.
                            local okMove,moveError=pcall(function()
                            local cpos=nil
                            for _=1,10 do
                                local okParent,islandParent=pcall(function() return highestIslandModel.Parent end)
                                if not okParent or not islandParent then break end
                                local candidates={}
                                local okSelf,isSelfPart=pcall(function() return isA(highestIslandModel,"BasePart") end)
                                if okSelf and isSelfPart then table.insert(candidates,highestIslandModel) end
                                local okPrimary,primaryPart=pcall(function() return highestIslandModel.PrimaryPart end)
                                if okPrimary and primaryPart then table.insert(candidates,primaryPart) end
                                local okParts,parts=pcall(function() return highestIslandModel:GetDescendants() end)
                                if okParts and parts then
                                    for _,part in pairs(parts) do
                                        if isA(part,"BasePart") then table.insert(candidates,part) end
                                    end
                                end
                                for _,part in pairs(candidates) do
                                    local okPos,pos=pcall(function() return part.Position end)
                                    if okPos and pos and pos.X then cpos=pos; break end
                                end
                                if cpos then break end
                                task.wait(0.3)
                            end

                            local myHrp=nil
                            if cpos then
                                for _=1,30 do
                                    local character=LocalPlayer.Character
                                    myHrp=character and character:FindFirstChild("HumanoidRootPart")
                                    if myHrp then break end
                                    task.wait(0.2)
                                end
                            end

                            if cpos and myHrp and S.autoRaid and S.raidMoveGeneration==moveGeneration then
                                local target=Vector3.new(cpos.X,cpos.Y+100,cpos.Z)
                                local speed=math.max(tonumber(S.RAID_TWEEN_SPEED) or 320,1)
                                local arrived=tweenTo(myHrp,target,speed,function()
                                    return S.autoRaid and S.raidMoveGeneration==moveGeneration
                                end)
                                if arrived then notify("Arrived!","laced.club",2) end
                            end
                            end)
                            if not okMove then warnThrottled("raidMove","[laced.club] Raid travel failed: "..tostring(moveError),15) end

                            if S.raidMoveGeneration==moveGeneration then S.raidTweenActive=false end
                        end)
                    end
                end
            end
            end)
            if not okScan then warnThrottled("raidScan","[laced.club] Raid scan failed: "..tostring(scanError),15) end
        end
    end
end)

task.spawn(function()
    while alive() do
        if S.autoRaid and S.raidDetected and not S.raidTweenActive and not farmPriorityBlocked() then
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local useRemote=S.remoteMode
                local fought=farmAttack(
                    hrp,
                    function()
                        return S.autoRaid and S.raidDetected and not S.raidTweenActive and not farmPriorityBlocked() and S.remoteMode==useRemote
                    end,
                    nil,
                    true,
                    1000,
                    useRemote and remoteAttack or nil,
                    useRemote and 0.05 or 0.06
                )
                -- Speed restore: next target one frame after a fight.
                if fought then frameWait() else task.wait(0.1) end
            else
                task.wait(0.1)
            end
        else task.wait(0.1) end
    end
end)

task.spawn(function()
    while alive() do
        if S.voidPull and not writesPaused() and not rootTweenOwned() then
            local hrp=localRoot()
            if hrp then
                pcall(function() hrp.Position=Vector3.new(hrp.Position.X,100000,hrp.Position.Z) end)
                zeroVelocity(hrp)
            end
        end
        if S.voidPull then task.wait(writeInterval(1/30)) else task.wait(IDLE_POLL) end
    end
end)

task.spawn(function()
    while alive() do
        if S.skyPull and not writesPaused() and not rootTweenOwned() then
            local hrp=localRoot()
            if hrp then
                pcall(function() hrp.Position=Vector3.new(hrp.Position.X,1000,hrp.Position.Z) end)
                zeroVelocity(hrp)
            end
        end
        if S.skyPull then task.wait(writeInterval(1/30)) else task.wait(IDLE_POLL) end
    end
end)

function isPvpTargetDead(char)
    if not char then return true end
    local okDead,dead=pcall(function()
        if not char.Parent then return true end
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 then return true end
        return false
    end)
    return not okDead or dead==true
end

-- S.pvpFarmLoop has no UI control in this build (kept dormant, see CHANGES.md).
task.spawn(function()
    local pvpTarget=nil
    while alive() do
        if S.pvpFarmLoop then
            local okStep=pcall(function()
            local char=LocalPlayer.Character
            local myHrp=char and char:FindFirstChild("HumanoidRootPart")
            if myHrp then
                if isPvpTargetDead(pvpTarget) then
                    pvpTarget=nil
                    local nearest, bestDist=nil, math.huge
                    local myName=LocalPlayer.Name
                    local myTeamName=""
                    pcall(function() myTeamName=(LocalPlayer.Team and LocalPlayer.Team.Name) or "" end)
                    local charsFolder=Workspace:FindFirstChild("Characters")
                    if charsFolder then
                        for _, c in pairs(charsFolder:GetChildren()) do
                            if isA(c,"Model") and c.Name~=myName then
                                local root=c:FindFirstChild("HumanoidRootPart")
                                local hum=c:FindFirstChildOfClass("Humanoid")
                                if root and hum and hum.Health>0 then
                                    local skip=false
                                    if myTeamName=="Marines" then
                                        local tp=Players:FindFirstChild(c.Name)
                                        pcall(function()
                                            if tp and tp.Team and tp.Team.Name=="Marines" then skip=true end
                                        end)
                                    end
                                    if not skip then
                                        local dx=root.Position.X-myHrp.Position.X
                                        local dy=root.Position.Y-myHrp.Position.Y
                                        local dz=root.Position.Z-myHrp.Position.Z
                                        local d=math.sqrt(dx*dx+dy*dy+dz*dz)
                                        if d<bestDist then bestDist=d; nearest=c end
                                    end
                                end
                            end
                        end
                    end
                    if nearest then pvpTarget=nearest end
                end
                if pvpTarget and not isPvpTargetDead(pvpTarget) then
                    local target=pvpTarget
                    local enemyRootPart=target:FindFirstChild("HumanoidRootPart")
                    if enemyRootPart then
                        local function engaged() return alive() and S.pvpFarmLoop and not isPvpTargetDead(target) end
                        task.spawn(function()
                            while engaged() do
                                pcall(function()
                                    local eh=target:FindFirstChild("HumanoidRootPart")
                                    local hd=target:FindFirstChild("Head")
                                    if eh then eh.CanCollide=false end
                                    if hd then hd.CanCollide=false end
                                end)
                                frameWait()
                            end
                        end)
                        local startX=myHrp.Position.X; local startY=myHrp.Position.Y; local startZ=myHrp.Position.Z
                        local tx=enemyRootPart.Position.X+20; local ty=enemyRootPart.Position.Y; local tz=enemyRootPart.Position.Z
                        local dx=tx-startX; local dy=ty-startY; local dz=tz-startZ
                        local duration=math.max(math.sqrt(dx*dx+dy*dy+dz*dz)/320,0.01); local t0=clock()
                        while engaged() do
                            local alpha=math.min((clock()-t0)/duration,1)
                            if not moveRoot(myHrp,startX+dx*alpha,startY+dy*alpha,startZ+dz*alpha,nil) then break end
                            if alpha>=1 then break end; frameWait()
                        end
                        local lastClick=0
                        local attackStart=clock()
                        while clock()-attackStart<2 and engaged() do
                            local tr=target:FindFirstChild("HumanoidRootPart")
                            if tr then
                                setPartPosition(myHrp,Vector3.new(tr.Position.X+20, tr.Position.Y, tr.Position.Z))
                                zeroVelocity(myHrp)
                            end
                            local now=clock()
                            if now-lastClick>=0.05 then basicAttack(target); lastClick=now end
                            frameWait()
                        end
                        if S.pvpFarmLoop then
                            local savedX=myHrp.Position.X; local savedZ=myHrp.Position.Z
                            local upStart=clock()
                            while clock()-upStart<5 and engaged() do
                                setPartPosition(myHrp,Vector3.new(savedX,10000000,savedZ))
                                zeroVelocity(myHrp)
                                task.wait(0.1)
                            end
                            local dHrp=target:FindFirstChild("HumanoidRootPart")
                            local groundY=dHrp and dHrp.Position and dHrp.Position.Y or 0
                            setPartPosition(myHrp,Vector3.new(savedX,groundY,savedZ))
                            zeroVelocity(myHrp)
                            task.wait(0.2)
                            if engaged() then
                                local a2=clock()
                                while clock()-a2<0.5 and engaged() do
                                    local tr2=target:FindFirstChild("HumanoidRootPart")
                                    if tr2 then
                                        setPartPosition(myHrp,Vector3.new(tr2.Position.X+20,tr2.Position.Y,tr2.Position.Z))
                                        zeroVelocity(myHrp)
                                    end
                                    local now=clock()
                                    if now-lastClick>=0.05 then basicAttack(target); lastClick=now end
                                    frameWait()
                                end
                            end
                        end
                    end
                else task.wait(0.5) end
            else task.wait(0.5) end
            end)
            if not okStep then pvpTarget=nil; task.wait(0.5) end
            -- Some branches above (target without a root) returned without
            -- yielding: always yield once per pass.
            frameWait()
        else pvpTarget=nil; task.wait(0.5) end
    end
end)

do
    local aura = {
        enabled       = false,
        maxDist       = 100,
        minDist       = 1,
        sessionId     = "32501259",
        targetCount   = 0,
        firstName     = "None",
        regAtk        = nil,
        regHit        = nil,
    }

    local function aura_ensureRemotes()
        if aura.regAtk and aura.regHit then return true end
        local net = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
        if net then net = net:FindFirstChild("Net") end
        if not net then return false end
        aura.regAtk = net:FindFirstChild("RE/RegisterAttack")
        aura.regHit = net:FindFirstChild("RE/RegisterHit")
        return aura.regAtk ~= nil and aura.regHit ~= nil
    end

    local function aura_getTargetPart(enemy)
        if not enemy or not enemy.Parent then return nil end
        local p = enemy:FindFirstChild("LeftLowerLeg")
        if p and isA(p,"BasePart") then return p end
        p = enemy:FindFirstChild("Head")
        if p and isA(p,"BasePart") then return p end
        p = enemy:FindFirstChild("HumanoidRootPart")
        if p and isA(p,"BasePart") then return p end
        for _, c in ipairs(enemy:GetChildren()) do
            if isA(c,"BasePart") then return c end
        end
        return nil
    end

    local function aura_getEnemies()
        local char = LocalPlayer.Character
        if not char then return {} end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return {} end
        local myPos = hrp.Position
        local folder = Workspace:FindFirstChild("Enemies")
        if not folder then return {} end
        local results = {}
        for _, enemy in ipairs(folder:GetChildren()) do
            if enemy and enemy.Parent then
                local hum = enemy:FindFirstChild("Humanoid")
                if hum and hum.Health and hum.Health > 0 then
                    local part = aura_getTargetPart(enemy)
                    if part and part.Parent then
                        local ok, pos = pcall(function() return part.Position end)
                        if ok and pos then
                            local dx=pos.X-myPos.X
                            local dy=pos.Y-myPos.Y
                            local dz=pos.Z-myPos.Z
                            local d=math.sqrt(dx*dx+dy*dy+dz*dz)
                            if d <= aura.maxDist and d >= aura.minDist then
                                table.insert(results, {enemy=enemy, part=part, dist=d})
                            end
                        end
                    end
                end
            end
        end
        return results
    end

    local function aura_attack(list)
        if #list == 0 then return end
        local hitTable = {}
        local primary = nil
        for _, entry in ipairs(list) do
            if entry.enemy and entry.enemy.Parent and entry.part and entry.part.Parent then
                table.insert(hitTable, {entry.enemy, entry.part})
                if not primary then primary = entry.part end
            end
        end
        if #hitTable == 0 then return end
        local extras = {}
        for i = 2, #hitTable do table.insert(extras, hitTable[i]) end
        local prof = BasicM1.profiles[BasicM1.profile] or BasicM1.profiles[1]
        BasicM1.fire("NPC Aura ", primary, prof.clientShape and extras or hitTable)
    end

    mainTab:AddSection("NPC Aura", { Column = 1 })
    mainTab:AddToggle("npc_aura", {
        Text="NPC Aura", Description="Fires RegisterHit on all NPCs within range. MATCHA PRO ONLY!",
        Default=false, Keybind=true, Column=1,
        Callback=function(v)
            aura.enabled = v
            aura_ensureRemotes()
            notify(v and "NPC Aura ON!" or "NPC Aura OFF!", "laced.club", 2)
        end
    })
    mainTab:AddSlider("npc_aura_range", {
        Text="Aura Range", Description="Max distance to hit NPCs (studs)",
        Min=10, Max=300, Default=100, Integer=true, Column=1,
        Callback=function(v) aura.maxDist = v end
    })

    task.spawn(function()
        while alive() do
            if aura.enabled then
                local okStep = pcall(function()
                    if aura_ensureRemotes() then
                        local enemies = aura_getEnemies()
                        aura.targetCount = #enemies
                        if aura.targetCount > 0 then
                            table.sort(enemies, function(a,b) return a.dist < b.dist end)
                            aura.firstName = enemies[1].enemy.Name or "Unknown"
                        else
                            aura.firstName = "None"
                        end
                        aura_attack(enemies)
                    end
                end)
                -- Back off while the remotes keep failing (non-Pro build).
                if not okStep or remoteFailing("NPC Aura RegisterHit") then task.wait(1) else task.wait(0.05) end
            else
                task.wait(0.1)
            end
        end
    end)
end

do
    local sessionId = "325bb15e"
    local minDist   = 1
    local regAtk, regHit = nil, nil

    local function pvp_ensureRemotes()
        if regAtk and regHit then return true end
        local net = game:GetService("ReplicatedStorage"):FindFirstChild("Modules")
        if net then net = net:FindFirstChild("Net") end
        if not net then return false end
        regAtk = net:FindFirstChild("RE/RegisterAttack")
        regHit = net:FindFirstChild("RE/RegisterHit")
        return regAtk ~= nil and regHit ~= nil
    end

    local function pvp_getTarget()
        local char = LocalPlayer.Character
        if not char then return nil, nil end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil, nil end
        local myPos = hrp.Position
        local closest, closestDist = nil, _pvpAuraMaxDist + 1
        for _, player in pairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local c = player.Character
            if c then
                local root = c:FindFirstChild("HumanoidRootPart")
                if root then
                    local rootPos=root.Position
                    local dx=rootPos.X-myPos.X
                    local dy=rootPos.Y-myPos.Y
                    local dz=rootPos.Z-myPos.Z
                    local d=math.sqrt(dx*dx+dy*dy+dz*dz)
                    if d < closestDist and d >= minDist then
                        closestDist = d; closest = player
                    end
                end
            end
        end
        if not closest then return nil, nil end
        local tc = closest.Character
        if not tc then return nil, nil end
        local partName = _pvpAuraAltPart and "ModelHitbox" or "Head"
        local part = tc:FindFirstChild(partName) or tc:FindFirstChild("Head")
        if not part or part:IsDescendantOf(LocalPlayer.Character) then return nil, nil end
        return closest, part
    end

    local function pvp_attack(part)
        if not part then return end
        BasicM1.fire("PvP Aura ", part, {})
    end

    task.spawn(function()
        while alive() do
            if _pvpAuraEnabled then
                local okStep = pcall(function()
                    if pvp_ensureRemotes() then
                        local _, part = pvp_getTarget()
                        pvp_attack(part)
                    end
                end)
                if not okStep or remoteFailing("PvP Aura RegisterHit") then task.wait(1) else task.wait(0.05) end
            else
                task.wait(0.1)
            end
        end
    end)
end

do
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")

    local FishConfig = {
        CastTarget     = 0.96,
        WaitBeforeReel = 0.2,
        DeadZone       = 0.35,
        BiteTimeout    = 20,
        ResetDelay     = 2,
    }

    local FishState = {
        Running        = false,
        IsHolding      = false,
        CastComplete   = false,
        FishDetected   = false,
        WaitingForUI   = false,
        ReelingStarted = false,
        WaitStart      = 0,
        Clicks         = 0,
        FishCaught     = 0,
        LastCastTime   = 0,
        BiteClickTime  = 0,
        Generation     = 0,
    }

    local function fish_hold()
        if not FishState.IsHolding and robloxFocused() and not menuUnderMouse() then FishState.IsHolding=true; pcall(mouse1press); FishState.Clicks=FishState.Clicks+1 end
    end
    local function fish_release()
        if FishState.IsHolding then FishState.IsHolding=false; pcall(mouse1release) end
    end
    local function fish_click()
        if farmClick() then FishState.Clicks=FishState.Clicks+1 end
    end

    local function fish_fullReset()
        fish_release()
        FishState.CastComplete=false
        FishState.FishDetected=false
        FishState.WaitingForUI=false
        FishState.ReelingStarted=false
        FishState.WaitStart=0
        FishState.LastCastTime=0
        FishState.BiteClickTime=0
        task.wait(FishConfig.ResetDelay)
    end

    local function fish_getCastFrame()
        local char=LocalPlayer.Character; if not char then return nil end
        local part=char:FindFirstChild("Fishing_Cast Meter"); if not part then return nil end
        local meter=part:FindFirstChild("CastMeter"); if not meter then return nil end
        local bar=meter:FindFirstChild("Bar"); if not bar then return nil end
        return bar:FindFirstChild("Frame")
    end

    local function fish_getCastFill()
        local frame=fish_getCastFrame(); if not frame then return 0 end
        local ok1,size=pcall(function() return frame.AbsoluteSize.Y end)
        local ok2,max=pcall(function() return frame.Parent.AbsoluteSize.Y end)
        if ok1 and ok2 and size and max and max>0 then return size/max end
        return 0
    end

    local function fish_getReelUI()
        if not PlayerGui or not PlayerGui.Parent then PlayerGui=LocalPlayer:FindFirstChild("PlayerGui") end
        if not PlayerGui then return nil end
        local ui=PlayerGui:FindFirstChild("Fishing_Reeling"); if not ui then return nil end
        local mini=ui:FindFirstChild("Minigame") or ui:FindFirstChild("MiniGame"); if not mini then return nil end
        local con=mini:FindFirstChild("Container"); if not con then return nil end
        local treasure=con:FindFirstChild("Treasure")
        local treasureIcon=treasure and (treasure:FindFirstChild("UnopenedIcon") or treasure:FindFirstChild("OpenedIcon")) or nil
        return {
            Fish=con:FindFirstChild("Fish"),
            Treasure=treasureIcon,
            Zone=con:FindFirstChild("ReelZone") or con:FindFirstChild("Zone")
        }
    end

    local function fish_isReelOpen()
        if not PlayerGui or not PlayerGui.Parent then PlayerGui=LocalPlayer:FindFirstChild("PlayerGui") end
        return PlayerGui and PlayerGui:FindFirstChild("Fishing_Reeling") ~= nil
    end

    local function fish_getCenter(obj)
        if not obj then return 0 end
        local ok1,x=pcall(function() return obj.AbsolutePosition.X end)
        local ok2,w=pcall(function() return obj.AbsoluteSize.X end)
        if ok1 and ok2 and x and w then return x+w/2 end
        return 0
    end

    local function fish_getFishSound()
        local char=LocalPlayer.Character; if not char then return nil end
        local rod=char:FindFirstChild("Fishing Rod"); if not rod then return nil end
        local part=rod:FindFirstChild("Fishing Rod"); if not part then return nil end
        local metal=part:FindFirstChild("Metal"); if not metal then return nil end
        return metal:FindFirstChild("FishOnLine")
    end

    local function fish_isBiting()
        if fish_getFishSound() then return true end
        local char=LocalPlayer.Character
        if not char then return false end
        local okDesc,descendants=pcall(function() return char:GetDescendants() end)
        if not okDesc or not descendants then return false end
        for _,object in pairs(descendants) do
            local okName,name=pcall(function() return string.lower(object.Name or "") end)
            if okName and (string.find(name,"fishonline",1,true) or string.find(name,"fish on line",1,true)) then
                return true
            end
        end
        return false
    end

    local function fish_isZoneLeft(ui)
        if not ui then return false end
        local fish=fish_getCenter(ui.Treasure or ui.Fish); local zone=fish_getCenter(ui.Zone)
        if fish==0 or zone==0 then return false end
        return zone < fish - FishConfig.DeadZone
    end

    local function fish_mainLoop(generation)
        FishState.WaitStart=0
        local ending=false; local endTimer=0; local wasOpen=false
        while alive() and FishState.Running and FishState.Generation==generation do
            task.wait(0.05)
            if farmPriorityBlocked() then
                fish_release()
                FishState.CastComplete=false
                FishState.FishDetected=false
                FishState.WaitingForUI=false
                FishState.ReelingStarted=false
                FishState.WaitStart=0
                continue
            end
            if not FishState.CastComplete then
                local frame=fish_getCastFrame()
                if frame then
                    fish_hold()
                    if fish_getCastFill()>=FishConfig.CastTarget then
                        fish_release()
                        FishState.CastComplete=true; FishState.FishDetected=false
                        FishState.WaitingForUI=false; FishState.ReelingStarted=false
                        FishState.WaitStart=0; FishState.LastCastTime=clock()
                        ending=false; wasOpen=false
                    end
                else
                    if not FishState.IsHolding then fish_click(); task.wait(0.1) end
                end
                continue
            end
            if FishState.CastComplete and not FishState.FishDetected then
                if clock()-FishState.LastCastTime>FishConfig.BiteTimeout then
                    fish_fullReset()
                    continue
                end
                if fish_isBiting() then
                    FishState.FishDetected=true
                    FishState.BiteClickTime=clock()
                    fish_click(); task.wait(0.14); fish_click(); task.wait(0.14); fish_click()
                end
                continue
            end
            if FishState.FishDetected then
                local open=fish_isReelOpen()
                if open then
                    wasOpen=true
                    local ui=fish_getReelUI()
                    if ui then
                        if not FishState.WaitingForUI then
                            FishState.WaitingForUI=true; FishState.ReelingStarted=false
                            FishState.WaitStart=clock(); ending=false
                        end
                        if not FishState.ReelingStarted then
                            if clock()-FishState.WaitStart>=FishConfig.WaitBeforeReel then
                                FishState.ReelingStarted=true; fish_click(); task.wait(0.2); fish_click()
                            end
                            continue
                        end
                        if FishState.ReelingStarted then
                            if fish_isZoneLeft(ui) then fish_hold() else fish_release() end
                        end
                    end
                else
                    if not wasOpen and clock()-FishState.BiteClickTime>3 then
                        fish_fullReset()
                        continue
                    end
                    if wasOpen and not ending then
                        ending=true; endTimer=clock()
                        FishState.FishCaught=FishState.FishCaught+1
                        fish_release()
                        notify("Fish caught! ("..FishState.FishCaught..")", "laced.club", 2)
                    end
                    if ending then
                        local el=clock()-endTimer
                        if el>=0 and el<0.05 then fish_click()
                        elseif el>=0.2 and el<0.25 then fish_click()
                        elseif el>=0.4 and el<0.45 then fish_click()
                        elseif el>=0.5 then
                            FishState.CastComplete=false; FishState.FishDetected=false
                            FishState.WaitingForUI=false; FishState.ReelingStarted=false
                            FishState.WaitStart=0; ending=false; wasOpen=false
                        end
                    end
                    FishState.WaitStart=clock()
                end
            end
        end
    end

    mainTab:AddToggle("auto_fish", {
        Text="Auto Fish", Description="Automatically casts, detects fish, and reels.",
        Default=false, Keybind=true, Column=2,
        Callback=function(v)
            S.autoFish=v
            if v then
                S.autoRepair=false
                pcall(function() Window:Set("auto_ship_repair",false) end)
                FishState.Running=true; FishState.CastComplete=false; FishState.FishDetected=false
                FishState.WaitingForUI=false; FishState.ReelingStarted=false
                FishState.WaitStart=0; FishState.Clicks=0; FishState.FishCaught=0
                FishState.LastCastTime=0; FishState.BiteClickTime=0
                -- A new generation retires any loop left over from a quick off/on,
                -- so two loops never fight over the mouse button.
                FishState.Generation=(FishState.Generation or 0)+1
                local generation=FishState.Generation
                task.spawn(function()
                    while alive() and FishState.Running and FishState.Generation==generation do
                        local okLoop,loopError=pcall(fish_mainLoop,generation)
                        fish_release()
                        if not okLoop then
                            warnThrottled("autoFish","[laced.club] Auto Fish error: "..tostring(loopError),15)
                            task.wait(1)
                        end
                    end
                end)
                notify("Auto Fish started!", "laced.club", 2)
            else
                FishState.Running=false
                FishState.Generation=(FishState.Generation or 0)+1
                fish_release()
                notify("Auto Fish stopped. Fish: "..FishState.FishCaught, "laced.club", 2)
            end
        end
    })
    -- Unload (also a re-run): never leave the left button held.
    onShutdown(function()
        FishState.Running=false
        FishState.Generation=(FishState.Generation or 0)+1
        fish_release()
    end)
end

do
    local RepairState={holding=false}

    local function repairRelease()
        if RepairState.holding then
            RepairState.holding=false
            pcall(mouse1release)
        end
    end

    local function repairHold()
        if not RepairState.holding and robloxFocused() and not menuUnderMouse() then
            RepairState.holding=true
            pcall(mouse1press)
        end
    end

    local function getRepairBarInfo()
        local playerGui=LocalPlayer:FindFirstChild("PlayerGui")
        local main=playerGui and playerGui:FindFirstChild("Main") or nil
        local bottom=main and main:FindFirstChild("BottomHUDList") or nil
        local mini=bottom and bottom:FindFirstChild("RepairMiniGame") or nil
        local progress=mini and mini:FindFirstChild("ProgressBar") or nil
        local fill=progress and progress:FindFirstChild("Fill") or nil
        local goal=progress and progress:FindFirstChild("Goal") or nil
        if not fill or not goal then return nil end

        local ok,fillPosition,fillSize,goalPosition,goalSize=pcall(function()
            return fill.AbsolutePosition,fill.AbsoluteSize,goal.AbsolutePosition,goal.AbsoluteSize
        end)
        if not ok or not fillPosition or not fillSize or not goalPosition or not goalSize then return nil end
        return {
            fillRight=fillPosition.X+fillSize.X,
            goalLeft=goalPosition.X,
            goalRight=goalPosition.X+goalSize.X
        }
    end

    task.spawn(function()
        while alive() do
            if S.autoRepair then
                local info=getRepairBarInfo()
                if info then
                    if info.fillRight>=info.goalLeft-8 and info.fillRight<=info.goalRight+14 then
                        repairRelease()
                        task.wait(0.35)
                    else
                        repairHold()
                    end
                else
                    repairRelease()
                end
                task.wait(0.02)
            else
                repairRelease()
                task.wait(0.2)
            end
        end
        repairRelease()
    end)
    onShutdown(function() repairRelease() end)
end

-- Load marker: this chunk ran to the end.
if LACED_LOAD and type(LACED_LOAD.done) == "table" then LACED_LOAD.done["70_misc"] = true end
