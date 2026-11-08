-- Abysall Hub | Blox Fruits
-- PlaceId: 2753915549 | UniverseId: 994732206
-- Player ESP, event-object ESP and a clean-room implementation of the 2026
-- Halloween Pumpkin Hunt auto-collector behaviour recovered from the supplied
-- obfuscated script. No code from that file is copied here.

local LoadStart = tick()
if not Abysall or not Abysall.Interface then
    warn("[Abysall] BloxFruits dogrudan calistirildi: once ana Loader (README loadstring) calistir.")
    return
end
Abysall.SavePath = "BloxFruits"

local Library = Abysall.Interface.Library
local Toggles = Library.Toggles
local Options = Library.Options

local function CloneReference(Object)
    if Abysall.Environment and Abysall.Environment.cloneref then
        return Abysall.Environment.cloneref(Object)
    end
    return Object
end

local Services = setmetatable({}, {
    __index = function(Self, Name)
        return CloneReference(game:GetService(Name))
    end,
})

local LocalPlayer = Services.Players.LocalPlayer
local Connections = {}
local Unloaded = false
local function TrackConn(Connection)
    table.insert(Connections, Connection)
    return Connection
end

local function ToggleOn(Name)
    local Toggle = Toggles and Toggles[Name]
    return not Unloaded and Toggle ~= nil and Toggle.Value == true
end

local function BindChange(Control, Callback)
    if Control == nil then return end
    local Registering = true
    Control:OnChanged(function(...)
        if Registering or Unloaded then return end
        return Callback(...)
    end)
    Registering = false
end

local function OnChange(Name, Callback)
    BindChange(Toggles and Toggles[Name], Callback)
end

local function GetCharacter()
    return LocalPlayer.Character
end

local function GetHumanoid()
    local Character = GetCharacter()
    return Character and Character:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart()
    local Character = GetCharacter()
    if not Character then return nil end
    return Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChildWhichIsA("BasePart", true)
end

local function PumpkinRoot()
    return Services.Workspace:FindFirstChild("PumpkinHunt")
end

local function IsPumpkinModel(Object)
    if not Object:IsA("Model") then return false end
    return Object:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function PumpkinPosition(Object)
    if Object:IsA("Model") then
        local Primary = Object.PrimaryPart or Object:FindFirstChildWhichIsA("BasePart", true)
        if Primary then return Primary.Position end
        local Ok, Pivot = pcall(function() return Object:GetPivot().Position end)
        if Ok and Pivot then return Pivot end
    elseif Object:IsA("BasePart") then
        return Object.Position
    end
    return nil
end

