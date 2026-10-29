local utils = TSS.Target.Utils

local function normalise(options, pointCoords)
    if options.label then options = { options } end
    local result = {}
    for index, option in ipairs(options) do
        local copy = {}
        for key, value in pairs(option) do copy[key] = value end
        -- Bridge groups and inventories may come from a different framework/provider.
        local groups, items = option.groups, option.items or option.item
        copy.groups, copy.items, copy.item = nil, nil, nil
        copy.canInteract = function(entity, distance, data)
            if groups and not TSS.Player.HasGroup(groups) then return false end
            if items then
                if type(items) == 'string' then
                    if not TSS.Inventory.Has(items, 1) then return false end
                elseif type(items) == 'table' then
                    for key, value in pairs(items) do
                        local name, amount = key, tonumber(value) or 1
                        if type(key) == 'number' then name, amount = value, 1 end
                        if not TSS.Inventory.Has(name, amount) then return false end
                    end
                else return false end
            end
            local coords = pointCoords
            if entity and entity ~= 0 then coords = GetEntityCoords(entity) end
            return not option.canInteract or option.canInteract(entity, distance, coords, option.name)
        end
        if option.action then
            copy.action = option.action
        elseif option.onSelect then
            copy.action = function(entity, data)
                option.onSelect({ entity = entity, coords = data.coords, args = option.args })
            end
        elseif option.serverEvent then
            copy.action = function() TriggerServerEvent(option.serverEvent, option.args) end
        elseif option.command then
            copy.action = function() ExecuteCommand(option.command) end
        elseif option.event and option.args ~= nil and (not option.type or option.type == 'client' or option.type == 'server') then
            copy.action = function()
                if option.type == 'server' then TriggerServerEvent(option.event, option.args)
                else TriggerEvent(option.event, option.args) end
            end
        end
        copy.onSelect, copy.serverEvent, copy.command = nil, nil, nil
        result[index] = copy
    end
    return result
end

local function point(resource, data, options, distance)
    local coords, name = data.coords or data[2], data.name or data[1]
    local registration = { options = normalise(options, coords), distance = distance or 2.0 }
    -- Radius, dimensions, heading and Z bounds deliberately do not create geometry.
    if name then return utils.Call(resource, 'AddPoint', name, coords, registration) end
    return utils.Call(resource, 'AddInteraction', coords, registration.options, registration.distance)
end

TSS.Target.RegisterAdapter('tss_interact', TSS.Resources.TssInteract, {
    supports = { entity = true, bones = true, model = true, box = true, circle = true, groups = true, items = true },
    bone = function(resource, bones, options, distance)
        local registration = utils.BoneRegistration(bones, options)
        utils.Call(resource, 'AddBone', registration.bones, { options = normalise(options), distance = distance or 2.0 })
        return registration
    end,
    removeBone = function(resource, registration) return utils.Call(resource, 'RemoveBone', registration.bones, registration.names) end,
    entity = function(resource, entity, options, distance)
        return utils.Call(resource, 'AddEntity', entity, { options = normalise(options), distance = distance or 2.0 })
    end,
    model = function(resource, models, options, distance)
        return utils.Call(resource, 'AddModel', models, { options = normalise(options), distance = distance or 2.0 })
    end,
    box = point,
    circle = point,
    removeEntity = function(resource, entity) return utils.Call(resource, 'RemoveEntity', entity) end,
    removeModel = function(resource, models) return utils.Call(resource, 'RemoveModel', models) end,
    removeZone = function(resource, id) return utils.Call(resource, 'RemoveInteraction', id) end,
}, { priority = 50, aliases = { 'tss-interactions', 'tss_interactions' } })
