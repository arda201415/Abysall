-- Apply enabled contact protections before ESP/prompt work enters the FIFO.
-- No WaitForChild, room-entry requirement, or per-frame workspace scan here.
local Touch = { CanTouch = false }
local Rules = {
    GiggleCeiling = { Toggle = "BypassGiggle", Properties = Touch },
    GloomPile = { Toggle = "BypassGloombatEggs", Properties = Touch },
    Snare = { Toggle = "BypassSnare", Properties = Touch },
    BananaPeel = { Toggle = "BypassBanana", Properties = Touch },
    NannerPeel = { Toggle = "BypassBanana", Properties = Touch },
    Lava = { Toggle = "BypassKillbricks", Properties = Touch },
    Seek_Arm = { Toggle = "BypassSeekObstructions", Properties = Touch },
    ChandelierObstruction = { Toggle = "BypassSeekObstructions", Properties = Touch },
    SeekFloodline = { Toggle = "BypassSeekObstructions", Properties = { CanTouch = false, CanCollide = true } },
    ScaryWall = { Toggle = "BypassSeekingWall", Properties = { CanTouch = false, CanCollide = false } },
    JeffTheKiller = { Toggle = "BypassJeff", Properties = { CanTouch = false, CanCollide = false } },
    DoorFake = { Toggle = "BypassDupe", FakeDoor = true },
    FakeDoor = { Toggle = "BypassDupe", FakeDoor = true },
    SideroomSpace = { Toggle = "BypassVacuum", Collision = true },
}

