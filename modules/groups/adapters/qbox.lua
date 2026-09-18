TSS.Groups.RegisterAdapter('qbox', TSS.Resources.Qbox, {
    supports = { bossroles = true, jobs = true, gangs = true },
    bossRoles = function(_, role)
        local roles = TSS.Groups.Utils.FindBossRole(TSS.Framework.Jobs(), role)
        if next(roles) then return roles end
        return TSS.Groups.Utils.FindBossRole(TSS.Framework.Gangs(), role)
    end,
}, { priority = 10, aliases = { 'qbx', 'qbx_core' } })

TSS.Groups.RegisterManagementAdapter('qbox', TSS.Resources.QboxManagement, {
    supports = { management = true, jobs = true },
    openBossMenu = function(resource, role)
        local ok = TSS.CallExport(resource, 'OpenBossMenu', role)
        return ok == true
    end,
    openGangMenu = function() return false end,
}, { priority = 30, aliases = { 'qbx_management' } })
