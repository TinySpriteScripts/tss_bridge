local root = assert(arg[1], 'expected resource root')
local registeredCommand
local opened = {}
local openCounts = {}
local denied = {}
local netEvents = {}
local callbackHandlers = {}
local moduleRequests = 0
local gameTimer = 10000
local savedKvp = { ['tss_bridge:configuration:ProgressBar'] = 'tss' }
local synced = {}

TSS = { Config = {
    Framework = 'auto', Notify = 'ox', ProgressBar = 'auto', Target = 'auto',
    Inventory = 'auto', TextUI = 'auto', Interaction = 'auto',
    VehicleKeys = 'auto', Fuel = 'auto',
} }
TSSBridgeLabZoneStorage = {
    Save = function(source, zone)
        return { success = source == 1 and type(zone) == 'table' }
    end,
}

TSSBridgeLabConfig = {
    TestItem = 'water',
    DefaultLocation = { x = 0.0, y = 0.0, z = 0.0, w = 0.0 },
    MoneyAccount = 'cash',
    StashSlots = 10,
    StashWeight = 25000,
}
TSSBridgeLabServerConfig = {
    Enabled = true,
    Command = 'bridgelab',
    AllowedDiscordIds = { '111' },
    AllowedFiveMIds = { '222' },
    DeniedMessage = 'denied',
    EnableMutationTests = false,
    MoneyAmount = 25,
    ItemAmount = 1,
}

function GetPlayerIdentifiers(source)
    if source == 1 then return { 'license:a', 'discord:111' } end
    if source == 2 then return { 'license:b', 'fivem:222' } end
    return { 'license:unauthorized' }
end

function GetConvar(name, fallback)
    if name == 'tss_notify' then return 'ox' end
    return fallback
end

function GetResourceKvpString(key)
    return savedKvp[key]
end

function SetResourceKvp(key, value)
    savedKvp[key] = value
end

function RegisterCommand(name, callback)
    assert(name == 'bridgelab')
    registeredCommand = callback
end

function RegisterNetEvent(name, callback)
    netEvents[name] = callback
end

function GetGameTimer()
    return gameTimer
end

function TriggerClientEvent(event, source, payload)
    if event == 'tss_bridge:lab:open' then
        opened[source] = payload
        openCounts[source] = (openCounts[source] or 0) + 1
    end
    if event == 'tss_bridge:lab:denied' then denied[source] = payload end
    if event == 'tss_bridge:client:configuration:sync' then synced[source] = payload end
end

function AddEventHandler() end

local modules = {
    Callbacks = {
        Register = function(name, handler)
            callbackHandlers[name] = handler
            return true
        end,
    },
}

exports = {
    tss_bridge = {
        GetModules = function(_, requested)
            assert(type(requested) == 'table' and #requested == 14)
            moduleRequests = moduleRequests + 1
            return modules
        end,
    },
}

assert(loadfile(root .. '/bridge_lab/authorization.lua'))()
assert(loadfile(root .. '/bridge_lab/configuration.lua'))()
assert(TSS.Config.ProgressBar == 'tss')
assert(loadfile(root .. '/bridge_lab/server/main.lua'))()
assert(type(registeredCommand) == 'function')
assert(type(netEvents['tss_bridge:lab:requestOpen']) == 'function')
assert(type(netEvents['tss_bridge:server:configuration:request']) == 'function')

source = 2
netEvents['tss_bridge:server:configuration:request']()
assert(synced[2].Notify == 'ox')

source = 3
netEvents['tss_bridge:lab:requestOpen']()
assert(denied[3] == 'denied')
assert(moduleRequests == 0)

gameTimer = 11000
registeredCommand(4)
assert(denied[4] == 'denied')
assert(moduleRequests == 0)

gameTimer = 12000
source = 1
netEvents['tss_bridge:lab:requestOpen']()
assert(type(opened[1]) == 'table')
assert(opened[1].mutationTests == false)
assert(type(opened[1].configuration) == 'table')
assert(moduleRequests == 1)
assert(callbackHandlers.serverSnapshot)
assert(callbackHandlers.recordClientAudit)
assert(callbackHandlers.setConfiguration)
assert(callbackHandlers.saveCreatedZone)
assert(callbackHandlers.prepareStash)
assert(callbackHandlers.runMutations)
assert(callbackHandlers.testServerDelivery)
assert(callbackHandlers.vehicleKeyRoundTrip)

local lockedResult = callbackHandlers.setConfiguration(1, 'Notify', 'qb')
assert(lockedResult.success == false and lockedResult.message == 'Blocked by server.cfg')
assert(TSS.Config.Notify == 'ox')

local invalidResult = callbackHandlers.setConfiguration(1, 'ProgressBar', 'not-an-adapter')
assert(invalidResult.success == false and TSS.Config.ProgressBar == 'tss')

local changedResult = callbackHandlers.setConfiguration(1, 'ProgressBar', 'qb')
assert(changedResult.success == true)
assert(TSS.Config.ProgressBar == 'qb')
assert(savedKvp['tss_bridge:configuration:ProgressBar'] == 'qb')
assert(synced[-1].ProgressBar == 'qb')

gameTimer = 12500
netEvents['tss_bridge:lab:requestOpen']()
assert(openCounts[1] == 1)

for _, handler in pairs(callbackHandlers) do
    local allowed, message = handler(3)
    assert(allowed == false and message == 'denied')
end

gameTimer = 13000
registeredCommand(2)
assert(type(opened[2]) == 'table')
assert(moduleRequests == 1)

print('bridge lab server authorization tests passed')
