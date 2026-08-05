---@type TSSServerModules
local TSS = exports.tss_bridge:GetModules({
    'Framework',
    'Player',
    'Money',
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
})

local mutationCooldowns = {}
local registeredStashes = {}

local function systemName(module)
    local system, resource = module.System()
    return system or 'none', resource or 'none'
end

local function playerJobName(source)
    local job = TSS.Player.Job(source)
    return job and job.name or 'none'
end

local function mutationAllowed(source)
    if not BridgeLabConfig.EnableMutationTests then
        return false, 'Mutation tests are disabled in config.lua'
    end

    if BridgeLabConfig.RequireMutationAce
        and not TSS.Player.HasPermission(source, BridgeLabConfig.MutationAce) then
        return false, ('Missing ACE permission: %s'):format(BridgeLabConfig.MutationAce)
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
    local itemCount = TSS.Inventory.Count(source, BridgeLabConfig.TestItem)

    local debugPreview = TSS.Debug.FormatLocationTable({ {
        coords = BridgeLabConfig.DefaultLocation,
        l = 1.0,
        w = 1.0,
        maxZ = BridgeLabConfig.DefaultLocation.z + 1.0,
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
        cash = TSS.Money.Balance(source, BridgeLabConfig.MoneyAccount),
        inventory = inventory,
        inventoryResource = inventoryResource,
        testItem = BridgeLabConfig.TestItem,
        testItemCount = itemCount,
        hasTestItem = TSS.Inventory.Has(source, BridgeLabConfig.TestItem, 1),
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
        slots = BridgeLabConfig.StashSlots,
        weight = BridgeLabConfig.StashWeight,
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

    local account = BridgeLabConfig.MoneyAccount
    local moneyAmount = BridgeLabConfig.MoneyAmount
    local moneyBefore = TSS.Money.Balance(source, account)
    local moneySetSame = TSS.Money.Set(source, account, moneyBefore, 'bridge_lab_test_set_same')
    local moneyAdded = TSS.Money.Add(source, account, moneyAmount, 'bridge_lab_test_add')
    local moneyAfterAdd = TSS.Money.Balance(source, account)
    local moneyRemoved = moneyAdded and TSS.Money.Remove(source, account, moneyAmount, 'bridge_lab_test_restore') or false
    local moneyAfterRestore = TSS.Money.Balance(source, account)

    local item = BridgeLabConfig.TestItem
    local itemAmount = BridgeLabConfig.ItemAmount
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

TSS.Callbacks.Register('serverSnapshot', function(source)
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

TSS.Callbacks.Register('recordClientAudit', function(source, report)
    if type(report) ~= 'table' then return false, 'invalid report' end
    local passed = math.max(0, math.min(100, tonumber(report.passed) or 0))
    local failed = math.max(0, math.min(100, tonumber(report.failed) or 0))
    print(('[bridge_lab] client audit from %s: %d passed, %d failed'):format(source, passed, failed))
    return true
end)

TSS.Callbacks.Register('prepareStash', function(source)
    return prepareStash(source)
end)

TSS.Callbacks.Register('runMutations', function(source)
    return runMutations(source)
end)

TSS.Callbacks.Register('testServerDelivery', function(source)
    TSS.TextUI.Show(source, { text = 'Server TextUI delivery passed', icon = 'server' })
    TSS.UI.Notify({ title = 'Bridge Lab UI', message = 'Direct server UI delivery passed', type = 'success' }, source)
    TSS.UI.Progress({ label = 'Server-driven UI progress', percent = 45 }, source)

    SetTimeout(2000, function()
        TSS.TextUI.Hide(source)
        TSS.UI.HideProgress(source)
    end)

    return true
end)

TSS.Callbacks.Register('vehicleKeyRoundTrip', function(source, networkId)
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

RegisterCommand('bridgelabserver', function(source)
    if source == 0 then
        TSS.Diagnostics.Print()
        return
    end

    TSS.Callbacks.Trigger(source, 'clientSnapshot', function(snapshot, callbackError)
        TSS.Notify.Send(source, {
            title = 'Bridge Lab',
            description = callbackError and ('Client callback failed: ' .. callbackError)
                or ('Client callback passed for ' .. snapshot.playerName),
            type = callbackError and 'error' or 'success',
        })
    end, 'server_command')
end, false)

AddEventHandler('playerDropped', function()
    mutationCooldowns[source] = nil
    registeredStashes[('bridge_lab_%s'):format(source)] = nil
end)

print(('[bridge_lab] server consumer loaded with %d bridge modules'):format(#TSS.Capabilities.LoadedModules()))
