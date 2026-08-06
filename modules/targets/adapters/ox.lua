local utils = TSS.Target.Utils

TSS.Target.RegisterAdapter('ox', TSS.Resources.OxTarget, {
    supports = { entity = true, model = true, box = true, circle = true, groups = true, items = true },
    entity = function(resource, entity, options, distance)
        return utils.Call(resource, 'addLocalEntity', entity, utils.NormaliseOxOptions(options, distance))
    end,
    model = function(resource, models, options, distance)
        return utils.Call(resource, 'addModel', models, utils.NormaliseOxOptions(options, distance))
    end,
    box = function(resource, data, options, distance)
        local box = utils.GetBoxData(data)
        local minZ = box.options.minZ or (box.coords.z - 1.0)
        local maxZ = box.options.maxZ or (box.coords.z + 1.0)
        return utils.Call(resource, 'addBoxZone', {
            coords = vec3(box.coords.x, box.coords.y, minZ + ((maxZ - minZ) / 2)),
            size = vec3(box.length, box.width, maxZ - minZ),
            rotation = box.options.heading or box.options.rotation or 0.0,
            debug = TSS.ShouldDebugPoly(box.options.debugPoly or box.options.debug),
            options = utils.NormaliseOxOptions(options, distance),
        })
    end,
    circle = function(resource, data, options, distance)
        local circle = utils.GetCircleData(data)
        return utils.Call(resource, 'addSphereZone', {
            coords = circle.coords, radius = circle.radius,
            debug = TSS.ShouldDebugPoly(circle.options.debugPoly or circle.options.debug),
            options = utils.NormaliseOxOptions(options, distance),
        })
    end,
    removeEntity = function(resource, entity) return utils.Call(resource, 'removeLocalEntity', entity) end,
    removeModel = function(resource, models) return utils.Call(resource, 'removeModel', models) end,
    removeZone = function(resource, zone) return utils.Call(resource, 'removeZone', zone) end,
}, { priority = 10, aliases = { 'ox_target' } })
