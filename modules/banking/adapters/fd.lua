local function isGang(kind, society)
    if kind == 'gang' then return true end
    if kind == 'job' then return false end
    return TSS.Framework.Jobs()[society] == nil and TSS.Framework.Gangs()[society] ~= nil
end

local function exportName(kind, society, jobExport, gangExport)
    return isGang(kind, society) and gangExport or jobExport
end

TSS.Banking.RegisterAdapter('fd', TSS.Resources.FdBanking, {
    supports = { society = true, gangs = true },
    mutationRecordsTransaction = true,

    getSociety = function(resource, society, kind)
        local ok, balance = TSS.CallExport(resource,
            exportName(kind, society, 'GetAccount', 'GetGangAccount'), society)
        return ok and tonumber(balance) or 0
    end,

    chargeSociety = function(resource, society, amount, kind, reason)
        local ok, result = TSS.CallExport(resource,
            exportName(kind, society, 'RemoveMoney', 'RemoveGangMoney'), society, amount, reason)
        return ok and result == true
    end,

    fundSociety = function(resource, society, amount, kind, reason)
        local ok, result = TSS.CallExport(resource,
            exportName(kind, society, 'AddMoney', 'AddGangMoney'), society, amount, reason)
        return ok and result == true
    end,
}, { priority = 20 })
