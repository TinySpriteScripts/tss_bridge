TSSModuleLoader.Define({
    name = 'Notify',
    files = {
        'modules/notify/shared.lua',
        'modules/notify/adapters/ox.lua',
        'modules/notify/adapters/qbox.lua',
        'modules/notify/adapters/qb.lua',
        'modules/notify/adapters/okok.lua',
        'modules/notify/adapters/wasabi.lua',
        'modules/notify/adapters/mythic.lua',
        'modules/notify/adapters/tss.lua',
        'modules/notify/adapters/native.lua',
    },
    server = function(context)
        return context.CopyFunctions(TSS.Notify, { 'System', 'Supports', 'Send' })
    end,
})
