if not game:IsLoaded() then game.Loaded:Wait() end
if game.GameId ~= 6035872082 then return end

-- ====================================================================
-- ADVANCED SILENT ANTI-CHEAT BYPASS LAYER (HARDENED & UNDETECTED)
-- ====================================================================
local oldsetmt = getrenv().setmetatable
local oldgc = getgc
local oldhook = hookmetamethod
local oldhookfunc = hookfunction

getrenv().setmetatable = newcclosure(function(t, mt)
    if mt and typeof(mt) == "table" and rawget(mt, "__mode") == "kv" then
        return oldsetmt({1, 2, 3}, {})
    end
    return oldsetmt(t, mt)
end)

local function is_script_closure(f)
    if typeof(f) ~= "function" then return false end
    local info = debug.getinfo(f)
    if info and info.source and (info.source:match("@") or info.source:match("slug") or info.source:match("CoreGui")) then
        return true
    end
    return false
end

getgc = newcclosure(function(...)
    local g = oldgc(...)
    local r = {}
    for i = 1, #g do
        local v = g[i]
        if typeof(v) == "function" then
            if not is_script_closure(v) then table.insert(r, v) end
        else
            table.insert(r, v)
        end
    end
    return r
end)

if getreg then
    local oldreg = getreg
    getreg = newcclosure(function(...)
        local r = oldreg(...)
        local cleaned = {}
        for k, v in pairs(r) do
            if not is_script_closure(v) and not is_script_closure(k) then cleaned[k] = v end
        end
        return cleaned
    end)
end

hookmetamethod = newcclosure(function(obj, method, func) return oldhook(obj, method, newcclosure(func)) end)
hookfunction = newcclosure(function(old, new) return oldhookfunc(old, newcclosure(new)) end)

pcall(function()
    local CameraSecurity = game:GetService("ReplicatedFirst"):WaitForChild("CameraSecurity", 5)
    if CameraSecurity then
        local module = require(CameraSecurity)
        if module then
            local mt = getmetatable(module)
            if mt then
                mt.__index = newcclosure(function(tbl, key) return rawget(tbl, key) end)
                mt.__newindex = newcclosure(function(tbl, key, value) return rawset(tbl, key, value) end)
            end
            module.SecurityDisabled = true
        end
    end
end)
-- ====================================================================

local function applyBypass()
    task.spawn(function()
        xpcall(function()
            local blockedNames = {"anticheat", "ac", "security", "detection", "monitor"}
            local function blockScript(obj)
                if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                    local n=obj.Name:lower()
                    for _,ac in pairs(blockedNames) do
                        if n:find(ac) then xpcall(function() obj.Disabled=true end, function() end); break end
                    end
                end
            end
            for _,obj in pairs(game:GetDescendants()) do blockScript(obj) end
            game.DescendantAdded:Connect(blockScript)
        end, function() end)
        xpcall(function()
            local networkClient=game:GetService("NetworkClient")
            if networkClient then
                networkClient.ChildAdded:Connect(function(child)
                    local n=child.Name:lower()
                    if n:find("telemetry") or n:find("log") or n:find("report") then
                        xpcall(function() child:Destroy() end, function() end)
                    end
                end)
            end
        end, function() end)
    end)
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")
local ScriptContext = game:GetService("ScriptContext")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = true
Library.ShowToggleFrameInKeybinds = true

local Player = Players.LocalPlayer
local ConfigFolder = "yeezy_v1"

-- Global Settings State
local GlobalSettings = {
    AutoloadEnabled = false,
    SilentLoadEnabled = false,
    AutoloadConfigName = ""
}

local CurrentConfigName = "default"
local StatsOverlay = nil
local StatsLoop = nil

local function EnsureFolder()
    if isfolder and not isfolder(ConfigFolder) then
        makefolder(ConfigFolder)
    end
end

local Modules, CosmeticLibrary, ItemLibrary, PlayerDataUtility, PlayerDataController
local ClientItemModule, Utility
local FloatingModelModule, StaticViewModelModule, EquipmentStateModule, CosmeticsModule

local LoadedCosmetics = {skins = {}, wraps = {}, charms = {}, finishers = {}}
local CosmeticsByWeapon = {}
local OriginalFunctions = {}

local CustomEquipped = { Skins = {}, Wraps = {}, Charms = {}, Finisher = nil }
local UnlockState = { Skins = true, Wraps = true, Charms = true, Finishers = true }
local UISettings = {}
local HooksActive = false
local _SkipSkinRedirect = false

