-- Routing and the Games tab share this catalog. Updated tracks the last source
-- change in Games/<Id>, not an update or a live compatibility check of the game.
-- Keep Updated and Features current when changing a game module.
local Registry = {
    Entries = {
        {
            Id = "Doors", Name = "DOORS", GameIds = { 2440500124 },
            PlaceScripts = { [6516141723] = "Lobby" },
            Dependencies = { "Games/Doors/RoomProtection.luau" },
            Updated = "2026-10-31", Coverage = "Lobby and in-game floors",
            Features = { "Entity alerts", "Player, item and entity ESP", "Early contact protection", "Puzzle helpers", "Rooms automation" },
        },
        {
            Id = "MurderDuels", Name = "Murder Duels", PlaceIds = { 120851538706364, 120783481568445 },
            Updated = "2026-10-24", Coverage = "Main game and Trading Plaza",
            Features = { "Aim settings", "Player ESP", "Remote tools" },
        },
        {
            Id = "Trollge", Name = "Trollge Rebirth", PlaceIds = { 130031996774546 },
            Updated = "2026-10-24", Coverage = "Main game",
            Features = { "Cooldown tools", "Aim settings", "Ability tools", "Player ESP" },
        },
        {
            Id = "Primeval", Name = "Primeval Earth", PlaceIds = { 10696301650 },
            Updated = "2026-10-24", Coverage = "Main game",
            Features = { "Zone scanning and ESP", "Zone claiming", "Player ESP", "Movement settings" },
        },
        {
            Id = "CheapDoors", Name = "DOORS but kinda cheap",
            PlaceIds = { 10926417608, 10873387885, 12696293710, 133809021725719 },
            Updated = "2026-10-24", Coverage = "Lobby, main game, Rooms and Hotel remake",
            Features = { "Revive tools", "Entity alerts", "Door navigation", "Player and entity ESP" },
        },
        {
            Id = "Forsaken", Name = "Forsaken",
            PlaceIds = { 18687417158, 83645629621104, 86454545238517, 94626476208514 },
            Updated = "2026-10-24", Coverage = "Standard, N, VC and Randomizer places",
            Features = { "Aim settings", "Player and item ESP", "Stamina settings", "Farming tools" },
        },
        {
            Id = "LarpingLegends2", Name = "Larping Legends 2", PlaceIds = { 7331291885 },
            Updated = "2026-10-24", Coverage = "Main game",
            Features = { "Combat settings", "Farming tools", "Player ESP", "Movement settings" },
        },
        {
            Id = "Pyramid", Name = "Build the Pyramid!", PlaceIds = { 123720558354386 },
            Updated = "2026-10-02", Coverage = "Main game",
            Features = { "Block pickup and placement", "Bench training", "Gifts and codes", "Player ESP" },
        },
        {
            Id = "Foundation", Name = "THE FOUNDATION", PlaceIds = { 18186775539, 77614252294790 },
            Updated = "2026-10-05", Coverage = "Main game and secondary place",
            Features = { "Toolbox, crowbar and puzzle ESP", "Door and lever ESP", "Movement settings" },
        },
        {
            Id = "ScooterEmpire", Name = "Scooter Empire", PlaceIds = { 100659280755645 },
            Updated = "2026-10-31", Coverage = "Main game",
            Features = { "Auto Drive", "Auto Wheelie", "Police and parked-car tools", "Movement settings" },
        },
        {
            Id = "StealAnEgg", Name = "Steal An Egg", PlaceIds = { 107778070777162 },
            Updated = "2026-10-31", Coverage = "Main game",
            Features = { "Loop WalkSpeed", "Instant prompts", "Client correction controls", "Character reset" },
        },
        {
            Id = "TapSimulator", Name = "Tap Simulator", PlaceIds = { 72858262610964 },
            Dependencies = { "Games/TapSimulator/Modules.luau", "Games/TapSimulator/Bridge.luau" },
            Updated = "2026-10-31", Coverage = "Main game and Halloween activities",
            Features = { "Tapping and rebirth", "Hatching, pets and enchanting", "Crafting and potions", "Rewards and world events", "Minigames and Halloween automation" },
        },
        {
            Id = "Universal", Name = "Universal", Fallback = true,
            Updated = "2026-10-24", Coverage = "Other experiences; feature availability varies by game",
            Features = { "Player ESP", "Movement and lighting settings", "Aim settings", "Ability tools" },
        },
    },
}

local Games, Places, ById = {}, {}, {}
for _, Entry in ipairs(Registry.Entries) do
    ById[Entry.Id] = Entry
    for _, Id in ipairs(Entry.GameIds or {}) do Games[Id] = Entry end
    for _, Id in ipairs(Entry.PlaceIds or {}) do Places[Id] = Entry end
end

function Registry:Resolve(GameId, PlaceId)
    return Games[GameId] or Places[PlaceId] or ById.Universal
end

function Registry:ScriptPath(Entry, PlaceId)
    local Script = Entry.PlaceScripts and Entry.PlaceScripts[PlaceId] or "Main"
    return "Games/" .. Entry.Id .. "/" .. Script .. ".luau"
end

return Registry