-- Returns event objects without duplicating a BasePart when its Model is already
-- a candidate. The supplied script targets Models under PumpkinHunt; the flat
-- BasePart fallback covers folders that only contain raw hitboxes.
local function ScanPumpkins()
    local Root = PumpkinRoot()
    if not Root then return {}, {} end
    local Descendants = Root:GetDescendants()
    local Models, Parts = {}, {}
    local IncludedParts = {}
    local IncludedModels = {}

    local function IncludeModel(Object)
        if IncludedModels[Object] or not IsPumpkinModel(Object) then return end
        IncludedModels[Object] = true
        Models[#Models + 1] = Object
        for _, Part in ipairs(Object:GetDescendants()) do
            if Part:IsA("BasePart") then IncludedParts[Part] = true end
        end
    end

    for _, Object in ipairs(Descendants) do
        if Object:IsA("Model") and string.find(string.lower(Object.Name), "pumpkin", 1, true) then
            IncludeModel(Object)
        end
    end

    -- A PumpkinHunt folder should contain only event objects, so Models there
    -- may have custom names. Include them when they have a usable part.
    for _, Object in ipairs(Descendants) do IncludeModel(Object) end

    for _, Object in ipairs(Descendants) do
        if Object:IsA("BasePart") and not IncludedParts[Object]
            and string.find(string.lower(Object.Name), "pumpkin", 1, true) then
            Parts[#Parts + 1] = Object
        end
    end

    return Models, Parts
end

local function NearestPumpkin(MaxRange)
    local RootPart = GetRootPart()
    if not RootPart then return nil, math.huge end
    local Best, BestDistance = nil, math.huge
    local Models, Parts = ScanPumpkins()
    for _, Candidate in ipairs(Models) do
        local Position = PumpkinPosition(Candidate)
        if Position then
            local Distance = (Position - RootPart.Position).Magnitude
            if Distance < BestDistance and (MaxRange <= 0 or Distance <= MaxRange) then
                Best, BestDistance = Candidate, Distance
            end
        end
    end
    for _, Candidate in ipairs(Parts) do
        local Distance = (Candidate.Position - RootPart.Position).Magnitude
        if Distance < BestDistance and (MaxRange <= 0 or Distance <= MaxRange) then
            Best, BestDistance = Candidate, Distance
        end
    end
    return Best, BestDistance
end

local function WorldToScreen(Position)
    local Camera = Services.Workspace.CurrentCamera
    if not Camera then return nil end
    local Ok, Vector, OnScreen = pcall(function()
        return Camera:WorldToViewportPoint(Position)
    end)
    if not Ok or not Vector or not OnScreen then return nil end
    return Vector2.new(Vector.X, Vector.Y)
end

local function ClickAt(Position)
    local Point = WorldToScreen(Position)
    if not Point then return false end
    local Ok, Input = pcall(function() return Services.VirtualInputManager end)
    if not Ok or not Input then return false end
    local X, Y = math.floor(Point.X + 0.5), math.floor(Point.Y + 0.5)
    local Press = pcall(function() Input:SendMouseButtonEvent(X, Y, 0, true, game, 0) end)
    local Release = pcall(function() Input:SendMouseButtonEvent(X, Y, 0, false, game, 0) end)
    return Press and Release
end

-- Player movement used only while Auto Collect is enabled. Blink mode is a
-- deliberate, user-selected fast jump to each pumpkin; otherwise the character
-- is moved in small server-tolerated increments.
local function MoveToward(Position, Delta, Blink, Speed)
    local RootPart = GetRootPart()
    if not RootPart or not Position then return false end
    local Current = RootPart.Position
    local ToTarget = Position - Current
    local Distance = ToTarget.Magnitude
    if Distance < 0.05 then return true end
    local Step = Blink and Distance or math.min(Distance, math.max(1, Speed or 80) * Delta)
    local Direction = ToTarget.Unit
    local NewPosition = Current + Direction * Step
    local Flat = Vector3.new(Position.X - NewPosition.X, 0, Position.Z - NewPosition.Z)
    local Rotation = Flat.Magnitude > 0.05
        and CFrame.lookAt(NewPosition, NewPosition + Flat)
        or RootPart.CFrame - RootPart.CFrame.Position + NewPosition
    local Ok = pcall(function()
        RootPart.CFrame = Rotation
    end)
    return Ok
end

local PreviousWalkSpeed
local function RestoreWalkSpeed()
    local Humanoid = GetHumanoid()
    if Humanoid and PreviousWalkSpeed then
        pcall(function() Humanoid.WalkSpeed = PreviousWalkSpeed end)
        PreviousWalkSpeed = nil
    end
end

local function ApplyWalkSpeed()
    if not ToggleOn("BloxLoopWalkSpeed") then RestoreWalkSpeed(); return end
    local Humanoid = GetHumanoid()
    if not Humanoid or Humanoid.Health <= 0 then return end
    if not PreviousWalkSpeed then PreviousWalkSpeed = Humanoid.WalkSpeed end
    local Wanted = math.clamp(tonumber(Options.BloxWalkSpeed.Value) or 16, 16, 300)
    if Humanoid.WalkSpeed ~= Wanted then Humanoid.WalkSpeed = Wanted end
end

local Window = Library:CreateWindow({
    Title = "Abysall Hub | Blox Fruits",
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
    Main = Window:AddTab("Main", "target"),
    Visuals = Window:AddTab("Visuals", "eye"),
}

-- // Movement // -------------------------------------------------------------
local Movement = Tabs.Main:AddLeftGroupbox("Movement")
Movement:AddToggle("BloxLoopWalkSpeed", {
    Text = "Loop WalkSpeed", Default = false,
    Tooltip = "Keeps the current character at the selected WalkSpeed.",
})
Movement:AddSlider("BloxWalkSpeed", {
    Text = "WalkSpeed", Default = 30, Min = 16, Max = 300, Rounding = 0,
})
BindChange(Toggles.BloxLoopWalkSpeed, function(Value)
    if Value then ApplyWalkSpeed() else RestoreWalkSpeed() end
end)
BindChange(Options.BloxWalkSpeed, ApplyWalkSpeed)

-- // Halloween Pumpkin Hunt // ---------------------------------------------
local Pumpkin = Tabs.Main:AddRightGroupbox("Halloween Pumpkin Hunt")
Pumpkin:AddToggle("AutoPumpkin", {
    Text = "Auto Collect Pumpkin", Default = false,
    Tooltip = "Finds spawned pumpkins in Workspace.PumpkinHunt, moves to the nearest one and sends a click at its screen position.",
})
Pumpkin:AddToggle("PumpkinBlink", {
    Text = "Blink to Pumpkins", Default = false,
    Tooltip = "Teleports directly to the nearest pumpkin instead of moving gradually. This is more aggressive and still client-side.",
})
Pumpkin:AddSlider("PumpkinMaxRange", {
    Text = "Max Range", Default = 2500, Min = 0, Max = 10000, Rounding = 0,
    Tooltip = "0 disables the distance limit.",
})
Pumpkin:AddSlider("PumpkinCollectRadius", {
    Text = "Collect Radius", Default = 12, Min = 2, Max = 60, Rounding = 0,
    Tooltip = "Distance at which the module tries to click the pumpkin.",
})
Pumpkin:AddSlider("PumpkinMoveSpeed", {
    Text = "Move Speed", Default = 90, Min = 16, Max = 300, Rounding = 0,
    Tooltip = "Studs per second when Blink is off.",
})
Pumpkin:AddSlider("PumpkinClickInterval", {
    Text = "Click Interval", Default = 0.25, Min = 0.1, Max = 2, Rounding = 2,
    Tooltip = "Seconds between click attempts while a pumpkin is in range.",
})
Pumpkin:AddLabel("The current Halloween event spawns pumpkins around the map. No pumpkins are fabricated or generated by this module.", true)

local CurrentTarget
local RetargetElapsed = 0
local ClickElapsed = 0
local function ValidTarget(Object)
    if not Object or not Object.Parent then return false end
    return PumpkinPosition(Object) ~= nil
end

local function AutoCollect(Delta)
    if not ToggleOn("AutoPumpkin") then return end
    local RootPart = GetRootPart()
    if not RootPart then return end

    RetargetElapsed += Delta
    ClickElapsed += Delta
    if RetargetElapsed >= 0.5 or not ValidTarget(CurrentTarget) then
        RetargetElapsed = 0
        local Range = tonumber(Options.PumpkinMaxRange.Value) or 2500
        CurrentTarget, _ = NearestPumpkin(Range)
    end
    if not CurrentTarget then return end

    local Position = PumpkinPosition(CurrentTarget)
    if not Position then CurrentTarget = nil; return end
    local Distance = (Position - RootPart.Position).Magnitude
    local Blink = ToggleOn("PumpkinBlink")
    if Distance > (tonumber(Options.PumpkinCollectRadius.Value) or 12) then
        MoveToward(Position, Delta, Blink, tonumber(Options.PumpkinMoveSpeed.Value) or 90)
        return
    end

    local Interval = math.max(0.1, tonumber(Options.PumpkinClickInterval.Value) or 0.25)
    if ClickElapsed < Interval then return end
    ClickElapsed = 0
    ClickAt(Position)
end

-- // Player ESP // ----------------------------------------------------------
local Players = Tabs.Visuals:AddLeftGroupbox("Player ESP")
Players:AddToggle("BloxPlayerESP", { Text = "Player ESP", Default = false })
Toggles.BloxPlayerESP:AddColorPicker("BloxPlayerESPColor", {
    Text = "ESP Color", Default = Color3.fromRGB(255, 70, 70), Transparency = 0,
})
local PlayerESPObjects = {}

local function AddPlayerESP(Player)
    if Player == LocalPlayer then return end
    local Character = Player.Character
    if not Character or PlayerESPObjects[Character] then return end
    PlayerESPObjects[Character] = true
    pcall(function()
        Abysall.ESPLibrary:AddESP({
            Object = Character,
            Text = Player.Name,
            Color = Options.BloxPlayerESPColor.Value,
            Player = Player,
        })
    end)
    Character.Destroying:Once(function()
        PlayerESPObjects[Character] = nil
        if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Character) end) end
    end)
end

local function RemovePlayerESP(Character)
    if not PlayerESPObjects[Character] then return end
    PlayerESPObjects[Character] = nil
    if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Character) end) end