CurrentEquipmentState = { Weapon = nil, Type = nil }

local CosmeticTypeCache = {}
local SkinModelCache = {}
local InfoStatsLabel = nil
local StatsRenderConnection = nil

local SpooferState = {
    Active = false, VictimId = "", Helper = "", Level = "1", Streak = "0", ELO = "0",
    Keys = "", Platform = "DESKTOP", Premium = false, Verified = false,
}
local SpooferDecodedData = nil
local SpooferHookInstalled = false
local SpooferRenderConnection = nil
local SpooferOldHook = nil
local SpooferOldNamecall = nil
local SpooferCharConnection = nil

local EmoteSwapState = { Enabled = false, OriginalEmote = "Shoulder Brush", ReplacementEmote = "Take The L" }
local OldRequireHook = nil

local RankPresets = {
    {"Bronze I", 0}, {"Bronze II", 200}, {"Bronze III", 400},
    {"Silver I", 600}, {"Silver II", 800}, {"Silver III", 1000},
    {"Gold I", 1200}, {"Gold II", 1400}, {"Gold III", 1600},
    {"Platinum I", 1800}, {"Platinum II", 2000}, {"Platinum III", 2200},
    {"Diamond I", 2400}, {"Diamond II", 2600}, {"Diamond III", 2800},
    {"Onyx I", 3000}, {"Onyx II", 3200}, {"Onyx III", 3400},
    {"Nemesis", 3600}
}
local RankNames = {}
for _, v in ipairs(RankPresets) do table.insert(RankNames, v[1]) end

local PlatformImageTable = {
    ["DESKTOP"] = "rbxassetid://17136633356",
    ["MOBILE"] = "rbxassetid://17136633510",
    ["CONSOLE"] = "rbxassetid://17136633629",
    ["VR"] = "rbxassetid://17136765745"
}
local PlatformNames = {"DESKTOP", "MOBILE", "CONSOLE", "VR"}

local WorldDefaults = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    Hue = 0,
    ResolutionScale = 1.0,
    ResolutionEnabled = false,
    SkyColor = Color3.fromRGB(199, 170, 160)
}

-- Notification Suppressor Helper
local function SendNotification(title, text, duration)
    if not GlobalSettings.SilentLoadEnabled then
        Library:Notify({Title = title, Description = text, Time = duration or 3})
    end
end

-- ============================================
-- DYNAMIC PROFILE MANAGEMENT SYSTEM
-- ============================================
local function GetConfigList()
    EnsureFolder()
    local list = {}
    if listfiles then
        local files = listfiles(ConfigFolder)
        for _, file in ipairs(files) do
            if file:sub(-5) == ".json" and not file:find("global_settings") then
                local cleanName = file:gsub(ConfigFolder .. "/", ""):gsub(ConfigFolder .. "\\", ""):gsub("%.json", "")
                table.insert(list, cleanName)
            end
        end
    end
    if #list == 0 then table.insert(list, "default") end
    return list
end

local function SaveGlobalSettings()
    if writefile then
        pcall(function()
            EnsureFolder()
            writefile(ConfigFolder .. "/global_settings.dat", HttpService:JSONEncode(GlobalSettings))
        end)
    end
end

local function LoadGlobalSettings()
    if readfile and isfile and isfile(ConfigFolder .. "/global_settings.dat") then
        pcall(function()
            local decoded = HttpService:JSONDecode(readfile(ConfigFolder .. "/global_settings.dat"))
            if decoded then
                for k, v in pairs(decoded) do GlobalSettings[k] = v end
            end
        end)
    end
end

-- ============================================
-- AIMBOT & TRIGGERBOT MODULES
-- ============================================
local AimbotState = {
    Enabled = false, Keybind = "E", KeybindMode = "Hold", ToggleAiming = false, Smoothness = 4, FOV = 150, MaxDistance = 1000, 
    TeamCheck = true, VisibleCheck = false, TargetPart = "Head", FOVVisible = true, FOVColor = Color3.fromRGB(255, 255, 255), 
    FOVFilled = false, SnapLine = false, SnapLineColor = Color3.fromRGB(255, 255, 255)
}
local TriggerbotState = {
    Enabled = false, Mode = "Always", ToggleActive = false, Keybind = "V", TargetPart = "Head", TeamCheck = true, WallCheck = true, 
    MaxDistance = 1000, CrosshairRadius = 25, Delay = 0, RandomDelay = false, MinDelay = 20, MaxDelay = 90, LastFire = 0, NextFire = 0,
    RequireScope = false
}
local AimbotConnection, FOVCircle, SnapLine, TriggerbotConnection = nil, nil, nil, nil

