if not game:IsLoaded() then game.Loaded:Wait() end
if game.GameId ~= 6035872082 then return end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")
local ScriptContext = game:GetService("ScriptContext")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- Obfuscation-safe bypass (no string literals)
local oldsetmt = getrenv().setmetatable
getrenv().setmetatable = newcclosure(function(t, mt)
    if mt and typeof(mt) == "table" and rawget(mt, "__mode") == "kv" then
        return oldsetmt({1, 2, 3}, {})
    end
    return oldsetmt(t, mt)
end)

local oldgc = getgc
getgc = function(...)
    local g = oldgc(...)
    local r = {}
    for i = 1, #g do
        if typeof(g[i]) ~= "function" then
            r[#r+1] = g[i]
        end
    end
    return r
end

pcall(function()
    local CameraSecurity = game:GetService("ReplicatedFirst"):WaitForChild("CameraSecurity", 5)
    if CameraSecurity then
        local module = require(CameraSecurity)
        if module then
            local mt = getmetatable(module)
            if mt then
                mt.__index = function(tbl, key) return rawget(tbl, key) end
                mt.__newindex = function(tbl, key, value) return rawset(tbl, key, value) end
            end
            module.SecurityDisabled = true
        end
    end
end)

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = true
Library.ShowToggleFrameInKeybinds = true

local Player = Players.LocalPlayer

local ConfigFolder = "yeezy_v1"
local IsAuthenticated = true

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

local CustomEquipped = {
    Skins = {},
    Wraps = {},
    Charms = {},
    Finisher = nil
}

local UnlockState = {
    Skins = true,
    Wraps = true,
    Charms = true,
    Finishers = true
}

local UISettings = {}

local HooksActive = false
local _SkipSkinRedirect = false

CurrentEquipmentState = {
    Weapon = nil,
    Type = nil
}

local ConfigFile = "cosmetics.json"

-- [FIX] Performance caches
local CosmeticTypeCache = {}
local SkinModelCache = {}
local InfoStatsLabel = nil
local StatsRenderConnection = nil

-- Spoofer State
local SpooferState = {
    Active = false,
    VictimId = "",
    Helper = "",
    Level = "1",
    Streak = "0",
    ELO = "0",
    Keys = "",
    Platform = "DESKTOP",
    Premium = false,
    Verified = false,
}
local SpooferDecodedData = nil
local SpooferHookInstalled = false
local SpooferRenderConnection = nil
local SpooferOldHook = nil
local SpooferOldNamecall = nil
local SpooferCharConnection = nil

-- Emote Swap State
local EmoteSwapState = {
    Enabled = false,
    OriginalEmote = "Shoulder Brush",
    ReplacementEmote = "Take The L"
}
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

local function SaveConfig()
    local config = {
        CustomEquipped = CustomEquipped,
        UnlockState = UnlockState,
        SpooferState = SpooferState,
        UISettings = UISettings
    }
    if writefile then
        pcall(function()
            EnsureFolder()
            writefile(ConfigFolder .. "/" .. ConfigFile, HttpService:JSONEncode(config))
        end)
    end
end

local function LoadConfig()
    if readfile and isfile then
        local success, result = pcall(function()
            if isfile(ConfigFolder .. "/" .. ConfigFile) then
                return HttpService:JSONDecode(readfile(ConfigFolder .. "/" .. ConfigFile))
            end
            return nil
        end)
        if success and result then
            CustomEquipped = result.CustomEquipped or CustomEquipped
            UnlockState = result.UnlockState or UnlockState
            if result.SpooferState then
                for k, v in pairs(result.SpooferState) do
                    SpooferState[k] = v
                end
            end
            if result.UISettings then
                for k, v in pairs(result.UISettings) do
                    UISettings[k] = v
                end
            end
            return true
        end
    end
    return false
end

local function BuildCosmeticLists()
    if not CosmeticLibrary then return end
    LoadedCosmetics = {skins = {}, wraps = {}, charms = {}, finishers = {}}
    CosmeticsByWeapon = {}
    CosmeticTypeCache = {} -- [FIX] Reset cache on rebuild

    for name, data in pairs(CosmeticLibrary.Cosmetics) do
        if type(data) == "table" and data.Type then
            local t = tostring(data.Type):lower()
            CosmeticTypeCache[name] = t -- [FIX] Cache type
            if t == "skin" then
                table.insert(LoadedCosmetics.skins, name)
                local weaponName = data.ItemName
                if weaponName then
                    if not CosmeticsByWeapon[weaponName] then
                        CosmeticsByWeapon[weaponName] = {skins = {}}
                    end
                    table.insert(CosmeticsByWeapon[weaponName].skins, name)
                end
            elseif t == "wrap" then
                table.insert(LoadedCosmetics.wraps, name)
            elseif t == "charm" then
                table.insert(LoadedCosmetics.charms, name)
            elseif t == "finisher" then
                table.insert(LoadedCosmetics.finishers, name)
            end
        end
    end
    table.sort(LoadedCosmetics.skins)
    table.sort(LoadedCosmetics.wraps)
    table.sort(LoadedCosmetics.charms)
    table.sort(LoadedCosmetics.finishers)
end

local function GetWeaponList()
    local weapons = {}
    if ItemLibrary and ItemLibrary.Items then
        for name, _ in pairs(ItemLibrary.Items) do
            table.insert(weapons, name)
        end
    end
    table.sort(weapons)
    return weapons
end

local function GetSkinsForWeapon(weaponName)
    if not weaponName or weaponName == "all weapons" then
        return LoadedCosmetics.skins
    end
    if CosmeticsByWeapon[weaponName] then
        return CosmeticsByWeapon[weaponName].skins or {}
    end
    return {}
end

local function GetWeaponFromSkin(skinName)
    local data = CosmeticLibrary.Cosmetics[skinName]
    if data and data.ItemName then
        return data.ItemName
    end
    return nil
end

-- [FIX] Cached version of GetCosmeticType
local function GetCosmeticType(cosmeticName)
    if not cosmeticName or cosmeticName == "NONE_COSMETIC" or cosmeticName == "RANDOM_COSMETIC" then
        return nil
    end
    local cached = CosmeticTypeCache[cosmeticName]
    if cached then return cached end
    local data = CosmeticLibrary and CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[cosmeticName]
    if data and data.Type then
        local t = tostring(data.Type):lower()
        CosmeticTypeCache[cosmeticName] = t
        return t
    end
    return nil
end

local function IsCustomEquipped(cosmeticName, weaponName)
    if not cosmeticName or not weaponName then return false end
    local cosmeticType = GetCosmeticType(cosmeticName)
    if not cosmeticType then return false end
    if cosmeticType == "skin" then
        return CustomEquipped.Skins[weaponName] == cosmeticName
    elseif cosmeticType == "wrap" then
        return CustomEquipped.Wraps[weaponName] == cosmeticName or CustomEquipped.Wraps["_ALL"] == cosmeticName
    elseif cosmeticType == "charm" then
        return CustomEquipped.Charms[weaponName] == cosmeticName or CustomEquipped.Charms["_ALL"] == cosmeticName
    elseif cosmeticType == "finisher" then
        return CustomEquipped.Finisher == cosmeticName
    end
    return false
end

-- [FIX] Cached skin model existence check
local function SkinModelExists(skinName)
    if not skinName then return false end
    local cached = SkinModelCache[skinName]
    if cached ~= nil then return cached end
    local result = Player.PlayerScripts.Assets.ViewModels:FindFirstChild(skinName, true) ~= nil
    SkinModelCache[skinName] = result
    return result
end

local function GetPing()
    local success, ping = pcall(function()
        return Player:GetNetworkPing() * 1000
    end)
    return success and math.floor(ping) or 0
end

local function CreateStatsOverlay()
    if StatsOverlay then return end
    if Toggles.StatsOverlayToggle and not Toggles.StatsOverlayToggle.Value then return end
    local RunService = game:GetService("RunService")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "YeezyV1StatsOverlay"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999
    pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
    if not screenGui.Parent then
        screenGui.Parent = Player:WaitForChild("PlayerGui")
    end
    local frame = Instance.new("Frame")
    frame.Name = "StatsFrame"
    frame.Size = UDim2.new(0, 240, 0, 24)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(50, 50, 50)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = frame
    local label = Instance.new("TextLabel")
    label.Name = "StatsLabel"
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 12
    label.Font = Enum.Font.Code
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = "YEEZY V1 | -- fps | -- ms"
    label.Parent = frame
    StatsOverlay = { Gui = screenGui, Frame = frame, Label = label }
    local frameCount = 0
    local lastTime = tick()
    local currentFPS = 0
    -- [FIX] Store connection for cleanup
    StatsRenderConnection = RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = tick()
        if now - lastTime >= 1 then
            currentFPS = math.floor(frameCount / (now - lastTime))
            frameCount = 0
            lastTime = now
        end
    end)
    StatsLoop = task.spawn(function()
        local lastText = ""
        while StatsOverlay do
            local fps = currentFPS
            local ping = GetPing()
            if StatsOverlay and StatsOverlay.Label then
                local newText = string.format(
                    "YEEZY V1 | %d fps | %d ms",
                    fps, ping
                )
                if newText ~= lastText then
                    StatsOverlay.Label.Text = newText
                    lastText = newText
                end
            end
            task.wait(0.5)
        end
    end)
end

local function DestroyStatsOverlay()
    -- [FIX] Disconnect RenderStepped
    if StatsRenderConnection then
        StatsRenderConnection:Disconnect()
        StatsRenderConnection = nil
    end
    if StatsOverlay then
        pcall(function() StatsOverlay.Gui:Destroy() end)
        StatsOverlay = nil
        StatsLoop = nil
    end
end

-- [FIX] Cached ShouldUnlockCosmetic
local function ShouldUnlockCosmetic(cosmeticName)
    if not cosmeticName then return false end
    local t = CosmeticTypeCache[cosmeticName]
    if not t then
        local data = CosmeticLibrary and CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[cosmeticName]
        if data and data.Type then
            t = tostring(data.Type):lower()
            CosmeticTypeCache[cosmeticName] = t
        else
            return false
        end
    end
    if t == "skin" then return UnlockState.Skins end
    if t == "wrap" then return UnlockState.Wraps end
    if t == "charm" then return UnlockState.Charms end
    if t == "finisher" then return UnlockState.Finishers end
    return false
end

local function InstallOwnershipHooks()
    if not CosmeticLibrary then return end
    local ownershipFunctions = {
        "OwnsCosmetic",
        "OwnsCosmeticNormally",
        "OwnsCosmeticUniversally",
        "OwnsCosmeticForWeapon",
        "OwnsCosmeticForSomething"
    }
    for _, funcName in ipairs(ownershipFunctions) do
        if CosmeticLibrary[funcName] and not OriginalFunctions["CL_" .. funcName] then
            OriginalFunctions["CL_" .. funcName] = CosmeticLibrary[funcName]
            CosmeticLibrary[funcName] = function(self, playerData, cosmeticName, ...)
                if ShouldUnlockCosmetic(cosmeticName) then
                    return true
                end
                return OriginalFunctions["CL_" .. funcName](self, playerData, cosmeticName, ...)
            end
        end
    end
end

local function InstallClientItemHook()
    if not OriginalFunctions.ClientItem_CreateViewModel then
        OriginalFunctions.ClientItem_CreateViewModel = ClientItemModule._CreateViewModel
        ClientItemModule._CreateViewModel = function(self, serialData)
            local weaponName = self.Name
            local isLocalPlayer = self.ClientFighter and self.ClientFighter.Player == Player
            serialData = serialData or {}
            local dataKey = self:ToEnum("Data")
            local nameKey = self:ToEnum("Name")
            if isLocalPlayer then
                if not serialData[dataKey] then
                    serialData[dataKey] = {}
                end
                local customSkin = CustomEquipped.Skins[weaponName]
                if customSkin and UnlockState.Skins then
                    if SkinModelExists(customSkin) then
                        serialData[dataKey][nameKey] = customSkin
                    end
                end
                local customWrap = CustomEquipped.Wraps[weaponName] or CustomEquipped.Wraps["_ALL"]
                if customWrap and UnlockState.Wraps then
                    local wrapKey = self:ToEnum("Wrap") or "À"
                    serialData[dataKey][wrapKey] = { Name = customWrap }
                end
                local customCharm = CustomEquipped.Charms[weaponName] or CustomEquipped.Charms["_ALL"]
                if customCharm and UnlockState.Charms then
                    local charmKey = self:ToEnum("Charm") or "k"
                    serialData[dataKey][charmKey] = { Name = customCharm }
                end
            end
            -- [FIX] Skip skin redirect for non-local players
            if not isLocalPlayer then
                _SkipSkinRedirect = true
            end
            local result = OriginalFunctions.ClientItem_CreateViewModel(self, serialData)
            _SkipSkinRedirect = false
            return result
        end
    end
