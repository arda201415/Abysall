if Abysall then
    pcall(function()
        if Abysall.LoadingScreen then Abysall.LoadingScreen:Destroy() end
        if Abysall.RoomProtection then Abysall.RoomProtection:Destroy() end
    end)
    -- Onceki calistirma yarida kesilmis olabilir; sessizce donmek yerine temizle
    warn("[Abysall] onceki oturum bulundu, temizleniyor")
    -- Onceki oturumun cleanup'ini calistir. Bu olmadan:
    --  - Doors'ta sahte (Fake) prompt'lar CoreGui'de saklanan gercek prompt'lari
    --    geride birakir; yeni oturumda esleşme olmadigi icin prompt'a basmak
    --    hicbir sey yapmaz.
    --  - ScooterEmpire auto-drive/wheelie donguleri calismaya devam eder ve
    --    W/A/S/D tuslari basili kalir.
    pcall(function()
        local Lib = Abysall.Interface and Abysall.Interface.Library
        if Lib and type(Lib.Unload) == "function" then
            Lib:Unload()
        end
    end)
    getgenv().Abysall = nil
end
-- Bootstrap UI is local so even the first failed download can be displayed.
local function CreateLoadingScreen()
    -- The screen is drawn before any UI library exists, so it cannot ask the
    -- theme manager for colors. The Settings tab stores the palette it last saw
    -- in UserData.json; reading it here keeps the menu from changing color
    -- right after this screen closes.
    local Palette = { Accent = "0055FF", Main = "1C1C1C", Background = "141414", Outline = "323232" }
    do
        local OkFile, Content = pcall(function() return readfile("Abysall/UserData.json") end)
        if OkFile and type(Content) == "string" and Content ~= "" then
            local OkJSON, Data = pcall(function()
                return game:GetService("HttpService"):JSONDecode(Content)
            end)
            local Saved = OkJSON and type(Data) == "table" and Data.LoadingPalette
            if type(Saved) == "table" then
                for Key in pairs(Palette) do
                    local Value = Saved[Key]
                    if type(Value) == "string" and Value:match("^%x%x%x%x%x%x$") then
                        Palette[Key] = Value:upper()
                    end
                end
            end
        end
    end

    local function FromHex(Hex, Fallback)
        local R, G, B = tonumber(Hex:sub(1, 2), 16), tonumber(Hex:sub(3, 4), 16), tonumber(Hex:sub(5, 6), 16)
        if not (R and G and B) then return Fallback end
        return Color3.fromRGB(R, G, B)
    end
    local Accent = FromHex(Palette.Accent, Color3.fromRGB(0, 85, 255))
    local MainColor = FromHex(Palette.Main, Color3.fromRGB(28, 28, 28))
    local BackgroundColor = FromHex(Palette.Background, Color3.fromRGB(20, 20, 20))
    local OutlineColor = FromHex(Palette.Outline, Color3.fromRGB(50, 50, 50))

    local Loading = { Stage = "Starting", Progress = 0, Status = "loading", StartedAt = tick() }
    local Gui, StageText, DetailText, Fill, Percent, Elapsed, Hint, Close, Copy, Timer

    function Loading:Destroy()
        if Timer then Timer:Disconnect(); Timer = nil end
        if Gui then Gui:Destroy(); Gui = nil end
        StageText, DetailText, Fill, Percent = nil, nil, nil, nil
        Elapsed, Hint, Close, Copy = nil, nil, nil, nil
    end

    function Loading:Update(Stage, Detail, Progress)
        if self.Status ~= "loading" then return end
        self.Stage, self.Detail = Stage, Detail
        self.Progress = math.max(self.Progress, math.clamp(Progress or self.Progress, 0, 1))
        -- The screen is built step by step, so any of these can still be nil.
        if StageText then StageText.Text = Stage end
        if DetailText then DetailText.Text = Detail or "" end
        if Fill then Fill.Size = UDim2.fromScale(self.Progress, 1) end
        if Percent then Percent.Text = math.floor(self.Progress * 100) .. "%" end
    end

    function Loading:Fail(Message)
        self.FailedStage, self.Error = self.Stage, tostring(Message)
        self:Update("Loading failed", self.FailedStage .. "\n" .. self.Error)
        self.Status = "failed"
        if Elapsed then Elapsed.Text = string.format("%.1fs elapsed", tick() - self.StartedAt) end
        if Timer then Timer:Disconnect(); Timer = nil end
        -- A partially built screen must still be able to show the error, so each
        -- element is guarded: a nil Hint used to raise inside the handler itself.
        if Fill then Fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60) end
        if Hint then Hint.Visible = false end
        if Close then Close.Visible = true end
        if Copy then Copy.Visible = type(setclipboard or toclipboard) == "function" end
    end

    function Loading:Finish(Name)
        self:Update("Ready", Name .. " loaded. Opening your menu...", 1)
        self.Status = "ready"
        if Elapsed then Elapsed.Text = string.format("%.1fs elapsed", tick() - self.StartedAt) end
        if Timer then Timer:Disconnect(); Timer = nil end
        task.delay(0.15, function() self:Destroy() end)
    end

    local Ok, Err = pcall(function()
        local function Create(Class, Parent, Properties)
            local Object = Instance.new(Class)
            for Key, Value in pairs(Properties) do Object[Key] = Value end
            Object.Parent = Parent
            return Object
        end
        Gui = Create("ScreenGui", nil, {
            Name = "AbysallLoading", ResetOnSpawn = false, IgnoreGuiInset = true,
            DisplayOrder = 10000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        })
        local Parent = type(gethui) == "function" and gethui() or game:GetService("CoreGui")
        local Previous = Parent:FindFirstChild("AbysallLoading")
        if Previous then Previous:Destroy() end
        local Parented = pcall(function() Gui.Parent = Parent end)
        if not Parented then
            Gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 5)
        end
        local Backdrop = Create("Frame", Gui, {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = BackgroundColor,
            BackgroundTransparency = 0.2, BorderSizePixel = 0, Active = true,
        })
        local Card = Create("Frame", Backdrop, {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -32, 0, 288), BackgroundColor3 = MainColor,
            BorderSizePixel = 0,
        })
        Create("UISizeConstraint", Card, { MaxSize = Vector2.new(440, 288) })
        Create("UICorner", Card, { CornerRadius = UDim.new(0, 6) })
        Create("UIStroke", Card, { Color = OutlineColor, Thickness = 1 })
        local function Label(Name, Text, Y, Height, Size, Color)
            return Create("TextLabel", Card, {
                Name = Name, Text = Text, Position = UDim2.fromOffset(24, Y),
                Size = UDim2.new(1, -48, 0, Height), BackgroundTransparency = 1,
                Font = Enum.Font.Gotham, TextSize = Size, TextColor3 = Color,
                TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
            })
        end
        Label("Brand", "ABYSALL HUB", 24, 18, 12, Accent)
        StageText = Label("Stage", "Starting", 55, 30, 22, Color3.fromRGB(255, 255, 255))
        DetailText = Label("Detail", "Preparing your menu...", 96, 76, 14, Color3.fromRGB(175, 175, 175))
        DetailText.TextTruncate = Enum.TextTruncate.AtEnd
        DetailText.ClipsDescendants = true
        local Track = Create("Frame", Card, {
            Position = UDim2.fromOffset(24, 184), Size = UDim2.new(1, -48, 0, 4),
            BackgroundColor3 = OutlineColor, BorderSizePixel = 0,
        })
        Create("UICorner", Track, { CornerRadius = UDim.new(0, 2) })
        Fill = Create("Frame", Track, {
            Name = "Progress", Size = UDim2.fromScale(0, 1), BorderSizePixel = 0,
            BackgroundColor3 = Accent,
        })
        Create("UICorner", Fill, { CornerRadius = UDim.new(0, 2) })
        Elapsed = Label("Elapsed", "0.0s elapsed", 202, 18, 12, Color3.fromRGB(120, 120, 120))
        Percent = Label("Percent", "0%", 202, 18, 12, Color3.fromRGB(175, 175, 175))
        Percent.TextXAlignment = Enum.TextXAlignment.Right
        Hint = Label("Hint", "Your menu will open automatically.", 245, 18, 12, Color3.fromRGB(120, 120, 120))
        local function Button(Text, X)
            local Object = Create("TextButton", Card, {
                Text = Text, Position = UDim2.new(X, X == 0 and 24 or 4, 0, 236),
                Size = UDim2.new(0.5, -28, 0, 30), Visible = false, BorderSizePixel = 0,
                BackgroundColor3 = Color3.fromRGB(35, 35, 35), TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.Gotham, TextSize = 13,
            })
            Create("UICorner", Object, { CornerRadius = UDim.new(0, 4) })
            Create("UIStroke", Object, { Color = OutlineColor, Thickness = 1 })
            return Object
        end
        Close, Copy = Button("Close", 0), Button("Copy error", 0.5)
        Close.MouseButton1Click:Connect(function() Loading:Destroy() end)
        Copy.MouseButton1Click:Connect(function()
            local CopyText = setclipboard or toclipboard
            if type(CopyText) == "function" then pcall(CopyText, Loading.Error) end
        end)
        local LastUpdate = 0
        Timer = game:GetService("RunService").Heartbeat:Connect(function()
            if not Gui or not Gui.Parent then Loading:Destroy(); return end
            if tick() - LastUpdate >= 0.2 then
                LastUpdate = tick()
                Elapsed.Text = string.format("%.1fs elapsed", tick() - Loading.StartedAt)
            end
        end)
    end)
    if not Ok then
        Loading:Destroy()
        warn("[Abysall] loading screen unavailable: " .. tostring(Err))
    end
    return Loading
