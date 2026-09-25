local moduleNames = {
    'Framework',
    'Player',
    'Banking',
    'Groups',
    'UI',
    'Notify',
    'TextUI',
    'Callbacks',
    'Inventory',
    'VehicleKeys',
    'Locale',
    'Capabilities',
    'Diagnostics',
    'Debug',
}

---@type TSSServerModules?
local TSS
local LabConfig = TSSBridgeLabConfig
local ServerConfig = TSSBridgeLabServerConfig
local Authorization = TSSBridgeLabAuthorization
local Configuration = TSSBridgeLabConfiguration
local ZoneStorage = TSSBridgeLabZoneStorage
local AttachmentStorage = TSSBridgeLabAttachmentStorage

local mutationCooldowns = {}
local openCooldowns = {}
local itemSpawnLimits = {}
local registeredStashes = {}
local allowedIdentifiers, allowedCount = Authorization.Build(ServerConfig)

local function isAuthorized(source)
    return Authorization.IsAllowed(source, allowedIdentifiers)
end

local function itemSpawnAllowed(source)
    local now = GetGameTimer()
    local limit = itemSpawnLimits[source]
    if not limit or now < limit.startedAt or now - limit.startedAt >= 60000 then
        limit = { startedAt = now, lastAt = 0, count = 0 }
        itemSpawnLimits[source] = limit
    end

    if limit.lastAt > 0 and now - limit.lastAt < 1000 then
        return false, 'Wait one second before spawning another item'
    end
    if limit.count >= 20 then
        return false, 'Item spawn limit reached; wait before trying again'
    end

    limit.lastAt = now
    limit.count = limit.count + 1
    return true
end

local function serverItemExists(itemName)
    local ok, items = pcall(TSS.Inventory.Items)
    if not ok or type(items) ~= 'table' then return false, 'The server item registry is unavailable' end

    if type(rawget(items, itemName)) == 'table' then return true end
    for key, definition in pairs(items) do
        if type(definition) == 'table' then
            local name = definition.name
            if name == nil and type(key) == 'string' then name = key end
            if name == nil then name = definition.id end
            if name ~= nil and tostring(name) == itemName then return true end
        end
    end

    return false, 'That item does not exist in the server item registry'
end

local function systemName(module)
    local system, resource = module.System()
    return system or 'none', resource or 'none'
end

local function playerJobName(source)
    local job = TSS.Player.Job(source)
    return job and job.name or 'none'
end

local function mutationAllowed(source)
    if not isAuthorized(source) then
        return false, ServerConfig.DeniedMessage
    end

    if not ServerConfig.EnableMutationTests then
        return false, 'Mutation tests are disabled in bridge_lab/server_config.lua'
    end

    local now = GetGameTimer()
    if mutationCooldowns[source] and now - mutationCooldowns[source] < 10000 then
        return false, 'Wait ten seconds before running another mutation test'
    end

    mutationCooldowns[source] = now
    return true
end

--- Builds a serialization-safe server snapshot for one player.
---@param source integer
---@return table snapshot
local function buildSnapshot(source)
    local framework, frameworkResource = TSS.Framework.System()
    local inventory, inventoryResource = systemName(TSS.Inventory)
    local keySystem, keyResource = systemName(TSS.VehicleKeys)
    local job = TSS.Player.Job(source)
    local jobName = job and job.name or 'none'
    local jobGrade = job and job.grade
    jobGrade = type(jobGrade) == 'table' and (jobGrade.level or jobGrade.grade) or jobGrade
    jobGrade = tonumber(jobGrade) or 0
    local bossRoles = jobName ~= 'none' and TSS.Groups.BossRoles(jobName) or {}
    local itemCount = TSS.Inventory.Count(source, LabConfig.TestItem)

    local debugPreview = TSS.Debug.FormatLocationTable({ {
        coords = LabConfig.DefaultLocation,
        l = 1.0,
        w = 1.0,
        maxZ = LabConfig.DefaultLocation.z + 1.0,
    } }, 'Shop')

    return {
        realm = 'server',
        framework = framework or 'none',
        frameworkResource = frameworkResource or 'none',
        playerName = TSS.Player.Name(source) or GetPlayerName(source) or 'unknown',
        identifier = TSS.Player.Identifier(source, 'citizenid')
            or TSS.Player.Identifier(source, 'license') or 'unknown',
        job = jobName,
        jobGrade = jobGrade,
        isBoss = bossRoles[jobName] ~= nil and jobGrade >= bossRoles[jobName],
        cash = TSS.Banking.GetAccount(source, LabConfig.MoneyAccount),
        inventory = inventory,
        inventoryResource = inventoryResource,
        testItem = LabConfig.TestItem,
        testItemCount = itemCount,
        hasTestItem = TSS.Inventory.Has(source, LabConfig.TestItem, 1),
        vehicleKeys = keySystem,
        vehicleKeysResource = keyResource,
        locale = TSS.Locale.Language(),
        localeCheck = TSS.Locale.T('callback_missing', 'bridge_lab_probe'),
        moneySupported = TSS.Framework.Supports('money'),
        inventoryCountSupported = TSS.Inventory.Supports('count'),
        availableModules = TSS.Capabilities.Modules(),
        loadedModules = TSS.Capabilities.LoadedModules(),
        notifyConfig = TSS.Capabilities.Config('Notify'),
        diagnostics = TSS.Diagnostics.Lines(),
        debugPreview = debugPreview,
    }
