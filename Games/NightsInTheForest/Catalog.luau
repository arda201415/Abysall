-- Names and constants recovered statically from the user-provided source.
local Catalog = {
    Items = {
        "Alien", "Alien Chest", "Alien Shelf", "Alpha Wolf", "Alpha Wolf Pelt",
        "Anvil Base", "Apple", "Bandage", "Bear", "Berry", "Bolt", "Broken Fan",
        "Broken Microwave", "Bunny", "Bunny Foot", "Cake", "Carrot", "Chair Set",
        "Chest", "Chilli", "Coal", "Coin Stack", "Crossbow Cultist", "Cultist",
        "Cultist Gem", "Deer", "Fuel Canister", "Giant Sack", "Good Axe", "Iron Body",
        "Item Chest", "Item Chest2", "Item Chest3", "Item Chest4", "Item Chest6",
        "Laser Fence Blueprint", "Laser Sword", "Leather Body", "Log", "Lost Child",
        "Lost Child2", "Lost Child3", "Lost Child4", "Medkit", "Meat? Sandwich",
        "Morsel", "Old Car Engine", "Old Flashlight", "Old Radio", "Oil Barrel",
        "Raygun", "Revolver", "Revolver Ammo", "Rifle", "Rifle Ammo", "Riot Shield",
        "Sapling", "Seed Box", "Sheet Metal", "Spear", "Steak", "Stronghold Diamond Chest",
        "Tyre", "UFO Component", "UFO Junk", "Washing Machine", "Wolf", "Wolf Corpse", "Wolf Pelt",
    },
    NPCs = { "Alien", "Alpha Wolf", "Wolf", "Crossbow Cultist", "Cultist", "Bunny", "Bear", "Polar Bear" },
    IgnoreRadius = 50,
    Campfire = CFrame.new(0, 10, 0),
    Grinder = CFrame.new(16.1, 4, -4.6),
    AimRadius = 100,
    AimInterval = 0.02,
    AimSmoothing = 0.2,
    FlySpeed = 60,
    TreeTimeout = 12,
    ClickInterval = 0.2,
}
Catalog.ItemSet, Catalog.NPCSet = {}, {}
for _, Name in ipairs(Catalog.Items) do Catalog.ItemSet[Name] = true end
for _, Name in ipairs(Catalog.NPCs) do Catalog.NPCSet[Name] = true end
return Catalog
