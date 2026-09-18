TSSModuleLoader.Define({
    name = 'Commands',
    files = { 'modules/commands/shared.lua', 'modules/commands/adapters/chat.lua' },
    client = function(context)
        local public = {}
        function public.Register(name, options, handler) return TSS.Commands.Register(context.Caller, name, options, handler) end
        function public.Unregister(name) return TSS.Commands.Unregister(context.Caller, name) end
        function public.Clear() return TSS.Commands.Clear(context.Caller) end
        function public.List() return TSS.Commands.List(0, context.Caller) end
        function public.Refresh() return TSS.Commands.Refresh() end
        context.OnStop(public.Clear)
        return public
    end,
})

RegisterNetEvent('tss_bridge:client:commands', function(list)
    if source ~= 65535 or type(list) ~= 'table' then return end
    TSSModuleLoader.Ensure('Commands')
    TSS.Commands.SetServerSuggestions(list)
end)
AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() or resource == 'chat' or resource == 'tss-chat' then
        TSSModuleLoader.Ensure('Commands')
        TSS.Commands.Refresh()
        TriggerServerEvent('tss_bridge:server:requestCommands')
    end
end)
AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if TSS.Commands and TSS.Commands.RemoveSuggestions then TSS.Commands.RemoveSuggestions() end
    elseif resource == 'tss-chat' then
        if TSS.Commands then TSS.Commands.Refresh() end
        TriggerServerEvent('tss_bridge:server:requestCommands')
    end
end)
