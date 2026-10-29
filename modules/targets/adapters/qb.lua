local utils = TSS.Target.Utils

TSS.Target.RegisterAdapter('qb', TSS.Resources.QbTarget, {
    supports = { 
        entity = true, 
        bones = true,
        model = true, 
        box = true, 
        circle = true, 
        groups = true, 
        items = true 
    },
    entity = utils.AddQbEntity, 
    bone = function(resource, bones, options, distance)
        local registration = utils.BoneRegistration(bones, options)
        utils.Call(resource, 'AddTargetBone', registration.bones, {
            options = utils.NormaliseQbOptions(options), distance = distance or 2.0,
        })
        return registration
    end,
    removeBone = function(resource, registration) return utils.Call(resource, 'RemoveTargetBone', registration.bones, registration.labels) end,
    model = utils.AddQbModel, 
    box = utils.AddQbBox, 
    circle = utils.AddQbCircle,

    removeEntity = function(resource, entity) return utils.Call(resource, 'RemoveTargetEntity', entity) end,

    removeModel = function(resource, models) return utils.Call(resource, 'RemoveTargetModel', models) end,

    removeZone = function(resource, zone) return utils.Call(resource, 'RemoveZone', zone) end,
    
}, { priority = 20, aliases = { 'qb-target' } })
