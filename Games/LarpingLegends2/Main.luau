-- Abysall Hub | Larping Legends 2
-- PlaceId: 7331291885
-- Remote'lar ReplicatedStorage.rEvents.* altinda; cogu argsiz cagrilmiyor
-- (InvokeServer(tablo, ...)). Dogru format icin Ability Spy kullanilir.

local LoadStart = tick()
Abysall.SavePath = "LarpingLegends2"

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

local function GetStat(Name)
    local Ls = LocalPlayer:FindFirstChild("leaderstats")
    local V = Ls and Ls:FindFirstChild(Name)
    return V and V.Value or nil
end

local function StatLabel(Base)
    local Parts = { Base }
    local Hp = GetStat("Health") or GetStat("HP")
    if Hp then table.insert(Parts, tostring(math.floor(Hp + 0.5))) end
    local Cash = GetStat("Cash") or GetStat("Coins") or GetStat("Money")
    if Cash then table.insert(Parts, tostring(math.floor(Cash + 0.5))) end
    return table.concat(Parts, " [") .. "]"
end

local Window = Library:CreateWindow({
    Title = "Abysall Hub | Larping Legends 2",
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

-- // Combat: Aimbot //
Groupboxes.Combat_Aim = Tabs.Combat:AddLeftGroupbox("Aimbot")

Groupboxes.Combat_Aim:AddToggle("AimbotEnabled", {
    Text = "Aimbot", Default = false,
    Tooltip = "Tus basiliyken kamerayi fareye en yakin dusmana kilitler.",
})
Toggles.AimbotEnabled:AddKeyPicker("AimbotKey", {
    Text = "Aimbot Key", Default = "Q", Mode = "Hold", SyncToggleState = false,
})
Groupboxes.Combat_Aim:AddToggle("AimbotUseRMB", {
    Text = "Sag Click ile de calissin", Default = true,
})
Groupboxes.Combat_Aim:AddDropdown("AimbotPart", {
    Text = "Hedef Parca", Values = { "Head", "HumanoidRootPart" }, Default = 1,
})
Groupboxes.Combat_Aim:AddSlider("AimbotFOV", {
    Text = "FOV", Min = 10, Max = 1000, Default = 200, Rounding = 0, Compact = true,
})
Groupboxes.Combat_Aim:AddToggle("AimbotTeamCheck", { Text = "Team Check", Default = true })
Groupboxes.Combat_Aim:AddToggle("AimbotWallCheck", { Text = "Wall Check", Default = false })
Groupboxes.Combat_Aim:AddSlider("AimSmooth", {
    Text = "Yumusatma", Min = 1, Max = 20, Default = 1, Rounding = 0, Compact = true,
})
Groupboxes.Combat_Aim:AddToggle("AimSticky", { Text = "Sticky Target", Default = true })
Groupboxes.Combat_Aim:AddToggle("AimFOVCircle", { Text = "FOV Dairesi", Default = true })

local function AimIsEnemy(Player)
    if Player == LocalPlayer then return false end
    if not Player.Character then return false end
    if Player:GetAttribute("Alive") == false then return false end
    if Toggles.AimbotTeamCheck and Toggles.AimbotTeamCheck.Value then
        if LocalPlayer.Team ~= nil and Player.Team ~= nil and Player.Team == LocalPlayer.Team then
            return false
        end
    end
    local Hum = Player.Character:FindFirstChildOfClass("Humanoid")
    if Hum and Hum.Health <= 0 then return false end
    return true
end

local function AimIsVisible(Part)
    if not Toggles.AimbotWallCheck or not Toggles.AimbotWallCheck.Value then return true end
    local Ok, Res = pcall(function()
        local RayParams = RaycastParams.new()
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        RayParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
        return Services.Workspace:Raycast(Camera.CFrame.Position, (Part.Position - Camera.CFrame.Position), RayParams)
    end)
    if not Ok or not Res then return true end
    return Res.Instance:IsDescendantOf(Part.Parent)
end

local function AimGetMouse()
    local L = Services.UserInputService:GetMouseLocation()
    return Vector2.new(L.X, L.Y)
end

local function AimGetTarget()
    local Best, BestDist = nil, Options.AimbotFOV and Options.AimbotFOV.Value or 200
    local PartName = Options.AimbotPart and Options.AimbotPart.Value or "Head"
    local Mouse = AimGetMouse()
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if AimIsEnemy(Player) then
            local Part = Player.Character:FindFirstChild(PartName)
            if Part then
                local Pos, On = Camera:WorldToViewportPoint(Part.Position)
                if On then
                    local D = (Vector2.new(Pos.X, Pos.Y) - Mouse).Magnitude
                    if D < BestDist and AimIsVisible(Part) then BestDist = D Best = Part end
                end
            end
        end
    end
    return Best
end

TrackConn(Services.RunService.RenderStepped:Connect(function()
    pcall(function()
        if not _G.SIM_FOVCircle and typeof(Drawing) == "function" then
            local C = Drawing.new("Circle")
            C.Thickness = 1
            C.NumSides = 64
            C.Filled = false
            C.Color = Color3.fromRGB(255, 255, 255)
            _G.SIM_FOVCircle = C
        end
        if _G.SIM_FOVCircle then
            local Show = Toggles.AimbotEnabled and Toggles.AimbotEnabled.Value and Toggles.AimFOVCircle and Toggles.AimFOVCircle.Value
            _G.SIM_FOVCircle.Visible = Show or false
            if Show then
                _G.SIM_FOVCircle.Position = AimGetMouse()
                _G.SIM_FOVCircle.Radius = Options.AimbotFOV and Options.AimbotFOV.Value or 200
            end
        end
    end)

    if Toggles.AimbotEnabled and Toggles.AimbotEnabled.Value then
        local HoldingKey = Options.AimbotKey and Options.AimbotKey:GetState()
        local HoldingRMB = Toggles.AimbotUseRMB and Toggles.AimbotUseRMB.Value and Services.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if HoldingKey or HoldingRMB then
            local Target = AimGetTarget()
            local FOV = (Options.AimbotFOV and Options.AimbotFOV.Value) or 200
            if Toggles.AimSticky and Toggles.AimSticky.Value and _G.SIM_Locked and _G.SIM_Locked.Parent then
                local LP = _G.SIM_Locked
                local Pos, On = Camera:WorldToViewportPoint(LP.Position)
                if On and (Vector2.new(Pos.X, Pos.Y) - AimGetMouse()).Magnitude <= (FOV + 50) then
                    Target = LP
                else
                    _G.SIM_Locked = nil
                end
            end
            if Target then
                _G.SIM_Locked = Target
                local Goal = CFrame.new(Camera.CFrame.Position, Target.Position)
                local Smooth = (Options.AimSmooth and Options.AimSmooth.Value) or 1
                Camera.CFrame = (Smooth <= 1) and Goal or Camera.CFrame:Lerp(Goal, 1 / Smooth)
            end
        else
            _G.SIM_Locked = nil
        end
    end
end))

-- // Combat: Kill Aura //
Groupboxes.Combat_Aura = Tabs.Combat:AddRightGroupbox("Kill Aura")

Groupboxes.Combat_Aura:AddToggle("KillAura", {
    Text = "Kill Aura", Default = false,
    Tooltip = "Menzil icindeki hedeflere hasar verir.",
})
Groupboxes.Combat_Aura:AddSlider("KillAuraRange", {
    Text = "Menzil", Min = 5, Max = 200, Default = 30, Rounding = 0, Compact = true,
})
Groupboxes.Combat_Aura:AddSlider("KillAuraDamage", {
    Text = "Hasar", Min = 1, Max = 100, Default = 25, Rounding = 0, Compact = true,
})
Groupboxes.Combat_Aura:AddSlider("KillAuraInterval", {
    Text = "Aralik (sn)", Min = 0.1, Max = 3, Default = 0.5, Rounding = 1, Compact = true,
})
Groupboxes.Combat_Aura:AddToggle("KillAuraAllTargets", { Text = "Tum Menzil", Default = true })
Groupboxes.Combat_Aura:AddToggle("KillAuraTeamCheck", { Text = "Team Check", Default = true })
Groupboxes.Combat_Aura:AddToggle("KillAuraWallCheck", { Text = "Wall Check", Default = false })

local function AuraIsEnemy(Player)
    if Player == LocalPlayer then return false end
    if not Player.Character then return false end
    if Player:GetAttribute("Alive") == false then return false end
    if Toggles.KillAuraTeamCheck and Toggles.KillAuraTeamCheck.Value then
        if LocalPlayer.Team ~= nil and Player.Team ~= nil and Player.Team == LocalPlayer.Team then
            return false
        end
    end
    local Hum = Player.Character:FindFirstChildOfClass("Humanoid")
    if Hum and Hum.Health <= 0 then return false end
    return true
end

local AuraAccum = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if not (Toggles.KillAura and Toggles.KillAura.Value) then return end
    local Char = LocalPlayer.Character
    local HRP = Char and Char:FindFirstChild("HumanoidRootPart")
    if not HRP then return end
    AuraAccum = AuraAccum + Delta
    local Interval = (Options.KillAuraInterval and Options.KillAuraInterval.Value) or 0.5
    if AuraAccum < Interval then return end
    AuraAccum = 0

    local Range = (Options.KillAuraRange and Options.KillAuraRange.Value) or 30
    local Damage = (Options.KillAuraDamage and Options.KillAuraDamage.Value) or 25
    local OnlyClosest = not (Toggles.KillAuraAllTargets and Toggles.KillAuraAllTargets.Value)
    local Targets, Best, BestDist = {}, nil, Range

    for _, Player in pairs(Services.Players:GetPlayers()) do
        if AuraIsEnemy(Player) then
            local Part = Player.Character:FindFirstChild("HumanoidRootPart")
            if Part then
                local D = (Part.Position - HRP.Position).Magnitude
                if D <= Range then
                    if OnlyClosest then
                        if D < BestDist then Best, BestDist = Player, D end
                    else
                        table.insert(Targets, Player)
                    end
                end
            end
        end
    end
    if OnlyClosest and Best then table.insert(Targets, Best) end
    for _, Player in ipairs(Targets) do
        local Hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if Hum and Hum.Health > 0 then
            pcall(function() Hum:TakeDamage(Damage) end)
            if Hum.Health > 0 then Hum.Health = math.max(0, Hum.Health - Damage) end
        end
    end
end))

