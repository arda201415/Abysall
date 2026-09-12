-- Abysall Hub | Murder Duels (Breakfast)
-- PlaceIds: 120851538706364 (main), 120783481568445 (Trading Plaza)
-- Not: FPS duel oyunu (1v1-4v4, first to 5). Kamera = silah oldugu icin
-- camera-lock aimbot server-side hit sayilir. SilentAim remote hook'u
-- remote isimleri dump'lanmadan eklenmedi (asagidaki Dump butonunu kullan).

local LoadStart = tick()
Abysall.SavePath = "MurderDuels"

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

local Window = Library:CreateWindow({
    Title = "Abysall Hub | Murder Duels",
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
}

-- // Combat: Aimbot (camera lock) //
local Groupboxes = {}
Groupboxes.Combat_Aim = Tabs.Combat:AddLeftGroupbox("Aimbot")

Groupboxes.Combat_Aim:AddToggle("AimbotEnabled", {
    Text = "Aimbot", Default = false,
    Tooltip = "Kamerayi en yakin dusmana kilitler. FPS oldugu icin atis server'a isabetli gider.",
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
Groupboxes.Combat_Aim:AddToggle("AimbotTeamCheck", {
    Text = "Team Check", Default = true,
})
Groupboxes.Combat_Aim:AddToggle("AimbotWallCheck", {
    Text = "Wall Check", Default = false,
    Tooltip = "Duvar arkasi hedefi gormezden gelir (raycast).",
})
Groupboxes.Combat_Aim:AddSlider("AimSmooth", {
    Text = "Yumusatma", Min = 1, Max = 20, Default = 1, Rounding = 0, Compact = true,
    Tooltip = "1 = aninda kilit (Solara'da 1 birak). Yuksek deger daha dogal ama yavas.",
})
Groupboxes.Combat_Aim:AddToggle("AimSticky", {
    Text = "Sticky Target", Default = true,
    Tooltip = "Hedef FOV disina cikana kadar ayni hedefte kalir, titreme yapmaz.",
})
Groupboxes.Combat_Aim:AddToggle("AimFOVCircle", { Text = "FOV Dairesi", Default = true })

local function IsEnemy(Player)
    if Player == LocalPlayer then return false end
    if not Player.Character then return false end
    if Player:GetAttribute("Alive") == false then return false end
    if Toggles.AimbotTeamCheck and Toggles.AimbotTeamCheck.Value then
        pcall(function()
            if LocalPlayer.Team ~= nil and Player.Team ~= nil and Player.Team == LocalPlayer.Team then
                return false
            end
        end)
        if LocalPlayer.Team ~= nil and Player.Team ~= nil and Player.Team == LocalPlayer.Team then
            return false
        end
    end
    local Char = Player.Character
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    if Hum and Hum.Health <= 0 then return false end
    return true
end

local function IsVisible(TargetPart)
    if not Toggles.AimbotWallCheck or not Toggles.AimbotWallCheck.Value then
        return true
    end
    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    RayParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    local Result = Services.Workspace:Raycast(Camera.CFrame.Position, (TargetPart.Position - Camera.CFrame.Position), RayParams)
    if not Result then return true end
    return Result.Instance:IsDescendantOf(TargetPart.Parent)
end

local function GetMousePos()
    local Loc = Services.UserInputService:GetMouseLocation()
    return Vector2.new(Loc.X, Loc.Y)
end

local function GetClosestTarget()
    local Best, BestDist = nil, Options.AimbotFOV and Options.AimbotFOV.Value or 200
    local PartName = Options.AimbotPart and Options.AimbotPart.Value or "Head"
    local Mouse = GetMousePos()
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if IsEnemy(Player) then
            local Part = Player.Character:FindFirstChild(PartName)
            if Part then
                local Pos, OnScreen = Camera:WorldToViewportPoint(Part.Position)
                if OnScreen then
                    local Dist = (Vector2.new(Pos.X, Pos.Y) - Mouse).Magnitude
                    if Dist < BestDist and IsVisible(Part) then
                        BestDist = Dist
                        Best = Part
                    end
                end
            end
        end
    end
    return Best
end

Services.RunService.RenderStepped:Connect(function()
    -- FOV dairesi (Drawing varsa, hook gerekmez -> Solara uyumlu)
    if typeof(Drawing) == "function" or typeof(getgenv) == "function" then
        pcall(function()
            if not _G.MD_FOVCircle and Drawing then
                local C = Drawing.new("Circle")
                C.Thickness = 1
                C.NumSides = 64
                C.Filled = false
                C.Color = Color3.fromRGB(255, 255, 255)
                _G.MD_FOVCircle = C
            end
            if _G.MD_FOVCircle then
                local Show = Toggles.AimbotEnabled and Toggles.AimbotEnabled.Value and Toggles.AimFOVCircle and Toggles.AimFOVCircle.Value
                _G.MD_FOVCircle.Visible = Show or false
                if Show then
                    local M = GetMousePos()
                    _G.MD_FOVCircle.Position = M
                    _G.MD_FOVCircle.Radius = Options.AimbotFOV and Options.AimbotFOV.Value or 200
                end
            end
        end)
    end

    if Toggles.AimbotEnabled and Toggles.AimbotEnabled.Value then
        local HoldingKey = Options.AimbotKey and Options.AimbotKey:GetState()
        local HoldingRMB = Toggles.AimbotUseRMB and Toggles.AimbotUseRMB.Value and Services.UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if HoldingKey or HoldingRMB then
            local Target = GetClosestTarget()
            -- Sticky: bir onceki hedef hala gecerliyse onu koru
            if Toggles.AimSticky and Toggles.AimSticky.Value and _G.MD_Locked and _G.MD_Locked.Parent then
                local LP = _G.MD_Locked
                local Pos, On = Camera:WorldToViewportPoint(LP.Position)
                if On and (Vector2.new(Pos.X, Pos.Y) - GetMousePos()).Magnitude <= (Options.AimbotFOV.Value + 50) then
                    Target = LP
                else
                    _G.MD_Locked = nil
                end
            end
            if Target then
                _G.MD_Locked = Target
                local Goal = CFrame.new(Camera.CFrame.Position, Target.Position)
                local Smooth = Options.AimSmooth and Options.AimSmooth.Value or 1
                if Smooth <= 1 then
                    Camera.CFrame = Goal
                else
                    Camera.CFrame = Camera.CFrame:Lerp(Goal, 1 / Smooth)
                end
            end
        else
            _G.MD_Locked = nil
        end
    end
end)

Groupboxes.Combat_Aim:AddDivider()
Groupboxes.Combat_Aim:AddButton({
    Text = "Dump Remotes (F9'a bas)",
    DoubleClick = false,
    Func = function()
        for _, Obj in pairs(game:GetDescendants()) do
            if Obj:IsA("RemoteEvent") or Obj:IsA("RemoteFunction") then
                local N = Obj:GetFullName()
                if N:lower():find("shoot") or N:lower():find("fire") or N:lower():find("network") or N:lower():find("damage") or N:lower():find("revolv") or N:lower():find("knife") then
                    print("[Abysall-Dump] " .. Obj.ClassName .. " | " .. N)
                end
            end
        end
        Library:Notify("Dump konsola yazildi (F9).")
    end
})

-- // Silent Aim: ShootReplicate hook //
Groupboxes.Combat_Silent = Tabs.Combat:AddRightGroupbox("Silent Aim")

Groupboxes.Combat_Silent:AddToggle("SilentAim", {
    Text = "Silent Aim", Default = false,
    Tooltip = "Ates ettiginde mermiyi FOV icindeki dusmana yonlendirir. Kamera oynamaz.",
})
Groupboxes.Combat_Silent:AddSlider("SilentFOV", {
    Text = "Silent FOV", Min = 10, Max = 1000, Default = 250, Rounding = 0, Compact = true,
})
Groupboxes.Combat_Silent:AddDropdown("SilentPart", {
    Text = "Hedef Parca", Values = { "Head", "HumanoidRootPart" }, Default = 1,
})
Groupboxes.Combat_Silent:AddToggle("SilentTeamCheck", { Text = "Team Check", Default = true })
Groupboxes.Combat_Silent:AddToggle("LogShootArgs", {
    Text = "Shoot Arg Logla (F9)", Default = false,
    Tooltip = "Ates edince ShootReplicate argumanlarini konsola basar. Format icin 1 kez acip 2-3 el ates et.",
})

local ShootRemote = Services.ReplicatedStorage:WaitForChild("Remotes", 10) and Services.ReplicatedStorage.Remotes:WaitForChild("ShootReplicate", 10)

local function GetSilentTarget()
    local Best, BestDist = nil, Options.SilentFOV and Options.SilentFOV.Value or 250
    local PartName = Options.SilentPart and Options.SilentPart.Value or "Head"
    local Mouse = GetMousePos()
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player == LocalPlayer then continue end
        local Char = Player.Character
        if not Char then continue end
        local Hum = Char:FindFirstChildOfClass("Humanoid")
        if not Hum or Hum.Health <= 0 then continue end
        if Toggles.SilentTeamCheck and Toggles.SilentTeamCheck.Value then
            if LocalPlayer.Team ~= nil and Player.Team ~= nil and Player.Team == LocalPlayer.Team then
                continue
            end
        end
        local Part = Char:FindFirstChild(PartName)
        if Part and IsVisible(Part) then
            local Pos, On = Camera:WorldToViewportPoint(Part.Position)
            if On then
                local D = (Vector2.new(Pos.X, Pos.Y) - Mouse).Magnitude
                if D < BestDist then Best, BestDist = Part, D end
            end
        end
    end
    return Best
end

local function RewriteShootArgs(Args, Target)
    local OriginIdx, DirIdx = nil, nil
    for I, A in pairs(Args) do
        if typeof(A) == "Vector3" then
            if OriginIdx == nil then
                OriginIdx = I
            elseif DirIdx == nil then
                DirIdx = I
                break
            end
        end
    end
    if OriginIdx and DirIdx then
        local Origin = Args[OriginIdx]
        Args[DirIdx] = (Target.Position - Origin).Unit * (Args[DirIdx].Magnitude > 0 and Args[DirIdx].Magnitude or 1000)
    else
        for I, A in pairs(Args) do
            if typeof(A) == "CFrame" then
                Args[I] = CFrame.new(A.Position, Target.Position)
                break
            end
        end
    end
    return Args
end

local function LogArgs(Args)
    if Toggles.LogShootArgs and Toggles.LogShootArgs.Value then
        for I, A in pairs(Args) do
            print("[Abysall-Shoot] arg" .. I .. " type=" .. typeof(A) .. " val=" .. tostring(A))
        end
    end
end

local HasNamecallHook = CheckCompat({ "hookmetamethod", "getnamecallmethod", "newcclosure" })
local HasFuncHook = CheckCompat({ "hookfunction", "newcclosure" })

if ShootRemote and HasNamecallHook then
    pcall(function()
    local OldNamecall
    OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(Self, ...)
        local Args = { ... }
        local Method = getnamecallmethod()
        if Self == ShootRemote and (Method == "FireServer" or Method == "fireServer") then
            LogArgs(Args)
            if Toggles.SilentAim and Toggles.SilentAim.Value then
                local Target = GetSilentTarget()
                if Target then
                    Args = RewriteShootArgs(Args, Target)
                    return OldNamecall(Self, unpack(Args))
                end
            end
        end
        return OldNamecall(Self, ...)
    end))
    end)
elseif ShootRemote and HasFuncHook then
    -- hookmetamethod yoksa fallback: FireServer'in kendisini hookla
    pcall(function()
    local OldFire
    OldFire = hookfunction(ShootRemote.FireServer, newcclosure(function(Self, ...)
        local Args = { ... }
        LogArgs(Args)
        if Toggles.SilentAim and Toggles.SilentAim.Value then
            local Target = GetSilentTarget()
            if Target then
                Args = RewriteShootArgs(Args, Target)
                return OldFire(Self, unpack(Args))
            end
        end
        return OldFire(Self, ...)
    end))
    end)
    Groupboxes.Combat_Silent:AddLabel("hookmetamethod yok, hookfunction ile calisiyor.", true)
else
    local Missing = {}
    for _, N in pairs({ "hookmetamethod", "getnamecallmethod", "newcclosure", "hookfunction" }) do
        if not Abysall.Environment[N] then table.insert(Missing, N) end
    end
    Groupboxes.Combat_Silent:AddLabel("Executor desteklemiyor (" .. table.concat(Missing, ", ") .. "). Silent kapali, Triggerbot kullan.", true)
end

-- Hook'suz Triggerbot: crosshair dusmandaysa oto-ates (mouse1click varsa)
Groupboxes.Combat_Silent:AddToggle("Triggerbot", { Text = "Triggerbot (hook'suz)", Default = false })
Groupboxes.Combat_Silent:AddSlider("TriggerFOV", { Text = "Trigger FOV", Min = 1, Max = 50, Default = 8, Rounding = 0, Compact = true })

Services.RunService.RenderStepped:Connect(function()
    if Toggles.Triggerbot and Toggles.Triggerbot.Value then
        local PartName = Options.SilentPart and Options.SilentPart.Value or "Head"
        local Mouse = GetMousePos()
        local Limit = Options.TriggerFOV and Options.TriggerFOV.Value or 8
        for _, Player in pairs(Services.Players:GetPlayers()) do
            if Player == LocalPlayer then continue end
            local Char = Player.Character
            if not Char then continue end
            local Hum = Char:FindFirstChildOfClass("Humanoid")
            if not Hum or Hum.Health <= 0 then continue end
            if Toggles.SilentTeamCheck and Toggles.SilentTeamCheck.Value then
                if LocalPlayer.Team ~= nil and Player.Team ~= nil and Player.Team == LocalPlayer.Team then
                    continue
                end
            end
            local Part = Char:FindFirstChild(PartName)
            if Part then
                local Pos, On = Camera:WorldToViewportPoint(Part.Position)
                if On and (Vector2.new(Pos.X, Pos.Y) - Mouse).Magnitude <= Limit then
                    if typeof(mouse1click) == "function" then
                        mouse1click()
                    end
                    break
                end
            end
        end
    end
end)

-- // Visuals: Player ESP (mevcut ESP kutuphanesi ile) //
Groupboxes.Visuals_ESP = Tabs.Visuals:AddLeftGroupbox("Player ESP")

Groupboxes.Visuals_ESP:AddToggle("PlayerESP", {
    Text = "Player ESP", Default = false, Tooltip = "Dusmanlari highlight + isim ile gosterir.",
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

-- Doors'taki room-based AddESP burada gerekli degil, direkt kutuphane
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

Services.Players.PlayerAdded:Connect(function(Player)
    Player.CharacterAdded:Connect(function(Char)
        task.wait(1)
        if Toggles.PlayerESP.Value and ShouldESP(Player) then
            AddPlayerESP({ Object = Char, Text = Player.Name, Color = Options.PlayerESPColor.Value })
        end
    end)
end)
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

-- // Misc //
Groupboxes.Misc_Move = Tabs.Misc:AddLeftGroupbox("Movement")
Groupboxes.Misc_Move:AddSlider("WalkSpeedVal", {
    Text = "WalkSpeed", Min = 16, Max = 100, Default = 16, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("WalkSpeedOn", { Text = "Speed", Default = false })

Services.RunService.RenderStepped:Connect(function()
    if Toggles.WalkSpeedOn and Toggles.WalkSpeedOn.Value and LocalPlayer.Character then
        local Hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Hum then Hum.WalkSpeed = Options.WalkSpeedVal.Value end
    end
end)

Library:OnUnload(function()
    getgenv().Abysall = nil
end)

Abysall.Interface.ApplySettingsTab(Window)
Library:Notify("Murder Duels destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")
