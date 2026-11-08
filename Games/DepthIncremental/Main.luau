-- Abysall Hub | Depth Incremental
-- PlaceId: 119101118479978 | UniverseId: 10769835283
-- Auto-teleport to the boss object named WormModel (or a configured name)
-- and track it with ESP. The game data layout is server-spawn dependent.

local LoadStart = tick()
if not Abysall or not Abysall.Interface then
    warn("[Abysall] DepthIncremental dogrudan calistirildi: once ana Loader (README loadstring) calistir.")
    return
end
Abysall.SavePath = "DepthIncremental"

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

local function GetRootPart()
    local Character = LocalPlayer.Character
    if not Character then return nil end
    return Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChildWhichIsA("BasePart", true)
end

local function TargetName()
    local Value = Options.WormTargetName and tostring(Options.WormTargetName.Value or "") or ""
    local Lower = string.lower(Value)
    Lower = string.gsub(Lower, "^%s+", "")
    Lower = string.gsub(Lower, "%s+$", "")
    return Lower
end

local function NameMatches(Name, Wanted)
    if Wanted == "" then return false end
    return string.find(string.lower(Name), Wanted, 1, true) ~= nil
end

local function ExactName(Name, Wanted)
    return Wanted ~= "" and string.lower(Name) == Wanted
end

local function IsValidTarget(Object)
    if not Object or not Object.Parent then return false end
    if Object:IsA("Model") then
        return Object:FindFirstChildWhichIsA("BasePart", true) ~= nil
            or pcall(function() return Object:GetPivot() end)
    end
    return Object:IsA("BasePart")
end

local function GetTargetPosition(Object)
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

-- Exact matches beat case-insensitive substring matches; Models beat raw parts.
-- If several children match, keep the ancestor-most Model instead of picking a
-- child hitbox and teleporting inside it.
local function ScanWormTarget()
    local Wanted = TargetName()
    if Wanted == "" then return nil end

    local ExactModel, ExactPart, PartialModel, PartialPart
    for _, Object in ipairs(Services.Workspace:GetDescendants()) do
        if IsValidTarget(Object) then
            if Object:IsA("Model") then
                if ExactName(Object.Name, Wanted) then
                    ExactModel = ExactModel or Object
                elseif NameMatches(Object.Name, Wanted) then
                    PartialModel = PartialModel or Object
                end
            elseif Object:IsA("BasePart") then
                if ExactName(Object.Name, Wanted) then
                    ExactPart = ExactPart or Object
                elseif NameMatches(Object.Name, Wanted) then
                    PartialPart = PartialPart or Object
                end
            end
        end
    end

    return ExactModel or PartialModel or ExactPart or PartialPart
end

local CurrentTarget
local LastAutoAt = 0
local LastTargetKey
local LastTargetPosition

local function TargetKey(Object)
    if not Object then return nil end
    if Object:IsA("Model") then
        return tostring(Object:GetFullName())
    end
    return tostring(Object:GetFullName())
end

local function ClearTargetState()
    CurrentTarget = nil
    LastTargetKey = nil
    LastTargetPosition = nil
end

local function RefreshTarget()
    local Wanted = TargetName()
    if Wanted == "" then
        ClearTargetState()
        return nil
    end
    if IsValidTarget(CurrentTarget) then return CurrentTarget end
    CurrentTarget = ScanWormTarget()
    if not CurrentTarget then ClearTargetState() end
    return CurrentTarget
end

local function WormTeleport(Manual)
    local Target = RefreshTarget()
    if not Target then
        if Manual then Library:Notify("'WormModel' was not found. Try changing Target Name.") end
        return false
    end
    local RootPart = GetRootPart()
    if not RootPart then
        if Manual then Library:Notify("Character hazir degil.") end
        return false
    end
    local Position = GetTargetPosition(Target)
    if not Position then return false end

    local Offset = tonumber(Options.WormTeleportOffset.Value) or 5
    Offset = math.clamp(Offset, -20, 40)
    local Destination = Position + Vector3.new(0, Offset, 0)
    local Rotation = RootPart.CFrame - RootPart.CFrame.Position + Destination
    local Ok = pcall(function()
        RootPart.CFrame = Rotation
    end)
    if Ok then
        LastAutoAt = tick()
        LastTargetKey = TargetKey(Target)
        LastTargetPosition = Position
    end
    return Ok
end

local function MaybeAutoTeleport()
    if not ToggleOn("AutoWormTeleport") then return end
    local Target = RefreshTarget()
    if not Target then return end
    local Position = GetTargetPosition(Target)
    if not Position then return end

    local Key = TargetKey(Target)
    local Cooldown = math.max(0.1, tonumber(Options.WormTeleportCooldown.Value) or 2)
    local Changed = Key ~= LastTargetKey
    local Moved = LastTargetPosition and (Position - LastTargetPosition).Magnitude > 12
    local CooldownReady = tick() - LastAutoAt >= Cooldown
    if Changed or Moved or CooldownReady then
        WormTeleport(false)
    end
end

