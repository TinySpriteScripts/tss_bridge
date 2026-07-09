# TSS Bridge





### commands

/tsschairdebug




Shared helper bridge for TinySprite scripts.

Add it to a resource like this:

```lua
dependency 'tss_bridge'

shared_scripts {
    '@tss_bridge/starter.lua',
}
```

Then call helpers directly:

```lua
local ok = progressBar({
    label = 'Searching...',
    time = 5000,
    dict = 'amb@prop_human_bum_bin@base',
    anim = 'base',
})

local blip = createBlip({
    coords = vector3(123.0, 456.0, 78.0),
    name = 'Shop',
    sprite = 52,
    color = 2,
})

local ped = createPed('a_m_m_business_01', vector4(123.0, 456.0, 78.0, 90.0))
local prop = createProp('prop_tool_box_04', vector4(123.0, 456.0, 78.0, 90.0), { freeze = true })
local veh = createVeh('sultan', vector4(123.0, 456.0, 78.0, 90.0))
notifyPlayer(nil, 'Done', 'success')
faceCoords(vector3(123.0, 456.0, 78.0))
```

Namespaced calls are also available:

```lua
TSS.ProgressBar(data)
TSS.CreateBlip(data)
TSS.CreatePed(data)
TSS.CreateProp(data)
TSS.CreateVehicle(data)
TSS.Target.Entity(entity, options, distance)
TSS.Target.Box(data, options, distance)
TSS.Inventory.Add(source, item, amount, metadata)
TSS.Inventory.Has(source, item, amount)
TSS.Notify.Send(title, message, type, source)
TSS.Groups.BossRoles(jobOrGang)
```

Progress bar selection is automatic by default:

- `ox_lib`
- `progressbar` with `qb-core`
- native fallback

You can force one with a convar:

```cfg
set tss_progressbar ox
set tss_target ox
set tss_inventory ox
set tss_debug true
```

Debug helpers:

```lua
setDebug(true)
debugPrint('message')
debugPoly(Config.Debug)
```

`set tss_debug true` enables bridge debug prints, bridge-created target zone debug outlines, and debug tools.

Common migration names:

```lua
resourceName()                         -- current resource name
getBossRoles('police')                 -- boss grade map for target jobs/gangs
notifyPlayer(nil, 'Message', 'error')  -- client notify
notifyPlayer(nil, 'Message', 'error', source) -- server notify
faceCoords(coords)                     -- turn player toward coords/entity
createDistanceProp(data, options)      -- spawn prop only near player
createDistancePed(data, coords, options) -- spawn ped only near player
```

For older TinySprite scripts moving away from `jim_bridge`, use:

```lua
makeBlip(...)      -> createBlip(...)
makeBossRoles(...) -> getBossRoles(...)
triggerNotify(...) -> notifyPlayer(...)
lookEnt(...)       -> faceCoords(...)
makeDistProp(...)  -> createDistanceProp(...)
makeDistPed(...)   -> createDistancePed(...)
MakeStash(...)     -> createStash(...)
getPlayerInv(...)  -> getPlayerInventory(...)
getScript()        -> resourceName()
```

Chair placement helper:

```text
/tsschairdebug
/tsslocdebug [chairs|washhands|poles|payments|shop|stash|publicstash|playerstash|crafting|bossmenus|outfit]
```

Controls:

```text
Chairs use the seated ghost ped preview
Other tables use an editable target box/polyzone preview
Position mode: W/S forward, A/D side
Zone size mode: W/S length, A/D width
Rotation mode: A/D rotate, W/S red local axis
Mouse wheel move height or heading based on mode
LShift switch mode
Z toggle player movement for setting chair stand positions
E save current point or zone
ESC/Backspace return to the table menu
Choose Save File from the table menu to save all created tables to one file in `tss_bridge/debug/`
```

Target systems auto-detect in this order:

- `ox_target`
- `qb-target`
- `tgiann-target`
- `bt-target`

Direct helper names are also available:

```lua
createEntityTarget(entity, options, 2.0)
createModelTarget({ `prop_atm_01` }, options, 2.0)
createBoxTarget({ 'zone_name', coords, length, width, zoneOptions }, options, 2.0)
createCircleTarget({ 'zone_name', coords, radius, zoneOptions }, options, 2.0)
removeEntityTarget(entity)
removeModelTarget(models)
removeZoneTarget(zone)
```

Inventory systems auto-detect in this order:

- `ox_inventory`
- `qb-inventory`
- `ps-inventory`
- `lj-inventory`
- `qs-inventory`
- `core_inventory`
- `codem-inventory`
- `origen_inventory`
- `tgiann-inventory`
- `ak47_inventory`
- `mf-inventory`
- `tss-inventory`
- `inventory`

Inventory adapters live in:

```text
shared/inventory/ox_inventory.lua
shared/inventory/qb-inventory.lua
shared/inventory/ps-inventory.lua
shared/inventory/lj-inventory.lua
shared/inventory/qs-inventory.lua
shared/inventory/core_inventory.lua
shared/inventory/codem-inventory.lua
shared/inventory/origen_inventory.lua
shared/inventory/tgiann-inventory.lua
shared/inventory/ak47_inventory.lua
shared/inventory/mf-inventory.lua
shared/inventory/tss-inventory.lua
shared/inventory/inventory.lua
```

`shared/modules/inventory.lua` is only the router and public API.

Inventory helpers:

```lua
addItem(source, 'water', 1)
removeItem(source, 'water', 1)
hasItem(source, 'water', 1)
canCarryItem(source, 'water', 1)
getItemCount(source, 'water')
getPlayerInventory(source)
createStash({ id = 'shop_storage', label = 'Storage', slots = 50, weight = 100000 })
openStash(source, 'shop_storage')
```
