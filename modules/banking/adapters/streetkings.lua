local function mutate(method, resource, source, account, amount)
    if not TSS.IsServer() or account ~= 'cash' then return false end
    local ok, result = TSS.CallExport(resource, method, source, amount)
    return ok and result == true
end
TSS.Banking.RegisterPlayerAdapter('streetkings', TSS.Resources.StreetKings, {
    getAccount = function(resource, source, account)
        if not TSS.IsServer() or account ~= 'cash' then return 0 end
        local ok, value = TSS.CallExport(resource, 'GetPlayerCash', source)
        return ok and value or 0
    end,
    addMoney = function(resource, source, account, amount)
        return mutate('AddPlayerCash', resource, source, account, amount)
    end,
    removeMoney = function(resource, source, account, amount)
        return mutate('RemovePlayerCash', resource, source, account, amount)
    end,
}, { priority = 40 })