-- // Farm: remote presetleri //
Groupboxes.Farm_Remotes = Tabs.Farm:AddLeftGroupbox("Remotes")

local function FindRemote(Name)
    local Found = Services.ReplicatedStorage:FindFirstChild(Name, true)
    if Found and (Found:IsA("RemoteEvent") or Found:IsA("RemoteFunction")) then
        return Found
    end
    return nil
end

local InternalFire = false

local function FireNamed(Name, ...)
    local R = FindRemote(Name)
    if not R then
        Library:Notify("Bulunamadi: " .. Name)
        return
    end
    local Args = { ... }
    InternalFire = true
    local Ok, Err = pcall(function()
        if R:IsA("RemoteEvent") then R:FireServer(table.unpack(Args))
        else R:InvokeServer(table.unpack(Args)) end
    end)
    InternalFire = false
    if Ok then Library:Notify("Ateslendi: " .. Name)
    else Library:Notify("Hata: " .. tostring(Err):sub(1, 80)) end
end

Groupboxes.Farm_Remotes:AddButton({
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
Groupboxes.Farm_Remotes:AddButton({ Text = "Pet Equip", Func = function() FireNamed("equipPetEvent") end })
Groupboxes.Farm_Remotes:AddButton({ Text = "Pet Sell", Func = function() FireNamed("sellPetEvent") end })
Groupboxes.Farm_Remotes:AddButton({ Text = "Brawl", Func = function() FireNamed("brawlEvent") end })
Groupboxes.Farm_Remotes:AddButton({ Text = "Purchase", Func = function() FireNamed("purchaseEvent") end })
Groupboxes.Farm_Remotes:AddButton({ Text = "Machine Interact", Func = function() FireNamed("machineInteractRemote") end })
Groupboxes.Farm_Remotes:AddButton({ Text = "Open Crystal", Func = function() FireNamed("openCrystalRemote") end })
Groupboxes.Farm_Remotes:AddButton({ Text = "Check Chest", Func = function() FireNamed("checkChestRemote") end })
Groupboxes.Farm_Remotes:AddButton({ Text = "Quests", Func = function() FireNamed("questsEvent") end })
Groupboxes.Farm_Remotes:AddButton({ Text = "Show Pets", Func = function() FireNamed("showPetsEvent") end })
Groupboxes.Farm_Remotes:AddLabel("Bunlar argsiz denemeler; dogru format icin Spy.", true)

-- // Farm: auto interaction //
Groupboxes.Farm_Auto = Tabs.Farm:AddRightGroupbox("Auto")

Groupboxes.Farm_Auto:AddToggle("AutoMachine", {
    Text = "Auto Machine Interact", Default = false,
    Tooltip = "Periyodikla machineInteractRemote cagirir.",
})
Groupboxes.Farm_Auto:AddSlider("AutoMachineDelay", {
    Text = "Aralik (sn)", Min = 0.5, Max = 30, Default = 3, Rounding = 1, Compact = true,
})
Groupboxes.Farm_Auto:AddToggle("AutoQuests", {
    Text = "Auto Quests", Default = false,
    Tooltip = "Periyodikla questsEvent cagirir.",
})
Groupboxes.Farm_Auto:AddSlider("AutoQuestsDelay", {
    Text = "Aralik (sn)", Min = 1, Max = 60, Default = 10, Rounding = 0, Compact = true,
})

local AutoAcc = { Machine = 0, Quests = 0 }
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if Toggles.AutoMachine and Toggles.AutoMachine.Value then
        AutoAcc.Machine = AutoAcc.Machine + Delta
        local D = (Options.AutoMachineDelay and Options.AutoMachineDelay.Value) or 3
        if AutoAcc.Machine >= D then
            AutoAcc.Machine = 0
            local R = FindRemote("machineInteractRemote")
            if R then
                InternalFire = true
                pcall(function() if R:IsA("RemoteEvent") then R:FireServer() else R:InvokeServer() end end)
                InternalFire = false
            end
        end
    else
        AutoAcc.Machine = 0
    end

    if Toggles.AutoQuests and Toggles.AutoQuests.Value then
        AutoAcc.Quests = AutoAcc.Quests + Delta
        local D = (Options.AutoQuestsDelay and Options.AutoQuestsDelay.Value) or 10
        if AutoAcc.Quests >= D then
            AutoAcc.Quests = 0
            local R = FindRemote("questsEvent")
            if R then
                InternalFire = true
                pcall(function() if R:IsA("RemoteEvent") then R:FireServer() else R:InvokeServer() end end)
                InternalFire = false
            end
        end
    else
        AutoAcc.Quests = 0
    end
end))

