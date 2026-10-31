if Abysall then
    pcall(function()
        if Abysall.LoadingScreen then Abysall.LoadingScreen:Destroy() end
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
        if StageText then
            StageText.Text = Stage
            DetailText.Text = Detail or ""
            Fill.Size = UDim2.fromScale(self.Progress, 1)
            Percent.Text = math.floor(self.Progress * 100) .. "%"
        end
    end

    function Loading:Fail(Message)
        self.FailedStage, self.Error = self.Stage, tostring(Message)
        self:Update("Loading failed", self.FailedStage .. "\n" .. self.Error)
        self.Status = "failed"
        if Elapsed then Elapsed.Text = string.format("%.1fs elapsed", tick() - self.StartedAt) end
        if Timer then Timer:Disconnect(); Timer = nil end
        if Fill then
            Fill.BackgroundColor3 = Color3.fromRGB(242, 99, 112)
            Hint.Visible = false
            Close.Visible = true
            Copy.Visible = type(setclipboard or toclipboard) == "function"
        end
    end

    function Loading:Finish(Name)
        self:Update("Ready", Name .. " loaded. Opening your menu...", 1)
        self.Status = "ready"
        if Elapsed then Elapsed.Text = string.format("%.1fs elapsed", tick() - self.StartedAt) end
        if Timer then Timer:Disconnect(); Timer = nil end
        task.delay(0.8, function() self:Destroy() end)
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
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 8, 14),
            BackgroundTransparency = 0.3, BorderSizePixel = 0, Active = true,
        })
        local Card = Create("Frame", Backdrop, {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -32, 0, 288), BackgroundColor3 = Color3.fromRGB(18, 23, 34),
            BorderSizePixel = 0,
        })
        Create("UISizeConstraint", Card, { MaxSize = Vector2.new(440, 288) })
        Create("UICorner", Card, { CornerRadius = UDim.new(0, 12) })
        Create("UIStroke", Card, { Color = Color3.fromRGB(44, 55, 76), Thickness = 1 })
        local function Label(Name, Text, Y, Height, Size, Color)
            return Create("TextLabel", Card, {
                Name = Name, Text = Text, Position = UDim2.fromOffset(24, Y),
                Size = UDim2.new(1, -48, 0, Height), BackgroundTransparency = 1,
                Font = Enum.Font.Gotham, TextSize = Size, TextColor3 = Color,
                TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
            })
        end
        Label("Brand", "ABYSALL HUB", 24, 18, 12, Color3.fromRGB(93, 161, 255))
        StageText = Label("Stage", "Starting", 55, 30, 22, Color3.fromRGB(239, 244, 255))
        DetailText = Label("Detail", "Preparing your menu...", 96, 76, 14, Color3.fromRGB(159, 174, 198))
        DetailText.TextTruncate = Enum.TextTruncate.AtEnd
        DetailText.ClipsDescendants = true
        local Track = Create("Frame", Card, {
            Position = UDim2.fromOffset(24, 184), Size = UDim2.new(1, -48, 0, 6),
            BackgroundColor3 = Color3.fromRGB(36, 45, 62), BorderSizePixel = 0,
        })
        Create("UICorner", Track, { CornerRadius = UDim.new(0, 3) })
        Fill = Create("Frame", Track, {
            Name = "Progress", Size = UDim2.fromScale(0, 1), BorderSizePixel = 0,
            BackgroundColor3 = Color3.fromRGB(70, 143, 255),
        })
        Create("UICorner", Fill, { CornerRadius = UDim.new(0, 3) })
        Elapsed = Label("Elapsed", "0.0s elapsed", 202, 18, 12, Color3.fromRGB(133, 149, 175))
        Percent = Label("Percent", "0%", 202, 18, 12, Color3.fromRGB(159, 174, 198))
        Percent.TextXAlignment = Enum.TextXAlignment.Right
        Hint = Label("Hint", "Your menu will open automatically.", 245, 18, 12, Color3.fromRGB(133, 149, 175))
        local function Button(Text, X)
            local Object = Create("TextButton", Card, {
                Text = Text, Position = UDim2.new(X, X == 0 and 24 or 4, 0, 236),
                Size = UDim2.new(0.5, -28, 0, 32), Visible = false, BorderSizePixel = 0,
                BackgroundColor3 = Color3.fromRGB(36, 48, 68), TextColor3 = Color3.fromRGB(239, 244, 255),
                Font = Enum.Font.Gotham, TextSize = 13,
            })
            Create("UICorner", Object, { CornerRadius = UDim.new(0, 6) })
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