end

local function InstallLookThroughHook()
    if not OriginalFunctions.Utility_LookThrough then
        OriginalFunctions.Utility_LookThrough = Utility.LookThrough
        Utility.LookThrough = function(self, parent, name)
            if not _SkipSkinRedirect then
                local customSkin = CustomEquipped.Skins[name]
                if customSkin and UnlockState.Skins then
                    local skinResult = OriginalFunctions.Utility_LookThrough(self, parent, customSkin)
                    if skinResult then
                        return skinResult
                    end
                end
            end
            return OriginalFunctions.Utility_LookThrough(self, parent, name)
        end
    end
end

local function InstallGetWeaponDataHook()
    if not OriginalFunctions.GetWeaponData then
        OriginalFunctions.GetWeaponData = PlayerDataUtility.GetWeaponData
        PlayerDataUtility.GetWeaponData = function(self, playerData, weaponName)
            local originalData, index = OriginalFunctions.GetWeaponData(self, playerData, weaponName)

            -- [FIX] Skip custom data when processing other players' viewmodels
            if _SkipSkinRedirect then
                return originalData, index
            end

            -- [FIX] Early return when no custom cosmetics for this weapon
            local wantsSkin = UnlockState.Skins and CustomEquipped.Skins[weaponName]
            local wantsWrap = UnlockState.Wraps and (CustomEquipped.Wraps[weaponName] or CustomEquipped.Wraps["_ALL"])
            local wantsCharm = UnlockState.Charms and (CustomEquipped.Charms[weaponName] or CustomEquipped.Charms["_ALL"])
            local wantsFinisher = UnlockState.Finishers and CustomEquipped.Finisher
            if not wantsSkin and not wantsWrap and not wantsCharm and not wantsFinisher then
                return originalData, index
            end

            if not originalData then
                local hasSkin = CustomEquipped.Skins[weaponName] and UnlockState.Skins
                local hasWrap = (CustomEquipped.Wraps[weaponName] or CustomEquipped.Wraps["_ALL"]) and UnlockState.Wraps
                local hasCharm = (CustomEquipped.Charms[weaponName] or CustomEquipped.Charms["_ALL"]) and UnlockState.Charms
                if hasSkin or hasWrap or hasCharm then
                    originalData = { Name = weaponName, Level = 1, XP = 0, Prestige = 0 }
                    index = -1
                else
                    return nil, nil
                end
            else
                local modifiedData = {}
                for k, v in pairs(originalData) do
                    if type(v) == "table" then
                        modifiedData[k] = {}
                        for k2, v2 in pairs(v) do
                            modifiedData[k][k2] = v2
                        end
                    else
                        modifiedData[k] = v
                    end
                end
                originalData = modifiedData
            end

            if UnlockState.Skins and CustomEquipped.Skins[weaponName] then
                originalData.Skin = { Name = CustomEquipped.Skins[weaponName] }
            end
            local wrap = CustomEquipped.Wraps[weaponName] or CustomEquipped.Wraps["_ALL"]
            if UnlockState.Wraps and wrap then
                originalData.Wrap = { Name = wrap }
            end
            local charm = CustomEquipped.Charms[weaponName] or CustomEquipped.Charms["_ALL"]
            if UnlockState.Charms and charm then
                originalData.Charm = { Name = charm }
            end
            if UnlockState.Finishers and CustomEquipped.Finisher then
                originalData.Finisher = { Name = CustomEquipped.Finisher }
            end
            return originalData, index
        end
    end
end

local function InstallFloatingModelHook()
    if not OriginalFunctions.FloatingModel_GetViewModelName then
        OriginalFunctions.FloatingModel_GetViewModelName = FloatingModelModule._GetViewModelName
        FloatingModelModule._GetViewModelName = function(self)
            local originalName = OriginalFunctions.FloatingModel_GetViewModelName(self)
            if originalName and UnlockState.Skins then
                local customSkin = CustomEquipped.Skins[originalName]
                if customSkin and SkinModelExists(customSkin) then
                    return customSkin
                end
            end
            return originalName
        end
    end
end

local function InstallStaticViewModelHooks()
    if not OriginalFunctions.StaticViewModel_SetWrap then
        OriginalFunctions.StaticViewModel_SetWrap = StaticViewModelModule.SetWrap
        StaticViewModelModule.SetWrap = function(self, wrapData)
            -- StaticViewModel is equipment UI (always local player)
            local weaponName = self.WeaponName
            local customWrap = nil
            if weaponName and UnlockState.Wraps then
                customWrap = CustomEquipped.Wraps[weaponName] or CustomEquipped.Wraps["_ALL"]
            end
            if customWrap then
                wrapData = { Name = customWrap }
            end
            return OriginalFunctions.StaticViewModel_SetWrap(self, wrapData)
        end
    end
    if not OriginalFunctions.StaticViewModel_SetCharm then
        OriginalFunctions.StaticViewModel_SetCharm = StaticViewModelModule.SetCharm
        StaticViewModelModule.SetCharm = function(self, charmData)
            -- StaticViewModel is equipment UI (always local player)
            local weaponName = self.WeaponName
            local customCharm = nil
            if weaponName and UnlockState.Charms then
                customCharm = CustomEquipped.Charms[weaponName] or CustomEquipped.Charms["_ALL"]
            end
            if customCharm then
                charmData = { Name = customCharm }
            end
            return OriginalFunctions.StaticViewModel_SetCharm(self, charmData)
        end
    end
end

local function InstallEquipmentStateHooks()
    if not OriginalFunctions.EquipmentState_SelectCosmetic then
        OriginalFunctions.EquipmentState_SelectCosmetic = EquipmentStateModule.SelectCosmetic
        EquipmentStateModule.SelectCosmetic = function(self, cosmeticName)
            local weaponName = self.SelectedWeapon
            CurrentEquipmentState.Weapon = weaponName
            CurrentEquipmentState.Type = GetCosmeticType(cosmeticName)  -- Track type accurately

            -- ALWAYS let original equip/save (no blocking!)
            local result = OriginalFunctions.EquipmentState_SelectCosmetic(self, cosmeticName)
            return result  -- Preserve original return (likely void/table)
        end
    end
    if not OriginalFunctions.EquipmentState_SelectWeapon then
        OriginalFunctions.EquipmentState_SelectWeapon = EquipmentStateModule.SelectWeapon
        EquipmentStateModule.SelectWeapon = function(self, weaponName)
            CurrentEquipmentState.Weapon = weaponName
            return OriginalFunctions.EquipmentState_SelectWeapon(self, weaponName)
        end
    end
    if not OriginalFunctions.EquipmentState_StartCustomizing then
        OriginalFunctions.EquipmentState_StartCustomizing = EquipmentStateModule.StartCustomizing
        EquipmentStateModule.StartCustomizing = function(self, cosmeticType)
            CurrentEquipmentState.Type = cosmeticType
            return OriginalFunctions.EquipmentState_StartCustomizing(self, cosmeticType)
        end
    end
end

local function InstallCosmeticsModuleHook()
    if not OriginalFunctions.Cosmetics_IsEquipped then
        OriginalFunctions.Cosmetics_IsEquipped = CosmeticsModule._IsEquipped
        CosmeticsModule._IsEquipped = function(self, cosmeticName)
            -- PRIORITIZE custom equipped (script override)
            local weaponName = self._equipment_state and self._equipment_state.SelectedWeapon or CurrentEquipmentState.Weapon
            if weaponName and cosmeticName and IsCustomEquipped(cosmeticName, weaponName) then
                return true
            end

            -- FALLBACK to game's original state (locker selections)
            return OriginalFunctions.Cosmetics_IsEquipped(self, cosmeticName)
        end
    end
end

local ClientEntityModule = nil

local function InstallFinisherHook()
    if OriginalFunctions.ClientEntity_PlayFinisher then return end
    ClientEntityModule = require(Player.PlayerScripts.Modules.ClientReplicatedClasses.ClientEntity)
    OriginalFunctions.ClientEntity_PlayFinisher = ClientEntityModule._PlayFinisher
    ClientEntityModule._PlayFinisher = function(self, finisherName, isFinal, eliminator, serialData)
        if eliminator and UnlockState.Finishers and CustomEquipped.Finisher then
            local isOurKill = false
            if typeof(eliminator) == "Instance" then
                if eliminator == Player then isOurKill = true
                elseif eliminator.Name == Player.Name then isOurKill = true end
            end
            if isOurKill then
                local finishersFolder = game:GetService("ReplicatedStorage").Modules.Finishers
                if finishersFolder:FindFirstChild(CustomEquipped.Finisher) then
                    finisherName = CustomEquipped.Finisher
                end
            end
        end
        return OriginalFunctions.ClientEntity_PlayFinisher(self, finisherName, isFinal, eliminator, serialData)
    end
end

local function InstallAllHooks()
    if HooksActive then return end
    InstallOwnershipHooks()
    InstallClientItemHook()
    InstallLookThroughHook()
    InstallGetWeaponDataHook()
    InstallFloatingModelHook()
    InstallStaticViewModelHooks()
    InstallEquipmentStateHooks()
    InstallCosmeticsModuleHook()
    InstallFinisherHook()
    HooksActive = true
end

local function RemoveHooks()
    if not HooksActive then return end
    for name, func in pairs(OriginalFunctions) do
        if name:sub(1, 3) == "CL_" then
            CosmeticLibrary[name:sub(4)] = func
        elseif name == "ClientItem_CreateViewModel" then
            ClientItemModule._CreateViewModel = func
        elseif name == "Utility_LookThrough" then
            Utility.LookThrough = func
        elseif name == "GetWeaponData" then
            PlayerDataUtility.GetWeaponData = func
        elseif name == "FloatingModel_GetViewModelName" then
            FloatingModelModule._GetViewModelName = func
        elseif name == "StaticViewModel_SetWrap" then
            StaticViewModelModule.SetWrap = func
        elseif name == "StaticViewModel_SetCharm" then
            StaticViewModelModule.SetCharm = func
        elseif name == "EquipmentState_SelectCosmetic" then
            EquipmentStateModule.SelectCosmetic = func
        elseif name == "EquipmentState_SelectWeapon" then
            EquipmentStateModule.SelectWeapon = func
        elseif name == "EquipmentState_StartCustomizing" then
            EquipmentStateModule.StartCustomizing = func
        elseif name == "Cosmetics_IsEquipped" then
            CosmeticsModule._IsEquipped = func
        elseif name == "ClientEntity_PlayFinisher" then
            ClientEntityModule._PlayFinisher = func
        end
    end
    OriginalFunctions = {}
    HooksActive = false
end

local function ApplySkin(skinName, weaponName)
    if not skinName then return false end
    local cosmeticData = CosmeticLibrary.Cosmetics[skinName]
    if not cosmeticData then return false end
    local targetWeapon = weaponName
    if not targetWeapon or targetWeapon == "all weapons" then
        targetWeapon = cosmeticData.ItemName
    end
    if not targetWeapon then return false end
    if not SkinModelExists(skinName) then return false end -- [FIX] Cached
    CustomEquipped.Skins[targetWeapon] = skinName
    SaveConfig()
    return true, targetWeapon
end

local function ApplyWrap(wrapName, weaponName)
    if not wrapName then return false end
    if weaponName and weaponName ~= "all weapons" then
        CustomEquipped.Wraps[weaponName] = wrapName
    else
        CustomEquipped.Wraps["_ALL"] = wrapName
    end
    SaveConfig()
    return true
end

local function ApplyCharm(charmName, weaponName)
    if not charmName then return false end
    if weaponName and weaponName ~= "all weapons" then
        CustomEquipped.Charms[weaponName] = charmName
    else
        CustomEquipped.Charms["_ALL"] = charmName
    end
    SaveConfig()
    return true
end

local function ApplyFinisher(finisherName)
    if not finisherName then return false end
    CustomEquipped.Finisher = finisherName
    SaveConfig()
    return true
end

