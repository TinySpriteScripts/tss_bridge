local moduleNames = {
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
}

local BridgeConfig = TSS.Config
local replicatedConfig = GlobalState and GlobalState.tssBridgeConfiguration
if type(replicatedConfig) == 'table' then
    for key, value in pairs(replicatedConfig) do
        if type(key) == 'string' and type(value) == 'string' then BridgeConfig[key] = value end
    end
end
---@type TSSClientModules?
local TSS
local LabConfig = TSSBridgeLabConfig
local PolyZoneCreator = TSSBridgeLabPolyZoneCreator
local ToolBrowser = TSSBridgeLabToolBrowser

local lab = {
    active = false,
    vehicle = nil,
    ped = nil,
    prop = nil,
    controllers = {},
    mutationTests = false,
    configuration = { items = {}, values = {} },
}

local openMainMenu
local openConfigMenu
local openConfigValueMenu
local openTestMenu
local openFeedbackMenu
local openGameplayMenu
local openToolsMenu
local openPolyZoneMenu

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

local function auditDetail(value)
    if type(value) == 'table' then
        local count = 0
        for _ in pairs(value) do count = count + 1 end
        return ('table (%d entries)'):format(count)
    end
    local detail = tostring(value)
    return #detail > 240 and (detail:sub(1, 237) .. '...') or detail
end

local function offset(coords, x, y, z, heading)
    return vector4(coords.x + x, coords.y + y, coords.z + (z or 0.0), heading or coords.w or 0.0)
end

local function testOrigin()
    if not LabConfig.SpawnAtPlayer then
        local location = LabConfig.DefaultLocation
        return vector4(location.x, location.y, location.z, location.w)
    end

    local playerPed = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 5.0, 0.0)
    return vector4(coords.x, coords.y, coords.z, GetEntityHeading(playerPed) + 180.0)
end

local function cleanupLab(silent)
    if not TSS then return end
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

local function applyConfigurationValues(values)
    if type(values) ~= 'table' then return end

    local structuralChange = false
    for key, value in pairs(values) do
        if type(key) == 'string' and type(value) == 'string' and BridgeConfig[key] ~= value then
            if key == 'Target' or key == 'Interaction' then structuralChange = true end
        end
    end

    if structuralChange and lab.active then cleanupLab(true) end

    for key, value in pairs(values) do
        if type(key) == 'string' and type(value) == 'string' then BridgeConfig[key] = value end
    end

    lab.configuration.values = values
    for i = 1, #(lab.configuration.items or {}) do
        local item = lab.configuration.items[i]
        if values[item.key] then item.current = values[item.key] end
    end
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
        :format(tostring(shown), tostring(isOpen), LabConfig.TextUIDuration / 1000),
        shown and isOpen and 'success' or 'warning')

    SetTimeout(LabConfig.TextUIDuration, function()
        TSS.TextUI.Hide()
    end)
end

