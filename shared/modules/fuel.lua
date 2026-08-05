TSS = TSS or {}
TSS.Fuel = TSS.Fuel or {}

local systems = {
    legacy = TSS.Resources.LegacyFuel,
    ox = TSS.Resources.OxFuel,
    ps = TSS.Resources.PsFuel,
    cdn = TSS.Resources.CdnFuel,
}

local aliases = {
    ['legacy'] = 'legacy', ['legacyfuel'] = 'legacy',
    ['ox'] = 'ox', ['ox_fuel'] = 'ox',
    ['ps'] = 'ps', ['ps-fuel'] = 'ps',
    ['cdn'] = 'cdn', ['cdn-fuel'] = 'cdn',
    ['native'] = 'native',
}

local function detect(preferred)
    local configured = tostring(preferred or TSS.Config.Fuel or 'auto'):lower()
    if configured ~= 'auto' then
        local system = aliases[configured] or configured
        if system == 'native' then return system end
        local resource = systems[system]
        if resource and TSS.IsStarted(resource) then return system, resource end
        TSS.Warn(('Configured fuel system is not started: %s'):format(tostring(resource or configured)))
        return 'native'
    end

    if TSS.IsStarted(TSS.Resources.OxFuel) then return 'ox', TSS.Resources.OxFuel end
    if TSS.IsStarted(TSS.Resources.PsFuel) then return 'ps', TSS.Resources.PsFuel end
    if TSS.IsStarted(TSS.Resources.CdnFuel) then return 'cdn', TSS.Resources.CdnFuel end
    if TSS.IsStarted(TSS.Resources.LegacyFuel) then return 'legacy', TSS.Resources.LegacyFuel end
    return 'native'
end

function TSS.Fuel.System(preferred)
    return detect(preferred)
end

function TSS.Fuel.Supports(feature)
    feature = tostring(feature or ''):lower()
    return feature == 'get' or feature == 'set'
end

function TSS.Fuel.Get(vehicle)
    if type(vehicle) ~= 'number' or vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end
    local system, resource = detect()
    if system ~= 'native' then
        local ok, value = TSS.CallExport(resource, 'GetFuel', vehicle)
        if not ok then ok, value = TSS.CallExport(resource, 'getFuel', vehicle) end
        if ok and tonumber(value) then return tonumber(value) end
    end
    return tonumber(GetVehicleFuelLevel(vehicle)) or 0
end

function TSS.Fuel.Set(vehicle, amount)
    if type(vehicle) ~= 'number' or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    amount = math.max(0.0, math.min(100.0, tonumber(amount) or 0.0))
    local system, resource = detect()
    if system ~= 'native' then
        local ok = TSS.CallExport(resource, 'SetFuel', vehicle, amount)
        if not ok then ok = TSS.CallExport(resource, 'setFuel', vehicle, amount) end
        if ok then return true end
    end
    SetVehicleFuelLevel(vehicle, amount)
    return true
end
