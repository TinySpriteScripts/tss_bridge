-- Lazy realm-aware implementation owned by the Player module.
TSS = TSS or {}
TSS.Player = TSS.Player or {}

local function data(source)
    return TSS.Framework.PlayerData(source)
end

local function object(source)
    return TSS.Framework.Player(source)
end

local function gradeLevel(group)
    if type(group) ~= 'table' then return 0 end
    local grade = group.grade
    if type(grade) == 'table' then return tonumber(grade.level or grade.grade) or 0 end
    return tonumber(grade) or 0
end


local function matchesGroup(playerData, filter)
    if not playerData or filter == nil then return false end
    local job = playerData.job or {}
    local gang = playerData.gang or {}

    local function matches(name, minimum)
        if job.name == name then return gradeLevel(job) >= (minimum or 0) end
        if gang.name == name then return gradeLevel(gang) >= (minimum or 0) end
        if playerData.jobs and playerData.jobs[name] ~= nil then return tonumber(playerData.jobs[name]) >= (minimum or 0) end
        if playerData.gangs and playerData.gangs[name] ~= nil then return tonumber(playerData.gangs[name]) >= (minimum or 0) end
        return playerData.citizenid == name or playerData.identifier == name
    end

    if type(filter) == 'string' then return matches(filter, 0) end
    if type(filter) ~= 'table' then return false end

    for key, value in pairs(filter) do
        if type(key) == 'number' then
            if matches(value, 0) then return true end
        elseif matches(key, tonumber(value) or 0) then
            return true
        end
    end
    return false
end

--- Returns the current player's normalized framework data.
---@param source? integer Server player ID; omit on the client.
---@return table? playerData
function TSS.Player.Data(source)
    return data(source)
end

--- Returns a player identifier such as a citizen ID or license.
---@param source? integer|string Server player ID, or the identifier kind when called on the client.
---@param kind? string Identifier field requested on the server.
---@return string? identifier
---@usage
--- ```lua
--- local citizenId = TSS.Player.Identifier(source, 'citizenid') -- server
--- local citizenId = TSS.Player.Identifier('citizenid')         -- client
--- ```
function TSS.Player.Identifier(source, kind)
    if not TSS.IsServer() then
        kind = source
        source = nil
    end
    local playerData = data(source)
    if not playerData then return nil end
    kind = kind or 'citizenid'

    if playerData[kind] ~= nil then return playerData[kind] end
    if kind == 'citizenid' then return playerData.citizenid or playerData.identifier end
    if kind == 'license' then return playerData.license or playerData.identifier end

    local player = object(source)
    if player and player.getIdentifier then return player.getIdentifier() end
    return nil
end

--- Returns the player's character name when available.
---@param source? integer Server player ID; omit on the client.
---@return string? name
function TSS.Player.Name(source)
    local playerData = data(source)
    if not playerData then return nil end
    local charinfo = playerData.charinfo or {}
    local fullName = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):match('^%s*(.-)%s*$')
    return fullName ~= '' and fullName or playerData.name
end

--- Returns the player's framework job data.
---@param source? integer Server player ID; omit on the client.
---@return table? job
function TSS.Player.Job(source)
    local playerData = data(source)
    return playerData and playerData.job or nil
end

--- Returns the player's framework gang data when supported.
---@param source? integer Server player ID; omit on the client.
---@return table? gang
function TSS.Player.Gang(source)
    local playerData = data(source)
    return playerData and playerData.gang or nil
end

--- Returns all player metadata or one metadata value.
---@param source? integer|string Server player ID, or the metadata key when called on the client.
---@param key? string Metadata key requested on the server.
---@return any value
function TSS.Player.Metadata(source, key)
    if not TSS.IsServer() then
        key = source
        source = nil
    end
    local playerData = data(source)
    if not playerData then return nil end
    local metadata = playerData.metadata or playerData.meta or {}
    if key == nil then return metadata end
    if metadata[key] ~= nil then return metadata[key] end

    local player = object(source)
    if player and player.getMeta then
        local ok, value = pcall(player.getMeta, key)
        if ok then return value end
    end
    return nil
end

--- Checks the player's job, gang, or identifier against a group filter.
---@param source? integer|string|table Server player ID, or the filter when called on the client.
---@param filter? string|string[]|table<string, integer> Group names or minimum grades.
---@return boolean matches
function TSS.Player.HasGroup(source, filter)
    if not TSS.IsServer() then
        filter = source
        source = nil
    end

    local system, resource = TSS.Framework.System()
    if system == 'qbox' then
        local ok, result
        if TSS.IsServer() then
            ok, result = TSS.CallExport(resource, 'HasGroup', source, filter)
        else
            ok, result = TSS.CallExport(resource, 'HasGroup', filter)
        end
        if ok then return result == true end
    end

    return matchesGroup(data(source), filter)
end

--- Reports whether player data is available.
---@param source? integer Server player ID; omit on the client.
---@return boolean loaded
function TSS.Player.IsLoaded(source)
    return data(source) ~= nil
end
