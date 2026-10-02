-- Abysall Hub | Forsaken (Forsaken Dev Team)
-- PlaceIds: 18687417158 (ana), 83645629621104 [N], 86454545238517 [VC],
--           94626476208514 [Randomizer]
-- Remotelar conch_networking + Modules.Network uzerinden gidiyor;
-- dogru ability'yi bulmak icin Ability Spy var.

local LoadStart = tick()
Abysall.SavePath = "Forsaken"

local Library = Abysall.Interface.Library
local SaveManager = Abysall.Interface.SaveManager
local ThemeManager = Abysall.Interface.ThemeManager

local Toggles = Library.Toggles
local Toggles = Library.Toggles
-- Toggle okumalarini nil-guvenli yapar; anahtar yoksa false doner (kutuphane sifirlanirsa cokmeyi onler)
local function ToggleOn(Name)
	local T = Toggles and Toggles[Name]
	if T == nil then return false end
	return T.Value == true
end
local function OnChange(Name, Fn)
	local T = Toggles and Toggles[Name]
	if T == nil then return end
	T:OnChanged(Fn)
end
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
    Title = "Abysall Hub | Forsaken",
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
    Visuals = Window:AddTab("Visuals", "eye"),
    Misc = Window:AddTab("Misc", "house"),
    Farm = Window:AddTab("Auto Farm", "target"),
}

local Groupboxes = {}

-- // Combat: Aimbot (kamera kilidi) //
Groupboxes.Combat_Aim = Tabs.Combat:AddLeftGroupbox("Aimbot")

