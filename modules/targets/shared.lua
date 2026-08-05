-- Lazy client implementation owned by the Targets module.
TSS = TSS or {}
TSS.Target = TSS.Target or {}

local tracked = {
    entities = {},
    models = {},
    zones = {},
}

local function first(...)
    for i = 1, select('#', ...) do
        local value = select(i, ...)
        if value ~= nil then return value end
    end
end

local function asArray(value)
    if value == nil then return {} end
    if type(value) ~= 'table' then return { value } end
    if #value == 0 and (value.label or value.event or value.action or value.onSelect) then return { value } end
    return value
end

local function getTargetSystem()
    local configured = TSS.Config.Target

    if configured ~= 'auto' then
        if configured == TSS.Resources.OxTarget then return 'ox' end
        if configured == TSS.Resources.QbTarget then return 'qb' end
        if configured == TSS.Resources.TgiannTarget then return 'tgiann' end
        if configured == TSS.Resources.BtTarget then return 'bt' end
        return configured
    end

    if TSS.IsStarted(TSS.Resources.OxTarget) then return 'ox' end
    if TSS.IsStarted(TSS.Resources.QbTarget) then return 'qb' end
    if TSS.IsStarted(TSS.Resources.TgiannTarget) then return 'tgiann' end
    if TSS.IsStarted(TSS.Resources.BtTarget) then return 'bt' end

    return nil
end

local function getTargetResource(system)
    if system == 'ox' then return TSS.Resources.OxTarget end
    if system == 'qb' then return TSS.Resources.QbTarget end
    if system == 'tgiann' then return TSS.Resources.TgiannTarget end
    if system == 'bt' then return TSS.Resources.BtTarget end
end

--- Detects the selected target adapter.
---@return string? system
---@return string? resource
function TSS.Target.System()
    local system = getTargetSystem()
    return system, getTargetResource(system)
end

--- Reports whether the selected target adapter supports a feature.
---@param feature 'entity'|'model'|'box'|'circle'|'groups'|'items'|string
---@return boolean supported
function TSS.Target.Supports(feature)
    local system = getTargetSystem()
    feature = tostring(feature or ''):lower()
    if not system then return false end
    return feature == 'entity' or feature == 'model' or feature == 'box' or feature == 'circle' or feature == 'groups' or feature == 'items'
end

local function normaliseOxOptions(options, distance)
    local normalised = {}
    options = asArray(options)

    for i = 1, #options do
        local option = options[i]
        normalised[i] = {
            name = option.name,
            icon = option.icon,
            label = option.label,
            event = option.event,
            serverEvent = option.serverEvent,
            command = option.command,
            args = option.args,
            items = option.items or option.item,
            groups = option.groups or option.job or option.gang,
            distance = option.distance or distance,
            canInteract = option.canInteract,
            onSelect = option.onSelect or option.action,
        }
    end

    return normalised
end

local function normaliseQbOptions(options)
    local normalised = {}
    options = asArray(options)

    for i = 1, #options do
        local option = options[i]
        local copy = {}

        for key, value in pairs(option) do
            copy[key] = value
        end

        copy.action = copy.action or copy.onSelect
        copy.onSelect = nil
        copy.item = copy.item or copy.items

        normalised[i] = copy
    end

    return normalised
end

local function getBoxData(data)
    if data[1] then
        return {
            name = data[1],
            coords = data[2],
            length = data[3],
            width = data[4],
            options = data[5] or {},
        }
    end

    local size = data.size
    return {
        name = data.name,
        coords = data.coords,
        length = data.length or data.l or data.width or (size and size.x) or 1.0,
        width = data.width or data.w or data.depth or (size and size.y) or 1.0,
        options = {
            name = data.name,
            heading = data.heading or data.rotation or (data.coords and data.coords.w) or 0.0,
            debugPoly = data.debug or data.debugPoly or false,
            minZ = data.minZ,
            maxZ = data.maxZ,
        },
    }
end

local function getCircleData(data)
    if data[1] then
        return {
            name = data[1],
            coords = data[2],
            radius = data[3],
            options = data[4] or {},
        }
    end

    return {
        name = data.name,
        coords = data.coords,
        radius = data.radius or 1.0,
        options = {
            name = data.name,
            debugPoly = data.debug or data.debugPoly or false,
        },
    }
end

local function callTarget(resource, exportName, ...)
    local ok, result = TSS.CallExport(resource, exportName, ...)

    if not ok then
        TSS.Warn(('%s:%s failed: %s'):format(resource, exportName, result))
        return nil
    end

    return result
end

