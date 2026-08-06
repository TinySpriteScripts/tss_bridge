TSSModuleLoader.Define({
    name = 'VehicleKeys',
    files = {
        'modules/vehiclekeys/shared.lua',
        'modules/vehiclekeys/adapters/qbox.lua',
        'modules/vehiclekeys/adapters/qb.lua',
        'modules/vehiclekeys/adapters/none.lua',
    },
    server = function(context)
        return context.CopyFunctions(TSS.VehicleKeys, { 'System', 'Supports', 'Has', 'Give', 'Remove' })
    end,
})
