-- @chunk 60_afq  (lines 5016-6378 of the single-file build)
local LACED_LOAD = type(getgenv().__lacedLoad) == "table" and getgenv().__lacedLoad or nil -- load marker (loader.lua)
if LACED_LOAD and type(LACED_LOAD.started) == "table" then LACED_LOAD.started["60_afq"] = true end
-- Per-execution bindings: captured at chunk load so a re-run of the script
-- cannot make this copy's loops read the new copy's state (alive is a
-- closure over this run's state since the Oct 15 stability pass).
local alive = alive
local SCRIPT_STATE = SCRIPT_STATE
local S = S
local AFL = AFL
local AFQ = AFQ
local AFQ_DEBUG = AFQ_DEBUG
AFL_QUEST_OFFSET_X=70
AFL_QUEST_OFFSET_Y=50

function afl_clickDialogueOption(optionNumber,timeout,notAddress)
    local object,center=afl_waitDialogueOption(optionNumber,timeout,notAddress)
    if not object or not center then return false,nil end
    if not afl_jitterClick(center.X+AFL_QUEST_OFFSET_X,center.Y+AFL_QUEST_OFFSET_Y) then return false,nil end
    mouse1press(); wait(0.1); mouse1release()
    local address=instKey(object)
    return true,address
end

-- Level-farm quest keys -> the game's quest giver key and quest index.
-- Source: ReplicatedStorage.Quests (decompiled live, Oct 15 2026). The giver
-- key is a key of that module, and the index is the 1-based position of the
-- quest in that giver's list (DialoguesList.Util.generateQuest sends the same
-- pair to CommF_ "StartQuest"). Every entry was checked against
-- AFL.questData: the enemy named here is the quest's Task, and questButton
-- equals the index. SkyIsland1/2 use "SkyQuest" (not SkyExp1Quest).
AFL.questRemote={
    Sea1First={giver="MarineQuest",index=1}, -- Trainee
    Jungle1={giver="JungleQuest",index=1}, -- Monkey
    Jungle2={giver="JungleQuest",index=2}, -- Gorilla
    PirateVillage1={giver="BuggyQuest1",index=1}, -- Pirate
    PirateVillage2={giver="BuggyQuest1",index=2}, -- Brute
    DesertIsland1={giver="DesertQuest",index=1}, -- Desert Bandit
    DesertIsland2={giver="DesertQuest",index=2}, -- Desert Officer
    WinterIsland1={giver="SnowQuest",index=1}, -- Snow Bandit
    WinterIsland2={giver="SnowQuest",index=2}, -- Snowman
    MarineFortress={giver="MarineQuest2",index=1}, -- Chief Petty Officer
    SkyIsland1={giver="SkyQuest",index=1}, -- Sky Bandit
    SkyIsland2={giver="SkyQuest",index=2}, -- Dark Master
    PrisonIsland1={giver="PrisonerQuest",index=1}, -- Prisoner
    PrisonIsland2={giver="PrisonerQuest",index=2}, -- Dangerous Prisoner
    ColosseumIsland1={giver="ColosseumQuest",index=1}, -- Toga Warrior
    ColosseumIsland2={giver="ColosseumQuest",index=2}, -- Gladiator
    MagmaIsland1={giver="MagmaQuest",index=1}, -- Military Soldier
    MagmaIsland2={giver="MagmaQuest",index=2}, -- Military Spy
    UnderWaterIsland1={giver="FishmanQuest",index=1}, -- Fishman Warrior
    UnderWaterIsland2={giver="FishmanQuest",index=2}, -- Fishman Commando
    SkyIsland3={giver="SkyExp1Quest",index=1}, -- God's Guard
    SkyIsland4={giver="SkyExp1Quest",index=2}, -- Shanda
    SkyIsland5={giver="SkyExp2Quest",index=1}, -- Royal Squad
    SkyIsland6={giver="SkyExp2Quest",index=2}, -- Royal Soldier
    FountainIsland1={giver="FountainQuest",index=1}, -- Galley Pirate
    FountainIsland2={giver="FountainQuest",index=2}, -- Galley Captain
    RoseKingdom1={giver="Area1Quest",index=1}, -- Raider
    RoseKingdom2={giver="Area1Quest",index=2}, -- Mercenary
    Factory1={giver="Area2Quest",index=1}, -- Swan Pirate
    Factory2={giver="Area2Quest",index=2}, -- Factory Staff
    GreenZone1={giver="MarineQuest3",index=1}, -- Marine Lieutenant
    GreenZone2={giver="MarineQuest3",index=2}, -- Marine Captain
    Graveyard1={giver="ZombieQuest",index=1}, -- Zombie
    Graveyard2={giver="ZombieQuest",index=2}, -- Vampire
    Snow1={giver="SnowMountainQuest",index=1}, -- Snow Trooper
    Snow2={giver="SnowMountainQuest",index=2}, -- Winter Warrior
    ColdSide1={giver="IceSideQuest",index=1}, -- Lab Subordinate
    ColdSide2={giver="IceSideQuest",index=2}, -- Horned Warrior
    HotSide1={giver="FireSideQuest",index=1}, -- Magma Ninja
    HotSide2={giver="FireSideQuest",index=2}, -- Lava Pirate
    HauntedShip1={giver="ShipQuest1",index=1}, -- Ship Deckhand
    HauntedShip2={giver="ShipQuest1",index=2}, -- Ship Engineer
    HauntedShip3={giver="ShipQuest2",index=1}, -- Ship Steward
    HauntedShip4={giver="ShipQuest2",index=2}, -- Ship Officer
    WinterCastle1={giver="FrostQuest",index=1}, -- Arctic Warrior
    WinterCastle2={giver="FrostQuest",index=2}, -- Snow Lurker
    Wano1={giver="ForgottenQuest",index=1}, -- Sea Soldier
    Wano2={giver="ForgottenQuest",index=2}, -- Water Fighter
    Port1={giver="PiratePortQuest",index=1}, -- Pirate Millionaire
    Port2={giver="PiratePortQuest",index=2}, -- Pistol Billionaire
    Hydra1={giver="DragonCrewQuest",index=1}, -- Dragon Crew Warrior
    Hydra2={giver="DragonCrewQuest",index=2}, -- Dragon Crew Archer
    Hydra3={giver="VenomCrewQuest",index=1}, -- Hydra Enforcer
    Hydra4={giver="VenomCrewQuest",index=2}, -- Venomous Assailant
    GreatTree1={giver="MarineTreeIsland",index=1}, -- Marine Commodore
    GreatTree2={giver="MarineTreeIsland",index=2}, -- Marine Rear Admiral
    TurtleEntrance1={giver="DeepForestIsland3",index=1}, -- Fishman Raider
    TurtleEntrance2={giver="DeepForestIsland3",index=2}, -- Fishman Captain
    Mansion1={giver="DeepForestIsland",index=1}, -- Forest Pirate
    Mansion2={giver="DeepForestIsland",index=2}, -- Mythological Pirate
    TurtleCenter1={giver="DeepForestIsland2",index=1}, -- Jungle Pirate
    TurtleCenter2={giver="DeepForestIsland2",index=2}, -- Musketeer Pirate
    HauntedCastle1={giver="HauntedQuest1",index=1}, -- Reborn Skeleton
    HauntedCastle2={giver="HauntedQuest1",index=2}, -- Living Zombie
    HauntedCastle3={giver="HauntedQuest2",index=1}, -- Demonic Soul
    HauntedCastle4={giver="HauntedQuest2",index=2}, -- Posessed Mummy
    Peanut1={giver="NutsIslandQuest",index=1}, -- Peanut Scout
    Peanut2={giver="NutsIslandQuest",index=2}, -- Peanut President
    IceCream1={giver="IceCreamIslandQuest",index=1}, -- Ice Cream Chef
    IceCream2={giver="IceCreamIslandQuest",index=2}, -- Ice Cream Commander
    CakeLand1={giver="CakeQuest1",index=1}, -- Cookie Crafter
    CakeLand2={giver="CakeQuest1",index=2}, -- Cake Guard
    CakeLand3={giver="CakeQuest2",index=1}, -- Baking Staff
    CakeLand4={giver="CakeQuest2",index=2}, -- Head Baker
    Chocolate1={giver="ChocQuest1",index=1}, -- Cocoa Warrior
    Chocolate2={giver="ChocQuest1",index=2}, -- Chocolate Bar Battler
    Chocolate3={giver="ChocQuest2",index=1}, -- Sweet Thief
    Chocolate4={giver="ChocQuest2",index=2}, -- Candy Rebel
    NorthPole1={giver="CandyQuest1",index=1}, -- Candy Pirate
    NorthPole2={giver="CandyQuest1",index=2}, -- Snow Demon
    Tiki1Quest1={giver="TikiQuest1",index=1}, -- Isle Outlaw
    Tiki1Quest2={giver="TikiQuest1",index=2}, -- Island Boy
    Tiki2Quest1={giver="TikiQuest2",index=1}, -- Sun-kissed Warrior
    Tiki2Quest2={giver="TikiQuest2",index=2}, -- Isle Champion
    Tiki3Quest1={giver="TikiQuest3",index=1}, -- Serpent Hunter
    Tiki3Quest2={giver="TikiQuest3",index=2}, -- Skull Slayer
}

function afl_getQuestRemote()
    local ok,remote=pcall(function()
        local remotes=game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        return remotes and remotes:FindFirstChild("CommF_") or nil
    end)
    return ok and remote or nil
end

-- Accept the current level-farm quest with the game's own remote:
-- CommF_:InvokeServer("StartQuest", giverKey, questIndex). Returns true when
-- the call went through, or false plus a reason when the caller should click
-- the dialogue instead. Server codes: 0 accepted, 1 error, 2 already
-- completed, any other number = level required. Under Matcha Hybrid mode the
-- invoke returns a boolean (true) instead of the code, so a boolean true is
-- taken as accepted.
--
-- Stability pass (Oct 15 2026): the user reports the client crashing
-- consistently when this remote pickup fires. Every StartQuest now goes
-- through quietInvoke (00_core: no part writes and no other remote for
-- AFQ_REMOTE_QUIET_BEFORE/AFTER s around the invoke, one CommF_ invoke at a
-- time), at most one per AFQ_REMOTE_MIN_INTERVAL s for the same quest, and
-- AFQ_DEBUG.remoteAcceptOff = true stops it altogether (Auto Farm Quest then
-- accepts through the giver dialogue, Level Farm clicks its dialogue).
AFQ_REMOTE_MIN_INTERVAL=10 -- s between two StartQuest invokes for one quest, and between two AbandonQuest
questRemoteLastAt={}       -- "giverKey#index" -> clock() of the last StartQuest invoke
function afl_questRemoteWait(giverKey,questIndex)
    local last=questRemoteLastAt[tostring(giverKey).."#"..tostring(questIndex)]
    if not last then return 0 end
    return math.max(0,AFQ_REMOTE_MIN_INTERVAL-(clock()-last))
end
-- Remote quest accept default (Oct 15 2026). The user's A/B run confirmed
-- the CommF_ StartQuest/AbandonQuest invoke as the crash trigger under
-- Matcha Hybrid (AFQ_DEBUG.remoteAcceptOff = true stopped the crashes), so
-- the "Remote quest accept" toggle (afl_remote_quest -> AFL.useRemoteQuest)
-- is OFF by default. Off = no StartQuest and no AbandonQuest from this
-- script at all: Auto Farm Quest accepts through the giver dialogue
-- (afq_acceptByDialogue) and switches quests by accepting the new one there
-- (the game keeps one active quest; a dialogue accept replaces it), Level
-- Farm clicks its dialogue. AFQ_DEBUG.remoteAcceptOff = true forces the same
-- even with the toggle on.
function afq_remoteQuestOff()
    if AFQ_DEBUG and AFQ_DEBUG.remoteAcceptOff==true then return true end
    return AFL.useRemoteQuest~=true
end
function afl_startQuestRemote(giverKey,questIndex)
    if afq_remoteQuestOff() then return false,"remote quest accept is off (toggle Remote quest accept / AFQ_DEBUG.remoteAcceptOff)" end
    if remoteFailing("StartQuest") then return false,"StartQuest remote keeps failing" end
    local left=afl_questRemoteWait(giverKey,questIndex)
    if left>0 then return false,"StartQuest for this quest was sent less than "..AFQ_REMOTE_MIN_INTERVAL.."s ago" end
    local remote=afl_getQuestRemote()
    if not remote then return false,"CommF_ not found" end
    questRemoteLastAt[tostring(giverKey).."#"..tostring(questIndex)]=clock()
    local ok,result=quietInvoke("StartQuest",remote,"StartQuest",giverKey,questIndex)
    if not ok then return false,tostring(result) end
    if type(result)=="number" then
        if result==0 then return true end
        return false,"server code "..tostring(result)
    end
    if result==false then return false,"invoke returned false" end
    return true
end

function afl_acceptQuestRemote()
    local questKey=AFL.npcToFarm
    local quest=AFL.questData and AFL.questData[questKey]
    local target=AFL.questRemote and AFL.questRemote[questKey]
    if not quest or not target then return false,"no remote mapping for "..tostring(questKey) end
    return afl_startQuestRemote(target.giver,target.index)
end

function afl_setQuest()
    if not AFL.enableGetQuest or not S.autoFarmLevel then return false end
    local quest=AFL.questData and AFL.questData[AFL.npcToFarm]
    if not quest then return false end

    -- Remote path first (toggle "Remote quest accept"). The caller has already
    -- teleported next to the giver, which is kept in case the server checks
    -- the distance. Any failure drops through to the dialogue clicks below.
    if AFL.useRemoteQuest then
        local okRemote,reason=afl_acceptQuestRemote()
        if okRemote then
            AFL.lastQuestVia="remote"
            wait(0.3)
            return true
        end
        warnThrottled("questRemote","[laced.club] Remote quest accept failed ("..tostring(reason).."); clicking the dialogue instead",30)
    end
    AFL.lastQuestVia="click"
    -- The clicks go to whatever window has focus, and the farm may be
    -- switched off during the ~3 s of waits: check both between the clicks.
    local function stillOn() return alive() and S.autoFarmLevel and robloxFocused() end
    if not robloxFocused() then
        warnThrottled("questClickFocus","[laced.club] Level Farm: the dialogue quest pickup needs the Roblox window in front",30)
        return false
    end

    wait(0.5)
    if not stillOn() then return false end
    mouse1press(); wait(0.08); mouse1release()
    wait(1)
    if not stillOn() then return false end

    local originalOption1=nil
    local initialOption1=afl_waitDialogueOption(1,3)
    if initialOption1 then originalOption1=instKey(initialOption1) end

    local selected=afl_clickDialogueOption(quest.questButton,3)
    if not selected then return false end
    wait(0.35)
    if not stillOn() then return false end

    local accepted=afl_clickDialogueOption(1,3,originalOption1)
    if not accepted then
        wait(0.4)
        accepted=afl_clickDialogueOption(1,1)
    end
    return accepted==true
