local Loader = TSSModuleLoader
local define = Loader.Define
local copyFunctions = Loader.CopyFunctions

assert(Loader.Realm == 'client', '[tss_bridge] Client module registry loaded on the server')

local function cleanupWhenCallerStops(caller, callback)
    AddEventHandler('onClientResourceStop', function(resource)
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
    return copyFunctions(TSS.Player, { 'Data', 'Identifier', 'Name', 'Job', 'Gang', 'Metadata', 'HasGroup', 'IsLoaded' })
end, { 'Framework' })

define('Money', { 'shared/modules/money.lua' }, function()
    return copyFunctions(TSS.Money, { 'Balance', 'Has' })
end, { 'Framework' })

define('Groups', { 'shared/modules/groups.lua' }, function()
    return copyFunctions(TSS.Groups, { 'BossRoles' })
end, { 'Framework' })

define('UI', { 'shared/modules/ui.lua' }, function()
    return copyFunctions(TSS.UI, { 'Notify', 'Progress', 'HideProgress', 'Menu', 'Context', 'Input', 'Close' })
end)

define('Notify', { 'shared/modules/notify.lua' }, function()
    return copyFunctions(TSS.Notify, { 'System', 'Supports', 'Send' })
end)

define('TextUI', { 'shared/modules/textui.lua' }, function(caller)
    local public = copyFunctions(TSS.TextUI, { 'System', 'Supports' })

    function public.Show(data)
        return TSS.TextUI.Show(data, caller)
    end

    function public.Hide()
        return TSS.TextUI.Hide(caller)
    end

    function public.IsOpen()
        local isOpen, data, owner = TSS.TextUI.IsOpen()
        if owner ~= caller then return false, nil end
        return isOpen, data
    end

    cleanupWhenCallerStops(caller, public.Hide)
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

    function public.Await(name, timeout, ...)
        return TSS.Callbacks.Await(caller, name, timeout, ...)
    end

    function public.Trigger(name, callback, ...)
        if type(callback) ~= 'function' then return false end
        local args = { n = select('#', ...), ... }
        CreateThread(function()
            local result = { n = 0 }
            result = table.pack(public.Await(name, nil, table.unpack(args, 1, args.n)))
            callback(table.unpack(result, 1, result.n))
        end)
        return true
    end

    cleanupWhenCallerStops(caller, function() TSS.Callbacks.Clear(caller) end)
    return public
end, { 'Locale' })

define('ProgressBar', { 'shared/modules/progressbars.lua' }, function()
    return copyFunctions(TSS.Progress, { 'System', 'Supports', 'Start', 'Stop' })
end, { 'UI' })

define('Blips', { 'shared/modules/blips.lua' }, function(caller)
    local owned = {}
    local public = {}

    function public.Create(data)
        local blip = TSS.CreateBlip(data)
        if blip then owned[blip] = true end
        return blip
    end

    public.CreateEntity = public.Create

    function public.Remove(blip)
        owned[blip] = nil
        return TSS.RemoveBlip(blip)
    end

    function public.Clear()
        for blip in pairs(owned) do
            TSS.RemoveBlip(blip)
            owned[blip] = nil
        end
    end

    cleanupWhenCallerStops(caller, public.Clear)
    return public
end)

define('Peds', { 'shared/modules/peds.lua' }, function(caller)
    local owned = {}
    local public = {}

    function public.Create(data, coords, options)
        local ped = TSS.CreatePed(data, coords, options)
        if ped then owned[ped] = true end
        return ped
    end

    function public.CreateScenario(data, coords, scenario, options)
        options = options or {}
        options.scenario = options.scenario or scenario
        return public.Create(data, coords, options)
    end

    function public.CreateAnimated(data, coords, anim, options)
        options = options or {}
        options.anim = options.anim or anim
        return public.Create(data, coords, options)
    end

    function public.Delete(ped)
        owned[ped] = nil
        return TSS.DeletePed(ped)
    end

    function public.Clear()
        for ped in pairs(owned) do
            TSS.DeletePed(ped)
            owned[ped] = nil
        end
    end

    cleanupWhenCallerStops(caller, public.Clear)
    return public
end)

define('Props', { 'shared/modules/props.lua' }, function(caller)
    local owned = {}
    local public = {}

    function public.Create(data, coords, options)
        local prop = TSS.CreateProp(data, coords, options)
        if prop then owned[prop] = true end
        return prop
    end

    function public.Delete(prop)
        owned[prop] = nil
        return TSS.DeleteProp(prop)
    end

    function public.Clear()
        for prop in pairs(owned) do
            TSS.DeleteProp(prop)
            owned[prop] = nil
        end
    end

    cleanupWhenCallerStops(caller, public.Clear)
    return public
end)

