TSS.Groups.RegisterAdapter('esx', TSS.Resources.ESX, {
    supports = { bossroles = true, jobs = true },
    bossRoles = function(_, role)
        return TSS.Groups.Utils.FindBossRole(TSS.Framework.Jobs(), role)
    end,
}, { priority = 30, aliases = { 'es_extended' } })
