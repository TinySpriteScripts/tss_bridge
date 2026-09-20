-- Public vehicle-key API. Key-resource behaviour lives in adapters.
TSS = TSS or {}
TSS.VehicleKeys = TSS.VehicleKeys or {}
TSS.VehicleKeys.Utils = TSS.VehicleKeys.Utils or {}

local registry = TSS.Adapters.Create('VehicleKeys', { config = 'VehicleKeys' })

function TSS.VehicleKeys.Utils.NormalizePlate(value)
    if type(value) == 'number' and DoesEntityExist(value) then
        value = GetVehicleNumberPlateText(value)
    end
    if type(value) ~= 'string' then return nil end
    return value:match('^%s*(.-)%s*$'):upper()
end

function TSS.VehicleKeys.RegisterAdapter(key, resource, adapter, options)
    return registry:Register(key, resource, adapter, options)
end

function TSS.VehicleKeys._Detect(preferred)
    return registry:Resolve(preferred)
end

TSS.VehicleKeys._NormalizePlate = TSS.VehicleKeys.Utils.NormalizePlate

--- Detects the selected vehicle-key adapter.
---@param preferred? string
---@return string? system
---@return string? resource
function TSS.VehicleKeys.System(preferred)
    local system, resource = registry:Resolve(preferred)
    return system, resource
end

--- Reports whether the active adapter supports a feature in this realm.
---@param feature 'has'|'give'|'remove'|string
---@return boolean supported
function TSS.VehicleKeys.Supports(feature)
    feature = tostring(feature or ''):lower()
    if TSS.IsClient() and feature ~= 'has' then return false end
    return registry:Supports(feature)
end

--- Checks whether a player owns keys for a vehicle or plate.
---@param first integer|TSSEntity|string
---@param second? TSSEntity|string
---@return boolean hasKeys
function TSS.VehicleKeys.Has(first, second)
    local _, resource, adapter = registry:Resolve()
    if not adapter or not adapter.has then return false end
    if TSS.IsServer() then
        return type(first) == 'number' and adapter.has(resource, first, second) == true or false
    end
    return adapter.has(resource, first) == true
end

--- Gives vehicle keys to a player. Server only.
---@param source integer
---@param vehicleOrPlate TSSEntity|string
---@return boolean success
function TSS.VehicleKeys.Give(source, vehicleOrPlate)
    if not TSS.IsServer() or type(source) ~= 'number' then return false end
    local _, resource, adapter = registry:Resolve()
    return adapter and adapter.give and adapter.give(resource, source, vehicleOrPlate) == true or false
end

--- Removes vehicle keys from a player. Server only.
---@param source integer
---@param vehicleOrPlate TSSEntity|string
---@return boolean success
function TSS.VehicleKeys.Remove(source, vehicleOrPlate)
    if not TSS.IsServer() or type(source) ~= 'number' then return false end
    local _, resource, adapter = registry:Resolve()
    return adapter and adapter.remove and adapter.remove(resource, source, vehicleOrPlate) == true or false
end