local function IsKeyHeld(key)
    if not key or key == "" then return false end
    if key == "E" then return UserInputService:IsKeyDown(Enum.KeyCode.E) end
    if key == "V" then return UserInputService:IsKeyDown(Enum.KeyCode.V) end
    pcall(function()
        if key:match("^Mouse") then
            return UserInputService:IsMouseButtonPressed(Enum.UserInputType[key])
        else
            return UserInputService:IsKeyDown(Enum.KeyCode[key])
        end
    end)
    return false
end

local function IsOnEnemyTeam(targetPlayer)
    if not AimbotState.TeamCheck then return true end
    if targetPlayer.Team ~= LocalPlayer.Team then return true end
    if targetPlayer:GetAttribute("Team") and LocalPlayer:GetAttribute("Team") then
        return targetPlayer:GetAttribute("Team") ~= LocalPlayer:GetAttribute("Team")
    end
    return false
end

local function IsSniperScoped()
    if not TriggerbotState.RequireScope then return true end
    local camera = workspace.CurrentCamera
    if camera and camera.FieldOfView < 55 then 
        return true 
    end
    return false
end

local function GetClosestPlayer()
    local camera = workspace.CurrentCamera
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local closest = nil
    local closestDist = AimbotState.FOV

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not player.Character then continue end
        if not IsOnEnemyTeam(player) then continue end

        local targetPart = player.Character:FindFirstChild(AimbotState.TargetPart)
        if not targetPart then continue end

        local humanoid = player.Character:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health <= 0 then continue end

        local pos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end

        local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
        if distance > AimbotState.MaxDistance then continue end

        if AimbotState.VisibleCheck then
            local ray = Ray.new(camera.CFrame.Position, (targetPart.Position - camera.CFrame.Position).Unit * distance)
            local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, camera})
            if hit and not hit:IsDescendantOf(player.Character) then continue end
        end

        local screenPos = Vector2.new(pos.X, pos.Y)
        local distFromCenter = (screenPos - center).Magnitude
        if distFromCenter < closestDist then
            closest = targetPart
            closestDist = distFromCenter
        end
    end
    return closest
end

local function AimAt(target)
    if not target or not mousemoverel then return end
    local camera = workspace.CurrentCamera
    local pos, onScreen = camera:WorldToViewportPoint(target.Position)
    if not onScreen then return end
    
    local mousePos = UserInputService:GetMouseLocation()
    local dx = (pos.X - mousePos.X) / (AimbotState.Smoothness <= 0 and 1 or AimbotState.Smoothness)
    local dy = (pos.Y - mousePos.Y) / (AimbotState.Smoothness <= 0 and 1 or AimbotState.Smoothness)
    
    mousemoverel(dx, dy)
end

local function UpdateAimbot()
    if not AimbotState.Enabled then return end
    local camera = workspace.CurrentCamera
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    if FOVCircle then
        FOVCircle.Visible = AimbotState.FOVVisible
        FOVCircle.Radius = AimbotState.FOV
        FOVCircle.Position = center
        FOVCircle.Color = AimbotState.FOVColor
        FOVCircle.Filled = AimbotState.FOVFilled
    end

    local target = GetClosestPlayer()
    local shouldAim = false
    local key = AimbotState.Keybind
    if Options.AimbotKeybind and Options.AimbotKeybind.Value then key = Options.AimbotKeybind.Value end

    if AimbotState.KeybindMode == "Hold" then
        shouldAim = IsKeyHeld(key)
    elseif AimbotState.KeybindMode == "Toggle" then
        shouldAim = AimbotState.ToggleAiming
    end

    if shouldAim and target then
        AimAt(target)
    end
end

local function StartAimbot()
    if not FOVCircle then 
        FOVCircle = Drawing.new("Circle") 
        FOVCircle.Thickness = 1
        FOVCircle.NumSides = 64
    end
    if AimbotConnection then return end
    AimbotConnection = RunService.RenderStepped:Connect(UpdateAimbot)
end

local function StopAimbot() 
    if AimbotConnection then AimbotConnection:Disconnect() AimbotConnection = nil end 
    if FOVCircle then FOVCircle:Remove() FOVCircle = nil end 
end

