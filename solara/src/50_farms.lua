-- @chunk 50_farms  (lines 4275-5015 of the single-file build)
local LACED_LOAD = type(getgenv().__lacedLoad) == "table" and getgenv().__lacedLoad or nil -- load marker (loader.lua)
if LACED_LOAD and type(LACED_LOAD.started) == "table" then LACED_LOAD.started["50_farms"] = true end
-- Per-execution bindings: captured at chunk load so a re-run of the script
-- cannot make this copy's loops read the new copy's state (alive is a
-- closure over this run's state since the Oct 15 stability pass).
local alive = alive
local SCRIPT_STATE = SCRIPT_STATE
local S = S
local AFL = AFL
function getChestType(chest)
    local okName,name=pcall(function() return chest and chest.Name end)
    if not okName or type(name)~="string" then return "Other" end
    local lowerName=string.lower(name)
    if string.match(lowerName,"diamond") then return "Diamond" end
    if string.match(lowerName,"gold") then return "Gold" end
    if string.match(lowerName,"silver") then return "Silver" end
    return "Other"
end

function getChestPriorityRank(chestType)
    for rank,name in ipairs(S.chestPriority) do
        if name==chestType then return rank end
    end
    return #S.chestPriority+1
end

function getPriorityChest(children,hrp)
    if not children or not hrp then return nil,nil,nil end
    local okPlayer,playerPos=pcall(function() return hrp.Position end)
    if not okPlayer or not playerPos then return nil,nil,nil end

    local activeKeys={}
    for _,chest in pairs(children) do
        activeKeys[trackedInstanceKey(chest)]=true
    end
    for key in pairs(S.handledChests) do
        if not activeKeys[key] then S.handledChests[key]=nil end
    end

    local bestChest,bestPart,bestType=nil,nil,nil
    local bestRank,bestDistance=math.huge,math.huge
    for _,chest in pairs(children) do
        local chestKey=trackedInstanceKey(chest)
        local part=chest and (chest:FindFirstChild("RootPart") or chest:FindFirstChildWhichIsA("BasePart")) or nil
        local okParent,parent=pcall(function() return chest and chest.Parent end)
        local okPos,pos=pcall(function() return part and part.Position end)
        if not S.handledChests[chestKey] and okParent and parent and okPos and pos then
            local chestType=getChestType(chest)
            local rank=getChestPriorityRank(chestType)
            local dx=pos.X-playerPos.X
            local dy=pos.Y-playerPos.Y
            local dz=pos.Z-playerPos.Z
            local distanceSq=dx*dx+dy*dy+dz*dz
            if rank<bestRank or (rank==bestRank and distanceSq<bestDistance) then
                bestChest,bestPart,bestType=chest,part,chestType
                bestRank,bestDistance=rank,distanceSq
            end
        end
    end
    return bestChest,bestPart,bestType
end

task.spawn(function()
    -- An unreachable chest (tween never ends within 2 studs) is given up after
    -- three tries instead of being picked again every 0.25 s forever.
    local chestTries={}
    while alive() do
        if S.autoFarming and not farmPriorityBlocked() then
            local reachedChest=false
            local ChestModels=Workspace:FindFirstChild("ChestModels")
            if ChestModels then
                local okChildren,children=pcall(function() return ChestModels:GetChildren() end)
                local char=LocalPlayer.Character
                local hrp=char and char:FindFirstChild("HumanoidRootPart") or nil
                if okChildren and children and hrp then
                    local okPick,chest,part,chestType=pcall(getPriorityChest,children,hrp)
                    if not okPick then chest,part,chestType=nil,nil,nil end
                    local okPos,pos=pcall(function() return part and part.Position end)
                    if chest and part and okPos and pos then
                        notify("Going to "..chestType.." chest","laced.club",2)
                        local destination=Vector3.new(pos.X,pos.Y+3,pos.Z)
                        tweenTo(hrp,destination,S.CHEST_SPEED,function()
                            local okChest,chestParent=pcall(function() return chest.Parent end)
                            local okPart,partParent=pcall(function() return part.Parent end)
                            return S.autoFarming and not farmPriorityBlocked()
                                and okChest and chestParent~=nil and okPart and partParent~=nil
                        end)
                        local okArrival,currentPos=pcall(function() return hrp.Position end)
                        if okArrival and currentPos then
                            local dx=currentPos.X-destination.X
                            local dy=currentPos.Y-destination.Y
                            local dz=currentPos.Z-destination.Z
                            local chestKey=trackedInstanceKey(chest)
                            if dx*dx+dy*dy+dz*dz<=4 then
                                S.handledChests[chestKey]=true
                                chestTries[chestKey]=nil
                                reachedChest=true
                            elseif S.autoFarming and not farmPriorityBlocked() then
                                chestTries[chestKey]=(chestTries[chestKey] or 0)+1
                                if chestTries[chestKey]>=3 then S.handledChests[chestKey]=true; chestTries[chestKey]=nil end
                            end
                        end
                    end
                end
            end
            if reachedChest then frameWait() else task.wait(0.25) end
        else task.wait(0.1) end
    end
end)

function getCurrentlyHeldTool()
    local char=LocalPlayer.Character
    if not char then return nil end
    for _,child in pairs(char:GetChildren()) do
        local okClass, className=pcall(function() return child.ClassName end)
        if okClass and className=="Tool" then
            return child
        end
    end
    return nil
end

-- Hotbar order lives in the game's PlayerGui.Backpack.LocalScriptB (custom
-- backpack; it disables Enum.CoreGuiType.Backpack). Each hotbar slot is a
-- PlayerGui.Backpack.Hotbar.Container.Template frame whose Number.Text is the
-- key label ("1".."9","0") and whose "ItemName" attribute is the tool's Name
-- (April Fools fruits: "Plastic <name>"). The client equips with
-- Humanoid:EquipTool, which Matcha does not bind.
WeaponEquip = {
    vk = { [0] = 0x30, [1] = 0x31, [2] = 0x32, [3] = 0x33, [4] = 0x34,
           [5] = 0x35, [6] = 0x36, [7] = 0x37, [8] = 0x38, [9] = 0x39 },
    -- Fallback when the hotbar cannot be read: the slot's usual weapon type first.
    typeOrder = {
        [1] = { "Melee", "Sword", "Demon Fruit" },
        [2] = { "Demon Fruit", "Melee", "Sword" },
        [3] = { "Sword", "Melee", "Demon Fruit" },
    },
    defaultTypeOrder = { "Melee", "Sword", "Demon Fruit" },
    -- Live-tested 2026-10-15: a Matcha `tool.Parent = Character` write does
    -- NOT reparent. Parent reads back as the new value, but the Character's and
    -- Backpack's child lists do not change, so the game (local or server) never
    -- sees an equip. Off by default; the key route is the only one that equips.
    parentSwap = false,
    lastToolName = nil,
    lastRoute = "none",
}