local function addQbEntity(resource, entity, options, distance)
    return callTarget(resource, 'AddTargetEntity', entity, {
        options = normaliseQbOptions(options),
        distance = distance or 2.0,
    })
end

local function addQbModel(resource, models, options, distance)
    return callTarget(resource, 'AddTargetModel', models, {
        options = normaliseQbOptions(options),
        distance = distance or 2.0,
    })
end

local function addQbBox(resource, data, options, distance)
    local box = getBoxData(data)
    box.options.name = box.options.name or box.name
    box.options.debugPoly = TSS.ShouldDebugPoly(box.options.debugPoly or box.options.debug)

    callTarget(resource, 'AddBoxZone', box.name, box.coords, box.length, box.width, box.options, {
        options = normaliseQbOptions(options),
        distance = distance or 2.0,
    })

    return box.name
end

local function addQbCircle(resource, data, options, distance)
    local circle = getCircleData(data)
    circle.options.name = circle.options.name or circle.name
    circle.options.debugPoly = TSS.ShouldDebugPoly(circle.options.debugPoly or circle.options.debug)

    callTarget(resource, 'AddCircleZone', circle.name, circle.coords, circle.radius, circle.options, {
        options = normaliseQbOptions(options),
        distance = distance or 2.0,
    })

    return circle.name
end

local adapters = {
    ox = {
        entity = function(resource, entity, options, distance)
            return callTarget(resource, 'addLocalEntity', entity, normaliseOxOptions(options, distance))
        end,
        model = function(resource, models, options, distance)
            return callTarget(resource, 'addModel', models, normaliseOxOptions(options, distance))
        end,
        box = function(resource, data, options, distance)
            local box = getBoxData(data)
            local minZ = box.options.minZ or (box.coords.z - 1.0)
            local maxZ = box.options.maxZ or (box.coords.z + 1.0)

            return callTarget(resource, 'addBoxZone', {
                coords = vec3(box.coords.x, box.coords.y, minZ + ((maxZ - minZ) / 2)),
                size = vec3(box.length, box.width, maxZ - minZ),
                rotation = box.options.heading or box.options.rotation or 0.0,
                debug = TSS.ShouldDebugPoly(box.options.debugPoly or box.options.debug),
                options = normaliseOxOptions(options, distance),
            })
        end,
        circle = function(resource, data, options, distance)
            local circle = getCircleData(data)

            return callTarget(resource, 'addSphereZone', {
                coords = circle.coords,
                radius = circle.radius,
                debug = TSS.ShouldDebugPoly(circle.options.debugPoly or circle.options.debug),
                options = normaliseOxOptions(options, distance),
            })
        end,
        removeEntity = function(resource, entity)
            return callTarget(resource, 'removeLocalEntity', entity)
        end,
        removeModel = function(resource, models)
            return callTarget(resource, 'removeModel', models)
        end,
        removeZone = function(resource, zone)
            return callTarget(resource, 'removeZone', zone)
        end,
    },
    qb = {
        entity = addQbEntity,
        model = addQbModel,
        box = addQbBox,
        circle = addQbCircle,
        removeEntity = function(resource, entity) return callTarget(resource, 'RemoveTargetEntity', entity) end,
        removeModel = function(resource, models) return callTarget(resource, 'RemoveTargetModel', models) end,
        removeZone = function(resource, zone) return callTarget(resource, 'RemoveZone', zone) end,
    },
    tgiann = {
        entity = addQbEntity,
        model = addQbModel,
        box = addQbBox,
        circle = addQbCircle,
        removeEntity = function(resource, entity) return callTarget(resource, 'RemoveTargetEntity', entity) end,
        removeModel = function(resource, models) return callTarget(resource, 'RemoveTargetModel', models) end,
        removeZone = function(resource, zone) return callTarget(resource, 'RemoveZone', zone) end,
    },
    bt = {
        entity = addQbEntity,
        model = addQbModel,
        box = addQbBox,
        circle = addQbCircle,
        removeEntity = function(resource, entity) return callTarget(resource, 'RemoveTargetEntity', entity) end,
        removeModel = function(resource, models) return callTarget(resource, 'RemoveTargetModel', models) end,
        removeZone = function(resource, zone) return callTarget(resource, 'RemoveZone', zone) end,
    },
}

local function getAdapter()
    local system = getTargetSystem()
    local resource = getTargetResource(system)

    if not system or not resource or not adapters[system] then
        TSS.Warn('No supported target system found')
        return nil, nil, nil
    end

    if not TSS.IsStarted(resource) then
        TSS.Warn(('Configured target is not started: %s'):format(resource))
        return nil, nil, nil
    end

    return adapters[system], resource, system
