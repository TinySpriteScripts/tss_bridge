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

### Automatic version checks

Any resource that calls `exports.tss_bridge:GetModules(...)` is checked once by
the bridge. No version-check module or extra script is required. By default the
bridge reads:

```text
https://github.com/TinySpriteScripts/version_check
```

and requests `<resource-name>-version.txt` from its `main` branch. A version
file contains the latest version, expected resource name, and support link:

```text
1.2.2
tss-comicbook
https://discord.gg/example
```

Third-party resources can select another public repository in their manifest:

```lua
version '1.2.2'
version_check_repo 'https://github.com/example/public-versions'
```

Normal GitHub repository links, GitHub `/tree/<branch>` links, raw HTTPS base
URLs, and direct `.txt` URLs are supported. A direct URL may contain
`{resource}` (or `%s`), which is replaced with the invoking resource name. Repository and
base URLs have `<resource-name>-version.txt` appended. The resource name must
match line two of the version file so renamed installations are reported.

To disable checking for one resource, add:

```lua
suppress_updates 'true'
```

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

Framework, Inventory, Banking, Billing, Groups, Notify, ProgressBar, Targets,
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

Society mutations automatically add provider transaction history when the
selected adapter needs a separate history call. Providers such as QB Banking
and FD Banking already record their own mutations, so the bridge does not add a
duplicate. Pass transaction metadata in place of the reason string when richer
history is useful:

```lua
TSS.Banking.FundSociety('police', 1000, 'job', {
    reason = 'vehicle_sale',
    message = 'Sale of vehicle ABC 123',
    issuer = 'Premium Deluxe Motorsport',
    receiver = 'LSPD',
    source = source,
})
```

Renewed Banking and okokBanking support both explicit transaction recording
and history retrieval. QB Banking supports explicit bank-statement creation,
but does not expose history retrieval. Check the capability before using an
optional operation:

```lua
if TSS.Banking.Supports('transactions') then
    local transactions = TSS.Banking.GetTransactions('police', 25)
end

if TSS.Banking.Supports('recordtransaction') then
    local recorded = TSS.Banking.RecordTransaction('checking', {
        amount = 500,
        type = 'withdraw',
        reason = 'shop_purchase',
        issuer = 'John Doe',
        receiver = '24/7 Supermarket',
        source = source,
        accountType = 'player',
    })
end
```

`RecordTransaction` records history only; it never changes a balance. Do not
call it after a QB/FD society mutation unless a second, intentional record is
required. Returned history uses normalized `account`, `id`, `amount`, `type`,
`reason`, `issuer`, `receiver`, and `time` fields while retaining fields supplied
by the provider. History limits default to 50 and are capped at 200.

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

`CreateUsableItem` is an alias. Item names are lowercased. Registration calls
the selected framework directly: QB-Core's `Functions.CreateUseableItem`,
Qbox's `CreateUseableItem` export, or ESX's `RegisterUsableItem`.

The original callback is passed unchanged. Its arguments, return values,
replacement and lifetime follow the framework. The bridge does not normalize
item data, track ownership, create definitions or consume items. Register after
the framework starts and re-register after restarting it.

`TSS.Inventory.Supports('usable')` reports whether a supported framework is
started on the server. Registration methods are absent from the client API.
The inventory must use the selected framework's usable-item registry;
successful registration alone does not guarantee inventory dispatch.

For OX, the bridge now relies on its framework integration, without installing
`usingItem` hooks or changing item definitions. In the installed OX dispatch,
framework callbacks require `consume` omitted/false and a working
`server.UseItem` integration. `consume = 0` takes the native use path instead.

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
entity directly or return raw transform data. F2 cycles Move, Rotate, and the
combined Move + Rotate layout; F3 switches between world and heading-relative
local movement. Enter accepts, Backspace
cancels, Ctrl enables precision, and RMB plus WASD/Q/E controls the optional
detached camera.

```lua
local TSS = exports.tss_bridge:GetModules({ 'Gizmo' })

local started, err = TSS.Gizmo.Start({
    entity = prop,
    space = 'world', -- use 'local' for entity-local axes
    camera = true,
    restoreOnCancel = true,
}, function(result, cancelled)
    if cancelled then return end
    print(json.encode(result)) -- coords, rotation, heading, mode, space and entity
end)
```

