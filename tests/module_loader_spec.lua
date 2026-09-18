local realm = assert(arg[1], 'expected client or server realm')
assert(realm == 'client' or realm == 'server', 'expected client or server realm')

local root = assert(arg[2], 'expected resource root')
local manifestFile = assert(io.open(root .. '/fxmanifest.lua', 'rb'))
local manifest = manifestFile:read('*a')
manifestFile:close()
assert(manifest:find("'modules/**/shared.lua'", 1, true),
    'module shared implementations must be included in the client packfile')
assert(manifest:find("'modules/**/adapters/*.lua'", 1, true),
    'module adapters must be included in the client packfile')

local registeredExports = {}
local notifications = {}
local clientEvents = {}
local misalignedExportCalls = 0
local playerData = {
    source = 7,
    citizenid = 'TEST123',
    license = 'license:test',
    charinfo = { firstname = 'Test', lastname = 'Player' },
    job = { name = 'police', grade = { level = 2 } },
    gang = { name = 'none', grade = { level = 0 } },
    metadata = { hunger = 50 },
    money = { cash = 1000, bank = 2500 },
}

local playerObject = {
    PlayerData = playerData,
    Functions = {},
}

function playerObject.Functions.AddMoney(moneyType, amount)
    playerData.money[moneyType] = playerData.money[moneyType] + amount
    return true
end

function playerObject.Functions.RemoveMoney(moneyType, amount)
    if playerData.money[moneyType] < amount then return false end
    playerData.money[moneyType] = playerData.money[moneyType] - amount
    return true
end

function playerObject.Functions.SetMoney(moneyType, amount)
    playerData.money[moneyType] = amount
    return true
end

local qbCore = {
    Shared = { Jobs = {}, Gangs = {} },
    Functions = {
        GetPlayer = function(source) return source == 7 and playerObject or nil end,
        GetPlayerData = function() return playerData end,
    },
}

