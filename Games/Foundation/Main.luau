-- Abysall Hub | THE FOUNDATION (namegames, Doors benzeri)
-- PlaceIds: 18186775539 (ana yer), 77614252294790 (alt yer)
-- ToolBox / PuzzleGate / Crowbar (LLV1+LLV2) / Door / LeverModel ESP + Speed.

local LoadStart = tick()
if not Abysall or not Abysall.Interface then
    warn("[Abysall] Foundation direkt calistirildi: once ana Loader (README loadstring) calistir.")
    return
end
Abysall.SavePath = "Foundation"

local Library = Abysall.Interface.Library
local SaveManager = Abysall.Interface.SaveManager
local ThemeManager = Abysall.Interface.ThemeManager

local Toggles = Library.Toggles
-- Toggle okumalarini nil-guvenli yapar; anahtar yoksa false doner (kutuphane sifirlanirsa cokmeyi onler)
local function ToggleOn(Name)
	local T = Toggles and Toggles[Name]
	if T == nil then return false end
	return T.Value == true
end
local function OnChange(Name, Fn)
	local T = Toggles and Toggles[Name]
	if T == nil then return end
	T:OnChanged(Fn)
end
local Options = Library.Options

local function CloneReference(Object)
    if Abysall and Abysall.Environment.cloneref then
        return Abysall.Environment.cloneref(Object)
    else
        return Object
    end
end

local Services = setmetatable({}, {
    __index = function(self, Name)
        return CloneReference(game:GetService(Name))
    end
})

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

Services.Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Services.Workspace.CurrentCamera
end)

local Connections = {}
local function TrackConn(Conn)
    table.insert(Connections, Conn)
    return Conn
end

