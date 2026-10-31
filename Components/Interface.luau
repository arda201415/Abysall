local UIStyle = Abysall.UILibrary == "Linoria" and "Linoria" or "Obsidian"
local BaseUrls = {
  Obsidian = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/",
  Linoria = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/",
}
local BaseUrl = BaseUrls[UIStyle]
local AbysallUrl = "https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/"

local InterfaceUrls = {
  Library = BaseUrl .. "Library.lua",
  SaveManager = BaseUrl .. "addons/SaveManager.lua",
  ThemeManager = BaseUrl .. "addons/ThemeManager.lua",
  InfoTab = AbysallUrl .. "Components/InfoTab.luau",
  SettingsTab = AbysallUrl .. "Components/SettingsTab.luau",
  Addons = AbysallUrl .. "Components/Addons.luau",
  SupportedGamesTab = AbysallUrl .. "Components/SupportedGamesTab.luau",
}
if UIStyle == "Linoria" then InterfaceUrls.LinoriaCursor = AbysallUrl .. "Components/LinoriaCursor.luau" end

local Report = Abysall.ReportProgress
local RunModule = Abysall.RunModule
local InterfaceSources = Abysall.FetchModules(InterfaceUrls, "Downloading interface", 0.5, 0.68)

Report("Starting interface", UIStyle, 0.7)
local Library, Cursor
if UIStyle == "Linoria" then
  Cursor = RunModule(InterfaceSources.LinoriaCursor, "LinoriaCursor")()
  -- Keep the cursor adapter local to this library, without replacing Drawing globally.
  Library = RunModule("local Drawing = ...\n" .. InterfaceSources.Library, UIStyle .. "/Library", Cursor.Drawing)
  Cursor:Bind(Library)
else
  Library = RunModule(InterfaceSources.Library, UIStyle .. "/Library")
end
local Interface = { UIStyle = UIStyle, Library = Library }
-- Keep a reference for cleanup if a manager or shared tab fails to initialize.
Abysall.Interface = Interface
if UIStyle == "Linoria" then
  -- Linoria exposes these tables globally; game modules use Library fields.
  Library.Toggles = getgenv().Toggles
  Library.Options = getgenv().Options
  Library.Scheme = Library

  -- Shared components also use Obsidian's table-based notification format.
  local Notify = Library.Notify
  function Library:Notify(Message, Duration)
    if type(Message) == "table" then
      Duration = Message.Time or Duration
      local Title = tostring(Message.Title or "")
      local Body = tostring(Message.Description or Message.Body or "")
      Message = Title .. (Title ~= "" and Body ~= "" and "\n" or "") .. Body
    end
    return Notify(self, tostring(Message), type(Duration) == "number" and Duration or nil)
  end
end

Report("Loading themes and profiles", UIStyle, 0.74)
Interface.SaveManager = RunModule(InterfaceSources.SaveManager, UIStyle .. "/SaveManager")
Interface.ThemeManager = RunModule(InterfaceSources.ThemeManager, UIStyle .. "/ThemeManager")
Report("Preparing menu", "Info, games, settings and addons", 0.77)
local ApplyInfo = RunModule(InterfaceSources.InfoTab, "InfoTab")
local ApplySettings = RunModule(InterfaceSources.SettingsTab, "SettingsTab")
local ApplyAddons = RunModule(InterfaceSources.Addons, "Addons")
Interface.ApplySupportedGamesTab = RunModule(InterfaceSources.SupportedGamesTab, "SupportedGamesTab")

function Interface.ApplyInfoTab(Window)
  Report("Building menu", "Home and supported games", 0.9)
  return ApplyInfo(Window)
end

function Interface.ApplySettingsTab(Window)
  Report("Applying settings", "Loading your theme and profile...", 0.92)
  return ApplySettings(Window)
end

function Interface.ApplyAddons(Window, CurrentGame)
  Report("Loading addons", "Finishing your menu...", 0.96)
  return ApplyAddons(Window, CurrentGame)
end

Interface.ThemeManager.BuiltInThemes = {
		["Default"]        = { 1,  { FontColor = "ffffff", MainColor = "1c1c1c", AccentColor = "0055ff", BackgroundColor = "141414", OutlineColor = "323232" } },
		["BBot"]           = { 2,  { FontColor = "ffffff", MainColor = "1e1e1e", AccentColor = "7e48a3", BackgroundColor = "232323", OutlineColor = "141414" } },
		["Fatality"]       = { 3,  { FontColor = "ffffff", MainColor = "1e1842", AccentColor = "c50754", BackgroundColor = "191335", OutlineColor = "3c355d" } },
		["Jester"]         = { 4,  { FontColor = "ffffff", MainColor = "242424", AccentColor = "db4467", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
		["Mint"]           = { 5,  { FontColor = "ffffff", MainColor = "242424", AccentColor = "3db488", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
		["Tokyo Night"]    = { 6,  { FontColor = "ffffff", MainColor = "191925", AccentColor = "6759b3", BackgroundColor = "16161f", OutlineColor = "323232" } },
		["Ubuntu"]         = { 7,  { FontColor = "ffffff", MainColor = "3e3e3e", AccentColor = "e2581e", BackgroundColor = "323232", OutlineColor = "191919" } },
		["Quartz"]         = { 8,  { FontColor = "ffffff", MainColor = "232330", AccentColor = "426e87", BackgroundColor = "1d1b26", OutlineColor = "27232f" } },
		["Nord"]           = { 9,  { FontColor = "eceff4", MainColor = "3b4252", AccentColor = "88c0d0", BackgroundColor = "2e3440", OutlineColor = "4c566a" } },
		["Dracula"]        = { 10, { FontColor = "f8f8f2", MainColor = "44475a", AccentColor = "ff79c6", BackgroundColor = "282a36", OutlineColor = "6272a4" } },
		["Monokai"]        = { 11, { FontColor = "f8f8f2", MainColor = "272822", AccentColor = "f92672", BackgroundColor = "1e1f1c", OutlineColor = "49483e" } },
		["Gruvbox"]        = { 12, { FontColor = "ebdbb2", MainColor = "3c3836", AccentColor = "fb4934", BackgroundColor = "282828", OutlineColor = "504945" } },
		["Solarized"]      = { 13, { FontColor = "839496", MainColor = "073642", AccentColor = "cb4b16", BackgroundColor = "002b36", OutlineColor = "586e75" } },
		["Catppuccin"]     = { 14, { FontColor = "d9e0ee", MainColor = "302d41", AccentColor = "f5c2e7", BackgroundColor = "1e1e2e", OutlineColor = "575268" } },
		["One Dark"]       = { 15, { FontColor = "abb2bf", MainColor = "282c34", AccentColor = "c678dd", BackgroundColor = "21252b", OutlineColor = "5c6370" } },
		["Cyberpunk"]      = { 16, { FontColor = "f9f9f9", MainColor = "262335", AccentColor = "00ff9f", BackgroundColor = "1a1a2e", OutlineColor = "413c5e" } },
		["Oceanic Next"]   = { 17, { FontColor = "d8dee9", MainColor = "1b2b34", AccentColor = "6699cc", BackgroundColor = "16232a", OutlineColor = "343d46" } },
		["Material"]       = { 18, { FontColor = "eeffff", MainColor = "212121", AccentColor = "82aaff", BackgroundColor = "151515", OutlineColor = "424242" } },
	}

return Interface
