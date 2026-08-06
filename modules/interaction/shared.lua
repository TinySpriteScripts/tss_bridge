-- Lazy client implementation owned by the Interaction module.
TSS = TSS or {}
TSS.Interaction = TSS.Interaction or {}
TSS.Interaction.Utils = TSS.Interaction.Utils or {}

local registry = TSS.Adapters.Create('Interaction', { config = 'Interaction', fallback = 'textui' })

local entries = {}
local nextId = 0
local proximityThread = false
local visibleEntry

local function detect(preferred)
    return registry:Resolve(preferred)
end

function TSS.Interaction.RegisterAdapter(key, resource, adapter, options)
    return registry:Register(key, resource, adapter, options)
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

TSS.Interaction.Utils.StartProximity = startProximityThread

--- Detects whether interactions use a target adapter or proximity TextUI.
---@param preferred? string Adapter override for this interaction.
---@return string system
---@return string? resource
function TSS.Interaction.System(preferred)
    local system, resource = detect(preferred)
    return system, resource
end

--- Reports whether an interaction mode supports a feature.
---@param feature string Feature such as `entity`, `coords`, `groups`, or `items`.
---@param preferred? string Adapter override for this check.
---@return boolean supported
function TSS.Interaction.Supports(feature, preferred)
    feature = tostring(feature or ''):lower()
    if feature == 'callback' or feature == 'event' or feature == 'serverevent' then return true end
    return registry:Supports(feature, preferred)
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
        system = nil,
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

    local system, resource, adapter = detect(data.adapter)
    entry.system = system
    entry.adapter = adapter
    entry.adapterResource = resource
    if not adapter or not adapter.create or adapter.create(resource, entry, data, activate) ~= true then return nil end

    entries[entry.id] = entry
    if system == 'textui' then startProximityThread() end
    return entry.id
end

--- Removes one interaction by ID.
---@param id integer Interaction ID returned by `Create`.
---@return boolean removed
function TSS.Interaction.Remove(id)
    local entry = entries[id]
    if not entry then return false end
    if visibleEntry == entry then hideVisible() end
    if entry.adapter and entry.adapter.remove then entry.adapter.remove(entry.adapterResource, entry) end
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
