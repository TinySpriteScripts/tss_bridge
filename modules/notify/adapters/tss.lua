local function ensureUI()
    if TSS.UI and TSS.UI.Notify then return true end
    if TSSModuleLoader and TSSModuleLoader.Ensure then TSSModuleLoader.Ensure('UI') end
    return TSS.UI and TSS.UI.Notify ~= nil or false
end

TSS.Notify.RegisterAdapter('tss', nil, {
    supports = { title = true, type = true, duration = true, position = true, icon = true, id = true },
    send = function(_, data)
        return ensureUI() and TSS.UI.Notify(data) == true or false
    end,
}, { priority = 900, aliases = { 'tss_bridge' }, available = ensureUI })
