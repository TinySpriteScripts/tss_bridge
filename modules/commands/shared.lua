-- Native command execution with caller-owned handlers and optional chat integrations.
TSS.Commands = TSS.Commands or {}
local entries, installed = {}, {}
local server = TSS.IsServer()

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end

local function isArray(value)
    if type(value) ~= 'table' then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then return false end
        count = count + 1
    end
    return count == #value
end

local function nameOf(value)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('^/', ''):lower()
    if #value < 1 or #value > 64 or not value:match('^[%w_%-]+$') then return nil end
    return value
end

local function allowed(entry, source)
    local data = entry.data
    if data.debugOnly and not TSS.Config.Debug then return false end
    if server and source == 0 then return data.allowConsole end
    local permission = data.permission
    if permission == false then return true end
    if not server then return false end
    if IsPlayerAceAllowed(tostring(source), 'command.' .. data.name) then return true end
    if type(permission) == 'string' then return IsPlayerAceAllowed(tostring(source), permission) end
    for _, ace in ipairs(permission) do
        if IsPlayerAceAllowed(tostring(source), ace) then return true end
    end
    return false
end

local function reply(source, message)
    if server and source == 0 then print('[tss_bridge] ' .. message)
    elseif server then TriggerClientEvent('chat:addMessage', source, { args = { 'Commands', message }, channel = 'system' })
    else TriggerEvent('chat:addMessage', { args = { 'Commands', message }, channel = 'system' }) end
end

local function parse(data, args)
    local parsed = {}
    for i, argument in ipairs(data.arguments) do
        local value = argument.type == 'rest' and table.concat(args, ' ', i) or args[i]
        if value == '' then value = nil end
        if value == nil then
            if not argument.optional then return nil, 'Missing argument: ' .. argument.name end
        elseif argument.type == 'number' or argument.type == 'integer' then
            value = tonumber(value)
            if not value or value ~= value or value == math.huge or value == -math.huge
                or (argument.type == 'integer' and value % 1 ~= 0) then
                return nil, 'Expected ' .. argument.type .. ' for ' .. argument.name
            end
        elseif argument.type == 'boolean' then
            if value:lower() == 'true' then value = true
            elseif value:lower() == 'false' then value = false
            else return nil, 'Expected true or false for ' .. argument.name end
        end
        parsed[argument.name] = value
    end
    return parsed
end

function TSS.Commands.List(source, owner)
    local list = {}
    for _, entry in pairs(entries) do
        if (not owner or owner == entry.owner) and not entry.data.hidden and allowed(entry, source or 0) then
            list[#list + 1] = copy(entry.data)
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function TSS.Commands.Register(owner, name, options, handler)
    name = nameOf(name)
    if not name then return false, 'invalid command name' end
    if not TSS.IsCallable(handler) then return false, 'handler must be callable' end
    if options ~= nil and type(options) ~= 'table' then return false, 'options must be a table' end
    options = options or {}
    if entries[name] and entries[name].owner ~= owner then return false, 'command belongs to another resource' end
    if not installed[name] then
        for _, command in ipairs(GetRegisteredCommands()) do
            if command.name:lower() == name then return false, 'command already registered outside this module' end
        end
    end
    local permission = options.permission
    if permission == nil or permission == false or permission == 'user' then permission = false
    elseif type(permission) == 'string' then
        if permission == '' then return false, 'permission must not be empty' end
    elseif isArray(permission) and #permission > 0 then
        for _, ace in ipairs(permission) do
            if type(ace) ~= 'string' or ace == '' or ace == 'user' then return false, 'permissions must be ACE names' end
        end
    else return false, 'permission must be false, an ACE name, or an array of ACE names' end
    if not server and permission ~= false then return false, 'restricted commands must be registered on the server' end
    local arguments, seen = {}, {}
    if options.arguments ~= nil and not isArray(options.arguments) then return false, 'arguments must be an array' end
    for i, arg in ipairs(options.arguments or {}) do
        if type(arg) ~= 'table' or type(arg.name) ~= 'string' or arg.name == '' or seen[arg.name] then
            return false, 'arguments need unique names'
        end
        local kind = arg.type or 'string'
        if kind ~= 'string' and kind ~= 'number' and kind ~= 'integer' and kind ~= 'boolean' and kind ~= 'rest' then
            return false, 'unsupported argument type: ' .. tostring(kind)
        end
        if kind == 'rest' and i ~= #options.arguments then return false, 'rest argument must be last' end
        arguments[i] = { name = arg.name, type = kind, optional = arg.optional == true,
            help = tostring(arg.help or arg.description or ''), options = copy(arg.options) }
        seen[arg.name] = true
    end
    local data = { name = name, command = '/' .. name, category = tostring(options.category or 'general'),
        description = tostring(options.description or options.help or ''), arguments = arguments,
        permission = copy(permission), hidden = options.hidden == true, debugOnly = options.debugOnly == true,
        allowConsole = options.allowConsole ~= false }
    entries[name] = { owner = owner, data = data, handler = handler }
    if not installed[name] then
        RegisterCommand(name, function(source, args, raw)
            local entry = entries[name]
            if not entry then return end -- Consumer has stopped or unregistered this command.
            if not allowed(entry, source) then reply(source, 'You cannot use this command.'); return end
            local parsed, err = parse(entry.data, args or {})
            if not parsed then reply(source, err); return end
            local ok, failure = pcall(entry.handler, source, parsed, raw, args or {})
            if not ok then
                TSS.Warn(('Command /%s (%s) failed: %s'):format(name, entry.owner, tostring(failure)))
                reply(source, 'The command could not be completed.')
            end
        end, false)
        installed[name] = true
    end
    TSS.Commands.Refresh()
    return true
end

function TSS.Commands.Unregister(owner, name)
    name = nameOf(name)
    if not name or not entries[name] or entries[name].owner ~= owner then return false end
    entries[name] = nil
    TSS.Commands.Refresh()
    return true
end

function TSS.Commands.Clear(owner)
    for name, entry in pairs(entries) do if entry.owner == owner then entries[name] = nil end end
    TSS.Commands.Refresh()
end

function TSS.Commands.Refresh()
    if server then
        if TSS.Commands.RefreshTssChat then TSS.Commands.RefreshTssChat() end
        for _, player in ipairs(GetPlayers()) do
            local source = tonumber(player)
            TriggerClientEvent('tss_bridge:client:commands', source, TSS.Commands.List(source))
        end
    elseif TSS.Commands.RefreshSuggestions then TSS.Commands.RefreshSuggestions() end
end
