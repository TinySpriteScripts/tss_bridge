# TSS Bridge

TSS Bridge exposes explicitly selected, realm-specific modules through a FiveM export. Bridge code and adapter state remain inside `tss_bridge`; consuming resources receive only the public methods they request.

## Setup

Declare the dependency without injecting bridge files:

```lua
-- fxmanifest.lua
dependency 'tss_bridge'

client_scripts { 'client/*.lua' }
server_scripts { 'server/*.lua' }
```

Request modules separately in each realm:

```lua
-- client/main.lua
local TSS = exports.tss_bridge:GetModules({
    'Framework',
    'Player',
    'Notify',
    'Interaction',
})
```

```lua
-- server/main.lua
local TSS = exports.tss_bridge:GetModules({
    'Framework',
    'Player',
    'Banking',
    'Inventory',
    'Notify',
})
```

Module names are case-insensitive and returned under their canonical names. An unknown module, malformed request, or module unavailable in the current realm produces a startup error.

The old `@tss_bridge/starter.lua` injection entry point no longer exists.

### LuaLS autocomplete

The bridge includes documentation types in `shared/types.lua`. Add the realm type
above each module request to get hover documentation, parameter hints, and
completion in Lua Language Server:

```lua
-- client/main.lua
---@type TSSClientModules
local TSS = exports.tss_bridge:GetModules({ 'Notify', 'Interaction' })
```

```lua
-- server/main.lua
---@type TSSServerModules
local TSS = exports.tss_bridge:GetModules({ 'Callbacks', 'Banking', 'Inventory' })
```

Each public function also has an EmmyLua/LuaLS documentation block in its
implementation. The type catalog records the client/server signature differences;
for example, server money mutation methods do not exist on `TSSClientModules`.

## Configuration

Defaults live in `shared/config.lua`:

```lua
TSS.Config.Framework = 'auto'
TSS.Config.Notify = 'auto'
TSS.Config.ProgressBar = 'auto'
TSS.Config.Target = 'auto'
TSS.Config.Inventory = 'auto'
TSS.Config.TextUI = 'auto'
TSS.Config.Interaction = 'auto'
TSS.Config.VehicleKeys = 'auto'
TSS.Config.Fuel = 'auto'
TSS.Config.Locale = 'en'
TSS.Config.CallbackTimeout = 10000
```

Convars override the Lua defaults when set:

```cfg
set tss_framework qb
set tss_notify ox
set tss_progressbar ox
set tss_target qb
set tss_inventory qb
set tss_textui qb
set tss_interaction auto
set tss_vehiclekeys qb
set tss_fuel legacy
set tss_locale en
set tss_callback_timeout 10000
set tss_debug false
```

Common aliases and resource names are accepted, including `qb`, `qb-core`, `qbox`, `qbx_core`, `esx`, `es_extended`, `ox`, and `ox_lib` where relevant.

Authorized Bridge Lab users can also choose the nine adapter defaults from the
in-game **Configuration** menu. The effective priority is:

1. A convar present in `server.cfg` (shown as **Blocked by server.cfg** and not
   editable in the lab).
2. A selection saved through the Bridge Lab.
3. The default in `shared/config.lua`.

Lab selections are persisted in the server resource KVP store and synchronized
to connected clients. Remove the corresponding convar and restart FXServer
before attempting to edit a previously convar-controlled setting.

## Modules by realm

| Module | Client | Server |
| --- | --- | --- |
| `Framework` | Framework detection and current player data | Framework detection and player lookup |
| `Player` | Read-only current player data | Read-only player lookup and permissions |
| `Banking` | Player account reads and provider detection | Player mutations and society accounts |
| `Billing` | Opens the selected billing interface | Unavailable |
| `Inventory` | Read/open operations | Read, mutation, stash and open operations |
| `Notify` | Adapter selection and local notifications | Notifications delivered to a player source |
| `TextUI` | Local show/hide/state | Show/hide for a player source |
| `Callbacks` | Register client callbacks and invoke server callbacks | Register server callbacks and invoke client callbacks |
| `Interaction` | Target or proximity/TextUI interactions | Unavailable |
| `Targets` | Entity, model and zone targets | Unavailable |
| `ProgressBar` | Progress UI | Unavailable |
| `VehicleKeys` | Read-only `Has` | `Has`, `Give`, `Remove` |
| `Fuel` | `Get`, `Set` | Unavailable |
| `UI` | Notify, progress, menu, context and input | Remote notify/progress |
| `Blips`, `Peds`, `Props`, `Vehicles`, `World`, `Gizmo` | Client entity/world and transform-editor helpers | Unavailable |
| `Groups` | Boss-grade lookup | Boss-grade lookup |
| `Locale`, `Capabilities`, `Diagnostics` | Available | Available |
| `Debug` | Debug tools | Secured debug persistence |

