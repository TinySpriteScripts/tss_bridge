-- Lazy realm-aware implementation owned by the Notify module.
TSS = TSS or {}
TSS.Notify = TSS.Notify or {}

local registry = TSS.Adapters.Create('Notify', { config = 'Notify', fallback = 'native' })

function TSS.Notify.RegisterAdapter(key, resource, adapter, options)
    return registry:Register(key, resource, adapter, options)
end

local function normalizeType(value)
    value = tostring(value or 'info'):lower()
    if value == 'inform' or value == 'primary' or value == 'neutral' then return 'info' end
    if value == 'danger' then return 'error' end
    if value == 'warn' then return 'warning' end
    if value == 'success' or value == 'error' or value == 'warning' then return value end
    return 'info'
end

local function normalize(data, message, notifyType, duration)
    local result = {}

    if type(data) == 'table' then
        for key, value in pairs(data) do result[key] = value end
        result.message = result.message or result.description or result.text
    else
        result.title = data
        result.message = message or data
        result.type = notifyType
        result.duration = duration
    end

    result.title = tostring(result.title or 'TinySprite')
    result.message = tostring(result.message or result.title or '')
    result.type = normalizeType(result.type)
    result.duration = math.max(250, math.min(60000, tonumber(result.duration or result.time) or 4500))
    result.position = result.position or 'top-right'
    result.sound = result.sound == true
    return result
end

local function clientSend(data, preferred)
    local system, resource, adapter = registry:Resolve(preferred or data.adapter)
    if adapter and adapter.send and adapter.send(resource, data) == true then return true end
    if system ~= 'native' then
        local _, fallbackResource, fallback = registry:Fallback()
        return fallback and fallback.send and fallback.send(fallbackResource, data) == true or false
    end
    return false
end

--- Detects the selected notification adapter.
---@param preferred? string Adapter override for this call.
---@return string? system Normalized adapter name.
---@return string? resource Started adapter resource, when applicable.
function TSS.Notify.System(preferred)
    local system, resource = registry:Resolve(preferred)
    return system, resource
end

--- Reports whether a notification adapter supports an option.
---@param feature string Option such as `position`, `icon`, `sound`, or `style`.
---@param preferred? string Adapter override for this check.
---@return boolean supported
function TSS.Notify.Supports(feature, preferred)
    return registry:Supports(feature, preferred)
end

--- Sends a normalized notification through the selected adapter.
---
--- On the client use `Send(data)`. On the server use `Send(source, data)`.
--- Legacy positional title/message/type arguments are also accepted.
---@param first integer|TSSNotifyData|string Target player ID on the server, data table, or legacy title.
---@param second? TSSNotifyData|string Data on the server or legacy message.
---@param third? TSSNotifyType Legacy notification type.
---@param fourth? integer Server target for the legacy form, or legacy duration.
---@param fifth? integer Legacy server duration.
---@return boolean sent
---@usage
--- ```lua
--- TSS.Notify.Send({ title = 'Inventory', description = 'Water added', type = 'success' })
--- TSS.Notify.Send(source, { title = 'Inventory', description = 'Water added', type = 'success' })
--- ```
function TSS.Notify.Send(first, second, third, fourth, fifth, preferred)
    if TSS.IsServer() then
        local source, data

        if type(first) == 'number' then
            source = first
            if type(second) == 'table' then
                data = normalize(second)
            else
                data = normalize({ message = second, type = third, duration = fourth })
            end
        else
            source = fourth
            data = normalize(first, second, third, fifth)
        end

        if type(source) ~= 'number' then
            TSS.Warn('Notify.Send on server needs a player source')
            return false
        end

        data.adapter = TSS.Adapters.Preference('Notify', data.adapter or preferred)
        TriggerClientEvent('tss_bridge:client:notify', source, data)
        return true
    end

    local data = normalize(first, second, third, fifth or fourth)
    data.adapter = data.adapter or preferred
    return clientSend(data)
end

--- Receives a validated server notification on the client transport.
---@private
---@param data TSSNotifyData
---@return boolean sent
function TSS.Notify.Receive(data)
    if TSS.IsServer() or type(data) ~= 'table' then return false end
    return clientSend(normalize(data))
end

if not TSS.IsServer() then
    exports('Notify', function(data, message, notifyType, duration)
        return clientSend(normalize(data, message, notifyType, duration))
    end)
end
