-- Lazy realm-aware implementation owned by the Money module.
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

--- Returns a player's balance for an account type.
---@param source? integer|string Server player ID, or the account type when called on the client.
---@param moneyType? TSSMoneyType Account type on the server; defaults to `cash`.
---@return number balance
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

--- Checks whether a player has at least the requested account balance.
---@param source integer|string Server player ID, or the account type on the client.
---@param moneyType string|number Account type on the server, or amount on the client.
---@param amount? number Amount required on the server.
---@return boolean hasFunds
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
