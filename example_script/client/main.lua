---@type TSSClientModules
local TSS = exports.tss_bridge:GetModules({
    'Framework',
    'Player',
    'Money',
    'Groups',
    'UI',
    'Notify',
    'TextUI',
    'Callbacks',
    'ProgressBar',
    'Blips',
    'Peds',
    'Props',
    'Vehicles',
    'World',
    'Targets',
    'Interaction',
    'Inventory',
    'VehicleKeys',
    'Fuel',
    'Locale',
    'Capabilities',
    'Diagnostics',
    'Debug',
})

local lab = {
    active = false,
    vehicle = nil,
    ped = nil,
    prop = nil,
    controllers = {},
}

local openMainMenu

local function notify(message, notifyType, title)
    return TSS.Notify.Send({
        id = ('bridge_lab_%s'):format(GetGameTimer()),
        title = title or 'Bridge Lab',
        description = message,
        type = notifyType or 'inform',
        duration = 5000,
        position = 'top-right',
        icon = 'flask',
    })
end

local function pretty(value)
    if type(value) == 'table' and json and json.encode then
        local ok, encoded = pcall(json.encode, value)
        if ok then return encoded end
    end
    return tostring(value)
end

local function offset(coords, x, y, z, heading)
    return vector4(coords.x + x, coords.y + y, coords.z + (z or 0.0), heading or coords.w or 0.0)
end

local function testOrigin()
    if not BridgeLabConfig.SpawnAtPlayer then
        local location = BridgeLabConfig.DefaultLocation
        return vector4(location.x, location.y, location.z, location.w)
    end

    local playerPed = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 5.0, 0.0)
    return vector4(coords.x, coords.y, coords.z, GetEntityHeading(playerPed) + 180.0)
end

local function cleanupLab(silent)
    TSS.TextUI.Hide()
    TSS.UI.Close()
    TSS.Interaction.Clear()
    TSS.Targets.Clear()

    for i = 1, #lab.controllers do
        local controller = lab.controllers[i]
        if controller and controller.remove then pcall(controller.remove) end
    end

    TSS.Blips.Clear()
    TSS.Peds.Clear()
    TSS.Props.Clear()
    TSS.Vehicles.Clear()

    lab.active = false
    lab.vehicle = nil
    lab.ped = nil
    lab.prop = nil
    lab.controllers = {}

    if not silent then notify('All Bridge Lab entities, targets, interactions, and UI were cleared.', 'success') end
end

local function notificationSuite()
    local notices = {
        { type = 'inform', description = 'Inform notification adapter check.' },
        { type = 'success', description = 'Success notification adapter check.' },
        { type = 'warning', description = 'Warning notification adapter check.' },
        { type = 'error', description = 'Error notification adapter check.' },
    }

    for index = 1, #notices do
        local notice = notices[index]
        SetTimeout((index - 1) * 650, function()
            TSS.Notify.Send({
                title = 'Bridge Lab Notify',
                description = notice.description,
                type = notice.type,
                duration = 3500,
                position = 'top-right',
            })
        end)
    end

    TSS.UI.Notify({
        title = 'Built-in UI',
        message = 'Direct UI.Notify check.',
        type = 'success',
        duration = 4000,
    })
end

local function textUiSuite()
    local shown = TSS.TextUI.Show({
        text = '[E] Bridge TextUI is active',
        position = 'right-center',
        icon = 'flask',
    })
    local isOpen = TSS.TextUI.IsOpen()
    notify(('TextUI.Show=%s, IsOpen=%s; it will hide in %.1fs.')
        :format(tostring(shown), tostring(isOpen), BridgeLabConfig.TextUIDuration / 1000),
        shown and isOpen and 'success' or 'warning')

    SetTimeout(BridgeLabConfig.TextUIDuration, function()
        TSS.TextUI.Hide()
    end)
end

local function progressSuite()
    CreateThread(function()
        local completed = TSS.ProgressBar.Start({
            label = 'Calibrating bridge adapters',
            duration = BridgeLabConfig.ProgressDuration,
            canCancel = true,
            disableMovement = true,
            disableCombat = true,
            dict = 'amb@world_human_clipboard@male@idle_a',
            anim = 'idle_c',
            flag = 49,
        })

        notify(completed and 'Progress adapter completed successfully.' or 'Progress was cancelled or failed.',
            completed and 'success' or 'warning')
    end)
end

