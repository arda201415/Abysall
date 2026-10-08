-- Abysall Hub | Scooter Empire [BETA]
-- PlaceId: 100659280755645
-- Disable Police (Workspace.Police + "Police" adli her sey) + hiz/noclip/fly/freecam/fullbright/nofog.

local LoadStart = tick()
if not Abysall or not Abysall.Interface then
    warn("[Abysall] ScooterEmpire direkt calistirildi: once ana Loader (README loadstring) calistir.")
    return
end
Abysall.SavePath = "ScooterEmpire"

local Library = Abysall.Interface.Library
local ThemeManager = Abysall.Interface.ThemeManager

local Toggles = Library.Toggles
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

local Connections = {}
local function TrackConn(Conn)
    table.insert(Connections, Conn)
    return Conn
end

local Window = Library:CreateWindow({
    Title = "Abysall Hub | Scooter Empire",
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
    Exploits = Window:AddTab("Exploits", "zap"),
    Misc = Window:AddTab("Misc", "house"),
}

local Groupboxes = {}

-- // Exploits: Disable Police //
Groupboxes.Exploits_Police = Tabs.Exploits:AddLeftGroupbox("Police")
Groupboxes.Exploits_Police:AddToggle("DisablePolice", {
    Text = "Disable Police",
    Default = false,
    Tooltip = "Deletes Workspace.Police and everything named 'Police' in the workspace.",
})
Groupboxes.Exploits_Police:AddToggle("DeleteParkedCars", {
    Text = "Delete Parked Cars",
    Default = false,
    Tooltip = "Deletes 'ParkedCar' models (Workspace.Map.Props.ParkedCars).",
})

-- Silinen objeleri geri almak icin saklanir (toggle kapatilinca).
local PoliceBackup = {}
local PoliceWatching = setmetatable({}, { __mode = "k" })

local function Remember(Object)
    if not Object or PoliceBackup[Object] or not Object.Parent then return end
    PoliceBackup[Object] = { Parent = Object.Parent, CFrame = Object:IsA("BasePart") and Object.CFrame or nil }
    PoliceWatching[Object] = true
end

local function RemovePoliceInstance(Object)
    if not Object or not Object.Parent then return end
    -- Kullanici karakteri veya UI icinde bir 'Police' adi varsa dokunma.
    if LocalPlayer.Character and Object:IsDescendantOf(LocalPlayer.Character) then return end
    if LocalPlayer:FindFirstChild("PlayerGui") and Object:IsDescendantOf(LocalPlayer:FindFirstChild("PlayerGui")) then return end
    Remember(Object)
    pcall(function() Object:Destroy() end)
end

local function ScanAndRemovePolice()
    local Root = Services.Workspace
    if not Root then return end

    -- 1) Workspace.Police (tum agacla birlikte)
    local PoliceFolder = Root:FindFirstChild("Police")
    if PoliceFolder then RemovePoliceInstance(PoliceFolder) end

    -- 2) Adinda 'Police' gecen her sey (case-insensitive, "police" substring dahil)
    for _, Desc in ipairs(Root:GetDescendants()) do
        if Desc.Name:lower():find("police") then
            RemovePoliceInstance(Desc)
        end
    end
end

local function RestorePolice()
    for Object, Info in pairs(PoliceBackup) do
        if Object and Object.Parent == nil and Info and Info.Parent then
            pcall(function() Object.Parent = Info.Parent end)
        end
    end
    PoliceBackup = {}
end

OnChange("DisablePolice", function(Value)
    if Value then
        ScanAndRemovePolice()
    else
        RestorePolice()
    end
end)

-- Yeni spawn eden 'Police' objelerini de yakala.
TrackConn(Services.Workspace.DescendantAdded:Connect(function(Desc)
    if ToggleOn("DisablePolice") and Desc.Name:lower():find("police") then
        RemovePoliceInstance(Desc)
    end
end))

-- // Delete Parked Cars //
-- ParkedCar modeli ParkedCars klasoru altinda spawn olur ama baska klasorlere
-- de tasinabilir; bu yuzden isim eslesmesi tum workspace icin yapilir.
local ParkedCarBackup = {}

