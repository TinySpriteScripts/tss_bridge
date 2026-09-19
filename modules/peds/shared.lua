-- Lazy client implementation owned by the Peds module.
TSS = TSS or {}
TSS.Peds = TSS.Peds or {}

-- Custom appearance is applied only when explicitly supplied by a consumer.
local function applyAppearance(ped, custom)
    if type(custom) ~= 'table' then return end
    SetPedDefaultComponentVariation(ped)
    if custom.randomize then
        SetPedRandomComponentVariation(ped, 0)
        SetPedRandomProps(ped)
    end
    local random = custom.randomize == true
    local function parent(key) return custom[key] or (random and math.random(0, 45) or 0) end
    SetPedHeadBlendData(ped, parent('faceFather'), parent('faceMother'), custom.raceShape or 0,
        parent('skinFather'), parent('skinMother'), custom.raceSkin or 0,
        custom.faceMix or 0.5, custom.skinMix or 0.5, custom.raceMix or 0, false)
    local features = {
        'noseWidth', 'noseHeight', 'noseSize', 'noseBoneHeight', 'nosePeakHeight', 'noseBoneTwist',
        'eyebrowHeight', 'eyebrowDepth', 'cheekBoneHeight', 'cheekBoneWidth', 'cheeckWidth',
        'eyeOpening', 'lipThickness', 'jawWidth', 'jawSize', 'chinLowering', 'chinLength',
        'chinSize', 'chinHole', 'neckThickness',
    }
    for index, name in ipairs(features) do
        local value = custom[name]
        if name == 'cheeckWidth' then value = custom.cheekWidth or value end
        if value == nil then value = random and (math.random() * 2 - 1) or 0 end
        SetPedFaceFeature(ped, index - 1, math.max(-1, math.min(1, value)))
    end
    local components = { Hair=2, Mask=1, Scarf=7, Jacket=11, Shirt=8, Vest=9,
        Bags=5, Arms=3, Pants=4, Shoes=6, Decal=10 }
    for name, component in pairs(components) do
        if custom[name] ~= nil then
            SetPedComponentVariation(ped, component, custom[name], custom[name .. 'Variant'] or 0, 0)
        end
    end
    if custom.HairTexture ~= nil or custom.HairHighlight ~= nil then
        SetPedHairColor(ped, custom.HairTexture or 0, custom.HairHighlight or 0)
    end
    if custom.Eyecolor ~= nil then SetPedEyeColor(ped, custom.Eyecolor) end
    for name, overlay in pairs({ Eyebrows=2, Makeup=4, Lipstick=8, Beard=1 }) do
        if custom[name] ~= nil then
            SetPedHeadOverlay(ped, overlay, custom[name], custom[name .. 'Opacity'] or 1.0)
            SetPedHeadOverlayColor(ped, overlay, (name == 'Makeup' or name == 'Lipstick') and 2 or 1,
                custom[name .. 'Color'] or 0, 0)
        end
    end
    for name, prop in pairs({ Hat=0, Glasses=1, Ear=2, Watches=6, Bracelets=7 }) do
        if custom[name] ~= nil then
            if custom[name] < 0 then ClearPedProp(ped, prop)
            else SetPedPropIndex(ped, prop, custom[name], custom[name .. 'Variant'] or 0, true) end
        end
    end
end

--- Creates and tracks a configured client-side ped.
---@param data TSSEntityCreateData|string|integer Ped definition or model.
---@param coords? vector3|vector4|table Coordinates when a model is passed directly.
---@param options? TSSEntityCreateOptions Creation options.
---@return TSSEntity? ped
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

    if not ped or ped == 0 or not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(model)
        return nil
    end
    applyAppearance(ped, data.custom or options.custom)

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

--- Deletes a bridge-tracked ped.
---@param ped TSSEntity Ped handle.
function TSS.DeletePed(ped)
    if ped and DoesEntityExist(ped) then
        DeletePed(ped)
    end

    TSS.Peds[ped] = nil
    TSS.ForgetEntity(ped)
end

--- Deletes all bridge-tracked peds.
function TSS.ClearPeds()
    for ped in pairs(TSS.Peds) do
        if type(ped) == 'number' then TSS.DeletePed(ped) end
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

--- Turns a ped toward an entity or coordinates, then looks at it for five seconds.
--- Waits only when turning; returns false for invalid or despawned entities.
---@param target TSSEntity|vector3|vector4|table
---@param ped? TSSEntity Defaults to the local player.
---@param timeout? integer Turn duration in milliseconds (default 1500).
---@return boolean success
function TSS.Peds.LookAt(target, ped, timeout)
    if TSS.IsServer() then return false end
    ped = ped or PlayerPedId()
    if type(ped) ~= 'number' or ped == 0 or not DoesEntityExist(ped) then return false end
    local entity = type(target) == 'number'
    if entity and (target == 0 or not DoesEntityExist(target)) then return false end
    local kind = type(target)
    if not entity and kind ~= 'table' and kind ~= 'vector3' and kind ~= 'vector4' then return false end
    local coords = entity and GetEntityCoords(target) or target
    if not coords or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then return false end
    timeout = math.max(0, math.floor(tonumber(timeout) or 1500))
    if not IsPedHeadingTowardsPosition(ped, coords.x, coords.y, coords.z, 30.0) then
        TaskTurnPedToFaceCoord(ped, coords.x, coords.y, coords.z, timeout)
        Wait(timeout)
    end
    if not DoesEntityExist(ped) or (entity and not DoesEntityExist(target)) then return false end
    if entity then TaskLookAtEntity(ped, target, 5000, 1, 1)
    else TaskLookAtCoord(ped, coords.x, coords.y, coords.z, 5000, 1, 1) end
    return true
end