end

function afl_getNextNpc()
    local quest=AFL.questData[AFL.npcToFarm]; if not quest then return end
    local _,root=afl_getCharacter(); if not root then return end
    local cur=root.Position; local best,bestD=nil,math.huge
    local wanted=string.lower(quest.enemy)
    local now=clock()
    if AFL.nextNpcCache and now-(AFL.nextNpcCacheTime or 0)<0.12 then
        local cached=AFL.nextNpcCache
        local okCached,aliveCached=pcall(function()
            return cached and cached.Parent and cached:FindFirstChildOfClass("Humanoid")
                and cached:FindFirstChildOfClass("Humanoid").Health>0
                and string.find(string.lower(cached.Name),wanted,1,true)
        end)
        if okCached and aliveCached then return cached end
        AFL.nextNpcCache=nil
    end
    local folder=Workspace:FindFirstChild("Enemies")
    if not folder then return end
    local ok,enemies=pcall(function() return folder:GetChildren() end)
    if not ok or not enemies then return end
    for _,enemy in pairs(enemies) do
        if enemy and enemy.Parent and isA(enemy,"Model") then
            local hrp=enemy:FindFirstChild("HumanoidRootPart")
            local hum=enemy:FindFirstChildOfClass("Humanoid")
            local enemyName=""
            pcall(function() enemyName=string.lower(enemy.Name) end)
            if hrp and hum and hum.Health>0 and string.find(enemyName,wanted,1,true) then
                local dx=hrp.Position.X-cur.X; local dy=hrp.Position.Y-cur.Y; local dz=hrp.Position.Z-cur.Z
                local d=dx*dx+dy*dy+dz*dz
                if d<bestD then bestD=d; best=enemy end
            end
        end
    end
    AFL.nextNpcCache=best
    AFL.nextNpcCacheTime=now
    return best
end

function afl_farmNpcs()
    local kills=0
    afl_getLevels()
    if not AFL.npcToFarm then wait(1); return end
    local function pressNevermind()
        afl_clickDialogueOption(3,1)
    end
    local function farming()
        return alive() and S.autoFarmLevel and not farmPriorityBlocked()
    end
    -- Travel + quest pickup, aborting between steps once the toggle goes off.
    local function goGetQuest()
        afl_teleportTo(AFL.islandPositions[AFL.npcToFarm])
        if not farming() then return end
        wait(0.5); afl_setQuest()
        if not farming() then return end
        wait(0.5)
        afl_teleportToWait(AFL.npcToFarm); wait(0.5)
    end
    if farmPriorityBlocked() then return end
    if AFL.islandPositions[AFL.npcToFarm] and AFL.waitPositions[AFL.npcToFarm] then
        if farmPriorityBlocked() then return end
        goGetQuest()
    end
    while alive() and S.autoFarmLevel do
        if farmPriorityBlocked() then wait(0.1); continue end
        local curLevel=afl_readLevel()
        if curLevel and curLevel~=AFL.lastLevel then
            AFL.lastLevel=curLevel; local old=AFL.npcToFarm; afl_getLevels()
            if old~=AFL.npcToFarm and AFL.npcToFarm and AFL.islandPositions[AFL.npcToFarm] then
                kills=0
                goGetQuest()
                continue
            end
        end
        local quest=AFL.questData[AFL.npcToFarm]
        local maxKills=quest and quest.ammountToKill or 8
        if kills>=maxKills then
            kills=0
            goGetQuest()
            if not farming() then continue end
        end
        if AFL.selectedNpc and quest then
            -- Same case-insensitive match afl_getNextNpc uses to pick the NPC.
            local okName,npcName=pcall(function() return string.lower(AFL.selectedNpc.Name) end)
            if not okName or not string.find(npcName,string.lower(quest.enemy),1,true) then AFL.selectedNpc=nil end
        end
        if not AFL.selectedNpc or not partStillThere(AFL.selectedNpc) then
            local attempts=0
            -- Speed restore: the 0.05 s wait only while nothing is found (it
            -- also ran after a successful pick, delaying every next target).
            repeat
                AFL.selectedNpc=afl_getNextNpc(); attempts=attempts+1
                if AFL.selectedNpc then break end
                wait(0.05)
            until attempts>15
            if not AFL.selectedNpc then
                if AFL.waitPositions[AFL.npcToFarm] then afl_teleportToWait(AFL.npcToFarm) end
                wait(0.5); continue
            end
        end
        local npc=AFL.selectedNpc
        local hrp=npc:FindFirstChild("HumanoidRootPart")
        local hum=npc:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health<=0 then AFL.selectedNpc=nil; wait(0.05); continue end
        local fightStart=clock()
        local lastClick=0
        local lastRemoteAttack=0
        local reachedNpc=false
        local head=headExpander(npc)
        AFL.activeHead=head
        while hum and hum.Health>0 and partStillThere(npc) and farming() do
            if not partStillThere(hrp) then break end
            if clock()-fightStart>50 then pressNevermind(); AFL.selectedNpc=nil; break end
            local char,playerHrp=afl_getCharacter()
            if not char or not playerHrp then break end

            local okEnemy,enemyPos=pcall(function() return hrp.Position end)
            local okPlayer,playerPos=pcall(function() return playerHrp.Position end)
            if not okEnemy or not okPlayer or not enemyPos or not playerPos then break end
            if not enemyPos.X or not enemyPos.Y or not enemyPos.Z or not playerPos.X or not playerPos.Y or not playerPos.Z then break end

            local useRemote=S.remoteMode
            if not useRemote then head.apply() end
            local ox,oy,oz=getNormalFarmOffsets()
            local targetPos=Vector3.new(enemyPos.X+ox,enemyPos.Y+oy,enemyPos.Z+oz)
            if not reachedNpc then
                tweenTo(playerHrp,targetPos,S.FARM_SPEED,function()
                    return farming() and S.remoteMode==useRemote and isAlive(npc)
                end)
                reachedNpc=true
            else
                hardLockNpcCFrame(playerHrp,targetPos)
            end
            local now=clock()
            if useRemote then
                if now-lastRemoteAttack>=0.05 then
                    remoteAttack(npc)
                    lastRemoteAttack=now
                end
            else
                if now-lastClick>=0.06 then farmClick(); lastClick=now end
            end
            frameWait()
            hrp=npc:FindFirstChild("HumanoidRootPart")
            hum=npc:FindFirstChildOfClass("Humanoid")
        end
        head.restore()
        AFL.activeHead=nil
        if hum and hum.Health<=0 then kills=kills+1; AFL.selectedNpc=nil end
        -- A fight that ends at once (e.g. own character respawning) used to
        -- loop straight back here without yielding and freeze the VM.
        frameWait()
    end
end

task.spawn(function()
    while alive() do
        if S.autoFarmLevel and not farmPriorityBlocked() and not AFL.farmLoopRunning then
            AFL.farmLoopRunning=true
            local ok,farmError=pcall(afl_farmNpcs)
            AFL.farmLoopRunning=false
            if AFL.activeHead then pcall(AFL.activeHead.restore); AFL.activeHead=nil end
            AFL.selectedNpc=nil
            AFL.nextNpcCache=nil
            if not ok then
                warnThrottled("levelFarm","[laced.club] Level farm error: "..tostring(farmError),15)
                wait(0.5)
            end
        end
        wait(0.5)
    end
end)

