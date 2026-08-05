-- Server-owned runtime configuration used by the Bridge Lab editor.
-- server.cfg convars always win; unlocked selections are persisted as resource KVPs.
TSSBridgeLabConfiguration = {}

local Configuration = TSSBridgeLabConfiguration
local bridgeConfig = assert(TSS and TSS.Config, 'TSS configuration is not initialized')
local unsetConvar = '__tss_bridge_convar_not_set__'
local kvpPrefix = 'tss_bridge:configuration:'

local definitions = {
    {
        key = 'Notify', label = 'Notifications', convar = 'tss_notify', icon = 'notify',
        description = 'Default notification adapter used by client and server calls.',
        options = {
            { value = 'auto', label = 'Auto Detect' },
            { value = 'tss', label = 'TSS Built-in' },
            { value = 'ox', label = 'ox_lib' },
            { value = 'qb', label = 'QB-Core' },
            { value = 'qbox', label = 'Qbox' },
            { value = 'okok', label = 'okokNotify' },
            { value = 'mythic', label = 'mythic_notify' },
            { value = 'wasabi', label = 'Wasabi Notify' },
            { value = 'native', label = 'GTA Native' },
        },
    },
    {
        key = 'ProgressBar', label = 'Progress Bar', convar = 'tss_progressbar', icon = 'timer',
        description = 'Default progress adapter for timed client interactions.',
        options = {
            { value = 'auto', label = 'Auto Detect' },
            { value = 'tss', label = 'TSS Built-in' },
            { value = 'ox', label = 'ox_lib' },
            { value = 'qb', label = 'QB Progressbar' },
        },
    },
    {
        key = 'TextUI', label = 'Text UI', convar = 'tss_textui', icon = 'text',
        description = 'Default adapter for persistent player prompts.',
        options = {
            { value = 'auto', label = 'Auto Detect' },
            { value = 'ox', label = 'ox_lib' },
            { value = 'qb', label = 'QB-Core' },
            { value = 'native', label = 'GTA Native' },
        },
    },
    {
        key = 'Interaction', label = 'Interactions', convar = 'tss_interaction', icon = 'interaction',
        description = 'Choose target-based or proximity/TextUI interactions.',
        options = {
            { value = 'auto', label = 'Auto Detect' },
            { value = 'target', label = 'Target System' },
            { value = 'textui', label = 'Proximity + TextUI' },
        },
    },
}

local byKey = {}
local locked = {}

local function normalize(value)
    return tostring(value or ''):lower():match('^%s*(.-)%s*$')
end

local function acceptedValues(definition)
    local accepted = {}
    for i = 1, #definition.options do accepted[definition.options[i].value] = true end
    return accepted
end

for i = 1, #definitions do
    local definition = definitions[i]
    definition.accepted = acceptedValues(definition)
    byKey[definition.key:lower()] = definition

    local convarValue = GetConvar(definition.convar, unsetConvar)
    locked[definition.key] = convarValue ~= unsetConvar

    if locked[definition.key] then
        bridgeConfig[definition.key] = normalize(convarValue)
    elseif type(GetResourceKvpString) == 'function' then
        local saved = normalize(GetResourceKvpString(kvpPrefix .. definition.key))
        if definition.accepted[saved] then bridgeConfig[definition.key] = saved end
    end
end

--- Returns the current editable configuration without lock metadata.
---@return table<string, string> values
function Configuration.Values()
    local values = {}
    for i = 1, #definitions do
        local definition = definitions[i]
        values[definition.key] = normalize(bridgeConfig[definition.key])
    end
    return values
end

local function publish(values, target)
    if GlobalState and target == nil then GlobalState.tssBridgeConfiguration = values end
    TriggerClientEvent('tss_bridge:client:configuration:sync', target or -1, values)
end

--- Returns configuration definitions, choices, current values, and convar locks.
---@return table snapshot
function Configuration.Snapshot()
    local items = {}
    for i = 1, #definitions do
        local definition = definitions[i]
        local options = {}
        for optionIndex = 1, #definition.options do
            local option = definition.options[optionIndex]
            options[optionIndex] = { value = option.value, label = option.label }
        end

        items[i] = {
            key = definition.key,
            label = definition.label,
            description = definition.description,
            convar = definition.convar,
            icon = definition.icon,
            current = normalize(bridgeConfig[definition.key]),
            locked = locked[definition.key] == true,
            blockedMessage = locked[definition.key] and 'Blocked by server.cfg' or nil,
            options = options,
        }
    end

    return { items = items, values = Configuration.Values() }
end

--- Applies and persists one unlocked adapter selection.
---@param key string
---@param value string
---@return boolean changed
---@return string message
function Configuration.Set(key, value)
    local definition = type(key) == 'string' and byKey[key:lower()] or nil
    if not definition then return false, 'Unknown bridge configuration option' end
    if locked[definition.key] then return false, 'Blocked by server.cfg' end

    value = normalize(value)
    if not definition.accepted[value] then return false, 'Unsupported adapter selection' end

    bridgeConfig[definition.key] = value
    if type(SetResourceKvp) == 'function' then SetResourceKvp(kvpPrefix .. definition.key, value) end

    publish(Configuration.Values())
    return true, ('%s changed to %s'):format(definition.label, value)
end

RegisterNetEvent('tss_bridge:server:configuration:request', function()
    publish(Configuration.Values(), source)
end)

if GlobalState then GlobalState.tssBridgeConfiguration = Configuration.Values() end
