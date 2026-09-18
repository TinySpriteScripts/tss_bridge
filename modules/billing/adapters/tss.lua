TSS.Billing.RegisterAdapter('tss', TSS.Resources.TssBossMenu, {
    supports = { open = true },
    open = function(resource, data)
        local account = data.business or data.job or data.gang
        local ok = TSS.CallExport(resource, 'OpenBillingMenu', data.gang ~= nil, account)
        return ok == true
    end,
}, { priority = 10, aliases = { 'tss-bossmenu' } })
