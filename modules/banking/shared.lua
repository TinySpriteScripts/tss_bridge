TSS = TSS or {}
TSS.Banking = TSS.Banking or {}

local playerRegistry = TSS.Adapters.Create('PlayerBanking')
local societyRegistry = TSS.Adapters.Create('Banking', { config = 'Banking' })
local transactionWarnings = {}

local function amount(value, allowZero)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    if (allowZero and value < 0) or (not allowZero and value <= 0) then return nil end
    return value
end

local function account(value)
    value = tostring(value or 'cash'):lower()
    return value == 'money' and 'cash' or value
end

local function reasonText(reason)
    if type(reason) == 'table' then reason = reason.reason or reason.message end
    if reason == nil or reason == '' then return 'tss_bridge' end
    return tostring(reason)
end

local function transactionType(value)
    value = type(value) == 'string' and value:lower() or value
    if value == 'deposit' or value == 'credit' or value == 'fund' or value == 'add' then return 'deposit' end
    if value == 'withdraw' or value == 'debit' or value == 'charge' or value == 'remove' then return 'withdraw' end
end

local function transactionData(accountName, data)
    if type(data) ~= 'table' then return nil end

    local value = amount(data.amount or data.value, false)
    local kind = transactionType(data.type or data.transactionType or data.statementType)
    if not value or not kind then return nil end

    local reason = reasonText(data)
    local issuer = tostring(data.issuer or data.senderName or (kind == 'withdraw' and accountName or 'External'))
    local receiver = tostring(data.receiver or data.receiverName or (kind == 'deposit' and accountName or 'External'))
    local source = tonumber(data.source)
    if source and (source ~= source or source == math.huge or source == -math.huge or source < 1) then source = nil end
    local accountType = tostring(data.accountType or data.kind or 'player'):lower()
    if accountType ~= 'player' and accountType ~= 'job' and accountType ~= 'gang' and accountType ~= 'shared' then
        return nil
    end

    return {
        account = accountName,
        amount = value,
        type = kind,
        reason = reason,
        message = tostring(data.message or reason),
        title = tostring(data.title or accountName),
        issuer = issuer,
        receiver = receiver,
        senderIdentifier = tostring(data.senderIdentifier or data.issuerIdentifier or issuer),
        receiverIdentifier = tostring(data.receiverIdentifier or receiver),
        senderName = tostring(data.senderName or issuer),
        receiverName = tostring(data.receiverName or receiver),
        source = source and math.floor(source) or nil,
        transactionId = data.transactionId or data.transId or data.trans_id,
        accountType = accountType,
    }
end

local function normaliseTransaction(accountName, value)
    if type(value) ~= 'table' then return nil end

    local result = {}
    for key, field in pairs(value) do result[key] = field end
    result.account = result.account or accountName
    result.id = result.id or result.trans_id or result.transaction_id
    result.amount = tonumber(result.amount or result.value) or 0
    result.type = transactionType(result.type or result.trans_type or result.statement_type)
        or result.type or result.trans_type or result.statement_type
    result.reason = result.reason or result.message
    result.issuer = result.issuer or result.sender_name
    result.receiver = result.receiver or result.receiver_name
    result.time = result.time or result.date or result.created_at
    return result
end

function TSS.Banking.RegisterPlayerAdapter(key, resource, adapter, options)
    return playerRegistry:Register(key, resource, adapter, options)
end

function TSS.Banking.RegisterAdapter(key, resource, adapter, options)
    return societyRegistry:Register(key, resource, adapter, options)
end

local function playerAdapter()
    local framework = TSS.Framework.System()
    local _, resource, adapter = playerRegistry:Resolve(framework)
    return resource, adapter
end

function TSS.Banking.System(preferred)
    local system, resource = societyRegistry:Resolve(preferred)
    return system, resource
end

function TSS.Banking.Supports(feature, preferred)
    return societyRegistry:Supports(feature, preferred)
end

function TSS.Banking.GetAccount(source, accountType)
    if TSS.IsClient() then
        accountType = source
        source = nil
    end

    local resource, adapter = playerAdapter()
    if not adapter or not adapter.getAccount then return 0 end
    return tonumber(adapter.getAccount(resource, source, account(accountType))) or 0
