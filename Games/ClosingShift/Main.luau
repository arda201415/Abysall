-- Abysall Hub | Closing Shift (IgnitedFreddy)
-- PlaceId: 118297934142609 | UniverseId: 10767355485
-- Player ESP + Animatronic ESP (tum Workspace taranir; IgnitedFreddy /
-- IgnitedBonnie / IgnitedBonnieLocal otomatik yakalanir) + ESP ayarlari.

local LoadStart = tick()
if not Abysall or not Abysall.Interface then
    warn("[Abysall] ClosingShift dogrudan calistirildi: once ana Loader (README loadstring) calistir.")
    return
end
Abysall.SavePath = "ClosingShift"

local Library = Abysall.Interface.Library
local Toggles = Library.Toggles
local Options = Library.Options

-- Linoria OnChanged'i kayit aninda hemen cagirir; menu kurulurken bunu bastir.
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

local Connections = {}
local function TrackConn(Conn)
    table.insert(Connections, Conn)
    return Conn
end

local Window = Library:CreateWindow({
    Title = "Abysall Hub | Closing Shift",
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
}

-- // Player ESP // ----------------------------------------------------------
local Players = Tabs.Visuals:AddLeftGroupbox("Player ESP")

Players:AddToggle("PlayerESP", { Text = "Player ESP", Default = false })
Toggles.PlayerESP:AddColorPicker("PlayerESPColor", {
    Text = "ESP Color", Default = Color3.fromRGB(255, 60, 60), Transparency = 0,
})
Players:AddToggle("ESPShowHealth", {
    Text = "Show Health", Default = true, Tooltip = "Ismin yaninda cani gosterir.",
})

local HealthConns = {}
local function TrackHealth(Player, Char)
    local Old = HealthConns[Char]
    if Old then pcall(function() Old:Disconnect() end); HealthConns[Char] = nil end
    if not (Toggles.ESPShowHealth and ToggleOn("ESPShowHealth")) then
        Abysall.ESPLibrary:UpdateObjectText(Char, Player.Name)
        return
    end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    if not Hum then return end
    local function Refresh()
        if Hum.Parent then
            Abysall.ESPLibrary:UpdateObjectText(Char, Player.Name .. " [" .. math.floor(Hum.Health + 0.5) .. "]")
        end
    end
    Refresh()
    local Conn = Hum.HealthChanged:Connect(Refresh)
    HealthConns[Char] = Conn
    TrackConn(Conn)
    Char.Destroying:Once(function()
        local C = HealthConns[Char]
        if C then pcall(function() C:Disconnect() end); HealthConns[Char] = nil end
    end)
end

local function AddPlayerESP(Player)
    local Char = Player.Character
    if not Char or Player == LocalPlayer then return end
    pcall(function()
        Abysall.ESPLibrary:AddESP({
            Object = Char, Text = Player.Name,
            Color = Options.PlayerESPColor.Value, Player = Player,
        })
        TrackHealth(Player, Char)
        Char.Destroying:Once(function()
            if Abysall and Abysall.ESPLibrary then Abysall.ESPLibrary:RemoveESP(Char) end
        end)
    end)
end

OnChange("ESPShowHealth", function()
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character and ToggleOn("PlayerESP") then
            TrackHealth(Player, Player.Character)
        end
    end
end)

OnChange("PlayerESP", function(Value)
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            if Value and Player.Character then
                AddPlayerESP(Player)
            elseif Player.Character then
                Abysall.ESPLibrary:RemoveESP(Player.Character)
            end
        end
    end
end)

BindChange(Options.PlayerESPColor, function(Value)
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character then
            Abysall.ESPLibrary:UpdateObjectColor(Player.Character, Value)
        end
    end
end)

local function HookPlayer(Player)
    if Player == LocalPlayer then return end
    TrackConn(Player.CharacterAdded:Connect(function(Char)
        task.wait(0.6)
        if ToggleOn("PlayerESP") then AddPlayerESP(Player) end
    end))
    TrackConn(Player.CharacterRemoving:Connect(function(Char)
        if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Char) end) end
    end))
end

TrackConn(Services.Players.PlayerAdded:Connect(HookPlayer))
for _, Player in pairs(Services.Players:GetPlayers()) do
    HookPlayer(Player)
    if Player ~= LocalPlayer and Player.Character and ToggleOn("PlayerESP") then AddPlayerESP(Player) end
end

-- // Animatronic ESP // -----------------------------------------------------
-- Tek secenek altinda: IgnitedFreddy, IgnitedBonnie, IgnitedBonnieLocal ve
-- Humanoid iceren tum NPC'ler. Ismi "Ignited" gecen modeller de yakalanir.
-- Isaretleme icin TUM Workspace taranir (streaming ile gelenler dahil).
local Entities = Tabs.Visuals:AddRightGroupbox("Animatronic ESP")

Entities:AddToggle("EntityESP", { Text = "Animatronic ESP", Default = false })
Toggles.EntityESP:AddColorPicker("EntityESPColor", {
    Text = "ESP Color", Default = Color3.fromRGB(255, 170, 0), Transparency = 0,
})
Entities:AddInput("EntityFilter", {
    Text = "Name Filter", Default = "", Placeholder = "orn: Ignited, Bonnie (bos = hepsi)",
    Tooltip = "Isminde bu metin gecen animatronikleri gosterir. Virgulle ayir. Bos = hepsi.",
})
Entities:AddLabel("Tum Workspace taranir: IgnitedFreddy / IgnitedBonnie / IgnitedBonnieLocal + NPC'ler.", true)

