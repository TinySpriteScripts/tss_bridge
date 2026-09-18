TSS.Billing.RegisterAdapter('tgg', TSS.Resources.TggBilling, {
    supports = { open = true },
    open = function(resource)
        local ok = TSS.CallExport(resource, 'OpenBillingMenu')
        return ok == true
    end,
}, { priority = 40, aliases = { 'tgg-billing' } })
