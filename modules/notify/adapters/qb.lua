TSS.Notify.RegisterAdapter('qb', TSS.Resources.QBCore, {
    supports = { title = true, type = true, duration = true, icon = true },
    send = function(resource, data)
        local ok, core = TSS.CallExport(resource, 'GetCoreObject')
        if not ok or not core or not core.Functions or not core.Functions.Notify then return false end
        core.Functions.Notify({ text = data.message, caption = data.title },
            data.type == 'info' and 'primary' or data.type, data.duration, data.icon)
        return true
    end,
}, { priority = 30, aliases = { 'qb-core', 'qbcore' } })
