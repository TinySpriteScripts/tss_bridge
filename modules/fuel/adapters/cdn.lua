TSS.Fuel.RegisterAdapter('cdn', TSS.Resources.CdnFuel, {
    supports = { get = true, set = true },
    get = function(resource, vehicle)
        local ok, value = TSS.CallExport(resource, 'GetFuel', vehicle)
        if not ok then ok, value = TSS.CallExport(resource, 'getFuel', vehicle) end
        return ok and value or GetVehicleFuelLevel(vehicle)
    end,
    set = function(resource, vehicle, amount)
        local ok = TSS.CallExport(resource, 'SetFuel', vehicle, amount)
        if not ok then ok = TSS.CallExport(resource, 'setFuel', vehicle, amount) end
        if ok then return true end
        SetVehicleFuelLevel(vehicle, amount)
        return true
    end,
}, { priority = 30, aliases = { 'cdn-fuel' } })
