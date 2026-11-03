-- Fake an Egg: reconstructed from the supplied local script, without its external UI/key flow.
local Session = Abysall
if not Session or not Session.Interface then warn("[Abysall] Run the main Loader first."); return end
Session.SavePath = "FakeAnEgg"
local Library = Session.Interface.Library
local Toggles, Options = Library.Toggles, Library.Options
local Services = setmetatable({}, { __index = function(Self, Name)
    local Service = game:GetService(Name)
    local Clone = Session.Environment and Session.Environment.cloneref
    if Clone then Service = Clone(Service) end
    rawset(Self, Name, Service)
    return Service
end })
local BaseUrl = "https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/Games/FakeAnEgg/"
local Sources = Session.FetchModules({ Catalog = BaseUrl .. "Catalog.luau", Controller = BaseUrl .. "Controller.luau" },
    "Preparing Fake an Egg", 0.88, 0.9)
local Catalog = Session.RunModule(Sources.Catalog, "FakeAnEgg/Catalog")
local MakeController = Session.RunModule(Sources.Controller, "FakeAnEgg/Controller")
local Window = Library:CreateWindow({
    Title = "Abysall Hub | Fake an Egg", Footer = "dsc.gg/abysallhub",
    AutoShow = true, Center = true, NotifySide = "Right", ShowCustomCursor = false,
    TabPadding = 3, MenuFadeTime = 0, CornerRadius = 2,
})
Session.Interface.ApplyInfoTab(Window)
local Main = Window:AddTab("Main", "egg")
local Automation = Main:AddLeftGroupbox("Automation")
local Status = {}
local Controls = {
    { "AutoHatch", "FakeEggAutoHatch", "Auto Hatch", "Opens slots 1 through 20 in order, every 0.3 seconds." },
    { "AutoRebirth", "FakeEggAutoRebirth", "Auto Rebirth", "Requests a rebirth every second." },
    { "AutoSell", "FakeEggAutoSell", "Auto Sell All", "Sells Pets every second." },
}
for _, Entry in ipairs(Controls) do
    Automation:AddToggle(Entry[2], { Text = Entry[3], Default = false, Tooltip = Entry[4] })
    Status[Entry[1]] = Automation:AddLabel("Off", true)
end
local Steal = Main:AddRightGroupbox("Auto Steal")
Steal:AddDropdown("FakeEggRarities", {
    Text = "Rarities", Values = Catalog.Rarities, Multi = true, AllowNull = true, Default = {},
})
Steal:AddToggle("FakeEggAutoSteal", {
    Text = "Auto Steal", Default = false,
    Tooltip = "Moves to a matching egg, triggers its prompt twice and returns to your Collect point.",
})
Steal:AddLabel("Select rarities first. Auto Steal moves your character.", true)
Status.AutoSteal = Steal:AddLabel("Off", true)
local Ids = { AutoHatch = "FakeEggAutoHatch", AutoRebirth = "FakeEggAutoRebirth", AutoSell = "FakeEggAutoSell", AutoSteal = "FakeEggAutoSteal" }
local FirePrompt = Session.Environment and Session.Environment.fireproximityprompt
local Controller = MakeController({
    Catalog = Catalog, Services = Services, Player = Services.Players.LocalPlayer, FirePrompt = FirePrompt,
    Status = function(Feature, Text) Status[Feature]:SetText(Text) end,
    Changed = function(Feature, Value)
        if Toggles[Ids[Feature]].Value ~= Value then Toggles[Ids[Feature]]:SetValue(Value) end
    end,
    Error = function(Feature, Error) Library:Notify(Feature .. " stopped: " .. Error) end,
})
Session.FakeAnEgg = Controller
local function BindChange(Control, Callback)
    local Registering = true
    Control:OnChanged(function(...) if not Registering then Callback(...) end end)
    Registering = false
end
BindChange(Options.FakeEggRarities, function(Value) Controller:SetRarities(Value) end)
Controller:SetRarities(Options.FakeEggRarities.Value)
for Feature, Id in pairs(Ids) do
    local function Changed(Value)
        local Ok, Error = Controller:Set(Feature, Value)
        if not Ok then
            if Toggles[Id].Value then Toggles[Id]:SetValue(false) end
            Library:Notify(Error)
        end
    end
    BindChange(Toggles[Id], Changed)
    if Toggles[Id].Value then Changed(true) end
end
Library:OnUnload(function()
    Controller:Destroy()
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
Session.Interface.ApplyAddons(Window, "fakeanegg")
Library:Notify("Fake an Egg loaded.")
