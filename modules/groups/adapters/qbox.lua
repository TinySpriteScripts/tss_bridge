TSS.Groups.RegisterAdapter('qbox', TSS.Resources.Qbox, {
    supports = { bossroles = true, jobs = true, gangs = true },
    bossRoles = function(_, role)
        local roles = TSS.Groups.Utils.FindBossRole(TSS.Framework.Jobs(), role)
        if next(roles) then return roles end
        return TSS.Groups.Utils.FindBossRole(TSS.Framework.Gangs(), role)
    end,
}, { priority = 10, aliases = { 'qbx', 'qbx_core' } })
