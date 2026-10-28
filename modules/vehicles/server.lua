TSSModuleLoader.Define({
    name = 'Vehicles',
    files = { 'modules/vehicles/access/shared.lua' },
    server = function(context)
        return context.CopyFunctions(TSSVehicleAccess, { 'FromNetworkId', 'Current', 'Inspect' })
    end,
})