For data without an entity, pass `coords`, `rotation` or `heading`. Use
`GetState()`, `Finish()` and `Stop()` when another UI owns confirmation. Advanced
tools can call `Create()` and describe axis, point and ring handles; the Bridge
Lab uses this route for bone-local attachments and zone resize/radius handles.

## Vehicle keys

Vehicle keys support `qb-vehiclekeys` and `qbx_vehiclekeys`:

```lua
-- Client, read only
local hasKeys = TSS.VehicleKeys.Has(vehicle)

-- Server
TSS.VehicleKeys.Give(source, plateOrVehicle)
TSS.VehicleKeys.Remove(source, plateOrVehicle)
local hasKeys = TSS.VehicleKeys.Has(source, plateOrVehicle)
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

The bridge includes an official, lazily loaded developer lab. Configure
authorized Discord/FiveM identifiers in `bridge_lab/server_config.lua`, restart
the bridge, and use `/bridgelab` or press `F7` in game. Both entry points are
authorized by the server; the allowlist remains server-only and
every lab callback rechecks the player's identifiers.

See `bridge_lab/README.md` for setup, security, and tool details.
The built-in developer tools include a detached-freecam PolyZone Creator, ped
animation, prop-attachment, and multi-prop scene gizmo editors, a client/server
API Explorer, and a read-only shared inventory item browser. Created zones,
attachments, and prop scenes are saved to
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
lua tests/banking_transactions_spec.lua <resource-path>
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
Inventory and other gameplay providers remain bridge-wide. The config key
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

`Inventory.GetSlot(source, slot)`, `Inventory.Find(source, item, metadata)`,
`Inventory.Weight(source)` and `Inventory.MaxWeight(source)` provide normalized,
read-only inspection. Omit `source` on the client. `Find` returns every matching
stack ordered by slot. Weight methods return `nil` when the active provider does
not expose enough information; check `Supports('weight')` or
`Supports('maxweight')` first. Weight values remain in the provider's native
units (normally grams).

Successful server mutations emit the local event
`tss_bridge:server:inventoryAudit`. Its payload includes `action`, `system`,
`resource`, `caller`, `timestamp` and the relevant source/inventory, item,
amount, metadata, slot and reason fields. Actions are `add`, `remove`,
`stash_add`, `stash_remove` and `set_metadata`. The event is server-local and
does not replace authorization in the consuming resource.

`Peds.LookAt(target, ped?, timeout?)` turns the local player (or supplied ped) toward an entity or coordinates and looks for five seconds. The turn defaults to 1500 ms and yields only when needed. Invalid/despawned entities return `false`. `World.Face` remains a compatible alias.

### Server stash transactions

`Inventory.Stash(id)`, `Inventory.RemoveFromStash(id, item, amount, metadata, slot, reason)` and `Inventory.AddToStash(...)` operate on non-player stashes. These are server-only operations; validate the stash ID and player access in the consuming resource. Check `Supports('stashitems')`, `Supports('stashremove')` and `Supports('stashadd')` first. Unsupported adapters return nil/false explicitly.

Currently implemented for ox_inventory and qb-inventory. QB mutations also persist the live stash through oxmysql because its normal stash save occurs on UI close. Failed persistence is logged. Exact slots and metadata are preserved for refunds.


## StreetKings

StreetKings is an additive framework adapter. Existing Qbox, QB and ESX adapters
remain installed and retain their automatic detection priority. StreetKings is
detected when its resource is started; optionally use `setr tss_framework streetkings`.
Start `streetkings`, then `tss_bridge`, then the consuming resources. The bridge
does not have a mandatory StreetKings dependency on other framework servers.

`Framework.System()` returns `streetkings`. On the server, `Player.Data`, `Name`,
`Identifier`, `Metadata` and `IsLoaded` use the active save. Metadata contains
progression, stats and gameState. `Banking.GetAccount(source, 'cash')`, `AddMoney`
and `RemoveMoney` use StreetKings cash exports. Bank/crypto/society accounts,
jobs, gangs, duty, needs, inventory and vehicle-key ownership are not supplied
by StreetKings. Existing independently installed providers remain available.

StreetKings does not export client save documents or active save IDs. Normalized
client player data is therefore nil and client cash reads return zero. Server
`identifier`/`license` identify the account, not the save slot; no citizenid is
fabricated. For per-save progress, use `StreetKings.ReadSaveData/WriteSaveData`
rather than account identifiers. `Framework.Object()` is nil; `Framework.Player()`
is a snapshot, not a mutable QB/ESX player object.

Notifications automatically use StreetKings toasts while StreetKings is available.
Provider overrides still apply, e.g. `setr tss_notify ox` or `streetkings`.

Request the dedicated realm-specific module for native gameplay features:

```lua
local TSS = exports.tss_bridge:GetModules({ 'StreetKings', 'Banking', 'Player' })
-- server
if TSS.StreetKings.HasActiveSave(source) then
    local found = TSS.StreetKings.ReadSaveData(source, 'myScript.found') or {}
    -- Validate actions and rewards on the server before writing progress.
    TSS.StreetKings.WriteSaveData(source, 'myScript.found', found)
