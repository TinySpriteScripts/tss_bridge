-- Public group API. Framework group formats live in adapters.
TSS = TSS or {}
TSS.Groups = TSS.Groups or {}
TSS.Groups.Utils = TSS.Groups.Utils or {}

local registry = TSS.Adapters.Create('Groups')

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
---@param feature 'bossroles'|'jobs'|'gangs'|string
---@return boolean supported
function TSS.Groups.Supports(feature)
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

function getBossRoles(role)
    return TSS.Groups.BossRoles(role)
end

TSS.GetBossRoles = TSS.Groups.BossRoles
