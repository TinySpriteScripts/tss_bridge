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
    'Money',
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
local TSS = exports.tss_bridge:GetModules({ 'Callbacks', 'Money', 'Inventory' })
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
| `Money` | `Balance`, `Has` | `Balance`, `Has`, `Add`, `Remove`, `Set` |
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
| `Blips`, `Peds`, `Props`, `Vehicles`, `World` | Client entity/world helpers | Unavailable |
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

Framework, Inventory, Money, Groups, Fuel, Notify, ProgressBar, Targets,
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

## Framework, Player and Money

Framework adapters support QB-Core, Qbox and ESX.

```lua
local TSS = exports.tss_bridge:GetModules({ 'Framework', 'Player', 'Money' })

local framework, resource = TSS.Framework.System()
local playerData = TSS.Player.Data(source)
local citizenId = TSS.Player.Identifier(source, 'citizenid')
local job = TSS.Player.Job(source)
local isPolice = TSS.Player.HasGroup(source, { police = 2 })
local cash = TSS.Money.Balance(source, 'cash')
```

Money mutations are server-only and validate sources and amounts:

```lua
if TSS.Money.Has(source, 'cash', 500) then
    TSS.Money.Remove(source, 'cash', 500, 'shop_purchase')
end

TSS.Money.Add(source, 'bank', 1000, 'mission_reward')
```

Client Player and Money calls omit `source`:

```lua
local citizenId = TSS.Player.Identifier('citizenid')
local hunger = TSS.Player.Metadata('hunger')
local cash = TSS.Money.Balance('cash')
```

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
local TSS = exports.tss_bridge:GetModules({ 'Callbacks', 'Money' })

TSS.Callbacks.Register('getBalance', function(source, account)
    -- Validate source and arguments here.
    return TSS.Money.Balance(source, account)
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

print(TSS.Capabilities.Module('Money'))
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

- Client module registries never contain Inventory, Money, or VehicleKeys mutation methods.
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
