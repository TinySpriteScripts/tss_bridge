TSSModuleLoader.Define({
    name = 'Groups',
    dependencies = { 'Framework' },
    files = { 'modules/groups/shared.lua' },
    server = function(context)
        return context.CopyFunctions(TSS.Groups, { 'BossRoles' })
    end,
})