Mutation methods are not merely guarded with `IsDuplicityVersion()`; they are absent from client module projections.

## Adding or extending modules

Modules self-register from `modules/<name>/client.lua` and
`modules/<name>/server.lua`. Realm-specific wildcards in `fxmanifest.lua`
discover them automatically, so there is no central client registry, server
registry, or manifest list to update. Server factories are never loaded as
client scripts.

Every module now owns its complete implementation directory. There is no
`shared/modules` implementation tree:

```text
modules/
└── money/
    ├── client.lua  # client API
    ├── server.lua  # server API and authoritative mutations
    └── shared.lua  # read logic genuinely used by both realms
```

Module-specific integrations stay in the same directory as well; for example,
all integrations use `modules/<name>/adapters/`:

```text
modules/
â””â”€â”€ notify/
    â”œâ”€â”€ client.lua
    â”œâ”€â”€ server.lua
    â”œâ”€â”€ shared.lua
    â””â”€â”€ adapters/
        â”œâ”€â”€ ox.lua
        â”œâ”€â”€ qb.lua
        â”œâ”€â”€ qbox.lua
        â””â”€â”€ native.lua
```

Framework, Inventory, Banking, Billing, Groups, Fuel, Notify, ProgressBar, Targets,
Interaction, TextUI and VehicleKeys all share the same adapter registry. The
registry handles aliases, config selection, priority-based auto detection,
availability checks and fallbacks. Public module files only normalize arguments
and expose the stable bridge API; resource-specific exports stay in adapter
files.

An adapter registers itself after the module's `shared.lua` creates its registry:

```lua
-- modules/example/adapters/provider.lua
TSS.Example.RegisterAdapter('provider', 'provider_resource', {
    supports = { read = true },
    read = function(resource, value)
        local ok, result = TSS.CallExport(resource, 'Read', value)
        return ok and result or nil
    end,
}, {
    priority = 20,
    aliases = { 'provider-resource', 'legacy-provider-name' },
})
```

Add that adapter path to the module descriptor's lazy `files` list. There is no
detection switch or central adapter table to edit. `fxmanifest.lua` already
packages every `modules/**/adapters/*.lua` file for clients.

For example, a client module is one file:

```lua
-- modules/example/client.lua
TSSModuleLoader.Define({
    name = 'Example',
    dependencies = { 'Framework' },

    client = function(context)
        local Example = {}

        --- Returns the resource that requested this module.
        ---@return string resource
        function Example.Consumer()
            return context.Caller
        end

        return Example
    end,
})
```

A server implementation lives separately:

```lua
-- modules/example/server.lua
TSSModuleLoader.Define({
    name = 'Example',

    server = function(context)
        local Example = {}

        --- Performs a server-authoritative check.
        ---@param source integer Trusted server player ID.
        ---@return boolean allowed
        function Example.CanUse(source)
            return source > 0 and IsPlayerAceAllowed(source, 'example.use')
        end

        return Example
    end,
})
```

To add a function to an existing module, edit only its `client.lua` or
`server.lua` factory and add the function before returning the public table. A
new one-realm module needs one file; a module available in both realms needs two.
Updating `shared/types.lua` is optional at runtime, but recommended when the new
function should appear in consumer autocomplete.

To add support for another provider, add one adapter file and include it in that
module's descriptor. Existing adapter files and the shared registry do not need
changes.

Descriptor options:

- `dependencies` initializes other modules first without exposing them to the consumer.
- `files` contains implementation files loaded lazily in both realms.
- `clientFiles` and `serverFiles` contain realm-specific lazy implementation files.
- `client` and `server` are independent API factories in their corresponding files.
- `context.Caller` identifies the consuming resource.
- `context.Options` contains the options passed to `GetModules`.
- `context.CopyFunctions` safely copies existing implementation functions.
- `context.OnStop` registers cleanup scoped to the consuming resource.

