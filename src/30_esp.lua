-- @chunk 30_esp  (lines 2951-3650 of the single-file build)
local LACED_LOAD = type(_G.__lacedLoad) == "table" and _G.__lacedLoad or nil -- load marker (loader.lua)
if LACED_LOAD and type(LACED_LOAD.started) == "table" then LACED_LOAD.started["30_esp"] = true end
-- Per-execution bindings: captured at chunk load so a re-run of the script
-- cannot make this copy's loops read the new copy's state (alive is a
-- closure over this run's state since the Oct 15 stability pass).
local alive = alive
local SCRIPT_STATE = SCRIPT_STATE
local S = S
BERRIES={
    {name="Green Toad Berry",   sphere="Sphere.011"},
    {name="Yellow Star Berry",  sphere="Sphere.022"},
    {name="Orange Berry",       sphere="Sphere.007"},
    {name="Red Cherry Berry",   sphere="Sphere.005"},
    {name="Purple Jelly Berry", sphere="Sphere.004"},
    {name="Pink Pig Berry",     sphere="Sphere.008"},
    {name="Blue Icicle Berry",  sphere="Sphere.018"},
    {name="White Cloud Berry",  sphere="Sphere.035"},
}

BERRY_SPHERE_NAMES={}
for _,berry in pairs(BERRIES) do
    BERRY_SPHERE_NAMES[berry.sphere]=berry.name
end

function getSafeFruitPosition(candidate)
    if not candidate then return nil end
    local okParent, parent=pcall(function() return candidate.Parent end)
    if not okParent or not parent then return nil end
    local okPos, pos=pcall(function() return candidate.Position end)
    if okPos and pos and pos.X and pos.Y and pos.Z then return pos end
    return nil
end

function resolveFruitPart(root)
    if not root then return nil end

    local okClass, className=pcall(function() return root.ClassName end)
    if okClass and className=="Tool" then
        local okHandle, handle=pcall(function() return root:FindFirstChild("Handle") end)
        if okHandle and handle and getSafeFruitPosition(handle) then return handle end
        local okBasePart, basePart=pcall(function() return root:FindFirstChildWhichIsA("BasePart") end)
        if okBasePart and basePart and getSafeFruitPosition(basePart) then return basePart end
    end

    if getSafeFruitPosition(root) then return root end
    for _, childName in pairs({"Handle", "Fruit"}) do
        local okChild, child=pcall(function() return root:FindFirstChild(childName) end)
        if okChild and child then
            if getSafeFruitPosition(child) then return child end
            local okInner, inner=pcall(function() return child:FindFirstChild("Fruit") end)
            if okInner and inner and getSafeFruitPosition(inner) then return inner end
        end
    end
    local okDesc, descendants=pcall(function() return root:GetDescendants() end)
    if okDesc and descendants then
        for _, descendant in pairs(descendants) do
            if getSafeFruitPosition(descendant) then return descendant end
        end
    end
    return nil
end

function getFruitInstanceKey(part)
    local okAddress, address=pcall(function() return part.Address end)
    if okAddress and address and address~=0 then return "addr:"..tostring(address) end

    local pos=getSafeFruitPosition(part)
    if pos then
        return tostring(part)..":"..tostring(pos.X)..":"..tostring(pos.Y)..":"..tostring(pos.Z)
    end
    return tostring(part)
end

function getWorkspaceFruits()
    local fruits, seen={}, {}
    local okChildren, children=pcall(function() return Workspace:GetChildren() end)
    if not okChildren or not children then return fruits end
    local function addFruit(root, displayName)
        local part=resolveFruitPart(root)
        if not part then return end
        local partPos=getSafeFruitPosition(part)
        if not partPos then return end
        local key=getFruitInstanceKey(part)
        if seen[key] then return end

        for _, existing in pairs(fruits) do
            local existingPos=existing.position or getSafeFruitPosition(existing.part)
            if existingPos then
                local dx=partPos.X-existingPos.X
                local dy=partPos.Y-existingPos.Y
                local dz=partPos.Z-existingPos.Z
                if dx*dx+dy*dy+dz*dz<=9 then return end
            end
        end

        seen[key]=true
        table.insert(fruits, {part=part, position=partPos, name=displayName or "Spawned Fruit"})
    end
    for _, obj in pairs(children) do
        local okName, objName=pcall(function() return obj.Name end)
        objName=(okName and type(objName)=="string") and objName or ""
        local lowerName=string.lower(objName)
        if string.match(lowerName, "fruit") then
            addFruit(obj, objName)
        end

        local okFolder, fruitFolder=pcall(function() return obj:FindFirstChild("Fruit") end)
        if okFolder and fruitFolder then
            local fruitName=(objName~="" and objName~="Fruit" and objName) or "Spawned Fruit"
            addFruit(fruitFolder, fruitName)
        end
    end
    return fruits
end

function buildChamBoxes(fruits)
    fruits=fruits or getWorkspaceFruits()
    local active={}
    local list={}
    for _, fruit in pairs(fruits) do
        local fruitPart=fruit.part
        local key=getFruitInstanceKey(fruitPart)
        local entry=S.chamBoxCache[key]
        if not entry then
            local lines={}
            for _=1,4 do
                local line=newLine(Color3.new(1,0.4,0),2,9)
                if line then table.insert(lines,line) end
            end
            entry={lines=lines, part=fruitPart, key=key}
            S.chamBoxCache[key]=entry
        else
            entry.part=fruitPart
        end
        active[key]=true
        table.insert(list, entry)
    end
    pruneEspCache(S.chamBoxCache, active)
    S.chamBoxes=list
end

function getFruitIslandName(position)
    if not position or type(islandList)~="table" then return "Unknown" end
    local closestName="Unknown"
    local closestDistanceSq=math.huge
    for _,island in pairs(islandList) do
        local islandPosition=island and island.pos or nil
        if islandPosition then
            local dx=position.X-islandPosition.X
            local dz=position.Z-islandPosition.Z
            local distanceSq=dx*dx+dz*dz
            if distanceSq<closestDistanceSq then
                closestDistanceSq=distanceSq
                closestName=island.name or "Unknown"
            end
        end
    end
    if closestDistanceSq>625000000 then return "Sea" end
    return closestName
end

function buildEspLabels(fruits)
    fruits=fruits or getWorkspaceFruits()
    local active={}
    local list={}
    for _, fruit in pairs(fruits) do
        local fruitPart, fruitName=fruit.part, fruit.name
        local fruitPosition=fruit.position or getSafeFruitPosition(fruitPart)
        local displayText=tostring(fruitName).." ["..getFruitIslandName(fruitPosition).."]"
        local key=getFruitInstanceKey(fruitPart)
        local entry=S.espLabelCache[key]
        if not entry then
            entry={label=newText(displayText, Color3.new(0,1,0), 14, 10), part=fruitPart, key=key}
            S.espLabelCache[key]=entry
        else
            setProp(entry.label, "Text", displayText)
            entry.part=fruitPart
        end
        active[key]=true
        table.insert(list, entry)
    end
    pruneEspCache(S.espLabelCache, active)
    S.espLabels=list
end

berryScanRunning=false
BERRY_SCAN_BATCH=80
BERRY_DRAW_DISTANCE=10000
BERRY_DRAW_DISTANCE_SQ=BERRY_DRAW_DISTANCE*BERRY_DRAW_DISTANCE
-- Stability pass (Oct 15 2026): the scan walks the whole Workspace tree and
-- the 1 s builder restarted it as soon as it finished, so with Berry ESP on
-- the script traversed the map continuously. Now a scan starts at most every
-- BERRY_RESCAN_INTERVAL s (the toggle forces one at once), skips the
-- top-level folders that never hold map berries, and stops expanding after
-- BERRY_SCAN_MAX_OBJECTS objects.
BERRY_RESCAN_INTERVAL=15
BERRY_SCAN_MAX_OBJECTS=60000
BERRY_SCAN_SKIP_ROOTS={Enemies=true,Characters=true,Camera=true,Boats=true,ChestModels=true}
berryNextScanAt=0

function isBerryWorldObject(object)
    local current=object
    for _=1,64 do
        if not current then return false end
        local okInfo,parent,className=pcall(function()
            return current.Parent,current.ClassName
        end)
        if not okInfo then return false end
        if className=="Tool" then return false end
        local okHumanoid,humanoid=pcall(function()
            return current:FindFirstChildOfClass("Humanoid")
        end)
        if okHumanoid and humanoid then return false end
        if parent==Workspace then return true end
        current=parent
    end
    return false
end

function buildBerryEspLabels(force)
    if berryScanRunning then
        return
    end
    if not force and clock()<berryNextScanAt then return end

    berryScanRunning=true
    berryNextScanAt=clock()+BERRY_RESCAN_INTERVAL
    local generation=S.berryScanGeneration
    task.spawn(function()
        -- A scan that outlives its toggle (off/on while it is yielded) stops
        -- instead of publishing entries that clearBerryEspLabels already removed.
        local function current()
            return alive() and S.berryEsp and S.berryScanGeneration==generation
        end
        local okScan,scanError=pcall(function()
            local activeEntries={}
            local activeKeys={}
            local publishedKeys={}
            local queue={}
            local queueIndex=1
            local queueCount=0
            local processed=0

            local char=LocalPlayer and LocalPlayer.Character or nil
            local hrp=char and char:FindFirstChild("HumanoidRootPart") or nil
            local okPlayer,playerPos=pcall(function() return hrp and hrp.Position end)

            for _,published in pairs(S.berryEspLabels) do
                if published and published.key then publishedKeys[published.key]=true end
            end

            local okRoots,roots=pcall(function() return Workspace:GetChildren() end)
            if okRoots and roots then
                for _,root in pairs(roots) do
                    local okRootName,rootName=pcall(function() return root.Name end)
                    if not (okRootName and BERRY_SCAN_SKIP_ROOTS[rootName]) then
                        queueCount=queueCount+1
                        queue[queueCount]=root
                    end
                end
            end

            while current() and queueIndex<=queueCount do
                local object=queue[queueIndex]
                -- Drop the reference once taken, so the wrappers of the part of
                -- the tree already scanned can be collected during the scan.
                queue[queueIndex]=nil
                queueIndex=queueIndex+1

                local okName,objectName=pcall(function() return object.Name end)
                local berryName=okName and BERRY_SPHERE_NAMES[objectName] or nil
                if berryName and isBerryWorldObject(object) then
                    local berryPart=object
                    local berryPos=getSafeFruitPosition(berryPart)
                    if not berryPos then
                        local part=nil
                        pcall(function() part=object.PrimaryPart end)
                        if not part then pcall(function() part=object:FindFirstChildWhichIsA("BasePart") end) end
                        if part then
                            berryPart=part
                            berryPos=getSafeFruitPosition(berryPart)
                        end
                    end
                    local inRange=berryPos~=nil
                    if inRange and okPlayer and playerPos then
                        local dx=berryPos.X-playerPos.X
                        local dy=berryPos.Y-playerPos.Y
                        local dz=berryPos.Z-playerPos.Z
                        inRange=(dx*dx+dy*dy+dz*dz)<=BERRY_DRAW_DISTANCE_SQ
                    end

                    if inRange then
                        local key=getFruitInstanceKey(berryPart)
                        local entry=S.berryEspLabelCache[key]
                        if not entry then
                            entry={label=newText(berryName, Color3.new(1,0.35,0.75), 28, 12),part=berryPart,name=berryName,key=key}
                            S.berryEspLabelCache[key]=entry
                        else
                            entry.part=berryPart
                            entry.name=berryName
                            entry.key=key
                        end
                        activeKeys[key]=true
                        table.insert(activeEntries,entry)
                        if not publishedKeys[key] then
                            publishedKeys[key]=true
                            table.insert(S.berryEspLabels,entry)
                        end
                    end
                end

                if queueCount<BERRY_SCAN_MAX_OBJECTS then
                    local okChildren,children=pcall(function() return object:GetChildren() end)
                    if okChildren and children then
                        for _,child in pairs(children) do
                            queueCount=queueCount+1
                            queue[queueCount]=child
                        end
                    end
                end

                processed=processed+1
                if processed>=BERRY_SCAN_BATCH then
                    processed=0
                    frameWait()
                end
            end

            if current() then
                pruneEspCache(S.berryEspLabelCache, activeKeys)
                S.berryEspLabels=activeEntries
            end
        end)
        -- Only the scan of the current generation owns the flag (a quick
        -- off/on clears it and may already have started a newer scan).
        if S.berryScanGeneration==generation then berryScanRunning=false end
        berryNextScanAt=clock()+BERRY_RESCAN_INTERVAL
        if not okScan then warnThrottled("berryScan","[laced.club] Berry scan failed: "..tostring(scanError),30) end
    end)
end

TWEEN_STEP_TIME=FRAME_TIME -- one CFrame write per frame (was 0.01 before the stability pass); safe mode doubles it

-- Lerps the root part to targetPos at `speed` studs/s. Returns true when the
-- target was reached, false when stopped (checkFn false, part gone, unload,
-- or another tween took the root).
--
-- Speed restore + smooth flight (Oct 15 2026). Live symptoms after the
-- stability pass: "the camera bugs out and teleports quickly" and "tweening
-- is causing the character to be flung". Rules now:
--   * exactly one write per frame: CFrame, then Velocity and
--     AssemblyLinearVelocity = 0 (placeRoot, every written frame, no
--     "only when non-zero" or 0.05-stud skip), so physics cannot build up
--     speed between writes and launch the character;
--   * the position is interpolated from a fixed base point and the clock()
--     time since the base (never from the last written position), so a
--     late frame catches up on the straight line and the real speed is
--     `speed` studs/s at any frame rate;
--   * the rotation is captured once (lockedRotation: shared with
--     afq_holdAt and the hard lock while they keep running) and held for
--     the whole flight, so the camera does not turn;
--   * after a pause (CommF_ quiet window) the interpolation is re-based from
--     the root's current position and the current time: no jump on resume;
--   * the tween owns the root (claimRoot token): afq_holdAt, the hard lock,
--     Freeze Position and the void/sky pulls do not write the root while it
--     is in flight; a newer tween takes the root over and this one stops;
--   * on arrival the final CFrame is written with zero velocity for three
--     consecutive frames (the callers then restore CanCollide).
-- The local character's root is re-fetched every step and compared by key:
-- after a death or respawn the old root (possibly freed) is never touched.
function tweenTo(hrp, targetPos, speed, checkFn)
    if not hrp or not targetPos then return false end
    local okStart,startPos=pcall(function() return hrp.Position end)
    if not okStart or not startPos then return false end
    local rootKey=instKey(hrp)
    local isLocalRoot=false
    pcall(function()
        local char=LocalPlayer.Character
        local cur=char and char:FindFirstChild("HumanoidRootPart")
        isLocalRoot=cur~=nil and instKey(cur)==rootKey
    end)
    local rotationCF=isLocalRoot and lockedRotation(hrp) or rootRotation(hrp)
    local function currentPart()
        if not isLocalRoot then
            local okParent,parent=pcall(function() return hrp.Parent end)
            return (okParent and parent) and hrp or nil
        end
        -- Stop when the character left the DataModel (death/respawn) or its
        -- root is no longer the one this tween started with.
        local okCur,cur=pcall(function()
            local char=LocalPlayer.Character
            if not char or not char.Parent then return nil end
            return char:FindFirstChild("HumanoidRootPart")
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
        return placeRoot(hrp,targetPos.X,targetPos.Y,targetPos.Z,rotationCF)
    end
    local moveSpeed=tonumber(speed) or 320
    if moveSpeed<=0 then moveSpeed=320 end
    local token=isLocalRoot and claimRoot() or nil
    local function finish(result)
        if token then releaseRoot(token) end
        return result
    end
    local function ownsRoot()
        if not token then return true end
        if not holdsRoot(token) then return false end
        refreshRoot(token)
        return true
    end
    -- Interpolation base: a fixed point and the time the flight left it.
    local baseX,baseY,baseZ=startPos.X,startPos.Y,startPos.Z
    local duration=distance/moveSpeed
    local baseTime=clock()
    local function rebase()
        local part=currentPart()
        local okPos,pos=pcall(function() return part and part.Position end)
        if okPos and pos and pos.X then baseX,baseY,baseZ=pos.X,pos.Y,pos.Z end
        dx=targetPos.X-baseX; dy=targetPos.Y-baseY; dz=targetPos.Z-baseZ
        duration=math.max(math.sqrt(dx*dx+dy*dy+dz*dz)/moveSpeed,FRAME_TIME)
        baseTime=clock()
    end
    local lastWrite=-1e9
    while keepGoing() do
        if not ownsRoot() then return false end -- a newer tween owns the root
        markTravel() -- a background CommF_ invoke (Auto Stat) waits until the flight is over
        local step=writeInterval(TWEEN_STEP_TIME)
        local now=clock()
        if writesPaused() then
            -- CommF_ quiet window (quietInvoke): no write. Resume from where
            -- the root is when the window closes (no jump back onto the line).
            repeat
                if not ownsRoot() then return false end
                markTravel()
                task.wait(0.05)
            until not writesPaused() or not keepGoing()
            rebase()
        elseif now-lastWrite<step-0.004 then
            -- Write floor: one write per frame (4 ms jitter slack), even when
            -- task.wait resumes early.
            task.wait(step-(now-lastWrite))
        else
            local part=currentPart()
            if not part then return finish(false) end
            local alpha=math.min((now-baseTime)/duration,1)
            if placeRoot(part,baseX+dx*alpha,baseY+dy*alpha,baseZ+dz*alpha,rotationCF) then
                lastWrite=now
                if alpha>=1 then
                    -- Arrival: final CFrame with zero velocity for three
                    -- consecutive frames (this one plus two), then hand over.
                    for _=1,2 do
                        task.wait(step)
                        local last=currentPart()
                        if not last or not ownsRoot() then break end
                        placeRoot(last,targetPos.X,targetPos.Y,targetPos.Z,rotationCF)
                    end
                    return finish(true)
                end
                task.wait(step)
            elseif not writesPaused() then
                return finish(false) -- the root left the DataModel
            end
            -- else: a quiet window began between the check and the write;
            -- the pause branch above handles it on the next pass.
        end
    end
    return finish(false)
end

espFolderSnapshots={}

function trackedInstanceKey(instance)
    return instKey(instance)
end

function trackedSetChanged(snapshotName,current)
    local previous=espFolderSnapshots[snapshotName]
    espFolderSnapshots[snapshotName]=current
    if not previous then return true end
    for key in pairs(current) do
        if not previous[key] then return true end
    end
    for key in pairs(previous) do
        if not current[key] then return true end
    end
    return false
end

function trackedFolderChanged(snapshotName,folder)
    local current={}
    if folder then
        current["folder:"..trackedInstanceKey(folder)]=true
        local okChildren,children=pcall(function() return folder:GetChildren() end)
        if okChildren and children then
            for _,child in pairs(children) do
                current["child:"..trackedInstanceKey(child)]=true
            end
        end
    end
    return trackedSetChanged(snapshotName,current)
end

function trackedFlowersChanged()
    local current={}
    for _,name in ipairs({"Flower1","Flower2"}) do
        local flower=Workspace:FindFirstChild(name)
        if flower then current[name..":"..trackedInstanceKey(flower)]=true end
    end
    return trackedSetChanged("flowers",current)
end

CHEST_ESP_COLORS={
    SilverChest=Color3.fromRGB(165,165,165),
    GoldChest=Color3.fromRGB(255,215,55),
    DiamondChest=Color3.fromRGB(85,205,255),
}

function buildChestEspLabels()
    local active={}
    local list={}
    local chestModels=Workspace:FindFirstChild("ChestModels")
    local okChildren,children=pcall(function() return chestModels and chestModels:GetChildren() end)
    if chestModels and okChildren and children then
        for _,chest in pairs(children) do
            local part=nil
            pcall(function() part=chest:FindFirstChild("RootPart") or chest:FindFirstChildWhichIsA("BasePart") end)
            local okPos,pos=pcall(function() return part and part.Position end)
            if okPos and pos and pos.X and pos.Y and pos.Z then
                local key=getFruitInstanceKey(part)
                local okName,chestName=pcall(function() return chest.Name end)
                chestName=(okName and type(chestName)=="string" and chestName~="") and chestName or "Chest"
                local chestColor=CHEST_ESP_COLORS[chestName] or Color3.fromRGB(235,235,235)
                local entry=S.chestEspLabelCache[key]
                if not entry then
                    entry={label=newText(chestName, chestColor, 14, 10),part=part,name=chestName,key=key}
                    S.chestEspLabelCache[key]=entry
                else
                    entry.part=part
                    entry.name=chestName
                    setProp(entry.label,"Text",chestName)
                    setProp(entry.label,"Color",chestColor)
                end
                active[key]=true
                table.insert(list,entry)
            end
        end
    end
    -- Chests that despawned lose their label for good (the cache used to grow forever).
    pruneEspCache(S.chestEspLabelCache, active)
    S.chestEspLabels=list
end

function getBoatEspKey(boat)
    return "boat:"..instKey(boat)
end

function getBoatEspParts(boat)
    local parts={}
    local okBase,isBase=pcall(function() return isA(boat,"BasePart") end)
    if okBase and isBase==true then table.insert(parts,boat) end
    local okDescendants,descendants=pcall(function() return boat:GetDescendants() end)
    if okDescendants and descendants then
        for _,object in pairs(descendants) do
            local okPart,isPart=pcall(function() return isA(object,"BasePart") end)
            if okPart and isPart==true then table.insert(parts,object) end
        end
    end
    return parts
end

function getBoatEspBounds(parts)
    local minX,minY,minZ=math.huge,math.huge,math.huge
    local maxX,maxY,maxZ=-math.huge,-math.huge,-math.huge
    local found=false
    for _,part in pairs(parts or {}) do
        local okParent,parent=pcall(function() return part.Parent end)
        local okData,pos,size=pcall(function() return part.Position,part.Size end)
        if okParent and parent and okData and pos and size then
            local halfX,halfY,halfZ=size.X/2,size.Y/2,size.Z/2
            if pos.X-halfX<minX then minX=pos.X-halfX end
            if pos.Y-halfY<minY then minY=pos.Y-halfY end
            if pos.Z-halfZ<minZ then minZ=pos.Z-halfZ end
            if pos.X+halfX>maxX then maxX=pos.X+halfX end
            if pos.Y+halfY>maxY then maxY=pos.Y+halfY end
            if pos.Z+halfZ>maxZ then maxZ=pos.Z+halfZ end
            found=true
        end
    end
    if not found then return nil end
    return minX,minY,minZ,maxX,maxY,maxZ
end

-- Shared by boat and flower ESP (they were copy-pasted builders).
function boxBoundsRelativeTo(parts,anchor)
    local minX,minY,minZ,maxX,maxY,maxZ=getBoatEspBounds(parts)
    local okAnchor,anchorPos=pcall(function() return anchor and anchor.Position end)
    if not anchor or not minX or not okAnchor or not anchorPos then return nil end
    return {
        minX=minX-anchorPos.X,minY=minY-anchorPos.Y,minZ=minZ-anchorPos.Z,
        maxX=maxX-anchorPos.X,maxY=maxY-anchorPos.Y,maxZ=maxZ-anchorPos.Z,
    }
end

function upsertBoxEntry(cache,key,lineColor,labelText,labelColor)
    local entry=cache[key]
    if not entry then
        local lines={}
        for _=1,12 do
            local line=newLine(lineColor,2,10)
            if line then table.insert(lines,line) end
        end
        entry={lines=lines,label=newText(labelText,labelColor,18,11),key=key}
        cache[key]=entry
    else
        setProp(entry.label,"Text",labelText)
        setProp(entry.label,"Color",labelColor)
        for _,line in pairs(entry.lines) do setProp(line,"Color",lineColor) end
    end
    entry.name=labelText
    return entry
end

function buildBoatEsp()
    local active={}
    local list={}
    local boats=Workspace:FindFirstChild("Boats")
    local okChildren,children=pcall(function() return boats and boats:GetChildren() end)
    if boats and okChildren and children then
        for _,boat in pairs(children) do
            local parts=getBoatEspParts(boat)
            if #parts>0 then
                local anchor=nil
                pcall(function() anchor=boat.PrimaryPart end)
                if not anchor then
                    for _,part in pairs(parts) do
                        local okClass,className=pcall(function() return part.ClassName end)
                        if okClass and className=="VehicleSeat" then anchor=part; break end
                    end
                end
                if not anchor then anchor=parts[1] end

                local bounds=boxBoundsRelativeTo(parts,anchor)
                if bounds then
                    local key=getBoatEspKey(boat)
                    local okName,boatName=pcall(function() return boat.Name end)
                    boatName=(okName and type(boatName)=="string" and boatName~="") and boatName or "Boat"
                    local entry=upsertBoxEntry(S.boatEspCache,key,Color3.fromRGB(40,190,255),boatName,Color3.fromRGB(90,215,255))
                    entry.boat=boat
                    entry.anchor=anchor
                    entry.bounds=bounds
                    active[key]=true
                    table.insert(list,entry)
                end
            end
        end
    end
    pruneEspCache(S.boatEspCache, active)
    S.boatEspEntries=list
end

FLOWER_ESP_TARGETS={
    {workspaceName="Flower1",label="Blue Flower",color=Color3.fromRGB(55,145,255)},
    {workspaceName="Flower2",label="Red Flower",color=Color3.fromRGB(255,65,65)},
}

function getFlowerEspKey(flowerName,flower)
    return "flower:"..flowerName..":"..instKey(flower)
end

function buildFlowerEsp()
    local active={}
    local list={}
    for _,target in ipairs(FLOWER_ESP_TARGETS) do
        local flower=Workspace:FindFirstChild(target.workspaceName)
        if flower then
            local parts=getBoatEspParts(flower)
            if #parts>0 then
                local anchor=nil
                local okPrimary,primary=pcall(function() return flower.PrimaryPart end)
                if okPrimary and primary then anchor=primary end
                if not anchor then anchor=parts[1] end

                local bounds=boxBoundsRelativeTo(parts,anchor)
                if bounds then
                    local key=getFlowerEspKey(target.workspaceName,flower)
                    local entry=upsertBoxEntry(S.flowerEspCache,key,target.color,target.label,target.color)
                    entry.flower=flower
                    entry.anchor=anchor
                    entry.bounds=bounds
                    active[key]=true
                    table.insert(list,entry)
                end
            end
        end
    end
    pruneEspCache(S.flowerEspCache, active)
    S.flowerEspEntries=list
end

ESP_BOX_EDGES={
    {1,2},{2,4},{4,3},{3,1},
    {5,6},{6,8},{8,7},{7,5},
    {1,5},{2,6},{3,7},{4,8},
}

function updateWorldBoxEntry(entry)
    if not entry or entry.removed then return end
    local visible=false
    local okAnchor,anchorParent,anchorPos=pcall(function()
        return entry.anchor and entry.anchor.Parent,entry.anchor and entry.anchor.Position
    end)
    local bounds=entry.bounds
    if okAnchor and anchorParent and anchorPos and bounds and #entry.lines>=#ESP_BOX_EDGES then
        local minX=anchorPos.X+bounds.minX
        local minY=anchorPos.Y+bounds.minY
        local minZ=anchorPos.Z+bounds.minZ
        local maxX=anchorPos.X+bounds.maxX
        local maxY=anchorPos.Y+bounds.maxY
        local maxZ=anchorPos.Z+bounds.maxZ
        local corners=entry.worldCorners or {}
        entry.worldCorners=corners
        corners[1]=Vector3.new(minX,minY,minZ)
        corners[2]=Vector3.new(maxX,minY,minZ)
        corners[3]=Vector3.new(minX,maxY,minZ)
        corners[4]=Vector3.new(maxX,maxY,minZ)
        corners[5]=Vector3.new(minX,minY,maxZ)
        corners[6]=Vector3.new(maxX,minY,maxZ)
        corners[7]=Vector3.new(minX,maxY,maxZ)
        corners[8]=Vector3.new(maxX,maxY,maxZ)

        local screenPoints=entry.screenPoints or {}
        entry.screenPoints=screenPoints
        local screenMinX,screenMinY=math.huge,math.huge
        local screenMaxX=-math.huge
        local projectedCount=0
        for index=1,8 do
            local okScreen,screenPos,onScreen=pcall(WorldToScreen,corners[index])
            if okScreen and screenPos and onScreen==true then
                screenPoints[index]=screenPos
                projectedCount=projectedCount+1
                if screenPos.X<screenMinX then screenMinX=screenPos.X end
                if screenPos.Y<screenMinY then screenMinY=screenPos.Y end
                if screenPos.X>screenMaxX then screenMaxX=screenPos.X end
            else
                break
            end
        end

        if projectedCount==8 then
            for index,edge in ipairs(ESP_BOX_EDGES) do
                entry.lines[index].From=screenPoints[edge[1]]
                entry.lines[index].To=screenPoints[edge[2]]
            end
            if entry.label then
                entry.label.Position=Vector2.new((screenMinX+screenMaxX)/2,screenMinY-20)
            end
            visible=true
        end
    end

    setEntryVisible(entry,visible)
end

-- Positions a Text label over its part; hides it when the part is gone, out
-- of range, or WorldToScreen reports it off-screen.
function renderLabelEntry(entry,playerPos,maxDistanceSq,yOffset)
    if not entry or entry.removed or not entry.label then return end
    local part=entry.part
    local visible=false
    local okInfo,parent,pos=pcall(function() return part and part.Parent,part and part.Position end)
    if okInfo and parent and pos and playerPos then
        local inRange=true
        if maxDistanceSq then
            local dx=pos.X-playerPos.X
            local dy=pos.Y-playerPos.Y
            local dz=pos.Z-playerPos.Z
            inRange=(dx*dx+dy*dy+dz*dz)<=maxDistanceSq
        end
        if inRange then
            local okScreen,screenPos,onScreen=pcall(WorldToScreen,pos)
            if okScreen and screenPos and onScreen==true then
                entry.label.Position=Vector2.new(screenPos.X,screenPos.Y-yOffset)
                visible=true
            end
        end
    end
    entry.label.Visible=visible
end

-- 2D box around a fruit. Only corners WorldToScreen reports on-screen are
-- used: off-screen corners come back as (0,0) and used to stretch the box to
-- the top-left of the screen.
function renderChamEntry(entry,playerPos)
    if not entry or entry.removed or #entry.lines<4 then return end
    local part=entry.part
    local okInfo,parent,pos,size=pcall(function() return part.Parent,part.Position,part.Size end)
    if not okInfo or not parent or not pos or not size or not playerPos then
        setEntryVisible(entry,false)
        return
    end
    local sx,sy,sz=size.X*0.5,size.Y*0.5,size.Z*0.5
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
    local projected=0
    for ix=-1,1,2 do
        for iy=-1,1,2 do
            for iz=-1,1,2 do
                local corner=Vector3.new(pos.X+sx*ix,pos.Y+sy*iy,pos.Z+sz*iz)
                local okScreen,screenPos,onScreen=pcall(WorldToScreen,corner)
                if okScreen and screenPos and onScreen==true then
                    projected=projected+1
                    if screenPos.X<minX then minX=screenPos.X end
                    if screenPos.Y<minY then minY=screenPos.Y end
                    if screenPos.X>maxX then maxX=screenPos.X end
                    if screenPos.Y>maxY then maxY=screenPos.Y end
                end
            end
        end
    end
    if projected==0 then
        setEntryVisible(entry,false)
        return
    end
    local lines=entry.lines
    lines[1].From=Vector2.new(minX,minY); lines[1].To=Vector2.new(maxX,minY)
    lines[2].From=Vector2.new(minX,maxY); lines[2].To=Vector2.new(maxX,maxY)
    lines[3].From=Vector2.new(minX,minY); lines[3].To=Vector2.new(minX,maxY)
    lines[4].From=Vector2.new(maxX,minY); lines[4].To=Vector2.new(maxX,maxY)
    setEntryVisible(entry,true)
end

-- Load marker: this chunk ran to the end.
if LACED_LOAD and type(LACED_LOAD.done) == "table" then LACED_LOAD.done["30_esp"] = true end
