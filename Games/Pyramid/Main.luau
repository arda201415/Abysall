-- Abysall Hub | Build the Pyramid!
-- PlaceId: 123720558354386
-- Knit tabanli: BookService (Pickup/Drop), PyramidService (Place),
-- GymService (StartBench/StopBench), DataService (Upgrade),
-- FreeGiftService (Claim), CodesService (Redeem).
-- RF'ler argsiz denenir; dogru format icin Ability Spy kullanilir.

local LoadStart = tick()
if not Abysall or not Abysall.Interface then
    warn("[Abysall] Pyramid direkt calistirildi: once ana Loader (README loadstring) calistir.")
    return
end
Abysall.SavePath = "Pyramid"

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
    Title = "Abysall Hub | Build the Pyramid",
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
    Farm = Window:AddTab("Farm", "wheat"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Misc = Window:AddTab("Misc", "house"),
}

local Groupboxes = {}

local function FindRemote(Name)
    local Found = Services.ReplicatedStorage:FindFirstChild(Name, true)
    if Found and (Found:IsA("RemoteEvent") or Found:IsA("RemoteFunction")) then
        return Found
    end
    return nil
end

local InternalFire = false

local function CallRemote(Name, ...)
    local R = FindRemote(Name)
    if not R then
        Library:Notify("Bulunamadi: " .. Name)
        return nil
    end
    local Args = { ... }
    InternalFire = true
    local Results = { pcall(function()
        if R:IsA("RemoteEvent") then
            R:FireServer(table.unpack(Args))
            return true
        else
            return R:InvokeServer(table.unpack(Args))
        end
    end) }
    InternalFire = false
    local Ok = table.remove(Results, 1)
    if Ok then
        return true, table.unpack(Results)
    else
        Library:Notify("Hata (" .. Name .. "): " .. tostring(Results[1]):sub(1, 80))
        return false
    end
end

-- // Farm: blok dongusu //
Groupboxes.Farm_Block = Tabs.Farm:AddLeftGroupbox("Auto Block")

Groupboxes.Farm_Block:AddToggle("AutoPickup", {
    Text = "Auto Pickup", Default = false, Tooltip = "Blok almayi dener.",
})
Groupboxes.Farm_Block:AddToggle("AutoPlace", {
    Text = "Auto Place", Default = false, Tooltip = "Tasidigin blogu koymayi dener.",
})
Groupboxes.Farm_Block:AddSlider("BlockInterval", {
    Text = "Aralik (sn)", Min = 0.5, Max = 10, Default = 2, Rounding = 1, Compact = true,
})
Groupboxes.Farm_Block:AddDivider()
Groupboxes.Farm_Block:AddButton({
    Text = "Pickup Simdi", DoubleClick = false,
    Func = function() CallRemote("Pickup") end,
})
Groupboxes.Farm_Block:AddButton({
    Text = "Place Simdi", DoubleClick = false,
    Func = function() CallRemote("Place") end,
})
Groupboxes.Farm_Block:AddButton({
    Text = "Drop", DoubleClick = false,
    Func = function() CallRemote("Drop") end,
})
Groupboxes.Farm_Block:AddLabel("Argsiz denemeler; olmazsa Spy ile format bul.", true)

local BlockAcc = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    local DoPick = Toggles.AutoPickup and ToggleOn("AutoPickup")
    local DoPlace = Toggles.AutoPlace and ToggleOn("AutoPlace")
    if not (DoPick or DoPlace) then
        BlockAcc = 0
        return
    end
    BlockAcc = BlockAcc + Delta
    local Interval = (Options.BlockInterval and Options.BlockInterval.Value) or 2
    if BlockAcc < Interval then return end
    BlockAcc = 0
    if DoPick then CallRemote("Pickup") end
    if DoPlace then CallRemote("Place") end
end))

-- // Farm: antrenman + hediye + kod //
Groupboxes.Farm_Train = Tabs.Farm:AddRightGroupbox("Train & Gifts")

Groupboxes.Farm_Train:AddToggle("AutoBench", {
    Text = "Auto Bench", Default = false, Tooltip = "Bench antrenmanini baslatir.",
})
Groupboxes.Farm_Train:AddSlider("BenchInterval", {
    Text = "Aralik (sn)", Min = 1, Max = 30, Default = 5, Rounding = 0, Compact = true,
})
Groupboxes.Farm_Train:AddButton({
    Text = "Start Bench", DoubleClick = false,
    Func = function() CallRemote("StartBench") end,
})
Groupboxes.Farm_Train:AddButton({
    Text = "Stop Bench", DoubleClick = false,
    Func = function() CallRemote("StopBench") end,
})
Groupboxes.Farm_Train:AddDivider()
Groupboxes.Farm_Train:AddButton({
    Text = "Claim Free Gift", DoubleClick = false,
    Func = function()
        local Ok = CallRemote("Claim")
        if Ok then Library:Notify("Gift istendi.") end
    end,
})
Groupboxes.Farm_Train:AddInput("RedeemCode", {
    Text = "Kod", Default = "", Numeric = false, Finished = false,
    Placeholder = "Kodu yaz",
})
Groupboxes.Farm_Train:AddButton({
    Text = "Redeem", DoubleClick = false,
    Func = function()
        local Code = Options.RedeemCode and Options.RedeemCode.Value or ""
        if Code == "" then
            Library:Notify("Once kod yaz.")
            return
        end
        local Ok, Res = CallRemote("Redeem", Code)
        if Ok then Library:Notify("Redeem dondu: " .. tostring(Res):sub(1, 100)) end
    end,
})

