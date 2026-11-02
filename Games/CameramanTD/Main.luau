-- Abysall Hub | Cameraman Tower Defense
-- PlaceId: 132929771812494 | UniverseId: 10762636904
-- Oyunun kendi remote'lari ile: Auto Play (yerlestirme), Auto Upgrade/Sell/Target,
-- Auto Wave Skip, Game Speed, Auto Summon, ESP, WalkSpeed/JumpPower.

local LoadStart = tick()
if not Abysall or not Abysall.Interface then
    warn("[Abysall] CameramanTD dogrudan calistirildi: once ana Loader (README loadstring) calistir.")
    return
end
Abysall.SavePath = "CameramanTD"

local Library = Abysall.Interface.Library
local Toggles = Library.Toggles
local Options = Library.Options

local function BindChange(Control, Fn)
    if Control == nil then return end
    local Registering = true
    Control:OnChanged(function(...)
        if Registering then return end
        return Fn(...)
    end)
    Registering = false
end
local function ToggleOn(Name)
    local T = Toggles and Toggles[Name]
    if T == nil then return false end
    return T.Value == true
end
local function OnChange(Name, Fn)
    BindChange(Toggles and Toggles[Name], Fn)
end

local function CloneReference(Object)
    if Abysall.Environment and Abysall.Environment.cloneref then
        return Abysall.Environment.cloneref(Object)
    end
    return Object
end

local Services = setmetatable({}, {
    __index = function(self, Name)
        return CloneReference(game:GetService(Name))
    end,
})

local LocalPlayer = Services.Players.LocalPlayer
local Unloaded = false
local Connections = {}
local function TrackConn(Conn)
    table.insert(Connections, Conn)
    return Conn
end

-- // Oyun modulleri // ------------------------------------------------------
local ReplicatedStorage = Services.ReplicatedStorage
local ModuleLoader = ReplicatedStorage:WaitForChild("ModuleLoader", 30)
local Network = nil
local Replication = nil

task.spawn(function()
    local Ok = pcall(function()
        local Shared = ModuleLoader:WaitForChild("Shared")
        local Net = Shared:WaitForChild("Network")
        Network = require(Net)
    end)
    if not Ok then warn("[Abysall] CameramanTD: Network modulu yuklenemedi") end
    pcall(function()
        local Client = ModuleLoader:WaitForChild("Client")
        Replication = require(Client:WaitForChild("Replication"))
    end)
end)

local function Remote(Name)
    if not Network then return nil end
    local Ok, Result = pcall(function() return Network.Get(Name) end)
    return Ok and Result or nil
end
local function Fire(Name, ...)
    local R = Remote(Name)
    if not R then return false end
    local Args = table.pack(...)
    local Ok = pcall(function() R:FireServer(table.unpack(Args, 1, Args.n)) end)
    return Ok
end
local function Invoke(Name, ...)
    local R = Remote(Name)
    if not R then return nil end
    local Args = table.pack(...)
    local Ok, Result = pcall(function() return R:InvokeServer(table.unpack(Args, 1, Args.n)) end)
    if Ok then return Result end
    return nil
end

local function GetReplicaData()
    if not Replication then return nil end
    local Ok, Replica = pcall(Replication.GetCurrentReplica)
    if Ok and Replica then
        return Replica.Data
    end
    return nil
end

local function GetGame()
    return Services.Workspace:FindFirstChild("Game")
end
local function GetPlacedTowerModels()
    local Game = GetGame()
    local Folder = Game and Game:FindFirstChild("Towers")
    return Folder
end

-- // Pencere // -------------------------------------------------------------
local Window = Library:CreateWindow({
    Title = "Abysall Hub | Cameraman Tower Defense",
    Footer = "dsc.gg/abysallhub",
    NotifySide = "Right",
    ShowCustomCursor = false,
    AutoShow = true,
    Center = true,
    TabPadding = 3,
    MenuFadeTime = 0,
    CornerRadius = 2,
})
Abysall.Interface.ApplyInfoTab(Window)

