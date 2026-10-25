-- Native StreetKings API, kept separate from normalized RP modules.
TSSModuleLoader.Define({
    name = 'StreetKings',
    client = function(context)
        local public = {}
        function public.IsAvailable()
            return GetResourceState(TSS.Resources.StreetKings) == 'started'
        end
        local methods = { 'AllowLeaveVehicle', 'ClosePhone', 'CreateWaypoint', 'DisableChaseCam', 'EnableChaseCam', 'GetAllVehicleData', 'GetCurrentTime', 'GetCurrentTrack', 'GetCurrentWeather', 'GetGameState', 'GetPlayerVehicle', 'GetVehicleAvailability', 'GetVehicleData', 'GetWantedLevel', 'IsChaseCamEnabled', 'IsCinematicMode', 'IsInFreeroam', 'IsNearPolice', 'IsPhoneOpen', 'IsPlayerWasted', 'IsPoliceChasing', 'IsRaceEditorFreecamEnabled', 'LoadAnimDict', 'LoadAnimSet', 'LoadModel', 'LoadPtfxAsset', 'OpenPhone', 'RaceEditorFreecamRaycast', 'RegisterGameState', 'RemoveAllWaypoints', 'RemoveWaypoint', 'SetCinematicMode', 'SetGameState', 'SetSoundtrackEnabled', 'SetSpeedometerEnabled', 'SetupTestJump', 'ShowNotification', 'StartRaceEditorFreecam', 'StopRaceEditorFreecam', 'TeardownTestJump', 'UnloadModel', 'WarpPlayer', 'WarpToWaypoint', 'awaitDebugToolsPermission' }
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
        function public.CheckpointCleared()
            if not public.IsAvailable() then return false end
            TriggerEvent('streetkings:nitrous:checkpointCleared')
            return true
        end
        return public
    end,
})
