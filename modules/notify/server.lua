TSSModuleLoader.Define({
    name = 'Notify',
    files = { 'modules/notify/shared.lua' },
    server = function(context)
        return context.CopyFunctions(TSS.Notify, { 'System', 'Supports', 'Send' })
    end,
})
