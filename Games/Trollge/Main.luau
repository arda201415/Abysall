-- Abysall Hub | Trollge Rebirth ([WORKSHOP] Trollge Rebirth, NoTitle Studios)
-- PlaceId: 130031996774546
-- Not: ability cooldown'lari client tarafta tutulan degerlerdir; server
-- dogrulamaliysa NoCooldown ise yaramaz. Once F9 dump + tek tek dene.

local LoadStart = tick()
Abysall.SavePath = "Trollge"

local Library = Abysall.Interface.Library
local SaveManager = Abysall.Interface.SaveManager
local ThemeManager = Abysall.Interface.ThemeManager

local Toggles = Library.Toggles
local Options = Library.Options

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

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

Services.Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Services.Workspace.CurrentCamera
end)

local function CheckCompat(Array)
    for _, Name in pairs(Array) do
        if not Abysall.Environment[Name] then
            return false
        end
    end
    return true
end

local Connections = {}
local function TrackConn(Conn)
    table.insert(Connections, Conn)
    return Conn
end

local Window = Library:CreateWindow({
    Title = "Abysall Hub | Trollge Rebirth",
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
    Combat = Window:AddTab("Combat", "swords"),
    Farm = Window:AddTab("Farm", "wheat"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Misc = Window:AddTab("Misc", "house"),
}

local Groupboxes = {}

-- // Combat: NoCooldown (client-tarafli supurucu) //
Groupboxes.Combat_CD = Tabs.Combat:AddLeftGroupbox("NoCooldown")

Groupboxes.Combat_CD:AddToggle("NoCooldown", {
    Text = "NoCooldown", Default = false,
    Tooltip = "Karakterdeki ve GUI'deki cooldown degerlerini surekli sifirlar. Server dogrulamaliysa ise yaramaz.",
})
Groupboxes.Combat_CD:AddLabel("Server kontrol ediyorsa calismaz.", true)

local function LooksLikeCooldown(Name)
    local N = string.lower(tostring(Name))
    if N:find("cooldown") or N:find("cool_down") or N:find("skillcd") then return true end
    if N == "cd" or N:sub(1, 3) == "cd_" or N:sub(-3) == "_cd" or N:find("_cd_", 1, true) then return true end
    if N:match("^cd%d*$") or N:match("cd%d*$") then return true end
    return false
end

local function ClearCooldowns()
    local Char = LocalPlayer.Character
    local Targets = {}
    if Char then table.insert(Targets, Char) end
    table.insert(Targets, LocalPlayer)
    local Gui = LocalPlayer:FindFirstChild("PlayerGui")
    if Gui then table.insert(Targets, Gui) end

    for _, Root in ipairs(Targets) do
        -- attribute'lar
        local OkAttr, Attrs = pcall(function() return Root:GetAttributes() end)
        if OkAttr and type(Attrs) == "table" then
            for Key in pairs(Attrs) do
                if LooksLikeCooldown(Key) then
                    pcall(function() Root:SetAttribute(Key, 0) end)
                end
            end
        end
        -- deger instance'lari (NumberValue / IntValue)
        for _, Desc in ipairs(Root:GetDescendants()) do
            if Desc:IsA("NumberValue") or Desc:IsA("IntValue") then
                if LooksLikeCooldown(Desc.Name) and Desc.Value ~= 0 then
                    pcall(function() Desc.Value = 0 end)
                end
            elseif Desc:IsA("TextLabel") or Desc:IsA("TextButton") then
                -- "12.4s" gibi geri sayim yazilari (sadece gorunum)
                if LooksLikeCooldown(Desc.Name) and Desc.Text:match("%d") then
                    pcall(function() Desc.Text = "Ready" end)
                end
            end
        end
    end
end

local SweepAcc, SweepRate = 0, 0.1
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if Toggles.NoCooldown and Toggles.NoCooldown.Value then
        SweepAcc = SweepAcc + Delta
        if SweepAcc >= SweepRate then
            SweepAcc = 0
            pcall(ClearCooldowns)
        end
    else
        SweepAcc = SweepRate
    end
end))

-- // Combat: Ability Spy (dogru remote + arglari bulmak icin) //
local RefireLast, DumpCooldownValues
Groupboxes.Combat_Spy = Tabs.Combat:AddLeftGroupbox("Ability Spy")