local Window = Library:CreateWindow({
    Title = "Abysall Hub | THE FOUNDATION",
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
    Visuals = Window:AddTab("Visuals", "eye"),
    Misc = Window:AddTab("Misc", "house"),
}

local Groupboxes = {}

-- // Visuals: Object ESP //
Groupboxes.Visuals_Object = Tabs.Visuals:AddLeftGroupbox("Object ESP")

Groupboxes.Visuals_Object:AddToggle("ESPToolBox", {
    Text = "ToolBox ESP", Default = false, Tooltip = "ToolBox objelerini isaretler.",
})
Toggles.ESPToolBox:AddColorPicker("ESPToolBoxColor", {
    Text = "ToolBox Rengi", Default = Color3.fromRGB(0, 255, 0), Transparency = 0,
})
Groupboxes.Visuals_Object:AddToggle("ESPPuzzleGate", {
    Text = "PuzzleGate ESP", Default = false, Tooltip = "PuzzleGate objelerini isaretler.",
})
Toggles.ESPPuzzleGate:AddColorPicker("ESPPuzzleGateColor", {
    Text = "PuzzleGate Rengi", Default = Color3.fromRGB(255, 165, 0), Transparency = 0,
})
Groupboxes.Visuals_Object:AddToggle("ESPCrowbar", {
    Text = "Crowbar ESP", Default = false, Tooltip = "CrowbarVariantLLV1 ve CrowbarVariantLLV2 ikisini de isaretler.",
})
Toggles.ESPCrowbar:AddColorPicker("ESPCrowbarColor", {
    Text = "Crowbar Rengi", Default = Color3.fromRGB(255, 255, 0), Transparency = 0,
})
Groupboxes.Visuals_Object:AddToggle("ESPDoor", {
    Text = "Door ESP", Default = false, Tooltip = "Kapi objelerini isaretler.",
})
Toggles.ESPDoor:AddColorPicker("ESPDoorColor", {
    Text = "Door Rengi", Default = Color3.fromRGB(0, 200, 255), Transparency = 0,
})
Groupboxes.Visuals_Object:AddToggle("ESPLeverModel", {
    Text = "LeverModel ESP", Default = false, Tooltip = "LeverModel objelerini isaretler.",
})
Toggles.ESPLeverModel:AddColorPicker("ESPLeverModelColor", {
    Text = "LeverModel Rengi", Default = Color3.fromRGB(170, 0, 255), Transparency = 0,
})

-- isim (normalize edilmis) -> ESP girisi
local ESPEntries = {
    { Toggle = "ESPToolBox", Color = "ESPToolBoxColor", Label = "Tool Box",
        Names = { toolbox = true } },
    { Toggle = "ESPPuzzleGate", Color = "ESPPuzzleGateColor", Label = "Puzzle Gate",
        Names = { puzzlegate = true } },
    { Toggle = "ESPCrowbar", Color = "ESPCrowbarColor", Label = "Crowbar",
        Names = { crowbarvariantllv1 = true, crowbarvariantllv2 = true, crowbar = true } },
    { Toggle = "ESPDoor", Color = "ESPDoorColor", Label = "Door",
        Names = { door = true } },
    { Toggle = "ESPLeverModel", Color = "ESPLeverModelColor", Label = "Lever",
        Names = { levermodel = true, lever = true } },
}

local ESPObjects = {}
local HookedObjects = {}

local function NormalizeName(Name)
    return (string.lower(Name or "")):gsub("[%s_%-]", "")
end

local function EntryFor(Obj)
    local Normalized = NormalizeName(Obj.Name)
    for _, Entry in ipairs(ESPEntries) do
        if Entry.Names[Normalized] then
            return Entry
        end
    end
    return nil
end

local function IsPlayerItem(Obj)
    for _, P in ipairs(Services.Players:GetPlayers()) do
        if P.Character and Obj:IsDescendantOf(P.Character) then return true end
        local BP = P:FindFirstChild("Backpack")
        if BP and Obj:IsDescendantOf(BP) then return true end
    end
    return false
end

local function HookObject(Obj)
    if HookedObjects[Obj] then return end
    if not (Obj:IsA("Model") or Obj:IsA("BasePart") or Obj:IsA("Tool")) then return end
    if IsPlayerItem(Obj) then return end
    local Entry = EntryFor(Obj)
    if not Entry then return end
    local Toggle = Toggles[Entry.Toggle]
    if not Toggle or not Toggle.Value then return end
    HookedObjects[Obj] = true
    local Color = Color3.fromRGB(255, 255, 255)
    pcall(function()
        local Picker = Options[Entry.Color]
        if Picker then Color = Picker.Value end
    end)
    local Ok = pcall(function()
        Abysall.ESPLibrary:AddESP({ Object = Obj, Text = Entry.Label, Color = Color })
    end)
    if not Ok then
        HookedObjects[Obj] = nil
        return
    end
    table.insert(ESPObjects, { Object = Obj, Entry = Entry })
    pcall(function()
        Obj.Destroying:Once(function()
            HookedObjects[Obj] = nil
            if Abysall and Abysall.ESPLibrary then
                pcall(function() Abysall.ESPLibrary:RemoveESP(Obj) end)
            end
        end)
    end)
end

local function ScanObjects()
    for _, D in ipairs(Services.Workspace:GetDescendants()) do
        HookObject(D)
    end
end

local function ClearObjects()
    for _, Item in ipairs(ESPObjects) do
        pcall(function() Abysall.ESPLibrary:RemoveESP(Item.Object) end)
        HookedObjects[Item.Object] = nil
    end
    ESPObjects = {}
end

local function RefreshObjects()
    local AnyOn = false
    for _, Entry in ipairs(ESPEntries) do
        local Toggle = Toggles[Entry.Toggle]
        if Toggle and Toggle.Value then
            AnyOn = true
            break
        end
    end
    if AnyOn then
        ScanObjects()
    else
        ClearObjects()
    end
end

for _, Entry in ipairs(ESPEntries) do
    local ToggleName = Entry.Toggle
    OnChange(ToggleName, function(Value)
        if Value then
            ScanObjects()
        else
            pcall(RefreshObjects)
        end
    end)
    local Picker = Options[Entry.Color]
    if Picker then
        Picker:OnChanged(function(Value)
            for _, Item in ipairs(ESPObjects) do
                if Item.Entry == Entry then
                    Abysall.ESPLibrary:UpdateObjectColor(Item.Object, Value)
                end
            end
        end)
    end
end
TrackConn(Services.Workspace.DescendantAdded:Connect(function(Obj)
    HookObject(Obj)
end))

-- // Misc: Movement //
Groupboxes.Misc_Move = Tabs.Misc:AddLeftGroupbox("Movement")
Groupboxes.Misc_Move:AddSlider("WalkSpeedVal", {
    Text = "WalkSpeed", Min = 16, Max = 200, Default = 16, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("WalkSpeedOn", { Text = "Speed", Default = false })
Groupboxes.Misc_Move:AddDivider()
Groupboxes.Misc_Move:AddToggle("Fly", { Text = "Fly", Default = false })
Toggles.Fly:AddKeyPicker("FlyKey", {
    Text = "Fly", Default = "F", Mode = "Toggle", SyncToggleState = true,
})
Groupboxes.Misc_Move:AddSlider("FlySpeed", {
    Text = "Fly Speed", Min = 0, Max = 200, Default = 50, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("Noclip", { Text = "Noclip", Default = false })
Toggles.Noclip:AddKeyPicker("NoclipKey", {
    Text = "Noclip", Default = "N", Mode = "Toggle", SyncToggleState = true,
})

TrackConn(Services.RunService.RenderStepped:Connect(function()
    if Toggles.WalkSpeedOn and ToggleOn("WalkSpeedOn") and LocalPlayer.Character then
        local Hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Hum then Hum.WalkSpeed = Options.WalkSpeedVal.Value end
    end
end))

local FlyBody = Instance.new("BodyVelocity")
FlyBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)
FlyBody.Velocity = Vector3.zero

local function FlyRoot()
    local Char = LocalPlayer.Character
    if not Char then return nil end
    return Char:FindFirstChild("HumanoidRootPart") or Char:FindFirstChild("UpperTorso") or Char:FindFirstChild("Head")
end

local function FlyDir()
    local Char = LocalPlayer.Character
    local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
    if not Hum or Hum.MoveDirection == Vector3.zero or not Camera then
        return Vector3.zero
    end
    local LookFlat = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
    if LookFlat.Magnitude < 0.01 then LookFlat = Vector3.new(0, 0, -1) end
    local FlatFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + LookFlat)
    local Vel = (Camera.CFrame * CFrame.new(FlatFrame:VectorToObjectSpace(Hum.MoveDirection))).Position - Camera.CFrame.Position
    if Vel.Magnitude < 0.01 then return Vector3.zero end
    return Vel.Unit
end

TrackConn(Services.RunService.RenderStepped:Connect(function()
    local R = FlyRoot()
    if Toggles.Fly and ToggleOn("Fly") and R then
        FlyBody.Parent = R
        FlyBody.Velocity = FlyDir() * ((Options.FlySpeed and Options.FlySpeed.Value) or 50)
    elseif FlyBody.Parent then
        FlyBody.Velocity = Vector3.zero
        FlyBody.Parent = nil
    end
end))

TrackConn(Services.RunService.Stepped:Connect(function()
    if Toggles.Noclip and ToggleOn("Noclip") and LocalPlayer.Character then
        for _, P in ipairs(LocalPlayer.Character:GetDescendants()) do
            if P:IsA("BasePart") and P.CanCollide then
                P.CanCollide = false
            end
        end
    end
end))

-- // Misc: World //
Groupboxes.Misc_World = Tabs.Misc:AddRightGroupbox("World")
Groupboxes.Misc_World:AddToggle("Fullbright", { Text = "Fullbright", Default = false })
Groupboxes.Misc_World:AddToggle("NoFog", { Text = "No Fog", Default = false })

local OldLight = {}
local function ApplyBright(On)
    local L = Services.Lighting
    if On then
        if OldLight.B == nil then
            OldLight = { B = L.Brightness, C = L.ClockTime, G = L.GlobalShadows, F = L.FogEnd, A = L.Ambient }
        end
        L.Brightness = 2
        L.ClockTime = 14
        L.GlobalShadows = false
        L.FogEnd = 100000
        L.Ambient = Color3.new(1, 1, 1)
    elseif OldLight.B ~= nil then
        L.Brightness = OldLight.B
        L.ClockTime = OldLight.C
        L.GlobalShadows = OldLight.G
        L.FogEnd = OldLight.F
        L.Ambient = OldLight.A
    end
end
OnChange("Fullbright", function(V) pcall(ApplyBright, V) end)

local OldFog = nil
local function ApplyNoFog(On)
    local L = Services.Lighting
    if On then
        if OldFog == nil then OldFog = L.FogEnd end
        L.FogEnd = 100000
    elseif OldFog ~= nil then
        L.FogEnd = OldFog
    end
end
OnChange("NoFog", function(V) pcall(ApplyNoFog, V) end)

local BrightAcc = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    BrightAcc = BrightAcc + Delta
    if BrightAcc < 2 then return end
    BrightAcc = 0
    if Toggles.Fullbright and ToggleOn("Fullbright") then
        pcall(ApplyBright, true)
    end
    if Toggles.NoFog and ToggleOn("NoFog") then
        pcall(ApplyNoFog, true)
    end
end))

Library:OnUnload(function()
    for _, Conn in ipairs(Connections) do
        pcall(function() Conn:Disconnect() end)
    end
    pcall(function() Abysall.ESPLibrary:Unload() end)
    pcall(function()
        FlyBody.Velocity = Vector3.zero
        FlyBody.Parent = nil
    end)
    pcall(ApplyBright, false)
    pcall(ApplyNoFog, false)
    pcall(function()
        local Char = LocalPlayer.Character
        local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
        if Hum then Hum.WalkSpeed = 16 end
        if Char then
            for _, P in ipairs(Char:GetDescendants()) do
                if P:IsA("BasePart") and P.Name ~= "HumanoidRootPart" then
                    P.CanCollide = true
                end
            end
        end
    end)
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
Abysall.Interface.ApplyAddons(Window, "foundation")
Library:Notify("THE FOUNDATION destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")
