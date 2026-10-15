-- @chunk 20_ui2  (lines 1822-2950 of the single-file build)
local LACED_LOAD = type(_G.__lacedLoad) == "table" and _G.__lacedLoad or nil -- load marker (loader.lua)
if LACED_LOAD and type(LACED_LOAD.started) == "table" then LACED_LOAD.started["20_ui2"] = true end
-- Per-execution bindings: captured at chunk load so a re-run of the script
-- cannot make this copy's loops read the new copy's state (alive is a
-- closure over this run's state since the Oct 15 stability pass).
local alive = alive
local SCRIPT_STATE = SCRIPT_STATE
local S = S
local AFL = AFL
BOSS_OPTIONS={"The Gorilla King","Bobby","The Saw","Yeti","Mob Leader","Vice Admiral","Saber Expert","Warden","Chief Warden","Swan","Magma Admiral","Fishman Lord","Wysper","Thunder God","Cyborg","Ice Admiral","Greybeard","Diamond","Jeremy","Orbitus","Don Swan","Smoke Admiral","Awakened Ice Admiral","Tide Keeper","Darkbeard","Cursed Captain","Order","Stone","Hydra Leader","Kilo Admiral","Captain Elephant","Beautiful Pirate","Cake Queen","Dough King","Longma","Soul Reaper","rip_indra True Form","Tyrant of the Skies"}
MATERIAL_OPTIONS={"Leather + Scrap Metal","Angel Wings","Magma Ore","Fish Tail","Radioactive Material","Ectoplasm","Mystic Droplet","Vampire Fang","Demonic Wisp","Conjured Cocoa","Dragon Scale","Gunpowder","Mini Tusk"}
SEA_EVENT_OPTIONS={"Shark","Terrorshark","Piranha","Fish Crew Member","Haunted Crew Member"}

automationTab:AddSection("Boss and Materials",{Column=1})
automationTab:AddDropdown("boss_target",{
    Text="Boss",Options=BOSS_OPTIONS,Default=BOSS_OPTIONS[1],MaxVisible=8,Column=1,
    Callback=function(v) if type(v)=="string" then S.selectedBoss=v end end
})
automationTab:AddToggle("auto_boss_farm",{
    Text="Auto Farm Boss",Description="Tweens to and farms the selected spawned boss",Default=false,Column=1,
    Callback=function(v)
        S.autoBossFarm=v
        if v then Window:Set("auto_material_farm",false) end
    end
})
automationTab:AddDropdown("material_target",{
    Text="Material",Options=MATERIAL_OPTIONS,Default=MATERIAL_OPTIONS[1],MaxVisible=7,Column=1,
    Callback=function(v) if type(v)=="string" then S.selectedMaterial=v end end
})
automationTab:AddToggle("auto_material_farm",{
    Text="Auto Farm Material",Description="Farms enemies that drop the selected material",Default=false,Column=1,
    Callback=function(v)
        S.autoMaterialFarm=v
        if v then Window:Set("auto_boss_farm",false) end
    end
})

automationTab:AddSection("Automatic Stats",{Column=2})
automationTab:AddSlider("stat_amount",{
    Text="Points Per Upgrade",Min=1,Max=1000,Step=1,Default=10,Integer=true,Column=2,
    Callback=function(v) S.statAmount=math.max(1,math.floor(tonumber(v) or 10)) end
})
S.statStatusLabel=automationTab:AddLabel("stat_status",{Text="Pts ? | reading stats...",Column=2})
-- {toggle id, label, toggle state key, cap slider id, cap state key}
for _,entry in ipairs({{"stat_melee","Melee","autoStatMelee","stat_cap_melee","statCapMelee"},{"stat_defense","Defense","autoStatDefense","stat_cap_defense","statCapDefense"},{"stat_sword","Sword","autoStatSword","stat_cap_sword","statCapSword"},{"stat_gun","Gun","autoStatGun","stat_cap_gun","statCapGun"},{"stat_fruit","Blox Fruit","autoStatFruit","stat_cap_fruit","statCapFruit"}}) do
    local controlId=entry[1]
    local label=entry[2]
    local stateKey=entry[3]
    local capKey=entry[5]
    automationTab:AddToggle(controlId,{
        Text="Auto "..label,Default=false,Column=2,
        Callback=function(v) S[stateKey]=v end
    })
    automationTab:AddSlider(entry[4],{
        Text=label.." Cap",Description="Stop adding points to "..label.." once its level reaches this value. 0 = no cap (unlimited).",
        Min=0,Max=2600,Step=25,Default=0,Integer=true,Column=2,
        Callback=function(v) S[capKey]=math.max(0,math.floor(tonumber(v) or 0)) end
    })
end

automationTab:AddSection("Sea Events",{Column=1})
automationTab:AddDropdown("sea_event_target",{
    Text="Sea Target",Options=SEA_EVENT_OPTIONS,Default=SEA_EVENT_OPTIONS[1],MaxVisible=5,Column=1,
    Callback=function(v) if type(v)=="string" then S.selectedSeaEvent=v end end
})
automationTab:AddToggle("auto_sea_event",{
    Text="Auto Farm Sea Target",Description="Tweens to and attacks the selected spawned sea enemy",Default=false,Column=1,
    Callback=function(v) S.autoSeaEvent=v end
})

miscTab:AddSection("Mirage",{Column=2})
miscTab:AddToggle("mirage_esp",{
    Text="Mirage ESP",Description="Shows the Mirage Island location",Default=false,Column=2,
    -- clearMirageEsp is defined by 80_misc2: guarded in case UE applies a
    -- config while the later chunks are still loading.
    Callback=function(v) S.mirageEsp=v; if not v and type(clearMirageEsp)=="function" then clearMirageEsp() end end
})
miscTab:AddToggle("auto_mirage_tween",{
    Text="Tween to Mirage",Description="Tweens above Mirage Island when it exists",Default=false,Column=2,
    Callback=function(v) S.autoMirageTween=v end
})
miscTab:AddToggle("auto_mirage_gear",{
    Text="Collect Mirage Gear",Description="Finds and tweens to the visible Mirage gear",Default=false,Column=2,
    Callback=function(v) S.autoMirageGear=v end
})

miscTab:AddSection("World Status",{Column=2})
miscTab:AddButton("check_events",{Text="Check Event Islands",Column=2,Callback=function() if type(showEventStatus)=="function" then showEventStatus() end end})
miscTab:AddButton("check_bosses",{Text="Check Important Bosses",Column=2,Callback=function() if type(showBossStatus)=="function" then showBossStatus() end end})
miscTab:AddButton("check_swords",{Text="Check Legendary Sword Dealer",Column=2,Callback=function() task.spawn(function() if type(showLegendarySwordStatus)=="function" then showLegendarySwordStatus() end end) end})

task.spawn(function()
    task.wait(0.2)
    Window.Indicator:SetVisible(false)
    Window.Config.IndicatorEnabled = false
end)

mainTab:AddSection("Farming", { Column = 1 })

mainTab:AddToggle("auto_farm_nearest", {
    Text="Auto Farm Nearest", Description="Farms the nearest enemy (load chests/enemies first!)",
    Default=false, Keybind=true, Column=1,
    Callback=function(v) S.autoFarmNearest=v; notify(v and "Auto Farm Nearest ON!" or "Auto Farm Nearest OFF!","laced.club",2) end
})

mainTab:AddToggle("remote_mode", {
    Text="Remote M1 (no clicks)", Description="Attacks with RegisterAttack + RegisterHit instead of mouse clicks, so Roblox does not need focus. Hits the target plus up to 9 enemies within 60 studs. Needs Matcha Pro (Hybrid); turns itself off and falls back to clicks if the remotes keep failing.",
    Default=true, Column=1,
    Callback=function(v)
        S.remoteMode=v
        -- Give a manual re-enable a fresh chance before the auto fallback trips again.
        if v then RemoteFailures["RegisterAttack"]=0; RemoteFailures["RegisterHit"]=0 end
        notify(v and "Remote Mode ON! (RegisterHit aura)" or "Remote Mode OFF! (back to click farm)","laced.club",2)
    end
})

-- Speed restore (Oct 15 2026): remote M1 rate, 10 swings/s by default (the
-- stability pass had capped it at 4). BasicM1 (40_combat) is defined after
-- this chunk, so the value goes through S: S.onAttackRate is installed by
-- 40_combat and applies it to BasicM1.minInterval; 40_combat also reads
-- S.attackRate when it loads.
mainTab:AddSlider("attack_rate", {
    Text="Remote M1 swings/s", Description="Remote M1 swing rate (RegisterAttack + RegisterHit per swing), per attack source. Default 10. Safe mode (AFQ_DEBUG.safeMode) halves it.",
    Min=2, Max=20, Step=1, Default=10, Integer=true, Column=1,
    Callback=function(v)
        S.attackRate=math.max(2,math.min(20,math.floor(tonumber(v) or 10)))
        if type(S.onAttackRate)=="function" then pcall(S.onAttackRate,S.attackRate) end
    end
})

mainTab:AddToggle("auto_farm_chest", {
    Text="Auto Farm Chest", Description="Automatically farms chests (load them in first!)",
    Default=false, Column=1,
    Callback=function(v) S.autoFarming=v; S.handledChests={}; if v then S.chestIndex=1 end; notify(v and "Auto Farm Chest ON!" or "Auto Farm Chest OFF!","laced.club",2) end
})

otherTab:AddPriorityList("chest_priority", {
    Text="Chest Priority",
    Description="Reorder chest types from highest to lowest priority",
    Options={"Diamond","Gold","Silver"},
    Default={"Diamond","Gold","Silver"},
    MaxVisible=3,
    Column=1,
    Callback=function(order)
        if type(order)~="table" then return end
        local nextOrder={}
        for _,chestType in ipairs(order) do
            if chestType=="Diamond" or chestType=="Gold" or chestType=="Silver" then
                table.insert(nextOrder,chestType)
            end
        end
        if #nextOrder==3 then S.chestPriority=nextOrder end
    end
})

mainTab:AddToggle("auto_farm_fruits", {
    Text="Auto Farm Fruits", Description="Tweens to the nearest fruit and farms it",
    Default=false, Column=1,
    Callback=function(v)
        S.autoFruits=v
        if not v then S.fruitPriorityActive=false end
        notify(v and "Auto Farm Fruits ON! (interrupts only when fruit is found)" or "Auto Farm Fruits OFF!","laced.club",2)
    end
})

mainTab:AddToggle("auto_dino_bone", {
    Text="Auto DinoBone", Description="Teleports to every Workspace.DinoBone until it disappears",
    Default=false, Column=1,
    Callback=function(v)
        S.autoDinoBone=v
        notify(v and "Auto DinoBone ON!" or "Auto DinoBone OFF!","laced.club",2)
    end
})

mainTab:AddToggle("auto_race_ability",{
    Text="Auto Race Ability",Description="Keeps sending the race ability activation remote",Default=false,Column=1,
    Callback=function(v) S.autoRaceAbility=v end
})

mainTab:AddSection("NPC Farm", { Column = 1 })

mainTab:AddToggle("auto_npc_farm", {
    Text="Auto NPC Farm", Description="Farms NPCs on the selected island",
    Default=false, Column=1,
    Callback=function(v) S.autoNpcFarm=v; notify(v and "Auto NPC Farm ON!" or "Auto NPC Farm OFF!","laced.club",2) end
})

mainTab:AddDropdown("npc_island", {
    Text="NPC Island", Description="Select which island to farm NPCs on",
    Options=islandNames, Default=islandNames[1], MaxVisible=6, Column=1,
    Callback=function(v)
        for i, isle in pairs(islandList) do
            if isle.name == v then S.selectedIsland=i; break end
        end
        notify("Island: "..tostring(v),"laced.club",1)
    end
})

mainTab:AddToggle("auto_farm_level", {
    Text="Auto Farm Level", Description="Farms mobs based on your current level (quest giver must be loaded!)",
    Default=false, Column=1,
    Callback=function(v)
        S.autoFarmLevel=v
        if v then pcall(function() AFL.lastLevel=afl_readLevel() or 0 end) end
        notify(v and "Auto Farm Level ON!" or "Auto Farm Level OFF!","laced.club",2)
    end
})

mainTab:AddToggle("afl_remote_quest", {
    Text="Remote quest accept", Description="Accept quests with the StartQuest remote. OFF by default: on Matcha Hybrid this remote was found to crash the client (Oct 15 2026). Needs Roblox focused when off.",
    Default=false, Column=1,
    Callback=function(v)
        AFL.useRemoteQuest=v
        -- Give a manual re-enable a fresh chance before the click fallback trips again.
        if v then RemoteFailures["StartQuest"]=0 end
        notify(v and "Remote quest accept ON!" or "Remote quest accept OFF! (dialogue clicks)","laced.club",2)
    end
})

-- Auto Farm Quest state and status-line writer (the loop itself is defined
-- after the Level Farm loop; the toggle callbacks below only touch these).
-- current = {giverKey, questIndex} of the quest this loop holds on the server
-- (set on accept or when the tracker already shows the selected quest,
-- cleared on completion and abandon). It survives a toggle off/on because the
-- quest stays active on the server. lastSwitch/switchPending: see afq_step.
AFQ = {
    entry=nil, kills=0, accepted=false, trackerSeen=false, status="off",
    activeHead=nil, loopRunning=false, selectedNpc=nil, giverPos={}, waitKey={},
    current=nil, lastSwitch=-1e9, switchPending=false,
    -- boss interleave (see afq_bossDecide): bossMode nil/"boss"/"fallback"/
    -- "pending", the boss quest and its fallback mob quest, the cached boss
    -- scan, when the boss was seen up while the fallback was held, empty
    -- scans at the boss spot, and until when a parked model is ignored.
    bossMode=nil, bossQuest=nil, bossFallback=nil, bossAlive=false, bossPolledFor=nil,
    bossPollAt=-1e9, bossUpAt=nil, bossMisses=0, bossRsIgnoreUntil=0,
    -- stability pass (Oct 15 2026): gen is bumped by the toggle callback and a
    -- running step stops when it no longer matches stepGen (quick off/on);
    -- acceptFails/abandonFails drive the bounded retry backoff (retryAt);
    -- npcBlock holds enemies that survived a 50 s fight (key -> until);
    -- trackerMissingSince debounces "tracker gone = quest completed".
    gen=0, stepGen=0, acceptFails=0, abandonFails=0, retryAt=0, npcBlock={},
    trackerMissingSince=nil,
}
local AFQ = AFQ -- this run's table for the callbacks below
AFQ_SWITCH_COOLDOWN=6       -- s between two quest switches (stops a flapping selection)
AFQ_LEVEL_CHECK_INTERVAL=3  -- s between the level reads inside a fight
AFQ_WAIT_HEIGHT=24          -- studs a derived wait spot sits above the spawn centroid
AFQ_WAIT_STALE_DIST=500     -- a static wait spot this far from the spawn centroid is stale
AFQ_BOSS_POLL=5             -- s between two boss presence scans (boss interleave)
AFQ_BOSS_MAX_WAIT=180       -- s an unfinished quest may delay the switch to a respawned boss
S.autoFarmQuest=false
S.questFarmBosses=false
AFQ_STATUS_LABEL=nil   -- set when the UI builds the status line below
-- Isolation switches for live testing (all false in normal use). phase is
-- written by afq_step/afq_fight so a heartbeat probe can report it.
-- forceLevel (nil in normal use): a number makes afq_level(), the level the
-- quest selector uses, return it instead of LocalPlayer.Data.Level.Value, so
-- the quest switch on level-up can be tested without levelling.
-- forceBossAlive (nil in normal use): true/false replaces the boss presence
-- scan of the boss interleave (afq_bossAlive), so the boss-up/boss-down
-- transitions can be tested without waiting for a real respawn.
-- safeMode (false in normal use): true doubles every bridge-write / swing
-- interval (root lock, holdAt, tween step, head expander, BasicM1, clicks)
-- for A/B crash tests.
-- quietAccept (true in normal use): every CommF_ invoke (StartQuest,
-- AbandonQuest, AddPoint) gets the quiet window of quietInvoke (00_core);
-- false skips the quiet window for A/B tests (the remotes stay serialised).
-- remoteAcceptOff (false in normal use): true sends no StartQuest and no
-- AbandonQuest at all: Auto Farm Quest accepts at the giver through the
-- dialogue (needs Roblox in front), Level Farm clicks its dialogue. A/B test
-- for the user-reported crash on the remote quest pickup (CHANGES.md); the
-- user's A/B run (Oct 15 2026) confirmed the remote as the crash trigger.
-- Since then the user-facing switch is the "Remote quest accept" toggle
-- (afl_remote_quest, AFL.useRemoteQuest), OFF by default, which does the
-- same; remoteAcceptOff stays as a hard override that wins even when the
-- toggle is on (afq_remoteQuestOff in 60_afq).
AFQ_DEBUG={noAccept=false,noFight=false,noHead=false,noLock=false,noClick=false,forceLevel=nil,forceBossAlive=nil,phase="idle",safeMode=false,
    quietAccept=true,remoteAcceptOff=false}
WRITE_BUDGET.debug=AFQ_DEBUG -- writeInterval() (00_core) reads safeMode through this link

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
end

mainTab:AddSection("Auto Farm Quest", { Column = 1 })

mainTab:AddToggle("auto_farm_quest", {
    Text="Auto Farm Quest", Description="Picks the highest quest your level allows in this sea (QUEST_LEVELS), accepts it with the StartQuest remote, farms its enemies and re-selects after each completed quest. Takes priority over the other farms.",
    Default=false, Column=1,
    Callback=function(v)
        S.autoFarmQuest=v
        -- A step still running from before this toggle stops at its next check.
        if AFQ then AFQ.gen=(AFQ.gen or 0)+1 end
        if v then
            RemoteFailures["StartQuest"]=0; RemoteFailures["AbandonQuest"]=0
            if AFQ then
                AFQ.entry=nil; AFQ.kills=0; AFQ.switchPending=false; AFQ.bossUpAt=nil; AFQ.bossMisses=0; AFQ.bossPollAt=-1e9
                AFQ.acceptFails=0; AFQ.abandonFails=0; AFQ.retryAt=0; AFQ.npcBlock={}; AFQ.trackerMissingSince=nil
            end
        else
            if AFQ then AFQ.entry=nil; AFQ.kills=0; AFQ.switchPending=false; AFQ.bossUpAt=nil; AFQ.bossMisses=0; AFQ.bossMode=nil; AFQ.status="off"; pcall(afq_updateLabel) end
        end
        notify(v and "Auto Farm Quest ON!" or "Auto Farm Quest OFF!","laced.club",2)
    end
})

mainTab:AddToggle("quest_farm_bosses", {
    Text="Include boss quests", Description="Lets Auto Farm Quest pick single-kill boss quests too: it kills the boss while it is up and farms the level's best mob quest while it respawns (off: only mob quests)",
    Default=false, Column=1,
    Callback=function(v)
        S.questFarmBosses=v
        if AFQ then AFQ.bossMode=nil; AFQ.bossUpAt=nil; AFQ.bossMisses=0; AFQ.bossPollAt=-1e9 end
    end
})

AFQ_STATUS_LABEL=mainTab:AddLabel("auto_farm_quest_status", { Text="Auto Farm Quest: off", Column=1 })

otherTab:AddSection("Custom NPC Offset", { Column = 2 })

otherTab:AddToggle("custom_offset", {
    Text="Custom NPC Offset", Description="Use custom XYZ offset when positioning on NPCs",
    Default=false, Column=2,
    Callback=function(v)
        S.customOffset=v
        notify(v and "Custom Offset ON!" or "Custom Offset OFF!","laced.club",2)
    end
})

otherTab:AddSlider("offset_x", {
    Text="Offset X", Description="X offset from enemy position",
    Min=-100, Max=100, Default=0, Decimals=1, Column=2,
    Callback=function(v) S.customOffsetX=v end
})

otherTab:AddSlider("offset_y", {
    Text="Offset Y", Description="Y offset from enemy position",
    Min=-100, Max=100, Default=23, Decimals=1, Column=2,
    Callback=function(v) S.customOffsetY=v end
})

otherTab:AddSlider("offset_z", {
    Text="Offset Z", Description="Z offset from enemy position",
    Min=-100, Max=100, Default=0, Decimals=1, Column=2,
    Callback=function(v) S.customOffsetZ=v end
})

mainTab:AddSection("Weapon Selection", { Column = 2 })

mainTab:AddDropdown("weapon_slot", {
    Text="Weapon Slot", Description="Hotbar key your farming weapon is on (1-9, 0)",
    Options={"1","2","3","4","5","6","7","8","9","0"}, Default=tostring(S.weaponSlot or 1), Column=2,
    Callback=function(v)
        local slot=tonumber(v)
        if slot then S.weaponSlot=slot end
    end
})

miscTab:AddSection("ESP", { Column = 1 })

miscTab:AddToggle("fruit_esp", {
    Text="Fruit ESP", Description="Shows drawing ESP with the fruit name and nearest island",
    Default=false, Column=1,
    Callback=function(v)
        S.fruitEsp=v; S.chamEsp=v
        if v then
            if type(buildEspLabels)=="function" then buildEspLabels() end
            if type(buildChamBoxes)=="function" then buildChamBoxes() end
        else clearEspLabels(); clearChamBoxes() end
        notify(v and "Fruit ESP On!" or "Fruit ESP Off!","laced.club",2)
    end
})

miscTab:AddToggle("chest_esp", {
    Text="Chest ESP", Description="Shows a text label on every spawned chest",
    Default=false, Column=1,
    Callback=function(v)
        S.chestEsp=v
        if v then if type(buildChestEspLabels)=="function" then buildChestEspLabels() end else clearChestEspLabels() end
        notify(v and "Chest ESP On!" or "Chest ESP Off!","laced.club",2)
    end
})

miscTab:AddToggle("berry_esp", {
    Text="Berry Esp", Description="Shows map berries at 60 Hz with an optimized one-second rescan",
    Default=false, Column=1,
    Callback=function(v)
        S.berryEsp=v
        if v then if type(buildBerryEspLabels)=="function" then buildBerryEspLabels(true) end else clearBerryEspLabels() end
        notify(v and "Berry Esp On!" or "Berry Esp Off!","laced.club",2)
    end
})

miscTab:AddToggle("boat_esp", {
    Text="Boat ESP", Description="Draws a full 3D box around each on-screen boat",
    Default=false, Column=1,
    Callback=function(v)
        S.boatEsp=v
        if v then if type(buildBoatEsp)=="function" then buildBoatEsp() end else clearBoatEsp() end
        notify(v and "Boat ESP On!" or "Boat ESP Off!","laced.club",2)
    end
})

miscTab:AddToggle("flower_esp", {
    Text="Flower Esp", Description="Shows a label and a 3d box around all flowers, 2ND SEA",
    Default=false, Column=1,
    Callback=function(v)
        S.flowerEsp=v
        if v then if type(buildFlowerEsp)=="function" then buildFlowerEsp() end else clearFlowerEsp() end
        notify(v and "Flower Esp On!" or "Flower Esp Off!","laced.club",2)
    end
})

miscTab:AddSection("Combat", { Column = 1 })

miscTab:AddToggle("big_hitbox", {
    Text="Big Hitbox", Description="Expands enemy HumanoidRootPart size for easier hits",
    Default=false, Column=1,
    Callback=function(v) S.bigHitbox=v; notify(v and "Big Hitbox ON!" or "Big Hitbox OFF!","laced.club",2) end
})

miscTab:AddToggle("pull_enemies", {
    Text="Pull Enemies", Description="Pulls all enemies to one point under you",
    Default=false, Column=1,
    Callback=function(v) S.pullEnemies=v; notify(v and "Pull Enemies ON!" or "Pull Enemies OFF!","laced.club",2) end
})

miscTab:AddToggle("buddha_pull", {
    Text="Buddha Pull", Description="Pulls all enemies to X=40 under you",
    Default=false, Column=1,
    Callback=function(v) S.buddhaPull=v; notify(v and "Buddha Pull ON!" or "Buddha Pull OFF!","laced.club",2) end
})

miscTab:AddToggle("auto_ken", {
    Text="Auto Ken", Description="Automatically keeps Ken (Observation Haki) active",
    Default=false, Keybind=true, Column=1,
    Callback=function(v) S.autoKen=v; notify(v and "Auto Ken ON!" or "Auto Ken OFF!","laced.club",2) end
})

miscTab:AddToggle("auto_haki", {
    Text="Auto Haki", Description="Automatically keeps Armament Haki active",
    Default=false, Column=1,
    Callback=function(v) S.autoHaki=v; notify(v and "Auto Haki ON!" or "Auto Haki OFF!","laced.club",2) end
})

miscTab:AddToggle("freeze_pos", {
    Text="Freeze Position", Description="Locks your character in place",
    Default=false, Column=1,
    Callback=function(v)
        S.freezePos=v
        if v then
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if hrp then S.freezePosition=hrp.Position end
        else
            S.freezePosition=nil
        end
        notify(v and "Freeze ON!" or "Freeze OFF!","laced.club",2)
    end
})

miscTab:AddToggle("freeze_enemies", {
    Text="Freeze Enemies", Description="Locks all enemies in place (auto-catches new spawns)",
    Default=false, Column=1,
    Callback=function(v)
        S.freezeEnemies=v
        S.frozenEnemies={}
        if v then
            local folder=Workspace:FindFirstChild("Enemies")
            if folder then
                for _, model in pairs(folder:GetChildren()) do
                    if isA(model,"Model") then
                        local hrp=model:FindFirstChild("HumanoidRootPart")
                        if hrp then S.frozenEnemies[instKey(model)]={model=model,position=hrp.Position} end
                    end
                end
            end
        end
        notify(v and "Freeze Enemies ON!" or "Freeze Enemies OFF!","laced.club",2)
    end
})

miscTab:AddToggle("tween_ember", {
    Text="Auto Tween Dragon Ember", Description="Quickly tweens to Workspace EmberTemplate objects",
    Default=false, Column=1,
    Callback=function(v) S.tweenEmber=v; notify(v and "Auto Tween Dragon Ember ON!" or "Auto Tween Dragon Ember OFF!","laced.club",2) end
})

miscTab:AddToggle("teleport_ember", {
    Text="Auto Tp Azure Embers", Description="Auto tps to azure embers",
    Default=false, Column=1,
    Callback=function(v) S.teleportEmber=v; notify(v and "Auto Tp Azure Embers ON!" or "Auto Tp Azure Embers OFF!","laced.club",2) end
})

miscTab:AddToggle("teleport_kitsune", {
    Text="Goto Kitsune Island", Description="Tweens to Kitsune Island shrine (2s scan)",
    Default=false, Column=1,
    Callback=function(v) S.teleportKitsune=v; notify(v and "Goto Kitsune Island ON!" or "Goto Kitsune Island OFF!","laced.club",2) end
})

miscTab:AddSection("Sea", { Column = 2 })

boatSeatOptions={"No boats found"}
boatSeatByLabel={}
lastBoatSeatSignature=""
boatSeatDropdown=nil

function findBoatVehicleSeat(boat)
    if not boat then return nil end
    local okDirect,directSeat=pcall(function() return boat:FindFirstChildOfClass("VehicleSeat") end)
    if okDirect and directSeat then return directSeat end
    local okDescendants,descendants=pcall(function() return boat:GetDescendants() end)
    if okDescendants and descendants then
        for _,object in pairs(descendants) do
            local okClass,className=pcall(function() return object.ClassName end)
            if okClass and className=="VehicleSeat" then return object end
        end
    end
    return nil
end

function refreshBoatSeatList()
    local entries={}
    local boats=Workspace:FindFirstChild("Boats")
    local okChildren,children=pcall(function() return boats and boats:GetChildren() end)
    if okChildren and children then
        for _,boat in pairs(children) do
            local seat=findBoatVehicleSeat(boat)
            if seat then
                local okName,name=pcall(function() return boat.Name end)
                name=(okName and type(name)=="string" and name~="") and name or "Boat"
                local okAddress,address=pcall(function() return seat.Address end)
                local key=(okAddress and address and address~=0) and tostring(address) or tostring(seat)
                table.insert(entries,{name=name,seat=seat,key=key})
            end
        end
    end

    table.sort(entries,function(a,b)
        if a.name==b.name then return a.key<b.key end
        return a.name<b.name
    end)

    local totals={}
    for _,entry in ipairs(entries) do totals[entry.name]=(totals[entry.name] or 0)+1 end
    local used={}
    local nextLabels={}
    local nextMap={}
    local selectedLabel=nil
    local selectedKey=S.selectedBoatSeat and instKey(S.selectedBoatSeat) or nil
    for _,entry in ipairs(entries) do
        used[entry.name]=(used[entry.name] or 0)+1
        local label=entry.name
        if totals[entry.name]>1 then label=label.." #"..tostring(used[entry.name]) end
        table.insert(nextLabels,label)
        nextMap[label]=entry.seat
        if selectedKey and entry.key==selectedKey then selectedLabel=label end
    end

    if #nextLabels==0 then
        nextLabels={"No boats found"}
        nextMap={}
    end

    boatSeatByLabel=nextMap
    local signature=table.concat(nextLabels,"|")
    if signature~=lastBoatSeatSignature then
        for index=#boatSeatOptions,1,-1 do boatSeatOptions[index]=nil end
        for _,label in ipairs(nextLabels) do table.insert(boatSeatOptions,label) end
        lastBoatSeatSignature=signature
        -- The dropdown shares this table; SetValues makes UE redraw an open list.
        if boatSeatDropdown and boatSeatDropdown.SetValues then
            pcall(function() boatSeatDropdown:SetValues(boatSeatOptions) end)
        end
    end

    if not selectedLabel and S.selectedBoatSeatLabel and nextMap[S.selectedBoatSeatLabel] then
        selectedLabel=S.selectedBoatSeatLabel
    end
    if not selectedLabel then selectedLabel=nextLabels[1] end
    local selectedSeat=nextMap[selectedLabel]
    local selectedSeatKey=selectedSeat and instKey(selectedSeat) or nil
    if selectedLabel~=S.selectedBoatSeatLabel or selectedSeatKey~=selectedKey then
        Window:Set("boat_seat_target",selectedLabel)
    end
end

boatSeatDropdown=miscTab:AddDropdown("boat_seat_target", {
    Text="Boat Seat", Description="Select a spawned boat seat to travel to",
    Options=boatSeatOptions, Default=boatSeatOptions[1], MaxVisible=8, Column=2,
    Callback=function(value)
        S.selectedBoatSeatLabel=value
        S.selectedBoatSeat=boatSeatByLabel[value]
    end
})

miscTab:AddToggle("auto_boat_seat", {
    Text="Auto Go To Seat", Description="Teleports to the selected seat until you are sitting in it",
    Default=false, Column=2,
    Callback=function(v)
        S.autoBoatSeat=v
        if v then refreshBoatSeatList() end
        notify(v and "Auto Boat Seat ON!" or "Auto Boat Seat OFF!","laced.club",2)
    end
})

miscTab:AddButton("refresh_boat_seats", {
    Text="Refresh Boat Seats", Description="Rescan Workspace.Boats now", Column=2,
    Callback=function() refreshBoatSeatList() end
})

miscTab:AddToggle("boat_fly", {
    Text="Boat Fly", Description="Fly your boat with WASD, Space, Shift",
    Default=false, Keybind=true, Column=2,
    Callback=function(v)
        S.boatFlyEnabled=v
        if not v then S.boatTweening=false end
        notify(v and "Boat Fly ON!" or "Boat Fly OFF!","laced.club",2)
    end
})

miscTab:AddSlider("boat_fly_speed", {
    Text="Fly Speed", Description="Speed of boat fly (default 5)",
    Min=1, Max=20, Step=1, Default=5, Integer=true, Column=2,
    Callback=function(v) S.boatFlySpeed=v end
})

dangerLevelDropdown=miscTab:AddDropdown("danger_level", {
    Text="Danger Level", Description="Fly boat to selected danger level",
    Options=dangerLevelNames, Default=dangerLevelNames[1], MaxVisible=6, Column=2,
    Callback=function(v)
        for _, d in pairs(dangerLevels) do
            if d.name==v then
                S.boatTweening=false
                notify("Going to "..d.name.."...","laced.club",2)
                -- The wait lives in the new thread: yielding here stalled the UI step.
                task.spawn(function()
                    task.wait(0.05)
                    boatTweenTo(d.pos)
                end)
                break
            end
        end
    end
})
-- Only a click in the list should launch a flight. Programmatic sets (config
-- load from the Settings tab calls SetValue on every dropdown) just record the
-- selection instead of flying the boat across the map.
if dangerLevelDropdown then
    dangerLevelDropdown.SetValue=function(self,value)
        self.Value=value
        if self.Window then self.Window._visibilityDirty=true end
        return self
    end
    dangerLevelDropdown.Set=dangerLevelDropdown.SetValue
end

miscTab:AddButton("stop_boat", {
    Text="Stop", Description="Stop current boat tween", Column=2,
    Callback=function() S.boatTweening=false; notify("Stopped!","laced.club",2) end
})

function isUsingSelectedBoatSeat(seat,char,humanoid,hrp)
    local okOccupant,occupant=pcall(function() return seat.Occupant end)
    if okOccupant and occupant then
        if occupant==humanoid then return true end
        local okParent,parent=pcall(function() return occupant.Parent end)
        return okParent and parent==char
    end

    local okSeatPart,seatPart=pcall(function() return humanoid and humanoid.SeatPart end)
    if okSeatPart and seatPart then return seatPart==seat end
    -- Matcha binds neither VehicleSeat.Occupant nor Humanoid.SeatPart: both read
    -- as nil instead of raising, so "nil" cannot mean "not seated". Fall back
    -- to the distance check.

    local okPositions,seatPos,playerPos=pcall(function() return seat.Position,hrp.Position end)
    if not okPositions or not seatPos or not playerPos then return false end
    local dx=seatPos.X-playerPos.X
    local dy=seatPos.Y-playerPos.Y
    local dz=seatPos.Z-playerPos.Z
    return dx*dx+dy*dy+dz*dz<=25
end

task.spawn(function()
    pcall(refreshBoatSeatList)
    while alive() do
        task.wait(1)
        local okRefresh,refreshError=pcall(refreshBoatSeatList)
        if not okRefresh then warnThrottled("boatSeats","[laced.club] Boat seat scan failed: "..tostring(refreshError),30) end
    end
end)

dinoBoneTarget=nil

function getDinoBonePart(object)
    if not object or not object.Parent then return nil end
    if isA(object,"BasePart") then return object end
    local part=object:FindFirstChild("HumanoidRootPart")
    if not part and isA(object,"Model") then part=object.PrimaryPart end
    return part or object:FindFirstChildWhichIsA("BasePart")
end

function findNearestDinoBone(playerRoot)
    local nearest=nil
    local nearestDistance=math.huge
    local playerPos=playerRoot.Position
    for _,object in pairs(Workspace:GetChildren()) do
        if object.Name=="DinoBone" then
            local part=getDinoBonePart(object)
            if part then
                local partPos=part.Position
                local dx=partPos.X-playerPos.X
                local dy=partPos.Y-playerPos.Y
                local dz=partPos.Z-playerPos.Z
                local distanceSquared=dx*dx+dy*dy+dz*dz
                if distanceSquared<nearestDistance then
                    nearestDistance=distanceSquared
                    nearest=object
                end
            end
        end
    end
    return nearest
end

task.spawn(function()
    -- A Workspace:GetChildren() rescan at most every 0.5 s while no bone is
    -- found (it ran every frame), and root writes at 30 Hz.
    local nextScan=0
    while alive() do
        if S.autoDinoBone then task.wait(1/30) else task.wait(IDLE_POLL) end
        if S.autoDinoBone then
            local okStep=pcall(function()
                local char=LocalPlayer.Character
                local hrp=char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local bonePart=getDinoBonePart(dinoBoneTarget)
                    if not bonePart and clock()>=nextScan then
                        nextScan=clock()+0.5
                        dinoBoneTarget=findNearestDinoBone(hrp)
                        bonePart=getDinoBonePart(dinoBoneTarget)
                    end
                    if bonePart then
                        local bonePos=bonePart.Position
                        setPartPosition(hrp,Vector3.new(bonePos.X,bonePos.Y,bonePos.Z))
                        zeroVelocity(hrp)
                    end
                end
            end)
            if not okStep then dinoBoneTarget=nil end
        else
            dinoBoneTarget=nil
        end
    end
end)

task.spawn(function()
    while alive() do
        if S.autoBoatSeat then
            local seat=S.selectedBoatSeat
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart") or nil
            local humanoid=char and char:FindFirstChildOfClass("Humanoid") or nil
            local okSeat,seatParent,seatPos=pcall(function()
                return seat and seat.Parent,seat and seat.Position
            end)
            if seat and char and hrp and humanoid and okSeat and seatParent and seatPos and not writesPaused()
                and not isUsingSelectedBoatSeat(seat,char,humanoid,hrp) then
                pcall(function()
                    hrp.Position=Vector3.new(seatPos.X,seatPos.Y+2,seatPos.Z)
                    hrp.Velocity=Vector3.new(0,0,0)
                    hrp.AssemblyLinearVelocity=Vector3.new(0,0,0)
                end)
            end
        end
        -- 30 Hz while on (three root writes per pass), idle cadence while off.
        if S.autoBoatSeat then task.wait(1/30) else task.wait(IDLE_POLL) end
    end
end)

mainTab:AddSection("Games", { Column = 2 })

mainTab:AddToggle("auto_raid", {
    Text="Auto Raid", Description="Tracks each raid island, travels 100 studs above it, then farms its enemies",
    Default=false, Keybind=true, Column=2,
    Callback=function(v)
        S.autoRaid=v
        S.raidTweenActive=false
        S.raidDetected=false
        S.raidLastIslandNum=0
        S.raidLastIslandKey=nil
        S.raidMapKey=nil
        S.raidMoveGeneration=S.raidMoveGeneration+1
        notify(v and "Auto Raid ON!" or "Auto Raid OFF!","laced.club",2)
    end
})

mainTab:AddToggle("auto_mastery", {
    Text="Auto Mastery", Description="Goto ChocolateIsland And use buddha transformation",
    Default=false, Keybind=true, Column=2,
    Callback=function(v)
        S.autoMastery=v
        notify(v and "Auto Mastery ON!" or "Auto Mastery OFF!","laced.club",2)
    end
})

otherTab:AddSection("Custom Pull", { Column = 1 })

otherTab:AddToggle("custom_pull", {
    Text="Custom Pull", Description="Pulls all enemies to a custom XYZ offset relative to you",
    Default=false, Column=1,
    Callback=function(v) S.customPull=v; notify(v and "Custom Pull ON!" or "Custom Pull OFF!","laced.club",2) end
})

otherTab:AddSlider("custom_pull_x", {
    Text="Pull X Offset", Description="X offset from your position",
    Min=-100, Max=100, Step=1, Default=0, Integer=true, Column=1,
    Callback=function(v) S.customPullX=v end
})

otherTab:AddSlider("custom_pull_y", {
    Text="Pull Y Offset", Description="Y offset from your position",
    Min=-100, Max=100, Step=1, Default=-10, Integer=true, Column=1,
    Callback=function(v) S.customPullY=v end
})

otherTab:AddSlider("custom_pull_z", {
    Text="Pull Z Offset", Description="Z offset from your position",
    Min=-100, Max=100, Step=1, Default=0, Integer=true, Column=1,
    Callback=function(v) S.customPullZ=v end
})

otherTab:AddSection("Tween Settings", { Column = 1 })

tweenSettingsPopup=Window:CreatePopup({
    Title="Tween Slider Settings",
    Width=520,
    Height=500,
    Columns=2,
    Divider=true
})

otherTab:AddButton("open_tween_settings", {
    Text="Tween Sliders", Description="Open every movement tween speed slider",
    Column=1,
    Callback=function() tweenSettingsPopup:Show() end
})

tweenSettingsPopup:AddSection("Farming Tweens",{Column=1})
tweenSettingsPopup:AddSlider("tween_farm_speed",{
    Text="Farm Tween Speed", Min=50, Max=2000, Step=50, Default=S.FARM_SPEED,
    Integer=true, Column=1, Callback=function(v) S.FARM_SPEED=v end
})
tweenSettingsPopup:AddSlider("tween_chest_speed",{
    Text="Chest Tween Speed", Min=50, Max=2000, Step=50, Default=S.CHEST_SPEED,
    Integer=true, Column=1, Callback=function(v) S.CHEST_SPEED=v end
})
tweenSettingsPopup:AddSlider("tween_fruit_speed",{
    Text="Fruit Tween Speed", Min=50, Max=2000, Step=50, Default=S.FRUIT_SPEED,
    Integer=true, Column=1, Callback=function(v) S.FRUIT_SPEED=v end
})
tweenSettingsPopup:AddSlider("tween_npc_speed",{
    Text="NPC Travel Speed", Min=50, Max=2000, Step=50, Default=S.NPC_TWEEN_SPEED,
    Integer=true, Column=1, Callback=function(v) S.NPC_TWEEN_SPEED=v end
})

tweenSettingsPopup:AddSection("World Tweens",{Column=2})
tweenSettingsPopup:AddSlider("tween_level_speed",{
    Text="Level Tween Speed", Min=50, Max=2000, Step=50, Default=AFL.tweenSpeed,
    Integer=true, Column=2, Callback=function(v) AFL.tweenSpeed=v end
})
tweenSettingsPopup:AddSlider("tween_raid_speed",{
    Text="Raid Tween Speed", Min=50, Max=2000, Step=50, Default=S.RAID_TWEEN_SPEED,
    Integer=true, Column=2, Callback=function(v) S.RAID_TWEEN_SPEED=v end
})
tweenSettingsPopup:AddSlider("tween_mastery_speed",{
    Text="Mastery Tween Speed", Min=50, Max=2000, Step=50, Default=S.MASTERY_TWEEN_SPEED,
    Integer=true, Column=2, Callback=function(v) S.MASTERY_TWEEN_SPEED=v end
})
tweenSettingsPopup:AddSlider("tween_boat_speed",{
    Text="Boat Tween Speed", Min=50, Max=2000, Step=50, Default=S.BOAT_TWEEN_SPEED,
    Integer=true, Column=2, Callback=function(v) S.BOAT_TWEEN_SPEED=v end
})

tweenSettingsPopup:AddButton("close_tween_settings",{
    Text="Close", Column=2, Callback=function() tweenSettingsPopup:Hide() end
})

pvpTab:AddSection("PvP", { Column = 1 })

pvpTab:AddToggle("void_pull", {
    Text="Escape (risky)", Description="Sends you to Y=100000",
    Default=false, Column=1,
    Callback=function(v) S.voidPull=v; notify(v and "Go Up ON!" or "Go Up OFF!","laced.club",2) end
})

pvpTab:AddToggle("sky_pull", {
    Text="Go Back Down (risky)", Description="Brings you back to Y=100",
    Default=false, Column=1,
    Callback=function(v) S.skyPull=v; notify(v and "Go Down ON!" or "Go Down OFF!","laced.club",2) end
})

pvpTab:AddToggle("pvp_aura", {
    Text="PvP Aura", Description="Fires RegisterHit on the nearest player. MATCHA PRO ONLY!",
    Default=false, Keybind=true, Column=1,
    Callback=function(v)
        _pvpAuraEnabled = v
        notify(v and "PvP Aura ON!" or "PvP Aura OFF!", "laced.club", 2)
    end
})
pvpTab:AddToggle("pvp_aura_alt_part", {
    Text="Use ModelHitbox", Description="Toggle between Head and ModelHitbox hit part.",
    Default=false, Column=1,
    Callback=function(v)
        _pvpAuraAltPart = v
        notify("Hit part: " .. (v and "ModelHitbox" or "Head"), "laced.club", 2)
    end
})
pvpTab:AddSlider("pvp_aura_range", {
    Text="PvP Range", Description="Max distance to target players (studs)",
    Min=10, Max=300, Default=100, Integer=true, Column=1,
    Callback=function(v) _pvpAuraMaxDist = v end
})

pvpTab:AddSection("Glitches", { Column = 2 })

pvpTab:AddToggle("sanguine_z_boost", {
    Text="Sanguine Z Boost", Description="Boosts current velocity during Sanguine Art Z",
    Default=false, Column=2,
    Callback=function(v) S.sanguineZBoost=v end
})

pvpTab:AddToggle("dragon_talon_z_boost", {
    Text="Dragon Talon Z Boost", Description="Boosts current velocity after pressing Z",
    Default=false, Column=2,
    Callback=function(v) S.dragonTalonZBoost=v end
})

pvpTab:AddToggle("yama_z_boost", {
    Text="Yama Z Boost", Description="Boosts current velocity after pressing Z",
    Default=false, Column=2,
    Callback=function(v) S.yamaZBoost=v end
})

pvpTab:AddToggle("tushita_x_boost", {
    Text="Tushita X Boost", Description="Boosts current velocity after pressing X",
    Default=false, Column=2,
    Callback=function(v) S.tushitaXBoost=v end
})

pvpTab:AddToggle("fox_lamp_x_boost", {
    Text="Fox Lamp X Boost", Description="Boosts current velocity after pressing X",
    Default=false, Column=2,
    Callback=function(v) S.foxLampXBoost=v end
})

pvpTab:AddToggle("soul_guitar_m1_boost", {
    Text="Soul Guitar M1", Description="Boosts after Q + M1 within 0.5 seconds",
    Default=false, Column=2,
    Callback=function(v) S.soulGuitarM1Boost=v end
})

pvpTab:AddToggle("diamond_m1_boost", {
    Text="Diamond M1", Description="Sanguine-style boost when M1 is released with Diamond-Diamond equipped",
    Default=false, Column=2,
    Callback=function(v) S.diamondM1Boost=v end
})

pvpTab:AddToggle("flame_f_boost", {
    Text="Flame F Boost", Description="Boosts current velocity after pressing F",
    Default=false, Column=2,
    Callback=function(v) S.flameFBoost=v end
})

pvpTab:AddSection("PvP misc", { Column = 1 })

pvpTab:AddToggle("r_to_x", {
    Text="R to X", Description="Automatically taps X when you press R",
    Default=false, Column=1,
    Callback=function(v) S.rToX=v end
})

pvpTab:AddToggle("r_to_x_then_z", {
    Text="R to X then Z", Description="Taps X when you press R, waits 25ms, then taps Z",
    Default=false, Column=1,
    Callback=function(v) S.rToXThenZ=v end
})

pvpTab:AddToggle("flame_r_to_c", {
    Text="Flame R to C", Description="FLAME, When u flashstep = flame C move",
    Default=false, Column=1,
    Callback=function(v) S.flameRToC=v end
})

glitchSettingsPopup=Window:CreatePopup({
    Title="Glitch Slider Settings",
    Width=520,
    Height=680,
    Columns=2,
    Divider=true
})

pvpTab:AddButton("open_glitch_settings", {
    Text="Adjust Glitch Sliders", Description="Open individual settings for every boost glitch",
    Column=2,
    Callback=function() glitchSettingsPopup:Show() end
})

glitchSliderProfiles={
    {key="sanguine",label="Sanguine Z",column=1,color=Color3.fromRGB(220,45,65)},
    {key="dragonTalon",label="Dragon Talon Z",column=1,color=Color3.fromRGB(255,125,25)},
    {key="yama",label="Yama Z",column=1,color=Color3.fromRGB(160,75,255)},
    {key="tushita",label="Tushita X",column=1,color=Color3.fromRGB(40,190,255)},
    {key="foxLamp",label="Fox Lamp X",column=2,color=Color3.fromRGB(255,80,190)},
    {key="soulGuitar",label="Soul Guitar M1",column=2,color=Color3.fromRGB(70,220,125)},
    {key="diamond",label="Diamond M1",column=2,color=Color3.fromRGB(70,220,255)},
    {key="flame",label="Flame F",column=2,color=Color3.fromRGB(255,205,40)},
}

for _,entry in ipairs(glitchSliderProfiles) do
    local profileKey=entry.key
    local profile=S.glitchSettings[profileKey]
    local column=entry.column
    glitchSettingsPopup:AddSection(entry.label,{Column=column})
    glitchSettingsPopup:AddSlider("glitch_"..profileKey.."_speed",{
        Text="Speed", Min=50, Max=1000, Step=50, Default=profile.speed,
        Color=entry.color, Integer=true, Column=column,
        Callback=function(v) profile.speed=v end
    })
    glitchSettingsPopup:AddSlider("glitch_"..profileKey.."_delay",{
        Text="Start Delay", Min=0.01, Max=1, Step=0.01, Default=profile.delay,
        Color=entry.color, Decimals=2, Integer=false, Column=column,
        Callback=function(v) profile.delay=v end
    })
    glitchSettingsPopup:AddSlider("glitch_"..profileKey.."_duration",{
        Text="Duration", Min=0.01, Max=1, Step=0.01, Default=profile.duration,
        Color=entry.color, Decimals=2, Integer=false, Column=column,
        Callback=function(v) profile.duration=v end
    })
end

glitchSettingsPopup:AddButton("close_glitch_settings",{
    Text="Close", Column=2,
    Callback=function() glitchSettingsPopup:Hide() end
})

function getBoat()
    local char=LocalPlayer.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local boatsFolder=Workspace:FindFirstChild("Boats")
    if not boatsFolder then return nil end
    local okPlayer,playerPos=pcall(function() return hrp.Position end)
    if not okPlayer or not playerPos then return nil end
    for _, b in pairs(boatsFolder:GetChildren()) do
        local okModel,isModel=pcall(function() return isA(b,"Model") end)
        if okModel and isModel then
            local okSeat,seatPos=pcall(function()
                local seat=b:FindFirstChildOfClass("VehicleSeat")
                return seat and seat.Position
            end)
            if okSeat and seatPos then
                local dx=seatPos.X-playerPos.X
                local dy=seatPos.Y-playerPos.Y
                local dz=seatPos.Z-playerPos.Z
                if math.sqrt(dx*dx+dy*dy+dz*dz)<20 then return b end
            end
        end
    end
    return nil
end

function getBoatCameraVectors()
    local char=LocalPlayer.Character
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return Vector3.new(0,0,-1), Vector3.new(1,0,0) end
    local okPositions,cp,hp=pcall(function() return Workspace.CurrentCamera.Position,hrp.Position end)
    if not okPositions or not cp or not hp then return Vector3.new(0,0,-1), Vector3.new(1,0,0) end
    local fx=hp.X-cp.X; local fz=hp.Z-cp.Z
    local fl=math.sqrt(fx*fx+fz*fz)
    if fl>0.001 then fx=fx/fl; fz=fz/fl else fx=0; fz=-1 end
    return Vector3.new(fx,0,fz), Vector3.new(-fz,0,fx)
end

-- S.boatTween holds the token of the tween that owns the boat; starting a new
-- tween replaces it, so an older tween still in its start-up wait cannot run
-- concurrently with the new one.
function boatTweenTo(targetPos)
    local token={}
    S.boatTween=token
    local function owns() return S.boatTween==token end
    local function active() return alive() and S.boatTweening and owns() end
    local function finish(arrived)
        if owns() then
            S.boatTweening=false; S.currentBoat=nil; S.boatTween=nil
            if arrived then notify("Arrived!","Boat Fly",2) end
        end
    end

    S.currentBoat = getBoat()
    if not S.currentBoat then notify("No boat found!","Boat Fly",2); finish(false); return end
    local okPrimary,primary=pcall(function() return S.currentBoat.PrimaryPart end)
    if not okPrimary or not primary or not targetPos then finish(false); return end
    S.boatTweening=true
    local okRaise=pcall(function()
        primary.Position=Vector3.new(primary.Position.X, primary.Position.Y+50, primary.Position.Z)
    end)
    if not okRaise then finish(false); return end
    task.wait(0.1)
    if not active() then finish(false); return end
    local okStart,startPos=pcall(function() return primary.Position end)
    if not okStart or not startPos then finish(false); return end
    local fixedY=startPos.Y
    local startX=startPos.X; local startZ=startPos.Z
    local dx=targetPos.X-startX; local dz=targetPos.Z-startZ
    local dist=math.sqrt(dx*dx+dz*dz)
    local speed=math.max(tonumber(S.BOAT_TWEEN_SPEED) or 500,1)
    -- dist can be 0 (already there): never divide by zero.
    local duration=math.max(dist/speed,0.01)
    local t0=clock()
    local arrived=false
    while active() do
        -- Marked before the pause too, so a deferrable invoke (Auto Stat)
        -- that started its lead-in releases the quiet window at once.
        markTravel() -- a background CommF_ invoke waits until the flight is over
        -- CommF_ quiet window: no write; the flight resumes where it stopped.
        while writesPaused() and active() do local pausedAt=clock(); markTravel(); task.wait(0.05); t0=t0+(clock()-pausedAt) end
        local alpha=math.min((clock()-t0)/duration,1)
        local okMove=pcall(function()
            primary.Position=Vector3.new(startX+dx*alpha, fixedY, startZ+dz*alpha)
        end)
        if not okMove then break end
        zeroVelocity(primary)
        if alpha>=1 then arrived=true; break end
        frameWait() -- was task.wait(0.01), ~100 writes/s; alpha is time-based, so the speed is unchanged
    end
    finish(arrived)
end

task.spawn(function()
    while alive() do
        idleWait(S.boatFlyEnabled)
        if not S.boatFlyEnabled or S.boatTweening or writesPaused() then continue end
        local boat=getBoat(); if not boat then continue end
        local okPrimary,primary=pcall(function() return boat.PrimaryPart end)
        if not okPrimary or not primary then continue end
        local fwd, right=getBoatCameraVectors()
        local mx, my, mz=0,0,0
        if keyDown(0x57) then mx=mx+fwd.X*S.boatFlySpeed;   mz=mz+fwd.Z*S.boatFlySpeed   end
        if keyDown(0x53) then mx=mx-fwd.X*S.boatFlySpeed;   mz=mz-fwd.Z*S.boatFlySpeed   end
        if keyDown(0x44) then mx=mx+right.X*S.boatFlySpeed; mz=mz+right.Z*S.boatFlySpeed end
        if keyDown(0x41) then mx=mx-right.X*S.boatFlySpeed; mz=mz-right.Z*S.boatFlySpeed end
        if keyDown(0x58) then my=my+S.boatFlySpeed end
        if keyDown(0x10) then my=my-S.boatFlySpeed end
        zeroVelocity(primary)
        pcall(function()
            primary.Position=Vector3.new(primary.Position.X+mx, primary.Position.Y+my, primary.Position.Z+mz)
        end)
    end
end)

-- ESP clear functions: remove every Drawing object, not just hide it, so the
-- caches cannot grow without bound across toggles. `state` defaults to this
-- run's S (shutdownScript clears its own run's caches directly).
function clearEspLabels(state)
    state=state or S
    clearEspCache(state.espLabelCache)
    state.espLabels={}
end

function clearChestEspLabels(state)
    state=state or S
    clearEspCache(state.chestEspLabelCache)
    state.chestEspLabels={}
end

function clearBerryEspLabels(state)
    state=state or S
    state.berryScanGeneration=state.berryScanGeneration+1
    clearEspCache(state.berryEspLabelCache)
    state.berryEspLabels={}
    -- The running scan sees the new generation at its next batch and stops;
    -- clearing the flag lets a quick off/on start a fresh scan at once.
    berryScanRunning=false
end

function clearBoatEsp(state)
    state=state or S
    clearEspCache(state.boatEspCache)
    state.boatEspEntries={}
end

function clearFlowerEsp(state)
    state=state or S
    clearEspCache(state.flowerEspCache)
    state.flowerEspEntries={}
end

function clearChamBoxes(state)
    state=state or S
    clearEspCache(state.chamBoxCache)
    state.chamBoxes={}
end

-- Load marker: this chunk ran to the end.
if LACED_LOAD and type(LACED_LOAD.done) == "table" then LACED_LOAD.done["20_ui2"] = true end
