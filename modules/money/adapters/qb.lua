local function player(source)
    return TSS.Framework.Player(source)
end

local function mutate(action, source, moneyType, amount, reason)
    local value = player(source)
    local fn = value and value.Functions and value.Functions[action .. 'Money']
    return TSS.IsCallable(fn) and fn(moneyType, amount, reason) == true or false
end

TSS.Money.RegisterAdapter('qb', TSS.Resources.QBCore, {
    balance = function(_, source, moneyType)
        local data = TSS.Framework.PlayerData(source)
        return data and data.money and data.money[moneyType] or 0
    end,
    add = function(_, source, moneyType, amount, reason)
        return mutate('Add', source, moneyType, amount, reason)
    end,
    remove = function(_, source, moneyType, amount, reason)
        return mutate('Remove', source, moneyType, amount, reason)
    end,
    set = function(_, source, moneyType, amount, reason)
        return mutate('Set', source, moneyType, amount, reason)
    end,
}, { priority = 20, aliases = { 'qb-core', 'qbcore' } })
