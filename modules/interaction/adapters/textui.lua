TSS.Interaction.RegisterAdapter('textui', nil, {
    supports = { coords = true, entity = true, key = true },
    create = function(_, entry)
        return entry.coords ~= nil or entry.entity ~= nil
    end,
    remove = function() return true end,
}, { priority = 1000, aliases = { 'proximity' } })