Factories must return a table containing only named functions. Invalid public
values fail during `GetModules` rather than silently exposing internal state.

## Notify

Supported systems:

1. TSS built-in UI
2. `ox_lib`
3. QB-Core
4. Qbox
5. `okokNotify`
6. `wasabi_notify`
7. `mythic_notify`
8. Native GTA fallback

Auto-detection prefers ox, Qbox, QB-Core, okok, Wasabi, Mythic, TSS, then native.

```lua
-- Client
local TSS = exports.tss_bridge:GetModules({ 'Notify' })

TSS.Notify.Send({
    id = 'item_added',
    title = 'Inventory',
    message = 'Water added',
    type = 'success',
    duration = 5000,
    position = 'top-right',
    icon = 'check',
})

print(TSS.Notify.System())
print(TSS.Notify.Supports('position'))
```

```lua
-- Server
local TSS = exports.tss_bridge:GetModules({ 'Notify' })
TSS.Notify.Send(source, {
    title = 'Inventory',
    message = 'Water added',
    type = 'success',
})
```

The old positional format remains supported:

```lua
TSS.Notify.Send('Inventory', 'Water added', 'success')
TSS.Notify.Send('Inventory', 'Water added', 'success', source, 5000) -- server
```

## Framework, Player, Banking and Billing

Framework adapters support QB-Core, Qbox and ESX.

```lua
local TSS = exports.tss_bridge:GetModules({ 'Framework', 'Player', 'Banking' })

local framework, resource = TSS.Framework.System()
local playerData = TSS.Player.Data(source)
local citizenId = TSS.Player.Identifier(source, 'citizenid')
local job = TSS.Player.Job(source)
local isPolice = TSS.Player.HasGroup(source, { police = 2 })
local cash = TSS.Banking.GetAccount(source, 'cash')
```

Player and society mutations are server-only and validate amounts:

```lua
if TSS.Banking.GetAccount(source, 'cash') >= 500 then
    TSS.Banking.RemoveMoney(source, 'cash', 500, 'shop_purchase')
end

TSS.Banking.AddMoney(source, 'bank', 1000, 'mission_reward')
TSS.Banking.FundSociety('police', 1000, 'job', 'mission_reward')
```

Client player-account calls omit `source`:

```lua
local citizenId = TSS.Player.Identifier('citizenid')
local hunger = TSS.Player.Metadata('hunger')
local cash = TSS.Banking.GetAccount('cash')
```

## Usable inventory items

Register an existing item in **server code** using just the Inventory module:

```lua
local TSS = exports.tss_bridge:GetModules({ 'Inventory' })

local registered, err = TSS.Inventory.CreateUseableItem('gps_beacon', function(source, item)
    TriggerClientEvent('tss-blipcreator:client:OpenMenu', source)
end)

if not registered then error(('GPS registration failed: %s'):format(err)) end
```

`CreateUsableItem` is an alias with the alternate spelling. The item name is
normalized to lowercase. This registers behavior; it does not create an item
definition or remove an item. The callback receives a numeric player source and
an item table with `name`, `metadata`/`info`, plus `slot` and `count`/`amount` when
the provider supplies them. Other provider fields are retained. Callback return
values are forwarded to the provider; their meaning remains provider-specific.

Each item has one bridge consumer owner. A second resource cannot overwrite it;
the same resource can replace its own callback. Stopping the consumer disables
its callbacks and releases ownership. Providers without an unregister API may
retain an inert bridge wrapper. Restart consumers after restarting the bridge,
inventory or framework. Register after those dependencies have started.

`TSS.Inventory.Supports('usable')` reports whether the adapter implements this
feature. Registration still checks the actual framework/provider and can fail.
Registration methods are absent from the client API.

For **OX** (including QB-Core, ESX and Qbox), use a non-consuming item
definition:

```lua
['gps_beacon'] = {
    label = 'GPS Beacon',
    weight = 100,
    stack = false,
    close = true,
    consume = 0,
},
```