function WeaponEquip.slotNumber(slot)
    local n = tonumber(slot) or tonumber(S.weaponSlot) or 1
    return math.floor(n) % 10
end

function WeaponEquip.key(slot)
    return WeaponEquip.vk[WeaponEquip.slotNumber(slot)] or 0x31
end

function WeaponEquip.focused()
    if type(isrbxactive) ~= "function" then return true end
    local okActive, active = pcall(isrbxactive)
    return not (okActive and active == false)
end

-- Tool name in the given hotbar slot, read from the game's own hotbar GUI.
-- Live 2026-10-15: through Matcha, GetAttribute("ItemName") returned the name
-- only on the frame of the tool currently held (slot 2 "Ice-Ice"); the other
-- slots' frames read nil although LocalScriptB sets the attribute on every
-- frame. So this usually returns nil and pickTool falls through to the last
-- held tool, then the WeaponType order.
function WeaponEquip.hotbarName(slot)
    local want = tostring(WeaponEquip.slotNumber(slot))
    local found = nil
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local gui = pg and pg:FindFirstChild("Backpack")
        local hotbar = gui and gui:FindFirstChild("Hotbar")
        local container = hotbar and hotbar:FindFirstChild("Container")
        if not container then return end
        for _, frame in ipairs(container:GetChildren()) do
            if frame.Name == "Template" then
                local number = frame:FindFirstChild("Number")
                if number and number.Text == want then
                    local item = frame:GetAttribute("ItemName")
                    if type(item) == "string" and item ~= "" then
                        found = item
                        return
                    end
                end
            end
        end
    end)
    return found
end

-- Backpack tool for the slot: hotbar name, then the last tool seen held,
-- then the first Backpack tool whose WeaponType attribute fits the slot.
function WeaponEquip.pickTool(slot)
    local backpack = LocalPlayer and LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return nil, "no backpack" end
    local function byName(name)
        if type(name) ~= "string" or name == "" then return nil end
        local okTool, tool = pcall(function() return backpack:FindFirstChild(name) end)
        if okTool and tool and tool.ClassName == "Tool" then return tool end
        return nil
    end
    local hotbar = WeaponEquip.hotbarName(slot)
    local tool = byName(hotbar)
    if not tool and hotbar then tool = byName((string.gsub(hotbar, "^Plastic ", ""))) end
    if tool then return tool, "hotbar" end
    tool = byName(WeaponEquip.lastToolName)
    if tool then return tool, "last held" end
    local okKids, kids = pcall(function() return backpack:GetChildren() end)
    if okKids and kids then
        local order = WeaponEquip.typeOrder[WeaponEquip.slotNumber(slot)] or WeaponEquip.defaultTypeOrder
        for _, wanted in ipairs(order) do
            for _, child in ipairs(kids) do
                local okInfo, isTool, weaponType = pcall(function()
                    return child.ClassName == "Tool", child:GetAttribute("WeaponType")
                end)
                if okInfo and isTool and weaponType == wanted then return child, "type " .. wanted end
            end
        end
    end
    return nil, "none"
