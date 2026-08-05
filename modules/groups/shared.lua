-- Lazy shared implementation owned by the Groups module.
TSS = TSS or {}
TSS.Groups = TSS.Groups or {}

--- Finds the minimum boss grade for a job or gang.
---@param role string Job or gang name.
---@return table<string, integer> roles Role mapped to its minimum boss grade.
function TSS.Groups.BossRoles(role)
    local roles = {}
    local jobs = rawget(_G, 'Jobs')
    local gangs = rawget(_G, 'Gangs')

    if TSS.Framework then
        jobs = jobs or (TSS.Framework.Jobs and TSS.Framework.Jobs())
        gangs = gangs or (TSS.Framework.Gangs and TSS.Framework.Gangs())
    end

    local group = (jobs and jobs[role]) or (gangs and gangs[role])

    if not group or not group.grades then
        return roles
    end

    for grade, data in pairs(group.grades) do
        if data.isboss or data.isBoss or data.bankAuth then
            local level = tonumber(grade)
            if level then
                roles[role] = roles[role] and math.min(roles[role], level) or level
            end
        end
    end

    return roles
end

function getBossRoles(role)
    return TSS.Groups.BossRoles(role)
end

TSS.GetBossRoles = TSS.Groups.BossRoles
