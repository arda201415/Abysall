return function(Window)
    local LatestChangelog = {
        "2/10/2026",
        "<font color=\"rgb(0, 255, 0)\">+ Yeniden yazilan executor yetenek testi (paralel, cokmeyen, yedekli)</font>",
        "2/10/2026",
        "<font color=\"rgb(0, 255, 0)\">+ Auto Farm (kacis + katil), Infinite Stamina, God Mode</font>",
        "27/9/2026",
        "<font color=\"rgb(0, 255, 0)\">+ Added Build the Pyramid support (Auto Block, Bench, Gifts, ESP)</font>",
    }

    local function SafeText(Value)
        -- fix for veloshitty 💔 (RichText etiketleri patlatiyor)
        local Text = tostring(Value or "")
        Text = Text:gsub("<", "(")
        Text = Text:gsub(">", ")")
        return Text
    end

    local function CloneReference(Object)
        if Abysall and Abysall.Environment and Abysall.Environment.Safe then
            return Abysall.Environment.Safe.cloneref(Object)
        end
        return Object
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
    local InfoTab = Window:AddTab("Info", "user")

    local User = InfoTab:AddLeftGroupbox("User Info")

    local ImageSize = Enum.ThumbnailSize.Size420x420
    local ImageType = Enum.ThumbnailType.HeadShot

    -- Profil resmi alinamazsa sekme cokmesin
    local OkThumb, Content = pcall(function()
        return Services.Players:GetUserThumbnailAsync(LocalPlayer.UserId, ImageType, ImageSize)
    end)
    if OkThumb and type(Content) == "string" then
        pcall(function()
            User:AddImage("UserIcon", { Image = Content })
        end)
    end

    User:AddLabel("ID: " .. tostring(LocalPlayer.Name), true)
    User:AddLabel("Total Executions: " .. tostring(Abysall.TotalExecutions or "N/A"), true)

    local Changelog = InfoTab:AddRightGroupbox("Changelog")
    for _, Change in pairs(LatestChangelog) do
        Changelog:AddLabel(SafeText(Change), true)
    end

    local Executor = InfoTab:AddRightGroupbox("Executor Info")
    Executor:AddLabel("Name: " .. SafeText(Abysall.Environment.identifyexecutor()), true)

    Executor:AddDivider()

    -- Test sonuclari arka planda tamamlandikca otomatik guncellenir
    local StatusLabel = Executor:AddLabel("Yetenek testi calisiyor...", true)
    local Details = Executor:AddLabel("", true)
    Details.TextSize = 12

    local function RefreshReport()
        local Ok, Report = pcall(function()
            return Abysall.Environment.Report()
        end)
        if not Ok or type(Report) ~= "string" then return false end
        local Lines = {}
        for Line in string.gmatch(Report, "([^\n]+)") do
            table.insert(Lines, SafeText(Line))
        end
        StatusLabel.Text = table.remove(Lines, 1) or "Test Result"
        local Body = table.concat(Lines, "\n")
        Details.Text = Body
        return Abysall.Environment.Ready == true
    end

    RefreshReport()
    task.spawn(function()
        for _ = 1, 60 do
            task.wait(0.5)
            local Done = RefreshReport()
            if Done then break end
        end
    end)

    local Community = InfoTab:AddLeftGroupbox("Community")
    Community:AddButton("Copy Discord Invite", function()
        pcall(function() toclipboard("https://dsc.gg/abysallhub") end)
        Library:Notify("Discord invite copied.")
    end)
    Community:AddButton("Copy Test Report", function()
        local Ok, Report = pcall(function() return Abysall.Environment.Report() end)
        if Ok then
            pcall(function() toclipboard(Report) end)
            Library:Notify("Test report copied.")
        end
    end)
end