end

-- Key route only. Never sends a key while Roblox is not the foreground window
-- (the injected key would go to whatever app has focus).
function pressWeaponSlot(slot)
    if not WeaponEquip.focused() then return getCurrentlyHeldTool() ~= nil end
    local selectedKey = WeaponEquip.key(slot)
    pcall(function()
        keyrelease(selectedKey)
        task.wait(0.02)
        keypress(selectedKey)
        task.wait(0.1)
        keyrelease(selectedKey)
    end)
    local equipped = getCurrentlyHeldTool() ~= nil
    if equipped then WeaponEquip.lastRoute = "key" end
    return equipped
end

-- Equip the weapon for S.weaponSlot (or slot). Live-tested 2026-10-15: the
-- parent-swap route (tool.Parent = Character) does nothing useful in Matcha.
-- The write succeeds and Parent reads back as the Character, but
-- Character:GetChildren() / Backpack:GetChildren() are unchanged, the hotbar
-- does not react and getCurrentlyHeldTool() still returns the old tool (or
-- nil), so the route can never report success. It stays behind
-- WeaponEquip.parentSwap (default false) and should not be re-enabled.
-- Equipping therefore needs the key press, which needs Roblox focused; with
-- Roblox unfocused and no tool held, the remote M1 (requireTool) idles until
-- the player equips a weapon. Note: the remote M1 landed with a fruit
-- (Ice-Ice) held, so any held tool satisfies the server.
function equipWeaponSlot(slot)
    slot = WeaponEquip.slotNumber(slot)
    local held = getCurrentlyHeldTool()
    if held then
        pcall(function() WeaponEquip.lastToolName = held.Name end)
        return true
    end
    if WeaponEquip.parentSwap then
        local char = LocalPlayer and LocalPlayer.Character
        local tool, how = WeaponEquip.pickTool(slot)
        if tool and char then
            local okSwap = pcall(function() tool.Parent = char end)
            if okSwap then
                task.wait(0.1)
                local now = getCurrentlyHeldTool()
                local okName, same = pcall(function() return now ~= nil and now.Name == tool.Name end)
                if okName and same then
                    WeaponEquip.lastToolName = tool.Name
                    WeaponEquip.lastRoute = "parent (" .. how .. ")"
                    return true
                end
            end
        end
    end
    return pressWeaponSlot(slot)
end

function restoreHeldTool(rememberedTool, toolName)

    local char=LocalPlayer and LocalPlayer.Character or nil
    local backpack=LocalPlayer and LocalPlayer:FindFirstChild("Backpack") or nil
    local hum=char and char:FindFirstChildOfClass("Humanoid") or nil
    local tool=nil

    if rememberedTool then
        local okTool, isTool=pcall(function() return isA(rememberedTool,"Tool") end)
        local okParent, parent=pcall(function() return rememberedTool.Parent end)
        if okTool and isTool and okParent and parent and (parent==char or parent==backpack) then
            tool=rememberedTool
        end
    end

    if not tool and toolName then
        local charTool=char and char:FindFirstChild(toolName) or nil
        local backpackTool=backpack and backpack:FindFirstChild(toolName) or nil
        if charTool and isA(charTool,"Tool") then
            tool=charTool
        elseif backpackTool and isA(backpackTool,"Tool") then
            tool=backpackTool
        end
    end

    if tool and char then
        local equipped=false
        if hum then
            local okEquip=pcall(function() hum:EquipTool(tool) end)
            if okEquip then
                local okParent, parent=pcall(function() return tool.Parent end)
                equipped=okParent and parent==char
            end
        end

        if not equipped then
            pcall(function() tool.Parent=char end)
        end
    end

end

function partStillThere(part)
    if not part then return false end
    local okParent,parent=pcall(function() return part.Parent end)
    return okParent and parent~=nil
end

