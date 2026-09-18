TSSModuleLoader.Define({
    name = 'Groups',
    dependencies = { 'Framework' },
    files = {
        'modules/groups/shared.lua',
        'modules/groups/adapters/tss.lua',
        'modules/groups/adapters/qbox.lua',
        'modules/groups/adapters/qb.lua',
        'modules/groups/adapters/esx.lua',
    },
    client = function(context)
        return context.CopyFunctions(TSS.Groups, {
            'System', 'Supports', 'BossRoles', 'ManagementSystem',
            'IsJobBoss', 'IsGangBoss', 'OpenBossMenu', 'OpenGangMenu',
        })
    end,
})
