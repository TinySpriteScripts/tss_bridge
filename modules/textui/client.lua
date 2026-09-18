TSSModuleLoader.Define({
    name = 'TextUI',
    files = {
        'modules/textui/shared.lua',
        'modules/textui/adapters/ox.lua',
        'modules/textui/adapters/qb.lua',
        'modules/textui/adapters/native.lua',
    },
    client = function(context)
        ---@type TSSTextUIClientModule
        local public = context.ProviderAPI(TSS.TextUI, 'TextUI')

        function public.Show(data)
            return TSS.TextUI.Show(context.ProviderData('TextUI', data), context.Caller)
        end

        function public.Hide()
            return TSS.TextUI.Hide(context.Caller)
        end

        function public.IsOpen()
            local isOpen, data, owner = TSS.TextUI.IsOpen()
            if owner ~= context.Caller then return false, nil end
            return isOpen, data
        end

        context.OnStop(public.Hide)
        return public
    end,
})

RegisterNetEvent('tss_bridge:client:textui:show', function(data, owner)
    if TSSModuleLoader.Ensure('TextUI') then TSS.TextUI.ReceiveShow(data, owner) end
end)

RegisterNetEvent('tss_bridge:client:textui:hide', function(owner)
    if TSSModuleLoader.Ensure('TextUI') then TSS.TextUI.ReceiveHide(owner) end
end)
