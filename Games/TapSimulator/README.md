# Tap Simulator

Place ID: `72858262610964`. The central game registry routes this place to the
dedicated module and lists it on the existing Home page.

Game logic is adapted from [TrustyCoding/slopix-hub](https://github.com/TrustyCoding/slopix-hub/blob/11e1ab4ac99cb8a94e2b1146b9983cf2a4d3c478/games/72858262610964.lua),
revision `11e1ab4ac99cb8a94e2b1146b9983cf2a4d3c478` (MIT). The original copyright
and complete license are included both in `Modules.luau` and in
`LICENSE.slopix.txt`. `upstream.json` records the source hash and imported modules.

## Feature coverage

All 26 game feature modules from the upstream entry point are included:

| Module | Controls and behavior |
| --- | --- |
| home | Live currencies/progression, activity, Stop All, anti AFK |
| performance | FPS cap, effects/3D rendering, game quality, pets and hatch animations |
| tap | Paced tapping with sequence recovery, native auto clicker, rebirth packs |
| upgrades | Selected upgrades and rate-limit handling |
| skilltree | Automatic and manual affordable skill purchases |
| hatch | Egg selection, affordability, hatch count, teleport and delete filters |
| pets | Periodic/manual equip best |
| treats | Selected treats for pet leveling |
| enchant | Team/chosen pet, slot, keep filters and protected trait replacement |
| shrine | Select a blessing and track its tier |
| tradepost | Build, page, validate and copy a pet trade post |
| craft | Golden/Diamond/Rainbow strategies, exclusions and return position |
| honeypot | Selected Honey Pot recipes |
| potions | Brewing, potion crafting and selected boost use |
| rewards | Offline earnings/hatches, quests, Pet Index, chests and spins |
| stars | Shiny Star navigation and collection |
| items | Totems, gifts, weather dials, mastery rings and leaderboard rewards |
| pickups | Lucky Ducky, balloons and pigs |
| dig | Dig-site travel and timed hits |
| creatures | Creatures and world events, including available event handling |
| defense | Pet Defense, stopping wave, relic and return position |
| minigames | Memory Match and Boingo quests |
| mining | Mining, upgrades and daily choices |
| fishing | Spot, bait selection, rare waits and bait stock |
| halloween | Hallow Boss, Trick or Treat, Candy Witch and CandyCorn shop |
| dungeon | Mansion/dungeon focus and chest selection |

Settings/themes are supplied by Abysall's existing managers and save under
`Abysall/TapSimulator`. Addon game key: `tapsimulator`. The upstream UI, icon
bundle, downloader, 180-second blocking ready check and separate settings manager
are excluded. `Bridge.luau` maps its groupboxes, controls and variable-height
labels to the selected Linoria or Obsidian library.

The window opens before game data is ready. A cancellable background task reads
`Controllers.Core.DataController`, creates the feature controls, then loads the
profile and enables callbacks/automation. Home shows progress and per-module
errors. An unavailable game module affects its feature rather than closing the
entire menu. Unloading stops tracked workers and runs each module's cleanup.

Automation still uses the game's own remotes, prices, unlocks, gamepasses,
streaming, distances and seasonal availability. Local checks cannot establish
live server acceptance.

The upstream Bouncy Obby toggle and its automation branch are commented out in
this revision. That inactive code is retained; the active feature inventory has
97 controls (59 toggles, 10 sliders, 26 dropdowns and 2 inputs).

## Updating the import

Change the pinned revision in `Tools/import-tapsimulator.cjs`, review the upstream
changes, then run from the repository root:

```powershell
node Tools/import-tapsimulator.cjs
```

The importer also accepts a downloaded source and LICENSE as two arguments. It
extracts factory bodies without executing them and applies Abysall file paths,
persistent global names, branding and community links. Keep adapter changes in
`Main.luau` and `Bridge.luau` so rebuilding the package preserves them.
