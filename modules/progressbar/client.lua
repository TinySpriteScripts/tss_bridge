TSSModuleLoader.Define({
    name = 'ProgressBar',
    dependencies = { 'UI' },
    files = { 'modules/progressbar/shared.lua' },
    client = function(context)
        return context.CopyFunctions(TSS.Progress, { 'System', 'Supports', 'Start', 'Stop' })
    end,
})
