TSSModuleLoader.Define({
    name = 'UI',
    files = { 'modules/ui/shared.lua' },
    client = function(context)
        return context.CopyFunctions(TSS.UI, {
            'Notify', 'Progress', 'HideProgress', 'Menu', 'Context', 'Input', 'Close',
        })
    end,
})

RegisterNetEvent('tss_bridge:client:uiNotify', function(data)
    if TSSModuleLoader.Ensure('UI') then TSS.UI.Notify(data) end
end)

RegisterNetEvent('tss_bridge:client:uiProgress', function(data)
    if not TSSModuleLoader.Ensure('UI') then return end
    if data == nil then TSS.UI.HideProgress() else TSS.UI.Progress(data) end
end)
