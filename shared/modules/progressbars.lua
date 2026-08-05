TSS = TSS or {}
TSS.Progress = TSS.Progress or {}

local active = false

local function bool(value, default)
    if value == nil then return default end
    return value
end

local function getProgressSystem()
    local configured = tostring(TSS.Config.ProgressBar or 'auto'):lower()

    if configured ~= 'auto' then
        if configured == TSS.Resources.OxLib then return 'ox' end
        if configured == TSS.Resources.ProgressBar or configured == 'qb-core' or configured == 'qbcore' then return 'qb' end
        if configured == 'tss_bridge' then return 'tss' end
        return configured
    end

    if TSS.IsStarted(TSS.Resources.OxLib) then return 'ox' end
    if TSS.IsStarted(TSS.Resources.ProgressBar) and TSS.IsStarted(TSS.Resources.QBCore) then return 'qb' end
    return 'tss'
end

function TSS.Progress.System()
    local system = getProgressSystem()
    if system == 'ox' then return system, TSS.Resources.OxLib end
    if system == 'qb' then return system, TSS.Resources.ProgressBar end
    return system, nil
end

function TSS.Progress.Supports(feature)
    local system = getProgressSystem()
    feature = tostring(feature or ''):lower()
    if feature == 'cancel' or feature == 'animation' or feature == 'controls' then return true end
    if feature == 'circle' then return system == 'ox' end
    if feature == 'props' then return system == 'ox' or system == 'qb' end
    return false
end

local function playProgressAnim(ped, data, duration)
    if data.task then
        TaskStartScenarioInPlace(ped, data.task, 0, true)
    elseif data.dict and data.anim and TSS.LoadAnimDict(data.dict) then
        TaskPlayAnim(ped, data.dict, data.anim, 8.0, -8.0, duration, data.flag or 49, 0.0, false, false, false)
    end
end

local function cleanupProgressPed(ped, data)
    if data.task or data.dict or data.anim then
        ClearPedTasks(ped)
    end

    FreezeEntityPosition(ped, false)
end

local function runTssProgress(data)
    local ped = PlayerPedId()
    local duration = data.duration or data.time or 5000
    local label = data.label or data.progressText or 'Working...'
    local expires = GetGameTimer() + duration
    local nextUiUpdate = 0

    if data.disableMovement then
        FreezeEntityPosition(ped, true)
    end

    playProgressAnim(ped, data, duration)

    while active and GetGameTimer() < expires do
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
        if bool(data.canCancel, bool(data.cancel, true)) and (IsControlJustPressed(0, 73) or IsControlJustPressed(0, 200) or IsControlJustPressed(0, 177)) then
            cleanupProgressPed(ped, data)
            if TSS.UI and TSS.UI.HideProgress then TSS.UI.HideProgress() end
            return false
        end
    end

    cleanupProgressPed(ped, data)
    if TSS.UI and TSS.UI.Progress then
        TSS.UI.Progress({ label = label, percent = 100 })
        Wait(80)
    end
    if TSS.UI and TSS.UI.HideProgress then TSS.UI.HideProgress() end

    return active == true
end

local function runNativeProgress(data)
    return runTssProgress(data)
end

local function runOxProgress(data)
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
        options.anim = {
            dict = data.dict,
            clip = data.anim,
            scenario = data.task,
            flag = data.flag,
        }
    end

    if data.prop and data.prop.model then
        options.prop = data.prop
    end

    if data.propTwo and data.propTwo.model then
        options.propTwo = data.propTwo
    end

    if data.type == 'circle' or data.progressType == 'circle' then
        return exports[TSS.Resources.OxLib]:progressCircle(options) == true
    end

    return exports[TSS.Resources.OxLib]:progressBar(options) == true
end

local function runQbProgress(data)
    local p = promise.new()
    local core = exports[TSS.Resources.QBCore]:GetCoreObject()

    core.Functions.Progressbar(
        data.name or 'tss_progress',
        data.label or 'Working...',
        data.duration or data.time or 5000,
        data.useWhileDead or data.dead or false,
        bool(data.canCancel, bool(data.cancel, true)),
        {
            disableMovement = data.disableMovement or false,
            disableCarMovement = data.disableCarMovement or data.disableMovement or false,
            disableMouse = data.disableMouse or false,
            disableCombat = bool(data.disableCombat, true),
        },
        {
            animDict = data.dict,
            anim = data.anim,
            flags = data.flag or 49,
            task = data.task,
        },
        data.prop or {},
        data.propTwo or {},
        function() p:resolve(true) end,
        function() p:resolve(false) end
    )

    return Citizen.Await(p)
end

function TSS.ProgressBar(data)
    if active then return false end
    active = true

    data = data or {}

    local system = getProgressSystem()
    local ok, result = pcall(function()
        if system == 'ox' then return runOxProgress(data) end
        if system == 'qb' then return runQbProgress(data) end
        if system == 'native' then return runNativeProgress(data) end
        return runNativeProgress(data)
    end)

    active = false

    if not ok then
        TSS.Warn(('Progress bar failed using %s: %s'):format(system, result))
        return false
    end

    return result == true
end

function TSS.StopProgressBar()
    local system = getProgressSystem()

    if system == 'ox' and TSS.IsStarted(TSS.Resources.OxLib) then
        exports[TSS.Resources.OxLib]:cancelProgress()
    elseif system == 'qb' then
        TriggerEvent('progressbar:client:cancel')
    end

    active = false
    if TSS.UI and TSS.UI.HideProgress then TSS.UI.HideProgress() end
end

TSS.Progress.Start = TSS.ProgressBar
TSS.Progress.Stop = TSS.StopProgressBar

function progressBar(data)
    return TSS.ProgressBar(data)
end

function stopProgressBar()
    return TSS.StopProgressBar()
end

if TSS.IsClient() then
    exports('ProgressBar', function(data)
        return TSS.ProgressBar(data or {})
    end)

    exports('CancelProgressBar', function()
        return TSS.StopProgressBar()
    end)

    RegisterCommand('tss_cancelprogress', function()
        TSS.StopProgressBar()
    end, false)

    RegisterKeyMapping('tss_cancelprogress', 'Cancel TinySprite progress', 'keyboard', 'X')
end
