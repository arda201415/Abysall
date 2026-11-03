# BARRAGE loader — static analysis

Analysis of `cameraman auto farm.lua`, the script supplied as BARRAGE's Cameraman
Tower Defense entry point. The file is a protected distribution loader, not a game
script; this document records what it contains, what it talks to, and what cannot
be recovered from it.

## File under analysis

| Property | Value |
| --- | --- |
| Size | 407,751 bytes |
| Lines | 24 (line 12 is 406,824 bytes) |
| SHA-256 | `2a8ecd3f5fb1e301b6ed6c44b0dda42ac9175f17fe9ca9a07c14cc8269bd6c59` |
| MD5 | `1a1c245bbc6df966f270a8443cd58613` |

The hash matches the copy decoded on 2026-11-01, so the findings below describe
this exact file.

## What the file is

A distribution shell around BARRAGE's hosted scripts. It:

1. guards against double execution with `shared._barrageLoaderFlight`;
2. authenticates a key against `barrage.cc` and binds it to the executor's HWID;
3. opens a session and checks the current place against the remote catalog;
4. downloads the game-specific Luau from `/script/`, compiles it and runs it;
5. downloads a separate UI bundle and a runtime bundle;
6. caches all of that under `BARRAGE/` and re-queues itself after teleports.

It contains **no Cameraman Tower Defense gameplay code**. Across all 132 decoded
functions and 392 decoded strings there is not a single gameplay identifier:
`TowerAdd`, `TowerUpgrade`, `TowerSell`, `TowerTarget`, `WaveSkip`,
`SummonTowers`, `ChangeSpeed`, `PlayAgain`, `RedeemCode`, `Cameraman` — zero
matches. Neither do those names appear as plain text anywhere in the 407 KB.

## Anatomy

| Region | Content |
| --- | --- |
| Lines 1–10 | Plain wrapper: in-flight guard, notification, `shared` flags |
| Line 11 | `local _ok, _err = pcall(function(...)` |
| Line 12 | `return({ <132 VM handlers> })` over the packed frame |
| Lines 13–24 | `end, ...)`, readiness flags, error propagation |

Protection layers recovered from the payload:

| Layer | Detail |
| --- | --- |
| Packing | Custom-alphabet text blob, 200,871 bytes at offset 69,411 (+2 padding) |
| Frame cipher | Repeating XOR key `e3 36 18 5b 27 4b 6e 3d` |
| String cipher | `((byte - 179) * inverse(201)) mod 256 XOR 71` |
| Layer 1 bytecode | 53 functions / 10,526 instructions |
| Layer 2 bytecode | 132 functions / 29,603 instructions / 2,627 constants / 392 strings |

Verification performed here: the function index sums to exactly 29,603
instructions and its union of string references is exactly the 392-entry string
table, matching the decoder manifest. The VM itself was not executed.

## Network contract

| Endpoint | Purpose |
| --- | --- |
| `https://barrage.cc/ping` | Liveness probe |
| `https://barrage.cc/authentication` | Key/HWID authentication bundle |
| `https://barrage.cc/session/create` | Session creation |
| `https://barrage.cc/session/refresh` | Session refresh |
| `https://barrage.cc/session/owner` | Session owner lookup |
| `https://barrage.cc/catalog` | Game catalog (471 entries) |
| `https://barrage.cc/script/` | Per-game Luau delivery |
| `https://barrage.cc/runtime` | Runtime bundle |
| `https://barrage.cc/ui` | UI bundle |
| `https://barrage.cc/loader` | Loader self-reference |

Request headers observed in the string table: `X-Barrage-Session`,
`X-Barrage-User-ID`, `X-Barrage-Game-ID`, `X-Barrage-Universe-ID`,
`X-Barrage-Source-SHA256`, `X-Barrage-Bundle-SHA256`, `X-Barrage-Bundle-Key`,
`X-Barrage-Bundle-Size`, `X-Barrage-Cache-Version`, `X-Barrage-If-SHA256`,
`x-barrage-cache-hit`.

