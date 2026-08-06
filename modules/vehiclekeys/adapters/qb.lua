local function call(resource, exportName, source, value)
    value = TSS.VehicleKeys.Utils.NormalizePlate(value)
    if not value then return false end
    local ok, result
    if TSS.IsServer() then ok, result = TSS.CallExport(resource, exportName, source, value)
    else ok, result = TSS.CallExport(resource, exportName, value) end
    return ok and result ~= false
end

TSS.VehicleKeys.RegisterAdapter('qb', TSS.Resources.QbVehicleKeys, {
    supports = { has = true, give = true, remove = true },
    has = function(resource, source, value)
        if TSS.IsClient() then value = source; source = nil end
        local result = call(resource, 'HasKeys', source, value)
        return result == true
    end,
    give = function(resource, source, value) return call(resource, 'GiveKeys', source, value) end,
    remove = function(resource, source, value) return call(resource, 'RemoveKeys', source, value) end,
}, { priority = 20, aliases = { 'qb-vehiclekeys' } })
