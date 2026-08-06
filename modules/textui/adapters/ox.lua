TSS.TextUI.RegisterAdapter('ox', TSS.Resources.OxLib, {
    supports = { position = true, icon = true, style = true },
    show = function(resource, data)
        local ok = TSS.CallExport(resource, 'showTextUI', data.text, {
            position = data.position, icon = data.icon, iconColor = data.iconColor,
            iconAnimation = data.iconAnimation, style = data.style, alignIcon = data.alignIcon,
        })
        return ok
    end,
    hide = function(resource)
        local ok = TSS.CallExport(resource, 'hideTextUI')
        return ok
    end,
}, { priority = 10, aliases = { 'ox_lib' } })
