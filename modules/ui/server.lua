TSSModuleLoader.Define({
    name = 'UI',
    files = { 'modules/ui/shared.lua' },
    server = function(context)
        return context.CopyFunctions(TSS.UI, { 'Notify', 'Progress', 'HideProgress' })
    end,
})
