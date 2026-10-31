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

For the original full compatibility diagnostics, set
`getgenv().AbysallFullChecks = true` before running the loader. These tests include
network and signal checks and can take longer. Set it to `false` for fast startup.

The **Home** page shows the 12 dedicated game modules and the Universal fallback,
with features, supported places and module source update dates. Routing and this
list share `Components/GameRegistry.luau`; update its IDs, features and `Updated`
date when changing a game module. Browsing the catalog does not switch modules.

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
The source analysis and behavior reconstruction are in [Research/StealAnEgg.md](Research/StealAnEgg.md).

**Tap Simulator** (`72858262610964`) adapts 26 MIT-licensed feature modules from
[TrustyCoding/slopix-hub](https://github.com/TrustyCoding/slopix-hub/blob/main/games/72858262610964.lua)
to the selected Abysall UI. The menu opens while game data initializes; feature
controls and the saved profile load afterwards. Status and module errors appear
on Home. See [Games/TapSimulator/README.md](Games/TapSimulator/README.md) for coverage
and the pinned source/license details.
