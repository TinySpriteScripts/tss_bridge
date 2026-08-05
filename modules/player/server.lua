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

        return Player
    end,
})
