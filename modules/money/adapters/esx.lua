local function accountName(moneyType)
    return moneyType == 'cash' and 'money' or moneyType
end

local function balance(_, source, moneyType)
    local player = TSS.Framework.Player(source)
    if not player then return 0 end
    local account = accountName(moneyType)

    if TSS.IsServer() then
        if account == 'money' and player.getMoney then return player.getMoney() end
        if player.getAccount then
            local value = player.getAccount(account)
            return value and (value.money or value.amount) or 0
        end
        return 0
    end

    if account == 'money' then return player.money or 0 end
    local accounts = player.accounts or {}
    if accounts[account] then
        local value = accounts[account]
        return type(value) == 'table' and (value.money or value.amount) or value
    end
    for _, value in pairs(accounts) do
        if type(value) == 'table' and value.name == account then return value.money or value.amount or 0 end
    end
    return 0
end

local function mutate(action, _, source, moneyType, amount, reason)
    local player = TSS.Framework.Player(source)
    if not player then return false end
    local account = accountName(moneyType)
    local fn = account == 'money' and player[action .. 'Money'] or player[action .. 'AccountMoney']
    if not TSS.IsCallable(fn) then return false end
    local ok
    if account == 'money' then ok = pcall(fn, amount, reason)
    else ok = pcall(fn, account, amount, reason) end
    return ok
end

TSS.Money.RegisterAdapter('esx', TSS.Resources.ESX, {
    balance = balance,
    add = function(...) return mutate('add', ...) end,
    remove = function(...) return mutate('remove', ...) end,
    set = function(...) return mutate('set', ...) end,
}, { priority = 30, aliases = { 'es_extended' } })
