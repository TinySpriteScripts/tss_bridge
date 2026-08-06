local function mutate(exportName, resource, source, moneyType, amount, reason)
    local ok, result = TSS.CallExport(resource, exportName, source, moneyType, amount, reason)
    return ok and result == true
end

TSS.Money.RegisterAdapter('qbox', TSS.Resources.Qbox, {
    balance = function(resource, source, moneyType)
        if TSS.IsServer() then
            local ok, amount = TSS.CallExport(resource, 'GetMoney', source, moneyType)
            return ok and amount or 0
        end
        local data = TSS.Framework.PlayerData()
        return data and data.money and data.money[moneyType] or 0
    end,
    add = function(resource, source, moneyType, amount, reason)
        return mutate('AddMoney', resource, source, moneyType, amount, reason)
    end,
    remove = function(resource, source, moneyType, amount, reason)
        return mutate('RemoveMoney', resource, source, moneyType, amount, reason)
    end,
    set = function(resource, source, moneyType, amount, reason)
        return mutate('SetMoney', resource, source, moneyType, amount, reason)
    end,
}, { priority = 10, aliases = { 'qbx', 'qbx_core' } })