-- // Combat: Ability Spy //
local RefireLast
Groupboxes.Combat_Spy = Tabs.Combat:AddRightGroupbox("Ability Spy")

Groupboxes.Combat_Spy:AddToggle("LogAbilityArgs", {
    Text = "Log Remote (F9)", Default = false,
    Tooltip = "Oyun remote'lari cagrildiginda ad + argumanlari F9'a basar.",
})
Groupboxes.Combat_Spy:AddButton({
    Text = "Son Remote'u Tekrar", DoubleClick = false,
    Func = function() RefireLast() end,
})
Groupboxes.Combat_Spy:AddToggle("SpamLastRemote", { Text = "Spam Son Remote", Default = false })
Groupboxes.Combat_Spy:AddSlider("SpamInterval", {
    Text = "Spam Araligi (sn)", Min = 0.2, Max = 10, Default = 1, Rounding = 1, Compact = true,
})
Groupboxes.Combat_Spy:AddInput("FireRemoteName", {
    Text = "Remote Adi", Default = "", Numeric = false, Finished = false,
    Placeholder = "Orn: rebirthRemote",
})
Groupboxes.Combat_Spy:AddButton({
    Text = "Isimle Atesle (argsiz)", DoubleClick = false,
    Func = function()
        local Name = Options.FireRemoteName and Options.FireRemoteName.Value or ""
        if Name == "" then
            Library:Notify("Once remote adi yaz.")
            return
        end
        FireNamed(Name)
    end
})

