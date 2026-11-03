return function(Window)
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

	local Library = Abysall.Interface.Library
	local SaveManager = Abysall.Interface.SaveManager
	local ThemeManager = Abysall.Interface.ThemeManager
	
	local Toggles = Library.Toggles
	local Options = Library.Options

	-- Obsidian fork'umuzda eksik olan makefolder adimini burada kapat:
	-- config klasorleri yoksa SaveManager listesi/autoload sessizce olur.
	pcall(function()
		local Env = Abysall.Environment
		if Env.makefolder and Env.isfolder then
			local Paths = {
				"Abysall",
				"Abysall/" .. tostring(Abysall.SavePath),
				"Abysall/" .. tostring(Abysall.SavePath) .. "/settings",
				"Abysall/themes",
				"Abysall/themes/settings",
			}
			for _, P in ipairs(Paths) do
				if not Env.isfolder(P) then Env.makefolder(P) end
			end
		end
	end)
	
	local SettingsTab = Window:AddTab("Settings", "settings")
	local MenuGroup = SettingsTab:AddLeftGroupbox("Menu")
	
	MenuGroup:AddToggle("KeybindMenuOpen", {
		Default = Library.KeybindFrame.Visible,
		Text = "Open Keybind Menu",
		Callback = function(value)
			Library.KeybindFrame.Visible = value
		end,
	})
	if Abysall.Interface.UIStyle ~= "Linoria" then
		MenuGroup:AddToggle("ShowCustomCursor", {
			Text = "Custom Cursor",
			Default = false,
			Callback = function(Value)
				Library.ShowCustomCursor = Value
			end,
		})
	end

	-- Visible opt-out for Components/Analytics.luau. The preference lives in
	-- Abysall/UserData.json, so it is deliberately excluded from save configs.
	MenuGroup:AddToggle("SendAnonymousStats", {
		Text = "Send anonymous stats",
		Default = Abysall.Telemetry ~= false,
		Tooltip = "Sends your Roblox username, executor name, game name and place ID, and execution count to the hub's analytics endpoint. No IP address or hardware ID is collected. Changes apply the next time you run the loader.",
		Callback = function(Value)
			if type(Abysall.SetTelemetry) ~= "function" then return end
			local Ok, Err = Abysall.SetTelemetry(Value)
			if not Ok then
				Library:Notify("Stats preference applied for this run but could not be saved: " .. tostring(Err))
			end
		end,
	})

	local SelectedStyle = Abysall.UILibrary
	MenuGroup:AddDropdown("UILibrary", {
		Text = "UI Style",
		Tooltip = "Style changes apply the next time you run the script.",
		Values = {
			"Obsidian",
			"Linoria"
		},
		Default = (Abysall.UILibrary == "Linoria" and 2 or 1),
		Callback = function(Value)
			if Value == SelectedStyle then return end
			local Ok, Err = Abysall.SetUIStyle(Value)
			if not Ok then
				Options.UILibrary:SetValue(SelectedStyle)
				Library:Notify("UI style could not be saved: " .. tostring(Err))
				return
			end
			SelectedStyle = Value
			if Value ~= Abysall.Interface.UIStyle then
				Library:Notify("UI style saved. Run the script again to apply " .. Value .. ".")
			else
				Library:Notify("UI style saved: " .. Value .. ".")
			end
		end
	})
	
	if type(Library.SetDPIScale) == "function" then
		MenuGroup:AddDropdown("DPIDropdown", {
			Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
			Default = "100%",
			Text = "DPI Scale",
			Callback = function(Value)
				local Scale = Value:gsub("%%", "")
				local DPI = tonumber(Scale)
				Library:SetDPIScale(DPI)
			end,
		})
	end
	MenuGroup:AddDivider()
	MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
	
	MenuGroup:AddButton("Copy Discord Invite", function()
		local Clipboard = setclipboard or toclipboard
		if type(Clipboard) ~= "function" then
			Library:Notify("This executor has no clipboard function.")
			return
		end
		Clipboard("https://dsc.gg/abysallhub")
		Library:Notify("Discord invite copied.")
	end)
	
	MenuGroup:AddButton("Unload", function()
		Library:Unload()
	end)
	
	Library.ToggleKeybind = Options.MenuKeybind
	
	-- Config yuklemesi sirasinda bir toggle callback'i patlarsa tum hatt
	-- susturuluyordu; kim oldugu belli olmuyordu. Artik adini + hatayi yaziyor
	-- ve hatanin gecerlilik zincirini kesmiyor.
	local OldSafeCallback = Library.SafeCallback
	Library.SafeCallback = function(self, Func, ...)
		if not (Func and typeof(Func) == "function") then return end
		local Name = "?"
		pcall(function()
			local Info = debug.info(Func, "sl")
			if Info then Name = Info.short_src .. ":" .. tostring(Info.currentline) end
		end)
		local Ok, Err = xpcall(Func, function(E) return E end, ...)
		if not Ok then
			warn("[Abysall:Config] callback patladi -> " .. tostring(Name) .. " | " .. tostring(Err))
		end
		return Ok, Err
	end
	
	ThemeManager:SetLibrary(Library)
	SaveManager:SetLibrary(Library)
	SaveManager:IgnoreThemeSettings()
	SaveManager:SetIgnoreIndexes({"UILibrary", "SupportedGame", "SendAnonymousStats"})
	ThemeManager:SetFolder("Abysall")
	SaveManager:SetFolder("Abysall/" .. Abysall.SavePath)
	SaveManager:BuildConfigSection(SettingsTab)
	ThemeManager:ApplyToTab(SettingsTab)
	local OkLoad, ErrLoad = pcall(function() SaveManager:LoadAutoloadConfig() end)
	if not OkLoad then
		warn("[Abysall:Config] autoload basarisiz: " .. tostring(ErrLoad))
	end

	-- Remember the palette this menu ended up with (theme applied or stock
	-- Obsidian scheme) so the next run's bootstrap screen opens in the same
	-- colors instead of flashing the built-in blue.
	pcall(function()
		local Scheme = Library.Scheme
		if type(Scheme) ~= "table" or type(Abysall.SetLoadingPalette) ~= "function" then return end
		local function Hex(Color)
			if typeof(Color) ~= "Color3" then return nil end
			return string.format("%02X%02X%02X",
				math.floor(math.clamp(Color.R, 0, 1) * 255 + 0.5),
				math.floor(math.clamp(Color.G, 0, 1) * 255 + 0.5),
				math.floor(math.clamp(Color.B, 0, 1) * 255 + 0.5))
		end
		Abysall.SetLoadingPalette({
			Accent = Hex(Scheme.AccentColor),
			Main = Hex(Scheme.MainColor),
			Background = Hex(Scheme.BackgroundColor),
			Outline = Hex(Scheme.OutlineColor),
		})
	end)

	Library.SafeCallback = OldSafeCallback
end
