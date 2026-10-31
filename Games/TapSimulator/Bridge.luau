-- Adapt the imported feature API to the active Abysall UI library.
return function(Session, Life, Env)
    local Library = Session.Interface.Library
    local Ui = { Library = Library, Tabs = {}, Ready = false }
    local Controls, Automations = {}, {}

    local function Run(Name, Callback, ...)
        if not Life.alive or not Ui.Ready then return end
        return Life.call("ui:" .. Name, Callback, ...)
    end

    local function WrapControl(Id, Native, Callback)
        if Controls[Id] then return Controls[Id].Proxy end
        local State = { Native = Native, Callback = Callback }
        local Proxy = {}
        function Proxy:OnChanged(Fn)
            State.Changed = Fn
            local Registering = true
            Native:OnChanged(function(...)
                if not Registering then Run(Id, Fn, ...) end
            end)
            Registering = false
        end
        setmetatable(Proxy, {
            __index = function(_, Key)
                if Key == "Changed" then return State.Changed end
                local Value = Native[Key]
                if type(Value) == "function" then
                    return function(_, ...)
                        if Env then Env.elevate() end
                        return Value(Native, ...)
                    end
                end
                return Value
            end,
            __newindex = function(_, Key, Value) Native[Key] = Value end,
        })
        State.Proxy = Proxy
        Controls[Id] = State
        return Proxy
    end

    local function ControlTable(Native)
        return setmetatable({}, {
            __index = function(_, Id)
                local Control = Native[Id]
                return Control and WrapControl(Id, Control)
            end,
        })
    end
    Ui.Options, Ui.Toggles = ControlTable(Library.Options), ControlTable(Library.Toggles)

    local function WrapGroup(Native)
        local Group = {}
        for _, Method in ipairs({ "AddToggle", "AddSlider", "AddDropdown", "AddInput" }) do
            Group[Method] = function(_, Id, Info)
                if Env then Env.elevate() end
                local Copy = table.clone(Info)
                local Callback = Copy.Callback
                if Callback then Copy.Callback = function(...) Run(Id .. ":callback", Callback, ...) end end
                local Control = Native[Method](Native, Id, Copy)
                return WrapControl(Id, Control, Callback)
            end
        end
        function Group:AddButton(Info, Callback)
            local Text, Fn = Info, Callback
            if type(Info) == "table" then Text, Fn = Info.Text, Info.Func end
            if Env then Env.elevate() end
            if type(Info) == "table" then
                local Copy = table.clone(Info)
                Copy.Func = function(...) Run("button:" .. Text, Fn, ...) end
                return Native:AddButton(Copy)
            end
            return Native:AddButton(Text, function(...) Run("button:" .. Text, Fn, ...) end)
        end
        function Group:AddLabel(Text, Wrap)
            if Env then Env.elevate() end
            local Previous = {}
            if Native.Container then
                for _, Child in ipairs(Native.Container:GetChildren()) do Previous[Child] = true end
            end
            local Label = Native:AddLabel(Text, Wrap)
            local SetText = Label.SetText
            function Label:SetText(Value)
                if not Life.alive then return end
                if Env then Env.elevate() end
                return SetText(self, Value)
            end
            if type(Label.SetVisible) == "function" then return Label end
            local Added = {}
            if Native.Container then
                for _, Child in ipairs(Native.Container:GetChildren()) do
                    if not Previous[Child] and Child:IsA("GuiObject") then table.insert(Added, Child) end
                end
            elseif Label.TextLabel then
                table.insert(Added, Label.TextLabel)
            end
            function Label:SetVisible(Visible)
                if Env then Env.elevate() end
                for _, Child in ipairs(Added) do Child.Visible = Visible end
                if Native.Resize then Native:Resize() end
            end
            return Label
        end
        function Group:AddDivider()
            if Env then Env.elevate() end
            return Native:AddDivider()
        end
        return Group
    end

    function Ui.wrapTab(Native)
        return {
            AddGroupbox = function(_, Info)
                if Env then Env.elevate() end
                local Method = Info.Side == "Right" and "AddRightGroupbox" or "AddLeftGroupbox"
                return WrapGroup(Native[Method](Native, Info.Name))
            end,
        }
    end

    function Ui.notify(Title, Message, Duration)
        if not Life.alive then return end
        Library:Notify({ Title = Title == "Slopix Hub" and "Abysall Hub" or Title, Description = Message, Time = Duration or 5 })
    end

    function Ui.on(Id)
        local Toggle = Library.Toggles[Id]
        return Life.alive and Ui.Ready and Toggle ~= nil and Toggle.Value == true
    end

    function Ui.set(Id, Value)
        local Toggle = Library.Toggles[Id]
        if Life.alive and Toggle and Toggle.Value ~= Value then Toggle:SetValue(Value) end
    end

    function Ui.automation(Id, Stays)
        table.insert(Automations, { Id = Id, Stays = Stays == true })
    end

    function Ui.stopAll(MoversOnly)
        for _, Entry in ipairs(Automations) do
            if not (MoversOnly and Entry.Stays) then Ui.set(Entry.Id, false) end
        end
    end

    function Ui.panel(Group, Rows)
        local Labels = {}
        for Index = 1, Rows do
            Labels[Index] = Group:AddLabel("", true)
            Labels[Index]:SetVisible(false)
        end
        Group:AddDivider()
        local Footer = Group:AddLabel("", true)
        return { set = function(Lines, Text)
            if not Life.alive then return end
            for Index, Label in ipairs(Labels) do
                local Line = Lines[Index]
                Label:SetVisible(Line ~= nil)
                if Line ~= nil then Label:SetText(Line) end
            end
            Footer:SetText(Text or "")
        end }
    end

    function Ui.activate()
        if not Life.alive or Ui.Ready then return end
        Ui.Ready = true
        for Id, State in pairs(Controls) do
            if State.Callback then Run(Id .. ":callback", State.Callback, State.Native.Value) end
            if State.Changed then Run(Id, State.Changed, State.Native.Value) end
        end
    end

    return Ui
end
