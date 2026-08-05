-- Lazy client implementation owned by the Interaction module.
TSS = TSS or {}
TSS.Interaction = TSS.Interaction or {}

local entries = {}
local nextId = 0
local proximityThread = false
local visibleEntry

local function targetAvailable()
    local system = TSS.Target.System()
    return system ~= nil
end

local function detect(preferred)
    local configured = tostring(preferred or TSS.Config.Interaction or 'auto'):lower()
    if configured == 'target' then return targetAvailable() and 'target' or 'textui' end
    if configured == 'textui' or configured == 'proximity' then return 'textui' end
    return targetAvailable() and 'target' or 'textui'
end

local function coordsFor(entry)
    if entry.entity and DoesEntityExist(entry.entity) then return GetEntityCoords(entry.entity) end
    return entry.coords
end

local function hasItems(filter)
    if filter == nil then return true end
    if type(filter) == 'string' then return TSS.Inventory.Has(filter, 1) end
    if type(filter) ~= 'table' then return false end

    for key, value in pairs(filter) do
        if type(key) == 'number' then
            if not TSS.Inventory.Has(value, 1) then return false end
        elseif not TSS.Inventory.Has(key, tonumber(value) or 1) then
            return false
        end
    end
    return true
end

local function canUse(entry, context)
    if entry.groups and not TSS.Player.HasGroup(entry.groups) then return false end
    if not hasItems(entry.items) then return false end
    return not entry.canInteract or entry.canInteract(entry.entity, context) ~= false
end

local function activate(entry, context)
    if not canUse(entry, context) then return end
    if entry.onSelect then return entry.onSelect(context or { entity = entry.entity, coords = entry.coords }) end
    if entry.serverEvent then return TriggerServerEvent(entry.serverEvent, entry.args) end
    if entry.event then return TriggerEvent(entry.event, entry.args) end
    if entry.command then return ExecuteCommand(entry.command) end
end

local function hideVisible()
    if visibleEntry then
        TSS.TextUI.Hide(visibleEntry.owner)
        visibleEntry = nil
    end
end

local function startProximityThread()
    if proximityThread then return end
    proximityThread = true

    CreateThread(function()
        while next(entries) do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local closest, closestDistance
            local hasProximity = false

            for _, entry in pairs(entries) do
                if entry.system == 'textui' then
                    hasProximity = true
                    local coords = coordsFor(entry)
                    if coords then
                        local distance = #(playerCoords - vec3(coords.x, coords.y, coords.z))
                        if distance <= entry.distance and canUse(entry, { entity = entry.entity, coords = entry.coords, distance = distance })
                            and (not closestDistance or distance < closestDistance) then
                            closest = entry
                            closestDistance = distance
                        end
                    end
                end
            end

            if not hasProximity then break end

            if closest ~= visibleEntry then
                hideVisible()
                if closest then
                    TSS.TextUI.Show({
                        text = closest.text or ('[%s] %s'):format(closest.keyLabel, closest.label),
                        position = closest.position,
                        icon = closest.icon,
                        adapter = closest.textUI,
                    }, closest.owner)
                    visibleEntry = closest
                end
            end

            if closest and IsControlJustReleased(0, closest.control) then
                activate(closest, { entity = closest.entity, coords = closest.coords, distance = closestDistance })
            end

            Wait(closest and 0 or 250)
        end

        hideVisible()
        proximityThread = false
    end)
end

local function removeTarget(entry)
    if not entry.target then return end
    if entry.target.kind == 'entity' then TSS.Target.RemoveEntity(entry.target.value) end
    if entry.target.kind == 'model' then TSS.Target.RemoveModel(entry.target.value) end
    if entry.target.kind == 'zone' then TSS.Target.RemoveZone(entry.target.value) end
    entry.target = nil
end

--- Detects whether interactions use a target adapter or proximity TextUI.
---@param preferred? string Adapter override for this interaction.
---@return string system
---@return string? resource
function TSS.Interaction.System(preferred)
    return detect(preferred)
end