local BenchAcc = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    if Toggles.AutoBench and ToggleOn("AutoBench") then
        BenchAcc = BenchAcc + Delta
        local Interval = (Options.BenchInterval and Options.BenchInterval.Value) or 5
        if BenchAcc >= Interval then
            BenchAcc = 0
            CallRemote("StartBench")
        end
    else
        BenchAcc = 0
    end
end))

-- // Farm: Spy + Dump //
local RefireLast
Groupboxes.Farm_Spy = Tabs.Farm:AddLeftGroupbox("Spy")

Groupboxes.Farm_Spy:AddToggle("LogAbilityArgs", {
    Text = "Log Remote (F9)", Default = false,
    Tooltip = "Oynarken cagrilan remote + argumanlari kaydeder.",
})
Groupboxes.Farm_Spy:AddButton({
    Text = "Son Remote'u Tekrar", DoubleClick = false,
    Func = function() RefireLast() end,
})
Groupboxes.Farm_Spy:AddToggle("SpamLastRemote", { Text = "Spam Son Remote", Default = false })
Groupboxes.Farm_Spy:AddSlider("SpamInterval", {
    Text = "Spam Araligi (sn)", Min = 0.2, Max = 10, Default = 1, Rounding = 1, Compact = true,
})
Groupboxes.Farm_Spy:AddButton({
    Text = "Dump Remotes (F9'a bas)", DoubleClick = false,
    Func = function()
        for _, Obj in pairs(Services.ReplicatedStorage:GetDescendants()) do
            if Obj:IsA("RemoteEvent") or Obj:IsA("RemoteFunction") then
                print("[Abysall-Dump] " .. Obj.ClassName .. " | " .. Obj:GetFullName())
            end
        end
        Library:Notify("Dump konsola yazildi (F9).")
    end
})
Groupboxes.Farm_Spy:AddInput("FireRemoteName", {
    Text = "Remote Adi", Default = "", Numeric = false, Finished = false,
    Placeholder = "Orn: PurchaseUpgrade",
})
Groupboxes.Farm_Spy:AddButton({
    Text = "Isimle Atesle (argsiz)", DoubleClick = false,
    Func = function()
        local Name = Options.FireRemoteName and Options.FireRemoteName.Value or ""
        if Name == "" then
            Library:Notify("Once remote adi yaz.")
            return
        end
        CallRemote(Name)
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
                end
            end
        end
        return Old(Self, ...)
    end))
end
OnChange("LogAbilityArgs", function(Value) if Value then InstallSpy() end end)

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
    if Toggles.SpamLastRemote and ToggleOn("SpamLastRemote") and LastRecorded then
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

local function AddPlayerESP(Data)
    pcall(function()
        Abysall.ESPLibrary:AddESP(Data)
        Data.Object.Destroying:Once(function()
            if Abysall then Abysall.ESPLibrary:RemoveESP(Data.Object) end
        end)
    end)
end

OnChange("PlayerESP", function(Value)
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
        if Player.Character then Abysall.ESPLibrary:UpdateObjectColor(Player.Character, Value) end
    end
end)

TrackConn(Services.Players.PlayerAdded:Connect(function(Player)
    Player.CharacterAdded:Connect(function(Char)
        task.wait(1)
        if ToggleOn("PlayerESP") and ShouldESP(Player) then
            AddPlayerESP({ Object = Char, Text = Player.Name, Color = Options.PlayerESPColor.Value })
        end
    end)
end))
for _, Player in pairs(Services.Players:GetPlayers()) do
    if Player ~= LocalPlayer then
        Player.CharacterAdded:Connect(function(Char)
            task.wait(1)
            if ToggleOn("PlayerESP") and ShouldESP(Player) then
                AddPlayerESP({ Object = Char, Text = Player.Name, Color = Options.PlayerESPColor.Value })
            end
        end)
    end
end

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
Toggles.Fly:AddKeyPicker("FlyKey", { Text = "Fly", Default = "F", Mode = "Toggle", SyncToggleState = true })
Groupboxes.Misc_Move:AddSlider("FlySpeed", {
    Text = "Fly Speed", Min = 0, Max = 200, Default = 50, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("Noclip", { Text = "Noclip", Default = false })
Toggles.Noclip:AddKeyPicker("NoclipKey", { Text = "Noclip", Default = "N", Mode = "Toggle", SyncToggleState = true })

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
            if P:IsA("BasePart") and P.CanCollide then P.CanCollide = false end
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
Abysall.Interface.ApplyAddons(Window, "pyramid")
Library:Notify("Pyramid destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")