local function GetTriggerbotTarget()
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local closestTarget = nil
    local closestDist = TriggerbotState.CrosshairRadius

    for _, player in ipairs(Players:GetPlayers()) do
        if player and player ~= LocalPlayer then
            if not IsOnEnemyTeam(player) then continue end
            local character = player.Character
            if not character then continue end
            local targetPart = character:FindFirstChild(TriggerbotState.TargetPart)
            if not targetPart then continue end
            
            local pos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
            if not onScreen then continue end
            local screenPos = Vector2.new(pos.X, pos.Y)
            local dist = (screenPos - center).Magnitude
            if dist <= closestDist then
                if TriggerbotState.WallCheck then
                    local params = RaycastParams.new()
                    params.FilterDescendantsInstances = {LocalPlayer.Character, camera}
                    params.FilterType = Enum.RaycastFilterType.Blacklist
                    local ray = workspace:Raycast(camera.CFrame.Position, (targetPart.Position - camera.CFrame.Position).Unit * TriggerbotState.MaxDistance, params)
                    if not ray or not ray.Instance or not ray.Instance:IsDescendantOf(character) then continue end
                end
                closestTarget = targetPart
                closestDist = dist
            end
        end
    end
    return closestTarget
end

local function UpdateTriggerbot()
    if not TriggerbotState.Enabled then return end
    if TriggerbotState.Mode == "Hold" and not IsKeyHeld(TriggerbotState.Keybind) then return end
    if TriggerbotState.Mode == "Toggle" and not TriggerbotState.ToggleActive then return end
    
    if not IsSniperScoped() then return end
    if tick() < TriggerbotState.NextFire then return end
    
    local targetPart = GetTriggerbotTarget()
    if targetPart and mouse1click then
        mouse1click()
        TriggerbotState.LastFire = tick()
        if TriggerbotState.RandomDelay then
            TriggerbotState.NextFire = tick() + (math.random(TriggerbotState.MinDelay, TriggerbotState.MaxDelay) / 1000)
        else
            TriggerbotState.NextFire = tick() + (TriggerbotState.Delay / 1000)
        end
    end
end

-- ============================================
-- VISUALS TAB MODULES
-- ============================================
local ESPState = { 
    Enabled = false, Boxes = true, BoxFilled = false, Names = true, ShowDistance = true, TeamCheck = false, 
    MaxDistance = 1000, BoxColor = Color3.fromRGB(255, 255, 255), EnemyColor = Color3.fromRGB(255, 0, 0), NameColor = Color3.fromRGB(255, 255, 255) 
}
local ESPConnections = {}
local ESPObjects = {}

local function RemovePlayerESP(player)
    local data = ESPObjects[player]
    if data then
        for _, obj in pairs(data) do
            pcall(function() obj:Remove() end)
        end
        ESPObjects[player] = nil
    end
end

local function ClearESP()
    for player, _ in pairs(ESPObjects) do
        RemovePlayerESP(player)
    end
    ESPObjects = {}
end

local function CreateESPObjects(player)
    if player == LocalPlayer or ESPObjects[player] then return end
    ESPObjects[player] = {
        BoxOutline = Drawing.new("Square"),
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        HealthBarOutline = Drawing.new("Square"),
        HealthBar = Drawing.new("Square")
    }
    local objs = ESPObjects[player]
    objs.BoxOutline.Thickness = 3
    objs.BoxOutline.Filled = false
    objs.BoxOutline.Color = Color3.fromRGB(0,0,0)
    objs.BoxOutline.Transparency = 0.5
    
    objs.Box.Thickness = 1
    objs.Box.Filled = false
    
    objs.Name.Size = 13
    objs.Name.Outline = true
    objs.Name.Center = true
    
    objs.HealthBarOutline.Filled = true
    objs.HealthBarOutline.Color = Color3.fromRGB(0,0,0)
    objs.HealthBarOutline.Thickness = 1
    
    objs.HealthBar.Filled = true
    objs.HealthBar.Thickness = 1
end

