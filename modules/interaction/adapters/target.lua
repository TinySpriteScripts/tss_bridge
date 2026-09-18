TSS.Interaction.RegisterAdapter('target', nil, {
    supports = function(feature, targets)
        return (targets or TSS.Target).Supports(feature)
    end,
    create = function(_, entry, data, activate)
        local targets = entry.targets or TSS.Target
        local option = {
            name = data.name or ('tss_interaction_%s'):format(entry.id),
            label = entry.label, icon = entry.icon, distance = entry.distance,
            canInteract = entry.canInteract,
            onSelect = function(context) activate(entry, context) end,
            groups = data.groups, job = data.job, gang = data.gang,
            items = data.items, item = data.item,
        }

        if entry.entity then
            targets.Entity(entry.entity, { option }, entry.distance)
            entry.target = { kind = 'entity', value = entry.entity }
        elseif entry.model then
            targets.Model(entry.model, { option }, entry.distance)
            entry.target = { kind = 'model', value = entry.model }
        elseif entry.coords then
            local zoneData = {
                name = option.name, coords = entry.coords, radius = data.radius or entry.distance,
                length = data.length, width = data.width, minZ = data.minZ, maxZ = data.maxZ,
                heading = data.heading, debug = data.debug,
            }
            local zone = (data.shape == 'box' or data.length or data.width)
                and targets.Box(zoneData, { option }, entry.distance)
                or targets.Circle(zoneData, { option }, entry.distance)
            if not zone then return false end
            entry.target = { kind = 'zone', value = zone }
        else
            return false
        end
        return true
    end,
    remove = function(_, entry)
        local targets = entry.targets or TSS.Target
        if not entry.target then return true end
        if entry.target.kind == 'entity' then targets.RemoveEntity(entry.target.value) end
        if entry.target.kind == 'model' then targets.RemoveModel(entry.target.value) end
        if entry.target.kind == 'zone' then targets.RemoveZone(entry.target.value) end
        entry.target = nil
        return true
    end,
}, {
    priority = 10,
    available = function(_, _, targets) return (targets or TSS.Target).System() ~= nil end,
})
