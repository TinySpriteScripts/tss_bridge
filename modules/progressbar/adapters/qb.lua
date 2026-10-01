local function bool(value, default)
    if value == nil then return default end
    return value
end

TSS.Progress.RegisterAdapter('qb', TSS.Resources.ProgressBar, {
    supports = { cancel = true, animation = true, controls = true, props = true },
    start = function(_, data)
        local ok, core = TSS.CallExport(TSS.Resources.QBCore, 'GetCoreObject')
        if not ok or not core or not core.Functions or not core.Functions.Progressbar then return false end
        local pending = promise.new()
        core.Functions.Progressbar(
            data.name or 'tss_progress', 
            data.label or 'Working...', 
            data.duration or data.time or 5000,
            data.useWhileDead or data.dead or false, bool(data.canCancel, bool(data.cancel, true)),
            {
                disableMovement = data.disableMovement or false,
                disableCarMovement = data.disableCarMovement or data.disableMovement or false,
                disableMouse = data.disableMouse or false,
                disableCombat = bool(data.disableCombat, true),
            },
            { animDict = data.dict, anim = data.anim, flags = data.flag or 49, task = data.task },
            data.prop or {}, data.propTwo or {},
            function() pending:resolve(true) end,
            function() pending:resolve(false) end
        )
        return Citizen.Await(pending)
    end,
    stop = function()
        TriggerEvent('progressbar:client:cancel')
        return true
    end,
}, {
    priority = 20,
    aliases = { 'qb-core', 'qbcore', 'progressbar' },
    available = function()
        return TSS.IsStarted(TSS.Resources.ProgressBar) and TSS.IsStarted(TSS.Resources.QBCore)
    end,
})
