-- Run from tss_bridge: lua tests/commands_spec.lua
local assertions=0
local function check(value,message) assertions=assertions+1;assert(value,message) end
local function runtime(server)
 local env=setmetatable({}, {__index=_G})
 local r={env=env,events={},native={},sent={},aces={},exported={},states={},caller='alpha',logs={}}
 env._G=env
 env.load=function(text,name) return load(text,name,'t',env) end
 env.GetCurrentResourceName=function() return 'tss_bridge' end
 env.GetInvokingResource=function() return r.caller end
 env.IsDuplicityVersion=function() return server end
 env.GetConvar=function(_,fallback) return fallback end
 env.GetResourceState=function(name) return r.states[name] or 'missing' end
 env.GetGameTimer=function() return 10000 end
 env.GetCurrentGameName=function() return 'gta5' end
 env.LoadResourceFile=function(_,file) local f=assert(io.open(file));local s=f:read('*a');f:close();return s end
 env.GetPlayers=function() return {'7','8'} end
 env.IsPlayerAceAllowed=function(source,ace) return r.aces[tostring(source)..':'..ace]==true end
 env.GetRegisteredCommands=function() local list={{name='external'}};for name in pairs(r.native) do list[#list+1]={name=name} end;return list end
 env.RegisterCommand=function(name,handler) r.native[name]=handler end
 env.AddEventHandler=function(name,fn) r.events[name]=r.events[name] or {};table.insert(r.events[name],fn) end
 env.RegisterNetEvent=env.AddEventHandler
 env.TriggerClientEvent=function(...) r.sent[#r.sent+1]={...} end
 env.TriggerServerEvent=env.TriggerClientEvent
 env.TriggerEvent=env.TriggerClientEvent
 env.print=function(...) r.logs[#r.logs+1]={...} end
 env.exports=setmetatable({}, {__call=function(_,name,fn) r.exported[name]=fn end})
 function r.fire(name,...) for _,fn in ipairs(r.events[name] or {}) do fn(...) end end
 function r.load(file) assert(loadfile(file,'t',env))() end
 r.load('shared/config.lua');r.load('shared/helpers.lua');r.load('shared/loader.lua')
 r.load('modules/commands/'..(server and 'server' or 'client')..'.lua')
 function r.api(owner) r.caller=owner;return env.TSSModuleLoader.GetModules({'Commands'}).Commands end
 return r
end
local r=runtime(true);local a,b=r.api('alpha'),r.api('beta');local hits=0;local result
check(a.Register('/Example',{description='Example',permission='admin',arguments={{name='id',type='integer'},{name='enabled',type='boolean'},{name='text',type='rest',optional=true}}},function(source,args,raw,rawArgs) hits=hits+1;result={source,args,raw,rawArgs} end),'register')
check(not a.Register('external',{},function()end),'external conflict')
check(not b.Register('example',{},function()end),'foreign overwrite')
check(not b.Unregister('example'),'foreign removal')
r.native.example(7,{'4','true'},'example 4 true');check(hits==0,'unauthorized execution')
check(#a.List(7)==0,'unauthorized metadata leak')
r.aces['7:admin']=true
check(#a.List(7)==1,'authorized list')
r.native.example(7,{'4','false','hello','World'},'example 4 false hello World')
check(hits==1 and result[2].id==4 and result[2].enabled==false and result[2].text=='hello World','typed arguments')
check(result[1]==7 and result[4][1]=='4','native source/raw args')
for _,args in ipairs({{}, {'x','true'},{'1.5','true'},{'4','maybe'}}) do r.native.example(7,args,'example') end
check(hits==1,'invalid arguments executed')
r.native.example(0,{'5','true'},'example');check(hits==2,'console denied')
r.aces['8:command.example']=true;r.native.example(8,{'6','true'},'example');check(hits==3,'command ACE failed')
r.aces['7:admin']=nil;r.native.example(7,{'4','true'},'example');check(hits==3,'revoked ACE ignored')
local copied=a.List(8);copied[1].arguments[1].name='corrupted';check(a.List(8)[1].arguments[1].name=='id','metadata aliases registry')
check(a.Register('hidden',{hidden=true},function()hits=hits+1 end),'hidden registration');check(#a.List(0)==1,'hidden metadata leaked');r.native.hidden(7,{},'hidden');check(hits==4,'hidden should execute')
check(a.Register('debug',{debugOnly=true},function()hits=hits+1 end),'debug registration');r.native.debug(7,{},'debug');check(hits==4,'debug gate ignored');r.env.TSS.Config.Debug=true;r.native.debug(7,{},'debug');check(hits==5,'debug gate enabled failed')
check(a.Register('playeronly',{allowConsole=false},function()hits=hits+1 end),'player registration');r.native.playeronly(0,{},'playeronly');check(hits==5,'console restriction bypass')
local cfx=setmetatable({__cfx_functionReference='test'}, {__call=function()hits=hits+1 end})
check(b.Register('reference',{},cfx),'CFX callable rejected');r.native.reference(7,{},'reference');check(hits==6,'CFX callback failed')
check(a.Unregister('example'),'unregister');r.native.example(8,{'4','true'},'example');check(hits==6,'unregistered callback ran')
check(a.Register('example',{},function()hits=hits+10 end),'reregister');r.native.example(7,{},'example');check(hits==16,'stale handler invoked')
r.fire('onResourceStop','alpha');r.native.example(7,{},'example');check(hits==16,'stopped consumer handler ran');check(#a.List(0)==0,'stopped metadata remains');check(#b.List(0)==1,'other owner cleared')
check(b.Register('failure',{},function()error('test failure')end),'error command');r.native.failure(7,{},'failure');check(#r.logs>0,'handler failure not logged')
-- Real tss-chat provider integration, with Cfx export method/self semantics.
local chat=setmetatable({}, {__index=r.env});chat.TSSChatConfig={};chat.CreateThread=function()end
local chatExports={};chat.exports=setmetatable({}, {__call=function(_,name,fn)chatExports[name]=fn end})
local bridgeProxy={};for name,fn in pairs(r.exported) do bridgeProxy[name]=function(self,...) assert(self==bridgeProxy);return fn(...) end end
chat.exports.tss_bridge=bridgeProxy
assert(loadfile('../../tss-chat/server/sv_main.lua','t',chat))()
local chatProxy={};for name,fn in pairs(chatExports) do chatProxy[name]=function(self,...) assert(self==chatProxy);return fn(...) end end
r.env.exports['tss-chat']=chatProxy;r.states['tss-chat']='started';r.states.tss_bridge='started'
r.fire('tss-chat:server:ready')
check(b.Register('staff',{permission={'staff','admin'}},function()end),'staff registration')
local function contains(list,name) for _,v in ipairs(list) do if v.name==name then return true end end return false end
check(not contains(chatExports.GetCommandList(7),'staff'),'provider permission leaked')
r.aces['7:staff']=true;check(contains(chatExports.GetCommandList(7),'staff'),'provider lost player source')
check(not contains(chatExports.GetCommandList(8),'staff'),'provider used wrong source')
r.states['tss-chat']='stopped';r.fire('onResourceStop','tss-chat');r.states['tss-chat']='started';r.fire('tss-chat:server:ready');check(contains(chatExports.GetCommandList(7),'staff'),'chat restart failed')
b.Unregister('staff');check(not contains(chatExports.GetCommandList(7),'staff'),'stale chat command after unregister')
check(not b.Register('badargs',{arguments={wrong={name='x'}}},function()end),'non-array arguments accepted')
check(not b.Register('badpermission',{permission={admin=true}},function()end),'non-array permissions accepted')
check(not b.Register('badrest',{arguments={{name='text',type='rest'},{name='other'}}},function()end),'non-final rest accepted')
check(not b.Register('badtype',{arguments={{name='x',type='unsupported'}}},function()end),'invalid type accepted')
local c=runtime(false);local ca=c.api('client_owner');check(not ca.Register('restricted',{permission='admin'},function()end),'client restriction accepted')
check(ca.Register('localui',{arguments={{name='message',type='rest'}}},function(_,args) result=args end),'client registration')
c.native.localui(0,{'hello','there'},'localui hello there');check(result.message=='hello there','client parsing')
c.env.source=65535;c.fire('tss_bridge:client:commands',{{name='servercommand',description='Server',arguments={}}})
check(c.sent[#c.sent][1]=='chat:addSuggestion','fallback suggestions missing')
c.env.source=1;local before=#c.sent;c.fire('tss_bridge:client:commands',{});check(#c.sent==before,'accepted non-server suggestion payload')
c.fire('onClientResourceStop','client_owner');check(#ca.List()==0,'client cleanup failed')
print(('PASS: %d Commands checks including actual tss-chat provider integration'):format(assertions))
