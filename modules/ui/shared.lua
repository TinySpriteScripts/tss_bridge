-- Lazy realm-aware implementation owned by the UI module.
TSS = TSS or {}
TSS.UI = TSS.UI or {}

local function sendClientMessage(action, payload)
    if not TSS.IsClient() then return false end

    SendNUIMessage({
        action = action,
        payload = payload,
    })

    return true
end

--- Sends a notification through the bridge's built-in NUI.
---@param data TSSNotifyData|string Notification data.
---@param source? integer Target player ID when called on the server.
---@return boolean sent
function TSS.UI.Notify(data, source)
    data = type(data) == 'table' and data or { message = tostring(data or '') }

    if TSS.IsServer() then
        if not source then return false end
        TriggerClientEvent('tss_bridge:client:uiNotify', source, data)
        return true
    end

    return sendClientMessage('notify', data)
end

--- Shows or updates the bridge's built-in progress display.
---@param data TSSProgressData|table Progress display data.
---@param source? integer Target player ID when called on the server.
---@return boolean sent
function TSS.UI.Progress(data, source)
    if TSS.IsServer() then
        if not source then return false end
        TriggerClientEvent('tss_bridge:client:uiProgress', source, data)
        return true
    end

    if data ~= nil and type(data) ~= 'table' then data = {} end

    return sendClientMessage('progress', data)
end

--- Hides the bridge's built-in progress display.
---@param source? integer Target player ID when called on the server.
---@return boolean sent
function TSS.UI.HideProgress(source)
    if TSS.IsServer() then
        if not source then return false end
        TriggerClientEvent('tss_bridge:client:uiProgress', source, nil)
        return true
    end

    return sendClientMessage('progress', nil)
end

local activeUiCallback
local activeUiId = 0

local function openInteractive(kind, data, callback)
    if not TSS.IsClient() then return false end
    activeUiId = activeUiId + 1
    data = type(data) == 'table' and data or {}
    data.id = activeUiId
    activeUiCallback = callback
    SetNuiFocus(true, true)
    sendClientMessage(kind, data)
    return activeUiId
end

--- Opens a built-in client menu.
---@param data table Menu definition.
---@param callback? fun(result?: table) Receives the selection or `nil` when closed.
---@return integer|false uiId
function TSS.UI.Menu(data, callback)
    return openInteractive('menu', data, callback)
end

--- Opens a built-in client context menu.
---@param data table Context-menu definition.
---@param callback? fun(result?: table) Receives the selection or `nil` when closed.
---@return integer|false uiId
function TSS.UI.Context(data, callback)
    return openInteractive('context', data, callback)
end

--- Opens a built-in client input dialog.
---@param data table Input definition.
---@param callback? fun(result?: table) Receives submitted values or `nil` when closed.
---@return integer|false uiId
function TSS.UI.Input(data, callback)
    return openInteractive('input', data, callback)
end

--- Closes the active built-in client UI and releases NUI focus.
---@return boolean closed
function TSS.UI.Close()
    if not TSS.IsClient() then return false end
    SetNuiFocus(false, false)
    activeUiCallback = nil
    return sendClientMessage('closeUi', nil)
end

if TSS.IsClient() then
    local function finishInteractive(result)
        SetNuiFocus(false, false)
        local callback = activeUiCallback
        activeUiCallback = nil
        if callback then callback(result) end
    end

    RegisterNUICallback('uiSelect', function(data, cb)
        cb({ ok = true })
        finishInteractive({ index = data.index, value = data.value, id = data.id })
    end)

    RegisterNUICallback('uiSubmit', function(data, cb)
        cb({ ok = true })
        finishInteractive({ values = data.values or {}, id = data.id })
    end)

    RegisterNUICallback('uiClose', function(data, cb)
        cb({ ok = true })
        finishInteractive(nil)
    end)

    AddEventHandler('onClientResourceStop', function(resource)
        if resource == GetCurrentResourceName() then TSS.UI.Close() end
    end)

end
