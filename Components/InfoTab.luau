return function(Window)
    -- Built from Components/GameRegistry.luau so the Home page cannot drift from
    -- the catalog: adding a game module updates this list by itself.
    local function BuildChangelog()
        local Registry = Abysall.GameRegistry
        local Entries = Registry and Registry.Entries
        if type(Entries) ~= "table" then return { "Module catalog is unavailable." } end
        local Sorted = {}
        for _, Entry in ipairs(Entries) do
            if not Entry.Fallback then table.insert(Sorted, Entry) end
        end
        table.sort(Sorted, function(A, B)
            if A.Updated == B.Updated then return A.Name < B.Name end
            return tostring(A.Updated or "") > tostring(B.Updated or "")
        end)
        local Lines = {}
        for Index = 1, math.min(6, #Sorted) do
            local Entry = Sorted[Index]
            local Year, Month, Day = string.match(tostring(Entry.Updated or ""), "^(%d+)-(%d+)-(%d+)$")
            table.insert(Lines, Year and (Day .. "/" .. Month .. "/" .. Year) or tostring(Entry.Updated or "?"))
            table.insert(Lines, string.format(
                '<font color="rgb(0, 255, 0)">+ %s module updated</font>', Entry.Name))
        end
        if #Lines == 0 then Lines = { "No game module has a recorded update date." } end
        return Lines
    end
    local LatestChangelog = BuildChangelog()

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
        local Clipboard = setclipboard or toclipboard
        if type(Clipboard) ~= "function" then
            Library:Notify("This executor has no clipboard function.")
            return
        end
        Clipboard("https://dsc.gg/abysallhub")
        Library:Notify("Discord invite copied.")
    end)
    Community:AddDivider()
    Community:AddLabel("Anonymous stats: " .. (Abysall.Telemetry ~= false and "on" or "off")
        .. ". Username, executor, game and place only; switch it off in Settings.", true)
    return InfoTab
end
