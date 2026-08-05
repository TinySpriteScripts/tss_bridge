TSS = TSS or {}
TSS.Money = TSS.Money or {}

local function normalizeType(moneyType)
    moneyType = tostring(moneyType or 'cash'):lower()
    if moneyType == 'money' then return 'cash' end
    return moneyType
end

local function validAmount(amount, allowZero)
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount == math.huge or amount == -math.huge then return nil end
    if allowZero and amount < 0 or not allowZero and amount <= 0 then return nil end
    return amount
end

local function esxAccount(player, moneyType)
    local account = moneyType == 'cash' and 'money' or moneyType
    if account == 'money' and player.getMoney then return player.getMoney() end
    if player.getAccount then
        local value = player.getAccount(account)
        return value and (value.money or value.amount) or 0
    end
    return 0
end

function TSS.Money.Balance(source, moneyType)
    if not TSS.IsServer() then
        moneyType = source
        source = nil
    end
    moneyType = normalizeType(moneyType)

    local system, resource = TSS.Framework.System()
    if system == 'qbox' and TSS.IsServer() then
        local ok, amount = TSS.CallExport(resource, 'GetMoney', source, moneyType)
        return ok and tonumber(amount) or 0
    end

    local player = TSS.Framework.Player(source)
    local playerData = TSS.Framework.PlayerData(source)
    if system == 'esx' and player then
        if TSS.IsServer() then return tonumber(esxAccount(player, moneyType)) or 0 end
        if moneyType == 'cash' then return tonumber(playerData.money) or 0 end
        local accounts = playerData.accounts or {}
        if accounts[moneyType] then
            local account = accounts[moneyType]
            return tonumber(type(account) == 'table' and (account.money or account.amount) or account) or 0
        end
        for _, account in pairs(accounts) do
            if type(account) == 'table' and account.name == moneyType then return tonumber(account.money) or 0 end
        end
        return 0
    end
    return playerData and playerData.money and tonumber(playerData.money[moneyType]) or 0
end

function TSS.Money.Has(source, moneyType, amount)
    if not TSS.IsServer() then
        amount = moneyType
        moneyType = source
        source = nil
    end
    amount = validAmount(amount, true)
    if not amount then return false end
    if not TSS.IsServer() then return TSS.Money.Balance(moneyType) >= amount end
    return TSS.Money.Balance(source, moneyType) >= amount
end

local function mutate(action, source, moneyType, amount, reason)
    if not TSS.IsServer() or type(source) ~= 'number' then return false end
    amount = validAmount(amount, action == 'Set')
    if not amount then return false end
    moneyType = normalizeType(moneyType)
    reason = type(reason) == 'string' and reason:sub(1, 128) or 'tss_bridge'

    local system, resource = TSS.Framework.System()
    if system == 'qbox' then
        local ok, result = TSS.CallExport(resource, action .. 'Money', source, moneyType, amount, reason)
        return ok and result == true
    end

    local player = TSS.Framework.Player(source)
    if not player then return false end

    if system == 'qb' then
        local fn = player.Functions and player.Functions[action .. 'Money']
        return type(fn) == 'function' and fn(moneyType, amount, reason) == true or false
    end

    local account = moneyType == 'cash' and 'money' or moneyType
    local fn
    if action == 'Add' then fn = account == 'money' and player.addMoney or player.addAccountMoney end
    if action == 'Remove' then fn = account == 'money' and player.removeMoney or player.removeAccountMoney end
    if action == 'Set' then fn = account == 'money' and player.setMoney or player.setAccountMoney end
    if type(fn) ~= 'function' then return false end

    local ok = pcall(fn, account == 'money' and amount or account, account == 'money' and reason or amount, account == 'money' and nil or reason)
    return ok
end

function TSS.Money.Add(source, moneyType, amount, reason)
    return mutate('Add', source, moneyType, amount, reason)
end

function TSS.Money.Remove(source, moneyType, amount, reason)
    return mutate('Remove', source, moneyType, amount, reason)
end

function TSS.Money.Set(source, moneyType, amount, reason)
    return mutate('Set', source, moneyType, amount, reason)
end
