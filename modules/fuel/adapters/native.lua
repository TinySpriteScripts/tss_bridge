TSS.Fuel.RegisterAdapter('native', nil, {
    supports = { get = true, set = true },
    get = function(_, vehicle)
        return GetVehicleFuelLevel(vehicle)
    end,
    set = function(_, vehicle, amount)
        SetVehicleFuelLevel(vehicle, amount)
        return true
    end,
}, { priority = 1000 })
