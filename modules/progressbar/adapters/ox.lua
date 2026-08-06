local function bool(value, default)
    if value == nil then return default end
    return value
end

TSS.Progress.RegisterAdapter('ox', TSS.Resources.OxLib, {
    supports = { cancel = true, animation = true, controls = true, circle = true, props = true },
    start = function(resource, data)
        local options = {
            duration = data.duration or data.time or 5000,
            label = data.label or 'Working...',
            position = data.position or 'bottom',
            useWhileDead = data.useWhileDead or data.dead or false,
            canCancel = bool(data.canCancel, bool(data.cancel, true)),
            disable = {
                move = data.disableMovement or false,
                car = data.disableCarMovement or data.disableMovement or false,
                combat = bool(data.disableCombat, true),
                mouse = data.disableMouse or false,
            },
        }
        if data.dict or data.anim or data.task then
            options.anim = { dict = data.dict, clip = data.anim, scenario = data.task, flag = data.flag }
        end
        if data.prop and data.prop.model then options.prop = data.prop end
        if data.propTwo and data.propTwo.model then options.propTwo = data.propTwo end

        local exportName = (data.type == 'circle' or data.progressType == 'circle') and 'progressCircle' or 'progressBar'
        local ok, result = TSS.CallExport(resource, exportName, options)
        return ok and result == true
    end,
    stop = function(resource)
        local ok = TSS.CallExport(resource, 'cancelProgress')
        return ok
    end,
}, { priority = 10, aliases = { 'ox_lib' } })
