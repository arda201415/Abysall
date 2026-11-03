-- Abysall Hub | Cameraman Tower Defense
-- PlaceId: 132929771812494 | UniverseId: 10762636904
-- Oyunun kendi remote'lari ile: Auto Play (yerlestirme), Auto Upgrade/Sell/Target,
-- Auto Wave Skip, Game Speed, Auto Summon, ESP, WalkSpeed/JumpPower.

local LoadStart = tick()
if not Abysall or not Abysall.Interface then
    warn("[Abysall] CameramanTD dogrudan calistirildi: once ana Loader (README loadstring) calistir.")
    return
end
Abysall.SavePath = "CameramanTD"

local Library = Abysall.Interface.Library
local Toggles = Library.Toggles
local Options = Library.Options

-- Button and OnChanged callbacks run on a signal thread, which this executor
-- sandboxes against Instance creation ("lacking capability Plugin"). Notifications
-- are queued instead and created by the module's own loop, spawned at load time.
local NotifyQueue = {}
local function NotifyLater(Message)
    table.insert(NotifyQueue, tostring(Message))
end

local function BindChange(Control, Fn)
    if Control == nil then return end
    local Registering = true
    Control:OnChanged(function(...)
        if Registering then return end
        return Fn(...)
    end)
    Registering = false
end
local function ToggleOn(Name)
    local T = Toggles and Toggles[Name]
    if T == nil then return false end
    return T.Value == true
end
local function OnChange(Name, Fn)
    BindChange(Toggles and Toggles[Name], Fn)
end

local function CloneReference(Object)
    if Abysall.Environment and Abysall.Environment.cloneref then
        return Abysall.Environment.cloneref(Object)
    end
    return Object
end

local Services = setmetatable({}, {
    __index = function(self, Name)
        return CloneReference(game:GetService(Name))
    end,
})

local LocalPlayer = Services.Players.LocalPlayer
local Unloaded = false
local Connections = {}

-- // Oyun modulleri // ------------------------------------------------------
local ReplicatedStorage = Services.ReplicatedStorage
local Network = nil
local Replication = nil

-- The window must not wait for the game's modules: a missing folder used to
-- block the menu for up to 30 seconds. Everything degrades to a no-op until the
-- remotes resolve.
task.spawn(function()
    local OkLoader, Loader = pcall(function()
        return ReplicatedStorage:WaitForChild("ModuleLoader", 20)
    end)
    if not OkLoader or not Loader then
        warn("[Abysall] CameramanTD: ModuleLoader bulunamadi, remote'lar devre disi")
        return
    end
    local Ok = pcall(function()
        local Shared = Loader:WaitForChild("Shared", 10)
        Network = require(Shared:WaitForChild("Network", 10))
    end)
    if not Ok then warn("[Abysall] CameramanTD: Network modulu yuklenemedi") end
    pcall(function()
        local Client = Loader:WaitForChild("Client", 10)
        Replication = require(Client:WaitForChild("Replication", 10))
    end)
end)

local function Remote(Name)
    if Network then
        local Ok, Result = pcall(function() return Network.Get(Name) end)
        if Ok and Result ~= nil then return Result end
    end
    -- Network.Get does not resolve every remote (CSComms is one), so fall back to
    -- the instance tree before reporting the remote as missing.
    return ReplicatedStorage:FindFirstChild(Name, true)
end
local function Fire(Name, ...)
    local R = Remote(Name)
    if not R then return false end
    local Args = table.pack(...)
    local Ok = pcall(function() R:FireServer(table.unpack(Args, 1, Args.n)) end)
    return Ok
end
local function Invoke(Name, ...)
    local R = Remote(Name)
    if not R then return nil end
    local Args = table.pack(...)
    local Ok, Result = pcall(function() return R:InvokeServer(table.unpack(Args, 1, Args.n)) end)
    if Ok then return Result end
    return nil
end

local function GetReplicaData()
    if not Replication then return nil end
    local Ok, Replica = pcall(Replication.GetCurrentReplica)
    if Ok and Replica then
        return Replica.Data
    end
    return nil
end

local function GetGame()
    return Services.Workspace:FindFirstChild("Game")
end
local function GetPlacedTowerModels()
    local Game = GetGame()
    local Folder = Game and Game:FindFirstChild("Towers")
    return Folder
end

-- // Pencere // -------------------------------------------------------------
local Window = Library:CreateWindow({
    Title = "Abysall Hub | Cameraman Tower Defense",
    Footer = "dsc.gg/abysallhub",
    NotifySide = "Right",
    ShowCustomCursor = false,
    AutoShow = true,
    Center = true,
    TabPadding = 3,
    MenuFadeTime = 0,
    CornerRadius = 2,
})
Abysall.Interface.ApplyInfoTab(Window)