## Recovered state machine

Stage identifiers in the string table outline the flow:

`AUTH_CACHED` / `AUTH_DOWNLOAD` / `AUTH_COMPILE` / `AUTH_CLOSING` →
`CATALOG` / `CATALOG_CACHE` → `SCRIPT_REQUEST` / `SCRIPT_CACHE` / `SCRIPT_COMPILE`
/ `SCRIPT_EXECUTE` → `RUNTIME_REQUEST`.

Function mapping (layer 2 ids):

| Function | Size | Role |
| --- | --- | --- |
| `#0` | 1,563 instructions, 217 registers | Main orchestrator (auth, catalog, auto-rejoin) |
| `#5` | 183 instructions | Cache naming: `BARRAGE/cache`, `.bin`, `.lua` |
| `#33`, `#34` | — | Script request against `/script/` |
| `#46`, `#48`, `#52` | — | `barrage_session.dat` handling |
| `#68` | — | `X-Barrage-Game-ID` header |
| `#71` | — | `RUNTIME_REQUEST` stage |
| `#107`, `#108` | — | `BARRAGE/cache/index.json` |

On-disk cache paths named by the loader: `BARRAGE/cache/index.json`,
`BARRAGE/Game`, `BARRAGE/Runtime`, `BARRAGE/UI`, `BARRAGE/Authentication`,
`BARRAGE/catalog.json`, `barrage_session.dat`, `barrage_premium.dat`,
`barrage-authentication-cache:`, `barrage_rawtest_`.

## Access control

The string table documents key-system behaviour rather than just mentioning it:

- HWID binding via `gethwid` / `getexecutorhwid`, with `hwid_mismatch` errors;
- anti-sharing: "Your key was frozen by BARRAGE's anti-sharing protection";
- bans: "This key or device is banned from BARRAGE";
- session expiry and "session doesn't match this game" checks;
- per-place gating: `_barrageSupportedGames` decides whether the current place is
  in the catalog at all.

Data handled locally: the loader writes its own cache (`BARRAGE/...`), a session
file (`barrage_session.dat`) and a key file (`barrage_premium.dat`), and reads the
executor HWID. A `_barrageWebhook` identifier exists in the string table, but the
destination it resolves to is not recoverable from the static listing.

## What cannot be recovered statically

- **Gameplay logic.** It is delivered by `/script/` after authentication and never
  ships inside this file. Without a valid key and a matching HWID the payload is
  not reachable, so the Cameraman Tower Defense automation cannot be extracted by
  reading this loader.
- **VM behaviour beyond the listing.** The decoder produced an instruction
  listing, not source: mutation handlers, padding and runtime dispatch remain
  opaque, and the VM was deliberately not executed during analysis.

## Consequences for the Abysall module

`Games/CameramanTD/Main.luau` calls `TowerAdd`, `TowerUpgrade`, `TowerSell`,
`TowerTarget`, `WaveSkip`, `SummonTowers`, `ChangeSpeed`, `PlayAgain` and
`RedeemCode` through `ModuleLoader.Shared.Network`. None of those names can be
traced to this loader, so they date from a different source and remain
**unverified against the live game**. An in-game probe (list the real remote
names and their return values) is the only way to confirm or correct them.

## Reproduction

The decoder parameters are recorded in `manifest.json` in this folder
(frame offset/length, XOR key, string transform constants, layer counts). The
extracted string table is `strings.json`; the catalog snapshot fetched from
`barrage.cc/catalog` on 2026-11-01 is `catalog.json` (471 entries, SHA-256
`827be79b64c9c86f8aa30661e2426389b93cffc995907bc273efcaab346b502c`), which
includes `[💰X2] Cameraman Tower Defense` with places `132929771812494`,
`114068177100380` and universe `10762636904`.

The bulk artifacts from the earlier pass (`prototypes.json`, `functions.txt`, ~3.8
MB of instruction listings) are not kept in the repository; they can be
regenerated from the parameters in `manifest.json`.
