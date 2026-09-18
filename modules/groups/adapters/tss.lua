TSS.Groups.RegisterManagementAdapter('tss', TSS.Resources.TssBossMenu, {
    supports = { management = true, jobs = true, gangs = true },
    openBossMenu = function(resource, role)
        local ok = TSS.CallExport(resource, 'OpenBillingMenu', false, role)
        return ok == true
    end,
    openGangMenu = function(resource, role)
        local ok = TSS.CallExport(resource, 'OpenBillingMenu', true, role)
        return ok == true
    end,
}, { priority = 10, aliases = { 'tss-bossmenu' } })