Groupboxes.Combat_Aim:AddToggle("AimbotEnabled", {
    Text = "Aimbot", Default = false,
    Tooltip = "Tus basiliyken kamerayi fareye en yakin dusmana kilitler.",
})
Toggles.AimbotEnabled:AddKeyPicker("AimbotKey", {
    Text = "Aimbot Key", Default = "E", Mode = "Hold", SyncToggleState = false,
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
Groupboxes.Combat_Aim:AddToggle("AimbotWallCheck", {
    Text = "Wall Check", Default = false, Tooltip = "Duvar arkasi hedefi gormezden gelir.",
})
Groupboxes.Combat_Aim:AddSlider("AimSmooth", {
    Text = "Yumusatma", Min = 1, Max = 20, Default = 1, Rounding = 0, Compact = true,
})
Groupboxes.Combat_Aim:AddToggle("AimSticky", { Text = "Sticky Target", Default = true })
Groupboxes.Combat_Aim:AddToggle("AimFOVCircle", { Text = "FOV Dairesi", Default = true })

local function AimIsEnemy(Player)
    if Player == LocalPlayer then return false end
    if not Player.Character then return false end
    if Player:GetAttribute("Alive") == false then return false end
    if Toggles.AimbotTeamCheck and ToggleOn("AimbotTeamCheck") then
        if LocalPlayer.Team ~= nil and Player.Team ~= nil and Player.Team == LocalPlayer.Team then
            return false
        end
    end
    local Hum = Player.Character:FindFirstChildOfClass("Humanoid")
    if Hum and Hum.Health <= 0 then return false end
    return true
end

local function AimIsVisible(TargetPart)
    if not Toggles.AimbotWallCheck or not ToggleOn("AimbotWallCheck") then
        return true
    end
    local Ok, Res = pcall(function()
        local RayParams = RaycastParams.new()
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        RayParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
        return Services.Workspace:Raycast(Camera.CFrame.Position, (TargetPart.Position - Camera.CFrame.Position), RayParams)
    end)
    if not Ok or not Res then return true end
    return Res.Instance:IsDescendantOf(TargetPart.Parent)
end

local function AimGetMouse()
    local Loc = Services.UserInputService:GetMouseLocation()
    return Vector2.new(Loc.X, Loc.Y)
end

local function AimGetTarget()
    local Best, BestDist = nil, Options.AimbotFOV and Options.AimbotFOV.Value or 200
    local PartName = Options.AimbotPart and Options.AimbotPart.Value or "Head"
    local Mouse = AimGetMouse()
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if AimIsEnemy(Player) then
            local Part = Player.Character:FindFirstChild(PartName)
            if Part then
                local Pos, OnScreen = Camera:WorldToViewportPoint(Part.Position)
                if OnScreen then
                    local Dist = (Vector2.new(Pos.X, Pos.Y) - Mouse).Magnitude
                    if Dist < BestDist and AimIsVisible(Part) then
                        BestDist = Dist
                        Best = Part
                    end
                end
            end
        end
    end
    return Best
end

TrackConn(Services.RunService.RenderStepped:Connect(function()
    pcall(function()
        if not _G.FS_FOVCircle and typeof(Drawing) == "function" then
            local C = Drawing.new("Circle")
            C.Thickness = 1
            C.NumSides = 64
            C.Filled = false
            C.Color = Color3.fromRGB(255, 255, 255)
            _G.FS_FOVCircle = C
        end
        if _G.FS_FOVCircle then
            local Show = Toggles.AimbotEnabled and ToggleOn("AimbotEnabled") and Toggles.AimFOVCircle and ToggleOn("AimFOVCircle")
            _G.FS_FOVCircle.Visible = Show or false
            if Show then
                _G.FS_FOVCircle.Position = AimGetMouse()
                _G.FS_FOVCircle.Radius = Options.AimbotFOV and Options.AimbotFOV.Value or 200
            end
        end
    end)

    if Toggles.AimbotEnabled and ToggleOn("AimbotEnabled") then
        local HoldingKey = Options.AimbotKey and Options.AimbotKey:GetState()
        local HoldingRMB = Toggles.AimbotUseRMB and ToggleOn("AimbotUseRMB") and Services.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if HoldingKey or HoldingRMB then
            local Target = AimGetTarget()
            local FOV = (Options.AimbotFOV and Options.AimbotFOV.Value) or 200
            if Toggles.AimSticky and ToggleOn("AimSticky") and _G.FS_Locked and _G.FS_Locked.Parent then
                local LP = _G.FS_Locked
                local Pos, On = Camera:WorldToViewportPoint(LP.Position)
                if On and (Vector2.new(Pos.X, Pos.Y) - AimGetMouse()).Magnitude <= (FOV + 50) then
                    Target = LP
                else
                    _G.FS_Locked = nil
                end
            end
            if Target then
                _G.FS_Locked = Target
                local Goal = CFrame.new(Camera.CFrame.Position, Target.Position)
                local Smooth = (Options.AimSmooth and Options.AimSmooth.Value) or 1
                if Smooth <= 1 then
                    Camera.CFrame = Goal
                else
                    Camera.CFrame = Camera.CFrame:Lerp(Goal, 1 / Smooth)
                end
            end
        else
            _G.FS_Locked = nil
        end
    end
end))

-- // Combat: Killer arkasi //
local BackstabBusy = false

local function FindKillerHRP()
    for _, P in ipairs(Services.Players:GetPlayers()) do
        if P ~= LocalPlayer and P.Character then
            local Hum = P.Character:FindFirstChildOfClass("Humanoid")
            local HRP = P.Character:FindFirstChild("HumanoidRootPart")
            if Hum and HRP and Hum.Health > 0 and Hum.MaxHealth >= 500 then
                return HRP
            end
        end
    end
    return nil
end

-- Oyundaki kendi Q aksiyonunu da tetikle (varsa)
local function FireGameKeyAction()
    local Fired = false
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local function Scan(Root, Depth)
        if not Root or Depth > 6 then return end
        for _, Child in ipairs(Root:GetChildren()) do
            if Child:IsA("GuiButton") or Child:IsA("TextButton") or Child:IsA("ImageButton") then
                local Name = string.lower(Child.Name or "")
                local Text = ""
                pcall(function() Text = string.lower(Child.Text or "") end)
                if Name == "q" or Text == "q" or string.find(Name, "ability", 1, true) or string.find(Name, "skill", 1, true) then
                    pcall(function() Child:Activate() end)
                    pcall(function() Child.Activated:Fire() end)
                    Fired = true
                end
            end
            Scan(Child, Depth + 1)
        end
    end
    if PlayerGui then Scan(PlayerGui, 0) end
    pcall(function()
        local VIM = Services.VirtualInputManager
        VIM:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
        task.wait(0.05)
        VIM:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
        Fired = true
    end)
    return Fired
end

-- Killer'in arkasina kilitlenip 2 sn takip et, sonra eski konuma don
local function GoBehindKiller()
    if BackstabBusy then return end
    BackstabBusy = true
    task.spawn(function()
        local Duration = 2
        pcall(function() Duration = ToggleOn("KillerBackDuration") end)
        local MyHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not MyHRP then
            BackstabBusy = false
            Library:Notify("Karakter yok.")
            return
        end
        local KillerHRP = FindKillerHRP()
        if not KillerHRP then
            BackstabBusy = false
            return
        end
        local Saved = MyHRP.CFrame
        local Offset = 3
        pcall(function() Offset = ToggleOn("KillerBackOffset") end)
        local EndTime = tick() + Duration
        while tick() < EndTime do
            if not MyHRP.Parent or not KillerHRP.Parent then break end
            pcall(function()
                local Behind = KillerHRP.CFrame * CFrame.new(0, 0, Offset)
                MyHRP.CFrame = CFrame.lookAt(Behind.Position, KillerHRP.Position)
            end)
            task.wait()
        end
        pcall(function()
            if MyHRP.Parent then MyHRP.CFrame = Saved end
        end)
        BackstabBusy = false
    end)
end

local function DoBackstab()
    if not ToggleOn("KillerBackEnabled") then
        Library:Notify("Backstab kapali.")
        return
    end
    task.spawn(function()
        GoBehindKiller()
        if ToggleOn("KillerBackGameKey") then
            FireGameKeyAction()
        end
    end)
end

Groupboxes.Combat_Killer = Tabs.Combat:AddLeftGroupbox("Killer")

Groupboxes.Combat_Killer:AddToggle("KillerBackEnabled", {
    Text = "Backstab", Default = true,
    Tooltip = "Kapaliyken backstab tusu ve butonu calismaz.",
})
Groupboxes.Combat_Killer:AddToggle("KillerBackGameKey", {
    Text = "Oyun Q Butonu", Default = true,
    Tooltip = "Basilan tus ayrica oyundaki kendi Q aksiyonunu da tetikler.",
})
Groupboxes.Combat_Killer:AddSlider("KillerBackDuration", {
    Text = "Bekleme (sn)", Min = 0.5, Max = 10, Default = 2, Rounding = 1, Compact = true,
})
Groupboxes.Combat_Killer:AddSlider("KillerBackOffset", {
    Text = "Killer Mesafesi", Min = 1, Max = 12, Default = 3, Rounding = 1, Compact = true,
})
Groupboxes.Combat_Killer:AddToggle("KillerBack", {
    Text = "Backstab (Tuş)", Default = false,
    Tooltip = "Tuşa basınca killer arkasına kilitlenir, 2sn bekler, sonra döner.",
})
Toggles.KillerBack:AddKeyPicker("KillerBackKey", {
    Text = "Killer Arkası", Default = "Q", Mode = "Toggle", SyncToggleState = true,
})
OnChange("KillerBack", function(Value)
    if not Value then return end
    DoBackstab()
    pcall(function() Toggles.KillerBack:SetValue(false) end)
end)
Groupboxes.Combat_Killer:AddButton({
    Text = "Killer Arkasına Git",
    DoubleClick = false,
    Func = function() DoBackstab() end,
})
Groupboxes.Combat_Killer:AddLabel("Tuşla veya butonla; 1sn sonra döner.", true)

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
Groupboxes.Combat_Aura:AddToggle("KillAuraAllTargets", {
    Text = "Tum Menzil", Default = true,
    Tooltip = "Kapaliyken sadece en yakin hedefe vurur.",
})
Groupboxes.Combat_Aura:AddToggle("KillAuraTeamCheck", { Text = "Team Check", Default = true })
Groupboxes.Combat_Aura:AddToggle("KillAuraWallCheck", {
    Text = "Wall Check", Default = false, Tooltip = "Duvar arkasinin hasarini engeller.",
})
Groupboxes.Combat_Aura:AddToggle("KillAuraToolOnly", {
    Text = "Sadece Tool", Default = false,
    Tooltip = "Sadece elinde tool varken calisir.",
})

local function AuraIsEnemy(Player)
    if Player == LocalPlayer then return false end
    if not Player.Character then return false end
    if Player:GetAttribute("Alive") == false then return false end
    if Toggles.KillAuraTeamCheck and ToggleOn("KillAuraTeamCheck") then
        if LocalPlayer.Team ~= nil and Player.Team ~= nil and Player.Team == LocalPlayer.Team then
            return false
        end
    end
    local Hum = Player.Character:FindFirstChildOfClass("Humanoid")
    if Hum and Hum.Health <= 0 then return false end
    return true
end

local function AuraVisible(TargetPart, Origin)
    if not Toggles.KillAuraWallCheck or not ToggleOn("KillAuraWallCheck") then
        return true
    end
    local Ok, Res = pcall(function()
        local RayParams = RaycastParams.new()
        RayParams.FilterType = Enum.RaycastFilterType.Exclude
        RayParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
        return Services.Workspace:Raycast(Origin, (TargetPart.Position - Origin), RayParams)
    end)
    if not Ok or not Res then return true end
    return Res.Instance:IsDescendantOf(TargetPart.Parent)
end

local AuraAccum = 0

TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if not (Toggles.KillAura and ToggleOn("KillAura")) then return end
    if not LocalPlayer.Character then return end
    if Toggles.KillAuraToolOnly and ToggleOn("KillAuraToolOnly") then
        if not LocalPlayer.Character:FindFirstChildOfClass("Tool") then return end
    end
    AuraAccum = AuraAccum + Delta
    local Interval = (Options.KillAuraInterval and Options.KillAuraInterval.Value) or 0.5
    if AuraAccum < Interval then return end
    AuraAccum = 0

    local HRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not HRP then return end
    local Range = (Options.KillAuraRange and Options.KillAuraRange.Value) or 30
    local Damage = (Options.KillAuraDamage and Options.KillAuraDamage.Value) or 25
    local OnlyClosest = not (Toggles.KillAuraAllTargets and ToggleOn("KillAuraAllTargets"))
    local Targets = {}
    local Best, BestDist = nil, Range

    for _, Player in pairs(Services.Players:GetPlayers()) do
        if AuraIsEnemy(Player) then
            local Part = Player.Character:FindFirstChild("HumanoidRootPart")
            if Part then
                local Dist = (Part.Position - HRP.Position).Magnitude
                if Dist <= Range and AuraVisible(Part, HRP.Position) then
                    if OnlyClosest then
                        if Dist < BestDist then Best, BestDist = Player, Dist end
                    else
                        table.insert(Targets, { Player = Player, Part = Part })
                    end
                end
            end
        end
    end
    if OnlyClosest and Best then
        table.insert(Targets, { Player = Best, Part = Best.Character:FindFirstChild("HumanoidRootPart") })
    end
    if #Targets == 0 then return end

    for _, Entry in ipairs(Targets) do
        local Hum = Entry.Player.Character and Entry.Player.Character:FindFirstChildOfClass("Humanoid")
        if Hum and Hum.Health > 0 then
            pcall(function() Hum:TakeDamage(Damage) end)
            if Hum.Health > 0 then
                Hum.Health = math.max(0, Hum.Health - Damage)
            end
        end
    end
end))