end

--- Registers the per-player Bridge Lab stash.
---@param source integer
---@return boolean success
---@return string stashIdOrError
local function prepareStash(source)
    local stashId = ('bridge_lab_%s'):format(source)
    if registeredStashes[stashId] then return true, stashId end

    if not TSS.Inventory.Supports('stash') then
        return false, 'The active inventory does not support stash registration'
    end

    local success = TSS.Inventory.RegisterStash({
        id = stashId,
        label = ('Bridge Lab - %s'):format(GetPlayerName(source) or source),
        slots = LabConfig.StashSlots,
        weight = LabConfig.StashWeight,
        owner = false,
    })

    if success then registeredStashes[stashId] = true end
    return success, success and stashId or 'Stash registration failed'
end

--- Runs reversible server-authoritative money and inventory mutations.
---@param source integer
---@return table report
local function runMutations(source)
    local allowed, reason = mutationAllowed(source)
    if not allowed then return { allowed = false, error = reason } end

    local account = LabConfig.MoneyAccount
    local moneyAmount = ServerConfig.MoneyAmount
    local moneyBefore = TSS.Banking.GetAccount(source, account)
    local moneySetSame = true
    local moneyAdded = TSS.Banking.AddMoney(source, account, moneyAmount, 'bridge_lab_test_add')
    local moneyAfterAdd = TSS.Banking.GetAccount(source, account)
    local moneyRemoved = moneyAdded and TSS.Banking.RemoveMoney(source, account, moneyAmount, 'bridge_lab_test_restore') or false
    local moneyAfterRestore = TSS.Banking.GetAccount(source, account)

    local item = LabConfig.TestItem
    local itemAmount = ServerConfig.ItemAmount
    local itemBefore = TSS.Inventory.Count(source, item)
    local itemCanCarry = TSS.Inventory.CanCarry(source, item, itemAmount)
    local itemAdded = itemCanCarry
        and TSS.Inventory.Add(source, item, itemAmount, nil, nil, 'bridge_lab_test_add') or false
    local itemAfterAdd = TSS.Inventory.Count(source, item)
    local itemRemoved = itemAdded and TSS.Inventory.Remove(source, item, itemAmount, nil, nil, 'bridge_lab_test_restore') or false
    local itemAfterRestore = TSS.Inventory.Count(source, item)

    return {
        allowed = true,
        money = {
            before = moneyBefore,
            afterAdd = moneyAfterAdd,
            afterRestore = moneyAfterRestore,
            setSame = moneySetSame,
            added = moneyAdded,
            removed = moneyRemoved,
            restored = moneyAdded and moneyRemoved and moneyAfterRestore == moneyBefore,
        },
        inventory = {
            item = item,
            before = itemBefore,
            afterAdd = itemAfterAdd,
            afterRestore = itemAfterRestore,
            canCarry = itemCanCarry,
            added = itemAdded,
            removed = itemRemoved,
            restored = itemAdded and itemRemoved and itemAfterRestore == itemBefore,
        },
    }
end

local function secureCallback(name, handler)
    local registered = TSS.Callbacks.Register(name, function(source, ...)
        if not isAuthorized(source) then return false, ServerConfig.DeniedMessage end
        return handler(source, ...)
    end)
    if not registered then error(('Unable to register Bridge Lab callback: %s'):format(name), 0) end
end

local function registerCallbacks()
secureCallback('setConfiguration', function(source, key, value)
    local changed, message = Configuration.Set(key, value)
    return {
        success = changed,
        message = message,
        configuration = Configuration.Snapshot(),
    }
end)

secureCallback('saveCreatedZone', function(source, zone)
    return ZoneStorage.Save(source, zone)
end)

secureCallback('saveCreatedPropAttachment', function(source, attachment)
    return AttachmentStorage.Save(source, attachment)
end)

secureCallback('saveCreatedPedAnimations', function(source, peds)
    return TSSBridgeLabPedAnimationStorage.Save(source, peds)
end)

secureCallback('saveCreatedPropScene', function(source, scene)
    return TSSBridgeLabPropSceneStorage.Save(source, scene)
end)