local function UpdateESP()
    if not ESPState.Enabled then ClearESP() return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player and player ~= LocalPlayer then
            local objs = ESPObjects[player]
            local character = player.Character
            
            if not ESPState.TeamCheck and player.Team == LocalPlayer.Team and not IsOnEnemyTeam(player) then
                if objs then for _, o in pairs(objs) do o.Visible = false end end
                continue
            end
            
            if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") then
                local hrp = character.HumanoidRootPart
                local humanoid = character.Humanoid
                
                if humanoid.Health > 0 then
                    local pos, onScreen = camera:WorldToViewportPoint(hrp.Position)
                    local distance = (camera.CFrame.Position - hrp.Position).Magnitude
                    
                    if onScreen and distance <= ESPState.MaxDistance then
                        if not objs then 
                            CreateESPObjects(player)
                            objs = ESPObjects[player]
                        end
                        
                        local head = character:FindFirstChild("Head")
                        local topPos = camera:WorldToViewportPoint(head and head.Position + Vector3.new(0, 0.5, 0) or hrp.Position + Vector3.new(0, 3, 0))
                        local bottomPos = camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.2, 0))
                        
                        local boxHeight = math.abs(topPos.Y - bottomPos.Y)
                        local boxWidth = boxHeight * 0.55
                        
                        local isEnemy = IsOnEnemyTeam(player)
                        local currentBoxColor = isEnemy and ESPState.EnemyColor or ESPState.BoxColor
                        
                        if ESPState.Boxes then
                            objs.BoxOutline.Size = Vector2.new(boxWidth, boxHeight)
                            objs.BoxOutline.Position = Vector2.new(pos.X - boxWidth/2, topPos.Y)
                            objs.BoxOutline.Visible = true
                            
                            objs.Box.Size = Vector2.new(boxWidth, boxHeight)
                            objs.Box.Position = Vector2.new(pos.X - boxWidth/2, topPos.Y)
                            objs.Box.Color = currentBoxColor
                            objs.Box.Visible = true
                        else
                            objs.Box.Visible = false
                            objs.BoxOutline.Visible = false
                        end
                        
                        if ESPState.Names then
                            objs.Name.Text = player.Name .. (ESPState.ShowDistance and " ["..math.floor(distance).."m]" or "")
                            objs.Name.Position = Vector2.new(pos.X, topPos.Y - 17)
                            objs.Name.Color = ESPState.NameColor
                            objs.Name.Visible = true
                        else
                            objs.Name.Visible = false
                        end
                        
                        local healthPct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                        local barX = pos.X - boxWidth/2 - 6
                        local barY = topPos.Y
                        
                        objs.HealthBarOutline.Size = Vector2.new(4, boxHeight)
                        objs.HealthBarOutline.Position = Vector2.new(barX, barY)
                        objs.HealthBarOutline.Visible = true
                        
                        objs.HealthBar.Size = Vector2.new(2, boxHeight * healthPct)
                        objs.HealthBar.Position = Vector2.new(barX + 1, barY + (boxHeight - (boxHeight * healthPct)))
                        objs.HealthBar.Color = Color3.fromHSV((healthPct * 120) / 360, 1, 1)
                        objs.HealthBar.Visible = true
                        continue
                    end
                end
            end
            if objs then for _, o in pairs(objs) do o.Visible = false end end
        end
    end
end

local function StartESP()
    if ESPConnections.RenderStepped then return end
    ESPConnections.RenderStepped = RunService.RenderStepped:Connect(UpdateESP)
    ESPConnections.PlayerAdded = Players.PlayerAdded:Connect(CreateESPObjects)
    ESPConnections.PlayerRemoving = Players.PlayerRemoving:Connect(RemovePlayerESP)
end

local function StopESP() 
    for _, c in pairs(ESPConnections) do c:Disconnect() end 
    ESPConnections = {} 
    ClearESP() 
end

local function SaveConfig(name)
    local targetName = name or CurrentConfigName
    local config = { CustomEquipped = CustomEquipped, UnlockState = UnlockState, SpooferState = SpooferState, UISettings = UISettings }
    if writefile then
        pcall(function()
            EnsureFolder()
            writefile(ConfigFolder .. "/" .. targetName .. ".json", HttpService:JSONEncode(config))
            if Options.ConfigDropdown then Options.ConfigDropdown:SetValues(GetConfigList()) end
            SendNotification("Profile Manager", "Saved config: " .. targetName)
        end)
    end
end

local function LoadConfig(name)
    local targetName = name or CurrentConfigName
    if readfile and isfile and isfile(ConfigFolder .. "/" .. targetName .. ".json") then
        local success, result = pcall(function() return HttpService:JSONDecode(readfile(ConfigFolder .. "/" .. targetName .. ".json")) end)
        if success and result then
            CustomEquipped = result.CustomEquipped or CustomEquipped
            UnlockState = result.UnlockState or UnlockState
            if result.SpooferState then for k, v in pairs(result.SpooferState) do SpooferState[k] = v end end
            CurrentConfigName = targetName
            RestoreSpooferUI()
            UpdateStatsLabel()
            UpdateDropdowns()
            SendNotification("Profile Manager", "Loaded config profile: " .. targetName)
            return true
        end
    end
    return false
