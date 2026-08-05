-- Lazy client implementation owned by the Blips module.
TSS = TSS or {}
TSS.Blips = TSS.Blips or {}

local function applyBlipOptions(blip, data)
    SetBlipAsShortRange(blip, data.shortRange ~= false)
    SetBlipSprite(blip, data.sprite or 1)
    SetBlipColour(blip, data.color or data.col or 0)
    SetBlipScale(blip, data.scale or 0.7)
    SetBlipDisplay(blip, data.display or data.disp or 4)

    if data.category then
        SetBlipCategory(blip, data.category)
    end

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

    applyBlipOptions(blip, data)
    TSS.Blips[blip] = blip

    return blip
end

--- Removes a tracked map blip.
---@param blip integer Blip handle.
function TSS.RemoveBlip(blip)
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
