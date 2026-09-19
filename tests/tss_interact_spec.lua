local adapter, registration
local calls = {}
local allowed, hasItem = true, true
TSS = {
    Resources = {TssInteract = 'tss-interactions'},
    Player = {HasGroup = function() return allowed end},
    Inventory = {Has = function() return hasItem end},
    Target = {
        Utils = {Call = function(resource, name, ...)
            assert(resource == 'tss-interactions')
            calls[#calls+1] = {name, ...}
            return 'registration-id'
        end},
        RegisterAdapter = function(key, resource, value, options)
            assert(key == 'tss_interact') adapter, registration = value, options
        end,
    },
}
local emitted
function TriggerEvent(...) emitted = {...} end
TriggerServerEvent = TriggerEvent
function ExecuteCommand(name) emitted = {name} end
function GetEntityCoords() return {x=1,y=2,z=3} end
dofile('modules/targets/adapters/tss_interact.lua')
local coords = {x=1,y=2,z=3}
local context
local options = {{label='Example', groups={mechanic=2}, items={steel=2}, onSelect=function(value) context=value end}}
assert(adapter.box('tss-interactions', {name='desk',coords=coords,length=999,minZ=-100}, options, 2.5) == 'registration-id')
local call = calls[#calls]
assert(call[1]=='AddPoint' and call[2]=='desk' and call[3]==coords and call[4].distance==2.5)
assert(call[4].length==nil and call[4].minZ==nil)
local option = call[4].options[1]
assert(option.canInteract(0,1,{}))
allowed=false assert(not option.canInteract(0,1,{})) allowed=true
hasItem=false assert(not option.canInteract(0,1,{})) hasItem=true
option.action(nil,{coords=coords}) assert(context.coords==coords)
adapter.circle('tss-interactions', {'legacy',coords,100,{}}, options)
assert(calls[#calls][2]=='legacy')
adapter.circle('tss-interactions', {coords=coords}, options)
assert(calls[#calls][1]=='AddInteraction')
adapter.entity('tss-interactions', 42, {label='Event',serverEvent='example',args={id=3}})
call=calls[#calls] assert(call[1]=='AddEntity')
call[3].options[1].action() assert(emitted[1]=='example' and emitted[2].id==3)
adapter.model('tss-interactions', {'model'}, options)
assert(calls[#calls][1]=='AddModel')
adapter.removeEntity('tss-interactions',42) assert(calls[#calls][1]=='RemoveEntity')
adapter.removeModel('tss-interactions',{'model'}) assert(calls[#calls][1]=='RemoveModel')
adapter.removeZone('tss-interactions','registration-id') assert(calls[#calls][1]=='RemoveInteraction')
print('Passed: point conversion, legacy zone input, geometry ignored, callbacks, group/item filters, events and removal routes.')
