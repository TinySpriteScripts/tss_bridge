-- Public progress API. Rendering integrations live in adapters.
TSS = TSS or {}
TSS.Progress = TSS.Progress or {}
TSS.Progress.Utils = TSS.Progress.Utils or {}

local active = false
local running
local registry = TSS.Adapters.Create('ProgressBar', { config = 'ProgressBar', fallback = 'tss' })

function TSS.Progress.RegisterAdapter(key, resource, adapter, options)
    return registry:Register(key, resource, adapter, options)
end

function TSS.Progress._IsActive()
    return active
end

--- Detects the selected progress-bar adapter.
---@param preferred? string
---@return string? system
---@return string? resource
function TSS.Progress.System(preferred)
    local system, resource = registry:Resolve(preferred)
    return system, resource
end

--- Reports whether the selected progress adapter supports a feature.
---@param feature 'cancel'|'animation'|'controls'|'circle'|'props'|string
---@param preferred? string
---@return boolean supported
function TSS.Progress.Supports(feature, preferred)
    return registry:Supports(feature, preferred)
end

--- Runs a progress action and waits until it completes or is cancelled.
---@param data TSSProgressData|table
---@return boolean completed
function TSS.ProgressBar(data, owner)
    if running then return false end
    active = true
    data = data or {}

    local system, resource, adapter = registry:Resolve(data.adapter)
    local action = { adapter = adapter, resource = resource, owner = owner }
    running = action
    local ok, result = pcall(function()
        return adapter and adapter.start and adapter.start(resource, data) == true or false
    end)
    if running == action then active, running = false, nil end

    if not ok then
        TSS.Warn(('Progress bar failed using %s: %s'):format(tostring(system), result))
        return false
    end
    return result == true
end

--- Cancels the active progress action.
---@return boolean stopped
function TSS.StopProgressBar(owner)
    local action = running
    if not action or (owner and action.owner ~= owner) then return false end
    active = false
    if action.adapter and action.adapter.stop then action.adapter.stop(action.resource) end
    return true
end

TSS.Progress.Start = TSS.ProgressBar
TSS.Progress.Stop = TSS.StopProgressBar

function progressBar(data) return TSS.ProgressBar(data) end
function stopProgressBar() return TSS.StopProgressBar() end

if TSS.IsClient() then
    exports('ProgressBar', function(data) return TSS.ProgressBar(data or {}) end)
    exports('CancelProgressBar', function() return TSS.StopProgressBar() end)
    RegisterCommand('tss_cancelprogress', function() TSS.StopProgressBar() end, false)
    RegisterKeyMapping('tss_cancelprogress', 'Cancel TinySprite progress', 'keyboard', 'X')
end