end

OnChange("BloxPlayerESP", function(Value)
    for _, Player in ipairs(Services.Players:GetPlayers()) do
        if Value then
            AddPlayerESP(Player)
        elseif Player.Character then
            RemovePlayerESP(Player.Character)
        end
    end
end)
BindChange(Options.BloxPlayerESPColor, function(Value)
    for Character in pairs(PlayerESPObjects) do
        pcall(function() Abysall.ESPLibrary:UpdateObjectColor(Character, Value) end)
    end
end)
local function HookPlayer(Player)
    if Player == LocalPlayer then return end
    TrackConn(Player.CharacterAdded:Connect(function()
        task.wait(0.6)
        if ToggleOn("BloxPlayerESP") then AddPlayerESP(Player) end
    end))
    TrackConn(Player.CharacterRemoving:Connect(RemovePlayerESP))
end
TrackConn(Services.Players.PlayerAdded:Connect(HookPlayer))
for _, Player in ipairs(Services.Players:GetPlayers()) do HookPlayer(Player) end

-- // Name-filtered ESP // ---------------------------------------------------
local Generic = Tabs.Visuals:AddRightGroupbox("Filtered ESP")
Generic:AddToggle("BloxNameFilterESP", {
    Text = "Name Filter ESP", Default = false,
    Tooltip = "Enable before using the comma/semicolon-separated object names.",
})
Toggles.BloxNameFilterESP:AddColorPicker("BloxNameFilterColor", {
    Text = "ESP Color", Default = Color3.fromRGB(80, 180, 255), Transparency = 0,
})
Generic:AddInput("BloxNameFilter", {
    Text = "Name Filter", Default = "", Placeholder = "Orn: Fruit, Kitsune, Pumpkin",
    Tooltip = "Comma/semicolon-separated object names. Leave blank to hide matches.",
})
Generic:AddLabel("Scans Models and BaseParts. Player characters are ignored.", true)

