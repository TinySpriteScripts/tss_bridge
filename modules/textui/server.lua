TSSModuleLoader.Define({
    name = 'TextUI',
    files = {
        'modules/textui/shared.lua',
        'modules/textui/adapters/ox.lua',
        'modules/textui/adapters/qb.lua',
        'modules/textui/adapters/native.lua',
    },
    server = function(context)
        local shown = {}
        ---@type TSSTextUIServerModule
        local public = context.ProviderAPI(TSS.TextUI, 'TextUI')

        function public.Show(source, data)
            if type(source) ~= 'number' then return false end
            shown[source] = true
            return TSS.TextUI.Show(source, context.ProviderData('TextUI', data), context.Caller)
        end

        function public.Hide(source)
            shown[source] = nil
            return TSS.TextUI.Hide(source, context.Caller)
        end

        context.OnStop(function()
            for source in pairs(shown) do TSS.TextUI.Hide(source, context.Caller) end
        end)
        return public
    end,
})
