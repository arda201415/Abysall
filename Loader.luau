if Abysall then
    -- Onceki calistirma yarida kesilmis olabilir; sessizce donmek yerine temizle
    warn("[Abysall] onceki oturum bulundu, temizleniyor")
    -- Onceki oturumun cleanup'ini calistir. Bu olmadan:
    --  - Doors'ta sahte (Fake) prompt'lar CoreGui'de saklanan gercek prompt'lari
    --    geride birakir; yeni oturumda esleşme olmadigi icin prompt'a basmak
    --    hicbir sey yapmaz.
    --  - ScooterEmpire auto-drive/wheelie donguleri calismaya devam eder ve
    --    W/A/S/D tuslari basili kalir.
    pcall(function()
        local Lib = Abysall.Interface and Abysall.Interface.Library
        if Lib and type(Lib.Unload) == "function" then
            Lib:Unload()
        end
    end)
    getgenv().Abysall = nil
end
getgenv().Abysall = {
    Legit = true
}

local GameList = {
  [2440500124] = "Doors"
}

local PlaceList = {
  [120851538706364] = "MurderDuels",
  [120783481568445] = "MurderDuels", -- Trading Plaza
  [130031996774546] = "Trollge", -- Trollge Rebirth
  [10696301650] = "Primeval", -- Primeval Earth
  [10926417608] = "CheapDoors", -- DOORS but kinda cheap
  [10873387885] = "CheapDoors", -- root/lobi
  [12696293710] = "CheapDoors", -- rooms
  [133809021725719] = "CheapDoors", -- hotel remake
  [18687417158] = "Forsaken", -- Forsaken
  [83645629621104] = "Forsaken", -- [N] Forsaken
  [86454545238517] = "Forsaken", -- [VC] Forsaken
  [94626476208514] = "Forsaken", -- [Randomizer] Forsaken
  [7331291885] = "LarpingLegends2", -- Larping Legends 2
  [123720558354386] = "Pyramid", -- Build the Pyramid!
  [18186775539] = "Foundation", -- THE FOUNDATION (ana yer)
  [77614252294790] = "Foundation", -- THE FOUNDATION (alt yer)
  [100659280755645] = "ScooterEmpire", -- Scooter Empire [BETA]
}



local BaseUrl = "https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/"
-- Bagimsiz modulleri paralel indir (sirali indirme yuklemeyi yavaslatiyordu)
local EnvSource, ESPSource
task.spawn(function()
	local Ok, Res = pcall(function() return game:HttpGet(BaseUrl .. "Components/Environment.luau") end)
	if Ok then EnvSource = Res end
end)
task.spawn(function()
	local Ok, Res = pcall(function() return game:HttpGet(BaseUrl .. "Components/ESP.luau") end)
	if Ok then ESPSource = Res end
end)
local FetchStart = tick()
while (not EnvSource or not ESPSource) and tick() - FetchStart < 15 do task.wait() end
if not EnvSource then EnvSource = game:HttpGet(BaseUrl .. "Components/Environment.luau") end
if not ESPSource then ESPSource = game:HttpGet(BaseUrl .. "Components/ESP.luau") end
getgenv().Abysall = {
    Environment = loadstring(EnvSource)(),
    ESPLibrary = loadstring(ESPSource)(),

    Legit = true, -- pog
}

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

local Env = Abysall.Environment
local UserData = {}
if Env.readfile then
    local OkRead, Decoded = pcall(function()
        return Services.HttpService:JSONDecode(Env.readfile("Abysall/UserData.json"))
    end)
    if OkRead and type(Decoded) == "table" then UserData = Decoded end
end
UserData.TotalExecutions = (tonumber(UserData.TotalExecutions) or 0) + 1
UserData.UILibrary = UserData.UILibrary == "Linoria" and "Linoria" or "Obsidian"
Abysall.TotalExecutions = UserData.TotalExecutions
Abysall.UILibrary = UserData.UILibrary

local function SaveUserData(Data)
    if not (Env.readfile and Env.writefile) then
        return false, "File access is unavailable."
    end
    return pcall(function()
        local MakeFolder = Env.makefolder or getgenv().makefolder
        if MakeFolder then pcall(MakeFolder, "Abysall") end
        Env.writefile("Abysall/UserData.json", Services.HttpService:JSONEncode(Data))
    end)
end

function Abysall.SetUIStyle(Value)
    if Value ~= "Obsidian" and Value ~= "Linoria" then
        return false, "Unknown UI style."
    end
    local Updated = table.clone(UserData)
    Updated.UILibrary = Value
    local Ok, Err = SaveUserData(Updated)
    if not Ok then return false, Err end
    UserData = Updated
    Abysall.UILibrary = Value
    return true
end

if Env.readfile and Env.writefile then
    local OkSave, ErrSave = SaveUserData(UserData)
    if not OkSave then warn("[Abysall] user settings could not be saved: " .. tostring(ErrSave)) end
end

local OkInterface, ErrInterface = pcall(function()
    Abysall.Interface = loadstring(game:HttpGet(BaseUrl .. "Components/Interface.luau"))()
    Abysall.Analytics = loadstring(game:HttpGet(BaseUrl .. "Components/Analytics.luau"))()
end)
if not OkInterface then
    warn("[Abysall] arayuz yukleme hatasi: " .. tostring(ErrInterface))
    getgenv().Abysall = nil
    return
end

local CurrentGame = GameList[game.GameId] or PlaceList[game.PlaceId]
print("[Abysall] place " .. tostring(game.PlaceId) .. " -> " .. tostring(CurrentGame or "Universal"))
local OkLoad, ErrLoad = pcall(function()
	if CurrentGame then
		loadstring(game:HttpGet(BaseUrl .. "Games/" .. CurrentGame .. "/Loader.luau"))()
	else
		loadstring(game:HttpGet(BaseUrl .. "Games/Universal/Loader.luau"))()
	end
end)
if not OkLoad then
	warn("[Abysall] yukleme hatasi: " .. tostring(ErrLoad))
	getgenv().Abysall = nil
end