end

local function playerMutate(method, source, accountType, value, reason)
    if not TSS.IsServer() or type(source) ~= 'number' then return false end
    value = amount(value, false)
    if not value then return false end

    local resource, adapter = playerAdapter()
    if not adapter or not adapter[method] then return false end
    return adapter[method](resource, source, account(accountType), value, reasonText(reason)) == true
end

function TSS.Banking.AddMoney(source, accountType, value, reason)
    return playerMutate('addMoney', source, accountType, value, reason)
end

function TSS.Banking.RemoveMoney(source, accountType, value, reason)
    return playerMutate('removeMoney', source, accountType, value, reason)
end

function TSS.Banking.GetSociety(society, kind, preferred)
    if type(society) ~= 'string' or society == '' then return 0 end

    local _, resource, adapter = societyRegistry:Resolve(preferred)
    if not adapter or not adapter.getSociety then return 0 end
    return tonumber(adapter.getSociety(resource, society, kind)) or 0
end

local function societyMutate(method, society, value, kind, reason, preferred)
    if not TSS.IsServer() or type(society) ~= 'string' or society == '' then return false end

    value = amount(value, false)
    if not value then return false end

    local _, resource, adapter = societyRegistry:Resolve(preferred)
    if not adapter or not adapter[method] then return false end

    local completed = adapter[method](resource, society, value, kind, reasonText(reason)) == true
    if not completed or adapter.mutationRecordsTransaction or not adapter.recordTransaction then return completed end

    local data = type(reason) == 'table' and reason or { reason = reason }
    data = transactionData(society, {
        amount = value,
        type = method == 'fundSociety' and 'deposit' or 'withdraw',
        reason = data.reason,
        message = data.message,
        title = data.title,
        issuer = data.issuer,
        receiver = data.receiver,
        senderIdentifier = data.senderIdentifier,
        receiverIdentifier = data.receiverIdentifier,
        senderName = data.senderName,
        receiverName = data.receiverName,
        source = data.source,
        transactionId = data.transactionId,
        accountType = data.accountType or kind,
    })
    local recorded = data and adapter.recordTransaction(resource, society, data)
    local warningKey = tostring(resource or 'fallback')
    if recorded ~= true and not transactionWarnings[warningKey] then
        transactionWarnings[warningKey] = true
        TSS.Warn(('Banking transaction history could not be recorded for %s'):format(society))
    end
    return true
end

function TSS.Banking.ChargeSociety(society, value, kind, reason, preferred)
    return societyMutate('chargeSociety', society, value, kind, reason, preferred)
end

function TSS.Banking.FundSociety(society, value, kind, reason, preferred)
    return societyMutate('fundSociety', society, value, kind, reason, preferred)
end

function TSS.Banking.RecordTransaction(accountName, data, preferred)
    if not TSS.IsServer() or type(accountName) ~= 'string' or accountName == '' then return false end

    data = transactionData(accountName, data)
    if not data then return false end

    local _, resource, adapter = societyRegistry:Resolve(preferred)
    if not adapter or not adapter.recordTransaction then return false end

    local ok, record = adapter.recordTransaction(resource, accountName, data)
    return ok == true, normaliseTransaction(accountName, record)
end

function TSS.Banking.GetTransactions(accountName, limit, preferred)
    if not TSS.IsServer() or type(accountName) ~= 'string' or accountName == '' then return nil end

    limit = limit == nil and 50 or tonumber(limit)
    if not limit or limit ~= limit or limit < 0 then return nil end
    limit = math.min(math.floor(limit), 200)
    if limit == 0 then return {} end

    local _, resource, adapter = societyRegistry:Resolve(preferred)
    if not adapter or not adapter.getTransactions then return nil end

    local values = adapter.getTransactions(resource, accountName, limit)
    if type(values) ~= 'table' then return nil end

    local transactions = {}
    for i = 1, math.min(#values, limit) do
        local transaction = normaliseTransaction(accountName, values[i])
        if transaction then transactions[#transactions + 1] = transaction end
    end
    return transactions
end
