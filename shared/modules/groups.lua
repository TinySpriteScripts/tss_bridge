TSS = TSS or {}
TSS.Groups = TSS.Groups or {}

function TSS.Groups.BossRoles(role)
    local roles = {}
    local group = (Jobs and Jobs[role]) or (Gangs and Gangs[role])

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
