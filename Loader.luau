if Abysall then
    return 
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
    if not Decoded.TotalExecutions then
        Decoded.TotalExecutions = 0    
    end

    Decoded.TotalExecutions = Decoded.TotalExecutions + 1

    if not Decoded.UILibrary then
        Decoded.UILibrary = "Obsidian"
    end

    Abysall.TotalExecutions = Decoded.TotalExecutions
    Abysall.UILibrary = Decoded.UILibrary

    Abysall.Environment.writefile("Abysall/UserData.json", Services.HttpService:JSONEncode(Decoded))
end

Abysall.Interface = loadstring(game:HttpGet(BaseUrl .. "Components/Interface.luau"))()
Abysall.Analytics = loadstring(game:HttpGet(BaseUrl .. "Components/Analytics.luau"))()

local CurrentGame = GameList[game.GameId] or PlaceList[game.PlaceId]
if CurrentGame then
    loadstring(game:HttpGet(BaseUrl .. "Games/" .. CurrentGame .. "/Loader.luau"))()
else
    loadstring(game:HttpGet(BaseUrl .. "Games/Universal/Loader.luau"))()
end