-- ===========================================================================
-- Auto Farm Quest: level-driven quest chain through the StartQuest remote.
-- ===========================================================================
-- QUEST_LEVELS: one row per quest of ReplicatedStorage.Quests (116 rows).
-- Source: https://blox-fruits.fandom.com/wiki/Quests (captured 2026-10-15) for
-- the npc, island and reward columns. giverKey, questIndex, enemy/internalName,
-- count and boss were reconciled with the decompiled Quests module, and level
-- was checked against the live client's quest table on Oct 15 2026 (each
-- entry's LevelReq read from the Luau heap next to its Name). Rows whose wiki
-- value was corrected say so. uncertain = true marks rows whose NPC/giver
-- pairing is inferred; their giverKey, enemy, count and level are verified.
-- internalName is the Workspace.Enemies / Quests module spelling when it
-- differs from the wiki name.
QUEST_LEVELS = {
    { giverKey = "BanditQuest1", questIndex = 1, sea = 1, npc = "Bandit Quest Giver", island = "Pirate Starter", enemy = "Bandit", count = 5, level = 0, boss = false, rewardExp = 300, rewardBeli = 350 },
    { giverKey = "MarineQuest", questIndex = 1, sea = 1, npc = "Marine Leader", island = "Marine Starter", enemy = "Trainee", count = 5, level = 0, boss = false, rewardExp = 300, rewardBeli = 350 },
    { giverKey = "JungleQuest", questIndex = 1, sea = 1, npc = "Adventurer", island = "Jungle", enemy = "Monkey", count = 6, level = 10, boss = false, rewardExp = 2300, rewardBeli = 800 },
    { giverKey = "JungleQuest", questIndex = 2, sea = 1, npc = "Adventurer", island = "Jungle", enemy = "Gorilla", count = 8, level = 15, boss = false, rewardExp = 4500, rewardBeli = 1200 },
    { giverKey = "JungleQuest", questIndex = 3, sea = 1, npc = "Adventurer", island = "Jungle", enemy = "Gorilla King", internalName = "The Gorilla King", count = 1, level = 20, boss = true, rewardExp = 9500, rewardBeli = 2000 },
    { giverKey = "BuggyQuest1", questIndex = 1, sea = 1, npc = "Pirate Adventurer", island = "Pirate Village", enemy = "Pirate", count = 8, level = 30, boss = false, rewardExp = 13000, rewardBeli = 3000 },
    { giverKey = "BuggyQuest1", questIndex = 2, sea = 1, npc = "Pirate Adventurer", island = "Pirate Village", enemy = "Brute", count = 8, level = 40, boss = false, rewardExp = 22000, rewardBeli = 3500 },
    { giverKey = "BuggyQuest1", questIndex = 3, sea = 1, npc = "Pirate Adventurer", island = "Pirate Village", enemy = "Chef", count = 1, level = 55, boss = true, rewardExp = 45000, rewardBeli = 8000 },
    { giverKey = "DesertQuest", questIndex = 1, sea = 1, npc = "Desert Adventurer", island = "Desert", enemy = "Desert Bandit", count = 8, level = 60, boss = false, rewardExp = 45000, rewardBeli = 4000 },
    { giverKey = "DesertQuest", questIndex = 2, sea = 1, npc = "Desert Adventurer", island = "Desert", enemy = "Desert Officer", count = 6, level = 75, boss = false, rewardExp = 65000, rewardBeli = 4500 },
    { giverKey = "SnowQuest", questIndex = 1, sea = 1, npc = "Villager", island = "Frozen Village", enemy = "Snow Bandit", count = 7, level = 90, boss = false, rewardExp = 90000, rewardBeli = 5000 },
    { giverKey = "SnowQuest", questIndex = 2, sea = 1, npc = "Villager", island = "Frozen Village", enemy = "Snowman", count = 8, level = 100, boss = false, rewardExp = 150000, rewardBeli = 5500 },
    { giverKey = "SnowQuest", questIndex = 3, sea = 1, npc = "Villager", island = "Frozen Village", enemy = "Yeti", count = 1, level = 105, boss = true, rewardExp = 220000, rewardBeli = 10000 },
    { giverKey = "MarineQuest2", questIndex = 1, sea = 1, npc = "Marine", island = "Marine Fortress", enemy = "Chief Petty Officer", count = 8, level = 120, boss = false, rewardExp = 225000, rewardBeli = 6000 },
    { giverKey = "MarineQuest2", questIndex = 2, sea = 1, npc = "Marine", island = "Marine Fortress", enemy = "Vice Admiral", count = 1, level = 130, boss = true, rewardExp = 415000, rewardBeli = 15000 },
    { giverKey = "SkyQuest", questIndex = 1, sea = 1, npc = "Sky Adventurer", island = "Skylands", enemy = "Sky Bandit", count = 7, level = 150, boss = false, rewardExp = 315000, rewardBeli = 7000 }, -- corrected: count None -> 7
    { giverKey = "SkyQuest", questIndex = 2, sea = 1, npc = "Sky Adventurer", island = "Skylands", enemy = "Dark Master", count = 8, level = 175, boss = false, rewardExp = 450000, rewardBeli = 7500 }, -- corrected: count None -> 8
    { giverKey = "PrisonerQuest", questIndex = 1, sea = 1, npc = "Jail Keeper", island = "Prison", enemy = "Prisoner", count = 8, level = 190, boss = false, rewardExp = 550000, rewardBeli = 7000 }, -- corrected: count None -> 8
    { giverKey = "PrisonerQuest", questIndex = 2, sea = 1, npc = "Jail Keeper", island = "Prison", enemy = "Dangerous Prisoner", count = 8, level = 210, boss = false, rewardExp = 780000, rewardBeli = 7500 }, -- corrected: count None -> 8
    { giverKey = "ImpelQuest", questIndex = 1, sea = 1, npc = "Head Jailer", island = "Prison", enemy = "Ruthless Prisoner", count = 8, level = 225, boss = false, rewardExp = 900000, rewardBeli = 8000, uncertain = true }, -- uncertain: NPC/giver pairing inferred (giverKey, enemy, count and level are verified); corrected: count None -> 8
    { giverKey = "ImpelQuest", questIndex = 2, sea = 1, npc = "Head Jailer", island = "Prison", enemy = "Warden", count = 1, level = 230, boss = true, rewardExp = 1000000, rewardBeli = 10000, uncertain = true }, -- uncertain: NPC/giver pairing inferred (giverKey, enemy, count and level are verified)
    { giverKey = "ColosseumQuest", questIndex = 1, sea = 1, npc = "Colosseum Quest Giver", island = "Colosseum", enemy = "Toga Warrior", count = 7, level = 250, boss = false, rewardExp = 1100000, rewardBeli = 7000 }, -- corrected: count None -> 7
    { giverKey = "ColosseumQuest", questIndex = 2, sea = 1, npc = "Colosseum Quest Giver", island = "Colosseum", enemy = "Gladiator", count = 8, level = 275, boss = false, rewardExp = 1300000, rewardBeli = 7500 }, -- corrected: count None -> 8
    { giverKey = "MagmaQuest", questIndex = 1, sea = 1, npc = "The Mayor", island = "Magma Village", enemy = "Military Soldier", count = 7, level = 300, boss = false, rewardExp = 1700000, rewardBeli = 8250 }, -- corrected: count None -> 7
    { giverKey = "MagmaQuest", questIndex = 2, sea = 1, npc = "The Mayor", island = "Magma Village", enemy = "Military Spy", count = 8, level = 325, boss = false, rewardExp = 2000000, rewardBeli = 8500 }, -- corrected: count None -> 8
    { giverKey = "MagmaQuest", questIndex = 3, sea = 1, npc = "The Mayor", island = "Magma Village", enemy = "Magma General", internalName = "Magma Admiral", count = 1, level = 350, boss = true, rewardExp = 3000000, rewardBeli = 15000 },
    { giverKey = "FishmanQuest", questIndex = 1, sea = 1, npc = "King Neptune", island = "Underwater City", enemy = "Fishman Warrior", count = 8, level = 375, boss = false, rewardExp = 3050000, rewardBeli = 8750 }, -- corrected: count None -> 8
    { giverKey = "FishmanQuest", questIndex = 2, sea = 1, npc = "King Neptune", island = "Underwater City", enemy = "Fishman Commando", count = 7, level = 400, boss = false, rewardExp = 3350000, rewardBeli = 9000 }, -- corrected: count None -> 7
    { giverKey = "FishmanQuest", questIndex = 3, sea = 1, npc = "King Neptune", island = "Underwater City", enemy = "Fishman Lord", count = 1, level = 425, boss = true, rewardExp = 4250000, rewardBeli = 15000 },
    { giverKey = "SkyExp1Quest", questIndex = 1, sea = 1, npc = "Mole", island = "Upper Skylands", enemy = "God's Guard", count = 7, level = 450, boss = false, rewardExp = 4250000, rewardBeli = 8750 }, -- corrected: count None -> 7
    { giverKey = "SkyExp1Quest", questIndex = 2, sea = 1, npc = "Mole", island = "Upper Skylands", enemy = "Shanda", count = 9, level = 475, boss = false, rewardExp = 5000000, rewardBeli = 9000 }, -- corrected: count None -> 9
    { giverKey = "SkyExp1Quest", questIndex = 3, sea = 1, npc = "Mole", island = "Upper Skylands", enemy = "Sky Warlord", internalName = "Wysper", count = 1, level = 500, boss = true, rewardExp = 5700000, rewardBeli = 15000 },
    { giverKey = "SkyExp2Quest", questIndex = 1, sea = 1, npc = "Sky Quest Giver 2", island = "Upper Skylands", enemy = "Royal Squad", count = 8, level = 525, boss = false, rewardExp = 5800000, rewardBeli = 9500 }, -- corrected: count None -> 8
    { giverKey = "SkyExp2Quest", questIndex = 2, sea = 1, npc = "Sky Quest Giver 2", island = "Upper Skylands", enemy = "Royal Soldier", count = 8, level = 550, boss = false, rewardExp = 6300000, rewardBeli = 9750 }, -- corrected: count None -> 8
    { giverKey = "SkyExp2Quest", questIndex = 3, sea = 1, npc = "Sky Quest Giver 2", island = "Upper Skylands", enemy = "Lightning God", internalName = "Thunder God", count = 1, level = 575, boss = true, rewardExp = 8000000, rewardBeli = 20000 },
    { giverKey = "FountainQuest", questIndex = 1, sea = 1, npc = "Freezeburg Quest Giver", island = "Fountain City", enemy = "Galley Pirate", count = 8, level = 625, boss = false, rewardExp = 7500000, rewardBeli = 10000 }, -- corrected: count None -> 8
    { giverKey = "FountainQuest", questIndex = 2, sea = 1, npc = "Freezeburg Quest Giver", island = "Fountain City", enemy = "Galley Captain", count = 9, level = 650, boss = false, rewardExp = 8500000, rewardBeli = 10000 }, -- corrected: count None -> 9
    { giverKey = "FountainQuest", questIndex = 3, sea = 1, npc = "Freezeburg Quest Giver", island = "Fountain City", enemy = "Cyborg", count = 1, level = 675, boss = true, rewardExp = 10000000, rewardBeli = 20000 },
    { giverKey = "Area1Quest", questIndex = 1, sea = 2, npc = "Area 1 Quest Giver", island = "Kingdom of Rose", enemy = "Raider", count = 8, level = 700, boss = false, rewardExp = 8750000, rewardBeli = 10250 }, -- corrected: count None -> 8
    { giverKey = "Area1Quest", questIndex = 2, sea = 2, npc = "Area 1 Quest Giver", island = "Kingdom of Rose", enemy = "Mercenary", count = 8, level = 725, boss = false, rewardExp = 9750000, rewardBeli = 10500 }, -- corrected: count None -> 8
    { giverKey = "Area1Quest", questIndex = 3, sea = 2, npc = "Area 1 Quest Giver", island = "Kingdom of Rose", enemy = "Diamond", count = 1, level = 750, boss = true, rewardExp = 12500000, rewardBeli = 25000 },
    { giverKey = "Area2Quest", questIndex = 1, sea = 2, npc = "Area 2 Quest Giver", island = "Kingdom of Rose", enemy = "Swan Pirate", count = 8, level = 775, boss = false, rewardExp = 11500000, rewardBeli = 10750 }, -- corrected: count None -> 8
    { giverKey = "Area2Quest", questIndex = 2, sea = 2, npc = "Area 2 Quest Giver", island = "Kingdom of Rose", enemy = "Factory Staff", count = 8, level = 800, boss = false, rewardExp = 13000000, rewardBeli = 11000 }, -- corrected: count None -> 8
    { giverKey = "Area2Quest", questIndex = 3, sea = 2, npc = "Area 2 Quest Giver", island = "Kingdom of Rose", enemy = "Jeremy", count = 1, level = 850, boss = true, rewardExp = 16000000, rewardBeli = 25000 },
    { giverKey = "MarineQuest3", questIndex = 1, sea = 2, npc = "Marine Quest Giver", island = "Green Zone", enemy = "Marine Lieutenant", count = 8, level = 875, boss = false, rewardExp = 15000000, rewardBeli = 11250 }, -- corrected: count None -> 8
    { giverKey = "MarineQuest3", questIndex = 2, sea = 2, npc = "Marine Quest Giver", island = "Green Zone", enemy = "Marine Captain", count = 9, level = 900, boss = false, rewardExp = 16500000, rewardBeli = 11500 }, -- corrected: count None -> 9
    { giverKey = "MarineQuest3", questIndex = 3, sea = 2, npc = "Marine Quest Giver", island = "Green Zone", enemy = "Orbitus", count = 1, level = 925, boss = true, rewardExp = 19000000, rewardBeli = 25000 },
    { giverKey = "ZombieQuest", questIndex = 1, sea = 2, npc = "Graveyard Quest Giver", island = "Graveyard Island", enemy = "Zombie", count = 8, level = 950, boss = false, rewardExp = 19000000, rewardBeli = 11750 }, -- corrected: count None -> 8
    { giverKey = "ZombieQuest", questIndex = 2, sea = 2, npc = "Graveyard Quest Giver", island = "Graveyard Island", enemy = "Vampire", count = 8, level = 975, boss = false, rewardExp = 20500000, rewardBeli = 12000 }, -- corrected: count None -> 8
    { giverKey = "SnowMountainQuest", questIndex = 1, sea = 2, npc = "Snow Quest Giver", island = "Snow Mountain", enemy = "Snow Trooper", count = 8, level = 1000, boss = false, rewardExp = 22500000, rewardBeli = 12250 }, -- corrected: count None -> 8
    { giverKey = "SnowMountainQuest", questIndex = 2, sea = 2, npc = "Snow Quest Giver", island = "Snow Mountain", enemy = "Winter Warrior", count = 9, level = 1050, boss = false, rewardExp = 24000000, rewardBeli = 12500 }, -- corrected: count None -> 9
    { giverKey = "IceSideQuest", questIndex = 1, sea = 2, npc = "Ice Quest Giver", island = "Hot and Cold", enemy = "Lab Subordinate", count = 8, level = 1100, boss = false, rewardExp = 25500000, rewardBeli = 12250 }, -- corrected: count None -> 8
    { giverKey = "IceSideQuest", questIndex = 2, sea = 2, npc = "Ice Quest Giver", island = "Hot and Cold", enemy = "Horned Warrior", count = 9, level = 1125, boss = false, rewardExp = 27000000, rewardBeli = 12500 }, -- corrected: count None -> 9
    { giverKey = "IceSideQuest", questIndex = 3, sea = 2, npc = "Ice Quest Giver", island = "Hot and Cold", enemy = "Smoke Admiral", count = 1, level = 1150, boss = true, rewardExp = 32500000, rewardBeli = 20000 },
    { giverKey = "FireSideQuest", questIndex = 1, sea = 2, npc = "Fire Quest Giver", island = "Hot and Cold", enemy = "Magma Ninja", count = 8, level = 1175, boss = false, rewardExp = 29000000, rewardBeli = 12250 }, -- corrected: count None -> 8
    { giverKey = "FireSideQuest", questIndex = 2, sea = 2, npc = "Fire Quest Giver", island = "Hot and Cold", enemy = "Lava Pirate", count = 8, level = 1200, boss = false, rewardExp = 31000000, rewardBeli = 12500 }, -- corrected: count None -> 8
    { giverKey = "ShipQuest1", questIndex = 1, sea = 2, npc = "Rear Crew Quest Giver", island = "Cursed Ship", enemy = "Ship Deckhand", count = 8, level = 1250, boss = false, rewardExp = 33000000, rewardBeli = 12250, uncertain = true }, -- uncertain: NPC/giver pairing inferred (giverKey, enemy, count and level are verified); corrected: count None -> 8
    { giverKey = "ShipQuest1", questIndex = 2, sea = 2, npc = "Rear Crew Quest Giver", island = "Cursed Ship", enemy = "Ship Engineer", count = 8, level = 1275, boss = false, rewardExp = 35500000, rewardBeli = 12500, uncertain = true }, -- uncertain: NPC/giver pairing inferred (giverKey, enemy, count and level are verified); corrected: count None -> 8
    { giverKey = "ShipQuest2", questIndex = 1, sea = 2, npc = "Front Crew Quest Giver", island = "Cursed Ship", enemy = "Ship Steward", count = 8, level = 1300, boss = false, rewardExp = 37500000, rewardBeli = 12250, uncertain = true }, -- uncertain: NPC/giver pairing inferred (giverKey, enemy, count and level are verified); corrected: count None -> 8
    { giverKey = "ShipQuest2", questIndex = 2, sea = 2, npc = "Front Crew Quest Giver", island = "Cursed Ship", enemy = "Ship Officer", count = 8, level = 1325, boss = false, rewardExp = 39500000, rewardBeli = 12500, uncertain = true }, -- uncertain: NPC/giver pairing inferred (giverKey, enemy, count and level are verified); corrected: count None -> 8
    { giverKey = "FrostQuest", questIndex = 1, sea = 2, npc = "Frost Quest Giver", island = "Ice Castle", enemy = "Arctic Warrior", count = 8, level = 1350, boss = false, rewardExp = 41000000, rewardBeli = 12250 }, -- corrected: count None -> 8
    { giverKey = "FrostQuest", questIndex = 2, sea = 2, npc = "Frost Quest Giver", island = "Ice Castle", enemy = "Snow Lurker", count = 8, level = 1375, boss = false, rewardExp = 43000000, rewardBeli = 12500 }, -- corrected: count None -> 8
    { giverKey = "FrostQuest", questIndex = 3, sea = 2, npc = "Frost Quest Giver", island = "Ice Castle", enemy = "Awakened Ice Admiral", count = 1, level = 1400, boss = true, rewardExp = 45000000, rewardBeli = 20000 },
    { giverKey = "ForgottenQuest", questIndex = 1, sea = 2, npc = "Forgotten Quest Giver", island = "Forgotten Island", enemy = "Sea Soldier", count = 8, level = 1425, boss = false, rewardExp = 47000000, rewardBeli = 12250 }, -- corrected: count None -> 8
    { giverKey = "ForgottenQuest", questIndex = 2, sea = 2, npc = "Forgotten Quest Giver", island = "Forgotten Island", enemy = "Water Fighter", count = 8, level = 1450, boss = false, rewardExp = 49000000, rewardBeli = 12500 }, -- corrected: count None -> 8
    { giverKey = "ForgottenQuest", questIndex = 3, sea = 2, npc = "Forgotten Quest Giver", island = "Forgotten Island", enemy = "Tide Keeper", count = 1, level = 1475, boss = true, rewardExp = 51000000, rewardBeli = 12500 },
    { giverKey = "PiratePortQuest", questIndex = 1, sea = 3, npc = "Pirate Port Quest Giver", island = "Port Town", enemy = "Pirate Millionaire", count = 8, level = 1500, boss = false, rewardExp = 53000000, rewardBeli = 13000 }, -- corrected: count None -> 8
    { giverKey = "PiratePortQuest", questIndex = 2, sea = 3, npc = "Pirate Port Quest Giver", island = "Port Town", enemy = "Pistol Billionaire", count = 8, level = 1525, boss = false, rewardExp = 55500000, rewardBeli = 15000 }, -- corrected: count None -> 8
    { giverKey = "PiratePortQuest", questIndex = 3, sea = 3, npc = "Pirate Port Quest Giver", island = "Port Town", enemy = "Stone", count = 1, level = 1550, boss = true, rewardExp = 60000000, rewardBeli = 25000 },
    { giverKey = "DragonCrewQuest", questIndex = 1, sea = 3, npc = "Dragon Crew Quest Giver", island = "Hydra Island", enemy = "Dragon Crew Warrior", count = 8, level = 1575, boss = false, rewardExp = 58000000, rewardBeli = 13000 }, -- corrected: count None -> 8
    { giverKey = "DragonCrewQuest", questIndex = 2, sea = 3, npc = "Dragon Crew Quest Giver", island = "Hydra Island", enemy = "Dragon Crew Archer", count = 8, level = 1600, boss = false, rewardExp = 60500000, rewardBeli = 15000 }, -- corrected: count None -> 8
    { giverKey = "VenomCrewQuest", questIndex = 1, sea = 3, npc = "Hydra Town Quest Giver", island = "Hydra Island", enemy = "Hydra Enforcer", count = 8, level = 1625, boss = false, rewardExp = 62500000, rewardBeli = 13000 }, -- corrected: count None -> 8
    { giverKey = "VenomCrewQuest", questIndex = 2, sea = 3, npc = "Hydra Town Quest Giver", island = "Hydra Island", enemy = "Venomous Assailant", count = 8, level = 1650, boss = false, rewardExp = 64500000, rewardBeli = 15000 }, -- corrected: count None -> 8
    { giverKey = "VenomCrewQuest", questIndex = 3, sea = 3, npc = "Hydra Town Quest Giver", island = "Hydra Island", enemy = "Hydra Leader", count = 1, level = 1675, boss = true, rewardExp = 70000000, rewardBeli = 30000 },
    { giverKey = "MarineTreeIsland", questIndex = 1, sea = 3, npc = "Marine Tree Quest Giver", island = "Great Tree", enemy = "Marine Commodore", count = 8, level = 1700, boss = false, rewardExp = 68000000, rewardBeli = 13000 }, -- corrected: count None -> 8
    { giverKey = "MarineTreeIsland", questIndex = 2, sea = 3, npc = "Marine Tree Quest Giver", island = "Great Tree", enemy = "Marine Rear Admiral", count = 8, level = 1725, boss = false, rewardExp = 70500000, rewardBeli = 15000 }, -- corrected: count None -> 8
    { giverKey = "MarineTreeIsland", questIndex = 3, sea = 3, npc = "Marine Tree Quest Giver", island = "Great Tree", enemy = "Kilo Admiral", count = 1, level = 1750, boss = true, rewardExp = 78000000, rewardBeli = 35000 },
    { giverKey = "DeepForestIsland3", questIndex = 1, sea = 3, npc = "Turtle Adventure Quest Giver", island = "Floating Turtle", enemy = "Fishman Raider", count = 8, level = 1775, boss = false, rewardExp = 73000000, rewardBeli = 13000 }, -- corrected: giverKey DeepForestIsland -> DeepForestIsland3; count None -> 8
    { giverKey = "DeepForestIsland3", questIndex = 2, sea = 3, npc = "Turtle Adventure Quest Giver", island = "Floating Turtle", enemy = "Fishman Captain", count = 8, level = 1800, boss = false, rewardExp = 75500000, rewardBeli = 15000 }, -- corrected: giverKey DeepForestIsland -> DeepForestIsland3; count None -> 8
    { giverKey = "DeepForestIsland", questIndex = 1, sea = 3, npc = "Deep Forest Quest Giver", island = "Floating Turtle", enemy = "Forest Pirate", count = 8, level = 1825, boss = false, rewardExp = 78000000, rewardBeli = 13000 }, -- corrected: giverKey DeepForestIsland2 -> DeepForestIsland; count None -> 8
    { giverKey = "DeepForestIsland", questIndex = 2, sea = 3, npc = "Deep Forest Quest Giver", island = "Floating Turtle", enemy = "Mythological Pirate", count = 8, level = 1850, boss = false, rewardExp = 81000000, rewardBeli = 13000 }, -- corrected: giverKey DeepForestIsland2 -> DeepForestIsland; count None -> 8
    { giverKey = "DeepForestIsland", questIndex = 3, sea = 3, npc = "Deep Forest Quest Giver", island = "Floating Turtle", enemy = "Captain Elephant", count = 1, level = 1875, boss = true, rewardExp = 90000000, rewardBeli = 40000 }, -- corrected: giverKey DeepForestIsland2 -> DeepForestIsland
    { giverKey = "DeepForestIsland2", questIndex = 1, sea = 3, npc = "Deep Forest Area 2 Quest Giver", island = "Floating Turtle", enemy = "Jungle Pirate", count = 8, level = 1900, boss = false, rewardExp = 85000000, rewardBeli = 13000 }, -- corrected: giverKey DeepForestIsland3 -> DeepForestIsland2; count None -> 8
    { giverKey = "DeepForestIsland2", questIndex = 2, sea = 3, npc = "Deep Forest Area 2 Quest Giver", island = "Floating Turtle", enemy = "Musketeer Pirate", count = 8, level = 1925, boss = false, rewardExp = 87500000, rewardBeli = 15000 }, -- corrected: giverKey DeepForestIsland3 -> DeepForestIsland2; count None -> 8
    { giverKey = "DeepForestIsland2", questIndex = 3, sea = 3, npc = "Deep Forest Area 2 Quest Giver", island = "Floating Turtle", enemy = "Beautiful Pirate", count = 1, level = 1950, boss = true, rewardExp = 100000000, rewardBeli = 50000 }, -- corrected: giverKey DeepForestIsland3 -> DeepForestIsland2
    { giverKey = "HauntedQuest1", questIndex = 1, sea = 3, npc = "Haunted Castle Quest Giver 1", island = "Haunted Castle", enemy = "Reborn Skeleton", count = 8, level = 1975, boss = false, rewardExp = 90000000, rewardBeli = 13000 }, -- corrected: count None -> 8
    { giverKey = "HauntedQuest1", questIndex = 2, sea = 3, npc = "Haunted Castle Quest Giver 1", island = "Haunted Castle", enemy = "Living Zombie", count = 8, level = 2000, boss = false, rewardExp = 93500000, rewardBeli = 13250 }, -- corrected: count None -> 8
    { giverKey = "HauntedQuest2", questIndex = 1, sea = 3, npc = "Haunted Castle Quest Giver 2", island = "Haunted Castle", enemy = "Demonic Soul", count = 8, level = 2025, boss = false, rewardExp = 96000000, rewardBeli = 13500 }, -- corrected: count None -> 8
    { giverKey = "HauntedQuest2", questIndex = 2, sea = 3, npc = "Haunted Castle Quest Giver 2", island = "Haunted Castle", enemy = "Possessed Mummy", internalName = "Posessed Mummy", count = 8, level = 2050, boss = false, rewardExp = 98500000, rewardBeli = 13750 }, -- corrected: internalName 'Possessed Mummy' -> 'Posessed Mummy'; count None -> 8
    { giverKey = "NutsIslandQuest", questIndex = 1, sea = 3, npc = "Peanut Quest Giver", island = "Sea of Treats", enemy = "Peanut Scout", count = 8, level = 2075, boss = false, rewardExp = 100000000, rewardBeli = 14000 }, -- corrected: count None -> 8
    { giverKey = "NutsIslandQuest", questIndex = 2, sea = 3, npc = "Peanut Quest Giver", island = "Sea of Treats", enemy = "Peanut President", count = 8, level = 2100, boss = false, rewardExp = 102500000, rewardBeli = 14100 }, -- corrected: count None -> 8
    { giverKey = "IceCreamIslandQuest", questIndex = 1, sea = 3, npc = "Ice Cream Quest Giver", island = "Sea of Treats", enemy = "Ice Cream Chef", count = 8, level = 2125, boss = false, rewardExp = 105000000, rewardBeli = 14200 }, -- corrected: count None -> 8
    { giverKey = "IceCreamIslandQuest", questIndex = 2, sea = 3, npc = "Ice Cream Quest Giver", island = "Sea of Treats", enemy = "Ice Cream Commander", count = 8, level = 2150, boss = false, rewardExp = 107500000, rewardBeli = 14300 }, -- corrected: count None -> 8
    { giverKey = "IceCreamIslandQuest", questIndex = 3, sea = 3, npc = "Ice Cream Quest Giver", island = "Sea of Treats", enemy = "Cake Queen", count = 1, level = 2175, boss = true, rewardExp = 112500000, rewardBeli = 30000 },
    { giverKey = "CakeQuest1", questIndex = 1, sea = 3, npc = "Cake Quest Giver 1", island = "Sea of Treats", enemy = "Cookie Crafter", count = 8, level = 2200, boss = false, rewardExp = 110000000, rewardBeli = 14200 }, -- corrected: count None -> 8
    { giverKey = "CakeQuest1", questIndex = 2, sea = 3, npc = "Cake Quest Giver 1", island = "Sea of Treats", enemy = "Cake Guard", count = 8, level = 2225, boss = false, rewardExp = 112500000, rewardBeli = 14300 }, -- corrected: count None -> 8
    { giverKey = "CakeQuest2", questIndex = 1, sea = 3, npc = "Cake Quest Giver 2", island = "Sea of Treats", enemy = "Baking Staff", count = 8, level = 2250, boss = false, rewardExp = 115000000, rewardBeli = 14400 }, -- corrected: count None -> 8
    { giverKey = "CakeQuest2", questIndex = 2, sea = 3, npc = "Cake Quest Giver 2", island = "Sea of Treats", enemy = "Head Baker", count = 8, level = 2275, boss = false, rewardExp = 117500000, rewardBeli = 14500 }, -- corrected: count None -> 8
    { giverKey = "ChocQuest1", questIndex = 1, sea = 3, npc = "Chocolate Quest Giver 1", island = "Sea of Treats", enemy = "Cocoa Warrior", count = 8, level = 2300, boss = false, rewardExp = 120000000, rewardBeli = 14600 }, -- corrected: count None -> 8
    { giverKey = "ChocQuest1", questIndex = 2, sea = 3, npc = "Chocolate Quest Giver 1", island = "Sea of Treats", enemy = "Chocolate Bar Battler", count = 8, level = 2325, boss = false, rewardExp = 122500000, rewardBeli = 14700 }, -- corrected: count None -> 8
    { giverKey = "ChocQuest2", questIndex = 1, sea = 3, npc = "Chocolate Quest Giver 2", island = "Sea of Treats", enemy = "Sweet Thief", count = 8, level = 2350, boss = false, rewardExp = 125000000, rewardBeli = 14800 }, -- corrected: count None -> 8
    { giverKey = "ChocQuest2", questIndex = 2, sea = 3, npc = "Chocolate Quest Giver 2", island = "Sea of Treats", enemy = "Candy Rebel", count = 8, level = 2375, boss = false, rewardExp = 127500000, rewardBeli = 14900 }, -- corrected: count None -> 8
    { giverKey = "CandyQuest1", questIndex = 1, sea = 3, npc = "Candy Cane Quest Giver", island = "Sea of Treats", enemy = "Candy Pirate", count = 8, level = 2400, boss = false, rewardExp = 129000000, rewardBeli = 14800 }, -- corrected: count None -> 8
    { giverKey = "CandyQuest1", questIndex = 2, sea = 3, npc = "Candy Cane Quest Giver", island = "Sea of Treats", enemy = "Snow Demon", count = 8, level = 2425, boss = false, rewardExp = 131000000, rewardBeli = 14900 }, -- corrected: count None -> 8
    { giverKey = "TikiQuest1", questIndex = 1, sea = 3, npc = "Tiki Quest Giver 1", island = "Tiki Outpost", enemy = "Isle Outlaw", count = 8, level = 2450, boss = false, rewardExp = 133000000, rewardBeli = 15100 }, -- corrected: count None -> 8
    { giverKey = "TikiQuest1", questIndex = 2, sea = 3, npc = "Tiki Quest Giver 1", island = "Tiki Outpost", enemy = "Island Boy", count = 8, level = 2475, boss = false, rewardExp = 135000000, rewardBeli = 15200 }, -- corrected: count None -> 8
    { giverKey = "TikiQuest2", questIndex = 1, sea = 3, npc = "Tiki Quest Giver 2", island = "Tiki Outpost", enemy = "Sun-kissed Warrior", count = 8, level = 2500, boss = false, rewardExp = 137000000, rewardBeli = 15250 }, -- corrected: count None -> 8
    { giverKey = "TikiQuest2", questIndex = 2, sea = 3, npc = "Tiki Quest Giver 2", island = "Tiki Outpost", enemy = "Isle Champion", count = 8, level = 2525, boss = false, rewardExp = 139000000, rewardBeli = 15500 }, -- corrected: count None -> 8
    { giverKey = "TikiQuest3", questIndex = 1, sea = 3, npc = "Tiki Quest Giver 3", island = "Tiki Outpost", enemy = "Serpent Hunter", count = 8, level = 2550, boss = false, rewardExp = 141000000, rewardBeli = 15750 }, -- corrected: count None -> 8
    { giverKey = "TikiQuest3", questIndex = 2, sea = 3, npc = "Tiki Quest Giver 3", island = "Tiki Outpost", enemy = "Skull Slayer", count = 8, level = 2575, boss = false, rewardExp = 143000000, rewardBeli = 16000 }, -- corrected: count None -> 8
    { giverKey = "SubmergedQuest1", questIndex = 1, sea = 3, npc = "Submerged Quest Giver 1", island = "Submerged Island", enemy = "Reef Bandit", count = 8, level = 2600, boss = false, rewardExp = 145000000, rewardBeli = 15450 }, -- corrected: count None -> 8
    { giverKey = "SubmergedQuest1", questIndex = 2, sea = 3, npc = "Submerged Quest Giver 1", island = "Submerged Island", enemy = "Coral Pirate", count = 8, level = 2625, boss = false, rewardExp = 147000000, rewardBeli = 15500 }, -- corrected: count None -> 8
    { giverKey = "SubmergedQuest2", questIndex = 1, sea = 3, npc = "Submerged Quest Giver 2", island = "Submerged Island", enemy = "Sea Chanter", count = 8, level = 2650, boss = false, rewardExp = 150000000, rewardBeli = 15550 }, -- corrected: count None -> 8
    { giverKey = "SubmergedQuest2", questIndex = 2, sea = 3, npc = "Submerged Quest Giver 2", island = "Submerged Island", enemy = "Ocean Prophet", count = 8, level = 2675, boss = false, rewardExp = 152000000, rewardBeli = 15600 }, -- corrected: count None -> 8
    { giverKey = "SubmergedQuest3", questIndex = 1, sea = 3, npc = "Submerged Quest Giver 3", island = "Submerged Island", enemy = "High Disciple", count = 8, level = 2675, boss = false, rewardExp = 154000000, rewardBeli = 15650 }, -- corrected: count None -> 8; level 2700 -> 2675
    { giverKey = "SubmergedQuest3", questIndex = 2, sea = 3, npc = "Submerged Quest Giver 3", island = "Submerged Island", enemy = "Grand Devotee", count = 8, level = 2700, boss = false, rewardExp = 156000000, rewardBeli = 15700 }, -- corrected: count None -> 8; level 2725 -> 2700
}

