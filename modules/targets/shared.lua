-- Lazy client implementation owned by the Targets module.
TSS = TSS or {}
TSS.Target = TSS.Target or {}
TSS.Target.Utils = TSS.Target.Utils or {}

local registry = TSS.Adapters.Create('Targets', { config = 'Target' })

local scopedApis = {}

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

function TSS.Target.RegisterAdapter(key, resource, adapter, options)
    return registry:Register(key, resource, adapter, options)
end

--- Detects the selected target adapter.
---@return string? system
---@return string? resource
function TSS.Target.System(preferred)
    local system, resource = registry:Resolve(preferred)
    return system, resource
end

--- Reports whether the selected target adapter supports a feature.
---@param feature 'entity'|'model'|'box'|'circle'|'groups'|'items'|string
---@return boolean supported
function TSS.Target.Supports(feature)
    return registry:Supports(feature)
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
            bones = option.bones,
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

TSS.Target.Utils.First = first
TSS.Target.Utils.NormaliseOxOptions = normaliseOxOptions
TSS.Target.Utils.NormaliseQbOptions = normaliseQbOptions
TSS.Target.Utils.BoneRegistration = function(bones, options)
    local registration = { bones = type(bones) == 'table' and bones or { bones }, names = {}, labels = {} }
    for _, option in ipairs(asArray(options)) do
        registration.names[#registration.names + 1] = option.name or option.label
        registration.labels[#registration.labels + 1] = option.label
    end
    return registration
end
TSS.Target.Utils.GetBoxData = getBoxData
TSS.Target.Utils.GetCircleData = getCircleData
TSS.Target.Utils.Call = callTarget
TSS.Target.Utils.AddQbEntity = addQbEntity
TSS.Target.Utils.AddQbModel = addQbModel
TSS.Target.Utils.AddQbBox = addQbBox
TSS.Target.Utils.AddQbCircle = addQbCircle

-- Each imported API owns its registrations and remembers the creating provider.
function TSS.Target.CreateAPI(preferred)
    local public = {}
    local tracked = { entities = {}, models = {}, zones = {}, bones = {} }
    -- Arrays cross resource exports by value, so table identity cannot identify them.
    local function registrationKey(value)
        if type(value) ~= 'table' then return value end
        local keys = {}
        for i = 1, #value do keys[i] = type(value[i]) .. ':' .. tostring(value[i]) end
        table.sort(keys)
        return 'list:' .. table.concat(keys, '|')
    end
    function public.System(override)
        local system, resource = registry:Resolve(override or preferred)
        return system, resource
    end
    function public.Supports(feature, override)
        return registry:Supports(feature, override or preferred)
    end
    local function add(kind, method, value, options, distance)
        local _, resource, adapter = registry:Resolve(preferred)
        if not adapter then TSS.Warn('No supported target system found'); return nil end
        local result = adapter[method](resource, value, options, distance)
        local key = kind == 'zones' and result or value
        if key ~= nil then
            local saved = key
            if type(key) == 'table' then
                saved = {}
                for i = 1, #key do saved[i] = key[i] end
            end
            tracked[kind][registrationKey(key)] = { adapter = adapter, resource = resource, value = saved }
        end
        return result
    end
    local function remove(kind, method, value)
        local key = registrationKey(value)
        local entry = tracked[kind][key]
        if not entry then return end
        tracked[kind][key] = nil
        return entry.adapter[method](entry.resource, entry.value)
    end
    function public.Entity(entity, options, distance) return add('entities', 'entity', entity, options, distance) end
    function public.Bone(bones, options, distance)
        local _, resource, adapter = registry:Resolve(preferred)
        if not adapter or not adapter.bone then return false end
        local key = registrationKey(bones)
        if tracked.bones[key] then public.RemoveBone(bones) end
        local registration = adapter.bone(resource, bones, options, distance)
        if not registration then return false end
        tracked.bones[key] = { adapter = adapter, resource = resource, value = registration, bones = bones }
        return true
    end
    function public.RemoveBone(bones) return remove('bones', 'removeBone', bones) end
    function public.Model(models, options, distance) return add('models', 'model', models, options, distance) end
    function public.Box(data, options, distance) return add('zones', 'box', data, options, distance) end
    function public.Circle(data, options, distance) return add('zones', 'circle', data, options, distance) end
    function public.RemoveEntity(entity) return remove('entities', 'removeEntity', entity) end
    function public.RemoveModel(models) return remove('models', 'removeModel', models) end
    function public.RemoveZone(zone) return remove('zones', 'removeZone', zone) end
    function public.Clear()
        for _, entry in pairs(tracked.bones) do public.RemoveBone(entry.bones) end
        for _, entry in pairs(tracked.entities) do public.RemoveEntity(entry.value) end
        for _, entry in pairs(tracked.models) do public.RemoveModel(entry.value) end
        for _, entry in pairs(tracked.zones) do public.RemoveZone(entry.value) end
    end
    scopedApis[public] = true
    return public
end

-- Weak keys allow an unused, cleaned consumer API to be collected.
setmetatable(scopedApis, { __mode = 'k' })
local defaultAPI = TSS.Target.CreateAPI()
for name, fn in pairs(defaultAPI) do TSS.Target[name] = fn end

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for api in pairs(scopedApis) do api.Clear() end
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
