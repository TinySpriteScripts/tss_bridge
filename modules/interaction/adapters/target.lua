TSS.Interaction.RegisterAdapter('target', nil, {
    supports = function(feature)
        return TSS.Target.Supports(feature)
    end,
    create = function(_, entry, data, activate)
        local option = {
            name = data.name or ('tss_interaction_%s'):format(entry.id),
            label = entry.label, icon = entry.icon, distance = entry.distance,
            canInteract = entry.canInteract,
            onSelect = function(context) activate(entry, context) end,
            groups = data.groups, job = data.job, gang = data.gang,
            items = data.items, item = data.item,
        }

        if entry.entity then
            TSS.Target.Entity(entry.entity, { option }, entry.distance)
            entry.target = { kind = 'entity', value = entry.entity }
        elseif entry.model then
            TSS.Target.Model(entry.model, { option }, entry.distance)
            entry.target = { kind = 'model', value = entry.model }
        elseif entry.coords then
            local zoneData = {
                name = option.name, coords = entry.coords, radius = data.radius or entry.distance,
                length = data.length, width = data.width, minZ = data.minZ, maxZ = data.maxZ,
                heading = data.heading, debug = data.debug,
            }
            local zone = (data.shape == 'box' or data.length or data.width)
                and TSS.Target.Box(zoneData, { option }, entry.distance)
                or TSS.Target.Circle(zoneData, { option }, entry.distance)
            if not zone then return false end
            entry.target = { kind = 'zone', value = zone }
        else
            return false
        end
        return true
    end,
    remove = function(_, entry)
        if not entry.target then return true end
        if entry.target.kind == 'entity' then TSS.Target.RemoveEntity(entry.target.value) end
        if entry.target.kind == 'model' then TSS.Target.RemoveModel(entry.target.value) end
        if entry.target.kind == 'zone' then TSS.Target.RemoveZone(entry.target.value) end
        entry.target = nil
        return true
    end,
}, {
    priority = 10,
    available = function() return TSS.Target.System() ~= nil end,
})