function Session.FetchModules(Urls, Stage, StartProgress, EndProgress)
    local Sources, Errors, Names = {}, {}, {}
    local Completed, Closed = 0, false
    for Name in pairs(Urls) do table.insert(Names, Name) end
    table.sort(Names)
    Session.ReportProgress(Stage, "Downloading " .. #Names .. " components...", StartProgress)
    for _, Name in ipairs(Names) do
        task.spawn(function()
            local Ok, Result
            for _ = 1, 2 do
                if Closed or getgenv().Abysall ~= Session then return end
                Ok, Result = pcall(function() return game:HttpGet(Urls[Name]) end)
                if Ok and type(Result) == "string" and Result ~= "" then break end
                if Ok then Result = "empty or invalid response" end
                Ok = false
            end
            if Closed then return end
            if Ok then Sources[Name] = Result else Errors[Name] = tostring(Result) end
            Completed = Completed + 1
            Session.ReportProgress(Stage, Name .. " (" .. Completed .. "/" .. #Names .. ")",
                StartProgress + (EndProgress - StartProgress) * Completed / #Names)
        end)
    end
    local Started = tick()
    while Completed < #Names and tick() - Started < 15 and getgenv().Abysall == Session do task.wait() end
    Closed = true
    if getgenv().Abysall ~= Session then error("Loading interrupted by another session.", 0) end
    for _, Name in ipairs(Names) do
        if not Sources[Name] then
            error("Could not download " .. Name .. ": " .. (Errors[Name] or "request timed out after 15s")
                .. "\n" .. Urls[Name], 0)
        end
    end
    return Sources
end

function Session.RunModule(Source, Name)
    local Chunk, Err = loadstring(Source, "@Abysall/" .. Name)
    if not Chunk then error("Could not compile " .. Name .. ": " .. tostring(Err), 0) end
    return Chunk()
end

local function Bootstrap()
    local Core = Session.FetchModules({
        Environment = BaseUrl .. "Components/Environment.luau",
        ESP = BaseUrl .. "Components/ESP.luau",
        GameRegistry = BaseUrl .. "Components/GameRegistry.luau",
    }, "Downloading core modules", 0.02, 0.24)
    Session.ReportProgress("Detecting game", "Finding the right module...", 0.25)
    Session.GameRegistry = Session.RunModule(Core.GameRegistry, "GameRegistry")
    Session.CurrentGame = Session.GameRegistry:Resolve(game.GameId, game.PlaceId)
    Session.ReportProgress("Checking compatibility", Session.CurrentGame.Name .. " / executor capabilities", 0.28)
    Session.Environment = Session.RunModule(Core.Environment, "Environment")
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
    local UserData = {}
    if Env.readfile then
        local OkRead, Decoded = pcall(function()
            return Services.HttpService:JSONDecode(Env.readfile("Abysall/UserData.json"))
        end)
        if OkRead and type(Decoded) == "table" then UserData = Decoded end
    end
    UserData.TotalExecutions = (tonumber(UserData.TotalExecutions) or 0) + 1
    UserData.UILibrary = UserData.UILibrary == "Linoria" and "Linoria" or "Obsidian"
    Session.TotalExecutions = UserData.TotalExecutions
    Session.UILibrary = UserData.UILibrary

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

    if Env.readfile and Env.writefile then
        local OkSave, ErrSave = SaveUserData(UserData)
        if not OkSave then warn("[Abysall] user settings could not be saved: " .. tostring(ErrSave)) end
    end

    local HubSources = Session.FetchModules({
        Interface = BaseUrl .. "Components/Interface.luau",
        Analytics = BaseUrl .. "Components/Analytics.luau",
    }, "Downloading hub components", 0.46, 0.5)
    Session.ReportProgress("Starting interface", Session.UILibrary, 0.5)
    Session.Interface = Session.RunModule(HubSources.Interface, "Interface")
    Session.ReportProgress("Preparing session", "Starting session services...", 0.8)
    Session.Analytics = Session.RunModule(HubSources.Analytics, "Analytics")

    local Current = Session.CurrentGame
    local GameSource = Session.FetchModules({
        [Current.Id] = BaseUrl .. "Games/" .. Current.Id .. "/Loader.luau",
    }, "Loading game module", 0.82, 0.86)
    Session.ReportProgress("Starting " .. Current.Name, "Waiting for the game and building your menu...", 0.88)
    Session.RunModule(GameSource[Current.Id], "Games/" .. Current.Id .. "/Loader")
end

local Ok, Err = xpcall(Bootstrap, function(Message) return debug.traceback(tostring(Message), 2) end)
if getgenv().Abysall ~= Session then
    Loading:Destroy()
    return
end
if Ok then
    Session.LoadTime = tick() - Loading.StartedAt
    Loading:Finish(Session.CurrentGame.Name)
else
    Loading:Fail(Err)
    warn("[Abysall] " .. Loading.FailedStage .. ": " .. tostring(Err))
    pcall(function()
        local Library = Session.Interface and Session.Interface.Library
        if Library and type(Library.Unload) == "function" then Library:Unload() end
    end)
    pcall(function()
        if Session.ESPLibrary then Session.ESPLibrary:Unload() end
    end)
    if getgenv().Abysall == Session then getgenv().Abysall = nil end
end
