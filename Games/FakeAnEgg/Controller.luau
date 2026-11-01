-- Readable reconstruction of the source's four automations.
return function(Context)
    local Catalog, Services, Player = Context.Catalog, Context.Services, Context.Player
    local Self = {
        Enabled = {}, Rarities = {}, Time = 0, NextHatch = 0, NextRebirth = 0,
        NextSell = 0, NextSteal = 0, HatchSlot = 1, Destroyed = false, StatusText = {},
    }
    local Features = { AutoHatch = true, AutoRebirth = true, AutoSell = true, AutoSteal = true }
    local AllowedRarities = {}
    for _, Name in ipairs(Catalog.Rarities) do AllowedRarities[Name] = true end

    function Self:_status(Feature, Text)
        if self.StatusText[Feature] == Text then return end
        self.StatusText[Feature] = Text
        if Context.Status then Context.Status(Feature, Text) end
    end

    function Self:_cancelSteal()
        local Active = self.Active
        self.Active = nil
        if Active and Active.Prompt and Active.Duration ~= nil then
            pcall(function() Active.Prompt.HoldDuration = Active.Duration end)
        end
    end

    function Self:_stop(Feature, Error)
        self:Set(Feature, false)
        self:_status(Feature, "Stopped: " .. tostring(Error))
        if Context.Changed then Context.Changed(Feature, false) end
        if Context.Error then Context.Error(Feature, tostring(Error)) end
    end

    function Self:Set(Feature, Enabled)
        if self.Destroyed then return false, "Module is unloaded." end
        if not Features[Feature] then return false, "Unknown automation." end
        Enabled = Enabled == true
        if Enabled and Feature == "AutoSteal" and type(Context.FirePrompt) ~= "function" then
            return false, "Auto Steal needs fireproximityprompt in this executor."
        end
        if self.Enabled[Feature] == Enabled then return true end
        self.Enabled[Feature] = Enabled
        if Feature == "AutoHatch" then self.HatchSlot, self.NextHatch = 1, self.Time end
        if Feature == "AutoRebirth" then self.NextRebirth = self.Time end
        if Feature == "AutoSell" then self.NextSell = self.Time end
        if Feature == "AutoSteal" then self:_cancelSteal(); self.NextSteal = self.Time end
        self:_status(Feature, Enabled and "Waiting for game data..." or "Off")
        return true
    end

    function Self:SetRarities(Selection)
        if self.Destroyed then return end
        local Selected = {}
        for Key, Value in pairs(type(Selection) == "table" and Selection or {}) do
            local Name = type(Key) == "number" and Value or (Value == true and Key)
            if AllowedRarities[Name] then Selected[Name] = true end
        end
        self.Rarities = Selected
        self:_cancelSteal()
        self.NextSteal = self.Time
    end

    function Self:_remote(Name, ...)
        local Folder = Services.ReplicatedStorage:FindFirstChild("RemoteEvents")
        local Remote = Folder and Folder:FindFirstChild(Name)
        if not Remote or not (Remote:IsA("RemoteEvent") or Remote:IsA("UnreliableRemoteEvent")) then return false end
        Remote:FireServer(...)
        return true
    end

    function Self:_root()
        local Character = Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        if not Root or not Root:IsA("BasePart") or (Humanoid and Humanoid.Health <= 0) then return nil end
        return Root, Character
    end

    local function FrameOf(Object)
        if Object:IsA("BasePart") then return Object.CFrame end
        if Object:IsA("Model") then
            local Ok, Frame = pcall(function() return Object:GetPivot() end)
            if Ok then return Frame end
        end
    end

    local function SameOwner(Value)
        return Value == Player.Name or Value == Player
    end

    local function IsOwnBase(Base)
        if Base.Name == Player.Name or SameOwner(Base:GetAttribute("Creator")) or SameOwner(Base:GetAttribute("Owner")) then return true end
        for _, Object in ipairs(Base:GetDescendants()) do
            if (Object:IsA("StringValue") or Object:IsA("ObjectValue")) and SameOwner(Object.Value) then return true end
        end
        return false
    end

    function Self:_collectFrame()
        local Bases = Services.Workspace:FindFirstChild("Bases")
        if not Bases then return nil end
        for _, Base in ipairs(Bases:GetChildren()) do
            if IsOwnBase(Base) then
                local Collect = Base:FindFirstChild("Collect", true)
                local Frame = Collect and FrameOf(Collect)
                if Frame then return Frame + Vector3.new(0, 3, 0) end
            end
        end
    end

    function Self:_matches(Egg)
        local Info = Egg:FindFirstChild("InfoGui")
        local Frame = Info and Info:FindFirstChild("Frame")
        local Rarity = Frame and Frame:FindFirstChild("CharRarity")
        if not Rarity then return false end
        local Texts = {}
        if Rarity:IsA("TextLabel") or Rarity:IsA("TextButton") then table.insert(Texts, Rarity.Text) end
        for Name in pairs(self.Rarities) do
            if Rarity:FindFirstChild(Name) then return true end
        end
        for _, Object in ipairs(Rarity:GetDescendants()) do
            if Object:IsA("TextLabel") or Object:IsA("TextButton") then table.insert(Texts, Object.Text) end
        end
        for _, Text in ipairs(Texts) do
            local Lower = string.lower((string.gsub(Text, "<[^>]->", "")))
            for Name in pairs(self.Rarities) do
                -- A Common selection must not also match Uncommon.
                if string.find(Lower, "%f[%a]" .. string.lower(Name) .. "%f[%A]") then return true end
            end
        end
        return false
    end

    function Self:_steal()
        local Root, Character = self:_root()
        if not Root then
            self:_cancelSteal()
            self:_status("AutoSteal", "Waiting for your character...")
            self.NextSteal = self.Time + Catalog.StealInterval
            return
        end
        local Active = self.Active
        if Active then
            if Active.Character ~= Character then self:_cancelSteal(); return end
            if self.Time < Active.Due then return end
            if Active.Phase == "Return" then
                local Frame = self:_collectFrame()
                if Frame then Root.CFrame = Frame end
                self:_cancelSteal()
                self.NextSteal = self.Time + Catalog.StealInterval
                self:_status("AutoSteal", Frame and "Returned to your Collect point." or "Your Collect point is not loaded.")
                return
            end
            local Eggs = Services.Workspace:FindFirstChild("ClientEggs")
            local Present = Eggs and Active.Egg:IsDescendantOf(Eggs)
            local Prompt = Active.Prompt
            if Active.Phase == "Approach" then
                if not Present then self:_cancelSteal(); self.NextSteal = self.Time + Catalog.StealInterval; return end
                Prompt = Active.Egg:FindFirstChildWhichIsA("ProximityPrompt", true)
                Active.Prompt = Prompt
                if Prompt then Active.Duration = Prompt.HoldDuration end
            end
            if Present and Prompt and Prompt.Parent and Prompt:IsDescendantOf(Active.Egg) then
                Prompt.HoldDuration = 0
                Context.FirePrompt(Prompt)
            end
            Active.Phase = Active.Phase == "Approach" and "SecondPrompt" or "Return"
            Active.Due = self.Time + (Active.Phase == "SecondPrompt" and Catalog.PromptDelay or Catalog.ReturnDelay)
            self:_status("AutoSteal", Active.Phase == "Return" and "Returning to your base..." or "Collecting " .. Active.Egg.Name .. "...")
            return
        end
        if self.Time < self.NextSteal then return end
        self.NextSteal = self.Time + Catalog.StealInterval
        if next(self.Rarities) == nil then self:_status("AutoSteal", "Select at least one rarity."); return end
        local Eggs = Services.Workspace:FindFirstChild("ClientEggs")
        if not Eggs then self:_status("AutoSteal", "Waiting for ClientEggs..."); return end
        local Matches = {}
        for _, Egg in ipairs(Eggs:GetChildren()) do
            if self:_matches(Egg) then
                local Frame = FrameOf(Egg)
                if Frame then table.insert(Matches, { Egg = Egg, Frame = Frame }) end
            end
        end
        if #Matches == 0 then self:_status("AutoSteal", "No loaded eggs match your rarities."); return end
        local Match = Matches[(Context.Random or math.random)(1, #Matches)]
        Root.CFrame = Match.Frame + Vector3.new(0, 3, 0)
        self.Active = { Egg = Match.Egg, Character = Character, Phase = "Approach", Due = self.Time + Catalog.ApproachDelay }
        self:_status("AutoSteal", "Approaching " .. Match.Egg.Name .. "...")
    end

    function Self:Step(Delta)
        if self.Destroyed then return end
        self.Time += math.max(tonumber(Delta) or 0, 0)
        for _, Feature in ipairs({ "AutoHatch", "AutoRebirth", "AutoSell", "AutoSteal" }) do
            if self.Enabled[Feature] then
                local Ok, Error = pcall(function()
                    if Feature == "AutoSteal" then self:_steal(); return end
                    local Next = Feature == "AutoHatch" and "NextHatch" or Feature == "AutoRebirth" and "NextRebirth" or "NextSell"
                    if self.Time < self[Next] then return end
                    local Name = Feature == "AutoHatch" and "OpenBlockEvent" or Feature == "AutoRebirth" and "RebirthEvent" or "SellAllEvent"
                    local Sent
                    if Feature == "AutoHatch" then
                        local Slot = self.HatchSlot
                        Sent = self:_remote(Name, tostring(Slot))
                        if Sent then self.HatchSlot = Slot % Catalog.HatchSlots + 1 end
                        self[Next] = self.Time + Catalog.HatchInterval + (Sent and Slot == Catalog.HatchSlots and Catalog.HatchCyclePause or 0)
                        self:_status(Feature, Sent and ("Opening slot " .. Slot .. "/" .. Catalog.HatchSlots) or "Waiting for " .. Name .. "...")
                    else
                        if Feature == "AutoSell" then Sent = self:_remote(Name, "Pets") else Sent = self:_remote(Name) end
                        self[Next] = self.Time + (Feature == "AutoSell" and Catalog.SellInterval or Catalog.RebirthInterval)
                        self:_status(Feature, Sent and "Active" or "Waiting for " .. Name .. "...")
                    end
                end)
                if not Ok then self:_stop(Feature, Error) end
            end
        end
    end

    function Self:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        self:_cancelSteal()
        table.clear(self.Enabled)
        if self.Connection then self.Connection:Disconnect() end
    end

    Self.Connection = Services.RunService.Heartbeat:Connect(function(Delta) Self:Step(Delta) end)
    return Self
end
