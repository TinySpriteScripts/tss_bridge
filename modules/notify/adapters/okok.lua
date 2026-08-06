TSS.Notify.RegisterAdapter('okok', TSS.Resources.OkokNotify, {
    supports = { title = true, type = true, duration = true, sound = true },
    send = function(resource, data)
        local ok = TSS.CallExport(resource, 'Alert', data.title, data.message, data.duration, data.type, data.sound)
        return ok
    end,
}, { priority = 40, aliases = { 'okoknotify' } })
