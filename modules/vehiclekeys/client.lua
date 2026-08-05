TSSModuleLoader.Define({
    name = 'VehicleKeys',
    files = { 'modules/vehiclekeys/shared.lua' },
    client = function(context)
        return context.CopyFunctions(TSS.VehicleKeys, { 'System', 'Supports', 'Has' })
    end,
})
