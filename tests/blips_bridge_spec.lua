-- Run from tss_bridge: lua tests/blips_bridge_spec.lua
local records, events, threads, cleanup = {}, {}, {}, {}
local nextHandle, assertions = 0, 0
local function check(value, message) assertions=assertions+1; assert(value,message) end
local vectorMeta = {}
vectorMeta.__sub=function(a,b) return setmetatable({x=a.x-b.x,y=a.y-b.y,z=a.z-b.z},vectorMeta) end
vectorMeta.__len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
function vector3(x,y,z) return setmetatable({x=x,y=y,z=z},vectorMeta) end
function AddBlipForCoord(x,y,z)
    nextHandle=nextHandle+1; records[nextHandle]={coords=vector3(x,y,z)}; return nextHandle
end
function AddBlipForEntity(entity) local b=AddBlipForCoord(0,0,0);records[b].entity=entity;return b end
function SetBlipCoords(b,x,y,z) records[b].coords=vector3(x,y,z) end
function DoesBlipExist(b) return records[b] ~= nil end
function RemoveBlip(b) records[b]=nil end
function GetBlipCoords(b) return records[b].coords end
function GetBlipColour(b) return records[b].color end
for native, field in pairs({SetBlipAsShortRange='shortRange',SetBlipSprite='sprite',SetBlipColour='color',
    SetBlipScale='scale',SetBlipDisplay='display',SetBlipCategory='category',SetBlipHiddenOnLegend='legend',
    SetBlipRoute='route',SetBlipRouteColour='routeColor'}) do
    _G[native]=function(b,value) records[b][field]=value end
