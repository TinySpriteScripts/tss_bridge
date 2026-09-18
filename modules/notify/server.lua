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
        local public = context.ProviderAPI(TSS.Notify, 'Notify')
        function public.Send(first, second, third, fourth, fifth)
            return TSS.Notify.Send(first, second, third, fourth, fifth, context.Preference('Notify'))
        end
        return public
    end,
})
