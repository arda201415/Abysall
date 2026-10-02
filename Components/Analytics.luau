--[[

    For anyone wondering, this just sends a discord message when someone executed the script.
    We only log basic data such as roblox username, executor used and the game you are in.
    Sensetive data such as IP adresses or HWIDs are NOT logged and never will be.
    If you want proof of this, feel free to dm me on discord: bocaj111004.

]]--

local function CloneReference(Object)
    if Abysall.Environment.cloneref then
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

local Safe = Abysall.Environment.Safe
local Identify = Abysall.Environment.identifyexecutor
local Request = Abysall.Environment.request
local CanSend = (type(Identify) == "function" and type(Request) == "function") or (Safe ~= nil and type(Safe.HttpGet) == "function")
if CanSend then
    local Player = Services.Players.LocalPlayer
    local GameName = "Bilinmiyor"
    pcall(function()
        local Info = Services.MarketplaceService:GetProductInfo(game.PlaceId)
        if Info and Info.Name then GameName = Info.Name end
    end)
    local Data = {
        Account = Player and Player.Name or "Bilinmiyor",
        Executor = Identify and Identify() or "Unknown",
        Executions = tonumber(Abysall.TotalExecutions) or 0,
        GameName = GameName,
        PlaceId = tostring(game.PlaceId)
    }

    task.spawn(function()
        pcall(function()
            local Url = "https://abysall.wispbyte.org/api/send"
            local Body = Services.HttpService:JSONEncode(Data)
            if type(Request) == "function" then
                Request({
                    Url = Url,
                    Method = "POST",
                    Headers = { ["content-type"] = "application/json" },
                    Body = Body
                })
            elseif Safe then
                Safe.HttpGet(Url .. "?account=" .. tostring(Data.Account)
                    .. "&executor=" .. tostring(Data.Executor)
                    .. "&place=" .. tostring(Data.PlaceId))
            end
        end)
    end)
end