end
local label
function BeginTextCommandSetBlipName() end
function AddTextComponentString(value) label=value end
function EndTextCommandSetBlipName(b) records[b].label=label end
function AddEventHandler(name,fn) events[name]=fn end
RegisterNetEvent=AddEventHandler
function GetCurrentResourceName() return 'tss_bridge' end
TSS={Warn=function(message) error(message) end}
local descriptor
TSSModuleLoader={Define=function(value) descriptor=value end}
dofile('modules/blips/shared.lua'); dofile('modules/blips/client.lua')
local function makeApi()
    return descriptor.client({OnStop=function(fn) cleanup[#cleanup+1]=fn end})
end
local api, other=makeApi(),makeApi()
local handle=api.Create({coords=vector3(1,2,3),sprite=0,colour=0,display=0,shortRange=false,hiddenOnLegend=false,route=false})
check(api.Exists(handle) and not other.Exists(handle),'ownership/existence')
check(records[handle].sprite==0 and records[handle].display==0 and records[handle].color==0,'zero options lost')
check(records[handle].shortRange==false and records[handle].legend==false,'false options lost')
check(api.Update(handle,{display=2,route=true,routeColor=5}),'update failed')
check(records[handle].sprite==0 and records[handle].coords.x==1,'partial update reset options')
check(api.Update(handle,{route=false,hiddenOnLegend=true,colour=7}),'route update failed')
check(records[handle].route==false and records[handle].legend==true and api.Colour(handle)==7,'option update failed')
check(not other.Update(handle,{display=0}),'cross-consumer update allowed')
check(not api.Update(nil,{}) and not api.Exists(nil),'nil handle not safe')
api.Remove(nil); api.Remove(handle)
check(not api.Exists(handle) and api.Coords(handle)==nil,'removed handle still exists')
local entity=api.CreateEntity({entity=17})
check(records[entity].entity==17,'entity path broken')
api.Clear()

local character, playerCoords=nil,vector3(0,0,0)
function CreateThread(fn) threads[#threads+1]=coroutine.create(fn) end
function Wait() coroutine.yield() end
function TriggerEvent(name,...) return events[name](...) end
function TriggerServerEvent() end
function PlayerPedId() return 1 end
function GetEntityCoords() return playerCoords end
function debugPrint() end
local modules={Blips=api,Player={Identifier=function() return character end,Job=function() return {name='police'} end}}
exports={tss_bridge={GetModules=function(_,names)
    local requested=false
    for _,name in ipairs(names) do if name=='Blips' then requested=true end end
    check(requested,'consumer did not request Blips module');return modules
end}}
local consumer=setmetatable({}, {__index=_G})
local function loadConsumer(path) assert(loadfile('../../[tss_free]/tss-blipcreator/'..path,'t',consumer))() end
loadConsumer('shared/config.lua'); loadConsumer('client/bridge.lua'); loadConsumer('client/utils.lua'); loadConsumer('client/main.lua')
local cfg=consumer.Config
cfg.Options.PingBlipTimer=1
cfg.DefaultBlips={
    {JobLocked='ambulance',vector=vector3(5,5,5),text='Locked'},
    {vector=vector3(6,6,6),text='Visible',sprite=40,scale=0.5,color=3,view=5,hiddenlegend=true,rangeshort=false},
}
local function tick(index) local ok,err=coroutine.resume(threads[index]);assert(ok,err) end
for i=1,#threads do tick(i) end
TriggerEvent('tss-blipcreator:CreateDefaultBlips')
check(consumer.DefaultBlips[1]==nil and api.Exists(consumer.DefaultBlips[2]),'job lock prevented remaining defaults')
local default=consumer.DefaultBlips[2]
check(records[default].legend and not records[default].shortRange,'default legend/range lost')
TriggerEvent('tss-blipcreator:CreateDefaultBlips')
check(not records[default],'default blip leaked on refresh')
local data={a={coords=vector3(100,100,100),sprite='House',colour='Blue',scale='Small',label='Home'}}
TriggerEvent('tss-blipcreator:client:CreateBlips',data)
handle=consumer.Blips.a
check(records[handle].sprite==40 and records[handle].label=='Home','personal creation failed')
consumer.ToggleBlipsVisibility()
check(records[handle].display==0,'visibility toggle failed')
data.a.label='Updated';data.a.colour='Red'
TriggerEvent('tss-blipcreator:client:UpdateBlip',data,'a')
check(consumer.Blips.a==handle and records[handle].label=='Updated' and records[handle].display==0,'edit recreated handle or reset visibility')
TriggerEvent('tss-blipcreator:client:CreateBlipPing','a')
local ping=consumer.PingingBlips.a.ID
check(records[ping].color==1,'ping colour mismatch')
tick(2)
check(not records[ping] and consumer.PingingBlips.a==nil,'ping expiration leaked')
TriggerEvent('tss-blipcreator:client:SetGPSTo','a')
local route=consumer.MyRouteBlip
check(records[route].route and records[route].sprite==0 and records[route].routeColor==1,'GPS route lost')
data.a.colour='Blue';data.a.coords=vector3(200,200,200)
TriggerEvent('tss-blipcreator:client:UpdateBlip',data,'a')
check(records[route].routeColor==3 and records[route].coords.x==200,'route not updated with marker')
TriggerEvent('tss-blipcreator:client:CreateBlipPing','a')
TriggerEvent('tss-blipcreator:client:RemoveBlip','a')
check(not records[handle] and not records[route] and consumer.Blips.a==nil and consumer.PingingBlips.a==nil,'delete leaked marker/ping/route')
TriggerEvent('tss-blipcreator:client:NewBlipRegistered',data,'a')
TriggerEvent('tss-blipcreator:client:SetGPSTo','a')
route=consumer.MyRouteBlip;playerCoords=vector3(200,200,200);tick(3)
check(not records[route] and consumer.MyRouteBlip==nil,'arrival did not remove route')
character='new-character';tick(1)
check(next(consumer.Blips)==nil and consumer.MyRouteBlip==nil,'character switch did not clear state')
local foreign=other.Create({coords=vector3(0,0,0)})
cleanup[1]()
check(records[foreign]~=nil,'consumer cleanup removed another consumer blip')
other.Clear()
check(next(records)==nil,'cleanup leaked blips')
print(('PASS: %d checks for blip options, partial updates, ownership, creator flows, ping expiry, routes and cleanup'):format(assertions))