local function ClearAllCustomCosmetics()
    CustomEquipped = { Skins = {}, Wraps = {}, Charms = {}, Finisher = nil }
    SaveConfig()
end

-- [FIX] Define UpdateStatsLabel
local lastStatsCount = 0
local function UpdateStatsLabel()
    if not InfoStatsLabel then return end
    local sc, wc, cc = 0, 0, 0
    for _ in pairs(CustomEquipped.Skins) do sc = sc + 1 end
    for _ in pairs(CustomEquipped.Wraps) do wc = wc + 1 end
    for _ in pairs(CustomEquipped.Charms) do cc = cc + 1 end
    local f = CustomEquipped.Finisher and 1 or 0
    local count = sc + wc + cc + f
    if count ~= lastStatsCount then
        InfoStatsLabel:SetText(count .. " cosmetics equipped")
        lastStatsCount = count
    end
end

local function ApplyLoadedConfig()
    UpdateStatsLabel()
end

local function UpdateDropdowns()
    task.wait(0.1)
    if Options.SkinDropdown then
        if #LoadedCosmetics.skins > 0 then
            local weaponFilter = Options.WeaponDropdown and Options.WeaponDropdown.Value
            local skins = GetSkinsForWeapon(weaponFilter)
            if #skins > 0 then
                Options.SkinDropdown:SetValues(skins)
                Options.SkinDropdown:SetValue(skins[1])
            end
        end
    end
    if Options.WrapDropdown then
        if #LoadedCosmetics.wraps > 0 then
            Options.WrapDropdown:SetValues(LoadedCosmetics.wraps)
            Options.WrapDropdown:SetValue(LoadedCosmetics.wraps[1])
        end
    end
    if Options.CharmDropdown then
        if #LoadedCosmetics.charms > 0 then
            Options.CharmDropdown:SetValues(LoadedCosmetics.charms)
            Options.CharmDropdown:SetValue(LoadedCosmetics.charms[1])
        end
    end
    if Options.FinisherDropdown then
        if #LoadedCosmetics.finishers > 0 then
            Options.FinisherDropdown:SetValues(LoadedCosmetics.finishers)
            Options.FinisherDropdown:SetValue(LoadedCosmetics.finishers[1])
        end
    end
    if Options.WeaponDropdown then
        local weapons = GetWeaponList()
        table.insert(weapons, 1, "all weapons")
        Options.WeaponDropdown:SetValues(weapons)
        Options.WeaponDropdown:SetValue("all weapons")
    end
    UpdateStatsLabel()
end

-- ============================================
-- SPOOFER FUNCTIONS
-- ============================================

local function SpooferChangeChar()
    if not SpooferDecodedData then return end
    local plr = Players:FindFirstChild(SpooferDecodedData.name)
    if not plr or not plr.Character then return end
    local success, err = pcall(function()
        local appearance = Players:GetCharacterAppearanceAsync(SpooferDecodedData.id)
        for _, v in pairs(plr.Character:GetChildren()) do
            if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("BodyColors") then
                v:Destroy()
            end
        end
        for _, v in pairs(appearance:GetChildren()) do
            if v:IsA("Shirt") or v:IsA("Pants") or v:IsA("BodyColors") then
                v.Parent = plr.Character
            elseif v:IsA("Accessory") then
                plr.Character.Humanoid:AddAccessory(v)
            end
        end
        if appearance:FindFirstChild("face") then
            if plr.Character:WaitForChild("Head"):FindFirstChild("face") then
                plr.Character.Head.face:Destroy()
            end
            appearance.face.Parent = plr.Character.Head
        else
            if plr.Character:WaitForChild("Head"):FindFirstChild("face") then
                plr.Character.Head.face:Destroy()
            end
            local face = Instance.new("Decal")
            face.Face = "Front"
            face.Name = "face"
            face.Texture = "rbxasset://textures/face.png"
            face.Transparency = 0
            face.Parent = plr.Character.Head
        end
        local parent = plr.Character.Parent
        plr.Character.Parent = nil
        plr.Character.Parent = parent
    end)
    if not success then
        warn("[YEEZY V1] SpooferChangeChar error: " .. tostring(err))
    end
end

local function ApplySpooferStats()
    if not SpooferDecodedData then return end
    local spoofedPlr = Players:FindFirstChild(SpooferDecodedData.name)
    if not spoofedPlr then
        spoofedPlr = Players.LocalPlayer
    end
    if not spoofedPlr then return end
    pcall(function()
        spoofedPlr:SetAttribute("Level", tonumber(SpooferState.Level) or 1)
        spoofedPlr:SetAttribute("StatisticDuelsWinStreak", tonumber(SpooferState.Streak) or 0)
        local ls = spoofedPlr:FindFirstChild("leaderstats")
        if ls then
            if ls:FindFirstChild("Level") then
                ls.Level.Value = tonumber(SpooferState.Level) or 1
            end
            if ls:FindFirstChild("Win Streak") then
                ls["Win Streak"].Value = tonumber(SpooferState.Streak) or 0
            end
        end
        local eloVal = tonumber(SpooferState.ELO) or 0
        if eloVal > 0 then
            spoofedPlr:SetAttribute("DisplayELO", eloVal)
        end
    end)
end

local function InstallSpooferHooks()
    if SpooferHookInstalled then return end
    if not SpooferDecodedData then return end
    local spoofedPlayer = Players:FindFirstChild(SpooferDecodedData.name)
    if not spoofedPlayer then
        spoofedPlayer = Players.LocalPlayer
    end
    if not spoofedPlayer then return end
    SpooferOldHook = hookmetamethod(game, "__index", function(self, key)
        if self == spoofedPlayer then
            if key == "Name" then
                return SpooferDecodedData.name
            end
            if key == "DisplayName" then
                return SpooferDecodedData.displayName
            end
            if key == "UserId" then
                return SpooferDecodedData.id
            end
            if key == "CharacterAppearanceId" then
                return SpooferDecodedData.id
            end
            if key == "MembershipType" and SpooferState.Premium then
                return Enum.MembershipType.Premium
            end
            if key == "HasVerifiedBadge" and SpooferState.Verified then
                return true
            end
        end
        return SpooferOldHook(self, key)
    end)

    SpooferOldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if self == Players and SpooferDecodedData then
            local firstArg = select(1, ...)
            if method == "GetNameFromUserIdAsync" and firstArg == SpooferDecodedData.id then
                return SpooferDecodedData.name
            end
            if method == "GetDisplayNameAsync" and firstArg == SpooferDecodedData.id then
                return SpooferDecodedData.displayName
            end
            if method == "GetUserIdFromNameAsync" and firstArg == SpooferDecodedData.name then
                return SpooferDecodedData.id
            end
        end
        return SpooferOldNamecall(self, ...)
    end)

    SpooferHookInstalled = true
end

local function StartSpooferRenderLoop()
    if SpooferRenderConnection then return end
    if not SpooferDecodedData then return end
    local victimName = SpooferDecodedData.name
    local victimId = SpooferDecodedData.id
    local localPlayer = Players.LocalPlayer
    local platformImg = ""
    local lastPlatform = ""
    local lastKeys = ""
    SpooferRenderConnection = game:GetService("RunService").RenderStepped:Connect(function()
        local platform = SpooferState.Platform
        local keys = SpooferState.Keys
        if platform ~= lastPlatform then
            platformImg = PlatformImageTable[platform] or ""
            lastPlatform = platform
        end
        -- nametag platform icon
        local ctrl =
            Players:FindFirstChild(victimName)
            and Players[victimName].Character
            and Players[victimName].Character:FindFirstChild("HumanoidRootPart")
            and Players[victimName].Character.HumanoidRootPart:FindFirstChild("Nametag")
            and Players[victimName].Character.HumanoidRootPart.Nametag:FindFirstChild("Frame")
            and Players[victimName].Character.HumanoidRootPart.Nametag.Frame:FindFirstChild("Player")
            and Players[victimName].Character.HumanoidRootPart.Nametag.Frame.Player:FindFirstChild("Controls")
        if ctrl and platformImg ~= "" then
            ctrl.Image = platformImg
        end
        -- scoreboard container
        local container =
            localPlayer:FindFirstChild("PlayerGui")
            and localPlayer.PlayerGui:FindFirstChild("MainGui")
            and localPlayer.PlayerGui.MainGui:FindFirstChild("MainFrame")
            and localPlayer.PlayerGui.MainGui.MainFrame:FindFirstChild("DuelInterfaces")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces:FindFirstChild("DuelInterface")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces.DuelInterface:FindFirstChild("Scoreboard")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces.DuelInterface.Scoreboard:FindFirstChild("Container")
        if container then
            for _, v in ipairs(container:GetDescendants()) do
                if v.Name == "Username" and string.find(v.Text, "@" .. victimName) then
                    pcall(function() v.Parent.Container.TeammateSlot.Container.Controls.Image = platformImg end)
                end
            end
        end
        -- scores teams
        for _, v in ipairs(
            localPlayer:FindFirstChild("PlayerGui")
            and localPlayer.PlayerGui:FindFirstChild("MainGui")
            and localPlayer.PlayerGui.MainGui:FindFirstChild("MainFrame")
            and localPlayer.PlayerGui.MainGui.MainFrame:FindFirstChild("DuelInterfaces")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces:FindFirstChild("DuelInterface")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces.DuelInterface:FindFirstChild("Top")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces.DuelInterface.Top:FindFirstChild("Scores")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces.DuelInterface.Top.Scores:FindFirstChild("Teams")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces.DuelInterface.Top.Scores.Teams:GetDescendants()
            or {}
        ) do
            if v.Name == "Headshot" and string.find(v.Image, tostring(victimId)) then
                pcall(function() v.Parent:FindFirstChild("Controls").Image = platformImg end)
            end
        end
        -- final results
        for _, v in ipairs(
            localPlayer:FindFirstChild("PlayerGui")
            and localPlayer.PlayerGui:FindFirstChild("MainGui")
            and localPlayer.PlayerGui.MainGui:FindFirstChild("MainFrame")
            and localPlayer.PlayerGui.MainGui.MainFrame:FindFirstChild("DuelInterfaces")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces:FindFirstChild("DuelInterface")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces.DuelInterface:FindFirstChild("FinalResults")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces.DuelInterface.FinalResults:FindFirstChild("Winners")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces.DuelInterface.FinalResults.Winners:FindFirstChild("Players")
            and localPlayer.PlayerGui.MainGui.MainFrame.DuelInterfaces.DuelInterface.FinalResults.Winners.Players:GetDescendants()
            or {}
        ) do
            if v.Name == "Username" and string.find(v.Text, "@" .. victimName) then
                local controls = v.Parent and v.Parent.Parent and v.Parent.Parent:FindFirstChild("Controls")
                if controls then
                    controls.Image = platformImg
                end
            end
        end
        -- keys currency
        if keys ~= "" and keys ~= lastKeys then
            for _, v in ipairs(
                localPlayer:FindFirstChild("PlayerGui")
                and localPlayer.PlayerGui:FindFirstChild("MainGui")
                and localPlayer.PlayerGui.MainGui:FindFirstChild("MainFrame")
                and localPlayer.PlayerGui.MainGui.MainFrame:FindFirstChild("Lobby")
                and localPlayer.PlayerGui.MainGui.MainFrame.Lobby:FindFirstChild("Currency")
                and localPlayer.PlayerGui.MainGui.MainFrame.Lobby.Currency:FindFirstChild("Container")
                and localPlayer.PlayerGui.MainGui.MainFrame.Lobby.Currency.Container:GetDescendants()
                or {}
            ) do
                if v.Name == "Icon" and v.Image == "rbxassetid://17860673529" then
                    pcall(function() v.Parent.Parent.Title.Text = keys end)
                end
            end
            lastKeys = keys
        end
    end)
end

local function StopSpoofer()
    if SpooferRenderConnection then
        SpooferRenderConnection:Disconnect()
        SpooferRenderConnection = nil
    end
    if SpooferCharConnection then
        SpooferCharConnection:Disconnect()
        SpooferCharConnection = nil
    end
    if SpooferOldHook then
        hookmetamethod(game, "__index", SpooferOldHook)
        SpooferOldHook = nil
    end
    if SpooferOldNamecall then
        hookmetamethod(game, "__namecall", SpooferOldNamecall)
        SpooferOldNamecall = nil
    end
    SpooferHookInstalled = false
    SpooferState.Active = false
    SpooferDecodedData = nil