Groupboxes.Combat_Spy:AddToggle("LogAbilityArgs", {
    Text = "Log Ability (F9)", Default = false,
    Tooltip = "Ability kullanirken ateslenen remote + argumanlari F9'a ve hafizaya kaydeder. 1 kez normal ability kullan.",
})
Groupboxes.Combat_Spy:AddButton({
    Text = "Son Ability'yi Atesle",
    DoubleClick = false,
    Func = function() RefireLast() end,
})
Groupboxes.Combat_Spy:AddToggle("SpamLastAbility", {
    Text = "Spam Son Ability", Default = false,
    Tooltip = "Kaydedilen son ability'yi araliklarla tekrar atesler.",
})
Groupboxes.Combat_Spy:AddSlider("SpamInterval", {
    Text = "Spam Araligi (sn)", Min = 0.2, Max = 5, Default = 1, Rounding = 1, Compact = true,
})
Groupboxes.Combat_Spy:AddButton({
    Text = "Dump Cooldown Degerleri (F9)",
    DoubleClick = false,
    Func = function() DumpCooldownValues() end,
})

local LastRecorded, LastLogAt, InternalFire, HookInstalled = nil, {}, false, false

local function InstallSpy()
    if HookInstalled then return end
    if not CheckCompat({ "hookmetamethod", "getnamecallmethod", "newcclosure" }) then
        Library:Notify("Executor hook desteklemiyor.")
        return
    end
    HookInstalled = true
    local Old
    Old = hookmetamethod(game, "__namecall", newcclosure(function(Self, ...)
        local Method = getnamecallmethod()
        if Method == "FireServer" and typeof(Self) == "Instance" and Self:IsA("RemoteEvent") then
            if not InternalFire and Toggles.LogAbilityArgs and Toggles.LogAbilityArgs.Value then
                local Nm = Self:GetFullName()
                local Now = tick()
                if not LastLogAt[Nm] or Now - LastLogAt[Nm] > 2 then
                    LastLogAt[Nm] = Now
                    local Args = { ... }
                    LastRecorded = { Name = Nm, Short = Self.Name, Remote = Self, Args = Args }
                    print("[Abysall-Spy] " .. Nm)
                    for I, A in ipairs(Args) do
                        print("  arg" .. I .. " " .. typeof(A) .. " = " .. tostring(A):sub(1, 160))
                    end
                    Library:Notify("Kaydedildi: " .. Self.Name)
                end
            end
        end
        return Old(Self, ...)
    end))
end
Toggles.LogAbilityArgs:OnChanged(function(Value)
    if Value then InstallSpy() end
end)

RefireLast = function()
    if not LastRecorded or not LastRecorded.Remote then
        Library:Notify("Once log acikken ability kullan.")
        return
    end
    local R, Args = LastRecorded.Remote, LastRecorded.Args
    InternalFire = true
    local Ok, Err = pcall(function() R:FireServer(table.unpack(Args)) end)
    InternalFire = false
    if Ok then
        Library:Notify("Ateslendi: " .. tostring(LastRecorded.Short))
    else
        Library:Notify("Hata: " .. tostring(Err):sub(1, 80))
    end
end

DumpCooldownValues = function()
    local Char = LocalPlayer.Character
    local function Scan(Root, Tag)
        local OkAttr, Attrs = pcall(function() return Root:GetAttributes() end)
        if OkAttr and type(Attrs) == "table" then
            for Key, Val in pairs(Attrs) do
                if LooksLikeCooldown(Key) then
                    print("[Abysall-CD] attr " .. Tag .. "." .. tostring(Key) .. " = " .. tostring(Val))
                end
            end
        end
        for _, Desc in ipairs(Root:GetDescendants()) do
            if (Desc:IsA("NumberValue") or Desc:IsA("IntValue")) and LooksLikeCooldown(Desc.Name) then
                print("[Abysall-CD] value " .. Desc:GetFullName() .. " = " .. tostring(Desc.Value))
            end
        end
    end
    if Char then Scan(Char, "char") end
    Scan(LocalPlayer, "player")
    local Gui = LocalPlayer:FindFirstChild("PlayerGui")
    if Gui then Scan(Gui, "gui") end
    Library:Notify("Cooldown degerleri F9'da.")
