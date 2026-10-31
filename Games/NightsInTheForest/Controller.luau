-- Readable reconstruction; the obfuscated source is never executed.
return function(Dependencies)
    local Services, Player = Dependencies.Services, Dependencies.Player
    local World, Input = Services.Workspace, Services.UserInputService
    local Catalog, ESP = Dependencies.Catalog, Dependencies.ESP
    local Clock = Dependencies.Clock or os.clock
    local NewInstance = Dependencies.NewInstance or Instance.new
    local Self = { Active = true, Enabled = {}, Candidates = {}, Trees = {}, Marked = {}, Connections = {} }
    local BlockedTrees = setmetatable({}, { __mode = "k" })
    local LastESP, LastAim, NextTree = 0, 0, 0
    local Tree, TreeDeadline, NextClick, TreeRoot
    local FlyRoot, FlyHumanoid, OldAutoRotate, Velocity, Gyro

    local function InWorld(Object)
        return Object and Object.Parent ~= nil and Object:IsDescendantOf(World)
    end
    local function IsPlayerObject(Object)
        for _, Other in ipairs(Services.Players:GetPlayers()) do
            local Character = Other.Character
            if Character and (Object == Character or Object:IsDescendantOf(Character)) then return true end
        end
        return false
    end
    local function Rig()
        local Character = Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        if not Character or not InWorld(Character) or not Root or Root.Parent ~= Character or not Humanoid or Humanoid.Health <= 0 then return end
        return Character, Root, Humanoid
    end
    local function Part(Object)
        if Object:IsA("BasePart") then return Object end
        if Object:IsA("Model") then
            return Object:FindFirstChild("HumanoidRootPart") or Object.PrimaryPart
                or Object:FindFirstChildWhichIsA("BasePart", true)
        end
    end
    local function Status(Text)
        if Dependencies.Status then Dependencies.Status(Text) end
    end
    local function ForgetESP(Object)
        if not Self.Marked[Object] then return end
        Self.Marked[Object] = nil
        ESP:RemoveESP(Object)
    end
    local function RefreshObject(Object)
        local Kind
        if InWorld(Object) and not IsPlayerObject(Object) then
            local Anchor = Part(Object)
            if Catalog.NPCSet[Object.Name] and Object:IsA("Model") then
                local Human = Object:FindFirstChildOfClass("Humanoid")
                if Self.Enabled.NPCESP and Object:FindFirstChild("HumanoidRootPart") and (not Human or Human.Health > 0) then Kind = "NPC" end
            elseif Self.Enabled.ItemESP and Catalog.ItemSet[Object.Name] and Anchor
                and Anchor.Position.Magnitude >= Catalog.IgnoreRadius
                and not Object:FindFirstChildOfClass("Humanoid") then
                local Parent = Object.Parent
                if not (Parent and Catalog.ItemSet[Parent.Name] and Parent:IsA("Model")) then Kind = "Item" end
            end
        end
        if Kind == Self.Marked[Object] then return end
        ForgetESP(Object)
        if Kind then
            ESP:AddESP({ Object = Object, Text = Object.Name, Color = Color3.fromRGB(255, 85, 0) })
            Self.Marked[Object] = Kind
        end
    end
    local function Index(Object)
        if (Object:IsA("Model") or Object:IsA("BasePart")) and (Catalog.ItemSet[Object.Name] or Catalog.NPCSet[Object.Name]) then
            Self.Candidates[Object] = true
            RefreshObject(Object)
        end
        if Object:IsA("BasePart") and Object.Name == "Trunk" and Object.Parent and Object.Parent.Name == "Small Tree" then
            Self.Trees[Object] = true
        end
    end
    local function Connect(Signal, Callback)
        table.insert(Self.Connections, Signal:Connect(function(...)
            if Self.Active then Callback(...) end
        end))
    end
    function Self:StopFly()
        if Velocity then Velocity:Destroy(); Velocity = nil end
        if Gyro then Gyro:Destroy(); Gyro = nil end
        if FlyHumanoid then pcall(function() FlyHumanoid.AutoRotate = OldAutoRotate end) end
        FlyRoot, FlyHumanoid, OldAutoRotate = nil, nil, nil
    end
    function Self:Set(Feature, Value)
        if not self.Active then return end
        Value = Value == true
        if self.Enabled[Feature] == Value then return end
        self.Enabled[Feature] = Value
        if Feature == "Fly" and not Value then self:StopFly() end
        if Feature == "AutoTree" then
            Tree, TreeRoot, NextTree = nil, nil, 0
            if Value then table.clear(BlockedTrees) end
            Status(Value and "Equip an axe; looking for a small tree." or "Tree farm is off.")
        end
        if Feature == "Aimbot" and not Value and Dependencies.DrawAim then Dependencies.DrawAim(false) end
        if Feature == "ItemESP" or Feature == "NPCESP" then
            for Object in pairs(self.Candidates) do RefreshObject(Object) end
        end
        if Dependencies.Changed then Dependencies.Changed(Feature, Value) end
    end
    function Self:Teleport(Frame)
        local Character, Root = Rig()
        if not Character then return false, "Your character is not ready." end
        if Root.Anchored then return false, "Your character is anchored." end
        self:Set("AutoTree", false)
        Root.AssemblyLinearVelocity = Vector3.zero
        Character:PivotTo(Frame)
        return true
    end
    function Self:TeleportItem(Name)
        if not Catalog.ItemSet[Name] then return false, "Select an item from the list." end
        local _, Root = Rig()
        if not Root then return false, "Your character is not ready." end
        local Best, Distance
        for Object in pairs(self.Candidates) do
            if InWorld(Object) and Object.Name == Name and not IsPlayerObject(Object) then
                local Anchor = Part(Object)
                if Anchor and Anchor.Position.Magnitude >= Catalog.IgnoreRadius then
                    local Delta = (Anchor.Position - Root.Position).Magnitude
                    if not Distance or Delta < Distance then Best, Distance = Object, Delta end
                end
            end
        end
        if not Best then return false, Name .. " is not loaded outside the camp radius." end
        local Ok, Frame = pcall(function() return Best:GetPivot() end)
        if not Ok then return false, "The selected item is no longer available." end
        return self:Teleport(Frame + Vector3.new(0, 5, 0))
    end
    function Self:FlyStep()
        if not self.Enabled.Fly then self:StopFly(); return end
        local _, Root, Human = Rig()
        local Camera = World.CurrentCamera
        if not Root or Root.Anchored or not Camera then self:StopFly(); return end
        if FlyRoot ~= Root then
            self:StopFly()
            FlyRoot, FlyHumanoid, OldAutoRotate = Root, Human, Human.AutoRotate
            Human.AutoRotate = false
            Velocity, Gyro = NewInstance("BodyVelocity"), NewInstance("BodyGyro")
            Velocity.Name, Gyro.Name = "Abysall99FlyVelocity", "Abysall99FlyGyro"
            Velocity.MaxForce, Gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9), Vector3.new(9e9, 9e9, 9e9)
            Gyro.P = 90000
            Velocity.Parent, Gyro.Parent = Root, Root
        end
        local Move = Vector3.zero
        local Frame = Camera.CFrame
        if not Input:GetFocusedTextBox() then
            if Input:IsKeyDown(Enum.KeyCode.W) then Move += Frame.LookVector end
            if Input:IsKeyDown(Enum.KeyCode.S) then Move -= Frame.LookVector end
            if Input:IsKeyDown(Enum.KeyCode.A) then Move -= Frame.RightVector end
            if Input:IsKeyDown(Enum.KeyCode.D) then Move += Frame.RightVector end
            if Input:IsKeyDown(Enum.KeyCode.Space) then Move += Frame.UpVector end
            if Input:IsKeyDown(Enum.KeyCode.LeftShift) then Move -= Frame.UpVector end
        end
        Velocity.Velocity = Move.Magnitude > 0 and Move.Unit * Catalog.FlySpeed or Vector3.zero
        Gyro.CFrame = Frame
    end
    function Self:FarmStep(Now)
        if not self.Enabled.AutoTree then return end
        if self.Enabled.Fly then Tree = nil; Status("Tree farm paused while flying."); return end
        local Character, Root = Rig()
        if not Root or Root.Anchored then Tree = nil; Status("Waiting for your character."); return end
        if TreeRoot ~= Root then Tree, TreeRoot = nil, Root end
        if Tree and (not InWorld(Tree) or not Tree.Parent or Tree.Parent.Name ~= "Small Tree") then Tree = nil; NextTree = Now + 0.3 end
        if Tree and Now >= TreeDeadline then
            BlockedTrees[Tree] = true
            Tree, NextTree = nil, Now + 0.3
        end
        if not Tree then
            if Now < NextTree then return end
            local Distance
            for Trunk in pairs(self.Trees) do
                if InWorld(Trunk) and Trunk.Parent.Name == "Small Tree" and not IsPlayerObject(Trunk)
                    and Trunk.Position.Magnitude > Catalog.IgnoreRadius and not BlockedTrees[Trunk] then
                    local Delta = (Trunk.Position - Root.Position).Magnitude
                    if not Distance or Delta < Distance then Tree, Distance = Trunk, Delta end
                end
            end
            if not Tree then NextTree = Now + 1.5; Status("No eligible small tree is loaded."); return end
            Root.AssemblyLinearVelocity = Vector3.zero
            Character:PivotTo(Tree.CFrame + Vector3.new(0, 3, 0))
            TreeDeadline, NextClick = Now + Catalog.TreeTimeout, Now + Catalog.ClickInterval
            Status("Farming a small tree; equip an axe.")
        end
        if Now >= NextClick then
            local Ok, Error = Dependencies.Click()
            if Ok == false then error(Error or "Mouse input is unavailable.") end
            NextClick = Now + Catalog.ClickInterval
        end
    end
    function Self:AimStep(Now)
        if not self.Enabled.Aimbot or Input:GetFocusedTextBox()
            or not Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            if Dependencies.DrawAim then Dependencies.DrawAim(false) end
            return
        end
        if Now - LastAim < Catalog.AimInterval then return end
        LastAim = Now
        local Camera = World.CurrentCamera
        if not Camera then
            if Dependencies.DrawAim then Dependencies.DrawAim(false) end
            return
        end
        local Mouse = Input:GetMouseLocation()
        local Inset = Services.GuiService:GetGuiInset()
        local Target, Score
        for Object in pairs(self.Candidates) do
            if Catalog.NPCSet[Object.Name] and Object:IsA("Model") and InWorld(Object) and not IsPlayerObject(Object) then
                local Head = Object:FindFirstChild("Head")
                local Human = Object:FindFirstChildOfClass("Humanoid")
                if Head and Head:IsA("BasePart") and (not Human or Human.Health > 0) then
                    local Position, OnScreen = Camera:WorldToViewportPoint(Head.Position)
                    if OnScreen and Position.Z > 0 then
                        local Delta = (Vector2.new(Position.X, Position.Y) + Inset - Mouse).Magnitude
                        if Delta <= Catalog.AimRadius and (not Score or Delta < Score) then Target, Score = Head, Delta end
                    end
                end
            end
        end
        if Target then Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, Target.Position), Catalog.AimSmoothing) end
        if Dependencies.DrawAim then Dependencies.DrawAim(Target ~= nil, Mouse, Catalog.AimRadius) end
    end
    local function Safely(Feature, Callback, ...)
        local Ok, Error = pcall(Callback, Self, ...)
        if not Ok then
            Self:Set(Feature, false)
            if Dependencies.Error then Dependencies.Error(Feature, tostring(Error)) end
        end
    end
    function Self:Destroy()
        if not self.Active then return end
        self.Active = false
        for _, Connection in ipairs(self.Connections) do Connection:Disconnect() end
        self:StopFly()
        for Object in pairs(self.Marked) do ForgetESP(Object) end
        if Dependencies.DrawAim then Dependencies.DrawAim(false) end
        table.clear(self.Candidates); table.clear(self.Trees); table.clear(self.Connections)
    end
    Connect(World.DescendantAdded, Index)
    Connect(World.DescendantRemoving, function(Object)
        Self.Candidates[Object], Self.Trees[Object] = nil, nil
        ForgetESP(Object)
    end)
    Connect(Services.RunService.Heartbeat, function()
        local Now = Clock()
        Safely("Fly", Self.FlyStep)
        Safely("AutoTree", Self.FarmStep, Now)
        if Now - LastESP >= 0.5 then
            LastESP = Now
            for Object in pairs(Self.Candidates) do
                if not InWorld(Object) then Self.Candidates[Object] = nil end
                RefreshObject(Object)
            end
        end
    end)
    Connect(Services.RunService.RenderStepped, function() Safely("Aimbot", Self.AimStep, Clock()) end)
    for _, Object in ipairs(World:GetDescendants()) do Index(Object) end
    return Self
end
