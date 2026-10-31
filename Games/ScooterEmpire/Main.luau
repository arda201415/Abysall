-- Abysall Hub | Scooter Empire [BETA]
-- PlaceId: 100659280755645
-- Police / parked car removal, movement, Auto Wheelie and road-following Auto Drive.

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
    Tooltip = "Follows connected Street surfaces using visible waypoints. With Auto Wheelie, only steers (A/D).",
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
-- Acilis bir kez; ardindan 0.2sn W / 0.2sn birak dongusu.
local WheelieRun = 0
local VIM = nil
pcall(function() VIM = CloneReference(game:GetService("VirtualInputManager")) end)

-- Iki otomasyon ayni sanal tusu birbirinin elinden almamali.
local InputRequests = { Wheelie = {}, Drive = {} }
local InputHeld = {}
local InputUnloaded = false
local InputWarned = false

local function SyncInput(Key)
    local Down = false
    if not InputUnloaded then
        local WheelieOwnsKey = Key == Enum.KeyCode.W or Key == Enum.KeyCode.S
        if ToggleOn("AutoWheelie") and WheelieOwnsKey then
            Down = InputRequests.Wheelie[Key] == true
        else
            Down = (ToggleOn("AutoWheelie") and InputRequests.Wheelie[Key] == true)
                or (ToggleOn("AutoDrive") and InputRequests.Drive[Key] == true)
        end
    end
    if (InputHeld[Key] == true) == Down then return end
    if not VIM then return end
    local Ok, Err = pcall(function() VIM:SendKeyEvent(Down, Key, false, game) end)
    if Ok then
        InputHeld[Key] = Down
    elseif not InputWarned then
        InputWarned = true
        warn("[Abysall-Input] " .. tostring(Err))
        Library:Notify("Virtual key input failed. See F9 [Abysall-Input].")
    end
end

local function RequestInput(Owner, Down, Key)
    InputRequests[Owner][Key] = Down
    SyncInput(Key)
end

local function WheelieKey(Down, Key)
    RequestInput("Wheelie", Down, Key)
end

local function WheelieReleaseAll()
    WheelieKey(false, Enum.KeyCode.W)
    WheelieKey(false, Enum.KeyCode.LeftControl)
    WheelieKey(false, Enum.KeyCode.RightControl)
end

local function WheelieActive(RunId)
    return not InputUnloaded and RunId == WheelieRun and ToggleOn("AutoWheelie")
end

local function WheelieWait(Seconds, RunId)
    local Deadline = os.clock() + Seconds
    while os.clock() < Deadline do
        if not WheelieActive(RunId) then return false end
        task.wait(math.max(0, math.min(0.03, Deadline - os.clock())))
    end
    return WheelieActive(RunId)
end

local function WheelieHold(Key, Seconds, RunId)
    if not WheelieActive(RunId) then return false end
    WheelieKey(true, Key)
    local Active = WheelieWait(Seconds, RunId)
    if RunId == WheelieRun then WheelieKey(false, Key) end
    return Active
end

OnChange("AutoWheelie", function(Value)
    WheelieRun += 1
    WheelieReleaseAll()
    SyncInput(Enum.KeyCode.S)
    if not Value then return end
    if not VIM then
        Library:Notify("Auto Wheelie requires VirtualInputManager.")
        Toggles.AutoWheelie:SetValue(false)
        return
    end
    local RunId = WheelieRun
    task.spawn(function()
        local function Finish()
            -- Eski bir dongu yeni acilan dongunun tuslarini birakmasin.
            if RunId == WheelieRun then WheelieReleaseAll() end
        end
        -- Ilk acilista biraz gecikme: oyuncunun scooter'a binmesi icin sure tanir.
        if not WheelieWait(1, RunId) then return end
        -- Acilis: 3sn W (hizlan) -> 0.3sn Ctrl (tek tekerlege kalk) ->
        -- 0.5sn W -> 0.2sn birak. Bir kez yapilir.
        if not WheelieHold(Enum.KeyCode.W, 3, RunId) then return Finish() end
        WheelieKey(true, Enum.KeyCode.LeftControl)
        if not WheelieWait(0.3, RunId) then return Finish() end
        WheelieKey(false, Enum.KeyCode.LeftControl)
        if not WheelieHold(Enum.KeyCode.W, 0.5, RunId) then return Finish() end
        if not WheelieWait(0.2, RunId) then return Finish() end
        -- Denge dongusu: 0.2sn W bas -> 0.2sn birak, kapatilana kadar.
        while WheelieActive(RunId) do
            if not WheelieHold(Enum.KeyCode.W, 0.2, RunId) then break end
            if not WheelieWait(0.2, RunId) then break end
        end
        Finish()
    end)
end)