end
```

```lua
local TSS = exports.tss_bridge:GetModules({ 'StreetKings', 'Notify' })
-- client
if TSS.StreetKings.IsAvailable() and TSS.StreetKings.GetGameState() == 'freeroam' then
    TSS.Notify.Send({ title = 'Challenge', message = 'Ready to start' })
end
```

The module preserves native argument signatures and all return values, including
false and nil. It exposes only the native exports listed below in their original
realm, plus `IsAvailable()` in both realms and client `CheckpointCleared()` for
the native nitrous checkpoint event. Calls fail with a descriptive error when
StreetKings is unavailable or an export fails. No client network event for save
writes, rewards or arbitrary export invocation is introduced.

`tss_carcollectibles` and `tss_speedzones` now request this module and declare a
bridge dependency; their gameplay, validation and reward rules are unchanged.
They remain StreetKings gameplay resources, not generic RP scripts.

### Native API inventory

**Client**

`AllowLeaveVehicle`, `ClosePhone`, `CreateWaypoint`, `DisableChaseCam`, `EnableChaseCam`, `GetAllVehicleData`, `GetCurrentTime`, `GetCurrentTrack`, `GetCurrentWeather`, `GetGameState`, `GetPlayerVehicle`, `GetVehicleAvailability`, `GetVehicleData`, `GetWantedLevel`, `IsChaseCamEnabled`, `IsCinematicMode`, `IsInFreeroam`, `IsNearPolice`, `IsPhoneOpen`, `IsPlayerWasted`, `IsPoliceChasing`, `IsRaceEditorFreecamEnabled`, `LoadAnimDict`, `LoadAnimSet`, `LoadModel`, `LoadPtfxAsset`, `OpenPhone`, `RaceEditorFreecamRaycast`, `RegisterGameState`, `RemoveAllWaypoints`, `RemoveWaypoint`, `SetCinematicMode`, `SetGameState`, `SetSoundtrackEnabled`, `SetSpeedometerEnabled`, `SetupTestJump`, `ShowNotification`, `StartRaceEditorFreecam`, `StopRaceEditorFreecam`, `TeardownTestJump`, `UnloadModel`, `WarpPlayer`, `WarpToWaypoint`, `awaitDebugToolsPermission`.

**Server**

`AddPlayerCash`, `AwardPlayerXp`, `AwardVehicleXp`, `BroadcastPhoneMessage`, `CreateServerWaypoint`, `GetActiveVehicle`, `GetOwnedVehicles`, `GetPlayerCash`, `GetPlayerGameState`, `GetPlayerLevel`, `GetServerWaypoints`, `HasActiveSave`, `IncrementStat`, `IsPlayerInHangoutZone`, `PersistSave`, `ReadSaveData`, `RecordActivityBest`, `RegisterStat`, `RemovePlayerCash`, `RemoveServerWaypoint`, `SendPhoneMessage`, `SetStatMax`, `SetTime`, `SetWeather`, `WriteSaveData`.