end

local Session = { Legit = true }
getgenv().Abysall = Session
local Loading = CreateLoadingScreen()
Session.LoadingScreen = Loading
local BaseUrl = "https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/"

function Session.ReportProgress(Stage, Detail, Progress)
    if getgenv().Abysall == Session then Loading:Update(Stage, Detail, Progress) end
end

-- A per-run cache shares in-flight downloads with later stages. A new session
-- always fetches fresh sources so script updates take effect on the next run.
local Downloads = {}
function Session.PrefetchModules(Urls)
    for _, Url in pairs(Urls) do
        if Downloads[Url] then continue end
        local Request = { StartedAt = tick() }
        Downloads[Url] = Request
        task.spawn(function()
            local Ok, Result
            for _ = 1, 2 do
                if Request.Expired or getgenv().Abysall ~= Session then return end
                Ok, Result = pcall(function() return game:HttpGet(Url) end)
                if Ok and type(Result) == "string" and Result ~= "" then break end
                if Ok then Result = "empty or invalid response" end
                Ok = false
            end
            if Request.Expired or getgenv().Abysall ~= Session then return end
            if Ok then Request.Source = Result else Request.Error = tostring(Result) end
            Request.Done = true
        end)
    end
end

function Session.FetchModules(Urls, Stage, StartProgress, EndProgress)
    local Sources, Names, Reported = {}, {}, {}
    for Name in pairs(Urls) do table.insert(Names, Name) end
    table.sort(Names)
    Session.ReportProgress(Stage, "Downloading " .. #Names .. " components...", StartProgress)
    Session.PrefetchModules(Urls)
    local Completed = 0
    while getgenv().Abysall == Session do
        for _, Name in ipairs(Names) do
            local Request = Downloads[Urls[Name]]
            if not Request.Done and tick() - Request.StartedAt >= 15 then
                Request.Done, Request.Expired = true, true
                Request.Error = "request timed out after 15s"
            end
            if Request.Done and not Reported[Name] then
                Reported[Name] = true
                Completed = Completed + 1
                Session.ReportProgress(Stage, Name .. " (" .. Completed .. "/" .. #Names .. ")",
                    StartProgress + (EndProgress - StartProgress) * Completed / #Names)
            end
        end
        if Completed == #Names then break end
        task.wait()
    end
    if getgenv().Abysall ~= Session then error("Loading interrupted by another session.", 0) end
    for _, Name in ipairs(Names) do
        local Request = Downloads[Urls[Name]]
        if not Request.Source then
            error("Could not download " .. Name .. ": " .. tostring(Request.Error)
                .. "\n" .. Urls[Name], 0)
        end
        Sources[Name] = Request.Source
    end
    return Sources
end

function Session.RunModule(Source, Name, ...)
    local Chunk, Err = loadstring(Source, "@Abysall/" .. Name)
    if not Chunk then error("Could not compile " .. Name .. ": " .. tostring(Err), 0) end
    return Chunk(...)
end

local function Bootstrap()
    -- The UI library is the heaviest single download. Its style lives in a small
    -- local file, so read that first and start the download next to the core
    -- modules instead of after them.
    local function ReadUserFile()
        local Genv = getgenv and getgenv() or {}
        local Reader = (Session.Environment and Session.Environment.readfile) or readfile or Genv.readfile
        if type(Reader) ~= "function" then return {} end
        local Ok, Decoded = pcall(function()
            return game:GetService("HttpService"):JSONDecode(Reader("Abysall/UserData.json"))
        end)
        if Ok and type(Decoded) == "table" then return Decoded end
        return {}
    end

    local UIBases = {
        Obsidian = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/",
        Linoria = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/",
    }
    local EarlyData = ReadUserFile()
    local EarlyStyle = EarlyData.UILibrary == "Linoria" and "Linoria" or "Obsidian"
    local EarlyBase = UIBases[EarlyStyle]
    local UIDownloads = {
        EarlyBase .. "Library.lua",
        EarlyBase .. "addons/SaveManager.lua",
        EarlyBase .. "addons/ThemeManager.lua",
    }
    if EarlyStyle == "Linoria" then
        table.insert(UIDownloads, BaseUrl .. "Components/LinoriaCursor.luau")
    end

    local CoreUrls = {
        Environment = BaseUrl .. "Components/Environment.luau",
        ESP = BaseUrl .. "Components/ESP.luau",
        GameRegistry = BaseUrl .. "Components/GameRegistry.luau",
        Interface = BaseUrl .. "Components/Interface.luau",
        InfoTab = BaseUrl .. "Components/InfoTab.luau",
        SettingsTab = BaseUrl .. "Components/SettingsTab.luau",
        Addons = BaseUrl .. "Components/Addons.luau",
        SupportedGamesTab = BaseUrl .. "Components/SupportedGamesTab.luau",
    }
    -- Core first so the registry can route as early as possible; the UI library
    -- rides along in the same batch. FetchModules below re-prefetches (a no-op)
    -- and waits for the batch.
    Session.PrefetchModules(CoreUrls)
    Session.PrefetchModules(UIDownloads)
    local Core = Session.FetchModules(CoreUrls, "Downloading core modules", 0.02, 0.24)
    Session.ReportProgress("Detecting game", "Finding the right module...", 0.25)
    Session.GameRegistry = Session.RunModule(Core.GameRegistry, "GameRegistry")
    Session.CurrentGame = Session.GameRegistry:Resolve(game.GameId, game.PlaceId)

    -- The game module is the largest file for most experiences (DOORS alone is
    -- ~300 KB). Start it now so it downloads while the ESP, preferences and
    -- interface stages run.
    local GamePath = Session.GameRegistry:ScriptPath(Session.CurrentGame, game.PlaceId)
    local GameUrl = BaseUrl .. GamePath
    local GameDownloads = { [Session.CurrentGame.Id] = GameUrl }
    for _, Path in ipairs(Session.CurrentGame.Dependencies or {}) do
        GameDownloads[Path] = BaseUrl .. Path
    end
    Session.PrefetchModules(GameDownloads)

    Session.ReportProgress("Checking compatibility", Session.CurrentGame.Name .. " / executor capabilities", 0.28)
    Session.Environment = Session.RunModule(Core.Environment, "Environment", getgenv().AbysallFullChecks ~= true)
    Session.ReportProgress("Preparing visuals", "Starting the ESP library...", 0.4)
    Session.ESPLibrary = Session.RunModule(Core.ESP, "ESP")
    Session.ReportProgress("Reading preferences", "Loading your UI style and saved settings...", 0.44)

    local function CloneReference(Object)
        if Session.Environment.cloneref then
            return Session.Environment.cloneref(Object)
        else
            return Object
        end
    end

    local Services = setmetatable({}, {
        __index = function(self, Name)
            return CloneReference(game:GetService(Name))
        end
    })

    local Env = Session.Environment
    -- Authoritative read; the earlier one only decided which downloads to start.
    local UserData = ReadUserFile()
    UserData.TotalExecutions = (tonumber(UserData.TotalExecutions) or 0) + 1
    UserData.UILibrary = UserData.UILibrary == "Linoria" and "Linoria" or "Obsidian"
    -- Anonymous usage stats are opt-out rather than hidden: only an explicit
    -- false disables them, and Settings exposes the switch that writes it.
    UserData.Telemetry = UserData.Telemetry ~= false
    Session.TotalExecutions = UserData.TotalExecutions
    Session.UILibrary = UserData.UILibrary
    Session.Telemetry = UserData.Telemetry

    local function SaveUserData(Data)
        if not (Env.readfile and Env.writefile) then
            return false, "File access is unavailable."
        end
        return pcall(function()
            local MakeFolder = Env.makefolder or getgenv().makefolder
            if MakeFolder then pcall(MakeFolder, "Abysall") end
            Env.writefile("Abysall/UserData.json", Services.HttpService:JSONEncode(Data))
        end)
    end

    function Session.SetUIStyle(Value)
        if Value ~= "Obsidian" and Value ~= "Linoria" then
            return false, "Unknown UI style."
        end
        local Updated = table.clone(UserData)
        Updated.UILibrary = Value
        local Ok, Err = SaveUserData(Updated)
        if not Ok then return false, Err end
        UserData = Updated
        Session.UILibrary = Value
        return true
    end

    function Session.SetTelemetry(Value)
        -- Apply immediately even when the file write fails, so disabling stats
        -- is never blocked by an executor without filesystem access.
        local Enabled = Value == true
        Session.Telemetry = Enabled
        local Updated = table.clone(UserData)
        Updated.Telemetry = Enabled
        UserData = Updated
        local Ok, Err = SaveUserData(Updated)
        if not Ok then return false, Err end
        return true
    end

    function Session.SetLoadingPalette(Colors)
        -- Snapshot of the palette the active theme uses, so the next run's
        -- bootstrap screen opens in the same colors. Only six-digit hex values
        -- are stored; anything else keeps the previous entry.
        if type(Colors) ~= "table" then return false, "invalid palette" end
        local Previous = type(UserData.LoadingPalette) == "table" and UserData.LoadingPalette or {}
        local Updated = table.clone(UserData)
        Updated.LoadingPalette = {}
        local Changed = false
        for _, Key in ipairs({ "Accent", "Main", "Background", "Outline" }) do
            local Value = Colors[Key]
            if type(Value) == "string" and Value:match("^%x%x%x%x%x%x$") then
                Value = Value:upper()
                Updated.LoadingPalette[Key] = Value
                if Previous[Key] ~= Value then Changed = true end
            elseif Previous[Key] then
                Updated.LoadingPalette[Key] = Previous[Key]
            end
        end
        if not Changed then return true end
        UserData = Updated
        local Ok, Err = SaveUserData(Updated)
        if not Ok then return false, Err end
        return true
    end

    if Env.readfile and Env.writefile then
        local OkSave, ErrSave = SaveUserData(UserData)
        if not OkSave then warn("[Abysall] user settings could not be saved: " .. tostring(ErrSave)) end
    end

    local Current = Session.CurrentGame
    Session.ReportProgress("Starting interface", Session.UILibrary, 0.5)
    Session.Interface = Session.RunModule(Core.Interface, "Interface")

    local GameSource = Session.FetchModules({
        [Current.Id] = GameUrl,
    }, "Loading game module", 0.82, 0.86)
    Session.ReportProgress("Starting " .. Current.Name, "Waiting for the game and building your menu...", 0.88)
    Session.RunModule(GameSource[Current.Id], GamePath)
end

local Ok, Err = xpcall(Bootstrap, function(Message) return debug.traceback(tostring(Message), 2) end)
if getgenv().Abysall ~= Session then
    Loading:Destroy()
    return
end
if Ok then
    Session.LoadTime = tick() - Loading.StartedAt
    Loading:Finish(Session.CurrentGame.Name)
    -- Optional session metadata must never delay opening the menu.
    task.defer(function()
        if getgenv().Abysall ~= Session then return end
        -- Avoid even fetching the analytics module when the user opted out.
        if Session.Telemetry == false then return end
        local OkAnalytics, Result = pcall(function()
            local Source = game:HttpGet(BaseUrl .. "Components/Analytics.luau")
            if getgenv().Abysall ~= Session then return end
            return Session.RunModule(Source, "Analytics")
        end)
        if OkAnalytics and getgenv().Abysall == Session then Session.Analytics = Result end
    end)
else
    Loading:Fail(Err)
    warn("[Abysall] " .. Loading.FailedStage .. ": " .. tostring(Err))
    pcall(function() if Session.RoomProtection then Session.RoomProtection:Destroy() end end)
    pcall(function()
        local Library = Session.Interface and Session.Interface.Library
        if Library and type(Library.Unload) == "function" then Library:Unload() end
    end)
    pcall(function()
        if Session.ESPLibrary then Session.ESPLibrary:Unload() end
    end)
    if getgenv().Abysall == Session then getgenv().Abysall = nil end
end
