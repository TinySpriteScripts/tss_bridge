TSS = TSS or {}
TSS.Notify = TSS.Notify or {}

local function nativeNotify(title, message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message or title or ''))
    EndTextCommandThefeedPostTicker(false, false)
end

local function clientNotify(title, message, notifyType)
    notifyType = notifyType or 'inform'

    if TSS.IsStarted(TSS.Resources.OxLib) then
        exports[TSS.Resources.OxLib]:notify({
            title = title,
            description = message,
            type = notifyType,
        })
        return true
    end

    if TSS.IsStarted(TSS.Resources.QBCore) then
        TriggerEvent('QBCore:Notify', message or title, notifyType)
        return true
    end

    nativeNotify(title, message)
    return true
end

function TSS.Notify.Send(title, message, notifyType, source)
    if TSS.IsServer() then
        if not source then
            TSS.Warn('Notify.Send on server needs a player source')
            return false
        end

        TriggerClientEvent('tss_bridge:client:notify', source, title, message, notifyType)
        return true
    end

    return clientNotify(title, message, notifyType)
end

if TSS.IsClient() then
    RegisterNetEvent('tss_bridge:client:notify', function(title, message, notifyType)
        clientNotify(title, message, notifyType)
    end)
end

function notifyPlayer(title, message, notifyType, source)
    return TSS.Notify.Send(title, message, notifyType, source)
end

TSS.NotifyPlayer = TSS.Notify.Send