task.spawn(function()
    -- A fruit still there after a full collect attempt is skipped for 60 s, so
    -- it cannot hold the priority flag (which pauses every other farm) in a
    -- 3 s loop forever.
    local fruitBlock={}
    while alive() do
        if S.autoFruits then
            local okStep,stepError=pcall(function()
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local bestPart, bestDist=nil, math.huge
                local okHrp, hrpPos=pcall(function() return hrp.Position end)
                if okHrp and hrpPos and hrpPos.X and hrpPos.Y and hrpPos.Z then
                    local now=clock()
                    for key,untilAt in pairs(fruitBlock) do if now>=untilAt then fruitBlock[key]=nil end end
                    for _, fruit in pairs(getWorkspaceFruits()) do
                        local fp, fpPos=fruit.part, getSafeFruitPosition(fruit.part)
                        if fp and fpPos and not fruitBlock[getFruitInstanceKey(fp)] then
                            local dx=fpPos.X-hrpPos.X
                            local dy=fpPos.Y-hrpPos.Y
                            local dz=fpPos.Z-hrpPos.Z
                            local dist=math.sqrt(dx*dx+dy*dy+dz*dz)
                            if dist<bestDist then bestDist=dist; bestPart=fp end
                        end
                    end
                end
                if bestPart then

                    S.fruitPriorityActive=true

                    notify("Farming fruit...","laced.club",1)
                    local okTarget, fruitPos=pcall(function() return bestPart.Position end)
                    local arrived=false
                    if okTarget and fruitPos and fruitPos.X and fruitPos.Y and fruitPos.Z then
                        tweenTo(hrp, Vector3.new(fruitPos.X,fruitPos.Y+3,fruitPos.Z), S.FRUIT_SPEED, function()
                            return S.autoFruits and partStillThere(bestPart)
                        end)
                        arrived=true
                    end

                    if arrived and S.autoFruits then
                        task.wait(1)
                        if alive() and S.autoFruits then equipWeaponSlot(S.weaponSlot) end
                    end

                    local fruitWaitStart=clock()
                    while alive() and S.autoFruits and partStillThere(bestPart) and clock()-fruitWaitStart<3 do
                        task.wait(0.05)
                    end
                    if alive() and S.autoFruits and partStillThere(bestPart) then
                        fruitBlock[getFruitInstanceKey(bestPart)]=clock()+60
                    end
                end
            end
            end)
            -- Always release the priority lock, even when the step failed.
            S.fruitPriorityActive=false
            if not okStep then warnThrottled("fruitFarm","[laced.club] Fruit farm step failed: "..tostring(stepError),15) end
            task.wait(0.1)
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    local equipping=false
    -- Bounded retry: after 5 failed attempts in a row (empty slot, lost tool)
    -- one attempt every 5 s instead of a key tap every ~0.4 s.
    local failures=0
    local nextTry=0
    while alive() do
        local farming=S.autoFarmNearest or S.autoNpcFarm or S.autoFarmLevel or S.autoRaid or S.autoBossFarm or S.autoMaterialFarm or S.autoSeaEvent
            or S.autoFarmQuest or S.dungeonEnabled or S.autoMastery
        if not farming then failures=0 end
        -- One equip attempt at a time: overlapping key taps toggle the tool back off.
        if farming and not equipping and clock()>=nextTry and not getCurrentlyHeldTool() then
            local selectedSlot=S.weaponSlot
            equipping=true
            task.spawn(function()
                local okEquip,equipped=pcall(equipWeaponSlot,selectedSlot)
                if okEquip and equipped then failures=0 else failures=failures+1 end
                if failures>=5 then nextTry=clock()+5 end
                equipping=false
            end)
        end
        task.wait(0.25)
    end
end)

task.spawn(function()
    while alive() do
        if S.autoFarmNearest and not farmPriorityBlocked() then
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if hrp then

                local useRemote=S.remoteMode
                local fought=farmAttack(
                    hrp,
                    function()
                        return S.autoFarmNearest and S.remoteMode==useRemote and not farmPriorityBlocked()
                    end,
                    nil,
                    true,
                    1000,
                    useRemote and remoteAttack or nil,
                    useRemote and 0.05 or 0.06
                )
                -- Speed restore: next target one frame after a fight (0.1 s
                -- only when nothing was in range).
                if fought then frameWait() else task.wait(0.1) end
            else
                task.wait(0.1)
            end
        else task.wait(0.1) end
    end
end)

task.spawn(function()
    while alive() do
        if S.autoNpcFarm and not farmPriorityBlocked() then
            local okStep,stepError=pcall(function()
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            local island=islandList[S.selectedIsland] or islandList[1]
            if hrp and island then
                local ip=island.pos
                notify("NPC Farm: going to "..tostring(island.name),"laced.club",2)
                tweenTo(hrp, Vector3.new(ip.X,ip.Y,ip.Z), S.NPC_TWEEN_SPEED, function() return S.autoNpcFarm and not farmPriorityBlocked() end)
                task.wait(0.5)
                -- Same parts as before (every BasePart child of the character);
                -- restored below when the farm stops (it used to stay off).
                afl_setCanCollide(false)
                while alive() and S.autoNpcFarm and not farmPriorityBlocked() do
                    local hrp2=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if not hrp2 then task.wait(0.1); break end

                    -- Remote and click mode share farmAttack (the remote branch was a
                    -- hand-copied duplicate of it).
                    local useRemote=S.remoteMode
                    local fought=farmAttack(hrp2, function()
                        return S.autoNpcFarm and S.remoteMode==useRemote and not farmPriorityBlocked()
                    end, nil, true, 1000, useRemote and remoteAttack or nil, useRemote and 0.05 or 0.06)
                    -- Speed restore: next target one frame after a fight.
                    if fought then frameWait() else task.wait(0.1) end
                end
            end
            end)
            if S.collisionOff then pcall(afl_setCanCollide,true) end
            if not okStep then warnThrottled("npcFarm","[laced.club] NPC farm step failed: "..tostring(stepError),15) end
            task.wait(0.1)
        else task.wait(0.1) end
    end
end)

