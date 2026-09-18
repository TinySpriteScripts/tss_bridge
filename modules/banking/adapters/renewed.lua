TSS.Banking.RegisterAdapter('renewed', TSS.Resources.RenewedBanking, {
    supports = { society = true },

    getSociety = function(resource, society)
        local ok, balance = TSS.CallExport(resource, 'getAccountMoney', society)
        return ok and balance or 0
    end,

    chargeSociety = function(resource, society, amount)
        local ok, result = TSS.CallExport(resource, 'removeAccountMoney', society, amount)
        return ok and result ~= false
    end,

    fundSociety = function(resource, society, amount)
        local ok, result = TSS.CallExport(resource, 'addAccountMoney', society, amount)
        return ok and result ~= false
    end,
}, { priority = 10, aliases = { 'renewed-banking', 'Renewed-Banking' } })
