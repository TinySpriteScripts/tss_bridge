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

function TSS.UI.Notify(data, source)
    data = type(data) == 'table' and data or { message = tostring(data or '') }

    if TSS.IsServer() then
        if not source then return false end
        TriggerClientEvent('tss_bridge:client:uiNotify', source, data)
        return true
    end

    return sendClientMessage('notify', data)
end

function TSS.UI.Progress(data, source)
    if TSS.IsServer() then
        if not source then return false end
        TriggerClientEvent('tss_bridge:client:uiProgress', source, data)
        return true
    end

    if data ~= nil and type(data) ~= 'table' then data = {} end

    return sendClientMessage('progress', data)
end

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

function TSS.UI.Menu(data, callback)
    return openInteractive('menu', data, callback)
end

function TSS.UI.Context(data, callback)
    return openInteractive('context', data, callback)
end

function TSS.UI.Input(data, callback)
    return openInteractive('input', data, callback)
end

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
