TSS = TSS or {}
TSS.Notify = TSS.Notify or {}

local function nativeNotify(title, message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message or title or ''))
    EndTextCommandThefeedPostTicker(false, false)
end

local function normalizeType(notifyType)
    notifyType = tostring(notifyType or 'info'):lower()

    if notifyType == 'inform' or notifyType == 'primary' then return 'info' end
    if notifyType == 'error' or notifyType == 'danger' then return 'error' end
    if notifyType == 'warning' or notifyType == 'warn' then return 'warning' end
    if notifyType == 'success' then return 'success' end

    return 'info'
end

local function clientNotify(title, message, notifyType, time)
    notifyType = normalizeType(notifyType)

    if TSS.UI and TSS.UI.Notify then
        TSS.UI.Notify({
            title = title or 'TinySprite',
            message = message or title or '',
            type = notifyType,
            duration = time or 4500,
        })
        return true
    end

    nativeNotify(title, message)
    return true
end

function TSS.Notify.Send(title, message, notifyType, source, time)
    if TSS.IsServer() then
        if not source then
            TSS.Warn('Notify.Send on server needs a player source')
            return false
        end

        TriggerClientEvent('tss_bridge:client:notify', source, title, message, notifyType, time)
        return true
    end

    return clientNotify(title, message, notifyType, time)
end

if TSS.IsClient() then
    RegisterNetEvent('tss_bridge:client:notify', function(title, message, notifyType, time)
        clientNotify(title, message, notifyType, time)
    end)

    RegisterNetEvent('tss-hud:client:Notify', function(title, message, notifyType, time)
        clientNotify(title, message, notifyType, time)
    end)

    exports('Notify', function(title, message, notifyType, time)
        return clientNotify(title, message, notifyType, time)
    end)
end

function notifyPlayer(title, message, notifyType, source, time)
    return TSS.Notify.Send(title, message, notifyType, source, time)
end

TSS.NotifyPlayer = TSS.Notify.Send