-- // Combat: Ability Spy //
local RefireLast
Groupboxes.Combat_Spy = Tabs.Combat:AddRightGroupbox("Ability Spy")

Groupboxes.Combat_Spy:AddToggle("LogAbilityArgs", {
    Text = "Log Ability (F9)", Default = false,
    Tooltip = "Ability/komut kullanirken ateslenen remote + argumanlari kaydeder.",
})
Groupboxes.Combat_Spy:AddButton({
    Text = "Son Ability'yi Atesle",
    DoubleClick = false,
    Func = function() RefireLast() end,
})
Groupboxes.Combat_Spy:AddToggle("SpamLastAbility", { Text = "Spam Son Ability", Default = false })
Groupboxes.Combat_Spy:AddSlider("SpamInterval", {
    Text = "Spam Araligi (sn)", Min = 0.2, Max = 5, Default = 1, Rounding = 1, Compact = true,
})
Groupboxes.Combat_Spy:AddButton({
    Text = "Freecam Config Oku (F9)",
    DoubleClick = false,
    Func = function()
        local C = Services.ReplicatedStorage:FindFirstChild("FreecamPlus", true)
        local Cfg = C and C:FindFirstChild("FREECAM_CONFIG", true)
        if Cfg and Cfg:IsA("RemoteFunction") then
            local Ok, Res = pcall(function() return Cfg:InvokeServer() end)
            warn("[Abysall:Forsaken] FREECAM_CONFIG = " .. (Ok and tostring(Res) or tostring(Res)))
        else
            Library:Notify("FREECAM_CONFIG bulunamadi.")
        end
    end,
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
        local IsFire = Method == "FireServer" and typeof(Self) == "Instance" and Self:IsA("RemoteEvent")
        local IsInvoke = Method == "InvokeServer" and typeof(Self) == "Instance" and Self:IsA("RemoteFunction")
        if IsFire or IsInvoke then
            if not InternalFire and Toggles.LogAbilityArgs and ToggleOn("LogAbilityArgs") then
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
                    Library:Notify("Kaydedildi: " .. Self.Name)
                end
            end
        end
        return Old(Self, ...)
    end))
end
OnChange("LogAbilityArgs", function(Value)
    if Value then
        InstallSpy()
        task.delay(0.5, function()
            local Saved = LastRecorded
            local T = Instance.new("RemoteEvent")
            pcall(function() T:FireServer("abysall_hook_test") end)
            T:Destroy()
            task.wait(0.3)
            if LastRecorded and LastRecorded.Args[1] == "abysall_hook_test" then
                Library:Notify("Hook calisiyor, simdi ability kullan.")
            else
                Library:Notify("Hook CALISMIYOR (executor desteklemiyor).")
            end
            LastRecorded = Saved
        end)
    end
end)

