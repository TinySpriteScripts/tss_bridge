TSSModuleLoader.Define({
    name = 'Vehicles',
    files = { 'modules/vehicles/shared.lua', 'modules/vehicles/access/shared.lua' },
    client = function(context)
        local owned = {}
        ---@type TSSVehiclesModule
        local public = context.CopyFunctions(TSSVehicleAccess, { 'FromNetworkId', 'Current', 'Inspect', 'Nearby', 'TrunkPosition' })

        function public.Create(data, coords, options)
            local vehicle = TSS.CreateVehicle(data, coords, options)
            if vehicle then owned[vehicle] = true end
            return vehicle
        end

        function public.Delete(vehicle)
            owned[vehicle] = nil
            return TSS.DeleteVehicle(vehicle)
        end

        function public.Clear()
            for vehicle in pairs(owned) do
                TSS.DeleteVehicle(vehicle)
                owned[vehicle] = nil
            end
        end

        context.OnStop(public.Clear)
        return public
    end,
})
