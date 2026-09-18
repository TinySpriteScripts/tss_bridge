-- Lazy client implementation owned by the Blips module.
TSS = TSS or {}
TSS.Blips = TSS.Blips or {}

local function applyBlipOptions(blip, data, creating)
    if creating or data.shortRange ~= nil then SetBlipAsShortRange(blip, data.shortRange ~= false) end
    if creating or data.sprite ~= nil then SetBlipSprite(blip, data.sprite or 1) end
    local color = data.color or data.colour or data.col
    if creating or color ~= nil then SetBlipColour(blip, color or 0) end
    if creating or data.scale ~= nil then SetBlipScale(blip, data.scale or 0.7) end
    local display = data.display or data.disp
    if creating or display ~= nil then SetBlipDisplay(blip, display or 4) end
    if data.category ~= nil then SetBlipCategory(blip, data.category) end
    if data.hiddenOnLegend ~= nil then SetBlipHiddenOnLegend(blip, data.hiddenOnLegend) end
    if data.route ~= nil then SetBlipRoute(blip, data.route) end
    if data.routeColor ~= nil then SetBlipRouteColour(blip, data.routeColor) end
    if data.name or data.label then
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(tostring(data.name or data.label))
        EndTextCommandSetBlipName(blip)
    end
end

--- Creates and tracks a map blip for coordinates or an entity.
---@param data TSSBlipData|table Blip definition.
---@return integer? blip Blip handle.
function TSS.CreateBlip(data)
    data = data or {}

    local blip
    if data.entity then
        blip = AddBlipForEntity(data.entity)
    else
        local coords = data.coords or data.pos
        if not coords then
            TSS.Warn('CreateBlip needs coords or entity')
            return nil
        end

        blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipCoords(blip, coords.x, coords.y, coords.z)
    end

    if not blip or blip == 0 then return nil end
    applyBlipOptions(blip, data, true)
    TSS.Blips[blip] = blip

    return blip
end

--- Changes only supplied options on an existing blip, preserving its handle.
---@param blip integer Blip handle.
---@param data TSSBlipData|table Options to update.
---@return boolean updated
function TSS.UpdateBlip(blip, data)
    if not blip or not DoesBlipExist(blip) or type(data) ~= 'table' then return false end
    local coords = data.coords or data.pos
    if coords then SetBlipCoords(blip, coords.x, coords.y, coords.z) end
    applyBlipOptions(blip, data, false)
    return true
end

--- Removes a tracked map blip.
---@param blip integer Blip handle.
function TSS.RemoveBlip(blip)
    if blip == nil then return end
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end

    TSS.Blips[blip] = nil
end

--- Removes all bridge-tracked blips.
function TSS.ClearBlips()
    for blip in pairs(TSS.Blips) do
        TSS.RemoveBlip(blip)
    end
end

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        TSS.ClearBlips()
    end
end)

function createBlip(data)
    return TSS.CreateBlip(data)
end

function createEntityBlip(data)
    data = data or {}
    return TSS.CreateBlip(data)
end

function removeBlip(blip)
    return TSS.RemoveBlip(blip)
end
