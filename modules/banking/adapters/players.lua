local function qbMutate(action, source, accountType, value, reason)
    local player = TSS.Framework.Player(source)
    local fn = player and player.Functions and player.Functions[action]
    return TSS.IsCallable(fn) and fn(accountType, value, reason) == true or false
end

TSS.Banking.RegisterPlayerAdapter('qb', TSS.Resources.QBCore, {
    getAccount = function(_, source, accountType)
        local data = TSS.Framework.PlayerData(source)
        return data and data.money and data.money[accountType] or 0
    end,

    addMoney = function(_, source, accountType, amount, reason)
        return qbMutate('AddMoney', source, accountType, amount, reason)
    end,

    removeMoney = function(_, source, accountType, amount, reason)
        return qbMutate('RemoveMoney', source, accountType, amount, reason)
    end,
}, { priority = 20, aliases = { 'qb-core' } })

TSS.Banking.RegisterPlayerAdapter('qbox', TSS.Resources.Qbox, {
    getAccount = function(resource, source, accountType)
        if TSS.IsClient() then
            local data = TSS.Framework.PlayerData()
            return data and data.money and data.money[accountType] or 0
        end

        local ok, value = TSS.CallExport(resource, 'GetMoney', source, accountType)
        return ok and value or 0
    end,

    addMoney = function(resource, source, accountType, amount, reason)
        local ok, result = TSS.CallExport(resource, 'AddMoney', source, accountType, amount, reason)
        return ok and result == true
    end,

    removeMoney = function(resource, source, accountType, amount, reason)
        local ok, result = TSS.CallExport(resource, 'RemoveMoney', source, accountType, amount, reason)
        return ok and result == true
    end,
}, { priority = 10, aliases = { 'qbx_core' } })

local function esxAccount(accountType)
    return accountType == 'cash' and 'money' or accountType
end

local function esxGet(_, source, accountType)
    local player = TSS.Framework.Player(source)
    if not player then return 0 end

    local account = esxAccount(accountType)
    if account == 'money' then
        return TSS.IsServer() and player.getMoney and player.getMoney() or player.money or 0
    end

    local value = player.getAccount and player.getAccount(account)
    return value and (value.money or value.amount) or 0
end

local function esxMutate(action, _, source, accountType, value, reason)
    local player = TSS.Framework.Player(source)
    if not player then return false end

    local account = esxAccount(accountType)
    local fn = account == 'money' and player[action .. 'Money'] or player[action .. 'AccountMoney']
    if not TSS.IsCallable(fn) then return false end

    if account == 'money' then return pcall(fn, value, reason) end
    return pcall(fn, account, value, reason)
end

TSS.Banking.RegisterPlayerAdapter('esx', TSS.Resources.ESX, {
    getAccount = esxGet,

    addMoney = function(...)
        return esxMutate('add', ...)
    end,

    removeMoney = function(...)
        return esxMutate('remove', ...)
    end,
}, { priority = 30, aliases = { 'es_extended' } })