function afl_loadQuestData()
    AFL.questData={}
    if AFL.currentSea==1 then
        AFL.questData.Sea1First={enemy="Trainee",questButton=1,ammountToKill=5}
        AFL.questData.Jungle1={enemy="Monkey",questButton=1,ammountToKill=6}
        AFL.questData.Jungle2={enemy="Gorilla",questButton=2,ammountToKill=8}
        AFL.questData.PirateVillage1={enemy="Pirate",questButton=1,ammountToKill=8}
        AFL.questData.PirateVillage2={enemy="Brute",questButton=2,ammountToKill=8}
        AFL.questData.DesertIsland1={enemy="Desert Bandit",questButton=1,ammountToKill=8}
        AFL.questData.DesertIsland2={enemy="Desert Officer",questButton=2,ammountToKill=6}
        AFL.questData.WinterIsland1={enemy="Snow Bandit",questButton=1,ammountToKill=7}
        AFL.questData.WinterIsland2={enemy="Snowman",questButton=2,ammountToKill=8}
        AFL.questData.MarineFortress={enemy="Chief Petty Officer",questButton=1,ammountToKill=8}
        AFL.questData.SkyIsland1={enemy="Sky Bandit",questButton=1,ammountToKill=7}
        AFL.questData.SkyIsland2={enemy="Dark Master",questButton=2,ammountToKill=8}
        AFL.questData.PrisonIsland1={enemy="Prisoner",questButton=1,ammountToKill=8}
        AFL.questData.PrisonIsland2={enemy="Dangerous Prisoner",questButton=2,ammountToKill=8}
        AFL.questData.ColosseumIsland1={enemy="Toga Warrior",questButton=1,ammountToKill=7}
        AFL.questData.ColosseumIsland2={enemy="Gladiator",questButton=2,ammountToKill=8}
        AFL.questData.MagmaIsland1={enemy="Military Soldier",questButton=1,ammountToKill=7}
        AFL.questData.MagmaIsland2={enemy="Military Spy",questButton=2,ammountToKill=8}
        AFL.questData.UnderWaterIsland1={enemy="Fishman Warrior",questButton=1,ammountToKill=8}
        AFL.questData.UnderWaterIsland2={enemy="Fishman Commando",questButton=2,ammountToKill=7}
        AFL.questData.SkyIsland3={enemy="God's Guard",questButton=1,ammountToKill=7}
        AFL.questData.SkyIsland4={enemy="Shanda",questButton=2,ammountToKill=9}
        AFL.questData.SkyIsland5={enemy="Royal Squad",questButton=1,ammountToKill=8}
        AFL.questData.SkyIsland6={enemy="Royal Soldier",questButton=2,ammountToKill=8}
        AFL.questData.FountainIsland1={enemy="Galley Pirate",questButton=1,ammountToKill=8}
        AFL.questData.FountainIsland2={enemy="Galley Captain",questButton=2,ammountToKill=9}
    elseif AFL.currentSea==2 then
        AFL.questData.RoseKingdom1={enemy="Raider",questButton=1,ammountToKill=8}
        AFL.questData.RoseKingdom2={enemy="Mercenary",questButton=2,ammountToKill=8}
        AFL.questData.Factory1={enemy="Swan Pirate",questButton=1,ammountToKill=8}
        AFL.questData.Factory2={enemy="Factory Staff",questButton=2,ammountToKill=8}
        AFL.questData.GreenZone1={enemy="Marine Lieutenant",questButton=1,ammountToKill=8}
        AFL.questData.GreenZone2={enemy="Marine Captain",questButton=2,ammountToKill=9}
        AFL.questData.Graveyard1={enemy="Zombie",questButton=1,ammountToKill=8}
        AFL.questData.Graveyard2={enemy="Vampire",questButton=2,ammountToKill=8}
        AFL.questData.Snow1={enemy="Snow Trooper",questButton=1,ammountToKill=8}
        AFL.questData.Snow2={enemy="Winter Warrior",questButton=2,ammountToKill=9}
        AFL.questData.ColdSide1={enemy="Lab Subordinate",questButton=1,ammountToKill=8}
        AFL.questData.ColdSide2={enemy="Horned Warrior",questButton=2,ammountToKill=9}
        AFL.questData.HotSide1={enemy="Magma Ninja",questButton=1,ammountToKill=8}
        AFL.questData.HotSide2={enemy="Lava Pirate",questButton=2,ammountToKill=8}
        AFL.questData.HauntedShip1={enemy="Ship Deckhand",questButton=1,ammountToKill=8}
        AFL.questData.HauntedShip2={enemy="Ship Engineer",questButton=2,ammountToKill=8}
        AFL.questData.HauntedShip3={enemy="Ship Steward",questButton=1,ammountToKill=8}
        AFL.questData.HauntedShip4={enemy="Ship Officer",questButton=2,ammountToKill=8}
        AFL.questData.WinterCastle1={enemy="Arctic Warrior",questButton=1,ammountToKill=8}
        AFL.questData.WinterCastle2={enemy="Snow Lurker",questButton=2,ammountToKill=8}
        AFL.questData.Wano1={enemy="Sea Soldier",questButton=1,ammountToKill=8}
        AFL.questData.Wano2={enemy="Water Fighter",questButton=2,ammountToKill=8}
    elseif AFL.currentSea==3 then
        AFL.questData.Port1={enemy="Pirate Millionaire",questButton=1,ammountToKill=8}
        AFL.questData.Port2={enemy="Pistol Billionaire",questButton=2,ammountToKill=8}
        AFL.questData.Hydra1={enemy="Dragon Crew Warrior",questButton=1,ammountToKill=8}
        AFL.questData.Hydra2={enemy="Dragon Crew Archer",questButton=2,ammountToKill=8}
        AFL.questData.Hydra3={enemy="Hydra Enforcer",questButton=1,ammountToKill=8}
        AFL.questData.Hydra4={enemy="Venomous Assailant",questButton=2,ammountToKill=8}
        AFL.questData.GreatTree1={enemy="Marine Commodore",questButton=1,ammountToKill=8}
        AFL.questData.GreatTree2={enemy="Marine Rear Admiral",questButton=2,ammountToKill=8}
        AFL.questData.TurtleEntrance1={enemy="Fishman Raider",questButton=1,ammountToKill=8}
        AFL.questData.TurtleEntrance2={enemy="Fishman Captain",questButton=2,ammountToKill=8}
        AFL.questData.Mansion1={enemy="Forest Pirate",questButton=1,ammountToKill=8}
        AFL.questData.Mansion2={enemy="Mythological Pirate",questButton=2,ammountToKill=8}
        AFL.questData.TurtleCenter1={enemy="Jungle Pirate",questButton=1,ammountToKill=8}
        AFL.questData.TurtleCenter2={enemy="Musketeer Pirate",questButton=2,ammountToKill=8}
        AFL.questData.HauntedCastle1={enemy="Reborn Skeleton",questButton=1,ammountToKill=8}
        AFL.questData.HauntedCastle2={enemy="Living Zombie",questButton=2,ammountToKill=8}
        AFL.questData.HauntedCastle3={enemy="Demonic Soul",questButton=1,ammountToKill=8}
        AFL.questData.HauntedCastle4={enemy="Posessed Mummy",questButton=2,ammountToKill=8}
        AFL.questData.Peanut1={enemy="Peanut Scout",questButton=1,ammountToKill=8}
        AFL.questData.Peanut2={enemy="Peanut President",questButton=2,ammountToKill=8}
        AFL.questData.IceCream1={enemy="Ice Cream Chef",questButton=1,ammountToKill=8}
        AFL.questData.IceCream2={enemy="Ice Cream Commander",questButton=2,ammountToKill=8}
        AFL.questData.CakeLand1={enemy="Cookie Crafter",questButton=1,ammountToKill=8}
        AFL.questData.CakeLand2={enemy="Cake Guard",questButton=2,ammountToKill=8}
        AFL.questData.CakeLand3={enemy="Baking Staff",questButton=1,ammountToKill=8}
        AFL.questData.CakeLand4={enemy="Head Baker",questButton=2,ammountToKill=8}
        AFL.questData.Chocolate1={enemy="Cocoa Warrior",questButton=1,ammountToKill=8}
        AFL.questData.Chocolate2={enemy="Chocolate Bar Battler",questButton=2,ammountToKill=8}
        AFL.questData.Chocolate3={enemy="Sweet Thief",questButton=1,ammountToKill=8}
        AFL.questData.Chocolate4={enemy="Candy Rebel",questButton=2,ammountToKill=8}
        AFL.questData.NorthPole1={enemy="Candy Pirate",questButton=1,ammountToKill=8}
        AFL.questData.NorthPole2={enemy="Snow Demon",questButton=2,ammountToKill=8}
        AFL.questData.Tiki1Quest1={enemy="Isle Outlaw",questButton=1,ammountToKill=8}
        AFL.questData.Tiki1Quest2={enemy="Island Boy",questButton=2,ammountToKill=8}
        AFL.questData.Tiki2Quest1={enemy="Sun-kissed Warrior",questButton=1,ammountToKill=8}
        AFL.questData.Tiki2Quest2={enemy="Isle Champion",questButton=2,ammountToKill=8}
        AFL.questData.Tiki3Quest1={enemy="Serpent Hunter",questButton=1,ammountToKill=8}
        AFL.questData.Tiki3Quest2={enemy="Skull Slayer",questButton=2,ammountToKill=8}
    end
