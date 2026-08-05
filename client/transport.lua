local Loader = TSSModuleLoader

RegisterNetEvent('tss_bridge:client:notify', function(data)
    if Loader.Ensure('Notify') then TSS.Notify.Receive(data) end
end)

RegisterNetEvent('tss-hud:client:Notify', function(title, message, notifyType, duration)
    if not Loader.Ensure('Notify') then return end
    TSS.Notify.Send(title, message, notifyType, duration)
end)

RegisterNetEvent('tss_bridge:client:textui:show', function(data, owner)
    if Loader.Ensure('TextUI') then TSS.TextUI.ReceiveShow(data, owner) end
end)

RegisterNetEvent('tss_bridge:client:textui:hide', function(owner)
    if Loader.Ensure('TextUI') then TSS.TextUI.ReceiveHide(owner) end
end)

RegisterNetEvent('tss_bridge:client:uiNotify', function(data)
    if Loader.Ensure('UI') then TSS.UI.Notify(data) end
end)

RegisterNetEvent('tss_bridge:client:uiProgress', function(data)
    if not Loader.Ensure('UI') then return end
    if data == nil then TSS.UI.HideProgress() else TSS.UI.Progress(data) end
end)
