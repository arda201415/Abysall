-- Abysall Addons (mspaint-tarzi eklenti sistemi)
-- Kullanim: executor'un workspace klasorunde "Abysall/addons" VEYA
-- "mspaint/addons" klasorune .luau / .lua / .txt eklentileri koy.
-- (mspaint klasoru de taranir, eklentiyi tasimana gerek yok.)
-- Sekme, bu oyunda gecerli en az 1 eklenti varsa otomatik acilir.
--
-- Eklenti sablonu:
--   abysall.AddonInfo = {
--       Name = "StarJug",            -- bosluk icermez
--       Title = "Star Jug",          -- groupbox basligi
--       Description = "Aciklama",    -- opsiyonel
--       Game = "*",                  -- "*" hepsi; veya "doors/doors", "doors/lobby",
--                                    -- "murderduels", "universal"; tablo da olur
--   }
--   abysall.Groupbox:AddButton({ Text = "Ver", Func = function() ... end })
--   abysall.Groupbox:AddToggle("StarJug_Hiz", { Text = "Hiz", Default = false })
--   abysall.Library.Toggles.StarJug_Hiz:OnChanged(function(V) ... end)
--   abysall.AddonDisable = function() ... end  -- unload'da calisir (opsiyonel)
--
-- Kurallar (mspaint ile ayni):
-- * AddonInfo dosyanin en ustunde OLMALI; ama yazilmamissa dosya adindan
--   otomatik uydurulur (Game = "*" sayilir) ve dosya yine calistirilir.
-- * Game uymazsa eklenti sessizce atlanir.
-- * Element ID'lerini eklenti adiyla prefix'le (corton: "StarJug_Hiz"), yoksa
--   baska eklentilerle cakisir. mspaint uyumlulugu icin `mspaint` globali de
--   ayni tabloya baglidir.