local NameESPObjects = {}
local function NameFilterValue()
    return Options.BloxNameFilter and tostring(Options.BloxNameFilter.Value or "") or ""
end
local function NameFilterOn()
    return ToggleOn("BloxNameFilterESP") and NameFilterValue() ~= ""
end
local function MatchesNameFilter(Object)
    local Raw = NameFilterValue()
    if Raw == "" then return false end
    local Name = string.lower(Object.Name)
    for Token in string.gmatch(Raw, "[^,;%s]+") do
        if string.find(Name, string.lower(Token), 1, true) then return true end
    end
    return false
end

local function IsGenericCandidate(Object)
    if Object:IsA("Model") then
        return Object:FindFirstChildWhichIsA("BasePart", true) ~= nil
    end
    if Object:IsA("BasePart") then
        local Model = Object:FindFirstAncestorOfClass("Model")
        return Model == nil or not MatchesNameFilter(Model)
    end
    return false
end

local function RemoveNameESP(Object)
    if not NameESPObjects[Object] then return end
    NameESPObjects[Object] = nil
    if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Object) end) end
end

local function AddNameESP(Object)
    if NameESPObjects[Object] or not NameFilterOn() or not MatchesNameFilter(Object) or not IsGenericCandidate(Object) then return end
    if Services.Players:GetPlayerFromCharacter(Object) then return end
    NameESPObjects[Object] = true
    pcall(function()
        Abysall.ESPLibrary:AddESP({ Object = Object, Text = Object.Name, Color = Options.BloxNameFilterColor.Value })
    end)
    Object.Destroying:Once(function() RemoveNameESP(Object) end)
end

local function ScanNameESP()
    if not NameFilterOn() then return end
    for _, Object in ipairs(Services.Workspace:GetDescendants()) do AddNameESP(Object) end
    for Object in pairs(NameESPObjects) do
        if not Object.Parent or not NameFilterOn() or not MatchesNameFilter(Object) then RemoveNameESP(Object) end
    end
end

local function ClearNameESP()
    for Object in pairs(NameESPObjects) do RemoveNameESP(Object) end
    table.clear(NameESPObjects)
end

