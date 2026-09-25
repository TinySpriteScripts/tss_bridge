local function getAccount(resource, societyName)
    local ok, society = TSS.CallExport(resource, 'GetSociety', societyName)
    if not ok or not society then return nil end

    local pending = promise.new()
    TriggerEvent('esx_addonaccount:getSharedAccount', society.account, function(account)
        pending:resolve(account)
    end)

    return Citizen.Await(pending)
end

TSS.Banking.RegisterAdapter('esx', TSS.Resources.EsxSociety, {
    supports = { society = true },

    getSociety = function(resource, society)
        local account = getAccount(resource, society)
        return account and account.money or 0
    end,

    chargeSociety = function(resource, society, amount)
        local account = getAccount(resource, society)
        if not account or account.money < amount then return false end

        account.removeMoney(amount)
        return true
    end,

    fundSociety = function(resource, society, amount)
        local account = getAccount(resource, society)
        if not account then return false end

        account.addMoney(amount)
        return true
    end,
}, { priority = 60 })
