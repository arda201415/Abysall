local BaseUrl = "https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/"
local Script = game.PlaceId == 79546208627805 and "Lobby.luau" or "Main.luau"
loadstring(game:HttpGet(BaseUrl .. "Games/NightsInTheForest/" .. Script))()
