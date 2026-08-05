-- Lazy realm-aware implementation owned by the Notify module.
TSS = TSS or {}
TSS.Notify = TSS.Notify or {}

local aliases = {
    ['tss'] = 'tss',
    ['tss_bridge'] = 'tss',
    ['ox'] = 'ox',
    ['ox_lib'] = 'ox',
    ['qb'] = 'qb',
    ['qb-core'] = 'qb',
    ['qbcore'] = 'qb',
    ['qbox'] = 'qbox',
    ['qbx'] = 'qbox',
    ['qbx_core'] = 'qbox',
    ['okok'] = 'okok',
    ['okoknotify'] = 'okok',
    ['mythic'] = 'mythic',
    ['mythic_notify'] = 'mythic',
    ['wasabi'] = 'wasabi',
    ['wasabi_notify'] = 'wasabi',
    ['native'] = 'native',
}

local resources = {
    ox = TSS.Resources.OxLib,
    qb = TSS.Resources.QBCore,
    qbox = TSS.Resources.Qbox,
    okok = TSS.Resources.OkokNotify,
    mythic = TSS.Resources.MythicNotify,
    wasabi = TSS.Resources.WasabiNotify,
}

local support = {
    tss = { title = true, type = true, duration = true, position = true, icon = true, id = true },
    ox = { title = true, type = true, duration = true, position = true, icon = true, id = true, sound = true, style = true },
    qb = { title = true, type = true, duration = true, icon = true },
    qbox = { title = true, type = true, duration = true, position = true, icon = true, style = true },
    okok = { title = true, type = true, duration = true, sound = true },
    mythic = { type = true, duration = true },
    wasabi = { title = true, type = true, duration = true, icon = true, id = true, sound = true },
    native = { title = true },
}

local function ensureTssUI()
    if TSS.UI and TSS.UI.Notify then return true end
    if TSSModuleLoader and TSSModuleLoader.Ensure then TSSModuleLoader.Ensure('UI') end
    return TSS.UI and TSS.UI.Notify ~= nil or false
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

local function detect(preferred)
    local configured = tostring(preferred or TSS.Config.Notify or 'auto'):lower()

    if configured ~= 'auto' then
        local system = aliases[configured] or configured
        local resource = resources[system]
        if system == 'tss' then
            return ensureTssUI() and system or 'native', nil
        end
        if system == 'native' then return system, nil end
        if resource and TSS.IsStarted(resource) then return system, resource end
        TSS.Warn(('Configured notification system is not started: %s'):format(tostring(resource or configured)))
        return 'native', nil
    end

    if TSS.IsStarted(TSS.Resources.OxLib) then return 'ox', TSS.Resources.OxLib end
    if TSS.IsStarted(TSS.Resources.Qbox) then return 'qbox', TSS.Resources.Qbox end
    if TSS.IsStarted(TSS.Resources.QBCore) then return 'qb', TSS.Resources.QBCore end
    if TSS.IsStarted(TSS.Resources.OkokNotify) then return 'okok', TSS.Resources.OkokNotify end
    if TSS.IsStarted(TSS.Resources.WasabiNotify) then return 'wasabi', TSS.Resources.WasabiNotify end
    if TSS.IsStarted(TSS.Resources.MythicNotify) then return 'mythic', TSS.Resources.MythicNotify end
    if ensureTssUI() then return 'tss', nil end
    return 'native', nil
end

local function nativeNotify(data)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(data.message)
    EndTextCommandThefeedPostTicker(false, false)
    return true
end

local function clientSend(data, preferred)
    local system, resource = detect(preferred or data.adapter)

    if system == 'ox' then
        local ok = TSS.CallExport(resource, 'notify', {
            id = data.id,
            title = data.title,
            description = data.message,
            duration = data.duration,
            position = data.position,
            type = data.type,
            style = data.style,
            icon = data.icon,
            iconAnimation = data.iconAnimation,
            iconColor = data.iconColor,
            sound = data.soundData,
        })
        if ok then return true end
    elseif system == 'qbox' then
        local ok = TSS.CallExport(resource, 'Notify', { text = data.message, caption = data.title }, data.type == 'info' and 'inform' or data.type,
            data.duration, data.subtitle, data.position, data.style, data.icon, data.iconColor)
        if ok then return true end
    elseif system == 'qb' then
        local ok, core = TSS.CallExport(resource, 'GetCoreObject')
        if not ok then core = nil end
        if core and core.Functions and core.Functions.Notify then
            core.Functions.Notify({ text = data.message, caption = data.title }, data.type == 'info' and 'primary' or data.type, data.duration, data.icon)
            return true
        end
    elseif system == 'okok' then
        local ok = TSS.CallExport(resource, 'Alert', data.title, data.message, data.duration, data.type, data.sound)
        if ok then return true end
    elseif system == 'wasabi' then
        local ok = TSS.CallExport(resource, 'notify', data.title, data.message, data.duration, data.type, data.sound, data.icon, data.id)
        if ok then return true end
    elseif system == 'mythic' then
        local ok = TSS.CallExport(resource, 'SendAlert', data.type == 'info' and 'inform' or data.type, data.message, data.duration)
        if ok then return true end
    elseif system == 'tss' and TSS.UI and TSS.UI.Notify then
        return TSS.UI.Notify(data)
    end

    return nativeNotify(data)
end

--- Detects the selected notification adapter.
---@param preferred? string Adapter override for this call.
---@return string? system Normalized adapter name.
---@return string? resource Started adapter resource, when applicable.
function TSS.Notify.System(preferred)
    return detect(preferred)
end

--- Reports whether a notification adapter supports an option.
---@param feature string Option such as `position`, `icon`, `sound`, or `style`.
---@param preferred? string Adapter override for this check.
---@return boolean supported
function TSS.Notify.Supports(feature, preferred)
    local system = detect(preferred)
    return support[system] and support[system][tostring(feature or ''):lower()] == true or false
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
function TSS.Notify.Send(first, second, third, fourth, fifth)
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

        TriggerClientEvent('tss_bridge:client:notify', source, data)
        return true
    end

    return clientSend(normalize(first, second, third, fifth or fourth))
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
