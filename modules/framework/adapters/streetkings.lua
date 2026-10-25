-- StreetKings has save documents rather than RP player objects.
local function playerData(resource, source)
    -- No client save/identity export exists; do not fabricate loaded player data.
    if not TSS.IsServer() or type(source) ~= 'number' or source <= 0 then return nil end
    local ok, active = TSS.CallExport(resource, 'HasActiveSave', source)
    if not ok or active ~= true then return nil end
    local function read(path)
        local success, value = TSS.CallExport(resource, 'ReadSaveData', source, path)
        return success and value or nil
    end
    local license = GetPlayerIdentifierByType(source, 'license')
    local profile = read('profile') or {}
    local _, state = TSS.CallExport(resource, 'GetPlayerGameState', source)
    return {
        source = source, identifier = license, license = license,
        name = profile.alias or GetPlayerName(source),
        money = { cash = tonumber(read('economy.cash')) or 0 },
        metadata = { progression = read('progression'), stats = read('stats'), gameState = state },
    }
end

TSS.Framework.RegisterAdapter('streetkings', TSS.Resources.StreetKings, {
    supports = { player = TSS.IsServer(), money = TSS.IsServer(), jobs = false, gangs = false, object = false },
    player = playerData,
    playerData = playerData,
}, { priority = 40, aliases = { 'streetking', 'sk' } })