return function(Context)
    local Workspace, Rooms, Player = Context.Workspace, Context.Rooms, Context.Player
    local IsOn = Context.IsOn
    local Controller = { Active = true }
    local Roots = setmetatable({}, { __mode = "k" })
    local Records = setmetatable({}, { __mode = "k" })
    local Connections, Streamed = {}, {}
    local StreamBusy, StreamPending, Scheduled = false, false, false

    function Controller:IsDupeDoor(Object)
        if not Object or not Object.Parent then return false end
        if Object.Name ~= "DoorFake" and Object.Name ~= "FakeDoor" then return false end
        -- Decorative/boarded doors reuse these names. A real Dupe door has
        -- its own physical Hidden trigger; the name alone is not sufficient.
        local Hidden = Object:FindFirstChild("Hidden")
        return Hidden ~= nil and Hidden:IsA("BasePart")
    end

    local function HasPathName(Object, Root, Name)
        local Parent = Object
        while Parent and Parent ~= Root do
            if Parent.Name == Name then return true end
            Parent = Parent.Parent
        end
        return false
    end

    local function DesiredProperties(Object)
        local Desired = {}
        local IsPart, IsPrompt = Object:IsA("BasePart"), Object:IsA("ProximityPrompt")
        local Parent = Object
        while Parent and Parent ~= Workspace do
            local Rule = Rules[Parent.Name]
            if Rule then
                Roots[Parent] = true
                if IsOn(Rule.Toggle) then
                    if Rule.FakeDoor then
                        if Controller:IsDupeDoor(Parent) then
                            if IsPart and HasPathName(Object, Parent, "Hidden") then Desired.CanTouch = false end
                            if IsPrompt and Object.Name == "UnlockPrompt"
                                and (HasPathName(Object, Parent, "Lock") or HasPathName(Object, Parent, "LockPart")) then
                                Desired.Enabled = false
                            end
                        end
                    elseif Rule.Collision then
                        if IsPart and HasPathName(Object, Parent, "Collision") then
                            Desired.CanTouch, Desired.CanCollide = false, true
                        end
                    elseif IsPart then
                        for Property, Value in pairs(Rule.Properties) do Desired[Property] = Value end
                    end
                end
            end
            Parent = Parent.Parent
        end
        return Desired
    end

    local function Restore(Object, Record)
        for _, Connection in pairs(Record.Signals) do Connection:Disconnect() end
        if Record.Ancestry then Record.Ancestry:Disconnect() end
        for Property, Value in pairs(Record.Original) do
            pcall(function() Object[Property] = Value end)
        end
        Records[Object] = nil
    end

    function Controller:Apply(Object)
        if not self.Active or not Object.Parent then return end
        if not Object:IsA("BasePart") and not Object:IsA("ProximityPrompt") then return end
        local Desired = DesiredProperties(Object)
        local Record = Records[Object]
        if not next(Desired) then
            if Record then Restore(Object, Record) end
            return
        end
        if not Record then
            Record = { Original = {}, Signals = {} }
            Records[Object] = Record
            Record.Ancestry = Object.AncestryChanged:Connect(function()
                if not self.Active then return end
                if Object:IsDescendantOf(Workspace) then self:Apply(Object) else Restore(Object, Record) end
            end)
        end
        for Property, Original in pairs(Record.Original) do
            if Desired[Property] == nil then
                Record.Signals[Property]:Disconnect()
                Record.Signals[Property], Record.Original[Property] = nil, nil
                Object[Property] = Original
            end
        end
        for Property, Value in pairs(Desired) do
            if Record.Original[Property] == nil then
                Record.Original[Property] = Object[Property]
                Record.Signals[Property] = Object:GetPropertyChangedSignal(Property):Connect(function()
                    if not self.Active then return end
                    local Expected = DesiredProperties(Object)[Property]
                    if Expected ~= nil and Object[Property] ~= Expected then Object[Property] = Expected end
                end)
            end
            if Object[Property] ~= Value then Object[Property] = Value end
        end
    end

    function Controller:Observe(Object)
        if not self.Active then return end
        -- A streamed trigger can arrive after its lock/prompt. Revisit that
        -- door immediately so all of its protection becomes ready together.
        if Object.Name == "Hidden" and Object.Parent
            and (Object.Parent.Name == "DoorFake" or Object.Parent.Name == "FakeDoor") then
            Object = Object.Parent
        end
        if Rules[Object.Name] then
            Roots[Object] = true
            self:Apply(Object)
            for _, Part in ipairs(Object:GetDescendants()) do self:Apply(Part) end
        else
            self:Apply(Object)
        end
    end

    function Controller:Scan(Container)
        if not self.Active or not Container then return end
        if Rules[Container.Name] then self:Observe(Container) end
        for _, Object in ipairs(Container:GetDescendants()) do
            if Rules[Object.Name] then self:Observe(Object) end
        end
    end

    local function CurrentRoomNumber()
        return tonumber(Player:GetAttribute("CurrentRoom"))
            or (Context.LatestRoom and tonumber(Context.LatestRoom.Value)) or 0
    end

    function Controller:RequestAhead()
        if not self.Active or not Workspace.StreamingEnabled then return end
        local Enabled = false
        for _, Rule in pairs(Rules) do if IsOn(Rule.Toggle) then Enabled = true; break end end
        if not Enabled then return end
        if StreamBusy then StreamPending = true; return end
        local Number = CurrentRoomNumber()
        local Current = Rooms:FindFirstChild(tostring(Number))
        local Next = Rooms:FindFirstChild(tostring(Number + 1))
        local Target = Next and (Next:FindFirstChild("RoomEntrance") or Next:FindFirstChild("RoomExit"))
            or (Current and Current:FindFirstChild("RoomExit"))
        if not Target or not Target:IsA("BasePart") then return end
        local Key = tostring(Number + 1)
        -- Coalesce room-added, room-number and config events for the same door.
        if Streamed[Key] and tick() - Streamed[Key] < 1 then return end
        Streamed[Key], StreamBusy = tick(), true
        task.spawn(function()
            if self.Active then
                -- This can only stream instances that the server has created.
                pcall(function() Player:RequestStreamAroundAsync(Target.Position, 2) end)
            end
            StreamBusy = false
            if not self.Active then return end
            self:Scan(Rooms:FindFirstChild(tostring(CurrentRoomNumber() + 1)))
            if StreamPending then StreamPending = false; self:ScheduleAhead() end
        end)
    end

    function Controller:ScheduleAhead()
        if not self.Active or Scheduled then return end
        Scheduled = true
        task.defer(function()
            Scheduled = false
            if self.Active then self:RequestAhead() end
        end)
    end

    function Controller:Refresh()
        if not self.Active then return end
        for Object in pairs(Records) do self:Apply(Object) end
        for Root in pairs(Roots) do
            if Root:IsDescendantOf(Workspace) then self:Observe(Root) else Roots[Root] = nil end
        end
        self:ScheduleAhead()
    end

    function Controller:Destroy()
        if not self.Active then return end
        self.Active = false
        for _, Connection in ipairs(Connections) do Connection:Disconnect() end
        for Object, Record in pairs(Records) do Restore(Object, Record) end
        table.clear(Roots)
    end
    Controller.Disconnect = Controller.Destroy

    -- Subscribe before taking the initial snapshot so streaming during the scan
    -- cannot leave an unprotected gap. Late hitboxes use the same immediate path.
    table.insert(Connections, Workspace.DescendantAdded:Connect(function(Object) Controller:Observe(Object) end))
    table.insert(Connections, Rooms.ChildAdded:Connect(function(Room)
        Controller:Scan(Room)
        Controller:ScheduleAhead()
    end))
    table.insert(Connections, Player:GetAttributeChangedSignal("CurrentRoom"):Connect(function() Controller:ScheduleAhead() end))
    if Context.LatestRoom then
        table.insert(Connections, Context.LatestRoom:GetPropertyChangedSignal("Value"):Connect(function() Controller:ScheduleAhead() end))
    end
    Controller:Scan(Rooms)
    for _, Object in ipairs(Workspace:GetChildren()) do
        if Rules[Object.Name] then Controller:Observe(Object) end
    end
    Controller:ScheduleAhead()
    return Controller
end
