local current
local running = false

TSS.TextUI.RegisterAdapter('native', nil, {
    supports = {},
    show = function(_, data)
        current = data
        if running then return true end
        running = true
        CreateThread(function()
            while current do
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(current.text)
                EndTextCommandDisplayHelp(0, false, true, -1)
                Wait(0)
            end
            running = false
        end)
        return true
    end,
    hide = function()
        current = nil
        return true
    end,
}, { priority = 1000 })
