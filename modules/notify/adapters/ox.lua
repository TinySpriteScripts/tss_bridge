TSS.Notify.RegisterAdapter('ox', TSS.Resources.OxLib, {
    supports = { title = true, type = true, duration = true, position = true, icon = true, id = true, sound = true, style = true },
    send = function(resource, data)
        local ok = TSS.CallExport(resource, 'notify', {
            id = data.id, title = data.title, description = data.message,
            duration = data.duration, position = data.position, type = data.type,
            style = data.style, icon = data.icon, iconAnimation = data.iconAnimation,
            iconColor = data.iconColor, sound = data.soundData,
        })
        return ok
    end,
}, { priority = 10, aliases = { 'ox_lib' } })
