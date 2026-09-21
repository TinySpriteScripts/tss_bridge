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
- **Developer Tools** contains the interactive certification yard, PolyZone and
  prop-attachment creators, API Explorer, shared-item browser, and session
  cleanup.

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
  ground marker. Aim at an existing point and hold left click to drag it across
  the ground. Right click removes the last point, and the mouse wheel raises or
  lowers `maxZ`. The editor renders the resulting walls; `maxZ` stops at ground
  level. Enter saves and Backspace deletes the draft.
- Enter saves box/circle edits; Backspace deletes the draft.

The server validates names, coordinates, dimensions, polygon area, point count,
file size, authorization, and save rate before appending formatted Lua to
`bridge_lab/created_zones.lua`. Clients never provide raw Lua source. The output
contains `box`, `circle`, and `poly` records compatible with the familiar
PolyZone fields while retaining 3D size and ground-height information.

## Prop Attachment Creator

Open **Developer Tools → Prop Attachment Creator**, then provide a save name and
a valid GTA prop model. The editor attaches a local, non-colliding preview to
the current player ped.

- Press `B` to open the in-editor settings panel. Its dropdown contains the
  common ped-bone list and updates the live attachment immediately. Left/Right
  arrows remain available as quick bone-cycle controls.
- The settings panel accepts an animation dictionary, clip and flag. **Play**
  previews it on the ped, **Stop** ends the preview, and **Done editing** returns
  keyboard and mouse control to the gizmo.
- `Tab` switches between move axes and three-axis rotation rings.
- Left-drag a colored gizmo, and hold `Ctrl` for precision adjustments.
- Hold right mouse to look around. `WASD` moves the camera and `Q`/`E` moves it
  vertically.
- Enter saves; Backspace deletes the draft.

The server validates the model, bone, offsets, rotations, optional animation,
authorization, file size, and save rate before appending data to
`bridge_lab/created_prop_attatchments.lua`. The filename retains the requested
`attatchments` spelling. It is a data file and is not loaded automatically.

## Bridge API Explorer

The API Explorer parses `shared/types.lua`, the bridge's existing public type
source, whenever it opens. It groups functions by module, identifies client and
server availability independently, and shows exact parameter and return
signatures. Searches match both module and function names. Function names,
example calls, and `GetModules` imports can be copied directly.

Keeping the public annotations in `shared/types.lua` current automatically keeps
the explorer current; there is no separate API catalogue to maintain.

## Inventory Item Browser

The Item Browser calls only `Inventory.Items()` on the client. It never calls
`Inventory.Player()` and never reads a player's inventory. It displays the
active inventory adapter/resource, searches the shared item-definition table by
code or label, and tries the adapter resource's common image directories.

Selecting an item exposes every serialization-safe top-level field. Nested
tables are shown as JSON, and every displayed field—as well as the item code—has
its own clipboard button.

## Security model

- Lab access is authorized on the server using the player's actual
  `discord:` and `fivem:` identifiers.
- The identifier allowlist never leaves the server.
- Every server callback rechecks authorization independently.
- Created attachment payloads are validated and formatted by the server; the
  client cannot submit raw Lua.
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

## Ped Animation Editor

Open **Developer Tools > Ped Animation Editor**. Choose `mp_m_freemode_01` or
`mp_f_freemode_01`, then a scenario or animation dictionary/clip. The editor
spawns a local, translucent, non-colliding ghost; your player is frozen while
editing. Animation takes priority over scenario when both are supplied.

- **Tab:** switch move/heading gizmos. Drag with the left mouse button; hold Ctrl for precision.
- **Right mouse + WASD:** look and move the camera. Q/E moves down/up; Shift increases speed.
- **Enter:** capture and print the current placement to F8, then move the same ghost to the next seat.
- **G:** print all captured placements as a Lua table. This does not exit the editor.
- **F:** open pose settings to change/replay the animation, resume placement, copy the Lua output, or explicitly exit.

Backspace does not exit this editor. Captures stay in memory until cleared or
exited (maximum 100); print/copy the batch before exiting. No server file is
written. Exported vector4 coordinates are the ped origin, with no automatic
chair-height offset. Animation exports include dictionary, clip and flag;
scenario exports include `useEnterAnim = false`. Match these settings when
replaying placements in your script. Invalid animation dictionaries/clips are
rejected; scenario names should be known GTA scenario types.

The existing Ped Spawner keeps its separate add-ped/save-and-exit workflow.
Restart cleanup deletes the ghost and camera and restores the player's prior
freeze/invincibility state. Automated checks: `lua tests/ped_animation_spec.lua`.
In-game placement and animation alignment still need verification in FiveM.