local LastRecorded, LastLogAt, HookInstalled = nil, {}, false

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
        local IsFire = Method == "FireServer" and typeof(Self) == "Instance" and Self:IsA("RemoteEvent")
        local IsInvoke = Method == "InvokeServer" and typeof(Self) == "Instance" and Self:IsA("RemoteFunction")
        if IsFire or IsInvoke then
            if not InternalFire and Toggles.LogAbilityArgs and Toggles.LogAbilityArgs.Value then
                local Nm = Method .. " | " .. Self:GetFullName()
                local Now = tick()
                if not LastLogAt[Nm] or Now - LastLogAt[Nm] > 2 then
                    LastLogAt[Nm] = Now
                    local Args = { ... }
                    LastRecorded = { Name = Nm, Short = Self.Name, Remote = Self, Args = Args, IsInvoke = IsInvoke }
                    print("[Abysall-Spy] " .. Nm)
                    for I, A in ipairs(Args) do
                        print("  arg" .. I .. " " .. typeof(A) .. " = " .. tostring(A):sub(1, 160))
                    end
                end
            end
        end
        return Old(Self, ...)
    end))
end
Toggles.LogAbilityArgs:OnChanged(function(Value) if Value then InstallSpy() end end)

RefireLast = function()
    if not LastRecorded or not LastRecorded.Remote then
        Library:Notify("Once log acikken bir islem yap.")
        return
    end
    local R, Args = LastRecorded.Remote, LastRecorded.Args
    InternalFire = true
    local Ok, Err = pcall(function()
        if LastRecorded.IsInvoke then R:InvokeServer(table.unpack(Args))
        else R:FireServer(table.unpack(Args)) end
    end)
    InternalFire = false
    if Ok then Library:Notify("Ateslendi: " .. tostring(LastRecorded.Short))
    else Library:Notify("Hata: " .. tostring(Err):sub(1, 80)) end
