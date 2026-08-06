-- Public money API. Framework account behaviour lives in adapters.
TSS = TSS or {}
TSS.Money = TSS.Money or {}

local registry = TSS.Adapters.Create('Money')

local function normalizeType(moneyType)
    moneyType = tostring(moneyType or 'cash'):lower()
    return moneyType == 'money' and 'cash' or moneyType
end

local function validAmount(amount, allowZero)
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount == math.huge or amount == -math.huge then return nil end
    if (allowZero and amount < 0) or (not allowZero and amount <= 0) then return nil end
    return amount
end

function TSS.Money.RegisterAdapter(key, resource, adapter, options)
    return registry:Register(key, resource, adapter, options)
end

local function resolve()
    local framework = TSS.Framework.System()
    return registry:Resolve(framework)
end

--- Returns a player's balance for an account type.
---@param source? integer|string
---@param moneyType? TSSMoneyType
---@return number balance
function TSS.Money.Balance(source, moneyType)
    if TSS.IsClient() then
        moneyType = source
        source = nil
    end

    local _, resource, adapter = resolve()
    if not adapter or not adapter.balance then return 0 end
    return tonumber(adapter.balance(resource, source, normalizeType(moneyType))) or 0
end

--- Checks whether a player has at least the requested account balance.
---@param source integer|string
---@param moneyType string|number
---@param amount? number
---@return boolean hasFunds
function TSS.Money.Has(source, moneyType, amount)
    if TSS.IsClient() then
        amount = moneyType
        moneyType = source
        source = nil
    end
    amount = validAmount(amount, true)
    if not amount then return false end
    if TSS.IsClient() then return TSS.Money.Balance(moneyType) >= amount end
    return TSS.Money.Balance(source, moneyType) >= amount
end

local function mutate(action, source, moneyType, amount, reason)
    if not TSS.IsServer() or type(source) ~= 'number' then return false end
    amount = validAmount(amount, action == 'set')
    if not amount then return false end

    local _, resource, adapter = resolve()
    local method = adapter and adapter[action]
    if not method then return false end
    reason = type(reason) == 'string' and reason:sub(1, 128) or 'tss_bridge'
    return method(resource, source, normalizeType(moneyType), amount, reason) == true
end

--- Adds money to a player after validating the amount.
---@param source integer
---@param moneyType TSSMoneyType
---@param amount number
---@param reason? string
---@return boolean success
function TSS.Money.Add(source, moneyType, amount, reason)
    return mutate('add', source, moneyType, amount, reason)
end

--- Removes money from a player after validating the amount.
---@param source integer
---@param moneyType TSSMoneyType
---@param amount number
---@param reason? string
---@return boolean success
function TSS.Money.Remove(source, moneyType, amount, reason)
    return mutate('remove', source, moneyType, amount, reason)
end

--- Sets a player's account balance.
---@param source integer
---@param moneyType TSSMoneyType
---@param amount number
---@param reason? string
---@return boolean success
function TSS.Money.Set(source, moneyType, amount, reason)
    return mutate('set', source, moneyType, amount, reason)
end
