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
local registeredStashes = {}
local allowedIdentifiers, allowedCount = Authorization.Build(ServerConfig)

local function isAuthorized(source)
    return Authorization.IsAllowed(source, allowedIdentifiers)
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
secureCallback('serverSnapshot', function(source)
    local snapshot = buildSnapshot(source)

    TSS.Notify.Send(source, {
        title = 'Bridge Lab',
        description = 'Server callback and server notification passed.',
        type = 'success',
    })

    TSS.Callbacks.Trigger(source, 'clientSnapshot', function(clientSnapshot, callbackError)
        if callbackError then
            print(('[bridge_lab] client callback failed for %s: %s'):format(source, callbackError))
            return
        end
        print(('[bridge_lab] client callback passed for %s (%s / %s)')
            :format(source, clientSnapshot.framework, clientSnapshot.inventory))
    end, 'serverSnapshot')

    return snapshot
end)

secureCallback('recordClientAudit', function(source, report)
    if type(report) ~= 'table' then return false, 'invalid report' end
    local passed = math.max(0, math.min(100, tonumber(report.passed) or 0))
    local failed = math.max(0, math.min(100, tonumber(report.failed) or 0))
    print(('[bridge_lab] client audit from %s: %d passed, %d failed'):format(source, passed, failed))
    return true
end)

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

secureCallback('saveCreatedPeds', function(source, peds)
    return TSSBridgeLabPedStorage.Save(source, peds)
end)

secureCallback('prepareStash', function(source)
    return prepareStash(source)
end)

secureCallback('runMutations', function(source)
    return runMutations(source)
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

secureCallback('vehicleKeyRoundTrip', function(source, networkId)
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
    if not system then return { success = false, error = 'no vehicle-key adapter detected' } end

    local value = system == 'qbox' and vehicle or GetVehicleNumberPlateText(vehicle)
    local hadKeysBefore = TSS.VehicleKeys.Has(source, value)
    if hadKeysBefore then
        return {
            success = true,
            skipped = true,
            system = system,
            hadKeysBefore = true,
            hasAfter = true,
        }
    end

    local gave = TSS.VehicleKeys.Give(source, value)
    local hadKeys = gave and TSS.VehicleKeys.Has(source, value) or false
    local removed = gave and TSS.VehicleKeys.Remove(source, value) or false
    local hasAfter = TSS.VehicleKeys.Has(source, value)

    return {
        success = gave and removed,
        system = system,
        hadKeysBefore = false,
        gave = gave,
        hadKeys = hadKeys,
        removed = removed,
        hasAfter = hasAfter,
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
        mutationTests = ServerConfig.EnableMutationTests == true,
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
    registeredStashes[('bridge_lab_%s'):format(source)] = nil
end)

if not ServerConfig.Enabled then
    print('^3[bridge_lab] disabled in bridge_lab/server_config.lua^7')
elseif allowedCount == 0 then
    print('^3[bridge_lab] enabled, but no Discord or FiveM IDs are authorized in bridge_lab/server_config.lua^7')
else
    print(('[bridge_lab] ready for %d configured identifier(s); modules will load on first authorized use'):format(allowedCount))
end
