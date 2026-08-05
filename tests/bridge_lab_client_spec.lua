local root = assert(arg[1], 'expected resource root')
local events = {}
local moduleRequests = 0
local menusOpened = 0
local menus = {}
local callbackRegistered = false
local commands = {}
local keyMapping
local serverRequests = 0

TSS = { Config = {
    Framework = 'auto', Notify = 'ox', ProgressBar = 'auto', Target = 'auto',
    Inventory = 'auto', TextUI = 'auto', Interaction = 'auto',
    VehicleKeys = 'auto', Fuel = 'auto',
} }
TSSBridgeLabConfig = {}
TSSBridgeLabPolyZoneCreator = {
    Start = function() return true end,
}

function RegisterNetEvent(name, callback)
    events[name] = callback
end

function AddEventHandler() end
function RegisterCommand(name, callback)
    commands[name] = callback
end
function RegisterKeyMapping(command, description, device, key)
    keyMapping = { command, description, device, key }
end
function TriggerServerEvent(event)
    assert(event == 'tss_bridge:lab:requestOpen')
    serverRequests = serverRequests + 1
end

local modules = {
    Callbacks = {
        Register = function(name)
            assert(name == 'clientSnapshot')
            callbackRegistered = true
            return true
        end,
    },
    UI = {
        Menu = function(data, callback)
            assert(type(data) == 'table')
            menusOpened = menusOpened + 1
            menus[menusOpened] = { data = data, callback = callback }
            return 1
        end,
    },
}

exports = {
    tss_bridge = {
        GetModules = function(_, requested)
            assert(type(requested) == 'table' and #requested == 23)
            moduleRequests = moduleRequests + 1
            return modules
        end,
    },
}

assert(loadfile(root .. '/bridge_lab/client/main.lua'))()
assert(moduleRequests == 0)
assert(type(commands['+tss_bridge_lab']) == 'function')
assert(type(commands['-tss_bridge_lab']) == 'function')
assert(keyMapping[1] == '+tss_bridge_lab')
assert(keyMapping[3] == 'keyboard' and keyMapping[4] == 'F7')
assert(type(events['tss_bridge:lab:open']) == 'function')
assert(type(events['tss_bridge:lab:denied']) == 'function')
assert(type(events['tss_bridge:client:configuration:sync']) == 'function')

commands['+tss_bridge_lab']()
assert(serverRequests == 1)
assert(moduleRequests == 0)

local configuration = {
    values = { Notify = 'ox', ProgressBar = 'auto' },
    items = {
        {
            key = 'Notify', label = 'Notifications', convar = 'tss_notify', icon = 'notify',
            current = 'ox', locked = true, blockedMessage = 'Blocked by server.cfg',
            options = { { value = 'auto', label = 'Auto Detect' }, { value = 'ox', label = 'ox_lib' } },
        },
        {
            key = 'ProgressBar', label = 'Progress Bar', convar = 'tss_progressbar', icon = 'timer',
            current = 'auto', locked = false,
            options = { { value = 'auto', label = 'Auto Detect' }, { value = 'qb', label = 'QB Progressbar' } },
        },
    },
}

events['tss_bridge:lab:open']({ mutationTests = true, configuration = configuration })
assert(moduleRequests == 1)
assert(callbackRegistered)
assert(menusOpened == 1)
assert(menus[1].data.options[1].value == 'configuration')
assert(menus[1].data.options[2].value == 'tests')
assert(menus[1].data.options[3].value == 'tools')

menus[1].callback({ value = 'configuration' })
assert(menusOpened == 2)
assert(menus[2].data.title == 'Configuration')
assert(menus[2].data.options[1].description:find('Blocked by server.cfg', 1, true))

menus[2].callback(nil)
assert(menusOpened == 3 and menus[3].data.title == 'Bridge Laboratory')
menus[3].callback({ value = 'tests' })
assert(menusOpened == 4)
assert(menus[4].data.title == 'Test Centre')
assert(#menus[4].data.options == 3)

menus[4].callback(nil)
assert(menusOpened == 5 and menus[5].data.title == 'Bridge Laboratory')
menus[5].callback({ value = 'tools' })
assert(menusOpened == 6)
assert(menus[6].data.title == 'Developer Tools')
assert(menus[6].data.options[2].value == 'polyzone')
assert(menus[6].data.options[2].disabled ~= true)
menus[6].callback({ value = 'polyzone' })
assert(menusOpened == 7)
assert(menus[7].data.title == 'PolyZone Creator')
assert(#menus[7].data.options == 3)

events['tss_bridge:lab:open']({ mutationTests = false, configuration = configuration })
assert(moduleRequests == 1)
assert(menusOpened == 8)

print('bridge lab client lazy-load tests passed')
