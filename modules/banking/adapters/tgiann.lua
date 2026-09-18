local function isGang(kind, society)
    if kind == 'gang' then return true end
    if kind == 'job' then return false end
    return not TSS.Framework.Jobs()[society] and TSS.Framework.Gangs()[society] ~= nil
end

TSS.Banking.RegisterAdapter('tgiann', TSS.Resources.TgiannBank, {
    supports = { society = true, gangs = true },

    getSociety = function(resource, society, kind)
        local exportName = isGang(kind, society) and 'GetGangAccountBalance' or 'GetJobAccountBalance'
        local ok, balance = TSS.CallExport(resource, exportName, society)
        return ok and balance or 0
    end,

    chargeSociety = function(resource, society, amount, kind)
        local exportName = isGang(kind, society) and 'RemoveGangMoney' or 'RemoveJobMoney'
        local ok, result = TSS.CallExport(resource, exportName, society, amount)
        return ok and result ~= false
    end,

    fundSociety = function(resource, society, amount, kind)
        local exportName = isGang(kind, society) and 'AddGangMoney' or 'AddJobMoney'
        local ok, result = TSS.CallExport(resource, exportName, society, amount)
        return ok and result ~= false
    end,
}, { priority = 40, aliases = { 'tgiann-bank' } })