local Window = Library:CreateWindow({
    Title = "Abysall Hub | Depth Incremental",
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

-- // Worm Target // ----------------------------------------------------------
local Worm = Tabs.Main:AddLeftGroupbox("Worm Target")
Worm:AddToggle("AutoWormTeleport", {
    Text = "Auto Worm Teleport", Default = false,
    Tooltip = "Teleports to the first WormModel match as soon as it exists in Workspace.",
})
Worm:AddInput("WormTargetName", {
    Text = "Target Name", Default = "WormModel", Placeholder = "WormModel",
    Tooltip = "Case-insensitive name match. Leave blank to disable targeting.",
})
Worm:AddSlider("WormTeleportOffset", {
    Text = "Teleport Height", Default = 5, Min = -20, Max = 40, Rounding = 0,
})
Worm:AddSlider("WormTeleportCooldown", {
    Text = "Auto Cooldown", Default = 2, Min = 0.5, Max = 30, Rounding = 1,
    Tooltip = "Repeat delay when the same worm stays in place. A newly found or moved worm teleports immediately.",
})
Worm:AddButton("Teleport to Worm Now", function() WormTeleport(true) end)
local WormStatus
WormStatus = Worm:AddLabel("Waiting for a WormModel...", true)

-- // Worm ESP // ------------------------------------------------------------
local Visuals = Tabs.Visuals:AddLeftGroupbox("Worm ESP")
Visuals:AddToggle("WormESP", {
    Text = "Worm ESP", Default = false,
})
Toggles.WormESP:AddColorPicker("WormESPColor", {
    Text = "ESP Color", Default = Color3.fromRGB(255, 80, 50), Transparency = 0,
})
Visuals:AddLabel("Tracks the same target name used by Worm Target.", true)

local WormESPObjects = {}
local function RemoveWormESP(Object)
    if not WormESPObjects[Object] then return end
    WormESPObjects[Object] = nil
    if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Object) end) end
end

local function AddWormESP(Object)
    if not Object or WormESPObjects[Object] then return end
    WormESPObjects[Object] = true
    pcall(function()
        Abysall.ESPLibrary:AddESP({
            Object = Object,
            Text = "Worm",
            Color = Options.WormESPColor.Value,
        })
    end)
    Object.Destroying:Once(function() RemoveWormESP(Object) end)
end

local function ScanWormESP()
    local Target = RefreshTarget()
    if ToggleOn("WormESP") and Target then AddWormESP(Target) end
    for Object in pairs(WormESPObjects) do
        if not Object.Parent or Object ~= Target then RemoveWormESP(Object) end
    end
    if not ToggleOn("AutoWormTeleport") and not ToggleOn("WormESP") then
        WormStatus:SetText("Auto Worm Teleport and Worm ESP are off.")
    elseif Target then
        WormStatus:SetText("Worm found: " .. tostring(Target:GetFullName()))
    else
        WormStatus:SetText("Waiting for a WormModel...")
    end
end

OnChange("WormESP", function(Value)
    if Value then ScanWormESP() else
        for Object in pairs(WormESPObjects) do RemoveWormESP(Object) end
        table.clear(WormESPObjects)
    end
end)
BindChange(Options.WormESPColor, function(Value)
    for Object in pairs(WormESPObjects) do
        pcall(function() Abysall.ESPLibrary:UpdateObjectColor(Object, Value) end)
    end
end)
BindChange(Options.WormTargetName, function()
    ClearTargetState()
    CurrentTarget = nil
    if ToggleOn("WormESP") then
        for Object in pairs(WormESPObjects) do RemoveWormESP(Object) end
        table.clear(WormESPObjects)
        ScanWormESP()
    else
        WormStatus:SetText("Target name updated.")
    end
end)
OnChange("AutoWormTeleport", function(Value)
    if Value then
        WormTeleport(false)
    else
        LastAutoAt = 0
        LastTargetKey = nil
        LastTargetPosition = nil
    end
end)

-- // Rescan // --------------------------------------------------------------
local ScanAccum = 0
TrackConn(Services.Workspace.DescendantAdded:Connect(function(Object)
    if TargetName() ~= "" and NameMatches(Object.Name, TargetName()) then
        ScanAccum = 1 -- forces the normal refresh path on the next heartbeat
        WormStatus:SetText("Worm candidate added: " .. Object.Name)
    end
end))
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    ScanAccum += Delta
    if ScanAccum < 0.5 then return end
    ScanAccum = 0
    MaybeAutoTeleport()
    ScanWormESP()
end))

-- // Unload // --------------------------------------------------------------
Library:OnUnload(function()
    Unloaded = true
    for _, Connection in ipairs(Connections) do pcall(function() Connection:Disconnect() end) end
    for Object in pairs(WormESPObjects) do
        if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Object) end) end
    end
    table.clear(WormESPObjects)
    if Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:Unload() end) end
    if type(Abysall.AddonDisablers) == "table" then
        for _, Disabler in ipairs(Abysall.AddonDisablers) do
            pcall(function() if Disabler.Fn then Disabler.Fn() end end)
        end
        Abysall.AddonDisablers = nil
    end
    pcall(function() getgenv().abysall = nil end)
    pcall(function() getgenv().mspaint = nil end)
    getgenv().Abysall = nil
end)

Abysall.Interface.ApplySettingsTab(Window)
Abysall.Interface.ApplyAddons(Window, "depthincremental")
Library:Notify("Depth Incremental destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")
