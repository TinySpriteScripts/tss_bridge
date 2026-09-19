TSSModuleLoader.Define({
    name = 'Player',
    dependencies = { 'Framework' },
    files = { 'modules/player/shared.lua' },
    server = function(context)
        ---@type TSSPlayerServerModule
        local Player = context.CopyFunctions(TSS.Player, {
            'Data', 'Identifier', 'Name', 'Job', 'Gang', 'Metadata', 'HasGroup', 'IsLoaded',
        })

        --- Checks a player's ACE permission.
        ---@param source integer Server player ID.
        ---@param permission string ACE name, also checked with a `tss_bridge.` prefix.
        ---@return boolean allowed
        function Player.HasPermission(source, permission)
            if type(source) ~= 'number' or type(permission) ~= 'string' then return false end
            return IsPlayerAceAllowed(source, permission)
                or IsPlayerAceAllowed(source, ('tss_bridge.%s'):format(permission))
        end

        --- Set duty through the selected framework. ESX stores duty in job metadata.
        function Player.SetDuty(source, duty)
            if type(source) ~= 'number' or source <= 0 or type(duty) ~= 'boolean' then return false end
            local player = TSS.Framework.Player(source)
            if not player then return false end
            if player.Functions and player.Functions.SetJobDuty then
                player.Functions.SetJobDuty(duty)
                return true
            end
            if player.setMeta then
                player.setMeta('tss_duty', duty)
                return true
            end
            return false
        end

        --- Apply server-authorized needs deltas, clamped to 0..100.
        function Player.AddNeeds(source, needs)
            local player = TSS.Framework.Player(source)
            if not player or type(needs) ~= 'table' then return false end
            if player.Functions and player.Functions.SetMetaData then
                local metadata = TSS.Player.Metadata(source) or {}
                for _, key in ipairs({ 'hunger', 'thirst', 'stress' }) do
                    local delta = tonumber(needs[key])
                    if delta and delta == delta then
                        player.Functions.SetMetaData(key, math.max(0, math.min(100, (tonumber(metadata[key]) or 0) + delta)))
                    end
                end
                local updated = TSS.Player.Metadata(source) or {}
                TriggerClientEvent('hud:client:UpdateNeeds', source, updated.hunger, updated.thirst)
                TriggerClientEvent('hud:client:UpdateStress', source, updated.stress)
                return true
            end
            if TSS.Framework.System() == 'esx' then
                for _, key in ipairs({ 'hunger', 'thirst' }) do
                    local delta = tonumber(needs[key])
                    if delta and delta == delta then
                        TriggerClientEvent('esx_status:' .. (delta >= 0 and 'add' or 'remove'), source, key, math.abs(delta) * 10000)
                    end
                end
                return true
            end
            return false
        end

        return Player
    end,
})