end

local SpamAcc = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if Toggles.SpamLastRemote and Toggles.SpamLastRemote.Value and LastRecorded then
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

-- // Visuals: Player ESP //
Groupboxes.Visuals_ESP = Tabs.Visuals:AddLeftGroupbox("Player ESP")

Groupboxes.Visuals_ESP:AddToggle("PlayerESP", { Text = "Player ESP", Default = false })
Toggles.PlayerESP:AddColorPicker("PlayerESPColor", {
    Text = "ESP Rengi", Default = Color3.fromRGB(255, 0, 0), Transparency = 0,
})
Groupboxes.Visuals_ESP:AddToggle("ESPTeamCheck", { Text = "Team Check", Default = true })
Groupboxes.Visuals_ESP:AddToggle("ESPShowStats", {
    Text = "Show Stats", Default = true, Tooltip = "Can / Cash bilgisini etikete ekler.",
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

local StatConns = {}
local function TrackStats(Player, Char)
    local Old = StatConns[Player]
    if Old then pcall(function() Old:Disconnect() end) StatConns[Player] = nil end
    if not (Toggles.ESPShowStats and Toggles.ESPShowStats.Value) then
        Abysall.ESPLibrary:UpdateObjectText(Char, Player.Name)
        return
    end
    local Ls = Player:FindFirstChild("leaderstats")
    if not Ls then
        Abysall.ESPLibrary:UpdateObjectText(Char, Player.Name)
        return
    end
    local function Refresh()
        Abysall.ESPLibrary:UpdateObjectText(Char, StatLabel(Player.DisplayName or Player.Name))
    end
    Refresh()
    local Conns = {}
    for _, Stat in ipairs(Ls:GetChildren()) do
        if Stat:IsA("IntValue") or Stat:IsA("NumberValue") or Stat:IsA("StringValue") then
            table.insert(Conns, Stat:GetPropertyChangedSignal("Value"):Connect(Refresh))
        end
    end
    StatConns[Player] = function()
        for _, C in ipairs(Conns) do pcall(function() C:Disconnect() end) end
    end
end

local function AddPlayerESP(Data)
    pcall(function()
        Abysall.ESPLibrary:AddESP(Data)
        if Data.Player and Data.Object then TrackStats(Data.Player, Data.Object) end
        Data.Object.Destroying:Once(function()
            if Abysall then Abysall.ESPLibrary:RemoveESP(Data.Object) end
        end)
    end)
end

Toggles.PlayerESP:OnChanged(function(Value)
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player.Character then
            if Value and ShouldESP(Player) then
                AddPlayerESP({ Object = Player.Character, Text = Player.Name, Color = Options.PlayerESPColor.Value, Player = Player })
            else
                Abysall.ESPLibrary:RemoveESP(Player.Character)
            end
        end
    end
end)
Options.PlayerESPColor:OnChanged(function(Value)
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player.Character then Abysall.ESPLibrary:UpdateObjectColor(Player.Character, Value) end
    end
end)
Toggles.ESPShowStats:OnChanged(function()
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character and Toggles.PlayerESP.Value and ShouldESP(Player) then
            TrackStats(Player, Player.Character)
        end
    end
end)

TrackConn(Services.Players.PlayerAdded:Connect(function(Player)
    Player.CharacterAdded:Connect(function(Char)
        task.wait(1)
        if Toggles.PlayerESP.Value and ShouldESP(Player) then
            AddPlayerESP({ Object = Char, Text = Player.Name, Color = Options.PlayerESPColor.Value, Player = Player })
        end
    end)
end))
for _, Player in pairs(Services.Players:GetPlayers()) do
    if Player ~= LocalPlayer then
        Player.CharacterAdded:Connect(function(Char)
            task.wait(1)
            if Toggles.PlayerESP.Value and ShouldESP(Player) then
                AddPlayerESP({ Object = Char, Text = Player.Name, Color = Options.PlayerESPColor.Value, Player = Player })
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
    Text = "WalkSpeed", Min = 16, Max = 300, Default = 16, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("WalkSpeedOn", { Text = "Speed", Default = false })
Groupboxes.Misc_Move:AddToggle("InfiniteJump", { Text = "Infinite Jump", Default = false })
Groupboxes.Misc_Move:AddDivider()
Groupboxes.Misc_Move:AddToggle("Fly", { Text = "Fly", Default = false })
Toggles.Fly:AddKeyPicker("FlyKey", { Text = "Fly", Default = "F", Mode = "Toggle", SyncToggleState = true })
Groupboxes.Misc_Move:AddSlider("FlySpeed", {
    Text = "Fly Speed", Min = 0, Max = 300, Default = 60, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("Noclip", { Text = "Noclip", Default = false })
Toggles.Noclip:AddKeyPicker("NoclipKey", { Text = "Noclip", Default = "N", Mode = "Toggle", SyncToggleState = true })

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

local FlyBody = Instance.new("BodyVelocity")
FlyBody.MaxForce = Vector3.new(9e9, 9e9, 9e9)
FlyBody.Velocity = Vector3.zero

local function FlyRoot()
    local Char = LocalPlayer.Character
    if not Char then return nil end
    return Char:FindFirstChild("HumanoidRootPart") or Char:FindFirstChild("UpperTorso") or Char:FindFirstChild("Head")
end

local function FlyDir()
    local Char = LocalPlayer.Character
    local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
    if not Hum or Hum.MoveDirection == Vector3.zero or not Camera then return Vector3.zero end
    local LookFlat = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
    if LookFlat.Magnitude < 0.01 then LookFlat = Vector3.new(0, 0, -1) end
    local FlatFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + LookFlat)
    local Vel = (Camera.CFrame * CFrame.new(FlatFrame:VectorToObjectSpace(Hum.MoveDirection))).Position - Camera.CFrame.Position
    if Vel.Magnitude < 0.01 then return Vector3.zero end
    return Vel.Unit
end

TrackConn(Services.RunService.RenderStepped:Connect(function()
    local R = FlyRoot()
    if Toggles.Fly and Toggles.Fly.Value and R then
        FlyBody.Parent = R
        FlyBody.Velocity = FlyDir() * ((Options.FlySpeed and Options.FlySpeed.Value) or 60)
    elseif FlyBody.Parent then
        FlyBody.Velocity = Vector3.zero
        FlyBody.Parent = nil
    end
end))

TrackConn(Services.RunService.Stepped:Connect(function()
    if Toggles.Noclip and Toggles.Noclip.Value and LocalPlayer.Character then
        for _, P in ipairs(LocalPlayer.Character:GetDescendants()) do
            if P:IsA("BasePart") and P.CanCollide then P.CanCollide = false end
        end
    end
end))

Groupboxes.Misc_World = Tabs.Misc:AddRightGroupbox("World")
Groupboxes.Misc_World:AddToggle("Fullbright", { Text = "Fullbright", Default = false })
Groupboxes.Misc_World:AddToggle("AntiAFK", { Text = "Anti AFK", Default = false })
Groupboxes.Misc_World:AddToggle("NoWeather", {
    Text = "Hava Efektini Kapat", Default = false,
    Tooltip = "MeteorStrike / LightningBolt gibi efektleri engeller.",
})

local NoWeatherConn = nil
Toggles.NoWeather:OnChanged(function(Value)
    if NoWeatherConn then
        pcall(function() NoWeatherConn:Disconnect() end)
        NoWeatherConn = nil
    end
    if Value then
        local function Block()
            for _, N in ipairs({ "MeteorStrike", "LightningBolt", "WeatherThing", "UpdateWeather" }) do
                local R = FindRemote(N)
                if R then
                    pcall(function() R.Parent = nil end)
                end
            end
        end
        Block()
        NoWeatherConn = Services.ReplicatedStorage.DescendantAdded:Connect(function(Obj)
            if Obj:IsA("RemoteEvent") or Obj:IsA("RemoteFunction") then
                if Obj.Name == "MeteorStrike" or Obj.Name == "LightningBolt" or Obj.Name == "UpdateWeather" then
                    pcall(function() Obj.Parent = nil end)
                end
            end
        end)
    end
end)

local OldLight = {}
local function ApplyBright(On)
    local L = Services.Lighting
    if On then
        if OldLight.B == nil then
            OldLight = { B = L.Brightness, C = L.ClockTime, G = L.GlobalShadows, F = L.FogEnd, A = L.Ambient }
        end
        L.Brightness = 2
        L.ClockTime = 14
        L.GlobalShadows = false
        L.FogEnd = 100000
        L.Ambient = Color3.new(1, 1, 1)
    elseif OldLight.B ~= nil then
        L.Brightness = OldLight.B
        L.ClockTime = OldLight.C
        L.GlobalShadows = OldLight.G
        L.FogEnd = OldLight.F
        L.Ambient = OldLight.A
    end
end
Toggles.Fullbright:OnChanged(function(V) pcall(ApplyBright, V) end)

local BrightAcc = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if Toggles.Fullbright and Toggles.Fullbright.Value then
        BrightAcc = BrightAcc + Delta
        if BrightAcc >= 2 then
            BrightAcc = 0
            pcall(ApplyBright, true)
        end
    else
        BrightAcc = 0
    end
end))

local AFKConn = nil
Toggles.AntiAFK:OnChanged(function(Value)
    if Value then
        local Ok, VU = pcall(function() return game:GetService("VirtualUser") end)
        if Ok and VU then
            AFKConn = LocalPlayer.Idled:Connect(function()
                pcall(function() VU:CaptureController() VU:ClickButton2(Vector2.new()) end)
            end)
            TrackConn(AFKConn)
        else
            Library:Notify("VirtualUser yok.")
        end
    elseif AFKConn then
        pcall(function() AFKConn:Disconnect() end)
        AFKConn = nil
    end
end)

Library:OnUnload(function()
    for _, Conn in ipairs(Connections) do
        pcall(function() Conn:Disconnect() end)
    end
    pcall(function() Abysall.ESPLibrary:Unload() end)
    pcall(function()
        FlyBody.Velocity = Vector3.zero
        FlyBody.Parent = nil
    end)
    pcall(function()
        local Char = LocalPlayer.Character
        local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
        if Hum then Hum.WalkSpeed = 16 end
        if Char then
            for _, P in ipairs(Char:GetDescendants()) do
                if P:IsA("BasePart") and P.Name ~= "HumanoidRootPart" then P.CanCollide = true end
            end
        end
    end)
    pcall(ApplyBright, false)
    pcall(function()
        if _G.SIM_FOVCircle then _G.SIM_FOVCircle:Remove() end
        _G.SIM_FOVCircle = nil
        _G.SIM_Locked = nil
    end)
    if AFKConn then pcall(function() AFKConn:Disconnect() end) AFKConn = nil end
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
Abysall.Interface.ApplyAddons(Window, "larpinglegends2")
Library:Notify("Larping Legends 2 destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")
