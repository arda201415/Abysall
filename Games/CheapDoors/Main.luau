-- Abysall Hub | DOORS but kinda cheap and shorter (THouse Studios)
-- PlaceIds: 10926417608 (oyun), 10873387885 (root/lobi)
-- Entity uyarilari ClientEntityEvent'ten, revive ReviveEvent'ten.

local LoadStart = tick()
Abysall.SavePath = "CheapDoors"

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
    Title = "Abysall Hub | Cheap Doors",
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
    General = Window:AddTab("General", "house"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Misc = Window:AddTab("Misc", "wind"),
}

local Groupboxes = {}

local function FindRemote(Name)
    local Found = Services.ReplicatedStorage:FindFirstChild(Name, true)
    if Found and (Found:IsA("RemoteEvent") or Found:IsA("RemoteFunction")) then
        return Found
    end
    return nil
end

-- // General: hayatta kalma //
Groupboxes.General_Survival = Tabs.General:AddLeftGroupbox("Survival")

Groupboxes.General_Survival:AddToggle("AutoRevive", {
    Text = "Auto Revive", Default = false,
    Tooltip = "Olunce ReviveEvent atesler.",
})
Groupboxes.General_Survival:AddButton({
    Text = "Revive",
    DoubleClick = false,
    Func = function()
        local R = FindRemote("ReviveEvent")
        if not R then
            Library:Notify("ReviveEvent bulunamadi.")
            return
        end
        local Ok = pcall(function()
            if R:IsA("RemoteEvent") then R:FireServer() else R:InvokeServer() end
        end)
        Library:Notify(Ok and "Revive ateslendi." or "Revive basarisiz.")
    end,
})
Groupboxes.General_Survival:AddInput("ReviveName", {
    Text = "Oyuncu", Default = "", Numeric = false, Finished = false,
    Placeholder = "Isim yaz",
})
Groupboxes.General_Survival:AddButton({
    Text = "Revive Player",
    DoubleClick = false,
    Func = function()
        local Name = Options.ReviveName and Options.ReviveName.Value or ""
        if Name == "" then
            Library:Notify("Once oyuncu adi yaz.")
            return
        end
        local Target = nil
        for _, P in pairs(Services.Players:GetPlayers()) do
            if P ~= LocalPlayer and P.Name:lower():find(Name:lower(), 1, true) then
                Target = P
                break
            end
        end
        if not Target then
            Library:Notify("Oyuncu bulunamadi.")
            return
        end
        local R = FindRemote("ReviveEvent")
        if not R then
            Library:Notify("ReviveEvent bulunamadi.")
            return
        end
        local Ok = pcall(function()
            if R:IsA("RemoteEvent") then R:FireServer(Target) else R:InvokeServer(Target) end
        end)
        Library:Notify(Ok and ("Revive denendi: " .. Target.Name) or "Revive basarisiz.")
    end,
})

local function HookDeath(Char)
    local Hum = Char:WaitForChild("Humanoid", 10)
    if not Hum then return end
    Hum.Died:Connect(function()
        if Toggles.AutoRevive and Toggles.AutoRevive.Value then
            task.wait(2)
            local R = FindRemote("ReviveEvent")
            if R and R:IsA("RemoteEvent") then
                local Ok = pcall(function() R:FireServer() end)
                Library:Notify(Ok and "Revive ateslendi." or "Revive basarisiz.")
            else
                Library:Notify("ReviveEvent bulunamadi.")
            end
        end
    end)
end
if LocalPlayer.Character then task.spawn(HookDeath, LocalPlayer.Character) end
TrackConn(LocalPlayer.CharacterAdded:Connect(function(Char)
    task.wait(1)
    HookDeath(Char)
end))