local function RemoveParkedCar(Object)
    if not Object or not Object.Parent then return end
    if LocalPlayer.Character and Object:IsDescendantOf(LocalPlayer.Character) then return end
    if LocalPlayer:FindFirstChild("PlayerGui") and Object:IsDescendantOf(LocalPlayer:FindFirstChild("PlayerGui")) then return end
    if not ParkedCarBackup[Object] then
        ParkedCarBackup[Object] = { Parent = Object.Parent }
    end
    pcall(function() Object:Destroy() end)
end

local function ScanAndRemoveParkedCars()
    local Root = Services.Workspace
    if not Root then return end
    -- 1) Bilinen yol: Workspace.Map.Props.ParkedCars (agacla birlikte)
    local ParkedCarsFolder = Root:FindFirstChild("Map", true)
    if ParkedCarsFolder then
        local Props = ParkedCarsFolder:FindFirstChild("Props")
        if Props then
            local Cars = Props:FindFirstChild("ParkedCars")
            if Cars then
                for _, Child in ipairs(Cars:GetChildren()) do
                    if Child.Name:lower() == "parkedcar" then
                        RemoveParkedCar(Child)
                    end
                end
            end
        end
    end
    -- 2) Baska yerde spawn olursa yedek: adinda 'parkedcar' gecen modeller.
    for _, Desc in ipairs(Root:GetDescendants()) do
        if Desc.Name:lower():find("parkedcar") and (Desc:IsA("Model") or Desc:IsA("Folder")) then
            RemoveParkedCar(Desc)
        end
    end
end

local function RestoreParkedCars()
    for Object, Info in pairs(ParkedCarBackup) do
        if Object and Object.Parent == nil and Info and Info.Parent then
            pcall(function() Object.Parent = Info.Parent end)
        end
    end
    ParkedCarBackup = {}
end

OnChange("DeleteParkedCars", function(Value)
    if Value then
        ScanAndRemoveParkedCars()
    else
        RestoreParkedCars()
    end
end)

-- Yeni spawn eden ParkedCar objelerini de yakala.
TrackConn(Services.Workspace.DescendantAdded:Connect(function(Desc)
    if ToggleOn("DeleteParkedCars") and Desc.Name:lower():find("parkedcar") and (Desc:IsA("Model") or Desc:IsA("Folder")) then
        task.defer(RemoveParkedCar, Desc)
    end
end))