define('Vehicles', { 'shared/modules/vehicles.lua' }, function(caller)
    local owned = {}
    local public = {}

    function public.Create(data, coords, options)
        local vehicle = TSS.CreateVehicle(data, coords, options)
        if vehicle then owned[vehicle] = true end
        return vehicle
    end

    function public.Delete(vehicle)
        owned[vehicle] = nil
        return TSS.DeleteVehicle(vehicle)
    end

    function public.Clear()
        for vehicle in pairs(owned) do
            TSS.DeleteVehicle(vehicle)
            owned[vehicle] = nil
        end
    end

    cleanupWhenCallerStops(caller, public.Clear)
    return public
end)

define('World', { 'shared/modules/world.lua' }, function(caller)
    local controllers = {}
    local public = copyFunctions(TSS.World, { 'Face' })

    public.ResourceName = function()
        return caller
    end

    function public.CreateDistanceProp(data, options)
        local controller = TSS.World.CreateDistanceProp(data, options)
        if controller then controllers[#controllers + 1] = controller end
        return controller
    end

    function public.CreateDistancePed(data, coords, options)
        local controller = TSS.World.CreateDistancePed(data, coords, options)
        if controller then controllers[#controllers + 1] = controller end
        return controller
    end

    cleanupWhenCallerStops(caller, function()
        for i = 1, #controllers do
            controllers[i].remove()
        end
        controllers = {}
    end)

    return public
end, { 'Peds', 'Props' })

define('Targets', { 'shared/modules/targets.lua' }, function(caller)
    local entities = {}
    local models = {}
    local zones = {}
    local public = {}

    public.System = TSS.Target.System
    public.Supports = TSS.Target.Supports

    function public.Entity(entity, options, distance)
        entities[entity] = true
        return TSS.Target.Entity(entity, options, distance)
    end

    function public.Model(modelList, options, distance)
        models[#models + 1] = modelList
        return TSS.Target.Model(modelList, options, distance)
    end

    function public.Box(data, options, distance)
        local zone = TSS.Target.Box(data, options, distance)
        if zone then zones[zone] = true end
        return zone
    end

    function public.Circle(data, options, distance)
        local zone = TSS.Target.Circle(data, options, distance)
        if zone then zones[zone] = true end
        return zone
    end

    function public.RemoveEntity(entity)
        entities[entity] = nil
        return TSS.Target.RemoveEntity(entity)
    end

    function public.RemoveModel(modelList)
        for i = #models, 1, -1 do
            if models[i] == modelList then table.remove(models, i) end
        end
        return TSS.Target.RemoveModel(modelList)
    end

    function public.RemoveZone(zone)
        zones[zone] = nil
        return TSS.Target.RemoveZone(zone)
    end

    function public.Clear()
        for entity in pairs(entities) do
            TSS.Target.RemoveEntity(entity)
            entities[entity] = nil
        end

        for i = 1, #models do
            TSS.Target.RemoveModel(models[i])
        end
        models = {}

        for zone in pairs(zones) do
            TSS.Target.RemoveZone(zone)
            zones[zone] = nil
        end
    end

    cleanupWhenCallerStops(caller, public.Clear)
    return public
end)

define('Interaction', { 'shared/modules/interaction.lua' }, function(caller)
    local public = copyFunctions(TSS.Interaction, { 'System', 'Supports' })

    function public.Create(data)
        return TSS.Interaction.Create(data, caller)
    end

    function public.Remove(id)
        return TSS.Interaction.Remove(id)
    end

    function public.Clear()
        return TSS.Interaction.Clear(caller)
    end

    cleanupWhenCallerStops(caller, public.Clear)
    return public
end, { 'Targets', 'TextUI', 'Player', 'Inventory' })

define('Inventory', Loader.InventoryFiles, function()
    return copyFunctions(TSS.Inventory, { 'System', 'Supports', 'Count', 'Has', 'Player', 'Items', 'Open', 'OpenStash', 'Close' })
end)

define('VehicleKeys', { 'shared/modules/vehiclekeys.lua' }, function()
    return copyFunctions(TSS.VehicleKeys, { 'System', 'Supports', 'Has' })
end)

define('Fuel', { 'shared/modules/fuel.lua' }, function()
    return copyFunctions(TSS.Fuel, { 'System', 'Supports', 'Get', 'Set' })
end)

define('Debug', { 'shared/modules/debug.lua' }, function()
    local public = copyFunctions(TSS.DebugTools, { 'FormatLocationTable', 'FormatLocationTables', 'FormatChairTable' })
    public.SetEnabled = TSS.SetDebug
    return public
end)