-- // Auto Drive //
-- Uzak part merkezlerine duz cizgi yerine yol ustunde kisa ara hedefler.
-- Her baglanti yol yuzeyinde kalmali ve scooter genisliginde engelsiz olmali.
local DriveId = 0
local DriveVisited = {}
local DriveBlocked = {}
local DriveTarget, DriveAim, DriveOrigin = nil, nil, nil
local DriveHL, DriveBeam, DriveAtt0, DriveAtt1, DriveTag, DriveTagLabel = nil, nil, nil, nil, nil, nil
local DriveMarker = nil
local DriveStreets = {}
local DriveStreetsAt = 0
local DriveRoads = nil

local function DriveKey(Key, Down)
    if (Key == "W" or Key == "S") and ToggleOn("AutoWheelie") then Down = false end
    RequestInput("Drive", Down, Enum.KeyCode[Key])
end

local function DriveReleaseAll()
    for _, K in ipairs({ "W", "A", "S", "D" }) do
        DriveKey(K, false)
    end
end

local function DriveClearVis()
    DriveTarget, DriveAim, DriveOrigin = nil, nil, nil
    -- pairs: yarida olusan gorsellerde nil araligi digerlerini atlamasin.
    for _, Object in pairs({ DriveHL, DriveBeam, DriveAtt0, DriveAtt1, DriveTag, DriveMarker }) do
        pcall(function() Object:Destroy() end)
    end
    DriveHL, DriveBeam, DriveAtt0, DriveAtt1, DriveTag, DriveTagLabel = nil, nil, nil, nil, nil, nil
    DriveMarker = nil
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

local function DriveFlat(V)
    return Vector3.new(V.X, 0, V.Z)
end

-- Uzun ve donuk yol parcalarinda da yuzeyin en yakin ic noktasini bulur.
local function DriveClosestPoint(Part, RP)
    if not Part or not Part.Parent then return nil end
    local CF, Size = Part.CFrame, Part.Size
    local Point = CF:PointToObjectSpace(RP)
    local HalfX = math.max(0, Size.X / 2 - 2.5)
    local HalfZ = math.max(0, Size.Z / 2 - 2.5)
    return CF:PointToWorldSpace(Vector3.new(
        math.clamp(Point.X, -HalfX, HalfX), Size.Y / 2,
        math.clamp(Point.Z, -HalfZ, HalfZ)
    ))
end

local function DriveOnTarget(Part, RP, Margin)
    if not Part or not Part.Parent then return false end
    local Point = Part.CFrame:PointToObjectSpace(RP)
    local Size = Part.Size
    Margin = Margin or 2
    -- Baska bir Street'in ustunde olmak bu parta varildigi anlamina gelmez.
    return math.abs(Point.X) <= math.max(0, Size.X / 2 - Margin)
        and math.abs(Point.Z) <= math.max(0, Size.Z / 2 - Margin)
        and Point.Y >= Size.Y / 2 - 3 and Point.Y <= Size.Y / 2 + 18
end

local function DriveCurrentStreet(RP)
    local Best, BestHeight = nil, math.huge
    for _, Street in ipairs(DriveStreets) do
        if DriveOnTarget(Street, RP, 0) then
            local Point = DriveClosestPoint(Street, RP)
            local Height = math.abs(Point.Y - RP.Y)
            if Height < BestHeight then Best, BestHeight = Street, Height end
        end
    end
    return Best
end

local function DriveRayParams(Char, Root)
    local Exclude = { Char }
    -- Sadece Street zeminini atla; Roads altindaki bariyerler hala engeldir.
    for _, Street in ipairs(DriveStreets) do table.insert(Exclude, Street) end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Seat = Hum and Hum.SeatPart
    if Seat then
        table.insert(Exclude, Seat)
        local Vehicle = Seat:FindFirstAncestorOfClass("Model")
        local Map = Services.Workspace:FindFirstChild("Map")
        if Vehicle and Vehicle ~= Map and (not Map or not Map:IsDescendantOf(Vehicle)) then
            table.insert(Exclude, Vehicle)
        end
    end
    -- Seat kullanmayan scooterlarda karaktere kaynakli parcalari da atla.
    local Ok, Parts = pcall(function() return Root:GetConnectedParts(true) end)
    if Ok then
        for _, Part in ipairs(Parts) do table.insert(Exclude, Part) end
    end
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = Exclude
    Params.IgnoreWater = true
    Params.RespectCanCollide = true
    return Params
end

