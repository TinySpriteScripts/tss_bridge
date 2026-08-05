local Loader = TSSModuleLoader
local define = Loader.Define
local copyFunctions = Loader.CopyFunctions

assert(Loader.Realm == 'server', '[tss_bridge] Server module registry loaded on the client')

local function cleanupWhenCallerStops(caller, callback)
    AddEventHandler('onResourceStop', function(resource)
        if resource == caller then callback() end
    end)
end

define('Locale', { 'shared/locales/en.lua', 'shared/modules/locale.lua' }, function()
    return copyFunctions(TSS.Locale, { 'Language', 'Translate', 'Exists', 'T' })
end)

define('Capabilities', { 'shared/modules/capabilities.lua' }, function()
    return copyFunctions(TSS.Capabilities, { 'Resource', 'Module', 'Modules', 'LoadedModules', 'Config', 'Resources', 'Snapshot' })
end)

define('Diagnostics', { 'shared/modules/diagnostics.lua' }, function()
    return copyFunctions(TSS.Diagnostics, { 'Lines', 'Print' })
end, { 'Capabilities' })

define('Framework', { 'shared/modules/framework.lua' }, function()
    return copyFunctions(TSS.Framework, { 'System', 'Object', 'Player', 'PlayerData', 'Jobs', 'Gangs', 'Supports' })
end)

define('Player', { 'shared/modules/player.lua' }, function()
    return copyFunctions(TSS.Player, {
        'Data', 'Identifier', 'Name', 'Job', 'Gang', 'Metadata', 'HasGroup', 'IsLoaded', 'HasPermission'
    })
end, { 'Framework' })

define('Money', { 'shared/modules/money.lua' }, function()
    return copyFunctions(TSS.Money, { 'Balance', 'Has', 'Add', 'Remove', 'Set' })
end, { 'Framework' })

define('Groups', { 'shared/modules/groups.lua' }, function()
    return copyFunctions(TSS.Groups, { 'BossRoles' })
end, { 'Framework' })

define('UI', { 'shared/modules/ui.lua' }, function()
    return copyFunctions(TSS.UI, { 'Notify', 'Progress', 'HideProgress' })
end)

define('Notify', { 'shared/modules/notify.lua' }, function()
    return copyFunctions(TSS.Notify, { 'System', 'Supports', 'Send' })
end)

define('TextUI', { 'shared/modules/textui.lua' }, function(caller)
    local shown = {}
    local public = copyFunctions(TSS.TextUI, { 'System', 'Supports' })

    function public.Show(source, data)
        if type(source) ~= 'number' then return false end
        shown[source] = true
        return TSS.TextUI.Show(source, data, caller)
    end

    function public.Hide(source)
        shown[source] = nil
        return TSS.TextUI.Hide(source, caller)
    end

    cleanupWhenCallerStops(caller, function()
        for source in pairs(shown) do TSS.TextUI.Hide(source, caller) end
    end)
    return public
end)

define('Callbacks', { 'shared/modules/callbacks.lua' }, function(caller)
    local public = {}

    function public.Register(name, handler)
        return TSS.Callbacks.Register(caller, name, handler)
    end

    function public.Unregister(name)
        return TSS.Callbacks.Unregister(caller, name)
    end

    function public.Await(source, name, timeout, ...)
        return TSS.Callbacks.Await(caller, source, name, timeout, ...)
    end

    function public.Trigger(source, name, callback, ...)
        if type(callback) ~= 'function' then return false end
        local args = { n = select('#', ...), ... }
        CreateThread(function()
            local result = table.pack(public.Await(source, name, nil, table.unpack(args, 1, args.n)))
            callback(table.unpack(result, 1, result.n))
        end)
        return true
    end

    cleanupWhenCallerStops(caller, function() TSS.Callbacks.Clear(caller) end)
    return public
end, { 'Locale' })

define('Inventory', Loader.InventoryFiles, function()
    return copyFunctions(TSS.Inventory, {
        'System', 'Supports', 'Add', 'Remove', 'Count', 'Has', 'CanCarry', 'Player', 'Items',
        'RegisterStash', 'Open', 'OpenStash', 'Close'
    })
end)

define('VehicleKeys', { 'shared/modules/vehiclekeys.lua' }, function()
    return copyFunctions(TSS.VehicleKeys, { 'System', 'Supports', 'Has', 'Give', 'Remove' })
end)

define('Debug', { 'shared/modules/debug.lua' }, function()
    local public = copyFunctions(TSS.DebugTools, { 'FormatLocationTable', 'FormatLocationTables', 'FormatChairTable' })
    public.SetEnabled = TSS.SetDebug
    return public
end)
