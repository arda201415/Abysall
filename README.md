# Abysall Hub is a free, open-sourced script hub I made because scripting is fun.
If you want to try it for yourself:
```
loadstring(game:HttpGet("https://raw.githubusercontent.com/arda201415/Abysall/refs/heads/main/Loader.luau"))()
```
Feel free to use any of the source code for your own projects, but credit would be appreciated.

The startup screen shows download, compatibility, interface, settings and addon
progress. Failed loads show the stage and a copyable error; successful loads close
the screen automatically.

The **Games** tab lists the 10 dedicated game modules and the Universal fallback,
with features, supported places and module source update dates. Routing and this
list share `Components/GameRegistry.luau`; update its IDs, features and `Updated`
date when changing a game module. Browsing the catalog does not switch modules.
