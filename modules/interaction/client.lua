TSSModuleLoader.Define({
    name = 'Interaction',
    dependencies = { 'Targets', 'TextUI', 'Player', 'Inventory' },
    files = { 'modules/interaction/shared.lua' },
    client = function(context)
        ---@type TSSInteractionModule
        local public = context.CopyFunctions(TSS.Interaction, { 'System', 'Supports' })

        function public.Create(data)
            return TSS.Interaction.Create(data, context.Caller)
        end

        function public.Remove(id)
            return TSS.Interaction.Remove(id)
        end

        function public.Clear()
            return TSS.Interaction.Clear(context.Caller)
        end

        context.OnStop(public.Clear)
        return public
    end,
})
