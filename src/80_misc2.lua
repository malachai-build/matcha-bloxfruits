-- @chunk 80_misc2  (lines 7476-8507 of the single-file build)
local LACED_LOAD = type(_G.__lacedLoad) == "table" and _G.__lacedLoad or nil -- load marker (loader.lua)
if LACED_LOAD and type(LACED_LOAD.started) == "table" then LACED_LOAD.started["80_misc2"] = true end
-- Per-execution bindings: captured at chunk load so a re-run of the script
-- cannot make this copy's loops read the new copy's state (alive is a
-- closure over this run's state since the Oct 15 stability pass).
local alive = alive
local SCRIPT_STATE = SCRIPT_STATE
local S = S
local AFL = AFL
MASTERY_WAYPOINTS={
    {pos=Vector3.new(109.6,47.5,-12520.8)},
    {pos=Vector3.new(15.1,47.5,-12567.3)},
    {pos=Vector3.new(61.2,47.5,-12670.0)},
    {pos=Vector3.new(-150.7,47.5,-12666.5)},
    {pos=Vector3.new(86.2,47.5,-12849.6)},
    {pos=Vector3.new(233.5,47.5,-12952.1)},
    {pos=Vector3.new(129.1,47.5,-13049.1)},
    {pos=Vector3.new(-31.2,47.5,-12939.9)},
    {pos=Vector3.new(33.5,47.5,-12790.5),waitTime=5},
    {pos=Vector3.new(59.7,47.5,-12874.7),waitTime=3.2},
    {pos=Vector3.new(-108.3,47.5,-12285.8),look=Vector3.new(-0.980,0,-0.197)},
    {pos=Vector3.new(5.9,47.5,-12249.4)},
    {pos=Vector3.new(114.2,47.5,-12225.0)},
    {pos=Vector3.new(-7.4,47.5,-12257.7),waitTime=5},
    {pos=Vector3.new(594.8,47.5,-12426.1),look=Vector3.new(0.591,0,-0.807)},
    {pos=Vector3.new(617.6,47.5,-12557.3)},
    {pos=Vector3.new(707.3,47.5,-12570.6)},
    {pos=Vector3.new(714.0,47.5,-12708.4)},
    {pos=Vector3.new(820.5,47.5,-12679.7)},
    {pos=Vector3.new(803.9,47.5,-12763.1)},
    {pos=Vector3.new(698.0,47.5,-12605.4),waitTime=4},
    {pos=Vector3.new(676.5,47.5,-12570.8),waitTime=10,forceWait=true},
}
masteryWaypoint=1
masteryLastRemoteFired=0
masteryLookVector=Vector3.new(0.040,0,-0.999)

-- Rotation-only CFrame facing lookVector. CFrame.lookAt is not documented in
-- Matcha; fall back to the documented 12-number constructor.
function facingCFrame(lookVector)
    local facing=nil
    local okLookAt=pcall(function() facing=CFrame.lookAt(Vector3.new(0,0,0),lookVector) end)
    if okLookAt and facing then return facing end
    pcall(function()
        local forward=lookVector.Unit
        local right=forward:Cross(Vector3.new(0,1,0))
        if right.Magnitude<0.001 then right=Vector3.new(1,0,0) else right=right.Unit end
        local up=right:Cross(forward)
        facing=CFrame.new(0,0,0,
            right.X,up.X,-forward.X,
            right.Y,up.Y,-forward.Y,
            right.Z,up.Z,-forward.Z)
    end)
    return facing
end

function masteryTweenTo(hrp,targetPos,lookVector,checkFn)
    if not hrp or not targetPos then return end
    if lookVector then masteryLookVector=lookVector end
    local okStart,startPos=pcall(function() return hrp.Position end)
    if not okStart or not startPos then return end
    local dx=targetPos.X-startPos.X
    local dy=targetPos.Y-startPos.Y
    local dz=targetPos.Z-startPos.Z
    local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
    local speed=math.max(tonumber(S.MASTERY_TWEEN_SPEED) or 320,1)
    local duration=math.max(distance/speed,0.01)
    local startTime=clock()
    local facingCF=facingCFrame(masteryLookVector)
    -- Oct 15 2026: owns the root while in flight (claimRoot), zero velocity
    -- on every written frame (placeRoot), re-based after a quiet-window pause
    -- (no jump on resume), constant facing for the whole flight.
    local token=claimRoot()
    while alive() do
        if not holdsRoot(token) then return end -- another tween took the root
        refreshRoot(token)
        markTravel()
        if checkFn then
            local okCheck,keepGoing=pcall(checkFn)
            if not okCheck or not keepGoing then releaseRoot(token); return end
        end
        if writesPaused() then
            task.wait(0.05)
            local okNow,now=pcall(function() return hrp.Position end)
            if okNow and now and now.X then startPos=now end
            dx=targetPos.X-startPos.X; dy=targetPos.Y-startPos.Y; dz=targetPos.Z-startPos.Z
            distance=math.sqrt(dx*dx+dy*dy+dz*dz)
            duration=math.max(distance/speed,0.01)
            startTime=clock()
        else
            local alpha=distance<0.1 and 1 or math.min((clock()-startTime)/duration,1)
            local okMove=placeRoot(hrp,startPos.X+dx*alpha,startPos.Y+dy*alpha,startPos.Z+dz*alpha,facingCF)
            if (not okMove and not writesPaused()) or alpha>=1 then releaseRoot(token); return end
            frameWait() -- was task.wait(0.01), ~100 writes/s; alpha is time-based
        end
    end
    releaseRoot(token)
end

function masteryGetTargets(hrp)
    local targets={}
    if not hrp then return targets end
    local okMyPos,myPos=pcall(function() return hrp.Position end)
    local enemies=Workspace:FindFirstChild("Enemies")
    if not okMyPos or not myPos or not enemies then return targets end
    local okChildren,children=pcall(function() return enemies:GetChildren() end)
    if not okChildren or not children then return targets end
    for _,enemy in pairs(children) do
        pcall(function()
            local hum=enemy and enemy:FindFirstChildOfClass("Humanoid") or nil
            if hum and hum.Health and hum.Health>0 then
                local part=enemy:FindFirstChild("LeftLowerLeg") or enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChildWhichIsA("BasePart")
                local okPos,pos=pcall(function() return part and part.Position end)
                if okPos and pos then
                    local dx=pos.X-myPos.X
                    local dy=pos.Y-myPos.Y
                    local dz=pos.Z-myPos.Z
                    local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
                    if distance>=1 and distance<=120 then table.insert(targets,{enemy,part}) end
                end
            end
        end)
    end
    return targets
end

function masteryAttackTargets(targets)
    if not targets or #targets==0 or not ensureRemotes() then return end
    local hitTable={}
    local primary=nil
    for _,entry in pairs(targets) do
        local enemy=entry[1]
        local part=entry[2]
        local okEnemy,enemyParent=pcall(function() return enemy and enemy.Parent end)
        local okPart,partParent=pcall(function() return part and part.Parent end)
        if okEnemy and enemyParent and okPart and partParent then
            table.insert(hitTable,{enemy,part})
            if not primary then primary=part end
        end
    end
    if #hitTable==0 or not primary then return end
    local extras={}
    for i=2,#hitTable do table.insert(extras,hitTable[i]) end
    local prof=BasicM1.profiles[BasicM1.profile] or BasicM1.profiles[1]
    local okHit=BasicM1.fire("Mastery ",primary,prof.clientShape and extras or hitTable)
    if okHit then masteryLastRemoteFired=clock() end
end

task.spawn(function()
    while alive() do
        if S.autoMastery and not farmPriorityBlocked() then
            local okStep=pcall(function()
            local char=LocalPlayer and LocalPlayer.Character or nil
            local hrp=char and char:FindFirstChild("HumanoidRootPart") or nil
            local waypoint=MASTERY_WAYPOINTS[masteryWaypoint]
            if hrp and waypoint then
                masteryTweenTo(hrp,waypoint.pos,waypoint.look,function()
                    return S.autoMastery and not farmPriorityBlocked()
                end)
                if S.autoMastery and waypoint.waitTime then
                    local deadline=clock()+waypoint.waitTime
                    masteryLastRemoteFired=clock()
                    while alive() and S.autoMastery and not farmPriorityBlocked() and clock()<deadline do
                        if not waypoint.forceWait and clock()-masteryLastRemoteFired>=1.5 then break end
                        task.wait(0.1)
                    end
                end
                if S.autoMastery and not farmPriorityBlocked() then
                    masteryWaypoint=(masteryWaypoint%#MASTERY_WAYPOINTS)+1
                end
            else
                task.wait(0.1)
            end
            end)
            -- masteryTweenTo returns at once when the move is rejected or the
            -- waypoint is already reached; without this yield the loop could
            -- spin through waypoints forever and freeze the VM.
            if okStep then frameWait() else task.wait(0.5) end
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while alive() do
        if S.autoMastery and not farmPriorityBlocked() then
            local char=LocalPlayer and LocalPlayer.Character or nil
            local hrp=char and char:FindFirstChild("HumanoidRootPart") or nil
            pcall(function() masteryAttackTargets(masteryGetTargets(hrp)) end)
            if remoteFailing("Mastery RegisterHit") then task.wait(1) else task.wait(0.05) end
        else
            task.wait(0.1)
        end
    end
end)

function runVelocityBoost(settings,enabledFn,horizontalOnly,lockedDirection)
    if not settings then return end
    task.wait(settings.delay)
    if not enabledFn() then return end

    local char=LocalPlayer and LocalPlayer.Character or nil
    local hrp=char and char:FindFirstChild("HumanoidRootPart") or nil
    if not hrp then return end

    local direction=lockedDirection
    if not direction then
        pcall(function()
            local velocity=hrp.AssemblyLinearVelocity
            if not velocity then return end
            local dx,dy,dz=velocity.X,velocity.Y,velocity.Z
            if horizontalOnly then dy=0 end
            local magnitude=math.sqrt(dx*dx+dy*dy+dz*dz)
            if magnitude>0.1 then
                direction=Vector3.new(dx/magnitude,dy/magnitude,dz/magnitude)
            end
        end)
    end
    if not direction then return end

    local endTime=clock()+settings.duration
    while clock()<endTime and enabledFn() do
        local currentChar=LocalPlayer and LocalPlayer.Character or nil
        local currentHrp=currentChar and currentChar:FindFirstChild("HumanoidRootPart") or nil
        if not currentHrp then return end
        if not writesPaused() then pcall(function()
            currentHrp.AssemblyLinearVelocity=Vector3.new(
                direction.X*settings.speed,
                horizontalOnly and 0 or direction.Y*settings.speed,
                direction.Z*settings.speed
            )
        end) end
        frameWait()
    end
end

task.spawn(function()
    local wasZFire=false
    local boosting=false
    while alive() do
        local char=LocalPlayer and LocalPlayer.Character or nil
        local hrp=char and char:FindFirstChild("HumanoidRootPart") or nil
        local zFire=hrp and hrp:FindFirstChild("SanguineArtZFire")~=nil or false
        if S.sanguineZBoost and zFire and not wasZFire and not boosting then
            boosting=true
            task.spawn(function()
                pcall(runVelocityBoost,S.glitchSettings.sanguine,function() return S.sanguineZBoost end)
                boosting=false
            end)
        end
        wasZFire=zFire
        idleWait(S.sanguineZBoost) -- 60 Hz key polling only while the feature is on
    end
end)

task.spawn(function()
    local holdingZ=false
    local boosting=false
    while alive() do
        local pressed=keyDown(0x5A)
        if S.dragonTalonZBoost and pressed and not holdingZ then
            holdingZ=true
            if not boosting then
                boosting=true
                task.spawn(function()
                    local char=LocalPlayer and LocalPlayer.Character or nil
                    if char and char:FindFirstChild("Dragon Talon") then
                        pcall(runVelocityBoost,S.glitchSettings.dragonTalon,function() return S.dragonTalonZBoost end)
                    end
                    boosting=false
                end)
            end
        elseif not pressed then
            holdingZ=false
        end
        idleWait(S.dragonTalonZBoost) -- 60 Hz key polling only while the feature is on
    end
end)

task.spawn(function()
    local holdingZ=false
    local boosting=false
    while alive() do
        local pressed=keyDown(0x5A)
        if S.yamaZBoost and pressed and not holdingZ then
            holdingZ=true
            if not boosting then
                boosting=true
                task.spawn(function()
                    local char=LocalPlayer and LocalPlayer.Character or nil
                    if char and char:FindFirstChild("Yama") then
                        pcall(runVelocityBoost,S.glitchSettings.yama,function() return S.yamaZBoost end)
                    end
                    boosting=false
                end)
            end
        elseif not pressed then
            holdingZ=false
        end
        idleWait(S.yamaZBoost) -- 60 Hz key polling only while the feature is on
    end
end)

task.spawn(function()
    local holdingX=false
    local boosting=false
    while alive() do
        local pressed=keyDown(0x58)
        if S.tushitaXBoost and pressed and not holdingX then
            holdingX=true
            if not boosting then
                boosting=true
                task.spawn(function()
                    local char=LocalPlayer and LocalPlayer.Character or nil
                    if char and char:FindFirstChild("Tushita") then
                        pcall(runVelocityBoost,S.glitchSettings.tushita,function() return S.tushitaXBoost end)
                    end
                    boosting=false
                end)
            end
        elseif not pressed then
            holdingX=false
        end
        idleWait(S.tushitaXBoost) -- 60 Hz key polling only while the feature is on
    end
end)

task.spawn(function()
    local holdingX=false
    local boosting=false
    while alive() do
        local pressed=keyDown(0x58)
        if S.foxLampXBoost and pressed and not holdingX then
            holdingX=true
            if not boosting then
                boosting=true
                task.spawn(function()
                    local char=LocalPlayer and LocalPlayer.Character or nil
                    if char and char:FindFirstChild("Fox Lamp") then
                        pcall(runVelocityBoost,S.glitchSettings.foxLamp,function() return S.foxLampXBoost end)
                    end
                    boosting=false
                end)
            end
        elseif not pressed then
            holdingX=false
        end
        idleWait(S.foxLampXBoost) -- 60 Hz key polling only while the feature is on
    end
end)

task.spawn(function()
    local wasQPressed=false
    local wasM1Pressed=false
    local lastQPress=nil
    local lastM1Press=nil
    local boosting=false
    while alive() do
        local qPressed=keyDown(0x51)
        local m1Pressed=ismouse1pressed()
        local now=clock()

        if S.soulGuitarM1Boost then
            if qPressed and not wasQPressed then lastQPress=now end
            if m1Pressed and not wasM1Pressed then lastM1Press=now end

            if not boosting and lastQPress and lastM1Press and math.abs(lastQPress-lastM1Press)<=0.5 then
                lastQPress=nil
                lastM1Press=nil
                boosting=true
                task.spawn(function()
                    local char=LocalPlayer and LocalPlayer.Character or nil
                    local hasGuitar=char and (
                        char:FindFirstChild("Skull Guitar") or
                        char:FindFirstChild("Soul Guitar")
                    )
                    if hasGuitar then
                        pcall(runVelocityBoost,S.glitchSettings.soulGuitar,function() return S.soulGuitarM1Boost end,true)
                    end
                    boosting=false
                end)
            end
        else
            lastQPress=nil
            lastM1Press=nil
        end

        wasQPressed=qPressed
        wasM1Pressed=m1Pressed
        idleWait(S.soulGuitarM1Boost) -- 60 Hz key polling only while the feature is on
    end
end)

task.spawn(function()
    local wasM1Pressed=false
    local boosting=false
    while alive() do
        local m1Pressed=ismouse1pressed()
        if S.diamondM1Boost and not m1Pressed and wasM1Pressed and not boosting then
            boosting=true
            task.spawn(function()
                local char=LocalPlayer and LocalPlayer.Character or nil
                if char and char:FindFirstChild("Diamond-Diamond") then
                    pcall(runVelocityBoost,S.glitchSettings.diamond,function()
                        return S.diamondM1Boost
                    end)
                end
                boosting=false
            end)
        end
        wasM1Pressed=m1Pressed
        idleWait(S.diamondM1Boost) -- 60 Hz key polling only while the feature is on
    end
end)

task.spawn(function()
    local holdingF=false
    local boosting=false
    while alive() do
        local pressed=keyDown(0x46)
        if S.flameFBoost and pressed and not holdingF then
            holdingF=true
            if not boosting then
                boosting=true
                task.spawn(function()
                    local char=LocalPlayer and LocalPlayer.Character or nil
                    if char and char:FindFirstChild("Flame-Flame") then
                        pcall(runVelocityBoost,S.glitchSettings.flame,function() return S.flameFBoost end)
                    end
                    boosting=false
                end)
            end
        elseif not pressed then
            holdingF=false
        end
        idleWait(S.flameFBoost) -- 60 Hz key polling only while the feature is on
    end
end)

task.spawn(function()
    local holdingR=false
    while alive() do
        local rPressed=keyDown(0x52)
        if S.rToX and rPressed and not holdingR then
            holdingR=true
            local char=LocalPlayer and LocalPlayer.Character or nil
            local portal=char and char:FindFirstChild("Portal-Portal") or nil
            if portal then
                task.spawn(function()
                    pcall(function()
                        setrobloxinput(true)
                        keyrelease(0x58)
                        task.wait(0.02)
                        keypress(0x58)
                        task.wait(0.08)
                        keyrelease(0x58)
                    end)
                end)
            end
        elseif not rPressed then
            holdingR=false
        end
        idleWait(S.rToX) -- 60 Hz key polling only while the feature is on
    end
end)

task.spawn(function()
    local holdingR=false
    while alive() do
        local rPressed=keyDown(0x52)
        if S.rToXThenZ and rPressed and not holdingR then
            holdingR=true
            local char=LocalPlayer and LocalPlayer.Character or nil
            local portal=char and char:FindFirstChild("Portal-Portal") or nil
            if portal then
                task.spawn(function()
                    pcall(function()
                        setrobloxinput(true)
                        keyrelease(0x58)
                        task.wait(0.02)
                        keypress(0x58)
                        task.wait(0.08)
                        keyrelease(0x58)
                        task.wait(0.025)
                        keyrelease(0x5A)
                        task.wait(0.02)
                        keypress(0x5A)
                        task.wait(0.08)
                        keyrelease(0x5A)
                    end)
                end)
            end
        elseif not rPressed then
            holdingR=false
        end
        idleWait(S.rToXThenZ) -- 60 Hz key polling only while the feature is on
    end
end)

task.spawn(function()
    local holdingR=false
    while alive() do
        local rPressed=false
        local okKey, keyState=pcall(function() return keyDown(0x52) end)
        if okKey and keyState==true then rPressed=true end

        if S.flameRToC and rPressed and not holdingR then
            holdingR=true

            local char=nil
            local okChar, charValue=pcall(function()
                return LocalPlayer and LocalPlayer.Character or nil
            end)
            if okChar then char=charValue end

            local flame=nil
            if char then
                local okFlame, flameValue=pcall(function()
                    return char:FindFirstChild("Flame-Flame")
                end)
                if okFlame then flame=flameValue end
            end

            local isTool=false
            if flame then
                local okClass, className=pcall(function() return flame.ClassName end)
                isTool=okClass and className=="Tool"
            end

            if isTool then
                task.spawn(function()
                    pcall(function()
                        setrobloxinput(true)
                        keyrelease(0x43)
                        keypress(0x43)
                        task.wait(0.08)
                        keyrelease(0x43)
                    end)
                end)
            end
        elseif not rPressed then
            holdingR=false
        end
        idleWait(S.flameRToC) -- 60 Hz key polling only while the feature is on
    end
end)

MATERIAL_ENEMIES={
    ["Leather + Scrap Metal"]={"Pirate","Brute","Gladiator","Mercenary","Swan Pirate","Marine Captain","Jungle Pirate","Forest Pirate"},
    ["Angel Wings"]={"God's Guard","Shanda","Royal Squad","Royal Soldier"},
    ["Magma Ore"]={"Military Soldier","Military Spy","Magma Ninja","Lava Pirate"},
    ["Fish Tail"]={"Fishman Warrior","Fishman Commando","Fishman Raider","Fishman Captain"},
    ["Radioactive Material"]={"Factory Staff"},
    ["Ectoplasm"]={"Ship Deckhand","Ship Engineer","Ship Steward","Ship Officer","Cursed Captain"},
    ["Mystic Droplet"]={"Sea Soldier","Water Fighter"},
    ["Vampire Fang"]={"Vampire"},
    ["Demonic Wisp"]={"Demonic Soul"},
    ["Conjured Cocoa"]={"Cocoa Warrior","Chocolate Bar Battler","Sweet Thief","Candy Rebel"},
    ["Dragon Scale"]={"Dragon Crew Warrior","Dragon Crew Archer"},
    ["Gunpowder"]={"Pistol Billionaire"},
    ["Mini Tusk"]={"Mythological Pirate"}
}

function materialWaitPosition(material)
    local sea=AFL.currentSea
    if material=="Angel Wings" then return AFL.waitPositions.SkyIsland3 end
    if material=="Radioactive Material" then return AFL.waitPositions.Factory2 end
    if material=="Ectoplasm" then return AFL.waitPositions.HauntedShip2 end
    if material=="Mystic Droplet" then return AFL.waitPositions.Wano2 end
    if material=="Vampire Fang" then return AFL.waitPositions.Graveyard2 end
    if material=="Demonic Wisp" then return AFL.waitPositions.HauntedCastle2 end
    if material=="Conjured Cocoa" then return AFL.waitPositions.Chocolate2 end
    if material=="Dragon Scale" then return AFL.waitPositions.Hydra2 end
    if material=="Gunpowder" then return AFL.waitPositions.Port2 end
    if material=="Mini Tusk" then return AFL.waitPositions.TurtleCenter1 end
    if material=="Magma Ore" then return sea==1 and AFL.waitPositions.MagmaIsland2 or AFL.waitPositions.HotSide2 end
    if material=="Fish Tail" then return sea==1 and AFL.waitPositions.UnderWaterIsland2 or AFL.waitPositions.Tiki2Quest1 end
    if material=="Leather + Scrap Metal" then
        if sea==1 then return AFL.waitPositions.PirateVillage2 end
        if sea==2 then return AFL.waitPositions.RoseKingdom2 end
        return AFL.waitPositions.TurtleEntrance2
    end
    return nil
end

enhancedComm=nil
enhancedCommMissUntil=0 -- a failed full ReplicatedStorage scan is not repeated for 10 s
function getEnhancedComm()
    if enhancedComm then
        local okParent,parent=pcall(function() return enhancedComm.Parent end)
        if okParent and parent then return enhancedComm end
        enhancedComm=nil
    end
    local storage=game:GetService("ReplicatedStorage")
    local remotes=storage and storage:FindFirstChild("Remotes")
    enhancedComm=remotes and remotes:FindFirstChild("CommF_") or nil
    if not enhancedComm and clock()<enhancedCommMissUntil then return nil end
    if not enhancedComm then enhancedCommMissUntil=clock()+10 end
    if not enhancedComm and storage then
        local okDescendants,descendants=pcall(function() return storage:GetDescendants() end)
        if okDescendants and descendants then
            for _,object in pairs(descendants) do
                local okName,name=pcall(function() return object.Name end)
                if okName and name=="CommF_" then enhancedComm=object; break end
            end
        end
    end
    return enhancedComm
end

function invokeEnhancedComm(first,second,third,fourth)
    local remote=getEnhancedComm()
    if not remote then return false,nil,"CommF_ not found" end
    -- Same trailing-nil trimming as before; quietInvoke (00_core) serialises
    -- the CommF_ invokes, keeps the part writes quiet around them, and goes
    -- through safeRemote (pcall, throttled warning).
    local ok,result
    if fourth~=nil then ok,result=quietInvoke("CommF_",remote,first,second,third,fourth)
    elseif third~=nil then ok,result=quietInvoke("CommF_",remote,first,second,third)
    elseif second~=nil then ok,result=quietInvoke("CommF_",remote,first,second)
    elseif first~=nil then ok,result=quietInvoke("CommF_",remote,first)
    else ok,result=quietInvoke("CommF_",remote) end
    if not ok then
        -- A postponed (deferrable) invoke was never sent: keep the remote.
        if result~=QUIET_POSTPONED then enhancedComm=nil end
        return false,nil,tostring(result)
    end
    return true,result,nil
end

function nearestMatchingEnemy(hrp,names)
    local folder=Workspace:FindFirstChild("Enemies")
    if not folder or not hrp or not names then return nil end
    local allowed={}
    for _,name in ipairs(names) do allowed[name]=true end
    local okPlayer,playerPos=pcall(function() return hrp.Position end)
    if not okPlayer or not playerPos then return nil end
    local best,bestDistance=nil,math.huge
    for _,enemy in pairs(folder:GetChildren()) do
        local okName,name=pcall(function() return enemy.Name end)
        if okName and allowed[name] and isAlive(enemy) then
            local root=enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChildWhichIsA("BasePart")
            local okPos,pos=pcall(function() return root and root.Position end)
            if okPos and pos then
                local dx=pos.X-playerPos.X
                local dy=pos.Y-playerPos.Y
                local dz=pos.Z-playerPos.Z
                local distance=dx*dx+dy*dy+dz*dz
                if distance<bestDistance then best,bestDistance=name,distance end
            end
        end
    end
    return best
end

function showEventStatus()
    local locations=nil
    pcall(function()
        local origin=Workspace:FindFirstChild("_WorldOrigin")
        locations=origin and origin:FindFirstChild("Locations") or nil
    end)
    local map=Workspace:FindFirstChild("Map")
    local mirage=locations and locations:FindFirstChild("Mirage Island")
    local prehistoric=locations and locations:FindFirstChild("Prehistoric Island")
    local frozen=locations and locations:FindFirstChild("Frozen Dimension")
    local kitsune=map and map:FindFirstChild("KitsuneIsland")
    local message="Mirage: "..(mirage and "YES" or "NO").." | Kitsune: "..(kitsune and "YES" or "NO").." | Prehistoric: "..(prehistoric and "YES" or "NO").." | Frozen: "..(frozen and "YES" or "NO")
    print("[World Status] "..message)
    notify(message,"World Status",8)
end

function showBossStatus()
    local storage=game:GetService("ReplicatedStorage")
    local enemies=Workspace:FindFirstChild("Enemies")
    local function present(name,alternate)
        return (enemies and (enemies:FindFirstChild(name) or (alternate and enemies:FindFirstChild(alternate)))) or storage:FindFirstChild(name) or (alternate and storage:FindFirstChild(alternate))
    end
    local message="Rip Indra: "..(present("rip_indra True Form","rip_indra") and "YES" or "NO").." | Dough King: "..(present("Dough King") and "YES" or "NO").." | Cake Prince: "..(present("Cake Prince") and "YES" or "NO")
    print("[Boss Status] "..message)
    notify(message,"Boss Status",8)
end

function showLegendarySwordStatus()
    -- Verified against the game's DialoguesList (live, Oct 15 2026):
    --   CommF_("LegendarySwordDealer","1") = check only; returns the sword name, or nil when the dealer is gone.
    --   CommF_("LegendarySwordDealer","2") = BUYS the sword for $2,000,000.
    -- The old loop sent "1","2","3" (one per sword name), so pressing the button could spend 2M Beli.
    -- Only "1" is sent now. Matcha's Hybrid InvokeServer returns a boolean, not the server value,
    -- so the sword name itself cannot be read back here; the dealer is reported as present or absent.
    local ok,result=invokeEnhancedComm("LegendarySwordDealer","1")
    local message
    if ok and type(result)=="string" and result~="" then
        message="Dealer present, selling: "..result
    elseif ok and result then
        message="Dealer present (sword name not readable in Matcha)"
    else
        message="Not found"
    end
    -- notify() is silenced, so print like the other two status buttons do.
    print("[Legendary Sword Dealer] "..message)
    notify(message,"Legendary Sword Dealer",6)
end

function safeObjectPosition(object)
    if not object then return nil end
    local okPosition,position=pcall(function() return object.Position end)
    if okPosition and position and position.X and position.Y and position.Z then return position end
    local okPrimary,primary=pcall(function() return object.PrimaryPart end)
    if okPrimary and primary then
        local okPrimaryPosition,primaryPosition=pcall(function() return primary.Position end)
        if okPrimaryPosition and primaryPosition then return primaryPosition end
    end
    local okChildren,children=pcall(function() return object:GetDescendants() end)
    if okChildren and children then
        for _,child in pairs(children) do
            local okClass,className=pcall(function() return child.ClassName end)
            if okClass and (className=="Part" or className=="MeshPart" or className=="VehicleSeat") then
                local okChildPosition,childPosition=pcall(function() return child.Position end)
                if okChildPosition and childPosition then return childPosition end
            end
        end
    end
    return nil
end

function findMirageObject()
    local origin=Workspace:FindFirstChild("_WorldOrigin")
    local locations=origin and origin:FindFirstChild("Locations")
    local location=locations and locations:FindFirstChild("Mirage Island")
    if location then return location end
    local map=Workspace:FindFirstChild("Map")
    return map and (map:FindFirstChild("MysticIsland") or map:FindFirstChild("Mirage Island")) or nil
end

-- clearMirageEsp removes the label (toggle off / unload); hideMirageEsp only
-- hides it for a frame when Mirage is off-screen or missing.
function clearMirageEsp()
    removeDrawing(S.mirageEspLabel)
    S.mirageEspLabel=nil
end

function hideMirageEsp()
    setProp(S.mirageEspLabel,"Visible",false)
end

function updateMirageEsp()
    if not S.mirageEsp then
        if S.mirageEspLabel then clearMirageEsp() end
        return
    end
    if not S.mirageEspLabel then
        S.mirageEspLabel=newText("Mirage Island",Color3.fromRGB(100,220,255),22,20)
        if not S.mirageEspLabel then return end
    end
    local mirage=findMirageObject()
    local position=safeObjectPosition(mirage)
    if not position then hideMirageEsp(); return end
    local okScreen,screen,onScreen=pcall(WorldToScreen,position)
    if not okScreen or not screen or onScreen~=true then hideMirageEsp(); return end
    local distanceText=""
    local playerPosition=localRootPosition()
    if playerPosition then
        local dx=position.X-playerPosition.X
        local dy=position.Y-playerPosition.Y
        local dz=position.Z-playerPosition.Z
        distanceText=" ["..tostring(math.floor(math.sqrt(dx*dx+dy*dy+dz*dz))).."]"
    end
    setProp(S.mirageEspLabel,"Text","Mirage Island"..distanceText)
    setProp(S.mirageEspLabel,"Position",screen)
    setProp(S.mirageEspLabel,"Visible",true)
end

function findMirageGear()
    local map=Workspace:FindFirstChild("Map")
    local island=map and map:FindFirstChild("MysticIsland")
    if not island then return nil end
    local okChildren,children=pcall(function() return island:GetChildren() end)
    if not okChildren or not children then return nil end
    local character=LocalPlayer.Character
    local hrp=character and character:FindFirstChild("HumanoidRootPart")
    local okPlayer,playerPosition=pcall(function() return hrp and hrp.Position end)
    local nearest,nearestDistance=nil,math.huge
    for _,child in pairs(children) do
        local okInfo,name,className,transparency=pcall(function() return child.Name,child.ClassName,child.Transparency end)
        if okInfo and name=="Part" and className=="MeshPart" and (tonumber(transparency) or 0)<1 then
            local position=safeObjectPosition(child)
            if position then
                local distance=0
                if okPlayer and playerPosition then
                    local dx=position.X-playerPosition.X
                    local dy=position.Y-playerPosition.Y
                    local dz=position.Z-playerPosition.Z
                    distance=dx*dx+dy*dy+dz*dz
                end
                if distance<nearestDistance then nearest,nearestDistance=child,distance end
            end
        end
    end
    return nearest
end

namedRemoteCache={}
namedRemoteMissUntil={} -- name -> clock(): no full ReplicatedStorage scan before then
function findReplicatedObject(name)
    local cached=namedRemoteCache[name]
    if cached then
        local okParent,parent=pcall(function() return cached.Parent end)
        if okParent and parent then return cached end
        namedRemoteCache[name]=nil
    end
    local storage=game:GetService("ReplicatedStorage")
    local direct=storage and storage:FindFirstChild(name)
    if direct then namedRemoteCache[name]=direct; return direct end
    if clock()<(namedRemoteMissUntil[name] or 0) then return nil end
    namedRemoteMissUntil[name]=clock()+10
    local okDescendants,descendants=pcall(function() return storage:GetDescendants() end)
    if okDescendants and descendants then
        for _,object in pairs(descendants) do
            local okName,objectName=pcall(function() return object.Name end)
            if okName and objectName==name then namedRemoteCache[name]=object; return object end
        end
    end
    return nil
end

task.spawn(function()
    while alive() do
        pcall(updateMirageEsp)
        task.wait(0.05)
    end
end)

-- Boss / material / sea-event farms. farmAttack returns immediately when the
-- target it finds differs from the one nearestMatchingEnemy saw (or none is in
-- range); every branch now yields so such a case cannot freeze the VM.
task.spawn(function()
    while alive() do
        if S.autoSeaEvent and not (S.fruitPriorityActive or S.gachaPaused) and not S.autoMirageTween and not S.autoMirageGear then
            local character=LocalPlayer.Character
            local hrp=character and character:FindFirstChild("HumanoidRootPart")
            local target=S.selectedSeaEvent
            local spawned=hrp and nearestMatchingEnemy(hrp,{target}) or nil
            if hrp and spawned then
                local useRemote=S.remoteMode
                pcall(farmAttack,hrp,function()
                    return S.autoSeaEvent and not (S.fruitPriorityActive or S.gachaPaused) and not S.autoMirageTween and not S.autoMirageGear and S.selectedSeaEvent==target and S.remoteMode==useRemote
                end,target,true,1000000,useRemote and remoteAttack or nil,useRemote and 0.05 or 0.06)
                frameWait()
            else
                task.wait(0.25)
            end
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while alive() do
        if S.autoMirageTween and not (S.fruitPriorityActive or S.gachaPaused) then
            local mirage=findMirageObject()
            local position=safeObjectPosition(mirage)
            local character=LocalPlayer.Character
            local hrp=character and character:FindFirstChild("HumanoidRootPart")
            if position and hrp then
                tweenTo(hrp,Vector3.new(position.X,position.Y+300,position.Z),S.FARM_SPEED,function()
                    return S.autoMirageTween and not (S.fruitPriorityActive or S.gachaPaused) and findMirageObject()~=nil
                end)
                -- Once hovering above Mirage tweenTo returns at once; this loop used
                -- to re-enter it without ever yielding.
                frameWait()
            else
                task.wait(0.35)
            end
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while alive() do
        if S.autoMirageGear and not (S.fruitPriorityActive or S.gachaPaused) then
            local gear=findMirageGear()
            local position=safeObjectPosition(gear)
            local character=LocalPlayer.Character
            local hrp=character and character:FindFirstChild("HumanoidRootPart")
            if gear and position and hrp then
                tweenTo(hrp,Vector3.new(position.X,position.Y+3,position.Z),S.FARM_SPEED,function()
                    return S.autoMirageGear and not (S.fruitPriorityActive or S.gachaPaused) and partStillThere(gear)
                end)
                task.wait(0.2)
            else
                task.wait(0.25)
            end
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    local lastAbility=-math.huge
    while alive() do
        if S.autoRaceAbility and clock()-lastAbility>=1 then
            local remote=findReplicatedObject("CommE")
            if remote then safeRemote("CommE ActivateAbility",remote,"FireServer","ActivateAbility") end
            -- Back off to once every 5 s while the remote keeps failing.
            lastAbility=remoteFailing("CommE ActivateAbility") and clock()+4 or clock()
        end
        task.wait(0.1)
    end
end)

task.spawn(function()
    while alive() do
        if S.autoBossFarm and not (S.fruitPriorityActive or S.gachaPaused) and not S.autoSeaEvent and not S.autoMirageTween and not S.autoMirageGear then
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            local target=S.selectedBoss
            local spawned=hrp and nearestMatchingEnemy(hrp,{target}) or nil
            if hrp and spawned then
                local useRemote=S.remoteMode
                pcall(farmAttack,hrp,function()
                    return S.autoBossFarm and not (S.fruitPriorityActive or S.gachaPaused) and not S.autoSeaEvent and not S.autoMirageTween and not S.autoMirageGear and S.selectedBoss==target and S.remoteMode==useRemote
                end,target,true,5000,useRemote and remoteAttack or nil,useRemote and 0.05 or 0.06)
                frameWait()
            else
                task.wait(0.25) -- re-scan at 4 Hz while no target is up (was 0.35 s)
            end
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while alive() do
        if S.autoMaterialFarm and not S.autoBossFarm and not (S.fruitPriorityActive or S.gachaPaused) and not S.autoSeaEvent and not S.autoMirageTween and not S.autoMirageGear then
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            local material=S.selectedMaterial
            local names=MATERIAL_ENEMIES[material]
            local target=hrp and nearestMatchingEnemy(hrp,names) or nil
            if hrp and target then
                local useRemote=S.remoteMode
                pcall(farmAttack,hrp,function()
                    return S.autoMaterialFarm and not S.autoBossFarm and not (S.fruitPriorityActive or S.gachaPaused) and not S.autoSeaEvent and not S.autoMirageTween and not S.autoMirageGear and S.selectedMaterial==material and S.remoteMode==useRemote
                end,target,true,5000,useRemote and remoteAttack or nil,useRemote and 0.05 or 0.06)
                frameWait()
            elseif hrp then
                local waitPos=materialWaitPosition(material)
                if waitPos then
                    tweenTo(hrp,waitPos,S.FARM_SPEED,function()
                        return S.autoMaterialFarm and not S.autoBossFarm and not (S.fruitPriorityActive or S.gachaPaused) and not S.autoSeaEvent and not S.autoMirageTween and not S.autoMirageGear and S.selectedMaterial==material
                    end)
                end
                task.wait(0.25) -- re-scan at 4 Hz while no target is up (was 0.35 s)
            else
                task.wait(0.35)
            end
        else
            task.wait(0.1)
        end
    end
end)

-- Auto Stat with per-stat caps. Reads LocalPlayer.Data.Points and
-- Data.Stats[<name>].Level (confirmed live); the AddPoint name is the
-- Data.Stats folder name. Cap 0 = unlimited (the old behaviour). Each call
-- spends min(points per upgrade, cap - level, available points).
--
-- Stability pass (Oct 15 2026). Matcha's InvokeServer returns only a boolean,
-- so a refused AddPoint looked like a spend, and a spend whose Data update
-- took longer than 5 s was forgotten and spent again (cap overshoot; with no
-- replication at all, one irreversible AddPoint about every 1.6 s). Now:
--   * a spend is "pending" until Data proves it (Level rose or Points
--     dropped); while anything is pending no stat spends at all;
--   * a proven spend whose Level has not replicated yet keeps its expected
--     level as a floor for the cap arithmetic, so a stale Level cannot cause
--     a second spend past the cap;
--   * no proof within AUTO_STAT_CONFIRM_SECS: that stat's toggle is switched
--     off with a warning (never a blind re-spend after a timeout); its floor
--     stays until the toggle is switched on again;
--   * the cap switches a toggle off only against the confirmed (live) level;
--   * one spend per pass, and the pass is pcall'd with a back-off on error.
AUTO_STAT_CONFIRM_SECS=15
-- Speed restore (Oct 15 2026): every AddPoint goes through quietInvoke, whose
-- quiet window (~0.6-1.1 s without root writes or M1 swings) used to land in
-- the middle of fights and flights. Spends are now queued (points stay
-- unspent) and sent only at a calm moment: no travel mark (tweenTo, mastery
-- and boat tweens, pads) for AUTO_STAT_CALM_SECS and no combat mark (hard
-- lock, remote M1 swing, farm click) for AUTO_STAT_CALM_SECS. That is: farms
-- off, waiting for a spawn at a wait spot, or at a quest giver. During a
-- farm with no calm moment, at most one spend per AUTO_STAT_BUSY_INTERVAL s,
-- and only while not travelling (never mid-flight). The invoke is
-- deferrable (S.quietDefer): if travel (or, for a calm spend, combat) starts
-- during the quiet window's lead-in, the AddPoint is not sent and is retried
-- at the next calm moment.
AUTO_STAT_CALM_SECS=1.5
AUTO_STAT_BUSY_INTERVAL=60
task.spawn(function()
    -- {toggle state key, AddPoint / Data.Stats name, cap state key, toggle id, label}
    local statEntries={{"autoStatMelee","Melee","statCapMelee","stat_melee","Melee"},{"autoStatDefense","Defense","statCapDefense","stat_defense","Def"},{"autoStatSword","Sword","statCapSword","stat_sword","Sword"},{"autoStatGun","Gun","statCapGun","stat_gun","Gun"},{"autoStatFruit","Demon Fruit","statCapFruit","stat_fruit","Fruit"}}
    local pending={}   -- name -> {base, lvl, pts, t, entry}: one AddPoint not yet proven by Data
    local lastSpendAt=-1e9 -- clock() of the last AddPoint sent
    local queued=false     -- points are waiting for a calm moment (label)
    -- nil = wait (travel, or combat inside AUTO_STAT_BUSY_INTERVAL); "any" =
    -- calm spend (postponed by travel or combat); "travel" = the once per
    -- AUTO_STAT_BUSY_INTERVAL s spend during combat (postponed by travel).
    local function spendMode()
        local now=clock()
        if now-ACTIVITY.travelAt<AUTO_STAT_CALM_SECS then return nil end
        if now-ACTIVITY.fightAt>=AUTO_STAT_CALM_SECS then return "any" end
        if now-lastSpendAt>=AUTO_STAT_BUSY_INTERVAL then return "travel" end
        return nil
    end
    local floor={}     -- name -> expected level of proven (or unproven, stopped) spends not replicated yet
    local wasOn={}     -- name -> toggle state last pass (a fresh "on" clears the floor)
    local function readValue(parent,name)
        local child=parent and parent:FindFirstChild(name)
        if not child then return nil end
        local ok,v=pcall(function() return child.Value end)
        return ok and tonumber(v) or nil
    end
    local function statData() return LocalPlayer and LocalPlayer:FindFirstChild("Data") end
    local function points() return readValue(statData(),"Points") end
    local function liveLevel(name)
        local data=statData()
        local stats=data and data:FindFirstChild("Stats")
        return readValue(stats and stats:FindFirstChild(name),"Level")
    end
    -- Level for the cap arithmetic: the live value, raised by the floor and by
    -- a pending spend. nil when Level cannot be read.
    local function spendLevel(name)
        local cur=liveLevel(name)
        if cur==nil then return nil end
        local f=floor[name]
        if f then
            if cur>=f then floor[name]=nil else cur=f end
        end
        local p=pending[name]
        if p and p.lvl>cur then cur=p.lvl end
        return cur
    end
    local function capOf(e)
        local cap=math.floor(tonumber(S[e[3]]) or 0)
        if cap<=0 then return math.huge end
        return cap
    end
    local function updateLabel(pts)
        local label=S.statStatusLabel
        if type(label)~="table" then return end
        local parts={}
        for _,e in ipairs(statEntries) do
            local cur,cap,live=spendLevel(e[2]),capOf(e),liveLevel(e[2])
            local s=e[5].." "..(cur and tostring(cur) or "?").."/"..(cap==math.huge and "-" or tostring(cap))
            if live and cap~=math.huge and live>=cap then s=s.."(cap)"
            elseif pending[e[2]] then s=s.."(wait)" end
            parts[#parts+1]=s
        end
        local suffix=queued and " (queued: fighting/travelling)" or ""
        pcall(function() label.Text="Pts "..(pts and tostring(pts) or "?").." | "..table.concat(parts," ")..suffix end)
    end
    local function switchOff(e)
        if not S[e[1]] then return end
        pcall(function() Window:Set(e[4],false) end)
        S[e[1]]=false
    end
    local function capReached(e,cap)
        if not S[e[1]] then return end
        switchOff(e)
        notify("Auto "..e[2].." stopped at cap "..tostring(cap),"Auto Stat",3)
        warnThrottled("autostat:cap:"..e[2],"[laced.club] Auto Stat: "..e[2].." reached its cap ("..tostring(cap).."), toggle switched off",30)
    end
    -- Proven: the level rose above the level before the call, or Points
    -- dropped below the points before it. Timed out: the stat is stopped.
    local function resolvePending()
        local now=clock()
        local pts=points()
        for name,p in pairs(pending) do
            local cur=liveLevel(name)
            local levelRose=cur~=nil and p.base~=nil and cur>p.base
            local pointsDropped=pts~=nil and p.pts~=nil and pts<p.pts
            if levelRose or pointsDropped then
                pending[name]=nil
                if cur==nil or cur<p.lvl then floor[name]=math.max(floor[name] or 0,p.lvl) end
            elseif now-p.t>=AUTO_STAT_CONFIRM_SECS then
                pending[name]=nil
                floor[name]=math.max(floor[name] or 0,p.lvl)
                switchOff(p.entry)
                warnThrottled("autostat:unconfirmed:"..name,"[laced.club] Auto Stat: AddPoint "..name.." was not confirmed by Data within "
                    ..AUTO_STAT_CONFIRM_SECS.."s; Auto "..name.." switched off (no blind re-spend)",30)
            end
        end
    end
    local function pass()
        resolvePending()
        local pts=points()
        for _,e in ipairs(statEntries) do
            local on=S[e[1]]==true
            if on and not wasOn[e[2]] then floor[e[2]]=nil end
            wasOn[e[2]]=on
        end
        if not pts or pts<=0 or remoteFailing("CommF_") or next(pending)~=nil then queued=false; updateLabel(pts); return end
        local mode=spendMode()
        queued=mode==nil
        updateLabel(pts)
        if not mode then return end -- queued until a calm moment
        for _,e in ipairs(statEntries) do
            if not alive() then return end
            if S[e[1]] then
                local cap=capOf(e)
                local live=liveLevel(e[2])
                local cur=spendLevel(e[2])
                if cur==nil and cap~=math.huge then
                    -- Never spend blind against a cap.
                    warnThrottled("autostat:read","[laced.club] Auto Stat: cannot read Data.Stats."..e[2]..".Level; capped stat skipped",30)
                elseif live~=nil and cap~=math.huge and live>=cap then
                    capReached(e,cap)
                elseif cap-(cur or 0)>0 then
                    local remaining=cap-(cur or 0)
                    local amount=math.max(1,math.floor(tonumber(S.statAmount) or 10))
                    local n=math.floor(math.min(amount,remaining,pts))
                    if n>0 then
                        S.quietDefer=mode -- read (and cleared) by quietInvoke
                        local ok,_,err=invokeEnhancedComm("AddPoint",e[2],n)
                        S.quietDefer=nil
                        if not ok and err==QUIET_POSTPONED then
                            -- Travel/combat started in the lead-in: not sent,
                            -- not a failure; retried at the next calm moment.
                            return
                        end
                        lastSpendAt=clock()
                        if not ok then
                            warnThrottled("autostat:remote","[laced.club] Auto Stat: AddPoint failed: "..tostring(err),20)
                            return
                        end
                        pending[e[2]]={base=live,lvl=(cur or 0)+n,pts=pts,t=clock(),entry=e}
                        -- Give Data up to ~1 s; an unproven spend stays pending
                        -- (blocking every stat) until AUTO_STAT_CONFIRM_SECS.
                        local waited=0
                        repeat
                            task.wait(0.12)
                            waited=waited+0.12
                            resolvePending()
                        until not alive() or waited>=1 or pending[e[2]]==nil
                        updateLabel(points())
                        return -- one spend per pass; the next pass re-reads everything
                    end
                end
                -- else: the cap is reached only by spends Data has not shown
                -- yet (floor/pending): hold, do not switch the toggle off.
            end
        end
    end
    while alive() do
        local okPass,passError=pcall(pass)
        if not okPass then
            warnThrottled("autostat:error","[laced.club] Auto Stat error: "..tostring(passError),30)
            task.wait(2)
        end
        if remoteFailing("CommF_") then task.wait(5) else task.wait(0.5) end
    end
end)

-- Auto Fruit Gacha (Oct 15 2026). The Blox Fruit Gacha NPC (Sea 1 Middle
-- Town, Sea 2 Cafe, Sea 3 Mansion) still answers the classic CommF_
-- "Cousin" call from anywhere on the map (live: "Cousin","Check" answered in
-- Sea 2 about 4,000 studs from the Cafe), so no travel is needed: the roll is
-- CommF_ "Cousin","Buy" through invokeEnhancedComm (quiet window,
-- serialised with every other CommF_ invoke).
-- Matcha's InvokeServer returns only a boolean, so the server's answer
-- (fruit name, cooldown text) is not visible. A roll is proven by Data.Beli
-- dropping or a new "... Fruit" tool appearing within GACHA_CONFIRM_SECS.
--   * proven: the next roll is GACHA_COOLDOWN_SECS later;
--   * not proven (cooldown still running from a roll made elsewhere, not
--     enough Beli, level too low): retried after GACHA_RETRY_SECS, never
--     spammed.
-- The next-roll time is os.time() based and saved per account to
-- laced_club_configs/gacha_<UserId>.txt, so a re-run or a rejoin keeps it.
-- "Roll Gacha Now" ignores the saved time for one attempt.
-- Store Rolled Fruit (on by default): after a proven roll with a new fruit
-- tool, the fruit is equipped by its hotbar number key and stored with
-- CommF_ "StoreFruit" (storeFruit below).
GACHA_COOLDOWN_SECS=2*60*60
GACHA_RETRY_SECS=10*60
GACHA_CONFIRM_SECS=4
GACHA_CALM_SECS=1.5
GACHA_PAUSE_SECS=5
task.spawn(function()
    local folder="laced_club_configs"
    local userId=0
    pcall(function() userId=tonumber(LocalPlayer.UserId) or 0 end)
    local path=folder.."/gacha_"..tostring(userId)..".txt"
    local function now() return os.time() end
    local function loadNext()
        local value=0
        pcall(function()
            if isfile(path) then value=tonumber(readfile(path)) or 0 end
        end)
        return value
    end
    local function saveNext(t)
        pcall(function()
            if not isfolder(folder) then makefolder(folder) end
            writefile(path,tostring(math.floor(t)))
        end)
    end
    local nextAt=loadNext()
    local lastResult="idle"
    local function setLabel()
        local label=S.gachaStatusLabel
        if type(label)~="table" then return end
        local left=nextAt-now()
        local timer
        if left<=0 then timer="ready"
        else timer=string.format("next in %dh %02dm",math.floor(left/3600),math.floor((left%3600)/60)) end
        pcall(function() label.Text="Gacha: "..lastResult.." | "..timer end)
    end
    local function beli()
        local data=LocalPlayer and LocalPlayer:FindFirstChild("Data")
        local value=data and data:FindFirstChild("Beli")
        if not value then return nil end
        local ok,v=pcall(function() return value.Value end)
        return ok and tonumber(v) or nil
    end
    -- Names of fruit tools held now (Backpack and Character), as a set.
    local function fruitTools()
        local out={}
        for _,holder in ipairs({LocalPlayer and LocalPlayer:FindFirstChild("Backpack"),LocalPlayer and LocalPlayer.Character}) do
            if holder then
                local okChildren,children=pcall(function() return holder:GetChildren() end)
                if okChildren and children then
                    for _,child in ipairs(children) do
                        local okName,name=pcall(function() return child.Name end)
                        if okName and type(name)=="string" and string.find(name,"Fruit",1,true) then out[name]=(out[name] or 0)+1 end
                    end
                end
            end
        end
        return out
    end
    local function newFruit(before,after)
        for name,count in pairs(after) do
            if count>(before[name] or 0) then return name end
        end
        return nil
    end
    local function findFruitTool(name)
        for _,holder in ipairs({LocalPlayer and LocalPlayer.Character,LocalPlayer and LocalPlayer:FindFirstChild("Backpack")}) do
            local okTool,tool=pcall(function() return holder and holder:FindFirstChild(name) end)
            if okTool and tool then return tool end
        end
        return nil
    end
    local function heldName()
        local tool=getCurrentlyHeldTool()
        local okName,name=pcall(function() return tool and tool.Name end)
        return okName and name or nil
    end
    -- Hotbar key route (the user's ask): press number keys until the new
    -- fruit is the held tool. The hotbar frames' names are not readable
    -- through Matcha (WeaponEquip.hotbarName), so the slot is found by trying:
    -- the slot after the last filled one first (a new tool lands there), then
    -- 1-9. A wrong tool is put away again by pressing its key a second time.
    -- Keys only while Roblox is focused and before the pause deadline (the
    -- farms are paused, so no farm click can eat the fruit in hand).
    local function equipFruitByKey(name,deadline)
        if not robloxFocused() then return false,nil end
        local kids=0
        pcall(function()
            for _,child in ipairs(LocalPlayer.Backpack:GetChildren()) do
                if child.ClassName=="Tool" then kids=kids+1 end
            end
        end)
        if getCurrentlyHeldTool() then kids=kids+1 end
        local order={}
        local guess=math.min(9,math.max(1,kids))
        order[1]=guess
        for slot=1,9 do if slot~=guess then order[#order+1]=slot end end
        for _,slot in ipairs(order) do
            if not alive() or not robloxFocused() then return false,nil end
            if clock()>=deadline-1.5 then break end -- keep time for the store call
            if heldName()==name then return true,nil end
            local key=WeaponEquip.key(slot)
            pcall(function()
                setrobloxinput(true)
                keyrelease(key); task.wait(0.02); keypress(key); task.wait(0.1); keyrelease(key)
            end)
            task.wait(0.35)
            local held=heldName()
            if held==name then return true,key end
            if held~=nil then
                -- Wrong tool: press the same key again to put it away.
                pcall(function() keypress(key); task.wait(0.1); keyrelease(key) end)
                task.wait(0.25)
            end
        end
        return heldName()==name,nil
    end
    -- "Spin Fruit" -> "Spin-Spin" when the tool has no OriginalName attribute.
    local function storeName(tool,name)
        local okAttr,attr=pcall(function() return tool:GetAttribute("OriginalName") end)
        if okAttr and type(attr)=="string" and attr~="" then return attr end
        local base=string.match(name,"^(.-)%s+Fruit$") or name
        return base.."-"..base
    end
    -- Equip the rolled fruit with its hotbar key, then store it (CommF_
    -- "StoreFruit", the call the game's Store button makes). Auto Farm Quest
    -- never leaves a calm moment, so instead of waiting for one every farm is
    -- paused (S.gachaPaused, read by farmPriorityFeatureActive and the
    -- boss/material/sea/mirage/raid loops) for at most GACHA_PAUSE_SECS. The
    -- pause is always released, stored or not; the farms (AFQ's loop
    -- included) pick up again on their own at their next pass.
    -- Proven by the tool leaving Backpack and Character.
    local function storeFruitPaused(name,deadline)
        -- Let the farms see the pause and stop clicking/swinging.
        local settleUntil=math.min(deadline-3,clock()+0.6)
        while alive() and clock()<settleUntil do task.wait(0.05) end
        local equipped,equipKey=equipFruitByKey(name,deadline)
        local tool=findFruitTool(name)
        if not tool then return true,"gone",nil end
        local ok,_,err=invokeEnhancedComm("StoreFruit",storeName(tool,name),tool)
        if not ok then return false,"StoreFruit failed: "..tostring(err),equipKey end
        repeat
            task.wait(0.2)
        until not alive() or findFruitTool(name)==nil or clock()>=deadline
        if findFruitTool(name)==nil then return true,equipped and "key" or "remote",nil end
        return false,"still in backpack (storage full?)",equipKey
    end
    local function storeFruit(name)
        local deadline=clock()+GACHA_PAUSE_SECS
        S.gachaPaused=true
        local okRun,stored,how,equipKey=pcall(storeFruitPaused,name,deadline)
        -- Not stored: put the fruit away so the farm re-equips its weapon and
        -- no click can eat it.
        if not (okRun and stored) and equipKey and heldName()==name and robloxFocused() then
            pcall(function() keypress(equipKey); task.wait(0.1); keyrelease(equipKey) end)
        end
        S.gachaPaused=false
        if not okRun then return false,tostring(stored) end
        return stored,how
    end
    local function roll(manual)
        local beliBefore=beli()
        local toolsBefore=fruitTools()
        S.quietDefer="travel" -- read (and cleared) by quietInvoke: a flight starting in the lead-in postpones it
        local ok,_,err=invokeEnhancedComm("Cousin","Buy")
        S.quietDefer=nil
        if not ok and err==QUIET_POSTPONED then return "postponed" end
        if not ok then
            lastResult="remote failed"
            warnThrottled("gacha:remote","[laced.club] Gacha: Cousin Buy failed: "..tostring(err),30)
            nextAt=now()+GACHA_RETRY_SECS
            return "failed"
        end
        local waited=0
        local fruit,spent=nil,false
        repeat
            task.wait(0.2)
            waited=waited+0.2
            local beliAfter=beli()
            spent=beliBefore~=nil and beliAfter~=nil and beliAfter<beliBefore
            fruit=newFruit(toolsBefore,fruitTools())
        until not alive() or spent or fruit or waited>=GACHA_CONFIRM_SECS
        if spent or fruit then
            -- Give the fruit tool a moment to replicate after the Beli drop.
            if not fruit then task.wait(0.6); fruit=newFruit(toolsBefore,fruitTools()) end
            lastResult=fruit and ("got "..fruit) or "rolled"
            nextAt=now()+GACHA_COOLDOWN_SECS
            saveNext(nextAt)
            notify(fruit and ("Gacha rolled: "..fruit) or "Gacha rolled (fruit sent to inventory)","Fruit Gacha",5)
            if fruit and S.gachaStoreFruit then
                local stored,how=storeFruit(fruit)
                if stored then
                    lastResult="stored "..fruit
                    notify("Stored "..fruit,"Fruit Gacha",4)
                else
                    lastResult="got "..fruit.." (not stored)"
                    warnThrottled("gacha:store","[laced.club] Gacha: could not store "..fruit..": "..tostring(how),30)
                    notify("Could not store "..fruit..": "..tostring(how),"Fruit Gacha",5)
                end
            end
            return "rolled"
        end
        lastResult="no roll (cooldown/Beli?)"
        nextAt=now()+GACHA_RETRY_SECS
        if manual then notify("Gacha did not roll: cooldown running, not enough Beli, or level too low","Fruit Gacha",5) end
        return "none"
    end
    while alive() do
        local okPass,passError=pcall(function()
            local manual=S.gachaRollNow==true
            if (S.autoGachaRoll or manual) and not remoteFailing("CommF_") then
                if manual or now()>=nextAt then
                    if clock()-ACTIVITY.travelAt<GACHA_CALM_SECS then
                        lastResult="waiting (travelling)"
                    elseif roll(manual)~="postponed" then
                        S.gachaRollNow=false
                    end
                end
            else
                S.gachaRollNow=false
            end
            setLabel()
        end)
        if not okPass then
            S.gachaRollNow=false
            warnThrottled("gacha:error","[laced.club] Gacha error: "..tostring(passError),30)
            task.wait(2)
        end
        task.wait(1)
    end
end)
-- Load marker: this chunk ran to the end.
if LACED_LOAD and type(LACED_LOAD.done) == "table" then LACED_LOAD.done["80_misc2"] = true end