end

local function DeleteConfig(name)
    if not name or name == "default" then return end
    if delfile and isfile(ConfigFolder .. "/" .. name .. ".json") then
        pcall(function()
            delfile(ConfigFolder .. "/" .. name .. ".json")
            if Options.ConfigDropdown then Options.ConfigDropdown:SetValues(GetConfigList()) end
            Library:Notify({Title = "Profile Manager", Description = "Deleted config: " .. name, Time = 3})
        end)
    end
end

local function LoadGameModules()
    Modules = ReplicatedStorage:WaitForChild("Modules")
    CosmeticLibrary = require(Modules:WaitForChild("CosmeticLibrary"))
    ItemLibrary = require(Modules:WaitForChild("ItemLibrary"))
    PlayerDataUtility = require(Modules:WaitForChild("PlayerDataUtility"))
    PlayerDataController = require(Player:WaitForChild("PlayerScripts"):WaitForChild("Controllers"):WaitForChild("PlayerDataController"))
    ClientItemModule = require(Player.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
    Utility = require(ReplicatedStorage.Modules.Utility)
    FloatingModelModule = require(Player.PlayerScripts.Modules.UserInterface.Equipment.FloatingModel)
    StaticViewModelModule = require(Player.PlayerScripts.Modules.StaticModel.StaticViewModel)
    EquipmentStateModule = require(Player.PlayerScripts.Modules.UserInterface.Equipment.EquipmentState)
    CosmeticsModule = require(Player.PlayerScripts.Modules.UserInterface.Equipment.Interface.Customize.Cosmetics)
end

local function BuildCosmeticLists()
    if not CosmeticLibrary then return end
    LoadedCosmetics = {skins = {}, wraps = {}, charms = {}, finishers = {}}
    CosmeticsByWeapon = {}
    CosmeticTypeCache = {}
    for name, data in pairs(CosmeticLibrary.Cosmetics) do
        if type(data) == "table" and data.Type then
            local t = tostring(data.Type):lower()
            CosmeticTypeCache[name] = t
            if t == "skin" then
                table.insert(LoadedCosmetics.skins, name)
                local weaponName = data.ItemName
                if weaponName then
                    if not CosmeticsByWeapon[weaponName] then CosmeticsByWeapon[weaponName] = {skins = {}} end
                    table.insert(CosmeticsByWeapon[weaponName].skins, name)
                end
            elseif t == "wrap" then table.insert(LoadedCosmetics.wraps, name)
            elseif t == "charm" then table.insert(LoadedCosmetics.charms, name)
            elseif t == "finisher" then table.insert(LoadedCosmetics.finishers, name)
            end
        end
    end
end

local function GetWeaponList()
    local weapons = {}
    if ItemLibrary and ItemLibrary.Items then for name, _ in pairs(ItemLibrary.Items) do table.insert(weapons, name) end end
    return weapons
end

local function GetSkinsForWeapon(weaponName)
    if not weaponName or weaponName == "all weapons" then return LoadedCosmetics.skins end
    if CosmeticsByWeapon[weaponName] then return CosmeticsByWeapon[weaponName].skins or {} end
    return {}
end

local function GetCosmeticType(cosmeticName)
    if not cosmeticName or cosmeticName == "NONE_COSMETIC" then return nil end
    if CosmeticTypeCache[cosmeticName] then return CosmeticTypeCache[cosmeticName] end
    return nil
end

local function IsCustomEquipped(cosmeticName, weaponName)
    local cosmeticType = GetCosmeticType(cosmeticName)
    if not cosmeticType then return false end
    if cosmeticType == "skin" then return CustomEquipped.Skins[weaponName] == cosmeticName
    elseif cosmeticType == "wrap" then return CustomEquipped.Wraps[weaponName] == cosmeticName or CustomEquipped.Wraps["_ALL"] == cosmeticName
    end
    return false
end

local function SkinModelExists(skinName)
    return Player.PlayerScripts.Assets.ViewModels:FindFirstChild(skinName, true) ~= nil
end

local function CreateStatsOverlay()
    if StatsOverlay then return end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "YeezyV1StatsOverlay"
    screenGui.ResetOnSpawn = false
    pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
    if not screenGui.Parent then screenGui.Parent = Player:WaitForChild("PlayerGui") end
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 24)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.Parent = screenGui
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Text = "YEEZY V1 | Loaded Safely"
    label.Parent = frame
    StatsOverlay = { Gui = screenGui, Frame = frame, Label = label }
end

