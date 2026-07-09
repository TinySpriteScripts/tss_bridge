TSS = TSS or {}

local active = false

local function bool(value, default)
    if value == nil then return default end
    return value
end

local function getProgressSystem()
    local configured = TSS.Config.ProgressBar

    if configured ~= 'auto' then
        return configured
    end

    if TSS.IsStarted(TSS.Resources.OxLib) then return 'ox' end
    if TSS.IsStarted(TSS.Resources.ProgressBar) and TSS.IsStarted(TSS.Resources.QBCore) then return 'qb' end

    return 'native'
end

local function runNativeProgress(data)
    local ped = PlayerPedId()
    local duration = data.duration or data.time or 5000
    local expires = GetGameTimer() + duration

    if data.disableMovement then
        FreezeEntityPosition(ped, true)
    end

    if data.task then
        TaskStartScenarioInPlace(ped, data.task, 0, true)
    elseif data.dict and data.anim and TSS.LoadAnimDict(data.dict) then
        TaskPlayAnim(ped, data.dict, data.anim, 8.0, -8.0, duration, data.flag or 49, 0.0, false, false, false)
    end

    while GetGameTimer() < expires do
        Wait(0)
        if bool(data.cancel, true) and IsControlJustPressed(0, 200) then
            ClearPedTasks(ped)
            FreezeEntityPosition(ped, false)
            return false
        end
    end

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)

    return true
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
end

function progressBar(data)
    return TSS.ProgressBar(data)
end

function stopProgressBar()
    return TSS.StopProgressBar()
end