end

local SpamAcc = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if Toggles.SpamLastAbility and Toggles.SpamLastAbility.Value and LastRecorded then
        SpamAcc = SpamAcc + Delta
        local Interval = (Options.SpamInterval and Options.SpamInterval.Value) or 1
        if SpamAcc >= Interval then
            SpamAcc = 0
            RefireLast()
        end
    else
        SpamAcc = 0
    end
end))

-- // Combat: Remote araclari (dump'unda cikan 116 remote) //
Groupboxes.Combat_Remotes = Tabs.Combat:AddRightGroupbox("Remotes")

local function FindRemote(Name)
    local RS = Services.ReplicatedStorage
    local Direct = RS:FindFirstChild(Name, true)
    if Direct and (Direct:IsA("RemoteEvent") or Direct:IsA("RemoteFunction")) then
        return Direct
    end
    return nil
end

local function FireRemote(Name)
    local R = FindRemote(Name)
    if not R then
        Library:Notify("Bulunamadi: " .. Name)
        return
    end
    local Ok, Err = pcall(function()
        if R:IsA("RemoteEvent") then
            R:FireServer()
        else
            R:InvokeServer()
        end
    end)
    if Ok then
        Library:Notify("Ateslendi: " .. Name)
    else
        Library:Notify("Hata: " .. tostring(Err):sub(1, 80))
    end
end

Groupboxes.Combat_Remotes:AddButton({
    Text = "Dump Remotes (F9'a bas)",
    DoubleClick = false,
    Func = function()
        for _, Obj in pairs(Services.ReplicatedStorage:GetDescendants()) do
            if Obj:IsA("RemoteEvent") or Obj:IsA("RemoteFunction") then
                print("[Abysall-Dump] " .. Obj.ClassName .. " | " .. Obj:GetFullName())
            end
        end
        Library:Notify("Dump konsola yazildi (F9).")
    end
})
Groupboxes.Combat_Remotes:AddDivider()
Groupboxes.Combat_Remotes:AddButton({
    Text = "Open Bags (TopEvents)",
    DoubleClick = false,
    Func = function() FireRemote("OpenBags") end,
})
Groupboxes.Combat_Remotes:AddButton({
    Text = "Open All (TopEvents)",
    DoubleClick = false,
    Func = function() FireRemote("Openall") end,
})
Groupboxes.Combat_Remotes:AddLabel("ClearInv bilerek yok: envanteri siler.", true)

-- // Farm: otomatik torba acma //
Groupboxes.Farm_Bags = Tabs.Farm:AddLeftGroupbox("Auto Farm")

Groupboxes.Farm_Bags:AddToggle("AutoOpenBags", {
    Text = "Auto Open Bags", Default = false,
    Tooltip = "Belirli araliklarla TopEvents.OpenBags atesler.",
})
Groupboxes.Farm_Bags:AddSlider("AutoOpenBagsDelay", {
    Text = "Acma Araligi (sn)", Min = 2, Max = 120, Default = 15, Rounding = 0, Compact = true,
})

local BagAcc = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if Toggles.AutoOpenBags and Toggles.AutoOpenBags.Value then
        BagAcc = BagAcc + Delta
        local Delay = (Options.AutoOpenBagsDelay and Options.AutoOpenBagsDelay.Value) or 15
        if BagAcc >= Delay then
            BagAcc = 0
            local R = FindRemote("OpenBags")
            if R and R:IsA("RemoteEvent") then
                pcall(function() R:FireServer() end)
            end
        end
    else
        BagAcc = 0
    end
end))

-- // Visuals: Player ESP (mevcut ESP kutuphanesi ile) //
Groupboxes.Visuals_ESP = Tabs.Visuals:AddLeftGroupbox("Player ESP")

Groupboxes.Visuals_ESP:AddToggle("PlayerESP", {
    Text = "Player ESP", Default = false, Tooltip = "Oyunculari highlight + isim ile gosterir.",
})
Toggles.PlayerESP:AddColorPicker("PlayerESPColor", {
    Text = "ESP Rengi", Default = Color3.fromRGB(255, 0, 0), Transparency = 0,
})
Groupboxes.Visuals_ESP:AddToggle("ESPTeamCheck", {
    Text = "Team Check", Default = true,
})