local Tabs = {
    Automation = Window:AddTab("Automation", "bot"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Misc = Window:AddTab("Misc", "settings"),
}

-- // Automation // ----------------------------------------------------------
local Auto = Tabs.Automation:AddLeftGroupbox("Match")

Auto:AddToggle("AutoPlay", {
    Text = "Auto Play (Place Units)", Default = false,
    Tooltip = "Sahip oldugun unitleri TowerArea uzerine yerlestirir. Para rezervine saygi duyar.",
})
Auto:AddToggle("AutoUpgrade", { Text = "Auto Upgrade", Default = false })
Auto:AddToggle("AutoTarget", { Text = "Auto Target", Default = false })
Auto:AddToggle("AutoSell", {
    Text = "Auto Sell (over limit)", Default = false,
    Tooltip = "Kule sayisi limiti asinca en dusuk seviyeli kuleleri satar.",
})
Auto:AddSlider("MaxTowers", { Text = "Max Towers", Default = 20, Min = 1, Max = 60, Rounding = 0 })
Auto:AddSlider("MoneyReserve", { Text = "Money Reserve", Default = 0, Min = 0, Max = 100000, Rounding = 0 })
Auto:AddToggle("AutoWaveSkip", { Text = "Auto Wave Skip", Default = false })
Auto:AddToggle("AutoPlayAgain", { Text = "Auto Play Again (lobby)", Default = false })

local Economy = Tabs.Automation:AddRightGroupbox("Economy")

Economy:AddDropdown("GameSpeed", {
    Text = "Game Speed", Values = { "Default (1x)", "1.5x", "2x", "Normal (1x)" },
    Default = "1.5x",
})
Economy:AddToggle("AutoSummon", {
    Text = "Auto Summon (Basic Crate)", Default = false,
    Tooltip = "SummonTowers('Basic Crate', 1) - 100 para.",
})
Economy:AddInput("RedeemCodes", {
    Text = "Codes", Default = "", Placeholder = "kod1, kod2",
    Tooltip = "RedeemCode ile tek tek dener (bir kez).",
})
Economy:AddButton("Redeem Now", function()
    local Raw = tostring(Options.RedeemCodes.Value or "")
    local Sent = 0
    for Code in string.gmatch(Raw, "[^,;%s]+") do
        if Fire("RedeemCode", Code) then Sent += 1 end
        task.wait(0.6)
    end
    Library:Notify(Sent .. " kod gonderildi.")
end)

local SpeedValues = { ["Default (1x)"] = 1, ["1.5x"] = 1.5, ["2x"] = 2, ["Normal (1x)"] = 1 }

-- // Visuals // -------------------------------------------------------------
local Esp = Tabs.Visuals:AddLeftGroupbox("ESP")

Esp:AddToggle("TowerESP", { Text = "Tower ESP", Default = false })
Toggles.TowerESP:AddColorPicker("TowerESPColor", { Text = "Tower Color", Default = Color3.fromRGB(0, 200, 255), Transparency = 0 })
Esp:AddToggle("EnemyESP", { Text = "Enemy ESP", Default = false })
Toggles.EnemyESP:AddColorPicker("EnemyESPColor", { Text = "Enemy Color", Default = Color3.fromRGB(255, 60, 60), Transparency = 0 })
Esp:AddToggle("TDPlayerESP", { Text = "Player ESP", Default = false })
Toggles.TDPlayerESP:AddColorPicker("TDPlayerESPColor", { Text = "Player Color", Default = Color3.fromRGB(255, 255, 0), Transparency = 0 })

local EspSettings = Tabs.Visuals:AddRightGroupbox("ESP Settings")
EspSettings:AddToggle("ESPShowDistance", { Text = "Show Distance", Default = true })
EspSettings:AddToggle("ESPTracers", { Text = "Tracers", Default = false })
EspSettings:AddToggle("ESPArrows", { Text = "Arrows", Default = false })
OnChange("ESPShowDistance", function(V) Abysall.ESPLibrary:SetShowDistance(V) end)
OnChange("ESPTracers", function(V) Abysall.ESPLibrary:SetTracers(V) end)
OnChange("ESPArrows", function(V) Abysall.ESPLibrary:SetArrows(V) end)

-- // Misc // ----------------------------------------------------------------
local Misc = Tabs.Misc:AddLeftGroupbox("Player")
Misc:AddToggle("TDWalkSpeed", { Text = "WalkSpeed", Default = false })
Misc:AddSlider("TDWalkSpeedValue", { Text = "Speed", Default = 16, Min = 16, Max = 200, Rounding = 0 })
Misc:AddToggle("TDJumpPower", { Text = "JumpPower", Default = false })
Misc:AddSlider("TDJumpPowerValue", { Text = "Jump", Default = 50, Min = 50, Max = 300, Rounding = 0 })

-- // ESP // -----------------------------------------------------------------
local TrackedESP = {}

local function AddESP(Object, Text, Color)
    if TrackedESP[Object] then
        pcall(function() Abysall.ESPLibrary:UpdateObjectColor(Object, Color) end)
        return
    end
    TrackedESP[Object] = true
    pcall(function()
        Abysall.ESPLibrary:AddESP({ Object = Object, Text = Text, Color = Color })
        Object.Destroying:Once(function()
            TrackedESP[Object] = nil
            if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Object) end) end
        end)
    end)
