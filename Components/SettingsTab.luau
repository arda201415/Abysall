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
	MenuGroup:AddToggle("ShowCustomCursor", {
		Text = "Custom Cursor",
		Default = false,
		Callback = function(Value)
			Library.ShowCustomCursor = Value
		end,
	})

	MenuGroup:AddDropdown("UILibrary", {
		Text = "UI Style",
		Values = {
			"Obsidian",
			"Linoria"
		},
		Default = (Abysall.UILibrary == "Linoria" and 2 or 1),
		Callback = function(Value)
			if Abysall.Environment.writefile and Abysall.Environment.readfile then
				if not Abysall.Environment.isfile("Abysall/UserData.json") then
					local Data = {
						TotalExecutions = 0,
						UILibrary = "Obsidian"
					}
					Abysall.Environment.writefile("Abysall/UserData.json", Services.HttpService:JSONEncode(Data))
				end

				local UserData = Abysall.Environment.readfile("Abysall/UserData.json")
				local Decoded = Services.HttpService:JSONDecode(UserData)
				Decoded.UILibrary = Value

				if not Decoded.UILibrary then
					Decoded.UILibrary = "Obsidian"
				end

				Abysall.TotalExecutions = Decoded.TotalExecutions
				Abysall.UILibrary = Decoded.UILibrary

				Abysall.Environment.writefile("Abysall/UserData.json", Services.HttpService:JSONEncode(Decoded))
			end
		end
	})
	
	MenuGroup:AddDropdown("DPIDropdown", {
		Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
		Default = "100%",
	
		Text = "DPI Scale",
	
		Callback = function(Value)
			Value = Value:gsub("%%", "")
			local DPI = tonumber(Value)
	
			Library:SetDPIScale(DPI)
		end,
	})
	MenuGroup:AddDivider()
	MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
	
	MenuGroup:AddButton("Copy Discord Invite", function()
		toclipboard("https://dsc.gg/abysallhub")
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
	SaveManager:SetIgnoreIndexes({"UILibrary"})
	ThemeManager:SetFolder("Abysall")
	SaveManager:SetFolder("Abysall/" .. Abysall.SavePath)
	SaveManager:BuildConfigSection(SettingsTab)
	ThemeManager:ApplyToTab(SettingsTab)
	local OkLoad, ErrLoad = pcall(function() SaveManager:LoadAutoloadConfig() end)
	if not OkLoad then
		warn("[Abysall:Config] autoload basarisiz: " .. tostring(ErrLoad))
	end
	Library.SafeCallback = OldSafeCallback
end
