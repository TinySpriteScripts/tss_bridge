TSSModuleLoader.Define({
    name = 'ProgressBar',
    dependencies = { 'UI' },
    files = {
        'modules/progressbar/shared.lua',
        'modules/progressbar/adapters/ox.lua',
        'modules/progressbar/adapters/qb.lua',
        'modules/progressbar/adapters/tss.lua',
        'modules/progressbar/adapters/native.lua',
    },
    client = function(context)
        return context.CopyFunctions(TSS.Progress, { 'System', 'Supports', 'Start', 'Stop' })
    end,
})
