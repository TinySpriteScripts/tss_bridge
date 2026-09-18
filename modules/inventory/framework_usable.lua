-- Registration for inventories that consume the framework's usable-item registry.
-- This file is server-only; it is not an additional inventory provider.
local Utils = TSS.Inventory.Utils

function Utils.RegisterFrameworkUsable(item, callback, allowed)
    local system, resource = TSS.Framework.System()
    if allowed and not allowed[system] then return false, 'unsupported_inventory_framework' end
    if not system or not TSS.IsStarted(resource) then return false, 'framework_unavailable' end
    if system == 'qbox' then
        return Utils.RegisterUsableExport(resource, 'CreateUseableItem', item, callback)
    end
    local core = TSS.Framework.Object()
    local register = system == 'qb' and core and core.Functions and core.Functions.CreateUseableItem
        or system == 'esx' and core and core.RegisterUsableItem
    if not TSS.IsCallable(register) then return false, 'framework_registration_unavailable' end
    local ok, result = pcall(register, item, callback)
    if not ok then return false, tostring(result) end
    if result == false then return false, 'provider_rejected_registration' end
    return true
end
