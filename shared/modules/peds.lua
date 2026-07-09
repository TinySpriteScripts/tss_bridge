TSS = TSS or {}
TSS.Peds = TSS.Peds or {}

function TSS.CreatePed(data, coords, options)
    options = options or {}

    if type(data) ~= 'table' then
        data = { model = data, coords = coords }
    end

    coords = coords or data.coords
    if not data.model or not coords then
        TSS.Warn('CreatePed needs a model and coords')
        return nil
    end

    local loaded, model = TSS.LoadModel(data.model)
    if not loaded then return nil end

    local pedType = data.pedType or options.pedType or 0
    local networked = options.networked or data.networked or false
    local ped = CreatePed(pedType, model, coords.x, coords.y, coords.z, coords.w or 0.0, networked, false)

    SetEntityInvincible(ped, options.invincible ~= false and data.invincible ~= false)
    SetBlockingOfNonTemporaryEvents(ped, options.blockEvents ~= false and data.blockEvents ~= false)
    FreezeEntityPosition(ped, options.freeze ~= false and data.freeze ~= false)

    if options.collision == false or data.collision == false then
        SetEntityCollision(ped, false, false)
    end

    if data.scenario or options.scenario then
        TaskStartScenarioInPlace(ped, data.scenario or options.scenario, 0, true)
    elseif (data.anim or options.anim) then
        local anim = data.anim or options.anim
        if TSS.LoadAnimDict(anim.dict or anim[1]) then
            TaskPlayAnim(ped, anim.dict or anim[1], anim.clip or anim.name or anim[2], 8.0, -8.0, anim.duration or -1, anim.flag or 1, 0.0, false, false, false)
        end
    end

    SetModelAsNoLongerNeeded(model)

    TSS.TrackEntity(ped, DeletePed)
    TSS.Peds[ped] = ped

    if options.fade ~= false and data.fade ~= false then
        TSS.FadeInEntity(ped)
    end

    return ped
end

function TSS.DeletePed(ped)
    if ped and DoesEntityExist(ped) then
        DeletePed(ped)
    end

    TSS.Peds[ped] = nil
    TSS.ForgetEntity(ped)
end

function TSS.ClearPeds()
    for ped in pairs(TSS.Peds) do
        TSS.DeletePed(ped)
    end
end

function createPed(data, coords, options)
    return TSS.CreatePed(data, coords, options)
end

function createScenarioPed(data, coords, scenario, options)
    options = options or {}
    options.scenario = scenario
    return TSS.CreatePed(data, coords, options)
end

function createAnimatedPed(data, coords, anim, options)
    options = options or {}
    options.anim = anim
    return TSS.CreatePed(data, coords, options)
end

function deletePed(ped)
    return TSS.DeletePed(ped)
end
