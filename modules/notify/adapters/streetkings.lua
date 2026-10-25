TSS.Notify.RegisterAdapter('streetkings', TSS.Resources.StreetKings, {
    supports = { title = true, type = true, duration = true },
    send = function(resource, data)
        local text = data.message
        if data.title ~= '' and data.title ~= text then text = data.title .. ': ' .. text end
        local ok = TSS.CallExport(resource, 'ShowNotification', {
            title = text, type = data.type, duration = data.duration,
        })
        return ok
    end,
}, { priority = 5 })
