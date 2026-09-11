<<<<<<< HEAD
local BaseUrl = "https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/"
=======
local BaseUrl = "https://raw.githubusercontent.com/bocaj111004/Abysall/refs/heads/main/"
>>>>>>> 9fd6495987acf258fe2ef09198420edce8e0383b
if game.PlaceId ~= 6516141723 then
    loadstring(game:HttpGet(BaseUrl .. "Games/Doors/Main.luau"))()
else
    loadstring(game:HttpGet(BaseUrl .. "Games/Doors/Lobby.luau"))()
end
