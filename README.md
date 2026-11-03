# Abysall Hub is a free, open-sourced script hub I made because scripting is fun.
If you want to try it for yourself:
```
loadstring(game:HttpGet("https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/Loader.luau"))()
```
Feel free to use any of the source code for your own projects, but credit would be appreciated.

The startup screen shows download, compatibility, interface, settings and addon
progress. Failed loads show the stage and a copyable error; successful loads close
the screen automatically.

Startup uses quick capability detection, prefetches shared components and loads
the game script alongside the UI downloads. Avatar content resolves asynchronously
and optional session metadata runs after the menu opens. Downloads are shared only
within a run, so re-executing the loader always picks up fresh code.

Anonymous usage stats are on by default: Roblox username, executor name, game
name and place ID, and execution count, with no IP address or hardware ID.
**Settings → Send anonymous stats** turns them off; the choice is written to
`Abysall/UserData.json` and applied on the next run. `Components/Analytics.luau`
documents the exact payload.

For the original full compatibility diagnostics, set
`getgenv().AbysallFullChecks = true` before running the loader. These tests include
network and signal checks and can take longer. Set it to `false` for fast startup.

The **Home** page lists every dedicated game module and the Universal fallback,
with features, supported places and module source update dates. Routing, the game
list and the Home changelog all read `Components/GameRegistry.luau`; update its
IDs, features and `Updated` date when changing a game module. Browsing the catalog
does not switch modules.

In DOORS, the existing entity bypass switches also enable next-door preparation.
Enabled contact bypasses apply immediately to loaded rooms and newly streamed
hitboxes, independently of the ESP/prompt queue. Enable **Bypass Giggle** (or the
relevant entity bypass) to use its protection. Turning a bypass off or unloading restores
the original part properties. Next-door streaming requests run in the background;
they do not generate rooms or entities that the server has not created yet.

DOORS **Velocity Manipulation** uses **V** to toggle forward movement at the
selected speed. Both methods hold altitude while collisions are disabled;
**Pivot** advances in small steps based on frame time. Fly, hiding, cutscenes and
character death suspend the movement force.

The Linoria menu displays a small cursor in the current accent color while open.
Closing or unloading the menu restores the previous mouse icon and lock state.

**Steal An Egg** (`107778070777162`) includes Loop WalkSpeed, Instant Prompts,
optional client correction controls and character reset. Settings save separately
under `Abysall/StealAnEgg`; the module appears in the Home catalog automatically.

**Tap Simulator** (`72858262610964`) adapts 26 MIT-licensed feature modules from
[TrustyCoding/slopix-hub](https://github.com/TrustyCoding/slopix-hub/blob/main/games/72858262610964.lua)
to the selected Abysall UI. The menu opens while game data initializes; feature
controls and the saved profile load afterwards. Status and module errors appear
on Home. See [Games/TapSimulator/README.md](Games/TapSimulator/README.md) for coverage
and the pinned source/license details.

**99 Nights in the Forest** detects universe `7326934954`, lobby `79546208627805`
and forest place `126509999114328`. It includes item/NPC ESP, the source's 69
teleport names, campfire/grinder return, small-tree farming, right-click NPC aim
and flight. The lobby shows information and settings; run the loader again in a
forest match. Profiles save under `Abysall/NightsInTheForest`.

**Fake an Egg** detects universe `10769384180` and place `97289366402005`.
It includes auto hatch for slots 1–20, auto rebirth, auto sell pets and auto steal
with 11 rarity choices and return to the player's Collect point. Profiles save
under `Abysall/FakeAnEgg`.

The supplied `cameraman auto farm.lua` matched BARRAGE's shared loader after
newline normalization and was used to build **Cameraman Tower Defense**
(`132929771812494`, `114068177100380`). The offline analysis that documented it
(132 serialized functions and 392 strings) is no longer kept in the repository;
the module itself is the record.
