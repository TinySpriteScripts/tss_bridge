-- Vehicle queries shared by both sides, plus client-only compartment animation.
TSSVehicleAccess = {}
local vehicleAccess = TSSVehicleAccess
local isServer = IsDuplicityVersion()

function vehicleAccess.FromNetworkId(networkId)
    if type(networkId) ~= 'number' or networkId % 1 ~= 0 or networkId <= 0 or networkId > 65535 then return nil end
    local vehicle = NetworkGetEntityFromNetworkId(networkId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return nil end
    return vehicle
end

function vehicleAccess.Current(playerSource)
    local playerPed = isServer and GetPlayerPed(playerSource) or PlayerPedId()
    if not playerPed or playerPed == 0 then return nil end
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    return vehicle ~= 0 and vehicle or nil
end

function vehicleAccess.Inspect(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return nil end
    local coordinates = GetEntityCoords(vehicle)
    return {
        entity = vehicle,
        networkId = NetworkGetNetworkIdFromEntity(vehicle),
        model = GetEntityModel(vehicle),
        plate = (GetVehicleNumberPlateText(vehicle) or ''):match('^%s*(.-)%s*$'):upper(),
        coords = { x = coordinates.x, y = coordinates.y, z = coordinates.z },
        bucket = isServer and GetEntityRoutingBucket(vehicle) or nil,
        locked = GetVehicleDoorLockStatus(vehicle) > 1,
        vehicleType = GetVehicleType(vehicle),
        class = not isServer and GetVehicleClass(vehicle) or nil,
    }
end

function vehicleAccess.Nearby(distance)
    if isServer then return {} end
    local playerPosition = GetEntityCoords(PlayerPedId())
    local vehicles = {}
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local vehiclePosition = GetEntityCoords(vehicle)
        local distanceSquared = (playerPosition.x - vehiclePosition.x) ^ 2
            + (playerPosition.y - vehiclePosition.y) ^ 2 + (playerPosition.z - vehiclePosition.z) ^ 2
        if distanceSquared <= distance * distance then vehicles[#vehicles + 1] = vehicle end
    end
    return vehicles
end

function vehicleAccess.TrunkPosition(vehicle)
    if isServer then return nil end
    local bootBone = GetEntityBoneIndexByName(vehicle, 'boot')
    if bootBone ~= -1 then return GetWorldPositionOfEntityBone(vehicle, bootBone) end
    local minimumDimensions = GetModelDimensions(GetEntityModel(vehicle))
    return GetOffsetFromEntityInWorldCoords(vehicle, 0.0, minimumDimensions.y - 0.25, 0.0)
end

function vehicleAccess.SetTrunkOpen(vehicle, shouldOpen)
    if isServer or not vehicle or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2
        or not GetIsDoorValid(vehicle, 5) or IsVehicleDoorDamaged(vehicle, 5) then return false end
    local wasOpen = GetVehicleDoorAngleRatio(vehicle, 5) > 0.1
    if shouldOpen then SetVehicleDoorOpen(vehicle, 5, false, false)
    else SetVehicleDoorShut(vehicle, 5, false) end
    return true, wasOpen
end
