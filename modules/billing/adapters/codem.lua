TSS.Billing.RegisterAdapter('codem', TSS.Resources.CodemBilling, {
    supports = { open = true },
    open = function()
        TriggerEvent('codem-billing:client:OpenMenu')
        return true
    end,
}, { priority = 50, aliases = { 'codem-billing' } })
