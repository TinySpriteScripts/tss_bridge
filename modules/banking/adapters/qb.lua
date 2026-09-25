local function ensureAccount(resource, society, kind)
    local ok, account = TSS.CallExport(resource, 'GetAccount', society)
    if ok and account then return true end

    local isGang
    if kind == 'gang' then
        isGang = true
    elseif kind == 'job' then
        isGang = false
    elseif TSS.Framework.Jobs()[society] ~= nil then
        isGang = false
    elseif TSS.Framework.Gangs()[society] ~= nil then
        isGang = true
    else
        return false
    end

    local exportName = isGang and 'CreateGangAccount' or 'CreateJobAccount'
    local called, created = TSS.CallExport(resource, exportName, society, 0)
    if not called or not created then return false end

    local verified, newAccount = TSS.CallExport(resource, 'GetAccount', society)
    return verified and newAccount ~= nil
end

TSS.Banking.RegisterAdapter('qb', TSS.Resources.QbBanking, {
    supports = { society = true, gangs = true, recordtransaction = true },
    mutationRecordsTransaction = true,

    getSociety = function(resource, society, kind)
        if not ensureAccount(resource, society, kind) then return 0 end
        local ok, balance = TSS.CallExport(resource, 'GetAccountBalance', society)
        return ok and balance or 0
    end,

    chargeSociety = function(resource, society, amount, kind, reason)
        if not ensureAccount(resource, society, kind) then return false end
        local ok, result = TSS.CallExport(resource, 'RemoveMoney', society, amount, reason)
        return ok and result == true
    end,

    fundSociety = function(resource, society, amount, kind, reason)
        if not ensureAccount(resource, society, kind) then return false end
        local ok, result = TSS.CallExport(resource, 'AddMoney', society, amount, reason)
        return ok and result == true
    end,

    recordTransaction = function(resource, account, data)
        if not data.source or data.source < 1 then return false end
        local ok, result = TSS.CallExport(resource, 'CreateBankStatement', data.source, account, data.amount,
            data.reason, data.type, data.accountType)
        return ok and result == true
    end,
}, { priority = 50 })
