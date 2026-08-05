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

function TSS.Player.Data(source)
    return data(source)
end

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

function TSS.Player.Name(source)
    local playerData = data(source)
    if not playerData then return nil end
    local charinfo = playerData.charinfo or {}
    local fullName = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):match('^%s*(.-)%s*$')
    return fullName ~= '' and fullName or playerData.name
end

function TSS.Player.Job(source)
    local playerData = data(source)
    return playerData and playerData.job or nil
end

function TSS.Player.Gang(source)
    local playerData = data(source)
    return playerData and playerData.gang or nil
end

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

function TSS.Player.IsLoaded(source)
    return data(source) ~= nil
end

function TSS.Player.HasPermission(source, permission)
    if not TSS.IsServer() or type(source) ~= 'number' or type(permission) ~= 'string' then return false end
    return IsPlayerAceAllowed(source, permission) or IsPlayerAceAllowed(source, ('tss_bridge.%s'):format(permission))
end
