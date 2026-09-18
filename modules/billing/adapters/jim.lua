TSS.Billing.RegisterAdapter('jim', TSS.Resources.JimPayments, {
    supports = { open = true },
    open = function(_, data)
        TriggerEvent('jim-payments:client:Charge', {
            job = data.job or data.business,
            gang = data.gang,
            coords = data.coords,
            img = data.img,
        })
        return true
    end,
}, { priority = 20, aliases = { 'jim-payments' } })
