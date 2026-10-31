-- Adapt Linoria's two cursor triangles to a small GUI pointer. Its own menu
-- lifecycle creates/removes the shapes; the executor's Drawing API is not used.
return function()
    local Input = game:GetService("UserInputService")
    local Cursor = { Drawing = {}, Active = true }
    local Library, Gui, SavedIcon, SavedBehavior
    local Shapes = {}

    local function RestoreMouse()
        if SavedIcon ~= nil then Input.MouseIconEnabled = SavedIcon; SavedIcon = nil end
        if SavedBehavior ~= nil then Input.MouseBehavior = SavedBehavior; SavedBehavior = nil end
    end

    local function ClearEmptyGui()
        for Shape in pairs(Shapes) do if Shape.Image then return end end
        if Gui then Gui:Destroy(); Gui = nil end
        RestoreMouse()
    end

    local function Update(Shape)
        if not Cursor.Active then return end
        local Properties = Shape.Properties
        if not Properties.Filled or not Properties.Visible or Input.MouseEnabled == false then
            if Shape.Image then Shape.Image.Visible = false end
            return
        end
        if not Library or not Library.ScreenGui or not Library.ScreenGui.Parent then return end
        if SavedIcon == nil then SavedIcon, SavedBehavior = Input.MouseIconEnabled, Input.MouseBehavior end
        if not Gui then
            Gui = Instance.new("ScreenGui")
            Gui.Name = "AbysallLinoriaCursor"
            Gui.ResetOnSpawn = false
            Gui.IgnoreGuiInset = true
            Gui.DisplayOrder = 2147483647
            Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            Gui.Parent = Library.ScreenGui.Parent
        end
        if not Shape.Image then
            local Image = Instance.new("ImageLabel")
            Image.Name = "Pointer"
            Image.BackgroundTransparency = 1
            Image.Active = false
            Image.Size = UDim2.fromOffset(14, 18)
            -- Crop the transparent padding of Roblox's built-in 64px cursor.
            Image.Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png"
            Image.ImageRectOffset = Vector2.new(23, 31)
            Image.ImageRectSize = Vector2.new(24, 30)
            Image.AnchorPoint = Vector2.new(9 / 24, 1 / 30)
            Image.Parent = Gui
            Shape.Image = Image
        end
        local Position = Properties.PointA or Input:GetMouseLocation()
        Shape.Image.Position = UDim2.fromOffset(Position.X, Position.Y)
        Shape.Image.ImageColor3 = Properties.Color or Library.AccentColor
        Shape.Image.Visible = true
        Input.MouseIconEnabled = false
        Input.MouseBehavior = Enum.MouseBehavior.Default
    end

    function Cursor.Drawing.new(Kind)
        assert(Kind == "Triangle", "Unsupported Linoria cursor shape: " .. tostring(Kind))
        local Shape = { Properties = {} }
        function Shape:Remove()
            if self.Image then self.Image:Destroy(); self.Image = nil end
            Shapes[self] = nil
            ClearEmptyGui()
        end
        Shapes[Shape] = true
        return setmetatable(Shape, {
            __index = function(Self, Key) return Self.Properties[Key] end,
            __newindex = function(Self, Key, Value)
                if Key == "Image" then rawset(Self, Key, Value); return end
                Self.Properties[Key] = Value
                Update(Self)
            end,
        })
    end

    function Cursor:Destroy()
        if not self.Active then return end
        self.Active = false
        for Shape in pairs(Shapes) do Shape:Remove() end
        if Gui then Gui:Destroy(); Gui = nil end
        RestoreMouse()
    end

    function Cursor:Bind(TargetLibrary)
        Library = TargetLibrary
        local Unload = Library.Unload
        function Library:Unload(...)
            local Result = table.pack(pcall(Unload, self, ...))
            if not Result[1] and self.ScreenGui then pcall(function() self.ScreenGui:Destroy() end) end
            Cursor:Destroy()
            if not Result[1] then error(Result[2], 0) end
            return table.unpack(Result, 2, Result.n)
        end
    end

    return Cursor
end
