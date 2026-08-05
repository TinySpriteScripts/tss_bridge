TSSModuleLoader.Define({
    name = 'TextUI',
    files = { 'modules/textui/shared.lua' },
    server = function(context)
        local shown = {}
        ---@type TSSTextUIServerModule
        local public = context.CopyFunctions(TSS.TextUI, { 'System', 'Supports' })

        function public.Show(source, data)
            if type(source) ~= 'number' then return false end
            shown[source] = true
            return TSS.TextUI.Show(source, data, context.Caller)
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
