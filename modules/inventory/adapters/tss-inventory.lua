-- TSS grid inventory adapter. Stable item instance IDs are exposed as bridge slots.
local U=TSS.Inventory.Utils
local server=TSS.IsServer()
local function call(resource,name,...) return U.TryExports(resource,{name},...) end
local function inventory(resource,source)
    if server then return call(resource,'GetPlayerInventory',tonumber(source)) end
    return call(resource,'GetLocalInventory')
end
local function normalise(item,resource)
    local d=item.definition or call(resource,'GetItemDefinition',item.name) or {}
    local out={};for k,v in pairs(item) do out[k]=v end
    out.slot=item.id;out.count=item.amount;out.info=item.metadata;out.weight=d.weight or 0;out.label=d.label or item.name
    return out
end
local function items(resource,source)
    local inv=inventory(resource,source);local out={}
    for _,item in ipairs(inv and inv.items or {}) do out[#out+1]=normalise(item,resource) end
    return out
end
local function add(resource,id,name,amount,metadata,slot)
    if slot and slot~=false then return call(resource,'AddItemToSlot',id,name,amount or 1,metadata,tonumber(slot))==true end
    return call(resource,'AddItem',id,name,amount or 1,metadata)==true
end
local adapter={
    inventory=items,
    items=function(resource) return call(resource,'GetItemDefinitions') or {} end,
    count=function(resource,source,name,metadata) return U.CountItems(items(resource,source),name,metadata) end,
    getSlot=function(resource,source,slot) return U.GetSlot(items(resource,source),tonumber(slot)) end,
    find=function(resource,source,name,metadata) return U.FindItems(items(resource,source),name,metadata) end,
    weight=function(resource,source) local inv=inventory(resource,source);if not inv then return nil end return inv.weight or (server and call(resource,'GetInventoryWeight',inv.id)) end,
    maxWeight=function(resource,source) local inv=inventory(resource,source);return inv and inv.maxWeight end,
    image=function(resource,name,definition) return ('https://cfx-nui-%s/web/images/%s'):format(resource,definition.image or name..'.png') end,
    close=function(resource,source) if server then return call(resource,'CloseInventory',tonumber(source)) end return call(resource,'CloseInventory') end,
    openInventory=function(resource,source,kind,data)
        local id=type(data)=='table' and (data.id or data.stash or data.name or data.type) or data
        if not server then
            if kind=='player' then return call(resource,'OpenSelf')==true end
            if kind=='shop' and type(id)=='string' then return call(resource,'OpenShop',id)==true end
            return false -- Arbitrary stash grants must originate on the server.
        end
        if kind=='shop' then return call(resource,'OpenShop',tonumber(source),id)==true end
        if kind=='player' then local inv=inventory(resource,source);return inv and call(resource,'OpenInventory',tonumber(source),inv.id)==true or false end
        if kind=='stash' and type(id)=='string' then return call(resource,'OpenInventory',tonumber(source),id)==true end
        return false
    end,
}
if server then
    adapter.add=function(resource,source,name,amount,metadata,slot) local inv=inventory(resource,source);return inv and add(resource,inv.id,name,amount,metadata,slot) or false end
    adapter.remove=function(resource,source,name,amount,metadata,slot) local inv=inventory(resource,source);return inv and call(resource,'RemoveItemsByName',inv.id,name,amount or 1,metadata,slot and tonumber(slot))==true or false end
    adapter.canCarry=function(resource,source,name,amount,metadata) local inv=inventory(resource,source);return inv and call(resource,'CanCarryItem',inv.id,name,amount or 1,metadata)==true or false end
    adapter.setMetadata=function(resource,source,slot,metadata) local inv=inventory(resource,source);return inv and call(resource,'SetItemMetadata',inv.id,slot,metadata)==true or false end
    adapter.registerUsable=function(resource,name,callback,owner) return call(resource,'RegisterUsableItem',name,function(source,item,id) return callback(source,normalise(item,resource),id) end,owner)==true end
    adapter.registerStash=function(resource,data)
        local id=data.id or data.name
        if data.owner or data.groups or data.coords then return false end
        local existing=call(resource,'GetInventory',id);if existing then return existing.type~='shop' end
        local size=data.size
        if not size then local slots=tonumber(data.slots) or 50;local x=math.min(8,slots);size={x=x,y=math.ceil(slots/x)} end
        -- Owner/groups/coords require an access policy; never silently discard restrictions.
        return call(resource,'CreateInventory',id,'stash',{label=data.label or id,size=size,maxWeight=data.weight or data.maxWeight,metadata=data.metadata or {}})==true
    end
    adapter.stashItems=function(resource,id) local inv=call(resource,'GetInventory',id);if not inv or inv.type=='shop' then return nil end local out={} for _,item in ipairs(inv.items) do out[#out+1]=normalise(item,resource) end return out end
    adapter.stashAdd=add
    adapter.stashRemove=function(resource,id,name,amount,metadata,slot) return call(resource,'RemoveItemsByName',id,name,amount or 1,metadata,slot and tonumber(slot))==true end
    adapter.registerShop=function(resource,data)
        local stock={}
        for _,item in ipairs(data.items) do
            if type(item)~='table' or type(item.name)~='string' or item.name=='' then return false,'Invalid shop item' end
            if stock[item.name] then return false,'Duplicate item names are not supported in a shop' end
            stock[item.name]={price=item.price,amount=item.count~=nil and item.count or (item.amount~=nil and item.amount or false),metadata=item.metadata or item.info}
        end
        return call(resource,'RegisterShop',data.id,{label=data.label,size=data.size or {x=8,y=10},coords=data.coords,distance=data.distance,account=data.account,groups=data.groups,stock=stock})==true
    end
    adapter.openShop=function(resource,source,id) return call(resource,'OpenShop',tonumber(source),id)==true end
end
TSS.Inventory.RegisterAdapter('tss',TSS.Resources.TssInventory,adapter,{priority=5,aliases={'tss-inventory','tss_inventory'}})
