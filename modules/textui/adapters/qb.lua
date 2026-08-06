TSS.TextUI.RegisterAdapter('qb', TSS.Resources.QBCore, {
    supports = { position = true },
    show = function(resource, data)
        local position = data.position:find('left') and 'left' or data.position:find('top') and 'top' or 'right'
        local ok = TSS.CallExport(resource, 'DrawText', data.text, position)
        return ok
    end,
    hide = function(resource)
        local ok = TSS.CallExport(resource, 'HideText')
        return ok
    end,
}, { priority = 20, aliases = { 'qb-core', 'qbcore' } })