`consume = 0` is OX's documented reusable-item setting. For compatibility with
older bridge item definitions, an omitted/false `consume` is changed to `0` in
OX's live server item definition when the callback is registered. Do not also
configure a native client use action or server export for the same item; consuming
items and native server handlers are rejected to avoid duplicate effects. The
bridge uses OX's `usingItem` hook and removes it when the consumer stops.

See [adapter routes and research notes](modules/inventory/USABLE_ITEMS.md) for
all 13 providers, version limitations and source references.

## TextUI and Interaction

TextUI supports ox, QB-Core and a native fallback:

```lua
local TSS = exports.tss_bridge:GetModules({ 'TextUI' })

TSS.TextUI.Show({
    text = '[E] Open shop',
    position = 'right-center',
    icon = 'store',
})

TSS.TextUI.Hide()
```

Interaction chooses the configured target adapter when available and otherwise uses a proximity TextUI prompt:

```lua
local TSS = exports.tss_bridge:GetModules({ 'Interaction' })

local interaction = TSS.Interaction.Create({
    name = 'shop_counter',
    coords = vector3(25.7, -1347.3, 29.5),
    radius = 1.5,
    distance = 2.0,
    label = 'Open shop',
    icon = 'basket-shopping',
    onSelect = function()
        TriggerEvent('my_shop:client:open')
    end,
})

TSS.Interaction.Remove(interaction)
```

It also accepts `entity`, `model`, `event`, `serverEvent`, `command`, `groups`, `items`, `canInteract`, and box-zone dimensions. Server events triggered by an interaction must validate the player and all submitted data.

## Callbacks

Callback names are automatically scoped to the consuming resource.

```lua
-- server/main.lua
local TSS = exports.tss_bridge:GetModules({ 'Callbacks', 'Banking' })

TSS.Callbacks.Register('getBalance', function(source, account)
    -- Validate source and arguments here.
    return TSS.Banking.GetAccount(source, account)
end)
```

```lua
-- client/main.lua
local TSS = exports.tss_bridge:GetModules({ 'Callbacks' })

local balance, err = TSS.Callbacks.Await('getBalance', 5000, 'bank')
if err then print(err) end

TSS.Callbacks.Trigger('getBalance', function(value, callbackError)
    print(value, callbackError)
end, 'cash')
```

Server-to-client callbacks use the mirrored API:

```lua
local result, err = TSS.Callbacks.Await(source, 'clientCheck', 5000, data)
TSS.Callbacks.Trigger(source, 'clientCheck', function(value, callbackError) end, data)
```

Namespacing prevents collisions, not cheating. A client can request any server callback it knows, so every server callback must validate `source`, permissions, ownership, ranges and payload values. Requests are rate-limited and time out automatically.

## Blips

Request `Blips` on the client. Each module instance tracks the handles it creates
and clears them when the consumer stops. `Update` changes only supplied options.

```lua
local TSS = exports.tss_bridge:GetModules({ 'Blips' })
local blip = TSS.Blips.Create({
    coords = vector3(25.7, -1347.3, 29.5),
    label = 'Shop', sprite = 52, colour = 2, display = 2,
})
TSS.Blips.Update(blip, { display = 0 }) -- Hide without replacing the handle.
TSS.Blips.Update(blip, { display = 2, route = true, routeColor = 2 })
local coords = TSS.Blips.Coords(blip)
local colour = TSS.Blips.Colour(blip)
TSS.Blips.Remove(blip)
```

`Exists`, `Update`, `Coords` and `Colour` operate on this module instance's owned
blips. `Clear()` removes all its blips. Options include `hiddenOnLegend`,
`shortRange`, `category`, `scale`, `route` and `routeColor`; false and zero values
are preserved. Creation supports either `coords` or `entity`.

## Gizmo

Request `Gizmo` on the client for a reusable move/rotate editor. It can edit an
entity directly or return raw transform data. Tab changes mode, Enter accepts,
Backspace cancels, Ctrl enables precision, and RMB plus WASD/Q/E controls the
optional detached camera.

```lua
local TSS = exports.tss_bridge:GetModules({ 'Gizmo' })

local started, err = TSS.Gizmo.Start({
    entity = prop,
    space = 'world', -- use 'local' for entity-local axes
    camera = true,
    restoreOnCancel = true,
}, function(result, cancelled)
    if cancelled then return end
    print(json.encode(result)) -- coords, rotation, heading, mode and entity
end)
```