end

local function RestoreSpooferUI()
    pcall(function()
        if Options.SpooferVictimInput then Options.SpooferVictimInput:SetValue(SpooferState.VictimId) end
        if Options.SpooferHelperInput then Options.SpooferHelperInput:SetValue(SpooferState.Helper) end
        if Options.SpooferLevelInput then Options.SpooferLevelInput:SetValue(SpooferState.Level) end
        if Options.SpooferStreakInput then Options.SpooferStreakInput:SetValue(SpooferState.Streak) end
        if Options.SpooferKeysInput then Options.SpooferKeysInput:SetValue(SpooferState.Keys) end
        if Options.SpooferELOInput then Options.SpooferELOInput:SetValue(SpooferState.ELO) end
        if Options.SpooferPlatformDropdown then Options.SpooferPlatformDropdown:SetValue(SpooferState.Platform) end
        if Toggles.SpooferPremiumToggle then Toggles.SpooferPremiumToggle:SetValue(SpooferState.Premium) end
        if Toggles.SpooferVerifiedToggle then Toggles.SpooferVerifiedToggle:SetValue(SpooferState.Verified) end
    end)
end

local function ApplyFullSpoof()
    StopSpoofer()
    local helperName = SpooferState.Helper
    local friend = helperName ~= "" and Players:FindFirstChild(helperName) or Players.LocalPlayer
    if not friend then
        Library:Notify({Title = "error", Description = "helper not found", Time = 2})
        return
    end
    
    local useLocalPlayer = SpooferState.VictimId == ""
    local userId = useLocalPlayer and Players.LocalPlayer.UserId or tonumber(SpooferState.VictimId)
    
    local success, err = pcall(function()
        if not userId or userId <= 0 then
            error("invalid user id")
        end
        local UserData = game:HttpGet("https://users.roblox.com/v1/users/" .. tostring(userId), true)
        if not UserData or UserData == "" then
            error("empty response")
        end
        local decoded = HttpService:JSONDecode(UserData)
        if type(decoded) ~= "table" then
            error("invalid user data")
        end
        SpooferDecodedData = decoded
    end)
    if not success or not SpooferDecodedData then
        Library:Notify({Title = "error", Description = "failed to fetch user data: " .. tostring(err), Time = 3})
        return
    end
    
    if not useLocalPlayer then
        pcall(function()
            friend.Name = SpooferDecodedData.name
            friend.UserId = SpooferDecodedData.id
            friend.CharacterAppearanceId = SpooferDecodedData.id
            friend.DisplayName = SpooferDecodedData.displayName
        end)
        if friend.Character then
            pcall(function()
                friend.Character:WaitForChild("Humanoid")
                friend.Character.Name = SpooferDecodedData.name
                friend.Character.Humanoid.DisplayName = SpooferDecodedData.displayName
            end)
        end
    end
    
    ApplySpooferStats()
    if not useLocalPlayer then
        SpooferChangeChar()
    end
    InstallSpooferHooks()
    StartSpooferRenderLoop()
    
    local targetPlayer = useLocalPlayer and Players.LocalPlayer or Players:FindFirstChild(SpooferDecodedData.name)
    if targetPlayer then
        SpooferCharConnection = targetPlayer.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            if not useLocalPlayer then
                SpooferChangeChar()
            end
            ApplySpooferStats()
        end)
    end
    
    SpooferState.Active = true
    SaveConfig()
    Library:Notify({Title = "YEEZY V1 Spoofer", Description = useLocalPlayer and "spoofer enabled" or "spoofing as " .. SpooferDecodedData.displayName, Time = 3})
end

local function InstallEmoteSwapHook()
    if OldRequireHook then return end
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local EmotesFolder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Emotes")
    
    local originalEmote = EmotesFolder:FindFirstChild(EmoteSwapState.OriginalEmote)
    local replacementEmote = EmotesFolder:FindFirstChild(EmoteSwapState.ReplacementEmote)
    
    if not originalEmote or not replacementEmote then
        Library:Notify({Title = "Error", Description = "Emotes not found", Time = 2})
        return
    end
    
    OldRequireHook = hookfunction(require, function(module)
        if module == originalEmote then
            return require(replacementEmote)
        end
        return OldRequireHook(module)
    end)
end

local function RemoveEmoteSwapHook()
    if OldRequireHook then
        hookfunction(require, OldRequireHook)
        OldRequireHook = nil
    end
end

-- ============================================
-- CREATE UI
-- ============================================

local Window = Library:CreateWindow({
    Title = "YEEZY V1",
    Footer = "YEEZY V1",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = false,
})

local Tabs = {
    Main = Window:AddTab("Skin Changer", "shirt"),
    World = Window:AddTab("World", "globe"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Aimbot = Window:AddTab("Aimbot", "target"),
    Triggerbot = Window:AddTab("Triggerbot", "target"),
}

-- MAIN TAB
local InfoGroup = Tabs.Main:AddLeftGroupbox("Info")
InfoGroup:AddLabel("Change Skins With Our UI")
InfoGroup:AddDivider()
InfoStatsLabel = InfoGroup:AddLabel("Equipped: None")
InfoGroup:AddDivider()
InfoGroup:AddLabel("Trust In YEEZY V1")

-- SKINS TAB
local SkinSelectGroup = Tabs.Main:AddLeftGroupbox("Select Skin")

SkinSelectGroup:AddDropdown("WeaponDropdown", {
    Values = {"Loading..."}, Default = 1, Text = "Weapon",
    Callback = function(Value)
        local skins = GetSkinsForWeapon(Value)
        if #skins > 0 then
            Options.SkinDropdown:SetValues(skins)
            Options.SkinDropdown:SetValue(skins[1])
        end
    end
})

SkinSelectGroup:AddDropdown("SkinDropdown", {
    Values = {"Loading..."}, Default = 1, Text = "Skin", Searchable = true
})

SkinSelectGroup:AddButton({
    Text = "Apply Skin",
    Func = function()
        local skinName = Options.SkinDropdown.Value
        local weaponName = Options.WeaponDropdown.Value
        local success, targetWeapon = ApplySkin(skinName, weaponName ~= "all weapons" and weaponName or nil)
        UpdateStatsLabel()
        if success then
            Library:Notify({Title = "Applied", Description = skinName, Time = 3})
        end
    end
})

local AppliedGroup = Tabs.Main:AddRightGroupbox("Applied")

AppliedGroup:AddButton({
    Text = "View Applied",
    Func = function()
        local lines = {}
        for weapon, skin in pairs(CustomEquipped.Skins) do
            table.insert(lines, weapon .. ": " .. skin)
        end
        Library:Notify({
            Title = "Skins (" .. #lines .. ")",
            Description = #lines > 0 and table.concat(lines, "\n") or "None",
            Time = 5
        })
    end
})

AppliedGroup:AddButton({
    Text = "Clear Skins",
    Func = function()
        CustomEquipped.Skins = {}
        UpdateStatsLabel()
        SaveConfig()
        Library:Notify({Title = "Cleared", Description = "Skins Removed", Time = 2})
    end
})

-- COSMETICS TAB
local WrapsGroup = Tabs.Main:AddLeftGroupbox("Wraps")

WrapsGroup:AddDropdown("WrapDropdown", {
    Values = {"Enable First"}, Default = 1, Text = "Wrap", Searchable = true
})

WrapsGroup:AddButton({
    Text = "Apply Wrap",
    Func = function()
        local wrapName = Options.WrapDropdown.Value
        if wrapName == "enable wraps first" or wrapName == "enable first" or wrapName == "Enable First" then
            Library:Notify({Title = "Error", Description = "Enable Wraps First", Time = 2})
            return
        end
        ApplyWrap(wrapName, nil)
        UpdateStatsLabel()
        Library:Notify({Title = "Applied", Description = wrapName, Time = 2})
    end
})

local CharmsGroup = Tabs.Main:AddLeftGroupbox("Charms")

CharmsGroup:AddDropdown("CharmDropdown", {
    Values = {"Enable First"}, Default = 1, Text = "Charm", Searchable = true
})

CharmsGroup:AddButton({
    Text = "Apply Charm",
    Func = function()
        local charmName = Options.CharmDropdown.Value
        if charmName == "enable charms first" or charmName == "enable first" or charmName == "Enable First" then
            Library:Notify({Title = "Error", Description = "Enable Charms First", Time = 2})
            return
        end
        ApplyCharm(charmName, nil)
        UpdateStatsLabel()
        Library:Notify({Title = "Applied", Description = charmName, Time = 2})
    end
})

local FinishersGroup = Tabs.Main:AddRightGroupbox("Finishers")
FinishersGroup:AddDivider()

FinishersGroup:AddDropdown("FinisherDropdown", {
    Values = {"Enable First"}, Default = 1, Text = "Finisher", Searchable = true
})

FinishersGroup:AddButton({
    Text = "Apply Finisher",
    Func = function()
        local finisherName = Options.FinisherDropdown.Value
        if finisherName == "enable finishers first" or finisherName == "enable first" or finisherName == "Enable First" then
            Library:Notify({Title = "Error", Description = "Enable Finishers First", Time = 2})
            return
        end
        ApplyFinisher(finisherName)
        UpdateStatsLabel()
        Library:Notify({Title = "Applied", Description = finisherName, Time = 2})
    end
})

local ClearGroup = Tabs.Main:AddRightGroupbox("Clear")

ClearGroup:AddButton({
    Text = "Clear All",
    Func = function()
        ClearAllCustomCosmetics()
        UpdateStatsLabel()
        Library:Notify({Title = "Cleared", Description = "All Reset", Time = 2})
    end,
    DoubleClick = true
})

-- SPOOFER TAB
local SpooferIdentityGroup = Tabs.Main:AddLeftGroupbox("Identity")

SpooferIdentityGroup:AddInput("SpooferVictimInput", {
    Default = SpooferState.VictimId,
    Numeric = true,
    Finished = false,
    Text = "Victim User ID",
    Placeholder = "Enter Roblox User ID",
    Callback = function(Value)
        SpooferState.VictimId = Value
        SaveConfig()
    end
})

SpooferIdentityGroup:AddInput("SpooferHelperInput", {
    Default = SpooferState.Helper,
    Numeric = false,
    Finished = false,
    Text = "Helper (Optional)",
    Placeholder = "Leave Empty For Self",
    Callback = function(Value)
        SpooferState.Helper = Value
        SaveConfig()
    end
})

SpooferIdentityGroup:AddButton({
    Text = "Apply Spoof",
    Func = function()
        ApplyFullSpoof()
    end
})

SpooferIdentityGroup:AddButton({
    Text = "Stop Spoof",
    Func = function()
        StopSpoofer()
        Library:Notify({Title = "Spoofer", Description = "Spoof Stopped", Time = 2})
    end,
    DoubleClick = true
})

local SpooferStatsGroup = Tabs.Main:AddLeftGroupbox("Stats")

SpooferStatsGroup:AddInput("SpooferLevelInput", {
    Default = SpooferState.Level,
    Numeric = true,
    Finished = false,
    Text = "Level",
    Placeholder = "1",
    Callback = function(Value)
        SpooferState.Level = Value
        SaveConfig()
    end
})

SpooferStatsGroup:AddInput("SpooferStreakInput", {
    Default = SpooferState.Streak,
    Numeric = true,
    Finished = false,
    Text = "Win Streak",
    Placeholder = "0",
    Callback = function(Value)
        SpooferState.Streak = Value
        SaveConfig()
    end
})

SpooferStatsGroup:AddInput("SpooferKeysInput", {
    Default = SpooferState.Keys,
    Numeric = false,
    Finished = false,
    Text = "Keys Display",
    Placeholder = "Leave Empty To Skip",
    Callback = function(Value)
        SpooferState.Keys = Value
        SaveConfig()
    end
})

SpooferStatsGroup:AddButton({
    Text = "Update Stats",
    Func = function()
        if SpooferDecodedData then
            ApplySpooferStats()
            Library:Notify({Title = "Spoofer", Description = "Stats Updated", Time = 2})
        else
            Library:Notify({Title = "Error", Description = "Apply Spoof First", Time = 2})
        end
    end
})

local SpooferRankGroup = Tabs.Main:AddRightGroupbox("Rank Changer")
SpooferRankGroup:AddLabel("Select A Rank Preset")
SpooferRankGroup:AddDivider()

SpooferRankGroup:AddDropdown("RankPresetDropdown", {
    Values = RankNames, Default = 1, Text = "Rank",
    Callback = function(Value)
        for _, preset in ipairs(RankPresets) do
            if preset[1] == Value then
                SpooferState.ELO = tostring(preset[2])
                if Options.SpooferELOInput then
                    Options.SpooferELOInput:SetValue(tostring(preset[2]))
                end
                break
            end
        end
    end
})

SpooferRankGroup:AddInput("SpooferELOInput", {
    Default = SpooferState.ELO,
    Numeric = true,
    Finished = false,
    Text = "Custom ELO",
    Placeholder = "0",
    Callback = function(Value)
        SpooferState.ELO = Value
        SaveConfig()
    end
})

SpooferRankGroup:AddButton({
    Text = "Apply Rank",
    Func = function()
        if SpooferDecodedData then
            local eloVal = tonumber(SpooferState.ELO) or 0
            local spoofedPlr = Players:FindFirstChild(SpooferDecodedData.name)
            if spoofedPlr and eloVal > 0 then
                spoofedPlr:SetAttribute("DisplayELO", eloVal)
                Library:Notify({Title = "Spoofer", Description = "ELO Set To " .. eloVal, Time = 2})
            elseif eloVal <= 0 then
                Library:Notify({Title = "Error", Description = "ELO Must Be > 0", Time = 2})
            end
        else
            Library:Notify({Title = "Error", Description = "Apply Spoof First", Time = 2})
        end
    end
})

local SpooferOptionsGroup = Tabs.Main:AddRightGroupbox("Options")

SpooferOptionsGroup:AddDropdown("SpooferPlatformDropdown", {
    Values = PlatformNames, Default = 1, Text = "Platform",
    Callback = function(Value)
        SpooferState.Platform = Value
    end
})

SpooferOptionsGroup:AddCheckbox("SpooferPremiumToggle", {
    Text = "Premium Badge", Default = SpooferState.Premium,
    Callback = function(Value)
        SpooferState.Premium = Value
    end
})

SpooferOptionsGroup:AddCheckbox("SpooferVerifiedToggle", {
    Text = "Verified Badge", Default = SpooferState.Verified,
    Callback = function(Value)
        SpooferState.Verified = Value
    end
})

-- EMOTES TAB
local EmoteSwapGroup = Tabs.Main:AddLeftGroupbox("Emote Swap")

EmoteSwapGroup:AddLabel("Local / Visual Only")
EmoteSwapGroup:AddDivider()

EmoteSwapGroup:AddCheckbox("EmoteSwapToggle", {
    Text = "Enable Emote Swap", Default = false,
    Callback = function(Value)
        EmoteSwapState.Enabled = Value
        if Value then
            InstallEmoteSwapHook()
            Library:Notify({Title = "Emote Swap", Description = "Enabled", Time = 2})
        else
            RemoveEmoteSwapHook()
            Library:Notify({Title = "Emote Swap", Description = "Disabled", Time = 2})
        end
    end
})

local EmoteSelectGroup = Tabs.Main:AddRightGroupbox("Select Emotes")

EmoteSelectGroup:AddLabel("Original Emote")
EmoteSelectGroup:AddDivider()

EmoteSelectGroup:AddInput("OriginalEmoteInput", {
    Default = EmoteSwapState.OriginalEmote,
    Numeric = false,
    Finished = false,
    Text = "Original Emote",
    Placeholder = "e.g. Shoulder Brush",
    Callback = function(Value)
        EmoteSwapState.OriginalEmote = Value
        if EmoteSwapState.Enabled then
            RemoveEmoteSwapHook()
            InstallEmoteSwapHook()
        end
    end
})

EmoteSelectGroup:AddLabel("Replacement Emote")
EmoteSelectGroup:AddDivider()

EmoteSelectGroup:AddInput("ReplacementEmoteInput", {
    Default = EmoteSwapState.ReplacementEmote,
    Numeric = false,
    Finished = false,
    Text = "Replacement Emote",
    Placeholder = "e.g. Take The L",
    Callback = function(Value)
        EmoteSwapState.ReplacementEmote = Value
        if EmoteSwapState.Enabled then
            RemoveEmoteSwapHook()
            InstallEmoteSwapHook()
        end
    end
})

EmoteSelectGroup:AddButton({
    Text = "Apply Swap",
    Func = function()
        if EmoteSwapState.Enabled then
            RemoveEmoteSwapHook()
            InstallEmoteSwapHook()
            Library:Notify({Title = "Emote Swap", Description = "Applied: " .. EmoteSwapState.OriginalEmote .. " -> " .. EmoteSwapState.ReplacementEmote, Time = 3})
        else
            Library:Notify({Title = "Error", Description = "Enable Emote Swap First", Time = 2})
        end
    end
})

-- WORLD TAB
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local WorldDefaults = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    Hue = 0,
    ResolutionScale = 1.0,
    ResolutionEnabled = false,
    SkyColor = Color3.fromRGB(199, 170, 160)
}

