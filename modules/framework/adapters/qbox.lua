local playerData

local function clientPlayerData(resource)
    if playerData and playerData.citizenid then return playerData end
    local succeeded, current = TSS.CallExport(resource, 'GetPlayerData')
    playerData = succeeded and type(current) == 'table' and current.citizenid and current or nil
    return playerData
end

TSS.Framework.RegisterAdapter('qbox', TSS.Resources.Qbox, {
    supports = { player = true, jobs = true, gangs = true, money = true },
    player = function(resource, source)
        if TSS.IsClient() then return clientPlayerData(resource) end
        if type(source) ~= 'number' then return nil end
        local ok, player = TSS.CallExport(resource, 'GetPlayer', source)
        return ok and player or nil
    end,
    playerData = function(resource, source)
        if TSS.IsClient() then return clientPlayerData(resource) end
        if type(source) ~= 'number' then return nil end
        local ok, player = TSS.CallExport(resource, 'GetPlayer', source)
        return ok and player and (player.PlayerData or player) or nil
    end,
    jobs = function(resource)
        local ok, jobs = TSS.CallExport(resource, 'GetJobs')
        return ok and jobs or {}
    end,
    gangs = function(resource)
        local ok, gangs = TSS.CallExport(resource, 'GetGangs')
        return ok and gangs or {}
    end,
    getUsableItem = function(resource, itemName)
        local succeeded, callback = TSS.CallExport(resource, 'CanUseItem', itemName)
        return succeeded and callback or nil
    end,
}, { priority = 10, aliases = { 'qbx', 'qbx_core' } })

if TSS.IsClient() then
    RegisterNetEvent('QBCore:Player:SetPlayerData', function(data) playerData = data end)
    RegisterNetEvent('qbx_core:client:playerLoggedOut', function() playerData = nil end)
    RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() playerData = nil end)
end

AddEventHandler(TSS.IsServer() and 'onResourceStop' or 'onClientResourceStop', function(resource)
    if resource == TSS.Resources.Qbox then playerData = nil end
end)