local Tabs = {
    Automation = Window:AddTab("Automation", "bot"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Misc = Window:AddTab("Misc", "settings"),
    Debug = Window:AddTab("Debug", "terminal"),
}

-- // Automation // ----------------------------------------------------------
local Auto = Tabs.Automation:AddLeftGroupbox("Match")

Auto:AddToggle("AutoPlay", {
    Text = "Auto Play (Place Units)", Default = false,
    Tooltip = "Sahip oldugun unitleri TowerArea uzerine yerlestirir. Para rezervine saygi duyar.",
})
Auto:AddToggle("AutoUpgrade", { Text = "Auto Upgrade", Default = false })
Auto:AddToggle("AutoTarget", { Text = "Auto Target", Default = false })
Auto:AddToggle("AutoSell", {
    Text = "Auto Sell (over limit)", Default = false,
    Tooltip = "Kule sayisi limiti asinca kuleleri satar; 'Level' attribute'u varsa once en dusuk seviyelileri.",
})
Auto:AddSlider("MaxTowers", { Text = "Max Towers", Default = 20, Min = 1, Max = 60, Rounding = 0 })
Auto:AddSlider("MoneyReserve", { Text = "Money Reserve", Default = 0, Min = 0, Max = 100000, Rounding = 0 })
Auto:AddSlider("PathOffset", {
    Text = "Path Offset", Default = 4, Min = 0, Max = 12, Rounding = 0,
    Tooltip = "Yol parcasindan saga/sola kaydirma (stud). Kuleleri yolun kenarina dizer.",
})
Auto:AddSlider("UpgradeEvery", {
    Text = "Upgrade Every N Places", Default = 3, Min = 1, Max = 10, Rounding = 0,
})
Auto:AddToggle("AutoWaveSkip", { Text = "Auto Wave Skip", Default = false })
Auto:AddToggle("AutoPlayAgain", { Text = "Auto Play Again (lobby)", Default = false })

local Economy = Tabs.Automation:AddRightGroupbox("Economy")

Economy:AddDropdown("GameSpeed", {
    Text = "Game Speed", Values = { "Default (1x)", "1.5x", "2x", "Normal (1x)" },
    Default = "1.5x",
})
Economy:AddToggle("AutoSummon", {
    Text = "Auto Summon (Basic Crate)", Default = false,
    Tooltip = "Opens the Basic Crate with the game's OpenCrate remote every ~2.2 seconds.",
})
Economy:AddInput("RedeemCodes", {
    Text = "Codes", Default = "", Placeholder = "kod1, kod2",
    Tooltip = "RedeemCode ile tek tek dener (bir kez).",
})
Economy:AddButton("Redeem Now", function()
    if not Remote("RedeemCode") then
        NotifyLater("This place exposes no RedeemCode remote; codes are not supported here.")
        return
    end
    local Raw = tostring(Options.RedeemCodes.Value or "")
    local Sent = 0
    for Code in string.gmatch(Raw, "[^,;%s]+") do
        if Fire("RedeemCode", Code) then Sent += 1 end
        task.wait(0.6)
    end
    NotifyLater(Sent .. " kod gonderildi.")
end)

local SpeedValues = { ["Default (1x)"] = 1, ["1.5x"] = 1.5, ["2x"] = 2, ["Normal (1x)"] = 1 }

-- // Visuals // -------------------------------------------------------------
local Esp = Tabs.Visuals:AddLeftGroupbox("ESP")

Esp:AddToggle("TowerESP", { Text = "Tower ESP", Default = false })
Toggles.TowerESP:AddColorPicker("TowerESPColor", { Text = "Tower Color", Default = Color3.fromRGB(0, 200, 255), Transparency = 0 })
Esp:AddToggle("EnemyESP", { Text = "Enemy ESP", Default = false })
Toggles.EnemyESP:AddColorPicker("EnemyESPColor", { Text = "Enemy Color", Default = Color3.fromRGB(255, 60, 60), Transparency = 0 })
Esp:AddToggle("TDPlayerESP", { Text = "Player ESP", Default = false })
Toggles.TDPlayerESP:AddColorPicker("TDPlayerESPColor", { Text = "Player Color", Default = Color3.fromRGB(255, 255, 0), Transparency = 0 })

local EspSettings = Tabs.Visuals:AddRightGroupbox("ESP Settings")
EspSettings:AddToggle("ESPShowDistance", { Text = "Show Distance", Default = true })
EspSettings:AddToggle("ESPTracers", { Text = "Tracers", Default = false })
EspSettings:AddToggle("ESPArrows", { Text = "Arrows", Default = false })
OnChange("ESPShowDistance", function(V) Abysall.ESPLibrary:SetShowDistance(V) end)
OnChange("ESPTracers", function(V) Abysall.ESPLibrary:SetTracers(V) end)
OnChange("ESPArrows", function(V) Abysall.ESPLibrary:SetArrows(V) end)

-- // Misc // ----------------------------------------------------------------
local Misc = Tabs.Misc:AddLeftGroupbox("Player")
Misc:AddToggle("TDWalkSpeed", { Text = "WalkSpeed", Default = false })
Misc:AddSlider("TDWalkSpeedValue", { Text = "Speed", Default = 16, Min = 16, Max = 200, Rounding = 0 })
Misc:AddToggle("TDJumpPower", { Text = "JumpPower", Default = false })
Misc:AddSlider("TDJumpPowerValue", { Text = "Jump", Default = 50, Min = 50, Max = 300, Rounding = 0 })

local Session = Tabs.Misc:AddRightGroupbox("Session")
Session:AddToggle("AutoSave", {
    Text = "Auto Save", Default = false,
    Tooltip = "Ayar degistiginde config'i otomatik kaydeder ve autoload olarak isaretler.",
})
Session:AddToggle("AutoRejoin", {
    Text = "Re-exec after teleport", Default = false,
    Tooltip = "Teleport sonrasi scripti otomatik yeniden calistirir (queue_on_teleport).",
})
Session:AddButton("Save Now", function()
    local Ok, Err = pcall(function() Abysall.Interface.SaveManager:Save("autoload") end)
    if Ok then NotifyLater("Config kaydedildi (autoload).") else NotifyLater("Kaydedilemedi: " .. tostring(Err)) end
end)

-- // Diagnostics // ---------------------------------------------------------
-- The remote names this module uses were never confirmed against the live game
-- (they do not come from BARRAGE's loader, which ships no gameplay code). This
-- tab reports what the game actually exposes so the API can be verified in-game.
local DiagGroup = Tabs.Debug:AddLeftGroupbox("Diagnostics")
local DiagLines = {}

local function DescribeValue(Value, Limit)
    Limit = Limit or 12
    if Value == nil then return "nil" end
    if typeof(Value) == "Instance" then return Value.ClassName .. ":" .. Value.Name end
    local Kind = type(Value)
    if Kind ~= "table" then return Kind end
    local Parts, Count = {}, 0
    for Key in pairs(Value) do
        Count += 1
        if #Parts < Limit then table.insert(Parts, tostring(Key)) end
    end
    table.sort(Parts)
    return string.format("table(%d){%s%s}", Count, table.concat(Parts, ", "), Count > #Parts and ", ..." or "")
end

local function DescribeChildren(Folder, Limit)
    if not Folder then return "MISSING" end
    local Names, Total = {}, 0
    for _, Child in ipairs(Folder:GetChildren()) do
        Total += 1
        if #Names < (Limit or 8) then table.insert(Names, Child.Name) end
    end
    return string.format("%d [%s%s]", Total, table.concat(Names, ", "), Total > #Names and ", ..." or "")
end

local function Summarize(Value, Depth)
    Depth = Depth or 0
    local Kind = type(Value)
    if Kind == "string" then
        return string.format("%q", Value)
    elseif Kind == "number" or Kind == "boolean" or Kind == "nil" then
        return tostring(Value)
    elseif typeof(Value) == "Instance" then
        return Value.ClassName .. ":" .. Value.Name
    elseif Kind == "table" then
        if Depth >= 2 then return "{...}" end
        local Parts = {}
        for Key, Inner in pairs(Value) do
            if #Parts >= 8 then
                table.insert(Parts, "...")
                break
            end
            table.insert(Parts, tostring(Key) .. "=" .. Summarize(Inner, Depth + 1))
        end
        return "{" .. table.concat(Parts, ", ") .. "}"
    end
    return Kind
end

local function CollectDiagnostics()
    local Lines = {}
    local function Add(Format, ...) table.insert(Lines, string.format(Format, ...)) end

    Add("Abysall CameramanTD diagnostics")
    Add("placeId=%s gameId=%s", tostring(game.PlaceId), tostring(game.GameId))
    Add("ModuleLoader=%s", ReplicatedStorage:FindFirstChild("ModuleLoader") and "present" or "MISSING")
    Add("Network=%s", DescribeValue(Network))
    Add("Replication=%s", DescribeValue(Replication))

    -- Every remote the client can see, with its class, so the real names can be
    -- matched against the ones this module fires.
    local RemoteNames, RemoteTotal = {}, 0
    for _, Object in ipairs(ReplicatedStorage:GetDescendants()) do
        if Object:IsA("RemoteEvent") or Object:IsA("RemoteFunction") or Object:IsA("UnreliableRemoteEvent") then
            RemoteTotal += 1
            if #RemoteNames < 60 then
                table.insert(RemoteNames, Object.Name .. ":" .. Object.ClassName)
            end
        end
    end
    Add("replicatedStorage remotes=%d [%s%s]", RemoteTotal,
        table.concat(RemoteNames, ", "), RemoteTotal > #RemoteNames and ", ..." or "")

    local Data = GetReplicaData()
    Add("replicaData=%s", DescribeValue(Data))
    if type(Data) == "table" then
        local Keys = {}
        for Key, Value in pairs(Data) do
            table.insert(Keys, tostring(Key) .. ":" .. type(Value))
        end
        table.sort(Keys)
        Add("replicaData keys(%d)=[%s]", #Keys, table.concat(Keys, ", "))
    end
    if type(Data) == "table" and type(Data.Towers) == "table" then
        local Count, SampleId, Sample = 0, nil, nil
        for UnitId, Info in pairs(Data.Towers) do
            Count += 1
            if Sample == nil then SampleId, Sample = UnitId, Info end
        end
        Add("replica.Towers count=%d sampleId=%s", Count, tostring(SampleId))
        if type(Sample) == "table" then
            local Parts = {}
            for Key, Value in pairs(Sample) do
                table.insert(Parts, tostring(Key) .. "=" .. Summarize(Value))
            end
            table.sort(Parts)
            Add("replica.Towers sample={%s}", table.concat(Parts, ", "))
        end
    end

    local Game = GetGame()
    Add("workspace.Game=%s", Game and "present" or "MISSING")
    if Game then
        Add("  children=%s", DescribeChildren(Game))
        Add("  Paths=%s", Game:FindFirstChild("Paths") and DescribeChildren(Game.Paths, 6) or "MISSING")
        Add("  TowerArea=%s", Game:FindFirstChild("TowerArea") and DescribeChildren(Game.TowerArea, 10) or "MISSING")
        Add("  Towers=%s", Game:FindFirstChild("Towers") and DescribeChildren(Game.Towers, 10) or "MISSING")
        Add("  Enemies=%s", Game:FindFirstChild("Enemies") and DescribeChildren(Game.Enemies, 10) or "MISSING")
        Add("  Units=%s", Game:FindFirstChild("Units") and DescribeChildren(Game.Units, 6) or "MISSING")
        Add("  Waypoints=%s", Game:FindFirstChild("Waypoints") and DescribeChildren(Game.Waypoints, 6) or "MISSING")
        Add("  PlacingTowers=%s", Game:FindFirstChild("PlacingTowers") and DescribeChildren(Game.PlacingTowers, 6) or "MISSING")
    end

    -- Which of the names the module fires actually resolve, and what the game
    -- exposes instead.
    local Known = {
        "TowerAdd", "TowerUpgrade", "TowerTarget", "TowerSell",
        "WaveSkip", "SummonTowers", "OpenCrate", "ChangeSpeed", "PlayAgain",
        "RedeemCode", "UpdateSetting", "CSComms", "UnitAdd", "UnitUpdate",
    }
    for _, Name in ipairs(Known) do
        local Found = Remote(Name)
        local Kind = "nil"
        if Found ~= nil then Kind = tostring(Found.ClassName or type(Found)) end
        Add("remote %-14s %s", Name, Kind)
    end

    -- A placed tower reveals whether the game exposes Level/Id attributes, which
    -- Auto Sell and the upgrade loop rely on.
    local Folders = GetPlacedTowerModels()
    if Folders then
        for _, Model in ipairs(Folders:GetChildren()) do
            if Model:IsA("Model") then
                local Attributes = Model:GetAttributes()
                local Pairs = {}
                for Key, Value in pairs(Attributes) do
                    table.insert(Pairs, Key .. "=" .. tostring(Value))
                end
                table.sort(Pairs)
                Add("tower sample name=%s attrs=[%s] children=%d",
                    Model.Name, table.concat(Pairs, ","), #Model:GetChildren())
                break
            end
        end
    end

    return Lines
end

DiagGroup:AddLabel("The remote names below are what this module fires.", true)
DiagGroup:AddLabel("Collect reports what the game actually exposes.", true)
DiagGroup:AddButton("Collect report", function()
    DiagLines = CollectDiagnostics()
    for _, Line in ipairs(DiagLines) do print("[Abysall:TD] " .. Line) end
    NotifyLater("Diagnostics collected: " .. #DiagLines .. " lines (console + Copy report).")
end)
DiagGroup:AddButton("Copy report", function()
    if #DiagLines == 0 then
        NotifyLater("Collect the report first.")
        return
    end
    local Clipboard = setclipboard or toclipboard
    if type(Clipboard) ~= "function" then
        NotifyLater("This executor has no clipboard function.")
        return
    end
    Clipboard(table.concat(DiagLines, "\n"))
    NotifyLater("Diagnostics copied (" .. #DiagLines .. " lines).")
end)

-- // Remote log // -----------------------------------------------------------
-- Records the calls the game itself makes (and other scripts make) so the real
-- remote names and argument shapes can be learned by playing normally. It never
-- calls anything; it only observes __namecall.
local RemoteLog = {}
local RemoteLogLimit = 200
local LoggingRemotes = false
local RemoteHookInstalled = false

local LastHookError = nil

local function ResolveFunction(Names)
    local Genv = (getgenv and getgenv()) or {}
    local Sources = { Genv, _G, type(syn) == "table" and syn or nil, type(fluxus) == "table" and fluxus or nil }
    for _, Name in ipairs(Names) do
        for _, Source in ipairs(Sources) do
            if type(Source) == "table" then
                local Value = Source[Name]
                if type(Value) == "function" then return Value end
            end
        end
    end
    return nil
end

local function InstallRemoteHook()
    if RemoteHookInstalled then return true, nil end

    local Hook = ResolveFunction({ "hookmetamethod" })
    local GetMethod = ResolveFunction({ "getnamecallmethod", "get_namecall_method" })
    if type(Hook) ~= "function" then
        LastHookError = "hookmetamethod bulunamadi"
        return false, LastHookError
    end
    if type(GetMethod) ~= "function" then
        LastHookError = "getnamecallmethod bulunamadi"
        return false, LastHookError
    end

    local Wrap = ResolveFunction({ "newcclosure" }) or function(Function) return Function end
    local Original = nil

    local Wrapper = Wrap(function(Self, ...)
        local Args = table.pack(...)
        if LoggingRemotes and typeof(Self) == "Instance" then
            local Method = GetMethod()
            if Method == "FireServer" or Method == "InvokeServer" then
                local Parts = {}
                for Index = 1, math.min(Args.n, 6) do
                    table.insert(Parts, Summarize(Args[Index]))
                end
                local Line = string.format("%s:%s(%s)", Self.ClassName, Self.Name, table.concat(Parts, ", "))
                table.insert(RemoteLog, Line)
                while #RemoteLog > RemoteLogLimit do table.remove(RemoteLog, 1) end
                print("[Abysall:TD:remote] " .. Line)
            end
        end
        if type(Original) == "function" then
            return Original(Self, table.unpack(Args, 1, Args.n))
        end
        -- Some executors do not hand back the original; dispatch through the
        -- instance method directly, which sidesteps __namecall entirely.
        local Method = GetMethod()
        local Direct = Self[Method]
        if type(Direct) == "function" then
            return Direct(Self, table.unpack(Args, 1, Args.n))
        end
        return nil
    end)

    -- Executors disagree on the signature: most take (object, method, hook),
    -- others take (method, hook). Try both and keep the first that works.
    local Attempts = {
        function() return Hook(game, "__namecall", Wrapper) end,
        function() return Hook("__namecall", Wrapper) end,
    }
    for _, Attempt in ipairs(Attempts) do
        local Ok, Returned = pcall(Attempt)
        if Ok then
            if type(Returned) == "function" then Original = Returned end
            RemoteHookInstalled = true
            LastHookError = nil
            return true, nil
        end
        LastHookError = tostring(Returned)
    end
    return false, LastHookError
end

DiagGroup:AddDivider()
DiagGroup:AddToggle("TDLogRemotes", {
    Text = "Log game remotes", Default = false,
    Tooltip = "Records RemoteEvent:FireServer / RemoteFunction:InvokeServer calls while you play. Turn the automation toggles off first so the log only shows the game's own calls.",
})
DiagGroup:AddButton("Copy remote log", function()
    if #RemoteLog == 0 then
        NotifyLater("Remote log is empty. Enable 'Log game remotes' and play a wave.")
        return
    end
    local Clipboard = setclipboard or toclipboard
    if type(Clipboard) ~= "function" then
        NotifyLater("This executor has no clipboard function.")
        return
    end
    Clipboard(table.concat(RemoteLog, "\n"))
    NotifyLater("Remote log copied (" .. #RemoteLog .. " calls).")
end)
DiagGroup:AddButton("Clear remote log", function()
    table.clear(RemoteLog)
    NotifyLater("Remote log cleared.")
end)
DiagGroup:AddButton("Check hook support", function()
    local Hook = ResolveFunction({ "hookmetamethod" })
    local GetMethod = ResolveFunction({ "getnamecallmethod", "get_namecall_method" })
    local Wrap = ResolveFunction({ "newcclosure" })
    NotifyLater(string.format(
        "hookmetamethod=%s  getnamecallmethod=%s  newcclosure=%s  hooked=%s",
        Hook and "yes" or "no", GetMethod and "yes" or "no",
        Wrap and "yes" or "no", RemoteHookInstalled and "yes" or "no"))
end)
OnChange("TDLogRemotes", function(Value)
    if Value then
        local Ok, Reason = InstallRemoteHook()
        if not Ok then
            NotifyLater("Remote hook failed: " .. tostring(Reason))
            Toggles.TDLogRemotes:SetValue(false)
            return
        end
        LoggingRemotes = true
        NotifyLater("Remote logging on. Play normally; the log keeps the last " .. RemoteLogLimit .. " calls.")
    else
        LoggingRemotes = false
    end
end)

-- // Auto Save // -----------------------------------------------------------
local SaveManager = Abysall.Interface.SaveManager
local SaveDirty, SaveAt = false, 0
task.spawn(function()
    pcall(function() SaveManager:SetAutoloadConfig("autoload") end)
    for _, Control in pairs(Library.Options) do
        pcall(function()
            Control:OnChanged(function() SaveDirty = true end)
        end)
    end
    while not Unloaded do
        task.wait(1)
        if SaveDirty and ToggleOn("AutoSave") and os.clock() - SaveAt > 3 then
            SaveDirty = false
            SaveAt = os.clock()
            pcall(function() SaveManager:Save("autoload") end)
        end
    end
end)

-- // Teleport persistence // ------------------------------------------------
local function ApplyTeleportQueue()
    local Queue = queue_on_teleport or queueonteleport or (type(syn) == "table" and syn.queue_on_teleport)
    if type(Queue) ~= "function" then return false end
    local Code = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/Loader.luau"))()'
    local Ok = pcall(Queue, Code)
    return Ok
end
OnChange("AutoRejoin", function(Value)
    if Value then
        if ApplyTeleportQueue() then
            NotifyLater("Teleport sonrasi yeniden calisma ayarlandi.")
        else
            NotifyLater("Bu executor queue_on_teleport desteklemiyor.")
            Toggles.AutoRejoin:SetValue(false)
        end
    end
end)
if ToggleOn("AutoRejoin") then pcall(ApplyTeleportQueue) end

-- // ESP // -----------------------------------------------------------------
local TrackedESP = {}
local ESPText = {}
local ESPColor = {}

local function AddESP(Object, Text, Color)
    if TrackedESP[Object] then
        -- Enemy labels carry live health, so refresh the text only when it moved.
        if Text ~= nil and ESPText[Object] ~= Text then
            ESPText[Object] = Text
            pcall(function() Abysall.ESPLibrary:UpdateObjectText(Object, Text) end)
        end
        if ESPColor[Object] ~= Color then
            ESPColor[Object] = Color
            pcall(function() Abysall.ESPLibrary:UpdateObjectColor(Object, Color) end)
        end
        return
    end
    TrackedESP[Object] = true
    ESPText[Object] = Text
    ESPColor[Object] = Color
    pcall(function()
        Abysall.ESPLibrary:AddESP({ Object = Object, Text = Text, Color = Color })
        Object.Destroying:Once(function()
            TrackedESP[Object] = nil
            ESPText[Object] = nil
            ESPColor[Object] = nil
            if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Object) end) end
        end)
    end)
end
local function RemoveESP(Object)
    TrackedESP[Object] = nil
    ESPText[Object] = nil
    ESPColor[Object] = nil
    if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Object) end) end
end

local function RefreshTowerESP()
    if not ToggleOn("TowerESP") then return end
    local Folder = GetPlacedTowerModels()
    if not Folder then return end
    for _, Model in ipairs(Folder:GetChildren()) do
        if Model:IsA("Model") then AddESP(Model, "Tower", Options.TowerESPColor.Value) end
    end
end

local function RefreshEnemyESP()
    if not ToggleOn("EnemyESP") then return end
    local Game = GetGame()
    local Folder = Game and Game:FindFirstChild("Enemies")
    if not Folder then return end
    for _, Model in ipairs(Folder:GetChildren()) do
        local Hum = Model:FindFirstChildOfClass("Humanoid")
        local Text = Model.Name
        if Hum then Text = Model.Name .. " [" .. math.floor(Hum.Health + 0.5) .. "]" end
        AddESP(Model, Text, Options.EnemyESPColor.Value)
    end
end

local function RefreshPlayerESP()
    if not ToggleOn("TDPlayerESP") then return end
    for _, Player in ipairs(Services.Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character then
            AddESP(Player.Character, Player.Name, Options.TDPlayerESPColor.Value)
        end
    end
end

OnChange("TowerESP", function(V)
    if V then RefreshTowerESP()
    else
        local Folder = GetPlacedTowerModels()
        if Folder then for _, M in ipairs(Folder:GetChildren()) do RemoveESP(M) end end
    end
end)
OnChange("EnemyESP", function(V)
    if V then RefreshEnemyESP()
    else
        local Game = GetGame()
        local Folder = Game and Game:FindFirstChild("Enemies")
        if Folder then for _, M in ipairs(Folder:GetChildren()) do RemoveESP(M) end end
    end
end)
OnChange("TDPlayerESP", function(V)
    for _, Player in ipairs(Services.Players:GetPlayers()) do
        if Player.Character then
            if V and Player ~= LocalPlayer then
                AddESP(Player.Character, Player.Name, Options.TDPlayerESPColor.Value)
            else
                RemoveESP(Player.Character)
            end
        end
    end
end)

-- // Game Speed // ----------------------------------------------------------
local function ApplySpeed()
    local Value = SpeedValues[Options.GameSpeed.Value] or 1
    -- Some builds expose ChangeSpeed as an event rather than a function, so try
    -- the invocation first and fall back to firing.
    if Invoke("ChangeSpeed", Value) == nil then Fire("ChangeSpeed", Value) end
end
BindChange(Options.GameSpeed, function() ApplySpeed() end)

-- The dropdown advertises 1.5x by default; apply it once instead of leaving the
-- game at 1x until the control is touched.
task.delay(2, function()
    if Unloaded then return end
    if Options.GameSpeed.Value ~= "Default (1x)" then ApplySpeed() end
end)

-- // Auto Play (placement) // ----------------------------------------------
-- Waypoints are the real path centre line: 12 parts named 1..12. Interpolating
-- between consecutive ones gives evenly spaced anchors, unlike the 313 decorative
-- path models, which are scattered over the whole map.
local function GetPlacementPoints()
    local Game = GetGame()
    if not Game then return {} end
    local Points = {}

    local Waypoints = Game:FindFirstChild("Waypoints")
    if Waypoints then
        local Ordered = {}
        for _, Part in ipairs(Waypoints:GetChildren()) do
            if Part:IsA("BasePart") then
                table.insert(Ordered, {
                    Order = tonumber(Part.Name) or math.huge,
                    Position = Part.Position,
                })
            end
        end
        table.sort(Ordered, function(A, B) return A.Order < B.Order end)
        for Index = 1, #Ordered - 1 do
            local From, To = Ordered[Index].Position, Ordered[Index + 1].Position
            local Delta = To - From
            local Length = Delta.Magnitude
            if Length > 2 then
                local Direction = Delta.Unit
                local Count = math.max(1, math.floor(Length / 6))
                for Step = 1, Count do
                    local Position = From + Direction * (Length * (Step - 0.5) / Count)
                    table.insert(Points, { CFrame = CFrame.lookAt(Position, Position + Direction) })
                end
            end
        end
    end

    -- Fallback: decorative path parts, then the buildable area.
    if #Points == 0 then
        local Paths = Game:FindFirstChild("Paths")
        if Paths then
            for _, Object in ipairs(Paths:GetDescendants()) do
                if Object:IsA("BasePart") then table.insert(Points, { CFrame = Object.CFrame }) end
            end
        end
    end
    if #Points == 0 then
        local Area = Game:FindFirstChild("TowerArea")
        if Area then
            for _, Part in ipairs(Area:GetChildren()) do
                if Part:IsA("BasePart") then table.insert(Points, { CFrame = Part.CFrame }) end
            end
        end
    end
    return Points
end

local function GetEquippedUnits()
    local Data = GetReplicaData()
    local List = {}
    local Towers = Data and Data.Towers
    if type(Towers) == "table" then
        for UnitId, Info in pairs(Towers) do
            if type(Info) == "table" and Info.Name then
                -- Equipped is a slot number (e.g. 5), not a boolean; 0 is benched.
                local Slot = tonumber(Info.Equipped)
                local IsEquipped = (Slot ~= nil and Slot > 0) or Info.Equipped == true
                if IsEquipped then
                    table.insert(List, { UnitId = tostring(UnitId), Name = Info.Name, Level = tonumber(Info.Level) or 0 })
                end
            end
        end
    end
    table.sort(List, function(A, B) return (A.Level or 0) > (B.Level or 0) end)
    return List
end

-- The live replica does expose `Money`; the reserve only applies when one of these
-- fields is a number, so an unknown schema cannot stop placement entirely.
local MoneyFields = { "Money", "Cash", "Coins", "Tokens", "Gems", "Currency", "Funds" }
local function ReadMoney(Data)
    if type(Data) ~= "table" then return nil end
    for _, Field in ipairs(MoneyFields) do
        local Value = tonumber(Data[Field])
        if Value ~= nil then return Value, Field end
    end
    return nil
end

local function PlaceOne()
    local Data = GetReplicaData()
    if not Data then return false end
    local Money = ReadMoney(Data)
    local Reserve = tonumber(Options.MoneyReserve.Value) or 0
    if Money ~= nil and Money <= Reserve then return false end
    local Folder = GetPlacedTowerModels()
    local Count = Folder and #Folder:GetChildren() or 0
    if Count >= (tonumber(Options.MaxTowers.Value) or 20) then return false end
    local Units = GetEquippedUnits()
    if #Units == 0 then return false end
    local Points = GetPlacementPoints()
    if #Points == 0 then return false end
    local Unit = Units[math.random(1, #Units)]
    local Point = Points[math.random(1, #Points)]
    -- Yolun kenarina kaydirma (sag/sol donusumlu)
    local Offset = tonumber(Options.PathOffset and Options.PathOffset.Value) or 0
    local Side = (Count % 2 == 0) and 1 or -1
    local CF = Point.CFrame * CFrame.new(Offset * Side, 0, 0)
    return Fire("TowerAdd", {
        Name = Unit.Name, UnitId = Unit.UnitId,
        Pos = CF.Position, CFrame = CF,
    })
end

-- // Kule yardimcilari // ---------------------------------------------------
local function ForEachTower(Fn)
    local Folder = GetPlacedTowerModels()
    if not Folder then return 0 end
    local Count = 0
    for _, Model in ipairs(Folder:GetChildren()) do
        if Model:IsA("Model") then
            Count += 1
            Fn(Model)
        end
    end
    return Count
end

local function UpgradeAll()
    ForEachTower(function(Model) Fire("TowerUpgrade", { Id = Model.Name }) end)
end
local function TargetAll()
    ForEachTower(function(Model) Fire("TowerTarget", { Id = Model.Name }) end)
end
local function SellExcess()
    local Max = tonumber(Options.MaxTowers.Value) or 20
    local Models = {}
    ForEachTower(function(Model) table.insert(Models, Model) end)
    if #Models <= Max then return end
    -- Live towers expose no Level attribute (only HeadsActive/OriginalPos), so
    -- only sort when the game actually provides one; otherwise keep folder order.
    local HasLevel = false
    for _, Model in ipairs(Models) do
        if tonumber(Model:GetAttribute("Level") or Model:GetAttribute("Tier")) ~= nil then
            HasLevel = true
            break
        end
    end
    if HasLevel then
        table.sort(Models, function(A, B)
            local LevelA = tonumber(A:GetAttribute("Level") or A:GetAttribute("Tier")) or 0
            local LevelB = tonumber(B:GetAttribute("Level") or B:GetAttribute("Tier")) or 0
            return LevelA < LevelB
        end)
    end
    for Index = 1, #Models - Max do
        Fire("TowerSell", { Id = Models[Index].Name })
        task.wait(0.2)
    end
end

-- // Ana dongu // -----------------------------------------------------------
local function GetHumanoid()
    local Char = LocalPlayer.Character
    return Char and Char:FindFirstChildOfClass("Humanoid") or nil
end

-- Original movement values, so turning the toggles off (or unloading) restores
-- what the player had instead of hardcoding 16/50.
local OriginalWalk = setmetatable({}, { __mode = "k" })
local OriginalJump = setmetatable({}, { __mode = "k" })
local OriginalUseJump = setmetatable({}, { __mode = "k" })

task.spawn(function()
    local LastUpgrade, LastTarget, LastPlace, LastSkip, LastSummon, LastEsp, LastSell, LastAgain = 0, 0, 0, 0, 0, 0, 0, 0
    local PlacedSinceUpgrade = 0
    while not Unloaded do
        task.wait(0.1)
        local Now = os.clock()

        -- Notifications are created here: this thread was spawned at load time and
        -- keeps the full capabilities that callback threads lack on some executors.
        while #NotifyQueue > 0 do
            local Message = table.remove(NotifyQueue, 1)
            pcall(function() Library:Notify(Message) end)
        end

        -- Auto Play: N yerleştir -> 1 upgrade -> döngü
        if ToggleOn("AutoPlay") and Now - LastPlace > 0.5 then
            LastPlace = Now
            local Every = math.max(1, tonumber(Options.UpgradeEvery.Value) or 3)
            if PlacedSinceUpgrade >= Every then
                local Models = {}
                ForEachTower(function(M) table.insert(Models, M) end)
                if #Models > 0 then
                    local M = Models[math.random(1, #Models)]
                    Fire("TowerUpgrade", { Id = M.Name })
                    PlacedSinceUpgrade = 0
                end
            elseif PlaceOne() then
                PlacedSinceUpgrade += 1
            end
        end

        -- Auto Upgrade
        if ToggleOn("AutoUpgrade") and Now - LastUpgrade > 0.4 then
            LastUpgrade = Now
            UpgradeAll()
        end

        -- Auto Target
        if ToggleOn("AutoTarget") and Now - LastTarget > 0.4 then
            LastTarget = Now
            TargetAll()
        end

        -- Auto Sell (over limit)
        if ToggleOn("AutoSell") and Now - LastSell > 1 then
            LastSell = Now
            SellExcess()
        end

        -- Auto Wave Skip
        if ToggleOn("AutoWaveSkip") and Now - LastSkip > 1 then
            LastSkip = Now
            Fire("WaveSkip")
        end

        -- Auto Summon. The game exposes OpenCrate as a RemoteFunction; SummonTowers
        -- was assumed and does not exist in this place.
        if ToggleOn("AutoSummon") and Now - LastSummon > 2.2 then
            LastSummon = Now
            if Remote("SummonTowers") then
                Invoke("SummonTowers", "Basic Crate", 1)
            elseif Remote("OpenCrate") then
                -- RemoteFunction, not an event.
                Invoke("OpenCrate", "Basic Crate", 1)
            end
        end

        -- Auto Play Again (lobby). Its own timer: sharing LastSkip fired this
        -- every 0.1s because nothing reset that timestamp while wave skip was off.
        if ToggleOn("AutoPlayAgain") and Now - LastAgain > 3 then
            LastAgain = Now
            Fire("PlayAgain")
        end

        -- ESP refresh
        if Now - LastEsp > 1 then
            LastEsp = Now
            RefreshTowerESP()
            RefreshEnemyESP()
            RefreshPlayerESP()
        end

        -- WalkSpeed / JumpPower
        local Hum = GetHumanoid()
        if Hum then
            if ToggleOn("TDWalkSpeed") then
                if OriginalWalk[Hum] == nil then OriginalWalk[Hum] = Hum.WalkSpeed end
                local Speed = tonumber(Options.TDWalkSpeedValue.Value) or 16
                if Hum.WalkSpeed ~= Speed then Hum.WalkSpeed = Speed end
            else
                local Original = OriginalWalk[Hum]
                if Original ~= nil then
                    Hum.WalkSpeed = Original
                    OriginalWalk[Hum] = nil
                end
            end
            if ToggleOn("TDJumpPower") then
                if OriginalJump[Hum] == nil then
                    OriginalJump[Hum] = Hum.JumpPower
                    OriginalUseJump[Hum] = Hum.UseJumpPower
                end
                local Power = tonumber(Options.TDJumpPowerValue.Value) or 50
                if not Hum.UseJumpPower then Hum.UseJumpPower = true end
                if Hum.JumpPower ~= Power then Hum.JumpPower = Power end
            elseif OriginalJump[Hum] ~= nil then
                local Power, UseJumpPower = OriginalJump[Hum], OriginalUseJump[Hum]
                OriginalJump[Hum], OriginalUseJump[Hum] = nil, nil
                pcall(function()
                    Hum.JumpPower = Power
                    Hum.UseJumpPower = UseJumpPower
                end)
            end
        end
    end
end)

-- // Unload // --------------------------------------------------------------
Library:OnUnload(function()
    Unloaded = true
    for _, Conn in ipairs(Connections) do
        pcall(function() Conn:Disconnect() end)
    end
    for Object in pairs(TrackedESP) do
        if Abysall and Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:RemoveESP(Object) end) end
    end
    TrackedESP = {}
    ESPText, ESPColor = {}, {}
    for Humanoid, Speed in pairs(OriginalWalk) do
        pcall(function() Humanoid.WalkSpeed = Speed end)
    end
    for Humanoid, Power in pairs(OriginalJump) do
        local UseJumpPower = OriginalUseJump[Humanoid]
        pcall(function()
            Humanoid.JumpPower = Power
            Humanoid.UseJumpPower = UseJumpPower
        end)
    end
    table.clear(OriginalWalk)
    table.clear(OriginalJump)
    table.clear(OriginalUseJump)
    if Abysall.ESPLibrary then pcall(function() Abysall.ESPLibrary:Unload() end) end
    if type(Abysall.AddonDisablers) == "table" then
        for _, D in ipairs(Abysall.AddonDisablers) do
            pcall(function() if D.Fn then D.Fn() end end)
        end
        Abysall.AddonDisablers = nil
    end
    pcall(function() getgenv().abysall = nil end)
    pcall(function() getgenv().mspaint = nil end)
    getgenv().Abysall = nil
end)

Abysall.Interface.ApplySettingsTab(Window)
pcall(function() Abysall.Interface.SaveManager:SetAutoloadConfig("autoload") end)
Abysall.Interface.ApplyAddons(Window, "cameramantd")
Library:Notify("Cameraman Tower Defense destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")