local WorldState = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    Hue = 0,
    ResolutionScale = 1.0,
    ResolutionEnabled = false,
    MasterEnabled = false
}
local ResolutionConnection = nil

-- Ensure ColorCorrection exists for Hue
if not Lighting:FindFirstChild("ColorCorrection") then
    local cc = Instance.new("ColorCorrectionEffect", Lighting)
    cc.Name = "ColorCorrection"
    cc.TintColor = Color3.new(1, 1, 1)
end

local WorldMasterGroup = Tabs.World:AddLeftGroupbox("Master Control")

WorldMasterGroup:AddToggle("WorldMasterEnabled", {
    Text = "Enable World Changes",
    Default = false,
    Callback = function(Value)
        WorldState.MasterEnabled = Value
        if not Value then
            Lighting.Brightness = WorldDefaults.Brightness
            Lighting.ClockTime = WorldDefaults.ClockTime
            local cc = Lighting:FindFirstChild("ColorCorrection")
            if cc then cc.TintColor = Color3.new(1, 1, 1) end
            local atm = Lighting:FindFirstChild("Atmosphere")
            if atm then atm.Color = WorldDefaults.SkyColor end
            if ResolutionConnection then
                ResolutionConnection:Disconnect()
                ResolutionConnection = nil
            end
            if Options.Brightness then Options.Brightness:SetValue(WorldDefaults.Brightness) end
            if Options.ClockTime then Options.ClockTime:SetValue(WorldDefaults.ClockTime) end
            if Options.Hue then Options.Hue:SetValue(0) end
            if Options.SkyColorR then Options.SkyColorR:SetValue(199) end
            if Options.SkyColorG then Options.SkyColorG:SetValue(170) end
            if Options.SkyColorB then Options.SkyColorB:SetValue(160) end
            if Options.ResolutionEnabled then Options.ResolutionEnabled:SetValue(false) end
            if Options.ResolutionScale then Options.ResolutionScale:SetValue(1.0) end
        end
    end
})

local LightingGroup = Tabs.World:AddLeftGroupbox("Lighting")

LightingGroup:AddSlider("Brightness", {
    Text = "Brightness",
    Min = 0,
    Max = 5,
    Default = WorldDefaults.Brightness,
    Rounding = 1,
    Callback = function(Value)
        if not WorldState.MasterEnabled then return end
        WorldState.Brightness = Value
        Lighting.Brightness = Value
    end
})

LightingGroup:AddSlider("ClockTime", {
    Text = "Time of Day",
    Min = 0,
    Max = 24,
    Default = WorldDefaults.ClockTime,
    Rounding = 1,
    Callback = function(Value)
        if not WorldState.MasterEnabled then return end
        WorldState.ClockTime = Value
        Lighting.ClockTime = Value
    end
})

LightingGroup:AddSlider("Hue", {
    Text = "Hue",
    Min = 0,
    Max = 1,
    Default = 0,
    Rounding = 2,
    Callback = function(Value)
        if not WorldState.MasterEnabled then return end
        WorldState.Hue = Value
        local cc = Lighting:FindFirstChild("ColorCorrection")
        if cc then
            cc.TintColor = Color3.fromHSV(Value, 1, 1)
        end
    end
})

LightingGroup:AddButton({
    Text = "Reset Lighting",
    Func = function()
        Options.Brightness:SetValue(WorldDefaults.Brightness)
        Options.ClockTime:SetValue(WorldDefaults.ClockTime)
        Options.Hue:SetValue(0)
        Lighting.Brightness = WorldDefaults.Brightness
        Lighting.ClockTime = WorldDefaults.ClockTime
        local cc = Lighting:FindFirstChild("ColorCorrection")
        if cc then cc.TintColor = Color3.new(1, 1, 1) end
    end
})

local AtmosphereGroup = Tabs.World:AddRightGroupbox("Sky Color")

local function GetOrCreateAtmosphere()
    local atm = Lighting:FindFirstChild("Atmosphere")
    if not atm then
        atm = Instance.new("Atmosphere", Lighting)
        atm.Name = "Atmosphere"
    end
    return atm
end

AtmosphereGroup:AddSlider("SkyColorR", {
    Text = "Red",
    Min = 0,
    Max = 255,
    Default = 199,
    Rounding = 0,
    Callback = function(Value)
        if not WorldState.MasterEnabled then return end
        local atm = GetOrCreateAtmosphere()
        local g = atm.Color.G * 255
        local b = atm.Color.B * 255
        atm.Color = Color3.fromRGB(Value, g, b)
    end
})

AtmosphereGroup:AddSlider("SkyColorG", {
    Text = "Green",
    Min = 0,
    Max = 255,
    Default = 170,
    Rounding = 0,
    Callback = function(Value)
        if not WorldState.MasterEnabled then return end
        local atm = GetOrCreateAtmosphere()
        local r = atm.Color.R * 255
        local b = atm.Color.B * 255
        atm.Color = Color3.fromRGB(r, Value, b)
    end
})

AtmosphereGroup:AddSlider("SkyColorG", {
    Text = "Green",
    Min = 0,
    Max = 255,
    Default = 170,
    Rounding = 0,
    Callback = function(Value)
        if not WorldState.MasterEnabled then return end
        local atm = GetOrCreateAtmosphere()
        local r = atm.Color.R * 255
        local b = atm.Color.B * 255
        atm.Color = Color3.fromRGB(r, Value, b)
    end
})

AtmosphereGroup:AddSlider("SkyColorB", {
    Text = "Blue",
    Min = 0,
    Max = 255,
    Default = 160,
    Rounding = 0,
    Callback = function(Value)
        if not WorldState.MasterEnabled then return end
        local atm = GetOrCreateAtmosphere()
        local r = atm.Color.R * 255
        local g = atm.Color.G * 255
        atm.Color = Color3.fromRGB(r, g, Value)
    end
})

AtmosphereGroup:AddButton({
    Text = "Apply Sky Color",
    Func = function()
        if not WorldState.MasterEnabled then
            Library:Notify({Title = "Error", Description = "Enable World Changes First", Time = 2})
            return
        end
        local atm = GetOrCreateAtmosphere()
        local r = Options.SkyColorR and Options.SkyColorR.Value or 199
        local g = Options.SkyColorG and Options.SkyColorG.Value or 170
        local b = Options.SkyColorB and Options.SkyColorB.Value or 160
        atm.Color = Color3.fromRGB(r, g, b)
        Library:Notify({Title = "Sky Color", Description = "Applied R" .. r .. " G" .. g .. " B" .. b, Time = 3})
    end
})

AtmosphereGroup:AddButton({
    Text = "Reset Sky Color",
    Func = function()
        Options.SkyColorR:SetValue(199)
        Options.SkyColorG:SetValue(170)
        Options.SkyColorB:SetValue(160)
        local atm = Lighting:FindFirstChild("Atmosphere")
        if atm then atm.Color = Color3.fromRGB(199, 170, 160) end
    end
})

local ResolutionGroup = Tabs.World:AddLeftGroupbox("Resolution")

ResolutionGroup:AddToggle("ResolutionEnabled", {
    Text = "Enable Resolution Changer",
    Default = false,
    Callback = function(Value)
        if not WorldState.MasterEnabled then return end
        WorldState.ResolutionEnabled = Value
        if Value then
            local Camera = workspace.CurrentCamera
            ResolutionConnection = RunService.RenderStepped:Connect(function()
                local scale = WorldState.ResolutionScale
                Camera.CFrame = Camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, scale, 0, 0, 0, 1)
            end)
        else
            if ResolutionConnection then
                ResolutionConnection:Disconnect()
                ResolutionConnection = nil
            end
        end
    end
})