end
afl_loadQuestData()

function afl_jitterClick(x, y)

    local okMouse, mouse=pcall(function() return LocalPlayer:GetMouse() end)
    if not okMouse or not mouse then return false end
    -- mousemoveabs/mousemoverel are documented with integer pixels; the
    -- dialogue centre (AbsolutePosition + size/2) is usually fractional.
    x=math.floor((tonumber(x) or 0)+0.5); y=math.floor((tonumber(y) or 0)+0.5)

    mousemoveabs(x,y)
    wait(0.05)
    for _=1,12 do
        local okPos,mx,my=pcall(function() return mouse.X,mouse.Y end)
        if not okPos or not mx or not my then return false end
        local dx=math.floor(x-mx+0.5); local dy=math.floor(y-my+0.5)
        if math.abs(dx)<=2 and math.abs(dy)<=2 then break end
        mousemoverel(dx,dy)
        wait(0.03)
    end

    mousemoverel(3,0); wait(0.03)
    mousemoverel(-3,3); wait(0.03)
    mousemoverel(0,-3); wait(0.03)

    local okFinal,mx,my=pcall(function() return mouse.X,mouse.Y end)
    if okFinal and mx and my then mousemoverel(math.floor(x-mx+0.5),math.floor(y-my+0.5)) end
    wait(0.1)
    return true
