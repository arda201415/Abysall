-- Abysall Hub | Steal An Egg
-- PlaceId: 107778070777162
-- Adapted from the statically recovered behavior documented in Research/StealAnEgg.md.
local LoadStart = tick()
local Session = Abysall
if not Session or not Session.Interface then
    warn("[Abysall] Run the main Loader before the Steal An Egg module.")
    return
end
Session.SavePath = "StealAnEgg"

local Library = Session.Interface.Library
local Toggles, Options = Library.Toggles, Library.Options
local Services = setmetatable({}, {
    __index = function(Self, Name)
        local Service = game:GetService(Name)
        local CloneReference = Session.Environment and Session.Environment.cloneref
        if CloneReference then Service = CloneReference(Service) end
        rawset(Self, Name, Service)
        return Service
    end,
})
local LocalPlayer = Services.Players.LocalPlayer
local Unloaded = false
local Connections = {}
local Speeds = setmetatable({}, { __mode = "k" })
local Prompts = setmetatable({}, { __mode = "k" })
local PausedConnections = {}
local GetConnections = Session.Environment and Session.Environment.getconnections
local CorrectionError = false
local CorrectionElapsed = 0
local NetworkStatus
local CorrectionNames = {
    ["ClientCharacter: CorrectionStarted"] = true,
    ["ClientCharacter: Ready"] = true,
    ["ClientCharacter: RequestCharacterReset"] = true,
}

local function ToggleOn(Name)
    return not Unloaded and Toggles[Name] ~= nil and Toggles[Name].Value == true
end

local function OnChange(Control, Callback)
    -- Linoria calls OnChanged immediately when registering a listener.
    local Registering = true
    Control:OnChanged(function(...)
        if not Registering and not Unloaded then Callback(...) end
    end)
    Registering = false
end

local function Connect(Signal, Callback)
    local Connection = Signal:Connect(function(...)
        if not Unloaded then Callback(...) end
    end)
    table.insert(Connections, Connection)
end

local function GetHumanoid()
    local Character = LocalPlayer.Character
    return Character and Character:FindFirstChildOfClass("Humanoid")
end

local function ApplySpeed()
    if not ToggleOn("EggLoopWalkSpeed") then return end
    local Humanoid = GetHumanoid()
    if not Humanoid or Humanoid.Health <= 0 then return end
    if Speeds[Humanoid] == nil then Speeds[Humanoid] = Humanoid.WalkSpeed end
    local Speed = math.clamp(tonumber(Options.EggWalkSpeed.Value) or 16, 16, 1000)
    if Humanoid.WalkSpeed ~= Speed then Humanoid.WalkSpeed = Speed end
end

local function RestoreSpeeds()
    for Humanoid, Speed in pairs(Speeds) do
        pcall(function() Humanoid.WalkSpeed = Speed end)
    end
    table.clear(Speeds)
end

local function ApplyPrompt(Object)
    if not ToggleOn("EggInstantPrompts") or not Object:IsA("ProximityPrompt") then return end
    if Prompts[Object] == nil then Prompts[Object] = Object.HoldDuration end
    Object.HoldDuration = 0
end

local function RestorePrompts()
    for Prompt, Duration in pairs(Prompts) do
        pcall(function() Prompt.HoldDuration = Duration end)
    end
    table.clear(Prompts)
end

local function GetNetwork()
    return Services.ReplicatedStorage:FindFirstChild("Network")
end

local function UpdateNetworkStatus()
    if not NetworkStatus then return end
    local Count = 0
    for _ in pairs(PausedConnections) do Count += 1 end
    if type(GetConnections) ~= "function" or CorrectionError then
        NetworkStatus:SetText("Client listener control is unavailable in this executor.")
    else
        NetworkStatus:SetText(GetNetwork()
            and ("Client correction listeners paused: " .. Count)
            or "Waiting for the game's Network folder...")
    end
end

local function PauseCorrection(Object)
    if not ToggleOn("EggBlockClientCorrections") or not CorrectionNames[Object.Name]
        or Object.Parent ~= GetNetwork() then return end
    if not (Object:IsA("RemoteEvent") or Object:IsA("UnreliableRemoteEvent")) then return end
    local Ok, Listeners = pcall(GetConnections, Object.OnClientEvent)
    if not Ok or type(Listeners) ~= "table" then CorrectionError = true; return end
    for _, Listener in ipairs(Listeners) do
        local Paused = pcall(function()
            if type(Listener.Enabled) ~= "boolean" or type(Listener.Disable) ~= "function" or type(Listener.Enable) ~= "function" then
                error("Unsupported client listener")
            end
            if Listener.Enabled then
                Listener:Disable()
                PausedConnections[Listener] = true
            end
        end)
        if not Paused then CorrectionError = true end
    end
end

local function ApplyCorrections()
    local Network = GetNetwork()
    if Network then
        for _, Object in ipairs(Network:GetChildren()) do PauseCorrection(Object) end
    end
    UpdateNetworkStatus()