OnChange("BloxNameFilterESP", function(Value)
    if Value then
        ScanNameESP()
    else
        ClearNameESP()
    end
end)
BindChange(Options.BloxNameFilter, function()
    ClearNameESP()
    ScanNameESP()
end)
BindChange(Options.BloxNameFilterColor, function(Value)
    for Object in pairs(NameESPObjects) do
        pcall(function() Abysall.ESPLibrary:UpdateObjectColor(Object, Value) end)
    end
end)

-- // Pumpkin ESP // ---------------------------------------------------------
local PumpkinEsp = Tabs.Visuals:AddRightGroupbox("Pumpkin ESP")
PumpkinEsp:AddToggle("PumpkinESP", { Text = "Pumpkin ESP", Default = false })
Toggles.PumpkinESP:AddColorPicker("PumpkinESPColor", {
    Text = "ESP Color", Default = Color3.fromRGB(255, 135, 35), Transparency = 0,
})
PumpkinEsp:AddLabel("Labels pumpkin objects in Workspace.PumpkinHunt as \"Pumpkin\".", true)

local PumpkinESPObjects = {}
local function AddPumpkinESP(Object)
    if PumpkinESPObjects[Object] then return end
    PumpkinESPObjects[Object] = true
    pcall(function()
        Abysall.ESPLibrary:AddESP({ Object = Object, Text = "Pumpkin", Color = Options.PumpkinESPColor.Value })
    end)
    Object.Destroying:Once(function()
        PumpkinESPObjects[Object] = nil
        if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Object) end) end
    end)
end

local function RemovePumpkinESP(Object)
    if not PumpkinESPObjects[Object] then return end
    PumpkinESPObjects[Object] = nil
    if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Object) end) end
end

local function ScanPumpkinESP()
    if not ToggleOn("PumpkinESP") then return end
    local Models, Parts = ScanPumpkins()
    for _, Object in ipairs(Models) do AddPumpkinESP(Object) end
    for _, Object in ipairs(Parts) do AddPumpkinESP(Object) end
    for Object in pairs(PumpkinESPObjects) do
        if not Object.Parent then RemovePumpkinESP(Object) end
    end
end

OnChange("PumpkinESP", function(Value)
    if Value then ScanPumpkinESP() else
        for Object in pairs(PumpkinESPObjects) do RemovePumpkinESP(Object) end
        table.clear(PumpkinESPObjects)
    end
end)
BindChange(Options.PumpkinESPColor, function(Value)
    for Object in pairs(PumpkinESPObjects) do
        pcall(function() Abysall.ESPLibrary:UpdateObjectColor(Object, Value) end)
    end
end)

-- // Shared refresh // ------------------------------------------------------
local ScanElapsed = 0
TrackConn(Services.Workspace.DescendantAdded:Connect(function(Object)
    if NameFilterOn() then AddNameESP(Object) end
    if ToggleOn("PumpkinESP") and string.find(string.lower(Object.Name), "pumpkin", 1, true) then
        ScanPumpkinESP()
    end
end))
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    ApplyWalkSpeed()
    AutoCollect(Delta)
    ScanElapsed += Delta
    if ScanElapsed >= 1 then
        ScanElapsed = 0
        if NameFilterOn() then ScanNameESP() end
        ScanPumpkinESP()
    end
end))

-- // Unload // --------------------------------------------------------------
Library:OnUnload(function()
    Unloaded = true
    for _, Connection in ipairs(Connections) do pcall(function() Connection:Disconnect() end) end
    RestoreWalkSpeed()
    for Character in pairs(PlayerESPObjects) do
        if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Character) end) end
    end
    table.clear(PlayerESPObjects)
    ClearNameESP()
    for Object in pairs(PumpkinESPObjects) do
        if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Object) end) end
    end
    table.clear(PumpkinESPObjects)
    if Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:Unload() end) end
    if type(Abysall.AddonDisablers) == "table" then
        for _, Disabler in ipairs(Abysall.AddonDisablers) do
            pcall(function() if Disabler.Fn then Disabler.Fn() end end)
        end
        Abysall.AddonDisablers = nil
    end
    getgenv().Abysall = nil
end)

Abysall.Interface.ApplySettingsTab(Window)
Abysall.Interface.ApplyAddons(Window, "bloxfruits")
Library:Notify("Blox Fruits destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")
