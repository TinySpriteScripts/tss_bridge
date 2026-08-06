TSS.Notify.RegisterAdapter('mythic', TSS.Resources.MythicNotify, {
    supports = { type = true, duration = true },
    send = function(resource, data)
        local ok = TSS.CallExport(resource, 'SendAlert', data.type == 'info' and 'inform' or data.type,
            data.message, data.duration)
        return ok
    end,
}, { priority = 60, aliases = { 'mythic_notify' } })
