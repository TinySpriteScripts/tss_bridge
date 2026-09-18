TSSModuleLoader.Define({
    name = 'Interaction',
    dependencies = { 'Targets', 'TextUI', 'Player', 'Inventory' },
    files = {
        'modules/interaction/shared.lua',
        'modules/interaction/adapters/target.lua',
        'modules/interaction/adapters/textui.lua',
    },
    client = function(context)
        ---@type TSSInteractionModule
        local targets = TSS.Target.CreateAPI(context.Preference('Target'))
        local public = {}
        function public.System(preferred)
            return TSS.Interaction.System(context.Preference('Interaction', preferred), targets)
        end
        function public.Supports(feature, preferred)
            return TSS.Interaction.Supports(feature, context.Preference('Interaction', preferred), targets)
        end

        function public.Create(data)
            if type(data) ~= 'table' then return nil end
            local scoped = context.ProviderData('Interaction', data)
            scoped.textUI = scoped.textUI or context.Preference('TextUI')
            return TSS.Interaction.Create(scoped, context.Caller, targets)
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
