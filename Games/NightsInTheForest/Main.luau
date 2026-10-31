-- 99 Nights in the Forest: readable reconstruction of the supplied local script.
local Session = Abysall
if not Session or not Session.Interface then warn("[Abysall] Run the main Loader first."); return end
Session.SavePath = "NightsInTheForest"
local Library = Session.Interface.Library
local Toggles, Options = Library.Toggles, Library.Options
local Services = setmetatable({}, { __index = function(Self, Name)
    local Service = game:GetService(Name)
    local Clone = Session.Environment and Session.Environment.cloneref
    if Clone then Service = Clone(Service) end
    rawset(Self, Name, Service)
    return Service
end })
local BaseUrl = "https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/Games/NightsInTheForest/"
local Sources = Session.FetchModules({ Catalog = BaseUrl .. "Catalog.luau", Controller = BaseUrl .. "Controller.luau" },
    "Preparing 99 Nights in the Forest", 0.88, 0.9)
local Catalog = Session.RunModule(Sources.Catalog, "NightsInTheForest/Catalog")
local MakeController = Session.RunModule(Sources.Controller, "NightsInTheForest/Controller")
local Window = Library:CreateWindow({
    Title = "Abysall Hub | 99 Nights in the Forest", Footer = "dsc.gg/abysallhub",
    AutoShow = true, Center = true, NotifySide = "Right", ShowCustomCursor = false,
    TabPadding = 3, MenuFadeTime = 0, CornerRadius = 2,
})
Session.Interface.ApplyInfoTab(Window)
local Main = Window:AddTab("Main", "trees")
local Teleports = Main:AddLeftGroupbox("Teleports")
local Controller
local function Teleport(Frame)
    local Ok, Error = Controller:Teleport(Frame)
    if not Ok then Library:Notify(Error) end
end
Teleports:AddButton("Teleport to Campfire", function() Teleport(Catalog.Campfire) end)
Teleports:AddButton("Teleport to Grinder", function() Teleport(Catalog.Grinder) end)
Teleports:AddDropdown("NightTeleportItem", {
    Text = "Item or NPC", Values = Catalog.Items, Default = Catalog.Items[1], Searchable = true,
})
Teleports:AddButton("Teleport to Selected", function()
    local Ok, Error = Controller:TeleportItem(Options.NightTeleportItem.Value)
    if not Ok then Library:Notify(Error) end
end)
Teleports:AddLabel("Uses the nearest loaded match outside the camp radius.", true)
local Visuals = Main:AddRightGroupbox("Visuals")
Visuals:AddToggle("NightItemESP", { Text = "Item ESP", Default = false })
Visuals:AddToggle("NightNPCESP", { Text = "NPC ESP", Default = false })
local Automation = Main:AddLeftGroupbox("Small Trees")
Automation:AddToggle("NightTreeFarm", {
    Text = "Auto Tree Farm", Default = false,
    Tooltip = "Moves to small trees outside camp and clicks every 0.2s. Equip an axe first. Skips a tree after 12s.",
})
local FarmStatus = Automation:AddLabel("Tree farm is off.", true)
local Movement = Main:AddRightGroupbox("Aim and Movement")
Movement:AddToggle("NightAimbot", {
    Text = "Aimbot (Right Click)", Default = false,
    Tooltip = "Aims at the closest supported NPC head inside a 100px circle while holding right click.",
})
Movement:AddToggle("NightFly", { Text = "Fly", Default = false })
Toggles.NightFly:AddKeyPicker("NightFlyKey", { Text = "Fly", Default = "Q", Mode = "Toggle", SyncToggleState = true })
Movement:AddLabel("Fly: WASD, Space up, Left Shift down. Speed: 60.", true)
local Ids = { ItemESP = "NightItemESP", NPCESP = "NightNPCESP", AutoTree = "NightTreeFarm", Aimbot = "NightAimbot", Fly = "NightFly" }
local AimGui, Circle
local function DrawAim(Visible, Position, Radius)
    if not Visible then if Circle then Circle.Visible = false end; return end
    if not Circle then
        local Parent = Library.ScreenGui and Library.ScreenGui.Parent
        if not Parent then return end
        AimGui = Instance.new("ScreenGui")
        AimGui.Name, AimGui.ResetOnSpawn, AimGui.IgnoreGuiInset = "Abysall99Aim", false, true
        AimGui.DisplayOrder = 2147483646
        AimGui.Parent = Parent
        Circle = Instance.new("Frame")
        Circle.BackgroundTransparency = 1
        Circle.AnchorPoint = Vector2.new(0.5, 0.5)
        Circle.Parent = AimGui
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(1, 0)
        Corner.Parent = Circle
        local Stroke = Instance.new("UIStroke")
        Stroke.Color, Stroke.Thickness, Stroke.Transparency = Color3.fromRGB(128, 255, 0), 1, 0.5
        Stroke.Parent = Circle
    end
    Circle.Size, Circle.Position = UDim2.fromOffset(Radius * 2, Radius * 2), UDim2.fromOffset(Position.X, Position.Y)
    Circle.Visible = true
end
local function Click()
    local NativeClick = Session.Environment and Session.Environment.mouse1click
    if type(NativeClick) == "function" then return pcall(NativeClick) end
    local Input = Services.VirtualInputManager
    local Pressed, Error = pcall(function() Input:SendMouseButtonEvent(0, 0, 0, true, game, 0) end)
    -- Release even if a press fails; do not leave a simulated button held down.
    local Released, ReleaseError = pcall(function() Input:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
    return Pressed and Released, Error or ReleaseError
end
Controller = MakeController({
    Services = Services, Player = Services.Players.LocalPlayer, Catalog = Catalog, ESP = Session.ESPLibrary,
    Click = Click, DrawAim = DrawAim, Status = function(Text) FarmStatus:SetText(Text) end,
    Changed = function(Feature, Value)
        local Toggle = Toggles[Ids[Feature]]
        if Toggle and Toggle.Value ~= Value then Toggle:SetValue(Value) end
    end,
    Error = function(Feature, Error) Library:Notify(Feature .. " stopped: " .. Error) end,
})
Session.NightsInTheForest = Controller
for Feature, Id in pairs(Ids) do
    local Registering = true
    Toggles[Id]:OnChanged(function(Value) if not Registering then Controller:Set(Feature, Value) end end)
    Registering = false
    if Toggles[Id].Value then Controller:Set(Feature, true) end
end
Library:OnUnload(function()
    Controller:Destroy()
    if AimGui then AimGui:Destroy() end
    if Session.ESPLibrary then pcall(function() Session.ESPLibrary:Unload() end) end
    for _, Disabler in ipairs(Session.AddonDisablers or {}) do
        if type(Disabler.Fn) == "function" then pcall(Disabler.Fn) end
    end
    Session.AddonDisablers = nil
    if getgenv().Abysall == Session then
        getgenv().abysall, getgenv().mspaint, getgenv().Abysall = nil, nil, nil
    end
end)
Session.Interface.ApplySettingsTab(Window)
Session.Interface.ApplyAddons(Window, "nightsintheforest")
Library:Notify("99 Nights in the Forest loaded.")
