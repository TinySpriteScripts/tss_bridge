TSS.Notify.RegisterAdapter('wasabi', TSS.Resources.WasabiNotify, {
    supports = { title = true, type = true, duration = true, icon = true, id = true, sound = true },
    send = function(resource, data)
        local ok = TSS.CallExport(resource, 'notify', data.title, data.message, data.duration,
            data.type, data.sound, data.icon, data.id)
        return ok
    end,
}, { priority = 50, aliases = { 'wasabi_notify' } })