ResolutionGroup:AddSlider("ResolutionScale", {
    Text = "Resolution Scale",
    Min = 0.5,
    Max = 1.0,
    Default = 1.0,
    Rounding = 2,
    Callback = function(Value)
        if not WorldState.MasterEnabled then return end
        WorldState.ResolutionScale = Value
    end
})

ResolutionGroup:AddButton({
    Text = "Reset Resolution",
    Func = function()
        Options.ResolutionEnabled:SetValue(false)
        Options.ResolutionScale:SetValue(1.0)
        WorldState.ResolutionEnabled = false
        WorldState.ResolutionScale = 1.0
        if ResolutionConnection then
            ResolutionConnection:Disconnect()
            ResolutionConnection = nil
            end
    end
})

-- VISUALS TAB
local ESPState = {
    Enabled = false,
    Boxes = true,
    BoxFilled = false,
    Names = true,
    ShowDistance = true,
    Tracers = false,
    TracerPosition = "Bottom",
    HealthBar = true,
    HealthBarSide = "Left",
    TeamCheck = false,
    MaxDistance = 1000,
    BoxColor = Color3.fromRGB(255, 255, 255),
    EnemyColor = Color3.fromRGB(255, 0, 0),
    NameColor = Color3.fromRGB(255, 255, 255),
}
local ESPConnections = {}
local ESPObjects = {}

local function ClearESP()
    for _, data in pairs(ESPObjects) do
        for _, obj in pairs(data) do
            if obj and obj.Destroy then obj:Destroy()
            elseif obj and obj.Remove then obj:Remove() end
        end
    end
    ESPObjects = {}
end

local function CreateESPObjects(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end

    local boxOutline = Drawing.new("Square")
    boxOutline.Visible = false
    boxOutline.Thickness = 3
    boxOutline.Color = Color3.fromRGB(0, 0, 0)
    boxOutline.Filled = false
    boxOutline.Transparency = 0.5

    local box = Drawing.new("Square")
    box.Visible = false
    box.Thickness = 1
    box.Color = ESPState.BoxColor
    box.Filled = false
    box.Transparency = 1

    local nameText = Drawing.new("Text")
    nameText.Visible = false
    nameText.Center = true
    nameText.Outline = true
    nameText.Size = 13
    nameText.Color = ESPState.NameColor
    nameText.Transparency = 1

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = 1
    tracer.Color = ESPState.BoxColor
    tracer.Transparency = 1

    local healthBarOutline = Drawing.new("Square")
    healthBarOutline.Visible = false
    healthBarOutline.Thickness = 1
    healthBarOutline.Filled = true
    healthBarOutline.Color = Color3.fromRGB(0, 0, 0)
    healthBarOutline.Transparency = 0.4

    local healthBar = Drawing.new("Square")
    healthBar.Visible = false
    healthBar.Thickness = 1
    healthBar.Filled = true
    healthBar.Color = Color3.fromRGB(0, 255, 0)
    healthBar.Transparency = 1

    ESPObjects[player] = {
        BoxOutline = boxOutline,
        Box = box,
        Name = nameText,
        Tracer = tracer,
        HealthBarOutline = healthBarOutline,
        HealthBar = healthBar,
    }
end

local function UpdateESP()
    if not ESPState.Enabled then
        ClearESP()
        return
    end

    local camera = workspace.CurrentCamera
    for _, player in ipairs(Players:GetPlayers()) do
        if player and player ~= LocalPlayer and LocalPlayer then
            local shouldShow = true
            if ESPState.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                local objs = ESPObjects[player]
                if objs then for _, obj in pairs(objs) do obj.Visible = false end end
                shouldShow = false
            end

            if shouldShow then
                local character = player.Character
                if character then
                    local humanoid = character:FindFirstChild("Humanoid")
                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if humanoid and hrp then
                        if not ESPObjects[player] then
                            CreateESPObjects(player)
                        end
                        local objects = ESPObjects[player]
                        if objects then
                            local pos, onScreen = camera:WorldToViewportPoint(hrp.Position)
                            if onScreen then
                                local distance = (camera.CFrame.Position - hrp.Position).Magnitude
                                if distance <= ESPState.MaxDistance then
                                    local successBBox, bboxCFrame, bboxSize = pcall(function()
                                        return character:GetBoundingBox()
                                    end)
                                    local topPos, bottomPos, leftPos, rightPos
                                    if successBBox and bboxSize then
                                        topPos = camera:WorldToViewportPoint(bboxCFrame.Position + Vector3.new(0, bboxSize.Y / 2, 0))
                                        bottomPos = camera:WorldToViewportPoint(bboxCFrame.Position - Vector3.new(0, bboxSize.Y / 2, 0))
                                        leftPos = camera:WorldToViewportPoint(bboxCFrame.Position - bboxCFrame.RightVector * (bboxSize.X / 2))
                                        rightPos = camera:WorldToViewportPoint(bboxCFrame.Position + bboxCFrame.RightVector * (bboxSize.X / 2))
                                    else
                                        local head = character:FindFirstChild("Head")
                                        topPos = head and camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or pos
                                        bottomPos = camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                                        leftPos = camera:WorldToViewportPoint(hrp.Position - Vector3.new(1, 0, 0))
                                        rightPos = camera:WorldToViewportPoint(hrp.Position + Vector3.new(1, 0, 0))
                                    end

                                    local boxHeight = math.max(20, math.abs(topPos.Y - bottomPos.Y))
                                    local boxWidth = math.max(20, math.abs(rightPos.X - leftPos.X))
                                    if boxWidth < boxHeight * 0.3 then
                                        boxWidth = boxHeight * 0.3
                                    end

                                    local isEnemy = true
                                    if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                                        isEnemy = false
                                    end

                                    local boxColor = isEnemy and ESPState.EnemyColor or ESPState.BoxColor

                                    -- Update Box Outline
                                    if ESPState.Boxes and objects.BoxOutline then
                                        objects.BoxOutline.Size = Vector2.new(boxWidth + 4, boxHeight + 4)
                                        objects.BoxOutline.Position = Vector2.new(pos.X - (boxWidth + 4) / 2, topPos.Y - 2)
                                        objects.BoxOutline.Visible = true
                                    elseif objects.BoxOutline then
                                        objects.BoxOutline.Visible = false
                                    end

                                    -- Update Box
                                    if ESPState.Boxes and objects.Box then
                                        objects.Box.Size = Vector2.new(boxWidth, boxHeight)
                                        objects.Box.Position = Vector2.new(pos.X - boxWidth / 2, topPos.Y)
                                        objects.Box.Visible = true
                                        objects.Box.Filled = ESPState.BoxFilled
                                        objects.Box.Color = boxColor
                                    elseif objects.Box then
                                        objects.Box.Visible = false
                                    end

                                    -- Update Name
                                    if ESPState.Names and objects.Name then
                                        local displayName = player.Name
                                        if ESPState.ShowDistance then
                                            displayName = displayName .. " [" .. math.floor(distance) .. "m]"
                                        end
                                        objects.Name.Text = displayName
                                        objects.Name.Position = Vector2.new(pos.X, topPos.Y - 18)
                                        objects.Name.Visible = true
                                        objects.Name.Color = ESPState.NameColor
                                    elseif objects.Name then
                                        objects.Name.Visible = false
                                    end

                                    -- Update Tracer
                                    if ESPState.Tracers and objects.Tracer then
                                        local tracerOriginY = camera.ViewportSize.Y
                                        if ESPState.TracerPosition == "Top" then
                                            tracerOriginY = 0
                                        elseif ESPState.TracerPosition == "Center" then
                                            tracerOriginY = camera.ViewportSize.Y / 2
                                        end
                                        objects.Tracer.From = Vector2.new(camera.ViewportSize.X / 2, tracerOriginY)
                                        objects.Tracer.To = Vector2.new(pos.X, bottomPos.Y)
                                        objects.Tracer.Visible = true
                                        objects.Tracer.Color = boxColor
                                    elseif objects.Tracer then
                                        objects.Tracer.Visible = false
                                    end

                                    -- Update Health Bar
                                    if ESPState.HealthBar and objects.HealthBar and objects.HealthBarOutline then
                                        local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                                        local barHeight = math.max(4, boxHeight * healthPercent)
                                        local barWidth = 3
                                        local barX = pos.X - boxWidth / 2 - 6
                                        if ESPState.HealthBarSide == "Right" then
                                            barX = pos.X + boxWidth / 2 + 4
                                        end
                                        local barY = topPos.Y + (boxHeight - barHeight)

                                        objects.HealthBarOutline.Size = Vector2.new(barWidth + 2, boxHeight + 2)
                                        objects.HealthBarOutline.Position = Vector2.new(barX - 1, topPos.Y - 1)
                                        objects.HealthBarOutline.Visible = true

                                        objects.HealthBar.Size = Vector2.new(barWidth, barHeight)
                                        objects.HealthBar.Position = Vector2.new(barX, barY)
                                        objects.HealthBar.Visible = true
                                        objects.HealthBar.Color = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
                                    elseif objects.HealthBar then
                                        if objects.HealthBar then objects.HealthBar.Visible = false end
                                        if objects.HealthBarOutline then objects.HealthBarOutline.Visible = false end
                                    end
                                else
                                    for _, obj in pairs(objects) do obj.Visible = false end
                                end
                            else
                                for _, obj in pairs(objects) do obj.Visible = false end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function RemovePlayerESP(player)
    local data = ESPObjects[player]
    if data then
        for _, obj in pairs(data) do
            if obj and obj.Destroy then obj:Destroy()
            elseif obj and obj.Remove then obj:Remove() end
        end
        ESPObjects[player] = nil
    end
end

local function StartESP()
    if ESPConnections.RenderStepped then return end
    ESPConnections.RenderStepped = RunService.RenderStepped:Connect(function()
        UpdateESP()
    end)
    ESPConnections.PlayerAdded = Players.PlayerAdded:Connect(CreateESPObjects)
    ESPConnections.PlayerRemoving = Players.PlayerRemoving:Connect(RemovePlayerESP)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            player.CharacterRemoving:Connect(function()
                RemovePlayerESP(player)
            end)
        end
    end
    ESPConnections.PlayerAddedCleanup = Players.PlayerAdded:Connect(function(player)
        if player == LocalPlayer then return end
        player.CharacterRemoving:Connect(function()
            RemovePlayerESP(player)
        end)
    end)
end

local function StopESP()
    for _, conn in pairs(ESPConnections) do
        if conn then conn:Disconnect() end
    end
    ESPConnections = {}
    ClearESP()
end

local VisualsGroup = Tabs.Visuals:AddLeftGroupbox("ESP")

VisualsGroup:AddToggle("ESPEnabled", {
    Text = "Enable ESP",
    Default = false,
    Callback = function(Value)
        ESPState.Enabled = Value
        if Value then
            StartESP()
        else
            StopESP()
        end
    end,
})

VisualsGroup:AddToggle("ESPBoxes", {
    Text = "Boxes",
    Default = true,
    Callback = function(Value) ESPState.Boxes = Value end,
})

VisualsGroup:AddToggle("ESPNames", {
    Text = "Names",
    Default = true,
    Callback = function(Value) ESPState.Names = Value end,
})

VisualsGroup:AddToggle("ESPTracers", {
    Text = "Tracers",
    Default = false,
    Callback = function(Value) ESPState.Tracers = Value end,
})

VisualsGroup:AddToggle("ESPHealthBar", {
    Text = "Health Bar",
    Default = true,
    Callback = function(Value) ESPState.HealthBar = Value end,
})

VisualsGroup:AddToggle("ESPTeamCheck", {
    Text = "Team Check",
    Default = false,
    Callback = function(Value) ESPState.TeamCheck = Value end,
})

VisualsGroup:AddToggle("ESPShowDistance", {
    Text = "Show Distance",
    Default = true,
    Callback = function(Value) ESPState.ShowDistance = Value end,
})

VisualsGroup:AddSlider("ESPMaxDistance", {
    Text = "Max Distance",
    Min = 100,
    Max = 5000,
    Default = 1000,
    Rounding = 0,
    Callback = function(Value) ESPState.MaxDistance = Value end,
})

local VisualsStyleGroup = Tabs.Visuals:AddRightGroupbox("Style")

VisualsStyleGroup:AddSlider("ESPRed", {
    Text = "Box Red",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        ESPState.BoxColor = Color3.fromRGB(Value, ESPState.BoxColor.G * 255, ESPState.BoxColor.B * 255)
    end,
})

VisualsStyleGroup:AddSlider("ESPGreen", {
    Text = "Box Green",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        ESPState.BoxColor = Color3.fromRGB(ESPState.BoxColor.R * 255, Value, ESPState.BoxColor.B * 255)
    end,
})

VisualsStyleGroup:AddSlider("ESPBlue", {
    Text = "Box Blue",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        ESPState.BoxColor = Color3.fromRGB(ESPState.BoxColor.R * 255, ESPState.BoxColor.G * 255, Value)
    end,
})

VisualsStyleGroup:AddToggle("ESPBoxFilled", {
    Text = "Filled Boxes",
    Default = false,
    Callback = function(Value) ESPState.BoxFilled = Value end,
})

VisualsStyleGroup:AddSlider("ESPEnemyRed", {
    Text = "Enemy Red",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        ESPState.EnemyColor = Color3.fromRGB(Value, ESPState.EnemyColor.G * 255, ESPState.EnemyColor.B * 255)
    end,
})

VisualsStyleGroup:AddSlider("ESPEnemyGreen", {
    Text = "Enemy Green",
    Min = 0,
    Max = 255,
    Default = 0,
    Rounding = 0,
    Callback = function(Value)
        ESPState.EnemyColor = Color3.fromRGB(ESPState.EnemyColor.R * 255, Value, ESPState.EnemyColor.B * 255)
    end,
})

VisualsStyleGroup:AddSlider("ESPEnemyBlue", {
    Text = "Enemy Blue",
    Min = 0,
    Max = 255,
    Default = 0,
    Rounding = 0,
    Callback = function(Value)
        ESPState.EnemyColor = Color3.fromRGB(ESPState.EnemyColor.R * 255, ESPState.EnemyColor.G * 255, Value)
    end,
})

VisualsStyleGroup:AddSlider("ESPNameRed", {
    Text = "Name Red",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        ESPState.NameColor = Color3.fromRGB(Value, ESPState.NameColor.G * 255, ESPState.NameColor.B * 255)
    end,
})

VisualsStyleGroup:AddSlider("ESPNameGreen", {
    Text = "Name Green",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        ESPState.NameColor = Color3.fromRGB(ESPState.NameColor.R * 255, Value, ESPState.NameColor.B * 255)
    end,
})

VisualsStyleGroup:AddSlider("ESPNameBlue", {
    Text = "Name Blue",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        ESPState.NameColor = Color3.fromRGB(ESPState.NameColor.R * 255, ESPState.NameColor.G * 255, Value)
    end,
})

VisualsStyleGroup:AddDropdown("ESPTracerPos", {
    Text = "Tracer Origin",
    Default = 1,
    Values = {"Bottom", "Center", "Top"},
    Callback = function(Value)
        ESPState.TracerPosition = Value
    end,
})

VisualsStyleGroup:AddDropdown("ESPHealthBarSide", {
    Text = "Health Bar Side",
    Default = 1,
    Values = {"Left", "Right"},
    Callback = function(Value)
        ESPState.HealthBarSide = Value
    end,
})

VisualsStyleGroup:AddButton({
    Text = "Reset ESP Style",
    Func = function()
        Options.ESPRed:SetValue(255)
        Options.ESPGreen:SetValue(255)
        Options.ESPBlue:SetValue(255)
        Options.ESPEnemyRed:SetValue(255)
        Options.ESPEnemyGreen:SetValue(0)
        Options.ESPEnemyBlue:SetValue(0)
        Options.ESPNameRed:SetValue(255)
        Options.ESPNameGreen:SetValue(255)
        Options.ESPNameBlue:SetValue(255)
        Options.ESPBoxFilled:SetValue(false)
        ESPState.BoxColor = Color3.fromRGB(255, 255, 255)
        ESPState.EnemyColor = Color3.fromRGB(255, 0, 0)
        ESPState.NameColor = Color3.fromRGB(255, 255, 255)
    end,
})

-- AIMBOT TAB
local AimbotState = {
    Enabled = false,
    Keybind = "E",
    KeybindMode = "Hold",
    ToggleAiming = false,
    Smoothness = 0.15,
    FOV = 150,
    MaxDistance = 1000,
    TeamCheck = true,
    VisibleCheck = false,
    TargetPart = "Head",
    FOVVisible = true,
    FOVColor = Color3.fromRGB(255, 255, 255),
    FOVFilled = false,
    SnapLine = false,
    SnapLineColor = Color3.fromRGB(255, 255, 255),
}

local TriggerbotState = {
    Enabled = false,
    Mode = "Always",
    ToggleActive = false,
    Keybind = "V",
    TargetPart = "Head",
    TeamCheck = true,
    WallCheck = true,
    MaxDistance = 1000,
    CrosshairRadius = 25,
    Delay = 60,
    RandomDelay = false,
    MinDelay = 20,
    MaxDelay = 90,
    LastFire = 0,
    NextFire = 0,
}

local AimbotConnection = nil
local FOVCircle = nil
local SnapLine = nil
local TriggerbotConnection = nil

local function CreateFOV()
    if not FOVCircle then
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Visible = AimbotState.FOVVisible
        FOVCircle.Thickness = 1
        FOVCircle.NumSides = 64
        FOVCircle.Radius = AimbotState.FOV
        FOVCircle.Filled = AimbotState.FOVFilled
        FOVCircle.Color = AimbotState.FOVColor
        FOVCircle.Transparency = 1
    end
    if not SnapLine then
        SnapLine = Drawing.new("Line")
        SnapLine.Visible = false
        SnapLine.Thickness = 1
        SnapLine.Color = AimbotState.SnapLineColor
        SnapLine.Transparency = 1
    end
end

local function DestroyFOV()
    if FOVCircle then
        FOVCircle:Remove()
        FOVCircle = nil
    end
    if SnapLine then
        SnapLine:Remove()
        SnapLine = nil
    end
end

local function GetMouseButtonType(key)
    if not key or key == "" then return nil end
    if typeof(key) == "EnumItem" and key.EnumType == Enum.UserInputType then
        return key
    end
    local normalized = tostring(key)
    normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")
    normalized = normalized:gsub("[Mm]ouse", "Mouse")
    normalized = normalized:gsub("[Bb]utton", "Button")
    normalized = normalized:gsub("^Mouse([1-5])$", "MouseButton%1")
    normalized = normalized:gsub("^Button([1-5])$", "MouseButton%1")
    if normalized:match("^MouseButton[1-5]$") then
        local ok, button = pcall(function() return Enum.UserInputType[normalized] end)
        return ok and button or nil
    end
    return nil
end

local function GetKeyCode(key)
    if not key or key == "" then return nil end
    if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
        return key
    end
    local keyName = tostring(key)
    if keyName and keyName ~= "" then
        local ok, keyCode = pcall(function() return Enum.KeyCode[keyName] end)
        if ok and keyCode then
            return keyCode
        end
    end
    return nil
end

local function IsInputMatch(input, key)
    if not key or key == "" then return false end
    local button = GetMouseButtonType(key)
    if button then
        return input.UserInputType == button
    end
    local keyCode = GetKeyCode(key)
    if keyCode then
        return input.KeyCode == keyCode
    end
    return false
end

local function IsKeyHeld(key)
    if not key or key == "" then return false end
    local button = GetMouseButtonType(key)
    if button then
        return UserInputService:IsMouseButtonPressed(button)
    end
    local keyCode = GetKeyCode(key)
    if keyCode then
        return UserInputService:IsKeyDown(keyCode)
    end
    return false
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if AimbotState.Enabled then
        local key = AimbotState.Keybind
        if Options.AimbotKeybind and Options.AimbotKeybind.Value then
            key = Options.AimbotKeybind.Value
        end
        if IsInputMatch(input, key) and AimbotState.KeybindMode == "Toggle" then
            AimbotState.ToggleAiming = not AimbotState.ToggleAiming
        end
    end

    if TriggerbotState.Enabled and TriggerbotState.Mode == "Toggle" then
        local key = TriggerbotState.Keybind
        if Options.TriggerbotKeybind and Options.TriggerbotKeybind.Value then
            key = Options.TriggerbotKeybind.Value
        end
        if IsInputMatch(input, key) then
            TriggerbotState.ToggleActive = not TriggerbotState.ToggleActive
        end
    end
end)

