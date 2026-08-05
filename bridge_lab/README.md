# TSS Bridge Lab

The Bridge Lab is an authorization-gated certification suite built directly
into `tss_bridge`. It loads no bridge modules until an authorized player uses
the configured command or F7 mapping.

## Access configuration

Edit `server_config.lua`. This file is server-only and is never included in the
client resource pack.

```lua
TSSBridgeLabServerConfig = {
    Enabled = true,
    Command = 'bridgelab',
    AllowedDiscordIds = {
        '123456789012345678',
    },
    AllowedFiveMIds = {
        '1234567',
    },
}
```

IDs may be entered with or without `discord:` / `fivem:` prefixes. Keep them as
quoted strings so long Discord IDs do not lose numeric precision. With both
lists empty, nobody can open the lab.

Restart `tss_bridge` after changing either config file, then use `/bridgelab` or
press `F7` in game. The F7 mapping only requests access from the server; both
entry points use the same server-side identifier check. There are no direct
client-side audit, spawn, or cleanup commands; all test actions are selected
from the authorized menu.

## Lab interface

The landing menu separates bridge certification from developer tooling:

- **Configuration** edits bridge-wide framework, notification, progress,
  target, inventory, TextUI, interaction, vehicle-key, and fuel defaults. Any
  option with a matching `server.cfg` convar is read-only and displays
  **Blocked by server.cfg**.
- **Test Centre** contains the full read-only audit plus grouped UI/feedback
  and gameplay/data suites.
- **Developer Tools** contains the interactive certification yard, session
  cleanup, and the freecam PolyZone Creator.

Highlighting an entry shows its purpose, availability, and suite status in the
detail panel. Pressing Escape in a submenu returns to its parent menu.

Unlocked configuration selections are validated by the server, saved across
resource restarts, and synchronized to all clients. A `server.cfg` convar always
has priority over a saved selection and the Lua default.

## PolyZone Creator

Open **Developer Tools → PolyZone Creator**, choose a shape, and enter a zone
name. The editor does not load or depend on the reference PolyZone resource.

All shapes use detached freecam controls:

- `WASD` moves the camera, `Q`/`E` moves down/up, `Shift` moves faster, and
  `Ctrl` enables precision movement. In box/circle mode, the mouse wheel changes
  camera speed.
- Box and circle editors use a mouse cursor. Hold right mouse to look around,
  left-drag the colored axes to move, and drag red handles to resize.
- Boxes start at `1 x 1 x 1`, have six face handles, and have a yellow heading
  ring. Circles start with a radius of `1`, have one radius handle, and are saved
  as three-dimensional `useZ` spheres.
- Polygon mode uses mouse look and a center crosshair. Left click places the
  ground marker, right click removes the last point, and the mouse wheel raises
  or lowers `maxZ`. The editor renders the resulting walls; `maxZ` stops at
  ground level. Enter saves and Backspace deletes the draft.
- Enter saves box/circle edits; Backspace or Escape deletes the draft.

The server validates names, coordinates, dimensions, polygon area, point count,
file size, authorization, and save rate before appending formatted Lua to
`bridge_lab/created_zones.lua`. Clients never provide raw Lua source. The output
contains `box`, `circle`, and `poly` records compatible with the familiar
PolyZone fields while retaining 3D size and ground-height information.

## Security model

- Lab access is authorized on the server using the player's actual
  `discord:` and `fivem:` identifiers.
- The identifier allowlist never leaves the server.
- Every server callback rechecks authorization independently.
- Mutation amounts, stash definitions, and other authoritative values come
  from bridge configuration rather than client payloads.
- Vehicle-key tests validate network ownership and never remove existing keys.
- Client-created entities, targets, interactions, and UI are cleaned when the
  bridge stops.

A client can execute arbitrary local code and display local UI, so the server
authorization checks—not the menu event—are the security boundary.

## What it exercises

The menu covers all bridge module families, including framework/player data,
money, groups, inventory, notifications, TextUI, progress, callbacks, UI,
blips, entities, distance spawning, targets, interactions, fuel, vehicle keys,
locale, capabilities, diagnostics, and debug formatters.

The read-only audit prints concise PASS/FAIL results to F8. Optional adapters
may report `none` without representing a bridge failure.

## Mutation tests

Money and item mutation tests are disabled by default in `server_config.lua`.
When enabled, they add and immediately restore configured values, reporting
whether the final balance/count matches its starting state. Do not enable these
tests on production: an adapter failure between the two operations could leave
the temporary value behind.

Shared visual/entity settings are in `config.lua`. Sensitive settings and
identifier allowlists belong only in `server_config.lua`.
