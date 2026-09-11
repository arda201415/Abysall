-- Abysall | Murder Duels Standalone (Doors / Loader bağımsız)
-- Kullanim (Doors loader'ini CALISTIRMA, bunu direkt execute et):
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/Games/MurderDuels/Standalone.luau"))()
-- Tuslar: F1 = ESP ac/kapa, F2 = Tracer ac/kapa, Basili SagClick = Aimbot, F3 = Speed ac/kapa

if getgenv and getgenv().MD_Standalone_Loaded then return end
if getgenv then getgenv().MD_Standalone_Loaded = true end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end)

getgenv().MD_Config = getgenv().MD_Config or {
    ESP = true,
    Tracers = false,
    Aimbot = true,
    TeamCheck = true,
    WallCheck = false,
    AimPart = "Head", -- "Head" veya "HumanoidRootPart"
    FOV = 200,
    Speed = false,
    SpeedValue = 22,
}

local Config = getgenv().MD_Config
local Drawings = {} -- [Player] = {Box, Name, Line}

local function IsEnemy(Player)
    if Player == LocalPlayer then return false end
    if not Player.Character then return false end
    local Hum = Player.Character:FindFirstChildOfClass("Humanoid")
    if not Hum or Hum.Health <= 0 then return false end
    if Config.TeamCheck and LocalPlayer.Team ~= nil and Player.Team ~= nil then
        if Player.Team == LocalPlayer.Team then return false end
    end
    return true
end

local function IsVisible(Part)
    if not Config.WallCheck then return true end
    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    local Res = Workspace:Raycast(Camera.CFrame.Position, (Part.Position - Camera.CFrame.Position), Params)
    if not Res then return true end
    return Res.Instance:IsDescendantOf(Part.Parent)
end

local function GetMouse()
    local L = UserInputService:GetMouseLocation()
    return Vector2.new(L.X, L.Y)
end

local function GetTarget()
    local Best, BestDist = nil, Config.FOV
    local Mouse = GetMouse()
    for _, P in pairs(Players:GetPlayers()) do
        if IsEnemy(P) then
            local Part = P.Character and P.Character:FindFirstChild(Config.AimPart)
            if Part then
                local Pos, On = Camera:WorldToViewportPoint(Part.Position)
                if On and IsVisible(Part) then
                    local D = (Vector2.new(Pos.X, Pos.Y) - Mouse).Magnitude
                    if D < BestDist then Best, BestDist = Part, D end
                end
            end
        end
    end
    return Best
end

local function ClearDraw(Player)
    local D = Drawings[Player]
    if D then
        pcall(function() D.Box:Remove() end)
        pcall(function() D.Name:Remove() end)
        pcall(function() D.Line:Remove() end)
        Drawings[Player] = nil
    end
end

local function GetDraw(Player)
    if Drawings[Player] then return Drawings[Player] end
    if not Drawing then return nil end
    local Box = Drawing.new("Square")
    Box.Thickness = 1
    Box.Filled = false
    Box.Color = Color3.fromRGB(255, 0, 0)
    local Name = Drawing.new("Text")
    Name.Size = 13
    Name.Center = true
    Name.Outline = true
    Name.Color = Color3.fromRGB(255, 255, 255)
    local Line = Drawing.new("Line")
    Line.Thickness = 1
    Line.Color = Color3.fromRGB(255, 0, 0)
    Drawings[Player] = { Box = Box, Name = Name, Line = Line }
    return Drawings[Player]
end

Players.PlayerRemoving:Connect(ClearDraw)

-- Aimbot: sag click basiliyken
RunService.RenderStepped:Connect(function()
    -- Speed (Doors'tan bagimsiz, sadece WalkSpeed)
    if Config.Speed and LocalPlayer.Character then
        local H = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if H then H.WalkSpeed = Config.SpeedValue end
    end

    if Config.Aimbot and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local T = GetTarget()
        if T then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, T.Position)
        end
    end

    -- ESP
    if not Drawing then return end
    local Mouse = GetMouse()
    local ScreenSize = Camera.ViewportSize
    for _, P in pairs(Players:GetPlayers()) do
        if P ~= LocalPlayer and IsEnemy(P) and Config.ESP then
            local Char = P.Character
            local Root = Char and Char:FindFirstChild("HumanoidRootPart")
            local Head = Char and Char:FindFirstChild("Head")
            if Root and Head then
                local RootPos, On1 = Camera:WorldToViewportPoint(Root.Position)
                local HeadPos, On2 = Camera:WorldToViewportPoint(Head.Position + Vector3.new(0, 0.5, 0))
                local LegPos, _ = Camera:WorldToViewportPoint(Root.Position - Vector3.new(0, 3, 0))
                if On1 and On2 then
                    local D = GetDraw(P)
                    if D then
                        local H = math.abs(HeadPos.Y - LegPos.Y)
                        local W = H / 2
                        D.Box.Size = Vector2.new(W, H)
                        D.Box.Position = Vector2.new(RootPos.X - W / 2, HeadPos.Y)
                        D.Box.Visible = true
                        local Dist = math.floor((Camera.CFrame.Position - Root.Position).Magnitude)
                        D.Name.Text = P.Name .. " [" .. Dist .. "]"
                        D.Name.Position = Vector2.new(RootPos.X, HeadPos.Y - 15)
                        D.Name.Visible = true
                        if Config.Tracers then
                            D.Line.From = Vector2.new(ScreenSize.X / 2, ScreenSize.Y)
                            D.Line.To = Vector2.new(RootPos.X, RootPos.Y)
                            D.Line.Visible = true
                        else
                            D.Line.Visible = false
                        end
                    end
                else
                    local D = Drawings[P]
                    if D then D.Box.Visible = false D.Name.Visible = false D.Line.Visible = false end
                end
            end
        else
            local D = Drawings[P]
            if D then D.Box.Visible = false D.Name.Visible = false D.Line.Visible = false end
        end
    end
    _ = Mouse
end)

UserInputService.InputBegan:Connect(function(Input, GPE)
    if GPE then return end
    if Input.KeyCode == Enum.KeyCode.F1 then
        Config.ESP = not Config.ESP
        warn("[MD] ESP: " .. tostring(Config.ESP))
    elseif Input.KeyCode == Enum.KeyCode.F2 then
        Config.Tracers = not Config.Tracers
        warn("[MD] Tracer: " .. tostring(Config.Tracers))
    elseif Input.KeyCode == Enum.KeyCode.F3 then
        Config.Speed = not Config.Speed
        if not Config.Speed and LocalPlayer.Character then
            local H = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if H then H.WalkSpeed = 16 end
        end
        warn("[MD] Speed: " .. tostring(Config.Speed))
    end
end)

warn("[MD Standalone] yuklendi. F1=ESP F2=Tracer F3=Speed | Aimbot=Basili SagClick")
