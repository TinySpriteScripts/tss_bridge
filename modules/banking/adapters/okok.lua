TSS.Banking.RegisterAdapter('okok', TSS.Resources.OkokBanking, {
    supports = {
        society = true,
        transactions = true,
        recordtransaction = true,
        transactionhistory = true,
    },

    getSociety = function(resource, society)
        local ok, account = TSS.CallExport(resource, 'GetAccount', society)
        return ok and tonumber(account) or 0
    end,

    chargeSociety = function(resource, society, amount)
        local ok, result = TSS.CallExport(resource, 'RemoveMoney', society, amount)
        return ok and result ~= false
    end,

    fundSociety = function(resource, society, amount)
        local ok, result = TSS.CallExport(resource, 'AddMoney', society, amount)
        return ok and result ~= false
    end,

    recordTransaction = function(resource, account, data)
        local transaction = {
            sender_identifier = data.senderIdentifier,
            sender_name = data.senderName,
            receiver_identifier = data.receiverIdentifier,
            receiver_name = data.receiverName,
            value = data.amount,
            type = data.type,
            reason = data.reason,
        }
        local ok, result = TSS.CallExport(resource, 'AddTransaction', account, transaction, data.source)
        return ok and result ~= false, result
    end,

    getTransactions = function(resource, account, limit)
        local ok, result = TSS.CallExport(resource, 'GetPlayerTransactions', account, limit)
        return ok and type(result) == 'table' and result or nil
    end,
}, { priority = 30 })
