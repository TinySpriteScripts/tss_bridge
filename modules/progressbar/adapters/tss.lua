local function bool(value, default)
    if value == nil then return default end
    return value
end

local adapter = {
    supports = { cancel = true, animation = true, controls = true },
    start = function(_, data)
        local ped = PlayerPedId()
        local duration = data.duration or data.time or 5000
        local label = data.label or data.progressText or 'Working...'
        local expires = GetGameTimer() + duration
        local nextUiUpdate = 0

        if data.disableMovement then FreezeEntityPosition(ped, true) end
        if data.task then
            TaskStartScenarioInPlace(ped, data.task, 0, true)
        elseif data.dict and data.anim and TSS.LoadAnimDict(data.dict) then
            TaskPlayAnim(ped, data.dict, data.anim, 8.0, -8.0, duration, data.flag or 49, 0.0, false, false, false)
        end

        while TSS.Progress._IsActive() and GetGameTimer() < expires do
            local now = GetGameTimer()
            if now >= nextUiUpdate and TSS.UI and TSS.UI.Progress then
                TSS.UI.Progress({
                    label = label,
                    percent = math.floor(((duration - math.max(0, expires - now)) / duration) * 100),
                    canCancel = bool(data.canCancel, bool(data.cancel, true)),
                })
                nextUiUpdate = now + 50
            end
            Wait(0)
            if bool(data.canCancel, bool(data.cancel, true))
                and (IsControlJustPressed(0, 73) or IsControlJustPressed(0, 200) or IsControlJustPressed(0, 177)) then
                if data.task or data.dict or data.anim then ClearPedTasks(ped) end
                FreezeEntityPosition(ped, false)
                if TSS.UI and TSS.UI.HideProgress then TSS.UI.HideProgress() end
                return false
            end
        end

        if data.task or data.dict or data.anim then ClearPedTasks(ped) end
        FreezeEntityPosition(ped, false)
        if TSS.UI and TSS.UI.Progress then
            TSS.UI.Progress({ label = label, percent = 100 })
            Wait(80)
        end
        if TSS.UI and TSS.UI.HideProgress then TSS.UI.HideProgress() end
        return TSS.Progress._IsActive()
    end,
    stop = function()
        if TSS.UI and TSS.UI.HideProgress then TSS.UI.HideProgress() end
        return true
    end,
}

TSS.Progress.Utils.BuiltInAdapter = adapter
TSS.Progress.RegisterAdapter('tss', nil, adapter, { priority = 1000, aliases = { 'tss_bridge' } })
