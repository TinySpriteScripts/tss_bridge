TSS = TSS or {}
TSS.Banking = TSS.Banking or {}

local playerRegistry = TSS.Adapters.Create('PlayerBanking')
local societyRegistry = TSS.Adapters.Create('Banking', { config = 'Banking' })

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
    return adapter[method](resource, source, account(accountType), value, reason or 'tss_bridge') == true
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
    return adapter[method](resource, society, value, kind, reason or 'tss_bridge') == true
end

function TSS.Banking.ChargeSociety(society, value, kind, reason, preferred)
    return societyMutate('chargeSociety', society, value, kind, reason, preferred)
end

function TSS.Banking.FundSociety(society, value, kind, reason, preferred)
    return societyMutate('fundSociety', society, value, kind, reason, preferred)
end
