TSSBridgeLabAuthorization = TSSBridgeLabAuthorization or {}

local function addIdentifiers(destination, values, prefix)
    if type(values) ~= 'table' then return 0 end
    local count = 0

    for i = 1, #values do
        local value = tostring(values[i] or ''):lower():match('^%s*(.-)%s*$')
        if value ~= '' then
            local identifier = value:sub(1, #prefix + 1) == prefix .. ':' and value or (prefix .. ':' .. value)
            if not destination[identifier] then
                destination[identifier] = true
                count = count + 1
            end
        end
    end
    return count
end

--- Builds an exact server-side Discord/FiveM identifier allowlist.
---@param config table
---@return table<string, boolean> identifiers
---@return integer count
function TSSBridgeLabAuthorization.Build(config)
    config = type(config) == 'table' and config or {}
    local identifiers = {}
    local count = addIdentifiers(identifiers, config.AllowedDiscordIds, 'discord')
        + addIdentifiers(identifiers, config.AllowedFiveMIds, 'fivem')
    return identifiers, count
end

--- Checks a player's server-provided identifiers against the exact allowlist.
---@param source integer
---@param allowed table<string, boolean>
---@param identifierProvider? fun(source: integer): string[] Test override.
---@return boolean authorized
function TSSBridgeLabAuthorization.IsAllowed(source, allowed, identifierProvider)
    if type(source) ~= 'number' or source <= 0 or type(allowed) ~= 'table' then return false end
    identifierProvider = identifierProvider or GetPlayerIdentifiers
    local identifiers = identifierProvider(source)
    if type(identifiers) ~= 'table' then return false end

    for i = 1, #identifiers do
        if allowed[tostring(identifiers[i]):lower()] then return true end
    end
    return false
end