-- // Misc: Movement //
Groupboxes.Misc_Move = Tabs.Misc:AddLeftGroupbox("Movement")
Groupboxes.Misc_Move:AddSlider("WalkSpeedVal", {
    Text = "WalkSpeed", Min = 16, Max = 300, Default = 16, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddToggle("WalkSpeedOn", { Text = "Speed", Default = false })
Groupboxes.Misc_Move:AddDivider()
Groupboxes.Misc_Move:AddToggle("Noclip", { Text = "Noclip", Default = false })
Toggles.Noclip:AddKeyPicker("NoclipKey", {
    Text = "Noclip", Default = "N", Mode = "Toggle", SyncToggleState = true,
})
Groupboxes.Misc_Move:AddToggle("Fly", { Text = "Fly", Default = false })
Toggles.Fly:AddKeyPicker("FlyKey", {
    Text = "Fly", Default = "F", Mode = "Toggle", SyncToggleState = true,
})
Groupboxes.Misc_Move:AddSlider("FlySpeed", {
    Text = "Fly Speed", Min = 1, Max = 300, Default = 50, Rounding = 0, Compact = true,
})
Groupboxes.Misc_Move:AddDivider()
Groupboxes.Misc_Move:AddToggle("AutoWheelie", {
    Text = "Auto Wheelie",
    Default = false,
    Tooltip = "Acilis: W (3s) -> Ctrl (0.3s) -> W (0.5s) -> release (0.2s). Sonra W (0.2s) / release (0.2s) loop.",
})
Groupboxes.Misc_Move:AddToggle("AutoDrive", {
    Text = "Auto Drive",
    Default = false,
    Tooltip = "Street parcalarinda otomatik surer: hedef yesil + isinla gosterilir, engelden kacar, takilirsa geri gider.",
})
Toggles.AutoDrive:AddKeyPicker("AutoDriveKey", {
    Text = "Auto Drive", Default = "G", Mode = "Toggle", SyncToggleState = true,
})

TrackConn(Services.RunService.RenderStepped:Connect(function()
    if Toggles.WalkSpeedOn and ToggleOn("WalkSpeedOn") and LocalPlayer.Character then
        local Hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Hum then Hum.WalkSpeed = Options.WalkSpeedVal.Value end
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

-- // Auto Wheelie //
-- W (3sn) -> Ctrl tap -> W (0.5sn) -> birak (0.1sn) -> W (0.1sn) -> birak,
-- kapatilana kadar doner. VirtualInputManager ile gercek tus basiymis gibi verilir.
local WheelieRun = 0
local VIM = nil
pcall(function() VIM = CloneReference(game:GetService("VirtualInputManager")) end)

local function WheelieKey(Down, Key)
    if not VIM then return end
    pcall(function() VIM:SendKeyEvent(Down, Key, false, game) end)
end

local function WheelieReleaseAll()
    WheelieKey(false, Enum.KeyCode.W)
    WheelieKey(false, Enum.KeyCode.LeftControl)
    WheelieKey(false, Enum.KeyCode.RightControl)
end

local function WheelieHold(Key, Seconds, RunId)
    WheelieKey(true, Key)
    local Elapsed = 0
    while Elapsed < Seconds do
        if RunId ~= WheelieRun or not ToggleOn("AutoWheelie") then
            WheelieKey(false, Key)
            return false
        end
        task.wait(0.05)
        Elapsed += 0.05
    end
    WheelieKey(false, Key)
    return RunId == WheelieRun and ToggleOn("AutoWheelie")
end

local function WheelieWait(Seconds, RunId)
    local Elapsed = 0
    while Elapsed < Seconds do
        if RunId ~= WheelieRun or not ToggleOn("AutoWheelie") then return false end
        task.wait(0.05)
        Elapsed += 0.05
    end
    return RunId == WheelieRun and ToggleOn("AutoWheelie")
end

OnChange("AutoWheelie", function(Value)
    if not Value then
        WheelieRun += 1
        WheelieReleaseAll()
        return
    end
    WheelieRun += 1
    local RunId = WheelieRun
    task.spawn(function()
        -- Ilk acilista biraz gecikme: oyuncunun scooter'a binmesi icin sure tanir.
        if not WheelieWait(1, RunId) then return end
        -- Acilis: 3sn W (hizlan) -> 0.3sn Ctrl (tek tekerlege kalk) ->
        -- 0.5sn W -> 0.2sn birak. Bir kez yapilir.
        if not WheelieHold(Enum.KeyCode.W, 3, RunId) then return WheelieReleaseAll() end
        WheelieKey(true, Enum.KeyCode.LeftControl)
        if not WheelieWait(0.3, RunId) then return WheelieReleaseAll() end
        WheelieKey(false, Enum.KeyCode.LeftControl)
        if not WheelieHold(Enum.KeyCode.W, 0.5, RunId) then return WheelieReleaseAll() end
        if not WheelieWait(0.2, RunId) then return WheelieReleaseAll() end
        -- Denge dongusu: 0.2sn W bas -> 0.2sn birak, kapatilana kadar.
        while RunId == WheelieRun and ToggleOn("AutoWheelie") do
            if not WheelieHold(Enum.KeyCode.W, 0.2, RunId) then break end
            if not WheelieWait(0.2, RunId) then break end
        end
        WheelieReleaseAll()
    end)
end)

-- // Auto Drive //
-- Workspace.Map.Roads altindaki "Street" parcalarini toplar, en yakindan baslayip
-- hepsini gezer. Hedef yesil Highlight + karakterden hedefe isin (Beam) + "HEDEF: Xm"
-- etiketiyle gosterilir. W gaz, A/D direksiyon; onde engel varsa bos tarafa kacar,
-- 3sn'den uzun takilirsa 1.2sn geri vites yapar.
local DriveId = 0
local DriveVisited = {}
local DriveBlocked = {}
local DriveTarget = nil
local DriveHL, DriveBeam, DriveAtt0, DriveAtt1, DriveTag, DriveTagLabel = nil, nil, nil, nil, nil, nil
local DriveKeys = { W = false, A = false, S = false, D = false }
local DriveStreets = {}
local DriveStreetsAt = 0
local DriveRoads = nil

local function DriveKey(Key, Down)
    if DriveKeys[Key] == Down then return end
    DriveKeys[Key] = Down
    WheelieKey(Down, Enum.KeyCode[Key])
end

local function DriveReleaseAll()
    for _, K in ipairs({ "W", "A", "S", "D" }) do
        DriveKey(K, false)
    end
end

local function DriveClearVis()
    DriveTarget = nil
    for _, I in ipairs({ DriveHL, DriveBeam, DriveAtt0, DriveAtt1, DriveTag }) do
        pcall(function() if I then I:Destroy() end end)
    end
    DriveHL, DriveBeam, DriveAtt0, DriveAtt1, DriveTag, DriveTagLabel = nil, nil, nil, nil, nil, nil
end

local function DriveRefreshStreets()
    if tick() - DriveStreetsAt < 5 and #DriveStreets > 0 then return end
    DriveStreetsAt = tick()
    DriveStreets = {}
    local Map = Services.Workspace:FindFirstChild("Map")
    DriveRoads = Map and Map:FindFirstChild("Roads") or nil
    if not DriveRoads then return end
    for _, D in ipairs(DriveRoads:GetDescendants()) do
        if D:IsA("BasePart") and D.Name == "Street" then
            table.insert(DriveStreets, D)
        end
    end
end

-- Hedef secimi: duz cizgide ENGEL olan adaylari eler. Sadece "en yakin" secmek
-- 115m oteye dogrudan duvara toslamaya yol aciyordu.
local function DriveBlockedBy(RP, S)
    local DX, DZ = S.Position.X - RP.X, S.Position.Z - RP.Z
    local D = math.sqrt(DX * DX + DZ * DZ)
    if D < 1 then return false end
    local Dir = Vector3.new(DX / D, 0, DZ / D)
    local Char = LocalPlayer.Character
    local BL = {}
    if Char then table.insert(BL, Char) end
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = BL
    Params.IgnoreWater = true
    -- Hedefe kadar 3.5 yukseklikte tarama: bina/direk/arfalar engel sayilir,
    -- Street ve Roads altindaki yol parcalari sayilmaz.
    local Probe = RP + Vector3.new(0, 3.5, 0)
    local step = 6
    local d = step
    while d < D - 12 do
        local Hit = Services.Workspace:Raycast(Probe, Dir * step, Params)
        if Hit and Hit.Instance then
            local IH = Hit.Instance
            local IsRoad = IH.Name == "Street" or (DriveRoads and IH:IsDescendantOf(DriveRoads))
            if not IsRoad then return true end
        end
        Probe += Dir * step
        d += step
    end
    return false
end

local function DrivePickTarget(RootPos)
    local Best, BestD = nil, math.huge
    local Fallback, FallbackD = nil, math.huge

    local function Scan(Skip, Blocked)
        local B, BD = nil, math.huge
        for _, S in ipairs(DriveStreets) do
            if S.Parent and not Skip[S] and not Blocked[S] then
                local D = (S.Position - RootPos).Magnitude
                if D < BD then BD = D B = S end
            end
        end
        return B, BD
    end

    Best, BestD = Scan(DriveVisited, DriveBlocked)
    if not Best then
        -- Ziyaretli + engelli havuzlarini temizle, yeniden dene.
        DriveVisited = {}
        DriveBlocked = {}
        Best, BestD = Scan(DriveVisited, DriveBlocked)
    end
    if not Best then return nil end

    -- En yakin hedef duz cizgide engelliyse engelsiz olana kadar ara.
    if DriveBlockedBy(RootPos, Best) then
        for _, S in ipairs(DriveStreets) do
            if S.Parent and not DriveVisited[S] and not DriveBlocked[S] and S ~= Best then
                if not DriveBlockedBy(RootPos, S) then
                    local D = (S.Position - RootPos).Magnitude
                    if D < BestD then BestD = D Best = S end
                else
                    local D = (S.Position - RootPos).Magnitude
                    if D < FallbackD then FallbackD = D Fallback = S end
                end
            end
        end
        -- Hicbiri engelsiz degilse: engelsiz olmayan en yakini kullan ve engel
        -- listesine at ki bir sonraki denemede tekrar denenmesin.
        if Best == nil or DriveBlockedBy(RootPos, Best) then
            DriveBlocked[Fallback or DrivePickTarget.LastBlocked] = true
        end
        Best = Best or Fallback
    end

    if Best and DriveBlockedBy(RootPos, Best) then
        DriveBlocked[Best] = true
    end

    return Best
end

local function DriveShowTarget(Target)
    DriveClearVis()
    if not Target or not Target.Parent then return end
    DriveTarget = Target

    DriveHL = Instance.new("Highlight")
    DriveHL.Adornee = Target
    DriveHL.FillColor = Color3.fromRGB(0, 255, 100)
    DriveHL.OutlineColor = Color3.fromRGB(255, 255, 255)
    DriveHL.FillTransparency = 0.6
    DriveHL.Parent = Target

    DriveTag = Instance.new("BillboardGui")
    DriveTag.Size = UDim2.new(0, 140, 0, 44)
    DriveTag.AlwaysOnTop = true
    DriveTag.StudsOffset = Vector3.new(0, 8, 0)
    DriveTag.Adornee = Target
    DriveTag.Parent = Target
    local TL = Instance.new("TextLabel")
    TL.Size = UDim2.new(1, 0, 1, 0)
    TL.BackgroundTransparency = 1
    TL.TextColor3 = Color3.fromRGB(0, 255, 100)
    TL.TextStrokeTransparency = 0
    TL.TextScaled = true
    TL.Font = Enum.Font.GothamBold
    TL.Text = "HEDEF"
    TL.Parent = DriveTag
    DriveTagLabel = TL

    local Char = LocalPlayer.Character
    local Root = Char and Char:FindFirstChild("HumanoidRootPart")
    if Root then
        DriveAtt0 = Instance.new("Attachment")
        DriveAtt0.Parent = Root
        DriveAtt1 = Instance.new("Attachment")
        DriveAtt1.Parent = Target
        DriveBeam = Instance.new("Beam")
        DriveBeam.Attachment0 = DriveAtt0
        DriveBeam.Attachment1 = DriveAtt1
        DriveBeam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 100))
        DriveBeam.Width0 = 1
        DriveBeam.Width1 = 1
        DriveBeam.FaceCamera = true
        DriveBeam.Parent = Root
    end
end

local function DriveRay(Origin, Dir, Len, Blacklist)
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = Blacklist
    Params.IgnoreWater = true
    return Services.Workspace:Raycast(Origin, Dir * Len, Params)
end

OnChange("AutoDrive", function(Value)
    if not Value then
        DriveId = DriveId + 1
        DriveReleaseAll()
        DriveClearVis()
        return
    end
    -- AutoWheelie ile birlikte calisabilir: Wheelie aciksa gaz (W) ve geri (S)
    -- Wheelie'ye birakilir, Auto Drive sadece direksiyon (A/D) yapar.
DriveId = DriveId + 1
    local MyId = DriveId
    task.spawn(function()
        local NoStreetWarn = 0
        local StuckT = 0
        local ReverseT = 0
        local UprightT = 0
        while MyId == DriveId and ToggleOn("AutoDrive") do
            local Char = LocalPlayer.Character
            local Root = Char and Char:FindFirstChild("HumanoidRootPart")
            if not Root then
                DriveReleaseAll()
                task.wait(0.5)
            else
                DriveRefreshStreets()
                if #DriveStreets == 0 then
                    if tick() - NoStreetWarn > 5 then
                        NoStreetWarn = tick()
                        Library:Notify("Auto Drive: Street bulunamadi (Map.Roads yok).")
                    end
                    DriveReleaseAll()
                    task.wait(1)
                else
                    local RP = Root.Position
                    local WheelieOn = Toggles.AutoWheelie and ToggleOn("AutoWheelie") or false

                    -- Devrilme kontrolu: arac yan yatmis / havada ise once duzelt.
                    local UpY = Root.CFrame.Up.Y
                    if UpY < 0.45 then
                        UprightT = UprightT + 0.1
                        if UprightT > 0.8 then
                            UprightT = 0
                            -- Space ile ziplama genelde araci dogru kaldirir.
                            pcall(function() VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game) end)
                            task.wait(0.15)
                            pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
                        end
                    else
                        UprightT = 0
                    end

                    -- Geri viste miyiz?
                    if ReverseT > 0 then
                        ReverseT = ReverseT - 0.1
                        task.wait(0.1)
                    else
                        if not DriveTarget or not DriveTarget.Parent then
                            DriveShowTarget(DrivePickTarget(RP))
                        end
                        if DriveTarget and (not DriveBeam or not DriveBeam.Parent) then
                            local T = DriveTarget
                            DriveShowTarget(T)
                        end
                        local T = DriveTarget
                        if T and T.Parent then
                            local HX, HZ = Root.CFrame.LookVector.X, Root.CFrame.LookVector.Z
                            local Head = Vector3.new(HX, 0, HZ)
                            if Head.Magnitude < 0.01 then Head = Vector3.new(0, 0, -1) else Head = Head.Unit end
                            local DX, DZ = T.Position.X - RP.X, T.Position.Z - RP.Z
                            local Dist = math.sqrt(DX * DX + DZ * DZ)
                            if DriveTagLabel then
                                DriveTagLabel.Text = "HEDEF: " .. tostring(math.floor(Dist)) .. "m"
                            end

                            -- Varis: 80 stud icine girince ziyaret edildi say, siradakine gec.
                            if Dist < 80 then
                                DriveVisited[T] = true
                                DriveShowTarget(DrivePickTarget(RP))
                                T = DriveTarget
                            end

                            if T and T.Parent then
                                local DirX, DirZ = DX / math.max(Dist, 0.01), DZ / math.max(Dist, 0.01)
                                local CrossY = Head.Z * DirX - Head.X * DirZ
                                local Dot = Head.X * DirX + Head.Z * DirZ
                                local Ang = math.atan2(CrossY, Dot)

                                -- Engel taramasi: on + sol/sag 30 derece.
                                local BL = { Char }
                                local Hum = Char:FindFirstChildOfClass("Humanoid")
                                if Hum and Hum.SeatPart then
                                    table.insert(BL, Hum.SeatPart.Parent or Hum.SeatPart)
                                end
                                local Up3 = RP + Vector3.new(0, 3, 0)
                                local Hit = DriveRay(Up3, Head, 45, BL)
                                local Steer = nil
                                if Hit and Hit.Instance then
                                    local IH = Hit.Instance
                                    local IsRoad = IH.Name == "Street" or (DriveRoads and IH:IsDescendantOf(DriveRoads))
                                    if not IsRoad then
                                        local function SideDist(Off)
                                            local C, S = math.cos(Off), math.sin(Off)
                                            local SX = Head.X * C + Head.Z * S
                                            local SZ = -Head.X * S + Head.Z * C
                                            local H2 = DriveRay(Up3, Vector3.new(SX, 0, SZ), 45, BL)
                                            if H2 and H2.Position then
                                                local OX, OZ = H2.Position.X - RP.X, H2.Position.Z - RP.Z
                                                return math.sqrt(OX * OX + OZ * OZ)
                                            end
                                            return 45
                                        end
                                        local L = SideDist(0.5)
                                        local R = SideDist(-0.5)
                                        Steer = (L >= R) and "A" or "D"
                                    end
                                end

                                -- Takilma: hiz 3'un altinda 3sn kalirsa 1.2sn geri git.
                                local Speed = Root.AssemblyLinearVelocity.Magnitude
                                if Speed < 3 then StuckT = StuckT + 0.1 else StuckT = 0 end
                                if StuckT > 3 then
                                    StuckT = 0
                                    -- Bu hedefe bir daha deneme: engelli listesine at, yenisine gec.
                                    if DriveTarget then
                                        DriveBlocked[DriveTarget] = true
                                    end
                                    DriveVisited = {}
                                    DriveShowTarget(DrivePickTarget(RP))
                                    if WheelieOn then
                                        -- Wheelie gazı yönetiyor: sadece direksiyonu bırak, geri vitese girme.
                                        DriveKey("A", false)
                                        DriveKey("D", false)
                                    else
                                        DriveKey("W", false)
                                        DriveKey("A", false)
                                        DriveKey("D", false)
                                        DriveKey("S", true)
                                        ReverseT = 1.2
                                    end
                                else
                                    if not WheelieOn then
                                        DriveKey("W", true)
                                        DriveKey("S", false)
                                    else
                                        DriveKey("W", false)
                                        DriveKey("S", false)
                                    end
                                    if Steer then
                                        DriveKey("A", Steer == "A")
                                        DriveKey("D", Steer == "D")
                                    elseif Ang < -0.15 then
                                        DriveKey("D", true)
                                        DriveKey("A", false)
                                    elseif Ang > 0.15 then
                                        DriveKey("A", true)
                                        DriveKey("D", false)
                                    else
                                        DriveKey("A", false)
                                        DriveKey("D", false)
                                    end
                                end
                            end
                        end
                        task.wait(0.1)
                    end
                end
            end
        end
        DriveReleaseAll()
        DriveClearVis()
    end)
end)

-- // Misc: World //
Groupboxes.Misc_World = Tabs.Misc:AddRightGroupbox("World")
Groupboxes.Misc_World:AddToggle("Fullbright", { Text = "Fullbright", Default = false })
Groupboxes.Misc_World:AddToggle("NoFog", { Text = "No Fog", Default = false })

local OldLight = {}
local function ApplyBright(On)
    local L = Services.Lighting
    if On then
        if OldLight.B == nil then
            OldLight = { B = L.Brightness, C = L.ClockTime, G = L.GlobalShadows, A = L.Ambient }
        end
        L.Brightness = 2
        L.ClockTime = 14
        L.GlobalShadows = false
        L.Ambient = Color3.new(1, 1, 1)
    elseif OldLight.B ~= nil then
        L.Brightness = OldLight.B
        L.ClockTime = OldLight.C
        L.GlobalShadows = OldLight.G
        L.Ambient = OldLight.A
    end
end
OnChange("Fullbright", function(V) pcall(ApplyBright, V) end)

local OldFog = nil
local function ApplyNoFog(On)
    local L = Services.Lighting
    if On then
        if OldFog == nil then OldFog = L.FogEnd end
        L.FogEnd = 100000
    elseif OldFog ~= nil then
        L.FogEnd = OldFog
    end
end
OnChange("NoFog", function(V) pcall(ApplyNoFog, V) end)

local BrightAcc = 0
TrackConn(Services.RunService.Heartbeat:Connect(function(Delta)
    BrightAcc = BrightAcc + Delta
    if BrightAcc < 2 then return end
    BrightAcc = 0
    if Toggles.Fullbright and ToggleOn("Fullbright") then
        pcall(ApplyBright, true)
    end
    if Toggles.NoFog and ToggleOn("NoFog") then
        pcall(ApplyNoFog, true)
    end
end))

Library:OnUnload(function()
    WheelieRun = WheelieRun + 1
    DriveId = DriveId + 1
    pcall(WheelieReleaseAll)
    pcall(DriveReleaseAll)
    pcall(DriveClearVis)
    for _, Conn in ipairs(Connections) do
        pcall(function() Conn:Disconnect() end)
    end
    pcall(function()
        FlyBody.Velocity = Vector3.zero
        FlyBody.Parent = nil
    end)
    pcall(ApplyBright, false)
    pcall(ApplyNoFog, false)
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
Abysall.Interface.ApplyAddons(Window, "scooterempire")
Library:Notify("Scooter Empire destegi yuklendi (" .. math.floor((tick() - LoadStart) * 100) / 100 .. "s).")