-- Lazy realm-aware implementation owned by the TextUI module.
TSS = TSS or {}
TSS.TextUI = TSS.TextUI or {}

local active
local activeOwner
local nativeThread = false

local aliases = {
    ['ox'] = 'ox', ['ox_lib'] = 'ox',
    ['qb'] = 'qb', ['qb-core'] = 'qb', ['qbcore'] = 'qb',
    ['native'] = 'native',
}

local support = {
    ox = { position = true, icon = true, style = true },
    qb = { position = true },
    native = {},
}

local function detect(preferred)
    local configured = tostring(preferred or TSS.Config.TextUI or 'auto'):lower()
    if configured ~= 'auto' then
        local system = aliases[configured] or configured
        if system == 'native' then return system end
        local resource = system == 'ox' and TSS.Resources.OxLib or system == 'qb' and TSS.Resources.QBCore
        if resource and TSS.IsStarted(resource) then return system, resource end
        TSS.Warn(('Configured text UI system is not started: %s'):format(tostring(resource or configured)))
        return 'native'
    end

    if TSS.IsStarted(TSS.Resources.OxLib) then return 'ox', TSS.Resources.OxLib end
    if TSS.IsStarted(TSS.Resources.QBCore) then return 'qb', TSS.Resources.QBCore end
    return 'native'
end

local function normalize(data)
    if type(data) ~= 'table' then data = { text = tostring(data or '') } end
    return {
        text = tostring(data.text or data.label or data.message or ''),
        position = data.position or 'right-center',
        icon = data.icon,
        iconColor = data.iconColor,
        iconAnimation = data.iconAnimation,
        style = data.style,
        alignIcon = data.alignIcon,
        adapter = data.adapter,
    }
end

local function nativeShow(data)
    active = data
    if nativeThread then return true end
    nativeThread = true

    CreateThread(function()
        while active do
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(active.text)
            EndTextCommandDisplayHelp(0, false, true, -1)
            Wait(0)
        end
        nativeThread = false
    end)

    return true
end

local function clientShow(data, owner)
    data = normalize(data)
    local system, resource = detect(data.adapter)
    local ok

    if system == 'ox' then
        ok = TSS.CallExport(resource, 'showTextUI', data.text, {
            position = data.position,
            icon = data.icon,
            iconColor = data.iconColor,
            iconAnimation = data.iconAnimation,
            style = data.style,
            alignIcon = data.alignIcon,
        })
    elseif system == 'qb' then
        local position = data.position:find('left') and 'left' or data.position:find('top') and 'top' or 'right'
        ok = TSS.CallExport(resource, 'DrawText', data.text, position)
    else
        ok = nativeShow(data)
    end

    if ok then
        active = data
        activeOwner = owner
        return true
    end
    activeOwner = owner
    return nativeShow(data)
end

local function clientHide(owner, force)
    if owner and activeOwner and owner ~= activeOwner and not force then return false end
    local system, resource = detect(active and active.adapter)

    if system == 'ox' then
        TSS.CallExport(resource, 'hideTextUI')
    elseif system == 'qb' then
        TSS.CallExport(resource, 'HideText')
    end

    active = nil
    activeOwner = nil
    return true
end

--- Detects the selected TextUI adapter.
---@param preferred? string Adapter override for this call.
---@return string? system
---@return string? resource
function TSS.TextUI.System(preferred)
    return detect(preferred)
end

--- Reports whether a TextUI adapter supports an option.
---@param feature string Option such as `position`, `icon`, or `style`.
---@param preferred? string Adapter override for this check.
---@return boolean supported
function TSS.TextUI.Supports(feature, preferred)
    local system = detect(preferred)
    return support[system] and support[system][tostring(feature or ''):lower()] == true or false
end

--- Shows TextUI for the local player or a selected server player.
---@param first integer|TSSTextUIData|string Target player ID on the server, otherwise display data.
---@param second? TSSTextUIData|string Server-side display data.
---@param owner? string Internal caller namespace.
---@return boolean shown
---@usage
--- ```lua
--- TSS.TextUI.Show({ text = '[E] Open garage', icon = 'car' }) -- client
--- TSS.TextUI.Show(source, { text = '[E] Open garage' })       -- server
--- ```
function TSS.TextUI.Show(first, second, owner)
    if TSS.IsServer() then
        if type(first) ~= 'number' then return false end
        TriggerClientEvent('tss_bridge:client:textui:show', first, normalize(second), owner)
        return true
    end
    return clientShow(first, second)
end

--- Hides TextUI for the local player or a selected server player.
---@param first? integer|string Target player ID on the server; internal owner on the client.
---@param owner? string Internal caller namespace.
---@return boolean hidden
function TSS.TextUI.Hide(first, owner)
    if TSS.IsServer() then
        if type(first) ~= 'number' then return false end
        TriggerClientEvent('tss_bridge:client:textui:hide', first, owner)
        return true
    end
    return clientHide(first)
end

--- Returns the active local TextUI state.
---@return boolean isOpen
---@return TSSTextUIData? data
---@return string? owner
function TSS.TextUI.IsOpen()
    return active ~= nil, active, activeOwner
end

--- Receives a validated server TextUI request on the client transport.
---@private
---@param data TSSTextUIData
---@param owner? string
---@return boolean shown
function TSS.TextUI.ReceiveShow(data, owner)
    if TSS.IsServer() or type(data) ~= 'table' then return false end
    return clientShow(data, owner)
end

--- Receives a validated server TextUI hide request on the client transport.
---@private
---@param owner? string
---@return boolean hidden
function TSS.TextUI.ReceiveHide(owner)
    if TSS.IsServer() then return false end
    return clientHide(owner, false)
end

if not TSS.IsServer() then
    AddEventHandler('onClientResourceStop', function(resource)
        if resource == GetCurrentResourceName() then clientHide(nil, true) end
    end)
end
