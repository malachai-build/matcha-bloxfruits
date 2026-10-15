-- @chunk 10_ui  (lines 784-1821 of the single-file build)
-- Per-execution bindings: captured at chunk load so a re-run of the script
-- cannot make this copy's loops read the new copy's state.
local alive = alive
local SCRIPT_STATE = SCRIPT_STATE
UE_URL = "https://raw.githubusercontent.com/hauntedscripts/Scripts2/refs/heads/main/matcha%20ue"

function ueEnvironments()
    local envs = {}
    local getgenvFn = _G.getgenv
    if type(getgenvFn) == "function" then
        local okGenv, genv = pcall(getgenvFn)
        if okGenv and type(genv) == "table" then table.insert(envs, genv) end
    end
    table.insert(envs, _G)
    return envs
end

-- loadstring drops top-level returns in Matcha, so the library is only
-- reachable through the UELibrary global it publishes.
function findExposedUE()
    for _, env in ipairs(ueEnvironments()) do
        local candidate = env.UELibrary
        if type(candidate) == "table" and type(candidate.CreateWindow) == "function" then return candidate end
    end
    for _, env in ipairs(ueEnvironments()) do
        local candidate = env.Library
        if type(candidate) == "table" and type(candidate.CreateWindow) == "function" and candidate.Raw == nil then
            return candidate
        end
    end
    return nil
end