--- Reports whether an interaction mode supports a feature.
---@param feature string Feature such as `entity`, `coords`, `groups`, or `items`.
---@param preferred? string Adapter override for this check.
---@return boolean supported
function TSS.Interaction.Supports(feature, preferred)
    local system = detect(preferred)
    feature = tostring(feature or ''):lower()
    if feature == 'callback' or feature == 'event' or feature == 'serverevent' then return true end
    if system == 'target' then return TSS.Target.Supports(feature) end
    return feature == 'coords' or feature == 'entity' or feature == 'key'
end

--- Creates a target or proximity interaction owned by the calling resource.
---@param data TSSInteractionData Interaction definition.
---@param owner? string Internal caller namespace.
---@return integer? id Interaction ID.
---@usage
--- ```lua
--- local id = TSS.Interaction.Create({
---     coords = vec3(100.0, 200.0, 30.0),
---     label = 'Open storage',
---     onSelect = function() print('selected') end,
--- })
--- ```
function TSS.Interaction.Create(data, owner)
    if type(data) ~= 'table' then return nil end
    nextId = nextId + 1

    local entry = {
        id = nextId,
        owner = owner or GetCurrentResourceName(),
        system = detect(data.adapter),
        entity = data.entity,
        model = data.model or data.models,
        coords = data.coords,
        label = tostring(data.label or data.text or 'Interact'),
        text = data.text,
        icon = data.icon,
        position = data.position,
        distance = tonumber(data.distance or data.radius) or 2.0,
        control = tonumber(data.control) or 38,
        keyLabel = tostring(data.key or 'E'),
        textUI = data.textUI,
        groups = data.groups or data.job or data.gang,
        items = data.items or data.item,
        onSelect = data.onSelect or data.action,
        canInteract = data.canInteract,
        event = data.event,
        serverEvent = data.serverEvent,
        command = data.command,
        args = data.args,
    }

    if entry.system == 'target' then
        local option = {
            name = data.name or ('tss_interaction_%s'):format(entry.id),
            label = entry.label,
            icon = entry.icon,
            distance = entry.distance,
            canInteract = entry.canInteract,
            onSelect = function(context) activate(entry, context) end,
            groups = data.groups,
            job = data.job,
            gang = data.gang,
            items = data.items,
            item = data.item,
        }

        if entry.entity then
            TSS.Target.Entity(entry.entity, { option }, entry.distance)
            entry.target = { kind = 'entity', value = entry.entity }
        elseif entry.model then
            TSS.Target.Model(entry.model, { option }, entry.distance)
            entry.target = { kind = 'model', value = entry.model }
        elseif entry.coords then
            local zoneData = {
                name = option.name,
                coords = entry.coords,
                radius = data.radius or entry.distance,
                length = data.length,
                width = data.width,
                minZ = data.minZ,
                maxZ = data.maxZ,
                heading = data.heading,
                debug = data.debug,
            }
            local zone = (data.shape == 'box' or data.length or data.width)
                and TSS.Target.Box(zoneData, { option }, entry.distance)
                or TSS.Target.Circle(zoneData, { option }, entry.distance)
            entry.target = { kind = 'zone', value = zone }
        else
            return nil
        end
    else
        if not entry.coords and not entry.entity then return nil end
        entries[entry.id] = entry
        startProximityThread()
    end

    entries[entry.id] = entry
    return entry.id
end

--- Removes one interaction by ID.
---@param id integer Interaction ID returned by `Create`.
---@return boolean removed
function TSS.Interaction.Remove(id)
    local entry = entries[id]
    if not entry then return false end
    if visibleEntry == entry then hideVisible() end
    removeTarget(entry)
    entries[id] = nil
    return true
end

--- Removes interactions belonging to an owner, or all interactions internally.
---@param owner? string Internal caller namespace.
function TSS.Interaction.Clear(owner)
    local ids = {}
    for id, entry in pairs(entries) do
        if not owner or entry.owner == owner then ids[#ids + 1] = id end
    end
    for i = 1, #ids do TSS.Interaction.Remove(ids[i]) end
end

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then TSS.Interaction.Clear() end
end)
