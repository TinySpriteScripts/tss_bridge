-- Public framework API. Framework-specific behaviour lives in adapters.
TSS = TSS or {}
TSS.Framework = TSS.Framework or {}

local registry = TSS.Adapters.Create('Framework', { config = 'Framework' })

function TSS.Framework.RegisterAdapter(key, resource, adapter, options)
    return registry:Register(key, resource, adapter, options)
end

local function resolve()
    return registry:Resolve()
end

--- Detects the active framework selected by configuration or resource state.
---@return TSSFrameworkName? system
---@return string? resource
function TSS.Framework.System()
    local system, resource = resolve()
    return system, resource
end

--- Returns the framework's shared object when it exposes one.
---@return table? frameworkObject
function TSS.Framework.Object()
    local _, resource, adapter = resolve()
    return adapter and adapter.object and adapter.object(resource) or nil
end

--- Returns the framework-native player object for the current realm.
---@param source? integer
---@return table? player
function TSS.Framework.Player(source)
    local _, resource, adapter = resolve()
    return adapter and adapter.player and adapter.player(resource, source) or nil
end

--- Returns normalized framework player data for the current realm.
---@param source? integer
---@return table? playerData
function TSS.Framework.PlayerData(source)
    local _, resource, adapter = resolve()
    if not adapter then return nil end
    if adapter.playerData then return adapter.playerData(resource, source) end

    local player = adapter.player and adapter.player(resource, source) or nil
    return TSS.IsServer() and player and (player.PlayerData or player) or player
end

--- Returns all jobs known to the active framework.
---@return table jobs
function TSS.Framework.Jobs()
    local _, resource, adapter = resolve()
    return adapter and adapter.jobs and adapter.jobs(resource) or {}
end

--- Returns all gangs known to the active framework.
---@return table gangs
function TSS.Framework.Gangs()
    local _, resource, adapter = resolve()
    return adapter and adapter.gangs and adapter.gangs(resource) or {}
end

--- Reports whether the active framework supports a bridge feature.
---@param feature 'player'|'jobs'|'gangs'|'money'|'object'|string
---@return boolean supported
function TSS.Framework.Supports(feature)
    return registry:Supports(feature)
end