function qbCore.Functions.Notify(...)
    notifications[#notifications + 1] = { ... }
end

function GetCurrentResourceName()
    return 'tss_bridge'
end

function GetInvokingResource()
    return 'test_resource'
end

function IsDuplicityVersion()
    return realm == 'server'
end

function GetCurrentGameName()
    return 'gta5'
end

function GetConvar(_, default)
    return default
end

function GetResourceState(resource)
    local started = resource == 'qb-core' or resource == 'qb-inventory' or resource == 'qb-vehiclekeys'
        or resource == 'LegacyFuel' or resource == 'test-export'
    return started and 'started' or 'missing'
end

function AddEventHandler() end
function CreateThread() end
function RegisterNUICallback() end
function RegisterNetEvent() end
function RegisterCommand() end
function RegisterKeyMapping() end
function TriggerClientEvent(event, source, ...)
    clientEvents[#clientEvents + 1] = { event = event, source = source, args = { ... } }
end
function TriggerServerEvent() end
function DoesEntityExist(entity) return entity == 10 end
function GetVehicleNumberPlateText() return ' TEST ' end
function GetVehicleFuelLevel() return 30.0 end
function SetVehicleFuelLevel() end

function LoadResourceFile(_, path)
    local file = assert(io.open(root .. '/' .. path, 'rb'))
    local contents = file:read('*a')
    file:close()
    return contents
end

exports = setmetatable({}, {
    __call = function(_, name, callback)
        registeredExports[name] = callback
    end,
    __index = function(_, resource)
        return setmetatable({}, {
            __index = function(_, exportName)
                if resource == 'test-export' and exportName == 'Echo' then
                    return function(proxy, value)
                        if type(proxy) ~= 'table' or value == nil then
                            misalignedExportCalls = misalignedExportCalls + 1
                            error('misaligned export call')
                        end
                        return value
                    end
                end
                if resource == 'qb-core' and exportName == 'GetCoreObject' then
                    return function() return qbCore end
                end
                if resource == 'qb-vehiclekeys' and exportName == 'HasKeys' then
                    return function() return true end
                end
                if resource == 'qb-vehiclekeys' and (exportName == 'GiveKeys' or exportName == 'RemoveKeys') then
                    return function() return true end
                end
                if resource == 'LegacyFuel' and exportName == 'GetFuel' then
                    return function() return 42.0 end
                end
                if resource == 'LegacyFuel' and exportName == 'SetFuel' then
                    return function() return true end
                end
                return function() return {} end
            end,
        })
    end,
})

assert(loadfile(root .. '/shared/config.lua'))()
assert(loadfile(root .. '/shared/helpers.lua'))()
assert(loadfile(root .. '/shared/adapters.lua'))()

TSS.Config.RegistrySpec = 'auto'
local registrySpec = TSS.Adapters.Create('RegistrySpec', { config = 'RegistrySpec', fallback = 'fallback' })
registrySpec:Register('later', 'LegacyFuel', { supports = { read = true } }, { priority = 20, aliases = { 'legacy' } })
registrySpec:Register('first', 'qb-core', { supports = { read = true } }, { priority = 10 })
registrySpec:Register('manual', nil, {}, { priority = 1, auto = false })
registrySpec:Register('fallback', nil, { supports = { safe = true } }, { priority = 1000 })
local registrySystem = registrySpec:Resolve()
assert(registrySystem == 'first', 'registry must choose the lowest-priority available automatic adapter')
assert(registrySpec:Supports('read'))
TSS.Config.RegistrySpec = 'legacy'
assert(registrySpec:Resolve() == 'later', 'registry aliases must resolve to their adapter')
TSS.Config.RegistrySpec = 'missing-adapter'
assert(registrySpec:Resolve() == 'fallback', 'unavailable configured adapters must use the declared fallback')
assert(registrySpec:Supports('safe'))
TSS.Config.RegistrySpec = 'manual'
assert(registrySpec:Resolve() == 'manual', 'manual-only adapters must remain directly selectable')
TSS.Config.RegistrySpec = nil
local callableReference = setmetatable({ __cfx_functionReference = 'test' }, {
    __call = function() return true end,
})
assert(TSS.IsCallable(function() end))
assert(TSS.IsCallable(callableReference))
assert(not TSS.IsCallable({}))
local exportOk, exportValue = TSS.CallExport('test-export', 'Echo', 'aligned')
assert(exportOk and exportValue == 'aligned')
assert(misalignedExportCalls == 0)
assert(loadfile(root .. '/shared/loader.lua'))()
assert(registeredExports.GetModules == nil)

local moduleDescriptors = realm == 'client' and {
    'blips', 'callbacks', 'capabilities', 'debug', 'diagnostics', 'framework', 'fuel',
    'groups', 'interaction', 'inventory', 'locale', 'money', 'notify', 'peds', 'player',
    'progressbar', 'props', 'targets', 'textui', 'ui', 'vehiclekeys', 'vehicles', 'world',
} or {
    'callbacks', 'capabilities', 'debug', 'diagnostics', 'framework', 'groups', 'inventory',
    'locale', 'money', 'notify', 'player', 'textui', 'ui', 'vehiclekeys',
}

for i = 1, #moduleDescriptors do
    assert(loadfile(root .. '/modules/' .. moduleDescriptors[i] .. '/' .. realm .. '.lua'))()
end

assert(loadfile(root .. '/shared/export.lua'))()
local getModules = assert(registeredExports.GetModules)

local function includes(values, expected)
    for i = 1, #values do
        if values[i] == expected then return true end
    end
    return false
end

assert(not includes(TSSModuleLoader.ListLoaded(), 'Inventory'))

local extensionDefinition = { name = 'ExtensionTest' }
extensionDefinition[realm] = function(context)
    return { Realm = function() return context.Realm end }
end
TSSModuleLoader.Define(extensionDefinition)

local extension = getModules({ 'ExtensionTest' }).ExtensionTest
assert(extension.Realm() == realm)

local invalidDefinition = { name = 'InvalidApiTest' }
invalidDefinition[realm] = function() return { Value = true } end
TSSModuleLoader.Define(invalidDefinition)
local invalidApiOk, invalidApiError = pcall(getModules, { 'InvalidApiTest' })
assert(not invalidApiOk)
assert(invalidApiError:find('only contain named functions', 1, true))

local cycleA = { name = 'CycleA', dependencies = { 'CycleB' } }
local cycleB = { name = 'CycleB', dependencies = { 'CycleA' } }
cycleA[realm] = function() return {} end
cycleB[realm] = function() return {} end
TSSModuleLoader.Define(cycleA)
TSSModuleLoader.Define(cycleB)
local cycleOk, cycleError = pcall(getModules, { 'CycleA' })
assert(not cycleOk)
assert(cycleError:find('Circular dependency', 1, true))

local modules = getModules({ 'framework', 'Inventory', 'Inventory' })

assert(modules.Framework)
assert(modules.Inventory)
assert(modules.Banking == nil)
assert(includes(TSSModuleLoader.ListLoaded(), 'Inventory'))
assert(modules.Inventory.System)
assert(modules.Inventory.Utils == nil)

if realm == 'client' then
    assert(modules.Inventory.Open)
    assert(modules.Inventory.Add == nil)
    assert(modules.Inventory.Remove == nil)
    assert(modules.Inventory.RegisterStash == nil)
else
    assert(modules.Inventory.Add)
    assert(modules.Inventory.Remove)
    assert(modules.Inventory.RegisterStash)
end


local expandedNames
if realm == 'client' then
    expandedNames = {
        'Locale', 'Capabilities', 'Diagnostics', 'Player', 'Banking', 'Billing', 'Notify', 'TextUI',
        'Callbacks', 'Interaction', 'VehicleKeys', 'Fuel', 'ProgressBar', 'Blips', 'Peds',
        'Props', 'Vehicles', 'World', 'Groups', 'Targets', 'Debug'
    }
else
    expandedNames = {
        'Locale', 'Capabilities', 'Diagnostics', 'Player', 'Banking', 'Notify', 'TextUI',
        'Callbacks', 'VehicleKeys', 'Groups', 'Debug'
    }
end

local expanded = getModules(expandedNames)
assert(expanded.Locale.T)
assert(expanded.Capabilities.Snapshot)
assert(expanded.Diagnostics.Lines)
assert(expanded.Player.Data)
assert(expanded.Notify.System)
assert(expanded.Notify.Supports)
assert(expanded.TextUI.Show)
assert(expanded.Callbacks.Register)
assert(expanded.Callbacks.Await)
assert(expanded.VehicleKeys.Has)
assert(expanded.Debug.FormatLocationTable)
assert(expanded.Callbacks.Register('callable_reference', callableReference))
if realm == 'client' then
    assert(expanded.Callbacks.Trigger('callable_reference', callableReference))
else
    assert(expanded.Callbacks.Trigger(7, 'callable_reference', callableReference))
end

if realm == 'client' then
    assert(expanded.Banking.GetAccount)
    assert(expanded.Banking.AddMoney == nil)
    assert(expanded.Billing.Open)
    assert(expanded.VehicleKeys.Give == nil)
    assert(expanded.Interaction.Create)
    assert(expanded.Fuel.Set)
    assert(expanded.ProgressBar.Start)
    assert(expanded.ProgressBar.System)
    assert(expanded.Blips.Create)
    assert(expanded.Peds.Create)
    assert(expanded.Props.Create)
    assert(expanded.Vehicles.Create)
    assert(expanded.World.Face)
    assert(expanded.Groups.BossRoles)
    assert(expanded.Targets.System)
    assert(expanded.Targets.CreateZoneAndProps)
    assert(expanded.Groups.ManagementSystem)
    assert(expanded.Groups.IsJobBoss)
    assert(expanded.Groups.IsGangBoss)
    assert(expanded.Groups.OpenBossMenu)
    assert(expanded.Groups.OpenGangMenu)
    assert(expanded.Player.Identifier('citizenid') == 'TEST123')
    assert(expanded.Player.Metadata('hunger') == 50)
    assert(expanded.Player.HasGroup({ police = 2 }))
    assert(expanded.Banking.GetAccount('cash') == 1000)
    assert(expanded.Banking.GetAccount('bank') >= 2000)
    assert(expanded.VehicleKeys.Has(10))
    assert(not expanded.VehicleKeys.Supports('give'))
    assert(not modules.Inventory.Supports('add'))
    assert(expanded.Fuel.Get(10) == 42.0)
    assert(expanded.Notify.System() == 'qb')
    assert(expanded.Notify.Send({ title = 'Test', message = 'Hello', type = 'success' }))
    assert(#notifications == 1)
    assert(expanded.TextUI.Show('[E] Test'))
    assert(expanded.TextUI.IsOpen())
    assert(expanded.TextUI.Hide())
else
    assert(expanded.Banking.AddMoney)
    assert(expanded.Banking.RemoveMoney)
    assert(expanded.VehicleKeys.Give)
    assert(expanded.VehicleKeys.Remove)
    assert(expanded.Player.Identifier(7, 'license') == 'license:test')
    assert(expanded.Player.Name(7) == 'Test Player')
    assert(expanded.Player.HasGroup(7, { police = 2 }))
    assert(expanded.Banking.GetAccount(7, 'cash') == 1000)
    assert(expanded.Banking.AddMoney(7, 'cash', 100, 'test'))
    assert(expanded.Banking.GetAccount(7, 'cash') == 1100)
    assert(expanded.Banking.RemoveMoney(7, 'cash', 100, 'test'))
    assert(expanded.VehicleKeys.Has(7, 'TEST'))
    assert(expanded.VehicleKeys.Give(7, 'TEST'))
    assert(expanded.VehicleKeys.Supports('give'))
    assert(modules.Inventory.Supports('add'))
    assert(expanded.Notify.Send(7, { title = 'Test', message = 'Hello', type = 'success' }))
    assert(clientEvents[#clientEvents].event == 'tss_bridge:client:notify')
    assert(clientEvents[#clientEvents].source == 7)

    local fuelOk, fuelMessage = pcall(getModules, { 'Fuel' })
    assert(not fuelOk)
    assert(fuelMessage:find('not available', 1, true))
end

local ui = getModules({ 'UI' }).UI
assert(ui.Notify)

if realm == 'client' then
    assert(ui.Menu)
    assert(ui.Input)
else
    assert(ui.Menu == nil)
    assert(ui.Input == nil)
end

local unavailable = realm == 'client' and 'not-a-module' or 'ProgressBar'
local ok, message = pcall(getModules, { unavailable })
assert(not ok)
assert(message:find('not available', 1, true))

local malformedOk = pcall(getModules, { [2] = 'Inventory' })
assert(not malformedOk)

print(('module loader %s tests passed'):format(realm))