local function DestroyStatsOverlay()
    if StatsOverlay then pcall(function() StatsOverlay.Gui:Destroy() end) StatsOverlay = nil end
end

local function InstallOwnershipHooks()
    if not CosmeticLibrary then return end
    local ownershipFunctions = {"OwnsCosmetic", "OwnsCosmeticNormally", "OwnsCosmeticUniversally"}
    for _, funcName in ipairs(ownershipFunctions) do
        if CosmeticLibrary[funcName] then
            OriginalFunctions["CL_" .. funcName] = CosmeticLibrary[funcName]
            CosmeticLibrary[funcName] = function(self, playerData, cosmeticName, ...)
                return true
            end
        end
    end
end

local function InstallClientItemHook()
    if not OriginalFunctions.ClientItem_CreateViewModel then
        OriginalFunctions.ClientItem_CreateViewModel = ClientItemModule._CreateViewModel
        ClientItemModule._CreateViewModel = function(self, serialData)
            local weaponName = self.Name
            serialData = serialData or {}
            local dataKey = self:ToEnum("Data")
            local nameKey = self:ToEnum("Name")
            if self.ClientFighter and self.ClientFighter.Player == Player then
                if not serialData[dataKey] then serialData[dataKey] = {} end
                local customSkin = CustomEquipped.Skins[weaponName]
                if customSkin and SkinModelExists(customSkin) then serialData[dataKey][nameKey] = customSkin end
            end
            return OriginalFunctions.ClientItem_CreateViewModel(self, serialData)
        end
    end
end

local function UpdateDropdowns()
    task.wait(0.1)
    if Options.SkinDropdown and #LoadedCosmetics.skins > 0 then
        local weaponFilter = Options.WeaponDropdown and Options.WeaponDropdown.Value
        Options.SkinDropdown:SetValues(GetSkinsForWeapon(weaponFilter))
    end
    if Options.WeaponDropdown then
        local wpns = GetWeaponList()
        table.insert(wpns, 1, "all weapons")
        Options.WeaponDropdown:SetValues(wpns)
    end
end

local function UpdateStatsLabel()
    if InfoStatsLabel then InfoStatsLabel:SetText("System Engine Validated") end
end

local function RestoreSpooferUI() end

local function InstallAllHooks()
    InstallOwnershipHooks()
    InstallClientItemHook()
end

local function ApplySpooferStats() end

-- ============================================
-- CREATE UI WINDOW INTERFACE
-- ============================================
local Window = Library:CreateWindow({
    Title = "YEEZY V1", Footer = "YEEZY V1", Icon = 95816097006870, NotifySide = "Right", ShowCustomCursor = false,
})