end
local function RemoveESP(Object)
    TrackedESP[Object] = nil
    if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Object) end) end
end

local function RefreshTowerESP()
    if not ToggleOn("TowerESP") then return end
    local Folder = GetPlacedTowerModels()
    if not Folder then return end
    for _, Model in ipairs(Folder:GetChildren()) do
        if Model:IsA("Model") then AddESP(Model, "Tower", Options.TowerESPColor.Value) end
    end
end

local function RefreshEnemyESP()
    if not ToggleOn("EnemyESP") then return end
    local Game = GetGame()
    local Folder = Game and Game:FindFirstChild("Enemies")
    if not Folder then return end
    for _, Model in ipairs(Folder:GetChildren()) do
        local Hum = Model:FindFirstChildOfClass("Humanoid")
        local Text = Model.Name
        if Hum then Text = Model.Name .. " [" .. math.floor(Hum.Health + 0.5) .. "]" end
        AddESP(Model, Text, Options.EnemyESPColor.Value)
    end
end

local function RefreshPlayerESP()
    if not ToggleOn("TDPlayerESP") then return end
    for _, Player in ipairs(Services.Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character then
            AddESP(Player.Character, Player.Name, Options.TDPlayerESPColor.Value)
        end
    end
end

OnChange("TowerESP", function(V)
    if V then RefreshTowerESP()
    else
        local Folder = GetPlacedTowerModels()
        if Folder then for _, M in ipairs(Folder:GetChildren()) do RemoveESP(M) end end
    end
end)
OnChange("EnemyESP", function(V)
    if V then RefreshEnemyESP()
    else
        local Game = GetGame()
        local Folder = Game and Game:FindFirstChild("Enemies")
        if Folder then for _, M in ipairs(Folder:GetChildren()) do RemoveESP(M) end end
    end
end)
OnChange("TDPlayerESP", function(V)
    for _, Player in ipairs(Services.Players:GetPlayers()) do
        if Player.Character then
            if V and Player ~= LocalPlayer then
                AddESP(Player.Character, Player.Name, Options.TDPlayerESPColor.Value)
            else
                RemoveESP(Player.Character)
            end
        end
    end
end)

-- // Game Speed // ----------------------------------------------------------
local function ApplySpeed()
    local Value = SpeedValues[Options.GameSpeed.Value] or 1
    Invoke("ChangeSpeed", Value)
end
BindChange(Options.GameSpeed, function() ApplySpeed() end)

-- // Auto Play (placement) // ----------------------------------------------
local function GetPlacementPoints()
    local Game = GetGame()
    local Area = Game and Game:FindFirstChild("TowerArea")
    local Points = {}
    if Area then
        for _, Part in ipairs(Area:GetChildren()) do
            if Part:IsA("BasePart") then
                local Size = Part.Size
                for _ = 1, 4 do
                    local Local = Vector3.new(
                        (math.random() - 0.5) * math.max(Size.X - 2, 0),
                        Size.Y / 2,
                        (math.random() - 0.5) * math.max(Size.Z - 2, 0)
                    )
                    table.insert(Points, Part.CFrame * CFrame.new(Local))
                end
            end
        end
    end
    return Points
end

local function GetEquippedUnits()
    local Data = GetReplicaData()
    local List = {}
    local Towers = Data and Data.Towers
    if type(Towers) == "table" then
        for UnitId, Info in pairs(Towers) do
            if type(Info) == "table" and Info.Name then
                if Info.Equipped then
                    table.insert(List, { UnitId = tostring(UnitId), Name = Info.Name, Level = tonumber(Info.Level) or 0 })
                end
            end
        end
    end
    table.sort(List, function(A, B) return (A.Level or 0) > (B.Level or 0) end)
    return List
end

local function PlaceOne()
    local Data = GetReplicaData()
    if not Data then return false end
    local Money = tonumber(Data.Money) or 0
    local Reserve = tonumber(Options.MoneyReserve.Value) or 0
    if Money <= Reserve then return false end
    local Folder = GetPlacedTowerModels()
    local Count = Folder and #Folder:GetChildren() or 0
    if Count >= (tonumber(Options.MaxTowers.Value) or 20) then return false end
    local Units = GetEquippedUnits()
    if #Units == 0 then return false end
    local Points = GetPlacementPoints()
    if #Points == 0 then return false end
    local Unit = Units[math.random(1, #Units)]
    local CF = Points[math.random(1, #Points)]
    return Fire("TowerAdd", {
        Name = Unit.Name, UnitId = Unit.UnitId,
        Pos = CF.Position, CFrame = CF,
    })
end

-- // Kule yardimcilari // ---------------------------------------------------
local function ForEachTower(Fn)
    local Folder = GetPlacedTowerModels()
    if not Folder then return 0 end
    local Count = 0
    for _, Model in ipairs(Folder:GetChildren()) do
        if Model:IsA("Model") then
            Count += 1
            Fn(Model)
        end
    end
    return Count
end

local function UpgradeAll()
    ForEachTower(function(Model) Fire("TowerUpgrade", { Id = Model.Name }) end)
end
local function TargetAll()
    ForEachTower(function(Model) Fire("TowerTarget", { Id = Model.Name }) end)
end
local function SellExcess()
    local Max = tonumber(Options.MaxTowers.Value) or 20
    local Models = {}
    ForEachTower(function(Model) table.insert(Models, Model) end)
    if #Models <= Max then return end
    for Index = 1, #Models - Max do
        Fire("TowerSell", { Id = Models[Index].Name })
        task.wait(0.2)
    end
end

-- // Ana dongu // -----------------------------------------------------------
local function GetHumanoid()
    local Char = LocalPlayer.Character
    return Char and Char:FindFirstChildOfClass("Humanoid") or nil
end

task.spawn(function()
    local LastUpgrade, LastTarget, LastPlace, LastSkip, LastSummon, LastEsp, LastSell = 0, 0, 0, 0, 0, 0, 0
    while not Unloaded do
        task.wait(0.1)
        local Now = os.clock()

        -- Auto Play
        if ToggleOn("AutoPlay") and Now - LastPlace > 0.7 then
            LastPlace = Now
            if not PlaceOne() then
                -- yer yok / para yok: bekle
            end
        end

        -- Auto Upgrade
        if ToggleOn("AutoUpgrade") and Now - LastUpgrade > 0.4 then
            LastUpgrade = Now
            UpgradeAll()
        end

        -- Auto Target
        if ToggleOn("AutoTarget") and Now - LastTarget > 0.4 then
            LastTarget = Now
            TargetAll()
        end

        -- Auto Sell (over limit)
        if ToggleOn("AutoSell") and Now - LastSell > 1 then
            LastSell = Now
            SellExcess()
        end

        -- Auto Wave Skip
        if ToggleOn("AutoWaveSkip") and Now - LastSkip > 1 then
            LastSkip = Now
            Fire("WaveSkip")
        end

        -- Auto Summon
        if ToggleOn("AutoSummon") and Now - LastSummon > 2.2 then
            LastSummon = Now
            Invoke("SummonTowers", "Basic Crate", 1)
        end

        -- Auto Play Again (lobby)
        if ToggleOn("AutoPlayAgain") and Now - LastSkip > 3 then
            Fire("PlayAgain")
        end

        -- ESP refresh
        if Now - LastEsp > 1 then
            LastEsp = Now
            RefreshTowerESP()
            RefreshEnemyESP()
            RefreshPlayerESP()
        end

        -- WalkSpeed / JumpPower
        local Hum = GetHumanoid()
        if Hum then
            if ToggleOn("TDWalkSpeed") then
                local Speed = tonumber(Options.TDWalkSpeedValue.Value) or 16
                if Hum.WalkSpeed ~= Speed then Hum.WalkSpeed = Speed end
            elseif Hum.WalkSpeed ~= 16 then
                Hum.WalkSpeed = 16
            end
            if ToggleOn("TDJumpPower") then
                local Power = tonumber(Options.TDJumpPowerValue.Value) or 50
                if not Hum.UseJumpPower then Hum.UseJumpPower = true end
                if Hum.JumpPower ~= Power then Hum.JumpPower = Power end
            end
        end
    end
end)

-- // Unload // --------------------------------------------------------------
Library:OnUnload(function()
    Unloaded = true
    for _, Conn in ipairs(Connections) do
        pcall(function() Conn:Disconnect() end)
    end
    for Object in pairs(TrackedESP) do
        if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Object) end) end
    end
    TrackedESP = {}
    if Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:Unload() end) end
    if type(Abysall.AddonDisablers) == "table" then
        for _, D in ipairs(Abysall.AddonDisablers) do
            pcall(function() if D.Fn then D.Fn() end end)
        end
        Abysall.AddonDisablers = nil
    end
    pcall(function() getgenv().abysall = nil end)
    pcall(function() getgenv().mspaint = nil end)
    getgenv().Abysall = nil
end)

Abysall.Interface.ApplySettingsTab(Window)
Abysall.Interface.ApplyAddons(Window, "cameramantd")
Library:Notify("Cameraman Tower Defense destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")