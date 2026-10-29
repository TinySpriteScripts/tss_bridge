local utils = TSS.Target.Utils

TSS.Target.RegisterAdapter('ox', TSS.Resources.OxTarget, {
    supports = { entity = true, bones = true, model = true, box = true, circle = true, groups = true, items = true },
    bone = function(resource, bones, options, distance)
        local registration = utils.BoneRegistration(bones, options)
        local normalized = utils.NormaliseOxOptions(options, distance)
        for optionIndex, option in ipairs(normalized) do
            option.bones = registration.bones
            option.name = registration.names[optionIndex]
        end
        utils.Call(resource, 'addGlobalVehicle', normalized)
        return registration
    end,
    removeBone = function(resource, registration) return utils.Call(resource, 'removeGlobalVehicle', registration.names) end,
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
        -- Calls into ox_target are owned by tss_bridge, not by the consuming
        -- resource. Preserve the consumer's deterministic zone name so a
        -- restart can replace stale zones instead of stacking options.
        if box.name then utils.Call(resource, 'removeZone', box.name, true) end
        return utils.Call(resource, 'addBoxZone', {
            name = box.name,
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
            name = circle.name,
            coords = circle.coords, radius = circle.radius,
            debug = TSS.ShouldDebugPoly(circle.options.debugPoly or circle.options.debug),
            options = utils.NormaliseOxOptions(options, distance),
        })
    end,
    removeEntity = function(resource, entity) return utils.Call(resource, 'removeLocalEntity', entity) end,
    removeModel = function(resource, models) return utils.Call(resource, 'removeModel', models) end,
    removeZone = function(resource, zone) return utils.Call(resource, 'removeZone', zone) end,
}, { priority = 10, aliases = { 'ox_target' } })
