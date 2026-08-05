TSSModuleLoader.Define({
    name = 'Money',
    dependencies = { 'Framework' },
    files = { 'modules/money/shared.lua' },
    client = function(context)
        return context.CopyFunctions(TSS.Money, { 'Balance', 'Has' })
    end,
})