local function DriveBlockedBy(From, Aim, Params)
    local Delta = Aim - From
    local Flat = DriveFlat(Delta)
    if Flat.Magnitude < 0.1 then return false end
    local Side = Vector3.new(-Flat.Z, 0, Flat.X).Unit * 2
    -- Tum mesafeyi iki yukseklikte, scooterin iki yaninda kontrol et.
    for _, Height in ipairs({ 1.5, 3.5 }) do
        for _, Offset in ipairs({ Vector3.zero, Side, -Side }) do
            local Origin = From + Vector3.new(0, Height, 0) + Offset
            if Services.Workspace:Raycast(Origin, Delta, Params) then return true end
        end
    end
    return false
end

local function DriveRoadSegment(From, Aim, Current, Target)
    if not Current then return true end -- Yola ilk giris engel kontrolunden gecer.
    local Flat = DriveFlat(Aim - From)
    local Side = Flat.Magnitude > 0.1 and Vector3.new(-Flat.Z, 0, Flat.X).Unit * 2 or Vector3.zero
    local Steps = math.max(1, math.ceil((Aim - From).Magnitude / 4))
    for I = 0, Steps do
        local Point = From:Lerp(Aim, I / Steps)
        -- Birlesen partlarin sinirinda yapay bosluk olmasin; genisligi yanlardan denetle.
        for _, Offset in ipairs({ Vector3.zero, Side, -Side }) do
            local Sample = Point + Offset
            if not DriveOnTarget(Current, Sample, 0) and not DriveOnTarget(Target, Sample, 0) then return false end
        end
    end
    return true
end

local function DriveAvoidPoint(Point)
    if Point then table.insert(DriveBlocked, { Point = Point, Until = os.clock() + 5 }) end
end

local function DrivePickTarget(RP, Head, Speed, Params)
    local Now = os.clock()
    for I = #DriveBlocked, 1, -1 do
        if DriveBlocked[I].Until <= Now then table.remove(DriveBlocked, I) end
    end
    local Current = DriveCurrentStreet(RP)
    local From = DriveClosestPoint(Current, RP) or RP - Vector3.new(0, 3, 0)
    local Ahead = math.clamp(18 + Speed * 0.4, 22, 48)
    local Candidates = {}
    for _, Street in ipairs(DriveStreets) do
        local Closest = DriveClosestPoint(Street, RP)
        if Closest and math.abs(Closest.Y - RP.Y) < 20
            and DriveFlat(Closest - RP).Magnitude < (Current and Ahead + 12 or 40) then
            local Point = Street.CFrame:PointToObjectSpace(RP)
            local Size = Street.Size
            local AlongX = Size.X >= Size.Z
            local HalfLength = math.max(0, (AlongX and Size.X or Size.Z) / 2 - 4)
            local Lane = math.min(8, (AlongX and Size.Z or Size.X) / 4)
            local Along = AlongX and Point.X or Point.Z
            for _, Sign in ipairs({ 1, -1 }) do
                local Next = math.clamp(Along + Sign * Ahead, -HalfLength, HalfLength)
                for _, Offset in ipairs({ 0, Lane, -Lane }) do
                    local LocalPoint = AlongX and Vector3.new(Next, Size.Y / 2, Offset)
                        or Vector3.new(Offset, Size.Y / 2, Next)
                    local Aim = Street.CFrame:PointToWorldSpace(LocalPoint)
                    local Delta = DriveFlat(Aim - RP)
                    local Distance = Delta.Magnitude
                    -- Yol sonunda yalnizca yana kayip hedef degistirme dongusune girme.
                    if Sign * (Next - Along) >= 8 and Distance >= 8
                        and Distance <= Ahead + 30 and DriveOnTarget(Street, Aim) then
                        local Dot = Head:Dot(Delta.Unit)
                        local Blocked = false
                        for _, Entry in ipairs(DriveBlocked) do
                            if (Entry.Point - Aim).Magnitude < 7 then Blocked = true break end
                        end
                        if Dot > -0.25 and not Blocked and DriveRoadSegment(From, Aim, Current, Street) then
                            local Score = (1 - Dot) * Ahead * 1.3 + math.abs(Distance - Ahead) * 0.4
                                + math.abs(Offset) * 0.3 + math.min(DriveVisited[Street] or 0, 5) * 4
                            table.insert(Candidates, { Street = Street, Aim = Aim, Score = Score })
                        end
                    end
                end
            end
        end
    end
    table.sort(Candidates, function(A, B) return A.Score < B.Score end)
    for _, Candidate in ipairs(Candidates) do
        if not DriveBlockedBy(From, Candidate.Aim, Params) then
            return Candidate.Street, Candidate.Aim
        end
    end
    -- Guvenli baglanti yoksa bina arkasindaki bir hedefi zorla secme.
    return nil, nil
