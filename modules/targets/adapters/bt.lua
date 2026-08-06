local utils = TSS.Target.Utils

TSS.Target.RegisterAdapter('bt', TSS.Resources.BtTarget, {
    supports = { entity = true, model = true, box = true, circle = true, groups = true, items = true },
    entity = utils.AddQbEntity, model = utils.AddQbModel, box = utils.AddQbBox, circle = utils.AddQbCircle,
    removeEntity = function(resource, entity) return utils.Call(resource, 'RemoveTargetEntity', entity) end,
    removeModel = function(resource, models) return utils.Call(resource, 'RemoveTargetModel', models) end,
    removeZone = function(resource, zone) return utils.Call(resource, 'RemoveZone', zone) end,
}, { priority = 40, aliases = { 'bt-target' } })
