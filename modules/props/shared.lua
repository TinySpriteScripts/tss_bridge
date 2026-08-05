-- Lazy client implementation owned by the Props module.
TSS = TSS or {}
TSS.Props = TSS.Props or {}

--- Creates and tracks a configured client-side prop.
---@param data TSSEntityCreateData|string|integer Prop definition or model.
---@param coords? vector3|vector4|table Coordinates when a model is passed directly.
---@param options? TSSEntityCreateOptions Creation options.
---@return TSSEntity? prop
function TSS.CreateProp(data, coords, options)
    options = options or {}

    if type(data) ~= 'table' then
        data = { model = data, coords = coords }
    end

    data.model = data.model or data.prop
    coords = coords or data.coords

    if not data.model or not coords then
        TSS.Warn('CreateProp needs a model and coords')
        return nil
    end

    local loaded, model = TSS.LoadModel(data.model)
    if not loaded then return nil end

    local networked = options.networked or data.networked or false
    local dynamic = options.dynamic or data.dynamic or false
    local prop = CreateObject(model, coords.x, coords.y, coords.z, networked, networked, dynamic)

    SetEntityHeading(prop, coords.w or data.heading or 0.0)
    FreezeEntityPosition(prop, options.freeze or data.freeze or false)

    if options.collision == false or data.collision == false then
        SetEntityCollision(prop, false, false)
    end

    SetModelAsNoLongerNeeded(model)

    TSS.TrackEntity(prop, DeleteObject)
    TSS.Props[prop] = prop

    if options.fade ~= false and data.fade ~= false then
        TSS.FadeInEntity(prop)
    end

    return prop
end

--- Deletes and detaches a bridge-tracked prop.
---@param prop TSSEntity Prop handle.
function TSS.DeleteProp(prop)
    if prop and DoesEntityExist(prop) then
        if IsEntityAttached(prop) then
            DetachEntity(prop, true, true)
        end

        DeleteObject(prop)
    end

    TSS.Props[prop] = nil
    TSS.ForgetEntity(prop)
end

--- Deletes all bridge-tracked props.
function TSS.ClearProps()
    for prop in pairs(TSS.Props) do
        TSS.DeleteProp(prop)
    end
end

function createProp(data, coords, options)
    return TSS.CreateProp(data, coords, options)
end

function deleteProp(prop)
    return TSS.DeleteProp(prop)
end