local function progressSuite()
    CreateThread(function()
        local completed = TSS.ProgressBar.Start({
            label = 'Calibrating bridge adapters',
            duration = LabConfig.ProgressDuration,
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
        model = LabConfig.PedModel,
        coords = pedCoords,
        scenario = LabConfig.PedScenario,
        freeze = true,
        invincible = true,
    })

    lab.prop = TSS.Props.Create({
        model = LabConfig.PropModel,
        coords = propCoords,
        freeze = true,
    })

    lab.vehicle = TSS.Vehicles.Create({
        model = LabConfig.VehicleModel,
        coords = vehicleCoords,
        fuel = 63.0,
        networked = true,
    })

    local controller = TSS.World.CreateDistanceProp({
        model = LabConfig.DistancePropModel,
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

    TSS.Targets.Model(LabConfig.PropModel, { {
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
            slots = LabConfig.StashSlots,
            weight = LabConfig.StashWeight,
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
            local detail = ok and auditDetail(values[1]) or tostring(values[1])
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
        check('Money.Balance', function() return TSS.Money.Balance(LabConfig.MoneyAccount) end,
            function(value) return type(value) == 'number' end)
        check('Money.Has', function() return TSS.Money.Has(LabConfig.MoneyAccount, 0) end,
            function(value) return type(value) == 'boolean' end)
        check('Groups.BossRoles', function()
            local job = TSS.Player.Job()
            return TSS.Groups.BossRoles(job and job.name or 'none')
        end, function(value) return type(value) == 'table' end)
        check('Inventory.System', TSS.Inventory.System)
        check('Inventory.Supports', function() return TSS.Inventory.Supports('count') end,
            function(value) return value == true end)
        check('Inventory.Count', function() return TSS.Inventory.Count(LabConfig.TestItem) end,
            function(value) return type(value) == 'number' end)
        check('Inventory.Has', function() return TSS.Inventory.Has(LabConfig.TestItem, 1) end,
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

local function initialiseLab()
    if TSS then return true end

    local ok, modules = pcall(function()
        return exports.tss_bridge:GetModules(moduleNames)
    end)
    if not ok then
        print(('^1[bridge_lab] Unable to load client modules: %s^7'):format(tostring(modules)))
        return false
    end

    TSS = modules
    local registered = TSS.Callbacks.Register('clientSnapshot', function(trigger)
        local framework = TSS.Framework.System()
        local inventory = TSS.Inventory.System()
        return {
            realm = 'client',
            trigger = tostring(trigger or 'unknown'),
            framework = framework or 'none',
            inventory = inventory or 'none',
            playerName = TSS.Player.Name() or GetPlayerName(PlayerId()) or 'unknown',
            money = TSS.Money.Balance(LabConfig.MoneyAccount),
            locale = TSS.Locale.Language(),
            resource = TSS.World.ResourceName(),
            labActive = lab.active,
        }
    end)

    if not registered then
        print('^1[bridge_lab] Unable to register the internal client callback.^7')
        TSS = nil
        return false
    end
    return true
end

local function handleMenuResult(result, parent, actions)
    if not result then
        if parent then parent() end
        return
    end

    local action = actions[result.value]
    if action then action() end
end

local function findConfigurationItem(key)
    for i = 1, #(lab.configuration.items or {}) do
        local item = lab.configuration.items[i]
        if item.key == key then return item end
    end
end

local function configurationCounts()
    local total, locked = #(lab.configuration.items or {}), 0
    for i = 1, total do
        if lab.configuration.items[i].locked then locked = locked + 1 end
    end
    return total, locked
end

openConfigValueMenu = function(key)
    local item = findConfigurationItem(key)
    if not item then
        notify('Configuration metadata is unavailable. Reopen the Bridge Lab.', 'error')
        return openConfigMenu()
    end

    if item.locked then
        notify(('Blocked by server.cfg: %s is controlled by %s.'):format(item.label, item.convar), 'warning', 'Configuration Locked')
        return openConfigMenu()
    end

    local options = {}
    for i = 1, #(item.options or {}) do
        local choice = item.options[i]
        local selected = choice.value == item.current
        options[i] = {
            label = choice.label,
            description = selected and 'Currently selected.' or ('Set %s to %s.'):format(item.label, choice.label),
            value = choice.value,
            icon = selected and 'check' or item.icon,
            badge = selected and 'CURRENT' or string.upper(choice.value),
            arrow = false,
        }
    end

    TSS.UI.Menu({
        label = 'Bridge Lab / Configuration',
        title = item.label,
        description = ('Choose the default adapter. server.cfg key: %s'):format(item.convar),
        status = string.upper(item.current or 'auto'),
        previewLabel = 'Adapter choice',
        options = options,
    }, function(result)
        if not result then return openConfigMenu() end

        local response, callbackError = TSS.Callbacks.Await('setConfiguration', 5000, item.key, result.value)
        if type(response) ~= 'table' or response.success ~= true then
            local message = type(response) == 'table' and response.message or callbackError
            notify(message or 'Unable to update bridge configuration.', 'error', 'Configuration Failed')
            return openConfigMenu()
        end

        lab.configuration = response.configuration or lab.configuration
        applyConfigurationValues(lab.configuration.values)
        notify(response.message or ('%s updated.'):format(item.label), 'success', 'Configuration Saved')
        openConfigMenu()
    end)
end

openConfigMenu = function()
    local total, locked = configurationCounts()
    local options = {}

    for i = 1, total do
        local item = lab.configuration.items[i]
        options[i] = {
            label = item.label,
            description = item.locked and ('Blocked by server.cfg · %s = %s'):format(item.convar, item.current)
                or ('Current: %s · Select to change'):format(item.current),
            value = item.key,
            icon = item.locked and 'shield' or item.icon,
            badge = item.locked and 'LOCKED' or string.upper(item.current or 'auto'),
            arrow = not item.locked,
        }
    end

    TSS.UI.Menu({
        label = 'Bridge Lab',
        title = 'Configuration',
        description = 'Choose bridge-wide adapter defaults. server.cfg convars remain authoritative.',
        status = ('%d EDITABLE · %d LOCKED'):format(total - locked, locked),
        statusTone = locked == total and 'warning' or 'neutral',
        previewLabel = 'Bridge setting',
        options = options,
    }, function(result)
        if not result then return openMainMenu() end
        openConfigValueMenu(result.value)
    end)
end

openFeedbackMenu = function()
    TSS.UI.Menu({
        label = 'Bridge Lab / Test Centre',
        title = 'UI & Feedback',
        description = 'Exercise every player-facing adapter through focused, non-destructive checks.',
        status = '6 SUITES',
        previewLabel = 'Interface test',
        options = {
            { label = 'Notifications', description = 'Preview success, warning, error and information notifications.', value = 'notify', icon = 'notify', arrow = false },
            { label = 'Text UI', description = 'Validate show, update and hide behavior for world prompts.', value = 'textui', icon = 'text', arrow = false },
            { label = 'Progress', description = 'Run and cancel timed progress interactions.', value = 'progress', icon = 'timer', arrow = false },
            { label = 'Context Menus', description = 'Check context-menu rendering, selection and callbacks.', value = 'context', icon = 'menu', arrow = false },
            { label = 'Input Dialogs', description = 'Validate typed fields and submitted values.', value = 'input', icon = 'input', arrow = false },
            { label = 'Server Delivery', description = 'Deliver Notify, TextUI and built-in UI from the server.', value = 'server_ui', icon = 'server', arrow = false },
        },
    }, function(result)
        handleMenuResult(result, openTestMenu, {
            notify = notificationSuite,
            textui = textUiSuite,
            progress = progressSuite,
            context = contextSuite,
            input = inputSuite,
            server_ui = serverDeliverySuite,
        })
    end)
end

openGameplayMenu = function()
    TSS.UI.Menu({
        label = 'Bridge Lab / Test Centre',
        title = 'Gameplay & Data',
        description = 'Validate adapters that interact with vehicles, inventories and player state.',
        status = '3 SUITES',
        previewLabel = 'Gameplay test',
        options = {
            { label = 'Vehicle, Fuel & Keys', description = 'Checks vehicle state, fuel integration and key ownership.', value = 'vehicle', icon = 'vehicle', arrow = false },
            { label = 'Inventory Stash', description = 'Registers a temporary lab stash and opens it through the active inventory.', value = 'stash', icon = 'stash', arrow = false },
            {
                label = 'Reversible Mutations',
                description = lab.mutationTests and 'Tests controlled Money and Inventory mutations, then restores them.'
                    or 'Disabled in bridge_lab/server_config.lua',
                value = 'mutations',
                icon = 'mutations',
                badge = lab.mutationTests and 'ENABLED' or 'LOCKED',
                disabled = not lab.mutationTests,
                arrow = false,
            },
        },
    }, function(result)
        handleMenuResult(result, openTestMenu, {
            vehicle = vehicleSuite,
            stash = stashSuite,
            mutations = mutationSuite,
        })
    end)
end

openTestMenu = function()
    TSS.UI.Menu({
        label = 'Bridge Lab',
        title = 'Test Centre',
        description = 'Run a complete health check or drill into a focused adapter group.',
        status = '10 SUITES',
        previewLabel = 'Test category',
        options = {
            { label = 'Full Read-only Audit', description = 'Checks client APIs, server snapshots and callback round trips in one pass.', value = 'audit', icon = 'audit', badge = 'RECOMMENDED', arrow = false },
            { label = 'UI & Feedback', description = 'Notifications, TextUI, progress, menus, input and server delivery.', value = 'feedback', icon = 'feedback', badge = '6 SUITES' },
            { label = 'Gameplay & Data', description = 'Vehicles, fuel, keys, inventory stashes and guarded mutations.', value = 'gameplay', icon = 'gameplay', badge = '3 SUITES' },
        },
    }, function(result)
        handleMenuResult(result, openMainMenu, {
            audit = runAudit,
            feedback = openFeedbackMenu,
            gameplay = openGameplayMenu,
        })
    end)
end

local function requestZoneName(zoneType)
    local labels = { box = 'Box Zone', circle = 'Circle Zone', poly = 'Polygon Zone' }
    local label = labels[zoneType]
    TSS.UI.Input({
        label = 'Bridge Lab / PolyZone Creator',
        title = ('Create %s'):format(label),
        description = 'Give the zone a safe Lua identifier or readable name.',
        confirmLabel = 'Start Freecam',
        fields = {
            {
                name = 'name',
                label = 'Zone name',
                value = ('%s_zone'):format(zoneType),
                placeholder = 'example_zone',
                type = 'text',
            },
        },
    }, function(result)
        if not result then return openPolyZoneMenu() end
        local name = result.values and tostring(result.values.name or ''):match('^%s*(.-)%s*$') or ''
        if name == '' or #name > 64 or not name:match('^[%w _%-]+$') then
            notify('Use 1-64 letters, numbers, spaces, underscores, or hyphens.', 'error', 'Invalid Zone Name')
            return requestZoneName(zoneType)
        end

        local started = PolyZoneCreator.Start(zoneType, name, {
            onSave = function(zone)
                local response, callbackError = TSS.Callbacks.Await('saveCreatedZone', 7000, zone)
                if type(response) == 'table' and response.success then
                    notify(response.message, 'success', 'PolyZone Saved')
                else
                    notify(type(response) == 'table' and response.error or callbackError or 'Unable to save zone.',
                        'error', 'PolyZone Save Failed')
                end
                openPolyZoneMenu()
            end,
            onCancel = function()
                notify('Zone draft deleted. Nothing was saved.', 'inform', 'PolyZone Creator')
                openPolyZoneMenu()
            end,
        })

        if not started then
            notify('The PolyZone Creator is already active.', 'warning')
            openPolyZoneMenu()
        end
    end)
end

openPolyZoneMenu = function()
    TSS.UI.Menu({
        label = 'Bridge Lab / Developer Tools',
        title = 'PolyZone Creator',
        description = 'Create collision-style zones in detached freecam and save ready-to-use Lua.',
        status = 'FREECAM EDITOR',
        previewLabel = 'Zone shape',
        options = {
            {
                label = 'Box Zone',
                description = 'Move and rotate a 3D box, then resize any face with its red handle.',
                value = 'box', icon = 'boxzone', badge = '6 RESIZE HANDLES',
            },
            {
                label = 'Circle Zone',
                description = 'Position a 3D sphere and drag one red handle to set its radius.',
                value = 'circle', icon = 'circlezone', badge = 'RADIUS HANDLE',
            },
            {
                label = 'Polygon Zone',
                description = 'Aim at the ground and place an ordered polygon point-by-point.',
                value = 'poly', icon = 'polyzone', badge = 'DRAW MODE',
            },
        },
    }, function(result)
        if not result then return openToolsMenu() end
        requestZoneName(result.value)
    end)
end

local function openApiExplorer()
    local opened, browserError = ToolBrowser.OpenApi(openToolsMenu)
    if not opened then
        notify(browserError or 'Unable to open the API Explorer.', 'error', 'API Explorer')
        openToolsMenu()
    end
end

local function openItemBrowser()
    local opened, browserError = ToolBrowser.OpenItems(TSS.Inventory, openToolsMenu)
    if not opened then
        notify(browserError or 'Unable to load the shared item database.', 'error', 'Item Browser')
        openToolsMenu()
    end
end

local function requestPropAttachment()
    TSS.UI.Input({
        label = 'Bridge Lab / Prop Attachment Creator',
        title = 'Create Prop Attachment',
        description = 'Choose a save name and a valid GTA prop model. The preview attaches to your current ped.',
        confirmLabel = 'Start Editor',
        fields = {
            { name = 'name', label = 'Attachment name', value = 'new_attachment', placeholder = 'clipboard_prop' },
            { name = 'model', label = 'Prop model', value = 'prop_cs_tablet', placeholder = 'prop_cs_tablet' },
        },
    }, function(result)
        if not result then return openToolsMenu() end
        local values = result.values or {}
        local name = tostring(values.name or ''):match('^%s*(.-)%s*$')
        local model = tostring(values.model or ''):match('^%s*(.-)%s*$')
        if name == '' or #name > 64 or not name:match('^[%w _%-]+$') then
            notify('Use 1-64 letters, numbers, spaces, underscores, or hyphens for the name.', 'error', 'Invalid Name')
            return requestPropAttachment()
        end
        if model == '' or #model > 80 or not model:match('^[%w_%-]+$') then
            notify('Enter a valid prop model name.', 'error', 'Invalid Model')
            return requestPropAttachment()
        end

        -- Resolve at use time: FiveM may initialise newly added client files after
        -- this main chunk, so caching the global here can permanently cache nil.
        local creator = TSSBridgeLabPropAttachmentCreator
        if type(creator) ~= 'table' or type(creator.Start) ~= 'function' then
            notify('The Prop Attachment Creator client script did not load. Restart tss_bridge and check F8 for its startup error.',
                'error', 'Prop Attachment Creator')
            return openToolsMenu()
        end

        local started, startError = creator.Start(name, model, TSS.Props, {
            onSave = function(attachment)
                local response, callbackError = TSS.Callbacks.Await('saveCreatedPropAttachment', 7000, attachment)
                if type(response) == 'table' and response.success then
                    notify(response.message, 'success', 'Attachment Saved')
                else
                    notify(type(response) == 'table' and response.error or callbackError or 'Unable to save attachment.',
                        'error', 'Attachment Save Failed')
                end
                openToolsMenu()
            end,
            onCancel = function()
                notify('Attachment draft deleted. Nothing was saved.', 'inform', 'Prop Attachment Creator')
                openToolsMenu()
            end,
        })
        if not started then
            notify(startError or 'Unable to start the attachment editor.', 'error', 'Prop Attachment Creator')
            openToolsMenu()
        end
    end)
end

openToolsMenu = function()
    TSS.UI.Menu({
        label = 'Bridge Lab',
        title = 'Developer Tools',
        description = 'Build, inspect and clean up test environments from one workspace.',
        status = lab.active and 'YARD ACTIVE' or 'READY',
        statusTone = lab.active and 'success' or 'neutral',
        previewLabel = 'Lab tool',
        options = {
            {
                label = lab.active and 'Rebuild Certification Yard' or 'Deploy Certification Yard',
                description = 'Creates the lab ped, props, vehicle, blips, targets and interactions.',
                value = 'spawn',
                icon = 'deploy',
                badge = lab.active and 'ACTIVE' or 'AVAILABLE',
                arrow = false,
            },
            {
                label = 'PolyZone Creator',
                description = 'Create box, circle, and polygon zones using a freecam world editor.',
                value = 'polyzone',
                icon = 'polyzone',
                badge = 'AVAILABLE',
            },
            {
                label = 'Prop Attachment Creator',
                description = 'Attach a prop to a ped bone, then position and rotate it with local gizmos.',
                value = 'prop_attachment',
                icon = 'prop',
                badge = 'GIZMO EDITOR',
            },
            {
                label = 'Bridge API Explorer',
                description = 'Browse every documented public function, signature, parameter and client/server realm.',
                value = 'api_explorer',
                icon = 'api',
                badge = 'LIVE TYPES',
            },
            {
                label = 'Inventory Item Browser',
                description = 'Search the active inventory shared item database, preview images and copy any field.',
                value = 'item_browser',
                icon = 'items',
                badge = 'READ ONLY',
            },
            {
                label = 'Clean Up Lab Session',
                description = lab.active and 'Removes every entity, target, interaction and blip created by the lab.'
                    or 'There is no active certification yard to clean up.',
                value = 'cleanup',
                icon = 'cleanup',
                badge = lab.active and 'READY' or 'INACTIVE',
                disabled = not lab.active,
                arrow = false,
            },
        },
    }, function(result)
        handleMenuResult(result, openMainMenu, {
            spawn = spawnLab,
            polyzone = openPolyZoneMenu,
            prop_attachment = requestPropAttachment,
            api_explorer = openApiExplorer,
            item_browser = openItemBrowser,
            cleanup = cleanupLab,
        })
    end)
end

openMainMenu = function()
    local configTotal, configLocked = configurationCounts()
    TSS.UI.Menu({
        label = 'TSS Bridge / Authorized',
        title = 'BridgeLab',
        description = 'A focused workspace for bridge certification and developer tooling.',
        status = lab.active and 'LAB ACTIVE' or 'SYSTEM READY',
        statusTone = lab.active and 'success' or 'neutral',
        previewLabel = 'Workspace',
        options = {
            {
                label = 'Configuration',
                description = 'Choose bridge defaults that are not locked by server.cfg.',
                value = 'configuration',
                icon = 'configuration',
                badge = ('%d EDITABLE'):format(configTotal - configLocked),
            },
            {
                label = 'Test Centre',
                description = 'Run audits and focused adapter certification suites.',
                value = 'tests',
                icon = 'tests',
                badge = '10 SUITES',
            },
            {
                label = 'Developer Tools',
                description = 'Deploy the lab yard and access upcoming creation tools.',
                value = 'tools',
                icon = 'tools',
                badge = lab.active and 'YARD ACTIVE' or '6 TOOLS',
            },
        },
    }, function(result)
        handleMenuResult(result, nil, {
            configuration = openConfigMenu,
            tests = openTestMenu,
            tools = openToolsMenu,
        })
    end)
end

RegisterCommand('+tss_bridge_lab', function()
    TriggerServerEvent('tss_bridge:lab:requestOpen')
end, false)

RegisterCommand('-tss_bridge_lab', function() end, false)
RegisterKeyMapping('+tss_bridge_lab', 'Open the TSS Bridge Laboratory', 'keyboard', 'F7')

RegisterNetEvent('tss_bridge:lab:denied', function(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message or 'Bridge Lab access denied.'))
    EndTextCommandThefeedPostTicker(false, false)
end)

RegisterNetEvent('tss_bridge:lab:open', function(session)
    if not initialiseLab() then return end
    lab.mutationTests = type(session) == 'table' and session.mutationTests == true
    if type(session) == 'table' and type(session.configuration) == 'table' then
        lab.configuration = session.configuration
        applyConfigurationValues(lab.configuration.values)
    end
    openMainMenu()
end)

RegisterNetEvent('tss_bridge:client:configuration:sync', function(values)
    applyConfigurationValues(values)
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        TriggerServerEvent('tss_bridge:server:configuration:request')
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then cleanupLab(true) end
end)
