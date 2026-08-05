TSSModuleLoader.Define({
    name = 'VehicleKeys',
    files = { 'modules/vehiclekeys/shared.lua' },
    server = function(context)
        ---@type TSSVehicleKeysServerModule
        local VehicleKeys = context.CopyFunctions(TSS.VehicleKeys, { 'System', 'Supports', 'Has' })

        local function mutate(exportName, source, vehicleOrPlate)
            if type(source) ~= 'number' then return false end
            local system, resource = TSS.VehicleKeys._Detect()
            if not system then return false end
            local value = system == 'qbox' and vehicleOrPlate or TSS.VehicleKeys._NormalizePlate(vehicleOrPlate)
            if value == nil then return false end
            local ok, result = TSS.CallExport(resource, exportName, source, value)
            return ok and result ~= false
        end

        --- Gives vehicle keys to a player.
        ---@param source integer Server player ID.
        ---@param vehicleOrPlate TSSEntity|string Vehicle handle or plate.
        ---@return boolean success
        function VehicleKeys.Give(source, vehicleOrPlate)
            return mutate('GiveKeys', source, vehicleOrPlate)
        end

        --- Removes vehicle keys from a player.
        ---@param source integer Server player ID.
        ---@param vehicleOrPlate TSSEntity|string Vehicle handle or plate.
        ---@return boolean success
        function VehicleKeys.Remove(source, vehicleOrPlate)
            return mutate('RemoveKeys', source, vehicleOrPlate)
        end

        return VehicleKeys
    end,
})