For data without an entity, pass `coords`, `rotation` or `heading`. Use
`GetState()`, `Finish()` and `Stop()` when another UI owns confirmation. Advanced
tools can call `Create()` and describe axis, point and ring handles; the Bridge
Lab uses this route for bone-local attachments and zone resize/radius handles.

## Vehicle keys and fuel

Vehicle keys support `qb-vehiclekeys` and `qbx_vehiclekeys`:

```lua
-- Client, read only
local hasKeys = TSS.VehicleKeys.Has(vehicle)

-- Server
TSS.VehicleKeys.Give(source, plateOrVehicle)
TSS.VehicleKeys.Remove(source, plateOrVehicle)
local hasKeys = TSS.VehicleKeys.Has(source, plateOrVehicle)
```

Fuel supports LegacyFuel, ox_fuel, ps-fuel, cdn-fuel and native fuel levels:

```lua
-- Client only: installed fuel resources own their client-side state.
local fuel = TSS.Fuel.Get(vehicle)
TSS.Fuel.Set(vehicle, 75.0)
```

## Capabilities and diagnostics

```lua
local TSS = exports.tss_bridge:GetModules({ 'Capabilities', 'Diagnostics' })

print(TSS.Capabilities.Module('Banking'))
print(TSS.Capabilities.Resource('ox_lib'))
local snapshot = TSS.Capabilities.Snapshot()
TSS.Diagnostics.Print()
```

The server registers `/tssbridge` automatically. Console use is always allowed; players require:

```cfg
add_ace group.admin tss_bridge.diagnostics allow
```

The report lists available and loaded modules, configured adapters, started resources and server consumers.

## Built-in Bridge Lab

The bridge includes an official, lazily loaded certification lab. Configure
authorized Discord/FiveM identifiers in `bridge_lab/server_config.lua`, restart
the bridge, and use `/bridgelab` or press `F7` in game. Both entry points are
authorized by the server; the allowlist remains server-only and
every lab callback rechecks the player's identifiers.

See `bridge_lab/README.md` for setup, security, and mutation-test details.
The built-in developer tools include a detached-freecam PolyZone Creator, a ped
prop-attachment gizmo editor, a client/server API Explorer, and a read-only
shared inventory item browser. Created zones and prop attachments are saved to
server-validated Lua data files under `bridge_lab/`.

## Localization

English strings live in `shared/locales/en.lua`. Add another file using the same table structure and select it with:

```cfg
set tss_locale fr
```

```lua
local TSS = exports.tss_bridge:GetModules({ 'Locale' })
print(TSS.Locale.T('callback_timeout', 'my_callback'))
```

Missing languages and keys fall back to English.

## Security

- Client module registries never contain Inventory, Banking, or VehicleKeys mutation methods.
- Server APIs require a player source where relevant and do not trust client-provided sources.
- Callback handlers and consuming resource network events must still perform authorization and data validation.
- Debug table saving requires debug mode, rate limiting and the `tss_bridge.debug` ACE permission.
- Per-resource cleanup removes bridge-created entities, targets, interactions and UI ownership when a consuming client resource stops.

```cfg
add_ace group.admin tss_bridge.debug allow
```

## Testing

The loader test exercises both mocked realms and asserts that client projections cannot access server mutation methods:

```powershell
lua tests/module_loader_spec.lua client <resource-path>
lua tests/module_loader_spec.lua server <resource-path>
```

### Per-resource presentation settings

Pass your script's `Config.TSS` as the second argument on both client and server:

```lua
Config.TSS = {
    Target = 'qb',
    Notify = 'qb',
    -- ProgressBar = 'ox',
    -- TextUI = 'ox',
    -- Interaction = 'target', -- target, textui, or auto
}

local TSS = exports.tss_bridge:GetModules({ 'Targets', 'Notify', 'Debug' }, Config.TSS)
TSS.Notify.Send({ message = 'Saved', type = 'success' }) -- client
TSS.Debug.Print('Saved a blip')
```

Only Target, Notify, ProgressBar, TextUI and Interaction accept these overrides.
Inventory, Fuel and other gameplay providers remain bridge-wide. The config key
is `Target` (singular); the imported module is `Targets` (plural).

