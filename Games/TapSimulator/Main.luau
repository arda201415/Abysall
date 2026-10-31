-- Abysall Hub | Tap Simulator | PlaceId: 72858262610964
-- Game feature modules: TrustyCoding/slopix-hub (MIT), pinned in upstream.json.
local Session = Abysall
if not Session or not Session.Interface then
    warn("[Abysall] Run the main Loader before the Tap Simulator module.")
    return
end
Session.SavePath = "TapSimulator"
local Library = Session.Interface.Library
local BaseUrl = "https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/Games/TapSimulator/"
local Sources = Session.FetchModules({
    Modules = BaseUrl .. "Modules.luau",
    Bridge = BaseUrl .. "Bridge.luau",
}, "Preparing Tap Simulator", 0.88, 0.9)
local Bundle = Session.RunModule(Sources.Modules, "TapSimulator/Modules")
local MakeBridge = Session.RunModule(Sources.Bridge, "TapSimulator/Bridge")
local Cache, Loading = {}, {}
local function Use(Name)
    if Cache[Name] ~= nil then return Cache[Name] end
    local Factory = Bundle.Factories[Name]
    assert(type(Factory) == "function", "Missing Tap Simulator module: " .. Name)
    assert(not Loading[Name], "Circular Tap Simulator module: " .. Name)
    Loading[Name] = true
    local Ok, Result = pcall(Factory, Use)
    Loading[Name] = nil
    if not Ok then error(Result, 0) end
    Cache[Name] = Result == nil and true or Result
    return Cache[Name]
end

local Env = Use("core/env")
local Life = Use("shared/life")
local Ui = MakeBridge(Session, Life, Env)
Cache["shared/ui"], Cache["core/ui"] = Ui, Ui
local State = { Life = Life, Ui = Ui, Env = Env, Features = {}, Loaded = 0, Phase = "Waiting for game data" }
Session.TapSimulator = State
Life.onCleanup(function() Env.stopped = true end)

-- Requiring the game's DataController can yield. Keep it off the UI/startup path,
-- and retry transient failures instead of caching an unavailable controller forever.
local DataController, DataJob, NextDataAttempt
local Require = Session.Environment and Session.Environment.require or require
function Env.preloadData()
    if DataController then return DataController end
    if DataJob or (NextDataAttempt and os.clock() < NextDataAttempt) or not Life.alive then return nil end
    local Controllers = Env.ReplicatedStorage:FindFirstChild("Controllers")
    local Core = Controllers and Controllers:FindFirstChild("Core")
    local Module = Core and Core:FindFirstChild("DataController")
    if not Module then return nil end
    DataJob = true
    Life.spawn("data:controller", function()
        local Ok, Controller = Env.call(Require, Module)
        if not Life.alive then return end
        DataJob = nil
        if Ok and type(Controller) == "table" then
            DataController = Controller
            Life.errors["data:require"] = nil
        else
            NextDataAttempt = os.clock() + 5
            Life.errors["data:require"] = tostring(Controller)
        end
    end)
    return nil
end
function Env.replica()
    local Controller = Env.preloadData()
    if not Controller then return nil end
    local Ok, Replica = Env.call(function()
        if type(Controller.GetReplica) == "function" then return Controller:GetReplica() end
        if type(Controller.Get) == "function" then return Controller:Get() end
    end)
    return Ok and Replica or nil
end
function Env.data()
    local Replica = Env.replica()
    return Replica and Replica.Data or nil
end

local Window = Library:CreateWindow({
    Title = "Abysall Hub | Tap Simulator",
    Footer = "dsc.gg/abysallhub",
    NotifySide = "Right", ShowCustomCursor = false,
    AutoShow = true, Center = true, TabPadding = 3, MenuFadeTime = 0, CornerRadius = 2,
})
Ui.Window = Window
local Home = Session.Interface.ApplyInfoTab(Window)
Ui.Tabs.Home = Ui.wrapTab(Home)
for _, Tab in ipairs({
    { "Tapping", "hand" }, { "Pets", "egg" }, { "Craft", "hammer" },
    { "Rewards", "gift" }, { "World", "globe" }, { "Minigames", "gamepad-2" },
    { "Halloween", "ghost" },
}) do
    Ui.Tabs[Tab[1]] = Ui.wrapTab(Window:AddTab(Tab[1], Tab[2]))
end
local Runtime = Home:AddRightGroupbox("Tap Simulator Status")
local Status = Runtime:AddLabel("Waiting for the game's player data...", true)
local Problems = Runtime:AddLabel("", true)
Runtime:AddLabel("Feature controls appear as their game modules become ready.", true)

Library:OnUnload(function()
    Ui.stopAll()
    Ui.Ready = false
    Life.shutdown()
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

Life.loop("abysall:status", 1, function()
    Status:SetText(State.Phase .. string.format(" (%d/%d modules)", State.Loaded, #Bundle.Features))
    local Messages = {}
    for Name, Error in pairs(Life.errors) do
        if Name ~= "abysall:status" then
            table.insert(Messages, Name .. ": " .. (tostring(Error):match("^[^\n]+") or "unavailable"))
        end
    end
    table.sort(Messages)
    local Extra = math.max(0, #Messages - 4)
    while #Messages > 4 do table.remove(Messages) end
    if Extra > 0 then table.insert(Messages, Extra .. " more messages") end
    Problems:SetText(table.concat(Messages, "\n"))
end)

Life.spawn("abysall:initialize", function()
    while Life.alive do
        local Data = Env.data()
        if type(Data) == "table" and type(Data.Currencies) == "table"
            and Env.ReplicatedStorage:FindFirstChild("RemoteServices") then break end
        Life.wait(0.5)
    end
    if not Life.alive then return end
    State.Phase = "Building feature controls"
    for _, Name in ipairs(Bundle.Features) do
        if not Life.alive then return end
        local Ok, Result = Life.call("load:" .. Name, Use, Name)
        if Ok then
            State.Features[Name] = Result
            State.Loaded += 1
        else
            warn("[Abysall Tap Simulator] " .. Name .. ": " .. tostring(Result))
        end
    end
    if not Life.alive then return end
    -- The native game auto-clicker is also stopped by the shared Stop All button.
    Ui.automation("AutoClicker", true)
    State.Phase = "Loading saved settings"
    Session.Interface.ApplySettingsTab(Window)
    if not Life.alive then return end
    Session.Interface.ApplyAddons(Window, "tapsimulator")
    Ui.activate()
    local Rewards = State.Features["features/rewards"]
    if Rewards and type(Rewards.afterLoad) == "function" then
        Life.call("rewards:after-load", Rewards.afterLoad)
    end
    State.Phase = State.Loaded == #Bundle.Features and "Ready" or "Ready with module errors"
    Library:Notify("Tap Simulator ready: " .. State.Loaded .. "/" .. #Bundle.Features .. " feature modules.")
end)