-- Giver positions come from the Level Farm tables through AFL.questRemote
-- (questData key -> giver/index): every giver that Level Farm visits gets the
-- same island position, and its wait positions/routes are reused. The Mayor
-- (MagmaQuest) is pinned to his NPC position. Givers without a position
-- (BanditQuest1, ImpelQuest, SubmergedQuest1-3) are skipped by the selector
-- and named in the status line instead of guessed.
--
-- Underwater City (Sea 1) is a separate map far away from the sea it sits in.
-- Its spot in the sea is the whirlpool: Workspace._WorldOrigin.Locations.
-- Whirlpool at (4078.93, -13.78, -1814.86) (map definition world position
-- (4087.79, -13.78, -1814.86), diameter 1600). Over it lies the touch pad
-- Workspace.Map.TeleportSpawn.Entrance, 250 x 250 studs, centre (4050.31,
-- -1.69, -1814.12): touching it makes the server move the character to
-- TeleportSpawn.EntrancePoint (61163.85, 11.68, 1819.78) inside the city. The
-- 100 x 100 pad TeleportSpawn.Exit, centre (61170.05, -2.00, 1952.83), sends
-- it back to ExitPoint (3864.69, 6.74, -1926.21). The city map is centred on
-- (61379.79, -13.78, 1221.75) (map definition "backend" position). A straight
-- tween from the sea to a city position is a ~57,000-stud flight that only
-- gets in when its line happens to cross the entrance pad at sea level.
UNDERWATER_CITY={
    whirlpool=Vector3.new(4078.93,-13.78,-1814.86),
    entrancePad=Vector3.new(4050.31,-1.69,-1814.12),
    entrancePoint=Vector3.new(61163.85,11.68,1819.78),
    exitPad=Vector3.new(61170.05,-2.00,1952.83),
    exitPoint=Vector3.new(3864.69,6.74,-1926.21),
    center=Vector3.new(61379.79,-13.78,1221.75),
    radius=1000, -- horizontal; the map is 1600 across, every spawn/NPC is inside 800
}

