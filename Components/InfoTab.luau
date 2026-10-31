return function(Window)
    local LatestChangelog = {
        "27/9/2026",
        "<font color=\"rgb(0, 255, 0)\">+ Added Build the Pyramid support (Auto Block, Bench, Gifts, ESP)</font>",
    }

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

    local Library = Abysall.Interface.Library
    local SaveManager = Abysall.Interface.SaveManager
    local ThemeManager = Abysall.Interface.ThemeManager

    local Toggles = Library.Toggles
    local Options = Library.Options

    local LocalPlayer = Services.Players.LocalPlayer
    local InfoTab = Window:AddTab("Home", "house")
    Abysall.Interface.ApplySupportedGamesTab(InfoTab)

    local User = InfoTab:AddLeftGroupbox("User Info")

    if type(User.AddImage) == "function" then
        -- Roblox resolves this content asynchronously; no thumbnail RPC on startup.
        local Content = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=420&h=420"
        User:AddImage("UserIcon", { Image = Content })
    end

    User:AddLabel("ID: " .. LocalPlayer.Name, true)
    User:AddLabel("Total Executions: " .. (Abysall.TotalExecutions and Abysall.TotalExecutions or "N/A"), true)

    local Changelog = InfoTab:AddRightGroupbox("Changelog")
    for Index, Change in pairs(LatestChangelog) do
        Changelog:AddLabel(Change, true)
    end

    local Environment = Abysall.Environment
    local Name, Version = Environment.ExecutorName, Environment.ExecutorVersion
    if not Name and Environment.identifyexecutor then Name, Version = Environment.identifyexecutor() end
    local Executor = InfoTab:AddRightGroupbox("Executor Info")
    Executor:AddLabel("Name: " .. (Name or "Unknown"), true)
	Executor:AddLabel("Version: " .. (Version and Version or "N/A"), true)
    Executor:AddDivider()
    Executor:AddLabel(Environment.FastStartup and "Checks: availability only" or "Checks: full diagnostics", true)
    local DetailsShown = false
    Executor:AddButton("Show capability details", function()
        if DetailsShown then return end
        DetailsShown = true
        for _, Result in ipairs(Environment.Results) do
            Result = Result:gsub("<", "("):gsub(">", ")")
            Executor:AddLabel(Result, true)
        end
    end)

    local Community = InfoTab:AddLeftGroupbox("Community")
    Community:AddButton("Copy Discord Invite", function()
	    toclipboard("https://dsc.gg/abysallhub")
	    Library:Notify("Discord invite copied.")
    end)
end