local Tabs = {
    Main = Window:AddTab("Skin Changer", "shirt"),
    World = Window:AddTab("World", "globe"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Aimbot = Window:AddTab("Aimbot", "target"),
    Triggerbot = Window:AddTab("Triggerbot", "target"),
    Settings = Window:AddTab("Settings", "wrench")
}

local InfoGroup = Tabs.Main:AddLeftGroupbox("Info")
InfoStatsLabel = InfoGroup:AddLabel("Equipped: Initializing")

local SkinSelectGroup = Tabs.Main:AddLeftGroupbox("Select Skin")
SkinSelectGroup:AddDropdown("WeaponDropdown", { Values = {"all weapons"}, Default = 1, Text = "Weapon", Callback = function(v) UpdateDropdowns() end })
SkinSelectGroup:AddDropdown("SkinDropdown", { Values = {"None"}, Default = 1, Text = "Skin" })
SkinSelectGroup:AddButton({ Text = "Apply Skin", Func = function() CustomEquipped.Skins[Options.WeaponDropdown.Value] = Options.SkinDropdown.Value SaveConfig() end })

local VisualsGroup = Tabs.Visuals:AddLeftGroupbox("ESP Layout")
VisualsGroup:AddToggle("ESPEnabled", { Text = "Enable ESP Rendering", Default = false, Callback = function(v) ESPState.Enabled = v if v then StartESP() else StopESP() end end })
VisualsGroup:AddToggle("ESPBoxes", { Text = "Bounding Boxes", Default = true, Callback = function(v) ESPState.Boxes = v end })
VisualsGroup:AddToggle("ESPNames", { Text = "Show Player Identification", Default = true, Callback = function(v) ESPState.Names = v end })
VisualsGroup:AddSlider("ESPMaxDistance", { Text = "Max ESP Render Distance", Min = 100, Max = 4000, Default = 1000, Rounding = 0, Callback = function(v) ESPState.MaxDistance = v end })

local AimbotGroup = Tabs.Aimbot:AddLeftGroupbox("Aimbot Parameters")
AimbotGroup:AddToggle("AimbotEnabled", { Text = "Enable Aimbot Lock", Default = false, Callback = function(v) AimbotState.Enabled = v if v then StartAimbot() else StopAimbot() end end })
AimbotGroup:AddDropdown("AimbotKeybindMode", { Text = "Activation Mode", Default = 1, Values = {"Hold", "Toggle"}, Callback = function(v) AimbotState.KeybindMode = v end })
AimbotGroup:AddSlider("AimbotSmoothness", { Text = "Smoothness / Mouse Divisor", Min = 1, Max = 20, Default = 4, Rounding = 1, Callback = function(v) AimbotState.Smoothness = v end })
AimbotGroup:AddSlider("AimbotFOV", { Text = "Locking FOV Radius", Min = 30, Max = 400, Default = 150, Rounding = 0, Callback = function(v) AimbotState.FOV = v end })
AimbotGroup:AddToggle("AimbotTeamCheck", { Text = "Team Check", Default = true, Callback = function(v) AimbotState.TeamCheck = v end })
AimbotGroup:AddToggle("AimbotVisCheck", { Text = "Wall Visibility Check", Default = false, Callback = function(v) AimbotState.VisibleCheck = v end })
AimbotGroup:AddDropdown("AimbotTargetPart", { Text = "Target Hitbox Bone", Default = 1, Values = {"Head", "HumanoidRootPart"}, Callback = function(v) AimbotState.TargetPart = v end })
AimbotGroup:AddLabel("Aimbot Keybind"):AddKeyPicker("AimbotKeybind", { Default = "E", NoUI = false, Text = "Aimbot Keybind", Callback = function(v) AimbotState.Keybind = v end })

local TriggerbotGroup = Tabs.Triggerbot:AddLeftGroupbox("Triggerbot Control")
TriggerbotGroup:AddToggle("TriggerbotEnabled", { Text = "Enable Triggerbot", Default = false, Callback = function(v) TriggerbotState.Enabled = v end })
TriggerbotGroup:AddToggle("TriggerbotScopeCheck", { Text = "Sniper & Crossbow Scope Check", Default = false, Callback = function(v) TriggerbotState.RequireScope = v end })
TriggerbotGroup:AddSlider("TriggerbotRadius", { Text = "Crosshair Radius Trigger Box", Min = 5, Max = 100, Default = 25, Rounding = 0, Callback = function(v) TriggerbotState.CrosshairRadius = v end })
TriggerbotGroup:AddDropdown("TriggerbotTargetPart", { Text = "Hitbox Targeting", Default = 1, Values = {"Head", "HumanoidRootPart"}, Callback = function(v) TriggerbotState.TargetPart = v end })

local ConfigGroup = Tabs.Settings:AddLeftGroupbox("Configurations")
ConfigGroup:AddDropdown("ConfigDropdown", { Values = GetConfigList(), Default = 1, Text = "Profile Selection", Callback = function(v) CurrentConfigName = v end })
ConfigGroup:AddButton({ Text = "Save Profile Data", Func = function() SaveConfig(CurrentConfigName) end })
ConfigGroup:AddButton({ Text = "Load Profile Data", Func = function() LoadConfig(CurrentConfigName) end })

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Interface")
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
Library.ToggleKeybind = Options.MenuKeybind

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if AimbotState.Enabled and AimbotState.KeybindMode == "Toggle" then
        local key = Options.AimbotKeybind and Options.AimbotKeybind.Value or AimbotState.Keybind
        if input.KeyCode == Enum.KeyCode[key] or input.UserInputType == Enum.UserInputType[key] then
            AimbotState.ToggleAiming = not AimbotState.ToggleAiming
        end
    end
end)

-- ============================================
-- CRITICAL CONFIG-FIRST COMPLIANT INITIALIZATION
-- ============================================
task.spawn(function()
    EnsureFolder()
    applyBypass()
    LoadGlobalSettings()
    LoadGameModules()
    BuildCosmeticLists()
    PlayerDataController:WaitUntilLoaded()
    CreateStatsOverlay()
    LoadConfig("default")
    InstallAllHooks()
    UpdateDropdowns()
    UpdateStatsLabel()
    if Options.ConfigDropdown then Options.ConfigDropdown:SetValues(GetConfigList()) end
    RunService.RenderStepped:Connect(UpdateTriggerbot)
end)
