TSSModuleLoader.Define({
    name = 'Player',
    dependencies = { 'Framework' },
    files = { 'modules/player/shared.lua' },
    client = function(context)
        return context.CopyFunctions(TSS.Player, {
            'Data', 'Identifier', 'Name', 'Job', 'Gang', 'Metadata', 'HasGroup', 'IsLoaded',
        })
    end,
})
