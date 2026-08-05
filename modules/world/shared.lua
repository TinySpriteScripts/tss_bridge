-- Lazy client implementation owned by the World module.
TSS = TSS or {}
TSS.World = TSS.World or {}

local distanceItems = {}

local function asVec3(coords)
    if not coords then return nil end
    return vec3(coords.x, coords.y, coords.z)
end

local function targetCoords(target)
    if type(target) == 'number' and DoesEntityExist(target) then
        return GetEntityCoords(target)
    end

    return target
end

--- Returns the resource currently executing this implementation.
--- The public wrapper returns the consuming resource instead.
---@return string resource
function TSS.World.ResourceName()
    return GetCurrentResourceName()
end

--- Turns a ped toward an entity or coordinates and waits for the turn.
---@param target TSSEntity|vector3|table Target entity or coordinates.
---@param ped? TSSEntity Ped handle; defaults to the local player ped.
---@param timeout? integer Turn duration in milliseconds.
---@return boolean success
function TSS.World.Face(target, ped, timeout)
    if TSS.IsServer() then return false end

    ped = ped or PlayerPedId()
    timeout = timeout or 1500

    local coords = targetCoords(target)
    if not coords then return false end

    if not IsPedHeadingTowardsPosition(ped, coords.x, coords.y, coords.z, 30.0) then
        TaskTurnPedToFaceCoord(ped, coords.x, coords.y, coords.z, timeout)
        Wait(timeout)
    end

    if type(target) == 'number' and DoesEntityExist(target) then
        TaskLookAtEntity(ped, target, 5000, 1, 1)
    else
        TaskLookAtCoord(ped, coords.x, coords.y, coords.z, 5000, 1, 1)
    end

    return true
end

local function createDistanceEntity(kind, data, options)
    if TSS.IsServer() then return nil end

    options = options or {}
    data = data or {}

    local coords = data.coords or options.coords
    if not coords then
        TSS.Warn(('CreateDistance%s needs coords'):format(kind))
        return nil
    end

    local range = options.range or data.range or 50.0
    local despawnRange = options.despawnRange or data.despawnRange or (range + 10.0)
    local origin = asVec3(coords)
    local controller = {
        entity = nil,
        active = true,
    }

    local function spawn()
        if controller.entity and DoesEntityExist(controller.entity) then return end

        if kind == 'Prop' then
            controller.entity = TSS.CreateProp(data, coords, options)
        else
            controller.entity = TSS.CreatePed(data, coords, options)
        end

        if controller.entity and options.onSpawn then
            options.onSpawn(controller.entity)
        end
    end

    local function despawn()
        if not controller.entity then return end

        if kind == 'Prop' then
            TSS.DeleteProp(controller.entity)
        else
            TSS.DeletePed(controller.entity)
        end

        controller.entity = nil
    end

    function controller.remove()
        controller.active = false
        despawn()
    end

    function controller.getEntity()
        return controller.entity
    end

    CreateThread(function()
        while controller.active do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - origin)

            if distance <= range then
                spawn()
            elseif distance >= despawnRange then
                despawn()
            end

            Wait(options.interval or 1000)
        end
    end)

    distanceItems[#distanceItems + 1] = controller
    return controller
end

--- Creates a controller that spawns a prop only while the player is nearby.
---@param data table Prop and coordinates definition.
---@param options? table Distance, polling, and spawn options.
---@return TSSDistanceController? controller
function TSS.World.CreateDistanceProp(data, options)
    data = data or {}
    data.model = data.model or data.prop
    return createDistanceEntity('Prop', data, options)
end

--- Creates a controller that spawns a ped only while the player is nearby.
---@param data TSSEntityCreateData|string|integer Ped definition or model.
---@param coords? vector3|vector4|table Coordinates when a model is passed directly.
---@param options? table Distance, polling, and spawn options.
---@return TSSDistanceController? controller
function TSS.World.CreateDistancePed(data, coords, options)
    options = options or {}

    if type(data) ~= 'table' then
        data = {
            model = data,
            coords = coords,
        }
    else
        coords = coords or data.coords
        data.coords = coords
    end

    return createDistanceEntity('Ped', data, options)
end

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #distanceItems do
        distanceItems[i].remove()
    end
end)

function resourceName()
    return TSS.World.ResourceName()
end

function faceCoords(target, ped, timeout)
    return TSS.World.Face(target, ped, timeout)
end

function createDistanceProp(data, options)
    return TSS.World.CreateDistanceProp(data, options)
end

function createDistancePed(data, coords, options)
    return TSS.World.CreateDistancePed(data, coords, options)
end

TSS.ResourceName = TSS.World.ResourceName
TSS.FaceCoords = TSS.World.Face
TSS.CreateDistanceProp = TSS.World.CreateDistanceProp
TSS.CreateDistancePed = TSS.World.CreateDistancePed
