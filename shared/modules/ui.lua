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

if TSS.IsClient() then
    RegisterNetEvent('tss_bridge:client:uiNotify', function(data)
        TSS.UI.Notify(data)
    end)

    RegisterNetEvent('tss_bridge:client:uiProgress', function(data)
        if data == nil then
            TSS.UI.HideProgress()
        else
            TSS.UI.Progress(data)
        end
    end)
end
