local Session = Abysall
if not Session or not Session.Interface then warn("[Abysall] Run the main Loader first."); return end
Session.SavePath = "NightsInTheForest"
local Library = Session.Interface.Library
local Window = Library:CreateWindow({
    Title = "Abysall Hub | 99 Nights in the Forest", Footer = "dsc.gg/abysallhub",
    AutoShow = true, Center = true, ShowCustomCursor = false, NotifySide = "Right", MenuFadeTime = 0,
})
local Home = Session.Interface.ApplyInfoTab(Window)
local Info = Home:AddLeftGroupbox("99 Nights Lobby")
Info:AddLabel("Join a forest match to use ESP, teleports, tree farming, aimbot and flight.", true)
Info:AddLabel("Run the main loader again after joining the match.", true)
Library:OnUnload(function()
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
Session.Interface.ApplyAddons(Window, "nightsintheforest/lobby")
