-- Run from tss_bridge: lua tests/inventory_usable_spec.lua
local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end

local function environment(realm, inventory, framework)
    TSS, TSSModuleLoader = nil, nil
    local state = { caller = 'consumer_a', events = {}, calls = {}, providers = {}, warnings = {} }
    function GetCurrentResourceName() return 'tss_bridge' end
    function GetInvokingResource() return state.caller end
    function IsDuplicityVersion() return realm == 'server' end
    function GetCurrentGameName() return 'gta5' end
    function GetConvar(_, default) return default end
    function AddEventHandler(name, callback)
        state.events[name] = state.events[name] or {}
        table.insert(state.events[name], callback)
    end
    RegisterNetEvent = AddEventHandler
    function LoadResourceFile(_, path)
        local f = assert(io.open(path, 'r')); local text = f:read('*a'); f:close(); return text
    end
    function GetResourceState(resource)
        return state.started[resource] and 'started' or 'missing'
    end
    local function register(provider, name, handler)
        state.calls[#state.calls + 1] = { provider, name }
        if state.fail == 'throw' then error('provider failure') end
        if state.fail == 'false' then return false end
        state.providers[name] = handler
        return nil -- real framework registration often returns no value
    end
    local qb = { Functions = { CreateUseableItem = function(name, handler) return register('qb', name, handler) end } }
    local esx = { RegisterUsableItem = function(name, handler) return register('esx', name, handler) end }
    exports = setmetatable({}, { __index = function(_, resource)
        return setmetatable({}, { __index = function(_, method)
            return function(self, ...)
                check(type(self) == 'table', 'export called without proxy self')
                if method == 'GetCoreObject' then return qb end
                if method == 'getSharedObject' then return esx end
                if method == 'Items' then return state.definition end
                local expected = state.exportNames[resource]
                check(method == expected, 'wrong registration export: ' .. resource .. ':' .. method)
                return register(resource .. ':' .. method, ...)
            end
        end })
    end })
    dofile('shared/config.lua')
    TSS.Config.Inventory, TSS.Config.Framework = inventory, framework
    local resources = {
        ox = 'ox_inventory', qb = 'qb-inventory', ps = 'ps-inventory', lj = 'lj-inventory',
        qs = 'qs-inventory', core = 'core_inventory', codem = 'codem-inventory', origen = 'origen_inventory',
        tgiann = 'tgiann-inventory', ak47 = 'ak47_inventory', mf = 'mf-inventory', tss = 'tss-inventory', chezza = 'inventory',
    }
    local frameworkResource = ({qb='qb-core',qbox='qbx_core',esx='es_extended'})[framework]
    state.started = { [resources[inventory]] = true }
    if frameworkResource then state.started[frameworkResource] = true end
    state.exportNames = {
        ['ps-inventory']='CreateUsableItem', ['lj-inventory']='CreateUsableItem', ['qs-inventory']='CreateUsableItem',
        ['origen_inventory']='CreateUseableItem', ['tss-inventory']='CreateUseableItem', ['qbx_core']='CreateUseableItem',
    }
    state.definition = {name='gps_beacon'}
    dofile('shared/helpers.lua')
    TSS.Warn = function(message) state.warnings[#state.warnings + 1] = message end
    dofile('shared/adapters.lua')
    dofile('shared/loader.lua')
    dofile('modules/framework/' .. realm .. '.lua')
    dofile('modules/inventory/' .. realm .. '.lua')
    local inv = TSSModuleLoader.GetModules({'Inventory'}).Inventory
    return state, inv
end

local cases = {
    {'qb','qb','qb'}, {'ps','qb','ps-inventory:CreateUsableItem'}, {'lj','qb','lj-inventory:CreateUsableItem'},
    {'qs','esx','qs-inventory:CreateUsableItem'}, {'origen','qb','origen_inventory:CreateUseableItem'},
    {'tss','qb','tss-inventory:CreateUseableItem'}, {'codem','qb','qb'}, {'codem','esx','esx'},
    {'core','qb','qb'}, {'core','esx','esx'}, {'core','qbox','qbx_core:CreateUseableItem'},
    {'tgiann','qb','qb'}, {'tgiann','esx','esx'}, {'tgiann','qbox','qbx_core:CreateUseableItem'},
    {'ak47','qb','qb'}, {'ak47','esx','esx'}, {'mf','esx','esx'}, {'chezza','esx','esx'},
    {'ox','esx','esx'}, {'ox','qbox','qbx_core:CreateUseableItem'},
}
for _, case in ipairs(cases) do
    local state, inv = environment('server', case[1], case[2])
    check(inv.Supports('usable'), 'missing server capability: ' .. case[1])
    check(inv.CreateUsableItem == inv.CreateUseableItem, 'spelling alias differs')
    local received, uses = nil, 0
    local consumerCallback = setmetatable({}, { __call = function(_, source, item, extra)
        received = {source, item, extra}; uses = uses + 1; return 'handled'
    end })
    check(inv.CreateUseableItem('gps_beacon', consumerCallback), 'registration failed: ' .. case[1])
    check(state.calls[1][1] == case[3], 'wrong provider: ' .. case[1])
    local bound = state.providers.gps_beacon
    local raw = {name='gps_beacon',slot=4,amount=2,info={serial='A'}}
    if case[1] == 'mf' then
        local remove = function() end
        check(bound('7', remove, raw) == 'handled', 'MF return value lost')
        check(received[3] == remove, 'MF removal callback lost')
    elseif case[2] == 'esx' and case[1] ~= 'qs' then
        check(bound('7','gps_beacon',raw) == 'handled', 'ESX return value lost')
    else
        check(bound('7',raw) == 'handled', 'callback return value lost')
    end
    check(received[1] == 7 and received[2].slot == 4, 'source/slot not normalized')
    check(received[2].metadata.serial == 'A' and received[2].count == 2, 'metadata/count not normalized')
    check(raw.metadata == nil, 'provider item mutated')
    check(bound(-1,raw) == false and uses == 1, 'invalid source dispatched')
    state.caller = 'consumer_b'
    local other = TSSModuleLoader.GetModules({'Inventory'}).Inventory
    local ok, err = other.CreateUseableItem('gps_beacon', function() end)
    check(not ok and err == 'item_already_registered_by:consumer_a', 'ownership collision not rejected')
    check(#state.calls == 1, 'collision overwrote provider')
    state.fail = 'false'
    check(not inv.CreateUseableItem('gps_beacon', function() error('replacement') end), 'false treated as success')
    check(bound(7,raw) == 'handled', 'failed replacement lost original callback')
    state.fail = nil
    check(inv.CreateUseableItem('gps_beacon', function() return 'new' end), 'replacement failed')
    check(bound(7,raw) == false, 'superseded callback still active')
    local replacement = state.providers.gps_beacon
    for _, cleanup in ipairs(state.events.onResourceStop or {}) do cleanup('consumer_a') end
    check(replacement(7,raw) == false, 'stopped consumer still active')
    check(not inv.CreateUseableItem('another', function() end), 'stopped module allowed registration')
    check(other.CreateUseableItem('gps_beacon', function() return true end), 'new owner cannot register after cleanup')
end

for _, case in ipairs(cases) do
    local _, inv = environment('client',case[1],case[2])
    check(inv.CreateUseableItem == nil and inv.CreateUsableItem == nil, 'server API exposed on client')
    check(not inv.Supports('usable') and not inv.Supports('useable'), 'client claims registration support')
end

local state, inv = environment('server','tss','qb')
check(not inv.CreateUseableItem('',function() end), 'empty name accepted')
check(not inv.CreateUseableItem('bad item',function() end), 'whitespace name accepted')
check(not inv.CreateUseableItem('gps_beacon',{}), 'uncallable callback accepted')
check(#state.calls == 0, 'invalid request reached provider')
state.fail = 'throw'
local ok, err = inv.CreateUseableItem('gps_beacon',function() end)
check(not ok and err:find('provider failure',1,true), 'provider error lost')
check(#state.calls == 1, 'failed export retried')
state.fail = nil
check(inv.CreateUseableItem('gps_beacon', function() error('consumer failed') end), 'registration after failure failed')
check(state.providers.gps_beacon(7,{}) == false and #state.warnings == 1, 'callback error escaped')

for _, framework in ipairs({'qb','none'}) do
    local _, ox = environment('server','ox',framework)
    local success, reason = ox.CreateUseableItem('gps_beacon',function() end)
    check(not success and reason == 'unsupported_inventory_framework', 'stock OX accepted unsupported framework')
end
state, inv = environment('server','ox','qbox')
state.definition.consume = 0
ok, err = inv.CreateUseableItem('gps_beacon',function() end)
check(not ok and err:find('ox_item_uses_native_handler',1,true), 'OX consume conflict not detected')
state.definition = nil
ok, err = inv.CreateUseableItem('missing',function() end)
check(not ok and err == 'item_not_defined', 'OX missing item accepted')

state, inv = environment('server','tss','qb')
check(inv.CreateUseableItem('GPS_BEACON',function() return false, 'custom rejection' end), 'uppercase registration failed')
check(state.providers.gps_beacon ~= nil, 'item name not canonicalized')
local accepted, message = state.providers.gps_beacon(7,{})
check(accepted == false and message == 'custom rejection', 'multiple callback return values lost')
state.caller = 'consumer_b'
local other = TSSModuleLoader.GetModules({'Inventory'}).Inventory
check(not other.CreateUseableItem('gps_beacon',function() end), 'case variant bypassed ownership')

-- Exercise the actual consumer file against the new API, not a duplicated example.
state, inv = environment('server','qb','qb')
local sent
Config = {Options={BlipItem='gps_beacon'}}
function TriggerClientEvent(...) sent=table.pack(...) end
exports.tss_bridge = {GetModules=function() return {Inventory=inv} end}
local consumerEnv = setmetatable({}, {__index=_G})
assert(loadfile('../../[tss_free]/tss-blipcreator/server/bridge.lua', 't', consumerEnv))()
state.providers.gps_beacon(7,{name='gps_beacon'})
check(sent[1] == 'tss-blipcreator:client:OpenMenu' and sent[2] == 7, 'GPS did not open menu')
print(('PASS: %d checks; 13 adapters, framework routes, callback normalization, ownership, cleanup, failures, client isolation and GPS integration'):format(checks))