function validateUESource(body)
    if type(body) ~= "string" or #body < 2000 then
        return false, "empty or truncated download (" .. tostring(type(body) == "string" and #body or 0) .. " bytes)"
    end
    local head = string.lower(string.sub(body, 1, 300))
    if string.find(head, "<!doctype", 1, true) or string.find(head, "<html", 1, true)
        or string.find(head, "404: not found", 1, true) then
        return false, "server returned an error page instead of the library"
    end
    if not string.find(body, "CreateWindow", 1, true) or not string.find(body, "UELibrary", 1, true) then
        return false, "downloaded file is not the UE library"
    end
    return true, nil
end

function loadUEAdapter()
    local ueSource = safeHttpGet(UE_URL)
    local valid, reason = validateUESource(ueSource)
    assert(valid, "UE download rejected: " .. tostring(reason))

    local previousUE = findExposedUE()
    local ueChunk = loadstring(ueSource, "laced.club UE")
    assert(type(ueChunk) == "function", "UE compile failed")
    ueChunk()

    local UE = findExposedUE()
    assert(type(UE) == "table", "UE did not expose UELibrary")
    assert(UE ~= previousUE, "UE chunk did not run (stale UELibrary from a previous execution)")
    assert(not UE._unloaded, "UE library is already unloaded")

    local controls = {}

    local function roundTo(value, decimals)
        local power = 10 ^ (decimals or 0)
        return math.floor(value * power + 0.5) / power
    end

    local function roundingFor(step, explicit)
        local explicitNumber = tonumber(explicit)
        if explicitNumber then return math.max(0, math.floor(explicitNumber)) end
        step = tonumber(step) or 1
        if step >= 1 then return 0 end
        local decimals = tostring(step):match("%.(%d+)")
        return decimals and #decimals or 0
    end

    local function enhanceControl(id, control)
        if not control then return control end
        controls[id] = control
        control.Set = control.SetValue
        control.SetOptions = control.SetValues
        return control
    end

    local function makeTab(rawTab)
        local tab = { Raw = rawTab, Groups = {} }

        local function columnOf(info)
            local column = tonumber(info and info.Column) or 1
            return column == 2 and 2 or 1
        end

        local function groupFor(self, info)
            local column = columnOf(info)
            local group = self.Groups[column]
            if not group then
                if column == 2 then group = self.Raw:AddRightGroupbox("General")
                else group = self.Raw:AddLeftGroupbox("General") end
                self.Groups[column] = group
            end
            return group
        end

        function tab:AddSection(name, info)
            local column = columnOf(info)
            local group
            if column == 2 then group = self.Raw:AddRightGroupbox(name)
            else group = self.Raw:AddLeftGroupbox(name) end
            self.Groups[column] = group
            return group
        end

        function tab:AddToggle(id, info)
            info = info or {}
            local group = groupFor(self, info)
            local toggle = group:AddToggle(id, {
                Text = info.Text or id,
                Default = info.Default == true,
                Callback = info.Callback,
                Tooltip = info.Description,
                Risky = info.Risky == true,
            })
            enhanceControl(id, toggle)
            if info.Keybind == true then
                local picker = toggle:AddKeyPicker(id .. "_keybind", {
                    Text = (info.Text or id) .. " key",
                    Default = "None",
                    Mode = "Toggle",
                    SyncToggleState = true,
                })
                enhanceControl(id .. "_keybind", picker)
            end
            return toggle
        end

        function tab:AddSlider(id, info)
            info = info or {}
            -- A slider declared with Decimals but no Step must not snap to whole numbers.
            local step = tonumber(info.Step)
            if not step then
                local decimals = tonumber(info.Decimals)
                step = (decimals and decimals > 0) and (10 ^ -math.floor(decimals)) or 1
            end
            if step <= 0 then step = 1 end
            local minimum = tonumber(info.Min) or 0
            local maximum = tonumber(info.Max) or 100
            local rounding = roundingFor(step, info.Decimals)
            local callback = info.Callback
            local slider
            local function changed(value)
                value = tonumber(value) or minimum
                local snapped = minimum + math.floor(((value - minimum) / step) + 0.5) * step
                snapped = roundTo(snapped, rounding)
                if snapped < minimum then snapped = minimum end
                if snapped > maximum then snapped = maximum end
                if slider then slider.Value = snapped end
                if callback then callback(snapped) end
            end
            slider = groupFor(self, info):AddSlider(id, {
                Text = info.Text or id,
                Default = info.Default,
                Min = minimum,
                Max = maximum,
                Rounding = rounding,
                Suffix = info.Suffix or "",
                Callback = changed,
                Tooltip = info.Description,
            })
            return enhanceControl(id, slider)
        end

        function tab:AddDropdown(id, info)
            info = info or {}
            local values = info.Options or info.Values or {}
            local default = info.Default
            if default ~= nil and not info.Multi then
                local found = false
                for _, value in ipairs(values) do
                    if value == default then found = true; break end
                end
                if not found then default = values[1] end
            end
            local dropdown = groupFor(self, info):AddDropdown(id, {
                Text = info.Text or id,
                Default = default,
                Values = values,
                Multi = info.Multi == true,
                AllowNull = info.AllowNull == true,
                Callback = info.Callback,
                Tooltip = info.Description,
            })
            return enhanceControl(id, dropdown)
        end

        function tab:AddButton(id, info)
            info = info or {}
            local button = groupFor(self, info):AddButton({
                Text = info.Text or id,
                Func = info.Callback,
                Tooltip = info.Description,
                DoubleClick = info.DoubleClick == true,
            })
            return enhanceControl(id, button)
        end

        -- Read-only text line (UE GroupMethods:AddLabel(text, wraps)). UE draws
        -- the control's Text field every frame, so writing label.Text updates it.
        -- Not registered in Controls: labels have no value to save or reset.
        function tab:AddLabel(id, info)
            info = info or {}
            local label = groupFor(self, info):AddLabel(info.Text or id, info.Wrap == true)
            return label
        end

        function tab:AddPriorityList(id, info)
            info = info or {}
            local group = groupFor(self, info)
            local options = info.Options or {}
            local selected = {}
            for index, value in ipairs(info.Default or options) do selected[index] = value end
            local pickers = {}
            local changing = false

            local function emit()
                if info.Callback then
                    local order = {}
                    for index = 1, #options do order[index] = selected[index] end
                    info.Callback(order)
                end
            end

            for index = 1, #options do
                local slot = index
                local picker = group:AddDropdown(id .. "_" .. tostring(slot), {
                    Text = (info.Text or id) .. " " .. tostring(slot),
                    Default = selected[slot],
                    Values = options,
                    Callback = function(value)
                        if changing then return end
                        local previous = selected[slot]
                        local duplicate = nil
                        for other = 1, #selected do
                            if other ~= slot and selected[other] == value then duplicate = other; break end
                        end
                        selected[slot] = value
                        if duplicate then
                            selected[duplicate] = previous
                            if pickers[duplicate] then pickers[duplicate].Value = previous end
                        end
                        emit()
                    end,
                    Tooltip = info.Description,
                })
                pickers[slot] = picker
                enhanceControl(id .. "_" .. tostring(slot), picker)
            end

            local list = { Pickers = pickers, Value = selected }
            function list:SetValue(order)
                if type(order) ~= "table" then return self end
                changing = true
                for index = 1, math.min(#order, #pickers) do
                    selected[index] = order[index]
                    pickers[index].Value = order[index]
                end
                changing = false
                emit()
                return self
            end
            function list:SetValues(values)
                for _, picker in ipairs(pickers) do picker:SetValues(values or {}) end
                return self
            end
            list.SetOptions = list.SetValues
            controls[id] = list
            return list
        end

        return tab
    end

    local Adapter = { Raw = UE, Controls = controls, Windows = {} }

    local function makePopup(adapter, info)
        info = info or {}
        local wasToggled = adapter.Raw.Toggled
        local raw = adapter.Raw:CreateWindow({
            Title = info.Title or "Settings",
            Width = info.Width or 520,
            Height = info.Height or 500,
            AutoShow = false,
            Center = true,
        })
        -- CreateWindow copies the new (hidden) window's visibility into
        -- Library.Toggled, which would hide the main menu; restore it.
        adapter.Raw.Toggled = wasToggled ~= false
        local page = makeTab(raw:AddTab(info.Title or "Settings"))
        local popup = { Raw = raw }
        function popup:AddSection(...) return page:AddSection(...) end
        function popup:AddToggle(...) return page:AddToggle(...) end
        function popup:AddSlider(...) return page:AddSlider(...) end
        function popup:AddDropdown(...) return page:AddDropdown(...) end
        function popup:AddButton(...) return page:AddButton(...) end
        function popup:AddPriorityList(...) return page:AddPriorityList(...) end
        function popup:Show() raw:Show(); return self end
        function popup:Hide() raw:Hide(); return self end
        function popup:Set(id, value)
            local control = controls[id]
            if control and control.SetValue then control:SetValue(value)
            elseif control and control.Set then control:Set(value) end
            return self
        end
        return popup
    end

    function Adapter:OnUnload(callback)
        if type(self.Raw.OnUnload) == "function" then self.Raw:OnUnload(callback) end
    end

    function Adapter:CreateWindow(info)
        info = info or {}
        local accent = info.Theme and info.Theme.Colors and info.Theme.Colors.Accent
        if accent then
            -- StaticAccentColor is what the Settings tab picker, Rainbow-off and
            -- config load restore to; without it the accent snaps back to blue.
            self.Raw.AccentColor = accent
            self.Raw.StaticAccentColor = accent
        end
        if info.ConfigFile or info.SettingsFile then
            self.Raw.SettingsFile = (info.ConfigFile or info.SettingsFile) .. ".ui.json"
        end
        local raw = self.Raw:CreateWindow({
            Title = info.Title or "laced.club",
            Width = info.Width or 540,
            Height = info.Height or 430,
            AutoShow = true,
            Center = true,
        })
        local window = {
            Raw = raw,
            Tabs = {},
            Indicator = { SetVisible = function() end },
            Config = { IndicatorEnabled = false },
            _lastMenuDown = false,
        }

        local configFolder = tostring(info.ConfigFolder or "laced_club_configs")
        local selectedConfig = ""
        local function safeConfigName(name)
            name = tostring(name or ""):gsub("[^%w%._%- ]", "_"):gsub("^%s+", ""):gsub("%s+$", "")
            if name == "" then name = "default" end
            return name:sub(1, 64)
        end
        local function ensureConfigFolder()
            pcall(function()
                if not isfolder(configFolder) then makefolder(configFolder) end
            end)
        end
        local function configPathFor(name)
            return configFolder .. "/" .. safeConfigName(name) .. ".json"
        end
        local function listConfigNames()
            ensureConfigFolder()
            local names = {}
            local ok, files = pcall(listfiles, configFolder)
            if ok and type(files) == "table" then
                for _, path in ipairs(files) do
                    -- listfiles returns workspace-relative paths with backslashes.
                    local fileName = tostring(path):match("([^/\\]+)%.json$")
                    if fileName then table.insert(names, fileName) end
                end
            end
            table.sort(names)
            return names
        end
        local configPath = configPathFor("default")
        local function configValue(control)
            if not control then return nil end
            local kind = control.Type
            if kind == "Toggle" then return control.Value == true end
            if kind == "Slider" then return tonumber(control.Value) end
            if kind == "KeyPicker" then
                return type(control.Value) == "string" and control.Value or "None"
            end
            if kind == "Dropdown" then
                if control.Multi then
                    local out = {}
                    for key, value in pairs(control.Value or {}) do
                        if type(key) == "string" then out[key] = value == true end
                    end
                    return out
                end
                return type(control.Value) == "string" and control.Value or nil
            end
            return nil
        end
        local function saveFeatureConfig(name)
            name = safeConfigName(name or selectedConfig)
            ensureConfigFolder()
            local path = configPathFor(name)
            local data = { version = 4, controls = {}, name = name }
            for id, control in pairs(controls) do
                local value = configValue(control)
                if value ~= nil then data.controls[id] = value end
            end
            local ok = pcall(function()
                local http = game:GetService("HttpService")
                writefile(path, http:JSONEncode(data))
            end)
            if ok then
                selectedConfig = name
                configPath = path
                window.Config.File = path
            end
            return ok
        end
        local function loadFeatureConfig(name)
            name = safeConfigName(name or selectedConfig)
            local path = configPathFor(name)
            -- readfile raises on a missing file in Matcha.
            local okExists, exists = pcall(isfile, path)
            if not okExists or not exists then return false end
            local wasVisible = raw.Visible
            local wasToggled = self.Raw.Toggled
            local ok, data = pcall(function()
                local http = game:GetService("HttpService")
                return http:JSONDecode(readfile(path))
            end)
            if not ok or type(data) ~= "table" or data.version ~= 4 or type(data.controls) ~= "table" then
                return false
            end
            local toggleStates = {}
            for id, saved in pairs(data.controls) do
                local control = controls[id]
                local value = saved
                -- Also accept the UE Settings-tab format { type = ..., value = ... }.
                if type(saved) == "table" and saved.value ~= nil and saved.type ~= nil then value = saved.value end
                if control and control.Type == "Toggle" and type(value) == "boolean" then
                    toggleStates[id] = value
                elseif control and control.Type ~= "Button" and control.SetValue then
                    pcall(function() control:SetValue(value) end)
                end
            end
            local previous = {}
            for id, value in pairs(toggleStates) do
                local control = controls[id]
                if control then
                    previous[id] = control.Value == true
                    control.Value = value
                end
            end
            for id, value in pairs(toggleStates) do
                local control = controls[id]
                if control and previous[id] ~= value then
                    pcall(function() if control.Callback then control.Callback(value) end end)
                    pcall(function() if control.Changed then control.Changed(value) end end)
                end
            end
            for id, value in pairs(toggleStates) do
                local control = controls[id]
                if control then control.Value = value end
            end
            raw.Visible = wasVisible
            self.Raw.Toggled = wasToggled
            raw._visibilityDirty = true
            selectedConfig = name
            configPath = path
            window.Config.File = path
            return true
        end
        local function refreshConfigList(dropdown)
            local names = listConfigNames()
            if dropdown and dropdown.SetValues then
                pcall(function() dropdown:SetValues(names) end)
            end
            if selectedConfig == "" and names[1] then selectedConfig = names[1] end
            return names
        end
        window.Config = {
            IndicatorEnabled = false,
            File = configPath,
            Folder = configFolder,
            Save = function(name) return saveFeatureConfig(name) end,
            Load = function(name) return loadFeatureConfig(name) end,
            Refresh = function(dropdown) return refreshConfigList(dropdown) end,
            List = function() return listConfigNames() end,
        }

        function window:AddTab(name)
            local tab = makeTab(raw:AddTab(name))
            self.Tabs[name] = tab
            return tab
        end

        function window:Set(id, value)
            local control = controls[id]
            if control and control.SetValue then control:SetValue(value)
            elseif control and control.Set then control:Set(value) end
            return self
        end

        function window:CreatePopup(popupInfo)
            return makePopup(Adapter, popupInfo)
        end

        function window:Show() raw:Show(); return self end
        function window:Hide() raw:Hide(); return self end
        function window:SetVisible(value) if value then raw:Show() else raw:Hide() end; return self end

        function window:Step()
            return self
        end

        table.insert(Adapter.Windows, window)

        -- The UE Settings tab owns the visible config UI; point Window.Config
        -- at the same store so both paths read and write the same files.
        local ueConfigs = self.Raw.Configs
        if type(ueConfigs) == "table" then
            window.Config.Folder = ueConfigs.Folder or window.Config.Folder
            window.Config.File = tostring(window.Config.Folder) .. "/default.json"
            if type(ueConfigs.Save) == "function" then window.Config.Save = ueConfigs.Save end
            if type(ueConfigs.Load) == "function" then window.Config.Load = ueConfigs.Load end
            if type(ueConfigs.Refresh) == "function" then window.Config.Refresh = ueConfigs.Refresh end
        end
        return window
    end

    return Adapter
end

do
    local okUE, ueResult = pcall(loadUEAdapter)
    if okUE and type(ueResult) == "table" then
        Library = ueResult
        menuUE = ueResult.Raw
    else
        warn("Failed to load UE UI: " .. tostring(ueResult))
        return
    end
end

_pvpAuraEnabled = false
_pvpAuraAltPart = false
_pvpAuraMaxDist = 100

islandNames = {}
for _, isle in pairs(islandList) do table.insert(islandNames, isle.name) end

Window = Library:CreateWindow({
    Title = "laced.club",
    Columns = 2,
    Divider = true,
    ConfigFile = "myth4c_bloxfruits.json",
    BuiltInIndicatorToggle = false,
    Width = 540,
    Height = 570,
    Theme = { Colors = { Accent = Color3.fromRGB(255,111,0) } }
})

mainTab=Window:AddTab("Main")
miscTab=Window:AddTab("Misc")
misc2Tab=Window:AddTab("Misc2")
otherTab=Window:AddTab("Other")
pvpTab=Window:AddTab("PvP")
automationTab=Window:AddTab("Automation")

do
    local MagnetSettings={
        enabled=false,
        targetPlayers=true,
        autoFarm=false,
        autoFarmNearest=false,
        farmMode=nil,
        selectedPlayerName="",
        range=100,
        attackNumber=1,
        m1Delay=0.10
    }

    local MAGNET_FARM_X_OFFSET=10
    local MAGNET_FARM_TWEEN_SPEED=350
    local MAGNET_NEAREST_ATTACK_TIME=1
    local MagnetNearestFarm={
        target=nil,
        attacking=false,
        attackEnds=0,
        holdPosition=nil,
        visited={}
    }

    local function magnetResetNearestFarm()
        MagnetNearestFarm.target=nil
        MagnetNearestFarm.attacking=false
        MagnetNearestFarm.attackEnds=0
        MagnetNearestFarm.holdPosition=nil
        MagnetNearestFarm.visited={}
    end

    local function magnetGetPlayerNames()
        local names={}
        for _,player in pairs(Players:GetChildren()) do
            if player~=LocalPlayer then table.insert(names,player.Name) end
        end
        if #names==0 then table.insert(names,"No players") end
        return names
    end

    local function magnetFindPlayerByName(name)
        if type(name)~="string" or name=="" then return nil end
        for _,player in pairs(Players:GetChildren()) do
            if player~=LocalPlayer and player.Name==name then return player end
        end
        return nil
    end

    misc2Tab:AddSection("Magnet M1 Aura",{Column=1})
    misc2Tab:AddToggle("magnet_m1_aura",{
        Text="Magnet M1 Aura",
        Description="Aims Magnet M1 at the closest enemy or enabled player target",
        Default=false,
        Keybind=true,
        Column=1,
        Callback=function(value)
            MagnetSettings.enabled=value
            notify(value and "Magnet M1 Aura ON!" or "Magnet M1 Aura OFF!","laced.club",2)
        end
    })

    misc2Tab:AddToggle("magnet_target_players",{
        Text="Target Players",
        Description="Allow Magnet M1 Aura to target other players",
        Default=true,
        Column=1,
        Callback=function(value) MagnetSettings.targetPlayers=value end
    })

    misc2Tab:AddSlider("magnet_target_range",{
        Text="Target Range",
        Description="Maximum aura targeting distance in studs",
        Min=10,Max=2000,Step=10,Integer=true,Default=100,Column=1,
        Color=Color3.fromRGB(210,70,255),
        Callback=function(value)
            MagnetSettings.range=math.max(10,tonumber(value) or 100)
        end
    })

    misc2Tab:AddSlider("magnet_m1_delay",{
        Text="Wait Between M1s",
        Description="Seconds to wait between Magnet remote calls",
        Min=0.01,Max=2,Step=0.01,Integer=false,Default=0.10,Column=1,
        Color=Color3.fromRGB(0,220,255),
        Callback=function(value)
            MagnetSettings.m1Delay=math.max(0.01,tonumber(value) or 0.10)
        end
    })

    misc2Tab:AddSlider("magnet_attack_number",{
        Text="Attack Number",
        Description="Selects Magnet M1 attack 1 through 5",
        Min=1,Max=5,Step=1,Integer=true,Default=1,Column=1,
        Color=Color3.fromRGB(255,80,150),
        Callback=function(value)
            MagnetSettings.attackNumber=math.max(1,math.min(5,math.floor(tonumber(value) or 1)))
        end
    })

    misc2Tab:AddSection("Magnet Auto Farm",{Column=2})
    misc2Tab:AddToggle("magnet_auto_farm",{
        Text="Auto Farm Player",
        Description="Tweens 10 studs along X from the selected player and spams Magnet M1",
        Default=false,Keybind=true,Column=2,
        Callback=function(value)
            MagnetSettings.autoFarm=value
            if value then
                MagnetSettings.farmMode="player"
                MagnetSettings.autoFarmNearest=false
                magnetResetNearestFarm()
                pcall(function() Window:Set("magnet_auto_farm_nearest",false) end)
            elseif MagnetSettings.farmMode=="player" then
                MagnetSettings.farmMode=nil
            end
            notify(value and "Magnet Auto Farm Player ON!" or "Magnet Auto Farm Player OFF!","laced.club",2)
        end
    })

    misc2Tab:AddToggle("magnet_auto_farm_nearest",{
        Text="Auto Farm Nearest Enemy",
        Description="Tweens to each nearest enemy, holds still for 1 second, then switches",
        Default=false,Column=2,
        Callback=function(value)
            MagnetSettings.autoFarmNearest=value
            magnetResetNearestFarm()
            if value then
                MagnetSettings.farmMode="enemy"
                MagnetSettings.autoFarm=false
                pcall(function() Window:Set("magnet_auto_farm",false) end)
            elseif MagnetSettings.farmMode=="enemy" then
                MagnetSettings.farmMode=nil
            end
            notify(value and "Magnet Auto Farm Nearest ON!" or "Magnet Auto Farm Nearest OFF!","laced.club",2)
        end
    })

    local initialMagnetPlayerNames=magnetGetPlayerNames()
    if initialMagnetPlayerNames[1]~="No players" then
        MagnetSettings.selectedPlayerName=initialMagnetPlayerNames[1]
    end

    local magnetPlayerDropdown=misc2Tab:AddDropdown("magnet_target_player",{
        Text="Target Player",
        Description="Select the player Magnet Auto Farm follows",
        Options=initialMagnetPlayerNames,
        Default=initialMagnetPlayerNames[1],
        MaxVisible=8,
        Column=2,
        Callback=function(selected)
            if type(selected)=="string" and selected~="No players" then
                MagnetSettings.selectedPlayerName=selected
            end
        end
    })

    misc2Tab:AddButton("magnet_rescan_players",{
        Text="Rescan Players",
        Description="Refreshes the Magnet target player list",
        Column=2,
        Callback=function()
            local names=magnetGetPlayerNames()
            local keptSelection=false
            for _,name in pairs(names) do
                if name==MagnetSettings.selectedPlayerName then keptSelection=true end
            end

            local refreshed=false
            if magnetPlayerDropdown then
                refreshed=pcall(function() magnetPlayerDropdown:SetValues(names) end)
                if not refreshed then
                    refreshed=pcall(function() magnetPlayerDropdown:SetOptions(names) end)
                end
            end

            if not keptSelection then
                MagnetSettings.selectedPlayerName=names[1]~="No players" and names[1] or ""
                if MagnetSettings.selectedPlayerName~="" then
                    pcall(function() magnetPlayerDropdown:SetValue(MagnetSettings.selectedPlayerName) end)
                end
            end
            notify(refreshed and "Player list refreshed" or "Player list refresh failed","laced.club",2)
        end
    })

    local function magnetGetRoot(model)
        if not model then return nil end
        return model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("UpperTorso")
            or model:FindFirstChild("Torso")
            or model:FindFirstChildWhichIsA("BasePart")
    end

    local function magnetIsAlive(model)
        if not model or not model.Parent then return false end
        local humanoid=model:FindFirstChildOfClass("Humanoid")
        return not humanoid or humanoid.Health>0
    end

    local function magnetDistanceSquared(a,b)
        local dx=a.X-b.X
        local dy=a.Y-b.Y
        local dz=a.Z-b.Z
        return dx*dx+dy*dy+dz*dz
    end

    local function magnetConsiderTarget(origin,model,bestModel,bestRoot,bestDistanceSquared)
        if model and model~=LocalPlayer.Character and magnetIsAlive(model) then
            local root=magnetGetRoot(model)
            if root then
                local currentDistanceSquared=magnetDistanceSquared(origin,root.Position)
                if currentDistanceSquared<bestDistanceSquared then
                    return model,root,currentDistanceSquared
                end
            end
        end
        return bestModel,bestRoot,bestDistanceSquared
    end

    local function magnetFindClosestTarget(playerRoot)
        local bestModel=nil
        local bestRoot=nil
        local bestDistanceSquared=MagnetSettings.range*MagnetSettings.range
        local origin=playerRoot.Position
        local enemies=Workspace:FindFirstChild("Enemies")

        if enemies then
            for _,enemy in pairs(enemies:GetChildren()) do
                bestModel,bestRoot,bestDistanceSquared=magnetConsiderTarget(
                    origin,enemy,bestModel,bestRoot,bestDistanceSquared
                )
            end
        end

        if MagnetSettings.targetPlayers then
            for _,player in pairs(Players:GetChildren()) do
                if player~=LocalPlayer then
                    bestModel,bestRoot,bestDistanceSquared=magnetConsiderTarget(
                        origin,player.Character,bestModel,bestRoot,bestDistanceSquared
                    )
                end
            end
        end
        return bestModel,bestRoot
    end

    local function magnetFindClosestEnemy(playerRoot,excluded)
        local enemies=Workspace:FindFirstChild("Enemies")
        if not enemies then return nil,nil end
        local bestModel=nil
        local bestRoot=nil
        local bestDistanceSquared=MagnetSettings.range*MagnetSettings.range
        local origin=playerRoot.Position

        for _,enemy in pairs(enemies:GetChildren()) do
            if not excluded or not excluded[instKey(enemy)] then
                bestModel,bestRoot,bestDistanceSquared=magnetConsiderTarget(
                    origin,enemy,bestModel,bestRoot,bestDistanceSquared
                )
            end
        end
        return bestModel,bestRoot
    end

    local function magnetGetRemote()
        local characters=Workspace:FindFirstChild("Characters")
        local character=characters and characters:FindFirstChild(LocalPlayer.Name)
        if not character then character=LocalPlayer.Character end
        local magnet=character and character:FindFirstChild("Magnet-Magnet")
        return magnet and magnet:FindFirstChild("LeftClickRemote")
    end

    local function magnetDirectionTo(origin,target)
        local dx=target.X-origin.X
        local dy=target.Y-origin.Y
        local dz=target.Z-origin.Z
        local length=math.sqrt(dx*dx+dy*dy+dz*dz)
        if length<0.001 then return Vector3.new(0,0,-1) end
        return Vector3.new(dx/length,dy/length,dz/length)
    end

    local function magnetGetSelectedPlayerTarget()
        local player=magnetFindPlayerByName(MagnetSettings.selectedPlayerName)
        local character=player and player.Character
        if not magnetIsAlive(character) then return nil,nil end
        return character,magnetGetRoot(character)
    end

    task.spawn(function()
        local lastStep=clock()
        while alive() do
            local now=clock()
            local deltaTime=now-lastStep
            lastStep=now

            -- One bad frame (target or root destroyed mid-write) must not kill the loop.
            local okStep,stepError=pcall(function()
            if MagnetSettings.farmMode=="player" or MagnetSettings.farmMode=="enemy" then
                local character=LocalPlayer.Character
                local playerRoot=magnetGetRoot(character)
                local targetModel,targetRoot=nil,nil

                if MagnetSettings.farmMode=="enemy" and playerRoot then
                    if MagnetNearestFarm.attacking then
                        targetModel=MagnetNearestFarm.target
                    elseif MagnetNearestFarm.target and not magnetIsAlive(MagnetNearestFarm.target) then
                        MagnetNearestFarm.visited[instKey(MagnetNearestFarm.target)]=true
                        MagnetNearestFarm.target=nil
                        MagnetNearestFarm.attacking=false
                        MagnetNearestFarm.attackEnds=0
                        MagnetNearestFarm.holdPosition=nil
                    end

                    if not MagnetNearestFarm.attacking and not MagnetNearestFarm.target then
                        targetModel,targetRoot=magnetFindClosestEnemy(playerRoot,MagnetNearestFarm.visited)
                        if not targetModel then
                            MagnetNearestFarm.visited={}
                            targetModel,targetRoot=magnetFindClosestEnemy(playerRoot,MagnetNearestFarm.visited)
                        end
                        MagnetNearestFarm.target=targetModel
                    elseif not MagnetNearestFarm.attacking then
                        targetModel=MagnetNearestFarm.target
                        targetRoot=magnetGetRoot(targetModel)
                    end
                else
                    targetModel,targetRoot=magnetGetSelectedPlayerTarget()
                end

                if MagnetSettings.farmMode=="enemy" and not MagnetNearestFarm.attacking
                    and targetModel and not targetRoot then
                    MagnetNearestFarm.visited[instKey(targetModel)]=true
                    MagnetNearestFarm.target=nil
                end

                if playerRoot and MagnetSettings.farmMode=="enemy" and MagnetNearestFarm.attacking then
                    if MagnetNearestFarm.holdPosition then
                        playerRoot.Position=MagnetNearestFarm.holdPosition
                    end
                    playerRoot.Velocity=Vector3.new(0,0,0)
                    playerRoot.AssemblyLinearVelocity=Vector3.new(0,0,0)

                    if now>=MagnetNearestFarm.attackEnds then
                        if MagnetNearestFarm.target then
                            MagnetNearestFarm.visited[instKey(MagnetNearestFarm.target)]=true
                        end
                        MagnetNearestFarm.target=nil
                        MagnetNearestFarm.attacking=false
                        MagnetNearestFarm.attackEnds=0
                        MagnetNearestFarm.holdPosition=nil
                    end
                elseif playerRoot and targetModel and targetRoot then
                    local currentPosition=playerRoot.Position
                    local targetPosition=Vector3.new(
                        targetRoot.Position.X+MAGNET_FARM_X_OFFSET,
                        targetRoot.Position.Y,
                        targetRoot.Position.Z
                    )
                    local dx=targetPosition.X-currentPosition.X
                    local dy=targetPosition.Y-currentPosition.Y
                    local dz=targetPosition.Z-currentPosition.Z
                    local distance=math.sqrt(dx*dx+dy*dy+dz*dz)

                    if distance>0.01 then
                        local maxStep=MAGNET_FARM_TWEEN_SPEED*math.min(deltaTime,0.1)
                        local alpha=math.min(maxStep/distance,1)
                        playerRoot.Position=Vector3.new(
                            currentPosition.X+dx*alpha,
                            currentPosition.Y+dy*alpha,
                            currentPosition.Z+dz*alpha
                        )
                    end

                    if MagnetSettings.farmMode=="enemy" and MagnetNearestFarm.target==targetModel
                        and not MagnetNearestFarm.attacking and distance<=1.5 then
                        playerRoot.Position=targetPosition
                        MagnetNearestFarm.attacking=true
                        MagnetNearestFarm.attackEnds=now+MAGNET_NEAREST_ATTACK_TIME
                        MagnetNearestFarm.holdPosition=targetPosition
                    end
                    playerRoot.Velocity=Vector3.new(0,0,0)
                    playerRoot.AssemblyLinearVelocity=Vector3.new(0,0,0)
                end
            end
            end)
            if not okStep then warnThrottled("magnetFarm","[laced.club] Magnet farm step failed: "..tostring(stepError),10) end
            frameWait()
        end
    end)

    task.spawn(function()
        local lastM1=0
        while alive() do
            if MagnetSettings.enabled or MagnetSettings.farmMode~=nil then
                local character=LocalPlayer.Character
                local playerRoot=magnetGetRoot(character)
                local now=clock()

                if playerRoot and now-lastM1>=MagnetSettings.m1Delay then
                    local targetModel,targetRoot=nil,nil
                    if MagnetSettings.farmMode=="enemy" then
                        if MagnetNearestFarm.attacking and magnetIsAlive(MagnetNearestFarm.target) then
                            targetModel=MagnetNearestFarm.target
                            targetRoot=magnetGetRoot(targetModel)
                        end
                    elseif MagnetSettings.farmMode=="player" then
                        targetModel,targetRoot=magnetGetSelectedPlayerTarget()
                    else
                        targetModel,targetRoot=magnetFindClosestTarget(playerRoot)
                    end

                    local remote=magnetGetRemote()
                    if targetModel and targetRoot and remote then
                        local okDirection,direction=pcall(function()
                            return magnetDirectionTo(playerRoot.Position,targetRoot.Position)
                        end)
                        if okDirection and direction then
                            safeRemote("Magnet M1",remote,"FireServer",direction,MagnetSettings.attackNumber)
                        end
                        lastM1=now
                    end
                end
            end
            -- Back off while the remote keeps failing (non-Pro build) instead of firing every frame.
            if remoteFailing("Magnet M1") then task.wait(1) else frameWait() end
        end
    end)
end

misc2Tab:AddSection("Ship Repair",{Column=1})
misc2Tab:AddToggle("auto_ship_repair",{
    Text="Auto Repair",
    Description="Automatically holds and releases the ship repair mini-game in its green zone",
    Default=false,
    Keybind=true,
    Column=1,
    Callback=function(value)
        S.autoRepair=value
        if value then pcall(function() Window:Set("auto_fish",false) end) end
        if not value then pcall(mouse1release) end
        notify(value and "Auto Repair ON!" or "Auto Repair OFF!","laced.club",2)
    end
})

mainTab:AddSection("Dungeon",{Column=2})
mainTab:AddToggle("dungeon_enabled",{
    Text="Enable Dungeon",
    Description="Master switch for the Second Sea dungeon automation",
    Default=false,Keybind=true,Column=2,
    Callback=function(value)
        S.dungeonEnabled=value
        notify(value and "Dungeon Farm ON!" or "Dungeon Farm OFF!","laced.club",2)
    end
})
mainTab:AddToggle("dungeon_auto_door",{
    Text="Smart Door Path",
    Description="Moves to the exit teleporter when the current island is clear",
    Default=true,Column=2,
    Callback=function(value) S.dungeonAutoDoor=value end
})
mainTab:AddToggle("dungeon_destroy_vents",{
    Text="Destroy Vents First",
    Description="Prioritizes vents, shrines, rocks, and dungeon props",
    Default=true,Column=2,
    Callback=function(value) S.dungeonDestroyObj=value end
})
mainTab:AddToggle("dungeon_vent_skills",{
    Text="Skills on Vents Z/X/C/V",
    Description="Uses equipped-tool skills against dungeon objectives",
    Default=true,Column=2,
    Callback=function(value) S.dungeonUseMoves=value end
})

