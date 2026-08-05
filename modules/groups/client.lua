TSSModuleLoader.Define({
    name = 'Groups',
    dependencies = { 'Framework' },
    files = { 'modules/groups/shared.lua' },
    client = function(context)
        return context.CopyFunctions(TSS.Groups, { 'BossRoles' })
    end,
})