function uwc_inCity(pos)
    if not pos or not pos.X or not pos.Z then return false end
    local c=UNDERWATER_CITY.center
    local dx,dz=pos.X-c.X,pos.Z-c.Z
    return dx*dx+dz*dz<=UNDERWATER_CITY.radius*UNDERWATER_CITY.radius
end

-- After a pad teleport the server can re-assert the character's position
-- for a moment while the new area streams in (seen live: a tween started at
-- once was pulled back ~70 studs). Wait until the root has stayed within 2
-- studs for 0.5 s (five 0.1 s samples), at most 2 s.
function afq_settleAfterPad(keep)
    local last=nil
    local stable=0
    local deadline=clock()+2
    while keep() and clock()<deadline do
        local _,root=afl_getCharacter()
        if not root then return end
        local okPos,pos=pcall(function() return root.Position end)
        if okPos and pos and last then
            local dx,dy,dz=pos.X-last.X,pos.Y-last.Y,pos.Z-last.Z
            if dx*dx+dy*dy+dz*dz<4 then stable=stable+1 else stable=0 end
            if stable>=5 then return end
        end
        last=okPos and pos or nil
        task.wait(0.1)
    end
end

-- Stand on a teleport pad until the server has moved the character to the
-- other side (uwc_inCity(position)==wantInside). Yields every 0.1 s, stops as
-- soon as checkFn() is false, gives up after 8 s on the pad.
function afq_usePad(padCenter,wantInside,checkFn)
    local function keep()
        local okKeep,result=pcall(checkFn)
        return okKeep and result and true or false
    end
    local char,hrp=afl_getCharacter()
    if not char or not hrp then return false end
    local okPos,pos=pcall(function() return hrp.Position end)
    if okPos and pos and uwc_inCity(pos)==wantInside then return true end
    afl_setCanCollide(false)
    local arrived=tweenTo(hrp,Vector3.new(padCenter.X,padCenter.Y+12,padCenter.Z),AFL.tweenSpeed,keep)
    afl_setCanCollide(true)
    if not arrived then return false end
    local deadline=clock()+8
    local nextPlace=0
    local sink=true
    while keep() and clock()<deadline do
        local _,root=afl_getCharacter()
        if not root then return false end
        local okRoot,rootPos=pcall(function() return root.Position end)
        if okRoot and rootPos and uwc_inCity(rootPos)==wantInside then
            afq_settleAfterPad(keep)
            return keep()
        end
        -- Standing still on the pad did not fire its touch live (2 s); the
        -- teleport came when the legs passed through it. So alternate between
        -- legs inside the pad (root 1 stud above it) and just above it, which
        -- makes a fresh contact each time. Re-placed every 0.8 s so a teleport
        -- in flight is not undone.
        markTravel() -- no background CommF_ invoke while on a pad
        if clock()>=nextPlace then
            local y=sink and padCenter.Y+1 or padCenter.Y+4
            moveRoot(root,padCenter.X,y,padCenter.Z,rootRotation(root))
            sink=not sink
            nextPlace=clock()+0.8
        end
        task.wait(0.1)
    end
    return false
end

-- Per-island overrides for Auto Farm Quest, keyed by giverKey. Any field may
-- be left out:
--   giverPos  Vector3 used instead of the Level Farm island position
--   waitPos   {[questIndex]=Vector3} used instead of the Level Farm wait spot
--   inside    function(pos) -> true when pos is on this island's own map
--   enter     function(checkFn) -> true once the character is inside
--   leave     function(checkFn) -> true once the character is outside
-- afq_teleportTo calls enter/leave when a move crosses the island boundary.
AFQ_ISLAND_OVERRIDES={
    FishmanQuest={
        giverPos=AFL.pos.underwater,
        waitPos={
            [1]=AFL.pos.underwaterWait1, -- Fishman Warrior spawns
            [2]=AFL.pos.underwaterWait2, -- Fishman Commando spawns
            [3]=Vector3.new(61352.90,88.53,1029.11), -- above where the Fishman Lord stood
        },
        inside=uwc_inCity,
        enter=function(checkFn) return afq_usePad(UNDERWATER_CITY.entrancePad,true,checkFn) end,
        leave=function(checkFn) return afq_usePad(UNDERWATER_CITY.exitPad,false,checkFn) end,
    },
}

-- The enter/leave step a move from fromPos to toPos needs, or nil.
function afq_routeFor(fromPos,toPos)
    for _,o in pairs(AFQ_ISLAND_OVERRIDES) do
        if type(o.inside)=="function" then
            local fromIn,toIn=o.inside(fromPos),o.inside(toPos)
            if toIn and not fromIn and o.enter then return o.enter end
            if fromIn and not toIn and o.leave then return o.leave end
        end
    end
    return nil
end

function afq_buildPositions()
    AFQ.giverPos={}; AFQ.waitKey={}
    for key,m in pairs(AFL.questRemote or {}) do
        local pos=AFL.islandPositions and AFL.islandPositions[key]
        if pos and not AFQ.giverPos[m.giver] then AFQ.giverPos[m.giver]=pos end
        AFQ.waitKey[m.giver.."#"..tostring(m.index)]=key
    end
    AFQ.giverPos.MagmaQuest=Vector3.new(-5308.87,17.04,8482.70)
    for giverKey,o in pairs(AFQ_ISLAND_OVERRIDES) do
        if o.giverPos then AFQ.giverPos[giverKey]=o.giverPos end
    end
end
afq_buildPositions()

function afq_enemyName(q) return q.internalName or q.enemy end

-- Boss interleave (Oct 15 2026). With "Include boss quests" on and a boss
-- quest as the selector's top pick, Auto Farm Quest kills the boss while it
-- is up and farms the best mob quest of the level (the fallback) while it is
-- down; a boss that respawns while the fallback is held waits until that
-- quest completes (at most AFQ_BOSS_MAX_WAIT s). See afq_bossDecide.
--
-- The living boss model of boss quest q and whether it is in Workspace.Enemies.
-- Enemies names are matched like afq_nearestEnemy (lower-case plain find, so
-- "[Lv. n]" suffixes do not matter). A boss that is up but not streamed in is
-- parked by the game in ReplicatedStorage under its internal name (seen live:
-- Magma Admiral, Warden, Mob Leader at their spawn spots, full health); that
-- model counts too, except until AFQ.bossRsIgnoreUntil (set after a kill or
-- an empty boss spot, so a stale parked model cannot hold the loop there).
function afq_bossFind(q)
    local wanted=afq_enemyName(q)
    local lower=string.lower(wanted)
    local folder=Workspace:FindFirstChild("Enemies")
    local okList,enemies=pcall(function() return folder and folder:GetChildren() or {} end)
    if okList and enemies then
        for _,enemy in pairs(enemies) do
            local okName,name=pcall(function() return string.lower(enemy.Name) end)
            if okName and name and string.find(name,lower,1,true) then
                local hum=enemy:FindFirstChildOfClass("Humanoid")
                local okHp,hp=pcall(function() return hum and hum.Health or 0 end)
                if okHp and type(hp)=="number" and hp>0 then return enemy,true end
            end
        end
    end
    if clock()<(AFQ.bossRsIgnoreUntil or 0) then return nil,false end
    local okRs,parked=pcall(function() return game:GetService("ReplicatedStorage"):FindFirstChild(wanted) end)
    if okRs and parked then
        local okClass,className=pcall(function() return parked.ClassName end)
        local hum=okClass and className=="Model" and parked:FindFirstChildOfClass("Humanoid") or nil
        local okHp,hp=pcall(function() return hum and hum.Health or 0 end)
        if okHp and type(hp)=="number" and hp>0 then return parked,false end
    end
    return nil,false
end

-- Is boss quest q's boss up? AFQ_DEBUG.forceBossAlive (true/false) replaces
-- the scan for live tests. A scan result is reused for AFQ_BOSS_POLL s.
-- (_WorldOrigin.EnemySpawns is no help here: its parts are static spawn
-- markers that exist whether the boss is up or not.)
function afq_bossAlive(q)
    local forced=AFQ_DEBUG and AFQ_DEBUG.forceBossAlive
    if forced==true or forced==false then return forced end
    local now=clock()
    if AFQ.bossPolledFor~=q or now-(AFQ.bossPollAt or -1e9)>=AFQ_BOSS_POLL then
        AFQ.bossPolledFor=q; AFQ.bossPollAt=now
        AFQ.bossAlive=afq_bossFind(q)~=nil
    end
    return AFQ.bossAlive==true
end

-- The boss was killed or its spot is empty: count it as down now (the next
-- scan comes AFQ_BOSS_POLL s later) and ignore a parked model for ignoreFor s.
function afq_bossMarkDown(ignoreFor)
    AFQ.bossAlive=false; AFQ.bossPollAt=clock()
    if ignoreFor then AFQ.bossRsIgnoreUntil=clock()+ignoreFor end
end

