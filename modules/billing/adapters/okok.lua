TSS.Billing.RegisterAdapter('okok', TSS.Resources.OkokBilling, {
    supports = { open = true },
    open = function()
        TriggerEvent('okokBilling:ToggleCreateInvoice')
        return true
    end,
}, { priority = 30, aliases = { 'okokBilling' } })