return function(Window, CurrentGame)
    local Loaded = {}
    if not Window then return Loaded end
    CurrentGame = string.lower(tostring(CurrentGame or "*"))
    warn("[Abysall:Addons] v2 yukleyici basladi, oyun: " .. CurrentGame)

    local Library = Abysall.Interface.Library
    local Env = Abysall.Environment or {}

    -- Environment sadece testten gecen fonksiyonlari kaydeder (orn. isfolder
    -- hic test edilmedigi icin hep nil'dir). Eksikleri globalden tamamla.
    local G = getgenv()
    local function FS(Name)
        if type(Env[Name]) == "function" then return Env[Name] end
        if type(G[Name]) == "function" then return G[Name] end
        return nil
    end
    local isfolder, makefolder = FS("isfolder"), FS("makefolder")
    local listfiles, readfile = FS("listfiles"), FS("readfile")
    local isfile, writefile = FS("isfile"), FS("writefile")

    local function Notify(Title, Body, Time)
        pcall(function()
            Library:Notify({ Title = Title, Description = Body, Time = Time or 5 })
        end)
        pcall(function()
            warn("[Abysall:Addons] " .. tostring(Title) .. ": " .. tostring(Body))
        end)
    end

    -- Dosya sistemi yoksa eklenti calismaz (mspaint ile ayni kural)
    if not (isfolder and makefolder and listfiles and readfile) then
        local Missing = {}
        if not isfolder then table.insert(Missing, "isfolder") end
        if not makefolder then table.insert(Missing, "makefolder") end
        if not listfiles then table.insert(Missing, "listfiles") end
        if not readfile then table.insert(Missing, "readfile") end
        warn("[Abysall:Addons] eksik fonksiyon: " .. table.concat(Missing, ", "))
        return Loaded
    end

    pcall(function() if not isfolder("Abysall") then makefolder("Abysall") end end)
    pcall(function() if not isfolder("Abysall/addons") then makefolder("Abysall/addons") end end)
    if not isfolder("Abysall/addons") then
        warn("[Abysall:Addons] Abysall/addons klasoru yok/acilamadi")
        return Loaded
    end

    -- Ilk kurulumda kisa bilgi dosyasi birak
    pcall(function()
        if isfile and writefile and not isfile("Abysall/addons/README.txt") then
            writefile("Abysall/addons/README.txt",
                "Abysall Addons\n" ..
                "==============\n" ..
                "Bu klasore .luau / .lua / .txt eklentileri koy (ornek: StarJug.luau).\n" ..
                "mspaint/addons klasorun varsa oradakiler de otomatik yuklenir.\n" ..
                "Her eklenti su blokla baslamali:\n\n" ..
                '  abysall.AddonInfo = { Name = "Ornek", Title = "Ornek", Description = "", Game = "*" }\n' ..
                "  abysall.Groupbox:AddButton({ Text = \"Merhaba\", Func = function() print(\"selam\") end })\n\n" ..
                'Game: "*" (hepsi), "doors/doors", "doors/lobby", "murderduels", "universal".\n' ..
                "Tablo da olur: Game = {\"doors/doors\", \"doors/lobby\"}.\n" ..
                "Element ID'lerini eklenti adiyla baslat (\"Ornek_Hiz\" gibi), yoksa cakisir.\n" ..
                "Dikkat: buradaki her dosya calistirilir, guvenmedigin dosyayi koyma.\n")
        end
    end)

    -- Iki klasor de taranir: once Abysall/addons, sonra mspaint/addons.
    -- Ayni isim iki tarafta da varsa Abysall/addons kazanir.
    local Folders = { "Abysall/addons", "mspaint/addons" }
    local Candidates = {}
    local Seen = {}
    local FolderCounts = {}
    for _, Folder in ipairs(Folders) do
        FolderCounts[Folder] = 0
        if isfolder(Folder) then
            local OkList, Files = pcall(function() return listfiles(Folder) end)
            if OkList and type(Files) == "table" then
                warn("[Abysall:Addons] " .. Folder .. ": " .. #Files .. " girdi")
                for _, Path in ipairs(Files) do
                    local Base = string.lower(tostring(Path):match("([^/\\]+)$") or tostring(Path))
                    -- README ve "_" / "." ile baslayanlar ile .disabled bitenler yuklenmez
                    local Skipped = Base:sub(1, 6) == "readme" or Base:sub(1, 1) == "_" or Base:sub(1, 1) == "."
                        or Base:match("%.disabled$")
                    local IsAddon = Base:match("%.luau$") or Base:match("%.lua$") or Base:match("%.txt$")
                    if not Skipped and IsAddon and not Seen[Base] then
                        Seen[Base] = true
                        FolderCounts[Folder] = FolderCounts[Folder] + 1
                        table.insert(Candidates, { Path = Path, Folder = Folder })
                    end
                end
            else
                warn("[Abysall:Addons] " .. Folder .. " listelenemedi")
            end
        end
    end
    table.sort(Candidates, function(A, B) return tostring(A.Path) < tostring(B.Path) end)
    warn("[Abysall:Addons] " .. #Candidates .. " eklenti adayi")
    if #Candidates == 0 then return Loaded end

    -- Sekme karari: AddonInfo iceren dosya yoksa sekme acma (calistirmadan bak)
    local HasCandidate = false
    for _, C in ipairs(Candidates) do
        local Ok, Src = pcall(readfile, C.Path)
        if Ok and type(Src) == "string" and Src:find("AddonInfo", 1, true) then
            HasCandidate = true
            break
        end
    end
    if not HasCandidate then
        warn("[Abysall:Addons] AddonInfo iceren dosya yok, hepsi otomatik taninacak")
    end

    -- Game eslesmesi: string | number (PlaceId) | table | "*"
    local function GameMatches(GameField)
        if GameField == nil then return false end
        if GameField == "*" then return true end
        local T = type(GameField)
        if T == "table" then
            for _, V in pairs(GameField) do
                if GameMatches(V) then return true end
            end
            return false
        end
        if T == "number" then
            local Ok, Pid = pcall(function() return game.PlaceId end)
            return Ok and Pid == GameField
        end
        local S = string.lower(tostring(GameField))
        if S == "*" or S == "all" then return true end
        return S == CurrentGame
    end

    local Tab = Window:AddTab("Addons", "puzzle")
    local Manager = Tab:AddLeftGroupbox("Addons")
    Manager:AddLabel("Klasor: Abysall/addons + mspaint/addons", true)

    local UseLeft = false
    local Skipped, Failed = 0, 0

    for _, C in ipairs(Candidates) do
        local Path = C.Path
        local FileName = tostring(Path):match("([^/\\]+)$") or tostring(Path)

        local OkRead, Source = pcall(readfile, Path)
        if not OkRead or type(Source) ~= "string" then
            Failed = Failed + 1
            pcall(function() Manager:AddLabel(FileName .. ": okunamadi", true) end)
        else
            local Fn, CompErr = loadstring(Source, "@" .. FileName)
            if not Fn then
                Failed = Failed + 1
                pcall(function() Manager:AddLabel(FileName .. ": syntax hatasi", true) end)
                warn("[Abysall:Addons] " .. FileName .. " derlenemedi: " .. tostring(CompErr))
            else
                -- mspaint kurali: AddonInfo set edilmeden Groupbox nil'dir.
                -- AddonInfo set edildigi anda game kontrolu yapilir, uyarsa
                -- groupbox hemen kurulur; uymazsa yukleme orada durur.
                local GroupboxRef = nil
                local State = { Set = false, Ok = false, Info = nil }
                local Ctx = {}
                local Shared = {
                    Library = Library,
                    Environment = Env,
                    Toggles = Library.Toggles,
                    Options = Library.Options,
                }
                setmetatable(Ctx, {
                    __index = function(_, Key)
                        if Key == "Groupbox" then
                            if State.Set and State.Ok then return GroupboxRef end
                            return nil
                        end
                        local Own = rawget(Ctx, Key)
                        if Own ~= nil then return Own end
                        return Shared[Key]
                    end,
                    __newindex = function(_, Key, Value)
                        if Key == "AddonInfo" then
                            State.Info = Value
                            State.Set = true
                            if type(Value) ~= "table" or type(Value.Name) ~= "string" then
                                error("__ABYSALL_ADDON_BAD_INFO__", 0)
                            end
                            if not GameMatches(Value.Game) then
                                error("__ABYSALL_ADDON_GAME_MISMATCH__", 0)
                            end
                            State.Ok = true
                            UseLeft = not UseLeft
                            local Title = tostring(Value.Title or Value.Name)
                            if UseLeft then
                                GroupboxRef = Tab:AddLeftGroupbox(Title)
                            else
                                GroupboxRef = Tab:AddRightGroupbox(Title)
                            end
                            if type(Value.Description) == "string" and Value.Description ~= "" then
                                GroupboxRef:AddLabel(Value.Description, true)
                            end
                            return
                        end
                        rawset(Ctx, Key, Value)
                    end,
                })

                local PrevAbysall = nil
                local PrevMspaint = nil
                pcall(function()
                    PrevAbysall = getgenv().abysall
                    PrevMspaint = getgenv().mspaint
                end)
                getgenv().abysall = Ctx
                getgenv().mspaint = Ctx
                local OkRun, RunErr = pcall(Fn)
                getgenv().abysall = PrevAbysall
                getgenv().mspaint = PrevMspaint

                if not OkRun then
                    local Msg = tostring(RunErr)
                    if Msg:find("__ABYSALL_ADDON_GAME_MISMATCH__", 1, true) then
                        Skipped = Skipped + 1
                    elseif Msg:find("__ABYSALL_ADDON_BAD_INFO__", 1, true) then
                        Failed = Failed + 1
                        pcall(function() Manager:AddLabel(FileName .. ": AddonInfo hatali", true) end)
                    else
                        Failed = Failed + 1
                        pcall(function() Manager:AddLabel(FileName .. ": calisma hatasi", true) end)
                        warn("[Abysall:Addons] " .. FileName .. " hatasi: " .. Msg)
                    end
                elseif not (State.Set and State.Ok) then
                    -- AddonInfo yazilmamissa dosya adindan uydur: kendi
                    -- groupbox'ini ac, yuklendi say (mspaint'ten farkli, kolaylik).
                    local BaseName = tostring(FileName):gsub("%.[^.]*$", "")
                    local AutoTitle = BaseName:gsub("[_%-%+]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                    if AutoTitle == "" then AutoTitle = "Addon" end
                    local AutoName = AutoTitle:gsub("%s+", "")
                    if AutoName == "" then AutoName = "Addon" end
                    UseLeft = not UseLeft
                    local AutoBox
                    if UseLeft then
                        AutoBox = Tab:AddLeftGroupbox(AutoTitle)
                    else
                        AutoBox = Tab:AddRightGroupbox(AutoTitle)
                    end
                    AutoBox:AddLabel("Otomatik tanindi (AddonInfo yoktu)", true)
                    local AutoDisabler = rawget(Ctx, "AddonDisable") or rawget(Ctx, "AddonDisabled")
                    if AutoDisabler ~= nil and type(AutoDisabler) ~= "function" then AutoDisabler = nil end
                    table.insert(Loaded, { Name = AutoName, Title = AutoTitle, File = FileName, Disable = AutoDisabler, Auto = true })
                    if AutoDisabler then
                        if type(Abysall.AddonDisablers) ~= "table" then Abysall.AddonDisablers = {} end
                        table.insert(Abysall.AddonDisablers, { Name = AutoName, Fn = AutoDisabler })
                    end
                    pcall(function()
                        Manager:AddLabel("Yuklendi: " .. AutoTitle .. " (otomatik)", true)
                    end)
                else
                    local Info = State.Info
                    local Disabler = rawget(Ctx, "AddonDisable") or rawget(Ctx, "AddonDisabled")
                    if Disabler ~= nil and type(Disabler) ~= "function" then Disabler = nil end
                    table.insert(Loaded, { Name = tostring(Info.Name), File = FileName, Disable = Disabler })
                    if Disabler then
                        if type(Abysall.AddonDisablers) ~= "table" then Abysall.AddonDisablers = {} end
                        table.insert(Abysall.AddonDisablers, { Name = tostring(Info.Name), Fn = Disabler })
                    end
                    pcall(function()
                        Manager:AddLabel("Yuklendi: " .. tostring(Info.Title or Info.Name), true)
                    end)
                end
            end
        end
    end

    pcall(function()
        Manager:AddLabel(#Loaded .. " yuklendi, " .. Skipped .. " atlandi, " .. Failed .. " hatali", true)
    end)
    warn("[Abysall:Addons] ozet: " .. #Loaded .. " yuklendi, " .. Skipped .. " atlandi, " .. Failed .. " hatali")
    if #Loaded > 0 then
        Notify("Addons", #Loaded .. " eklenti yuklendi.", 4)
    end

    return Loaded
end
