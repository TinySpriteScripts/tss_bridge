TSS.Groups.RegisterAdapter('qb', TSS.Resources.QBCore, {
    supports = { bossroles = true, jobs = true, gangs = true },
    bossRoles = function(_, role)
        local roles = TSS.Groups.Utils.FindBossRole(TSS.Framework.Jobs(), role)
        if next(roles) then return roles end
        return TSS.Groups.Utils.FindBossRole(TSS.Framework.Gangs(), role)
    end,
}, { priority = 20, aliases = { 'qb-core', 'qbcore' } })
