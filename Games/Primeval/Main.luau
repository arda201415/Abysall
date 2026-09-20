-- Abysall Hub | Primeval Earth (Dinosaur Survival, TEA - Studios)
-- PlaceId: 10696301650
-- Zone claim otomasyonu: en yakindan baslayarak her zone'un ortasina
-- isinlan, 10 sn bekle, sonrakine gec, bitince "done" bildir.

local LoadStart = tick()
Abysall.SavePath = "Primeval"

local Library = Abysall.Interface.Library
local SaveManager = Abysall.Interface.SaveManager
local ThemeManager = Abysall.Interface.ThemeManager

local Toggles = Library.Toggles
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

local Connections = {}
local function TrackConn(Conn)
    table.insert(Connections, Conn)
    return Conn
end

local Window = Library:CreateWindow({
    Title = "Abysall Hub | Primeval Earth",
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
    Zones = Window:AddTab("Zones", "flag"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Misc = Window:AddTab("Misc", "house"),
}

local Groupboxes = {}

-- // Zone tarama //
local Zones = {}

local function PlayerPos()
    local Char = LocalPlayer.Character
    local HRP = Char and Char:FindFirstChild("HumanoidRootPart")
    if HRP then return HRP.Position end
    return Vector3.zero
end

local function ZoneCenter(Zone)
    local Ok, CF = pcall(function() return Zone:GetBoundingBox() end)
    if Ok and CF then return CF end
    local PP = Zone.PrimaryPart
    if PP then return PP.CFrame end
    return nil
end

local function FindZones()
    local Found = {}
    for _, Desc in ipairs(Services.Workspace:GetDescendants()) do
        if Desc:IsA("Model") and Desc.Name == "Zone" then
            table.insert(Found, Desc)
        end
    end
    local From = PlayerPos()
    table.sort(Found, function(A, B)
        local CA, CB = ZoneCenter(A), ZoneCenter(B)
        if CA and CB then
            return (CA.Position - From).Magnitude < (CB.Position - From).Magnitude
        end
        return tostring(A:GetFullName()) < tostring(B:GetFullName())
    end)
    Zones = Found
    return Found
end

local RefreshZoneESP
Groupboxes.Zones_Scan = Tabs.Zones:AddLeftGroupbox("Zones")
Groupboxes.Zones_Scan:AddButton({
    Text = "Scan Zones",
    DoubleClick = false,
    Func = function()
        local Found = FindZones()
        Library:Notify(#Found .. " zone bulundu.")
        if Toggles.ZoneESP and Toggles.ZoneESP.Value then
            RefreshZoneESP()
        end
    end
})

-- // Zone ESP //
RefreshZoneESP = function()
    for _, Z in ipairs(Zones) do
        pcall(function() Abysall.ESPLibrary:RemoveESP(Z) end)
    end
    if Toggles.ZoneESP and Toggles.ZoneESP.Value then
        local Color = Options.ZoneESPColor and Options.ZoneESPColor.Value or Color3.fromRGB(0, 255, 0)
        for _, Z in ipairs(Zones) do
            pcall(function()
                Abysall.ESPLibrary:AddESP({ Object = Z, Text = "Zone", Color = Color })
            end)
        end
    end
end

Groupboxes.Zones_ESP = Tabs.Zones:AddRightGroupbox("Zone ESP")
Groupboxes.Zones_ESP:AddToggle("ZoneESP", {
    Text = "Zone ESP", Default = false, Tooltip = "Tum zone'lari isaretler.",
})
Toggles.ZoneESP:AddColorPicker("ZoneESPColor", {
    Text = "ESP Rengi", Default = Color3.fromRGB(0, 255, 0), Transparency = 0,
})
Toggles.ZoneESP:OnChanged(function() RefreshZoneESP() end)
Options.ZoneESPColor:OnChanged(function()
    if Toggles.ZoneESP.Value then RefreshZoneESP() end
end)

-- // Claim Every Zone //
local Claiming, ClaimStop = false, false

local function AliveRoot()
    local Char = LocalPlayer.Character
    local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
    local HRP = Char and Char:FindFirstChild("HumanoidRootPart")
    if Hum and HRP and Hum.Health > 0 then
        return HRP
    end
    return nil
end

local function ClaimEveryZone()
    if Claiming then
        Library:Notify("Zaten calisiyor.")
        return
    end
    local Found = FindZones()
    if #Found == 0 then
        Library:Notify("Zone bulunamadi, once Scan dene.")
        return
    end
    Claiming = true
    ClaimStop = false
    Library:Notify("Claim basladi: " .. #Found .. " zone.")
    task.spawn(function()
        for I, Zone in ipairs(Found) do
            if ClaimStop then
                Library:Notify("Durduruldu.")
                break
            end
            local HRP = AliveRoot()
            if not HRP then
                Library:Notify("Oldun/dustun, durdu.")
                break
            end
            local Center = ZoneCenter(Zone)
            if Center then
                pcall(function()
                    HRP.CFrame = Center + Vector3.new(0, 5, 0)
                end)
                Library:Notify("Zone " .. I .. "/" .. #Found)
            else
                Library:Notify("Zone " .. I .. " merkezi yok, atlandi.")
            end
            for _ = 1, 10 do
                if ClaimStop then break end
                task.wait(1)
            end
        end
        Claiming = false
        if not ClaimStop then
            Library:Notify("done")
        end
    end)
end

Groupboxes.Zones_Claim = Tabs.Zones:AddLeftGroupbox("Auto Claim")
Groupboxes.Zones_Claim:AddButton({
    Text = "Claim Every Zone",
    DoubleClick = false,
    Func = function() ClaimEveryZone() end,
})
Groupboxes.Zones_Claim:AddButton({
    Text = "Stop",
    DoubleClick = false,
    Func = function()
        ClaimStop = true
        Library:Notify("Durduruluyor...")
    end,
})
Groupboxes.Zones_Claim:AddLabel("Her zone'da 10 sn bekler.", true)

FindZones()

-- // Misc: hareket //
Groupboxes.Misc_Move = Tabs.Misc:AddLeftGroupbox("Movement")
Groupboxes.Misc_Move:AddSlider("WalkSpeedVal", {
    Text = "WalkSpeed", Min = 16, Max = 200, Default = 16, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("WalkSpeedOn", { Text = "Speed", Default = false })
Groupboxes.Misc_Move:AddToggle("InfiniteJump", {
    Text = "Infinite Jump", Default = false,
})

TrackConn(Services.RunService.RenderStepped:Connect(function()
    if Toggles.WalkSpeedOn and Toggles.WalkSpeedOn.Value and LocalPlayer.Character then
        local Hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Hum then Hum.WalkSpeed = Options.WalkSpeedVal.Value end
    end
end))

TrackConn(Services.UserInputService.JumpRequest:Connect(function()
    if Toggles.InfiniteJump and Toggles.InfiniteJump.Value and LocalPlayer.Character then
        local Hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Hum then Hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

Library:OnUnload(function()
    ClaimStop = true
    Claiming = false
    for _, Conn in ipairs(Connections) do
        pcall(function() Conn:Disconnect() end)
    end
    pcall(function() Abysall.ESPLibrary:Unload() end)
    pcall(function()
        local Char = LocalPlayer.Character
        local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
        if Hum then Hum.WalkSpeed = 16 end
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
Abysall.Interface.ApplyAddons(Window, "primeval")
Library:Notify("Primeval Earth destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")