end

function afl_getCharacter()
    local char=LocalPlayer.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if char and hrp then return char,hrp end
    return nil,nil
end

-- afl_setCanCollide(on) sets CanCollide to `on` (it used to write `not on`,
-- so the travel tween ran WITH collisions and noclip was left on afterwards).
-- Writes only parts whose value differs (fewer bridge writes) and records in
-- S.collisionOff that this run switched collisions off, so unload restores
-- them (shutdown hook below).
function afl_setCanCollide(on)
    local char=afl_getCharacter()
    if not char then return end
    if writesPaused() then return end
    S.collisionOff=(on==false)
    for _,c in pairs(char:GetChildren()) do
        pcall(function()
            if isA(c,"BasePart") and c.CanCollide~=on then c.CanCollide=on end
        end)
    end
end
onShutdown(function()
    if S.collisionOff then
        S.collisionOff=false
        local char=afl_getCharacter()
        if char then
            for _,c in pairs(char:GetChildren()) do
                pcall(function() if isA(c,"BasePart") and c.CanCollide~=true then c.CanCollide=true end end)
            end
        end
    end
end)

function afl_teleportTo(position)
    local char,hrp=afl_getCharacter()
    if not char or not position then return end
    afl_setCanCollide(false)
    tweenTo(hrp,position,AFL.tweenSpeed,function()
        return S.autoFarmLevel and char.Parent and not farmPriorityBlocked()
    end)
    afl_setCanCollide(true)
end

function afl_teleportToWait(questKey)
    local position=nil
    if afl_getNextNpc then
        local target=afl_getNextNpc()
        local targetRoot=target and target:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local p=targetRoot.Position
            position=Vector3.new(p.X,p.Y+23,p.Z)
        end
    end
    local route=AFL.waitRoutes and AFL.waitRoutes[questKey] or nil
    if not position and route and #route>0 then
        local index=(AFL.waitRouteIndices[questKey] or 0)+1
        if index>#route then index=1 end
        AFL.waitRouteIndices[questKey]=index
        position=route[index]
    elseif not position then
        position=AFL.waitPositions and AFL.waitPositions[questKey] or nil
    end
    if position then afl_teleportTo(position) end
end

function afl_readLevel()

    local okData,dataLevel=pcall(function() return LocalPlayer.Data.Level.Value end)
    if okData and type(dataLevel)=="number" and dataLevel>0 then return dataLevel end

    local okGui,levelText=pcall(function() return LocalPlayer.PlayerGui.Main.Level.Text end)
    if okGui and type(levelText)=="string" then
        local parsed=tonumber(string.match(levelText,"%d+"))
        if parsed and parsed>0 then return parsed end
    end
    return nil