local function inputSuite()
    TSS.UI.Input({
        label = 'Bridge input test',
        title = 'Adapter Test Details',
        description = 'Submit values to verify the built-in input callback.',
        confirmLabel = 'Run Test',
        fields = {
            { name = 'label', label = 'Test label', value = 'Consumer test', placeholder = 'Label' },
            { name = 'amount', label = 'Number', type = 'number', value = '25', min = 1, max = 100, suffix = 'units' },
        },
    }, function(result)
        if not result then
            notify('Input dialog was closed.', 'warning')
            return
        end
        notify(('Input callback returned: %s'):format(pretty(result.values)), 'success')
    end)
end

local function contextSuite()
    TSS.UI.Context({
        label = 'Bridge context test',
        closeLabel = 'Close test',
        options = {
            { label = 'Success notification', value = 'success', icon = 'check' },
            { label = 'Run progress test', value = 'progress', icon = 'timer' },
            { label = 'Open input test', value = 'input', icon = 'zap' },
        },
    }, function(result)
        if not result then return end
        if result.value == 'success' then notify('Context selection callback passed.', 'success') end
        if result.value == 'progress' then progressSuite() end
        if result.value == 'input' then inputSuite() end
    end)
end

local function serverDeliverySuite()
    CreateThread(function()
        local delivered, callbackError = TSS.Callbacks.Await('testServerDelivery', 5000)
        if callbackError then
            notify(('Server delivery callback failed: %s'):format(callbackError), 'error')
            return
        end
        notify(('Server-driven Notify, TextUI, and UI request returned %s.'):format(tostring(delivered)),
            delivered and 'success' or 'warning')
    end)
end