secureCallback('spawnBrowserItem', function(source, itemName)
    itemName = type(itemName) == 'string' and itemName:match('^%s*(.-)%s*$') or ''
    if itemName == '' or #itemName > 128 or itemName:find('%c') then
        return { success = false, error = 'Invalid item code' }
    end

    local allowed, limitError = itemSpawnAllowed(source)
    if not allowed then return { success = false, error = limitError } end

    local exists, registryError = serverItemExists(itemName)
    if not exists then
        print(('[bridge_lab] rejected item spawn from %s: %s'):format(source, itemName))
        return { success = false, error = registryError }
    end

    local canCarryOk, canCarry = pcall(TSS.Inventory.CanCarry, source, itemName, 1, nil)
    if not canCarryOk then
        print(('[bridge_lab] item carry check failed for %s (%s): %s'):format(source, itemName, tostring(canCarry)))
        return { success = false, error = 'The inventory carry check failed' }
    end
    if canCarry ~= true then return { success = false, error = 'You cannot carry this item' } end

    local addOk, added = pcall(TSS.Inventory.Add, source, itemName, 1, nil, nil, 'bridge_lab_item_browser')
    if not addOk or added ~= true then
        print(('[bridge_lab] item grant failed for %s (%s): %s'):format(source, itemName, tostring(added)))
        return { success = false, error = 'The inventory could not add this item' }
    end

    print(('[bridge_lab] authorized item spawn: player %s received 1x %s'):format(source, itemName))
    return {
        success = true,
        item = itemName,
        amount = 1,
        message = ('Added 1x %s to your inventory.'):format(itemName),
    }
end)

secureCallback('testServerDelivery', function(source)
    TSS.TextUI.Show(source, { text = 'Server TextUI delivery passed', icon = 'server' })
    TSS.UI.Notify({ title = 'Bridge Lab UI', message = 'Direct server UI delivery passed', type = 'success' }, source)
    TSS.UI.Progress({ label = 'Server-driven UI progress', percent = 45 }, source)

    SetTimeout(2000, function()
        TSS.TextUI.Hide(source)
        TSS.UI.HideProgress(source)
    end)

    return true
end)

secureCallback('giveVehicleKeys', function(source, networkId)
    if type(networkId) ~= 'number' or networkId <= 0 then
        return { success = false, error = 'invalid network ID' }
    end

    local vehicle = NetworkGetEntityFromNetworkId(networkId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return { success = false, error = 'vehicle is not networked on the server yet' }
    end

    if NetworkGetEntityOwner and NetworkGetEntityOwner(vehicle) ~= source then
        return { success = false, error = 'the player does not own this network entity' }
    end

    local system = TSS.VehicleKeys.System()
    if not system then return { success = false, error = 'No vehicle-key system is available.' } end

    local value = system == 'qbox' and vehicle or GetVehicleNumberPlateText(vehicle)
    local gave = TSS.VehicleKeys.Give(source, value)
    return {
        success = gave == true,
        system = system,
        error = gave and nil or 'The active vehicle-key system rejected the request.',
        message = gave and ('Vehicle keys granted through %s.'):format(system) or nil,
    }
end)
end

local function initialiseLab()
    if TSS then return true end

    local ok, modules = pcall(function()
        return exports.tss_bridge:GetModules(moduleNames)
    end)
    if not ok then
        print(('^1[bridge_lab] Unable to load server modules: %s^7'):format(tostring(modules)))
        return false
    end

    TSS = modules
    local registered, registerError = pcall(registerCallbacks)
    if not registered then
        print(('^1[bridge_lab] %s^7'):format(tostring(registerError)))
        TSS = nil
        return false
    end
    return true
end

local command = tostring(ServerConfig.Command or 'bridgelab'):lower()
if not command:match('^[%w_-]+$') then command = 'bridgelab' end

local function requestOpen(playerSource)
    if playerSource == 0 then
        print(('[bridge_lab] /%s must be used by an authorized in-game player.'):format(command))
        return
    end

    local now = GetGameTimer()
    if openCooldowns[playerSource] and now - openCooldowns[playerSource] < 1000 then return end
    openCooldowns[playerSource] = now

    if not isAuthorized(playerSource) then
        TriggerClientEvent('tss_bridge:lab:denied', playerSource, ServerConfig.DeniedMessage)
        print(('[bridge_lab] denied access for player %s'):format(playerSource))
        return
    end

    if not initialiseLab() then
        TriggerClientEvent('tss_bridge:lab:denied', playerSource, 'The TSS Bridge Lab could not be initialized. Check the server console.')
        return
    end

    TriggerClientEvent('tss_bridge:lab:open', playerSource, {
        configuration = Configuration.Snapshot(),
    })
end

if ServerConfig.Enabled then
    RegisterCommand(command, function(source)
        requestOpen(source)
    end, false)

    RegisterNetEvent('tss_bridge:lab:requestOpen', function()
        requestOpen(source)
    end)
end

AddEventHandler('playerDropped', function()
    mutationCooldowns[source] = nil
    openCooldowns[source] = nil
    itemSpawnLimits[source] = nil
    registeredStashes[('bridge_lab_%s'):format(source)] = nil
end)

if not ServerConfig.Enabled then
    print('^3[bridge_lab] disabled in bridge_lab/server_config.lua^7')
elseif allowedCount == 0 then
    print('^3[bridge_lab] enabled, but no Discord or FiveM IDs are authorized in bridge_lab/server_config.lua^7')
else
    print(('[bridge_lab] ready for %d configured identifier(s); modules will load on first authorized use'):format(allowedCount))
end
