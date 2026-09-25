-- Lazy shared implementation owned by the Capabilities module.
TSS = TSS or {}
TSS.Capabilities = TSS.Capabilities or {}

--- Reports whether a resource is started.
---@param resource string Resource name.
---@return boolean started
---@return string state
function TSS.Capabilities.Resource(resource)
    if type(resource) ~= 'string' then return false, 'unknown' end
    local state = GetResourceState(resource)
    return state and state:find('start') ~= nil or false, state
end

--- Reports whether a module is available in the current realm.
---@param name string Module name.
---@return boolean available
function TSS.Capabilities.Module(name)
    return TSSModuleLoader.HasDefinition(name)
end

--- Lists all modules available in the current realm.
---@return string[] modules
function TSS.Capabilities.Modules()
    return TSSModuleLoader.ListAvailable()
end

--- Lists the modules initialized by consumers in the current realm.
---@return string[] modules
function TSS.Capabilities.LoadedModules()
    return TSSModuleLoader.ListLoaded()
end

--- Returns one resolved bridge configuration value.
---@param name string Configuration key.
---@return any value
function TSS.Capabilities.Config(name)
    if type(name) ~= 'string' then return nil end
    return TSS.Config[name]
end

--- Returns status information for every configured adapter resource.
---@return table<string, {resource: string, started: boolean, state: string}> resources
function TSS.Capabilities.Resources()
    local result = {}
    for label, resource in pairs(TSS.Resources) do
        local started, state = TSS.Capabilities.Resource(resource)
        result[label] = { resource = resource, started = started, state = state }
    end
    return result
end

--- Returns a diagnostic snapshot of modules, configuration, and adapters.
---@return table snapshot
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
            Locale = TSS.Config.Locale,
        },
    }
end