local function spawnLab()
    cleanupLab(true)

    local origin = testOrigin()
    local pedCoords = offset(origin, -1.5, 0.0, 0.0, origin.w)
    local propCoords = offset(origin, 1.5, 0.0, -1.0, origin.w)
    local vehicleCoords = offset(origin, 4.0, 2.5, 0.0, origin.w)
    local distancePropCoords = offset(origin, -3.0, 2.0, -1.0, origin.w)

    TSS.Blips.Create({
        coords = origin,
        sprite = 354,
        color = 1,
        scale = 0.75,
        label = 'TSS Bridge Lab',
        shortRange = true,
    })

    lab.ped = TSS.Peds.Create({
        model = BridgeLabConfig.PedModel,
        coords = pedCoords,
        scenario = BridgeLabConfig.PedScenario,
        freeze = true,
        invincible = true,
    })

    lab.prop = TSS.Props.Create({
        model = BridgeLabConfig.PropModel,
        coords = propCoords,
        freeze = true,
    })

    lab.vehicle = TSS.Vehicles.Create({
        model = BridgeLabConfig.VehicleModel,
        coords = vehicleCoords,
        fuel = 63.0,
        networked = true,
    })

    local controller = TSS.World.CreateDistanceProp({
        model = BridgeLabConfig.DistancePropModel,
        coords = distancePropCoords,
        freeze = true,
    }, {
        range = 25.0,
        despawnRange = 35.0,
        interval = 500,
    })
    if controller then lab.controllers[#lab.controllers + 1] = controller end

    TSS.Targets.Box({
        name = 'bridge_lab_box',
        coords = vector3(origin.x, origin.y, origin.z),
        length = 1.2,
        width = 1.2,
        minZ = origin.z - 1.0,
        maxZ = origin.z + 1.5,
        heading = origin.w,
    }, { {
        name = 'bridge_lab_box_option',
        label = 'Test box target',
        icon = 'fas fa-cube',
        onSelect = function() notify('Box target selection passed.', 'success') end,
    } }, 2.0)

    TSS.Targets.Circle({
        name = 'bridge_lab_circle',
        coords = vector3(origin.x + 2.0, origin.y, origin.z),
        radius = 1.0,
    }, { {
        name = 'bridge_lab_circle_option',
        label = 'Test circle target',
        icon = 'fas fa-circle',
        onSelect = contextSuite,
    } }, 2.0)

    if lab.vehicle then
        TSS.Targets.Entity(lab.vehicle, { {
            name = 'bridge_lab_vehicle_option',
            label = 'Inspect test vehicle',
            icon = 'fas fa-car',
            onSelect = function()
                local fuel = TSS.Fuel.Get(lab.vehicle)
                local hasKeys = TSS.VehicleKeys.Has(lab.vehicle)
                notify(('Vehicle target passed. Fuel %.1f, local keys %s.'):format(fuel, tostring(hasKeys)), 'success')
            end,
        } }, 2.5)
    end

    if lab.ped then
        TSS.Interaction.Create({
            name = 'bridge_lab_technician',
            entity = lab.ped,
            distance = 2.5,
            label = 'Open Bridge Lab',
            icon = 'fas fa-flask',
            onSelect = function() openMainMenu() end,
        })
        TSS.World.Face(lab.ped)
    end

    TSS.Targets.Model(BridgeLabConfig.PropModel, { {
        name = 'bridge_lab_model_option',
        label = 'Test model target',
        icon = 'fas fa-toolbox',
        onSelect = function() notify('Model target selection passed.', 'success') end,
    } }, 2.0)

    if lab.vehicle then
        TSS.Fuel.Set(lab.vehicle, 63.0)
    end

    lab.active = lab.ped ~= nil or lab.prop ~= nil or lab.vehicle ~= nil
    notify(lab.active and 'Bridge Lab spawned nearby. Use the technician, zones, vehicle, and toolbox targets.'
        or 'The lab could not spawn any entities; check configured models.', lab.active and 'success' or 'error')
end

local function vehicleSuite()
    CreateThread(function()
        if not lab.vehicle or not DoesEntityExist(lab.vehicle) then spawnLab() end
        if not lab.vehicle or not DoesEntityExist(lab.vehicle) then
            notify('No test vehicle is available.', 'error')
            return
        end

        TSS.Fuel.Set(lab.vehicle, 72.5)
        local fuel = TSS.Fuel.Get(lab.vehicle)
        local localKeysBefore = TSS.VehicleKeys.Has(lab.vehicle)
        local networkId = NetworkGetNetworkIdFromEntity(lab.vehicle)
        local report, callbackError = TSS.Callbacks.Await('vehicleKeyRoundTrip', 7000, networkId)

        if callbackError or not report then
            notify(('Vehicle-key callback failed: %s'):format(callbackError or 'no report'), 'error')
            return
        end

        local keySummary = report.skipped and 'server mutation skipped because keys already existed'
            or ('give=%s, detected=%s, remove=%s, after=%s')
                :format(tostring(report.gave), tostring(report.hadKeys), tostring(report.removed), tostring(report.hasAfter))
        notify(('Fuel %.1f; local keys before=%s; %s (%s).')
            :format(fuel, tostring(localKeysBefore), keySummary, report.system or 'none'),
            report.success and 'success' or 'warning')
    end)
end

local function stashSuite()
    CreateThread(function()
        local success, stashIdOrError = TSS.Callbacks.Await('prepareStash', 7000)
        if not success then
            notify(('Stash preparation failed: %s'):format(stashIdOrError or 'unknown error'), 'error')
            return
        end

        local opened = TSS.Inventory.OpenStash({
            id = stashIdOrError,
            label = 'Bridge Lab',
            slots = BridgeLabConfig.StashSlots,
            weight = BridgeLabConfig.StashWeight,
        })
        notify(('Inventory.OpenStash returned %s.'):format(tostring(opened)), opened and 'success' or 'warning')
    end)
end

local function mutationSuite()
    CreateThread(function()
        local report, callbackError = TSS.Callbacks.Await('runMutations', 10000)
        if callbackError or not report then
            notify(('Mutation callback failed: %s'):format(callbackError or 'no report'), 'error')
            return
        end
        if not report.allowed then
            notify(report.error or 'Mutation tests were rejected.', 'warning')
            return
        end

        print('[bridge_lab] mutation report: ' .. pretty(report))
        local restored = report.money.restored and report.inventory.restored
        notify(('Money restored=%s; inventory restored=%s. Full report printed to F8.')
            :format(tostring(report.money.restored), tostring(report.inventory.restored)),
            restored and 'success' or 'error')
    end)
end

local function runAudit()
    CreateThread(function()
        local results = {}
        local passed, failed = 0, 0

        local function check(name, callback, validate)
            local values = table.pack(pcall(callback))
            local ok = values[1]
            table.remove(values, 1)
            values.n = values.n - 1
            local valid = ok and (not validate or validate(table.unpack(values, 1, values.n)))
            local detail = ok and pretty(values[1]) or tostring(values[1])
            results[#results + 1] = { name = name, passed = valid, detail = detail }
            if valid then passed = passed + 1 else failed = failed + 1 end
        end

        check('Framework.System', TSS.Framework.System, function(value) return value ~= nil end)
        check('Framework.Object', TSS.Framework.Object)
        check('Framework.Supports', function() return TSS.Framework.Supports('money') end,
            function(value) return value == true end)
        check('Framework.Jobs', TSS.Framework.Jobs, function(value) return type(value) == 'table' end)
        check('Framework.Gangs', TSS.Framework.Gangs, function(value) return type(value) == 'table' end)
        check('Player.IsLoaded', TSS.Player.IsLoaded, function(value) return value == true end)
        check('Player.Identifier', function() return TSS.Player.Identifier('citizenid') end, function(value) return value ~= nil end)
        check('Player.Name', TSS.Player.Name, function(value) return value ~= nil end)
        check('Player.Job', TSS.Player.Job, function(value) return type(value) == 'table' end)
        check('Player.Gang', TSS.Player.Gang)
        check('Player.Metadata', TSS.Player.Metadata)
        check('Player.HasGroup', function()
            local job = TSS.Player.Job()
            return job and TSS.Player.HasGroup(job.name) or false
        end, function(value) return value == true end)
        check('Money.Balance', function() return TSS.Money.Balance(BridgeLabConfig.MoneyAccount) end,
            function(value) return type(value) == 'number' end)
        check('Money.Has', function() return TSS.Money.Has(BridgeLabConfig.MoneyAccount, 0) end,
            function(value) return type(value) == 'boolean' end)
        check('Groups.BossRoles', function()
            local job = TSS.Player.Job()
            return TSS.Groups.BossRoles(job and job.name or 'none')
        end, function(value) return type(value) == 'table' end)
        check('Inventory.System', TSS.Inventory.System)
        check('Inventory.Supports', function() return TSS.Inventory.Supports('count') end,
            function(value) return value == true end)
        check('Inventory.Count', function() return TSS.Inventory.Count(BridgeLabConfig.TestItem) end,
            function(value) return type(value) == 'number' end)
        check('Inventory.Has', function() return TSS.Inventory.Has(BridgeLabConfig.TestItem, 1) end,
            function(value) return type(value) == 'boolean' end)
        check('Inventory.Player', TSS.Inventory.Player, function(value) return type(value) == 'table' end)
        check('Inventory.Items', TSS.Inventory.Items, function(value) return type(value) == 'table' end)
        check('Notify.System', TSS.Notify.System, function(value) return value ~= nil end)
        check('Notify.Supports', function() return TSS.Notify.Supports('position') end,
            function(value) return type(value) == 'boolean' end)
        check('TextUI.System', TSS.TextUI.System, function(value) return value ~= nil end)
        check('TextUI.Supports', function() return TSS.TextUI.Supports('show') end,
            function(value) return type(value) == 'boolean' end)
        check('ProgressBar.System', TSS.ProgressBar.System, function(value) return value ~= nil end)
        check('ProgressBar.Supports', function() return TSS.ProgressBar.Supports('cancel') end,
            function(value) return type(value) == 'boolean' end)
        check('Targets.System', TSS.Targets.System)
        check('Interaction.System', TSS.Interaction.System, function(value) return value ~= nil end)
        check('VehicleKeys.System', TSS.VehicleKeys.System)
        check('Fuel.System', TSS.Fuel.System, function(value) return value ~= nil end)
        check('Locale.Language', TSS.Locale.Language, function(value) return type(value) == 'string' end)
        check('Locale.Exists', function() return TSS.Locale.Exists('callback_timeout') end,
            function(value) return value == true end)
        check('Capabilities.Module', function() return TSS.Capabilities.Module('Money') end,
            function(value) return value == true end)
        check('Capabilities.Resource', function() return TSS.Capabilities.Resource('tss_bridge') end,
            function(value) return value == true end)
        check('Capabilities.Resources', TSS.Capabilities.Resources, function(value) return type(value) == 'table' end)
        check('Capabilities.Snapshot', TSS.Capabilities.Snapshot, function(value) return type(value) == 'table' end)
        check('Diagnostics.Lines', TSS.Diagnostics.Lines, function(value) return type(value) == 'table' end)
        check('World.ResourceName', TSS.World.ResourceName, function(value) return type(value) == 'string' end)
        check('Debug.FormatLocationTable', function()
            return TSS.Debug.FormatLocationTable({ {
                coords = testOrigin(), l = 1.0, w = 1.0, maxZ = testOrigin().z + 1.0,
            } }, 'Shop')
        end, function(value) return type(value) == 'string' and #value > 0 end)

        local serverSnapshot, callbackError = TSS.Callbacks.Await('serverSnapshot', 7000)
        check('Callbacks.Await serverSnapshot', function()
            if callbackError then error(callbackError) end
            return serverSnapshot
        end, function(value) return type(value) == 'table' and value.realm == 'server' end)

        local recorded = TSS.Callbacks.Await('recordClientAudit', 5000, { passed = passed, failed = failed })
        check('Callbacks report upload', function() return recorded end, function(value) return value == true end)

        print(('^5[bridge_lab]^7 audit complete: %d passed, %d failed'):format(passed, failed))
        for i = 1, #results do
            local result = results[i]
            print(('^%s[bridge_lab] %s %s: %s^7'):format(result.passed and '2' or '1',
                result.passed and 'PASS' or 'FAIL', result.name, result.detail))
        end
        if serverSnapshot then print('[bridge_lab] server snapshot: ' .. pretty(serverSnapshot)) end

        notify(('%d checks passed, %d failed. Details are in F8.'):format(passed, failed),
            failed == 0 and 'success' or 'warning', 'Bridge Audit')
    end)
end

TSS.Callbacks.Register('clientSnapshot', function(trigger)
    local framework = TSS.Framework.System()
    local inventory = TSS.Inventory.System()
    return {
        realm = 'client',
        trigger = tostring(trigger or 'unknown'),
        framework = framework or 'none',
        inventory = inventory or 'none',
        playerName = TSS.Player.Name() or GetPlayerName(PlayerId()) or 'unknown',
        money = TSS.Money.Balance(BridgeLabConfig.MoneyAccount),
        locale = TSS.Locale.Language(),
        resource = TSS.World.ResourceName(),
        labActive = lab.active,
    }
end)

openMainMenu = function()
    TSS.UI.Menu({
        label = 'TSS Bridge consumer test',
        title = 'Bridge Laboratory',
        description = 'Run focused adapter tests or spawn the interactive certification yard.',
        options = {
            { label = 'Run read-only audit', description = 'Checks client APIs and callback round trips.', value = 'audit', icon = 'check' },
            { label = 'Spawn interactive lab', description = 'Creates entities, blips, targets and interactions.', value = 'spawn', icon = 'zap' },
            { label = 'Notification suite', value = 'notify' },
            { label = 'TextUI suite', value = 'textui' },
            { label = 'Progress suite', value = 'progress', icon = 'timer' },
            { label = 'Context menu suite', value = 'context' },
            { label = 'Input dialog suite', value = 'input' },
            { label = 'Server delivery suite', description = 'Server Notify, TextUI and built-in UI.', value = 'server_ui' },
            { label = 'Vehicle, fuel and keys', value = 'vehicle' },
            { label = 'Register and open stash', value = 'stash' },
            {
                label = 'Reversible mutation suite',
                description = BridgeLabConfig.EnableMutationTests and 'Tests Money and Inventory mutations.'
                    or 'Disabled in config.lua',
                value = 'mutations',
                disabled = not BridgeLabConfig.EnableMutationTests,
            },
            { label = 'Clean up lab', value = 'cleanup', icon = 'close' },
        },
    }, function(result)
        if not result then return end
        local actions = {
            audit = runAudit,
            spawn = spawnLab,
            notify = notificationSuite,
            textui = textUiSuite,
            progress = progressSuite,
            context = contextSuite,
            input = inputSuite,
            server_ui = serverDeliverySuite,
            vehicle = vehicleSuite,
            stash = stashSuite,
            mutations = mutationSuite,
            cleanup = cleanupLab,
        }
        local action = actions[result.value]
        if action then action() end
    end)
end

RegisterCommand(BridgeLabConfig.Command, openMainMenu, false)
RegisterCommand(BridgeLabConfig.Command .. 'audit', runAudit, false)
RegisterCommand(BridgeLabConfig.Command .. 'spawn', spawnLab, false)
RegisterCommand(BridgeLabConfig.Command .. 'cleanup', function() cleanupLab(false) end, false)
RegisterKeyMapping(BridgeLabConfig.Command, 'Open the TSS Bridge Laboratory', 'keyboard', 'F7')

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then cleanupLab(true) end
end)

CreateThread(function()
    Wait(1500)
    notify(('Consumer loaded. Use /%s or F7 to open the Bridge Lab.'):format(BridgeLabConfig.Command), 'inform')
end)