local function GetClosestPlayer()
    local camera = workspace.CurrentCamera
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local closest = nil
    local closestDist = AimbotState.FOV

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not player.Character then continue end
        if AimbotState.TeamCheck and player.Team == LocalPlayer.Team then continue end

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
            local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
            if hit and hit.Parent ~= player.Character then continue end
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
    if not target then return end
    local camera = workspace.CurrentCamera
    local pos = camera:WorldToViewportPoint(target.Position)
    local mousePos = UserInputService:GetMouseLocation()

    local dx = (pos.X - mousePos.X) * AimbotState.Smoothness
    local dy = (pos.Y - mousePos.Y) * AimbotState.Smoothness

    if typeof(mousemoverel) == "function" then
        mousemoverel(dx, dy)
    else
        local targetCFrame = CFrame.new(camera.CFrame.Position, target.Position)
        local smooth = math.clamp(AimbotState.Smoothness, 0.01, 1)
        camera.CFrame = camera.CFrame:Lerp(targetCFrame, smooth)
    end
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
    if SnapLine then
        if target and AimbotState.SnapLine then
            local pos = camera:WorldToViewportPoint(target.Position)
            SnapLine.Visible = true
            SnapLine.From = center
            SnapLine.To = Vector2.new(pos.X, pos.Y)
            SnapLine.Color = AimbotState.SnapLineColor
        else
            SnapLine.Visible = false
        end
    end

    local shouldAim = false
    local key = AimbotState.Keybind
    if Options.AimbotKeybind and Options.AimbotKeybind.Value then
        key = Options.AimbotKeybind.Value
    end

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
    CreateFOV()
    if AimbotConnection then return end
    AimbotConnection = RunService.RenderStepped:Connect(function()
        UpdateAimbot()
    end)
end

local function StopAimbot()
    if AimbotConnection then
        AimbotConnection:Disconnect()
        AimbotConnection = nil
    end
    DestroyFOV()
end

local function IsTriggerbotActive()
    if not TriggerbotState.Enabled then
        return false
    end
    if TriggerbotState.Mode == "Always" then
        return true
    elseif TriggerbotState.Mode == "Hold" then
        return IsKeyHeld(TriggerbotState.Keybind)
    elseif TriggerbotState.Mode == "Toggle" then
        return TriggerbotState.ToggleActive
    end
    return false
end

local function ScheduleTriggerbotFire()
    if TriggerbotState.RandomDelay then
        TriggerbotState.NextFire = tick() + math.random(TriggerbotState.MinDelay, TriggerbotState.MaxDelay) / 1000
    else
        TriggerbotState.NextFire = tick() + TriggerbotState.Delay / 1000
    end
end

local function TriggerbotFire()
    if typeof(mouse1click) == "function" then
        mouse1click()
    elseif typeof(mouse1press) == "function" then
        mouse1press()
        task.wait(0.03)
        if typeof(mouse1release) == "function" then
            mouse1release()
        end
    end
    TriggerbotState.LastFire = tick()
    ScheduleTriggerbotFire()
end

local function GetTriggerbotTarget()
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local closestTarget = nil
    local closestDist = TriggerbotState.CrosshairRadius

    for _, player in ipairs(Players:GetPlayers()) do
        if player and player ~= LocalPlayer then
            if TriggerbotState.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                continue
            end
            local character = player.Character
            if not character then continue end
            local targetPart = TriggerbotState.TargetPart == "Any" and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("LowerTorso")) or character:FindFirstChild(TriggerbotState.TargetPart)
            if not targetPart then continue end
            local projected, onScreen = camera:WorldToViewportPoint(targetPart.Position)
            if not onScreen then continue end
            local screenPos = Vector2.new(projected.X, projected.Y)
            local dist = (screenPos - center).Magnitude
            if dist <= closestDist then
                if TriggerbotState.WallCheck then
                    local params = RaycastParams.new()
                    params.FilterDescendantsInstances = {LocalPlayer.Character}
                    params.FilterType = Enum.RaycastFilterType.Blacklist
                    params.IgnoreWater = true
                    local ray = workspace:Raycast(camera.CFrame.Position, (targetPart.Position - camera.CFrame.Position).Unit * TriggerbotState.MaxDistance, params)
                    if not ray or not ray.Instance or not ray.Instance:IsDescendantOf(character) then
                        continue
                    end
                end
                closestTarget = targetPart
                closestDist = dist
            end
        end
    end
    return closestTarget