RefireLast = function()
    if not LastRecorded or not LastRecorded.Remote then
        Library:Notify("Once log acikken ability kullan.")
        return
    end
    local R, Args = LastRecorded.Remote, LastRecorded.Args
    InternalFire = true
    local Ok, Err = pcall(function()
        if LastRecorded.IsInvoke then
            local Ret = { R:InvokeServer(table.unpack(Args)) }
            print("[Abysall-Spy] invoke dondu, " .. #Ret .. " deger")
        else
            R:FireServer(table.unpack(Args))
        end
    end)
    InternalFire = false
    if Ok then
        Library:Notify("Ateslendi: " .. tostring(LastRecorded.Short))
    else
        Library:Notify("Hata: " .. tostring(Err):sub(1, 80))
    end
end

local SpamAcc = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if Toggles.SpamLastAbility and ToggleOn("SpamLastAbility") and LastRecorded then
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

-- // Combat: Remotes //
Groupboxes.Combat_Remotes = Tabs.Combat:AddRightGroupbox("Remotes")

local function FindRemote(Name)
    local Found = Services.ReplicatedStorage:FindFirstChild(Name, true)
    if Found and (Found:IsA("RemoteEvent") or Found:IsA("RemoteFunction")) then
        return Found
    end
    return nil
end

local function FireNamed(Name)
    local R = FindRemote(Name)
    if not R then
        Library:Notify("Bulunamadi: " .. Name)
        return
    end
    InternalFire = true
    local Ok, Err = pcall(function()
        if R:IsA("RemoteEvent") then R:FireServer() else R:InvokeServer() end
    end)
    InternalFire = false
    if Ok then Library:Notify("Ateslendi: " .. Name)
    else Library:Notify("Hata: " .. tostring(Err):sub(1, 80)) end
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
Groupboxes.Combat_Remotes:AddInput("FireRemoteName", {
    Text = "Remote Adi", Default = "", Numeric = false, Finished = false,
    Placeholder = "Orn: invoke_server_command",
})
Groupboxes.Combat_Remotes:AddButton({
    Text = "Isimle Atesle (argsiz)",
    DoubleClick = false,
    Func = function()
        local Name = Options.FireRemoteName and Options.FireRemoteName.Value or ""
        if Name == "" then
            Library:Notify("Once remote adi yaz.")
            return
        end
        FireNamed(Name)
    end
})
Groupboxes.Combat_Remotes:AddDivider()
Groupboxes.Combat_Remotes:AddButton({
    Text = "Generator RF (argsiz dene)",
    DoubleClick = false,
    Func = function() FireNamed("RF") end,
})
Groupboxes.Combat_Remotes:AddButton({
    Text = "Generator RE (argsiz dene)",
    DoubleClick = false,
    Func = function() FireNamed("RE") end,
})
Groupboxes.Combat_Remotes:AddLabel("Generator'lar argsiz calismayabilir, Spy kullan.", true)

-- // Visuals: Report (resmi rapor API'si, tek seferlik) //
Groupboxes.Visuals_Report = Tabs.Visuals:AddRightGroupbox("Report")

local ReportReasons = {
    "Exploiting",
    "Cheating",
    "Inappropriate Content",
    "Bullying / Harassment",
    "Offensive Username",
    "Other",
}

Groupboxes.Visuals_Report:AddLabel("Oyuncu sec, sebebi sec, Report'a bas.", true)
Groupboxes.Visuals_Report:AddDropdown("ReportTarget", { Text = "Oyuncu", Values = {}, Default = 1 })
Groupboxes.Visuals_Report:AddDropdown("ReportReason", { Text = "Sebep", Values = ReportReasons, Default = 1 })
Groupboxes.Visuals_Report:AddInput("ReportComment", {
    Text = "Aciklama", Default = "", Numeric = false, Finished = false,
    Placeholder = "Istege bagli",
})

local function ReportTargetOptions()
    local Names = {}
    for _, P in ipairs(Services.Players:GetPlayers()) do
        if P ~= LocalPlayer then table.insert(Names, P.Name) end
    end
    table.sort(Names)
    if #Names == 0 then table.insert(Names, "(Oyuncu yok)") end
    return Names
end
Groupboxes.Visuals_Report:AddButton({
    Text = "Oyuncu Listesini Yenile",
    DoubleClick = false,
    Func = function()
        local D = Options.ReportTarget
        local Current = D and D.Value
        local New = ReportTargetOptions()
        pcall(function() D:SetValues(New) end)
        if Current then
            pcall(function()
                for I, V in ipairs(New) do
                    if V == Current then D:SetValue(V) return end
                end
            end)
        end
        Library:Notify(#New .. " oyuncu listelendi.")
    end,
})
Groupboxes.Visuals_Report:AddButton({
    Text = "Report Gonder",
    DoubleClick = true,
    Func = function()
        -- Roblox script'lerden rapor API'si sunmuyor: hem Players hem Player
        -- uzerinde ReportPlayer yok ("not a valid member"). Rapor sadece
        -- resmi menuden gidiyor.
        Library:Notify("Script ile rapor yok: ESC -> Report menusunden gonder.")
    end,
})
Groupboxes.Visuals_Report:AddLabel("Cift tik: onay ister. Otomatik gonderim yok.", true)
task.spawn(function()
    task.wait(1)
    pcall(function() Options.ReportTarget:SetValues(ReportTargetOptions()) end)
end)

-- // Visuals: Player ESP //
Groupboxes.Visuals_ESP = Tabs.Visuals:AddLeftGroupbox("Player ESP")

Groupboxes.Visuals_ESP:AddToggle("PlayerESP", { Text = "Player ESP", Default = false })
Toggles.PlayerESP:AddColorPicker("PlayerESPColor", {
    Text = "ESP Rengi", Default = Color3.fromRGB(255, 0, 0), Transparency = 0,
})
Groupboxes.Visuals_ESP:AddToggle("ESPTeamCheck", { Text = "Team Check", Default = true })
Groupboxes.Visuals_ESP:AddToggle("ESPShowHealth", { Text = "Show Health", Default = true })
Groupboxes.Visuals_ESP:AddToggle("ESPShowStamina", {
    Text = "Show Stamina", Default = true, Tooltip = "Stamina barini da gosterir.",
})
Groupboxes.Visuals_ESP:AddToggle("RoleColors", {
    Text = "Role Colors", Default = true, Tooltip = "Killer kirmizi, survivor yesil (cana gore).",
})

-- Killer'lar 1000+ HP, survivor'lar ~100 HP
local function RoleColor(Char, Fallback)
    if Toggles.RoleColors and ToggleOn("RoleColors") then
        local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
        if Hum and Hum.MaxHealth >= 500 then
            return Color3.fromRGB(255, 0, 0)
        end
        return Color3.fromRGB(0, 255, 0)
    end
    return Fallback
end

local function ShouldESP(Player)
    if Player == LocalPlayer then return false end
    if not Player.Character then return false end
    if Toggles.ESPTeamCheck and ToggleOn("ESPTeamCheck") then
        if LocalPlayer.Team ~= nil and Player.Team ~= nil and Player.Team == LocalPlayer.Team then
            return false
        end
    end
    return true
end

local HealthConns = {}
local function TrackHealth(Player, Char)
    local Old = HealthConns[Char]
    if Old then pcall(function() Old:Disconnect() end) HealthConns[Char] = nil end
    local ShowHP = Toggles.ESPShowHealth and ToggleOn("ESPShowHealth")
    local ShowStam = Toggles.ESPShowStamina and ToggleOn("ESPShowStamina")
    if not (ShowHP or ShowStam) then
        Abysall.ESPLibrary:UpdateObjectText(Char, Player.Name)
        return
    end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    if not Hum then return end
    local function Refresh()
        if not Hum.Parent then return end
        local Parts = {}
        if ShowHP then table.insert(Parts, tostring(math.floor(Hum.Health + 0.5))) end
        if ShowStam then
            local Leaderstats = Player:FindFirstChild("leaderstats")
            local Stamina = Leaderstats and Leaderstats:FindFirstChild("Stamina")
            if Stamina then table.insert(Parts, tostring(math.floor(Stamina.Value + 0.5))) end
        end
        local Suffix = #Parts > 0 and (" [" .. table.concat(Parts, " | ") .. "]") or ""
        Abysall.ESPLibrary:UpdateObjectText(Char, Player.Name .. Suffix)
    end
    Refresh()
    local Conn = Hum.HealthChanged:Connect(Refresh)
    HealthConns[Char] = Conn
    TrackConn(Conn)
    local Leaderstats = Player:FindFirstChild("leaderstats")
    local Stamina = Leaderstats and Leaderstats:FindFirstChild("Stamina")
    if Stamina then
        local SConn = Stamina:GetPropertyChangedSignal("Value"):Connect(Refresh)
        HealthConns[Char .. "_stam"] = SConn
        TrackConn(SConn)
    end
    Char.Destroying:Once(function()
        local C = HealthConns[Char]
        if C then pcall(function() C:Disconnect() end) HealthConns[Char] = nil end
        local S = HealthConns[Char .. "_stam"]
        if S then pcall(function() S:Disconnect() end) HealthConns[Char .. "_stam"] = nil end
    end)
end

local function AddPlayerESP(Data)
    pcall(function()
        Abysall.ESPLibrary:AddESP(Data)
        if Data.Player and Data.Object then TrackHealth(Data.Player, Data.Object) end
        Data.Object.Destroying:Once(function()
            if Abysall then Abysall.ESPLibrary:RemoveESP(Data.Object) end
        end)
    end)
end

OnChange("PlayerESP", function(Value)
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player.Character then
            if Value and ShouldESP(Player) then
                AddPlayerESP({ Object = Player.Character, Text = Player.Name, Color = RoleColor(Player.Character, Options.PlayerESPColor.Value), Player = Player })
            else
                Abysall.ESPLibrary:RemoveESP(Player.Character)
            end
        end
    end
end)
Options.PlayerESPColor:OnChanged(function(Value)
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player.Character then
            Abysall.ESPLibrary:UpdateObjectColor(Player.Character, RoleColor(Player.Character, Value))
        end
    end
end)
OnChange("RoleColors", function()
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character and ToggleOn("PlayerESP") and ShouldESP(Player) then
            Abysall.ESPLibrary:UpdateObjectColor(Player.Character, RoleColor(Player.Character, Options.PlayerESPColor.Value))
        end
    end
end)
OnChange("ESPShowHealth", function()
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character and ToggleOn("PlayerESP") and ShouldESP(Player) then
            TrackHealth(Player, Player.Character)
        end
    end
end)
OnChange("ESPShowStamina", function()
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character and ToggleOn("PlayerESP") and ShouldESP(Player) then
            TrackHealth(Player, Player.Character)
        end
    end
end)

TrackConn(Services.Players.PlayerAdded:Connect(function(Player)
    Player.CharacterAdded:Connect(function(Char)
        task.wait(1)
        if ToggleOn("PlayerESP") and ShouldESP(Player) then
            AddPlayerESP({ Object = Char, Text = Player.Name, Color = RoleColor(Char, Options.PlayerESPColor.Value), Player = Player })
        end
    end)
end))
for _, Player in pairs(Services.Players:GetPlayers()) do
    if Player ~= LocalPlayer then
        Player.CharacterAdded:Connect(function(Char)
            task.wait(1)
            if ToggleOn("PlayerESP") and ShouldESP(Player) then
                AddPlayerESP({ Object = Char, Text = Player.Name, Color = RoleColor(Char, Options.PlayerESPColor.Value), Player = Player })
            end
        end)
    end
end

-- // Visuals: Item ESP (Medkit, BloxyCola...) //
Groupboxes.Visuals_Item = Tabs.Visuals:AddLeftGroupbox("Item ESP")

Groupboxes.Visuals_Item:AddToggle("ItemESP", {
    Text = "Item ESP", Default = false, Tooltip = "Haritadaki esyalari isaretler.",
})
Toggles.ItemESP:AddColorPicker("ItemESPColor", {
    Text = "Esya Rengi", Default = Color3.fromRGB(0, 255, 255), Transparency = 0,
})

local ItemNames = { Medkit = true, BloxyCola = true }
local ItemESPObjects = {}

local function IsPlayerItem(Obj)
    for _, P in ipairs(Services.Players:GetPlayers()) do
        if P.Character and Obj:IsDescendantOf(P.Character) then return true end
        local BP = P:FindFirstChild("Backpack")
        if BP and Obj:IsDescendantOf(BP) then return true end
    end
    return false
end

local function HookItem(Obj)
    local Label = nil
    if Obj:IsA("Tool") and not IsPlayerItem(Obj) then
        Label = Obj.Name
    elseif Obj:IsA("Model") and ItemNames[Obj.Name] and not IsPlayerItem(Obj) then
        Label = Obj.Name
    end
    if not Label then return end
    if Toggles.ItemESP and ToggleOn("ItemESP") then
        local Target = Obj
        pcall(function()
            Abysall.ESPLibrary:AddESP({ Object = Target, Text = Label, Color = Options.ItemESPColor.Value })
            Target.Destroying:Once(function()
                if Abysall then Abysall.ESPLibrary:RemoveESP(Target) end
            end)
        end)
        table.insert(ItemESPObjects, Target)
    end
end

local function ScanItems()
    for _, D in ipairs(Services.Workspace:GetDescendants()) do
        if D:IsA("Tool") or D:IsA("Model") then HookItem(D) end
    end
end

local function ClearItems()
    for _, O in ipairs(ItemESPObjects) do
        pcall(function() Abysall.ESPLibrary:RemoveESP(O) end)
    end
    ItemESPObjects = {}
end

OnChange("ItemESP", function(Value)
    if Value then
        ScanItems()
    else
        ClearItems()
    end
end)
Options.ItemESPColor:OnChanged(function(Value)
    for _, O in ipairs(ItemESPObjects) do
        Abysall.ESPLibrary:UpdateObjectColor(O, Value)
    end
end)
TrackConn(Services.Workspace.DescendantAdded:Connect(function(Obj)
    if Obj:IsA("Tool") or Obj:IsA("Model") then HookItem(Obj) end
end))

Groupboxes.Visuals_Settings = Tabs.Visuals:AddRightGroupbox("ESP Settings")
Groupboxes.Visuals_Settings:AddToggle("ESPShowDistance", { Text = "Show Distance", Default = true })
Groupboxes.Visuals_Settings:AddToggle("ESPTracers", { Text = "Tracers", Default = false })
Groupboxes.Visuals_Settings:AddToggle("ESPArrows", { Text = "Arrows", Default = false })
OnChange("ESPShowDistance", function(V) Abysall.ESPLibrary:SetShowDistance(V) end)
OnChange("ESPTracers", function(V) Abysall.ESPLibrary:SetTracers(V) end)
OnChange("ESPArrows", function(V) Abysall.ESPLibrary:SetArrows(V) end)
Abysall.ESPLibrary:SetShowDistance(true)

-- // Misc: hareket //
Groupboxes.Misc_Move = Tabs.Misc:AddLeftGroupbox("Movement")
Groupboxes.Misc_Move:AddSlider("WalkSpeedVal", {
    Text = "WalkSpeed", Min = 16, Max = 200, Default = 16, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("WalkSpeedOn", { Text = "Speed", Default = false })
Groupboxes.Misc_Move:AddToggle("InfiniteJump", { Text = "Infinite Jump", Default = false })
Groupboxes.Misc_Move:AddDivider()
Groupboxes.Misc_Move:AddToggle("Fly", { Text = "Fly", Default = false })
Toggles.Fly:AddKeyPicker("FlyKey", {
    Text = "Fly", Default = "F", Mode = "Toggle", SyncToggleState = true,
})
Groupboxes.Misc_Move:AddSlider("FlySpeed", {
    Text = "Fly Speed", Min = 0, Max = 200, Default = 50, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("Noclip", { Text = "Noclip", Default = false })
Toggles.Noclip:AddKeyPicker("NoclipKey", {
    Text = "Noclip", Default = "N", Mode = "Toggle", SyncToggleState = true,
})

-- // Misc: Stamina //
-- Forsalede stamina ReplicatedStorage.Systems.Character.Game.Sprinting modulunden yonetiliyor
Groupboxes.Misc_Stamina = Tabs.Misc:AddLeftGroupbox("Stamina")
Groupboxes.Misc_Stamina:AddToggle("InfStamina", {
    Text = "Infinite Stamina", Default = false,
    Tooltip = "Sprint staminasini tuketilmez yapar.",
})
Groupboxes.Misc_Stamina:AddSlider("StaminaMax", {
    Text = "Max Stamina", Min = 50, Max = 5000, Default = 500, Rounding = 1, Compact = true,
})
Groupboxes.Misc_Stamina:AddSlider("StaminaGain", {
    Text = "Regen", Min = 0, Max = 500, Default = 100, Rounding = 1, Compact = true,
})
Groupboxes.Misc_Stamina:AddToggle("StaminaNoLoss", {
    Text = "Tuketim Kapat", Default = true, Tooltip = "Sprint staminasi hic dusunmesin.",
})
Groupboxes.Misc_Stamina:AddToggle("StaminaSprintSpeed", {
    Text = "Sprint Hizi", Default = false, Tooltip = "Sprint hizini da yukseltir.",
})
Groupboxes.Misc_Stamina:AddSlider("StaminaSprintSpeedVal", {
    Text = "Sprint Speed", Min = 16, Max = 300, Default = 80, Rounding = 0, Compact = true,
})

local SprintModule = nil
local StaminaSaved = nil

local function FindSprintModule()
    if SprintModule then return SprintModule end
    local Rep = Services.ReplicatedStorage
    local Direct = Rep:FindFirstChild("Systems")
        and Rep.Systems:FindFirstChild("Character")
        and Rep.Systems.Character:FindFirstChild("Game")
        and Rep.Systems.Character.Game:FindFirstChild("Sprinting")
    local Candidates = { Direct }
    for _, Name in ipairs({ "Sprinting", "Stamina", "Sprint", "SprintingSystem" }) do
        table.insert(Candidates, Rep:FindFirstChild(Name, true))
    end
    for _, Mod in ipairs(Candidates) do
        if Mod and Mod:IsA("ModuleScript") then
            local Ok, Result = pcall(require, Mod)
            if Ok and type(Result) == "table" then
                SprintModule = Result
                return SprintModule
            end
        end
    end
    return nil
end

local StaminaFields = { "Stamina", "CurrentStamina", "StaminaValue" }

local function ApplyStamina()
    local Mod = FindSprintModule()
    if not Mod then return end
    local Max = Options.StaminaMax and Options.StaminaMax.Value or 500
    local Gain = Options.StaminaGain and Options.StaminaGain.Value or 100
    pcall(function() Mod.MaxStamina = Max end)
    pcall(function() Mod.StaminaGain = Gain end)
    pcall(function() Mod.StaminaLossDisabled = Toggles.StaminaNoLoss and ToggleOn("StaminaNoLoss") or false end)
    pcall(function() Mod.MinStamina = -9999 end)
    if Toggles.StaminaSprintSpeed and ToggleOn("StaminaSprintSpeed") then
        pcall(function()
            Mod.SprintSpeed = Options.StaminaSprintSpeedVal and Options.StaminaSprintSpeedVal.Value or 80
        end)
    end
    for _, Field in ipairs(StaminaFields) do
        pcall(function()
            if Mod[Field] ~= nil and type(Mod[Field]) == "number" then
                Mod[Field] = Max
            end
        end)
    end
end

local function SaveStamina()
    local Mod = FindSprintModule()
    if not Mod or StaminaSaved then return end
    StaminaSaved = {
        MaxStamina = Mod.MaxStamina,
        MinStamina = Mod.MinStamina,
        StaminaGain = Mod.StaminaGain,
        StaminaLoss = Mod.StaminaLoss,
        StaminaLossDisabled = Mod.StaminaLossDisabled,
        SprintSpeed = Mod.SprintSpeed,
    }
end

local function RestoreStamina()
    local Mod = SprintModule
    if not Mod or not StaminaSaved then return end
    for Key, Value in pairs(StaminaSaved) do
        if Value ~= nil then pcall(function() Mod[Key] = Value end) end
    end
    StaminaSaved = nil
end

OnChange("InfStamina", function(Value)
    if Value then
        SaveStamina()
        ApplyStamina()
    else
        RestoreStamina()
    end
end)

local StaminaAcc = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if Toggles.InfStamina and ToggleOn("InfStamina") then
        StaminaAcc = StaminaAcc + Delta
        if StaminaAcc >= 0.1 then
            StaminaAcc = 0
            ApplyStamina()
        end
    else
        StaminaAcc = 0
    end
end))

-- // Misc: Extra //
Groupboxes.Misc_Extra = Tabs.Misc:AddRightGroupbox("Extra")
Groupboxes.Misc_Extra:AddToggle("GodMode", { Text = "God Mode", Default = false })
Groupboxes.Misc_Extra:AddToggle("Hitbox", { Text = "Hitbox Expander", Default = false })
Groupboxes.Misc_Extra:AddSlider("HitboxSize", {
    Text = "Hitbox", Min = 1, Max = 10, Default = 3, Rounding = 1, Compact = true,
})
Groupboxes.Misc_Extra:AddToggle("JumpPower", { Text = "Jump Power", Default = false })
Groupboxes.Misc_Extra:AddSlider("JumpPowerVal", {
    Text = "Jump Power", Min = 20, Max = 300, Default = 100, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Extra:AddToggle("RemovePopups", { Text = "Bildirimleri Kapat", Default = false })

local GodAcc = 0
local HitboxSaved = nil
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if not LocalPlayer.Character then return end
    local Hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not Hum then return end
    if Toggles.GodMode and ToggleOn("GodMode") then
        GodAcc = GodAcc + Delta
        if GodAcc >= 0.1 then
            GodAcc = 0
            pcall(function() Hum.Health = Hum.MaxHealth end)
        end
    else
        GodAcc = 0
    end
    if Toggles.JumpPower and ToggleOn("JumpPower") then
        pcall(function()
            Hum.UseJumpPower = true
            Hum.JumpPower = Options.JumpPowerVal and Options.JumpPowerVal.Value or 100
        end)
    end
    local Head = LocalPlayer.Character:FindFirstChild("Head")
    if Toggles.Hitbox and ToggleOn("Hitbox") and Head then
        if not HitboxSaved then HitboxSaved = Head.Size end
        pcall(function()
            local Mult = Options.HitboxSize and Options.HitboxSize.Value or 3
            Head.Size = HitboxSaved * Mult
            Head.Transparency = 1
            Head.CanCollide = false
        end)
    elseif HitboxSaved and Head then
        pcall(function() Head.Size = HitboxSaved end)
    end
end))

OnChange("RemovePopups", function(Value)
    pcall(function()
        local StarterGui = Services.StarterGui
        StarterGui:SetCore("SendNotification", not Value)
    end)
end)

TrackConn(Services.RunService.RenderStepped:Connect(function()
    if Toggles.WalkSpeedOn and ToggleOn("WalkSpeedOn") and LocalPlayer.Character then
        local Hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Hum then Hum.WalkSpeed = Options.WalkSpeedVal.Value end
    end
end))

TrackConn(Services.UserInputService.JumpRequest:Connect(function()
    if Toggles.InfiniteJump and ToggleOn("InfiniteJump") and LocalPlayer.Character then
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
    if not Hum or Hum.MoveDirection == Vector3.zero or not Camera then
        return Vector3.zero
    end
    local LookFlat = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
    if LookFlat.Magnitude < 0.01 then LookFlat = Vector3.new(0, 0, -1) end
    local FlatFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + LookFlat)
    local Vel = (Camera.CFrame * CFrame.new(FlatFrame:VectorToObjectSpace(Hum.MoveDirection))).Position - Camera.CFrame.Position
    if Vel.Magnitude < 0.01 then return Vector3.zero end
    return Vel.Unit
end

TrackConn(Services.RunService.RenderStepped:Connect(function()
    local R = FlyRoot()
    if Toggles.Fly and ToggleOn("Fly") and R then
        FlyBody.Parent = R
        FlyBody.Velocity = FlyDir() * ((Options.FlySpeed and Options.FlySpeed.Value) or 50)
    elseif FlyBody.Parent then
        FlyBody.Velocity = Vector3.zero
        FlyBody.Parent = nil
    end
end))

TrackConn(Services.RunService.Stepped:Connect(function()
    if Toggles.Noclip and ToggleOn("Noclip") and LocalPlayer.Character then
        for _, P in ipairs(LocalPlayer.Character:GetDescendants()) do
            if P:IsA("BasePart") and P.CanCollide then
                P.CanCollide = false
            end
        end
    end
end))

Groupboxes.Misc_World = Tabs.Misc:AddRightGroupbox("World")
Groupboxes.Misc_World:AddToggle("Fullbright", { Text = "Fullbright", Default = false })
Groupboxes.Misc_World:AddToggle("AntiAFK", { Text = "Anti AFK", Default = false })

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
OnChange("Fullbright", function(V) pcall(ApplyBright, V) end)

local BrightAcc = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if Toggles.Fullbright and ToggleOn("Fullbright") then
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
OnChange("AntiAFK", function(Value)
    if Value then
        local Ok, VU = pcall(function() return game:GetService("VirtualUser") end)
        if Ok and VU then
            AFKConn = LocalPlayer.Idled:Connect(function()
                pcall(function()
                    VU:CaptureController()
                    VU:ClickButton2(Vector2.new())
                end)
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

-- // Auto Farm //
Groupboxes.Farm_Survive = Tabs.Farm:AddLeftGroupbox("Auto Farm (Survivor)")
Groupboxes.Farm_Survive:AddToggle("FarmFlee", {
    Text = "Kacis", Default = false,
    Tooltip = "Katil veya minion tehdit mesafesine yaklasinca haritanin diger ucuna isinlar.",
})
Groupboxes.Farm_Survive:AddSlider("FarmDanger", {
    Text = "Tehdit Mesafesi", Min = 5, Max = 400, Default = 50, Rounding = 0, Compact = true,
})
Groupboxes.Farm_Survive:AddToggle("FarmFleeMinions", {
    Text = "Minionlari da Say", Default = true,
})
Groupboxes.Farm_Survive:AddSlider("FarmFleeCooldown", {
    Text = "Kacis Araligi (sn)", Min = 0.5, Max = 20, Default = 3, Rounding = 1, Compact = true,
})
Groupboxes.Farm_Survive:AddToggle("FarmFleeRandom", {
    Text = "Rastgele Noktaya", Default = false,
    Tooltip = "Kapaliyken haritanin en uzak noktasina gider.",
})
Groupboxes.Farm_Survive:AddButton({
    Text = "Simdi Kac",
    DoubleClick = false,
    Func = function() FleeNow() end,
})

Groupboxes.Farm_Kill = Tabs.Farm:AddRightGroupbox("Auto Farm (Katil)")
Groupboxes.Farm_Kill:AddToggle("FarmKill", {
    Text = "Oyunculari Oldur", Default = false,
    Tooltip = "En yakin oyuncunun arkasina kilitlenip vurur; olce 2sn bekler, sonra digerine gider.",
})
Groupboxes.Farm_Kill:AddToggle("FarmBackstab", {
    Text = "Arkasina Kilitlen", Default = true,
})
Groupboxes.Farm_Kill:AddSlider("FarmBackstabTime", {
    Text = "Sabitlenme (sn)", Min = 0.2, Max = 5, Default = 2, Rounding = 1, Compact = true,
})
Groupboxes.Farm_Kill:AddSlider("FarmOffset", {
    Text = "Hedef Mesafesi", Min = 1, Max = 12, Default = 3, Rounding = 1, Compact = true,
})
Groupboxes.Farm_Kill:AddSlider("FarmHitRange", {
    Text = "Vurus Mesafesi", Min = 2, Max = 40, Default = 10, Rounding = 1, Compact = true,
})
Groupboxes.Farm_Kill:AddToggle("FarmMB1", {
    Text = "MB1 ile Vur", Default = true,
})
Groupboxes.Farm_Kill:AddToggle("FarmAbility", {
    Text = "Ability Tusu", Default = true,
})
Toggles.FarmAbility:AddKeyPicker("FarmAbilityKey", {
    Text = "Ability", Default = "R", Mode = "Toggle", SyncToggleState = true,
})
Groupboxes.Farm_Kill:AddToggle("FarmAbility2", {
    Text = "2. Ability Tusu", Default = false,
})
Toggles.FarmAbility2:AddKeyPicker("FarmAbilityKey2", {
    Text = "Ability 2", Default = "F", Mode = "Toggle", SyncToggleState = true,
})
Groupboxes.Farm_Kill:AddToggle("FarmUseSpy", {
    Text = "Spy Remote'unu Kullan", Default = true,
    Tooltip = "Spy ile kaydedilen son ability'yi otomatik atesler.",
})
Groupboxes.Farm_Kill:AddSlider("FarmDeathWait", {
    Text = "Oldukten Sonra (sn)", Min = 0, Max = 10, Default = 2, Rounding = 1, Compact = true,
})

-- Yardimcilar
local function ToKeyCode(Key)
    if Key == nil then return nil end
    if type(Key) == "EnumItem" then return Key end
    local Code = nil
    pcall(function() Code = Enum.KeyCode[string.upper(tostring(Key))] end)
    return Code
end

local function GetBoundKey(Picker)
    if not Picker then return nil end
    local State = nil
    pcall(function() State = Picker:GetState() end)
    if typeof(State) == "string" and State ~= "" and State ~= "None" and State ~= "Unbound" then
        return ToKeyCode(State)
    end
    return nil
end

local function SimulateKey(KeyCode, PressTime)
    if not KeyCode then return false end
    local Name = ""
    pcall(function() Name = string.lower(KeyCode.Name) end)
    local Used = false
    pcall(function()
        local VIM = Services.VirtualInputManager
        VIM:SendKeyEvent(true, KeyCode, false, game)
        Used = true
    end)
    task.wait(PressTime or 0.05)
    pcall(function()
        local VIM = Services.VirtualInputManager
        VIM:SendKeyEvent(false, KeyCode, false, game)
    end)
    if Used then return true end
    -- VIM client'ta yok: oyundaki tus butonunu aktiflestir
    local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local Fired = false
    local function Scan(Root, Depth)
        if not Root or Depth > 6 then return end
        for _, Child in ipairs(Root:GetChildren()) do
            if Child:IsA("GuiButton") or Child:IsA("TextButton") or Child:IsA("ImageButton") then
                local N = string.lower(Child.Name or "")
                local T = ""
                pcall(function() T = string.lower(Child.Text or "") end)
                if N == Name or T == Name then
                    pcall(function() Child:Activate() end)
                    pcall(function() Child.Activated:Fire() end)
                    Fired = true
                end
            end
            Scan(Child, Depth + 1)
        end
    end
    if PlayerGui then Scan(PlayerGui, 0) end
    return Fired
end

local function SimulateClick()
    local Used = false
    pcall(function()
        local VIM = Services.VirtualInputManager
        VIM:SendMouseButtonEvent(DISPLAY_CURSOR, MOUSE_BUTTON1, 0, true, 0, false)
        Used = true
    end)
    task.wait(0.05)
    pcall(function()
        local VIM = Services.VirtualInputManager
        VIM:SendMouseButtonEvent(DISPLAY_CURSOR, MOUSE_BUTTON1, 0, false, 0, false)
    end)
    if Used then return true end
    -- Fallback: elindeki tool'u aktiflestir
    local Char = LocalPlayer.Character
    if not Char then return false end
    local Hit = false
    for _, Item in ipairs(Char:GetChildren()) do
        if Item:IsA("Tool") then
            pcall(function() Item:Activate() end)
            Hit = true
        end
    end
    return Hit
end

local function IsSelfKiller()
    local Char = LocalPlayer.Character
    local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
    return Hum ~= nil and Hum.MaxHealth >= 500
end

-- Oyuncu disi canli NPC'ler (minion, zombie, summon)
local function GetMinionParts()
    local Result = {}
    local PlayerChars = {}
    for _, P in ipairs(Services.Players:GetPlayers()) do
        if P.Character then PlayerChars[P.Character] = true end
    end
    for _, D in ipairs(Services.Workspace:GetDescendants()) do
        if D:IsA("Humanoid") and D.Health > 0 then
            local Model = D.Parent
            if Model and Model:IsA("Model") and not PlayerChars[Model] then
                local Part = Model:FindFirstChild("HumanoidRootPart")
                    or Model:FindFirstChild("Head")
                    or Model:FindFirstChild("Torso")
                if Part then table.insert(Result, Part) end
            end
        end
    end
    return Result
end

local function NearestThreat()
    local HRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not HRP then return nil, math.huge end
    local Best, BestDist = nil, math.huge
    local Killer = FindKillerHRP()
    if Killer and Killer.Parent then
        Best, BestDist = Killer, (Killer.Position - HRP.Position).Magnitude
    end
    if Toggles.FarmFleeMinions and ToggleOn("FarmFleeMinions") then
        for _, Part in ipairs(GetMinionParts()) do
            if Part.Parent then
                local Dist = (Part.Position - HRP.Position).Magnitude
                if Dist < BestDist then Best, BestDist = Part, Dist end
            end
        end
    end
    return Best, BestDist
end

-- Harita parcalarini topla (oyuncu parcalari haric)
local function GetMapParts()
    local PlayerChars = {}
    for _, P in ipairs(Services.Players:GetPlayers()) do
        if P.Character then PlayerChars[P.Character] = true end
    end
    local Parts = {}
    local Count = 0
    for _, D in ipairs(Services.Workspace:GetDescendants()) do
        Count = Count + 1
        if Count > 4000 then break end
        if D:IsA("BasePart") then
            local Skip = false
            for Model in pairs(PlayerChars) do
                if D:IsDescendantOf(Model) then Skip = true break end
            end
            if not Skip then table.insert(Parts, D) end
        end
    end
    return Parts
end

local function TeleportTo(Part)
    local HRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not HRP or not Part then return false end
    local CF = HRP.CFrame
    return pcall(function()
        HRP.CFrame = CFrame.new(Part.Position + Vector3.new(0, 3, 0)) * (CF - CF.Position)
    end)
end

local FleeRunning = false
local FleeNow
function FleeNow()
    if FleeRunning then return end
    FleeRunning = true
    task.spawn(function()
        pcall(function()
            local Threat, Dist = NearestThreat()
            if not Threat or not Threat.Parent then return end
            local Danger = Options.FarmDanger and Options.FarmDanger.Value or 50
            if Dist > Danger then return end
            local Parts = GetMapParts()
            if #Parts == 0 then return end
            local Best, BestDist = nil, -1
            local Random = Toggles.FarmFleeRandom and ToggleOn("FarmFleeRandom")
            for _, Part in ipairs(Parts) do
                if Part.Parent then
                    local D = (Part.Position - Threat.Position).Magnitude
                    if D > BestDist then Best, BestDist = Part, D end
                end
            end
            if Random then
                Best = Parts[math.random(1, #Parts)]
            end
            if Best then TeleportTo(Best) end
        end)
        FleeRunning = false
    end)
end

local FleeAcc = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if not (Toggles.FarmFlee and ToggleOn("FarmFlee")) then
        FleeAcc = 0
        return
    end
    if IsSelfKiller() then
        FleeAcc = 0
        return
    end
    FleeAcc = FleeAcc + Delta
    local Interval = (Options.FarmFleeCooldown and Options.FarmFleeCooldown.Value) or 3
    if FleeAcc < Interval then return end
    FleeAcc = 0
    local HRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not HRP then return end
    local Threat, Dist = NearestThreat()
    if not Threat or not Threat.Parent then return end
    local Danger = Options.FarmDanger and Options.FarmDanger.Value or 50
    if Dist > Danger then return end
    local Parts = GetMapParts()
    if #Parts == 0 then return end
    local Best, BestDist = nil, -1
    for _, Part in ipairs(Parts) do
        if Part.Parent then
            local D = (Part.Position - Threat.Position).Magnitude
            if D > BestDist then Best, BestDist = Part, D end
        end
    end
    if Toggles.FarmFleeRandom and ToggleOn("FarmFleeRandom") then
        Best = Parts[math.random(1, #Parts)]
    end
    if Best then TeleportTo(Best) end
end))

local function FarmTargetAlive(Target)
    if not Target or not Target.Parent then return false end
    local Char = Target.Character
    if not Char then return false end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    if Hum and Hum.Health <= 0 then return false end
    return true
end

local function FindFarmTarget()
    local HRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not HRP then return nil end
    local Best, BestDist = nil, math.huge
    for _, P in ipairs(Services.Players:GetPlayers()) do
        if P ~= LocalPlayer and FarmTargetAlive(P) and AuraIsEnemy(P) then
            local Part = P.Character:FindFirstChild("HumanoidRootPart")
            if Part then
                local D = (Part.Position - HRP.Position).Magnitude
                if D < BestDist then Best, BestDist = P, D end
            end
        end
    end
    return Best
end

local function LockBehind(Target, Time, Offset)
    local HRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not HRP then return false end
    local End = tick() + Time
    while tick() < End do
        local Part = Target.Character and Target.Character:FindFirstChild("HumanoidRootPart")
        if not Part or not HRP.Parent or not Part.Parent then return false end
        local Hum = Target.Character:FindFirstChildOfClass("Humanoid")
        if Hum and Hum.Health <= 0 then return false end
        pcall(function()
            local Behind = Part.CFrame * CFrame.new(0, 0, Offset)
            HRP.CFrame = CFrame.lookAt(Behind.Position, Part.Position)
        end)
        task.wait()
    end
    return true
end

local function Attack(Target, Bursts)
    local HitRange = Options.FarmHitRange and Options.FarmHitRange.Value or 10
    local MyHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    for _ = 1, Bursts do
        if not FarmTargetAlive(Target) then return end
        local Part = Target.Character:FindFirstChild("HumanoidRootPart")
        if MyHRP and Part and (Part.Position - MyHRP.Position).Magnitude > HitRange then
            task.wait(0.1)
        else
            if Toggles.FarmMB1 and ToggleOn("FarmMB1") then SimulateClick() end
            if Toggles.FarmAbility and ToggleOn("FarmAbility") then
                SimulateKey(GetBoundKey(Options.FarmAbilityKey), 0.05)
            end
            if Toggles.FarmAbility2 and ToggleOn("FarmAbility2") then
                SimulateKey(GetBoundKey(Options.FarmAbilityKey2), 0.05)
            end
            if Toggles.FarmUseSpy and ToggleOn("FarmUseSpy") then RefireLast() end
            task.wait(0.2)
        end
    end
end

local KillLoopRunning = false
OnChange("FarmKill", function(Value)
    if Value then
        if KillLoopRunning then return end
        KillLoopRunning = true
        task.spawn(function()
            while Toggles.FarmKill and ToggleOn("FarmKill") do
                local Target = FindFarmTarget()
                if not Target then
                    task.wait(0.5)
                else
                    if Toggles.FarmBackstab and ToggleOn("FarmBackstab") then
                        local Time = Options.FarmBackstabTime and Options.FarmBackstabTime.Value or 2
                        local Offset = Options.FarmOffset and Options.FarmOffset.Value or 3
                        LockBehind(Target, Time, Offset)
                    end
                    Attack(Target, 3)
                    local WaitFor = Options.FarmDeathWait and Options.FarmDeathWait.Value or 2
                    local End = tick() + WaitFor
                    while tick() < End and FarmTargetAlive(Target) do
                        Attack(Target, 1)
                    end
                    task.wait(0.3)
                end
            end
            KillLoopRunning = false
        end)
    else
        KillLoopRunning = false
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
                if P:IsA("BasePart") and P.Name ~= "HumanoidRootPart" then
                    P.CanCollide = true
                end
            end
        end
    end)
    pcall(ApplyBright, false)
    pcall(RestoreStamina)
    pcall(function()
        local Char = LocalPlayer.Character
        local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
        if Hum then
            Hum.UseJumpPower = true
            Hum.JumpPower = 50
        end
        if Char then
            local Head = Char:FindFirstChild("Head")
            if Head and HitboxSaved then Head.Size = HitboxSaved end
        end
    end)
    pcall(function() Services.StarterGui:SetCore("SendNotification", true) end)
    pcall(function()
        if _G.FS_FOVCircle then _G.FS_FOVCircle:Remove() end
        _G.FS_FOVCircle = nil
        _G.FS_Locked = nil
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
Abysall.Interface.ApplyAddons(Window, "forsaken")
Library:Notify("Forsaken destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")
