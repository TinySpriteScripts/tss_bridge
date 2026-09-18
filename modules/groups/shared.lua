-- Public group API. Framework group formats live in adapters.
TSS = TSS or {}
TSS.Groups = TSS.Groups or {}
TSS.Groups.Utils = TSS.Groups.Utils or {}

local registry = TSS.Adapters.Create('Groups')
local managementRegistry = TSS.Adapters.Create('Management')

function TSS.Groups.Utils.FindBossRole(groups, role)
    local roles = {}
    local group = groups and groups[role]
    if not group or not group.grades then return roles end

    for grade, data in pairs(group.grades) do
        if data.isboss or data.isBoss or data.bankAuth then
            local level = tonumber(grade)
            if level then roles[role] = roles[role] and math.min(roles[role], level) or level end
        end
    end
    return roles
end

function TSS.Groups.RegisterAdapter(key, resource, adapter, options)
    return registry:Register(key, resource, adapter, options)
end

function TSS.Groups.RegisterManagementAdapter(key, resource, adapter, options)
    return managementRegistry:Register(key, resource, adapter, options)
end

local function resolve()
    local framework = TSS.Framework.System()
    return registry:Resolve(framework)
end

--- Detects the Groups adapter paired with the configured framework.
---@return TSSFrameworkName? system
---@return string? resource
function TSS.Groups.System()
    local system, resource = resolve()
    return system, resource
end

--- Reports whether the active Groups adapter supports a feature.
---@param feature 'bossroles'|'jobs'|'gangs'|'management'|'jobboss'|'gangboss'|string
---@return boolean supported
function TSS.Groups.Supports(feature)
    if feature == 'management' then
        return managementRegistry:Supports(feature)
    end
    local framework = TSS.Framework.System()
    return registry:Supports(feature, framework)
end

--- Finds the minimum boss grade for a job or gang.
---@param role string
---@return table<string, integer> roles
function TSS.Groups.BossRoles(role)
    if type(role) ~= 'string' or role == '' then return {} end
    local _, resource, adapter = resolve()
    return adapter and adapter.bossRoles and adapter.bossRoles(resource, role) or {}
end

--- Returns the active management/boss-menu backend.
---@return string? system
---@return string? resource
function TSS.Groups.ManagementSystem()
    local system, resource = managementRegistry:Resolve()
    return system, resource
end

--- Checks whether a player is the boss of the requested job.
---@param role? string Defaults to the player's current job.
---@param source? integer Required on the server when checking another player.
---@return boolean isBoss
function TSS.Groups.IsJobBoss(role, source)
    local _, resource, adapter = resolve()
    return adapter and adapter.isJobBoss and adapter.isJobBoss(resource, role, source) or false
end

--- Checks whether a player is the boss of the requested gang.
---@param role? string Defaults to the player's current gang.
---@param source? integer Required on the server when checking another player.
---@return boolean isBoss
function TSS.Groups.IsGangBoss(role, source)
    local _, resource, adapter = resolve()
    return adapter and adapter.isGangBoss and adapter.isGangBoss(resource, role, source) or false
end

--- Opens the selected job management menu on the client.
---@param role? string Defaults to the player's current job.
---@return boolean opened
function TSS.Groups.OpenBossMenu(role)
    if TSS.IsServer() then return false end
    local _, resource, adapter = managementRegistry:Resolve()
    return adapter and adapter.openBossMenu and adapter.openBossMenu(resource, role) or false
end

--- Opens the selected gang management menu on the client.
---@param role? string Defaults to the player's current gang.
---@return boolean opened
function TSS.Groups.OpenGangMenu(role)
    if TSS.IsServer() then return false end
    local _, resource, adapter = managementRegistry:Resolve()
    return adapter and adapter.openGangMenu and adapter.openGangMenu(resource, role) or false
end

function getBossRoles(role)
    return TSS.Groups.BossRoles(role)
end

TSS.GetBossRoles = TSS.Groups.BossRoles
