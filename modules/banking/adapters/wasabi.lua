TSS.Banking.RegisterAdapter('wasabi', TSS.Resources.WasabiBanking, {
    supports = { society = true },

    getSociety = function(resource, society)
        local ok, balance = TSS.CallExport(resource, 'GetAccountBalance', society, 'society')
        return ok and balance or 0
    end,

    chargeSociety = function(resource, society, amount)
        local ok, result = TSS.CallExport(resource, 'RemoveMoney', 'society', society, amount)
        return ok and result ~= false
    end,

    fundSociety = function(resource, society, amount)
        local ok, result = TSS.CallExport(resource, 'AddMoney', 'society', society, amount)
        return ok and result ~= false
    end,
}, { priority = 70 })