end

--- Adds target options to one or more local entities.
---@param entity TSSEntity|TSSEntity[] Entity handle or handles.
---@param options TSSTargetOption[]|TSSTargetOption Target options.
---@param distance? number Default interaction distance.
---@return any result Adapter result.
function TSS.Target.Entity(entity, options, distance)
    local adapter, resource = getAdapter()
    if not adapter then return nil end

    tracked.entities[entity] = true
    return adapter.entity(resource, entity, options, distance)
end

--- Adds target options to one or more models.
---@param models string|integer|(string|integer)[] Model name, hash, or list.
---@param options TSSTargetOption[]|TSSTargetOption Target options.
---@param distance? number Default interaction distance.
---@return any result Adapter result.
function TSS.Target.Model(models, options, distance)
    local adapter, resource = getAdapter()
    if not adapter then return nil end

    tracked.models[#tracked.models + 1] = models
    return adapter.model(resource, models, options, distance)
end

--- Creates a box target zone.
---@param data TSSTargetZoneData Zone definition.
---@param options TSSTargetOption[]|TSSTargetOption Target options.
---@param distance? number Default interaction distance.
---@return string|number? zone Adapter zone identifier.
function TSS.Target.Box(data, options, distance)
    local adapter, resource = getAdapter()
    if not adapter then return nil end

    local zone = adapter.box(resource, data, options, distance)
    tracked.zones[#tracked.zones + 1] = zone

    return zone
end

--- Creates a circle or sphere target zone.
---@param data TSSTargetZoneData Zone definition.
---@param options TSSTargetOption[]|TSSTargetOption Target options.
---@param distance? number Default interaction distance.
---@return string|number? zone Adapter zone identifier.
function TSS.Target.Circle(data, options, distance)
    local adapter, resource = getAdapter()
    if not adapter then return nil end

    local zone = adapter.circle(resource, data, options, distance)
    tracked.zones[#tracked.zones + 1] = zone

    return zone
end

--- Removes target options from one or more local entities.
---@param entity TSSEntity|TSSEntity[] Entity handle or handles.
---@return any result Adapter result.
function TSS.Target.RemoveEntity(entity)
    local adapter, resource = getAdapter()
    if not adapter then return nil end

    tracked.entities[entity] = nil
    return adapter.removeEntity(resource, entity)
end

--- Removes target options from one or more models.
---@param models string|integer|(string|integer)[] Model name, hash, or list.
---@return any result Adapter result.
function TSS.Target.RemoveModel(models)
    local adapter, resource = getAdapter()
    if not adapter then return nil end

    return adapter.removeModel(resource, models)
end

--- Removes a target zone.
---@param zone string|number Adapter zone identifier.
---@return any result Adapter result.
function TSS.Target.RemoveZone(zone)
    local adapter, resource = getAdapter()
    if not adapter then return nil end

    return adapter.removeZone(resource, zone)
end

--- Removes every target registered internally by this bridge instance.
function TSS.Target.Clear()
    local adapter, resource = getAdapter()
    if not adapter then return end

    for entity in pairs(tracked.entities) do
        adapter.removeEntity(resource, entity)
        tracked.entities[entity] = nil
    end

    for i = 1, #tracked.models do
        adapter.removeModel(resource, tracked.models[i])
        tracked.models[i] = nil
    end

    for i = 1, #tracked.zones do
        if tracked.zones[i] then
            adapter.removeZone(resource, tracked.zones[i])
        end
        tracked.zones[i] = nil
    end
end

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        TSS.Target.Clear()
    end
end)

function createEntityTarget(entity, options, distance)
    return TSS.Target.Entity(entity, options, distance)
end

function createModelTarget(models, options, distance)
    return TSS.Target.Model(models, options, distance)
end

function createBoxTarget(data, options, distance)
    return TSS.Target.Box(data, options, distance)
end

function createCircleTarget(data, options, distance)
    return TSS.Target.Circle(data, options, distance)
end

function createZoneTarget(data, options, distance)
    local zoneType = first(data.type, data.zoneType, data.shape)

    if zoneType == 'circle' or zoneType == 'sphere' then
        return TSS.Target.Circle(data, options, distance)
    end

    return TSS.Target.Box(data, options, distance)
end

function removeEntityTarget(entity)
    return TSS.Target.RemoveEntity(entity)
end

function removeModelTarget(models)
    return TSS.Target.RemoveModel(models)
end

function removeZoneTarget(zone)
    return TSS.Target.RemoveZone(zone)
end
