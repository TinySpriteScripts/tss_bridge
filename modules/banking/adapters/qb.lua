local function ensureAccount(resource, society, kind)
    local ok, account = TSS.CallExport(resource, 'GetAccount', society)
    if ok and account then return true end

    local isGang = kind == 'gang' or (kind == nil and TSS.Framework.Gangs()[society] ~= nil)
    local exportName = isGang and 'CreateGangAccount' or 'CreateJobAccount'
    local created = TSS.CallExport(resource, exportName, society, 0)

    if created then Wait(150) end
    return created == true
end

TSS.Banking.RegisterAdapter('qb', TSS.Resources.QbBanking, {
    supports = { society = true, gangs = true },

    getSociety = function(resource, society, kind)
        if not ensureAccount(resource, society, kind) then return 0 end
        local ok, balance = TSS.CallExport(resource, 'GetAccountBalance', society)
        return ok and balance or 0
    end,

    chargeSociety = function(resource, society, amount, kind, reason)
        if not ensureAccount(resource, society, kind) then return false end
        local ok, result = TSS.CallExport(resource, 'RemoveMoney', society, amount, reason)
        return ok and result ~= false
    end,

    fundSociety = function(resource, society, amount, kind, reason)
        if not ensureAccount(resource, society, kind) then return false end
        local ok, result = TSS.CallExport(resource, 'AddMoney', society, amount, reason)
        return ok and result ~= false
    end,
}, { priority = 50, aliases = { 'qb-banking' } })