end

local function DriveShowTarget(Target, Aim, RP, Root)
    if not Target or not Target.Parent or not Aim then DriveClearVis() return end
    if DriveMarker and not DriveMarker.Parent then DriveClearVis() end
    if DriveTarget ~= Target then DriveVisited[Target] = (DriveVisited[Target] or 0) + 1 end
    DriveTarget, DriveAim, DriveOrigin = Target, Aim, RP

    if DriveMarker and DriveMarker.Parent then
        DriveMarker.Position = Aim + Vector3.new(0, 1, 0)
        DriveHL.Adornee = Target
        if DriveAtt0.Parent ~= Root then DriveAtt0.Parent = Root end
        return
    end

    DriveMarker = Instance.new("Part")
    DriveMarker.Name = "AbysallDriveWaypoint"
    DriveMarker.Size = Vector3.new(1.5, 1.5, 1.5)
    DriveMarker.Shape = Enum.PartType.Ball
    DriveMarker.Material = Enum.Material.Neon
    DriveMarker.Color = Color3.fromRGB(0, 255, 100)
    DriveMarker.Anchored = true
    DriveMarker.CanCollide = false
    DriveMarker.CanTouch = false
    DriveMarker.CanQuery = false
    DriveMarker.Position = Aim + Vector3.new(0, 1, 0)
    DriveMarker.Parent = Services.Workspace

    DriveHL = Instance.new("Highlight")
    DriveHL.Adornee = Target
    DriveHL.FillColor = Color3.fromRGB(0, 255, 100)
    DriveHL.OutlineColor = Color3.fromRGB(255, 255, 255)
    DriveHL.FillTransparency = 0.85
    DriveHL.Parent = DriveMarker

    DriveTag = Instance.new("BillboardGui")
    DriveTag.Size = UDim2.new(0, 140, 0, 44)
    DriveTag.AlwaysOnTop = true
    DriveTag.StudsOffset = Vector3.new(0, 8, 0)
    DriveTag.Adornee = DriveMarker
    DriveTag.Parent = DriveMarker
    local TL = Instance.new("TextLabel")
    TL.Size = UDim2.new(1, 0, 1, 0)
    TL.BackgroundTransparency = 1
    TL.TextColor3 = Color3.fromRGB(0, 255, 100)
    TL.TextStrokeTransparency = 0
    TL.TextScaled = true
    TL.Font = Enum.Font.GothamBold
    TL.Text = "NEXT WAYPOINT"
    TL.Parent = DriveTag
    DriveTagLabel = TL

    if Root then
        DriveAtt0 = Instance.new("Attachment")
        DriveAtt0.Parent = Root
        DriveAtt1 = Instance.new("Attachment")
        DriveAtt1.Parent = DriveMarker
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

local function DriveReached(RP, Speed)
    if not DriveAim or not DriveOrigin then return true end
    local Delta = DriveFlat(DriveAim - RP)
    if Delta.Magnitude < math.clamp(4 + Speed * 0.08, 4, 10) then return true end
    local Along = DriveFlat(DriveAim - DriveOrigin)
    if Along.Magnitude < 0.1 then return true end
    local Past = DriveFlat(RP - DriveAim)
    local Lateral = math.abs(Along.Unit:Cross(Past).Y)
    return Along:Dot(Past) > 0 and Lateral < 8
end