-- Where to wait for boss quest q: the island override's wait spot, else 20
-- studs above the boss model, else 20 studs above its _WorldOrigin.EnemySpawns
-- part ("<enemy> [Lv. n] [Boss]"; parts of bosses whose area is not loaded
-- sit at 0,0,0 and are skipped). nil when none is known.
function afq_bossPos(q)
    local override=AFQ_ISLAND_OVERRIDES[q.giverKey]
    local pos=override and override.waitPos and override.waitPos[q.questIndex]
    if pos then return pos end
    local model=afq_bossFind(q)
    local root=model and model:FindFirstChild("HumanoidRootPart")
    local okPos,p=pcall(function() return root and root.Position end)
    if okPos and p and p.X then return Vector3.new(p.X,p.Y+20,p.Z) end
    local origin=Workspace:FindFirstChild("_WorldOrigin")
    local spawns=origin and origin:FindFirstChild("EnemySpawns")
    local okList,parts=pcall(function() return spawns and spawns:GetChildren() or {} end)
    if not okList or not parts then return nil end
    for _,name in ipairs({q.enemy,q.internalName}) do
        if type(name)=="string" and name~="" then
            local prefix=string.lower(name).." ["
            for _,part in pairs(parts) do
                local okName,partName=pcall(function() return string.lower(part.Name) end)
                if okName and partName and string.sub(partName,1,#prefix)==prefix then
                    local okP,sp=pcall(function() return part.Position end)
                    if okP and sp and sp.X and math.abs(sp.X)+math.abs(sp.Y)+math.abs(sp.Z)>1 then
                        return Vector3.new(sp.X,sp.Y+20,sp.Z)
                    end
                end
            end
        end
    end
    return nil
end

-- Travel to boss quest q's spot (afq_teleportTo uses the island pads), or to
-- the Level Farm wait spot of its giver when no boss position is known.
function afq_goToBoss(q)
    local pos=afq_bossPos(q)
    if pos then return afq_teleportTo(pos),pos end
    return afq_goToWait(q)
end

-- The interleave decision for a boss quest pick: boss is the top pick (a boss
-- quest), fallback the best mob quest of the same level and sea. Sets
-- AFQ.bossMode for the status line and returns the quest to farm:
--   boss down                                  -> fallback ("fallback")
--   boss up, fallback accepted and unfinished  -> fallback ("pending") until
--     it completes or AFQ_BOSS_MAX_WAIT s after the boss was first seen up;
--     afq_step then switches (no abandon when the quest completed). After a
--     toggle off/on (entry cleared, AFQ.current kept) the held fallback's
--     progress is read from the tracker instead of AFQ.kills.
--   boss up otherwise                          -> boss ("boss")
-- After a boss kill afq_step marks the boss down, so the next pick is the
-- fallback at once.
function afq_bossDecide(boss,fallback)
    AFQ.bossQuest=boss; AFQ.bossFallback=fallback
    if not afq_bossAlive(boss) then
        AFQ.bossUpAt=nil; AFQ.bossMode="fallback"
        return fallback
    end
    local entry=AFQ.entry
    local onEntry=entry~=nil and AFQ.accepted and afq_sameQuest(entry,fallback)
    if onEntry or afq_sameQuest(AFQ.current,fallback) then
        if not AFQ.bossUpAt then AFQ.bossUpAt=clock() end
        local done
        if onEntry then
            done=AFQ.kills>=entry.count or afq_trackerGone(afq_trackerFrame())
        else
            local k,n=afq_trackerProgress()
            done=(k~=nil and n~=nil and k>=n) or not afq_trackerFrame()
        end
        if not done and clock()-AFQ.bossUpAt<AFQ_BOSS_MAX_WAIT then
            AFQ.bossMode="pending"
            return fallback
        end
    elseif entry and afq_sameQuest(entry,boss) then
        AFQ.bossUpAt=nil
    end
    AFQ.bossMode="boss"
    return boss
end

-- Highest level <= the player's level in the current sea; bosses only with
-- the toggle; a higher index at the same giver wins a tie. A boss pick goes
-- through afq_bossDecide (boss interleave), which can return the best mob
-- quest instead. Returns the pick and, when a better quest was skipped for
-- lack of a giver position, that one.
function afq_select(level)
    local sea=AFL.currentSea or 1
    local best,skipped,bestMob=nil,nil,nil
    local function better(q,cur)
        if not cur then return true end
        if q.level~=cur.level then return q.level>cur.level end
        if q.giverKey==cur.giverKey then return q.questIndex>cur.questIndex end
        return false
    end
    for _,q in ipairs(QUEST_LEVELS) do
        if q.sea==sea and type(q.level)=="number" and q.level<=level and type(q.count)=="number"
            and (S.questFarmBosses or not q.boss) then
            if AFQ.giverPos[q.giverKey] then
                if better(q,best) then best=q end
                if not q.boss and better(q,bestMob) then bestMob=q end
            elseif better(q,skipped) then skipped=q end
        end
    end
    if skipped and best and skipped.level<=best.level then skipped=nil end
    -- Boss interleave: a boss top pick with a mob quest to fall back on.
    if best and best.boss and bestMob then return afq_bossDecide(best,bestMob),skipped end
    AFQ.bossMode=nil
    return best,skipped
end

-- The React quest tracker (PlayerGui.TrackedQuestFrame) exists only while a
-- quest is active. PlayerGui.Main.Quest is a static legacy label and is not used.
function afq_trackerFrame()
    local ok,frame=pcall(function() return LocalPlayer.PlayerGui:FindFirstChild("TrackedQuestFrame") end)
    return ok and frame or nil
end

-- Address key of the tracker frame now on screen (nil: none).
function afq_trackerKey()
    local frame=afq_trackerFrame()
    return frame and instKey(frame) or nil
end

-- "The tracker seen after the accept has gone" = quest completed, but only
-- after AFQ_TRACKER_GONE_SECS without a frame: a React remount (respawn, UI
-- reload) used to read as a completed quest from one missing sample.
AFQ_TRACKER_GONE_SECS=1.5
function afq_trackerGone(tracker)
    if tracker then AFQ.trackerMissingSince=nil; return false end
    if not AFQ.trackerSeen then return false end
    local now=clock()
    if not AFQ.trackerMissingSince then AFQ.trackerMissingSince=now; return false end
    return now-AFQ.trackerMissingSince>=AFQ_TRACKER_GONE_SECS
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
end

-- AFQ.stepGen is the generation the running step started with; the toggle
-- callback bumps AFQ.gen, so a step left over from before a quick off/on
-- stops at its next check instead of writing into the freshly reset state.
function afq_farming()
    return alive() and S.autoFarmQuest==true and AFQ.stepGen==AFQ.gen and not farmPriorityFeatureActive()
end

-- Sleep up to seconds, in steps of at most 0.25 s, ending early when the
-- farm stops (a plain wait(60) would keep the step alive after toggle off).
function afq_sleep(seconds)
    local untilAt=clock()+(tonumber(seconds) or 0)
    repeat
        task.wait(math.min(0.25,math.max(0.05,untilAt-clock())))
    until clock()>=untilAt or not afq_farming()
end

-- Bounded retry backoff: 3 s, 6 s, 12 s ... at most 60 s.
function afq_backoff(fails)
    return math.min(3*2^(math.max(1,fails)-1),60)
end

-- Level the quest selector uses: AFQ_DEBUG.forceLevel when it is a number
-- (live tests), otherwise the real level (Data.Level.Value, GUI fallback).
function afq_level()
    local forced=AFQ_DEBUG and AFQ_DEBUG.forceLevel
    if type(forced)=="number" then return forced end
    return afl_readLevel()
end

function afq_sameQuest(a,b)
    return a~=nil and b~=nil and a.giverKey==b.giverKey and a.questIndex==b.questIndex
end

-- What the tracker says about quest q: nil when there is no tracker, "same"
-- when a label is q's enemy name ("Fishman Warrior") or its objective line
-- ("Defeat 8 Fishman Warriors"), "other" when it shows an objective line for
-- another enemy, "unknown" when its text is not readable yet. Whole labels
-- are compared so "Bandit" does not match "Sky Bandit".
function afq_trackerQuestIs(q)
    local frame=afq_trackerFrame()
    if not frame then return nil end
    local texts=afq_trackerTexts(frame)
    if not texts then return "unknown" end
    local names={}
    for _,n in ipairs({q.enemy,q.internalName}) do
        if type(n)=="string" and n~="" then
            local lower=string.lower(n)
            local escaped=string.gsub(lower,"[%^%$%(%)%%%.%[%]%*%+%-%?]","%%%0")
            names[#names+1]={plain=lower,pattern=escaped}
        end
    end
    local sawObjective=false
    for _,text in ipairs(texts) do
        do
            local lower=string.lower(string.match(text,"^%s*(.-)%s*$") or text)
            local objective=string.find(lower,"^defeat%s")~=nil
            if objective then sawObjective=true end
            for _,n in ipairs(names) do
                if lower==n.plain then return "same" end
                if objective and string.find(lower,"^defeat%s+%d*%s*"..n.pattern.."s?$") then return "same" end
            end
        end
    end
    return sawObjective and "other" or "unknown"
end

-- Status line plus a throttled warn for quest switches.
function afq_logSwitch(text)
    AFQ.status=text; afq_updateLabel()
    warnThrottled("questSwitch","[laced.club] Auto Farm Quest: "..text,5)
end

-- Drop the active quest with the game's own remote. The game allows one
-- active quest and refuses StartQuest while another is held; Matcha's
-- InvokeServer returns only a boolean, so the refusal cannot be read from
-- the result and the old quest has to be abandoned first. Waits up to 1.5 s
-- (0.1 s steps) for the tracker to go away.
--
-- Stability pass (Oct 15 2026): the local quest state used to be wiped as the
-- first statement, before the remote ran or was seen to work, and the result
-- was the pcall status only. Now: no tracker on screen = nothing to abandon
-- (local state dropped, no invoke); otherwise at most one AbandonQuest per
-- AFQ_REMOTE_MIN_INTERVAL s through quietInvoke, and the local state is
-- dropped only once the tracker is gone. Returns ok, reason; on false the
-- held quest is kept and the caller backs off.
function afq_clearHeld()
    AFQ.current=nil; AFQ.accepted=false; AFQ.trackerSeen=false; AFQ.kills=0; AFQ.selectedNpc=nil
    AFQ.trackerMissingSince=nil
end
function afq_abandon()
    if AFQ_DEBUG.noAccept then afq_clearHeld(); return true end
    if not afq_trackerFrame() then afq_clearHeld(); return true end
    if afq_remoteQuestOff() then
        -- Never reached from afq_step while the remote is off (the dialogue
        -- accept replaces the held quest); kept as a guard.
        return false,"AbandonQuest is not sent while remote quest accept is off"
    end
    local since=clock()-(AFQ.lastAbandonAt or -1e9)
    if since<AFQ_REMOTE_MIN_INTERVAL then
        return false,"AbandonQuest was sent "..math.floor(since).."s ago (at most one per "..AFQ_REMOTE_MIN_INTERVAL.."s)"
    end
    if remoteFailing("AbandonQuest") then return false,"AbandonQuest remote keeps failing" end
    local remote=afl_getQuestRemote()
    if not remote then return false,"CommF_ not found" end
    AFQ.lastAbandonAt=clock()
    local ok,err=quietInvoke("AbandonQuest",remote,"AbandonQuest")
    if not ok then return false,"AbandonQuest failed: "..tostring(err) end
    -- InvokeServer returns only a boolean: the tracker going away is the
    -- proof. Polled at 2 Hz (FindFirstChild only), at most 2 s.
    local deadline=clock()+2
    while afq_farming() and afq_trackerFrame() and clock()<deadline do task.wait(0.5) end
    if afq_trackerFrame() then return false,"the tracker still shows a quest after AbandonQuest" end
    afq_clearHeld()
    return true
end

-- Accept proof (Matcha's InvokeServer returns only a boolean): poll the
-- tracker until it shows quest q, for at most seconds. Stability pass (Oct 15
-- 2026): polled at AFQ_TRACKER_POLL (2 Hz) through the cached tracker
-- strings (afq_trackerTexts, at most one GetDescendants per second), starting
-- after quietInvoke's quiet window, not at 10 Hz right after the invoke.
-- False whenever the farm was switched off (it used to return the last
-- poll's result). An unreadable tracker ("unknown") counts only when a
-- tracker frame appeared during this accept (none before, or a different
-- one: beforeKey = afq_trackerKey() taken before the invoke); a frame that
-- was already there proves nothing.
AFQ_REMOTE_ACCEPT_WAIT=3    -- s the tracker may take to show an accepted quest (was 2 s at 10 Hz)
AFQ_TRACKER_POLL=0.5
function afq_waitTrackerFor(q,seconds,beforeKey)
    local deadline=clock()+(seconds or AFQ_REMOTE_ACCEPT_WAIT)
    local state=afq_trackerQuestIs(q)
    while state~="same" and clock()<deadline and afq_farming() do
        task.wait(AFQ_TRACKER_POLL)
        state=afq_trackerQuestIs(q)
    end
    if not afq_farming() then return false end
    if state=="same" then return true end
    if state=="unknown" then
        local key=afq_trackerKey()
        return key~=nil and key~=beforeKey
    end
    return false
end

-- Seconds until a StartQuest for q may be sent (0 = now): never inside the
-- switch cooldown, at most one per AFQ_REMOTE_MIN_INTERVAL s per quest.
function afq_acceptWait(q)
    local cooldown=AFQ_SWITCH_COOLDOWN-(clock()-(AFQ.lastSwitch or -1e9))
    return math.max(0,cooldown,afl_questRemoteWait(q.giverKey,q.questIndex))
end

-- No-remote accept, the normal path since Oct 15 2026 (Remote quest accept
-- off by default; also AFQ_DEBUG.remoteAcceptOff): the Level Farm dialogue
-- clicks at the giver (questButton = questIndex for every quest, checked
-- against the Quests module). Needs Roblox in front. The dialogue's accept
-- option is the game's own client call (DialoguesList.Util.generateQuest ->
-- CommF_ StartQuest from the game's LocalScript, not through Matcha's
-- InvokeServer bridge). A quest that is still active is replaced by the new
-- accept (one active quest; the wiki says a new accept overrides it, and
-- the old Level Farm click flow in afl_setQuest relied on that); afq_step
-- verifies it through the tracker showing the new quest.
function afq_acceptByDialogue(q)
    if not robloxFocused() then return false,"the dialogue accept needs the Roblox window in front" end
    wait(0.5)
    if not afq_farming() then return false,"stopped" end
    mouse1press(); wait(0.08); mouse1release()
    wait(1)
    if not afq_farming() then return false,"stopped" end
    local original=nil
    local first=afl_waitDialogueOption(1,3)
    if first then original=instKey(first) end
    if not afl_clickDialogueOption(q.questIndex,3) then return false,"quest option "..q.questIndex.." not found in the dialogue" end
    wait(0.35)
    if not afq_farming() then return false,"stopped" end
    local accepted=afl_clickDialogueOption(1,3,original)
    if not accepted then wait(0.4); accepted=afl_clickDialogueOption(1,1) end
    if not accepted then return false,"accept option not found in the dialogue" end
    return true
end

-- Cheap level read during a fight: when the selection no longer matches the
-- quest being farmed, flag the switch (afq_step does it after this kill) and
-- say so in the status line.
function afq_checkSwitchPending()
    if AFQ.switchPending or not AFQ.entry then return end
    local level=afq_level()
    if not level then return end
    local q=afq_select(level)
    if q and not afq_sameQuest(q,AFQ.entry) then
        AFQ.switchPending=true
        afq_logSwitch("Lv "..level..": "..q.giverKey.." #"..q.questIndex.." selected, switching after this kill")
    end
end

function afq_teleportTo(position)
    local char,hrp=afl_getCharacter()
    if not char or not hrp or not position then return false end
    -- Crossing into or out of a separate island map (Underwater City) goes
    -- through that island's pad first instead of one impossible straight tween.
    local okFrom,fromPos=pcall(function() return hrp.Position end)
    local route=okFrom and fromPos and afq_routeFor(fromPos,position) or nil
    if route then
        AFQ_DEBUG.phase=tostring(AFQ_DEBUG.phase).."-route"
        if not route(function() return afq_farming() and char.Parent end) then return false end
        char,hrp=afl_getCharacter()
        if not char or not hrp then return false end
    end
    afl_setCanCollide(false)
    local ok=tweenTo(hrp,position,AFL.tweenSpeed,function() return afq_farming() and char.Parent end)
    afl_setCanCollide(true)
    -- tweenTo writes CFrame only, so gravity keeps adding fall speed for the
    -- whole trip (seen live: -540 studs/s on arrival). Drop it on arrival.
    if ok then zeroVelocity(hrp) end
    return ok
end

-- Keep the root at position for seconds: re-placed and its velocity zeroed
-- every frame, so a wait spot in the air is held instead of free-falling
-- (seen live: wait spot over open air -> fell to the sea, tweened back up,
-- every ~3.3 s). Only while afq_farming(); always yields at least one frame.
-- Oct 15 2026: 60 Hz (ROOT_WRITE_HZ; 30 Hz in safe mode), one placeRoot per
-- frame (CFrame with the held rotation + zero velocity, no skip), and no
-- write while a tween owns the root.
function afq_holdAt(position,seconds)
    local deadline=clock()+(seconds or 0)
    repeat
        local _,root=afl_getCharacter()
        if root and position and afq_farming() and not rootTweenOwned() then
            placeRoot(root,position.X,position.Y,position.Z,lockedRotation(root))
        end
        task.wait(writeInterval(1/ROOT_WRITE_HZ))
    until clock()>=deadline or not afq_farming()
end

-- Centroid of quest q's readable _WorldOrigin.EnemySpawns parts ("<enemy>
-- [Lv. n]..."; parts outside the loaded area read 0,0,0 and are skipped),
-- or nil. Tries q.enemy, then q.internalName.
function afq_spawnCentroid(q)
    local origin=Workspace:FindFirstChild("_WorldOrigin")
    local spawns=origin and origin:FindFirstChild("EnemySpawns")
    local okList,parts=pcall(function() return spawns and spawns:GetChildren() or {} end)
    if not okList or not parts then return nil end
    for _,name in ipairs({q.enemy,q.internalName}) do
        if type(name)=="string" and name~="" then
            local prefix=string.lower(name).." ["
            local sx,sy,sz,n=0,0,0,0
            for _,part in pairs(parts) do
                local okName,partName=pcall(function() return string.lower(part.Name) end)
                if okName and partName and string.sub(partName,1,#prefix)==prefix then
                    local okP,sp=pcall(function() return part.Position end)
                    if okP and sp and sp.X and math.abs(sp.X)+math.abs(sp.Y)+math.abs(sp.Z)>1 then
                        sx,sy,sz,n=sx+sp.X,sy+sp.Y,sz+sp.Z,n+1
                    end
                end
            end
            if n>0 then return Vector3.new(sx/n,sy/n,sz/n) end
        end
    end
    return nil
end

function afq_goToWait(q)
    local override=AFQ_ISLAND_OVERRIDES[q.giverKey]
    local overridePos=override and override.waitPos and override.waitPos[q.questIndex]
    if overridePos then return afq_teleportTo(overridePos),overridePos end
    local key=AFQ.waitKey[q.giverKey.."#"..tostring(q.questIndex)]
        or AFQ.waitKey[q.giverKey.."#1"] or AFQ.waitKey[q.giverKey.."#2"]
    local position=nil
    local route=key and AFL.waitRoutes and AFL.waitRoutes[key] or nil
    if route and #route>0 then
        local index=(AFL.waitRouteIndices[key] or 0)+1
        if index>#route then index=1 end
        AFL.waitRouteIndices[key]=index
        position=route[index]
    elseif key then
        position=AFL.waitPositions and AFL.waitPositions[key] or nil
    end
    -- Stale-map guard: a static spot more than AFQ_WAIT_STALE_DIST from the
    -- quest enemy's spawn markers (island moved in a game update) is replaced
    -- by AFQ_WAIT_HEIGHT studs above their centroid; so is a missing one.
    local centroid=afq_spawnCentroid(q)
    if centroid then
        local spot=Vector3.new(centroid.X,centroid.Y+AFQ_WAIT_HEIGHT,centroid.Z)
        local far=true
        if position then
            local dx,dy,dz=position.X-spot.X,position.Y-spot.Y,position.Z-spot.Z
            far=dx*dx+dy*dy+dz*dz>AFQ_WAIT_STALE_DIST*AFQ_WAIT_STALE_DIST
        end
        if far then position=spot end
    end
    if not position then return false end
    return afq_teleportTo(position),position
end

-- Nearest living Workspace.Enemies model whose Name contains the quest enemy
-- (case-insensitive plain find: models carry suffixes such as "[Lv. 300]").
function afq_nearestEnemy(q)
    local _,root=afl_getCharacter(); if not root then return nil end
    local okPos,cur=pcall(function() return root.Position end)
    if not okPos or not cur then return nil end
    local wanted=string.lower(afq_enemyName(q))
    local folder=Workspace:FindFirstChild("Enemies")
    if not folder then return nil end
    local ok,enemies=pcall(function() return folder:GetChildren() end)
    if not ok or not enemies then return nil end
    local best,bestD=nil,math.huge
    local now=clock()
    local blocked=AFQ.npcBlock or {}
    for key,untilAt in pairs(blocked) do if now>=untilAt then blocked[key]=nil end end
    local anyBlocked=next(blocked)~=nil
    for _,enemy in pairs(enemies) do
        if enemy and enemy.Parent and isA(enemy,"Model") and not (anyBlocked and blocked[instKey(enemy)]) then
            local hrp=enemy:FindFirstChild("HumanoidRootPart")
            local hum=enemy:FindFirstChildOfClass("Humanoid")
            local name=""
            pcall(function() name=string.lower(enemy.Name) end)
            if hrp and hum and hum.Health>0 and string.find(name,wanted,1,true) then
                local okE,p=pcall(function() return hrp.Position end)
                if okE and p then
                    local dx,dy,dz=p.X-cur.X,p.Y-cur.Y,p.Z-cur.Z
                    local d=dx*dx+dy*dy+dz*dz
                    if d<bestD then bestD=d; best=enemy end
                end
            end
        end
    end
    return best
end

-- Same fight as the Level Farm loop (head expander, offsets, tween then hard
-- lock, click or RegisterHit), bounded by afq_farming(). Returns true when the
-- enemy's Humanoid reached 0 HP.
function afq_fight(npc)
    local hrp=npc:FindFirstChild("HumanoidRootPart")
    local hum=npc:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health<=0 then return false end
    local fightStart=clock()
    local lastClick,lastRemoteAttack=0,0
    local lastLevelCheck=fightStart
    local reachedNpc=false
    local head=headExpander(npc)
    AFQ.activeHead=head
    while hum and hum.Health>0 and partStillThere(npc) and afq_farming() do
        if not partStillThere(hrp) then break end
        if clock()-fightStart>50 then
            -- Not damageable (out of reach, immune, safe zone): skip it for 60 s
            -- instead of fighting it again in 50 s blocks forever.
            if type(AFQ.npcBlock)=="table" then AFQ.npcBlock[instKey(npc)]=clock()+60 end
            break
        end
        local char,playerHrp=afl_getCharacter()
        if not char or not playerHrp then break end
        local okEnemy,enemyPos=pcall(function() return hrp.Position end)
        local okPlayer,playerPos=pcall(function() return playerHrp.Position end)
        if not okEnemy or not okPlayer or not enemyPos or not playerPos then break end
        if not enemyPos.X or not enemyPos.Y or not enemyPos.Z or not playerPos.X or not playerPos.Y or not playerPos.Z then break end
        local useRemote=S.remoteMode
        if not useRemote and not AFQ_DEBUG.noHead then head.apply() end
        local ox,oy,oz=getNormalFarmOffsets()
        local targetPos=Vector3.new(enemyPos.X+ox,enemyPos.Y+oy,enemyPos.Z+oz)
        if not reachedNpc then
            AFQ_DEBUG.phase="fight-tween"
            tweenTo(playerHrp,targetPos,S.FARM_SPEED,function()
                return afq_farming() and S.remoteMode==useRemote and isAlive(npc)
            end)
            reachedNpc=true
            AFQ_DEBUG.phase="fight-lock"
        elseif not AFQ_DEBUG.noLock then
            hardLockNpcCFrame(playerHrp,targetPos)
        end
        local now=clock()
        if now-lastLevelCheck>=AFQ_LEVEL_CHECK_INTERVAL then
            lastLevelCheck=now
            pcall(afq_checkSwitchPending)
        end
        if AFQ_DEBUG.noClick then
            -- isolation run: no attack input at all
        elseif useRemote then
            if now-lastRemoteAttack>=0.05 then remoteAttack(npc); lastRemoteAttack=now end
        else
            if now-lastClick>=writeInterval(0.06) then farmClick(); lastClick=now end
        end
        frameWait()
        hrp=npc:FindFirstChild("HumanoidRootPart")
        hum=npc:FindFirstChildOfClass("Humanoid")
    end
    local okDead,dead=pcall(function() return hum~=nil and hum.Health<=0 end)
    head.restore()
    AFQ.activeHead=nil
    frameWait()
    return okDead and dead==true
end

-- One step of the chain: select for the current level, switch (abandon the
-- held quest) when the selection changed, (re)accept when needed, otherwise
-- fight the nearest quest enemy. Every path yields.
function afq_step()
    AFQ_DEBUG.phase="select"
    local level=afq_level()
    if not level then AFQ.status="level unknown"; afq_updateLabel(); wait(1); return end
    local q,skipped=afq_select(level)
    if not q then
        AFQ.status="Lv "..level..": no quest with a known giver position in sea "..tostring(AFL.currentSea)
        afq_updateLabel(); wait(2); return
    end
    local warnText=skipped and (" [no giver position for "..skipped.giverKey.."]") or ""
    -- Quest switch: the selection (level-up, forceLevel, boss toggle) differs
    -- from the quest this loop holds. Abandon it before travelling, or the new
    -- giver's StartQuest is refused and the old quest stays active. Within
    -- AFQ_SWITCH_COOLDOWN of the previous switch the held quest is kept, so a
    -- flapping selection cannot abandon/accept in a loop.
    local held=AFQ.current
    -- A held quest that is already complete (count reached, or its tracker
    -- went away after the accept) needs no abandon and no cooldown: the boss
    -- interleave switches to the boss only after the fallback quest is done,
    -- and back to the fallback after the boss quest's single kill.
    if held and not afq_sameQuest(held,q) and AFQ.accepted and AFQ.entry and afq_sameQuest(held,AFQ.entry)
        and (AFQ.kills>=AFQ.entry.count or afq_trackerGone(afq_trackerFrame())) then
        AFQ.current=nil; held=nil
    end
    if held and not afq_sameQuest(held,q) then
        local left=AFQ_SWITCH_COOLDOWN-(clock()-(AFQ.lastSwitch or -1e9))
        if left>0 then
            if AFQ.entry and afq_sameQuest(AFQ.entry,held) then
                warnText=warnText.." [switch to "..q.giverKey.." #"..q.questIndex.." in "..math.ceil(left).."s]"
                q=AFQ.entry
            else
                AFQ.status="Lv "..level..": quest switch cooldown ("..math.ceil(left).."s)"
                afq_updateLabel(); wait(0.5); return
            end
        elseif afq_remoteQuestOff() then
            -- Remote quest accept off (the default): no AbandonQuest. The
            -- dialogue accept at the new giver replaces the held quest; the
            -- held quest stays in AFQ.current until the tracker shows the new
            -- one (markAccepted), so a failed dialogue keeps it on record.
            AFQ_DEBUG.phase="switch"
            afq_logSwitch("Lv "..level..": switching "..held.giverKey.." #"..held.questIndex
                .." -> "..q.giverKey.." #"..q.questIndex.." (the dialogue accept replaces the old quest)")
            AFQ.lastSwitch=clock()
            AFQ.entry=nil
        else
            AFQ_DEBUG.phase="switch"
            afq_logSwitch("Lv "..level..": switching "..held.giverKey.." #"..held.questIndex
                .." -> "..q.giverKey.." #"..q.questIndex.." (abandoning the old quest)")
            AFQ.lastSwitch=clock()
            local okAbandon,why=afq_abandon()
            if not okAbandon then
                -- The held quest is kept (and farmed meanwhile, see the cooldown
                -- branch above); the next switch attempt waits a bounded backoff.
                AFQ.abandonFails=(AFQ.abandonFails or 0)+1
                local backoff=math.max(AFQ_SWITCH_COOLDOWN,afq_backoff(AFQ.abandonFails))
                AFQ.lastSwitch=clock()+backoff-AFQ_SWITCH_COOLDOWN
                afq_logSwitch("Lv "..level..": abandon of "..held.giverKey.." #"..held.questIndex
                    .." not confirmed ("..tostring(why).."), keeping it; retry in "..math.ceil(backoff).."s")
                afq_sleep(0.5)
                return
            end
            AFQ.abandonFails=0
            AFQ.entry=nil
            if not afq_farming() then return end
        end
    end
    local function setStatus(extra)
        -- A step that outlived its toggle must not overwrite the "off" status.
        if not afq_farming() then return end
        local mode=AFQ.bossMode
        local text
        if mode and q.boss and afq_sameQuest(q,AFQ.bossQuest) then
            text="Boss: "..q.enemy.." ("..(afq_bossAlive(q) and "alive" or "down")..", "..AFQ.kills.."/"..q.count..")"
        elseif mode=="pending" and afq_sameQuest(q,AFQ.bossFallback) then
            local left=math.max(0,math.ceil(AFQ_BOSS_MAX_WAIT-(clock()-(AFQ.bossUpAt or clock()))))
            text="Boss up: finishing "..q.enemy.." "..AFQ.kills.."/"..q.count.." then switching ("..left.."s left)"
        elseif mode and afq_sameQuest(q,AFQ.bossFallback) then
            text="Fallback: "..q.enemy.." "..AFQ.kills.."/"..q.count.." (boss down, polling)"
        else
            text=q.giverKey.." #"..q.questIndex.." - "..q.enemy.." ("..AFQ.kills.."/"..q.count..")"
        end
        AFQ.status="Lv "..level..": "..text..(extra or "")..warnText
        afq_updateLabel()
    end
    if AFQ.entry~=q then
        AFQ.entry=q; AFQ.kills=0; AFQ.accepted=false; AFQ.trackerSeen=false; AFQ.selectedNpc=nil
        AFQ.switchPending=false; AFQ.trackerMissingSince=nil
    end
    local tracker=afq_trackerFrame()
    local trackerGone=afq_trackerGone(tracker)
    if tracker then AFQ.trackerSeen=true end
    -- The tracker seen after the accept is missing, but not yet for
    -- AFQ_TRACKER_GONE_SECS: look again shortly instead of fighting on.
    if AFQ.accepted and AFQ.trackerSeen and not tracker and not trackerGone then
        setStatus(" (checking the quest tracker)")
        afq_sleep(0.5)
        return
    end
    -- The tracker already shows the selected quest (accepted before the toggle
    -- went on, or by the player): hold it, no giver trip.
    if not AFQ.accepted and tracker and afq_trackerQuestIs(q)=="same" then
        AFQ.accepted=true; AFQ.current={giverKey=q.giverKey,questIndex=q.questIndex}
        local k=afq_trackerProgress(); if k then AFQ.kills=k end
        setStatus(" (already active)")
    end
    -- Re-accept when nothing is accepted yet, the local count is complete, or
    -- the tracker that was seen after the accept has gone (quest completed).
    local completed=AFQ.accepted and (AFQ.kills>=q.count or trackerGone)
    local needAccept=not AFQ.accepted or completed
    if needAccept then
        if completed then AFQ.current=nil end -- the held quest is done
        AFQ.kills=0
        -- Level re-check plus the one-active-quest guard, run right before
        -- every StartQuest. The completed quest's EXP can level the player
        -- after this step's first read: a different pick goes back through
        -- the top of afq_step (switch/travel). Another quest the tracker shows
        -- (or a different one this loop still holds) is abandoned first.
        -- False when this step should return.
        local function preAccept()
            local freshLevel=afq_level()
            local fresh=freshLevel and afq_select(freshLevel) or nil
            if fresh and not afq_sameQuest(fresh,q) then
                AFQ.status="Lv "..freshLevel..": "..fresh.giverKey.." #"..fresh.questIndex.." selected before accepting "
                    ..q.giverKey.." #"..q.questIndex
                afq_updateLabel()
                AFQ.entry=nil
                return false
            end
            -- Dialogue path (remote off): the accept replaces whatever quest
            -- is active, so there is nothing to abandon first.
            if afq_remoteQuestOff() then return true end
            if afq_trackerQuestIs(q)=="other" or (AFQ.current and not afq_sameQuest(AFQ.current,q)) then
                AFQ_DEBUG.phase="abandon"
                afq_logSwitch("Lv "..tostring(freshLevel or level)..": another quest is active, abandoning it before "
                    ..q.giverKey.." #"..q.questIndex)
                AFQ.lastSwitch=clock()
                local okAbandon,why=afq_abandon()
                if not okAbandon then
                    AFQ.abandonFails=(AFQ.abandonFails or 0)+1
                    local backoff=math.max(AFQ_SWITCH_COOLDOWN,afq_backoff(AFQ.abandonFails))
                    AFQ.lastSwitch=clock()+backoff-AFQ_SWITCH_COOLDOWN
                    afq_logSwitch("Lv "..tostring(freshLevel or level)..": abandon not confirmed ("..tostring(why)
                        .."); retry in "..math.ceil(backoff).."s")
                    afq_sleep(math.min(backoff,1))
                    return false
                end
                AFQ.abandonFails=0
                if not afq_farming() then return false end
            end
            return true
        end
        local function markAccepted(seen)
            AFQ.accepted=true; AFQ.trackerSeen=seen and true or false
            AFQ.trackerMissingSince=nil
            AFQ.current={giverKey=q.giverKey,questIndex=q.questIndex}
        end
        -- Dedupe: never send StartQuest while the tracker already shows q.
        local function adoptIfShown()
            if afq_trackerQuestIs(q)=="same" then
                markAccepted(true)
                local k=afq_trackerProgress(); AFQ.kills=k or 0
                setStatus(" (already active)")
                return true
            end
            return false
        end
        -- Remote quest accept on: StartQuest is accepted from anywhere (seen
        -- live from 289 studs in Underwater City and across Upper Skylands),
        -- so accept where the character stands and go straight to the wait
        -- spot. Under Matcha the invoke returns only a boolean, so the
        -- tracker showing q (afq_waitTrackerFor) is the proof of acceptance.
        -- No proof within AFQ_REMOTE_ACCEPT_WAIT: fall back once to the giver
        -- trip below.
        -- Remote quest accept off (the default since Oct 15 2026, or
        -- AFQ_DEBUG.remoteAcceptOff): no StartQuest at all; accept at the
        -- giver through the dialogue instead.
        local viaGiver=afq_remoteQuestOff()
        local fallback=false
        if not viaGiver then
            setStatus(" accepting (remote)")
            if not preAccept() then return end
            if adoptIfShown() then return end
            local gate=afq_acceptWait(q)
            if gate>0 then
                setStatus(" accepting in "..math.ceil(gate).."s")
                afq_sleep(math.min(gate,1))
                return
            end
            AFQ_DEBUG.phase="accept"
            local beforeKey=afq_trackerKey()
            local ok,reason=true,nil
            -- From the step thread, after every hold/tween of this step has
            -- returned; quietInvoke pauses all other part writes and remotes.
            if not AFQ_DEBUG.noAccept then ok,reason=afl_startQuestRemote(q.giverKey,q.questIndex) end
            local shown=AFQ_DEBUG.noAccept or (ok and afq_waitTrackerFor(q,AFQ_REMOTE_ACCEPT_WAIT,beforeKey))
            if not afq_farming() then return end
            if shown then
                markAccepted(not AFQ_DEBUG.noAccept)
                AFQ.acceptFails=0
            else
                viaGiver=true; fallback=true
                local why=ok and ("tracker did not show "..q.enemy.." within "..AFQ_REMOTE_ACCEPT_WAIT.."s")
                    or tostring(reason)
                setStatus(" accepting at giver (fallback)")
                warnThrottled("questRemoteAFQ","[laced.club] Auto Farm Quest: remote accept of "..q.giverKey
                    .." #"..q.questIndex.." not confirmed ("..why.."); accepting at the giver instead",30)
            end
        end
        if viaGiver then
            -- Remote accept off (the default: dialogue accept), or the remote
            -- fallback above: travel to the giver and accept there.
            local dialogue=afq_remoteQuestOff()
            if not fallback then setStatus(dialogue and " accepting (dialogue)" or " accepting") end
            -- The dialogue clicks need Roblox in front: do not fly to the giver
            -- for a click that cannot be sent; look again in a second.
            if dialogue and not AFQ_DEBUG.noAccept and not robloxFocused() then
                setStatus(" accept waiting: focus the Roblox window (dialogue accept)")
                warnThrottled("questDialogueFocus","[laced.club] Auto Farm Quest: Remote quest accept is off, so the quest is "
                    .."accepted through the giver dialogue, which needs the Roblox window in front",30)
                afq_sleep(1); return
            end
            -- No travel while the remote is known to be failing: wait for the
            -- next probe (one call per backoff period, see below) instead.
            if not dialogue and not AFQ_DEBUG.noAccept and remoteFailing("StartQuest") then
                AFQ.acceptFails=(AFQ.acceptFails or 0)+1
                local backoff=afq_backoff(AFQ.acceptFails)
                setStatus(" accept failed: StartQuest remote keeps failing (retry in "..math.ceil(backoff).."s)")
                RemoteFailures["StartQuest"]=REMOTE_FAILURE_LIMIT-1 -- allows one probe after the backoff
                afq_sleep(backoff); return
            end
            AFQ_DEBUG.phase="tween-giver"
            local giverPos=AFQ.giverPos[q.giverKey]
            local atGiver=afq_teleportTo(giverPos)
            if not afq_farming() then return end
            if atGiver then afq_holdAt(giverPos,0.5) else afq_sleep(0.5) end
            if not afq_farming() then return end -- toggled off during the wait: do not accept
            if not preAccept() then return end
            if adoptIfShown() then return end
            -- Wait out the rate limit / switch cooldown at the giver (holding)
            -- rather than failing the fallback right after the remote try.
            -- The dialogue sends no remote from this script: no gate (the
            -- switch cooldown still applies to the switch decision itself).
            local gate=dialogue and 0 or afq_acceptWait(q)
            if gate>0 then
                setStatus(" accepting at the giver in "..math.ceil(gate).."s")
                if atGiver then afq_holdAt(giverPos,gate) else afq_sleep(gate) end
                if not afq_farming() then return end
                if adoptIfShown() then return end
            end
            AFQ_DEBUG.phase=fallback and "accept-fallback" or "accept"
            local beforeKey=afq_trackerKey()
            local ok,reason=true,nil
            if AFQ_DEBUG.noAccept then -- isolation run: no accept at all
            elseif dialogue then ok,reason=afq_acceptByDialogue(q)
            else ok,reason=afl_startQuestRemote(q.giverKey,q.questIndex) end
            -- The boolean result is not proof: the tracker has to show q (the
            -- giver path used to mark the quest accepted without any check).
            local shown=AFQ_DEBUG.noAccept or (ok and afq_waitTrackerFor(q,AFQ_REMOTE_ACCEPT_WAIT,beforeKey))
            if not afq_farming() then return end
            if not shown then
                AFQ.accepted=false
                AFQ.acceptFails=(AFQ.acceptFails or 0)+1
                local backoff=afq_backoff(AFQ.acceptFails)
                local why=ok and ("the tracker did not show "..q.enemy
                    ..((dialogue and AFQ.current and not afq_sameQuest(AFQ.current,q)) and " (the old quest may still be active)" or "")) or tostring(reason)
                setStatus(" accept failed: "..why.." (retry in "..math.ceil(backoff).."s)")
                warnThrottled("questFarm","[laced.club] Auto Farm Quest: accept of "..q.giverKey.." #"..q.questIndex
                    .." failed ("..why.."); retry in "..math.ceil(backoff).."s",30)
                if remoteFailing("StartQuest") then RemoteFailures["StartQuest"]=REMOTE_FAILURE_LIMIT-1 end
                afq_sleep(backoff); return
            end
            AFQ.acceptFails=0
            markAccepted(not AFQ_DEBUG.noAccept)
            if atGiver then afq_holdAt(giverPos,0.5) else afq_sleep(0.5) end
            if not afq_farming() then return end
        end
        -- Travel to the wait (or boss) spot. afq_teleportTo picks the island
        -- enter/leave step (Underwater City pads) from the current position
        -- and this destination, so the island change happens on this leg when
        -- the giver trip was skipped.
        AFQ_DEBUG.phase="tween-wait"
        if q.boss then afq_goToBoss(q) else afq_goToWait(q) end
        setStatus()
        AFQ_DEBUG.phase="after-wait"
        return
    end
    if AFQ_DEBUG.noFight then AFQ_DEBUG.phase="nofight-idle"; setStatus(" (fight disabled)"); wait(0.5); return end
    AFQ_DEBUG.phase="scan"
    if AFQ.selectedNpc then
        local okName,npcName=pcall(function() return string.lower(AFQ.selectedNpc.Name) end)
        if not okName or not string.find(npcName,string.lower(afq_enemyName(q)),1,true) then AFQ.selectedNpc=nil end
    end
    if not AFQ.selectedNpc or not partStillThere(AFQ.selectedNpc) then
        local attempts=0
        -- Hold where the scan starts (usually the wait spot) instead of
        -- falling for the ~0.8 s the scan takes.
        local _,scanRoot=afl_getCharacter()
        local okScan,scanPos=pcall(function() return scanRoot and scanRoot.Position end)
        if not okScan or not scanPos or not scanPos.X then scanPos=nil end
        -- Speed restore: the 0.05 s hold only while nothing is found (it
        -- also ran after a successful pick, delaying every next target).
        repeat
            AFQ.selectedNpc=afq_nearestEnemy(q); attempts=attempts+1
            if AFQ.selectedNpc then break end
            if scanPos then afq_holdAt(scanPos,0.05) else wait(0.05) end
        until attempts>15 or not afq_farming()
        if not AFQ.selectedNpc then
            setStatus(" waiting for spawn")
            local arrived,spot=false,nil
            if q.boss then
                arrived,spot=afq_goToBoss(q)
                -- Boss interleave: at the boss spot with no living boss in
                -- Workspace.Enemies three times in a row (~4 s), count it as
                -- down (parked model ignored for 30 s): the fallback resumes.
                if arrived and AFQ.bossMode and afq_farming() then
                    local _,inEnemies=afq_bossFind(q)
                    AFQ.bossMisses=inEnemies and 0 or (AFQ.bossMisses or 0)+1
                    if AFQ.bossMisses>=3 then AFQ.bossMisses=0; afq_bossMarkDown(AFQ_BOSS_POLL*6) end
                end
            else
                arrived,spot=afq_goToWait(q)
            end
            -- 0.25 s (was 0.5): the next step scans again, so a spawn is seen
            -- at 4 Hz or better while waiting.
            if arrived and spot then afq_holdAt(spot,0.25) else wait(0.25) end
            return
        end
    end
    setStatus()
    AFQ_DEBUG.phase="fight"
    AFQ.bossMisses=0
    local killed=afq_fight(AFQ.selectedNpc)
    AFQ_DEBUG.phase="after-fight"
    if not afq_farming() then return end
    -- Not killed (50 s cap, own death, target gone): pick afresh next step.
    if killed then AFQ.kills=AFQ.kills+1 end
    AFQ.selectedNpc=nil
    local k=afq_trackerProgress()
    if k then AFQ.kills=k end
    -- Boss interleave: the boss is down, so the next afq_step picks the
    -- fallback quest at once (the completed boss quest needs no abandon).
    if killed and q.boss and AFQ.bossMode then afq_bossMarkDown(AFQ_BOSS_POLL*6) end
    setStatus()
end

task.spawn(function()
    while alive() do
        if S.autoFarmQuest and not farmPriorityFeatureActive() and not AFQ.loopRunning then
            AFQ.loopRunning=true
            AFQ.stepGen=AFQ.gen
            local ok,stepError=pcall(afq_step)
            AFQ.loopRunning=false
            if AFQ.activeHead then pcall(AFQ.activeHead.restore); AFQ.activeHead=nil end
            if not ok then
                warnThrottled("questFarm","[laced.club] Auto Farm Quest error: "..tostring(stepError),15)
                wait(0.5)
            end
        elseif AFQ.activeHead then
            pcall(AFQ.activeHead.restore); AFQ.activeHead=nil
        end
        -- Speed restore: one frame between steps while the farm runs (the
        -- next target is picked right after a kill; every step path yields
        -- by itself), IDLE_POLL (0.25 s) only while it is off. Was 0.3 s.
        idleWait(S.autoFarmQuest==true and not farmPriorityFeatureActive())
    end
end)

-- Unload: restore a head the Level Farm or Auto Farm Quest fight left
-- enlarged (their loops restore it too, at their next wake-up).
onShutdown(function()
    if AFQ.activeHead then pcall(AFQ.activeHead.restore); AFQ.activeHead=nil end
    if AFL.activeHead then pcall(AFL.activeHead.restore); AFL.activeHead=nil end
end)

-- (Two leftover per-type render loops for fruit and chest labels were removed
-- here after live testing: they ran alongside the shared loop below and fought
-- it over label visibility; the fruit one also indexed entry.part unguarded.)
-- One render loop for every ESP type (replaces six copy-pasted loops). Each
-- renderer runs in its own pcall so a vanished part cannot kill the others.
task.spawn(function()
    while alive() do
        local playerPos=localRootPosition()
        if S.fruitEsp then
            for _, entry in pairs(S.espLabels) do pcall(renderLabelEntry,entry,playerPos,nil,20) end
        end
        if S.chamEsp then
            for _, entry in pairs(S.chamBoxes) do pcall(renderChamEntry,entry,playerPos) end
        end
        if S.chestEsp then
            for _, entry in pairs(S.chestEspLabels) do pcall(renderLabelEntry,entry,playerPos,100000000,20) end
        end
        if S.berryEsp then
            for _, entry in pairs(S.berryEspLabels) do pcall(renderLabelEntry,entry,playerPos,BERRY_DRAW_DISTANCE_SQ,18) end
        end
        if S.boatEsp then
            for _, entry in pairs(S.boatEspEntries) do pcall(updateWorldBoxEntry,entry) end
        end
        if S.flowerEsp then
            for _, entry in pairs(S.flowerEspEntries) do pcall(updateWorldBoxEntry,entry) end
        end
        idleWait(S.fruitEsp or S.chamEsp or S.chestEsp or S.berryEsp or S.boatEsp or S.flowerEsp)
    end
end)

task.spawn(function()
    while alive() do
        task.wait(1)
        if S.berryEsp then pcall(buildBerryEspLabels) end
        if S.flowerEsp and trackedFlowersChanged() then pcall(buildFlowerEsp) end
    end
end)

task.spawn(function()
    while alive() do
        task.wait(2)
        if S.fruitEsp then
            -- One workspace scan feeds both the labels and the boxes.
            local okFruits,fruits=pcall(getWorkspaceFruits)
            if okFruits and fruits then
                pcall(buildEspLabels,fruits)
                pcall(buildChamBoxes,fruits)
            end
        end
        if S.chestEsp then
            local chestModels=Workspace:FindFirstChild("ChestModels")
            if trackedFolderChanged("chests",chestModels) then pcall(buildChestEspLabels) end
        end
        if S.boatEsp then
            local boats=Workspace:FindFirstChild("Boats")
            if trackedFolderChanged("boats",boats) then pcall(buildBoatEsp) end
        end
    end
end)

-- Load marker: this chunk ran to the end.
if LACED_LOAD and type(LACED_LOAD.done) == "table" then LACED_LOAD.done["60_afq"] = true end
