-- Lazy client implementation owned by the Vehicles module.
TSS = TSS or {}
TSS.Vehicles = TSS.Vehicles or {}

--- Creates and tracks a configured client-side vehicle.
---@param data TSSEntityCreateData|string|integer Vehicle definition or model.
---@param coords? vector3|vector4|table Coordinates when a model is passed directly.
---@param options? TSSEntityCreateOptions Creation options.
---@return TSSEntity? vehicle
function TSS.CreateVehicle(data, coords, options)
    options = options or {}

    if type(data) ~= 'table' then
        data = { model = data, coords = coords }
    end

    data.model = data.model or data.vehicle
    coords = coords or data.coords

    if not data.model or not coords then
        TSS.Warn('CreateVehicle needs a model and coords')
        return nil
    end

    local loaded, model = TSS.LoadModel(data.model)
    if not loaded then return nil end

    local networked = options.networked
    if networked == nil then networked = data.networked end
    if networked == nil then networked = true end

    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w or data.heading or 0.0, networked, false)

    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleOnGroundProperly(vehicle)

    if TSS.Game() ~= 'rdr3' then
        SetVehicleNeedsToBeHotwired(vehicle, false)
        SetVehRadioStation(vehicle, 'OFF')
        SetVehicleModKit(vehicle, 0)

        if networked then
            SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(vehicle), true)
        end
    end

    if options.freeze or data.freeze then
        FreezeEntityPosition(vehicle, true)
    end

    SetModelAsNoLongerNeeded(model)

    TSS.TrackEntity(vehicle, DeleteVehicle)
    TSS.Vehicles[vehicle] = vehicle

    if options.fade ~= false and data.fade ~= false then
        TSS.FadeInEntity(vehicle)
    end

    return vehicle
end

--- Deletes a bridge-tracked vehicle.
---@param vehicle TSSEntity Vehicle handle.
function TSS.DeleteVehicle(vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        DeleteVehicle(vehicle)
    end

    TSS.Vehicles[vehicle] = nil
    TSS.ForgetEntity(vehicle)
end

--- Deletes all bridge-tracked vehicles.
function TSS.ClearVehicles()
    for vehicle in pairs(TSS.Vehicles) do
        TSS.DeleteVehicle(vehicle)
    end
end

function createVeh(data, coords, options)
    return TSS.CreateVehicle(data, coords, options)
end

function createVehicle(data, coords, options)
    return TSS.CreateVehicle(data, coords, options)
end

function deleteVehicle(vehicle)
    return TSS.DeleteVehicle(vehicle)
end

function deleteVeh(vehicle)
    return TSS.DeleteVehicle(vehicle)
end