Groupboxes.General_Survival:AddToggle("EntityAlerts", {
    Text = "Entity Alerts", Default = false,
    Tooltip = "ClientEntityEvent gelince bildirir + F9'a argumanlari basar.",
})
Groupboxes.General_Survival:AddButton({
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
Groupboxes.General_Survival:AddInput("FireRemoteName", {
    Text = "Remote Adi", Default = "", Numeric = false, Finished = false,
    Placeholder = "Orn: ReviveEvent",
})
Groupboxes.General_Survival:AddButton({
    Text = "Isimle Atesle (argsiz)",
    DoubleClick = false,
    Func = function()
        local Name = Options.FireRemoteName and Options.FireRemoteName.Value or ""
        if Name == "" then
            Library:Notify("Once remote adi yaz.")
            return
        end
        local R = FindRemote(Name)
        if not R then
            Library:Notify("Bulunamadi: " .. Name)
            return
        end
        local Ok, Err = pcall(function()
            if R:IsA("RemoteEvent") then R:FireServer() else R:InvokeServer() end
        end)
        if Ok then Library:Notify("Ateslendi: " .. Name)
        else Library:Notify("Hata: " .. tostring(Err):sub(1, 80)) end
    end
})

-- // General: kapi isinlanma (en yuksek numarali oda taramasi) //
Groupboxes.General_TP = Tabs.General:AddRightGroupbox("Door Teleport")

local LastTP = 0

local function SortedRooms()
    local List = {}
    local Seen = {}
    for _, D in ipairs(Services.Workspace:GetDescendants()) do
        if D:IsA("Model") and tonumber(D.Name) and not Seen[D] then
            local Door = D:FindFirstChild("Door", true)
            if Door then
                Seen[D] = true
                table.insert(List, { Num = tonumber(D.Name), Model = D, Door = Door })
            end
        end
    end
    table.sort(List, function(A, B) return A.Num < B.Num end)
    return List
end

local function DoorCF(Door)
    if Door:IsA("BasePart") then return Door.CFrame end
    if Door:IsA("Model") then
        local Ok, CF = pcall(function() return Door:GetBoundingBox() end)
        if Ok and CF then return CF end
        local PP = Door.PrimaryPart
        if PP then return PP.CFrame end
    end
    return nil
end

local function AliveHRP()
    local Char = LocalPlayer.Character
    local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
    local HRP = Char and Char:FindFirstChild("HumanoidRootPart")
    if Hum and HRP and Hum.Health > 0 then return HRP end
    return nil
end

local function TPTo(Entry)
    if tick() - LastTP < 0.2 then return end
    LastTP = tick()
    local HRP = AliveHRP()
    local CF = Entry and DoorCF(Entry.Door) or nil
    if HRP and CF then
        pcall(function() HRP.CFrame = CF + Vector3.new(0, 5, 0) end)
        Library:Notify("Oda " .. Entry.Num)
    end
end

local function NearestNum(List)
    local HRP = AliveHRP()
    if not HRP then return nil end
    local BestNum, BestDist = nil, math.huge
    for _, E in ipairs(List) do
        local CF = DoorCF(E.Door)
        if CF then
            local D = (CF.Position - HRP.Position).Magnitude
            if D < BestDist then BestDist = D BestNum = E.Num end
        end
    end
    return BestNum
end

Groupboxes.General_TP:AddButton({
    Text = "En Son Kapi",
    DoubleClick = false,
    Func = function()
        local List = SortedRooms()
        if #List == 0 then
            Library:Notify("Oda bulunamadi.")
            return
        end
        TPTo(List[#List])
    end,
})
Groupboxes.General_TP:AddButton({
    Text = "Sonraki Kapi",
    DoubleClick = false,
    Func = function()
        local List = SortedRooms()
        if #List == 0 then
            Library:Notify("Oda bulunamadi.")
            return
        end
        local Cur = NearestNum(List) or List[#List].Num
        for _, E in ipairs(List) do
            if E.Num > Cur then
                TPTo(E)
                return
            end
        end
        TPTo(List[#List])
    end,
})
Groupboxes.General_TP:AddButton({
    Text = "Onceki Kapi",
    DoubleClick = false,
    Func = function()
        local List = SortedRooms()
        if #List == 0 then
            Library:Notify("Oda bulunamadi.")
            return
        end
        local Cur = NearestNum(List) or List[1].Num
        for I = #List, 1, -1 do
            if List[I].Num < Cur then
                TPTo(List[I])
                return
            end
        end
        TPTo(List[1])
    end,
})
Groupboxes.General_TP:AddLabel("Tiklar arasi 0.2sn bekleme var.", true)

local EntityHooked = falselocal function HookEntities()
    if EntityHooked then return end
    local CE = FindRemote("ClientEntityEvent")
    if not CE then
        Library:Notify("ClientEntityEvent bulunamadi.")
        return
    end
    EntityHooked = true
    TrackConn(CE.OnClientEvent:Connect(function(...)
        local Args = { ... }
        for I, A in ipairs(Args) do
            print("[Abysall-Entity] arg" .. I .. " " .. typeof(A) .. " = " .. tostring(A):sub(1, 160))
        end
        -- Isim tespiti: A-60 / A-120 oncelikli, yoksa ilk kisa string
        local EntName = nil
        for _, A in ipairs(Args) do
            if typeof(A) == "string" then
                local U = A:upper():gsub("%s+", "")
                if U:find("A%-?60") then EntName = "A-60" break end
                if U:find("A%-?120") then EntName = "A-120" break end
            end
        end
        if not EntName then
            for _, A in ipairs(Args) do
                if typeof(A) == "string" and #A < 40 then
                    EntName = A
                    break
                end
            end
        end
        if Toggles.EntityAlerts and Toggles.EntityAlerts.Value then
            if EntName == "A-60" or EntName == "A-120" then
                Library:Notify(EntName .. " geliyor! Saklan!")
            else
                Library:Notify(EntName or "Entity!")
            end
        end
        if Toggles.EntityESP and Toggles.EntityESP.Value then
            local Color = Options.EntityESPColor and Options.EntityESPColor.Value or Color3.fromRGB(255, 165, 0)
            for _, A in ipairs(Args) do
                if typeof(A) == "Instance" and (A:IsA("Model") or A:IsA("BasePart")) and A.Parent == Services.Workspace then
                    local Target = A
                    pcall(function()
                        Abysall.ESPLibrary:AddESP({ Object = Target, Text = EntName or "Entity", Color = Color })
                        Target.Destroying:Once(function()
                            if Abysall then Abysall.ESPLibrary:RemoveESP(Target) end
                        end)
                    end)
                end
            end
        end
    end))
    Library:Notify("Entity dinleyici baglandi.")
end
Toggles.EntityAlerts:OnChanged(function(Value)
    if Value then HookEntities() end
end)

-- // Visuals: Player ESP //
Groupboxes.Visuals_ESP = Tabs.Visuals:AddLeftGroupbox("Player ESP")

Groupboxes.Visuals_ESP:AddToggle("PlayerESP", {
    Text = "Player ESP", Default = false,
})
Toggles.PlayerESP:AddColorPicker("PlayerESPColor", {
    Text = "ESP Rengi", Default = Color3.fromRGB(255, 0, 0), Transparency = 0,
})
Groupboxes.Visuals_ESP:AddToggle("ESPTeamCheck", {
    Text = "Team Check", Default = true,
})
Groupboxes.Visuals_ESP:AddToggle("ESPShowHealth", {
    Text = "Show Health", Default = true,
})

Groupboxes.Visuals_Entity = Tabs.Visuals:AddRightGroupbox("Entity ESP")
Groupboxes.Visuals_Entity:AddToggle("EntityESP", {
    Text = "Entity ESP", Default = false,
    Tooltip = "Event'ten gelen entity modellerini isaretler (A-60, A-120...).",
})
Toggles.EntityESP:AddColorPicker("EntityESPColor", {
    Text = "ESP Rengi", Default = Color3.fromRGB(255, 165, 0), Transparency = 0,
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

local HealthConns = {}
local function TrackHealth(Player, Char)
    local Old = HealthConns[Char]
    if Old then pcall(function() Old:Disconnect() end) HealthConns[Char] = nil end
    if not (Toggles.ESPShowHealth and Toggles.ESPShowHealth.Value) then
        Abysall.ESPLibrary:UpdateObjectText(Char, Player.Name)
        return
    end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    if not Hum then return end
    local function Refresh()
        if Hum.Parent then
            Abysall.ESPLibrary:UpdateObjectText(Char, Player.Name .. " [" .. math.floor(Hum.Health + 0.5) .. "]")
        end
    end
    Refresh()
    local Conn = Hum.HealthChanged:Connect(Refresh)
    HealthConns[Char] = Conn
    TrackConn(Conn)
    Char.Destroying:Once(function()
        local C = HealthConns[Char]
        if C then pcall(function() C:Disconnect() end) HealthConns[Char] = nil end
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
        if Player.Character then
            Abysall.ESPLibrary:UpdateObjectColor(Player.Character, Value)
        end
    end
end)
Toggles.ESPShowHealth:OnChanged(function()
    for _, Player in pairs(Services.Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character and Toggles.PlayerESP.Value and ShouldESP(Player) then
            TrackHealth(Player, Player.Character)
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
    Text = "WalkSpeed", Min = 16, Max = 200, Default = 16, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("WalkSpeedOn", { Text = "Speed", Default = false })
Groupboxes.Misc_Move:AddToggle("InfiniteJump", {
    Text = "Infinite Jump", Default = false,
})
Groupboxes.Misc_Move:AddDivider()
Groupboxes.Misc_Move:AddToggle("Fly", {
    Text = "Fly", Default = false,
})
Toggles.Fly:AddKeyPicker("FlyKey", {
    Text = "Fly", Default = "F", Mode = "Toggle", SyncToggleState = true,
})
Groupboxes.Misc_Move:AddSlider("FlySpeed", {
    Text = "Fly Speed", Min = 0, Max = 200, Default = 50, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("Noclip", {
    Text = "Noclip", Default = false,
})
Toggles.Noclip:AddKeyPicker("NoclipKey", {
    Text = "Noclip", Default = "N", Mode = "Toggle", SyncToggleState = true,
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
    if Toggles.Fly and Toggles.Fly.Value and R then
        FlyBody.Parent = R
        FlyBody.Velocity = FlyDir() * ((Options.FlySpeed and Options.FlySpeed.Value) or 50)
    elseif FlyBody.Parent then
        FlyBody.Velocity = Vector3.zero
        FlyBody.Parent = nil
    end
end))

TrackConn(Services.RunService.Stepped:Connect(function()
    if Toggles.Noclip and Toggles.Noclip.Value and LocalPlayer.Character then
        for _, P in ipairs(LocalPlayer.Character:GetDescendants()) do
            if P:IsA("BasePart") and P.CanCollide then
                P.CanCollide = false
            end
        end
    end
end))

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
Abysall.Interface.ApplyAddons(Window, "cheapdoors")
Library:Notify("Cheap Doors destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")
