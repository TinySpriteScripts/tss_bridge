-- Lazy realm-aware implementation owned by the VehicleKeys module.
TSS = TSS or {}
TSS.VehicleKeys = TSS.VehicleKeys or {}

local aliases = {
    ['qb'] = 'qb', ['qb-vehiclekeys'] = 'qb',
    ['qbox'] = 'qbox', ['qbx'] = 'qbox', ['qbx_vehiclekeys'] = 'qbox',
    ['none'] = 'none',
}

local function detect(preferred)
    local configured = tostring(preferred or TSS.Config.VehicleKeys or 'auto'):lower()
    if configured ~= 'auto' then
        local system = aliases[configured] or configured
        if system == 'none' then return system end
        local resource = system == 'qbox' and TSS.Resources.QboxVehicleKeys or system == 'qb' and TSS.Resources.QbVehicleKeys
        if resource and TSS.IsStarted(resource) then return system, resource end
        TSS.Warn(('Configured vehicle key system is not started: %s'):format(tostring(resource or configured)))
        return nil, nil
    end

    if TSS.IsStarted(TSS.Resources.QboxVehicleKeys) then return 'qbox', TSS.Resources.QboxVehicleKeys end
    if TSS.IsStarted(TSS.Resources.QbVehicleKeys) then return 'qb', TSS.Resources.QbVehicleKeys end
    return nil, nil
end

local function normalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    return plate:match('^%s*(.-)%s*$'):upper()
end

TSS.VehicleKeys._Detect = detect
TSS.VehicleKeys._NormalizePlate = normalizePlate

--- Detects the selected vehicle-key adapter.
---@param preferred? string Adapter override for this call.
---@return string? system
---@return string? resource
function TSS.VehicleKeys.System(preferred)
    return detect(preferred)
end

--- Reports whether the vehicle-key adapter supports a feature in this realm.
---@param feature 'has'|'give'|'remove'|string
---@return boolean supported
function TSS.VehicleKeys.Supports(feature)
    local system = detect()
    feature = tostring(feature or ''):lower()
    if not TSS.IsServer() and feature ~= 'has' then return false end
    if system == 'qbox' then return feature == 'has' or feature == 'give' or feature == 'remove' end
    if system == 'qb' then return feature == 'has' or feature == 'give' or feature == 'remove' end
    return false
end

--- Checks whether a player owns keys for a vehicle or plate.
---@param first integer|TSSEntity|string Server player ID, or vehicle/plate on the client.
---@param second? TSSEntity|string Vehicle or plate on the server.
---@return boolean hasKeys
function TSS.VehicleKeys.Has(first, second)
    local system, resource = detect()
    if not system then return false end

    if TSS.IsServer() then
        if type(first) ~= 'number' then return false end
        local value = system == 'qbox' and second or normalizePlate(second)
        local ok, result = TSS.CallExport(resource, 'HasKeys', first, value)
        return ok and result == true
    end

    local value = first
    if system == 'qb' then
        if type(value) == 'number' and DoesEntityExist(value) then value = GetVehicleNumberPlateText(value) end
        value = normalizePlate(value)
    end
    local ok, result = TSS.CallExport(resource, 'HasKeys', value)
    return ok and result == true
end
