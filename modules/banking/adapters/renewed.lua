TSS.Banking.RegisterAdapter('renewed', TSS.Resources.RenewedBanking, {
    supports = {
        society = true,
        transactions = true,
        recordtransaction = true,
        transactionhistory = true,
    },

    getSociety = function(resource, society)
        local ok, balance = TSS.CallExport(resource, 'getAccountMoney', society)
        return ok and balance or 0
    end,

    chargeSociety = function(resource, society, amount)
        local ok, result = TSS.CallExport(resource, 'removeAccountMoney', society, amount)
        return ok and result == true
    end,

    fundSociety = function(resource, society, amount)
        local ok, result = TSS.CallExport(resource, 'addAccountMoney', society, amount)
        return ok and result == true
    end,

    recordTransaction = function(resource, account, data)
        local ok, result = TSS.CallExport(resource, 'handleTransaction', account, data.title, data.amount,
            data.message, data.issuer, data.receiver, data.type, data.transactionId)
        return ok and type(result) == 'table', result
    end,

    getTransactions = function(resource, account)
        local ok, result = TSS.CallExport(resource, 'getAccountTransactions', account)
        return ok and type(result) == 'table' and result or nil
    end,
}, { priority = 10 })
