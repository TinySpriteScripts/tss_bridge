TSSModuleLoader.Define({
    name = 'Notify',
    files = { 'modules/notify/shared.lua' },
    client = function(context)
        return context.CopyFunctions(TSS.Notify, { 'System', 'Supports', 'Send' })
    end,
})

RegisterNetEvent('tss_bridge:client:notify', function(data)
    if TSSModuleLoader.Ensure('Notify') then TSS.Notify.Receive(data) end
end)

RegisterNetEvent('tss-hud:client:Notify', function(title, message, notifyType, duration)
    if not TSSModuleLoader.Ensure('Notify') then return end
    TSS.Notify.Send(title, message, notifyType, duration)
end)
