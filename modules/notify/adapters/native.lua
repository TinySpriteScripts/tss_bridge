TSS.Notify.RegisterAdapter('native', nil, {
    supports = { title = true },
    send = function(_, data)
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(data.message)
        EndTextCommandThefeedPostTicker(false, false)
        return true
    end,
}, { priority = 1000 })
