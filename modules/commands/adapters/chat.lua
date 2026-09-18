-- Standard chat suggestions also cover client commands inside tss-chat.
local serverSuggestions, published = {}, {}
function TSS.Commands.RemoveSuggestions()
    for name in pairs(published) do TriggerEvent('chat:removeSuggestion', '/' .. name) end
    published = {}
end
function TSS.Commands.RefreshSuggestions()
    TSS.Commands.RemoveSuggestions()
    local list = TSS.Commands.List(0)
    -- tss-chat receives server commands through its richer provider API.
    if GetResourceState('tss-chat') ~= 'started' then
        for _, data in ipairs(serverSuggestions) do list[#list + 1] = data end
    end
    for _, data in ipairs(list) do
        TriggerEvent('chat:addSuggestion', '/' .. data.name, data.description, data.arguments)
        published[data.name] = true
    end
end
function TSS.Commands.SetServerSuggestions(list)
    serverSuggestions = list
    TSS.Commands.RefreshSuggestions()
end