local function ShouldESP(Player)
    if Player == LocalPlayer then return false end
    if not Player.Character then return false end
    if Toggles.ESPTeamCheck and Toggles.ESPTeamCheck.Value then
        if LocalPlayer.Team ~= nil and Player.Team ~= nil and Player.Team == LocalPlayer.Team then
            return false
        end
    end
    return true
end

local function AddPlayerESP(Data)
    pcall(function()
        Abysall.ESPLibrary:AddESP(Data)
        Data.Object.Destroying:Once(function()
            if Abysall then Abysall.ESPLibrary:RemoveESP(Data.Object) end
        end)
    end)
end

Toggles.PlayerESP:OnChanged(function(Value)
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player.Character then
            if Value and ShouldESP(Player) then
                AddPlayerESP({ Object = Player.Character, Text = Player.Name, Color = Options.PlayerESPColor.Value })
            else
                Abysall.ESPLibrary:RemoveESP(Player.Character)
            end
        end
    end
end)
Options.PlayerESPColor:OnChanged(function(Value)
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player.Character then
            Abysall.ESPLibrary:UpdateObjectColor(Player.Character, Value)
        end
    end
end)

TrackConn(Services.Players.PlayerAdded:Connect(function(Player)
    Player.CharacterAdded:Connect(function(Char)
        task.wait(1)
        if Toggles.PlayerESP.Value and ShouldESP(Player) then
            AddPlayerESP({ Object = Char, Text = Player.Name, Color = Options.PlayerESPColor.Value })
        end
    end)
end))
for _, Player in pairs(Services.Players:GetPlayers()) do
    if Player ~= LocalPlayer then
        Player.CharacterAdded:Connect(function(Char)
            task.wait(1)
            if Toggles.PlayerESP.Value and ShouldESP(Player) then
                AddPlayerESP({ Object = Char, Text = Player.Name, Color = Options.PlayerESPColor.Value })
            end
        end)
    end
end

Groupboxes.Visuals_Settings = Tabs.Visuals:AddRightGroupbox("ESP Settings")
Groupboxes.Visuals_Settings:AddToggle("ESPShowDistance", { Text = "Show Distance", Default = true })
Groupboxes.Visuals_Settings:AddToggle("ESPTracers", { Text = "Tracers", Default = false })
Groupboxes.Visuals_Settings:AddToggle("ESPArrows", { Text = "Arrows", Default = false })
Toggles.ESPShowDistance:OnChanged(function(V) Abysall.ESPLibrary:SetShowDistance(V) end)
Toggles.ESPTracers:OnChanged(function(V) Abysall.ESPLibrary:SetTracers(V) end)
Toggles.ESPArrows:OnChanged(function(V) Abysall.ESPLibrary:SetArrows(V) end)
Abysall.ESPLibrary:SetShowDistance(true)

-- // Misc: hareket //
Groupboxes.Misc_Move = Tabs.Misc:AddLeftGroupbox("Movement")
Groupboxes.Misc_Move:AddSlider("WalkSpeedVal", {
    Text = "WalkSpeed", Min = 16, Max = 200, Default = 16, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("WalkSpeedOn", { Text = "Speed", Default = false })
Groupboxes.Misc_Move:AddToggle("InfiniteJump", {
    Text = "Infinite Jump", Default = false, Tooltip = "Havada ziplamaya izin verir.",
})

TrackConn(Services.RunService.RenderStepped:Connect(function()
    if Toggles.WalkSpeedOn and Toggles.WalkSpeedOn.Value and LocalPlayer.Character then
        local Hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Hum then Hum.WalkSpeed = Options.WalkSpeedVal.Value end
    end
end))

TrackConn(Services.UserInputService.JumpRequest:Connect(function()
    if Toggles.InfiniteJump and Toggles.InfiniteJump.Value and LocalPlayer.Character then
        local Hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Hum then Hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

Library:OnUnload(function()
    for _, Conn in ipairs(Connections) do
        pcall(function() Conn:Disconnect() end)
    end
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
Abysall.Interface.ApplyAddons(Window, "trollge")
Library:Notify("Trollge Rebirth destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")
