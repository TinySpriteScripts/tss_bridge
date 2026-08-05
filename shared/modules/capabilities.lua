TSS = TSS or {}
TSS.Capabilities = TSS.Capabilities or {}

function TSS.Capabilities.Resource(resource)
    if type(resource) ~= 'string' then return false, 'unknown' end
    local state = GetResourceState(resource)
    return state and state:find('start') ~= nil or false, state
end

function TSS.Capabilities.Module(name)
    return TSSModuleLoader.HasDefinition(name)
end

function TSS.Capabilities.Modules()
    return TSSModuleLoader.ListAvailable()
end

function TSS.Capabilities.LoadedModules()
    return TSSModuleLoader.ListLoaded()
end

function TSS.Capabilities.Config(name)
    if type(name) ~= 'string' then return nil end
    return TSS.Config[name]
end

function TSS.Capabilities.Resources()
    local result = {}
    for label, resource in pairs(TSS.Resources) do
        local started, state = TSS.Capabilities.Resource(resource)
        result[label] = { resource = resource, started = started, state = state }
    end
    return result
end

function TSS.Capabilities.Snapshot()
    return {
        realm = TSS.IsServer() and 'server' or 'client',
        available = TSS.Capabilities.Modules(),
        loaded = TSS.Capabilities.LoadedModules(),
        resources = TSS.Capabilities.Resources(),
        config = {
            Framework = TSS.Config.Framework,
            Notify = TSS.Config.Notify,
            ProgressBar = TSS.Config.ProgressBar,
            Target = TSS.Config.Target,
            Inventory = TSS.Config.Inventory,
            TextUI = TSS.Config.TextUI,
            Interaction = TSS.Config.Interaction,
            VehicleKeys = TSS.Config.VehicleKeys,
            Fuel = TSS.Config.Fuel,
            Locale = TSS.Config.Locale,
        },
    }
end