Selection order: explicit server convar, per-call `adapter` (where supported),
`Config.TSS` supplied at import, bridge config, then automatic detection. Explicit
`auto` requests automatic detection. Missing or unavailable providers retain each
module's normal fallback behavior. Import settings are copied; restart the consumer
after changing its config. They do not modify other resources' choices.

Server provider convars are also replicated by the bridge. Restart the bridge after
changing those convars. `TSS.Debug.Print(...)` uses the bridge's existing debug switch;
use `setr tss_debug true` before startup to enable it on both client and server.

### Menu icons

`UI.Menu` and `UI.Context` options accept existing named icons, Font Awesome Free
class names, or image URLs. Both the option row and selected-item preview display
the same icon. Images preserve their original colours; missing images show a placeholder.
Font Awesome Free is bundled locally (solid, regular and brands; no Pro icons).

```lua
{ label = 'Tools', icon = 'wrench' }
{ label = 'Home', icon = 'fas fa-house' }
{ label = 'My marker', icon = {
    type = 'image',
    src = 'https://cfx-nui-my_resource/images/40.png',
} }
```

A full image URL can also be supplied directly as `icon`. Put local images in the
calling resource and list them in that resource's `files` manifest; no image pack
needs to be installed in the bridge. Blipcreator demonstrates this with its own
`images/blips/<sprite ID>.png` previews. Replace those images to match custom YTDs;
the UI does not read live map textures.

### Commands

Import `Commands` in the realm where the handler should run. Registration uses
FiveM natives, so it works with QBCore, Qbox, ESX, or no framework. Server commands
are automatically supplied to tss-chat's command provider when it is running;
otherwise the default chat receives standard suggestions. Client commands receive
standard suggestions in either chat. No tss-chat dependency or manual registration
is needed, including when tss-chat starts later or restarts.

```lua
-- server.lua in your resource (with dependency 'tss_bridge')
local TSS = exports.tss_bridge:GetModules({ 'Commands', 'Notify' })
local ok, err = TSS.Commands.Register('announce', {
    description = 'Send a server announcement',
    category = 'admin',
    permission = 'my_script.announce',
    arguments = {
        { name = 'message', type = 'rest', help = 'Announcement text' },
    },
}, function(source, args, rawCommand, rawArgs)
    TSS.Notify.Send(-1, { title = 'Announcement', message = args.message })
end)
assert(ok, err)
```

Grant the configured ACE (for example `add_ace group.admin my_script.announce allow`),
or grant `command.announce`. Permission strings are ACE names, not framework job or
group names. A permission array allows any listed ACE. Omit permission (or use false
or `user`) for public commands. Permissions are checked on every execution. Console
source 0 is allowed unless `allowConsole = false`. Register restricted actions server-side;
the client module rejects restricted permission settings.

`arguments` are required unless `optional = true`. Types: string, number, integer,
boolean (`true`/`false`), and rest (remaining text, last argument only). The callback
receives named, converted `args`, plus the untouched command text and positional
`rawArgs`. `options` on an argument supplies autocomplete choices, not validation.
Additional positional arguments remain available in `rawArgs`.

`hidden = true` hides a command; `debugOnly = true` also blocks execution unless bridge
debugging is enabled. `List(source)` returns visible commands owned by the caller.
`Refresh()` refreshes suggestions after permission or debug changes; tss-chat also
rechecks server command visibility whenever it requests its command list.

`Unregister(name)` and `Clear()` disable handlers and remove suggestions. Resource-stop
cleanup runs automatically. Native command wrappers remain inert until the bridge
stops, and can be reused on consumer restart. Another consumer cannot overwrite or
remove your registration. Names already registered outside this module are rejected.
Register again from the consumer's startup after restarting the bridge itself.

## TSS interaction target adapter

Use `tss_interact` as the target provider to route existing bridge target calls to `tss-interactions`:

```lua
local TSS = exports.tss_bridge:GetModules({ 'Targets', 'Interaction' }, {
    Target = 'tss_interact',
    Interaction = 'target',
})

local desk = TSS.Targets.Box({
    name = 'reception_desk',
    coords = vector3(307.2, -595.3, 43.3),
    length = 2.0,
    width = 2.0,
}, {
    {
        label = 'Speak to reception',
        icon = 'fas fa-comment',
        onSelect = function(context)
            print('hello', context.coords)
        end,
    },
}, 2.5)

-- TSS.Targets.RemoveZone(desk)
```