local ESPObjects = {} -- [Model] = true

local function MatchesFilter(Object)
    local Raw = Options.EntityFilter and tostring(Options.EntityFilter.Value or "") or ""
    if Raw == "" then return true end
    local Name = string.lower(Object.Name)
    for Token in string.gmatch(Raw, "[^,;%s]+") do
        if string.find(Name, string.lower(Token), 1, true) then return true end
    end
    return false
end

local KnownNames = {
    IgnitedFreddy = true, IgnitedBonnie = true, IgnitedBonnieLocal = true,
    Freddy = true, Bonnie = true, Chica = true, Foxy = true,
    GoldenFreddy = true, Fredbear = true, Puppet = true,
}

-- ESP'de gorunmemesi gereken nesneler (sahne/dekor)
local Blacklist = {
    ShowStage = true, Door = true, SecondStage = true, TableSeat = true,
}

local function IsAnimatronic(Object)
    if not Object or not Object.Parent then return false end
    if not Object:IsA("Model") then return false end
    if Blacklist[Object.Name] then return false end
    if Services.Players:GetPlayerFromCharacter(Object) then return false end
    if Object == LocalPlayer.Character then return false end
    if Object:FindFirstChildOfClass("Humanoid") then return true end
    if KnownNames[Object.Name] then return true end
    -- "Ignited" iceren (IgnitedFreddy, IgnitedBonnie, IgnitedBonnieLocal ...) veya
    -- "*Stage" altindaki modeller
    if string.find(Object.Name, "Ignited", 1, true) then return true end
    local Parent = Object.Parent
    if Parent and string.find(string.lower(Parent.Name), "stage", 1, true) then return true end
    return false
end

local function AddEntity(Model)
    if ESPObjects[Model] then return end
    ESPObjects[Model] = true
    pcall(function()
        local Hum = Model:FindFirstChildOfClass("Humanoid")
        local Text = Model.Name
        if Hum then Text = Model.Name .. " [" .. math.floor(Hum.Health + 0.5) .. "]" end
        Abysall.ESPLibrary:AddESP({ Object = Model, Text = Text, Color = Options.EntityESPColor.Value })
        Model.Destroying:Once(function()
            ESPObjects[Model] = nil
            if Abysall and Abysall.ESPLibrary then Abysall.ESPLibrary:RemoveESP(Model) end
        end)
    end)
end

local function RemoveEntity(Model)
    ESPObjects[Model] = nil
    if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Model) end) end
end

local function ScanEntities()
    if not ToggleOn("EntityESP") then return end
    local Workspace = Services.Workspace
    for _, Object in ipairs(Workspace:GetDescendants()) do
        if IsAnimatronic(Object) and MatchesFilter(Object) then
            AddEntity(Object)
        end
    end
    for Model in pairs(ESPObjects) do
        if not Model.Parent then RemoveEntity(Model) end
    end
end

OnChange("EntityESP", function(Value)
    if Value then
        ScanEntities()
    else
        for Model in pairs(ESPObjects) do RemoveEntity(Model) end
    end
end)

BindChange(Options.EntityESPColor, function(Value)
    for Model in pairs(ESPObjects) do
        Abysall.ESPLibrary:UpdateObjectColor(Model, Value)
    end
end)

BindChange(Options.EntityFilter, function()
    if not ToggleOn("EntityESP") then return end
    for Model in pairs(ESPObjects) do RemoveEntity(Model) end
    ScanEntities()
end)

-- Anlik yakalama: yeni eklenen animatronikler (streaming / spawn)
TrackConn(Services.Workspace.DescendantAdded:Connect(function(Object)
    if ToggleOn("EntityESP") and IsAnimatronic(Object) and MatchesFilter(Object) then
        AddEntity(Object)
    end
end))

-- Periyodik tam tarama: cozulmemis/gecikmis nesneler icin
local ScanAccum = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if not ToggleOn("EntityESP") then return end
    ScanAccum += Delta
    if ScanAccum < 1 then return end
    ScanAccum = 0
    ScanEntities()
end))

-- // ESP Settings // --------------------------------------------------------
local Settings = Tabs.Visuals:AddRightGroupbox("ESP Settings")
Settings:AddToggle("ESPShowDistance", { Text = "Show Distance", Default = true })
Settings:AddToggle("ESPTracers", { Text = "Tracers", Default = false })
Settings:AddToggle("ESPArrows", { Text = "Arrows", Default = false })
OnChange("ESPShowDistance", function(V) Abysall.ESPLibrary:SetShowDistance(V) end)
OnChange("ESPTracers", function(V) Abysall.ESPLibrary:SetTracers(V) end)
OnChange("ESPArrows", function(V) Abysall.ESPLibrary:SetArrows(V) end)

-- // Unload // --------------------------------------------------------------
Library:OnUnload(function()
    for _, Conn in ipairs(Connections) do
        pcall(function() Conn:Disconnect() end)
    end
    for Model in pairs(ESPObjects) do
        if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Model) end) end
    end
    ESPObjects = {}
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
Abysall.Interface.ApplyAddons(Window, "closingshift")
Library:Notify("Closing Shift destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")
