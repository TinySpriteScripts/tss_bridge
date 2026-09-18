local function accountBalance(account)
    if type(account) == 'table' then
        return account.balance or account.amount or account.money or 0
    end
    return account or 0
end

TSS.Banking.RegisterAdapter('fd', TSS.Resources.FdBanking, {
    supports = { society = true },

    getSociety = function(resource, society)
        local ok, account = TSS.CallExport(resource, 'GetAccount', society)
        return ok and accountBalance(account) or 0
    end,

    chargeSociety = function(resource, society, amount)
        local ok, result = TSS.CallExport(resource, 'RemoveMoney', society, amount)
        return ok and result ~= false
    end,

    fundSociety = function(resource, society, amount)
        local ok, result = TSS.CallExport(resource, 'AddMoney', society, amount)
        return ok and result ~= false
    end,
}, { priority = 20, aliases = { 'fd_banking' } })
