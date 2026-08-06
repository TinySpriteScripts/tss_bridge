TSS.Notify.RegisterAdapter('qbox', TSS.Resources.Qbox, {
    supports = { title = true, type = true, duration = true, position = true, icon = true, style = true },
    send = function(resource, data)
        local ok = TSS.CallExport(resource, 'Notify', { text = data.message, caption = data.title },
            data.type == 'info' and 'inform' or data.type, data.duration, data.subtitle,
            data.position, data.style, data.icon, data.iconColor)
        return ok
    end,
}, { priority = 20, aliases = { 'qbx', 'qbx_core' } })