local function DriveStep(State, Now)
    local Char = LocalPlayer.Character
    local Root = Char and Char:FindFirstChild("HumanoidRootPart")
    if not Root or Root.CFrame.UpVector.Y < 0 then
        DriveReleaseAll()
        DriveClearVis()
        State.Root = nil
        return
    end
    if State.Root ~= Root then
        DriveReleaseAll()
        DriveClearVis()
        State.Root, State.ProgressPos, State.ProgressAt = Root, Root.Position, Now
        State.ReverseUntil, State.NextPlan = 0, 0
    end
    DriveRefreshStreets()
    if #DriveStreets == 0 then
        DriveReleaseAll()
        DriveClearVis()
        if Now - State.WarnAt > 5 then
            State.WarnAt = Now
            Library:Notify("Auto Drive: no Street parts found in Workspace.Map.Roads.")
        end
        return
    end

    local RP = Root.Position
    local Head = DriveFlat(Root.CFrame.LookVector)
    if Head.Magnitude < 0.01 then DriveReleaseAll() return end
    Head = Head.Unit
    local Speed = DriveFlat(Root.AssemblyLinearVelocity).Magnitude
    local WheelieOn = ToggleOn("AutoWheelie")
    local Params = DriveRayParams(Char, Root)
    local Current = DriveCurrentStreet(RP)
    local From = DriveClosestPoint(Current, RP) or RP - Vector3.new(0, 3, 0)

    -- Wheelie ortada acilsa bile geri vites hemen iptal edilir.
    if WheelieOn then State.ReverseUntil = 0 end
    if Now < State.ReverseUntil then
        local Back = From - Head * 10
        if Current and DriveRoadSegment(From, Back, Current, Current)
            and not DriveBlockedBy(From, Back, Params) then
            DriveKey("W", false)
            DriveKey("S", true)
            DriveKey("A", false)
            DriveKey("D", false)
            return
        end
        State.ReverseUntil = 0
    end
    DriveKey("S", false)
    if DriveFlat(RP - State.ProgressPos).Magnitude > 4 then
        State.ProgressPos, State.ProgressAt = RP, Now
    elseif Now - State.ProgressAt > 3 then
        DriveAvoidPoint(DriveAim)
        DriveClearVis()
        DriveReleaseAll()
        State.ProgressPos, State.ProgressAt, State.NextPlan = RP, Now, 0
        if not WheelieOn then State.ReverseUntil = Now + 0.7 end
        return
    end

    local NeedsPlan = not DriveTarget or not DriveTarget.Parent or DriveReached(RP, Speed)
    if not NeedsPlan and Now >= State.CheckAt then
        State.CheckAt = Now + 0.2
        if not DriveRoadSegment(From, DriveAim, Current, DriveTarget)
            or DriveBlockedBy(From, DriveAim, Params) then
            DriveAvoidPoint(DriveAim)
            NeedsPlan = true
        end
    end
    if NeedsPlan then
        if Now < State.NextPlan then DriveReleaseAll() return end
        State.NextPlan = Now + 0.2
        local Target, Aim = DrivePickTarget(RP, Head, Speed, Params)
        DriveShowTarget(Target, Aim, RP, Root)
        if not Aim then
            DriveReleaseAll()
            if Now - State.WarnAt > 5 then
                State.WarnAt = Now
                Library:Notify("Auto Drive: no clear road waypoint. Reposition the scooter; retrying.")
            end
            return
        end
    end
    if not DriveAim then DriveReleaseAll() return end

    -- Hedef degisince eski DX/DZ kullanilmaz; yeni nokta icin yeniden hesapla.
    local Delta = DriveFlat(DriveAim - RP)
    if Delta.Magnitude < 0.1 then DriveReleaseAll() return end
    local Dir = Delta.Unit
    local Angle = math.atan2(Head:Cross(Dir).Y, Head:Dot(Dir))
    -- Donus momentini hesaba kat ve kisa direksiyon darbeleriyle salinimi azalt.
    local Error = Angle - Root.AssemblyAngularVelocity.Y * 0.2
    local Duty = math.clamp(math.abs(Error) / 0.6, 0.15, 1)
    local Steer = math.abs(Error) > 0.06 and (Now % 0.2) < 0.2 * Duty
    DriveKey("A", Steer and Error > 0)
    DriveKey("D", Steer and Error < 0)
    DriveKey("W", not WheelieOn and (math.abs(Angle) < 0.6 or (Now % 0.4) < 0.12))
    if DriveTagLabel then
        DriveTagLabel.Text = "NEXT: " .. tostring(math.floor(Delta.Magnitude)) .. " studs"
    end
end

OnChange("AutoDrive", function(Value)
    DriveId += 1
    DriveReleaseAll()
    DriveClearVis()
    if not Value then return end
    if not VIM then
        Library:Notify("Auto Drive requires VirtualInputManager.")
        Toggles.AutoDrive:SetValue(false)
        return
    end
    DriveVisited, DriveBlocked = {}, {}
    DriveStreetsAt = -math.huge
    local MyId = DriveId
    local State = { ReverseUntil = 0, NextPlan = 0, CheckAt = 0, WarnAt = -math.huge }
    task.spawn(function()
        local Ok, Err = pcall(function()
            while not InputUnloaded and MyId == DriveId and ToggleOn("AutoDrive") do
                DriveStep(State, os.clock())
                task.wait(0.05)
            end
        end)
        if MyId ~= DriveId then return end
        DriveReleaseAll()
        DriveClearVis()
        if not Ok then
            warn("[Abysall-AutoDrive] " .. tostring(Err))
            Library:Notify("Auto Drive stopped: see F9 [Abysall-AutoDrive].")
            Toggles.AutoDrive:SetValue(false)
        end
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
    InputUnloaded = true
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
