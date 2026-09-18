TSSModuleLoader.Define({
    name = 'Commands',
    files = { 'modules/commands/shared.lua', 'modules/commands/adapters/tss_chat.lua' },
    server = function(context)
        local public = {}
        function public.Register(name, options, handler) return TSS.Commands.Register(context.Caller, name, options, handler) end
        function public.Unregister(name) return TSS.Commands.Unregister(context.Caller, name) end
        function public.Clear() return TSS.Commands.Clear(context.Caller) end
        function public.List(source) return TSS.Commands.List(source or 0, context.Caller) end
        function public.Refresh() return TSS.Commands.Refresh() end
        context.OnStop(public.Clear)
        return public
    end,
})

-- tss-chat queries this provider for each player, including permission changes.
exports('GetBridgeCommandList', function(source)
    if not TSSModuleLoader.Ensure('Commands') then return {} end
    return TSS.Commands.List(tonumber(source) or -1)
end)

local requestedAt = {}
RegisterNetEvent('tss_bridge:server:requestCommands', function()
    local player = source
    if player <= 0 then return end
    local now = GetGameTimer()
    if requestedAt[player] and now - requestedAt[player] < 1000 then return end
    requestedAt[player] = now
    TSSModuleLoader.Ensure('Commands')
    TriggerClientEvent('tss_bridge:client:commands', player, TSS.Commands.List(player))
end)
AddEventHandler('playerDropped', function() requestedAt[source] = nil end)
