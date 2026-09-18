-- Lazy realm-aware implementation owned by the TextUI module.
TSS = TSS or {}
TSS.TextUI = TSS.TextUI or {}

local active
local activeOwner
local activeAdapter
local activeResource
local registry = TSS.Adapters.Create('TextUI', { config = 'TextUI', fallback = 'native' })

function TSS.TextUI.RegisterAdapter(key, resource, adapter, options)
    return registry:Register(key, resource, adapter, options)
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

local function clientShow(data, owner)
    data = normalize(data)
    if activeAdapter and activeAdapter.hide then activeAdapter.hide(activeResource) end
    active, activeOwner, activeAdapter, activeResource = nil, nil, nil, nil
    local system, resource, adapter = registry:Resolve(data.adapter)
    local ok = adapter and adapter.show and adapter.show(resource, data) == true

    if not ok and system ~= 'native' then
        system, resource, adapter = registry:Fallback()
        ok = adapter and adapter.show and adapter.show(resource, data) == true
    end

    if ok then
        active = data
        activeOwner = owner
        activeAdapter = adapter
        activeResource = resource
        return true
    end
    return false
end

local function clientHide(owner, force)
    if owner and activeOwner and owner ~= activeOwner and not force then return false end
    if activeAdapter and activeAdapter.hide then activeAdapter.hide(activeResource) end

    active = nil
    activeOwner = nil
    activeAdapter = nil
    activeResource = nil
    return true
end

--- Detects the selected TextUI adapter.
---@param preferred? string Adapter override for this call.
---@return string? system
---@return string? resource
function TSS.TextUI.System(preferred)
    local system, resource = registry:Resolve(preferred)
    return system, resource
end

--- Reports whether a TextUI adapter supports an option.
---@param feature string Option such as `position`, `icon`, or `style`.
---@param preferred? string Adapter override for this check.
---@return boolean supported
function TSS.TextUI.Supports(feature, preferred)
    return registry:Supports(feature, preferred)
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
        local data = normalize(second)
        data.adapter = TSS.Adapters.Preference('TextUI', data.adapter)
        TriggerClientEvent('tss_bridge:client:textui:show', first, data, owner)
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
