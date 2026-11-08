# Blox Fruits: supplied Halloween collector and Abysall support

Source file: `blox fruit.lua` (46,870 bytes, 12 logical lines). It is a
LuaObfuscator.com Alpha 0.10.9 output, not readable game code. Its visible
header credits `SPIRITUAL GAMING`; the decoded GUI says `BLOX FRUITS
HALLOWEEN` and its only gameplay action is `AUTO COLLECT PUMPKIN`.

## Static recovery

The payload after the `LOL!` marker is an RLE-hex stream. Decoding it yields a
13,427-byte constant block. The embedded Ferib VM parser was isolated from the
executor path and run offline against that payload. It produced the complete
constant table without running the game code or contacting a service.

Recovered behavior:

- Creates `BloxFruitsHalloweenGUI` in `CoreGui`; the window is named
  `BloxFruitsHalloweenGUI`, prevents respawn loss, is draggable and can be
  minimized through `MinimizeBtn`.
- The button is labelled `AUTO COLLECT PUMPKIN`, uses cursor asset
  `rbxassetid://100054563`, and the footer reads `YOUTUBE: SPIRITUAL GAMING`.
- Toggles a movement state using `BodyVelocity` (`FarmBodyVelocity`),
  `BodyGyro` (`FarmBodyGyro`) and `Humanoid.PlatformStand`; `Stepped` and
  `task.spawn` drive collection and `Disconnect`/`Destroy` tear it down.
- Looks for `PumpkinHunt` in the workspace, reads child `Model` objects,
  follows `PrimaryPart`/`GetPivot()`, measures distance with `Magnitude`, and
  moves toward the target using vector direction helpers.
- Uses virtual mouse clicks through `VirtualInputManager:SendMouseButtonEvent`;
  GUI helpers use `AbsolutePosition`/`AbsoluteSize` for drag and display code.
- Iterates workspace `BasePart` descendants and changes `CanCollide` during the
  collection path.
- No webhook, remote name, or game-specific validation is present in the
  recovered constants. It is a client-side automation for the 2026 Halloween
  Pumpkin Hunt.

## Abysall implementation

`Games/BloxFruits/Main.luau` is a clean-room implementation. It does not copy
the supplied file. It provides:

- Player ESP.
- Generic name-filtered ESP for Models and BaseParts, with comma/semicolon
  separated filters.
- Pumpkin ESP for objects under `Workspace.PumpkinHunt`, plus a name-token
  fallback.
- Auto Collect Pumpkin: scans the event objects, selects the nearest target,
  moves gradually or blinks at the user's option, caps range/click timing, and
  clicks the target's projected screen position when it is visible.
- Optional WalkSpeed looping.

Place `2753915549` / Universe `994732206` are registered in
`Components/GameRegistry.luau`.

## Limitations

- Pumpkin object layout is event-specific. The implementation accepts both
  `Model` objects with a usable part and raw `BasePart` objects, because the
  supplied script reportedly collects a server-spawned event folder whose
  exact descendant classes can vary by update.
- `VirtualInputManager` clicks require the cursor/pumpkin to be on screen and
  the object's screen projection to be available. `Blink to Pumpkins` bypasses
  the traversal requirement but is more aggressive than gradual movement.
- The module does not generate pumpkins, fabricate drops, or call game remotes.
  It only reacts to objects that already exist on the client.
- Verify the event in a live server after Roblox content updates; event names
  or folders can change without an Abysall update.