end

local function UpdateTriggerbot()
    if not IsTriggerbotActive() then
        return
    end
    if tick() < TriggerbotState.NextFire then
        return
    end
    local targetPart = GetTriggerbotTarget()
    if targetPart then
        TriggerbotFire()
    end
end

local function StartTriggerbot()
    if TriggerbotConnection then return end
    TriggerbotConnection = RunService.RenderStepped:Connect(UpdateTriggerbot)
    ScheduleTriggerbotFire()
end

local function StopTriggerbot()
    if TriggerbotConnection then
        TriggerbotConnection:Disconnect()
        TriggerbotConnection = nil
    end
end

local function ToggleTriggerbotMode(key)
    if TriggerbotState.Mode ~= "Toggle" then return end
    if not IsInputMatch(key, TriggerbotState.Keybind) then return end
    TriggerbotState.ToggleActive = not TriggerbotState.ToggleActive
end

local AimbotGroup = Tabs.Aimbot:AddLeftGroupbox("Aimbot")

AimbotGroup:AddToggle("AimbotEnabled", {
    Text = "Enable Aimbot",
    Default = false,
    Callback = function(Value)
        if AimbotState.Enabled == Value then return end
        AimbotState.Enabled = Value
        AimbotState.ToggleAiming = false
        if Value then
            StartAimbot()
        else
            StopAimbot()
        end
    end,
})

AimbotGroup:AddLabel("Aimbot Keybind")
    :AddKeyPicker("AimbotKeybind", { Default = "E", NoUI = false, Text = "Aimbot Keybind", Callback = function(Value) AimbotState.Keybind = Value end })

AimbotGroup:AddDropdown("AimbotKeybindMode", {
    Text = "Keybind Mode",
    Default = 1,
    Values = {"Hold", "Toggle"},
    Callback = function(Value) AimbotState.KeybindMode = Value end,
})

AimbotGroup:AddSlider("AimbotSmoothness", {
    Text = "Smoothness",
    Min = 0.01,
    Max = 1,
    Default = 0.15,
    Rounding = 2,
    Callback = function(Value) AimbotState.Smoothness = Value end,
})

AimbotGroup:AddSlider("AimbotFOV", {
    Text = "FOV",
    Min = 10,
    Max = 500,
    Default = 150,
    Rounding = 0,
    Callback = function(Value) AimbotState.FOV = Value end,
})

AimbotGroup:AddSlider("AimbotMaxDist", {
    Text = "Max Distance",
    Min = 100,
    Max = 5000,
    Default = 1000,
    Rounding = 0,
    Callback = function(Value) AimbotState.MaxDistance = Value end,
})

AimbotGroup:AddToggle("AimbotTeamCheck", {
    Text = "Team Check",
    Default = true,
    Callback = function(Value) AimbotState.TeamCheck = Value end,
})

AimbotGroup:AddToggle("AimbotVisCheck", {
    Text = "Visibility Check",
    Default = false,
    Callback = function(Value) AimbotState.VisibleCheck = Value end,
})

AimbotGroup:AddDropdown("AimbotTargetPart", {
    Text = "Target Part",
    Default = 1,
    Values = {"Head", "HumanoidRootPart", "Torso", "UpperTorso"},
    Callback = function(Value) AimbotState.TargetPart = Value end,
})

local FOVGroup = Tabs.Aimbot:AddRightGroupbox("FOV")

FOVGroup:AddToggle("AimbotFOVVisible", {
    Text = "Show FOV Circle",
    Default = true,
    Callback = function(Value) AimbotState.FOVVisible = Value end,
})

FOVGroup:AddToggle("AimbotFOVFilled", {
    Text = "Filled FOV",
    Default = false,
    Callback = function(Value) AimbotState.FOVFilled = Value end,
})

FOVGroup:AddSlider("AimbotFOVRed", {
    Text = "FOV Red",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        AimbotState.FOVColor = Color3.fromRGB(Value, AimbotState.FOVColor.G * 255, AimbotState.FOVColor.B * 255)
    end,
})

FOVGroup:AddSlider("AimbotFOVGreen", {
    Text = "FOV Green",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        AimbotState.FOVColor = Color3.fromRGB(AimbotState.FOVColor.R * 255, Value, AimbotState.FOVColor.B * 255)
    end,
})

FOVGroup:AddSlider("AimbotFOVBlue", {
    Text = "FOV Blue",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        AimbotState.FOVColor = Color3.fromRGB(AimbotState.FOVColor.R * 255, AimbotState.FOVColor.G * 255, Value)
    end,
})

FOVGroup:AddToggle("AimbotSnapLine", {
    Text = "Snap Line",
    Default = false,
    Callback = function(Value) AimbotState.SnapLine = Value end,
})

FOVGroup:AddSlider("AimbotSnapRed", {
    Text = "Snap Red",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        AimbotState.SnapLineColor = Color3.fromRGB(Value, AimbotState.SnapLineColor.G * 255, AimbotState.SnapLineColor.B * 255)
    end,
})

FOVGroup:AddSlider("AimbotSnapGreen", {
    Text = "Snap Green",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        AimbotState.SnapLineColor = Color3.fromRGB(AimbotState.SnapLineColor.R * 255, Value, AimbotState.SnapLineColor.B * 255)
    end,
})

FOVGroup:AddSlider("AimbotSnapBlue", {
    Text = "Snap Blue",
    Min = 0,
    Max = 255,
    Default = 255,
    Rounding = 0,
    Callback = function(Value)
        AimbotState.SnapLineColor = Color3.fromRGB(AimbotState.SnapLineColor.R * 255, AimbotState.SnapLineColor.G * 255, Value)
    end,
})

FOVGroup:AddButton({
    Text = "Reset Aimbot Style",
    Func = function()
        Options.AimbotFOVRed:SetValue(255)
        Options.AimbotFOVGreen:SetValue(255)
        Options.AimbotFOVBlue:SetValue(255)
        Options.AimbotSnapRed:SetValue(255)
        Options.AimbotSnapGreen:SetValue(255)
        Options.AimbotSnapBlue:SetValue(255)
        Options.AimbotFOVFilled:SetValue(false)
        AimbotState.FOVColor = Color3.fromRGB(255, 255, 255)
        AimbotState.SnapLineColor = Color3.fromRGB(255, 255, 255)
    end,
})

local TriggerbotGroup = Tabs.Triggerbot:AddLeftGroupbox("Triggerbot")

TriggerbotGroup:AddToggle("TriggerbotEnabled", {
    Text = "Enable Triggerbot",
    Default = false,
    Callback = function(Value)
        if TriggerbotState.Enabled == Value then return end
        TriggerbotState.Enabled = Value
        if Value then
            StartTriggerbot()
        else
            StopTriggerbot()
        end
    end,
})

TriggerbotGroup:AddLabel("Triggerbot Keybind")
    :AddKeyPicker("TriggerbotKeybind", { Default = "V", NoUI = false, Text = "Triggerbot Keybind", Callback = function(Value) TriggerbotState.Keybind = Value end })

TriggerbotGroup:AddDropdown("TriggerbotMode", {
    Text = "Activation Mode",
    Default = 1,
    Values = {"Always", "Hold", "Toggle"},
    Callback = function(Value) TriggerbotState.Mode = Value end,
})

TriggerbotGroup:AddDropdown("TriggerbotTargetPart", {
    Text = "Target Part",
    Default = 1,
    Values = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "Any"},
    Callback = function(Value) TriggerbotState.TargetPart = Value end,
})

TriggerbotGroup:AddToggle("TriggerbotTeamCheck", {
    Text = "Team Check",
    Default = true,
    Callback = function(Value) TriggerbotState.TeamCheck = Value end,
})

TriggerbotGroup:AddToggle("TriggerbotWallCheck", {
    Text = "Require Line Of Sight",
    Default = true,
    Callback = function(Value) TriggerbotState.WallCheck = Value end,
})

local TriggerbotAdvancedGroup = Tabs.Triggerbot:AddRightGroupbox("Advanced")

TriggerbotAdvancedGroup:AddSlider("TriggerbotRadius", {
    Text = "Crosshair Radius",
    Min = 0,
    Max = 150,
    Default = 25,
    Rounding = 0,
    Callback = function(Value) TriggerbotState.CrosshairRadius = Value end,
})

TriggerbotAdvancedGroup:AddSlider("TriggerbotMaxDist", {
    Text = "Max Distance",
    Min = 100,
    Max = 5000,
    Default = 1000,
    Rounding = 0,
    Callback = function(Value) TriggerbotState.MaxDistance = Value end,
})

TriggerbotAdvancedGroup:AddToggle("TriggerbotRandomDelay", {
    Text = "Random Delay",
    Default = false,
    Callback = function(Value) TriggerbotState.RandomDelay = Value end,
})

TriggerbotAdvancedGroup:AddSlider("TriggerbotDelay", {
    Text = "Delay (ms)",
    Min = 0,
    Max = 500,
    Default = 60,
    Rounding = 0,
    Callback = function(Value) TriggerbotState.Delay = Value end,
})

TriggerbotAdvancedGroup:AddSlider("TriggerbotMinDelay", {
    Text = "Min Delay (ms)",
    Min = 0,
    Max = 500,
    Default = 20,
    Rounding = 0,
    Callback = function(Value) TriggerbotState.MinDelay = Value end,
})

TriggerbotAdvancedGroup:AddSlider("TriggerbotMaxDelay", {
    Text = "Max Delay (ms)",
    Min = 0,
    Max = 500,
    Default = 90,
    Rounding = 0,
    Callback = function(Value) TriggerbotState.MaxDelay = Value end,
})

TriggerbotAdvancedGroup:AddButton({
    Text = "Reset Triggerbot",
    Func = function()
        Options.TriggerbotMode:SetValue(1)
        Options.TriggerbotKeybind:SetValue("V")
        Options.TriggerbotTargetPart:SetValue(1)
        Options.TriggerbotTeamCheck:SetValue(true)
        Options.TriggerbotWallCheck:SetValue(true)
        Options.TriggerbotRadius:SetValue(25)
        Options.TriggerbotMaxDist:SetValue(1000)
        Options.TriggerbotRandomDelay:SetValue(false)
        Options.TriggerbotDelay:SetValue(60)
        Options.TriggerbotMinDelay:SetValue(20)
        Options.TriggerbotMaxDelay:SetValue(90)
        TriggerbotState.Mode = "Always"
        TriggerbotState.Keybind = "V"
        TriggerbotState.TargetPart = "Head"
        TriggerbotState.TeamCheck = true
        TriggerbotState.WallCheck = true
        TriggerbotState.CrosshairRadius = 25
        TriggerbotState.MaxDistance = 1000
        TriggerbotState.RandomDelay = false
        TriggerbotState.Delay = 60
        TriggerbotState.MinDelay = 20
        TriggerbotState.MaxDelay = 90
    end,
})

-- UI SETTINGS TAB
local MenuGroup = Tabs.Main:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("StatsOverlayToggle", {
    Text = "Show Stats Overlay",
    Default = true,
    Callback = function(Value)
        if Value then
            CreateStatsOverlay()
        else
            DestroyStatsOverlay()
        end
    end,
})

MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = Library.KeybindFrame.Visible,
    Text = "Open Keybind Menu",
    Callback = function(value)
        Library.KeybindFrame.Visible = value
    end,
})

MenuGroup:AddLabel("Menu bind")
    :AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })

Library.ToggleKeybind = Options.MenuKeybind

-- UPGRADED INIT (AUTOLOAD & SILENTLOAD)
task.spawn(function()
    LoadGameModules()
    BuildCosmeticLists()
    PlayerDataController:WaitUntilLoaded()
    CreateStatsOverlay()
    
    -- Silent loading config
    LoadConfig()
    
    -- Auto-forcing true autoloading states in filesystem for server hops
    if writefile and makefolder then
        pcall(function()
            EnsureFolder()
            writefile(ConfigFolder .. "/autoload.txt", "true")
        end)
    end
    
    RestoreSpooferUI()
    InstallAllHooks()
    ApplyLoadedConfig()
    UpdateDropdowns()
    UpdateStatsLabel()
end)
