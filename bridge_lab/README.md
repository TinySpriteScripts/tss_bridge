# TSS Bridge Lab

The Bridge Lab is an authorization-gated development suite built directly
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
client-side tool commands; all actions are selected
from the authorized menu.

## Lab interface

The landing menu separates bridge configuration, focused tests, and developer tooling:

- **Configuration** edits the exposed notification, progress, TextUI, and
  interaction defaults. Any
  option with a matching `server.cfg` convar is read-only and displays
  **Blocked by server.cfg**.
- **Test Centre** contains focused UI/feedback checks and practical vehicle
  tools for spawning vehicles, granting keys, and cleanup.
- **Developer Tools** contains the PolyZone, ped-animation, prop-scene, and
  prop-attachment editors alongside the API Explorer and shared-item browser.

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
`bridge_lab/exported_data/created_zones.lua`. Clients never provide raw Lua source. The output
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
- `F2` cycles move axes, three-axis rotation rings, and a combined layout.
- Left-drag a colored gizmo, and hold `Ctrl` for precision adjustments.
- Hold right mouse to look around. `WASD` moves the camera and `Q`/`E` moves it
  vertically.
- Enter saves; Backspace deletes the draft.

The server validates the model, bone, offsets, rotations, optional animation,
authorization, file size, and save rate before appending data to
`bridge_lab/exported_data/created_prop_attatchments.lua`. The filename retains the requested
`attatchments` spelling. It is a data file and is not loaded automatically.

## Prop Scene Editor

Open **Developer Tools → Prop Scene Editor**, name the scene, and enter its first
prop model. The editor keeps every prop visible while one active prop is edited.

- **F2** cycles Move, Rotate, Scale, and a combined layout. Rotation and scale
  expose independent red X, green Y, and blue Z handles.
- **F3** switches world/local axes. Left/Right selects the previous/next prop,
  **G** duplicates the active prop, and **F** opens the scene manager.
- Click a placed prop to select it again. The Position, Rotation, and Scale cards
  on the right are clickable and accept exact X/Y/Z values.
- **Ctrl+Z** undoes and **Ctrl+Y** redoes transformations, additions, duplicates,
  deletions, and direct value edits. The editor retains up to 100 scene states.
- **F5** opens the categorized prop library along the bottom of the screen.
  Search or filter the catalog, click a card to add it beside the selected prop,
  or drag it onto visible world geometry to place it at the drop point. Extend
  the curated catalog in `bridge_lab/data/prop_library.lua`.
- The manager can add a different model, select, duplicate, or delete props,
  resume editing, generate copyable Lua, or save the complete scene.
- Hold right mouse to look around; use `WASD`, `Q`/`E`, Shift, the mouse wheel,
  and Ctrl for freecam movement and precision editing.

Saved scenes are server-validated and appended to
`bridge_lab/exported_data/created_prop_scenes.lua` as model, position, full
rotation, and three-axis scale records. GTA V has no true object-scale native,
so the editor previews scale through `SetEntityMatrix`. This changes the visible
model but does not resize its collision bounds; scene scripts should reproduce
the same matrix scaling when spawning exported props.

## Bridge API Explorer

The API Explorer parses `shared/types.lua`, the bridge's existing public type
source, whenever it opens. It groups functions by module, identifies client and
server availability independently, and shows exact parameter and return
signatures. Searches match both module and function names. Function names,
example calls, and `GetModules` imports can be copied directly.

Keeping the public annotations in `shared/types.lua` current automatically keeps
the explorer current; there is no separate API catalogue to maintain.

## Inventory Item Browser

The Item Browser uses `Inventory.Items()` on the client to display the active
inventory adapter/resource, search the shared item-definition table by code or
label, and try the adapter resource's common image directories. It never calls
`Inventory.Player()` or reads a player's inventory.

Selecting an item exposes every serialization-safe top-level field. Nested
tables are shown as JSON, and every displayed field—as well as the item code—has
its own clipboard button. Authorized users can also spawn one copy of the
selected item. The server rechecks Bridge Lab authorization, resolves the item
against its own item registry, checks carry capacity, rate-limits grants, and
always grants to the requesting player rather than a client-supplied target.

## Security model

- Lab access is authorized on the server using the player's actual
  `discord:` and `fivem:` identifiers.
- The identifier allowlist never leaves the server.
- Every server callback rechecks authorization independently.
- Item Browser grants are validated against the server's item registry, fixed
  to one item, carry-checked, rate-limited, and restricted to the requester.
- Created attachment payloads are validated and formatted by the server; the
  client cannot submit raw Lua.
- Vehicle-key grants validate network ownership before changing key state.
- Client-created entities and UI are cleaned when the
  bridge stops.

A client can execute arbitrary local code and display local UI, so the server
authorization checks—not the menu event—are the security boundary.

## What it exercises

The Test Centre covers notifications, TextUI, progress, callbacks, built-in UI,
vehicle spawning, and vehicle keys. The creation tools cover
zones, animation placements, prop scenes, and prop attachments.

Shared visual/entity settings are in `config.lua`. Sensitive settings and
identifier allowlists belong only in `server_config.lua`.

## Ped Animation Editor

Open **Developer Tools > Ped Animation Editor**. Choose `mp_m_freemode_01` or
`mp_f_freemode_01`, then a scenario or animation dictionary/clip. The editor
spawns a local, translucent, non-colliding ghost; your player is frozen while
editing. Animation takes priority over scenario when both are supplied.
Animation dictionary fields search anywhere within names in `data/animlist.lua`
as you type. Selecting an exact dictionary changes the clip field into a
dropdown of its known clips.

- **F2:** cycle Move, Rotate, and Combined gizmos. Rotate exposes red X, green Y, and blue Z rings. **F3:** switch world/local axes. Drag with the left mouse button; hold Ctrl for precision.
- **Right mouse + WASD:** look and move the camera. Q/E moves down/up; Shift increases speed.
- **G:** commit the current ped in place and create another editable ghost with the same pose. Committed peds remain visible so completed seats and beds are easy to track.
- **F:** open pose settings to change/replay the current ghost, resume placement, print/copy the committed Lua, clear committed peds, save the batch to a file, or explicitly exit.

Backspace does not exit this editor. Up to 100 committed placements stay visible
until cleared, saved, or exited. **Save file** appends the server-validated batch
to `bridge_lab/exported_data/created_ped_animation.lua`; the client never sends
raw Lua source. Exported vector4 coordinates are the ped origin, with no
automatic chair-height offset. A separate `rotation = vector3(x, y, z)` preserves
all three authored axes. Animation exports include dictionary, clip and flag;
scenario exports include `useEnterAnim = false`. Match these settings when
replaying placements in your script. Invalid animation dictionaries/clips are
rejected; scenario names should be known GTA scenario types.

Ped placement, prop attachment, and box/circle zone editing all use the public
client `Gizmo` module. Other resources can request it with
`exports.tss_bridge:GetModules({ 'Gizmo' })`; see the root README for the simple
entity/transform API and the advanced custom-handle API.

All active Bridge Lab-generated Lua data lives under `bridge_lab/exported_data/`.
Restart cleanup deletes the ghost and camera and restores the player's prior
freeze/invincibility state.