end

function afl_getLevels()
    if not AFL.autofarmByLevel then return end
    local level=afl_readLevel()
    if not level then return end

    if level>=2800 then
        AFL.currentSea=3
        afl_loadQuestData()
        AFL.npcToFarm="Tiki3Quest2"
        AFL.islandPositions.Tiki3Quest2=Vector3.new(-16665.98,105.31,1576.49)
        AFL.waitPositions.Tiki3Quest2=Vector3.new(-16847.48,122.17,1727.21)
        return
    end
    local seaTable=AFL.levelFarmTable[AFL.currentSea]
    if not seaTable then return end
    for _,data in ipairs(seaTable) do
        if level>=data[1] and level<data[2] and AFL.questData[data[3]] then
            AFL.npcToFarm=data[3]; return
        end
    end
    for i=#seaTable,1,-1 do
        if AFL.questData[seaTable[i][3]] then AFL.npcToFarm=seaTable[i][3]; return end
    end
end

function afl_findDialogueOption(optionNumber)
    local wanted="option"..tostring(optionNumber)
    local okGui,dialogueGui=pcall(function() return LocalPlayer.PlayerGui:FindFirstChild("DialogueGui") end)
    if okGui and dialogueGui then
        local okDesc,descendants=pcall(function() return dialogueGui:GetDescendants() end)
        if okDesc and descendants then
            local function safeName(object)
                local okName,name=pcall(function() return object.Name end)
                return okName and type(name)=="string" and string.lower(name) or ""
            end
            local function ancestorContains(object,fragment)
                local current=object
                for _=1,16 do
                    if not current or current==dialogueGui then break end
                    if string.find(safeName(current),fragment,1,true) then return true end
                    local okParent,parent=pcall(function() return current.Parent end)
                    if not okParent then break end
                    current=parent
                end
                return false
            end
            local fallback=nil
            for _,object in pairs(descendants) do
                local name=safeName(object)
                if name=="textlabel" and ancestorContains(object,"button")
                    and ancestorContains(object,wanted) and ancestorContains(object,"optionslist") then
                    local okBounds,p,s=pcall(function() return object.AbsolutePosition,object.AbsoluteSize end)
                    if okBounds and p and s and type(p.X)=="number" and type(p.Y)=="number"
                        and type(s.X)=="number" and type(s.Y)=="number" and s.X>0 and s.Y>0 then
                        return object,Vector2.new(p.X+s.X/2,p.Y+s.Y/2)
                    end
                elseif name=="fill" and ancestorContains(object,"word1") and ancestorContains(object,"button")
                    and ancestorContains(object,wanted) and ancestorContains(object,"optionslist") then
                    local okBounds,p,s=pcall(function() return object.AbsolutePosition,object.AbsoluteSize end)
                    if okBounds and p and s and type(p.X)=="number" and type(p.Y)=="number"
                        and type(s.X)=="number" and type(s.Y)=="number" and s.X>0 and s.Y>0 then
                        return object,Vector2.new(p.X+s.X/2,p.Y+s.Y/2)
                    end
                elseif not fallback and name=="button" and ancestorContains(object,wanted) then
                    fallback=object
                end
            end
            if fallback then
                local okBounds,p,s=pcall(function() return fallback.AbsolutePosition,fallback.AbsoluteSize end)
                if okBounds and p and s and p.X and p.Y and s.X and s.Y then
                    return fallback,Vector2.new(p.X+s.X/2,p.Y+s.Y/2)
                end
            end
        end
    end

    local okOld,oldDialogue=pcall(function() return LocalPlayer.PlayerGui.Main.Dialogue end)
    local oldButton=okOld and oldDialogue and oldDialogue:FindFirstChild("Option"..tostring(optionNumber)) or nil
    if oldButton then
        local okBounds,p,s=pcall(function() return oldButton.AbsolutePosition,oldButton.AbsoluteSize end)
        if okBounds and p and s and p.X and p.Y and s.X and s.Y then
            return oldButton,Vector2.new(p.X+s.X/2,p.Y+s.Y/2)
        end
    end
    return nil,nil
end

function afl_waitDialogueOption(optionNumber,timeout,notAddress)
    local started=clock()
    local lastObject,lastCenter=nil,nil
    while clock()-started<(timeout or 3) do
        local object,center=afl_findDialogueOption(optionNumber)
        if object and center then
            lastObject,lastCenter=object,center
            local address=instKey(object)
            if not notAddress or not address or address~=notAddress then return object,center end
        end
        wait(0.05)
    end
    return lastObject,lastCenter
end

-- Load marker: this chunk ran to the end.
if LACED_LOAD and type(LACED_LOAD.done) == "table" then LACED_LOAD.done["50_farms"] = true end
