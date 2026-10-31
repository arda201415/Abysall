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

The **Home** page shows the 10 dedicated game modules and the Universal fallback,
with features, supported places and module source update dates. Routing and this
list share `Components/GameRegistry.luau`; update its IDs, features and `Updated`
date when changing a game module. Browsing the catalog does not switch modules.

In DOORS, the existing entity bypass switches also enable next-door preparation.
Enabled contact bypasses apply immediately to loaded rooms and newly streamed
hitboxes, independently of the ESP/prompt queue. Enable **Bypass Giggle** (or the
relevant entity bypass) to use its protection. Turning a bypass off or unloading restores
the original part properties. Next-door streaming requests run in the background;
they do not generate rooms or entities that the server has not created yet.