end

local function RestoreCorrections()
    for Listener in pairs(PausedConnections) do
        pcall(function() Listener:Enable() end)
    end
    table.clear(PausedConnections)
    UpdateNetworkStatus()
end

local Window = Library:CreateWindow({
    Title = "Abysall Hub | Steal An Egg",
    Footer = "dsc.gg/abysallhub",
    NotifySide = "Right",
    ShowCustomCursor = false,
    AutoShow = true,
    Center = true,
    TabPadding = 3,
    MenuFadeTime = 0,
    CornerRadius = 2,
})
Session.Interface.ApplyInfoTab(Window)
local Main = Window:AddTab("Main", "egg")
local Movement = Main:AddLeftGroupbox("Movement")
Movement:AddToggle("EggLoopWalkSpeed", {
    Text = "Loop WalkSpeed", Default = false,
    Tooltip = "Keeps your current character at the selected walking speed.",
})
Movement:AddSlider("EggWalkSpeed", {
    Text = "WalkSpeed", Default = 16, Min = 16, Max = 1000, Rounding = 0,
})
OnChange(Toggles.EggLoopWalkSpeed, function(Value)
    if Value then ApplySpeed() else RestoreSpeeds() end
end)
OnChange(Options.EggWalkSpeed, ApplySpeed)

local Interactions = Main:AddLeftGroupbox("Interactions")
Interactions:AddToggle("EggInstantPrompts", {
    Text = "Instant Prompts", Default = false,
    Tooltip = "Removes the local hold duration from existing and newly loaded prompts.",
})
OnChange(Toggles.EggInstantPrompts, function(Value)
    if Value then
        for _, Object in ipairs(Services.Workspace:GetDescendants()) do ApplyPrompt(Object) end
    else
        RestorePrompts()
    end
end)

local Network = Main:AddRightGroupbox("Client Corrections")
Network:AddToggle("EggBlockClientCorrections", {
    Text = "Block Client Corrections", Default = false,
    Tooltip = "Pauses listeners on the original script's three client correction events. Requires getconnections. May interrupt character synchronization; turning this off restores paused listeners.",
})
Network:AddLabel("Changes the client only; server checks can still apply.", true)
NetworkStatus = Network:AddLabel("", true)
Network:AddDivider()
Network:AddButton("Reset Character", function()
    local Humanoid = GetHumanoid()
    if Humanoid and Humanoid.Health > 0 then
        Humanoid.Health = 0
    else
        Library:Notify("Your character is not ready to reset.")
    end
end)
OnChange(Toggles.EggBlockClientCorrections, function(Value)
    if Value then
        CorrectionError = false
        if type(GetConnections) == "function" then ApplyCorrections() end
        if type(GetConnections) ~= "function" or CorrectionError then
            Toggles.EggBlockClientCorrections:SetValue(false)
            Library:Notify("Client correction control is unavailable in this executor.")
        end
    else
        RestoreCorrections()
    end
end)
UpdateNetworkStatus()

Connect(Services.RunService.Heartbeat, function(Delta)
    ApplySpeed()
    if not ToggleOn("EggBlockClientCorrections") then CorrectionElapsed = 0; return end
    CorrectionElapsed += Delta
    if CorrectionElapsed >= 1 then
        CorrectionElapsed = 0
        -- The game may connect a listener after its RemoteEvent was replicated.
        ApplyCorrections()
        if CorrectionError then
            Toggles.EggBlockClientCorrections:SetValue(false)
            Library:Notify("Client correction control stopped: listener access failed.")
        end
    end
end)
Connect(Services.Workspace.DescendantAdded, ApplyPrompt)
Connect(Services.ReplicatedStorage.DescendantAdded, function(Object)
    if Object.Name == "Network" and Object.Parent == Services.ReplicatedStorage then
        ApplyCorrections()
    elseif Object.Parent == GetNetwork() then
        PauseCorrection(Object)
        UpdateNetworkStatus()
    end
end)
Connect(Services.ReplicatedStorage.ChildRemoved, function(Object)
    if Object.Name == "Network" then UpdateNetworkStatus() end
end)

Library:OnUnload(function()
    Unloaded = true
    for _, Connection in ipairs(Connections) do pcall(function() Connection:Disconnect() end) end
    RestoreSpeeds()
    RestorePrompts()
    RestoreCorrections()
    if Session.ESPLibrary then pcall(function() Session.ESPLibrary:Unload() end) end
    for _, Disabler in ipairs(Session.AddonDisablers or {}) do
        if type(Disabler.Fn) == "function" then pcall(Disabler.Fn) end
    end
    Session.AddonDisablers = nil
    if getgenv().Abysall == Session then
        getgenv().abysall = nil
        getgenv().mspaint = nil
        getgenv().Abysall = nil
    end
end)

Session.Interface.ApplySettingsTab(Window)
Session.Interface.ApplyAddons(Window, "stealanegg")
Library:Notify("Steal An Egg loaded (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")
