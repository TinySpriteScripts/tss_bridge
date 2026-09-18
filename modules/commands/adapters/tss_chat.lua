-- Optional metadata provider; execution always remains in the bridge.
local resource = GetCurrentResourceName()
local registered = false
function TSS.Commands.RefreshTssChat()
    if GetResourceState('tss-chat') ~= 'started' then registered = false; return end
    if not registered then
        local ok, result = TSS.CallExport('tss-chat', 'RegisterCommandProvider', resource, 'GetBridgeCommandList')
        registered = ok and result == true
    else
        TSS.CallExport('tss-chat', 'RefreshCommands')
    end
end
AddEventHandler('tss-chat:server:ready', function()
    registered = false
    TSS.Commands.RefreshTssChat()
end)
AddEventHandler('onResourceStop', function(stopped)
    if stopped == 'tss-chat' then registered = false end
    if stopped == resource and GetResourceState('tss-chat') == 'started' then
        TSS.CallExport('tss-chat', 'UnregisterCommandProvider', resource)
    end
end)
