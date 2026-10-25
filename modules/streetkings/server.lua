-- Native StreetKings API, kept separate from normalized RP modules.
TSSModuleLoader.Define({
    name = 'StreetKings',
    server = function(context)
        local public = {}
        function public.IsAvailable()
            return GetResourceState(TSS.Resources.StreetKings) == 'started'
        end
        local methods = { 'AddPlayerCash', 'AwardPlayerXp', 'AwardVehicleXp', 'BroadcastPhoneMessage', 'CreateServerWaypoint', 'GetActiveVehicle', 'GetOwnedVehicles', 'GetPlayerCash', 'GetPlayerGameState', 'GetPlayerLevel', 'GetServerWaypoints', 'HasActiveSave', 'IncrementStat', 'IsPlayerInHangoutZone', 'PersistSave', 'ReadSaveData', 'RecordActivityBest', 'RegisterStat', 'RemovePlayerCash', 'RemoveServerWaypoint', 'SendPhoneMessage', 'SetStatMax', 'SetTime', 'SetWeather', 'WriteSaveData' }
        for i = 1, #methods do
            local method = methods[i]
            public[method] = function(...)
                local result = table.pack(TSS.CallExport(TSS.Resources.StreetKings, method, ...))
                if not result[1] then
                    error(('[tss_bridge] StreetKings.%s failed: %s'):format(method, tostring(result[2])), 2)
                end
                return table.unpack(result, 2, result.n)
            end
        end
        
        return public
    end,
})