Or select it server-wide with `setr tss_target tss_interact`. Server overrides take precedence over per-resource preferences. Start `tss-interactions` before resources registering these interactions. Restart those consumers after changing providers or restarting `tss-interactions`.

Entity and model calls retain their anchors. Box and circle calls become coordinate points: dimensions, radius, heading, Z bounds and debug-zone settings are ignored. The distance argument controls interaction range (default 2 metres). Removal and consumer-stop cleanup use the existing bridge API.

`onSelect` receives a context table containing `entity`, `coords` and `args`; native `action` callbacks receive `(entity, data)`. Bridge `groups` and `items` filters use the bridge's Player and Inventory providers. Native TSS fields such as `job`, `gang` and `citizenid` remain available and use the interaction resource's player data.

Aliases `tss-interactions` and `tss_interactions` also work. Auto detection prefers existing ox/qb/tgiann/bt providers before TSS so installing this adapter does not change those selections; select `tss_interact` explicitly to use it alongside another target resource.

## Restaurant integration capabilities

Server Inventory also exposes RegisterShop(data), OpenShop(source, id), and
SetMetadata(source, slot, metadata). Shop data contains id, label, items and optional
coords/groups. QB and OX adapters implement these operations; other adapters return
false with unsupported_shop or unsupported_metadata. Supports('shop') and
Supports('metadata') advertise availability on the server. Consumers must validate
shop access and exact bag ownership before calling these methods.

The OX shop adapter accepts both native `count`/`metadata` fields and the shared
QB-style `amount`/`info` aliases without mutating the caller's shop table. OX
metadata updates verify that the requested slot exists before reporting success.
OX stash definitions also forward the optional `instance` restriction.

Server Player.SetDuty(source, boolean) uses QB/Qbox SetJobDuty or ESX tss_duty
metadata. Player.AddNeeds(source, { hunger=delta, thirst=delta, stress=delta }) applies
server-authorized changes, clamped to 0..100 for QB/Qbox; ESX hunger/thirst use
esx_status. These mutation methods are not exposed on the client.

UI.Input fields support type='select', options={ {value='bank', label='Bank'} },
required, min, max and step. Submitted values remain keyed by field name.

Regression checks: lua tests/restaurant_capabilities_spec.lua. Restaurant integration
checks live in tss-restaurant/tests/bridge_spec.lua.

### Dialogue NPC support

Peds.Create and World.CreateDistancePed accept data.custom for freemode head blend,
face sliders, hair, overlays, clothing and props. Custom fields follow the existing
TSS dialogue definitions; custom.randomize randomizes appearance before applying
explicit overrides, and a negative prop index clears that accessory. Unspecified
fields use safe defaults for non-randomized custom peds.

Distance controllers accept options.onDespawn(entity), called before deletion so
consumers can remove targets and close UI. Repeated remove calls are harmless;
peds finishing model loading after cancellation or leaving range are discarded.
Run lua tests/dialogue_peds_spec.lua for mocked appearance/lifecycle checks.

`Inventory.Image(item)` returns an item image URL for QB Inventory and OX Inventory (including custom image filenames), preserves absolute image URLs, and returns `nil` for unknown items or unsupported image providers. OX image URLs respect its `inventory:imagepath` convar, including external CDN paths.

`Peds.LookAt(target, ped?, timeout?)` turns the local player (or supplied ped) toward an entity or coordinates and looks for five seconds. The turn defaults to 1500 ms and yields only when needed. Invalid/despawned entities return `false`. `World.Face` remains a compatible alias.

### Server stash transactions

`Inventory.Stash(id)`, `Inventory.RemoveFromStash(id, item, amount, metadata, slot, reason)` and `Inventory.AddToStash(...)` operate on non-player stashes. These are server-only operations; validate the stash ID and player access in the consuming resource. Check `Supports('stashitems')`, `Supports('stashremove')` and `Supports('stashadd')` first. Unsupported adapters return nil/false explicitly.

Currently implemented for ox_inventory and qb-inventory. QB mutations also persist the live stash through oxmysql because its normal stash save occurs on UI close. Failed persistence is logged. Exact slots and metadata are preserved for refunds.
