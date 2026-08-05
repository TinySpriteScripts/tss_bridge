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

function TSS.VehicleKeys.System(preferred)
    return detect(preferred)
end

function TSS.VehicleKeys.Supports(feature)
    local system = detect()
    feature = tostring(feature or ''):lower()
    if not TSS.IsServer() and feature ~= 'has' then return false end
    if system == 'qbox' then return feature == 'has' or feature == 'give' or feature == 'remove' end
    if system == 'qb' then return feature == 'has' or feature == 'give' or feature == 'remove' end
    return false
end

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

function TSS.VehicleKeys.Give(source, vehicleOrPlate)
    if not TSS.IsServer() or type(source) ~= 'number' then return false end
    local system, resource = detect()
    if not system then return false end
    local value = system == 'qbox' and vehicleOrPlate or normalizePlate(vehicleOrPlate)
    if value == nil then return false end
    local ok, result = TSS.CallExport(resource, 'GiveKeys', source, value)
    return ok and result ~= false
end

function TSS.VehicleKeys.Remove(source, vehicleOrPlate)
    if not TSS.IsServer() or type(source) ~= 'number' then return false end
    local system, resource = detect()
    if not system then return false end
    local value = system == 'qbox' and vehicleOrPlate or normalizePlate(vehicleOrPlate)
    if value == nil then return false end
    local ok, result = TSS.CallExport(resource, 'RemoveKeys', source, value)
    return ok and result ~= false
end
